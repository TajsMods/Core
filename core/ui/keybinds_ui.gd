class_name TajsCoreKeybindsUI
extends RefCounted

const LOG_NAME: String = "TajemnikTV-Core:KeybindsUI"

var _manager: Variant
var _ui: Variant
var _container: VBoxContainer
var _rebind_overlay: CanvasLayer
var _rebind_action_id: String = ""
var _item_rows: Dictionary = {}

const COLOR_CONFLICT: Color = Color(1.0, 0.6, 0.4, 1.0)
const COLOR_MODULE: Color = Color(0.6, 0.8, 1.0, 1.0)
const COLOR_CATEGORY: Color = Color(0.8, 0.8, 0.8, 1.0)

func setup(manager: Variant, ui: Variant, container: VBoxContainer) -> void:
    _manager = manager
    _ui = ui
    _container = container
    @warning_ignore("unsafe_method_access")
    if _manager != null and _manager.has_signal("binding_changed"):
        @warning_ignore("unsafe_method_access")
        _manager.binding_changed.connect(_on_binding_changed)
    _build_ui()

func _build_ui() -> void:
    for child: Variant in _container.get_children():
        @warning_ignore("unsafe_method_access")
        child.queue_free()
    _item_rows.clear()

    if _manager == null:
        var label: Variant = Label.new()
        label.text = "Keybinds not available."
        @warning_ignore("unsafe_call_argument")
        _container.add_child(label)
        return

    @warning_ignore("unsafe_method_access")
    var conflicts: Variant = _manager.get_conflicts()
    var conflicting_ids: Array = []
    for conflict: Variant in conflicts:
        for action_id: Variant in conflict["actions"]:
            if action_id not in conflicting_ids:
                conflicting_ids.append(action_id)

    @warning_ignore("unsafe_method_access")
    var actions: Array = _manager.get_actions_for_ui()
    var grouped: Dictionary = {}
    for action: Variant in actions:
        @warning_ignore("unsafe_method_access")
        var module_id: Variant = action.get("module_id", "core")
        if not grouped.has(module_id):
            grouped[module_id] = []
        @warning_ignore("unsafe_method_access")
        grouped[module_id].append(action)

    var module_ids: Array = grouped.keys()
    @warning_ignore("unsafe_method_access")
    module_ids.sort()

    for module_id: Variant in module_ids:
        @warning_ignore("unsafe_call_argument")
        _add_category_header(str(module_id))
        var group_actions: Array = grouped[module_id]
        group_actions.sort_custom(func(a: Variant, b: Variant) -> bool:
            @warning_ignore("unsafe_method_access")
            return str(a.get("display_name", "")).naturalnocasecmp_to(str(b.get("display_name", ""))) < 0
        )
        for action: Variant in group_actions:
            @warning_ignore("unsafe_method_access")
            var action_id: String = action.get("id", "")
            var has_conflict: bool = action_id in conflicting_ids
            @warning_ignore("unsafe_cast")
            _add_action_row(action as Dictionary, has_conflict)

    _add_reset_all_button()

func _add_category_header(category: String) -> void:
    var header: Label = Label.new()
    header.text = category
    @warning_ignore("unsafe_method_access")
    header.add_theme_font_size_override("font_size", 26)
    @warning_ignore("unsafe_method_access")
    header.add_theme_color_override("font_color", COLOR_CATEGORY)

    var margin: MarginContainer = MarginContainer.new()
    @warning_ignore("unsafe_method_access")
    margin.add_theme_constant_override("margin_top", 15)
    @warning_ignore("unsafe_method_access")
    margin.add_theme_constant_override("margin_bottom", 5)
    margin.add_child(header)

    _container.add_child(margin)

