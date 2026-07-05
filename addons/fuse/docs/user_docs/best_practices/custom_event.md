# 自定义 Event 创建最佳实践指南

## 概述

本指南基于 Fuse Visual Programming 系统中的 Event 架构，提供了创建自定义 Event 类的完整最佳实践。通过遵循这些实践，您可以创建高效、可靠且易于维护的自定义事件。

## 目录

1. [Event 架构基础](#event-架构基础)
2. [核心方法实现](#核心方法实现)
3. [生命周期管理](#生命周期管理)
4. [错误处理和日志](#错误处理和日志)
5. [性能优化](#性能优化)
6. [常见实现模式](#常见实现模式)
7. [完整示例](#完整示例)
8. [测试和验证](#测试和验证)

---

## Event 架构基础

### BaseEvent 核心职责

`BaseEvent` 是所有事件类的基类，提供以下核心功能：

- **信号系统**：`triggered(context: Node)` 信号用于通知触发器
- **生命周期管理**：`initialize()` 和 `terminate()` 方法管理事件生命周期
- **错误处理**：统一的 `FuseError` 错误处理机制
- **元数据**：事件类型、分类和描述信息
- **运行时实例支持**：`initialize_with_runtime_instance()` 方法支持内存优化
- **验证机制**：`validate()` 方法验证配置有效性
- **性能优化**：本地化类缓存提升性能约 70%

### 事件生命周期

```
创建 → initialize() → [监听游戏事件] → triggered.emit() → terminate()
```

1. **创建阶段**：Event 资源被实例化
2. **初始化阶段**：`initialize()` 或 `initialize_with_runtime_instance()` 被调用，设置监听
3. **运行阶段**：监听游戏事件，条件满足时触发
4. **清理阶段**：`terminate()` 被调用，清理资源

---

## 核心方法实现

### 1. 必须实现的抽象方法

#### initialize(owner_node: Node)

这是最重要的方法，负责设置事件监听：

```gdscript
func initialize(owner_node: Node) -> void:
    # 检查是否在编辑器模式下
    if Engine.is_editor_hint():
        _log_debug("编辑器模式下，跳过事件初始化")
        return

    # 1. 验证输入参数
    if not owner_node:
        _log_error("Owner node is null")
        _create_fuse_error("Owner 节点为空", FuseError.ErrorType.CONFIGURATION_ERROR)
        return

    # 2. 获取目标节点（如果需要）
    _target_node = owner_node.get_node_or_null(target_node_path)
    if not _target_node:
        _log_error("无法找到目标节点: %s" % target_node_path)
        return

    # 3. 连接信号
    if not _target_node.some_signal.is_connected(_on_some_event):
        _target_node.some_signal.connect(_on_some_event)

    _log_debug("事件初始化完成: %s" % get_description())
```

#### initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance)

使用运行时实例初始化事件（内存优化）：

```gdscript
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
    # 检查是否在编辑器模式下
    if Engine.is_editor_hint():
        _log_debug("编辑器模式下，跳过事件初始化")
        return

    # 调用基础初始化
    initialize(owner_node)

    # 子类可以重写此方法来处理特定的运行时状态
    _initialize_runtime_state(runtime_instance)
```

**重要说明：**
- 此方法是内存优化的一部分，避免不必要的资源复制
- 默认实现会调用原有的 `initialize()` 方法，保持向后兼容
- 子类可以重写 `_initialize_runtime_state()` 来处理特定运行时状态

#### _initialize_runtime_state(runtime_instance: RuntimeEventInstance)

初始化特定的运行时状态（可选重写）：

```gdscript
func _initialize_runtime_state(runtime_instance: RuntimeEventInstance):
    # 默认实现为空，子类可以重写
    _log_debug("运行时状态初始化: %s" % runtime_instance.get_description())

    # 示例：从运行时实例恢复状态
    if runtime_instance.has_meta("last_trigger_time"):
        _last_trigger_time = runtime_instance.get_meta("last_trigger_time")
```

#### terminate(owner_node: Node)

负责清理资源和断开连接：

```gdscript
func terminate(owner_node: Node) -> void:
    # 1. 断开信号连接
    if _target_node and is_instance_valid(_target_node):
        if _target_node.some_signal.is_connected(_on_some_event):
            _target_node.some_signal.disconnect(_on_some_event)
    
    # 2. 清理内部资源
    _cleanup_internal_resources()
    
    # 3. 清理状态
    _internal_state.clear()
    
    _log_debug("事件清理完成")
```

#### _update_resource_name()

更新事件在编辑器列表中显示的名称，让使用者能够直观地看到事件的作用与参数：

```gdscript
func _update_resource_name():
    resource_name = "事件类型: 参数值"
```

**重要说明：**
- 这是一个抽象方法，必须在子类中实现
- 应该在关键属性的 setter 中调用此方法，确保参数变化时名称同步更新
- 名称应该简洁明了，包含最重要的参数信息
- 避免在名称中包含过多细节，保持可读性

**实现示例：**

```gdscript
# 在属性 setter 中调用
@export var delay_seconds: float = 0.0:
    set(value):
        delay_seconds = value
        _update_resource_name()

@export var target_group: String = "":
    set(value):
        target_group = value
        _update_resource_name()

# 实现更新方法
func _update_resource_name():
    if delay_seconds > 0:
        resource_name = "延迟触发: %.1f秒" % delay_seconds
    else:
        resource_name = "立即触发"
    
    if not target_group.is_empty():
        resource_name += " [组: %s]" % target_group
```

### 2. 推荐重写的方法

#### get_description() -> String

提供事件的描述信息：

```gdscript
func get_description() -> String:
    return "当 %s 发生时触发" % event_name
```

#### get_event_type() -> String

返回唯一的事件类型标识符：

```gdscript
func get_event_type() -> String:
    return "custom_event_type"
```

#### get_event_category() -> String

返回事件分类，用于在编辑器中组织：

```gdscript
func get_event_category() -> String:
    return "custom"
```

#### validate() -> Array[String]

验证事件配置的有效性：

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

## 生命周期管理

### 资源管理最佳实践

#### 1. 节点引用管理

```gdscript
# 存储节点引用以便后续清理
var _target_node: Node = null
var _timer: Timer = null

func initialize(owner_node: Node) -> void:
    # 获取节点引用
    _target_node = owner_node.get_node_or_null(target_node_path)
    
    # 创建临时节点（如计时器）
    if needs_timer:
        _timer = Timer.new()
        owner_node.add_child(_timer)

func terminate(owner_node: Node) -> void:
    # 清理节点引用
    if _timer:
        _timer.queue_free()
        _timer = null
    
    _target_node = null
```

#### 2. 信号连接管理

```gdscript
func initialize(owner_node: Node) -> void:
    # 安全连接信号
    if _target_node and not _target_node.some_signal.is_connected(_on_some_event):
        _target_node.some_signal.connect(_on_some_event)

func terminate(owner_node: Node) -> void:
    # 安全断开信号
    if _target_node and is_instance_valid(_target_node):
        if _target_node.some_signal.is_connected(_on_some_event):
            _target_node.some_signal.disconnect(_on_some_event)
```

#### 3. 状态重置

```gdscript
func reset() -> void:
    super.reset()
    
    # 重置内部状态
    _has_triggered = false
    _triggered_objects.clear()
    
    # 停止进行中的操作
    if _timer:
        _timer.stop()
    
    _log_debug("事件状态已重置")
```

---

## 错误处理和日志

### 1. 统一错误处理

```gdscript
func initialize(owner_node: Node) -> void:
    # 参数验证
    if not owner_node:
        _create_fuse_error("Owner 节点为空", FuseError.ErrorType.CONFIGURATION_ERROR)
        return
    
    # 节点验证
    _target_node = owner_node.get_node_or_null(target_node_path)
    if not _target_node:
        _create_fuse_error("无法找到目标节点: %s" % target_node_path, FuseError.ErrorType.CONFIGURATION_ERROR)
        return
    
    # 类型验证
    if not _target_node is ExpectedType:
        _create_fuse_error("节点类型不匹配，期望 %s，实际 %s" % [
            "ExpectedType", _target_node.get_class()
        ], FuseError.ErrorType.CONFIGURATION_ERROR)
        return
```

### 2. 分级日志记录

```gdscript
func _on_some_event(context: Node) -> void:
    _log_debug("事件触发条件满足")
    
    # 条件检查
    if not _check_conditions(context):
        _log_debug("条件不满足，跳过触发")
        return
    
    _log_info("触发事件: %s" % get_description())
    triggered.emit(context)
```

### 3. 上下文信息记录

```gdscript
func _create_fuse_error(message: String, error_type: FuseError.ErrorType, context: Dictionary = {}):
    var error_context = context.duplicate()
    error_context["event_type"] = get_event_type()
    error_context["event_description"] = get_description()
    error_context["target_node_path"] = target_node_path
    
    super._create_fuse_error(message, error_type, error_context)
```

---

## 性能优化

### 1. 本地化类缓存（内置优化）

BaseEvent 已经实现了本地化类缓存，避免重复 `load()` 调用，性能提升约 70%：

```gdscript
# BaseEvent 内部已实现
static var _fuse_localization_class: RefCounted = null

# 使用本地化日志方法时自动利用缓存
func _log_info_localized(message_key: String, args: Dictionary = {}) -> void:
    FuseLogger.log_info_localized("BaseEvent", log_level, message_key, args, get_event_type())
```

### 2. 条件检查优化

```gdscript
# 使用短路逻辑优化条件检查
func _check_conditions(context: Node) -> bool:
    # 先检查轻量级条件
    if not context or not _enabled:
        return false

    # 再检查重量级条件
    if not _check_expensive_condition(context):
        return false

    return true
```

### 3. 缓存机制

```gdscript
# 缓存计算结果
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

### 4. 批量操作

```gdscript
# 批量处理多个对象
func _process_multiple_objects(objects: Array[Node]) -> void:
    var valid_objects: Array[Node] = []

    # 先过滤，再处理
    for obj in objects:
        if _is_valid_object(obj):
            valid_objects.append(obj)

    # 批量触发
    for obj in valid_objects:
        triggered.emit(obj)
```

---

## 常见实现模式

### 1. 延迟触发模式

基于 `OnReady` 的实现模式：

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

### 2. 过滤触发模式

基于 `OnArea2DEnter` 的实现模式：

```gdscript
@export var target_group: String = ""
@export var trigger_once_per_object: bool = false
var _triggered_objects: Array[Node] = []

func _on_event_triggered(object: Node) -> void:
    # 组过滤
    if not target_group.is_empty() and not object.is_in_group(target_group):
        return
    
    # 重复触发检查
    if trigger_once_per_object and _triggered_objects.has(object):
        return
    
    # 记录已触发对象
    if trigger_once_per_object:
        _triggered_objects.append(object)
    
    triggered.emit(object)
```

### 3. 状态监听模式

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

### 4. 动态资源名称更新模式

基于 `_update_resource_name()` 的实现模式，提供直观的编辑器体验：

```gdscript
# 多参数事件的资源名称更新
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
    
    # 基础事件名称
    if not event_name.is_empty():
        parts.append(event_name)
    else:
        parts.append("自定义事件")
    
    # 优先级信息
    if priority != 0:
        parts.append("(优先级:%d)" % priority)
    
    # 状态信息
    if not enabled:
        parts.append("[已禁用]")
    
    # 组合最终名称
    resource_name = " ".join(parts)

# 条件性资源名称更新
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

## 完整示例

### 自定义事件示例：EventOnHealthChanged

```gdscript
@tool
class_name EventOnHealthChanged extends BaseEvent

## 目标节点路径
@export var target_node_path: NodePath:
    set(value):
        target_node_path = value
        _update_resource_name()

## 健康值变化阈值
@export var health_threshold: float = 0.0:
    set(value):
        health_threshold = value
        _update_resource_name()

## 监听健康值增加还是减少
@export_enum("增加", "减少", "任意变化") var change_type: int = 2:
    set(value):
        change_type = value
        _update_resource_name()

## 是否只触发一次
@export var trigger_once: bool = false:
    set(value):
        trigger_once = value
        _update_resource_name()

# 内部状态
var _target_node: Node = null
var _last_health: float = -1.0
var _has_triggered: bool = false
var _last_trigger_time: float = 0.0

# 更新资源名称
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
    # 检查是否在编辑器模式下
    if Engine.is_editor_hint():
        _log_debug("编辑器模式下，跳过事件初始化")
        return

    _log_debug("初始化健康值变化事件")

    # 验证和获取目标节点
    _target_node = owner_node.get_node_or_null(target_node_path)
    if not _target_node:
        _create_fuse_error("无法找到目标节点: %s" % target_node_path, FuseError.ErrorType.CONFIGURATION_ERROR)
        return

    # 验证节点是否有健康值属性
    if not _target_node.has_method("get_health") or not _target_node.has_signal("health_changed"):
        _create_fuse_error("目标节点不支持健康值监听", FuseError.ErrorType.CONFIGURATION_ERROR)
        return

    # 连接健康值变化信号
    if not _target_node.health_changed.is_connected(_on_health_changed):
        _target_node.health_changed.connect(_on_health_changed)

    # 获取初始健康值
    _last_health = _target_node.get_health()

    _log_debug("健康值事件初始化完成，初始值: %.2f" % _last_health)

func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
    # 检查是否在编辑器模式下
    if Engine.is_editor_hint():
        _log_debug("编辑器模式下，跳过事件初始化")
        return

    _log_debug("使用运行时实例初始化健康值变化事件")

    # 调用基础初始化
    initialize(owner_node)

    # 处理运行时状态
    _initialize_runtime_state(runtime_instance)

func _initialize_runtime_state(runtime_instance: RuntimeEventInstance):
    _log_debug("运行时状态初始化: %s" % runtime_instance.get_description())

    # 从运行时实例恢复上次触发时间
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
    
    # 检查变化类型
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
    
    # 检查阈值
    if abs(health_change) < health_threshold:
        _log_debug("变化量 %.2f 小于阈值 %.2f，跳过触发" % [abs(health_change), health_threshold])
        return
    
    # 检查是否已触发
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

# 统一日志方法
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

## 测试和验证

### 1. 单元测试模式

```gdscript
# 测试事件初始化
func test_event_initialization():
    var event = EventOnHealthChanged.new()
    var test_node = Node.new()
    test_node.set_script(load("res://test_health_node.gd"))
    
    # 测试正常初始化
    event.target_node_path = "^/TestNode"
    event.initialize(test_node)
    assert(event._target_node != null)
    
    # 测试清理
    event.terminate(test_node)
    assert(event._target_node == null)

# 测试事件触发
func test_event_triggering():
    var event = EventOnHealthChanged.new()
    var test_node = create_test_health_node()
    
    event.initialize(test_node)
    
    # 模拟健康值变化
    test_node.set_health(50.0)
    
    # 验证事件是否触发
    # 这里需要连接 triggered 信号进行验证
    
    event.terminate(test_node)
```

### 2. 集成测试模式

```gdscript
# 在实际场景中测试事件
func test_event_in_scene():
    # 创建测试场景
    var scene = PackedScene.new()
    # 添加必要的节点和事件配置
    
    # 运行场景并验证事件行为
```

### 3. 性能测试

```gdscript
func test_event_performance():
    var event = EventOnHealthChanged.new()
    var start_time = Time.get_ticks_msec()
    
    # 执行大量事件操作
    for i in range(1000):
        event._on_health_changed(i * 0.1)
    
    var end_time = Time.get_ticks_msec()
    print("事件处理时间: %d ms" % (end_time - start_time))
```

---

## 总结

创建自定义 Event 时遵循以下关键原则：

1. **完整生命周期管理**：正确实现 `initialize()` 和 `terminate()` 方法
2. **运行时实例支持**：实现 `initialize_with_runtime_instance()` 以支持内存优化
3. **状态初始化**：重写 `_initialize_runtime_state()` 处理特定运行时状态
4. **健壮的错误处理**：使用统一的错误处理机制（包括本地化错误）
5. **清晰的日志记录**：提供适当的调试信息（包括本地化日志）
6. **性能优化**：利用内置的本地化类缓存（性能提升约 70%）
7. **状态一致性**：确保事件状态在生命周期内保持一致
8. **资源清理**：及时释放不再需要的资源
9. **参数验证**：在 `validate()` 中验证配置参数
10. **直观的资源名称**：实现 `_update_resource_name()` 方法，让事件在编辑器中显示清晰的信息
11. **编辑器模式检测**：在初始化方法中检查 `Engine.is_editor_hint()`

通过遵循这些最佳实践，您可以创建高质量、高性能的自定义 Event 类，为 Fuse Visual Programming 系统提供强大而可靠的事件处理能力。

---
## 更新说明（2026-03）

- BaseEvent 现在通过 `get_default_runtime_state()` 方法自声明运行时状态
- 使用 `initialize_with_runtime_instance()` 进行运行时实例初始化
- 使用 `get_runtime_instance()` 访问运行时实例
- 元数据通过 `EventMetadata` 类和 `_get_event_metadata()` 静态方法定义
- 详细参考: [Runtime Instance 模式](../../architecture/runtime-instance-pattern.md)