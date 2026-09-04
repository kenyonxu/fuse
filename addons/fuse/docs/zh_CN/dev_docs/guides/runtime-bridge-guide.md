> 🌐 中文 | [**English**](../../../en_US/dev_docs/guides/runtime-bridge-guide.md)

# Fuse RuntimeBridge 开发指南

> **目标**: 为开发者提供 FuseRuntimeBridge 运行时变量桥的完整开发指引，包括双模式架构、TCP 协议和变量快照。

**适用对象**: Fuse 系统开发者、贡献者

**最后更新**: 2026-09-04

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
│  │  (变量快照缓存)     │      │              │  │  _collect_units_+  │     │
│  │                    │      │              │  │  _containers()     │     │
│  └────────────────────┘      │              │  └────────────────────┘     │
│        ↕                     │              │        ↕                    │
│  FuseVariableWatcher        │              │  BaseTrigger/Runner 单元    │
│  (变量监视器)                 │              │  ScopeVariableContainer 容器│
└──────────────────────────────┘              └──────────────────────────────┘
```

### 数据流

```
运行游戏侧：
  _process(delta)
    → _client_poll(delta)       每 0.5s
        → _push_snapshot()
            → _collect_units_and_containers()  root 全树单遍收集，
                │                              逐节点三判归类（树遍历只产出 containers/units）
                → BaseTrigger / Runner → units（local 取最近执行上下文，
                │   运行后保留——非即焚）
                → ScopeVariableContainer → containers
            → _collect_global_flat()           global 独立收集（与树遍历平行，仅标量）
            → JSON.stringify + put_partial_data()

编辑器侧：
  _process(delta)
    → _server_poll()            每帧
        → 接受新连接
        → 读缓冲区 → _read_json_lines()
            → _update_cache(containers/units/global)
        → 所有连接断开 → _cached.clear()

编辑器侧（写回）：
  变量监视器编辑提交
    → send_set_var(target, target_id, name, value)
        → JSON.stringify + put_partial_data()   广播到所有连接
        → 无连接 → 返回 false

运行游戏侧（应用写回）：
  _client_poll → _read_json_lines → _handle_message（按 "t" 分发）
    → t == "set_var" → _apply_set_var()
        → 按 target 三分发（container / unit / global）
        → 类型收窄 + 非标量闸门（三路共用）→ 写入
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
## 编辑器侧：获取缓存的运行时变量快照（v3 双键结构）
## 返回: Dictionary — {"containers": [容器条目...], "units": [单元条目...]}
func get_cached_vars() -> Dictionary

## 编辑器侧：游戏侧 global 标量快照（{name: value}）
func get_cached_global() -> Dictionary

## 编辑器侧：是否有运行游戏连接
func is_game_connected() -> bool

## 编辑器侧：向运行游戏广播写回（fire-and-forget）
## target: "container" | "unit" | "global"；无连接返回 false
func send_set_var(target: String, target_id: int, name: String, value: Variant) -> bool

## 测试注入：以显式端口启动对应模式（默认 BRIDGE_PORT = 24563）
func start_server(port: int = BRIDGE_PORT) -> void
func start_client(port: int = BRIDGE_PORT) -> void

## 编辑器侧：Server 是否已启动并在监听
func is_server_active() -> bool

## 纯函数：从流缓冲提取完整 JSON 行（粘包/半包处理）
## 返回 {lines: Array[Dictionary], rest: String}
static func extract_json_lines(buffer: String) -> Dictionary
```

编辑器工具（如 FuseVariableWatcher）用这些接口读取缓存数据，并向运行游戏写回变量值。

### 生命周期

```gdscript
func _ready() -> void:
    # 注入守卫：已显式注入模式（测试）则尊重现状，不自动分叉
    if _server != null or _client != null:
        return
    if Engine.is_editor_hint():
        start_server()
    else:
        start_client()

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
func start_server(port: int = BRIDGE_PORT) -> void # 公开：启动 TCPServer，监听指定端口（默认 :24563）
func _server_poll() -> void                        # 每帧轮询：接受连接 + 读取数据
func _read_json_lines(conn: StreamPeerTCP) -> void # 从 TCP 流中按行读取 JSON
func _update_cache(payload: Dictionary) -> void    # 更新 _cached（containers/units 走 .get，字段缺失降级空集）

# ===== 运行游戏侧 - Client =====
func start_client(port: int = BRIDGE_PORT) -> void # 公开：连接编辑器
func _client_poll(delta: float) -> void            # 每 0.5s 轮询 + 推送
func _push_snapshot() -> void                      # 推送变量快照
func _collect_units_and_containers() -> Dictionary # v3 收集：root 全树单遍，三判归类
```

---

## TCP 协议

### 协议格式

TCP 流 + JSON line（`\n` 分隔）。

**推送（游戏 → 编辑器，协议 `proto = 3`），每 0.5s，恒定推送**——即使没有单元/容器，`global` 快照仍会推送（空 `containers`/`units` 会清空编辑器缓存）：

```json
{"t": "vars", "proto": 3,
 "containers": [
    {"id": 99001, "path": "/World/LevelScope", "scope_id": "level1",
     "vars": {"alert_level": 50, "items": {"__complex": "[item1, item2]", "ty": "Array"}}}
 ],
 "units": [
    {"id": 123456789, "path": "/Enemies/Slime", "kind": "trigger", "ago_ms": 320,
     "local": {"health": 85}},
    {"id": 123456790, "path": "/Main/Runner1", "kind": "runner", "ago_ms": 5,
     "local": {"score": 100}}
 ],
 "global": {"player_score": 2450, "game_time": 132.5}}
