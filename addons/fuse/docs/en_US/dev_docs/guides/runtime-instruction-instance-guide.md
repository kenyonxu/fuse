> 🌐 [**中文版**](../../../zh_CN/dev_docs/guides/runtime-instruction-instance-guide.md) | English

# RuntimeInstructionInstance Development Guide

## Overview

RuntimeInstructionInstance is the runtime instance wrapper for instructions, providing independent state storage and execution isolation.

## Architecture

```
BaseInstruction (Resource, shared)
        │
        ▼
RuntimeInstructionInstance (RefCounted, independent per execution)
    - runtime_state: Dictionary  ← independent state storage
    - instruction: BaseInstruction  ← points to the shared resource
```

### Architecture Comparison

| Layer | Has a RuntimeInstance | State isolation |
|------|----------------------|----------|
| Event | ✅ RuntimeEventInstance | ✅ Yes |
| ActionRunner | ✅ RuntimeActionRunnerInstance | ✅ Yes |
| Instruction | ✅ RuntimeInstructionInstance | ✅ Yes |

## Core Features

### State Isolation

Every RuntimeInstructionInstance has its own `runtime_state` dictionary, ensuring concurrent executions do not interfere with each other.

### Timeout Mechanism

```gdscript
var runtime_inst = RuntimeInstructionInstance.new(instruction, context, null)
runtime_inst.execution_timeout = 5.0  # 5-second timeout
runtime_inst.timeout.connect(_on_timeout)
```

### Pause/Resume

```gdscript
runtime_inst.pause()
# ... while paused
runtime_inst.resume()
```

### Signals

| Signal | Description |
|------|------|
| `finished()` | Execution completed |
| `error_occurred(message: String)` | Execution error |
| `paused()` | Paused |
| `resumed()` | Resumed |
| `timeout()` | Timed out |

## Adding Runtime Instance Support to an Instruction

### Method 1: Declare the Default State

Override the `get_default_runtime_state()` method to declare the runtime state you need:

```gdscript
class_name MyInstruction extends BaseInstruction

func get_default_runtime_state() -> Dictionary:
    var state = super.get_default_runtime_state()
    state["my_timer"] = null
    state["my_counter"] = 0
    return state
```

### Method 2: Implement the Runtime Execution Method

Override the `execute_with_runtime_instance()` method:

```gdscript
func execute_with_runtime_instance(runtime_instance: RuntimeInstructionInstance) -> bool:
    _start_execution(runtime_instance.execution_context)

    # Use runtime_instance.runtime_state to store state
    var state = runtime_instance.runtime_state

    # Create a timer
    var scene_tree = Engine.get_main_loop()
    if scene_tree:
        var timer = scene_tree.create_timer(1.0)
        state["timer"] = timer

        # Create a Callable and register it with the runtime_instance
        var callback = _create_timer_callback(runtime_instance)
        timer.timeout.connect(callback)
        runtime_instance.register_timer_callback(callback)

        return false  # Asynchronous execution

    runtime_instance._complete_execution()
    return true  # Synchronous completion

func _create_timer_callback(runtime_instance: RuntimeInstructionInstance) -> Callable:
    var callback = func():
        _on_timer_done(runtime_instance)
    return callback

func _on_timer_done(runtime_instance: RuntimeInstructionInstance):
    if not runtime_instance or runtime_instance.is_completed():
        return
    runtime_instance._complete_execution()
```

### Method 3: Implement the Pause/Resume Callbacks

```gdscript
func on_runtime_pause(runtime_instance: RuntimeInstructionInstance) -> void:
    var state = runtime_instance.runtime_state
    # Save the state at pause time
    runtime_instance.set_runtime_state("paused_at", Time.get_ticks_msec())

func on_runtime_resume(runtime_instance: RuntimeInstructionInstance) -> void:
    # Resume execution
    pass
```

## Signal Connection Management

**Important:** do not connect SceneTreeTimer signals with `bind()`; use the registration mechanism instead:

```gdscript
# ✅ Correct: register the callback
var callback = func(): _on_timer_done(runtime_instance)
timer.timeout.connect(callback)
runtime_instance.register_timer_callback(callback)

# ❌ Wrong: using bind may cause memory leaks
timer.timeout.connect(_on_timer_done.bind(runtime_instance))
```

## Error Handling

Use condition checks and `_handle_execution_error()` to handle errors (GDScript has no try-catch):

```gdscript
# GDScript uses condition checks instead of try-catch
if risky_operation() != OK:
    runtime_instance._handle_execution_error("操作失败")
    return true

# Or check the return value
var result = risky_operation()
if result == null or result.has_error():
    runtime_instance._handle_execution_error("操作失败: %s" % str(result.get_error()))
    return true
```

## Migrating Existing Instructions

1. **Add `get_default_runtime_state()`** - declare the state
2. **Add `execute_with_runtime_instance()`** - implement the runtime execution
3. **Switch instance variables to `runtime_state`** - state storage
4. **Implement `on_runtime_pause()` / `on_runtime_resume()`** - if needed
5. **Keep the original `execute()` method** - for legacy-mode compatibility

## Example: Wait Instruction Migration

```gdscript
# Declare the default runtime state
func get_default_runtime_state() -> Dictionary:
    var state = super.get_default_runtime_state()
    state["timer"] = null
    state["wait_time"] = wait_time
    state["remaining_time"] = 0.0
    state["pause_remaining_time"] = 0.0
    return state

# Runtime execution method
func execute_with_runtime_instance(runtime_instance: RuntimeInstructionInstance) -> bool:
    _start_execution(runtime_instance.execution_context)

    var state = runtime_instance.runtime_state
    var actual_wait_time = _get_wait_time(runtime_instance.execution_context)

    if actual_wait_time < 0:
        runtime_instance._handle_execution_error("无效的等待时间")
        return true

    var scene_tree = Engine.get_main_loop()
    if scene_tree:
        var timer = scene_tree.create_timer(actual_wait_time)
        state["timer"] = timer
        state["is_running"] = true
        state["actual_wait_time"] = actual_wait_time

        var callback = _create_timer_callback(runtime_instance)
        timer.timeout.connect(callback)
        runtime_instance.register_timer_callback(callback)

        return false  # Asynchronous

    runtime_instance._complete_execution()
    return true

# Pause handling
func on_runtime_pause(runtime_instance: RuntimeInstructionInstance) -> void:
    var state = runtime_instance.runtime_state
    if state.has("timer") and state["timer"]:
        var elapsed = Time.get_ticks_msec() / 1000.0 - state.get("wait_start_time", 0.0)
        var remaining = state.get("actual_wait_time", 0.0) - elapsed
        state["pause_remaining_time"] = max(0.0, remaining)
        state["timer"] = null

# Resume handling
func on_runtime_resume(runtime_instance: RuntimeInstructionInstance) -> void:
    var state = runtime_instance.runtime_state
    var remaining = state.get("pause_remaining_time", 0.0)

    if remaining > 0:
        var scene_tree = Engine.get_main_loop()
        if scene_tree:
            var timer = scene_tree.create_timer(remaining)
            state["timer"] = timer

            var callback = _create_timer_callback(runtime_instance)
            timer.timeout.connect(callback)
            runtime_instance.register_timer_callback(callback)

    state["pause_remaining_time"] = 0.0
```

## Notes

1. **Keep the original `execute()` method** - ensures backward compatibility
2. **Use condition checks instead of try-catch** - GDScript has no exceptions
3. **Register timer callbacks** - avoid `bind()`, which causes memory leaks
4. **Store state in `runtime_state`** - ensures concurrency isolation
5. **Check instance validity** - verify `is_completed()` inside callbacks
