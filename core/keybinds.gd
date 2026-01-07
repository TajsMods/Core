# ==============================================================================
# Taj's Core - Keybinds
# Author: TajemnikTV
# Description: Keybinds
# ==============================================================================
class_name TajsCoreKeybinds
extends Node

const CONTEXT_ANY := "any"
const CONTEXT_GAMEPLAY := "gameplay"
const CONTEXT_UI := "ui"

var _settings
var _logger
var _event_bus
var _actions: Dictionary = {}
var _conflicts: Array = []
var _register_counter: int = 0

func setup(settings, logger, event_bus = null) -> void:
    _settings = settings
    _logger = logger
    _event_bus = event_bus
    set_process_unhandled_input(true)

func register_action(action_id: String, display_name: String, default_shortcuts: Array, context: String, callback: Callable, module_id: String, priority: int = 0) -> bool:
    if action_id == "":
        _log_warn(module_id, "Action id is required.")
        return false
    if _actions.has(action_id):
        _log_warn(module_id, "Action '%s' already registered." % action_id)
        return false
    var normalized_defaults := _normalize_shortcuts(default_shortcuts)
    var shortcuts := normalized_defaults
    var overrides := _get_overrides()
    if overrides.has(action_id):
        var override_events := _normalize_shortcuts(overrides[action_id])
        if not override_events.is_empty():
            shortcuts = override_events
    _actions[action_id] = {
        "id": action_id,
        "display_name": display_name,
        "module_id": module_id,
        "context": context,
        "priority": priority,
        "registered_at": _register_counter,
        "callback": callback,
        "default_shortcuts": normalized_defaults,
        "shortcuts": shortcuts
    }
    _register_counter += 1
    _apply_binding(action_id, shortcuts)
    _rebuild_conflicts()
    return true

func get_binding(action_id: String) -> Array:
    if not _actions.has(action_id):
        return []
    return _actions[action_id]["shortcuts"].duplicate()

func set_binding(action_id: String, shortcuts: Array) -> void:
    if not _actions.has(action_id):
        _log_warn("keybinds", "Unknown action '%s'." % action_id)
        return
    var normalized := _normalize_shortcuts(shortcuts)
    _actions[action_id]["shortcuts"] = normalized
    _apply_binding(action_id, normalized)
    var overrides := _get_overrides()
    overrides[action_id] = _serialize_shortcuts(normalized)
    _save_overrides(overrides)
    _rebuild_conflicts()

func reset_to_default(action_id: String) -> void:
    if not _actions.has(action_id):
        return
    var defaults: Array = _actions[action_id]["default_shortcuts"]
    _actions[action_id]["shortcuts"] = defaults
    _apply_binding(action_id, defaults)
    var overrides := _get_overrides()
    overrides.erase(action_id)
    _save_overrides(overrides)
    _rebuild_conflicts()

func get_conflicts() -> Array:
    return _conflicts.duplicate(true)

func get_actions_for_ui() -> Array:
    var result: Array = []
    var conflict_lookup := {}
    for conflict in _conflicts:
        for action_id in conflict["actions"]:
            conflict_lookup[action_id] = true
    for action in _actions.values():
        result.append({
            "id": action["id"],
            "display_name": action["display_name"],
            "module_id": action["module_id"],
            "context": action["context"],
            "priority": action["priority"],
            "shortcuts": _format_shortcuts(action["shortcuts"]),
            "default_shortcuts": _format_shortcuts(action["default_shortcuts"]),
            "has_conflict": conflict_lookup.has(action["id"])
        })
    return result

func _unhandled_input(event: InputEvent) -> void:
    if _actions.is_empty():
        return
    if event is InputEventKey:
        if not event.pressed or event.echo:
            return
    elif event is InputEventMouseButton:
        if not event.pressed:
            return
    else:
        return
    var matches: Array = []
    for action in _actions.values():
        if not _context_allows(action["context"]):
            continue
        if InputMap.event_is_action(event, action["id"]):
            matches.append(action)
    if matches.is_empty():
        return
    var winner = _resolve_conflict(matches)
    if winner == null:
        return
    var callback: Callable = winner["callback"]
    if callback != null and callback.is_valid():
        callback.call()
        get_viewport().set_input_as_handled()

func _context_allows(context: String) -> bool:
    match context:
        CONTEXT_GAMEPLAY:
            return not _is_text_input_focused()
        CONTEXT_UI:
            return _is_ui_focused()
        CONTEXT_ANY:
            return true
        _:
            return true

func _is_ui_focused() -> bool:
    var focus: Control = get_viewport().gui_get_focus_owner()
    return focus != null

func _is_text_input_focused() -> bool:
    var focus: Control = get_viewport().gui_get_focus_owner()
    if focus == null:
        return false
    return focus is LineEdit or focus is TextEdit or focus is CodeEdit or focus is SpinBox

