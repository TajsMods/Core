class_name TajsCoreRuntime
extends Node

var CORE_VERSION: String = "0.0.0"
const API_LEVEL := 1
const META_KEY := "TajsCore"

var logger: Variant
var storage: Variant
var settings: Variant
var migrations: Variant
var event_bus: Variant
var command_registry: Variant
var commands: Variant
var context_menu: Variant
var context_menus: Variant
var command_palette: Variant
var command_palette_controller: Variant
var command_palette_overlay: Variant
var keybinds: Variant
var patches: Variant
var diagnostics: Variant
var module_registry: Variant
var modules: Variant
var workshop_sync: Variant
var ui_manager: Variant
var node_registry: Variant
var nodes: Variant
var util: Variant

var features: Variant
var assets: Variant
var localization: Variant
var theme_manager: Variant
var font_registry: Variant
var fonts: Variant
var theme_editor: Variant
var icon_registry: Variant
var window_scenes: Variant
var file_variations: Variant
var window_menus: Variant
var tree_registry: Variant
var trees: Variant
var hook_manager: Variant
var upgrade_caps: Variant
var undo_manager: Variant
var node_finder: Variant
var safe_ops: Variant
var calculations: Variant
var economy_helpers: Variant
var node_limit_helpers: Variant
var resource_helpers: Variant
var connectivity_helpers: Variant
var boot_screen: Variant
var desktop_layers: Variant

