# ==============================================================================
# Taj's Core - Undo Manager
# Author: TajemnikTV
# Description: Full-featured Undo/Redo manager service for Core.
# ==============================================================================
class_name TajsCoreUndoManager
extends RefCounted

const LOG_NAME = "TajsCore:UndoManager"
const MAX_HISTORY_SIZE := 100

# Preload Core commands
const TransactionCommandScript = preload("res://mods-unpacked/TajemnikTV-Core/core/commands/undo/transaction_command.gd")
const MoveNodesCommandScript = preload("res://mods-unpacked/TajemnikTV-Core/core/commands/undo/move_nodes_command.gd")
const ConnectCommandScript = preload("res://mods-unpacked/TajemnikTV-Core/core/commands/undo/connect_command.gd")
const DisconnectCommandScript = preload("res://mods-unpacked/TajemnikTV-Core/core/commands/undo/disconnect_command.gd")
const NodeCreatedCommandScript = preload("res://mods-unpacked/TajemnikTV-Core/core/commands/undo/node_created_command.gd")
const NodeDeletedCommandScript = preload("res://mods-unpacked/TajemnikTV-Core/core/commands/undo/node_deleted_command.gd")
const PropertyChangeCommandScript = preload("res://mods-unpacked/TajemnikTV-Core/core/commands/undo/property_change_command.gd")
const CallableCommandScript = preload("res://mods-unpacked/TajemnikTV-Core/core/commands/undo/callable_command.gd")

# Signals
signal undo_performed(command_description: String)
signal redo_performed(command_description: String)
signal history_changed # Fired on push/undo/redo/clear
signal notification_requested(type: String, message: String)

var _undo_stack: Array = []
var _redo_stack: Array = []
var _enabled: bool = true

# Transaction state
var _transaction_depth: int = 0
var _transaction_name: String = ""
var _transaction_commands: Array = []

# Tracking state
var _drag_start_positions: Dictionary = {}
var _is_dragging: bool = false
var _params: Dictionary = {} # Optional params like { "signals_node": ..., "globals": ... }
var _is_undoing_or_redoing: bool = false
var _bulk_operation: bool = false

# Dependencies
var _logger = null

func _init(logger = null) -> void:
    _logger = logger

func setup(config: Dictionary = {}) -> void:
    # Connect to global signals if available
    var signals_node = Engine.get_main_loop().root.get_node_or_null("Signals")
    if signals_node:
        _connect_signals(signals_node)
    
    # Listen for new windows to track
    var desktop = Engine.get_main_loop().root.get_node_or_null("Main/MainContainer/GameViewport/Desktop")
    if desktop:
        var windows = desktop.get_node_or_null("Windows")
        if windows and not windows.child_entered_tree.is_connected(_check_new_window):
            windows.child_entered_tree.connect(_check_new_window)
    
    _log_info("UndoManager initialized found signals: %s" % (signals_node != null))

# ==============================================================================
# PUBLIC API
# ==============================================================================

func set_enabled(enabled: bool) -> void:
    _enabled = enabled
    if not enabled:
        clear()

func clear() -> void:
    _undo_stack.clear()
    _redo_stack.clear()
    cancel_action()
    history_changed.emit()

func can_undo() -> bool:
    return _enabled and not _undo_stack.is_empty()

func can_redo() -> bool:
    return _enabled and not _redo_stack.is_empty()

func undo() -> bool:
    if not _enabled or _undo_stack.is_empty():
        return false
    
    var command = _undo_stack.pop_back()
    
    if not command.is_valid():
        notification_requested.emit("exclamation", "Cannot undo: invalid state")
        return false
        
    _is_undoing_or_redoing = true
    var success = command.undo()
    _is_undoing_or_redoing = false
    
    if success:
        _redo_stack.push_back(command)
        undo_performed.emit(command.get_description())
        history_changed.emit()
    
    return success

func redo() -> bool:
    if not _enabled or _redo_stack.is_empty():
        return false
        
    var command = _redo_stack.pop_back()
    
    if not command.is_valid():
        notification_requested.emit("exclamation", "Cannot redo: invalid state")
        return false
        
    _is_undoing_or_redoing = true
    var success = command.execute()
    _is_undoing_or_redoing = false
    
    if success:
        _undo_stack.push_back(command)
        redo_performed.emit(command.get_description())
        history_changed.emit()
        
    return success

func push_command(command) -> void:
    if not _enabled: return
    
    if _transaction_depth > 0:
        _transaction_commands.append(command)
    else:
        _push_internal(command)

func begin_action(name: String) -> void:
    _transaction_depth += 1
    if _transaction_depth == 1:
        _transaction_name = name
        _transaction_commands.clear()

func commit_action() -> void:
    if _transaction_depth <= 0: return
    _transaction_depth -= 1
    
    if _transaction_depth == 0 and not _transaction_commands.is_empty():
        if _transaction_commands.size() == 1:
            _push_internal(_transaction_commands[0])
        else:
            var t_cmd = TransactionCommandScript.new(_transaction_name, _transaction_commands.duplicate())
            _push_internal(t_cmd)
        _transaction_commands.clear()

func cancel_action() -> void:
    _transaction_depth = 0
    _transaction_commands.clear()

func record_property_change(target: Object, property: String, before, after, label: String = "") -> void:
    if not _enabled: return
    var cmd = PropertyChangeCommandScript.new()
    cmd.setup(target, property, before, after, label)
    push_command(cmd)

