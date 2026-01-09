# ==============================================================================
# Taj's Core - Hot Reload
# Author: TajemnikTV
# Description: Lightweight hot reload helper for dev workflows.
# ==============================================================================
class_name TajsCoreHotReload
extends Node

signal script_reloaded(path: String)

var _watch_paths: Dictionary = {}

func enable_hot_reload(mod_id: String, watch_paths: Array[String]) -> void:
	if mod_id == "":
		return
	_watch_paths[mod_id] = watch_paths.duplicate()

func trigger_reload(mod_id: String) -> void:
	if not _watch_paths.has(mod_id):
		return
	for path in _watch_paths[mod_id]:
		if ResourceLoader.exists(path):
			ResourceLoader.load(path, "GDScript", ResourceLoader.CACHE_MODE_REPLACE)
			emit_signal("script_reloaded", path)

func trigger_reload_all() -> void:
	for mod_id in _watch_paths.keys():
		trigger_reload(mod_id)
