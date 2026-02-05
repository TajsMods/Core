class_name TajsCoreUndoManager
extends RefCounted

const LOG_NAME = "TajsCore:UndoManager"
const MAX_HISTORY_SIZE := 100

# Preload Core commands
const TransactionCommandScript = preload("res://mods-unpacked/TajemnikTV-Core/core/commands/undo/transaction_command.gd")
const MoveNodesCommandScript = preload("res://mods-unpacked/TajemnikTV-Core/core/commands/undo/move_nodes_command.gd")
const ResizeNodesCommandScript = preload("res://mods-unpacked/TajemnikTV-Core/core/commands/undo/resize_nodes_command.gd")
const ConnectCommandScript = preload("res://mods-unpacked/TajemnikTV-Core/core/commands/undo/connect_command.gd")
const DisconnectCommandScript = preload("res://mods-unpacked/TajemnikTV-Core/core/commands/undo/disconnect_command.gd")
const NodeCreatedCommandScript = preload("res://mods-unpacked/TajemnikTV-Core/core/commands/undo/node_created_command.gd")
const NodeDeletedCommandScript = preload("res://mods-unpacked/TajemnikTV-Core/core/commands/undo/node_deleted_command.gd")
const PropertyChangeCommandScript = preload("res://mods-unpacked/TajemnikTV-Core/core/commands/undo/property_change_command.gd")
const CallableCommandScript = preload("res://mods-unpacked/TajemnikTV-Core/core/commands/undo/callable_command.gd")
const GroupColorCommandScript = preload("res://mods-unpacked/TajemnikTV-Core/core/commands/undo/group_color_command.gd")
const PauseNodesCommandScript = preload("res://mods-unpacked/TajemnikTV-Core/core/commands/undo/pause_nodes_command.gd")
const GroupNodeChangedCommandScript = preload("res://mods-unpacked/TajemnikTV-Core/core/commands/undo/group_node_changed_command.gd")

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
var _drag_start_sizes: Dictionary = {}
var _drag_start_size_positions: Dictionary = {} # Resize can move window (left/top edges)
var _group_color_snapshots: Dictionary = {} # window -> color index before change
var _window_clean_data: Dictionary = {} # window_name -> saved data (for group_changed tracking)
var _is_dragging: bool = false
@warning_ignore("unused_private_class_variable")
var _params: Dictionary = {} # Optional params like { "signals_node": ..., "globals": ... }
var _is_undoing_or_redoing: bool = false
var _bulk_operation: bool = false
var _signals_connected: bool = false
var _recording: bool = false # Only true after boot signal - prevents recording during initial load
var _debug_enabled: bool = false # Enable verbose logging (set via setup config)

# Dependencies
var _logger = null

func _init(logger = null) -> void:
    _logger = logger

func setup(config: Dictionary = {}) -> void:
    _debug_enabled = config.get("debug", false)
    # Defer signal connection to ensure Signals autoload exists
    # The undo_manager is created early during Core bootstrap, before autoloads are ready
    _try_connect_signals_deferred()

    _log_debug("UndoManager setup initiated (signal connection deferred)")

func _try_connect_signals_deferred() -> void:
    # Use process_frame to retry until Signals autoload exists
    var main_loop = Engine.get_main_loop()
    if main_loop == null:
        _log_debug("MainLoop not available yet, will retry")
        # Can't do much without main loop, try call_deferred as last resort
        _try_connect_signals_once.call_deferred()
        return

    # SceneTree has process_frame signal
    if main_loop.has_signal("process_frame"):
        main_loop.process_frame.connect(_try_connect_signals_once, CONNECT_ONE_SHOT)
    else:
        _log_debug("process_frame signal not found, trying immediately")
        _try_connect_signals_once()

func _try_connect_signals_once() -> void:
    if _signals_connected:
        return

    var main_loop = Engine.get_main_loop()
    if main_loop == null:
        return

    var signals_node = main_loop.root.get_node_or_null("Signals")
    if signals_node:
        _connect_signals(signals_node)
        _signals_connected = true
        _log_debug("Connected to Signals autoload (deferred)")

        # Also set up Windows child tracking now
        _setup_windows_tracking()
    else:
        # Signals not ready yet, retry next frame
        if main_loop.has_signal("process_frame"):
            main_loop.process_frame.connect(_try_connect_signals_once, CONNECT_ONE_SHOT)

