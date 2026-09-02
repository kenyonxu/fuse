> 🌐 [**中文版**](../../../zh_CN/dev_docs/guides/execution-context-diagnostics-guide.md) | English

# ExecutionContext and ExecutionDiagnostics Development Guide

> **Goal**: Provide developers with a complete development guide to the `ExecutionContext` execution context and its diagnostics subsystem, ExecutionDiagnostics.

**Audience**: Fuse system developers, contributors

**Last updated**: 2026-07-07

---

## 📋 Table of Contents

1. [System Overview](#system-overview)
2. [Architecture Design: Facade Pattern](#architecture-design-facade-pattern)
3. [ExecutionContext API](#executioncontext-api)
4. [ExecutionDiagnostics API](#executiondiagnostics-api)
5. [VariableContext Facade](#variable-facade-delegates-to-variablecontext)
6. [State Lifecycle](#state-lifecycle)
7. [Dependency Graph System](#dependency-graph-facade-delegates-to-diagnostics)
8. [FuseError Integration](#fuseerror-integration)
9. [Best Practices](#best-practices)
10. [Common Pitfalls](#common-pitfalls)

---

## System Overview

`ExecutionContext` is the core environment object when Fuse executes instructions, serving as the bridge through which all instructions interact with the game world. It adopts the **facade pattern**, delegating its responsibilities to two subsystems:

| Subsystem | Class | File | Responsibilities |
|--------|------|------|------|
| Variable subsystem | `VariableContext` | `core/base/variable_context.gd` | Variable read/write, loop control, indexed access, snapshots |
| Diagnostics subsystem | `ExecutionDiagnostics` | `core/base/execution_diagnostics.gd` | State machine, history records, dependency graph, statistics |

### Core Files

| File | Lines | Class |
|------|------|-----|
| `core/base/execution_context.gd` | ~750 | `ExecutionContext extends RefCounted` |
| `core/base/execution_diagnostics.gd` | ~290 | `ExecutionDiagnostics extends RefCounted` |

### Design Goals

- **Facade encapsulation**: EC provides a unified API, delegating internally to VariableContext and ExecutionDiagnostics
- **State management**: a complete state machine (IDLE → RUNNING → COMPLETED/ERROR/CANCELLED)
- **Weak references**: node references use `WeakRef` to avoid memory leaks
- **Deep copy**: `duplicate()` fully copies variable and diagnostics state (including the B11 fix)
- **Unified logging**: logs are emitted through `FuseLogger`

---

## Architecture Design: Facade Pattern

```
ExecutionContext (facade)
    │
    ├── target: Node                ← target node (WeakRef)
    ├── trigger: Node               ← trigger node (WeakRef)
    ├── owner: Node                 ← owner node
    ├── tree: SceneTree             ← scene tree
    ├── action_runner               ← ActionRunner reference
    ├── custom_data: Dictionary     ← custom data storage
    ├── execution_id: String        ← unique execution ID
    │
    ├──► _variable_context: VariableContext  ← variable subsystem (delegated)
    │       ├── local_variables: Dictionary
    │       ├── global_variables
    │       ├── set_variable / get_variable / has_variable
    │       ├── loop flags (break/continue)
    │       ├── indexed access
    │       └── snapshots
    │
    ├──► _diagnostics: ExecutionDiagnostics  ← diagnostics subsystem (delegated)
    │       ├── ExecutionState state machine
    │       ├── execution history records
    │       ├── state change listeners
    │       ├── dependency graph
    │       └── statistics
    │
    └──► _fuse_error: FuseError    ← error state
```

---

## ExecutionContext API

**File location**: `addons/fuse/core/base/execution_context.gd`

**Class definition**:
```gdscript
class_name ExecutionContext extends RefCounted
```

### Signals

```gdscript
signal cancel_requested                                ## Execution cancellation requested
signal execution_state_changed(new_state: int)         ## Execution state changed
```

### Enums

```gdscript
enum ExecutionState {
    IDLE,       # Idle
    RUNNING,    # Running
    PAUSED,     # Paused
    COMPLETED,  # Completed
    CANCELLED,  # Cancelled
    ERROR       # Error
}
```

### Core Properties

```gdscript
var target: Node = null                # Target node (primary operation target)
var trigger = null                     # Trigger node
var owner: Node = null                 # Owner node
var tree: SceneTree = null             # Scene tree
var local_variables: Dictionary = {}   # Local variables (compatibility reference into _variable_context)
var global_variables = null            # Global variable container
var custom_data: Dictionary = {}       # Custom data
var execution_start_time: float = 0.0  # Execution start time
var execution_id: String = ""          # Unique execution ID (format: "exec_<timestamp>_<random>")
var log_level: FuseLogger.LogLevel = FuseLogger.LogLevel.NONE
var action_runner = null               # ActionRunner reference
var delta_time: float = 0.0           # Delta time
```

### Constructor

```gdscript
func _init(
    target_node: Node = null,
    trigger_node: Node = null,
    global_vars: Variant = null,
    scene_tree: SceneTree = null,
    owner_node: Node = null
) -> void
```

During initialization:
1. Record the execution start time
2. Generate a unique `execution_id`
3. Set up node references (with WeakRef)
4. Create the `ExecutionDiagnostics` subsystem
5. Create the `VariableContext` subsystem
6. Initialize the `local_variables` / `global_variables` compatibility references

### Factory Method

```gdscript
static func create_with_params(
    target_node: Node = null,
    trigger_node: Node = null,
    global_vars: Variant = null,
    scene_tree: SceneTree = null
) -> ExecutionContext
```

### Scene Access

```gdscript
func get_tree() -> SceneTree                    # Get the scene tree
func get_node(path: NodePath) -> Node           # Multi-strategy node lookup
```

`get_node()` lookup order:
1. From the `trigger` node using `FuseNodeUtils.find_node_at_runtime()`
2. From the `target` node
3. From `current_scene`
4. From `tree.root` by absolute path

### Variable Facade (Delegates to VariableContext)

```gdscript
func add_variable(name: String, variable: BaseVariable) -> bool
func set_variable(name: String, value: Variant, scope: String = "local") -> bool
func get_variable(name: String, default: Variant = null, scope: String = "local") -> Variant
func get_variable_object(name: String) -> BaseVariable
func has_variable(name: String) -> bool
func get_global_variable_assistant() -> GlobalVariableAssistant
func set_global_variable_assistant(assistant: GlobalVariableAssistant) -> void
```

### Loop Control Facade (Delegates to VariableContext)

```gdscript
func set_break_loop() -> void
func set_continue_loop() -> void
func should_break_loop() -> bool
func should_continue_loop() -> bool
func clear_loop_flags() -> void
func push_loop_flags() -> void
func pop_loop_flags() -> void
```

### Indexed Access Facade (Delegates to VariableContext)

```gdscript
func precompile_variable_access(variable_names: Array[String]) -> void
func set_variable_by_index(index: int, value: Variant) -> void
func get_variable_by_index(index: int) -> Variant
func get_variable_index(name: String) -> int
func is_indexed_access_enabled() -> bool
func get_indexed_access_stats() -> Dictionary
```

### Variable Snapshot Facade (Delegates to VariableContext)

```gdscript
func get_all_local_variables_snapshot() -> Dictionary
func get_all_scope_variables_snapshot() -> Dictionary
func get_all_global_variables_snapshot() -> Dictionary
```

### Logging Methods

```gdscript
func set_log_level(level: FuseLogger.LogLevel) -> void
func get_log_level() -> FuseLogger.LogLevel
func print_message(message: String) -> void      # Calls FuseLogger.log_info
func print_warning(message: String) -> void      # Calls FuseLogger.log_warning
func print_error(message: String) -> void        # Calls FuseLogger.log_error
```

### Custom Data

```gdscript
func set_custom_data(key: String, value: Variant) -> void
func get_custom_data(key: String, default: Variant = null) -> Variant
```

### ActionRunner Management

```gdscript
func set_action_runner(runner) -> void
func get_action_runner()
func has_action_runner() -> bool
```

### State Management Facade (Delegates to Diagnostics)

```gdscript
func get_execution_state() -> ExecutionState
func set_execution_state(state: ExecutionState) -> void
func reset_execution_state() -> void
func is_running() -> bool
func is_completed() -> bool
func has_error() -> bool
func is_cancelled() -> bool
func request_cancel() -> void
func get_execution_progress() -> float
func set_execution_progress(progress: float) -> void
func get_error_message() -> String
func set_error_message(message: String, error_type: FuseError.ErrorType = ..., context: Dictionary = {}) -> void
```

### History/Listener Facade (Delegates to Diagnostics)

```gdscript
func get_execution_history(limit: int = 0) -> Array[Dictionary]
func clear_execution_history() -> void
func add_state_change_listener(listener: Callable) -> void
func remove_state_change_listener(listener: Callable) -> void
func get_state_statistics() -> Dictionary
func get_recent_state_changes(count: int = 10) -> Array[Dictionary]
```

### Dependency Graph Facade (Delegates to Diagnostics)

```gdscript
func get_dependency_graph() -> Dictionary
func check_dependencies(dependencies: Array[String]) -> Dictionary
func get_dependency_status() -> Dictionary
func check_dependencies_batch(dependencies_list: Array) -> Array
func get_dependency_visualization_data() -> Dictionary
```

### Lifecycle

```gdscript
func cleanup() -> void          # Release all references
func duplicate(p_deep: bool) -> ExecutionContext  # Deep copy
func get_info() -> Dictionary   # Get context info
func get_execution_time() -> float  # Get the execution time (milliseconds)
```

### FuseError Integration

```gdscript
func get_fuse_error() -> FuseError
func has_fuse_error() -> bool
func had_error() -> bool
```

---

## ExecutionDiagnostics API

**File location**: `addons/fuse/core/base/execution_diagnostics.gd`

**Class definition**:
```gdscript
class_name ExecutionDiagnostics extends RefCounted
```

### Constructor

```gdscript
func _init(owner: ExecutionContext) -> void
```

### State Management

```gdscript
func get_execution_state() -> int
func set_execution_state(state: int) -> void       # Auto emit + record history
func reset_execution_state() -> void               # Reset to IDLE
func is_running() -> bool
func is_completed() -> bool
func has_error() -> bool
func is_cancelled() -> bool
func request_cancel() -> void                      # Set CANCELLED + emit cancel_requested
```

### Progress

```gdscript
func get_execution_progress() -> float             # Returns 0.0 ~ 1.0
func set_execution_progress(progress: float) -> void  # clamp + record history when the change > 0.01
```

### Errors

```gdscript
func get_error_message() -> String
func set_error_message(message: String, error_type: int = 0, context: Dictionary = {}) -> void  # Automatically sets the ERROR state
```

### History Records

```gdscript
func _record_execution_history(state: int, message: String = "", data: Dictionary = {}) -> void
func get_execution_history(limit: int = 0) -> Array[Dictionary]
func clear_execution_history() -> void
```

History entry format:
```gdscript
{
    "timestamp": float,           # Timestamp (seconds)
    "state": int,                 # State value
    "state_name": String,         # State name
    "message": String,            # Description message
    "progress": float,            # Current progress
    "execution_time": float,      # Execution time
    "data": Dictionary            # Additional data
}
```

### State Change Listeners

```gdscript
func add_state_change_listener(listener: Callable) -> void
func remove_state_change_listener(listener: Callable) -> void
```

Listener signature: `callable(old_state: int, new_state: int, context: ExecutionContext)`

### State Statistics

```gdscript
func get_state_statistics() -> Dictionary     # State counts + time spent per state
func get_recent_state_changes(count: int = 10) -> Array[Dictionary]
```

### Dependency Graph

```gdscript
func get_dependency_graph() -> Dictionary
func _collect_all_variables() -> Dictionary
func check_dependencies(dependencies: Array[String]) -> Dictionary
func get_dependency_status() -> Dictionary
func check_dependencies_batch(dependencies_list: Array) -> Array
func get_dependency_visualization_data() -> Dictionary
```

### Duplication

```gdscript
func duplicate(p_deep: bool = true) -> ExecutionDiagnostics
```

---

## State Lifecycle

```
      ┌──────────┐
      │   IDLE   │
      └────┬─────┘
           │ run/execute
           ▼
      ┌──────────┐
      │ RUNNING  │ ◄──── PAUSED ────►  (pause/resume)
      └────┬─────┘
           │
    ┌──────┼──────────┐
    │      │          │
    ▼      ▼          ▼
┌──────┐ ┌────────┐ ┌──────────┐
│DONE  │ │ ERROR  │ │CANCELLED │
└──────┘ └────────┘ └──────────┘
```

- `set_execution_state()` triggers the `execution_state_changed` signal
- `set_error_message()` automatically sets the `ERROR` state
- `request_cancel()` automatically sets the `CANCELLED` state

---

## FuseError Integration

ExecutionContext creates FuseError instances through `_create_fuse_error()`:

```gdscript
func _create_fuse_error(message: String, error_type: FuseError.ErrorType, context: Dictionary):
    var error_context = context.duplicate()
    error_context["execution_id"] = execution_id
    _fuse_error = FuseError.create_with_context(error_type, "ExecutionContext", message, error_context)
```

---

## Best Practices

### 1. Creating an ExecutionContext

```gdscript
# Use the factory method
var context = ExecutionContext.create_with_params(
    target_node,
    trigger_node,
    global_variables,
    get_tree()
)
```

### 2. Using It in Instructions

```gdscript
func execute(context: ExecutionContext):
    _start_execution(context)
    
    # Get a node
    var node = context.get_node(target_node)
    
    # Read/write variables
    context.set_variable("score", 100)
    var score = context.get_variable("score", 0)
    
    # Logging
    context.print_message("指令执行中...")
    
    # State check
    if context.is_cancelled():
        finished.emit()
        return
    
    _on_execution_completed()
```

### 3. Deep-Copying the Context

```gdscript
var copy = context.duplicate(true)
# Note: fixed by B11; duplicate fully copies _diagnostics
```

### 4. Cleaning Up the Context

Call `cleanup()` after execution completes to release references:

```gdscript
context.cleanup()
```

### 5. Debugging with the Dependency Graph

```gdscript
var graph = context.get_dependency_visualization_data()
# Contains the node list, edge list, and execution context info
```

---

## Common Pitfalls

### Pitfall 1: WeakRef Makes target/trigger Unexpectedly null

ExecutionContext stores the target and trigger references using `WeakRef`. If a node is freed, the `target` property automatically becomes `null`. Always check before use:

```gdscript
if not context.target:
    _log_error("目标节点已不存在")
    return
```

### Pitfall 2: duplicate Skips Copying Diagnostics Data (Historical Bug B11)

The old `duplicate()` did not copy the `_diagnostics` subsystem, so the copied context lost its execution history/state. **The current version has fixed this issue**.

### Pitfall 3: Wrong Variable Scope Argument

The scope argument of `set_variable(name, value, scope)` is a string, not the `VariableScope` enum:

```gdscript
# ✅ Correct
context.set_variable("hp", 100, "local")
context.set_variable("hp", 100, "scope")
context.set_variable("hp", 100, "global")

# ❌ Wrong — omitting the scope argument defaults to "local"
context.set_variable("hp", 100)
```

### Pitfall 4: Accessing Node References in _init

ExecutionContext is `RefCounted`, not a `Node`; `get_tree()` is unavailable inside its `_init`. In the constructor, only assign the passed-in values; do not call methods that depend on the SceneTree.

### Pitfall 5: Calling cleanup Multiple Times

`cleanup()` is idempotent; calling it multiple times is safe. However, the context should not be used again afterwards.

---

## Reference Documents

- [FuseLogger Logging System Guide](fuse-logger-guide.md)
- [ActionRunner Development Guide](action-runner-guide.md)
- [RuntimeBridge Development Guide](runtime-bridge-guide.md)
- [FuseEventBus Development Guide](event-bus-guide.md)
- [Instruction Creation Guide](instruction-creation-guide.md)

---

**Document maintainer**: Fuse development team | **Last updated**: 2026-07-07 | **Godot version**: 4.7
