# =============================================================================
# Taj's Core - UI Manager
# Author: TajemnikTV
# Description: Attaches Core settings UI to the HUD
# =============================================================================
class_name TajsCoreUiManager
extends Node

const LOG_NAME := "TajemnikTV-Core:UIManager"

var _core
var _workshop_sync
var _ui
var _settings_menu

func setup(core, workshop_sync) -> void:
    _core = core
    _workshop_sync = workshop_sync

func _ready() -> void:
    set_process_input(true)
    get_tree().node_added.connect(_on_node_added)
    call_deferred("_check_existing_main")

func _check_existing_main() -> void:
    var main = get_tree().root.get_node_or_null("Main")
    if main:
        _setup_for_main(main)

func _on_node_added(node: Node) -> void:
    if node.name == "Main" and node.get_parent().name == "root":
        call_deferred("_setup_for_main", node)

func _setup_for_main(main_node: Node) -> void:
    var hud = main_node.get_node_or_null("HUD")
    if hud == null:
        return

    var overlay = hud.get_node_or_null("Main/MainContainer/Overlay")
    if overlay and overlay.has_node("TajsCoreMenus"):
        return

    var base_dir = get_script().resource_path.get_base_dir()
    var ui_script = load(base_dir.path_join("settings_ui.gd"))
    if ui_script == null:
        _log_warn("Failed to load settings UI script.")
        return

    _ui = ui_script.new(hud, _core.get_version() if _core != null else "")
    _ui.add_mod_button(func(): _ui.set_visible(!_ui.is_visible()))
    if _core != null:
        _ui.set_settings(_core.settings)

    var menu_script = load(base_dir.path_join("settings_menu.gd"))
    if menu_script == null:
        _log_warn("Failed to load settings menu script.")
        return

    _settings_menu = menu_script.new()
    _settings_menu.setup(_core, _ui, _workshop_sync)
    _settings_menu.build_settings_menu()

    if _workshop_sync:
        _workshop_sync.set_restart_callback(Callable(_ui, "show_restart_banner"))

func _input(event: InputEvent) -> void:
    if _ui == null or not _ui.is_visible():
        return
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        var mouse_pos := get_viewport().get_mouse_position()
        var panel_rect: Rect2 = _ui.settings_panel.get_global_rect() if _ui.settings_panel else Rect2()
        var btn_rect: Rect2 = _ui.settings_button.get_global_rect() if _ui.settings_button else Rect2()
        if not panel_rect.has_point(mouse_pos) and not btn_rect.has_point(mouse_pos):
            _ui.set_visible(false)

func _log_warn(message: String) -> void:
    if ClassDB.class_exists("ModLoaderLog"):
        ModLoaderLog.warning(message, LOG_NAME)
    else:
        print(LOG_NAME + ": " + message)
