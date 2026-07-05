# Fuse Event Bus 系统设计提案

**状态**: ✅ 已实现
**优先级**: 高
**创建日期**: 2026-02-27
**归档**: 2026-06-26 — 实现已落地,见 [FuseEventBus](../../../core/fuse_event_bus.gd) Autoload + [SendEvent](../../../instructions/event/send_event.gd) 指令 + [OnReceiveEvent](../../../events/event/on_receive_event.gd) 事件
**作者**: Claude Code

---

## 背景和动机

### 当前问题

Fuse 可视化编程系统目前**缺少全局事件通信机制**，导致以下问题：

1. **无法跨 Trigger 通信** - 一个 Trigger 无法通知另一个 Trigger
2. **无法发送自定义事件** - 没有"Send Event"类型的指令
3. **无法监听自定义事件** - 没有"On Receive Event"类型的事件
4. **复杂逻辑需要变通方案** - 用户必须使用节点信号或组信号实现间接通信

### 现有通信模式对比

```
┌─────────────────────────────────────────────────────────────────┐
│                    当前 Fuse 通信模式                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   ✅ 点对点 (OnTargetSignalEmit)                                │
│   ┌─────────┐    signal    ┌─────────┐                         │
│   │ Node A  │ ───────────→ │ Trigger │ → ActionRunner          │
│   └─────────┘              └─────────┘                         │
│                                                                 │
│   ✅ 组监听 (OnSignalFromGroup)                                 │
│   ┌─────────┐                                              │
│   │ Group A │ ──┐                                          │
│   ├─────────┤   │ signal   ┌─────────┐                     │
│   │ Group A │ ──┼────────→ │ Trigger │ → ActionRunner       │
│   ├─────────┤   │          └─────────┘                     │
│   │ Group A │ ──┘                                          │
│   └─────────┘                                              │
│                                                                 │
│   ❌ 缺失模式: 全局事件广播                                      │
│   ┌─────────┐              ┌─────────┐                         │
│   │ Trigger │ ──?──?──?──→ │ Trigger │                         │
│   │    A    │              │    B    │                         │
│   └─────────┘              └─────────┘                         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 为什么需要 Event Bus

| 场景 | 当前方案 | Event Bus 方案 |
|------|----------|----------------|
| 玩家死亡通知 | 需要节点信号转发 | `SendEvent("player_died")` |
| 任务完成触发 | 需要全局变量轮询 | `SendEvent("quest_completed", {id: 1})` |
| 场景状态同步 | 需要复杂信号链 | `SendEvent("scene_ready")` |
| UI 更新通知 | 需要直接引用 | `SendEvent("ui_refresh")` |

---

## 目标

### 核心目标

1. **实现全局事件总线** - 提供跨场景、跨 Trigger 的事件通信机制
2. **提供 SendEvent 指令** - 允许在动作序列中发送自定义事件
3. **提供 OnReceiveEvent 事件** - 允许监听自定义事件并触发动作

### 非目标

- 不替代 Godot 信号系统（仅作为 Fuse 内部通信）
- 不实现网络同步（纯本地事件）
- 不实现事件持久化（运行时内存存储）

---

## 技术方案

### 架构概览

```
┌─────────────────────────────────────────────────────────────────┐
│                    Fuse Event Bus 架构                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │              FuseEventBus (Autoload 单例)              │  │
│   │                                                         │  │
│   │   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │  │
│   │   │ Listener    │  │ Event       │  │ Debug       │    │  │
│   │   │ Registry    │  │ History     │  │ Support     │    │  │
│   │   └─────────────┘  └─────────────┘  └─────────────┘    │  │
│   │                                                         │  │
│   │   API:                                                  │  │
│   │   - send_event(name, args)                             │  │
│   │   - subscribe(name, callback) → Subscription           │  │
│   │   - unsubscribe(subscription)                          │  │
│   │                                                         │  │
│   └─────────────────────────────────────────────────────────┘  │
│                              ▲                                 │
│                              │                                 │
│           ┌──────────────────┼──────────────────┐             │
│           │                  │                  │             │
│   ┌───────┴───────┐  ┌───────┴───────┐  ┌───────┴───────┐    │
│   │ SendEvent     │  │ OnReceiveEvent │  │ WaitEvent     │    │
│   │ Instruction   │  │ Event          │  │ Instruction   │    │
│   │ (Phase 1)     │  │ (Phase 1)      │  │ (Phase 2)     │    │
│   └───────────────┘  └───────────────┘  └───────────────┘    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 文件结构

