class_name TajsCoreResourceHelpers
extends RefCounted

func get_resource_by_id(id: String) -> ResourceContainer:
    if Globals == null or Globals.desktop == null:
        return null
    return Globals.desktop.get_resource(id)

func get_all_resources() -> Array[ResourceContainer]:
    var result: Array[ResourceContainer] = []
    if Globals == null or Globals.desktop == null:
        return result
    if Globals.desktop.resources is Dictionary:
        result.assign(Globals.desktop.resources.values())
    return result

func get_production_rate(resource_id: String) -> float:
    var res := get_resource_by_id(resource_id)
    if res == null:
        return 0.0
    if res.has_method("get"):
        var value: Variant = res.get("production")
        if value != null:
            return float(value)
    return 0.0

func get_consumption_rate(resource_id: String) -> float:
    var res := get_resource_by_id(resource_id)
    if res == null:
        return 0.0
    if res.has_method("get"):
        var value: Variant = res.get("required")
        if value != null:
            return float(value)
    return 0.0
