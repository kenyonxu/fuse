> 🌐 中文 | [**English**](../../../en_US/dev_docs/guides/runtime-bridge-guide.md)

# Fuse RuntimeBridge 开发指南

> **目标**: 为开发者提供 FuseRuntimeBridge 运行时变量桥的完整开发指引，包括双模式架构、TCP 协议和变量快照。

**适用对象**: Fuse 系统开发者、贡献者

**最后更新**: 2026-07-07

---

## 📋 目录

1. [系统概述](#系统概述)
2. [架构设计](#架构设计)
3. [API 参考](#api-参考)
4. [TCP 协议](#tcp-协议)
5. [使用场景](#使用场景)
6. [粘包/半包处理](#粘包半包处理)
7. [最佳实践](#最佳实践)
8. [常见陷阱](#常见陷阱)

---

## 系统概述

`FuseRuntimeBridge` 是一个**双模式 TCP 桥接器**，负责在 Godot 编辑器进程和运行的游戏进程之间传递变量快照数据。使编辑器的调试工具（如 FuseVariableWatcher）能够实时查看运行中游戏的变量状态。

> **Autoload 单例约定**
> `FuseRuntimeBridge` 通过 Autoload 注册为全局单例（无 `class_name`），只能用 Autoload 名 `FuseRuntimeBridge` 直接访问。
> - ✅ `FuseRuntimeBridge.get_cached_vars()`
> - ❌ ~~`FuseRuntimeBridge.new()`~~（没有 `class_name`，无法实例化）
> - ❌ ~~`preload("res://...").get_cached_vars()`~~（preload 拿到的是脚本而非实例）

### 核心文件

| 文件 | 用途 |
|------|------|
| `core/fuse_runtime_bridge.gd` | 运行时桥接器（Autoload） |
| `editor/bootstrap/fuse_runtime_bootstrap.gd` | 运行时引导程序 |

### 设计目标

- **双模式切换**: 编辑器侧为 TCPServer，运行游戏侧为 TCP Client
- **低侵入性**: 无需修改现有指令/触发器代码
- **实时性优先**: 变量快照实时推送，丢帧可接受
- **自动清理**: 编辑器检测到连接断开时自动清空缓存

---

## 架构设计

```
┌──────────────────────────────┐     TCP     ┌──────────────────────────────┐
│      Godot 编辑器进程          │ ◄──────────► │      运行游戏进程             │
│                              │   127.0.0.1   │                              │
│  FuseRuntimeBridge           │   :24563      │  FuseRuntimeBridge           │
│  ┌────────────────────┐      │  JSON line    │  ┌────────────────────┐     │
│  │  TCPServer 模式    │      │  (\n 分隔)    │  │  TCP Client 模式   │     │
│  │                    │      │              │  │                    │     │
│  │  _cached: Dict     │ ◄────┼──────────────┼──┤  0.5s 定时推送     │     │
│  │  (变量快照缓存)     │      │              │  │  _collect_runners()│     │
│  └────────────────────┘      │              │  └────────────────────┘     │
│        ↕                     │              │        ↕                    │
│  FuseVariableWatcher        │              │  Runner 节点                │
│  (变量监视器)                 │              │  (current_execution_context)│
└──────────────────────────────┘              └──────────────────────────────┘
```

### 数据流

```
运行游戏侧：
  _process(delta)
    → _client_poll(delta)       每 0.5s
        → _push_snapshot()
            → _collect_runners()   遍历场景中的 Runner 节点
                → ec = runner.current_execution_context
                → vc = ec._variable_context
                → snapshot: {local_vars, scope_vars}
            → JSON.stringify + put_partial_data()

编辑器侧：
  _process(delta)
    → _server_poll()            每帧
        → 接受新连接
        → 读缓冲区 → _read_json_lines()
            → _update_cache(runners)
        → 所有连接断开 → _cached.clear()
```

---

## API 参考

**文件位置**: `addons/fuse/core/fuse_runtime_bridge.gd`

**类定义**:
```gdscript
@tool
extends Node
```

FuseRuntimeBridge 通过 `@tool` 声明使其在编辑器中也运行。它通过 Autoload 自动实例化。

### 常量

```gdscript
const BRIDGE_PORT := 24563        # TCP 端口
const PUSH_INTERVAL := 0.5        # 推送间隔（秒）
```

### 公开接口

```gdscript
## 获取缓存的运行时变量快照（编辑器侧）
## 返回: Dictionary — {runner_name: {"local": {...}, "scope": {...}}}
func get_cached_vars() -> Dictionary
```

这是唯一的公开方法，供编辑器工具（如 FuseVariableWatcher）读取缓存数据。

### 生命周期

```gdscript
func _ready() -> void:
    if Engine.is_editor_hint():
        _start_server()
    else:
        _connect_client()

func _exit_tree() -> void:
    # 停止 Server / 断开 Client，清理缓冲和缓存

func _process(delta: float) -> void:
    if Engine.is_editor_hint():
        if _server:
            _server_poll()
    else:
        if _client:
            _client_poll(delta)
```

### 内部方法

```gdscript
# ===== 编辑器侧 - Server =====
func _start_server() -> void                      # 启动 TCPServer，监听 :24563
func _server_poll() -> void                        # 每帧轮询：接受连接 + 读取数据
func _read_json_lines(conn: StreamPeerTCP) -> void # 从 TCP 流中按行读取 JSON
func _update_cache(runners: Array) -> void         # 更新 _cached 缓存

# ===== 运行游戏侧 - Client =====
func _connect_client() -> void                     # 连接 127.0.0.1:24563
func _client_poll(delta: float) -> void            # 每 0.5s 轮询 + 推送
func _push_snapshot() -> void                      # 推送变量快照
func _collect_runners() -> Array                   # 收集场景中所有 Runner 的变量
```

---

## TCP 协议

### 协议格式

TCP 流 + JSON line（`\n` 分隔）：

```json
{"t": "vars", "runners": [
    {
        "name": "RunnerName",
        "local": {"score": 100, "name": "player"},
        "scope": {"health": 80, "mana": 50}
    },
    ...
]}
```

### 端口

- 固定端口: **24563**
- 监听地址: **127.0.0.1**（仅本地回环）

### 粘包/半包处理

每条连接有独立的读缓冲区 `_read_buffers: Dictionary`（key 为 `conn.get_instance_id()`）：

```gdscript
# 伪代码
_read_buffers[cid] += data
while "\n" found:
    line = extract_line
    parse JSON → _update_cache
```

---

## 使用场景

### 编辑器变量监视

`FuseVariableWatcher` 编辑器面板调用 `FuseRuntimeBridge.get_cached_vars()` 获取运行中的变量快照：

```gdscript
# addons/fuse/editor/debugging/variable_watcher.gd
var vars = FuseRuntimeBridge.get_cached_vars()
for runner_name in vars:
    var local_data = vars[runner_name].local
    var scope_data = vars[runner_name].scope
    # 显示到编辑器面板
```

### 运行时调试

在游戏运行过程中，编辑器侧自动接收变量快照，无需手动设置断点或打印日志即可查看变量变化。

---

## 最佳实践

### 1. 数据类型限制

确保变量可被 JSON 序列化（基本类型、Dictionary、Array），自定义对象不会被正确传输。

### 2. 推送频率控制

`PUSH_INTERVAL = 0.5s` 是合理值——过低增加网络和序列化开销，过高丢失实时性。不要手动在 `_process` 中修改此值。

### 3. 缓冲清理

`_read_buffers` 按连接 ID 索引，断开连接时自动清理：

```gdscript
var cid := conn.get_instance_id()
conn.disconnect_from_host()
_read_buffers.erase(cid)
_connections.remove_at(i)
```

### 4. 连接断开检测

```gdscript
# _server_poll 中每帧 poll() 后检查状态
conn.poll()
var st := conn.get_status()
if st == StreamPeerTCP.STATUS_NONE or st == StreamPeerTCP.STATUS_ERROR:
    # 断开连接 + 清理
```

### 5. 运行游戏侧自动重连

```gdscript
func _connect_client() -> void:
    # ...连接...
    # 失败时 _client_poll 中判断 STATUS_ERROR 后再次调用 _connect_client()
```

---

## 常见陷阱

### 陷阱 1：端口冲突

**问题**: 如果其他程序占用了 24563 端口，StartServer 失败。

**表现**: 控制台输出 `WARNING: FuseRuntimeBridge: 监听 24563 失败(ERR_...)`。

**解决方案**: 检查端口占用。`FuseRuntimeBridge` 在失败时静默处理，`get_cached_vars()` 返回空 Dictionary。

### 陷阱 2：多编辑器实例冲突

**问题**: 同时启动多个 Godot 编辑器实例，每个都试图监听 24563。

**解决方案**: 只有一个实例能成功启动 Server。建议只在一个实例中运行游戏。

### 陷阱 3：粘包导致 JSON 解析错误

**问题**: TCP 流中多个 JSON line 合并发送，`get_utf8_string()` 一次读回多条。

**解决方案**: 通过 `\n` 分割逐行解析，`_read_json_lines()` 已处理此场景。

### 陷阱 4：运行时 `get_tree()` 返回 null

**问题**: `_collect_runners()` 依赖 `get_tree().current_scene`，如果场景未准备好则返回空数组。

**解决方案**: 推送前检查 `scene != null`，空则跳过本次推送。

### 陷阱 5：变量未更新

**问题**: 修改了变量但编辑器看不到更新。

**可能原因**: 
- `Runner.current_execution_context` 未设置
- `_variable_context` 为空（B19 历史 bug 已修复）
- 连接已断开但 `_cached` 未清空

---

## 参考文档

- [ExecutionContext 与 Diagnostics 指南](execution-context-diagnostics-guide.md)
- [FuseLogger 日志系统指南](fuse-logger-guide.md)
- [FuseEventBus 开发指南](event-bus-guide.md)
- [ActionRunner 开发指南](action-runner-guide.md)

---

**文档维护**: Fuse 开发团队 | **最后更新**: 2026-07-07 | **Godot 版本**: 4.7
