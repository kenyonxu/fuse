# 运行时变量 TCP 桥 — 实施计划

**日期:** 2026-06-27
**关联:** [运行时变量访问调研](2026-06-27-runtime-variable-access-research.md)（方案 A 不可行 → C TCP 桥）· [Stage 7 plan](2026-06-27-stage7-implementation-plan.md)
**目标:** local/scope 变量运行时可见（变量监视器看运行游戏实例的变量）
**预估工时:** 2-3 天

---

## 0. 背景 + 选型

- **问题:** 变量监视器 local/scope 运行时不可见（[调研](2026-06-27-runtime-variable-access-research.md)确认：`get_edited_scene_root` 拿编辑场景，运行游戏独立进程；Godot 远程调试 API 无 RPC + RefCounted 不可穿透 + EngineDebugger 未暴露 GDScript）
- **方案 A（C++ GDExtension）不可行:** godot-cpp 不暴露 `EditorDebuggerPlugin`/`EngineDebugger`（Godot 刻意，引擎内部调试基础设施）
- **选方案 C（TCP 自建桥，纯 GDScript）:** 运行游戏主动推扁平快照，编辑器 TCP 接收，绕开 Godot debugger 协议。0 编译，不改发布模型。

---

## 1. 架构

双模式 Autoload（FuseRuntimeBridge）：

```
编辑器进程                              运行游戏进程（F5/F6）
FuseRuntimeBridge (Autoload)            FuseRuntimeBridge (Autoload)
  is_editor_hint() → TCPServer            is_editor_hint() false → TCP 客户端
    listen 127.0.0.1:24563                  connect 127.0.0.1:24563
    accept + 读 JSON line → _cached         _process 0.5s 收集 Runner 变量
                                            put JSON line
       ↑                                        |
       |  variable_watcher.get_cached_vars()    |
       +---------- (同进程，Autoload 全局) <----+
```

**关键:** Autoload 在编辑器进程和运行游戏进程**各自加载一个实例**（Autoload 机制）。用 `Engine.is_editor_hint()` 区分模式：
- 编辑器实例 → TCPServer（listen）
- 运行游戏实例 → TCP 客户端（connect + push）

variable_watcher（编辑器 Dock）访问编辑器进程的 `FuseRuntimeBridge`（全局 Autoload），读 `_cached`。

---

## 2. 协议

TCP 流 + **JSON line**（每条消息一行，`\n` 分隔）：

**运行游戏 → 编辑器:**
```json
{"t":"vars","runners":[{"name":"Runner1","local":{"hp":100,"name":"player"},"scope":{...}},{"name":"Runner2",...}]}
```

- `local`/`scope` 是 `VariableContext.get_all_*_variables_snapshot()` 的扁平 Dictionary（变量名→值，纯标量/String，无 RefCounted 嵌套）
- 编辑器缓存最新一条（按 `runner_name` 索引，覆盖）
- 连接关闭（运行游戏退出）→ 清缓存

**反向（编辑器→运行游戏）:** V1 不做（local/scope 编辑需反向通道，见 §7 后续）。

---

## 3. 任务分解

| 任务 | 内容 | 工时 |
|---|---|:--:|
| A | FuseRuntimeBridge Autoload（双模式 TCP + 协议）| 1 天 |
| B | variable_watcher 改读 bridge 缓存 | 0.5 天 |
| C | 注册（FuseRuntimeBootstrap）+ 集成 + 连接管理 | 0.5 天 |
| D | 验收 + 边界 | 0.5 天 |

---

## 4. 任务 A — FuseRuntimeBridge Autoload

**文件:** `addons/fuse/core/fuse_runtime_bridge.gd`

