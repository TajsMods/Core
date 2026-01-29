# ==============================================================================
# Taj's Core - Icon Registry
# Author: TajemnikTV
# Description: Collects and resolves icons from the base game, Core, and mods.
# ==============================================================================
class_name TajsCoreIconRegistry
extends Node

const Util = preload("util.gd")

const DEFAULT_ICON_PATH := "res://textures/icons/puzzle.png"
const DEFAULT_ICON_ID := "base:puzzle.png"
const ICON_EXTENSIONS := [".png"]
const GROUP_BASE := "base"
const GROUP_CORE := "core"
const GROUP_MODS := "mods"

var _assets
var _icons: Array = []
var _icons_by_id: Dictionary = {}
var _custom_sources: Dictionary = {}
var _source_labels: Dictionary = {}
var _cache_ready: bool = false

func _init(assets = null) -> void:
	_assets = assets
	_register_builtin_sources()

func get_all_icons() -> Array:
	_ensure_index()
	return _icons.duplicate()

func get_all_icons_by_group(group_filter: String = "") -> Array:
	_ensure_index()
	if group_filter == "":
		return _icons.duplicate()
	var results := []
	for entry in _icons:
		if _get_source_group(entry.get("source_id", "")) == group_filter:
			results.append(entry)
	return results

func get_source_label(source_id: String) -> String:
	if source_id == "":
		return ""
	if _source_labels.has(source_id):
		return _source_labels[source_id]
	var group := _get_source_group(source_id)
	if group == GROUP_MODS:
		return "Mods"
	if group == GROUP_CORE:
		return "Core"
	if group == GROUP_BASE:
		return "Base Game"
	return source_id

func get_group_counts(allowed_groups: Array = []) -> Dictionary:
	_ensure_index()
	var counts := {GROUP_BASE: 0, GROUP_CORE: 0, GROUP_MODS: 0}
	for entry in _icons:
		if _matches_allowed(entry, allowed_groups):
			var group := _get_source_group(entry.get("source_id", ""))
			if counts.has(group):
				counts[group] += 1
	return counts

func resolve_icon(icon_id: String) -> Dictionary:
	_ensure_index()
	var entry := _icons_by_id.get(icon_id, null)
	var result := {
		"texture": null,
		"entry": entry,
		"path": "",
		"missing": true
	}
	if entry != null:
		result.path = entry.get("path", "")
		var tex := _load_texture(result.path)
		if tex != null:
			result.texture = tex
			result.missing = false
			return result
	if result.path == "":
		result.path = DEFAULT_ICON_PATH
	result.texture = _load_texture(result.path)
	return result

func register_source(source_id: String, label: String, lister: Callable) -> bool:
	if source_id == "" or label == "" or lister == null:
		return false
	if _custom_sources.has(source_id):
		return false
	_source_labels[source_id] = label
	_custom_sources[source_id] = lister
	_cache_ready = false
	return true

func refresh_index() -> void:
	_cache_ready = false

func get_default_icon_id() -> String:
	return DEFAULT_ICON_ID

func get_default_icon_path() -> String:
	return DEFAULT_ICON_PATH

func get_source_group(source_id: String) -> String:
	return _get_source_group(source_id)

func _ensure_index() -> void:
	if _cache_ready:
		return
	_build_index()

func _build_index() -> void:
	_icons.clear()
	_icons_by_id.clear()
	_index_builtin_sources()
	_index_mod_icons()
	_index_custom_sources()
	_icons.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var order_a := a.get("source_order", 99)
		var order_b := b.get("source_order", 99)
		if order_a == order_b:
			return a.get("display_name", "") < b.get("display_name", "")
		return order_a < order_b
	)
	_cache_ready = true

func _register_builtin_sources() -> void:
	register_source(GROUP_BASE, "Base Game", Callable(self , "_list_base_icons"))
	register_source(GROUP_CORE, "Core", Callable(self , "_list_core_icons"))

func _index_builtin_sources() -> void:
	for source_id in [GROUP_BASE, GROUP_CORE]:
		var lister := _custom_sources.get(source_id, null)
		if lister == null or not lister.is_valid():
			continue
		var entries: Array = lister.call()
		_add_entries(entries)

func _index_mod_icons() -> void:
	var icons := _list_mod_icons()
	_add_entries(icons)

func _index_custom_sources() -> void:
	for source_id in _custom_sources.keys():
		if source_id == GROUP_BASE or source_id == GROUP_CORE:
			continue
		var lister := _custom_sources.get(source_id)
		if lister == null or not lister.is_valid():
			continue
		var entries: Array = lister.call()
		_add_entries(entries)

