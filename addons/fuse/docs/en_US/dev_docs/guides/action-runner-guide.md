> 🌐 [**中文版**](../../../zh_CN/dev_docs/guides/action-runner-guide.md) | English

# Fuse ActionRunner Development Guide

> **Goal**: Provide developers with a complete development guide to the ActionRunner executor, covering execution modes, instruction orchestration, runtime instances, and performance optimization.

**Audience**: Fuse system developers, contributors

**Last updated**: 2026-07-07

---

## 📋 Table of Contents

1. [System Overview](#system-overview)
2. [Architecture Design](#architecture-design)
3. [ActionRunner API Reference](#actionrunner-api-reference)
4. [RuntimeActionRunnerInstance API](#runtimeactionrunnerinstance-api)
5. [Execution Modes](#execution-modes)
6. [Signals and Events](#signals-and-events)
7. [Performance Optimizations](#performance-optimizations)
8. [Best Practices](#best-practices)
9. [Common Pitfalls](#common-pitfalls)

---

## System Overview

`ActionRunner` is the core execution engine of the Fuse visual programming system, responsible for orchestrating and executing instruction sequences. It comes in two forms:

| Form | Class name | File | Description |
|------|------|------|------|
| **Definition resource** | `ActionRunner` | `core/base/action_runner.gd` | Resource subclass storing the instruction sequence and configuration |
| **Runtime instance** | `RuntimeActionRunnerInstance` | `core/runtime_action_runner_instance.gd` | RefCounted, wraps an ActionRunner to provide independent runtime state |

### Design Goals

- **Resource-based**: ActionRunner is a Resource — reusable, serializable, shareable
- **Dual-mode execution**: supports SEQUENTIAL and PARALLEL execution
- **Instruction orchestration**: supports conditional skip (`skip_instruction`) and conditional stop (`stop_execution`)
- **Runtime isolation**: `RuntimeActionRunnerInstance` gives each trigger its own execution environment
- **Performance optimizations**: compilation cache (Phase 3), signal batching (Phase 2.5), object pool (Phase 2)

---

## Architecture Design

```
                        ┌─────────────────┐
                        │   ActionRunner   │  ← Resource, reusable
                        │  (Resource)      │
                        └────────┬────────┘
                                 │ wraps
                                 ▼
                  ┌──────────────────────────┐
                  │ RuntimeActionRunnerInstance│  ← RefCounted, independent state
                  │ (RefCounted)               │
                  └────────┬─────────────────┘
                           │ executes
                           ▼
                  ┌──────────────────┐
                  │ ExecutionContext │  ← execution context
                  │ (RefCounted)     │
                  └──────────────────┘
                           │
            ┌──────────────┼──────────────┐
            ▼              ▼              ▼
      [Instruction 1] [Instruction 2] [Instruction 3 ...]
            │              │
            ▼              ▼
     FuseLogger ──── log output
     FuseError  ──── error handling
```

---

## ActionRunner API Reference

**File location**: `addons/fuse/core/base/action_runner.gd`

**Class definition**:
```gdscript
@tool
@icon("res://addons/fuse/icons/action_runner.svg")
class_name ActionRunner extends Resource
```

### Exported Properties

```gdscript
## Instruction array
@export var instructions: Array[BaseInstruction] = []

## Execution mode: SEQUENTIAL or PARALLEL
@export var execution_mode: ExecutionMode = ExecutionMode.SEQUENTIAL

## Whether to stop when an instruction errors
@export var stop_on_error: bool = true

## Log level
@export var log_level: FuseLogger.LogLevel = FuseLogger.LogLevel.INFO

## Timeout configuration group
@export var enable_instruction_timeout: bool = false   # Enable instruction timeout
@export var instruction_timeout: float = 5.0           # Per-instruction timeout (seconds)
```

### Execution State Properties

```gdscript
var is_running: bool = false                  # Whether currently executing
var is_canceling: bool = false                # Whether currently canceling
var cancellation_reason: String = ""          # Cancellation reason
var current_context: ExecutionContext = null  # Current execution context
var current_instruction_index: int = 0        # Current instruction index
var execution_start_time: float = 0.0         # Execution start time
var execution_end_time: float = 0.0           # Execution end time
```

### Core Execution Methods

```gdscript
## Run the instruction sequence
## Arguments: context - the execution context
func run(context: ExecutionContext) -> void

## Stop execution (sets the running state to false)
func stop() -> void

## Cancel the execution sequence
## Arguments: reason - the cancellation reason
func cancel_execution(reason: String = "") -> void

## Get the canceling state
func get_is_canceling() -> bool

## Get the execution status dictionary (includes progress info)
func get_execution_status() -> Dictionary
```

### Instruction Management Methods

```gdscript
## Validate all instructions
func validate_instructions() -> bool

## Add an instruction (position = -1 means the end)
func add_instruction(instruction: BaseInstruction, position: int = -1) -> void

## Remove an instruction
func remove_instruction(position: int) -> void

## Clear all instructions
func clear_instructions() -> void

## Get the instruction at the given position
func get_instruction(position: int) -> BaseInstruction

## Get the instruction count
func get_instruction_count() -> int

## Check whether the given instruction is present
func has_instruction(instruction: BaseInstruction) -> bool

## Get the instruction index
func get_instruction_index(instruction: BaseInstruction) -> int
```

### Execution Control Methods

```gdscript
## Set the number of instructions to skip
func set_skip_instruction_count(count: int) -> void

## Request stopping the execution
func set_stop_execution(stop: bool, reason: String = "") -> void

## Reset the runner state
func reset() -> void

## Clear the validation cache
func clear_validation_cache() -> void
```

### Batch Operation Methods

```gdscript
## Batch run (multiple contexts)
func run_batch(contexts: Array[ExecutionContext]) -> Dictionary

## Batch validate instructions
func validate_instructions_batch() -> Dictionary

## Batch get instruction info
func get_instructions_info_batch() -> Array[Dictionary]

## Batch add instructions
func add_instructions_batch(new_instructions: Array[BaseInstruction], position: int = -1) -> Dictionary
```

### Serialization and Cloning

```gdscript
## Serialize the runner
func serialize() -> Dictionary

## Deserialize the runner
func deserialize(data: Dictionary) -> void

## Clone the runner (deep-copies the instructions)
func clone() -> ActionRunner
```

### Debug Support

```gdscript
func enable_debug() -> void                    # Enable debug mode
func disable_debug() -> void                   # Disable debug mode
func is_debug_enabled() -> bool                # Check the debug state
func get_execution_tracker()                   # Get the execution tracker
```

---

## RuntimeActionRunnerInstance API

**File location**: `addons/fuse/core/runtime_action_runner_instance.gd`

**Class definition**:
```gdscript
class_name RuntimeActionRunnerInstance extends RefCounted
```

### Properties

```gdscript
var action_runner: ActionRunner                    # ActionRunner definition resource
var runtime_state: Dictionary = {}                 # Runtime state dictionary
var owner_trigger: Node                           # Trigger node owning this instance
var log_level: FuseLogger.LogLevel = FuseLogger.LogLevel.INFO
var use_instruction_pool: bool = true             # Whether the object pool is enabled
```

### Signals

```gdscript
signal execution_completed(total_time: float)
signal execution_failed(error_message: String)
signal execution_canceled(reason: String)
signal instruction_started(instruction: BaseInstruction)
signal instruction_completed(instruction: BaseInstruction)
signal all_instructions_completed()
```

### Constructor

```gdscript
func _init(definition: ActionRunner, trigger: Node) -> void
```

### Static Object Pool

```gdscript
## The shared InstructionInstancePool instance
static var _shared_instruction_pool: RefCounted = null

## Get the shared pool
static func get_shared_pool() -> RefCounted
```

### Performance Optimization Features

| Feature | Phase | Description |
|------|-------|------|
| Validation cache | 2.5 | Avoids re-validating the instruction array every frame |
| Signal batching mode | 2.5 | Reduces per-instruction signal emission overhead |
| State cache variables | 1 | Avoids frequent dictionary access |
| InstructionInstancePool | 2 | A shared object pool reduces instantiation overhead |
| CompiledInstructionSequence | 3 | Pre-caches description strings and method bindings |

---

## Execution Modes

### Sequential Execution (SEQUENTIAL)

```gdscript
ExecutionMode.SEQUENTIAL
```

Flow:
1. Iterate the `instructions` array
2. Check `_skip_instruction_count` — skip the given number of instructions
3. Check `_stop_execution` — conditional stop
4. Check `is_running` / `is_canceling`
5. Call `_execute_instruction(instruction, context)` to execute the instruction
   - Synchronous completion → check errors and timeout → continue with the next
   - Asynchronous completion → `await instruction.finished` → continue with the next
6. Emit the `instruction_completed` signal

### Parallel Execution (PARALLEL)

```gdscript
ExecutionMode.PARALLEL
```

Flow:
1. Start all instructions (without await)
2. Use `_wait_for_all_tasks()` to wait for all of them to finish
3. Use the `_SignalAggregator` inner class to aggregate completion events from multiple signals
4. Check for errors and emit `execution_failed` (if anything failed)

### Timeout Mechanism

```gdscript
# Total timeout calculation:
# Instruction timeout enabled → timeout = instruction_timeout * max(1, instructions.size())
# Not enabled                 → timeout = DEFAULT_TIMEOUT(30) + instructions.size() * 5.0

# On timeout → emit execution_failed(TIMEOUT_ERROR)
```

---

## Signals and Events

```gdscript
# ActionRunner signals
signal execution_started                                    # Execution started
signal instruction_started(instruction: BaseInstruction)     # Instruction started
signal instruction_completed(instruction: BaseInstruction)   # Instruction completed
signal execution_completed                                   # Execution completed
signal execution_failed(error_message: String)               # Execution failed
signal execution_canceled(reason: String)                    # Execution canceled
```

**Signal connection management**:

`_instruction_callback_cache: Dictionary` caches each instruction's callback, ensuring:

- All connections are disconnected via `_disconnect_all_signals()` when execution ends
- `_disconnect_instruction_signal()` disconnects using the cached callback
- **Memory-leak prevention**: `_SignalAggregator` has a `_disconnect_all()` mechanism

---

## Performance Optimizations

### Phase 1: State Cache Variables

```gdscript
# Cache variables in RuntimeActionRunnerInstance
var _is_running_cached: bool = false
var _is_canceling_cached: bool = false
var _context_cached: ExecutionContext = null
```

Avoids frequent `runtime_state` dictionary access by using member variables directly.

### Phase 2: Object Pool

```gdscript
# The shared InstructionInstancePool
var use_instruction_pool: bool = true
static var _shared_instruction_pool: RefCounted = null

# Get the shared pool
static func get_shared_pool() -> RefCounted:
    if not _shared_instruction_pool:
        _shared_instruction_pool = InstructionInstancePool.new(32, 128)
    return _shared_instruction_pool
```

### Phase 2.5: Signal Batching Mode

```gdscript
var _batch_signals: bool = false
var _pending_started_instructions: Array[BaseInstruction] = []
var _pending_completed_instructions: Array[BaseInstruction] = []
```

Buffers signals in batches, reducing high-frequency emission overhead (suited to scenarios that trigger many times per frame).

### Phase 3: Compilation Cache

```gdscript
var _compiled_cache: RefCounted = null  # CompiledInstructionSequence
```

All `RuntimeActionRunnerInstance`s share the same compilation cache, which pre-caches description strings and method bindings.

---

## Best Practices

### 1. Creating an ActionRunner

```gdscript
var runner = ActionRunner.new()
runner.execution_mode = ActionRunner.ExecutionMode.SEQUENTIAL
runner.stop_on_error = true

# Add an instruction
var instruction = PrintMessage.new()
instruction.message = "Hello"
runner.add_instruction(instruction)
```

### 2. Using RuntimeActionRunnerInstance

```gdscript
var runtime_instance = RuntimeActionRunnerInstance.new(runner, trigger_node)
runtime_instance.execution_completed.connect(_on_completed)
```

### 3. Cloning an ActionRunner

```gdscript
var cloned = original_runner.clone()  # Deep copy
```

### 4. Conditional Skip and Stop

```gdscript
# Inside a Condition:
# Skip the next N instructions
context.action_runner.set_skip_instruction_count(2)

# Stop the whole execution
context.action_runner.set_stop_execution(true, "条件未满足")
```

---

## Common Pitfalls

### Pitfall 1: Calling run() Multiple Times Concurrently

ActionRunner does not allow repeated calls while executing:

```gdscript
func run(context: ExecutionContext):
    if is_running:
        context.print_warning("ActionRunner is already running")
        return
```

**Solution**: create a new `ExecutionContext` for each run, or call `reset()` after the execution completes.

### Pitfall 2: Validation Cache Retains Stale Instruction State

After modifying the `instructions` array, the validation cache is not cleared automatically.

**Solution**: call `clear_validation_cache()` to force re-validation.

### Pitfall 3: Signal Leaks

An async instruction's `finished` signal is connected to the ActionRunner; if execution exits midway without disconnecting, signals keep arriving.

**Solution**: ActionRunner already manages the signal lifecycle internally via `_instruction_callback_cache`, making sure `_disconnect_all_signals()` is called in `_complete_execution()`.

### Pitfall 4: Race Conditions in Parallel Mode

In parallel execution, multiple instructions share the same `ExecutionContext`; simultaneous variable writes cause races.

**Solution**: in parallel mode, isolate state using `LOCAL`-scope variables from `VariableOperations`, or manage signals inside the instruction with `register_timer_callback()`.

---

## Reference Documents

- [ExecutionContext and Diagnostics Guide](execution-context-diagnostics-guide.md)
- [FuseLogger Logging System Guide](fuse-logger-guide.md)
- [Object Pool System Guide](object-pool-guide.md)
- [Instruction Creation Guide](instruction-creation-guide.md)
- [RuntimeInstructionInstance Guide](runtime-instruction-instance-guide.md)

---

**Document maintainer**: Fuse development team | **Last updated**: 2026-07-07 | **Godot version**: 4.7
