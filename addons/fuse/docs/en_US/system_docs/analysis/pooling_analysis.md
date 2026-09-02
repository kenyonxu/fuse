> 🌐 [**中文版**](../../../zh_CN/system_docs/analysis/pooling_analysis.md) | English

# Object Pool System Analysis Report


> **Analyzed as of**: 2026-07-07 (each article verified against code during the same-day full documentation audit; implementation evolution after this point defers to the source code; for recently verified mechanical conclusions see the threading / runtime_instance / preset_nested articles)
## Document Overview

This report describes the current state of the object pool subsystem in the Fuse visual programming system. The pools live in `core/pooling/` and consist of 5 classes: the generic scene pool (`FuseObjectPool`), the pool-item wrapper (`FusePoolItem`), the global pool manager (`FusePoolManager`), the dedicated recycle timer (`FuseRecycleTimer`), and the instruction instance pool for `RuntimeInstructionInstance` (`InstructionInstancePool`). The two pool systems respectively serve "scene node reuse" (bullets, effects, etc.) and "instruction runtime instance reuse" (memory optimization on high-frequency execution paths), each with its own pooling strategy, lifecycle, and collaborating objects.

**Source directory:** [core/pooling/](../../../../core/pooling/)
**Class count:** 5
**Total lines:** 1498 lines
**Integrators:** `RuntimeActionRunnerInstance` (instruction instance pool); the `instantiate_scene`/`recycle_pooled_scene`/`warm_up_pool` instructions (scene pool)

---

## 1. Class Inventory and Responsibilities

| Class | File | Lines | Base class | Responsibilities |
|------|------|------|------|------|
| `FusePoolItem` | [fuse_pool_item.gd](../../../../core/pooling/fuse_pool_item.gd) | 140 | `RefCounted` | Pool-item wrapper; tracks a single object's in_use/usage_count/timestamps, provides efficiency scoring and expiry detection |
| `FuseObjectPool` | [fuse_object_pool.gd](../../../../core/pooling/fuse_object_pool.gd) | 597 | `RefCounted` | Generic scene object pool; handles instance creation/reuse/recycling/reset/shrink for a single scene path |
| `FusePoolManager` | [fuse_pool_manager.gd](../../../../core/pooling/fuse_pool_manager.gd) | 528 | `RefCounted` | Global singleton; indexes multiple `FuseObjectPool`s by `scene_path`, provides the `instantiate_pooled`/`recycle_pooled` entries, multi-strategy path matching, and manages recycle-timer lifecycle |
| `FuseRecycleTimer` | [fuse_recycle_timer.gd](../../../../core/pooling/fuse_recycle_timer.gd) | 148 | `Node` | Dedicated delayed-recycle timer; weak-ref instance + usage_count consistency validation + multiple "already recycled" detections, invoking the manager to recycle on timeout |
| `InstructionInstancePool` | [instruction_instance_pool.gd](../../../../core/pooling/instruction_instance_pool.gd) | 185 | `RefCounted` | Dedicated pool for `RuntimeInstructionInstance`; achieves high-frequency execution path reuse via `acquire`/`release` paired with `reinitialize`/`reset_for_pool` |

---

## 2. Core Properties

### 2.1 FuseObjectPool ([fuse_object_pool.gd:7-23](../../../../core/pooling/fuse_object_pool.gd))

| Property | Type | Default | Description |
|------|------|--------|------|
| `_pool_items` | `Array[FusePoolItem]` | `[]` | Pool item collection |
| `_scene_path` | `String` | `""` | Bound scene path |
| `_pool_size` | `int` | `20` | Target pool size |
| `_max_pool_size` | `int` | `100` | Pool capacity ceiling |
| `_min_pool_size` | `int` | `5` | Pool capacity floor |
| `_auto_resize` | `bool` | `true` | Whether auto resizing is enabled |
| `_resize_threshold` | `float` | `0.8` | Usage threshold for expansion |
| `_total_created/_total_reused/_peak_usage/_cleanup_count` | `int` | `0` | Statistics counters |
| `_enable_debug` | `bool` | `false` | Debug log switch |

### 2.2 FusePoolItem ([fuse_pool_item.gd:8-30](../../../../core/pooling/fuse_pool_item.gd))

