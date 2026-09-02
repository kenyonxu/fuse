> 🌐 [**中文版**](../../../zh_CN/system_docs/analysis/runtime_instance_analysis.md) | English

# Runtime Instance Trio Analysis Report


> **Analyzed as of**: 2026-07-07 (each article verified against code during the same-day full documentation audit; implementation evolution after this point defers to the source code; for recently verified mechanical conclusions see the threading / runtime_instance / preset_nested articles)
## Document Overview

This report presents a focused analysis of a core piece of the Fuse v2.0 architecture — the **runtime instance trio**. The trio consists of three cooperating `RefCounted` classes that together solve one core engineering problem: **letting the same `.tres` Resource definition be shared by multiple Triggers while their respective runtime states stay unpolluted**.

| Class | Source file | Lines | Responsibility |
|------|--------|------|------|
| `RuntimeEventInstance` | [runtime_event_instance.gd](../../../../core/runtime_event_instance.gd) | 289 lines | Wraps `BaseEvent`, holds event-level runtime state, forwards and filters the triggered signal |
| `RuntimeInstructionInstance` | [runtime_instruction_instance.gd](../../../../core/runtime_instruction_instance.gd) | 549 lines | Wraps `BaseInstruction`, holds per-instruction execution state, pause/resume/timeout control |
| `RuntimeActionRunnerInstance` | [runtime_action_runner_instance.gd](../../../../core/runtime_action_runner_instance.gd) | 692 lines | Wraps `ActionRunner`, schedules the instruction sequence, manages parallel/sequential execution, batch signals, object pool integration |

**Common base class:** `RefCounted` (not in the scene tree, GC-able, lightweight)
**Annotations:** `@tool` (usable in editor mode)

---

## 1. Class Overview and Responsibilities

### 1.1 Why the Trio Is Needed

In the v1 architecture, event state was stored directly on the `BaseEvent` resource instance. When a single `.tres` event resource was referenced (shared) by two Triggers at the same time:

```
Trigger A ──┐
            ├──→ the same OnArea2DEnter.tres (holding trigger_count = 5)
Trigger B ──┘
```

Both Triggers read and wrote the same `trigger_count`, causing states to overwrite each other, cooldown timers to be reset by the other side, and signals to be broadcast to the wrong target. v2.0 introduced the trio, forcibly separating **"Resource definition (immutable, shareable, serializable)"** from **"runtime state (mutable, instance-private, non-serializable)"**:

```
Trigger A ──→ RuntimeEventInstance(OnArea2DEnter.tres, A)  [trigger_count=5]
Trigger B ──→ RuntimeEventInstance(OnArea2DEnter.tres, B)  [trigger_count=2]
                       ↑
            two independent runtime_state Dictionaries
            sharing the same immutable event_definition
```

The Resource only describes "what to do"; the trio records "how far along it is".

### 1.2 Responsibilities of Each Member of the Trio

| Class | Role | Owner | What it holds |
|----|------|--------|----------|
| `RuntimeEventInstance` (REI) | Event-level state container + signal filter | Trigger | One `BaseEvent` resource + that Trigger's event state |
| `RuntimeActionRunnerInstance` (RARI) | Instruction sequence scheduler | Trigger | One `ActionRunner` resource + execution flow state + RII array |
| `RuntimeInstructionInstance` (RII) | Execution handle for a single instruction | RARI | One `BaseInstruction` + the pause/timeout/completion state of that execution |

Hierarchy: `Trigger → REI / RARI → RII`. REI and RARI are peers (both held directly by the Trigger), while RII is created / acquired from the pool on demand by RARI when executing the instruction sequence.

---

## 2. Core Properties

### 2.1 RuntimeEventInstance

| Property | Type | Default | Description |
|------|------|--------|------|
| `event_definition` | `BaseEvent` | — | Event definition resource (shared, read-only semantics) |
| `runtime_state` | `Dictionary` | `{}` | Trigger-private event runtime state |
| `owner_trigger` | `Node` | — | The Trigger node that owns this instance (used for signal filtering) |
| `log_level` | `FuseLogger.LogLevel` | `INFO` | Log level |