func _add_entries(entries: Array) -> void:
	if entries == null:
		return
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var stable_id: String = entry.get("stable_id", "")
		if stable_id == "":
			continue
		if _icons_by_id.has(stable_id):
			continue
		entry["name"] = entry.get("display_name", entry.get("stable_id", ""))
		entry["source_order"] = _get_source_order(entry.get("source_id", ""))
		entry["source_group"] = entry.get("source_group", _get_source_group(entry.get("source_id", "")))
		_icons.append(entry)
		_icons_by_id[stable_id] = entry

func _load_texture(path: String) -> Texture2D:
	if path == "":
		return null
	if _assets != null:
		var tex: Texture2D = _assets.load_texture(path)
		if tex != null:
			return tex
	if ResourceLoader.exists(path):
		return load(path)
	return null

func _list_base_icons() -> Array:
	return _list_icons_from_dir("res://textures/icons", GROUP_BASE, "Base Game", "")

func _list_core_icons() -> Array:
	var core_path := "res://mods-unpacked/TajemnikTV-Core/textures/icons"
	return _list_icons_from_dir(core_path, GROUP_CORE, "Core", "")

func _list_mod_icons() -> Array:
	var results := []
	var base_dir := Util.get_unpacked_mods_dir()
	var dir := DirAccess.open(base_dir)
	if dir == null:
		return results
	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name == "":
			break
		if name.begins_with("."):
			continue
		if name == "mods disabled":
			continue
		var mod_path := base_dir.path_join(name)
		if not DirAccess.dir_exists_absolute(mod_path):
			continue
		var icons_path := mod_path.path_join("textures/icons")
		if not DirAccess.dir_exists_absolute(icons_path):
			continue
		var manifest := _load_manifest(mod_path)
		var label := manifest.get("name", name)
		results += _list_icons_from_dir(icons_path, "mod:%s" % name, label, name)
	return results

func _load_manifest(mod_path: String) -> Dictionary:
	var manifest_path := mod_path.path_join("manifest.json")
	if not FileAccess.file_exists(manifest_path):
		return {}
	var file := FileAccess.open(manifest_path, FileAccess.READ)
	if file == null:
		return {}
	var content := file.get_as_text()
	file.close()
	var json := JSON.new()
	var parse_error := json.parse(content)
	if parse_error != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {}
	return json.data

func _list_icons_from_dir(base_path: String, source_id: String, source_label: String, mod_id: String) -> Array:
	return _collect_icons(base_path, base_path, source_id, source_label, mod_id)

func _collect_icons(current_path: String, root_path: String, source_id: String, source_label: String, mod_id: String) -> Array:
	var results := []
	var dir := DirAccess.open(current_path)
	if dir == null:
		return results
	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name == "":
			break
		if name.begins_with("."):
			continue
		var full_path := current_path.path_join(name)
		if dir.current_is_dir():
			results += _collect_icons(full_path, root_path, source_id, source_label, mod_id)
			continue
		if not _is_icon_file(name):
			continue
		var relative := _make_relative_path(root_path, full_path)
		var entry := {
			"stable_id": _make_stable_id(source_id, relative, mod_id),
			"display_name": _format_display_name(relative),
			"source_id": source_id,
			"source_label": source_label,
			"path": full_path,
			"relative_path": relative,
			"mod_id": mod_id,
			"source_group": _get_source_group(source_id)
		}
		results.append(entry)
	return results

func _make_relative_path(base_path: String, full_path: String) -> String:
	var rel := full_path.substr(base_path.length() + 1)
	rel = rel.replace("\\", "/")
	return rel

func _make_stable_id(source_id: String, relative_path: String, mod_id: String) -> String:
	if source_id.begins_with("mod:") and mod_id != "":
		return "%s:%s" % [source_id, relative_path]
	return "%s:%s" % [source_id, relative_path]

func _format_display_name(relative_path: String) -> String:
	var name := relative_path.get_file().get_basename()
	name = name.replace("_", " ").replace("-", " ")
	return name.capitalize()

func _is_icon_file(file_name: String) -> bool:
	var lower := file_name.to_lower()
	for ext in ICON_EXTENSIONS:
		if lower.ends_with(ext):
			return true
	return false

func _matches_allowed(entry: Dictionary, allowed: Array) -> bool:
	if allowed == null or allowed.size() == 0:
		return true
	var source := entry.get("source_id", "")
	if allowed.has(source):
		return true
	var group := _get_source_group(source)
	if allowed.has(group):
		return true
	return false

func _get_source_group(source_id: String) -> String:
	if source_id.begins_with("mod:"):
		return GROUP_MODS
	if source_id == GROUP_CORE:
		return GROUP_CORE
	return GROUP_BASE if source_id == GROUP_BASE else source_id

func _get_source_order(source_id: String) -> int:
	match _get_source_group(source_id):
		GROUP_BASE:
			return 0
		GROUP_CORE:
			return 1
		GROUP_MODS:
			return 2
		_:
			return 99
