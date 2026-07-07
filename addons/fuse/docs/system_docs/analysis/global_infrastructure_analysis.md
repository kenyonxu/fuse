# 全局基础设施分析报告（FuseEventBus / FuseRuntimeBridge）

## 文档概述

本报告对 Fuse 顶层的两个全局 Autoload 单例节点进行了全面分析：

- **`FuseEventBus`** —— 全局事件通信中枢，提供跨 Trigger 的自定义事件订阅/发布。
- **`FuseRuntimeBridge`** —— 运行时变量 TCP 桥，在编辑器进程与运行游戏进程之间传输 Runner 的 local/scope 变量快照，供编辑器侧变量监视器（`FuseVariableWatcher`）实时显示。

两者均为 `extends Node` 的 Autoload 单例，由插件启用时通过 `FuseRuntimeBootstrap` 动态注册到 `project.godot`，插件禁用时反注册。两者**互不直接调用**，分属两条独立子系统（事件通信 / 调试反射）。

**源文件：**
- [`addons/fuse/core/fuse_event_bus.gd`](../../../core/fuse_event_bus.gd)（216 行）
- [`addons/fuse/core/fuse_runtime_bridge.gd`](../../../core/fuse_runtime_bridge.gd)（199 行）
- [`addons/fuse/editor/bootstrap/fuse_runtime_bootstrap.gd`](../../../editor/bootstrap/fuse_runtime_bootstrap.gd)（注册引导）

**基类：** Node（两者均是）
**注册方式：** Autoload 单例（`project.godot` 的 `[autoload]` 段，前缀 `*` 表示启用）

---

## 1. Autoload 单例机制

### 1.1 注册位置

`project.godot`（[第 26–29 行](../../../../../project.godot)）：

```ini
[autoload]

FuseEventBus="*uid://ptmsqnuut75p"
FuseRuntimeBridge="*uid://c6iequlsnctd7"
```

要点：
- 以 **UID** 形式注册（Godot 4.4+），路径解析稳定，不依赖相对路径。
- 前缀 `*` 表示单例**启用**（去掉 `*` 即禁用但保留条目）。
- 注册名 `FuseEventBus` / `FuseRuntimeBridge` 即全局访问名。

### 1.2 注册引导（FuseRuntimeBootstrap）

注册不是手动写入 `project.godot`，而是由 `EditorPlugin` 在插件启用/禁用时调用 `add_autoload_singleton` / `remove_autoload_singleton` 动态完成（[fuse_runtime_bootstrap.gd:16-24](../../../editor/bootstrap/fuse_runtime_bootstrap.gd)）：

```gdscript
func setup() -> void:
    _register_event_bus()
    _register_reflection_cache_cleanup()
    _register_runtime_bridge()

func teardown() -> void:
    _unregister_runtime_bridge()
    _unregister_reflection_cache_cleanup()
    _unregister_event_bus()
```

每个 `_register_*` 都先查 `ProjectSettings.get_setting("autoload", {})` 避免重复注册；`_unregister_*` 对称清理。这种"插件托管注册/注销"模式让用户拉入/移除插件时无需手动改 `project.godot`。

### 1.3 全局访问方式

由于 `FuseEventBus` / `FuseRuntimeBridge` 是 Autoload，理论上可直接以名称访问。但消费方代码（`SendEvent`、`OnReceiveEvent`、`FuseVariableWatcher`）出于**降级安全**考虑，统一采用显式 `get_node_or_null` 路径，避免 Autoload 未注册时硬崩溃：

```gdscript
# SendEvent / OnReceiveEvent 的写法
var bus: Node = Engine.get_main_loop().root.get_node_or_null("FuseEventBus")

# FuseVariableWatcher 的写法
var bridge = get_tree().root.get_node_or_null("FuseRuntimeBridge")
if bridge == null or not bridge.has_method("get_cached_vars"):
    return result   # 安全降级
```

### 1.4 生命周期

