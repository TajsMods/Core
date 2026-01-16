# ==============================================================================
# Taj's Core - Economy Helpers
# Author: TajemnikTV
# Description: Helpers for currency and attribute adjustments.
# ==============================================================================
class_name TajsCoreEconomyHelpers
extends RefCounted

func has_currency(currency_id: String) -> bool:
	if Globals == null:
		return false
	if not (Globals.currencies is Dictionary):
		return false
	return Globals.currencies.has(currency_id)

func get_currency(currency_id: String, default_value: float = 0.0) -> float:
	if not has_currency(currency_id):
		return default_value
	return float(Globals.currencies.get(currency_id, default_value))

func set_currency(currency_id: String, value: float, clamp_zero: bool = true) -> bool:
	if not has_currency(currency_id):
		return false
	var new_value := float(value)
	if clamp_zero and new_value < 0.0:
		new_value = 0.0
	Globals.currencies[currency_id] = new_value
	_update_currency_caps(currency_id, new_value)
	_refresh_globals()
	return true

func add_currency(currency_id: String, delta: float, clamp_zero: bool = true) -> float:
	if not has_currency(currency_id):
		return 0.0
	var current := get_currency(currency_id, 0.0)
	var new_value := current + float(delta)
	if clamp_zero and new_value < 0.0:
		new_value = 0.0
	Globals.currencies[currency_id] = new_value
	_update_currency_caps(currency_id, new_value)
	_refresh_globals()
	return new_value

func has_attribute(attribute_id: String) -> bool:
	if Attributes == null:
		return false
	if not (Attributes.attributes is Dictionary):
		return false
	return Attributes.attributes.has(attribute_id)

func get_attribute(attribute_id: String, default_value: float = 0.0) -> float:
	if not has_attribute(attribute_id):
		return default_value
	return float(Attributes.get_attribute(attribute_id))

func set_attribute(attribute_id: String, value: float) -> bool:
	if not has_attribute(attribute_id):
		return false
	var current := get_attribute(attribute_id, 0.0)
	var delta := float(value) - current
	Attributes.attributes[attribute_id].add(delta, 0, 0, 0)
	_refresh_globals()
	return true

func add_attribute(attribute_id: String, amount: float) -> bool:
	if not has_attribute(attribute_id):
		return false
	Attributes.attributes[attribute_id].add(float(amount), 0, 0, 0)
	_refresh_globals()
	return true

func _update_currency_caps(currency_id: String, new_value: float) -> void:
	if currency_id == "money":
		Globals.max_money = max(Globals.max_money, new_value)
	elif currency_id == "research":
		Globals.max_research = max(Globals.max_research, new_value)

func _refresh_globals() -> void:
	if Globals != null and Globals.has_method("process"):
		Globals.process(0)
