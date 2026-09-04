> 🌐 中文 | [**English**](../../../en_US/dev_docs/guides/58-variable-watcher-dev-guide.md)

# 变量监视器开发指南

> **目标**: 为开发者提供 `FuseVariableWatcher` 的架构说明与扩展指引，覆盖数据源接入、轮询刷新机制、Tree 展示层（三级增量 diff / 折叠持久 / 过滤集重建 / 编辑定位）与双击编辑、折线图的实现细节与性能设计。

**适用对象**: Fuse 系统开发者、编辑器插件贡献者

**最后更新**: 2026-09-04

**配套用户文档**: [56-variable-watcher-guide.md](../../user_docs/guides/56-variable-watcher-guide.md)

---

## 📋 目录

1. [系统架构总览](#系统架构总览)
2. [数据源接入](#数据源接入)
3. [轮询与刷新机制](#轮询与刷新机制)
4. [Tree 展示层（FuseVariableWatcherTree）](#tree-展示层fusevariablewatchertree)
5. [Stage 7a — 双击编辑](#stage-7a--双击编辑)
6. [Stage 7b — 历史折线图](#stage-7b--历史折线图)
7. [扩展指南](#扩展指南)
8. [性能设计](#性能设计)
9. [常见陷阱](#常见陷阱)

---

## 系统架构总览

`FuseVariableWatcher`（`editor/debugging/variable_watcher.gd`）是嵌入编辑器底部 Dock 的实时变量监视面板，`extends Control`，由 `plugin.gd` 在插件激活时创建。展示层拆分为独立组件 `FuseVariableWatcherTree`（`editor/debugging/variable_watcher_tree.gd`，`extends Tree`）：

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

主文件按职责分两层：

| 层 | 职责 |
|----|------|
| 数据层（纯函数，测试覆盖） | 桥读取、`_rows_from_cached`、`_make_var_row`、`_is_row_editable`、`_history_key`、`_coerce_value`、`_finish_edit` 分发、`_write_back_global` |
| 展示层 | `FuseVariableWatcherTree`（三级树）、顶栏（搜索 + 状态摘要）、底部图区（选中展开）、空态叠层 |

### 数据源架构

监视器本身**不直接访问游戏场景**，而是通过两个数据源间接获取变量：

```
┌───────────────────────────────────────────────────────┐
│             FuseVariableWatcher (Bottom Dock)          │
│                                                        │
│  0.5s Timer ──→ _refresh() ──┬── apply_data()（三级树） │
│                              └── apply_global()（GLOBAL 根）│
└──────┬───────────────────────────────┬─────────────────┘
       │                               │
       ▼                               ▼
 FuseRuntimeBridge              GlobalVariableService
 (Autoload, TCP)                (→ Manager 单例)
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
| `FuseRuntimeBridge` | v3 快照：`units`（BaseTrigger/MultiEventTrigger/Runner 的 local 变量，宿主直报）+ `containers`（ScopeVariableContainer 变量）+ `scene`（当前场景名） | 场景运行中 |
| `GlobalVariableService` | 全局变量名称/值/类型 | 始终可用（游戏运行中改读游戏侧实时快照） |

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
 "scene":"Main",
 "containers":[{"id":99001,"path":"/World/LevelScope","scope_id":"level1","vars":{"alert":50}}],
 "units":[{"id":123456,"path":"/Main/Runner1","kind":"runner","ago_ms":5,"local":{"health":85}}],
 "global":{"score":2450}}
```

`scene` 为游戏侧当前场景名（缺省为空字符串），供 Tree 层做场景归组。非标量值以只读包装 `{"__complex":"str(v) ≤200字符","ty":"Vector2"}` 到达。完整字段表与写回语义见 [Runtime Bridge 开发指南](runtime-bridge-guide.md)。

**监视器消费接口**：

```gdscript
## 编辑器侧：获取缓存的运行时变量（v3 双键结构）
## 返回 {"containers": [容器条目...], "units": [单元条目...]}
func get_cached_vars() -> Dictionary
```

监视器在 `_refresh()` 中读取该缓存，经 `_rows_from_cached()` 转换为行数据。

### GlobalVariableService

全局变量分区通过服务层读取（而非直接访问 Manager）：

```gdscript
var service := GlobalVariableService.new()
var info: Dictionary = service.get_all_global_variables_info()
# → {name: {"value": ..., "type": "int", ...}, ...}
```

服务层细节见 [59-global-variables-dev-guide.md](59-global-variables-dev-guide.md)。

---

## 轮询与刷新机制

面板由 0.5 秒 `Timer` 驱动：

```gdscript
_timer.wait_time = 0.5
_timer.autostart = true
_timer.timeout.connect(_refresh)
```

### `_refresh()` 执行流程

```
1. 从桥缓存收集 local + scope 行（_rows_from_cached，
   v3 键："units" → local 行按宿主分组，"containers" → scope 行按容器分组；
   字段缺失降级空集）
2. 收集 global 行（桥已连接 → get_cached_global() 游戏侧实时快照；
   否则 GlobalVariableService 编辑器侧定义）
3. _record_history() 记录数值历史（仅 int/float，键经 _history_key）
4. _tree.apply_data(rows, scene_name, filter_text)
   ← 三级增量 diff，返回摘要 {scenes, hosts, global}
5. _tree.apply_global(global_rows, filter_text)
   ← 刷新 GLOBAL 根（须每轮紧跟 apply_data，勿调序）
6. 更新状态摘要（场景:N · 宿主:M · Global:K）
7. 未连接且行集为空 → 显示"等待运行游戏…"空态叠层
```

> **设计要点**: 每轮刷新产出 v3 行字典后交给 Tree 层做**增量 diff**（仅增删改变化的 item，不闪、选中/折叠态不断续）。搜索输入变化也走同一条路径（过滤集变化即 diff 出增删）。编辑覆盖层独立于树行，刷新无需冻结。

---

## Tree 展示层（FuseVariableWatcherTree）

`FuseVariableWatcherTree`（`editor/debugging/variable_watcher_tree.gd`，`class_name` 同名，`extends Tree`）承载全部树形展示，三列：名称（EXPAND_FILL）/ 值（EXPAND_FILL，最小 120px）/ 类型（固定 ~86px 窄列）。视觉全部继承编辑器主题（零硬编码色、零字号 override；HistoryGraph 内部除外）。

### 树结构（三级 + 平级根）

- **一级 = 场景根**（加粗）：宿主按节点路径归组——`/root/<名>/...` 前缀归对应附加场景（`scene_of()` 静态纯函数），其余归当前场景（名取推送 `scene` 字段，缺省归未命名分组）
- **二级 = 宿主**（同层平铺）：**容器在前组件在后**（`_build_targets` 内保持原序）。容器行 `<path> (<scope_id>)`；组件行 `<path> [<Trigger|MultiEvent|Runner>] · <ago>`；`ago_ms > 5000`（`STALE_MS`）整行用主题 disabled 色灰显
- **三级 = 变量行**：宿主的 vars/local；`__complex` 行值列灰显（只读标识）
- **`GLOBAL` 为与场景平级的独立根**（内部键 `"__global__"`），进程级变量直挂其下

item 元数据：变量行挂 v3 行字典（`target`/`id`/`name`/`type`/`is_complex`/`group_key`/`group_path`）；分组行挂 `{"collapse_key": ...}`。

### 稳定键与增量 diff

| 层级 | 稳定键 |
|------|--------|
| 场景根 | `s:<场景名>`（折叠键；GLOBAL 为 `s:__global__`） |
| 宿主 | `c<id>` / `u<id>` |
| 变量行 | `target:id:name` |

`diff_plan(old_keys, new_keys)` 是纯函数（headless 可测），返回 `{add: [...], remove: [...]}`；`apply_data()` 按计划逐层执行：新键 `create_item` 挂正确父节点，消失键 `free()` 子树，存量键仅刷新变化列的文本与灰显状态。

### 折叠持久

增量更新下 item 持续存活，Tree 自身折叠态天然保持；item 重建（宿主/场景消失又重现）时按成员字典 `_collapsed` 恢复，键 `s:<场景名>` / `c<id>` / `u<id>`（`item_collapsed` 信号回写）。

### 过滤（过滤集重建）

过滤匹配**场景名 / 宿主路径 / 变量名 + 值**（`_passes_filter`，大小写不敏感包含）。场景名或宿主路径命中 → 整组可见；过滤后为空的组不建 item。过滤集变化体现为目标键集变化，走同一条 diff 路径（"按过滤集重建可见树"），折叠态经 `_collapsed` 保持。

### GLOBAL 根契约

`apply_data()` 与 `apply_global(global_rows, filter_text)` 必须成对、每轮按此顺序调用——GLOBAL 根的创建在 `apply_data()` 内，行挂载在 `apply_global()` 内（主文件内有注释锚点，勿调序）。`apply_global()` 对 global 行全删全建（行少且无稳定 id），同样走 `_check_selection_stale()`。

### 选中与编辑定位

- 信号 `variable_selected(row, selected)`：选中变量行时发出（`selected=false` 表示失选）；`variable_activated(row)`：双击可编辑行时发出（编辑请求）
- **Tree 无 `item_deselected` 信号**——选中行被 diff 移除后经 `_check_selection_stale()` 检测 `_row_meta` 缺键补发失选事件（主文件收到后收起图区）
- `value_cell_screen_rect()`：选中行值列的屏幕矩形（`get_item_area_rect` 换算），供主文件把 `LineEdit` 编辑覆盖层定位到值单元格上

---

## Stage 7a — 双击编辑

### 交互流程

```
双击变量行 → Tree item_activated → variable_activated(row)
    ↓ 主文件 _on_variable_activated()：_is_row_editable(row) 门控
LineEdit 覆盖层定位到 value_cell_screen_rect()（值单元格屏幕矩形）
    ↓ 输入（树刷新照常，编辑覆盖层独立于树行，无需冻结）
Enter 提交 / 失焦提交 → _finish_edit(text, row)
    ↓
_coerce_value(text, type_str)     ← 类型转换（失败返回 null，中止写回）
    ↓
按 target 三路分发写回 → 清理覆盖层 → _refresh() 回显真实值
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

### 可编辑性门控（`_is_row_editable`）

非 `__complex`、类型在 `EDITABLE_TYPES`（JSON 标量）内、`target` 有效（`container`/`unit`/`global`）三者同时满足才可编辑；Tree 层双击任何行都会发 `variable_activated`，门控在主文件侧。

---

## Stage 7b — 历史折线图

### 历史记录

```gdscript
const HISTORY_MAX := 120  # 60s / 0.5s = 120 帧滑动窗口

var _history: Dictionary = {}   # var_key → Array[float]
var _selected_key := ""
```

`_record_history(var_key, value, type_str)` 规则：

- 仅记录 `int` / `float`（其他类型直接忽略）
- 键方案（v3，`_record_history` 与行选中经 `_history_key` 共用）：`local:<单元路径>/<名>`、`scope:<容器路径>/<名>`、`global/<名>`（如 `"global/player_score"`）
- 超过 `HISTORY_MAX` 时弹出最旧帧

### 选中展开图区

- Tree `variable_selected(row, true)` → 主文件记录 `_selected_key = _history_key(row)`，展开 `_graph_panel`（VSplitContainer 底部，默认 100px，可拖高），标题 `group_path/name`
- 换选自动切换曲线；`variable_selected(row, false)`（含 `_check_selection_stale` 补发）或点击标题行 ✕ → 收起图区
- 无数据/非数值选中时 `_graph.set_points([])` 显示占位文本

### HistoryGraph 组件

```gdscript
class HistoryGraph extends Control:
	# 嵌套类，绘制逻辑：
	# 1. 取 _history[_selected_key]
	# 2. 归一化到 [0, 1] 范围
	# 3. draw_line() 绘制折线（主题 accent 色，取色失败兜底淡蓝）
	# 4. 无数据时显示灰色占位文本 "(无数值历史)"
```

---

## 扩展指南

### 行数据结构

`_make_var_row()` 产出的 Dictionary 是渲染与编辑的统一数据载体，核心键：

| 键 | 说明 |
|----|------|
| `name` | 变量名 |
| `value` | 显示值（字符串化） |
| `type` | 类型字符串（`int`/`float`/`Vector2`/...） |
| `is_complex` | `__complex` 只读包装行标记（Tree 层据此灰显值列） |
| `target` / `id` | v3 写回目标（`container`/`unit`/`global`）与宿主/容器实例 id |
| `group_key` / `group_path` | 所属宿主分组（`u<id>` / `c<id>`）及显示路径（树形归组 + 过滤） |

新增可编辑类型时在 `_coerce_value()` 中添加转换分支，并在 `EDITABLE_TYPES` 中登记。

### 接入新的运行时数据源

1. 在游戏侧扩展 `FuseRuntimeBridge._push_snapshot()` 的 JSON 负载
2. 在编辑器侧扩展 `_update_cache()` 的缓存结构
3. 在 `_rows_from_cached()` 中读取新字段并生成行/分组

> **注意**: Bridge 协议是 JSON line，新增字段向后兼容（旧版本解析器忽略未知键）。

---

## 性能设计

| 机制 | 开销控制 |
|------|----------|
| 0.5s 轮询 | 避免逐帧刷新；与 Bridge 推送频率一致（0.5s），不会读到半更新状态 |
| 增量 diff | 仅增删改变化的 TreeItem（`diff_plan` 纯函数），无全量重建闪烁，选中/折叠态天然保持 |
| 过滤集重建 | 过滤不改变数据收集，仅改变目标键集再走同一条 diff 路径 |
| 历史仅数值 | `int`/`float` 才进 `_history`，String/Vector 等零开销 |
| 历史定长窗口 | `HISTORY_MAX = 120`，超出即弹出，内存恒定 |

**已知开销点**（扩展时注意）：

- `_apply_complex_color()` 每轮遍历全部存量变量行——行数极大时可改为 diff 阶段定点刷新
- global 行 `apply_global()` 全删全建——行少可接受，若未来 global 数量膨胀需改为增量

---

## 常见陷阱

### 陷阱 1: 编辑提交时游戏可能已退出

**问题**: 行渲染自最近一次推送的快照，从渲染某行到提交编辑之间游戏可能已退出。无存活连接时 `send_set_var` 返回 `false`，值永远到不了游戏。

**解决**: 把 `false` 返回视为写回失败——警告（`FUSE_UI_WATCHER_EDIT_NO_CONNECTION`），编辑覆盖层随即关闭；提交后的下一次刷新会自然把显示校正回游戏侧权威值。（`_coerce_value` 转换失败仍会静默中止写回——那是输入问题，不是连接问题。）

### 陷阱 2: 直接访问 GlobalVariableManager 绕过服务层

**问题**: 面板各处直接 `GlobalVariableManager.get_instance()`，与 Assistant 信号流脱节。

**解决**: 读取走 `GlobalVariableService.get_all_global_variables_info()`；写回走 `_write_back_global()` 统一入口。

### 陷阱 3: 历史键不含作用域

**问题**: 不同作用域同名变量共用历史曲线，数据互相污染。

**解决**: 键必须用 v3 方案——`local:<单元路径>/<名>`、`scope:<容器路径>/<名>`、`global/<名>`（`_history_key` 已约定，`_record_history` 与行选中两端同键，否则折线图静默失效）。

### 陷阱 4: Bridge 推送与轮询频率不一致

**问题**: 修改 `PUSH_INTERVAL` 后监视器仍按 0.5s 假设工作（历史窗口时长错位）。

**解决**: 历史窗口语义 `HISTORY_MAX × PUSH_INTERVAL = 显示秒数`，改频率时同步调整注释与文档。

### 陷阱 5: 对象值导致的"假 String"行（v2 遗留——已消除）

**问题**: v2 把 `Object` 值序列化成裸字符串推送，编辑器无法与真 `String` 行区分，会对不可编辑的值提供编辑。

**解决**: v3 协议将非标量以只读包装 `{"__complex": "str(v) ≤200字符", "ty": "Vector2"}` 编码——根源已在协议层消除（类型列显示真实类型名，行不可编辑）。游戏侧非标量闸门仍保留，作为手造消息的最后防线。

### 陷阱 6: 运行结束后 local 行消失（设计说明）

**问题**: 早期设计在执行结束即焚毁上下文（"即焚"），Trigger/Runner 跑完后无数据可报。

**解决**: v3 改为保留**最近**执行上下文：BaseTrigger（`_create_execution_context`）、MultiEventTrigger 与 Runner 均赋值 `current_execution_context` / `current_execution_context_at_ms`，单元持续上报最近一次运行的 local，`ago_ms` 新鲜度字段让 Tree 层对超时宿主（> 5s）灰显。

### 陷阱 7: 折叠状态跨刷新丢失

**问题**: 展示层若每轮重建树，用户折叠的组会在下一帧弹开。

**解决**: 增量 diff 下 item 持续存活，Tree 自身折叠态天然保持；仅当 item 重建（宿主/场景消失又重现）时按 `_collapsed` 字典恢复，键 `s:<场景名>` / `c<id>` / `u<id>`（`item_collapsed` 信号回写），不依赖重建前的控件引用。搜索过滤不改变折叠字典——过滤集重建复用同一折叠态。

### 陷阱 8: Tree 无 item_deselected 信号——选中失效需主动补发

**问题**: 选中行被 diff 移除（宿主/变量消失、过滤命中集变化）后，Tree 不会发出失选事件；主文件若沿用旧选中键取历史/图区数据，会拿到已消失变量的残留曲线。

**解决**: Tree 层维护 `_row_meta` 键索引，每轮 `apply_data()` / `apply_global()` 末尾跑 `_check_selection_stale()`——`_selected_key` 在索引中消失即清空并补发 `variable_selected({}, false)`，主文件据此收起图区。

---

## 总结

变量监视器开发核心要点：

1. ✅ **数据层/展示层分离** — 主文件保留纯函数数据层（桥读取/行生成/编辑分发，测试覆盖）；展示层为 `FuseVariableWatcherTree`
2. ✅ **TCP 双模式桥** — 编辑器 TCPServer / 游戏客户端，JSON line 协议，0.5s 推送（v3：`containers` + `units` + `scene` + `global`）
3. ✅ **三级树 + 平级根** — 场景根（`s:<场景>`，`/root/<名>` 前缀归附加场景）→ 宿主（`c<id>`/`u<id>`，容器在前组件在后）→ 变量行（`target:id:name`）；GLOBAL 平级独立根
4. ✅ **增量 diff** — `diff_plan` 纯函数产增删计划，Tree 层只执行；折叠态天然保持 + `_collapsed` 重建恢复；过滤集变化走同一路径
5. ✅ **编辑保护新形态** — 编辑覆盖层独立于树行，无需冻结刷新；`_coerce_value` 返回 null 中止写回；可编辑性由 `_is_row_editable` 门控
6. ✅ **选中联动** — 选中展开折线图；Tree 无 `item_deselected`，选中失效经 `_check_selection_stale` 补发
7. ✅ **apply_global 契约** — 须每轮紧跟 `apply_data()` 调用，GLOBAL 根依赖此顺序

**参考文档**:
- [变量监视器使用指南](../../user_docs/guides/56-variable-watcher-guide.md)
- [全局变量开发指南](59-global-variables-dev-guide.md)
- [Runtime Bridge 开发指南](runtime-bridge-guide.md)
- [调试系统用户指南](../../user_docs/guides/25-debugging-guide.md)

---

**文档维护**: Fuse 开发团队
**最后更新**: 2026-09-04
