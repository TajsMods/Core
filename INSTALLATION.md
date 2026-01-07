# Installation Guide for Taj's Core Framework

This guide will walk you through setting up Taj's Core framework in your Godot 4.x project.

## Prerequisites

- Godot 4.0 or later
- A Godot project (new or existing)

## Installation Steps

### Step 1: Copy the Core Framework

1. Clone or download this repository
2. Copy the entire `core/` directory into your Godot project at `res://core/`

Your project structure should look like:
```
your_project/
├── core/
│   ├── mod_main.gd
│   ├── runtime.gd
│   ├── logger.gd
│   ├── settings.gd
│   ├── event_bus.gd
│   ├── keybinds.gd
│   └── patches.gd
└── ... (your other project files)
```

### Step 2: Add Core as AutoLoad Singleton

1. Open your Godot project
2. Go to **Project → Project Settings**
3. Navigate to the **Autoload** tab
4. Click the folder icon next to **Path**
5. Select `res://core/mod_main.gd`
6. Set **Node Name** to: `Core` (case-sensitive!)
7. Make sure **Enable** is checked
8. Click **Add**

![AutoLoad Setup](https://docs.godotengine.org/en/stable/_images/autoload_example.png)
*(Example from Godot documentation)*

### Step 3: Verify Installation

Create a simple test script to verify the installation:

```gdscript
extends Node

func _ready():
    print("Core version: ", Core.get_version())
    Core.Logger.info("Core framework is working!")
```

Run your project. You should see:
```
============================================================
  Taj's Core Framework v1.0.0
  Modding framework for Godot
============================================================
[timestamp] [INFO] Core framework initialized successfully
Core version: 1.0.0
[timestamp] [INFO] Core framework is working!
```

## Optional: Install Example Module

To see a working example:

1. Copy `examples/example_module/` to your project
2. Add `example_module.gd` to your scene tree or as an AutoLoad
3. Run the project and press **F1** to test the keybind

## Next Steps

- Read the [API Documentation](docs/API.md) to learn about all features
- Review the [example module](examples/example_module/) for usage patterns
- Create your first module following the examples

## Troubleshooting

### "Core is not defined" error

- Make sure you added `mod_main.gd` as an AutoLoad singleton
- Verify the Node Name is exactly `Core` (case-sensitive)
- Ensure the path is `res://core/mod_main.gd`

### Settings file errors

- The framework creates settings in `user://tajs_core_settings.cfg`
- On Windows: `%APPDATA%\Godot\app_userdata\[ProjectName]/`
- On Linux: `~/.local/share/godot/app_userdata/[ProjectName]/`
- On macOS: `~/Library/Application Support/Godot/app_userdata/[ProjectName]/`

### Module not registering

- Ensure you're calling `Core.register_module()` after the Core framework is ready
- Call it in your module's `_ready()` function or later
- Check the console for warning messages

## Uninstallation

To remove the framework:

1. Remove the AutoLoad singleton from Project Settings
2. Delete the `res://core/` directory
3. Delete any modules that depend on the framework

## Getting Help

- Check the [API Documentation](docs/API.md)
- Review the [README](README.md)
- Look at the [example module](examples/example_module/)
- Check the [CHANGELOG](CHANGELOG.md) for version-specific information
