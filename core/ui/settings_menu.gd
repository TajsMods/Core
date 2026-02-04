# =============================================================================
# Taj's Core - Settings Menu
# Author: TajemnikTV
# Description: Builds the Core settings tabs
# =============================================================================
class_name TajsCoreSettingsMenu
extends RefCounted

const LOG_NAME := "TajemnikTV-Core:Settings"
const DEFAULT_MOD_ICON := "res://textures/icons/puzzle.png"
const TAJS_CORE_MOD_ID := "TajemnikTV-Core"

var _core
var _ui
var _workshop_sync
var _logger
var _keybinds_ui

var _mod_initial_states: Dictionary = {}
var _mod_row_by_id: Dictionary = {}
var _selected_mod_id: String = ""
var _mod_row_selected_style: StyleBoxFlat = null

var _mod_details_panel_root: Control = null
var _mod_details_placeholder: Label = null
var _mod_details_icon: TextureRect = null
var _mod_details_name_label: Label = null
var _mod_details_version_label: Label = null
var _mod_details_meta_label: Label = null
var _mod_details_desc_label: Label = null
var _mod_details_deps_container: VBoxContainer = null
var _mod_details_links_container: VBoxContainer = null
var _mod_details_enable_toggle: CheckButton = null

func setup(core, ui, workshop_sync) -> void:
    _core = core
    _ui = ui
    _workshop_sync = workshop_sync
    _logger = core.logger if core != null else null

func build_settings_menu() -> void:
    _build_core_tab()
    _build_keybinds_tab()
    _build_mod_manager_tab()
    _build_diagnostics_tab()
    _ui.add_mod_section_separator()
    _build_mod_settings_tabs()

func _build_core_tab() -> void:
    var core_vbox = _ui.add_tab("Core", "res://textures/icons/cog.png")

    if _core == null or _core.settings == null:
        var label = Label.new()
        label.text = "Core settings not available."
        core_vbox.add_child(label)
        return

    _ui.add_toggle(core_vbox, "Debug Logging", _core.settings.get_bool("core.debug", false), func(v):
        _core.settings.set_value("core.debug", v)
        if _core.logger != null:
            _core.logger.set_debug_enabled(v)
    , "Enable verbose logging.")

    _ui.add_toggle(core_vbox, "Log to File", _core.settings.get_bool("core.log_to_file", false), func(v):
        _core.settings.set_value("core.log_to_file", v)
        if _core.logger != null:
            var path = _core.settings.get_string("core.log_file_path", "user://tajs_core.log")
            _core.logger.set_file_logging(v, path)
    , "Write logs to user://tajs_core.log")


    var log_slider = _ui.add_slider(core_vbox, "Log Ring Size", _core.settings.get_int("core.log_ring_size", 200), 50, 500, 10, "", func(v):
        var size = int(v)
        _core.settings.set_value("core.log_ring_size", size, false)
        if _core.logger != null:
            _core.logger.set_ring_size(size)
    )
    if log_slider != null:
        log_slider.drag_ended.connect(func(changed: bool):
            if not changed:
                return
            _core.settings.set_value("core.log_ring_size", int(log_slider.value), true)
        )

    _ui.add_button(core_vbox, "Export Diagnostics", func():
        if _core.diagnostics != null:
            var result = _core.diagnostics.export_json()
            _notify("check", "Diagnostics written to: %s" % result.get("path", ""))
    )

    _ui.add_button(core_vbox, "Run Self Test", func():
        if _core.diagnostics != null:
            var result = _core.diagnostics.self_test()
            _notify("check", "Self-test complete: %s" % str(result.get("ok", false)))
    )

func _build_keybinds_tab() -> void:
    var keybinds_vbox = _ui.add_tab("Keybinds", "res://mods-unpacked/TajemnikTV-Core/textures/icons/Keyboard.png")

    if _core == null or _core.keybinds == null:
        var label = Label.new()
        label.text = "Keybinds not available."
        keybinds_vbox.add_child(label)
        return

    var script = load(_core.get_script().resource_path.get_base_dir().path_join("ui/keybinds_ui.gd"))
    if script == null:
        var label2 = Label.new()
        label2.text = "Keybinds UI failed to load."
        keybinds_vbox.add_child(label2)
        return

    _keybinds_ui = script.new()
    _keybinds_ui.setup(_core.keybinds, _ui, keybinds_vbox)