func _add_action_row(action: Dictionary, has_conflict: bool) -> void:
    var row: HBoxContainer = HBoxContainer.new()
    @warning_ignore("unsafe_method_access")
    row.add_theme_constant_override("separation", 10)

    var name_label: Label = Label.new()
    @warning_ignore("unsafe_method_access")
    var display_name: String = str(action.get("display_name", action.get("id", "")))
    @warning_ignore("unsafe_method_access")
    var module_id: String = str(action.get("module_id", "core"))
    if module_id != "core":
        display_name = "(%s) %s" % [module_id, display_name]
        @warning_ignore("unsafe_method_access")
        name_label.add_theme_color_override("font_color", COLOR_MODULE)
    name_label.text = display_name
    name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    @warning_ignore("unsafe_method_access")
    name_label.add_theme_font_size_override("font_size", 22)
    row.add_child(name_label)

    var binding_label: Label = Label.new()
    @warning_ignore("unsafe_method_access")
    @warning_ignore("unsafe_cast")
    binding_label.text = _format_binding_display(action.get("id", "") as String)
    @warning_ignore("unsafe_method_access")
    binding_label.add_theme_font_size_override("font_size", 22)
    binding_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    binding_label.custom_minimum_size.x = 180

    if has_conflict:
        @warning_ignore("unsafe_method_access")
        binding_label.add_theme_color_override("font_color", COLOR_CONFLICT)
        binding_label.tooltip_text = "Conflicts with another keybind"

    row.add_child(binding_label)

    var rebind_btn: Button = Button.new()
    rebind_btn.text = "Rebind"
    @warning_ignore("unsafe_method_access")
    rebind_btn.add_theme_font_size_override("font_size", 16)
    rebind_btn.custom_minimum_size.x = 70
    @warning_ignore("unsafe_method_access")
    @warning_ignore("unsafe_cast")
    @warning_ignore("return_value_discarded")
    rebind_btn.pressed.connect(_on_rebind_pressed.bind(action.get("id", "") as String))
    row.add_child(rebind_btn)

    var reset_btn: Button = Button.new()
    reset_btn.text = "Reset"
    reset_btn.tooltip_text = "Reset to default"
    reset_btn.custom_minimum_size.x = 60
    @warning_ignore("unsafe_method_access")
    @warning_ignore("unsafe_cast")
    @warning_ignore("return_value_discarded")
    reset_btn.pressed.connect(_on_reset_pressed.bind(action.get("id", "") as String))
    row.add_child(reset_btn)

    _container.add_child(row)

    @warning_ignore("unsafe_method_access")
    _item_rows[action.get("id", "")] = {
        "row": row,
        "binding_label": binding_label
    }

func _add_reset_all_button() -> void:
    var spacer: MarginContainer = MarginContainer.new()
    @warning_ignore("unsafe_method_access")
    spacer.add_theme_constant_override("margin_top", 20)

    var btn: Button = Button.new()
    btn.text = "Reset All Keybinds"
    @warning_ignore("return_value_discarded")
    btn.pressed.connect(_on_reset_all_pressed)
    spacer.add_child(btn)

    _container.add_child(spacer)

func _on_rebind_pressed(action_id: String) -> void:
    _rebind_action_id = action_id
    _show_rebind_overlay()

func _on_reset_pressed(action_id: String) -> void:
    @warning_ignore("unsafe_method_access")
    _manager.reset_to_default(action_id)
    _update_binding_label(action_id)
    _play_sound("click")

func _on_reset_all_pressed() -> void:
    @warning_ignore("unsafe_method_access")
    if _manager.has_method("reset_all_to_default"):
        @warning_ignore("unsafe_method_access")
        _manager.reset_all_to_default()
    _build_ui()
    _play_sound("click")
    _notify("check", "All keybinds reset to defaults")

func _on_binding_changed(action_id: String, _shortcuts: Array) -> void:
    _update_binding_label(action_id)
    _refresh_conflicts()

func _refresh_conflicts() -> void:
    if _manager == null:
        return
    @warning_ignore("unsafe_method_access")
    var conflicts: Variant = _manager.get_conflicts()
    var conflicting_ids: Array = []
    for conflict: Variant in conflicts:
        @warning_ignore("unsafe_method_access")
        for conflict_id: Variant in conflict["actions"]:
            if conflict_id not in conflicting_ids:
                conflicting_ids.append(conflict_id)
    for action_id: Variant in _item_rows.keys():
        var item: Variant = _item_rows[action_id]
        if conflicting_ids.has(action_id):
            @warning_ignore("unsafe_method_access")
            item.binding_label.add_theme_color_override("font_color", COLOR_CONFLICT)
            @warning_ignore("unsafe_method_access")
            item.binding_label.tooltip_text = "Conflicts with another keybind"
        else:
            @warning_ignore("unsafe_method_access")
            item.binding_label.remove_theme_color_override("font_color")
            @warning_ignore("unsafe_method_access")
            item.binding_label.tooltip_text = ""

func _update_binding_label(action_id: String) -> void:
    if _item_rows.has(action_id):
        var item: Variant = _item_rows[action_id]
        @warning_ignore("unsafe_method_access")
        item.binding_label.text = _format_binding_display(action_id)

func _format_binding_display(action_id: String) -> String:
    var bindings: Array = []
    if _manager != null:
        @warning_ignore("unsafe_method_access")
        bindings = _manager.get_binding(action_id)
    if bindings.is_empty():
        return "Unbound"
    var parts: Array = []
    for binding: Variant in bindings:
        if binding is InputEvent:
            @warning_ignore("unsafe_method_access")
            parts.append(binding.as_text())
    return ", ".join(parts)

