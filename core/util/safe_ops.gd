# ==============================================================================
# Taj's Core - Safe Ops
# Author: TajemnikTV
# Description: Defensive helpers for common operations.
# ==============================================================================
class_name TajsCoreSafeOps
extends RefCounted

static func safe_get_node(path: NodePath, default: Node = null) -> Node:
	if path == null or String(path) == "":
		return default
	var tree = Engine.get_main_loop()
	if tree is SceneTree:
		var node = tree.root.get_node_or_null(path)
		if node != null:
			return node
	return default

static func safe_connect(signal_ref: Signal, callable: Callable) -> void:
	if signal_ref == null or callable == null or not callable.is_valid():
		return
	if signal_ref.is_connected(callable):
		return
	signal_ref.connect(callable)

static func safe_disconnect(signal_ref: Signal, callable: Callable) -> void:
	if signal_ref == null or callable == null or not callable.is_valid():
		return
	if not signal_ref.is_connected(callable):
		return
	signal_ref.disconnect(callable)

static func defer_until_ready(callback: Callable) -> void:
	if callback == null or not callback.is_valid():
		return
	callback.call_deferred()
