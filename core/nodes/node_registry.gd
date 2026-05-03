class_name TajsCoreNodeRegistry
extends RefCounted

## Public node/window/resource registry used by mods to contribute runtime content.
##
## Most mods should prefer [method TajsCoreRuntime.register_window_tab] and
## [method TajsCoreRuntime.register_file_variation] wrappers when possible.
const DEFAULT_ICON := "question_mark"
const DEFAULT_CATEGORY := "utility"
const DEFAULT_SUB_CATEGORY := "file"
const DEFAULT_ATTRIBUTES := {"limit": - 1}
const WINDOW_BUTTON_SCENE := preload("res://scenes/window_button.tscn")
const WINDOW_MENU_SCRIPT := "res://scripts/windows_menu.gd"
const NodeDefs := preload("res://mods-unpacked/TajemnikTV-Core/core/nodes/node_defs.gd")

var _allowed_categories: Array[String] = ["network", "cpu", "gpu", "research", "ai", "hacking", "factory", "power", "coding", "utility"]

var _nodes: Dictionary = {}
var _mod_nodes: Dictionary = {}
var _pending_windows: Array = []
var _resource_types: Dictionary = {}
var _file_types: Dictionary = {}
var _window_categories: Dictionary = {}
var _category_items: Dictionary = {}
var _logger: Variant
var _event_bus: Variant
var _patches: Variant

func _init(logger: Variant = null, event_bus: Variant = null, patches: Variant = null) -> void:
    _logger = logger
    _event_bus = event_bus
    _patches = patches

## Registers a full node definition.
##
## Expected id format: [code]ModId.local_id[/code].
## Required keys:
## - [code]id[/code] String (namespaced)
## - [code]display_name[/code] String
## - one of:
##   - [code]packed_scene_path[/code] String ([code]res://...[/code], [code].tscn[/code] inferred)
##   - [code]factory[/code] Callable
## Optional keys (with defaults):
## - [code]description[/code] String (default: "")
## - [code]category[/code] String (default: [constant DEFAULT_CATEGORY])
## - [code]sub_category[/code] String (default: [constant DEFAULT_SUB_CATEGORY])
## - [code]icon[/code] String (default: [constant DEFAULT_ICON])
## - [code]icon_path[/code] String ([code].png[/code] inferred)
## - [code]attributes[/code] Dictionary (default: [code]{"limit": -1}[/code])
## - [code]data[/code] Dictionary (default: {})
## - [code]group[/code], [code]level[/code], [code]requirement[/code], [code]hidden[/code], [code]guide[/code], [code]tags[/code]
## Example:
## [codeblock]
## core.nodes.register_node({
##     "id": "TajemnikTV-QoL.quick_tool",
##     "display_name": "Quick Tool",
##     "packed_scene_path": "res://mods-unpacked/TajemnikTV-QoL/scenes/quick_tool.tscn",
##     "category": "utility",
##     "sub_category": "file",
##     "attributes": {"limit": 1}
## })
## [/codeblock]
## Return value:
## - [code]true[/code] on successful registration
## - [code]false[/code] when validation fails or id conflicts
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

## Convenience wrapper for window config contribution.
func register_window_type(id: String, config: Dictionary) -> bool:
    var def := _window_config_to_def(id, config)
    if def.is_empty():
        return false
    return register_node(def)

## Unregisters previously registered node/window type.
func unregister_window_type(id: String) -> bool:
    return unregister_node(id)

## Returns registered node definition for id.
func get_window_config(id: String) -> Dictionary:
    return get_node_def(id)

## Lists all registered window type ids.
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

## Registers a Data.resources entry and optional icon contribution.
func register_resource_type(id: String, config: Dictionary) -> bool:
    if id == "":
        return false
    if not _autoload_ready("Data"):
        return false
    Data.resources[id] = config.duplicate(true)
    _resource_types[id] = config.duplicate(true)
    _try_register_resource_icon(id, config)
    return true

