# Fuse 事件创建完整指南

> **目标**: 为开发者提供完整的 Fuse 事件创建指引，基于项目开发经验总结和最佳实践。

**适用对象**: Fuse 系统开发者、贡献者

**最后更新**: 2026-01-28

---

## 目录

1. [命名规范](#命名规范)
2. [图标规范](#图标规范)
3. [事件生命周期](#事件生命周期)
4. [完整事件模板](#完整事件模板)
5. [创建步骤](#创建步骤)
6. [最佳实践](#最佳实践)
7. [常见陷阱](#常见陷阱)
8. [测试规范](#测试规范)

---

## 命名规范

**重要**: 所有 Fuse 事件遵循以下命名规范，保持简洁一致。

### 文件命名

- **事件文件**: 使用 `on_` 前缀 + snake_case
  - ✅ 正确：`on_body_entered.gd`, `on_timer.gd`, `on_animation_finished.gd`
  - ❌ 错误：`body_entered_event.gd`, `timer_event.gd`, `animation_finished.gd`

### 类命名

- **类名**: 使用 `On` 前缀 + PascalCase
  - ✅ 正确：`class_name OnBodyEntered`, `class_name OnTimer`, `class_name OnAnimationFinished`
  - ❌ 错误：`class_name BodyEnteredEvent`, `class_name TimerEvent`, `class_name AnimationFinishedEvent`

### 测试文件命名

- **测试脚本**: `test_<event_name>.gd`
  - 例如：`test_on_body_entered.gd`, `test_on_timer.gd`
- **测试场景**: `test_<event_name>.tscn`
  - 例如：`test_on_body_entered.tscn`, `test_on_timer.tscn`

### 统一性原则

- 文件名、类名、测试文件名保持一致的基础名称
- 使用描述性名称表示何时触发
- 保持简洁可读

**示例**:
```
事件文件：   on_body_entered.gd
类名：       class_name OnBodyEntered
测试脚本：   test_on_body_entered.gd
测试场景：   test_on_body_entered.tscn
```

---

## 图标规范

**图标选择原则**: 每个事件都应该配置图标，提升用户体验和可视化效果。

### 图标配置方式

**推荐：使用 Godot 内置图标**
```gdscript
metadata.builtin_icon = "PhysicsBody2D"  # 使用 Godot 内置图标名称
```

**常用图标命名参考**

**生命周期事件**:
- `HostNode` - 场景就绪
- `Timer` - 定时器
- `ToolLoop` - 每帧更新

**物理事件**:
- `PhysicsBody2D`, `PhysicsBody3D` - 物理碰撞
- `Shape2D`, `Shape3D` - Area 碰撞
- `Collision` - 碰撞相关

**输入事件**:
- `Keyboard` - 键盘输入
- `Mouse` - 鼠标输入
- `Gamepad` - 手柄输入
- `JoyButton` - 手柄按钮

**动画事件**:
- `Animation` - 动画相关
- `Key" - 动画关键帧

**音频事件**:
- `AudioStreamPlayer` - 音频播放
- `AudioBus" - 音频总线

**UI 事件**:
- `Button` - 按钮点击
- `SpinBox` - 值变化

**信号事件**:
- `Signals` - 信号监听
- `Link" - 连接

### 图标配置步骤

在 `_get_event_metadata()` 中配置图标：

```gdscript
static func _get_event_metadata() -> EventMetadata:
    var metadata = EventMetadata.new()
    metadata.builtin_icon = "PhysicsBody2D"  # 配置图标
    return metadata
```

---

## 事件生命周期

事件的核心生命周期包含三个阶段：

### 1. 初始化阶段（initialize）

```gdscript
func initialize(owner_node: Node) -> void:
    # 1. 验证参数
    if not owner_node:
        _create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", ...)
        return

    # 2. 获取目标节点
    _target_node = owner_node.get_node_or_null(target_node_path)
    if not _target_node:
        _create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", ...)
        return

    # 3. 验证节点类型（如果需要）
    if not _target_node is ExpectedType:
        _create_fuse_error_localized("FUSE_ERROR_INVALID_TARGET", ...)
        return

    # 4. 连接信号
    if not _target_node.signal_name.is_connected(_on_signal):
        _target_node.signal_name.connect(_on_signal)

    # 5. 记录日志
    _log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})
```

### 2. 运行阶段（触发）

```gdscript
func _on_signal(...args):
    # 1. 检查触发条件
    if trigger_once and _has_triggered:
        return

    # 2. 过滤条件（如果有）
    if not _check_condition(...args):
        return

    # 3. 标记已触发
    _has_triggered = true

    # 4. 记录日志
    _log_info_localized("FUSE_LOG_EVENT_TRIGGERED", {"event": get_event_type()})

    # 5. 发出触发信号（传递上下文）
    triggered.emit(context_data)
```

### 3. 清理阶段（terminate）

```gdscript
func terminate(owner_node: Node) -> void:
    # 1. 断开信号连接
    if _target_node and is_instance_valid(_target_node):
        if _target_node.signal_name.is_connected(_on_signal):
            _target_node.signal_name.disconnect(_on_signal)

    # 2. 清理定时器（如果有）
    if _timer:
        if _timer.timeout.is_connected(_on_timer_timeout):
            _timer.timeout.disconnect(_on_timer_timeout)
        if owner_node and is_instance_valid(owner_node):
            owner_node.remove_child(_timer)
        _timer.queue_free()
        _timer = null

    # 3. 清理引用
    _target_node = null
    _has_triggered = false

    # 4. 记录日志
    _log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})
```

---

## 完整事件模板

```gdscript
@tool
@icon("res://addons/fuse/icons/builtin/PhysicsBody2D.png")
extends BaseEvent
class_name OnEventTemplate

## 事件描述

# =============================================
# 参数定义
# =============================================

## 目标节点路径
var target_node: NodePath = NodePath(""):
	set(value):
		target_node = value
		_update_resource_name()

## 是否只触发一次
var trigger_once: bool = false:
	set(value):
		trigger_once = value
		_update_resource_name()

## 是否传递上下文数据
var emit_context: bool = true

# 运行时状态
var _target_node: Node = null
var _has_triggered: bool = false

# =============================================
# 元数据方法
# =============================================

## 获取事件元数据（必需）
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_ON_XXX_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_XXX"
	metadata.description_key = "FUSE_EVENT_ON_XXX_DESC"
	metadata.keywords = ["keyword1", "keyword2", "keyword3"]
	metadata.builtin_icon = "PhysicsBody2D"
	return metadata

# =============================================
# 资源名称和描述
# =============================================

## 更新资源名称（必需）
func _update_resource_name():
	var parts = []

	parts.append("事件名称")

	if not target_node.is_empty():
		parts.append("'%s'" % target_node)

	if trigger_once:
		parts.append("[仅一次]")

	resource_name = " ".join(parts)

## 获取事件描述
func get_description() -> String:
	var node_name = target_node if not target_node.is_empty() else "未指定"
	var once_text = "，仅触发一次" if trigger_once else ""
	return "当事件触发于 %s 时%s" % [node_name, once_text]

## 获取事件类型
func get_event_type() -> String:
	return "event_type_name"

## 获取事件分类
func get_event_category() -> String:
	return "category_name"

# =============================================
# 生命周期方法
# =============================================

## 初始化事件监听（必需）
func initialize(owner_node: Node) -> void:
	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

	# 1. 验证 owner_node
	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 2. 验证目标节点路径
	if target_node.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 3. 获取目标节点
	_target_node = owner_node.get_node_or_null(target_node)
	if not _target_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(target_node)})
		return

	# 4. 验证节点类型（如果需要）
	if not _target_node is ExpectedType:
		_create_fuse_error_localized("FUSE_ERROR_INVALID_TARGET", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(target_node)})
		return

	# 5. 连接信号
	if not _target_node.signal_name.is_connected(_on_signal):
		_target_node.signal_name.connect(_on_signal)

	_log_info_localized("FUSE_LOG_EVENT_SIGNAL_SOURCE", {"source": _target_node.name, "signal": "signal_name"})

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	# 1. 断开信号连接
	if _target_node and is_instance_valid(_target_node):
		if _target_node.signal_name.is_connected(_on_signal):
			_target_node.signal_name.disconnect(_on_signal)

	# 2. 清理引用和状态
	_target_node = null
	_has_triggered = false

	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

# =============================================
# 信号处理
# =============================================

## 信号回调函数
func _on_signal(...args):
	# 1. 检查是否只触发一次
	if trigger_once and _has_triggered:
		_log_debug_localized("FUSE_LOG_EVENT_ALREADY_TRIGGERED", {})
		return

	# 2. 检查其他条件（如果有）
	if not _check_condition(...args):
		return

	# 3. 标记已触发
	_has_triggered = true

	# 4. 记录日志
	_log_info_localized("FUSE_LOG_EVENT_TRIGGERED", {"event": get_event_type()})

	# 5. 发出触发信号（传递上下文）
	if emit_context:
		triggered.emit(context_data)
	else:
		triggered.emit(null)

# =============================================
# 验证和重置
# =============================================

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	if target_node.is_empty():
		errors.append("目标节点路径不能为空")

	return errors

## 重置事件状态
func reset() -> void:
	super.reset()
	_has_triggered = false
	_log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})
