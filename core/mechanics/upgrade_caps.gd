class_name TajsCoreUpgradeCaps
extends RefCounted

var _caps: Dictionary = {}
var _logger

func _init(logger = null) -> void:
    _logger = logger

func register_extended_cap(upgrade_id: String, config: Dictionary) -> void:
    if upgrade_id == "":
        return
    var normalized := _normalize_config(upgrade_id, config)
    _caps[upgrade_id] = normalized

func get_effective_cap(upgrade_id: String) -> int:
    if not Data.upgrades.has(upgrade_id):
        return -1
    var vanilla := int(Data.upgrades[upgrade_id].limit)
    if vanilla == 0:
        vanilla = -1
    if not _caps.has(upgrade_id):
        return vanilla
    if not is_extended_cap_enabled(upgrade_id):
        return vanilla
    var cfg: Dictionary = _caps[upgrade_id]
    var extended := int(cfg.get("extended_cap", vanilla))
    if extended <= 0:
        return vanilla
    return extended

func is_extended_cap_enabled(upgrade_id: String) -> bool:
    if not _caps.has(upgrade_id):
        return false
    var cfg: Dictionary = _caps[upgrade_id]
    var requires: Array = cfg.get("requires", [])
    if requires.is_empty():
        return true
    for req in requires:
        if not Globals.unlocks.has(req) or not Globals.unlocks[req]:
            return false
    return true

func get_config(upgrade_id: String) -> Dictionary:
    if not _caps.has(upgrade_id):
        return {}
    return _caps[upgrade_id].duplicate(true)

func list_caps() -> Dictionary:
    return _caps.duplicate(true)

func _normalize_config(upgrade_id: String, config: Dictionary) -> Dictionary:
    var vanilla := int(Data.upgrades[upgrade_id].limit) if Data.upgrades.has(upgrade_id) else 0
    var normalized := {
        "vanilla_cap": int(config.get("vanilla_cap", vanilla)),
        "extended_cap": int(config.get("extended_cap", -1)),
        "mode": str(config.get("mode", "int")),
        "step": int(config.get("step", 1)),
        "requires": config.get("requires", []),
        "cost_multiplier": float(config.get("cost_multiplier", 1.0))
    }
    if normalized["extended_cap"] == 0:
        normalized["extended_cap"] = -1
    return normalized
