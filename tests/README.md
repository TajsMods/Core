# Tests

This directory contains test scripts for the Taj's Core framework.

## Running Tests

### Option 1: Manual Testing in Godot Editor

1. Create a new Godot 4.x project
2. Copy the `core/` directory to `res://core/`
3. Add `res://core/mod_main.gd` as an AutoLoad singleton named "Core"
   - Project → Project Settings → Autoload
   - Path: `res://core/mod_main.gd`
   - Node Name: `Core`
4. Create a new scene with a Node as root
5. Attach `test_framework.gd` to the root node
6. Run the scene

The tests will execute automatically and print results to the console.

### Option 2: Command Line (if Godot CLI is available)

```bash
# Create a minimal project
godot --headless --quit --path /path/to/test/project

# Run tests
godot --headless --path /path/to/test/project res://test_scene.tscn
```

## Test Coverage

The `test_framework.gd` script tests:

1. ✓ Framework initialization and versioning
2. ✓ Logger system (debug, info, warn, error levels)
3. ✓ Settings system (get/set with namespaces)
4. ✓ Module registration and retrieval
5. ✓ Keybind registration and conflict detection
6. ✓ Event bus (custom signals and connections)
7. ✓ Patch system (apply-once functionality)

## Expected Output

When all tests pass, you should see:

```
=== Starting Core Framework Tests ===

Test 1: Framework Version
  Core version: 1.0.0
  ✓ PASS

Test 2: Logger System
  [timestamp] [INFO] Info message
  [timestamp] [WARN] Warning message
  [timestamp] [ERROR] Error message
  ✓ PASS

... (more tests) ...

=== All Tests Passed! ===
```

## Notes

- These are basic integration tests to verify the framework works correctly
- For production use, consider adding more comprehensive unit tests
- Tests automatically quit the application after completion
