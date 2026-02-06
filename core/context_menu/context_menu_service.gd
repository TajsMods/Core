class_name TajsCoreContextMenuService
extends RefCounted

signal provider_registered(provider_id: String)
signal provider_unregistered(provider_id: String)

const CONTEXT_CANVAS: String = "canvas"
const CONTEXT_NODE: String = "node"
const CONTEXT_GROUP: String = "group_node"
const CONTEXT_STICKY_NOTE: String = "sticky_note"
const CONTEXT_SELECTION: String = "selection"
const CONTEXT_UNKNOWN: String = "unknown"

var _providers: Array = []
var _register_counter: int = 0
var _logger: Variant = null
var _event_bus: Variant = null

func _init(logger: Variant = null, event_bus: Variant = null) -> void:
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


func unregister_provider(provider_or_id: Variant) -> bool:
    var idx: int = _find_provider_index(provider_or_id, str(provider_or_id))
    if idx == -1:
        return false
    var entry: Dictionary = _providers[idx]
    _providers.remove_at(idx)
    provider_unregistered.emit(entry.get("id", ""))
    _emit_event("context_menu.provider_unregistered", {"id": entry.get("id", "")})
    return true


func list_providers() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for entry: Variant in _providers:
        if entry is Dictionary:
            var entry_dict: Dictionary = entry
            result.append(entry_dict.duplicate(true))
    return result


func resolve_context(data: Dictionary = {}) -> Dictionary:
    var screen_pos: Vector2 = data.get("screen_position", Vector2.ZERO)
    var world_pos: Vector2 = data.get("position", Vector2.ZERO)
    if world_pos == Vector2.ZERO and screen_pos != Vector2.ZERO:
        world_pos = _screen_to_world(screen_pos)
    var target: Variant = data.get("target", null)
    var ui_target: Variant = data.get("ui_target", target)

    var selection: Array = data.get("selection", _get_selection())
    var connectors: Array = data.get("connectors", _get_connector_selection())
    var selection_count: int = selection.size()

    var resolved_window: Variant = null
    var resolved_note: Variant = null
    var context_type: String = CONTEXT_UNKNOWN

    if target != null:
        var resolved: Dictionary = _resolve_target(target)
        resolved_window = resolved.get("window", null)
        resolved_note = resolved.get("note", null)
        if resolved_window != null:
            if resolved_window is WindowContainer:
                var window_instance: WindowContainer = resolved_window
                context_type = CONTEXT_GROUP if _is_group_window(window_instance) else CONTEXT_NODE
        elif resolved_note != null:
            context_type = CONTEXT_STICKY_NOTE

    if context_type == CONTEXT_UNKNOWN and world_pos != Vector2.ZERO:
        resolved_window = _find_window_at_position(world_pos)
        if resolved_window != null:
            if resolved_window is WindowContainer:
                var window_instance: WindowContainer = resolved_window
                context_type = CONTEXT_GROUP if _is_group_window(window_instance) else CONTEXT_NODE
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
    var merged: Dictionary = {}
    var providers: Array = _providers.duplicate()
    providers.sort_custom(func(a: Variant, b: Variant) -> bool:
        if not (a is Dictionary and b is Dictionary):
            return false
        var a_dict: Dictionary = a
        var b_dict: Dictionary = b
        var a_priority: int = a_dict.get("priority", 0)
        var b_priority: int = b_dict.get("priority", 0)
        return a_priority > b_priority
    )

    for entry: Variant in providers:
        if not (entry is Dictionary):
            continue
        var entry_dict: Dictionary = entry
        var provider: Variant = entry_dict["provider"]
        if provider == null or not is_instance_valid(provider):
            continue
        @warning_ignore("unsafe_method_access", "unsafe_cast")
        if not (typeof(provider) == TYPE_OBJECT) or not (provider as Object).has_method("get_actions"):
            continue
        @warning_ignore("unsafe_method_access", "unsafe_cast")
        var provided: Variant = (provider as Object).call("get_actions", context)
        var actions: Array = []
        if provided is Dictionary:
            actions.append(provided)
        elif provided is Array:
            actions = provided
        for raw_action: Variant in actions:
            if not (raw_action is Dictionary):
                continue
            var raw_dict: Dictionary = raw_action
            var action: Dictionary = _normalize_action(raw_dict, entry_dict)
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
    for action: Variant in merged.values():
        result.append(action)
    result.sort_custom(func(a: Variant, b: Variant) -> bool:
        if not (a is Dictionary and b is Dictionary):
            return false
        var a_dict: Dictionary = a
        var b_dict: Dictionary = b
        return _compare_actions(a_dict, b_dict)
    )
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
    var result: Variant = run_func.call(context)
    if typeof(result) == TYPE_INT:
        var result_code: int = result
        if result_code != OK:
            return false
    return true


