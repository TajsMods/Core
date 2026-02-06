class_name TajsCoreCommandRegistry
extends RefCounted

signal command_registered(command_id: String, command: Dictionary)
signal command_unregistered(command_id: String)
signal command_executed(command_id: String, context: Variant, success: bool)
signal commands_changed

const LOG_NAME: String = "TajemnikTV-Core:CommandRegistry"

var _commands: Dictionary = {}
var _categories: Dictionary = {}
var _root_items: Array[String] = []
var _register_counter: int = 0
var _logger: Variant
var _event_bus: Variant


func _init(logger: Variant = null, event_bus: Variant = null) -> void:
    _logger = logger
    _event_bus = event_bus
    _categories[""] = []


func register(data: Dictionary) -> bool:
    var id: String = str(data.get("id", "")).strip_edges()
    if id == "":
        _log_error("Command must have an id.")
        return false
    var title: String = str(data.get("title", "")).strip_edges()
    if title == "":
        _log_error("Command '%s' must have a title." % id)
        return false

    var command: Dictionary = _build_command(data, id, title)
    if _commands.has(id):
        _log_warn("Command '%s' already registered. Replacing existing entry." % id)
        var prev_cmd: Dictionary = _commands[id]
        _remove_from_categories(id, prev_cmd)

    _commands[id] = command
    _add_to_categories(command)
    command_registered.emit(id, command)
    commands_changed.emit()
    _emit_event("command.registered", {"id": id, "title": title})
    return true


func register_command(command_id: String, meta: Dictionary = {}, callback: Callable = Callable()) -> bool:
    var data: Dictionary = meta.duplicate(true)
    data["id"] = command_id
    if not data.has("title"):
        var fallback_title: String = str(meta.get("name", "")).strip_edges()
        data["title"] = fallback_title if fallback_title != "" else command_id
    if callback.is_valid():
        data["run"] = callback
    return register(data)


func register_many(commands: Array) -> void:
    for cmd: Variant in commands:
        if cmd is Dictionary:
            var cmd_dict: Dictionary = cmd
            var _ignored: bool = register(cmd_dict)


func unregister(command_id: String) -> bool:
    if not _commands.has(command_id):
        return false
    var previous: Dictionary = _commands[command_id]
    var _ignored: Variant = _commands.erase(command_id)
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
    var cmd: Dictionary = _commands[command_id]
    return cmd.duplicate(true)


func list_commands() -> Array[Dictionary]:
    return get_all_commands()


func list() -> Array[Dictionary]:
    return get_all_commands()


func get_all() -> Array[Dictionary]:
    return get_all_commands()


func get_all_commands() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for cmd: Variant in _commands.values():
        if cmd is Dictionary:
            var cmd_dict: Dictionary = cmd
            result.append(cmd_dict.duplicate(true))
    return result


func get_all_executable_commands() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for cmd: Variant in _commands.values():
        if cmd is Dictionary:
            var cmd_dict: Dictionary = cmd
            if not cmd_dict.get("is_category", false):
                result.append(cmd_dict.duplicate(true))
    return result


func get_root_items() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for cmd_id: Variant in _root_items:
        if _commands.has(cmd_id):
            var cmd: Dictionary = _commands[cmd_id]
            result.append(cmd.duplicate(true))
    return result


func get_commands_in_category(category_path: Array) -> Array[Dictionary]:
    var path_key: String = "/".join(category_path)
    var result: Array[Dictionary] = []
    if _categories.has(path_key):
        for cmd_id: Variant in _categories[path_key]:
            if _commands.has(cmd_id):
                var cmd: Dictionary = _commands[cmd_id]
                result.append(cmd.duplicate(true))
    return result


func get_count() -> int:
    return _commands.size()


func is_visible(command: Variant, context: Variant = null) -> bool:
    var cmd: Dictionary = _resolve_command(command)
    if cmd.is_empty():
        return false
    if cmd.get("hidden", false):
        return false
    var is_visible_func: Callable = cmd.get("is_visible", Callable())
    if is_visible_func.is_valid():
        return _call_bool_with_optional_context(is_visible_func, context, false, "is_visible")
    return true


func is_enabled(command: Variant, context: Variant = null) -> bool:
    var cmd: Dictionary = _resolve_command(command)
    if cmd.is_empty():
        return false
    var enabled_func: Callable = cmd.get("is_enabled", Callable())
    if not enabled_func.is_valid():
        enabled_func = cmd.get("can_run", Callable())
    if enabled_func.is_valid():
        return _call_bool_with_optional_context(enabled_func, context, false, "is_enabled/can_run")
    return true


func execute(command_id: String, context: Variant = null) -> bool:
    if not _commands.has(command_id):
        _log_error("Command not found: %s" % command_id)
        _emit_event("command.failed", {"id": command_id, "reason": "not_found"})
        command_executed.emit(command_id, context, false)
        return false
    var cmd: Dictionary = _commands[command_id]
    if cmd.get("is_category", false):
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
    var success: bool = true
    var result: Variant = _call_with_optional_context(run_func, context, "run", command_id)
    if typeof(result) == TYPE_INT:
        var result_code: int = result
        if result_code != OK:
            success = false
            _log_warn("Command '%s' returned error: %s" % [command_id, str(result)])
    command_executed.emit(command_id, context, success)
    _emit_event("command.executed", {"id": command_id, "success": success})
    return success


