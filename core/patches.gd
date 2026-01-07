# ==============================================================================
# Taj's Core - Patches
# Author: TajemnikTV
# Description: Patches
# ==============================================================================
class_name TajsCorePatches
extends RefCounted

var _applied: Dictionary = {}
var _logger

func _init(logger = null) -> void:
    _logger = logger

func apply_once(patch_id: String, callable: Callable) -> bool:
    if patch_id == "":
        return false
    if _applied.has(patch_id):
        return false
    _applied[patch_id] = true
    if callable != null and callable.is_valid():
        callable.call()
        return true
    _log_warn("patches", "Invalid patch callable for '%s'" % patch_id)
    return false

func is_applied(patch_id: String) -> bool:
    return _applied.has(patch_id)

func list_applied() -> Array:
    return _applied.keys()

func connect_signal_once(target: Object, signal_name: String, callable: Callable, patch_id: String) -> bool:
    return apply_once(patch_id, func() -> void:
        if target == null:
            _log_warn("patches", "Target is null for '%s'" % patch_id)
            return
        if not target.has_signal(signal_name):
            _log_warn("patches", "Signal '%s' missing for '%s'" % [signal_name, patch_id])
            return
        if target.is_connected(signal_name, callable):
            return
        target.connect(signal_name, callable)
    )

func _log_warn(module_id: String, message: String) -> void:
    if _logger != null and _logger.has_method("warn"):
        _logger.warn(module_id, message)
