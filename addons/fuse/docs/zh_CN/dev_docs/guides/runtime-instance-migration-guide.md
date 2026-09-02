> 🌐 中文 | [**English**](../../../en_US/dev_docs/guides/runtime-instance-migration-guide.md)

# Event RuntimeInstance 迁移指南

**状态:** 已发布
**版本:** 2.0
**作者:** Fuse 开发团队
**日期:** 2026-06-17
**关键词:** runtime-instance, migration, event, state-isolation, self-declared-state, _emit_triggered

---

## 概述

当你创建一个 Event 类（比如 `OnMouseEnter`），你可能会想存储一些运行时状态——比如 `_is_hovered`。这在单个 Trigger 时工作正常，但当多个 Trigger 共享同一个 Event 资源时，状态会互相覆盖。

RuntimeInstance 架构通过将状态从 Event 资源中分离出来，放到轻量级的 `RuntimeEventInstance` 中，彻底解决这个问题。

**核心思想：**
- Event 资源 = 纯配置（`@export` 变量）
- RuntimeEventInstance = 运行时状态（每个 Trigger 独立）

**新版架构（自声明状态模式）：**
- Event 通过 `get_default_runtime_state()` 方法声明自己的状态
- 无需修改核心代码（`RuntimeEventInstance`）
- 遵循开闭原则（Open/Closed Principle）

---

## 迁移步骤（新版）

### 第一步：识别状态变量

找到你的 Event 类中的运行时状态变量。它们通常是用来追踪事件触发状态的成员变量。

```gdscript
class_name OnMyEvent extends BaseEvent

var _has_triggered: bool = false     # ❌ 共享状态
var _trigger_count: int = 0          # ❌ 共享状态
var _last_trigger_time: float = 0.0  # ❌ 共享状态
```

**问题**：当两个 Trigger 共享这个 Event 资源时，后初始化的 Trigger 会覆盖先初始化的 Trigger 的状态。

---

### 第二步：删除状态变量

删除这些状态变量，添加对 `RuntimeEventInstance` 的引用：

```gdscript
class_name OnMyEvent extends BaseEvent

# 🔧 运行时状态现在存储在 RuntimeEventInstance 中
var _runtime_instance_ref: RuntimeEventInstance = null
```

**就这么简单**。不再需要在 Event 类中存储任何运行时状态。

---

### 第三步：实现 get_default_runtime_state() 方法

这是**新版架构的核心**。在 Event 中添加 `get_default_runtime_state()` 方法来声明状态：

```gdscript
## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["has_triggered"] = false
	base["trigger_count"] = 0
	base["last_trigger_time"] = 0.0
	return base
```

**关键点：**
- 调用 `super.get_default_runtime_state()` 获取基础状态（initialized, trigger_count, last_trigger_time）
- 添加你的 Event 特定的状态
- 返回完整的状态字典

**优势：**
- ✅ 无需修改 `RuntimeEventInstance._initialize_runtime_state()`
- ✅ 状态声明清晰明确
- ✅ 用户创建自定义 Event 更方便

---

### 第四步：实现 initialize_with_runtime_instance() 方法

如果你的 Event 有运行时状态，需要实现 `initialize_with_runtime_instance()` 方法来接收 RuntimeEventInstance 实例：

```gdscript
## 使用运行时实例初始化事件
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		return

	# 🔧 保存 RuntimeEventInstance 引用
	_runtime_instance_ref = runtime_instance

	# 验证参数
	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 连接信号或设置监听
	# ... 你的初始化逻辑 ...

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})
```

**关键点**：
- 必须先检查 `Engine.is_editor_hint()`
- 保存 `runtime_instance` 到 `_runtime_instance_ref`
- 使用传入的 `owner_node` 参数进行初始化
- 这是 Trigger 调用 Event 的入口点

**何时需要实现此方法**：
- ✅ Event 有运行时状态（已实现 `get_default_runtime_state()`）
- ✅ Event 使用 RuntimeInstance 架构

