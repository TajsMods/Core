# ==============================================================================
# Taj's Core - Theme Manager
# Author: TajemnikTV
# Description: Shared theme registry for UI.
# ==============================================================================
class_name TajsCoreThemeManager
extends RefCounted

const DEFAULT_THEME_ID := "default"

var _themes: Dictionary = {}

func _init(default_theme_path: String = "res://themes/main.tres") -> void:
	if ResourceLoader.exists(default_theme_path):
		_themes[DEFAULT_THEME_ID] = load(default_theme_path)

func register_theme(theme_id: String, theme: Theme) -> void:
	if theme_id == "" or theme == null:
		return
	_themes[theme_id] = theme

func get_theme(theme_id: String) -> Theme:
	if _themes.has(theme_id):
		return _themes[theme_id]
	return _themes.get(DEFAULT_THEME_ID, null)

func apply_theme(control: Control, theme_id: String) -> void:
	if control == null:
		return
	var theme := get_theme(theme_id)
	if theme != null:
		control.theme = theme

func list_themes() -> Array:
	return _themes.keys()