## Registers a Data.files entry.
func register_file_type(id: String, config: Dictionary) -> bool:
    if id == "":
        return false
    if not _autoload_ready("Data"):
        return false
    Data.files[id] = config.duplicate(true)
    _file_types[id] = config.duplicate(true)
    return true

## Registers a custom category metadata entry.
func register_window_category(id: String, label: String, icon: String, position: int = -1) -> bool:
    if id == "":
        return false
    _window_categories[id] = {"label": label, "icon": icon, "position": position}
    if not _allowed_categories.has(id):
        _allowed_categories.append(id)
    _log_warn("nodes", "Registered custom window category '%s'; UI injection may require custom scenes." % id)
    return true

## Adds a window id to a logical category grouping.
func add_to_window_category(category_id: String, window_id: String, position: int = -1) -> bool:
    if category_id == "" or window_id == "":
        return false
    if not _category_items.has(category_id):
        _category_items[category_id] = []
    _category_items[category_id].append({"id": window_id, "position": position})
    return true

## Unregisters node and removes related runtime/global entries when safe.
func unregister_node(node_id: String) -> bool:
    if not _nodes.has(node_id):
        return false
    if _data_has_window(node_id):
        var count: int = _get_window_count(node_id)
        if count > 0:
            _log_warn("nodes", "Node '%s' has active windows; unregister blocked." % node_id)
            return false
        var _ignored: Variant = Data.windows.erase(node_id)
        _remove_from_attributes(node_id)
        _remove_from_globals(node_id)
        _remove_from_menu(node_id)
    var _ignored: Variant = _nodes.erase(node_id)
    _untrack_mod_node(node_id)
    return true

## Returns defensive copy of node definition.
func get_node_def(node_id: String) -> Dictionary:
    if not _nodes.has(node_id):
        return {}
    return _nodes[node_id].duplicate(true)

## Lists registered nodes with optional filtering by mod/category/tag(s).
func list_nodes(filter: Dictionary = {}) -> Array[Dictionary]:
    var results: Array[Dictionary] = []
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
            for tag: Variant in required:
                if not tags_list.has(tag):
                    ok = false
                    break
            if not ok:
                continue
        results.append(entry.duplicate(true))
    return results

func refresh_node_catalog() -> bool:
    var menu: Variant = _find_windows_menu()
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

## Returns mapping of mod_id -> node id list.
func get_mod_nodes() -> Dictionary:
    var result := {}
    for mod_id: Variant in _mod_nodes:
        result[mod_id] = _mod_nodes[mod_id].duplicate()
    return result

## Returns total number of tracked mod node registrations.
func get_mod_node_count() -> int:
    var count := 0
    for mod_id: Variant in _mod_nodes:
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
    for item: Variant in queue:
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
        var value: Variant = window_def["attributes"][attr_name]
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
        var _ignored: Variant = Attributes.window_attributes.erase(safe_id)

func _remove_from_globals(node_id: String) -> void:
    var safe_id := _sanitize_id(node_id)
    if not _autoload_ready("Globals"):
        return
    if Globals.window_count is Dictionary and Globals.window_count.has(safe_id):
        var _ignored: Variant = Globals.window_count.erase(safe_id)
    if Globals.windows_data is Dictionary and Globals.windows_data.has(safe_id):
        var _ignored: Variant = Globals.windows_data.erase(safe_id)

func setup_signals() -> void:
    if _patches == null:
        return
    if Signals == null:
        _log_warn("nodes", "Signals autoload missing in setup_signals!")
        return
    _patches.connect_signal_once(Signals, "desktop_ready", Callable(self , "_on_desktop_ready"), "core.nodes.desktop_ready")

func _on_desktop_ready() -> void:
    # Defer by one frame to ensure windows_menu._ready() has fully completed
    # before we modify Data.windows
    (func():
        process_pending()
        var _ignored: Variant = refresh_node_catalog()
    ).call_deferred()

