# ==============================================================================
# Taj's Core - Command Registry
# Author: TajemnikTV
# Description: Command storage and execution helpers
# ==============================================================================
class_name TajsCoreCommandRegistry
extends RefCounted

signal command_registered(command_id: String, command: Dictionary)
signal command_unregistered(command_id: String)
signal command_executed(command_id: String, context: Variant, success: bool)
signal commands_changed

const LOG_NAME := "TajemnikTV-Core:CommandRegistry"

var _commands: Dictionary = {}
var _categories: Dictionary = {}
var _root_items: Array[String] = []
var _register_counter: int = 0
var _logger
var _event_bus


func _init(logger = null, event_bus = null) -> void:
	_logger = logger
	_event_bus = event_bus
	_categories[""] = []


func register(data: Dictionary) -> bool:
	var id := str(data.get("id", "")).strip_edges()
	if id == "":
		_log_error("Command must have an id.")
		return false
	var title := str(data.get("title", "")).strip_edges()
	if title == "":
		_log_error("Command '%s' must have a title." % id)
		return false

	var command := _build_command(data, id, title)
	if _commands.has(id):
		_log_warn("Command '%s' already registered. Replacing existing entry." % id)
		_remove_from_categories(id, _commands[id])

	_commands[id] = command
	_add_to_categories(command)
	command_registered.emit(id, command)
	commands_changed.emit()
	_emit_event("command.registered", {"id": id, "title": title})
	return true


func register_command(command_id: String, meta: Dictionary = {}, callback: Callable = Callable()) -> bool:
	var data := meta.duplicate(true)
	data["id"] = command_id
	if not data.has("title"):
		var fallback_title := str(meta.get("name", "")).strip_edges()
		data["title"] = fallback_title if fallback_title != "" else command_id
	if callback.is_valid():
		data["run"] = callback
	return register(data)


func register_many(commands: Array) -> void:
	for cmd in commands:
		if cmd is Dictionary:
			register(cmd)


func unregister(command_id: String) -> bool:
	if not _commands.has(command_id):
		return false
	var previous: Dictionary = _commands[command_id]
	_commands.erase(command_id)
	_remove_from_categories(command_id, previous)
	command_unregistered.emit(command_id)
	commands_changed.emit()
	_emit_event("command.unregistered", {"id": command_id})
	return true


func clear() -> void:
	_commands.clear()
	_categories.clear()
	_root_items.clear()
	_categories[""] = []
	commands_changed.emit()


func get_command(command_id: String) -> Dictionary:
	if not _commands.has(command_id):
		return {}
	return _commands[command_id].duplicate(true)


func list_commands() -> Array[Dictionary]:
	return get_all_commands()


func list() -> Array[Dictionary]:
	return get_all_commands()


func get_all() -> Array[Dictionary]:
	return get_all_commands()


func get_all_commands() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for cmd in _commands.values():
		result.append(cmd.duplicate(true))
	return result


func get_all_executable_commands() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for cmd in _commands.values():
		if not bool(cmd.get("is_category", false)):
			result.append(cmd.duplicate(true))
	return result


func get_root_items() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for cmd_id in _root_items:
		if _commands.has(cmd_id):
			result.append(_commands[cmd_id].duplicate(true))
	return result


func get_commands_in_category(category_path: Array) -> Array[Dictionary]:
	var path_key := "/".join(category_path)
	var result: Array[Dictionary] = []
	if _categories.has(path_key):
		for cmd_id in _categories[path_key]:
			if _commands.has(cmd_id):
				result.append(_commands[cmd_id].duplicate(true))
	return result


func get_count() -> int:
	return _commands.size()


func is_visible(command: Variant, context = null) -> bool:
	var cmd := _resolve_command(command)
	if cmd.is_empty():
		return false
	if bool(cmd.get("hidden", false)):
		return false
	var is_visible_func: Callable = cmd.get("is_visible", Callable())
	if is_visible_func.is_valid():
		return bool(is_visible_func.call(context))
	return true


func is_enabled(command: Variant, context = null) -> bool:
	var cmd := _resolve_command(command)
	if cmd.is_empty():
		return false
	var enabled_func: Callable = cmd.get("is_enabled", Callable())
	if not enabled_func.is_valid():
		enabled_func = cmd.get("can_run", Callable())
	if enabled_func.is_valid():
		return bool(enabled_func.call(context))
	return true


