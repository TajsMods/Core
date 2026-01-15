class_name TajsCoreCallableCommand
extends "res://mods-unpacked/TajemnikTV-Core/core/commands/undo/undo_command.gd"

var _do_func: Callable
var _undo_func: Callable

func setup(do_func: Callable, undo_func: Callable, label: String = "") -> void:
    _do_func = do_func
    _undo_func = undo_func
    description = label if label else "Custom Action"

func execute() -> bool:
    if _do_func.is_valid():
        _do_func.call()
        return true
    return false

func undo() -> bool:
    if _undo_func.is_valid():
        _undo_func.call()
        return true
    return false

func is_valid() -> bool:
    return _do_func.is_valid() and _undo_func.is_valid()
