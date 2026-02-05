class_name TajsCoreThemeManager
extends RefCounted

const DEFAULT_THEME_ID := "default"

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
var _tooltip_styling = null
var _tooltip_applied := false

func _init(default_theme_path: String = "res://themes/main.tres") -> void:
    if ResourceLoader.exists(default_theme_path):
        _themes[DEFAULT_THEME_ID] = load(default_theme_path)
    _init_tooltip_styling()

func _init_tooltip_styling() -> void:
    var base_dir: String = get_script().resource_path.get_base_dir()
    var tooltip_script_path: String = base_dir.path_join("tooltip_styling.gd")
    if ResourceLoader.exists(tooltip_script_path):
        var tooltip_script = load(tooltip_script_path)
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
