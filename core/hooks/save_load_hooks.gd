class_name TajsCoreSaveLoadHooks
extends Node

var _event_bus: Variant

func setup(event_bus: Variant) -> void:
    _event_bus = event_bus

func _ready() -> void:
    if not _autoload_ready("Signals"):
        return
    Signals.saving.connect(_on_saving)
    Signals.boot.connect(_on_boot)
    Signals.desktop_ready.connect(_on_desktop_ready)

func _on_saving() -> void:
    var _ignored: Variant = _emit_event("game.saving", {})

func _on_boot() -> void:
    var _ignored: Variant = _emit_event("game.started", {})

func _on_desktop_ready() -> void:
    var _ignored: Variant = _emit_event("game.desktop_ready", {})

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
