# TajemnikTV-Core Implementation Checklist
## Actionable Tasks for Core Framework Development

**Last Updated:** 2026-01-09

---

## Quick Reference: Current State

### ✅ Already Implemented
| Component | File | Status |
|-----------|------|--------|
| Runtime Singleton | `core/runtime.gd` | Complete |
| Logger | `core/logger.gd` | Complete |
| Settings Manager | `core/settings.gd` | Complete |
| Migrations | `core/migrations.gd` | Complete |
| Event Bus | `core/event_bus.gd` | Complete |
| Keybinds | `core/keybinds.gd` | Complete |
| Patches | `core/patches.gd` | Partial |
| Module Registry | `core/module_registry.gd` | Complete |
| Version Utils | `core/version.gd` | Complete |
| Workshop Sync | `core/workshop_sync.gd` | Complete |
| Node Registry | `core/nodes/node_registry.gd` | Partial |
| UI Manager | `core/ui/ui_manager.gd` | Partial |
| Diagnostics | `core/diagnostics.gd` | Partial |

---

## Phase 1: Essential Hooks (P0)

### 1.1 Window Lifecycle Hooks
- [ ] **Task:** Add `pre_window_create` hook
  - Location: `core/hooks/window_hooks.gd` (new file)
  - Connect to `Signals.create_window`
  - Emit event before window is added
  
- [ ] **Task:** Add `pre_window_delete` hook
  - Intercept window close() calls
  - Allow cancellation
  
- [ ] **Task:** Add `window_upgraded` hook
  - Connect to upgrade button signals
  - Emit with window ID and new level

### 1.2 Connection Hooks
- [ ] **Task:** Add `pre_connection_create` hook
  - Connect to `Signals.create_connection`
  - Add cancellation support
  
- [ ] **Task:** Add `connection_validated` hook
  - Allow mods to block connections
  - Return false to prevent

### 1.3 Selection Hooks  
- [ ] **Task:** Add `pre_selection_delete` hook
  - Intercept delete operations
  - Allow cancellation/modification
  
- [ ] **Task:** Add `selection_copied/pasted` hooks
  - Connect to desktop _input for Ctrl+C/V

### 1.4 Save/Load Hooks
- [ ] **Task:** Add `pre_load` and `post_load` hooks
  - Connect to Data loading flow
  - Emit before/after save restoration

---

## Phase 2: Core Utilities (P1)

### 2.1 Node Finding Utilities
- [ ] **Task:** Create `core/util/node_finder.gd`
  ```gdscript
  func find_windows_by_type(type: String) -> Array[WindowContainer]
  func find_windows_by_pattern(pattern: String) -> Array[WindowContainer]
  func find_windows_by_predicate(predicate: Callable) -> Array[WindowContainer]
  func get_window_by_name(name: String) -> WindowContainer
  func get_all_connected_to(window: WindowContainer) -> Array[WindowContainer]
  ```

### 2.2 Path Resolution Utilities
- [ ] **Task:** Add to `core/util.gd`
  ```gdscript
  func get_mod_path(mod_id: String) -> String
  func resolve_texture_path(relative: String, mod_id: String) -> String
  func get_mod_data_path(mod_id: String) -> String
  ```

### 2.3 Safe Operations
- [ ] **Task:** Create `core/util/safe_ops.gd`
  ```gdscript
  func safe_get_node(path: NodePath, default: Node = null) -> Node
  func safe_connect(signal: Signal, callable: Callable) -> void
  func safe_disconnect(signal: Signal, callable: Callable) -> void
  func defer_until_ready(callback: Callable) -> void
  ```

### 2.4 Calculation Helpers
- [ ] **Task:** Create `core/util/calculations.gd`
  ```gdscript
  func calculate_upgrade_cost(upgrade: String, from_level: int, to_level: int) -> float
  func calculate_max_affordable(upgrade: String, current_level: int, currency: float) -> int
  func get_effective_cap(upgrade: String) -> int
  ```

---

## Phase 3: UI Framework (P1)

