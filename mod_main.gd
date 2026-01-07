extends Node

const MOD_ID := "TajemnikTV-Core"
const LOG_NAME := "Core:Main"
const META_KEY := "core"

var _core

func _init() -> void:
    if Engine.has_meta(META_KEY):
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
    if ClassDB.class_exists("ModLoaderLog"):
        ModLoaderLog.warning(message, LOG_NAME)
    else:
        print("%s %s" % [LOG_NAME, message])

func _log_error(message: String) -> void:
    if ClassDB.class_exists("ModLoaderLog"):
        ModLoaderLog.error(message, LOG_NAME)
    else:
        print("%s %s" % [LOG_NAME, message])
