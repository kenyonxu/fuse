> 🌐 [**中文版**](../../../zh_CN/system_docs/analysis/global_infrastructure_analysis.md) | English

# Global Infrastructure Analysis Report (FuseEventBus / FuseRuntimeBridge)


> **Analysis as of**: 2026-07-07 (code verified article-by-article during the same-day full documentation audit; implementation evolution since then defers to the source code; for recently verified mechanical conclusions see the threading / runtime_instance / preset_nested articles)
## Document Overview

This report provides a comprehensive analysis of Fuse's two top-level global Autoload singleton nodes:

- **`FuseEventBus`** — the global event communication hub, providing custom event subscription/publishing across Triggers.
- **`FuseRuntimeBridge`** — the runtime variable TCP bridge, transporting Runner local/scope variable snapshots between the editor process and the running game process, for real-time display by the editor-side variable watcher (`FuseVariableWatcher`).

Both are `extends Node` Autoload singletons that `FuseRuntimeBootstrap` dynamically registers into `project.godot` when the plugin is enabled and deregisters when the plugin is disabled. The two **never call each other directly** and belong to two independent subsystems (event communication / debug reflection).

**Source files:**
- [`addons/fuse/core/fuse_event_bus.gd`](../../../../core/fuse_event_bus.gd) (216 lines)
- [`addons/fuse/core/fuse_runtime_bridge.gd`](../../../../core/fuse_runtime_bridge.gd) (199 lines)
- [`addons/fuse/editor/bootstrap/fuse_runtime_bootstrap.gd`](../../../../editor/bootstrap/fuse_runtime_bootstrap.gd) (registration bootstrap)

**Base class:** Node (both)
**Registration method:** Autoload singleton (the `[autoload]` section of `project.godot`; the `*` prefix means enabled)

---

## 1. The Autoload Singleton Mechanism

### 1.1 Registration Location

`project.godot` ([lines 26–29](../../../../../../project.godot)):

```ini
[autoload]

FuseEventBus="*uid://ptmsqnuut75p"
FuseRuntimeBridge="*uid://c6iequlsnctd7"
```

Key points:
- Registered as a **UID** (Godot 4.4+); path resolution is stable and does not depend on relative paths.
- The `*` prefix means the singleton is **enabled** (removing `*` disables it but keeps the entry).
- The registration names `FuseEventBus` / `FuseRuntimeBridge` are the global access names.

### 1.2 Registration Bootstrap (FuseRuntimeBootstrap)

Registration is not written into `project.godot` manually; instead, the `EditorPlugin` calls `add_autoload_singleton` / `remove_autoload_singleton` dynamically when the plugin is enabled/disabled ([fuse_runtime_bootstrap.gd:16-24](../../../../editor/bootstrap/fuse_runtime_bootstrap.gd)):

```gdscript
func setup() -> void:
    _register_event_bus()
    _register_reflection_cache_cleanup()
    _register_runtime_bridge()

func teardown() -> void:
    _unregister_runtime_bridge()
    _unregister_reflection_cache_cleanup()
    _unregister_event_bus()
```

Each `_register_*` first checks `ProjectSettings.get_setting("autoload", {})` to avoid duplicate registration; `_unregister_*` cleans up symmetrically. This "plugin-managed register/deregister" pattern means users never need to edit `project.godot` by hand when adding or removing the plugin.

### 1.3 Global Access Pattern

Since `FuseEventBus` / `FuseRuntimeBridge` are Autoloads, they could in principle be accessed directly by name. But consumer code (`SendEvent`, `OnReceiveEvent`, `FuseVariableWatcher`) uniformly uses explicit `get_node_or_null` paths for **graceful degradation**, avoiding hard crashes when the Autoload is not registered:

```gdscript
# How SendEvent / OnReceiveEvent do it
var bus: Node = Engine.get_main_loop().root.get_node_or_null("FuseEventBus")

# How FuseVariableWatcher does it
var bridge = get_tree().root.get_node_or_null("FuseRuntimeBridge")
if bridge == null or not bridge.has_method("get_cached_vars"):
    return result   # safe degradation
```

