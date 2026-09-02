> 🌐 [**中文版**](../../../zh_CN/user_docs/guides/30-lifecycle-events-guide.md) | English

# Lifecycle Events Guide

## Overview

Lifecycle events fire at points in a node's lifecycle, covering the entire span from scene readiness to exit. There are **7 events** in total, located in the `events/lifecycle/` directory.

| Event | class_name | Trigger timing | Frequency | Performance impact |
|------|-----------|----------|----------|----------|
| OnReady | OnReady | After the scene tree is ready (`_ready()`) | Once | Low |
| OnEnterTree | OnEnterTree | Node enters the scene tree (`tree_entered`) | Once | Low |
| OnExitTree | OnExitTree | Node exits the scene tree (`tree_exiting`) | Once | Low |
| OnProcess | OnProcess | Every frame (`_process(delta)`) | Every frame | ⚠️ High |
| OnPhysicsProcess | OnPhysicsProcess | Every physics frame (`_physics_process(delta)`) | Fixed rate (default 60 FPS) | ⚠️ High |
| OnInterval | OnInterval | At a fixed time interval | Configurable | Medium |
| OnIntervalWithVariable | OnIntervalWithVariable | Interval determined dynamically by a variable | Configurable | Medium |

---

## One-Shot Events

### OnReady

**File:** `events/lifecycle/on_ready.gd`
**class_name:** OnReady

Maps to Godot's `_ready()` callback. Fires as soon as the scene tree is ready; suitable for **initialization logic**.

| Parameter | Type | Default | Description |
|------|------|--------|------|
| `delay_seconds` | float | 0.0 | Seconds to delay the trigger |

**Example:** initialize health, bind signals, load config

```
OnReady
└── SetVariable
    variable_name: "player_health"
    value: 100
    scope: GLOBAL
```

### OnEnterTree

**File:** `events/lifecycle/on_enter_tree.gd`
**class_name:** OnEnterTree

Maps to the `tree_entered` signal. Fires when the node enters the scene tree, **earlier than OnReady**.

**Differences from OnReady:**
- `OnEnterTree` fires immediately when the node joins the scene tree; the parent node may not be ready yet
- `OnReady` guarantees the whole scene tree is ready before firing, which is safer
- In most cases use `OnReady`

| Parameter | Type | Description |
|------|------|------|
| — | — | No parameters |

### OnExitTree

**File:** `events/lifecycle/on_exit_tree.gd`
**class_name:** OnExitTree

Maps to the `tree_exiting` signal. Fires when the node is about to exit the scene tree; suitable for **resource cleanup**.

| Parameter | Type | Default | Description |
|------|------|--------|------|
| `cleanup_resources` | bool | false | Whether to automatically clean up held resource references |

**Example:** save game progress, disconnect signals, release resources

```
OnExitTree
├── SaveGlobalVariables
│   save_target: Assistant Resource
│   save_scope: PERSISTENT_ONLY
└── LogInstruction
    message: "场景退出，数据已保存"
```

---

## Frame Loop Events

### OnProcess

**File:** `events/lifecycle/on_process.gd`
**class_name:** OnProcess

Maps to `_process(delta)`. Fires **every frame**; used for continuous checks and updates.

> **⚠️ Performance warning:** OnProcess fires every frame and has an extreme performance impact. Always set `execution_interval` to lower the frequency.

| Parameter | Type | Default | Description |
|------|------|--------|------|
| `execution_interval` | float | 0.016 | Execution interval (seconds); defaults to 0.016 (about 60 FPS); set to 0 for every-frame execution |

**Recommendations:**
- Use `OnInterval` instead for continuous checks (more controllable)
- When you must use OnProcess, set `execution_interval ≥ 0.1` (at most 10 times per second)

### OnPhysicsProcess

**File:** `events/lifecycle/on_physics_process.gd`
**class_name:** OnPhysicsProcess

Maps to `_physics_process(delta)`. Fires every **physics frame** at a fixed rate (default 60 FPS). Suitable for physics-related updates.

| Parameter | Type | Default | Description |
|------|------|--------|------|
| `execution_interval` | int | 0 | Execution interval (physics frames); 0 = every physics frame |

