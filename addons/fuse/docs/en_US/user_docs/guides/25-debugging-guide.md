> 🌐 [**中文版**](../../../zh_CN/user_docs/guides/25-debugging-guide.md) | English

# Debugging System User Guide

Fuse provides a set of debugging tools to help you troubleshoot instruction execution issues during development and at runtime. The debugging system includes 3 instructions and 2 editor tools, covering everything from simple log output to full breakpoint debugging.

**Category:** Debug
**Related files:** `addons/fuse/instructions/debug/`, `addons/fuse/editor/debugging/`

---

## Debug Instructions Overview

| Instruction | Purpose | Variable snapshot | Pauses execution | Conditional trigger |
|------|------|:---:|:---:|:---:|
| Print | Outputs a custom message | No | No | No |
| PrintVariableValue | Outputs a single variable value | No | No | No |
| BreakpointInstruction | Breakpoint debugging | Yes | Yes (editor) | Yes |

---

## Print -- Print Message

The most basic debug instruction; it outputs a custom message to the Godot output window.

**File:** [print.gd](../../../../instructions/debug/print.gd)
**Icon:** Debug

### Properties

| Property | Type | Default | Description |
|------|------|--------|------|
| message | String | "Hello, World!" | The message text to print |

### Output Format

Godot output window:
```
[PrintInstruction] your message content
```

It also emits a log message through the ExecutionContext.

### Use Cases

**Mark the execution flow:**
Insert Print into the instruction sequence to confirm how far execution has reached:
```
message: "开始处理受伤逻辑"
```

**Output intermediate results:**
```
message: "计算完成，伤害值为 25"
```

### Validation Rules

- message must not be an empty string

### Notes

- Print is a synchronous instruction and completes immediately after execution
- The message is output to both the Godot console and the ExecutionContext log
- Suited for quick debugging scenarios that need no condition checks or variable inspection

---

## PrintVariableValue -- Print Variable Value

Outputs the name, scope, and current value of the specified variable.

**File:** [print_variable_value.gd](../../../../instructions/debug/print_variable_value.gd)
**Icon:** FileList

### Properties

| Property | Type | Default | Description |
|------|------|--------|------|
| variable_name | String | "" | Variable name |
| variable_scope | enum | Local | Variable scope (Local/Scope/Global) |
| scope_source | enum | Nearest | Scope source (only for the Scope scope) |
| custom_scope_id | String | "" | Custom scope ID |
| target_node_path | NodePath | "" | Target node path |

### Scope Description

| variable_scope | Description |
|----------------|------|
| Local | Read from the local variables on the ExecutionContext |
| Scope | Read from a scope container (a source must be specified) |
| Global | Read from the global variables |

When using the Scope scope, the source can be specified via scope_source:

| scope_source | Effect |
|-------------|------|
| Nearest | The nearest scope container (default) |
| Custom ID | The container matching the specified custom_scope_id |
| Trigger Scope | The scope container on the Trigger node |
| Target Node | The scope container on the node pointed to by target_node_path |

### Output Format

Godot output window:
```
[LOCAL] variable name: "value" (type: String)
[SCOPE] variable name: 42 (type: int)
[GLOBAL] variable name: Vector2(1.50, 2.30)
```

### Supported Type Formatting

| Type | Output format |
|------|---------|
| bool | `true` / `false` |
| int | Prints the number directly |
| float | Prints the number directly |
| String | `"value"` (quoted) |
| Vector2 | `Vector2(x.xx, y.xx)` |
| Vector3 | `Vector3(x.xx, y.xx, z.xx)` |
| Color | `Color(r.xx, g.xx, b.xx, a.xx)` |
| BaseVariable | Prints its internal value |
| null | `null` |

### Use Cases

**Inspect a local variable:**
```
variable_name: "health"
variable_scope: Local
```

**Inspect a scope variable:**
```
variable_name: "player_score"
variable_scope: Scope
scope_source: Trigger Scope
```

**Inspect a global variable:**
```
variable_name: "game_time"
variable_scope: Global
```

### Validation Rules

- variable_name must not be empty
- Using the Scope scope requires a ScopeVariableManager instance

---

## BreakpointInstruction -- Breakpoint Debugging

The most full-featured debug instruction. On hit it outputs a snapshot of all variables, and supports conditional triggering and execution pausing.

**File:** [breakpoint_instruction.gd](../../../../instructions/debug/breakpoint_instruction.gd)
**Icon:** Debug

### Core Properties

| Property | Type | Default | Description |
|------|------|--------|------|
| label | String | "" | Custom label identifying the breakpoint |
| ignore_count | int | 0 | Ignore the first N hits |
| log_variables | bool | true | Output variable info on hit |
| pause_execution | bool | true | Pause on hit (editor only) |
| use_expression_condition | bool | false | Enable the conditional breakpoint |
| condition | String | "" | Condition expression |
| scope_source | enum | Nearest | Scope variable source |

