class_name TajsCoreContextMenuService
extends RefCounted

signal provider_registered(provider_id: String)
signal provider_unregistered(provider_id: String)

const CONTEXT_CANVAS := "canvas"
const CONTEXT_NODE := "node"
const CONTEXT_GROUP := "group_node"
const CONTEXT_STICKY_NOTE := "sticky_note"
const CONTEXT_SELECTION := "selection"
const CONTEXT_UNKNOWN := "unknown"

var _providers: Array = []
var _register_counter: int = 0
var _logger = null
var _event_bus = null

func _init(logger = null, event_bus = null) -> void:
    _logger = logger
    _event_bus = event_bus


func register_provider(provider: Object, provider_id: String = "", priority: int = 0) -> bool:
    if provider == null or not provider.has_method("get_actions"):
        _log_warn("context_menu", "Provider missing get_actions().")
        return false
    if provider_id == "":
        provider_id = _derive_provider_id(provider)
    if _find_provider_index(provider, provider_id) != -1:
        _log_warn("context_menu", "Provider already registered: %s" % provider_id)
        return false
    _providers.append({
        "provider": provider,
        "id": provider_id,
        "priority": int(priority),
        "registered_at": _register_counter
    })
    _register_counter += 1
    provider_registered.emit(provider_id)
    _emit_event("context_menu.provider_registered", {"id": provider_id})
    return true


func unregister_provider(provider_or_id) -> bool:
    var idx := _find_provider_index(provider_or_id, str(provider_or_id))
    if idx == -1:
        return false
    var entry: Dictionary = _providers[idx]
    _providers.remove_at(idx)
    provider_unregistered.emit(entry.get("id", ""))
    _emit_event("context_menu.provider_unregistered", {"id": entry.get("id", "")})
    return true


func list_providers() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for entry in _providers:
        result.append(entry.duplicate(true))
    return result


func resolve_context(data: Dictionary = {}) -> Dictionary:
    var screen_pos: Vector2 = data.get("screen_position", Vector2.ZERO)
    var world_pos: Vector2 = data.get("position", Vector2.ZERO)
    if world_pos == Vector2.ZERO and screen_pos != Vector2.ZERO:
        world_pos = _screen_to_world(screen_pos)
    var target = data.get("target", null)
    var ui_target = data.get("ui_target", target)

    var selection: Array = data.get("selection", _get_selection())
    var connectors: Array = data.get("connectors", _get_connector_selection())
    var selection_count := selection.size()

    var resolved_window = null
    var resolved_note = null
    var context_type := CONTEXT_UNKNOWN

    if target != null:
        var resolved := _resolve_target(target)
        resolved_window = resolved.get("window", null)
        resolved_note = resolved.get("note", null)
        if resolved_window != null:
            context_type = CONTEXT_GROUP if _is_group_window(resolved_window) else CONTEXT_NODE
        elif resolved_note != null:
            context_type = CONTEXT_STICKY_NOTE

    if context_type == CONTEXT_UNKNOWN and world_pos != Vector2.ZERO:
        resolved_window = _find_window_at_position(world_pos)
        if resolved_window != null:
            context_type = CONTEXT_GROUP if _is_group_window(resolved_window) else CONTEXT_NODE
        else:
            resolved_note = _find_sticky_note_at_position(world_pos)
            if resolved_note != null:
                context_type = CONTEXT_STICKY_NOTE

    if context_type == CONTEXT_UNKNOWN:
        if selection_count > 0:
            context_type = CONTEXT_SELECTION
        elif world_pos != Vector2.ZERO or screen_pos != Vector2.ZERO:
            context_type = CONTEXT_CANVAS

    return {
        "type": context_type,
        "position": world_pos,
        "screen_position": screen_pos,
        "target": target,
        "ui_target": ui_target,
        "window": resolved_window,
        "note": resolved_note,
        "selection": selection,
        "selection_count": selection_count,
        "connectors": connectors,
        "has_selection": selection_count > 0
    }


func query_actions(context: Dictionary) -> Array[Dictionary]:
    var merged := {}
    var providers := _providers.duplicate()
    providers.sort_custom(func(a, b): return int(a["priority"]) > int(b["priority"]))

    for entry in providers:
        var provider = entry["provider"]
        if provider == null or not is_instance_valid(provider):
            continue
        if not provider.has_method("get_actions"):
            continue
        var provided = provider.get_actions(context)
        var actions: Array = []
        if provided is Dictionary:
            actions.append(provided)
        elif provided is Array:
            actions = provided
        for raw_action in actions:
            if not (raw_action is Dictionary):
                continue
            var action := _normalize_action(raw_action, entry)
            if action.is_empty():
                continue
            if not _is_visible(action, context):
                continue
            action["enabled"] = _is_enabled(action, context)
            var action_id: String = action["id"]
            if merged.has(action_id):
                var previous: Dictionary = merged[action_id]
                if _should_replace_action(previous, action):
                    merged[action_id] = action
            else:
                merged[action_id] = action

    var result: Array[Dictionary] = []
    for action in merged.values():
        result.append(action)
    result.sort_custom(func(a, b): return _compare_actions(a, b))
    return result


