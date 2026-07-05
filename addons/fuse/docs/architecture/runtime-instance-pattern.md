# RuntimeInstance 架构模式

## 版本信息

- **v2.0** (自声明状态模式) - 2026-02-03 起推荐 ⭐
- **v1.0** (match 分支模式) - 早期实现，向后兼容

---

## 概述

Fuse 系统采用"RuntimeInstance 模式"来实现资源共享与状态隔离的平衡。这是一个在 Godot 引擎中处理 Resource 共享问题的设计模式。

## 问题背景

在 Godot 中，Resource 类型（如 Event、ActionRunner）作为 SubResource 被多个节点共享时，如果 Resource 包含运行时状态（如 `_is_hovered`、`_has_exited`），会导致状态污染问题。

### 问题示例

```
场景：两个按钮（start 和 continue）共享同一个 OnMouseEnter 资源

1. start Trigger 初始化 → Event._is_hovered = false
2. continue Trigger 初始化 → Event._is_hovered = false
3. 鼠标进入 start → Event._is_hovered = true
4. 鼠标进入 continue → Event._is_hovered 被覆盖，start 的状态丢失 ❌
```

### 根本原因

**Godot SubResource 机制**：当多个场景实例引用同一个 SubResource 时，它们共享**同一个 Resource 对象实例**。这意味着 Resource 中的成员变量会被所有引用者共享。

**问题代码模式**：
```gdscript
# ❌ 错误：在 Resource 中定义运行时状态
class_name OnMouseEnter extends BaseEvent
    var _is_hovered: bool = false  # 共享状态！
    var _owner_node_ref: Node = null  # 共享引用！
```

## 解决方案

### 设计原则

1. **Resource = 纯配置**
   - 只包含 `@export` 配置变量
   - 不包含运行时状态
   - 可安全地被多个节点共享

2. **RuntimeInstance = 运行时逻辑 + 状态**
   - 继承自 `RefCounted`（轻量级，自动内存管理）
   - 包含所有运行时状态
   - 每个 Trigger 有独立实例

### 架构组件

#### 1. RuntimeEventInstance

```gdscript
class_name RuntimeEventInstance extends RefCounted

## 事件定义资源（共享配置）
var event_definition: BaseEvent

## 运行时状态字典（独立状态）
var runtime_state: Dictionary = {}

## 拥有此实例的触发器节点
var owner_trigger: Node

## 信号：每个实例独立发出
signal triggered(context: Node)

# 状态管理方法
func get_runtime_state(key: String, default_value = null)
func set_runtime_state(key: String, value)
func has_runtime_state(key: String) -> bool
func remove_runtime_state(key: String)
func get_all_runtime_states() -> Dictionary
func reset_runtime_state()
```

**关键特性**：
- **轻量级**：继承自 `RefCounted`，内存开销小
- **自动清理**：引用计数为 0 时自动销毁
- **独立信号**：每个实例有独立的 `triggered` 信号
- **状态隔离**：每个实例有独立的 `runtime_state` 字典
- **Trigger 验证**：在 `_on_event_triggered()` 中验证 Trigger 匹配

#### 2. RuntimeActionRunnerInstance

```gdscript
class_name RuntimeActionRunnerInstance extends RefCounted

## ActionRunner 定义资源（共享配置）
var action_runner: ActionRunner

## 运行时状态字典（独立状态）
var runtime_state: Dictionary = {}

## 拥有此实例的触发器节点
var owner_trigger: Node

## 信号：每个实例独立发出
signal execution_completed(total_time: float)
signal execution_failed(error_message: String)
signal instruction_started(instruction: BaseInstruction)
signal instruction_completed(instruction: BaseInstruction)
```

**关键特性**：
- **执行隔离**：每个实例独立执行指令序列
- **状态管理**：独立的运行时状态（`is_running`、`current_context` 等）
- **信号独立**：每个实例有独立的完成信号
- **取消支持**：支持独立的执行取消

#### 3. BaseEvent 集成

```gdscript
class_name BaseEvent extends Resource

## RuntimeEventInstance 引用（由子类使用）
var _runtime_instance_ref: RuntimeEventInstance = null

## 使用 RuntimeEventInstance 初始化（新方法）
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
    # 保存引用
    _runtime_instance_ref = runtime_instance

    # 调用原有的 initialize 方法（向后兼容）
    initialize(owner_node)

    # 子类可以重写此方法来处理特定的运行时状态
    _initialize_runtime_state(runtime_instance)

## 传统的 initialize 方法（向后兼容）
func initialize(owner_node: Node) -> void:
    # 传统初始化逻辑
    pass

## 由子类实现：初始化运行时状态
func _initialize_runtime_state(runtime_instance: RuntimeEventInstance) -> void:
    pass
```

