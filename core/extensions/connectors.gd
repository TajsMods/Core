extends "res://scripts/connectors.gd"


func _ready() -> void:
    super._ready()
    Signals.tool_set.connect(_on_tool_set)
    _apply_mouse_filter_policy()


func _on_tool_set() -> void:
    _apply_mouse_filter_policy()


func _apply_mouse_filter_policy() -> void:
    if Globals.editing_connection:
        mouse_filter = Control.MOUSE_FILTER_PASS
    else:
        mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_gui_input(event: InputEvent) -> void:
    if event.device == -1:
        return

    if event is InputEventMouseMotion:
        if grabbing:
            grabbing.move_and_snap(event.position)
            queue_redraw()
            accept_event()
            return
        elif Globals.tool != Utils.tools.MOVE:
            var new_hover: Connector
            var point_data: Dictionary = get_point_at(event.position)

            if point_data.connector:
                new_hover = point_data.connector
                hovering_pos = point_data.position
                queue_redraw()

            if new_hover != hovering_connection:
                hovering_connection = new_hover
                if hovering_connection:
                    Signals.highlight_connection.emit([hovering_connection.input_id])
                else:
                    Signals.highlight_connection.emit([])
                queue_redraw()
    elif event is InputEventScreenDrag:
        if grabbing:
            grabbing.move_and_snap(event.position)
            queue_redraw()
            accept_event()
            return

    if Globals.editing_connection and Globals.tool != Utils.tools.MOVE:
        if event is InputEventScreenTouch:
            if event.index == 0:
                if handle_press_input(event):
                    accept_event()
                    return
        elif event is InputEventMouseButton:
            if event.button_index == MOUSE_BUTTON_LEFT:
                if handle_press_input(event):
                    accept_event()
                    return

    Signals.unhandled_input.emit(event, global_position)
