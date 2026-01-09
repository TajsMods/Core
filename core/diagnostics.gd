# ==============================================================================
# Taj's Core - Diagnostics
# Author: TajemnikTV
# Description: 
# ==============================================================================
class_name TajsCoreDiagnostics
extends RefCounted

const DEFAULT_EXPORT_PATH := "user://tajs_core_diagnostics.json"

var _core
var _logger

func _init(core, logger = null) -> void:
	_core = core
	_logger = logger

func collect() -> Dictionary:
	var data := {}
	data["core_version"] = _core.get_version() if _core != null and _core.has_method("get_version") else "unknown"
	data["api_level"] = _core.get_api_level() if _core != null and _core.has_method("get_api_level") else 0
	data["godot_version"] = Engine.get_version_info()
	data["mod_loader_version"] = _try_get_mod_loader_version()
	data["modules"] = _core.module_registry.list_modules() if _core != null and _core.module_registry != null else []
	data["settings"] = _core.settings.get_snapshot(true) if _core != null and _core.settings != null else {}
	data["keybinds"] = _core.keybinds.get_actions_for_ui() if _core != null and _core.keybinds != null else []
	data["keybind_conflicts"] = _core.keybinds.get_conflicts() if _core != null and _core.keybinds != null else []
	data["keybind_conflicts_summary"] = {
		"count": data["keybind_conflicts"].size()
	}
	if _core != null and _core.node_registry != null:
		data["nodes"] = {
			"count": _core.node_registry.get_mod_node_count(),
			"mods": _core.node_registry.get_mod_nodes()
		}
	data["patches"] = _core.patches.list_applied() if _core != null and _core.patches != null else []
	data["logs"] = _core.logger.get_entries() if _core != null and _core.logger != null else []
	return data

func export_json(path: String = "") -> Dictionary:
	var json_string := JSON.stringify(collect(), "\t")
	var output_path := path
	if output_path == "":
		output_path = DEFAULT_EXPORT_PATH
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file != null:
		file.store_string(json_string)
		file.close()
	return {"path": output_path, "json": json_string}

func self_test() -> Dictionary:
	var checks: Array = []
	var ok: bool = true
	if _core != null and _core.has_method("compare_versions"):
		var cmp: int = _core.compare_versions("1.0.0", "1.0.1")
		var pass_check: bool = cmp < 0
		checks.append({"name": "version_compare", "ok": pass_check})
		ok = ok and pass_check
	if _core != null and _core.settings != null:
		_core.settings.set_value("core.self_test", true)
		var pass2: bool = _core.settings.get_bool("core.self_test", false)
		checks.append({"name": "settings_roundtrip", "ok": pass2})
		ok = ok and pass2
	if _core != null and _core.event_bus != null:
		var flag: bool = false
		_core.event_bus.on("core.self_test", func(_payload): flag = true, self, true)
		_core.event_bus.emit("core.self_test", {})
		checks.append({"name": "event_bus", "ok": flag})
		ok = ok and flag
	var result := {"ok": ok, "checks": checks}
	_log_info("diagnostics", "Self-test results: %s" % str(result))
	return result

func _try_get_mod_loader_version() -> String:
	if ClassDB.class_exists("ModLoader") and ClassDB.class_has_method("ModLoader", "get_version"):
		return str(ModLoader.get_version())
	return "unknown"

func _log_info(module_id: String, message: String) -> void:
	if _logger != null and _logger.has_method("info"):
		_logger.info(module_id, message)