**Signal:** `triggered(context: Node)` — the forwarded, independent event trigger signal.

### 2.2 RuntimeInstructionInstance

| Property | Type | Default | Description |
|------|------|--------|------|
| `instruction` | `BaseInstruction` | — | Instruction definition resource |
| `runtime_state` | `Dictionary` | `{}` | Runtime state of this execution (including timer/elapsed_time/is_paused, etc.) |
| `execution_context` | `ExecutionContext` | — | Execution context |
| `owner_runner` | `RuntimeActionRunnerInstance` | — | Back-reference so the instruction can write state back |
| `log_level` | `FuseLogger.LogLevel` | `INFO` | Synced from the instruction |
| `execution_timeout` | `float` | `0.0` | Execution timeout (0 = unlimited) |
| `_is_executing` / `_is_completed` / `_is_paused` / `_has_error` | `bool` | `false` | Internal execution state machine flags |
| `_error_message` | `String` | `""` | Error message |
| `_timeout_timer` | `SceneTreeTimer` | `null` | Timeout timer |
| `_paused_time` / `_pause_start_time` | `float` | `0.0` | Accumulated pause time |
| `_connected_timer_callbacks` | `Array[Callable]` | `[]` | Connected timer signals (for cleanup) |

**Signals (5):** `finished()`, `error_occurred(message: String)`, `paused()`, `resumed()`, `timeout()`.

### 2.3 RuntimeActionRunnerInstance

| Property | Type | Default | Description |
|------|------|--------|------|
| `action_runner` | `ActionRunner` | — | ActionRunner definition resource |
| `runtime_state` | `Dictionary` | `{}` | Sequence-level execution state (is_running/current_instruction_index, etc.) |
| `owner_trigger` | `Node` | — | The Trigger that owns this instance |
| `log_level` | `FuseLogger.LogLevel` | `INFO` | Synced from the ActionRunner |
| `_instruction_instances` | `Array[RuntimeInstructionInstance]` | `[]` | Currently held RII list (returned to the pool during cleanup) |
| `_instructions_validated` / `_validated_instruction_count` | `bool` / `int` | `false` / `-1` | Validation cache (Phase 2.5) |
| `_batch_signals` / `_pending_started_instructions` / `_pending_completed_instructions` | `bool` / `Array` | `false` / `[]` | Batch signal mode (Phase 2.5) |
| `_is_running_cached` / `_is_canceling_cached` / `_context_cached` | `bool`/`bool`/`ExecutionContext` | `false`/`false`/`null` | Performance cache variables (Phase 1), avoiding dictionary access on hot paths |
| `use_instruction_pool` | `bool` | `true` | Whether the object pool is enabled |
| `_shared_instruction_pool` (static) | `RefCounted` | `null` | Globally shared `InstructionInstancePool` instance |

**Signals (6):** `execution_completed(total_time: float)`, `execution_failed(error_message: String)`, `execution_canceled(reason: String)`, `instruction_started(instruction)`, `instruction_completed(instruction)`, `all_instructions_completed()`.

### 2.4 Default Contents of the Three runtime_state Types

| Instance | Initialized in | Key entries |
|------|----------|--------|
| REI | `_initialize_runtime_state()` calls `event.get_default_runtime_state()` for self-declaration; `_ensure_base_states()` acts as a fallback | `initialized`, `trigger_count`, `last_trigger_time` + entries appended by Event subclasses (e.g. `object_cooldowns`, `entered_bodies`) |
| RII | `_initialize_runtime_state()` calls `instruction.get_default_runtime_state()` for self-declaration; `_ensure_base_states()` acts as a fallback | `initialized`, `execution_status`(=PENDING) + `timer`, `elapsed_time`, `is_running` |
| RARI | `_initialize_runtime_state()` hardcoded | `is_running`, `is_canceling`, `cancellation_reason`, `current_context`, `current_instruction_index`, `execution_start_time`, `execution_end_time`, `has_triggered`, `fuse_error` |

---

## 3. Key Methods

### 3.1 RuntimeEventInstance

