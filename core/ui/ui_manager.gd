# =============================================================================
# Taj's Core - UI Manager
# Author: TajemnikTV
# Description: Attaches Core settings UI to the HUD
# =============================================================================
class_name TajsCoreUiManager
extends Node

const LOG_NAME := "TajemnikTV-Core:UIManager"

var _core
var _workshop_sync
var _ui
var _settings_menu
var _hud_injector
var _popup_manager
var _mod_tabs: Dictionary = {} # mod_id -> VBoxContainer
var _pending_mod_tabs: Dictionary = {} # mod_id -> {name, icon}

func setup(core, workshop_sync) -> void:
    _core = core
    _workshop_sync = workshop_sync

func _ready() -> void:
    set_process_input(true)
    get_tree().node_added.connect(_on_node_added)
    call_deferred("_check_existing_main")

func _check_existing_main() -> void:
    var main = get_tree().root.get_node_or_null("Main")
    if main:
        _setup_for_main(main)

func _on_node_added(node: Node) -> void:
    if node.name == "Main" and node.get_parent().name == "root":
        call_deferred("_setup_for_main", node)

func _setup_for_main(main_node: Node) -> void:
    var hud = main_node.get_node_or_null("HUD")
    if hud == null:
        return

    var overlay = hud.get_node_or_null("Main/MainContainer/Overlay")
    if overlay and overlay.has_node("TajsCoreMenus"):
        return

    var base_dir = get_script().resource_path.get_base_dir()
    var ui_script = load(base_dir.path_join("settings_ui.gd"))
    if ui_script == null:
        _log_warn("Failed to load settings UI script.")
        return

    _ui = ui_script.new(hud, _core.get_version() if _core != null else "")
    _ui.add_mod_button(func(): _ui.set_visible(!_ui.is_visible()))
    if _core != null:
        _ui.set_settings(_core.settings)

    var menu_script = load(base_dir.path_join("settings_menu.gd"))
    if menu_script == null:
        _log_warn("Failed to load settings menu script.")
        return

    _settings_menu = menu_script.new()
    _settings_menu.setup(_core, _ui, _workshop_sync)
    _settings_menu.build_settings_menu()

    if _workshop_sync:
        _workshop_sync.set_restart_callback(Callable(_ui, "show_restart_banner"))

    _setup_hud_services(hud)
    _emit_hud_ready()

func _setup_hud_services(hud: Node) -> void:
    var base_dir = get_script().resource_path.get_base_dir()
    var injector_script = load(base_dir.path_join("hud_injector.gd"))
    if injector_script != null:
        _hud_injector = injector_script.new()
        _hud_injector.name = "CoreHudInjector"
        _hud_injector.setup(hud)
        add_child(_hud_injector)
    var popup_script = load(base_dir.path_join("popup_manager.gd"))
    if popup_script != null:
        _popup_manager = popup_script.new()
        _popup_manager.name = "CorePopupManager"
        _popup_manager.setup(hud)
        add_child(_popup_manager)
        if _ui != null:
            _ui.set_popup_provider(Callable(_popup_manager, "show_popup"))

func add_settings_tab(title: String, icon: String) -> VBoxContainer:
    if _ui == null:
        return null
    return _ui.add_tab(title, icon)

