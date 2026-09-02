> 🌐 [**中文版**](../../../zh_CN/dev_docs/guides/runtime-instance-migration-guide.md) | English

# Event RuntimeInstance Migration Guide

**Status:** Released
**Version:** 2.0
**Author:** Fuse Development Team
**Date:** 2026-06-17
**Keywords:** runtime-instance, migration, event, state-isolation, self-declared-state, _emit_triggered

---

## Overview

When you create an Event class (for example `OnMouseEnter`), you may be tempted to store some runtime state — such as `_is_hovered`. This works fine with a single Trigger, but when multiple Triggers share the same Event resource, their states overwrite each other.

The RuntimeInstance architecture solves this problem completely by separating the state from the Event resource into a lightweight `RuntimeEventInstance`.

**Core idea:**
- Event resource = pure configuration (`@export` variables)
- RuntimeEventInstance = runtime state (independent per Trigger)

**New architecture (self-declared state pattern):**
- The Event declares its own state via the `get_default_runtime_state()` method
- No core code changes needed (`RuntimeEventInstance`)
- Follows the Open/Closed Principle

---

## Migration Steps (New Pattern)

### Step 1: Identify State Variables

Find the runtime state variables in your Event class. They are usually member variables that track the event's trigger state.

```gdscript
class_name OnMyEvent extends BaseEvent

var _has_triggered: bool = false     # ❌ shared state
var _trigger_count: int = 0          # ❌ shared state
var _last_trigger_time: float = 0.0  # ❌ shared state
```

**Problem**: when two Triggers share this Event resource, the Trigger initialized later overwrites the state of the Trigger initialized first.

---

### Step 2: Remove the State Variables

Delete these state variables and add a reference to `RuntimeEventInstance`:

```gdscript
class_name OnMyEvent extends BaseEvent

# 🔧 Runtime state is now stored in RuntimeEventInstance
var _runtime_instance_ref: RuntimeEventInstance = null
```

**It's that simple**. There is no longer any need to store runtime state in the Event class.

---

### Step 3: Implement the get_default_runtime_state() Method

This is **the core of the new architecture**. Add the `get_default_runtime_state()` method to the Event to declare its state:

```gdscript
## Get the default runtime state
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["has_triggered"] = false
	base["trigger_count"] = 0
	base["last_trigger_time"] = 0.0
	return base
```

**Key points:**
- Call `super.get_default_runtime_state()` to get the base state (initialized, trigger_count, last_trigger_time)
- Add your Event-specific state
- Return the complete state dictionary

**Advantages:**
- ✅ No need to modify `RuntimeEventInstance._initialize_runtime_state()`
- ✅ State declarations are clear and explicit
- ✅ Users can create custom Events more easily

---

### Step 4: Implement the initialize_with_runtime_instance() Method

If your Event has runtime state, you need to implement the `initialize_with_runtime_instance()` method to receive the RuntimeEventInstance instance:

```gdscript
## Initialize the event with the runtime instance
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		return

	# 🔧 Save the RuntimeEventInstance reference
	_runtime_instance_ref = runtime_instance

	# Validate parameters
	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# Connect signals or set up listeners
	# ... your initialization logic ...

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})
```

**Key points**:
- Must check `Engine.is_editor_hint()` first
- Save `runtime_instance` into `_runtime_instance_ref`
- Use the passed-in `owner_node` parameter for initialization
- This is the entry point through which the Trigger invokes the Event

**When this method is required**:
- ✅ The Event has runtime state (i.e. it implements `get_default_runtime_state()`)
- ✅ The Event uses the RuntimeInstance architecture

**When it is not needed**:
- ⚠️ The Event is stateless (pure signal forwarding)
- ⚠️ The Event still uses the old `initialize()` method

**Backward compatibility**:
- If an Event does not implement `initialize_with_runtime_instance()`, the Trigger falls back to the old `initialize()` method
- This guarantees backward compatibility

---

### Step 5: Update State Access

From now on, all state access goes through `RuntimeEventInstance`:

**Reading state:**
```gdscript
func _on_event_triggered():
	# Use the RuntimeEventInstance state
	var has_triggered: bool = false
	if _runtime_instance_ref and _runtime_instance_ref.has_runtime_state("has_triggered"):
		has_triggered = _runtime_instance_ref.get_runtime_state("has_triggered")

	# Check the trigger condition
	if has_triggered:
		return

	# ... event logic ...
```

**Writing state:**
```gdscript
func _on_event_triggered():
	# ... event logic ...

	# Update the RuntimeEventInstance state
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("has_triggered", true)
		_runtime_instance_ref.set_runtime_state("trigger_count",
			_runtime_instance_ref.get_runtime_state("trigger_count", 0) + 1
		)
```

**It's that simple**. All state is now independent, with one copy per Trigger.

---

### Step 6: Clean Up State

Clean up the RuntimeEventInstance state in the `terminate()` and `reset()` methods:

```gdscript
func terminate(owner_node: Node) -> void:
	# Disconnect signals
	_disconnect_signals(owner_node)

	# Clean up the RuntimeEventInstance state
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("has_triggered", false)
		_runtime_instance_ref.set_runtime_state("trigger_count", 0)

	# Clean up references
	_runtime_instance_ref = null

	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

func reset() -> void:
	super.reset()

	# Reset the RuntimeEventInstance state
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("has_triggered", false)
		_runtime_instance_ref.set_runtime_state("trigger_count", 0)
```

**That's it!** Your Event class now uses the RuntimeInstance architecture.

---

## Complete Example

### Before: Old Architecture (Shared State Problem)

```gdscript
class_name OnMouseEnter extends BaseEvent

@export var target_node_path: NodePath = NodePath("")
@export var trigger_once_per_enter: bool = true

signal triggered(context: Node)

var _is_hovered: bool = false       # ❌ shared state
var _owner_node_ref: Node = null     # ❌ shared reference
var _signal_connections: Dictionary = {}

func initialize(owner_node: Node) -> void:
	_owner_node_ref = owner_node
	# ... connect signals ...

func _on_mouse_entered():
	# ❌ uses the shared state
	if trigger_once_per_enter and _is_hovered:
		return

	_is_hovered = true  # ❌ modifies the shared state

	triggered.emit(null)
```

**Problem**: when two Triggers share this Event resource, `_is_hovered` gets overwritten.

---

### After: New Architecture (State Isolation + Self-Declared State)

```gdscript
class_name OnMouseEnter extends BaseEvent

@export var target_node_path: NodePath = NodePath("")
@export var trigger_once_per_enter: bool = true

# Note: BaseEvent already defines the triggered(context: Node) signal; subclasses do not need to redeclare it

# ✅ Runtime state is stored in RuntimeEventInstance
var _runtime_instance_ref: RuntimeEventInstance = null
var _signal_connections: Dictionary = {}

## Get the default runtime state
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["is_hovered"] = false
	return base

func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		return

	# ✅ Save the RuntimeEventInstance reference
	_runtime_instance_ref = runtime_instance

	var target_node = owner_node.get_node_or_null(target_node_path)
	if not target_node:
		return

	_connect_hover_signals(target_node, owner_node)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

func _on_mouse_entered_with_context(owner: Node):
	# ✅ Use the RuntimeEventInstance state
	var is_hovered: bool = false
	if _runtime_instance_ref and _runtime_instance_ref.has_runtime_state("is_hovered"):
		is_hovered = _runtime_instance_ref.get_runtime_state("is_hovered")

	if trigger_once_per_enter and is_hovered:
		_log_debug_localized("FUSE_LOG_EVENT_ALREADY_ENTERED", {})
		return

	# ✅ Update the RuntimeEventInstance state
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("is_hovered", true)
		_runtime_instance_ref.update_trigger_stats()

	var target_node = owner.get_node_or_null(target_node_path)

	# ✅ Use _emit_triggered() to set the trigger meta automatically
	_emit_triggered(target_node, owner)

func terminate(owner_node: Node) -> void:
	# ... disconnect signals ...

	# ✅ Clean up the RuntimeEventInstance state
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("is_hovered", false)

	_runtime_instance_ref = null
```

