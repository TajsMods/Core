extends "res://scripts/windows_menu.gd"

const MENU_EDGE_MARGIN := 16.0
const MENU_MIN_VISIBLE_HEIGHT := 360.0

var _menu_open_top := -724.0
var _menu_closed_top := 20.0
var _menu_closed_bottom := 744.0

func _ready() -> void:
    var categories_node: Control = get_node_or_null("Categories")
    if categories_node == null:
        categories_node = get_node_or_null("VBoxContainer/WindowsPanel/MainContainer/TabsPanels")
    var core: Variant = Engine.get_meta("TajsCore", null)
    if core != null and core.window_menus != null and categories_node != null:
        core.window_menus.ensure_tabs(categories_node)
    super ()
    _update_menu_bounds()
    if not open:
        offset_top = _menu_closed_top
        offset_bottom = _menu_closed_bottom
    var viewport := get_viewport()
    if viewport != null and not viewport.size_changed.is_connected(_on_viewport_resized):
        viewport.size_changed.connect(_on_viewport_resized)

func toggle(toggled: bool, _tab: int = cur_tab) -> void:
    _update_menu_bounds()
    var tween: Tween = create_tween()
    tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.set_parallel(true)

    if toggled:
        modulate.a = 0
        visible = true
        tween.set_parallel()
        tween.tween_property(self, "offset_top", _menu_open_top, 0.25)
        tween.tween_property(self, "offset_bottom", 0, 0.25)
        tween.tween_property(self, "modulate:a", 1, 0.25)
        mouse_filter = Control.MOUSE_FILTER_STOP
    else:
        modulate.a = 1
        visible = true
        tween.set_parallel()
        tween.tween_property(self, "offset_top", _menu_closed_top, 0.25)
        tween.tween_property(self, "offset_bottom", _menu_closed_bottom, 0.25)
        tween.tween_property(self, "modulate:a", 0, 0.25)
        tween.finished.connect(func() -> void: visible = open)
        mouse_filter = Control.MOUSE_FILTER_IGNORE
    open = toggled

    if !Globals.tutorial_done:
        if open:
            if Globals.tutorial_step == Utils.tutorial_steps.OPEN_MENU:
                Globals.set_tutorial_step(Utils.tutorial_steps.OPEN_MENU + 1)
            elif Globals.tutorial_step == Utils.tutorial_steps.OPEN_MENU2:
                Globals.set_tutorial_step(Utils.tutorial_steps.OPEN_MENU2 + 1)
        else:
            if Globals.tutorial_step == Utils.tutorial_steps.ADD_UPLOADER:
                Globals.set_tutorial_step(Utils.tutorial_steps.OPEN_MENU)
            elif Globals.tutorial_step == Utils.tutorial_steps.SELECT_COLLECTOR:
                Globals.set_tutorial_step(Utils.tutorial_steps.OPEN_MENU2)
            elif Globals.tutorial_step == Utils.tutorial_steps.ADD_COLLECTOR:
                Globals.set_tutorial_step(Utils.tutorial_steps.OPEN_MENU2)

func open_tab(tab: int) -> void:
    var child: Control = _get_tab_node(tab)
    if child == null:
        return
    child.visible = true
    child.modulate.a = 0
    child.offset_top = 236

    var tween: Tween = create_tween()
    tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.set_parallel()
    tween.tween_property(child, "modulate:a", 1, 0.25)
    tween.tween_property(child, "offset_top", 0, 0.25)
    tween.finished.connect(func() -> void:
        child.visible = true
    )

func close_tab(tab: int) -> void:
    var child: Control = _get_tab_node(tab)
    if child == null:
        return
    child.visible = true
    child.modulate.a = 1
    child.offset_top = 0

    var tween: Tween = create_tween()
    tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.set_parallel()
    tween.tween_property(child, "offset_top", 236, 0.25)
    tween.tween_property(child, "modulate:a", 0, 0.25)
    tween.finished.connect(func() -> void:
        child.visible = false
    )

func add_window(w: String) -> void:
    var path := _resolve_window_scene(w)
    if path == "":
        return
    var window: WindowContainer = load(path).instantiate()
    window.name = w
    window.global_position = Vector2(Globals.camera_center - window.size / 2).snappedf(50)
    Signals.create_window.emit(window)

func _on_add_pressed() -> void:
    var current_window := _get_current_window()
    if current_window.is_empty():
        return
    if _is_node_limit_reached(1):
        Signals.notify.emit("exclamation", "build_limit_reached")
        Sound.play("error")
        return
    elif Utils.can_add_window(current_window):
        add_window(current_window)
        Signals.set_menu.emit(0, 0)

func _on_window_selected(w: String) -> void:
    var current_window := _get_current_window()
    if Data.platform == 2 or Data.platform == 3:
        if w == current_window:
            _set_current_window("")
        else:
            _set_current_window(w)
    elif not w.is_empty():
        if _is_node_limit_reached(1):
            Signals.notify.emit("exclamation", "build_limit_reached")
            Sound.play("error")
            return
        elif Utils.can_add_window(w):
            add_window(w)
            if not Input.is_key_pressed(KEY_SHIFT):
                Signals.set_menu.emit(0, 0)

func _on_spawn_placer(placer: Button) -> void:
    _update_menu_bounds()
    modulate.a = 1
    var tween: Tween = create_tween()
    tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.set_parallel()
    tween.tween_property(self, "offset_top", _menu_closed_top, 0.15)
    tween.tween_property(self, "offset_bottom", _menu_closed_bottom, 0.15)
    tween.tween_property(self, "modulate:a", 0, 0.15)
    placer.tree_exiting.connect(_on_placer_exiting_tree)
    $VBoxContainer / WindowsPanel / MainContainer / TabContainer / Windows / WindowsContainer / TopContainer / Search.release_focus()

