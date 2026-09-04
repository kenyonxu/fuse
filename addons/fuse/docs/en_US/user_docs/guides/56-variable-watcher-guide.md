> 🌐 [**中文版**](../../../zh_CN/user_docs/guides/56-variable-watcher-guide.md) | English

# Variable Watcher User Guide

`FuseVariableWatcher` is a **real-time variable monitoring panel** docked at the bottom of the Godot editor, showing the name, value, and type of every visible Fuse runtime variable at a 0.5-second polling rate. Variables are presented as a **scene → host → variable** three-level tree (GLOBAL as a sibling root), with double-click editing (write-back to the running game over the TCP bridge at runtime), search filtering, and a line chart that expands at the bottom when a numeric variable is selected.

**Related file:** `addons/fuse/editor/debugging/variable_watcher.gd`

---

## Feature Overview

| Feature | Description |
|------|------|
| Polling interval | 0.5 seconds (Timer driven, incremental updates without flicker) |
| Display layers | Scene → host → variable three-level tree; GLOBAL as a sibling root |
| Runtime data source | `FuseRuntimeBridge` (Autoload node push, protocol v3) |
| Global variable data source | While the game runs: live snapshot from the game process; otherwise `GlobalVariableService` |
| History | 120 frames = 60-second sliding window (numeric types only) |
| Search filter | Real-time filtering by scene name / host path / variable name (case-insensitive) |
| Line chart | Expands in the bottom area when a numeric variable is selected (resizable, ✕ to collapse) |

---

## Panel Layout

The variable watcher sits in the editor's bottom dock; its layout has a top bar, the variable tree, and a bottom chart area (the chart area stays collapsed and takes no space until a variable is selected):

```
+-----------------------------------------------------------+
| [Search variables...____]     场景:2 · 宿主:3 · Global:2 |
+-----------------------------------------------------------+
| ▾ Main                                                    |
|   ▾ /Main/Runner1 [Runner] · 0.3s                         |
|     health      | 85          | int                       |
|     target_pos  | (120, 340)  | Vector2                   |
|   ▾ /World/LevelScope (level1)                            |
|     alert_level | 50          | int                       |
| ▸ /root/Enemies/Guard [Trigger] · 6.2s   (stale host, gray) |
| ▾ GLOBAL                                                  |
|   player_score  | 2450        | int                       |
|   game_time     | 132.5       | float                     |
+-----------------------------------------------------------+
| group_path/name                                       [✕] |
| [=== Line chart area (expands on selection, resizable) ==] |
+-----------------------------------------------------------+
```

When not connected to a running game and there is no data, a centered gray hint **"Waiting for a running game…"** is overlaid on the tree.

### Top Bar

| Control | Description |
|------|------|
| Search box | Filters tree rows in real time (see below) |
| Status summary | A single line of gray text, e.g. `场景:2 · 宿主:3 · Global:2` (currently hardcoded labels meaning scene count / host count / global row count; the first two are post-filter counts and shrink while a filter is active) |

### Search Box

Filters tree rows in real time, matching **scene names / host paths / variable names** (case-insensitive). When a scene name or host path matches, the **whole group stays visible**; when only a variable name matches, only the matching rows show. Filter-set changes go through the same incremental update path and the collapsed state is preserved. An empty string shows everything.

### Variable Tree

Three-column layout: **Name** (wide) | **Value** (wide) | **Type** (narrow column). All visuals inherit the editor theme (light/dark adaptive, no hardcoded colors):

- **Scene roots / GLOBAL root**: bold; both levels (scenes, hosts) are collapsible and the collapsed state survives refreshes
- **Host rows**: containers first, components after; containers read `<path> (<scope_id>)`, components read `<path> [<Trigger|MultiEvent|Runner>] · <ago>`; hosts that have not reported for more than 5 seconds have their name column grayed out
- **Variable rows**: `__complex` values (Vector2 etc.) show a dimmed value column and are read-only

