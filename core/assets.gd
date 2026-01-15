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

func register_icon_dir(path: String, take_over: bool = true) -> int:
	if path == "":
		return 0
	var dir := DirAccess.open(path)
	if dir == null:
		return 0
	var count := 0
	for file_name in dir.get_files():
		if not file_name.ends_with(".png"):
			continue
		var texture: Texture2D = load(path.path_join(file_name))
		if texture == null:
			continue
		if take_over:
			texture.take_over_path("res://textures/icons".path_join(file_name))
		var resources = _get_autoload("Resources")
		if resources != null:
			if resources.icons == null:
				resources.icons = {}
			resources.icons[file_name] = texture
		count += 1
	return count

func _get_autoload(name: String) -> Object:
	if Engine.has_singleton(name):
		return Engine.get_singleton(name)
	var tree = Engine.get_main_loop()
	if not (tree is SceneTree):
		return null
	return tree.get_root().get_node_or_null(name)

func resolve_icon_path(icon_id: String, mod_id: String = "") -> String:
	if icon_id.begins_with("res://"):
		return icon_id
	if icon_id.ends_with(".png"):
		if mod_id != "":
			return _get_mod_path(mod_id).path_join(icon_id)
		return "res://textures/icons".path_join(icon_id)
	if mod_id != "":
		return _get_mod_path(mod_id).path_join("textures/icons").path_join(icon_id + ".png")
	return "res://textures/icons".path_join(icon_id + ".png")

func clear_cache() -> void:
	_cache.clear()


func _get_mod_path(mod_id: String) -> String:
	if mod_id == "":
		return ""
	if _has_global_class("ModLoaderMod"):
		return ModLoaderMod.get_unpacked_dir().path_join(mod_id)
	return "res://mods-unpacked".path_join(mod_id)


func _has_global_class(class_name_str: String) -> bool:
	for entry in ProjectSettings.get_global_class_list():
		if entry.get("class", "") == class_name_str:
			return true
	return false
