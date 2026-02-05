class_name TajsCoreDiagnostics
extends RefCounted

const DEFAULT_EXPORT_PATH := "user://tajs_core_diagnostics.json"
const DUMP_FORMAT_VERSION := 1
const DEFAULT_DUMP_PREFIX := "tajs_core_diagnostics_dump_"
const DEFAULT_DUMP_EXTENSION := ".txt"
const DEFAULT_LOG_ENTRY_LIMIT := 80
const DEFAULT_MOD_LOADER_LOG_LIMIT := 60
const DEFAULT_KEYBIND_LIMIT := 200
const DEFAULT_COMMAND_LIMIT := 200
const DEFAULT_LIST_LIMIT := 200
const DEFAULT_MOD_MESSAGE_LIMIT := 5
const DEFAULT_NODE_PREVIEW_LIMIT := 20

var _core
var _logger

func _init(core, logger = null) -> void:
    _core = core
    _logger = logger

func collect(options: Dictionary = {}) -> Dictionary:
    var data := {}
    data["dump_format_version"] = DUMP_FORMAT_VERSION
    data["timestamp"] = _get_timestamp()
    data["timestamp_unix"] = Time.get_unix_time_from_system()
    data["core_version"] = _get_core_version()
    data["api_level"] = _get_api_level()
    data["godot_version"] = Engine.get_version_info()
    data["project"] = _collect_project_info()
    data["environment"] = _collect_environment_info()
    data["mod_loader_version"] = _try_get_mod_loader_version()
    data["mod_loader"] = _collect_mod_loader_info(options)
    data["mods"] = _collect_mods_info(options)
    data["modules"] = _collect_modules()
    data["settings"] = _collect_settings_snapshot()
    data["settings_meta"] = _collect_settings_meta(data["settings"])
    data["keybinds"] = _collect_keybinds()
    data["keybind_conflicts"] = _collect_keybind_conflicts()
    data["keybind_conflicts_summary"] = {
        "count": data["keybind_conflicts"].size()
    }
    var event_bus = _collect_event_bus()
    if not event_bus.is_empty():
        data["event_bus"] = event_bus
    var features = _collect_features()
    if not features.is_empty():
        data["features"] = features
    var upgrade_caps = _collect_upgrade_caps()
    if not upgrade_caps.is_empty():
        data["upgrade_caps"] = upgrade_caps
    var nodes = _collect_nodes()
    if not nodes.is_empty():
        data["nodes"] = nodes
    data["patches"] = _collect_patches()
    var hooks = _collect_hooks()
    if not hooks.is_empty():
        data["hooks"] = hooks
    var commands = _collect_commands()
    if not commands.is_empty():
        data["commands"] = commands
    var logs = _collect_logs()
    data["logs"] = logs
    data["logs_summary"] = _summarize_log_entries(logs)
    var mod_loader_logs = _collect_mod_loader_logs(options)
    if not mod_loader_logs.is_empty():
        data["mod_loader_logs"] = mod_loader_logs
    data["limits"] = _collect_limits(options)
    return data

func generate_dump(options: Dictionary = {}) -> String:
    var data := collect(options)
    return format(data, options)