func _show_rebind_overlay() -> void:
    if _rebind_overlay and is_instance_valid(_rebind_overlay):
        return

    var root: Node = _container.get_tree().root

    var canvas: CanvasLayer = CanvasLayer.new()
    canvas.layer = 200
    canvas.name = "CoreKeybindRebindLayer"

    var bg: ColorRect = ColorRect.new()
    bg.color = Color(0, 0, 0, 0.8)
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

    var center: CenterContainer = CenterContainer.new()
    center.set_anchors_preset(Control.PRESET_FULL_RECT)
    center.mouse_filter = Control.MOUSE_FILTER_STOP
    center.focus_mode = Control.FOCUS_ALL

    _rebind_overlay = canvas

    var panel: PanelContainer = PanelContainer.new()
    panel.custom_minimum_size = Vector2(420, 220)

    var vbox: VBoxContainer = VBoxContainer.new()
    @warning_ignore("unsafe_method_access")
    vbox.add_theme_constant_override("separation", 20)
    vbox.alignment = BoxContainer.ALIGNMENT_CENTER

    var title: Label = Label.new()
    title.text = "Press any key..."
    @warning_ignore("unsafe_method_access")
    title.add_theme_font_size_override("font_size", 28)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(title)

    var subtitle: Label = Label.new()
    subtitle.text = "Rebinding: %s" % _rebind_action_id
    @warning_ignore("unsafe_method_access")
    subtitle.add_theme_font_size_override("font_size", 18)
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    @warning_ignore("unsafe_method_access")
    subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
    vbox.add_child(subtitle)

    var cancel_btn: Button = Button.new()
    cancel_btn.text = "Cancel (Escape)"
    @warning_ignore("return_value_discarded")
    cancel_btn.pressed.connect(_hide_rebind_overlay)
    cancel_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    vbox.add_child(cancel_btn)

    panel.add_child(vbox)
    center.add_child(panel)

    canvas.add_child(bg)
    canvas.add_child(center)

    @warning_ignore("return_value_discarded")
    center.gui_input.connect(_on_rebind_input)

    @warning_ignore("unsafe_method_access")
    root.add_child(canvas)
    center.grab_focus()

func _hide_rebind_overlay() -> void:
    if _rebind_overlay and is_instance_valid(_rebind_overlay):
        _rebind_overlay.queue_free()
        _rebind_overlay = null
    _rebind_action_id = ""

func _on_rebind_input(event: InputEvent) -> void:
    if event is InputEventKey and event.get("pressed"):
        if event.get("keycode") == KEY_ESCAPE:
            _hide_rebind_overlay()
            return
        if event.get("keycode") in [KEY_CTRL, KEY_ALT, KEY_SHIFT, KEY_META]:
            return
        @warning_ignore("unsafe_method_access")
        _manager.set_binding(_rebind_action_id, [event])
        _update_binding_label(_rebind_action_id)
        _hide_rebind_overlay()
        _play_sound("click")
        @warning_ignore("unsafe_method_access")
        _notify("check", "Rebound to: %s" % event.as_text())
    elif event is InputEventMouseButton and event.get("pressed"):
        if event.get("button_index") == MOUSE_BUTTON_LEFT:
            return
        @warning_ignore("unsafe_method_access")
        _manager.set_binding(_rebind_action_id, [event])
        _update_binding_label(_rebind_action_id)
        _hide_rebind_overlay()
        _play_sound("click")
        @warning_ignore("unsafe_method_access")
        _notify("check", "Rebound to: %s" % event.as_text())

func _notify(icon: String, message: String) -> void:
    @warning_ignore("unsafe_method_access")
    var signals: Variant = _get_root_node("Signals")
    @warning_ignore("unsafe_method_access")
    if signals != null and signals.has_signal("notify"):
        @warning_ignore("unsafe_method_access")
        var _ignored: Variant = signals.emit_signal("notify", icon, message)
        return
    _log_info(message)

func _play_sound(name: String) -> void:
    @warning_ignore("unsafe_method_access")
    var sound: Variant = _get_root_node("Sound")
    @warning_ignore("unsafe_method_access")
    if sound != null and sound.has_method("play"):
        @warning_ignore("unsafe_method_access")
        sound.call("play", name)

func _get_root_node(name: String) -> Node:
    if Engine.get_main_loop():
        @warning_ignore("unsafe_property_access")
        var root: Variant = Engine.get_main_loop().root
        if root:
            @warning_ignore("unsafe_method_access")
            if root.has_node(name):
                @warning_ignore("unsafe_method_access")
                return root.get_node(name)
    return null

func _log_info(message: String) -> void:
    if _has_global_class("ModLoaderLog"):
        ModLoaderLog.info(message, LOG_NAME)
    else:
        print(LOG_NAME + ": " + message)


func _has_global_class(class_name_str: String) -> bool:
    for entry: Variant in ProjectSettings.get_global_class_list():
        @warning_ignore("unsafe_method_access")
        if entry.get("class", "") == class_name_str:
            return true
    return false
