# ==============================================================================
# Taj's Core - Util
# Author: TajemnikTV
# Description: Adds utility functions to the Core
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

static func has_global_class(class_name_str: String) -> bool:
	for entry in ProjectSettings.get_global_class_list():
		if entry.get("class", "") == class_name_str:
			return true
	return false

static func get_mod_path(mod_id: String) -> String:
	if mod_id == "":
		return ""
	if has_global_class("ModLoaderMod"):
		return ModLoaderMod.get_unpacked_dir().path_join(mod_id)
	return "res://mods-unpacked".path_join(mod_id)

static func get_mod_data_path(mod_id: String) -> String:
	if mod_id == "":
		return "user://mods"
	var path := "user://mods".path_join(mod_id)
	if not DirAccess.dir_exists_absolute(path):
		DirAccess.make_dir_recursive_absolute(path)
	return path

static func resolve_texture_path(relative_path: String, mod_id: String) -> String:
	if relative_path == "":
		return ""
	if relative_path.begins_with("res://"):
		return relative_path
	var base := get_mod_path(mod_id)
	if base == "":
		return ""
	return base.path_join(relative_path)

static func format_number(value: float, notation: int = -1, hide_decimals: bool = true) -> String:
	if notation < 0:
		return Utils.print_string(value, hide_decimals)
	match notation:
		1:
			return Utils.to_latin(value, hide_decimals)
		2:
			return Utils.print_scientific(value, hide_decimals)
		3:
			return Utils.print_engineering(value, hide_decimals)
		_:
			return Utils.to_aa(value, hide_decimals)

static func format_time(seconds: float) -> String:
	if seconds < 0:
		seconds = 0
	var total := int(round(seconds))
	var secs := total % 60
	var mins := int(total / 60) % 60
	var hours := int(total / 3600)
	if hours > 0:
		return "%02d:%02d:%02d" % [hours, mins, secs]
	return "%02d:%02d" % [mins, secs]

static func format_percentage(value: float, decimals: int = 1) -> String:
	var percent := value * 100.0
	var fmt := "%." + str(decimals) + "f%%"
	return fmt % percent

static func parse_number(text: String) -> float:
	var cleaned := text.strip_edges().replace(",", "").to_lower()
	if cleaned == "":
		return 0.0
	if cleaned.find("e") != -1:
		return cleaned.to_float()
	var suffixes := Utils.suffixes
	for i in range(suffixes.size() - 1, -1, -1):
		var suffix: String = suffixes[i]
		if suffix == "":
			continue
		if cleaned.ends_with(suffix):
			var number_part := cleaned.substr(0, cleaned.length() - suffix.length())
			return number_part.to_float() * pow(1000.0, i)
	var latin := Utils.suffixes_latin
	for k in range(latin.size() - 1, -1, -1):
		var latin_suffix: String = str(latin[k]).to_lower()
		if latin_suffix == "":
			continue
		if cleaned.ends_with(latin_suffix):
			var number_part3 := cleaned.substr(0, cleaned.length() - latin_suffix.length())
			return number_part3.to_float() * pow(1000.0, k)
	var metric := Utils.metric
	for j in range(metric.size() - 1, -1, -1):
		var metric_suffix: String = metric[j].to_lower()
		if metric_suffix == "":
			continue
		if cleaned.ends_with(metric_suffix):
			var number_part2 := cleaned.substr(0, cleaned.length() - metric_suffix.length())
			return number_part2.to_float() * pow(1000.0, j)
	return cleaned.to_float()
