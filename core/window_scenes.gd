# ==============================================================================
# Taj's Core - Window Scene Resolver
# Author: TajemnikTV
# Description: Resolve window scenes across mod directories and normalize saves.
# ==============================================================================
class_name TajsCoreWindowScenes
extends RefCounted

const BASE_DIR := "res://scenes/windows"
const SCENE_EXT := ".tscn"

var _extra_dirs: Array[String] = []
var _logger

func _init(logger = null) -> void:
	_logger = logger

func register_dir(dir_path: String) -> bool:
	if dir_path == "":
		return false
	if not dir_path.begins_with("res://"):
		_log_warn("windows", "Window dir must be res:// path: %s" % dir_path)
		return false
	if _extra_dirs.has(dir_path):
		return true
	if DirAccess.open(dir_path) == null:
		_log_warn("windows", "Window dir not found: %s" % dir_path)
		return false
	_extra_dirs.append(dir_path)
	return true

func register_mod_dir(mod_id: String, relative_dir: String = "scenes/windows") -> bool:
	var base := TajsCoreUtil.get_mod_path(mod_id)
	if base == "":
		return false
	return register_dir(base.path_join(relative_dir))

func list_dirs() -> Array:
	return _extra_dirs.duplicate()

func resolve_scene_path(scene: String) -> String:
	if scene == "":
		return ""
	if scene.begins_with("res://"):
		var full := scene
		if not full.ends_with(SCENE_EXT):
			full += SCENE_EXT
		return full

	var file_name := scene
	if not file_name.ends_with(SCENE_EXT):
		file_name += SCENE_EXT

	var base_path := BASE_DIR.path_join(file_name)
	if ResourceLoader.exists(base_path):
		return base_path

	for dir_path: String in _extra_dirs:
		var candidate := dir_path.path_join(file_name)
		if ResourceLoader.exists(candidate):
			return candidate

	return base_path

func make_save_filename(scene_path: String) -> String:
	if scene_path == "":
		return ""
	if TajsCoreUtil.has_global_class("TajsCoreNodeDefs"):
		return TajsCoreNodeDefs.make_save_filename(scene_path)
	var normalized := scene_path
	if normalized.begins_with("res://") and not normalized.ends_with(SCENE_EXT):
		normalized += SCENE_EXT
	if not normalized.begins_with("res://"):
		return ""
	return normalized.replace(BASE_DIR + "/", "")

func normalize_saved_windows(save_data: Dictionary) -> void:
	if save_data.is_empty():
		return
	if not save_data.has("windows"):
		return
	var windows = save_data["windows"]
	if not (windows is Dictionary):
		return
	for window_id in windows.keys():
		var entry = windows[window_id]
		if not (entry is Dictionary):
			continue
		if not entry.has("filename"):
			continue
		var filename := str(entry["filename"])
		if filename == "":
			continue
		var normalized := _normalize_filename(filename)
		if normalized != "":
			entry["filename"] = normalized

func _normalize_filename(filename: String) -> String:
	if filename.begins_with("res://"):
		if ResourceLoader.exists(filename):
			return make_save_filename(filename)
		var fixed := filename
		if not fixed.ends_with(SCENE_EXT):
			fixed += SCENE_EXT
		if ResourceLoader.exists(fixed):
			return make_save_filename(fixed)
		return ""

	var resolved := resolve_scene_path(filename)
	if resolved == "":
		return ""
	if not ResourceLoader.exists(resolved):
		return ""
	return make_save_filename(resolved)

func _log_warn(module_id: String, message: String) -> void:
	if _logger != null and _logger.has_method("warn"):
		_logger.warn(module_id, message)
