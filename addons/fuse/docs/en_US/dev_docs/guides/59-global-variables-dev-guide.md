> 🌐 [**中文版**](../../../zh_CN/dev_docs/guides/59-global-variables-dev-guide.md) | English

# Global Variables Development Guide

> **Goal**: Provide developers with an architecture description and integration guide for the Fuse global variable system, covering the `GlobalVariableManager` + `GlobalVariableService` + `GlobalVariableAssistant` three-layer division of responsibilities, the declaration and read/write APIs, thread safety, the persistence pipeline, and the integration with the preset system.

**Audience**: Fuse system developers, contributors

**Last updated**: 2026-07-19

**Companion user doc**: [54-global-variables-guide.md](../../user_docs/guides/54-global-variables-guide.md)

---

## 📋 Table of Contents

1. [Two-Layer Architecture Overview](#two-layer-architecture-overview)
2. [GlobalVariableManager (Singleton Core)](#globalvariablemanager-singleton-core)
3. [GlobalVariableService (Tree-Independent Service Layer)](#globalvariableservice-tree-independent-service-layer)
4. [GlobalVariableAssistant (Scene Tree Helper)](#globalvariableassistant-scene-tree-helper)
5. [GlobalVariableResource (Data Carrier)](#globalvariableresource-data-carrier)
6. [Variable Declaration and Access](#variable-declaration-and-access)
7. [Thread-Safe API](#thread-safe-api)
8. [Persistence Pipeline](#persistence-pipeline)
9. [Integration with the Preset System](#integration-with-the-preset-system)
10. [Best Practices](#best-practices)
11. [Common Pitfalls](#common-pitfalls)

---

## Two-Layer Architecture Overview

The global variable system adopts a **Service + Assistant two-layer architecture**, backed by the Manager singleton:

| Layer | Component | Type | Path | Responsibilities |
|----|------|------|------|------|
| Core layer | GlobalVariableManager | RefCounted singleton | `core/global_variable_manager.gd` | Variable CRUD, signals, thread safety, persistence core |
| Service layer | GlobalVariableService | RefCounted | `core/global_variable_service.gd` | Tree-independent CRUD facade; naming consistent with the Assistant |
| Helper layer | GlobalVariableAssistant | Node | `core/global_variable_assistant.gd` | Scene tree lifecycle, resource binding, auto save/load |
| Data layer | GlobalVariableResource | Resource | `core/global_variable_resource.gd` | `.tres` save format |

### Dependency Relationships

```
┌────────────────────────────────────────────────┐
│ GlobalVariableAssistant (Node, scene tree)      │
│  - lifecycle: _ready auto load / _exit_tree save │
│  - holds GlobalVariableService                   │
└───────────────┬────────────────────────────────┘
                │ delegates
                ▼
┌────────────────────────────────────────────────┐
│ GlobalVariableService (RefCounted, tree-free)   │
│  - add_global_variable / get_global_variable    │
│  - save_persistent_variables / load_resource    │
└───────────────┬────────────────────────────────┘
                │ delegates
                ▼
┌────────────────────────────────────────────────┐
│ GlobalVariableManager (RefCounted singleton)    │
│  - _variables: Dictionary (name → BaseVariable) │
│  - Mutex protection + signal notifications      │
│  - save_to_resource / load_from_resource        │
└───────────────┬────────────────────────────────┘
                │ serialization
                ▼
        GlobalVariableResource (.tres)
```

### Which Layer to Use When

| Scenario | Recommended entry point |
|------|----------|
| Read/write variables in instructions/runtime | `VariableOperations.get/set_variable(context, name, GLOBAL, ...)` |
| Read/write variables in ordinary scripts | `GlobalVariableManager.get_instance()` |
| No scene tree available (tool scripts, tests) | `GlobalVariableService.new()` |
| Auto save/load and resource binding needed | Place a `GlobalVariableAssistant` node in the scene |
| Editor tools (e.g. the variable watcher) | `GlobalVariableService` (see [58-variable-watcher-dev-guide.md](58-variable-watcher-dev-guide.md)) |

---

## GlobalVariableManager (Singleton Core)

`GlobalVariableManager` is the de facto data core, a `RefCounted` singleton.

### Singleton Access

```gdscript
# ✅ Correct
var gvm := GlobalVariableManager.get_instance()

# ❌ Wrong — never new() / preload()
var gvm = GlobalVariableManager.new()

# Check whether the singleton exists (avoids implicit creation)
if GlobalVariableManager.has_instance():
	pass
```

### CRUD API

| Method | Returns | Description |
|------|------|------|
| `add_variable(name, variable)` | bool | Add a variable (BaseVariable) |
| `get_variable(name)` | BaseVariable | Get; returns null if absent |
| `has_variable(name)` | bool | Existence check |
| `remove_variable(name)` | bool | Remove |
| `get_all_variable_names()` | Array[String] | All variable names |
| `get_variable_count()` | int | Number of variables |
| `clear_all_variables()` | void | Clear everything |
| `get_all_variables_snapshot()` | Dictionary | Full snapshot (value copy) |
| `get_variables_safe()` | Dictionary | Safely get the variable dictionary |

### Signals

| Signal | Arguments | Emitted when |
|------|------|----------|
| `variable_added` | name, variable | `add_variable()` succeeds |
| `variable_removed` | name | `remove_variable()` succeeds |
| `variable_changed` | name, old_value, new_value | Variable value changed (including content-level changes) |

Content-level changes (e.g. array element modifications) require manual notification:

```gdscript
gvm.notify_variable_content_changed("inventory")
```

### Internal Implementation Notes

- `_variables: Dictionary` stores `BaseVariable` instances directly (not value copies)
- `_mutex: Mutex` protects multithreaded access (see [Thread-Safe API](#thread-safe-api))
- `_resource_path: String` records the most recent save/load path

---

## GlobalVariableService (Tree-Independent Service Layer)

`GlobalVariableService` is a pure `RefCounted` facade, **independent of the scene tree**; it grabs the Manager on construction:

```gdscript
var _manager: GlobalVariableManager

func _init():
	_manager = GlobalVariableManager.get_instance()
```

### API (Naming Aligned with the Assistant)

| Method | Returns | Description |
|------|------|------|
| `add_global_variable(name, variable)` | bool | Add |
| `get_global_variable(name)` | BaseVariable | Get |
| `has_global_variable(name)` | bool | Existence |
| `remove_global_variable(name)` | bool | Remove |
| `get_all_global_variable_names()` | Array[String] | Name list |
| `get_all_global_variables_info()` | Dictionary | Detailed info (for debugging/watchers) |
| `get_variable_count()` | int | Count |
| `save_persistent_variables(path)` | bool | Saves only persistent variables |
| `load_resource(path)` | bool | Load from `.tres` |
| `create_new_resource(path, description)` | bool | Create a new resource file |
| `get_resource_path()` | String | Current resource path |
| `get_statistics()` | Dictionary | Statistics |

### Usage Example

```gdscript
# In tree-free tool scripts / editor plugins
var service := GlobalVariableService.new()

var score := BaseVariable.new()
score.variable_name = "score"
score.value = 0
score.persistent = true
service.add_global_variable("score", score)

var info := service.get_all_global_variables_info()
for name in info:
	print("%s = %s (%s)" % [name, info[name]["value"], info[name]["type"]])
```

> **Design intent**: Service uses the same naming style as the Assistant (`add_global_variable` instead of `add_variable`), so that caller code can switch painlessly between the "scene tree available" and "no scene tree" environments.

---

## GlobalVariableAssistant (Scene Tree Helper)

`GlobalVariableAssistant` is a `Node` subclass that plugs the global variable system **into the scene tree lifecycle**.

### How to Access

```gdscript
# ✅ Recommended: place the node in a scene (drag it in the editor, or the scene file does the add_child)
# ✅ Get it at runtime
var assistant := GlobalVariableAssistant.get_instance()

# ❌ Wrong — never manually new() + add_child()
```

### Exported Properties

| Property | Type | Default | Description |
|------|------|--------|------|
| `current_resource` | GlobalVariableResource | null | Currently bound resource |
| `resource_path` | String | `""` | Resource file path |
| `auto_save` | bool | true | Auto save on exit |
| `auto_load_on_ready` | bool | true | Auto load in `_ready` |
| `cleanup_on_exit` | bool | true | Clear non-persistent variables on exit |
| `auto_save_on_change` | bool | false | Auto save on variable change (high-frequency overhead, off by default) |
| `auto_save_delay` | float | 1.0 | Delayed-save seconds after a change (debounce) |
| `auto_register` | bool | true | Auto register with the Manager |
| `log_level` | FuseLogger.LogLevel | INFO | Log level |

### Lifecycle

```
_enter_tree()   → register the singleton reference (auto_register)
_ready()        → _setup_save_timer()
                  if auto_load_on_ready → _load_from_current_resource()
While running   → listen to Manager signals → forward variable_added/removed/modified
                  if auto_save_on_change → _request_delayed_save() (Timer debounce)
_exit_tree()    → _perform_save_and_cleanup()
                  if auto_save → save
                  if cleanup_on_exit → clear non-persistent variables
```

### Signals

| Signal | Arguments | Description |
|------|------|------|
| `resource_changed` | old_resource, new_resource | Resource switched |
| `variable_added` | name, variable_data | Variable added (forwarded from the Manager) |
| `variable_removed` | name | Variable removed |
| `variable_modified` | name, old_data, new_data | Variable modified |
| `save_completed` | success, path | Save finished |
| `load_completed` | success, path, resource | Load finished |

### Key Methods

| Method | Description |
|------|------|
| `register_to_manager()` / `unregister_from_manager()` | Establish/tear down the signal connections with the Manager |
| `set_current_resource(resource)` | Switch the bound resource |
| `load_resource(path)` | Load the given resource |
| `save_current_resource()` | Save to the current resource |
| `save_persistent_variables()` | Save only persistent variables |
| `create_new_resource(path, description)` | Create a new resource file |
| `get_current_resource_info()` | Resource metadata |

### Error Handling

The Assistant has built-in `FuseError` integration:

```gdscript
if assistant.has_fuse_error():
	var err: FuseError = assistant.get_fuse_error()
	push_error(err.get_formatted_message())
```

---

## GlobalVariableResource (Data Carrier)

`GlobalVariableResource` is the resource format of `.tres` save files:

| Property | Type | Description |
|------|------|------|
| `variables` | Dictionary | Variable name → variable data |
| `description` | String | Description |
| `created_time` | float | Creation timestamp |
| `last_modified` | float | Last modified timestamp |
| `version` | String | Version (`CURRENT_VERSION = "2.0.0"`) |
| `author` | String | Author |
| `tags` | Array[String] | Tags |

It provides methods such as `add_variable(name, variable_data, persistent)` / `set_variable()`, accepting either raw values or dictionary-formatted data.

---

## Variable Declaration and Access

### Declaring in Code

```gdscript
var gvm := GlobalVariableManager.get_instance()

# Idempotent initialization (recommended inside _ready)
if not gvm.has_variable("player_health"):
	var v := BaseVariable.new()
	v.variable_name = "player_health"
	v.value = 100
	v.persistent = true        # Persistence flag
	gvm.add_variable("player_health", v)
```

### Reading/Writing at the Instruction Level (Recommended)

Instructions should **not** access the Manager directly; always go through `VariableOperations`:

```gdscript
# Read
var value = VariableOperations.get_variable(
	context, "player_health",
	BaseVariable.VariableScope.GLOBAL,
	0  # Default value
)

# Write
VariableOperations.set_variable(
	context, "player_health",
	BaseVariable.VariableScope.GLOBAL,
	80
)
```

Internally, `VariableOperations` routes the `GLOBAL` branch to `context.global_variables` (i.e. the Manager), while handling existence checks and error logging.

### Scope Resolution Recap

| Scope | Storage location | Lifetime |
|--------|----------|----------|
| LOCAL | ExecutionContext | A single execution |
| SCOPE | ScopeVariableContainer | Node lifetime |
| GLOBAL | GlobalVariableManager | Game process |

See the [Variable System User Guide](../../user_docs/guides/01-variable-system-guide.md) for details.

---

## Thread-Safe API

The Manager has a built-in `Mutex` and provides a family of `_thread_safe`-suffixed methods for multithreaded instructions:

| Method | Description |
|------|------|
| `get_variable_thread_safe(name)` | Locked read |
| `has_variable_thread_safe(name)` | Locked existence check |
| `set_variable_thread_safe(name, variable)` | Locked write of an entire variable |
| `set_variable_value_thread_safe(name, value)` | Locked value write |
| `get_variables_batch_thread_safe(names)` | Batched locked reads |
| `get_variables_safe()` / `get_all_variables_snapshot()` | Safe snapshots |

```gdscript
# Inside a multithreaded worker
var gvm := GlobalVariableManager.get_instance()
gvm.set_variable_value_thread_safe("progress", 0.75)
var batch := gvm.get_variables_batch_thread_safe(["hp", "mp", "exp"])
```

> **Note**: Direct access via `get_variable()` / `add_variable()` is not thread-safe. Multithreaded code must use the `_thread_safe` family. See [multithreading.md](../../user_docs/guides/52-multithreading-optimization.md) for details.

---

## Persistence Pipeline

### Manager Level

```gdscript
var gvm := GlobalVariableManager.get_instance()

gvm.save_to_resource("user://save.tres")             # Save everything
gvm.save_persistent_to_resource("user://save.tres")  # persistent only
gvm.load_from_resource("user://save.tres")           # Load (clears existing variables)
```

### Instruction Level

| Instruction | Path | Key properties |
|------|------|----------|
| SaveGlobalVariables | `instructions/variables/save_global_variables.gd` | `save_target`(ASSISTANT_RESOURCE/CUSTOM_PATH), `custom_path`, `save_scope`(ALL/PERSISTENT_ONLY) |
| LoadGlobalVariables | `instructions/variables/load_global_variables.gd` | `load_source`, `custom_path` |

### The Persistence Flag

Only variables with `persistent = true` are saved by `PERSISTENT_ONLY` / `save_persistent_to_resource()`. Temporary state such as cooldown timers should use `persistent = false`.

---

## Integration with the Preset System

The preset system interacts with global variables through **variable dependency declarations** (see [57-preset-system-dev-guide.md](57-preset-system-dev-guide.md) for details):

1. **At export**: `FusePreset.collect_variables()` scans the instructions and writes the names of variables with `variable_scope == 2` (GLOBAL) into `variables["global"]`
2. **At import**: the import dialog shows the global dependencies but does **not auto-create** the variables — global variables are project-level state
3. **At runtime**: `GetVariable/SetVariable [GLOBAL]` in preset instructions is routed to the Manager through `VariableOperations`

### Division of Responsibilities

| Concern | Responsible system |
|--------|----------|
| Declaring "which global variables are needed" | The preset (`variables.global`) |
| Variable creation/initial value/persistent | The project initialization flow (SetVariable instruction or code) |
| Cross-scene persistence | GlobalVariableAssistant + Save/Load instructions |

### Integration Checklist

When developing presets that depend on global variables:

- ✅ Instructions use the `variable_name` + `variable_scope` properties (so the preset system can collect dependencies automatically)
- ✅ Establish initial values with SetVariable [GLOBAL] in a game-initialization Trigger
- ✅ Set `persistent = true` for variables that need to be saved
- ❌ Do not expect preset import to auto-register global variables

---

## Best Practices

### 1. Cache the Singleton Reference

```gdscript
# ✅ Cache it
var _gvm: GlobalVariableManager

func _ready():
	_gvm = GlobalVariableManager.get_instance()

# ❌ Calling get_instance() every time
```

### 2. Idempotent Initialization

Always pre-check with `has_variable()` before registering a variable, to avoid overwriting existing values (especially save values auto-loaded by the Assistant).

### 3. Keep auto_save_on_change Off

High-frequency variables (e.g. timers updated every frame) would trigger disk IO storms. Recommended:
- `auto_save_on_change = false` (the default)
- Save manually with the SaveGlobalVariables instruction at key points
- Or rely on the `auto_save_delay` debounce

### 4. Pick the Right Layer

- Game runtime scripts → Manager
- Editor plugins/tools → Service
- Scene-level automatic persistence → Assistant node

### 5. Use Only the _thread_safe Family in Multithreading

Mixing locking and non-locking APIs breaks the mutual-exclusion semantics.

---

## Common Pitfalls

### Pitfall 1: Creating the Manager with new()

**Problem**: `GlobalVariableManager.new()` creates a second instance and the data splits.

**Solution**: always use `GlobalVariableManager.get_instance()`; use `has_instance()` as a defensive check.

### Pitfall 2: Manually Adding the Assistant via add_child

**Problem**: `GlobalVariableAssistant.new()` + `add_child()` bypasses the singleton registration and the lifecycle callback ordering goes wrong.

**Solution**: put the Assistant node into the scene file in the editor, or get the running instance with `get_instance()`.

### Pitfall 3: Loading Overwrites Unsaved Data

**Problem**: `load_from_resource()` **clears existing variables** before loading, so unsaved runtime data is lost.

**Solution**: call `save_to_resource()` before loading, or make sure of the load timing (game start / save-slot load).

### Pitfall 4: Content-Level Changes Emit No Signal

**Problem**: after modifying array/dictionary elements, `variable_changed` is not emitted and the UI does not refresh.

**Solution**: call `notify_variable_content_changed(name)` after modifying.

### Pitfall 5: Accessing the Manager Directly in Instructions

**Problem**: writing `GlobalVariableManager.get_instance().get_variable(...)` inside an instruction bypasses the unified routing and error handling of the three-layer variable system.

**Solution**: instructions must always use `VariableOperations.get/set_variable(context, name, GLOBAL, ...)`.

### Pitfall 6: Using Non-Locking APIs in Multithreading

**Problem**: a worker thread calls `get_variable()`, racing with main-thread writes.

**Solution**: replace all multithreaded paths with the `_thread_safe` family of methods.

---

## Summary

Core takeaways for global variable system development:

1. ✅ **Three layers with clear responsibilities** — Manager (data core) ∥ Service (tree-free facade) ∥ Assistant (scene lifecycle)
2. ✅ **Singleton discipline** — neither Manager nor Assistant may be `new()`ed; use `get_instance()`
3. ✅ **Instructions go through VariableOperations** — unified GLOBAL routing; never touch the Manager directly
4. ✅ **Explicit thread safety** — `_thread_safe`-suffixed APIs + Mutex
5. ✅ **Driven by the persistence flag** — `persistent` decides the save scope; `auto_save_on_change` is off by default
6. ✅ **Presets only declare dependencies** — the right to create global variables belongs to the project, not to the preset

**Reference documents**:
- [Global Variables Management Guide](../../user_docs/guides/54-global-variables-guide.md)
- [Preset System Developer Guide](57-preset-system-dev-guide.md)
- [Variable Watcher Development Guide](58-variable-watcher-dev-guide.md)
- [Variable Operations Utility](variable-operations-guide.md)
- [Multithreading Support](../../user_docs/guides/52-multithreading-optimization.md)

---

**Document maintainer**: Fuse development team
**Last updated**: 2026-07-19
