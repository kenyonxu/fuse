> 🌐 [**中文版**](../../../zh_CN/system_docs/analysis/fuse_core_analysis_report.md) | English

# Fuse Visual Programming System - Core Architecture Analysis Report


> **Analyzed as of**: 2026-07-07 (each article verified against code during the same-day full documentation audit; implementation evolution after this point defers to the source code; for recently verified mechanical conclusions see the threading / runtime_instance / preset_nested articles)
## 1. Overview
Fuse is a visual programming system designed for Godot 4.x. Analyzing the core files under `addons/fuse` shows that the system adopts a **resource-driven** architectural design, making full use of Godot's `Resource` system for serialization, editor integration, and runtime logic.

The system's core goal is to decouple game logic into reusable **instructions**, **events**, and **variables**, scheduled through **runners**.

## 2. Core Architecture Components

### 2.1 Instruction System
Instructions are Fuse's smallest execution unit.
*   **Base class**: `BaseInstruction` (`addons/fuse/core/base/base_instruction.gd`)
*   **Design pattern**: Command Pattern
*   **Lifecycle**:
    *   **Initialization**: `_init` and `_setup_metadata` set up the metadata.
    *   **Execution**: `execute(context)` receives the execution context.
    *   **State management**: maintains `ExecutionStatus` (PENDING, RUNNING, COMPLETED, ERROR, CANCELLED).
    *   **Async support**: supports asynchronous operations (waiting for animations, delays, etc.) via the `finished` signal.
*   **Features**:
    *   **Strong typing**: built-in `InstructionMetadata` for editor descriptions.
    *   **Error handling**: integrates `FuseError` and a timeout mechanism (`_timeout_timer`).
    *   **Validation**: the `validate()` method for parameter checks in editor and runtime.

### 2.2 Execution Environment
*   **Class**: `ExecutionContext` (`addons/fuse/core/base/execution_context.gd`)
*   **Role**: provides a "sandbox" environment for instruction execution.
*   **Core functions**:
    *   **Context references**: holds `target` (the target node) and `trigger` (the trigger source).
    *   **Variable access**: manages `local_variables` (local variables) and `global_variables` (global variable references) uniformly.
    *   **State tracking**: records execution ID, start time, and execution history for debugging.
    *   **Dependency injection**: allows instructions to request specific nodes or data.

### 2.3 Flow Control
*   **Class**: `ActionRunner` (`addons/fuse/core/base/action_runner.gd`)
*   **Role**: manages and executes a group of instructions.
*   **Execution modes**:
    *   **SEQUENTIAL**: executes instructions in order, supporting `await` for async instructions to finish.
    *   **PARALLEL**: starts all instructions simultaneously and waits for all of them to finish.
*   **Features**:
    *   **Error interruption**: `stop_on_error` controls whether to abort the sequence on error.
    *   **Timeout control**: supports per-instruction timeout settings.
    *   **Batch operations**: supports batch validation and execution.

## 3. Data Management System

### 3.1 Variable System
*   **Base class**: `BaseVariable` (`addons/fuse/core/base/base_variable.gd`)
*   **Features**:
    *   **Type safety**: defines the `VariableType` enum, supporting Godot basic types and math types.
    *   **Scopes**: `VariableScope` (LOCAL, GLOBAL).
    *   **Factory pattern**: provides static factory methods such as `create_local`, `create_global`.
    *   **Type conversion**: built-in safe type conversion and validation logic.

### 3.2 Variable Containers and Global Management (three-layer scopes)

> After v2.0 the variable system was refactored into **local / scope / global three-layer scopes**; the old `VariableContainer` was marked `@deprecated` (2026-02-08) and is no longer recommended.

| Scope | Storage | Classes involved |
|--------|------|--------|
| **local** | the `ExecutionContext.local_variables` dictionary | `ExecutionContext` / `VariableContext` |
| **scope** | `ScopeVariableContainer` mounted on the node tree (looked up by `scope_id`) | `ScopeVariableContainer` + `ScopeVariableManager` + `VariableContext` |
| **global** | a `BaseVariable` dictionary managed by a static instance | `GlobalVariableAssistant` (Node entry) + `GlobalVariableManager` + `GlobalVariableService` + `GlobalVariableResource` |

*   **VariableContainer** (`addons/fuse/core/base/variable_container.gd`):
    *   **@deprecated (2026-02-08)**: kept only for compatibility; new code should use the three-layer structure above. Its original duties have been split into `ExecutionContext.local_variables` (local) and `GlobalVariableAssistant` (global).
