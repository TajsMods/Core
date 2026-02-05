class_name TajsCoreUndoStack
extends RefCounted

signal action_registered(action_type: String)
signal undo_performed()
signal redo_performed()

const DEFAULT_MAX_SIZE := 100

var _undo_stack: Array = []
var _redo_stack: Array = []
var _handlers: Dictionary = {}
var _max_size: int = DEFAULT_MAX_SIZE
var _enabled: bool = true

func set_enabled(enabled: bool) -> void:
	_enabled = enabled

func is_enabled() -> bool:
	return _enabled

func set_max_size(size: int) -> void:
	_max_size = max(1, size)

func register_handler(action_type: String, undo_callable: Callable, redo_callable: Callable = Callable()) -> void:
	if action_type == "":
		return
	_handlers[action_type] = {
		"undo": undo_callable,
		"redo": redo_callable
	}

func register_action(action_type: String, data: Dictionary) -> void:
	if not _enabled or action_type == "":
		return
	_undo_stack.append({
		"type": action_type,
		"data": data
	})
	if _undo_stack.size() > _max_size:
		_undo_stack.pop_front()
	_redo_stack.clear()
	action_registered.emit(action_type)

func undo() -> bool:
	if not _enabled or _undo_stack.is_empty():
		return false
	var action: Dictionary = _undo_stack.pop_back()
	if _execute(action, true):
		_redo_stack.append(action)
		undo_performed.emit()
		return true
	return false

func redo() -> bool:
	if not _enabled or _redo_stack.is_empty():
		return false
	var action: Dictionary = _redo_stack.pop_back()
	if _execute(action, false):
		_undo_stack.append(action)
		redo_performed.emit()
		return true
	return false

func clear() -> void:
	_undo_stack.clear()
	_redo_stack.clear()

func get_undo_count() -> int:
	return _undo_stack.size()

func get_redo_count() -> int:
	return _redo_stack.size()

func _execute(action: Dictionary, is_undo: bool) -> bool:
	var action_type := str(action.get("type", ""))
	var data: Variant = action.get("data", {})
	if action_type == "":
		return false
	if _handlers.has(action_type):
		var handler: Dictionary = _handlers[action_type]
		var callable: Callable = handler["undo"] if is_undo else handler["redo"]
		if callable != null and callable.is_valid():
			callable.call(data)
			return true
	return false