```gdscript
extends Node
class_name FuseRuntimeBridge

## 运行时变量 TCP 桥（双模式 Autoload）
## 编辑器侧：TCPServer listen，接收运行游戏推送的变量快照，缓存
## 运行游戏侧：TCP 客户端，0.5s 收集 Runner 的 local/scope 变量并推送

const BRIDGE_PORT := 24563
const PUSH_INTERVAL := 0.5

var _server: TCPServer = null
var _connections: Array[StreamPeerTCP] = []
var _client: StreamPeerTCP = null
var _cached: Dictionary = {}  # 编辑器侧：{runner_name: {local, scope}}
var _push_acc: float = 0.0


func _ready() -> void:
    if Engine.is_editor_hint():
        _start_server()
    else:
        _connect_client()


func _exit_tree() -> void:
    if _server:
        _server.stop()
    if _client:
        _client.disconnect_from_host()


# ============ 编辑器侧 ============

func _start_server() -> void:
    _server = TCPServer.new()
    var err := _server.listen(BRIDGE_PORT, "127.0.0.1")
    if err != OK:
        push_warning("FuseRuntimeBridge: 监听 %d 失败(%d)，运行时变量桥不可用" % [BRIDGE_PORT, err])


func _server_poll() -> void:
    while _server and _server.is_connection_available():
        _connections.append(_server.take_connection())
    var i := 0
    while i < _connections.size():
        var conn: StreamPeerTCP = _connections[i]
        if conn.get_status() == StreamPeerTCP.STATUS_NONE:
            _connections.remove_at(i)
            continue
        _read_json_lines(conn)
        i += 1


func _read_json_lines(conn: StreamPeerTCP) -> void:
    var avail := conn.get_available_bytes()
    if avail <= 0:
        return
    var data := conn.get_utf8_string(avail)
    for line in data.split("\n"):
        if line.strip_edges().is_empty():
            continue
        var parsed = JSON.parse_string(line)
        if parsed is Dictionary and parsed.has("runners"):
            _update_cache(parsed["runners"])


func _update_cache(runners: Array) -> void:
    _cached.clear()
    for r in runners:
        var rname: String = r.get("name", "?")
        _cached[rname] = {"local": r.get("local", {}), "scope": r.get("scope", {})}


func get_cached_vars() -> Dictionary:
    return _cached


# ============ 运行游戏侧 ============

func _connect_client() -> void:
    _client = StreamPeerTCP.new()
    _client.connect_to_host("127.0.0.1", BRIDGE_PORT)


func _client_poll(delta: float) -> void:
    var st := _client.get_status()
    if st == StreamPeerTCP.STATUS_NONE or st == StreamPeerTCP.STATUS_ERROR:
        _connect_client()  # 重连
        return
    if st != StreamPeerTCP.STATUS_CONNECTED:
        return
    _push_acc += delta
    if _push_acc < PUSH_INTERVAL:
        return
    _push_acc = 0.0
    _push_snapshot()


func _push_snapshot() -> void:
    var runners := _collect_runners()
    if runners.is_empty():
        return
    var msg := JSON.stringify({"t": "vars", "runners": runners}) + "\n"
    _client.put_data(msg.to_utf8_buffer())


func _collect_runners() -> Array:
    var result: Array = []
    var scene = get_tree().current_scene
    if scene == null:
        return result
    for runner in scene.find_children("*", "Runner"):
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
    return result


func _process(delta: float) -> void:
    if Engine.is_editor_hint():
        if _server:
            _server_poll()
    else:
        if _client:
            _client_poll(delta)
```

---

## 5. 任务 B — variable_watcher 改读缓存

