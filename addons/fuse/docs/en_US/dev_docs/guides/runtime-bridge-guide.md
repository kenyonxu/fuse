> 🌐 [**中文版**](../../../zh_CN/dev_docs/guides/runtime-bridge-guide.md) | English

# Fuse RuntimeBridge Development Guide

> **Goal**: Provide developers with a complete guide to the FuseRuntimeBridge runtime variable bridge, covering the dual-mode architecture, the TCP protocol, and variable snapshots.

**Audience**: Fuse system developers, contributors

**Last updated**: 2026-07-07

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
│  │  (snapshot cache)  │      │              │  │  _collect_runners()│     │
│  └────────────────────┘      │              │  └────────────────────┘     │
│        ↕                     │              │        ↕                    │
│  FuseVariableWatcher         │              │  Runner nodes               │
│  (variable watcher)          │              │  (current_execution_context)│
└──────────────────────────────┘              └──────────────────────────────┘
```

### Data Flow

```
Game side:
  _process(delta)
    → _client_poll(delta)       every 0.5s
        → _push_snapshot()
            → _collect_runners()   iterate the Runner nodes in the scene
                → ec = runner.current_execution_context
                → vc = ec._variable_context
                → snapshot: {local_vars, scope_vars}
            → JSON.stringify + put_partial_data()

Editor side:
  _process(delta)
    → _server_poll()            every frame
        → accept new connections
        → read buffer → _read_json_lines()
            → _update_cache(runners)
        → all connections disconnected → _cached.clear()
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
## Get the cached runtime variable snapshot (editor side)
## Returns: Dictionary — {runner_name: {"local": {...}, "scope": {...}}}
func get_cached_vars() -> Dictionary
```

This is the only public method, used by editor tools (such as FuseVariableWatcher) to read the cached data.

### Lifecycle

```gdscript
func _ready() -> void:
    if Engine.is_editor_hint():
        _start_server()
    else:
        _connect_client()

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
func _start_server() -> void                      # Start the TCPServer, listen on :24563
func _server_poll() -> void                        # Poll every frame: accept connections + read data
func _read_json_lines(conn: StreamPeerTCP) -> void # Read JSON line by line from the TCP stream
func _update_cache(runners: Array) -> void         # Update the _cached cache

# ===== Game side - Client =====
func _connect_client() -> void                     # Connect to 127.0.0.1:24563
func _client_poll(delta: float) -> void            # Poll + push every 0.5s
func _push_snapshot() -> void                      # Push the variable snapshot
func _collect_runners() -> Array                   # Collect variables from all Runners in the scene
```

---

## TCP Protocol

### Protocol Format

TCP stream + JSON line (`\n` separated):

```json
{"t": "vars", "runners": [
    {
        "name": "RunnerName",
        "local": {"score": 100, "name": "player"},
        "scope": {"health": 80, "mana": 50}
    },
    ...
]}
```

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
for runner_name in vars:
    var local_data = vars[runner_name].local
    var scope_data = vars[runner_name].scope
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
func _connect_client() -> void:
    # ...connect...
    # On failure, _client_poll detects STATUS_ERROR and calls _connect_client() again
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

### Pitfall 4: `get_tree()` Returns null at Runtime

**Problem**: `_collect_runners()` depends on `get_tree().current_scene`; if the scene is not ready it returns an empty array.

**Solution**: check `scene != null` before pushing; if null, skip this push.

### Pitfall 5: Variables Not Updating

**Problem**: a variable was modified but the editor shows no update.

**Possible causes**:
- `Runner.current_execution_context` is not set
- `_variable_context` is empty (the historical B19 bug, now fixed)
- The connection is gone but `_cached` was not cleared

---

## Reference Documents

- [ExecutionContext and Diagnostics Guide](execution-context-diagnostics-guide.md)
- [FuseLogger Logging System Guide](fuse-logger-guide.md)
- [FuseEventBus Development Guide](event-bus-guide.md)
- [ActionRunner Development Guide](action-runner-guide.md)

---

**Document maintainer**: Fuse development team | **Last updated**: 2026-07-07 | **Godot version**: 4.7
