# =============================================================================
# Taj's Core - Settings UI
# Author: TajemnikTV
# Description: Core settings interface
# =============================================================================
class_name TajsCoreSettingsUI
extends RefCounted

const LOG_NAME := "TajemnikTV-Core:UI"
# Panel sizing - matches game's native Menus container
const MENUS_OFFSET_LEFT := -1180.0 # Same as HUD/Main/MainContainer/Overlay/Menus
const MENUS_OFFSET_RIGHT := -100.0 # 100px margin from right edge
const PANEL_INNER_MARGIN := 20.0 # Inner margin for panel content
const PANEL_MIN_WIDTH := 560.0

signal action_triggered(key: String)

var _hud_node: Node
var _core_version: String
var _settings_ref = null

# UI References
var root_control: Control
var settings_panel: PanelContainer
var tab_container: TabContainer
var tab_buttons_container: Container
var _tab_buttons: Array[Button] = []
var settings_button: Button

# Restart Banner State
var _restart_pending := false
var _restart_banner: Control = null
var _restart_indicator: Control = null
var _main_vbox: VBoxContainer = null

# Search Bar State
var _search_field: LineEdit = null
var _searchable_rows: Array = []
var _filter_only_changed := false
var _filter_show_advanced := false
var _filter_only_changed_btn: CheckButton = null
var _filter_show_advanced_btn: CheckButton = null
var _export_button: Button = null
var _import_button: Button = null
var _reset_tab_button: Button = null

# Sidebar Collapse State
const SIDEBAR_WIDTH_COLLAPSED := 46.0
const SIDEBAR_WIDTH_EXPANDED := 180.0
var _sidebar: Control = null
var _sidebar_expanded := false
var _sidebar_tween: Tween = null
var _search_container: Control = null

# Mod Tab Section State
const DEFAULT_MOD_ICON := "res://textures/icons/puzzle.png"
var _mod_section_started := false
var _mod_section_separator: Control = null

var _tab_meta: Array[Dictionary] = []
var _tab_index_by_container: Dictionary = {}
var _current_tab_index: int = 0
var _controls_by_key: Dictionary = {}
var _suppressed_control_events: Dictionary = {}
var _restart_required_changed: Dictionary = {}
var _restart_from_settings := false
var _restart_from_external := false
var _popup_provider: Callable = Callable()

var _is_animating := false
var _tween: Tween = null

func _init(hud: Node, version: String):
    _hud_node = hud
    _core_version = version
    _create_ui_structure()

func _create_ui_structure() -> void:
    root_control = Control.new()
    root_control.name = "TajsCoreMenus"
    root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
    # Match the game's Menus container anchoring (right side, full height)
    root_control.anchor_left = 1.0
    root_control.anchor_right = 1.0
    root_control.anchor_bottom = 1.0
    # Use same offsets as the game's native Menus container
    root_control.offset_left = MENUS_OFFSET_LEFT
    root_control.offset_right = MENUS_OFFSET_RIGHT
    root_control.grow_horizontal = Control.GROW_DIRECTION_BEGIN
    root_control.grow_vertical = Control.GROW_DIRECTION_BOTH

    var overlay = _hud_node.get_node_or_null("Main/MainContainer/Overlay")
    if overlay:
        overlay.add_child(root_control)
    else:
        _log_warn("Could not find Overlay to attach Settings UI")
        return

    settings_panel = PanelContainer.new()
    settings_panel.name = "TajsCoreSettingsPanel"
    settings_panel.visible = false
    settings_panel.theme_type_variation = "ShadowPanelContainer"
    # Fill the parent control with a small inner margin (matching native panels)
    settings_panel.anchor_right = 1.0
    settings_panel.anchor_bottom = 1.0
    settings_panel.offset_right = - PANEL_INNER_MARGIN
    settings_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
    settings_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
    root_control.add_child(settings_panel)

    var main_vbox = VBoxContainer.new()
    main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
    main_vbox.add_theme_constant_override("separation", 0)
    settings_panel.add_child(main_vbox)
    _main_vbox = main_vbox

    _create_title_panel(main_vbox)
    _create_content_panel(main_vbox)
    _create_footer_panel(main_vbox)
    # Connect to viewport resize to match game's dynamic scaling
    var viewport = root_control.get_viewport()
    if viewport != null:
        var resize_handler := Callable(self, "_on_viewport_resized")
        if not viewport.size_changed.is_connected(resize_handler):
            viewport.size_changed.connect(resize_handler)

func _on_viewport_resized() -> void:
    # The panel automatically scales with resolution because we're using the same
    # anchor/offset setup as the native Menus container. The HUD's update_size()
    # scales Main which contains our panel, so no additional logic is needed here.
    # This callback is kept for potential future adjustments.
    pass

func _create_title_panel(parent: Control) -> void:
    var title_panel := Panel.new()
    title_panel.custom_minimum_size = Vector2(0, 80)
    title_panel.theme_type_variation = "OverlayPanelTitle"
    parent.add_child(title_panel)

    var title_container := HBoxContainer.new()
    title_container.set_anchors_preset(Control.PRESET_FULL_RECT)
    title_container.offset_left = 15
    title_container.offset_top = 15
    title_container.offset_right = -15
    title_container.offset_bottom = -15
    title_container.alignment = BoxContainer.ALIGNMENT_CENTER
    title_panel.add_child(title_container)

    var title_icon := TextureRect.new()
    title_icon.custom_minimum_size = Vector2(48, 48)
    title_icon.texture = load("res://textures/icons/puzzle.png")
    title_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    title_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    title_icon.self_modulate = Color(0.567, 0.69465, 0.9, 1)
    title_container.add_child(title_icon)

    var title_label := Label.new()
    title_label.text = "Taj's Core"
    title_label.add_theme_font_size_override("font_size", 40)
    title_container.add_child(title_label)

func _create_content_panel(parent: Control) -> void:
    var content_panel := PanelContainer.new()
    content_panel.theme_type_variation = "MenuPanel"
    content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    parent.add_child(content_panel)

    var main_hbox := HBoxContainer.new()
    main_hbox.add_theme_constant_override("separation", 0)
    content_panel.add_child(main_hbox)

    var sidebar := VBoxContainer.new()
    sidebar.name = "Sidebar"
    sidebar.custom_minimum_size = Vector2(SIDEBAR_WIDTH_COLLAPSED, 0)
    sidebar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
    sidebar.add_theme_constant_override("separation", 0)
    sidebar.clip_contents = true
    sidebar.mouse_filter = Control.MOUSE_FILTER_STOP
    main_hbox.add_child(sidebar)
    _sidebar = sidebar

    sidebar.mouse_entered.connect(_on_sidebar_mouse_entered)
    sidebar.mouse_exited.connect(_on_sidebar_mouse_exited)

    var tab_scroll := ScrollContainer.new()
    tab_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    tab_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    tab_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    tab_scroll.mouse_entered.connect(_on_sidebar_mouse_entered)
    tab_scroll.mouse_exited.connect(_on_sidebar_mouse_exited)
    sidebar.add_child(tab_scroll)

    tab_buttons_container = VBoxContainer.new()
    tab_buttons_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    tab_buttons_container.add_theme_constant_override("separation", 10)
    tab_buttons_container.mouse_filter = Control.MOUSE_FILTER_PASS
    tab_scroll.add_child(tab_buttons_container)

    var separator := VSeparator.new()
    separator.add_theme_constant_override("separation", 2)
    main_hbox.add_child(separator)

    var content_vbox := VBoxContainer.new()
    content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content_vbox.add_theme_constant_override("separation", 0)
    main_hbox.add_child(content_vbox)

    _create_search_field(content_vbox)

    tab_container = TabContainer.new()
    tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
    tab_container.theme_type_variation = "EmptyTabContainer"
    tab_container.tabs_visible = false
    content_vbox.add_child(tab_container)

func _create_footer_panel(parent: Control) -> void:
    var version_panel := PanelContainer.new()
    version_panel.theme_type_variation = "MenuPanelTitle"
    version_panel.custom_minimum_size = Vector2(0, 40)
    parent.add_child(version_panel)

    var version_label := Label.new()
    version_label.text = "Taj's Core v" + _core_version
    version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    version_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    version_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    version_label.add_theme_color_override("font_color", Color(0.627, 0.776, 0.812, 0.8))
    version_panel.add_child(version_label)

func add_mod_button(callback: Callable) -> void:
    var extras_container = _hud_node.get_node_or_null("Main/MainContainer/Overlay/ExtrasButtons/Container")
    if extras_container == null:
        return

    settings_button = Button.new()
    settings_button.name = "TajsCoreSettings"
    settings_button.custom_minimum_size = Vector2(80, 80)
    settings_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER | Control.SIZE_EXPAND
    settings_button.focus_mode = Control.FOCUS_NONE
    settings_button.theme_type_variation = "ButtonMenu"
    settings_button.toggle_mode = true
    settings_button.icon = load("res://textures/icons/puzzle.png")
    settings_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
    settings_button.expand_icon = true
    settings_button.pressed.connect(callback)

    extras_container.add_child(settings_button)
    extras_container.move_child(settings_button, 0)

func add_tab(p_name: String, icon_path: String) -> VBoxContainer:
    return add_tab_ex(p_name, icon_path)

