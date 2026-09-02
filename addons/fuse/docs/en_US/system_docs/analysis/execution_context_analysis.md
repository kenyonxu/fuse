> 🌐 [**中文版**](../../../zh_CN/system_docs/analysis/execution_context_analysis.md) | English

# ExecutionContext Analysis Report


> **Analyzed as of**: 2026-07-07 (each article verified against code during the same-day full documentation audit; implementation evolution after this point defers to the source code; for recently verified mechanical conclusions see the threading / runtime_instance / preset_nested articles)
## Document Overview

This report describes the current state of the `ExecutionContext` core script in the Fuse visual programming system. `ExecutionContext` is the execution context class (`class_name ExecutionContext extends RefCounted`), providing the environment and context information for instruction execution; it is the bridge between instructions and the game world.

After refactoring, `ExecutionContext` is now a **facade class**: it keeps only execution-environment data such as node references, custom data, logging, ActionRunner, and FuseError; responsibilities such as execution state/history/progress/dependency graph, variable CRUD/scopes/indexed access/snapshots, and the loop break/continue flag stack are **fully delegated** to two subsystems — `ExecutionDiagnostics` and `VariableContext`. EC creates the two subsystem instances in `_init()`, and external callers access them through the facade methods EC exposes.

**Source file:** [execution_context.gd](../../../../core/base/execution_context.gd)
**Lines:** 773
**Base class:** RefCounted
**Subsystems:** [ExecutionDiagnostics](../../../../core/base/execution_diagnostics.gd) (281 lines), [VariableContext](../../../../core/base/variable_context.gd) (463 lines)

---

## 1. Class Overview and Responsibilities

### Core Responsibilities

1. **Facade/delegation**: exposes a unified execution context interface, delegating internally to VariableContext and ExecutionDiagnostics
2. **Execution environment data**: node references (target/trigger/owner), scene tree, custom_data, execution_id
3. **Node access**: get_node / get_tree multi-strategy node lookup
4. **Logging**: leveled + localized logging based on FuseLogger
5. **Error handling**: FuseError instance management (_create_fuse_error / get_fuse_error / had_error)
6. **Duplication**: duplicate() deep copy (variable subsystem deep-copied, node references shallow-copied)
7. **Static factory**: create_with_params() provides parameterized construction

### Design Characteristics

- `@tool` annotation, supports running in editor mode
- `extends RefCounted`: reference counting manages the lifecycle, avoiding the burden of Node ownership
- `_init()` creates both subsystems and passes itself (`self`) in as `_owner`; the subsystems reference EC's fields back through `_owner`
- EC's `local_variables` / `global_variables` are **compatibility references** pointing to the dictionaries inside `_variable_context`; existing external code reading/writing these two fields is equivalent to operating on the subsystem

---

## 2. Delegation Architecture

```
ExecutionContext (RefCounted, facade)
    │
    ├── _variable_context: VariableContext ── variable subsystem
    │       ├── local_variables / global_variables
    │       ├── _global_variable_assistant
    │       ├── LRU name cache (_variable_name_cache, _cache_max_size=1000)
    │       ├── Indexed access (_variable_index_map / _variable_array)
    │       ├── Loop flags (_break_loop_flag / _continue_loop_flag / _loop_flag_stack)
    │       └── _owner → ExecutionContext
    │
    ├── _diagnostics: ExecutionDiagnostics ── diagnostics subsystem
    │       ├── _execution_state / _execution_progress
    │       ├── _error_message / _is_cancelled
    │       ├── _execution_history (max 100)
    │       ├── _state_change_listeners
    │       └── _owner → ExecutionContext
    │
    └── Retained by EC itself
        ├── target / trigger / owner / tree
        ├── _target_weakref / _trigger_weakref
        ├── custom_data / execution_id / execution_start_time
        ├── log_level / action_runner / delta_time
        └── _fuse_error
```

### Delegation Style

Facade methods on EC **forward directly** to the subsystems with no extra logic (a few methods excepted). For example:

```gdscript
func set_variable(name, value, scope = "local") -> bool:
    return _variable_context.set_variable(name, value, scope)

func get_execution_state() -> ExecutionState:
    return _diagnostics.get_execution_state() as ExecutionState
```

Exceptions: `set_error_message()` creates a FuseError instance and logs after delegating; `get_dependency_visualization_data()` appends FuseError details to the subsystem's return value.

