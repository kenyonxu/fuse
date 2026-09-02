> 🌐 [**中文版**](../../../zh_CN/system_docs/analysis/action_runner_analysis.md) | English

# ActionRunner Analysis Report


> **Analyzed as of**: 2026-07-07 (each article verified against code during the same-day full documentation audit; implementation evolution after this point defers to the source code; for recently verified mechanical conclusions see the threading / runtime_instance / preset_nested articles)
> **Baseline code**: `addons/fuse/core/base/action_runner.gd` (1041 lines)
> **Related classes**: `RuntimeActionRunnerInstance` (`core/runtime_action_runner_instance.gd`, 691 lines), `CompiledInstructionSequence` (`core/execution/compiled_instruction_sequence.gd`, 142 lines)
> **Audit correction**: an earlier audit misjudged the three directories `core/execution`, `core/pooling`, `core/serialization` as "missing / ghost references / runtime crashes". Direct inspection proved this a **misjudgment** — the three directories and the `CompiledInstructionSequence` / `InstructionInstancePool` / `InstructionSerializer` classes **all really exist**: the `CompiledInstructionSequenceClass` preload at `action_runner.gd:9` is in effect; the `InstructionSerializer` class definition is complete (the preload at `action_runner.gd:6` is commented out, but the class still exists under the `serialization/` directory). This document reflects the fact that "code references are complete" and does not propagate the misjudgment.

## Document Overview

This report describes the instruction execution core of the Fuse visual programming system — `ActionRunner` (the Resource definition) and its runtime wrapper `RuntimeActionRunnerInstance` (RefCounted). Together they form the "**resource definition + runtime instance**" two-layer architecture, the standard shape since v2.0. This document uses the current-state description style (the critiques about "naive timeouts / parallel races / code duplication" from the early "criticism + improvement suggestions" draft have been fully superseded by the v2.0 implementation and are no longer listed as items to improve).

## 1. Classes and Inheritance

```gdscript
# action_runner.gd:1-3
@tool
@icon("res://addons/fuse/icons/action_runner.svg")
class_name ActionRunner extends Resource
```

```gdscript
# runtime_action_runner_instance.gd:2-3
@tool
class_name RuntimeActionRunnerInstance extends RefCounted
```

`ActionRunner` is a `Resource`, holding serializable instruction definitions and configuration; `RuntimeActionRunnerInstance` is a `RefCounted` held by Triggers, carrying the runtime state of each execution. The `RefCounted` choice makes it garbage-collectable and avoids long-term Node references.

## 2. Core Properties

### 2.1 ActionRunner (resource definition layer)

| Property | Type | Location | Description |
|------|------|------|------|
| `instructions` | `Array[BaseInstruction]` | :12 | The instruction sequence; the setter clears `_validation_cache` |
| `execution_mode` | `ExecutionMode` enum | :18 | `SEQUENTIAL` / `PARALLEL` |
| `stop_on_error` | `bool` | :23 | Whether to stop after the first error |
| `log_level` | `FuseLogger.LogLevel` | :28 | Log level (delegated to FuseLogger) |
| `enable_instruction_timeout` | `bool` (@export) | :31 | Enable custom per-instruction timeout (default `false`) |
| `instruction_timeout` | `float` (@export) | :36 | Per-instruction timeout in seconds; the setter clamps the minimum to `0.1` (default `5.0`) |
| `_compiled_cache` | `RefCounted` | :64 | The shared `CompiledInstructionSequence` cache |
| `_validation_cache` | `Dictionary` | :50 | Validation cache, invalidated when the instruction array changes |
| `_fuse_error` | `FuseError` | :49 | Most recent error instance (unified error handling) |

### 2.2 RuntimeActionRunnerInstance (runtime layer)