### 1.4 Lifecycle

| Phase | Trigger | Behavior |
|------|------|------|
| Plugin enabled / project loaded | `EditorPlugin._enter_tree()` → `FuseRuntimeBootstrap.setup()` | Writes the autoload into `project.godot` |
| Main loop starts | Godot SceneTree creates the autoload nodes | Mounted at `/root/FuseEventBus`, `/root/FuseRuntimeBridge`; `_ready()` fires |
| Run ends | Node deletion notification `NOTIFICATION_PREDELETE` | `FuseEventBus._notification` clears `_listeners` |
| Exiting the tree | `_exit_tree()` | `FuseRuntimeBridge` shuts down the TCP server/client and clears caches |
| Plugin disabled | `EditorPlugin._exit_tree()` → `teardown()` | Removes the autoload entries from `project.godot` |

> **Important**: Autoload nodes exist **independently in both the editor process and the running game process**. `FuseRuntimeBridge` exploits exactly this, running in different modes in the two processes (see §5 for details).

### 1.5 Why Autoload Instead of a Resource Singleton

| Dimension | Autoload Node | Resource singleton (static var + load) |
|------|---------------|------------------------------------|
| Lifecycle hooks | `_ready` / `_process` / `_exit_tree` / `_notification` | None (manual init/cleanup required) |
| Signals | Native `signal` | Resources can declare them too, but need an explicit emit entry point |
| Cross-scene persistence | Built in | Built in |
| Cross-process instances | One copy each in editor / run | Same |
| Network timers | Driven directly by `_process` | Needs an external driver |
| `Engine.is_editor_hint()` dual mode | The same script can behave differently in the two processes | Same |

`FuseEventBus` needs to listen to `SceneTree.node_removed` (reflection cache cleanup), and `FuseRuntimeBridge` needs `_process` to drive TCP polling and timed snapshot pushes — both depend heavily on the Node lifecycle, so Autoload is the inevitable choice.

---

## 2. FuseEventBus — The Global Event Bus

### 2.1 Class Overview and Responsibilities

`FuseEventBus` is Fuse's **global publish-subscribe hub** for custom events, solving the problem of "how different Triggers communicate". It is independent of the Trigger-internal signal chain of `BaseEvent.triggered` / `BaseTrigger`, providing a lightweight communication channel of **string event names + Dictionary arguments**.

**Core responsibilities:**
1. **Subscription management**: maintains a `{event_name: [Subscription, ...]}` dictionary
2. **Event dispatch**: `send_event()` synchronously notifies all subscribers
3. **Deferred sending**: `send_event_deferred()` sends at the end of the frame
4. **Event history**: keeps the most recent 100 events for the debugger/editor to inspect
5. **Reflection cache cleanup**: hooks `node_removed` in `_ready`, clearing the `ReflectionCache` / `FunctionManager` caches when nodes are deleted

### 2.2 Signals

| Signal | Parameters | Purpose |
|------|------|------|
| `event_sent` | `(event_name: String, args: Dictionary)` | Emitted synchronously on every event send, **for editor debugging only**, to observe the event flow (see [fuse_event_bus.gd:14](../../../../core/fuse_event_bus.gd)) |

### 2.3 Inner Class and Constants

```gdscript
class Subscription extends RefCounted:
    var event_name: String
    var callback: Callable
    var id: int

const MAX_HISTORY_SIZE: int = 100
```

`Subscription` is a `RefCounted`: `subscribe()` returns it and `unsubscribe()` removes it by reference — **never** rely on `id` or callback object equality alone.

### 2.4 Instance Properties

| Property | Type | Description |
|------|------|------|
| `_listeners` | Dictionary | `{event_name(String) : Array[Subscription]}`, the subscription table |
| `_subscription_counter` | int | Monotonically increasing subscription id |
| `_event_history` | Array | Recent event records, each `{name, args, timestamp}` |

