# ==============================================================================
# Taj's Core - Node Registry
# Author: TajemnikTV
# Description: Mod-safe registry for window/node metadata.
# ==============================================================================
class_name TajsCoreNodeRegistry
extends RefCounted

const DEFAULT_ICON := "question_mark"
const DEFAULT_CATEGORY := "utility"
const DEFAULT_SUB_CATEGORY := "file"
const DEFAULT_ATTRIBUTES := {"limit": - 1}
const WINDOW_BUTTON_SCENE := preload("res://scenes/window_button.tscn")
const WINDOW_MENU_SCRIPT := "res://scripts/windows_menu.gd"
const NodeDefs := preload("res://mods-unpacked/TajemnikTV-Core/core/nodes/node_defs.gd")

var _allowed_categories: Array = ["network", "cpu", "gpu", "research", "hacking", "factory", "coding", "utility"]

var _nodes: Dictionary = {}
var _mod_nodes: Dictionary = {}
var _pending_windows: Array = []
var _resource_types: Dictionary = {}
var _file_types: Dictionary = {}
var _window_categories: Dictionary = {}
var _category_items: Dictionary = {}
var _logger
var _event_bus
var _patches

func _init(logger = null, event_bus = null, patches = null) -> void:
	_logger = logger
	_event_bus = event_bus
	_patches = patches

func register_node(def: Dictionary) -> bool:
	var normalized := _normalize_def(def)
	if normalized.is_empty():
		return false
	var node_id: String = normalized["id"]
	if _nodes.has(node_id):
		_log_error("nodes", "Node '%s' already registered." % node_id)
		_emit_failed(node_id, "duplicate_id", normalized.get("mod_id", ""))
		return false
	if _data_has_window(node_id):
		_log_error("nodes", "Node '%s' conflicts with existing Data.windows entry." % node_id)
		_emit_failed(node_id, "data_conflict", normalized.get("mod_id", ""))
		return false
	_nodes[node_id] = normalized
	_track_mod_node(node_id, normalized.get("mod_id", ""))

	if normalized.has("window_def"):
		_register_data_window(node_id, normalized["window_def"])
		_try_refresh_menu(node_id)

	_emit_registered(node_id, normalized.get("mod_id", ""))
	return true

func register_window_type(id: String, config: Dictionary) -> bool:
	var def := _window_config_to_def(id, config)
	if def.is_empty():
		return false
	return register_node(def)

func unregister_window_type(id: String) -> bool:
	return unregister_node(id)

func get_window_config(id: String) -> Dictionary:
	return get_node_def(id)

func get_registered_window_types() -> Array[String]:
	return _nodes.keys()

func set_window_limit(node_id: String, limit: int) -> bool:
	if not _autoload_ready("Data"):
		return false
	var safe_id := _sanitize_id(node_id)
	if not Data.windows.has(safe_id):
		return false
	Data.windows[safe_id]["attributes"]["limit"] = limit
	if _autoload_ready("Attributes"):
		if Attributes.window_attributes == null:
			Attributes.window_attributes = {}
		if not Attributes.window_attributes.has(safe_id):
			Attributes.window_attributes[safe_id] = {}
		Attributes.window_attributes[safe_id]["limit"] = Attribute.new(limit)
	return true

func register_resource_type(id: String, config: Dictionary) -> bool:
	if id == "":
		return false
	if not _autoload_ready("Data"):
		return false
	Data.resources[id] = config.duplicate(true)
	_resource_types[id] = config.duplicate(true)
	_try_register_resource_icon(id, config)
	return true

func register_file_type(id: String, config: Dictionary) -> bool:
	if id == "":
		return false
	if not _autoload_ready("Data"):
		return false
	Data.files[id] = config.duplicate(true)
	_file_types[id] = config.duplicate(true)
	return true

func register_window_category(id: String, label: String, icon: String, position: int = -1) -> bool:
	if id == "":
		return false
	_window_categories[id] = {"label": label, "icon": icon, "position": position}
	if not _allowed_categories.has(id):
		_allowed_categories.append(id)
	_log_warn("nodes", "Registered custom window category '%s'; UI injection may require custom scenes." % id)
	return true

func add_to_window_category(category_id: String, window_id: String, position: int = -1) -> bool:
	if category_id == "" or window_id == "":
		return false
	if not _category_items.has(category_id):
		_category_items[category_id] = []
	_category_items[category_id].append({"id": window_id, "position": position})
	return true

