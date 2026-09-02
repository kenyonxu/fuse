> 🌐 [**中文版**](../../../zh_CN/system_docs/analysis/base_trigger_analysis.md) | English

# BaseTrigger Analysis Report


> **Analysis date**: 2026-07-07 (code verified report-by-report during the same-day full documentation audit; for implementation evolution after that date the source code is authoritative — see the threading / runtime_instance / preset_nested and other reports for recently verified mechanism conclusions)
## Document Overview

This report is a comprehensive analysis of the `BaseTrigger` core script in the Fuse visual programming system. `BaseTrigger` is the abstract base class of the trigger system (`@abstract class_name BaseTrigger extends Node`), defining the unified interface for trigger cooperation with event / action runtime instances, cooldown checks, execution context creation, engine callback forwarding, and pool reset hooks, providing the common capabilities shared by the two concrete subclasses `Trigger` (single event) and `MultiEventTrigger` (multi-event binding).

**Source file:** `addons/fuse/core/base_trigger.gd`
**Lines:** 354
**Base class:** Node
**Subclasses:** `Trigger` (`addons/fuse/core/trigger.gd`), `MultiEventTrigger` (`addons/fuse/core/multi_event_trigger.gd`)

> **Path note**: this class sits at the top level of `core/` (same directory as `trigger.gd` / `multi_event_trigger.gd` / `runtime_event_instance.gd` / `runtime_action_runner_instance.gd`). Earlier documents mistakenly wrote `core/base/base_trigger.gd`; that path does not exist.

---

## 1. Class Overview and Responsibilities

`BaseTrigger` is a purely abstract base class: it holds no event / action runtime instances itself and only provides the protocol (5 abstract methods) and reusable utility methods. The concrete event storage, signal connections, and ActionRunner dispatching are done by the subclasses.

### Core Responsibilities

1. **Protocol definition**: 5 `@abstract` methods prescribe the event / runtime instance access interfaces that subclasses must expose
2. **Cooldown control**: provides `_check_cooldown()` / `_clear_cooldown_state()`, supporting the three `CooldownMode` policies
3. **Execution context factory**: `_create_execution_context()` creates an ExecutionContext and automatically syncs the RuntimeEventInstance's event args
4. **Unified engine callback forwarding**: forwards `_process` / `_physics_process` / `_notification` / `_unhandled_input` to every event instance's `on_process` / `on_physics_process` / `handle_process_notification` / `handle_physics_process_notification` / `handle_input`
5. **ActionRunner signal bridging**: `_connect_action_runner_signals_at()` / `_disconnect_action_runner_signals_at()` uniformly connect / disconnect `execution_completed` / `execution_failed` / `execution_canceled`
6. **Pooling support**: `pool_reset()` delegates to the subclass's `_on_pool_reset()` for a full rebuild
7. **Errors and logging**: unified FuseError creation / query interface and the localized logging method family

### Design Characteristics

- Uses `@abstract` to mark the abstract class and abstract methods (GDScript 2.0 syntax)
- The `@tool` annotation enables editor-mode execution (consistent with the subclasses)
- In editor mode all engine callbacks return immediately to avoid side effects
- The 5 abstract methods form an "index-based access contract", letting the base-class utilities serve both the single-event (Trigger) and multi-event (MultiEventTrigger) storage models at once

---

## 2. Core Properties

### Enum

```gdscript
enum CooldownMode {
    NONE,               ## No cooldown, triggers every time
    GLOBAL_COOLDOWN,    ## Global cooldown: everything waits after a trigger
    PER_OBJECT_COOLDOWN ## Per-object cooldown: each object has its own cooldown timer
}
```

| Value | Meaning | Cooldown state key (stored in RuntimeEventInstance.runtime_state) |
|----|------|-----------------------------------------------------|
| `NONE` | no cooldown check; `_check_cooldown` returns true immediately | — |
| `GLOBAL_COOLDOWN` | after a trigger all callers wait `cooldown_time` seconds | `last_trigger_time: float` |
| `PER_OBJECT_COOLDOWN` | timed separately per `context.get_instance_id()` | `object_cooldowns: Dictionary[int, float]` |

