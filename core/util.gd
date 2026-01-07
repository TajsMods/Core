# ==============================================================================
# Taj's Core - Util
# Author: TajemnikTV
# Description: Util
# ==============================================================================
class_name TajsCoreUtil
extends RefCounted

static func deep_merge(base: Dictionary, extra: Dictionary) -> Dictionary:
    var result := base.duplicate(true)
    for key in extra.keys():
        var val = extra[key]
        if result.has(key) and result[key] is Dictionary and val is Dictionary:
            result[key] = deep_merge(result[key], val)
        else:
            result[key] = val
    return result

static func safe_call(callable: Callable, args: Array = []) -> bool:
    if callable == null:
        return false
    if not callable.is_valid():
        return false
    callable.callv(args)
    return true
