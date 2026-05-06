extends "res://scripts/data.gd"

const LOG_TAG := "TajemnikTV-Core:SchematicsData"

var _schematic_load_report: Dictionary = {
    "scanned": 0,
    "loaded": 0,
    "failed": 0,
    "errors": [],
    "last_scan_unix": 0
}

func update_save(data: Dictionary) -> void:
    super (data)
    var core: Variant = Engine.get_meta("TajsCore", null)
    @warning_ignore("unsafe_method_access")
    if core != null and core.window_scenes != null:
        @warning_ignore("unsafe_method_access")
        core.window_scenes.normalize_saved_windows(data)
    @warning_ignore("unsafe_method_access")
    if core != null and core.metadata != null and core.metadata.has_method("on_save_loaded"):
        var desktop_data: Variant = data.get("desktop_data", {})
        if desktop_data is Dictionary:
            core.metadata.on_save_loaded(desktop_data)


func load_schematic(path: String) -> Dictionary:
    var file := ConfigFile.new()
    if file.load(path) != OK:
        _record_schematic_error(path, "config_load_failed")
        return {}

    if not file.has_section("schematic"):
        _record_schematic_error(path, "missing_schematic_section")
        return {}

    var windows_present := file.has_section_key("schematic", "windows")
    var connectors_present := file.has_section_key("schematic", "connectors")
    var links_present := file.has_section_key("schematic", "links")
    if not windows_present:
        _record_schematic_error(path, "missing_windows_key")
        return {}

    var data: Dictionary = {}
    data["windows"] = file.get_value("schematic", "windows")
    if connectors_present:
        data["connectors"] = file.get_value("schematic", "connectors")
    elif links_present:
        data["connectors"] = file.get_value("schematic", "links")
        _log_info("Schematic '%s' uses legacy 'links' key. Mapped to 'connectors'." % path.get_file())
    else:
        data["connectors"] = []
        _log_warn("Schematic '%s' missing connectors/links. Defaulted to empty connectors list." % path.get_file())
    data["rect"] = file.get_value("schematic", "rect", {})
    data["name"] = file.get_value("schematic", "name", path.get_file().get_basename())
    data["icon"] = file.get_value("schematic", "icon", "blueprint")
    data["version"] = file.get_value("schematic", "version", 0)

    var updated: bool = update_schematic(data)
    if updated:
        save_schematic(path.get_file().get_basename(), data)
        _log_info("Migrated schematic '%s' to current format." % path.get_file())

    return data


func load_schematics() -> void:
    schematics = {}
    _schematic_load_report = {
        "scanned": 0,
        "loaded": 0,
        "failed": 0,
        "errors": [],
        "last_scan_unix": Time.get_unix_time_from_system()
    }

    var dir_access := DirAccess.open("user://")
    if dir_access == null:
        _record_schematic_error("user://schematics", "cannot_open_user_dir")
        _log_error("Could not open user:// directory for schematic scan.")
        return
    if not dir_access.dir_exists("schematics"):
        _log_info("No user://schematics directory found.")
        return

    var files := dir_access.get_files_at("user://schematics")
    for file_name in files:
        var lower_name := file_name.to_lower()
        if not lower_name.ends_with(".dat") and not lower_name.ends_with(".cfg"):
            continue
        _schematic_load_report["scanned"] = int(_schematic_load_report.get("scanned", 0)) + 1
        var full_path := "user://schematics".path_join(file_name)
        var schematic_data: Dictionary = load_schematic(full_path)
        if schematic_data.is_empty():
            continue
        var schematic_name := file_name.get_basename()
        schematics[schematic_name] = schematic_data
        _schematic_load_report["loaded"] = int(_schematic_load_report.get("loaded", 0)) + 1

    _schematic_load_report["failed"] = int(_schematic_load_report.get("scanned", 0)) - int(_schematic_load_report.get("loaded", 0))
    if int(_schematic_load_report.get("failed", 0)) > 0:
        _log_warn("Loaded %d/%d schematics. %d failed to parse." % [
            int(_schematic_load_report.get("loaded", 0)),
            int(_schematic_load_report.get("scanned", 0)),
            int(_schematic_load_report.get("failed", 0))
        ])
    else:
        _log_info("Loaded %d schematics." % int(_schematic_load_report.get("loaded", 0)))


func get_schematic_load_report() -> Dictionary:
    return _schematic_load_report.duplicate(true)


func _record_schematic_error(path: String, reason: String) -> void:
    var errors: Array = _schematic_load_report.get("errors", [])
    errors.append({
        "path": path,
        "reason": reason
    })
    _schematic_load_report["errors"] = errors
    _log_warn("Schematic load failure [%s]: %s" % [reason, path])


func _log_info(message: String) -> void:
    _log("info", message)


func _log_warn(message: String) -> void:
    _log("warn", message)


func _log_error(message: String) -> void:
    _log("error", message)


func _log(level: String, message: String) -> void:
    var core: Variant = Engine.get_meta("TajsCore", null)
    if core != null and core.has_method("logi"):
        match level:
            "error":
                core.loge(LOG_TAG, message)
            "warn":
                core.logw(LOG_TAG, message)
            _:
                core.logi(LOG_TAG, message)
        return
    var fallback := "%s %s" % [LOG_TAG, message]
    if level == "error":
        push_error(fallback)
    elif level == "warn":
        push_warning(fallback)
    else:
        print(fallback)
