# 创建 Fuse 事件指南

> **目标**: 为开发者提供完整的 Fuse 事件创建指引，基于现有事件实现经验和最佳实践。
> **权威规范**: 组件生成的最终权威是 [fuse-event-generator skill](../../../agent_skills/fuse-event-generator/SKILL.md)（模板、命名禁则与验证 gate）；本指南是其架构原理的详述。

**适用对象**: Fuse 系统开发者、贡献者

**最后更新**: 2026-06-17

**版本**: v2.1 - 添加 stopped 信号、性能追踪文档，修复断链

---

## 📋 目录

1. [事件 vs 指令](#事件-vs-指令)
2. [命名规范](#命名规范)
3. [图标规范](#图标规范)
4. [必需实现的方法](#必需实现的方法)
5. [可选实现的方法](#可选实现的方法)
6. [完整事件模板](#完整事件模板)
7. [创建步骤](#创建步骤)
8. [最佳实践](#最佳实践)
9. [常见陷阱](#常见陷阱)
10. [测试规范](#测试规范)

---

## 事件 vs 指令

理解 Event 和 Instruction 的区别是创建事件的第一步。

| 特性 | Event (事件) | Instruction (指令) |
|------|-------------|-------------------|
| **用途** | 监听条件，触发响应 | 执行具体动作 |
| **生命周期** | `initialize_with_runtime_instance()` → `terminate()` | `execute()` → 完成/取消/错误 |
| **信号** | `triggered(context: Node)`, `stopped(reason, context)` | `finished` |
| **执行状态** | 无执行状态 | PENDING/RUNNING/COMPLETED/CANCELLED/ERROR |
| **清理时机** | 在 `terminate()` 中清理 | 在 `_cleanup_resources()` 中清理 |
| **典型用途** | 检测输入、碰撞、信号等 | 移动节点、播放动画、设置变量等 |

**核心区别**:
- **Event** 是"被动的" - 等待某事发生，然后发出 `triggered` 信号；当条件满足或主动停止时发出 `stopped` 信号
- **Instruction** 是"主动的" - 执行某个动作，然后发出 `finished` 信号

---

## RuntimeInstance 架构

**推荐**: 新 Event 应该使用 RuntimeInstance 架构来管理运行时状态。

**为什么需要**:

当多个 Trigger 共享同一个 Event 资源时，如果 Event 包含运行时状态（如 `_is_hovered`），会导致状态污染问题。

**示例**:
```
两个按钮（start 和 continue）共享同一个 OnMouseEnter 资源
1. start Trigger 初始化 → Event._is_hovered = false
2. continue Trigger 初始化 → Event._is_hovered = false（覆盖！）
3. 鼠标进入 start → continue 的状态被修改 ❌
```

**解决方案**:

使用 RuntimeInstance 架构将状态从 Event 资源中分离：

```
Event (Resource) = 纯配置（@export 变量）
RuntimeEventInstance (RefCounted) = 运行时状态（每个 Trigger 独立）
```

**核心优势**:
- ✅ 完全状态隔离（每个 Trigger 有独立状态）
- ✅ 资源共享（配置仍可共享，节省内存）
- ✅ 向后兼容（保留旧的 `initialize()` 方法）
- ✅ 轻量级设计（RefCounted，约 200-500 字节/实例）

**如何实施**:

参考下文「RuntimeInstance 架构」与「获取默认运行时状态」章节。

**新版架构（自声明状态模式）**:

Event 通过实现 `get_default_runtime_state()` 方法声明自己的状态：

```gdscript
## 获取默认运行时状态（新版核心方法）
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["is_hovered"] = false
	base["trigger_count"] = 0
	return base
```

**快速上手**:

```gdscript
# ❌ 旧方式（状态共享问题）
var _is_hovered: bool = false

func _on_event_triggered():
    if _is_hovered:
        return
    _is_hovered = true

# ✅ 新方式（状态隔离 + 自声明状态）
var _runtime_instance_ref: RuntimeEventInstance = null

## 声明默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["is_hovered"] = false
	return base

func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance):
    _runtime_instance_ref = runtime_instance
    # ... 初始化 ...

func _on_event_triggered():
    var is_hovered = _runtime_instance_ref.get_runtime_state("is_hovered", false)
    if is_hovered:
        return
    _runtime_instance_ref.set_runtime_state("is_hovered", true)
```

**核心优势**:
- ✅ 无需修改 `RuntimeEventInstance` 核心代码
- ✅ 遵循开闭原则（Open/Closed Principle）
- ✅ 用户创建自定义 Event 更方便

---

## 命名规范

**重要**: 所有 Fuse 事件遵循以下命名规范，保持简洁一致。

### 文件命名

- **事件文件**: 使用 `snake_case`，**必须添加** `on_` 前缀
  - ✅ 正确：`on_ready.gd`, `on_input_key.gd`, `on_area_2d_enter.gd`
  - ❌ 错误：`event_on_ready.gd`, `input_key_event.gd`, `area_2d_enter_event.gd`

### 类命名

- **类名**: 使用 `PascalCase`，**必须添加** `On` 前缀
  - ✅ 正确：`class_name OnReady`, `class_name OnInputKey`, `class_name OnArea2DEnter`
  - ❌ 错误：`class_name EventOnReady`, `class_name InputKeyEvent`, `class_name Area2DEnterEvent`

### 测试文件命名

- **测试脚本**: `test_on_<event_name>.gd`
  - 例如：`test_on_ready.gd`, `test_on_input_key.gd`
- **测试场景**: `test_on_<event_name>.tscn`
  - 例如：`test_on_ready.tscn`, `test_on_input_key.tscn`

### 统一性原则

- 文件名、类名、测试文件名保持一致的基础名称
- 必须使用 `on_` / `On` 前缀
- 保持简洁可读

**示例**:
```
事件文件：   on_input_key.gd
类名：       class_name OnInputKey
测试脚本：   test_on_input_key.gd
测试场景：   test_on_input_key.tscn
```

---

## 图标规范

**图标选择原则**: 每个事件都应该配置图标，提升用户体验和可视化效果。

### 图标配置方式

**推荐：使用 Godot 内置图标**
```gdscript
metadata.builtin_icon = "KeyKeyboard"  # 使用 Godot 内置图标名称
```

**备选：使用自定义图标库**
```gdscript
metadata.custom_icon = "my_custom_icon"  # 使用导入的自定义图标
```

**向后兼容**
```gdscript
metadata.icon_name = "KeyKeyboard"  # 旧方式，仍然有效
metadata.icon = preload("res://icon.png")  # 直接指定纹理
```

### 内置图标命名参考

**常用图标名称**：
- **输入事件**: `KeyKeyboard`, `JoyButton`, `Mouse`
- **场景事件**: `HostNode`, `Scene`, `Play`
- **物理事件**: `CollisionShape2D`, `CollisionShape3D`, `PhysicsBody2D`, `PhysicsBody3D`
- **信号事件**: `Signals`, `Connect`, `Call`
- **时间事件**: `Time`, `Timer`, `Clock`
- **生命周期**: `Refresh`, `Loop`, `Animation`
- **通用**: `Script`, `Node`, `File`, `Folder`

**完整列表**: 参考 [icon-system-guide.md](icon-system-guide.md)

### 图标配置步骤

在 `_get_event_metadata()` 中配置图标：

```gdscript
static func _get_event_metadata() -> EventMetadata:
    var metadata = EventMetadata.new()
    metadata.builtin_icon = "KeyKeyboard"  # 配置图标
    return metadata
```

---

## 必需实现的方法

所有事件**必须**实现以下方法，否则会导致运行时错误或编译错误。

### 1. `_update_resource_name()` - 更新资源名称

**标记**: `@abstract` - **必须实现**

```gdscript
## 更新资源名称（必需）
##
## 根据事件属性更新 resource_name，用于在编辑器检查器中显示
func _update_resource_name():
    var parts = []
    parts.append("事件类型名称")
    if not some_property.is_empty():
        parts.append("'%s'" % some_property)
    resource_name = " ".join(parts)
```

**作用**:
- 在事件列表中显示有意义的名称
- 方便用户识别和区分不同事件配置

**示例**:
```gdscript
# 简单事件
func _update_resource_name():
    resource_name = "On Ready With Delay: %s" % delay_seconds

# 复杂事件
func _update_resource_name():
    var key_name = _get_key_name()
    match key_event_type:
        0:  # 按下
            resource_name = "按键按下: %s" % key_name
        1:  # 释放
            resource_name = "按键释放: %s" % key_name
```

---

### 2. `initialize()` - 初始化事件监听

**标记**: 虽然不是 `@abstract`，但**必须重写**

```gdscript
## 初始化事件监听（必需）
##
## 由 Trigger 在 _ready() 时调用，用来 "启动" 事件监听
## 'owner_node' 通常就是 Trigger 节点
## 子类将在这里连接信号
##
## 参数：
## - owner_node: Node - 拥有此事件的触发器节点
func initialize(owner_node: Node) -> void:
    # 1. 验证 owner_node
    if not owner_node:
        _create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
        return

    # 2. 连接信号或设置监听
    # 示例：连接节点信号
    if not owner_node.some_signal.is_connected(_on_some_event):
        owner_node.some_signal.connect(_on_some_event)

    # 3. 记录日志
    _log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})
```

**作用**:
- 设置事件监听（连接信号、设置定时器等）
- 验证配置参数
- 初始化内部状态

**重要**:
- 必须验证 `owner_node` 有效性
- 必须记录初始化日志
- 避免重复连接信号

---

### 2.1. `initialize_with_runtime_instance()` - 使用运行时实例初始化（推荐）

**推荐**: 对于有运行时状态的 Event，优先使用此方法。

**标记**: 虽然不是 `@abstract`，但强烈推荐重写

```gdscript
## 使用运行时实例初始化事件（推荐）
##
## 由 Trigger 在 _ready() 时调用，使用 RuntimeEventInstance 初始化事件
## 这是内存优化的一部分，避免不必要的资源复制
##
## 参数：
## - owner_node: Node - 拥有此事件的触发器节点
## - runtime_instance: RuntimeEventInstance - 运行时事件实例
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
    # 1. 保存 RuntimeEventInstance 引用
    _runtime_instance_ref = runtime_instance

    # 2. 验证参数
    if not owner_node:
        _create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
        return

    # 3. 连接信号或设置监听
    # 示例：连接节点信号
    if not owner_node.some_signal.is_connected(_on_some_event):
        owner_node.some_signal.connect(_on_some_event)

    # 4. 记录日志
    _log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})
```

**作用**:
- 提供独立的运行时状态管理（通过 RuntimeEventInstance）
- 支持多个 Trigger 共享同一个 Event 资源而不会产生状态污染
- 保持向后兼容（BaseEvent 默认实现会调用 `initialize()`）

**何时使用**:
- ✅ Event 有运行时状态（如 `_is_hovered`、`_has_triggered`）
- ✅ 多个 Trigger 可能共享同一个 Event 资源
- ✅ 需要状态隔离保证

**何时不需要**:
- ⚠️ Event 是无状态的（纯监听，不存储状态）
- ⚠️ 确定 Event 不会被多个 Trigger 共享

**状态管理示例**:
```gdscript
# 在 RuntimeEventInstance 中读取状态
var is_hovered: bool = false
if _runtime_instance_ref and _runtime_instance_ref.has_runtime_state("is_hovered"):
    is_hovered = _runtime_instance_ref.get_runtime_state("is_hovered")

# 在 RuntimeEventInstance 中写入状态
if _runtime_instance_ref:
    _runtime_instance_ref.set_runtime_state("is_hovered", true)
    _runtime_instance_ref.set_runtime_state("trigger_count",
        _runtime_instance_ref.get_runtime_state("trigger_count", 0) + 1
    )
```

**在 Event 中声明默认状态**（新版架构，推荐）:

在 Event 类中实现 `get_default_runtime_state()` 方法：

```gdscript
## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["has_triggered"] = false
	base["trigger_count"] = 0
	base["last_trigger_time"] = 0.0
	return base
```

**优势**:
- ✅ 无需修改 `RuntimeEventInstance` 核心代码
- ✅ 状态声明清晰明确
- ✅ 自动获得基础状态（initialized, trigger_count, last_trigger_time）
- ✅ RuntimeEventInstance 会自动调用此方法

**在 RuntimeEventInstance 中初始化状态**（旧版架构，已弃用）:

> ⚠️ **注意**: 这是旧版架构，已弃用。新 Event 应使用上面的自声明状态模式。

在 `addons/fuse/core/runtime_event_instance.gd` 的 `_initialize_runtime_state()` 方法中添加状态初始化：

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

### 3. `terminate()` - 清理事件监听

**标记**: 虽然不是 `@abstract`，但**必须重写**

```gdscript
## 清理事件监听（必需）
##
## 由 Trigger 在 _exit_tree() 时调用，用来 "清理" 事件监听
## 这是必要的，以防止内存泄漏
## 子类将在这里断开信号
##
## 参数：
## - owner_node: Node - 拥有此事件的触发器节点
func terminate(owner_node: Node) -> void:
    # 1. 断开所有信号连接
    if owner_node and owner_node.some_signal.is_connected(_on_some_event):
        owner_node.some_signal.disconnect(_on_some_event)

    # 2. 清理定时器
    if _timer:
        if _timer.timeout.is_connected(_on_timer_timeout):
            _timer.timeout.disconnect(_on_timer_timeout)
        if owner_node and is_instance_valid(owner_node):
            owner_node.remove_child(_timer)
        _timer.queue_free()
        _timer = null

    # 3. 重置状态
    _internal_state = false

    # 4. 记录日志
    _log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})
```

**作用**:
- 断开所有信号连接
- 清理定时器、Tween 等资源
- 重置内部状态
- 防止内存泄漏

**重要**:
- 必须断开所有在 `initialize()` 中连接的信号
- 必须清理所有创建的临时节点（Timer、Tween 等）
- 使用 `is_instance_valid()` 检查节点有效性
- 清理顺序：先断开信号 → 移除子节点 → 释放资源

---

### 4. `stopped` 信号与 `notify_stopped()` — 事件停止通知

**信号**: `stopped(reason: String, context: Dictionary)`

当事件停止时发出（例如 `OnInterval` 因条件满足或达到最大重复次数而停止）。

**停止原因常量**:
```gdscript
STOP_REASON_CONDITION_MET  # 条件满足而停止
STOP_REASON_MAX_REPEATS    # 达到最大重复次数
STOP_REASON_MANUAL         # 手动停止
STOP_REASON_ERROR          # 因错误而停止
```

**通知方法**:

```gdscript
## 通知事件停止
##
## 当事件停止时调用此方法，会发出 stopped 信号并通知 Trigger
##
## 参数：
## - reason: String - 停止原因（使用 STOP_REASON_* 常量）
## - context: Dictionary - 停止上下文信息（可选）
func notify_stopped(reason: String, context: Dictionary = {}) -> void:
    # 发出 stopped 信号
    stopped.emit(reason, context)

    # 通知 Trigger 发出 event_stopped 信号
    if _trigger_ref:
        var stop_context = context.duplicate()
        stop_context["event"] = self
        stop_context["event_type"] = get_event_type()
        stop_context["event_description"] = get_description()
        if _trigger_ref.has_signal("event_stopped"):
            _trigger_ref.emit_signal("event_stopped", reason, stop_context)
```

**使用示例**:
```gdscript
# 在重复事件中，当达到最大次数时停止
func _on_event_triggered():
    if max_repeats > 0 and repeat_count >= max_repeats:
        notify_stopped(STOP_REASON_MAX_REPEATS, {"repeat_count": repeat_count})
        return
```

**重要**:
- 必须在 `set_trigger_ref()` 之后调用（Trigger 会在初始化时自动设置）
- `notify_stopped()` 会自动通知 Trigger 发出 `event_stopped` 信号
- 停止上下文信息用于调试和日志记录

---

### 5. `_emit_triggered()` — 推荐的事件触发方式

**推荐使用 `_emit_triggered()` 而非直接 `triggered.emit()`**：

```gdscript
## 发出 triggered 信号（自动设置 trigger meta）
##
## 此方法会自动设置 context 的 "trigger" meta，防止信号广播到其他 RuntimeEventInstance
## 适用于池化对象和共享 Event 资源的场景
##
## 参数：
## - context: Node - 事件上下文节点
## - owner_node: Node - 触发器节点（可选，如果 _trigger_ref 已设置）
func _emit_triggered(context: Node, owner_node: Node = null) -> void:
    var trigger_node = owner_node if owner_node else _trigger_ref
    if context and trigger_node:
        context.set_meta("trigger", trigger_node)
    triggered.emit(context)
```

**对比**:
```gdscript
# ❌ 旧方式：直接 emit，可能缺少 trigger meta
triggered.emit(some_node)

# ✅ 推荐方式：自动设置 trigger meta
_emit_triggered(some_node)
# 或指定 owner_node
_emit_triggered(context_node, owner_node)
```

---

## 可选实现的方法

这些方法不是强制要求，但强烈建议实现以提供完整的功能。

### 1. `get_description()` - 获取事件描述

```gdscript
## 获取事件描述（推荐）
##
## 返回事件的描述信息，用于在日志和调试中显示
##
## 返回：
## - String - 事件的描述信息
func get_description() -> String:
    return "事件描述字符串"
```

**示例**:
```gdscript
func get_description() -> String:
    if delay_seconds > 0:
        return "场景就绪后 %.2f 秒触发" % delay_seconds
    else:
        return "场景就绪时触发"
```

---

### 2. `get_event_type()` - 获取事件类型

```gdscript
## 获取事件类型（推荐）
##
## 返回事件的唯一类型标识符
##
## 返回：
## - String - 事件类型名称
func get_event_type() -> String:
    return "your_event_type"
```

**命名建议**:
- 使用 `snake_case`
- 简洁且具有描述性
- 例如：`"scene_ready"`, `"input_key"`, `"area_2d_enter"`

---

### 3. `get_event_category()` - 获取事件分类

```gdscript
## 获取事件分类（推荐）
##
## 返回事件的分类信息，用于在编辑器中组织事件
##
## 返回：
## - String - 事件分类名称
func get_event_category() -> String:
    return "your_category"
```

**常用分类**:
- `"scene"` - 场景生命周期事件
- `"input"` - 输入事件
- `"physics"` - 物理事件
- `"signal"` - 信号事件
- `"timer"` - 定时器事件

---

### 4. `validate()` - 验证事件配置

```gdscript
## 验证事件配置（推荐）
##
## 验证事件参数的有效性
##
## 返回：
## - Array[String] - 错误信息数组，如果为空则表示验证通过
func validate() -> Array[String]:
    var errors: Array[String] = []

    # 添加自定义验证
    if some_property <= 0:
        errors.append("属性必须大于0")

    return errors
```

**示例**:
```gdscript
func validate() -> Array[String]:
    var errors: Array[String] = []

    # 验证按键代码
    if key_code == KEY_NONE:
        errors.append("必须指定有效的按键代码")

    # 验证数值范围
    if delay_seconds < 0:
        errors.append("延迟时间不能为负数")

    return errors
```

---

### 5. `reset()` - 重置事件状态

```gdscript
## 重置事件状态（可选）
##
## 重置事件到初始状态，允许重新使用
## 子类可以重写此方法来重置特定状态
func reset() -> void:
    super.reset()  # 调用父类重置
    # 重置自定义状态
    _has_triggered = false
    _is_key_pressed = false
```

**使用场景**:
- 需要重新使用事件实例
- 清除运行时状态
- 准备下一次触发

---

### 6. `_get_event_metadata()` - 获取事件元数据

```gdscript
## 获取事件元数据（推荐）
##
## 静态方法，返回事件的元数据信息
## 用于事件选择器和编辑器显示
##
## 返回：
## - EventMetadata - 事件元数据对象
static func _get_event_metadata() -> EventMetadata:
    var metadata = EventMetadata.new()
    metadata.name_key = "FUSE_EVENT_XXX_NAME"
    metadata.category_key = "FUSE_EVENT_CATEGORY_XXX"
    metadata.description_key = "FUSE_EVENT_XXX_DESC"
    metadata.keywords = ["keyword1", "keyword2"]
    metadata.builtin_icon = "Script"
    return metadata
```

**元数据字段**:
- `name_key` - 事件名称的翻译键
- `category_key` - 分类名称的翻译键
- `description_key` - 描述的翻译键
- `keywords` - 搜索关键词数组
- `builtin_icon` - 内置图标名称

---

### 7. `_start_performance_track()` / `_stop_performance_track()` — 性能追踪

**用途**: 自动追踪事件的执行时间，使用 `FusePerformanceTracker`。

```gdscript
## 开始性能追踪
##
## 使用事件类型作为追踪名称，自动追踪所有事件的执行时间
## 示例追踪名称：OnProcess.on_process, OnPhysicsProcess.on_physics_process
##
## 参数：
## - method_name: String - 方法名称（默认为 "execute"）
func _start_performance_track(method_name: String = "execute") -> void:
    var track_name = "%s.%s" % [get_event_type(), method_name]
    FusePerformanceTracker.get_instance().start_track(track_name)

## 停止性能追踪
##
## 与 _start_performance_track 配对使用
##
## 参数：
## - method_name: String - 方法名称（必须与 _start_performance_track 一致）
func _stop_performance_track(method_name: String = "execute") -> void:
    var track_name = "%s.%s" % [get_event_type(), method_name]
    FusePerformanceTracker.get_instance().stop_track(track_name)
```

**使用示例**:
```gdscript
func _on_event_triggered():
    _start_performance_track("trigger")
    # ... 事件处理逻辑 ...
    _stop_performance_track("trigger")
    _emit_triggered(context_node)
```

**重要**:
- `_start_performance_track` 和 `_stop_performance_track` 必须配对使用
- 两个方法的 `method_name` 参数必须一致
- 追踪名称格式：`<event_type>.<method_name>`（如 `on_interval.trigger`）

---

## 完整事件模板

### 简单同步事件模板

```gdscript
@tool
@icon("res://addons/fuse/icons/builtin/Script.png")
extends BaseEvent
class_name EventSimpleTemplate

## 简单事件模板

# 参数定义
var target_node: NodePath = NodePath("")

# 内部状态
var _target_node_ref: Node = null

## 更新资源名称（必需）
func _update_resource_name():
    resource_name = "简单事件: %s" % target_node

## 初始化事件监听（必需）
func initialize(owner_node: Node) -> void:
    _log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

    # 验证 owner_node
    if not owner_node:
        _create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
        return

    # 验证目标节点
    if target_node.is_empty():
        _create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.CONFIGURATION_ERROR, {})
        return

    _target_node_ref = owner_node.get_node_or_null(target_node)
    if not _target_node_ref:
        _create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(target_node)})
        return

    # 连接信号
    if not _target_node_ref.some_signal.is_connected(_on_event_triggered):
        _target_node_ref.some_signal.connect(_on_event_triggered)

    _log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
    # 断开信号连接
    if _target_node_ref and is_instance_valid(_target_node_ref):
        if _target_node_ref.some_signal.is_connected(_on_event_triggered):
            _target_node_ref.some_signal.disconnect(_on_event_triggered)

    # 清理引用
    _target_node_ref = null

    _log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 事件处理回调
func _on_event_triggered():
    _log_info_localized("FUSE_LOG_EVENT_TRIGGERED", {"event_type": get_event_type()})
    _emit_triggered(_target_node_ref)  # 推荐：自动设置 trigger meta

## 获取事件描述（推荐）
func get_description() -> String:
    return "当 %s 发生时触发" % str(target_node)

## 获取事件类型（推荐）
func get_event_type() -> String:
    return "simple_template"

## 获取事件分类（推荐）
func get_event_category() -> String:
    return "template"

## 验证事件配置（推荐）
func validate() -> Array[String]:
    var errors: Array[String] = []

    if target_node.is_empty():
        errors.append("目标节点不能为空")

    return errors

## 获取事件元数据（推荐）
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

### 复杂异步事件模板

```gdscript
@tool
@icon("res://addons/fuse/icons/builtin/Timer.png")
extends BaseEvent
class_name EventComplexTemplate

## 复杂事件模板（带定时器）

# 参数定义
@export var delay_seconds: float = 0.0:
    set(value):
        delay_seconds = value
        _update_resource_name()

@export var trigger_once: bool = false:
    set(value):
        trigger_once = value
        _update_resource_name()

# 内部状态
var _timer: Timer = null
var _has_triggered: bool = false
var _owner_node_ref: Node = null

## 更新资源名称（必需）
func _update_resource_name():
    var once_text = " [仅一次]" if trigger_once else ""
    resource_name = "复杂事件: 延迟 %.2fs%s" % [delay_seconds, once_text]

## 初始化事件监听（必需）
func initialize(owner_node: Node) -> void:
    _log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

    # 验证 owner_node
    if not owner_node:
        _create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
        return

    _owner_node_ref = owner_node

    # 检查是否在场景树中
    if owner_node.is_inside_tree():
        _start_timer()
    else:
        # 等待进入场景树后再启动
        owner_node.tree_entered.connect(_on_tree_entered)

    _log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
    # 断开 tree_entered 连接
    if owner_node and owner_node.tree_entered.is_connected(_on_tree_entered):
        owner_node.tree_entered.disconnect(_on_tree_entered)

    # 清理定时器
    _cleanup_timer()

    # 重置状态
    _has_triggered = false
    _owner_node_ref = null

    _log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 启动定时器
func _start_timer():
    if not _owner_node_ref:
        return

    _cleanup_timer()

    if delay_seconds > 0:
        # 创建定时器
        _timer = Timer.new()
        _timer.wait_time = delay_seconds
        _timer.one_shot = true
        _timer.timeout.connect(_on_timer_timeout)
        _owner_node_ref.add_child(_timer)
        _timer.start()
        _log_debug_localized("FUSE_LOG_EVENT_DELAY", {"delay": delay_seconds})
    else:
        # 立即触发
        call_deferred("_deferred_trigger")

## 清理定时器
func _cleanup_timer():
    if _timer:
        # 先停止定时器
        _timer.stop()

        # 断开信号
        if _timer.timeout.is_connected(_on_timer_timeout):
            _timer.timeout.disconnect(_on_timer_timeout)

        # 从场景树中移除并释放
        if _owner_node_ref and is_instance_valid(_owner_node_ref):
            _owner_node_ref.remove_child(_timer)

        _timer.queue_free()
        _timer = null

## 当节点进入场景树时
func _on_tree_entered():
    _start_timer()

## 定时器超时回调
func _on_timer_timeout():
    _trigger_event()

## 延迟触发
func _deferred_trigger():
    _trigger_event()

## 触发事件
func _trigger_event():
    # 检查是否只触发一次
    if trigger_once and _has_triggered:
        _log_debug_localized("FUSE_LOG_EVENT_ALREADY_TRIGGERED", {})
        return

    _has_triggered = true
    _log_info_localized("FUSE_LOG_EVENT_TRIGGERED", {"event_type": get_event_type()})
    _emit_triggered(_owner_node_ref)  # 推荐：自动设置 trigger meta

## 获取事件描述（推荐）
func get_description() -> String:
    var once_text = trigger_once ? " (仅一次)" : ""
    if delay_seconds > 0:
        return "延迟 %.2f 秒后触发%s" % [delay_seconds, once_text]
    else:
        return "立即触发%s" % once_text

## 获取事件类型（推荐）
func get_event_type() -> String:
    return "complex_template"

## 获取事件分类（推荐）
func get_event_category() -> String:
    return "template"

## 验证事件配置（推荐）
func validate() -> Array[String]:
    var errors: Array[String] = []

    if delay_seconds < 0:
        errors.append("延迟时间不能为负数")

    return errors

## 重置事件状态（可选）
func reset() -> void:
    super.reset()
    _has_triggered = false
    if _timer:
        _timer.stop()
    _log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})

## 获取事件元数据（推荐）
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

### RuntimeInstance 感知的事件模板（推荐）

```gdscript
@tool
@icon("res://addons/fuse/icons/builtin/Script.png")
extends BaseEvent
class_name OnRuntimeInstanceTemplate

## RuntimeInstance 感知事件模板
##
## 此模板展示如何使用 RuntimeEventInstance 管理运行时状态
## 适用于有运行时状态的事件，或可能被多个 Trigger 共享的事件
##
## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - _has_triggered: bool - 是否已触发
## - _trigger_count: int - 触发次数
##
## 架构版本: 自声明状态模式 v2.0

# 参数定义
@export var target_node_path: NodePath = NodePath("")
@export var trigger_once_per_activation: bool = true

# 🔧 运行时状态现在存储在 RuntimeEventInstance 中
var _runtime_instance_ref: RuntimeEventInstance = null
var _signal_connections: Dictionary = {}

## 更新资源名称（必需）
func _update_resource_name():
    var once_text = " [仅一次]" if trigger_once_per_activation else ""
    resource_name = "RuntimeInstance 模板: %s%s" % [target_node_path, once_text]

## 获取默认运行时状态（新版核心方法）
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["has_triggered"] = false
	base["trigger_count"] = 0
	return base

## 使用运行时实例初始化事件（推荐）
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
    if Engine.is_editor_hint():
        return

    # 🔧 保存 RuntimeEventInstance 引用
    _runtime_instance_ref = runtime_instance

    # 验证参数
    if not owner_node:
        _create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
        return

    # 验证目标节点
    if target_node_path.is_empty():
        _create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.CONFIGURATION_ERROR, {})
        return

    var target_node = owner_node.get_node_or_null(target_node_path)
    if not target_node:
        _create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(target_node_path)})
        return

    # 连接信号
    _connect_signals(target_node, owner_node)

    _log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
    # 断开所有信号连接
    _disconnect_signals()

    # 🔧 清理 RuntimeEventInstance 的状态
    if _runtime_instance_ref:
        _runtime_instance_ref.set_runtime_state("has_triggered", false)
        _runtime_instance_ref.set_runtime_state("trigger_count", 0)

    # 清理引用
    _runtime_instance_ref = null

    _log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 事件处理回调
func _on_event_triggered(context: Node):
    _log_info_localized("FUSE_LOG_EVENT_TRIGGERED", {"event_type": get_event_type()})

    # 🔧 使用 RuntimeEventInstance 的状态
    var has_triggered: bool = false
    if _runtime_instance_ref and _runtime_instance_ref.has_runtime_state("has_triggered"):
        has_triggered = _runtime_instance_ref.get_runtime_state("has_triggered")

    # 检查触发条件
    if trigger_once_per_activation and has_triggered:
        _log_debug_localized("FUSE_LOG_EVENT_ALREADY_TRIGGERED", {})
        return

    # 🔧 更新 RuntimeEventInstance 的状态
    if _runtime_instance_ref:
        _runtime_instance_ref.set_runtime_state("has_triggered", true)
        _runtime_instance_ref.set_runtime_state("trigger_count",
            _runtime_instance_ref.get_runtime_state("trigger_count", 0) + 1
        )
        _runtime_instance_ref.set_runtime_state("last_trigger_time", Time.get_unix_time_from_system())
        _runtime_instance_ref.update_trigger_stats()

    # 发出事件信号
    _emit_triggered(context)  # 推荐：自动设置 trigger meta

## 连接信号
func _connect_signals(target_node: Node, owner: Node) -> void:
    # 示例：连接 mouse_entered 信号
    if target_node.has_signal("mouse_entered") and not target_node.mouse_entered.is_connected(_on_event_triggered):
        target_node.mouse_entered.connect(_on_event_triggered.bind(owner))
        _signal_connections[target_node] = "mouse_entered"

## 断开信号
func _disconnect_signals() -> void:
    for target_node in _signal_connections:
        if is_instance_valid(target_node):
            var signal_name = _signal_connections[target_node]
            if target_node.has_signal(signal_name):
                var signal_info = target_node.get_signal_list().filter(func(s): return s.name == signal_name)[0]
                if signal_info and target_node.signal_name.is_connected(_on_event_triggered):
                    target_node.signal_name.disconnect(_on_event_triggered)

    _signal_connections.clear()

## 获取事件描述（推荐）
func get_description() -> String:
    if trigger_once_per_activation:
        return "当 %s 被激活时触发（仅一次）" % str(target_node_path)
    else:
        return "当 %s 被激活时触发" % str(target_node_path)

## 获取事件类型（推荐）
func get_event_type() -> String:
    return "runtime_instance_template"

## 获取事件分类（推荐）
func get_event_category() -> String:
    return "template"

## 验证事件配置（推荐）
func validate() -> Array[String]:
    var errors: Array[String] = []

    if target_node_path.is_empty():
        errors.append("目标节点路径不能为空")

    return errors

## 重置事件状态（可选）
func reset() -> void:
    super.reset()

    # 🔧 重置 RuntimeEventInstance 的状态
    if _runtime_instance_ref:
        _runtime_instance_ref.set_runtime_state("has_triggered", false)
        _runtime_instance_ref.set_runtime_state("trigger_count", 0)

    _log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})

## 获取事件元数据（推荐）
static func _get_event_metadata() -> EventMetadata:
    var metadata = EventMetadata.new()
    metadata.name_key = "FUSE_EVENT_RUNTIME_INSTANCE_TEMPLATE_NAME"
    metadata.category_key = "FUSE_EVENT_CATEGORY_TEMPLATE"
    metadata.description_key = "FUSE_EVENT_RUNTIME_INSTANCE_TEMPLATE_DESC"
    metadata.keywords = ["template", "模板", "runtime", "运行时", "instance", "实例"]
    metadata.builtin_icon = "Script"
    return metadata
```

**关键区别**（与简单模板相比）:
- ✅ 使用 `initialize_with_runtime_instance()` 而非 `initialize()`
- ✅ 实现 `get_default_runtime_state()` 声明状态（新版核心）
- ✅ 通过 `RuntimeEventInstance` 管理状态
- ✅ 支持多个 Trigger 共享同一 Event 资源
- ✅ 状态完全隔离，无污染风险
- ✅ **无需修改 `RuntimeEventInstance` 核心代码**

**迁移检查清单**（新版）:
- [ ] 删除 Event 类中的运行时状态变量（如 `_has_triggered`）
- [ ] 添加 `_runtime_instance_ref: RuntimeEventInstance` 引用
- [ ] ⭐ **实现 `get_default_runtime_state()` 方法（新版核心）**
- [ ] 实现 `initialize_with_runtime_instance()` 方法
- [ ] 修改所有状态访问使用 `get_runtime_state()` / `set_runtime_state()`
- [ ] 在 `terminate()` 和 `reset()` 中清理状态

---

## 创建步骤

### Step 1: 创建事件类骨架

创建事件文件 `addons/fuse/events/on_<your_event_name>.gd`：

```gdscript
@tool
@icon("res://addons/fuse/icons/builtin/Script.png")
extends BaseEvent
class_name OnYourEventName

## 事件描述

# 参数定义
@export var your_property: String = ""

## 更新资源名称（必需）
func _update_resource_name():
    resource_name = "Your Event Name: %s" % your_property

## 初始化事件监听（必需）
func initialize(owner_node: Node) -> void:
    # TODO: 实现初始化逻辑
    pass

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
    # TODO: 实现清理逻辑
    pass
```

### Step 2: 实现核心方法

**2.1 实现 `initialize()`**:
```gdscript
func initialize(owner_node: Node) -> void:
    _log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

    # 验证 owner_node
    if not owner_node:
        _create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
        return

    # 连接信号或设置监听
    # ...

    _log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})
```

**2.2 实现 `terminate()`**:
```gdscript
func terminate(owner_node: Node) -> void:
    # 断开所有信号连接
    # ...

    # 清理定时器和其他资源
    # ...

    _log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})
```

**2.3 实现事件处理回调**:
```gdscript
func _on_event_triggered():
    _log_info_localized("FUSE_LOG_EVENT_TRIGGERED", {"event_type": get_event_type()})
    _emit_triggered(context_node)  # 推荐：自动设置 trigger meta
```

### Step 3: 添加本地化翻译

在 `addons/fuse/localization/translations.csv` 添加：

```csv
key,zh_CN,en_US
FUSE_EVENT_YOUR_EVENT_NAME,你的事件名称,Your Event Name
FUSE_EVENT_CATEGORY_YOUR_CATEGORY,你的分类,Your Category
FUSE_EVENT_YOUR_EVENT_DESC,事件描述,Event description
FUSE_LOG_EVENT_YOUR_EVENT_TRIGGERED,事件已触发,Event triggered
FUSE_ERROR_YOUR_EVENT_ERROR,错误消息,Error message
```

**注意**：
- 使用 `NAME` 后缀表示事件名称
- 使用 `DESC` 后缀表示事件描述
- 使用 `LOG_EVENT_` 前缀表示日志消息
- 使用 `ERROR_` 后缀表示错误消息
- 所有占位符使用 `{variable_name}` 格式

### Step 4: 创建测试场景

**Step 4.1: 创建测试场景文件**

创建 `tests/events/test_<event_name>.tscn`：

```gdscript
[gd_scene load_steps=2 format=3 uid="uid://test_xxx"]

[ext_resource type="Script" path="res://tests/events/test_xxx.gd" id="1"]

[node name="TestXxx" type="Node"]
script = ExtResource("1")

[node name="Trigger" type="Node" parent="."]
```

**Step 4.2: 创建测试脚本**

创建 `tests/events/test_on_<event_name>.gd`：

```gdscript
extends Node

## OnYourEventName 事件测试

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

    # 连接事件信号
    var triggered = false
    event.triggered.connect(func():
        triggered = true
        print("  Event triggered!")
    )

    # 初始化事件
    event.initialize(trigger)
    await get_tree().process_frame

    # 验证结果
    assert(condition, "Verification message")
    print("  ✓ Test 1 passed\n")

    # 清理
    event.terminate(trigger)
    trigger.queue_free()

func test_edge_cases():
    print("Test 2: Edge cases")
    # 测试边界情况...
    print("  ✓ Test 2 passed\n")
```

### Step 5: RuntimeInstance 迁移（推荐）

**为何迁移**:
- ✅ 完全状态隔离（每个 Trigger 有独立状态）
- ✅ 资源共享（配置仍可共享，节省内存）
- ✅ 支持多个 Trigger 共享同一个 Event 资源
- ✅ 轻量级设计（RefCounted，约 200-500 字节/实例）
- ✅ **无需修改核心代码（新版自声明状态模式）**

**快速迁移步骤（新版：自声明状态模式）**:

**5.1 删除状态变量**:
```gdscript
# ❌ 删除这些运行时状态变量
var _has_triggered: bool = false
var _trigger_count: int = 0
var _last_trigger_time: float = 0.0

# ✅ 添加 RuntimeEventInstance 引用
var _runtime_instance_ref: RuntimeEventInstance = null
```

**5.2 实现 `get_default_runtime_state()` 方法**（⭐ **新版核心步骤**）:
```gdscript
## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["has_triggered"] = false
	base["trigger_count"] = 0
	base["last_trigger_time"] = 0.0
	return base
```

**优势**:
- ✅ 无需修改 `RuntimeEventInstance` 核心代码
- ✅ 状态声明清晰明确
- ✅ 自动获得基础状态

**5.3 实现 `initialize_with_runtime_instance()`**:
```gdscript
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
    if Engine.is_editor_hint():
        return

    # 保存 RuntimeEventInstance 引用
    _runtime_instance_ref = runtime_instance

    # 验证参数
    if not owner_node:
        _create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
        return

    # 连接信号
    # ... 其余初始化逻辑 ...

    _log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})
```

**5.4 修改状态访问**:
```gdscript
# ❌ 旧方式：直接使用成员变量
if _has_triggered:
    return
_has_triggered = true

# ✅ 新方式：通过 RuntimeEventInstance
var has_triggered: bool = false
if _runtime_instance_ref and _runtime_instance_ref.has_runtime_state("has_triggered"):
    has_triggered = _runtime_instance_ref.get_runtime_state("has_triggered")

if has_triggered:
    return

if _runtime_instance_ref:
    _runtime_instance_ref.set_runtime_state("has_triggered", true)
```

**5.5 清理状态**:
```gdscript
func terminate(owner_node: Node) -> void:
    # 断开信号
    # ... 其余清理逻辑 ...

    # 清理 RuntimeEventInstance 的状态
    if _runtime_instance_ref:
        _runtime_instance_ref.set_runtime_state("has_triggered", false)
        _runtime_instance_ref.set_runtime_state("trigger_count", 0)

    # 清理引用
    _runtime_instance_ref = null

    _log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

func reset() -> void:
    super.reset()

    # 重置 RuntimeEventInstance 的状态
    if _runtime_instance_ref:
        _runtime_instance_ref.set_runtime_state("has_triggered", false)
        _runtime_instance_ref.set_runtime_state("trigger_count", 0)
```

**迁移检查清单**（新版）:
- [ ] 删除 Event 类中的运行时状态变量
- [ ] 添加 `_runtime_instance_ref: RuntimeEventInstance` 引用
- [ ] ⭐ **实现 `get_default_runtime_state()` 方法（新版核心）**
- [ ] 实现 `initialize_with_runtime_instance()` 方法
- [ ] 修改所有状态访问使用 `get_runtime_state()` / `set_runtime_state()`
- [ ] 在 `terminate()` 和 `reset()` 中清理状态
- [ ] 测试多个 Trigger 共享同一个 Event 资源的场景

---

### Step 6: 测试验证

1. 在 Godot 中打开测试场景
2. 运行测试，确认所有测试用例通过
3. 检查编辑器中的 Inspector 显示是否正确
4. 验证本地化是否生效
5. 验证资源清理是否正确（无内存泄漏）
6. **如果迁移到 RuntimeInstance**：测试多个 Trigger 共享同一 Event 资源

---

## 最佳实践

### 1. 信号管理

**原则**: 所有信号连接必须在 `terminate()` 中断开。

```gdscript
# ✅ 好的做法
func initialize(owner_node: Node):
    if not owner_node.some_signal.is_connected(_on_callback):
        owner_node.some_signal.connect(_on_callback)

func terminate(owner_node: Node):
    if owner_node and owner_node.some_signal.is_connected(_on_callback):
        owner_node.some_signal.disconnect(_on_callback)
```

```gdscript
# ❌ 避免重复连接
func initialize(owner_node: Node):
    owner_node.some_signal.connect(_on_callback)  # 可能重复连接
```

### 2. 资源清理

**原则**: 所有在 `initialize()` 中创建的资源必须在 `terminate()` 中清理。

```gdscript
# ✅ 好的做法
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
# ❌ 遗漏清理
func terminate(owner_node: Node):
    if _timer:
        _timer.queue_free()  # 忘记断开信号和移除子节点
        _timer = null
```

### 3. 节点有效性检查

**原则**: 在使用节点引用前，使用 `is_instance_valid()` 检查有效性。

```gdscript
# ✅ 好的做法
func terminate(owner_node: Node):
    if _target_node and is_instance_valid(_target_node):
        if _target_node.some_signal.is_connected(_on_callback):
            _target_node.some_signal.disconnect(_on_callback)
```

```gdscript
# ❌ 不检查有效性
func terminate(owner_node: Node):
    if _target_node:
        _target_node.some_signal.disconnect(_on_callback)  # 可能已释放
```

### 4. 错误处理

**原则**: 所有错误都应该使用本地化错误消息。

```gdscript
# ✅ 好的做法
if not owner_node:
    _create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
    return
```

```gdscript
# ❌ 避免硬编码
if not owner_node:
    push_error("Owner node is null")  # 不推荐
    return
```

### 5. 日志记录

**原则**: 使用本地化日志方法记录关键操作。

```gdscript
# ✅ 好的做法
func initialize(owner_node: Node):
    _log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})
    # ...

func _on_event_triggered():
    _log_info_localized("FUSE_LOG_EVENT_TRIGGERED", {"event_type": get_event_type()})
    _emit_triggered(context_node)  # 推荐：自动设置 trigger meta
```

### 6. 属性验证

**原则**: 使用 `validate()` 方法验证配置参数。

```gdscript
# ✅ 好的做法
func validate() -> Array[String]:
    var errors: Array[String] = []

    if target_path.is_empty():
        errors.append("目标路径不能为空")

    if delay_seconds < 0:
        errors.append("延迟时间不能为负数")

    return errors
```

### 7. 状态重置

**原则**: 实现 `reset()` 方法以支持事件重用。

```gdscript
# ✅ 好的做法
func reset() -> void:
    super.reset()
    _has_triggered = false
    _is_active = false
    if _timer:
        _timer.stop()
    _log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})
```

### 8. 编辑器模式检查

**原则**: 在 `initialize()` 中检查编辑器模式。

```gdscript
# BaseEvent 已经处理了编辑器检查
# 子类不需要额外处理
func initialize(owner_node: Node) -> void:
    # BaseEvent 会在编辑器模式下跳过初始化
    # 直接实现运行时逻辑即可
    ...
```

---

### 9. RuntimeInstance 状态管理

**原则**: 使用 RuntimeInstance 架构管理有状态的 Event。

```gdscript
# ✅ 好的做法：使用 RuntimeInstance 管理状态（新版：自声明状态模式）
var _runtime_instance_ref: RuntimeEventInstance = null

## 获取默认运行时状态（新版核心方法）
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
# ❌ 避免直接在 Event 中存储运行时状态
var _has_triggered: bool = false  # 多个 Trigger 共享此 Event 时会冲突

func _on_event_triggered():
    if _has_triggered:  # 可能读取到其他 Trigger 的状态
        return
    _has_triggered = true  # 可能覆盖其他 Trigger 的状态
```

**状态访问模式**:
```gdscript
# 读取状态（带默认值）
var value = _runtime_instance_ref.get_runtime_state("key", default_value)

# 检查状态是否存在
if _runtime_instance_ref.has_runtime_state("key"):
    # 状态存在
    pass

# 写入状态
_runtime_instance_ref.set_runtime_state("key", new_value)
```

**新版架构优势**（自声明状态模式）:
- ✅ Event 通过 `get_default_runtime_state()` 声明状态
- ✅ 无需修改 `RuntimeEventInstance` 核心代码
- ✅ 遵循开闭原则（Open/Closed Principle）
- ✅ 用户创建自定义 Event 更方便

**何时使用 RuntimeInstance**:
- ✅ Event 有运行时状态（如 `_is_hovered`、`_has_triggered`）
- ✅ 多个 Trigger 可能共享同一个 Event 资源
- ✅ 需要状态隔离保证

**何时不使用**:
- ⚠️ Event 是无状态的（纯监听，不存储状态）
- ⚠️ 确定 Event 不会被多个 Trigger 共享（节省内存）

---

## 常见陷阱

### 陷阱 1: 忘记断开信号连接

**问题**:
```gdscript
func initialize(owner_node: Node):
    owner_node.some_signal.connect(_on_callback)

func terminate(owner_node: Node):
    # ❌ 忘记断开信号
    pass
```

**后果**: 信号仍然保持连接，可能导致内存泄漏或意外触发。

**解决方案**:
```gdscript
func terminate(owner_node: Node):
    if owner_node and owner_node.some_signal.is_connected(_on_callback):
        owner_node.some_signal.disconnect(_on_callback)
```

---

### 陷阱 2: Timer 未正确清理

**问题**:
```gdscript
func terminate(owner_node: Node):
    _timer.queue_free()  # ❌ 忘记断开信号和移除子节点
    _timer = null
```

**后果**: Timer 可能仍在运行，导致错误或内存泄漏。

**解决方案**:
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

### 陷阱 3: 节点引用未检查有效性

**问题**:
```gdscript
func terminate(owner_node: Node):
    _target_node.some_signal.disconnect(_on_callback)  # ❌ 节点可能已释放
```

**后果**: 尝试访问已释放的节点导致错误。

**解决方案**:
```gdscript
func terminate(owner_node: Node):
    if _target_node and is_instance_valid(_target_node):
        if _target_node.some_signal.is_connected(_on_callback):
            _target_node.some_signal.disconnect(_on_callback)
```

---

### 陷阱 4: 重复连接信号

**问题**:
```gdscript
func initialize(owner_node: Node):
    owner_node.some_signal.connect(_on_callback)  # ❌ 每次调用都连接
```

**后果**: 信号回调被调用多次。

**解决方案**:
```gdscript
func initialize(owner_node: Node):
    if not owner_node.some_signal.is_connected(_on_callback):
        owner_node.some_signal.connect(_on_callback)
```

---

### 陷阱 5: 资源清理顺序错误

**问题**:
```gdscript
func terminate(owner_node: Node):
    if owner_node:
        owner_node.remove_child(_timer)  # ❌ 先移除子节点
    if _timer.timeout.is_connected(_on_timer_timeout):
        _timer.timeout.disconnect(_on_timer_timeout)  # 后断开信号（可能失败）
```

**后果**: 信号断开可能失败。

**解决方案**:
```gdscript
func terminate(owner_node: Node):
    if _timer:
        if _timer.timeout.is_connected(_on_timer_timeout):
            _timer.timeout.disconnect(_on_timer_timeout)  # 先断开信号
        if owner_node and is_instance_valid(owner_node):
            owner_node.remove_child(_timer)  # 后移除子节点
        _timer.queue_free()
```

**清理顺序**: 断开信号 → 移除子节点 → 释放资源

---

### 陷阱 6: 忘记触发信号

**问题**:
```gdscript
func _on_event_triggered():
    # ❌ 忘记发出 triggered 信号
    _log_info("Event triggered!")
```

**后果**: Trigger 无法知道事件已触发，指令不会执行。

**解决方案**:
```gdscript
func _on_event_triggered():
    _log_info_localized("FUSE_LOG_EVENT_TRIGGERED", {"event_type": get_event_type()})
    _emit_triggered(context_node)  # ✅ 发出信号（推荐使用 _emit_triggered 自动设置 trigger meta）
```

---

### 陷阱 7: 在 initialize 中执行耗时操作

**问题**:
```gdscript
func initialize(owner_node: Node):
    # ❌ 初始化中执行耗时操作
    for i in range(10000):
        some_heavy_computation()
```

**后果**: 场景启动卡顿。

**解决方案**:
```gdscript
func initialize(owner_node: Node):
    # ✅ 仅设置监听，不执行耗时操作
    if not owner_node.some_signal.is_connected(_on_callback):
        owner_node.some_signal.connect(_on_callback)
```

---

### 陷阱 8: 未实现必需方法

**问题**:
```gdscript
@tool
extends BaseEvent
class_name MyEvent

# ❌ 忘记实现 _update_resource_name()
# ❌ 忘记实现 initialize()
# ❌ 忘记实现 terminate()
```

**后果**:
- 编译错误（`_update_resource_name()` 是 `@abstract`）
- 运行时错误（`initialize()` 和 `terminate()` 有默认错误实现）

**解决方案**:
```gdscript
@tool
extends BaseEvent
class_name MyEvent

# ✅ 实现所有必需方法
func _update_resource_name():
    resource_name = "My Event"

func initialize(owner_node: Node) -> void:
    # 实现初始化逻辑
    pass

func terminate(owner_node: Node) -> void:
    # 实现清理逻辑
    pass
```

---

## 测试规范

### 测试文件结构

```gdscript
extends Node

## EventName 事件测试

func _ready():
    print("=== Testing EventName ===")
    test_initialization()
    test_triggering()
    test_termination()
    test_edge_cases()
    print("=== All EventName tests passed! ===")
```

### 测试用例设计

**必需的测试**:
1. **初始化测试** - 验证事件正确初始化
2. **触发测试** - 验证事件正确触发
3. **清理测试** - 验证资源正确清理
4. **边界值测试** - 测试极端参数值
5. **错误处理测试** - 验证错误情况被正确处理

**测试示例**:
```gdscript
func test_initialization():
    print("Test 1: Initialization")

    var event = EventName.new()
    var trigger = Node.new()
    add_child(trigger)

    # 初始化事件
    event.initialize(trigger)
    await get_tree().process_frame

    # 验证信号已连接
    assert(trigger.some_signal.is_connected(event._on_callback), "Signal should be connected")
    print("  ✓ Test 1 passed\n")

    # 清理
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

    # 触发事件
    trigger.emit_signal("some_signal")
    await get_tree().process_frame

    # 验证事件触发
    assert(triggered, "Event should be triggered")
    print("  ✓ Test 2 passed\n")

    # 清理
    event.terminate(trigger)
    trigger.queue_free()

func test_termination():
    print("Test 3: Termination")

    var event = EventName.new()
    var trigger = Node.new()
    add_child(trigger)

    event.initialize(trigger)
    event.terminate(trigger)

    # 验证信号已断开
    assert(not trigger.some_signal.is_connected(event._on_callback), "Signal should be disconnected")
    print("  ✓ Test 3 passed\n")

    trigger.queue_free()
```

### 测试断言

```gdscript
# 验证条件
assert(condition, "Error message")

# 验证事件触发
assert(triggered == should_trigger, "Event should trigger")

# 验证信号连接
assert(signal_connected, "Signal should be connected")

# 验证资源清理
assert(timer == null, "Timer should be cleaned up")
```

---

## 快速参考

### 常用代码片段

#### 信号连接
```gdscript
# 初始化时连接
func initialize(owner_node: Node):
    if not owner_node.some_signal.is_connected(_on_callback):
        owner_node.some_signal.connect(_on_callback)

# 清理时断开
func terminate(owner_node: Node):
    if owner_node and owner_node.some_signal.is_connected(_on_callback):
        owner_node.some_signal.disconnect(_on_callback)
```

#### Timer 创建和清理
```gdscript
# 创建
func _start_timer():
    _cleanup_timer()
    _timer = Timer.new()
    _timer.wait_time = delay_seconds
    _timer.one_shot = true
    _timer.timeout.connect(_on_timer_timeout)
    _owner_node.add_child(_timer)
    _timer.start()

# 清理
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

#### 节点获取和验证
```gdscript
# 获取节点
var target_node = owner_node.get_node_or_null(target_path)

# 验证
if not target_node:
    _create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(target_path)})
    return

if not target_node is Area2D:
    _create_fuse_error_localized("FUSE_ERROR_INVALID_TARGET", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(target_path)})
    return
```

#### 事件触发
```gdscript
func _on_event_triggered():
    _log_info_localized("FUSE_LOG_EVENT_TRIGGERED", {"event_type": get_event_type()})

    # 检查是否只触发一次
    if trigger_once and _has_triggered:
        return

    _has_triggered = true
    _emit_triggered(context_node)  # 推荐：自动设置 trigger meta
```

### 常用错误键

已定义的本地化错误键（参考 `translations.csv`）：
- `FUSE_ERROR_TARGET_NODE_NULL` - 目标节点为空
- `FUSE_ERROR_TARGET_NODE_EMPTY` - 目标节点路径为空
- `FUSE_ERROR_TARGET_NODE_NOT_FOUND` - 目标节点未找到
- `FUSE_ERROR_INVALID_TARGET` - 目标节点类型无效
- `FUSE_ERROR_MISSING_PARAMETER` - 缺少必需参数
- `FUSE_ERROR_CONFIGURATION_ERROR` - 配置错误

### 常用日志键

- `FUSE_LOG_EVENT_INITIALIZED` - 事件已初始化
- `FUSE_LOG_EVENT_TERMINATED` - 事件已终止
- `FUSE_LOG_EVENT_TRIGGERED` - 事件已触发
- `FUSE_LOG_EVENT_RESET` - 事件已重置
- `FUSE_LOG_EVENT_DELAY` - 延迟触发
- `FUSE_LOG_EVENT_ALREADY_TRIGGERED` - 事件已触发

---

## 总结

创建 Fuse 事件的关键要点：

1. ✅ **遵循命名规范** - `on_` 前缀，`On` 类前缀
2. ✅ **实现必需方法** - `_update_resource_name()`, `initialize()`, `terminate()`
3. ✅ **正确管理信号** - 在 `terminate()` 中断开所有连接
4. ✅ **清理资源** - Timer、节点引用等必须正确清理
5. ✅ **本地化消息** - 使用 `_log_*_localized()` 和 `_create_fuse_error_localized()`
6. ✅ **添加完整测试** - 初始化、触发、清理、边界情况
7. ✅ **验证配置** - 实现 `validate()` 方法
8. ✅ **提供元数据** - 实现 `_get_event_metadata()` 静态方法

**核心原则**:
- **initialize_with_runtime_instance()** 初始化事件（推荐），连接信号
- **terminate()** 断开信号并清理资源
- 事件触发时使用 `_emit_triggered()` 发出信号（自动设置 trigger meta）
- 事件停止时使用 `notify_stopped()` 通知 Trigger

**参考文档**:
- [BaseEvent API](../../../core/base/base_event.gd)
- [完整事件模板](#完整事件模板)
- [测试规范](#测试规范)

---

**文档维护**: Fuse 开发团队
**最后更新**: 2026-06-17
**版本**: v2.1 - 添加 stopped 信号、性能追踪文档，修复断链