**何时不需要实现**：
- ⚠️ Event 是无状态的（纯信号转发）
- ⚠️ Event 使用旧的 `initialize()` 方法

**向后兼容**：
- 如果 Event 没有实现 `initialize_with_runtime_instance()`，Trigger 会调用旧的 `initialize()` 方法
- 这样保证了向后兼容性

---

### 第五步：修改状态访问

现在所有状态访问都通过 `RuntimeEventInstance` 进行：

**读取状态：**
```gdscript
func _on_event_triggered():
	# 使用 RuntimeEventInstance 的状态
	var has_triggered: bool = false
	if _runtime_instance_ref and _runtime_instance_ref.has_runtime_state("has_triggered"):
		has_triggered = _runtime_instance_ref.get_runtime_state("has_triggered")

	# 检查触发条件
	if has_triggered:
		return

	# ... 事件逻辑 ...
```

**写入状态：**
```gdscript
func _on_event_triggered():
	# ... 事件逻辑 ...

	# 更新 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("has_triggered", true)
		_runtime_instance_ref.set_runtime_state("trigger_count",
			_runtime_instance_ref.get_runtime_state("trigger_count", 0) + 1
		)
```

**就这么简单**。所有状态现在都是独立的，每个 Trigger 有自己的一份。

---

### 第六步：清理状态

在 `terminate()` 和 `reset()` 方法中清理 RuntimeEventInstance 状态：

```gdscript
func terminate(owner_node: Node) -> void:
	# 断开信号连接
	_disconnect_signals(owner_node)

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

**就这样！** 你的 Event 类现在使用 RuntimeInstance 架构了。

---

## 完整示例

### Before: 旧架构（状态共享问题）

```gdscript
class_name OnMouseEnter extends BaseEvent

@export var target_node_path: NodePath = NodePath("")
@export var trigger_once_per_enter: bool = true

signal triggered(context: Node)

var _is_hovered: bool = false       # ❌ 共享状态
var _owner_node_ref: Node = null     # ❌ 共享引用
var _signal_connections: Dictionary = {}

func initialize(owner_node: Node) -> void:
	_owner_node_ref = owner_node
	# ... 连接信号 ...

func _on_mouse_entered():
	# ❌ 使用共享状态
	if trigger_once_per_enter and _is_hovered:
		return

	_is_hovered = true  # ❌ 修改共享状态

	triggered.emit(null)
```

**问题**：两个 Trigger 共享这个 Event 资源时，`_is_hovered` 会被覆盖。

---

### After: 新架构（状态隔离 + 自声明状态）

```gdscript
class_name OnMouseEnter extends BaseEvent

@export var target_node_path: NodePath = NodePath("")
@export var trigger_once_per_enter: bool = true

# 注：BaseEvent 已定义 triggered(context: Node) 信号，子类无需重新声明

# ✅ 运行时状态存储在 RuntimeEventInstance 中
var _runtime_instance_ref: RuntimeEventInstance = null
var _signal_connections: Dictionary = {}

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["is_hovered"] = false
	return base

func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		return

	# ✅ 保存 RuntimeEventInstance 引用
	_runtime_instance_ref = runtime_instance

	var target_node = owner_node.get_node_or_null(target_node_path)
	if not target_node:
		return

	_connect_hover_signals(target_node, owner_node)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

func _on_mouse_entered_with_context(owner: Node):
	# ✅ 使用 RuntimeEventInstance 的状态
	var is_hovered: bool = false
	if _runtime_instance_ref and _runtime_instance_ref.has_runtime_state("is_hovered"):
		is_hovered = _runtime_instance_ref.get_runtime_state("is_hovered")

	if trigger_once_per_enter and is_hovered:
		_log_debug_localized("FUSE_LOG_EVENT_ALREADY_ENTERED", {})
		return

	# ✅ 更新 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("is_hovered", true)
		_runtime_instance_ref.update_trigger_stats()

	var target_node = owner.get_node_or_null(target_node_path)

	# ✅ 使用 _emit_triggered() 自动设置 trigger meta
	_emit_triggered(target_node, owner)