### Signals

| Signal | Signature | Description |
|------|------|------|
| `event_completed` | `(context: Dictionary)` | the event finished executing (subclasses may define their own completion signals) |
| `event_stopped` | `(reason: String, context: Dictionary)` | emitted when the event stops (including failure / cancellation) |

> The subclass `MultiEventTrigger` additionally defines `event_completed_with_index(binding_index, context)` and `event_stopped_with_index(binding_index, reason, context)`, and in its callbacks emits both the base-class and the indexed signals to stay compatible (see `multi_event_trigger.gd:380-403`).

### @export Properties

| Property | Type | Default | Description |
|------|------|--------|------|
| `pool_mode` | bool | false | pooling mode: the first `_ready()` skips initialization and waits for an explicit `pool_reset()` |
| `log_level` | FuseLogger.LogLevel | NONE | log output level control |

### Internal State

| Property | Type | Description |
|------|------|------|
| `_fuse_error` | FuseError | error instance for unified error handling (cleared in `reset()`) |

> Note: `BaseTrigger` itself does **not** hold members such as `_runtime_event_instance` / `_runtime_action_runner_instance` / `event_definition`. Those are defined in the subclasses and exposed to the base class through the abstract methods.

---

## 3. Abstract Methods (Must Be Implemented by Subclasses)

The 5 `@abstract` methods form the "index-based access contract". All base-class utilities (cooldown checks, context creation, engine callback forwarding, signal bridging) access subclass data through these methods, supporting the single-event and multi-event models at once.

### 3.1 Event Access

#### `get_event_count() -> int`

Returns the number of events the trigger currently holds. `Trigger` returns 0 or 1 (depending on whether `event_definition` is null); `MultiEventTrigger` returns `event_bindings.size()`.

#### `get_event_at(index: int) -> BaseEvent`

Returns the BaseEvent resource at the given index. Subclasses return null when out of range. `Trigger` returns `event_definition` only when `index == 0`.

### 3.2 Runtime Instance Access

#### `get_runtime_event_instance_at(index: int) -> RuntimeEventInstance`

Returns the RuntimeEventInstance at the given index. It is the sole source for reading / writing cooldown state and for syncing event args.

#### `get_action_runner_instance_at(index: int) -> RuntimeActionRunnerInstance`

Returns the RuntimeActionRunnerInstance at the given index. The base class's ActionRunner signal bridging methods locate instances through it.

### 3.3 Pool Reset

#### `_on_pool_reset() -> void`

The full reset logic used when a pooled object is reused. Subclasses must implement it; it is responsible for:

1. calling `reset()` to clear its own state
2. calling `_disable_processing()` to suspend engine callbacks
3. terminating the old event listening (after setting the correct `_runtime_instance_ref`, calling `event.terminate(self)`)
4. cleaning up the old RuntimeEventInstance / RuntimeActionRunnerInstance
5. creating a new RuntimeEventInstance and calling `event.initialize_with_runtime_instance()`
6. creating a new RuntimeActionRunnerInstance (if there is an action_runner)
7. reconnecting the triggered signal
8. calling `_enable_processing()` to resume engine callbacks

See `trigger.gd:52-86` and `multi_event_trigger.gd:78-87` for the concrete implementations.

---

## 4. Key Methods

### 4.1 Lifecycle

#### `_ready() -> void`

```
Execution flow:
  1. Editor mode → print a localized debug log and return
  2. pool_mode == true → skip first-time initialization and wait for pool_reset()
  3. Call _on_trigger_ready() (subclass hook)
```

#### `_exit_tree() -> void`