var _version_util: Variant
var _extended_globals: Dictionary = {}
var _base_dir: String = ""
var _manual_icons: Dictionary = {} # icon_id -> path
var _manual_icon_source_registered := false

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
    Engine.set_meta(META_KEY, self )
    var base_dir: String = get_script().resource_path.get_base_dir()
    _base_dir = base_dir
    CORE_VERSION = _read_version_from_manifest(base_dir.get_base_dir().path_join("manifest.json"))
    # Init order: version -> logger -> settings -> migrations -> event_bus -> commands -> keybinds -> patches -> diagnostics -> module_registry -> core.ready
    _version_util = _load_script(base_dir.path_join("version.gd"))
    var logger_script: Variant = _load_script(base_dir.path_join("logger.gd"))
    if logger_script != null:
        logger = logger_script.new()

    var storage_script: Variant = _load_script(base_dir.path_join("storage.gd"))
    if storage_script != null:
        storage = storage_script.new(logger)

    var settings_script: Variant = _load_script(base_dir.path_join("settings.gd"))
    if settings_script != null:
        settings = settings_script.new(logger, storage)
        _register_core_schema()
        _apply_logger_settings()

    var features_script: Variant = _load_script(base_dir.path_join("features.gd"))
    if features_script != null and settings != null:
        features = features_script.new()
        features.setup(settings)

    var migrations_script: Variant = _load_script(base_dir.path_join("migrations.gd"))
    if migrations_script != null and settings != null:
        migrations = migrations_script.new(settings, logger, _version_util)
        _register_core_migrations()
        migrations.run_pending("core")

    var event_bus_script: Variant = _load_script(base_dir.path_join("event_bus.gd"))
    if event_bus_script != null:
        event_bus = event_bus_script.new(logger)
        _bridge_settings_events()
        _bind_command_palette_events()

    var command_registry_script: Variant = _load_script(base_dir.path_join("commands/command_registry.gd"))
    if command_registry_script != null:
        command_registry = command_registry_script.new(logger, event_bus)
        commands = command_registry

    var context_menu_script: Variant = _load_script(base_dir.path_join("context_menu/context_menu_service.gd"))
    if context_menu_script != null:
        context_menu = context_menu_script.new(logger, event_bus)
        context_menus = context_menu

    var assets_script: Variant = _load_script(base_dir.path_join("assets.gd"))
    if assets_script != null:
        assets = assets_script.new()
    var icon_registry_script: Variant = _load_script(base_dir.path_join("icon_registry.gd"))
    if icon_registry_script != null:
        icon_registry = icon_registry_script.new(assets)

    var localization_script: Variant = _load_script(base_dir.path_join("localization.gd"))
    if localization_script != null:
        localization = localization_script.new()

    var theme_script: Variant = _load_script(base_dir.path_join("theme_manager.gd"))
    if theme_script != null:
        theme_manager = theme_script.new()
        # Apply tooltip styling to match in-game UI design
        if theme_manager.has_method("apply_tooltip_styling"):
            call_deferred("_apply_tooltip_styling")
    var font_registry_script: Variant = _load_script(base_dir.path_join("font_registry.gd"))
    if font_registry_script != null:
        font_registry = font_registry_script.new(logger, settings, theme_manager)
        fonts = font_registry
    if theme_manager != null and theme_manager.has_method("set_services"):
        theme_manager.set_services(font_registry, logger)
    # Backward-compatible alias: theme editor API now lives in theme_manager.
    theme_editor = theme_manager

    var window_scenes_script: Variant = _load_script(base_dir.path_join("window_scenes.gd"))
    if window_scenes_script != null:
        window_scenes = window_scenes_script.new(logger)

    var file_variations_script: Variant = _load_script(base_dir.path_join("file_variations.gd"))
    if file_variations_script != null:
        file_variations = file_variations_script.new(settings, logger)

    var window_menus_script: Variant = _load_script(base_dir.path_join("window_menus.gd"))
    if window_menus_script != null:
        window_menus = window_menus_script.new()
        window_menus.set_event_bus(event_bus)

    var tree_script: Variant = _load_script(base_dir.path_join("tree_registry.gd"))
    if tree_script != null:
        tree_registry = tree_script.new()
        trees = tree_registry

    var keybinds_script: Variant = _load_script(base_dir.path_join("keybinds.gd"))
    if keybinds_script != null:
        keybinds = keybinds_script.new()
        add_child(keybinds)
        keybinds.setup(settings, logger, event_bus)

    var patches_script: Variant = _load_script(base_dir.path_join("patches.gd"))
    if patches_script != null:
        patches = patches_script.new(logger)

    var util_script: Variant = _load_script(base_dir.path_join("util.gd"))
    if util_script != null:
        util = util_script.new()

    var calculations_script: Variant = _load_script(base_dir.path_join("util/calculations.gd"))
    if calculations_script != null:
        calculations = calculations_script.new()

    var economy_helpers_script: Variant = _load_script(base_dir.path_join("util/economy_helpers.gd"))
    if economy_helpers_script != null:
        economy_helpers = economy_helpers_script.new()

    var node_limit_helpers_script: Variant = _load_script(base_dir.path_join("util/node_limit_helpers.gd"))
    if node_limit_helpers_script != null:
        node_limit_helpers = node_limit_helpers_script.new()

    var node_finder_script: Variant = _load_script(base_dir.path_join("util/node_finder.gd"))
    if node_finder_script != null:
        node_finder = node_finder_script.new()

    var resource_helpers_script: Variant = _load_script(base_dir.path_join("util/resource_helpers.gd"))
    if resource_helpers_script != null:
        resource_helpers = resource_helpers_script.new()

    var connectivity_script: Variant = _load_script(base_dir.path_join("util/connectivity_helpers.gd"))
    if connectivity_script != null:
        connectivity_helpers = connectivity_script.new()

    var safe_ops_script: Variant = _load_script(base_dir.path_join("util/safe_ops.gd"))
    if safe_ops_script != null:
        safe_ops = safe_ops_script.new()

    var undo_script: Variant = _load_script(base_dir.path_join("util/undo_manager.gd"))
    if undo_script != null:
        undo_manager = undo_script.new(logger)
        undo_manager.setup()
        _register_undo_keybinds()

    var upgrade_caps_script: Variant = _load_script(base_dir.path_join("mechanics/upgrade_caps.gd"))
    if upgrade_caps_script != null:
        upgrade_caps = upgrade_caps_script.new(logger)

    var node_registry_script: Variant = _load_script(base_dir.path_join("nodes/node_registry.gd"))
    if node_registry_script != null:
        node_registry = node_registry_script.new(logger, event_bus, patches)
        nodes = node_registry


    var diagnostics_script: Variant = _load_script(base_dir.path_join("diagnostics.gd"))
    if diagnostics_script != null:
        diagnostics = diagnostics_script.new(self , logger)

    var registry_script: Variant = _load_script(base_dir.path_join("module_registry.gd"))
    if registry_script != null:
        module_registry = registry_script.new(self , logger, event_bus)
        modules = module_registry

    var hooks_script: Variant = _load_script(base_dir.path_join("hooks/hook_manager.gd"))
    if hooks_script != null:
        hook_manager = hooks_script.new()
        hook_manager.name = "CoreHooks"
        hook_manager.setup(self )
        add_child(hook_manager)

    var desktop_layers_script: Variant = _load_script(base_dir.path_join("desktop_layers.gd"))
    if desktop_layers_script != null:
        desktop_layers = desktop_layers_script.new(logger, event_bus)
        desktop_layers.setup()

    _install_modloader_extensions(base_dir)

    if event_bus != null:
        event_bus.emit("core.ready", {"version": CORE_VERSION, "api_level": API_LEVEL}, true)
    if logger != null:
        logger.info("core", "Taj's Core ready (%s)." % CORE_VERSION)
    _init_boot_screen(base_dir)
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
    var signals: Variant = _get_autoload("Signals")
    if signals != null and signals.has_signal("notify"):
        var _ignored: Variant = signals.emit_signal("notify", icon, message)