**向后兼容性**：
- 保留原有的 `initialize()` 方法
- 新增 `initialize_with_runtime_instance()` 方法
- 子类可以选择性地使用 RuntimeEventInstance

## 使用方式

### Event 实现

#### 旧代码（状态共享问题）

```gdscript
class_name OnMouseEnter extends BaseEvent

# ❌ 不要在 Event 中定义状态
var _is_hovered: bool = false

func _on_mouse_entered():
    # ❌ 使用共享状态
    if trigger_once_per_enter and _is_hovered:
        return

    _is_hovered = true  # ❌ 影响所有共享此资源的 Trigger
```

#### 新代码（状态隔离）

```gdscript
class_name OnMouseEnter extends BaseEvent

# ✅ 只定义配置
@export var target_node_path: NodePath = NodePath("")
@export var trigger_once_per_enter: bool = true

var _runtime_instance_ref: RuntimeEventInstance = null

func _on_mouse_entered_with_context(owner: Node):
    # ✅ 使用 RuntimeEventInstance 的状态
    var is_hovered: bool = false
    if _runtime_instance_ref and _runtime_instance_ref.has_runtime_state("is_hovered"):
        is_hovered = _runtime_instance_ref.get_runtime_state("is_hovered")

    if trigger_once_per_enter and is_hovered:
        return

    # ✅ 更新 RuntimeEventInstance 的状态
    if _runtime_instance_ref:
        _runtime_instance_ref.set_runtime_state("is_hovered", true)
        _runtime_instance_ref.update_trigger_stats()
```

### Trigger 使用

```gdscript
class_name Trigger extends Node

## RuntimeEventInstance 实例
var _runtime_event_instance: RuntimeEventInstance = null

func _ready():
    # ✅ 创建 RuntimeEventInstance
    _runtime_event_instance = RuntimeEventInstance.new(event_definition, self)

    # ✅ 初始化 Event（传入 RuntimeEventInstance）
    event_definition.initialize_with_runtime_instance(self, _runtime_event_instance)

    # ✅ 连接 RuntimeEventInstance 的信号
    _runtime_event_instance.triggered.connect(_on_event_fired)

func _exit_tree():
    # ✅ 清理 RuntimeEventInstance
    if _runtime_event_instance:
        _runtime_event_instance.cleanup()
        _runtime_event_instance = null
```

---

## RuntimeEventInstance 状态初始化

### v2.0: 自声明状态模式（推荐）⭐

**这是当前推荐的方式**，遵循开闭原则，用户无需修改核心代码。

Event 通过实现 `get_default_runtime_state()` 方法来声明自己的运行时状态：

```gdscript
class_name OnMyEvent extends BaseEvent

var _runtime_instance_ref: RuntimeEventInstance = null

## 获取默认运行时状态 ⭐ 核心方法（v2.0）
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["has_triggered"] = false
	base["trigger_count"] = 0
	base["last_trigger_time"] = 0.0
	return base

## 使用 RuntimeInstance 初始化
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		return

	# 🔧 关键：必须保存 RuntimeEventInstance 引用
	_runtime_instance_ref = runtime_instance

	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 初始化运行时状态（RuntimeEventInstance 会调用 get_default_runtime_state()）
	# 状态已由 RuntimeEventInstance 自动初始化，这里可以直接使用

	# 获取目标节点并存储到 RuntimeInstance
	var target = owner_node.get_node_or_null(target_node_path)
	if not target:
		return

	# ✅ 将节点引用存储到 RuntimeInstance
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("target_node", target)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})
```

**访问运行时状态**：

```gdscript
# 读取状态（带默认值）
var has_triggered = _runtime_instance_ref.get_runtime_state("has_triggered", false)
var trigger_count = _runtime_instance_ref.get_runtime_state("trigger_count", 0)

# 写入状态
_runtime_instance_ref.set_runtime_state("has_triggered", true)
_runtime_instance_ref.set_runtime_state("trigger_count", trigger_count + 1)

# 检查状态是否存在
if _runtime_instance_ref.has_runtime_state("my_state"):
	var value = _runtime_instance_ref.get_runtime_state("my_state")
```

