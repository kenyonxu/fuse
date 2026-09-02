> 🌐 [**中文版**](../../../zh_CN/dev_docs/guides/event-creation-guide.md) | English

# Fuse Event Creation Guide

> **Goal**: Provide developers with a complete guide to creating Fuse events, based on existing event implementation experience and best practices.
> **Authoritative spec**: The final authority for component generation is the [fuse-event-generator skill](../../../../agent_skills/fuse-event-generator/SKILL.md) (templates, naming prohibitions, and validation gates); this guide elaborates on its architectural principles.

**Audience**: Fuse system developers and contributors

**Last updated**: 2026-06-17

**Version**: v2.1 - Added the stopped signal, performance tracking documentation, fixed broken links

---

## 📋 Table of Contents

1. [Events vs Instructions](#events-vs-instructions)
2. [Naming Conventions](#naming-conventions)
3. [Icon Conventions](#icon-conventions)
4. [Required Methods](#required-methods)
5. [Optional Methods](#optional-methods)
6. [Complete Event Templates](#complete-event-templates)
7. [Creation Steps](#creation-steps)
8. [Best Practices](#best-practices)
9. [Common Pitfalls](#common-pitfalls)
10. [Testing Guide](#testing-guide)

---

## Events vs Instructions

Understanding the difference between an Event and an Instruction is the first step in creating an event.

| Feature | Event | Instruction |
|---------|-------|-------------|
| **Purpose** | Listens for conditions, triggers a response | Performs a concrete action |
| **Lifecycle** | `initialize_with_runtime_instance()` → `terminate()` | `execute()` → completed/cancelled/error |
| **Signals** | `triggered(context: Node)`, `stopped(reason, context)` | `finished` |
| **Execution state** | No execution state | PENDING/RUNNING/COMPLETED/CANCELLED/ERROR |
| **Cleanup timing** | Cleaned up in `terminate()` | Cleaned up in `_cleanup_resources()` |
| **Typical uses** | Detecting input, collisions, signals, etc. | Moving nodes, playing animations, setting variables, etc. |

**Core difference**:
- **Event** is "passive" - it waits for something to happen and then emits the `triggered` signal; it emits the `stopped` signal when its condition is met or when it is actively stopped
- **Instruction** is "active" - it performs an action and then emits the `finished` signal

---

## RuntimeInstance Architecture

**Recommended**: new events should use the RuntimeInstance architecture to manage runtime state.

**Why it is needed**:

When multiple Triggers share the same Event resource, an Event that carries runtime state (such as `_is_hovered`) runs into state pollution.

**Example**:
```
两个按钮（start 和 continue）共享同一个 OnMouseEnter 资源
1. start Trigger 初始化 → Event._is_hovered = false
2. continue Trigger 初始化 → Event._is_hovered = false（覆盖！）
3. 鼠标进入 start → continue 的状态被修改 ❌
```

**Solution**:

Use the RuntimeInstance architecture to move state out of the Event resource:

```
Event (Resource) = 纯配置（@export 变量）
RuntimeEventInstance (RefCounted) = 运行时状态（每个 Trigger 独立）
```

**Core advantages**:
- ✅ Complete state isolation (each Trigger has independent state)
- ✅ Resource sharing (configuration can still be shared, saving memory)
- ✅ Backward compatibility (the legacy `initialize()` method is preserved)
- ✅ Lightweight design (RefCounted, ~200-500 bytes per instance)

**How to adopt**:

See the "RuntimeInstance Architecture" and "Get Default Runtime State" sections below.

**New architecture (self-declared state pattern)**:

An Event declares its own state by implementing the `get_default_runtime_state()` method:

```gdscript
## Get the default runtime state (core method of the new architecture)
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["is_hovered"] = false
	base["trigger_count"] = 0
	return base
```

**Quick start**:

```gdscript
# ❌ Old way (shared-state problem)
var _is_hovered: bool = false

func _on_event_triggered():
    if _is_hovered:
        return
    _is_hovered = true

# ✅ New way (state isolation + self-declared state)
var _runtime_instance_ref: RuntimeEventInstance = null

## Declare the default runtime state
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["is_hovered"] = false
	return base

func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance):
    _runtime_instance_ref = runtime_instance
    # ... initialization ...

func _on_event_triggered():
    var is_hovered = _runtime_instance_ref.get_runtime_state("is_hovered", false)
    if is_hovered:
        return
    _runtime_instance_ref.set_runtime_state("is_hovered", true)
```

**Core advantages**:
- ✅ No need to modify `RuntimeEventInstance` core code
- ✅ Follows the Open/Closed Principle
- ✅ Makes it easier for users to create custom events

---

## Naming Conventions

**Important**: all Fuse events follow the naming conventions below to stay concise and consistent.

### File Naming

- **Event files**: use `snake_case`, **must add** the `on_` prefix
  - ✅ Correct: `on_ready.gd`, `on_input_key.gd`, `on_area_2d_enter.gd`
  - ❌ Wrong: `event_on_ready.gd`, `input_key_event.gd`, `area_2d_enter_event.gd`

### Class Naming

- **Class names**: use `PascalCase`, **must add** the `On` prefix
  - ✅ Correct: `class_name OnReady`, `class_name OnInputKey`, `class_name OnArea2DEnter`
  - ❌ Wrong: `class_name EventOnReady`, `class_name InputKeyEvent`, `class_name Area2DEnterEvent`

### Test File Naming

- **Test scripts**: `test_on_<event_name>.gd`
  - Examples: `test_on_ready.gd`, `test_on_input_key.gd`
- **Test scenes**: `test_on_<event_name>.tscn`
  - Examples: `test_on_ready.tscn`, `test_on_input_key.tscn`

### Consistency Principles

- Keep the file name, class name, and test file names based on the same base name
- Always use the `on_` / `On` prefix
- Keep names concise and readable

**Example**:
```
事件文件：   on_input_key.gd
类名：       class_name OnInputKey
测试脚本：   test_on_input_key.gd
测试场景：   test_on_input_key.tscn
```

---

## Icon Conventions

**Icon selection principle**: every event should have an icon configured to improve user experience and visualization.

### Icon Configuration Methods

**Recommended: use Godot built-in icons**
```gdscript
metadata.builtin_icon = "KeyKeyboard"  # 使用 Godot 内置图标名称
```

**Alternative: use a custom icon library**
```gdscript
metadata.custom_icon = "my_custom_icon"  # 使用导入的自定义图标
```

**Backward compatibility**
```gdscript
metadata.icon_name = "KeyKeyboard"  # 旧方式，仍然有效
metadata.icon = preload("res://icon.png")  # 直接指定纹理
```

### Built-in Icon Naming Reference

**Common icon names**:
- **Input events**: `KeyKeyboard`, `JoyButton`, `Mouse`
- **Scene events**: `HostNode`, `Scene`, `Play`
- **Physics events**: `CollisionShape2D`, `CollisionShape3D`, `PhysicsBody2D`, `PhysicsBody3D`
- **Signal events**: `Signals`, `Connect`, `Call`
- **Time events**: `Time`, `Timer`, `Clock`
- **Lifecycle**: `Refresh`, `Loop`, `Animation`
- **General**: `Script`, `Node`, `File`, `Folder`

**Full list**: see [icon-system-guide.md](icon-system-guide.md)

### Icon Configuration Steps

Configure the icon in `_get_event_metadata()`:

```gdscript
static func _get_event_metadata() -> EventMetadata:
    var metadata = EventMetadata.new()
    metadata.builtin_icon = "KeyKeyboard"  # 配置图标
    return metadata
```

---

## Required Methods

All events **must** implement the following methods, otherwise runtime or compile errors will occur.

### 1. `_update_resource_name()` - Update the Resource Name

**Marker**: `@abstract` - **must implement**

```gdscript
## Update the resource name (required)
##
## Update resource_name based on event properties; shown in the editor Inspector
func _update_resource_name():
    var parts = []
    parts.append("事件类型名称")
    if not some_property.is_empty():
        parts.append("'%s'" % some_property)
    resource_name = " ".join(parts)
```

**Purpose**:
- Displays a meaningful name in the event list
- Helps users identify and distinguish different event configurations

**Example**:
```gdscript
# Simple event
func _update_resource_name():
    resource_name = "On Ready With Delay: %s" % delay_seconds

# Complex event
func _update_resource_name():
    var key_name = _get_key_name()
    match key_event_type:
        0:  # 按下
            resource_name = "按键按下: %s" % key_name
        1:  # 释放
            resource_name = "按键释放: %s" % key_name
```

---

### 2. `initialize()` - Initialize the Event Listener

**Marker**: although not `@abstract`, **must be overridden**

```gdscript
## Initialize the event listener (required)
##
## Called by the Trigger in _ready() to "start" the event listener
## 'owner_node' is usually the Trigger node itself
## Subclasses connect signals here
##
## Parameters:
## - owner_node: Node - the Trigger node that owns this event
func initialize(owner_node: Node) -> void:
    # 1. Validate owner_node
    if not owner_node:
        _create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
        return

    # 2. Connect signals or set up listeners
    # Example: connect a node signal
    if not owner_node.some_signal.is_connected(_on_some_event):
        owner_node.some_signal.connect(_on_some_event)

    # 3. Log
    _log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})
```

**Purpose**:
- Sets up event listening (connects signals, sets up timers, etc.)
- Validates configuration parameters
- Initializes internal state

**Important**:
- Must validate that `owner_node` is valid
- Must log initialization
- Avoid connecting the same signal more than once

---

### 2.1. `initialize_with_runtime_instance()` - Initialize with a Runtime Instance (Recommended)

**Recommended**: for events with runtime state, prefer this method.

**Marker**: although not `@abstract`, overriding it is strongly recommended

```gdscript
## Initialize the event with a runtime instance (recommended)
##
## Called by the Trigger in _ready(); initializes the event with a RuntimeEventInstance
## This is part of the memory optimization, avoiding unnecessary resource duplication
##
## Parameters:
## - owner_node: Node - the Trigger node that owns this event
## - runtime_instance: RuntimeEventInstance - the runtime event instance
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
    # 1. Save the RuntimeEventInstance reference
    _runtime_instance_ref = runtime_instance

    # 2. Validate parameters
    if not owner_node:
        _create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
        return

    # 3. Connect signals or set up listeners
    # Example: connect a node signal
    if not owner_node.some_signal.is_connected(_on_some_event):
        owner_node.some_signal.connect(_on_some_event)

    # 4. Log
    _log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})
```

**Purpose**:
- Provides independent runtime state management (via RuntimeEventInstance)
- Allows multiple Triggers to share the same Event resource without state pollution
- Stays backward compatible (the BaseEvent default implementation calls `initialize()`)

**When to use it**:
- ✅ The event has runtime state (such as `_is_hovered`, `_has_triggered`)
- ✅ Multiple Triggers may share the same Event resource
- ✅ State isolation guarantees are needed

**When it is not needed**:
- ⚠️ The event is stateless (pure listening, stores no state)
- ⚠️ You are certain the event will not be shared by multiple Triggers

**State management example**:
```gdscript
# Read state from the RuntimeEventInstance
var is_hovered: bool = false
if _runtime_instance_ref and _runtime_instance_ref.has_runtime_state("is_hovered"):
    is_hovered = _runtime_instance_ref.get_runtime_state("is_hovered")

# Write state to the RuntimeEventInstance
if _runtime_instance_ref:
    _runtime_instance_ref.set_runtime_state("is_hovered", true)
    _runtime_instance_ref.set_runtime_state("trigger_count",
        _runtime_instance_ref.get_runtime_state("trigger_count", 0) + 1
    )
```

**Declare default state in the Event** (new architecture, recommended):

Implement the `get_default_runtime_state()` method in the Event class:

```gdscript
## Get the default runtime state
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["has_triggered"] = false
	base["trigger_count"] = 0
	base["last_trigger_time"] = 0.0
	return base
```

**Advantages**:
- ✅ No need to modify `RuntimeEventInstance` core code
- ✅ State declarations are clear and explicit
- ✅ Base state is obtained automatically (initialized, trigger_count, last_trigger_time)
- ✅ RuntimeEventInstance calls this method automatically

**Initialize state in RuntimeEventInstance** (legacy architecture, deprecated):

> ⚠️ **Note**: this is the legacy architecture and is deprecated. New events should use the self-declared state pattern above.

Add state initialization to the `_initialize_runtime_state()` method in `addons/fuse/core/runtime_event_instance.gd`:

```gdscript
func _initialize_runtime_state():
    match event_definition.get_event_type():
        "your_event":
            runtime_state["has_triggered"] = false
            runtime_state["trigger_count"] = 0
            runtime_state["last_trigger_time"] = 0.0
            _log_debug("YourEvent 状态已初始化")
```

---

### 3. `terminate()` - Clean Up the Event Listener

**Marker**: although not `@abstract`, **must be overridden**

```gdscript
## Clean up the event listener (required)
##
## Called by the Trigger in _exit_tree() to "tear down" the event listener
## This is necessary to prevent memory leaks
## Subclasses disconnect signals here
##
## Parameters:
## - owner_node: Node - the Trigger node that owns this event
func terminate(owner_node: Node) -> void:
    # 1. Disconnect all signal connections
    if owner_node and owner_node.some_signal.is_connected(_on_some_event):
        owner_node.some_signal.disconnect(_on_some_event)

    # 2. Clean up timers
    if _timer:
        if _timer.timeout.is_connected(_on_timer_timeout):
            _timer.timeout.disconnect(_on_timer_timeout)
        if owner_node and is_instance_valid(owner_node):
            owner_node.remove_child(_timer)
        _timer.queue_free()
        _timer = null

    # 3. Reset state
    _internal_state = false

    # 4. Log
    _log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})
```

**Purpose**:
- Disconnects all signal connections
- Cleans up timers, Tweens, and other resources
- Resets internal state
- Prevents memory leaks

**Important**:
- Must disconnect every signal connected in `initialize()`
- Must clean up all temporary nodes created (Timer, Tween, etc.)
- Use `is_instance_valid()` to check node validity
- Cleanup order: disconnect signals → remove child nodes → free resources

---

### 4. The `stopped` Signal and `notify_stopped()` — Event Stop Notification

**Signal**: `stopped(reason: String, context: Dictionary)`

Emitted when the event stops (for example, `OnInterval` stops because its condition is met or it reaches the maximum repeat count).

**Stop reason constants**:
```gdscript
STOP_REASON_CONDITION_MET  # 条件满足而停止
STOP_REASON_MAX_REPEATS    # 达到最大重复次数
STOP_REASON_MANUAL         # 手动停止
STOP_REASON_ERROR          # 因错误而停止
```

**Notification method**:

```gdscript
## Notify that the event stopped
##
## Call this method when the event stops; it emits the stopped signal and notifies the Trigger
##
## Parameters:
## - reason: String - the stop reason (use the STOP_REASON_* constants)
## - context: Dictionary - stop context information (optional)
func notify_stopped(reason: String, context: Dictionary = {}) -> void:
    # Emit the stopped signal
    stopped.emit(reason, context)

    # Notify the Trigger to emit the event_stopped signal
    if _trigger_ref:
        var stop_context = context.duplicate()
        stop_context["event"] = self
        stop_context["event_type"] = get_event_type()
        stop_context["event_description"] = get_description()
        if _trigger_ref.has_signal("event_stopped"):
            _trigger_ref.emit_signal("event_stopped", reason, stop_context)
```

**Usage example**:
```gdscript
# In a repeating event, stop when the maximum count is reached
func _on_event_triggered():
    if max_repeats > 0 and repeat_count >= max_repeats:
        notify_stopped(STOP_REASON_MAX_REPEATS, {"repeat_count": repeat_count})
        return
```

**Important**:
- Must be called after `set_trigger_ref()` (the Trigger sets it automatically during initialization)
- `notify_stopped()` automatically notifies the Trigger to emit the `event_stopped` signal
- The stop context information is used for debugging and logging

---

### 5. `_emit_triggered()` — Recommended Way to Emit the Event Trigger

**Use `_emit_triggered()` instead of emitting `triggered.emit()` directly**:

```gdscript
## Emit the triggered signal (sets the trigger meta automatically)
##
## This method sets the "trigger" meta on the context automatically, preventing the signal
## from being broadcast to other RuntimeEventInstances
## Intended for pooled objects and shared Event resources
##
## Parameters:
## - context: Node - the event context node
## - owner_node: Node - the Trigger node (optional if _trigger_ref is already set)
func _emit_triggered(context: Node, owner_node: Node = null) -> void:
    var trigger_node = owner_node if owner_node else _trigger_ref
    if context and trigger_node:
        context.set_meta("trigger", trigger_node)
    triggered.emit(context)
```

**Comparison**:
```gdscript
# ❌ Old way: emit directly, the trigger meta may be missing
triggered.emit(some_node)

# ✅ Recommended way: the trigger meta is set automatically
_emit_triggered(some_node)
# Or specify the owner_node
_emit_triggered(context_node, owner_node)
```

---

## Optional Methods

These methods are not mandatory, but implementing them is strongly recommended to provide full functionality.

### 1. `get_description()` - Get the Event Description

```gdscript
## Get the event description (recommended)
##
## Returns the event's description, shown in logs and debugging
##
## Returns:
## - String - the event description
func get_description() -> String:
    return "事件描述字符串"
```

**Example**:
```gdscript
func get_description() -> String:
    if delay_seconds > 0:
        return "场景就绪后 %.2f 秒触发" % delay_seconds
    else:
        return "场景就绪时触发"
```

---

### 2. `get_event_type()` - Get the Event Type

```gdscript
## Get the event type (recommended)
##
## Returns the event's unique type identifier
##
## Returns:
## - String - the event type name
func get_event_type() -> String:
    return "your_event_type"
```

**Naming suggestions**:
- Use `snake_case`
- Be concise and descriptive
- Examples: `"scene_ready"`, `"input_key"`, `"area_2d_enter"`

---

### 3. `get_event_category()` - Get the Event Category

```gdscript
## Get the event category (recommended)
##
## Returns the event's category information, used to organize events in the editor
##
## Returns:
## - String - the event category name
func get_event_category() -> String:
    return "your_category"
```

**Common categories**:
- `"scene"` - scene lifecycle events
- `"input"` - input events
- `"physics"` - physics events
- `"signal"` - signal events
- `"timer"` - timer events

---

### 4. `validate()` - Validate the Event Configuration

```gdscript
## Validate the event configuration (recommended)
##
## Checks that the event parameters are valid
##
## Returns:
## - Array[String] - an array of error messages; empty means validation passed
func validate() -> Array[String]:
    var errors: Array[String] = []

    # Add custom validation
    if some_property <= 0:
        errors.append("属性必须大于0")

    return errors
```

**Example**:
```gdscript
func validate() -> Array[String]:
    var errors: Array[String] = []

    # Validate the key code
    if key_code == KEY_NONE:
        errors.append("必须指定有效的按键代码")

    # Validate the numeric range
    if delay_seconds < 0:
        errors.append("延迟时间不能为负数")

    return errors
```

---

### 5. `reset()` - Reset the Event State

```gdscript
## Reset the event state (optional)
##
## Resets the event to its initial state so it can be reused
## Subclasses can override this method to reset specific state
func reset() -> void:
    super.reset()  # 调用父类重置
    # Reset custom state
    _has_triggered = false
    _is_key_pressed = false
```

**Use cases**:
- The event instance needs to be reused
- Clearing runtime state
- Preparing for the next trigger

---

### 6. `_get_event_metadata()` - Get the Event Metadata

```gdscript
## Get the event metadata (recommended)
##
## Static method that returns the event's metadata
## Used by the event selector and the editor display
##
## Returns:
## - EventMetadata - the event metadata object
static func _get_event_metadata() -> EventMetadata:
    var metadata = EventMetadata.new()
    metadata.name_key = "FUSE_EVENT_XXX_NAME"
    metadata.category_key = "FUSE_EVENT_CATEGORY_XXX"
    metadata.description_key = "FUSE_EVENT_XXX_DESC"
    metadata.keywords = ["keyword1", "keyword2"]
    metadata.builtin_icon = "Script"
    return metadata
```

**Metadata fields**:
- `name_key` - translation key for the event name
- `category_key` - translation key for the category name
- `description_key` - translation key for the description
- `keywords` - array of search keywords
- `builtin_icon` - built-in icon name

---

### 7. `_start_performance_track()` / `_stop_performance_track()` — Performance Tracking

**Purpose**: automatically tracks event execution time using `FusePerformanceTracker`.

```gdscript
## Start performance tracking
##
## Uses the event type as the tracking name, automatically tracking execution time for all events
## Example tracking names: OnProcess.on_process, OnPhysicsProcess.on_physics_process
##
## Parameters:
## - method_name: String - the method name (defaults to "execute")
func _start_performance_track(method_name: String = "execute") -> void:
    var track_name = "%s.%s" % [get_event_type(), method_name]
    FusePerformanceTracker.get_instance().start_track(track_name)

## Stop performance tracking
##
## Used in pairs with _start_performance_track
##
## Parameters:
## - method_name: String - the method name (must match _start_performance_track)
func _stop_performance_track(method_name: String = "execute") -> void:
    var track_name = "%s.%s" % [get_event_type(), method_name]
    FusePerformanceTracker.get_instance().stop_track(track_name)
```

**Usage example**:
```gdscript
func _on_event_triggered():
    _start_performance_track("trigger")
    # ... event handling logic ...
    _stop_performance_track("trigger")
    _emit_triggered(context_node)
```

**Important**:
- `_start_performance_track` and `_stop_performance_track` must be used in pairs
- The `method_name` parameter must match in both methods
- Tracking name format: `<event_type>.<method_name>` (e.g. `on_interval.trigger`)

---

## Complete Event Templates

### Simple Synchronous Event Template

```gdscript
@tool
@icon("res://addons/fuse/icons/builtin/Script.png")
extends BaseEvent
class_name EventSimpleTemplate

## Simple event template

# Parameter definitions
var target_node: NodePath = NodePath("")

# Internal state
var _target_node_ref: Node = null

## Update the resource name (required)
func _update_resource_name():
    resource_name = "简单事件: %s" % target_node

## Initialize the event listener (required)
func initialize(owner_node: Node) -> void:
    _log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

    # Validate owner_node
    if not owner_node:
        _create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
        return

    # Validate the target node
    if target_node.is_empty():
        _create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.CONFIGURATION_ERROR, {})
        return

    _target_node_ref = owner_node.get_node_or_null(target_node)
    if not _target_node_ref:
        _create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(target_node)})
        return

    # Connect the signal
    if not _target_node_ref.some_signal.is_connected(_on_event_triggered):
        _target_node_ref.some_signal.connect(_on_event_triggered)

    _log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## Clean up the event listener (required)
func terminate(owner_node: Node) -> void:
    # Disconnect signals
    if _target_node_ref and is_instance_valid(_target_node_ref):
        if _target_node_ref.some_signal.is_connected(_on_event_triggered):
            _target_node_ref.some_signal.disconnect(_on_event_triggered)

    # Clean up references
    _target_node_ref = null

    _log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## Event handler callback
func _on_event_triggered():
    _log_info_localized("FUSE_LOG_EVENT_TRIGGERED", {"event_type": get_event_type()})
    _emit_triggered(_target_node_ref)  # 推荐：自动设置 trigger meta

## Get the event description (recommended)
func get_description() -> String:
    return "当 %s 发生时触发" % str(target_node)

## Get the event type (recommended)
func get_event_type() -> String:
    return "simple_template"

## Get the event category (recommended)
func get_event_category() -> String:
    return "template"

## Validate the event configuration (recommended)
func validate() -> Array[String]:
    var errors: Array[String] = []

    if target_node.is_empty():
        errors.append("目标节点不能为空")

    return errors

## Get the event metadata (recommended)
static func _get_event_metadata() -> EventMetadata:
    var metadata = EventMetadata.new()
    metadata.name_key = "FUSE_EVENT_SIMPLE_TEMPLATE_NAME"
    metadata.category_key = "FUSE_EVENT_CATEGORY_TEMPLATE"
    metadata.description_key = "FUSE_EVENT_SIMPLE_TEMPLATE_DESC"
    metadata.keywords = ["template", "模板", "simple", "简单"]
    metadata.builtin_icon = "Script"
    return metadata
```

---

### Complex Asynchronous Event Template

```gdscript
@tool
@icon("res://addons/fuse/icons/builtin/Timer.png")
extends BaseEvent
class_name EventComplexTemplate

## Complex event template (with timer)

# Parameter definitions
@export var delay_seconds: float = 0.0:
    set(value):
        delay_seconds = value
        _update_resource_name()

@export var trigger_once: bool = false:
    set(value):
        trigger_once = value
        _update_resource_name()

# Internal state
var _timer: Timer = null
var _has_triggered: bool = false
var _owner_node_ref: Node = null

## Update the resource name (required)
func _update_resource_name():
    var once_text = " [仅一次]" if trigger_once else ""
    resource_name = "复杂事件: 延迟 %.2fs%s" % [delay_seconds, once_text]

## Initialize the event listener (required)
func initialize(owner_node: Node) -> void:
    _log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

    # Validate owner_node
    if not owner_node:
        _create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
        return

    _owner_node_ref = owner_node

    # Check whether inside the scene tree
    if owner_node.is_inside_tree():
        _start_timer()
    else:
        # Wait until inside the scene tree before starting
        owner_node.tree_entered.connect(_on_tree_entered)

    _log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## Clean up the event listener (required)
func terminate(owner_node: Node) -> void:
    # Disconnect the tree_entered connection
    if owner_node and owner_node.tree_entered.is_connected(_on_tree_entered):
        owner_node.tree_entered.disconnect(_on_tree_entered)

    # Clean up the timer
    _cleanup_timer()

    # Reset state
    _has_triggered = false
    _owner_node_ref = null

    _log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## Start the timer
func _start_timer():
    if not _owner_node_ref:
        return

    _cleanup_timer()

    if delay_seconds > 0:
        # Create the timer
        _timer = Timer.new()
        _timer.wait_time = delay_seconds
        _timer.one_shot = true
        _timer.timeout.connect(_on_timer_timeout)
        _owner_node_ref.add_child(_timer)
        _timer.start()
        _log_debug_localized("FUSE_LOG_EVENT_DELAY", {"delay": delay_seconds})
    else:
        # Trigger immediately
        call_deferred("_deferred_trigger")

## Clean up the timer
func _cleanup_timer():
    if _timer:
        # Stop the timer first
        _timer.stop()

        # Disconnect the signal
        if _timer.timeout.is_connected(_on_timer_timeout):
            _timer.timeout.disconnect(_on_timer_timeout)

        # Remove from the scene tree and free
        if _owner_node_ref and is_instance_valid(_owner_node_ref):
            _owner_node_ref.remove_child(_timer)

        _timer.queue_free()
        _timer = null

## When the node enters the scene tree
func _on_tree_entered():
    _start_timer()

## Timer timeout callback
func _on_timer_timeout():
    _trigger_event()

## Deferred trigger
func _deferred_trigger():
    _trigger_event()

## Trigger the event
func _trigger_event():
    # Check whether it should trigger only once
    if trigger_once and _has_triggered:
        _log_debug_localized("FUSE_LOG_EVENT_ALREADY_TRIGGERED", {})
        return

    _has_triggered = true
    _log_info_localized("FUSE_LOG_EVENT_TRIGGERED", {"event_type": get_event_type()})
    _emit_triggered(_owner_node_ref)  # 推荐：自动设置 trigger meta

## Get the event description (recommended)
func get_description() -> String:
    var once_text = trigger_once ? " (仅一次)" : ""
    if delay_seconds > 0:
        return "延迟 %.2f 秒后触发%s" % [delay_seconds, once_text]
    else:
        return "立即触发%s" % once_text

## Get the event type (recommended)
func get_event_type() -> String:
    return "complex_template"

## Get the event category (recommended)
func get_event_category() -> String:
    return "template"

## Validate the event configuration (recommended)
func validate() -> Array[String]:
    var errors: Array[String] = []

    if delay_seconds < 0:
        errors.append("延迟时间不能为负数")

    return errors

## Reset the event state (optional)
func reset() -> void:
    super.reset()
    _has_triggered = false
    if _timer:
        _timer.stop()
    _log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})

## Get the event metadata (recommended)
static func _get_event_metadata() -> EventMetadata:
    var metadata = EventMetadata.new()
    metadata.name_key = "FUSE_EVENT_COMPLEX_TEMPLATE_NAME"
    metadata.category_key = "FUSE_EVENT_CATEGORY_TEMPLATE"
    metadata.description_key = "FUSE_EVENT_COMPLEX_TEMPLATE_DESC"
    metadata.keywords = ["template", "模板", "complex", "复杂", "timer", "定时器", "delay", "延迟"]
    metadata.builtin_icon = "Timer"
    return metadata
```

---

### RuntimeInstance-Aware Event Template (Recommended)

```gdscript
@tool
@icon("res://addons/fuse/icons/builtin/Script.png")
extends BaseEvent
class_name OnRuntimeInstanceTemplate

## RuntimeInstance-aware event template
##
## This template shows how to use RuntimeEventInstance to manage runtime state
## Suitable for events with runtime state, or events that may be shared by multiple Triggers
##
## Migrated to RuntimeInstance: 2026-02-03
## State variables:
## - _has_triggered: bool - whether it has triggered
## - _trigger_count: int - number of triggers
##
## Architecture version: self-declared state pattern v2.0

# Parameter definitions
@export var target_node_path: NodePath = NodePath("")
@export var trigger_once_per_activation: bool = true

# 🔧 Runtime state is now stored in the RuntimeEventInstance
var _runtime_instance_ref: RuntimeEventInstance = null
var _signal_connections: Dictionary = {}

## Update the resource name (required)
func _update_resource_name():
    var once_text = " [仅一次]" if trigger_once_per_activation else ""
    resource_name = "RuntimeInstance 模板: %s%s" % [target_node_path, once_text]

## Get the default runtime state (core method of the new architecture)
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["has_triggered"] = false
	base["trigger_count"] = 0
	return base

## Initialize the event with a runtime instance (recommended)
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
    if Engine.is_editor_hint():
        return

    # 🔧 Save the RuntimeEventInstance reference
    _runtime_instance_ref = runtime_instance

    # Validate parameters
    if not owner_node:
        _create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
        return

    # Validate the target node
    if target_node_path.is_empty():
        _create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.CONFIGURATION_ERROR, {})
        return

    var target_node = owner_node.get_node_or_null(target_node_path)
    if not target_node:
        _create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(target_node_path)})
        return

    # Connect signals
    _connect_signals(target_node, owner_node)

    _log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## Clean up the event listener (required)
func terminate(owner_node: Node) -> void:
    # Disconnect all signal connections
    _disconnect_signals()

    # 🔧 Clean up the RuntimeEventInstance state
    if _runtime_instance_ref:
        _runtime_instance_ref.set_runtime_state("has_triggered", false)
        _runtime_instance_ref.set_runtime_state("trigger_count", 0)

    # Clean up references
    _runtime_instance_ref = null

    _log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## Event handler callback
func _on_event_triggered(context: Node):
    _log_info_localized("FUSE_LOG_EVENT_TRIGGERED", {"event_type": get_event_type()})

    # 🔧 Use the RuntimeEventInstance state
    var has_triggered: bool = false
    if _runtime_instance_ref and _runtime_instance_ref.has_runtime_state("has_triggered"):
        has_triggered = _runtime_instance_ref.get_runtime_state("has_triggered")

    # Check the trigger condition
    if trigger_once_per_activation and has_triggered:
        _log_debug_localized("FUSE_LOG_EVENT_ALREADY_TRIGGERED", {})
        return

    # 🔧 Update the RuntimeEventInstance state
    if _runtime_instance_ref:
        _runtime_instance_ref.set_runtime_state("has_triggered", true)
        _runtime_instance_ref.set_runtime_state("trigger_count",
            _runtime_instance_ref.get_runtime_state("trigger_count", 0) + 1
        )
        _runtime_instance_ref.set_runtime_state("last_trigger_time", Time.get_unix_time_from_system())
        _runtime_instance_ref.update_trigger_stats()

    # Emit the event signal
    _emit_triggered(context)  # 推荐：自动设置 trigger meta

## Connect signals
func _connect_signals(target_node: Node, owner: Node) -> void:
    # Example: connect the mouse_entered signal
    if target_node.has_signal("mouse_entered") and not target_node.mouse_entered.is_connected(_on_event_triggered):
        target_node.mouse_entered.connect(_on_event_triggered.bind(owner))
        _signal_connections[target_node] = "mouse_entered"

## Disconnect signals
func _disconnect_signals() -> void:
    for target_node in _signal_connections:
        if is_instance_valid(target_node):
            var signal_name = _signal_connections[target_node]
            if target_node.has_signal(signal_name):
                var signal_info = target_node.get_signal_list().filter(func(s): return s.name == signal_name)[0]
                if signal_info and target_node.signal_name.is_connected(_on_event_triggered):
                    target_node.signal_name.disconnect(_on_event_triggered)

    _signal_connections.clear()

## Get the event description (recommended)
func get_description() -> String:
    if trigger_once_per_activation:
        return "当 %s 被激活时触发（仅一次）" % str(target_node_path)
    else:
        return "当 %s 被激活时触发" % str(target_node_path)

## Get the event type (recommended)
func get_event_type() -> String:
    return "runtime_instance_template"

## Get the event category (recommended)
func get_event_category() -> String:
    return "template"

## Validate the event configuration (recommended)
func validate() -> Array[String]:
    var errors: Array[String] = []

    if target_node_path.is_empty():
        errors.append("目标节点路径不能为空")

    return errors

## Reset the event state (optional)
func reset() -> void:
    super.reset()

    # 🔧 Reset the RuntimeEventInstance state
    if _runtime_instance_ref:
        _runtime_instance_ref.set_runtime_state("has_triggered", false)
        _runtime_instance_ref.set_runtime_state("trigger_count", 0)

    _log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})

## Get the event metadata (recommended)
static func _get_event_metadata() -> EventMetadata:
    var metadata = EventMetadata.new()
    metadata.name_key = "FUSE_EVENT_RUNTIME_INSTANCE_TEMPLATE_NAME"
    metadata.category_key = "FUSE_EVENT_CATEGORY_TEMPLATE"
    metadata.description_key = "FUSE_EVENT_RUNTIME_INSTANCE_TEMPLATE_DESC"
    metadata.keywords = ["template", "模板", "runtime", "运行时", "instance", "实例"]
    metadata.builtin_icon = "Script"
    return metadata
```

**Key differences** (compared with the simple template):
- ✅ Uses `initialize_with_runtime_instance()` instead of `initialize()`
- ✅ Implements `get_default_runtime_state()` to declare state (core of the new version)
- ✅ Manages state through `RuntimeEventInstance`
- ✅ Multiple Triggers can share the same Event resource
- ✅ State is fully isolated, no pollution risk
- ✅ **No need to modify `RuntimeEventInstance` core code**

**Migration checklist** (new version):
- [ ] Remove runtime state variables from the Event class (such as `_has_triggered`)
- [ ] Add the `_runtime_instance_ref: RuntimeEventInstance` reference
- [ ] ⭐ **Implement the `get_default_runtime_state()` method (core of the new version)**
- [ ] Implement the `initialize_with_runtime_instance()` method
- [ ] Change all state access to use `get_runtime_state()` / `set_runtime_state()`
- [ ] Clean up state in `terminate()` and `reset()`

---

## Creation Steps

### Step 1: Create the Event Class Skeleton

Create the event file `addons/fuse/events/on_<your_event_name>.gd`:

```gdscript
@tool
@icon("res://addons/fuse/icons/builtin/Script.png")
extends BaseEvent
class_name OnYourEventName

## Event description

# Parameter definitions
@export var your_property: String = ""

## Update the resource name (required)
func _update_resource_name():
    resource_name = "Your Event Name: %s" % your_property

## Initialize the event listener (required)
func initialize(owner_node: Node) -> void:
    # TODO: implement initialization logic
    pass

## Clean up the event listener (required)
func terminate(owner_node: Node) -> void:
    # TODO: implement cleanup logic
    pass
```

### Step 2: Implement the Core Methods

**2.1 Implement `initialize()`**:
```gdscript
func initialize(owner_node: Node) -> void:
    _log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

    # Validate owner_node
    if not owner_node:
        _create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
        return

    # Connect signals or set up listeners
    # ...

    _log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})
```

**2.2 Implement `terminate()`**:
```gdscript
func terminate(owner_node: Node) -> void:
    # Disconnect all signal connections
    # ...

    # Clean up timers and other resources
    # ...

    _log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})
```

**2.3 Implement the event handler callback**:
```gdscript
func _on_event_triggered():
    _log_info_localized("FUSE_LOG_EVENT_TRIGGERED", {"event_type": get_event_type()})
    _emit_triggered(context_node)  # 推荐：自动设置 trigger meta
```

### Step 3: Add Localization Translations

Add to `addons/fuse/localization/translations.csv`:

```csv
key,zh_CN,en_US
FUSE_EVENT_YOUR_EVENT_NAME,你的事件名称,Your Event Name
FUSE_EVENT_CATEGORY_YOUR_CATEGORY,你的分类,Your Category
FUSE_EVENT_YOUR_EVENT_DESC,事件描述,Event description
FUSE_LOG_EVENT_YOUR_EVENT_TRIGGERED,事件已触发,Event triggered
FUSE_ERROR_YOUR_EVENT_ERROR,错误消息,Error message
```

**Note**:
- Use the `NAME` suffix for event names
- Use the `DESC` suffix for event descriptions
- Use the `LOG_EVENT_` prefix for log messages
- Use the `ERROR_` suffix for error messages
- All placeholders use the `{variable_name}` format

### Step 4: Create the Test Scene

**Step 4.1: Create the test scene file**

Create `tests/events/test_<event_name>.tscn`:

```gdscript
[gd_scene load_steps=2 format=3 uid="uid://test_xxx"]

[ext_resource type="Script" path="res://tests/events/test_xxx.gd" id="1"]

[node name="TestXxx" type="Node"]
script = ExtResource("1")

[node name="Trigger" type="Node" parent="."]
```

**Step 4.2: Create the test script**

Create `tests/events/test_on_<event_name>.gd`:

```gdscript
extends Node

## OnYourEventName event tests

func _ready():
    print("=== Testing OnYourEventName ===")
    test_basic_functionality()
    test_edge_cases()
    print("=== All OnYourEventName tests passed! ===")

func test_basic_functionality():
    print("Test 1: Basic functionality")

    var event_script = load("res://addons/fuse/events/on_your_event_name.gd")
    var event = event_script.new()
    event.your_property = "test_value"

    var trigger = Node.new()
    add_child(trigger)

    # Connect the event signal
    var triggered = false
    event.triggered.connect(func():
        triggered = true
        print("  Event triggered!")
    )

    # Initialize the event
    event.initialize(trigger)
    await get_tree().process_frame

    # Verify the results
    assert(condition, "Verification message")
    print("  ✓ Test 1 passed\n")

    # Clean up
    event.terminate(trigger)
    trigger.queue_free()

func test_edge_cases():
    print("Test 2: Edge cases")
    # Test edge cases...
    print("  ✓ Test 2 passed\n")
```

### Step 5: RuntimeInstance Migration (Recommended)

**Why migrate**:
- ✅ Complete state isolation (each Trigger has independent state)
- ✅ Resource sharing (configuration can still be shared, saving memory)
- ✅ Multiple Triggers can share the same Event resource
- ✅ Lightweight design (RefCounted, ~200-500 bytes per instance)
- ✅ **No core code changes needed (new self-declared state pattern)**

**Quick migration steps (new version: self-declared state pattern)**:

**5.1 Remove the state variables**:
```gdscript
# ❌ Delete these runtime state variables
var _has_triggered: bool = false
var _trigger_count: int = 0
var _last_trigger_time: float = 0.0

# ✅ Add the RuntimeEventInstance reference
var _runtime_instance_ref: RuntimeEventInstance = null
```

**5.2 Implement the `get_default_runtime_state()` method** (⭐ **core step of the new version**):
```gdscript
## Get the default runtime state
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["has_triggered"] = false
	base["trigger_count"] = 0
	base["last_trigger_time"] = 0.0
	return base
```

**Advantages**:
- ✅ No need to modify `RuntimeEventInstance` core code
- ✅ State declarations are clear and explicit
- ✅ Base state is obtained automatically

**5.3 Implement `initialize_with_runtime_instance()`**:
```gdscript
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
    # ... remaining initialization logic ...

    _log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})
```

**5.4 Change state access**:
```gdscript
# ❌ Old way: use member variables directly
if _has_triggered:
    return
_has_triggered = true

# ✅ New way: go through the RuntimeEventInstance
var has_triggered: bool = false
if _runtime_instance_ref and _runtime_instance_ref.has_runtime_state("has_triggered"):
    has_triggered = _runtime_instance_ref.get_runtime_state("has_triggered")

if has_triggered:
    return

if _runtime_instance_ref:
    _runtime_instance_ref.set_runtime_state("has_triggered", true)
```

**5.5 Clean up the state**:
```gdscript
func terminate(owner_node: Node) -> void:
    # Disconnect signals
    # ... remaining cleanup logic ...

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

**Migration checklist** (new version):
- [ ] Remove runtime state variables from the Event class
- [ ] Add the `_runtime_instance_ref: RuntimeEventInstance` reference
- [ ] ⭐ **Implement the `get_default_runtime_state()` method (core of the new version)**
- [ ] Implement the `initialize_with_runtime_instance()` method
- [ ] Change all state access to use `get_runtime_state()` / `set_runtime_state()`
- [ ] Clean up state in `terminate()` and `reset()`
- [ ] Test the scenario where multiple Triggers share the same Event resource

---

### Step 6: Test Verification

1. Open the test scene in Godot
2. Run the tests and confirm all test cases pass
3. Check that the Inspector display in the editor is correct
4. Verify that localization takes effect
5. Verify that resources are cleaned up correctly (no memory leaks)
6. **If migrated to RuntimeInstance**: test multiple Triggers sharing the same Event resource

---

## Best Practices

### 1. Signal Management

**Principle**: every signal connection must be disconnected in `terminate()`.

```gdscript
# ✅ Good practice
func initialize(owner_node: Node):
    if not owner_node.some_signal.is_connected(_on_callback):
        owner_node.some_signal.connect(_on_callback)

func terminate(owner_node: Node):
    if owner_node and owner_node.some_signal.is_connected(_on_callback):
        owner_node.some_signal.disconnect(_on_callback)
```

```gdscript
# ❌ Avoid duplicate connections
func initialize(owner_node: Node):
    owner_node.some_signal.connect(_on_callback)  # 可能重复连接
```

### 2. Resource Cleanup

**Principle**: every resource created in `initialize()` must be cleaned up in `terminate()`.

```gdscript
# ✅ Good practice
func terminate(owner_node: Node):
    if _timer:
        _timer.stop()
        if _timer.timeout.is_connected(_on_timer_timeout):
            _timer.timeout.disconnect(_on_timer_timeout)
        if owner_node and is_instance_valid(owner_node):
            owner_node.remove_child(_timer)
        _timer.queue_free()
        _timer = null
```

```gdscript
# ❌ Missing cleanup
func terminate(owner_node: Node):
    if _timer:
        _timer.queue_free()  # 忘记断开信号和移除子节点
        _timer = null
```

### 3. Node Validity Checks

**Principle**: use `is_instance_valid()` to check validity before using node references.

```gdscript
# ✅ Good practice
func terminate(owner_node: Node):
    if _target_node and is_instance_valid(_target_node):
        if _target_node.some_signal.is_connected(_on_callback):
            _target_node.some_signal.disconnect(_on_callback)
```

```gdscript
# ❌ No validity check
func terminate(owner_node: Node):
    if _target_node:
        _target_node.some_signal.disconnect(_on_callback)  # 可能已释放
```

### 4. Error Handling

**Principle**: all errors should use localized error messages.

```gdscript
# ✅ Good practice
if not owner_node:
    _create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
    return
```

```gdscript
# ❌ Avoid hardcoding
if not owner_node:
    push_error("Owner node is null")  # 不推荐
    return
```

### 5. Logging

**Principle**: use the localized logging methods for key operations.

```gdscript
# ✅ Good practice
func initialize(owner_node: Node):
    _log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})
    # ...

func _on_event_triggered():
    _log_info_localized("FUSE_LOG_EVENT_TRIGGERED", {"event_type": get_event_type()})
    _emit_triggered(context_node)  # 推荐：自动设置 trigger meta
```

### 6. Property Validation

**Principle**: validate configuration parameters with the `validate()` method.

```gdscript
# ✅ Good practice
func validate() -> Array[String]:
    var errors: Array[String] = []

    if target_path.is_empty():
        errors.append("目标路径不能为空")

    if delay_seconds < 0:
        errors.append("延迟时间不能为负数")

    return errors
```

### 7. State Reset

**Principle**: implement the `reset()` method to support event reuse.

```gdscript
# ✅ Good practice
func reset() -> void:
    super.reset()
    _has_triggered = false
    _is_active = false
    if _timer:
        _timer.stop()
    _log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})
```

### 8. Editor Mode Checks

**Principle**: check the editor mode in `initialize()`.

```gdscript
# BaseEvent already handles the editor check
# Subclasses need no extra handling
func initialize(owner_node: Node) -> void:
    # BaseEvent skips initialization in editor mode
    # Just implement the runtime logic
    ...
```

---

### 9. RuntimeInstance State Management

**Principle**: use the RuntimeInstance architecture to manage stateful events.

```gdscript
# ✅ Good practice: manage state with RuntimeInstance (new: self-declared state pattern)
var _runtime_instance_ref: RuntimeEventInstance = null

## Get the default runtime state (core method of the new architecture)
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["has_triggered"] = false
	return base

func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance):
    _runtime_instance_ref = runtime_instance
    # ...

func _on_event_triggered():
    var has_triggered = _runtime_instance_ref.get_runtime_state("has_triggered", false)
    if has_triggered:
        return
    _runtime_instance_ref.set_runtime_state("has_triggered", true)
```

```gdscript
# ❌ Avoid storing runtime state directly in the Event
var _has_triggered: bool = false  # 多个 Trigger 共享此 Event 时会冲突

func _on_event_triggered():
    if _has_triggered:  # 可能读取到其他 Trigger 的状态
        return
    _has_triggered = true  # 可能覆盖其他 Trigger 的状态
```

**State access pattern**:
```gdscript
# Read state (with a default value)
var value = _runtime_instance_ref.get_runtime_state("key", default_value)

# Check whether the state exists
if _runtime_instance_ref.has_runtime_state("key"):
    # State exists
    pass

# Write state
_runtime_instance_ref.set_runtime_state("key", new_value)
```

**New architecture advantages** (self-declared state pattern):
- ✅ The event declares state via `get_default_runtime_state()`
- ✅ No need to modify `RuntimeEventInstance` core code
- ✅ Follows the Open/Closed Principle
- ✅ Makes it easier for users to create custom events

**When to use RuntimeInstance**:
- ✅ The event has runtime state (such as `_is_hovered`, `_has_triggered`)
- ✅ Multiple Triggers may share the same Event resource
- ✅ State isolation guarantees are needed

**When not to use it**:
- ⚠️ The event is stateless (pure listening, stores no state)
- ⚠️ You are certain the event will not be shared by multiple Triggers (saves memory)

---

## Common Pitfalls

### Pitfall 1: Forgetting to Disconnect Signals

**Problem**:
```gdscript
func initialize(owner_node: Node):
    owner_node.some_signal.connect(_on_callback)

func terminate(owner_node: Node):
    # ❌ Forgot to disconnect the signal
    pass
```

**Consequence**: the signal stays connected, which can cause memory leaks or unexpected triggers.

**Solution**:
```gdscript
func terminate(owner_node: Node):
    if owner_node and owner_node.some_signal.is_connected(_on_callback):
        owner_node.some_signal.disconnect(_on_callback)
```

---

### Pitfall 2: Timer Not Cleaned Up Properly

**Problem**:
```gdscript
func terminate(owner_node: Node):
    _timer.queue_free()  # ❌ 忘记断开信号和移除子节点
    _timer = null
```

**Consequence**: the Timer may still be running, causing errors or memory leaks.

**Solution**:
```gdscript
func terminate(owner_node: Node):
    if _timer:
        _timer.stop()
        if _timer.timeout.is_connected(_on_timer_timeout):
            _timer.timeout.disconnect(_on_timer_timeout)
        if owner_node and is_instance_valid(owner_node):
            owner_node.remove_child(_timer)
        _timer.queue_free()
        _timer = null
```

---

### Pitfall 3: Node References Not Validity-Checked

**Problem**:
```gdscript
func terminate(owner_node: Node):
    _target_node.some_signal.disconnect(_on_callback)  # ❌ 节点可能已释放
```

**Consequence**: accessing an already-freed node causes an error.

**Solution**:
```gdscript
func terminate(owner_node: Node):
    if _target_node and is_instance_valid(_target_node):
        if _target_node.some_signal.is_connected(_on_callback):
            _target_node.some_signal.disconnect(_on_callback)
```

---

### Pitfall 4: Connecting a Signal Multiple Times

**Problem**:
```gdscript
func initialize(owner_node: Node):
    owner_node.some_signal.connect(_on_callback)  # ❌ 每次调用都连接
```

**Consequence**: the signal callback gets invoked multiple times.

**Solution**:
```gdscript
func initialize(owner_node: Node):
    if not owner_node.some_signal.is_connected(_on_callback):
        owner_node.some_signal.connect(_on_callback)
```

---

### Pitfall 5: Wrong Cleanup Order

**Problem**:
```gdscript
func terminate(owner_node: Node):
    if owner_node:
        owner_node.remove_child(_timer)  # ❌ 先移除子节点
    if _timer.timeout.is_connected(_on_timer_timeout):
        _timer.timeout.disconnect(_on_timer_timeout)  # 后断开信号（可能失败）
```

**Consequence**: disconnecting the signal may fail.

**Solution**:
```gdscript
func terminate(owner_node: Node):
    if _timer:
        if _timer.timeout.is_connected(_on_timer_timeout):
            _timer.timeout.disconnect(_on_timer_timeout)  # 先断开信号
        if owner_node and is_instance_valid(owner_node):
            owner_node.remove_child(_timer)  # 后移除子节点
        _timer.queue_free()
```

**Cleanup order**: disconnect signals → remove child nodes → free resources

---

### Pitfall 6: Forgetting to Emit the Signal

**Problem**:
```gdscript
func _on_event_triggered():
    # ❌ Forgot to emit the triggered signal
    _log_info("Event triggered!")
```

**Consequence**: the Trigger never learns that the event fired, so instructions are not executed.

**Solution**:
```gdscript
func _on_event_triggered():
    _log_info_localized("FUSE_LOG_EVENT_TRIGGERED", {"event_type": get_event_type()})
    _emit_triggered(context_node)  # ✅ 发出信号（推荐使用 _emit_triggered 自动设置 trigger meta）
```

---

### Pitfall 7: Performing Expensive Operations in initialize

**Problem**:
```gdscript
func initialize(owner_node: Node):
    # ❌ Expensive operations during initialization
    for i in range(10000):
        some_heavy_computation()
```

**Consequence**: scene startup stutters.

**Solution**:
```gdscript
func initialize(owner_node: Node):
    # ✅ Only set up listeners; do not perform expensive operations
    if not owner_node.some_signal.is_connected(_on_callback):
        owner_node.some_signal.connect(_on_callback)
```

---

### Pitfall 8: Required Methods Not Implemented

**Problem**:
```gdscript
@tool
extends BaseEvent
class_name MyEvent

# ❌ Forgot to implement _update_resource_name()
# ❌ Forgot to implement initialize()
# ❌ Forgot to implement terminate()
```

**Consequence**:
- Compile error (`_update_resource_name()` is `@abstract`)
- Runtime error (`initialize()` and `terminate()` have default error implementations)

**Solution**:
```gdscript
@tool
extends BaseEvent
class_name MyEvent

# ✅ Implement all required methods
func _update_resource_name():
    resource_name = "My Event"

func initialize(owner_node: Node) -> void:
    # Implement the initialization logic
    pass

func terminate(owner_node: Node) -> void:
    # Implement the cleanup logic
    pass
```

---

## Testing Guide

### Test File Structure

```gdscript
extends Node

## EventName event tests

func _ready():
    print("=== Testing EventName ===")
    test_initialization()
    test_triggering()
    test_termination()
    test_edge_cases()
    print("=== All EventName tests passed! ===")
```

### Test Case Design

**Required tests**:
1. **Initialization test** - verify the event initializes correctly
2. **Trigger test** - verify the event triggers correctly
3. **Cleanup test** - verify resources are cleaned up correctly
4. **Boundary value test** - test extreme parameter values
5. **Error handling test** - verify error cases are handled correctly

**Test example**:
```gdscript
func test_initialization():
    print("Test 1: Initialization")

    var event = EventName.new()
    var trigger = Node.new()
    add_child(trigger)

    # Initialize the event
    event.initialize(trigger)
    await get_tree().process_frame

    # Verify the signal is connected
    assert(trigger.some_signal.is_connected(event._on_callback), "Signal should be connected")
    print("  ✓ Test 1 passed\n")

    # Clean up
    event.terminate(trigger)
    trigger.queue_free()

func test_triggering():
    print("Test 2: Triggering")

    var event = EventName.new()
    var trigger = Node.new()
    add_child(trigger)

    var triggered = false
    event.triggered.connect(func():
        triggered = true
    )

    event.initialize(trigger)

    # Trigger the event
    trigger.emit_signal("some_signal")
    await get_tree().process_frame

    # Verify the event triggered
    assert(triggered, "Event should be triggered")
    print("  ✓ Test 2 passed\n")

    # Clean up
    event.terminate(trigger)
    trigger.queue_free()

func test_termination():
    print("Test 3: Termination")

    var event = EventName.new()
    var trigger = Node.new()
    add_child(trigger)

    event.initialize(trigger)
    event.terminate(trigger)

    # Verify the signal is disconnected
    assert(not trigger.some_signal.is_connected(event._on_callback), "Signal should be disconnected")
    print("  ✓ Test 3 passed\n")

    trigger.queue_free()
```

### Test Assertions

```gdscript
# Verify a condition
assert(condition, "Error message")

# Verify the event triggered
assert(triggered == should_trigger, "Event should trigger")

# Verify the signal connection
assert(signal_connected, "Signal should be connected")

# Verify resource cleanup
assert(timer == null, "Timer should be cleaned up")
```

---

## Quick Reference

### Common Code Snippets

#### Signal Connection
```gdscript
# Connect on initialization
func initialize(owner_node: Node):
    if not owner_node.some_signal.is_connected(_on_callback):
        owner_node.some_signal.connect(_on_callback)

# Disconnect on cleanup
func terminate(owner_node: Node):
    if owner_node and owner_node.some_signal.is_connected(_on_callback):
        owner_node.some_signal.disconnect(_on_callback)
```

#### Timer Creation and Cleanup
```gdscript
# Create
func _start_timer():
    _cleanup_timer()
    _timer = Timer.new()
    _timer.wait_time = delay_seconds
    _timer.one_shot = true
    _timer.timeout.connect(_on_timer_timeout)
    _owner_node.add_child(_timer)
    _timer.start()

# Cleanup
func _cleanup_timer():
    if _timer:
        _timer.stop()
        if _timer.timeout.is_connected(_on_timer_timeout):
            _timer.timeout.disconnect(_on_timer_timeout)
        if _owner_node and is_instance_valid(_owner_node):
            _owner_node.remove_child(_timer)
        _timer.queue_free()
        _timer = null
```

#### Node Acquisition and Validation
```gdscript
# Get the node
var target_node = owner_node.get_node_or_null(target_path)

# Validate
if not target_node:
    _create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(target_path)})
    return

if not target_node is Area2D:
    _create_fuse_error_localized("FUSE_ERROR_INVALID_TARGET", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(target_path)})
    return
```

#### Event Triggering
```gdscript
func _on_event_triggered():
    _log_info_localized("FUSE_LOG_EVENT_TRIGGERED", {"event_type": get_event_type()})

    # Check whether it should trigger only once
    if trigger_once and _has_triggered:
        return

    _has_triggered = true
    _emit_triggered(context_node)  # 推荐：自动设置 trigger meta
```

### Common Error Keys

Defined localization error keys (see `translations.csv`):
- `FUSE_ERROR_TARGET_NODE_NULL` - target node is null
- `FUSE_ERROR_TARGET_NODE_EMPTY` - target node path is empty
- `FUSE_ERROR_TARGET_NODE_NOT_FOUND` - target node not found
- `FUSE_ERROR_INVALID_TARGET` - target node type is invalid
- `FUSE_ERROR_MISSING_PARAMETER` - a required parameter is missing
- `FUSE_ERROR_CONFIGURATION_ERROR` - configuration error

### Common Log Keys

- `FUSE_LOG_EVENT_INITIALIZED` - event initialized
- `FUSE_LOG_EVENT_TERMINATED` - event terminated
- `FUSE_LOG_EVENT_TRIGGERED` - event triggered
- `FUSE_LOG_EVENT_RESET` - event reset
- `FUSE_LOG_EVENT_DELAY` - delayed trigger
- `FUSE_LOG_EVENT_ALREADY_TRIGGERED` - event already triggered

---

## Summary

Key points for creating a Fuse event:

1. ✅ **Follow the naming conventions** - `on_` prefix, `On` class prefix
2. ✅ **Implement the required methods** - `_update_resource_name()`, `initialize()`, `terminate()`
3. ✅ **Manage signals correctly** - disconnect all connections in `terminate()`
4. ✅ **Clean up resources** - Timers, node references, etc. must be cleaned up properly
5. ✅ **Localize messages** - use `_log_*_localized()` and `_create_fuse_error_localized()`
6. ✅ **Add complete tests** - initialization, triggering, cleanup, edge cases
7. ✅ **Validate configuration** - implement the `validate()` method
8. ✅ **Provide metadata** - implement the static `_get_event_metadata()` method

**Core principles**:
- **initialize_with_runtime_instance()** initializes the event (recommended) and connects signals
- **terminate()** disconnects signals and cleans up resources
- Use `_emit_triggered()` to emit the signal when the event fires (sets the trigger meta automatically)
- Use `notify_stopped()` to notify the Trigger when the event stops

**Reference documents**:
- [BaseEvent API](../../../../core/base/base_event.gd)
- [Complete Event Templates](#complete-event-templates)
- [Testing Guide](#testing-guide)

---

**Maintained by**: Fuse development team
**Last updated**: 2026-06-17
**Version**: v2.1 - Added the stopped signal, performance tracking documentation, fixed broken links