### Feature Overview

- **Variable snapshot**: automatically outputs local, scope, and global variables
- **Conditional breakpoint**: supports expression conditions; only triggers when the condition is met
- **Ignore count**: skips the first N hits, useful for loop debugging
- **Pause execution**: in editor mode the game can be paused; press Enter to resume

### Detailed Usage

The breakpoint instruction has a complete usage guide, see:

**[Breakpoint Instruction Usage Guide](26-breakpoint-guide.md)**

That guide includes:
- Quick start
- Detailed property descriptions
- 5 usage scenarios (inspecting variables, conditional breakpoints, skipping hits, pausing execution, specifying the scope source)
- Execution flow
- Output format description

---

## Editor Debugging Tools

### DebugVisualizer -- Debug Visualization Panel

Provides a graphical interface for viewing execution history, performance metrics, and debug info.

**File:** [debug_visualizer.gd](../../../../editor/debugging/debug_visualizer.gd)

#### Features

- **Execution history tree**: shows instruction execution records as a tree, including each step's type, result, and elapsed time
- **Color coding**: green for success, red for errors, yellow for performance issues, light blue for start
- **Detail panel**: click a step in the tree to view details (execution result, performance data, variable state)
- **Auto refresh**: can enable auto refresh at 1-second intervals
- **Export**: export the execution history to a JSON file

#### Layout

```
+------------------------------------------+
| [Refresh] [Clear] [Export] [x Auto refresh] |
+---------------------+--------------------+
| Execution history (tree) | Detail panel      |
|  Execution #1 (0.35s)    | Basic info        |
|    Start: Print          | Execution result  |
|    Done: Print 0.01s     | Performance data  |
|    Start: MoveNode       | Variable state    |
|    Done: MoveNode 0.3s   |                   |
|  Execution #2 (0.12s)    |                   |
|    ...                   |                   |
+---------------------+--------------------+
| Performance chart (placeholder)          |
+------------------------------------------+
```

#### How to Use

1. Run the scene and trigger some instruction executions
2. Open the DebugVisualizer panel
3. Click an execution record or step in the tree on the left
4. The right side shows the detailed info
5. Click "Refresh" to update manually, or check "Auto refresh"
6. Click "Export" to save as a JSON file

---

### ExecutionTracker -- Execution Tracker

Records detailed instruction execution history in the background and feeds the data displayed by DebugVisualizer.

**File:** [execution_tracker.gd](../../../../editor/debugging/execution_tracker.gd)

#### Core Functions

| Function | Description |
|------|------|
| record_instruction_start() | Records the start of an instruction execution |
| record_instruction_complete() | Records the completion of an instruction execution |
| record_custom_event() | Records a custom event |
| record_error() | Records an execution error |
| record_performance_bottleneck() | Records a performance bottleneck |
| start_tracking() / stop_tracking() | Starts/stops a tracking session |
| get_execution_history() | Gets the execution history |
| get_execution_stats() | Gets execution statistics |
| export_execution_history() | Exports to JSON |

#### Tracking Configuration

| Setting | Default | Description |
|--------|--------|------|
| max_history_size | 100 | Maximum number of history records |
| track_performance_metrics | true | Whether to record performance metrics |
| track_memory_usage | false | Whether to record memory usage |
| track_variable_changes | true | Whether to record variable changes |

#### Execution Statistics

Call `get_execution_stats()` to get:

```json
{
  "total_executions": 15,
  "total_time": 2340.0,
  "average_time": 156.0,
  "average_instructions": 8.5,
  "total_errors": 1,
  "performance_issues": 2,
  "instruction_counts": [8, 9, 10],
  "error_counts": [0, 1, 0]
}
```

#### Export Format

The execution history is exported to a JSON file, containing:
- export_time: the export time
- execution_history: the full execution records
- stats: the execution statistics

### Variable Watcher

Debugging often starts with variables rather than instructions: when logic does not behave as expected, open the Variable Watcher first to watch variable values change in real time — it supports tab-per-scope viewing, double-click editing, history line-chart recording, and snapshot export, which is much faster than guessing blindly or adding Print instructions. For full usage see the [Variable Watcher Guide](56-variable-watcher-guide.md) (Chinese).

---

## Debugging Workflows

### Workflow 1: Quick Troubleshooting

1. Insert a **Print** instruction at suspicious positions to mark the execution flow
2. Run the scene and watch the output window to confirm the execution order
3. Use **PrintVariableValue** to check the values of key variables
4. Remove the debug instructions once the problem is located

### Workflow 2: Breakpoint Debugging

1. Insert a **BreakpointInstruction** at key positions
2. Set a label for easy identification (e.g. "pre-damage check")
3. Run the scene and watch the variable snapshots in the output window
4. If pausing is needed, enable `pause_execution`
5. Analyze the variable state in the output window, then press Enter to continue
6. For detailed usage see the [Breakpoint Guide](26-breakpoint-guide.md)