### 3.1 Settings Panel Builder
- [ ] **Task:** Expand `core/ui/ui_manager.gd` or create `core/ui/settings_builder.gd`
  - `add_settings_tab(title, icon) -> VBoxContainer`
  - `add_toggle(container, label, value, callback, tooltip) -> CheckButton`
  - `add_slider(container, label, value, min, max, step, suffix, callback) -> HSlider`
  - `add_dropdown(container, label, options, selected, callback) -> OptionButton`
  - `add_button(container, label, callback) -> Button`
  - `add_text_input(container, label, value, callback) -> LineEdit`
  - `add_color_picker(container, label, value, callback) -> ColorPickerButton`
  - `add_separator(container) -> HSeparator`
  - `add_section_header(container, title) -> Label`
  - `add_collapsible_section(container, title, expanded) -> VBoxContainer`

### 3.2 HUD Injection System
- [ ] **Task:** Create `core/ui/hud_injector.gd`
  - Define injection zones (TOP_LEFT, TOP_RIGHT, etc.)
  - `inject_widget(zone, widget, priority) -> void`
  - `remove_widget(widget) -> void`
  - `get_zone_container(zone) -> Control`

### 3.3 Popup System
- [ ] **Task:** Create `core/ui/popup_manager.gd`
  - `show_popup(title, content, buttons) -> void`
  - `show_confirmation(title, message, on_confirm, on_cancel) -> void`
  - `show_input_dialog(title, prompt, default, on_submit) -> void`
  - `close_popup() -> void`

### 3.4 Notification Helpers
- [ ] **Task:** Add to UI manager
  - `show_notification(icon, message) -> void` (wrapper for Signals.notify)
  - `show_toast(message, duration) -> void`

---

## Phase 4: Node Registry API (P1)

### 4.1 Custom Window Registration
- [ ] **Task:** Expand `core/nodes/node_registry.gd`
  ```gdscript
  func register_window_type(id: String, config: Dictionary) -> bool
  func unregister_window_type(id: String) -> bool
  func get_window_config(id: String) -> Dictionary
  func get_registered_window_types() -> Array[String]
  ```
  
- [ ] **Task:** Config structure validation
  ```gdscript
  # Required fields:
  # - name, icon, scene, category
  # Optional:
  # - description, group, level, requirement, hidden, attributes, data, guide
  ```

### 4.2 Resource Registration
- [ ] **Task:** Add to node_registry or create separate file
  ```gdscript
  func register_resource_type(id: String, config: Dictionary) -> bool
  func register_file_type(id: String, config: Dictionary) -> bool
  ```

### 4.3 Category Extensions
- [ ] **Task:** Window category management
  ```gdscript
  func register_window_category(id: String, label: String, icon: String, position: int) -> bool
  func add_to_window_category(category_id: String, window_id: String, position: int) -> bool
  ```

---

## Phase 5: Extended Features (P2)

### 5.1 Hot-Patching Utilities
- [ ] **Task:** Expand `core/patches.gd`
  ```gdscript
  func patch_script(script_path: String, target: String, replacement: String) -> bool
  func reload_script(script_path: String) -> bool
  func is_script_patched(script_path: String, patch_id: String) -> bool
  func register_patch(patch_id: String, script_path: String, target: String, replacement: String) -> void
  ```

### 5.2 Upgrade Cap Extensions
- [ ] **Task:** Create `core/mechanics/upgrade_caps.gd`
  ```gdscript
  func register_extended_cap(upgrade_id: String, config: Dictionary) -> void
  func get_effective_cap(upgrade_id: String) -> int
  func is_extended_cap_enabled(upgrade_id: String) -> bool
  ```

### 5.3 Undo/Redo Infrastructure
- [ ] **Task:** Create `core/util/undo_stack.gd`
  ```gdscript
  func register_action(type: String, data: Dictionary) -> void
  func undo() -> bool
  func redo() -> bool
  func clear() -> void
  func get_undo_count() -> int
  func get_redo_count() -> int
  signal action_registered(type: String)
  signal undo_performed()
  signal redo_performed()
  ```

### 5.4 Command Palette Hooks
- [ ] **Task:** Create `core/ui/palette_hooks.gd` (optional, for palette mod)
  ```gdscript
  signal palette_opened
  signal palette_closed
  signal command_executed(command_id: String)
  func register_command_provider(provider: Callable) -> void
  ```

