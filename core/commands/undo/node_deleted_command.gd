class_name TajsCoreNodeDeletedCommand
extends "res://mods-unpacked/TajemnikTV-Core/core/commands/undo/undo_command.gd"

var _window_name: String = ""
var _export_data: Dictionary = {}
var _position: Vector2 = Vector2.ZERO
var _importing: bool = false

func setup(window_name: String, export_data: Dictionary, position: Vector2, importing: bool = false) -> void:
    _window_name = window_name
    _export_data = export_data.duplicate(true)
    _position = position
    _importing = importing
    description = "Delete Node"

func execute() -> bool:
    var window = _find_window()
    if not is_instance_valid(window): return true # Already deleted is fine
    
    var globals = _get_globals()
    if globals and globals.selections.has(window):
        var new_sel = globals.selections.duplicate()
        new_sel.erase(window)
        globals.set_selection(new_sel, globals.connector_selection, globals.selection_type)
        
    window.propagate_call("close")
    return true

func undo() -> bool:
    if _export_data.is_empty(): return false
    var desktop = _get_desktop()
    if not desktop: return false
    
    var restore_data = {_window_name: _export_data}
    if desktop.has_method("add_windows_from_data"):
        desktop.add_windows_from_data(restore_data, _importing)
        
    var window = _find_window()
    if is_instance_valid(window):
        window.position = _position
    return true

func is_valid() -> bool:
    return not _export_data.is_empty()

func _find_window() -> Node:
    var desktop = _get_desktop()
    if not desktop: return null
    return desktop.get_node_or_null("Windows/" + _window_name)

func _get_desktop() -> Node:
    return Engine.get_main_loop().root.get_node_or_null("Main/MainContainer/GameViewport/Desktop")

func _get_globals() -> Object:
    return Engine.get_main_loop().root.get_node_or_null("Globals")