#### `_init(definition: BaseEvent, trigger: Node)` — Constructor

```
Execution flow (runtime_event_instance.gd:20-32):
  1. Save event_definition and owner_trigger
  2. _initialize_runtime_state()  // copy/initialize runtime_state
  3. event_definition.triggered.connect(_on_event_triggered)
     // hooking up the forwarding callback at construction time is the key to the relay filter
```

#### `_on_event_triggered(context: Node)` — Filtered Signal Forwarding

```
Execution flow (runtime_event_instance.gd:104-115):
  1. Check whether context.get_meta("trigger") equals owner_trigger
  2. Not equal → silent return (not this instance's event)
  3. Equal → triggered.emit(context), forwarding to the Trigger
```

This is the core mechanism for state isolation when Event resources are shared: BaseEvent writes a "trigger" meta onto the context via `_emit_triggered()` to identify the source, and the REI filters on it, ensuring the signal only reaches its owning Trigger.

#### `start_listening()` / `stop_listening()` — Proxy Methods

Called by MultiEventTrigger:
- `start_listening()` → `event_definition.initialize_with_runtime_instance(owner_trigger, self)`
- `stop_listening()` → `event_definition.terminate(owner_trigger)`

#### State Read/Write API

`get_runtime_state(key)`, `set_runtime_state(key, value)`, `has_runtime_state(key)`, `remove_runtime_state(key)`, `get_all_runtime_states()` (returns a copy), `reset_runtime_state()` (clears and re-initializes), `update_trigger_stats()` (increments trigger_count and refreshes last_trigger_time).

#### `cleanup()` — Cleanup

Disconnects the `event_definition.triggered` signal connection, clears runtime_state, and nulls out references.

### 3.2 RuntimeInstructionInstance

#### `_init(inst, context, runner)` — Constructor

Syncs the instruction's `log_level` and calls `_initialize_runtime_state()`.

#### `execute_sync() -> bool` — Execution Entry Point

Returns `true` when completed synchronously; `false` means an async await is needed.

```
Execution flow (runtime_instruction_instance.gd:102-163):
  1. Re-entrancy guard: if _is_executing or _is_completed is already true → return true directly
  2. Reset state machine flags
  3. runtime_state["execution_status"] = RUNNING
  4. _start_timeout_timer()  // if execution_timeout > 0
  5. Branch:
     a. instruction.has_method("execute_with_runtime_instance"):
        - connect instruction.finished → _on_instruction_finished
        - call instruction.execute_with_runtime_instance(self)
        - if completed synchronously without the signal firing → manually _complete_execution()
     b. otherwise _execute_legacy_mode() (compatibility with legacy instructions)
  6. Return the synchronous-completion flag
```

#### `_complete_execution()` / `_handle_execution_error(msg)` — Terminal State Transitions

Includes multi-fire protection on `_is_completed`. The error path sets `execution_status` to `ERROR` and emits `error_occurred` and `finished`.

#### `pause()` / `resume()` — Pause/Resume

Flips `_is_paused`, accumulates `_paused_time`, and notifies subclasses through the instruction's `on_runtime_pause(runtime_instance)` / `on_runtime_resume(runtime_instance)` hooks (BaseInstruction's default implementations are empty).

#### `cancel()` — Cancellation

Sets `execution_status = CANCELLED` and calls `_cleanup_runtime_resources()` to clean up timers/signal connections.

#### `_start_timeout_timer()` / `_on_execution_timeout()` — Timeout

Based on `SceneTree.create_timer()`. Note that a `SceneTreeTimer` cannot be actively cancelled; the only option is to disconnect the signal (explicitly stated in the `_stop_timeout_timer()` comment).

#### Pooling Support Methods (Phase 2)

- `reinitialize(inst, context, runner)` — resets all state after being taken from the pool and re-runs `_initialize_runtime_state()`.
- `reset_for_pool()` — cleanup before returning to the pool (disconnects signals, clears state, nulls references, clears callback tracking).
- `register_timer_callback(cb)` / `unregister_timer_callback(cb)` — tracks callbacks connected externally to the timer for easier cleanup.

