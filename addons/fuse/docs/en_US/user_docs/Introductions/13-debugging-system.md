> 🌐 [**中文版**](../../../zh_CN/user_docs/Introductions/13-调试体系.md) | English

# Visual Logic Can Be Stepped Through Too: Breakpoints, Execution Tracing, and Live Variable Watching in Fuse

The previous chapter turned node methods into formal instructions with one click, and the instruction library keeps getting thicker. But more instructions bring problems along—`SetVariable` is clearly wired up, yet the variable still holds its old value at runtime; `ForLoop` suddenly takes the wrong branch on its third iteration; an event trigger chain spans three Triggers—which one actually executes first? Traditional visual plugins usually answer "add a print statement and guess". After this chapter you'll know that Fuse equips visual logic with a debugging arsenal as complete as writing code: conditional breakpoints, skipping the first N hits, replaying the whole execution chain, plus a bottom Dock panel that watches variables live and plots line charts. Visual does not mean black box—this is the 13th piece of Fuse's moat.

## What Makes Visual Debugging Hard, Exactly

When GDScript misbehaves you can `print()`, set breakpoints, step through, and read the call stack. Visual systems lack all of these by nature—instructions are a pile of Resource configurations, the execution chain runs inside `ActionRunner`, variables live in an `ExecutionContext`, all invisible from the outside. Most similar tools' debugging experience stops at "add a log line to some instruction"; even "did this instruction actually execute" is guesswork.

Fuse's answer is to **make debugging a first-class citizen**: three dedicated debugging instructions cover the full chain from logging to breakpoints, two editor components provide execution replay and variable watching, and breakpoints even support expression conditions and hit-count control.

## The Three Debugging Instructions

**`Print` (print message)** is the lightest. It has only a `message` property; on execution it outputs to the Godot output window and the `ExecutionContext` log, formatted as `[PrintInstruction] your message`. Good for marking execution flow.

**`PrintVariableValue` (print variable value)** answers "what does the variable equal right now". It formats output by type—String with quotes, Vector2 as coordinates, Color as RGBA, null printed as null. Supports the Local/Scope/Global three-layer scopes.

**`BreakpointInstruction` (breakpoint)** is the heavy weapon, merging "log + variable snapshot + condition + pause" into a single instruction.

| Feature | Print | PrintVariableValue | BreakpointInstruction |
|---|---|---|---|
| Custom message | Yes | No | Via label |
| Variable output | No | Single variable | Full variable snapshot |
| Conditional triggering | No | No | Expression condition |
| Pause execution | No | No | Editor pause |
| Ignore count | No | No | Supported |
| Exported builds | Normal | Normal | Degrades to log |

## Advanced Breakpoints: This Is the Moat

**Conditional breakpoints.** Enable `use_expression_condition` and write an expression; it triggers only when the condition is true. To debug "damage settlement when health is below 30", just write `{scope:health} < 30`.

**Skipping the first N hits.** Set `ignore_count = 3` and the first 3 hits are skipped; output starts on the 4th.

**Pause on hit.** When enabled, the game pauses, the variable snapshot prints, and Enter resumes. **Editor only**—exported builds automatically degrade to logging.

**Scope source.** Four choices—Nearest/Custom ID/Trigger Scope/Target Node—to precisely lock onto the container you want to inspect.

## Execution Tracing: DebugVisualizer + ExecutionTracker

`ExecutionTracker` records every instruction's start, completion, errors, and performance bottlenecks. `DebugVisualizer` renders them as a clickable tree with color coding: green = success, red = error, yellow = performance issue, blue = start.

Five official workflows:
1. **Quick triage**: Print → PrintVariableValue → remove the debug instructions once located
2. **Breakpoint debugging**: BreakpointInstruction → read the output snapshot
3. **Performance profiling**: run a sequence → look for red/yellow records → export JSON
4. **Conditional breakpoint debugging**: enable a condition expression → trigger only in specific scenarios
5. **Topology static analysis**: see problem annotations directly at edit time

## The Variable Watcher: The Live Panel Is the Real Moat

Embedded in the editor's bottom Dock, it polls every 0.5 seconds to show all variables, in three layers: Local/Scope/Global.

Five differentiating features:
- **Double-click editing**: change a variable's value on the spot, no rerun needed
- **60-second line chart recording**: pick a variable to see its history curve; records int/float only
- **Snapshot export**: one-click JSON export for the record
- **Static declaration completion**: see variable reference relationships without running
- **Three-layer color coding**: know at a glance which layer a variable lives in

## In Practice: Debugging a "Damage Settlement Never Applies" Bug

Print to trace the flow → PrintVariableValue to inspect variables → BreakpointInstruction to pause on a condition and read the snapshot → the variable watcher's line chart → snapshot export for the record. From light to heavy, every step has a matching tool.

## Summary

Fuse's debugging system weaves a net of "three debug instructions + four breakpoint advances + execution tracing + the variable watcher". But these are all single-point debugging—as the project grows, the harder problem is the global view. The next chapter covers the Topology main screen, which draws the whole scene's Trigger relationships as one graph, with built-in static analysis that flags problems red without ever running.
