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

func paste(data: Dictionary) -> void:
	var seed: int = randi() / 10
	var new_windows: Dictionary
	var to_connect: Dictionary[String, Array]
	var required: int
	for window: String in data.windows:
		required += 1

		for resource: String in data.windows[window].container_data:
			var new_name: String = Utils.generate_id_from_seed(data.windows[window].container_data[resource].id.hash() + seed)
			data.windows[window].container_data[resource].id = new_name
			data.windows[window].container_data[resource].erase("count")
			to_connect[new_name] = []
			for output: String in data.windows[window].container_data[resource].outputs_id:
				to_connect[new_name].append(Utils.generate_id_from_seed(output.hash() + seed))
			data.windows[window].container_data[resource].outputs_id.clear()

		var new_name: String = find_window_name(window)
		new_windows[new_name] = data.windows[window].duplicate()
		new_windows[new_name].position -= data.rect.position - Globals.camera_center.snappedf(50) + (data.rect.size / 2)

	var limit := _get_node_limit()
	if limit >= 0 and required > limit - Globals.max_window_count:
		Signals.notify.emit("exclamation", "build_limit_reached")
		Sound.play("error")
		return

	data.windows = new_windows
	var windows_added: Array[WindowContainer]
	windows_added = add_windows_from_data(data.windows, true)
	Globals.set_selection(windows_added, [], 1)

	for i: String in data.connectors:
		var new_id: String = Utils.generate_id_from_seed(i.hash() + seed)
		data.connectors[i].pivot_pos -= data.rect.position - Globals.camera_center.snappedf(50) + (data.rect.size / 2)
		$Connectors.connector_data[new_id] = data.connectors[i]

	var connection_remaining: Dictionary[String, Array] = to_connect.duplicate(true)
	for i: String in to_connect:
		var container: ResourceContainer = get_resource(i)
		if !container: continue
		if container.resource.is_empty(): continue
		for output: String in to_connect[i]:
			Signals.create_connection.emit(i, output)
		connection_remaining.erase(i)

	for i: String in connection_remaining:
		for output: String in connection_remaining[i]:
			Signals.create_connection.emit(i, output)

	$Connectors.connector_data.clear()

func _resolve_window_path(filename: String, resolver) -> String:
	if filename == "":
		return ""
	if resolver != null:
		return resolver.resolve_scene_path(filename)
	return "res://scenes/windows/".path_join(filename)

func _get_scene_resolver():
	var core = Engine.get_meta("TajsCore", null)
	if core != null and core.window_scenes != null:
		return core.window_scenes
	return null

func _get_node_limit() -> int:
	var core = Engine.get_meta("TajsCore", null)
	if core != null and core.has_method("get"):
		var helper = core.get("node_limit_helpers")
		if helper != null and helper.has_method("get_node_limit"):
			return helper.get_node_limit()
	return Utils.MAX_WINDOW
