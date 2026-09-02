> 🌐 [**中文版**](../../../zh_CN/user_docs/guides/54-global-variables-guide.md) | English

# Global Variables Management Guide

## Overview

The Fuse global variable system provides an integrated **storage management + persistence** solution covering the complete workflow from variable creation to save/load. The system consists of the following components:

| Component | Type | Path | Purpose |
|------|------|------|------|
| GlobalVariableManager | Singleton (RefCounted) | `core/global_variable_manager.gd` | Variable CRUD, signal listening, persistence core logic |
| GlobalVariableAssistant | Node | `core/global_variable_assistant.gd` | Scene tree helper; manages resource files, auto save/load |
| GlobalVariableResource | Resource | `core/global_variable_resource.gd` | `.tres` resource file storing variable snapshots |
| SaveGlobalVariables | Instruction | `instructions/variables/save_global_variables.gd` | Save instruction |
| LoadGlobalVariables | Instruction | `instructions/variables/load_global_variables.gd` | Load instruction |

---

## Concept Primer

The Fuse variable system has three layers:

| Layer | Scope | Purpose |
|------|--------|------|
| **Local variables** | Within the owning instruction sequence | Temporary intermediate values, passing arguments |
| **Scope variables** | Execution context (Trigger Scope, Custom ID, Target Node) | Cross-instruction data passing |
| **Global variables** | Global (game process lifetime) | Persistent game state across scenes |

This guide focuses on managing and persisting **Global variables**. For the full variable system see `01-variable-system-guide.md`.

---

## Quick Start

```
# 1. Create variable → 2. Set value → 3. Save → 4. Load

1. Configure resource_path: "user://save.tres" in the GlobalVariableAssistant
2. Place SetVariable → scope: GLOBAL, variable_name: "player_health", value: 100
3. Place SaveGlobalVariables → save_target: Assistant Resource
4. On next startup, LoadGlobalVariables → load_source: Assistant Resource
```

---

## Using GlobalVariableManager

> **⚠️ Singleton pattern**: `GlobalVariableManager` is based on `RefCounted` and is obtained via `GlobalVariableManager.get_instance()`. **Do not** use `new()` or `preload()`.

### Variable CRUD

| Method | Returns | Description |
|------|------|------|
| `get_instance()` | GlobalVariableManager | Get the singleton instance |
| `add_variable(name, variable)` | bool | Add a variable |
| `get_variable(name)` | BaseVariable | Get a variable; returns null if it does not exist |
| `has_variable(name)` | bool | Check whether a variable exists |
| `remove_variable(name)` | bool | Remove a variable |
| `get_all_variable_names()` | Array[String] | List of all variable names |
| `get_variable_count()` | int | Number of variables |
| `clear_all_variables()` | void | Clear all variables |

```gdscript
var gvm = GlobalVariableManager.get_instance()

# Create a global variable
var hp = BaseVariable.new()
hp.variable_name = "player_health"
hp.value = 100
hp.persistent = true
gvm.add_variable("player_health", hp)

# Read
var val = gvm.get_variable("player_health")
if val:
	print(val.value)  # 100

# Update (triggers signals automatically)
val.value = 80

# Delete
gvm.remove_variable("temp_var")
```

### Signal Listening

| Signal | Parameters | Description |
|------|------|------|
| `variable_added` | name, variable | A variable was added |
| `variable_removed` | name | A variable was removed |
| `variable_changed` | name, old_value, new_value | A variable's value changed |

```gdscript
var gvm = GlobalVariableManager.get_instance()
gvm.variable_changed.connect(func(name, old_val, new_val):
	print("[变化] %s: %s → %s" % [name, old_val, new_val])
)
```

### Debug Methods

| Method | Returns | Description |
|------|------|------|
| `get_debug_info()` | String | Total variable count, resource path, name/type/value of every variable |
| `get_statistics()` | Dictionary | `total_variables`, `persistent_variables`, `resource_path` |

---

## Persistence System

### SaveGlobalVariables (Save)

| Property | Type | Description |
|------|------|------|
| `save_target` | SaveTarget | `ASSISTANT_RESOURCE` (use the Assistant-configured path) or `CUSTOM_PATH` |
| `custom_path` | String | Custom path (effective when `save_target == CUSTOM_PATH`) |
| `save_scope` | SaveScope | `ALL` (everything) or `PERSISTENT_ONLY` (only variables flagged persistent) |

### LoadGlobalVariables (Load)

| Property | Type | Description |
|------|------|------|
| `load_source` | LoadSource | `ASSISTANT_RESOURCE` or `CUSTOM_PATH` |
| `custom_path` | String | Custom path |

### Manager-Level Methods

```gdscript
var gvm = GlobalVariableManager.get_instance()

# Save all variables to the given path
gvm.save_to_resource("user://save.tres")

# Load from a file (clears existing variables)
gvm.load_from_resource("user://save.tres")
```

---

## GlobalVariableResource

`GlobalVariableResource` is a `.tres` resource file that stores variable snapshots.

### Properties

| Property | Type | Description |
|------|------|------|
| `variables` | Dictionary | Mapping of variable name → variable data |
| `description` | String | Resource description |

Persisted data can be viewed and edited directly in the Inspector.

---

## GlobalVariableAssistant

