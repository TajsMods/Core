# Settings and Migrations

## Settings Schema

Register settings early in your mod init:

```gdscript
core.settings.register_schema("YourNamespace-YourMod", {
    "yourmod.enabled": {"type": "bool", "default": true},
    "yourmod.path": {"type": "string", "default": ""}
})
```

Use typed getters:

```gdscript
var enabled = core.settings.get_bool("yourmod.enabled", true)
```

## Migrations

Register migrations per namespace. Each migration runs once per version and stores the last migrated version in the settings file.

```gdscript
core.migrations.register("yourmod", "0.2.0", func():
    var old = core.settings.get_bool("yourmod.old_flag", false)
    core.settings.set_value("yourmod.new_flag", old)
)
```

Migrations run during core bootstrap (`core.migrations.run_all()`).
