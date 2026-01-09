# ==============================================================================
# Taj's Core - Patches
# Author: TajemnikTV
# Description: Patches
# ==============================================================================
class_name TajsCorePatches
extends RefCounted

var _applied: Dictionary = {}
var _script_patches: Dictionary = {}
var _registered: Dictionary = {}
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

func register_patch(patch_id: String, script_path: String, target: String, replacement: String) -> void:
	if patch_id == "" or script_path == "" or target == "":
		return
	_registered[patch_id] = {
		"script_path": script_path,
		"target": target,
		"replacement": replacement
	}
	patch_script(script_path, target, replacement, patch_id)

func patch_script(script_path: String, target: String, replacement: String, patch_id: String = "") -> bool:
	if script_path == "" or target == "":
		return false
	var source := _get_script_source(script_path)
	if source == "":
		_log_warn("patches", "Failed to load script source: %s" % script_path)
		return false
	if not source.contains(target):
		_log_warn("patches", "Target not found in script: %s" % script_path)
		return false
	var patched := source.replace(target, replacement)
	var script := GDScript.new()
	script.source_code = patched
	script.resource_path = script_path
	if script.reload() != OK:
		_log_warn("patches", "Patched script failed to reload: %s" % script_path)
		return false
	script.take_over_path(script_path)
	if patch_id == "":
		patch_id = "%s:%s" % [script_path, target]
	_track_script_patch(script_path, patch_id)
	return true

func reload_script(script_path: String) -> bool:
	if script_path == "":
		return false
	if not ResourceLoader.exists(script_path):
		return false
	var res := ResourceLoader.load(script_path, "GDScript", ResourceLoader.CACHE_MODE_REPLACE)
	return res != null

func is_script_patched(script_path: String, patch_id: String) -> bool:
	if not _script_patches.has(script_path):
		return false
	return _script_patches[script_path].has(patch_id)

func _get_script_source(script_path: String) -> String:
	if FileAccess.file_exists(script_path):
		return FileAccess.get_file_as_string(script_path)
	if ResourceLoader.exists(script_path):
		var script = load(script_path)
		if script is GDScript:
			return script.source_code
	return ""

func _track_script_patch(script_path: String, patch_id: String) -> void:
	if not _script_patches.has(script_path):
		_script_patches[script_path] = []
	if not _script_patches[script_path].has(patch_id):
		_script_patches[script_path].append(patch_id)

func _log_warn(module_id: String, message: String) -> void:
	if _logger != null and _logger.has_method("warn"):
		_logger.warn(module_id, message)
