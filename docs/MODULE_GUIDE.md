# Module Guide

## Best Practices

- **Core-only dependency**: depend on Taj's Core only; avoid cross-module coupling.
- **Fail-soft**: if core or a service is missing, log and disable your module gracefully.
- **Namespacing**: prefix all settings, events, and action IDs with your mod ID or namespace.
- **Avoid duplicate patches**: use `core.patches.apply_once` and unique patch IDs.
- **Version checks**: always gate features with `core.require(min_version)`.

## Recommended Module Bootstrap

```gdscript
var core = Engine.has_meta("tajs_core") ? Engine.get_meta("tajs_core") : null
if core == null or not core.require("0.1.0"):
    return
core.register_module({
    "id": "YourNamespace-YourMod",
    "name": "Your Mod",
    "version": "1.0.0",
    "min_core_version": "0.1.0"
})
```

## Event Usage

Use `core.event_bus` for cross-module events rather than direct references. Prefer sticky events for bootstrapping (Core emits `core.ready`).
