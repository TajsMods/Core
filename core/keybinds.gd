class_name TajsCoreKeybinds
extends Node

signal binding_changed(action_id: String, shortcuts: Array)

const CONTEXT_ANY := "any"
const CONTEXT_GAMEPLAY := "gameplay"
const CONTEXT_UI := "ui"
const CONTEXT_DESKTOP := "desktop_only"
const CONTEXT_MENU := "menu_only"
const CONTEXT_NO_POPUP := "no_popup"
const CONTEXT_NO_TEXT := "no_text_input"

enum KeybindContext {
    ALWAYS,
    DESKTOP_ONLY,
    MENU_ONLY,
    NO_POPUP,
    NO_TEXT_INPUT
}

var _settings: Variant
var _logger: Variant
var _event_bus: Variant
var _actions: Dictionary = {}
var _conflicts: Array = []
var _register_counter: int = 0
var _categories: Dictionary = {}
var _hold_actions: Dictionary = {}

func setup(settings: Variant, logger: Variant, event_bus: Variant = null) -> void:
    _settings = settings
    _logger = logger
    _event_bus = event_bus
    set_process_input(true)
    set_process_unhandled_input(true)


func register(action_id: String, default_binding: Variant, callback: Callable, display_name: String = "", context: String = CONTEXT_ANY, module_id: String = "", priority: int = 0, category_id: String = "", use_input: bool = false) -> bool:
    var shortcuts: Array = []
    if default_binding is Array:
        shortcuts = default_binding
    elif default_binding is InputEvent:
        shortcuts = [default_binding]
    if display_name == "":
        display_name = action_id
    if module_id == "":
        module_id = _extract_module_id(action_id)
    return register_action(action_id, display_name, shortcuts, context, callback, module_id, priority, category_id, use_input)

func register_action(action_id: String, display_name: String, default_shortcuts: Array, context: String, callback: Callable, module_id: String, priority: int = 0, category_id: String = "", use_input: bool = false) -> bool:
    if action_id == "":
        _log_warn(module_id, "Action id is required.")
        return false
    _warn_if_unscoped(action_id, module_id)
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
    var normalized_context := _normalize_context(context)
    _actions[action_id] = {
        "id": action_id,
        "display_name": display_name,
        "module_id": module_id,
        "context": normalized_context,
        "priority": priority,
        "registered_at": _register_counter,
        "callback": callback,
        "default_shortcuts": normalized_defaults,
        "shortcuts": shortcuts,
        "category": category_id,
        "group": "",
        "hold": false,
        "use_input": use_input
    }
    _register_counter += 1
    _apply_binding(action_id, shortcuts)
    _rebuild_conflicts()
    if _event_bus != null and _event_bus.has_method("emit"):
        _event_bus.emit("keybind.registered", {"id": action_id, "module_id": module_id, "context": context})
    return true

func register_action_scoped(module_id: String, action_name: String, display_name: String, default_shortcuts: Array, context: String, callback: Callable, priority: int = 0, category_id: String = "", use_input: bool = false) -> bool:
    if module_id == "" or action_name == "":
        _log_warn(module_id, "Module id and action name are required.")
        return false
    var action_id: String = "%s.%s" % [module_id, action_name]
    return register_action(action_id, display_name, default_shortcuts, context, callback, module_id, priority, category_id, use_input)

func register_keybind_category(category_id: String, label: String, icon: String) -> void:
    if category_id == "":
        return
    _categories[category_id] = {"label": label, "icon": icon}

func set_keybind_group(action_id: String, group_id: String) -> void:
    if not _actions.has(action_id):
        return
    _actions[action_id]["group"] = group_id

func set_keybind_category(action_id: String, category_id: String) -> void:
    if not _actions.has(action_id):
        return
    _actions[action_id]["category"] = category_id

func register_combo_keybind(id: String, keys: Array[int], callback: Callable, display_name: String = "", context: String = CONTEXT_ANY, module_id: String = "") -> bool:
    if id == "" or keys.is_empty():
        return false
    if display_name == "":
        display_name = id
    if module_id == "":
        module_id = _extract_module_id(id)
    var event := _build_combo_event(keys)
    if event == null:
        return false
    return register_action(id, display_name, [event], context, callback, module_id)

