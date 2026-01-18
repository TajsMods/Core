# ==============================================================================
# Taj's Core - Desktop Layer Manager
# Author: TajemnikTV
# Description: Manages custom rendering layers on the game desktop.
#              Allows mods to inject Control nodes at specific positions
#              in the rendering order (before/after connectors, windows, etc.)
# ==============================================================================
extends RefCounted

const LOG_NAME := "DesktopLayers"

# Layer position constants - these define where in the Desktop's child order the layer is inserted
enum LayerPosition {
	BEFORE_LINES = 0, # After Background, before Lines
	BEFORE_CONNECTORS = 1, # After Lines, before Connectors (wires)
	BEFORE_WINDOWS = 2, # After Connectors, before Windows - IDEAL FOR GROUPS
	AFTER_WINDOWS = 3, # After Windows, before WindowSelections
	BEFORE_UI = 4 # After WindowSelections, before SelectionPanel
}

# Reference node names for each position (the layer is inserted BEFORE this node)
const POSITION_REFS := {
	LayerPosition.BEFORE_LINES: "Lines",
	LayerPosition.BEFORE_CONNECTORS: "Connectors",
	LayerPosition.BEFORE_WINDOWS: "Windows",
	LayerPosition.AFTER_WINDOWS: "WindowSelections",
	LayerPosition.BEFORE_UI: "SelectionPanel"
}

var _logger
var _event_bus
var _layers: Dictionary = {} # layer_id -> {node: Control, position: LayerPosition, owner: String}
var _desktop: Control = null
var _pending_layers: Array = [] # Layers registered before desktop was ready


func _init(logger = null, event_bus = null) -> void:
	_logger = logger
	_event_bus = event_bus


func setup() -> void:
	# Listen for desktop ready event
	if _event_bus != null:
		_event_bus.on("game.desktop_ready", Callable(self, "_on_desktop_ready"), self, true)
	# Also try to get desktop immediately if it's already available
	_try_get_desktop()


func _on_desktop_ready(_payload: Dictionary) -> void:
	_try_get_desktop()
	_inject_pending_layers()


func _try_get_desktop() -> void:
	if _desktop != null and is_instance_valid(_desktop):
		return
	if Globals != null and is_instance_valid(Globals.desktop):
		_desktop = Globals.desktop
		_log_debug("Desktop reference acquired")


func _inject_pending_layers() -> void:
	if _desktop == null:
		return
	for pending in _pending_layers:
		_inject_layer(pending.id, pending.position, pending.owner)
	_pending_layers.clear()


## Registers a new rendering layer at the specified position.
## Returns the Control node that content can be added to, or null if registration failed.
## If the desktop isn't ready yet, the layer will be created when it becomes available.
##
## Parameters:
## - layer_id: Unique identifier for this layer
## - position: LayerPosition enum value determining where the layer is inserted
## - owner_mod: ID of the mod registering this layer (for debugging/conflict resolution)
##
## Returns: Control node to parent content to, or null if layer_id already exists
func register_layer(layer_id: String, position: int, owner_mod: String = "") -> Control:
	if _layers.has(layer_id):
		_log_warn("Layer '%s' already registered by '%s'" % [layer_id, _layers[layer_id].owner])
		return _layers[layer_id].node
	
	# Create the layer node immediately so mods can parent to it
	var layer_node := Control.new()
	layer_node.name = "CoreLayer_%s" % layer_id
	layer_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer_node.set_anchors_preset(Control.PRESET_TOP_LEFT)
	
	_layers[layer_id] = {
		"node": layer_node,
		"position": position,
		"owner": owner_mod
	}
	
	if _desktop != null and is_instance_valid(_desktop):
		_inject_layer(layer_id, position, owner_mod)
	else:
		_pending_layers.append({"id": layer_id, "position": position, "owner": owner_mod})
		_log_debug("Layer '%s' queued for injection (desktop not ready)" % layer_id)
	
	return layer_node


## Gets an existing layer by ID.
## Returns: Control node for the layer, or null if not found
func get_layer(layer_id: String) -> Control:
	if _layers.has(layer_id):
		return _layers[layer_id].node
	return null


## Checks if a layer exists
func has_layer(layer_id: String) -> bool:
	return _layers.has(layer_id)


## Removes a layer and all its children
func remove_layer(layer_id: String) -> void:
	if not _layers.has(layer_id):
		return
	var entry = _layers[layer_id]
	if is_instance_valid(entry.node):
		entry.node.queue_free()
	_layers.erase(layer_id)
	_log_debug("Layer '%s' removed" % layer_id)


## Returns list of all registered layer IDs
func get_all_layer_ids() -> Array:
	return _layers.keys()


## Reparents a node to a specific layer.
## Useful for moving existing nodes (like group windows) to a different layer.
func reparent_to_layer(node: Node, layer_id: String) -> bool:
	if not _layers.has(layer_id):
		_log_warn("Cannot reparent to layer '%s': layer not found" % layer_id)
		return false
	if not is_instance_valid(node):
		return false
	
	var layer_node: Control = _layers[layer_id].node
	if not is_instance_valid(layer_node):
		return false
	
	# Store original parent for potential restoration
	var old_parent = node.get_parent()
	
	# Reparent the node
	if old_parent != null:
		old_parent.remove_child(node)
	layer_node.add_child(node)
	
	return true


func _inject_layer(layer_id: String, position: int, owner_mod: String) -> void:
	if not _layers.has(layer_id):
		return
	if _desktop == null or not is_instance_valid(_desktop):
		_log_warn("Cannot inject layer '%s': desktop not available" % layer_id)
		return
	
	var layer_node: Control = _layers[layer_id].node
	if layer_node.get_parent() == _desktop:
		# Already injected
		return
	
	var ref_name: String = POSITION_REFS.get(position, "Windows")
	var ref_node = _desktop.get_node_or_null(ref_name)
	
	if ref_node == null:
		_log_warn("Reference node '%s' not found in Desktop, adding layer at end" % ref_name)
		_desktop.add_child(layer_node)
	else:
		var ref_index = ref_node.get_index()
		_desktop.add_child(layer_node)
		_desktop.move_child(layer_node, ref_index)
	
	_log_info("Layer '%s' injected at position %s (before %s) by '%s'" % [layer_id, position, ref_name, owner_mod])


func _log_debug(message: String) -> void:
	if _logger != null and _logger.has_method("debug"):
		_logger.debug(LOG_NAME, message)


func _log_info(message: String) -> void:
	if _logger != null and _logger.has_method("info"):
		_logger.info(LOG_NAME, message)


func _log_warn(message: String) -> void:
	if _logger != null and _logger.has_method("warn"):
		_logger.warn(LOG_NAME, message)
	else:
		push_warning("%s: %s" % [LOG_NAME, message])
