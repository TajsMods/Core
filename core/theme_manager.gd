class_name TajsCoreThemeManager
extends RefCounted

const DEFAULT_THEME_ID := "default"
const DEFAULT_PROFILE_SAVE_PATH := "user://tajs_core_theme_profile_%s.tres"

# ─────────────────────────────────────────────────────────────────────────────
# Font Size Constants (matched to game's JetBrains Mono Thin font)
# These sizes work well with the game's thin font for readability
# ─────────────────────────────────────────────────────────────────────────────
const FONT_SIZE_TINY := 16 # Use sparingly, can be hard to read
const FONT_SIZE_SMALL := 20 # Secondary text, hints
const FONT_SIZE_NORMAL := 24 # Default body text (matches game's default_font_size)
const FONT_SIZE_MEDIUM := 28 # Labels, emphasis (matches game's Label/font_size)
const FONT_SIZE_LARGE := 32 # Titles, buttons (matches game's Button/font_size)
const FONT_SIZE_XLARGE := 36 # Headers

var _themes: Dictionary = {}
var _tooltip_styling: Variant = null
var _tooltip_applied := false
var _profiles: Dictionary = {} # profile_id -> Theme
var _font_registry: Variant = null
var _logger: Variant = null

func _init(default_theme_path: String = "res://themes/main.tres") -> void:
    if ResourceLoader.exists(default_theme_path):
        _themes[DEFAULT_THEME_ID] = load(default_theme_path)
    _init_tooltip_styling()

func set_services(font_registry: Variant, logger: Variant = null) -> void:
    _font_registry = font_registry
    _logger = logger

func _init_tooltip_styling() -> void:
    var base_dir: String = get_script().resource_path.get_base_dir()
    var tooltip_script_path: String = base_dir.path_join("tooltip_styling.gd")
    if ResourceLoader.exists(tooltip_script_path):
        var tooltip_script: Variant = load(tooltip_script_path)
        if tooltip_script != null:
            _tooltip_styling = tooltip_script.new()

func register_theme(theme_id: String, theme: Theme) -> void:
    if theme_id == "" or theme == null:
        return
    _themes[theme_id] = theme

func get_theme(theme_id: String) -> Theme:
    if _themes.has(theme_id):
        return _themes[theme_id]
    return _themes.get(DEFAULT_THEME_ID, null)

func get_game_theme() -> Theme:
    """Returns the game's main.tres theme. Use this to ensure consistent styling."""
    return get_theme(DEFAULT_THEME_ID)

func apply_theme(control: Control, theme_id: String) -> void:
    if control == null:
        return
    var theme := get_theme(theme_id)
    if theme != null:
        control.theme = theme

func apply_game_theme(control: Control) -> void:
    """Apply the game's main theme to a control for consistent fonts and styling."""
    apply_theme(control, DEFAULT_THEME_ID)

func list_themes() -> Array:
    return _themes.keys()

# ─────────────────────────────────────────────────────────────────────────────
# Tooltip Styling API
# ─────────────────────────────────────────────────────────────────────────────

func apply_tooltip_styling() -> void:
    """Apply in-game tooltip styling to the root viewport."""
    if _tooltip_styling == null or _tooltip_applied:
        return
    _tooltip_styling.apply_to_root()
    _tooltip_applied = true

func apply_tooltip_styling_to_theme(theme: Theme) -> void:
    """Apply tooltip styling to a specific theme."""
    if _tooltip_styling == null or theme == null:
        return
    _tooltip_styling.apply_to_theme(theme)

func is_tooltip_styling_applied() -> bool:
    """Check if tooltip styling has been applied."""
    return _tooltip_applied

func reset_tooltip_styling() -> void:
    """Remove tooltip styling and restore defaults."""
    if _tooltip_styling != null:
        _tooltip_styling.reset()
        _tooltip_applied = false

# ─────────────────────────────────────────────────────────────────────────────
# Theme Editor API
# ─────────────────────────────────────────────────────────────────────────────

func create_profile(profile_id: String, base_theme_id: String = DEFAULT_THEME_ID) -> Dictionary:
    var id := profile_id.strip_edges()
    if id == "":
        return {"ok": false, "error": "profile_id_empty"}
    if not _is_namespaced_id(id):
        return {"ok": false, "error": "profile_id_must_be_namespaced_modid.localid", "profile_id": id}
    if _profiles.has(id):
        return {"ok": false, "error": "duplicate_profile_id", "profile_id": id}
    var base_theme := get_theme(base_theme_id)
    if base_theme == null:
        return {"ok": false, "error": "base_theme_unavailable", "base_theme_id": base_theme_id}
    _profiles[id] = base_theme.duplicate(true)
    return {"ok": true, "profile_id": id, "base_theme_id": base_theme_id}

