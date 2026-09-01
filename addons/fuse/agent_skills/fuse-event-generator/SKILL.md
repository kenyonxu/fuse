---
name: fuse-event-generator
description: 专门用于创建 Fuse 可视化编程系统事件（Event）的开发技能。当需要创建新的 Fuse 事件时使用此技能，包括：添加生命周期事件、创建物理碰撞事件、实现输入事件、开发信号监听事件等。提供完整的事件创建工作流、代码模板、最佳实践参考和常见错误避坑指南。
---

# Fuse 事件生成器

专门用于创建 Fuse 可视化编程系统事件（Event）的开发技能。

## 快速开始

创建新事件时，按照以下步骤操作：

1. **确定事件类型和功能**
   - 明确事件要监听的内容（信号、状态、条件）
   - 确定事件的分类（Lifecycle、Physics、Input、Audio、Animation 等）

2. **选择合适的模板**
   - 简单信号事件：参考 [信号事件模板](templates/signal_event_template.gd)
   - 生命周期事件：参考 [生命周期事件模板](templates/lifecycle_event_template.gd)

3. **实现事件代码**
   - 使用模板创建事件文件
   - 实现必需方法：`_update_resource_name()`, `initialize_with_runtime_instance()`, `terminate()`
   - 实现 `get_default_runtime_state()` 声明运行时状态（新版核心）
   - 添加本地化翻译

4. **创建测试**
   - 创建测试场景和脚本
   - 验证信号连接和触发逻辑

5. **验证和调试**
   - 在编辑器中测试事件
   - 检查 Inspector 显示
   - 验证本地化

## 事件类型参考

| 类型 | 说明 | 模板 |
|------|------|------|
| **生命周期** | 节点初始化、帧更新、定时器 | lifecycle_event_template |
| **物理碰撞** | Area/Body 进入/退出 | signal_event_template |
| **输入事件** | 键盘、鼠标、手柄输入 | signal_event_template |
| **动画事件** | 动画开始、结束、标记点 | signal_event_template |
| **音频事件** | 音频开始、结束、总线变化 | signal_event_template |
| **UI 事件** | 按钮点击、值变化 | signal_event_template |
| **信号监听** | 任意节点信号 | signal_event_template |

## 关键开发规范

### 命名规范

- **文件名**：使用 `on_` 前缀 + snake_case
  - ✅ `on_body_entered.gd`, `on_timer.gd`, `on_animation_finished.gd`
  - ❌ `body_entered_event.gd`, `timer_event.gd`

- **类名**：使用 `On` 前缀 + PascalCase
  - ✅ `class_name OnBodyEntered`, `class_name OnTimer`
  - ❌ `class_name BodyEnteredEvent`

### 必需实现的方法

所有事件必须实现以下方法：

```gdscript
## 更新资源名称（必需）
func _update_resource_name():
    # 构建描述性资源名称
    pass

## 使用运行时实例初始化事件（推荐，替代旧 initialize()）
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
    if Engine.is_editor_hint():
        return
    _runtime_instance_ref = runtime_instance
    # 验证 owner_node、连接信号

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
    # 断开信号、清理资源
    pass

## 声明事件提供的 LOCAL 变量（必需，若事件触发时自动设 local 变量）
## 供静态分析（analyze_problems）白名单，避免指令读这些变量时误报"未声明"
## 如 OnInputActionComposite 提供 input_vector / last_input_vector
func get_provided_local_variables() -> Array[String]:
    # 示例：事件触发时自动设的 local 变量名
    return ["input_vector", "last_input_vector"]
```

### 运行时状态模式（RuntimeEventInstance）

**新版核心：自声明状态模式**。Event 通过 `get_default_runtime_state()` 声明状态：

```gdscript
## 获取默认运行时状态（新版核心方法）
func get_default_runtime_state() -> Dictionary:
    var base = super.get_default_runtime_state()
    base["is_hovered"] = false
    base["trigger_count"] = 0
    return base
```