```

---

## 创建步骤

### Step 1: 创建事件类骨架

创建事件文件 `addons/fuse/events/<category>/on_<event_name>.gd`

### Step 2: 添加本地化翻译

在 `addons/fuse/localization/translations.csv` 添加：

```csv
key,zh_CN,en_US
FUSE_EVENT_ON_XXX_NAME,事件名称,Event Name
FUSE_EVENT_CATEGORY_XXX,分类名称,Category Name
FUSE_EVENT_ON_XXX_DESC,事件描述,Event description
FUSE_LOG_EVENT_XXX_TRIGGERED,事件已触发,Event triggered
```

**注意**：
- 使用 `NAME` 后缀表示事件名称
- 使用 `DESC` 后缀表示事件描述
- 使用 `LOG_EVENT_XXX_TRIGGERED` 表示触发日志
- 所有占位符使用 `{variable_name}` 格式

### Step 3: 创建测试场景

**Step 3.1: 创建测试场景文件**

创建 `addons/fuse/tests/events/test_on_<event_name>.tscn`

**Step 3.2: 创建测试脚本**

创建 `addons/fuse/tests/events/test_on_<event_name>.gd`

### Step 4: 测试验证

1. 在 Godot 中打开测试场景
2. 运行测试，确认事件正确触发
3. 检查编辑器中的 Inspector 显示是否正确
4. 验证信号连接和断开
5. 验证资源清理

---

## 最佳实践

### 1. 信号连接和断开

**原则**: 总是检查信号是否已连接，避免重复连接。

```gdscript
# ✅ 好的做法
if not _target_node.signal_name.is_connected(_on_signal):
    _target_node.signal_name.connect(_on_signal)

