# Taj's Core Framework

**Version:** 1.0.0

A comprehensive modding framework for Godot games, providing essential systems for module management, logging, configuration, events, input handling, and code patching.

## Features

- 🎯 **Module Registration** - Register and manage game mods with version tracking
- 📝 **Logging System** - Centralized logging with multiple log levels and file output
- ⚙️ **Settings Management** - Namespaced configuration with automatic migrations
- 📡 **Event Bus** - Global event system for decoupled module communication
- 🎮 **Keybind Manager** - Input action registration with conflict detection
- 🔧 **Patch System** - Apply-once code patching with tracking
- 📚 **Complete Documentation** - Full API reference and examples

## Quick Start

### Installation

1. Clone or download this repository into your Godot project
2. Add `res://core/mod_main.gd` as an AutoLoad singleton:
   - Open **Project → Project Settings → Autoload**
   - Set Path: `res://core/mod_main.gd`
   - Set Node Name: `Core`
   - Enable the singleton

### Basic Usage

```gdscript
extends Node

func _ready():
    # Register your module
    Core.register_module("MyMod", self, "1.0.0")
    
    # Use logging
    Core.Logger.info("My mod initialized!")
    
    # Manage settings
    var enabled = Core.Settings.get_value("my_mod", "enabled", true)
    Core.Settings.set_value("my_mod", "enabled", enabled)
    
    # Register a keybind
    var key = InputEventKey.new()
    key.keycode = KEY_F1
    Core.Keybinds.register_action("my_action", [key], "My custom action")
    
    # Register a patch
    Core.Patches.register_patch("my_fix_v1", func():
        # Your patch code here
        return true
    , "Fix for issue #123")
```

## Framework Components

### Core.Runtime
Module registration and lifecycle management.

```gdscript
Core.Runtime.register_module("ModName", self, "1.0.0")
var mod = Core.Runtime.get_module("ModName")
```

### Core.Logger
Multi-level logging system with file output support.

```gdscript
Core.Logger.info("Normal message")
Core.Logger.warn("Warning message")
Core.Logger.error("Error message")
Core.Logger.set_log_level(Core.Logger.LogLevel.DEBUG)
```

### Core.Settings
Namespaced configuration with version-based migrations.

```gdscript
Core.Settings.set_value("my_mod", "setting_key", "value")
var value = Core.Settings.get_value("my_mod", "setting_key", "default")
Core.Settings.save_settings()
```

### Core.EventBus
Global event system for module communication.

```gdscript
# Connect to built-in events
Core.EventBus.module_registered.connect(_on_module_registered)

# Create custom events
Core.EventBus.register_custom_signal("my_event", ["param1"])
Core.EventBus.connect_custom("my_event", _on_my_event)
Core.EventBus.emit_custom("my_event", ["value"])
```

### Core.Keybinds
Input action management with conflict detection.

```gdscript
var key = InputEventKey.new()
key.keycode = KEY_SPACE
Core.Keybinds.register_action("jump", [key], "Jump action")

func _input(event):
    if event.is_action_pressed("jump"):
        player.jump()
```

### Core.Patches
Apply-once code patching system.

```gdscript
Core.Patches.register_patch("patch_id", func():
    # Patch code that runs once
    return true
, "Description of patch")

Core.Patches.apply_patch("patch_id")
```

## Documentation

- **[API Reference](docs/API.md)** - Complete API documentation
- **[Example Module](examples/example_module/)** - Working example showing all features

## Example Module

Check out the included example in `examples/example_module/` for a complete demonstration of:
- Module registration
- Keybind setup
- Settings management
- Event handling

## Project Structure

```
core/
├── mod_main.gd       # Main bootstrap (AutoLoad this as "Core")
├── runtime.gd        # Module registration system
├── logger.gd         # Logging utilities
├── settings.gd       # Configuration with migrations
├── event_bus.gd      # Event messaging system
├── keybinds.gd       # Input action management
└── patches.gd        # Code patching system

docs/
└── API.md            # Full API documentation

examples/
└── example_module/   # Example module implementation
    ├── example_module.gd
    └── README.md
```

## Semantic Versioning

This project follows [Semantic Versioning](https://semver.org/):
- **MAJOR** version for incompatible API changes
- **MINOR** version for backwards-compatible functionality additions
- **PATCH** version for backwards-compatible bug fixes

Current version: **1.0.0**

## Requirements

- Godot 4.0 or later
- No external dependencies

## License

This framework is provided as-is for use in game mods.

## Contributing

This is a modding framework for Taj's game mods. Feel free to fork and adapt for your own projects.

## Support

For issues or questions:
- Check the [API documentation](docs/API.md)
- Review the [example module](examples/example_module/)
- Open an issue on GitHub