### Workflow 3: Performance Analysis

1. Make sure ExecutionTracker is tracking (DebugVisualizer manages this automatically)
2. Run the scene and execute the instruction sequence to analyze
3. Open DebugVisualizer and view the execution history
4. Watch for execution records in red (errors) and yellow (performance issues)
5. Click a specific step to view detailed performance data
6. Use "Export" to save the full record for offline analysis

### Workflow 4: Conditional Breakpoint Debugging

1. Insert a **BreakpointInstruction**
2. Enable `use_expression_condition`
3. Write a condition expression, e.g. `{scope:health} < 30`
4. Run the scene; the breakpoint only triggers when HP is below 30
5. Check the variable snapshot and analyze the cause of the problem

### Workflow 5: Topology Static Analysis Debugging

The Fuse Topology main screen (the "Fuse" tab at the top of the editor) integrates static analysis, so issues can be spotted at edit time **without running the scene**. See [Editor Panels Overview](00-editor-panels-overview.md) for details.

#### Static Analysis Coverage

| Check | Description |
|--------|------|
| **Undeclared local variables** | local variables read or written in instruction chains but never declared via `SetVariable` (including declarations inside nested condition branches) |
| **Event-provided variable allowlist** | some events (e.g. OnInput) inject variables into the ExecutionContext; variables on the allowlist do not count as undeclared |
| **NodePath resolution failures** | a NodePath referenced by an instruction cannot resolve to an actual node in the current scene |
| **Signal reference checks** | whether the signal name referenced by an EmitSignal instruction exists on the target node |
| **Cross-Trigger variable relations** | write-read arrows / race warnings (multiple Triggers writing the same variable) / orphan writes and reads |

#### Issue Filtering

The OptionButton in the Topology banner offers three filter levels:

- **All** — show all nodes (default)
- **Errors only** — show only error nodes, to quickly locate must-fix issues
- **None** — turn off annotations for a pure topology view

#### Auto Refresh

Topology auto-refreshes at the following moments (0.5s debounce):

- **Scene switch** — switching to a new scene rebuilds the topology automatically
- **Scene save (Ctrl+S)** — saving after edits syncs the issue annotations automatically

It stays up to date without manually clicking the "Refresh" button; the selected entry is restored after a refresh.

#### Double-Click to Jump to the Inspector

- **Double-click a Trigger** → the Inspector jumps to the corresponding node in the scene (event / instruction configs editable directly)
- **Double-click an instruction** → the Inspector shows that instruction Resource (parameters editable directly)

#### Debugging Workflow: Topology → Inspector → Save

```
1. Open the Fuse Topology main screen → view the global topology + issue annotations
2. Switch issue filtering to "Errors only" → focus on must-fix issues
3. Double-click a problem node → the Inspector jumps to it
4. Edit instruction parameters / fix the NodePath / add the missing SetVariable declaration in the Inspector
5. Ctrl+S to save the scene → Topology auto-refreshes, issue annotations update
6. Repeat until no error remains → run the scene to verify
```

#### Export Issue Report

The "Export issue report" button in the banner → writes a summary of all scene issues to `user://fuse_problems_report_*.txt`, useful for archiving an issue list when Topology cannot be viewed directly (e.g. CI / offline review).

---

## Debug Instruction Comparison

| Feature | Print | PrintVariableValue | BreakpointInstruction |
|------|:-----:|:------------------:|:--------------------:|
| Custom message | Supported | Not supported (auto-formatted) | Via label |
| Variable value output | Not supported | Single variable | Snapshot of all variables |
| Conditional trigger | Not supported | Not supported | Expression condition |
| Pauses execution | Not supported | Not supported | Supported (editor) |
| Ignore count | Not supported | Not supported | Supported |
| Editor impact | None | None | Can pause the game |
| Exported builds | Works normally | Works normally | Degrades to log-only |
| Performance cost | Very low | Low | Medium |

---

## Best Practices

1. **Use breakpoints liberally during development, clean up before release**: BreakpointInstruction degrades to log output in exported builds, but it is recommended to remove all debug instructions before release
2. **Use labels to identify breakpoints**: give each BreakpointInstruction a meaningful label so it can be identified in the output window
3. **Use conditional breakpoints to reduce noise**: when debugging inside loops, use conditional breakpoints so they only trigger under specific conditions
4. **Export the execution history regularly**: DebugVisualizer's export feature can save JSON records, handy for tracking intermittent issues
5. **Combine them**: Print to mark the flow + PrintVariableValue to inspect variables + BreakpointInstruction for in-depth analysis

---

**Doc maintainer**: Fuse dev team
**Last updated**: 2026-03-19
**Version**: 1.0.0