---

## Phase 6: Developer Tools (P2)

### 6.1 Hot Reload Support
- [ ] **Task:** Create `core/dev/hot_reload.gd`
  ```gdscript
  func enable_hot_reload(mod_id: String, watch_paths: Array[String]) -> void
  func trigger_reload(mod_id: String) -> void
  signal script_reloaded(path: String)
  ```

### 6.2 Diagnostics Dashboard
- [ ] **Task:** Expand `core/diagnostics.gd`
  - Show registered modules
  - Show active hooks
  - Show event bus subscriptions
  - Show keybind registrations
  - Performance metrics

### 6.3 Debug Console
- [ ] **Task:** Create `core/dev/console.gd` (optional)
  - In-game console for debugging
  - Command registration API
  - Log output display

---

## Testing Checklist

### Unit Tests Needed
- [ ] Settings schema validation
- [ ] Event bus emit/receive
- [ ] Keybind conflict detection
- [ ] Version comparison
- [ ] Path resolution

### Integration Tests Needed
- [ ] Module registration flow
- [ ] Workshop sync behavior
- [ ] HUD injection
- [ ] Window registration

### Manual Testing
- [ ] Fresh game start
- [ ] Load existing save
- [ ] Multiple mods active
- [ ] Mod enable/disable
- [ ] Settings persistence

---

## Documentation Needed

### API Documentation
- [ ] Runtime API reference
- [ ] Event bus events list
- [ ] Settings schema format
- [ ] Node registration format
- [ ] UI builder methods

### Guides
- [ ] Getting started for modders
- [ ] Migrating from TajsModded
- [ ] Creating custom windows
- [ ] Using the event bus
- [ ] Hot-patching best practices

### Examples
- [ ] Minimal mod template
- [ ] Custom window example
- [ ] Settings panel example
- [ ] Event listener example
- [ ] Keybind registration example

---

## Migration Path from TajsModded

### Components to Extract
| TajsModded Component | Target Module | Priority |
|---------------------|---------------|----------|
| ConfigManager | Core Settings | ✅ Done |
| KeybindsManager | Core Keybinds | ✅ Done |
| WorkshopSync | Core Workshop | ✅ Done |
| Patcher | Core Patches | Partial |
| Command Palette | TajemnikTV-CommandPalette | High |
| Screenshot Manager | Separate mod | Medium |
| Buy Max | TajemnikTV-QoL | High |
| Wire Color Overrides | TajemnikTV-QoL | Low |
| Disconnected Highlighter | TajemnikTV-QoL | Medium |
| Sticky Notes | TajemnikTV-QoL | Low |
| Breach Threat Manager | Separate mod | Medium |
| Extended Caps | TajemnikTV-Cheats or Core | High |
| Undo Manager | Core or QoL | High |
| Schematic Limit Override | Core | High |

---

## Version Milestones

### v1.0.0 (MVP)
- [ ] Stable runtime singleton
- [ ] Settings system
- [ ] Logger
- [ ] Event bus
- [ ] Module registry
- [ ] Basic UI injection

### v1.1.0
- [ ] Keybinds system
- [ ] Workshop sync
- [ ] Extended hooks (pre/post)
- [ ] Node registry API

### v1.2.0
- [ ] Settings UI builder
- [ ] Popup system
- [ ] HUD zones
- [ ] Utility functions

### v2.0.0
- [ ] Hot-patching framework
- [ ] Undo/redo infrastructure
- [ ] Upgrade cap extensions
- [ ] Full documentation

---

## Notes

### Known Limitations
1. **Script extensions can't add signals** - Use event bus bridge instead
2. **Hooks in shipped builds** - Script hooks API doesn't work in exported builds
3. **Class_name conflicts** - Can't extend classes with class_name easily
4. **Loading order** - Core must load before dependent mods

### Design Decisions
1. **Singleton pattern** - Use Engine.set_meta for global access
2. **Lazy loading** - Only load optional services when needed
3. **Event bus over signals** - Better for cross-mod communication
4. **Schema-based settings** - Type safety and validation
5. **Namespace prefixes** - e.g., "core.debug" vs "mymod.setting"