func register_hold_keybind(id: String, key: int, on_press: Callable, on_release: Callable) -> bool:
    if id == "" or key == 0:
        return false
    var event := InputEventKey.new()
    event.keycode = key as Key
    event.pressed = true
    var ok := register_action(id, id, [event], CONTEXT_ANY, Callable(), _extract_module_id(id))
    if ok:
        _actions[id]["hold"] = true
        _hold_actions[id] = {"press": on_press, "release": on_release, "event": event, "context": CONTEXT_ANY}
    return ok

func set_keybind_context(action_id: String, context: Variant) -> void:
    if not _actions.has(action_id):
        return
    var normalized := _normalize_context(context)
    _actions[action_id]["context"] = normalized
    if _hold_actions.has(action_id):
        _hold_actions[action_id]["context"] = normalized

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
    var _ignored: Variant = emit_signal("binding_changed", action_id, normalized)
    if _event_bus != null and _event_bus.has_method("emit"):
        _event_bus.emit("keybind.overridden", {"id": action_id})

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
    emit_signal("binding_changed", action_id, defaults)

func reset_all_to_default() -> void:
    for action_id: Variant in _actions.keys():
        var defaults: Array = _actions[action_id]["default_shortcuts"]
        _actions[action_id]["shortcuts"] = defaults
        _apply_binding(action_id, defaults)
        var _ignored: Variant = emit_signal("binding_changed", action_id, defaults)
    var overrides := _get_overrides()
    overrides.clear()
    _save_overrides(overrides)
    _rebuild_conflicts()

func get_conflicts() -> Array:
    return _conflicts.duplicate(true)

func get_actions_for_ui() -> Array:
    var result: Array = []
    var conflict_lookup := {}
    for conflict: Variant in _conflicts:
        for action_id: Variant in conflict["actions"]:
            conflict_lookup[action_id] = true
    for action: Variant in _actions.values():
        result.append({
            "id": action["id"],
            "display_name": action["display_name"],
            "module_id": action["module_id"],
            "context": action["context"],
            "priority": action["priority"],
            "category": action.get("category", ""),
            "group": action.get("group", ""),
            "hold": action.get("hold", false),
            "shortcuts": _format_shortcuts(action["shortcuts"]),
            "default_shortcuts": _format_shortcuts(action["default_shortcuts"]),
            "has_conflict": conflict_lookup.has(action["id"])
        })
    return result

func _unhandled_input(event: InputEvent) -> void:
    if _actions.is_empty():
        return
    if event is InputEventKey:
        if _handle_hold(event):
            get_viewport().set_input_as_handled()
            return
        if not event.get("pressed") or event.get("echo"):
            return
    elif event is InputEventMouseButton:
        if not event.get("pressed"):
            return
    else:
        return
    var matches: Array = []
    for action: Variant in _actions.values():
        if action.get("use_input", false):
            continue
        if action.get("hold", false):
            continue
        if not _context_allows(action["context"]):
            continue
        if InputMap.event_is_action(event, action["id"]):
            matches.append(action)
    if matches.is_empty():
        return
    var winner: Variant = _resolve_conflict(matches)
    if winner == null:
        return
    var callback: Callable = winner["callback"]
    if callback != null and callback.is_valid():
        callback.call()
        if _event_bus != null and _event_bus.has_method("emit"):
            _event_bus.emit("keybind.pressed", {"id": winner["id"], "context": winner["context"]})
        get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
    if _actions.is_empty():
        return
    if event is InputEventKey:
        if not event.get("pressed") or event.get("echo"):
            return
    elif event is InputEventMouseButton:
        if not event.get("pressed"):
            return
    else:
        return
    var matches: Array = []
    for action: Variant in _actions.values():
        if not action.get("use_input", false):
            continue
        if action.get("hold", false):
            continue
        if not _context_allows(action["context"]):
            continue
        if InputMap.event_is_action(event, action["id"]):
            matches.append(action)
    if matches.is_empty():
        return
    var winner: Variant = _resolve_conflict(matches)
    if winner == null:
        return
    var callback: Callable = winner["callback"]
    if callback != null and callback.is_valid():
        callback.call()
        if _event_bus != null and _event_bus.has_method("emit"):
            _event_bus.emit("keybind.pressed", {"id": winner["id"], "context": winner["context"]})
        get_viewport().set_input_as_handled()

