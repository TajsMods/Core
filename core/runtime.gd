extends Node
## Taj's Core Runtime - Module Registration and Management
##
## Provides centralized module registration, version tracking, and lifecycle management
## for the Taj's Core modding framework.

const VERSION = "1.0.0"

var _modules := {}
var _module_load_order := []

## Register a module with the core framework
## @param module_name: Unique identifier for the module
## @param module_instance: The module instance (should have _ready, _process etc if needed)
## @param module_version: Semantic version string (e.g., "1.0.0")
func register_module(module_name: String, module_instance: Node, module_version: String = "1.0.0") -> bool:
	if _modules.has(module_name):
		if Core and Core.Logger:
			Core.Logger.warn("Module '%s' is already registered" % module_name)
		else:
			push_warning("Module '%s' is already registered" % module_name)
		return false
	
	_modules[module_name] = {
		"instance": module_instance,
		"version": module_version,
		"enabled": true
	}
	_module_load_order.append(module_name)
	
	if Core and Core.Logger:
		Core.Logger.info("Registered module: %s (v%s)" % [module_name, module_version])
	else:
		print("Registered module: %s (v%s)" % [module_name, module_version])
	
	if Core and Core.EventBus:
		Core.EventBus.module_registered.emit(module_name, module_version)
	
	return true

## Get a registered module instance
func get_module(module_name: String) -> Node:
	if _modules.has(module_name):
		return _modules[module_name].instance
	return null

## Check if a module is registered
func has_module(module_name: String) -> bool:
	return _modules.has(module_name)

## Get module version
func get_module_version(module_name: String) -> String:
	if _modules.has(module_name):
		return _modules[module_name].version
	return ""

## Get all registered modules
func get_all_modules() -> Array:
	return _module_load_order.duplicate()

## Enable/disable a module
func set_module_enabled(module_name: String, enabled: bool) -> void:
	if _modules.has(module_name):
		_modules[module_name].enabled = enabled
		if Core and Core.Logger:
			Core.Logger.info("Module '%s' %s" % [module_name, "enabled" if enabled else "disabled"])

## Check if module is enabled
func is_module_enabled(module_name: String) -> bool:
	if _modules.has(module_name):
		return _modules[module_name].enabled
	return false
