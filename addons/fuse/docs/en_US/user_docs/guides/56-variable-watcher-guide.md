> 🌐 [**中文版**](../../../zh_CN/user_docs/guides/56-variable-watcher-guide.md) | English

# Variable Watcher User Guide

`FuseVariableWatcher` is a **real-time variable monitoring panel** docked at the bottom of the Godot editor, showing the name, value, and type of every visible Fuse runtime variable at a 0.5-second polling rate. It supports double-click editing, recorded line charts, and static declaration snapshot completion.

**Related file:** `addons/fuse/editor/debugging/variable_watcher.gd`

---

## Feature Overview

| Feature | Description |
|------|------|
| Polling interval | 0.5 seconds (Timer driven) |
| Display layers | Local / Scope / Global |
| Runtime data source | `FuseRuntimeBridge` (Autoload node push) |
| Global variable data source | `GlobalVariableService` |
| History | 120 frames = 60-second sliding window (numeric types only) |
| Search filter | Real-time filtering by variable name |

---

## Panel Layout

The variable watcher sits in the editor's bottom dock; its layout has four areas:

```
+-----------------------------------------------------------+
| Refresh:0.5s                      Global:5  Runner:2 [📸Snapshot] |
| [Search variables...______________________________________] |
| [Variable       | Value         | Type                    ] |
+-----------------------------------------------------------+
| Local (Runner1)                                           |
| [health         | 85             | int                    ] |
| [target_pos     | (120, 340)     | Vector2                ] |
|                                                           |
| Scope                                                      |
| [alert_level    | 50             | int                    ] |
| [current_state  | "patrol"       | String                 ] |
|                                                           |
| Global                                                     |
| [player_score   | 2450           | int                    ] |
| [game_time      | 132.5          | float                  ] |
|                                                           |
| Instruction references (static)                            |
| [cooldown       | (static)       |local · read/write · 2 refs |
+-----------------------------------------------------------+
| [=== Line chart area =================================]   |
+-----------------------------------------------------------+
```

### Top Bar

| Control | Description |
|------|------|
| Status label | Shows polling status and variable statistics, e.g. `Global:5  Runner:2` |
| 📸Snapshot button | Click to export a snapshot of all current variables to `user://fuse_watcher_snapshot_{时间戳}.json` |

### Search Box

Filters variable rows across all sections in real time, matching variable names. An empty string shows everything.

### Column Headers

Three-column layout: **Variable** | **Value** | **Type**

The header row has a dark blue background (`COL_HEADER: Color(0.2, 0.3, 0.5)`).

### Scrollable Content Area

Variable rows grouped by section; each row follows the column headers' format.

---

## Three-Layer Variable Display

### 1. Local Variables

Shows the local (`local`) variables in each current Runner (`ActionRunner`) instance. Each row is labeled with the owning Runner's name:

```
Local (Runner1)
  [health     | 85   | int]
  [target_pos | (120, 340) | Vector2]

Local (Runner2)
  [loop_count | 3    | int]
```

**Runtime requirement**: shown only after the scene runs. When no runtime data is detected, the hint `(场景运行后可见)` is displayed.

### 2. Scope Variables

Shows variables declared with `scope` scope in each Runner:

```
Scope
  [alert_level  | 50       | int]
  [current_state| "patrol" | String]
```

Scope variables are obtained via `FuseRuntimeBridge.get_cached_vars()` and depend on runtime push.

### 3. Global Variables

Obtains all global variables registered in `GlobalVariableManager` via `GlobalVariableService.get_all_global_variables_info()`:

```
Global
  [player_score  | 2450       | int]
  [game_time     | 132.5      | float]
  [is_game_over  | false      | bool]
```

Global variables are **persistent** — they survive scene changes, making them suitable for cross-scene debugging.

---

## Polling Mechanism

A `Timer` drives the panel's 0.5-second refresh loop:

```gdscript
_timer.wait_time = 0.5
_timer.autostart = true
_timer.timeout.connect(_on_timer)
```

Each refresh (`_refresh()`) runs the following steps:

```
1. Check the _editing flag (skip while editing, to avoid destroying the LineEdit)
2. Clear the content area
3. Collect local + scope variables via _collect_runtime_variables()
4. Collect global variables via GlobalVariableService
5. Record history for each row (int/float only)
6. Render the Local / Scope / Global sections
7. Render the static declarations section (topology cache refreshed every 5 seconds)
8. Update the bottom line chart
9. Update the status label
```

---

## Stage 7 Features

### 7a — Double-Click Editing

Interactive rows (not notes, not static) support editing variable values by double-clicking:

| Scope | Editing | Write-back target |
|--------|----------|----------|
| **Local** | Runtime only | `context.set_variable(name, coerced_value, "local")` |
| **Scope** | Runtime only | `context.set_variable(name, coerced_value, "scope")` |
| **Global** | Always available | `GlobalVariableManager.add_variable(name, variable)` |

**How to operate**:
1. Double-click the value cell → it is replaced by a `LineEdit`
2. Type the new value (string input, converted automatically)
3. `Enter` commits / blur commits

**Type coercion rules** (`_coerce_value`):

| Target type | Rule |
|----------|----------|
| int | `text.is_valid_int()` → `text.to_int()` |
| float | `text.is_valid_float()` → `text.to_float()` |
| bool | matches `"true"` / `"1"` / `"是"` / `"yes"` |
| String | returned as-is |
| Other | best effort, returned as-is |

