# Event State Separation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 将 Event 资源中的运行时状态变量迁移到 RuntimeEventInstance，实现数据与逻辑的完全分离，解决多个 Trigger 共享 Event 资源时的状态冲突问题。

**Architecture:** 采用"数据与逻辑分离"架构模式：
- **Event (Resource)** = 纯配置数据（@export 变量），不包含任何运行时状态
- **RuntimeEventInstance (RefCounted)** = 运行时逻辑 + 状态，每个 Trigger 有独立实例

这种架构完全隔离了配置和状态，多个 Trigger 可以共享同一个 Event 配置资源，而每个 Trigger 都有独立的运行时状态。

**Tech Stack:**
- Godot 4.6
- GDScript 2.0
- RefCounted（轻量级运行时实例）
- Resource（配置资源）

---

## Phase 1: 扩展 RuntimeEventInstance 状态管理

### Task 1: 在 RuntimeEventInstance 中添加状态存储接口

**Files:**
- Modify: `addons/bricks/core/runtime_event_instance.gd:14-17`

**Step 1: 添加状态存储字典的访问方法**

在 `runtime_state` 字典定义后添加状态访问方法：

```gdscript
## 属性
var event_definition: BaseEvent
var runtime_state: Dictionary = {}
var owner_trigger: Node
var log_level: BricksLogger.LogLevel = BricksLogger.LogLevel.INFO

## 🔧 状态管理方法：获取状态值
##
## 参数：
## - key: String - 状态键
## - default_value: Variant = null - 默认值
##
## 返回：
## - Variant - 状态值，如果不存在则返回默认值
func get_state(key: String, default_value = null):
    if runtime_state.has(key):
        return runtime_state[key]
    return default_value

## 🔧 状态管理方法：设置状态值
##
## 参数：
## - key: String - 状态键
## - value: Variant - 状态值
func set_state(key: String, value):
    runtime_state[key] = value

## 🔧 状态管理方法：检查状态是否存在
##
## 参数：
## - key: String - 状态键
##
## 返回：
## - bool - 状态是否存在
func has_state(key: String) -> bool:
    return runtime_state.has(key)
```

**Step 2: 运行测试确保没有语法错误**

Run: 打开 Godot 编辑器，检查 `runtime_event_instance.gd` 是否有语法错误
Expected: 无语法错误，脚本可以正常加载

**Step 3: 提交**

```bash
git add addons/bricks/core/runtime_event_instance.gd
git commit -m "feat(runtime-event): 添加状态管理方法 get/set/has_state"
```

---

### Task 2: 为鼠标事件添加特定的状态初始化

**Files:**
- Modify: `addons/bricks/core/runtime_event_instance.gd:37-67`

**Step 1: 扩展 _initialize_runtime_state() 方法**

在现有的 OnInterval 初始化逻辑后，添加鼠标事件的状态初始化：

```gdscript
func _initialize_runtime_state():
    if not event_definition:
        _log_warning("没有事件定义，无法初始化运行时状态")
        return

    # 根据事件类型初始化特定的运行时状态
    match event_definition.get_event_type():
        "mouse_enter":
            runtime_state["is_hovered"] = false
            runtime_state["initialized"] = true
            runtime_state["trigger_count"] = 0
            runtime_state["last_trigger_time"] = 0.0
            _log_debug("鼠标进入事件状态已初始化")

        "mouse_exit":
            runtime_state["has_exited"] = false
            runtime_state["initialized"] = true
            runtime_state["trigger_count"] = 0
            runtime_state["last_trigger_time"] = 0.0
            _log_debug("鼠标离开事件状态已初始化")

        "interval":
            runtime_state["is_running"] = false
            runtime_state["elapsed_time"] = 0.0
            runtime_state["repeat_count"] = 0
            runtime_state["initialized"] = true
            _log_debug("间隔执行事件状态已初始化")

        _:
            # 默认状态
            runtime_state["initialized"] = true
            runtime_state["trigger_count"] = 0
            runtime_state["last_trigger_time"] = 0.0

    _log_debug("运行时状态已初始化，事件类型: %s" % event_definition.get_event_type())
```

**Step 2: 运行测试**