# ❌ 避免重复连接
_target_node.signal_name.connect(_on_signal)  # 可能重复连接
```

### 2. 资源清理

**原则**: 在 `terminate()` 中清理所有资源，防止内存泄漏。

```gdscript
func terminate(owner_node: Node) -> void:
    # 断开信号
    if _target_node and is_instance_valid(_target_node):
        if _target_node.signal_name.is_connected(_on_signal):
            _target_node.signal_name.disconnect(_on_signal)

    # 清理定时器
    if _timer:
        if _timer.timeout.is_connected(_on_timer_timeout):
            _timer.timeout.disconnect(_on_timer_timeout)
        if owner_node and is_instance_valid(owner_node):
            owner_node.remove_child(_timer)
        _timer.queue_free()
        _timer = null

    # 清理引用
    _target_node = null
    _has_triggered = false
```

### 3. 触发一次模式

**原则**: 使用布尔标志避免重复触发。

```gdscript
var _has_triggered: bool = false

func _on_signal():
    if trigger_once and _has_triggered:
        _log_debug_localized("FUSE_LOG_EVENT_ALREADY_TRIGGERED", {})
        return

    _has_triggered = true
    triggered.emit()
```

### 4. 上下文数据传递

**原则**: 通过 `triggered` 信号传递有用的上下文数据。

```gdscript
# 传递碰撞的物体
func _on_body_entered(body: Node2D):
    triggered.emit(body)

