# ==============================================================================
# Taj's Core - Popup Manager
# Author: TajemnikTV
# Description: Simple modal popup system for mods.
# ==============================================================================
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
	var panel := _build_panel(title, content, buttons)
	overlay.add_child(panel)
	_current_popup = overlay
	_root.add_child(overlay)

func show_confirmation(title: String, message: String, on_confirm: Callable, on_cancel: Callable = Callable()) -> void:
	var label := Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var buttons := [
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
	var buttons := [
		{"text": "Cancel", "callback": Callable(), "close": true},
		{"text": "Submit", "callback": func(): on_submit.call(input.text), "close": true}
	]
	show_popup(title, container, buttons)

func close_popup() -> void:
	_close_current()

func _create_root() -> void:
	if _hud == null:
		return
	var overlay = _hud.get_node_or_null("Main/MainContainer/Overlay")
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
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.5)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	return overlay

func _build_panel(title: String, content: Control, buttons: Array[Dictionary]) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 180) # Reduced from 420x200
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2.ZERO

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 20) # Reduced from 26
	vbox.add_child(title_label)

	if content != null:
		vbox.add_child(content)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	btn_row.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_row)

	for entry in buttons:
		var btn := Button.new()
		btn.text = str(entry.get("text", "OK"))
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 14) # Smaller buttons
		var cb: Callable = entry.get("callback", Callable())
		var should_close: bool = bool(entry.get("close", true))
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
