> 🌐 [**中文版**](../../../zh_CN/dev_docs/guides/58-variable-watcher-dev-guide.md) | English

# Variable Watcher Development Guide

> **Goal**: Provide developers with an architecture description and extension guide for `FuseVariableWatcher`, covering data source integration, the polling refresh mechanism, the Tree presentation layer (three-level incremental diff / collapse persistence / filter-set rebuild / edit positioning), and the implementation details and performance design of double-click editing and the line graph.

**Audience**: Fuse system developers, editor plugin contributors

**Last updated**: 2026-09-04

**Companion user doc**: [56-variable-watcher-guide.md](../../user_docs/guides/56-variable-watcher-guide.md)

---

## 📋 Table of Contents

1. [System Architecture Overview](#system-architecture-overview)
2. [Data Source Integration](#data-source-integration)
3. [Polling and Refresh Mechanism](#polling-and-refresh-mechanism)
4. [Tree Presentation Layer (FuseVariableWatcherTree)](#tree-presentation-layer-fusevariablewatchertree)
5. [Stage 7a — Double-Click Editing](#stage-7a--double-click-editing)
6. [Stage 7b — History Line Graph](#stage-7b--history-line-graph)
7. [Extension Guide](#extension-guide)
8. [Performance Design](#performance-design)
9. [Common Pitfalls](#common-pitfalls)

---

## System Architecture Overview

`FuseVariableWatcher` (`editor/debugging/variable_watcher.gd`) is a real-time variable monitoring panel docked at the bottom of the editor. It `extends Control` and is created by `plugin.gd` when the plugin is activated. The presentation layer is split into a standalone component, `FuseVariableWatcherTree` (`editor/debugging/variable_watcher_tree.gd`, `extends Tree`):

```gdscript
# addons/fuse/plugin.gd
var _watcher: FuseVariableWatcher = null

func _enter_tree() -> void:
	_watcher = preload("res://addons/fuse/editor/debugging/variable_watcher.gd").new()
	add_control_to_bottom_panel(_watcher, "Fuse Variables")

func _exit_tree() -> void:
	if _watcher:
		remove_control_from_bottom_panel(_watcher)
		_watcher = null
```

The main file is layered by responsibility:

| Layer | Responsibilities |
|----|------|
| Data layer (pure functions, test-covered) | Bridge reads, `_rows_from_cached`, `_make_var_row`, `_is_row_editable`, `_passes_filter`, `_history_key`, `_coerce_value`, `_finish_edit` dispatch, `_write_back_global` |
| Presentation layer | `FuseVariableWatcherTree` (three-level tree), top bar (search + status summary), bottom chart area (expands on selection), empty-state overlay |

### Data Source Architecture

The watcher itself **never accesses the running game scene directly**; instead it obtains variables indirectly through two data sources:

```
┌───────────────────────────────────────────────────────┐
│             FuseVariableWatcher (Bottom Dock)          │
│                                                        │
│  0.5s Timer ──→ _refresh() ──┬── apply_data() (3-level tree) │
│                              └── apply_global() (GLOBAL root) │
└──────┬───────────────────────────────┬─────────────────┘
       │                               │
       ▼                               ▼
 FuseRuntimeBridge              GlobalVariableService
 (Autoload, TCP)                (→ Manager singleton)
       │ ▲
       │ └── set_var (editor → game write-back, target = container/unit/global)
       ▼
 Running game (TCP client, pushes a JSON line every 0.5s, applies set_var)
   ├─ BaseTrigger / Runner → "units" (local from the most recent execution context)
   ├─ ScopeVariableContainer → "containers"
   └─ GlobalVariableManager → "global" (scalars)
```

| Data source | Provides | Available when |
|--------|----------|----------|
| `FuseRuntimeBridge` | v3 snapshots: `units` (BaseTrigger/MultiEventTrigger/Runner local vars, host-direct reporting) + `containers` (ScopeVariableContainer vars) + `scene` (current scene name) | While the scene is running |
| `GlobalVariableService` | Global variable names/values/types | Always available (while the game runs, the live game-side snapshot is used instead) |

---

## Data Source Integration

### FuseRuntimeBridge (TCP Bridge)

`FuseRuntimeBridge` (`core/fuse_runtime_bridge.gd`, `extends Node`, Autoload) is a **dual-mode** TCP bridge:

| Mode | Side | Behavior |
|------|--------|------|
| TCPServer | Editor | Listens on `127.0.0.1:24563`, receives pushes, caches into `_cached` |
| TCP client | Running game | Connects to `127.0.0.1:24563`, collects and pushes a snapshot every 0.5s |

**Key constants**:

```gdscript
const BRIDGE_PORT := 24563
const PUSH_INTERVAL := 0.5
```

**Protocol (v3, `proto = 3`)**: TCP stream + JSON line (`\n` separated):

```json
{"t":"vars","proto":3,
 "scene":"Main",
 "containers":[{"id":99001,"path":"/World/LevelScope","scope_id":"level1","vars":{"alert":50}}],
 "units":[{"id":123456,"path":"/Main/Runner1","kind":"runner","ago_ms":5,"local":{"health":85}}],
 "global":{"score":2450}}
```

`scene` is the game side's current scene name (empty string by default), used by the Tree layer for scene grouping. Non-scalar values are wrapped read-only as `{"__complex":"str(v) ≤200 chars","ty":"Vector2"}`. See the [Runtime Bridge Development Guide](runtime-bridge-guide.md) for the full field table and write-back semantics.

**Watcher consumption interface**:

```gdscript
## Editor side: get the cached runtime variables (v3 two-key structure)
## Returns {"containers": [container entries...], "units": [unit entries...]}
func get_cached_vars() -> Dictionary
```

The watcher reads this cache in `_refresh()` and converts it into row data via `_rows_from_cached()`.

### GlobalVariableService

The global variables section is read through the service layer (not by accessing the Manager directly):

```gdscript
var service := GlobalVariableService.new()
var info: Dictionary = service.get_all_global_variables_info()
# → {name: {"value": ..., "type": "int", ...}, ...}
```

See [59-global-variables-dev-guide.md](59-global-variables-dev-guide.md) for service layer details.

---

## Polling and Refresh Mechanism

The panel is driven by a 0.5-second `Timer`:

```gdscript
_timer.wait_time = 0.5
_timer.autostart = true
_timer.timeout.connect(_refresh)
```

### `_refresh()` Execution Flow

```
1. Collect local + scope rows from the bridge cache (_rows_from_cached;
   v3 keys: "units" → local rows grouped by host,
   "containers" → scope rows grouped by container;
   missing fields degrade to empty sets)
2. Collect global rows (bridge connected → get_cached_global() live game-side
   snapshot; otherwise GlobalVariableService editor-side definitions)
3. _record_history() records numeric history (int/float only, keyed via _history_key)
4. _tree.apply_data(rows, scene_name, filter_text)
   ← three-level incremental diff, returns the summary {scenes, hosts, global}
5. _tree.apply_global(global_rows, filter_text)
   ← refresh the GLOBAL root (must follow apply_data every tick; do not reorder)
6. Update the status summary (场景:N · 宿主:M · Global:K)
7. Disconnected and empty row set → show the "Waiting for a running game…" overlay
```

> **Design note**: every tick produces the v3 row dictionaries and hands them to the Tree layer for an **incremental diff** (only changed items are added/removed/updated — no flicker, and selection/collapsed state survive). Search input changes follow the same path (a filter-set change simply diffs into adds/removals). The edit overlay is independent of the tree rows, so refreshes never need to freeze.

---

## Tree Presentation Layer (FuseVariableWatcherTree)

`FuseVariableWatcherTree` (`editor/debugging/variable_watcher_tree.gd`, same-named `class_name`, `extends Tree`) carries the entire tree display with three columns: Name (EXPAND_FILL) / Value (EXPAND_FILL, min 120px) / Type (fixed ~86px narrow column). All visuals inherit the editor theme (zero hardcoded colors, zero font-size overrides; except inside HistoryGraph).

### Tree Structure (three levels + sibling root)

- **Level 1 = scene roots** (bold): hosts are grouped by node path — a `/root/<name>/...` prefix groups under the corresponding extra scene (the `scene_of()` static pure function), everything else under the current scene (name from the pushed `scene` field, missing field → unnamed group)
- **Level 2 = hosts** (flat on one level): **containers first, components after** (order preserved in `_build_targets`). Container rows read `<path> (<scope_id>)`; component rows read `<path> [<Trigger|MultiEvent|Runner>] · <ago>`; `ago_ms > 5000` (`STALE_MS`) grays the whole row with the theme disabled color
- **Level 3 = variable rows**: each host's vars/local; `__complex` rows show a dimmed value column (read-only marker)
- **`GLOBAL` is an independent root at the same level as scenes** (internal key `"__global__"`); process-level variables hang directly beneath it

Item metadata: variable rows carry the v3 row dictionary (`target`/`id`/`name`/`type`/`is_complex`/`group_key`/`group_path`); group rows carry `{"collapse_key": ...}`.

### Stable Keys and Incremental Diff

| Level | Stable key |
|------|--------|
| Scene root | `s:<scene name>` (collapse key; GLOBAL is `s:__global__`) |
| Host | `c<id>` / `u<id>` |
| Variable row | `target:id:name` |

`diff_plan(old_keys, new_keys)` is a pure function (headless-testable) returning `{add: [...], remove: [...]}`; `apply_data()` executes the plan level by level: new keys `create_item` under the right parent, vanished keys `free()` their subtree, existing keys only refresh the text and dimming of changed columns.

### Collapse Persistence

Under incremental updates items stay alive, so the Tree's own collapsed state is naturally preserved; when an item is rebuilt (a host/scene disappears and reappears) the `_collapsed` member dictionary restores it, keyed `s:<scene name>` / `c<id>` / `u<id>` (written back by the `item_collapsed` signal).

### Filtering (Filter-Set Rebuild)

Filtering matches **scene names / host paths / variable names + values** (`_passes_filter`, case-insensitive containment). A scene name or host path hit → the whole group stays visible; groups that match nothing are not built at all. Filter-set changes manifest as target key-set changes and follow the same diff path ("rebuild the visible tree from the filter set"), with the collapsed state preserved via `_collapsed`.

### GLOBAL Root Contract

`apply_data()` and `apply_global(global_rows, filter_text)` must be called as a pair, in this order, every tick — the GLOBAL root is created inside `apply_data()` while its rows are mounted inside `apply_global()` (the main file has a comment anchor; do not reorder). `apply_global()` rebuilds all global rows from scratch (few rows and no stable ids) and also runs `_check_selection_stale()`.

### Selection and Edit Positioning

- Signal `variable_selected(row, selected)`: emitted when a variable row is selected (`selected=false` means deselected); `variable_activated(row)`: emitted when an editable row is double-clicked (an edit request)
- **Tree has no `item_deselected` signal** — when the selected row is removed by the diff, `_check_selection_stale()` detects the missing `_row_meta` key and emits the deselection event (the main file collapses the chart area in response)
- `value_cell_screen_rect()`: the selected row's value-cell rect on screen (converted via `get_item_area_rect`), used by the main file to position the `LineEdit` edit overlay over the value cell

---

## Stage 7a — Double-Click Editing

### Interaction Flow

```
Double-click a variable row → Tree item_activated → variable_activated(row)
    ↓ main file _on_variable_activated(): _is_row_editable(row) gate
LineEdit overlay positioned at value_cell_screen_rect() (the value cell's screen rect)
    ↓ typing (tree refreshes continue; the edit overlay is independent of the rows, nothing freezes)
Enter commits / blur commits → _finish_edit(text, row)
    ↓
_coerce_value(text, type_str)     ← type coercion (returns null on failure, aborting the write-back)
    ↓
Write back, dispatched on target → dispose of the overlay → _refresh() shows the real value
```

### Write-Back Targets (v3, by `target`)

| Target | Write-back | Available when |
|--------|----------|----------|
| `unit` | `bridge.send_set_var("unit", id, name, value)` → applied by the running game (writes the host component's most recent execution context) | At runtime (row comes from the running game, `id` locatable) |
| `container` | `bridge.send_set_var("container", id, name, value)` → applied by the running game (writes the container variable) | At runtime (same requirement) |
| `global` | Game connected: `send_set_var("global", 0, name, value)` (existing variables only); otherwise `_write_back_global()` → `set_variable_value_thread_safe()` (metadata preserved; created only if missing) | Always available |

### Type Coercion (`_coerce_value`)

| Target type | Rule |
|----------|------|
| `int` | `text.is_valid_int()` → `to_int()` |
| `float` | `text.is_valid_float()` → `to_float()` |
| `bool` | Matches `"true"` / `"1"` / `"是"` / `"yes"` |
| `String` | Returned as-is |
| Others | Best effort, returned as-is |

**Return value convention**: returning `null` means the coercion failed, and the caller **must abort the write-back** (leaving the original value untouched).

### Editability Gate (`_is_row_editable`)

All three must hold: not `__complex`, type in `EDITABLE_TYPES` (JSON scalars), and a valid `target` (`container`/`unit`/`global`). The Tree layer emits `variable_activated` for any double-clicked row; the gate lives in the main file.

---

## Stage 7b — History Line Graph

### History Recording

```gdscript
const HISTORY_MAX := 120  # 60s / 0.5s = 120-frame sliding window

var _history: Dictionary = {}   # var_key → Array[float]
var _selected_key := ""
```

Rules for `_record_history(var_key, value, type_str)`:

- Only records `int` / `float` (other types are ignored)
- Key scheme (v3, shared by `_record_history` and row selection via `_history_key`): `local:<unit_path>/<name>`, `scope:<container_path>/<name>`, `global/<name>` (e.g. `"global/player_score"`)
- Pops the oldest frame once `HISTORY_MAX` is exceeded

### Chart Expands on Selection

- Tree `variable_selected(row, true)` → the main file stores `_selected_key = _history_key(row)`, expands `_graph_panel` (VSplitContainer bottom, 100px by default, resizable), title `group_path/name`
- Switching selection switches the curve; `variable_selected(row, false)` (including the `_check_selection_stale` re-emission) or clicking ✕ in the title row collapses the area
- With no data / a non-numeric selection, `_graph.set_points([])` shows the placeholder text

### HistoryGraph Component

```gdscript
class HistoryGraph extends Control:
	# Nested class, drawing logic:
	# 1. Take _history[_selected_key]
	# 2. Normalize to the [0, 1] range
	# 3. draw_line() draws the polyline (theme accent color, pale blue fallback if lookup fails)
	# 4. With no data, shows gray placeholder text "(无数值历史)"
```

---

## Extension Guide

### Row Data Structure

The Dictionary produced by `_make_var_row()` is the unified data carrier for rendering and editing. Core keys:

| Key | Description |
|----|------|
| `name` | Variable name |
| `value` | Displayed value (stringified) |
| `type` | Type string (`int`/`float`/`Vector2`/...) |
| `is_complex` | `__complex` read-only wrapper marker (the Tree layer dims the value column based on it) |
| `target` / `id` | v3 write-back target (`container`/`unit`/`global`) and the host/container instance id |
| `group_key` / `group_path` | Owning host group (`u<id>` / `c<id>`) and its display path (tree grouping + filtering) |

When adding a new editable type, add a coercion branch in `_coerce_value()` and register the type in `EDITABLE_TYPES`.

### Integrating a New Runtime Data Source

1. Extend the JSON payload of `FuseRuntimeBridge._push_snapshot()` on the game side
2. Extend the cache structure of `_update_cache()` on the editor side
3. Read the new fields in `_rows_from_cached()` and generate rows/groups

> **Note**: the Bridge protocol is a JSON line, so new fields are backward compatible (older parsers ignore unknown keys).

---

## Performance Design

| Mechanism | Overhead control |
|------|----------|
| 0.5s polling | Avoids per-frame refreshes; matches the Bridge push interval (0.5s), so half-updated states are never read |
| Incremental diff | Only changed TreeItems are added/removed/updated (`diff_plan` pure function) — no full-rebuild flicker, and selection/collapsed state survive naturally |
| Filter-set rebuild | Filtering does not change data collection; it only alters the target key set and follows the same diff path |
| Numeric-only history | Only `int`/`float` enter `_history`; String/Vector etc. cost nothing |
| Fixed-length history window | `HISTORY_MAX = 120`; frames are popped beyond that, keeping memory constant |

**Known overhead points** (watch out when extending):

- `_apply_complex_color()` walks every existing variable row each tick — with very large row counts, move it to targeted refreshes inside the diff phase
- `apply_global()` rebuilds all global rows from scratch — acceptable while the row count is small; switch to incremental if global variables ever balloon

---

## Common Pitfalls

### Pitfall 1: The Game May Have Exited by the Time the Edit Commits

**Problem**: Rows are rendered from the last pushed snapshot, so the game may exit between rendering a row and committing the edit. `send_set_var` returns `false` when there is no live connection, and the value never reaches the game.

**Solution**: Treat a `false` return as a failed write-back — warn (`FUSE_UI_WATCHER_EDIT_NO_CONNECTION`) and close the edit overlay; the next refresh after committing naturally corrects the display to the authoritative game-side value. (A failed coercion in `_coerce_value` still aborts the write-back silently — that is an input problem, not a connection problem.)

### Pitfall 2: Accessing GlobalVariableManager Directly and Bypassing the Service Layer

**Problem**: The panel calls `GlobalVariableManager.get_instance()` directly in places, falling out of sync with the Assistant signal flow.

**Solution**: Reads go through `GlobalVariableService.get_all_global_variables_info()`; write-backs go through the unified `_write_back_global()` entry point.

### Pitfall 3: History Keys Without the Scope

**Problem**: Same-named variables in different scopes share one history curve, polluting each other's data.

**Solution**: Keys must use the v3 scheme — `local:<unit_path>/<name>`, `scope:<container_path>/<name>`, `global/<name>` (as already required by `_history_key`, shared by `_record_history` and row selection; both ends must use the same scheme or the graph silently breaks).

### Pitfall 4: Bridge Push and Polling Frequencies Out of Sync

**Problem**: After changing `PUSH_INTERVAL`, the watcher still assumes 0.5s (so the history window duration is misaligned).

**Solution**: The history window semantics are `HISTORY_MAX × PUSH_INTERVAL = displayed seconds`; when changing the frequency, adjust the comments and documentation accordingly.

### Pitfall 5: Fake String Rows from Object Values (v2 legacy — eliminated)

**Problem**: v2 serialized `Object` values into bare strings in the push, so the editor could not tell them from real `String` rows and could offer editing on non-editable values.

**Solution**: The v3 protocol wraps non-scalars read-only as `{"__complex": "str(v) ≤200 chars", "ty": "Vector2"}` — the root cause is eliminated at the protocol layer (the type column shows the real type name, rows are not editable). The game-side non-scalar gate remains as the last line of defense for hand-crafted messages.

### Pitfall 6: Local Rows Disappearing Right After a Run (design note)

**Problem**: In earlier designs the execution context was discarded as soon as a run finished ("fire-and-forget"), so there was nothing to report after a Trigger/Runner completed.

**Solution**: v3 keeps the **most recent** execution context instead: BaseTrigger (`_create_execution_context`), MultiEventTrigger and Runner all assign `current_execution_context` / `current_execution_context_at_ms`, so units report their last-run locals and the `ago_ms` freshness field lets the Tree layer gray out stale hosts (> 5s).

### Pitfall 7: Collapsed State Lost Across Refreshes

**Problem**: If the presentation layer rebuilds the tree every tick, a group collapsed by the user pops open again on the next frame.

**Solution**: Under incremental diff the items stay alive, so the Tree's own collapsed state is naturally preserved; only when an item is rebuilt (a host/scene disappears and reappears) is it restored from the `_collapsed` dictionary, keyed `s:<scene name>` / `c<id>` / `u<id>` (written back by the `item_collapsed` signal) — no dependence on pre-rebuild control references. Search filtering does not touch the collapse dictionary — the filter-set rebuild reuses the same collapsed state.

### Pitfall 8: Tree Has No item_deselected Signal — Re-emit Stale Selection Manually

**Problem**: When the selected row is removed by the diff (host/variable vanished, filter hit-set changed), the Tree emits no deselection event; if the main file keeps using the old selection key to look up history/graph data, it gets the residual curve of a variable that no longer exists.

**Solution**: The Tree layer maintains the `_row_meta` key index and runs `_check_selection_stale()` at the end of every `apply_data()` / `apply_global()` — if `_selected_key` is missing from the index, it is cleared and `variable_selected({}, false)` is re-emitted, and the main file collapses the chart area in response.

---

## Summary

Key points of variable watcher development:

1. ✅ **Data/presentation layer separation** — the main file keeps the pure-function data layer (bridge reads/row generation/edit dispatch, test-covered); the presentation layer is `FuseVariableWatcherTree`
2. ✅ **Dual-mode TCP bridge** — editor TCPServer / game client, JSON line protocol, 0.5s pushes (v3: `containers` + `units` + `scene` + `global`)
3. ✅ **Three-level tree + sibling root** — scene roots (`s:<scene>`, `/root/<name>` prefix groups extra scenes) → hosts (`c<id>`/`u<id>`, containers first components after) → variable rows (`target:id:name`); GLOBAL as an independent sibling root
4. ✅ **Incremental diff** — the `diff_plan` pure function produces the add/remove plan and the Tree layer only executes it; collapsed state survives naturally + `_collapsed` restores rebuilt items; filter-set changes follow the same path
5. ✅ **Edit protection, new form** — the edit overlay is independent of the tree rows, nothing freezes; `_coerce_value` returning null aborts the write-back; editability is gated by `_is_row_editable`
6. ✅ **Selection wiring** — selecting expands the line graph; Tree has no `item_deselected`, so stale selection is re-emitted via `_check_selection_stale`
7. ✅ **apply_global contract** — must follow `apply_data()` every tick; the GLOBAL root depends on this order

**Reference documents**:
- [Variable Watcher User Guide](../../user_docs/guides/56-variable-watcher-guide.md)
- [Global Variables Development Guide](59-global-variables-dev-guide.md)
- [Runtime Bridge Development Guide](runtime-bridge-guide.md)
- [Debugging System User Guide](../../user_docs/guides/25-debugging-guide.md)

---

**Document maintainer**: Fuse development team
**Last updated**: 2026-09-04