### 2.5 Core API

#### `send_event(event_name: String, args: Dictionary = {}) -> void` — Synchronous send

Execution flow ([fuse_event_bus.gd:51-67](../../../../core/fuse_event_bus.gd)):
1. Warns on empty name and returns
2. `_record_event()` writes history
3. `event_sent.emit()` fires the debug signal
4. `duplicate()`s the listener list (avoiding mutation of the original array by subscribe/unsubscribe during iteration)
5. Iterates and calls, validating with `callback.is_valid()` before `callback.call(args)`

> **Note**: sending is **synchronously blocking**; logic inside subscriber callbacks blocks the sender.

#### `send_event_deferred(event_name, args = {}) -> void` — Deferred send

```gdscript
call_deferred("send_event", event_name, args)
```

Sent at the end of the frame, avoiding long call stacks from chained events triggering within the same frame.

#### `subscribe(event_name: String, callback: Callable) -> Subscription`

- Warns and returns null on empty name
- Automatically creates the `_listeners[event_name]` array
- Returns the newly created `Subscription` (with a unique id)

#### `unsubscribe(subscription: Subscription) -> void`

- Null check
- `find()` locates it in the subscription array by reference → `remove_at()`
- When the array becomes empty, `erase`s the whole event-name key

#### Query API

| Method | Returns | Description |
|------|------|------|
| `has_listeners(event_name)` | bool | Whether the event has subscribers |
| `get_listener_count(event_name="")` | int | Subscription count for one event or for all |
| `get_registered_events()` | Array[String] | List of subscribed event names |
| `get_event_history()` | Array | Copy of the history (avoids external mutation) |
| `clear_history()` / `clear_all_listeners()` | void | Cleanup |

### 2.6 Event History

```gdscript
func _record_event(event_name, args) -> void:
    _event_history.append({
        "name": event_name,
        "args": args.duplicate(),       # deep copy, avoids later external modification
        "timestamp": Time.get_ticks_msec()
    })
    if _event_history.size() > MAX_HISTORY_SIZE:
        _event_history.pop_front()       # FIFO, capped at 100 entries
```

### 2.7 Reflection Cache Cleanup (Unrelated to the Event Bus Itself)

`_ready()` hooks a side effect **unrelated to event communication** ([fuse_event_bus.gd:34-41](../../../../core/fuse_event_bus.gd)):

```gdscript
func _ready() -> void:
    if get_tree():
        get_tree().node_removed.connect(_on_node_removed_for_reflection_cache)

func _on_node_removed_for_reflection_cache(node: Node) -> void:
    ReflectionCache.get_instance().clear_node(node)
    FunctionManager.clear_callable_cache(node)
```

When a node is deleted, the reflection/callable caches are cleared to avoid dangling pointers.

> **Note (to be confirmed)**: `FuseRuntimeBootstrap._register_reflection_cache_cleanup()` **also** connects to `tree.node_removed` once ([fuse_runtime_bootstrap.gd:44-48](../../../../editor/bootstrap/fuse_runtime_bootstrap.gd)), with a callback body **identical** to `FuseEventBus._on_node_removed_for_reflection_cache`. In the editor process, **the same node's `node_removed` signal fires twice** — once from the bootstrap (editor only, since only `EditorPlugin` exists there) and once from the autoload (both editor and running game). The two cleanups are idempotent with respect to each other (the `clear_*` calls are fault-tolerant), so nothing breaks, but this is mild redundancy — likely historical residue from the bootstrap also doubling as the "running-game-side fallback". If simplification is desired, some place on the running-game side could take it over uniformly.

### 2.8 Cleanup Hook

```gdscript
func _notification(what: int) -> void:
    if what == NOTIFICATION_PREDELETE:
        _listeners.clear()
```

`PREDELETE` arrives before the object is freed; clearing the subscription table at that point avoids later callbacks touching invalidated objects.

---

## 3. FuseEventBus Cooperation with SendEvent / OnReceiveEvent

