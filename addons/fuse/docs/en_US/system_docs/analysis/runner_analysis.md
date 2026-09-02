> 🌐 [**中文版**](../../../zh_CN/system_docs/analysis/runner_analysis.md) | English

# Runner Analysis


> **Analyzed as of**: 2026-07-07 (each article verified against code during the same-day full documentation audit; implementation evolution after this point defers to the source code; for recently verified mechanical conclusions see the threading / runtime_instance / preset_nested articles)
## Overview

`Runner` is a Node wrapper component in the Fuse system that wraps the ActionRunner resource as a scene node, providing signal binding, runtime instance management, and awaitable execution.

- **File**: `addons/fuse/core/runner.gd` (430 lines)
- **Class name**: `Runner`
- **Inheritance**: `Node`
- **Icon**: `res://addons/fuse/icons/builtin/ViewportSpeed.png`

## Core Responsibilities

1. Wraps the `ActionRunner` resource as a scene node
2. Automatically creates and manages the `RuntimeActionRunnerInstance`
3. Supports signal binding (listening to any signal of any node)
4. Provides an awaitable execution API (`wait_completed()`)
5. Provides execution status queries and cancellation

## Relationship with Trigger

| Feature | Trigger | Runner |
|------|--------|-------|
| Base class | Node | Node |
| Event-driven | Automatically listens to Events (multiple input types) | Manually triggered via signal binding |
| Multiple events | MultiEventTrigger supports multiple bindings | A single ActionRunner |
| Runtime instance | Automatically managed | Automatically managed |
| awaitable | Not supported | Supports `wait_completed()` |
| Typical use | Key presses, physics collisions, etc. | Signal listening, programmatic invocation |

## Core Properties

### Exported Properties

| Property | Type | Description |
|------|------|------|
| `action_runner` | `ActionRunner` | The instruction-sequence resource to execute |
| `target_node` | `NodePath` | Path to the node whose signals are bound |
| `signal_name` | `String` | The name of the signal to bind |
| `log_level` | `FuseLogger.LogLevel` | Log level (default NONE) |

> All exported properties are declared with `@export_storage` (:11–33): the values persist with the scene/resource but are **not** shown in the Inspector by default — the Inspector entries are generated dynamically by `_get_property_list()` (see "Editor Integration" below), which can offer an enum dropdown for `signal_name` and group the properties into sections.

### Internal State

| Field | Type | Description |
|------|------|------|
| `_runtime_instance` | `RuntimeActionRunnerInstance` | The runtime ActionRunner instance |
| `_bound_node` | `Node` | Reference to the signal-bound target node |
| `_signal_connected` | `bool` | Whether the external signal is connected |
| `_runtime_signals_connected` | `bool` | Whether the runtime instance signals are connected |
| `current_execution_context` | `ExecutionContext` | The current execution context (written by `run()` at runtime, :36; variable watchers/debug tools read this field to observe the latest context) |

## Lifecycle

### Initialization (_ready)

```
1. Create the RuntimeActionRunnerInstance
2. Connect the RuntimeActionRunnerInstance signals
3. Set up the signal binding automatically (_setup_signal_binding)
```

### Cleanup (_exit_tree)

```
1. Disconnect the signal binding
2. Disconnect the runtime signals
3. Clean up the runtime instance
```

### On Property Changes

- `action_runner` changed → `_clear_runtime_instance()` → recreate
- `target_node` / `signal_name` changed → `_disconnect_signal_binding()` → rebind

## Signals

| Signal | Parameters | Description |
|------|------|------|
| `execution_completed` | `total_time: float` | Execution completed (with elapsed time) |
| `execution_failed` | `error_message: String` | Execution failed |
| `execution_canceled` | `reason: String` | Execution was canceled |
| `_internal_completed` | none | Internal completion signal (used by wait_completed) |

## Public API

### Execution Control

| Method | Description |
|------|------|
| `run(context_node)` | Executes the ActionRunner (optional context node) |
| `cancel(reason)` | Cancels the current execution |
| `stop()` | Stops the current execution (shorthand for cancel) |
| `is_running()` | Checks whether execution is in progress |
| `is_canceling()` | Checks whether cancellation is in progress |
| `reset()` | Resets state (cancels execution, disconnects signals, cleans up instances) |