func play_sound(sound_id: String) -> void:
    var sound: Variant = _get_autoload("Sound")
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

func get_game_theme() -> Theme:
    """Returns the game's main.tres theme for consistent font and styling."""
    if theme_manager != null:
        return theme_manager.get_game_theme()
    # Fallback if theme_manager not ready
    if ResourceLoader.exists("res://themes/main.tres"):
        return load("res://themes/main.tres")
    return null

func get_icon_registry() -> Variant: # Returns TajsCoreIconRegistry (Variant to avoid parse errors)
    return icon_registry

func register_window_tab(data: Dictionary) -> Dictionary:
    if window_menus == null:
        return {"ok": false, "error": "window_menus_unavailable"}
    if data.is_empty():
        return {"ok": false, "error": "tab_data_empty"}
    var id_info: Dictionary = _split_namespaced_id(str(data.get("id", "")))
    if not id_info.get("ok", false):
        logw("core", "register_window_tab failed: %s" % id_info.get("error", "invalid_id"))
        return id_info
    var mod_id: String = id_info["mod_id"]
    var tab_id: String = id_info["local_id"]
    var existing_index: int = int(window_menus.get_tab_index(mod_id, tab_id))
    if existing_index >= 0:
        logw("core", "register_window_tab duplicate id: %s" % str(data.get("id", "")))
        return {
            "ok": false,
            "error": "duplicate_id",
            "id": str(data.get("id", "")),
            "mod_id": mod_id,
            "tab_id": tab_id,
            "index": existing_index
        }
    var title: String = str(data.get("title", tab_id)).strip_edges()
    var rows: Variant = data.get("rows", data.get("categories", []))
    if rows == null or (rows is Array and rows.is_empty()) or (rows is Dictionary and rows.is_empty()):
        rows = [{"default": title}]
    var config := data.duplicate(true)
    config["rows"] = rows
    if not config.has("button_name") and not config.has("button_id"):
        config["button_name"] = str(data.get("button_name", tab_id))
    var index: int = window_menus.register_tab(mod_id, tab_id, config)
    return {
        "ok": index >= 0,
        "id": str(data.get("id", "")),
        "mod_id": mod_id,
        "tab_id": tab_id,
        "index": index
    }

func register_file_variation(id: String, variation_data: Dictionary, symbol: String = "", symbol_type: String = "file") -> Dictionary:
    if file_variations == null:
        return {"ok": false, "error": "file_variations_unavailable"}
    if variation_data.is_empty():
        return {"ok": false, "error": "variation_data_empty", "id": id}
    var id_info: Dictionary = _split_namespaced_id(id)
    if not id_info.get("ok", false):
        logw("core", "register_file_variation failed: %s" % id_info.get("error", "invalid_id"))
        return id_info
    var existing_mask: int = file_variations.get_mask(id_info["mod_id"], id_info["local_id"])
    if existing_mask != 0:
        logw("core", "register_file_variation duplicate id: %s" % id)
        return {
            "ok": false,
            "error": "duplicate_id",
            "id": id,
            "mod_id": id_info["mod_id"],
            "local_id": id_info["local_id"],
            "mask": existing_mask
        }
    var symbols := {}
    if symbol != "":
        symbols[id_info["local_id"]] = symbol
    var masks: Dictionary = file_variations.register_variations(id_info["mod_id"], {id_info["local_id"]: variation_data}, symbols, symbol_type)
    var mask: int = int(masks.get(id_info["local_id"], 0))
    return {
        "ok": mask != 0,
        "id": id,
        "mod_id": id_info["mod_id"],
        "local_id": id_info["local_id"],
        "mask": mask
    }

