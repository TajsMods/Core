class_name TajsCoreColorPickerPanel
extends PanelContainer

# Signals
signal color_changed(color: Color) # Fires live while dragging/typing
signal color_committed(color: Color) # Fires on commit (release/enter)

# Constants -  layout
const PANEL_SIZE: Variant = Vector2(500, 320)
const PLANE_SIZE: Variant = Vector2(200, 170)
const SLIDER_WIDTH: Variant = 30
const LEFT_COLUMN_WIDTH: Variant = 140
const SWATCH_SIZE: Variant = 26
const SWATCH_COLS: Variant = 4
const SWATCH_ROWS: Variant = 4
const RECENT_COLS: Variant = 4
const RECENT_ROWS: Variant = 4

# Default swatches (16 colors)
const DEFAULT_SWATCHES: Variant = [
    Color.WHITE, Color.BLACK, Color.RED, Color.GREEN,
    Color.BLUE, Color.YELLOW, Color.CYAN, Color.MAGENTA,
    Color(0.5, 0.5, 0.5), Color(0.8, 0.4, 0.0), Color(0.5, 0.0, 0.5), Color(0.0, 0.5, 0.5),
    Color(1.0, 0.5, 0.5), Color(0.5, 1.0, 0.5), Color(0.5, 0.5, 1.0), Color(1.0, 0.8, 0.6)
]

# Current color state (HSV model)
var _hue: float = 0.0 # 0.0 - 1.0
var _saturation: float = 0.0 # 0.0 - 1.0
var _value: float = 1.0 # 0.0 - 1.0
var _alpha: float = 1.0 # 0.0 - 1.0

# Dragging state
var _drag_position: Variant = null
var _dragging_plane: bool = false
var _dragging_hue: bool = false
var _dragging_alpha: bool = false
var _updating_ui: bool = false

# UI References
var _sv_plane: Control # Saturation-Value Plane
var _sv_plane_cursor: Control
var _hue_slider: Control
var _alpha_slider: Control
var _color_preview: ColorRect
var _hex_input: LineEdit
var _r_spinbox: SpinBox
var _g_spinbox: SpinBox
var _b_spinbox: SpinBox
var _a_spinbox: SpinBox
var _swatch_buttons: Array[ColorRect] = []
var _recent_buttons: Array[ColorRect] = []

const DEFAULT_SETTINGS_KEY := "core.ui.color_picker"
var _recent_colors: Array[Color] = []
var _custom_swatches: Array[Color] = []

# UI
var _reset_btn: Button

# Shader
var _sv_shader: Shader
var _sv_material: ShaderMaterial
var _settings: Variant = null
var _settings_key: String = DEFAULT_SETTINGS_KEY


func setup(settings: Variant = null, settings_key: String = "") -> void:
    _settings = settings
    if settings_key != "":
        _settings_key = settings_key
    if is_inside_tree():
        _load_data()
        _update_all_ui()


func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.get("button_index") == MOUSE_BUTTON_LEFT:
            if event.get("pressed"):
                _drag_position = global_position.distance_to(get_global_mouse_position())
                if _drag_position < 2000: # Simple check, store offset
                    _drag_position = get_global_mouse_position() - global_position
            else:
                _drag_position = null
    elif event is InputEventMouseMotion and _drag_position != null:
        global_position = get_global_mouse_position() - _drag_position


func _notification(what: int) -> void:
    if what == NOTIFICATION_VISIBILITY_CHANGED:
        if not is_visible_in_tree():
            # Panel closed/hidden: save current state to recent
            _add_to_recent(get_color())


func _init():
    custom_minimum_size = PANEL_SIZE


func _ready() -> void:
    _setup_panel_style()
    if _settings == null:
        _settings = _get_core_settings()
    _build_ui()
    _load_data()
    _update_all_ui()


func _setup_panel_style() -> void:
    # Match game theme: dark blue-gray with blue border
    var style: Variant = StyleBoxFlat.new()
    style.bg_color = Color(0.0862745, 0.101961, 0.137255, 1.0) # Game bg color
    style.border_color = Color(0.270064, 0.332386, 0.457031, 1.0) # Game border color
    style.set_border_width_all(2)
    style.set_corner_radius_all(16) # Game uses 16px corners
    style.set_content_margin_all(12)
    style.shadow_color = Color(0, 0, 0, 0.25)
    style.shadow_size = 6
    add_theme_stylebox_override("panel", style)