---

## 3. Core Properties

### EC's Own Properties

| Property | Type | Default | Description |
|------|------|--------|------|
| target | Node | null | Target node (the main object instructions operate on) |
| trigger | Variant | null | Trigger node |
| owner | Node | null | Owner node (the node that created this context) |
| tree | SceneTree | null | Scene tree reference |
| local_variables | Dictionary | {} | **Compatibility reference**, points to `_variable_context.local_variables` |
| global_variables | Variant | null | **Compatibility reference**, points to `_variable_context.global_variables` |
| _global_variable_assistant | GlobalVariableAssistant | null | Typed reference to the global variable assistant (compatibility reference) |
| _variable_context | VariableContext | null | Variable subsystem |
| _diagnostics | ExecutionDiagnostics | null | Diagnostics subsystem |
| custom_data | Dictionary | {} | Custom data for temporary cross-instruction exchange |
| execution_start_time | float | 0.0 | Execution start time (milliseconds, recorded at construction) |
| execution_id | String | "" | Unique execution identifier, format `exec_[timestamp]_[random]` |
| log_level | FuseLogger.LogLevel | NONE | Log output level |
| action_runner | Variant | null | Reference to an ActionRunner or RuntimeActionRunnerInstance |
| delta_time | float | 0.0 | Delta time (seconds), from physics/frame callbacks |
| _target_weakref | WeakRef | null | Weak reference to the target node |
| _trigger_weakref | WeakRef | null | Weak reference to the trigger node |
| _fuse_error | FuseError | null | FuseError instance |

### Enum

```
enum ExecutionState { IDLE, RUNNING, PAUSED, COMPLETED, CANCELLED, ERROR }
```

### Signals

| Signal | Parameters | Description |
|------|------|------|
| cancel_requested | (none) | Cancellation request |
| execution_state_changed | (new_state: int) | Execution state changed |

> **Note**: EC **declares only these two signals**. There are no `execution_step_completed` / `execution_progress_updated` signals — progress updates are written to history via `_diagnostics.set_execution_progress()`, not broadcast via signals.

---

## 4. Initialization

### _init() Constructor

```
_init(target_node=null, trigger_node=null, global_vars=null, scene_tree=null, owner_node=null)

Execution flow:
  1. Record execution_start_time = Time.get_ticks_msec()
  2. Generate execution_id = "exec_[timestamp]_[random]"
  3. Set target / trigger / global_variables / owner
  4. Resolve _global_variable_assistant:
     - global_vars is GlobalVariableAssistant → use directly
     - global_vars is GlobalVariableManager → GlobalVariableAssistant.get_instance()
     - other/null → GlobalVariableAssistant.get_instance()
  5. Set tree / weak references (target/trigger)
  6. Create _diagnostics = ExecutionDiagnostics.new(self)
  7. Create _variable_context = VariableContext.new(self)
     - sync global_variables and _global_variable_assistant into the subsystem
  8. Compatibility references: EC.local_variables = _variable_context.local_variables
                              EC.global_variables = _variable_context.global_variables
  9. reset_execution_state() → IDLE
```

> **Note**: steps 6 / 7 are **outside** the `if trigger_node:` block — i.e., when constructed as `ExecutionContext.new(target, null)` with only a target, `_diagnostics` and `_variable_context` are still created, ensuring the variable/diagnostics APIs work in target-only usage.
> History: the indentation once placed them inside the `if trigger_node:` block, so the subsystems were not created in target-only construction and `set_variable` reported Nil (CODE_ISSUES B19); fixed (commit `1ffe707`).

### create_with_params() Static Factory

```
static create_with_params(target_node=null, trigger_node=null, global_vars=null, scene_tree=null) -> ExecutionContext

Only sets target/trigger/global_variables/tree and returns the new instance.
Note: this factory performs no initialization logic beyond _init (it does not rebuild
the subsystem compatibility references), suitable for scenarios where the caller
configures things further after quick construction.
```

---

## 5. Node Access

### get_tree() — Scene Tree Retrieval (fallback implemented)

```
get_tree() -> SceneTree

Execution flow:
  1. If tree is already set → return it directly
  2. Otherwise take it from the main scene: Engine.get_main_loop().current_scene.get_tree()
  3. Cache into the tree field
  4. Return tree (may be null)
```

