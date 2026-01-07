class_name TajsCoreMigrations
extends RefCounted

var _settings
var _logger
var _version
var _registry: Dictionary = {}

func _init(settings, logger, version_util) -> void:
    _settings = settings
    _logger = logger
    _version = version_util

func register(ns: String, version: String, callable: Callable, description: String = "") -> void:
    if ns == "" or version == "":
        _log_warn("migrations", "Invalid migration registration for namespace '%s'." % ns)
        return
    if not _registry.has(ns):
        _registry[ns] = []
    _registry[ns].append({
        "version": version,
        "callable": callable,
        "description": description
    })

func run_all() -> void:
    for ns in _registry.keys():
        var last_version: String = _settings.get_migration_version(ns)
        var migrations: Array = _registry[ns]
        migrations.sort_custom(func(a, b):
            return _version.compare_versions(a["version"], b["version"]) < 0
        )
        for migration in migrations:
            if _version.compare_versions(last_version, migration["version"]) >= 0:
                continue
            _log_info("migrations", "Running migration %s for %s" % [migration["version"], ns])
            var ok: bool = migration["callable"].is_valid()
            if ok:
                migration["callable"].call()
                _settings.set_migration_version(ns, migration["version"])
            else:
                _log_warn("migrations", "Migration callable invalid for %s:%s" % [ns, migration["version"]])

func _log_info(module_id: String, message: String) -> void:
    if _logger != null and _logger.has_method("info"):
        _logger.info(module_id, message)

func _log_warn(module_id: String, message: String) -> void:
    if _logger != null and _logger.has_method("warn"):
        _logger.warn(module_id, message)