| Property | Type | Location | Description |
|------|------|------|------|
| `action_runner` | `ActionRunner` | :25 | Reference to the resource definition |
| `owner_trigger` | `Node` | :27 | The trigger node owning this instance |
| `runtime_state` | `Dictionary` | :26 | Runtime state dictionary (`is_running` / `cancellation_reason` / `current_instruction_index` etc.) |
| `_instruction_instances` | `Array[RuntimeInstructionInstance]` | :31 | Runtime instruction instances (state isolation) |
| `_instructions_validated` / `_validated_instruction_count` | `bool` / `int` | :35-36 | Validation cache (Phase 2.5) |
| `_batch_signals` | `bool` | :40 | Batch signal mode switch |
| `_pending_started_instructions` / `_pending_completed_instructions` | `Array[BaseInstruction]` | :41-42 | Instruction buffers awaiting batch emission |
| `_is_running_cached` / `_is_canceling_cached` / `_context_cached` | `bool` / `bool` / `ExecutionContext` | :46-48 | State cache variables (Phase 1) |
| `use_instruction_pool` | `bool` | :52 | Whether the object pool is enabled |
| `_shared_instruction_pool` | `RefCounted` (static) | :55 | Globally shared `InstructionInstancePool` |

## 3. Execution Modes and the Unified Execution Entry

The execution mode is defined by the enum (`action_runner.gd:67-70`):

```gdscript
enum ExecutionMode {
    SEQUENTIAL,    # sequential execution
    PARALLEL       # parallel execution
}
```

- **Sequential mode** (`_run_sequential`): executes instructions in order, supporting mixed sync/async. The unified entry `_execute_instruction()` wraps `instruction.execute_sync()` and decides from the return value whether to `await`. It integrates the condition-skip mechanism (`_skip_instruction_count`) and the external stop mechanism (`_stop_execution`).
- **Parallel mode** (`_run_parallel`): starts all instructions simultaneously, uses an internal aggregator to wait for all to complete, collects errors, and reports them uniformly via `execution_failed`.
- `RuntimeActionRunnerInstance` implements the same execution-mode dispatch logic (`runtime_action_runner_instance.gd:200-206`) and schedules `RuntimeInstructionInstance` through the object pool.

> **Correction**: an earlier version regarded the reuse of `_execute_single_instruction` as a "code duplication defect". In reality that logic has been unified in `_execute_instruction()` (`runtime_action_runner_instance.gd:548-556`); the duplication issue was resolved in v2.0.

## 4. Parallel Signal Aggregators: `_SignalAggregator` vs `_ParallelSignalAggregator`

The two inner classes are similar in shape but belong to different layers and must be clearly distinguished:

| Dimension | `_SignalAggregator` | `_ParallelSignalAggregator` |
|------|---------------------|------------------------------|
| Location | `action_runner.gd:935` (Resource layer) | `runtime_action_runner_instance.gd:507` (runtime layer) |
| Purpose | parallel signal waiting inside the Resource | parallel signal waiting inside the runtime instance |
| Completion ordering | `_on_signal_received` **disconnects all connections first, then emits** (:955-959) | `_on_signal_received` **emits first, then disconnects** (:527-531), ensuring receivers get the signal |
| Safety checks | `_disconnect_all` only checks `is_connected` (:963-964) | additionally checks `is_instance_valid(conn.signal)` (:536), guarding against already-freed objects |
| `PREDELETE` | `_disconnect_all` inside `_notification` (:967-970) | same, but with an added `is_instance_valid(self)` (:541-545) |

Both are `RefCounted` and use the `_completed` flag to prevent multiple firings. The runtime-layer version, being closer to the real runtime environment (complex object lifecycles), adds instance-validity checks.

## 5. The Value of RuntimeActionRunnerInstance's State Isolation

**Problem**: in the early architecture the Trigger called `ActionRunner.run()` directly, so when the same resource was shared by multiple Triggers, their runtime states (`is_running`, `cancellation_reason`, `current_instruction_index`, `current_context`) overwrote each other.

**v2.0 solution**: each Trigger holds its own `RuntimeActionRunnerInstance`:

```gdscript
# runtime_action_runner_instance.gd:64-67
func _init(definition: ActionRunner, trigger: Node):
    action_runner = definition
    owner_trigger = trigger
```

- Runtime state goes into the `runtime_state` dictionary and the `_instruction_instances` array, **without polluting** the Resource definition
- The same ActionRunner resource can be safely shared by multiple Triggers, each executing / canceling / timing independently
- The runtime layer emits its own signals (`execution_completed` / `execution_failed` / `instruction_started` etc., :17-22) so each Trigger receives independently
- The `RefCounted` choice lets instances be garbage-collected, avoiding long-term Node retention

