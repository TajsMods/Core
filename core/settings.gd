extends Node
## Taj's Core Settings - Namespaced Configuration with Migrations
##
## Provides a settings system with namespaced keys and version-based migrations
## to handle configuration changes across versions.

const SETTINGS_VERSION = 1
const SETTINGS_FILE = "user://tajs_core_settings.cfg"

var _config := ConfigFile.new()
var _migrations := {}

func _ready() -> void:
	_register_migrations()
	_load_settings()

## Register a migration function
## @param from_version: The version to migrate from
## @param migration_func: Callable that takes ConfigFile and migrates it
func register_migration(from_version: int, migration_func: Callable) -> void:
	_migrations[from_version] = migration_func
	if Core and Core.Logger:
		Core.Logger.debug("Registered migration from version %d" % from_version)

## Get a setting value with namespace
## @param namespace: The namespace (e.g., "core", "mod_name")
## @param key: The setting key
## @param default_value: Default value if setting doesn't exist
func get_value(namespace: String, key: String, default_value = null):
	return _config.get_value(namespace, key, default_value)

## Set a setting value with namespace
## @param namespace: The namespace (e.g., "core", "mod_name")
## @param key: The setting key
## @param value: The value to set
func set_value(namespace: String, key: String, value) -> void:
	_config.set_value(namespace, key, value)

## Save settings to disk
func save_settings() -> void:
	_config.set_value("_meta", "version", SETTINGS_VERSION)
	var error := _config.save(SETTINGS_FILE)
	if error != OK:
		if Core and Core.Logger:
			Core.Logger.error("Failed to save settings: %d" % error)
		else:
			push_error("Failed to save settings: %d" % error)
	else:
		if Core and Core.Logger:
			Core.Logger.debug("Settings saved successfully")

## Load settings from disk
func _load_settings() -> void:
	var error := _config.load(SETTINGS_FILE)
	
	if error == ERR_FILE_NOT_FOUND:
		if Core and Core.Logger:
			Core.Logger.info("No settings file found, using defaults")
		_config.set_value("_meta", "version", SETTINGS_VERSION)
		save_settings()
		return
	
	if error != OK:
		if Core and Core.Logger:
			Core.Logger.error("Failed to load settings: %d" % error)
		else:
			push_error("Failed to load settings: %d" % error)
		return
	
	# Check version and migrate if necessary
	var current_version := _config.get_value("_meta", "version", 0)
	if current_version < SETTINGS_VERSION:
		if Core and Core.Logger:
			Core.Logger.info("Migrating settings from version %d to %d" % [current_version, SETTINGS_VERSION])
		_migrate_settings(current_version)
		save_settings()
	
	if Core and Core.Logger:
		Core.Logger.info("Settings loaded successfully")

## Apply migrations from old version to current version
func _migrate_settings(from_version: int) -> void:
	var version := from_version
	while version < SETTINGS_VERSION:
		if _migrations.has(version):
			if Core and Core.Logger:
				Core.Logger.debug("Applying migration from version %d" % version)
			_migrations[version].call(_config)
		version += 1

## Register built-in migrations
func _register_migrations() -> void:
	# Example migration from version 0 to 1
	# register_migration(0, func(config: ConfigFile):
	#     # Migrate old settings to new format
	#     pass
	pass

## Check if a namespace exists
func has_namespace(namespace: String) -> bool:
	return _config.has_section(namespace)

## Get all keys in a namespace
func get_namespace_keys(namespace: String) -> PackedStringArray:
	if has_namespace(namespace):
		return _config.get_section_keys(namespace)
	return PackedStringArray()

## Erase a key from a namespace
func erase_key(namespace: String, key: String) -> void:
	_config.erase_section_key(namespace, key)