Delegates to the `_on_trigger_exit_tree()` subclass hook. `Trigger` disconnects signals and cleans up the RuntimeEventInstance / RuntimeActionRunnerInstance here; `MultiEventTrigger` additionally nulls `_condition_evaluator`.

#### Overridable Hooks

| Method | Default behavior |
|------|----------|
| `_on_trigger_ready()` | empty (subclasses initialize events / runtime instances / signals) |
| `_on_trigger_exit_tree()` | empty (subclass cleanup) |
| `reset()` | clears `_fuse_error` (subclasses add: clearing has_triggered, cooldown state, event.reset()) |
| `validate() -> Array[String]` | returns an empty array (subclasses add configuration validation) |
| `trigger_manually(context: Node = null)` | the default implementation push_warnings that the subclass did not override (subclasses override to forward to `_on_event_fired`) |
| `get_description() -> String` | returns "BaseTrigger" (subclasses override with the event description + cooldown info) |

### 4.2 Cooldown Checks

#### `_check_cooldown(index, context, cooldown_mode, cooldown_time) -> bool`

Parameter order: `index: int, context: Node, cooldown_mode: CooldownMode, cooldown_time: float`. Returns true when triggering is allowed.

```
Execution flow:
  1. cooldown_mode == NONE or cooldown_time <= 0 → return true
  2. event_instance = get_runtime_event_instance_at(index)
     if null → return true (no instance to record on)
  3. current_time = Time.get_ticks_msec() / 1000.0
  4. match cooldown_mode:
       GLOBAL_COOLDOWN:
         last_time = runtime_state.get("last_trigger_time", 0.0)
         if current_time - last_time < cooldown_time → print an info log and return false
         otherwise write runtime_state["last_trigger_time"] = current_time
       PER_OBJECT_COOLDOWN:
         object_cooldowns = runtime_state.get("object_cooldowns", {})
         object_id = context.get_instance_id() (0 when context is null)
         if object_id != 0 and object_cooldowns.has(object_id):
           if current_time - object_cooldowns[object_id] < cooldown_time
             → print an info log with the object name / ID and return false
         write object_cooldowns[object_id] = current_time
  5. return true
```

> All cooldown state lives in the RuntimeEventInstance.runtime_state dictionary, not in fields of the Trigger itself. That way, when multiple pooled objects share one Event resource, each object has its own RuntimeEventInstance and the cooldowns stay independent.

#### `_clear_cooldown_state(index: int) -> void`

Erases the `last_trigger_time` and `object_cooldowns` keys from the RuntimeEventInstance at the given index. Both `Trigger.reset()` and `MultiEventTrigger.reset()` call this method.

### 4.3 Execution Context Factory

#### `_create_execution_context(target: Node, index: int = 0) -> ExecutionContext`

```
Execution flow:
  1. context = ExecutionContext.new(target, self)
  2. Write context variables: event_source = self, triggered_node = target
  3. context.log_level = log_level
  4. If target has the meta "delta_time" → sync it to context.delta_time (for polling events)
  5. _sync_event_args_to_context(context, index)
  6. Return context
```

#### `_sync_event_args_to_context(context, index) -> void`

Syncs the RuntimeEventInstance's event args into the ExecutionContext variable namespace:

1. reads `runtime_state["last_event_args"]` (a Dictionary) and writes a variable `event_<key>` for each key
2. walks every `event_`-prefixed key in runtime_state (except `event_source`) and writes it into the context

> Both Trigger and MultiEventTrigger rely on this mechanism to expose event args (input_vector, key bindings, colliding bodies, etc.) to the instructions inside the ActionRunner.

### 4.4 ActionRunner Signal Bridging

#### `_connect_action_runner_signals_at(index, callbacks) -> bool`

The `callbacks` dictionary format: `{"completed": Callable, "failed": Callable, "canceled": Callable}`.

Locates the RuntimeActionRunnerInstance by index and `connect`s each of the `execution_completed` / `execution_failed` / `execution_canceled` signals (when present and not already connected). Returns true if at least one was connected.