```
addons/fuse/
├── core/
│   └── fuse_event_bus.gd          # 事件总线核心 (新增)
│
├── events/
│   └── event/
│       └── on_receive_event.gd       # 接收事件 (新增)
│
├── instructions/
│   └── event/
│       ├── send_event.gd             # 发送事件 (新增)
│       └── wait_event.gd             # 等待事件 (Phase 2)
│
└── editor/
    └── event_bus_debugger.gd         # 调试面板 (Phase 2)
```

---

## 核心组件设计

### 1. FuseEventBus (事件总线)

**文件**: `addons/fuse/core/fuse_event_bus.gd`

```gdscript
class_name FuseEventBus extends Node

## 事件发送信号 (用于编辑器调试)
signal event_sent(event_name: String, args: Dictionary)

## 订阅信息类
class Subscription extends RefCounted:
	var event_name: String
	var callback: Callable
	var id: int

## 私有变量
var _listeners: Dictionary = {}  # {event_name: [Subscription, ...]}
var _subscription_counter: int = 0
var _event_history: Array = []
var _max_history_size: int = 100

## 单例访问
static var _instance: FuseEventBus = null

static func get_instance() -> FuseEventBus:
	if _instance == null:
		_instance = FuseEventBus.new()
	return _instance


## 发送事件
func send_event(event_name: String, args: Dictionary = {}) -> void:
	if event_name.is_empty():
		push_warning("FuseEventBus: 事件名称不能为空")
		return

	# 记录历史
	_record_event(event_name, args)

	# 调试信号
	event_sent.emit(event_name, args)

	# 通知所有监听器
	if _listeners.has(event_name):
		var listeners = _listeners[event_name].duplicate()
		for subscription in listeners:
			if subscription.callback.is_valid():
				subscription.callback.call(args)


## 延迟发送事件（帧末尾）
func send_event_deferred(event_name: String, args: Dictionary = {}) -> void:
	call_deferred("send_event", event_name, args)


## 订阅事件
func subscribe(event_name: String, callback: Callable) -> Subscription:
	if not _listeners.has(event_name):
		_listeners[event_name] = []

	var subscription = Subscription.new()
	subscription.event_name = event_name
	subscription.callback = callback
	subscription.id = _subscription_counter
	_subscription_counter += 1

	_listeners[event_name].append(subscription)

	return subscription


## 取消订阅
func unsubscribe(subscription: Subscription) -> void:
	if subscription == null:
		return

	if _listeners.has(subscription.event_name):
		var listeners = _listeners[subscription.event_name]
		var idx = listeners.find(subscription)
		if idx >= 0:
			listeners.remove_at(idx)

		if listeners.is_empty():
			_listeners.erase(subscription.event_name)


## 获取事件历史
func get_event_history() -> Array:
	return _event_history.duplicate()


## 获取活跃监听器数量
func get_listener_count(event_name: String = "") -> int:
	if event_name.is_empty():
		var total = 0
		for key in _listeners:
			total += _listeners[key].size()
		return total
	elif _listeners.has(event_name):
		return _listeners[event_name].size()
	return 0


## 私有方法
func _record_event(event_name: String, args: Dictionary) -> void:
	_event_history.append({
		"name": event_name,
		"args": args.duplicate(),
		"timestamp": Time.get_ticks_msec()
	})

	if _event_history.size() > _max_history_size:
		_event_history.pop_front()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_listeners.clear()
		_instance = null
```