func register_research_entry(id: String, entry_data: Dictionary, mode: String = "add") -> Dictionary:
    if tree_registry == null:
        return {"ok": false, "error": "tree_registry_unavailable"}
    var normalized_mode := mode.strip_edges().to_lower()
    if normalized_mode != "add" and normalized_mode != "move":
        return {"ok": false, "error": "invalid_mode", "id": id, "mode": mode}
    var id_info: Dictionary = _split_namespaced_id(id)
    if not id_info.get("ok", false):
        logw("core", "register_research_entry failed: %s" % id_info.get("error", "invalid_id"))
        return id_info
    var payload: Dictionary = entry_data.duplicate(true)
    payload["name"] = id_info["id"]
    payload["owner_mod_id"] = id_info["mod_id"]
    if normalized_mode == "move":
        tree_registry.move_research_node(payload)
    else:
        tree_registry.add_research_node(payload)
    return {"ok": true, "id": id_info["id"], "mode": normalized_mode, "mod_id": id_info["mod_id"], "local_id": id_info["local_id"]}

func register_ascension_entry(id: String, entry_data: Dictionary, mode: String = "add") -> Dictionary:
    if tree_registry == null:
        return {"ok": false, "error": "tree_registry_unavailable"}
    var normalized_mode := mode.strip_edges().to_lower()
    if normalized_mode != "add" and normalized_mode != "move":
        return {"ok": false, "error": "invalid_mode", "id": id, "mode": mode}
    var id_info: Dictionary = _split_namespaced_id(id)
    if not id_info.get("ok", false):
        logw("core", "register_ascension_entry failed: %s" % id_info.get("error", "invalid_id"))
        return id_info
    var payload: Dictionary = entry_data.duplicate(true)
    payload["name"] = id_info["id"]
    payload["owner_mod_id"] = id_info["mod_id"]
    if normalized_mode == "move":
        tree_registry.move_ascension_node(payload)
    else:
        tree_registry.add_ascension_node(payload)
    return {"ok": true, "id": id_info["id"], "mode": normalized_mode, "mod_id": id_info["mod_id"], "local_id": id_info["local_id"]}

func register_icon(id: String, icon_path: String) -> Dictionary:
    var id_info: Dictionary = _split_namespaced_id(id)
    if not id_info.get("ok", false):
        logw("core", "register_icon failed: %s" % id_info.get("error", "invalid_id"))
        return id_info
    if _manual_icons.has(id):
        logw("core", "register_icon duplicate id: %s" % id)
        return {"ok": false, "error": "duplicate_id", "id": id, "path": str(_manual_icons[id])}
    if icon_path == "" or not ResourceLoader.exists(icon_path):
        return {"ok": false, "error": "icon_not_found", "id": id, "path": icon_path}
    _manual_icons[id] = icon_path
    _ensure_manual_icon_source()
    if icon_registry != null and icon_registry.has_method("refresh_index"):
        icon_registry.refresh_index()
    return {"ok": true, "id": id, "path": icon_path}

func register_translation_path(path: String) -> Dictionary:
    if localization == null:
        return {"ok": false, "error": "localization_unavailable"}
    if path.strip_edges() == "":
        return {"ok": false, "error": "path_empty"}
    var ok: bool = bool(localization.register_translation(path))
    return {"ok": ok, "path": path, "error": "" if ok else "register_failed"}

func register_translation(mod_id: String, path: String) -> Dictionary:
    var id_info: Dictionary = _validate_mod_id(mod_id)
    if not id_info.get("ok", false):
        logw("core", "register_translation failed: %s" % id_info.get("error", "invalid_mod_id"))
        return id_info
    var result: Dictionary = register_translation_path(path)
    result["mod_id"] = mod_id
    return result