func unregister_node(node_id: String) -> bool:
	if not _nodes.has(node_id):
		return false
	if _data_has_window(node_id):
		var count: int = _get_window_count(node_id)
		if count > 0:
			_log_warn("nodes", "Node '%s' has active windows; unregister blocked." % node_id)
			return false
		Data.windows.erase(node_id)
		_remove_from_attributes(node_id)
		_remove_from_globals(node_id)
		_remove_from_menu(node_id)
	_nodes.erase(node_id)
	_untrack_mod_node(node_id)
	return true

func get_node_def(node_id: String) -> Dictionary:
	if not _nodes.has(node_id):
		return {}
	return _nodes[node_id].duplicate(true)

func list_nodes(filter: Dictionary = {}) -> Array:
	var results: Array = []
	for node_id: String in _nodes:
		var entry: Dictionary = _nodes[node_id]
		if filter.has("mod_id") and entry.get("mod_id", "") != filter["mod_id"]:
			continue
		if filter.has("category") and entry.get("category", "") != filter["category"]:
			continue
		if filter.has("tag"):
			var tags: Array = entry.get("tags", [])
			if not tags.has(filter["tag"]):
				continue
		if filter.has("tags"):
			var required: Array = filter["tags"]
			var tags_list: Array = entry.get("tags", [])
			var ok := true
			for tag in required:
				if not tags_list.has(tag):
					ok = false
					break
			if not ok:
				continue
		results.append(entry.duplicate(true))
	return results

func refresh_node_catalog() -> bool:
	var menu = _find_windows_menu()
	if menu == null:
		_log_warn("nodes", "WindowsMenu not found; refresh skipped.")
		return false
	var added := 0
	for node_id: String in _nodes:
		if not _data_has_window(node_id):
			continue
		if _add_button_to_menu(menu, node_id):
			added += 1
	if added > 0:
		_log_info("nodes", "Refreshed WindowsMenu; added %d node(s)." % added)
	return added > 0

func get_mod_nodes() -> Dictionary:
	var result := {}
	for mod_id in _mod_nodes:
		result[mod_id] = _mod_nodes[mod_id].duplicate()
	return result

func get_mod_node_count() -> int:
	var count := 0
	for mod_id in _mod_nodes:
		count += _mod_nodes[mod_id].size()
	return count

func _normalize_def(def: Dictionary) -> Dictionary:
	if def.is_empty():
		_log_error("nodes", "Node definition missing.")
		return {}
	if not def.has("id"):
		_log_error("nodes", "Node definition missing id.")
		return {}
	var node_id := str(def["id"])
	if node_id == "" or not _is_namespaced_id(node_id):
		_log_error("nodes", "Invalid id '%s' (must be namespaced like ModId.node_id)." % node_id)
		_emit_failed(node_id, "invalid_id", _extract_mod_id(node_id))
		return {}
	if not def.has("display_name"):
		_log_error("nodes", "Node '%s' missing display_name." % node_id)
		_emit_failed(node_id, "missing_display_name", _extract_mod_id(node_id))
		return {}
	var display_name := str(def["display_name"])

	var scene_path := ""
	var scene_entry := ""
	if def.has("packed_scene_path"):
		scene_path = _normalize_scene_path(def["packed_scene_path"])
		if scene_path == "":
			_log_error("nodes", "Node '%s' packed_scene_path is invalid." % node_id)
			_emit_failed(node_id, "invalid_scene_path", _extract_mod_id(node_id))
			return {}
		if not ResourceLoader.exists(scene_path):
			_log_error("nodes", "Node '%s' scene missing: %s" % [node_id, scene_path])
			_emit_failed(node_id, "missing_scene", _extract_mod_id(node_id))
			return {}
		scene_entry = NodeDefs.make_scene_entry(scene_path)
	var factory: Callable = def.get("factory", Callable())
	if scene_path == "" and (factory == null or not factory.is_valid()):
		_log_error("nodes", "Node '%s' missing packed_scene_path or factory." % node_id)
		_emit_failed(node_id, "missing_factory_or_scene", _extract_mod_id(node_id))
		return {}

	var icon_entry := DEFAULT_ICON
	if def.has("icon_path"):
		var icon_path := _normalize_icon_path(def["icon_path"])
		if icon_path != "" and ResourceLoader.exists(icon_path):
			icon_entry = NodeDefs.make_icon_entry(icon_path)
		else:
			_log_warn("nodes", "Node '%s' icon_path missing: %s" % [node_id, icon_path])
	elif def.has("icon"):
		icon_entry = str(def["icon"])

	var category := str(def.get("category", DEFAULT_CATEGORY))
	var sub_category := str(def.get("sub_category", DEFAULT_SUB_CATEGORY))
	if not _allowed_categories.has(category):
		_log_warn("nodes", "Node '%s' category '%s' is not supported; menu entry may be skipped." % [node_id, category])
	var attributes: Dictionary = def.get("attributes", DEFAULT_ATTRIBUTES).duplicate(true)
	if not attributes.has("limit"):
		attributes["limit"] = -1

	var mod_id := str(def.get("mod_id", _extract_mod_id(node_id)))
	var normalized := {
		"id": node_id,
		"mod_id": mod_id,
		"display_name": display_name,
		"description": str(def.get("description", "")),
		"packed_scene_path": scene_path,
		"scene_entry": scene_entry,
		"icon": icon_entry,
		"category": category,
		"sub_category": sub_category,
		"group": str(def.get("group", "")),
		"level": int(def.get("level", 0)),
		"requirement": str(def.get("requirement", "")),
		"hidden": bool(def.get("hidden", false)),
		"attributes": attributes,
		"data": def.get("data", {}).duplicate(true),
		"guide": str(def.get("guide", "")),
		"tags": def.get("tags", []).duplicate()
	}
	if factory != null and factory.is_valid():
		normalized["factory"] = factory

	if scene_entry != "":
		normalized["window_def"] = {
			"name": display_name,
			"icon": icon_entry,
			"description": normalized["description"],
			"scene": scene_entry,
			"group": normalized["group"],
			"category": category,
			"sub_category": sub_category,
			"level": normalized["level"],
			"requirement": normalized["requirement"],
			"hidden": normalized["hidden"],
			"attributes": attributes,
			"data": normalized["data"],
			"guide": normalized["guide"]
		}

	return normalized

