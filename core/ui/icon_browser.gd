# ==============================================================================
# Taj's Core - Icon Browser
# Author: TajemnikTV
# Description: Unified icon picker UI with indexing support.
# ==============================================================================
class_name TajsCoreIconBrowser
extends RefCounted

signal icon_selected(icon_name: String, icon_path: String)
signal icon_confirmed(icon_id: String, entry: Dictionary)
signal selection_cleared()

const GRID_COLUMNS_MIN := 4
const GRID_COLUMNS_SMALL := 6 # For smaller viewports
const ICON_SIZE := 48
const ICON_SIZE_SMALL := 40
const ICON_SPACING := 8 # Reduced from 6
const ICON_SPACING_SMALL := 8
const MAX_SCROLL_HEIGHT := 360
const MIN_SCROLL_HEIGHT := 180
const SCROLL_HEIGHT_RATIO := 0.45 # Portion of parent viewport
const SMALL_VIEWPORT_THRESHOLD := 700 # Height threshold for compact mode
const SMALL_WIDTH_THRESHOLD := 620
const GRID_RIGHT_MARGIN := 12
const GRID_LEFT_MARGIN := 12
const PREVIEW_SIZE := 48
const DEFAULT_SEARCH_HINT := "Search icons..."
const DEFAULT_SELECT_TEXT := "Select"
const DEFAULT_CLEAR_TEXT := "Clear"
const GROUP_BASE := "base"
const GROUP_CORE := "core"
const GROUP_MODS := "mods"

var _registry: Variant # TajsCoreIconRegistry - using Variant to avoid circular dependency
var _all_icons: Array = []
var _icons_by_id: Dictionary = {}
var _filtered_icons: Array = []
var _buttons: Array = []
var _tab_buttons: Dictionary = {}
var _search_box: LineEdit
var _grid: GridContainer
var _preview_texture: TextureRect
var _preview_label: Label
var _preview_meta: Label
var _select_btn: Button
var _clear_btn: Button
var _selected_entry: Variant = null # Can be Dictionary or null
var _selection_callback: Variant = null # Can be Callable or null
var _allowed_sources: Array = []
var _allowed_source_set: Dictionary = {}
var _tab_groups: Array = []
var _tab_counts: Dictionary = {}
var _active_tab: String = GROUP_BASE
var _initial_selected_id: String = ""
var _pending_initial_selection: bool = false
var _default_texture: Texture2D
var _allow_clear: bool = true
var _show_source_tabs: bool = true
var _show_select_button: bool = true
var _clear_button_text: String = DEFAULT_CLEAR_TEXT
var _select_button_text: String = DEFAULT_SELECT_TEXT
var _search_hint: String = DEFAULT_SEARCH_HINT
var _options: Dictionary = {}
var _owns_popup: bool = false
var _compact_mode: bool = false
var _scroll_container: ScrollContainer
var _button_group: ButtonGroup
var _auto_confirm_on_click: bool = false
var _suppress_auto_confirm: bool = false

# Virtualization / lazy loading
var _visible_start_row: int = 0
var _visible_end_row: int = 0
var _texture_cache: Dictionary = {}
var _pending_texture_loads: Array = []
var _load_batch_size: int = 20 # Icons to load per batch
var _is_loading_batch: bool = false
var _placeholder_texture: Texture2D = null
var _grid_spacer: Control = null # Spacer at top for virtual scrolling
var _max_visible_buttons: int = 9999 # No limit - we use placeholders for fast creation
var _current_scroll_value: float = 0.0
var _last_rebuild_scroll: float = -1000.0
var _scroll_rebuild_threshold: float = 50.0 # Pixels to scroll before rebuild
var _pending_button_create_index: int = 0
var _is_creating_buttons: bool = false
var _button_create_batch_size: int = 50 # Buttons to create per batch

func _init() -> void:
    var core = Engine.get_meta("TajsCore")
    if core != null:
        _registry = core.get_icon_registry()
    _default_texture = _resolve_texture(_registry.get_default_icon_id() if _registry != null else "")
    if _default_texture == null and ResourceLoader.exists("res://textures/icons/puzzle.png"):
        _default_texture = load("res://textures/icons/puzzle.png")
    _placeholder_texture = _default_texture
    _texture_cache.clear()

