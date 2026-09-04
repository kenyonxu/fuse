> 🌐 [**中文版**](../../../zh_CN/dev_docs/guides/runtime-bridge-guide.md) | English

# Fuse RuntimeBridge Development Guide

> **Goal**: Provide developers with a complete guide to the FuseRuntimeBridge runtime variable bridge, covering the dual-mode architecture, the TCP protocol, and variable snapshots.

**Audience**: Fuse system developers, contributors

**Last updated**: 2026-09-04

---

## 📋 Table of Contents

1. [System Overview](#system-overview)
2. [Architecture Design](#architecture-design)
3. [API Reference](#api-reference)
4. [TCP Protocol](#tcp-protocol)
5. [Use cases](#use-cases)
6. [Sticky and Partial Packet Handling](#sticky-and-partial-packet-handling)
7. [Best Practices](#best-practices)
8. [Common Pitfalls](#common-pitfalls)

---

## System Overview

`FuseRuntimeBridge` is a **dual-mode TCP bridge** that transfers variable snapshot data between the Godot editor process and the running game process. It lets the editor's debug tools (such as FuseVariableWatcher) view the variable state of a running game in real time.

> **Autoload singleton convention**
> `FuseRuntimeBridge` is registered as a global singleton via Autoload (no `class_name`); it can only be accessed directly by the Autoload name `FuseRuntimeBridge`.
> - ✅ `FuseRuntimeBridge.get_cached_vars()`
> - ❌ ~~`FuseRuntimeBridge.new()`~~ (no `class_name`, cannot be instantiated)
> - ❌ ~~`preload("res://...").get_cached_vars()`~~ (preload returns the script, not the instance)

### Core Files

| File | Purpose |
|------|------|
| `core/fuse_runtime_bridge.gd` | Runtime bridge (Autoload) |
| `editor/bootstrap/fuse_runtime_bootstrap.gd` | Runtime bootstrap |

### Design Goals

- **Dual-mode switching**: TCPServer on the editor side, TCP client on the running-game side
- **Low intrusiveness**: no changes needed to existing instruction/trigger code
- **Real-time first**: variable snapshots are pushed in real time; dropped frames are acceptable
- **Automatic cleanup**: the editor side clears its cache automatically when it detects a disconnected connection

---

## Architecture Design

```
┌──────────────────────────────┐     TCP     ┌──────────────────────────────┐
│    Godot editor process      │ ◄──────────► │   Running game process       │
│                              │   127.0.0.1   │                              │
│  FuseRuntimeBridge           │   :24563      │  FuseRuntimeBridge           │
│  ┌────────────────────┐      │  JSON line    │  ┌────────────────────┐     │
│  │  TCPServer mode    │      │  (\n sepa-    │  │  TCP Client mode   │     │
│  │                    │      │   rated)      │  │                    │     │
│  │  _cached: Dict     │ ◄────┼──────────────┼──┤  0.5s periodic push│     │
│  │  (snapshot cache)  │      │              │  │  _collect_units_+  │     │
│  │                    │      │              │  │  _containers()     │     │
│  └────────────────────┘      │              │  └────────────────────┘     │
│        ↕                     │              │        ↕                    │
│  FuseVariableWatcher         │              │  BaseTrigger/Runner units   │
│  (variable watcher)          │              │  ScopeVariableContainers    │
└──────────────────────────────┘              └──────────────────────────────┘
```

### Data Flow

```
Game side:
  _process(delta)
    → _client_poll(delta)       every 0.5s
        → _push_snapshot()
            → _collect_units_and_containers()  single pass over the root tree,
                │                              three-way classification per node
                │                              (the tree walk only produces containers/units)
                → BaseTrigger / Runner → units (local from the most recent
                │   execution context, kept after the run — not fire-and-forget)
                → ScopeVariableContainer → containers
            → _collect_global_flat()           global collected independently
                │                              (parallel to the tree walk, scalars only)
            → JSON.stringify + put_partial_data()

Editor side:
  _process(delta)
    → _server_poll()            every frame
        → accept new connections
        → read buffer → _read_json_lines()
            → _update_cache(containers/units/global)
        → all connections disconnected → _cached.clear()

Editor side (write-back):
  variable watcher edit commit
    → send_set_var(target, target_id, name, value)
        → JSON.stringify + put_partial_data()   broadcast to all connections
        → no connections → return false

Game side (apply write-back):
  _client_poll → _read_json_lines → _handle_message (dispatched by "t")
    → t == "set_var" → _apply_set_var()
        → three-way dispatch on target (container / unit / global)
        → type narrowing + non-scalar gate (shared by all three paths) → write
```

---

## API Reference

**File location**: `addons/fuse/core/fuse_runtime_bridge.gd`

**Class definition**:
```gdscript
@tool
extends Node
```

FuseRuntimeBridge is declared with `@tool` so it also runs in the editor. It is instantiated automatically via Autoload.

### Constants

```gdscript
const BRIDGE_PORT := 24563        # TCP port
const PUSH_INTERVAL := 0.5        # Push interval (seconds)
```

### Public Interface

```gdscript
## Editor side: get the cached runtime variable snapshot (v3 two-key structure)
## Returns: Dictionary — {"containers": [container entries], "units": [unit entries]}
func get_cached_vars() -> Dictionary

## Editor side: game-side global scalar snapshot ({name: value})
func get_cached_global() -> Dictionary

## Editor side: whether a running game is connected
func is_game_connected() -> bool

## Editor side: broadcast a write-back to the running game (fire-and-forget)
## target: "container" | "unit" | "global"; returns false when there is no live connection
func send_set_var(target: String, target_id: int, name: String, value: Variant) -> bool

## Test injection: start either mode with an explicit port (default BRIDGE_PORT = 24563)
func start_server(port: int = BRIDGE_PORT) -> void
func start_client(port: int = BRIDGE_PORT) -> void

## Editor side: whether the server is up and listening
func is_server_active() -> bool

## Pure function: extract complete JSON lines from a stream buffer (sticky/partial packet handling)
## Returns {lines: Array[Dictionary], rest: String}
static func extract_json_lines(buffer: String) -> Dictionary
```

These are used by editor tools (such as FuseVariableWatcher) to read the cached data and write values back to the running game.

### Lifecycle

```gdscript
func _ready() -> void:
    # Injection guard: an explicitly injected mode (tests) is respected as-is — no auto-switching
    if _server != null or _client != null:
        return
    if Engine.is_editor_hint():
        start_server()
    else:
        start_client()

func _exit_tree() -> void:
    # Stop the server / disconnect the client, clean up buffers and cache

func _process(delta: float) -> void:
    if Engine.is_editor_hint():
        if _server:
            _server_poll()
    else:
        if _client:
            _client_poll(delta)
```

### Internal Methods

```gdscript
# ===== Editor side - Server =====
func start_server(port: int = BRIDGE_PORT) -> void # Public: start the TCPServer, listen on the port (default :24563)
func _server_poll() -> void                        # Poll every frame: accept connections + read data
func _read_json_lines(conn: StreamPeerTCP) -> void # Read JSON line by line from the TCP stream
func _update_cache(payload: Dictionary) -> void    # Update _cached (containers/units via .get, missing fields degrade to empty sets)

# ===== Game side - Client =====
func start_client(port: int = BRIDGE_PORT) -> void # Public: connect to the editor
func _client_poll(delta: float) -> void            # Poll + push every 0.5s
func _push_snapshot() -> void                      # Push the variable snapshot
func _collect_units_and_containers() -> Dictionary # v3 collection: single pass over the root tree, three-way classification
```

---

## TCP Protocol

### Protocol Format

TCP stream + JSON line (`\n` separated).

**Push (game → editor, protocol `proto = 3`), every 0.5s, always pushed** — even with zero units/containers the `global` snapshot is still pushed (empty `containers`/`units` clear the editor's caches):

```json
{"t": "vars", "proto": 3, "scene": "fuse_demo_level_01",
 "containers": [
    {"id": 99001, "path": "/World/LevelScope", "scope_id": "level1",
     "vars": {"alert_level": 50, "items": {"__complex": "[item1, item2]", "ty": "Array"}}}
 ],
 "units": [
    {"id": 123456789, "path": "/Enemies/Slime", "kind": "trigger", "ago_ms": 320,
     "local": {"health": 85}},
    {"id": 123456790, "path": "/Main/Runner1", "kind": "runner", "ago_ms": 5,
     "local": {"score": 100}}
 ],
 "global": {"player_score": 2450, "game_time": 132.5}}
```

**Protocol v3 fields**:

| Field | Meaning |
|------|------|
| `scene` (top level) | The game's current scene name (`current_scene.name`, empty string when no scene); the watcher groups hosts under the "current scene" root with this, while hosts with `/root/<name>` absolute paths group under their additive scene roots. A missing field degrades safely to an unnamed group |
| `containers[].id` / `path` / `scope_id` / `vars` | `ScopeVariableContainer` instance id / display path (current-scene relative, shown in group headers; falls back to an absolute path starting with `/root/...` outside the scene subtree) / scope id / variable snapshot |
| `units[].id` / `path` / `kind` | Host component instance id / display path / `trigger` \| `multi` \| `runner` (BaseTrigger / MultiEventTrigger / Runner) |
| `units[].ago_ms` | Milliseconds since the component's most recent execution; the watcher grays out group headers older than 5s |
| `units[].local` | Local variables of the component's **most recent execution context** — all three host kinds keep `current_execution_context` after a run instead of discarding it |
| `global` (top level) | Game-side snapshot of global variable **scalars** (`{name: value}`); complex types (Dictionary/Array/Vector etc.) do not enter the protocol |
| `__complex` wrapper | A non-scalar value is encoded read-only as `{"__complex": "str(v) ≤200 chars", "ty": "Vector2"}` — the editor can tell a real `String` from a complex value (v2 serialized objects into bare strings, a source of "fake String" rows; eliminated at the protocol layer) |

**Reverse message (editor → game)** — broadcast to **all** live connections, **fire-and-forget** (no acknowledgment; correctness is backed by the 0.5s push echo):

```json
{"t": "set_var", "proto": 3, "target": "container", "id": 99001, "name": "alert_level", "value": 75}
```

Application semantics on the game side (`_apply_set_var`, three-way dispatch on `target`):

- **Shared guards (all three paths)**: **type narrowing** — after JSON parsing every number is a `float`; it is narrowed to the target variable's existing type (an `int` target is narrowed back to `int`; a missing target is written as-is — the float widening is a known limitation). **Non-scalar gate** — a write-back whose target slot currently holds a non-scalar (`Object` / `Vector2` / containers) is silently ignored; since v3 the push side already labels non-scalars with the read-only `__complex` wrapper, so the editor never issues writes on those rows and the gate remains only as the last line of defense.
- **`target == "container"`**: `_find_node_by_id(id)` locates the `ScopeVariableContainer` → `set_variable`; a stale id is silently ignored.
- **`target == "unit"`**: locates a `BaseTrigger`/`Runner` → `current_execution_context` → `_variable_context` → `set_variable` on `local`; a unit without a valid recent context (never executed) is silently ignored.
- **`target == "global"`**: the variable is written only when it **already exists** (missing variables are not created, silently ignored).
- **`_find_node_by_id` locating**: a recursive scan of the root tree matching `get_instance_id()`, type-checked against the `expected` parameter (`""` = any BaseTrigger/Runner; `"ScopeVariableContainer"` = containers) — not `instance_from_id`, which would spam engine ERRORs on stale ids.
- **Editor side**: `send_set_var()` returns `false` when there is no live connection; a short write (partial bytes sent) warns and disconnects that connection, and the game side reconnects and self-heals.
- **Degradation**: `_handle_message` dispatches on `t` (not on key presence); missing fields fall back to empty sets via `.get` defaults, so even a degraded push still reaches `_update_cache` and clears the caches.

### Test Injection

For tests both modes can be injected in the same process with an explicit port; the production path keeps the default `BRIDGE_PORT` (24563):

```gdscript
FuseRuntimeBridge.start_server(24599)   # editor side, listening on the injected port
FuseRuntimeBridge.start_client(24599)   # game side, connects to the injected port
```

Loopback test: `tests/debugging/test_runtime_bridge_loopback.tscn` (uses port 24599 to avoid interference with the Autoload bridge on 24563).

### Port

- Fixed port: **24563**
- Listen address: **127.0.0.1** (local loopback only)

### Sticky and Partial Packet Handling

Each connection has its own read buffer `_read_buffers: Dictionary` (keyed by `conn.get_instance_id()`):

```gdscript
# Pseudocode
_read_buffers[cid] += data
while "\n" found:
    line = extract_line
    parse JSON → _update_cache
```

---

## Use cases

### Editor Variable Monitoring

The `FuseVariableWatcher` editor panel calls `FuseRuntimeBridge.get_cached_vars()` to fetch the running variable snapshot:

```gdscript
# addons/fuse/editor/debugging/variable_watcher.gd
var vars = FuseRuntimeBridge.get_cached_vars()
for unit in vars.get("units", []):
    var local_data = unit.get("local", {})   # group header: ▸ path [kind] · ago
for container in vars.get("containers", []):
    var scope_data = container.get("vars", {})   # group header: ▸ path (scope_id)
# Display in the editor panel
```

### Runtime Debugging

While the game is running, the editor side receives variable snapshots automatically, so you can watch variable changes without manually setting breakpoints or printing logs.

---

## Best Practices

### 1. Data Type Limitations

Make sure variables are JSON-serializable (basic types, Dictionary, Array); custom objects are not transferred correctly.

### 2. Push Frequency Control

`PUSH_INTERVAL = 0.5s` is a reasonable value — lower adds network and serialization overhead, higher loses real-time behavior. Do not modify this value manually in `_process`.

### 3. Buffer Cleanup

`_read_buffers` is indexed by connection ID and cleaned automatically on disconnect:

```gdscript
var cid := conn.get_instance_id()
conn.disconnect_from_host()
_read_buffers.erase(cid)
_connections.remove_at(i)
```

### 4. Disconnection Detection

```gdscript
# In _server_poll, check the status after poll() every frame
conn.poll()
var st := conn.get_status()
if st == StreamPeerTCP.STATUS_NONE or st == StreamPeerTCP.STATUS_ERROR:
    # Disconnect + clean up
```

### 5. Automatic Reconnect on the Game Side

```gdscript
func start_client(port: int = BRIDGE_PORT) -> void:
    # ...connect...
    # On failure, _client_poll detects STATUS_ERROR and reconnects automatically
```

---

## Common Pitfalls

### Pitfall 1: Port Conflict

**Problem**: if another program occupies port 24563, StartServer fails.

**Symptom**: the console prints `WARNING: FuseRuntimeBridge: 监听 24563 失败(ERR_...)`.

**Solution**: check what occupies the port. `FuseRuntimeBridge` fails silently; `get_cached_vars()` returns an empty Dictionary.

### Pitfall 2: Multiple Editor Instances Conflict

**Problem**: launching multiple Godot editor instances at once, each trying to listen on 24563.

**Solution**: only one instance can start the server successfully. Run the game in only one instance.

### Pitfall 3: Sticky Packets Cause JSON Parsing Errors

**Problem**: multiple JSON lines in the TCP stream arrive merged, and `get_utf8_string()` reads back several at once.

**Solution**: split on `\n` and parse line by line; `_read_json_lines()` already handles this case.

### Pitfall 4: Runtime-Added Subtrees Are Missed

**Problem**: the v2 collector walked `get_tree().current_scene`, so subtrees added at runtime (attached scenes) never reported.

**Solution**: v3 collects in a single pass from `get_tree().root` (`_collect_units_and_containers`), which covers attached scenes; the game process's autoloads contain no Fuse components, so the scan stays equivalent to the full scene.

### Pitfall 5: Variables Not Updating

**Problem**: a variable was modified but the editor shows no update.

**Possible causes**:
- The unit has no valid recent execution context yet (a BaseTrigger/Runner reports `local` only after its first execution)
- `_variable_context` is empty (the historical B19 bug, now fixed)
- The connection is gone but `_cached` was not cleared

---

## Reference Documents

- [ExecutionContext and Diagnostics Guide](execution-context-diagnostics-guide.md)
- [FuseLogger Logging System Guide](fuse-logger-guide.md)
- [FuseEventBus Development Guide](event-bus-guide.md)
- [ActionRunner Development Guide](action-runner-guide.md)

---

**Document maintainer**: Fuse development team | **Last updated**: 2026-09-04 | **Godot version**: 4.7