func run_action(action: Dictionary, context: Dictionary) -> bool:
    if action.is_empty():
        return false
    if not _is_visible(action, context):
        return false
    if not _is_enabled(action, context):
        return false
    var run_func: Callable = action.get("run", Callable())
    if not run_func.is_valid():
        _log_warn("context_menu", "Action has no run(): %s" % action.get("id", ""))
        return false
    var result = run_func.call(context)
    if typeof(result) == TYPE_INT and int(result) != OK:
        return false
    return true


func run_action_by_id(action_id: String, context: Dictionary) -> bool:
    if action_id == "":
        return false
    for action in query_actions(context):
        if action.get("id", "") == action_id:
            return run_action(action, context)
    return false


func _normalize_action(raw_action: Dictionary, provider_entry: Dictionary) -> Dictionary:
    var id := str(raw_action.get("id", "")).strip_edges()
    if id == "":
        return {}
    var title := str(raw_action.get("title", raw_action.get("label", ""))).strip_edges()
    if title == "":
        title = id
    var action: Dictionary = raw_action.duplicate(true)
    action["id"] = id
    action["title"] = title
    action["priority"] = int(action.get("priority", 0))
    action["order"] = int(action.get("order", 0))
    action["category_path"] = _normalize_category_path(action.get("category_path", action.get("path", [])))
    if not action.has("run"):
        action["run"] = Callable()
    if not action.has("is_visible"):
        action["is_visible"] = Callable()
    if not action.has("is_enabled"):
        action["is_enabled"] = Callable()
    action["_provider_id"] = provider_entry.get("id", "")
    action["_provider_priority"] = provider_entry.get("priority", 0)
    action["_provider_order"] = provider_entry.get("registered_at", 0)
    return action


func _normalize_category_path(value: Variant) -> Array[String]:
    var result: Array[String] = []
    if value is Array:
        for entry in value:
            var text := str(entry).strip_edges()
            if text != "":
                result.append(text)
    elif value is String:
        var text := str(value).strip_edges()
        if text != "":
            result.append(text)
    return result


func _is_visible(action: Dictionary, context: Dictionary) -> bool:
    if bool(action.get("hidden", false)):
        return false
    var is_visible_func: Callable = action.get("is_visible", Callable())
    if is_visible_func.is_valid():
        return bool(is_visible_func.call(context))
    if action.has("visible"):
        return bool(action.get("visible", true))
    return true


func _is_enabled(action: Dictionary, context: Dictionary) -> bool:
    var enabled_func: Callable = action.get("is_enabled", Callable())
    if not enabled_func.is_valid():
        enabled_func = action.get("can_run", Callable())
    if enabled_func.is_valid():
        return bool(enabled_func.call(context))
    if action.has("enabled"):
        return bool(action.get("enabled", true))
    return true


func _compare_actions(a: Dictionary, b: Dictionary) -> bool:
    var pa: int = int(a.get("priority", 0))
    var pb: int = int(b.get("priority", 0))
    if pa != pb:
        return pa > pb
    var oa: int = int(a.get("order", 0))
    var ob: int = int(b.get("order", 0))
    if oa != ob:
        return oa < ob
    var ta: String = str(a.get("title", a.get("id", "")))
    var tb: String = str(b.get("title", b.get("id", "")))
    if ta != tb:
        return ta < tb
    return int(a.get("_provider_order", 0)) < int(b.get("_provider_order", 0))


func _should_replace_action(previous: Dictionary, candidate: Dictionary) -> bool:
    var prev_priority: int = int(previous.get("priority", 0))
    var new_priority: int = int(candidate.get("priority", 0))
    if new_priority != prev_priority:
        return new_priority > prev_priority
    var prev_provider_priority: int = int(previous.get("_provider_priority", 0))
    var new_provider_priority: int = int(candidate.get("_provider_priority", 0))
    if new_provider_priority != prev_provider_priority:
        return new_provider_priority > prev_provider_priority
    return int(candidate.get("_provider_order", 0)) < int(previous.get("_provider_order", 0))


