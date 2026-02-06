class_name TajsCorePropertyChangeCommand
extends "res://mods-unpacked/TajemnikTV-Core/core/commands/undo/undo_command.gd"

var _target_ref: WeakRef
var _property: String
var _before: Variant
var _after: Variant

func setup(target: Object, property: String, before: Variant, after: Variant, label: String = "") -> void:
    _target_ref = weakref(target)
    _property = property
    _before = before
    _after = after
    description = label if label else "Change " + property

func execute() -> bool:
    var target: Object = _target_ref.get_ref()
    if not target: return false
    if target.has_method("set"):
        target.set(_property, _after)
    return true

func undo() -> bool:
    var target: Object = _target_ref.get_ref()
    if not target: return false
    if target.has_method("set"):
        target.set(_property, _before)
    return true

func is_valid() -> bool:
    return _target_ref.get_ref() != null