func add_tab_ex(display_name: String, icon_path: String, tab_id: String = "") -> VBoxContainer:
    # Guard against empty names - skip tab creation entirely
    if display_name.strip_edges().is_empty():
        _log_warn("Skipping tab with empty name (icon: %s)" % icon_path)
        return null

    var scroll := ScrollContainer.new()
    scroll.name = tab_id if tab_id != "" else display_name
    scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO

    var margin := MarginContainer.new()
    margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    margin.add_theme_constant_override("margin_left", 20)
    margin.add_theme_constant_override("margin_right", 20)
    margin.add_theme_constant_override("margin_top", 10)
    scroll.add_child(margin)

    var vbox := VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 10)
    margin.add_child(vbox)

    tab_container.add_child(scroll)
    var tab_index := tab_container.get_child_count() - 1

    var btn := Button.new()
    btn.name = display_name + "Tab"
    btn.text = ""
    btn.custom_minimum_size = Vector2(SIDEBAR_WIDTH_COLLAPSED, 50)
    btn.focus_mode = Control.FOCUS_NONE
    btn.theme_type_variation = "TabButton"
    btn.toggle_mode = true
    btn.icon = load(icon_path)
    btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
    btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
    btn.add_theme_constant_override("icon_max_width", 36)
    btn.add_theme_constant_override("h_separation", 10)
    btn.mouse_entered.connect(_on_sidebar_mouse_entered)
    btn.mouse_exited.connect(_on_sidebar_mouse_exited)

    btn.pressed.connect(func(): _on_tab_selected(tab_index))

    if tab_index == 0:
        btn.button_pressed = true

    tab_buttons_container.add_child(btn)
    _tab_buttons.append(btn)
    _register_tab_meta(tab_index, display_name, tab_id, "manual")
    _tab_index_by_container[vbox] = tab_index
    if tab_index == _current_tab_index:
        _update_tab_action_buttons()

    return vbox

func add_mod_section_separator() -> void:
    # Adds a visual separator between Core tabs and mod tabs in the sidebar.
    if _mod_section_started:
        return
    _mod_section_started = true

    var sep := HSeparator.new()
    sep.name = "ModSectionSeparator"
    sep.custom_minimum_size = Vector2(0, 20)
    sep.add_theme_constant_override("separation", 8)
    tab_buttons_container.add_child(sep)
    _mod_section_separator = sep

func add_mod_tab(display_name: String, icon_path: String = "") -> VBoxContainer:
    # Adds a tab for a mod in the mod section. Uses puzzle icon if no icon specified.
    return add_mod_tab_ex(display_name, icon_path)

func add_mod_tab_ex(display_name: String, icon_path: String = "", tab_id: String = "", kind: String = "manual") -> VBoxContainer:
    # Adds a tab for a mod in the mod section with optional internal tab id.
    if not _mod_section_started:
        add_mod_section_separator()

    var effective_icon := icon_path if icon_path != "" and ResourceLoader.exists(icon_path) else DEFAULT_MOD_ICON
    var container = add_tab_ex(display_name, effective_icon, tab_id)
    if container != null:
        _set_tab_kind_for_container(container, kind)
    return container

func _on_tab_selected(index: int) -> void:
    tab_container.current_tab = index
    _current_tab_index = index
    for i in range(_tab_buttons.size()):
        _tab_buttons[i].set_pressed_no_signal(i == index)
    _filter_rows(_search_field.text if _search_field else "")
    _update_tab_action_buttons()

func set_settings(settings_ref) -> void:
    if _settings_ref != null and _settings_ref.has_signal("value_changed"):
        var handler := Callable(self, "_on_settings_value_changed")
        if _settings_ref.value_changed.is_connected(handler):
            _settings_ref.value_changed.disconnect(handler)
    _settings_ref = settings_ref
    if _settings_ref != null and _settings_ref.has_signal("value_changed"):
        var new_handler := Callable(self, "_on_settings_value_changed")
        if not _settings_ref.value_changed.is_connected(new_handler):
            _settings_ref.value_changed.connect(new_handler)
    _filter_rows(_search_field.text if _search_field else "")
    _rebuild_restart_required_state()
    _update_tab_action_buttons()

func set_popup_provider(callable_show_popup: Callable) -> void:
    _popup_provider = callable_show_popup

func get_current_tab_id() -> String:
    var meta := _get_tab_meta(_current_tab_index)
    return str(meta.get("id", ""))

func get_current_tab_display_name() -> String:
    var meta := _get_tab_meta(_current_tab_index)
    return str(meta.get("display", ""))

func _register_tab_meta(index: int, display_name: String, tab_id: String, kind: String) -> void:
    var id_value := tab_id if tab_id != "" else display_name
    if index >= _tab_meta.size():
        _tab_meta.resize(index + 1)
    _tab_meta[index] = {
        "display": display_name,
        "id": id_value,
        "kind": kind
    }

func _get_tab_meta(index: int) -> Dictionary:
    if index >= 0 and index < _tab_meta.size():
        var meta = _tab_meta[index]
        if meta is Dictionary:
            return meta
    return {}

func _set_tab_kind_for_container(container: Control, kind: String) -> void:
    if container == null:
        return
    var index := _tab_index_by_container.get(container, -1)
    if index < 0:
        return
    if index >= _tab_meta.size():
        return
    var meta: Dictionary = _tab_meta[index]
    meta["kind"] = kind
    _tab_meta[index] = meta
    _update_tab_action_buttons()

func _get_current_tab_kind() -> String:
    var meta := _get_tab_meta(_current_tab_index)
    return str(meta.get("kind", "manual"))

func _update_tab_action_buttons() -> void:
    var enable_actions := false
    if _settings_ref != null and get_current_tab_id() != "" and _get_current_tab_kind() == "schema":
        enable_actions = true
    if _export_button:
        _export_button.disabled = not enable_actions
    if _import_button:
        _import_button.disabled = not enable_actions
    if _reset_tab_button:
        _reset_tab_button.disabled = not enable_actions

func set_visible(visible: bool) -> void:
    if _is_animating:
        return

    if visible:
        _emit_menu_close()

    if settings_button:
        settings_button.set_pressed_no_signal(visible)

    if _tween and _tween.is_valid():
        _tween.kill()

    _is_animating = true

    if visible:
        settings_panel.visible = true
        settings_panel.modulate.a = 0
        settings_panel.position.x = 200

        _tween = settings_panel.create_tween()
        _tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        _tween.set_parallel()
        _tween.tween_property(settings_panel, "modulate:a", 1.0, 0.25)
        _tween.tween_property(settings_panel, "position:x", 0.0, 0.25)
        _tween.finished.connect(func(): _is_animating = false)
        _play_sound("menu_open")
    else:
        settings_panel.modulate.a = 1
        _clear_search()

        _tween = settings_panel.create_tween()
        _tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        _tween.set_parallel()
        _tween.tween_property(settings_panel, "position:x", 200.0, 0.25)
        _tween.tween_property(settings_panel, "modulate:a", 0.0, 0.25)
        _tween.finished.connect(func():
            settings_panel.visible = false
            _is_animating = false
        )
        _play_sound("menu_close")

func is_visible() -> bool:
    if not is_instance_valid(settings_panel):
        return false
    return settings_panel.visible

func _create_search_field(parent: Control) -> void:
    var search_container := PanelContainer.new()
    search_container.theme_type_variation = "MenuPanelTitle"
    search_container.custom_minimum_size = Vector2(0, 90)
    parent.add_child(search_container)
    _search_container = search_container

    var search_margin := MarginContainer.new()
    search_margin.add_theme_constant_override("margin_left", 15)
    search_margin.add_theme_constant_override("margin_right", 15)
    search_margin.add_theme_constant_override("margin_top", 8)
    search_margin.add_theme_constant_override("margin_bottom", 8)
    search_container.add_child(search_margin)

    var layout := VBoxContainer.new()
    layout.add_theme_constant_override("separation", 6)
    search_margin.add_child(layout)

    var row_top := HBoxContainer.new()
    row_top.add_theme_constant_override("separation", 10)
    layout.add_child(row_top)

    _search_field = LineEdit.new()
    _search_field.placeholder_text = "Search settings..."
    _search_field.clear_button_enabled = true
    _search_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _search_field.add_theme_font_size_override("font_size", 24)
    _search_field.text_changed.connect(_filter_rows)
    row_top.add_child(_search_field)

    _filter_only_changed_btn = CheckButton.new()
    _filter_only_changed_btn.text = "Only changed"
    _filter_only_changed_btn.focus_mode = Control.FOCUS_NONE
    _filter_only_changed_btn.toggled.connect(func(v: bool):
        _filter_only_changed = v
        _filter_rows(_search_field.text if _search_field else "")
    )
    row_top.add_child(_filter_only_changed_btn)

    _filter_show_advanced_btn = CheckButton.new()
    _filter_show_advanced_btn.text = "Show advanced"
    _filter_show_advanced_btn.focus_mode = Control.FOCUS_NONE
    _filter_show_advanced_btn.toggled.connect(func(v: bool):
        _filter_show_advanced = v
        _filter_rows(_search_field.text if _search_field else "")
    )
    row_top.add_child(_filter_show_advanced_btn)

    var row_bottom := HBoxContainer.new()
    row_bottom.alignment = BoxContainer.ALIGNMENT_END
    row_bottom.add_theme_constant_override("separation", 10)
    layout.add_child(row_bottom)

    _export_button = Button.new()
    _export_button.text = "Export"
    _export_button.focus_mode = Control.FOCUS_NONE
    _export_button.theme_type_variation = "TabButton"
    _export_button.pressed.connect(_on_export_current_tab)
    row_bottom.add_child(_export_button)

    _import_button = Button.new()
    _import_button.text = "Import"
    _import_button.focus_mode = Control.FOCUS_NONE
    _import_button.theme_type_variation = "TabButton"
    _import_button.pressed.connect(_on_import_current_tab)
    row_bottom.add_child(_import_button)

    _reset_tab_button = Button.new()
    _reset_tab_button.text = "Reset Tab"
    _reset_tab_button.focus_mode = Control.FOCUS_NONE
    _reset_tab_button.theme_type_variation = "TabButton"
    _reset_tab_button.pressed.connect(_on_reset_current_tab)
    row_bottom.add_child(_reset_tab_button)

    _update_tab_action_buttons()

