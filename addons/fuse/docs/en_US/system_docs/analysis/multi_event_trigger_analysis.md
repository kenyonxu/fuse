> 🌐 [**中文版**](../../../zh_CN/system_docs/analysis/multi_event_trigger_analysis.md) | English

# MultiEventTrigger Analysis


> **Analyzed as of**: 2026-07-07 (each article verified against code during the same-day full documentation audit; implementation evolution after this point defers to the source code; for recently verified mechanical conclusions see the threading / runtime_instance / preset_nested articles)
## Overview

`MultiEventTrigger` is the component in the Fuse system for merging the functionality of multiple Triggers into a single node. It inherits from `BaseTrigger` and manages multiple event-action bindings through an `EventBinding` array, reducing the node count in scenes and improving performance.

- **File**: `addons/fuse/core/multi_event_trigger.gd` (481 lines)
- **Class name**: `MultiEventTrigger`
- **Inheritance**: `class_name MultiEventTrigger extends BaseTrigger` (multi_event_trigger.gd:4)
- **Icon**: `res://addons/fuse/icons/builtin/Signal.svg`

## Core Responsibilities

1. Manages multiple `EventBinding`s (event + ActionRunner + conditions + cooldown configuration)
2. Creates and manages a `RuntimeEventInstance` / `RuntimeActionRunnerInstance` for each binding
3. Supports parallel condition evaluation (`ParallelConditionEvaluator`)
4. Provides dynamic binding control (enable/disable, manual triggering, reset)

## Core Properties

### Exported Properties

| Property | Type | Description |
|------|------|------|
| `event_bindings` | `Array[EventBinding]` | The event binding list; each entry contains an event, an action_runner, conditions, and cooldown configuration |
| `use_parallel_condition_evaluation` | `bool` | Whether parallel condition evaluation is enabled (default true) |

### Internal State Arrays

Each array maps one-to-one with `event_bindings`:

| Array | Description |
|------|------|
| `_runtime_event_instances` | Runtime event instances |
| `_runtime_action_instances` | Runtime ActionRunner instances |
| `_has_triggered` | Whether already triggered (for trigger_once mode) |
| `_signal_connected` | Whether the signal is connected |
| `_action_signals_connected` | Whether the ActionRunner signals are connected |
| `_initialized` | Whether initialized |

## Lifecycle

### Initialization (_on_trigger_ready)

```
1. _initialize_parallel_evaluator()   # creates the ParallelConditionEvaluator
   # sets evaluation_mode = EvaluationMode.PARALLEL_SAFE (:108)
2. _initialize_runtime_instances()  # creates a Runtime*Instance for each binding
   # internally calls _cleanup_runtime_instances() first (:113), guaranteeing idempotency
3. _start_all_events()               # starts all event listeners
```

### Cleanup (_on_trigger_exit_tree)

```
1. _stop_all_events()               # stops all events
2. _cleanup_runtime_instances()      # disconnects signals, cleans up instances
3. _condition_evaluator = null       # clears the parallel evaluator
```

### Pool Reset (_on_pool_reset)

```
1. _disable_processing()
2. _stop_all_events()
3. _initialize_runtime_instances()   # re-creates the instances
4. _start_all_events()
5. _enable_processing()
```

## The EventBinding Data Structure

Each EventBinding contains:

| Field | Description |
|------|------|
| `event` | `BaseEvent` resource — the event to trigger on |
| `action_runner` | `ActionRunner` resource — the instruction sequence executed after triggering |
| `use_conditions` | `bool` (@export, event_binding.gd:53) — whether condition checking is enabled; controls the dynamic visibility of `conditions` in the editor (via `_get_property_list()`) |
| `conditions` | `Array[BaseCondition]` — the condition list (**plain var, not @export**, event_binding.gd:61; visibility decided by `use_conditions`) |
| `enabled` | `bool` — whether enabled |
| `trigger_once` | `bool` — whether to trigger only once |
| `cooldown_mode` | `CooldownMode` — the cooldown mode |
| `cooldown_time` | `float` — the cooldown time (seconds) |

## Condition Evaluation

### Parallel Evaluation (check_conditions_parallel)

Uses `ParallelConditionEvaluator` to check all conditions in parallel on the WorkerThreadPool:

```gdscript
var results: Array[bool] = _condition_evaluator.evaluate_parallel(context, conditions)
```

### Serial Evaluation (check_conditions_serial)

The fallback; checks them one by one on the main thread:

```gdscript
for condition in binding.conditions:
    if not condition.check(context):
        return false
return true
```

## Cooldown System

Two cooldown modes are supported:

| Mode | Description |
|------|------|
| `GLOBAL_COOLDOWN` | Global cooldown; waits the configured time after the last trigger |
| `PER_OBJECT_COOLDOWN` | Per-object cooldown; uses `context.get_instance_id()` to distinguish different trigger sources |

Cooldown times are stored in `RuntimeEventInstance.runtime_state` and cleared automatically on reset.

## Signals

In the ActionRunner callback, MultiEventTrigger **emits two signals simultaneously** (multi_event_trigger.gd:380–381): the base-class-compatible version (no index) plus this class's indexed version.