func _build_ui() -> void:
    var main_hbox: Variant = HBoxContainer.new()
    main_hbox.add_theme_constant_override("separation", 8)
    add_child(main_hbox)
    
    # === LEFT COLUMN ===
    var left_column: Variant = VBoxContainer.new()
    left_column.custom_minimum_size.x = LEFT_COLUMN_WIDTH
    left_column.add_theme_constant_override("separation", 4)
    main_hbox.add_child(left_column)
    
    _build_swatches_section(left_column)
    _build_recent_section(left_column)
    
    # === CENTER + RIGHT COLUMN ===
    var center_vbox: Variant = VBoxContainer.new()
    center_vbox.add_theme_constant_override("separation", 6)
    center_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    main_hbox.add_child(center_vbox)
    
    # Top row: SV plane + Hue slider
    var top_hbox: Variant = HBoxContainer.new()
    top_hbox.add_theme_constant_override("separation", 6)
    center_vbox.add_child(top_hbox)
    
    _build_sv_plane(top_hbox)
    _build_hue_slider(top_hbox)
    
    # Alpha slider
    _build_alpha_slider(center_vbox)
    
    # Color preview + Hex
    _build_preview_row(center_vbox)
    
    # Bottom: RGBA Grid
    _build_rgba_grid(center_vbox)


func _build_rgba_grid(parent: Control) -> void:
    var grid: Variant = GridContainer.new()
    grid.columns = 4
    grid.add_theme_constant_override("h_separation", 8)
    grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    parent.add_child(grid)
    
    _r_spinbox = _create_channel_spinbox("R", grid)
    _g_spinbox = _create_channel_spinbox("G", grid)
    _b_spinbox = _create_channel_spinbox("B", grid)
    _a_spinbox = _create_channel_spinbox("A", grid)
    
    _r_spinbox.value_changed.connect(func(val): _on_spinbox_changed())
    _g_spinbox.value_changed.connect(func(val): _on_spinbox_changed())
    _b_spinbox.value_changed.connect(func(val): _on_spinbox_changed())
    _a_spinbox.value_changed.connect(func(val): _on_spinbox_changed())


func _create_channel_spinbox(label_text: String, parent: Control) -> SpinBox:
    var container: Variant = VBoxContainer.new()
    container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    container.add_theme_constant_override("separation", 2)
    parent.add_child(container)
    
    var lbl: Variant = Label.new()
    lbl.text = label_text
    lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    lbl.add_theme_font_size_override("font_size", 15)
    container.add_child(lbl)
    
    var spinbox: Variant = SpinBox.new()
    spinbox.min_value = 0
    spinbox.max_value = 255
    spinbox.step = 1
    spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    spinbox.custom_minimum_size.x = 56
    spinbox.add_theme_font_size_override("font_size", 15)
    
    var line_edit: Variant = spinbox.get_line_edit()
    if line_edit:
        line_edit.add_theme_font_size_override("font_size", 15)
        line_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
    container.add_child(spinbox)
    
    return spinbox


func _build_swatches_section(parent: Control) -> void:
    var label: Variant = Label.new()
    label.text = "Swatches"
    label.add_theme_font_size_override("font_size", 15)
    label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
    parent.add_child(label)
    
    var grid: Variant = GridContainer.new()
    grid.columns = SWATCH_COLS
    grid.add_theme_constant_override("h_separation", 2)
    grid.add_theme_constant_override("v_separation", 2)
    parent.add_child(grid)
    
    for i: Variant in range(SWATCH_COLS * SWATCH_ROWS):
        var swatch: Variant = _create_color_swatch(DEFAULT_SWATCHES[i] if i < DEFAULT_SWATCHES.size() else Color.BLACK)
        grid.add_child(swatch)
        _swatch_buttons.append(swatch)
        
        var idx: Variant = i
        swatch.gui_input.connect(func(event): _on_swatch_input(event, idx))


func _build_recent_section(parent: Control) -> void:
    var label: Variant = Label.new()
    label.text = "Recent"
    label.add_theme_font_size_override("font_size", 15)
    label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
    parent.add_child(label)
    
    var grid: Variant = GridContainer.new()
    grid.columns = RECENT_COLS
    grid.add_theme_constant_override("h_separation", 2)
    grid.add_theme_constant_override("v_separation", 2)
    parent.add_child(grid)
    
    for i: Variant in range(RECENT_COLS * RECENT_ROWS):
        var swatch: Variant = _create_color_swatch(Color(0.2, 0.2, 0.2, 0.5))
        grid.add_child(swatch)
        _recent_buttons.append(swatch)
        
        var idx: Variant = i
        swatch.gui_input.connect(func(event): _on_recent_input(event, idx))


