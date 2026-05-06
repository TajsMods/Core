class_name TajsCoreHookHealth
extends RefCounted

const STATUS_HEALTHY := "healthy"
const STATUS_WARNING := "warning"
const STATUS_FAILED := "failed"

var _logger: Variant = null
var _entries: Array[Dictionary] = []
var _entry_index: Dictionary = {} # key -> index in _entries
var _attempts: Dictionary = {} # key -> count

func _init(logger: Variant = null) -> void:
    _logger = logger

func report_hook_status(mod_id: String, target: String, status: String, details: Dictionary = {}) -> Dictionary:
    var normalized_mod_id := _normalize_mod_id(mod_id)
    var normalized_target := _normalize_target(target)
    var normalized_status := _normalize_status(status)
    var safe_details := details if details is Dictionary else {}
    var method_name := str(safe_details.get("method", "")).strip_edges()
    var property_name := str(safe_details.get("property", "")).strip_edges()
    var phase := str(safe_details.get("phase", "")).strip_edges()

    var key := _build_key(normalized_mod_id, normalized_target, method_name, property_name, phase)
    var attempts := int(_attempts.get(key, 0)) + 1
    _attempts[key] = attempts

    var duplicate_attempt := attempts > 1
    var reason := _derive_reason(normalized_status, safe_details, duplicate_attempt, attempts)

    var entry := {
        "mod_id": normalized_mod_id,
        "target": normalized_target,
        "status": normalized_status,
        "reason": reason,
        "attempts": attempts,
        "updated_at_unix": Time.get_unix_time_from_system(),
        "details": _sanitize_details(safe_details)
    }

    if duplicate_attempt and normalized_status == STATUS_HEALTHY:
        entry["status"] = STATUS_WARNING
        entry["reason"] = "Duplicate hook attempt (%d) for same target binding." % attempts

    if _entry_index.has(key):
        var existing_index := int(_entry_index[key])
        _entries[existing_index] = entry
    else:
        _entry_index[key] = _entries.size()
        _entries.append(entry)

    if str(entry.get("status", "")) == STATUS_FAILED:
        _log_warn("Hook failed for %s on %s: %s" % [normalized_mod_id, normalized_target, str(entry.get("reason", ""))])
    elif str(entry.get("status", "")) == STATUS_WARNING:
        _log_warn("Hook warning for %s on %s: %s" % [normalized_mod_id, normalized_target, str(entry.get("reason", ""))])
    return entry.duplicate(true)

func get_hook_health() -> Dictionary:
    var healthy := 0
    var warning := 0
    var failed := 0
    var failed_entries: Array[Dictionary] = []
    var warning_entries: Array[Dictionary] = []
    var entries: Array[Dictionary] = []

    for entry: Dictionary in _entries:
        entries.append(entry.duplicate(true))
        var status := str(entry.get("status", STATUS_WARNING))
        match status:
            STATUS_HEALTHY:
                healthy += 1
            STATUS_FAILED:
                failed += 1
                failed_entries.append(entry.duplicate(true))
            _:
                warning += 1
                warning_entries.append(entry.duplicate(true))

    _sort_entries(entries)
    _sort_entries(failed_entries)
    _sort_entries(warning_entries)

    return {
        "counts": {
            "healthy": healthy,
            "warning": warning,
            "failed": failed,
            "total": entries.size()
        },
        "failed_hooks": failed_entries,
        "warnings": warning_entries,
        "entries": entries
    }

func has_failed_hooks(mod_id: String = "") -> bool:
    var normalized_mod_id := mod_id.strip_edges()
    for entry: Dictionary in _entries:
        if str(entry.get("status", "")) != STATUS_FAILED:
            continue
        if normalized_mod_id == "":
            return true
        if str(entry.get("mod_id", "")).strip_edges() == normalized_mod_id:
            return true
    return false

func _normalize_mod_id(mod_id: String) -> String:
    var normalized := mod_id.strip_edges()
    return normalized if normalized != "" else "unknown_mod"

func _normalize_target(target: String) -> String:
    var normalized := target.strip_edges()
    return normalized if normalized != "" else "unknown_target"

func _normalize_status(status: String) -> String:
    var normalized := status.strip_edges().to_lower()
    match normalized:
        STATUS_HEALTHY, STATUS_WARNING, STATUS_FAILED:
            return normalized
    return STATUS_WARNING

func _build_key(mod_id: String, target: String, method_name: String, property_name: String, phase: String) -> String:
    var method_part := method_name if method_name != "" else "-"
    var property_part := property_name if property_name != "" else "-"
    var phase_part := phase if phase != "" else "-"
    return "%s|%s|%s|%s|%s" % [mod_id, target, method_part, property_part, phase_part]

func _derive_reason(status: String, details: Dictionary, duplicate_attempt: bool, attempts: int) -> String:
    var explicit_reason := str(details.get("reason", "")).strip_edges()
    if explicit_reason != "":
        if duplicate_attempt and status != STATUS_FAILED:
            return "%s Duplicate attempts: %d." % [explicit_reason, attempts]
        return explicit_reason
    if details.get("missing_target_script", false):
        return "Target script is missing."
    if details.has("missing_methods"):
        var methods: Array = _to_string_array(details.get("missing_methods", []))
        if not methods.is_empty():
            return "Missing methods on target: %s." % ", ".join(methods)
    if details.has("missing_properties"):
        var properties: Array = _to_string_array(details.get("missing_properties", []))
        if not properties.is_empty():
            return "Missing properties on target: %s." % ", ".join(properties)
    if details.get("scene_lookup_failed", false):
        return "Scene lookup failed."
    if details.get("node_lookup_failed", false):
        return "Node lookup failed."
    if details.get("late_init", false):
        return "Hook initialized too late for expected lifecycle."
    if duplicate_attempt and status != STATUS_FAILED:
        return "Duplicate hook attempt (%d) for same target binding." % attempts
    match status:
        STATUS_HEALTHY:
            return "Hook is healthy."
        STATUS_FAILED:
            return "Hook registration failed."
        _:
            return "Hook has warnings."

func _sanitize_details(details: Dictionary) -> Dictionary:
    var clean: Dictionary = {}
    for key: Variant in details.keys():
        var key_str := str(key)
        var value: Variant = details[key]
        if value is Dictionary:
            clean[key_str] = _sanitize_details(value)
        elif value is Array or value is PackedStringArray:
            clean[key_str] = _to_string_array(value)
        elif value is String or value is int or value is float or value is bool:
            clean[key_str] = value
        else:
            clean[key_str] = str(value)
    return clean

func _to_string_array(value: Variant) -> Array:
    var result: Array = []
    if value is Array or value is PackedStringArray:
        for entry: Variant in value:
            result.append(str(entry))
    return result

func _sort_entries(entries: Array[Dictionary]) -> void:
    entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        var a_key := "%s|%s|%s|%s" % [str(a.get("mod_id", "")), str(a.get("target", "")), str(a.get("status", "")), str(a.get("reason", ""))]
        var b_key := "%s|%s|%s|%s" % [str(b.get("mod_id", "")), str(b.get("target", "")), str(b.get("status", "")), str(b.get("reason", ""))]
        return a_key.naturalnocasecmp_to(b_key) < 0
    )

func _log_warn(message: String) -> void:
    if _logger != null and _logger.has_method("warn"):
        _logger.warn("hooks", message)