static func open(options: Dictionary = {}, callback: Callable = Callable()) -> bool:
    var core = Engine.get_meta("TajsCore")
    if core == null or core.ui_manager == null:
        return false
    var opts := {}
    if typeof(options) == TYPE_DICTIONARY:
        opts = options.duplicate(true)
    if callback.is_valid():
        opts["selection_callback"] = callback
    else:
        var alt := opts.get("selection_callback", null)
        if alt == null and opts.has("on_selected"):
            opts["selection_callback"] = opts["on_selected"]
    opts["owns_popup"] = true
    opts["show_select_button"] = false # Hide redundant Select button
    var container := VBoxContainer.new()
    # Use get_script() to instantiate from within the same class
    var browser_script = load("res://mods-unpacked/TajemnikTV-Core/core/ui/icon_browser.gd")
    var browser = browser_script.new()
    browser.build_ui(container, opts)
    var title := opts.get("title", "Select Icon")
    # Add just a Close button with smaller styling (handled by popup manager)
    var close_btn := {"text": "Close", "close": true}
    core.ui_manager.show_popup(title, container, [close_btn])
    return true

func build_ui(parent: Control, options: Dictionary = {}) -> void:
    if parent == null:
        return
    # Allow the browser to fill available width
    parent.custom_minimum_size = Vector2(0, 0)
    parent.size_flags_horizontal = Control.SIZE_EXPAND_FILL

    var opts := options if typeof(options) == TYPE_DICTIONARY else {}
    _options = opts.duplicate(true)
    _owns_popup = bool(opts.get("owns_popup", false))
    _allow_clear = bool(opts.get("allow_clear", true))
    _show_select_button = bool(opts.get("show_select_button", true))
    _show_source_tabs = bool(opts.get("show_source_tabs", true))
    _clear_button_text = str(opts.get("clear_text", DEFAULT_CLEAR_TEXT))
    _select_button_text = str(opts.get("select_text", DEFAULT_SELECT_TEXT))
    _search_hint = str(opts.get("search_placeholder", DEFAULT_SEARCH_HINT))
    _initial_selected_id = str(opts.get("initial_selected_id", ""))
    _pending_initial_selection = _initial_selected_id != ""
    _auto_confirm_on_click = bool(opts.get("auto_confirm", false))
    _button_group = ButtonGroup.new()
    var callback := opts.get("selection_callback", null)
    if callback == null and opts.has("on_selected"):
        callback = opts["on_selected"]
    set_selection_callback(callback)
    _allowed_sources = _normalize_allowed_sources(opts.get("allowed_sources", []))
    _allowed_source_set.clear()
    for src in _allowed_sources:
        _allowed_source_set[src] = true
    _load_icons()
    _prepare_tabs()
    _build_search(parent)
    _build_tabs(parent)
    _build_grid(parent)
    #_build_preview(parent)
    _build_actions(parent)
    _apply_filters()
    var viewport := parent.get_viewport()
    if viewport != null:
        if not viewport.size_changed.is_connected(_on_viewport_resized):
            viewport.size_changed.connect(_on_viewport_resized)

func set_selected_icon(icon_identifier: String) -> bool:
    var entry: Variant = _find_entry(icon_identifier)
    if entry == null:
        return false
    _apply_initial_tab(entry)
    _apply_filters()
    _suppress_auto_confirm = true
    _select_entry(entry)
    _suppress_auto_confirm = false
    return true