Run: 在 Godot 编辑器中打开测试场景 `demos/bricks/brick_ui_demo.tscn`
Expected: 场景正常加载，无报错

**Step 3: 提交**

```bash
git add addons/bricks/core/runtime_event_instance.gd
git commit -m "feat(runtime-event): 为 mouse_enter/exit 事件添加状态初始化"
```

---

## Phase 2: 修改 OnMouseEnter 使用 RuntimeEventInstance 状态

### Task 3: 修改 OnMouseEnter 移除状态变量

**Files:**
- Modify: `addons/bricks/events/input/on_mouse_enter.gd:22-23`
- Modify: `addons/bricks/events/input/on_mouse_enter.gd:186-190`

**Step 1: 删除共享的状态变量**

找到并删除以下行：

```gdscript
var _is_hovered: bool = false
var _owner_node_ref: Node = null
```

替换为：

```gdscript
# 🔧 运行时状态现在存储在 RuntimeEventInstance 中，不再在 Event 资源中存储状态
# 每个 Trigger 通过 runtime_instance 访问独立的状态
var _runtime_instance_ref: RuntimeEventInstance = null
```

**Step 2: 修改 initialize() 方法保存 RuntimeEventInstance 引用**

在 `initialize()` 方法开头添加：

```gdscript
func initialize(owner_node: Node) -> void:
    # 🔧 保存 owner_node 引用（临时方案，后续将通过 RuntimeEventInstance 访问）
    _owner_node_ref = owner_node

    # 验证 owner_node
    if not owner_node:
        _create_bricks_error_localized("BRICKS_ERROR_TARGET_NODE_NULL", BricksError.ErrorType.CONFIGURATION_ERROR, {})
        return

    # ... 其余代码保持不变 ...
```

**Step 3: 添加新的初始化方法用于接收 RuntimeEventInstance**

在 `terminate()` 方法后添加：

```gdscript
## 🔧 使用 RuntimeEventInstance 初始化事件
##
## 这是推荐的方法，通过 RuntimeEventInstance 管理运行时状态
##
## 参数：
## - owner_node: Node - 拥有此事件的 Trigger 节点
## - runtime_instance: RuntimeEventInstance - 运行时事件实例
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
    if Engine.is_editor_hint():
        _log_debug("编辑器模式下，跳过事件初始化")
        return

    # 保存 RuntimeEventInstance 引用
    _runtime_instance_ref = runtime_instance
    _owner_node_ref = owner_node

    # 验证 owner_node
    if not owner_node:
        _create_bricks_error_localized("BRICKS_ERROR_TARGET_NODE_NULL", BricksError.ErrorType.CONFIGURATION_ERROR, {})
        return

    # 验证目标节点路径
    if target_node_path.is_empty():
        _create_bricks_error_localized("BRICKS_ERROR_TARGET_NODE_EMPTY", BricksError.ErrorType.CONFIGURATION_ERROR, {})
        return

    # 🔧 动态解析目标节点
    var target_node = _get_target_node()
    if not target_node:
        _create_bricks_error_localized("BRICKS_ERROR_TARGET_NODE_NOT_FOUND", BricksError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(target_node_path)})
        return

    # 验证节点类型
    if not _is_valid_target_type(target_node):
        _create_bricks_error_localized("BRICKS_ERROR_INVALID_TARGET", BricksError.ErrorType.CONFIGURATION_ERROR, {
            "node_path": str(target_node_path),
            "expected_types": "Control, CollisionObject2D, 或 CollisionObject3D"
        })
        return

    # 根据节点类型连接相应的信号
    _connect_hover_signals(target_node, owner_node)

    _log_debug_localized("BRICKS_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})
```

**Step 4: 修改 _on_mouse_entered_with_context() 使用 RuntimeEventInstance 状态**

将状态检查和修改改为使用 RuntimeEventInstance：

