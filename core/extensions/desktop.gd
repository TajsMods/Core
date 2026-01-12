extends "res://scripts/desktop.gd"

func add_windows_from_data(data: Dictionary, importing: bool = false) -> Array[WindowContainer]:
	var windows: Array[WindowContainer]
	var resolver = _get_scene_resolver()

	for window_id: String in data:
		if not data[window_id].has("filename"):
			continue
		var filename := str(data[window_id].filename)
		var path := _resolve_window_path(filename, resolver)
		if path == "" or not ResourceLoader.exists(path):
			continue
		var new_object: Control = get_node_or_null("Desktop/Windows/" + window_id)
		if not new_object:
			new_object = load(path).instantiate()
			new_object.importing = importing
			for key: String in data[window_id]:
				new_object.set(key, data[window_id][key])
			new_object.name = window_id
			$Windows.add_child(new_object)
			windows.append(new_object)
		else:
			new_object.name = window_id
			for key: String in data[window_id]:
				new_object.set(key, data[window_id][key])

	return windows

func _resolve_window_path(filename: String, resolver) -> String:
	if filename == "":
		return ""
	if resolver != null:
		return resolver.resolve_scene_path(filename)
	return "res://scenes/windows/".path_join(filename)

func _get_scene_resolver():
	var core := TajsCoreRuntime.instance()
	if core != null and core.window_scenes != null:
		return core.window_scenes
	return null