func update_layout() -> void:
    var viewport := _grid.get_viewport() if _grid != null else null
    var viewport_size := Vector2(900, 600)
    if viewport != null:
        viewport_size = viewport.get_visible_rect().size
    var parent_width := viewport_size.x
    if _scroll_container != null and _scroll_container.size.x > 0:
        parent_width = _scroll_container.size.x
    elif _grid != null and _grid.get_parent() is Control:
        parent_width = (_grid.get_parent() as Control).get_rect().size.x
    if parent_width <= 0:
        parent_width = viewport_size.x
    parent_width = max(parent_width - GRID_RIGHT_MARGIN - GRID_LEFT_MARGIN, 1.0)
    _compact_mode = viewport_size.y < SMALL_VIEWPORT_THRESHOLD or parent_width < SMALL_WIDTH_THRESHOLD
    var spacing := ICON_SPACING_SMALL if _compact_mode else ICON_SPACING
    if _grid != null:
        _grid.add_theme_constant_override("h_separation", spacing)
        _grid.add_theme_constant_override("v_separation", spacing)
        _grid.columns = _calculate_columns(parent_width, spacing)
    for btn in _buttons:
        if not is_instance_valid(btn):
            continue
        var size := ICON_SIZE_SMALL if _compact_mode else ICON_SIZE
        btn.custom_minimum_size = Vector2(size, size)
    if _scroll_container != null:
        var dynamic_height := viewport_size.y * SCROLL_HEIGHT_RATIO
        dynamic_height = clamp(dynamic_height, MIN_SCROLL_HEIGHT, MAX_SCROLL_HEIGHT)
        _scroll_container.custom_minimum_size.y = dynamic_height
    if _search_box != null:
        _search_box.add_theme_font_size_override("font_size", 12 if _compact_mode else 14)
    if _select_btn != null:
        _select_btn.add_theme_font_size_override("font_size", 12 if _compact_mode else 14)
    if _clear_btn != null:
        _clear_btn.add_theme_font_size_override("font_size", 12 if _compact_mode else 14)
    for key in _tab_buttons.keys():
        var btn: Button = _tab_buttons[key]
        if is_instance_valid(btn):
            btn.add_theme_font_size_override("font_size", 12 if _compact_mode else 14)
            btn.add_theme_constant_override("h_separation", 3 if _compact_mode else 4)

func _on_viewport_resized() -> void:
    update_layout()

func _calculate_columns(parent_width: float, spacing: int) -> int:
    var icon_size := ICON_SIZE_SMALL if _compact_mode else ICON_SIZE
    var available := max(parent_width, 1.0)
    var count := int(floor((available + spacing) / (icon_size + spacing)))
    count = max(count, GRID_COLUMNS_MIN)
    return count

func set_selection_callback(callback: Variant) -> void:
    if callback == null:
        _selection_callback = null
        return
    if callback is Callable and callback.is_valid():
        _selection_callback = callback

func _build_search(parent: Control) -> void:
    var search_row := HBoxContainer.new()
    search_row.name = "IconSearchRow"
    search_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    search_row.add_theme_constant_override("separation", 4) # Reduced spacing
    _search_box = LineEdit.new()
    _search_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _search_box.placeholder_text = _search_hint
    _search_box.add_theme_font_size_override("font_size", 14) # Smaller font
    _search_box.text_changed.connect(_on_search_changed)
    search_row.add_child(_search_box)
    parent.add_child(search_row)

func _build_tabs(parent: Control) -> void:
    _tab_buttons.clear()
    if not _show_source_tabs:
        return
    var tabs := HBoxContainer.new()
    tabs.name = "IconSourceTabs"
    tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    tabs.add_theme_constant_override("separation", 4) # Reduced from 8
    for group in _tab_groups:
        var btn := Button.new()
        btn.toggle_mode = true
        btn.focus_mode = Control.FOCUS_NONE
        btn.text = _make_tab_label(group)
        btn.add_theme_font_size_override("font_size", 14) # Smaller font
        btn.add_theme_constant_override("h_separation", 4) # Less padding
        btn.pressed.connect(_on_tab_pressed.bind(group))
        btn.button_pressed = group == _active_tab
        btn.disabled = _tab_counts.get(group, 0) == 0
        tabs.add_child(btn)
        _tab_buttons[group] = btn
    parent.add_child(tabs)