```gdscript
func _on_mouse_entered_with_context(owner: Node):
    # 验证 owner 是否有效
    if not owner or not is_instance_valid(owner):
        return

    # 使用传入的 owner 参数获取目标节点
    var target_node = owner.get_node_or_null(target_node_path)
    if not target_node:
        _log_error("无法获取目标节点")
        return

    # 🔧 使用 RuntimeEventInstance 的状态（如果可用）
    var is_hovered: bool = false
    if _runtime_instance_ref and _runtime_instance_ref.has_state("is_hovered"):
        is_hovered = _runtime_instance_ref.get_state("is_hovered")
    else:
        # 回退：使用 Event 资源的状态（向后兼容）
        is_hovered = _is_hovered if hasattr(self, "_is_hovered") else false

    # 检查是否只触发一次
    if trigger_once_per_enter and is_hovered:
        _log_debug_localized("BRICKS_LOG_EVENT_ALREADY_ENTERED", {})
        return

    # 🔧 更新 RuntimeEventInstance 的状态
    if _runtime_instance_ref:
        _runtime_instance_ref.set_state("is_hovered", true)

    var node_name = target_node.name if target_node else "Unknown"
    _log_info_localized("BRICKS_LOG_EVENT_MOUSE_ENTER_TRIGGERED", {"node": node_name})

    # 创建上下文节点传递事件信息
    var context_node = Node.new()
    context_node.name = "MouseEnterContext"
    context_node.set_meta("trigger", owner)
    context_node.set_meta("target_node", target_node)
    context_node.set_meta("node_path", str(target_node_path))

    triggered.emit(context_node)
    context_node.queue_free()
```

**Step 5: 修改 terminate() 清理 RuntimeEventInstance 状态**

```gdscript
func terminate(owner_node: Node) -> void:
    # 🔧 根据 owner_node 找到并断开对应的信号连接
    var owner_id = owner_node.get_instance_id()

    if _signal_connections.has(owner_id):
        var conn_info = _signal_connections[owner_id]
        var target_node = conn_info["target"]
        var callback = conn_info["callback"]

        if target_node and is_instance_valid(target_node):
            # 断开信号
            if target_node is Control:
                var control = target_node as Control
                if control.mouse_entered.is_connected(callback):
                    control.mouse_entered.disconnect(callback)
            elif target_node is CollisionObject2D:
                if target_node.mouse_entered.is_connected(callback):
                    target_node.mouse_entered.disconnect(callback)
            elif target_node is CollisionObject3D:
                var collision = target_node as CollisionObject3D
                if collision.mouse_entered.is_connected(callback):
                    collision.mouse_entered.disconnect(callback)

        # 清理注册表
        _signal_connections.erase(owner_id)

    # 🔧 清理 RuntimeEventInstance 的状态
    if _runtime_instance_ref:
        _runtime_instance_ref.set_state("is_hovered", false)

    # 清理引用
    _owner_node_ref = null
    _runtime_instance_ref = null

    _log_debug_localized("BRICKS_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})
```

**Step 6: 运行测试**

Run: 在 Godot 编辑器中运行 `demos/bricks/brick_ui_demo.tscn`
Expected:
1. 场景正常加载
2. 鼠标悬停在 start 按钮上，只有 start 放大
3. 鼠标悬停在 continue 按钮上，只有 continue 放大
4. 查看日志，确认使用的是 RuntimeEventInstance 状态

**Step 7: 提交**

```bash
git add addons/bricks/events/input/on_mouse_enter.gd
git commit -m "refactor(mouse-enter): 使用 RuntimeEventInstance 管理状态，实现完全隔离"
```

---

## Phase 3: 修改 OnMouseExit 使用 RuntimeEventInstance 状态

### Task 4: 修改 OnMouseExit 移除状态变量

**Files:**
- Modify: `addons/bricks/events/input/on_mouse_exit.gd:22-23`
- Modify: `addons/bricks/events/input/on_mouse_exit.gd:183-187`

**Step 1: 删除共享的状态变量**

找到并删除以下行：

```gdscript
var _has_exited: bool = false
var _owner_node_ref: Node = null
```

替换为：

```gdscript
# 🔧 运行时状态现在存储在 RuntimeEventInstance 中
var _runtime_instance_ref: RuntimeEventInstance = null
```

**Step 2: 添加 initialize_with_runtime_instance() 方法**

参考 OnMouseEnter 的实现，添加相同的方法，将 "mouse_enter" 相关的逻辑改为 "mouse_exit"：