**优势**：
- ✅ **开闭原则**：对扩展开放，对修改封闭
- ✅ **用户友好**：用户创建自定义 Event 无需修改核心代码
- ✅ **清晰明确**：状态声明就在 Event 类中，一目了然
- ✅ **易于维护**：相关代码集中，便于理解和修改

---

### v1.0: match 分支模式（已弃用）

**早期实现方式**，需要在 RuntimeEventInstance 中添加 match 分支。

```gdscript
# 在 RuntimeEventInstance.gd 的 _initialize_runtime_state() 中
func _initialize_runtime_state():
	# 调用 Event 的 get_default_runtime_state() 方法（v2.0）
	if event_definition.has_method("get_default_runtime_state"):
		var default_state = event_definition.get_default_runtime_state()
		for key in default_state:
			runtime_state[key] = default_state[key]
	else:
		# v1.0 兼容模式：使用 match 分支
		match event_definition.get_event_type():
			"mouse_enter":
				runtime_state["is_hovered"] = false
				runtime_state["trigger_count"] = 0
				runtime_state["last_trigger_time"] = 0.0
			"mouse_exit":
				runtime_state["has_exited"] = false
				runtime_state["trigger_count"] = 0
			"timer":
				runtime_state["elapsed_time"] = 0.0
				runtime_state["is_running"] = false
			# ... 每个新 Event 都要添加分支
```

**缺点**：
- ❌ 每次添加 Event 都要修改核心代码
- ❌ 违反开闭原则（Open/Closed Principle）
- ❌ 用户创建自定义 Event 不友好

---

## 架构对比

| 特性 | v1.0 (match 分支) | v2.0 (自声明状态) |
|------|------------------|------------------|
| **核心方法** | 在 RuntimeEventInstance 中添加 match 分支 | 在 Event 中实现 `get_default_runtime_state()` |
| **添加新 Event** | 需要修改核心代码 | 只需在 Event 类中实现方法 |
| **用户友好** | ❌ 需要了解 RuntimeEventInstance 内部 | ✅ 只需关注自己的 Event 类 |
| **开闭原则** | ❌ 对修改开放 | ✅ 对扩展开放，对修改封闭 |
| **向后兼容** | - | ✅ 旧版模式仍然可用 |
| **代码位置** | 集中在 RuntimeEventInstance | 分散在各个 Event 类 |
| **维护性** | 修改核心代码风险高 | Event 内部修改影响小 |

---

## 常见问题与解决方案

### 问题 1：忘记保存 RuntimeEventInstance 引用

**症状**：状态访问返回 `null` 或 `0`，Event 行为异常

**错误代码**：
```gdscript
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	# ❌ 忘记保存引用
	# _runtime_instance_ref = runtime_instance  # 这行缺失！

	# 后续访问会失败
	_runtime_instance_ref.set_runtime_state("has_triggered", false)  # 💥 错误
```

**正确代码**：
```gdscript
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	# ✅ 必须先保存引用
	_runtime_instance_ref = runtime_instance

	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 现在可以正常访问
	_runtime_instance_ref.set_runtime_state("has_triggered", false)
```

**实际案例**：`OnInterval` 的停止条件检查失效问题（2026-02-03 修复）

---

### 问题 2：节点未存储到 RuntimeEventInstance

**症状**：Event 初始化成功，但信号回调中无法访问节点

**错误代码**：
```gdscript
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	_runtime_instance_ref = runtime_instance

	# 获取目标节点
	var target = owner_node.get_node_or_null(target_node_path)
	if not target:
		return

	# ❌ 忘记存储到 RuntimeEventInstance

	target.some_signal.connect(_on_signal)

func _on_signal():
	# 💥 获取失败，因为没有存储过
	var target_node = _runtime_instance_ref.get_runtime_state("target_node")
	if not target_node:
		return  # 总是返回
```

**正确代码**：
```gdscript
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	_runtime_instance_ref = runtime_instance

	# 获取目标节点
	var target = owner_node.get_node_or_null(target_node_path)
	if not target:
		return

	# ✅ 立即存储到 RuntimeEventInstance
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("target_node", target)

	target.some_signal.connect(_on_signal)

func _on_signal():
	# ✅ 现在可以正常获取
	var target_node = _runtime_instance_ref.get_runtime_state("target_node")
	if target_node:
		triggered.emit(target_node)
```

