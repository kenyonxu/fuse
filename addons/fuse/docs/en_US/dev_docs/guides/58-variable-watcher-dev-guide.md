> 🌐 [**中文版**](../../../zh_CN/dev_docs/guides/58-variable-watcher-dev-guide.md) | English

# Variable Watcher Development Guide

> **Goal**: Provide developers with an architecture description and extension guide for `FuseVariableWatcher`, covering data source integration, the polling refresh mechanism, the UI construction pattern, and the implementation details and performance design of the Stage 7 features (double-click editing / line graph / static declarations / snapshots).

**Audience**: Fuse system developers, editor plugin contributors

**Last updated**: 2026-09-04

**Companion user doc**: [56-variable-watcher-guide.md](../../user_docs/guides/56-variable-watcher-guide.md)

---

## 📋 Table of Contents

1. [System Architecture Overview](#system-architecture-overview)
2. [Data Source Integration](#data-source-integration)
3. [Polling and Refresh Mechanism](#polling-and-refresh-mechanism)
4. [UI Construction Pattern](#ui-construction-pattern)
5. [Stage 7a — Double-Click Editing](#stage-7a--double-click-editing)
6. [Stage 7b — History Line Graph](#stage-7b--history-line-graph)
7. [Stage 7c — Static Declaration Section](#stage-7c--static-declaration-section)
8. [Stage 7d — Snapshot Export](#stage-7d--snapshot-export)
9. [WatcherUI Extension Guide](#watcherui-extension-guide)
10. [Performance Design](#performance-design)
11. [Common Pitfalls](#common-pitfalls)

---

## System Architecture Overview

`FuseVariableWatcher` (`editor/debugging/variable_watcher.gd`) is a real-time variable monitoring panel docked at the bottom of the editor. It `extends Control` and is created by `plugin.gd` when the plugin is activated:

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

### Data Source Architecture

The watcher itself **never accesses the running game scene directly**; instead it obtains variables indirectly through three data sources:

```
┌───────────────────────────────────────────────────────┐
│             FuseVariableWatcher (Bottom Dock)          │
│                                                        │
│  0.5s Timer ──→ _refresh() ──┬── Local/Scope section   │
│                              ├── Global section        │
│                              └── Static declaration section (5s cache) │
└──────┬────────────────┬────────────────┬──────────────┘
       │                │                │
       ▼                ▼                ▼
 FuseRuntimeBridge  GlobalVariableService  InstructionAnalyzer
 (Autoload, TCP)    (→ Manager singleton)  (editor static topology)
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
| `FuseRuntimeBridge` | v3 snapshots: `units` (BaseTrigger/MultiEventTrigger/Runner local vars, host-direct reporting) + `containers` (ScopeVariableContainer vars) | While the scene is running |
| `GlobalVariableService` | Global variable names/values/types | Always available |
| `InstructionAnalyzer` | Variable declarations in Trigger instruction chains (static) | Editor mode |

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
 "containers":[{"id":99001,"path":"/World/LevelScope","scope_id":"level1","vars":{"alert":50}}],
 "units":[{"id":123456,"path":"/Main/Runner1","kind":"runner","ago_ms":5,"local":{"health":85}}],
 "global":{"score":2450}}
```

Non-scalar values are wrapped read-only as `{"__complex":"str(v) ≤200 chars","ty":"Vector2"}`. See the [Runtime Bridge Development Guide](runtime-bridge-guide.md) for the full field table and write-back semantics.

**Watcher consumption interface**:

```gdscript
## Editor side: get the cached runtime variables (v3 two-key structure)
## Returns {"containers": [container entries...], "units": [unit entries...]}
func get_cached_vars() -> Dictionary
```

The watcher calls this method inside `_collect_runtime_variables()`, converting the cache into row data.

### GlobalVariableService

The global variables section is read through the service layer (not by accessing the Manager directly):

```gdscript
var service := GlobalVariableService.new()
var info: Dictionary = service.get_all_global_variables_info()
# → {name: {"value": ..., "type": "int", ...}, ...}
```

See [59-global-variables-dev-guide.md](59-global-variables-dev-guide.md) for service layer details.

### InstructionAnalyzer (Static Declarations)

In editor mode it scans the scene's Trigger topology and aggregates variable declarations (name/scope/read-write mode/number of reference sites). This scan is expensive and therefore runs on a **separate 5-second cache** (see below).

---

## Polling and Refresh Mechanism

The panel is driven by a 0.5-second `Timer`:

```gdscript
_timer.wait_time = 0.5
_timer.autostart = true
_timer.timeout.connect(_on_timer)

func _on_timer() -> void:
	_refresh()
```

### `_refresh()` Execution Flow

```
1. if _editing: return                    ← skip everything while editing (protects the LineEdit)
2. Clear _content (VBoxContainer)
3. _collect_runtime_variables()           ← Local + Scope rows from the Bridge cache
                                             (v3 keys: "units" → Local grouped by host,
                                              "containers" → Scope grouped by container;
                                              missing fields degrade to empty sets)
4. GlobalVariableService collects global variables
5. _record_history() records numeric history (int/float only)
6. _render_grouped_section() × 2 + flat render ← Local / Scope grouped, Global flat
7. _render_static_declarations()          ← static section (cached at 5s intervals)
8. _update_history_graph()                ← refresh the bottom line graph
9. Update the status label (Global:N  Unit:M  Ctn:K)
```

> **Design note**: UI rows are **fully rebuilt** on every tick (simple and reliable), with the `_editing` flag preventing destruction of controls being edited. At row counts in the tens to hundreds this strategy performs acceptably.

---

## UI Construction Pattern

All watcher UI is built in code (no `.tscn`), following the **row data Dictionary → row control** pattern.

### Color Constants

```gdscript
const COL_NAME := Color(0.1, 0.15, 0.3)    # Dark blue — variable name
const COL_VALUE := Color(0.1, 0.25, 0.15)  # Dark green — value
const COL_TYPE := Color(0.15, 0.15, 0.15)  # Light black — type
const COL_HEADER := Color(0.2, 0.3, 0.5)   # Section header blue
```

### Builder Function Layers

| Function | Responsibility |
|------|------|
| `_make_header_row()` | Three-column header row (variable ∥ value ∥ type) |
| `_make_section_header(title)` | Section header (Local/Scope/Global/static) |
| `_make_row_data(var_name, data, extra)` | Build the row data Dictionary |
| `_make_data_row(data)` | Row data → HBoxContainer control |
| `_make_value_panel(data)` | Value column (a PanelContainer supporting double-click editing) |
| `_make_label_panel(text, color, pass_mouse)` | Plain text column |
| `_render_section(parent, title, rows, filter, ...)` | Render an entire section (including search filtering) |

### Row Data Structure

The Dictionary produced by `_make_row_data()` is the unified data carrier for rendering and editing. Core keys:

| Key | Description |
|----|------|
| `name` | Variable name |
| `value` | Displayed value (stringified) |
| `type` | Type string (`int`/`float`/`Vector2`/...) |
| `scope` | Scope identifier (`local`/`scope`/`global`) |
| `target` / `id` | v3 write-back target (`container`/`unit`/`global`) and the host/container instance id |
| `group_key` / `group_path` | Owning group (`u<id>` / `c<id>` / `global`) and its display path (group headers + filtering) |
| `var_key` | History record key (v3 scheme): `local:<unit_path>/<name>`, `scope:<container_path>/<name>`, `global/<name>` |

> **Extension note**: when adding a new section, reuse `_make_row_data()` + `_render_section()` and pass section-specific keys in `extra` (e.g. the group path, whether it is editable).

---

## Stage 7a — Double-Click Editing

### Interaction Flow

```
Double-click the value column → _on_value_gui_input() → _enter_edit_mode()
    ↓ Label replaced by a LineEdit, _editing = true
Enter submits → _on_value_submitted() ┐
Focus loss submits → _on_focus_exited()     ┴→ _finish_edit()
    ↓
_coerce_value(text, type_str)     ← type coercion (returns null on failure, aborting the write-back)
    ↓
Write back by scope → _restore_label()  ← restore the Label, _editing = false
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

### Edit Protection

```gdscript
var _editing: bool = false  # Editing flag

func _refresh() -> void:
	if _editing:
		return  # Skip the rebuild to avoid destroying the LineEdit
```

---

## Stage 7b — History Line Graph

### History Recording

```gdscript
const HISTORY_MAX := 120  # 60s / 0.5s = 120-frame sliding window

var _history: Dictionary = {}   # var_key → Array[float]
var _selected_var_key: String = ""
```

Rules for `_record_history(var_key, value, type_str)`:

- Only records `int` / `float` (other types are ignored)
- Key scheme (v3, shared by `_record_history` and row selection via `_history_key`): `local:<unit_path>/<name>`, `scope:<container_path>/<name>`, `global/<name>` (e.g. `"global/player_score"`)
- Pops the oldest frame once `HISTORY_MAX` is exceeded

### HistoryGraph Component

```gdscript
class HistoryGraph extends Control:
	# Nested class, drawing logic:
	# 1. Take _history[_selected_var_key]
	# 2. Normalize to the [0, 1] range
	# 3. draw_polyline() draws the polyline (light blue 0.4, 0.8, 1.0)
	# 4. With no data, draws gray placeholder text "(No numeric history)"
```

Row selection is implemented via `_on_row_gui_input()`: clicking a row sets `_selected_var_key`, then `_update_history_graph()` switches the display.

---

## Stage 7c — Static Declaration Section

In editor mode it scans the scene's Trigger instruction topology and shows **variable declaration information** (not live values).

### Caching Mechanism

```gdscript
var _cached_static_rows: Array[Dictionary] = []
var _last_static_refresh_ms: int = 0
const STATIC_REFRESH_INTERVAL_MS := 5000
```

Topology scanning is expensive (walking every Trigger + instruction chain), so it is **decoupled from the 0.5s polling**: `_collect_static_var_rows(topology)` only re-runs every 5 seconds, while other refreshes render the cached rows directly.

### Row Format

```
[cooldown      | (static) | local · read/write · 2 refs]
[player_health | (static) | scope · read/write · 1 ref]
[level_score   | (static) | global · read · 3 refs]
```

- The value column is fixed to `(static)`
- Type column: `{scope} · {access mode} · {number of reference sites}`, where access mode = read / write / read-write

---

## Stage 7d — Snapshot Export

```gdscript
## Generate a full snapshot of all variables at the current moment
func get_snapshot() -> Dictionary
# → {"timestamp": ..., "global": {...}, "containers": [...], "units": [...]}

func _on_snapshot() -> void:
	# Serialize to JSON and write to user://fuse_watcher_snapshot_{timestamp}.json
```

Snapshot structure (v3: bridge cache entries pass through directly):

```json
{
	"timestamp": 1234.567,
	"global": {"player_score": {"value": 2450, "type": "int"}},
	"containers": [
		{"id": 99001, "path": "/World/LevelScope", "scope_id": "level1",
		 "vars": {"alert_level": {"value": 50, "type": "int"}}}
	],
	"units": [
		{"id": 123456, "path": "/Main/Runner1", "kind": "runner", "ago_ms": 5,
		 "local": {"health": {"value": 85, "type": "int"}}}
	]
}
```

> **Extension note**: `get_snapshot()` is a public method that other debugging tools (e.g. automated test reports) can call directly, without going through the UI.

---

## WatcherUI Extension Guide

### Adding a New Section

```gdscript
func _refresh() -> void:
	# ... existing sections ...
	_render_my_section(_content, _filter_text)

func _render_my_section(parent: VBoxContainer, filter: String) -> void:
	var rows: Array[Dictionary] = []
	for item in _collect_my_data():
		rows.append(_make_row_data(item.name, item.value, {
			"scope": "my_scope",
			"var_key": "my_scope/%s" % item.name,
		}))
	_render_section(parent, "My Section", rows, filter, false)
```

### Extending Row Data

The row data Dictionary can carry custom keys, and `_make_data_row()` branches on them when rendering. When adding a new editable type, add a coercion branch in `_coerce_value()`.

### Integrating a New Runtime Data Source

1. Extend the JSON payload of `FuseRuntimeBridge._push_snapshot()` on the game side
2. Extend the cache structure of `_update_cache()` on the editor side
3. Read the new fields in `_collect_runtime_variables()` and generate rows

> **Note**: the Bridge protocol is a JSON line, so new fields are backward compatible (older parsers ignore unknown keys).

---

## Performance Design

| Mechanism | Overhead control |
|------|----------|
| 0.5s polling | Avoids per-frame refreshes; matches the Bridge push interval (0.5s), so half-updated states are never read |
| Full UI rebuild | Acceptable while the row count is below a few hundred; `_editing` skips the rebuild while editing |
| 5s static declaration cache | Decouples topology scanning from high-frequency polling (`STATIC_REFRESH_INTERVAL_MS = 5000`) |
| Numeric-only history | Only `int`/`float` enter `_history`; String/Vector etc. cost nothing |
| Fixed-length history window | `HISTORY_MAX = 120`; frames are popped beyond that, keeping memory constant |
| Search filtering at the render layer | Filtering does not change data collection, it only skips row creation |

**Known overhead points** (watch out when extending):

- `_collect_static_var_rows()` walks every Trigger — do not put it into the 0.5s polling loop
- 3 PanelContainers per row — consider `VBoxContainer` virtualization if row counts explode (not implemented yet)

---

## Common Pitfalls

### Pitfall 1: The Polled Rebuild Destroys the LineEdit While Editing

**Problem**: The 0.5s refresh rebuilds the UI, releasing the LineEdit being typed in.

**Solution**: `_editing` must be set to `true` once editing starts; `_refresh()` checks that flag at the top and returns immediately.

### Pitfall 2: The Game May Have Exited by the Time the Edit Commits

**Problem**: Rows are rendered from the last pushed snapshot, so the game may exit between rendering a row and committing the edit. `send_set_var` returns `false` when there is no live connection, and the value never reaches the game.

**Solution**: Treat a `false` return as a failed write-back — restore the original displayed value and warn (`FUSE_UI_WATCHER_EDIT_NO_CONNECTION`). The next push after `_editing` ends naturally corrects the display to the authoritative game-side value. (A failed coercion in `_coerce_value` still aborts the write-back silently — that is an input problem, not a connection problem.)

### Pitfall 3: Accessing GlobalVariableManager Directly and Bypassing the Service Layer

**Problem**: The panel calls `GlobalVariableManager.get_instance()` directly in places, falling out of sync with the Assistant signal flow.

**Solution**: Reads go through `GlobalVariableService.get_all_global_variables_info()`; write-backs go through the unified `_write_back_global()` entry point.

### Pitfall 4: History Keys Without the Scope

**Problem**: Same-named variables in different scopes share one history curve, polluting each other's data.

**Solution**: Keys must use the v3 scheme — `local:<unit_path>/<name>`, `scope:<container_path>/<name>`, `global/<name>` (as already required by `_history_key`, shared by `_record_history` and row selection; both ends must use the same scheme or the graph silently breaks).

### Pitfall 5: Putting the Static Scan into High-Frequency Polling

**Problem**: `_collect_static_var_rows()` runs every 0.5s, stuttering the editor.

**Solution**: Throttle with `_last_static_refresh_ms` + `STATIC_REFRESH_INTERVAL_MS`.

### Pitfall 6: Bridge Push and Polling Frequencies Out of Sync

**Problem**: After changing `PUSH_INTERVAL`, the watcher still assumes 0.5s (so the history window duration is misaligned).

**Solution**: The history window semantics are `HISTORY_MAX × PUSH_INTERVAL = displayed seconds`; when changing the frequency, adjust the comments and documentation accordingly.

### Pitfall 7: Fake String Rows from Object Values (v2 legacy — eliminated)

**Problem**: v2 serialized `Object` values into bare strings in the push, so the editor could not tell them from real `String` rows and could offer editing on non-editable values.

**Solution**: The v3 protocol wraps non-scalars read-only as `{"__complex": "str(v) ≤200 chars", "ty": "Vector2"}` — the root cause is eliminated at the protocol layer (the type column shows the real type name, rows are not editable). The game-side non-scalar gate remains as the last line of defense for hand-crafted messages.

### Pitfall 8: Local Rows Disappearing Right After a Run (design note)

**Problem**: In earlier designs the execution context was discarded as soon as a run finished ("fire-and-forget"), so there was nothing to report after a Trigger/Runner completed.

**Solution**: v3 keeps the **most recent** execution context instead: BaseTrigger (`_create_execution_context`), MultiEventTrigger and Runner all assign `current_execution_context` / `current_execution_context_at_ms`, so units report their last-run locals and the `ago_ms` freshness field lets the panel gray out stale hosts (> 5s).

### Pitfall 9: Collapsed State Lost Across Refreshes

**Problem**: The 0.5s refresh rebuilds the whole UI, so a group collapsed by the user would pop open again on the next tick.

**Solution**: Collapse state lives in the `_collapsed: Dictionary` member keyed by group id (`u<id>` / `c<id>`), not in the rebuilt controls; `_render_grouped_section()` queries it on every rebuild. While a search filter is active the collapsed state is ignored so matches always show.

---

## Summary

Key points of variable watcher development:

1. ✅ **Three data sources kept separate** — Bridge (runtime local/scope) ∥ Service (global) ∥ Analyzer (static declarations)
2. ✅ **Dual-mode TCP bridge** — editor TCPServer / game client, JSON line protocol, 0.5s pushes
3. ✅ **Row data Dictionary pattern** — `_make_row_data()` → `_make_data_row()`, new sections reuse `_render_section()`
4. ✅ **Edit protection** — the `_editing` flag blocks polled rebuilds; `_coerce_value` returning null aborts the write-back; editability itself is gated by `_is_row_editable` (scalar types + locatable scope)
5. ✅ **Performance throttling** — 0.5s polling + 5s static cache + 120-frame fixed-length history
6. ✅ **Public snapshot API** — `get_snapshot()` can be called directly by external tools
7. ✅ **v3 host-direct protocol** — pushes `{containers, units, global}` (non-scalars wrapped read-only as `__complex`), write-back dispatches on `target` (container/unit/global), and the Local/Scope sections group by host/container with collapse state keyed by group id

**Reference documents**:
- [Variable Watcher User Guide](../../user_docs/guides/56-variable-watcher-guide.md)
- [Global Variables Development Guide](59-global-variables-dev-guide.md)
- [Runtime Bridge Development Guide](runtime-bridge-guide.md)
- [Debugging System User Guide](../../user_docs/guides/25-debugging-guide.md)

---

**Document maintainer**: Fuse development team
**Last updated**: 2026-09-04