func _create_color_swatch(color: Color) -> ColorRect:
    var swatch: Variant = ColorRect.new()
    swatch.custom_minimum_size = Vector2(SWATCH_SIZE, SWATCH_SIZE)
    swatch.color = color
    swatch.mouse_filter = Control.MOUSE_FILTER_STOP
    return swatch


func _build_sv_plane(parent: Control) -> void:
    var plane_container: Variant = Control.new()
    plane_container.custom_minimum_size = PLANE_SIZE
    plane_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
    plane_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    parent.add_child(plane_container)
    
    _sv_plane = ColorRect.new()
    _sv_plane.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _sv_plane.mouse_filter = Control.MOUSE_FILTER_STOP
    plane_container.add_child(_sv_plane)
    
    _sv_shader = load("res://mods-unpacked/TajemnikTV-Core/core/ui/shaders/sv_plane.gdshader")
    if _sv_shader:
        _sv_material = ShaderMaterial.new()
        _sv_material.shader = _sv_shader
        _sv_plane.material = _sv_material
    else:
        _sv_plane.set("color", Color.GRAY)
    
    _sv_plane_cursor = Control.new()
    _sv_plane_cursor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _sv_plane_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _sv_plane_cursor.draw.connect(_draw_sv_cursor)
    plane_container.add_child(_sv_plane_cursor)
    
    _sv_plane.gui_input.connect(_on_sv_plane_input)


func _draw_sv_cursor() -> void:
    # Saturation is X, Value is inverted Y
    var pos: Variant = Vector2(_saturation * _sv_plane_cursor.size.x, (1.0 - _value) * _sv_plane_cursor.size.y)
    var radius: Variant = 6.0
    _sv_plane_cursor.draw_arc(pos, radius, 0, TAU, 24, Color.BLACK, 2.0)
    _sv_plane_cursor.draw_arc(pos, radius - 1.5, 0, TAU, 24, Color.WHITE, 1.5)


func _build_hue_slider(parent: Control) -> void:
    var slider_container: Variant = VBoxContainer.new()
    slider_container.add_theme_constant_override("separation", 2)
    parent.add_child(slider_container)
    
    var label: Variant = Label.new()
    label.text = "H"
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 15)
    slider_container.add_child(label)
    
    var track_container: Variant = Control.new()
    track_container.custom_minimum_size = Vector2(SLIDER_WIDTH, 0)
    track_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
    slider_container.add_child(track_container)
    
    _hue_slider = Control.new()
    _hue_slider.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _hue_slider.mouse_filter = Control.MOUSE_FILTER_STOP
    _hue_slider.draw.connect(_draw_hue_slider)
    _hue_slider.gui_input.connect(_on_hue_slider_input)
    track_container.add_child(_hue_slider)


func _draw_hue_slider() -> void:
    var rect: Variant = Rect2(Vector2.ZERO, _hue_slider.size)
    var colors: Variant = PackedColorArray([
        Color(1, 0, 0), Color(1, 1, 0), Color(0, 1, 0),
        Color(0, 1, 1), Color(0, 0, 1), Color(1, 0, 1), Color(1, 0, 0)
    ])
    
    # Draw rainbow gradient
    var points: Variant = PackedVector2Array()
    var final_colors: Variant = PackedColorArray()
    
    # Approximation using rects or lines since GradientTexture2D isn't easily created on fly easily
    # Simple loop drawing lines
    var h: Variant = _hue_slider.size.y
    for y: Variant in range(int(h)):
        var t: Variant = float(y) / h
        var c: Variant = Color.from_hsv(1.0 - t, 1.0, 1.0) # 1.0 - t to match Hue 0 at top
        _hue_slider.draw_line(Vector2(0, y), Vector2(_hue_slider.size.x, y), c)
        
    _hue_slider.draw_rect(rect, Color(0.3, 0.3, 0.3), false, 1.0)
    
    # Cursor
    var handle_y: Variant = (1.0 - _hue) * _hue_slider.size.y
    _hue_slider.draw_rect(Rect2(-1, handle_y - 2, _hue_slider.size.x + 2, 4), Color.WHITE, false, 2.0)