*   **GlobalVariableManager** (`addons/fuse/core/global_variable_manager.gd`):
    *   **Not an autoload Node singleton**: `class_name GlobalVariableManager extends RefCounted`, providing an access point via the static field `static var _instance` + `static func get_instance()` (`global_variable_manager.gd:2/17`).
    *   **The core service layer**: a pure RefCounted logic layer, independent of the scene tree, providing variable CRUD + signals (`variable_added/removed/changed`), persistence (`save_to_resource` / `load_from_resource` / `save_persistent_to_resource`), and thread-safe `_mutex` protection.
    *   **Source of thread safety**: protected by its internal Mutex; the user-facing high-level API is wrapped by the companion `GlobalVariableService` (RefCounted) and `GlobalVariableAssistant` (Node, on the scene tree), which further delegate to the Manager, while `GlobalVariableResource` (Resource) owns the `.tres` persistence format.

## 4. Event-Driven Architecture

### 4.1 The Trigger System
Fuse's triggers use a **two-level inheritance** structure (after the v2.0 refactor):

*   **Abstract base class** `BaseTrigger` (`addons/fuse/core/base_trigger.gd`):
    *   `@abstract class_name BaseTrigger extends Node`
    *   Centralizes common functionality: cooldown checks (`CooldownMode` with three levels NONE / COOLDOWN / THROTTLE), execution context creation, event argument synchronization, engine callback forwarding, logging and FuseError integration.
    *   Declares 5 abstract methods for subclasses to implement, forming the Trigger extension protocol.
*   **Concrete subclass 1** `Trigger` (`addons/fuse/core/trigger.gd`):
    *   `class_name Trigger extends BaseTrigger` (note: **does not directly `extends Node`**)
    *   Single-event trigger: configures one"event → action"binding through the two @export resource fields `event_definition: BaseEvent` and `action_runner: ActionRunner`.
*   **Concrete subclass 2** `MultiEventTrigger` (`addons/fuse/core/multi_event_trigger.gd`):
    *   `class_name MultiEventTrigger extends BaseTrigger`
    *   Multi-event trigger: uses an `EventBinding` array to merge the functionality of multiple Triggers into a single node, reducing the node count; overrides the base-class signals, attaching `binding_index` to identify the trigger source.

**Bridge role**: trigger nodes connect **event definitions (Resources)** and **action execution (ActionRunner / RuntimeActionRunnerInstance)**. Typical flow:
    1.  In `_ready`, calls the event's `initialize_with_runtime_instance(owner_node, runtime_instance)`, binding the event lifecycle to the `RuntimeEventInstance`.
    2.  Listens for the event's `triggered` signal (forwarded through the runtime instance, ensuring multiple Triggers sharing the same Event resource do not interfere with each other).
    3.  When the signal fires, BaseTrigger creates the `ExecutionContext` (with cooldown/throttle checks).
    4.  Delegates to `RuntimeActionRunnerInstance` to execute the instruction sequence.

### 4.2 Event Definitions
*   **Class**: `BaseEvent` (`addons/fuse/core/base/base_event.gd`)
*   **Inherits**: `Resource`.
*   **Decoupling**: event logic is encapsulated in the resource and does not depend on specific nodes.
*   **Lifecycle interface** (dual signatures):
    *   `initialize(owner_node)` / `terminate(owner_node)`: the traditional dynamic signal bind/unbind entry points, overridden by subclasses.
    *   `initialize_with_runtime_instance(owner_node, runtime_instance: RuntimeEventInstance)` (introduced in v2.0, `base_event.gd:137/154`): binds the event lifecycle to the `RuntimeEventInstance`; after saving the `_runtime_instance_ref` reference it forwards to `initialize(owner_node)`, then calls `_initialize_runtime_state(runtime_instance)` so subclasses can consume the runtime state as needed. This is the event-side entry point of the"definition-runtime separation"architecture, ensuring state isolation when multiple Triggers share the same Event resource.

## 5. Infrastructure and Utilities

### 5.1 Serialization
*   **Class**: `InstructionSerializer` (`addons/fuse/core/serialization/instruction_serializer.gd`)
*   **Purpose**: converts instruction objects into dictionary data, and vice versa.
*   **Decoupling**: ensures the core runtime does not depend on the editor's serialization logic, easing save-system integration.

### 5.2 Logging and Errors
*   **FuseLogger**: provides unified log levels (DEBUG, INFO, WARNING, ERROR) and formatted output.
*   **FuseError**: encapsulates runtime errors, including error type, context information, and stack traces.

## 6. Editor Integration
Fuse provides deep editor integration, mainly through scripts under the `addons/fuse/editor` directory.
*   **Instruction registration**: `InstructionRegistry` (`addons/fuse/editor/instruction_selector/instruction_registry.gd`) scans and registers all instructions. It calls each instruction class's static method `_get_instruction_metadata()` to obtain metadata, realizing automatic instruction discovery.
*   **Custom property editors**: uses `EditorInspectorPlugin` (e.g. `CreateVariableInspector`) to provide custom GUIs for specific property types (such as variable default values), improving the user experience.
*   **Instruction selector**: provides a visual dialog where users search for and add instructions by category and keyword.

