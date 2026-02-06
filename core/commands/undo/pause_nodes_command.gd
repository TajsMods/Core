class_name TajsCorePauseNodesCommand
extends "res://mods-unpacked/TajemnikTV-Core/core/commands/undo/undo_command.gd"

## Before pause states: window_name -> bool (paused state)
var _before_states: Dictionary = {}

## After pause states: window_name -> bool (paused state)
var _after_states: Dictionary = {}


## Setup the command with before and after pause states
func setup(before: Dictionary, after: Dictionary) -> void:
    _before_states = before.duplicate()
    _after_states = after.duplicate()
    
    var count: int = _before_states.size()
    if count == 1:
        # Check if we're pausing or unpausing
        var keys_array: Array = _before_states.keys()
        var window_name: String = str(keys_array[0])
        var was_paused_val: Variant = _before_states.get(window_name, false)
        var was_paused: bool = true if was_paused_val else false
        var now_paused_val: Variant = _after_states.get(window_name, was_paused)
        var now_paused: bool = true if now_paused_val else false
        if now_paused and not was_paused:
            description = "Pause Node"
        elif was_paused and not now_paused:
            description = "Unpause Node"
        else:
            description = "Toggle Pause"
    else:
        description = "Toggle Pause (%d Nodes)" % count


## Execute (apply after states)
func execute() -> bool:
    return _apply_states(_after_states)


## Undo (apply before states)
func undo() -> bool:
    return _apply_states(_before_states)


## Apply pause states to windows
func _apply_states(states: Dictionary) -> bool:
    var success: bool = true
    
    for window_name: String in states:
        var window: Node = _find_window(window_name)
        if not is_instance_valid(window):
            success = false
            continue
        
        var paused_state_val: Variant = states.get(window_name, false)
        var paused_state: bool = true if paused_state_val else false
        
        # Use set_paused if available, otherwise set property directly
        if window.has_method("set_paused"):
            window.call("set_paused", paused_state)
        elif "paused" in window:
            window.set("paused", paused_state)
            # Manually trigger ticking update if set_paused wasn't available
            if window.has_method("update_ticking"):
                window.call("update_ticking")
    
    return success


## Check if command is still valid
func is_valid() -> bool:
    # At least one window must still exist
    for window_name: String in _before_states:
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