func _resolve_target(target) -> Dictionary:
    var node: Variant = target
    while node != null and node is Node:
        if node is WindowContainer:
            return {"window": node}
        if _is_sticky_note(node):
            return {"note": node}
        node = node.get_parent()
    return {}


func _find_window_at_position(world_pos: Vector2):
    var tree := _get_tree()
    if tree == null:
        return null
    var best = null
    var best_z := -99999
    var best_index := -99999
    var nodes = tree.get_nodes_in_group("selectable")
    for node in nodes:
        if not (node is WindowContainer):
            continue
        if not is_instance_valid(node):
            continue
        var rect: Rect2 = node.get_global_rect()
        if not rect.has_point(world_pos):
            continue
        var z := int(node.z_index)
        var idx := int(node.get_index())
        if z > best_z or (z == best_z and idx > best_index):
            best = node
            best_z = z
            best_index = idx
    return best


func _find_sticky_note_at_position(world_pos: Vector2):
    var tree := _get_tree()
    if tree == null:
        return null
    var notes: Array = tree.get_nodes_in_group("tajs_sticky_note")
    if notes.is_empty():
        var desktop = _get_desktop()
        if desktop != null:
            var container = desktop.get_node_or_null("StickyNotesContainer")
            if container != null:
                notes = container.get_children()
    for note in notes:
        if not (note is Control):
            continue
        if not is_instance_valid(note):
            continue
        var rect: Rect2 = note.get_global_rect()
        if rect.has_point(world_pos):
            return note
    return null


func _is_group_window(window: WindowContainer) -> bool:
    if window == null:
        return false
    if window.has_method("get") and window.get("window") == "group":
        return true
    if window.has_method("get") and window.get("window_id") == "group":
        return true
    if window.get_class() == "NodeGroup":
        return true
    var script = window.get_script()
    if script:
        var script_path: String = script.resource_path if script.resource_path else ""
        if "group" in script_path.to_lower():
            return true
    var window_name: String = str(window.name)
    if window_name.begins_with("group") and window_name.substr(5).is_valid_int():
        return true
    return false


func _is_sticky_note(node: Node) -> bool:
    if node == null:
        return false
    if node.is_class("TajsStickyNote"):
        return true
    if node.is_in_group("tajs_sticky_note"):
        return true
    var script = node.get_script()
    if script:
        var script_path: String = script.resource_path if script.resource_path else ""
        if "sticky_note" in script_path.to_lower():
            return true
    return false


func _screen_to_world(screen_pos: Vector2) -> Vector2:
    if _has_autoload("Utils") and Utils.has_method("screen_to_world_pos"):
        return Utils.screen_to_world_pos(screen_pos)
    return screen_pos


func _get_selection() -> Array:
    if Globals != null and "selections" in Globals:
        return Globals.selections
    return []


func _get_connector_selection() -> Array:
    if Globals != null and "connector_selection" in Globals:
        return Globals.connector_selection
    return []


func _get_desktop() -> Node:
    if Globals != null and "desktop" in Globals:
        return Globals.desktop
    return null


func _get_tree() -> SceneTree:
    var loop = Engine.get_main_loop()
    return loop if loop is SceneTree else null


func _find_provider_index(provider_or_id, provider_id: String) -> int:
    for i in range(_providers.size()):
        var entry: Dictionary = _providers[i]
        if provider_or_id is Object and entry.get("provider", null) == provider_or_id:
            return i
        if provider_id != "" and entry.get("id", "") == provider_id:
            return i
    return -1


func _derive_provider_id(provider: Object) -> String:
    if provider == null:
        return "unknown"
    if provider.has_method("get_id"):
        var pid = str(provider.get_id()).strip_edges()
        if pid != "":
            return pid
    if "name" in provider:
        var name_val = str(provider.name).strip_edges()
        if name_val != "":
            return name_val
    return "provider_%d" % _register_counter


func _has_autoload(name: String) -> bool:
    if Engine.has_singleton(name):
        return true
    var tree = Engine.get_main_loop()
    if not (tree is SceneTree):
        return false
    return tree.get_root().has_node(name)


func _emit_event(event_name: String, data: Dictionary) -> void:
    if _event_bus == null:
        return
    if _event_bus.has_method("emit_event"):
        _event_bus.emit_event(event_name, "core", data, false)
    elif _event_bus.has_method("emit"):
        _event_bus.emit(event_name, {"source": "core", "timestamp": Time.get_unix_time_from_system(), "data": data})


func _log_warn(module_id: String, message: String) -> void:
    if _logger != null and _logger.has_method("warn"):
        _logger.warn(module_id, message)


func _log_debug(message: String) -> void:
    if _logger != null and _logger.has_method("info"):
        _logger.info("TajsCore:ContextMenu", message)
