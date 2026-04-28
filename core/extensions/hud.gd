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
    # In newer game versions, new-window tracking moved to windows_menu.gd.
    # Keep this method as a no-op compatibility hook so any external calls remain safe.
    var windows_menu: Control = _get_windows_menu()
    if windows_menu != null and windows_menu.has_method("update_unlocks"):
        windows_menu.call("update_unlocks")

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
