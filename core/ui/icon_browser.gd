# ==============================================================================
# Taj's Core - Icon Browser
# Author: TajemnikTV
# Description: Simple icon picker UI component.
# ==============================================================================
class_name TajsCoreIconBrowser
extends RefCounted

signal icon_selected(icon_name: String, icon_path: String)

const GRID_COLUMNS := 8
const ICON_SIZE := 48
const ICON_SPACING := 6

var _icons: Array = []
var _filtered: Array = []
var _search: LineEdit
var _grid: GridContainer
var _buttons: Array = []

func _init() -> void:
	_icons = _scan_icons()
	_filtered = _icons.duplicate()

func build_ui(parent: Control) -> void:
	var search_row := HBoxContainer.new()
	parent.add_child(search_row)
	_search = LineEdit.new()
	_search.placeholder_text = "Search icons..."
	_search.text_changed.connect(_on_search_changed)
	search_row.add_child(_search)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 320)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)

	_grid = GridContainer.new()
	_grid.columns = GRID_COLUMNS
	_grid.add_theme_constant_override("h_separation", ICON_SPACING)
	_grid.add_theme_constant_override("v_separation", ICON_SPACING)
	scroll.add_child(_grid)

	_rebuild_grid()

func set_selected_icon(icon_name: String) -> void:
	if icon_name == "":
		return
	for i in range(_filtered.size()):
		if _filtered[i]["name"] == icon_name:
			_select_index(i)
			return

func _on_search_changed(text: String) -> void:
	var term := text.strip_edges().to_lower()
	_filtered.clear()
	if term == "":
		_filtered = _icons.duplicate()
	else:
		for entry in _icons:
			if entry["name"].to_lower().contains(term):
				_filtered.append(entry)
	_rebuild_grid()

func _rebuild_grid() -> void:
	for btn in _buttons:
		if is_instance_valid(btn):
			btn.queue_free()
	_buttons.clear()
	if _grid == null:
		return
	for i in range(_filtered.size()):
		var entry: Dictionary = _filtered[i]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
		btn.expand_icon = true
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.focus_mode = Control.FOCUS_NONE
		btn.toggle_mode = true
		btn.tooltip_text = entry["name"]
		btn.icon = load(entry["path"])
		btn.pressed.connect(func(): _select_index(i))
		_grid.add_child(btn)
		_buttons.append(btn)

func _select_index(index: int) -> void:
	for i in range(_buttons.size()):
		if is_instance_valid(_buttons[i]):
			_buttons[i].button_pressed = i == index
	if index >= 0 and index < _filtered.size():
		var entry: Dictionary = _filtered[index]
		icon_selected.emit(entry["name"], entry["path"])

func _scan_icons() -> Array:
	var results: Array = []
	var base_dir := "res://textures/icons"
	var dir := DirAccess.open(base_dir)
	if dir != null:
		for file_name in dir.get_files():
			if file_name.ends_with(".png"):
				results.append({"name": file_name.get_basename(), "path": base_dir.path_join(file_name)})
	if results.is_empty():
		for fallback in ["puzzle", "cog", "check", "cross", "warning", "info", "download", "upload"]:
			var path := base_dir.path_join(fallback + ".png")
			if ResourceLoader.exists(path):
				results.append({"name": fallback, "path": path})
	return results