### 3.3 RuntimeActionRunnerInstance

#### `_init(definition, trigger)` — Constructor

Syncs the ActionRunner's `log_level` and calls `_initialize_runtime_state()`.

#### `run(context: ExecutionContext)` — Execution Entry Point

```
Execution flow (runtime_action_runner_instance.gd:102-134):
  1. _is_running_cached check → if already running, emit a localized error and return
  2. validate_instructions() → on failure, emit execution_failed and return
  3. Set the cache variables _is_running_cached / _is_canceling_cached / _context_cached
  4. Sync into runtime_state (used for persistence)
  5. context.set_action_runner(self)  // used by condition-check instructions
  6. _execute_instructions(context)  // dispatch by execution_mode
```

#### `cancel_execution(reason)` / `set_stop_execution(stop, reason)`

The latter is an API compatibility method that forwards internally to the former. `set_stop_execution(true, reason)` is equivalent to `cancel_execution(reason)`.

#### `validate_instructions()` — Cached Validation

```
Execution flow (runtime_action_runner_instance.gd:174-196):
  - Cache hit (_instructions_validated && count unchanged) → skip
  - Otherwise do a full traversal check and update the cache on success
  - invalidate_validation_cache() is called manually when the instruction array changes
```

#### `_execute_instructions_sequential()` — Sequential Execution

Iterates by index:
1. Each round checks `_is_running_cached` (cache variable, hot-path performance optimization)
2. `_acquire_instruction_instance()` acquires an RII from the pool
3. `_emit_instruction_started()` (with batch mode support)
4. `runtime_instruction.execute_sync()`
5. Synchronous completion → check errors (controlled by `stop_on_error`) → `_emit_instruction_completed()` → continue
6. Async → `await runtime_instruction.finished` → error check

#### `_execute_instructions_parallel()` + `_wait_for_all_parallel_tasks()` — Parallel Execution

Starts all instructions (without awaiting), then waits for all to complete using a RefCounted-wrapped counter (`_counter.set_meta("remaining", n)`). The counter uses meta to work around GDScript closures being unable to modify captured primitive-type variables.

#### `_acquire_instruction_instance()` / `_cleanup_instruction_instances()` — Pooling Integration

```
Pooled mode:
  pool.acquire(instruction, context, self)         // reuse or create
  pool.release(runtime_instruction)                 // return (calls reset_for_pool internally)
Non-pooled mode:
  RuntimeInstructionInstance.new(...)
  instance.cleanup()
```

#### Batch Signal Mode (Phase 2.5)

When enabled via `set_batch_signal_mode(true)`, the `instruction_started/completed` signals are cached in `_pending_started/completed_instructions` and emitted together by `_flush_pending_signals()` during `_complete_execution()`, reducing per-instruction signal overhead in high-frequency trigger scenarios. MultiEventTrigger enables this mode by default.

#### `_get_or_create_compiled_cache()` — Phase 3 Compilation Cache

Gets the shared `CompiledInstructionSequence` from the ActionRunner, recompiles on demand, and caches results such as `get_description()`.

#### `cleanup()` — Cleanup

Calls `cancel_execution()` and `_cleanup_instruction_instances()` (returns all RIIs to the pool), clears pending signals, resets the validation cache, clears runtime_state, and nulls out references.

---

## 4. Architectural Relationships

### 4.1 Overall Collaboration Chain