**Advantage**: each Trigger has its own independent `is_hovered` state, with no interference. And **no RuntimeEventInstance changes are needed**!

---

## Common Patterns

### Pattern 1: State Declaration (Core of the New Pattern)

Implement the `get_default_runtime_state()` method in the Event:

```gdscript
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["state_key"] = default_value
	base["another_key"] = another_default
	return base
```

### Pattern 2: RuntimeInstance Initialization

Implement the `initialize_with_runtime_instance()` method to receive the RuntimeEventInstance instance:

```gdscript
## Initialize the event with the runtime instance
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		return

	# Save the RuntimeEventInstance reference
	_runtime_instance_ref = runtime_instance

	# Validate parameters
	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# Connect signals
	var target_node = owner_node.get_node_or_null(target_node_path)
	if not target_node:
		return

	if not target_node.some_signal.is_connected(_on_event_triggered):
		target_node.some_signal.connect(_on_event_triggered)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})
```

**Key points**:
- Check for editor mode
- Save the RuntimeEventInstance reference
- Validate owner_node
- Connect signals

### Pattern 3: State Access

Use `get_runtime_state()` to read and `set_runtime_state()` to write:

```gdscript
# Read
var value = _runtime_instance_ref.get_runtime_state("key", default_value)

# Check existence
if _runtime_instance_ref.has_runtime_state("key"):
	# the state exists
	pass

# Write
_runtime_instance_ref.set_runtime_state("key", new_value)
```

### Pattern 4: Signal Forwarding

Use `_emit_triggered()` to set the trigger meta automatically, without manually creating a temporary node:

```gdscript
# ✅ Recommended: use _emit_triggered() to set the trigger meta automatically
_emit_triggered(target_node, owner)

# If context and trigger_node are the same node:
_emit_triggered(owner_node, owner_node)
```

`_emit_triggered()` sets the `"trigger"` meta on the context, preventing the signal from being broadcast to other RuntimeEventInstances.

### Pattern 5: Handling Timer Objects

Node objects such as Timers are **not stored** in RuntimeEventInstance and are still managed in the Event class:

```gdscript
var _timer: Timer = null  # the Timer object stays in the Event class

## Get the default runtime state
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["current_count"] = 0  # only stores the counter state
	return base
```

---

## Old vs New Pattern Comparison

### Old Pattern (Deprecated) ❌

Requires modifying `RuntimeEventInstance._initialize_runtime_state()` to add a match branch:

```gdscript
# Add in RuntimeEventInstance.gd
match event_definition.get_event_type():
	"my_event":
		runtime_state["has_triggered"] = false
		runtime_state["trigger_count"] = 0
		runtime_state["last_trigger_time"] = 0.0
```

**Drawbacks:**
- Adding each Event requires modifying core code
- Violates the Open/Closed Principle
- Unfriendly to users creating custom Events
- Code is concentrated in the core class and hard to maintain

### New Pattern (Recommended) ✅

Implement the `get_default_runtime_state()` method in the Event:

```gdscript
# Add in the Event class
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["has_triggered"] = false
	base["trigger_count"] = 0
	base["last_trigger_time"] = 0.0
	return base
```

**Advantages:**
- ✅ No core code changes needed
- ✅ Follows the Open/Closed Principle
- ✅ Users can create custom Events more easily
- ✅ State declarations are clear and explicit
- ✅ Easy to maintain and extend

---

## Backward Compatibility

**Good news**: `RuntimeEventInstance` supports both the old and new patterns.

1. **New architecture (recommended)**: the Event implements the `get_default_runtime_state()` method
   - RuntimeEventInstance calls this method automatically
   - Gets the state declaration and initializes it

2. **Old architecture (backward compatible)**: the Event does not implement `get_default_runtime_state()`
   - RuntimeEventInstance initializes via match branches
   - Support for already-migrated Events is preserved