func _setup_windows_tracking() -> void:
    if Globals.desktop:
        var windows = Globals.desktop.get_node_or_null("Windows")
        if windows:
            if not windows.child_entered_tree.is_connected(_on_window_added_to_tree):
                windows.child_entered_tree.connect(_on_window_added_to_tree)
            # Hook existing windows for color tracking
            for child in windows.get_children():
                _hook_window_signals(child)

# ==============================================================================
# PUBLIC API
# ==============================================================================

func set_enabled(enabled: bool) -> void:
    _enabled = enabled
    if not enabled:
        clear()

func is_enabled() -> bool:
    return _enabled

func get_undo_stack_size() -> int:
    return _undo_stack.size()

func get_redo_stack_size() -> int:
    return _redo_stack.size()

func get_undo_description() -> String:
    if _undo_stack.is_empty():
        return ""
    return _undo_stack.back().get_description()

func get_redo_description() -> String:
    if _redo_stack.is_empty():
        return ""
    return _redo_stack.back().get_description()

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
    _log_debug("undo() called - enabled: %s, stack size: %d" % [_enabled, _undo_stack.size()])
    if not _enabled:
        _notify("exclamation", "Undo/Redo disabled")
        return false

    if _undo_stack.is_empty():
        _notify("exclamation", "Nothing to undo")
        return false

    var command = _undo_stack.pop_back()
    _log_debug("Undoing command: %s, valid: %s" % [command.get_description(), command.is_valid()])

    if not command.is_valid():
        _notify("exclamation", "Cannot undo: invalid state")
        notification_requested.emit("exclamation", "Cannot undo: invalid state")
        return false

    _is_undoing_or_redoing = true
    var success = command.undo()
    _is_undoing_or_redoing = false

    _log_debug("Undo result: %s" % success)

    if success:
        _redo_stack.push_back(command)
        undo_performed.emit(command.get_description())
        history_changed.emit()
    else:
        _notify("exclamation", "Undo failed")

    return success

func redo() -> bool:
    if not _enabled:
        _notify("exclamation", "Undo/Redo disabled")
        return false

    if _redo_stack.is_empty():
        _notify("exclamation", "Nothing to redo")
        return false

    var command = _redo_stack.pop_back()

    if not command.is_valid():
        _notify("exclamation", "Cannot redo: invalid state")
        notification_requested.emit("exclamation", "Cannot redo: invalid state")
        return false

    _is_undoing_or_redoing = true
    var success = command.execute()
    _is_undoing_or_redoing = false

    if success:
        _undo_stack.push_back(command)
        redo_performed.emit(command.get_description())
        history_changed.emit()
    else:
        _notify("exclamation", "Redo failed")

    return success

func push_command(command) -> void:
    if not _enabled: return

    if _transaction_depth > 0:
        _transaction_commands.append(command)
        _log_debug("Command added to transaction: %s" % command.get_description())
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

## Record a pause state change for multiple windows
func record_pause_change(window_states_before: Dictionary, window_states_after: Dictionary) -> void:
    if not _enabled: return
    if window_states_before.is_empty(): return

    var cmd = PauseNodesCommandScript.new()
    cmd.setup(window_states_before, window_states_after)
    push_command(cmd)

# ==============================================================================
# INTERNAL
# ==============================================================================

func _push_internal(command) -> void:
    if not _undo_stack.is_empty():
        var top = _undo_stack.back()
        if top.has_method("merge_with") and top.merge_with(command):
            _log_debug("Command merged with previous: %s" % command.get_description())
            return

    _undo_stack.push_back(command)
    _redo_stack.clear()

    while _undo_stack.size() > MAX_HISTORY_SIZE:
        _undo_stack.pop_front()

    _log_debug("Command pushed to undo stack: %s (stack size: %d)" % [command.get_description(), _undo_stack.size()])
    history_changed.emit()

func _log_info(msg: String) -> void:
    if _logger: _logger.info("undo", msg)
    else: print(LOG_NAME + ": " + msg)

func _log_debug(msg: String) -> void:
    if not _debug_enabled: return
    _log_info(msg)