func run_action_by_id(action_id: String, context: Dictionary) -> bool:
    if action_id == "":
        return false
    for action: Variant in query_actions(context):
        if action is Dictionary:
            var action_dict: Dictionary = action
            if action_dict.get("id", "") == action_id:
                return run_action(action_dict, context)
    return false


func _normalize_action(raw_action: Dictionary, provider_entry: Dictionary) -> Dictionary:
    var id: String = str(raw_action.get("id", "")).strip_edges()
    if id == "":
        return {}
    var title: String = str(raw_action.get("title", raw_action.get("label", ""))).strip_edges()
    if title == "":
        title = id
    var action: Dictionary = raw_action.duplicate(true)
    action["id"] = id
    action["title"] = title
    var priority_val: Variant = action.get("priority", 0)
    action["priority"] = priority_val if typeof(priority_val) == TYPE_INT else 0
    var order_val: Variant = action.get("order", 0)
    action["order"] = order_val if typeof(order_val) == TYPE_INT else 0
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
        for entry: Variant in value:
            var text: String = str(entry).strip_edges()
            if text != "":
                result.append(text)
    elif value is String:
        var text: String = str(value).strip_edges()
        if text != "":
            result.append(text)
    return result


func _is_visible(action: Dictionary, context: Dictionary) -> bool:
    var hidden_val: Variant = action.get("hidden", false)
    if hidden_val:
        return false
    var is_visible_func: Callable = action.get("is_visible", Callable())
    if is_visible_func.is_valid():
        var vis_result: Variant = is_visible_func.call(context)
        return true if vis_result else false
    if action.has("visible"):
        var visible_val: Variant = action.get("visible", true)
        return true if visible_val else false
    return true


func _is_enabled(action: Dictionary, context: Dictionary) -> bool:
    var enabled_func: Callable = action.get("is_enabled", Callable())
    if not enabled_func.is_valid():
        enabled_func = action.get("can_run", Callable())
    if enabled_func.is_valid():
        var enabled_result: Variant = enabled_func.call(context)
        return true if enabled_result else false
    if action.has("enabled"):
        var enabled_val: Variant = action.get("enabled", true)
        return true if enabled_val else false
    return true


func _compare_actions(a: Dictionary, b: Dictionary) -> bool:
    var pa_val: Variant = a.get("priority", 0)
    var pa: int = pa_val if typeof(pa_val) == TYPE_INT else 0
    var pb_val: Variant = b.get("priority", 0)
    var pb: int = pb_val if typeof(pb_val) == TYPE_INT else 0
    if pa != pb:
        return pa > pb
    var oa_val: Variant = a.get("order", 0)
    var oa: int = oa_val if typeof(oa_val) == TYPE_INT else 0
    var ob_val: Variant = b.get("order", 0)
    var ob: int = ob_val if typeof(ob_val) == TYPE_INT else 0
    if oa != ob:
        return oa < ob
    var ta: String = str(a.get("title", a.get("id", "")))
    var tb: String = str(b.get("title", b.get("id", "")))
    if ta != tb:
        return ta < tb
    var a_order_val: Variant = a.get("_provider_order", 0)
    var a_order: int = a_order_val if typeof(a_order_val) == TYPE_INT else 0
    var b_order_val: Variant = b.get("_provider_order", 0)
    var b_order: int = b_order_val if typeof(b_order_val) == TYPE_INT else 0
    return a_order < b_order


func _should_replace_action(previous: Dictionary, candidate: Dictionary) -> bool:
    var prev_priority_val: Variant = previous.get("priority", 0)
    var prev_priority: int = prev_priority_val if typeof(prev_priority_val) == TYPE_INT else 0
    var new_priority_val: Variant = candidate.get("priority", 0)
    var new_priority: int = new_priority_val if typeof(new_priority_val) == TYPE_INT else 0
    if new_priority != prev_priority:
        return new_priority > prev_priority
    var prev_provider_priority_val: Variant = previous.get("_provider_priority", 0)
    var prev_provider_priority: int = prev_provider_priority_val if typeof(prev_provider_priority_val) == TYPE_INT else 0
    var new_provider_priority_val: Variant = candidate.get("_provider_priority", 0)
    var new_provider_priority: int = new_provider_priority_val if typeof(new_provider_priority_val) == TYPE_INT else 0
    if new_provider_priority != prev_provider_priority:
        return new_provider_priority > prev_provider_priority
    var cand_order_val: Variant = candidate.get("_provider_order", 0)
    var cand_order: int = cand_order_val if typeof(cand_order_val) == TYPE_INT else 0
    var prev_order_val: Variant = previous.get("_provider_order", 0)
    var prev_order: int = prev_order_val if typeof(prev_order_val) == TYPE_INT else 0
    return cand_order < prev_order


