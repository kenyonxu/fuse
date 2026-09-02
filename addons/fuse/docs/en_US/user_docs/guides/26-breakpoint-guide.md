> 🌐 [**中文版**](../../../zh_CN/user_docs/guides/26-breakpoint-guide.md) | English

# Breakpoint Instruction Usage Guide

BreakpointInstruction is Fuse's debugging tool instruction. Insert it into an instruction list; when execution reaches that position it outputs a variable snapshot to the Godot output window, and can optionally pause execution for state inspection.

**File:** [breakpoint_instruction.gd](../../../../instructions/debug/breakpoint_instruction.gd)
**Category:** Debug
**Icon:** Debug

## Quick Start

In the ActionRunner's instruction list, locate the target instruction and insert a BreakpointInstruction before it:

1. Click the add button above the instruction list
2. Search for "breakpoint" or "Breakpoint" in the instruction selector
3. After inserting, run the scene; when the breakpoint hits, the output window shows the variable info

```
Output window example:

[BREAKPOINT] "检查血量" — hit #1
  Scope variables: {"health": 45, "max_health": 100}
  Global variables: {"player_score": 1200}
```

## Properties

### Condition Group

| Property | Type | Default | Description |
|------|------|--------|------|
| use_expression_condition | bool | false | Enable the conditional breakpoint |
| condition | String | "" | Condition expression (shown after the conditional breakpoint is enabled) |

### Basic Properties

| Property | Type | Default | Description |
|------|------|--------|------|
| label | String | "" | Custom label used to identify the breakpoint in the output |
| ignore_count | int | 0 | Ignore the first N hits |
| log_variables | bool | true | Output variable info to the output window on hit |
| pause_execution | bool | true | Pause execution on hit (editor mode only) |

### Scope Source Config Group

| Property | Type | Default | Description |
|------|------|--------|------|
| scope_source | enum | Nearest | Source of the scope variables |
| custom_scope_id | String | "" | Custom scope ID (shown when scope_source = Custom ID) |
| target_node_path | NodePath | "" | Target node path (shown when scope_source = Target Node) |

scope_source controls two things at once:
- which scope container the scope variables are read from when variables are output
- the source of variables referenced via `{scope:xxx}` in the condition expression

## Use Cases

### Scenario 1: Inspect Variable State

The simplest usage — look at variable values at a given moment. Insert a breakpoint, set a label, run the scene:

```
label: "受伤前"
log_variables: true
pause_execution: false
```

Output:
```
[BREAKPOINT] "受伤前" — hit #1
  Local variables: {"damage": 25, "is_critical": true}
  Scope variables: {"health": 100, "max_health": 100}
```

### Scenario 2: Conditional Breakpoint

Only trigger the breakpoint under specific conditions, to avoid drowning the output in irrelevant hits.

Enable `use_expression_condition` and write an expression in `condition`:

```
use_expression_condition: true
condition: {scope:health} < 30
```

Output (only triggers when HP is below 30):
```
[BREAKPOINT] "低血量检查" — hit #1
  Condition: {scope:health} < 30 → true
  Scope variables: {"health": 28, "max_health": 100}
```

Condition expressions support the same variable reference syntax as MathExpression:

```
{local:variable_name}     - local variables
{scope:variable_name}     - scope variables
{global:variable_name}    - global variables
```

If condition evaluation fails, the breakpoint degrades to an unconditional one; it outputs a warning but does not interrupt execution.

### Scenario 3: Skip the First N Hits

When inserting a breakpoint inside a loop, use `ignore_count` to skip the first few iterations:

```
ignore_count: 3
```

Hits 1-3 are skipped; from the 4th hit on, variable info is output.

The hit counter resets automatically at the start of each ActionRunner execution, so no manual management is needed.

### Scenario 4: Pause Execution

To pause at a critical position, inspect the variable state in the output window and press Enter to continue:

```
pause_execution: true
```

While paused, a prompt panel appears in the center of the screen, and the variable info is output to the Godot output window.

Press **Enter** to resume. After resuming, subsequent instructions execute normally.

> **Note:** the pause feature only works in editor mode. In exported builds it automatically degrades to log-only output.

### Scenario 5: Specify the Scope Source

By default, variables are read from the nearest scope container. If your project has multiple scope containers, use `scope_source` to specify which one to read:

```
scope_source: Trigger Scope
```

| scope_source value | Effect |
|-----------------|------|
| Nearest | The nearest scope container (default) |
| Custom ID | The container matching the specified `custom_scope_id` |
| Trigger Scope | The scope container on the Trigger node |
| Target Node | The scope container on the node pointed to by `target_node_path` |

## Execution Flow

```
execute()
  ① Detect a new execution cycle → reset the hit counter
  ② _hit_count += 1
  ③ ignore_count check → skip if not yet reached
  ④ use_expression_condition and condition is non-empty → evaluate the expression
     → false → skip the breakpoint
     → evaluation failed → degrade to unconditional, continue
  ⑤ log_variables == true → output the variable snapshot to the output window
  ⑥ pause_execution == true and editor mode → show the prompt panel → wait for the Enter key
     → exported build → degrade to log-only output + warning
  ⑦ Done
```

## Output Format

On hit, output to the Godot output window (with color formatting):

```
[BREAKPOINT] "检查血量" — hit #2
  Condition: {scope:health} < 50 → true
  Local variables: {"counter": 5, "temp": "test"}
  Scope variables: {"health": 45, "max_health": 100}
  Global variables: {"player_score": 1200}
```

- Only non-empty variable categories are shown
- When the label is empty, "Unnamed" is displayed

## Differences from Other Debug Instructions

| Instruction | Purpose | Pause | Condition |
|------|------|------|------|
| BreakpointInstruction | Inspect variable snapshots | Resume with the Enter key | Expression condition |
| Print | Output a custom message | Not supported | Not supported |
| PrintVariable | Output a single variable | Not supported | Not supported |

---

**Doc maintainer**: Fuse dev team
**Last updated**: 2026-03-19
**Version**: 1.0.0