func _filter_rows(query: String) -> void:
    var search_term := query.strip_edges().to_lower()
    var current_tab := _current_tab_index

    for entry in _searchable_rows:
        var entry_row: Control = entry.get("row", null)
        if entry_row == null or not is_instance_valid(entry_row):
            continue
        var visible := int(entry.get("tab_index", -1)) == current_tab
        if visible and not search_term.is_empty():
            var label_text := str(entry.get("label", ""))
            var key_text := str(entry.get("key", ""))
            var desc_text := str(entry.get("description", ""))
            var matches := label_text.to_lower().contains(search_term)
            if not matches and key_text != "":
                matches = key_text.to_lower().contains(search_term)
            if not matches and desc_text != "":
                matches = desc_text.to_lower().contains(search_term)
            visible = matches
        if visible and bool(entry.get("is_advanced", false)) and not _filter_show_advanced:
            visible = false
        if visible and _filter_only_changed and bool(entry.get("is_setting_row", false)) and str(entry.get("key", "")) != "":
            if _settings_ref != null and _settings_ref.has_method("is_default"):
                if _settings_ref.is_default(str(entry.get("key", ""))):
                    visible = false
        var depends_on = entry.get("depends_on", {})
        if visible and depends_on is Dictionary and not depends_on.is_empty():
            if not _dependency_is_met(depends_on):
                visible = false
        entry_row.visible = visible

func _clear_search() -> void:
    if _search_field and is_instance_valid(_search_field):
        _search_field.text = ""
        _filter_rows("")

func _track_row(row: Control, label_text: String, tab_idx: int, key: String = "", description: String = "", is_setting_row: bool = false, is_advanced: bool = false, depends_on: Dictionary = {}) -> void:
    _searchable_rows.append({
        "row": row,
        "label": label_text,
        "key": key,
        "description": description,
        "tab_index": tab_idx,
        "is_setting_row": is_setting_row,
        "is_advanced": is_advanced,
        "depends_on": depends_on
    })

func add_toggle(parent: Control, label_text: String, initial_val: bool, callback: Callable, tooltip: String = "") -> CheckButton:
    var row := HBoxContainer.new()
    row.custom_minimum_size = Vector2(0, 64)
    if tooltip != "":
        row.tooltip_text = tooltip
    parent.add_child(row)

    _track_row(row, label_text, tab_container.get_child_count() - 1)

    var label := Label.new()
    label.text = label_text
    label.add_theme_font_size_override("font_size", 32)
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(label)

    var toggle := CheckButton.new()
    toggle.size_flags_horizontal = Control.SIZE_SHRINK_END
    toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    toggle.focus_mode = Control.FOCUS_NONE
    toggle.flat = true
    toggle.button_pressed = initial_val
    toggle.toggled.connect(callback)
    row.add_child(toggle)

    return toggle

func add_slider(parent: Control, label_text: String, start_val: float, min_val: float, max_val: float, step: float, suffix: String, callback: Callable) -> HSlider:
    var container := VBoxContainer.new()
    container.add_theme_constant_override("separation", 5)
    parent.add_child(container)

    _track_row(container, label_text, tab_container.get_child_count() - 1)

    var header := HBoxContainer.new()
    container.add_child(header)

    var label := Label.new()
    label.text = label_text
    label.add_theme_font_size_override("font_size", 32)
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(label)

    var value_label := Label.new()
    value_label.text = _format_slider_value(start_val, suffix)
    value_label.add_theme_font_size_override("font_size", 32)
    header.add_child(value_label)

    var slider := HSlider.new()
    slider.min_value = min_val
    slider.max_value = max_val
    slider.step = step
    slider.value = start_val
    slider.focus_mode = Control.FOCUS_NONE

    slider.value_changed.connect(func(v):
        value_label.text = _format_slider_value(v, suffix)
        callback.call(v)
    )
    container.add_child(slider)
    return slider

func _format_slider_value(value: float, suffix: String) -> String:
    if suffix == "x":
        return str(snapped(value, 0.1)) + suffix
    if suffix == "%" or suffix == "px":
        return str(int(value)) + suffix
    return str(snapped(value, 0.1))

func add_button(parent: Control, text: String, callback: Callable) -> Button:
    var btn := Button.new()
    btn.text = text
    btn.custom_minimum_size = Vector2(0, 60)
    btn.theme_type_variation = "TabButton"
    btn.focus_mode = Control.FOCUS_NONE
    btn.pressed.connect(callback)
    parent.add_child(btn)

    _track_row(btn, text, tab_container.get_child_count() - 1)

    return btn

func add_dropdown(parent: Control, label_text: String, options: Array, selected: int, callback: Callable) -> OptionButton:
    var row := HBoxContainer.new()
    row.custom_minimum_size = Vector2(0, 64)
    parent.add_child(row)

    _track_row(row, label_text, tab_container.get_child_count() - 1)

    var label := Label.new()
    label.text = label_text
    label.add_theme_font_size_override("font_size", 32)
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(label)

    var dropdown := OptionButton.new()
    dropdown.focus_mode = Control.FOCUS_NONE
    for option in options:
        dropdown.add_item(str(option))
    dropdown.selected = clampi(selected, 0, max(0, options.size() - 1))
    dropdown.item_selected.connect(callback)
    row.add_child(dropdown)

    return dropdown

func add_text_input(parent: Control, label_text: String, value: String, callback: Callable) -> LineEdit:
    var row := HBoxContainer.new()
    row.custom_minimum_size = Vector2(0, 64)
    parent.add_child(row)

    _track_row(row, label_text, tab_container.get_child_count() - 1)

    var label := Label.new()
    label.text = label_text
    label.add_theme_font_size_override("font_size", 32)
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(label)

    var input := LineEdit.new()
    input.text = value
    input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    input.text_changed.connect(callback)
    row.add_child(input)

    return input

func add_color_picker(parent: Control, label_text: String, value: Color, callback: Callable) -> ColorPickerButton:
    var row := HBoxContainer.new()
    row.custom_minimum_size = Vector2(0, 64)
    parent.add_child(row)

    _track_row(row, label_text, tab_container.get_child_count() - 1)

    var label := Label.new()
    label.text = label_text
    label.add_theme_font_size_override("font_size", 32)
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(label)

    var picker := ColorPickerButton.new()
    picker.color = value
    picker.color_changed.connect(callback)
    row.add_child(picker)

    return picker

func add_separator(parent: Control) -> HSeparator:
    var sep := HSeparator.new()
    parent.add_child(sep)
    return sep

func add_section_separator_small(parent: Control) -> HSeparator:
    # Small separator placed under section headers
    var sep := HSeparator.new()
    sep.custom_minimum_size = Vector2(0, 12)
    # Create a StyleBoxLine for actual thickness control
    var style := StyleBoxLine.new()
    style.color = Color(0.627, 0.776, 0.812, 0.5) # Match the theme color with some transparency
    style.thickness = 2
    style.grow_begin = 0
    style.grow_end = 0
    sep.add_theme_stylebox_override("separator", style)
    parent.add_child(sep)
    return sep

func add_section_separator_large(parent: Control) -> HSeparator:
    # Larger separator placed at the end of sections
    var sep := HSeparator.new()
    sep.custom_minimum_size = Vector2(0, 24)
    # Create a StyleBoxLine for actual thickness control
    var style := StyleBoxLine.new()
    style.color = Color(0.627, 0.776, 0.812, 0.8) # Match the theme color, more visible
    style.thickness = 3
    style.grow_begin = 0
    style.grow_end = 0
    sep.add_theme_stylebox_override("separator", style)
    parent.add_child(sep)
    return sep

func add_section_header(parent: Control, title: String) -> Label:
    var label := Label.new()
    label.text = title.to_upper() # Force uppercase for section headers
    label.add_theme_font_size_override("font_size", 36) # Larger than settings (32px)
    label.add_theme_color_override("font_color", Color(0.627, 0.776, 0.812, 1.0)) # Theme accent color
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    label.custom_minimum_size = Vector2(0, 48) # Add vertical padding
    parent.add_child(label)
    return label

func add_collapsible_section(parent: Control, title: String, expanded: bool = false) -> VBoxContainer:
    var container := VBoxContainer.new()
    container.add_theme_constant_override("separation", 6)
    parent.add_child(container)

    var header := Button.new()
    header.text = title
    header.toggle_mode = true
    header.button_pressed = expanded
    header.theme_type_variation = "TabButton"
    container.add_child(header)

    var content := VBoxContainer.new()
    content.visible = expanded
    container.add_child(content)

    header.toggled.connect(func(v: bool): content.visible = v)

    return content

