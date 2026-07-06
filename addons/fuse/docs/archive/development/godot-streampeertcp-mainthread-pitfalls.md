# Godot StreamPeerTCP 主线程阻塞陷阱 — Fuse TCP 桥调试经验

**日期:** 2026-06-27
**场景:** [FuseRuntimeBridge](../../core/fuse_runtime_bridge.gd) TCP 桥（编辑器 Dock 访问运行游戏实例的 local/scope 变量）
**关联:** [运行时变量 TCP 桥 plan](../roadmap/2026-06-27-runtime-variable-tcp-bridge-plan.md)
**价值:** Godot 4 StreamPeerTCP 在编辑器主线程的阻塞陷阱 + 卡死诊断方法

---

## 背景

Fuse 变量监视器（编辑器 @tool 底部 Dock）需要访问**运行游戏实例**的 local/scope 变量。运行游戏和编辑器是独立进程/SceneTree，无法直接共享内存。方案：TCP 桥 —— 运行游戏每 0.5s 收集 Runner 变量，序列化 JSON line，通过 TCP（127.0.0.1:24563）推送给编辑器，编辑器接收 + 缓存 + 显示。

实现后编辑器反复**卡死**。调试耗费多轮，定位到一系列 Godot StreamPeerTCP 在主线程的阻塞陷阱。本文档记录这些陷阱 + 诊断方法，供将来参考。

**关键架构约束:** 编辑器 @tool Autoload + 嵌入运行（Embed Game Window）= 运行游戏和编辑器**共享主线程**。StreamPeerTCP 的 socket 操作若阻塞，卡的是共享主线程 = 编辑器卡死。

---

## 陷阱清单（4 个，按发现顺序）

### 陷阱 1：`conn.poll()` 没调 → 断开连接 status 陈旧 → `!is_open` 报错刷屏

**现象:** 编辑器控制台持续刷 `ERROR: Condition "!is_open()" is true. Returning: -1 at: get_available_bytes`。

**根因:** `_server_poll` 没对每个 conn 调 `conn.poll()`。运行游戏重连时旧连接断开，但 status 没更新（还显示 STATUS_CONNECTED），没被清除。`_read_json_lines` 每 帧对死连接调 `get_available_bytes` → `!is_open` 报错。

**修:** `_server_poll` 遍历连接时，对每个 conn 调 `conn.poll()`（更新状态），断开的（STATUS_NONE/ERROR）才能被清除。

```gdscript
# _server_poll
while i < _connections.size():
    var conn = _connections[i]
    conn.poll()  # 关键：poll 后 get_status 才准确
    var st = conn.get_status()
    if st == STATUS_NONE or st == STATUS_ERROR:
        # 清除
```

**教训:** Godot StreamPeerTCP 的 status **不会自动更新**，必须主动 `poll()`。

---

### 陷阱 2：`_client.poll()` 每帧 → 连接卡 CONNECTING（疑似每帧 poll 开销）

**现象:** 运行游戏 `[Bridge-Game] status=1`（CONNECTING）一直，从不到 CONNECTED。

**根因:** `_client.poll()` 每 帧 调（在 _process）。虽然 Godot 文档说 poll 非阻塞，但每帧 poll 在编辑器+运行游戏共享主线程下累积开销，连接握手不推进。

**修:** `_client.poll()` 移到节流（PUSH_INTERVAL 0.5s），和 push 一起节流，不每帧调。

```gdscript
func _client_poll(delta):
    _push_acc += delta
    if _push_acc < PUSH_INTERVAL:
        return
    _push_acc = 0.0
    _client.poll()  # 节流 0.5s，不每帧
    ...
```

**教训:** StreamPeerTCP.poll() 虽然文档说非阻塞，但在共享主线程下每帧调用有累积开销。节流（0.5s）足够推进连接 + 数据。

---

### 陷阱 3：`put_data` 阻塞（发送缓冲满时等）

**现象:** 编辑器卡死（运行游戏 `put_data` 推数据时）。

**根因:** Godot `StreamPeer.put_data(data)` **阻塞直到全部发送完成**。如果编辑器侧 `_server_poll` read 跟不上（或编辑器主线程忙），TCP 发送缓冲满，`put_data` 卡住运行游戏主线程 = 嵌入运行共享编辑器主线程 = 编辑器卡死。

**修:** 改用 `put_partial_data(data)`（非阻塞，发可用缓冲部分即返回，返回 [error, sent_bytes]）。丢弃未发送部分（下个 snapshot 覆盖，变量快照实时性优先于完整性）。

```gdscript
# put_data（阻塞）→ put_partial_data（非阻塞）
_client.put_partial_data(msg.to_utf8_buffer())
```

**教训:** `put_data` 是阻塞 API（写全部）。实时推送场景用 `put_partial_data`（非阻塞）。这是 TCP 生产消费失衡的经典坑 —— 生产者（push）比消费者（read）快时，阻塞 API 卡死。

---

### 陷阱 4：`get_utf8_string(-1)` 阻塞主线程（最隐蔽，最终卡源）⭐

