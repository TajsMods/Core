class_name TajsCoreWindowHooks
extends Node

var _event_bus
var _logger

func setup(event_bus, logger = null) -> void:
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
    var payload := _emit_event("window.pre_create", {"window": window}, true)
    if payload.get("cancelled", false):
        return false
    Signals.create_window.emit(window)
    return true

func _on_create_window(window: WindowContainer) -> void:
    _emit_event("window.pre_create", {"window": window}, true)

func _on_window_created(window: WindowContainer) -> void:
    _emit_event("window.created", {"window": window})

func _on_window_initialized(window: WindowContainer) -> void:
    _emit_event("window.initialized", {"window": window})

func _on_window_deleted(window: WindowContainer) -> void:
    _emit_event("window.pre_delete", {"window": window}, true)
    _emit_event("window.deleted", {"window": window})

func _on_window_moved(window: Control) -> void:
    _emit_event("window.moved", {"window": window})

func _on_new_upgrade(upgrade: String, levels: int) -> void:
    _emit_event("window.upgraded", {"upgrade": upgrade, "levels": levels})

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
    var tree = Engine.get_main_loop()
    if not (tree is SceneTree):
        return false
    return tree.get_root().has_node(autoload_name)
