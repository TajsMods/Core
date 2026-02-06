class_name TajsCoreTooltipStyling
extends RefCounted

# Game's color palette (extracted from main.tres)
const COLOR_BG_DARK := Color(0.0862745, 0.101961, 0.137255, 1.0)
const COLOR_BG_MEDIUM := Color(0.101961, 0.12549, 0.172549, 1.0)
const COLOR_BORDER := Color(0.270064, 0.332386, 0.457031, 1.0)
const COLOR_BORDER_SUBTLE := Color(0.129261, 0.159091, 0.21875, 1.0)
const COLOR_TEXT := Color(0.85, 0.97, 1.0, 1.0)
const CORNER_RADIUS := 8
const BORDER_WIDTH := 2
const PADDING := 8

var _applied := false
var _theme: Theme = null

func apply_to_viewport(viewport: Viewport) -> void:
    """Apply tooltip styling to a viewport's theme."""
    if viewport == null or _applied:
        return
    
    # Try to get the game's main theme first
    var main_theme: Theme = null
    if ResourceLoader.exists("res://themes/main.tres"):
        main_theme = load("res://themes/main.tres")
    
    if main_theme != null:
        _theme = main_theme
    elif viewport.get("theme") != null:
        _theme = viewport.get("theme")
    else:
        _theme = Theme.new()
        viewport.theme = _theme
    
    _setup_tooltip_panel_style()
    _setup_tooltip_label_style()
    _applied = true

func apply_to_root() -> void:
    """Apply tooltip styling to the root viewport using the game's main theme."""
    if _applied:
        return
    
    # Apply directly to the game's main theme for global effect
    var main_theme: Theme = null
    if ResourceLoader.exists("res://themes/main.tres"):
        main_theme = load("res://themes/main.tres")
    
    if main_theme != null:
        _theme = main_theme
        _setup_tooltip_panel_style()
        _setup_tooltip_label_style()
        _applied = true
        return
    
    # Fallback to viewport theme if main theme not found
    if Engine.get_main_loop() == null:
        return
    var root: Variant = Engine.get_main_loop().root
    if root != null:
        apply_to_viewport(root)

func apply_to_theme(theme: Theme) -> void:
    """Apply tooltip styles directly to an existing theme."""
    if theme == null:
        return
    _theme = theme
    _setup_tooltip_panel_style()
    _setup_tooltip_label_style()
    _applied = true

func _setup_tooltip_panel_style() -> void:
    """Configure the tooltip panel (background, border, corners)."""
    if _theme == null:
        return
    
    var panel_style := StyleBoxFlat.new()
    
    # Background
    panel_style.bg_color = COLOR_BG_DARK
    
    # Border
    panel_style.border_width_left = BORDER_WIDTH
    panel_style.border_width_top = BORDER_WIDTH
    panel_style.border_width_right = BORDER_WIDTH
    panel_style.border_width_bottom = BORDER_WIDTH
    panel_style.border_color = COLOR_BORDER
    
    # Corners
    panel_style.corner_radius_top_left = CORNER_RADIUS
    panel_style.corner_radius_top_right = CORNER_RADIUS
    panel_style.corner_radius_bottom_right = CORNER_RADIUS
    panel_style.corner_radius_bottom_left = CORNER_RADIUS
    
    # Padding (content margins)
    panel_style.content_margin_left = PADDING
    panel_style.content_margin_top = PADDING
    panel_style.content_margin_right = PADDING
    panel_style.content_margin_bottom = PADDING
    
    # Subtle shadow for depth
    panel_style.shadow_color = Color(0, 0, 0, 0.3)
    panel_style.shadow_size = 4
    
    # Apply to theme
    _theme.set_stylebox("panel", "TooltipPanel", panel_style)

func _setup_tooltip_label_style() -> void:
    """Configure the tooltip label (font, color, size)."""
    if _theme == null:
        return
    
    # Font color
    _theme.set_color("font_color", "TooltipLabel", COLOR_TEXT)
    
    # Font size - match the theme's default font size (24)
    _theme.set_font_size("font_size", "TooltipLabel", 24)
    
    # Don't set a custom font - let it inherit from the theme's default_font
    # This ensures tooltips look consistent with the rest of the UI

func is_applied() -> bool:
    return _applied

func reset() -> void:
    """Remove tooltip styling (restore defaults)."""
    if _theme == null:
        return
    
    # Clear tooltip styles
    if _theme.has_stylebox("panel", "TooltipPanel"):
        _theme.clear_stylebox("panel", "TooltipPanel")
    if _theme.has_color("font_color", "TooltipLabel"):
        _theme.clear_color("font_color", "TooltipLabel")
    if _theme.has_font_size("font_size", "TooltipLabel"):
        _theme.clear_font_size("font_size", "TooltipLabel")
    if _theme.has_font("font", "TooltipLabel"):
        _theme.clear_font("font", "TooltipLabel")
    
    _applied = false
