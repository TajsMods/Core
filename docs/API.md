# Taj's Core API

All APIs are accessed from the Core singleton:

```gdscript
var core = Engine.has_meta("tajs_core") ? Engine.get_meta("tajs_core") : null
if core == null:
    return
```

## Versioning

```gdscript
var version = core.get_version()
var ok = core.require("0.1.0")
var cmp = core.compare_versions("1.0.0", "1.0.1")
```

## Module Registry

```gdscript
core.register_module({
    "id": "YourNamespace-YourMod",
    "name": "Your Mod",
    "version": "1.0.0",
    "min_core_version": "0.1.0"
})
```

Emits `module.registered` on the event bus.

## Settings

Register a schema (namespaced keys recommended):

```gdscript
core.settings.register_schema("YourNamespace-YourMod", {
    "yourmod.enabled": {"type": "bool", "default": true},
    "yourmod.count": {"type": "int", "default": 5}
})
```

Read and write:

```gdscript
var enabled = core.settings.get_bool("yourmod.enabled", true)
core.settings.set_value("yourmod.enabled", false)
```

Listen for changes:

```gdscript
core.settings.value_changed.connect(Callable(self, "_on_setting_changed"))
```

## Event Bus

```gdscript
core.event_bus.on("core.ready", Callable(self, "_on_core_ready"), self, true)
core.event_bus.emit("my.event", {"payload": 1})
```

## Keybinds

```gdscript
var evt := InputEventKey.new()
evt.keycode = KEY_F8
core.keybinds.register_action(
    "yourmod.toggle",
    "Toggle Feature",
    [evt],
    "gameplay",
    Callable(self, "_on_toggle"),
    "YourNamespace-YourMod",
    0
)
```

Conflicts and UI data:

```gdscript
var conflicts = core.keybinds.get_conflicts()
var actions = core.keybinds.get_actions_for_ui()
```

## Patches

```gdscript
core.patches.apply_once("yourmod.patch", func():
    core.patches.connect_signal_once(node, "ready", Callable(self, "_on_ready"), "yourmod.ready")
)
```

## Diagnostics

```gdscript
var snapshot = core.diagnostics.collect()
var json = core.diagnostics.export_json()
var tests = core.diagnostics.self_test()
```