**实际案例**：`OnTargetSignalEmit` 收到信号但不触发 ActionRunner（2026-02-03 修复）

---

### 问题 3：空指针访问 `.name` 属性

**症状**：运行时错误 "Invalid access to property or key 'name' on a base object of type 'Nil'"

**错误代码**：
```gdscript
func _on_some_callback(node: Node):
	# ❌ 直接访问 .name，如果 node 为 null 会崩溃
	_log_info_localized("FUSE_LOG_SOME_MESSAGE", {
		"node": node.name  # 💥 运行时错误
	})
```

**正确代码**：
```gdscript
func _on_some_callback(node: Node):
	if not node or not is_instance_valid(node):
		return

	# ✅ 安全的名称提取
	var node_name = node.name if node.name else "Unknown"
	_log_info_localized("FUSE_LOG_SOME_MESSAGE", {
		"node": node_name
	})
```

**推荐模式**：
```gdscript
# 模式 1：简单情况（已知 node 不为 null）
var node_name = node.name if node else "Unknown"

# 模式 2：严格情况（需要验证实例有效性）
var node_name = "Unknown"
if node and is_instance_valid(node):
	node_name = node.name if node.name else "Unknown"
```

**实际案例**：多个 Event 文件的 `.name` 访问安全问题（2026-02-03 修复）
- 影响文件：`OnNodeInstance`, `OnPropertyChanged`, `OnSignalFromGroup`, `OnBodyEntered`

---

## 优势分析

### 1. 完全隔离

**问题**：多个 Trigger 共享 Event 资源时状态互相干扰

**解决**：每个 Trigger 有独立的 RuntimeEventInstance

```gdscript
# start Trigger
start_runtime_instance.set_runtime_state("is_hovered", true)
# ✅ 不影响 continue Trigger 的状态

# continue Trigger
continue_runtime_instance.set_runtime_state("is_hovered", true)
# ✅ 不影响 start Trigger 的状态
```

### 2. 资源共享

**优势**：配置资源仍可共享，节省内存

```gdscript
# 两个 Trigger 共享同一个 OnMouseEnter 资源
start.event_resource = OnMouseEnter  # 1 个 Resource
continue.event_resource = OnMouseEnter  # 共享同一个 Resource

# 但每个有独立的 RuntimeEventInstance
start._runtime_event_instance = RuntimeEventInstance.new(...)  # 实例 A
continue._runtime_event_instance = RuntimeEventInstance.new(...)  # 实例 B
```

**内存开销**：
- Event Resource：共享（约 1-2 KB）
- RuntimeEventInstance：每个 Trigger（约 200-500 字节）

### 3. 向后兼容

**保留旧方法**：
```gdscript
# 旧代码仍然可以使用
event.initialize(owner_trigger)

# 新代码使用 RuntimeEventInstance
event.initialize_with_runtime_instance(owner_trigger, runtime_instance)
```

### 4. 轻量级

**RefCounted 特性**：
- 自动引用计数管理
- 引用为 0 时自动销毁
- 不需要手动内存管理
- 内存开销小

**内存对比**：
- Node：约 2-3 KB
- RefCounted：约 200-500 字节
- 节省约 80-90% 内存

### 5. 扩展性

**易于添加新状态**：
```gdscript
# 在 Event 代码中
_runtime_instance_ref.set_runtime_state("new_state", value)

# 在其他地方访问
var value = _runtime_instance_ref.get_runtime_state("new_state")
```

**支持自定义状态**（v2.0）：
```gdscript
# 子类通过 get_default_runtime_state() 声明状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["custom_data"] = {}
	return base
```

---

## 迁移指南

### 步骤 1：移除共享状态变量

```gdscript
# ❌ 删除
var _is_hovered: bool = false
var _has_exited: bool = false
var _trigger_count: int = 0
```

### 步骤 2：添加 RuntimeEventInstance 引用

```gdscript
# ✅ 添加
var _runtime_instance_ref: RuntimeEventInstance = null
```

### 步骤 3：实现 get_default_runtime_state() ⭐

```gdscript
## 获取默认运行时状态（v2.0 核心方法）
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["is_hovered"] = false
	base["has_exited"] = false
	base["trigger_count"] = 0
	return base
```

### 步骤 4：更新 initialize_with_runtime_instance()

