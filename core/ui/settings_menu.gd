# =============================================================================
# Taj's Core - Settings Menu
# Author: TajemnikTV
# Description: Builds the Core settings tabs
# =============================================================================
class_name TajsCoreSettingsMenu
extends RefCounted

const LOG_NAME := "TajemnikTV-Core:Settings"

var _core
var _ui
var _workshop_sync
var _logger
var _keybinds_ui

var _mod_initial_states: Dictionary = {}

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
	, "Enable verbose logging for Core services.")

	_ui.add_toggle(core_vbox, "Log to File", _core.settings.get_bool("core.log_to_file", false), func(v):
		_core.settings.set_value("core.log_to_file", v)
		if _core.logger != null:
			var path = _core.settings.get_string("core.log_file_path", "user://tajs_core.log")
			_core.logger.set_file_logging(v, path)
	, "Write logs to user://tajs_core.log")


	_ui.add_slider(core_vbox, "Log Ring Size", _core.settings.get_int("core.log_ring_size", 200), 50, 500, 10, "", func(v):
		var size = int(v)
		_core.settings.set_value("core.log_ring_size", size)
		if _core.logger != null:
			_core.logger.set_ring_size(size)
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
	var keybinds_vbox = _ui.add_tab("Keybinds", "res://textures/icons/Keyboard.png")

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

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 300)
	modmgr_vbox.add_child(scroll)

	var mods_list = VBoxContainer.new()
	mods_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(mods_list)

	_populate_mod_list(mods_list)

func _build_diagnostics_tab() -> void:
	var diag_vbox = _ui.add_tab("Diagnostics", "res://textures/icons/magnifying_glass.png")

	if _core == null or _core.diagnostics == null:
		var label = Label.new()
		label.text = "Diagnostics not available."
		diag_vbox.add_child(label)
		return

	var refresh_btn = Button.new()
	refresh_btn.text = "Refresh Snapshot"
	refresh_btn.theme_type_variation = "TabButton"
	refresh_btn.focus_mode = Control.FOCUS_NONE
	diag_vbox.add_child(refresh_btn)

	var output := TextEdit.new()
	output.editable = false
	output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	output.custom_minimum_size = Vector2(0, 300)
	diag_vbox.add_child(output)

	var refresh = func():
		var data = _core.diagnostics.collect()
		output.text = JSON.stringify(data, "\t")

	refresh_btn.pressed.connect(refresh)
	refresh.call()

func _build_mod_settings_tabs() -> void:
	"""Automatically creates a settings tab for each enabled mod (excluding Core)."""
	if not TajsCoreUtil.has_global_class("ModLoaderMod"):
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

		var mod_vbox = _ui.add_mod_tab(display_name, icon_path)
		if mod_vbox == null:
			continue

		# 1. Check for schemas registered via Core Settings API (Priority)
		var core_schema = {}
		if _core != null and _core.settings != null:
			core_schema = _core.settings.get_schemas_for_namespace(mod_id)

		if not core_schema.is_empty():
			_generate_settings_from_schema(mod_vbox, core_schema)
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
	"""Extracts display name from mod manifest, handling both Object and Dictionary types."""
	if manifest is Dictionary:
		return manifest.get("name", "Unknown Mod")
	elif manifest != null and "name" in manifest:
		return str(manifest.name)
	return "Unknown Mod"

func _get_mod_icon_path(manifest, mod_id: String) -> String:
	"""Gets mod icon path from manifest or returns empty for default puzzle icon."""
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
	"""Extracts config_schema from mod manifest."""
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

func _populate_mod_list(container: VBoxContainer) -> void:
	if not TajsCoreUtil.has_global_class("ModLoaderMod") or not TajsCoreUtil.has_global_class("ModLoaderUserProfile"):
		var label = Label.new()
		label.text = "Mod Loader APIs not available."
		container.add_child(label)
		return

	var all_mods = ModLoaderMod.get_mod_data_all()
	if all_mods == null:
		var label2 = Label.new()
		label2.text = "No mod data available."
		container.add_child(label2)
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
		var name_a = all_mods[a].manifest.name if all_mods[a].manifest is Object else all_mods[a].manifest.get("name", "")
		var name_b = all_mods[b].manifest.name if all_mods[b].manifest is Object else all_mods[b].manifest.get("name", "")
		return str(name_a).naturalnocasecmp_to(str(name_b)) < 0
	)

	for mod_id in sorted_mods:
		var mod_data = all_mods[mod_id]
		var manifest = mod_data.manifest

		var row = HBoxContainer.new()
		container.add_child(row)

		var display_name = ""
		if manifest is Dictionary:
			display_name = manifest.get("name", "")
		else:
			display_name = manifest.name
		var name_label = Label.new()
		var version_number = ""
		if manifest is Dictionary:
			version_number = manifest.get("version_number", "")
		else:
			version_number = manifest.version_number
		name_label.text = "%s v%s" % [display_name, version_number]
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)

		var id_label = Label.new()
		id_label.text = "(%s)" % mod_id
		id_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		row.add_child(id_label)

		var toggle = CheckButton.new()
		toggle.text = "Enabled" if mod_data.is_active else "Disabled"
		toggle.button_pressed = mod_data.is_active

		if mod_id == "TajemnikTV-Core":
			toggle.disabled = true
			toggle.tooltip_text = "Core cannot be disabled from its own settings."

		toggle.toggled.connect(func(active):
			toggle.text = "Enabled" if active else "Disabled"

			var success = false
			if active:
				success = ModLoaderUserProfile.enable_mod(mod_id)
			else:
				success = ModLoaderUserProfile.disable_mod(mod_id)

			if not success:
				toggle.set_pressed_no_signal(not active)
				toggle.text = "Enabled" if not active else "Disabled"
				_notify("error", "Failed to change mod state")
			else:
				_update_restart_banner_for_mods()
		)
		row.add_child(toggle)

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
	elif TajsCoreUtil.has_global_class("ModLoaderLog"):
		ModLoaderLog.info(message, LOG_NAME)
	else:
		print(LOG_NAME + ": " + message)
