# ==============================================================================
# Taj's Core - Selection Hooks
# Author: TajemnikTV
# Description: Selection-related hooks and keyboard helpers.
# ==============================================================================
class_name TajsCoreSelectionHooks
extends Node

var _event_bus

func setup(event_bus) -> void:
	_event_bus = event_bus

func _ready() -> void:
	set_process_input(true)
	if _autoload_ready("Signals"):
		Signals.selection_set.connect(_on_selection_set)
		Signals.move_selection.connect(_on_move_selection)

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or event.echo:
		return
	if event.is_released() and event.ctrl_pressed:
		if event.keycode == KEY_C:
			_emit_event("selection.copied", _selection_payload())
		elif event.keycode == KEY_V:
			_emit_event("selection.pasted", _selection_payload())
	if event.pressed and event.keycode == KEY_DELETE:
		_emit_event("selection.pre_delete", _selection_payload(), true)

func _on_selection_set() -> void:
	_emit_event("selection.changed", _selection_payload())

func _on_move_selection(offset: Vector2) -> void:
	var data := _selection_payload()
	data["offset"] = offset
	_emit_event("selection.moved", data)

func _selection_payload() -> Dictionary:
	return {
		"count": Globals.selections.size() if Globals != null else 0,
		"selection": Globals.selections if Globals != null else [],
		"connectors": Globals.connector_selection if Globals != null else []
	}

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