func format(data: Dictionary, options: Dictionary = {}) -> String:
    var lines: Array[String] = []
    lines.append("Taj's Core Diagnostics Dump")
    var timestamp := str(data.get("timestamp", ""))
    if timestamp != "":
        lines.append("Generated: %s" % timestamp)
    var core_version := str(data.get("core_version", "unknown"))
    var api_level := str(data.get("api_level", "0"))
    lines.append("Core Version: %s (API %s)" % [core_version, api_level])
    var project: Dictionary = data.get("project", {})
    var game_name := str(project.get("name", ""))
    var game_version := str(project.get("version", ""))
    if game_name != "":
        var game_line := game_name
        if game_version != "":
            game_line += " v" + game_version
        lines.append("Game: %s" % game_line)
    var godot_str := _format_godot_version(data.get("godot_version", {}))
    if godot_str != "":
        lines.append("Godot: %s" % godot_str)
    _append_json_section(lines, "Summary", _build_summary(data))
    _append_json_section(lines, "Limits", data.get("limits", {}))
    _append_json_section(lines, "Project", data.get("project", {}))
    _append_json_section(lines, "Environment", data.get("environment", {}))
    _append_json_section(lines, "Mod Loader", _build_mod_loader_section(data))
    _append_json_section(lines, "Mods", data.get("mods", {}))
    _append_json_section(lines, "Modules", data.get("modules", []))
    _append_json_section(lines, "Settings", _build_settings_section(data))
    _append_json_section(lines, "Keybinds", _build_keybinds_section(data, options))
    _append_json_section(lines, "Registries", _build_registries_section(data, options))
    _append_json_section(lines, "Core Logs", _build_logs_section(data, options))
    if data.has("mod_loader_logs"):
        _append_json_section(lines, "Mod Loader Logs", data.get("mod_loader_logs", {}))
    return "\n".join(lines)

func copy_dump_to_clipboard(options: Dictionary = {}) -> Dictionary:
    var dump: String = str(options.get("dump", ""))
    if dump == "":
        dump = generate_dump(options)
    if dump == "":
        return {"ok": false, "error": "empty_dump"}
    if not _set_clipboard(dump):
        return {"ok": false, "error": "clipboard_unavailable"}
    return {"ok": true, "bytes": dump.length()}

func save_dump_to_file(path: String = "", options: Dictionary = {}) -> Dictionary:
    var dump: String = str(options.get("dump", ""))
    if dump == "":
        dump = generate_dump(options)
    var output_path := path
    if output_path == "":
        output_path = _build_dump_path()
    var file := FileAccess.open(output_path, FileAccess.WRITE)
    if file == null:
        return {"ok": false, "path": output_path, "error": FileAccess.get_open_error()}
    file.store_string(dump)
    file.close()
    return {"ok": true, "path": output_path, "bytes": dump.length()}

func open_dump_folder(path: String = "") -> bool:
    var target := path
    if target == "":
        target = "user://"
    if target.find(".") != -1:
        target = target.get_base_dir()
    var global_path := ProjectSettings.globalize_path(target)
    if global_path == "":
        return false
    return OS.shell_open(global_path)

func export_json(path: String = "", options: Dictionary = {}) -> Dictionary:
    var json_string := JSON.stringify(collect(options), "\t")
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
        var flag_dict := {"value": false}
        _core.event_bus.on("core.self_test", func(_payload): flag_dict["value"] = true, self , true)
        _core.event_bus.emit("core.self_test", {})
        checks.append({"name": "event_bus", "ok": flag_dict["value"]})
        ok = ok and flag_dict["value"]
    var result := {"ok": ok, "checks": checks}
    _log_info("diagnostics", "Self-test results: %s" % str(result))
    return result

func _try_get_mod_loader_version() -> String:
    var store = _get_autoload("ModLoaderStore")
    if store != null:
        var version = store.get("MODLOADER_VERSION") if store.has_method("get") else null
        if version != null:
            return str(version)
    if Engine.has_singleton("ModLoader"):
        var mod_loader = Engine.get_singleton("ModLoader")
        if mod_loader != null and mod_loader.has_method("get_version"):
            return str(mod_loader.get_version())
    return "unknown"

func _log_info(module_id: String, message: String) -> void:
    if _logger != null and _logger.has_method("info"):
        _logger.info(module_id, message)

func _get_core_version() -> String:
    if _core != null and _core.has_method("get_version"):
        return str(_core.get_version())
    return "unknown"

func _get_api_level() -> int:
    if _core != null and _core.has_method("get_api_level"):
        return int(_core.get_api_level())
    return 0

func _get_timestamp() -> String:
    return Time.get_datetime_string_from_system()

func _build_dump_path() -> String:
    var stamp := _get_timestamp_for_filename()
    return "user://%s%s%s" % [DEFAULT_DUMP_PREFIX, stamp, DEFAULT_DUMP_EXTENSION]