func _try_refresh_menu(node_id: String) -> void:
    var menu: Variant = _find_windows_menu()
    if menu == null:
        _log_debug("nodes", "Node menu refresh skipped for '%s': windows_menu_not_found" % node_id)
        return
    if not menu.is_node_ready():
        _log_debug("nodes", "Node menu refresh skipped for '%s': windows_menu_not_ready" % node_id)
        return
    var _ignored: Variant = _add_button_to_menu(menu, node_id)

func _add_button_to_menu(menu: Node, node_id: String) -> bool:
    if not _data_has_window(node_id):
        _log_debug("nodes", "Node menu add failed for '%s': missing_data_windows_entry" % node_id)
        return false
    var safe_id := _sanitize_id(node_id)
    var win_def: Dictionary = Data.windows.get(safe_id)
    if win_def == null:
        _log_debug("nodes", "Node menu add failed for '%s': missing_data_windows_entry" % node_id)
        return false
    var target_info: Dictionary = _find_target_container(menu, win_def)
    var sub_node: Node = target_info.get("node", null)
    if sub_node == null:
        _log_debug("nodes", "Node menu add failed for '%s': %s" % [node_id, str(target_info.get("reason", "missing_container"))])
        return false
    if sub_node.has_node(safe_id):
        _log_debug("nodes", "Node menu add failed for '%s': duplicate_existing_button" % node_id)
        return false
    var instance: Control = WINDOW_BUTTON_SCENE.instantiate()
    instance.name = safe_id
    var windows_tab: Node = _get_windows_tab_node(menu)
    var selection_target: Node = windows_tab if windows_tab != null else menu
    if selection_target == null:
        _log_debug("nodes", "Node menu add failed for '%s': missing_callback_target" % node_id)
        return false
    var has_selected_callback: bool = selection_target.has_method("_on_window_selected")
    var has_hovered_callback: bool = selection_target.has_method("_on_window_hovered")
    if not has_selected_callback or not has_hovered_callback:
        _log_debug("nodes", "Node menu add failed for '%s': missing_callback_target" % node_id)
        return false
    if selection_target != null and selection_target.has_method("_on_window_selected"):
        instance.get("selected").connect(Callable(selection_target, "_on_window_selected"))
    if selection_target != null and selection_target.has_method("_on_window_hovered"):
        instance.get("hovered").connect(Callable(selection_target, "_on_window_hovered"))
    sub_node.add_child(instance)
    var window_set_owner: Node = windows_tab if windows_tab != null else menu
    if window_set_owner == null:
        _log_debug("nodes", "Node menu add failed for '%s': failed_signal_connection" % node_id)
        instance.queue_free()
        return false
    if window_set_owner.has_signal("window_set"):
        window_set_owner.get("window_set").connect(Callable(instance, "_on_window_set"))
    else:
        _log_debug("nodes", "Node menu add failed for '%s': failed_signal_connection" % node_id)
        instance.queue_free()
        return false
    _log_debug("nodes", "Node menu add succeeded for '%s': mode=%s container=%s" % [
        node_id,
        str(target_info.get("mode", "unknown")),
        str(sub_node.get_path())
    ])
    return true

func _remove_from_menu(node_id: String) -> void:
    var menu: Variant = _find_windows_menu()
    if menu == null:
        return
    var safe_id := _sanitize_id(node_id)
    if menu.has_node("Categories"):
        var categories: Node = menu.get_node("Categories")
        for category: Variant in categories.get_children():
            if not category.has_method("get"):
                continue
            var sub_categories: Dictionary = category.get("sub_categories")
            if sub_categories == null:
                continue
            for sub: Variant in sub_categories.values():
                if sub.has_node(safe_id):
                    sub.get_node(safe_id).queue_free()
                    return
    var categories_container: Node = _get_windows_categories_container(menu)
    if categories_container == null:
        return
    for category_panel: Variant in categories_container.get_children():
        if category_panel != null and category_panel.has_node(safe_id):
            category_panel.get_node(safe_id).queue_free()
            return

