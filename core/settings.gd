class_name TajsCoreSettings
extends RefCounted

signal value_changed(key: String, value: Variant, old_value: Variant)
signal settings_synced(settings_namespace: String)

const CONFIG_PATH := "user://tajs_core_settings.json"

var _values: Dictionary = {}
var _meta: Dictionary = {}
var _schemas: Dictionary = {}
var _restart_baseline: Dictionary = {}
var _batch_depth: int = 0
var _pending_save := false
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
    _pending_save = false

func begin_batch() -> void:
    _batch_depth += 1

func end_batch(save := true) -> void:
    if _batch_depth <= 0:
        _batch_depth = 0
        _flush_pending_if_ready(save)
        return
    _batch_depth -= 1
    if _batch_depth == 0:
        _flush_pending_if_ready(save)

# Schema entry fields (v1) are optional except "default". Used by Settings Hub UI.
# - type: "bool" | "int" | "float" | "string" | "enum" | "keybind" | "action" | "dict" | "array"
# - label, description, category, min, max, step, options, requires_restart, experimental, hidden, sensitive, depends_on
# Example:
# var schema := {
#     "qol.autosort.enabled": {
#         "type": "bool",
#         "default": true,
#         "label": "Auto-sort",
#         "category": "UI",
#         "description": "Automatically sorts items."
#     }
# }
func register_schema(module_id: String, schema: Dictionary, namespace_prefix: String = "") -> void:
    var changed := false
    var expected_prefix := module_id
    if namespace_prefix != "":
        expected_prefix = namespace_prefix
    for key in schema.keys():
        var entry = schema[key]
        if entry is Dictionary:
            var stored: Dictionary = entry.duplicate(true)
            if module_id != "" and not stored.has("module_id"):
                stored["module_id"] = module_id
            _schemas[key] = stored
            if not key.contains("."):
                _log_warn(module_id, "Settings key '%s' is not namespaced." % key)
            if expected_prefix != "" and not str(key).begins_with(expected_prefix + "."):
                _log_warn(module_id, "Settings key '%s' does not start with '%s.'." % [key, expected_prefix])
            if not _values.has(key) and stored.has("default"):
                if _apply_value(str(key), stored["default"], false, false):
                    changed = true
            elif _values.has(key):
                var sanitized := _sanitize_value(str(key), _values[key], stored, module_id)
                if sanitized.ok or sanitized.used_default:
                    if _apply_value(str(key), sanitized.value, false, false):
                        changed = true
            _register_restart_baseline(str(key), stored)
        else:
            _log_warn(module_id, "Settings schema entry for '%s' must be a dictionary." % key)
    if changed:
        _flush_pending_if_ready(true)

func is_restart_pending(key: String) -> bool:
    if not _restart_baseline.has(key):
        return false
    var schema_entry := _get_schema_entry(key)
    var default_value = _get_schema_default_from_entry(schema_entry) if schema_entry.has("default") else null
    var current_value = _values.get(key, default_value)
    return current_value != _restart_baseline[key]

func _register_restart_baseline(key: String, schema_entry: Dictionary) -> void:
    if not schema_entry.get("requires_restart", false):
        return
    if _restart_baseline.has(key):
        return
    var default_value = _get_schema_default_from_entry(schema_entry) if schema_entry.has("default") else null
    var value = _values.get(key, default_value)
    _restart_baseline[key] = _duplicate_if_collection(value)


func register_section(section_id: String, defaults: Dictionary) -> void:
    if section_id == "":
        return
    if not (defaults is Dictionary):
        _log_warn(section_id, "Settings section defaults must be a dictionary.")
        return
    var schema := {}
    for key in defaults.keys():
        var full_key := "%s.%s" % [section_id, str(key)]
        schema[full_key] = {"default": defaults[key]}
    register_schema(section_id, schema)


func get_section_value(section_id: String, key: String, default_override = null):
    if section_id == "" or key == "":
        return default_override
    return get_value("%s.%s" % [section_id, key], default_override)


func set_section_value(section_id: String, key: String, value) -> void:
    if section_id == "" or key == "":
        return
    set_value("%s.%s" % [section_id, key], value)

func get_value(key: String, default_override = null):
    if _values.has(key):
        return _values[key]
    if _schemas.has(key) and _schemas[key].has("default"):
        return _schemas[key]["default"]
    return default_override

func set_value(key: String, value, save := true) -> void:
    var schema_entry := _get_schema_entry(key)
    var sanitized := _sanitize_value(key, value, schema_entry, "settings")
    if not sanitized.ok and not sanitized.used_default:
        return
    _apply_value(key, sanitized.value, save, true)

func get_bool(key: String, default_value: bool = false) -> bool:
    var value = get_value(key, default_value)
    if typeof(value) == TYPE_BOOL:
        return value
    _log_warn("settings", "Expected bool for '%s', got %s" % [key, typeof(value)])
    return default_value


