# ==============================================================================
# Taj's Core - Asset Manager
# Author: TajemnikTV
# Description: Shared icon/texture loading helpers.
# ==============================================================================
class_name TajsCoreAssets
extends RefCounted

var _cache: Dictionary = {}

func load_texture(path: String) -> Texture2D:
	if path == "":
		return null
	if _cache.has(path):
		return _cache[path]
	if not ResourceLoader.exists(path):
		return null
	var texture: Texture2D = load(path)
	if texture != null:
		_cache[path] = texture
	return texture

func load_icon(icon_id: String, mod_id: String = "") -> Texture2D:
	if icon_id == "":
		return null
	var path := resolve_icon_path(icon_id, mod_id)
	return load_texture(path)

func resolve_icon_path(icon_id: String, mod_id: String = "") -> String:
	if icon_id.begins_with("res://"):
		return icon_id
	if icon_id.ends_with(".png"):
		if mod_id != "":
			return TajsCoreUtil.get_mod_path(mod_id).path_join(icon_id)
		return "res://textures/icons".path_join(icon_id)
	if mod_id != "":
		return TajsCoreUtil.get_mod_path(mod_id).path_join("textures/icons").path_join(icon_id + ".png")
	return "res://textures/icons".path_join(icon_id + ".png")

func clear_cache() -> void:
	_cache.clear()