func _build_grid(parent: Control) -> void:
    _scroll_container = ScrollContainer.new()
    _scroll_container.name = "IconGridScroll"
    # Make scroll height responsive to viewport size
    var viewport_height := 600.0 # Default fallback
    if parent.get_viewport() != null:
        viewport_height = parent.get_viewport().get_visible_rect().size.y
    var dynamic_height := min(viewport_height * SCROLL_HEIGHT_RATIO, MAX_SCROLL_HEIGHT)
    _scroll_container.custom_minimum_size = Vector2(0, dynamic_height)
    _scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    _scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    _scroll_container.clip_contents = true
    _grid = GridContainer.new()
    _grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    # Columns are computed dynamically based on width
    _grid.add_theme_constant_override("h_separation", ICON_SPACING)
    _grid.add_theme_constant_override("v_separation", ICON_SPACING)
    _scroll_container.add_child(_grid)
    parent.add_child(_scroll_container)
    _scroll_container.resized.connect(update_layout)
    # Connect to scrollbar for lazy loading
    var vscroll := _scroll_container.get_v_scroll_bar()
    if vscroll != null:
        vscroll.value_changed.connect(_on_scroll_changed)
    update_layout()

# Preview section removed to prevent dialog overflow
# func _build_preview(parent: Control) -> void:
# 	var preview := HBoxContainer.new()
# 	preview.name = "IconPreview"
# 	preview.custom_minimum_size = Vector2(0, PREVIEW_SIZE + 20)
# 	preview.add_theme_constant_override("separation", 12)
# 	_preview_texture = TextureRect.new()
# 	_preview_texture.custom_minimum_size = Vector2(PREVIEW_SIZE, PREVIEW_SIZE)
# 	_preview_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
# 	_preview_texture.texture = _default_texture
# 	preview.add_child(_preview_texture)
# 	var info := VBoxContainer.new()
# 	_preview_label = Label.new()
# 	_preview_label.text = "No icon selected"
# 	_preview_meta = Label.new()
# 	_preview_meta.text = ""
# 	info.add_child(_preview_label)
# 	info.add_child(_preview_meta)
# 	preview.add_child(info)
# 	parent.add_child(preview)

func _build_actions(parent: Control) -> void:
    var actions := HBoxContainer.new()
    actions.name = "IconBrowserActions"
    actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    actions.alignment = BoxContainer.ALIGNMENT_END
    var spacer := Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    actions.add_child(spacer)
    if _allow_clear:
        _clear_btn = Button.new()
        _clear_btn.text = _clear_button_text
        _clear_btn.focus_mode = Control.FOCUS_NONE
        _clear_btn.add_theme_font_size_override("font_size", 14) # Smaller font
        _clear_btn.pressed.connect(_on_clear_pressed)
        actions.add_child(_clear_btn)
    _select_btn = Button.new()
    _select_btn.text = _select_button_text
    _select_btn.focus_mode = Control.FOCUS_NONE
    _select_btn.add_theme_font_size_override("font_size", 14) # Smaller font
    _select_btn.disabled = true
    _select_btn.visible = _show_select_button
    _select_btn.pressed.connect(_on_select_pressed)
    actions.add_child(_select_btn)
    parent.add_child(actions)
    update_layout()

func _load_icons() -> void:
    if _registry == null:
        _all_icons = []
        _icons_by_id.clear()
        return
    _all_icons = _registry.get_all_icons()
    _icons_by_id.clear()
    for entry in _all_icons:
        var id: String = entry.get("stable_id", "")
        if id == "":
            continue
        _icons_by_id[id] = entry

func _normalize_allowed_sources(value: Variant) -> Array:
    var raw := value
    if typeof(raw) == TYPE_STRING:
        raw = [raw]
    elif typeof(raw) != TYPE_ARRAY:
        raw = []
    var result := []
    for item in raw:
        if typeof(item) != TYPE_STRING:
            continue
        var cleaned: String = item.strip_edges()
        if cleaned == "":
            continue
        if result.has(cleaned):
            continue
        result.append(cleaned)
    if result.is_empty():
        return [GROUP_BASE, GROUP_CORE, GROUP_MODS]
    return result

func _prepare_tabs() -> void:
    var counts := {}
    if _registry != null:
        counts = _registry.get_group_counts(_allowed_sources)
    _tab_counts.clear()
    for group in [GROUP_BASE, GROUP_CORE, GROUP_MODS]:
        _tab_counts[group] = counts.get(group, 0)
    _tab_groups.clear()
    for group in [GROUP_BASE, GROUP_CORE, GROUP_MODS]:
        if _tab_counts.get(group, 0) > 0:
            _tab_groups.append(group)
    if _tab_groups.is_empty():
        _tab_groups = [GROUP_BASE, GROUP_CORE, GROUP_MODS]
    if _initial_selected_id != "":
        var entry: Variant = _find_entry(_initial_selected_id)
        if entry != null:
            var entry_group: String = _get_entry_group(entry)
            if entry_group != "" and _tab_groups.has(entry_group):
                _active_tab = entry_group
    elif not _tab_groups.has(_active_tab):
        _active_tab = _tab_groups[0] if _tab_groups.size() > 0 else GROUP_BASE

