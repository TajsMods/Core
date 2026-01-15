class_name TajsCoreDisconnectCommand
extends "res://mods-unpacked/TajemnikTV-Core/core/commands/undo/undo_command.gd"

var _output_window_name: String = ""
var _output_path: String = ""
var _input_window_name: String = ""
var _input_path: String = ""

func setup(output_window: String, output_path: String, input_window: String, input_path: String) -> void:
    _output_window_name = output_window
    _output_path = output_path
    _input_window_name = input_window
    _input_path = input_path
    description = "Disconnect Wire"

func execute() -> bool:
    var output_id = _get_resource_id(_output_window_name, _output_path)
    var input_id = _get_resource_id(_input_window_name, _input_path)
    if output_id == "" or input_id == "": return false
        
    var signals_node = Engine.get_main_loop().root.get_node_or_null("Signals")
    if signals_node:
        signals_node.emit_signal("delete_connection", output_id, input_id)
    return true

func undo() -> bool:
    var output_id = _get_resource_id(_output_window_name, _output_path)
    var input_id = _get_resource_id(_input_window_name, _input_path)
    if output_id == "" or input_id == "": return false
        
    var signals_node = Engine.get_main_loop().root.get_node_or_null("Signals")
    if signals_node:
        signals_node.emit_signal("create_connection", output_id, input_id)
    return true

func _get_resource_id(window_name: String, relative_path: String) -> String:
    var desktop = Engine.get_main_loop().root.get_node_or_null("Main/MainContainer/GameViewport/Desktop")
    if not desktop: return ""
        
    var window = desktop.get_node_or_null("Windows/" + window_name)
    if not window: return ""
        
    var resource_node = window.get_node_or_null(relative_path)
    if resource_node and "id" in resource_node:
        return resource_node.id
    return ""
