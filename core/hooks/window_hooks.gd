class_name TajsCoreWindowHooks
extends Node

var _event_bus: Variant
var _logger: Variant
var _suppress_create_event_for_window_ids: Dictionary = {}

# Event payload for core.desktop.window_* events:
# {window_id:String, window_type_id:String, owner_mod_id:String}
func setup(event_bus: Variant, logger: Variant = null) -> void:
    _event_bus = event_bus
    _logger = logger

func _ready() -> void:
    if not _autoload_ready("Signals"):
        return
    Signals.create_window.connect(_on_create_window)
    Signals.window_created.connect(_on_window_created)
    Signals.window_initialized.connect(_on_window_initialized)
    Signals.window_deleted.connect(_on_window_deleted)
    Signals.window_moved.connect(_on_window_moved)
    Signals.new_upgrade.connect(_on_new_upgrade)

func request_window_create(window: WindowContainer) -> bool:
    if window == null:
        return false
    var payload := _emit_event("core.desktop.window_create_requested", _build_window_payload(window), true)
    if payload.get("cancelled", false):
        return false
    var window_key := _get_window_key(window)
    if window_key != "":
        _suppress_create_event_for_window_ids[window_key] = true
    Signals.create_window.emit(window)
    return true

func _on_create_window(window: WindowContainer) -> void:
    var window_key := _get_window_key(window)
    if window_key != "" and _suppress_create_event_for_window_ids.has(window_key):
        _suppress_create_event_for_window_ids.erase(window_key)
        return
    _emit_event("core.desktop.window_create_requested", _build_window_payload(window), true)

func _on_window_created(window: WindowContainer) -> void:
    _emit_event("core.desktop.window_created", _build_window_payload(window))

func _on_window_initialized(window: WindowContainer) -> void:
    _emit_event("core.desktop.window_initialized", _build_window_payload(window))

func _on_window_deleted(window: WindowContainer) -> void:
    _emit_event("core.desktop.window_delete_requested", _build_window_payload(window), true)
    _emit_event("core.desktop.window_deleted", _build_window_payload(window))

func _on_window_moved(window: Control) -> void:
    _emit_event("core.desktop.window_moved", _build_window_payload(window))

func _on_new_upgrade(upgrade: String, levels: int) -> void:
    _emit_event("core.desktop.window_upgraded", {
        "window_id": "",
        "window_type_id": "",
        "owner_mod_id": "base",
        "upgrade_id": upgrade,
        "levels": levels
    })

func _emit_event(event_name: String, data: Dictionary, cancellable: bool = false) -> Dictionary:
    if _event_bus == null:
        return {}
    if _event_bus.has_method("emit_event"):
        return _event_bus.emit_event(event_name, "core", data, cancellable)
    if _event_bus.has_method("emit"):
        var payload := {"source": "core", "timestamp": Time.get_unix_time_from_system(), "data": data, "cancellable": cancellable, "cancelled": false}
        _event_bus.emit(event_name, payload)
        return payload
    return {}

func _autoload_ready(autoload_name: String) -> bool:
    var tree: Variant = Engine.get_main_loop()
    if not (tree is SceneTree):
        return false
    return tree.get_root().has_node(autoload_name)

func _build_window_payload(window: Variant) -> Dictionary:
    if window == null:
        return {"window_id": "", "window_type_id": "", "owner_mod_id": "base"}
    var window_id := ""
    if window is Node:
        window_id = str(window.name)
    var window_type_id := ""
    if window.has_method("get"):
        window_type_id = str(window.get("window"))
        if window_type_id == "":
            window_type_id = str(window.get("filename"))
    return {
        "window_id": window_id,
        "window_type_id": window_type_id,
        "owner_mod_id": "base"
    }

func _get_window_key(window: Variant) -> String:
    if window == null:
        return ""
    if window is Object:
        return str(window.get_instance_id())
    return ""