func _notify(icon: String, message: String) -> void:
    # Use vanilla Signals.notify if available
    var main_loop = Engine.get_main_loop()
    if main_loop and main_loop.root:
        var signals_node = main_loop.root.get_node_or_null("Signals")
        if signals_node and signals_node.has_signal("notify"):
            signals_node.notify.emit(icon, message)
            return
    # Fallback: emit our own signal
    notification_requested.emit(icon, message)

func _play_sound(sound_name: String) -> void:
    # Use vanilla Sound autoload if available
    var main_loop = Engine.get_main_loop()
    if main_loop and main_loop.root:
        var sound_node = main_loop.root.get_node_or_null("Sound")
        if sound_node and sound_node.has_method("play"):
            sound_node.play(sound_name)

func _get_windows_container() -> Node:
    if not Globals.desktop:
        return null
    return Globals.desktop.get_node_or_null("Windows")

# ==============================================================================
# SIGNAL TRACKING (Auto-Record)
# ==============================================================================

func _connect_signals(signals: Node) -> void:
    # Boot signal - only start recording after game is fully loaded
    if signals.has_signal("boot"):
        if not signals.boot.is_connected(_on_boot):
            signals.boot.connect(_on_boot)

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
    # Schematic paste transaction wrapping
    if signals.has_signal("place_schematic"):
        if not signals.place_schematic.is_connected(_on_place_schematic_begin):
            signals.place_schematic.connect(_on_place_schematic_begin)

func _on_boot() -> void:
    # Game has fully loaded - now we can start recording undo actions
    _recording = true
    clear()
    _log_debug("Boot signal received - recording enabled, history cleared")

func _on_dragging_set() -> void:
    if not _enabled or not _recording: return
    if _is_undoing_or_redoing: return

    _log_debug("dragging_set signal: Globals.dragging=%s, _is_dragging=%s" % [Globals.dragging, _is_dragging])

    if Globals.dragging and not _is_dragging:
        _is_dragging = true
        _snapshot_all_window_positions()
        _snapshot_all_window_sizes()
    elif not Globals.dragging and _is_dragging:
        _is_dragging = false
        _create_move_command_if_changed()
        _create_resize_command_if_changed()

func _snapshot_all_window_positions() -> void:
    _drag_start_positions.clear()
    var windows = _get_windows_container()
    if not windows: return

    for child in windows.get_children():
        if is_instance_valid(child):
            _drag_start_positions[child] = child.position

func _snapshot_all_window_sizes() -> void:
    _drag_start_sizes.clear()
    _drag_start_size_positions.clear()
    var windows = _get_windows_container()
    if not windows: return

    for child in windows.get_children():
        if is_instance_valid(child) and "size" in child:
            _drag_start_sizes[child] = child.size
            _drag_start_size_positions[child] = child.position

func _create_move_command_if_changed() -> void:
    if _drag_start_positions.is_empty(): return

    var before_pos: Dictionary = {}
    var after_pos: Dictionary = {}

    for window in _drag_start_positions:
        if not is_instance_valid(window): continue
        var start = _drag_start_positions[window]
        var end = window.position
        # Only count as move if size didn't change (otherwise it's a resize)
        var size_changed := false
        if window in _drag_start_sizes:
            var start_size = _drag_start_sizes[window]
            if "size" in window and start_size.distance_to(window.size) > 0.1:
                size_changed = true

        if not size_changed and start.distance_to(end) > 0.1:
            before_pos[window.name] = start
            after_pos[window.name] = end

    if not before_pos.is_empty():
        var cmd = MoveNodesCommandScript.new()
        cmd.setup(before_pos, after_pos)
        push_command(cmd)

    _drag_start_positions.clear()

