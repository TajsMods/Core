# TajemnikTV-Core Framework Requirements
## Comprehensive Feature List & Missing Hooks Analysis

**Author:** TajemnikTV  
**Date:** 2026-01-09  
**Purpose:** Central reference for features, hooks, and utilities that should be provided by the Core framework mod.

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Core Infrastructure](#core-infrastructure)
3. [Missing Vanilla Hooks](#missing-vanilla-hooks)
4. [Commonly Needed Utilities](#commonly-needed-utilities)
5. [UI Framework Components](#ui-framework-components)
6. [Settings & Configuration](#settings--configuration)
7. [Event System](#event-system)
8. [Keybinds System](#keybinds-system)
9. [Node Registry](#node-registry)
10. [Workshop & Steam Integration](#workshop--steam-integration)
11. [Common Mod Patterns](#common-mod-patterns)
12. [Feature Requests from Disabled Mods](#feature-requests-from-disabled-mods)
13. [Priority Matrix](#priority-matrix)

---

## Executive Summary

Based on analysis of:
- **TajemnikTV-TajsModded** (116 files) - The previous monolithic mod
- **Huslaa-ModPack** (47 files) - Another comprehensive mod with hot-reload
- **Huslaa-Console** - Developer console mod
- **Goody-MultipleDesktops** - Multi-desktop features with hot-patching
- **bernier154-network_combiner** - Custom window registration
- **kuuk-SmartGPUManager/SmartThreadManager** - Automation mods
- **Vanilla game scripts** - globals.gd, signals.gd, data.gd, desktop.gd, etc.

The Core framework should provide:
1. **Centralized hooks** that vanilla game lacks
2. **Shared utilities** to avoid duplicate code across mods
3. **Standard patterns** for common mod operations
4. **Inter-mod communication** via event bus

---

## Core Infrastructure

### ✅ Already Implemented
- [x] **Runtime singleton** (`TajsCoreRuntime`) - Central access point via `Engine.get_meta("TajsCore")`
- [x] **Logger** - Unified logging with debug levels, file output, ring buffer
- [x] **Settings** - Schema-based configuration with typed values
- [x] **Migrations** - Version-based config migrations
- [x] **Event Bus** - Pub/sub for inter-mod communication
- [x] **Keybinds** - Keybind registration and override system
- [x] **Patches** - Script patching utilities
- [x] **Module Registry** - Mod registration and dependency tracking
- [x] **Version Utility** - SemVer comparison
- [x] **Workshop Sync** - Steam Workshop integration

### ⬜ Missing/Needed
- [ ] **Diagnostics Dashboard** - In-game diagnostics viewer
- [ ] **UI Manager** - Centralized HUD injection system
- [ ] **Node Registry** - Custom window type registration
- [ ] **Localization** - Translation key registration for mods
- [ ] **Theming** - Shared UI theme system
- [ ] **Asset Manager** - Icon/texture loading helpers

---

## Missing Vanilla Hooks

The vanilla game (`signals.gd`) provides some signals, but many important hooks are missing. The Core should provide these:

### Window Lifecycle Hooks

| Hook | Description | Vanilla Signal | Core Needed |
|------|-------------|----------------|-------------|
| `pre_window_create` | Before a window is instantiated | ❌ | ✅ |
| `window_created` | After window added to scene | `Signals.window_created` | ⬜ (exists) |
| `window_initialized` | After window fully set up | `Signals.window_initialized` | ⬜ (exists) |
| `pre_window_delete` | Before window is deleted | ❌ | ✅ |
| `window_deleted` | After window removed | `Signals.window_deleted` | ⬜ (exists) |
| `window_upgraded` | When window level changes | ❌ | ✅ |
| `window_paused` | When window processing paused | ❌ | ✅ |
| `window_resumed` | When window processing resumed | ❌ | ✅ |

### Connection Hooks

| Hook | Description | Vanilla Signal | Core Needed |
|------|-------------|----------------|-------------|
| `pre_connection_create` | Before wire connection | ❌ | ✅ |
| `connection_created` | After wire connected | `Signals.connection_created` | ⬜ (exists) |
| `pre_connection_delete` | Before wire disconnected | ❌ | ✅ |
| `connection_deleted` | After wire disconnected | `Signals.connection_deleted` | ⬜ (exists) |
| `connection_validated` | Check if connection allowed | ❌ | ✅ |

### Selection Hooks

| Hook | Description | Vanilla Signal | Core Needed |
|------|-------------|----------------|-------------|
| `selection_set` | Selection changed | `Signals.selection_set` | ⬜ (exists) |
| `pre_selection_delete` | Before deleting selection | ❌ | ✅ |
| `selection_moved` | After selection dragged | ❌ | ✅ |
| `selection_copied` | After Ctrl+C | ❌ | ✅ |
| `selection_pasted` | After Ctrl+V | ❌ | ✅ |

### Resource/Currency Hooks

| Hook | Description | Vanilla Signal | Core Needed |
|------|-------------|----------------|-------------|
| `currency_changed` | Any currency value changed | ❌ | ✅ |
| `resource_transferred` | Resource moved between nodes | ❌ | ✅ |
| `production_tick` | Per-tick production values | ❌ | ✅ |

### Progression Hooks

| Hook | Description | Vanilla Signal | Core Needed |
|------|-------------|----------------|-------------|
| `new_upgrade` | Upgrade purchased | `Signals.new_upgrade` | ⬜ (exists) |
| `new_research` | Research completed | `Signals.new_research` | ⬜ (exists) |
| `research_queued` | Research added to queue | `Signals.research_queued` | ⬜ (exists) |
| `new_perk` | Perk purchased | `Signals.new_perk` | ⬜ (exists) |
| `upgrade_cap_reached` | Hit vanilla cap | ❌ | ✅ |
| `pre_upgrade_purchase` | Before buying upgrade | ❌ | ✅ |

### Breach/Hacking Hooks

| Hook | Description | Vanilla Signal | Core Needed |
|------|-------------|----------------|-------------|
| `breached` | Breach completed | `Signals.breached` | ⬜ (exists) |
| `breach_failed` | Breach failed | ❌ | ✅ (from TajsModded) |
| `breach_threat_changed` | Threat level adjusted | ❌ | ✅ |
| `hack_level_changed` | Hack progression | `Signals.new_hack_level` | ⬜ (exists) |

### Save/Load Hooks

| Hook | Description | Vanilla Signal | Core Needed |
|------|-------------|----------------|-------------|
| `saving` | Before save | `Signals.saving` | ⬜ (exists) |
| `pre_load` | Before loading save | ❌ | ✅ |
| `post_load` | After loading complete | ❌ | ✅ |
| `new_game` | Fresh game started | ❌ | ✅ |
| `save_exported` | Schematic/save exported | ❌ | ✅ |

### UI/Menu Hooks

| Hook | Description | Vanilla Signal | Core Needed |
|------|-------------|----------------|-------------|
| `menu_opened` | Menu panel opened | `Signals.menu_set` | ⬜ (exists) |
| `menu_closed` | Menu panel closed | ❌ | ✅ |
| `hud_ready` | HUD fully initialized | ❌ | ✅ |
| `popup_shown` | Popup displayed | ❌ | ✅ |
| `tooltip_shown` | Tooltip displayed | ❌ | ✅ |

### Input Hooks

| Hook | Description | Vanilla Signal | Core Needed |
|------|-------------|----------------|-------------|
| `input_blocked` | Input being consumed | ❌ | ✅ |
| `tool_changed` | Tool switched | `Signals.tool_set` | ⬜ (exists) |
| `camera_moved` | Camera panned/zoomed | ❌ | ✅ |
| `keyboard_shortcut` | Global shortcut pressed | ❌ | ✅ |

---

## Commonly Needed Utilities

### Number Formatting
```gdscript
# Vanilla has Utils.print_string(), but mods often need:
func format_number(value: float, notation: int = -1) -> String
func format_time(seconds: float) -> String
func format_percentage(value: float, decimals: int = 1) -> String
func parse_number(text: String) -> float  # Inverse of format
```

### Node Finding
```gdscript
# Find nodes by type, name pattern, or custom predicate
func find_windows_by_type(type: String) -> Array[WindowContainer]
func find_windows_by_pattern(pattern: String) -> Array[WindowContainer]
func find_windows_by_predicate(predicate: Callable) -> Array[WindowContainer]
func get_window_by_name(name: String) -> WindowContainer
func get_all_connected_to(window: WindowContainer) -> Array[WindowContainer]
```

### Resource Helpers
```gdscript
func get_resource_by_id(id: String) -> ResourceContainer
func get_all_resources() -> Array[ResourceContainer]
func get_production_rate(resource_id: String) -> float
func get_consumption_rate(resource_id: String) -> float
```

### Path Helpers
```gdscript
func get_mod_path(mod_id: String) -> String
func get_mod_data_path(mod_id: String) -> String
func resolve_texture_path(relative_path: String, mod_id: String) -> String
```

### UI Helpers
```gdscript
func show_notification(icon: String, message: String) -> void
func show_toast(message: String, duration: float = 2.0) -> void
func create_button(text: String, callback: Callable) -> Button
func create_slider(label: String, value: float, min: float, max: float, callback: Callable) -> HSlider
func create_toggle(label: String, value: bool, callback: Callable) -> CheckButton
```

### Calculation Helpers
```gdscript
func calculate_upgrade_cost(upgrade: String, from_level: int, to_level: int) -> float
func calculate_max_affordable(upgrade: String, current_level: int, currency: float) -> int
func get_effective_cap(upgrade: String) -> int  # Including mod extensions
```

### Safe Operations
```gdscript
func safe_get_node(path: NodePath, default: Node = null) -> Node
func safe_connect(signal: Signal, callable: Callable) -> void
func safe_disconnect(signal: Signal, callable: Callable) -> void
func defer_until_ready(callback: Callable) -> void
```

---

## UI Framework Components

### Settings Panel Builder
The old TajsModded had a comprehensive settings UI. Core should provide:

```gdscript
# Settings Tab API
func add_settings_tab(title: String, icon: String) -> VBoxContainer
func add_toggle(container: VBoxContainer, label: String, value: bool, callback: Callable, tooltip: String = "") -> CheckButton
func add_slider(container: VBoxContainer, label: String, value: float, min: float, max: float, step: float, suffix: String, callback: Callable) -> HSlider
func add_dropdown(container: VBoxContainer, label: String, options: Array, selected: int, callback: Callable) -> OptionButton
func add_button(container: VBoxContainer, label: String, callback: Callable) -> Button
func add_text_input(container: VBoxContainer, label: String, value: String, callback: Callable) -> LineEdit
func add_color_picker(container: VBoxContainer, label: String, value: Color, callback: Callable) -> ColorPickerButton
func add_separator(container: VBoxContainer) -> HSeparator
func add_section_header(container: VBoxContainer, title: String) -> Label
func add_collapsible_section(container: VBoxContainer, title: String, expanded: bool = false) -> VBoxContainer
```

### HUD Injection Points
```gdscript
# Standard injection zones
enum HudZone {
    TOP_LEFT,
    TOP_RIGHT,
    BOTTOM_LEFT,
    BOTTOM_RIGHT,
    OVERLAY_CENTER,
    TOOLBAR_LEFT,
    TOOLBAR_RIGHT,
    STATUS_BAR
}

func inject_hud_widget(zone: HudZone, widget: Control, priority: int = 0) -> void
func remove_hud_widget(widget: Control) -> void
func get_hud_zone(zone: HudZone) -> Control
```

### Popup System
```gdscript
func show_popup(title: String, content: Control, buttons: Array[Dictionary]) -> void
func show_confirmation(title: String, message: String, on_confirm: Callable, on_cancel: Callable = Callable()) -> void
func show_input_dialog(title: String, prompt: String, default: String, on_submit: Callable) -> void
func close_popup() -> void
```

### Icon Browser
From TajsModded, the icon browser for selecting icons:
```gdscript
func open_icon_browser(callback: Callable, initial_selection: String = "") -> void
```

### Mod Settings Button
Standard button placement for mod settings access:
```gdscript
func register_mod_settings_button(mod_id: String, icon: String, callback: Callable) -> void
```

---

## Settings & Configuration

### Schema System (Already Implemented)
```gdscript
# Register typed settings with validation
func register_schema(namespace: String, schema: Dictionary) -> void

# Schema format:
{
    "key.name": {
        "type": "bool" | "int" | "float" | "string" | "dict" | "array",
        "default": <value>,
        "description": "Help text",
        "min": <optional>,
        "max": <optional>,
        "options": [<for enums>],
        "requires_restart": false,
        "visible": true,
        "on_change": Callable  # Optional callback
    }
}
```

### Missing: Settings Sync
```gdscript
# Sync settings across mod instances
signal settings_synced(namespace: String)
func export_settings(namespace: String) -> String
func import_settings(namespace: String, data: String) -> bool
```

### Missing: Feature Flags
```gdscript
# Simple feature toggles that can be checked anywhere
func register_feature(feature_id: String, default: bool, description: String) -> void
func is_feature_enabled(feature_id: String) -> bool
func set_feature_enabled(feature_id: String, enabled: bool) -> void
```

---

## Event System

### Core Events (Should be standardized)

```gdscript
# Core lifecycle events
"core.ready"              # Core framework initialized
"core.module_registered"  # New module registered
"core.settings_loaded"    # Settings file loaded

# Game state events
"game.started"           # Game scene entered
"game.main_ready"        # Main node ready
"game.hud_ready"         # HUD fully initialized
"game.desktop_ready"     # Desktop/canvas ready
"game.saving"            # About to save
"game.saved"             # Save completed
"game.loading"           # About to load
"game.loaded"            # Load completed

# Window events (extended from vanilla)
"window.pre_create"      # Before window instantiated
"window.created"         # Window added to scene
"window.initialized"     # Window fully ready
"window.pre_delete"      # Before window deleted
"window.deleted"         # Window removed
"window.upgraded"        # Window level changed
"window.moved"           # Window position changed

# Connection events
"connection.pre_create"  # Before connection made
"connection.created"     # Connection established
"connection.pre_delete"  # Before disconnection
"connection.deleted"     # Connection removed
"connection.validate"    # Check if connection allowed (return false to block)

# Selection events
"selection.changed"      # Selection modified
"selection.pre_delete"   # Before selection deleted
"selection.deleted"      # Selection deleted
"selection.copied"       # Ctrl+C performed
"selection.pasted"       # Ctrl+V performed

# UI events
"ui.menu_opened"         # Menu panel opened
"ui.menu_closed"         # Menu panel closed
"ui.popup_shown"         # Popup displayed
"ui.popup_closed"        # Popup closed

# Keybind events
"keybind.pressed"        # Registered keybind triggered
"keybind.registered"     # New keybind added
"keybind.overridden"     # Keybind remapped
```

### Event Data Patterns
```gdscript
# All events should include standardized payload:
{
    "source": <mod_id>,
    "timestamp": <unix_time>,
    "data": {<event-specific data>},
    "cancellable": <bool>,  # If true, handlers can set "cancelled" = true
    "cancelled": <bool>
}
```

### Blocking Events
```gdscript
# Example: Block a connection
event_bus.on("connection.validate", func(event: Dictionary):
    if should_block_connection(event.data.output, event.data.input):
        event.cancelled = true
        return false
)
```

---

## Keybinds System

### Already Implemented
- [x] Register keybinds with ID, key combo, callback
- [x] Override existing keybinds
- [x] Context system (e.g., only active when on desktop)
- [x] Conflict detection
- [x] Save/load overrides

### Needed Extensions
```gdscript
# Keybind categories for UI grouping
func register_keybind_category(category_id: String, label: String, icon: String) -> void

# Keybind groups (e.g., "editing", "navigation")
func set_keybind_group(keybind_id: String, group_id: String) -> void

# Combo support (Ctrl+Shift+Key)
func register_combo_keybind(id: String, keys: Array[int], callback: Callable) -> void

# Hold vs press distinction
func register_hold_keybind(id: String, key: int, on_press: Callable, on_release: Callable) -> void

# Context presets
enum KeybindContext {
    ALWAYS,
    DESKTOP_ONLY,
    MENU_ONLY,
    NO_POPUP,
    NO_TEXT_INPUT
}
func set_keybind_context(id: String, context: KeybindContext) -> void
```

### Default Keybinds to Register
From TajsModded analysis:
- `Ctrl+Z` - Undo
- `Ctrl+Y` / `Ctrl+Shift+Z` - Redo
- `Ctrl+A` - Select All
- `Delete` - Delete Selection
- `Escape` - Cancel/Close
- `Middle Mouse` - Command Palette (if enabled)
- `F5` - Take Screenshot (if enabled)
- `Ctrl+S` - Quick Save

---

## Node Registry

### Custom Window Registration
From `bernier154-network_combiner`, mods need to register custom windows:

```gdscript
# Register a new window type
func register_window_type(id: String, config: Dictionary) -> bool

# Config structure:
{
    "name": "Display Name",
    "icon": "res://path/to/icon.png",  # Or relative path from mod
    "description": "What this node does",
    "scene": "res://path/to/scene.tscn",
    "category": "network|cpu|gpu|research|factory|hacking|coding|utility",
    "group": "",  # For grouped limits like "machine"
    "level": 0,   # Unlock level
    "requirement": "",  # Unlock requirement key
    "hidden": false,
    "attributes": {
        "limit": -1,  # -1 = unlimited
        # ... custom attributes
    },
    "data": {},  # Initial window data
    "guide": "Help text"
}
```

### Resource Type Registration
```gdscript
# Register new resource types
func register_resource_type(id: String, config: Dictionary) -> bool

# Register new file types
func register_file_type(id: String, config: Dictionary) -> bool
```

### Category Extensions
```gdscript
# Add new category tabs to windows menu
func register_window_category(id: String, label: String, icon: String, position: int = -1) -> bool

# Add items to existing categories
func add_to_window_category(category_id: String, window_id: String, position: int = -1) -> bool
```

---

## Workshop & Steam Integration

### Already Implemented
- [x] Check subscribed items
- [x] Request downloads
- [x] High-priority downloads
- [x] Force re-download

### Needed Extensions
```gdscript
# Workshop item metadata
func get_subscribed_items() -> Array[Dictionary]
func get_item_details(workshop_id: int) -> Dictionary
func is_item_installed(workshop_id: int) -> bool
func get_item_install_path(workshop_id: int) -> String

# Download progress
signal download_progress(workshop_id: int, progress: float)
signal download_completed(workshop_id: int, success: bool)

# Restart handling
signal restart_required(reason: String)
func request_restart(reason: String) -> void
func show_restart_dialog() -> void
```

---

## Common Mod Patterns

### Pattern 1: Extending Vanilla Globals
```gdscript
# Many mods extend Globals with new properties
# Core should provide official extension mechanism
func extend_globals(property: String, value: Variant) -> void
func get_extended_global(property: String, default: Variant = null) -> Variant
```

### Pattern 2: Hot-Patching Scripts
From `Goody-MultipleDesktops`:
```gdscript
# Safe script patching
func patch_script(script_path: String, target: String, replacement: String) -> bool
func reload_script(script_path: String) -> bool
func is_script_patched(script_path: String, patch_id: String) -> bool
```

### Pattern 3: Hot Reload (Developer Mode)
From `Huslaa-ModPack`:
```gdscript
# Developer hot-reload support
func enable_hot_reload(mod_id: String, watch_paths: Array[String]) -> void
func trigger_hot_reload(mod_id: String) -> void
signal script_reloaded(path: String)
```

### Pattern 4: Upgrade Cap Extensions
From TajsModded's `ExtendedCapsManager`:
```gdscript
# Override upgrade caps beyond vanilla limits
func register_extended_cap(upgrade_id: String, config: Dictionary) -> void

# Config structure:
{
    "vanilla_cap": 10,
    "extended_cap": 50,  # Or -1 for unlimited
    "mode": "int" | "float",  # How to track level
    "step": 1,  # Level increment
    "requires": ["some_research"],  # Prerequisites
    "cost_multiplier": 1.5  # Cost scaling beyond vanilla
}

func get_effective_cap(upgrade_id: String) -> int
func is_extended_cap_enabled(upgrade_id: String) -> bool
```

### Pattern 5: Undo/Redo System
From TajsModded's `UndoManager`:
```gdscript
# Register undoable action
func register_undo_action(action_type: String, data: Dictionary) -> void

# Action types:
# - "window_create" / "window_delete" / "window_move"
# - "connection_create" / "connection_delete"
# - "upgrade_purchase" / etc.

func undo() -> bool
func redo() -> bool
func clear_history() -> void
func get_undo_count() -> int
func get_redo_count() -> int
```

---

## Feature Requests from Disabled Mods

### From TajemnikTV-TajsModded
| Feature | Status | Priority |
|---------|--------|----------|
| Command Palette | Extract to separate mod | High |
| Keybinds Manager | ✅ In Core | Done |
| Screenshot Manager | Extract to separate mod | Medium |
| Wire Color Overrides | Extract to QoL mod | Low |
| Disconnected Node Highlighter | Extract to QoL mod | Medium |
| Sticky Notes | Extract to QoL mod | Low |
| Buy Max Button | Extract to QoL mod | High |
| Go To Group | Extract to QoL mod | Medium |
| Notification Log | Extract to QoL mod | Medium |
| Breach Threat Manager | Extract to feature mod | Medium |
| Extended Caps | Extract to feature mod | High |
| Undo/Redo | Extract to Core or QoL | High |
| Schematic Node Limit Override | Core utility | High |
| Smooth Scroll | Extract to QoL mod | Low |

### From Huslaa-ModPack
| Feature | Status | Priority |
|---------|--------|----------|
| Hot Reload System | Core utility for devs | Medium |
| Module Loader System | Core pattern | Medium |
| Keybind Helper | ✅ In Core | Done |

### From Goody-MultipleDesktops
| Feature | Status | Priority |
|---------|--------|----------|
| Hot-Patching Utilities | Core utility | High |
| Safe Resource Access | Core utility | High |
| Signal Guard (prevent double-connect) | Core utility | Medium |

### From bernier154-network_combiner
| Feature | Status | Priority |
|---------|--------|----------|
| Custom Window Registration | Core API | High |
| Relative Path Resolution | Core utility | Medium |

### From kuuk-SmartGPUManager
| Feature | Status | Priority |
|---------|--------|----------|
| Window Automation API | Consider for Core | Low |
| Production Monitoring | Consider for Core | Low |

---

## Priority Matrix

### P0 - Critical (Must Have)
1. **Stable singleton access** - `TajsCoreRuntime.instance()`
2. **Event bus** - Cross-mod communication
3. **Settings system** - Schema + persistence
4. **Logger** - Unified logging
5. **Module registry** - Dependency management
6. **Custom window registration API**
7. **HUD injection system**
8. **Node limit override support**

### P1 - Important (Should Have)
1. **Keybinds system** (already implemented)
2. **Settings UI builder**
3. **Hot-patching utilities**
4. **Extended signal hooks**
5. **Undo/redo infrastructure**
6. **Safe node access utilities**
7. **Workshop sync** (already implemented)
8. **Upgrade cap extension API**

### P2 - Nice to Have
1. **Command palette Hook/API**
2. **Icon browser component**
3. **Hot reload for development**
4. **Theming system**
5. **Production monitoring API**
6. **Tooltip system**
7. **Color picker component**

### P3 - Future Consideration
1. **Localization system**
2. **Achievement injection**
3. **Save migration framework**
4. **Multiplayer hooks** (if game adds MP)
5. **Cloud save integration**

---

## Implementation Notes

### Script Extension Strategy
The vanilla game uses `ModLoaderMod.install_script_extension()` which works but has limitations:
- Can't add truly new signals to vanilla classes
- Order-dependent loading
- Conflicts between mods extending same script

**Recommendation:** Core should provide hook injection via runtime patching where extensions don't suffice.

### Signal Bridging
Since we can't add signals to vanilla classes, Core should:
1. Connect to existing vanilla signals
2. Re-emit them through event bus with enhanced payload
3. Provide pre/post hooks via Callable injection

### API Stability
- Use semantic versioning
- Deprecate with warnings before removal
- Provide `TajsCoreRuntime.require("1.0.0")` for version checking
- Document breaking changes in CHANGELOG

### Performance Considerations
- Event bus should be O(1) for common operations
- Settings reads should be cached
- Lazy-load optional services
- Avoid per-frame operations where possible

---

## Files to Reference

### Core Components
- `core/runtime.gd` - Main runtime
- `core/logger.gd` - Logging
- `core/settings.gd` - Configuration
- `core/event_bus.gd` - Events
- `core/keybinds.gd` - Keybinds
- `core/patches.gd` - Script patching
- `core/module_registry.gd` - Mod tracking
- `core/version.gd` - Version utilities
- `core/workshop_sync.gd` - Steam integration
- `core/nodes/node_registry.gd` - Custom nodes

### Vanilla Files to Hook
- `scripts/globals.gd` - Game state
- `scripts/signals.gd` - Vanilla signals
- `scripts/data.gd` - Game data
- `scripts/desktop.gd` - Main canvas
- `scripts/hud.gd` - UI layer
- `scripts/utils.gd` - Utilities
- `scenes/windows/window_container.gd` - Window base
- `scenes/resource_container.gd` - Resource slots

---

## Conclusion

The Core framework should be the foundation that all other mods build upon. By providing:

1. **Stable APIs** for common operations
2. **Missing hooks** that vanilla doesn't provide
3. **Shared utilities** to reduce code duplication
4. **Standard patterns** for mod development
5. **Inter-mod communication** via event bus

We enable a healthier mod ecosystem where mods can:
- Share functionality without conflicts
- Communicate without direct dependencies
- Be smaller and more focused
- Update independently

The monolithic TajsModded approach worked but doesn't scale. Splitting into Core + feature mods is the right architecture.
