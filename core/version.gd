# ==============================================================================
# Taj's Core - Version
# Author: TajemnikTV
# Description: Version
# ==============================================================================
class_name TajsCoreVersion
extends RefCounted

static func parse(version: String) -> Dictionary:
	var clean := version.strip_edges()
	var build_split := clean.split("+", false, 1)
	var base := build_split[0]
	var pre := ""
	if base.find("-") != -1:
		var parts := base.split("-", false, 1)
		base = parts[0]
		pre = parts[1]
	var nums := base.split(".")
	var major: int = int(nums[0]) if nums.size() > 0 and nums[0].is_valid_int() else 0
	var minor: int = int(nums[1]) if nums.size() > 1 and nums[1].is_valid_int() else 0
	var patch: int = int(nums[2]) if nums.size() > 2 and nums[2].is_valid_int() else 0
	var pre_parts: Array = []
	if pre != "":
		pre_parts = pre.split(".")
	return {
		"major": major,
		"minor": minor,
		"patch": patch,
		"pre": pre_parts
	}

static func compare_versions(a: String, b: String) -> int:
	var pa := parse(a)
	var pb := parse(b)
	if pa["major"] != pb["major"]:
		return -1 if pa["major"] < pb["major"] else 1
	if pa["minor"] != pb["minor"]:
		return -1 if pa["minor"] < pb["minor"] else 1
	if pa["patch"] != pb["patch"]:
		return -1 if pa["patch"] < pb["patch"] else 1
	return _compare_pre(pa["pre"], pb["pre"])

static func _compare_pre(a: Array, b: Array) -> int:
	if a.is_empty() and b.is_empty():
		return 0
	if a.is_empty() and not b.is_empty():
		return 1
	if not a.is_empty() and b.is_empty():
		return -1
	var count: int = min(a.size(), b.size())
	for i in range(count):
		var ai = a[i]
		var bi = b[i]
		var a_is_int: bool = ai is String and ai.is_valid_int()
		var b_is_int: bool = bi is String and bi.is_valid_int()
		if a_is_int and b_is_int:
			var a_num: int = int(ai)
			var b_num: int = int(bi)
			if a_num != b_num:
				return -1 if a_num < b_num else 1
		elif a_is_int and not b_is_int:
			return -1
		elif not a_is_int and b_is_int:
			return 1
		else:
			if str(ai) != str(bi):
				return -1 if str(ai) < str(bi) else 1
	if a.size() == b.size():
		return 0
	return -1 if a.size() < b.size() else 1