func execute(command_id: String, context = null) -> bool:
	if not _commands.has(command_id):
		_log_error("Command not found: %s" % command_id)
		_emit_event("command.failed", {"id": command_id, "reason": "not_found"})
		command_executed.emit(command_id, context, false)
		return false
	var cmd: Dictionary = _commands[command_id]
	if bool(cmd.get("is_category", false)):
		_log_warn("Command '%s' is a category and cannot execute." % command_id)
		command_executed.emit(command_id, context, false)
		return false
	if not is_visible(cmd, context):
		_log_warn("Command '%s' is not visible in this context." % command_id)
		command_executed.emit(command_id, context, false)
		return false
	if not is_enabled(cmd, context):
		_log_warn("Command '%s' is disabled in this context." % command_id)
		command_executed.emit(command_id, context, false)
		return false
	var run_func: Callable = cmd.get("run", Callable())
	if not run_func.is_valid():
		_log_warn("Command '%s' has no run handler." % command_id)
		command_executed.emit(command_id, context, false)
		return false
	var success := true
	var result = run_func.call(context)
	if typeof(result) == TYPE_INT and int(result) != OK:
		success = false
		_log_warn("Command '%s' returned error: %s" % [command_id, str(result)])
	command_executed.emit(command_id, context, success)
	_emit_event("command.executed", {"id": command_id, "success": success})
	return success


func run(command_id: String, context = null) -> bool:
	return execute(command_id, context)


func _build_command(data: Dictionary, id: String, title: String) -> Dictionary:
	var command: Dictionary = data.duplicate(true)
	command["id"] = id
	command["title"] = title
	command["priority"] = int(command.get("priority", 0))
	command["keywords"] = _normalize_string_array(command.get("keywords", []))
	command["tags"] = _normalize_string_array(command.get("tags", []))
	command["hidden"] = bool(command.get("hidden", false))
	command["is_category"] = bool(command.get("is_category", false))
	command["category_path"] = _normalize_string_array(command.get("category_path", []))
	if str(command.get("category", "")).strip_edges() == "" and command["category_path"].size() > 0:
		command["category"] = str(command["category_path"][0])
	if not command.has("run"):
		command["run"] = Callable()
	if not command.has("is_visible"):
		command["is_visible"] = Callable()
	if not command.has("is_enabled"):
		command["is_enabled"] = Callable()
	if not command.has("can_run") and command["is_enabled"].is_valid():
		command["can_run"] = command["is_enabled"]
	if not command.has("_has_metadata"):
		command["_has_metadata"] = _has_help_metadata(command)
	command["registered_at"] = _register_counter
	_register_counter += 1
	return command


func _add_to_categories(command: Dictionary) -> void:
	var path_key := "/".join(command.get("category_path", []))
	if not _categories.has(path_key):
		_categories[path_key] = []
	if command["id"] not in _categories[path_key]:
		_categories[path_key].append(command["id"])
	if command.get("category_path", []).is_empty():
		if command["id"] not in _root_items:
			_root_items.append(command["id"])


func _remove_from_categories(command_id: String, command: Dictionary) -> void:
	var path_key := "/".join(command.get("category_path", []))
	if _categories.has(path_key):
		_categories[path_key].erase(command_id)
	_root_items.erase(command_id)


func _normalize_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for entry in value:
			var text := str(entry).strip_edges()
			if text != "":
				result.append(text)
	return result


func _has_help_metadata(command: Dictionary) -> bool:
	return command.has("display_name") or command.has("aliases") or command.has("description") \
		or command.has("usage") or command.has("examples") or command.has("category") \
		or command.has("tags") or command.has("hidden")


func _resolve_command(command: Variant) -> Dictionary:
	if command is Dictionary:
		return command
	if command is String and _commands.has(command):
		return _commands[command]
	return {}


func _emit_event(event_name: String, data: Dictionary) -> void:
	if _event_bus != null and _event_bus.has_method("emit_event"):
		_event_bus.emit_event(event_name, "core", data, false)


func _log_warn(message: String) -> void:
	if _logger != null and _logger.has_method("warn"):
		_logger.warn("commands", message)
	elif _has_global_class("ModLoaderLog"):
		ModLoaderLog.warning(message, LOG_NAME)
	else:
		print("%s %s" % [LOG_NAME, message])


func _log_error(message: String) -> void:
	if _logger != null and _logger.has_method("error"):
		_logger.error("commands", message)
	elif _has_global_class("ModLoaderLog"):
		ModLoaderLog.error(message, LOG_NAME)
	else:
		print("%s %s" % [LOG_NAME, message])


func _has_global_class(class_name_str: String) -> bool:
	for entry in ProjectSettings.get_global_class_list():
		if entry.get("class", "") == class_name_str:
			return true
	return false