func _get_timestamp_for_filename() -> String:
    var dt := Time.get_datetime_dict_from_system()
    return "%04d%02d%02d_%02d%02d%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second]

func _collect_project_info() -> Dictionary:
    var info := {}
    info["name"] = str(ProjectSettings.get_setting("application/config/name", ""))
    info["version"] = str(ProjectSettings.get_setting("application/config/version", ""))
    info["features"] = _to_string_array(ProjectSettings.get_setting("application/config/features", PackedStringArray()))
    info["main_scene"] = str(ProjectSettings.get_setting("application/run/main_scene", ""))
    info["custom_user_dir"] = bool(ProjectSettings.get_setting("application/config/use_custom_user_dir", false))
    info["custom_user_dir_name"] = str(ProjectSettings.get_setting("application/config/custom_user_dir_name", ""))
    return info

func _collect_environment_info() -> Dictionary:
    var info := {
        "os_name": OS.get_name(),
        "os_version": OS.get_version(),
        "locale": OS.get_locale(),
        "is_editor": OS.has_feature("editor"),
        "is_debug_build": OS.is_debug_build()
    }
    var display_name := DisplayServer.get_name()
    if display_name != "":
        info["display_server"] = display_name
    return info

func _collect_mod_loader_info(options: Dictionary = {}) -> Dictionary:
    var info := {}
    var store = _get_autoload("ModLoaderStore")
    if store == null:
        return info
    var list_limit := _get_limit(options, "list_limit", DEFAULT_LIST_LIMIT)
    info["is_initializing"] = bool(store.get("is_initializing")) if store.has_method("get") else false
    var mod_data = store.get("mod_data") if store.has_method("get") else {}
    info["mod_count"] = mod_data.size() if mod_data is Dictionary else 0
    var load_order = store.get("mod_load_order") if store.has_method("get") else []
    info["mod_load_order"] = _mod_load_order_to_ids(load_order)
    var missing_deps = store.get("mod_missing_dependencies") if store.has_method("get") else {}
    info["missing_dependencies"] = _sorted_dictionary(missing_deps if missing_deps is Dictionary else {})
    var script_extensions_raw = store.get("script_extensions") if store.has_method("get") else null
    var script_extensions = _to_string_array(script_extensions_raw if script_extensions_raw != null else [])
    info["script_extensions_count"] = script_extensions.size()
    info["script_extensions"] = _limit_array(script_extensions, list_limit)
    var hooked_scripts_raw = store.get("hooked_script_paths") if store.has_method("get") else null
    var hooked_scripts = _sorted_keys(hooked_scripts_raw if hooked_scripts_raw != null else {})
    info["hooked_scripts_count"] = hooked_scripts.size()
    info["hooked_scripts"] = _limit_array(hooked_scripts, list_limit)
    var modding_hooks_raw = store.get("modding_hooks") if store.has_method("get") else null
    var modding_hooks = _sorted_keys(modding_hooks_raw if modding_hooks_raw != null else {})
    info["modding_hooks_count"] = modding_hooks.size()
    info["modding_hooks"] = _limit_array(modding_hooks, list_limit)
    var options_obj = store.get("ml_options") if store.has_method("get") else null
    var options_dict := _collect_mod_loader_options(options_obj)
    if not options_dict.is_empty():
        info["options"] = options_dict
        info["mods_enabled"] = bool(options_dict.get("enable_mods", true))
    return info