This is the event bus's main consumption chain, forming "cross-Trigger communication".

### 3.1 The SendEvent Instruction (Sender)

[send_event.gd:76-122](../../../../instructions/event/send_event.gd):

```gdscript
func execute(context: ExecutionContext) -> void:
    # 1. validate
    if event_name.is_empty():
        set_error_localized("FUSE_ERROR_EVENT_NAME_EMPTY", ...)
        finished.emit(); return

    # 2. resolve $variable_name references
    var resolved_args := _resolve_args(context, event_args)

    # 3. access via the Autoload (degradation-safe)
    var bus: Node = Engine.get_main_loop().root.get_node_or_null("FuseEventBus")
    if bus == null:
        set_error_localized("FUSE_ERROR_EVENT_BUS_NOT_FOUND", ...)
        finished.emit(); return

    # 4. send (sync or deferred)
    if deferred:
        bus.send_event_deferred(event_name, resolved_args)
    else:
        bus.send_event(event_name, resolved_args)

    _on_execution_completed()
```

`@export` options:
- `event_name: String`
- `event_args: Dictionary` — supports `"$variable_name"` string references, resolved at execution time by `context.get_variable()`
- `deferred: bool` — chooses `send_event` or `send_event_deferred`

### 3.2 The OnReceiveEvent Event (Receiver)

[on_receive_event.gd](../../../../events/event/on_receive_event.gd):

`@export` options:
- `event_name: String` — the event name to listen for
- `trigger_once: bool` — automatically unsubscribes after firing once
- `store_args_to_local: bool` — whether to store the arguments into RuntimeEventInstance state
- `local_var_prefix: String` — variable name prefix when storing (default `event_`)

**Initialization (subscribe)**: [on_receive_event.gd:143-153](../../../../events/event/on_receive_event.gd)

```gdscript
func _subscribe_to_event(owner_node: Node) -> void:
    var bus: Node = Engine.get_main_loop().root.get_node_or_null("FuseEventBus")
    if bus == null:
        _create_fuse_error_localized("FUSE_ERROR_EVENT_BUS_NOT_FOUND", ...)
        return
    _subscription = bus.subscribe(event_name, _on_event_received.bind(owner_node))
```

Note that `.bind(owner_node)` binds the Trigger node into the Callable as an extra argument — the callback signature is `(args, owner_node)`.

**Callback (receive)**: [on_receive_event.gd:177-256](../../../../events/event/on_receive_event.gd)
1. `trigger_once` check (state read from RuntimeEventInstance first, falling back to `_has_triggered`)
2. Marks as triggered (writes RuntimeEventInstance synchronously)
3. When `store_args_to_local`, writes each argument into runtime state as `local_var_prefix + key`, and saves the full `last_event_args`
4. `update_trigger_stats()`
5. Creates a temporary `Node` as the context carrier, set_metas `event_name` / `event_args` / `trigger`, then `triggered.emit(context_node)` followed by `queue_free()`
6. Unsubscribes immediately when `trigger_once`

**Cleanup (unsubscribe)**: `terminate()` unsubscribes via the `_subscription` reference.

### 3.3 Data Flow

```
[Trigger A's instruction chain]              [FuseEventBus Autoload]              [Trigger B's event subscription]
   SendEvent.execute(ec)
     │ bus.send_event(name, args)
     ▼
     _record_event + event_sent.emit
     │
     ▼ iterate _listeners[name]
     │ Subscription(B).callback.call(args)
     ▼                                   ────►    OnReceiveEvent._on_event_received(args, owner=B)
                                                                 │
                                                                 ▼ store state + update_stats
                                                                 ▼ triggered.emit(ctx_node)
                                                                 ▼
                                                          RuntimeEventInstance → Trigger → ActionRunner
```

### 3.4 Difference from BaseEvent's Internal Signals

