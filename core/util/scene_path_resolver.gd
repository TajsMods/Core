class_name TajsCoreScenePathResolver
extends RefCounted

const DEFAULT_WINDOW_DIRS: Array[String] = [
    "res://scenes/windows/"
]

func resolve_window_scene(scene_value: Variant, extra_dirs: Array[String] = []) -> Dictionary:
    var original: String = str(scene_value).strip_edges()
    var attempted: Array[String] = []
    if original.is_empty():
        return {"original": original, "resolved": "", "attempted": attempted}

    var candidates: Array[String] = []
    if original.begins_with("res://"):
        candidates.append(_ensure_tscn(original))
    elif original.ends_with(".tscn"):
        candidates.append(original)
        for dir_path: String in _merge_dirs(extra_dirs):
            candidates.append(dir_path + original)
    else:
        var with_ext: String = original + ".tscn"
        candidates.append(with_ext)
        for dir_path: String in _merge_dirs(extra_dirs):
            candidates.append(dir_path + with_ext)

    for candidate: String in candidates:
        if attempted.has(candidate):
            continue
        attempted.append(candidate)
        if ResourceLoader.exists(candidate):
            return {"original": original, "resolved": candidate, "attempted": attempted}

    var fallback: String = attempted[0] if attempted.size() > 0 else ""
    return {"original": original, "resolved": fallback, "attempted": attempted}

func _merge_dirs(extra_dirs: Array[String]) -> Array[String]:
    var merged: Array[String] = []
    for base_dir: String in DEFAULT_WINDOW_DIRS:
        merged.append(_ensure_dir_suffix(base_dir))
    for dir_path: String in extra_dirs:
        var normalized: String = _ensure_dir_suffix(str(dir_path))
        if normalized.is_empty() or merged.has(normalized):
            continue
        merged.append(normalized)
    return merged

func _ensure_tscn(path: String) -> String:
    return path if path.ends_with(".tscn") else (path + ".tscn")

func _ensure_dir_suffix(dir_path: String) -> String:
    var normalized: String = str(dir_path).strip_edges()
    if normalized.is_empty():
        return ""
    return normalized if normalized.ends_with("/") else (normalized + "/")