func _resolve_target(target: Variant) -> Dictionary:
    var node: Variant = target
    while node != null and node is Node:
        if node is WindowContainer:
            return {"window": node}
        var node_obj: Node = node
        if _is_sticky_note(node_obj):
            return {"note": node}
        node = node_obj.get_parent()
    return {}


@warning_ignore("unsafe_method_access")
func _find_window_at_position(world_pos: Vector2) -> Variant:
    var tree: SceneTree = _get_tree()
    if tree == null:
        return null
    var best: Variant = null
    var best_z: int = -99999
    var best_index: int = -99999
    var nodes: Variant = tree.get_nodes_in_group("selectable")
    for node: Variant in nodes:
        if not (node is WindowContainer):
            continue
        if not is_instance_valid(node):
            continue
        var window: WindowContainer = node
        var rect: Rect2 = window.get_global_rect()
        if not rect.has_point(world_pos):
            continue
        var z_val: Variant = window.get("z_index")
        var z: int = z_val if typeof(z_val) == TYPE_INT else 0
        var idx_val: Variant = window.call("get_index")
        var idx: int = idx_val if typeof(idx_val) == TYPE_INT else 0
        if z > best_z or (z == best_z and idx > best_index):
            best = node
            best_z = z
            best_index = idx
    return best


@warning_ignore("unsafe_method_access")
func _find_sticky_note_at_position(world_pos: Vector2) -> Variant:
    var tree: SceneTree = _get_tree()
    if tree == null:
        return null
    var notes: Array = tree.get_nodes_in_group("tajs_sticky_note")
    if notes.is_empty():
        var desktop: Variant = _get_desktop()
        if desktop != null and typeof(desktop) == TYPE_OBJECT:
            var desktop_obj: Object = desktop
            if desktop_obj.has_method("get_node_or_null"):
                var container: Variant = desktop_obj.call("get_node_or_null", "StickyNotesContainer")
                if container != null and typeof(container) == TYPE_OBJECT:
                    var container_obj: Object = container
                    if container_obj.has_method("get_children"):
                        notes = container_obj.call("get_children")
    for note: Variant in notes:
        if not (note is Control):
            continue
        if not is_instance_valid(note):
            continue
        var note_ctrl: Control = note
        var rect: Rect2 = note_ctrl.get_global_rect()
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
    var script: Variant = window.get_script()
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
    var script: Variant = node.get_script()
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
    var loop: Variant = Engine.get_main_loop()
    return loop if loop is SceneTree else null


func _find_provider_index(provider_or_id: Variant, provider_id: String) -> int:
    for i: Variant in range(_providers.size()):
        var entry: Dictionary = _providers[i]
        if provider_or_id is Object and entry.get("provider", null) == provider_or_id:
            return i
        if provider_id != "" and entry.get("id", "") == provider_id:
            return i
    return -1


@warning_ignore("unsafe_method_access")
func _derive_provider_id(provider: Object) -> String:
    if provider == null:
        return "unknown"
    if provider.has_method("get_id"):
        var pid_val: Variant = provider.call("get_id")
        var pid: String = str(pid_val).strip_edges()
        if pid != "":
            return pid
    if "name" in provider:
        var name_val: Variant = provider.get("name")
        var name_str: String = str(name_val).strip_edges()
        if name_str != "":
            return name_str
    return "provider_%d" % _register_counter


@warning_ignore("unsafe_method_access")
func _has_autoload(name: String) -> bool:
    if Engine.has_singleton(name):
        return true
    var tree: Variant = Engine.get_main_loop()
    if not (tree is SceneTree):
        return false
    var scene_tree: SceneTree = tree
    return scene_tree.get_root().has_node(name)


@warning_ignore("unsafe_method_access")
func _emit_event(event_name: String, data: Dictionary) -> void:
    if _event_bus == null:
        return
    if typeof(_event_bus) == TYPE_OBJECT:
        var event_bus_obj: Object = _event_bus
        if event_bus_obj.has_method("emit_event"):
            event_bus_obj.call("emit_event", event_name, "core", data, false)
        elif event_bus_obj.has_method("emit"):
            event_bus_obj.call("emit", event_name, {"source": "core", "timestamp": Time.get_unix_time_from_system(), "data": data})


@warning_ignore("unsafe_method_access")
func _log_warn(module_id: String, message: String) -> void:
    if _logger != null and typeof(_logger) == TYPE_OBJECT:
        var logger_obj: Object = _logger
        if logger_obj.has_method("warn"):
            logger_obj.call("warn", module_id, message)


@warning_ignore("unsafe_method_access")
func _log_debug(message: String) -> void:
    if _logger != null and typeof(_logger) == TYPE_OBJECT:
        var logger_obj: Object = _logger
        if logger_obj.has_method("info"):
            logger_obj.call("info", "TajsCore:ContextMenu", message)