func register_mod_settings_tab(mod_id: String, display_name: String, icon_path: String = "") -> VBoxContainer:
    """
    Registers a settings tab for a mod. Returns the VBoxContainer to add settings widgets to.
    
    Parameters:
    - mod_id: The unique mod identifier (e.g., "TajemnikTV-CommandPalette")
    - display_name: Human-readable name shown in the tab (e.g., "Command Palette")
    - icon_path: Optional path to tab icon. Defaults to puzzle icon if empty.
    
    Returns: VBoxContainer to add settings widgets, or null if UI not ready.
    """
    if _mod_tabs.has(mod_id):
        var cached_tab = _mod_tabs[mod_id]
        if is_instance_valid(cached_tab):
            return cached_tab
        else:
            # Tab was freed (e.g., on reload), remove stale reference
            _mod_tabs.erase(mod_id)
    if _ui == null:
        _pending_mod_tabs[mod_id] = {"name": display_name, "icon": icon_path}
        return null
    var effective_name := display_name
    var effective_icon := icon_path
    if _pending_mod_tabs.has(mod_id):
        var entry: Dictionary = _pending_mod_tabs[mod_id]
        effective_name = entry.get("name", display_name)
        effective_icon = entry.get("icon", icon_path)
        _pending_mod_tabs.erase(mod_id)
    var container = _ui.add_mod_tab_ex(effective_name, effective_icon, mod_id, "manual")
    if container != null:
        _mod_tabs[mod_id] = container
    return container

func get_mod_settings_tab(mod_id: String) -> VBoxContainer:
    # Returns the existing settings tab container for a mod, or null if not registered.
    return _mod_tabs.get(mod_id, null)

func has_mod_settings_tab(mod_id: String) -> bool:
    # Returns true if the mod has already registered a settings tab.
    return _mod_tabs.has(mod_id) or _pending_mod_tabs.has(mod_id)

func add_toggle(container: Control, label: String, value: bool, callback: Callable, tooltip: String = "") -> CheckButton:
    if _ui == null:
        return null
    return _ui.add_toggle(container, label, value, callback, tooltip)

func add_slider(container: Control, label: String, value: float, min_val: float, max_val: float, step: float, suffix: String, callback: Callable) -> HSlider:
    if _ui == null:
        return null
    return _ui.add_slider(container, label, value, min_val, max_val, step, suffix, callback)

func add_dropdown(container: Control, label: String, options: Array, selected: int, callback: Callable) -> OptionButton:
    if _ui == null:
        return null
    return _ui.add_dropdown(container, label, options, selected, callback)

func add_button(container: Control, label: String, callback: Callable) -> Button:
    if _ui == null:
        return null
    return _ui.add_button(container, label, callback)

func add_text_input(container: Control, label: String, value: String, callback: Callable) -> LineEdit:
    if _ui == null:
        return null
    return _ui.add_text_input(container, label, value, callback)

func add_color_picker(container: Control, label: String, value: Color, callback: Callable) -> ColorPickerButton:
    if _ui == null:
        return null
    return _ui.add_color_picker(container, label, value, callback)

func add_separator(container: Control) -> HSeparator:
    if _ui == null:
        return null
    return _ui.add_separator(container)

func add_section_header(container: Control, title: String) -> Label:
    if _ui == null:
        return null
    return _ui.add_section_header(container, title)

func add_collapsible_section(container: Control, title: String, expanded: bool = false) -> VBoxContainer:
    if _ui == null:
        return null
    return _ui.add_collapsible_section(container, title, expanded)

func inject_hud_widget(zone: int, widget: Control, priority: int = 0) -> void:
    if _hud_injector == null:
        return
    _hud_injector.inject_widget(zone, widget, priority)

func remove_hud_widget(widget: Control) -> void:
    if _hud_injector == null:
        return
    _hud_injector.remove_widget(widget)

func get_hud_zone(zone: int) -> Control:
    if _hud_injector == null:
        return null
    return _hud_injector.get_zone_container(zone)

func show_popup(title: String, content: Control, buttons: Array[Dictionary]) -> void:
    if _popup_manager == null:
        return
    _popup_manager.show_popup(title, content, buttons)

func show_confirmation(title: String, message: String, on_confirm: Callable, on_cancel: Callable = Callable()) -> void:
    if _popup_manager == null:
        return
    _popup_manager.show_confirmation(title, message, on_confirm, on_cancel)

func show_input_dialog(title: String, prompt: String, default_text: String, on_submit: Callable) -> void:
    if _popup_manager == null:
        return
    _popup_manager.show_input_dialog(title, prompt, default_text, on_submit)

func close_popup() -> void:
    if _popup_manager == null:
        return
    _popup_manager.close_popup()