| 阶段 | 触发 | 行为 |
|------|------|------|
| 插件启用 / 项目加载 | `EditorPlugin._enter_tree()` → `FuseRuntimeBootstrap.setup()` | 写入 `project.godot` autoload |
| 主循环启动 | Godot SceneTree 创建 autoload 节点 | 挂载到 `/root/FuseEventBus`、`/root/FuseRuntimeBridge`，触发 `_ready()` |
| 运行结束 | 节点删除通知 `NOTIFICATION_PREDELETE` | `FuseEventBus._notification` 清空 `_listeners` |
| 退出树 | `_exit_tree()` | `FuseRuntimeBridge` 关闭 TCP server/client、清缓存 |
| 插件禁用 | `EditorPlugin._exit_tree()` → `teardown()` | 从 `project.godot` 移除 autoload 条目 |

> **重要**：Autoload 节点在**编辑器进程**和**运行游戏进程**里**各自独立存在一份**。`FuseRuntimeBridge` 正是利用这一点，在两个进程里以不同模式运行（详见 §5）。

### 1.5 为何用 Autoload 而非 Resource 单例

| 维度 | Autoload Node | Resource 单例（static var + load） |
|------|---------------|------------------------------------|
| 生命周期钩子 | `_ready` / `_process` / `_exit_tree` / `_notification` | 无（需手动 init/cleanup） |
| 信号 | 原生 `signal` | Resource 也可声明，但需主动 emit 入口 |
| 跨场景持久 | 自带 | 自带 |
| 跨进程实例 | 编辑器/运行各一份 | 同 |
| 网络定时器 | `_process` 直接驱动 | 需外部 driver |
| `Engine.is_editor_hint()` 双模式 | 同一脚本可在两个进程表现不同 | 同 |

`FuseEventBus` 需要监听 `SceneTree.node_removed`（清理反射缓存），`FuseRuntimeBridge` 需要 `_process` 推进 TCP 轮询与定时快照推送——两者都强依赖 Node 生命周期，因此 Autoload 是必然选择。

---

## 2. FuseEventBus —— 全局事件总线

### 2.1 类概述与职责

`FuseEventBus` 是 Fuse 自定义事件的**全局发布订阅中枢**，解决"不同 Trigger 之间如何通信"的问题。它独立于 `BaseEvent.triggered` / `BaseTrigger` 的 Trigger 内部信号链路，提供**字符串事件名 + Dictionary 参数**的轻量通信通道。

**核心职责：**
1. **订阅管理**：维护 `{event_name: [Subscription, ...]}` 字典
2. **事件分发**：`send_event()` 同步通知所有订阅者
3. **延迟发送**：`send_event_deferred()` 帧末尾发送
4. **历史记录**：保留最近 100 条事件，供调试器/编辑器查看
5. **反射缓存清理**：`_ready` 时挂 `node_removed`，节点删除时清 `ReflectionCache` / `FunctionManager` 缓存

### 2.2 信号

| 信号 | 参数 | 用途 |
|------|------|------|
| `event_sent` | `(event_name: String, args: Dictionary)` | 每次发送事件时同步 emit，**仅供编辑器调试**观察事件流（见 [fuse_event_bus.gd:14](../../../core/fuse_event_bus.gd)） |

### 2.3 内部类与常量

```gdscript
class Subscription extends RefCounted:
    var event_name: String
    var callback: Callable
    var id: int

const MAX_HISTORY_SIZE: int = 100
```

`Subscription` 是 `RefCounted`，`subscribe()` 返回它，`unsubscribe()` 凭引用移除——**禁止**仅靠 `id` 或回调函数对象判等。

### 2.4 实例属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `_listeners` | Dictionary | `{event_name(String) : Array[Subscription]}`，订阅表 |
| `_subscription_counter` | int | 单调递增的订阅 id |
| `_event_history` | Array | 最近事件记录，每项 `{name, args, timestamp}` |

### 2.5 核心 API

#### `send_event(event_name: String, args: Dictionary = {}) -> void` —— 同步发送

