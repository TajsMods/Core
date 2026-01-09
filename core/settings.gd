# ==============================================================================
# Taj's Core - Settings
# Author: TajemnikTV
# Description: Settings
# ==============================================================================
class_name TajsCoreSettings
extends RefCounted

signal value_changed(key: String, value: Variant, old_value: Variant)

const CONFIG_PATH := "user://tajs_core_settings.json"

var _values: Dictionary = {}
var _meta: Dictionary = {}
var _schemas: Dictionary = {}
var _logger

func _init(logger = null) -> void:
	_logger = logger
	load_settings()

func load_settings() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		_values = {}
		_meta = {"migrations": {}}
		save_settings()
		_log_info("settings", "No settings file found, created defaults.")
		return
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		_log_warn("settings", "Failed to open settings file for reading.")
		return
	var json_string := file.get_as_text()
	file.close()
	var json := JSON.new()
	var result := json.parse(json_string)
	if result != OK:
		_log_warn("settings", "Settings JSON parse error: %s" % json.get_error_message())
		return
	var data = json.get_data()
	if data is Dictionary:
		if data.has("values"):
			_values = data.get("values", {})
			_meta = data.get("meta", {})
		else:
			_values = data
			_meta = {"migrations": {}}
		if not _meta.has("migrations"):
			_meta["migrations"] = {}
		_log_info("settings", "Settings loaded.")
	else:
		_log_warn("settings", "Settings file malformed, expected a dictionary.")

func save_settings() -> void:
	var payload := {
		"values": _values,
		"meta": _meta
	}
	var file := FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if file == null:
		_log_warn("settings", "Failed to open settings file for writing.")
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()

func register_schema(module_id: String, schema: Dictionary) -> void:
	var changed := false
	for key in schema.keys():
		var entry = schema[key]
		if entry is Dictionary:
			_schemas[key] = entry
			if not key.contains("."):
				_log_warn(module_id, "Settings key '%s' is not namespaced." % key)
			if not _values.has(key) and entry.has("default"):
				_values[key] = entry["default"]
				changed = true
		else:
			_log_warn(module_id, "Settings schema entry for '%s' must be a dictionary." % key)
	if changed:
		save_settings()

func get_value(key: String, default_override = null):
	if _values.has(key):
		return _values[key]
	if _schemas.has(key) and _schemas[key].has("default"):
		return _schemas[key]["default"]
	return default_override

func set_value(key: String, value) -> void:
	var old_value = _values.get(key)
	_values[key] = value
	save_settings()
	emit_signal("value_changed", key, value, old_value)

func get_bool(key: String, default_value: bool = false) -> bool:
	var value = get_value(key, default_value)
	if typeof(value) == TYPE_BOOL:
		return value
	_log_warn("settings", "Expected bool for '%s', got %s" % [key, typeof(value)])
	return default_value

func get_int(key: String, default_value: int = 0) -> int:
	var value = get_value(key, default_value)
	if typeof(value) == TYPE_INT:
		return value
	if typeof(value) == TYPE_FLOAT:
		return int(value)
	_log_warn("settings", "Expected int for '%s', got %s" % [key, typeof(value)])
	return default_value

func get_float(key: String, default_value: float = 0.0) -> float:
	var value = get_value(key, default_value)
	if typeof(value) == TYPE_FLOAT:
		return value
	if typeof(value) == TYPE_INT:
		return float(value)
	_log_warn("settings", "Expected float for '%s', got %s" % [key, typeof(value)])
	return default_value

func get_string(key: String, default_value: String = "") -> String:
	var value = get_value(key, default_value)
	if typeof(value) == TYPE_STRING:
		return value
	_log_warn("settings", "Expected string for '%s', got %s" % [key, typeof(value)])
	return default_value

func get_dict(key: String, default_value: Dictionary = {}) -> Dictionary:
	var value = get_value(key, default_value)
	if value is Dictionary:
		return value
	_log_warn("settings", "Expected dictionary for '%s', got %s" % [key, typeof(value)])
	return default_value

func get_snapshot(redact_sensitive: bool = true) -> Dictionary:
	var snapshot := _values.duplicate(true)
	if not redact_sensitive:
		return snapshot
	for key in _schemas.keys():
		var entry = _schemas[key]
		if entry is Dictionary and entry.get("sensitive", false):
			if snapshot.has(key):
				snapshot[key] = "<redacted>"
	return snapshot

func get_migration_version(ns: String) -> String:
	if _meta.has("migrations") and _meta["migrations"].has(ns):
		return str(_meta["migrations"][ns])
	return "0.0.0"

func set_migration_version(ns: String, version: String) -> void:
	if not _meta.has("migrations"):
		_meta["migrations"] = {}
	_meta["migrations"][ns] = version
	save_settings()

func _log_info(module_id: String, message: String) -> void:
	if _logger != null and _logger.has_method("info"):
		_logger.info(module_id, message)

func _log_warn(module_id: String, message: String) -> void:
	if _logger != null and _logger.has_method("warn"):
		_logger.warn(module_id, message)