# --- Schema-Driven UI ---

func build_schema_tab(container: VBoxContainer, settings_ref, ns_prefix: String, schema: Dictionary, opts := {}) -> void:
    if container == null or schema.is_empty():
        return
    if settings_ref != null and settings_ref != _settings_ref:
        set_settings(settings_ref)
    var tab_index := _get_tab_index_for_container(container)
    _set_tab_kind_for_container(container, "schema")

    var grouped: Dictionary = {}
    for key in schema.keys():
        var entry = schema[key]
        if not (entry is Dictionary):
            continue
        var category := str(entry.get("category", "General"))
        if category == "":
            category = "General"
        if not grouped.has(category):
            grouped[category] = []
        grouped[category].append(str(key))

    var categories: Array = grouped.keys()
    categories.sort_custom(func(a, b):
        return str(a).naturalnocasecmp_to(str(b)) < 0
    )

    var category_count := categories.size()
    var category_idx := 0
    for category in categories:
        var header = add_section_header(container, str(category))
        _track_row(header, str(category), tab_index)
        # Add small separator under the section header
        var small_sep = add_section_separator_small(container)
        _track_row(small_sep, str(category), tab_index)
        var keys: Array = grouped[category]
        keys = _sort_keys_by_dependency(keys, schema)
        for key in keys:
            var entry = schema.get(key, {})
            if entry is Dictionary:
                _build_schema_entry(container, tab_index, str(key), entry)
        # Add large separator at the end of the section (except for the last section)
        category_idx += 1
        if category_idx < category_count:
            var large_sep = add_section_separator_large(container)
            _track_row(large_sep, str(category), tab_index)

    _filter_rows(_search_field.text if _search_field else "")
    _rebuild_restart_required_state()

func _sort_keys_by_dependency(keys: Array, schema: Dictionary) -> Array:
    # Sort keys so that settings depending on other settings appear after their parent.
    # First, do an alphabetical sort as a baseline.
    var sorted_keys: Array = keys.duplicate()
    sorted_keys.sort_custom(func(a, b):
        return str(a).naturalnocasecmp_to(str(b)) < 0
    )
    
    # Build a dependency graph: for each key, find what it depends on
    var depends_on_map: Dictionary = {} # key -> parent key it depends on (if any)
    var dependents_map: Dictionary = {} # parent key -> array of keys that depend on it
    
    for key in sorted_keys:
        var entry = schema.get(str(key), {})
        if entry is Dictionary:
            var dep = entry.get("depends_on", {})
            if dep is Dictionary and dep.has("key"):
                var parent_key := str(dep.get("key", ""))
                if parent_key != "":
                    depends_on_map[str(key)] = parent_key
                    if not dependents_map.has(parent_key):
                        dependents_map[parent_key] = []
                    dependents_map[parent_key].append(str(key))
    
    # Now reorder: place each key, then immediately place its dependents (recursively)
    var result: Array = []
    var visited: Dictionary = {}
    
    for key in sorted_keys:
        _add_key_with_dependents(str(key), result, visited, depends_on_map, dependents_map, sorted_keys, schema)
    
    return result

func _add_key_with_dependents(key: String, result: Array, visited: Dictionary, depends_on_map: Dictionary, dependents_map: Dictionary, all_keys: Array, schema: Dictionary) -> void:
    if visited.has(key):
        return
    # If this key depends on something, ensure the parent is added first
    if depends_on_map.has(key):
        var parent_key: String = depends_on_map[key]
        if not visited.has(parent_key) and all_keys.has(parent_key):
            _add_key_with_dependents(parent_key, result, visited, depends_on_map, dependents_map, all_keys, schema)
    
    # Re-check after parent processing - the parent may have already added us as a dependent
    if visited.has(key):
        return
    
    # Don't add if not in our category's key list
    if not all_keys.has(key):
        return
    
    visited[key] = true
    result.append(key)
    
    # Add all dependents of this key immediately after it
    if dependents_map.has(key):
        var dependents: Array = dependents_map[key].duplicate()
        # Sort dependents alphabetically
        dependents.sort_custom(func(a, b):
            return str(a).naturalnocasecmp_to(str(b)) < 0
        )
        for dep_key in dependents:
            _add_key_with_dependents(str(dep_key), result, visited, depends_on_map, dependents_map, all_keys, schema)

func _build_schema_entry(container: VBoxContainer, tab_index: int, key: String, entry: Dictionary) -> void:
    if _settings_ref == null:
        return
    var schema_entry: Dictionary = entry.duplicate(true)
    var label_text := str(schema_entry.get("label", key))
    var description := str(schema_entry.get("description", ""))
    var is_advanced := bool(schema_entry.get("hidden", false)) or bool(schema_entry.get("experimental", false))
    var depends_on = schema_entry.get("depends_on", {})
    if not (depends_on is Dictionary):
        depends_on = {}
    var default_value = schema_entry.get("default", null)
    var current_value = _settings_ref.get_value(key, default_value)
    var entry_type := str(schema_entry.get("type", ""))
    if entry_type == "" and schema_entry.has("default"):
        entry_type = _infer_schema_type(schema_entry["default"])
    var ui_control := _get_schema_ui_control(schema_entry)

    if ui_control == "color_map":
        _build_schema_color_map(container, tab_index, key, label_text, description, current_value, is_advanced, depends_on, schema_entry)
        return

    match entry_type:
        "bool":
            _build_schema_bool(container, tab_index, key, label_text, description, bool(current_value), is_advanced, depends_on, schema_entry)
        "int", "float":
            if ui_control == "input":
                _build_schema_numeric_input(container, tab_index, key, label_text, description, current_value, is_advanced, depends_on, schema_entry, entry_type)
            elif schema_entry.has("min") and schema_entry.has("max"):
                _build_schema_slider(container, tab_index, key, label_text, description, current_value, is_advanced, depends_on, schema_entry, entry_type)
            else:
                _build_schema_numeric_input(container, tab_index, key, label_text, description, current_value, is_advanced, depends_on, schema_entry, entry_type)
        "enum":
            var options = schema_entry.get("options", [])
            if options is Array and not options.is_empty():
                _build_schema_enum(container, tab_index, key, label_text, description, current_value, is_advanced, depends_on, schema_entry, options)
            else:
                _build_schema_text(container, tab_index, key, label_text, description, str(current_value), is_advanced, depends_on, schema_entry)
        "string":
            _build_schema_text(container, tab_index, key, label_text, description, str(current_value), is_advanced, depends_on, schema_entry)
        "dict", "array", "keybind":
            _build_schema_json(container, tab_index, key, label_text, description, current_value, is_advanced, depends_on, schema_entry)
        "action":
            _build_schema_action(container, tab_index, key, label_text, description, is_advanced, depends_on, schema_entry)
        _:
            _build_schema_text(container, tab_index, key, label_text, description, str(current_value), is_advanced, depends_on, schema_entry)

func _build_schema_bool(container: VBoxContainer, tab_index: int, key: String, label_text: String, description: String, value: bool, is_advanced: bool, depends_on: Dictionary, schema_entry: Dictionary) -> void:
    var row := HBoxContainer.new()
    row.custom_minimum_size = Vector2(0, 64)
    if description != "":
        row.tooltip_text = description
    container.add_child(row)
    _track_row(row, label_text, tab_index, key, description, true, is_advanced, depends_on)

    var label := Label.new()
    label.text = label_text
    label.add_theme_font_size_override("font_size", 32)
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(label)

    var badge := _create_changed_badge()
    row.add_child(badge)

    var reset_btn := _create_reset_button(key)
    row.add_child(reset_btn)

    var toggle := CheckButton.new()
    toggle.size_flags_horizontal = Control.SIZE_SHRINK_END
    toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    toggle.focus_mode = Control.FOCUS_NONE
    toggle.flat = true
    toggle.button_pressed = value
    toggle.toggled.connect(func(v: bool):
        if _settings_ref == null:
            return
        if _is_event_suppressed(key):
            return
        _settings_ref.set_value(key, v)
    )
    row.add_child(toggle)

    _controls_by_key[key] = {
        "kind": "bool",
        "control": toggle,
        "row": row,
        "badge": badge,
        "schema": schema_entry
    }
    _update_changed_badge_for_key(key, badge)
    _register_restart_requirement(key, schema_entry)

