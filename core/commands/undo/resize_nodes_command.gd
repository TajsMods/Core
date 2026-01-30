# ==============================================================================
# Taj's Core - ResizeNodesCommand
# Undoable command for node resize changes
# ==============================================================================
class_name TajsCoreResizeNodesCommand
extends "res://mods-unpacked/TajemnikTV-Core/core/commands/undo/undo_command.gd"

## Before data: window_name -> {size: Vector2, position: Vector2}
var _before_data: Dictionary = {}

## After data: window_name -> {size: Vector2, position: Vector2}
var _after_data: Dictionary = {}


## Setup the command with before and after size/position data
func setup(before: Dictionary, after: Dictionary) -> void:
	_before_data = before.duplicate(true)
	_after_data = after.duplicate(true)
	
	var count = _before_data.size()
	if count == 1:
		description = "Resize Node"
	else:
		description = "Resize %d Nodes" % count


## Execute (apply after sizes/positions)
func execute() -> bool:
	return _apply_data(_after_data)


## Undo (apply before sizes/positions)
func undo() -> bool:
	return _apply_data(_before_data)


## Apply a set of sizes and positions to windows
func _apply_data(data: Dictionary) -> bool:
	var success := true
	
	for window_name in data:
		var window = _find_window(window_name)
		if not is_instance_valid(window):
			success = false
			continue
		
		var entry = data[window_name]
		window.position = entry.position
		window.size = entry.size
		# window_group uses custom_minimum_size to enforce minimum
		if "custom_minimum_size" in window:
			window.custom_minimum_size = entry.size
	
	# Emit dragging_set signal to trigger UI updates (cables etc)
	Signals.dragging_set.emit()
	
	return success


## Check if command is still valid
func is_valid() -> bool:
	# At least one window must still exist
	for window_name in _before_data:
		var window = _find_window(window_name)
		if is_instance_valid(window):
			return true
	return false


## Helper to find window by name
func _find_window(window_name: String) -> Node:
	if not Globals.desktop:
		return null
	var windows = Globals.desktop.get_node_or_null("Windows")
	if not windows:
		return null
	return windows.get_node_or_null(window_name)