```gdscript
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
    if Engine.is_editor_hint():
        _log_debug("编辑器模式下，跳过事件初始化")
        return

    # 保存 RuntimeEventInstance 引用
    _runtime_instance_ref = runtime_instance
    _owner_node_ref = owner_node

    # 验证 owner_node
    if not owner_node:
        _create_bricks_error_localized("BRICKS_ERROR_TARGET_NODE_NULL", BricksError.ErrorType.CONFIGURATION_ERROR, {})
        return

    # 验证目标节点路径
    if target_node_path.is_empty():
        _create_bricks_error_localized("BRICKS_ERROR_TARGET_NODE_EMPTY", BricksError.ErrorType.CONFIGURATION_ERROR, {})
        return

    # 🔧 动态解析目标节点
    var target_node = _get_target_node()
    if not target_node:
        _create_bricks_error_localized("BRICKS_ERROR_TARGET_NODE_NOT_FOUND", BricksError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(target_node_path)})
        return

    # 验证节点类型
    if not _is_valid_target_type(target_node):
        _create_bricks_error_localized("BRICKS_ERROR_INVALID_TARGET", BricksError.ErrorType.CONFIGURATION_ERROR, {
            "node_path": str(target_node_path),
            "expected_types": "Control, CollisionObject2D, 或 CollisionObject3D"
        })
        return

    # 根据节点类型连接相应的信号
    _connect_hover_signals(target_node, owner_node)

    _log_debug_localized("BRICKS_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})
```

**Step 3: 修改 _on_mouse_exited_with_context() 使用 RuntimeEventInstance 状态**

```gdscript
func _on_mouse_exited_with_context(owner: Node):
    # 验证 owner 是否有效
    if not owner or not is_instance_valid(owner):
        return

    # 使用传入的 owner 参数获取目标节点
    var target_node = owner.get_node_or_null(target_node_path)
    if not target_node:
        _log_error("无法获取目标节点")
        return

    # 🔧 使用 RuntimeEventInstance 的状态（如果可用）
    var has_exited: bool = false
    if _runtime_instance_ref and _runtime_instance_ref.has_state("has_exited"):
        has_exited = _runtime_instance_ref.get_state("has_exited")
    else:
        # 回退：使用 Event 资源的状态（向后兼容）
        has_exited = _has_exited if hasattr(self, "_has_exited") else false

    # 检查是否只触发一次
    if trigger_once_per_exit and has_exited:
        _log_debug_localized("BRICKS_LOG_EVENT_ALREADY_EXITED", {})
        return

    # 🔧 更新 RuntimeEventInstance 的状态
    if _runtime_instance_ref:
        _runtime_instance_ref.set_state("has_exited", true)

    var node_name = target_node.name if target_node else "Unknown"
    _log_info_localized("BRICKS_LOG_EVENT_MOUSE_EXIT_TRIGGERED", {"node": node_name})

    # 创建上下文节点传递事件信息
    var context_node = Node.new()
    context_node.name = "MouseExitContext"
    context_node.set_meta("trigger", owner)
    context_node.set_meta("target_node", target_node)
    context_node.set_meta("node_path", str(target_node_path))

    triggered.emit(context_node)
    context_node.queue_free()
```

**Step 4: 修改 terminate() 清理 RuntimeEventInstance 状态**

```gdscript
func terminate(owner_node: Node) -> void:
    # 🔧 根据 owner_node 找到并断开对应的信号连接
    var owner_id = owner_node.get_instance_id()

    if _signal_connections.has(owner_id):
        var conn_info = _signal_connections[owner_id]
        var target_node = conn_info["target"]
        var callback = conn_info["callback"]

        if target_node and is_instance_valid(target_node):
            # 断开信号
            if target_node is Control:
                var control = target_node as Control
                if control.mouse_exited.is_connected(callback):
                    control.mouse_exited.disconnect(callback)
            elif target_node is CollisionObject2D:
                if target_node.mouse_exited.is_connected(callback):
                    target_node.mouse_exited.disconnect(callback)
            elif target_node is CollisionObject3D:
                var collision = target_node as CollisionObject3D
                if collision.mouse_exited.is_connected(callback):
                    collision.mouse_exited.disconnect(callback)

        # 清理注册表
        _signal_connections.erase(owner_id)

    # 🔧 清理 RuntimeEventInstance 的状态
    if _runtime_instance_ref:
        _runtime_instance_ref.set_state("has_exited", false)

    # 清理引用
    _owner_node_ref = null
    _runtime_instance_ref = null

    _log_debug_localized("BRICKS_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})
```