func register_translations_dir(dir_path: String) -> Dictionary:
    if localization == null:
        return {"ok": false, "error": "localization_unavailable"}
    if dir_path.strip_edges() == "":
        return {"ok": false, "error": "dir_path_empty"}
    var count: int = int(localization.register_translations_dir(dir_path))
    return {"ok": count > 0, "dir_path": dir_path, "count": count, "error": "" if count > 0 else "register_failed"}

func register_translation_dir(mod_id: String, dir_path: String) -> Dictionary:
    var id_info: Dictionary = _validate_mod_id(mod_id)
    if not id_info.get("ok", false):
        logw("core", "register_translation_dir failed: %s" % id_info.get("error", "invalid_mod_id"))
        return id_info
    var result: Dictionary = register_translations_dir(dir_path)
    result["mod_id"] = mod_id
    return result

func register_window_directory(dir_path: String) -> Dictionary:
    if window_scenes == null:
        return {"ok": false, "error": "window_scenes_unavailable"}
    if dir_path.strip_edges() == "":
        return {"ok": false, "error": "dir_path_empty"}
    var ok: bool = bool(window_scenes.register_dir(dir_path))
    return {"ok": ok, "dir_path": dir_path, "error": "" if ok else "register_failed"}

func register_settings_schema(module_id: String, schema: Dictionary, namespace_prefix: String = "") -> Dictionary:
    if settings == null:
        return {"ok": false, "error": "settings_unavailable"}
    if module_id.strip_edges() == "":
        return {"ok": false, "error": "module_id_empty"}
    if schema.is_empty():
        return {"ok": false, "error": "schema_empty", "module_id": module_id}
    settings.register_schema(module_id, schema, namespace_prefix)
    return {"ok": true, "module_id": module_id, "keys": schema.keys().size()}

func register_action(command_id: String, meta: Dictionary = {}, callback: Callable = Callable()) -> Dictionary:
    if command_registry == null:
        return {"ok": false, "error": "command_registry_unavailable"}
    var id_info: Dictionary = _split_namespaced_id(command_id)
    if not id_info.get("ok", false):
        logw("core", "register_action failed: %s" % id_info.get("error", "invalid_id"))
        return id_info
    var ok: bool = command_registry.register_command(command_id, meta, callback)
    return {"ok": ok, "id": command_id, "error": "" if ok else "register_failed"}

func run_command(command_id: String, context: Variant = null) -> bool:
    if command_registry != null and command_registry.has_method("execute"):
        return command_registry.execute(command_id, context)
    return false

func register_font(font_id: String, font_path: String) -> Dictionary:
    if font_registry == null:
        return {"ok": false, "error": "font_registry_unavailable"}
    return font_registry.register_font(font_id, font_path)

func apply_font_to_class(control_class_name: String, font_id: String, property_name: String = "font") -> Dictionary:
    if font_registry == null:
        return {"ok": false, "error": "font_registry_unavailable"}
    return font_registry.apply_font_to_class(control_class_name, font_id, property_name)

func apply_font_to_node(node: Node, font_id: String, opts: Dictionary = {}) -> Dictionary:
    if font_registry == null:
        return {"ok": false, "error": "font_registry_unavailable"}
    return font_registry.apply_font_to_node(node, font_id, opts)

func build_font_theme(class_map: Dictionary, save_to_user: bool = false, output_path: String = "") -> Dictionary:
    if font_registry == null:
        return {"ok": false, "error": "font_registry_unavailable"}
    var result: Dictionary = font_registry.build_theme(class_map, save_to_user, output_path)
    if not save_to_user and font_registry.has_method("maybe_persist_theme"):
        var persisted: Dictionary = font_registry.maybe_persist_theme(class_map)
        result["persisted_by_config"] = persisted
    return result

func apply_font_to_guide_panel(panel: Node, font_id: String) -> Dictionary:
    if font_registry == null:
        return {"ok": false, "error": "font_registry_unavailable"}
    if panel == null:
        return {"ok": false, "error": "panel_null"}
    var label: RichTextLabel = panel.get_node_or_null("PanelContainer/Label")
    if label == null:
        return {"ok": false, "error": "guide_label_not_found"}
    return font_registry.apply_font_to_node(label, font_id, {})

