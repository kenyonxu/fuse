> 🌐 [**中文版**](../../../zh_CN/system_docs/analysis/fuse_architecture_analysis.md) | English

# Fuse Visual Programming System Architecture Analysis Report


> **Analysis timestamp**: 2026-07-07 (mechanisms verified against code article by article during the same-day full documentation audit; for evolution since then the source code is authoritative — recently verified mechanistic conclusions appear in the threading / runtime_instance / preset_nested and related articles)
> This document is based on the actual code under `addons/fuse/core/` (2026-07-07 snapshot). All APIs / class names / file paths have been verified; nothing is fabricated. The original v1.0 body (describing a single layer where Resources directly hold state) is deprecated; this edition fully rewrites §1–10 and keeps the better-quality §11 evolution chapter.

## Overview

Fuse is a visual programming plugin designed for Godot 4.7, providing an event-driven programming framework of "event → trigger → action". Developers configure Resources (events / instructions / conditions / triggers) by dragging and dropping in the editor, while the runtime layer (Runtime instances + object pools + threading system) takes care of actual execution.

Core architecture characteristics (since v2.0):
1. **Dual-layer architecture of resource definition + runtime orchestration**: Resources only describe "what to do"; at runtime the trio of `RuntimeEventInstance` / `RuntimeInstructionInstance` / `RuntimeActionRunnerInstance` carries the state
2. **The trigger quartet**: `BaseTrigger`(@abstract) ← `Trigger` / `MultiEventTrigger`; plus the scene-level `Runner`
3. **Three-layer variable scopes**: LOCAL (EC) / SCOPE (`ScopeVariableContainer` node chain) / GLOBAL (`GlobalVariableAssistant`/`GlobalVariableManager`)
4. **Object pool + multithreading infrastructure**: 5 classes in `core/pooling/` + 4 classes in `core/threading/`
5. **Global Node infrastructure**: `FuseEventBus` (event bus) and `FuseRuntimeBridge` (runtime variable TCP bridge), both Autoload singletons

## 1. Overall System Architecture

### 1.1 Architecture Overview

The actual directory structure and responsibility layers of Fuse `core/` are as follows (all paths relative to `addons/fuse/core/`):

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  Top-level Node / Autoload layer (scene level)                              │
│  ┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐            │
│  │ fuse_event_bus   │ │ fuse_runtime_    │ │ global_variable_ │            │
│  │ .gd (Autoload)   │ │ bridge.gd        │ │ assistant.gd     │            │
│  │ global event bus │ │ (Autoload) var   │ │ (scene Node)     │            │
│  └──────────────────┘ └──────────────────┘ └──────────────────┘            │
├─────────────────────────────────────────────────────────────────────────────┤
│  Trigger / Runner layer (scene Node, orchestration entry)                  │
│  ┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐            │
│  │ base_trigger.gd  │ │ trigger.gd       │ │ multi_event_     │            │
│  │ @abstract Node   │ │ single-event     │ │ trigger.gd       │            │
│  │ (4 abstract)     │ │ extends BaseTrig │ │ multi-event      │            │
│  └──────────────────┘ └──────────────────┘ └──────────────────┘            │
│  ┌──────────────────┐                                                       │
│  │ runner.gd        │  signals → ActionRunner auto-bound execution entry    │
│  │ Node (no Trigger)│                                                       │
│  └──────────────────┘                                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│  Runtime instance layer (RefCounted, state isolation)                      │
│  ┌────────────────────┐ ┌──────────────────────┐ ┌─────────────────────┐   │
│  │ runtime_event_     │ │ runtime_instruction_ │ │ runtime_action_     │   │
│  │ instance.gd        │ │ instance.gd          │ │ runner_instance.gd  │   │
│  │ event runtime state│ │ timeout/pause/cancel │ │ instr. orchestration│   │
│  └────────────────────┘ └──────────────────────┘ └─────────────────────┘   │
├─────────────────────────────────────────────────────────────────────────────┤
│  base/ definition layer (Resource / RefCounted abstract base classes)      │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌───────────┐ │
│  │base_event  │ │base_       │ │base_       │ │base_       │ │execution_ │ │
│  │.gd         │ │instruction │ │condition   │ │variable    │ │context.gd │ │
│  │            │ │.gd         │ │.gd         │ │.gd         │ │(facade)   │ │
│  └────────────┘ └────────────┘ └────────────┘ └────────────┘ └───────────┘ │
│  ┌────────────────────┐ ┌────────────────────┐ ┌──────────────────────────┐│
│  │action_runner.gd    │ │variable_context.gd │ │execution_diagnostics.gd  ││
│  │ Resource instr. seq│ │ EC variable system │ │ EC diagnostics system    ││
│  └────────────────────┘ └────────────────────┘ └──────────────────────────┘│
│  ┌──────────────────────────┐ ┌──────────────────────────────────────────┐ │
│  │scope_variable_container  │ │variable_container.gd (@deprecated)       │ │
│  │.gd (Node scope container)│ │                                          │ │
│  └──────────────────────────┘ └──────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────────────────────┤
│  Specialized subsystems                                                     │
│  ┌──────────── pooling/ (5 classes) ──────┐ ┌── threading/ (4 classes) ──┐│
│  │ fuse_object_pool  scene object pool    │ │ fuse_task_manager task mgmt││
│  │ fuse_pool_item    pool item wrapper    │ │ parallel_condition_        ││
│  │ fuse_pool_manager global pool mgmt     │ │   evaluator parallel cond. ││
│  │ fuse_recycle_timer recycle timer(Node) │ │ fuse_thread_safe utilities ││
│  │ instruction_instance_pool              │ │ fuse_threading_config conf ││
│  │   RuntimeInstructionInstance pool      │ │                            ││
│  └────────────────────────────────────────┘ └────────────────────────────┘│
│  ┌── execution/ ──────────┐ ┌── serialization/ ──────┐ ┌── audio/ ───────┐ │
│  │ compiled_instruction_  │ │ instruction_serializer │ │ fuse_audio_     │ │
│  │   sequence.gd compiled │ │   .gd serializer       │ │   container.gd  │ │
│  └────────────────────────┘ └────────────────────────┘ └─────────────────┘ │
│  ┌── logging/ ───────────┐ ┌── resources/ ──────────┐ ┌── utils/ ────────┐ │
│  │ fuse_logger.gd        │ │ fuse_preset.gd         │ │ expression_      │ │
│  │ fuse_error.gd         │ │ fuse_icon_library.gd   │ │   helper.gd      │ │
│  └───────────────────────┘ └────────────────────────┘ │ fuse_icon_       │ │
│  ┌── top-level RefCounted┐ ┌── singletons/Service ──┐ │   manager.gd     │ │
│  │ global_variable_      │ │ global_variable_       │ │ variable_        │ │
│  │   resource.gd         │ │   manager.gd(singleton)│ │   operations.gd  │ │
│  │ global_variable_      │ │ scope_variable_        │ │ variable_scope_  │ │
│  │   service.gd          │ │   manager.gd (Node sgl)│ │   utils.gd       │ │
│  └───────────────────────┘ └────────────────────────┘ └─────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 1.2 Core Design Principles