执行流程（[fuse_event_bus.gd:51-67](../../../core/fuse_event_bus.gd)）：
1. 空名警告并返回
2. `_record_event()` 写历史
3. `event_sent.emit()` 发调试信号
4. `duplicate()` 监听器列表（避免迭代中订阅/取消订阅修改原数组）
5. 遍历调用，`callback.is_valid()` 校验后 `callback.call(args)`

> **注**：发送是**同步阻塞**的，订阅者回调内的逻辑会阻塞发送方。

#### `send_event_deferred(event_name, args = {}) -> void` —— 延迟发送

```gdscript
call_deferred("send_event", event_name, args)
```

帧末尾发送，避免同帧内事件链式触发产生长调用栈。

#### `subscribe(event_name: String, callback: Callable) -> Subscription`

- 空名警告返回 null
- 自动创建 `_listeners[event_name]` 数组
- 返回新建的 `Subscription`（带唯一 id）

#### `unsubscribe(subscription: Subscription) -> void`

- null 检查
- `find()` 在订阅数组中按引用定位 → `remove_at()`
- 数组变空时 `erase` 掉整个事件名键

#### 查询 API

| 方法 | 返回 | 说明 |
|------|------|------|
| `has_listeners(event_name)` | bool | 该事件是否有订阅者 |
| `get_listener_count(event_name="")` | int | 单事件或全部订阅数 |
| `get_registered_events()` | Array[String] | 已订阅事件名清单 |
| `get_event_history()` | Array | 历史记录副本（避免外部修改） |
| `clear_history()` / `clear_all_listeners()` | void | 清理 |

### 2.6 历史记录

```gdscript
func _record_event(event_name, args) -> void:
    _event_history.append({
        "name": event_name,
        "args": args.duplicate(),       # 深拷贝，避免外部后续修改
        "timestamp": Time.get_ticks_msec()
    })
    if _event_history.size() > MAX_HISTORY_SIZE:
        _event_history.pop_front()       # FIFO，限 100 条
```

### 2.7 反射缓存清理（与事件总线无直接关系）

`_ready()` 里挂了一个**与事件通信无关**的副作用（[fuse_event_bus.gd:34-41](../../../core/fuse_event_bus.gd)）：

```gdscript
func _ready() -> void:
    if get_tree():
        get_tree().node_removed.connect(_on_node_removed_for_reflection_cache)

func _on_node_removed_for_reflection_cache(node: Node) -> void:
    ReflectionCache.get_instance().clear_node(node)
    FunctionManager.clear_callable_cache(node)
```

节点删除时清掉反射/可调用缓存，避免悬挂指针。

> **注（待确认）**：`FuseRuntimeBootstrap._register_reflection_cache_cleanup()` **也**连接了一次 `tree.node_removed`（[fuse_runtime_bootstrap.gd:44-48](../../../editor/bootstrap/fuse_runtime_bootstrap.gd)），回调体与 `FuseEventBus._on_node_removed_for_reflection_cache` **完全相同**。在编辑器进程里，**同一节点的 `node_removed` 信号会被触发两次**——一次来自 bootstrap（仅在编辑器，因为 `EditorPlugin` 才存在），一次来自 autoload（编辑器和运行游戏都有）。两次清理彼此幂等（`clear_*` 容错），不会出错，但属于轻度冗余，疑似 bootstrap 同时兼负"运行游戏侧兜底"职责的历史遗留。如需精简，可由运行游戏侧的某处统一接管。

### 2.8 清理钩子

```gdscript
func _notification(what: int) -> void:
    if what == NOTIFICATION_PREDELETE:
        _listeners.clear()
```

`PREDELETE` 在对象被释放前到达，此时清空订阅表，避免后续回调访问已失效对象。

---

## 3. FuseEventBus 与 SendEvent / OnReceiveEvent 的协作

这是事件总线的主要消费链路，构成"跨 Trigger 通信"。

### 3.1 SendEvent 指令（发送方）

[send_event.gd:76-122](../../../instructions/event/send_event.gd)：