func _context_allows(context: Variant) -> bool:
    var normalized := _normalize_context(context)
    match normalized:
        CONTEXT_GAMEPLAY:
            return _is_desktop_active() and not _is_text_input_focused()
        CONTEXT_UI:
            return _is_ui_focused()
        CONTEXT_DESKTOP:
            return _is_desktop_active()
        CONTEXT_MENU:
            return _is_menu_open()
        CONTEXT_NO_POPUP:
            return not _is_popup_open()
        CONTEXT_NO_TEXT:
            return not _is_text_input_focused()
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

func _is_desktop_active() -> bool:
    if Globals == null:
        return true
    return Globals.cur_screen == 0

func _is_menu_open() -> bool:
    var hud := _get_hud()
    if hud == null:
        return false
    if hud.has_method("get"):
        var menu_val: Variant = hud.get("cur_menu")
        if menu_val != null:
            return int(menu_val) != Utils.menu_types.NONE
    return false

func _is_popup_open() -> bool:
    return false

func _get_hud() -> Node:
    var tree: Variant = Engine.get_main_loop()
    if tree is SceneTree:
        return tree.root.get_node_or_null("Main/HUD")
    return null

func _resolve_conflict(matches: Array) -> Dictionary:
    var winner: Variant = matches[0]
    for action: Variant in matches:
        if action["priority"] > winner["priority"]:
            winner = action
        elif action["priority"] == winner["priority"]:
            if action["registered_at"] < winner["registered_at"]:
                winner = action
    return winner

func _rebuild_conflicts() -> void:
    var grouped := {}
    for action: Variant in _actions.values():
        var context: String = action["context"]
        for shortcut: Variant in action["shortcuts"]:
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
    for group: Variant in grouped.values():
        if group["actions"].size() <= 1:
            continue
        var winner: Variant = _resolve_conflict(group["actions"])
        var action_ids: Array = []
        for action: Variant in group["actions"]:
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
    for shortcut: Variant in shortcuts:
        if shortcut is InputEvent:
            InputMap.action_add_event(action_id, shortcut)

func _normalize_shortcuts(shortcuts: Array) -> Array:
    var result: Array = []
    for entry: Variant in shortcuts:
        if entry is InputEvent:
            result.append(entry)
        elif entry is Dictionary:
            var event: Variant = _deserialize_shortcut(entry)
            if event != null:
                result.append(event)
    return result

func _serialize_shortcuts(shortcuts: Array) -> Array:
    var result: Array = []
    for shortcut: Variant in shortcuts:
        var data := _serialize_shortcut(shortcut)
        if not data.is_empty():
            result.append(data)
    return result

func _serialize_shortcut(event: InputEvent) -> Dictionary:
    if event is InputEventKey:
        return {
            "type": "key",
            "keycode": event.get("keycode"),
            "shift": event.get("shift_pressed"),
            "ctrl": event.get("ctrl_pressed"),
            "alt": event.get("alt_pressed"),
            "meta": event.get("meta_pressed")
        }
    if event is InputEventMouseButton:
        return {
            "type": "mouse",
            "button_index": event.get("button_index"),
            "shift": event.get("shift_pressed"),
            "ctrl": event.get("ctrl_pressed"),
            "alt": event.get("alt_pressed"),
            "meta": event.get("meta_pressed")
        }
    return {}

func _deserialize_shortcut(data: Dictionary) -> InputEvent:
    if not data.has("type"):
        return null
    match data["type"]:
        "key":
            var keycode := int(data.get("keycode", 0))
            if keycode <= 0:
                return null # Invalid keycode, reject this shortcut
            var ev := InputEventKey.new()
            ev.keycode = keycode as Key
            ev.shift_pressed = bool(data.get("shift", false))
            ev.ctrl_pressed = bool(data.get("ctrl", false))
            ev.alt_pressed = bool(data.get("alt", false))
            ev.meta_pressed = bool(data.get("meta", false))
            ev.pressed = true
            return ev
        "mouse":
            var button_index := int(data.get("button_index", 0))
            if button_index <= 0:
                return null # Invalid button_index, reject this shortcut
            var ev2 := InputEventMouseButton.new()
            ev2.button_index = button_index as MouseButton
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
    for shortcut: Variant in shortcuts:
        if shortcut is InputEvent:
            result.append(shortcut.as_text())
    return result

