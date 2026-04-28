extends "res://scripts/windows_menu.gd"

func _ready() -> void:
    var core: Variant = Engine.get_meta("TajsCore", null)
    if core != null and core.window_menus != null:
        core.window_menus.ensure_tabs($Categories)
    super ()

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
    var core: Variant = Engine.get_meta("TajsCore", null)
    if core != null and core.window_menus != null:
        var custom: Control = core.window_menus.get_panel_for_tab(tab, $Categories)
        if custom != null:
            return custom
    if category_tabs.has(tab):
        return $Categories.get_node(category_tabs[tab])
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