**Step 5: 运行测试**

Run: 在 Godot 编辑器中运行 `demos/bricks/brick_ui_demo.tscn`
Expected:
1. 场景正常加载
2. 鼠标进入 start 按钮后离开，start 缩回到正常大小
3. 鼠标进入 continue 按钮后离开，continue 缩回到正常大小
4. 两个按钮的行为完全独立，互不影响

**Step 6: 提交**

```bash
git add addons/bricks/events/input/on_mouse_exit.gd
git commit -m "refactor(mouse-exit): 使用 RuntimeEventInstance 管理状态，实现完全隔离"
```

---

## Phase 4: 更新 BaseEvent 支持新的初始化模式

### Task 5: 在 BaseEvent 中添加 RuntimeEventInstance 引用

**Files:**
- Modify: `addons/bricks/core/base/base_event.gd:27-29`

**Step 1: 添加 RuntimeEventInstance 引用变量**

在 `_trigger_ref` 变量后添加：

```gdscript
## 事件状态
var _bricks_error: BricksError = null
var _trigger_ref: Node = null
## 🔧 运行时实例引用（可选），用于访问运行时状态
var _runtime_instance_ref: RuntimeEventInstance = null
```

**Step 2: 修改 initialize_with_runtime_instance() 保存引用**

```gdscript
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
    if Engine.is_editor_hint():
        _log_debug("编辑器模式下，跳过事件初始化")
        return

    # 🔧 保存 RuntimeEventInstance 引用，子类可以通过它访问运行时状态
    _runtime_instance_ref = runtime_instance

    # 先设置 Trigger 引用，这样子类的 initialize() 就能使用它
    set_trigger_ref(owner_node)

    # 默认实现调用原有的 initialize 方法，保持向后兼容
    initialize(owner_node)

    # 子类可以重写此方法来处理特定的运行时状态
    _initialize_runtime_state(runtime_instance)
```

**Step 3: 添加辅助方法 get_runtime_instance()**

在 `set_trigger_ref()` 方法后添加：

```gdscript
## 🔧 获取 RuntimeEventInstance 引用
##
## 返回：
## - RuntimeEventInstance - 运行时实例，如果未设置则返回 null
func get_runtime_instance() -> RuntimeEventInstance:
    return _runtime_instance_ref
```

**Step 4: 修改 terminate() 清理 RuntimeEventInstance 引用**

在 `reset()` 方法中添加清理：

```gdscript
func reset() -> void:
    _bricks_error = null
    _runtime_instance_ref = null  # 🔧 清理运行时实例引用
```

**Step 5: 运行测试**

Run: 在 Godot 编辑器中打开项目，检查是否有语法错误
Expected: 无语法错误

**Step 6: 提交**

```bash
git add addons/bricks/core/base/base_event.gd
git commit -m "feat(base-event): 添加 RuntimeEventInstance 引用支持"
```

---

## Phase 5: 更新 Trigger 使用新的初始化模式

### Task 6: 修改 Trigger 确保使用 initialize_with_runtime_instance()

**Files:**
- Modify: `addons/bricks/core/trigger.gd:46-55`
- Modify: `addons/bricks/events/input/on_mouse_enter.gd:42-68`
- Modify: `addons/bricks/events/input/on_mouse_exit.gd:42-68`

**Step 1: 确认 Trigger 已正确调用 initialize_with_runtime_instance()**

检查 `trigger.gd` 的 `_ready()` 方法，确认第 54 行调用了 `initialize_with_runtime_instance()`。

如果已经调用，跳过此步骤。

如果未调用，添加：

```gdscript
# 在第 51 行后
# 将运行时实例传递给事件定义，让事件定义可以访问运行时状态
event_definition.initialize_with_runtime_instance(self, _runtime_event_instance)
```

**Step 2: 确保子类的 initialize() 方法与 initialize_with_runtime_instance() 兼容**

在 `on_mouse_enter.gd` 和 `on_mouse_exit.gd` 中，确保：
1. `initialize()` 方法保持不变（向后兼容）
2. `initialize_with_runtime_instance()` 方法实现新的状态管理逻辑