```
                    ┌──────────────────────── Trigger (Node) ────────────────────────┐
                    │                                                                │
                    │  Holds and creates:                                            │
                    │    _runtime_event_instances[i]   → RuntimeEventInstance        │
                    │    _runtime_action_instances[i]  → RuntimeActionRunnerInstance │
                    │                                                                │
                    │  Signal connections:                                           │
                    │    REI.triggered      → Trigger._on_event_fired                │
                    │    RARI.execution_*  → Trigger._on_action_*                    │
                    │                                                                │
                    └────────────────────────────────────────────────────────────────┘
Upstream (Resource definitions, shareable)     Downstream (runtime instances, private)
       │                                              │
       ▼                                              ▼
┌──────────────┐    _emit_triggered         ┌──────────────────────┐
│  BaseEvent   │ ─────triggered─────────→   │ RuntimeEventInstance │
│  (.tres)     │    (sets trigger meta)     │  - runtime_state     │
└──────────────┘                            │  - owner_trigger     │
                                            │  - filters by meta   │
                                            └──────────┬───────────┘
                                                       │ triggered (filtered)
                                                       ▼
                                            Trigger._on_event_fired()
                                                       │
                                                       │ create ExecutionContext
                                                       │ condition checks
                                                       ▼
┌──────────────┐    run(context)            ┌──────────────────────────┐
│ ActionRunner │ ◀──────────────────────   │ RuntimeActionRunnerInst  │
│  (.tres)     │                            │  - runtime_state         │
│  instructions│                            │  - _instruction_instances│
└──────┬───────┘                            │  - pooling/batch/cache   │
       │                                    └────────────┬─────────────┘
       │ execute_sync                                    │ _acquire_instruction_instance
       ▼                                                 ▼ (pooled)
┌─────────────────┐    execute_with_runtime   ┌─────────────────────────┐
│ BaseInstruction │ ◀─────────────────────── │ RuntimeInstructionInst  │
│   (.tres)       │                           │  - runtime_state        │
│  get_default_   │                           │  - pause/timeout/cancel │
│  runtime_state  │                           │  - finished signal      │
└─────────────────┘                           └─────────────────────────┘
```

### 4.2 State Isolation in Shared Scenarios

When two Triggers share the same Event resource:

```
Triggers A and B both reference OnTimer.tres (the same resource)

Trigger A._ready():
  REI_A = RuntimeEventInstance.new(OnTimer.tres, A)
    - runtime_state = {trigger_count:0, last_trigger_time:0, ...}  ← private to A
    - OnTimer.tres.triggered.connect(_on_event_triggered)

Trigger B._ready():
  REI_B = RuntimeEventInstance.new(OnTimer.tres, B)
    - runtime_state = {...}  ← private to B (invisible to A and vice versa)
    - OnTimer.tres.triggered.connect(_on_event_triggered)
```

The `OnTimer.tres.triggered` signal has **two** subscribers (REI_A and REI_B). When the event fires, BaseEvent writes the `trigger = owner_node` meta onto the context via `_emit_triggered(context, owner_node)`, and each REI checks the meta:

- `REI_A._on_event_triggered`: `context.trigger == A` → forwards
- `REI_B._on_event_triggered`: `context.trigger != B` → silently drops

This way the signal reaches exactly its owning Trigger, and the state dictionaries are fully isolated.

### 4.3 Relationship with BaseTrigger

`BaseTrigger` ([base_trigger.gd:57-60](../../../../core/base_trigger.gd)) delegates access to the trio down to subclasses through two abstract methods:

```gdscript
@abstract func get_runtime_event_instance_at(index: int) -> RuntimeEventInstance
@abstract func get_action_runner_instance_at(index: int) -> RuntimeActionRunnerInstance
```

Implementations in concrete subclasses:

- **Trigger** (single event): holds a single `_runtime_event_instance` and `_runtime_action_runner_instance`; `get_*_at(0)` returns them directly.
- **MultiEventTrigger** (multi-event binding): holds two arrays `_runtime_event_instances[]` and `_runtime_action_instances[]`, returning by index.

`BaseTrigger`'s own methods such as `_check_cooldown()`, `_clear_cooldown_state()`, and `_sync_event_args_to_context()` read and write the REI's `runtime_state` (e.g. `last_trigger_time`, `object_cooldowns`) directly through `get_runtime_event_instance_at()` — this is exactly the benefit of moving state out of the Resource into Runtime instances: cooldown counters are now private per Trigger.

---

## 5. Collaboration Patterns

### 5.1 Full Trigger Execution Chain

Taking one complete trigger in MultiEventTrigger as an example (with line numbers):