1. **Event-driven architecture**: based on the "event → trigger → action" paradigm
2. **Resource + runtime dual-layer separation**: Resources only describe configuration; runtime state is carried by independent RefCounted instances, avoiding state pollution when multiple triggers share one Resource
3. **Type safety**: GDScript 2.0 strong type annotations, validated at runtime
4. **Three-layer scoped variables**: explicit LOCAL / SCOPE / GLOBAL layering
5. **Unified infrastructure**: the `FuseLogger` + `FuseError` + `FuseLocalization` trio runs through the whole stack
6. **Extensibility**: pluggable abstract base classes (`@abstract` methods); subclasses implement the concrete behavior

## 2. Core Component Analysis

### 2.1 BaseInstruction - The Instruction Base Class (base/base_instruction.gd)

`BaseInstruction extends Resource`, the abstract base class of all instructions. Key points:

- **`execute()` is `@abstract`** (base_instruction.gd:379) — subclasses must implement it; there is no default implementation. Earlier documentation claiming "the default implementation directly calls `_on_execution_completed()`" was wrong.
- **Three execution modes**: `ExecutionMode = { AUTO_DETECT, FORCE_ASYNC, FORCE_SYNC }`; `AUTO_DETECT` is decided via static analysis in `_detect_sync_capability()`
- **Lifecycle state machine**: `ExecutionStatus = { PENDING, RUNNING, COMPLETED, CANCELLED, ERROR }`
- **Timeout mechanism**: `set_timeout()` / `_setup_timeout_timer()` use `SceneTreeTimer`, preventing long instructions from blocking
- **RuntimeInstructionInstance integration**: runtime state (timeout/pause/cancel) is carried by `RuntimeInstructionInstance`, while BaseInstruction itself keeps the pure data/configuration nature of a Resource
- **Static analysis hooks**: methods such as `_get_variable_accesses()` are called by `InstructionAnalyzer.analyze_problems`
- **i18n resource names**: instruction names/descriptions localized through `FuseLocalization`
- **Four-level icon fallback**: metadata icon → category icon → type default → builtin placeholder
- **Unified logging/errors**: `_log_debug/_log_info/_log_warning/_log_error` + `_log_*_localized` all delegate to `FuseLogger`; `_create_fuse_error()` / `_create_fuse_error_localized()` create `FuseError` instances stored in `_fuse_error`

### 2.2 ExecutionContext - The Execution Context (base/execution_context.gd)

`ExecutionContext extends RefCounted`. **In v2.0 it was refactored into a facade**, with its former state split into two subsystems:

| Subsystem | Class | Responsibilities |
|--------|-----|---------|
| Variable subsystem | `VariableContext extends RefCounted` | Local/scope/global variable CRUD, variable-name LRU cache, indexed access optimization, loop control flags (break/continue/nested stack) |
| Diagnostics subsystem | `ExecutionDiagnostics extends RefCounted` | Execution state machine, execution history, state change listeners, progress tracking, state statistics, dependency graph |

EC fields (execution_context.gd):

```gdscript
var target: Node = null              ## Target node (what instructions operate on)
var trigger = null                   ## Trigger node
var owner: Node = null               ## Owner node
var tree: SceneTree = null
var local_variables: Dictionary = {} ## Compatibility reference, points to _variable_context.local_variables
var global_variables = null          ## Compatibility reference
var _global_variable_assistant: GlobalVariableAssistant = null
var _variable_context: VariableContext = null
var _diagnostics: ExecutionDiagnostics = null
var custom_data: Dictionary = {}
var execution_start_time: float
var execution_id: String
var log_level: FuseLogger.LogLevel
var action_runner = null
var delta_time: float
var _target_weakref: WeakRef
var _trigger_weakref: WeakRef
var _fuse_error: FuseError
```

The EC public API (`set_variable` / `get_variable` / `set_break_loop` / `precompile_variable_access` / `get_all_local_variables_snapshot`, etc.) all delegate to `_variable_context` or `_diagnostics`. The `_execution_state` / `_execution_history` / `_break_loop_flag` fields described in earlier documentation have moved into these two subsystems.

### 2.3 ActionRunner - Dual Layers of Resource Definition + Runtime Orchestration (base/action_runner.gd)

The ActionRunner system adopts the dual layers of "Resource definition + RefCounted runtime orchestration":