> **Current status**: a previous draft listed this fallback as a "suggested improvement" — it is **actually already implemented**. `get_tree()` automatically falls back to the main scene and caches the result when tree is empty.

### get_node(path) — Multi-Strategy Node Lookup

```
get_node(path: NodePath) -> Node

Execution flow (by priority):
  1. Empty path → _log_error_localized("FUSE_ERROR_INVALID_NODE_PATH_EMPTY"), return null
  2. trigger node → FuseNodeUtils.find_node_at_runtime(trigger, path)
  3. target node → FuseNodeUtils.find_node_at_runtime(target, path)
  4. current_scene → FuseNodeUtils.find_node_at_runtime(current_scene, path)
  5. Absolute path → search from scene_tree.root
  6. All failed → _log_error_localized("FUSE_ERROR_NODE_NOT_FOUND_AT_PATH", {path}), return null
```

`FuseNodeUtils.find_node_at_runtime` encapsulates the multi-strategy node lookup logic.

---

## 6. Variable Subsystem Facade (Delegating to VariableContext)

### 6.1 Variable CRUD

| Facade method | Delegates to | Description |
|---------|---------|------|
| add_variable(name, variable: BaseVariable) -> bool | _variable_context.add_variable | Adds a BaseVariable object |
| set_variable(name, value, scope="local") -> bool | _variable_context.set_variable | Sets a variable (three-layer scope dispatch) |
| get_variable(name, default=null, scope="local") -> Variant | _variable_context.get_variable | Gets a variable value |
| get_variable_object(name) -> BaseVariable | _variable_context.get_variable_object | Gets the variable object (advanced API) |
| has_variable(name) -> bool | _variable_context.has_variable | Checks whether a variable exists |
| get_global_variable_assistant() -> GlobalVariableAssistant | _variable_context.get_global_variable_assistant | Gets the global variable assistant |
| set_global_variable_assistant(assistant) | _variable_context.set_global_variable_assistant | Sets the global variable assistant (syncs compatibility references) |

### 6.2 String Scopes

The `scope` parameter of `set_variable` / `get_variable` accepts string values:

| scope value | Behavior |
|---------|------|
| "local" | Reads/writes `local_variables` (default) |
| "scope" | Delegates to ScopeVariableContainer (located via `_find_scope_container`) |
| "global" | Delegates to GlobalVariableAssistant / the global_variables container |
| Other | `_log_error_localized("FUSE_ERROR_UNKNOWN_VARIABLE_SCOPE", {scope})` |

### 6.3 Loop Control (break/continue Flag Stack)

| Facade method | Description |
|---------|------|
| set_break_loop() | Sets the break flag |
| set_continue_loop() | Sets the continue flag |
| should_break_loop() -> bool | Checks the break flag |
| should_continue_loop() -> bool | Checks the continue flag |
| clear_loop_flags() | Clears both flags |
| push_loop_flags() | Saves the current flags onto the stack and clears them (entering an inner loop) |
| pop_loop_flags() | Restores the outer flags from the stack (clears if the stack is empty) |

VariableContext maintains internally:
- `_break_loop_flag: bool`
- `_continue_loop_flag: bool`
- `_loop_flag_stack: Array[Dictionary]` (each item `{"break": bool, "continue": bool}`)

`push/pop` is used for nested loops (ForEach / While instructions), ensuring an inner loop's break/continue does not pollute the outer loop.

### 6.4 Indexed Access Optimization

| Facade method | Description |
|---------|------|
| precompile_variable_access(names: Array[String]) | Precompiles the variable-name-to-index mapping and enables indexed access mode |
| set_variable_by_index(index, value) | Sets a variable by index |
| get_variable_by_index(index) -> Variant | Gets a variable by index |
| get_variable_index(name) -> int | Queries the index for a variable name (-1 means not enabled / not found) |
| is_indexed_access_enabled() -> bool | Whether indexed access is enabled |
| get_indexed_access_stats() -> Dictionary | Indexed access statistics |

VariableContext maintains `_variable_index_map` (StringName→int) and `_variable_array` internally. After precompilation, hot paths can bypass dictionary lookups.

### 6.5 LRU Name Cache

VariableContext maintains:
- `_variable_name_cache: Dictionary` (String → StringName)
- `_cache_max_size: int = 1000`
- `_cache_access_order: Array`