#### `_disconnect_action_runner_signals_at(index, callbacks) -> void`

Symmetric disconnection. Subclasses use the `_action_runner_signals_connected` flag to prevent duplicate connects / disconnects.

> Subclass callback signatures: `Trigger` uses `_on_action_runner_completed(total_time)` / `_on_action_runner_failed(error_message)` / `_on_action_runner_canceled(reason)`; `MultiEventTrigger` carries the binding index via `.bind(index)`.

### 4.5 Unified Engine Callback Forwarding

`BaseTrigger` uniformly forwards the four Godot node engine callbacks to all event instances (skipped in editor mode):

| BaseTrigger method | Forward target (event instance method) | Description |
|------------------|------------------------|------|
| `_process(delta)` | `event.on_process(delta, event_instance)` | per-frame polling (e.g. OnInterval, OnAnimationMarker) |
| `_physics_process(delta)` | `event.on_physics_process(delta, event_instance)` | physics-frame polling (e.g. OnBodyEntered continuous detection) |
| `_notification(NOTIFICATION_PROCESS)` | `event.handle_process_notification()` | process notification |
| `_notification(NOTIFICATION_PHYSICS_PROCESS)` | `event.handle_physics_process_notification()` | physics process notification |
| `_unhandled_input(event)` | `event.handle_input(event)` | input events (e.g. OnInputKey, OnMouseButton) |

Every forward is guarded by `event.has_method(...)`; events missing the method are silently skipped. Events are fetched via `get_event_at(i)` and the matching RuntimeEventInstance via `get_runtime_event_instance_at(i)` (`on_process` / `on_physics_process` need the instance passed in so the event can read/write state).

### 4.6 Pooling Support

#### `pool_reset() -> void`

Public entry point, delegating to `_on_pool_reset()` (abstract). Together with the `pool_mode` property it enables object pool reuse.

#### `_disable_processing() / _enable_processing() -> void`

Toggle the `set_physics_process` / `set_process` switches. Subclasses call them at the start and end of `_on_pool_reset()`, so engine callbacks are not forwarded to stale event instances during the rebuild.

### 4.7 Error Handling

| Method | Description |
|------|------|
| `_create_fuse_error(message, error_type, context)` | creates a FuseError instance stored in `_fuse_error`, automatically adding `trigger_name = name` to the context |
| `_create_fuse_error_localized(message_key, error_type, context, args)` | translates via `FuseLocalization.translate_format(message_key, args)` before creating |
| `get_fuse_error() -> FuseError` | returns the current error |
| `has_fuse_error() -> bool` | whether there is an error |

Common `FuseError.ErrorType` values: `RUNTIME_ERROR`, `CONFIGURATION_ERROR` (used by subclasses in `validate()` / `_on_trigger_ready()` when configuration is missing).

### 4.8 Logging Methods

Two groups — localized and non-localized — all delegating to `FuseLogger`:

| Non-localized | Localized (takes a translation key + args) |
|----------|----------------------------|
| `_log_debug(message)` | `_log_debug_localized(message_key, args = {})` |
| `_log_info(message)` | `_log_info_localized(message_key, args = {})` |
| `_log_warning(message)` | `_log_warning_localized(message_key, args = {})` |
| `_log_error(message)` | `_log_error_localized(message_key, args = {})` |

All calls use `"Trigger"` as the category, passing `log_level` and the node `name`. Example localized keys: `FUSE_LOG_TRIGGER_INITIALIZED`, `FUSE_ERROR_TRIGGER_NO_ACTION_RUNNER`, `FUSE_LOG_TRIGGER_POOL_RESET`, etc.

---

## 5. Cooperation with RuntimeEventInstance

`RuntimeEventInstance` (`addons/fuse/core/runtime_event_instance.gd`, 288 lines, `extends RefCounted`) is the sole carrier of runtime state in the BaseTrigger system.

### Integration Architecture