func _create_resize_command_if_changed() -> void:
    if _drag_start_sizes.is_empty(): return

    var before_data: Dictionary = {}
    var after_data: Dictionary = {}

    for window in _drag_start_sizes:
        if not is_instance_valid(window): continue
        if not "size" in window: continue

        var start_size = _drag_start_sizes[window]
        var start_pos = _drag_start_size_positions.get(window, window.position)
        var end_size = window.size
        var end_pos = window.position

        # Check if size actually changed
        if start_size.distance_to(end_size) > 0.1:
            before_data[window.name] = {"size": start_size, "position": start_pos}
            after_data[window.name] = {"size": end_size, "position": end_pos}

    if not before_data.is_empty():
        var cmd = ResizeNodesCommandScript.new()
        cmd.setup(before_data, after_data)
        push_command(cmd)

    _drag_start_sizes.clear()
    _drag_start_size_positions.clear()

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
    _log_debug("window_created signal received: %s, in_tree: %s, ignore: %s" % [window.name, window.is_inside_tree(), _should_ignore_signal()])
    if not window.is_inside_tree(): return
    if _should_ignore_signal(): return

    # Hook signals for this new window
    _hook_window_signals(window)

    var cmd = NodeCreatedCommandScript.new()
    cmd.setup(window.name)
    push_command(cmd)
    _log_debug("Pushed NodeCreatedCommand for %s" % window.name)

func _on_window_deleted(window: Node) -> void:
    _log_debug("window_deleted signal received: %s, ignore: %s" % [window.name, _should_ignore_signal()])
    if _should_ignore_signal(): return

    # Clean up color snapshot
    _group_color_snapshots.erase(window)

    var export_data = {}
    if window.has_method("export"):
        export_data = window.export()

    var importing = window.get("importing") if "importing" in window else false
    var cmd = NodeDeletedCommandScript.new()
    cmd.setup(window.name, export_data, window.position, importing)
    push_command(cmd)
    _log_debug("Pushed NodeDeletedCommand for %s" % window.name)

func _on_window_added_to_tree(node: Node) -> void:
    # Hook signals for newly added windows
    _hook_window_signals(node)

func _hook_window_signals(window: Node) -> void:
    # Hook color_changed for window_group nodes (vanilla color cycling)
    if window.has_signal("color_changed"):
        if not window.color_changed.is_connected(_on_group_color_changed.bind(window)):
            window.color_changed.connect(_on_group_color_changed.bind(window))
        # Snapshot current color
        if "color" in window:
            _group_color_snapshots[window] = window.color

    # Hook group_changed for full group tracking (name, icon, pattern changes)
    if window.has_signal("group_changed"):
        if not window.group_changed.is_connected(_on_group_node_changed.bind(window)):
            window.group_changed.connect(_on_group_node_changed.bind(window))

    # Snapshot window data for group tracking (any window with save() method)
    if window.has_method("save"):
        var window_name = str(window.name)
        _window_clean_data[window_name] = window.save()

func _on_group_color_changed(window: Node) -> void:
    if _should_ignore_signal(): return
    if not is_instance_valid(window): return
    if not "color" in window: return

    var before = _group_color_snapshots.get(window, 0)
    var after = window.color

    if before != after:
        var cmd = GroupColorCommandScript.new()
        cmd.setup(window.name, before, after)
        push_command(cmd)

    # Update snapshot for next change
    _group_color_snapshots[window] = after

func _on_group_node_changed(window: Node) -> void:
    if _should_ignore_signal(): return
    if not is_instance_valid(window): return
    if not window.has_method("save"): return

    var window_name = str(window.name)
    var after = window.save()

    if not _window_clean_data.has(window_name):
        _window_clean_data[window_name] = after
        return

    var before = _window_clean_data[window_name]

    # Compare using hash for efficiency
    if before.hash() == after.hash():
        return

    var cmd = GroupNodeChangedCommandScript.new()
    cmd.setup(window_name, before, after)
    push_command(cmd)

    # Update snapshot for next change
    _window_clean_data[window_name] = after

func _on_place_schematic_begin(_schematic: String) -> void:
    if _should_ignore_signal(): return
    begin_action("Paste Schematic")
    # Commit after paste completes - use call_deferred to run after current frame
    _commit_schematic_paste.call_deferred()

func _commit_schematic_paste() -> void:
    commit_action()

func _should_ignore_signal() -> bool:
    return not _enabled or not _recording or _is_undoing_or_redoing or _bulk_operation

func _resolve_node(res_id: String) -> Node:
    if not Globals.desktop:
        return null
    return Globals.desktop.get_resource(res_id)

func _get_window(node: Node) -> Node:
    var p = node
    while p:
        if p.name.begins_with("Window") or p.get_parent().name == "Windows": # Heuristic
             return p
        p = p.get_parent()
    return null
