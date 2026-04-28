extends "res://scripts/data.gd"

func update_save(data: Dictionary) -> void:
    super (data)
    var core: Variant = Engine.get_meta("TajsCore", null)
    @warning_ignore("unsafe_method_access")
    if core != null and core.window_scenes != null:
        @warning_ignore("unsafe_method_access")
        core.window_scenes.normalize_saved_windows(data)
    _sanitize_legacy_desktop_windows(data)


func _sanitize_legacy_desktop_windows(data: Dictionary) -> void:
    if not data.has("desktop_data"):
        return
    var desktop_data: Variant = data.get("desktop_data", {})
    if not (desktop_data is Dictionary):
        return
    var windows_data: Variant = desktop_data.get("windows", [])
    if not (windows_data is Array):
        return

    var filtered: Array = []
    for window_entry in windows_data:
        if not (window_entry is Dictionary):
            continue
        var filename := _normalize_legacy_window_filename(window_entry)
        var normalized := filename.to_lower()
        # Upload Labs 4.6.2 regression: encompressor save entries can resolve to a scene
        # missing the "Process" node required by window_process.gd load().
        # Keep startup stable by dropping only this broken legacy entry.
        if normalized == "window_encompressor.tscn" or normalized == "window_encompressor":
            continue

        # Upload Labs 4.6.2 migration guard: legacy machine producer save entries
        # can resolve to incompatible scene instances where required nodes
        # (e.g. "Component") are missing during load().
        # Drop producer entries during migration to keep startup stable.
        var is_machine_producer := (
            normalized == "window_machine_producer.tscn"
            or normalized == "window_machine_producer"
            or normalized == "window_machine_producer_liquid.tscn"
            or normalized == "window_machine_producer_liquid"
        )
        if is_machine_producer:
            continue

        # Disabled/legacy mod scenes should not be loaded from saves after updates.
        if filename.begins_with("res://mods-unpacked/mods disabled/"):
            continue

        window_entry["filename"] = filename
        filtered.append(window_entry)

    desktop_data["windows"] = filtered
    data["desktop_data"] = desktop_data


func _normalize_legacy_window_filename(window_entry: Dictionary) -> String:
    var filename := str(window_entry.get("filename", ""))
    if filename == "":
        return filename
    if not filename.ends_with(".gd"):
        return filename

    # Legacy saves may store script filenames (e.g. window_machine_producer.gd).
    # Desktop loader expects scene filenames; convert using window metadata.
    var window_id := str(window_entry.get("window", ""))
    if window_id != "" and windows is Dictionary and windows.has(window_id):
        var def: Variant = windows[window_id]
        if def is Dictionary:
            var scene_name := str(def.get("scene", ""))
            if scene_name != "":
                return scene_name + ".tscn"

    # Fallback: replace script extension with scene extension.
    # If the resulting scene does not exist it will be filtered out by loader checks.
    return filename.trim_suffix(".gd") + ".tscn"
