> 🌐 [**中文版**](../../../zh_CN/user_docs/guides/00-editor-panels-overview.md) | English

# Editor Panels Overview

Fuse integrates several dedicated interfaces into the Godot editor, covering: the **Fuse Topology main screen tab** (whole-scene Trigger topology overview + problem annotations), **Inspector enhancements** (data flow card + preset operations), the **scope variable editor**, and the **bottom-dock variable watcher** ([56-variable-watcher-guide](56-variable-watcher-guide.md)). This document serves as the entry reference for all editor panels.

---

## Table of Contents

| Panel | Documentation Section | Core Files |
|------|----------|----------|
| **Fuse Topology Main Screen** | [Fuse Topology](#fuse-topology-main-screen) | `editor/topology/fuse_topology.gd` |
| Inspector plugin | See this chapter | `editor/fuse_inspector_plugin.gd` |
| Scope variable editor | [Scope Variable Editor](#scope-variable-editor) | `editor/scope_variable_container_plugin.gd` |
| Collaborators | [How the Panels Work Together](#how-the-panels-work-together) | Multi-component coordination |

---

## Fuse Topology Main Screen

The Fuse plugin registers a **"Fuse" tab** in the editor main screen (alongside 2D / 3D / Script), providing a whole-scene topology overview of Fuse units (three unit types: Trigger / MultiEventTrigger / Runner; Runners are highlighted in green, with their bound signal name shown in the second column). It is the **top-level entry point** of the Fuse editor integration.

**File:** `editor/topology/fuse_topology.gd` (depends on `fuse_graph_builder.gd`, `fuse_graph_node.gd`, `analysis/instruction_analyzer.gd`)

### Registration Mechanism

| Stage | Behavior |
|------|------|
| Plugin enabled (`_enter_tree`) | `EditorInterface.get_editor_main_screen().add_child(_topology)` + `_make_visible(false)` (initially hidden) |
| User switches to the "Fuse" tab | `_make_visible(true)` shows it |
| Plugin metadata | `_has_main_screen() = true`; `_get_plugin_name()` → `"Fuse"`; icon `VisualShader` |

### UI Layout

```
[Fuse Scene Topology] [Problem Filter▾] [Search: unit/instruction/variable…] [🔄 Refresh] [Export Problem Report] [Export JSON]
┌────────────────────────┬─────────────────────────────────┐
│ Trigger          Event │  Details (BBCode rich text)      │
│ ├ Trigger(OnKey)  on_key│  Select a Trigger → Trigger summary │
│ │  ├ SetVariable        │  Select an instruction → instruction details │
│ │  ├ CompareVariable    │                                  │
│ │  └ EmitSignal         │  Global cross-reference scan     │
│ └ Runner(OnTimer) timer │  (variable/signal references across Triggers) │
└────────────────────────┴─────────────────────────────────┘
```

### Features

| Area | Description |
|------|------|
| **Left Trigger tree** | Scans the whole scene and displays nested instruction chains grouped by Trigger (with icons + branch markers); the second column shows the bound event |
| **Right details panel** | BBCode rich text: selecting a Trigger shows its summary, selecting an instruction shows the instruction details (parameters / dependencies / references) |
| **Global cross-reference scan** | The `cross_ref_label` annotates variable / signal / node reference relations across Triggers |
| **Refresh** | Re-scans the current scene and rebuilds the Trigger tree and details |
| **Search filter** | Banner search box: matches by unit name / instruction type / variable name / signal name (case-insensitive, orthogonal to and stacked with the problem filter, 0.5 s debounce) |
| **Runner units** | L3 Runners (signal-binding units) are displayed as standalone units, highlighted in green, with signal_name in the second column; RunRunner call edges (`run` type) count into the global cross-references |

### Problem Annotations (Static Analysis)

Whenever the Topology refreshes, it automatically runs instruction-sequence analysis (undeclared `local` variable detection) and annotates the results in place:

- **Instruction nodes**: StatusError (red) / StatusWarning (yellow) theme icons + row coloring
- **Trigger nodes**: an aggregated problem count for the subtree (e.g. `(2 errors, 1 warning)`); rows containing an error are colored red
- **Selected node** → the right details panel shows the node's specific problems (BBCode, colored by severity)
- **"Export Problem Report" button** (top banner) → writes a whole-scene problem summary to `user://fuse_problems_report_*.txt`

The analysis is provided by `InstructionAnalyzer.analyze_problems` (it reuses the reflective `_extract_variables` extraction and is not a separate engine).

### Problem Filter

The Topology's top banner provides a problem filter OptionButton:

| Option | Behavior |
|------|------|
| **All** | Shows all Triggers / instructions (default) |
| **Errors only** | Shows only nodes containing errors (hides problem-free and warning-only nodes) |
| **None** | Turns off problem annotations; a pure topology view |

Combined with the problem counts (the `(2 errors, 1 warning)` suffix on Trigger rows), this quickly locates problem-dense areas.

### Search Filter

The banner search box filters the unit tree in real time (0.5 s debounce). The match surface covers **unit names, instruction type names (including nested and event_bindings chains), three-layer variable names, signal_binding signal names, and the signals list**—queries like "which unit uses `hp`" are answered in one step. Empty text shows everything; when nothing matches, a gray hint is shown. It stacks orthogonally with the problem filter dropdown.

### Topology JSON Export

The "Export JSON" button / headless CLI (`export_topology.tscn -- --scene res://<scene>`) writes the topology report to disk as JSON (by default `res://fuse_reports/topology/<scene-file>.json`), containing the `source_scene` provenance path, the `exported_at` timestamp, all units / cross-unit references / variable analysis. It is the ground truth for the handoff artifacts on the graduation side (fed to the user's AI agent to write code that runs without Fuse), and can also be used for cross-scene search and as AI context material.

This JSON is also the topology snapshot source of the handoff bundle (consumed by the `fuse-handoff-packer` skill).

### Cross-Trigger References

The Topology details panel automatically scans for variable / signal reference relations across Triggers:

- **Write-read arrows**: Trigger A writes variable `x`, Trigger B reads `x` → the details panel annotates `x: written by TriggerA → read by TriggerB`
- **Race warnings**: multiple Triggers write the same variable (write-write conflict) → annotated with a ⚠ warning that the execution order is undefined
- **Orphan writes / orphan reads**:
  - Orphan write: a variable is only written, never read → annotated with a hint (possibly redundant logic)
  - Orphan read: a variable is only read, never written → annotated as an error (it will always hold the default value at runtime; a write is likely missing)

### Auto Refresh and Interaction

- **Auto refresh**: the Topology refreshes automatically when the scene changes or is saved (Ctrl+S) (0.5 s debounce to avoid overly frequent refreshes)
- **Selection persistence**: after a refresh, the previously selected entry (Trigger/instruction) is restored automatically
- **Double-click jump**: double-click a Trigger → the Inspector jumps to the corresponding node in the scene; double-click an instruction → the Inspector shows the instruction Resource
- **Manual refresh**: the banner "Refresh" button still works (selection persistence included)

### GraphEdit (Kept but Dormant)

The code keeps `FuseGraphEdit` (a visual node graph based on Godot's `GraphEdit`) and `FuseGraphNode`, but they are currently **hidden by default** (`visible = false`). For now the **Tree view** is the primary interaction; the GraphEdit view is not enabled and its code is kept for reference only.

---

## Inspector Plugin

`FuseInspectorPlugin` (an `EditorInspectorPlugin`) is Fuse's core entry point in the Inspector panel, activating automatically when a Fuse-related node or resource is selected.

### Applicable Types

For the following types, the plugin automatically takes over Inspector rendering:

| Type | Effect |
|------|----------|
| `BaseInstruction` | Keeps the default property editing |
| `BaseEvent` | Adds a "select event" button |
| `BaseCondition` | Adds a "select condition" button |
| `BaseVariable` | Keeps the default property editing |
| `ActionRunner` | Keeps the default property editing |
| `BaseTrigger` | **Data flow card** + export/import buttons |
| Objects with `instructions` / `event` / `condition` properties | Button enhancements |

The **selector buttons** allow quick replacement of event/condition resources:

```
[ Click to select an event... ▼ ]   ← BaseEvent property
[ Click to select a condition... ▼ ]   ← BaseCondition property
```

Clicking opens the `ComponentSelector` dialog, which shows all registered components available for selection.

---

### Inspector Data Flow Card

When a **BaseTrigger** node (such as Trigger or MultiEventTrigger) is selected, the Inspector automatically generates a **collapsible data flow info card** at the bottom, visualizing the overall structure of that Trigger's instruction chain.

#### Trigger Buttons

A row of buttons appears at the bottom of the Inspector:

```
[📊 Data Flow: OnInterval (5 instructions, 3 nodes, 8 variables, 2 signals)]     ← data flow summary
[📦 Export (Trigger)] [📥 Import Preset]                  ← preset operations
```

The `📊 Data Flow` button is **click-to-collapse**: clicking expands/collapses the data flow card.

#### Problem Count Badge

When the Trigger's instruction chain has static analysis problems, the `📊 Data Flow` button shows a **problem count badge** (e.g. `2 errors, 1 warning`; the button text turns red when an error exists). Once the data flow card is expanded, the "Problem Details" section at the bottom lists the specific problems grouped by error / warning (instruction name + problem description), consistent with the problem annotations on the Fuse Topology main screen.

#### Data Flow Card Contents

The card presents the analysis result as indented text:

```
Data Flow
  Event: OnInterval
  Operated nodes: Player, Enemy, ScoreLabel
  Variables: [local] damage, cooldown | [scope] hp(../Player) | [global] score
  Signals: score_changed(ScoreManager) | on_death(Player)
  Instruction chain (5)
    ┊ SetVariable → damage = 25
    ┊ CompareVariable → hp > 0 ?
    ┊ TweenMoveTo → move to Enemy
    ┊ EmitSignal → score_changed
    ┊ LogInstruction → "attack finished"
```

**Data source**: the `InstructionAnalyzer.build_topology()` analysis result, containing:

| Field | Description |
|------|------|
| `event` | Event resource name |
| `nodes` | All operated node paths referenced by instructions |
| `variables` | Variable information grouped by local/scope/global |
| `signals` | All signals referenced by EmitSignal in the instruction chain |
| `instructions_flat` | The flattened instruction chain (with indentation prefixes) |

---

### Preset Operations

Below the data flow card are preset export/import buttons; for detailed operations see the [Preset System Guide](55-preset-system-guide.md).

#### Export

- Automatically detects the current node's preset level (L2/L3/L4)
- The button text dynamically shows the current level: `📦 Export (Trigger)`
- Clicking opens the `PresetExportDialog`; after configuring the name/category/description it exports `.tres` + `.json`

**Pre-checks**: the export button is shown only when the following conditions are met:

| Level | Condition |
|------|------|
| L2 (Trigger) | `event_definition` is configured |
| L3 (Runner) | `action_runner` is configured |
| L4 (MultiEventTrigger) | At least 1 binding with `enabled` |

If validation fails, the export button is not shown (only the import button appears).

#### Import

- Always available
- Clicking opens a `FileDialog` filtered to `.tres` / `.json`
- Creates the corresponding node based on the preset level (Trigger / Runner / MultiEventTrigger)
- Automatically pops up the NodePath mapping confirmation dialog

---

### Inspector Property Recognition Flow

The decision flow of `_parse_property()` (main flow; instruction arrays are delegated to the separate `instructions_array_inspector_plugin.gd`):

```
1. Is it an instruction-array property?            → delegate to instructions_array_inspector_plugin
2. Type is OBJECT + PROPERTY_HINT_RESOURCE_TYPE
   + the type string contains "BaseEvent"     → add the event selector button
3. Type is OBJECT + PROPERTY_HINT_RESOURCE_TYPE
   + the type string contains "BaseCondition"  → add the condition selector button
4. Otherwise → do nothing, return false
```

---

## Scope Variable Editor

`ScopeVariableContainerPlugin` (an `EditorInspectorPlugin`) provides a dedicated variable editing panel for `ScopeVariableContainer` nodes.

**File:** `editor/scope_variable_container_plugin.gd`
**Target node:** `core/base/scope_variable_container.gd`

### UI Layout

After selecting a `ScopeVariableContainer` node in the scene, the Inspector shows:

```
+------------------------------------------------------+
| Scope Variables                                       |
+------------------------------------------------------|
| [────────────────────]                               |
|                                                       |
|   health = 100                                        |
|   mana = 50                                           |
|   current_state = "idle"                              |
|                                                       |
| [────────────────────]                               |
| [+ Add Variable]  [- Remove Variable]  [↻ Refresh]   |
+------------------------------------------------------+
```

### Features

| Button | Description |
|------|------|
| **Add Variable** | Creates a new variable, automatically named `new_var_{index}`, with initial value `0` |
| **Remove Variable** | Removes the variable selected in the list |
| **Refresh** | Re-reads the variable list from the node and updates the display |

### Formatted Display

Variable values are formatted by type:

| Value Type | Display Format |
|--------|----------|
| null | `variable_name = null` |
| String | `variable_name = "text"` |
| Array | `variable_name = [N elements]` |
| Dictionary | `variable_name = {N keys}` |
| Other | `variable_name = value` (calls `str()` directly) |

### Editing Operations

After every modification (add/remove/refresh), `notify_property_list_changed()` is called automatically to sync the display state of the remaining Inspector properties.

---

## How the Panels Work Together

How the three panels cooperate inside the editor:

```
┌─────────────────────────────────────────────────────┐
│                     Godot Editor                    │
│                                                      │
│  ┌────────────────────┐  ┌────────────────────────┐│
│  │   Scene Dock       │  │  Inspector (Fuse-enhanced) ││
│  │                    │  │                        ││
│  │  ☐ Trigger (selected)  │  │  event: [Select event ▼]  ││
│  │    ├─ ActionRunner │  │  📊 Data flow card         ││
│  │    └─ ...          │  │  📦 Export  📥 Import      ││
│  │                    │  │                        ││
│  │  ☐ ScopeVarContr. │  │  Scope variable editor       ││
│  │    (selected)          │  │  [+] [-] [↻]          ││
│  └────────────────────┘  └────────────────────────┘│
│                                                      │
│  ┌──────────────────────────────────────────────────┐│
│  │  Bottom Dock                                     ││
│  │                                                  ││
│  │  [VariableWatcher]                               ││
│  │                                                  ││
│  │  Variable watcher (problem annotations live on the Fuse Topology main screen)  ││
│  └──────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────┘
```

### Typical Workflows

**Debugging workflow:**
1. Select a `Trigger` in the scene → check the **data flow card** in the Inspector to confirm the instruction chain
2. Run the scene → watch variable changes live in the bottom **VariableWatcher**
3. Find a problem → refresh the **Fuse Topology main screen**, which automatically annotates instruction-sequence problems (red = error / yellow = warning)
4. Fix → export a preset backup from the Inspector → keep iterating

**Configuration workflow:**
1. Add a `ScopeVariableContainer` node to the scene
2. Add variables with initial values via the **scope variable editor** in the Inspector
3. Instructions in the Trigger reference these scope variables
4. After running, **VariableWatcher** shows the runtime values of the scope variables

---

## Troubleshooting

| Problem | Cause | Solution |
|------|------|----------|
| The Inspector shows no data flow card | The selected node is not a BaseTrigger | Select a Trigger / MultiEventTrigger node |
| Instruction nodes are red in the Topology | `analyze_problems` detected an error (e.g. an undeclared local variable) | Select the node and check the right details panel for the specific problem |
| The scope variable editor is blank | ScopeVariableContainer has no variables | Click "Add Variable" to create one |
| The export button does not appear | The pre-checks did not pass | Check the event_definition/action_runner configuration |
| Localized text does not take effect | Editor language detection is delayed | Restart the editor or switch languages |

---

**Related docs:**
- [Preset System Guide](55-preset-system-guide.md)
- [Variable Watcher Guide](56-variable-watcher-guide.md)
- [Variable System Guide](01-variable-system-guide.md)
- [Debugging System Guide](25-debugging-guide.md)
- [Breakpoint Guide](26-breakpoint-guide.md)