func _window_config_to_def(id: String, config: Dictionary) -> Dictionary:
	if id == "":
		return {}
	var display_name := str(config.get("name", config.get("display_name", "")))
	if display_name == "":
		return {}
	var mod_id := str(config.get("mod_id", _extract_mod_id(id)))
	var scene_path := str(config.get("scene", ""))
	if scene_path != "":
		scene_path = _resolve_mod_path(scene_path, mod_id)
	var icon_value := str(config.get("icon", ""))
	var icon_path := ""
	if icon_value != "":
		if icon_value.begins_with("res://") or icon_value.find("/") != -1:
			icon_path = _resolve_mod_path(icon_value, mod_id)
			icon_value = ""
	var icon_path_override := str(config.get("icon_path", ""))
	if icon_path_override != "":
		icon_path = _resolve_mod_path(icon_path_override, mod_id)
	var def := {
		"id": id,
		"mod_id": mod_id,
		"display_name": display_name,
		"description": str(config.get("description", "")),
		"packed_scene_path": scene_path,
		"category": str(config.get("category", DEFAULT_CATEGORY)),
		"sub_category": str(config.get("sub_category", DEFAULT_SUB_CATEGORY)),
		"group": str(config.get("group", "")),
		"level": int(config.get("level", 0)),
		"requirement": str(config.get("requirement", "")),
		"hidden": bool(config.get("hidden", false)),
		"attributes": config.get("attributes", DEFAULT_ATTRIBUTES).duplicate(true),
		"data": config.get("data", {}).duplicate(true),
		"guide": str(config.get("guide", "")),
		"tags": config.get("tags", []).duplicate()
	}
	if icon_path != "":
		def["icon_path"] = icon_path
	elif icon_value != "":
		def["icon"] = icon_value
	if config.has("factory") and config["factory"] is Callable:
		def["factory"] = config["factory"]
	return def

func _register_data_window(node_id: String, window_def: Dictionary) -> void:
	if not _autoload_ready("Data"):
		_pending_windows.append({"id": node_id, "def": window_def})
		return
	var safe_id := _sanitize_id(node_id)
	Data.windows[safe_id] = window_def.duplicate(true)
	_sync_attributes(safe_id, window_def)
	_sync_globals(safe_id, window_def)
	_log_info("nodes", "Registered node '%s' to Data.windows as '%s'." % [node_id, safe_id])

func process_pending() -> void:
	if not _autoload_ready("Data"):
		return
	if _pending_windows.size() > 0:
		_log_info("nodes", "Processing %d pending node(s)." % _pending_windows.size())
	var queue := _pending_windows.duplicate()
	_pending_windows.clear()
	for item in queue:
		_register_data_window(item["id"], item["def"])
		_try_refresh_menu(item["id"])

