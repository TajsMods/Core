class_name TajsCoreNodeCreatedCommand
extends "res://mods-unpacked/TajemnikTV-Core/core/commands/undo/undo_command.gd"

## The window name
var _window_name: String = ""

## The window's export data (captured before deletion for redo)
var _export_data: Dictionary = {}

## The window's position
var _position: Vector2 = Vector2.ZERO

## Whether the window was in importing state
var _importing: bool = false


## Setup the command with the window name
func setup(window_name: String) -> void:
    _window_name = window_name
    description = "Create Node"


## Capture the window's data (called before undo to enable redo)
func capture_window_data() -> bool:
    var window: Node = _find_window()
    if not is_instance_valid(window):
        return false
    
    if window.has_method("export"):
        _export_data = window.call("export")
    _position = window.get("position") if window.get("position") != null else Vector2.ZERO
    _importing = window.get("importing") if window.get("importing") != null else false
    return true


## Execute (recreate the window) - used for redo
func execute() -> bool:
    if _export_data.is_empty():
        push_warning("NodeCreatedCommand: No export data to recreate window")
        return false
    
    if not Globals.desktop:
        return false
    
    var restore_data: Dictionary = {_window_name: _export_data}
    if Globals.desktop.has_method("add_windows_from_data"):
        Globals.desktop.call("add_windows_from_data", restore_data, _importing)
    
    # Restore position
    var window: Node = _find_window()
    if is_instance_valid(window):
        window.set("position", _position)
    
    return true


## Undo (delete the window)
func undo() -> bool:
    var window: Node = _find_window()
    if not is_instance_valid(window):
        push_warning("NodeCreatedCommand: Window '%s' not found for undo" % _window_name)
        return false
    
    # Capture data before deletion (for redo)
    var _ignored: bool = capture_window_data()
    
    # Deselect if selected
    if Globals.selections.has(window):
        var new_sel: Array = Globals.selections.duplicate()
        new_sel.erase(window)
        Globals.set_selection(new_sel, Globals.connector_selection)
    
    # Close/delete the window
    if window.has_method("propagate_call"):
        window.call("propagate_call", "close")
    return true


## Check if command is still valid
func is_valid() -> bool:
    # For creation commands, there should be a window OR export data (for redo)
    var window: Node = _find_window()
    return is_instance_valid(window) or not _export_data.is_empty()


## Helper to find window by name
func _find_window() -> Node:
    if not Globals.desktop:
        return null
    return Globals.desktop.get_node_or_null("Windows/" + _window_name)