`_get_cached_name_key(name) -> StringName` evicts the oldest 1/5 when capacity reaches the limit. `local_variables` uses StringName keys to speed up dictionary lookups.

### 6.6 Variable Snapshots (breakpoint debugging)

| Facade method | Description |
|---------|------|
| get_all_local_variables_snapshot() -> Dictionary | Local variable snapshot (StringName keys converted to String) |
| get_all_scope_variables_snapshot() -> Dictionary | Scope variable snapshot (via ScopeVariableContainer.get_variable_names) |
| get_all_global_variables_snapshot() -> Dictionary | Global variable snapshot (delegates to GlobalVariableAssistant.get_all_global_variables_info) |

### 6.7 Scope Container Lookup

`VariableContext._find_scope_container() -> ScopeVariableContainer` lookup priority:
1. The nearest ScopeVariableContainer from the `trigger` node
2. The nearest ScopeVariableContainer from the `target` node
3. The nearest ScopeVariableContainer from the `owner` node
4. Returns null (`_set/_get_scope_variable` falls back to local variables and push_warning)

---

## 7. Diagnostics Subsystem Facade (Delegating to ExecutionDiagnostics)

### 7.1 Execution State

| Facade method | Description |
|---------|------|
| get_execution_state() -> ExecutionState | Current state |
| set_execution_state(state) | Sets the state (on change: emit execution_state_changed + record history + notify listeners) |
| reset_execution_state() | Resets to IDLE (clears progress/error/cancel flags) |
| is_running() -> bool | state == RUNNING |
| is_completed() -> bool | state == COMPLETED |
| has_error() -> bool | state == ERROR |
| is_cancelled() -> bool | _is_cancelled or state == CANCELLED |
| request_cancel() | Only when RUNNING: sets _is_cancelled, switches to CANCELLED, emits cancel_requested |

### 7.2 Progress and Errors

| Facade method | Description |
|---------|------|
| get_execution_progress() -> float | Current progress (0.0–1.0) |
| set_execution_progress(progress) | Clamps to [0,1]; records history when the change is >0.01 |
| get_error_message() -> String | Error message |
| set_error_message(msg, error_type=RUNTIME_ERROR, context={}) | **Special**: after delegating, also creates a FuseError instance + writes a log |

`set_error_message` is one of the few facade methods with extra logic:

```gdscript
func set_error_message(message, error_type=RUNTIME_ERROR, context={}):
    _diagnostics.set_error_message(message, error_type, context)
    var error_context = context.duplicate()
    error_context["execution_id"] = execution_id
    error_context["execution_state"] = ExecutionState.keys()[_diagnostics.get_execution_state()]
    _create_fuse_error(message, error_type, error_context)
    _log_error("Execution error: %s" % message)
```

### 7.3 History Records

| Facade method | Description |
|---------|------|
| get_execution_history(limit=0) -> Array[Dictionary] | Returns all when limit<=0 or >= size; otherwise returns the last limit entries |
| clear_execution_history() | Clears history |
| _record_execution_history(state, message="", data={}) | Internal recording (each entry contains timestamp/state/state_name/message/progress/execution_time/data) |

ExecutionDiagnostics internally sets `_max_history_size = 100` and automatically pop_front beyond that.

### 7.4 State Change Listeners

| Facade method | Description |
|---------|------|
| add_state_change_listener(listener: Callable) | Registers a listener |
| remove_state_change_listener(listener: Callable) | Removes a listener |
| _notify_state_change(old_state, new_state) | Internal notification (listener.call(old, new, owner)) |

### 7.5 State Statistics

| Facade method | Description |
|---------|------|
| get_state_statistics() -> Dictionary | total_history_entries / state_counts / total_time_in_states / last_state_change_time / current_state_duration |
| get_recent_state_changes(count=10) -> Array[Dictionary] | The most recent actual state change entries |

### 7.6 Dependency Graph

| Facade method | Description |
|---------|------|
| get_dependency_graph() -> Dictionary | Nodes + edges + context_info (execution_id/target/trigger/execution_time) |
| _collect_all_variables() -> Dictionary | Internally collects all local variables |
| check_dependencies(deps: Array[String]) -> Dictionary | Checks whether the dependent variables exist |
| get_dependency_status() -> Dictionary | total_variables / total_conditions / variable_dependencies / condition_dependencies |
| check_dependencies_batch(deps_list: Array) -> Array | Batch check |
| get_dependency_visualization_data() -> Dictionary | **Special**: merges graph+status+context_info, and appends fuse_error details when _fuse_error exists |

