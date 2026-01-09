# ==============================================================================
# Taj's Core - Node Finder
# Author: TajemnikTV
# Description: Helpers for querying windows and connections.
# ==============================================================================
class_name TajsCoreNodeFinder
extends RefCounted

func find_windows_by_type(type: String) -> Array[WindowContainer]:
	var results: Array[WindowContainer] = []
	var windows_root := _get_windows_root()
	if windows_root == null:
		return results
	for node in windows_root.get_children():
		if node is WindowContainer:
			if _matches_type(node, type):
				results.append(node)
	return results

func find_windows_by_pattern(pattern: String) -> Array[WindowContainer]:
	var results: Array[WindowContainer] = []
	var windows_root := _get_windows_root()
	if windows_root == null:
		return results
	var regex := RegEx.new()
	if regex.compile(pattern) != OK:
		return results
	for node in windows_root.get_children():
		if node is WindowContainer and regex.search(node.name) != null:
			results.append(node)
	return results

func find_windows_by_predicate(predicate: Callable) -> Array[WindowContainer]:
	var results: Array[WindowContainer] = []
	if predicate == null or not predicate.is_valid():
		return results
	var windows_root := _get_windows_root()
	if windows_root == null:
		return results
	for node in windows_root.get_children():
		if node is WindowContainer:
			if predicate.call(node):
				results.append(node)
	return results

func get_window_by_name(name: String) -> WindowContainer:
	if name == "":
		return null
	var windows_root := _get_windows_root()
	if windows_root == null:
		return null
	var direct := windows_root.get_node_or_null(name)
	if direct is WindowContainer:
		return direct
	var sanitized := name.replace(".", "_")
	var fallback := windows_root.get_node_or_null(sanitized)
	if fallback is WindowContainer:
		return fallback
	for node in windows_root.get_children():
		if node is WindowContainer and node.name.to_lower() == name.to_lower():
			return node
	return null

func get_all_connected_to(window: WindowContainer) -> Array[WindowContainer]:
	var results: Array[WindowContainer] = []
	if window == null:
		return results
	var containers: Array = []
	if window.has_method("get"):
		containers = window.get("containers") if window.get("containers") != null else []
	for container in containers:
		if container is ResourceContainer:
			for output in container.outputs:
				var target = _find_window_root(output)
				if target != null and not results.has(target):
					results.append(target)
			if container.input != null:
				var input_window = _find_window_root(container.input)
				if input_window != null and not results.has(input_window):
					results.append(input_window)
	return results

func _get_windows_root() -> Node:
	if Globals == null or Globals.desktop == null:
		return null
	return Globals.desktop.get_node_or_null("Windows")

func _find_window_root(node: Node) -> WindowContainer:
	var cursor := node
	while cursor != null:
		if cursor is WindowContainer:
			return cursor
		cursor = cursor.get_parent()
	return null

func _matches_type(window: WindowContainer, type: String) -> bool:
	if window.name == type:
		return true
	if window.name.to_lower() == type.to_lower():
		return true
	var safe_type := type.replace(".", "_")
	if window.name == safe_type:
		return true
	if window.scene_file_path != "":
		var scene_name := window.scene_file_path.get_file().get_basename()
		if scene_name.to_lower() == type.to_lower():
			return true
	return false