> **⚠️ Singleton pattern**: `GlobalVariableAssistant` can be placed as a node in the scene tree (recommended), or its running instance can be obtained via `GlobalVariableAssistant.get_instance()`. **Do not** create it manually with `new()` and then add it via `add_child()`.

### Properties

| Property | Type | Default | Description |
|------|------|--------|------|
| `current_resource` | GlobalVariableResource | null | Currently bound resource file |
| `resource_path` | String | "" | Resource file path |
| `auto_save` | bool | true | Auto save on exit |
| `auto_load_on_ready` | bool | true | Auto load when ready |
| `cleanup_on_exit` | bool | true | Clean up non-persistent variables on exit |
| `auto_save_on_change` | bool | false | Auto save when variables change |
| `auto_save_delay` | float | 1.0 | Auto save delay in seconds |

### Signals

| Signal | Parameters | Description |
|------|------|------|
| `resource_changed` | old_resource, new_resource | The resource file was switched |
| `variable_added` | name, variable_data | A variable was added |
| `variable_removed` | name | A variable was removed |
| `variable_modified` | name, old_data, new_data | A variable was modified |
| `save_completed` | success, path | Save completed |
| `load_completed` | success, path, resource | Load completed |

---

## Complete Examples

### Multiple Save Slots

```
Trigger: SaveToSlot1 (hotkey S)
├── SetVariable
│   variable_name: "current_save_slot"
│   value: "user://saves/slot_01.tres"
│   scope: GLOBAL
├── SaveGlobalVariables
│   save_target: CUSTOM_PATH
│   custom_path: "user://saves/slot_01.tres"
│   save_scope: PERSISTENT_ONLY
└── LogInstruction
    message: "已保存到存档槽 1"

Trigger: LoadFromSlot1 (hotkey L)
├── LoadGlobalVariables
│   load_source: CUSTOM_PATH
│   custom_path: "user://saves/slot_01.tres"
└── LogInstruction
    message: "已从存档槽 1 加载"
```

### Auto Save (Assistant Configuration)

Add a `GlobalVariableAssistant` node to the scene and set:
- `resource_path` → `"user://saves/autosave.tres"`
- `auto_save` → `true`
- `auto_save_on_change` → `false` (triggering saves manually via instructions is recommended)
- `auto_load_on_ready` → `true`

### Sharing State Across Scenes

```
# Scene A: set player properties
SetVariable → scope: GLOBAL, name: "player_health", value: 100
SetVariable → scope: GLOBAL, name: "player_score", value: 0

# Read in scene B after switching scenes
CompareVariable → variable_name: "player_health", operator: LESS_THAN, value: 30
    └── (triggers a low-health warning)
```

---

## Marking Variables as Persistent

Only variables marked `persistent = true` are saved under the `PERSISTENT_ONLY` scope.

```gdscript
var gvm = GlobalVariableManager.get_instance()

# Mark as persistent
var score = BaseVariable.new()
score.variable_name = "score"
score.value = 0
score.persistent = true
gvm.add_variable("score", score)

# Non-persistent temporary variable
var timer = BaseVariable.new()
timer.variable_name = "cooldown_timer"
timer.value = 0
timer.persistent = false
gvm.add_variable("cooldown_timer", timer)
```

---

## Debugging and Monitoring

```gdscript
var gvm = GlobalVariableManager.get_instance()

# Print debug info for all variables
print(gvm.get_debug_info())

# Get statistics
var stats = gvm.get_statistics()
print("总变量: %d, 持久化: %d" % [stats.total_variables, stats.persistent_variables])

# Monitor all changes
gvm.variable_changed.connect(func(name, old_val, new_val):
	push_error("[监控] %s: %s → %s" % [name, old_val, new_val])
)

# Export state
func export_state() -> Dictionary:
	var state = {}
	for name in gvm.get_all_variable_names():
		var v = gvm.get_variable(name)
		if v:
			state[name] = {"value": v.value, "persistent": v.persistent}
	return state
```

---

## Best Practices

### Naming Conventions
- Use `snake_case`: `player_health`, `current_level`
- Avoid special characters, spaces, and leading digits

### Initialization Pattern
```gdscript
func _ready():
	var gvm = GlobalVariableManager.get_instance()
	if not gvm.has_variable("player_health"):
		var v = BaseVariable.new()
		v.variable_name = "player_health"
		v.value = 100
		v.persistent = true
		gvm.add_variable("player_health", v)
```

### Save Strategy
- Use `PERSISTENT_ONLY` to avoid saving temporary state (cooldown timers, etc.)
- Save only at key points (after a cutscene, before exit, manual saves)
- Cache the `get_instance()` return value to avoid frequent calls

### Performance Optimization
- `auto_save_on_change` is off by default; it is costly with high-frequency changes
- Use persistent flags sensibly to control save size

---

## Troubleshooting

| Problem | Cause | Solution |
|------|------|----------|
| File not found | The save file was not created before loading | Save before loading, or check whether the file exists |
| Invalid path | Malformed custom path | Use the `user://saves/xxx.tres` format |
| Insufficient permissions | Cannot write to the directory | Make sure the `user://saves/` directory exists |
| Variable is null | Not initialized or already deleted | Pre-check with `has_variable()` |

---

**Related docs:**
- [Variable System Guide](01-variable-system-guide.md)
- [Scene Management Guide](17-scene-management-guide.md)