**Resource layer — `ActionRunner extends Resource` (base/action_runner.gd)**:
- `@export var instructions: Array[BaseInstruction]` — the instruction sequence (data carrier)
- `@export var execution_mode: ExecutionMode = SEQUENTIAL` — `SEQUENTIAL` / `PARALLEL`
- `@export var stop_on_error: bool = true`
- `@export var enable_instruction_timeout: bool` / `instruction_timeout: float`
- The static `ExecutionMode` enum
- `is_running` / `is_canceling` / `cancellation_reason` / `current_context` — compatibility fields
- A built-in `_SignalAggregator` (different from the runtime layer's `_ParallelSignalAggregator`)
- Preloads `CompiledInstructionSequenceClass` (compiled cache)

**Runtime layer — `RuntimeActionRunnerInstance extends RefCounted` (runtime_action_runner_instance.gd)**:

```gdscript
class_name RuntimeActionRunnerInstance extends RefCounted

signal execution_completed(total_time: float)
signal execution_failed(error_message: String)
signal execution_canceled(reason: String)
signal instruction_started(instruction: BaseInstruction)
signal instruction_completed(instruction: BaseInstruction)
signal all_instructions_completed()

var action_runner: ActionRunner
var runtime_state: Dictionary = {}
var owner_trigger: Node
var _instruction_instances: Array[RuntimeInstructionInstance]
```

Key performance optimizations (Phase 1/2/2.5):

| Optimization | Implementation |
|------|------|
| State-cached variables | `_is_running_cached` / `_is_canceling_cached` / `_context_cached` replace dictionary lookups |
| Validation cache | `_instructions_validated` / `_validated_instruction_count` avoid re-validating every frame |
| Batch signal mode | `set_batch_signal_mode(true)` buffers the `instruction_started/completed` signals and emits them in one batch at the end of execution (enabled by default on Trigger) |
| Shared object pool | `static var _shared_instruction_pool` → `InstructionInstancePool.new(32, 128)`, shared by all instances |
| Compiled cache | Integrates `CompiledInstructionSequence` (core/execution/) |

Execution flow: `run(context)` → validation → acquire a `RuntimeInstructionInstance` via `InstructionInstancePool.acquire()` → `_execute_instruction()` → sync/async branch → wrap-up by `_SignalAggregator`/`_ParallelSignalAggregator`.

### 2.4 Trigger - The Trigger Quartet + Dual Runtime Instances

The Trigger system is the bridge between events and actions, made up of four classes:

| Class | Inheritance | Path | Role |
|----|------|------|------|
| `BaseTrigger` | `@abstract extends Node` | `core/base_trigger.gd` | Abstract base class: 5 abstract methods + cooldown checks + signal management + engine callback forwarding |
| `Trigger` | `extends BaseTrigger` | `core/trigger.gd` | Single-event trigger, the most common |
| `MultiEventTrigger` | `extends BaseTrigger` | `core/multi_event_trigger.gd` | Multi-event binding (`Array[EventBinding]`), merged into one node |
| `Runner` | `extends Node` (does not inherit BaseTrigger) | `core/runner.gd` | Signal auto-binding execution entry (no event layer) |

> ⚠️ Path correction: `BaseTrigger` lives at `core/base_trigger.gd` (not `core/base/base_trigger.gd`).

#### 2.4.1 BaseTrigger Abstract Methods (base_trigger.gd:51-63)

```gdscript
@abstract func get_event_count() -> int
@abstract func get_event_at(index: int) -> BaseEvent
@abstract func get_runtime_event_instance_at(index: int) -> RuntimeEventInstance
@abstract func get_action_runner_instance_at(index: int) -> RuntimeActionRunnerInstance
@abstract func _on_pool_reset() -> void
```

Public capabilities provided by BaseTrigger:
- **`CooldownMode` enum**: `NONE` / `GLOBAL_COOLDOWN` / `PER_OBJECT_COOLDOWN`
- **Cooldown check**: `_check_cooldown(index, context, cooldown_mode, cooldown_time)`, with state written into `RuntimeEventInstance.runtime_state`
- **Execution context creation**: `_create_execution_context(target, index)` syncs event parameters into the EC
- **ActionRunner signal management**: `_connect_action_runner_signals_at` / `_disconnect_action_runner_signals_at` (uniformly connecting `execution_completed/failed/canceled`)
- **Engine callback forwarding**: `_process` / `_physics_process` / `_unhandled_input` / `_notification` forwarded to each Event's `on_process` / `on_physics_process` / `handle_input`, etc.
- **Pooling support**: `pool_mode: bool` + the `pool_reset()` hook

#### 2.4.2 Trigger - Single-Event Trigger (trigger.gd)

```gdscript
@export var event_definition: BaseEvent
@export var action_runner: ActionRunner
@export var trigger_once: bool = false
@export var cooldown_mode: CooldownMode
@export var cooldown_time: float

var _runtime_event_instance: RuntimeEventInstance = null
var _runtime_action_runner_instance: RuntimeActionRunnerInstance = null
```

**Dual Runtime instances**: each Trigger holds `_runtime_event_instance` + `_runtime_action_runner_instance`. Lifecycle:

1. `_on_trigger_ready()`: create `RuntimeEventInstance.new(event_definition, self)` → `event_definition.initialize_with_runtime_instance(self, instance)` → create `RuntimeActionRunnerInstance.new(action_runner, self)` → `set_batch_signal_mode(true)` → connect signals
2. `_on_event_fired(context)`: cooldown check → `_create_execution_context(context, 0)` → `_runtime_action_runner_instance.run(ec)`
3. `_on_trigger_exit_tree()`: terminate the event, disconnect signals, `cleanup()` both Runtime instances

#### 2.4.3 MultiEventTrigger - Multi-Event Trigger (multi_event_trigger.gd)

```gdscript
@export var event_bindings: Array[EventBinding]  ## each EventBinding = (event, action_runner, conditions, ...)

signal event_completed_with_index(binding_index: int, context: Dictionary)
signal event_stopped_with_index(binding_index: int, reason: String, context: Dictionary)
```

Each binding independently maintains a pair of `RuntimeEventInstance` + `RuntimeActionRunnerInstance`, and supports `use_conditions` (controlling the dynamic visibility of the conditions field inside `EventBinding`). `trigger_binding(index, context=null)` manually fires the given binding. `_initialize_runtime_instances()` calls `_cleanup_runtime_instances()` first internally.

Parallel condition evaluation is supported: `check_conditions_parallel(binding_index, context)` delegates to `ParallelConditionEvaluator`.

#### 2.4.4 Runner - Signal Auto-Binding Execution Entry (runner.gd)

`Runner extends Node` (not BaseTrigger), used for direct "external signal → ActionRunner" execution (no Event layer required):

```gdscript
@export_storage var action_runner: ActionRunner
@export_storage var target_node: NodePath
@export_storage var signal_name: String
@export_storage var log_level: FuseLogger.LogLevel
var current_execution_context: ExecutionContext  ## set at runtime (read by the variable watcher)
var _runtime_instance: RuntimeActionRunnerInstance
```

Features:
- **Editor integration**: `@tool`; `_editor_refresh_signals()` collects available signals via `SignalManager.get_node_signals(target)` → the `signal_name` dropdown; icon `ViewportSpeed.png`
- **Runtime signal discovery**: validated via `SignalManager.has_signal_named(node, name)` (not the `get_signal_list()` of earlier documentation)
- **`@export_storage` semantics**: fields persist into the scene file, avoiding Resource reference cycles
- Public API: `run(context_node=null)` / `cancel(reason)` / `stop()` / `is_running()` / `is_canceling()` / `wait_completed()` / `get_execution_status()`

## 3. The Condition System (base/base_condition.gd)

`BaseCondition extends Resource`. Key features:

- **`_evaluate_condition()` is `@abstract`**: subclasses must implement the concrete evaluation logic
- **`is_thread_safe: bool` + `_compute_thread_safety()`**: declares thread safety, which together with `ParallelConditionEvaluator` decides whether to run in parallel
- **Cache mechanism**: `enable_cache` / `cache_duration` + `_cached_result` / `_cache_timestamp` / `_cache_context_hash`; `_is_cache_valid()` checks both time expiry and context hash changes
- **Dependency graph**: `get_dependencies()` / `_compute_dependencies()` / `get_affected_variables()` / `get_dependency_graph()`
- **Batch operations**: `check_batch()` / `optimized_check_batch()`
- **Performance monitoring**: `get_performance_metrics()` / `get_cache_info()`
- **Unified logging/errors**: same as BaseInstruction, integrating `FuseError` + `FuseLogger`
- ⚠️ **No signals at all**: earlier documentation mentioning "condition met/failed signals" was wrong; `on_condition_met` / `on_condition_failed` are plain methods

## 4. Event-Driven Architecture

### 4.1 BaseEvent - The Event Base Class (base/base_event.gd)

```gdscript
signal triggered(context: Node)
```

Key BaseEvent interfaces:
- `initialize(owner_node: Node)` / `terminate(owner_node: Node)`
- **`initialize_with_runtime_instance(trigger, runtime_instance)`**: the v2.0 interface that binds `_runtime_instance_ref` to the Event; all state access is forwarded via `get_runtime_state()` to the corresponding `RuntimeEventInstance`
- `handle_input(event)` / `on_process(delta, instance)` / `on_physics_process(delta, instance)` — engine callbacks (forwarded by BaseTrigger)
- `get_event_type()` / `get_description()` / `get_event_icon()` / `get_detailed_info()` / `_get_node_display_name()`

### 4.2 Signal Flow (v2.0 Three-Layer Relay)

```
Triggered inside an Event subclass
  → event_definition.triggered.emit(context)
    → RuntimeEventInstance._on_event_triggered(context)
      → runtime_event_instance.triggered.emit(context)   # instance-level independent signal
        → Trigger._on_event_fired(context)
          → _check_cooldown → _create_execution_context
            → _runtime_action_runner_instance.run(ec)
```

In its `_init()`, `RuntimeEventInstance` connects to `event_definition.triggered` and forwards it, ensuring that when multiple triggers share the same Event Resource each receives its own independent signal (filtered by trigger meta).

### 4.3 A Concrete Event Example

`OnInputKey`: `@export_enum("按下:0", "释放:1", "持续按下:2") var key_event_type` — via `_validate_property()`, `held_initial_delay` / `held_repeat_interval` are only editable in the "持续按下" (held) mode.

## 5. The Variable System (7 Classes, Three-Layer Scopes)

The variable system is the most deeply refactored subsystem of Fuse v2.0. Complete class list:

| # | Class | Type | Path | Responsibility |
|---|----|------|------|------|
| 1 | `BaseVariable` | `extends Resource` | `base/base_variable.gd` | Variable base class; defines the `VariableScope` enum and the value-changed signal |
| 2 | `VariableContext` | `extends RefCounted` | `base/variable_context.gd` | EC variable subsystem: three-layer scope CRUD + LRU cache + loop flags |
| 3 | `VariableContainer` | `extends Resource` **@deprecated** | `base/variable_container.gd` | Old unified storage, deprecated (migrated to EC.local_variables + GlobalVariableAssistant) |
| 4 | `ScopeVariableContainer` | `extends Node` | `base/scope_variable_container.gd` | Scope container attached to nodes, providing SCOPE variables for a subtree |
| 5 | `GlobalVariableManager` | `extends RefCounted` | `core/global_variable_manager.gd` | **Not a Node singleton**: `static var _instance`, Mutex thread safety, variable CRUD + resource persistence |
| 6 | `GlobalVariableAssistant` | `extends Node` | `core/global_variable_assistant.gd` | Scene proxy node bridging the Manager and the scene tree; delayed autosave timer |
| 7 | `GlobalVariableResource` | `extends Resource` | `core/global_variable_resource.gd` | Global variable data carrier; normalization + deep-copy serialization |
| - | `GlobalVariableService` | `extends RefCounted` | `core/global_variable_service.gd` | Pure logic service layer, standing in for the Assistant when no scene exists |
| - | `ScopeVariableManager` | `extends Node` | `core/scope_variable_manager.gd` | Singleton Node registry managing all `ScopeVariableContainer`s |

### 5.1 The VariableScope Three-Layer Scopes (base_variable.gd:41-45)

```gdscript
enum VariableScope {
    LOCAL = 0,      ## Local variables (ExecutionContext lifetime)
    SCOPE = 1,      ## Scope variables (ScopeVariableContainer lifetime)
    GLOBAL = 2      ## Global variables (GlobalVariableAssistant lifetime)
}
```

> ⚠️ Correction: earlier documentation claiming there are only the two values `LOCAL/GLOBAL` was wrong.

### 5.2 BaseVariable Key Points (base/base_variable.gd)

- The `value: Variant` setter assigns directly (**no type validation**; the `_validate_value()` of earlier documentation was fabricated), firing the `value_changed(old, new)` signal
- `variable_name` / `description` / `scope` / `log_level`
- Factory method `static func create(name, val, scope=LOCAL) -> BaseVariable`
- `set_value(new_value) -> bool` / `get_value() -> Variant` / `reset()` / `get_type_name() -> String`
- ⚠️ Earlier documentation's "loose type validation" was based on the nonexistent `_validate_value()`; the actual semantics are free Variant assignment, with type safety checked on demand by consumers (e.g. the set_variable instruction)

### 5.3 VariableContext - Three-Layer Dispatch (base/variable_context.gd:59-69)

```gdscript
func set_variable(name: String, value: Variant, scope: String = "local") -> bool:
    match scope:
        "scope":  return _set_scope_variable(name, value)
        "global": return _set_global_variable(name, value)
        "local":  return _set_local_variable(name, value)
```

- **LOCAL**: written directly into the `local_variables` Dictionary
- **SCOPE**: written after locating the container via `ScopeVariableManager.find_nearest_scope(node)`
- **GLOBAL**: delegated through the `_global_variable_assistant` or the `global_variables` reference
- **Fallback chain**: when `get_variable("local")` finds nothing, it falls back to querying global

### 5.4 GlobalVariableManager - The RefCounted Singleton (global_variable_manager.gd)

```gdscript
class_name GlobalVariableManager extends RefCounted
static var _instance: GlobalVariableManager = GlobalVariableManager.new()  ## static initialization to avoid races

signal variable_added(name, variable)
signal variable_removed(name)
signal variable_changed(name, old_value, new_value)
```

> ⚠️ Correction: earlier documentation calling it a "singleton Node" was wrong; it actually `extends RefCounted`, and the static `_instance` is accessed via `get_instance()`. All CRUD operations are protected by `_mutex: Mutex`.

API: `add_variable` / `get_variable` / `has_variable` / `remove_variable` / `save_to_resource` / `load_from_resource` / `save_persistent_to_resource` / `get_all_variables_snapshot`.

### 5.5 Variable Operation Utilities

- **`VariableOperations`** (utils/variable_operations.gd): static methods `get_variable()` / `set_variable()` / `check_variable()`, papering over the access differences between LOCAL/SCOPE/GLOBAL
- **`VariableScopeUtils`** (utils/variable_scope_utils.gd): enum/string conversion, `ScopeSource` handling, and `validate_scope_source_property()` for `_validate_property()` callbacks

## 6. The Editor Tool System

### 6.1 The Instruction Registry and Metadata

Each instruction provides metadata through a static method (`_get_instruction_metadata()`), collected by the editor-side registry (under `editor/`, out of scope for this document).

### 6.2 Conditional Property Visibility

`_validate_property(property: Dictionary)` is a standard Godot hook used to dynamically control property visibility. Typical usage (OnInputKey):

```gdscript
func _validate_property(property: Dictionary) -> void:
    if key_event_type != 2:  # not the held mode
        if property.name == "held_initial_delay" or property.name == "held_repeat_interval":
            property.usage = PROPERTY_USAGE_READ_ONLY
```

`VariableScopeUtils.validate_scope_source_property()` follows the same pattern.

## 7. Serialization and Persistence (serialization/instruction_serializer.gd)

`InstructionSerializer` provides instruction serialization/deserialization:

- **Static property cache** `_property_cache: Dictionary`: caches the `PROPERTY_USAGE_STORAGE` property list per type, avoiding reflection every time
- **`serialize_instruction(instruction) -> Dictionary`**: serializes using the cached property list
- **`deserialize_instruction(data) -> Dictionary`**: `_create_instruction()` based on the `type` field, then `set`s each property

Global variable persistence is handled by `GlobalVariableManager.save_to_resource()` / `GlobalVariableResource._to_dict()` / `from_dict()`.

## 8. The Logging System and Error Handling (logging/)

### 8.1 FuseLogger (logging/fuse_logger.gd)

Unified leveled logging:

```gdscript
enum LogLevel { NONE, INFO, WARNING, ERROR, DEBUG }
```

- **Two-layer level control**: `component_level` (component configuration) + `message_level` (per message); output only when `message_level <= component_level`
- **Rich text**: `print_rich` outputs with colors (red=error / yellow=warning / green=info / cyan=debug)
- **Localization**: `log_debug_localized()` / `log_info_localized()`, etc., supporting translation keys + arguments
- **Performance**: caches the `FuseLocalization` class reference to avoid repeated `load()`

### 8.2 FuseError (logging/fuse_error.gd)

```gdscript
enum ErrorType { VALIDATION_ERROR, EXECUTION_ERROR, CONFIGURATION_ERROR, RUNTIME_ERROR, TIMEOUT_ERROR }
```

- **`context: Dictionary`**: attach arbitrary context
- **Automatic logging**: `_log_to_fuse_logger()` writes to the log on construction
- **Localization**: the `create_*_localized()` family of static methods

All core components (BaseInstruction / BaseCondition / BaseTrigger / RuntimeEventInstance / RuntimeActionRunnerInstance, etc.) integrate the `_fuse_error` instance variable and the `_create_fuse_error()` / `_create_fuse_error_localized()` methods.

## 9. Performance Optimization and Memory Management

### 9.1 Smart Caching

| Cache | Location | Notes |
|------|------|------|
| Property cache | `InstructionSerializer._property_cache` | Reflection cache of serialized property lists |
| Variable-name LRU cache | `VariableContext._variable_name_cache` | StringName cache, `_cache_max_size=1000` |
| Indexed access | `VariableContext._variable_index_map` + `_variable_array` | Precompiled via `precompile_variable_access()` |
| Condition result cache | `BaseCondition._cached_result` + context hash | Dual validation of time expiry + context change |
| Validation cache | `RuntimeActionRunnerInstance._instructions_validated` | Avoids re-validating the instruction array every frame |
| Compiled cache | `CompiledInstructionSequence._descriptions` | Pre-cached description strings, invalidated when the instruction count changes |
| Reflection cache | `ReflectionCache` (auto-cleaned by FuseEventBus) | `clear_node()` when a node is removed |

### 9.2 Memory Optimization

- **WeakRef**: the EC's `_target_weakref` / `_trigger_weakref` avoid node reference cycles
- **Runtime instance isolation**: lightweight RefCounted lifecycles, avoiding Resource duplication
- **Object pool reuse**: see §11

### 9.3 Sync/Async Execution Optimization

```gdscript
func can_execute_sync() -> bool:
    match execution_mode:
        ExecutionMode.FORCE_SYNC:  return true
        ExecutionMode.FORCE_ASYNC: return false
        ExecutionMode.AUTO_DETECT: return _detect_sync_capability()
```

`RuntimeActionRunnerInstance._execute_instruction()` takes a fast path for synchronous instructions, avoiding await overhead.

## 10. Design Pattern Analysis

### 10.1 The Template Method Pattern
BaseInstruction / BaseCondition / BaseTrigger / BaseEvent define the skeleton through `@abstract` methods; subclasses fill in the concrete logic.

### 10.2 The Strategy Pattern
- `ActionRunner.ExecutionMode = { SEQUENTIAL, PARALLEL }`
- `BaseInstruction.ExecutionMode = { AUTO_DETECT, FORCE_ASYNC, FORCE_SYNC }`
- `ParallelConditionEvaluator.EvaluationMode = { SEQUENTIAL, PARALLEL_SAFE, PARALLEL_ALL }`
- `BaseTrigger.CooldownMode = { NONE, GLOBAL_COOLDOWN, PER_OBJECT_COOLDOWN }`

### 10.3 The Observer Pattern
- BaseEvent `signal triggered(context)`
- RuntimeEventInstance / RuntimeActionRunnerInstance, each with independent signals
- BaseVariable `signal value_changed(old, new)`
- GlobalVariableManager `signal variable_added/removed/changed`
- The FuseEventBus global event bus (see §11.8)

### 10.4 The Factory Pattern
`BaseVariable.create(name, val, scope)`, `RuntimeActionRunnerInstance.get_shared_pool()`.

### 10.5 The Singleton Pattern (RefCounted static _instance)
- `GlobalVariableManager._instance` (RefCounted)
- `FuseTaskManager._instance` (RefCounted)
- `FusePoolManager._instance` (RefCounted)
- `RuntimeActionRunnerInstance._shared_instruction_pool` (RefCounted)

> Note: `GlobalVariableManager` is not a Node singleton; it is a RefCounted static instance.

### 10.6 The Facade Pattern
The `ExecutionContext` facade delegates to `VariableContext` + `ExecutionDiagnostics`.

### 10.7 The Self-Declared State Pattern
`BaseEvent.get_default_runtime_state()` lets an Event describe its own runtime state, replacing hard-coded match branches (`RuntimeEventInstance._initialize_runtime_state()` checks this method first).

### 10.8 The Pooling Pattern
`InstructionInstancePool` / `FuseObjectPool` / `FusePoolManager` reuse instances.

## 10.x Summary

Fuse is a visual programming system built on the "resource + runtime dual-layer" architecture. Its core engineering value lies in:
1. **Thorough state isolation**: Resources only describe; Runtime instances carry state — multiple triggers sharing the same Resource cause no pollution
2. **Clear three-layer scopes**: explicit LOCAL/SCOPE/GLOBAL layering, with the `ScopeVariableContainer` node chain enabling hierarchical scoping
3. **Unified infrastructure**: `FuseLogger` + `FuseError` + `FuseLocalization` consistent across the whole stack
4. **Engineered performance**: layer upon layer of optimization — object pools, compiled caches, state-cached variables, batch signal mode
5. **Complete thread-safety infrastructure**: `FuseTaskManager` + `ParallelConditionEvaluator` + `FuseThreadSafe`

---

## 11. Architecture Evolution: Systems Added in 2026

This chapter records the major architectural extensions Fuse introduced in early 2026. On top of the original core architecture of event-driven execution, instruction execution, and condition evaluation, these new systems introduce runtime instantiation, a unified variable system, multithreading support, an expression system, and an enhanced editor toolchain, further improving the system's engineering maturity.

> Note: §1–10 have already folded these facts back into the main body; this chapter is kept as an "evolution timeline + detailed explanation".

### 11.1 The Runtime Instance Architecture (Runtime Instance Pattern)

The runtime instance architecture is one of the most important architectural evolutions of 2026. Its core idea is to completely separate the **definition resource** (Resource) from the **runtime state** (Runtime State), avoiding the state pollution problem when multiple triggers share the same resource.

#### 11.1.1 The Three-Layer Runtime Instance System

The system provides corresponding runtime instance classes for events, instructions, and action runners, all extending `RefCounted` for lightweight lifecycle management:

| Definition resource | Runtime instance | Path | Core responsibility |
|---------|-----------|------|---------|
| `BaseEvent` | `RuntimeEventInstance` | `core/runtime_event_instance.gd` | Event runtime state storage, independent signal forwarding |
| `BaseInstruction` | `RuntimeInstructionInstance` | `core/runtime_instruction_instance.gd` | Instruction runtime instance with timeout/pause/cancel support |
| `ActionRunner` | `RuntimeActionRunnerInstance` | `core/runtime_action_runner_instance.gd` | ActionRunner runtime instance, instruction sequence orchestration |

#### 11.1.2 The Self-Declared State Pattern

The new architecture introduces the `get_default_runtime_state()` method, allowing events and instructions to define their runtime state in a self-declared manner, replacing the old hard-coded match branch pattern:

```gdscript
# New architecture: the Event self-declares its state (recommended)
func get_default_runtime_state() -> Dictionary:
    return {
        "timer": null,
        "elapsed_time": 0.0,
        "is_running": false,
        "duration": 1.0
    }
```

`RuntimeEventInstance._initialize_runtime_state()` checks this method first, falling back to `_initialize_runtime_state_legacy()` for backward compatibility.

#### 11.1.3 Key Features of RuntimeInstructionInstance

- **Signal multiple-firing protection**: the `_is_completed` flag prevents the `finished` signal from firing more than once
- **Execution timeout mechanism**: the timeout is configured via `execution_timeout`, implemented internally with `SceneTreeTimer`
- **Pause/resume**: supported through the `pause()` / `resume()` methods, with instructions notified via the `on_runtime_pause` / `on_runtime_resume` callbacks
- **Object pool support**: the `reinitialize()` and `reset_for_pool()` methods support instance reuse

#### 11.1.4 Performance Optimizations of RuntimeActionRunnerInstance

- **State-cached variables**: `_is_running_cached` / `_is_canceling_cached` plain variables replace dictionary lookups, avoiding dictionary overhead on hot paths
- **Batch signal mode**: `set_batch_signal_mode(true)` buffers the `instruction_started` / `instruction_completed` signals and emits them in one batch after execution ends, reducing signal overhead in high-frequency scenarios
- **Validation cache**: the `_instructions_validated` flag avoids re-validating the same instruction array every frame
- **Compiled cache integration**: `CompiledInstructionSequence` (`core/execution/`) caches compilation results such as instruction descriptions
- **Shared object pool**: `InstructionInstancePool` statically pools `RuntimeInstructionInstance`s; all instances share one pool (`get_shared_pool()`)

> **Reference document:** `archive/architecture/runtime-instance-pattern.md`

### 11.2 The Unified Variable System

In 2026 the variable system underwent a major refactor, evolving from the single `VariableContainer` into the **three-layer variable system** (Local / Scope / Global) with a unified operation interface. See §5 for details.

#### 11.2.1 The Global Variable Subsystem

The global variable subsystem consists of four core classes:

- **`GlobalVariableManager`** (`core/global_variable_manager.gd`): a **RefCounted static singleton** (not a Node) that uses a `Mutex` for thread safety and supports variable CRUD, resource persistence (`save_to_resource` / `load_from_resource` / `save_persistent_to_resource`), batch operations, and variable snapshots (`get_all_variables_snapshot`)
- **`GlobalVariableResource`** (`core/global_variable_resource.gd`): extends `Resource`, the data carrier for global variables. Supports variable data normalization (`_normalize_variable_data`), deep-copy serialization (`from_dict` / `_to_dict`), and serializable value validation
- **`GlobalVariableAssistant`** (`core/global_variable_assistant.gd`): a scene node acting as the manager's scene proxy. Supports autosave (with a delayed-save timer), persistent variable cleanup, and bridging resource loading/saving
- **`GlobalVariableService`** (`core/global_variable_service.gd`): a pure RefCounted service layer that stands in for the Assistant when no scene exists; API naming aligned with the Assistant

#### 11.2.2 The Scope Variable Subsystem

Scope variables implement hierarchical variable management based on the scene tree:

- **`ScopeVariableContainer`** (`base/scope_variable_container.gd`): a scope container attached to scene nodes, providing scope-level variable storage. Supports `InheritanceMode` and forms a hierarchy chain via `get_parent_scope()` / `get_child_scopes()` / `get_scope_chain()`
- **`ScopeVariableManager`** (`core/scope_variable_manager.gd`): a singleton Node registry managing registration/unregistration of all scope containers. Supports lookup by `scope_id`, upward search from a node for the nearest container (`find_nearest_scope`), and getting the node chain (`get_scope_node_chain`)

#### 11.2.3 Variable Operation Utilities

- **`VariableOperations`** (`utils/variable_operations.gd`): a unified three-layer variable operation interface with the static methods `get_variable()` / `set_variable()` / `check_variable()`, papering over the LOCAL / SCOPE / GLOBAL access differences
- **`VariableScopeUtils`** (`utils/variable_scope_utils.gd`): a scope utility class providing enum/string conversion, scope source (`ScopeSource`) handling, and property visibility validation (`validate_scope_source_property`) for `_validate_property()` callbacks

#### 11.2.4 The Variable Scope Enum Extension

`BaseVariable.VariableScope` (base_variable.gd:41-45) forms a complete three-level system:

```gdscript
enum VariableScope {
    LOCAL = 0,   # Local variables (ExecutionContext lifetime)
    SCOPE = 1,   # Scope variables (ScopeVariableContainer lifetime)
    GLOBAL = 2   # Global variables (GlobalVariableAssistant lifetime)
}
```

### 11.3 The Object Pool System (core/pooling/, 5 Classes)

The object pool system was **entirely missing** from earlier documentation; this section is new. The 5 classes live under `core/pooling/`:

| Class | Inheritance | Path | Responsibility |
|----|------|------|------|
| `FuseObjectPool` | `RefCounted` | `pooling/fuse_object_pool.gd` | General scene object pool with automatic growth/shrink, performance monitoring, `warm_up` preheating, and `reset_object` for resetting Fuse components |
| `FusePoolItem` | `RefCounted` | `pooling/fuse_pool_item.gd` | Pool item wrapper tracking `in_use` / `last_used_time` / `usage_count`; provides `is_expired` / `get_efficiency_score` |
| `FusePoolManager` | `RefCounted` | `pooling/fuse_pool_manager.gd` | Global pool manager (`get_instance()` singleton) uniformly managing the `scene_path -> FuseObjectPool` mapping; supports `instantiate_pooled` / `recycle_pooled` |
| `FuseRecycleTimer` | `Node` | `pooling/fuse_recycle_timer.gd` | Dedicated recycle timer driven by `SceneTreeTimer`, weak-referencing instances to avoid cycles; `_creation_usage_count` detects object reuse |
| `InstructionInstancePool` | `RefCounted` | `pooling/instruction_instance_pool.gd` | Dedicated pool for `RuntimeInstructionInstance`: `acquire()` / `release()` / `release_all()`, defaults `_pool_size=32` / `_max_pool_size=128`, statically shared via `RuntimeActionRunnerInstance._shared_instruction_pool` |

Design points:
- Pooled objects reset Trigger / ActionRunner state via `_reset_fuse_components(node)`, and `_terminate_fuse_triggers(node)` cleans up events
- `_schedule_safe_remove(obj)` removes safely with a delay, avoiding within-frame deletion conflicts
- `get_statistics()` / `get_detailed_status()` provide pool efficiency monitoring

### 11.4 The Threading System (core/threading/, 4 Classes)

The threading system gives Fuse safe, efficient parallel processing, mainly serving compute-intensive scenarios such as condition evaluation. See the [Multithreading Developer Guide](../../dev_docs/guides/multithreading-developer-guide.md).

| Class | Inheritance | Path | Responsibility |
|----|------|------|------|
| `FuseTaskManager` | `RefCounted` | `threading/fuse_task_manager.gd` | Wraps `WorkerThreadPool`; `TaskStatus = {PENDING, RUNNING, COMPLETED, FAILED, CANCELED}`; `submit_task` / `submit_batch` / `await_task` / `await_all` |
| `ParallelConditionEvaluator` | `RefCounted` | `threading/parallel_condition_evaluator.gd` | Parallel condition evaluation; `EvaluationMode = {SEQUENTIAL, PARALLEL_SAFE, PARALLEL_ALL}`; context snapshots avoid races |
| `FuseThreadSafe` | `RefCounted` | `threading/fuse_thread_safe.gd` | Thread-safety utilities: static methods such as `dict_get_safe` / `dict_set_safe` / `dict_has_safe` / `arr_append_safe` wrapping a Mutex |
| `FuseThreadingConfig` | `Resource` | `threading/fuse_threading_config.gd` | Threading configuration: `enable_multithreading` / `parallel_condition_evaluation` / `max_parallel_conditions` (1-16) |

#### 11.4.1 The FuseTaskManager Task Manager

`FuseTaskManager` wraps Godot's `WorkerThreadPool` and provides a unified asynchronous task interface:

- **Task lifecycle**: `PENDING` -> `RUNNING` -> `COMPLETED` / `FAILED` / `CANCELED`
- **Submission interface**: `submit_task()` submits a single task, `submit_batch()` submits in bulk; both return task IDs for tracking
- **Synchronous waiting**: `await_task()` / `await_all()` support blocking waits with a timeout (note: should not be used on the main thread)
- **Thread safety**: a `Mutex` protects the task state dictionary and the completion notification queue
- **Signal notification**: `task_completed` / `task_failed` are emitted thread-safely; receivers should use `CONNECT_DEFERRED`

#### 11.4.2 The ParallelConditionEvaluator Parallel Condition Evaluator

Parallelism is enabled only for conditions marked `is_thread_safe` (`PARALLEL_SAFE` mode):

- **Context snapshot**: before parallel evaluation, a deep-copy snapshot of the `ExecutionContext` is created (including local and global variables) to avoid race conditions
- **Semaphore synchronization**: `Semaphore.post()` / `try_wait()` wait for all parallel tasks to finish, with a `Mutex` protecting the results array
- **Timeout protection**: `timeout_per_condition: float = 0.1`, a wait loop with timeout

> `MultiEventTrigger.check_conditions_parallel()` delegates to this evaluator, mitigating the "condition evaluation cannot be parallelized" weakness listed in earlier documentation.

### 11.5 Compiled Cache and Execution Diagnostics (New Top-Level Classes)

#### 11.5.1 CompiledInstructionSequence (execution/compiled_instruction_sequence.gd)

```gdscript
class_name CompiledInstructionSequence extends RefCounted
```

Phase 3 performance optimization: precompiles the descriptions and method bindings of an instruction sequence, reducing repeated computation overhead when `RuntimeActionRunnerInstance` executes.

- `_descriptions: PackedStringArray` — pre-cached description strings
- `_execution_callables: Array[Callable]` — pre-bound execution methods (reserved in Phase 3.2)
- `_instruction_count: int` + `_is_valid: bool` — cache invalidation checks
- `compile(action_runner) -> bool` / `is_valid_for(action_runner) -> bool` / `invalidate()`

`ActionRunner` (base/action_runner.gd) references it via the `CompiledInstructionSequenceClass` preload, and `RuntimeActionRunnerInstance` integrates and uses it.

#### 11.5.2 ExecutionDiagnostics (base/execution_diagnostics.gd)

```gdscript
class_name ExecutionDiagnostics extends RefCounted
```

The EC diagnostics subsystem, split out of the earlier inline ExecutionContext state:

- `_execution_state: int` — the `ExecutionContext.ExecutionState` state machine
- `_execution_history: Array[Dictionary]` — history records (`_max_history_size=100`)
- `_state_change_listeners: Array[Callable]` — state change listeners
- `get_dependency_graph()` / `check_dependencies(deps)` / `get_dependency_status()` — the dependency graph and visualization data

### 11.6 Unified Error Handling

#### 11.6.1 The FuseError Class (see §8.2 for details)

- **Error type enum**: `VALIDATION_ERROR` / `EXECUTION_ERROR` / `CONFIGURATION_ERROR` / `RUNTIME_ERROR` / `TIMEOUT_ERROR`
- **Context information**: `context: Dictionary` stores arbitrary additional context data
- **Automatic logging**: the constructor automatically calls `_log_to_fuse_logger()` to write the error into the log
- **Localization support**: the `create_*_localized()` family of static methods creates localized error messages from translation keys and arguments

#### 11.6.2 The Unified Interface

All core components (`BaseInstruction`, `BaseCondition`, `BaseTrigger`, `RuntimeEventInstance`, `RuntimeActionRunnerInstance`, etc.) integrate `FuseError`; error instances are created uniformly via the `_create_fuse_error()` and `_create_fuse_error_localized()` methods and stored in the `_fuse_error` instance variable.

### 11.7 The Unified Logging System (see §8.1 for details)

`FuseLogger` provides unified leveled log management; all `_log_*` methods delegate to it, mitigating the "inconsistent log formats" problem listed in earlier documentation.

### 11.8 Top-Level Node Infrastructure (Autoload Singletons)

#### 11.8.1 FuseEventBus (core/fuse_event_bus.gd)

```gdscript
extends Node  # Autoload singleton (registered as FuseEventBus in project.godot)
```

A global event bus that lets different Triggers communicate through custom events (paired with the `SendEvent` instruction + the `OnReceiveEvent` event).

API:
- `send_event(event_name, args={})` / `send_event_deferred(event_name, args={})`
- `subscribe(event_name, callback) -> Subscription` / `unsubscribe(subscription)`
- `has_listeners(name)` / `get_listener_count()` / `get_registered_events()`
- `get_event_history()` / `clear_history()` / `clear_all_listeners()` (`MAX_HISTORY_SIZE=100`)
- Embedded `class Subscription extends RefCounted` (`event_name` / `callback` / `id`)

Side effect: `_ready()` connects `get_tree().node_removed` → automatically cleans the node caches of `ReflectionCache` + `FunctionManager`.

#### 11.8.2 FuseRuntimeBridge (core/fuse_runtime_bridge.gd)

```gdscript
extends Node  # Autoload singleton (registered as FuseRuntimeBridge in project.godot)
```

The runtime variable TCP bridge, a **dual-mode Autoload**:

| Mode | Role | Behavior |
|------|------|------|
| Editor side | TCPServer | `listen 127.0.0.1:24563`, accepts variable snapshots pushed by the running game, caching them into `_cached` |
| Running-game side | TCP client | Connects to `127.0.0.1:24563`; every `PUSH_INTERVAL=0.5s` collects local/scope variable snapshots of all `Runner`s under the scene, serializes them as JSON lines and pushes them |

Protocol: TCP stream + JSON lines (`\n`-separated), running game → editor: `{"t":"vars","runners":[{"name":"Runner1","local":{...},"scope":{...}},...]}`.

On the editor side, `get_cached_vars() -> Dictionary` is read by the variable watcher; on the running-game side, snapshots are collected via `Runner.current_execution_context._variable_context.get_all_local_variables_snapshot()` / `get_all_scope_variables_snapshot()`.

### 11.9 The Expression System

The expression system gives Fuse runtime dynamic evaluation capabilities, supporting embedded variable references and a rich set of built-in functions.

#### 11.9.1 The ExpressionHelper Utility Class (utils/expression_helper.gd)

- **Variable reference syntax**: variables are referenced in expressions with the `{local:xxx}` / `{scope:xxx}` / `{global:xxx}` syntax and substituted via regex matching (`VAR_PATTERN`)
- **Safe evaluation**: the `evaluate()` method wraps parsing and execution of Godot's `Expression` class; on failure the error message is returned through the `error_text` argument
- **Value escaping**: `escape_value()` for math contexts (numbers preferred), `escape_value_for_string()` for string contexts (preserving the string type)
- **The GameExprHelper inner class**: passed in as the `base_instance` of `Expression.execute()`, providing commonly used game functions:

| Category | Functions |
|------|------|
| Vector | `vec2()`, `vec3()`, `normalize()`, `distance()`, `direction()`, `angle()` |
| Numeric | `remap()`, `inverse_lerp()`, `snap()`, `move_toward_val()`, `is_zero()` |
| String | `format_num()`, `pad_left()`, `pad_right()` |

#### 11.9.2 Expression Instructions and Conditions

Three business components built on `ExpressionHelper` (under `instructions/math/`, `instructions/string/`, `conditions/math/`):

- **`MathExpression`**: a math expression instruction supporting arithmetic, math functions, and vector literals, with the output type selectable among Float / Int / Vector2 / Vector3
- **`StringExpression`**: a string expression instruction supporting concatenation, conditional text, type conversion, and string utility functions
- **`ExpressionCondition`**: an expression condition supporting comparison, logic, and ternary operations, returning a boolean for conditional branching

All three support the `ScopeSource` enum, allowing the scope source in an expression to be specified flexibly (nearest container / custom ID / trigger node / target node).

### 11.10 Editor Tool Extensions

In 2026 the editor toolchain (under `editor/`, out of scope for this document) was greatly expanded, covering three dimensions: debug visualization, static analysis, and code generation. This section only gives an overview:

- **Debug visualization**: `DebugVisualizer` + `ExecutionTracker` (`editor/debugging/`) — tree display of execution history, performance metrics, JSON export
- **Static analysis**: `InstructionAnalyzer.analyze_problems` + `FuseTopology` annotation — detection of undeclared local variables, with results annotated in place on the Topology main screen
- **Automatic instruction generation**: `InstructionGenerator` + `PropertyInstructionGenerator` + helper modules (`TypeMapper` / `ConflictHandler` / `MethodFilter` / `MethodSelectorDialog`)

---

**Last updated**: 2026-07-07 | **Baseline code**: actual implementation under `addons/fuse/core/` | **Audit basis**: [AUDIT_REPORT_2026-07-07.md (Chinese)](../../../zh_CN/system_docs/analysis/AUDIT_REPORT_2026-07-07.md)