| Dimension | BaseEvent.triggered (Trigger-local) | FuseEventBus (global) |
|------|-------------------------------------|----------------------|
| Scope | The Event resource held by a single Trigger | Global, across Triggers |
| Trigger source | Subclass internals (e.g. OnBodyEntered listening to Area2D signals) | Explicit `SendEvent` instruction or script call |
| Context | `Node` + `trigger` meta identifying ownership | String event name + Dictionary arguments |
| Routing | Relayed and filtered via RuntimeEventInstance | Dispatched directly via the `_listeners` dictionary |
| Typical scenarios | Node signals, animation, physics | User-defined cross-module communication |

OnReceiveEvent **bridges the two**: outwardly it consumes FuseEventBus; inwardly it still goes through the BaseEvent.triggered chain.

---

## 4. FuseRuntimeBridge — The Runtime Variable TCP Bridge

### 4.1 Class Overview and Responsibilities

`FuseRuntimeBridge` is a **dual-mode Autoload**: the same script **executes different branches** in the editor process and the running game process, establishing a communication channel over localhost TCP (`127.0.0.1:24563`) and pushing the running game's Runner variable snapshots to the editor for real-time display by the variable watcher.

**Why a TCP bridge is needed**: Godot's built-in debug protocol (`EngineDebugger`) is not directly callable from the GDScript side, and the editor process and the running game process are memory-isolated — RefCounted / Object references cannot reach across processes. See the historical design research `archive/roadmap/2026-06-27-runtime-variable-access-research.md` ("running game → editor: push flat snapshots" was the only viable path).

### 4.2 Constants and Protocol

```gdscript
const BRIDGE_PORT := 24563
const PUSH_INTERVAL := 0.5
```

**Protocol**: TCP stream + JSON line (`\n`-separated). Each message is one line of JSON:

```
running game → editor:
  {"t":"vars","runners":[
      {"name":"Runner1","local":{...},"scope":{...}},
      {"name":"Runner2","local":{...},"scope":{...}}
  ]}
```

`local` / `scope` are both **flat Dictionaries** (variable name → value), produced by `VariableContext.get_all_local_variables_snapshot()` / `get_all_scope_variables_snapshot()` (see [variable_context.gd:374-383](../../../../core/base/variable_context.gd) for details).

### 4.3 Instance Properties

| Property | Type | Description |
|------|------|------|
| `_server` | TCPServer | Editor-side listening instance (null on the running game side) |
| `_connections` | Array[StreamPeerTCP] | Editor-side connections to all attached running games |
| `_client` | StreamPeerTCP | Running-game-side client connection to the editor (null on the editor side) |
| `_cached` | Dictionary | Editor-side cache: `{runner_name: {"local":{...}, "scope":{...}}}` |
| `_push_acc` | float | Running-game-side push timing accumulator |
| `_read_buffers` | Dictionary | `{conn.get_instance_id() : String}`, TCP read buffers handling sticky/split packets |

### 4.4 Dual-Mode Lifecycle

```gdscript
func _ready() -> void:
    if Engine.is_editor_hint():
        _start_server()        # editor side: open a TCPServer
    else:
        _connect_client()      # running game side: connect the TCP client

func _process(delta: float) -> void:
    if Engine.is_editor_hint():
        if _server:
            _server_poll()     # editor side: accept + read JSON lines
    else:
        if _client:
            _client_poll(delta)  # running game side: throttled push

func _exit_tree() -> void:
    # close the server, disconnect all connections, disconnect the client, clear caches
```

> The same script branches via `Engine.is_editor_hint()` — the standard usage for a dual-mode Autoload.

### 4.5 Editor Side (TCPServer Mode)

#### Listen Startup

```gdscript
func _start_server() -> void:
    _server = TCPServer.new()
    var err := _server.listen(BRIDGE_PORT, "127.0.0.1")
    if err != OK:
        push_warning("FuseRuntimeBridge: 监听 %d 失败(%d)..." % [BRIDGE_PORT, err])
```

Listen failure is not fatal, only a `push_warning` — when the bridge is unavailable, the editor-side `get_cached_vars()` returns an empty dictionary and the watcher displays nothing.