| Signal | Parameters | Description |
|------|------|------|
| `event_completed_with_index` | `binding_index: int, context: Dictionary` | A given binding finished executing |
| `event_stopped_with_index` | `binding_index: int, reason: String, context: Dictionary` | A given binding stopped |

Signals inherited from BaseTrigger (emitted alongside on every trigger, preserving backward compatibility):
- `event_completed(context: Dictionary)` - any binding completed
- `event_stopped(reason: String, context: Dictionary)` - any binding stopped

> Meanwhile, `binding_index` is injected into the `ExecutionContext` (multi_event_trigger.gd:267) so downstream instructions can read it via `context.get_variable("binding_index")`.

## Public API

| Method | Description |
|------|------|
| `get_event_count()` | Gets the total number of bindings |
| `get_event_at(index)` | Gets the event at the given position |
| `get_description()` | Gets the description (N bindings, M enabled) |
| `validate()` | Validates all binding configurations, returning a list of errors |
| `reset()` | Resets all trigger states and cooldowns |
| `trigger_binding(index, context=null)` | Manually triggers the given binding (the second parameter is an optional trigger-source node, multi_event_trigger.gd:458) |
| `set_binding_enabled(index, enabled)` | Dynamically enables/disables a binding |

## Performance Optimizations

1. **Batch signal mode**: RuntimeActionRunnerInstance enables `set_batch_signal_mode(true)` to reduce signal overhead under high-frequency firing
2. **Parallel condition evaluation**: conditions checked in parallel on the WorkerThreadPool
3. **Runtime checks**: skips already-triggered trigger_once bindings, currently running ActionRunners, and bindings in cooldown
4. **Preallocated state arrays**: all state arrays map one-to-one with event_bindings, avoiding runtime lookups

## Design Decisions

- **One-to-one correspondence principle**: all internal state arrays correspond by index one-to-one with `event_bindings`, simplifying data management
- **Shared Event resources**: multiple bindings can reference the same Event resource, each with its own independent RuntimeEventInstance
- **Pooling support**: `_on_pool_reset()` implements the complete pooling lifecycle

## Editor Context Menu

MultiEventTrigger provides two editor tools, accessed through the scene tree right-click menu:

### TriggerMerger - Merging Multiple Triggers

- **File**: `addons/fuse/editor/context_menu/trigger_merger.gd`
- **Class name**: `TriggerMerger extends RefCounted`
- **Function**: merges multiple Trigger nodes into one MultiEventTrigger

#### Merge Conditions (`can_merge`)

| Condition | Description |
|------|------|
| Node count >= 2 | At least 2 Triggers required |
| All of type Trigger | Non-Trigger nodes are rejected |
| Same parent node | All Triggers must be under the same parent node |

#### Merge Flow (`merge`)

```
1. Sort the nodes by scene tree index
2. Create the MultiEventTrigger node
3. Create an EventBinding for each Trigger (deep-copying event_definition + action_runner)
4. Validate binding data integrity
5. Register the UndoRedo operations
6. Delete the original Triggers, add the MultiEventTrigger
```

#### Property Mapping

| Trigger property | → EventBinding property |
|-------------|-------------------|
| `event_definition` | `event` |
| `action_runner` | `action_runner` |
| `trigger_once` | `trigger_once` |
| `cooldown_mode` | `cooldown_mode` |
| `cooldown_time` | `cooldown_time` |
| — | `enabled = true` (enabled by default) |

### TriggerSplitter - Splitting a MultiEventTrigger

- **File**: `addons/fuse/editor/context_menu/trigger_splitter.gd`
- **Class name**: `TriggerSplitter extends RefCounted`
- **Function**: splits a MultiEventTrigger into multiple independent Triggers

#### Split Conditions (`can_split`)

| Condition | Description |
|------|------|
| Type is MultiEventTrigger | Non-MultiEventTrigger nodes are rejected |
| event_bindings >= 2 | Cannot split with only 1 binding |

#### Split Flow (`split`)

```
1. Create a Trigger node for each EventBinding
2. Deep-copy event + action_runner into the new Triggers
3. Name each Trigger automatically from the event class name (e.g. OnInputKey, OnSceneReady)
4. On name clashes, append a numeric suffix automatically (OnInputKey_2)
5. Register the UndoRedo operations
6. Delete the MultiEventTrigger, add the multiple Triggers
```

### UndoRedo Support

| Operation | Undo | Redo |
|------|------|------|
| Merge | Restores all original Triggers (with properties and positions) | Merges back into a MultiEventTrigger |
| Split | Restores the MultiEventTrigger (with all bindings) | Splits back into multiple Triggers |

### Context Menu Entry

- **File**: `addons/fuse/editor/context_menu/fuse_context_menu_plugin.gd`
- Menu items:
  - Multiple Triggers selected → "Merge into MultiEventTrigger"
  - A MultiEventTrigger selected → "Split into multiple Triggers"
  - Also a "Generate Instructions" item (used together with InstructionGenerator)