func _build_schema_slider(container: VBoxContainer, tab_index: int, key: String, label_text: String, description: String, value: Variant, is_advanced: bool, depends_on: Dictionary, schema_entry: Dictionary, entry_type: String) -> void:
    var wrapper := VBoxContainer.new()
    wrapper.add_theme_constant_override("separation", 5)
    if description != "":
        wrapper.tooltip_text = description
    container.add_child(wrapper)
    _track_row(wrapper, label_text, tab_index, key, description, true, is_advanced, depends_on)

    var header := HBoxContainer.new()
    wrapper.add_child(header)

    var label := Label.new()
    label.text = label_text
    label.add_theme_font_size_override("font_size", 32)
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(label)

    var value_label := Label.new()
    value_label.text = _format_schema_value(value, entry_type)
    value_label.add_theme_font_size_override("font_size", 24)
    header.add_child(value_label)

    var badge := _create_changed_badge()
    header.add_child(badge)

    var reset_btn := _create_reset_button(key)
    header.add_child(reset_btn)

    var slider := HSlider.new()
    slider.min_value = float(schema_entry.get("min", 0.0))
    slider.max_value = float(schema_entry.get("max", 1.0))
    slider.step = float(schema_entry.get("step", 1.0 if entry_type == "int" else 0.1))
    var numeric_value := float(value) if value != null else slider.min_value
    if entry_type == "int":
        numeric_value = float(int(numeric_value))
    slider.value = numeric_value
    slider.focus_mode = Control.FOCUS_NONE
    slider.value_changed.connect(func(v: float):
        if _settings_ref == null:
            return
        var next_value = int(v) if entry_type == "int" else v
        value_label.text = _format_schema_value(next_value, entry_type)
        if _is_event_suppressed(key):
            return
        _settings_ref.set_value(key, next_value, false)
    )
    slider.drag_ended.connect(func(changed: bool):
        if not changed or _settings_ref == null:
            return
        var final_value = int(slider.value) if entry_type == "int" else slider.value
        _settings_ref.set_value(key, final_value, true)
    )
    slider.focus_exited.connect(func():
        if _settings_ref == null:
            return
        var final_value = int(slider.value) if entry_type == "int" else slider.value
        _settings_ref.set_value(key, final_value, true)
    )
    wrapper.add_child(slider)

    _controls_by_key[key] = {
        "kind": "slider",
        "control": slider,
        "row": wrapper,
        "badge": badge,
        "schema": schema_entry,
        "value_label": value_label,
        "entry_type": entry_type
    }
    _update_changed_badge_for_key(key, badge)
    _register_restart_requirement(key, schema_entry)

func _build_schema_numeric_input(container: VBoxContainer, tab_index: int, key: String, label_text: String, description: String, value: Variant, is_advanced: bool, depends_on: Dictionary, schema_entry: Dictionary, entry_type: String) -> void:
    var row := HBoxContainer.new()
    row.custom_minimum_size = Vector2(0, 64)
    if description != "":
        row.tooltip_text = description
    container.add_child(row)
    _track_row(row, label_text, tab_index, key, description, true, is_advanced, depends_on)

    var label := Label.new()
    label.text = label_text
    label.add_theme_font_size_override("font_size", 32)
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(label)

    var badge := _create_changed_badge()
    row.add_child(badge)

    var reset_btn := _create_reset_button(key)
    row.add_child(reset_btn)

    var input := LineEdit.new()
    input.text = str(value)
    input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    input.focus_mode = Control.FOCUS_ALL
    var apply_value := func(text: String, save: bool):
        if _settings_ref == null:
            return
        if entry_type == "int":
            if text.is_valid_int():
                _settings_ref.set_value(key, int(text), save)
        else:
            if text.is_valid_float():
                _settings_ref.set_value(key, float(text), save)
    input.text_changed.connect(func(text: String):
        if _is_event_suppressed(key):
            return
        apply_value.call(text, false)
    )
    input.text_submitted.connect(func(text: String):
        if _is_event_suppressed(key):
            return
        apply_value.call(text, true)
    )
    input.focus_exited.connect(func():
        if _is_event_suppressed(key):
            return
        apply_value.call(input.text, true)
    )
    row.add_child(input)

    _controls_by_key[key] = {
        "kind": "numeric",
        "control": input,
        "row": row,
        "badge": badge,
        "schema": schema_entry,
        "entry_type": entry_type
    }
    _update_changed_badge_for_key(key, badge)
    _register_restart_requirement(key, schema_entry)

func _build_schema_enum(container: VBoxContainer, tab_index: int, key: String, label_text: String, description: String, value: Variant, is_advanced: bool, depends_on: Dictionary, schema_entry: Dictionary, options: Array) -> void:
    var row := HBoxContainer.new()
    row.custom_minimum_size = Vector2(0, 64)
    if description != "":
        row.tooltip_text = description
    container.add_child(row)
    _track_row(row, label_text, tab_index, key, description, true, is_advanced, depends_on)

    var label := Label.new()
    label.text = label_text
    label.add_theme_font_size_override("font_size", 32)
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(label)

    var badge := _create_changed_badge()
    row.add_child(badge)

    var reset_btn := _create_reset_button(key)
    row.add_child(reset_btn)

    var dropdown := OptionButton.new()
    dropdown.focus_mode = Control.FOCUS_NONE
    var option_labels: Array = []
    var option_values: Array = []
    for option in options:
        if option is Dictionary:
            var opt_value = option.get("value", option.get("label", ""))
            var opt_label = option.get("label", opt_value)
            option_values.append(opt_value)
            option_labels.append(str(opt_label))
        else:
            option_values.append(option)
            option_labels.append(str(option))
    for i in range(option_labels.size()):
        dropdown.add_item(option_labels[i])
    # JSON loads integers as floats, so we need to coerce when comparing against int option values
    var lookup_value = value
    if typeof(value) == TYPE_FLOAT and not option_values.is_empty():
        var all_int := true
        for ov in option_values:
            if typeof(ov) != TYPE_INT:
                all_int = false
                break
        if all_int:
            lookup_value = int(value)
    var selected_idx := option_values.find(lookup_value)
    if selected_idx < 0:
        selected_idx = 0
    dropdown.select(selected_idx)
    dropdown.item_selected.connect(func(idx: int):
        if _settings_ref == null:
            return
        if _is_event_suppressed(key):
            return
        var next_value = option_values[idx] if idx >= 0 and idx < option_values.size() else option_values[0]
        _settings_ref.set_value(key, next_value)
    )
    row.add_child(dropdown)

    _controls_by_key[key] = {
        "kind": "dropdown",
        "control": dropdown,
        "row": row,
        "badge": badge,
        "schema": schema_entry,
        "options": options,
        "option_values": option_values
    }
    _update_changed_badge_for_key(key, badge)
    _register_restart_requirement(key, schema_entry)

func _build_schema_text(container: VBoxContainer, tab_index: int, key: String, label_text: String, description: String, value: String, is_advanced: bool, depends_on: Dictionary, schema_entry: Dictionary) -> void:
    var row := HBoxContainer.new()
    row.custom_minimum_size = Vector2(0, 64)
    if description != "":
        row.tooltip_text = description
    container.add_child(row)
    _track_row(row, label_text, tab_index, key, description, true, is_advanced, depends_on)

    var label := Label.new()
    label.text = label_text
    label.add_theme_font_size_override("font_size", 32)
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(label)

    var badge := _create_changed_badge()
    row.add_child(badge)

    var reset_btn := _create_reset_button(key)
    row.add_child(reset_btn)

    var input := LineEdit.new()
    input.text = value
    input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    input.text_changed.connect(func(text: String):
        if _settings_ref == null:
            return
        if _is_event_suppressed(key):
            return
        _settings_ref.set_value(key, text, false)
    )
    input.text_submitted.connect(func(text: String):
        if _settings_ref == null:
            return
        if _is_event_suppressed(key):
            return
        _settings_ref.set_value(key, text, true)
    )
    input.focus_exited.connect(func():
        if _settings_ref == null:
            return
        if _is_event_suppressed(key):
            return
        _settings_ref.set_value(key, input.text, true)
    )
    row.add_child(input)

    _controls_by_key[key] = {
        "kind": "text",
        "control": input,
        "row": row,
        "badge": badge,
        "schema": schema_entry
    }
    _update_changed_badge_for_key(key, badge)
    _register_restart_requirement(key, schema_entry)

func _build_schema_json(container: VBoxContainer, tab_index: int, key: String, label_text: String, description: String, value: Variant, is_advanced: bool, depends_on: Dictionary, schema_entry: Dictionary) -> void:
    var row := HBoxContainer.new()
    row.custom_minimum_size = Vector2(0, 64)
    if description != "":
        row.tooltip_text = description
    container.add_child(row)
    _track_row(row, label_text, tab_index, key, description, true, is_advanced, depends_on)

    var label := Label.new()
    label.text = label_text
    label.add_theme_font_size_override("font_size", 32)
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(label)

    var badge := _create_changed_badge()
    row.add_child(badge)

    var reset_btn := _create_reset_button(key)
    row.add_child(reset_btn)

    var copy_btn := Button.new()
    copy_btn.text = "Copy JSON"
    copy_btn.focus_mode = Control.FOCUS_NONE
    copy_btn.pressed.connect(func():
        var payload = JSON.stringify(_settings_ref.get_value(key, value), "\t")
        DisplayServer.clipboard_set(payload)
    )
    row.add_child(copy_btn)

    var edit_btn := Button.new()
    edit_btn.text = "Edit JSON"
    edit_btn.focus_mode = Control.FOCUS_NONE
    edit_btn.pressed.connect(func():
        _show_json_editor(key, _settings_ref.get_value(key, value))
    )
    row.add_child(edit_btn)

    _controls_by_key[key] = {
        "kind": "json",
        "control": null,
        "row": row,
        "badge": badge,
        "schema": schema_entry
    }
    _update_changed_badge_for_key(key, badge)
    _register_restart_requirement(key, schema_entry)