[variable_watcher.gd `_collect_runtime_variables`](../../editor/debugging/variable_watcher.gd#L309)：用 `FuseRuntimeBridge.get_cached_vars()` 替代 `EditorInterface.get_edited_scene_root()` 扫 Runner。

```gdscript
func _collect_runtime_variables() -> Dictionary:
    var local_rows: Array[Dictionary] = []
    var scope_rows: Array[Dictionary] = []
    var runners: Array = []
    var runner_count := 0
    var active_count := 0

    # 从 FuseRuntimeBridge 读运行游戏推送的变量（替代 get_edited_scene_root）
    if ClassDB.class_exists("FuseRuntimeBridge"):
        var cached: Dictionary = FuseRuntimeBridge.get_cached_vars()
        for runner_name in cached:
            runner_count += 1
            active_count += 1
            var data: Dictionary = cached[runner_name]
            var locals: Dictionary = data.get("local", {})
            for var_name in locals:
                local_rows.append(_make_row_data(var_name, locals[var_name],
                    {"context": null, "scope": "local", "runner": runner_name}))
            var scopes: Dictionary = data.get("scope", {})
            for var_name in scopes:
                scope_rows.append(_make_row_data(var_name, scopes[var_name],
                    {"context": null, "scope": "scope", "runner": runner_name}))
            runners.append({"runner_name": runner_name, "local": locals, "scope": scopes})

    return {
        "local_rows": local_rows, "scope_rows": scope_rows, "runners": runners,
        "runner_count": runner_count, "active_count": active_count
    }
```

**注意:** `context` 传 null（local/scope 编辑需反向通道，V1 不支持运行时编辑 local/scope，只读）。行数据加 `runner` 字段（标识来源）。

---

## 6. 任务 C — 注册 + 集成

**FuseRuntimeBootstrap.setup()** 加 Autoload 注册（参照 FuseEventBus，[fuse_runtime_bootstrap.gd:25-30](../../editor/bootstrap/fuse_runtime_bootstrap.gd#L25)）:

```gdscript
const BRIDGE_PATH := "res://addons/fuse/core/fuse_runtime_bridge.gd"

func setup() -> void:
    # ... 现有 FuseEventBus 注册 ...
    var autoloads = ProjectSettings.get_setting("autoload", {})
    if not autoloads.has("FuseRuntimeBridge"):
        _plugin.add_autoload_singleton("FuseRuntimeBridge", BRIDGE_PATH)
        print("[FusePlugin] FuseRuntimeBridge 已注册为 Autoload")

func teardown() -> void:
    # ... 现有 FuseEventBus 注销 ...
    var autoloads = ProjectSettings.get_setting("autoload", {})
    if autoloads.has("FuseRuntimeBridge"):
        _plugin.remove_autoload_singleton("FuseRuntimeBridge")
```

**project.godot:** add_autoload_singleton 会自动写入 autoload 配置。

---

## 7. 验收

1. **local/scope 运行时可见:** 运行含 Runner + local/scope 变量的场景（如 [game_scene.tscn](../../../demos/fuse/brickian/game_scene.tscn)）→ 变量监视器显示运行游戏的 local/scope（非空）
2. **实时刷新:** 运行中变量变化 → 监视器 0.5s 内反映
3. **停止清空:** 停止运行 → 连接关闭 → 缓存清空 → local/scope 消失
4. **多 Runner:** 场景多个 Runner → 各自 local/scope 都显示（按 runner_name 区分）
5. **global 不受影响:** global（GlobalVariableService）照常
6. **回归:** 7a（global 编辑）/7b（折线图，global 数值）/7c（静态声明）/7d（snapshot）不破坏

---

## 8. 风险与限制

| 风险 | 应对 |
|---|---|
| 端口冲突（24563 占用）| `_start_server` listen 失败 push_warning；可配置端口（ProjectSettings）|
| 连接断开/重连 | `_client_poll` 检测 STATUS_NONE/ERROR 重连 |
| 多运行实例（同时跑两个游戏）| 端口冲突，第二个连不上。V1 接受（单实例调试） |
| local/scope 编辑（7a 扩展）| V1 只读（context 传 null）。编辑需反向通道（编辑器→运行游戏 set_variable），后续任务 |
| 性能（0.5s JSON 推）| 扁平 Dictionary，纯标量，开销低。大变量集可限推频率 |
| Autoload 顺序 | FuseRuntimeBridge 需在 Runner 之前加载（Autoload 顺序，project.godot） |
| TCP 缓冲粘包 | JSON line（\n 分隔）+ split 解析，自然处理粘包 |

---

## 9. 决策点

| 项 | 建议 | 说明 |
|---|---|---|
| 端口 | 固定 24563 + listen 失败 warning | 简单；冲突时用户感知。或 ProjectSettings 可配 |
| 多运行实例 | V1 不支持（单实例） | 调试场景足够 |
| local/scope 编辑 | V1 只读 | 编辑需反向通道，单独任务 |
| 推送频率 | 0.5s | 与监视器刷新一致 |

---

## 10. 执行顺序

```
Day 1: 任务 A — FuseRuntimeBridge（双模式 TCP + 协议 + _collect_runners）
       + 单测：编辑器 listen + 运行游戏 connect + 收发 JSON
Day 2 上午: 任务 B — variable_watcher 改读缓存 + 集成
Day 2 下午: 任务 C — Autoload 注册 + 连接管理 + 端到端验收
```

**关键检查点:**
- A 后：运行游戏推 JSON，编辑器收到 + 缓存（print 验证）
- B 后：监视器显示运行游戏 local/scope
- C 后：停止运行 → 清空

---

## 11. 执行结果（2026-06-27）✅ 完成

TCP 桥实现 + 调试完成，运行时 local/scope 变量在编辑器变量监视器可见。

**实际工时:** ~2-3 天（实现 1 天 + 卡死调试 1-2 天，调试占大头）

**踩的坑（详见 [修复经验文档](../development/godot-streampeertcp-mainthread-pitfalls.md)）:**
1. `conn.poll()` 没调 → `!is_open` 报错刷屏（修：加 conn.poll 更新状态）
2. `_client.poll()` 每帧 → 连接卡 CONNECTING（修：节流 0.5s）
3. `put_data` 阻塞（修：`put_partial_data` 非阻塞）
4. **`get_utf8_string(-1)` 阻塞主线程**（最终卡源）→ `get_utf8_string(avail)` 精确字节
5. `class_name` vs Autoload 同名冲突（修：去 class_name）

**完成:** ✅ 运行游戏 local/scope 在编辑器变量监视器可见，不卡，停止运行→连接关闭→清空。

**状态:** ✅ 完成。修复经验详见 [Godot StreamPeerTCP 主线程阻塞陷阱](../development/godot-streampeertcp-mainthread-pitfalls.md)。
