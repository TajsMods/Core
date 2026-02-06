class_name TajsCorePopupManager
extends Node

var _hud: Node
var _root: Control
var _current_popup: Control

func setup(hud: Node) -> void:
    _hud = hud
    _create_root()

func show_popup(title: String, content: Control, buttons: Array[Dictionary]) -> void:
    _close_current()
    if _root == null:
        return
    var overlay := _build_overlay()
    var center := CenterContainer.new()
    center.set_anchors_preset(Control.PRESET_FULL_RECT)
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var panel := _build_panel(title, content, buttons)
    panel.pivot_offset = panel.custom_minimum_size * 0.5
    panel.modulate.a = 0.0
    panel.scale = Vector2(0.94, 0.94)
    center.add_child(panel)
    overlay.add_child(center)
    _current_popup = overlay
    _root.add_child(overlay)

    var tween := panel.create_tween()
    tween.set_trans(Tween.TRANS_QUAD)
    tween.set_parallel()
    tween.tween_property(panel, "modulate:a", 1.0, 0.14)
    tween.tween_property(panel, "scale", Vector2.ONE, 0.16)

func show_confirmation(title: String, message: String, on_confirm: Callable, on_cancel: Callable = Callable()) -> void:
    var label := Label.new()
    label.text = message
    label.autowrap_mode = TextServer.AUTOWRAP_WORD
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var buttons: Array[Dictionary] = [
        {"text": "Cancel", "callback": on_cancel, "close": true},
        {"text": "OK", "callback": on_confirm, "close": true}
    ]
    show_popup(title, label, buttons)

func show_input_dialog(title: String, prompt: String, default_text: String, on_submit: Callable) -> void:
    var container := VBoxContainer.new()
    var label := Label.new()
    label.text = prompt
    label.autowrap_mode = TextServer.AUTOWRAP_WORD
    container.add_child(label)
    var input := LineEdit.new()
    input.text = default_text
    container.add_child(input)
    var buttons: Array[Dictionary] = [
        {"text": "Cancel", "callback": Callable(), "close": true},
        {"text": "Submit", "callback": func(): on_submit.call(input.text), "close": true}
    ]
    show_popup(title, container, buttons)

func show_checkbox_confirmation(
    title: String,
    message: String,
    checkbox_text: String,
    on_confirm: Callable,
    on_cancel: Callable = Callable(),
    confirm_text: String = "Confirm",
    cancel_text: String = "Cancel",
    helper_text: String = ""
) -> void:
    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 12)
    content.alignment = BoxContainer.ALIGNMENT_CENTER

    var message_label := Label.new()
    message_label.text = message
    message_label.autowrap_mode = TextServer.AUTOWRAP_WORD
    message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    message_label.custom_minimum_size = Vector2(0, 88)
    content.add_child(message_label)

    var check := CheckBox.new()
    check.text = checkbox_text
    check.add_theme_font_size_override("font_size", 17)
    content.add_child(check)

    if helper_text != "":
        var helper_label := Label.new()
        helper_label.text = helper_text
        helper_label.autowrap_mode = TextServer.AUTOWRAP_WORD
        helper_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        helper_label.add_theme_font_size_override("font_size", 15)
        helper_label.add_theme_color_override("font_color", Color(0.68, 0.74, 0.82, 1.0))
        content.add_child(helper_label)

    var confirm_callback := func():
        if not check.button_pressed:
            return
        if on_confirm != null and on_confirm.is_valid():
            on_confirm.call()
        _close_current()

    var buttons: Array[Dictionary] = [
        {"text": cancel_text, "callback": on_cancel, "close": true},
        {"text": confirm_text, "callback": confirm_callback, "close": false}
    ]
    show_popup(title, content, buttons)

func close_popup() -> void:
    _close_current()

func _create_root() -> void:
    if _hud == null:
        return
    var overlay: Variant = _hud.get_node_or_null("Main/MainContainer/Overlay")
    if overlay == null:
        return
    if overlay.has_node("TajsCorePopups"):
        _root = overlay.get_node("TajsCorePopups")
        return
    _root = Control.new()
    _root.name = "TajsCorePopups"
    _root.set_anchors_preset(Control.PRESET_FULL_RECT)
    _root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    overlay.add_child(_root)

func _build_overlay() -> Control:
    var overlay := Control.new()
    overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
    overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    var dim := ColorRect.new()
    dim.color = Color(0, 0, 0, 0.364)
    dim.set_anchors_preset(Control.PRESET_FULL_RECT)
    dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    overlay.add_child(dim)
    return overlay

func _build_panel(title: String, content: Control, buttons: Array[Dictionary]) -> Control:
    var panel := PanelContainer.new()
    panel.theme_type_variation = "ShadowPanelContainer"
    panel.custom_minimum_size = Vector2(618, 0)
    panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER

    var vbox := VBoxContainer.new()
    vbox.add_theme_constant_override("separation", -1)
    panel.add_child(vbox)

    var title_panel := Panel.new()
    title_panel.custom_minimum_size = Vector2(0, 80)
    title_panel.theme_type_variation = "TitlePanel"
    vbox.add_child(title_panel)

    var title_label := Label.new()
    title_label.text = title
    title_label.set_anchors_preset(Control.PRESET_FULL_RECT)
    title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    title_label.add_theme_font_size_override("font_size", 40)
    title_panel.add_child(title_label)

    var main_panel := PanelContainer.new()
    main_panel.custom_minimum_size = Vector2(0, 200)
    main_panel.theme_type_variation = "WindowPanelContainerFlatBottom"
    vbox.add_child(main_panel)

    var content_margin := MarginContainer.new()
    content_margin.add_theme_constant_override("margin_left", 20)
    content_margin.add_theme_constant_override("margin_top", 16)
    content_margin.add_theme_constant_override("margin_right", 20)
    content_margin.add_theme_constant_override("margin_bottom", 16)
    main_panel.add_child(content_margin)

    if content != null:
        content_margin.add_child(content)

    if not buttons.is_empty():
        var btn_row := HBoxContainer.new()
        btn_row.add_theme_constant_override("separation", 0)
        vbox.add_child(btn_row)

        for entry: Variant in buttons:
            var index := btn_row.get_child_count()
            if index > 0:
                var separator := ColorRect.new()
                separator.custom_minimum_size = Vector2(2, 0)
                separator.color = Color(0.101961, 0.12549, 0.172549, 1)
                btn_row.add_child(separator)

            var btn := Button.new()
            btn.text = str(entry.get("text", "OK"))
            btn.custom_minimum_size = Vector2(0, 80)
            btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            btn.focus_mode = Control.FOCUS_NONE
            var default_theme := "WindowButtonBottom1" if index == 0 else "WindowButtonBottom3"
            btn.theme_type_variation = str(entry.get("theme", default_theme))
            if entry.has("font_size"):
                btn.add_theme_font_size_override("font_size", int(entry.get("font_size", 16)))
            var cb: Callable = entry.get("callback", Callable())
            var should_close: bool = bool(entry.get("close", true))
            btn.disabled = bool(entry.get("disabled", false))
            btn.pressed.connect(func():
                if cb != null and cb.is_valid():
                    cb.call()
                if should_close:
                    _close_current()
            )
            btn_row.add_child(btn)

    return panel

func _close_current() -> void:
    if _current_popup and is_instance_valid(_current_popup):
        _current_popup.queue_free()
    _current_popup = null