func record_call(do_func: Callable, undo_func: Callable, label: String = "") -> void:
    if not _enabled: return
    var cmd = CallableCommandScript.new()
    cmd.setup(do_func, undo_func, label)
    push_command(cmd)

# ==============================================================================
# INTERNAL
# ==============================================================================

func _push_internal(command) -> void:
    if not _undo_stack.is_empty():
        var top = _undo_stack.back()
        if top.has_method("merge_with") and top.merge_with(command):
            return
            
    _undo_stack.push_back(command)
    _redo_stack.clear()
    
    while _undo_stack.size() > MAX_HISTORY_SIZE:
        _undo_stack.pop_front()
    
    history_changed.emit()

func _log_info(msg: String) -> void:
    if _logger: _logger.info("undo", msg)
    else: print(LOG_NAME + ": " + msg)

# ==============================================================================
# SIGNAL TRACKING (Auto-Record)
# ==============================================================================

func _connect_signals(signals: Node) -> void:
    if not signals.dragging_set.is_connected(_on_dragging_set):
        signals.dragging_set.connect(_on_dragging_set)
    if not signals.connection_created.is_connected(_on_connection_created):
        signals.connection_created.connect(_on_connection_created)
    if not signals.connection_deleted.is_connected(_on_connection_deleted):
        signals.connection_deleted.connect(_on_connection_deleted)
    if not signals.window_created.is_connected(_on_window_created):
        signals.window_created.connect(_on_window_created)
    if not signals.window_deleted.is_connected(_on_window_deleted):
        signals.window_deleted.connect(_on_window_deleted)

func _on_dragging_set() -> void:
    if not _enabled: return
    # We check the global 'dragging' state. 
    # Assumes Globals autoload exists basically everywhere in this game modding ctx
    var globals = Engine.get_main_loop().root.get_node_or_null("Globals")
    if not globals: return
    
    if globals.dragging and not _is_dragging:
        _is_dragging = true
        _snapshot_all_window_positions()
    elif not globals.dragging and _is_dragging:
        _is_dragging = false
        _create_move_command_if_changed()

func _snapshot_all_window_positions() -> void:
    _drag_start_positions.clear()
    var desktop = Engine.get_main_loop().root.get_node_or_null("Main/MainContainer/GameViewport/Desktop")
    if not desktop: return
    var windows = desktop.get_node_or_null("Windows")
    if not windows: return
    
    for child in windows.get_children():
        if is_instance_valid(child):
            _drag_start_positions[child] = child.position

func _create_move_command_if_changed() -> void:
    if _drag_start_positions.is_empty(): return
    
    var before_pos: Dictionary = {}
    var after_pos: Dictionary = {}
    
    for window in _drag_start_positions:
        if not is_instance_valid(window): continue
        var start = _drag_start_positions[window]
        var end = window.position
        if start.distance_to(end) > 0.1:
            before_pos[window.name] = start
            after_pos[window.name] = end
            
    if not before_pos.is_empty():
        var cmd = MoveNodesCommandScript.new()
        cmd.setup(before_pos, after_pos)
        push_command(cmd)
        
    _drag_start_positions.clear()

func _on_connection_created(out_id: String, in_id: String) -> void:
    if _should_ignore_signal(): return
    var out_node = _resolve_node(out_id)
    var in_node = _resolve_node(in_id)
    if not out_node or not in_node: return
    
    var out_win = _get_window(out_node)
    var in_win = _get_window(in_node)
    if not out_win or not in_win: return
    
    var cmd = ConnectCommandScript.new()
    cmd.setup(out_win.name, str(out_win.get_path_to(out_node)), in_win.name, str(in_win.get_path_to(in_node)))
    push_command(cmd)

func _on_connection_deleted(out_id: String, in_id: String) -> void:
    if _should_ignore_signal(): return
    var out_node = _resolve_node(out_id)
    var in_node = _resolve_node(in_id)
    if not out_node or not in_node: return
    
    var out_win = _get_window(out_node)
    var in_win = _get_window(in_node)
    if not out_win or not in_win: return
    
    var cmd = DisconnectCommandScript.new()
    cmd.setup(out_win.name, str(out_win.get_path_to(out_node)), in_win.name, str(in_win.get_path_to(in_node)))
    push_command(cmd)

func _on_window_created(window: Node) -> void:
    if not window.is_inside_tree(): return
    if _should_ignore_signal(): return
    
    var cmd = NodeCreatedCommandScript.new()
    cmd.setup(window.name)
    push_command(cmd)

func _on_window_deleted(window: Node) -> void:
    if _should_ignore_signal(): return
    
    var export_data = {}
    if window.has_method("export"):
        export_data = window.export()
    
    var importing = window.get("importing") if "importing" in window else false
    var cmd = NodeDeletedCommandScript.new()
    cmd.setup(window.name, export_data, window.position, importing)
    push_command(cmd)

func _check_new_window(node: Node) -> void:
    pass # Hook potential listeners if needed later

func _should_ignore_signal() -> bool:
    return not _enabled or _is_undoing_or_redoing or _bulk_operation

func _resolve_node(res_id: String) -> Node:
    var desktop = Engine.get_main_loop().root.get_node_or_null("Main/MainContainer/GameViewport/Desktop")
    if not desktop: return null
    return desktop.get_resource(res_id) # Assumes get_resource exists on desktop

func _get_window(node: Node) -> Node:
    var p = node
    while p:
        if p.name.begins_with("Window") or p.get_parent().name == "Windows": # Heuristic
             return p
        p = p.get_parent()
    return null