**状态访问**（通过 RuntimeEventInstance）：
```gdscript
# 读取状态
var is_hovered = _runtime_instance_ref.get_runtime_state("is_hovered", false)

# 检查状态是否存在
if _runtime_instance_ref.has_runtime_state("key"):
    pass

# 写入状态
_runtime_instance_ref.set_runtime_state("is_hovered", true)
```

**何时使用 RuntimeInstance**：
- ✅ Event 有运行时状态（`_is_hovered`, `_has_triggered` 等）
- ✅ 多个 Trigger 可能共享同一个 Event 资源
- ⚠️ Event 是无状态纯监听 → 可继续使用旧 `initialize()`

### 生命周期模式

事件的核心生命周期：

```
initialize_with_runtime_instance() → 监听状态 → 触发事件 → terminate()
```

**initialize_with_runtime_instance()** - 初始化阶段：
- 验证参数和节点
- 保存 `_runtime_instance_ref`
- 连接信号
- 创建定时器
- 记录日志

**terminate()** - 清理阶段：
- 断开所有信号连接
- 清理定时器和资源
- 清理 RuntimeEventInstance 状态
- 重置引用

**触发** - 运行阶段：
- 检查触发条件（通过 RuntimeEventInstance 状态）
- 过滤不必要的触发
- 使用 `_emit_triggered()` 发出信号（自动设置 trigger meta）
- 传递上下文数据

### 信号连接模式

**简单信号连接**：
```gdscript
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
    if Engine.is_editor_hint():
        return
    _runtime_instance_ref = runtime_instance

    if not owner_node:
        _create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
        return

    _target_node = owner_node.get_node_or_null(target_node_path)

    if not _target_node:
        _create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(target_node_path)})
        return

    if not _target_node.signal_name.is_connected(_on_signal):
        _target_node.signal_name.connect(_on_signal)
```

**清理信号连接**：
```gdscript
func terminate(owner_node: Node) -> void:
    if _target_node and is_instance_valid(_target_node):
        if _target_node.signal_name.is_connected(_on_signal):
            _target_node.signal_name.disconnect(_on_signal)

    # 清理 RuntimeEventInstance 状态
    if _runtime_instance_ref:
        _runtime_instance_ref.set_runtime_state("has_triggered", false)

    _target_node = null
    _runtime_instance_ref = null
```

### 事件触发方式

**推荐使用 `_emit_triggered()`**（自动设置 trigger meta）：

```gdscript
# ✅ 推荐：自动设置 "trigger" meta，防止信号广播到其他 RuntimeEventInstance
_emit_triggered(context_node)
_emit_triggered(context_node, owner_node)  # 指定 trigger_node

# ❌ 旧方式：直接 emit，可能缺少 trigger meta
triggered.emit(some_node)
```

### stopped 信号

当事件需要主动停止时（如 `OnInterval` 达到最大重复次数），使用 `notify_stopped()`：

```gdscript
# 停止原因常量
STOP_REASON_CONDITION_MET  # 条件满足而停止
STOP_REASON_MAX_REPEATS    # 达到最大重复次数
STOP_REASON_MANUAL         # 手动停止
STOP_REASON_ERROR          # 因错误而停止

# 通知停止
func _on_event_triggered():
    if max_repeats > 0 and repeat_count >= max_repeats:
        notify_stopped(STOP_REASON_MAX_REPEATS, {"repeat_count": repeat_count})
        return
```

### 性能追踪

```gdscript
func _on_event_triggered():
    _start_performance_track("trigger")
    # ... 事件处理逻辑 ...
    _stop_performance_track("trigger")
    _emit_triggered(context_node)
```

## 常见错误参考

| 错误 | 正确做法 |
|------|----------|
| 忘记断开信号 | 在 `terminate()` 中断开所有信号 |
| 使用 `get_node()` | 使用 `owner_node.get_node_or_null()` |
| 信号连接检查缺失 | 连接前检查 `is_connected()` |
| 定时器未清理 | 在 `terminate()` 中 stop() 并 queue_free() |
| 运行时状态用成员变量 | 使用 RuntimeEventInstance + `get_default_runtime_state()` |
| 直接 `triggered.emit()` | 使用 `_emit_triggered()` |
| 没有停止通知 | 使用 `notify_stopped()` 通知 Trigger |