#### Polling Logic `_server_poll()`

Runs every frame ([fuse_runtime_bridge.gd:78-101](../../../../core/fuse_runtime_bridge.gd)):
1. `take_connection()` accepts all pending connections into `_connections`
2. Iterates `_connections`:
   - `conn.poll()` (**key**: the comment explicitly notes "after poll, get_status is accurate and disconnected connections get cleared, avoiding !is_open error spam flooding the log and stalling")
   - On status `STATUS_NONE` / `STATUS_ERROR`: disconnect, clear the buffer, `remove_at`, **without incrementing i** (continue)
   - Otherwise `_read_json_lines(conn)`, `i += 1`
3. All connections gone → `_cached.clear()` (the running game has exited)

#### Sticky-Packet Handling `_read_json_lines()`

[Lines 104–124](../../../../core/fuse_runtime_bridge.gd):
1. `get_utf8_string(avail)` reads all available bytes
2. Appends to `_read_buffers[cid]` (an independent buffer per connection)
3. Loops `find("\n")`, splitting by line; each line goes through `JSON.parse_string`
4. If the parse result is a `Dictionary` containing the `runners` key → `_update_cache()`

#### Cache Update `_update_cache()`

```gdscript
for r in runners:
    var rname: String = r.get("name", "?")
    var local_data: Dictionary = r.get("local", {})
    var scope_data: Dictionary = r.get("scope", {})
    _cached[rname] = {"local": local_data.duplicate(), "scope": scope_data.duplicate()}
```

Each push **overwrites `_cached` wholesale** (no deltas), guaranteeing stale data is cleared after the running game exits or a Runner disappears.

#### Public API `get_cached_vars() -> Dictionary`

The entry point for the editor-side variable watcher (`FuseVariableWatcher`):

```gdscript
# variable_watcher.gd:331-336
var bridge = get_tree().root.get_node_or_null("FuseRuntimeBridge")
if bridge == null or not bridge.has_method("get_cached_vars"):
    return result
var cached: Dictionary = bridge.get_cached_vars()
```

### 4.6 Running Game Side (TCP Client Mode)

#### Connection Establishment

```gdscript
func _connect_client() -> void:
    if _client:
        _client.disconnect_from_host()
        _client = null
    _client = StreamPeerTCP.new()
    _client.connect_to_host("127.0.0.1", BRIDGE_PORT)
```

Non-blocking connect; if the editor has not started, the connection sits in `STATUS_CONNECTING` and is retried by subsequent `_client_poll` calls.

#### Throttled Polling `_client_poll(delta)`

[Lines 155–168](../../../../core/fuse_runtime_bridge.gd):

```gdscript
_push_acc += delta
if _push_acc < PUSH_INTERVAL:    # 0.5s throttle
    return
_push_acc = 0.0
_client.poll()
var st := _client.get_status()
if st == STATUS_NONE or STATUS_ERROR:
    _connect_client()            # reconnect
    return
if st != STATUS_CONNECTED:
    return
_push_snapshot()
```

**Reason for throttling** (comment): avoid per-frame poll blocking the main thread.

#### Snapshot Push `_push_snapshot()`

```gdscript
var runners := _collect_runners()
if runners.is_empty():
    return
var msg := JSON.stringify({"t": "vars", "runners": runners}) + "\n"
# put_partial_data is non-blocking (returns as soon as a partial send happens when the buffer is full), avoiding put_data blocking the main thread
# the unsent portion is dropped (the next snapshot overwrites it; snapshot freshness beats completeness)
_client.put_partial_data(msg.to_utf8_buffer())
```

Design philosophy: **freshness > completeness**. Drop when the buffer is full; the next push 0.5s later overwrites wholesale, without blocking the main thread.

#### Runner Collection `_collect_runners()`

[Lines 181–199](../../../../core/fuse_runtime_bridge.gd):

