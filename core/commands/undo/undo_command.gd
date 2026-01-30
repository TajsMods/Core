class_name TajsCoreUndoCommand
extends RefCounted

## Maximum time between commands to allow merging (ms)
const MERGE_WINDOW_MS: int = 1000

## Description of the command (shown in UI logs)
var description: String = "Unknown Command"

## Creation timestamp (used for merging)
var timestamp: int = 0

func _init() -> void:
	timestamp = Time.get_ticks_msec()

## Execute the command (used for redo)
## Returns true on success
func execute() -> bool:
	return false

## Undo the command
## Returns true on success
func undo() -> bool:
	return false

## Check if the command is still valid manually
## (e.g., referenced nodes still exist)
func is_valid() -> bool:
	return true

## Merge this command with a new one (optional optimization)
## Returns true if merged
func merge_with(_other) -> bool:
	return false

## Get description string
func get_description() -> String:
	return description