func _collect_mod_loader_options(options_obj) -> Dictionary:
    var options := {}
    if options_obj == null:
        return options
    var get_value := func(key: String, fallback: Variant) -> Variant:
        if options_obj.has_method("get"):
            var value = options_obj.get(key)
            return value if value != null else fallback
        return fallback
    options["enable_mods"] = bool(get_value.call("enable_mods", true))
    options["load_from_steam_workshop"] = bool(get_value.call("load_from_steam_workshop", false))
    options["load_from_local"] = bool(get_value.call("load_from_local", true))
    options["load_from_unpacked"] = bool(get_value.call("load_from_unpacked", true))
    options["disabled_mods"] = _to_string_array(get_value.call("disabled_mods", []))
    options["locked_mods"] = _to_string_array(get_value.call("locked_mods", []))
    options["game_version"] = str(get_value.call("semantic_version", ""))
    var steam_id := int(get_value.call("steam_id", 0))
    if steam_id != 0:
        options["steam_id"] = "<redacted>"
    var override_mods := str(get_value.call("override_path_to_mods", ""))
    options["override_mods_path_set"] = override_mods != ""
    var override_configs := str(get_value.call("override_path_to_configs", ""))
    options["override_configs_path_set"] = override_configs != ""
    var override_workshop := str(get_value.call("override_path_to_workshop", ""))
    options["override_workshop_path_set"] = override_workshop != ""
    var override_hook_pack := str(get_value.call("override_path_to_hook_pack", ""))
    options["override_hook_pack_path_set"] = override_hook_pack != ""
    var customize_script := str(get_value.call("customize_script_path", ""))
    options["customize_script_set"] = customize_script != ""
    return options

func _collect_mods_info(options: Dictionary = {}) -> Dictionary:
    var result := {
        "total": 0,
        "enabled": 0,
        "disabled": 0,
        "loadable": 0,
        "with_errors": 0,
        "with_warnings": 0,
        "list": []
    }
    if not _has_global_class("ModLoaderMod"):
        return result
    var all_mods = ModLoaderMod.get_mod_data_all()
    if not (all_mods is Dictionary):
        return result
    var mod_ids := all_mods.keys()
    mod_ids.sort_custom(func(a, b):
        return str(a).naturalnocasecmp_to(str(b)) < 0
    )
    var source_counts := {}
    for mod_id in mod_ids:
        var mod_data = all_mods[mod_id]
        var entry := _build_mod_entry(str(mod_id), mod_data, options)
        result["list"].append(entry)
        result["total"] += 1
        if entry.get("active", false):
            result["enabled"] += 1
        else:
            result["disabled"] += 1
        if entry.get("loadable", false):
            result["loadable"] += 1
        if entry.get("errors_count", 0) > 0:
            result["with_errors"] += 1
        if entry.get("warnings_count", 0) > 0:
            result["with_warnings"] += 1
        var source = str(entry.get("source", "unknown"))
        source_counts[source] = int(source_counts.get(source, 0)) + 1
    if not source_counts.is_empty():
        result["source_counts"] = _sorted_dictionary(source_counts)
    return result

func _build_mod_entry(mod_id: String, mod_data: Variant, options: Dictionary) -> Dictionary:
    var entry := {
        "id": mod_id,
        "name": "",
        "version": "",
        "active": true,
        "loadable": true,
        "source": "unknown",
        "locked": false,
        "is_overwrite": false,
        "errors": [],
        "warnings": [],
        "errors_count": 0,
        "warnings_count": 0
    }
    var manifest = _get_field(mod_data, "manifest", null)
    var display_name := str(_get_manifest_value(manifest, "display_name", ""))
    if display_name == "":
        display_name = str(_get_manifest_value(manifest, "name", mod_id))
    entry["name"] = display_name
    var version := str(_get_manifest_value(manifest, "version_number", _get_manifest_value(manifest, "version", "")))
    entry["version"] = version
    entry["namespace"] = str(_get_manifest_value(manifest, "mod_namespace", _get_manifest_value(manifest, "namespace", "")))
    entry["authors"] = _to_string_array(_get_manifest_value(manifest, "authors", []))
    entry["dependencies"] = _to_string_array(_get_manifest_value(manifest, "dependencies", []))
    entry["optional_dependencies"] = _to_string_array(_get_manifest_value(manifest, "optional_dependencies", []))
    entry["active"] = bool(_get_field(mod_data, "is_active", true))
    entry["loadable"] = bool(_get_field(mod_data, "is_loadable", true))
    entry["locked"] = bool(_get_field(mod_data, "is_locked", false))
    entry["is_overwrite"] = bool(_get_field(mod_data, "is_overwrite", false))
    entry["source"] = _format_mod_source(_get_field(mod_data, "source", -1))
    var message_limit := _get_limit(options, "mod_message_limit", DEFAULT_MOD_MESSAGE_LIMIT)
    var errors: Array = _to_string_array(_get_field(mod_data, "load_errors", []))
    var warnings: Array = _to_string_array(_get_field(mod_data, "load_warnings", []))
    entry["errors_count"] = errors.size()
    entry["warnings_count"] = warnings.size()
    entry["errors"] = _limit_array(errors, message_limit)
    entry["warnings"] = _limit_array(warnings, message_limit)
    return entry