```
[1] Event subclass detects that its condition is met
    └─ BaseEvent._emit_triggered(context, owner_node)
       └─ context.set_meta("trigger", owner_node)       # base_event.gd
       └─ triggered.emit(context)

[2] RuntimeEventInstance._on_event_triggered(context)   # runtime_event_instance.gd:104
    └─ if context.get_meta("trigger") != owner_trigger: return
    └─ triggered.emit(context)                          # forward

[3] MultiEventTrigger._on_event_fired(context, index)   # multi_event_trigger.gd:242
    └─ trigger_once / is_running / cooldown / condition checks
    └─ action_instance.run(execution_context)            # multi_event_trigger.gd:286

[4] RuntimeActionRunnerInstance.run(context)             # runtime_action_runner_instance.gd:102
    └─ validate_instructions()
    └─ _execute_instructions(context)
       └─ _execute_instructions_sequential / _parallel

[5] RARI._execute_instructions_sequential
    └─ for i in instructions:
       ├─ runtime_instruction = _acquire_instruction_instance(...)  # acquire RII from the pool
       ├─ _emit_instruction_started(instruction)                   # batch mode: cache
       ├─ runtime_instruction.execute_sync()
       │  └─ instruction.execute_with_runtime_instance(self)
       │     └─ actual work (modifies runtime_instruction.runtime_state)
       ├─ synchronous completion → _emit_instruction_completed(instruction)
       └─ async → await runtime_instruction.finished

[6] All completed → _complete_execution()
    └─ _flush_pending_signals()       # batch-emit the cached started/completed
    └─ execution_completed.emit(total_time)
    └─ all_instructions_completed.emit()

[7] Trigger._on_action_completed() receives
```

### 5.2 Pooling Collaboration

`RuntimeActionRunnerInstance` holds a static shared pool (`InstructionInstancePool.new(32, 128)` on the first `get_shared_pool()` call). All RARI instances share this pool:

```
RARI_A executes an instruction sequence:
  acquire() → pool empty → RuntimeInstructionInstance.new()  [create]
  ...
  release(rii) → rii.reset_for_pool() → placed into the pool        [return]

RARI_B executes later:
  acquire() → pool non-empty → rii.reinitialize(...)            [reuse, saving the new() overhead]
```

Pool statistics (`get_statistics()`) expose `pool_size`, `total_created`, `total_reused`, `peak_usage`, `reuse_ratio`, and `efficiency_score`, useful for tuning.

### 5.3 Lifecycle

| Phase | Trigger behavior | Trio behavior |
|------|--------------|------------|
| **Creation** | In `_initialize_runtime_instances()`: `RuntimeEventInstance.new(event, self)` and `RuntimeActionRunnerInstance.new(action_runner, self)` | Constructors initialize runtime_state and connect the forwarding signal (REI only) |
| **Start** | `_start_all_events()` → `event_instance.start_listening()` | REI proxies to `event.initialize_with_runtime_instance()` |
| **Execution** | Signal callback `_on_event_fired` → `action_instance.run()` | RARI schedules → acquires RII from the pool → RII executes |
| **Reset (pooled)** | `_on_pool_reset()` | REI/RARI runtime_state each re-initialized |
| **Stop** | `_stop_all_events()` → set `_runtime_instance_ref` → `event.terminate()` | REI stops listening |
| **Cleanup** | `_cleanup_runtime_instances()` | REI/RARI each `cleanup()`; RARI internally returns all RIIs to the pool |

**Key detail (multi_event_trigger.gd:209-216):** before calling `event.terminate()`, MultiEventTrigger explicitly sets `binding.event._runtime_instance_ref = event_instance`, **fixing** a bug where terminate internally read the wrong runtime_state when multiple pooled objects shared the same Event resource.

---

## 6. Self-Declaring State Pattern

The trio follows a unified state declaration convention:

### 6.1 Pattern Rules

1. **Resource subclasses** (`BaseEvent` / `BaseInstruction`) override `get_default_runtime_state() -> Dictionary` to declare which state keys and default values they need.
2. **Runtime instances** call `event/instruction.get_default_runtime_state()` at construction time, deep-copy it with `duplicate(true)`, and write it into their own `runtime_state`.
3. **`_ensure_base_states()`** acts as a safety net to ensure common base keys exist (e.g. `initialized`, `trigger_count`, `execution_status`).
4. **Runtime reads/writes** all go through `runtime_instance.set_runtime_state(key, value)` / `get_runtime_state(key)`, never touching the Resource itself.