```gdscript
var scene = get_tree().current_scene
if scene == null:
    return result

for runner in scene.find_children("*", "Runner", true, false):
    var ec = runner.get("current_execution_context")
    if ec == null or not is_instance_valid(ec):
        continue
    var vc = ec.get("_variable_context")
    if vc == null:
        continue
    result.append({
        "name": runner.name,
        "local": vc.get_all_local_variables_snapshot(),
        "scope": vc.get_all_scope_variables_snapshot()
    })
```

Data chain:

```
Runner.current_execution_context (ExecutionContext)
   └── ._variable_context (VariableContext)
         ├── get_all_local_variables_snapshot()  → Dictionary
         └── get_all_scope_variables_snapshot()  → Dictionary
```

> **Note**: `current_execution_context` is a property the Runner sets at runtime ([fuse_architecture_analysis.md:265](fuse_architecture_analysis.md)), and `_variable_context` is a private field of ExecutionContext. The running game side reads it via `Object.get(prop_name)` reflection, avoiding hard type coupling.

### 4.7 Relationship with GlobalVariableManager

**No direct interaction**. `FuseRuntimeBridge` collects only **Runner local / scope variables** (from `VariableContext`), **not** global variables.

Editor-side display of global variables takes **another path**: `FuseVariableWatcher._refresh()` reads directly through `GlobalVariableService` ([variable_watcher.gd:395-404](../../../../editor/debugging/variable_watcher.gd)), with no TCP bridge needed (because `GlobalVariableManager` is an Autoload — the editor process already holds a full copy).

| Variable scope | Data source | Via TCP bridge? |
|-----------|---------|---------------|
| local | `VariableContext.get_all_local_variables_snapshot()` | Yes (running game → editor) |
| scope | `VariableContext.get_all_scope_variables_snapshot()` | Yes |
| global | `GlobalVariableService.get_all_global_variables_info()` | No (the editor process reads GlobalVariableManager directly) |

---

## 5. How the Two Cooperate

### 5.1 Direct Call Relationships: None

`FuseEventBus` and `FuseRuntimeBridge` **never reference or call each other**. What they share is only infrastructure-level facts: "the Autoload registration mechanism" and "registration by the same bootstrap":

```gdscript
# fuse_runtime_bootstrap.gd
func setup() -> void:
    _register_event_bus()                # registers FuseEventBus
    _register_reflection_cache_cleanup() # registers node_removed → clears reflection caches
    _register_runtime_bridge()           # registers FuseRuntimeBridge
```

### 5.2 Responsibility Comparison

| Dimension | FuseEventBus | FuseRuntimeBridge |
|------|--------------|---------------------|
| Subsystem | Event communication (runtime business) | Debug reflection (development-time observation) |
| Data flow direction | Many-to-many (subscribe/publish) | One-way (running game → editor) |
| Communication medium | In-process (between objects in the same process) | Cross-process TCP + JSON |
| Active phase | Active in both editor and running game | Active only while the editor is open + the game is running |
| Affects business logic? | Yes (SendEvent / OnReceiveEvent depend on it) | No (observation only; disconnection does not affect game logic) |
| Public API | `send_event` / `subscribe` / `unsubscribe` / queries | `get_cached_vars()` |

### 5.3 The Shared Registration/Cleanup Host

Both are registered by `FuseRuntimeBootstrap`, and the **registration order** and **deregistration order** are symmetric (setup forward, teardown reverse), keeping dependencies correct (e.g. reflection cache cleanup requires the SceneTree to exist).

---

## 6. Design Intent and Trade-offs

### 6.1 Choosing Autoload over a Resource Singleton

Both `FuseEventBus` and `FuseRuntimeBridge` need Node lifecycle hooks:
- The former relies on `_ready` to hook `node_removed` automatically and on `_notification(PREDELETE)` as the safety net for clearing the subscription table
- The latter relies on `_ready` to start TCP, `_process` for throttled pushes, and `_exit_tree` to close connections

Resource singletons have none of these hooks and would need an external driver — an Autoload Node drives itself and is the most natural carrier.

### 6.2 Dual-Mode Autoload (FuseRuntimeBridge)

