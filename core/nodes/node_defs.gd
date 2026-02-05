class_name TajsCoreNodeDefs
extends RefCounted

static func make_scene_entry(packed_scene_path: String) -> String:
    if packed_scene_path == "":
        return ""
    var normalized := _ensure_res_path(packed_scene_path)
    if normalized == "":
        return ""
    if normalized.ends_with(".tscn"):
        normalized = normalized.substr(0, normalized.length() - 5)
    return _make_relative_path("res://scenes/windows", normalized)

static func make_save_filename(packed_scene_path: String) -> String:
    if packed_scene_path == "":
        return ""
    var normalized := _ensure_res_path(packed_scene_path)
    if normalized == "":
        return ""
    if not normalized.ends_with(".tscn"):
        normalized += ".tscn"
    return _make_relative_path("res://scenes/windows", normalized)

static func make_icon_entry(icon_path: String) -> String:
    if icon_path == "":
        return ""
    if not icon_path.begins_with("res://"):
        return icon_path
    var normalized := icon_path
    if normalized.ends_with(".png"):
        normalized = normalized.substr(0, normalized.length() - 4)
    return _make_relative_path("res://textures/icons", normalized)

static func scene_entry_to_path(scene_entry: String) -> String:
    if scene_entry == "":
        return ""
    return "res://scenes/windows/".path_join(scene_entry + ".tscn")

static func icon_entry_to_path(icon_entry: String) -> String:
    if icon_entry == "":
        return ""
    return "res://textures/icons/".path_join(icon_entry + ".png")

static func _ensure_res_path(path: String) -> String:
    if path.begins_with("res://"):
        return path
    return ""

static func _make_relative_path(from_dir: String, to_path: String) -> String:
    var from_parts := from_dir.trim_prefix("res://").split("/", false)
    var to_parts := to_path.trim_prefix("res://").split("/", false)
    while from_parts.size() > 0 and to_parts.size() > 0 and from_parts[0] == to_parts[0]:
        from_parts.remove_at(0)
        to_parts.remove_at(0)
    var rel_parts: Array[String] = []
    for _i in from_parts:
        rel_parts.append("..")
    rel_parts.append_array(to_parts)
    return "/".join(rel_parts)
