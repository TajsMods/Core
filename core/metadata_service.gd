class_name TajsCoreMetadataService
extends RefCounted

const MODULE_ID := "TajemnikTV-Core"
const SAVE_SCHEMA_VERSION := 1
const GLOBAL_SCHEMA_VERSION := 1
const SAVE_BLOB_KEY := "tajs_core_metadata"
const ORPHAN_DELETE_AFTER_MISSES := 3

const SCOPE_SAVE := "save"
const SCOPE_BOARD := "board"
const SCOPE_WORKSPACE := "workspace"
const SCOPE_WINDOW := "window"
const SCOPE_NODE := "node"
const SCOPE_SCHEMATIC := "schematic"
const SCOPE_GLOBAL := "global"

const SAVE_SCOPES := [SCOPE_SAVE, SCOPE_BOARD, SCOPE_WORKSPACE, SCOPE_WINDOW, SCOPE_NODE, SCOPE_SCHEMATIC]
const ALL_SCOPES := [SCOPE_SAVE, SCOPE_BOARD, SCOPE_WORKSPACE, SCOPE_WINDOW, SCOPE_NODE, SCOPE_SCHEMATIC, SCOPE_GLOBAL]

var _core: Variant
var _logger: Variant
var _storage: Variant
var _event_bus: Variant

var _save_data: Dictionary = {}
var _global_data: Dictionary = {}
var _orphan_miss_counts: Dictionary = {}
var _save_identity: String = ""
var _loaded_from_save_blob := false

func _init(core: Variant, logger: Variant, storage: Variant, event_bus: Variant) -> void:
    _core = core
    _logger = logger
    _storage = storage
    _event_bus = event_bus
    _reset_save_data()
    _load_global_data()
    _load_save_fallback()
    _bind_events()

func metadata_get(scope: String, owner_id: String, key: String, fallback: Variant = null) -> Variant:
    if not _is_valid_scope(scope):
        return fallback
    if not _is_valid_namespaced_key(key):
        return fallback
    var owner_key := _normalize_owner_id(owner_id)
    var owners := _get_scope_store(scope)
    if not owners.has(owner_key):
        return fallback
    var owner_bucket: Variant = owners.get(owner_key, {})
    if not (owner_bucket is Dictionary):
        return fallback
    if not owner_bucket.has(key):
        return fallback
    return _duplicate_json_safe(owner_bucket[key])

func metadata_set(scope: String, owner_id: String, key: String, value: Variant) -> Dictionary:
    if not _is_valid_scope(scope):
        return {"ok": false, "error": "invalid_scope", "scope": scope}
    if not _is_valid_namespaced_key(key):
        return {"ok": false, "error": "invalid_key", "key": key}
    if not _is_json_compatible(value):
        return {"ok": false, "error": "value_not_json_compatible", "key": key}

    var owner_key := _normalize_owner_id(owner_id)
    var owners := _get_scope_store(scope)
    if not owners.has(owner_key):
        owners[owner_key] = {}
    var owner_bucket: Variant = owners.get(owner_key, {})
    if not (owner_bucket is Dictionary):
        owner_bucket = {}
    owner_bucket[key] = _duplicate_json_safe(value)
    owners[owner_key] = owner_bucket
    _mark_dirty(scope)
    return {"ok": true, "scope": scope, "owner_id": owner_key, "key": key}

func metadata_delete(scope: String, owner_id: String, key: String) -> Dictionary:
    if not _is_valid_scope(scope):
        return {"ok": false, "error": "invalid_scope", "scope": scope}
    if not _is_valid_namespaced_key(key):
        return {"ok": false, "error": "invalid_key", "key": key}

    var owner_key := _normalize_owner_id(owner_id)
    var owners := _get_scope_store(scope)
    if not owners.has(owner_key):
        return {"ok": true, "deleted": false}
    var owner_bucket: Variant = owners.get(owner_key, {})
    if not (owner_bucket is Dictionary):
        return {"ok": true, "deleted": false}
    if not owner_bucket.erase(key):
        return {"ok": true, "deleted": false}
    if owner_bucket.is_empty():
        owners.erase(owner_key)
    else:
        owners[owner_key] = owner_bucket
    _mark_dirty(scope)
    return {"ok": true, "deleted": true}

func metadata_list(scope: String, owner_id: String = "") -> Dictionary:
    if not _is_valid_scope(scope):
        return {}
    var owners: Dictionary = _get_scope_store(scope)
    if owner_id == "":
        return owners.duplicate(true)
    var owner_key := _normalize_owner_id(owner_id)
    var bucket: Variant = owners.get(owner_key, {})
    if bucket is Dictionary:
        return bucket.duplicate(true)
    return {}

