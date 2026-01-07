# ==============================================================================
# Taj's Core - Logger
# Author: TajemnikTV
# Description: Logger
# ==============================================================================
class_name TajsCoreLogger
extends RefCounted

const DEFAULT_RING_SIZE := 200
const DEFAULT_FILE_PATH := "user://tajs_core.log"

var _ring: Array = []
var _ring_size: int = DEFAULT_RING_SIZE
var _debug_enabled: bool = false
var _file_logging_enabled: bool = false
var _file_path: String = DEFAULT_FILE_PATH

func set_debug_enabled(enabled: bool) -> void:
    _debug_enabled = enabled

func set_ring_size(size: int) -> void:
    _ring_size = max(10, size)

func set_file_logging(enabled: bool, path: String = "") -> void:
    _file_logging_enabled = enabled
    if path != "":
        _file_path = path

func debug(module_id: String, message: String) -> void:
    if _debug_enabled:
        _log("debug", module_id, message)

func info(module_id: String, message: String) -> void:
    _log("info", module_id, message)

func warn(module_id: String, message: String) -> void:
    _log("warn", module_id, message)

func error(module_id: String, message: String) -> void:
    _log("error", module_id, message)

func get_entries() -> Array:
    return _ring.duplicate(true)

func _log(level: String, module_id: String, message: String) -> void:
    var tag := "TajsCore"
    if module_id != "":
        tag = "%s:%s" % [tag, module_id]
    var entry := {
        "time": Time.get_datetime_string_from_system(),
        "level": level,
        "module": module_id,
        "message": message
    }
    _ring.append(entry)
    if _ring.size() > _ring_size:
        _ring.pop_front()
    _log_to_console(level, tag, message)
    if _file_logging_enabled:
        _log_to_file(level, tag, message)

func _log_to_console(level: String, tag: String, message: String) -> void:
    if ClassDB.class_exists("ModLoaderLog"):
        match level:
            "debug":
                ModLoaderLog.debug(message, tag)
            "info":
                ModLoaderLog.info(message, tag)
            "warn":
                ModLoaderLog.warning(message, tag)
            "error":
                ModLoaderLog.error(message, tag)
            _:
                ModLoaderLog.info(message, tag)
        return
    var prefix := "%s [%s]" % [tag, level]
    print("%s %s" % [prefix, message])

func _log_to_file(level: String, tag: String, message: String) -> void:
    var file := FileAccess.open(_file_path, FileAccess.READ_WRITE)
    if file == null:
        file = FileAccess.open(_file_path, FileAccess.WRITE)
    if file == null:
        return
    file.seek_end()
    var line := "%s [%s] %s\n" % [tag, level, message]
    file.store_string(line)
    file.close()
