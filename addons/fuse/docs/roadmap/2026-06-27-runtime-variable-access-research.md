# 运行时变量访问调研 — 变量监视器 local/scope 运行时可见

**日期:** 2026-06-27
**关联:** [Stage 7 plan](2026-06-27-stage7-implementation-plan.md) · [Stage 7 实施代码](../../editor/debugging/variable_watcher.gd)
**Godot 源码:** `E:\GitHub\godot`（4.8 dev，调试协议与 4.7 稳定版一致）
**状态:** 调研完成，待方案决策

---

## 1. 背景

Stage 7 变量监视器 V2 验收发现：运行游戏时 local/scope 变量不可见。

**根因:** [variable_watcher.gd `_collect_runtime_variables`](../../editor/debugging/variable_watcher.gd#L309) 用 `EditorInterface.get_edited_scene_root()` 扫**编辑场景**的 Runner，但运行游戏（F5/F6）是**独立进程/SceneTree**，运行中持有 `current_execution_context` 的 Runner 在游戏实例里，不在编辑场景。所以扫到的编辑场景 Runner 都是 `ec == null` → local/scope 空。

这是 **Stage 2c V1 既有限制**（不只 Stage 7），roadmap 标注「场景运行后 local/scope 可见」从未真正实现。

---

## 2. Godot 远程调试调研结论（核心限制）

调研 Godot 源码 `E:\GitHub\godot`（4.8 dev），结论明确 —— **GDScript @tool 几乎拿不到运行游戏的 API**：

| 调研项 | 结论 | 源码依据 |
|---|---|---|
| EditorInterface 远程调试入口 | **无** | `editor_interface.cpp:846-862` bind 清单无 `get_debugger`/`get_remote_*` |
| EditorDebuggerNode 的 `request_remote_tree`/`request_remote_objects`/`request_remote_evaluate` | **未 bind ClassDB**（GDScript 不可用） | `editor_debugger_node.cpp:220-228` 只暴露 `live_debug_*` |
| 协议 RPC（调运行游戏方法） | **无** | 协议只有属性读写 + `evaluate`（且 evaluate 仅断点 breaked 时） |
| RefCounted 序列化（穿透 Runner→ExecutionContext→VariableContext） | **不可穿透** | `scene_debugger_object.cpp:189` 对无路径 RefCounted 只发 `EncodedObjectAsID`（仅 ObjectID，无内容） |
| EngineDebugger 暴露 GDScript | **否** | `core/debugger/engine_debugger.h` 是 C++ 单例，GDScript 不能 `EngineDebugger.get_singleton()` |
| 通信 | TCP 单连接串行 | `remote_debugger.cpp:264/289/378` MutexLock，受 `max_message_size` 限制 |

**底层协议消息**（C++ 内部，仅编辑器自用）：
- `scene:request_scene_tree` — 请求节点树
- `scene:inspect_objects` — 请求 ObjectID 属性快照
- `evaluate` — 表达式求值（仅 breaked）
- `scene:set_object_property` — 远程改属性
- 运行端注册：`scene/debugger/scene_debugger.cpp:74` `register_message_capture`

---

## 3. 可行性矩阵

| 场景 | 可行 | 限制 |
|---|:--:|---|
| 编辑器→运行游戏：读 Node 普通属性 | 部分 | 需绕过未暴露 API（GDScript 拿不到） |
| 编辑器→运行游戏：读 RefCounted（`current_execution_context`） | ❌ | 序列化为 ObjectID，无内容 |
| 编辑器→运行游戏：读深层对象（`context._variable_context`） | ❌ | RefCounted 无法穿透 |
| 编辑器→运行游戏：调方法（`get_all_local_variables_snapshot()`） | ❌ | 协议无 RPC |
| **运行游戏→编辑器：推送扁平快照** | ✅ | 需 C++ 桥接 `send_message`（GDScript 直调不到 EngineDebugger） |

**关键不对称:** 不能「编辑器拉」，只能「运行游戏推」。且推送需 C++ 桥接（EngineDebugger 未暴露 GDScript）。

---

## 4. 方案选项

### 方案 A — C++ GDExtension 调试器桥接（完整方案）⭐

**思路:**
1. C++ 侧写 `FuseDebuggerPlugin`（继承 `EditorDebuggerPlugin`），注册 `fuse:variables` 消息处理器
2. C++ 侧暴露 `Fuse.debug_send_snapshot(dict)` helper（包装 `EngineDebugger::send_message`）
3. 运行游戏 Runner 在 `_process`（节流 0.5s）调 `Fuse.debug_send_snapshot(VariableContext.get_all_local_variables_snapshot() + get_all_scope_variables_snapshot())` —— 扁平 Dictionary（无 RefCounted 嵌套）
4. 编辑器侧 `FuseDebuggerPlugin` 收 `fuse:variables` → 缓存 → `variable_watcher.gd` 从缓存读（替代 `get_edited_scene_root`）

**优点:** Godot 官方 LiveEdit/Profiler 同款机制（`scene_debugger.cpp:74` register_message_capture），稳定可靠，0.5s 推送安全。
**缺点:** **改变 Fuse 发布模型** —— 从纯 GDScript 插件变成含 C++ 二进制（GDExtension，需多平台编译），违背「轻量纯 GDScript」定位。工作量大（C++ + GDExtension + 多平台构建）。

### 方案 B — 纯 GDScript 文件中转（轻量方案）

**思路:**
1. 运行游戏 Runner 在 `_process`（节流 0.5s）把 local/scope 快照写到 `user://fuse_runtime_vars.json`
2. 编辑器 `variable_watcher.gd` 读该 JSON（替代 `get_edited_scene_root`）

**优点:** 纯 GDScript，不改发布模型，实现简单（~50 行）。
**缺点:** 文件 I/O 性能差（0.5s 写读磁盘），可靠性低（文件竞争/丢失），跨平台 user:// 路径差异。仅够「调试用」，不适合高频。

### 方案 C — 接受现状（不修）

**思路:** local/scope 运行时不可见作为**已知限制**记入文档。变量监视器聚焦：
- global（编辑器 + 运行共享 .tres 资源，可见 + 可编辑）
- 静态声明（7c，编辑模式指令链引用，不依赖运行实例）
- snapshot（7d，运行时 global + 编辑场景数据）

**优点:** 零工作量。
**缺点:** local/scope 运行时调试仍是空白（Stage 2c/7 原始目标未达）。

---

## 5. 推荐与决策点

**推荐:** 视 Fuse 发布定位而定 ——

- 若坚持「纯 GDScript 轻量插件」定位 → **方案 C**（接受）或 **B**（轻量调试用）
- 若接受 C++ 依赖（GDExtension）换取完整运行时调试 → **方案 A**（完整）

**关键决策（待 Kai 定）:**

1. **是否引入 C++ GDExtension**（方案 A）—— 改变发布模型（纯 GDScript → 含二进制），需多平台编译。这是根本性的定位选择。
2. **若不引入 C++**（B/C）—— local/scope 运行时可见的优先级如何？是否值得文件中转的代价（B）？还是接受限制（C）？
3. **替代思路:** 是否考虑把变量监视器**移到运行游戏内**（RuntimeWatcher，游戏自带 UI 面板，直接读 Runner context）—— 不走编辑器远程，纯运行时本地。但这要游戏内 UI（overlay），不是编辑器 Dock。

---

## 6. 约束与风险

| 项 | 说明 |
|---|---|
| Godot 远程调试协议 | 无 RPC + RefCounted 不可穿透 —— 任何方案都只能「运行游戏推扁平快照」，不能「编辑器拉深层对象」 |
| EngineDebugger 未暴露 GDScript | 方案 A 必须 C++ 桥接，无纯 GDScript 捷径 |
| 协议串行 | 推送频率 ≤ 0.5s 安全，60fps 会卡主线程（Mutex） |
| 跨进程隔离 | 编辑器与运行游戏是两个进程，任何内存共享（Autoload/Service）都不跨进程 |
| 发布模型 | 方案 A 引入 C++ 二进制，影响 Fuse 独立发布（commit bd3f183 仓库拆分定位） |

---

## 7. 下一步

等 Kai 决策（A/B/C + 是否接受 C++）：
- 选 A → 写 C++ GDExtension 实施计划（FuseDebuggerPlugin + send_message 桥接）
- 选 B → 改 variable_watcher.gd 文件中转（轻量，~50 行）
- 选 C → 更新 roadmap/文档标 local/scope 运行时可见为已知限制

---

**调研方法说明:** 基于 Godot 4.8 dev 源码（`E:\GitHub\godot`）审计 EditorInterface/EditorDebuggerNode/SceneDebugger/EngineDebugger 的 bind_methods + 协议消息 + 序列化逻辑。所有结论带源码 file:line 引用可复核。协议与 4.7 稳定版一致。
