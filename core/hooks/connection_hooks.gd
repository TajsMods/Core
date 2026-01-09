# ==============================================================================
# Taj's Core - Connection Hooks
# Author: TajemnikTV
# Description: Bridges connection events to the Core event bus.
# ==============================================================================
class_name TajsCoreConnectionHooks
extends Node

var _event_bus

func setup(event_bus) -> void:
	_event_bus = event_bus

func _ready() -> void:
	if not _autoload_ready("Signals"):
		return
	Signals.create_connection.connect(_on_create_connection)
	Signals.connection_created.connect(_on_connection_created)
	Signals.delete_connection.connect(_on_delete_connection)
	Signals.connection_deleted.connect(_on_connection_deleted)

func request_connection_create(output: String, input: String) -> bool:
	var payload := _emit_event("connection.validate", {"output": output, "input": input}, true)
	if payload.get("cancelled", false):
		return false
	Signals.create_connection.emit(output, input)
	return true

func _on_create_connection(output: String, input: String) -> void:
	_emit_event("connection.pre_create", {"output": output, "input": input}, true)
	_emit_event("connection.validate", {"output": output, "input": input}, true)

func _on_connection_created(output: String, input: String) -> void:
	_emit_event("connection.created", {"output": output, "input": input})

func _on_delete_connection(output: String, input: String) -> void:
	_emit_event("connection.pre_delete", {"output": output, "input": input}, true)

func _on_connection_deleted(output: String, input: String) -> void:
	_emit_event("connection.deleted", {"output": output, "input": input})

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

func _autoload_ready(name: String) -> bool:
	var tree = Engine.get_main_loop()
	if not (tree is SceneTree):
		return false
	return tree.get_root().has_node(name)