func _on_placer_exiting_tree() -> void:
    _update_menu_bounds()
    modulate.a = 0
    var tween: Tween = create_tween()
    tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.set_parallel()
    tween.tween_property(self, "offset_top", _menu_open_top, 0.15)
    tween.tween_property(self, "offset_bottom", 0, 0.15)
    tween.tween_property(self, "modulate:a", 1, 0.15)
    if !Data.is_mobile():
        $VBoxContainer / WindowsPanel / MainContainer / TabContainer / Windows / WindowsContainer / TopContainer / Search.grab_focus()

func _on_viewport_resized() -> void:
    _update_menu_bounds()
    if open:
        offset_top = _menu_open_top
        offset_bottom = 0.0
    else:
        offset_top = _menu_closed_top
        offset_bottom = _menu_closed_bottom

func _on_unlocked(unlocked: Dictionary) -> void:
    var new_windows = unlocked.get("windows", [])
    if not (new_windows is Array) or new_windows.is_empty():
        return

    var categories: Array = []
    for window_id in new_windows:
        var id := str(window_id)
        if id == "" or not Data.windows.has(id):
            continue
        var category := str(Data.windows[id].category)
        if category == "" or categories.has(category):
            continue
        categories.append(category)

    if categories.is_empty():
        return

    for category_id in categories:
        if category_tabs.has(category_id):
            var tab_name := str(category_tabs[category_id])
            var new_tex: TextureRect = $VBoxContainer/WindowsPanel/MainContainer/TabsPanels/WindowPanel/WindowsTabs.get_node_or_null(tab_name + "/New")
            if new_tex != null:
                new_tex.visible = true
        match category_id:
            "cpu":
                Signals.notify.emit("processor", "new_windows_processor")
            "network":
                Signals.notify.emit("web", "new_windows_network")
            "gpu":
                Signals.notify.emit("gpu", "new_windows_gpu")
            "research":
                Signals.notify.emit("research", "new_windows_research")
            "ai":
                Signals.notify.emit("brain", "new_windows_ai")
            "factory":
                Signals.notify.emit("robot_arm", "new_windows_factory")
            "power":
                Signals.notify.emit("lightning", "new_windows_power")
            "hacking":
                Signals.notify.emit("hacker", "new_windows_hacking")
            "coding":
                Signals.notify.emit("code", "new_windows_coding")
            "utility":
                Signals.notify.emit("tools", "new_windows_utilities")

    var core: Variant = Engine.get_meta("TajsCore", null)
    if core != null and core.window_menus != null:
        for category_id in categories:
            var notice: String = core.window_menus.get_notice_for_category(category_id)
            if notice != "":
                Signals.notify.emit(category_id, notice)

func _get_tab_node(tab: int) -> Control:
    var categories_node: Control = get_node_or_null("Categories")
    if categories_node == null:
        categories_node = get_node_or_null("VBoxContainer/WindowsPanel/MainContainer/TabsPanels")
    var core: Variant = Engine.get_meta("TajsCore", null)
    if core != null and core.window_menus != null and categories_node != null:
        var custom: Control = core.window_menus.get_panel_for_tab(tab, categories_node)
        if custom != null:
            return custom
    if category_tabs.has(tab) and categories_node != null:
        return categories_node.get_node_or_null(category_tabs[tab])
    return null

func _resolve_window_scene(window_id: String) -> String:
    if not Data.windows.has(window_id):
        return ""
    var scene := str(Data.windows[window_id].scene)
    if scene == "":
        return ""
    var core: Variant = Engine.get_meta("TajsCore", null)
    if core != null and core.window_scenes != null:
        return core.window_scenes.resolve_scene_path(scene)
    var file_name := scene
    if not file_name.ends_with(".tscn"):
        file_name += ".tscn"
    return "res://scenes/windows".path_join(file_name)

func _is_node_limit_reached(additional: int) -> bool:
    var helper: Variant = _get_node_limit_helpers()
    if helper != null and helper.has_method("can_add_nodes"):
        return not helper.can_add_nodes(additional)
    return Globals.max_window_count + max(additional, 0) > Utils.MAX_WINDOW

func _get_node_limit_helpers() -> Object:
    var core: Variant = Engine.get_meta("TajsCore", null)
    if core != null and core.has_method("get"):
        return core.get("node_limit_helpers")
    return null

func _get_windows_tab() -> Node:
    return get_node_or_null("VBoxContainer/WindowsPanel/MainContainer/TabContainer/Windows")

func _get_current_window() -> String:
    var windows_tab := _get_windows_tab()
    if windows_tab == null:
        return ""
    return str(windows_tab.get("cur_window"))

func _set_current_window(window_id: String) -> void:
    var windows_tab := _get_windows_tab()
    if windows_tab != null and windows_tab.has_method("set_window"):
        windows_tab.call("set_window", window_id)

func _update_menu_bounds() -> void:
    var viewport := get_viewport()
    if viewport == null:
        _menu_open_top = -724.0
        _menu_closed_top = 20.0
        _menu_closed_bottom = 744.0
        return
    var visible_size: Vector2 = viewport.get_visible_rect().size
    var usable_height: float = maxf(visible_size.y - (MENU_EDGE_MARGIN * 2.0), MENU_MIN_VISIBLE_HEIGHT)
    var open_height: float = minf(usable_height, 724.0)
    _menu_open_top = -open_height
    _menu_closed_top = MENU_EDGE_MARGIN
    _menu_closed_bottom = open_height + MENU_EDGE_MARGIN + 4.0
