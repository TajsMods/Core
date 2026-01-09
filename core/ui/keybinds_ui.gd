# =============================================================================
# Taj's Core - Keybinds UI
# Author: TajemnikTV
# Description: Settings panel for viewing and rebinding keybinds
# =============================================================================
class_name TajsCoreKeybindsUI
extends RefCounted

const LOG_NAME := "TajemnikTV-Core:KeybindsUI"

var _manager
var _ui
var _container: VBoxContainer
var _rebind_overlay: CanvasLayer
var _rebind_action_id: String = ""
var _item_rows: Dictionary = {}

const COLOR_CONFLICT := Color(1.0, 0.6, 0.4, 1.0)
const COLOR_MODULE := Color(0.6, 0.8, 1.0, 1.0)
const COLOR_CATEGORY := Color(0.8, 0.8, 0.8, 1.0)

func setup(manager, ui, container: VBoxContainer) -> void:
	_manager = manager
	_ui = ui
	_container = container
	if _manager != null and _manager.has_signal("binding_changed"):
		_manager.binding_changed.connect(_on_binding_changed)
	_build_ui()

func _build_ui() -> void:
	for child in _container.get_children():
		child.queue_free()
	_item_rows.clear()

	if _manager == null:
		var label = Label.new()
		label.text = "Keybinds not available."
		_container.add_child(label)
		return

	var conflicts = _manager.get_conflicts()
	var conflicting_ids: Array = []
	for conflict in conflicts:
		for action_id in conflict["actions"]:
			if action_id not in conflicting_ids:
				conflicting_ids.append(action_id)

	var actions: Array = _manager.get_actions_for_ui()
	var grouped := {}
	for action in actions:
		var module_id = action.get("module_id", "core")
		if not grouped.has(module_id):
			grouped[module_id] = []
		grouped[module_id].append(action)

	var module_ids = grouped.keys()
	module_ids.sort()

	for module_id in module_ids:
		_add_category_header(module_id)
		var group_actions: Array = grouped[module_id]
		group_actions.sort_custom(func(a, b):
			return str(a.get("display_name", "")).naturalnocasecmp_to(str(b.get("display_name", ""))) < 0
		)
		for action in group_actions:
			var action_id: String = action.get("id", "")
			var has_conflict = action_id in conflicting_ids
			_add_action_row(action, has_conflict)

	_add_reset_all_button()

func _add_category_header(category: String) -> void:
	var header = Label.new()
	header.text = category
	header.add_theme_font_size_override("font_size", 26)
	header.add_theme_color_override("font_color", COLOR_CATEGORY)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 5)
	margin.add_child(header)

	_container.add_child(margin)

func _add_action_row(action: Dictionary, has_conflict: bool) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var name_label = Label.new()
	var display_name = str(action.get("display_name", action.get("id", "")))
	var module_id = str(action.get("module_id", "core"))
	if module_id != "core":
		display_name = "(%s) %s" % [module_id, display_name]
		name_label.add_theme_color_override("font_color", COLOR_MODULE)
	name_label.text = display_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 22)
	row.add_child(name_label)

	var binding_label = Label.new()
	binding_label.text = _format_binding_display(action.get("id", ""))
	binding_label.add_theme_font_size_override("font_size", 22)
	binding_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	binding_label.custom_minimum_size.x = 180

	if has_conflict:
		binding_label.add_theme_color_override("font_color", COLOR_CONFLICT)
		binding_label.tooltip_text = "Conflicts with another keybind"

	row.add_child(binding_label)

	var rebind_btn = Button.new()
	rebind_btn.text = "Rebind"
	rebind_btn.add_theme_font_size_override("font_size", 16)
	rebind_btn.custom_minimum_size.x = 70
	rebind_btn.pressed.connect(_on_rebind_pressed.bind(action.get("id", "")))
	row.add_child(rebind_btn)

	var reset_btn = Button.new()
	reset_btn.text = "Reset"
	reset_btn.tooltip_text = "Reset to default"
	reset_btn.custom_minimum_size.x = 60
	reset_btn.pressed.connect(_on_reset_pressed.bind(action.get("id", "")))
	row.add_child(reset_btn)

	_container.add_child(row)

	_item_rows[action.get("id", "")] = {
		"row": row,
		"binding_label": binding_label
	}

