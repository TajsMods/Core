extends "res://scripts/utils.gd"

func get_variation_quality_multiplier(variation: int) -> float:
	var multiplier := super (variation)
	multiplier *= _get_core_variation_multiplier(variation, "quality")
	return multiplier

func get_variation_value_multiplier(variation: int) -> float:
	var multiplier := super (variation)
	multiplier *= _get_core_variation_multiplier(variation, "value")
	return multiplier

func get_variation_research_multiplier(variation: int) -> float:
	var multiplier := super (variation)
	multiplier *= _get_core_variation_multiplier(variation, "research")
	return multiplier

func get_variation_neuron_multiplier(variation: int) -> float:
	var multiplier := super (variation)
	multiplier *= _get_core_variation_multiplier(variation, "neuron")
	return multiplier

func get_variation_size_multiplier(variation: int) -> float:
	var multiplier := super (variation)
	multiplier *= _get_core_variation_multiplier(variation, "size")
	return multiplier

func get_resource_symbols(type: String, variation: int) -> String:
	var symbols = super (type, variation)
	if symbols == null:
		symbols = ""
	var core = Engine.get_meta("TajsCore", null)
	if core != null and core.file_variations != null:
		symbols += core.file_variations.get_symbols(type, variation)
	return symbols

func can_add_window(window: String) -> bool:
	if not super (window):
		return false
	var limit := _get_node_limit()
	if limit >= 0 and Globals.max_window_count >= limit:
		return false
	return true

func _get_core_variation_multiplier(variation: int, key: String) -> float:
	var core = Engine.get_meta("TajsCore", null)
	if core == null or core.file_variations == null:
		return 1.0
	return core.file_variations.get_multiplier(variation, key)

func _get_node_limit() -> int:
	var helper = _get_node_limit_helpers()
	if helper != null and helper.has_method("get_node_limit"):
		return helper.get_node_limit()
	return Utils.MAX_WINDOW

func _get_node_limit_helpers() -> Object:
	var core = Engine.get_meta("TajsCore", null)
	if core != null and core.has_method("get"):
		return core.get("node_limit_helpers")
	return null
