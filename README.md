# Taj's Core Framework

Taj's Core is an infrastructure-only framework mod for Upload Labs. It provides stable services that other mods can depend on without pulling in gameplay changes.

## Access

Core registers itself as a global singleton via `Engine` metadata:

```gdscript
var core = Engine.has_meta("TajsCore") ? Engine.get_meta("TajsCore") : null
```

## Usage

In your module entrypoint, grab the Core singleton and verify version:

```gdscript
var core = Engine.has_meta("TajsCore") ? Engine.get_meta("TajsCore") : null
if core == null or not core.require("0.1.0"):
    return
core.modules.register_module({
    "id": "YourNamespace-YourMod",
    "name": "Your Mod",
    "version": "1.0.0",
    "min_core_version": "1.0.0"
})
```

## Subsystems

Core services are exposed on the singleton (e.g., `core.nodes`, `core.assets`).

### Node Registry (`core.nodes`)

Register custom windows and resources.

```gdscript
# Register a simple window node
core.nodes.register_node({
    "id": "MyMod.MyWindow",
    "display_name": "My Window",
    "category": "utility",
    "packed_scene_path": "res://scenes/windows/my_window.tscn", 
    "attributes": { "limit": 1 }
})

# Register a custom category in the Windows menu
core.nodes.register_window_category("my_category", "My Stuff", "res://icon.png")
```

### Window Management

**Window Scenes (`core.window_scenes`)**: Register directories containing window scenes to resolve paths across mods.
```gdscript
core.window_scenes.register_mod_dir("MyMod", "scenes/windows")
```

**Window Menus (`core.window_menus`)**: Add custom buttons/tabs to the OS window menu.
```gdscript
core.window_menus.register_tab("MyMod", "my_tab", {
    "button_name": "My Tab",
    "icon": "my_icon.png"
})
```

### Hooks System (`core.hooks`)

Listen for global lifecycle events.

```gdscript
# Listen for window creation
core.event_bus.on("window.created", Callable(self, "_on_window_created"))

# Hook into game load
core.event_bus.on("save_load.loaded", Callable(self, "_on_game_loaded"))
```

Supported events: `window.created`, `window.deleted`, `connection.created`, `selection.changed`, `ui.popup`, etc.

### Asset Management (`core.assets`)

Load and cache assets, resolving paths relative to your mod options.

```gdscript
# Load an icon from your mod's 'textures/icons' folder
var icon = core.assets.load_icon("my_icon.png", "MyMod")
```

### Upgrade Caps (`core.upgrade_caps`)

Extend vanilla upgrade limits purely via config.

```gdscript
core.upgrade_caps.register_extended_cap("processor_speed", {
    "extended_cap": 20, # Vanilla is 10
    "cost_multiplier": 1.5
})
```

### Tree Registry (`core.tree_registry`)

Inject nodes into Research and Ascension trees.

```gdscript
core.tree_registry.add_research_node({
    "name": "MyResearch",
    "x": 100, "y": 200,
    "ref": "ExistingNode" # Position relative to this node
})
```

### Feature Flags (`core.features`)

Manage toggleable features backed by Core settings.

```gdscript
core.features.register_feature("my_feature", true, "Enable my cool feature")
if core.features.is_feature_enabled("my_feature"):
    pass
```

### Localization (`core.localization`)

Register translation directories automatically.

```gdscript
core.localization.register_mod_translations("MyMod", "translations")
```

### Theme Manager (`core.theme_manager`)

Register and apply UI themes.

```gdscript
core.theme_manager.register_theme("dark_mode", load("res://themes/dark.tres"))
core.theme_manager.apply_theme(my_control, "dark_mode")
```

### File Variations (`core.file_variations`)

Register variation bits for files (advanced usage).

```gdscript
core.file_variations.register_variations("MyMod", {
    "rare": { "size_mult": 1.2 }
})
```

## Standard Services

*   **Settings (`core.settings`)**: Persistent settings store (`user://tajs_core_settings.json`).
*   **Keybinds (`core.keybinds`)**: Register remappable keybinds.
*   **Migrations (`core.migrations`)**: Versioned data migrations.
*   **Commands (`core.commands`)**: Register palette commands.
*   **Patches (`core.patches`)**: Utilities like `apply_once` or `connect_signal_once`.
*   **Diagnostics (`core.diagnostics`)**: Export debug snapshots.

## Helper Functions

```gdscript
core.notify("check", "Hello from Core")
core.play_sound("click")
core.copy_to_clipboard("text")
```