func _sync_attributes(safe_id: String, window_def: Dictionary) -> void:
	if not _autoload_ready("Attributes"):
		return
	if Attributes.window_attributes == null:
		Attributes.window_attributes = {}
	if Attributes.window_attributes.has(safe_id):
		return
	Attributes.window_attributes[safe_id] = {}
	for attr_name: String in window_def["attributes"]:
		var value = window_def["attributes"][attr_name]
		Attributes.window_attributes[safe_id][attr_name] = Attribute.new(value)

func _sync_globals(safe_id: String, window_def: Dictionary) -> void:
	if not _autoload_ready("Globals"):
		return
	if Globals.window_count is Dictionary and not Globals.window_count.has(safe_id):
		Globals.window_count[safe_id] = 0
	if Globals.windows_data is Dictionary and not window_def["data"].is_empty():
		if not Globals.windows_data.has(safe_id):
			Globals.windows_data[safe_id] = window_def["data"].duplicate(true)
		else:
			Globals.windows_data[safe_id] = Globals.windows_data[safe_id].merged(window_def["data"].duplicate(true))
	if window_def["group"] != "" and Globals.group_count is Dictionary and not Globals.group_count.has(window_def["group"]):
		Globals.group_count[window_def["group"]] = 0

func _remove_from_attributes(node_id: String) -> void:
	var safe_id := _sanitize_id(node_id)
	if not _autoload_ready("Attributes"):
		return
	if Attributes.window_attributes is Dictionary and Attributes.window_attributes.has(safe_id):
		Attributes.window_attributes.erase(safe_id)

func _remove_from_globals(node_id: String) -> void:
	var safe_id := _sanitize_id(node_id)
	if not _autoload_ready("Globals"):
		return
	if Globals.window_count is Dictionary and Globals.window_count.has(safe_id):
		Globals.window_count.erase(safe_id)
	if Globals.windows_data is Dictionary and Globals.windows_data.has(safe_id):
		Globals.windows_data.erase(safe_id)

func setup_signals() -> void:
	if _patches == null:
		return
	if Signals == null:
		_log_warn("nodes", "Signals autoload missing in setup_signals!")
		return
	_patches.connect_signal_once(Signals, "desktop_ready", Callable(self, "_on_desktop_ready"), "core.nodes.desktop_ready")

func _on_desktop_ready() -> void:
	# Defer by one frame to ensure windows_menu._ready() has fully completed
	# before we modify Data.windows
	(func():
		process_pending()
		refresh_node_catalog()
	).call_deferred()

func _try_refresh_menu(node_id: String) -> void:
	var menu = _find_windows_menu()
	if menu == null:
		return
	if not menu.is_node_ready():
		return
	_add_button_to_menu(menu, node_id)

func _add_button_to_menu(menu: Node, node_id: String) -> bool:
	if not _data_has_window(node_id):
		return false
	var safe_id := _sanitize_id(node_id)
	var win_def: Dictionary = Data.windows.get(safe_id)
	if win_def == null:
		return false
	if not menu.has_node("Categories"):
		return false
	var categories: Node = menu.get_node("Categories")
	if not categories.has_node(win_def["category"]):
		return false
	var category_node: Node = categories.get_node(win_def["category"])
	if not category_node.has_method("get"):
		return false
	var sub_categories: Dictionary = category_node.get("sub_categories")
	if sub_categories == null or not sub_categories.has(win_def["sub_category"]):
		return false
	var sub_node: Node = sub_categories[win_def["sub_category"]]
	if sub_node.has_node(safe_id):
		return false
	var instance: Control = WINDOW_BUTTON_SCENE.instantiate()
	instance.name = safe_id
	instance.selected.connect(Callable(menu, "_on_window_selected"))
	instance.hovered.connect(Callable(menu, "_on_window_hovered"))
	sub_node.add_child(instance)
	if menu.has_signal("window_set"):
		menu.window_set.connect(Callable(instance, "_on_window_set"))
	return true

func _remove_from_menu(node_id: String) -> void:
	var menu = _find_windows_menu()
	if menu == null:
		return
	if not menu.has_node("Categories"):
		return
	var categories: Node = menu.get_node("Categories")
	for category in categories.get_children():
		if not category.has_method("get"):
			continue
		var sub_categories: Dictionary = category.get("sub_categories")
		if sub_categories == null:
			continue
		for sub in sub_categories.values():
			var safe_id := _sanitize_id(node_id)
			if sub.has_node(safe_id):
				sub.get_node(safe_id).queue_free()
				return

