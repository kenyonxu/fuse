> 🌐 [**中文版**](../../../zh_CN/dev_docs/guides/object-pool-guide.md) | English

# Fuse Object Pool System Development Guide

> **Goal**: Provide developers with a complete development guide to the Fuse object pool system, covering pooled instance management, scene instance reuse, and state resets for triggers and variables.

**Audience**: Fuse system developers, contributors

**Last updated**: 2026-07-07

---

## 📋 Table of Contents

1. [System Overview](#system-overview)
2. [Architecture Design](#architecture-design)
3. [FuseObjectPool API](#fuseobjectpool-api)
4. [FusePoolItem API](#fusepoolitem-api)
5. [FusePoolManager API](#fusepoolmanager-api)
6. [Usage Guide](#usage-guide)
7. [State Reset Mechanism](#state-reset-mechanism)
8. [Performance Monitoring](#performance-monitoring)
9. [Best Practices](#best-practices)
10. [Common Pitfalls](#common-pitfalls)

---

## System Overview

The object pool system is the key infrastructure in Fuse for managing scene instance reuse, providing a complete pipeline from the **single object pool (FuseObjectPool)** to the **global pool manager (FusePoolManager)**.

### Core Files

| File | Class | Purpose |
|------|------|------|
| `core/pooling/fuse_object_pool.gd` | `FuseObjectPool` | Generic object pool managing the instance pool of a single scene |
| `core/pooling/fuse_pool_item.gd` | `FusePoolItem` | Pool item wrapper tracking usage state and efficiency |
| `core/pooling/fuse_pool_manager.gd` | `FusePoolManager` | Global pool manager with a unified interface |
| `core/pooling/instruction_instance_pool.gd` | `InstructionInstancePool` | Dedicated pool for instruction instances |

### Design Goals

- **Reduce instantiation overhead**: reuse created objects instead of frequent `instantiate()` / `queue_free()`
- **Automatic grow/shrink**: adjust pool size dynamically based on usage
- **State reset**: automatically reset Fuse components (Trigger, ScopeVariableContainer, ActionRunner) when objects are recycled
- **Unified management**: access all pools through the `FusePoolManager` singleton
- **Performance tracking**: integrates `FusePerformanceTracker` to monitor recycle performance

---

## Architecture Design

```
FusePoolManager (RefCounted singleton)
    │
    │  _scene_pools: Dictionary  {scene_path -> FuseObjectPool}
    │
    ├── FuseObjectPool (Scene A)
    │       ├── FusePoolItem (Node) — in_use = true/false
    │       ├── FusePoolItem (Node)
    │       └── ...
    │
    ├── FuseObjectPool (Scene B)
    │       ├── FusePoolItem (Node)
    │       └── ...
    │
    └── _active_recycle_timers: Array[FuseRecycleTimer]
```

### Instance Lifecycle

```
1. instantiate_pooled(scene_path)
       │  _get_or_create_pool() → get or create a FuseObjectPool
       ▼
2. pool.get_object()
       │  find an idle FusePoolItem → mark_used()
       │  or load the scene → create a new FusePoolItem → mark_used()
       ▼
3. parent.add_child(instance)
       ▼
4. pool.reset_object(instance)
       │  _reset_fuse_components()  ← recursively reset Triggers/variables
       ▼
5. In use...

6. recycle_pooled(scene_path, instance)
       ▼
7. pool.return_object(obj)
       │  _terminate_fuse_triggers(obj) → stop physics processing
       │  _schedule_safe_remove(obj)   → defer removal from the scene tree
       │  item.mark_unused()
       ▼
8. Awaiting reuse in the pool
```

---

## FuseObjectPool API

**File location**: `addons/fuse/core/pooling/fuse_object_pool.gd`

**Class definition**:
```gdscript
class_name FuseObjectPool extends RefCounted
```

### Constructor

```gdscript
## Create an object pool
## scene_path: scene file path
## initial_size: initial pool size (default 20, constrained by min/max)
func _init(scene_path: String, initial_size: int = 20) -> void
```

### Core Methods

```gdscript
## Get an object from the pool
## Returns: Node — the scene instance, or null when the pool is full and no object is available
func get_object() -> Node

## Return an object to the pool
## obj: the scene instance to return
func return_object(obj: Node) -> void

## Reset object state (basic properties + Fuse components)
func reset_object(obj: Node) -> void

## Warm up the pool by pre-creating count objects
func warm_up(count: int) -> void

## Clear the pool (release all objects)
func clear_pool() -> void
```

### Pool Configuration Methods

```gdscript
func set_pool_size(size: int) -> void             # Set the pool size
func set_max_pool_size(size: int) -> void          # Set the maximum pool size
func set_min_pool_size(size: int) -> void          # Set the minimum pool size
func enable_auto_resize(enabled: bool) -> void     # Enable/disable auto resizing
func set_resize_threshold(threshold: float) -> void # Set the resize threshold (0.1~1.0)
func process_auto_resize() -> void                 # Process auto grow/shrink
```

### Statistics Methods

```gdscript
func get_statistics() -> Dictionary      # Get statistics
func get_detailed_status() -> Dictionary # Get detailed status (including per-item details)
```

The statistics dictionary contains:
```
- scene_path, total_created, total_reused
- pool_size, current_usage, unused_count
- peak_usage, reuse_ratio, efficiency_score
- auto_resize, resize_threshold
```

### Key Internal Methods

```gdscript
func _load_scene() -> Node                          # Load and instantiate the scene
func _reset_fuse_components(node: Node) -> void     # Recursively reset Fuse components
func _terminate_fuse_triggers(node: Node) -> void   # Stop all Triggers
func _schedule_safe_remove(obj: Node) -> void       # Deferred removal (avoids physics callback conflicts)
func _adjust_pool_size() -> void                    # Adjust the pool size (remove inefficient objects)
```

---

## FusePoolItem API

**File location**: `addons/fuse/core/pooling/fuse_pool_item.gd`

**Class definition**:
```gdscript
class_name FusePoolItem extends RefCounted
```

### Properties

```gdscript
var object: Node         # The pooled object
var in_use: bool         # In-use flag
var pool_item_id: int    # Unique ID (auto-increment)
var created_time: float  # Creation timestamp
var last_used_time: float # Last-used timestamp
var usage_count: int     # Usage counter
```

### Methods

```gdscript
func mark_used() -> void                    # Mark as in use
func mark_unused() -> void                  # Mark as unused
func is_valid() -> bool                     # Check whether the object is valid
func is_expired(max_idle_time: float) -> bool  # Check whether the item has expired
func get_efficiency_score() -> float        # Efficiency score = usage count / lifetime
static func compare_by_efficiency(a, b) -> bool  # Sorting comparator

func get_statistics() -> Dictionary         # Get statistics
func set_debug_logging(enabled: bool, pool_path: String = "") -> void
```

### Efficiency Score

```gdscript
# Efficiency = usage_count / age(seconds)
# Used to decide which objects to keep when shrinking the pool: frequently used objects are kept first
```

---

## FusePoolManager API

**File location**: `addons/fuse/core/pooling/fuse_pool_manager.gd`

**Class definition**:
```gdscript
class_name FusePoolManager extends RefCounted
```

### Singleton

```gdscript
## Get the singleton
static func get_instance() -> FusePoolManager
```

### Core Methods

```gdscript
## Instantiate a scene from the pool and add it to a parent node
## Returns: Node — the scene instance, or null on failure
func instantiate_pooled(scene_path: String, parent: Node, pool_config: Dictionary = {}) -> Node

## Get an instance from the pool without adding it to the scene tree (deferred addition)
## Returns: Dictionary — {"instance": Node, "pool": FuseObjectPool}
func get_pooled_instance(scene_path: String, pool_config: Dictionary = {}) -> Dictionary

## Recycle a scene instance
## Returns: bool — success/failure
func recycle_pooled(scene_path: String, instance: Node) -> bool

## Warm up the pool of a scene
func warm_up_pool(scene_path: String, count: int, pool_config: Dictionary = {}) -> void

## Clear all pools
func clear_all_pools() -> void
```

### Query Methods

```gdscript
func is_instance_in_use(scene_path: String, instance: Node) -> bool  # Check whether an instance is in use
func get_instance_usage_count(scene_path: String, instance: Node) -> int  # Get the usage count
func get_statistics(scene_path: String = "") -> Dictionary  # Get statistics
func get_detailed_status() -> Dictionary  # Get detailed status
```

### Pool Lookup Strategy

When recycling, `recycle_pooled()` looks up the pool in the following order:

1. Get the path from the instance's `scene_file_path`
2. Exact match against the `_scene_pools` dictionary
3. Search all pools by instance ID (`_find_pool_by_instance_id`)
4. Match by file name (`_find_pool_by_any_path`)

### Registering/Unregistering Recycle Timers

```gdscript
func register_recycle_timer(timer: FuseRecycleTimer) -> void
func unregister_recycle_timer(timer: FuseRecycleTimer) -> void
```

---

## Usage Guide

### Basic Usage

```gdscript
# Get the FusePoolManager singleton
var pool_manager = FusePoolManager.get_instance()

# Instantiate a scene from the pool
var bullet = pool_manager.instantiate_pooled(
    "res://scenes/bullet.tscn",
    get_parent(),
    {"initial_size": 10, "max_size": 50}
)

# Recycle after use
pool_manager.recycle_pooled("", bullet)  # When scene_path is empty it is derived from the instance automatically
```

### Pool Warm-Up

```gdscript
# Warm up during game loading
pool_manager.warm_up_pool("res://scenes/enemy.tscn", 20)
```

### Deferred Addition to the Scene Tree

```gdscript
# Get an instance without adding it to the scene tree
var result = pool_manager.get_pooled_instance("res://scenes/particle.tscn")
if result.has("instance"):
    var particle = result["instance"]
    # Add it at the right moment
    call_deferred("add_child", particle)
```

---

## State Reset Mechanism

`reset_object()` and `_reset_fuse_components()` are responsible for restoring objects to their initial state.

### Basic Property Reset

```gdscript
# Node2D
obj.position = Vector2.ZERO
obj.rotation = 0.0
obj.scale = Vector2.ONE
obj.visible = true

# Node3D
obj.position = Vector3.ZERO
obj.rotation = Vector3.ZERO
obj.scale = Vector3.ONE
obj.visible = true

# Physics bodies
obj.set_linear_velocity(Vector2.ZERO / Vector3.ZERO)
obj.set_angular_velocity(0.0)

# Colors
obj.modulate = Color.WHITE
obj.self_modulate = Color.WHITE
```

### Recursive Reset of Fuse Components

```gdscript
# Walk the node tree:
# 1. Trigger → pool_reset() or reset()
# 2. MultiEventTrigger → pool_reset() or reset()
# 3. ScopeVariableContainer → save/restore _pool_default_variables
```

### Trigger Termination on Recycle

```gdscript
# Inside return_object():
# 1. _terminate_fuse_triggers(obj)
#    - stop physics processing (set_physics_process(false))
#    - call event_definition.terminate(trigger)
# 2. _schedule_safe_remove(obj) — deferred removal by one frame
```

---

## Performance Monitoring

### Auto Grow/Shrink

```gdscript
# Usage > 80% → pool size * 2 (auto grow)
# Usage < 40% → pool size / 2 (auto shrink)
# When shrinking, objects are sorted by efficiency score and low-frequency objects are removed
```

### Statistics Metrics

```gdscript
# Key metrics
reuse_ratio = total_reused / total_created
efficiency_score = reuse ratio*0.4 + utilization*0.3 + peak rate*0.2
```

### Debug Logging

```gdscript
pool_manager.set_debug_logging(true)
# Output: creation, reuse, recycle, grow and other events
```

---

## Best Practices

### 1. Choose the Initial Pool Size Based on Instance Type

```gdscript
# Frequently created objects (e.g. bullets) → larger initial pool
pool_cfg = {"initial_size": 30, "max_size": 100}

# Infrequently used objects → smaller initial pool
pool_cfg = {"initial_size": 5, "max_size": 20}
```

### 2. Warm Up During the Loading Phase

```gdscript
# Warm up while the scene loads to avoid runtime stutter
pool_manager.warm_up_pool("res://scenes/enemy_wave.tscn", 10)
```

### 3. Keep Triggers in the Scene Tree Clean

The object pool automatically terminates Triggers on recycle, ensuring that Triggers leaving the scene tree stop emitting events.

### 4. Leverage UID Paths

Both `res://` and `uid://` paths can manage pools. `recycle_pooled()` supports deriving the path automatically from the instance's `scene_file_path`.

---

## Common Pitfalls

### Pitfall 1: Recycling Objects Inside Physics Callbacks

**Problem**: Calling `remove_child()` directly inside `_physics_process()` causes state corruption.

**Solution**: `_schedule_safe_remove()` uses a `SceneTreeTimer` to defer removal by one frame.

### Pitfall 2: Stale State Because Objects Are Not Reset

**Problem**: Reused objects keep state from their previous use (position, visibility, Trigger activation).

**Solution**: `reset_object()` calls `_reset_fuse_components()` to recursively reset all Fuse components.

### Pitfall 3: Pool Lookup Failure

**Problem**: `recycle_pooled()` cannot find the corresponding pool.

**Solution**: `_find_pool_by_instance_id()` is used as a fallback strategy. If the passed-in `scene_path` differs from the path used at creation, it is derived automatically from the instance's `scene_file_path`.

### Pitfall 4: Unbounded Growth

**Problem**: When `auto_resize` is enabled, the pool size may grow without limit during traffic peaks.

**Solution**: Always set a reasonable `max_pool_size` cap.

---

## Reference Documents

- [ActionRunner Development Guide](action-runner-guide.md)
- [RuntimeInstructionInstance Guide](runtime-instruction-instance-guide.md)
- [ExecutionContext and Diagnostics Guide](execution-context-diagnostics-guide.md)

---

**Document maintainer**: Fuse development team | **Last updated**: 2026-07-07 | **Godot version**: 4.7
