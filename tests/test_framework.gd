extends Node
## Simple test script to verify the Core framework works
##
## This can be run in a minimal Godot project to test the framework

func _ready():
	print("\n=== Starting Core Framework Tests ===\n")
	
	# Test 1: Framework initialization
	print("Test 1: Framework Version")
	print("  Core version: ", Core.get_version())
	assert(Core.get_version() == "1.0.0", "Version should be 1.0.0")
	print("  ✓ PASS\n")
	
	# Test 2: Logger
	print("Test 2: Logger System")
	Core.Logger.debug("Debug message (should not appear at INFO level)")
	Core.Logger.info("Info message")
	Core.Logger.warn("Warning message")
	Core.Logger.error("Error message")
	print("  ✓ PASS\n")
	
	# Test 3: Settings
	print("Test 3: Settings System")
	Core.Settings.set_value("test", "key1", "value1")
	var val = Core.Settings.get_value("test", "key1", "default")
	assert(val == "value1", "Setting should be 'value1'")
	print("  Retrieved setting: ", val)
	print("  ✓ PASS\n")
	
	# Test 4: Module Registration
	print("Test 4: Module Registration")
	var test_module = Node.new()
	test_module.name = "TestModule"
	var success = Core.register_module("TestModule", test_module, "0.1.0")
	assert(success == true, "Module registration should succeed")
	assert(Core.Runtime.has_module("TestModule"), "Module should be registered")
	assert(Core.Runtime.get_module_version("TestModule") == "0.1.0", "Version should match")
	print("  Registered module: TestModule v0.1.0")
	print("  ✓ PASS\n")
	
	# Test 5: Keybinds
	print("Test 5: Keybind Registration")
	var key_event = InputEventKey.new()
	key_event.keycode = KEY_F12
	var kb_success = Core.Keybinds.register_action("test_action", [key_event], "Test action")
	assert(kb_success == true, "Keybind registration should succeed")
	assert(Core.Keybinds.has_action("test_action"), "Action should be registered")
	print("  Registered keybind: test_action (F12)")
	print("  ✓ PASS\n")
	
	# Test 6: Event Bus
	print("Test 6: Event Bus")
	var event_received = false
	Core.EventBus.register_custom_signal("test_signal", ["param"])
	Core.EventBus.connect_custom("test_signal", func(param):
		event_received = true
		print("  Custom event received with param: ", param)
	)
	Core.EventBus.emit_custom("test_signal", ["test_value"])
	await get_tree().process_frame
	assert(event_received == true, "Custom signal should be received")
	print("  ✓ PASS\n")
	
	# Test 7: Patches
	print("Test 7: Patch System")
	var patch_executed = false
	Core.Patches.register_patch("test_patch", func():
		patch_executed = true
		return true
	, "Test patch")
	var patch_applied = Core.Patches.apply_patch("test_patch")
	assert(patch_applied == true, "Patch should be applied")
	assert(patch_executed == true, "Patch function should execute")
	assert(Core.Patches.is_patch_applied("test_patch"), "Patch should be marked as applied")
	
	# Try applying again - should not execute
	patch_executed = false
	var patch_applied_again = Core.Patches.apply_patch("test_patch")
	assert(patch_applied_again == false, "Patch should not apply twice")
	assert(patch_executed == false, "Patch function should not execute again")
	print("  Patch applied once successfully")
	print("  ✓ PASS\n")
	
	print("=== All Tests Passed! ===\n")
	
	# Save settings
	Core.Settings.save_settings()
	
	# Quit after a moment
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()
