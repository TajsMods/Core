class_name TajsCoreConnectionHooks
extends Node

var _event_bus: Variant
var _logger: Variant

func setup(event_bus: Variant) -> void:
    _event_bus = event_bus
    var core: Variant = Engine.get_meta("TajsCore", null)
    if core != null:
        _logger = core.get("logger")

func _ready() -> void:
    if not _autoload_ready("Signals"):
        return
    _connect_signal_if_present("create_connection", Callable(self, "_on_create_connection"))
    _connect_signal_if_present("connection_created", Callable(self, "_on_connection_created"))
    _connect_signal_if_present("delete_connection", Callable(self, "_on_delete_connection"))
    _connect_signal_if_present("connection_deleted", Callable(self, "_on_connection_deleted"))

func request_connection_create(output: String, input: String) -> bool:
    var payload: Dictionary = _emit_event("connection.validate", {"output": output, "input": input}, true)
    if payload.get("cancelled", false):
        return false
    Signals.create_connection.emit(output, input)
    return true

func _on_create_connection(output: String, input: String) -> void:
    var _ignored5: Variant = _emit_event("connection.pre_create", {"output": output, "input": input}, true)
    var _ignored6: Variant = _emit_event("connection.validate", {"output": output, "input": input}, true)

func _on_connection_created(output: String, input: String) -> void:
    var _ignored7: Variant = _emit_event("connection.created", {"output": output, "input": input})

func _on_delete_connection(output: String, input: String) -> void:
    var _ignored8: Variant = _emit_event("connection.pre_delete", {"output": output, "input": input}, true)

func _on_connection_deleted(output: String, input: String) -> void:
    var _ignored9: Variant = _emit_event("connection.deleted", {"output": output, "input": input})

func _emit_event(event_name: String, data: Dictionary, cancellable: bool = false) -> Dictionary:
    if _event_bus == null:
        return {}
    @warning_ignore("unsafe_method_access")
    if _event_bus.has_method("emit_event"):
        @warning_ignore("unsafe_method_access")
        return _event_bus.emit_event(event_name, "core", data, cancellable)
    @warning_ignore("unsafe_method_access")
    if _event_bus.has_method("emit"):
        var payload: Dictionary = {"source": "core", "timestamp": Time.get_unix_time_from_system(), "data": data, "cancellable": cancellable, "cancelled": false}
        @warning_ignore("unsafe_method_access")
        _event_bus.emit(event_name, payload)
        return payload
    return {}

func _autoload_ready(autoload_name: String) -> bool:
    var tree: Variant = Engine.get_main_loop()
    if not (tree is SceneTree):
        return false
    @warning_ignore("unsafe_cast")
    var scene_tree: SceneTree = tree as SceneTree
    return scene_tree.get_root().has_node(autoload_name)

func _connect_signal_if_present(signal_name: String, callback: Callable) -> void:
    if not Signals.has_signal(signal_name):
        _log_debug("Missing signal '%s'" % signal_name)
        return
    var sig: Signal = Signals.get(signal_name)
    if sig.is_connected(callback):
        return
    sig.connect(callback)

func _log_debug(message: String) -> void:
    if _logger != null and _logger.has_method("debug"):
        _logger.debug("hooks", message)
