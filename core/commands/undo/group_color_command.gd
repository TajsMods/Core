class_name TajsCoreGroupColorCommand
extends "res://mods-unpacked/TajemnikTV-Core/core/commands/undo/undo_command.gd"

## Window name (Groups are named like "WindowGroup", "WindowGroup2", etc.)
var _window_name: String = ""

## Color index before the change
var _before_color: int = 0

## Color index after the change
var _after_color: int = 0


## Setup the command with window name and before/after colors
func setup(window_name: String, before_color: int, after_color: int) -> void:
    _window_name = window_name
    _before_color = before_color
    _after_color = after_color
    description = "Change Group Color"


## Execute (apply after color)
func execute() -> bool:
    return _apply_color(_after_color)


## Undo (apply before color)
func undo() -> bool:
    return _apply_color(_before_color)


## Apply a color index to the window
func _apply_color(color_index: int) -> bool:
    var window = _find_window()
    if not is_instance_valid(window):
        return false
    
    if not "color" in window:
        return false
    
    window.color = color_index
    if window.has_method("update_color"):
        window.update_color()
    
    return true


## Check if command is still valid
func is_valid() -> bool:
    var window = _find_window()
    return is_instance_valid(window) and "color" in window


## Helper to find window by name
func _find_window() -> Node:
    if not Globals.desktop:
        return null
    var windows = Globals.desktop.get_node_or_null("Windows")
    if not windows:
        return null
    return windows.get_node_or_null(_window_name)