**Recommendations:**
- For physical movement / force control, combine `OnPhysicsProcess` + `MoveCharacterBody` (movement system)
- `execution_interval` counts physics frames; set `2` = execute every 2 physics frames (about 30 FPS)

---

## Interval Events

### OnInterval

**File:** `events/lifecycle/on_interval.gd`
**class_name:** OnInterval

Fires periodically at a fixed time interval. More controllable and more performant than `OnProcess`.

| Parameter | Type | Default | Description |
|------|------|--------|------|
| `interval_seconds` | float | 1.0 | Trigger interval (seconds) |
| `max_repeats` | int | 0 | Maximum trigger count (0 = unlimited) |
| `auto_start` | bool | true | Whether to start automatically |
| `trigger_on_start` | bool | false | Trigger once immediately on start |

**Example:** check the player's state every 5 seconds

```
OnInterval → interval_seconds: 5.0, max_repeats: 0
└── CheckNodeProperty
    target_node: Player
    property_name: "health"
    operator: LESS_THAN
    value: 30
    └── (triggers low-HP handling)
```

### OnIntervalWithVariable

**File:** `events/lifecycle/on_interval_with_variable.gd`
**class_name:** OnIntervalWithVariable

Same as `OnInterval`, but the interval value is read dynamically from a **variable** and can change at runtime. Inherits all `OnInterval` parameters.

| Parameter | Type | Default | Description |
|------|------|--------|------|
| `variable_name` | String | "interval" | Name of the variable holding the interval value |
| `variable_scope` | VariableScope | LOCAL | Variable scope (Local/Scope/Global) |
| `default_interval` | float | 1.0 | Default interval used when the variable is missing or invalid |
| `initialize_variable` | bool | true | Whether to automatically set the variable's default value on initialization |
| `max_repeats` | int | 0 | Maximum trigger count (0 = unlimited) |
| `auto_start` | bool | true | Whether to start automatically |
| `trigger_on_start` | bool | false | Trigger immediately on start |

---

## Performance Tier Recommendations

| Event | Performance tier | Usage advice |
|------|---------|----------|
| **OnReady** | ✅ Low | Use freely |
| **OnEnterTree** | ✅ Low | Use in special cases |
| **OnExitTree** | ✅ Low | A must for cleanup scenarios |
| **OnInterval** | ⚠️ Medium | Set the interval as needed; recommended ≥ 0.1s |
| **OnIntervalWithVariable** | ⚠️ Medium | Ensure min_interval ≥ 0.033s |
| **OnProcess** | 🔴 High | Must set execution_interval |
| **OnPhysicsProcess** | 🔴 High | Only for physics updates; set execution_interval |

---

## Common Use Cases

### Initialization Logic (OnReady)

```
OnReady → delay_seconds: 0.5
├── SetVariable → scope: GLOBAL, name: "game_started", value: true
├── InstantiateScene → scene_path: "res://ui/hud.tscn", parent_node: "/root/Game/UI"
└── LogInstruction → message: "游戏初始化完成"
```

### Continuous Checking (OnInterval Instead of OnProcess)

```
OnInterval → interval_seconds: 2.0, max_repeats: 0
├── CheckDistance → target_a: Player, target_b: Enemy, operator: LESS_THAN, value: 10.0
│   └── (enemy approaches the player, triggers combat)
└── LogInstruction → message: "正在扫描敌人..."
```

### Physics-Frame-Synced Updates (OnPhysicsProcess + MoveCharacterBody)

```
OnPhysicsProcess → execution_interval: 0
└── MoveCharacterBody
    target_node: Player
    direction: {scope:input_direction}
    speed: 300.0
```

---

## Notes

1. **OnProcess performance**: fires every frame; complex instruction chains cause severe frame drops. If `OnInterval` can do the job, do not use `OnProcess`.
2. **PhysicsProcess default rate**: 60 FPS; `execution_interval = 1` is equivalent to 30 FPS.
3. **OnExitTree cleanup**: resources referenced by signals must be disconnected manually, otherwise memory leaks are possible.
4. **OnEnterTree timing**: earlier than OnReady; some child nodes may not be ready yet. In most cases OnReady is enough.
