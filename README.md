# Taj's Core Framework

## How to use

Currently available docs are outdated and possibly will stay that way, until all the Core features are added and complete (which is never lol?)
Website Docs: <https://tajsmods.github.io/docs/core/main/> (Possibly worst source of information, these are there mostly as a placeholder)
Deepwiki: <https://deepwiki.com/TajsMods/Core> (Can be updated every 7 days)

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
- `register_action(command_id: String, meta: Dictionary = {}, callback: Callable = Callable())`

All wrappers enforce namespaced IDs (`mod_id.local_id`) where applicable and return structured result dictionaries with `ok` and `error` fields.

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


## Credits

Free icons from [Streamline](https://streamlinehq.com/free-icons)