> 🌐 [**中文版**](../../../zh_CN/dev_docs/guides/multithreading-developer-guide.md) | English

# Fuse Multithreading System - Developer Guide

## Overview

Fuse now supports parallel condition evaluation and asynchronous scene preloading. The core idea is simple: run the time-consuming condition checks on worker threads and let the main thread handle only the results.

## Quick Start

### Parallel Condition Evaluation

```gdscript
# Enable in MultiEventTrigger
@export var use_parallel_condition_evaluation: bool = true
```

That is the whole change. The trigger automatically detects which conditions are thread-safe and evaluates them in parallel.

### Creating a Thread-Safe Condition

Extend `BaseCondition` and override `_compute_thread_safety()`:

```gdscript
class_name MyThreadSafeCondition extends BaseCondition

func _compute_thread_safety() -> bool:
    # Only safe when all of the following hold
    if uses_target_node or accesses_context:
        return false
    return true
```

**A thread-safe condition must:**
- Not access node properties
- Not call `get_node()` or `get_parent()`
- Only read data from `GlobalVariableManager`
- Not modify any state

## Core Classes

### FuseThreadSafe

Thread-safety utility class. Provides Mutex-wrapped dictionary and array operations.

```gdscript
# Safely modify a dictionary
FuseThreadSafe.safe_dict_write(my_dict, "key", value)

# Safely read and process
var snapshot = FuseThreadSafe.safe_dict_read(my_dict, "key", default_value)
```

### FuseTaskManager

A wrapper around `WorkerThreadPool`. Submit tasks and await results.

```gdscript
var task_manager = FuseTaskManager.get_instance()

# Submit a background task
var task_id = task_manager.submit_task(func():
    return do_expensive_work()
)

# Await the result (with timeout)
var result = await task_manager.await_task(task_id, 5.0)

# Cancel the task
task_manager.cancel_task(task_id)
```

| Method | Description |
|------|------|
| `submit_task(callable)` | Submit a task, returns the task ID |
| `await_task(id, timeout)` | Await task completion |
| `cancel_task(id)` | Cancel the task |
| `get_task_status(id)` | Get the status (returns `TaskStatus` or `null`) |

### ParallelConditionEvaluator

Evaluates multiple conditions in parallel. Three modes:

| Mode | Behavior |
|------|------|
| `SEQUENTIAL` | Run everything serially |
| `PARALLEL_SAFE` | Only parallelize thread-safe conditions |
| `PARALLEL_ALL` | Force-parallelize everything (dangerous, for testing only) |

```gdscript
var evaluator = ParallelConditionEvaluator.new()
evaluator.evaluation_mode = ParallelConditionEvaluator.EvaluationMode.PARALLEL_SAFE

var results = evaluator.evaluate_parallel(context, conditions)
# results: Array[bool], one-to-one with conditions
```

### FuseThreadingConfig

Configuration resource. Placed under `resources://` it loads automatically.

```gdscript
var config = FuseThreadingConfig.get_instance()

# Read the configuration
if config.enable_multithreading:
    evaluator.evaluation_mode = evaluator.EvaluationMode.PARALLEL_SAFE
```

## Implementing Thread-Safe Conditions

### Example: CheckVariable

```gdscript
func _compute_thread_safety() -> bool:
    if _thread_safety_computed:
        return _thread_safety_cached

    var is_safe := true

    # SCOPE-scope needs access to ExecutionContext, not safe
    if variable_scope == BaseVariable.VariableScope.SCOPE:
        match scope_source:
            ScopeSource.TARGET_NODE, ScopeSource.TRIGGER_SCOPE:
                is_safe = false
            ScopeSource.NEAREST, ScopeSource.CUSTOM_ID:
                is_safe = false

    # The comparison variable must be checked too
    if is_safe and check_with_another_variable:
        if compare_variable_scope == BaseCondition.VariableScope.SCOPE:
            match compare_scope_source:
                ScopeSource.TARGET_NODE, ScopeSource.TRIGGER_SCOPE:
                    is_safe = false
                ScopeSource.NEAREST, ScopeSource.CUSTOM_ID:
                    is_safe = false

    _thread_safety_cached = is_safe
    _thread_safety_computed = true
    return _thread_safety_cached
```

### Thread-Safety Checklist

Before returning `true` from `_compute_thread_safety()`, confirm that you:

- [ ] Do not access `context.trigger` or `context.target`
- [ ] Do not call `get_node()`, `get_parent()`, `get_tree()`
- [ ] Do not access any node properties
- [ ] Only use `GlobalVariableManager.get_all_variables_snapshot()`
- [ ] Do not modify any global state

## Signals and Threading

Godot signals used across threads require `CONNECT_DEFERRED`:

```gdscript
# ❌ Wrong - may fire on a worker thread and crash
signal.completed.connect(_on_completed)

# ✅ Correct - defers handling to the main thread
signal.completed.connect(_on_completed, Object.CONNECT_DEFERRED)
```

`RefCounted` has no `call_deferred()`. Use signals + `CONNECT_DEFERRED` instead:

```gdscript
# In a RefCounted class
signal _work_completed(result: Variant)

func do_work():
    WorkerThreadPool.add_task(_worker_func)

func _worker_func():
    var result = compute()
    _work_completed.emit(result)  # Emit the signal
    # The main thread receives it via CONNECT_DEFERRED
```

## Scene Preloading

Load scenes asynchronously to avoid hitches.

```gdscript
# Start loading
var instruction = PreloadSceneInstruction.new()
instruction.scene_path = "res://scenes/level_2.tscn"
instruction.preload_mode = PreloadSceneInstruction.PreloadMode.ASYNC_LATER
instruction.execute(context)

# Check the status
var check = CheckPreloadStatus.new()
check.scene_path = "res://scenes/level_2.tscn"
check.expected_status = CheckPreloadStatus.PreloadStatus.LOADED
if check.check(context):
    # Loaded, ready to instantiate
    var scene = PreloadSceneInstruction.get_loaded_scene("res://scenes/level_2.tscn")
```

| Status | Description |
|------|------|
| `NOT_LOADED` | Loading has not started |
| `LOADING` | Loading in progress |
| `LOADED` | Loaded, ready to instantiate |
| `FAILED` | Loading failed |
| `TIMEOUT` | Loading timed out |

## Debugging

Enable logging to see the detailed execution flow:

```gdscript
# Set the log level on the trigger
trigger.log_level = FuseLogger.LogLevel.DEBUG
```

View parallel evaluation statistics:

```gdscript
var stats = evaluator.get_statistics()
print("总评估次数: %d" % stats["total_conditions_evaluated"])
print("串行模式: %d" % stats["serial_evaluations"])
print("并行模式: %d" % stats["parallel_evaluations"])
```

## FAQ

### Q: Is parallel actually slower?

Parallelism has overhead. With few conditions (<10), serial is usually faster. Adjust the threshold in `FuseThreadingConfig`:

```gdscript
config.min_conditions_for_parallel = 8
```

### Q: Random crashes?

Check whether your conditions are truly thread-safe. Be conservative in `_compute_thread_safety()` — return `false` when in doubt.

### Q: Signals not received?

Make sure you use `CONNECT_DEFERRED`. WorkerThreadPool tasks run on worker threads; emitting a signal directly will not trigger main-thread callbacks.

## File Structure

```
addons/fuse/
├── core/
│   ├── threading/
│   │   ├── fuse_thread_safe.gd          # Utility class
│   │   ├── fuse_task_manager.gd         # Task manager
│   │   ├── parallel_condition_evaluator.gd # Parallel evaluator
│   │   └── fuse_threading_config.gd     # Configuration resource
│   └── base/
│       └── base_condition.gd              # Adds is_thread_safe
├── conditions/
│   └── variable/
│       └── check_variable.gd              # Thread-safety implementation example
└── instructions/
    └── scene/
        └── preload_scene_instruction.gd   # Scene preloading
```

## Optimized Conditions

| Condition | Thread-safe when | Priority |
|------|-------------|--------|
| CheckVariable | LOCAL/GLOBAL scopes | P0 ✅ |
| CheckPreloadStatus | Always safe | P0 ✅ |
| CheckInputPressed | Always safe | P1 ✅ |
| CheckInputHeld | Always safe | P1 ✅ |
| CheckInputReleased | Always safe | P1 ✅ |
| CheckAll | All child conditions safe | P2 ✅ |
| CheckAny | All child conditions safe | P2 ✅ |
| CheckNot | Child condition safe | P2 ✅ |
| CheckArraySize | VARIABLE + LOCAL/GLOBAL | P2 ✅ |
| CheckArrayContains | VARIABLE + LOCAL/GLOBAL | P2 ✅ |
| CheckDictSize | LOCAL/GLOBAL scopes | P2 ✅ |
| CheckDictContainsKey | LOCAL/GLOBAL scopes + safe key source | P2 ✅ |

## Conditions Not Optimized (Kept Serial)

The following conditions need access to nodes or the ExecutionContext and cannot be optimized:

- `CheckNodeProperty` - needs node property access
- `CheckNodeActive` - needs node access
- `CheckNodeExists` - needs node access
- `CheckChildCount` - needs node children access
- `CheckGroupCount` - needs SceneTree access
- `CheckAnimationFinished` - needs animation state access
- `CheckArraySize` (NODE_CHILDREN/NODE_GROUP modes) - needs node access
