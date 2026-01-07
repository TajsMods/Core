extends Node
## Taj's Core Keybinds - Action Registration and Conflict Handling
##
## Provides centralized keybind management with conflict detection and resolution.

var _registered_actions := {}
var _action_conflicts := {}

## Register an input action with the core framework
## @param action_name: Name of the action
## @param events: Array of InputEvent objects to bind
## @param description: Human-readable description of the action
## @param allow_conflicts: If true, allows conflicting bindings
func register_action(action_name: String, events: Array, description: String = "", allow_conflicts: bool = false) -> bool:
	if InputMap.has_action(action_name):
		if Core and Core.Logger:
			Core.Logger.warn("Action '%s' is already registered in InputMap" % action_name)
		return false
	
	# Check for conflicts
	var conflicts := _check_conflicts(events)
	if not conflicts.is_empty() and not allow_conflicts:
		if Core and Core.Logger:
			Core.Logger.warn("Action '%s' has conflicts: %s" % [action_name, str(conflicts)])
		if Core and Core.EventBus:
			Core.EventBus.keybind_conflict.emit(action_name, str(conflicts), str(events))
		return false
	
	# Register the action
	InputMap.add_action(action_name)
	for event in events:
		if event is InputEvent:
			InputMap.action_add_event(action_name, event)
	
	_registered_actions[action_name] = {
		"events": events,
		"description": description,
		"conflicts": conflicts
	}
	
	if Core and Core.Logger:
		Core.Logger.info("Registered keybind: %s - %s" % [action_name, description])
	if Core and Core.EventBus:
		Core.EventBus.keybind_registered.emit(action_name)
	
	return true

## Unregister an input action
func unregister_action(action_name: String) -> void:
	if not _registered_actions.has(action_name):
		if Core and Core.Logger:
			Core.Logger.warn("Action '%s' is not registered" % action_name)
		return
	
	InputMap.erase_action(action_name)
	_registered_actions.erase(action_name)
	_action_conflicts.erase(action_name)
	
	if Core and Core.Logger:
		Core.Logger.info("Unregistered keybind: %s" % action_name)

## Check if an action is registered
func has_action(action_name: String) -> bool:
	return _registered_actions.has(action_name)

## Get action description
func get_action_description(action_name: String) -> String:
	if _registered_actions.has(action_name):
		return _registered_actions[action_name].description
	return ""

## Get all registered actions
func get_all_actions() -> Array:
	return _registered_actions.keys()

## Get conflicts for an action
func get_action_conflicts(action_name: String) -> Array:
	if _action_conflicts.has(action_name):
		return _action_conflicts[action_name]
	return []

## Check for conflicts with existing actions
func _check_conflicts(events: Array) -> Array:
	var conflicts := []
	
	for event in events:
		if not event is InputEvent:
			continue
		
		for action_name in _registered_actions:
			var registered_events = _registered_actions[action_name].events
			for registered_event in registered_events:
				if _events_match(event, registered_event):
					conflicts.append({
						"action": action_name,
						"event": registered_event
					})
	
	return conflicts

## Check if two events match (same key/button)
func _events_match(event1: InputEvent, event2: InputEvent) -> bool:
	# Check if both are the same type
	if event1 is InputEventKey and event2 is InputEventKey:
		return event1.keycode == event2.keycode
	elif event1 is InputEventMouseButton and event2 is InputEventMouseButton:
		return event1.button_index == event2.button_index
	elif event1 is InputEventJoypadButton and event2 is InputEventJoypadButton:
		return event1.button_index == event2.button_index
	
	return false

## Rebind an action to new events
func rebind_action(action_name: String, new_events: Array, allow_conflicts: bool = false) -> bool:
	if not _registered_actions.has(action_name):
		if Core and Core.Logger:
			Core.Logger.warn("Cannot rebind unregistered action: %s" % action_name)
		return false
	
	# Check for conflicts
	var conflicts := _check_conflicts(new_events)
	if not conflicts.is_empty() and not allow_conflicts:
		if Core and Core.Logger:
			Core.Logger.warn("Rebind for '%s' has conflicts: %s" % [action_name, str(conflicts)])
		return false
	
	# Clear existing events
	InputMap.action_erase_events(action_name)
	
	# Add new events
	for event in new_events:
		if event is InputEvent:
			InputMap.action_add_event(action_name, event)
	
	_registered_actions[action_name].events = new_events
	_registered_actions[action_name].conflicts = conflicts
	
	if Core and Core.Logger:
		Core.Logger.info("Rebound action: %s" % action_name)
	
	return true
