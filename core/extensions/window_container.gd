extends "res://scenes/windows/window_container.gd"

func _enter_tree() -> void:
    rid = RenderingServer.canvas_item_create()
    RenderingServer.canvas_item_set_parent(rid, get_canvas_item())
    if not item_rect_changed.is_connected(_on_item_rect_changed):
        item_rect_changed.connect(_on_item_rect_changed)

func _exit_tree() -> void:
    if item_rect_changed.is_connected(_on_item_rect_changed):
        item_rect_changed.disconnect(_on_item_rect_changed)
    super._exit_tree()

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
    if _has_global_class("TajsCoreNodeDefs"):
        return TajsCoreNodeDefs.make_save_filename(scene_file_path)
    return scene_file_path.get_file()


func _has_global_class(class_name_str: String) -> bool:
    for entry: Variant in ProjectSettings.get_global_class_list():
        if entry.get("class", "") == class_name_str:
            return true
    return false