func _resolve_conflict(matches: Array):
    var winner = matches[0]
    for action in matches:
        if action["priority"] > winner["priority"]:
            winner = action
        elif action["priority"] == winner["priority"]:
            if action["registered_at"] < winner["registered_at"]:
                winner = action
    return winner

func _rebuild_conflicts() -> void:
    var grouped := {}
    for action in _actions.values():
        var context: String = action["context"]
        for shortcut in action["shortcuts"]:
            var signature: String = _event_signature(shortcut)
            var key: String = "%s|%s" % [context, signature]
            if not grouped.has(key):
                grouped[key] = {
                    "context": context,
                    "signature": signature,
                    "actions": []
                }
            grouped[key]["actions"].append(action)
    _conflicts = []
    for group in grouped.values():
        if group["actions"].size() <= 1:
            continue
        var winner = _resolve_conflict(group["actions"])
        var action_ids: Array = []
        for action in group["actions"]:
            action_ids.append(action["id"])
        _conflicts.append({
            "context": group["context"],
            "shortcut": group["signature"],
            "actions": action_ids,
            "winner": winner["id"]
        })

func _apply_binding(action_id: String, shortcuts: Array) -> void:
    if not InputMap.has_action(action_id):
        InputMap.add_action(action_id)
    InputMap.action_erase_events(action_id)
    for shortcut in shortcuts:
        if shortcut is InputEvent:
            InputMap.action_add_event(action_id, shortcut)

func _normalize_shortcuts(shortcuts: Array) -> Array:
    var result: Array = []
    for entry in shortcuts:
        if entry is InputEvent:
            result.append(entry)
        elif entry is Dictionary:
            var event = _deserialize_shortcut(entry)
            if event != null:
                result.append(event)
    return result

func _serialize_shortcuts(shortcuts: Array) -> Array:
    var result: Array = []
    for shortcut in shortcuts:
        var data := _serialize_shortcut(shortcut)
        if data != {}:
            result.append(data)
    return result

func _serialize_shortcut(event: InputEvent) -> Dictionary:
    if event is InputEventKey:
        return {
            "type": "key",
            "keycode": event.keycode,
            "shift": event.shift_pressed,
            "ctrl": event.ctrl_pressed,
            "alt": event.alt_pressed,
            "meta": event.meta_pressed
        }
    if event is InputEventMouseButton:
        return {
            "type": "mouse",
            "button_index": event.button_index,
            "shift": event.shift_pressed,
            "ctrl": event.ctrl_pressed,
            "alt": event.alt_pressed,
            "meta": event.meta_pressed
        }
    return {}

func _deserialize_shortcut(data: Dictionary) -> InputEvent:
    if not data.has("type"):
        return null
    match data["type"]:
        "key":
            var ev := InputEventKey.new()
            ev.keycode = int(data.get("keycode", 0))
            ev.shift_pressed = bool(data.get("shift", false))
            ev.ctrl_pressed = bool(data.get("ctrl", false))
            ev.alt_pressed = bool(data.get("alt", false))
            ev.meta_pressed = bool(data.get("meta", false))
            ev.pressed = true
            return ev
        "mouse":
            var ev2 := InputEventMouseButton.new()
            ev2.button_index = int(data.get("button_index", 0))
            ev2.shift_pressed = bool(data.get("shift", false))
            ev2.ctrl_pressed = bool(data.get("ctrl", false))
            ev2.alt_pressed = bool(data.get("alt", false))
            ev2.meta_pressed = bool(data.get("meta", false))
            ev2.pressed = true
            return ev2
        _:
            return null

func _format_shortcuts(shortcuts: Array) -> Array:
    var result: Array = []
    for shortcut in shortcuts:
        if shortcut is InputEvent:
            result.append(shortcut.as_text())
    return result

func _event_signature(event: InputEvent) -> String:
    if event is InputEventKey:
        return "key:%s:%s:%s:%s:%s" % [event.keycode, event.shift_pressed, event.ctrl_pressed, event.alt_pressed, event.meta_pressed]
    if event is InputEventMouseButton:
        return "mouse:%s:%s:%s:%s:%s" % [event.button_index, event.shift_pressed, event.ctrl_pressed, event.alt_pressed, event.meta_pressed]
    return event.as_text()

func _get_overrides() -> Dictionary:
    if _settings != null and _settings.has_method("get_dict"):
        return _settings.get_dict("core.keybinds.overrides", {})
    return {}

func _save_overrides(overrides: Dictionary) -> void:
    if _settings != null and _settings.has_method("set_value"):
        _settings.set_value("core.keybinds.overrides", overrides)

func _log_warn(module_id: String, message: String) -> void:
    if _logger != null and _logger.has_method("warn"):
        _logger.warn(module_id, message)