## 7. Event Implementation Details
Concrete event implementations (such as `OnInputKey`) show how Fuse handles runtime logic.
*   **Input handling**: event classes (such as `OnInputKey`) handle input logic directly and fire signals according to the configuration (pressed/released/held).
*   **Lifecycle management**: through the `initialize(owner_node)` and `terminate(owner_node)` methods, event resources can be dynamically mounted onto `Trigger` nodes and manage their own resources (such as `Timer`s).
*   **Dynamic configuration**: uses `_validate_property` to dynamically adjust property visibility in the Inspector (for example, hiding irrelevant parameters based on event type), keeping the configuration UI concise and correct.

## 8. Instruction Implementation Patterns
Analyzing the `Print` and `Wait` instructions reveals two main instruction implementation patterns:
*   **Synchronous instructions**: like `Print`, execute the logic in the `execute` method and then immediately call `_on_execution_completed()` to finish the instruction.
*   **Asynchronous instructions**: like `Wait`, start an asynchronous operation in `execute` (e.g. creating a `SceneTreeTimer`), wait for it to complete (e.g. connecting the `timeout` signal), and only then call `_on_execution_completed()`. This makes full use of Godot's `signal` and `await` mechanisms.
*   **Metadata definition**: all instructions return an `InstructionMetadata` object via the static method `_get_instruction_metadata()`, defining name, category, description, and keywords for easy editor recognition.

## 9. Summary
Fuse's core architecture shows a high degree of modularity and affinity with Godot:
1.  **Resource-First**: almost all configuration (instructions, variables, events) is a Resource, making it easy to save, reuse, and inspect in the Godot editor.
2.  **Runtime independence**: core logic (`core/`) is separated from editor logic (`editor/`), keeping the shipped game package lean and efficient.
3.  **Extensibility**: new features can be added easily by inheriting `BaseInstruction` or `BaseEvent`, and are registered automatically through the metadata mechanism.
4.  **Robustness**: complete error handling, timeout mechanisms, and type validation are built in.

## v2.0 New Features (2026-03 Update)

The following summarizes the cross-component architectural improvements and new infrastructure introduced in Fuse v2.0.

### FuseError Unified Error Handling System

v2.0 introduced `FuseError` (`addons/fuse/core/logging/fuse_error.gd`) as the system-wide unified error handling infrastructure:

- **Error type enum**: `ErrorType` includes `RUNTIME_ERROR`, `VALIDATION_ERROR`, `EXECUTION_ERROR`, `TIMEOUT_ERROR`, `CONFIGURATION_ERROR`, etc.
- **Context information**: every FuseError instance carries the error type, source component, message, stack trace, and a custom context dictionary
- **Factory method**: `FuseError.create_with_context()` creates a fully contextualized error object in one step
- **Integration scope**: core classes such as ActionRunner, ExecutionContext, BaseTrigger, RuntimeActionRunnerInstance, RuntimeEventInstance, GlobalVariableAssistant, and BaseVariable all integrate the `_fuse_error` field
- **Query interface**: `get_fuse_error()` / `has_fuse_error()` provide unified error queries
- **Localization support**: paired with the `_create_fuse_error_localized()` method, error messages support multilingual translation keys

### FuseLogger Unified Logging System

v2.0 introduced `FuseLogger` (`addons/fuse/core/logging/fuse_logger.gd`) as the system-wide unified log output layer:

- **Log levels**: the `LogLevel` enum includes `NONE`, `DEBUG`, `INFO`, `WARNING`, `ERROR`
- **Unified interface**: `log_debug()`, `log_info()`, `log_warning()`, `log_error()`, plus the localized variants `log_*_localized()`
- **Component identification**: every log entry carries a component name (such as `"ActionRunner"`, `ExecutionContext"`), easing log filtering
- **Level filtering**: controlled via the per-component `log_level` property; output happens only when the log level reaches the threshold
- **System-wide adoption**: all core classes use FuseLogger in place of the earlier direct `print()` / `push_warning()` / `push_error()` calls

### The Runtime*Instance Trio

v2.0 introduced three runtime instance classes, forming the core architectural pattern of"definition-runtime separation":

1. **RuntimeEventInstance** (`addons/fuse/core/runtime_event_instance.gd`)
   - Inherits `RefCounted`, wrapping the `BaseEvent` resource
   - Provides each Trigger independent runtime state (`runtime_state`)
   - The signal forwarding mechanism ensures multiple Triggers sharing the same Event resource do not interfere with each other
   - Supports the self-declared state pattern (`get_default_runtime_state()`) and the legacy match-branch pattern

