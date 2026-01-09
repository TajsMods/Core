# ==============================================================================
# Taj's Core - Hook Manager
# Author: TajemnikTV
# Description: Installs Core hook nodes.
# ==============================================================================
class_name TajsCoreHookManager
extends Node

var _core
var _event_bus
var _logger

var window_hooks
var connection_hooks
var selection_hooks
var save_load_hooks
var ui_hooks

func setup(core) -> void:
	_core = core
	_event_bus = core.event_bus if core != null else null
	_logger = core.logger if core != null else null

func _ready() -> void:
	_install_hooks()

func _install_hooks() -> void:
	var base_dir := get_script().resource_path.get_base_dir()
	window_hooks = _load_hook(base_dir.path_join("window_hooks.gd"), "window_hooks")
	connection_hooks = _load_hook(base_dir.path_join("connection_hooks.gd"), "connection_hooks")
	selection_hooks = _load_hook(base_dir.path_join("selection_hooks.gd"), "selection_hooks")
	save_load_hooks = _load_hook(base_dir.path_join("save_load_hooks.gd"), "save_load_hooks")
	ui_hooks = _load_hook(base_dir.path_join("ui_hooks.gd"), "ui_hooks")

	if window_hooks:
		window_hooks.setup(_event_bus, _logger)
		add_child(window_hooks)
	if connection_hooks:
		connection_hooks.setup(_event_bus)
		add_child(connection_hooks)
	if selection_hooks:
		selection_hooks.setup(_event_bus)
		add_child(selection_hooks)
	if save_load_hooks:
		save_load_hooks.setup(_event_bus)
		add_child(save_load_hooks)
	if ui_hooks:
		ui_hooks.setup(_event_bus)
		add_child(ui_hooks)

func _load_hook(path: String, name: String):
	var script = load(path)
	if script == null:
		_log_warn("Failed to load hook: %s" % path)
		return null
	var instance = script.new()
	if instance != null:
		instance.name = name
	return instance

func _log_warn(message: String) -> void:
	if _logger != null and _logger.has_method("warn"):
		_logger.warn("hooks", message)
