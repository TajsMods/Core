# Example Module

This is a simple example module that demonstrates how to use the Taj's Core framework.

## Features Demonstrated

- Module registration with `Core.register_module()`
- Keybind registration with `Core.Keybinds.register_action()`
- Settings management with namespaced keys
- Event handling through InputMap

## Usage

1. Add the Core framework as an AutoLoad singleton named "Core"
2. Add this example module to your scene tree or as an AutoLoad
3. Press F1 to toggle the module's enabled state

## Code Overview

```gdscript
# Register with Core framework
Core.register_module("ExampleModule", self, "1.0.0")

# Register a keybind
var key_event = InputEventKey.new()
key_event.keycode = KEY_F1
Core.Keybinds.register_action("example_toggle", [key_event], "Toggle example")

# Use namespaced settings
Core.Settings.set_value("example_module", "enabled", true)
var enabled = Core.Settings.get_value("example_module", "enabled", false)
```

## File Structure

```
examples/example_module/
├── example_module.gd    # Main module script
└── README.md            # This file
```