# 传递目标节点
func _on_timeout():
    triggered.emit(owner_node)

# 无需传递数据
func _on_simple_event():
    triggered.emit(null)
```

### 5. 节点获取

**原则**: 使用 `owner_node.get_node_or_null()` 而不是 `get_node()`。

```gdscript
# ✅ 好的做法
_target_node = owner_node.get_node_or_null(target_node_path)
if not _target_node:
    _create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", ...)

# ❌ 避免使用
_target_node = get_node(target_node_path)  # 不支持相对路径
```

### 6. 日志记录

**原则**: 使用本地化日志记录器，记录关键状态变化。

```gdscript
# 初始化
_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

# 触发
_log_info_localized("FUSE_LOG_EVENT_TRIGGERED", {"event": get_event_type()})

# 清理
_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})
```

---

## 常见陷阱

### 陷阱 1: 忘记断开信号

**问题**:
```gdscript
func terminate(owner_node: Node) -> void:
    _target_node = null  # ❌ 忘记断开信号
```

**解决方案**:
```gdscript
func terminate(owner_node: Node) -> void:
    if _target_node and is_instance_valid(_target_node):
        if _target_node.signal_name.is_connected(_on_signal):
            _target_node.signal_name.disconnect(_on_signal)
    _target_node = null
```

### 陷阱 2: 定时器未清理

**问题**:
```gdscript
func terminate(owner_node: Node) -> void:
    # ❌ 忘记清理定时器
```

**解决方案**:
```gdscript
func terminate(owner_node: Node) -> void:
    if _timer:
        if _timer.timeout.is_connected(_on_timer_timeout):
            _timer.timeout.disconnect(_on_timer_timeout)
        if owner_node and is_instance_valid(owner_node):
            owner_node.remove_child(_timer)
        _timer.queue_free()
        _timer = null
```

### 陷阱 3: 使用 get_node()

**问题**:
```gdscript
var node = get_node(target_node_path)  # ❌ 不支持相对路径
```

**解决方案**:
```gdscript
var node = owner_node.get_node_or_null(target_node_path)  # ✅ 支持相对路径
```

### 陷阱 4: 忘记检查 is_instance_valid()

**问题**:
```gdscript
if _target_node.signal_name.is_connected(_on_signal):  # ❌ 可能访问已释放的节点
```

**解决方案**:
```gdscript
if _target_node and is_instance_valid(_target_node):
    if _target_node.signal_name.is_connected(_on_signal):
        # 安全操作
```

### 陷阱 5: 信号重复连接

**问题**:
```gdscript
_target_node.signal_name.connect(_on_signal)  # ❌ 可能重复连接
```

**解决方案**:
```gdscript
if not _target_node.signal_name.is_connected(_on_signal):
    _target_node.signal_name.connect(_on_signal)
```

---

## 测试规范

### 测试文件结构

```gdscript
extends Node2D  # 或 Node3D，根据事件类型选择

## OnEventName 事件测试

func _ready():
    print("=== Testing OnEventName ===")
    test_initialization()
    test_trigger()
    test_terminate()
    print("=== All OnEventName tests passed! ===")