```gdscript
func execute(context: ExecutionContext) -> void:
    # 1. 验证
    if event_name.is_empty():
        set_error_localized("FUSE_ERROR_EVENT_NAME_EMPTY", ...)
        finished.emit(); return

    # 2. 解析 $variable_name 引用
    var resolved_args := _resolve_args(context, event_args)

    # 3. 通过 Autoload 访问（降级安全）
    var bus: Node = Engine.get_main_loop().root.get_node_or_null("FuseEventBus")
    if bus == null:
        set_error_localized("FUSE_ERROR_EVENT_BUS_NOT_FOUND", ...)
        finished.emit(); return

    # 4. 发送（同步或延迟）
    if deferred:
        bus.send_event_deferred(event_name, resolved_args)
    else:
        bus.send_event(event_name, resolved_args)

    _on_execution_completed()
```

`@export` 选项：
- `event_name: String`
- `event_args: Dictionary` —— 支持 `"$variable_name"` 字符串引用，执行时由 `context.get_variable()` 解析
- `deferred: bool` —— 选择 `send_event` 或 `send_event_deferred`

### 3.2 OnReceiveEvent 事件（接收方）

[on_receive_event.gd](../../../events/event/on_receive_event.gd)：

`@export` 选项：
- `event_name: String` —— 监听的事件名
- `trigger_once: bool` —— 触发一次后自动 unsubscribe
- `store_args_to_local: bool` —— 是否把参数存入 RuntimeEventInstance 状态
- `local_var_prefix: String` —— 存储时变量名前缀（默认 `event_`）

**初始化（订阅）**：[on_receive_event.gd:143-153](../../../events/event/on_receive_event.gd)

```gdscript
func _subscribe_to_event(owner_node: Node) -> void:
    var bus: Node = Engine.get_main_loop().root.get_node_or_null("FuseEventBus")
    if bus == null:
        _create_fuse_error_localized("FUSE_ERROR_EVENT_BUS_NOT_FOUND", ...)
        return
    _subscription = bus.subscribe(event_name, _on_event_received.bind(owner_node))
```

注意 `.bind(owner_node)` 把 Trigger 节点作为额外参数绑定进 Callable——回调签名是 `(args, owner_node)`。

**回调（接收）**：[on_receive_event.gd:177-256](../../../events/event/on_receive_event.gd)
1. `trigger_once` 检查（状态优先看 RuntimeEventInstance，回退到 `_has_triggered`）
2. 标记已触发（同步写 RuntimeEventInstance）
3. `store_args_to_local` 时把每个参数以 `local_var_prefix + key` 写入运行时状态，并保存完整 `last_event_args`
4. `update_trigger_stats()`
5. 创建临时 `Node` 作为上下文载体，set_meta `event_name` / `event_args` / `trigger`，`triggered.emit(context_node)` 后 `queue_free()`
6. `trigger_once` 时立即 unsubscribe

**清理（退订）**：`terminate()` 通过 `_subscription` 引用 unsubscribe。

### 3.3 数据流

```
[Trigger A 的指令链]              [FuseEventBus Autoload]              [Trigger B 的事件订阅]
   SendEvent.execute(ec)
     │ bus.send_event(name, args)
     ▼
     _record_event + event_sent.emit
     │
     ▼ 遍历 _listeners[name]
     │ Subscription(B).callback.call(args)
     ▼                                   ────►    OnReceiveEvent._on_event_received(args, owner=B)
                                                                 │
                                                                 ▼ 存状态 + update_stats
                                                                 ▼ triggered.emit(ctx_node)
                                                                 ▼
                                                          RuntimeEventInstance → Trigger → ActionRunner
```

### 3.4 与 BaseEvent 内部信号的区别

| 维度 | BaseEvent.triggered（Trigger 局部） | FuseEventBus（全局） |
|------|-------------------------------------|----------------------|
| 作用域 | 单个 Trigger 持有的 Event 资源 | 全局，跨 Trigger |
| 触发源 | 子类内部（如 OnBodyEntered 监听 Area2D 信号） | 显式 `SendEvent` 指令或脚本调用 |
| 上下文 | `Node` + `trigger` meta 标识归属 | 字符串事件名 + Dictionary 参数 |
| 路由 | RuntimeEventInstance 中转过滤 | `_listeners` 字典直接分发 |
| 典型场景 | 节点信号、动画、物理 | 用户自定义跨模块通信 |