检查 `on_mouse_enter.gd` 第 42-68 行，确保 `initialize()` 方法中没有直接使用 `_is_hovered` 等已删除的变量。

**Step 3: 运行完整的回归测试**

Run: 在 Godot 编辑器中运行以下测试场景
- `demos/bricks/brick_ui_demo.tscn` - 鼠标悬停测试
- `demos/bricks/brick_demo_basic.tscn` - 基本 Brick 功能测试

Expected:
1. 所有场景正常加载
2. 鼠标悬停功能正常工作
3. 两个按钮完全独立，互不干扰
4. 日志显示使用 RuntimeEventInstance 管理状态

**Step 4: 提交**

```bash
git add addons/bricks/core/trigger.gd
git commit -m "refactor(trigger): 确保使用 initialize_with_runtime_instance() 初始化事件"
```

---

## Phase 6: 清理和文档

### Task 7: 移除 Callable Wrapper 相关代码（可选）

**Files:**
- Modify: `addons/bricks/events/input/on_mouse_enter.gd:25-28, 104-132, 162-169`
- Modify: `addons/bricks/events/input/on_mouse_exit.gd:25-28, 104-132, 162-166`

**注意：** 这个任务可选，因为 Callable Wrapper 代码不会影响功能，只是增加了复杂度。如果希望保持代码简洁，可以移除。

**Step 1: 评估是否需要移除 Callable Wrapper**

现在状态已经完全存储在 RuntimeEventInstance 中，Callable Wrapper 的主要作用（传递正确的 owner）仍然需要。但如果 `_owner_node_ref` 不再被使用，可以简化代码。

**Step 2: 如果决定移除，删除 _signal_connections 相关代码**

删除以下内容：
1. `_signal_connections` 字典
2. `_connect_hover_signals()` 中的回调包装逻辑
3. `terminate()` 中的 `_signal_connections` 清理逻辑

保留：
1. `_on_mouse_entered_with_context(owner)` 方法（仍然需要正确的 owner）

**Step 3: 运行测试**

Run: 完整的回归测试
Expected: 所有功能正常

**Step 4: 提交（如果执行了此任务）**

```bash
git add addons/bricks/events/input/on_mouse_enter.gd addons/bricks/events/input/on_mouse_exit.gd
git commit -m "refactor(mouse-events): 移除 Callable Wrapper 代码，简化实现"
```

---

### Task 8: 更新文档

**Files:**
- Create: `addons/bricks/docs/architecture/runtime-instance-pattern.md`
- Update: `addons/bricks/docs/event-resource-sharing-solution.md`

**Step 1: 创建架构文档**

创建 `addons/bricks/docs/architecture/runtime-instance-pattern.md`：

```markdown
# RuntimeInstance 架构模式

## 概述

Bricks 系统采用"RuntimeInstance 模式"来实现资源共享与状态隔离的平衡。

## 问题背景

在 Godot 中，Resource 类型（如 Event、ActionRunner）作为 SubResource 被多个节点共享时，如果 Resource 包含运行时状态（如 `_is_hovered`、`_has_exited`），会导致状态污染问题。

## 解决方案

### 设计原则

1. **Resource = 纯配置**
   - 只包含 `@export` 配置变量
   - 不包含运行时状态
   - 可安全地被多个节点共享

2. **RuntimeInstance = 运行时逻辑 + 状态**
   - 继承自 `RefCounted`（轻量级）
   - 包含所有运行时状态
   - 每个 Trigger 有独立实例

### 架构组件

#### RuntimeEventInstance

```gdscript
class_name RuntimeEventInstance extends RefCounted

var event_definition: BaseEvent      # 配置（共享）
var runtime_state: Dictionary = {}    # 状态（独立）
var owner_trigger: Node              # 拥有者

# 状态管理方法
func get_state(key: String, default_value = null)
func set_state(key: String, value)
func has_state(key: String) -> bool
```

#### RuntimeActionRunnerInstance

```gdscript
class_name RuntimeActionRunnerInstance extends RefCounted

var action_runner: ActionRunner        # 配置（共享）
var runtime_state: Dictionary = {}     # 状态（独立）
var owner_trigger: Node               # 拥有者
```

## 使用方式

### Event 实现

```gdscript
class_name OnMouseEnter extends BaseEvent