func _make_tab_label(group: String) -> String:
    var label := group.capitalize()
    if _registry != null:
        label = _registry.get_source_label(group)
    var count := _tab_counts.get(group, 0)
    return "%s (%d)" % [label, count]

func _apply_filters() -> void:
    _filtered_icons.clear()
    var term := ""
    if _search_box != null:
        term = _search_box.text.strip_edges().to_lower()
    for entry in _all_icons:
        if not _matches_allowed(entry):
            continue
        if _show_source_tabs and _tab_groups.size() > 0 and not _matches_active_tab(entry):
            continue
        if term != "" and not _matches_search(entry, term):
            continue
        _filtered_icons.append(entry)
    _rebuild_grid()
    if _pending_initial_selection:
        _apply_initial_selection()
    update_layout()

func _rebuild_grid() -> void:
    # Cancel any pending batch operations
    _pending_button_create_index = 0
    _is_creating_buttons = false

    for btn in _buttons:
        if is_instance_valid(btn):
            btn.queue_free()
    _buttons.clear()
    _last_rebuild_scroll = -1000.0
    if _grid == null:
        return

    var total_icons := _filtered_icons.size()
    if total_icons == 0:
        update_layout()
        return

    # Create first batch immediately for instant feedback
    var first_batch := mini(total_icons, _button_create_batch_size)
    for i in range(first_batch):
        var entry: Dictionary = _filtered_icons[i]
        var btn := _create_icon_button(entry, i)
        _grid.add_child(btn)
        _buttons.append(btn)
        if _selected_entry != null and _selected_entry.get("stable_id", "") == entry.get("stable_id", ""):
            btn.button_pressed = true

    update_layout()

    # Schedule remaining buttons to be created in batches
    if total_icons > first_batch:
        _pending_button_create_index = first_batch
        _is_creating_buttons = true
        _schedule_next_button_batch()
    else:
        # All buttons created, start loading textures
        _queue_visible_texture_loads()


func _schedule_next_button_batch() -> void:
    if not _is_creating_buttons or _grid == null or not is_instance_valid(_grid):
        return
    if _grid.get_tree() == null:
        return
    var timer := _grid.get_tree().create_timer(0.005) # 5ms delay between batches
    timer.timeout.connect(_create_next_button_batch)


func _create_next_button_batch() -> void:
    if not _is_creating_buttons or _grid == null or not is_instance_valid(_grid):
        _is_creating_buttons = false
        return

    var total_icons := _filtered_icons.size()
    var end_index := mini(_pending_button_create_index + _button_create_batch_size, total_icons)

    for i in range(_pending_button_create_index, end_index):
        var entry: Dictionary = _filtered_icons[i]
        var btn := _create_icon_button(entry, i)
        _grid.add_child(btn)
        _buttons.append(btn)
        if _selected_entry != null and _selected_entry.get("stable_id", "") == entry.get("stable_id", ""):
            btn.button_pressed = true

    _pending_button_create_index = end_index

    if _pending_button_create_index < total_icons:
        _schedule_next_button_batch()
    else:
        # All buttons created
        _is_creating_buttons = false
        update_layout()
        _queue_visible_texture_loads()