func toggle_value(key: String, default_value: bool = false) -> bool:
    var current := get_bool(key, default_value)
    var next := not current
    set_value(key, next)
    return next

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

func get_dict(key: String, default_value: Variant = null) -> Dictionary:
    var fallback: Dictionary = {}
    if default_value is Dictionary:
        fallback = default_value
    var value = get_value(key, fallback)
    if value is Dictionary:
        return value.duplicate(true)
    _log_warn("settings", "Expected dictionary for '%s', got %s" % [key, typeof(value)])
    return fallback.duplicate(true)

func get_array(key: String, default_value: Variant = null) -> Array:
    var fallback: Array = []
    if default_value is Array:
        fallback = default_value
    var value = get_value(key, fallback)
    if value is Array:
        return value.duplicate(true)
    _log_warn("settings", "Expected array for '%s', got %s" % [key, typeof(value)])
    return fallback.duplicate(true)

func get_schemas_for_namespace(ns_prefix: String) -> Dictionary:
    #Returns all registered schema entries that start with the given namespace prefix.
    var result := {}
    var prefix := _normalize_prefix(ns_prefix)
    for key in _schemas.keys():
        if prefix == "" or key.begins_with(prefix):
            result[key] = _schemas[key]
    return result

func get_schemas_for_module(module_id: String) -> Dictionary:
    # Returns all registered schema entries tagged with the given module id.
    var result := {}
    if module_id == "":
        return result
    for key in _schemas.keys():
        var entry = _schemas[key]
        if entry is Dictionary and str(entry.get("module_id", "")) == module_id:
            result[key] = entry
    return result

func get_all_schemas() -> Dictionary:
    #Returns all registered schemas."""
    return _schemas.duplicate(true)

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

func is_default(key: String) -> bool:
    var schema_entry := _get_schema_entry(key)
    if schema_entry.has("default"):
        var default_value = _get_schema_default_from_entry(schema_entry)
        var value = _values.get(key, default_value)
        return value == default_value
    return not _values.has(key)

func reset_key(key: String, save := true) -> void:
    if is_default(key):
        return
    var schema_entry := _get_schema_entry(key)
    if schema_entry.has("default"):
        _apply_value(key, schema_entry["default"], save, true)
        return
    if _values.has(key):
        var old_value = _values.get(key)
        _values.erase(key)
        _pending_save = true
        _flush_pending_if_ready(save)
        emit_signal("value_changed", key, null, old_value)

func reset_namespace(ns_prefix: String, save := true) -> int:
    var count := 0
    var prefix := _normalize_prefix(ns_prefix)
    begin_batch()
    for key in _schemas.keys():
        if prefix == "" or key.begins_with(prefix):
            if not is_default(key):
                reset_key(key, false)
                count += 1
    end_batch(save)
    return count

func get_changed_keys(ns_prefix: String = "") -> Array[String]:
    var keys: Array[String] = []
    var prefix := _normalize_prefix(ns_prefix)
    for key in _schemas.keys():
        if prefix != "" and not key.begins_with(prefix):
            continue
        if not is_default(key):
            keys.append(key)
    return keys

func get_entries_for_namespace(ns_prefix: String, include_hidden := false) -> Array[Dictionary]:
    var entries: Array[Dictionary] = []
    var prefix := _normalize_prefix(ns_prefix)
    for key in _schemas.keys():
        if prefix != "" and not key.begins_with(prefix):
            continue
        var schema_entry := _get_schema_entry(key)
        if not include_hidden and schema_entry.get("hidden", false):
            continue
        var default_value = _get_schema_default_from_entry(schema_entry) if schema_entry.has("default") else null
        var current_value = _values.get(key, default_value)
        if current_value is Dictionary or current_value is Array:
            current_value = current_value.duplicate(true)
        var is_default_value := is_default(key)
        entries.append({
            "key": key,
            "schema": schema_entry.duplicate(true),
            "value": current_value,
            "is_default": is_default_value,
            "is_changed": not is_default_value
        })
    return entries

func export_settings(settings_namespace: String) -> String:
    var values := {}
    var prefix := _normalize_prefix(settings_namespace)
    for key in _values.keys():
        if prefix == "" or key.begins_with(prefix):
            values[key] = _values[key]
    return JSON.stringify({"namespace": settings_namespace, "values": values}, "\t")

