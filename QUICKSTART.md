# Quick Start Guide

Get up and running with Taj's Core Framework in 5 minutes!

## 1. Install (2 minutes)

```bash
# Copy the core directory to your Godot project
cp -r core/ /path/to/your/godot/project/
```

Then in Godot:
- **Project → Project Settings → Autoload**
- Path: `res://core/mod_main.gd`
- Node Name: `Core`
- Click **Add**

## 2. Create Your First Module (3 minutes)

Create a new script `my_first_mod.gd`:

```gdscript
extends Node

const MOD_NAME = "MyFirstMod"
const MOD_VERSION = "1.0.0"

func _ready():
    # Register the module
    Core.register_module(MOD_NAME, self, MOD_VERSION)
    
    # Log a message
    Core.Logger.info("My first mod is running!")
    
    # Save a setting
    Core.Settings.set_value(MOD_NAME, "enabled", true)
    Core.Settings.save_settings()
    
    # Register a keybind
    var key = InputEventKey.new()
    key.keycode = KEY_F2
    Core.Keybinds.register_action(
        "my_mod_action",
        [key],
        "Activate my mod feature"
    )

func _input(event):
    if event.is_action_pressed("my_mod_action"):
        Core.Logger.info("F2 was pressed!")
        _do_something_cool()

func _do_something_cool():
    # Your mod logic here
    print("🎉 My mod is doing something cool!")
```

## 3. Run It!

1. Add your script to a Node in your scene (or as an AutoLoad)
2. Run the project
3. Press **F2**
4. See your mod in action!

## What's Next?

### Learn More Features

**Settings with Migrations:**
```gdscript
# Get settings with defaults
var volume = Core.Settings.get_value("my_mod", "volume", 0.8)
var enabled = Core.Settings.get_value("my_mod", "enabled", true)

# Set settings
Core.Settings.set_value("my_mod", "volume", 1.0)
Core.Settings.save_settings()
```

**Event Bus for Communication:**
```gdscript
# Create a custom event
Core.EventBus.register_custom_signal("player_scored", ["points"])

# Listen for the event
Core.EventBus.connect_custom("player_scored", _on_player_scored)

func _on_player_scored(points):
    print("Player scored %d points!" % points)

# Emit the event
Core.EventBus.emit_custom("player_scored", [100])
```

**Patches (Run-Once Code):**
```gdscript
# Register a patch that runs once
Core.Patches.register_patch(
    "fix_bug_123",
    func():
        # Your fix code here
        PlayerGlobals.max_health = 100
        return true,
    "Fix player health bug"
)

# Apply the patch (or it auto-applies on startup)
Core.Patches.apply_patch("fix_bug_123")
```

**Advanced Keybinds:**
```gdscript
# Multiple keys for one action
var keys = [
    create_key_event(KEY_SPACE),
    create_key_event(KEY_ENTER)
]
Core.Keybinds.register_action("jump", keys, "Jump")

# Check for conflicts
var conflicts = Core.Keybinds.get_action_conflicts("jump")
if conflicts.size() > 0:
    print("Warning: Keybind conflicts detected!")

func create_key_event(keycode):
    var event = InputEventKey.new()
    event.keycode = keycode
    return event
```

### Explore Examples

Check out the full example module:
```bash
examples/example_module/example_module.gd
```

### Read the Documentation

- [Full API Reference](docs/API.md)
- [Installation Guide](INSTALLATION.md)
- [README](README.md)

## Common Patterns

### Module Template

```gdscript
extends Node

const MODULE_NAME = "ModuleName"
const MODULE_VERSION = "1.0.0"
const SETTINGS_NS = "module_name"

func _ready():
    _register()
    _load_settings()
    _register_keybinds()
    _register_patches()
    _connect_events()

func _register():
    Core.register_module(MODULE_NAME, self, MODULE_VERSION)
    Core.Logger.info("%s v%s loaded" % [MODULE_NAME, MODULE_VERSION])

func _load_settings():
    var enabled = Core.Settings.get_value(SETTINGS_NS, "enabled", true)
    # Load other settings...

func _register_keybinds():
    var key = InputEventKey.new()
    key.keycode = KEY_F3
    Core.Keybinds.register_action("module_action", [key], "Module action")

func _register_patches():
    Core.Patches.register_patch("module_patch_v1", _apply_patch, "Description")

func _connect_events():
    Core.EventBus.module_registered.connect(_on_module_registered)

func _apply_patch():
    # Patch logic
    return true

func _on_module_registered(name, version):
    Core.Logger.debug("Module registered: %s v%s" % [name, version])
```

## Tips

1. **Use namespaces** - Always namespace your settings: `Core.Settings.get_value("your_mod", "key", default)`
2. **Log everything** - Use appropriate log levels: `debug()`, `info()`, `warn()`, `error()`
3. **Version your patches** - Include version numbers in patch IDs: `"fix_issue_v1"`
4. **Handle conflicts** - Check for keybind conflicts before registering
5. **Save settings** - Always call `Core.Settings.save_settings()` after changes

## Need Help?

- Check if Core is registered: `print(Core.get_version())`
- Enable debug logging: `Core.Logger.set_log_level(Core.Logger.LogLevel.DEBUG)`
- List registered modules: `print(Core.Runtime.get_all_modules())`

Happy modding! 🚀