func _create_icon_button(entry: Dictionary, index: int) -> Button:
    var btn := Button.new()
    btn.toggle_mode = true
    btn.focus_mode = Control.FOCUS_NONE
    if _button_group != null:
        btn.button_group = _button_group
    var icon_size := ICON_SIZE_SMALL if _compact_mode else ICON_SIZE
    btn.custom_minimum_size = Vector2(icon_size, icon_size)
    btn.expand_icon = true
    btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER

    var icon_id: String = entry.get("stable_id", "")
    # Use cached texture or placeholder
    if _texture_cache.has(icon_id):
        btn.icon = _texture_cache[icon_id]
    else:
        btn.icon = _placeholder_texture

    btn.tooltip_text = entry.get("name", entry.get("display_name", ""))
    btn.set_meta("icon_id", icon_id)
    btn.set_meta("entry_index", index)
    btn.pressed.connect(_on_icon_pressed.bind(entry))
    btn.gui_input.connect(_on_icon_gui_input.bind(entry))
    return btn


func _on_scroll_changed(value: float) -> void:
    _current_scroll_value = value
    # Check if we've scrolled enough to warrant updates
    if abs(value - _last_rebuild_scroll) > _scroll_rebuild_threshold:
        _last_rebuild_scroll = value
        _queue_visible_texture_loads()


func _queue_visible_texture_loads() -> void:
    if _is_loading_batch or _grid == null:
        return

    _pending_texture_loads.clear()

    # Find buttons that need textures loaded
    for btn in _buttons:
        if not is_instance_valid(btn):
            continue
        var icon_id: String = btn.get_meta("icon_id")
        if icon_id == "" or _texture_cache.has(icon_id):
            continue
        if btn.icon == _placeholder_texture:
            _pending_texture_loads.append({"button": btn, "icon_id": icon_id})

    if _pending_texture_loads.size() > 0:
        _load_next_texture_batch()


func _load_next_texture_batch() -> void:
    if _pending_texture_loads.is_empty():
        _is_loading_batch = false
        return

    _is_loading_batch = true
    var batch_count := mini(_pending_texture_loads.size(), _load_batch_size)

    for i in range(batch_count):
        var item: Dictionary = _pending_texture_loads.pop_front()
        var btn: Button = item.get("button")
        var icon_id: String = item.get("icon_id")

        if not is_instance_valid(btn):
            continue

        # Load texture
        var tex: Texture2D = null
        var resolved := _resolve_icon(icon_id)
        if resolved.texture != null:
            tex = resolved.texture
        else:
            tex = _default_texture

        # Cache and apply
        _texture_cache[icon_id] = tex
        if is_instance_valid(btn) and btn.get_meta("icon_id") == icon_id:
            btn.icon = tex

    _is_loading_batch = false

    # Continue loading remaining in next frame using a timer
    if _pending_texture_loads.size() > 0 and _grid != null and is_instance_valid(_grid):
        var timer := _grid.get_tree().create_timer(0.01)
        timer.timeout.connect(_load_next_texture_batch)


func _on_search_changed(_text: String) -> void:
    _apply_filters()

func _on_tab_pressed(group: String) -> void:
    _set_active_tab(group)

func _set_active_tab(group: String) -> void:
    if group == "" or _active_tab == group:
        return
    _active_tab = group
    for name in _tab_buttons.keys():
        var btn: Button = _tab_buttons[name]
        if is_instance_valid(btn):
            btn.button_pressed = name == group
    _apply_filters()

func _matches_active_tab(entry: Dictionary) -> bool:
    if _active_tab == "":
        return true
    return _get_entry_group(entry) == _active_tab

func _matches_allowed(entry: Dictionary) -> bool:
    if _allowed_sources.size() == 0:
        return true
    var source := entry.get("source_id", "")
    if _allowed_source_set.has(source):
        return true
    var group := _get_entry_group(entry)
    if _allowed_source_set.has(group):
        return true
    return false

func _matches_search(entry: Dictionary, term: String) -> bool:
    var candidate: String = entry.get("name", entry.get("display_name", "")).to_lower()
    if candidate.find(term) != -1:
        return true
    var stable: String = entry.get("stable_id", "").to_lower()
    if stable.find(term) != -1:
        return true
    return false

func _on_icon_pressed(entry: Dictionary) -> void:
    _select_entry(entry)

func _on_icon_gui_input(event: InputEvent, entry: Dictionary) -> void:
    if event is InputEventMouseButton and event.double_click:
        _select_entry(entry)
        _confirm_selection()

