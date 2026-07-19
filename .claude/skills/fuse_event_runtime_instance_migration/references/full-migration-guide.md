# RuntimeInstance 架构完整迁移指南

**状态:** 已发布
**作者:** Fuse 开发团队
**日期:** 2026-02-03
**关键词:** runtime-instance, migration, event, state-isolation

---

## 概述

当你创建一个 Event 类（比如 `OnMouseEnter`），你可能会想存储一些运行时状态——比如 `_is_hovered`。这在单个 Trigger 时工作正常，但当多个 Trigger 共享同一个 Event 资源时，状态会互相覆盖。

RuntimeInstance 架构通过将状态从 Event 资源中分离出来，放到轻量级的 `RuntimeEventInstance` 中，彻底解决这个问题。

**核心思想：**
- Event 资源 = 纯配置（`@export` 变量）
- RuntimeEventInstance = 运行时状态（每个 Trigger 独立）

---

## 迁移步骤

### 第一步：识别状态变量

找到你的 Event 类中的运行时状态变量。它们通常是用来追踪事件触发状态的成员变量。

```gdscript
class_name OnMyEvent extends BaseEvent

var _has_triggered: bool = false     # ❌ 共享状态
var _trigger_count: int = 0          # ❌ 共享状态
var _last_trigger_time: float = 0.0  # ❌ 共享状态
```

**问题**：当两个 Trigger 共享这个 Event 资源时，后初始化的 Trigger 会覆盖先初始化的 Trigger 的状态。

**检测方法**：
- 查找所有 `var` 声明的成员变量
- 特别注意 `_` 前缀的私有变量
- 排除 `@export` 导出的配置变量

---

### 第二步：删除状态变量

删除这些状态变量，添加对 `RuntimeEventInstance` 的引用：

```gdscript
class_name OnMyEvent extends BaseEvent

# 🔧 运行时状态现在存储在 RuntimeEventInstance 中
# _runtime_instance_ref 继承自 BaseEvent，无需声明
```

**就这么简单**。不再需要在 Event 类中存储任何运行时状态。

---

### 第三步：添加 initialize_with_runtime_instance() 方法

实现新的初始化方法，接收并保存 `RuntimeEventInstance` 引用：

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

	# ... 其余初始化逻辑 ...

	# 连接信号
	_connect_signals(owner_node)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})
```

**关键点：**
- 在编辑器模式下跳过初始化
- 保存 `runtime_instance` 引用
- 使用传入的 `owner_node` 参数（不要依赖 `_owner_node_ref`）

---

### 第四步：修改状态访问

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

### 第五步：在 RuntimeEventInstance 中初始化状态

在 `RuntimeEventInstance._initialize_runtime_state()` 方法中为你的事件类型添加状态初始化：

```gdscript
# 在 addons/fuse/core/runtime_event_instance.gd 中

func _initialize_runtime_state():
	if not event_definition:
		_log_warning("没有事件定义，无法初始化运行时状态")
		return

	# 根据事件类型初始化特定的运行时状态
	match event_definition.get_event_type():
		"my_event":
			runtime_state["has_triggered"] = false
			runtime_state["trigger_count"] = 0
			runtime_state["last_trigger_time"] = 0.0
			_log_debug("MyEvent 状态已初始化")

		# ... 其他事件类型 ...
```

**位置**：在现有的 `mouse_enter`、`mouse_exit` 等初始化之后添加你的事件类型。

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

### After: 新架构（状态隔离）

```gdscript
class_name OnMouseEnter extends BaseEvent

@export var target_node_path: NodePath = NodePath("")
@export var trigger_once_per_enter: bool = true

signal triggered(context: Node)

# ✅ 运行时状态存储在 RuntimeEventInstance 中
# _runtime_instance_ref 继承自 BaseEvent，无需声明
var _signal_connections: Dictionary = {}

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
	var context_node = Node.new()
	context_node.set_meta("trigger", owner)
	context_node.set_meta("target_node", target_node)

	triggered.emit(context_node)
	context_node.queue_free()

func terminate(owner_node: Node) -> void:
	# ... 断开信号 ...

	# ✅ 清理 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("is_hovered", false)

	_runtime_instance_ref = null
```

**优势**：每个 Trigger 有独立的 `is_hovered` 状态，互不干扰。

---

## 常见模式

### 模式 1：状态初始化

在 `RuntimeEventInstance._initialize_runtime_state()` 中初始化状态：

```gdscript
match event_definition.get_event_type():
	"your_event":
		runtime_state["state_key"] = default_value
		runtime_state["another_key"] = another_default
```

### 模式 2：状态访问

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

### 模式 3：信号转发

如果事件信号需要验证来源，使用 `context.set_meta("trigger", owner)`：

```gdscript
var context_node = Node.new()
context_node.set_meta("trigger", owner)  # ✅ 设置正确的 trigger
triggered.emit(context_node)
```

`RuntimeEventInstance` 会验证 trigger 并转发信号。

---

## 向后兼容性

**好消息**：旧的 `initialize()` 方法仍然可用。

`BaseEvent.initialize_with_runtime_instance()` 的默认实现会调用 `initialize()`，所以不重写新方法的 Event 类仍然能正常工作。

**迁移是渐进式的**：
- 不需要一次性迁移所有 Event 类
- 可以选择性地迁移有状态共享问题的 Event
- 旧的 Event 类继续工作

---

## 性能影响

**内存开销**：
- 每个 `RuntimeEventInstance`：约 200-500 字节
- 100 个 Trigger：约 50-110 KB
- **影响可忽略**

**CPU 开销**：
- 状态访问：字典查找 O(1)，<1 微秒
- 信号转发：额外一次信号发射，<10 微秒
- **总体影响 <1%**

---

## 迁移检查清单

- [ ] 删除 Event 类中的运行时状态变量（`_is_hovered`、`_has_exited` 等）
- [ ] 添加 `_runtime_instance_ref: RuntimeEventInstance` 引用
- [ ] 实现 `initialize_with_runtime_instance()` 方法
- [ ] 修改所有状态访问使用 `get_runtime_state()` / `set_runtime_state()`
- [ ] 在 `RuntimeEventInstance._initialize_runtime_state()` 中添加状态初始化
- [ ] 在 `terminate()` 和 `reset()` 中清理状态
- [ ] 测试多个 Trigger 共享同一个 Event 资源的场景

---

**迁移完成后，你的 Event 类将拥有：**
- ✅ 完全独立的状态（每个 Trigger）
- ✅ 可共享的配置资源（节省内存）
- ✅ 向后兼容性（旧代码仍能工作）
- ✅ 清晰的架构（配置与状态分离）

**就这么简单！**