func _build_alpha_slider(parent: Control) -> void:
    var row: Variant = HBoxContainer.new()
    row.add_theme_constant_override("separation", 4)
    parent.add_child(row)
    
    var label: Variant = Label.new()
    label.text = "A"
    label.add_theme_font_size_override("font_size", 15)
    row.add_child(label)
    
    var track_container: Variant = Control.new()
    track_container.custom_minimum_size = Vector2(0, 16)
    track_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(track_container)
    
    _alpha_slider = Control.new()
    _alpha_slider.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _alpha_slider.mouse_filter = Control.MOUSE_FILTER_STOP
    _alpha_slider.draw.connect(_draw_alpha_slider)
    _alpha_slider.gui_input.connect(_on_alpha_slider_input)
    track_container.add_child(_alpha_slider)


func _draw_alpha_slider() -> void:
    var rect: Variant = Rect2(Vector2.ZERO, _alpha_slider.size)
    var checker_size: Variant = 4.0
    var checker_step: Variant = int(checker_size)
    for x: Variant in range(0, int(_alpha_slider.size.x), checker_step):
        for y: Variant in range(0, int(_alpha_slider.size.y), checker_step):
            var cell_x: Variant = int(float(x) / checker_size)
            var cell_y: Variant = int(float(y) / checker_size)
            var is_light: Variant = (cell_x + cell_y) % 2 == 0
            var checker_color: Variant = Color(0.4, 0.4, 0.4) if is_light else Color(0.25, 0.25, 0.25)
            _alpha_slider.draw_rect(Rect2(x, y, checker_step, checker_step), checker_color)
    
    # Gradient from Transparent to Opaque current color
    var c: Variant = get_color()
    c.a = 1.0
    for x: Variant in range(int(_alpha_slider.size.x)):
        var t: Variant = float(x) / _alpha_slider.size.x
        var draw_c: Variant = c
        draw_c.a = t
        _alpha_slider.draw_line(Vector2(x, 0), Vector2(x, _alpha_slider.size.y), draw_c)
        
    _alpha_slider.draw_rect(rect, Color(0.3, 0.3, 0.3), false, 1.0)
    var handle_x: Variant = _alpha * _alpha_slider.size.x
    _alpha_slider.draw_rect(Rect2(handle_x - 2, -1, 4, _alpha_slider.size.y + 2), Color.WHITE, false, 2.0)


func _build_preview_row(parent: Control) -> void:
    var row: Variant = HBoxContainer.new()
    row.add_theme_constant_override("separation", 6)
    parent.add_child(row)
    
    _color_preview = ColorRect.new()
    _color_preview.custom_minimum_size = Vector2(32, 20)
    _color_preview.color = get_color()
    row.add_child(_color_preview)
    
    var hex_label: Variant = Label.new()
    hex_label.text = "#"
    hex_label.add_theme_font_size_override("font_size", 15)
    row.add_child(hex_label)
    
    _hex_input = LineEdit.new()
    _hex_input.custom_minimum_size.x = 76
    _hex_input.max_length = 8
    _hex_input.add_theme_font_size_override("font_size", 15)
    _hex_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _hex_input.text_submitted.connect(_on_hex_submitted)
    row.add_child(_hex_input)
    
    # Reset swatches button
    _reset_btn = Button.new()
    _reset_btn.text = "Reset"
    _reset_btn.add_theme_font_size_override("font_size", 15)
    _reset_btn.custom_minimum_size.x = 60
    _reset_btn.tooltip_text = "Reset swatches to defaults"
    _reset_btn.pressed.connect(_reset_swatches)
    row.add_child(_reset_btn)


# === INPUT HANDLERS ===

func _on_sv_plane_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.get("button_index") == MOUSE_BUTTON_LEFT:
            if event.get("pressed"):
                _dragging_plane = true
                _update_sv_from_mouse(event.get("position"))
            else:
                _dragging_plane = false
    elif event is InputEventMouseMotion and _dragging_plane:
        _update_sv_from_mouse(event.get("position"))

func _update_sv_from_mouse(pos: Vector2) -> void:
    var s: Variant = clamp(pos.x / _sv_plane.size.x, 0.0, 1.0)
    var v: Variant = clamp(1.0 - (pos.y / _sv_plane.size.y), 0.0, 1.0) # V is inverted Y
    if _saturation != s or _value != v:
        _saturation = s
        _value = v
        _update_all_ui(true)