```gdscript
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	# ✅ 必须保存引用
	_runtime_instance_ref = runtime_instance

	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# RuntimeEventInstance 会自动调用 get_default_runtime_state() 初始化状态

	# 获取并存储节点引用
	var target = owner_node.get_node_or_null(target_node_path)
	if target and _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("target_node", target)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})
```

### 步骤 5：更新状态访问

```gdscript
# ❌ 旧代码
if _is_hovered:
    return

# ✅ 新代码
var is_hovered = _runtime_instance_ref.get_runtime_state("is_hovered", false)
if is_hovered:
    return
```

### 步骤 6：更新状态设置

```gdscript
# ❌ 旧代码
_is_hovered = true

# ✅ 新代码
_runtime_instance_ref.set_runtime_state("is_hovered", true)
```

### 步骤 7：更新 terminate() 和 reset()

```gdscript
func terminate(owner_node: Node) -> void:
	# 断开信号连接
	if owner_node and owner_node.some_signal.is_connected(_on_some_signal):
		owner_node.some_signal.disconnect(_on_some_signal)

	# 清理运行时状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("is_hovered", false)
		_runtime_instance_ref.set_runtime_state("trigger_count", 0)

	_runtime_instance_ref = null

	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

func reset() -> void:
	super.reset()

	# 重置运行时状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("is_hovered", false)
		_runtime_instance_ref.set_runtime_state("trigger_count", 0)
```

---

## 最佳实践

### 1. 总是检查 RuntimeEventInstance 是否有效

```gdscript
# ✅ 推荐
if _runtime_instance_ref and _runtime_instance_ref.has_runtime_state("is_hovered"):
    is_hovered = _runtime_instance_ref.get_runtime_state("is_hovered")

# ❌ 不推荐（可能导致崩溃）
is_hovered = _runtime_instance_ref.get_runtime_state("is_hovered")
```

### 2. 提供默认值

```gdscript
# ✅ 推荐（提供默认值）
var is_hovered = _runtime_instance_ref.get_runtime_state("is_hovered", false)

# ❌ 不推荐（可能返回 null）
var is_hovered = _runtime_instance_ref.get_runtime_state("is_hovered")
```

### 3. 更新触发统计

```gdscript
# ✅ 推荐（更新统计信息）
if _runtime_instance_ref:
    _runtime_instance_ref.set_runtime_state("is_hovered", true)
    _runtime_instance_ref.update_trigger_stats()  # 更新计数和时间
```

### 4. 清理资源

```gdscript
# ✅ 在 Trigger._exit_tree() 中清理
func _exit_tree():
    if _runtime_event_instance:
        _runtime_event_instance.cleanup()
        _runtime_event_instance = null
```

### 5. 安全访问节点属性

```gdscript
# ✅ 安全访问 .name 属性
var node_name = "Unknown"
if node and is_instance_valid(node):
	node_name = node.name if node.name else "Unknown"

# ✅ 在日志中使用安全值
_log_info_localized("FUSE_LOG_EVENT_TRIGGERED", {
	"node": node_name
})
```

---

## 实际案例

### OnMouseEnter 迁移

**迁移前**（有问题）：
```gdscript
class_name OnMouseEnter extends BaseEvent
    var _is_hovered: bool = false

    func _on_mouse_entered():
        if trigger_once_per_enter and _is_hovered:
            return
        _is_hovered = true
```

**迁移后**（解决问题）：
```gdscript
class_name OnMouseEnter extends BaseEvent
    var _runtime_instance_ref: RuntimeEventInstance = null

    func get_default_runtime_state() -> Dictionary:
        var base = super.get_default_runtime_state()
        base["is_hovered"] = false
        return base

    func _on_mouse_entered_with_context(owner: Node):
        var is_hovered = _runtime_instance_ref.get_runtime_state("is_hovered", false)

        if trigger_once_per_enter and is_hovered:
            return

        _runtime_instance_ref.set_runtime_state("is_hovered", true)
        _runtime_instance_ref.update_trigger_stats()
```

**测试结果**：
```
✅ 鼠标进入 start → start 缩放到 (1.25, 1.25)
✅ 鼠标进入 continue → continue 缩放到 (1.25, 1.25)
✅ 两个按钮互不影响
```

### OnMouseExit 迁移

**迁移前**（有问题）：
```gdscript
class_name OnMouseExit extends BaseEvent
    var _has_exited: bool = false

    func _on_mouse_exited():
        if trigger_once_per_exit and _has_exited:
            return
        _has_exited = true
```

