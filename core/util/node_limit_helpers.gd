# ==============================================================================
# Taj's Core - Node Limit Helpers
# Author: TajemnikTV
# Description: Helpers for node count and limit queries.
# ==============================================================================
class_name TajsCoreNodeLimitHelpers
extends RefCounted

const UNLIMITED := -1
var _override_limit: int = Utils.MAX_WINDOW
var _override_active := false

func get_node_count() -> int:
	if Globals == null:
		return 0
	return int(Globals.max_window_count)

func get_node_limit() -> int:
	var globals_limit: Variant = _get_globals_custom_limit()
	if globals_limit != null:
		return int(globals_limit)
	if _override_active:
		return _override_limit
	return Utils.MAX_WINDOW

func get_limit_label(limit: int) -> String:
	if limit < 0:
		return "Unlimited"
	return str(limit)

func set_node_limit(limit: int) -> void:
	_override_limit = int(limit)
	_override_active = true
	if Globals == null:
		return
	if _has_globals_custom_limit():
		Globals.custom_node_limit = _override_limit

func can_add_nodes(additional: int = 1) -> bool:
	var limit := get_node_limit()
	if limit < 0:
		return true
	return get_node_count() + max(additional, 0) <= limit

func _has_globals_custom_limit() -> bool:
	if Globals == null:
		return false
	for prop in Globals.get_property_list():
		if prop is Dictionary and prop.get("name", "") == "custom_node_limit":
			return true
	return false

func _get_globals_custom_limit() -> Variant:
	if not _has_globals_custom_limit():
		return null
	return Globals.get("custom_node_limit")
