class_name TajsCoreCalculations
extends RefCounted

func calculate_upgrade_cost(upgrade: String, from_level: int, to_level: int) -> float:
    if upgrade == "" or not Data.upgrades.has(upgrade):
        return 0.0
    if to_level <= from_level:
        return 0.0
    var total := 0.0
    for level: Variant in range(from_level, to_level):
        total += _get_upgrade_level_cost(upgrade, level)
    return total

func calculate_max_affordable(upgrade: String, current_level: int, currency: float) -> int:
    if upgrade == "" or not Data.upgrades.has(upgrade):
        return current_level
    var cap := get_effective_cap(upgrade)
    var level := current_level
    var remaining := currency
    while cap < 0 or level < cap:
        var cost := _get_upgrade_level_cost(upgrade, level)
        if cost > remaining:
            break
        remaining -= cost
        level += 1
    return level

func get_effective_cap(upgrade: String) -> int:
    if upgrade == "" or not Data.upgrades.has(upgrade):
        return -1
    var core: Variant = Engine.get_meta("TajsCore", null)
    if core != null and core.has_method("get_upgrade_cap"):
        return core.get_upgrade_cap(upgrade)
    var limit := int(Data.upgrades[upgrade].limit)
    if limit == 0:
        return -1
    return limit

func _get_upgrade_level_cost(upgrade: String, level: int) -> float:
    var data: Variant = Data.upgrades[upgrade]
    var cost_type := int(data.cost_type)
    var cost := 0.0
    if cost_type == Utils.COST_TYPES.ATTRIBUTE:
        cost = data.cost
    else:
        cost = data.cost * pow(10.0, data.cost_e)
        var inc_type := Utils.COST_INC_TYPES.MULTIPLY
        if data.has("inc_type"):
            inc_type = int(data.inc_type) as Utils.COST_INC_TYPES
        if inc_type == Utils.COST_INC_TYPES.MULTIPLY:
            cost *= pow(data.cost_inc, level)
        elif inc_type == Utils.COST_INC_TYPES.ADD:
            cost += data.cost_inc * level
        if data.currency == "money":
            cost *= Attributes.get_attribute("price_multiplier")
    return cost