## 6. Batch Signal Mode (Phase 2.5)

In high-frequency firing scenarios, the overhead of per-instruction `instruction_started` / `instruction_completed` signal emission is significant. `RuntimeActionRunnerInstance` provides `set_batch_signal_mode(enabled: bool)` (:212-216):

- When enabled, `_emit_instruction_started` / `_emit_instruction_completed` (:219-230) buffer instructions into `_pending_started_instructions` / `_pending_completed_instructions`
- At the end of execution, `_complete_execution()` emits everything at once via `_flush_pending_signals()` (:232-239)
- Disabling (`set_batch_signal_mode(false)`) flushes the already-buffered signals immediately (:213-215)
- Callers: `Trigger` (`trigger.gd:104`) and `MultiEventTrigger` (`multi_event_trigger.gd:139`) enable it in high-frequency scenarios

## 7. State Cache Variables (Phase 1 performance optimization)

To reduce frequent access to the `runtime_state` dictionary, the runtime layer introduces three cache variables (`runtime_action_runner_instance.gd:44-48`):

```gdscript
var _is_running_cached: bool = false              ## running-state cache
var _is_canceling_cached: bool = false            ## canceling-state cache
var _context_cached: ExecutionContext = null      ## execution context cache
```

- Synced on start: `_is_running_cached = true; _is_canceling_cached = false; _context_cached = context` (:117-119)
- On cancel: `_is_canceling_cached = true; _is_running_cached = false` (:147-148)
- On completion, cleared and synced back to `runtime_state` (:566-571)
- Many execution paths read the cache variables directly (:104, :142, :303-304, :422-423, :492, :560, :586, :638), avoiding dictionary hash lookups

## 8. The Compiled Cache CompiledInstructionSequence (Phase 3)

`CompiledInstructionSequence` (`core/execution/compiled_instruction_sequence.gd`, 142 lines, `class_name ... extends RefCounted`) is the core of the Phase 3 performance optimization.

### 8.1 Cached Content

```gdscript
var _descriptions: PackedStringArray = []         # pre-cached description strings
var _execution_callables: Array[Callable] = []    # pre-bound execution methods (reserved for Phase 3.2)
var _instruction_count: int = 0                   # instruction count at compile time (invalidation check)
var _is_valid: bool = false
```

### 8.2 How It Works

- `compile(action_runner)` (:40-60): iterates the instructions, pre-storing each `get_description()` return value into `_descriptions`; pre-binds `instruction.execute` as a Callable
- `is_valid_for(action_runner)` (:71-74): fast invalidation check keyed on the instruction count
- ActionRunner holds `_compiled_cache` (`action_runner.gd:64`); all RuntimeActionRunnerInstances **share** the same cache
- The runtime layer lazy-loads it through `_get_or_create_compiled_cache()` (:259-273) and reads it on hot paths such as `_get_cached_description(index)` (:284-288)

### 8.3 Benefits

- Avoids repeated `get_description()` calls every frame (metadata table lookups and string concatenation)
- After Phase 3.2, the pre-bound Callables can directly start a lightweight execution context
- Cache invalidation is keyed on the instruction count, so configuration changes are sensed at zero cost
- Public API: `compile` / `is_valid_for` / `get_cached_description` / `get_cached_callable` / `get_instruction_count` / `is_valid` / `invalidate` / `get_cache_stats` / `get_all_descriptions`

## 9. Per-Instruction Timeout Configuration

ActionRunner provides two `@export` settings (`action_runner.gd:30-39`):

```gdscript
@export_group("Timeout Configuration")
@export var enable_instruction_timeout: bool = false  ## whether to enable custom instruction timeout checks
@export var instruction_timeout: float = 5.0          ## per-instruction timeout (seconds), minimum 0.1
```

Timeout determination happens in `_check_timeout(context)` (`action_runner.gd:395-415`):

```gdscript
if enable_instruction_timeout and instruction_timeout > 0:
    # total timeout = per-instruction timeout × instruction count
    effective_timeout = instruction_timeout * max(1, instructions.size())
else:
    # default formula: base time + 5.0 extra seconds per instruction
    effective_timeout = DEFAULT_TIMEOUT + (instructions.size() * 5.0)
```