func metadata_migrate(mod_id: String, from_version: String, to_version: String, callable: Callable) -> Dictionary:
    if mod_id.strip_edges() == "":
        return {"ok": false, "error": "mod_id_empty"}
    if not callable.is_valid():
        return {"ok": false, "error": "callable_invalid"}

    var namespace_prefix := "%s." % mod_id
    var migrated := 0
    for scope: String in ALL_SCOPES:
        var owners: Dictionary = _get_scope_store(scope)
        for owner_key: String in owners.keys():
            var owner_bucket: Variant = owners.get(owner_key, {})
            if not (owner_bucket is Dictionary):
                continue
            var updates: Array = []
            for full_key: String in owner_bucket.keys():
                if not full_key.begins_with(namespace_prefix):
                    continue
                var current_value: Variant = owner_bucket[full_key]
                var result: Variant = callable.call(scope, owner_key, full_key, _duplicate_json_safe(current_value), from_version, to_version)
                if result is Dictionary:
                    updates.append({"source_key": full_key, "result": result})
            for update in updates:
                var source_key: String = str(update.get("source_key", ""))
                var result_dict: Dictionary = update.get("result", {})
                if bool(result_dict.get("delete", false)):
                    owner_bucket.erase(source_key)
                    migrated += 1
                    continue
                var next_key: String = str(result_dict.get("key", source_key))
                var next_value: Variant = result_dict.get("value", owner_bucket.get(source_key, null))
                if not next_key.begins_with(namespace_prefix):
                    _logw("metadata", "Rejected migration key outside namespace: %s" % next_key)
                    continue
                if not _is_valid_namespaced_key(next_key):
                    _logw("metadata", "Rejected invalid migration key: %s" % next_key)
                    continue
                if not _is_json_compatible(next_value):
                    _logw("metadata", "Rejected non-JSON migration value for key: %s" % next_key)
                    continue
                owner_bucket.erase(source_key)
                owner_bucket[next_key] = _duplicate_json_safe(next_value)
                migrated += 1
            if owner_bucket.is_empty():
                owners.erase(owner_key)
            else:
                owners[owner_key] = owner_bucket
    _mark_dirty(SCOPE_SAVE)
    _mark_dirty(SCOPE_GLOBAL)
    return {"ok": true, "migrated": migrated, "mod_id": mod_id, "from_version": from_version, "to_version": to_version}

func on_save_loaded(save_data: Dictionary) -> void:
    _loaded_from_save_blob = false
    _save_identity = _compute_save_identity(save_data)
    var blob: Variant = save_data.get(SAVE_BLOB_KEY, {})
    if blob is Dictionary and int(blob.get("schema_version", 0)) == SAVE_SCHEMA_VERSION:
        _load_save_blob(blob)
        _loaded_from_save_blob = true
        return
    _logi("metadata", "No save-scoped metadata blob found in loaded save; using fallback store.")

func attach_save_blob(desktop_data: Dictionary) -> void:
    if desktop_data == null:
        return
    _cleanup_orphans(false)
    _save_data["save_identity"] = _save_identity
    _save_data["updated_unix"] = Time.get_unix_time_from_system()
    desktop_data[SAVE_BLOB_KEY] = _save_data.duplicate(true)
    _save_save_fallback()

func flush() -> void:
    _cleanup_orphans(false)
    _save_global_data()
    _save_save_fallback()

func get_diagnostics_summary() -> Dictionary:
    var scopes := {}
    for scope: String in ALL_SCOPES:
        var owners: Dictionary = _get_scope_store(scope)
        var owner_count := owners.size()
        var key_count := 0
        var namespaces := {}
        for owner_key: String in owners.keys():
            var bucket: Variant = owners.get(owner_key, {})
            if not (bucket is Dictionary):
                continue
            for full_key: String in bucket.keys():
                key_count += 1
                var ns := _extract_namespace(full_key)
                if ns != "":
                    namespaces[ns] = int(namespaces.get(ns, 0)) + 1
        scopes[scope] = {
            "owners": owner_count,
            "keys": key_count,
            "namespaces": namespaces
        }
    return {
        "save_identity": _save_identity,
        "loaded_from_save_blob": _loaded_from_save_blob,
        "orphan_miss_counts": _orphan_miss_counts.duplicate(true),
        "scopes": scopes
    }

