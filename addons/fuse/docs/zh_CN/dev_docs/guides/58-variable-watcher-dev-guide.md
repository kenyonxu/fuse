> 🌐 中文 | [**English**](../../../en_US/dev_docs/guides/58-variable-watcher-dev-guide.md)

# 变量监视器开发指南

> **目标**: 为开发者提供 `FuseVariableWatcher` 的架构说明与扩展指引，覆盖数据源接入、轮询刷新机制、UI 构建模式、Stage 7 功能（双击编辑/折线图/静态声明/快照）的实现细节与性能设计。

**适用对象**: Fuse 系统开发者、编辑器插件贡献者

**最后更新**: 2026-09-04

**配套用户文档**: [56-variable-watcher-guide.md](../../user_docs/guides/56-variable-watcher-guide.md)

---

## 📋 目录

1. [系统架构总览](#系统架构总览)
2. [数据源接入](#数据源接入)
3. [轮询与刷新机制](#轮询与刷新机制)
4. [UI 构建模式](#ui-构建模式)
5. [Stage 7a — 双击编辑](#stage-7a--双击编辑)
6. [Stage 7b — 历史折线图](#stage-7b--历史折线图)
7. [Stage 7c — 静态声明分区](#stage-7c--静态声明分区)
8. [Stage 7d — 快照导出](#stage-7d--快照导出)
9. [WatcherUI 扩展指南](#watcherui-扩展指南)
10. [性能设计](#性能设计)
11. [常见陷阱](#常见陷阱)

---

## 系统架构总览

`FuseVariableWatcher`（`editor/debugging/variable_watcher.gd`）是嵌入编辑器底部 Dock 的实时变量监视面板，`extends Control`，由 `plugin.gd` 在插件激活时创建：

```gdscript
# addons/fuse/plugin.gd
var _watcher: FuseVariableWatcher = null

func _enter_tree() -> void:
	_watcher = preload("res://addons/fuse/editor/debugging/variable_watcher.gd").new()
	add_control_to_bottom_panel(_watcher, "Fuse Variables")

func _exit_tree() -> void:
	if _watcher:
		remove_control_from_bottom_panel(_watcher)
		_watcher = null
```

### 数据源架构

监视器本身**不直接访问游戏场景**，而是通过三个数据源间接获取变量：

```
┌───────────────────────────────────────────────────────┐
│             FuseVariableWatcher (Bottom Dock)          │
│                                                        │
│  0.5s Timer ──→ _refresh() ──┬── Local/Scope 分区      │
│                              ├── Global 分区           │
│                              └── 静态声明分区 (5s 缓存) │
└──────┬────────────────┬────────────────┬──────────────┘
       │                │                │
       ▼                ▼                ▼
 FuseRuntimeBridge  GlobalVariableService  InstructionAnalyzer
 (Autoload, TCP)    (→ Manager 单例)       (编辑器静态拓扑)
       │ ▲
       │ └── set_var（编辑器 → 游戏写回，target = container/unit/global）
       ▼
 运行中的游戏（TCP 客户端，每 0.5s 推送 JSON line，并应用 set_var）
   ├─ BaseTrigger / Runner → "units"（local 取最近执行上下文）
   ├─ ScopeVariableContainer → "containers"
   └─ GlobalVariableManager → "global"（仅标量）
```

| 数据源 | 提供内容 | 可用时机 |
|--------|----------|----------|
| `FuseRuntimeBridge` | v3 快照：`units`（BaseTrigger/MultiEventTrigger/Runner 的 local 变量，宿主直报）+ `containers`（ScopeVariableContainer 变量） | 场景运行中 |
| `GlobalVariableService` | 全局变量名称/值/类型 | 始终可用 |
| `InstructionAnalyzer` | Trigger 指令链的变量声明（静态） | 编辑器模式 |

---

## 数据源接入

### FuseRuntimeBridge（TCP 桥）

`FuseRuntimeBridge`（`core/fuse_runtime_bridge.gd`，`extends Node`，Autoload）是**双模式** TCP 桥：

| 模式 | 运行侧 | 行为 |
|------|--------|------|
| TCPServer | 编辑器 | 监听 `127.0.0.1:24563`，接收推送，缓存到 `_cached` |
| TCP 客户端 | 运行游戏 | 连接 `127.0.0.1:24563`，每 0.5s 收集并推送快照 |

**关键常量**：

```gdscript
const BRIDGE_PORT := 24563
const PUSH_INTERVAL := 0.5
```

**协议（v3，`proto = 3`）**: TCP 流 + JSON line（`\n` 分隔）：

```json
{"t":"vars","proto":3,
 "containers":[{"id":99001,"path":"/World/LevelScope","scope_id":"level1","vars":{"alert":50}}],
 "units":[{"id":123456,"path":"/Main/Runner1","kind":"runner","ago_ms":5,"local":{"health":85}}],
 "global":{"score":2450}}
```

非标量值以只读包装 `{"__complex":"str(v) ≤200字符","ty":"Vector2"}` 到达。完整字段表与写回语义见 [Runtime Bridge 开发指南](runtime-bridge-guide.md)。

**监视器消费接口**：

```gdscript
## 编辑器侧：获取缓存的运行时变量（v3 双键结构）
## 返回 {"containers": [容器条目...], "units": [单元条目...]}
func get_cached_vars() -> Dictionary
```

监视器在 `_collect_runtime_variables()` 中调用该方法，将缓存转换为行数据。

### GlobalVariableService

全局变量分区通过服务层读取（而非直接访问 Manager）：

```gdscript
var service := GlobalVariableService.new()
var info: Dictionary = service.get_all_global_variables_info()
# → {name: {"value": ..., "type": "int", ...}, ...}
```

服务层细节见 [59-global-variables-dev-guide.md](59-global-variables-dev-guide.md)。

### InstructionAnalyzer（静态声明）

编辑器模式下扫描场景 Trigger 拓扑，汇总变量声明（名称/作用域/读写模式/引用处数）。该扫描开销较大，走 **5 秒独立缓存**（见下文）。

---

## 轮询与刷新机制

面板由 0.5 秒 `Timer` 驱动：

```gdscript
_timer.wait_time = 0.5
_timer.autostart = true
_timer.timeout.connect(_on_timer)

func _on_timer() -> void:
	_refresh()
```

### `_refresh()` 执行流程

```
1. if _editing: return                    ← 编辑中整体跳过（保护 LineEdit）
2. 清空 _content（VBoxContainer）
3. _collect_runtime_variables()           ← 从 Bridge 缓存收集 Local + Scope 行
                                             （v3 键："units" → Local 按宿主分组，
                                              "containers" → Scope 按容器分组；
                                              字段缺失降级空集）
4. GlobalVariableService 收集 global 变量
5. _record_history() 记录数值历史（仅 int/float）
6. _render_grouped_section() × 2 + 平铺渲染 ← Local / Scope 分组，Global 平铺
7. _render_static_declarations()          ← 静态分区（5s 间隔缓存）
8. _update_history_graph()                ← 刷新底部折线图
9. 更新状态标签（Global:N  Unit:M  Ctn:K）
```

> **设计要点**: 每帧**全量重建** UI 行（简单可靠），依赖 `_editing` 标志避免销毁正在编辑的控件。行数量级（几十到几百）下该策略性能可接受。

---

## UI 构建模式

监视器全部 UI 由代码构建（无 `.tscn`），遵循**行数据 Dictionary → 行控件** 的模式。

### 颜色常量

```gdscript
const COL_NAME := Color(0.1, 0.15, 0.3)    # 深蓝 — 变量名
const COL_VALUE := Color(0.1, 0.25, 0.15)  # 深绿 — 值
const COL_TYPE := Color(0.15, 0.15, 0.15)  # 浅黑 — 类型
const COL_HEADER := Color(0.2, 0.3, 0.5)   # 分区标题蓝
```

### 构建函数分层

| 函数 | 职责 |
|------|------|
| `_make_header_row()` | 三列标题行（变量 ∥ 值 ∥ 类型） |
| `_make_section_header(title)` | 分区标题（Local/Scope/Global/静态） |
| `_make_var_row(var_name, encoded, extra)` | 构造行数据 Dictionary |
| `_make_data_row(data)` | 行数据 → HBoxContainer 控件 |
| `_make_value_panel(data)` | 值列（支持双击编辑的 PanelContainer） |
| `_make_label_panel(text, color, pass_mouse)` | 普通文本列 |
| `_render_grouped_section(parent, title, groups, rows, filter)` | 渲染整个分组分区（组头 + 变量行，含搜索过滤） |

### 行数据结构

`_make_var_row()` 产出的 Dictionary 是渲染与编辑的统一数据载体，核心键：

| 键 | 说明 |
|----|------|
| `name` | 变量名 |
| `value` | 显示值（字符串化） |
| `type` | 类型字符串（`int`/`float`/`Vector2`/...） |
| `target` / `id` | v3 写回目标（`container`/`unit`/`global`）与宿主/容器实例 id |
| `group_key` / `group_path` | 所属分组（`u<id>` / `c<id>` / `global`）及显示路径（组头 + 过滤） |
| `var_key` | 历史记录键（v3 方案）：`local:<单元路径>/<名>`、`scope:<容器路径>/<名>`、`global/<名>` |

> **扩展要点**: 新增分区时复用 `_make_var_row()` + `_render_grouped_section()`，在 `extra` 中传入分区特有的键（如组路径、是否可编辑）。

---

## Stage 7a — 双击编辑

### 交互流程

```
双击值列 → _on_value_gui_input() → _enter_edit_mode()
    ↓ Label 替换为 LineEdit，_editing = true
Enter 提交 → _on_value_submitted() ┐
失焦提交 → _on_focus_exited()     ┴→ _finish_edit()
    ↓
_coerce_value(text, type_str)     ← 类型转换（失败返回 null，中止写回）
    ↓
按 scope 写回 → _restore_label()  ← 恢复 Label，_editing = false
```

### 写回目标（v3，按 `target`）

| 目标 | 写回方式 | 可用时机 |
|--------|----------|----------|
| `unit` | `bridge.send_set_var("unit", id, name, value)` → 由运行游戏应用（写宿主组件的最近执行上下文） | 运行时（行来自运行游戏，`id` 可定位） |
| `container` | `bridge.send_set_var("container", id, name, value)` → 由运行游戏应用（写容器变量） | 运行时（同上） |
| `global` | 游戏已连接：`send_set_var("global", 0, name, value)`（仅已存在的变量）；否则 `_write_back_global()` → `set_variable_value_thread_safe()`（保留元数据；仅缺失时创建） | 始终可用 |

### 类型转换（`_coerce_value`）

| 目标类型 | 规则 |
|----------|------|
| `int` | `text.is_valid_int()` → `to_int()` |
| `float` | `text.is_valid_float()` → `to_float()` |
| `bool` | 匹配 `"true"` / `"1"` / `"是"` / `"yes"` |
| `String` | 原样返回 |
| 其他 | 最佳努力，原样返回 |

**返回值约定**: 返回 `null` 表示转换失败，调用方**必须中止写回**（不破坏原值）。

### 编辑保护

```gdscript
var _editing: bool = false  # 编辑中标志

func _refresh() -> void:
	if _editing:
		return  # 跳过重建，避免销毁 LineEdit
```

---

## Stage 7b — 历史折线图

### 历史记录

```gdscript
const HISTORY_MAX := 120  # 60s / 0.5s = 120 帧滑动窗口

var _history: Dictionary = {}   # var_key → Array[float]
var _selected_var_key: String = ""
```

`_record_history(var_key, value, type_str)` 规则：

- 仅记录 `int` / `float`（其他类型直接忽略）
- 键方案（v3，`_record_history` 与行选中经 `_history_key` 共用）：`local:<单元路径>/<名>`、`scope:<容器路径>/<名>`、`global/<名>`（如 `"global/player_score"`）
- 超过 `HISTORY_MAX` 时弹出最旧帧

### HistoryGraph 组件

```gdscript
class HistoryGraph extends Control:
	# 嵌套类，绘制逻辑：
	# 1. 取 _history[_selected_var_key]
	# 2. 归一化到 [0, 1] 范围
	# 3. draw_polyline() 绘制折线（淡蓝 0.4, 0.8, 1.0）
	# 4. 无数据时绘制灰色占位文本 "(无数值历史)"
```

行选中通过 `_on_row_gui_input()` 实现：单击行 → 设置 `_selected_var_key` → `_update_history_graph()` 切换显示。

---

## Stage 7c — 静态声明分区

编辑器模式下扫描场景 Trigger 指令拓扑，展示**变量声明信息**（非实时值）。

### 缓存机制

```gdscript
var _cached_static_rows: Array[Dictionary] = []
var _last_static_refresh_ms: int = 0
const STATIC_REFRESH_INTERVAL_MS := 5000
```

拓扑扫描开销大（遍历全部 Trigger + 指令链），因此**独立于 0.5s 轮询**，每 5 秒才重新执行 `_collect_static_var_rows(topology)`，其余刷新直接渲染缓存行。

### 行格式

```
[cooldown      | (静态) | local · 读写 · 2处]
[player_health | (静态) | scope · 读写 · 1处]
[level_score   | (静态) | global · 读 · 3处]
```

- 值列固定 `(静态)`
- 类型列：`{作用域} · {访问模式} · {引用处数}`，访问模式 = 读 / 写 / 读写

---

## Stage 7d — 快照导出

```gdscript
## 生成当前时刻全量变量快照
func get_snapshot() -> Dictionary
# → {"timestamp": ..., "global": {...}, "containers": [...], "units": [...]}

func _on_snapshot() -> void:
	# 序列化为 JSON 写入 user://fuse_watcher_snapshot_{时间戳}.json
```

快照结构（v3：桥缓存条目直通）：

```json
{
	"timestamp": 1234.567,
	"global": {"player_score": {"value": 2450, "type": "int"}},
	"containers": [
		{"id": 99001, "path": "/World/LevelScope", "scope_id": "level1",
		 "vars": {"alert_level": {"value": 50, "type": "int"}}}
	],
	"units": [
		{"id": 123456, "path": "/Main/Runner1", "kind": "runner", "ago_ms": 5,
		 "local": {"health": {"value": 85, "type": "int"}}}
	]
}
```

> **扩展要点**: `get_snapshot()` 是公开方法，可直接被其他调试工具（如自动测试报告）调用，无需经过 UI。

---

## WatcherUI 扩展指南

### 添加新分区

```gdscript
func _refresh() -> void:
	# ... 现有分区 ...
	_render_my_section(_content, _filter_text)

func _render_my_section(parent: VBoxContainer, filter: String) -> void:
	var groups: Array = [{"key": "my", "path": "/My Section"}]
	var rows: Array[Dictionary] = []
	for item in _collect_my_data():
		rows.append(_make_var_row(item.name, item.value, {
			"target": "global",
			"id": 0,
			"group_key": "my",
			"group_path": "/My Section",
		}))
	_render_grouped_section(parent, "My Section", groups, rows, filter)
```

### 扩展行数据

行数据 Dictionary 可携带自定义键，在 `_make_data_row()` 中按键分支渲染。新增可编辑类型时在 `_coerce_value()` 中添加转换分支。

### 接入新的运行时数据源

1. 在游戏侧扩展 `FuseRuntimeBridge._push_snapshot()` 的 JSON 负载
2. 在编辑器侧扩展 `_update_cache()` 的缓存结构
3. 在 `_collect_runtime_variables()` 中读取新字段并生成行

> **注意**: Bridge 协议是 JSON line，新增字段向后兼容（旧版本解析器忽略未知键）。

---

## 性能设计

| 机制 | 开销控制 |
|------|----------|
| 0.5s 轮询 | 避免逐帧刷新；与 Bridge 推送频率一致（0.5s），不会读到半更新状态 |
| 全量重建 UI | 行数 < 几百时可接受；编辑中 `_editing` 跳过重建 |
| 静态声明 5s 缓存 | 拓扑扫描与高频轮询解耦（`STATIC_REFRESH_INTERVAL_MS = 5000`） |
| 历史仅数值 | `int`/`float` 才进 `_history`，String/Vector 等零开销 |
| 历史定长窗口 | `HISTORY_MAX = 120`，超出即弹出，内存恒定 |
| 搜索过滤在渲染层 | 过滤不改变数据收集，仅跳过行创建 |

**已知开销点**（扩展时注意）：

- `_collect_static_var_rows()` 遍历全部 Trigger — 不要放进 0.5s 轮询
- 每行 3 个 PanelContainer — 行数爆炸时考虑 `VBoxContainer` 虚拟化（当前未实现）

---

## 常见陷阱

### 陷阱 1: 编辑中被轮询重建销毁 LineEdit

**问题**: 0.5s 刷新重建 UI，正在输入的 LineEdit 被释放。

**解决**: 已进入编辑必须置 `_editing = true`；`_refresh()` 开头检查该标志直接返回。

### 陷阱 2: 编辑提交时游戏可能已退出

**问题**: 行渲染自最近一次推送的快照，从渲染某行到提交编辑之间游戏可能已退出。无存活连接时 `send_set_var` 返回 `false`，值永远到不了游戏。

**解决**: 把 `false` 返回视为写回失败——恢复原显示值并警告（`FUSE_UI_WATCHER_EDIT_NO_CONNECTION`）。`_editing` 结束后的下一次推送会自然把显示校正回游戏侧权威值。（`_coerce_value` 转换失败仍会静默中止写回——那是输入问题，不是连接问题。）

### 陷阱 3: 直接访问 GlobalVariableManager 绕过服务层

**问题**: 面板各处直接 `GlobalVariableManager.get_instance()`，与 Assistant 信号流脱节。

**解决**: 读取走 `GlobalVariableService.get_all_global_variables_info()`；写回走 `_write_back_global()` 统一入口。

### 陷阱 4: 历史键不含作用域

**问题**: 不同作用域同名变量共用历史曲线，数据互相污染。

**解决**: 键必须用 v3 方案——`local:<单元路径>/<名>`、`scope:<容器路径>/<名>`、`global/<名>`（`_history_key` 已约定，`_record_history` 与行选中两端同键，否则折线图静默失效）。

### 陷阱 5: 静态扫描放进高频轮询

**问题**: `_collect_static_var_rows()` 每 0.5s 执行，编辑器卡顿。

**解决**: 使用 `_last_static_refresh_ms` + `STATIC_REFRESH_INTERVAL_MS` 节流。

### 陷阱 6: Bridge 推送与轮询频率不一致

**问题**: 修改 `PUSH_INTERVAL` 后监视器仍按 0.5s 假设工作（历史窗口时长错位）。

**解决**: 历史窗口语义 `HISTORY_MAX × PUSH_INTERVAL = 显示秒数`，改频率时同步调整注释与文档。

### 陷阱 7: 对象值导致的"假 String"行（v2 遗留——已消除）

**问题**: v2 把 `Object` 值序列化成裸字符串推送，编辑器无法与真 `String` 行区分，会对不可编辑的值提供编辑。

**解决**: v3 协议将非标量以只读包装 `{"__complex": "str(v) ≤200字符", "ty": "Vector2"}` 编码——根源已在协议层消除（类型列显示真实类型名，行不可编辑）。游戏侧非标量闸门仍保留，作为手造消息的最后防线。

### 陷阱 8: 运行结束后 local 行消失（设计说明）

**问题**: 早期设计在执行结束即焚毁上下文（"即焚"），Trigger/Runner 跑完后无数据可报。

**解决**: v3 改为保留**最近**执行上下文：BaseTrigger（`_create_execution_context`）、MultiEventTrigger 与 Runner 均赋值 `current_execution_context` / `current_execution_context_at_ms`，单元持续上报最近一次运行的 local，`ago_ms` 新鲜度字段让面板对超时宿主（> 5s）灰显。

### 陷阱 9: 折叠状态跨刷新丢失

**问题**: 0.5s 刷新全量重建 UI，用户折叠的组会在下一帧弹开。

**解决**: 折叠状态存于成员字典 `_collapsed`，按组 id 键（`u<id>` / `c<id>`）而非重建的控件；`_render_grouped_section()` 每次重建时查询。搜索过滤激活时忽略折叠状态，命中行始终显示。

---

## 总结

变量监视器开发核心要点：

1. ✅ **三数据源分离** — Bridge（运行时 local/scope）∥ Service（global）∥ Analyzer（静态声明）
2. ✅ **TCP 双模式桥** — 编辑器 TCPServer / 游戏客户端，JSON line 协议，0.5s 推送
3. ✅ **行数据 Dictionary 模式** — `_make_var_row()` → `_make_data_row()`，新分区复用 `_render_grouped_section()`
4. ✅ **编辑保护** — `_editing` 标志阻止轮询重建；`_coerce_value` 返回 null 中止写回；可编辑性本身由 `_is_row_editable` 门控（标量类型 + 作用域可定位）
5. ✅ **性能节流** — 0.5s 轮询 + 5s 静态缓存 + 120 帧定长历史
6. ✅ **公开快照接口** — `get_snapshot()` 可供外部工具直接调用
7. ✅ **v3 宿主直报协议** — 推送 `{containers, units, global}`（非标量以 `__complex` 只读包装），写回按 `target`（container/unit/global）三分发，Local/Scope 分区按宿主/容器分组、折叠状态按组 id 键保持

**参考文档**:
- [变量监视器使用指南](../../user_docs/guides/56-variable-watcher-guide.md)
- [全局变量开发指南](59-global-variables-dev-guide.md)
- [Runtime Bridge 开发指南](runtime-bridge-guide.md)
- [调试系统用户指南](../../user_docs/guides/25-debugging-guide.md)

---

**文档维护**: Fuse 开发团队
**最后更新**: 2026-09-04