### 2. SendEvent Instruction

**文件**: `addons/fuse/instructions/event/send_event.gd`

```gdscript
@tool
class_name SendEvent extends BaseInstruction

## 事件名称
@export var event_name: String = ""

## 事件参数
@export var event_args: Dictionary = {}

## 是否延迟发送
@export var deferred: bool = false


func _init():
	super._init()
	_instruction_name = "SendEvent"


func execute(context: ExecutionContext) -> void:
	if event_name.is_empty():
		FuseLogger.warning("SendEvent: 事件名称不能为空")
		return

	# 解析参数中的变量引用
	var resolved_args = _resolve_args(context, event_args)

	# 获取事件总线实例
	var bus = FuseEventBus.get_instance()
	if bus == null:
		FuseLogger.error("SendEvent: 无法获取 FuseEventBus 实例")
		return

	# 发送事件
	if deferred:
		bus.send_event_deferred(event_name, resolved_args)
	else:
		bus.send_event(event_name, resolved_args)

	FuseLogger.debug("SendEvent: 发送事件 '%s' 参数: %s" % [event_name, resolved_args])


func _resolve_args(context: ExecutionContext, args: Dictionary) -> Dictionary:
	var resolved = {}
	for key in args:
		var value = args[key]
		# 如果是变量引用格式，从上下文解析
		if value is String and value.begins_with("$"):
			var var_name = value.substr(1)
			resolved[key] = context.get_variable(var_name)
		else:
			resolved[key] = value
	return resolved


func get_config_dict() -> Dictionary:
	var config = super.get_config_dict()
	config["event_name"] = event_name
	config["event_args"] = event_args
	config["deferred"] = deferred
	return config


func load_from_dict(config_dict: Dictionary) -> bool:
	if not super.load_from_dict(config_dict):
		return false

	event_name = config_dict.get("event_name", "")
	event_args = config_dict.get("event_args", {})
	deferred = config_dict.get("deferred", false)
	return true


func validate_instruction() -> String:
	if event_name.is_empty():
		return "事件名称不能为空"
	return ""


static func get_metadata() -> Dictionary:
	return {
		"category": "event",
		"label": "Send Event",
		"description": "发送自定义事件到事件总线",
		"icon": "Signal",
		"color": "#FF9800"
	}
```

### 3. OnReceiveEvent Event

**文件**: `addons/fuse/events/event/on_receive_event.gd`