func _build_mod_manager_tab() -> void:
    var modmgr_vbox = _ui.add_tab("Mod Manager", "res://textures/icons/puzzle.png")

    if _core == null or _core.settings == null:
        var label = Label.new()
        label.text = "Core settings not available."
        modmgr_vbox.add_child(label)
        return

    _ui.add_toggle(modmgr_vbox, "Workshop Sync on Startup", _core.settings.get_bool("core.workshop.sync_on_startup", true), func(v):
        _core.settings.set_value("core.workshop.sync_on_startup", v)
        if _workshop_sync:
            _workshop_sync.sync_on_startup = v
    , "Automatically check for Workshop updates on startup.")

    _ui.add_toggle(modmgr_vbox, "High Priority Downloads", _core.settings.get_bool("core.workshop.high_priority", true), func(v):
        _core.settings.set_value("core.workshop.high_priority", v)
        if _workshop_sync:
            _workshop_sync.high_priority_downloads = v
    , "Use high priority for Workshop downloads.")

    _ui.add_toggle(modmgr_vbox, "Force Download All Items", _core.settings.get_bool("core.workshop.force_download_all", true), func(v):
        _core.settings.set_value("core.workshop.force_download_all", v)
        if _workshop_sync:
            _workshop_sync.force_download_all = v
    , "Always request downloads for all subscribed items.")

    _ui.add_button(modmgr_vbox, "Force Workshop Sync Now", func():
        if _workshop_sync:
            _workshop_sync.start_sync()
        else:
            _notify("cross", "Workshop Sync not available")
    )

    var steam_status = Label.new()
    steam_status.add_theme_font_size_override("font_size", 20)
    steam_status.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8, 0.8))
    if _workshop_sync and _workshop_sync.is_steam_available():
        steam_status.text = "Steam Workshop available"
        steam_status.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5, 0.9))
    else:
        steam_status.text = "Steam not available"
        steam_status.add_theme_color_override("font_color", Color(0.8, 0.5, 0.5, 0.9))
    modmgr_vbox.add_child(steam_status)

    modmgr_vbox.add_child(HSeparator.new())

    var mods_label = Label.new()
    mods_label.text = "Installed Mods"
    mods_label.add_theme_font_size_override("font_size", 24)
    modmgr_vbox.add_child(mods_label)

    var layout := HFlowContainer.new()
    layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    layout.add_theme_constant_override("h_separation", 18)
    layout.add_theme_constant_override("v_separation", 18)
    modmgr_vbox.add_child(layout)

    var list_panel := PanelContainer.new()
    list_panel.theme_type_variation = "MenuPanel"
    list_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    list_panel.custom_minimum_size = Vector2(420, 320)
    layout.add_child(list_panel)

    var list_margin := MarginContainer.new()
    list_margin.add_theme_constant_override("margin_left", 12)
    list_margin.add_theme_constant_override("margin_right", 12)
    list_margin.add_theme_constant_override("margin_top", 10)
    list_margin.add_theme_constant_override("margin_bottom", 10)
    list_panel.add_child(list_margin)

    var list_vbox := VBoxContainer.new()
    list_vbox.add_theme_constant_override("separation", 8)
    list_margin.add_child(list_vbox)

    var scroll = ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.custom_minimum_size = Vector2(0, 300)
    list_vbox.add_child(scroll)

    var mods_list = VBoxContainer.new()
    mods_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    mods_list.add_theme_constant_override("separation", 6)
    scroll.add_child(mods_list)

    var details_panel := PanelContainer.new()
    details_panel.theme_type_variation = "MenuPanel"
    details_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    details_panel.custom_minimum_size = Vector2(360, 320)
    layout.add_child(details_panel)

    var details_margin := MarginContainer.new()
    details_margin.add_theme_constant_override("margin_left", 14)
    details_margin.add_theme_constant_override("margin_right", 14)
    details_margin.add_theme_constant_override("margin_top", 12)
    details_margin.add_theme_constant_override("margin_bottom", 12)
    details_panel.add_child(details_margin)

    var details_stack := VBoxContainer.new()
    details_stack.add_theme_constant_override("separation", 12)
    details_margin.add_child(details_stack)

    var placeholder := Label.new()
    placeholder.text = "Select a mod to see details."
    placeholder.autowrap_mode = TextServer.AUTOWRAP_WORD
    placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    placeholder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    placeholder.size_flags_vertical = Control.SIZE_EXPAND_FILL
    placeholder.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8, 0.7))
    details_stack.add_child(placeholder)
    _mod_details_placeholder = placeholder

    var details_content := VBoxContainer.new()
    details_content.add_theme_constant_override("separation", 12)
    details_content.visible = false
    details_stack.add_child(details_content)
    _mod_details_panel_root = details_content

    var header := HBoxContainer.new()
    header.add_theme_constant_override("separation", 12)
    details_content.add_child(header)

    var icon := TextureRect.new()
    icon.custom_minimum_size = Vector2(48, 48)
    icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    header.add_child(icon)
    _mod_details_icon = icon

    var title_vbox := VBoxContainer.new()
    title_vbox.add_theme_constant_override("separation", 2)
    header.add_child(title_vbox)

    var name_label := Label.new()
    name_label.text = ""
    name_label.add_theme_font_size_override("font_size", 28)
    title_vbox.add_child(name_label)
    _mod_details_name_label = name_label

    var version_label := Label.new()
    version_label.text = ""
    version_label.add_theme_font_size_override("font_size", 18)
    version_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9, 0.85))
    title_vbox.add_child(version_label)
    _mod_details_version_label = version_label

    # Reserved for future badges (conflicts/warnings).

    var meta_label := Label.new()
    meta_label.text = ""
    meta_label.add_theme_font_size_override("font_size", 16)
    meta_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8, 0.8))
    details_content.add_child(meta_label)
    _mod_details_meta_label = meta_label

    # Enable/Disable toggle - prominently placed in details panel
    var enable_toggle := CheckButton.new()
    enable_toggle.text = "Enabled"
    enable_toggle.focus_mode = Control.FOCUS_NONE
    details_content.add_child(enable_toggle)
    _mod_details_enable_toggle = enable_toggle

    var about_label := Label.new()
    about_label.text = "About"
    about_label.add_theme_font_size_override("font_size", 18)
    about_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9, 0.9))
    details_content.add_child(about_label)

    var desc_label := Label.new()
    desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
    desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    details_content.add_child(desc_label)
    _mod_details_desc_label = desc_label

    var deps_label := Label.new()
    deps_label.text = "Dependencies"
    deps_label.add_theme_font_size_override("font_size", 18)
    deps_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9, 0.9))
    details_content.add_child(deps_label)

    var deps_container := VBoxContainer.new()
    deps_container.add_theme_constant_override("separation", 4)
    details_content.add_child(deps_container)
    _mod_details_deps_container = deps_container

    var links_label := Label.new()
    links_label.text = "Links"
    links_label.add_theme_font_size_override("font_size", 18)
    links_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9, 0.9))
    details_content.add_child(links_label)

    var links_container := VBoxContainer.new()
    links_container.add_theme_constant_override("separation", 6)
    details_content.add_child(links_container)
    _mod_details_links_container = links_container

    _populate_mod_list(mods_list)