---

## 8. FuseError Integration

| Method | Description |
|------|------|
| _create_fuse_error(message, error_type=RUNTIME_ERROR, context={}) | Creates a FuseError instance (injecting execution_id) and stores it in _fuse_error |
| get_fuse_error() -> FuseError | Gets the current FuseError (null if none) |
| has_fuse_error() -> bool | Whether a FuseError exists |
| had_error() -> bool | Alias of has_fuse_error (backward compatibility) |

`_create_fuse_error` creates the instance via `FuseError.create_with_context(error_type, "ExecutionContext", message, error_context)`. `set_error_message` is the main path that triggers FuseError creation.

---

## 9. Logging System

### Leveled Logging (based on FuseLogger)

| Method | Delegates to |
|------|------|
| print_message(message) | FuseLogger.log_info("ExecutionContext", log_level, message, execution_id) |
| print_warning(message) | FuseLogger.log_warning(...) |
| print_error(message) | FuseLogger.log_error(...) |
| _log_debug(message) | FuseLogger.log_debug(...) |
| _log_info(message) | FuseLogger.log_info(...) |
| _log_warning(message) | FuseLogger.log_warning(...) |
| _log_error(message) | FuseLogger.log_error(...) |

### Localized Logging

| Method | Delegates to |
|------|------|
| _log_debug_localized(message_key, args={}) | FuseLogger.log_debug_localized(...) |
| _log_info_localized(message_key, args={}) | FuseLogger.log_info_localized(...) |
| _log_warning_localized(message_key, args={}) | FuseLogger.log_warning_localized(...) |
| _log_error_localized(message_key, args={}) | FuseLogger.log_error_localized(...) |

All logging methods pass `execution_id` as the correlation identifier. message_key goes through FuseLocalization translation; args are used for placeholder substitution.

### Log Level Control

- `set_log_level(level)` sets the level and prints a change log
- `get_log_level() -> FuseLogger.LogLevel`

---

## 10. ActionRunner Integration

| Method | Description |
|------|------|
| set_action_runner(runner) | Sets the ActionRunner or RuntimeActionRunnerInstance reference |
| get_action_runner() | Gets the reference (null if not set) |
| has_action_runner() -> bool | Whether it is set |

The `action_runner` field is typed Variant and can hold either runner type.

---

## 11. WeakRef Node Reference Management

To reduce memory leak risk (node freed before EC), EC keeps weak references to the target/trigger nodes.

| Method | Description |
|------|------|
| set_target_node(node) | Sets target and _target_weakref |
| get_target_node() -> Node | Checks the weak reference first; if stale, warns and cleans up, falling back to target |
| set_trigger_node(node) | Sets trigger and _trigger_weakref |
| get_trigger_node() -> Node | Checks the weak reference first; if stale, warns and cleans up, falling back to trigger |

When a weak reference goes stale, `_log_warning_localized("FUSE_WARNING_TARGET_NODE_RELEASED" / "FUSE_WARNING_TRIGGER_NODE_RELEASED")` is called and the field is cleaned up.

---

## 12. Duplication and Cleanup

### duplicate(p_deep=true) -> ExecutionContext

```
Execution flow:
  1. Create a new EC (no arguments → _init takes the default path)
  2. Copy target / trigger / tree (shallow copy, shared nodes)
  3. _variable_context.duplicate() deep-copies the variable subsystem
     - update _owner to point to the new EC
     - sync EC.local_variables into the new VariableContext's dictionary
  4. Copy global_variables / _global_variable_assistant (shared containers)
  5. custom_data.duplicate() (shallow-copied dictionary)
  6. Copy execution_start_time / execution_id / action_runner (shared runner)
  7. _diagnostics deep copy (preserves execution history / state / listeners)
```

> **Note**: duplicate copies `_diagnostics` (deep copy, independent instance) and does not copy WeakRefs. Both the variable subsystem and the diagnostics subsystem are deep-copy targets.
> History: `_diagnostics` copying was once omitted (CODE_ISSUES B11); fixed (commit `1ffe707`, test `test_execution_context_init.tscn`).

### cleanup()