func set_color(profile_id: String, color_name: String, control_class_name: String, color: Color) -> Dictionary:
    var theme := _get_profile(profile_id)
    if theme == null:
        return {"ok": false, "error": "profile_not_found", "profile_id": profile_id}
    theme.set_color(color_name, control_class_name , color)
    return {"ok": true, "profile_id": profile_id, "type": "color", "key": color_name, "class_name": control_class_name }

func set_constant(profile_id: String, constant_name: String, control_class_name: String, value: int) -> Dictionary:
    var theme := _get_profile(profile_id)
    if theme == null:
        return {"ok": false, "error": "profile_not_found", "profile_id": profile_id}
    theme.set_constant(constant_name, control_class_name , value)
    return {"ok": true, "profile_id": profile_id, "type": "constant", "key": constant_name, "class_name": control_class_name }

func set_font(profile_id: String, control_class_name: String, property_name: String, font_id: String) -> Dictionary:
    var theme := _get_profile(profile_id)
    if theme == null:
        return {"ok": false, "error": "profile_not_found", "profile_id": profile_id}
    if _font_registry == null or not _font_registry.has_method("get_font"):
        return {"ok": false, "error": "font_registry_unavailable"}
    var font_res: Font = _font_registry.get_font(font_id)
    if font_res == null:
        return {"ok": false, "error": "font_not_registered", "font_id": font_id}
    theme.set_font(property_name, control_class_name , font_res)
    return {"ok": true, "profile_id": profile_id, "type": "font", "font_id": font_id, "class_name": control_class_name , "property": property_name}

func set_stylebox_flat(profile_id: String, stylebox_name: String, control_class_name: String, opts: Dictionary) -> Dictionary:
    var theme := _get_profile(profile_id)
    if theme == null:
        return {"ok": false, "error": "profile_not_found", "profile_id": profile_id}
    var box := StyleBoxFlat.new()
    if opts.has("bg_color"):
        box.bg_color = opts["bg_color"]
    if opts.has("border_color"):
        box.border_color = opts["border_color"]
    if opts.has("border_width"):
        var w: int = int(opts["border_width"])
        box.border_width_left = w
        box.border_width_top = w
        box.border_width_right = w
        box.border_width_bottom = w
    if opts.has("corner_radius"):
        var r: int = int(opts["corner_radius"])
        box.set_corner_radius_all(r)
    theme.set_stylebox(stylebox_name, control_class_name , box)
    return {"ok": true, "profile_id": profile_id, "type": "stylebox_flat", "key": stylebox_name, "class_name": control_class_name }

func apply_profile_to_node(profile_id: String, node: Control) -> Dictionary:
    if node == null:
        return {"ok": false, "error": "node_null"}
    var theme := _get_profile(profile_id)
    if theme == null:
        return {"ok": false, "error": "profile_not_found", "profile_id": profile_id}
    node.theme = theme
    return {"ok": true, "profile_id": profile_id, "node": str(node.name)}

func save_profile(profile_id: String, output_path: String = "") -> Dictionary:
    if not _is_namespaced_id(profile_id):
        return {"ok": false, "error": "profile_id_must_be_namespaced_modid.localid", "profile_id": profile_id}
    var theme := _get_profile(profile_id)
    if theme == null:
        return {"ok": false, "error": "profile_not_found", "profile_id": profile_id}
    var path := output_path if output_path != "" else DEFAULT_PROFILE_SAVE_PATH % _profile_file_token(profile_id)
    var err: Error = ResourceSaver.save(theme, path)
    if err != OK:
        return {"ok": false, "error": "save_failed", "profile_id": profile_id, "path": path, "error_code": int(err)}
    return {"ok": true, "profile_id": profile_id, "path": path}

func load_profile(profile_id: String, input_path: String) -> Dictionary:
    var id := profile_id.strip_edges()
    if not _is_namespaced_id(id):
        return {"ok": false, "error": "profile_id_must_be_namespaced_modid.localid", "profile_id": profile_id}
    if input_path == "" or not ResourceLoader.exists(input_path):
        return {"ok": false, "error": "path_not_found", "profile_id": profile_id, "path": input_path}
    var res: Variant = load(input_path)
    if not (res is Theme):
        return {"ok": false, "error": "resource_not_theme", "profile_id": profile_id, "path": input_path}
    _profiles[id] = res
    return {"ok": true, "profile_id": id, "path": input_path}

func list_profiles() -> Array:
    var ids := _profiles.keys()
    ids.sort()
    return ids

func get_profile_theme(profile_id: String) -> Theme:
    return _get_profile(profile_id)

func get_diagnostics() -> Dictionary:
    return {
        "profiles": list_profiles(),
        "profile_count": _profiles.size()
    }

func _get_profile(profile_id: String) -> Theme:
    return _profiles.get(profile_id, null)

func _is_namespaced_id(id: String) -> bool:
    var idx := id.find(".")
    return idx > 0 and idx < id.length() - 1

func _profile_file_token(profile_id: String) -> String:
    var sanitized := profile_id.replace("/", "_").replace("\\", "_").replace(":", "_")
    sanitized = sanitized.replace("..", "_")
    return sanitized