func _build_diagnostics_tab() -> void:
    var diag_vbox = _ui.add_tab("Diagnostics", "res://textures/icons/magnifying_glass.png")

    if _core == null or _core.diagnostics == null:
        var label = Label.new()
        label.text = "Diagnostics not available."
        diag_vbox.add_child(label)
        return

    var output := TextEdit.new()
    output.editable = false
    output.size_flags_vertical = Control.SIZE_EXPAND_FILL
    output.custom_minimum_size = Vector2(0, 300)

    var refresh = func() -> String:
        var dump: String = _core.diagnostics.generate_dump()
        output.text = dump
        return dump

    _ui.add_button(diag_vbox, "Refresh Diagnostics Dump", func():
        refresh.call()
    )

    _ui.add_button(diag_vbox, "Copy Diagnostics Dump", func():
        var dump = refresh.call()
        var result = _core.diagnostics.copy_dump_to_clipboard({"dump": dump})
        if result.get("ok", false):
            _notify("check", "Diagnostics dump copied to clipboard.")
        else:
            _notify("cross", "Failed to copy diagnostics dump.")
    )

    _ui.add_button(diag_vbox, "Save Diagnostics Dump", func():
        var dump = refresh.call()
        var result = _core.diagnostics.save_dump_to_file("", {"dump": dump})
        if result.get("ok", false):
            _notify("check", "Diagnostics dump saved to: %s" % result.get("path", ""))
        else:
            _notify("cross", "Failed to save diagnostics dump.")
    )

    diag_vbox.add_child(output)
    refresh.call()

func _build_mod_settings_tabs() -> void:
    # Automatically creates a settings tab for each enabled mod (excluding Core)
    if not _has_global_class("ModLoaderMod"):
        return

    var all_mods = ModLoaderMod.get_mod_data_all()
    if all_mods == null:
        return

    # Sort mods alphabetically by display name
    var sorted_mods = all_mods.keys()
    sorted_mods.sort_custom(func(a, b):
        var name_a = _get_mod_display_name(all_mods[a].manifest)
        var name_b = _get_mod_display_name(all_mods[b].manifest)
        return str(name_a).naturalnocasecmp_to(str(name_b)) < 0
    )

    for mod_id in sorted_mods:
        # Skip Core - it has its own dedicated tabs
        if mod_id == "TajemnikTV-Core":
            continue

        var mod_data = all_mods[mod_id]
        # Only create tabs for active mods
        if not mod_data.is_active:
            continue

        var manifest = mod_data.manifest
        var display_name = _get_mod_display_name(manifest)
        var icon_path = _get_mod_icon_path(manifest, mod_id)

        if _core != null and _core.ui_manager != null and _core.ui_manager.has_mod_settings_tab(mod_id):
            _core.ui_manager.register_mod_settings_tab(mod_id, display_name, icon_path)
            continue

        var core_schema := {}
        if _core != null and _core.settings != null:
            core_schema = _core.settings.get_schemas_for_namespace(mod_id)
            if core_schema.is_empty() and _core.settings.has_method("get_schemas_for_module"):
                core_schema = _core.settings.get_schemas_for_module(mod_id)

        var tab_id: String = mod_id
        if not core_schema.is_empty():
            tab_id = _infer_schema_namespace(core_schema, mod_id)

        var tab_kind := "schema" if not core_schema.is_empty() else "manual"
        var mod_vbox = _ui.add_mod_tab_ex(display_name, icon_path, tab_id, tab_kind)
        if mod_vbox == null:
            continue

        # 1. Check for schemas registered via Core Settings API (Priority)
        if not core_schema.is_empty():
            _ui.build_schema_tab(mod_vbox, _core.settings, tab_id, core_schema)
            continue

        # 2. Check for config_schema from manifest (Fallback)
        var config_schema = _get_mod_config_schema(manifest)
        if config_schema != null and not config_schema.is_empty():
            # TODO: Auto-generate settings UI from manifest config_schema
            var placeholder_label = Label.new()
            placeholder_label.text = "Settings available (manifest schema found)."
            placeholder_label.add_theme_font_size_override("font_size", 24)
            placeholder_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6, 0.8))
            mod_vbox.add_child(placeholder_label)
            continue

        # 3. No settings found
        var no_settings_label = Label.new()
        no_settings_label.text = "No configurable settings."
        no_settings_label.add_theme_font_size_override("font_size", 24)
        no_settings_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8, 0.7))
        mod_vbox.add_child(no_settings_label)