**迁移后**（解决问题）：
```gdscript
class_name OnMouseExit extends BaseEvent
    var _runtime_instance_ref: RuntimeEventInstance = null

    func get_default_runtime_state() -> Dictionary:
        var base = super.get_default_runtime_state()
        base["has_exited"] = false
        return base

    func _on_mouse_exited_with_context(owner: Node):
        var has_exited = _runtime_instance_ref.get_runtime_state("has_exited", false)

        if trigger_once_per_exit and has_exited:
            return

        _runtime_instance_ref.set_runtime_state("has_exited", true)
        _runtime_instance_ref.update_trigger_stats()
```

---

## 架构图

```
┌─────────────────────────────────────────────────────────────┐
│                      Trigger (Node)                          │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  RuntimeEventInstance (RefCounted)                    │  │
│  │  ├─ event_definition: BaseEvent (共享)               │  │
│  │  ├─ runtime_state: Dictionary (独立)                  │  │
│  │  │  ├─ is_hovered: false                             │  │
│  │  │  ├─ trigger_count: 0                              │  │
│  │  │  └─ last_trigger_time: 0.0                        │  │
│  │  └─ owner_trigger: Node                              │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ 引用
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              BaseEvent (Resource) - 共享配置                  │
│  @export var target_node_path: NodePath                     │
│  @export var trigger_once_per_enter: bool                   │
│                                                               │
│  func get_default_runtime_state() -> Dictionary:            │
│    var base = super.get_default_runtime_state()             │
│    base["is_hovered"] = false                               │
│    return base                                              │
│                                                               │
│  var _runtime_instance_ref: RuntimeEventInstance            │
└─────────────────────────────────────────────────────────────┘
                            ▲
                            │ 共享
                            │
┌─────────────────────────────────────────────────────────────┐
│                      Trigger (Node)                          │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  RuntimeEventInstance (RefCounted) - 不同实例           │  │
│  │  ├─ event_definition: BaseEvent (同一个)               │  │
│  │  ├─ runtime_state: Dictionary (不同状态)               │  │
│  │  │  ├─ is_hovered: true                               │  │
│  │  │  ├─ trigger_count: 1                               │  │
│  │  │  └─ last_trigger_time: 123456.78                   │  │
│  │  └─ owner_trigger: Node (不同)                        │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## 性能影响

### 内存开销

**单个 Trigger**：
- RuntimeEventInstance：约 200-500 字节
- RuntimeActionRunnerInstance：约 300-600 字节

**100 个 Trigger**：
- 总开销：约 50-110 KB
- **影响可忽略**

### CPU 开销

**状态访问**：
- 字典查找：O(1)
- 开销：<1 微秒

**信号转发**：
- RuntimeEventInstance.triggered → Event.triggered
- 额外一次信号发射
- 开销：<10 微秒

**总体影响**：<1% 性能损失（可测量但可接受）

---

## 迁移检查清单

### 迁移前检查

- [ ] Event 有运行时状态变量（如 `_has_triggered`, `_timer`, `_is_active`）
- [ ] Event 可能被多个场景/节点共享
- [ ] 备份原始 Event 文件

### 迁移步骤

- [ ] 1. 识别所有运行时状态变量
- [ ] 2. 删除状态变量，添加 `_runtime_instance_ref`
- [ ] 3. ⭐ **实现 `get_default_runtime_state()` 方法**
- [ ] 4. ⭐ **在 `initialize_with_runtime_instance()` 中保存引用**
- [ ] 5. 修改所有状态访问代码（使用 `get_runtime_state()` / `set_runtime_state()`）
- [ ] 6. 在 `terminate()` 和 `reset()` 中清理状态
- [ ] 7. 添加迁移注释文档

### 迁移后验证

- [ ] Event 功能正常工作
- [ ] 多个节点共享 Event 时状态独立
- [ ] 没有内存泄漏
- [ ] 通过 Godot headless 语法检查

---

## 与其他模式对比

### vs. Callable Wrapper 模式

| 特性 | RuntimeInstance | Callable Wrapper |
|------|----------------|------------------|
| 状态隔离 | ✅ 完全隔离 | 🟡 部分隔离（状态变量仍共享） |
| 资源共享 | ✅ 支持 | ✅ 支持 |
| 代码侵入性 | 🟢 低（修改 BaseEvent） | 🟡 中（修改每个 Event） |
| 维护成本 | 🟢 低 | 🔴 高 |
| 扩展性 | 🟢 高 | 🔴 低 |

### vs. SignalManager 模式

| 特性 | RuntimeInstance | SignalManager |
|------|----------------|---------------|
| 状态隔离 | ✅ 完全隔离 | ✅ 完全隔离 |
| 资源共享 | ✅ 支持 | ✅ 支持 |
| 复杂度 | 🟢 低 | 🟡 中等 |
| 实施成本 | 🟢 低 | 🟡 中等 |
| 统一管理 | 🟢 是（RuntimeInstance） | 🟢 是（SignalManager） |

---

## 相关文档

- **完整迁移指南**: [addons/fuse/docs/migration-guide-to-runtime-instance.md](migration-guide-to-runtime-instance.md)
- **快速开始指南**: [docs/plans/event-migration-quick-start.md](../../../plans/event-migration-quick-start.md)
- [Event 资源共享问题解决方案](../event-resource-sharing-solution.md)
- [BaseEvent API Reference](../api/base-event.md)
- [RuntimeEventInstance API Reference](../api/runtime-event-instance.md)
- [RuntimeActionRunnerInstance API Reference](../api/runtime-action-runner-instance.md)
- [自定义 Event 开发指南](../user_docs/best_practices/custom_event.md)

---

## 实施历史

### 2026-02-03

**迁移完成**：
- 完成 Phase 2 迁移，共 **61 个 Events** 全部迁移到 RuntimeInstance 架构
- 批次：Phase 1 (12个) + Batch 1-7 (49个)
- 所有 Events 通过 Godot headless 语法检查

**Bug 修复**：
1. **OnInterval 停止条件失效**
   - 问题：缺少 `_runtime_instance_ref = runtime_instance`
   - 修复：在 `initialize_with_runtime_instance()` 中添加引用保存
   - 文件：`addons/fuse/events/lifecycle/on_interval.gd:127`

2. **OnTargetSignalEmit 收到信号但不触发 ActionRunner**
   - 问题：`target_node` 未存储到 RuntimeEventInstance
   - 修复：在获取目标节点后立即存储到 `runtime_state["target_node"]`
   - 文件：`addons/fuse/events/node/on_target_signal_emit.gd:623-626`

3. **多个 Event 的 `.name` 空指针访问**
   - 问题：直接访问 `node.name` 未检查 null
   - 修复：添加安全名称提取模式
   - 影响文件：
     - `addons/fuse/events/node/on_node_instance.gd` (3处)
     - `addons/fuse/events/node/on_property_changed.gd` (1处)
     - `addons/fuse/events/node/on_signal_from_group.gd` (1处)
     - `addons/fuse/events/physics/on_body_entered.gd` (2处)

**架构升级**：
- 从 v1.0 (match 分支模式) 升级到 **v2.0 (自声明状态模式)**
- 实现开闭原则，用户添加自定义 Event 无需修改核心代码
- 所有 Events 实现 `get_default_runtime_state()` 方法

### 2026-02-02

- **初始实施 RuntimeEventInstance 架构**
- **OnMouseEnter 迁移完成**
- **OnMouseExit 迁移完成**
- **BaseEvent 集成完成**
- **Trigger 集成完成**

---

## 总结

RuntimeInstance 架构模式通过引入轻量级的运行时实例（继承自 RefCounted），在保持资源共享的同时实现了状态隔离。这个模式：

1. **解决了核心问题**：多个 Trigger 共享 Event 资源时的状态冲突
2. **保持了资源优势**：配置资源仍可共享，节省内存
3. **向后兼容**：保留旧的 `initialize()` 方法
4. **轻量高效**：RefCounted 对象，内存和 CPU 开销小
5. **易于扩展**：清晰的状态管理接口，易于添加新功能
6. **遵循开闭原则**：v2.0 自声明状态模式，对扩展开放，对修改封闭

这是一个在 Godot 引擎中处理 Resource 共享问题的优雅解决方案。

---

**文档版本**: 2.0
**最后更新**: 2026-02-03
**相关任务**:
- [docs/plans/2025-02-02-event-state-separation.md](../../../plans/2025-02-02-event-state-separation.md)
- [docs/plans/2025-02-03-event-runtime-instance-migration-phase2-complete.md](../../../plans/2025-02-03-event-runtime-instance-migration-phase2-complete.md)