func import_settings(settings_namespace: String, data: String, dry_run := false) -> Variant:
    if data == "":
        if dry_run:
            return []
        return false
    var json := JSON.new()
    var result := json.parse(data)
    if result != OK:
        _log_warn("settings", "Import failed: %s" % json.get_error_message())
        if dry_run:
            return []
        return false
    var payload = json.get_data()
    if not (payload is Dictionary):
        if dry_run:
            return []
        return false
    var values = payload.get("values", {})
    if not (values is Dictionary):
        if dry_run:
            return []
        return false
    var changes := _collect_import_changes(settings_namespace, values)
    if dry_run:
        return changes
    var changed := false
    begin_batch()
    for entry in changes:
        if not entry.get("ok", false):
            continue
        if not entry.get("would_change", false):
            continue
        var key: String = entry.get("key", "")
        if key == "":
            continue
        _apply_value(key, entry.get("new_value"), false, true)
        changed = true
    end_batch(true)
    if changed:
        emit_signal("settings_synced", settings_namespace)
    return true

func preview_import(settings_namespace: String, data: String) -> Array[Dictionary]:
    var result = import_settings(settings_namespace, data, true)
    if result is Array:
        return result
    return []

func apply_key_migration(rename_map: Dictionary, ns_prefix := "", save := true) -> int:
    if rename_map.is_empty():
        return 0
    var count := 0
    var prefix := _normalize_prefix(ns_prefix)
    begin_batch()
    for old_key in rename_map.keys():
        var old_key_str := str(old_key)
        if prefix != "" and not old_key_str.begins_with(prefix):
            continue
        if not _values.has(old_key_str):
            continue
        var new_key := str(rename_map[old_key])
        if new_key == "" or new_key == old_key_str:
            continue
        if _values.has(new_key):
            continue
        set_value(new_key, _values[old_key_str], false)
        if _values.has(new_key):
            _values.erase(old_key_str)
            count += 1
    end_batch(save)
    return count

func get_migration_version(ns: String) -> String:
    if _meta.has("migrations") and _meta["migrations"].has(ns):
        return str(_meta["migrations"][ns])
    return "0.0.0"

func set_migration_version(ns: String, version: String) -> void:
    if not _meta.has("migrations"):
        _meta["migrations"] = {}
    _meta["migrations"][ns] = version
    save_settings()

func _collect_import_changes(settings_namespace: String, values: Dictionary) -> Array[Dictionary]:
    var changes: Array[Dictionary] = []
    var prefix := _normalize_prefix(settings_namespace)
    for key in values.keys():
        var key_str := str(key)
        if prefix != "" and not key_str.begins_with(prefix):
            continue
        var raw_value = values[key]
        var schema_entry := _get_schema_entry(key_str)
        var sanitized := _sanitize_value(key_str, raw_value, schema_entry, "settings")
        var ok: bool = sanitized.ok or sanitized.used_default
        var old_value = _values.get(key_str)
        var new_value = raw_value
        if ok:
            new_value = sanitized.value
        var would_change: bool = ok and (not _values.has(key_str) or old_value != new_value)
        changes.append({
            "key": key_str,
            "old_value": old_value,
            "new_value": new_value,
            "ok": ok,
            "reason": sanitized.reason,
            "coerced": sanitized.coerced,
            "used_default": sanitized.used_default,
            "would_change": would_change
        })
    return changes