func _generate_settings_from_schema(container: VBoxContainer, schema: Dictionary) -> void:
    var keys = schema.keys()
    keys.sort()

    for key in keys:
        var entry = schema[key]
        if not (entry is Dictionary):
            continue

        var type = entry.get("type", "string")
        var description = entry.get("description", key)
        var default_val = entry.get("default", null)
        var current_val = _core.settings.get_value(key, default_val)

        # If description contains dots (like a key), try to make it prettier?
        # For now use description as label.
        var label_text = description

        match type:
            "bool":
                _ui.add_toggle(container, label_text, bool(current_val), func(v):
                    _core.settings.set_value(key, v)
                )
            "int":
                # TODO: Sliders if min/max defined in schema
                _ui.add_text_input(container, label_text, str(current_val), func(text):
                    if text.is_valid_int():
                        _core.settings.set_value(key, int(text))
                )
            "float":
                _ui.add_text_input(container, label_text, str(current_val), func(text):
                    if text.is_valid_float():
                        _core.settings.set_value(key, float(text))
                )
            "string":
                _ui.add_text_input(container, label_text, str(current_val), func(text):
                    _core.settings.set_value(key, text)
                )
            _:
                var unknown_label = Label.new()
                unknown_label.text = "%s: Unknown type '%s'" % [label_text, type]
                container.add_child(unknown_label)

func _get_mod_display_name(manifest) -> String:
    # Extracts display name from mod manifest, handling both Object and Dictionary types
    var display_name := ""
    if manifest is Dictionary:
        display_name = str(manifest.get("display_name", manifest.get("name", "")))
    elif manifest != null:
        if "display_name" in manifest:
            display_name = str(manifest.display_name)
        elif "name" in manifest:
            display_name = str(manifest.name)
    if display_name.strip_edges() != "":
        return display_name
    return "Unknown Mod"

func _is_valid_mod(mod_id: String, manifest) -> bool:
    # Checks if a mod entry is valid (not a stray folder like .idea)
    # Skip hidden directories (start with .)
    if mod_id.begins_with("."):
        return false

    # Skip entries with no manifest at all
    if manifest == null:
        return false

    # Check if manifest has meaningful data
    var display_name := _get_mod_display_name(manifest)
    var version := _get_mod_version(manifest)

    # If both name is "Unknown Mod" and version is empty or "0.0.0", likely not a real mod
    if display_name == "Unknown Mod" and (version == "" or version == "0.0.0"):
        return false

    return true

func _get_mod_icon_path(manifest, mod_id: String) -> String:
    # Gets mod icon path from manifest or returns empty for default puzzle icon
    var extra = null
    if manifest is Dictionary:
        extra = manifest.get("extra", {})
    elif manifest != null and "extra" in manifest:
        extra = manifest.extra

    if extra is Dictionary:
        var godot_extra = extra.get("godot", {})
        if godot_extra is Dictionary and godot_extra.has("image"):
            var image_path = godot_extra.get("image", "")
            if image_path != null and image_path != "" and ResourceLoader.exists(image_path):
                return image_path

    # Try to find an icon in the mod's folder
    var mod_dir = "res://mods-unpacked/" + mod_id
    var potential_icons = ["/icon.png", "/icon.svg", "/icon.tres"]
    for icon in potential_icons:
        var full_path = mod_dir + icon
        if ResourceLoader.exists(full_path):
            return full_path

    return "" # Will fall back to puzzle icon

func _get_mod_config_schema(manifest) -> Dictionary:
    # Extracts config_schema from mod manifest
    var extra = null
    if manifest is Dictionary:
        extra = manifest.get("extra", {})
    elif manifest != null and "extra" in manifest:
        extra = manifest.extra

    if extra is Dictionary:
        var godot_extra = extra.get("godot", {})
        if godot_extra is Dictionary:
            var schema = godot_extra.get("config_schema", {})
            if schema is Dictionary:
                return schema
    return {}

func _infer_schema_namespace(schema: Dictionary, fallback: String) -> String:
    if schema.is_empty():
        return fallback
    var keys: Array = schema.keys()
    if keys.size() == 1:
        var single_key := str(keys[0])
        var last_dot := single_key.rfind(".")
        return single_key.substr(0, last_dot) if last_dot > 0 else fallback

    var common_parts: Array = str(keys[0]).split(".")
    for idx in range(1, keys.size()):
        var parts: Array = str(keys[idx]).split(".")
        var max_parts: int = min(common_parts.size(), parts.size())
        var new_common: Array = []
        for i in range(max_parts):
            if common_parts[i] == parts[i]:
                new_common.append(common_parts[i])
            else:
                break
        common_parts = new_common
        if common_parts.is_empty():
            return fallback
    if common_parts.is_empty():
        return fallback
    return ".".join(common_parts)