OnReceiveEvent **桥接两者**：对外消费 FuseEventBus，对内仍走 BaseEvent.triggered 链路。

---

## 4. FuseRuntimeBridge —— 运行时变量 TCP 桥

### 4.1 类概述与职责

`FuseRuntimeBridge` 是**双模式 Autoload**：同一个脚本在编辑器进程和运行游戏进程里**执行不同分支**，通过本机 TCP（`127.0.0.1:24563`）建立通信通道，把运行游戏的 Runner 变量快照推送到编辑器，供变量监视器实时显示。

**为什么需要 TCP 桥**：Godot 的内置调试协议（`EngineDebugger`）在 GDScript 侧不可直接调用，且编辑器进程与运行游戏进程内存隔离，RefCounted / Object 跨进程不可达。详见历史方案调研 [`docs/archive/roadmap/2026-06-27-runtime-variable-access-research.md`](../../archive/roadmap/2026-06-27-runtime-variable-access-research.md)（"运行游戏→编辑器：推送扁平快照"是唯一可行路径）。

### 4.2 常量与协议

```gdscript
const BRIDGE_PORT := 24563
const PUSH_INTERVAL := 0.5
```

**协议**：TCP 流 + JSON line（`\n` 分隔）。每条消息一行 JSON：

```
运行游戏 → 编辑器:
  {"t":"vars","runners":[
      {"name":"Runner1","local":{...},"scope":{...}},
      {"name":"Runner2","local":{...},"scope":{...}}
  ]}
```

`local` / `scope` 均为**扁平 Dictionary**（变量名 → 值），由 `VariableContext.get_all_local_variables_snapshot()` / `get_all_scope_variables_snapshot()` 产出（详见 [variable_context.gd:374-383](../../../core/base/variable_context.gd)）。

### 4.3 实例属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `_server` | TCPServer | 编辑器侧监听实例（运行游戏侧为 null） |
| `_connections` | Array[StreamPeerTCP] | 编辑器侧所有接入的运行游戏连接 |
| `_client` | StreamPeerTCP | 运行游戏侧到编辑器的客户端连接（编辑器侧为 null） |
| `_cached` | Dictionary | 编辑器侧缓存：`{runner_name: {"local":{...}, "scope":{...}}}` |
| `_push_acc` | float | 运行游戏侧推送计时累加器 |
| `_read_buffers` | Dictionary | `{conn.get_instance_id() : String}`，TCP 读缓冲，处理粘包/半包 |

### 4.4 双模式生命周期

```gdscript
func _ready() -> void:
    if Engine.is_editor_hint():
        _start_server()        # 编辑器侧：开 TCPServer
    else:
        _connect_client()      # 运行游戏侧：连 TCP 客户端

func _process(delta: float) -> void:
    if Engine.is_editor_hint():
        if _server:
            _server_poll()     # 编辑器侧：accept + 读 JSON line
    else:
        if _client:
            _client_poll(delta)  # 运行游戏侧：节流推送

func _exit_tree() -> void:
    # 关 server、断所有 connections、断 client、清缓存
```

> 同一脚本通过 `Engine.is_editor_hint()` 分流——这是 Autoload 双模式的标准用法。

### 4.5 编辑器侧（TCPServer 模式）

#### 监听启动

```gdscript
func _start_server() -> void:
    _server = TCPServer.new()
    var err := _server.listen(BRIDGE_PORT, "127.0.0.1")
    if err != OK:
        push_warning("FuseRuntimeBridge: 监听 %d 失败(%d)..." % [BRIDGE_PORT, err])
```

监听失败不致命，仅 `push_warning`——桥不可用时编辑器侧 `get_cached_vars()` 返回空字典，监视器显示空。

