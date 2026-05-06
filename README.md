# Taj's Core Framework

## How to use

Source of truth:

- Inline code documentation (`##`)
- This README
- Website docs can lag and may include generated placeholder sections: <https://tajsmods.github.io/docs/core/main/>
- Deepwiki: <https://deepwiki.com/TajsMods/Core> (can be stale by up to ~7 days)

## Result dictionaries

Most runtime/service wrappers return:

- success: `{ "ok": true, "error": "", ...payload }`
- failure: `{ "ok": false, "error": "<code>", ...context }`

## Namespaced IDs

Use `ModId.local_id` for cross-mod identifiers.

Examples:

- `TajemnikTV-QoL.toggle_overlay`
- `TajemnikTV-QoL.tools_tab`
- `TajemnikTV-QoL.body_font`

Why it matters:

- Prevents collisions across mods
- Allows Core ownership/routing and diagnostics grouping

## Common mod flows

```gdscript
var core: Variant = Engine.has_meta("TajsCore") ? Engine.get_meta("TajsCore") : null
if core == null:
    return

# 1) Register module
core.register_module({
    "id": "TajemnikTV-QoL",
    "name": "QoL",
    "version": "2.1.5",
    "min_core_version": "3.2.0"
})

# 2) Listen for readiness
core.event_bus.on("core.ready", func(_payload: Dictionary): _on_core_ready())

# 3) Register settings schema
core.register_settings_schema("TajemnikTV-QoL", {
    "tajs_qol.quick_mode.enabled": {"type": "bool", "default": true}
}, "tajs_qol")

# 4) Register command/action
core.register_action("TajemnikTV-QoL.toggle_overlay", {"title": "Toggle Overlay"}, func(_ctx = null): _toggle_overlay())

# 5) Register font + apply to UI
core.register_font("TajemnikTV-QoL.body", "res://mods-unpacked/TajemnikTV-QoL/fonts/MyFont.ttf")
core.apply_font_to_node($Panel/Label, "TajemnikTV-QoL.body", {"property": "font"})

# 6) Create/apply theme profile
core.theme_create_profile("TajemnikTV-QoL.dark_alt")
core.theme_set_color("TajemnikTV-QoL.dark_alt", "font_color", "Label", Color(0.9, 0.95, 1.0))
core.theme_apply_profile_to_node("TajemnikTV-QoL.dark_alt", $PanelContainer)

# 7) Register window tab + icon
core.register_window_tab({"id": "TajemnikTV-QoL.tools", "title": "Tools"})
core.register_icon("TajemnikTV-QoL.tools_icon", "res://mods-unpacked/TajemnikTV-QoL/textures/icons/tools.png")

# 8) Diagnostics smoke check
var diag: Dictionary = core.diagnostics.self_test()
```

## Convenience API

Core now exposes thin wrapper APIs on runtime (`Engine.get_meta("TajsCore")`) for common mod registration flows.

Example usage:

```gdscript
var core: Variant = Engine.get_meta("TajsCore", null)
if core == null:
    return

# 1) Window tab
var tab_result: Dictionary = core.register_window_tab({
    "id": "TajemnikTV-QoL.tools",
    "title": "Tools",
    "icon": "wrench",
    "rows": [{"default": "Utilities"}]
})

# 2) Icon
var icon_result: Dictionary = core.register_icon(
    "TajemnikTV-QoL.tools_icon",
    "res://mods-unpacked/TajemnikTV-QoL/textures/icons/tools.png"
)

# 3) Translations
var tr_result: Dictionary = core.register_translation_dir(
    "TajemnikTV-QoL",
    "res://mods-unpacked/TajemnikTV-QoL/extensions/locale"
)

# 4) Gameplay/data registration (research tree)
var research_result: Dictionary = core.register_research_entry(
    "TajemnikTV-QoL.fast_tools",
    {"x": 1400, "y": 400, "ref": "research_processor"}
)
```

Available wrappers:

- `register_window_tab(data: Dictionary)`
- `register_file_variation(id: String, variation_data: Dictionary, symbol: String = "", symbol_type: String = "file")`
- `register_research_entry(id: String, entry_data: Dictionary, mode: String = "add")`
- `register_ascension_entry(id: String, entry_data: Dictionary, mode: String = "add")`
- `register_icon(id: String, icon_path: String)`
- `register_translation(mod_id: String, path: String)`
- `register_translation_dir(mod_id: String, dir_path: String)`
- `register_translation_path(path: String)`
- `register_translations_dir(dir_path: String)`
- `register_window_directory(dir_path: String)`
- `register_settings_schema(module_id: String, schema: Dictionary, namespace_prefix: String = "")`
- `get_setting(module_id: String, setting_id: String, fallback := null)`
- `set_setting(module_id: String, setting_id: String, value)`
- `reset_setting(module_id: String, setting_id: String)`
- `get_pending_restart_settings()`
- `register_action(command_id: String, meta: Dictionary = {}, callback: Callable = Callable())`
- `metadata_get(scope: String, owner_id: String, key: String, fallback := null)`
- `metadata_set(scope: String, owner_id: String, key: String, value)`
- `metadata_delete(scope: String, owner_id: String, key: String)`
- `metadata_list(scope: String, owner_id := "")`
- `metadata_migrate(mod_id: String, from_version: String, to_version: String, callable: Callable)`
- `report_hook_status(mod_id: String, target: String, status: String, details := {})`
- `get_hook_health()`
- `has_failed_hooks(mod_id := "")`
- `board_get_bounds(opts := {})`
- `board_get_viewport_rect()`
- `board_query_rect(rect: Rect2, opts := {})`
- `board_get_item_bounds(item_id: String)`
- `board_focus_item(item_id: String, opts := {})`

All wrappers enforce namespaced IDs (`mod_id.local_id`) where applicable and return structured result dictionaries with `ok` and `error` fields.

## Hook Health Monitor

Core tracks hook/extension health and exposes diagnostics in the Core Diagnostics tab and support bundle dump.

Status values:

- `healthy`
- `warning`
- `failed`

`report_hook_status()` details can include human-readable context like:

- `reason`
- `method` / `property`
- `missing_methods` / `missing_properties`
- `missing_target_script`
- `scene_lookup_failed` / `node_lookup_failed`
- `late_init`

## Metadata Service (Save-Scoped + Global)

Core now provides a metadata service for mod-owned persistent data with strict namespaced keys (`mod_id.key`).

Scopes:

- `save`
- `board`
- `workspace`
- `window`
- `node`
- `schematic`
- `global`

Notes:

- Save scopes are persisted into save payload (`desktop_data.tajs_core_metadata`) with `user://` fallback.
- Global scope is persisted under Core storage in `user://mods/...`.
- Values are JSON-compatible only (null/bool/int/float/string/array/dictionary with string keys).
- Metadata diagnostics now include scope/owner/key counts and namespace summaries.

## Settings Schema v2

`register_settings_schema()` now supports both:

- legacy format: `{ "my.key": { ...entry... } }`
- v2 payload format:

```gdscript
{
    "schema_version": 2,
    "entries": {
        "my_mod.feature.enabled": {
            "type": "bool",
            "default": true,
            "display_name": "Enable Feature",
            "description": "Turns feature on/off.",
            "category": "General",
            "tags": ["feature", "toggle"],
            "requires_restart": false,
            "live_apply": "MyMod.refresh_feature"
        }
    },
    "migrations": [
        {"from": 1, "to": 2, "rename": {"my_mod.old_key": "my_mod.feature.enabled"}}
    ]
}
```

Supported v2 entry fields include:

- `type`: `bool|int|float|string|enum|color|keybind`
- `default`
- `min|max|step` (numeric)
- `validator` (`Callable(key, value, schema) -> bool|Dictionary`)
- `display_name`, `description`, `category`
- `tags` / `search_terms`
- `requires_restart`
- `live_apply` (`Callable` or action id string)
- `advanced` / `dangerous`

Invalid schema entries now fail gracefully with structured `ok/error` results and do not hard-crash Core startup.

## Core Events

Readiness/lifecycle events:

- `core.ready`: Core runtime services initialized.
- `core.ui.ready`: UI hooks node initialized and baseline UI state detected.
- `core.ui.manager_ready`: Core UI manager/services initialized.

Window menu events:

- `core.window_menu.tab_registered`: tab definition registered.
- `core.window_menu.button_created`: menu button instance created.
- `core.window_menu.tab_opened`: user opened/switched window menu tab.

