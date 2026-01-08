# ==============================================================================
# Taj's Core - Runtime
# Author: TajemnikTV
# Description: Runtime
# ==============================================================================
class_name TajsCoreRuntime
extends Node

const CORE_VERSION := "1.0.0"
const API_LEVEL := 1
const META_KEY := "TajsCore"

var logger
var settings
var migrations
var event_bus
var keybinds
var patches
var diagnostics
var module_registry
var modules
var workshop_sync
var ui_manager
var node_registry
var nodes

var _version_util

func _init() -> void:
    bootstrap()

func _ready() -> void:
    if node_registry != null:
        node_registry.setup_signals()

func bootstrap() -> void:
    if Engine.has_meta(META_KEY) and Engine.get_meta(META_KEY) != self:
        _log_fallback("Core already registered, skipping bootstrap.")
        return
    Engine.set_meta(META_KEY, self)
    var base_dir: String = get_script().resource_path.get_base_dir()
    # Init order: version -> logger -> settings -> migrations -> event_bus -> keybinds -> patches -> diagnostics -> module_registry -> core.ready
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
        _register_core_migrations()
        migrations.run_pending("core")

    var event_bus_script = _load_script(base_dir.path_join("event_bus.gd"))
    if event_bus_script != null:
        event_bus = event_bus_script.new(logger)
        _bridge_settings_events()

    var keybinds_script = _load_script(base_dir.path_join("keybinds.gd"))
    if keybinds_script != null:
        keybinds = keybinds_script.new()
        add_child(keybinds)
        keybinds.setup(settings, logger, event_bus)

    var patches_script = _load_script(base_dir.path_join("patches.gd"))
    if patches_script != null:
        patches = patches_script.new(logger)

    var node_registry_script = _load_script(base_dir.path_join("nodes/node_registry.gd"))
    if node_registry_script != null:
        node_registry = node_registry_script.new(logger, event_bus, patches)
        nodes = node_registry

    var diagnostics_script = _load_script(base_dir.path_join("diagnostics.gd"))
    if diagnostics_script != null:
        diagnostics = diagnostics_script.new(self, logger)

    var registry_script = _load_script(base_dir.path_join("module_registry.gd"))
    if registry_script != null:
        module_registry = registry_script.new(self, logger, event_bus)
        modules = module_registry

    if event_bus != null:
        event_bus.emit("core.ready", {"version": CORE_VERSION, "api_level": API_LEVEL}, true)
    if logger != null:
        logger.info("core", "Taj's Core ready (%s)." % CORE_VERSION)

    _init_optional_services(base_dir)

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
        "core.debug": {
            "type": "bool",
            "default": false,
            "description": "Enable debug logging"
        },
        "core.debug_log": {
            "type": "bool",
            "default": false,
            "description": "Deprecated: use core.debug"
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
        "core.ui.disable_slider_scroll": {
            "type": "bool",
            "default": false,
            "description": "Prevent mouse wheel from changing slider values in Core UI"
        },
        "core.workshop.sync_on_startup": {
            "type": "bool",
            "default": true,
            "description": "Check Workshop updates on startup"
        },
        "core.workshop.high_priority": {
            "type": "bool",
            "default": true,
            "description": "Use high priority for Workshop downloads"
        },
        "core.workshop.force_download_all": {
            "type": "bool",
            "default": true,
            "description": "Request downloads for all subscribed items"
        },
        "core.keybinds.overrides": {
            "type": "dict",
            "default": {},
            "description": "Keybind overrides"
        }
    }
    settings.register_schema("core", schema)

func _apply_logger_settings() -> void:
    var debug_enabled: bool = settings.get_bool("core.debug", settings.get_bool("core.debug_log", false))
    logger.set_debug_enabled(debug_enabled)
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

func _bridge_settings_events() -> void:
    if settings == null or event_bus == null:
        return
    settings.value_changed.connect(Callable(self, "_on_settings_changed"))

func _on_settings_changed(key: String, value: Variant, old_value: Variant) -> void:
    if event_bus == null:
        return
    event_bus.emit("settings.changed", {"key": key, "old": old_value, "new": value})

func _register_core_migrations() -> void:
    if migrations == null or settings == null:
        return
    migrations.register_migration("core", "1.0.0", func() -> void:
        if settings.get_value("core.debug", null) == null and settings.get_value("core.debug_log", null) != null:
            settings.set_value("core.debug", settings.get_bool("core.debug_log", false))
    )

func _init_optional_services(base_dir: String) -> void:
    if settings == null:
        return
    var workshop_script = _load_script(base_dir.path_join("workshop_sync.gd"))
    if workshop_script != null:
        workshop_sync = workshop_script.new()
        workshop_sync.name = "WorkshopSync"
        workshop_sync.setup(logger)
        workshop_sync.sync_on_startup = settings.get_bool("core.workshop.sync_on_startup", true)
        workshop_sync.high_priority_downloads = settings.get_bool("core.workshop.high_priority", true)
        workshop_sync.force_download_all = settings.get_bool("core.workshop.force_download_all", true)
        add_child(workshop_sync)
        if workshop_sync.sync_on_startup:
            call_deferred("_start_workshop_sync")

    var ui_manager_script = _load_script(base_dir.path_join("ui/ui_manager.gd"))
    if ui_manager_script != null:
        ui_manager = ui_manager_script.new()
        ui_manager.name = "CoreUiManager"
        ui_manager.setup(self, workshop_sync)
        add_child(ui_manager)

func _start_workshop_sync() -> void:
    if workshop_sync != null:
        workshop_sync.start_sync()
