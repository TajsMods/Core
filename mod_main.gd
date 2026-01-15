extends Node

const MOD_ID := "TajemnikTV-Core"
const LOG_NAME := "TajemnikTV-Core:Main"
const META_KEY := "TajsCore"

var _core
static var _util_script: GDScript = null

static func _get_util() -> GDScript:
    if _util_script == null:
        # Get base directory from the current script's path
        var script_path := "res://mods-unpacked/TajemnikTV-Core/core/util.gd"
        _util_script = load(script_path)
    return _util_script

static func _has_global_class(class_name_str: String) -> bool:
    var util := _get_util()
    if util != null and util.has_method("has_global_class"):
        return util.has_global_class(class_name_str)
    # Fallback: check ProjectSettings directly
    for entry in ProjectSettings.get_global_class_list():
        if entry.get("class", "") == class_name_str:
            return true
    return false

func _init() -> void:
    if Engine.has_meta(META_KEY):
        var existing = Engine.get_meta(META_KEY)
        if existing != null:
            _log_warn("Core already initialized, skipping.")
            return
    var base_dir: String = get_script().resource_path.get_base_dir()
    var runtime_script = load(base_dir.path_join("core/runtime.gd"))
    if runtime_script == null:
        _log_error("Failed to load core runtime.")
        return
    _core = runtime_script.new()
    add_child(_core)

func _log_warn(message: String) -> void:
    if _has_global_class("ModLoaderLog"):
        ModLoaderLog.warning(message, LOG_NAME)
    else:
        print("%s %s" % [LOG_NAME, message])

func _log_error(message: String) -> void:
    if _has_global_class("ModLoaderLog"):
        ModLoaderLog.error(message, LOG_NAME)
    else:
        print("%s %s" % [LOG_NAME, message])
