extends "res://scripts/data.gd"

func update_save(data: Dictionary) -> void:
	super (data)
	var core = Engine.get_meta("TajsCore", null)
	if core != null and core.window_scenes != null:
		core.window_scenes.normalize_saved_windows(data)