func _find_windows_menu():
	var tree = Engine.get_main_loop()
	if not (tree is SceneTree):
		return null
	return _find_node_by_script(tree.get_root(), WINDOW_MENU_SCRIPT)

func _find_node_by_script(node: Node, script_path: String):
	if node == null:
		return null
	var script = node.get_script()
	if script != null and script.resource_path == script_path:
		return node
	for child in node.get_children():
		var found = _find_node_by_script(child, script_path)
		if found != null:
			return found
	return null

func _data_has_window(node_id: String) -> bool:
	return _autoload_ready("Data") and Data.windows.has(_sanitize_id(node_id))

func _get_window_count(node_id: String) -> int:
	var safe_id := _sanitize_id(node_id)
	if not _autoload_ready("Globals"):
		return 0
	if Globals.window_count is Dictionary:
		return int(Globals.window_count.get(safe_id, 0))
	return 0

func _autoload_ready(name: String) -> bool:
	var tree = Engine.get_main_loop()
	if not (tree is SceneTree):
		return false
	return tree.get_root().has_node(name)

func _normalize_scene_path(scene_path: String) -> String:
	var path := str(scene_path)
	if path == "":
		return ""
	if not path.begins_with("res://"):
		return ""
	if not path.ends_with(".tscn"):
		path += ".tscn"
	return path

func _normalize_icon_path(icon_path: String) -> String:
	var path := str(icon_path)
	if path == "":
		return ""
	if not path.begins_with("res://"):
		return ""
	if not path.ends_with(".png"):
		path += ".png"
	return path

func _resolve_mod_path(path: String, mod_id: String) -> String:
	if path.begins_with("res://"):
		return path
	if mod_id == "":
		return path
	return TajsCoreUtil.get_mod_path(mod_id).path_join(path)

func _try_register_resource_icon(resource_id: String, config: Dictionary) -> void:
	if not _autoload_ready("Resources"):
		return
	if Resources.icons == null:
		Resources.icons = {}
	var icon_name := str(config.get("icon", ""))
	var icon_path := str(config.get("icon_path", ""))
	if icon_path == "" and icon_name != "" and icon_name.begins_with("res://"):
		icon_path = icon_name
		icon_name = icon_name.get_file().get_basename()
	if icon_path == "" and icon_name != "":
		icon_path = "res://textures/icons".path_join(icon_name + ".png")
	if icon_name == "":
		icon_name = resource_id
	if icon_path != "" and ResourceLoader.exists(icon_path):
		Resources.icons[icon_name + ".png"] = load(icon_path)

func _is_namespaced_id(node_id: String) -> bool:
	return node_id.find(".") != -1

func _extract_mod_id(node_id: String) -> String:
	var dot := node_id.find(".")
	if dot <= 0:
		return ""
	return node_id.substr(0, dot)

func _track_mod_node(node_id: String, mod_id: String) -> void:
	if mod_id == "":
		return
	if not _mod_nodes.has(mod_id):
		_mod_nodes[mod_id] = []
	_mod_nodes[mod_id].append(node_id)

func _untrack_mod_node(node_id: String) -> void:
	for mod_id in _mod_nodes:
		if _mod_nodes[mod_id].has(node_id):
			_mod_nodes[mod_id].erase(node_id)

func _emit_registered(node_id: String, mod_id: String) -> void:
	if _event_bus != null and _event_bus.has_method("emit"):
		_event_bus.emit("nodes.registered", {"id": node_id, "mod_id": mod_id})

func _emit_failed(node_id: String, reason: String, mod_id: String) -> void:
	if _event_bus != null and _event_bus.has_method("emit"):
		_event_bus.emit("nodes.failed", {"id": node_id, "mod_id": mod_id, "reason": reason})

func _log_info(module_id: String, message: String) -> void:
	if _logger != null and _logger.has_method("info"):
		_logger.info(module_id, message)

func _log_warn(module_id: String, message: String) -> void:
	if _logger != null and _logger.has_method("warn"):
		_logger.warn(module_id, message)

func _log_error(module_id: String, message: String) -> void:
	if _logger != null and _logger.has_method("error"):
		_logger.error(module_id, message)

func _sanitize_id(node_id: String) -> String:
	return node_id.replace(".", "_")