func apply_font_to_window_menu_panel(panel: Node, font_id: String) -> Dictionary:
    if font_registry == null:
        return {"ok": false, "error": "font_registry_unavailable"}
    if panel == null:
        return {"ok": false, "error": "panel_null"}
    return font_registry.apply_font_to_tree(panel, font_id, "Control")

func theme_create_profile(profile_id: String, base_theme_id: String = "default") -> Dictionary:
    if theme_editor == null:
        return {"ok": false, "error": "theme_editor_unavailable"}
    if not _split_namespaced_id(profile_id).get("ok", false):
        return {"ok": false, "error": "profile_id_must_be_namespaced_modid.localid", "profile_id": profile_id}
    return theme_editor.create_profile(profile_id, base_theme_id)

func theme_set_color(profile_id: String, color_name: String, control_class_name: String, color: Color) -> Dictionary:
    if theme_editor == null:
        return {"ok": false, "error": "theme_editor_unavailable"}
    return theme_editor.set_color(profile_id, color_name, control_class_name, color)

func theme_set_constant(profile_id: String, constant_name: String, control_class_name: String, value: int) -> Dictionary:
    if theme_editor == null:
        return {"ok": false, "error": "theme_editor_unavailable"}
    return theme_editor.set_constant(profile_id, constant_name, control_class_name, value)

func theme_set_font(profile_id: String, control_class_name: String, property_name: String, font_id: String) -> Dictionary:
    if theme_editor == null:
        return {"ok": false, "error": "theme_editor_unavailable"}
    return theme_editor.set_font(profile_id, control_class_name, property_name, font_id)

func theme_set_stylebox_flat(profile_id: String, stylebox_name: String, control_class_name: String, opts: Dictionary) -> Dictionary:
    if theme_editor == null:
        return {"ok": false, "error": "theme_editor_unavailable"}
    return theme_editor.set_stylebox_flat(profile_id, stylebox_name, control_class_name, opts)

func theme_apply_profile_to_node(profile_id: String, node: Control) -> Dictionary:
    if theme_editor == null:
        return {"ok": false, "error": "theme_editor_unavailable"}
    return theme_editor.apply_profile_to_node(profile_id, node)

func theme_save_profile(profile_id: String, output_path: String = "") -> Dictionary:
    if theme_editor == null:
        return {"ok": false, "error": "theme_editor_unavailable"}
    return theme_editor.save_profile(profile_id, output_path)

func theme_load_profile(profile_id: String, input_path: String) -> Dictionary:
    if theme_editor == null:
        return {"ok": false, "error": "theme_editor_unavailable"}
    if not _split_namespaced_id(profile_id).get("ok", false):
        return {"ok": false, "error": "profile_id_must_be_namespaced_modid.localid", "profile_id": profile_id}
    if input_path.strip_edges() == "":
        return {"ok": false, "error": "input_path_empty", "profile_id": profile_id}
    return theme_editor.load_profile(profile_id, input_path)

static func instance() -> TajsCoreRuntime:
    if Engine.has_meta(META_KEY):
        return Engine.get_meta(META_KEY)
    return null

static func require_core(min_version: String) -> bool:
    var core: Variant = instance()
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
        },
        "core.boot_screen_enabled": {
            "type": "bool",
            "default": false,
            "description": "Enable custom boot screen"
        },
        "core.fonts.persist_generated_theme": {
            "type": "bool",
            "default": false,
            "description": "Persist generated composed font theme to disk"
        },
        "core.fonts.persist_path": {
            "type": "string",
            "default": "user://tajs_core_font_theme.tres",
            "description": "Output path for persisted composed font theme"
        },
        "core.undo_enabled": {
            "type": "bool",
            "default": true,
            "label": "Enable Undo/Redo",
            "description": "Enable undo/redo functionality (Ctrl+Z / Ctrl+Y).",
            "category": "Editing"
        }
    }
    settings.register_schema("core", schema)

func _split_namespaced_id(full_id: String) -> Dictionary:
    var normalized := full_id.strip_edges()
    if normalized == "":
        return {"ok": false, "error": "id_empty"}
    var idx := normalized.find(".")
    if idx <= 0 or idx >= normalized.length() - 1:
        return {"ok": false, "error": "id_must_be_namespaced_modid.localid", "id": full_id}
    var mod_id := normalized.substr(0, idx).strip_edges()
    var local_id := normalized.substr(idx + 1).strip_edges()
    if mod_id == "" or local_id == "":
        return {"ok": false, "error": "id_must_be_namespaced_modid.localid", "id": full_id}
    return {"ok": true, "id": normalized, "mod_id": mod_id, "local_id": local_id}