func _find_windows_menu() -> Variant:
    var tree: Variant = Engine.get_main_loop()
    if not (tree is SceneTree):
        _log_debug("nodes", "WindowsMenu lookup failed: no_scene_tree")
        return null
    var menu: Variant = _find_node_by_script(tree.get_root(), WINDOW_MENU_SCRIPT)
    if menu == null:
        _log_debug("nodes", "WindowsMenu lookup failed: script_not_found")
    else:
        _log_debug("nodes", "WindowsMenu lookup succeeded: %s" % str(menu.get_path()))
    return menu

func _find_node_by_script(node: Node, script_path: String) -> Variant:
    if node == null:
        return null
    var script: Variant = node.get_script()
    if script != null and script.resource_path == script_path:
        return node
    for child: Variant in node.get_children():
        var found: Variant = _find_node_by_script(child, script_path)
        if found != null:
            return found
    return null

func _find_target_container(menu: Node, win_def: Dictionary) -> Dictionary:
    if menu.has_node("Categories"):
        var categories: Node = menu.get_node("Categories")
        if not categories.has_node(win_def["category"]):
            return {"node": null, "mode": "legacy", "reason": "missing_category"}
        if categories.has_node(win_def["category"]):
            var category_node: Node = categories.get_node(win_def["category"])
            if category_node.has_method("get"):
                var sub_categories: Dictionary = category_node.get("sub_categories")
                if sub_categories != null and sub_categories.has(win_def["sub_category"]):
                    return {"node": sub_categories[win_def["sub_category"]], "mode": "legacy", "reason": ""}
                return {"node": null, "mode": "legacy", "reason": "missing_subcategory_container"}
            return {"node": null, "mode": "legacy", "reason": "missing_subcategory_container"}
    var categories_container: Node = _get_windows_categories_container(menu)
    if categories_container == null:
        var has_legacy: bool = menu.has_node("Categories")
        return {"node": null, "mode": "none", "reason": "missing_categories_container" if not has_legacy else "missing_subcategory_container"}
    var category_map := {
        "network": "Network",
        "cpu": "CPU",
        "gpu": "GPU",
        "research": "Research",
        "ai": "AI",
        "factory": "Factory",
        "power": "Power",
        "hacking": "Hacking",
        "coding": "Coding",
        "utility": "Utilities"
    }
    var category_id: String = str(win_def.get("category", ""))
    var category_name: String = category_map.get(category_id, category_id.capitalize())
    var container: Node = categories_container.get_node_or_null(category_name)
    if container == null:
        return {"node": null, "mode": "picker22", "reason": "missing_category"}
    return {"node": container, "mode": "picker22", "reason": ""}

func _get_windows_tab_node(menu: Node) -> Node:
    return menu.get_node_or_null("VBoxContainer/WindowsPanel/MainContainer/TabContainer/Windows")

func _get_windows_categories_container(menu: Node) -> Node:
    var windows_tab: Node = _get_windows_tab_node(menu)
    if windows_tab == null:
        return null
    return windows_tab.get_node_or_null("WindowsContainer/ScrollContainer/MarginContainer/CategoriesContainer")

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
    var tree: Variant = Engine.get_main_loop()
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
    return _get_mod_path(mod_id).path_join(path)

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
    for mod_id: Variant in _mod_nodes:
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

func _log_debug(module_id: String, message: String) -> void:
    if _logger != null and _logger.has_method("debug"):
        _logger.debug(module_id, message)

func _sanitize_id(node_id: String) -> String:
    return node_id.replace(".", "_")


func _get_mod_path(mod_id: String) -> String:
    if mod_id == "":
        return ""
    if _has_global_class("ModLoaderMod"):
        return ModLoaderMod.get_unpacked_dir().path_join(mod_id)
    return "res://mods-unpacked".path_join(mod_id)


func _has_global_class(class_name_str: String) -> bool:
    for entry: Variant in ProjectSettings.get_global_class_list():
        if entry.get("class", "") == class_name_str:
            return true
    return false