#### 轮询逻辑 `_server_poll()`

每帧执行（[fuse_runtime_bridge.gd:78-101](../../../core/fuse_runtime_bridge.gd)）：
1. `take_connection()` 接受所有待接入连接，存入 `_connections`
2. 遍历 `_connections`：
   - `conn.poll()`（**关键**：注释明确指出"poll 后 get_status 准确，断开连接能被清除，避免 !is_open 报错刷屏卡死"）
   - 状态为 `STATUS_NONE` / `STATUS_ERROR` 时断开、清缓冲、`remove_at`，**不递增 i**（continue）
   - 否则 `_read_json_lines(conn)`，`i += 1`
3. 所有连接断开 → `_cached.clear()`（运行游戏已退出）

#### 粘包处理 `_read_json_lines()`

[第 104–124 行](../../../core/fuse_runtime_bridge.gd)：
1. `get_utf8_string(avail)` 读取全部可用字节
2. 累加到 `_read_buffers[cid]`（每条连接独立缓冲）
3. 循环 `find("\n")`，按行切分；每行 `JSON.parse_string`
4. 解析结果是 `Dictionary` 且含 `runners` 键 → `_update_cache()`

#### 缓存更新 `_update_cache()`

```gdscript
for r in runners:
    var rname: String = r.get("name", "?")
    var local_data: Dictionary = r.get("local", {})
    var scope_data: Dictionary = r.get("scope", {})
    _cached[rname] = {"local": local_data.duplicate(), "scope": scope_data.duplicate()}
```

每次推送**整体覆盖** `_cached`（不增量），保证运行游戏退出/Runner 消失后旧数据被清掉。

#### 公开 API `get_cached_vars() -> Dictionary`

编辑器侧变量监视器（`FuseVariableWatcher`）的入口：

```gdscript
# variable_watcher.gd:331-336
var bridge = get_tree().root.get_node_or_null("FuseRuntimeBridge")
if bridge == null or not bridge.has_method("get_cached_vars"):
    return result
var cached: Dictionary = bridge.get_cached_vars()
```

### 4.6 运行游戏侧（TCP 客户端模式）

#### 连接建立

```gdscript
func _connect_client() -> void:
    if _client:
        _client.disconnect_from_host()
        _client = null
    _client = StreamPeerTCP.new()
    _client.connect_to_host("127.0.0.1", BRIDGE_PORT)
```

非阻塞连接；若编辑器未启动则连接进入 `STATUS_CONNECTING`，由后续 `_client_poll` 重试。

#### 节流轮询 `_client_poll(delta)`

[第 155–168 行](../../../core/fuse_runtime_bridge.gd)：

```gdscript
_push_acc += delta
if _push_acc < PUSH_INTERVAL:    # 0.5s 节流
    return
_push_acc = 0.0
_client.poll()
var st := _client.get_status()
if st == STATUS_NONE or STATUS_ERROR:
    _connect_client()            # 重连
    return
if st != STATUS_CONNECTED:
    return
_push_snapshot()
```

**节流理由**（注释）：避免每帧 poll 阻塞主线程。

#### 快照推送 `_push_snapshot()`

```gdscript
var runners := _collect_runners()
if runners.is_empty():
    return
var msg := JSON.stringify({"t": "vars", "runners": runners}) + "\n"
# put_partial_data 非阻塞（缓冲满发部分即返回），避免 put_data 阻塞主线程
# 丢弃未发送部分（下个 snapshot 覆盖，变量快照实时性优先于完整性）
_client.put_partial_data(msg.to_utf8_buffer())
```

设计哲学：**实时性 > 完整性**。缓冲满时丢弃，下次 0.5s 后整体覆盖，不阻塞主线程。

#### Runner 采集 `_collect_runners()`

[第 181–199 行](../../../core/fuse_runtime_bridge.gd)：

