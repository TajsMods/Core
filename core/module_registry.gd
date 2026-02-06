class_name TajsCoreModuleRegistry
extends RefCounted

var _modules: Dictionary = {}
var _core: Variant
var _logger: Variant
var _event_bus: Variant

func _init(core: Variant, logger: Variant = null, event_bus: Variant = null) -> void:
    _core = core
    _logger = logger
    _event_bus = event_bus

func register_module(meta: Dictionary) -> bool:
    if not meta.has("id"):
        _log_warn("registry", "Module registration missing id.")
        return false
    var module_id := str(meta["id"])
    if _modules.has(module_id):
        _log_warn("registry", "Module '%s' already registered." % module_id)
        return false
    var min_version := "0.0.0"
    if meta.has("min_core_version"):
        min_version = str(meta["min_core_version"])
    var enabled: bool = _core != null and _core.require(min_version)
    var entry := meta.duplicate(true)
    entry["enabled"] = enabled
    entry["disabled_reason"] = "" if enabled else "min_core_version_not_met"
    _modules[module_id] = entry
    if _event_bus != null and _event_bus.has_method("emit"):
        _event_bus.emit("module.registered", entry)
    if enabled:
        _log_info("registry", "Registered module '%s'." % module_id)
    else:
        _log_warn("registry", "Module '%s' disabled (core %s required)." % [module_id, min_version])
    return enabled

func get_module(module_id: String) -> Dictionary:
    return _modules.get(module_id, {})

func list_modules() -> Array:
    return _modules.values()

func _log_info(module_id: String, message: String) -> void:
    if _logger != null and _logger.has_method("info"):
        _logger.info(module_id, message)

func _log_warn(module_id: String, message: String) -> void:
    if _logger != null and _logger.has_method("warn"):
        _logger.warn(module_id, message)
