# Taj's Core Framework API Documentation

**Version:** 1.0.0

Taj's Core is a modular framework for creating mods in Godot. It provides essential systems for module management, logging, settings, events, keybinds, and code patching.

## Table of Contents

- [Installation](#installation)
- [Core Singleton](#core-singleton)
- [Runtime](#runtime)
- [Logger](#logger)
- [Settings](#settings)
- [EventBus](#eventbus)
- [Keybinds](#keybinds)
- [Patches](#patches)

---

## Installation

1. Copy the `core/` directory to your Godot project at `res://core/`
2. Add `res://core/mod_main.gd` as an AutoLoad singleton named **"Core"**
   - Project → Project Settings → Autoload
   - Path: `res://core/mod_main.gd`
   - Node Name: `Core`
   - Enable

The framework will automatically initialize all subsystems on startup.

---

## Core Singleton

The main entry point for the framework. Access subsystems through this singleton.

### Properties

- `Logger`: Logging subsystem
- `Settings`: Configuration subsystem
- `EventBus`: Event messaging subsystem
- `Runtime`: Module management subsystem
- `Keybinds`: Input action subsystem
- `Patches`: Code patching subsystem

### Methods

#### `get_version() -> String`
Returns the framework version string.

#### `register_module(module_name: String, module_instance: Node, module_version: String = "1.0.0") -> bool`
Convenience wrapper for `Runtime.register_module()`.

---

## Runtime

Manages module registration and lifecycle.

### Methods

#### `register_module(module_name: String, module_instance: Node, module_version: String = "1.0.0") -> bool`
Register a module with the framework.

**Parameters:**
- `module_name`: Unique identifier for the module
- `module_instance`: The module Node instance
- `module_version`: Semantic version string (default: "1.0.0")

**Returns:** `true` if successful, `false` if already registered

**Example:**
```gdscript
func _ready():
    Core.Runtime.register_module("MyMod", self, "1.2.3")
```

#### `get_module(module_name: String) -> Node`
Get a registered module instance.

**Returns:** The module Node, or `null` if not found

#### `has_module(module_name: String) -> bool`
Check if a module is registered.

#### `get_module_version(module_name: String) -> String`
Get the version of a registered module.

#### `get_all_modules() -> Array`
Get a list of all registered module names.

#### `set_module_enabled(module_name: String, enabled: bool) -> void`
Enable or disable a module.

#### `is_module_enabled(module_name: String) -> bool`
Check if a module is enabled.

---

## Logger

Centralized logging with multiple log levels and optional file output.

### Enums

#### `LogLevel`
- `DEBUG = 0`: Debug messages
- `INFO = 1`: Informational messages
- `WARN = 2`: Warning messages
- `ERROR = 3`: Error messages
- `NONE = 4`: Disable all logging

### Properties

- `current_log_level: LogLevel`: Minimum level to log (default: `INFO`)
- `log_to_file: bool`: Enable file logging (default: `false`)
- `log_file_path: String`: Path to log file (default: `"user://tajs_core.log"`)

### Methods

#### `debug(message: String) -> void`
Log a debug message.

#### `info(message: String) -> void`
Log an informational message.

#### `warn(message: String) -> void`
Log a warning message.

#### `error(message: String) -> void`
Log an error message.

#### `set_log_level(level: LogLevel) -> void`
Set the minimum log level.

**Example:**
```gdscript
Core.Logger.info("Module initialized")
Core.Logger.warn("Deprecated feature used")
Core.Logger.error("Failed to load resource")

# Enable debug logging
Core.Logger.set_log_level(Core.Logger.LogLevel.DEBUG)

# Enable file logging
Core.Logger.log_to_file = true
```

---

## Settings

Namespaced configuration system with version-based migrations.

### Constants

- `SETTINGS_VERSION = 1`: Current settings schema version
- `SETTINGS_FILE = "user://tajs_core_settings.cfg"`: Settings file path

### Methods

#### `get_value(namespace: String, key: String, default_value = null)`
Get a setting value from a namespace.

**Parameters:**
- `namespace`: The namespace (e.g., "core", "my_mod")
- `key`: The setting key
- `default_value`: Default value if setting doesn't exist

**Returns:** The setting value or default value

#### `set_value(namespace: String, key: String, value) -> void`
Set a setting value in a namespace.

#### `save_settings() -> void`
Save all settings to disk.

#### `register_migration(from_version: int, migration_func: Callable) -> void`
Register a migration function for settings schema updates.

**Parameters:**
- `from_version`: The version to migrate from
- `migration_func`: Callable that takes a `ConfigFile` and performs migration

#### `has_namespace(namespace: String) -> bool`
Check if a namespace exists.

#### `get_namespace_keys(namespace: String) -> PackedStringArray`
Get all keys in a namespace.

#### `erase_key(namespace: String, key: String) -> void`
Remove a key from a namespace.

**Example:**
```gdscript
# Get/set settings with namespace
var volume = Core.Settings.get_value("my_mod", "volume", 0.8)
Core.Settings.set_value("my_mod", "volume", 1.0)
Core.Settings.save_settings()

# Register a migration
Core.Settings.register_migration(0, func(config: ConfigFile):
    # Migrate old "sound" namespace to "audio"
    if config.has_section("sound"):
        var old_volume = config.get_value("sound", "level", 0.5)
        config.set_value("audio", "volume", old_volume)
        config.erase_section("sound")
)
```

---

## EventBus

Global event system for decoupled communication between modules.

### Signals

#### Built-in Signals

- `module_registered(module_name: String, version: String)`: Emitted when a module is registered
- `module_unregistered(module_name: String)`: Emitted when a module is unregistered
- `setting_changed(namespace: String, key: String, value)`: Emitted when a setting changes
- `keybind_registered(action_name: String)`: Emitted when a keybind is registered
- `keybind_conflict(action_name: String, existing_key: String, new_key: String)`: Emitted on keybind conflicts
- `patch_applied(patch_id: String)`: Emitted when a patch is applied

### Methods

#### `register_custom_signal(signal_name: String, param_names: Array = []) -> void`
Register a custom signal.

**Parameters:**
- `signal_name`: Name of the signal
- `param_names`: Array of parameter names (for documentation)

#### `emit_custom(signal_name: String, args: Array = []) -> void`
Emit a custom signal.

#### `connect_custom(signal_name: String, callable: Callable) -> void`
Connect to a custom signal.

#### `disconnect_custom(signal_name: String, callable: Callable) -> void`
Disconnect from a custom signal.

#### `get_custom_signals() -> Array`
Get list of all registered custom signals.

**Example:**
```gdscript
# Connect to built-in signal
Core.EventBus.module_registered.connect(_on_module_registered)

func _on_module_registered(module_name: String, version: String):
    print("Module loaded: %s v%s" % [module_name, version])

# Register and use custom signal
Core.EventBus.register_custom_signal("player_damaged", ["damage", "source"])
Core.EventBus.connect_custom("player_damaged", _on_player_damaged)
Core.EventBus.emit_custom("player_damaged", [10, "enemy"])
```

---

## Keybinds

Input action registration with conflict detection.

### Methods

#### `register_action(action_name: String, events: Array, description: String = "", allow_conflicts: bool = false) -> bool`
Register an input action.

**Parameters:**
- `action_name`: Name of the action
- `events`: Array of `InputEvent` objects
- `description`: Human-readable description
- `allow_conflicts`: Allow conflicting bindings (default: `false`)

**Returns:** `true` if successful, `false` if conflicts exist or already registered

#### `unregister_action(action_name: String) -> void`
Unregister an input action.

#### `has_action(action_name: String) -> bool`
Check if an action is registered.

#### `get_action_description(action_name: String) -> String`
Get the description of an action.

#### `get_all_actions() -> Array`
Get list of all registered actions.

#### `get_action_conflicts(action_name: String) -> Array`
Get conflicts for an action.

#### `rebind_action(action_name: String, new_events: Array, allow_conflicts: bool = false) -> bool`
Rebind an action to new events.

**Example:**
```gdscript
# Create key event
var key_event = InputEventKey.new()
key_event.keycode = KEY_F1

# Register action
Core.Keybinds.register_action(
    "toggle_menu",
    [key_event],
    "Toggle the main menu"
)

# Check for input
func _input(event: InputEvent):
    if event.is_action_pressed("toggle_menu"):
        _toggle_menu()

# Rebind to different key
var new_key = InputEventKey.new()
new_key.keycode = KEY_ESCAPE
Core.Keybinds.rebind_action("toggle_menu", [new_key])
```

---

## Patches

Apply-once patch registry for code modifications.

### Methods

#### `register_patch(patch_id: String, patch_func: Callable, description: String = "") -> void`
Register a patch.

**Parameters:**
- `patch_id`: Unique identifier for the patch
- `patch_func`: Callable that performs the patch
- `description`: Human-readable description

#### `apply_patch(patch_id: String) -> bool`
Apply a patch if not already applied.

**Returns:** `true` if applied, `false` if already applied or doesn't exist

#### `is_patch_applied(patch_id: String) -> bool`
Check if a patch has been applied.

#### `get_applied_patches() -> Array`
Get list of all applied patch IDs.

#### `get_registered_patches() -> Array`
Get list of all registered patch IDs.

#### `apply_all_patches() -> int`
Apply all registered patches that haven't been applied yet.

**Returns:** Number of patches applied

#### `reset_patch_history() -> void`
Reset patch history (use with caution!).

**Example:**
```gdscript
# Register a patch
Core.Patches.register_patch(
    "fix_player_speed_v1",
    func():
        # Patch code here
        PlayerGlobals.max_speed = 500
        return true,
    "Fix player speed cap to 500"
)

# Patches are automatically applied on startup
# You can also manually apply specific patches
Core.Patches.apply_patch("fix_player_speed_v1")

# Check if a patch was applied
if Core.Patches.is_patch_applied("fix_player_speed_v1"):
    print("Speed fix is active")
```

---

## Best Practices

### Module Structure

```gdscript
extends Node

const MODULE_NAME = "YourModName"
const MODULE_VERSION = "1.0.0"

func _ready():
    _register_module()
    _setup_keybinds()
    _load_settings()

func _register_module():
    Core.register_module(MODULE_NAME, self, MODULE_VERSION)
```

### Namespaced Settings

Always use a unique namespace for your module's settings:

```gdscript
const SETTINGS_NAMESPACE = "your_mod_name"

var enabled = Core.Settings.get_value(SETTINGS_NAMESPACE, "enabled", true)
Core.Settings.set_value(SETTINGS_NAMESPACE, "enabled", false)
```

### Logging

Use appropriate log levels:

```gdscript
Core.Logger.debug("Detailed debug information")  # Development only
Core.Logger.info("Normal operation")              # General info
Core.Logger.warn("Something unusual")             # Potential issues
Core.Logger.error("Something failed")             # Actual errors
```

### Event Communication

Use EventBus for loose coupling:

```gdscript
# Publisher
Core.EventBus.register_custom_signal("item_collected", ["item_id"])
Core.EventBus.emit_custom("item_collected", ["gold_coin"])

# Subscriber
Core.EventBus.connect_custom("item_collected", _on_item_collected)

func _on_item_collected(item_id: String):
    print("Collected: ", item_id)
```

---

## Version History

### 1.0.0
- Initial release
- Core module system
- Logging with multiple levels
- Namespaced settings with migrations
- Event bus system
- Keybind management with conflict detection
- Apply-once patch registry