| Property | Type | Description |
|------|------|------|
| `object` | `Node` | Pooled object reference |
| `in_use` | `bool` | In-use flag |
| `pool_item_id` | `int` | Unique ID (`_next_id` static increment, starting from 1) |
| `created_time` / `last_used_time` | `float` | Timestamps (seconds) |
| `usage_count` | `int` | Cumulative times marked used |
| `_next_id` (static) | `int` | Global ID generator |

### 2.3 FusePoolManager ([fuse_pool_manager.gd:7-23](../../../../core/pooling/fuse_pool_manager.gd))

| Property | Type | Description |
|------|------|------|
| `_instance` (static) | `FusePoolManager` | Singleton instance (lazily loaded via `get_instance()`) |
| `_scene_pools` | `Dictionary` | `scene_path → FuseObjectPool` index table |
| `_active_recycle_timers` | `Array[FuseRecycleTimer]` | Strong-reference set of active timers (prevents premature RefCounted release) |
| `_enable_debug` | `bool` | Debug log switch |

### 2.4 FuseRecycleTimer ([fuse_recycle_timer.gd:9-25](../../../../core/pooling/fuse_recycle_timer.gd))

| Property | Type | Description |
|------|------|------|
| `scene_path` | `String` | Associated scene path |
| `_instance_weak_ref` | `WeakRef` | Weak reference to the instance (avoids reference cycles) |
| `_creation_usage_count` | `int` | usage_count recorded at creation, used to detect whether the object has been reused |
| `_timer` | `SceneTreeTimer` | Underlying Godot timer |
| `_triggered` | `bool` | Re-entry guard flag |

### 2.5 InstructionInstancePool ([instruction_instance_pool.gd:9-25](../../../../core/pooling/instruction_instance_pool.gd))

| Property | Type | Default | Description |
|------|------|--------|------|
| `_pool` | `Array[RuntimeInstructionInstance]` | `[]` | Idle instance stack (popped via `pop_back`) |
| `_pool_size` | `int` | `32` | Target pool size |
| `_max_pool_size` | `int` | `128` | Pool capacity ceiling |
| `_total_created/_total_reused/_peak_usage` | `int` | `0` | Statistics counters |
| `_current_usage` | `int` | `0` | Instances currently loaned out and not yet returned |
| `_default_log_level` | `FuseLogger.LogLevel` | `INFO` | Default log level for pooled instances |

---

## 3. Core APIs

### 3.1 FusePoolItem (pool item interface)

| Method | Signature | Description |
|------|------|------|
| `mark_used()` | `() -> void` | Sets `in_use=true`, refreshes `last_used_time`, `usage_count += 1` |
| `mark_unused()` | `() -> void` | Sets `in_use=false` |
| `is_valid()` | `() -> bool` | `object != null and is_instance_valid(object)` |
| `is_expired(max_idle_time)` | `(float) -> bool` | Returns false while in use; true once idle beyond the threshold |
| `get_efficiency_score()` | `() -> float` | `usage_count / age` (usage frequency) |
| `compare_by_efficiency(a, b)` | `static (FusePoolItem, FusePoolItem) -> bool` | Sort comparator, descending by efficiency |

### 3.2 FuseObjectPool (scene pool core APIs)

**Acquire/return:**

| Method | Signature | Description |
|------|------|------|
| `get_object()` | `() -> Node` | Prefers an idle item; otherwise creates and wraps via `_load_scene()` within capacity; warns and returns null when full |
| `return_object(obj)` | `(Node) -> void` | Terminates Trigger/MultiEventTrigger processing in the subtree → deferred removal from the scene tree → `mark_unused`; unmatched objects get a new pool item appended |
| `reset_object(obj)` | `(Node) -> void` | Calls `obj.reset()` (if present) → recursive `_reset_fuse_components` → resets transform/visible/velocity/modulate |

**Configuration:**

| Method | Description |
|------|------|
| `_init(scene_path, initial_size=20)` | Initializes and clamps to `[_min_pool_size, _max_pool_size]` |
| `warm_up(count)` | Pre-creates idle instances (`mark_unused`) |
| `set_pool_size/set_max_pool_size/set_min_pool_size` | Capacity configuration, triggers `_adjust_pool_size()` |
| `enable_auto_resize(enabled)` / `set_resize_threshold(threshold)` | Auto-resize switch and threshold (threshold clamped to `[0.1, 1.0]`) |
| `process_auto_resize()` | Expands to `min(size*2, max)` when usage `> threshold`; shrinks to `max(size/2, min)` when `< threshold*0.5` |
| `clear_pool()` | `queue_free`s all objects and zeroes statistics |