func _collect_modules() -> Array:
    if _core == null or _core.module_registry == null or not _core.module_registry.has_method("list_modules"):
        return []
    var modules: Array = _core.module_registry.list_modules()
    modules.sort_custom(func(a, b):
        return str(a.get("id", "")).naturalnocasecmp_to(str(b.get("id", ""))) < 0
    )
    return modules

func _collect_settings_snapshot() -> Dictionary:
    if _core == null or _core.settings == null or not _core.settings.has_method("get_snapshot"):
        return {}
    var snapshot = _core.settings.get_snapshot(true)
    if snapshot is Dictionary:
        return _sorted_recursive(snapshot)
    return {}

func _collect_settings_meta(snapshot: Dictionary) -> Dictionary:
    var meta := {
        "total_keys": snapshot.size(),
        "changed_keys": [],
        "redacted_keys": []
    }
    if _core != null and _core.settings != null and _core.settings.has_method("get_changed_keys"):
        var changed_keys: Array = _core.settings.get_changed_keys()
        changed_keys.sort()
        meta["changed_keys"] = changed_keys
    for key in snapshot.keys():
        var value = snapshot[key]
        if value is String and value == "<redacted>":
            meta["redacted_keys"].append(str(key))
    meta["redacted_keys"].sort()
    return meta

func _collect_keybinds() -> Array:
    if _core == null or _core.keybinds == null or not _core.keybinds.has_method("get_actions_for_ui"):
        return []
    var actions: Array = _core.keybinds.get_actions_for_ui()
    actions.sort_custom(func(a, b):
        return str(a.get("id", "")).naturalnocasecmp_to(str(b.get("id", ""))) < 0
    )
    return actions

func _collect_keybind_conflicts() -> Array:
    if _core == null or _core.keybinds == null or not _core.keybinds.has_method("get_conflicts"):
        return []
    var conflicts: Array = _core.keybinds.get_conflicts()
    conflicts.sort_custom(func(a, b):
        var a_key := "%s|%s" % [str(a.get("context", "")), str(a.get("shortcut", ""))]
        var b_key := "%s|%s" % [str(b.get("context", "")), str(b.get("shortcut", ""))]
        return a_key.naturalnocasecmp_to(b_key) < 0
    )
    return conflicts

func _collect_event_bus() -> Dictionary:
    if _core == null or _core.event_bus == null:
        return {}
    var events: Array = _core.event_bus.list_events() if _core.event_bus.has_method("list_events") else []
    events.sort()
    var counts := {}
    for evt in events:
        if _core.event_bus.has_method("get_listener_count"):
            counts[evt] = _core.event_bus.get_listener_count(evt)
    return {
        "events": events,
        "listener_counts": counts
    }

func _collect_features() -> Array:
    if _core == null or _core.features == null or not _core.features.has_method("list_features"):
        return []
    var features: Array = _core.features.list_features()
    features.sort()
    return features

func _collect_upgrade_caps() -> Dictionary:
    if _core == null or _core.upgrade_caps == null or not _core.upgrade_caps.has_method("list_caps"):
        return {}
    return _sorted_recursive(_core.upgrade_caps.list_caps())