```gdscript
@tool
class_name OnReceiveEvent extends BaseEvent

## 监听的事件名称
@export var event_name: String = ""

## 是否只触发一次
@export var trigger_once: bool = false

## 事件参数存储到局部变量
@export var store_args_to_local: bool = true

## 局部变量前缀
@export var local_var_prefix: String = "event_"

## 订阅引用
var _subscription: RefCounted = null


func _init():
	super._init()
	_event_name = "OnReceiveEvent"
	resource_name = "On Receive Event"


func _update_resource_name() -> void:
	if event_name.is_empty():
		resource_name = "On Receive Event"
	else:
		resource_name = "On Receive Event: %s" % event_name


func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	super.initialize_with_runtime_instance(owner_node, runtime_instance)

	if event_name.is_empty():
		FuseLogger.warning("OnReceiveEvent: 事件名称为空，无法订阅")
		return

	# 获取事件总线实例
	var bus = FuseEventBus.get_instance()
	if bus == null:
		FuseLogger.error("OnReceiveEvent: 无法获取 FuseEventBus 实例")
		return

	# 订阅事件
	_subscription = bus.subscribe(event_name, _on_event_received.bind(owner_node))
	FuseLogger.debug("OnReceiveEvent: 已订阅事件 '%s'" % event_name)


func terminate(owner_node: Node) -> void:
	# 取消订阅
	if _subscription != null:
		var bus = FuseEventBus.get_instance()
		if bus != null:
			bus.unsubscribe(_subscription)
		_subscription = null
		FuseLogger.debug("OnReceiveEvent: 已取消订阅事件 '%s'" % event_name)

	super.terminate(owner_node)


func _on_event_received(args: Dictionary, owner_node: Node) -> void:
	FuseLogger.debug("OnReceiveEvent: 收到事件 '%s' 参数: %s" % [event_name, args])

	# 将参数存储到运行时状态
	if store_args_to_local and _runtime_instance_ref != null:
		for key in args:
			_runtime_instance_ref.set_runtime_state(local_var_prefix + key, args[key])

	# 触发事件
	_emit_triggered(owner_node, owner_node)

	# 如果只触发一次，取消订阅
	if trigger_once and _subscription != null:
		var bus = FuseEventBus.get_instance()
		if bus != null:
			bus.unsubscribe(_subscription)
		_subscription = null


func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["last_event_args"] = {}
	return base


func get_config_dict() -> Dictionary:
	var config = super.get_config_dict()
	config["event_name"] = event_name
	config["trigger_once"] = trigger_once
	config["store_args_to_local"] = store_args_to_local
	config["local_var_prefix"] = local_var_prefix
	return config


func load_from_dict(config_dict: Dictionary) -> bool:
	if not super.load_from_dict(config_dict):
		return false

	event_name = config_dict.get("event_name", "")
	trigger_once = config_dict.get("trigger_once", false)
	store_args_to_local = config_dict.get("store_args_to_local", true)
	local_var_prefix = config_dict.get("local_var_prefix", "event_")
	return true


func validate_event() -> String:
	if event_name.is_empty():
		return "事件名称不能为空"
	return ""


static func get_metadata() -> Dictionary:
	return {
		"category": "event",
		"label": "On Receive Event",
		"description": "当收到指定事件时触发",
		"icon": "Signal",
		"color": "#FF9800"
	}
```

---

## 执行流程

### SendEvent 执行流程

```
1. ActionRunner 执行 SendEvent 指令
   ↓
2. SendEvent.execute(context)
   ↓
3. _resolve_args() 解析变量引用
   ↓
4. FuseEventBus.get_instance()
   ↓
5. bus.send_event(event_name, args)
   ↓
6. 遍历 _listeners[event_name]
   ↓
7. 调用每个 subscription.callback(args)
```

### OnReceiveEvent 订阅流程

```
1. Trigger._ready()
   ↓
2. RuntimeEventInstance.new(event_definition, trigger)
   ↓
3. event_definition.initialize_with_runtime_instance()
   ↓
4. OnReceiveEvent.initialize_with_runtime_instance()
   ↓
5. FuseEventBus.subscribe(event_name, callback)
   ↓
6. 返回 Subscription 对象，存储在 _subscription
```

### OnReceiveEvent 触发流程

```
1. 其他 Trigger 发送 SendEvent 指令
   ↓
2. FuseEventBus.send_event() 被调用
   ↓
3. 遍历所有订阅者，调用 callback
   ↓
4. OnReceiveEvent._on_event_received(args)
   ↓
5. 存储参数到运行时状态
   ↓
6. _emit_triggered(owner_node)
   ↓
7. RuntimeEventInstance 转发信号
   ↓
8. Trigger._on_event_fired()
   ↓
9. ActionRunner 执行指令序列
```

---

## 变量引用机制

### 概念说明

变量引用是一种**在事件参数中动态获取变量值**的机制。使用 `$变量名` 语法，可以在发送事件时自动从 ExecutionContext 中解析变量值，而不是使用硬编码的固定值。

### 工作原理