```
BaseTrigger (Node, abstract)
    │
    ├── via get_event_at(i) → BaseEvent (Resource, can be shared by multiple Triggers)
    │
    ├── via get_runtime_event_instance_at(i) → RuntimeEventInstance (RefCounted, one per Trigger)
    │        │
    │        ├── event_definition: BaseEvent       (event resource reference)
    │        ├── owner_trigger: Node               (owning trigger)
    │        ├── runtime_state: Dictionary         (cooldown keys / event args / self-declared state)
    │        └── signal triggered(context: Node)   (forwarded from BaseEvent.triggered)
    │
    └── via get_action_runner_instance_at(i) → RuntimeActionRunnerInstance (RefCounted)
             │
             ├── definition: ActionRunner
             ├── signal execution_completed(total_time)
             ├── signal execution_failed(error_message)
             └── signal execution_canceled(reason)
```

### Signal Forwarding Chain (Key)

The `BaseEvent` resource is a Resource that multiple Triggers can share. On construction the RuntimeEventInstance connects `event_definition.triggered` to its own `_on_event_triggered` callback; before forwarding it checks `context.get_meta("trigger") == owner_trigger` and only forwards events belonging to its own trigger (see `runtime_event_instance.gd:104-115`):

```
BaseEvent.triggered.emit(context_with_trigger_meta)
    └──→ RuntimeEventInstance._on_event_triggered(context)
          ├── if context.trigger meta != owner_trigger → drop
          └── RuntimeEventInstance.triggered.emit(context)
                └──→ Trigger._on_event_fired(context)  [connected by the subclass]
```

This relaying layer solves the "signal crosstalk when one Event resource is shared by multiple pooled Triggers".

### Cooldown State Storage

All cooldown state is stored in `runtime_state`, with the key conventions:

| CooldownMode | Key | Type |
|--------------|----|----|
| GLOBAL_COOLDOWN | `last_trigger_time` | float (seconds) |
| PER_OBJECT_COOLDOWN | `object_cooldowns` | Dictionary[int, float] (instance_id → last trigger time) |

Read and written directly by the base class's `_check_cooldown()` / `_clear_cooldown_state()`. Subclasses need not care about cooldown details; they only expose `cooldown_mode` / `cooldown_time` as exported properties and pass the parameters to the base class.

### Key Fix in Pool Reset

`Trigger._on_pool_reset()` and `MultiEventTrigger._stop_all_events()` **explicitly set** `event._runtime_instance_ref = _runtime_event_instance` before calling `event.terminate(self)` (trigger.gd:63, multi_event_trigger.gd:215). The reason: the Event subclasses' `terminate()` accesses state internally through `get_runtime_state()`, which prefers the argument passed in and falls back to `_runtime_instance_ref`. Setting the correct reference up front ensures terminate operates on the right runtime instance, avoiding state clobbering when multiple pooled objects share an Event resource.

---

## 6. Subclass Implementation Patterns

### 6.1 Trigger (Single-Event Trigger, `trigger.gd`, 335 lines)

Storage model: a single set of fields.

| Field | Type | Description |
|------|------|------|
| `event_definition` | BaseEvent (@export) | the event resource to listen to |
| `action_runner` | ActionRunner (@export) | the action to run when triggered |
| `trigger_once` | bool (@export) | whether it triggers only once |
| `cooldown_mode` | CooldownMode (@export) | cooldown mode |
| `cooldown_time` | float (@export_range 0.0-60.0) | cooldown seconds |
| `has_triggered` | bool | trigger_once state |
| `_runtime_event_instance` | RuntimeEventInstance | the runtime event instance |
| `_runtime_action_runner_instance` | RuntimeActionRunnerInstance | the runtime action instance |

Abstract method implementations:

```gdscript
func get_event_count() -> int:
    return 1 if event_definition != null else 0
func get_event_at(index: int) -> BaseEvent:
    return event_definition if index == 0 else null
func get_runtime_event_instance_at(index: int) -> RuntimeEventInstance:
    return _runtime_event_instance if index == 0 else null
func get_action_runner_instance_at(index: int) -> RuntimeActionRunnerInstance:
    return _runtime_action_runner_instance if index == 0 else null
```

`_on_event_fired(context)` flow: trigger_once check → ActionRunner-running check → `_check_cooldown(0, ...)` → `_create_execution_context` → sync extra args such as input_vector → `_runtime_action_runner_instance.run(context)`.

### 6.2 MultiEventTrigger (Multi-Event Trigger, `multi_event_trigger.gd`, 481 lines)

Storage model: parallel arrays one-to-one with `event_bindings: Array[EventBinding]`.

| Field | Type | Description |
|------|------|------|
| `event_bindings` | Array[EventBinding] (@export) | event-action binding list |
| `_runtime_event_instances` | Array[RuntimeEventInstance] | one-to-one correspondence |
| `_runtime_action_instances` | Array[RuntimeActionRunnerInstance] | one-to-one correspondence |
| `_has_triggered` / `_signal_connected` / `_action_signals_connected` / `_initialized` | Array[bool] | state flags in one-to-one correspondence |
| `use_parallel_condition_evaluation` | bool (@export, default true) | enables WorkerThreadPool parallel condition evaluation |
| `_condition_evaluator` | ParallelConditionEvaluator | the parallel evaluator instance |

The abstract method implementations do indexed access bounded by `event_bindings.size()`. `_on_event_fired(context, index)` carries the binding index via `.bind(index)`; the flow resembles Trigger's but condition checks can take the parallel path (`check_conditions_parallel`) or the serial fallback (`check_conditions_serial`).

Distinctive methods:

| Method | Description |
|------|------|
| `trigger_binding(index, context = null)` | manually trigger the given binding |
| `set_binding_enabled(index, enabled)` | dynamically enable / disable a binding (calls `event_instance.start_listening()` / `stop_listening()`) |
| `event_completed_with_index` / `event_stopped_with_index` signals | carry binding_index and are emitted alongside the base-class signals |

### 6.3 EventBinding (Binding Resource, `event_binding.gd`)

`class_name EventBinding extends Resource`; each binding wraps:

| Field | Type | Default |
|------|------|--------|
| `event` | BaseEvent (@export) | — |
| `action_runner` | ActionRunner (@export) | — |
| `enabled` | bool (@export) | true |
| `trigger_once` | bool (@export) | false |
| `cooldown_mode` | BaseTrigger.CooldownMode (@export) | NONE |
| `cooldown_time` | float (@export_range 0.0-60.0) | 0.0 |
| `use_conditions` | bool (@export) | false (controls the dynamic visibility of conditions) |
| `conditions` | Array[BaseCondition] | [] |

---

## 7. Relationship with the ActionRunner System

`BaseTrigger` drives the ActionRunner indirectly through RuntimeActionRunnerInstance:

1. **Runtime instantiation**: the subclass calls `RuntimeActionRunnerInstance.new(action_runner, self)` in `_on_trigger_ready()` and turns on `set_batch_signal_mode(true)` (the Phase 2.5 optimization, reducing signal overhead for high-frequency triggers)
2. **Signal connection**: the subclass registers the completed / failed / canceled callbacks via the base class's `_connect_action_runner_signals_at()`
3. **Execution trigger**: the subclass calls `_runtime_action_runner_instance.run(execution_context)` in `_on_event_fired()`
4. **Callback dispatch**: RuntimeActionRunnerInstance emits `execution_completed(total_time)` / `execution_failed(error_message)` / `execution_canceled(reason)`; the subclass callbacks convert them into the `event_completed` / `event_stopped` signals (MultiEventTrigger additionally emits the indexed versions)
5. **Cleanup**: `action_instance.cleanup()` is called in `_on_trigger_exit_tree()` and `_on_pool_reset()`