func terminate(owner_node: Node) -> void:
	# ... 断开信号 ...

	# ✅ 清理 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("is_hovered", false)

	_runtime_instance_ref = null
```

**优势**：每个 Trigger 有独立的 `is_hovered` 状态，互不干扰。而且**无需修改 RuntimeEventInstance**！

---

## 常见模式

### 模式 1：状态声明（新版核心）

在 Event 中实现 `get_default_runtime_state()` 方法：

```gdscript
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["state_key"] = default_value
	base["another_key"] = another_default
	return base
```

### 模式 2：RuntimeInstance 初始化

实现 `initialize_with_runtime_instance()` 方法来接收 RuntimeEventInstance 实例：

```gdscript
## 使用运行时实例初始化事件
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
	var target_node = owner_node.get_node_or_null(target_node_path)
	if not target_node:
		return

	if not target_node.some_signal.is_connected(_on_event_triggered):
		target_node.some_signal.connect(_on_event_triggered)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})
```

**关键点**：
- 检查编辑器模式
- 保存 RuntimeEventInstance 引用
- 验证 owner_node
- 连接信号

### 模式 3：状态访问

使用 `get_runtime_state()` 读取，`set_runtime_state()` 写入：

```gdscript
# 读取
var value = _runtime_instance_ref.get_runtime_state("key", default_value)

# 检查是否存在
if _runtime_instance_ref.has_runtime_state("key"):
	# 状态存在
	pass

# 写入
_runtime_instance_ref.set_runtime_state("key", new_value)
```

### 模式 4：信号转发

使用 `_emit_triggered()` 自动设置 trigger meta，无需手动创建临时节点：

```gdscript
# ✅ 推荐：使用 _emit_triggered() 自动设置 trigger meta
_emit_triggered(target_node, owner)

# 如果 context 和 trigger_node 是同一个节点：
_emit_triggered(owner_node, owner_node)
```

`_emit_triggered()` 会在 context 上设置 `"trigger"` meta，防止信号被广播到其他 RuntimeEventInstance。

### 模式 5：Timer 对象处理

Timer 等节点对象**不存储**在 RuntimeEventInstance 中，仍然在 Event 类中管理：

```gdscript
var _timer: Timer = null  # Timer 对象保留在 Event 类

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["current_count"] = 0  # 只存储计数器状态
	return base
```

---

## 旧版 vs 新版对比

### 旧版（已弃用）❌

需要修改 `RuntimeEventInstance._initialize_runtime_state()`，添加 match 分支：

```gdscript
# 在 RuntimeEventInstance.gd 中添加
match event_definition.get_event_type():
	"my_event":
		runtime_state["has_triggered"] = false
		runtime_state["trigger_count"] = 0
		runtime_state["last_trigger_time"] = 0.0
```

**缺点：**
- 每添加一个 Event 都要修改核心代码
- 违反开闭原则（Open/Closed Principle）
- 用户创建自定义 Event 不友好
- 代码集中在核心类中，难以维护

### 新版（推荐）✅

在 Event 中实现 `get_default_runtime_state()` 方法：

```gdscript
# 在 Event 类中添加
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["has_triggered"] = false
	base["trigger_count"] = 0
	base["last_trigger_time"] = 0.0
	return base