```gdscript
var scene = get_tree().current_scene
if scene == null:
    return result

for runner in scene.find_children("*", "Runner", true, false):
    var ec = runner.get("current_execution_context")
    if ec == null or not is_instance_valid(ec):
        continue
    var vc = ec.get("_variable_context")
    if vc == null:
        continue
    result.append({
        "name": runner.name,
        "local": vc.get_all_local_variables_snapshot(),
        "scope": vc.get_all_scope_variables_snapshot()
    })
```

数据链路：

```
Runner.current_execution_context (ExecutionContext)
   └── ._variable_context (VariableContext)
         ├── get_all_local_variables_snapshot()  → Dictionary
         └── get_all_scope_variables_snapshot()  → Dictionary
```

> **注意**：`current_execution_context` 是 Runner 在运行时设置的属性（[fuse_architecture_analysis.md:265](fuse_architecture_analysis.md)），`_variable_context` 是 ExecutionContext 的私有字段。运行游戏侧通过 `Object.get(prop_name)` 反射读取，避免硬类型耦合。

### 4.7 与 GlobalVariableManager 的关系

**无直接交互**。`FuseRuntimeBridge` 仅采集 **Runner 的 local / scope 变量**（来自 `VariableContext`），**不**采集 global 变量。

全局变量的编辑器侧显示走**另一条路径**：`FuseVariableWatcher._refresh()` 直接通过 `GlobalVariableService` 读取（[variable_watcher.gd:395-404](../../../editor/debugging/variable_watcher.gd)），无需 TCP 桥（因为 `GlobalVariableManager` 是 Autoload，编辑器进程本就有完整副本）。

| 变量作用域 | 数据来源 | 是否经 TCP 桥 |
|-----------|---------|---------------|
| local | `VariableContext.get_all_local_variables_snapshot()` | 是（运行游戏 → 编辑器） |
| scope | `VariableContext.get_all_scope_variables_snapshot()` | 是 |
| global | `GlobalVariableService.get_all_global_variables_info()` | 否（编辑器进程直读 GlobalVariableManager） |

---

## 5. 两者协作关系

### 5.1 直接调用关系：无

`FuseEventBus` 与 `FuseRuntimeBridge` **互不引用、互不调用**。它们共享的只是"Autoload 注册机制"和"由同一 bootstrap 注册"这一基础设施层面的事实：

```gdscript
# fuse_runtime_bootstrap.gd
func setup() -> void:
    _register_event_bus()                # 注册 FuseEventBus
    _register_reflection_cache_cleanup() # 注册 node_removed → 清反射缓存
    _register_runtime_bridge()           # 注册 FuseRuntimeBridge
```

### 5.2 职责对比

| 维度 | FuseEventBus | FuseRuntimeBridge |
|------|--------------|---------------------|
| 子系统 | 事件通信（运行时业务） | 调试反射（开发期观测） |
| 数据流方向 | 多对多（订阅/发布） | 单向（运行游戏 → 编辑器） |
| 通信介质 | 进程内（同进程对象间） | 跨进程 TCP + JSON |
| 生产期 | 编辑器 + 运行游戏均活跃 | 仅在编辑器开启 + 游戏运行时活跃 |
| 是否影响业务逻辑 | 是（SendEvent / OnReceiveEvent 依赖它） | 否（仅观测，断开不影响游戏逻辑） |
| 公开 API | `send_event` / `subscribe` / `unsubscribe` / 查询 | `get_cached_vars()` |

### 5.3 共同的注册/清理宿主

两者均由 `FuseRuntimeBootstrap` 注册，但**注册顺序**与**注销顺序**对称（setup 正向、teardown 逆向），保证依赖关系（如反射缓存清理依赖 SceneTree 存在）正确。

---

## 6. 设计意图与权衡

### 6.1 选用 Autoload 而非 Resource 单例

`FuseEventBus` 与 `FuseRuntimeBridge` 都需要 Node 生命周期钩子：
- 前者依赖 `_ready` 自动挂 `node_removed`、`_notification(PREDELETE)` 兜底清订阅表
- 后者依赖 `_ready` 启动 TCP、`_process` 节流推送、`_exit_tree` 关连接