func _validate_mod_id(mod_id: String) -> Dictionary:
    var normalized := mod_id.strip_edges()
    if normalized == "":
        return {"ok": false, "error": "mod_id_empty"}
    return {"ok": true, "mod_id": normalized}

func _ensure_manual_icon_source() -> void:
    if _manual_icon_source_registered:
        return
    if icon_registry == null or not icon_registry.has_method("register_source"):
        return
    var ok: bool = icon_registry.register_source("core.manual_icons", "Core Manual Icons", Callable(self, "_list_manual_icons"))
    _manual_icon_source_registered = ok

func _list_manual_icons() -> Array:
    var entries: Array = []
    for stable_id: String in _manual_icons.keys():
        var icon_path: String = str(_manual_icons[stable_id])
        var display_name := stable_id.replace(".", " ").replace("_", " ").capitalize()
        var dot_idx := stable_id.find(".")
        var mod_id := stable_id
        if dot_idx > 0:
            mod_id = stable_id.substr(0, dot_idx)
        entries.append({
            "stable_id": stable_id,
            "display_name": display_name,
            "source_id": "core.manual_icons",
            "source_label": "Core Manual Icons",
            "path": icon_path,
            "relative_path": icon_path.get_file(),
            "mod_id": mod_id,
            "source_group": "core"
        })
    return entries

func _apply_logger_settings() -> void:
    var debug_enabled: bool = settings.get_bool("core.debug", settings.get_bool("core.debug_log", false))
    logger.set_debug_enabled(debug_enabled)
    logger.set_ring_size(settings.get_int("core.log_ring_size", 200))
    var file_path: String = settings.get_string("core.log_file_path", "user://tajs_core.log")
    logger.set_file_logging(settings.get_bool("core.log_to_file", false), file_path)

func _load_script(path: String) -> Variant:
    var script: Variant = load(path)
    if script == null:
        _log_fallback("Failed to load script: %s" % path)
    return script

func _read_version_from_manifest(path: String) -> String:
    if not FileAccess.file_exists(path):
        _log_fallback("Manifest not found: %s" % path)
        return "0.0.0"

    var file: Variant = FileAccess.open(path, FileAccess.READ)
    if file == null:
        _log_fallback("Failed to open manifest: %s" % path)
        return "0.0.0"

    var content: Variant = file.get_as_text()
    var json: Variant = JSON.new()
    var error: Variant = json.parse(content)
    if error == OK:
        var data: Variant = json.data
        if data is Dictionary and data.has("version_number"):
            return data["version_number"]

    _log_fallback("Failed to parse manifest version: %s" % path)
    return "0.0.0"

func _log_fallback(message: String) -> void:
    if logger != null:
        logger.warn("core", message)
    else:
        print("TajsCore: %s" % message)

func _has_global_class(class_name_str: String) -> bool:
    for entry: Variant in ProjectSettings.get_global_class_list():
        if entry.get("class", "") == class_name_str:
            return true
    return false

func _get_autoload(autoload_name: String) -> Object:
    if Engine.has_singleton(autoload_name):
        return Engine.get_singleton(autoload_name)
    if Engine.get_main_loop() == null:
        return null
    var root: Variant = Engine.get_main_loop().root
    if root == null:
        return null
    return root.get_node_or_null(autoload_name)

func _bridge_settings_events() -> void:
    if settings == null or event_bus == null:
        return
    settings.value_changed.connect(Callable(self , "_on_settings_changed"))

func _bind_command_palette_events() -> void:
    if event_bus == null:
        return
    event_bus.on("command_palette.ready", Callable(self , "_on_command_palette_ready"), self , true)

func _on_settings_changed(key: String, value: Variant, old_value: Variant) -> void:
    if event_bus == null:
        return
    event_bus.emit("settings.changed", {"key": key, "old": old_value, "new": value})

func _on_command_palette_ready(payload: Dictionary) -> void:
    command_palette_controller = payload.get("controller", null)
    command_palette_overlay = payload.get("overlay", null)