```

**优点：**
- ✅ 无需修改核心代码
- ✅ 遵循开闭原则
- ✅ 用户创建自定义 Event 更方便
- ✅ 状态声明清晰明确
- ✅ 易于维护和扩展

---

## 向后兼容性

**好消息**：`RuntimeEventInstance` 同时支持新旧两种模式。

1. **新架构（推荐）**: Event 实现了 `get_default_runtime_state()` 方法
   - RuntimeEventInstance 自动调用此方法
   - 获取状态声明并初始化

2. **旧架构（向后兼容）**: Event 未实现 `get_default_runtime_state()` 方法
   - RuntimeEventInstance 使用 match 分支初始化
   - 保持对已迁移 Events 的支持

**迁移是渐进式的**：
- 不需要一次性迁移所有 Event
- 可以选择性地迁移有状态共享问题的 Event
- 旧的 Event 继续工作

---

## 迁移检查清单

- [ ] 删除 Event 类中的运行时状态变量（`_is_hovered`、`_has_exited` 等）
- [ ] 添加 `_runtime_instance_ref: RuntimeEventInstance` 引用
- [ ] 实现 `get_default_runtime_state()` 方法（**新版核心步骤**）
- [ ] 实现 `initialize_with_runtime_instance()` 方法（接收 RuntimeEventInstance 实例）
- [ ] 修改所有状态访问使用 `get_runtime_state()` / `set_runtime_state()`
- [ ] 在 `terminate()` 和 `reset()` 中清理状态
- [ ] 测试多个 Trigger 共享同一个 Event 资源的场景
- [ ] 在 Event 文件顶部添加迁移注释

---

## 添加迁移注释

迁移完成后，在 Event 文件顶部添加注释：

```gdscript
## Event: OnMyEvent
##
## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - _has_triggered: bool - 是否已触发
## - _trigger_count: int - 触发次数
## - _last_trigger_time: float - 最后触发时间
##
## 相关文档: addons/fuse/docs/migration-guide-to-runtime-instance.md
class_name OnMyEvent
extends BaseEvent
```

---

## 性能影响

**内存开销：**
- 每个 `RuntimeEventInstance`：约 200-500 字节
- 100 个 Trigger：约 50-110 KB
- **影响可忽略**

**CPU 开销：**
- 状态访问：字典查找 O(1)，<1 微秒
- 信号转发：额外一次信号发射，<10 微秒
- **总体影响 <1%**

---

## 已迁移的 Events 示例

以下是已使用自声明状态模式迁移的 Events：

### 1. OnTimer
```gdscript
## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["current_repeat_count"] = 0
	return base
```

### 2. OnInputKey
```gdscript
## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["is_key_pressed"] = false
	base["has_triggered"] = false
	return base
```

### 3. OnInterval（最复杂的示例）
```gdscript
## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["current_repeat_count"] = 0
	base["is_running"] = false
	base["is_completed"] = false
	base["last_input_time"] = 0.0
	return base
```

**完整列表**：
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

## 相关资源

- [Runtime 实例分析](runtime-instruction-instance-guide.md) - 三件套架构与状态隔离
- Event 资源共享问题背景：见本文档「概述」与历史分析（本地归档）
- 快速入门：按本文档「迁移步骤」顺序执行即可
- [RuntimeEventInstance API](../../../../core/runtime_event_instance.gd) - 核心类

---

## 更新日志

### v2.1 (2026-06-17)
- 🔧 修复示例：使用 `_emit_triggered()` 替代 `triggered.emit()`
- 🔧 移除示例中不必要的 `signal triggered` 重新声明
- 🔧 移除创建临时节点的反模式
- 🔗 修复断链引用

### v2.0 (2026-02-03)
- ✨ 重构为自声明状态模式
- ✨ 添加 `get_default_runtime_state()` 方法说明
- ✨ 移除 match 分支迁移方式（标记为已弃用）
- 🐛 更新迁移步骤和示例
- 📝 添加 12 个已迁移 Events 示例

### v1.0 (2026-02-03)
- 🎉 初始版本（基于 match 分支模式）

---

**迁移完成后，你的 Event 类将拥有：**
- ✅ 完全独立的状态（每个 Trigger）
- ✅ 可共享的配置资源（节省内存）
- ✅ 向后兼容性（旧代码仍能工作）
- ✅ 清晰的架构（配置与状态分离）
- ✅ 无需修改核心代码

**就这么简单！**