func _select_entry(entry: Variant) -> void:
    if entry == null:
        _selected_entry = null
        #update_preview({})
        if _select_btn != null:
            _select_btn.disabled = true
        return
    _selected_entry = entry
    for btn in _buttons:
        if not is_instance_valid(btn):
            continue
        var btn_id: String = btn.get_meta("icon_id")
        btn.button_pressed = btn_id == entry.get("stable_id", "")
    #_update_preview(entry)
    if _select_btn != null:
        _select_btn.disabled = false
    var icon_id: String = str(entry.get("stable_id", ""))
    if icon_id == "":
        icon_id = str(entry.get("name", entry.get("display_name", "")))
    icon_selected.emit(icon_id, entry.get("path", ""))
    if _auto_confirm_on_click and not _suppress_auto_confirm:
        _confirm_selection()

# Preview update removed
# func _update_preview(entry: Variant) -> void:
# 	var tex := _default_texture
# 	var label := "No icon selected"
# 	var sub := ""
# 	if entry != null and entry is Dictionary:
# 		label = entry.get("name", entry.get("display_name", ""))
# 		sub = entry.get("stable_id", "")
# 		var result: Dictionary = _resolve_icon(entry.get("stable_id", ""))
# 		if result.texture != null:
# 			tex = result.texture
# 	if _preview_texture != null:
# 		_preview_texture.texture = tex
# 	if _preview_label != null:
# 		_preview_label.text = label
# 	if _preview_meta != null:
# 		_preview_meta.text = sub

func _apply_initial_selection() -> void:
    _pending_initial_selection = false
    if _initial_selected_id == "":
        return
    var entry: Variant = _find_entry(_initial_selected_id)
    if entry != null:
        _suppress_auto_confirm = true
        _select_entry(entry)
        _suppress_auto_confirm = false

func _confirm_selection() -> void:
    if _selected_entry == null:
        return
    icon_confirmed.emit(_selected_entry.get("stable_id", ""), _selected_entry)
    if _selection_callback != null and _selection_callback is Callable and _selection_callback.is_valid():
        _selection_callback.call(_selected_entry.get("stable_id", ""), _selected_entry)
    _close_parent_popup()

func _on_select_pressed() -> void:
    _confirm_selection()

func _on_clear_pressed() -> void:
    _selected_entry = null
    #_update_preview({})
    if _selection_callback != null and _selection_callback is Callable and _selection_callback.is_valid():
        _selection_callback.call(null, null)
    selection_cleared.emit()
    _close_parent_popup()

func _close_parent_popup() -> void:
    if not _owns_popup:
        return
    var core = Engine.get_meta("TajsCore")
    if core == null or core.ui_manager == null:
        return
    core.ui_manager.close_popup()

func _resolve_icon(icon_id: String) -> Dictionary:
    if _registry != null:
        return _registry.resolve_icon(icon_id)
    return {"texture": _default_texture, "entry": null, "path": "", "missing": true}

func _apply_initial_tab(entry: Variant) -> void:
    if entry == null or not entry is Dictionary:
        return
    var group: String = _get_entry_group(entry)
    if group == "":
        return
    if _tab_groups.has(group):
        _active_tab = group

func _get_entry_group(entry: Variant) -> String:
    if entry == null or not entry is Dictionary:
        return ""
    if entry.has("source_group") and str(entry["source_group"]) != "":
        return str(entry["source_group"])
    var source: String = entry.get("source_id", "")
    if _registry != null:
        return _registry.get_source_group(source)
    return source

func _find_entry(identifier: String) -> Variant:
    if identifier == "" or _all_icons.is_empty():
        return null
    var entry: Variant = _icons_by_id.get(identifier, null)
    if entry != null:
        return entry
    var target := identifier.to_lower()
    for item in _all_icons:
        if item == null:
            continue
        if item.get("name", "").to_lower() == target:
            return item
        if item.get("display_name", "").to_lower() == target:
            return item
        if item.get("stable_id", "").to_lower() == target:
            return item
        if item.get("relative_path", "").to_lower() == target:
            return item
    return null

func _resolve_texture(icon_id: String) -> Texture2D:
    if icon_id == "":
        return null
    if _registry != null:
        var result: Dictionary = _registry.resolve_icon(icon_id)
        if result.texture != null:
            return result.texture
    return null