```
Execution flow:
  1. _variable_context.cleanup() (clears variables/caches/indexes/flag stack)
  2. Iterate custom_data, null out RefCounted/Resource items, then clear()
  3. target/trigger: if not queued_for_deletion, log and null out
  4. Clear _target_weakref / _trigger_weakref
  5. Null out global_variables / tree / action_runner
  6. _diagnostics.cleanup() (clears history/listeners/state)
  7. Null out _fuse_error
  8. reset_execution_state()
  9. _log_debug_localized("FUSE_LOG_EXECUTION_CONTEXT_CLEANED")
```

---

## 13. Debug Information

### get_info() -> Dictionary

Returns a snapshot of the execution context, for debugging and logging:

```gdscript
{
    "execution_id": ...,
    "execution_time": get_execution_time(),
    "target": ...,
    "trigger": ...,
    "local_variables_count": local_variables.size(),
    "has_global_variables": global_variables != null,
    "custom_data_count": custom_data.size(),
    "execution_state": ExecutionState.keys()[...],
    "execution_progress": ...,
    "is_cancelled": ...,
    "error_message": ...,
    "has_action_runner": action_runner != null
}
```

`get_execution_time() -> float` returns the milliseconds since construction (`Time.get_ticks_msec() - execution_start_time`).

---

## 14. Custom Data

| Method | Description |
|------|------|
| set_custom_data(key, value) | Stores into the custom_data dictionary |
| get_custom_data(key, default=null) -> Variant | Reads; returns default if absent |

`custom_data` is used for temporary cross-instruction information exchange (not part of the variable scope system).

---

## 15. Compatibility Design

EC keeps **compatibility references** in several places to preserve legacy code access paths:

| Field/Method | Compatibility target |
|----------|---------|
| `local_variables` | The same dictionary as `_variable_context.local_variables` |
| `global_variables` | Points to `_variable_context.global_variables` |
| `_global_variable_assistant` | Kept in sync with `_variable_context._global_variable_assistant` |
| `had_error()` | Alias of `has_fuse_error()` |
| `print_message/warning/error` | Legacy interfaces equivalent to `_log_info/warning/error` |

`set_global_variable_assistant(assistant)` updates the references on both EC and VariableContext to keep them consistent.

---

## 16. Overall Assessment

### Strengths

1. **Clear facade architecture**: EC is the external interface; VariableContext / ExecutionDiagnostics each mind their own role and can evolve independently
2. **RefCounted lifecycle**: avoids the burden of Node ownership, suitable for object pool and Runtime instance scenarios
3. **Three-layer variable scopes**: local / scope / global string dispatch, with ScopeVariableContainer providing node-level scopes
4. **Indexed access optimization**: after precompilation, bypasses dictionary lookups, suited to high-frequency loops
5. **LRU name cache**: StringName keys + LRU capped at 1000, balancing hit rate and memory
6. **Loop flag stack**: push/pop supports break/continue isolation for nested loops
7. **WeakRef node management**: reduces the dangling-reference risk of nodes being freed before EC
8. **Unified FuseError errors**: consistent with the BaseEvent / BaseInstruction error model
9. **Localized logging**: the _log_*_localized series hooks into FuseLocalization
10. **get_tree fallback implemented**: automatically falls back to the main scene when tree is empty (an earlier draft wrongly listed this as a pending improvement)

### Weaknesses and Caveats

1. **create_with_params does not take the full _init path**: subsystem compatibility references are not synced; clarify the semantics before use
2. **Multiple sync points for `_global_variable_assistant`**: EC, VariableContext, and set_global_variable_assistant must stay consistent in three places, easy to miss one
3. **get_dependency_graph collects only local variables**: `_collect_all_variables` excludes scope/global, limiting the dependency graph view
4. **No signal for progress updates**: the `execution_progress_updated` signal envisioned in an earlier draft does not exist; progress changes only go into history, and external code must poll `get_execution_progress()`

> Historical B11 (duplicate not copying _diagnostics) and B19 (_init indentation leaving subsystems nil in target-only construction) are fixed (commit `1ffe707`, test `test_execution_context_init.tscn`) and removed from the caveats list.

---

**Maintained by**: Fuse development team
**Last updated**: 2026-07-07
**Version**: 2.0 (rewritten, aligned with execution_context.gd 773 lines + ExecutionDiagnostics 281 lines + VariableContext 463 lines)
