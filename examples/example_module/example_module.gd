extends Node
## Example Module for Taj's Core Framework
##
## This demonstrates how to create a module that integrates with the Core framework,
## including module registration and keybind setup.

const MODULE_NAME = "ExampleModule"
const MODULE_VERSION = "1.0.0"

func _ready() -> void:
	_register_with_core()
	_register_keybinds()
	_register_settings()

## Register this module with the Core framework
func _register_with_core() -> void:
	var success = Core.register_module(MODULE_NAME, self, MODULE_VERSION)
	
	if success:
		print("Example module registered successfully!")
	else:
		print("Failed to register example module")

## Register custom keybinds for this module
func _register_keybinds() -> void:
	# Create a key event for the action
	var key_event = InputEventKey.new()
	key_event.keycode = KEY_F1
	
	# Register the action
	var success = Core.Keybinds.register_action(
		"example_toggle",
		[key_event],
		"Toggle example module feature"
	)
	
	if success:
		Core.Logger.info("Example keybind registered: F1 for toggle")

## Register module-specific settings
func _register_settings() -> void:
	# Get or set default values
	var enabled = Core.Settings.get_value("example_module", "enabled", true)
	var feature_value = Core.Settings.get_value("example_module", "feature_value", 42)
	
	Core.Logger.info("Example module settings - Enabled: %s, Feature: %d" % [enabled, feature_value])

## Process input for our registered actions
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("example_toggle"):
		_on_toggle()

## Handle the toggle action
func _on_toggle() -> void:
	var current = Core.Settings.get_value("example_module", "enabled", true)
	Core.Settings.set_value("example_module", "enabled", not current)
	Core.Settings.save_settings()
	
	Core.Logger.info("Example module toggled: %s" % (not current))
	# Emit using the EventBus built-in signal properly
	Core.EventBus.setting_changed.emit("example_module", "enabled", not current)
