extends "res://scripts/hud.gd"

func _ready() -> void:
    super ()
    _build_core_window_buttons()
    update_unlockables()
    update_buttons()

func update_buttons() -> void:
    super ()
    var menu_buttons: Control = _get_menu_buttons()
    var windows_menu: Control = _get_windows_menu()
    var core: Variant = Engine.get_meta("TajsCore", null)
    @warning_ignore("unsafe_method_access")
    if core != null and core.window_menus != null and menu_buttons != null and windows_menu != null:
        @warning_ignore("unsafe_method_access")
        core.window_menus.update_button_states(menu_buttons, windows_menu)

func update_unlockables() -> void:
    super ()
    var menu_buttons: Control = _get_menu_buttons()
    var core: Variant = Engine.get_meta("TajsCore", null)
    @warning_ignore("unsafe_method_access")
    if core != null and core.window_menus != null and menu_buttons != null:
        @warning_ignore("unsafe_method_access")
        core.window_menus.update_unlocks(menu_buttons)

func check_new_windows() -> void:
    var new: Array[String] = get_new_windows()
    if new.size() > 0:
        var categories: Array = []
        for window_id: String in new:
            var category: String = Data.windows[window_id].category
            if categories.has(category):
                continue
            categories.append(category)

        for category_id: String in categories:
            match category_id:
                "cpu":
                    Signals.notify.emit("processor", "new_windows_processor")
                "network":
                    Signals.notify.emit("web", "new_windows_network")
                "gpu":
                    Signals.notify.emit("gpu", "new_windows_gpu")
                "research":
                    Signals.notify.emit("research", "new_windows_research")
                "factory":
                    Signals.notify.emit("robot_arm", "new_windows_factory")
                "hacking":
                    Signals.notify.emit("hacker", "new_windows_hacking")
                "coding":
                    Signals.notify.emit("code", "new_windows_coding")
                "utility":
                    Signals.notify.emit("tools", "new_windows_utilities")

        var core: Variant = Engine.get_meta("TajsCore", null)
        @warning_ignore("unsafe_method_access")
        if core != null and core.window_menus != null:
            for category_id: String in categories:
                @warning_ignore("unsafe_method_access")
                var notice: String = core.window_menus.get_notice_for_category(category_id)
                if notice != "":
                    Signals.notify.emit(category_id, notice)

        available_windows.append_array(new)

func _build_core_window_buttons() -> void:
    var menu_buttons: Control = _get_menu_buttons()
    if menu_buttons == null:
        return
    var core: Variant = Engine.get_meta("TajsCore", null)
    @warning_ignore("unsafe_method_access")
    if core != null and core.window_menus != null:
        @warning_ignore("unsafe_method_access")
        core.window_menus.build_buttons(menu_buttons)

func _get_menu_buttons() -> Control:
    return $Main/MainContainer/Overlay/BottomButtons/WindowsButtons/MenuButtons

func _get_windows_menu() -> Control:
    return $Main/MainContainer/Overlay/WindowsMenu