func _populate_mod_list(container: VBoxContainer) -> void:
    for child in container.get_children():
        child.queue_free()

    _mod_row_by_id.clear()

    if not _has_global_class("ModLoaderMod") or not _has_global_class("ModLoaderUserProfile"):
        var label = Label.new()
        label.text = "Mod Loader APIs not available."
        container.add_child(label)
        _show_mod_details_placeholder()
        return

    var all_mods = ModLoaderMod.get_mod_data_all()
    if all_mods == null:
        var label2 = Label.new()
        label2.text = "No mod data available."
        container.add_child(label2)
        _show_mod_details_placeholder()
        return

    _mod_initial_states.clear()
    for mod_id in all_mods:
        _mod_initial_states[mod_id] = all_mods[mod_id].is_active

    var sorted_mods = all_mods.keys()
    sorted_mods.sort_custom(func(a, b):
        if a == "TajemnikTV-Core":
            return true
        if b == "TajemnikTV-Core":
            return false
        var name_a = _get_mod_display_name(all_mods[a].manifest)
        var name_b = _get_mod_display_name(all_mods[b].manifest)
        return str(name_a).naturalnocasecmp_to(str(name_b)) < 0
    )

    var first_mod_id := ""
    for mod_id in sorted_mods:
        var mod_data = all_mods[mod_id]
        var manifest = mod_data.manifest

        # Filter out invalid entries (folders without proper manifests)
        if not _is_valid_mod(mod_id, manifest):
            continue

        if first_mod_id == "":
            first_mod_id = mod_id

        var row_panel := PanelContainer.new()
        row_panel.mouse_filter = Control.MOUSE_FILTER_STOP
        row_panel.focus_mode = Control.FOCUS_NONE
        row_panel.custom_minimum_size = Vector2(0, 42)
        row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        container.add_child(row_panel)

        var row_margin := MarginContainer.new()
        row_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
        row_margin.add_theme_constant_override("margin_left", 10)
        row_margin.add_theme_constant_override("margin_right", 10)
        row_margin.add_theme_constant_override("margin_top", 6)
        row_margin.add_theme_constant_override("margin_bottom", 6)
        row_panel.add_child(row_margin)

        var row = HBoxContainer.new()
        row.mouse_filter = Control.MOUSE_FILTER_IGNORE
        row.add_theme_constant_override("separation", 8)
        row_margin.add_child(row)

        _mod_row_by_id[mod_id] = row_panel
        var mod_id_for_row: String = mod_id
        row_panel.gui_input.connect(func(event: InputEvent):
            if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
                _select_mod(mod_id_for_row)
        )

        # Status indicator (colored dot)
        var status_dot := Label.new()
        status_dot.text = "●"
        status_dot.add_theme_font_size_override("font_size", 14)
        if mod_data.is_active:
            status_dot.add_theme_color_override("font_color", Color(0.4, 0.85, 0.5))
            status_dot.tooltip_text = "Enabled"
        else:
            status_dot.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
            status_dot.tooltip_text = "Disabled"
        row.add_child(status_dot)

        var display_name = _get_mod_display_name(manifest)
        var name_label = Label.new()
        var version_number = _get_mod_version(manifest)
        name_label.text = "%s v%s" % [display_name, version_number] if version_number != "" else display_name
        name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        name_label.clip_text = true
        row.add_child(name_label)

    var desired_selection := ""
    if _selected_mod_id != "" and all_mods.has(_selected_mod_id):
        desired_selection = _selected_mod_id
    elif first_mod_id != "":
        desired_selection = first_mod_id

    if desired_selection != "":
        _select_mod(desired_selection)
    else:
        _selected_mod_id = ""
        _show_mod_details_placeholder()

func _update_restart_banner_for_mods() -> void:
    var mod_restart_required := false
    var current_profile = ModLoaderUserProfile.get_current()
    if current_profile == null:
        return
    var current_enabled_mods = current_profile.mod_list

    for mod_id in _mod_initial_states:
        var originally_enabled = _mod_initial_states[mod_id]
        var currently_enabled = current_enabled_mods.has(mod_id)
        if currently_enabled != originally_enabled:
            mod_restart_required = true
            break

    if mod_restart_required:
        _ui.show_restart_banner()
    else:
        _ui.hide_restart_banner()

func _update_status_dot_for_mod(mod_id: String, is_active: bool) -> void:
    # Updates the status dot color for a mod in the list
    if not _mod_row_by_id.has(mod_id):
        return
    var row_panel = _mod_row_by_id[mod_id]
    if row_panel == null or not is_instance_valid(row_panel):
        return
    # Find the status dot (first label in the row)
    var row_margin = row_panel.get_child(0) if row_panel.get_child_count() > 0 else null
    if row_margin == null:
        return
    var row = row_margin.get_child(0) if row_margin.get_child_count() > 0 else null
    if row == null:
        return
    for child in row.get_children():
        if child is Label and child.text == "●":
            if is_active:
                child.add_theme_color_override("font_color", Color(0.4, 0.85, 0.5))
                child.tooltip_text = "Enabled"
            else:
                child.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
                child.tooltip_text = "Disabled"
            break

func _notify(icon: String, message: String) -> void:
    var signals = _get_root_node("Signals")
    if signals != null and signals.has_signal("notify"):
        signals.emit_signal("notify", icon, message)
        return
    _log_info(message)