The same script branches into server / client via `Engine.is_editor_hint()`, **avoiding maintaining two copies of the code**. The cost is that readers must keep each snippet's execution environment in mind.

### 6.3 The Consumers' "Degraded Access" Convention

`SendEvent` / `OnReceiveEvent` / `FuseVariableWatcher` all use double protection of `get_node_or_null(name)` + `has_method`, **never using the Autoload name directly as a global variable**. Benefits:
- No hard crash when the Autoload is unregistered; an error code is returned (`FUSE_ERROR_EVENT_BUS_NOT_FOUND`)
- Easy to mock in unit tests (inject a same-named node)
- Avoids false positives from editor static analysis

### 6.4 TCP Bridge: Freshness > Completeness

The `put_partial_data` + 0.5s wholesale-overwrite design avoids buffer accumulation and main-thread blocking — the right trade-off for the variable snapshot scenario (monitoring may drop frames, but must not stutter).

### 6.5 Bounded History (FIFO 100 Entries)

`_event_history` uses `pop_front()` to implement FIFO, avoiding unbounded growth. A common pattern for embedded debuggers.

---

## 7. Potential Issues and Improvement Points

### 7.1 Double Registration of `node_removed` (To Be Confirmed)

As described in §2.7, `FuseEventBus._ready` and `FuseRuntimeBootstrap._register_reflection_cache_cleanup` **both** connect to `node_removed` in the editor process, with identical callback bodies. Worth confirming whether this is intentional (e.g. the autoload serving as the fallback on the running game side, where no bootstrap exists) or historical residue that can be cleaned up.

### 7.2 `send_event` Synchronous Blocking

If a subscriber callback runs a long task (`await`, networking, heavy computation), it blocks `SendEvent.execute()` and its ActionRunner. `send_event_deferred` only defers "sending" to the end of the frame; it does not solve single-callback blocking. Complex scenarios need their own splitting.

### 7.3 TCP Port Hardcoded at 24563

`BRIDGE_PORT` is a constant. If the port is taken (e.g. multiple Godot instances running at once), `_start_server` only `push_warning`s and fails silently; the editor-side watcher will show empty forever. Port probing/fallback or multi-instance isolation could be considered.

### 7.4 `get_cached_vars` Wholesale-Overwrite Semantics

Each push overwrites `_cached` wholesale. If the editor queries multiple times between running-game pushes, it may read a partially updated intermediate state (extremely unlikely, since a JSON line is an atomic unit). The current implementation is acceptable.

### 7.5 Verbose `SendEvent` Debug Logging

[send_event.gd:135-159](../../../../instructions/event/send_event.gd): `_resolve_args` contains many `_log_debug` lines, logging 3 lines per argument. In production with the DEBUG level left on, this produces substantial log noise.

---

## 8. Overall Assessment

### Strengths

1. **Clear responsibilities**: FuseEventBus = business communication, FuseRuntimeBridge = debug observation, no coupling between them
2. **Degradation-safe**: consumers uniformly double-protect with `get_node_or_null` + `has_method`, degrading gracefully when the Autoload is missing
3. **Dual-mode Autoload**: the same script branches via `Engine.is_editor_hint()`, saving code
4. **Robust TCP design**: sticky-packet handling, status judged after `poll()`, non-blocking `put_partial_data`, throttled pushes
5. **Plugin-managed registration**: the bootstrap dynamically adds/removes autoloads; users never edit `project.godot` by hand
6. **History and reflection cleanup**: FuseEventBus ships a 100-entry event history and node-deletion cache cleanup

### Weaknesses

1. `node_removed` is registered twice in the editor process (mild redundancy, to be confirmed)
2. `send_event` blocks synchronously; no timeout/async mechanism
3. TCP port hardcoded, no port-conflict handling
4. SendEvent's debug logs are overly verbose at the DEBUG level

---

**Maintained by**: Fuse development team
**Last updated**: 2026-07-07
**Version**: 1.0.0
