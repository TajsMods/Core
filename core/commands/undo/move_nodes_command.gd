class_name TajsCoreMoveNodesCommand
extends "res://mods-unpacked/TajemnikTV-Core/core/commands/undo/undo_command.gd"

## Before positions: window_name -> Vector2
var _before_positions: Dictionary = {}

## After positions: window_name -> Vector2
var _after_positions: Dictionary = {}


## Setup the command with before and after positions
func setup(before: Dictionary, after: Dictionary) -> void:
    _before_positions = before.duplicate()
    _after_positions = after.duplicate()
    
    var count: Variant = _before_positions.size()
    if count == 1:
        description = "Move Node"
    else:
        description = "Move %d Nodes" % count


## Execute (apply after positions)
func execute() -> bool:
    return _apply_positions(_after_positions)


## Undo (apply before positions)
func undo() -> bool:
    return _apply_positions(_before_positions)


## Apply a set of positions to windows
func _apply_positions(positions: Dictionary) -> bool:
    var success: bool = true
    
    for window_name: String in positions:
        var window: Node = _find_window(window_name)
        if not is_instance_valid(window):
            push_warning("MoveNodesCommand: Window '%s' no longer exists" % window_name)
            success = false
            continue
        
        window.set("position", positions[window_name])
    
    # Emit dragging_set signal to update visuals (cables, etc.)
    Signals.dragging_set.emit()
    
    return success


## Check if command is still valid
func is_valid() -> bool:
    # At least one window must still exist
    for window_name: String in _before_positions:
        var window: Node = _find_window(window_name)
        if is_instance_valid(window):
            return true
    return false


## Helper to find window by name
func _find_window(window_name: String) -> Node:
    if not Globals.desktop:
        return null
    var windows: Node = Globals.desktop.get_node_or_null("Windows")
    if not windows:
        return null
    return windows.get_node_or_null(window_name)