func run(command_id: String, context: Variant = null) -> bool:
    return execute(command_id, context)


func _build_command(data: Dictionary, id: String, title: String) -> Dictionary:
    var command: Dictionary = data.duplicate(true)
    command["id"] = id
    command["title"] = title
    var priority_val: Variant = command.get("priority", 0)
    command["priority"] = priority_val if typeof(priority_val) == TYPE_INT else 0
    command["keywords"] = _normalize_string_array(command.get("keywords", []))
    command["tags"] = _normalize_string_array(command.get("tags", []))
    command["hidden"] = true if command.get("hidden", false) else false
    command["is_category"] = true if command.get("is_category", false) else false
    command["category_path"] = _normalize_string_array(command.get("category_path", []))
    var cat_path: Array[String] = command["category_path"]
    if str(command.get("category", "")).strip_edges() == "" and cat_path.size() > 0:
        command["category"] = str(cat_path[0])
    if not command.has("run"):
        command["run"] = Callable()
    if not command.has("is_visible"):
        command["is_visible"] = Callable()
    if not command.has("is_enabled"):
        command["is_enabled"] = Callable()
    var is_enabled_callable: Variant = command["is_enabled"]
    if not command.has("can_run"):
        if is_enabled_callable is Callable:
            var callable_val: Callable = is_enabled_callable
            if callable_val.is_valid():
                command["can_run"] = command["is_enabled"]
    if not command.has("_has_metadata"):
        command["_has_metadata"] = _has_help_metadata(command)
    command["registered_at"] = _register_counter
    _register_counter += 1
    return command


func _add_to_categories(command: Dictionary) -> void:
    var cat_path: Array[String] = command.get("category_path", [])
    var path_key: String = "/".join(cat_path)
    if not _categories.has(path_key):
        _categories[path_key] = []
    var category_list: Array = _categories[path_key]
    if command["id"] not in category_list:
        category_list.append(command["id"])
    if cat_path.is_empty():
        if command["id"] not in _root_items:
            _root_items.append(command["id"])


func _remove_from_categories(command_id: String, command: Dictionary) -> void:
    var cat_path: Array[String] = command.get("category_path", [])
    var path_key: String = "/".join(cat_path)
    if _categories.has(path_key):
        var category_list: Array = _categories[path_key]
        category_list.erase(command_id)
    _root_items.erase(command_id)


func _normalize_string_array(value: Variant) -> Array[String]:
    var result: Array[String] = []
    if value is Array:
        for entry: Variant in value:
            var text: String = str(entry).strip_edges()
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


func _call_with_optional_context(callable_func: Callable, context: Variant, role: String, command_id: String = "") -> Variant:
    var required_args: int = _get_required_argument_count(callable_func)
    if required_args == 0:
        return callable_func.call()
    if required_args == 1:
        return callable_func.call(context)

    var target_label: String = ""
    if command_id != "":
        target_label = " for command '%s'" % command_id
    _log_warn("Callable %s%s expects %d args; only 0 or 1 are supported." % [role, target_label, required_args])
    return ERR_INVALID_PARAMETER


func _call_bool_with_optional_context(callable_func: Callable, context: Variant, default_value: bool, role: String) -> bool:
    var result: Variant = _call_with_optional_context(callable_func, context, role)
    if typeof(result) == TYPE_INT:
        var result_code: int = result
        if result_code == ERR_INVALID_PARAMETER:
            return default_value
    return true if result else false


func _get_required_argument_count(callable_func: Callable) -> int:
    var required_args: int = callable_func.get_argument_count()
    if required_args < 0:
        return 0
    return required_args


@warning_ignore("unsafe_method_access", "unsafe_cast")
func _emit_event(event_name: String, data: Dictionary) -> void:
    if _event_bus != null and (typeof(_event_bus) == TYPE_OBJECT):
        var obj: Object = _event_bus
        if obj.has_method("emit_event"):
            obj.call("emit_event", event_name, "core", data, false)


@warning_ignore("unsafe_method_access", "unsafe_cast")
func _log_warn(message: String) -> void:
    if _logger != null and (typeof(_logger) == TYPE_OBJECT):
        var obj: Object = _logger
        if obj.has_method("warn"):
            obj.call("warn", "commands", message)
    elif _has_global_class("ModLoaderLog"):
        ModLoaderLog.warning(message, LOG_NAME)
    else:
        print("%s %s" % [LOG_NAME, message])


@warning_ignore("unsafe_method_access", "unsafe_cast")
func _log_error(message: String) -> void:
    if _logger != null and (typeof(_logger) == TYPE_OBJECT):
        var obj: Object = _logger
        if obj.has_method("error"):
            obj.call("error", "commands", message)
    elif _has_global_class("ModLoaderLog"):
        ModLoaderLog.error(message, LOG_NAME)
    else:
        print("%s %s" % [LOG_NAME, message])


func _has_global_class(class_name_str: String) -> bool:
    for entry: Variant in ProjectSettings.get_global_class_list():
        if entry is Dictionary:
            var entry_dict: Dictionary = entry
            if entry_dict.get("class", "") == class_name_str:
                return true
    return false