func _sanitize_value(key: String, value: Variant, schema_entry: Dictionary, log_context: String = "settings") -> Dictionary:
    var result := {
        "ok": true,
        "value": value,
        "reason": "",
        "coerced": false,
        "used_default": false
    }
    if schema_entry.is_empty():
        return result
    var entry_type := str(schema_entry.get("type", ""))
    if entry_type == "" and schema_entry.has("default"):
        entry_type = _infer_type_from_default(schema_entry["default"])
    var has_type := entry_type != ""
    if has_type:
        match entry_type:
            "bool":
                if typeof(value) != TYPE_BOOL:
                    _mark_invalid_with_default(result, schema_entry, "expected bool")
            "int":
                if typeof(value) == TYPE_INT:
                    pass
                elif typeof(value) == TYPE_FLOAT:
                    result.value = int(value)
                    result.coerced = true
                    result.reason = "coerced float to int"
                else:
                    _mark_invalid_with_default(result, schema_entry, "expected int")
            "float":
                if typeof(value) == TYPE_FLOAT:
                    pass
                elif typeof(value) == TYPE_INT:
                    result.value = float(value)
                    result.coerced = true
                    result.reason = "coerced int to float"
                else:
                    _mark_invalid_with_default(result, schema_entry, "expected float")
            "string":
                if typeof(value) != TYPE_STRING:
                    _mark_invalid_with_default(result, schema_entry, "expected string")
            "enum":
                var options = schema_entry.get("options", [])
                if not (options is Array):
                    _mark_invalid_with_default(result, schema_entry, "enum options missing")
                else:
                    var allowed_values: Array = []
                    for option in options:
                        if option is Dictionary and option.has("value"):
                            allowed_values.append(option.get("value"))
                        else:
                            allowed_values.append(option)
                    # Coerce float to int if all allowed values are integers (JSON loads numbers as floats)
                    var check_value = value
                    if typeof(value) == TYPE_FLOAT and not allowed_values.is_empty():
                        var all_int := true
                        for av in allowed_values:
                            if typeof(av) != TYPE_INT:
                                all_int = false
                                break
                        if all_int:
                            check_value = int(value)
                            if check_value != value:
                                result.coerced = true
                                result.reason = "coerced float to int for enum"
                            result.value = check_value
                    if not allowed_values.has(check_value):
                        _mark_invalid_with_default(result, schema_entry, "value not in options")
            "dict":
                if not (value is Dictionary):
                    _mark_invalid_with_default(result, schema_entry, "expected dict")
            "array":
                if not (value is Array):
                    _mark_invalid_with_default(result, schema_entry, "expected array")
            "keybind":
                if not (value is Dictionary or value is Array or typeof(value) == TYPE_STRING):
                    _mark_invalid_with_default(result, schema_entry, "expected keybind data")
            "action":
                pass
            _:
                pass
    if result.ok or result.used_default:
        var numeric_value = result.value
        if typeof(numeric_value) == TYPE_INT or typeof(numeric_value) == TYPE_FLOAT:
            var has_min := schema_entry.has("min")
            var has_max := schema_entry.has("max")
            if has_min or has_max:
                var min_value := float(schema_entry.get("min", numeric_value))
                var max_value := float(schema_entry.get("max", numeric_value))
                var clamped: float = clamp(float(numeric_value), min_value, max_value)
                if typeof(numeric_value) == TYPE_INT:
                    clamped = int(clamped)
                if clamped != numeric_value:
                    result.value = clamped
                    result.coerced = true
                    result.reason = "clamped to range"
    if result.coerced:
        _log_warn(log_context, "Coerced settings value for '%s': %s" % [key, result.reason])
    if result.used_default:
        _log_warn(log_context, "Invalid settings value for '%s' (%s), using default." % [key, result.reason])
    elif not result.ok:
        _log_warn(log_context, "Rejected settings value for '%s' (%s)." % [key, result.reason])
    return result

func _mark_invalid_with_default(result: Dictionary, schema_entry: Dictionary, reason: String) -> void:
    result.ok = false
    result.reason = reason
    if schema_entry.has("default"):
        result.value = _get_schema_default_from_entry(schema_entry)
        result.used_default = true

func _get_schema_entry(key: String) -> Dictionary:
    if not _schemas.has(key):
        return {}
    var entry = _schemas[key]
    if entry is Dictionary:
        var normalized: Dictionary = entry.duplicate(true)
        if not normalized.has("type") and normalized.has("default"):
            var inferred := _infer_type_from_default(normalized["default"])
            if inferred != "":
                normalized["type"] = inferred
        return normalized
    return {}

func _infer_type_from_default(default_value: Variant) -> String:
    match typeof(default_value):
        TYPE_BOOL:
            return "bool"
        TYPE_INT:
            return "int"
        TYPE_FLOAT:
            return "float"
        TYPE_STRING:
            return "string"
        TYPE_DICTIONARY:
            return "dict"
        TYPE_ARRAY:
            return "array"
        _:
            return ""

func _get_schema_default_from_entry(schema_entry: Dictionary):
    if not schema_entry.has("default"):
        return null
    var default_value = schema_entry["default"]
    return _duplicate_if_collection(default_value)

func _duplicate_if_collection(value: Variant):
    if value is Dictionary:
        return value.duplicate(true)
    if value is Array:
        return value.duplicate(true)
    return value

func _normalize_prefix(ns_prefix: String) -> String:
    if ns_prefix == "":
        return ""
    return ns_prefix + "." if not ns_prefix.ends_with(".") else ns_prefix

func _apply_value(key: String, value: Variant, save: bool, emit_change: bool) -> bool:
    var old_value = _values.get(key)
    var new_value = _duplicate_if_collection(value)
    if _values.has(key) and old_value == new_value:
        # Value unchanged, but still flush pending saves if requested
        _flush_pending_if_ready(save)
        return false
    _values[key] = new_value
    _pending_save = true
    _flush_pending_if_ready(save)
    if emit_change:
        emit_signal("value_changed", key, new_value, old_value)
    return true

func _flush_pending_if_ready(save: bool) -> void:
    if not save:
        return
    if _batch_depth > 0:
        return
    if _pending_save:
        save_settings()

func _log_info(module_id: String, message: String) -> void:
    if _logger != null and _logger.has_method("info"):
        _logger.info(module_id, message)

func _log_warn(module_id: String, message: String) -> void:
    if _logger != null and _logger.has_method("warn"):
        _logger.warn(module_id, message)