---

## Three-Level Tree Display

### 1. Scene Roots (scene grouping)

The first level consists of scene roots. Hosts are grouped by their node path: hosts under a `/root/<name>/...` prefix are grouped under the corresponding **extra scene** root, everything else goes under the **current scene** (the scene name comes from the `scene` field pushed by the running game; when the field is missing, hosts land in an unnamed group). Scene root labels carry a suffix marking their group: the current scene reads `<scene name> · 当前` and extra scenes read `<scene name> · 附加` (the current scene name comes from the bridge push, so the suffix follows scene switches).

### 2. Hosts (containers first, components after)

The second level lists hosts flat on one level, **containers first and components after**:

```
▾ /World/LevelScope (level1)        ← container (ScopeVariableContainer)
  alert_level   | 50       | int
▾ /Main/Runner1 [Runner] · 0.3s    ← component (BaseTrigger / MultiEventTrigger / Runner)
  health       | 85       | int
```

- **Containers**: show their declared (default) values, so even a subtree that has never been triggered shows its containers' values (depends on runtime push, via `FuseRuntimeBridge.get_cached_vars()`)
- **Components**: show the local variables reported from their **most recent execution context**, and appear only after their first execution (they have no execution context before that)

### 3. GLOBAL (Sibling Root)

`GLOBAL` is an independent root at the same level as scenes; process-level global variables hang directly beneath it, and its data source switches automatically depending on whether the game is running:

- **While the game runs**: shows the live scalar snapshot pushed by the game process (via `FuseRuntimeBridge`)
- **Not running**: reads the editor-side definitions via `GlobalVariableService.get_all_global_variables_info()`

```
GLOBAL
  player_score | 2450  | int
  game_time    | 132.5 | float
```

Global variables are **persistent** — they survive scene changes, making them suitable for cross-scene debugging.

---

## Polling Mechanism

A `Timer` drives the panel's 0.5-second refresh loop:

```gdscript
_timer.wait_time = 0.5
_timer.autostart = true
_timer.timeout.connect(_refresh)
```

Each refresh (`_refresh()`) runs the following steps:

```
1. Collect local + scope rows from the bridge cache (_rows_from_cached,
   v3 row dictionaries + the scene grouping field)
2. Collect global variables (live snapshot from the game while it runs,
   otherwise GlobalVariableService)
3. Record numeric history (int/float only)
4. _tree.apply_data(): three-level incremental diff (only changed rows are
   added/removed/updated; selection and collapsed state survive)
5. _tree.apply_global(): refresh the GLOBAL root (must follow apply_data every tick)
6. Update the status summary (场景:N · 宿主:M · Global:K)
7. Show the "Waiting for a running game…" empty state when disconnected and empty
```

---

## Double-Click Editing

Editable variable rows support value editing by double-clicking; the write-back semantics and data source split are unchanged:

| Scope | Editing | Write-back target |
|--------|----------|----------|
| **Local** | **Available while running** (scalar types) | `bridge.send_set_var("unit", id, name, value)` → applied by the running game (writes the host component's most recent execution context) |
| **Scope** | **Available while running** (scalar types) | `bridge.send_set_var("container", id, name, value)` → applied by the running game (writes the container variable) |
| **Global** | Always available, split by data source | While the game runs: `send_set_var("global", ...)` → running game (existing variables only); not running: editor-side definition via `set_variable_value_thread_safe` (metadata preserved; created only if missing) |

**Editable types**: JSON scalars only (`int` / `float` / `bool` / `String`). Non-scalar values arrive wrapped as `{"__complex": ..., "ty": "Vector2"}` — those rows show a dimmed, read-only value column and do not respond to double-clicks.

**How to operate**:
1. Double-click an editable row → a `LineEdit` overlay pops up over the value cell
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
- The edit overlay is independent of the tree rows: tree text keeps updating during refreshes with no need to freeze anything, and the next refresh after committing shows the real value
- Local/Scope rows must come from the running game (the row is editable only when its target id can locate the host/container on the game side)
- A failed write-back (connection lost) warns (`FUSE_UI_WATCHER_EDIT_NO_CONNECTION`); a failed type coercion silently aborts the write-back (an input problem, no warning)

---

## Line Chart (Expands on Selection)

Click to select any numeric variable row and the bottom chart area expands automatically, drawing its value history:

- Switching selection switches the curve; click **✕** in the chart title row, press **Esc**, or clear the selection to collapse the area; drag the splitter to resize it (100px by default)
- **History window**: `HISTORY_MAX = 120` frames (60-second sliding window, `0.5s × 120 = 60s`)
- **Recording scope**: only `int` and `float` variables (other types are ignored automatically)
- **Storage key** (v3, keyed by host/container so same-named variables never collide): `local:<unit_path>/<name>`, `scope:<container_path>/<name>`, `global/<name>` (e.g. `"global/player_score"`)

**HistoryGraph component**:
- Nested class `HistoryGraph extends Control`
- Drawing logic: values are normalized to `[0, 1]` to draw the line, using the editor theme's accent color
- With no data, a gray placeholder text `(no numeric history)` is shown
- Switches display automatically when a new variable is selected

```
# Selected "global/player_score"
# The line chart shows the score trend over the last 60 seconds
  ▁▂▃▅▇▆▅▄▃▂▁▂▃▄▅▆▇▆▅▄▃▂▁
  ↑                          ↑
  min=2100               max=2600
```

---

## Data Source Architecture

```
┌─────────────────────────────────────────────┐
│          FuseVariableWatcher (Dock)          │
│                                              │
│  ┌──────────────┐   ┌───────────────────┐   │
│  │ 0.5s Timer    │   │ GlobalVariableSvc │   │
│  └──────┬───────┘   └────────┬──────────┘   │
│         ▼                     │              │
│  ┌──────────────┐             │              │
│  │ _refresh()   │             │              │
│  └──────┬───────┘             │              │
│         ▼                     ▼              │
│  ┌───────────────────────────────────┐       │
│  │ FuseVariableWatcherTree (3-level)  │       │
│  └──────────────┬────────────────────┘       │
│                 ▼                            │
│    FuseRuntimeBridge (Autoload)              │
└─────────────────────────────────────────────┘
```

- **FuseRuntimeBridge**: an Autoload singleton that actively pushes variable caches while the game runs (v3: `containers` + `units` entries per host/container, the current scene name in the `scene` field, plus the global scalars)
- **GlobalVariableService**: reads the editor-side global variable definitions from `GlobalVariableManager` when the game is not running; while the game runs, the live game-side snapshot (via `FuseRuntimeBridge`) is used instead

---

## Troubleshooting

| Problem | Cause | Solution |
|------|------|----------|
| Panel shows "Waiting for a running game…" | Not connected to a running game and no data | Run the scene and make sure a Trigger/ActionRunner/ScopeVariableContainer exists |
| No scenes/hosts in the tree | `FuseRuntimeBridge` not registered | Check the Autoload configuration |
| Double-click edit does nothing | A running game is required, or the value is not a scalar | Local/Scope rows appear only while the scene runs (a host reports after its first execution); complex values (Vector2 etc., dimmed read-only) are not editable |
| Line chart has no data | Variable is not numeric | Only `int`/`float` variables are recorded in history |
| Extra scenes are not grouped separately | The push lacks the `scene` field | Scene grouping depends on the `scene` field reported by the running game; when missing, hosts land in an unnamed group |

---

**Related docs:**
- [Debugging System Guide](25-debugging-guide.md)
- [Breakpoint Guide](26-breakpoint-guide.md)
- [Global Variables Management Guide](54-global-variables-guide.md)
- [Editor Panels Overview](00-editor-panels-overview.md)
