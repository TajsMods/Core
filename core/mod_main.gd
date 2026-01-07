extends Node
## Taj's Core - Main Bootstrap
##
## This is the main entrypoint for the Taj's Core framework.
## Add this as an AutoLoad singleton named "Core" in your Godot project.

const VERSION = "1.0.0"

# Core subsystems
var Logger: Node
var Settings: Node
var EventBus: Node
var Runtime: Node
var Keybinds: Node
var Patches: Node

func _ready() -> void:
	_initialize_subsystems()
	_print_banner()
	
	# Apply any registered patches
	Patches.apply_all_patches()

## Initialize all core subsystems
func _initialize_subsystems() -> void:
	# Order matters - Logger must be first
	Logger = preload("res://core/logger.gd").new()
	Logger.name = "Logger"
	add_child(Logger)
	
	# EventBus second for event signaling
	EventBus = preload("res://core/event_bus.gd").new()
	EventBus.name = "EventBus"
	add_child(EventBus)
	
	# Settings for configuration
	Settings = preload("res://core/settings.gd").new()
	Settings.name = "Settings"
	add_child(Settings)
	
	# Runtime for module management
	Runtime = preload("res://core/runtime.gd").new()
	Runtime.name = "Runtime"
	add_child(Runtime)
	
	# Keybinds for input management
	Keybinds = preload("res://core/keybinds.gd").new()
	Keybinds.name = "Keybinds"
	add_child(Keybinds)
	
	# Patches for code patching
	Patches = preload("res://core/patches.gd").new()
	Patches.name = "Patches"
	add_child(Patches)

## Print startup banner
func _print_banner() -> void:
	print("=" * 60)
	print("  Taj's Core Framework v%s" % VERSION)
	print("  Modding framework for Godot")
	print("=" * 60)
	Logger.info("Core framework initialized successfully")

## Get the framework version
func get_version() -> String:
	return VERSION

## Register a module (convenience wrapper for Runtime.register_module)
func register_module(module_name: String, module_instance: Node, module_version: String = "1.0.0") -> bool:
	return Runtime.register_module(module_name, module_instance, module_version)