func _get_root_node(name: String) -> Node:
    if Engine.get_main_loop():
        var root = Engine.get_main_loop().root
        if root and root.has_node(name):
            return root.get_node(name)
    return null

func _log_info(message: String) -> void:
    if _logger != null and _logger.has_method("info"):
        _logger.info("settings", message)
    elif _has_global_class("ModLoaderLog"):
        ModLoaderLog.info(message, LOG_NAME)
    else:
        print(LOG_NAME + ": " + message)


func _has_global_class(class_name_str: String) -> bool:
    for entry in ProjectSettings.get_global_class_list():
        if entry.get("class", "") == class_name_str:
            return true
    return false

func _select_mod(mod_id: String) -> void:
    _selected_mod_id = mod_id
    _update_mod_row_highlight()

    if not _has_global_class("ModLoaderMod"):
        _show_mod_details_placeholder()
        return

    var all_mods = ModLoaderMod.get_mod_data_all()
    if all_mods == null or not all_mods.has(mod_id):
        _show_mod_details_placeholder()
        return

    var mod_data = all_mods[mod_id]
    _render_mod_details(mod_data.manifest, mod_id)

func _render_mod_details(manifest, mod_id: String) -> void:
    if _mod_details_panel_root == null or _mod_details_placeholder == null:
        return

    var display_name = _get_mod_display_name(manifest)
    var version = _get_mod_version(manifest)
    var author = str(_get_manifest_value(manifest, "author", "Unknown"))
    if author.strip_edges() == "":
        author = "Unknown"

    var resolved_mod_id := mod_id
    if resolved_mod_id.strip_edges() == "":
        resolved_mod_id = str(_get_manifest_value(manifest, "mod_id", ""))
    if resolved_mod_id.strip_edges() == "":
        resolved_mod_id = "Unknown ID"

    if _mod_details_name_label != null:
        _mod_details_name_label.text = display_name
    if _mod_details_version_label != null:
        if version != "":
            _mod_details_version_label.text = "v" + version
            _mod_details_version_label.visible = true
        else:
            _mod_details_version_label.text = ""
            _mod_details_version_label.visible = false

    if _mod_details_meta_label != null:
        _mod_details_meta_label.text = "%s - by %s" % [resolved_mod_id, author]

    # Configure enable/disable toggle
    if _mod_details_enable_toggle != null and _has_global_class("ModLoaderMod") and _has_global_class("ModLoaderUserProfile"):
        var all_mods = ModLoaderMod.get_mod_data_all()
        var is_active := false
        if all_mods != null and all_mods.has(mod_id):
            is_active = all_mods[mod_id].is_active

        # Disconnect any previous signals
        for conn in _mod_details_enable_toggle.toggled.get_connections():
            _mod_details_enable_toggle.toggled.disconnect(conn.callable)

        _mod_details_enable_toggle.set_pressed_no_signal(is_active)
        _mod_details_enable_toggle.text = "Enabled" if is_active else "Disabled"

        # Core cannot be disabled from its own menu
        if mod_id == TAJS_CORE_MOD_ID:
            _mod_details_enable_toggle.disabled = true
            _mod_details_enable_toggle.tooltip_text = "Core cannot be disabled from its own settings."
        else:
            _mod_details_enable_toggle.disabled = false
            _mod_details_enable_toggle.tooltip_text = ""

        var toggle_mod_id: String = mod_id
        _mod_details_enable_toggle.toggled.connect(func(active: bool):
            _mod_details_enable_toggle.text = "Enabled" if active else "Disabled"

            var success := false
            if active:
                success = ModLoaderUserProfile.enable_mod(toggle_mod_id)
            else:
                success = ModLoaderUserProfile.disable_mod(toggle_mod_id)

            if not success:
                _mod_details_enable_toggle.set_pressed_no_signal(not active)
                _mod_details_enable_toggle.text = "Enabled" if not active else "Disabled"
                _notify("error", "Failed to change mod state")
            else:
                _update_status_dot_for_mod(toggle_mod_id, active)
                _update_restart_banner_for_mods()
        )

    if _mod_details_desc_label != null:
        var description = str(_get_manifest_value(manifest, "description", ""))
        if description.strip_edges() == "":
            description = "No description provided."
        _mod_details_desc_label.text = description

    if _mod_details_icon != null:
        var icon_path = _get_mod_icon_path(manifest, resolved_mod_id)
        var icon_texture: Texture2D = null
        if icon_path != "" and ResourceLoader.exists(icon_path):
            icon_texture = load(icon_path)
        if icon_texture == null and ResourceLoader.exists(DEFAULT_MOD_ICON):
            icon_texture = load(DEFAULT_MOD_ICON)
        _mod_details_icon.texture = icon_texture

    if _mod_details_deps_container != null:
        for child in _mod_details_deps_container.get_children():
            child.queue_free()
        var deps_payload = _collect_manifest_dependencies(manifest)
        var deps: Array = deps_payload.get("deps", [])
        var core_found: bool = bool(deps_payload.get("core_found", false))
        if not core_found:
            var extra = _get_manifest_extra(manifest)
            var core_min = _get_extra_core_requirement(extra)
            if core_min != "":
                deps.append("Taj's Core >= %s" % core_min)

        if deps.is_empty():
            var none_label := Label.new()
            none_label.text = "No dependencies"
            none_label.add_theme_color_override("font_color", Color(0.65, 0.7, 0.8, 0.8))
            _mod_details_deps_container.add_child(none_label)
        else:
            for dep in deps:
                var dep_label := Label.new()
                dep_label.text = "- " + dep
                _mod_details_deps_container.add_child(dep_label)

    if _mod_details_links_container != null:
        for child in _mod_details_links_container.get_children():
            child.queue_free()
        var links = _build_mod_links(manifest)
        if links.is_empty():
            var none_links := Label.new()
            none_links.text = "No links"
            none_links.add_theme_color_override("font_color", Color(0.65, 0.7, 0.8, 0.8))
            _mod_details_links_container.add_child(none_links)
        else:
            for entry in links:
                var btn := Button.new()
                btn.text = str(entry.get("label", "Open"))
                btn.focus_mode = Control.FOCUS_NONE
                btn.theme_type_variation = "TabButton"
                btn.custom_minimum_size = Vector2(160, 34)
                var url := str(entry.get("url", ""))
                btn.pressed.connect(func():
                    if url != "":
                        OS.shell_open(url)
                )
                _mod_details_links_container.add_child(btn)

    _mod_details_placeholder.visible = false
    _mod_details_panel_root.visible = true

