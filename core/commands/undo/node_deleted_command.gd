# ==============================================================================
# Taj's Core - NodeDeletedCommand
# Undoable command for node deletion
# ==============================================================================
class_name TajsCoreNodeDeletedCommand
extends "res://mods-unpacked/TajemnikTV-Core/core/commands/undo/undo_command.gd"

## The window name
var _window_name: String = ""

## The window's export data (captured at deletion time)
var _export_data: Dictionary = {}

## The window's position
var _position: Vector2 = Vector2.ZERO

## Whether the window was in importing state
var _importing: bool = false


## Setup the command with the window data (captured at deletion time)
func setup(window_name: String, export_data: Dictionary, position: Vector2, importing: bool = false) -> void:
	_window_name = window_name
	_export_data = export_data.duplicate(true) # Deep copy
	_position = position
	_importing = importing
	description = "Delete Node"


## Execute (delete the window) - used for redo
func execute() -> bool:
	var window = _find_window()
	if not is_instance_valid(window):
		# Window already gone, consider success
		return true
	
	# Deselect if selected
	if Globals.selections.has(window):
		var new_sel = Globals.selections.duplicate()
		new_sel.erase(window)
		Globals.set_selection(new_sel, Globals.connector_selection, Globals.selection_type)
	
	# Close/delete the window
	window.propagate_call("close")
	return true


## Undo (recreate the window)
func undo() -> bool:
	if _export_data.is_empty():
		push_warning("NodeDeletedCommand: No export data to restore window")
		return false
	
	if not Globals.desktop:
		return false
	
	var restore_data = {_window_name: _export_data}
	Globals.desktop.add_windows_from_data(restore_data, _importing)
	
	# Restore position
	var window = _find_window()
	if is_instance_valid(window):
		window.position = _position
	
	return true


## Check if command is still valid
func is_valid() -> bool:
	# For deletion commands, we need the export data to exist
	return not _export_data.is_empty()


## Helper to find window by name
func _find_window() -> Node:
	if not Globals.desktop:
		return null
	return Globals.desktop.get_node_or_null("Windows/" + _window_name)