func _on_hue_slider_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.get("button_index") == MOUSE_BUTTON_LEFT:
            if event.get("pressed"):
                _dragging_hue = true
                _update_hue_from_mouse(event.get("position"))
            else:
                _dragging_hue = false
    elif event is InputEventMouseMotion and _dragging_hue:
        _update_hue_from_mouse(event.get("position"))

func _update_hue_from_mouse(pos: Vector2) -> void:
    var h: Variant = clamp(1.0 - (pos.y / _hue_slider.size.y), 0.0, 1.0) # Inverted so 0 (Red) is at top? Wait. HSV hue circle: 0=Red, 1/3=Green, 2/3=Blue.
    # Usually Hue slider goes 0->1 or 1->0. If 0 is Red.
    # 1.0 is also Red.
    # Let's map Top=1.0 (Red), Bottom=0.0 (Red).
    if _hue != h:
        _hue = h
        _update_all_ui(true)

func _on_alpha_slider_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.get("button_index") == MOUSE_BUTTON_LEFT:
            if event.get("pressed"):
                _dragging_alpha = true
                _update_alpha_from_mouse(event.get("position"))
            else:
                _dragging_alpha = false
    elif event is InputEventMouseMotion and _dragging_alpha:
        _update_alpha_from_mouse(event.get("position"))

func _update_alpha_from_mouse(pos: Vector2) -> void:
    var a: Variant = clamp(pos.x / _alpha_slider.size.x, 0.0, 1.0)
    if _alpha != a:
        _alpha = a
        _update_all_ui(true)

func _on_spinbox_changed() -> void:
    if _updating_ui: return
    
    var c: Variant = Color(
        _r_spinbox.value / 255.0,
        _g_spinbox.value / 255.0,
        _b_spinbox.value / 255.0,
        _a_spinbox.value / 255.0
    )
    set_color(c, true)

func _on_hex_submitted(text: String) -> void:
    if text.is_valid_html_color():
        set_color(Color(text), true)
        _commit_color()
    else:
        _hex_input.text = get_color().to_html()

func _on_swatch_input(event: InputEvent, index: int) -> void:
    # Left click to pick, Right click to save
    if event is InputEventMouseButton and event.get("pressed"):
        if event.get("button_index") == MOUSE_BUTTON_LEFT:
            set_color(_swatch_buttons[index].color, true)
            _commit_color()
        elif event.get("button_index") == MOUSE_BUTTON_RIGHT:
            _custom_swatches[index] = get_color()
            _swatch_buttons[index].color = get_color()
            _save_swatches()


func _on_recent_input(event: InputEvent, index: int) -> void:
    if event is InputEventMouseButton and event.get("pressed"):
        if event.get("button_index") == MOUSE_BUTTON_LEFT:
            if index < _recent_colors.size():
                set_color(_recent_colors[index], true)
                _commit_color()


# === CORE LOGIC ===

func set_color(c: Color, emit_color_signal: bool = false) -> void:
    # Update HSV state from color
    # Color.to_hsv() returns Vector3 (h, s, v)
    # But in Godot 3.x/4.x Color struct has h, s, v properties usually.
    # Godot 4: c.h, c.s, c.v
    _hue = c.h
    _saturation = c.s
    _value = c.v
    _alpha = c.a
    
    _update_all_ui(emit_color_signal)

func get_color() -> Color:
    return Color.from_hsv(_hue, _saturation, _value, _alpha)

func _commit_color() -> void:
    var c: Variant = get_color()
    color_committed.emit(c)
    _add_to_recent(c)


func _update_all_ui(emit_color_signal: bool = false) -> void:
    _updating_ui = true
    
    # Safety check: if UI hasn't been built yet, just return.
    # The state variables (_hue, etc.) are already updated, so when _ready() runs,
    # it will call _update_all_ui() and reflect the state correctly.
    if not is_instance_valid(_sv_plane_cursor):
        _updating_ui = false
        return
    
    var c: Variant = get_color()
    
    # Update shader
    if _sv_material:
        _sv_material.set_shader_parameter("hue", _hue)
    
    # Queue redraws
    _sv_plane_cursor.queue_redraw()
    _hue_slider.queue_redraw()
    _alpha_slider.queue_redraw()
    _color_preview.color = c
    
    # Update Inputs (only if not focused or specialized logic? For now update all)
    _r_spinbox.value = c.r8
    _g_spinbox.value = c.g8
    _b_spinbox.value = c.b8
    _a_spinbox.value = c.a8
    
    if not _hex_input.has_focus():
        _hex_input.text = c.to_html(true) # Include alpha
    
    _updating_ui = false
    
    if emit_color_signal:
        color_changed.emit(c)


