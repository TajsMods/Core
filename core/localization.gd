# ==============================================================================
# Taj's Core - Localization
# Author: TajemnikTV
# Description: Translation helpers for mods.
# ==============================================================================
class_name TajsCoreLocalization
extends RefCounted

func register_translation(resource_path: String) -> bool:
    if resource_path == "":
        return false
    if _has_global_class("ModLoaderMod"):
        ModLoaderMod.add_translation(resource_path)
        return true
    if not ResourceLoader.exists(resource_path):
        return false
    var translation: Translation = load(resource_path)
    if translation == null:
        return false
    TranslationServer.add_translation(translation)
    return true

func register_mod_translations(mod_id: String, relative_dir: String = "translations") -> int:
    var count := 0
    var base := _get_mod_path(mod_id)
    if base == "":
        return 0
    var dir_path := base.path_join(relative_dir)
    return register_translations_dir(dir_path)

func register_translations_dir(dir_path: String) -> int:
    if dir_path == "":
        return 0
    var dir := DirAccess.open(dir_path)
    if dir == null:
        return 0
    var count := 0
    for file_name in dir.get_files():
        if file_name.ends_with(".translation") or file_name.ends_with(".tres"):
            if register_translation(dir_path.path_join(file_name)):
                count += 1
    return count


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
