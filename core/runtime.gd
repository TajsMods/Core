# ==============================================================================
# Taj's Core - Runtime
# Author: TajemnikTV
# Description: Runtime
# ==============================================================================
class_name TajsCoreRuntime
extends Node

const CORE_VERSION := "1.0.0"
const API_LEVEL := 1
const META_KEY := "core"

var logger
var settings
var migrations
var event_bus
var keybinds
var patches
var diagnostics
var module_registry

var _version_util

func _init() -> void:
    bootstrap()

func bootstrap() -> void:
    if Engine.has_meta(META_KEY) and Engine.get_meta(META_KEY) != self:
        _log_fallback("Core already registered, skipping bootstrap.")
        return
    Engine.set_meta(META_KEY, self)
    var base_dir: String = get_script().resource_path.get_base_dir()
    _version_util = _load_script(base_dir.path_join("version.gd"))
    var logger_script = _load_script(base_dir.path_join("logger.gd"))
    if logger_script != null:
        logger = logger_script.new()

    var settings_script = _load_script(base_dir.path_join("settings.gd"))
    if settings_script != null:
        settings = settings_script.new(logger)
        _register_core_schema()
        _apply_logger_settings()

    var migrations_script = _load_script(base_dir.path_join("migrations.gd"))
    if migrations_script != null and settings != null:
        migrations = migrations_script.new(settings, logger, _version_util)

    var event_bus_script = _load_script(base_dir.path_join("event_bus.gd"))
    if event_bus_script != null:
        event_bus = event_bus_script.new(logger)

    var keybinds_script = _load_script(base_dir.path_join("keybinds.gd"))
    if keybinds_script != null:
        keybinds = keybinds_script.new()
        add_child(keybinds)
        keybinds.setup(settings, logger, event_bus)

    var patches_script = _load_script(base_dir.path_join("patches.gd"))
    if patches_script != null:
        patches = patches_script.new(logger)

    var diagnostics_script = _load_script(base_dir.path_join("diagnostics.gd"))
    if diagnostics_script != null:
        diagnostics = diagnostics_script.new(self, logger)

    var registry_script = _load_script(base_dir.path_join("module_registry.gd"))
    if registry_script != null:
        module_registry = registry_script.new(self, logger, event_bus)

    if migrations != null:
        migrations.run_all()
    if event_bus != null:
        event_bus.emit("core.ready", {"version": CORE_VERSION, "api_level": API_LEVEL}, true)
    if logger != null:
        logger.info("core", "Taj's Core ready (%s)." % CORE_VERSION)

func get_version() -> String:
    return CORE_VERSION

func get_api_level() -> int:
    return API_LEVEL

func compare_versions(a: String, b: String) -> int:
    if _version_util != null:
        return _version_util.compare_versions(a, b)
    return 0

func require(min_version: String) -> bool:
    if min_version == "":
        return true
    return compare_versions(CORE_VERSION, min_version) >= 0

func register_module(meta: Dictionary) -> bool:
    if module_registry == null:
        return false
    return module_registry.register_module(meta)

func logd(module_id: String, message: String) -> void:
    if logger != null:
        logger.debug(module_id, message)

func logi(module_id: String, message: String) -> void:
    if logger != null:
        logger.info(module_id, message)

func logw(module_id: String, message: String) -> void:
    if logger != null:
        logger.warn(module_id, message)

func loge(module_id: String, message: String) -> void:
    if logger != null:
        logger.error(module_id, message)

static func instance() -> TajsCoreRuntime:
    if Engine.has_meta(META_KEY):
        return Engine.get_meta(META_KEY)
    return null

static func require_core(min_version: String) -> bool:
    var core = instance()
    if core == null:
        return false
    return core.require(min_version)

func _register_core_schema() -> void:
    var schema := {
        "core.debug_log": {
            "type": "bool",
            "default": false,
            "description": "Enable debug logging"
        },
        "core.log_to_file": {
            "type": "bool",
            "default": false,
            "description": "Write logs to user://tajs_core.log"
        },
        "core.log_file_path": {
            "type": "string",
            "default": "user://tajs_core.log",
            "description": "Override log file path"
        },
        "core.log_ring_size": {
            "type": "int",
            "default": 200,
            "description": "In-memory log history size"
        },
        "core.keybinds.overrides": {
            "type": "dict",
            "default": {},
            "description": "Keybind overrides"
        }
    }
    settings.register_schema("core", schema)

func _apply_logger_settings() -> void:
    logger.set_debug_enabled(settings.get_bool("core.debug_log", false))
    logger.set_ring_size(settings.get_int("core.log_ring_size", 200))
    var file_path: String = settings.get_string("core.log_file_path", "user://tajs_core.log")
    logger.set_file_logging(settings.get_bool("core.log_to_file", false), file_path)

func _load_script(path: String):
    var script = load(path)
    if script == null:
        _log_fallback("Failed to load script: %s" % path)
    return script

func _log_fallback(message: String) -> void:
    if logger != null:
        logger.warn("core", message)
    else:
        print("TajsCore: %s" % message)
