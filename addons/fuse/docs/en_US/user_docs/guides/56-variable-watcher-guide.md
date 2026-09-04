> 🌐 [**中文版**](../../../zh_CN/user_docs/guides/56-variable-watcher-guide.md) | English

# Variable Watcher User Guide

`FuseVariableWatcher` is a **real-time variable monitoring panel** docked at the bottom of the Godot editor, showing the name, value, and type of every visible Fuse runtime variable at a 0.5-second polling rate. It supports double-click editing (write-back to the running game over the TCP bridge at runtime), recorded line charts, and static declaration snapshot completion.

**Related file:** `addons/fuse/editor/debugging/variable_watcher.gd`

---

## Feature Overview

| Feature | Description |
|------|------|
| Polling interval | 0.5 seconds (Timer driven) |
| Display layers | Local (grouped by host component) / Scope (grouped by container) / Global (flat) |
| Runtime data source | `FuseRuntimeBridge` (Autoload node push, protocol v3) |
| Global variable data source | While the game runs: live snapshot from the game process; otherwise `GlobalVariableService` |
| History | 120 frames = 60-second sliding window (numeric types only) |
| Search filter | Real-time filtering by group path + variable name (case-insensitive) |

---

## Panel Layout

The variable watcher sits in the editor's bottom dock; its layout has four areas:

```
+-----------------------------------------------------------+
| Refresh:0.5s          Global:5  Unit:2  Ctn:1 [📸Snapshot] |
| [Search variables...______________________________________] |
| [Variable       | Value         | Type                    ] |
+-----------------------------------------------------------+
| ▸ /Main/Runner1 [Runner] · 0.3s                           |
| [health         | 85             | int                    ] |
| [target_pos     | (120, 340)     | Vector2                ] |
|                                                           |
| ▸ /Enemies/Guard [Trigger] · 6.2s   (stale, grayed out)   |
| [aggro         | true           | bool                   ] |
|                                                           |
| ▸ /World/LevelScope (level1)                              |
| [alert_level    | 50             | int                    ] |
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
| Status label | Shows polling status and variable statistics, e.g. `Global:5  Unit:2  Ctn:1` (global rows / unit hosts / containers) |
| 📸Snapshot button | Click to export a snapshot of all current variables to `user://fuse_watcher_snapshot_{时间戳}.json` |

### Search Box

Filters variable rows across all sections in real time, matching **group paths + variable names** (case-insensitive). A group whose rows are all filtered out hides its group header too; while a filter is active the collapsed state is ignored so matches always show. An empty string shows everything.

### Column Headers

Three-column layout: **Variable** | **Value** | **Type**

The header row has a dark blue background (`COL_HEADER: Color(0.2, 0.3, 0.5)`).

### Scrollable Content Area

Variable rows grouped by section; each row follows the column headers' format.

---

## Three-Layer Variable Display

### 1. Local Variables (grouped by host component)

Shows the local (`local`) variables reported by each host component (BaseTrigger / MultiEventTrigger / Runner), from its **most recent execution context**. Each group header shows the component's path, kind, and freshness:

```
▸ /Main/Runner1 [Runner] · 0.3s
  [health     | 85   | int]
  [target_pos | (120, 340) | Vector2]

▸ /Enemies/Guard [Trigger] · 6.2s      ← older than 5s: grayed out
  [aggro     | true | bool]
```

Group headers are clickable and collapse/expand their group; the collapsed state survives refreshes. A component appears only after its first execution (it has no execution context before that).

### 2. Scope Variables (grouped by container)

Shows the variables of each `ScopeVariableContainer`, grouped by container:

```
▸ /World/LevelScope (level1)
  [alert_level   | 50       | int]
  [current_state | "patrol" | String]
```

Containers are collected from the whole scene tree, so even a subtree that has never been triggered shows its containers' declared (default) values. Scope variables are obtained via `FuseRuntimeBridge.get_cached_vars()` and depend on runtime push.

### 3. Global Variables

The Global section switches its data source automatically depending on whether the game is running:

- **While the game runs**: shows the live scalar snapshot pushed by the game process (via `FuseRuntimeBridge`); the section title carries the "(Game)" suffix
- **Not running**: reads the editor-side definitions via `GlobalVariableService.get_all_global_variables_info()`

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
3. Collect local + scope rows via _collect_runtime_variables() from the bridge cache (v3 keys: "containers" → Scope rows grouped by container, "units" → Local rows grouped by host; missing fields degrade to empty sets)
4. Collect global variables (live snapshot from the game while it runs, otherwise `GlobalVariableService`)
5. Record history for each row (int/float only)
6. Render the Local / Scope / Global sections (Local/Scope grouped, Global flat)
7. Render the static declarations section (topology cache refreshed every 5 seconds)
8. Update the bottom line chart
9. Update the status label (`Global:N  Unit:M  Ctn:K`)
```

---

## Stage 7 Features

### 7a — Double-Click Editing

Interactive rows (not notes, not static) support editing variable values by double-clicking:

| Scope | Editing | Write-back target |
|--------|----------|----------|
| **Local** | **Available while running** (scalar types) | `bridge.send_set_var("unit", id, name, value)` → applied by the running game (writes the host component's most recent execution context) |
| **Scope** | **Available while running** (scalar types) | `bridge.send_set_var("container", id, name, value)` → applied by the running game (writes the container variable) |
| **Global** | Always available, split by data source | While the game runs: `send_set_var("global", ...)` → running game (existing variables only); not running: editor-side definition via `set_variable_value_thread_safe` (metadata preserved; created only if missing) |

**Editable types**: JSON scalars only (`int` / `float` / `bool` / `String`). Non-scalar values arrive wrapped as `{"__complex": ..., "ty": "Vector2"}` — those rows are read-only (the value column shows the truncated string, the type column shows the real type name) and do not respond to double-clicks.

**Global data source while running**: while the game runs, the Global section title carries the "(Game)" suffix and the values come from the game process's live snapshot; once the game stops, the section falls back to the editor-side definitions.

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
| Complex types (`Vector2` etc.) | not editable (row is read-only), coercion never runs |

**Safety guards**:
- While editing, `_editing = true` and `_refresh()` skips rebuilding, so the LineEdit is not destroyed
- Local/Scope rows must come from the running game (the row is editable only when its target id can locate the host/container on the game side)
- A failed write-back (connection lost) restores the original displayed value and warns; a failed type coercion silently restores the original value (an input problem, no warning)

### 7b — Line Chart

Clicking any variable row selects it; the bottom line chart area shows its value history:

- **History window**: `HISTORY_MAX = 120` frames (60-second sliding window, `0.5s × 120 = 60s`)
- **Recording scope**: only `int` and `float` variables (other types are ignored automatically)
- **Storage key** (v3, keyed by host/container so same-named variables never collide): `local:<unit_path>/<name>`, `scope:<container_path>/<name>`, `global/<name>` (e.g. `"global/player_score"`)

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
    "containers": [
        {"id": 99001, "path": "/World/LevelScope", "scope_id": "level1",
         "vars": {"alert_level": {"value": 50, "type": "int"}}}
    ],
    "units": [
        {"id": 123456, "path": "/Main/Runner1", "kind": "runner", "ago_ms": 5,
         "local": {
            "health": {"value": 85, "type": "int"},
            "target_pos": {"value": "(120, 340)", "type": "Vector2"}
         }}
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

- **FuseRuntimeBridge**: an Autoload singleton that actively pushes variable caches while the game runs (v3: `containers` + `units` entries per host/container, plus the global scalars)
- **GlobalVariableService**: reads the editor-side global variable definitions from `GlobalVariableManager` when the game is not running; while the game runs, the live game-side snapshot (via `FuseRuntimeBridge`) is used instead
- **InstructionAnalyzer**: analyzes Trigger topology in the editor, providing static declaration data

---

## Troubleshooting

| Problem | Cause | Solution |
|------|------|----------|
| Blank panel | Scene not running or no Fuse nodes | Run the scene and make sure a Trigger/ActionRunner exists |
| Local/Scope not shown | `FuseRuntimeBridge` not registered | Check the Autoload configuration |
| Double-click edit does nothing | A running game is required | Local/Scope rows appear only while the scene runs (a host reports after its first execution); complex values (Vector2 etc., shown read-only) are not editable |
| Line chart has no data | Variable is not numeric | Only `int`/`float` variables are recorded in history |
| Snapshot save failed | Insufficient path permissions | Check permissions of the `user://` directory |
| Panel flickers while editing | 0.5s polling conflicts with editing | Protected by Stage 7a (the `_editing` flag blocks refresh rebuild) |

---

**Related docs:**
- [Debugging System Guide](25-debugging-guide.md)
- [Breakpoint Guide](26-breakpoint-guide.md)
- [Global Variables Management Guide](54-global-variables-guide.md)
- [Editor Panels Overview](00-editor-panels-overview.md)
