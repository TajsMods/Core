extends Node
## Taj's Core Patches - Apply-Once Patch Registry
##
## Provides a system for applying patches with tracking to ensure each patch
## is only applied once, even across game sessions.

var _applied_patches := {}
var _patch_registry := {}

func _ready() -> void:
	_load_patch_history()

## Register a patch with the system
## @param patch_id: Unique identifier for the patch
## @param patch_func: Callable that performs the patch
## @param description: Human-readable description of what the patch does
func register_patch(patch_id: String, patch_func: Callable, description: String = "") -> void:
	if _patch_registry.has(patch_id):
		if Core and Core.Logger:
			Core.Logger.warn("Patch '%s' is already registered" % patch_id)
		return
	
	_patch_registry[patch_id] = {
		"func": patch_func,
		"description": description,
		"registered_at": Time.get_unix_time_from_system()
	}
	
	if Core and Core.Logger:
		Core.Logger.debug("Registered patch: %s - %s" % [patch_id, description])

## Apply a patch if it hasn't been applied yet
## @param patch_id: The ID of the patch to apply
## @return true if patch was applied, false if already applied or doesn't exist
func apply_patch(patch_id: String) -> bool:
	if not _patch_registry.has(patch_id):
		if Core and Core.Logger:
			Core.Logger.error("Patch '%s' is not registered" % patch_id)
		return false
	
	if is_patch_applied(patch_id):
		if Core and Core.Logger:
			Core.Logger.debug("Patch '%s' has already been applied" % patch_id)
		return false
	
	var patch_data = _patch_registry[patch_id]
	
	if Core and Core.Logger:
		Core.Logger.info("Applying patch: %s - %s" % [patch_id, patch_data.description])
	
	# Apply the patch with error handling
	var result = null
	var error_occurred = false
	
	# Godot 4 doesn't have try/catch, so we validate the callable
	if patch_data.func.is_valid():
		result = patch_data.func.call()
	else:
		error_occurred = true
		if Core and Core.Logger:
			Core.Logger.error("Patch '%s' has invalid callable" % patch_id)
	
	if error_occurred:
		return false
	
	# Mark as applied
	_applied_patches[patch_id] = {
		"applied_at": Time.get_unix_time_from_system(),
		"description": patch_data.description,
		"result": result
	}
	
	_save_patch_history()
	
	if Core and Core.EventBus:
		Core.EventBus.emit_signal("patch_applied", patch_id)
	
	return true

## Check if a patch has been applied
func is_patch_applied(patch_id: String) -> bool:
	return _applied_patches.has(patch_id)

## Get all applied patches
func get_applied_patches() -> Array:
	return _applied_patches.keys()

## Get all registered patches
func get_registered_patches() -> Array:
	return _patch_registry.keys()

## Apply all registered patches that haven't been applied yet
func apply_all_patches() -> int:
	var count := 0
	
	for patch_id in _patch_registry:
		if apply_patch(patch_id):
			count += 1
	
	if Core and Core.Logger:
		Core.Logger.info("Applied %d patch(es)" % count)
	return count

## Reset patch history (use with caution!)
func reset_patch_history() -> void:
	_applied_patches.clear()
	_save_patch_history()
	if Core and Core.Logger:
		Core.Logger.warn("Patch history has been reset")

## Load patch history from settings
func _load_patch_history() -> void:
	if Core and Core.Settings:
		var history = Core.Settings.get_value("_patches", "applied", {})
		if history is Dictionary:
			_applied_patches = history
			if Core.Logger:
				Core.Logger.debug("Loaded patch history: %d patch(es) applied" % _applied_patches.size())

## Save patch history to settings
func _save_patch_history() -> void:
	if Core and Core.Settings:
		Core.Settings.set_value("_patches", "applied", _applied_patches)
		Core.Settings.save_settings()