RuntimeActionRunnerInstance itself provides `is_running()`, `cancel_execution(reason)`, `set_stop_execution(stop, reason)`, `validate_instructions()`, `invalidate_validation_cache()`, `get_runtime_state(key)` / `set_runtime_state(key, value)`, and other interfaces (see `runtime_action_runner_instance.gd`).

---

## 8. Performance Considerations

### Design-Level Optimizations

1. **Index-based access contract**: the 5 abstract methods let the base-class utilities serve the single- / multi-event models with zero copying, avoiding "array vs single value" branches in the base class
2. **Batch signal mode**: subclasses enable `set_batch_signal_mode(true)` on the RuntimeActionRunnerInstance, merging per-instruction signals into combined emissions
3. **Parallel condition evaluation**: MultiEventTrigger enables `use_parallel_condition_evaluation` by default, evaluating multiple BaseConditions in parallel on the WorkerThreadPool; it automatically falls back to serial when the evaluator is null
4. **Editor-mode skip**: all engine callbacks and `_ready()` return immediately under `Engine.is_editor_hint()`, avoiding accidental triggers in the editor
5. **Pooling support**: `pool_mode` + `pool_reset()` let Trigger nodes be reused through an object pool, avoiding repeated Node instantiation

### Potential Performance Overhead

1. **Full forwarding of engine callbacks**: `_process` / `_physics_process` / `_unhandled_input` iterate all events every frame with `has_method` guards — there is iteration overhead when the event count is large, but `has_method` calls are cheap
2. **Signal `.bind(index)`**: MultiEventTrigger generates a Callable with a bound index per callback; the number of bindings grows linearly with event_bindings

> History: the unbounded growth of the `object_cooldowns` dictionary with object count under PER_OBJECT_COOLDOWN (CODE_ISSUES B12) was solved by automatically cleaning expired entries (commit `0bd037b`, test `test_base_trigger_cooldown_cleanup.tscn`).

---

## 9. Overall Assessment

### Strengths

1. **Clean abstraction boundary**: the 5 abstract methods form a minimal protocol, the base-class utilities are highly reused, and each subclass only cares about the "single / multi storage model" difference
2. **Thorough runtime state isolation**: cooldowns, event args, and trigger counts all live in the RuntimeEventInstance, so Event resources can be shared safely and pooled objects never interfere
3. **Sensible three-tier cooldown design**: NONE / GLOBAL / PER_OBJECT cover the common use cases with clear state key conventions
4. **Unified engine callback forwarding**: implemented once, it benefits all event subclasses (OnInputKey, OnInterval, OnAnimationMarker, etc.) without each implementing _process
5. **Key pooling fix in place**: pre-setting `_runtime_instance_ref` before terminate solves the state-clobbering trap of shared Event resources (extensively commented)
6. **Unified errors / logging**: the FuseError + FuseLocalization + FuseLogger infrastructure runs throughout, consistent with BaseEvent / BaseInstruction

### Weaknesses

1. **No default emission for the `event_completed` / `event_stopped` signals**: the base class defines the signals but subclasses implement the callbacks; if a subclass forgets to `emit` in `_on_action_runner_completed` the signals never fire (both current subclasses emit correctly, but the base class enforces nothing)

> Historical B12/B13/B14/B15 (no PER_OBJECT_COOLDOWN cleanup / noisy cooldown info logs / empty default trigger_manually implementation / weak type annotations in _create_execution_context) were fixed (commit `0bd037b`) and removed from the weakness list.

---

**Maintained by**: Fuse development team
**Last updated**: 2026-07-07
**Version**: 1.0.0 (rewritten in the as-is description style)
**Reference source**: `addons/fuse/core/base_trigger.gd` (354) / `trigger.gd` (335) / `multi_event_trigger.gd` (481) / `runtime_event_instance.gd` (288) / `runtime_action_runner_instance.gd` (691) / `event_binding.gd`
