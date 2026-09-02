> 🌐 [**中文版**](../../../zh_CN/dev_docs/guides/event-bus-guide.md) | English

# FuseEventBus Event Bus Development Guide

> **Goal**: Provide developers with a complete guide to the FuseEventBus global event communication mechanism, covering event sending, subscribing, unsubscribing, and editor debugging.

**Audience**: Fuse system developers, contributors

**Last updated**: 2026-07-07

---

## 📋 Table of Contents

1. [System Overview](#system-overview)
2. [Architecture Design](#architecture-design)
3. [FuseEventBus API](#fuseeventbus-api)
4. [Subscription Class](#subscription-class)
5. [Integrated Components](#integrated-components)
6. [Usage Guide](#usage-guide)
7. [Debug Support](#debug-support)
8. [Best Practices](#best-practices)
9. [Common Pitfalls](#common-pitfalls)

---

## System Overview

`FuseEventBus` is the global event communication mechanism in Fuse, allowing different Triggers to communicate in a decoupled way through custom events. It is registered as a global singleton via Autoload and can be accessed anywhere directly through `FuseEventBus`.

> **Autoload singleton convention**
> `FuseEventBus` is registered as a global singleton via Autoload (no `class_name`); it can only be accessed directly by the Autoload name `FuseEventBus`.
> - ✅ `FuseEventBus.send_event("event_name", {})`
> - ❌ ~~`FuseEventBus.new()`~~ (no `class_name`, cannot be instantiated)
> - The `Subscription` object returned when subscribing to an event is only used for unsubscribing; no extra instantiation is needed.

### Core Files

| File | Class name | Purpose |
|------|------|------|
| `core/fuse_event_bus.gd` | `FuseEventBus extends Node` | Event bus (Autoload singleton) |

### Related Components

| File | Type | Purpose |
|------|------|------|
| `instructions/event/send_event.gd` | Instruction | Sends custom events |
| `events/event/on_receive_event.gd` | Event | Receives custom events |
| `tests/test_event_bus.gd` | Test | Event bus tests |

### Design Goals

- **Globally accessible**: registered via Autoload, no need to pass references manually
- **Decoupled communication**: publishers need not know about subscribers
- **Debug-friendly**: provides an event history and the `event_sent` signal for editor debugging
- **Deferred sending**: supports `call_deferred` to send events at the end of the current frame
- **Automatic cleanup**: clears all listeners on `NOTIFICATION_PREDELETE`

---

## Architecture Design

```
Sender (Trigger / instruction / GDScript)
        │
        │ FuseEventBus.send_event("event_name", {args})
        ▼
┌─────────────────────────────────────┐
│          FuseEventBus               │
│   (Autoload Node singleton)         │
│                                     │
│  _listeners: Dictionary             │
│  {event_name → [Subscription...]}   │
│                                     │
│  _event_history: Array[max 100]     │
│  {name, args, timestamp}            │
│                                     │
│  signal: event_sent(name, args)     │
└─────────────────────────────────────┘
        │
        ├─→ Notify all subscribers callback(args)
        │
        └─→ Record into the event history
                │
                ▼
        Editor debug tools (VariableWatcher, etc.)
```

### Message Flow

```
send_event("player_died", {"enemy": "boss"})
    │
    ├── _record_event("player_died", {"enemy": "boss"})
    │       → _event_history.append({name, args, timestamp})
    │       → exceeding MAX_HISTORY_SIZE(100) → pop_front()
    │
    ├── event_sent.emit("player_died", {"enemy": "boss"})
    │       → editor debug tools listen to this signal
    │
    └── iterate _listeners["player_died"]
            → subscription.callback.call({"enemy": "boss"})
            → skip callbacks with callback.is_valid() == false
```

---

## FuseEventBus API

**File location**: `addons/fuse/core/fuse_event_bus.gd`

**Class definition**:
```gdscript
extends Node  # Registered as a global singleton via Autoload
```

### Constants

```gdscript
const MAX_HISTORY_SIZE: int = 100  # Maximum number of history entries
```

### Signals

```gdscript
## Event sent signal (for editor debugging)
signal event_sent(event_name: String, args: Dictionary)
```

### Core Methods

```gdscript
## Send an event
## event_name: the event name (must not be empty)
## args: event arguments (optional, defaults to {})
func send_event(event_name: String, args: Dictionary = {}) -> void

## Send an event deferred (sent at the end of the current frame)
## event_name: the event name
## args: event arguments (optional)
func send_event_deferred(event_name: String, args: Dictionary = {}) -> void

## Subscribe to an event
## event_name: the name of the event to listen to
## callback: the callback function, receiving a Dictionary argument
## Returns: Subscription — used to unsubscribe
func subscribe(event_name: String, callback: Callable) -> Subscription

## Unsubscribe
## subscription: the subscription object to cancel
func unsubscribe(subscription: Subscription) -> void
```

### Query Methods

```gdscript
## Check whether an event has listeners
func has_listeners(event_name: String) -> bool

## Get the number of listeners for an event
## event_name: an empty string means get the total
func get_listener_count(event_name: String = "") -> int

## Get all registered event names
func get_registered_events() -> Array[String]

## Get the event history
func get_event_history() -> Array

## Clear the event history
func clear_history() -> void

## Clear all listeners
func clear_all_listeners() -> void
```

### Lifecycle

```gdscript
func _ready() -> void:
    # Register automatic cleanup for the runtime reflection cache
    get_tree().node_removed.connect(_on_node_removed_for_reflection_cache)

func _on_node_removed_for_reflection_cache(node: Node) -> void:
    # When a node is removed, automatically clean its entries from ReflectionCache and FunctionManager
    ReflectionCache.get_instance().clear_node(node)
    FunctionManager.clear_callable_cache(node)

func _notification(what: int) -> void:
    if what == NOTIFICATION_PREDELETE:
        _listeners.clear()
```

### Internal Methods

```gdscript
func _record_event(event_name: String, args: Dictionary) -> void
    # Record the event into the history, pop_front() when MAX_HISTORY_SIZE is exceeded
```

---

## Subscription Class

```gdscript
class Subscription extends RefCounted:
    var event_name: String
    var callback: Callable
    var id: int
    var paused: bool                ## Paused state: when true, sent events do not trigger this subscription's callback
```

`Subscription` is a simple data class holding the event name, the callback function, a unique ID, and the paused state. Unsubscribe via `unsubscribe(subscription)`. Setting `paused` to `true` temporarily disables the subscription without removing it.

---

## Integrated Components

### SendEvent Instruction

**File location**: `addons/fuse/instructions/event/send_event.gd`

```gdscript
# Inside instruction execution:
FuseEventBus.send_event(event_name, event_args)
```

### OnReceiveEvent Event

**File location**: `addons/fuse/events/event/on_receive_event.gd`

```gdscript
# When the event initializes:
FuseEventBus.subscribe(event_name, _on_event_received)
```

---

## Usage Guide

### Sending Events

```gdscript
# Basic send
FuseEventBus.send_event("boss_defeated", {"boss_name": "Dragon"})

# Deferred send (end of the current frame)
FuseEventBus.send_event_deferred("scene_loaded", {"scene_name": "level2"})

# Event without arguments
FuseEventBus.send_event("game_started")
```

### Subscribing to Events

```gdscript
var subscription = FuseEventBus.subscribe("boss_defeated", _on_boss_defeated)

func _on_boss_defeated(args: Dictionary) -> void:
    var boss_name = args.get("boss_name", "unknown")
    print("Boss defeated: %s" % boss_name)
```

### Unsubscribing

```gdscript
FuseEventBus.unsubscribe(subscription)
subscription = null  # Release the reference
```

### Querying and Debugging

```gdscript
# Check whether there are listeners
if FuseEventBus.has_listeners("boss_defeated"):
    print("有触发器在监听 boss_defeated 事件")

# Get the listener count
var total = FuseEventBus.get_listener_count()  # Total
var per_event = FuseEventBus.get_listener_count("boss_defeated")  # Specific event

# List registered events
print(FuseEventBus.get_registered_events())

# Get the history
var history = FuseEventBus.get_event_history()
for entry in history:
    print("%s: %s at %d" % [entry.name, entry.args, entry.timestamp])
```

---

## Debug Support

FuseEventBus provides two levels of interface for editor debugging:

### 1. The event_sent Signal

```gdscript
# Connect this signal in the editor to monitor events in real time
FuseEventBus.event_sent.connect(_on_event_sent)

func _on_event_sent(event_name: String, args: Dictionary) -> void:
    print("[EventBus] %s → %s" % [event_name, JSON.stringify(args)])
```

### 2. Event History

```gdscript
# Use get_event_history() to get the most recent 100 event records
var history = FuseEventBus.get_event_history()
for entry in history:
    var timestamp = entry.timestamp  # Time.get_ticks_msec()
    var name = entry.name
    var args = entry.args
```

### 3. VariableWatcher Integration

The event bus automatically connects the `node_removed` signal in `_ready()`; when a node is removed from the scene, its caches in `ReflectionCache` and `FunctionManager` are cleaned automatically.

---

## Best Practices

### 1. Event Naming Conventions

Name events in `snake_case`, grouped by system prefixes:

```gdscript
FuseEventBus.send_event("player_died")        # Player-related
FuseEventBus.send_event("scene_loaded")       # Scene-related
FuseEventBus.send_event("ui_button_clicked")  # UI-related
FuseEventBus.send_event("game_saved")         # Game-flow-related
```

### 2. Argument Conventions

```gdscript
# Use a Dictionary for event arguments with explicit key names
FuseEventBus.send_event("player_scored", {
    "points": 100,
    "enemy_type": "goblin",
    "combo_count": 5
})
```

### 3. Deferred Sending to Avoid Deadlocks

When sending events inside physics callbacks (`_physics_process`), use deferred sending to avoid event-loop issues within the current frame:

```gdscript
func _physics_process(delta):
    if detect_collision():
        FuseEventBus.send_event_deferred("player_hit", {"damage": 10})
```

### 4. Unsubscribe Promptly

Cancel unneeded subscriptions on scene changes or node release:

```gdscript
func _exit_tree():
    if _subscription:
        FuseEventBus.unsubscribe(_subscription)
        _subscription = null
```

### 5. Scene Changes with clear_all_listeners

```gdscript
func _on_scene_changed():
    # Clear all listeners on scene change
    FuseEventBus.clear_all_listeners()
```

---

## Common Pitfalls

### Pitfall 1: Subscription Callbacks Referencing Freed Objects

**Problem**: the callback object may have been freed while `Callback.is_valid()` still returns true.

**Solution**: FuseEventBus checks `callback.is_valid()` while iterating and skips invalid callbacks automatically. Still, when creating callbacks prefer weak references to the object or ensure proper lifecycle management.

### Pitfall 2: Forgetting to Unsubscribe Causes Memory Leaks

**Problem**: the subscription reference is kept after the node is freed, so the callback keeps being called.

**Solution**: unsubscribe in the node's `_exit_tree()` or `_notification(NOTIFICATION_PREDELETE)`.

### Pitfall 3: Event Names Are Case-Sensitive

`send_event("PlayerDied")` and `send_event("player_died")` are two different events. Keep naming consistent.

### Pitfall 4: Argument Mutations Affect History

`send_event` uses `args.duplicate()` to record history, but callbacks receive the **original reference**. If the passed-in Dictionary is modified afterwards, callbacks see the modified values.

**Solution**: if args may be modified after sending, use `args.duplicate()` to create a copy.

### Pitfall 5: MAX_HISTORY_SIZE Overflow

When events are sent frequently (every frame), the history only keeps the most recent 100 entries. Timestamp-based filtering should be implemented externally.

---

## Reference Documents

- [RuntimeBridge Development Guide](runtime-bridge-guide.md)
- [ExecutionContext and Diagnostics Guide](execution-context-diagnostics-guide.md)
- [FuseLogger Logging System Guide](fuse-logger-guide.md)
- [Event Creation Guide](event-creation-guide.md)

---

**Document maintainer**: Fuse development team | **Last updated**: 2026-07-07 | **Godot version**: 4.7