func _bind_events() -> void:
    if _event_bus == null or not _event_bus.has_method("on"):
        return
    _event_bus.on("game.started", Callable(self, "_on_game_started"), self, true)
    _event_bus.on("game.saving", Callable(self, "_on_game_saving"), self, true)
    _event_bus.on("game.desktop_ready", Callable(self, "_on_desktop_ready"), self, true)

func _on_game_started(_payload: Dictionary) -> void:
    var data := _get_autoload("Data")
    if data != null:
        var loading: Variant = data.get("loading") if data.has_method("get") else null
        if loading is Dictionary:
            var desktop_data: Variant = loading.get("desktop_data", {})
            if desktop_data is Dictionary:
                on_save_loaded(desktop_data)

func _on_game_saving(_payload: Dictionary) -> void:
    flush()

func _on_desktop_ready(_payload: Dictionary) -> void:
    _cleanup_orphans(true)

func _load_global_data() -> void:
    var path := _global_path()
    var data: Variant = _storage.read_json(path, {}) if _storage != null else {}
    if data is Dictionary and int(data.get("schema_version", 0)) == GLOBAL_SCHEMA_VERSION:
        _global_data = data.duplicate(true)
        if not _global_data.has("scopes"):
            _global_data["scopes"] = {}
    else:
        _global_data = {
            "schema_version": GLOBAL_SCHEMA_VERSION,
            "updated_unix": 0,
            "scopes": {}
        }

func _save_global_data() -> void:
    if _storage == null:
        return
    _global_data["updated_unix"] = Time.get_unix_time_from_system()
    var _ignored: Variant = _storage.write_json(_global_path(), _global_data, true)

func _load_save_fallback() -> void:
    var path := _save_fallback_path()
    var data: Variant = _storage.read_json(path, {}) if _storage != null else {}
    if data is Dictionary and int(data.get("schema_version", 0)) == SAVE_SCHEMA_VERSION:
        _save_data = data.duplicate(true)
    else:
        _reset_save_data()

func _save_save_fallback() -> void:
    if _storage == null:
        return
    _save_data["updated_unix"] = Time.get_unix_time_from_system()
    var _ignored: Variant = _storage.write_json(_save_fallback_path(), _save_data, true)

func _load_save_blob(blob: Dictionary) -> void:
    _save_data = {
        "schema_version": SAVE_SCHEMA_VERSION,
        "updated_unix": Time.get_unix_time_from_system(),
        "save_identity": _save_identity,
        "scopes": {}
    }
    var scopes: Variant = blob.get("scopes", {})
    if scopes is Dictionary:
        _save_data["scopes"] = scopes.duplicate(true)

func _reset_save_data() -> void:
    _save_data = {
        "schema_version": SAVE_SCHEMA_VERSION,
        "updated_unix": 0,
        "save_identity": "",
        "scopes": {}
    }

func _global_path() -> String:
    return _storage.get_data_path(MODULE_ID, "metadata_global.json") if _storage != null else "user://mods/TajemnikTV-Core/data/metadata_global.json"

func _save_fallback_path() -> String:
    return _storage.get_state_path(MODULE_ID, "metadata_save_fallback.json") if _storage != null else "user://mods/TajemnikTV-Core/state/metadata_save_fallback.json"

func _get_scope_store(scope: String) -> Dictionary:
    var source: Dictionary = _global_data if scope == SCOPE_GLOBAL else _save_data
    if not source.has("scopes"):
        source["scopes"] = {}
    var scopes: Variant = source.get("scopes", {})
    if not (scopes is Dictionary):
        scopes = {}
        source["scopes"] = scopes
    if not scopes.has(scope):
        scopes[scope] = {}
    var owners: Variant = scopes.get(scope, {})
    if not (owners is Dictionary):
        owners = {}
        scopes[scope] = owners
    return owners

func _is_valid_scope(scope: String) -> bool:
    return ALL_SCOPES.has(scope)

func _normalize_owner_id(owner_id: String) -> String:
    return owner_id.strip_edges()

func _is_valid_namespaced_key(key: String) -> bool:
    var clean := key.strip_edges()
    if clean == "":
        return false
    var split := clean.split(".", false, 1)
    if split.size() < 2:
        return false
    var ns := str(split[0])
    var local := str(split[1])
    if ns == "" or local == "":
        return false
    var regex := RegEx.new()
    var err := regex.compile("^[A-Za-z0-9_-]+\\.[A-Za-z0-9_.-]+$")
    if err != OK:
        return false
    return regex.search(clean) != null

