extends "res://scenes/window_dragger.gd"

func place() -> void:
	if Globals.max_window_count >= Utils.MAX_WINDOW:
		Signals.notify.emit("exclamation", "build_limit_reached")
		Sound.play("error")
	elif Utils.can_add_window(window):
		var path := _resolve_window_scene(window)
		if path != "":
			var instance: WindowContainer = load(path).instantiate()
			instance.name = window
			var instance_pos: Vector2 = Utils.screen_to_world_pos(global_position + size / 2)
			instance.global_position = (instance_pos - Vector2(175, instance.size.y / 2)).snappedf(50)
			Signals.create_window.emit(instance)

	Globals.dragging = false
	Signals.dragging_set.emit()

	queue_free()

func _resolve_window_scene(window_id: String) -> String:
	if not Data.windows.has(window_id):
		return ""
	var scene := str(Data.windows[window_id].scene)
	if scene == "":
		return ""
	var core := TajsCoreRuntime.instance()
	if core != null and core.window_scenes != null:
		return core.window_scenes.resolve_scene_path(scene)
	var file_name := scene
	if not file_name.ends_with(".tscn"):
		file_name += ".tscn"
	return "res://scenes/windows".path_join(file_name)