**Safety guards**:
- While editing, `_editing = true` and `_refresh()` skips rebuilding, so the LineEdit is not destroyed
- Local/Scope variables need a valid `context` (editing is blocked when the runtime context is unavailable)

### 7b — Line Chart

Clicking any variable row selects it; the bottom line chart area shows its value history:

- **History window**: `HISTORY_MAX = 120` frames (60-second sliding window, `0.5s × 120 = 60s`)
- **Recording scope**: only `int` and `float` variables (other types are ignored automatically)
- **Storage key**: `"{scope}/{var_name}"` (e.g. `"global/player_score"`)

**HistoryGraph component**:
- Nested class `HistoryGraph extends Control`
- Drawing logic: values are normalized to `[0, 1]` to draw the line
- With no data, a gray placeholder text `(无数值历史)` is shown
- Switches display automatically when a new variable is selected

```
# Selected "global/player_score"
# The line chart shows the score trend over the last 60 seconds
  ▁▂▃▅▇▆▅▄▃▂▁▂▃▄▅▆▇▆▅▄▃▂▁
  ↑                          ↑
  min=2100               max=2600
```

### 7c — Static Declarations

In editor mode, the panel scans the instruction-chain topology of all Triggers in the scene, aggregates **variable declaration info**, and shows it in a separate section:

```
Instruction references (static)
  [cooldown        | (static) | local · read/write · 2 refs]
  [player_health   | (static) | scope · read/write · 1 ref]
  [level_score     | (static) | global · read · 3 refs]
```

**Meaning of each field**:

| Field | Description |
|------|------|
| Variable name | The declared variable name |
| Value | Fixed as `(静态)` (static), not a live value |
| Type | `{scope} · {access mode} · {reference count}` |

**Access modes**:
- `读写` (read/write) — both reads and writes
- `写` (write) — only writes such as SetVariable
- `读` (read) — only reads such as GetVariable

**Caching**: the topology scan runs every 5 seconds (`STATIC_REFRESH_INTERVAL_MS = 5000`) to avoid the overhead of scanning at the 0.5-second rate.

### 7d — Snapshot Export

Click the **📸Snapshot** button to export a complete snapshot of all variables at this moment to a JSON file:

```json
{
    "timestamp": 1234.567,
    "global": {
        "player_score": {"value": 2450, "type": "int"},
        "game_time": {"value": 132.5, "type": "float"}
    },
    "runners": [
        {
            "runner_name": "Runner1",
            "local": {
                "health": {"value": 85, "type": "int"},
                "target_pos": {"value": "(120, 340)", "type": "Vector2"}
            },
            "scope": {
                "alert_level": {"value": 50, "type": "int"}
            }
        }
    ]
}
```

Export path: `user://fuse_watcher_snapshot_{时间戳}.json`

---

## Color Scheme

| Area | Color | RGB |
|------|------|-----|
| Variable name | Dark blue | `(0.1, 0.15, 0.3)` |
| Value | Dark green | `(0.1, 0.25, 0.15)` |
| Type | Light black | `(0.15, 0.15, 0.15)` |
| Section titles | Medium blue | `(0.2, 0.3, 0.5)` |
| Font color (Label) | Light gray | `(0.85, 0.85, 0.85)` |
| Line chart stroke | Pale blue | `(0.4, 0.8, 1.0)` |

---

## Data Source Architecture

```
┌─────────────────────────────────────────────┐
│          FuseVariableWatcher (Dock)          │
│                                              │
│  ┌──────────────┐   ┌───────────────────┐   │
│  │ 0.5s Timer    │   │ get_snapshot()    │   │
│  └──────┬───────┘   └────────┬──────────┘   │
│         │                     │              │
│         ▼                     ▼              │
│  ┌──────────────┐   ┌───────────────────┐   │
│  │ _refresh()   │   │ GlobalVariableSvc │   │
│  └──┬───────┬───┘   └───────────────────┘   │
│     │       │                                │
│     ▼       ▼                                │
│  ┌────┐ ┌──────┐                             │
│  │L/S │ │Global│                             │
│  └──┬─┘ └──────┘                             │
│     │                                        │
│     ▼                                        │
│  FuseRuntimeBridge (Autoload)                │
└─────────────────────────────────────────────┘
```

- **FuseRuntimeBridge**: an Autoload singleton that actively pushes local/scope variable caches while the game runs
- **GlobalVariableService**: reads global variables from `GlobalVariableManager`
- **InstructionAnalyzer**: analyzes Trigger topology in the editor, providing static declaration data

---

## Troubleshooting

| Problem | Cause | Solution |
|------|------|----------|
| Blank panel | Scene not running or no Fuse nodes | Run the scene and make sure a Trigger/ActionRunner exists |
| Local/Scope not shown | `FuseRuntimeBridge` not registered | Check the Autoload configuration |
| Double-click edit does nothing | A runtime context is required | local/scope variables can be edited only while the scene runs |
| Line chart has no data | Variable is not numeric | Only `int`/`float` variables are recorded in history |
| Snapshot save failed | Insufficient path permissions | Check permissions of the `user://` directory |
| Panel flickers while editing | 0.5s polling conflicts with editing | Protected by Stage 7a (the `_editing` flag blocks refresh rebuild) |

---

**Related docs:**
- [Debugging System Guide](25-debugging-guide.md)
- [Breakpoint Guide](26-breakpoint-guide.md)
- [Global Variables Management Guide](54-global-variables-guide.md)
- [Editor Panels Overview](00-editor-panels-overview.md)
