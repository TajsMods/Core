# Taj's Core Framework

Taj's Core is an infrastructure-only framework mod for Upload Labs. It provides stable services that other mods can depend on without pulling in gameplay changes.

## Access

Core registers itself as a global singleton via `Engine` metadata:

```gdscript
var core = Engine.has_meta("tajs_core") ? Engine.get_meta("tajs_core") : null
```

## Depend on Core

In your module entrypoint, grab the Core singleton and verify version:

```gdscript
var core = Engine.has_meta("tajs_core") ? Engine.get_meta("tajs_core") : null
if core == null or not core.require("0.1.0"):
    return
core.register_module({
    "id": "YourNamespace-YourMod",
    "name": "Your Mod",
    "version": "1.0.0",
    "min_core_version": "1.0.0"
})
```

Core services are exposed on the singleton: `core.settings`, `core.event_bus`, `core.keybinds`, `core.patches`, `core.diagnostics`, and `core.module_registry`.

## Services

- Versioning and compatibility checks
- Module registry
- Settings with schema, persistence, and migrations
- Event bus with sticky events (core.ready)
- Keybinds manager with conflict detection and persistence
- Patch utilities (apply_once, connect_signal_once)
- Diagnostics snapshot export

## Settings File

Core stores settings at `user://tajs_core_settings.json`.
