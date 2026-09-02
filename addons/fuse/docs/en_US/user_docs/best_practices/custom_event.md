> 🌐 [**中文版**](../../../zh_CN/user_docs/best_practices/custom_event.md) | English

# Custom Event Creation Best Practices Guide

## Overview

This guide is based on the Event architecture of the Fuse Visual Programming system and provides complete best practices for creating custom Event classes. By following these practices, you can create efficient, reliable, and easy-to-maintain custom events.

## Table of Contents

1. [Event Architecture Basics](#event-architecture-basics)
2. [Core Method Implementation](#core-method-implementation)
3. [Lifecycle Management](#lifecycle-management)
4. [Error Handling and Logging](#error-handling-and-logging)
5. [Performance Optimization](#performance-optimization)
6. [Common Implementation Patterns](#common-implementation-patterns)
7. [Complete Example](#complete-example)
8. [Testing and Validation](#testing-and-validation)

---

## Event Architecture Basics

### BaseEvent Core Responsibilities

`BaseEvent` is the base class of all event classes and provides the following core capabilities:

- **Signal system**: the `triggered(context: Node)` signal is used to notify triggers
- **Lifecycle management**: the `initialize()` and `terminate()` methods manage the event lifecycle
- **Error handling**: the unified `FuseError` error handling mechanism
- **Metadata**: event type, category, and description information
- **Runtime instance support**: the `initialize_with_runtime_instance()` method supports memory optimization
- **Validation mechanism**: the `validate()` method validates configuration validity
- **Performance optimization**: the localization class cache improves performance by about 70%

### Event Lifecycle

```
创建 → initialize() → [监听游戏事件] → triggered.emit() → terminate()
```

1. **Creation phase**: the Event resource is instantiated
2. **Initialization phase**: `initialize()` or `initialize_with_runtime_instance()` is called to set up listening
3. **Running phase**: game events are monitored; the event fires once conditions are met
4. **Cleanup phase**: `terminate()` is called to release resources

---

## Core Method Implementation

### 1. Required Abstract Methods

#### initialize(owner_node: Node)

This is the most important method, responsible for setting up event listening:

```gdscript
func initialize(owner_node: Node) -> void:
    # Check whether we are in the editor
    if Engine.is_editor_hint():
        _log_debug("编辑器模式下，跳过事件初始化")
        return

    # 1. Validate input parameters
    if not owner_node:
        _log_error("Owner node is null")
        _create_fuse_error("Owner 节点为空", FuseError.ErrorType.CONFIGURATION_ERROR)
        return

    # 2. Get the target node (if needed)
    _target_node = owner_node.get_node_or_null(target_node_path)
    if not _target_node:
        _log_error("无法找到目标节点: %s" % target_node_path)
        return

    # 3. Connect the signal
    if not _target_node.some_signal.is_connected(_on_some_event):
        _target_node.some_signal.connect(_on_some_event)

    _log_debug("事件初始化完成: %s" % get_description())
```

#### initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance)

Initializes the event with a runtime instance (memory optimization):

```gdscript
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
    # Check whether we are in the editor
    if Engine.is_editor_hint():
        _log_debug("编辑器模式下，跳过事件初始化")
        return

    # Call the base initialization
    initialize(owner_node)

    # Subclasses can override this method to handle specific runtime state
    _initialize_runtime_state(runtime_instance)
```

**Important notes:**
- This method is part of the memory optimization work and avoids unnecessary resource duplication
- The default implementation calls the original `initialize()` method to stay backward compatible
- Subclasses can override `_initialize_runtime_state()` to handle specific runtime state

#### _initialize_runtime_state(runtime_instance: RuntimeEventInstance)

Initializes runtime-specific state (optional override):

```gdscript
func _initialize_runtime_state(runtime_instance: RuntimeEventInstance):
    # The default implementation is empty; subclasses can override it
    _log_debug("运行时状态初始化: %s" % runtime_instance.get_description())

    # Example: restore state from the runtime instance
    if runtime_instance.has_meta("last_trigger_time"):
        _last_trigger_time = runtime_instance.get_meta("last_trigger_time")
```

#### terminate(owner_node: Node)

Responsible for releasing resources and disconnecting signals:

```gdscript
func terminate(owner_node: Node) -> void:
    # 1. Disconnect signals
    if _target_node and is_instance_valid(_target_node):
        if _target_node.some_signal.is_connected(_on_some_event):
            _target_node.some_signal.disconnect(_on_some_event)
    
    # 2. Release internal resources
    _cleanup_internal_resources()
    
    # 3. Clear state
    _internal_state.clear()
    
    _log_debug("事件清理完成")
```

#### _update_resource_name()

Updates the name displayed for the event in the editor list, so users can see at a glance what the event does and which parameters it uses:

```gdscript
func _update_resource_name():
    resource_name = "事件类型: 参数值"
```

**Important notes:**
- This is an abstract method and must be implemented in subclasses
- Call this method in the setters of key properties so the name is updated in sync whenever a parameter changes
- The name should be concise and contain the most important parameter information
- Avoid including too much detail in the name; keep it readable

**Implementation example:**

```gdscript
# Called in property setters
@export var delay_seconds: float = 0.0:
    set(value):
        delay_seconds = value
        _update_resource_name()

@export var target_group: String = "":
    set(value):
        target_group = value
        _update_resource_name()

# Implements the update method
func _update_resource_name():
    if delay_seconds > 0:
        resource_name = "延迟触发: %.1f秒" % delay_seconds
    else:
        resource_name = "立即触发"
    
    if not target_group.is_empty():
        resource_name += " [组: %s]" % target_group
```

### 2. Recommended Overrides

#### get_description() -> String

Provides the event description:

```gdscript
func get_description() -> String:
    return "当 %s 发生时触发" % event_name
```

#### get_event_type() -> String

Returns the unique event type identifier:

```gdscript
func get_event_type() -> String:
    return "custom_event_type"
```

#### get_event_category() -> String

Returns the event category, used to organize events in the editor:

```gdscript
func get_event_category() -> String:
    return "custom"
```

#### validate() -> Array[String]

Validates the event configuration:

```gdscript
func validate() -> Array[String]:
    var errors: Array[String] = []
    
    if target_node_path.is_empty():
        errors.append("必须指定目标节点路径")
    
    if required_parameter <= 0:
        errors.append("参数值必须大于0")
    
    return errors
```

---

## Lifecycle Management

### Resource Management Best Practices

#### 1. Node Reference Management

```gdscript
# Store node references for later cleanup
var _target_node: Node = null
var _timer: Timer = null

func initialize(owner_node: Node) -> void:
    # Get node references
    _target_node = owner_node.get_node_or_null(target_node_path)
    
    # Create temporary nodes (e.g. timers)
    if needs_timer:
        _timer = Timer.new()
        owner_node.add_child(_timer)

func terminate(owner_node: Node) -> void:
    # Clean up node references
    if _timer:
        _timer.queue_free()
        _timer = null
    
    _target_node = null
```

#### 2. Signal Connection Management

```gdscript
func initialize(owner_node: Node) -> void:
    # Connect signals safely
    if _target_node and not _target_node.some_signal.is_connected(_on_some_event):
        _target_node.some_signal.connect(_on_some_event)

func terminate(owner_node: Node) -> void:
    # Disconnect signals safely
    if _target_node and is_instance_valid(_target_node):
        if _target_node.some_signal.is_connected(_on_some_event):
            _target_node.some_signal.disconnect(_on_some_event)
```

#### 3. State Reset

```gdscript
func reset() -> void:
    super.reset()
    
    # Reset internal state
    _has_triggered = false
    _triggered_objects.clear()
    
    # Stop in-progress operations
    if _timer:
        _timer.stop()
    
    _log_debug("事件状态已重置")
```

---

## Error Handling and Logging

### 1. Unified Error Handling

```gdscript
func initialize(owner_node: Node) -> void:
    # Parameter validation
    if not owner_node:
        _create_fuse_error("Owner 节点为空", FuseError.ErrorType.CONFIGURATION_ERROR)
        return
    
    # Node validation
    _target_node = owner_node.get_node_or_null(target_node_path)
    if not _target_node:
        _create_fuse_error("无法找到目标节点: %s" % target_node_path, FuseError.ErrorType.CONFIGURATION_ERROR)
        return
    
    # Type validation
    if not _target_node is ExpectedType:
        _create_fuse_error("节点类型不匹配，期望 %s，实际 %s" % [
            "ExpectedType", _target_node.get_class()
        ], FuseError.ErrorType.CONFIGURATION_ERROR)
        return
```

### 2. Leveled Logging

```gdscript
func _on_some_event(context: Node) -> void:
    _log_debug("事件触发条件满足")
    
    # Condition check
    if not _check_conditions(context):
        _log_debug("条件不满足，跳过触发")
        return
    
    _log_info("触发事件: %s" % get_description())
    triggered.emit(context)
```

### 3. Context Information Logging

```gdscript
func _create_fuse_error(message: String, error_type: FuseError.ErrorType, context: Dictionary = {}):
    var error_context = context.duplicate()
    error_context["event_type"] = get_event_type()
    error_context["event_description"] = get_description()
    error_context["target_node_path"] = target_node_path
    
    super._create_fuse_error(message, error_type, error_context)
```

---

## Performance Optimization

### 1. Localization Class Cache (Built-in Optimization)

BaseEvent already implements a localization class cache that avoids repeated `load()` calls, improving performance by about 70%:

```gdscript
# Already implemented inside BaseEvent
static var _fuse_localization_class: RefCounted = null

# The localized logging methods automatically use the cache
func _log_info_localized(message_key: String, args: Dictionary = {}) -> void:
    FuseLogger.log_info_localized("BaseEvent", log_level, message_key, args, get_event_type())
```

### 2. Condition Check Optimization

```gdscript
# Use short-circuit logic to optimize condition checks
func _check_conditions(context: Node) -> bool:
    # Check lightweight conditions first
    if not context or not _enabled:
        return false

    # Then check heavyweight conditions
    if not _check_expensive_condition(context):
        return false

    return true
```

### 3. Caching Mechanism

```gdscript
# Cache computed results
var _cached_result: bool = false
var _cache_valid: bool = false

func _get_cached_result() -> bool:
    if not _cache_valid:
        _cached_result = _compute_expensive_result()
        _cache_valid = true
    return _cached_result

func _invalidate_cache():
    _cache_valid = false
```

### 4. Batch Operations

```gdscript
# Process multiple objects in batches
func _process_multiple_objects(objects: Array[Node]) -> void:
    var valid_objects: Array[Node] = []

    # Filter first, then process
    for obj in objects:
        if _is_valid_object(obj):
            valid_objects.append(obj)

    # Trigger in batches
    for obj in valid_objects:
        triggered.emit(obj)
```

---

## Common Implementation Patterns

### 1. Delayed Trigger Pattern

Implementation pattern based on `OnReady`:

```gdscript
@export var delay_seconds: float = 0.0
var _timer: Timer = null

func _start_delayed_trigger(owner_node: Node) -> void:
    if delay_seconds > 0:
        _timer = Timer.new()
        _timer.wait_time = delay_seconds
        _timer.one_shot = true
        _timer.timeout.connect(_on_timer_timeout.bind(owner_node))
        owner_node.add_child(_timer)
        _timer.start()
    else:
        call_deferred("_trigger_immediately", owner_node)

func _on_timer_timeout(owner_node: Node) -> void:
    triggered.emit(owner_node)
    _cleanup_timer()

func _cleanup_timer():
    if _timer:
        if _timer.timeout.is_connected(_on_timer_timeout):
            _timer.timeout.disconnect(_on_timer_timeout)
        _timer.queue_free()
        _timer = null
```

### 2. Filtered Trigger Pattern

Implementation pattern based on `OnArea2DEnter`:

```gdscript
@export var target_group: String = ""
@export var trigger_once_per_object: bool = false
var _triggered_objects: Array[Node] = []

func _on_event_triggered(object: Node) -> void:
    # Group filtering
    if not target_group.is_empty() and not object.is_in_group(target_group):
        return
    
    # Re-trigger check
    if trigger_once_per_object and _triggered_objects.has(object):
        return
    
    # Record already-triggered objects
    if trigger_once_per_object:
        _triggered_objects.append(object)
    
    triggered.emit(object)
```

### 3. State Listening Pattern

```gdscript
@export var target_state: String = ""
var _last_state: String = ""

func _on_state_changed(new_state: String) -> void:
    if new_state == _last_state:
        return  # 状态未变化
    
    _last_state = new_state
    
    if new_state == target_state:
        triggered.emit(get_tree().current_scene)
```

### 4. Dynamic Resource Name Update Pattern

Implementation pattern based on `_update_resource_name()`, providing an intuitive editor experience:

```gdscript
# Resource name updates for multi-parameter events
@export var event_name: String = "":
    set(value):
        event_name = value
        _update_resource_name()

@export var priority: int = 0:
    set(value):
        priority = value
        _update_resource_name()

@export var enabled: bool = true:
    set(value):
        enabled = value
        _update_resource_name()

func _update_resource_name():
    var parts = []
    
    # Base event name
    if not event_name.is_empty():
        parts.append(event_name)
    else:
        parts.append("自定义事件")
    
    # Priority information
    if priority != 0:
        parts.append("(优先级:%d)" % priority)
    
    # State information
    if not enabled:
        parts.append("[已禁用]")
    
    # Combine the final name
    resource_name = " ".join(parts)

# Conditional resource name updates
@export var trigger_condition: String = "always":
    set(value):
        trigger_condition = value
        _update_resource_name()

@export var custom_threshold: float = 0.0:
    set(value):
        custom_threshold = value
        _update_resource_name()

func _update_resource_name():
    var base_name = "条件触发"
    
    match trigger_condition:
        "always":
            resource_name = base_name + ": 始终"
        "threshold":
            if custom_threshold > 0:
                resource_name = "%s: 阈值%.1f" % [base_name, custom_threshold]
            else:
                resource_name = base_name + ": 阈值未设置"
        "custom":
            resource_name = base_name + ": 自定义条件"
        _:
            resource_name = base_name + ": 未知条件"
```

---

## Complete Example

### Custom Event Example: EventOnHealthChanged

```gdscript
@tool
class_name EventOnHealthChanged extends BaseEvent

## Target node path
@export var target_node_path: NodePath:
    set(value):
        target_node_path = value
        _update_resource_name()

## Health change threshold
@export var health_threshold: float = 0.0:
    set(value):
        health_threshold = value
        _update_resource_name()

## Whether to listen for health increases or decreases
@export_enum("增加", "减少", "任意变化") var change_type: int = 2:
    set(value):
        change_type = value
        _update_resource_name()

## Whether to trigger only once
@export var trigger_once: bool = false:
    set(value):
        trigger_once = value
        _update_resource_name()

# Internal state
var _target_node: Node = null
var _last_health: float = -1.0
var _has_triggered: bool = false
var _last_trigger_time: float = 0.0

# Update the resource name
func _update_resource_name():
    var node_name = "未指定节点"
    if not target_node_path.is_empty():
        node_name = target_node_path.get_name(0)
    
    var change_desc = ""
    match change_type:
        0: change_desc = "增加"
        1: change_desc = "减少"
        2: change_desc = "变化"
    
    var threshold_desc = ""
    if health_threshold > 0:
        threshold_desc = "(阈值:%.1f)" % health_threshold
    
    var once_desc = ""
    if trigger_once:
        once_desc = "[仅一次]"
    
    resource_name = "健康值%s: %s %s %s" % [
        change_desc,
        node_name,
        threshold_desc,
        once_desc
    ].strip_edges()

func initialize(owner_node: Node) -> void:
    # Check whether we are in the editor
    if Engine.is_editor_hint():
        _log_debug("编辑器模式下，跳过事件初始化")
        return

    _log_debug("初始化健康值变化事件")

    # Validate and get the target node
    _target_node = owner_node.get_node_or_null(target_node_path)
    if not _target_node:
        _create_fuse_error("无法找到目标节点: %s" % target_node_path, FuseError.ErrorType.CONFIGURATION_ERROR)
        return

    # Validate that the node supports health monitoring
    if not _target_node.has_method("get_health") or not _target_node.has_signal("health_changed"):
        _create_fuse_error("目标节点不支持健康值监听", FuseError.ErrorType.CONFIGURATION_ERROR)
        return

    # Connect the health_changed signal
    if not _target_node.health_changed.is_connected(_on_health_changed):
        _target_node.health_changed.connect(_on_health_changed)

    # Get the initial health value
    _last_health = _target_node.get_health()

    _log_debug("健康值事件初始化完成，初始值: %.2f" % _last_health)

func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
    # Check whether we are in the editor
    if Engine.is_editor_hint():
        _log_debug("编辑器模式下，跳过事件初始化")
        return

    _log_debug("使用运行时实例初始化健康值变化事件")

    # Call the base initialization
    initialize(owner_node)

    # Handle the runtime state
    _initialize_runtime_state(runtime_instance)

func _initialize_runtime_state(runtime_instance: RuntimeEventInstance):
    _log_debug("运行时状态初始化: %s" % runtime_instance.get_description())

    # Restore the last trigger time from the runtime instance
    if runtime_instance.has_meta("last_trigger_time"):
        _last_trigger_time = runtime_instance.get_meta("last_trigger_time")
        _log_debug("恢复上次触发时间: %.2f" % _last_trigger_time)

func terminate(owner_node: Node) -> void:
    if _target_node and is_instance_valid(_target_node):
        if _target_node.health_changed.is_connected(_on_health_changed):
            _target_node.health_changed.disconnect(_on_health_changed)
    
    _target_node = null
    _has_triggered = false
    _log_debug("健康值变化事件清理完成")

func _on_health_changed(new_health: float) -> void:
    var health_change = new_health - _last_health
    _last_health = new_health
    
    _log_debug("健康值变化: %.2f -> %.2f (变化: %.2f)" % [_last_health, new_health, health_change])
    
    # Check the change type
    var should_trigger = false
    match change_type:
        0:  # 增加
            should_trigger = health_change > 0
        1:  # 减少
            should_trigger = health_change < 0
        2:  # 任意变化
            should_trigger = true
    
    if not should_trigger:
        _log_debug("变化类型不匹配，跳过触发")
        return
    
    # Check the threshold
    if abs(health_change) < health_threshold:
        _log_debug("变化量 %.2f 小于阈值 %.2f，跳过触发" % [abs(health_change), health_threshold])
        return
    
    # Check whether it has already triggered
    if trigger_once and _has_triggered:
        _log_debug("已触发过，跳过")
        return
    
    _has_triggered = true
    _last_trigger_time = Time.get_ticks_msec() / 1000.0
    _log_info("健康值变化条件满足，触发事件")
    triggered.emit(_target_node)

func get_description() -> String:
    var change_desc = ""
    match change_type:
        0: change_desc = "增加"
        1: change_desc = "减少"
        2: change_desc = "变化"
    
    var threshold_desc = ""
    if health_threshold > 0:
        threshold_desc = " (阈值: %.1f)" % health_threshold
    
    var once_desc = ""
    if trigger_once:
        once_desc = " (仅一次)"
    
    return "当 %s 的健康值%s超过%.1f时触发%s" % [
        target_node_path.get_name(0),
        change_desc,
        health_threshold,
        once_desc
    ]

func get_event_type() -> String:
    return "health_changed"

func get_event_category() -> String:
    return "game_state"

func validate() -> Array[String]:
    var errors: Array[String] = []
    
    if target_node_path.is_empty():
        errors.append("必须指定目标节点路径")
    
    if health_threshold < 0:
        errors.append("健康值阈值不能为负数")
    
    return errors

func reset() -> void:
    super.reset()
    _has_triggered = false
    if _target_node and is_instance_valid(_target_node):
        _last_health = _target_node.get_health()
    _log_debug("健康值变化事件状态已重置")

# Unified logging methods
func _log_debug(message: String) -> void:
    FuseLogger.log_debug("EventOnHealthChanged", log_level, message)

func _log_info(message: String) -> void:
    FuseLogger.log_info("EventOnHealthChanged", log_level, message)

func _log_warning(message: String) -> void:
    FuseLogger.log_warning("EventOnHealthChanged", log_level, message)

func _log_error(message: String) -> void:
    FuseLogger.log_error("EventOnHealthChanged", log_level, message)
```

---

## Testing and Validation

### 1. Unit Test Pattern

```gdscript
# Test event initialization
func test_event_initialization():
    var event = EventOnHealthChanged.new()
    var test_node = Node.new()
    test_node.set_script(load("res://test_health_node.gd"))
    
    # Test normal initialization
    event.target_node_path = "^/TestNode"
    event.initialize(test_node)
    assert(event._target_node != null)
    
    # Test cleanup
    event.terminate(test_node)
    assert(event._target_node == null)

# Test event triggering
func test_event_triggering():
    var event = EventOnHealthChanged.new()
    var test_node = create_test_health_node()
    
    event.initialize(test_node)
    
    # Simulate a health change
    test_node.set_health(50.0)
    
    # Verify that the event fired
    # This requires connecting the triggered signal for verification
    
    event.terminate(test_node)
```

### 2. Integration Test Pattern

```gdscript
# Test the event in a real scene
func test_event_in_scene():
    # Create a test scene
    var scene = PackedScene.new()
    # Add the required nodes and event configuration
    
    # Run the scene and verify the event behavior
```

### 3. Performance Test

```gdscript
func test_event_performance():
    var event = EventOnHealthChanged.new()
    var start_time = Time.get_ticks_msec()
    
    # Perform a large number of event operations
    for i in range(1000):
        event._on_health_changed(i * 0.1)
    
    var end_time = Time.get_ticks_msec()
    print("事件处理时间: %d ms" % (end_time - start_time))
```

---

## Summary

When creating custom Events, follow these key principles:

1. **Complete lifecycle management**: implement the `initialize()` and `terminate()` methods correctly
2. **Runtime instance support**: implement `initialize_with_runtime_instance()` to support memory optimization
3. **State initialization**: override `_initialize_runtime_state()` to handle runtime-specific state
4. **Robust error handling**: use the unified error handling mechanism (including localized errors)
5. **Clear logging**: provide appropriate debug information (including localized logs)
6. **Performance optimization**: leverage the built-in localization class cache (about 70% faster)
7. **State consistency**: keep the event state consistent across the lifecycle
8. **Resource cleanup**: release unneeded resources in a timely manner
9. **Parameter validation**: validate configuration parameters in `validate()`
10. **Intuitive resource names**: implement `_update_resource_name()` so the event shows clear information in the editor
11. **Editor mode detection**: check `Engine.is_editor_hint()` in initialization methods

By following these best practices, you can create high-quality, high-performance custom Event classes that give the Fuse Visual Programming system powerful and reliable event handling.

---
## Update Notes (2026-03)

- BaseEvent now self-declares its runtime state via the `get_default_runtime_state()` method
- Runtime instance initialization uses `initialize_with_runtime_instance()`
- The runtime instance is accessed via `get_runtime_instance()`
- Metadata is defined through the `EventMetadata` class and the `_get_event_metadata()` static method

---

**Related docs:**

- [Custom Condition Creation Best Practices](custom_condition.md)
- [Event generation skill](../../../../agent_skills/fuse-event-generator/SKILL.md) — the final authority on event component specs (templates, naming rules, and validation gates); this guide details the architectural principles behind it
- [Event System Guide (Chinese)](../../../zh_CN/user_docs/guides/30-lifecycle-events-guide.md)
