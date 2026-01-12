extends "res://scenes/windows/window_container.gd"

func export() -> Dictionary:
	var data := super ()
	data["filename"] = _get_save_filename()
	return data

func save() -> Dictionary:
	var data := super ()
	data["filename"] = _get_save_filename()
	return data

func _get_save_filename() -> String:
	if scene_file_path == "":
		return ""
	if ClassDB.class_exists("TajsCoreNodeDefs"):
		return TajsCoreNodeDefs.make_save_filename(scene_file_path)
	return scene_file_path.get_file()
