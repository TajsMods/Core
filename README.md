# Taj's Core Framework

Taj's Core is an infrastructure-only framework mod for Upload Labs. It provides stable services that other mods can depend on without pulling in gameplay changes.

## Access

Core registers itself as a global singleton via `Engine` metadata:

```gdscript
var core = Engine.has_meta("TajsCore") ? Engine.get_meta("TajsCore") : null
```

## Depend on Core

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

Core services are exposed on the singleton: `core.settings`, `core.migrations`, `core.event_bus`, `core.keybinds`, `core.patches`, `core.diagnostics`, `core.modules`, `core.nodes`, and `core.node_spawner`.

## Settings UI

Core adds a settings button in the HUD overlay with tabs for Core settings, Keybinds, and Mod Manager (Workshop sync + mod enable/disable). Downstream keybinds registered via `core.keybinds` appear in the Keybinds tab automatically.

## Keybinds (scoped helper)

```gdscript
var evt := InputEventKey.new()
evt.keycode = KEY_F8
core.keybinds.register_action_scoped(
    "YourNamespace-YourMod",
    "toggle_feature",
    "Toggle Feature",
    [evt],
    "gameplay",
    Callable(self, "_on_toggle_feature"),
    0
)
```

## Migrations

```gdscript
core.migrations.register_migration("yourmod", "0.2.0", func() -> void:
    core.settings.set_value("yourmod.new_flag", true)
)
core.migrations.run_pending("yourmod")
```

## Events

```gdscript
core.event_bus.on("core.ready", Callable(self, "_on_core_ready"), self, true)
core.event_bus.on("settings.changed", Callable(self, "_on_settings_changed"), self, false)
```

## Services

- Versioning and compatibility checks
- Module registry
- Settings with schema, persistence, and migrations
- Event bus with sticky events (core.ready)
- Keybinds manager with conflict detection and persistence
- Patch utilities (apply_once, connect_signal_once)
- Diagnostics snapshot export
- Node registry and safe spawner for windows/nodes

## Settings File

Core stores settings at `user://tajs_core_settings.json`.