func _show_mod_details_placeholder() -> void:
    if _mod_details_placeholder != null:
        _mod_details_placeholder.visible = true
    if _mod_details_panel_root != null:
        _mod_details_panel_root.visible = false

func _update_mod_row_highlight() -> void:
    for mod_id in _mod_row_by_id.keys():
        var row_panel = _mod_row_by_id[mod_id]
        if row_panel == null or not is_instance_valid(row_panel):
            continue
        if mod_id == _selected_mod_id:
            row_panel.add_theme_stylebox_override("panel", _get_mod_row_selected_style())
        else:
            row_panel.remove_theme_stylebox_override("panel")

func _get_mod_row_selected_style() -> StyleBoxFlat:
    if _mod_row_selected_style == null:
        var style := StyleBoxFlat.new()
        style.bg_color = Color(0.18, 0.26, 0.38, 0.85)
        style.border_width_left = 1
        style.border_width_top = 1
        style.border_width_right = 1
        style.border_width_bottom = 1
        style.border_color = Color(0.35, 0.5, 0.7, 0.9)
        style.set_corner_radius_all(6)
        _mod_row_selected_style = style
    return _mod_row_selected_style

func _get_mod_version(manifest) -> String:
    var version = str(_get_manifest_value(manifest, "version", ""))
    if version.strip_edges() == "":
        version = str(_get_manifest_value(manifest, "version_number", ""))
    return version

func _get_manifest_value(manifest, key: String, fallback: Variant) -> Variant:
    if manifest is Dictionary:
        return manifest.get(key, fallback)
    if manifest != null:
        if manifest.has_method("get"):
            var value = manifest.get(key)
            return value if value != null else fallback
        if key in manifest:
            return manifest[key]
    return fallback

func _get_manifest_extra(manifest) -> Dictionary:
    var extra = null
    if manifest is Dictionary:
        extra = manifest.get("extra", {})
    elif manifest != null and "extra" in manifest:
        extra = manifest.extra

    return extra if extra is Dictionary else {}

func _collect_manifest_dependencies(manifest) -> Dictionary:
    var deps: Array[String] = []
    var core_found := false

    var raw = _get_manifest_value(manifest, "dependencies", null)
    if raw == null:
        raw = _get_manifest_value(manifest, "requires", null)
    if raw == null:
        raw = _get_manifest_value(manifest, "deps", null)

    if raw is Array or raw is PackedStringArray:
        for entry in raw:
            if entry is Dictionary:
                var dep_id := str(entry.get("mod_id", entry.get("id", entry.get("name", ""))))
                if dep_id == "":
                    deps.append(str(entry))
                    continue
                if dep_id == TAJS_CORE_MOD_ID:
                    core_found = true
                deps.append(_format_dependency_entry(dep_id, entry))
            elif entry is String:
                var dep_id_str := str(entry)
                if dep_id_str == TAJS_CORE_MOD_ID:
                    core_found = true
                deps.append(_format_dependency_entry(dep_id_str, null))
            else:
                deps.append(str(entry))
    elif raw is Dictionary:
        for dep_key in raw.keys():
            var dep_id := str(dep_key)
            if dep_id == TAJS_CORE_MOD_ID:
                core_found = true
            deps.append(_format_dependency_entry(dep_id, raw[dep_key]))

    return {"deps": deps, "core_found": core_found}

func _format_dependency_entry(dep_id: String, dep_value: Variant) -> String:
    if dep_id.strip_edges() == "":
        return ""
    var display_id := "Taj's Core" if dep_id == TAJS_CORE_MOD_ID else dep_id
    var version := ""
    var constraint := ""
    if dep_value is Dictionary:
        version = str(dep_value.get("version", dep_value.get("min_version", dep_value.get("min", ""))))
        constraint = str(dep_value.get("constraint", dep_value.get("version_constraint", "")))
    elif dep_value is String or dep_value is int or dep_value is float:
        version = str(dep_value)

    if version.strip_edges() != "":
        return "%s (>= %s)" % [display_id, version]
    if constraint.strip_edges() != "":
        return "%s (%s)" % [display_id, constraint]
    return display_id