**现象:** 编辑器卡死。前三个陷阱修了（poll/put_partial），还卡。

**根因:** `get_utf8_string(-1)`（-1 = 读全部可用）在 StreamPeerTCP 上**阻塞主线程**。-1 模式内部可能循环等数据，卡住编辑器主线程。

**修:** 改用 `get_utf8_string(avail)`（精确字节，avail = `get_available_bytes()`）。

```gdscript
var avail = conn.get_available_bytes()
if avail <= 0:
    return
var data = conn.get_utf8_string(avail)  # 精确字节，非 -1
```

**教训:** `get_utf8_string(-1)` 在 StreamPeerTCP 上阻塞。**永远用精确字节（avail）**，不用 -1。这是最难发现的 —— 文档没明确说 -1 阻塞，且只在有数据时触发（无数据时 avail 0 早 return）。

---

## 陷阱 5（非阻塞，但踩了）：class_name vs Autoload 同名冲突

**现象:** `get_cached_vars() non-static on class FuseRuntimeBridge directly`。

**根因:** `fuse_runtime_bridge.gd` 有 `class_name FuseRuntimeBridge` + Autoload 同名注册。GDScript 解析 `FuseRuntimeBridge` 当类（class_name 优先），调实例方法 `get_cached_vars()` 报 non-static。

**修:** 去 `class_name`（参照 FuseEventBus，Autoload 名即实例，不加 class_name）。或访问方改用 node 路径（`get_node_or_null("FuseRuntimeBridge")`）避免全局/class_name 歧义。

**教训:** Autoload 已注册全局名，**不要再加 class_name**（同名冲突）。

---

## 诊断方法：二分定位（卡死无错误时的有效手段）

卡死时通常没有错误输出（主线程卡，print 不刷）。**禁用逐步缩小**是有效方法：

```
1. 禁全 bridge（_process return）→ 不卡 → bridge 是源
2. 禁运行游戏侧 _client_poll → 不卡 → 运行游戏侧
3. _client.poll 节流 → 还卡 → 不是 poll
4. 禁 _push_snapshot → 不卡 → _push_snapshot
5. 禁 put_data（保留 find_children + JSON）→ 不卡 ← ⚠️ 漏洞：运行游戏不推 = 编辑器无数据不 read
6. 禁 _read_json_lines → 不卡 → 编辑器 read
7. get_utf8_string(avail)（不 -1）→ 不卡 → get_utf8_string(-1) 是卡源
```

**关键教训（陷阱 5 的漏洞）:** 禁 put_data 时，运行游戏不推 → 编辑器收不到数据 → `_read_json_lines` 的 `get_available_bytes` 返回 0 → 早 return。所以"禁 put_data 不卡"**无法区分**「put_data 阻塞」vs「编辑器 read 阻塞」—— 两者都被禁用了。

正确做法：禁 put_data 后，应改用**假数据注入**（编辑器侧模拟数据 read），才能区分。或像步骤 6-7 那样，在编辑器 read 内部继续细分（恢复 put，禁 read 的各步骤）。

**二分定位原则:** 禁用 A 不卡，只说明 A 链路有卡源，但要注意 A 的副作用（禁 A 可能连带禁 B）。

---

## 修法总结（Godot StreamPeerTCP 主线程安全清单）

| 操作 | ❌ 卡 | ✅ 安全 |
|---|---|---|
| 读数据 | `get_utf8_string(-1)` | `get_utf8_string(avail)`（精确字节）|
| 写数据 | `put_data` | `put_partial_data`（非阻塞）|
| 状态推进 | 不调 poll | `poll()`（conn 每帧 / client 节流）|
| Autoload | 加 class_name | 不加 class_name（Autoload 名即实例）|

---

## 架构教训

1. **编辑器 @tool + 嵌入运行 = 共享主线程。** 运行游戏和编辑器的 socket/重负载操作都在主线程，互相影响。任何阻塞操作卡的是共享主线程。

2. **Godot StreamPeerTCP 的 API 文档不够明确阻塞语义。** `get_utf8_string(-1)` 和 `put_data` 都阻塞，但文档没强调。实测才发现。

3. **纯 GDScript 跨进程通信（TCP 桥）可行，但要避开主线程阻塞。** 这套 TCP 桥让纯 GDScript 实现了"编辑器访问运行游戏变量"（不用 C++ GDExtension，不用 Godot 远程调试 API）。

4. **卡死诊断用二分定位（禁用逐步）。** 但注意副作用（禁 A 连带禁 B）。

---

## 参考

- [FuseRuntimeBridge 实现](../../core/fuse_runtime_bridge.gd)（已修复，完整工作）
- [运行时变量访问调研](../roadmap/2026-06-27-runtime-variable-access-research.md)（为何走 TCP 桥而非 Godot 远程调试）
- [TCP 桥 plan](../roadmap/2026-06-27-runtime-variable-tcp-bridge-plan.md)（架构 + 任务分解）
- Godot 文档 [StreamPeerTCP](https://docs.godotengine.org/en/4.7/classes/class_streampeertcp.html)（注意：-1/put_data 阻塞未明确）