func _is_json_compatible(value: Variant) -> bool:
    var t := typeof(value)
    if t == TYPE_NIL or t == TYPE_BOOL or t == TYPE_INT or t == TYPE_FLOAT or t == TYPE_STRING:
        return true
    if t == TYPE_ARRAY:
        for entry: Variant in value:
            if not _is_json_compatible(entry):
                return false
        return true
    if t == TYPE_DICTIONARY:
        for k: Variant in value.keys():
            if typeof(k) != TYPE_STRING:
                return false
            if not _is_json_compatible(value[k]):
                return false
        return true
    return false

func _duplicate_json_safe(value: Variant) -> Variant:
    if value is Dictionary or value is Array:
        return value.duplicate(true)
    return value

func _extract_namespace(key: String) -> String:
    var idx := key.find(".")
    if idx <= 0:
        return ""
    return key.substr(0, idx)

func _compute_save_identity(save_data: Dictionary) -> String:
    var globals_data: Variant = save_data.get("globals", {})
    if globals_data is Dictionary and not globals_data.is_empty():
        var payload: Dictionary = {
            "max_money": globals_data.get("max_money", 0),
            "max_research": globals_data.get("max_research", 0),
            "last_recorded_time": globals_data.get("last_recorded_time", 0),
            "save_ver": globals_data.get("save_ver", 0)
        }
        return str(payload.hash())
    return "unknown"

func _cleanup_orphans(log_only: bool) -> void:
    _cleanup_orphans_for_scope(SCOPE_WINDOW, _collect_live_window_ids(), log_only)
    _cleanup_orphans_for_scope(SCOPE_NODE, _collect_live_node_ids(), log_only)

func _cleanup_orphans_for_scope(scope: String, live_ids: Dictionary, log_only: bool) -> void:
    var owners: Dictionary = _get_scope_store(scope)
    var keys: Array = owners.keys()
    for owner_key_variant: Variant in keys:
        var owner_key := str(owner_key_variant)
        if owner_key == "":
            continue
        if live_ids.has(owner_key):
            _orphan_miss_counts.erase("%s|%s" % [scope, owner_key])
            continue
        var miss_key := "%s|%s" % [scope, owner_key]
        var misses: int = int(_orphan_miss_counts.get(miss_key, 0)) + 1
        _orphan_miss_counts[miss_key] = misses
        if misses < ORPHAN_DELETE_AFTER_MISSES:
            _logi("metadata", "Orphan candidate kept (%s, owner=%s, misses=%d)." % [scope, owner_key, misses])
            continue
        if log_only:
            _logi("metadata", "Orphan candidate reached delete threshold in log-only pass (%s, owner=%s)." % [scope, owner_key])
            continue
        owners.erase(owner_key)
        _orphan_miss_counts.erase(miss_key)
        _mark_dirty(scope)
        _logw("metadata", "Removed orphaned metadata owner (%s, owner=%s)." % [scope, owner_key])

func _collect_live_window_ids() -> Dictionary:
    var out := {}
    var desktop: Variant = _get_desktop()
    if desktop == null:
        return out
    var windows: Variant = desktop.get_node_or_null("Windows") if desktop.has_method("get_node_or_null") else null
    if windows != null and windows.has_method("get_children"):
        for child: Variant in windows.get_children():
            if child is Node:
                out[str(child.name)] = true
    var group_layer: Variant = desktop.get_node_or_null("CoreLayer_qol_groups") if desktop.has_method("get_node_or_null") else null
    if group_layer != null and group_layer.has_method("get_children"):
        for child: Variant in group_layer.get_children():
            if child is Node:
                out[str(child.name)] = true
    return out

func _collect_live_node_ids() -> Dictionary:
    var out := {}
    var tree: Variant = Engine.get_main_loop()
    if not (tree is SceneTree):
        return out
    for node: Node in tree.get_nodes_in_group("desktop"):
        out[str(node.name)] = true
    return out

func _get_desktop() -> Variant:
    var globals := _get_autoload("Globals")
    if globals != null and globals.has_method("get"):
        return globals.get("desktop")
    return null

func _get_autoload(autoload_name: String) -> Node:
    var tree: Variant = Engine.get_main_loop()
    if not (tree is SceneTree):
        return null
    return tree.get_root().get_node_or_null(autoload_name)

func _mark_dirty(scope: String) -> void:
    if scope == SCOPE_GLOBAL:
        _global_data["updated_unix"] = Time.get_unix_time_from_system()
    else:
        _save_data["updated_unix"] = Time.get_unix_time_from_system()

func _logi(channel: String, message: String) -> void:
    if _logger != null and _logger.has_method("info"):
        _logger.info(channel, message)

func _logw(channel: String, message: String) -> void:
    if _logger != null and _logger.has_method("warn"):
        _logger.warn(channel, message)