```
┌─────────────────────────────────────────────────────────────────┐
│                    变量引用解析流程                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   1. 配置阶段（编辑器）                                          │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │  Event Args:                                            │  │
│   │  {                                                      │  │
│   │    "player_id": "$current_player",    ← 字符串，带$前缀  │  │
│   │    "health": 100,                     ← 固定值          │  │
│   │    "position": "$player_position"     ← 字符串，带$前缀  │  │
│   │  }                                                      │  │
│   └─────────────────────────────────────────────────────────┘  │
│                              ↓                                  │
│   2. 执行阶段（运行时）                                          │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │  SendEvent.execute(context)                             │  │
│   │       ↓                                                 │  │
│   │  _resolve_args(context, event_args)                     │  │
│   │       ↓                                                 │  │
│   │  遍历每个参数:                                           │  │
│   │    - 是 "$xxx" 格式？ → 从 context 获取变量值            │  │
│   │    - 不是               → 直接使用原值                   │  │
│   └─────────────────────────────────────────────────────────┘  │
│                              ↓                                  │
│   3. 最终发送的事件参数                                          │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │  Resolved Args:                                         │  │
│   │  {                                                      │  │
│   │    "player_id": "p1",                 ← 从变量解析       │  │
│   │    "health": 100,                     ← 原值不变         │  │
│   │    "position": Vector2(100, 200)      ← 从变量解析       │  │
│   │  }                                                      │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 解析代码

```gdscript
func _resolve_args(context: ExecutionContext, args: Dictionary) -> Dictionary:
	var resolved = {}
	for key in args:
		var value = args[key]
		# 检查是否是变量引用格式
		if value is String and value.begins_with("$"):
			# 提取变量名（去掉 $ 前缀）
			var var_name = value.substr(1)  # "$player" → "player"
			# 从 ExecutionContext 获取变量值
			resolved[key] = context.get_variable(var_name)
		else:
			# 不是变量引用，直接使用原值
			resolved[key] = value
	return resolved
```

### 变量来源

ExecutionContext 中的变量可以来自多个地方：

| 变量类型 | 来源 | 示例 |
|----------|------|------|
| 全局变量 | GlobalVariableManager | `$global_score` |
| 局部变量 | Trigger 内部定义 | `$local_count` |
| 事件参数 | OnReceiveEvent 接收的参数 | `$event_item_id` |
| 上下文变量 | ExecutionContext 内置 | `$target`, `$owner` |

### 使用场景对比

**没有变量引用时的问题：**

```gdscript
# ❌ 硬编码 - 不灵活
SendEvent: "item_collected" { "item_id": "sword_01" }

# ❌ 只能用固定值 - 无法动态传递
# 需要为每种物品创建不同的 Trigger
```

**有了变量引用后：**

```gdscript
# ✅ 动态获取 - 灵活可配置
SendEvent: "item_collected" { "item_id": "$current_item" }

# 当前物品是什么，就发送什么
# 一个 Trigger 可以处理所有物品类型
```

### 完整数据流示例

```
┌─────────────────┐
│ Trigger A 执行   │
│                 │
│ 局部变量:        │
│  collected_item │
│  _id = "sword_01"│
│                 │
│ 全局变量:        │
│  current_player │
│  = "player_1"   │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────────────────┐
│ SendEvent 解析参数                           │
│                                             │
│ 输入:                                        │
│  {                                          │
│    "item_id": "$collected_item_id",         │
│    "player": "$current_player",             │
│    "count": 1                               │
│  }                                          │
│                                             │
│ 解析过程:                                    │
│  "$collected_item_id" → "sword_01"          │
│  "$current_player"    → "player_1"          │
│  1                    → 1 (不变)             │
│                                             │
│ 输出:                                        │
│  {                                          │
│    "item_id": "sword_01",                   │
│    "player": "player_1",                    │
│    "count": 1                               │
│  }                                          │
└────────┬────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────┐
│ Trigger B 接收                               │
│                                             │
│ OnReceiveEvent 收到参数:                     │
│  {                                          │
│    "item_id": "sword_01",                   │
│    "player": "player_1",                    │
│    "count": 1                               │
│  }                                          │
│                                             │
│ 存储到局部变量 (前缀 event_):                │
│  $event_item_id = "sword_01"                │
│  $event_player = "player_1"                 │
│  $event_count = 1                           │
└─────────────────────────────────────────────┘
```

---

## 与 Godot Autoload 集成

### 插件注册

在 `addons/fuse/plugin.gd` 中添加：

```gdscript
func _enter_tree() -> void:
	# ... 现有代码 ...

	# 注册 Event Bus 为 Autoload
	if not has_autoload("FuseEventBus"):
		add_autoload_singleton("FuseEventBus", "core/fuse_event_bus.gd")