## 参考资料详解

### 详细开发指南
- [完整事件创建指南](references/event_creation_guide.md) - 详细的开发步骤、最佳实践、常见陷阱

### 模板文件
- [信号事件模板](templates/signal_event_template.gd) - 简单信号事件的完整模板（含 RuntimeInstance）
- [生命周期事件模板](templates/lifecycle_event_template.gd) - 带定时器的生命周期事件模板（含 RuntimeInstance）

## 工作流程

### 1. 规划事件
- 确定要监听的信号或条件
- 选择合适的事件分类
- 确定是否需要"仅触发一次"选项
- 确定需要传递的上下文数据
- 确定是否需要 RuntimeInstance（有状态 = 需要）

### 2. 创建代码
- 从模板开始
- 实现 `get_default_runtime_state()` 声明状态
- 实现 `initialize_with_runtime_instance()`
- 实现 `terminate()` 清理
- 添加参数验证

### 3. 添加本地化
- 在 `addons/fuse/localization/translations.csv` 添加键值对
- 使用 `_log_*_localized()` 记录日志
- 使用 `_create_fuse_error_localized()` 创建错误
- 翻译键前缀：`FUSE_EVENT_*`, `FUSE_ERROR_*`, `FUSE_LOG_EVENT_*`

### 4. 创建测试
- 创建测试场景
- 编写测试脚本
- 测试触发和清理逻辑
- 测试多 Trigger 共享 Event 场景（RuntimeInstance）

### 5. 验证和调试
- 在编辑器中检查 Inspector 显示
- 运行测试场景
- 验证信号连接和断开
- 检查资源清理

## 提示和技巧

- **触发一次模式**：通过 RuntimeEventInstance 状态而非成员变量
  ```gdscript
  func get_default_runtime_state() -> Dictionary:
      var base = super.get_default_runtime_state()
      base["has_triggered"] = false
      return base

  func _on_signal():
      var has_triggered = _runtime_instance_ref.get_runtime_state("has_triggered", false)
      if trigger_once and has_triggered:
          return
      _runtime_instance_ref.set_runtime_state("has_triggered", true)
      _emit_triggered(context_node)
  ```

- **上下文传递**：通过 `_emit_triggered()` 传递有用数据
  ```gdscript
  _emit_triggered(body)       # context = 碰撞的物体
  _emit_triggered(node)       # context = 目标节点
  ```

- **编辑器友好**：使用 `@tool` 和 `@export` 属性
  ```gdscript
  @export var target_node_path: NodePath = NodePath(""):
      set(value):
          target_node_path = value
          _update_resource_name()
  ```

- **日志记录**：使用本地化日志
  ```gdscript
  _log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})
  _log_info_localized("FUSE_LOG_EVENT_TRIGGERED", {"event": name})
  ```

## 验证清单

创建事件后，确认以下各项：

- [ ] 文件命名符合规范（`on_` 前缀）
- [ ] 类命名符合规范（`On` 前缀）
- [ ] 实现了 `_update_resource_name()`, `initialize_with_runtime_instance()`, `terminate()`
- [ ] 实现了 `get_default_runtime_state()` 声明运行时状态
- [ ] 有状态的事件使用 RuntimeEventInstance 而非成员变量
- [ ] 使用 `_emit_triggered()` 而非 `triggered.emit()`
- [ ] 正确连接和断开信号
- [ ] 添加了本地化翻译（`FUSE_*` 前缀）
- [ ] 错误使用 `_create_fuse_error_localized()`
- [ ] 创建了测试场景和脚本
- [ ] 测试通过（含多 Trigger 共享场景）
- [ ] 在编辑器中验证 Inspector 显示
- [ ] 配置了图标
- [ ] 资源正确清理（无内存泄漏）
- [ ] 支持"仅触发一次"（如果适用）

## 获取帮助

- 查看完整指南：[references/event_creation_guide.md](references/event_creation_guide.md)
- 使用模板快速开始：[templates/](templates/)
