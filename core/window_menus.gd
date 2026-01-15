# ==============================================================================
# Taj's Core - Window Menus
# Author: TajemnikTV
# Description: Registry for custom window menu tabs and categories.
# ==============================================================================
class_name TajsCoreWindowMenus
extends RefCounted

const CUSTOM_TAB_START := 50
const CATEGORY_TAB_SCRIPT := "res://scripts/window_category_tab.gd"

var _tabs: Array = []
var _tabs_by_key: Dictionary = {}

func register_tab(mod_id: String, tab_id: String, config: Dictionary = {}) -> int:
	if tab_id == "":
		return -1
	var key := _make_key(mod_id, tab_id)
	if _tabs_by_key.has(key):
		return int(_tabs_by_key[key]["index"])

	var index := CUSTOM_TAB_START + _tabs.size() + 1
	var def := {
		"key": key,
		"mod_id": mod_id,
		"tab_id": tab_id,
		"index": index,
		"button_name": str(config.get("button_name", config.get("button_id", tab_id))),
		"icon": str(config.get("icon", "")),
		"rows": _normalize_rows(config),
		"visible_unlock": str(config.get("visible", "")),
		"disable_unlock": str(config.get("disable", "")),
		"before": str(config.get("before", "")),
		"after": str(config.get("after", "")),
		"notice": str(config.get("notice", ""))
	}
	_tabs.append(def)
	_tabs_by_key[key] = def
	return index

func get_tab_index(mod_id: String, tab_id: String) -> int:
	var key := _make_key(mod_id, tab_id)
	if _tabs_by_key.has(key):
		return int(_tabs_by_key[key]["index"])
	return -1

func get_tab_by_index(index: int) -> Dictionary:
	for tab in _tabs:
		if int(tab["index"]) == index:
			return tab
	return {}

func ensure_tabs(categories_node: Node) -> void:
	if categories_node == null:
		return
	for tab in _tabs:
		var tab_name: String = tab["tab_id"]
		if categories_node.has_node(tab_name):
			continue
		var panel := _build_tab_panel(tab)
		if panel != null:
			categories_node.add_child(panel)

func build_buttons(menu_buttons: Node) -> void:
	if menu_buttons == null:
		return
	for tab in _tabs:
		var button_name: String = tab["button_name"]
		if menu_buttons.has_node(button_name):
			continue
		var button := _build_button(tab)
		if button == null:
			continue
		var move_index := _resolve_insert_index(menu_buttons, tab)
		menu_buttons.add_child(button)
		if move_index != -1:
			menu_buttons.move_child(button, move_index)

func get_panel_for_tab(index: int, categories_node: Node) -> Control:
	if categories_node == null:
		return null
	var tab := get_tab_by_index(index)
	if tab.is_empty():
		return null
	var tab_name: String = tab["tab_id"]
	if categories_node.has_node(tab_name):
		return categories_node.get_node(tab_name)
	return null

func update_button_states(menu_buttons: Node, windows_menu: Node) -> void:
	if menu_buttons == null or windows_menu == null:
		return
	for tab in _tabs:
		var button_name: String = tab["button_name"]
		if not menu_buttons.has_node(button_name):
			continue
		var button: Button = menu_buttons.get_node(button_name)
		button.button_pressed = windows_menu.open and windows_menu.cur_tab == int(tab["index"])

func update_unlocks(menu_buttons: Node) -> void:
	if menu_buttons == null:
		return
	for tab in _tabs:
		var button_name: String = tab["button_name"]
		if not menu_buttons.has_node(button_name):
			continue
		var button: Button = menu_buttons.get_node(button_name)
		var visible_key: String = tab["visible_unlock"]
		var disable_key: String = tab["disable_unlock"]
		if visible_key != "":
			button.visible = Globals.unlocks[visible_key]
		if disable_key != "":
			button.disabled = not Globals.unlocks[disable_key]

func get_notice_for_category(category_id: String) -> String:
	for tab in _tabs:
		if tab["tab_id"] == category_id:
			return str(tab["notice"])
	return ""

func _build_button(tab: Dictionary) -> Button:
	var button := Button.new()
	button.name = tab["button_name"]
	button.custom_minimum_size = Vector2(80, 80)
	button.layout_mode = 2
	button.size_flags_horizontal = 6
	button.size_flags_vertical = 4
	button.focus_mode = Control.FOCUS_NONE
	button.theme_type_variation = &"ButtonMenu"
	button.toggle_mode = true
	button.icon_alignment = 1
	button.expand_icon = true

	var icon_value: String = tab["icon"]
	if icon_value != "":
		var icon_path := _resolve_icon_path(icon_value, tab["mod_id"])
		if icon_path != "":
			button.icon = load(icon_path)

	var index := int(tab["index"])
	button.pressed.connect(func() -> void:
		Signals.set_menu.emit(Utils.menu_types.WINDOWS, index)
	)
	return button