func _event_signature(event: InputEvent) -> String:
    if event is InputEventKey:
        return "key:%s:%s:%s:%s:%s" % [event.get("keycode"), event.get("shift_pressed"), event.get("ctrl_pressed"), event.get("alt_pressed"), event.get("meta_pressed")]
    if event is InputEventMouseButton:
        return "mouse:%s:%s:%s:%s:%s" % [event.get("button_index"), event.get("shift_pressed"), event.get("ctrl_pressed"), event.get("alt_pressed"), event.get("meta_pressed")]
    return event.as_text()

func _normalize_context(context: Variant) -> String:
    if typeof(context) == TYPE_INT:
        match int(context):
            KeybindContext.ALWAYS:
                return CONTEXT_ANY
            KeybindContext.DESKTOP_ONLY:
                return CONTEXT_DESKTOP
            KeybindContext.MENU_ONLY:
                return CONTEXT_MENU
            KeybindContext.NO_POPUP:
                return CONTEXT_NO_POPUP
            KeybindContext.NO_TEXT_INPUT:
                return CONTEXT_NO_TEXT
            _:
                return CONTEXT_ANY
    return str(context)

func _extract_module_id(action_id: String) -> String:
    if not action_id.contains("."):
        return ""
    return action_id.split(".")[0]

func _build_combo_event(keys: Array[int]) -> InputEventKey:
    var event := InputEventKey.new()
    for key: Variant in keys:
        match key:
            KEY_CTRL:
                event.ctrl_pressed = true
            KEY_SHIFT:
                event.shift_pressed = true
            KEY_ALT:
                event.alt_pressed = true
            KEY_META:
                event.meta_pressed = true
            _:
                event.keycode = int(key) as Key
    event.pressed = true
    if event.keycode == 0:
        return null
    return event

func make_key_event(keycode: int, ctrl: bool = false, shift: bool = false, alt: bool = false, meta: bool = false) -> InputEventKey:
    var event := InputEventKey.new()
    event.keycode = keycode as Key
    event.ctrl_pressed = ctrl
    event.shift_pressed = shift
    event.alt_pressed = alt
    event.meta_pressed = meta
    event.pressed = true
    return event

func make_mouse_event(button_index: int, ctrl: bool = false, shift: bool = false, alt: bool = false, meta: bool = false) -> InputEventMouseButton:
    var event := InputEventMouseButton.new()
    event.button_index = button_index as MouseButton
    event.ctrl_pressed = ctrl
    event.shift_pressed = shift
    event.alt_pressed = alt
    event.meta_pressed = meta
    event.pressed = true
    return event

func _handle_hold(event: InputEvent) -> bool:
    if not (event is InputEventKey):
        return false
    for action_id: Variant in _hold_actions.keys():
        var entry: Dictionary = _hold_actions[action_id]
        if not _context_allows(entry.get("context", CONTEXT_ANY)):
            continue
        var target: InputEventKey = entry.get("event", null)
        if target != null and _event_matches(event, target):
            var callable: Callable = entry["press"] if event.get("pressed") else entry["release"]
            if callable != null and callable.is_valid():
                callable.call()
            if _event_bus != null and _event_bus.has_method("emit"):
                _event_bus.emit("keybind.pressed", {"id": action_id, "state": "press" if event.pressed else "release"})
            return true
    return false

func _event_matches(event: InputEventKey, target: InputEventKey) -> bool:
    return event.keycode == target.keycode \
        and event.shift_pressed == target.shift_pressed \
        and event.ctrl_pressed == target.ctrl_pressed \
        and event.alt_pressed == target.alt_pressed \
        and event.meta_pressed == target.meta_pressed

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

func _warn_if_unscoped(action_id: String, module_id: String) -> void:
    if not action_id.contains("."):
        _log_warn(module_id, "Action id '%s' is not namespaced. Use '{module_id}.action'." % action_id)
        return
    if module_id != "" and not action_id.begins_with(module_id + "."):
        _log_warn(module_id, "Action id '%s' should start with '%s.'." % [action_id, module_id])