Desktop/window events:

- `core.desktop.window_create_requested` (cancellable)
- `core.desktop.window_created`
- `core.desktop.window_initialized`
- `core.desktop.window_delete_requested` (cancellable)
- `core.desktop.window_deleted`
- `core.desktop.window_moved`
- `core.desktop.window_restored`
- `core.desktop.window_upgraded`

Window payload shape (base fields):

```gdscript
{
    "window_id": String,
    "window_type_id": String,
    "owner_mod_id": String
}
```

`core.desktop.window_restored` also includes `scene_id`.

## Font Registry

Core now provides a font registry service exposed as `_core.fonts` (or wrapper calls on runtime).

```gdscript
var core: Variant = Engine.get_meta("TajsCore", null)
if core == null:
    return

# Register custom font
var font_result := core.register_font(
    "TajemnikTV-QoL.body",
    "res://mods-unpacked/TajemnikTV-QoL/fonts/MyFont.ttf"
)

# Apply to class-level theme targets
core.apply_font_to_class("Control", "TajemnikTV-QoL.body")
core.apply_font_to_class("Label", "TajemnikTV-QoL.body")
core.apply_font_to_class("RichTextLabel", "TajemnikTV-QoL.body", "normal_font")

# Apply to specific runtime nodes
core.apply_font_to_node($SomePanel, "TajemnikTV-QoL.body")
core.apply_font_to_guide_panel($GuidePanel, "TajemnikTV-QoL.body")
```

Service methods (via `_core.fonts`):

- `register_font(font_id, path)`
- `apply_font_to_class(class_name, font_id, property_name := "font")`
- `apply_font_to_node(node, font_id, opts := {})`
- `apply_font_to_tree(root, font_id, class_filter := "Control")`
- `build_theme(class_map, save_to_user := false, output_path := "")`
- `get_diagnostics()`

`build_theme()` mapping supports both forms:

```gdscript
# Simple
{
    "Label": "TajemnikTV-QoL.body",
    "Button": "TajemnikTV-QoL.body"
}

# Advanced (RichTextLabel-specific properties)
{
    "RichTextLabel": {
        "font_id": "TajemnikTV-QoL.body",
        "properties": ["normal_font", "bold_font", "italics_font", "bold_italics_font", "mono_font"]
    }
}
```

For simple `RichTextLabel` mapping, Core applies common rich-text font properties automatically.

## Theme Editor API

Core now exposes a custom theme profile editor API for mod-owned theme workflows.

```gdscript
var core: Variant = Engine.get_meta("TajsCore", null)
if core == null:
    return

core.theme_create_profile("TajemnikTV-QoL.dark_alt")
core.theme_set_color("TajemnikTV-QoL.dark_alt", "font_color", "Label", Color(0.9, 0.95, 1.0))
core.theme_set_constant("TajemnikTV-QoL.dark_alt", "h_separation", "HBoxContainer", 12)
core.theme_set_stylebox_flat("TajemnikTV-QoL.dark_alt", "panel", "PanelContainer", {
    "bg_color": Color(0.12, 0.14, 0.2, 0.95),
    "border_color": Color(0.26, 0.33, 0.45, 1.0),
    "border_width": 2,
    "corner_radius": 8
})
core.theme_apply_profile_to_node("TajemnikTV-QoL.dark_alt", $PanelContainer)
core.theme_save_profile("TajemnikTV-QoL.dark_alt", "user://themes/qol_dark_alt.tres")
```

Available theme editor wrappers:

- `theme_create_profile(profile_id, base_theme_id := "default")`
- `theme_set_color(profile_id, color_name, class_name, color)`
- `theme_set_constant(profile_id, constant_name, class_name, value)`
- `theme_set_font(profile_id, class_name, property_name, font_id)`
- `theme_set_stylebox_flat(profile_id, stylebox_name, class_name, opts)`
- `theme_apply_profile_to_node(profile_id, node)`
- `theme_save_profile(profile_id, output_path := "")`
- `theme_load_profile(profile_id, input_path)`

Theme profile IDs must be namespaced (`mod_id.local_id`).

## Credits

Free icons from [Streamline](https://streamlinehq.com/free-icons)