**Migration is incremental**:
- No need to migrate all Events at once
- You can selectively migrate Events with shared-state problems
- Old Events keep working

---

## Migration Checklist

- [ ] Remove the runtime state variables from the Event class (`_is_hovered`, `_has_exited`, etc.)
- [ ] Add the `_runtime_instance_ref: RuntimeEventInstance` reference
- [ ] Implement the `get_default_runtime_state()` method (**core step of the new pattern**)
- [ ] Implement the `initialize_with_runtime_instance()` method (receives the RuntimeEventInstance instance)
- [ ] Update all state access to use `get_runtime_state()` / `set_runtime_state()`
- [ ] Clean up the state in `terminate()` and `reset()`
- [ ] Test the scenario where multiple Triggers share the same Event resource
- [ ] Add the migration comment at the top of the Event file

---

## Adding the Migration Comment

After the migration is complete, add a comment at the top of the Event file:

```gdscript
## Event: OnMyEvent
##
## Migrated to RuntimeInstance: 2026-02-03
## State variables:
## - _has_triggered: bool - whether it has triggered
## - _trigger_count: int - trigger count
## - _last_trigger_time: float - last trigger time
##
## Related docs: addons/fuse/docs/migration-guide-to-runtime-instance.md
class_name OnMyEvent
extends BaseEvent
```

---

## Performance Impact

**Memory overhead:**
- Each `RuntimeEventInstance`: roughly 200-500 bytes
- 100 Triggers: roughly 50-110 KB
- **Impact is negligible**

**CPU overhead:**
- State access: dictionary lookup O(1), <1 microsecond
- Signal forwarding: one extra signal emission, <10 microseconds
- **Overall impact <1%**

---

## Examples of Migrated Events

The following Events have been migrated using the self-declared state pattern:

### 1. OnTimer
```gdscript
## Get the default runtime state
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["current_repeat_count"] = 0
	return base
```

### 2. OnInputKey
```gdscript
## Get the default runtime state
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["is_key_pressed"] = false
	base["has_triggered"] = false
	return base
```

### 3. OnInterval (Most Complex Example)
```gdscript
## Get the default runtime state
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["current_repeat_count"] = 0
	base["is_running"] = false
	base["is_completed"] = false
	base["last_input_time"] = 0.0
	return base
```

**Full list**:
- OnTimer
- OnInputKey
- OnArea2DEnter
- OnArea3DEntered
- OnSignalFromGroup
- OnPropertyChanged
- OnVariableChanged
- OnMouseButton
- OnCooldownFinished
- OnInterval
- OnMouseEnter
- OnMouseExit

---

## Related Resources

- [Runtime Instance Analysis](runtime-instruction-instance-guide.md) - The trigger trio architecture and state isolation
- Background on the Event resource sharing problem: see the "Overview" section of this document and the historical analysis (local archive)
- Quick start: just follow the "Migration Steps" section of this document in order
- [RuntimeEventInstance API](../../../../core/runtime_event_instance.gd) - Core class

---

## Changelog

### v2.1 (2026-06-17)
- 🔧 Fix examples: use `_emit_triggered()` instead of `triggered.emit()`
- 🔧 Remove the unnecessary `signal triggered` redeclaration in examples
- 🔧 Remove the anti-pattern of creating temporary nodes
- 🔗 Fix broken link references

### v2.0 (2026-02-03)
- ✨ Refactor to the self-declared state pattern
- ✨ Add documentation for the `get_default_runtime_state()` method
- ✨ Remove the match-branch migration approach (marked as deprecated)
- 🐛 Update migration steps and examples
- 📝 Add examples of 12 migrated Events

### v1.0 (2026-02-03)
- 🎉 Initial version (based on the match-branch pattern)

---

**After the migration, your Event class will have:**
- ✅ Fully independent state (per Trigger)
- ✅ A shareable configuration resource (memory savings)
- ✅ Backward compatibility (old code keeps working)
- ✅ A clean architecture (configuration and state separated)
- ✅ No core code changes needed

**It's that simple!**