func _register_core_migrations() -> void:
    if migrations == null or settings == null:
        return
    migrations.register_migration("core", "1.0.0", func() -> void:
        if settings.get_value("core.debug", null) == null and settings.get_value("core.debug_log", null) != null:
            settings.set_value("core.debug", settings.get_bool("core.debug_log", false))
    )

func _register_undo_keybinds() -> void:
    if keybinds == null or undo_manager == null:
        return

    # Register "Editing" category for undo/redo keybinds
    keybinds.register_keybind_category("core_editing", "Editing", "res://textures/icons/return.png")

    # Undo (Ctrl+Z)
    keybinds.register_action_scoped(
        "TajemnikTV-Core",
        "undo",
        "Undo",
        [keybinds.make_key_event(KEY_Z, true)],
        keybinds.CONTEXT_NO_TEXT,
        Callable(self , "_on_undo"),
        10,
        "core_editing"
    )

    # Redo (Ctrl+Y)
    keybinds.register_action_scoped(
        "TajemnikTV-Core",
        "redo",
        "Redo",
        [keybinds.make_key_event(KEY_Y, true)],
        keybinds.CONTEXT_NO_TEXT,
        Callable(self , "_on_redo"),
        10,
        "core_editing"
    )

    # Redo Alt (Ctrl+Shift+Z)
    keybinds.register_action_scoped(
        "TajemnikTV-Core",
        "redo_alt",
        "Redo (Alt)",
        [keybinds.make_key_event(KEY_Z, true, true)],
        keybinds.CONTEXT_NO_TEXT,
        Callable(self , "_on_redo"),
        10,
        "core_editing"
    )

    if logger != null:
        logger.info("core", "Undo/Redo keybinds registered (Ctrl+Z, Ctrl+Y, Ctrl+Shift+Z)")

func _on_undo() -> void:
    if undo_manager == null:
        return
    if settings != null and not settings.get_bool("core.undo_enabled", true):
        return
    if undo_manager.can_undo():
        undo_manager.undo()

func _on_redo() -> void:
    if undo_manager == null:
        return
    if settings != null and not settings.get_bool("core.undo_enabled", true):
        return
    if undo_manager.can_redo():
        undo_manager.redo()

func _init_optional_services(base_dir: String) -> void:
    if settings == null:
        return
    var workshop_script: Variant = _load_script(base_dir.path_join("workshop_sync.gd"))
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

    var ui_manager_script: Variant = _load_script(base_dir.path_join("ui/ui_manager.gd"))
    if ui_manager_script != null:
        ui_manager = ui_manager_script.new()
        ui_manager.name = "CoreUiManager"
        ui_manager.setup(self , workshop_sync)
        add_child(ui_manager)

func _start_workshop_sync() -> void:
    if workshop_sync != null:
        workshop_sync.start_sync()

func _apply_tooltip_styling() -> void:
    if theme_manager != null and theme_manager.has_method("apply_tooltip_styling"):
        theme_manager.apply_tooltip_styling()

func _init_boot_screen(base_dir: String) -> void:
    var boot_screen_script: Variant = _load_script(base_dir.path_join("features/boot_screen_feature.gd"))
    if boot_screen_script != null:
        boot_screen = boot_screen_script.new()
        boot_screen.setup(self )

func _install_modloader_extensions(base_dir: String) -> void:
    if not _has_global_class("ModLoaderMod"):
        return
    # NOTE: Scripts with class_name cannot use install_script_extension() because
    # ModLoader's take_over_path() creates a conflict. These are handled specially:
    # - desktop.gd (class_name Desktop) - uses runtime patching in _process()
    # - window_container.gd (class_name WindowContainer) - not yet reimplemented
    # See _process() for desktop runtime patching logic.
    var paths := [
        base_dir.path_join("extensions/data.gd"),
        base_dir.path_join("extensions/connectors.gd"),
        base_dir.path_join("extensions/windows_menu.gd"),
        base_dir.path_join("extensions/window_dragger.gd"),
        base_dir.path_join("extensions/hud.gd"),
        base_dir.path_join("extensions/main.gd"),
        base_dir.path_join("extensions/utils.gd")
    ]
    for path: Variant in paths:
        ModLoaderMod.install_script_extension(path)