# === PERSISTENCE ===

func _load_data() -> void:
    # Defaults
    _recent_colors.resize(RECENT_COLS * RECENT_ROWS)
    _recent_colors.fill(Color.BLACK)
    
    _custom_swatches.clear()
    _custom_swatches.append_array(DEFAULT_SWATCHES)
    _custom_swatches.resize(SWATCH_COLS * SWATCH_ROWS)
    
    var data: Variant = _read_config_file()
    var cp_data: Dictionary = {}
    if data.has("color_picker") and data["color_picker"] is Dictionary:
        cp_data = data["color_picker"]
    elif data is Dictionary:
        cp_data = data
    if cp_data.has("recent_colors"):
        var saved_recent: Variant = cp_data["recent_colors"]
        for i: Variant in range(min(saved_recent.size(), _recent_colors.size())):
            _recent_colors[i] = Color(saved_recent[i])
    if cp_data.has("swatches"):
        var saved_swatches: Variant = cp_data["swatches"]
        for i: Variant in range(min(saved_swatches.size(), _custom_swatches.size())):
            _custom_swatches[i] = Color(saved_swatches[i])
    
    # Update buttons
    for i: Variant in range(_recent_buttons.size()):
        _recent_buttons[i].color = _recent_colors[i]
        
    for i: Variant in range(_swatch_buttons.size()):
        if i < _custom_swatches.size():
            _swatch_buttons[i].color = _custom_swatches[i]
        else:
            _swatch_buttons[i].color = Color.BLACK


func _save_recent() -> void:
    var data: Variant = _read_config_file()
    if not data.has("color_picker"): data["color_picker"] = {}
    
    var arr: Variant = []
    for c: Variant in _recent_colors:
        arr.append(c.to_html())
    
    data["color_picker"]["recent_colors"] = arr
    _write_config_file(data)


func _save_swatches() -> void:
    var data: Variant = _read_config_file()
    if not data.has("color_picker"): data["color_picker"] = {}
    
    var arr: Variant = []
    for c: Variant in _custom_swatches:
        arr.append(c.to_html())
        
    data["color_picker"]["swatches"] = arr
    _write_config_file(data)


func _add_to_recent(c: Color) -> void:
    # Avoid duplicates at front
    if _recent_colors.size() > 0 and _recent_colors[0] == c:
        return
        
    _recent_colors.pop_back()
    _recent_colors.push_front(c)
    
    # Update UI
    for i: Variant in range(_recent_buttons.size()):
        _recent_buttons[i].color = _recent_colors[i]
        
    _save_recent()

func _reset_swatches() -> void:
    _custom_swatches.clear()
    _custom_swatches.append_array(DEFAULT_SWATCHES)
    _custom_swatches.resize(SWATCH_COLS * SWATCH_ROWS)
    
    for i: Variant in range(_swatch_buttons.size()):
        if i < _custom_swatches.size():
            _swatch_buttons[i].color = _custom_swatches[i]
    
    var data: Variant = _read_config_file()
    if data.has("color_picker"):
        data["color_picker"].erase("swatches")
        _write_config_file(data)


# Helper functions to match ConfigManager's JSON handling
func _read_config_file() -> Dictionary:
    var settings: Variant = _settings
    if settings == null:
        settings = _get_core_settings()
    if settings == null:
        return {}
    if _settings_key == "":
        return {}
    return settings.get_dict(_settings_key, {})

func _write_config_file(data: Dictionary) -> void:
    var settings: Variant = _settings
    if settings == null:
        settings = _get_core_settings()
    if settings == null:
        return
    if _settings_key == "":
        return
    settings.set_value(_settings_key, data)

func _get_core_settings() -> Variant:
    if Engine.has_meta("TajsCore"):
        var core: Variant = Engine.get_meta("TajsCore")
        if core != null and core.settings != null:
            return core.settings
    return null
