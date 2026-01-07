extends Node
## Taj's Core Logger - Centralized Logging System
##
## Provides consistent logging across all modules with different log levels
## and optional file output.

enum LogLevel {
	DEBUG = 0,
	INFO = 1,
	WARN = 2,
	ERROR = 3,
	NONE = 4
}

var current_log_level: LogLevel = LogLevel.INFO
var log_to_file: bool = false
var log_file_path: String = "user://tajs_core.log"

var _log_file: FileAccess = null

func _ready() -> void:
	if log_to_file:
		_open_log_file()

func _exit_tree() -> void:
	if _log_file:
		_log_file.close()

func _open_log_file() -> void:
	# Open in READ_WRITE mode and seek to end to append
	_log_file = FileAccess.open(log_file_path, FileAccess.READ_WRITE)
	if _log_file:
		_log_file.seek_end()
		info("Log file opened at: %s" % log_file_path)
	else:
		# If file doesn't exist, create it in WRITE mode
		_log_file = FileAccess.open(log_file_path, FileAccess.WRITE)
		if _log_file:
			info("Log file created at: %s" % log_file_path)

## Log a debug message
func debug(message: String) -> void:
	_log(LogLevel.DEBUG, message)

## Log an info message
func info(message: String) -> void:
	_log(LogLevel.INFO, message)

## Log a warning message
func warn(message: String) -> void:
	_log(LogLevel.WARN, message)

## Log an error message
func error(message: String) -> void:
	_log(LogLevel.ERROR, message)

func _log(level: LogLevel, message: String) -> void:
	if level < current_log_level:
		return
	
	var level_str := _get_level_string(level)
	var timestamp := Time.get_datetime_string_from_system()
	var formatted_message := "[%s] [%s] %s" % [timestamp, level_str, message]
	
	# Print to console
	match level:
		LogLevel.ERROR:
			push_error(formatted_message)
		LogLevel.WARN:
			push_warning(formatted_message)
		_:
			print(formatted_message)
	
	# Write to file if enabled
	if log_to_file and _log_file:
		_log_file.store_line(formatted_message)
		_log_file.flush()

func _get_level_string(level: LogLevel) -> String:
	match level:
		LogLevel.DEBUG: return "DEBUG"
		LogLevel.INFO: return "INFO"
		LogLevel.WARN: return "WARN"
		LogLevel.ERROR: return "ERROR"
		_: return "UNKNOWN"

## Set the minimum log level
func set_log_level(level: LogLevel) -> void:
	current_log_level = level
	info("Log level set to: %s" % _get_level_string(level))