```

### 测试用例设计

**必需的测试**:
1. **初始化测试** - 验证信号正确连接
2. **触发测试** - 验证事件正确触发
3. **清理测试** - 验证信号正确断开
4. **触发一次测试** - 验证 trigger_once 功能
5. **错误处理测试** - 验证错误情况被正确处理

**测试示例**:
```gdscript
func test_initialization():
    var trigger = Trigger.new()
    var event = OnEventName.new()
    event.target_node = "^/TestNode"

    add_child(trigger)
    trigger.add_event(event)

    event.initialize(trigger)
    await get_tree().process_frame

    assert(event._target_node != null, "Target node should be found")
    assert(event._target_node.signal_name.is_connected(event._on_signal), "Signal should be connected")

func test_trigger():
    var trigger = Trigger.new()
    var event = OnEventName.new()

    var triggered = false
    event.triggered.connect(func(): triggered = true)

    add_child(trigger)
    trigger.add_event(event)
    event.initialize(trigger)

    # 触发条件
    _trigger_condition()

    await get_tree().process_frame

    assert(triggered, "Event should be triggered")

func test_terminate():
    var trigger = Trigger.new()
    var event = OnEventName.new()

    add_child(trigger)
    trigger.add_event(event)
    event.initialize(trigger)

    event.terminate(trigger)

    assert(not event._target_node.signal_name.is_connected(event._on_signal), "Signal should be disconnected")
```

---

## 快速参考

### 常用代码片段

#### 信号连接
```gdscript
if not _target_node.signal_name.is_connected(_on_signal):
    _target_node.signal_name.connect(_on_signal)
```

#### 信号断开
```gdscript
if _target_node and is_instance_valid(_target_node):
    if _target_node.signal_name.is_connected(_on_signal):
        _target_node.signal_name.disconnect(_on_signal)
```

#### 定时器创建
```gdscript
_timer = Timer.new()
_timer.wait_time = delay
_timer.one_shot = true
_timer.timeout.connect(_on_timer_timeout)
owner_node.add_child(_timer)
_timer.start()
```

#### 定时器清理
```gdscript
if _timer:
    if _timer.timeout.is_connected(_on_timer_timeout):
        _timer.timeout.disconnect(_on_timer_timeout)
    if owner_node and is_instance_valid(owner_node):
        owner_node.remove_child(_timer)
    _timer.queue_free()
    _timer = null
```

### 常用错误键

已定义的本地化错误键（参考 `translations.csv`）：
- `FUSE_ERROR_TARGET_NODE_NULL` - 目标节点为 null
- `FUSE_ERROR_TARGET_NODE_EMPTY` - 目标节点路径为空
- `FUSE_ERROR_TARGET_NODE_NOT_FOUND` - 目标节点未找到
- `FUSE_ERROR_INVALID_TARGET` - 目标节点类型无效
- `FUSE_ERROR_SIGNAL_NOT_FOUND` - 信号未找到
- `FUSE_ERROR_EVENT_INITIALIZATION` - 事件初始化失败

### 常用日志键

- `FUSE_LOG_EVENT_INITIALIZED` - 事件已初始化
- `FUSE_LOG_EVENT_TERMINATED` - 事件已清理
- `FUSE_LOG_EVENT_TRIGGERED` - 事件已触发
- `FUSE_LOG_EVENT_ALREADY_TRIGGERED` - 事件已触发（仅一次模式）
- `FUSE_LOG_EVENT_SIGNAL_SOURCE` - 信号源信息
- `FUSE_LOG_EVENT_RESET` - 事件状态已重置

---

## 总结

创建 Fuse 事件的关键要点：

1. ✅ **遵循命名规范** - `on_` 前缀，描述性名称
2. ✅ **实现必需方法** - `initialize()`, `terminate()`, `_update_resource_name()`
3. ✅ **正确管理信号** - 连接前检查，清理时断开
4. ✅ **清理所有资源** - 信号、定时器、引用
5. ✅ **使用本地化日志** - `_log_*_localized()` 方法
6. ✅ **添加完整测试** - 初始化、触发、清理
7. ✅ **验证资源清理** - 无内存泄漏

---

**文档维护**: Fuse 开发团队
**最后更新**: 2026-01-28