func _get_extra_core_requirement(extra: Dictionary) -> String:
    var candidates := [
        extra.get("requires_core", ""),
        extra.get("core_min_version", ""),
        extra.get("tajs_core_min_version", "")
    ]
    for value in candidates:
        if value is String and value.strip_edges() != "":
            return value
        if value is int or value is float:
            return str(value)
    return ""

func _build_mod_links(manifest) -> Array[Dictionary]:
    var extra = _get_manifest_extra(manifest)
    var links: Array[Dictionary] = []

    var godot_extra := {}
    if extra.has("godot") and extra.get("godot") is Dictionary:
        godot_extra = extra.get("godot")

    var workshop_url = _first_non_empty_string([
        _get_manifest_value(manifest, "workshop_url", ""),
        extra.get("workshop_url", ""),
        extra.get("steam_workshop_url", "")
    ])
    var workshop_id = _first_non_empty_string([
        str(_get_manifest_value(manifest, "workshop_id", "")),
        str(_get_manifest_value(manifest, "steam_workshop_id", "")),
        str(extra.get("workshop_id", "")),
        str(extra.get("steam_workshop_id", "")),
        str(godot_extra.get("steam_workshop_id", "")),
        str(godot_extra.get("workshop_id", ""))
    ])
    if workshop_url == "" and workshop_id != "":
        workshop_url = "https://steamcommunity.com/sharedfiles/filedetails/?id=%s" % workshop_id
    workshop_url = _normalize_link_url(workshop_url)
    if workshop_url != "":
        links.append({"label": "Open Workshop", "url": workshop_url})

    var github_url = _first_non_empty_string([
        _get_manifest_value(manifest, "github", ""),
        _get_manifest_value(manifest, "github_url", ""),
        _get_manifest_value(manifest, "repo_url", ""),
        _get_manifest_value(manifest, "website_url", ""),
        extra.get("github", ""),
        extra.get("github_url", ""),
        extra.get("repo_url", ""),
        extra.get("website_url", ""),
        godot_extra.get("github", ""),
        godot_extra.get("github_url", ""),
        godot_extra.get("repo_url", "")
    ])
    github_url = _normalize_link_url(github_url)
    if github_url != "" and not _is_github_url(github_url):
        github_url = ""
    if github_url != "":
        links.append({"label": "Open GitHub", "url": github_url})

    var docs_url = _first_non_empty_string([
        _get_manifest_value(manifest, "docs", ""),
        _get_manifest_value(manifest, "docs_url", ""),
        _get_manifest_value(manifest, "documentation", ""),
        _get_manifest_value(manifest, "website_url", ""),
        extra.get("docs", ""),
        extra.get("docs_url", ""),
        extra.get("documentation", ""),
        extra.get("website_url", ""),
        godot_extra.get("docs", ""),
        godot_extra.get("docs_url", ""),
        godot_extra.get("documentation", "")
    ])
    docs_url = _normalize_link_url(docs_url)
    if docs_url != "" and not _is_docs_url(docs_url):
        docs_url = ""
    if docs_url != "":
        links.append({"label": "Open Docs", "url": docs_url})

    if workshop_url == "" and github_url == "" and docs_url == "":
        var website_url = _normalize_link_url(str(_get_manifest_value(manifest, "website_url", "")))
        if website_url == "":
            website_url = _normalize_link_url(str(extra.get("website_url", "")))
        if website_url == "":
            website_url = _normalize_link_url(str(godot_extra.get("website_url", "")))
        if website_url != "":
            if _is_github_url(website_url):
                links.append({"label": "Open GitHub", "url": website_url})
            elif _is_workshop_url(website_url):
                links.append({"label": "Open Workshop", "url": website_url})
            elif _is_docs_url(website_url):
                links.append({"label": "Open Docs", "url": website_url})
            else:
                links.append({"label": "Open Website", "url": website_url})

    return links

func _first_non_empty_string(values: Array) -> String:
    for value in values:
        if value is String and value.strip_edges() != "":
            return value
    return ""

func _normalize_link_url(raw: String) -> String:
    var trimmed := raw.strip_edges()
    if trimmed == "":
        return ""
    if trimmed.find("://") == -1:
        if trimmed.begins_with("steamcommunity.com") or trimmed.begins_with("www.steamcommunity.com"):
            return "https://" + trimmed
        if trimmed.begins_with("github.com") or trimmed.begins_with("www.github.com"):
            return "https://" + trimmed
        if trimmed.count("/") == 1 and trimmed.find(" ") == -1:
            return "https://github.com/" + trimmed
        return ""
    if trimmed.begins_with("http://") or trimmed.begins_with("https://"):
        return trimmed
    return ""

func _is_github_url(url: String) -> bool:
    return url.find("github.com") != -1

func _is_workshop_url(url: String) -> bool:
    return url.find("steamcommunity.com/sharedfiles") != -1

func _is_docs_url(url: String) -> bool:
    return url.find("docs") != -1 or url.find("readthedocs") != -1