### 6.2 BaseEvent Default State (base_event.gd)

```gdscript
func get_default_runtime_state() -> Dictionary:
    return {
        "initialized": true,
        "trigger_count": 0,
        "last_trigger_time": 0.0
    }
```

Subclasses inherit and append via `super.get_default_runtime_state()`.

### 6.3 BaseInstruction Default State (base_instruction.gd:1247)

```gdscript
func get_default_runtime_state() -> Dictionary:
    return {
        "initialized": true,
        "execution_status": ExecutionStatus.PENDING,
        "timer": null,
        "elapsed_time": 0.0,
        "is_running": false
    }
```

### 6.4 Backward-Compatible Legacy Mode

`RuntimeEventInstance._initialize_runtime_state()` checks `event.has_method("get_default_runtime_state")`:

- Present → self-declaring mode
- Absent → the match branches of `_initialize_runtime_state_legacy()` (dispatched by the event_type string, e.g. `"timer"`, `"input"`, `"area"`)

`RuntimeInstructionInstance` is similar: instructions that do not implement self-declaration fall back to the default `{timer, elapsed_time, is_running}`.

---

## 7. Signal Forwarding Mechanism

### 7.1 Filtered Forwarding in RuntimeEventInstance

The REI is a relay layer between BaseEvent and the Trigger, with two purposes:

1. **Isolate the signal source**: BaseEvent is a shared Resource whose `triggered` signal is subscribed to by all REIs; the REI provides an independent `triggered` signal to the Trigger so that each Trigger only receives its own events.
2. **Filter out interference**: through `context.trigger` meta validation, events not belonging to this instance are dropped.

```
BaseEvent.triggered ──┬──→ REI_A._on_event_triggered ──→ (meta != A) dropped
                      │
                      └──→ REI_B._on_event_triggered ──→ (meta == B) → REI_B.triggered.emit
                                                                │
                                                                ▼
                                                       Trigger_B._on_event_fired
```

### 7.2 The finished Signal of RuntimeInstructionInstance

The RII's `finished` signal is emitted in the following cases:

- `_complete_execution()` — normal completion
- `_handle_execution_error()` — execution error
- `_on_execution_timeout()` — timeout

RARI's sequential execution awaits async instructions via `await runtime_instruction.finished`; parallel execution tracks full completion with a counter. Multi-fire protection is implemented by the `_is_completed` flag.

### 7.3 Batch Signals of RuntimeActionRunnerInstance

| Signal | Emitted from | Purpose |
|------|--------|------|
| `execution_completed(total_time)` | `_complete_execution()` | Whole sequence completed |
| `execution_failed(error_message)` | Validation failure / instruction error (stop_on_error) | Sequence failed |
| `execution_canceled(reason)` | Exit triggered by `cancel_execution` during the execution loop | Cancellation |
| `instruction_started(instruction)` | `_emit_instruction_started()` | Single instruction started (batchable) |
| `instruction_completed(instruction)` | `_emit_instruction_completed()` | Single instruction completed (batchable) |
| `all_instructions_completed()` | `_complete_execution()` | Emitted together with execution_completed |

In batch mode, `instruction_started/completed` are cached into `_pending_*_instructions` and emitted together in `_flush_pending_signals()`, reducing per-instruction signal overhead in high-frequency trigger scenarios.

---

## 8. Performance Optimizations

The trio is the main carrier of Fuse's performance optimizations, hosting multiple rounds of optimization (Phase 1/2/2.5/3):