func _add_reset_all_button() -> void:
	var spacer = MarginContainer.new()
	spacer.add_theme_constant_override("margin_top", 20)

	var btn = Button.new()
	btn.text = "Reset All Keybinds"
	btn.pressed.connect(_on_reset_all_pressed)
	spacer.add_child(btn)

	_container.add_child(spacer)

func _on_rebind_pressed(action_id: String) -> void:
	_rebind_action_id = action_id
	_show_rebind_overlay()

func _on_reset_pressed(action_id: String) -> void:
	_manager.reset_to_default(action_id)
	_update_binding_label(action_id)
	_play_sound("click")

func _on_reset_all_pressed() -> void:
	if _manager.has_method("reset_all_to_default"):
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
	var conflicts = _manager.get_conflicts()
	var conflicting_ids: Array = []
	for conflict in conflicts:
		for conflict_id in conflict["actions"]:
			if conflict_id not in conflicting_ids:
				conflicting_ids.append(conflict_id)
	for action_id in _item_rows.keys():
		var item = _item_rows[action_id]
		if conflicting_ids.has(action_id):
			item.binding_label.add_theme_color_override("font_color", COLOR_CONFLICT)
			item.binding_label.tooltip_text = "Conflicts with another keybind"
		else:
			item.binding_label.remove_theme_color_override("font_color")
			item.binding_label.tooltip_text = ""

func _update_binding_label(action_id: String) -> void:
	if _item_rows.has(action_id):
		var item = _item_rows[action_id]
		item.binding_label.text = _format_binding_display(action_id)

func _format_binding_display(action_id: String) -> String:
	var bindings: Array = []
	if _manager != null:
		bindings = _manager.get_binding(action_id)
	if bindings.is_empty():
		return "Unbound"
	var parts: Array = []
	for binding in bindings:
		if binding is InputEvent:
			parts.append(binding.as_text())
	return ", ".join(parts)

func _show_rebind_overlay() -> void:
	if _rebind_overlay and is_instance_valid(_rebind_overlay):
		return

	var root = _container.get_tree().root

	var canvas = CanvasLayer.new()
	canvas.layer = 200
	canvas.name = "CoreKeybindRebindLayer"

	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.8)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_STOP
	center.focus_mode = Control.FOCUS_ALL

	_rebind_overlay = canvas

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 220)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var title = Label.new()
	title.text = "Press any key..."
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "Rebinding: %s" % _rebind_action_id
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(subtitle)

	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel (Escape)"
	cancel_btn.pressed.connect(_hide_rebind_overlay)
	cancel_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(cancel_btn)

	panel.add_child(vbox)
	center.add_child(panel)

	canvas.add_child(bg)
	canvas.add_child(center)

	center.gui_input.connect(_on_rebind_input)

	root.add_child(canvas)
	center.grab_focus()

func _hide_rebind_overlay() -> void:
	if _rebind_overlay and is_instance_valid(_rebind_overlay):
		_rebind_overlay.queue_free()
		_rebind_overlay = null
	_rebind_action_id = ""

func _on_rebind_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_hide_rebind_overlay()
			return
		if event.keycode in [KEY_CTRL, KEY_ALT, KEY_SHIFT, KEY_META]:
			return
		_manager.set_binding(_rebind_action_id, [event])
		_update_binding_label(_rebind_action_id)
		_hide_rebind_overlay()
		_play_sound("click")
		_notify("check", "Rebound to: %s" % event.as_text())
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			return
		_manager.set_binding(_rebind_action_id, [event])
		_update_binding_label(_rebind_action_id)
		_hide_rebind_overlay()
		_play_sound("click")
		_notify("check", "Rebound to: %s" % event.as_text())

func _notify(icon: String, message: String) -> void:
	var signals = _get_root_node("Signals")
	if signals != null and signals.has_signal("notify"):
		signals.emit_signal("notify", icon, message)
		return
	_log_info(message)

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

func _log_info(message: String) -> void:
	if ClassDB.class_exists("ModLoaderLog"):
		ModLoaderLog.info(message, LOG_NAME)
	else:
		print(LOG_NAME + ": " + message)