```

**协议 v3 字段**：

| 字段 | 含义 |
|------|------|
| `containers[].id` / `path` / `scope_id` / `vars` | `ScopeVariableContainer` 实例 id / 显示路径（current_scene 相对，用于组头；子树外回退绝对路径，`/root/...` 开头）/ scope id / 变量快照 |
| `units[].id` / `path` / `kind` | 宿主组件实例 id / 显示路径 / `trigger` \| `multi` \| `runner`（BaseTrigger / MultiEventTrigger / Runner） |
| `units[].ago_ms` | 距组件最近一次执行的毫秒数；监视器对超 5s 的组头灰显 |
| `units[].local` | 组件**最近执行上下文**的本地变量——三类宿主运行后均保留 `current_execution_context`，非即焚 |
| `global`（顶层） | 游戏侧全局变量**标量**快照（`{name: value}`）；复杂类型（Dictionary/Array/Vector 等）不入协议 |
| `__complex` 包装 | 非标量值编码为只读包装 `{"__complex": "str(v) ≤200字符", "ty": "Vector2"}`——编辑器据此区分真 `String` 与复杂值（v2 把对象序列化成裸字符串，是"假 String"行根源；已在协议层消除） |

**反向消息（编辑器 → 游戏）**——广播到**所有**存活连接，**fire-and-forget**（无确认；正确性由 0.5s 推送回显兜底）：

```json
{"t": "set_var", "proto": 3, "target": "container", "id": 99001, "name": "alert_level", "value": 75}
```

游戏侧应用语义（`_apply_set_var`，按 `target` 三分发）：

- **三路共用闸门**：**类型收窄**——JSON 解析后数字一律为 `float`；按目标变量现有类型收窄（`int` 目标收窄回 `int`；目标不存在时原样写入——float 化为已知限制）。**非标量闸门**——目标槽位当前持有非标量（`Object` / `Vector2` / 容器等）时静默忽略写回；v3 起推送侧已用只读 `__complex` 包装显式标注非标量（编辑器不会对这类行发起写回），闸门仅作为最后防线保留。
- **`target == "container"`**：`_find_node_by_id(id)` 定位 `ScopeVariableContainer` → `set_variable`；id 失效静默忽略。
- **`target == "unit"`**：定位 `BaseTrigger`/`Runner` → `current_execution_context` → `_variable_context` → 对 `local` 执行 `set_variable`；无有效最近上下文（尚未执行）的单元静默忽略。
- **`target == "global"`**：变量**存在才写**（不存在不创建，静默忽略）。
- **`_find_node_by_id` 定位**：root 全树递归扫描匹配 `get_instance_id()` 并按 `expected` 做类型校验（`""` = BaseTrigger/Runner 任一；`"ScopeVariableContainer"` = 容器）——不用 `instance_from_id`（失效 id 会刷引擎 ERROR）。
- **编辑器侧**：`send_set_var()` 无存活连接时返回 `false`；短写（部分字节发出）会警告并断开该连接，游戏侧重连自愈。
- **降级**：`_handle_message` 按 `t` 分发（而非按键存在性）；字段缺失经 `.get` 缺省为空集，降级消息也会触达 `_update_cache` 清空缓存。

### 测试注入

测试可在同一进程以显式端口注入两种模式；生产路径保持默认 `BRIDGE_PORT`（24563）：

```gdscript
FuseRuntimeBridge.start_server(24599)   # 编辑器侧，监听注入端口
FuseRuntimeBridge.start_client(24599)   # 游戏侧，连接注入端口
```

回环测试：`tests/debugging/test_runtime_bridge_loopback.tscn`（用 24599 端口，避免与 24563 上的 Autoload 桥互相干扰）。

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
for unit in vars.get("units", []):
    var local_data = unit.get("local", {})   # 组头：▸ path [kind] · ago
for container in vars.get("containers", []):
    var scope_data = container.get("vars", {})   # 组头：▸ path (scope_id)
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
func start_client(port: int = BRIDGE_PORT) -> void:
    # ...连接...
    # 失败时 _client_poll 中判断 STATUS_ERROR 后自动重连
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

### 陷阱 4：运行时附加的子树收不到

**问题**: v2 收集器遍历 `get_tree().current_scene`，运行时附加的子树（附加场景）永远不会上报。

**解决方案**: v3 改为从 `get_tree().root` 单遍收集（`_collect_units_and_containers`），覆盖附加场景；游戏进程的 autoload 内无 Fuse 组件，扫描量等效全场景。

### 陷阱 5：变量未更新

**问题**: 修改了变量但编辑器看不到更新。

**可能原因**: 
- 该单元还没有有效的最近执行上下文（BaseTrigger/Runner 首次执行后才会开始上报 `local`）
- `_variable_context` 为空（B19 历史 bug 已修复）
- 连接已断开但 `_cached` 未清空

---

## 参考文档

- [ExecutionContext 与 Diagnostics 指南](execution-context-diagnostics-guide.md)
- [FuseLogger 日志系统指南](fuse-logger-guide.md)
- [FuseEventBus 开发指南](event-bus-guide.md)
- [ActionRunner 开发指南](action-runner-guide.md)

---

**文档维护**: Fuse 开发团队 | **最后更新**: 2026-09-04 | **Godot 版本**: 4.7
