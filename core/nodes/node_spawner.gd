# ==============================================================================
# Taj's Core - Node Spawner
# Author: TajemnikTV
# Description: Safe helpers for instantiating windows from registry defs.
# ==============================================================================
class_name TajsCoreNodeSpawner
extends RefCounted

var _registry
var _logger

func _init(registry, logger = null) -> void:
	_registry = registry
	_logger = logger

func spawn_window(node_id: String, position: Vector2 = Vector2.ZERO, emit_signal: bool = true) -> WindowContainer:
	if _registry == null or node_id == "":
		return null
	var def: Dictionary = _registry.get_node_def(node_id)
	if def.is_empty():
		_log_warn("nodes", "Unknown node '%s'." % node_id)
		return null
	var instance: WindowContainer = null
	if def.has("factory") and def["factory"] is Callable and def["factory"].is_valid():
		instance = def["factory"].call()
	elif def.has("packed_scene_path") and def["packed_scene_path"] != "":
		var scene = load(def["packed_scene_path"])
		if scene != null:
			instance = scene.instantiate()
	if instance == null:
		_log_warn("nodes", "Failed to spawn node '%s'." % node_id)
		return null
	instance.name = node_id.replace(".", "_")
	if position != Vector2.ZERO:
		instance.global_position = position
	if emit_signal and _autoload_ready("Signals"):
		Signals.create_window.emit(instance)
	else:
		_add_to_desktop(instance)
	return instance

func _add_to_desktop(instance: WindowContainer) -> void:
	if Globals == null or Globals.desktop == null:
		return
	var windows_root := Globals.desktop.get_node_or_null("Windows")
	if windows_root != null:
		windows_root.add_child(instance)
	else:
		Globals.desktop.add_child(instance)

func _autoload_ready(name: String) -> bool:
	var tree = Engine.get_main_loop()
	if not (tree is SceneTree):
		return false
	return tree.get_root().has_node(name)

func _log_warn(module_id: String, message: String) -> void:
	if _logger != null and _logger.has_method("warn"):
		_logger.warn(module_id, message)