func _build_schema_color_map(container: VBoxContainer, tab_index: int, key: String, label_text: String, description: String, value: Variant, is_advanced: bool, depends_on: Dictionary, schema_entry: Dictionary) -> void:
    var overrides: Dictionary = value if value is Dictionary else {}
    var options_raw = schema_entry.get("color_options", {})
    var option_list: Array[Dictionary] = []
    if options_raw is Dictionary:
        for opt_key in options_raw.keys():
            option_list.append({
                "id": str(opt_key),
                "label": str(options_raw[opt_key])
            })
    elif options_raw is Array:
        for opt_key in options_raw:
            option_list.append({
                "id": str(opt_key),
                "label": str(opt_key)
            })
    option_list.sort_custom(func(a, b):
        return str(a.get("label", "")).naturalnocasecmp_to(str(b.get("label", ""))) < 0
    )
    if option_list.is_empty():
        _build_schema_json(container, tab_index, key, label_text, description, value, is_advanced, depends_on, schema_entry)
        return

    var header := HBoxContainer.new()
    header.custom_minimum_size = Vector2(0, 64)
    if description != "":
        header.tooltip_text = description
    container.add_child(header)
    _track_row(header, label_text, tab_index, key, description, true, is_advanced, depends_on)

    var title := Label.new()
    title.text = label_text
    title.add_theme_font_size_override("font_size", 32)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(title)

    var badge := _create_changed_badge()
    header.add_child(badge)

    var reset_btn := _create_reset_button(key)
    header.add_child(reset_btn)

    var list_container := VBoxContainer.new()
    list_container.add_theme_constant_override("separation", 6)
    container.add_child(list_container)

    var pickers: Dictionary = {}
    var color_get: Callable = schema_entry.get("color_get", Callable())
    for option in option_list:
        var option_id := str(option.get("id", ""))
        if option_id == "":
            continue
        var option_label := str(option.get("label", option_id))
        var row := HBoxContainer.new()
        row.custom_minimum_size = Vector2(0, 60)
        list_container.add_child(row)
        _track_row(row, option_label, tab_index, key, description, true, is_advanced, depends_on)

        var label := Label.new()
        label.text = option_label
        label.add_theme_font_size_override("font_size", 28)
        label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(label)

        var color_btn := Button.new()
        color_btn.custom_minimum_size = Vector2(90, 36)
        color_btn.focus_mode = Control.FOCUS_NONE
        var style := StyleBoxFlat.new()
        style.bg_color = _get_color_map_color(overrides, option_id, color_get)
        style.border_width_left = 2
        style.border_width_top = 2
        style.border_width_right = 2
        style.border_width_bottom = 2
        style.border_color = Color(0.3, 0.3, 0.3)
        style.set_corner_radius_all(4)
        color_btn.add_theme_stylebox_override("normal", style)
        color_btn.add_theme_stylebox_override("hover", style)
        color_btn.add_theme_stylebox_override("pressed", style)
        color_btn.pressed.connect(func():
            _show_color_map_picker(key, option_id, style.bg_color)
        )
        row.add_child(color_btn)

        var reset_color_btn := Button.new()
        reset_color_btn.text = "Reset"
        reset_color_btn.focus_mode = Control.FOCUS_NONE
        reset_color_btn.pressed.connect(func():
            if _settings_ref == null:
                return
            var data: Dictionary = _settings_ref.get_dict(key, {})
            if data.has(option_id):
                data.erase(option_id)
                _settings_ref.set_value(key, data, true)
        )
        row.add_child(reset_color_btn)

        pickers[option_id] = {"style": style, "button": color_btn}

    _controls_by_key[key] = {
        "kind": "color_map",
        "control": null,
        "row": header,
        "badge": badge,
        "schema": schema_entry,
        "pickers": pickers,
        "color_get": color_get
    }
    _update_changed_badge_for_key(key, badge)
    _register_restart_requirement(key, schema_entry)

func _build_schema_action(container: VBoxContainer, tab_index: int, key: String, label_text: String, description: String, is_advanced: bool, depends_on: Dictionary, schema_entry: Dictionary) -> void:
    var row := HBoxContainer.new()
    row.custom_minimum_size = Vector2(0, 64)
    if description != "":
        row.tooltip_text = description
    container.add_child(row)
    _track_row(row, label_text, tab_index, key, description, false, is_advanced, depends_on)

    var label := Label.new()
    label.text = label_text
    label.add_theme_font_size_override("font_size", 32)
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(label)

    var action_btn := Button.new()
    action_btn.text = "Run"
    action_btn.focus_mode = Control.FOCUS_NONE
    var action_callable = schema_entry.get("action", Callable())
    action_btn.pressed.connect(func():
        if action_callable is Callable and action_callable.is_valid():
            action_callable.call()
        else:
            emit_signal("action_triggered", key)
    )
    row.add_child(action_btn)

func _format_schema_value(value: Variant, entry_type: String) -> String:
    if entry_type == "int":
        return str(int(value))
    if entry_type == "float":
        return str(snapped(float(value), 0.01))
    return str(value)

func _infer_schema_type(default_value: Variant) -> String:
    match typeof(default_value):
        TYPE_BOOL:
            return "bool"
        TYPE_INT:
            return "int"
        TYPE_FLOAT:
            return "float"
        TYPE_STRING:
            return "string"
        TYPE_DICTIONARY:
            return "dict"
        TYPE_ARRAY:
            return "array"
        _:
            return "string"

func _get_schema_ui_control(schema_entry: Dictionary) -> String:
    var control = schema_entry.get("ui_control", "")
    if control == "":
        control = schema_entry.get("control", "")
    if control == "":
        control = schema_entry.get("widget", "")
    if control == "" and schema_entry.has("color_options"):
        control = "color_map"
    var control_str := str(control).to_lower()
    if control_str in ["input", "field", "numeric", "text"]:
        return "input"
    if control_str in ["color_map", "colors", "color"]:
        return "color_map"
    return control_str

func _get_color_map_color(overrides: Dictionary, option_id: String, color_get: Callable) -> Color:
    if overrides.has(option_id):
        var raw = overrides[option_id]
        if typeof(raw) == TYPE_STRING:
            return Color(str(raw))
    if color_get is Callable and color_get.is_valid():
        var result = color_get.call(option_id)
        if result is Color:
            return result
    return Color.WHITE

func _set_color_map_value(setting_key: String, option_id: String, color: Color, save: bool) -> void:
    if _settings_ref == null:
        return
    var data: Dictionary = _settings_ref.get_dict(setting_key, {})
    data[option_id] = color.to_html(false)
    _settings_ref.set_value(setting_key, data, save)

func _get_tab_index_for_container(container: Control) -> int:
    if _tab_index_by_container.has(container):
        return int(_tab_index_by_container[container])
    for i in range(tab_container.get_child_count()):
        var scroll := tab_container.get_child(i)
        if scroll is ScrollContainer and scroll.get_child_count() > 0:
            var margin := scroll.get_child(0)
            if margin is MarginContainer and margin.get_child_count() > 0:
                if margin.get_child(0) == container:
                    _tab_index_by_container[container] = i
                    return i
    return _current_tab_index

func _create_changed_badge() -> Label:
    var badge := Label.new()
    badge.text = "Changed"
    badge.add_theme_font_size_override("font_size", 16)
    badge.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
    badge.visible = false
    return badge

func _create_reset_button(key: String) -> Button:
    var btn := Button.new()
    btn.text = "Reset"
    btn.focus_mode = Control.FOCUS_NONE
    btn.pressed.connect(func():
        if _settings_ref != null and _settings_ref.has_method("reset_key"):
            _settings_ref.reset_key(key, true)
    )
    return btn

func _update_changed_badge_for_key(key: String, badge: Control) -> void:
    if badge == null:
        return
    var changed := false
    if _settings_ref != null and _settings_ref.has_method("is_default"):
        changed = not _settings_ref.is_default(key)
    badge.visible = changed

func _is_restart_pending_for_key(key: String) -> bool:
    if _settings_ref == null:
        return false
    if _settings_ref.has_method("is_restart_pending"):
        return _settings_ref.is_restart_pending(key)
    if _settings_ref.has_method("is_default"):
        return not _settings_ref.is_default(key)
    return false

func _register_restart_requirement(key: String, schema_entry: Dictionary) -> void:
    if not schema_entry.get("requires_restart", false):
        return
    if _is_restart_pending_for_key(key):
        _restart_required_changed[key] = true
    else:
        _restart_required_changed.erase(key)
    _restart_from_settings = _restart_required_changed.size() > 0

func _is_event_suppressed(key: String) -> bool:
    return _suppressed_control_events.has(key)

func _with_suppressed_event(key: String, callable: Callable) -> void:
    _suppressed_control_events[key] = true
    callable.call()
    _suppressed_control_events.erase(key)

func _dependency_is_met(depends_on: Dictionary) -> bool:
    var dep_key := str(depends_on.get("key", ""))
    if dep_key == "":
        return true
    if _settings_ref == null:
        return true
    var expected = depends_on.get("equals", null)
    var current = _settings_ref.get_value(dep_key, null)
    return current == expected

func _on_export_current_tab() -> void:
    if _settings_ref == null or not _settings_ref.has_method("export_settings"):
        return
    if _get_current_tab_kind() != "schema":
        return
    var ns := get_current_tab_id()
    if ns == "":
        return
    var payload: String = _settings_ref.export_settings(ns)
    var content := VBoxContainer.new()
    var text_edit := TextEdit.new()
    text_edit.text = payload
    text_edit.editable = false
    text_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
    text_edit.custom_minimum_size = Vector2(520, 300)
    content.add_child(text_edit)
    var buttons: Array[Dictionary] = [
        {"text": "Copy", "callback": func(): DisplayServer.clipboard_set(payload), "close": false},
        {"text": "Close", "close": true}
    ]
    _show_popup("Export Settings", content, buttons)