### Queries

| Method | Return type | Description |
|------|---------|------|
| `get_execution_status()` | `Dictionary` | Gets the detailed execution status |
| `wait_completed()` | `void` | Waits for execution to complete (awaitable) |

### Execution Flow

```
run() creates ExecutionContext → RuntimeActionRunnerInstance.run()
  → execution_completed → execution_completed.emit()
  → execution_failed → execution_failed.emit()
  → execution_canceled → execution_canceled.emit()
```

## The Signal Binding Mechanism

Runner can automatically listen to any signal of any node:

```
1. Find the target node via target_node (NodePath)
2. Check that the signal exists via SignalManager.has_signal_named()
3. Connect the signal to _on_bound_signal_triggered()
4. When the signal fires, call run() automatically
```

> Signal discovery and validation are uniformly delegated to `SignalManager`: `has_signal_named(node, signal_name)` (:277) validates before runtime binding; on the editor side, `_editor_refresh_signals` calls `SignalManager.get_node_signals(node)` (:196) to enumerate all of the target node's signals for the dropdown.

### Typical Usage

```
# Add a Runner node in the scene
# set target_node to some button node
# set signal_name to "pressed"
# configure the instruction sequence on action_runner

→ button clicked → signal fires → Runner.run() → instructions execute
```

## Editor Integration

`Runner` is annotated `@tool` (:2), providing a dynamic Inspector in the editor:

- **`_get_property_list()` (:92–157)** dynamically generates the property list, chunked into groups (`action_runner` / `signal_binding` / `configuration`); the `signal_name` field switches its hint based on the target node's available signals:
  - Has signals → `PROPERTY_HINT_ENUM` dropdown (`hint_string = ",".join(signal_names)`, :128–134)
  - No signals → plain `TYPE_STRING` text input (:136–140)
- **Signal list refresh** is coordinated by three internal fields (:71–73):
  - `_editor_available_signals: Array` — caches the result of `SignalManager.get_node_signals(target)`
  - `_editor_signals_loaded: bool` — marks whether the list has been loaded
  - `_editor_is_refreshing: bool` — re-entrancy guard
- **`_editor_refresh_signals()` (:183–200)** calls `SignalManager.get_node_signals(target)` (:196) to fill the cache, then `notify_property_list_changed()` tells the Inspector to redraw, and finally clears `_editor_is_refreshing`.
- **`target_node` changes trigger a refresh**: the setter (:22–24), under `Engine.is_editor_hint()`, resets `_editor_is_refreshing` and defers with `call_deferred("_editor_refresh_signals")`, avoiding node resolution during property setting.
- **`_get_target_node_in_editor()` (:203–207)** resolves relative paths via `get_node_or_null(target_node)` (Runner, being a scene node, resolves its own paths directly).

## Internal Methods

| Method | Description |
|------|------|
| `_create_execution_context(target)` (:391–394) | Creates the `ExecutionContext`: `ExecutionContext.new(target, self)`; both `target` and `trigger` point to the Runner itself; also sets `log_level` |
| `_on_bound_signal_triggered(_reason, _context)` (:397–398) | The unified callback signature for bound signals `(_reason: String = "", _context: Dictionary = {})`; **ignores the arguments** and calls `run()` directly |

## Relationship with the Event System

Runner is not part of the event system; it is a Node wrapper around ActionRunner. It:

- does not inherit BaseTrigger (no Event concept)
- does not use RuntimeEventInstance (only RuntimeActionRunnerInstance)
- suits programmatic invocation and simple signal-driven scenarios
- for event-driven needs (input, physics, lifecycle), a Trigger should be used

## Design Decisions

- **Simplified API**: exposes only the four core operations run / cancel / stop / reset
- **RuntimeActionRunnerInstance encapsulation**: the outside never touches the runtime instance directly
- **Flexible signal binding**: can listen to any signal of any Node
- **Automatic cleanup**: runtime instances are rebuilt automatically on property changes, preventing dangling references