When the timeout fires: a `TIMEOUT_ERROR`-type `FuseError` is created via `_create_fuse_error_localized(...)`, emitting the localized `execution_failed` signal (:407-413).

Additionally, when the per-instruction timeout is enabled, the execution path also calls `instruction.set_timeout(instruction_timeout)` (:321, :358) to push the timeout value down to each instruction — this is the true "per-instruction timeout".

## 10. Unified Error Handling with FuseError

v2.0 fully integrates `FuseError`:

- The `_fuse_error` field stores the most recent error (`action_runner.gd:49`)
- `_create_fuse_error()` / `_create_fuse_error_localized()` factory methods attach context such as execution mode and instruction count
- Error types covered: `VALIDATION_ERROR` (validation failure), `EXECUTION_ERROR` (execution failure), `TIMEOUT_ERROR` (timeout)
- Trigger points: the validation stage, single-instruction execution failure, parallel execution failure, timeout checks
- External query interface: `get_fuse_error()` / `has_fuse_error()`

## 11. Object Pool Support

`RuntimeActionRunnerInstance` lazily initializes the global `InstructionInstancePool` (`core/pooling/instruction_instance_pool.gd`, 185 lines) through the static method `get_shared_pool()` (:58-61):

```gdscript
static func get_shared_pool() -> RefCounted:
    if not _shared_instruction_pool:
        _shared_instruction_pool = InstructionInstancePool.new(32, 128)
    return _shared_instruction_pool
```

It pools `RuntimeInstructionInstance`, reducing GC pressure under high-frequency firing. It can be rolled back with `use_instruction_pool = false`.

## 12. Validation Cache

- **ActionRunner**: `_validation_cache` (:50), cleared when the instruction-array setter (:13-16) changes
- **RuntimeActionRunnerInstance**: `_instructions_validated` + `_validated_instruction_count` (:35-36), skipping repeated validation while the instruction count is unchanged; `invalidate_validation_cache()` (:244-246) is the external invalidation entry

## 13. Execution Tracking: `_execution_tracker`

`ActionRunner` holds `_execution_tracker` (:51), dynamically controlling an `ExecutionTracker` instance (located under `editor/debugging/`) via `enable_debug()` / `disable_debug()`:

- `record_instruction_start()` / `record_instruction_complete()` are called around each instruction during sequential execution
- `start_tracking()` at sequence start, `stop_tracking()` at the end
- The `_debug_enabled` (:52) flag controls whether tracking is enabled, avoiding production performance cost

## Overall Assessment

The `ActionRunner` + `RuntimeActionRunnerInstance` two-layer architecture completed the following evolution in v2.0:

1. **State isolation**: the Resource definition is decoupled from runtime state; sharing across multiple Triggers is safe
2. **Performance optimization**: a five-part combination of compiled cache, object pool, batch signals, state cache variables, and validation cache
3. **Error standardization**: the unified FuseError error object + localized error keys
4. **Parallel robustness**: the runtime layer's `_ParallelSignalAggregator` adds instance-validity checks, easing the early race-condition concerns

This document reflects the post-v2.0 state. Earlier critiques such as "naive timeouts / parallel races / code duplication" have been fully superseded by the implementations above and are no longer listed as items to improve.

## Appendix: v2.0 Evolution Timeline

- **Phase 1**: state cache variables (`_is_running_cached` etc.), reducing `runtime_state` dictionary access
- **Phase 2**: the object pool (`InstructionInstancePool`), pooling `RuntimeInstructionInstance`
- **Phase 2.5**: validation cache + batch signal mode (`set_batch_signal_mode`)
- **Phase 3**: the compiled cache `CompiledInstructionSequence`, pre-caching description strings and execution Callables
- **Unified infrastructure**: FuseLogger logging, FuseError errors, FuseLocalization localized error keys

---

**Last updated**: 2026-07-07 | **Baseline version**: v2.0 | **Audit basis**: [AUDIT_REPORT_2026-07-07.md (Chinese)](../../../zh_CN/system_docs/analysis/AUDIT_REPORT_2026-07-07.md) §3.2 | **Update spec**: [UPDATE_SPEC.md (Chinese)](../../../zh_CN/system_docs/analysis/UPDATE_SPEC.md) §4.2.2