func _collect_nodes() -> Dictionary:
    if _core == null or _core.node_registry == null:
        return {}
    var mod_nodes: Dictionary = _core.node_registry.get_mod_nodes()
    var sorted_nodes := {}
    for mod_id in _sorted_keys(mod_nodes):
        var nodes: Array = _to_string_array(mod_nodes.get(mod_id, []))
        nodes.sort()
        sorted_nodes[mod_id] = nodes
    return {
        "count": _core.node_registry.get_mod_node_count(),
        "mods": sorted_nodes
    }

func _collect_patches() -> Array:
    if _core == null or _core.patches == null or not _core.patches.has_method("list_applied"):
        return []
    var patches: Array = _core.patches.list_applied()
    patches.sort()
    return patches

func _collect_hooks() -> Dictionary:
    if _core == null or _core.hook_manager == null:
        return {}
    if not is_instance_valid(_core.hook_manager):
        return {}
    var hook_list: Array = []
    for child in _core.hook_manager.get_children():
        if child != null:
            hook_list.append(child.name)
    hook_list.sort()
    return {
        "count": hook_list.size(),
        "hooks": hook_list
    }

func _collect_commands() -> Dictionary:
    if _core == null:
        return {}
    var registry = _core.commands if _core.commands != null else _core.command_registry
    if registry == null:
        return {}
    var all_commands: Array = []
    if registry.has_method("get_all_commands"):
        all_commands = registry.get_all_commands()
    elif registry.has_method("get_all"):
        all_commands = registry.get_all()
    elif registry.has_method("list"):
        all_commands = registry.list()
    var command_ids: Array = []
    var categories := 0
    for cmd in all_commands:
        if cmd is Dictionary:
            var cmd_id := str(cmd.get("id", ""))
            if cmd_id != "":
                command_ids.append(cmd_id)
            if bool(cmd.get("is_category", false)):
                categories += 1
    command_ids.sort()
    return {
        "count": all_commands.size(),
        "categories": categories,
        "commands": command_ids
    }

func _collect_logs() -> Array:
    if _core == null or _core.logger == null or not _core.logger.has_method("get_entries"):
        return []
    return _core.logger.get_entries()

func _collect_mod_loader_logs(options: Dictionary = {}) -> Dictionary:
    if not _has_global_class("ModLoaderLog"):
        return {}
    var summary := {"total": 0, "by_type": {}}
    var logged = ModLoaderLog.logged_messages
    if logged is Dictionary:
        if logged.has("all") and logged["all"] is Dictionary:
            summary["total"] = logged["all"].size()
        if logged.has("by_type") and logged["by_type"] is Dictionary:
            for log_type in logged["by_type"].keys():
                var bucket = logged["by_type"][log_type]
                if bucket is Dictionary:
                    summary["by_type"][str(log_type)] = bucket.size()
    var entries: Array = ModLoaderLog.get_all_as_string()
    var limit := _get_limit(options, "mod_loader_log_limit", DEFAULT_MOD_LOADER_LOG_LIMIT)
    var preview := _limit_array(entries, limit, true)
    return {
        "summary": summary,
        "entries": preview
    }

func _collect_limits(options: Dictionary) -> Dictionary:
    return {
        "log_limit": _get_limit(options, "log_limit", DEFAULT_LOG_ENTRY_LIMIT),
        "mod_loader_log_limit": _get_limit(options, "mod_loader_log_limit", DEFAULT_MOD_LOADER_LOG_LIMIT),
        "keybind_limit": _get_limit(options, "keybind_limit", DEFAULT_KEYBIND_LIMIT),
        "command_limit": _get_limit(options, "command_limit", DEFAULT_COMMAND_LIMIT),
        "list_limit": _get_limit(options, "list_limit", DEFAULT_LIST_LIMIT),
        "mod_message_limit": _get_limit(options, "mod_message_limit", DEFAULT_MOD_MESSAGE_LIMIT),
        "node_preview_limit": _get_limit(options, "node_preview_limit", DEFAULT_NODE_PREVIEW_LIMIT)
    }

