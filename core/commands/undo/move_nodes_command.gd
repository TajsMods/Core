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
    
    var count = _before_positions.size()
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
    var success := true
    # We delay the check slightly to ensure Signal updates propagate if needed
    
    for window_name in positions:
        var window = _find_window(window_name)
        if not is_instance_valid(window):
            # Window might have been deleted, warning but continue
            success = false
            continue
        
        window.position = positions[window_name]
    
    # Emit dragging_set signal to trigger UI updates (cables etc)
    # Core doesn't access Signals directly usually, but undo manager needs it
    # We assume 'Signals' autoload exists in the game context
    var signals_node = Engine.get_main_loop().root.get_node_or_null("Signals")
    if signals_node and signals_node.has_signal("dragging_set"):
        signals_node.emit_signal("dragging_set")
    
    return success

## Check if command is still valid
func is_valid() -> bool:
    # At least one window must still exist
    for window_name in _before_positions:
        var window = _find_window(window_name)
        if is_instance_valid(window):
            return true
    return false

## Helper to find window by name
func _find_window(window_name: String) -> Node:
    var desktop = Engine.get_main_loop().root.get_node_or_null("Main/MainContainer/GameViewport/Desktop")
    if not desktop:
        # Fallback for different scene structure if needed
        desktop = Engine.get_main_loop().root.get_node_or_null("Desktop")
    
    if not desktop:
        return null
        
    var windows = desktop.get_node_or_null("Windows")
    if not windows:
        return null
    return windows.get_node_or_null(window_name)