2. **RuntimeActionRunnerInstance** (`addons/fuse/core/runtime_action_runner_instance.gd`)
   - Inherits `RefCounted`, wrapping the `ActionRunner` resource
   - Provides each Trigger independent execution state and signals
   - Object pool support (`InstructionInstancePool`), reusing RuntimeInstructionInstance in high-frequency firing scenarios
   - Batch signal mode reduces per-instruction signal overhead
   - Validation cache avoids repeated validation

3. **RuntimeInstructionInstance** (obtained from the object pool)
   - Wraps `BaseInstruction`, providing independent state for each execution
   - Supports the unified `execute_sync()` execution interface
   - Managed through `InstructionInstancePool`, pool size configurable (32~128)

This architecture solves the runtime state conflicts caused by Resource sharing, while reducing GC pressure under high-frequency firing through pooling.

### CompiledInstructionSequence: The Compiled Instruction Sequence

v2.0 introduced `CompiledInstructionSequence` (`addons/fuse/core/execution/compiled_instruction_sequence.gd`) as the Phase 3 performance optimization:

- **Pre-cached description strings**: at `compile()` time, all instructions are iterated and their `get_description()` return values pre-generated into a `PackedStringArray`, avoiding repeated runtime calls
- **Pre-bound execution methods**: the instructions' `execute` method references are stored in an `Array[Callable]` (reserved for Phase 3.2)
- **Cache invalidation check**: fast invalidation keyed on the instruction count (`is_valid_for(action_runner)`), avoiding unnecessary recompiles
- **Shared cache**: stored in ActionRunner's `_compiled_cache` field, shared by all RuntimeActionRunnerInstances

### Expression System (ExpressionHelper)

v2.0 introduced `ExpressionHelper` (`addons/fuse/core/utils/expression_helper.gd`) as the unified utility class for expression evaluation:

- **MathExpression instruction support**: provides the underlying computation for expression instructions such as `MathExpression`
- **Shared utility logic**: several expression classes (such as MathExpression, StringExpression) share the common methods in ExpressionHelper
- **Type-safe evaluation**: wraps Godot's `Expression` class, providing type checking and error handling

### Summary of Architectural Improvements

| Improvement area | Problem solved | Core classes |
|---------|-----------|--------|
| Error handling | Scattered error handling lacking unified context | FuseError |
| Log output | Uncontrollable log levels, inconsistent formats | FuseLogger |
| State isolation | Runtime state conflicts caused by Resource sharing | The Runtime*Instance trio |
| Performance optimization | Repeated computation and GC pressure under high-frequency firing | CompiledInstructionSequence + the `core/pooling/` object pool family |
| Variable scopes | Only LOCAL/GLOBAL granularity | `ScopeVariableContainer` + `ScopeVariableManager` + `VariableContext` (the old `VariableContainer` is @deprecated) |
| Global variables | Incomplete persistence, not thread-safe | `GlobalVariableManager` (RefCounted + static `get_instance()`) + `GlobalVariableAssistant` + `GlobalVariableService` + `GlobalVariableResource` |
| Condition evaluation | Serial multi-condition checks hurting performance | `core/threading/ParallelConditionEvaluator` |
| Multi-event support | Requiring multiple Trigger nodes | MultiEventTrigger |

### v2.0 Appendix: Infrastructure Path Quick Reference

*   **`core/pooling/` (the object pool family, 5 classes)**:
    *   `FuseObjectPool` (generic pool base class), `FusePoolItem` (pooled-item protocol), `FusePoolManager` (unified multi-pool management), `FuseRecycleTimer` (periodic recycling), `InstructionInstancePool` (dedicated to reusing `RuntimeInstructionInstance`, pool size configurable 32~128).
    *   Serves RuntimeActionRunnerInstance's high-frequency firing scenarios, reducing GC pressure.
*   **`core/threading/` (the threading system, 4 classes)**:
    *   `FuseTaskManager` (`extends RefCounted`, unified async task scheduling), `ParallelConditionEvaluator` (`extends RefCounted`, parallel multi-condition evaluation, working with the `BaseCondition.is_thread_safe` flag), `FuseThreadSafe` (thread-safety mixin / utilities), `FuseThreadingConfig` (threading behavior configuration).
*   **`ScopeVariableManager`** (`core/scope_variable_manager.gd`): `extends Node`, mounted on the node tree, looks up and manages the scene's `ScopeVariableContainer`s by `scope_id`, providing the backend for `VariableContext`'s scope layer.
*   **`CompiledInstructionSequence`** (`core/execution/compiled_instruction_sequence.gd`): `extends RefCounted`, see the "compiled instruction sequence" section above.