# ❌ 不要在 Event 中定义状态
# var _is_hovered: bool = false

# ✅ 只定义配置
@export var target_node_path: NodePath = NodePath("")
@export var trigger_once_per_enter: bool = true

var _runtime_instance_ref: RuntimeEventInstance = null

func initialize_with_runtime_instance(owner: Node, runtime_instance: RuntimeEventInstance):
    _runtime_instance_ref = runtime_instance
    # ... 初始化逻辑 ...

func _on_mouse_entered():
    # ✅ 使用 RuntimeEventInstance 的状态
    var is_hovered = _runtime_instance_ref.get_state("is_hovered", false)

    if trigger_once_per_enter and is_hovered:
        return

    # ✅ 更新状态
    _runtime_instance_ref.set_state("is_hovered", true)
```

### Trigger 使用

```gdscript
func _ready():
    # 创建 RuntimeEventInstance
    _runtime_event_instance = RuntimeEventInstance.new(event_definition, self)

    # 初始化 Event（传入 RuntimeEventInstance）
    event_definition.initialize_with_runtime_instance(self, _runtime_event_instance)

    # 连接 RuntimeEventInstance 的信号
    _runtime_event_instance.triggered.connect(_on_event_fired)
```

## 优势

1. **完全隔离**：每个 Trigger 有独立的状态
2. **资源共享**：配置资源仍可共享，节省内存
3. **向后兼容**：旧的 `initialize()` 方法仍然可用
4. **轻量级**：RefCounted 对象，内存开销小
5. **扩展性**：易于添加新的状态类型

## 迁移指南

### 旧代码（状态共享问题）

```gdscript
class OnMouseEnter extends BaseEvent
    var _is_hovered: bool = false  # ❌ 共享状态
```

### 新代码（状态隔离）

```gdscript
class OnMouseEnter extends BaseEvent
    var _runtime_instance_ref: RuntimeEventInstance = null

    func _on_mouse_entered():
        var is_hovered = _runtime_instance_ref.get_state("is_hovered", false)  # ✅ 独立状态
```

## 相关文档

- [Event 资源共享问题解决方案](../event-resource-sharing-solution.md)
- [BaseEvent API Reference](../api/base-event.md)
- [RuntimeEventInstance API Reference](../api/runtime-event-instance.md)
```

**Step 2: 更新现有文档**

在 `event-resource-sharing-solution.md` 的"总结"部分添加：

```markdown
## 最终实施方案

经过评估，我们采用了**方案 B（数据与逻辑分离）**作为最终解决方案：

- ✅ 架构清晰：Event = 纯配置，RuntimeEventInstance = 运行时逻辑 + 状态
- ✅ 完全隔离：每个 Trigger 有独立的状态
- ✅ 保持复用：配置资源仍可共享
- ✅ 向后兼容：旧代码仍可工作

**实施日期**: 2025-02-02
**相关文档**: [RuntimeInstance 架构模式](architecture/runtime-instance-pattern.md)
```

**Step 3: 提交**

```bash
git add addons/bricks/docs/
git commit -m "docs(runtime-instance): 添加 RuntimeInstance 架构模式文档"
```

---

## Phase 7: 最终验证和发布

### Task 9: 完整的回归测试

**Files:**
- Test: `demos/bricks/brick_ui_demo.tscn`
- Test: `demos/bricks/brick_demo_basic.tscn`
- Test: 所有使用鼠标事件的测试场景

**Step 1: 运行所有测试场景**

在 Godot 编辑器中依次运行：
1. `demos/bricks/brick_ui_demo.tscn` - 验证鼠标悬停功能
2. `demos/bricks/brick_demo_basic.tscn` - 验证基本功能
3. 其他包含鼠标事件的测试场景

**Step 2: 验证状态隔离**

测试场景：
1. 鼠标进入 start 按钮并离开
2. 鼠标进入 continue 按钮并离开
3. 重复多次，确保两个按钮的行为完全独立

**Step 3: 检查日志**

查看 Godot 输出日志，确认：
- 使用 RuntimeEventInstance 管理状态
- 没有状态污染的警告
- 每个按钮的事件触发次数正确