func _on_import_current_tab() -> void:
    if _settings_ref == null or not _settings_ref.has_method("import_settings"):
        return
    if _get_current_tab_kind() != "schema":
        return
    var ns := get_current_tab_id()
    if ns == "":
        return
    var content := VBoxContainer.new()
    var hint := Label.new()
    hint.text = "Paste settings JSON to import into this tab."
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD
    content.add_child(hint)
    var input := TextEdit.new()
    input.custom_minimum_size = Vector2(520, 240)
    input.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content.add_child(input)
    var import_callback := func():
        _settings_ref.import_settings(ns, input.text)
        _filter_rows(_search_field.text if _search_field else "")
        _rebuild_restart_required_state()
    var buttons: Array[Dictionary] = [
        {"text": "Cancel", "close": true},
        {"text": "Import", "callback": import_callback, "close": true}
    ]
    _show_popup("Import Settings", content, buttons)

func _on_reset_current_tab() -> void:
    if _settings_ref == null or not _settings_ref.has_method("reset_namespace"):
        return
    if _get_current_tab_kind() != "schema":
        return
    var ns := get_current_tab_id()
    if ns == "":
        return
    _show_confirmation("Reset Settings", "Reset all settings in this tab to defaults?", func():
        _settings_ref.reset_namespace(ns, true)
        _filter_rows(_search_field.text if _search_field else "")
        _rebuild_restart_required_state()
    )

func _show_confirmation(title: String, message: String, on_confirm: Callable) -> void:
    var label := Label.new()
    label.text = message
    label.autowrap_mode = TextServer.AUTOWRAP_WORD
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var buttons: Array[Dictionary] = [
        {"text": "Cancel", "close": true},
        {"text": "OK", "callback": on_confirm, "close": true}
    ]
    _show_popup(title, label, buttons)

func _show_json_editor(key: String, value: Variant) -> void:
    if _settings_ref == null:
        return
    var content := VBoxContainer.new()
    var input := TextEdit.new()
    input.text = JSON.stringify(value, "\t")
    input.custom_minimum_size = Vector2(520, 260)
    input.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content.add_child(input)
    var schema_entry: Dictionary = _controls_by_key.get(key, {}).get("schema", {})
    var entry_type := str(schema_entry.get("type", ""))
    if entry_type == "" and schema_entry.has("default"):
        entry_type = _infer_schema_type(schema_entry.get("default"))
    var save_callback := func():
        var json := JSON.new()
        var result := json.parse(input.text)
        if result != OK:
            _show_confirmation("Invalid JSON", "Could not parse the JSON payload.", func(): pass )
            return
        var data = json.get_data()
        if entry_type == "dict" and not (data is Dictionary):
            _show_confirmation("Invalid Type", "Expected a JSON object for this setting.", func(): pass )
            return
        if entry_type == "array" and not (data is Array):
            _show_confirmation("Invalid Type", "Expected a JSON array for this setting.", func(): pass )
            return
        _settings_ref.set_value(key, data, true)
    var buttons: Array[Dictionary] = [
        {"text": "Cancel", "close": true},
        {"text": "Save", "callback": save_callback, "close": true}
    ]
    _show_popup("Edit JSON", content, buttons)

func _show_color_map_picker(setting_key: String, option_id: String, start_color: Color) -> void:
    if _settings_ref == null:
        return
    if _hud_node == null:
        return
    var base_dir = get_script().resource_path.get_base_dir()
    var panel_script = load(base_dir.path_join("color_picker_panel.gd"))
    if panel_script == null:
        _log_warn("Failed to load color picker panel.")
        return
    
    # Create overlay that covers the entire screen
    var overlay := CanvasLayer.new()
    overlay.layer = 100 # Above most UI
    _hud_node.get_tree().root.add_child(overlay)
    
    # Semi-transparent background to dim the rest of the screen
    var bg := ColorRect.new()
    bg.color = Color(0, 0, 0, 0.5)
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    bg.mouse_filter = Control.MOUSE_FILTER_STOP
    overlay.add_child(bg)
    
    # Center container for picker + button
    var center := CenterContainer.new()
    center.set_anchors_preset(Control.PRESET_FULL_RECT)
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    overlay.add_child(center)
    
    # VBox to hold picker and close button
    var vbox := VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 16)
    vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
    center.add_child(vbox)
    
    # Title label
    var title_label := Label.new()
    title_label.text = "Pick Color"
    title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title_label.add_theme_font_size_override("font_size", 28)
    title_label.add_theme_color_override("font_color", Color.WHITE)
    vbox.add_child(title_label)
    
    # Create the color picker panel
    var panel = panel_script.new()
    if panel.has_method("setup"):
        panel.call("setup", _settings_ref)
    if panel.has_method("set_color"):
        panel.call("set_color", start_color)
    vbox.add_child(panel)
    
    # Helper function to save current color and close
    var close_and_save := func():
        # Get the current color from the panel and save it
        if panel.has_method("get_color"):
            var current_color: Color = panel.call("get_color")
            _set_color_map_value(setting_key, option_id, current_color, true)
        overlay.queue_free()
    
    # Close button below the picker
    var close_btn := Button.new()
    close_btn.text = "Close"
    close_btn.custom_minimum_size = Vector2(120, 40)
    close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    close_btn.add_theme_font_size_override("font_size", 20)
    close_btn.pressed.connect(close_and_save)
    vbox.add_child(close_btn)
    
    # Also close when clicking the background
    bg.gui_input.connect(func(event: InputEvent):
        if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
            close_and_save.call()
    )

func _show_popup(title: String, content: Control, buttons: Array[Dictionary]) -> void:
    if _popup_provider != null and _popup_provider.is_valid():
        _popup_provider.call(title, content, buttons)
        return
    if _hud_node == null:
        return
    
    # Create a Window instead of AcceptDialog for better control
    var popup := Window.new()
    popup.title = title
    popup.transient = true
    popup.exclusive = true
    popup.wrap_controls = true
    popup.unresizable = false
    popup.close_requested.connect(func(): popup.queue_free())
    
    # Create a styled panel as background
    var panel := PanelContainer.new()
    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = Color(0.0862745, 0.101961, 0.137255, 1.0)
    panel_style.set_content_margin_all(16)
    panel.add_theme_stylebox_override("panel", panel_style)
    popup.add_child(panel)
    
    # Main container for content and buttons
    var container := VBoxContainer.new()
    container.add_theme_constant_override("separation", 12)
    panel.add_child(container)
    
    # Add content
    if content != null:
        content.size_flags_vertical = Control.SIZE_EXPAND_FILL
        container.add_child(content)
    
    # Add button row
    var btn_row := HBoxContainer.new()
    btn_row.alignment = BoxContainer.ALIGNMENT_END
    btn_row.add_theme_constant_override("separation", 10)
    container.add_child(btn_row)
    
    for entry in buttons:
        var btn := Button.new()
        btn.text = str(entry.get("text", "OK"))
        btn.focus_mode = Control.FOCUS_NONE
        btn.custom_minimum_size = Vector2(80, 36)
        var cb: Callable = entry.get("callback", Callable())
        var should_close: bool = bool(entry.get("close", true))
        btn.pressed.connect(func():
            if cb != null and cb.is_valid():
                cb.call()
            if should_close:
                popup.queue_free()
        )
        btn_row.add_child(btn)
    
    # Calculate size based on content
    var content_size := Vector2(560, 360)
    if content != null:
        content_size.x = max(content_size.x, content.custom_minimum_size.x + 64)
        content_size.y = max(content_size.y, content.custom_minimum_size.y + 100)
    popup.size = content_size
    
    # Make panel fill the window
    panel.set_anchors_preset(Control.PRESET_FULL_RECT)
    
    _hud_node.get_tree().root.add_child(popup)
    popup.popup_centered()

func _on_settings_value_changed(key: String, value: Variant, _old_value: Variant) -> void:
    if not _controls_by_key.has(key):
        _filter_rows(_search_field.text if _search_field else "")
        _update_restart_requirement_for_key(key)
        return
    var entry: Dictionary = _controls_by_key[key]
    var kind := str(entry.get("kind", ""))
    var control = entry.get("control", null)
    var badge = entry.get("badge", null)
    var value_label = entry.get("value_label", null)
    var entry_type := str(entry.get("entry_type", ""))

    _with_suppressed_event(key, func():
        match kind:
            "bool":
                if control and control is CheckButton:
                    control.set_pressed_no_signal(bool(value))
            "slider":
                if control and control is HSlider:
                    if control.has_method("set_value_no_signal"):
                        control.set_value_no_signal(float(value))
                    else:
                        control.value = float(value)
                    if value_label != null:
                        var display_value = int(value) if entry_type == "int" else value
                        value_label.text = _format_schema_value(display_value, entry_type)
            "numeric":
                if control and control is LineEdit:
                    control.text = str(value)
            "text":
                if control and control is LineEdit:
                    control.text = str(value)
            "dropdown":
                if control and control is OptionButton:
                    var options = entry.get("option_values", entry.get("options", []))
                    var selected_idx: int = options.find(value)
                    if selected_idx < 0:
                        selected_idx = 0
                    control.select(selected_idx)
            "color_map":
                var pickers: Dictionary = entry.get("pickers", {})
                var color_get: Callable = entry.get("color_get", Callable())
                var overrides: Dictionary = value if value is Dictionary else {}
                for option_id in pickers.keys():
                    var picker_entry: Dictionary = pickers.get(option_id, {})
                    var style: StyleBoxFlat = picker_entry.get("style", null)
                    var button: Button = picker_entry.get("button", null)
                    if style != null:
                        style.bg_color = _get_color_map_color(overrides, str(option_id), color_get)
                    if button != null and is_instance_valid(button):
                        button.queue_redraw()
            "json":
                pass
            _:
                pass
    )

    _update_changed_badge_for_key(key, badge)
    _update_restart_requirement_for_key(key)
    _filter_rows(_search_field.text if _search_field else "")