func _exit_tree() -> void:
	# ... 现有代码 ...

	# 移除 Event Bus Autoload
	if has_autoload("FuseEventBus"):
		remove_autoload_singleton("FuseEventBus")
```

### 双模式支持

为了支持单例模式和手动实例化两种方式：

```gdscript
# FuseEventBus.gd
static func get_instance() -> FuseEventBus:
	# 优先使用 Autoload 单例
	if Engine.has_singleton("FuseEventBus"):
		return Engine.get_singleton("FuseEventBus")

	# 回退到手动创建的实例
	if _instance == null:
		_instance = FuseEventBus.new()
	return _instance
```

---

## 本地化支持

### 翻译键

```csv
# addons/fuse/localization/translations.csv
fuse.event.send_event,Send Event,发送事件
fuse.event.send_event.description,Send a custom event to the event bus,发送自定义事件到事件总线
fuse.event.send_event.event_name,Event Name,事件名称
fuse.event.send_event.event_args,Event Arguments,事件参数
fuse.event.send_event.deferred,Deferred,延迟发送

fuse.event.on_receive_event,On Receive Event,接收事件
fuse.event.on_receive_event.description,Trigger when receiving a specific event,收到指定事件时触发
fuse.event.on_receive_event.trigger_once,Trigger Once,只触发一次
fuse.event.on_receive_event.store_args_to_local,Store Args to Local,存储参数到局部变量
fuse.event.on_receive_event.local_var_prefix,Local Variable Prefix,局部变量前缀
```

---

## 使用示例

### 示例 1: 玩家死亡通知

**Trigger A (玩家死亡检测):**
```
Event: OnHealthZero
Actions:
  - SendEvent: "player_died" { "position": $player_position }
```

**Trigger B (游戏结束 UI):**
```
Event: OnReceiveEvent: "player_died"
Actions:
  - ShowGameUI: "game_over"
  - PlaySound: "death_sfx"
```

**Trigger C (敌人停止):**
```
Event: OnReceiveEvent: "player_died"
Actions:
  - StopAllEnemyAI
```

### 示例 2: 任务完成

**Trigger A (任务目标达成):**
```
Event: OnConditionMet (collected_items >= 10)
Actions:
  - SendEvent: "quest_completed" { "quest_id": "collect_10" }
```

**Trigger B (任务系统):**
```
Event: OnReceiveEvent: "quest_completed"
Actions:
  - UpdateQuestStatus: $event_quest_id
  - UnlockNextQuest
  - ShowNotification: "Quest Complete!"
```

### 示例 3: 场景加载完成

**场景管理器:**
```
Event: OnSceneLoaded
Actions:
  - SendEvent: "scene_ready" { "scene_name": $current_scene }
```

**玩家初始化:**
```
Event: OnReceiveEvent: "scene_ready"
Actions:
  - SpawnPlayer: $spawn_point
  - RestorePlayerState