**Fuse component reset ([fuse_object_pool.gd:236-291](../../../../core/pooling/fuse_object_pool.gd)):**

`_reset_fuse_components(node)` walks the entire subtree with an iterative stack, handling in order:
- `Trigger`: prefers `pool_reset()`, otherwise `reset()` + `set_physics_process(true)` + `set_process(true)`
- `MultiEventTrigger`: same strategy
- `ScopeVariableContainer` detection (`variables` field + `get_variable` method): the first reset saves `_pool_default_variables`; later resets write the defaults back

`_terminate_fuse_triggers(node)` ([:300-343](../../../../core/pooling/fuse_object_pool.gd)) stops all Trigger/MultiEventTrigger processing on return via `set_physics_process(false)` + `set_process(false)`, and calls `terminate()` on their `event_definition`/`event_bindings`.

### 3.3 FusePoolManager (global entry)

**Pooled scene APIs:**

| Method | Signature | Description |
|------|------|------|
| `get_instance()` | `static () -> FusePoolManager` | Lazily loaded singleton |
| `instantiate_pooled(scene_path, parent, pool_config={})` | `(...) -> Node` | Get object + `add_child` + `reset_object` (reset after entering the tree) |
| `get_pooled_instance(scene_path, pool_config={})` | `(...) -> Dictionary` | Returns `{"instance": Node, "pool": FuseObjectPool}` without attaching to the tree (for deferred attachment such as physics callbacks) |
| `recycle_pooled(scene_path, instance)` | `(String, Node) -> bool` | Resolves the path via multiple strategies (the instance's own `scene_file_path` → ID lookup → filename match → UID match), then returns the object |
| `warm_up_pool(scene_path, count, pool_config={})` | Warms up the given pool |
| `clear_all_pools()` | Clears all pools |
| `get_statistics(scene_path="")` | Empty string returns statistics for all pools, otherwise a single pool's |
| `get_detailed_status()` | Includes `total_pools`/`scene_paths`/`pool_statistics` |

**Recycle-timer collaboration APIs:**

| Method | Description |
|------|------|
| `register_recycle_timer(timer)` | Adds to the `_active_recycle_timers` strong-reference set |
| `unregister_recycle_timer(timer)` | Removes from the set when done |
| `is_instance_in_use(scene_path, instance)` | Queries the pool item's `in_use` flag |
| `get_instance_usage_count(scene_path, instance)` | Queries the pool item's `usage_count` (returns -1 if not found) |

**Path resolution strategies** ([fuse_pool_manager.gd:182-316](../../../../core/pooling/fuse_pool_manager.gd)): internally `recycle_pooled` tries `_find_pool_by_instance_id` → `_find_pool_by_any_path` in order (including `_get_resource_uid` converting `res://` to `uid://`), and hooks into `FusePerformanceTracker` performance tracking.

### 3.4 FuseRecycleTimer (delayed recycle)

| Method | Signature | Description |
|------|------|------|
| `create(scene_path, instance, delay)` | `static (...) -> FuseRecycleTimer` | Factory: records `_creation_usage_count` + registers with the manager + `_setup_timer` |
| `cancel()` | `() -> void` | Disconnects the timeout connection, sets `_triggered=true`, unregisters |
| `_on_timeout()` | internal | After multiple validations (weak-ref validity, instance validity, usage_count consistency, inside tree, still in_use), invokes `recycle_pooled` |
| `_cleanup_and_remove()` | internal | `cancel()` + removal from the parent node + `queue_free()` |

### 3.5 InstructionInstancePool (instruction instance pool)

| Method | Signature | Description |
|------|------|------|
| `_init(initial_size=32, max_size=128)` | Clamps to `[8, max_size]` |
| `acquire(instruction, context, runner)` | `(...) -> RuntimeInstructionInstance` | When the pool is non-empty, `pop_back` + `reinitialize` reuse; otherwise `new`; tracks `_total_reused/_total_created/_current_usage/_peak_usage` |
| `release(instance)` | `(RuntimeInstructionInstance) -> void` | Calls `instance.reset_for_pool()` then pushes back onto the stack (dropped for GC when full) |
| `release_all(instances)` | Batch return |
| `warm_up(count)` | Pre-creates `RuntimeInstructionInstance.new(null, null, null)` placeholders |
| `clear()` | Clears and resets statistics |
| `set_default_log_level(level)` | Sets the default log level for pooled instances |

---

## 4. Architectural Relationships

### 4.1 Class inheritance/composition

```
RefCounted
├── FusePoolItem          (pool item wrapper)
├── FuseObjectPool        (single scene pool, composes multiple FusePoolItems)
├── FusePoolManager       (singleton, composes multiple FuseObjectPools + multiple FuseRecycleTimers)
└── InstructionInstancePool (independent system, pools RuntimeInstructionInstances)

Node
└── FuseRecycleTimer      (lifecycle managed by Godot, strong-referenced by FusePoolManager._active_recycle_timers)
```

### 4.2 Scene pool system data flow

```
Caller (instructions / game code)
   │
   ├── instantiate_pooled(scene_path, parent, config)
   │       │
   │       ▼
   │   FusePoolManager._get_or_create_pool  ──( miss )──▶  new FuseObjectPool
   │       │                                              registered into _scene_pools[scene_path]
   │       ▼
   │   FuseObjectPool.get_object  ──( reuse )──▶  FusePoolItem.mark_used
   │       │            └─( miss )──▶ _load_scene → instantiate → new FusePoolItem
   │       ▼
   │   parent.add_child(instance)
   │   FuseObjectPool.reset_object  ──▶ _reset_fuse_components(Trigger/MultiEventTrigger/ScopeVariableContainer)
   │
   └── recycle_pooled(scene_path, instance)
           │
           ▼
       multi-strategy path resolution (instance_id / filename / uid)
           │
           ▼
       FuseObjectPool.return_object
           ├── _terminate_fuse_triggers  (set_physics_process(false) + event.terminate)
           ├── _schedule_safe_remove     (deferred remove_child)
           └── FusePoolItem.mark_unused
```

### 4.3 Delayed recycle chain

```
FuseRecycleTimer.create(scene_path, instance, delay)
   ├── pool_manager.get_instance_usage_count → records _creation_usage_count
   ├── pool_manager.register_recycle_timer   → joins _active_recycle_timers
   └── SceneTree.create_timer(delay).timeout → _on_timeout

_on_timeout five-fold validation:
   1. _triggered re-entry guard
   2. _instance_weak_ref.get_ref() non-null
   3. is_instance_valid(instance)
   4. current usage_count == _creation_usage_count (prevents mis-recycling after the object was reused)
   5. instance.is_inside_tree() and pool_manager.is_instance_in_use() == true

All pass    → pool_manager.recycle_pooled(scene_path, instance)
Any failure → _cleanup_and_remove (cancel timer + queue_free)
```

### 4.4 Instruction instance pool integration with RuntimeActionRunnerInstance

`InstructionInstancePool` and `RuntimeActionRunnerInstance` collaborate through a **shared static instance** pattern ([runtime_action_runner_instance.gd:51-61, 377-399](../../../../core/runtime_action_runner_instance.gd)):

| Component | Field/method | Lines | Description |
|------|-----------|------|------|
| `RuntimeActionRunnerInstance` | `use_instruction_pool: bool = true` | L52 | Can be disabled to roll back to non-pooled mode |
| Same as above | `_shared_instruction_pool: RefCounted` (static) | L55 | The globally unique pool instance, type-erased to `RefCounted` to avoid circular dependency |
| Same as above | `get_shared_pool()` (static) | L58-61 | Lazily loads `InstructionInstancePool.new(32, 128)` |
| Same as above | `_acquire_instruction_instance(...)` | L394-399 | When `use_instruction_pool` is true, `pool.acquire(instruction, context, self)`; otherwise `RuntimeInstructionInstance.new(...)` |
| Same as above | Cleanup path | L378-382 | When `use_instruction_pool` is true, iterates `_instruction_instances` calling `pool.release(runtime_instruction)` |

**Matching RuntimeInstructionInstance methods** ([runtime_instruction_instance.gd:397-458](../../../../core/runtime_instruction_instance.gd)):

| Method | Lines | Description |
|------|------|------|
| `reinitialize(inst, context, runner=null)` | L397 | Reuse path: replaces the three references + syncs `log_level` + zeroes execution state + `_connected_timer_callbacks.clear()` + `runtime_state.clear()` + re-runs `_initialize_runtime_state()` |
| `reset_for_pool()` | L433 | Return path: `_stop_timeout_timer` → disconnect `instruction.finished` → `_cleanup_timer_callbacks` → `_cleanup_runtime_resources` → nulls the three references + zeroes state |

`InstructionInstancePool.acquire` calls `reinitialize` immediately after `pop_back` when the pool is non-empty, and `release` calls `reset_for_pool` before pushing back, ensuring a reused instance's state is equivalent to a fresh instance's.

---

## 5. Usage Patterns

### 5.1 Scene pool: used through instructions

Game code usually does not call `FuseObjectPool` directly, but goes through Fuse instructions (in `instructions/node_operations/`):

| Instruction | Behavior |
|------|------|
| `warm_up_pool.gd` | Triggers `FusePoolManager.warm_up_pool(scene_path, count, pool_config)` |
| `instantiate_scene.gd` | Triggers `instantiate_pooled(scene_path, parent, pool_config)` |
| `recycle_pooled_scene.gd` | Triggers `recycle_pooled(scene_path, instance)`, optionally with delayed recycle via `FuseRecycleTimer.create` |

`FusePoolManager` is a `RefCounted` singleton (not a Node), created on first `get_instance()` access; the recycle timers are child Nodes whose lifecycle is taken over by the SceneTree, and `_active_recycle_timers` prevents premature release.

### 5.2 Instruction instance pool: enabled automatically

`RuntimeActionRunnerInstance.use_instruction_pool` defaults to `true`; acquisition/release of all instruction instances automatically goes through the pool, with no game-code changes needed. To roll back to non-pooled mode, set `use_instruction_pool = false` and it degrades to the `new`/direct GC mode ([runtime_action_runner_instance.gd:378-399](../../../../core/runtime_action_runner_instance.gd)).

### 5.3 Type erasure to avoid circular dependency

`RuntimeActionRunnerInstance` and `InstructionInstancePool` preloading each other would create a circular dependency, so `_shared_instruction_pool` and the `get_shared_pool()` return value are both declared as `RefCounted` ([runtime_action_runner_instance.gd:55, 58](../../../../core/runtime_action_runner_instance.gd)); at runtime it is actually an `InstructionInstancePool`.

---

## 6. Design Highlights

### 6.1 The two pool systems are kept separate

The scene pool (`FuseObjectPool` + `FusePoolManager` + `FuseRecycleTimer`) and the instruction instance pool (`InstructionInstancePool`) are deliberately separate:
- **Different reused object types**: the former handles `Node`s (with subtrees, Triggers, variable containers), the latter `RefCounted` (no scene-tree burden)
- **Different reuse strategies**: the former needs `_reset_fuse_components` to recursively reset the whole Fuse subsystem state; the latter only swaps references via `reinitialize`
- **Different lifecycle management**: the former needs `_terminate_fuse_triggers` to stop processing + deferred scene-tree removal; the latter is just a reference swap

### 6.2 Multi-strategy path matching

`recycle_pooled` does not require the caller to pass exactly the same `scene_path` as `instantiate_pooled`; matching proceeds in this priority order ([fuse_pool_manager.gd:128-179](../../../../core/pooling/fuse_pool_manager.gd)):
1. Prefer `instance.scene_file_path` (the instance carries its real scene path)
2. `_scene_pools.get(final_scene_path)` direct hit
3. `_find_pool_by_instance_id` iterates all pools via instance ID
4. `_find_pool_by_any_path` filename (extension stripped) match + `res://` to `uid://` match

This design tolerates both `res://` and `uid://` path formats and is forgiving about caller path precision.

### 6.3 Recycle safety: FuseRecycleTimer's five-fold validation

During the delayed-recycle window the object's state may change (recycled by other means, reused, removed from the scene tree). `_on_timeout` applies four detections — weak reference + `_creation_usage_count` consistency + `is_inside_tree` + `is_instance_in_use` — to avoid mis-recycling ([fuse_recycle_timer.gd:76-122](../../../../core/pooling/fuse_recycle_timer.gd)). A `usage_count` mismatch means the object was returned and `acquire`d again; the timer should let it go.

### 6.4 Physics callback safety

On return, if the object is inside the scene tree, `return_object` first runs `_terminate_fuse_triggers` (turning off Trigger `_physics_process`), then `_schedule_safe_remove` defers the `remove_child` by one frame ([fuse_object_pool.gd:115-156, 346-357](../../../../core/pooling/fuse_object_pool.gd)). This avoids the Godot physics engine state corruption caused by removing nodes directly inside physics callbacks.

### 6.5 Pooling hooks into the Fuse subsystem

`_reset_fuse_components` and `_terminate_fuse_triggers` detect and call the `Trigger`/`MultiEventTrigger` `pool_reset()` method (preferred over `reset()`), letting Triggers handle the full logic themselves — runtime instance rebuilding, signal reconnection, and so on. They also transparently persist `_pool_default_variables` for `ScopeVariableContainer`, so the variable's first state becomes the baseline for later resets.

### 6.6 Performance observability

- Scene pool: `FusePoolManager.recycle_pooled` and `_find_pool_by_instance_id` hook into `FusePerformanceTracker.start_track/stop_track`
- Pool statistics: `get_statistics` / `get_detailed_status` expose `reuse_ratio` and `efficiency_score` (scene pool: reuse 0.4 + utilization 0.3 + peak ratio 0.2; instruction pool: reuse 0.6 + utilization 0.4)
- Pool shrink: `_adjust_pool_size` sorts with `compare_by_efficiency`, evicting idle objects with the lowest efficiency score first

### 6.7 Expected benefits stated in the instruction pool's comments

The comments at [instruction_instance_pool.gd:1-4](../../../../core/pooling/instruction_instance_pool.gd) state explicitly: pooling `RuntimeInstructionInstance` is meant to save roughly 25μs of `.new()` overhead, marked as a "Phase 2 performance optimization". The four method names in the comments — `acquire`/`release`/`reinitialize`/`reset_for_pool` — match the actual code definitions exactly.

---

## 7. Overall Assessment

### Pros

1. **Clear layering of responsibilities**: `FusePoolItem` (wrapping) / `FuseObjectPool` (single pool) / `FusePoolManager` (multi-pool coordination) have distinct duties, and `InstructionInstancePool` stands as an independent system
2. **Fuse-aware scene pool**: `_reset_fuse_components` and `_terminate_fuse_triggers` deeply handle Trigger/MultiEventTrigger/ScopeVariableContainer, keeping pooled object state clean
3. **Multi-check delayed recycle**: `FuseRecycleTimer` combines weak reference + usage_count + in-tree state + in_use flag in a four-fold detection to avoid mis-recycling
4. **Forgiving path matching**: three strategies — `res://` / `uid://` / filename — with low path-precision demands on callers
5. **Observability**: `get_statistics` / `get_detailed_status` + `efficiency_score` + PerformanceTracker integration
6. **Disable-and-roll-back**: the `use_instruction_pool` switch degrades the instruction pool to non-pooled mode in one step

### Caveats

1. **Linear search (CODE_ISSUES B18, ⏸ low-priority skip)**: `FuseObjectPool.get_object` and `return_object` find items by iterating `_pool_items`. Decision: **keep as is** — `_pool_items` is typically n≤100, so linear search cost is negligible; switching to dictionary/indexed lookup adds memory and maintenance cost for limited benefit. Revisit if pool sizes grow significantly
2. **`_find_pool_by_instance_id` walks all pools**: every precise-path miss iterates every pool item of every pool
3. **Several lookup methods inside `recycle_pooled` (`_find_pool_by_instance_filename` etc.) are defined but unused on `recycle_pooled`'s actual call path**: kept as fallback capability
4. **`get_shared_pool()` is not thread-safe**: lazy loading of the `RuntimeActionRunnerInstance._shared_instruction_pool` static field has no concurrency guard; beware of multi-threaded first access

---

**Document maintainer**: Fuse dev team
**Last updated**: 2026-07-07
**Version**: 1.0.0
**Basis**: verified against the 5 classes of `core/pooling/` source + `core/runtime_action_runner_instance.gd` + `core/runtime_instruction_instance.gd`
