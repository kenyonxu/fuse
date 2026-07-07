# FuseEventBus 事件总线开发指南

> **目标**: 为开发者提供 FuseEventBus 全局事件通信机制的完整开发指引，包括事件发送、订阅、取消订阅和编辑器调试。

**适用对象**: Fuse 系统开发者、贡献者

**最后更新**: 2026-07-07

---

## 📋 目录

1. [系统概述](#系统概述)
2. [架构设计](#架构设计)
3. [FuseEventBus API](#fuseeventbus-api)
4. [Subscription 类](#subscription-类)
5. [集成组件](#集成组件)
6. [使用指南](#使用指南)
7. [调试支持](#调试支持)
8. [最佳实践](#最佳实践)
9. [常见陷阱](#常见陷阱)

---

## 系统概述

`FuseEventBus` 是 Fuse 中的全局事件通信机制，允许不同的 Trigger 之间通过自定义事件进行解耦通信。它通过 Autoload 注册为全局单例，可在任何地方通过 `FuseEventBus` 直接访问。

> **Autoload 单例约定**
> `FuseEventBus` 通过 Autoload 注册为全局单例（无 `class_name`），只能用 Autoload 名 `FuseEventBus` 直接访问。
> - ✅ `FuseEventBus.send_event("event_name", {})`
> - ❌ ~~`FuseEventBus.new()`~~（没有 `class_name`，无法实例化）
> - 订阅事件时返回的 `Subscription` 对象仅用于取消订阅，无需额外实例化。

### 核心文件

| 文件 | 类名 | 用途 |
|------|------|------|
| `core/fuse_event_bus.gd` | `FuseEventBus extends Node` | 事件总线（Autoload 单例） |

### 相关组件

| 文件 | 类型 | 用途 |
|------|------|------|
| `instructions/event/send_event.gd` | 指令 | 发送自定义事件 |
| `events/event/on_receive_event.gd` | 事件 | 接收自定义事件 |
| `tests/test_event_bus.gd` | 测试 | 事件总线测试 |

### 设计目标

- **全局可访问**: 通过 Autoload 注册，无需手动传递引用
- **解耦通信**: 发布者无需知道订阅者的存在
- **调试友好**: 提供事件历史记录和 `event_sent` 信号供编辑器调试
- **延迟发送**: 支持 `call_deferred` 在当前帧末尾发送事件
- **自动清理**: `NOTIFICATION_PREDELETE` 时清理所有监听器

---

## 架构设计

```
发送方 (Trigger / 指令 / GDScript)
        │
        │ FuseEventBus.send_event("event_name", {args})
        ▼
┌─────────────────────────────────────┐
│          FuseEventBus               │
│   (Autoload Node 单例)              │
│                                     │
│  _listeners: Dictionary             │
│  {event_name → [Subscription...]}   │
│                                     │
│  _event_history: Array[max 100]     │
│  {name, args, timestamp}            │
│                                     │
│  signal: event_sent(name, args)     │
└─────────────────────────────────────┘
        │
        ├─→ 通知所有订阅者 callback(args)
        │
        └─→ 记录到事件历史
                │
                ▼
        编辑器调试工具 (VariableWatcher 等)
```

### 消息流

```
send_event("player_died", {"enemy": "boss"})
    │
    ├── _record_event("player_died", {"enemy": "boss"})
    │       → _event_history.append({name, args, timestamp})
    │       → 超出 MAX_HISTORY_SIZE(100) → pop_front()
    │
    ├── event_sent.emit("player_died", {"enemy": "boss"})
    │       → 编辑器调试工具监听此信号
    │
    └── _listeners["player_died"] 遍历
            → subscription.callback.call({"enemy": "boss"})
            → 跳过 callback.is_valid() == false 的回调
```

---

## FuseEventBus API

**文件位置**: `addons/fuse/core/fuse_event_bus.gd`

**类定义**:
```gdscript
extends Node  # 通过 Autoload 注册为全局单例
```

### 常量

```gdscript
const MAX_HISTORY_SIZE: int = 100  # 最大历史记录数量
```

### 信号

```gdscript
## 事件发送信号（用于编辑器调试）
signal event_sent(event_name: String, args: Dictionary)
```

### 核心方法

```gdscript
## 发送事件
## event_name: 事件名称（不能为空）
## args: 事件参数（可选，默认 {}）
func send_event(event_name: String, args: Dictionary = {}) -> void

## 延迟发送事件（在当前帧末尾发送）
## event_name: 事件名称
## args: 事件参数（可选）
func send_event_deferred(event_name: String, args: Dictionary = {}) -> void

## 订阅事件
## event_name: 要监听的事件名称
## callback: 回调函数，接收 Dictionary 参数
## 返回: Subscription — 用于取消订阅
func subscribe(event_name: String, callback: Callable) -> Subscription

## 取消订阅
## subscription: 要取消的订阅对象
func unsubscribe(subscription: Subscription) -> void
```

### 查询方法

```gdscript
## 检查事件是否有监听器
func has_listeners(event_name: String) -> bool

## 获取事件监听器数量
## event_name: 空字符串表示获取总数
func get_listener_count(event_name: String = "") -> int

## 获取所有已注册的事件名称
func get_registered_events() -> Array[String]

## 获取事件历史记录
func get_event_history() -> Array

## 清除事件历史
func clear_history() -> void

## 清理所有监听器
func clear_all_listeners() -> void
```

### 生命周期

```gdscript
func _ready() -> void:
    # 注册运行时反射缓存自动清理
    get_tree().node_removed.connect(_on_node_removed_for_reflection_cache)

func _on_node_removed_for_reflection_cache(node: Node) -> void:
    # 节点移除时自动清理 ReflectionCache 和 FunctionManager
    ReflectionCache.get_instance().clear_node(node)
    FunctionManager.clear_callable_cache(node)

func _notification(what: int) -> void:
    if what == NOTIFICATION_PREDELETE:
        _listeners.clear()
```

### 内部方法

```gdscript
func _record_event(event_name: String, args: Dictionary) -> void
    # 记录事件到历史，超出 MAX_HISTORY_SIZE 时 pop_front()
```

---

## Subscription 类

```gdscript
class Subscription extends RefCounted:
    var event_name: String
    var callback: Callable
    var id: int
    var paused: bool                ## 暂停状态：为 true 时事件发送不会触发此订阅的回调
```

`Subscription` 是一个简单的数据类，包含事件名称、回调函数、唯一 ID 和暂停状态。通过 `unsubscribe(subscription)` 取消订阅。将 `paused` 设为 `true` 可临时禁用该订阅而不移除它。

---

## 集成组件

### SendEvent 指令

**文件位置**: `addons/fuse/instructions/event/send_event.gd`

```gdscript
# 在指令执行中：
FuseEventBus.send_event(event_name, event_args)
```

### OnReceiveEvent 事件

**文件位置**: `addons/fuse/events/event/on_receive_event.gd`

```gdscript
# 在事件初始化时：
FuseEventBus.subscribe(event_name, _on_event_received)
```

---

## 使用指南

### 发送事件

```gdscript
# 基本发送
FuseEventBus.send_event("boss_defeated", {"boss_name": "Dragon"})

# 延迟发送（当前帧末尾）
FuseEventBus.send_event_deferred("scene_loaded", {"scene_name": "level2"})

# 无参数的事件
FuseEventBus.send_event("game_started")
```

### 订阅事件

```gdscript
var subscription = FuseEventBus.subscribe("boss_defeated", _on_boss_defeated)

func _on_boss_defeated(args: Dictionary) -> void:
    var boss_name = args.get("boss_name", "unknown")
    print("Boss defeated: %s" % boss_name)
```

### 取消订阅

```gdscript
FuseEventBus.unsubscribe(subscription)
subscription = null  # 释放引用
```

### 查询与调试

```gdscript
# 检查是否有监听者
if FuseEventBus.has_listeners("boss_defeated"):
    print("有触发器在监听 boss_defeated 事件")

# 获取监听器数量
var total = FuseEventBus.get_listener_count()  # 总数
var per_event = FuseEventBus.get_listener_count("boss_defeated")  # 指定事件

# 列出已注册事件
print(FuseEventBus.get_registered_events())

# 获取历史
var history = FuseEventBus.get_event_history()
for entry in history:
    print("%s: %s at %d" % [entry.name, entry.args, entry.timestamp])
```

---

## 调试支持

FuseEventBus 为编辑器调试提供了两个层次的接口：

### 1. event_sent 信号

```gdscript
# 在编辑器中连接此信号即可实时监控事件
FuseEventBus.event_sent.connect(_on_event_sent)

func _on_event_sent(event_name: String, args: Dictionary) -> void:
    print("[EventBus] %s → %s" % [event_name, JSON.stringify(args)])
```

### 2. 事件历史

```gdscript
# 通过 get_event_history() 获取最近 100 条事件记录
var history = FuseEventBus.get_event_history()
for entry in history:
    var timestamp = entry.timestamp  # Time.get_ticks_msec()
    var name = entry.name
    var args = entry.args
```

### 3. VariableWatcher 集成

事件总线在 `_ready()` 中自动连接 `node_removed` 信号，当场景中的节点被移除时，自动清理 `ReflectionCache` 和 `FunctionManager` 中该节点的缓存。

---

## 最佳实践

### 1. 事件命名规范

使用 `snake_case` 命名事件，前缀按系统分组：

```gdscript
FuseEventBus.send_event("player_died")        # 玩家相关
FuseEventBus.send_event("scene_loaded")       # 场景相关
FuseEventBus.send_event("ui_button_clicked")  # UI 相关
FuseEventBus.send_event("game_saved")         # 游戏流程相关
```

### 2. 参数约定

```gdscript
# 事件参数使用 Dictionary，明确键名
FuseEventBus.send_event("player_scored", {
    "points": 100,
    "enemy_type": "goblin",
    "combo_count": 5
})
```

### 3. 延迟发送避免死锁

在物理回调（`_physics_process`）中发送事件时，使用延迟发送避免当前帧的事件循环问题：

```gdscript
func _physics_process(delta):
    if detect_collision():
        FuseEventBus.send_event_deferred("player_hit", {"damage": 10})
```

### 4. 及时取消订阅

场景切换或节点释放时取消不需要的订阅：

```gdscript
func _exit_tree():
    if _subscription:
        FuseEventBus.unsubscribe(_subscription)
        _subscription = null
```

### 5. 使用 clear_all_listeners 的场景切换

```gdscript
func _on_scene_changed():
    # 场景切换时清理所有监听器
    FuseEventBus.clear_all_listeners()
```

---

## 常见陷阱

### 陷阱 1：订阅回调引用失效

**问题**: 如果回调对象已被释放，但 `Callback.is_valid()` 仍返回 true。

**解决方案**: FuseEventBus 在遍历时检查 `callback.is_valid()`，无效的回调自动跳过。但创建回调时建议使用对象的弱引用或确保生命周期管理。

### 陷阱 2：忘记取消订阅导致内存泄漏

**问题**: 节点释放后仍保留 subscription 引用，回调继续被调用。

**解决方案**: 在节点的 `_exit_tree()` 或 `_notification(NOTIFICATION_PREDELETE)` 中取消订阅。

### 陷阱 3：事件名称大小写敏感

`send_event("PlayerDied")` 和 `send_event("player_died")` 是两个不同的事件。保持命名一致。

### 陷阱 4：参数修改影响历史

`send_event` 中使用 `args.duplicate()` 记录历史，但回调接收的是**原始引用**。如果后续修改传入的 Dictionary，回调中看到的是修改后的值。

**解决方案**: 如果 args 会在发送后被修改，使用 `args.duplicate()` 创建副本。

### 陷阱 5：MAX_HISTORY_SIZE 溢出

当事件发送频繁时（每帧发送），历史记录只保留最近 100 条。基于时间戳的过滤应在外部实现。

---

## 参考文档

- [RuntimeBridge 开发指南](runtime_bridge_guide.md)
- [ExecutionContext 与 Diagnostics 指南](execution_context_diagnostics_guide.md)
- [FuseLogger 日志系统指南](fuse_logger_guide.md)
- [事件创建指南](event_creation_guide.md)

---

**文档维护**: Fuse 开发团队 | **最后更新**: 2026-07-07 | **Godot 版本**: 4.7