func _summarize_log_entries(entries: Array) -> Dictionary:
    var summary := {
        "total": entries.size(),
        "levels": {}
    }
    for entry in entries:
        if not (entry is Dictionary):
            continue
        var level := str(entry.get("level", ""))
        if level == "":
            continue
        summary["levels"][level] = int(summary["levels"].get(level, 0)) + 1
    summary["levels"] = _sorted_dictionary(summary["levels"])
    return summary

func _build_summary(data: Dictionary) -> Dictionary:
    var project: Dictionary = data.get("project", {})
    var mods: Dictionary = data.get("mods", {})
    return {
        "core_version": data.get("core_version", "unknown"),
        "api_level": data.get("api_level", 0),
        "game": project.get("name", ""),
        "game_version": project.get("version", ""),
        "mod_loader_version": data.get("mod_loader_version", "unknown"),
        "mods": {
            "total": mods.get("total", 0),
            "enabled": mods.get("enabled", 0),
            "disabled": mods.get("disabled", 0)
        },
        "keybind_conflicts": data.get("keybind_conflicts_summary", {}),
        "logs": data.get("logs_summary", {})
    }

func _build_mod_loader_section(data: Dictionary) -> Dictionary:
    var mod_loader: Dictionary = data.get("mod_loader", {}).duplicate(true)
    mod_loader["version"] = data.get("mod_loader_version", "unknown")
    return mod_loader

func _build_settings_section(data: Dictionary) -> Dictionary:
    return {
        "meta": data.get("settings_meta", {}),
        "values": data.get("settings", {})
    }

func _build_keybinds_section(data: Dictionary, options: Dictionary) -> Dictionary:
    var keybinds: Array = data.get("keybinds", [])
    var keybind_limit := _get_limit(options, "keybind_limit", DEFAULT_KEYBIND_LIMIT)
    var preview := _limit_array(keybinds, keybind_limit)
    return {
        "actions_total": keybinds.size(),
        "actions": preview,
        "conflicts": data.get("keybind_conflicts", [])
    }

func _build_registries_section(data: Dictionary, options: Dictionary) -> Dictionary:
    var registries := {
        "event_bus": data.get("event_bus", {}),
        "patches": data.get("patches", []),
        "hooks": data.get("hooks", {})
    }
    var nodes: Dictionary = data.get("nodes", {})
    var node_limit := _get_limit(options, "node_preview_limit", DEFAULT_NODE_PREVIEW_LIMIT)
    if nodes is Dictionary and nodes.has("mods"):
        var mods: Dictionary = nodes.get("mods", {})
        var preview := {}
        for mod_id in _sorted_keys(mods):
            var node_list: Array = _to_string_array(mods.get(mod_id, []))
            preview[mod_id] = _limit_array(node_list, node_limit)
        registries["nodes"] = {
            "count": nodes.get("count", 0),
            "mods_total": mods.size(),
            "mods_preview": preview
        }
    else:
        registries["nodes"] = nodes
    var commands: Dictionary = data.get("commands", {})
    var command_ids: Array = commands.get("commands", [])
    var command_limit := _get_limit(options, "command_limit", DEFAULT_COMMAND_LIMIT)
    registries["commands"] = {
        "count": commands.get("count", 0),
        "categories": commands.get("categories", 0),
        "items": _limit_array(command_ids, command_limit)
    }
    return registries

func _build_logs_section(data: Dictionary, options: Dictionary) -> Dictionary:
    var logs: Array = data.get("logs", [])
    var log_limit := _get_limit(options, "log_limit", DEFAULT_LOG_ENTRY_LIMIT)
    return {
        "summary": data.get("logs_summary", {}),
        "entries": _limit_array(logs, log_limit, true),
        "entries_total": logs.size()
    }

func _append_json_section(lines: Array[String], title: String, payload: Variant) -> void:
    _append_section(lines, title)
    lines.append(JSON.stringify(_sorted_recursive(payload), "\t"))