func _build_tab_panel(tab: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = tab["tab_id"]
	panel.visible = false
	panel.layout_mode = 1
	panel.anchors_preset = Control.PRESET_FULL_RECT
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.theme_type_variation = &"MenuButtonsPanel2"
	panel.set_script(load(CATEGORY_TAB_SCRIPT))

	var scroll := ScrollContainer.new()
	scroll.name = "ScrollContainer"
	scroll.layout_mode = 2
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	panel.add_child(scroll)

	var margin := MarginContainer.new()
	margin.name = "MarginContainer"
	margin.layout_mode = 2
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_bottom", 10)
	scroll.add_child(margin)

	var categories := VBoxContainer.new()
	categories.name = "Categories"
	categories.layout_mode = 2
	categories.mouse_filter = Control.MOUSE_FILTER_PASS
	categories.add_theme_constant_override("separation", 0)
	margin.add_child(categories)

	var sub_map: Dictionary = {}
	var rows: Array = tab["rows"]
	if rows.is_empty():
		rows = [ {"default": tab["tab_id"]}]
	for row_index in range(rows.size()):
		var row_def: Dictionary = rows[row_index]
		var row_name := "Row%d" % row_index
		var row := HBoxContainer.new()
		row.name = row_name
		row.layout_mode = 2
		row.add_theme_constant_override("separation", 10)
		categories.add_child(row)
		for sub_id in row_def.keys():
			var column := VBoxContainer.new()
			column.name = sub_id
			column.layout_mode = 2
			column.size_flags_horizontal = 0
			column.add_theme_constant_override("separation", 0)
			row.add_child(column)

			var label := Label.new()
			label.name = "Label"
			label.layout_mode = 2
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.add_theme_font_size_override("font_size", 32)
			label.text = str(row_def[sub_id])
			label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			column.add_child(label)

			var panel_container := PanelContainer.new()
			panel_container.name = "Container"
			panel_container.layout_mode = 2
			panel_container.size_flags_horizontal = 0
			panel_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
			panel_container.theme_type_variation = &"PanelContainerDark"
			column.add_child(panel_container)

			var windows := HBoxContainer.new()
			windows.name = "Windows"
			windows.layout_mode = 2
			windows.mouse_filter = Control.MOUSE_FILTER_IGNORE
			windows.add_theme_constant_override("separation", 5)
			panel_container.add_child(windows)
			sub_map[sub_id] = windows
	panel.set("sub_categories", sub_map)
	return panel

func _resolve_insert_index(menu_buttons: Node, tab: Dictionary) -> int:
	var before := str(tab["before"])
	if before != "" and menu_buttons.has_node(before):
		return menu_buttons.get_node(before).get_index()
	var after := str(tab["after"])
	if after != "" and menu_buttons.has_node(after):
		return menu_buttons.get_node(after).get_index() + 1
	return -1

func _resolve_icon_path(icon_value: String, mod_id: String) -> String:
	if icon_value == "":
		return ""
	if icon_value.begins_with("res://"):
		return icon_value
	if icon_value.ends_with(".png"):
		if mod_id != "":
			return _get_mod_path(mod_id).path_join(icon_value)
		return "res://textures/icons".path_join(icon_value)
	if mod_id != "":
		return _get_mod_path(mod_id).path_join("textures/icons").path_join(icon_value + ".png")
	return "res://textures/icons".path_join(icon_value + ".png")

func _normalize_rows(config: Dictionary) -> Array:
	if config.has("rows"):
		var rows = config["rows"]
		if rows is Array:
			return rows
		if rows is Dictionary:
			return [rows]
	if config.has("categories"):
		var categories = config["categories"]
		if categories is Array:
			return categories
		if categories is Dictionary:
			return [categories]
	return []

func _make_key(mod_id: String, tab_id: String) -> String:
	if mod_id == "":
		return tab_id
	if tab_id.begins_with(mod_id + "."):
		return tab_id
	return "%s.%s" % [mod_id, tab_id]


func _get_mod_path(mod_id: String) -> String:
	if mod_id == "":
		return ""
	if _has_global_class("ModLoaderMod"):
		return ModLoaderMod.get_unpacked_dir().path_join(mod_id)
	return "res://mods-unpacked".path_join(mod_id)


func _has_global_class(class_name_str: String) -> bool:
	for entry in ProjectSettings.get_global_class_list():
		if entry.get("class", "") == class_name_str:
			return true
	return false