**Step 4: 性能测试（可选）**

使用 Godot 的性能分析器检查：
- 内存使用是否正常
- RuntimeEventInstance 的创建和销毁是否正常
- 没有内存泄漏

**Step 5: 创建发布标签**

```bash
git tag -a v0.9.0-event-state-separation -m "实现 Event 状态分离架构"
git push origin v0.9.0-event-state-separation
```

**Step 6: 提交最终版本**

```bash
git add .
git commit -m "release: 完成 Event 状态分离架构实施

- ✅ RuntimeEventInstance 支持状态管理
- ✅ OnMouseEnter 使用 RuntimeEventInstance
- ✅ OnMouseExit 使用 RuntimeEventInstance
- ✅ BaseEvent 支持新的初始化模式
- ✅ 完整的文档和测试

相关问题: #12 (Event 资源共享状态冲突)
"
```

---

## 附录：测试检查清单

### 功能测试

- [ ] 鼠标进入 start 按钮，只有 start 放大
- [ ] 鼠标进入 continue 按钮，只有 continue 放大
- [ ] 鼠标离开按钮后，按钮缩回到正常大小
- [ ] 多次鼠标悬停，按钮可以重复响应（trigger_once_per_enter = false）
- [ ] 设置 trigger_once_per_enter = true，按钮只响应一次

### 状态隔离测试

- [ ] 两个按钮的 `_is_hovered` 状态完全独立
- [ ] 两个按钮的 `_has_exited` 状态完全独立
- [ ] 快速在两个按钮之间移动鼠标，不会出现状态混乱

### 向后兼容性测试

- [ ] 旧的 Event 资源（没有 RuntimeEventInstance）仍能正常工作
- [ ] 旧的测试场景仍能正常运行
- [ ] 没有破坏性的 API 变更

### 性能测试

- [ ] 内存使用正常（没有明显增加）
- [ ] RuntimeEventInstance 正确创建和销毁
- [ ] 没有内存泄漏

### 文档完整性

- [ ] 架构文档完整
- [ ] API 文档更新
- [ ] 代码注释充分
- [ ] 示例代码正确

---

## 常见问题

### Q1: 为什么不直接使用 Resource.duplicate()？

**A:** Resource.duplicate() 虽然简单，但违背了 Resource 的设计初衷：
- 失去资源复用优势
- 编辑器修改不生效
- 违背"配置与状态分离"原则

RuntimeInstance 模式保留了资源共享的优势，同时实现了状态隔离。

### Q2: 是否需要立即迁移所有 Event 类？

**A:** 不需要。这个迁移是渐进式的：
- **高优先级**：有状态共享问题的 Event（OnMouseEnter、OnMouseExit 等）
- **中优先级**：其他 Input 类 Event（OnButtonPressed、OnKeyPressed 等）
- **低优先级**：没有状态共享问题的 Event（OnReady、OnTimer 等）

### Q3: 旧的 Event 代码还能用吗？

**A:** 可以。我们保持了向后兼容：
- `initialize()` 方法仍然可用
- Event 资源中的状态变量仍然有效
- 只是推荐使用新的 `initialize_with_runtime_instance()` 方法

### Q4: 如何调试 RuntimeEventInstance 的状态？

**A:** 可以使用以下方法：

```gdscript
# 在 Event 中打印状态
func _on_mouse_entered():
    var is_hovered = _runtime_instance_ref.get_state("is_hovered", false)
    _log_debug("is_hovered: %s" % is_hovered)

    # 打印所有状态
    _log_debug("所有状态: %s" % str(_runtime_instance_ref.runtime_state))
```

### Q5: RuntimeEventInstance 的性能开销是多少？

**A:** RuntimeEventInstance 继承自 RefCounted，非常轻量级：
- 内存开销：约 200-300 字节/实例
- 创建时间：< 1ms
- 状态访问：O(1) 字典查询

对于大多数应用场景，这个开销可以忽略不计。

---

**实施估算时间:**
- Phase 1-3: 2-3 小时（核心实现）
- Phase 4-5: 1-2 小时（集成和测试）
- Phase 6-7: 1 小时（文档和清理）
- Phase 8-9: 1-2 小时（最终验证）

**总计: 5-8 小时**