| Optimization | Instance | Description |
|--------|----------|------|
| State cache variables (`_is_running_cached` etc.) | RARI | Phase 1: avoids dictionary access on hot paths; `is_running()` returns the cache directly |
| Object pool (`InstructionInstancePool`) | RARI + RII | Phase 2: reuses RIIs, saving the ~25μs `new()` overhead |
| Pooling lifecycle methods (`reinitialize`/`reset_for_pool`) | RII | Phase 2: standard interface for pooled acquisition/return |
| Validation cache (`_instructions_validated`) | RARI | Phase 2.5: skips validation when the instruction count is unchanged |
| Batch signal mode (`_batch_signals`) | RARI | Phase 2.5: coalesces instruction_started/completed under high-frequency triggering |
| Compilation cache (`CompiledInstructionSequence`) | RARI + ActionRunner | Phase 3: caches results such as `get_description()` |
| Log-level pre-check (`should_log_debug`) | RARI / RII | Avoids needless log method calls on hot paths |
| Static shared pool | RARI | All RARIs share one pool, maximizing reuse |

### Potential Performance Issues

1. **Dictionary operation overhead**: the REI/RII `set/get_runtime_state` involves Dictionary hash lookups, which may become a bottleneck in high-frequency events.
2. **Memory spikes from batch signal caching**: for long instruction sequences, `_pending_started/completed_instructions` may accumulate a large number of BaseInstruction references.
3. **SceneTreeTimer cannot be cancelled**: the timeout timer can only be detached by disconnecting the signal; the timer object itself expires naturally (though with no side effects).
4. **Multiple REI subscriptions on shared Event resources**: if N Triggers share the same Event, BaseEvent.triggered has N connections and every trigger iterates N callbacks (though most are dropped by the meta filter).

---

## 9. Overall Assessment

### Strengths

1. **Thoroughly solves the state-pollution problem of resource sharing** — this was the core design goal of v2.0, and the trio solves it completely via the combination of runtime_state privatization + trigger meta filtering.
2. **Unified "self-declaring state" pattern** — Event/Instruction declare state through the same `get_default_runtime_state()` interface, consumed uniformly by the trio; the convention is clear.
3. **Clear division of responsibilities** — REI handles event state/signal filtering, RARI handles sequence scheduling/performance optimization, RII handles single-instruction execution/pause/timeout; no responsibility overreach.
4. **Pooling, batching, and caching layered on top of each other** — performance optimization is systematic and phased (Phase 1/2/2.5/3), and observable (`get_statistics()`, `get_info()`).
5. **Backward compatible with legacy code** — through `has_method` detection and legacy branches, old Events/Instructions work without immediate migration.
6. **Clear lifecycle** — each has explicit reclamation interfaces such as `cleanup()`, `reset_for_pool()`, and `reinitialize()`.

### Weaknesses

1. **No unified base class for the trio** — the three classes each duplicate `runtime_state`, `get/set_runtime_state`, `_log_*`, `_initialize_runtime_state`, `cleanup`, and similar logic; a shared `RuntimeInstanceBase` abstraction is missing.
2. **RARI is too large (692 lines)** — it simultaneously handles scheduling, pooling, batch signals, validation cache, compilation cache, and error handling, violating the single-responsibility principle. Splitting out an `InstructionScheduler` / `SignalBatcher` could be considered.
3. **Dual representation of state (cache variables + runtime_state)** — `_is_running_cached` and `runtime_state["is_running"]` must be synced manually, posing a consistency risk (although sync code currently exists in both places).
4. **Legacy branch maintenance burden** — the match branches in `_initialize_runtime_state_legacy()` must be maintained manually as new event types are added; coexisting with the self-declaring pattern adds cognitive load.
5. **Scattered RII error paths** — the three termination paths `_handle_execution_error` / `_on_execution_timeout` / `cancel` have similar but scattered state-transition logic, prone to future inconsistency.
6. **Timeout mechanism is pooling-unfriendly** — when a timed-out RII is returned to the pool, it must be ensured that `_timeout_timer` has been disconnected (`reset_for_pool` handles this), but the SceneTreeTimer still wakes the main loop when it expires naturally.

---

**Maintained by**: Fuse development team
**Last updated**: 2026-07-07
**Version**: 1.0.0
**Analyzed targets**: RuntimeEventInstance (289 lines) / RuntimeInstructionInstance (549 lines) / RuntimeActionRunnerInstance (692 lines)
