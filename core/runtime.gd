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
var command_registry
var commands
var command_palette
var keybinds
var patches
var diagnostics
var module_registry
var modules
var workshop_sync
var ui_manager
var node_registry
var nodes
var util

var features
var assets
var localization
var theme_manager
var window_scenes
var file_variations
var window_menus
var tree_registry
var trees
var hook_manager
var upgrade_caps
var undo_stack
var node_finder
var safe_ops
var calculations
var resource_helpers
var hot_reload

var _version_util
var _extended_globals: Dictionary = {}
var _base_dir: String = ""

# Runtime patching state for scripts with class_name (can't use install_script_extension)
var _desktop_patched := false
var _desktop_patch_failed := false

func _init() -> void:
	bootstrap()

func _ready() -> void:
	if node_registry != null:
		node_registry.setup_signals()

func _process(_delta: float) -> void:
	# Runtime patching for Desktop (has class_name, can't use install_script_extension)
	if not _desktop_patched and not _desktop_patch_failed:
		if is_instance_valid(Globals.desktop) and patches != null:
			var desktop_ext := _base_dir.path_join("extensions/desktop.gd")
			var result: bool = patches.patch_desktop(desktop_ext)
			if result:
				_desktop_patched = true
			else:
				_desktop_patch_failed = true

func bootstrap() -> void:
	if Engine.has_meta(META_KEY) and Engine.get_meta(META_KEY) != self:
		_log_fallback("Core already registered, skipping bootstrap.")
		return
	Engine.set_meta(META_KEY, self)
	var base_dir: String = get_script().resource_path.get_base_dir()
	_base_dir = base_dir
	# Init order: version -> logger -> settings -> migrations -> event_bus -> commands -> keybinds -> patches -> diagnostics -> module_registry -> core.ready
	_version_util = _load_script(base_dir.path_join("version.gd"))
	var logger_script = _load_script(base_dir.path_join("logger.gd"))
	if logger_script != null:
		logger = logger_script.new()

	var settings_script = _load_script(base_dir.path_join("settings.gd"))
	if settings_script != null:
		settings = settings_script.new(logger)
		_register_core_schema()
		_apply_logger_settings()

	var features_script = _load_script(base_dir.path_join("features.gd"))
	if features_script != null and settings != null:
		features = features_script.new()
		features.setup(settings)

	var migrations_script = _load_script(base_dir.path_join("migrations.gd"))
	if migrations_script != null and settings != null:
		migrations = migrations_script.new(settings, logger, _version_util)
		_register_core_migrations()
		migrations.run_pending("core")

	var event_bus_script = _load_script(base_dir.path_join("event_bus.gd"))
	if event_bus_script != null:
		event_bus = event_bus_script.new(logger)
		_bridge_settings_events()

	var command_registry_script = _load_script(base_dir.path_join("commands/command_registry.gd"))
	if command_registry_script != null:
		command_registry = command_registry_script.new(logger, event_bus)
		commands = command_registry

	var assets_script = _load_script(base_dir.path_join("assets.gd"))
	if assets_script != null:
		assets = assets_script.new()

	var localization_script = _load_script(base_dir.path_join("localization.gd"))
	if localization_script != null:
		localization = localization_script.new()

	var theme_script = _load_script(base_dir.path_join("theme_manager.gd"))
	if theme_script != null:
		theme_manager = theme_script.new()

	var window_scenes_script = _load_script(base_dir.path_join("window_scenes.gd"))
	if window_scenes_script != null:
		window_scenes = window_scenes_script.new(logger)

	var file_variations_script = _load_script(base_dir.path_join("file_variations.gd"))
	if file_variations_script != null:
		file_variations = file_variations_script.new(settings, logger)

	var window_menus_script = _load_script(base_dir.path_join("window_menus.gd"))
	if window_menus_script != null:
		window_menus = window_menus_script.new()

	var tree_script = _load_script(base_dir.path_join("tree_registry.gd"))
	if tree_script != null:
		tree_registry = tree_script.new()
		trees = tree_registry

	var keybinds_script = _load_script(base_dir.path_join("keybinds.gd"))
	if keybinds_script != null:
		keybinds = keybinds_script.new()
		add_child(keybinds)
		keybinds.setup(settings, logger, event_bus)

	var patches_script = _load_script(base_dir.path_join("patches.gd"))
	if patches_script != null:
		patches = patches_script.new(logger)

	var util_script = _load_script(base_dir.path_join("util.gd"))
	if util_script != null:
		util = util_script.new()

	var calculations_script = _load_script(base_dir.path_join("util/calculations.gd"))
	if calculations_script != null:
		calculations = calculations_script.new()

	var node_finder_script = _load_script(base_dir.path_join("util/node_finder.gd"))
	if node_finder_script != null:
		node_finder = node_finder_script.new()

	var resource_helpers_script = _load_script(base_dir.path_join("util/resource_helpers.gd"))
	if resource_helpers_script != null:
		resource_helpers = resource_helpers_script.new()

	var safe_ops_script = _load_script(base_dir.path_join("util/safe_ops.gd"))
	if safe_ops_script != null:
		safe_ops = safe_ops_script.new()

	var undo_script = _load_script(base_dir.path_join("util/undo_stack.gd"))
	if undo_script != null:
		undo_stack = undo_script.new()

	var upgrade_caps_script = _load_script(base_dir.path_join("mechanics/upgrade_caps.gd"))
	if upgrade_caps_script != null:
		upgrade_caps = upgrade_caps_script.new(logger)

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

	var hooks_script = _load_script(base_dir.path_join("hooks/hook_manager.gd"))
	if hooks_script != null:
		hook_manager = hooks_script.new()
		hook_manager.name = "CoreHooks"
		hook_manager.setup(self)
		add_child(hook_manager)

	_install_modloader_extensions(base_dir)

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