Resource 单例没有这些钩子，必须由外部 driver 调度——而 Autoload Node 自带驱动，是最自然的载体。

### 6.2 双模式 Autoload（FuseRuntimeBridge）

同一脚本通过 `Engine.is_editor_hint()` 分流为 server / client，**省去维护两份代码**。代价是阅读时需注意每段代码的执行环境。

### 6.3 消费方"降级访问"约定

`SendEvent` / `OnReceiveEvent` / `FuseVariableWatcher` 都用 `get_node_or_null(name)` + `has_method` 双重保护，**不直接以 Autoload 名作全局变量**。好处：
- Autoload 未注册时不硬崩溃，返回错误码（`FUSE_ERROR_EVENT_BUS_NOT_FOUND`）
- 便于单元测试 mock（注入同名节点）
- 避免编辑器静态分析误报

### 6.4 TCP 桥实时性 > 完整性

`put_partial_data` + 0.5s 整体覆盖的设计，避免了缓冲累积和主线程阻塞，是变量快照场景下的正确权衡（监控场景允许丢帧，不允许卡顿）。

### 6.5 历史记录限长（FIFO 100 条）

`_event_history` 用 `pop_front()` 实现 FIFO，避免无限增长。这是嵌入式调试器常见模式。

---

## 7. 潜在问题与改进点

### 7.1 `node_removed` 双重注册（待确认）

如 §2.7 所述，`FuseEventBus._ready` 与 `FuseRuntimeBootstrap._register_reflection_cache_cleanup` 在编辑器进程里**都**连了 `node_removed`，回调体完全一致。建议确认是否有意保留（如运行游戏侧无 bootstrap 时由 autoload 兜底），还是历史遗留可清理。

### 7.2 `send_event` 同步阻塞

订阅者回调若执行长任务（如 `await`、网络、重计算），会阻塞 `SendEvent.execute()` 及其 ActionRunner。`send_event_deferred` 仅把"发送"延迟到帧末，不解决单次回调阻塞问题。复杂场景需自行拆分。

### 7.3 TCP 端口硬编码 24563

`BRIDGE_PORT` 为常量。若端口被占用（如多开 Godot 实例），`_start_server` 仅 `push_warning` 后静默失败，编辑器侧监视器将永久显示空。可考虑端口探测/回退或多实例隔离。

### 7.4 `get_cached_vars` 整体覆盖语义

每次推送整体覆盖 `_cached`。若运行游戏推送间隔内编辑器侧多次查询，可能读到部分更新的中间态（虽概率极低，因 JSON line 是原子单位）。当前实现可接受。

### 7.5 `SendEvent` 调试日志冗长

[send_event.gd:135-159](../../../instructions/event/send_event.gd) 的 `_resolve_args` 含大量 `_log_debug` 行，对每个参数打 3 行日志。生产环境下若 DEBUG 级别未关，将产生大量日志噪声。

---

## 8. 总体评估

### 优点

1. **职责清晰**：FuseEventBus = 业务通信，FuseRuntimeBridge = 调试观测，互不耦合
2. **降级安全**：消费方统一 `get_node_or_null` + `has_method` 双保护，Autoload 缺失时优雅降级
3. **双模式 Autoload**：同一脚本用 `Engine.is_editor_hint()` 分流，省代码
4. **TCP 设计稳健**：粘包处理、`poll()` 后判状态、`put_partial_data` 非阻塞、节流推送
5. **插件托管注册**：bootstrap 动态 add/remove autoload，用户无需手动改 `project.godot`
6. **历史记录与反射清理**：FuseEventBus 自带 100 条事件历史与节点删除缓存清理

### 不足

1. `node_removed` 在编辑器进程被双重注册（轻度冗余，待确认）
2. `send_event` 同步阻塞，无超时/异步机制
3. TCP 端口硬编码，无端口冲突处理
4. SendEvent 的调试日志在 DEBUG 级别下过于冗长

---

**文档维护**: Fuse 开发团队
**最后更新**: 2026-07-07
**版本**: 1.0.0
