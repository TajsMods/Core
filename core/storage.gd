class_name TajsCoreStorage
extends RefCounted

const STORAGE_SCHEMA_VERSION := "1.0.0"
const STORAGE_ROOT := "user://mods"
const STORAGE_MAP_PATH := "user://mods/_storage_ids.json"
const MANIFEST_GLOB := "res://mods-unpacked/*/manifest.json"

var _logger: Variant
var _module_to_storage: Dictionary = {}

func _init(logger: Variant = null) -> void:
    _logger = logger
    _ensure_dir(STORAGE_ROOT)
    _load_storage_map()
    _index_manifests()
    _save_storage_map()

func list_known_modules() -> Array[String]:
    var keys: Array[String] = []
    for module_id: Variant in _module_to_storage.keys():
        keys.append(str(module_id))
    return keys

func get_storage_id(module_id: String) -> String:
    if module_id == "":
        return ""
    if _module_to_storage.has(module_id):
        return str(_module_to_storage[module_id])
    var fallback = _sanitize_segment(module_id)
    _module_to_storage[module_id] = fallback
    _save_storage_map()
    return fallback

func get_module_root(module_id: String) -> String:
    var storage_id = get_storage_id(module_id)
    if storage_id == "":
        return STORAGE_ROOT
    return STORAGE_ROOT.path_join(storage_id)

func ensure_module_dirs(module_id: String) -> void:
    var root = get_module_root(module_id)
    _ensure_dir(root)
    _ensure_dir(root.path_join("data"))
    _ensure_dir(root.path_join("state"))
    _ensure_dir(root.path_join("cache"))

func get_config_path(module_id: String) -> String:
    ensure_module_dirs(module_id)
    return get_module_root(module_id).path_join("config.json")

func get_data_path(module_id: String, relative_path: String) -> String:
    ensure_module_dirs(module_id)
    return get_module_root(module_id).path_join("data").path_join(_sanitize_relative_path(relative_path))

func get_state_path(module_id: String, relative_path: String) -> String:
    ensure_module_dirs(module_id)
    return get_module_root(module_id).path_join("state").path_join(_sanitize_relative_path(relative_path))

func get_cache_path(module_id: String, relative_path: String) -> String:
    ensure_module_dirs(module_id)
    return get_module_root(module_id).path_join("cache").path_join(_sanitize_relative_path(relative_path))

func read_json(path: String, default_value: Variant = {}) -> Variant:
    if not FileAccess.file_exists(path):
        return _duplicate(default_value)
    var file = FileAccess.open(path, FileAccess.READ)
    if file == null:
        return _duplicate(default_value)
    var text = file.get_as_text()
    file.close()
    var json = JSON.new()
    if json.parse(text) != OK:
        return _duplicate(default_value)
    return json.get_data()

func write_json(path: String, data: Variant, atomic := true) -> Error:
    var dir = path.get_base_dir()
    _ensure_dir(dir)
    var payload = JSON.stringify(data, "\t")
    if atomic:
        var temp_path = "%s.tmp" % path
        var temp_file = FileAccess.open(temp_path, FileAccess.WRITE)
        if temp_file == null:
            return ERR_CANT_OPEN
        var _ignored: Variant = temp_file.store_string(payload)
        temp_file.close()
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(path)
        var rename_err = DirAccess.rename_absolute(temp_path, path)
        if rename_err != OK:
            return rename_err
        return OK
    var file = FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return ERR_CANT_OPEN
    var _ignored_store: Variant = file.store_string(payload)
    file.close()
    return OK

func backup_file(path: String, reason := "migration") -> String:
    if not FileAccess.file_exists(path):
        return ""
    var stamp = Time.get_datetime_string_from_system(false, true).replace(":", "").replace("-", "").replace("T", "_")
    var backup_dir = STORAGE_ROOT.path_join("_migration_backups")
    _ensure_dir(backup_dir)
    var backup_path = backup_dir.path_join("%s_%s.json" % [reason, stamp])
    var source = FileAccess.open(path, FileAccess.READ)
    if source == null:
        return ""
    var text = source.get_as_text()
    source.close()
    var target = FileAccess.open(backup_path, FileAccess.WRITE)
    if target == null:
        return ""
    var _ignored: Variant = target.store_string(text)
    target.close()
    return backup_path

func make_meta(module_id: String, kind: String) -> Dictionary:
    return {
        "schema_version": STORAGE_SCHEMA_VERSION,
        "module": module_id,
        "kind": kind
    }

func _index_manifests() -> void:
    for manifest_path in _glob(MANIFEST_GLOB):
        var manifest = read_json(str(manifest_path), {})
        if not (manifest is Dictionary):
            continue
        var mod_namespace = str(manifest.get("namespace", "")).strip_edges()
        var name = str(manifest.get("name", "")).strip_edges()
        if mod_namespace == "" or name == "":
            continue
        var module_id = "%s-%s" % [mod_namespace, name]
        if not _module_to_storage.has(module_id):
            _module_to_storage[module_id] = _sanitize_segment(module_id)

func _load_storage_map() -> void:
    var data = read_json(STORAGE_MAP_PATH, {})
    if data is Dictionary:
        for key: Variant in data.keys():
            _module_to_storage[str(key)] = _sanitize_segment(str(data[key]))

func _save_storage_map() -> void:
    write_json(STORAGE_MAP_PATH, _module_to_storage, true)

func _sanitize_segment(value: String) -> String:
    var regex = RegEx.new()
    regex.compile("[^A-Za-z0-9_-]")
    var clean = regex.sub(value, "-", true)
    while clean.contains("--"):
        clean = clean.replace("--", "-")
    clean = clean.strip_edges().trim_prefix("-").trim_suffix("-")
    if clean == "":
        clean = "module"
    return clean

func _sanitize_relative_path(value: String) -> String:
    var normalized = value.replace("\\", "/").strip_edges()
    if normalized == "" or normalized.begins_with("/") or normalized.contains("../") or normalized.contains("..\\"):
        push_error("Unsafe relative path requested: %s" % value)
        return "invalid.json"
    return normalized

func _ensure_dir(path: String) -> void:
    DirAccess.make_dir_recursive_absolute(path)

func _glob(_pattern: String) -> PackedStringArray:
    var out = PackedStringArray()
    var dir = DirAccess.open("res://mods-unpacked")
    if dir == null:
        return out
    dir.list_dir_begin()
    while true:
        var entry = dir.get_next()
        if entry == "":
            break
        if entry.begins_with("."):
            continue
        var manifest_path = "res://mods-unpacked/%s/manifest.json" % entry
        if ResourceLoader.exists(manifest_path):
            out.append(manifest_path)
    dir.list_dir_end()
    return out

func _duplicate(value: Variant) -> Variant:
    if value is Dictionary or value is Array:
        return value.duplicate(true)
    return value