func extend_globals(property: String, value: Variant) -> void:
	if property == "":
		return
	_extended_globals[property] = value

func get_extended_global(property: String, default_value: Variant = null) -> Variant:
	if _extended_globals.has(property):
		return _extended_globals[property]
	return default_value

func get_upgrade_cap(upgrade_id: String) -> int:
	if upgrade_caps != null:
		return upgrade_caps.get_effective_cap(upgrade_id)
	if Data.upgrades.has(upgrade_id):
		var limit := int(Data.upgrades[upgrade_id].limit)
		return -1 if limit == 0 else limit
	return -1

func register_extended_cap(upgrade_id: String, config: Dictionary) -> void:
	if upgrade_caps != null:
		upgrade_caps.register_extended_cap(upgrade_id, config)

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

func notify(icon: String, message: String) -> void:
	if ui_manager != null and ui_manager.has_method("show_notification"):
		ui_manager.show_notification(icon, message)
		return
	var signals = _get_autoload("Signals")
	if signals != null and signals.has_signal("notify"):
		signals.emit_signal("notify", icon, message)

func play_sound(sound_id: String) -> void:
	var sound = _get_autoload("Sound")
	if sound != null and sound.has_method("play"):
		sound.play(sound_id)

func copy_to_clipboard(text: String) -> void:
	DisplayServer.clipboard_set(text)

func register_settings_tab(mod_id: String, display_name: String, icon_path: String = "") -> VBoxContainer:
	"""Registers a settings tab for a mod. Returns null if UI not ready yet."""
	if ui_manager == null:
		return null
	return ui_manager.register_mod_settings_tab(mod_id, display_name, icon_path)

func get_settings_tab(mod_id: String) -> VBoxContainer:
	"""Returns an existing settings tab container for a mod."""
	if ui_manager == null:
		return null
	return ui_manager.get_mod_settings_tab(mod_id)

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
		},
		"core.features": {
			"type": "dict",
			"default": {},
			"description": "Feature flag overrides"
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

func _get_autoload(name: String) -> Object:
	if Engine.has_singleton(name):
		return Engine.get_singleton(name)
	if Engine.get_main_loop() == null:
		return null
	var root = Engine.get_main_loop().root
	if root == null:
		return null
	return root.get_node_or_null(name)

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

	var hot_reload_script = _load_script(base_dir.path_join("dev/hot_reload.gd"))
	if hot_reload_script != null:
		hot_reload = hot_reload_script.new()
		hot_reload.name = "HotReload"
		add_child(hot_reload)

func _start_workshop_sync() -> void:
	if workshop_sync != null:
		workshop_sync.start_sync()

func _install_modloader_extensions(base_dir: String) -> void:
	if not TajsCoreUtil.has_global_class("ModLoaderMod"):
		return
	# NOTE: Scripts with class_name cannot use install_script_extension() because
	# ModLoader's take_over_path() creates a conflict. These are handled specially:
	# - desktop.gd (class_name Desktop) - uses runtime patching in _process()
	# - window_container.gd (class_name WindowContainer) - not yet reimplemented
	# See _process() for desktop runtime patching logic.
	var paths := [
		base_dir.path_join("extensions/data.gd"),
		base_dir.path_join("extensions/windows_menu.gd"),
		base_dir.path_join("extensions/window_dragger.gd"),
		base_dir.path_join("extensions/hud.gd"),
		base_dir.path_join("extensions/main.gd"),
		base_dir.path_join("extensions/utils.gd")
	]
	for path in paths:
		ModLoaderMod.install_script_extension(path)
