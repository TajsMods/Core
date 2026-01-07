extends Node
## Taj's Core EventBus - Global Event System
##
## Provides a centralized event bus for communication between modules
## without tight coupling.

## Emitted when a module is registered
signal module_registered(module_name: String, version: String)

## Emitted when a module is unregistered
signal module_unregistered(module_name: String)

## Emitted when settings are changed
signal setting_changed(namespace: String, key: String, value)

## Emitted when a keybind is registered
signal keybind_registered(action_name: String)

## Emitted when a keybind conflict is detected
signal keybind_conflict(action_name: String, existing_key: String, new_key: String)

## Emitted when a patch is applied
signal patch_applied(patch_id: String)

var _custom_signals := {}

## Register a custom signal
## @param signal_name: Name of the signal
## @param param_names: Array of parameter names (for documentation)
func register_custom_signal(signal_name: String, param_names: Array = []) -> void:
	if _custom_signals.has(signal_name):
		if Core and Core.Logger:
			Core.Logger.warn("Signal '%s' is already registered" % signal_name)
		return
	
	_custom_signals[signal_name] = {
		"params": param_names,
		"connections": []
	}
	
	if Core and Core.Logger:
		Core.Logger.debug("Registered custom signal: %s(%s)" % [signal_name, ", ".join(param_names)])

## Emit a custom signal
## @param signal_name: Name of the signal to emit
## @param args: Arguments to pass to connected callbacks
func emit_custom(signal_name: String, args: Array = []) -> void:
	if not _custom_signals.has(signal_name):
		if Core and Core.Logger:
			Core.Logger.warn("Attempting to emit unregistered signal: %s" % signal_name)
		return
	
	for connection in _custom_signals[signal_name].connections:
		connection.callv(args)

## Connect to a custom signal
## @param signal_name: Name of the signal
## @param callable: The callable to connect
func connect_custom(signal_name: String, callable: Callable) -> void:
	if not _custom_signals.has(signal_name):
		if Core and Core.Logger:
			Core.Logger.warn("Attempting to connect to unregistered signal: %s" % signal_name)
		return
	
	_custom_signals[signal_name].connections.append(callable)

## Disconnect from a custom signal
## @param signal_name: Name of the signal
## @param callable: The callable to disconnect
func disconnect_custom(signal_name: String, callable: Callable) -> void:
	if not _custom_signals.has(signal_name):
		return
	
	_custom_signals[signal_name].connections.erase(callable)

## Get all registered custom signals
func get_custom_signals() -> Array:
	return _custom_signals.keys()