```

---

## 实施计划

### Phase 1: 核心实现 (必须)

**工作量**: 2-3 小时

| 任务 | 文件 | 状态 |
|------|------|------|
| 创建 FuseEventBus 核心 | `core/fuse_event_bus.gd` | 待实现 |
| 创建 SendEvent 指令 | `instructions/event/send_event.gd` | 待实现 |
| 创建 OnReceiveEvent 事件 | `events/event/on_receive_event.gd` | 待实现 |
| 更新 plugin.gd 注册 Autoload | `plugin.gd` | 待实现 |
| 添加本地化翻译键 | `localization/translations.csv` | 待实现 |
| 创建测试场景 | `tests/test_event_bus.tscn` | 待实现 |

### Phase 2: 增强功能 (推荐)

**工作量**: 1-2 小时

| 任务 | 文件 | 状态 |
|------|------|------|
| 创建 WaitEvent 指令 | `instructions/event/wait_event.gd` | 待实现 |
| 创建调试面板 | `editor/event_bus_debugger.gd` | 待实现 |
| 添加事件历史查看器 | - | 待实现 |

### Phase 3: 高级特性 (可选)

**工作量**: 2-3 小时

| 任务 | 描述 | 状态 |
|------|------|------|
| 事件过滤/通配符 | 支持 `player_*` 匹配 | 待设计 |
| 事件优先级 | 支持监听器优先级排序 | 待设计 |
| 条件订阅 | 基于条件的自动订阅/取消订阅 | 待设计 |

---

## 风险评估

| 风险 | 影响 | 概率 | 缓解措施 |
|------|------|------|----------|
| 内存泄漏 | 高 | 中 | 使用 Subscription 对象管理，terminate 时清理 |
| 性能开销 | 中 | 低 | 提供事件队列模式，支持异步批量处理 |
| 事件命名冲突 | 低 | 中 | 建议使用命名空间前缀 `module:event_name` |
| 循环依赖 | 高 | 低 | 文档警告 + 可选最大递归深度限制 |
| 调试困难 | 中 | 中 | 提供事件历史和调试面板 |

---

## 替代方案

### 方案 A: 使用 Godot 信号 + Autoload

**描述**: 创建一个全局节点，使用 Godot 原生信号系统

**优点**:
- 利用 Godot 内置功能
- 性能更好

**缺点**:
- 需要动态创建信号（复杂）
- 无法在编辑器中预览事件列表
- 与 Fuse 系统集成度低

### 方案 B: 使用全局变量轮询

**描述**: 使用全局变量 + OnProcess 检查变化

**优点**:
- 无需新组件
- 实现简单

**缺点**:
- 性能差（每帧检查）
- 不实时
- 代码不直观

### 推荐方案: FuseEventBus

选择 **FuseEventBus** 方案，原因：

1. **与 Fuse 架构一致** - 符合 Event/Instruction 设计模式
2. **易于使用** - 无代码用户可直观理解
3. **可扩展** - 支持后续添加过滤、优先级等功能
4. **可调试** - 提供事件历史查看
5. **参考业界实践** - Game Creator、Unreal Blueprints 都有类似功能

---

## 行业参考

### Game Creator (Unity)

```
Broadcast: 发送全局消息
OnMessage: 监听全局消息
```

### Unreal Blueprints

```
Dispatch Event: 发送事件
Bind Event: 绑定事件监听
```

### Unity Visual Scripting

```
Trigger Custom Event: 触发自定义事件
On Custom Event: 监听自定义事件
```

---

## 验收标准

### 功能验收

- [ ] `SendEvent` 指令可以发送自定义事件
- [ ] `OnReceiveEvent` 事件可以接收自定义事件
- [ ] 事件参数可以正确传递
- [ ] 变量引用 (`$var`) 可以正确解析
- [ ] `trigger_once` 选项可以正常工作
- [ ] 组件生命周期正确管理（initialize/terminate）

### 性能验收

- [ ] 100 个监听器的发送延迟 < 1ms
- [ ] 内存使用正常，无泄漏

### 兼容性验收

- [ ] 与现有 Event/Instruction 系统兼容
- [ ] 支持本地化
- [ ] 支持序列化/反序列化

---

## 总结

Fuse Event Bus 系统是一个**高价值、低成本**的功能增强：

- **填补功能空白** - 实现跨 Trigger 通信
- **符合无代码理念** - 直观的事件驱动模型
- **架构自然扩展** - 与现有体系完美契合
- **实现成本低** - 核心功能只需 3 个文件

**建议优先实现 Phase 1 核心功能**，后续根据用户反馈逐步增强。

---

**文档版本**: 1.0
**最后更新**: 2026-02-27