func _format_godot_version(info: Dictionary) -> String:
    if info is Dictionary:
        var string_val := str(info.get("string", ""))
        if string_val != "":
            return string_val
        if info.has("major") and info.has("minor"):
            var patch := str(info.get("patch", "0"))
            return "%s.%s.%s" % [str(info.get("major", "")), str(info.get("minor", "")), patch]
    return ""

func _mod_load_order_to_ids(load_order: Variant) -> Array:
    var result: Array = []
    if load_order is Array:
        for entry in load_order:
            var mod_id := _get_mod_id_from_data(entry)
            result.append(mod_id if mod_id != "" else str(entry))
    return result

func _get_mod_id_from_data(mod_data: Variant) -> String:
    if mod_data == null:
        return ""
    if mod_data is Dictionary:
        return str(mod_data.get("id", mod_data.get("dir_name", "")))
    if mod_data.has_method("get"):
        var manifest = mod_data.get("manifest")
        if manifest != null and manifest.has_method("get_mod_id"):
            return str(manifest.get_mod_id())
        var dir_name = mod_data.get("dir_name")
        if dir_name != null:
            return str(dir_name)
    return ""

func _format_mod_source(source_value: Variant) -> String:
    var source := int(source_value)
    match source:
        0:
            return "unpacked"
        1:
            return "local"
        2:
            return "steam_workshop"
        _:
            return "unknown"

func _get_manifest_value(manifest: Variant, key: String, fallback: Variant) -> Variant:
    if manifest is Dictionary:
        return manifest.get(key, fallback)
    if manifest != null and manifest.has_method("get"):
        var value = manifest.get(key)
        return value if value != null else fallback
    return fallback

func _get_field(target: Variant, key: String, fallback: Variant) -> Variant:
    if target is Dictionary:
        return target.get(key, fallback)
    if target != null and target.has_method("get"):
        var value = target.get(key)
        return value if value != null else fallback
    return fallback

func _limit_array(values: Array, limit: int, tail: bool = false) -> Array:
    if limit <= 0 or values.size() <= limit:
        return values.duplicate()
    if tail:
        return values.slice(values.size() - limit, values.size())
    return values.slice(0, limit)

func _sorted_keys(dict: Dictionary) -> Array:
    var keys := dict.keys()
    keys.sort_custom(func(a, b):
        return str(a).naturalnocasecmp_to(str(b)) < 0
    )
    return keys

func _sorted_dictionary(dict: Dictionary) -> Dictionary:
    var sorted := {}
    for key in _sorted_keys(dict):
        sorted[key] = dict[key]
    return sorted

func _sorted_recursive(value: Variant) -> Variant:
    if value is Dictionary:
        var sorted := {}
        for key in _sorted_keys(value):
            sorted[key] = _sorted_recursive(value[key])
        return sorted
    if value is Array:
        var result: Array = []
        for entry in value:
            result.append(_sorted_recursive(entry))
        return result
    return value

func _to_string_array(value: Variant) -> Array:
    var result: Array = []
    if value is PackedStringArray:
        for entry in value:
            result.append(str(entry))
    elif value is Array:
        for entry in value:
            result.append(str(entry))
    return result

func _get_limit(options: Dictionary, key: String, fallback: int) -> int:
    if options.has(key):
        return int(options.get(key, fallback))
    return fallback

func _append_section(lines: Array[String], title: String) -> void:
    if not lines.is_empty():
        lines.append("")
    lines.append("## %s" % title)

func _set_clipboard(text: String) -> bool:
    if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
        DisplayServer.clipboard_set(text)
        return true
    if _core != null and _core.has_method("copy_to_clipboard"):
        _core.copy_to_clipboard(text)
        return true
    return false

func _get_autoload(name: String) -> Object:
    if Engine.has_singleton(name):
        return Engine.get_singleton(name)
    if Engine.get_main_loop() == null:
        return null
    var root = Engine.get_main_loop().root
    if root == null:
        return null
    return root.get_node_or_null(name)


func _has_global_class(class_name_str: String) -> bool:
    for entry in ProjectSettings.get_global_class_list():
        if entry.get("class", "") == class_name_str:
            return true
    return false
