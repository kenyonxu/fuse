> 🌐 [**中文版**](../../../zh_CN/user_docs/Introductions/14-Topology拓扑主屏.md) | English

# One Graph for All Scene Logic: The Fuse Topology Main Screen and Static Analysis

The previous chapter brought single-point debugging to IDE level with breakpoints, execution tracing, and the variable watcher. But debugging has a precondition—you must first know which Trigger the problem lives in. When a project has dozens of scenes and hundreds of Triggers interlinked through the Event Bus, "where to even look" becomes the biggest cost. Fuse's answer is to give the whole project a god's-eye view: the Fuse Topology main screen. After this chapter you'll understand that it is not just a pretty picture—it is a built-in static analyzer that, before you ever run the game, flags "undeclared variables", "dead NodePaths", and "write-write races" in red, and can tell you which Trigger wrote a variable and which Trigger read it. The engineering moat of a visual system starts taking shape on this screen.

Picking up from the previous chapter: single-point debugging is in place, but you need the global view to know where to break.

## The Topology Main Screen: A God's-Eye View of the Whole Scene

Topology registers under the "Fuse" tab at the top of the editor, alongside 2D/3D/Script. The UI splits left-right: the left side is a Trigger tree that scans all Triggers and Runners in the current scene, grouped by node structure; the right side is a details panel rendering the selected instruction or Trigger as BBCode rich text.

The tree view looks roughly like this:

```
Trigger(OnInputKey)    on_input_key
  ├ SetVariable
  ├ CompareVariable
  └ EmitSignal
Runner(OnTimer)        timer
  └ TweenMoveTo
```

## Interaction Design That Never Needs a Manual Refresh

Auto refresh with a 0.5-second debounce: the topology rebuilds automatically when you switch scenes and when you save a scene (Ctrl+S). Paired with selection retention (the previously selected node is restored after a refresh) and double-click jump (double-click a Trigger to jump straight to the Inspector; double-click an instruction to open Resource editing).

## Static Analysis: Red Flags at Edit Time (Moat Deepens)

Problems are analyzed on every refresh and annotated in place on the tree nodes. Five problem categories are covered:

- **Undeclared local variables**: read somewhere in the chain but never declared by any SetVariable
- **NodePath resolution failure**: a referenced path matches no actual node in the scene
- **Signal reference checking**: a signal referenced by EmitSignal does not exist on the target node
- **Event whitelist**: some input-type events inject variables; those do not count as undeclared
- **StatusError/Warning icons**: red/yellow annotation plus an end-of-line problem count

## Cross-Trigger Relationship Scanning (Moat Deepens)

Four relationship types are analyzed automatically:

- **Write-read arrows**: who wrote, who read—confirm the data flow matches expectations
- **Write-write race warnings**: multiple Triggers writing the same variable, flagged with a ⚠ warning
- **Orphan writes**: written but never read, possibly redundant logic
- **Orphan reads**: read but never written, flagged as error (the runtime will inevitably read the default value)

## The Inspector Data-Flow Card

Select any BaseTrigger node and a data-flow button appears at the bottom of the Inspector, formatted like `📊 Data Flow: OnInterval (5 instructions, 3 nodes, 8 variables, 2 signals)`. Expanding it reveals the structured instruction chain, variable categories, and signal references. When static analysis has found problems, the button shows a problem-count badge; red means there are errors.

## Three-Level Filtering and Report Export

The top banner offers three filter levels: All / Errors only / None. There is also an export-problems button that writes all scene problems into `user://fuse_problems_report_*.txt`, suitable for CI or offline review.

## A New Role: The Source of Handoff Artifacts

The panel's graph also has a CLI channel for headless export:

```bash
Godot --headless --path . res://addons/fuse/editor/topology/export_topology.tscn -- --scene res://<你的场景>.tscn
```

The exported topology JSON is the structured version of everything you see on the main screen—all Trigger / Runner units and cross-unit relationships (events, RunRunner calls, variable reads/writes, signals, race warnings), plus source-scene provenance fields. Its next stop is `derive_systems` to derive the System artifact, which finally enters the handoff bundle for an AI agent to write Fuse-independent engineering code—the full chain is walked in chapter 16. **The topology panel is not just a review tool; it is the source of the "graduation" leg.**

## In Practice: Sweeping a Messy Scene Clean

You inherit a prototype where a dozen-plus Triggers misbehave occasionally. Open the Fuse tab → filter Errors only → double-click to fix → Ctrl+S to auto-refresh and verify → check write-write races → export the report for the record. Without running the game even once.

## Summary

Topology puts the whole scene's Trigger relationships and static analysis on one graph, exposing configuration errors at edit time; it is also the source of handoff artifacts, with the topology JSON flowing down the CLI channel into the graduation pipeline. Debugging and review are both in place; the next level is performance and reuse—the next chapter covers the preset system, object pools, multithreaded conditions, and engineering performance; the series' true finale is chapter 16: AI collaboration and graduation handoff.