func _rebuild_restart_required_state() -> void:
    _restart_required_changed.clear()
    if _settings_ref == null:
        _restart_from_settings = false
        _update_restart_banner_state()
        return
    for key in _controls_by_key.keys():
        var entry: Dictionary = _controls_by_key[key]
        var schema_entry: Dictionary = entry.get("schema", {})
        if schema_entry.get("requires_restart", false):
            if _is_restart_pending_for_key(str(key)):
                _restart_required_changed[str(key)] = true
    _restart_from_settings = _restart_required_changed.size() > 0
    _update_restart_banner_state()

func _update_restart_requirement_for_key(key: String) -> void:
    if _settings_ref == null:
        return
    if not _controls_by_key.has(key):
        return
    var schema_entry: Dictionary = _controls_by_key[key].get("schema", {})
    if not schema_entry.get("requires_restart", false):
        return
    if _is_restart_pending_for_key(key):
        _restart_required_changed[key] = true
    else:
        _restart_required_changed.erase(key)
    _restart_from_settings = _restart_required_changed.size() > 0
    _update_restart_banner_state()

func _update_restart_banner_state() -> void:
    var should_show := _restart_from_external or _restart_from_settings
    if should_show and not _restart_pending:
        _restart_pending = true
        _create_restart_banner()
        _create_restart_indicator()
        _play_sound("menu_open")
    elif not should_show and _restart_pending:
        _restart_pending = false
        if _restart_banner and is_instance_valid(_restart_banner):
            _restart_banner.queue_free()
            _restart_banner = null
        if _restart_indicator and is_instance_valid(_restart_indicator):
            _restart_indicator.queue_free()
            _restart_indicator = null

func _refresh_filter_state() -> void:
    _filter_rows(_search_field.text if _search_field else "")

func _update_panel_layout() -> void:
    # This function is kept for backwards compatibility.
    # The panel now uses fixed offsets matching the game's native Menus container,
    # so it automatically scales with resolution through the HUD's scale system.
    # No dynamic width calculation is needed.
    pass
# --- Sidebar Collapse/Expand ---

func _on_sidebar_mouse_entered() -> void:
    _expand_sidebar()

func _on_sidebar_mouse_exited() -> void:
    _collapse_sidebar()

func _expand_sidebar() -> void:
    if _sidebar_expanded:
        return
    _sidebar_expanded = true

    if _sidebar_tween and _sidebar_tween.is_valid():
        _sidebar_tween.kill()

    _sidebar_tween = _sidebar.create_tween()
    _sidebar_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    _sidebar_tween.tween_property(_sidebar, "custom_minimum_size:x", SIDEBAR_WIDTH_EXPANDED, 0.2)

    for i in range(_tab_buttons.size()):
        var btn = _tab_buttons[i]
        if is_instance_valid(btn):
            var tab_name: String = btn.name.replace("Tab", "")
            if i < _tab_meta.size():
                tab_name = str(_tab_meta[i].get("display", tab_name))
            btn.text = "  " + tab_name
            btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
            btn.custom_minimum_size.x = SIDEBAR_WIDTH_EXPANDED

func _collapse_sidebar() -> void:
    if not _sidebar_expanded:
        return
    _sidebar_expanded = false

    if _sidebar_tween and _sidebar_tween.is_valid():
        _sidebar_tween.kill()

    _sidebar_tween = _sidebar.create_tween()
    _sidebar_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    _sidebar_tween.tween_property(_sidebar, "custom_minimum_size:x", SIDEBAR_WIDTH_COLLAPSED, 0.2)

    for btn in _tab_buttons:
        if is_instance_valid(btn):
            btn.text = ""
            btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
            btn.custom_minimum_size.x = SIDEBAR_WIDTH_COLLAPSED

# --- Restart Banner ---

func show_restart_banner() -> void:
    _restart_from_external = true
    _update_restart_banner_state()

func hide_restart_banner() -> void:
    _restart_from_external = false
    _update_restart_banner_state()

func is_restart_pending() -> bool:
    return _restart_pending

func _create_restart_banner() -> void:
    if _restart_banner and is_instance_valid(_restart_banner):
        return
    if not _main_vbox:
        return

    var banner = PanelContainer.new()
    banner.name = "RestartBanner"
    banner.custom_minimum_size = Vector2(0, 50)

    var style = StyleBoxFlat.new()
    style.bg_color = Color(0.85, 0.55, 0.15, 0.95)
    style.set_corner_radius_all(0)
    style.content_margin_left = 15
    style.content_margin_right = 15
    style.content_margin_top = 8
    style.content_margin_bottom = 8
    banner.add_theme_stylebox_override("panel", style)

    var hbox = HBoxContainer.new()
    hbox.add_theme_constant_override("separation", 10)
    banner.add_child(hbox)

    var icon = TextureRect.new()
    icon.custom_minimum_size = Vector2(28, 28)
    icon.texture = load("res://textures/icons/reload.png")
    icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    icon.self_modulate = Color(1, 1, 1)
    icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    hbox.add_child(icon)

    var label = Label.new()
    label.text = "Restart required for changes"
    label.add_theme_font_size_override("font_size", 22)
    label.add_theme_color_override("font_color", Color(1, 1, 1))
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    hbox.add_child(label)

    var dismiss_btn = Button.new()
    dismiss_btn.text = "Dismiss"
    dismiss_btn.custom_minimum_size = Vector2(90, 34)
    dismiss_btn.focus_mode = Control.FOCUS_NONE
    dismiss_btn.theme_type_variation = "TabButton"
    dismiss_btn.pressed.connect(func():
        _play_sound("menu_close")
        hide_restart_banner()
    )
    hbox.add_child(dismiss_btn)

    var exit_btn = Button.new()
    exit_btn.text = "Exit Now"
    exit_btn.custom_minimum_size = Vector2(90, 34)
    exit_btn.focus_mode = Control.FOCUS_NONE
    exit_btn.theme_type_variation = "TabButton"
    exit_btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.7))
    exit_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.9))
    exit_btn.pressed.connect(func():
        _hud_node.get_tree().quit()
    )
    hbox.add_child(exit_btn)

    _main_vbox.add_child(banner)
    _main_vbox.move_child(banner, 0)
    _restart_banner = banner

func _create_restart_indicator() -> void:
    if _restart_indicator and is_instance_valid(_restart_indicator):
        return
    if not settings_button or not is_instance_valid(settings_button):
        return

    var indicator = Panel.new()
    indicator.name = "RestartIndicator"
    indicator.custom_minimum_size = Vector2(14, 14)
    indicator.mouse_filter = Control.MOUSE_FILTER_PASS
    indicator.tooltip_text = "Restart required for some settings"

    var style = StyleBoxFlat.new()
    style.bg_color = Color(1.0, 0.6, 0.2, 1.0)
    style.set_corner_radius_all(7)
    style.border_width_left = 2
    style.border_width_top = 2
    style.border_width_right = 2
    style.border_width_bottom = 2
    style.border_color = Color(0.3, 0.2, 0.1, 1.0)
    indicator.add_theme_stylebox_override("panel", style)

    var btn_parent = settings_button.get_parent()
    if btn_parent:
        btn_parent.add_child(indicator)
        indicator.set_anchors_preset(Control.PRESET_TOP_LEFT)
        indicator.position = settings_button.position + Vector2(settings_button.size.x - 8, -3)
        settings_button.resized.connect(func():
            if is_instance_valid(indicator) and is_instance_valid(settings_button):
                indicator.position = settings_button.position + Vector2(settings_button.size.x - 8, -3)
        )

    _restart_indicator = indicator

func _emit_menu_close() -> void:
    var signals = _get_root_node("Signals")
    if signals != null and signals.has_signal("set_menu"):
        signals.emit_signal("set_menu", 0, 0)

func _play_sound(name: String) -> void:
    var sound = _get_root_node("Sound")
    if sound != null and sound.has_method("play"):
        sound.call("play", name)

func _get_root_node(name: String) -> Node:
    if Engine.get_main_loop():
        var root = Engine.get_main_loop().root
        if root and root.has_node(name):
            return root.get_node(name)
    return null

func _log_warn(message: String) -> void:
    if _has_global_class("ModLoaderLog"):
        ModLoaderLog.warning(message, LOG_NAME)
    else:
        print(LOG_NAME + ": " + message)


func _has_global_class(class_name_str: String) -> bool:
    for entry in ProjectSettings.get_global_class_list():
        if entry.get("class", "") == class_name_str:
            return true
    return false