func open_icon_browser(callback: Callable, initial_selection: String = "") -> void:
    if _popup_manager == null:
        return
    var icon_script = load(get_script().resource_path.get_base_dir().path_join("icon_browser.gd"))
    if icon_script == null:
        return
    var browser = icon_script.new()
    var container := VBoxContainer.new()
    browser.icon_selected.connect(func(name: String, path: String):
        if callback != null and callback.is_valid():
            callback.call(name, path)
        close_popup()
    )
    browser.build_ui(container)
    if initial_selection != "":
        browser.set_selected_icon(initial_selection)
    show_popup("Select Icon", container, [ {"text": "Close", "close": true}])

func create_button(text: String, callback: Callable) -> Button:
    var btn := Button.new()
    btn.text = text
    btn.focus_mode = Control.FOCUS_NONE
    if callback != null and callback.is_valid():
        btn.pressed.connect(callback)
    return btn

func create_slider(label: String, value: float, min_val: float, max_val: float, callback: Callable) -> HSlider:
    var slider := HSlider.new()
    slider.min_value = min_val
    slider.max_value = max_val
    slider.value = value
    slider.tooltip_text = label
    slider.focus_mode = Control.FOCUS_NONE
    if callback != null and callback.is_valid():
        slider.value_changed.connect(callback)
    return slider

func create_toggle(label: String, value: bool, callback: Callable) -> CheckButton:
    var toggle := CheckButton.new()
    toggle.button_pressed = value
    toggle.text = label
    toggle.focus_mode = Control.FOCUS_NONE
    if callback != null and callback.is_valid():
        toggle.toggled.connect(callback)
    return toggle

func register_mod_settings_button(mod_id: String, icon: String, callback: Callable) -> void:
    var extras_container = _get_extras_container()
    if extras_container == null:
        return
    if extras_container.has_node(mod_id):
        return
    var button := Button.new()
    button.name = mod_id
    button.custom_minimum_size = Vector2(80, 80)
    button.focus_mode = Control.FOCUS_NONE
    button.theme_type_variation = "ButtonMenu"
    button.toggle_mode = true
    button.icon = load(icon)
    button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
    button.expand_icon = true
    if callback != null and callback.is_valid():
        button.pressed.connect(callback)
    extras_container.add_child(button)

func show_notification(icon: String, message: String) -> void:
    var signals = _get_root_node("Signals")
    if signals != null and signals.has_signal("notify"):
        signals.emit_signal("notify", icon, message)

func show_toast(message: String, duration: float = 2.0) -> void:
    show_notification("info", message)

func _get_extras_container() -> Node:
    if Engine.get_main_loop() == null:
        return null
    var root = Engine.get_main_loop().root
    if root == null:
        return null
    return root.get_node_or_null("Main/HUD/Main/MainContainer/Overlay/ExtrasButtons/Container")

func _get_root_node(name: String) -> Node:
    if Engine.get_main_loop():
        var root = Engine.get_main_loop().root
        if root and root.has_node(name):
            return root.get_node(name)
    return null

func _emit_hud_ready() -> void:
    if _core == null or _core.event_bus == null:
        return
    if _core.event_bus.has_method("emit_event"):
        _core.event_bus.emit_event("game.hud_ready", "core", {})
    elif _core.event_bus.has_method("emit"):
        _core.event_bus.emit("game.hud_ready", {"source": "core", "timestamp": Time.get_unix_time_from_system(), "data": {}})

func _input(event: InputEvent) -> void:
    if _ui == null or not _ui.is_visible():
        return
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        var mouse_pos := get_viewport().get_mouse_position()
        var panel_rect: Rect2 = _ui.settings_panel.get_global_rect() if _ui.settings_panel else Rect2()
        var btn_rect: Rect2 = _ui.settings_button.get_global_rect() if _ui.settings_button else Rect2()
        if not panel_rect.has_point(mouse_pos) and not btn_rect.has_point(mouse_pos):
            _ui.set_visible(false)

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
