> 🌐 中文 | [**English**](../../../en_US/user_docs/guides/56-variable-watcher-guide.md)

# 变量监视器使用指南

`FuseVariableWatcher` 是嵌入在 Godot 编辑器底部 Dock 的**实时变量监视面板**，以 0.5 秒轮询频率展示 Fuse 运行时所有可见变量的名称、值与类型。变量按**场景 → 宿主 → 变量**三级树展示（GLOBAL 为平级独立根），支持双击编辑（运行中经 TCP 桥写回游戏进程）、搜索过滤，选中数值变量后底部展开折线图。

**相关文件:** `addons/fuse/editor/debugging/variable_watcher.gd`

---

## 功能概览

| 特性 | 说明 |
|------|------|
| 轮询频率 | 0.5 秒（Timer 驱动，增量更新不闪烁） |
| 显示层级 | 场景 → 宿主 → 变量三级树；GLOBAL 为平级独立根 |
| 运行时数据源 | `FuseRuntimeBridge`（Autoload 节点推送，协议 v3） |
| 全局变量数据源 | 游戏运行中：游戏侧实时快照；未运行：`GlobalVariableService` |
| 历史记录 | 120 帧 = 60 秒滑动窗口（仅数值类型） |
| 搜索过滤 | 按场景名 / 宿主路径 / 变量名实时筛选（不区分大小写） |
| 折线图 | 选中数值变量后在底部图区展开（可拖高，✕ 收起） |

---

## 面板布局

变量监视器位于编辑器底部 Dock，分为顶栏、变量树与底部图区（未选中变量时图区收起，不占空间）：

```
+-----------------------------------------------------------+
| [搜索变量...____________]        场景:2 · 宿主:3 · Global:2 |
+-----------------------------------------------------------+
| ▾ Main                                                    |
|   ▾ /Main/Runner1 [Runner] · 0.3s                         |
|     health      | 85          | int                       |
|     target_pos  | (120, 340)  | Vector2                   |
|   ▾ /World/LevelScope (level1)                            |
|     alert_level | 50          | int                       |
| ▸ /root/Enemies/Guard [Trigger] · 6.2s   （超时宿主，灰显） |
| ▾ GLOBAL                                                  |
|   player_score  | 2450        | int                       |
|   game_time     | 132.5       | float                     |
+-----------------------------------------------------------+
| group_path/name                                       [✕] |
| [=== 折线图区域（选中变量后展开，可拖高）==============]   |
+-----------------------------------------------------------+
```

未连接运行游戏且无数据时，树上叠居中灰字提示**"等待运行游戏…"**。

### 顶栏

| 控件 | 说明 |
|------|------|
| 搜索框 | 实时过滤树行（见下） |
| 状态摘要 | 单行灰字，如 `场景:2 · 宿主:3 · Global:2`（场景数 / 宿主数 / global 行数；前两项为过滤后计数，过滤激活时数字随之收缩） |

### 搜索框

实时过滤树中的行，匹配**场景名 / 宿主路径 / 变量名**（不区分大小写）。场景名或宿主路径命中时**整组可见**；仅变量命中时只显示命中行。过滤集变化走同一条增量更新路径，折叠状态保持。空字符串显示全部。

### 变量树

三列布局：**名称**（宽）| **值**（宽）| **类型**（窄列）。视觉全部继承编辑器主题（亮/暗自适应，无硬编码色）：

- **场景根 / GLOBAL 根**：加粗；两级（场景、宿主）均可折叠，折叠状态跨刷新保持
- **宿主行**：容器在前组件在后；容器行 `<path> (<scope_id>)`，组件行 `<path> [<Trigger|MultiEvent|Runner>] · <ago>`；超过 5 秒未上报的宿主整行灰显
- **变量行**：`__complex` 复杂值（Vector2 等）值列灰显，只读

---

## 三级树展示

### 1. 场景根（场景归组）

一级为场景根。宿主按其节点路径归组：`/root/<名>/...` 前缀的宿主归到对应**附加场景**根，其余归**当前场景**（场景名取运行游戏推送的 `scene` 字段，字段缺失时归入未命名分组）。

### 2. 宿主（容器在前，组件在后）

二级为宿主，同层平铺，**容器在前、组件在后**：

```
▾ /World/LevelScope (level1)        ← 容器（ScopeVariableContainer）
  alert_level   | 50       | int
▾ /Main/Runner1 [Runner] · 0.3s    ← 组件（BaseTrigger / MultiEventTrigger / Runner）
  health       | 85       | int
```

- **容器**：显示声明值（默认值），即使子树从未触发过也可见（依赖运行时推送，经 `FuseRuntimeBridge.get_cached_vars()`）
- **组件**：显示其**最近执行上下文**上报的 local 变量，首次执行后才会出现（此前没有执行上下文）

### 3. GLOBAL（平级根）

`GLOBAL` 是与场景平级的独立根，进程级全局变量直挂其下，按游戏是否运行自动切换数据源：

- **游戏运行中**：显示游戏进程推送的实时标量快照（经 `FuseRuntimeBridge`）
- **未运行**：通过 `GlobalVariableService.get_all_global_variables_info()` 读取编辑器侧定义

```
GLOBAL
  player_score | 2450  | int
  game_time    | 132.5 | float
```

全局变量**持久化**，即使场景切换也不会丢失，适用于跨场景调试。

---

## 轮询机制

面板通过一个 `Timer` 驱动 0.5 秒的刷新循环：

```gdscript
_timer.wait_time = 0.5
_timer.autostart = true
_timer.timeout.connect(_refresh)
```

每次刷新 (`_refresh()`) 执行以下流程：

```
1. 从桥缓存收集 local + scope 行（_rows_from_cached，v3 行字典 + scene 归组字段）
2. 收集 global 变量（游戏运行中取游戏侧实时快照，否则取 GlobalVariableService）
3. 记录数值历史（仅 int/float）
4. _tree.apply_data()：三级增量 diff 更新（仅增删改变化的行，选中/折叠态不断续）
5. _tree.apply_global()：刷新 GLOBAL 根（须每轮紧跟 apply_data）
6. 更新状态摘要（场景:N · 宿主:M · Global:K）
7. 未连接且无数据时显示"等待运行游戏…"空态
```

---

## 双击编辑

可编辑变量行支持双击修改值，写回语义与数据源分流保持不变：

| 作用域 | 编辑功能 | 写回目标 |
|--------|----------|----------|
| **Local** | **运行中可用**（标量类型） | `bridge.send_set_var("unit", id, name, value)` → 运行游戏应用（写宿主组件的最近执行上下文） |
| **Scope** | **运行中可用**（标量类型） | `bridge.send_set_var("container", id, name, value)` → 运行游戏应用（写容器变量） |
| **Global** | 恒可用，按数据源分流 | 游戏运行中：`send_set_var("global", ...)` → 运行游戏（仅已存在的变量）；未运行：编辑器侧定义 `set_variable_value_thread_safe`（保留元数据，不存在才新建） |

**可编辑类型**：仅限 JSON 标量（`int` / `float` / `bool` / `String`）。非标量值以 `{"__complex": ..., "ty": "Vector2"}` 包装到达——这类行值列灰显只读，双击无反应。

**操作方式**：
1. 双击可编辑行 → 值单元格上方弹出 `LineEdit` 覆盖层
2. 输入新值（字符串输入，自动类型转换）
3. `Enter` 提交 / 失焦提交

**类型转换规则**（`_coerce_value`）：

| 目标类型 | 转换规则 |
|----------|----------|
| int | `text.is_valid_int()` → `text.to_int()` |
| float | `text.is_valid_float()` → `text.to_float()` |
| bool | 匹配 `"true"` / `"1"` / `"是"` / `"yes"` |
| String | 原样返回 |
| 复杂类型（`Vector2` 等） | 不可编辑（行只读），不会进入转换 |

**安全保护**：
- 编辑覆盖层独立于树行，刷新期间树文本照常更新，无需冻结；提交后下一轮刷新回显真实值
- Local/Scope 行需来自运行中游戏（行携带的 target id 能在游戏侧定位到宿主/容器才可编辑）
- 写回失败（连接断开）警告（`FUSE_UI_WATCHER_EDIT_NO_CONNECTION`）；类型转换失败静默中止写回（输入问题，不警告）

---

## 折线图（选中展开）

点击选中任意数值变量行，底部图区自动展开并绘制其值历史曲线：

- 换选自动切换曲线；点击图区标题行的 **✕** 或取消选中收起图区；拖动分隔条可调高（默认 100px）
- **历史窗口**：`HISTORY_MAX = 120` 帧（60 秒滑动窗口，`0.5s × 120 = 60s`）
- **记录范围**：仅 `int` 和 `float` 类型的变量（其他类型自动忽略）
- **存储键**（v3，按宿主/容器区分，同名变量互不污染）：`local:<单元路径>/<名>`、`scope:<容器路径>/<名>`、`global/<名>`（如 `"global/player_score"`）

**HistoryGraph 组件**：
- 嵌套类 `HistoryGraph extends Control`
- 绘制逻辑：归一化到 `[0, 1]` 范围绘制折线，线条用编辑器主题 accent 色
- 无数据时显示灰色占位文本 `(无数值历史)`
- 选中新变量时自动切换显示

```
# 选中 "global/player_score"
# 折线图显示最近 60 秒的分数变化趋势
  ▁▂▃▅▇▆▅▄▃▂▁▂▃▄▅▆▇▆▅▄▃▂▁
  ↑                          ↑
  min=2100               max=2600
```

---

## 数据源架构

```
┌─────────────────────────────────────────────┐
│          FuseVariableWatcher (Dock)          │
│                                              │
│  ┌──────────────┐   ┌───────────────────┐   │
│  │ 0.5s Timer    │   │ GlobalVariableSvc │   │
│  └──────┬───────┘   └────────┬──────────┘   │
│         ▼                     │              │
│  ┌──────────────┐             │              │
│  │ _refresh()   │             │              │
│  └──────┬───────┘             │              │
│         ▼                     ▼              │
│  ┌───────────────────────────────────┐       │
│  │ FuseVariableWatcherTree（三级树）  │       │
│  └──────────────┬────────────────────┘       │
│                 ▼                            │
│    FuseRuntimeBridge (Autoload)              │
└─────────────────────────────────────────────┘
```

- **FuseRuntimeBridge**：Autoload 单例，游戏运行期间主动推送变量缓存（v3：按宿主/容器的 `containers` + `units` 条目、当前场景名 `scene` 字段，外加 global 标量）
- **GlobalVariableService**：未运行时从 `GlobalVariableManager` 读取编辑器侧全局变量定义；游戏运行中改读游戏侧实时快照（经 `FuseRuntimeBridge`）

---

## 常见问题

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| 面板显示"等待运行游戏…" | 未连接运行游戏且无数据 | 运行场景并确保有 Trigger/ActionRunner/ScopeVariableContainer |
| 树中没有场景/宿主 | `FuseRuntimeBridge` 未注册 | 检查 Autoload 配置 |
| 双击编辑无反应 | 需要运行中游戏，或值非标量 | 场景运行中才出现 Local/Scope 行（宿主首次执行后上报）；复杂值（Vector2 等，灰显只读）不可编辑 |
| 折线图无数据 | 变量非数值类型 | 仅 `int`/`float` 类型记录历史 |
| 附加场景没有独立归组 | 推送缺 `scene` 字段 | 场景归组依赖运行游戏上报的 `scene` 字段，缺省时宿主归入未命名分组 |

---

**相关文档:**
- [调试系统指南](25-debugging-guide.md)
- [断点指南](26-breakpoint-guide.md)
- [全局变量管理指南](54-global-variables-guide.md)
- [编辑器面板总览](00-editor-panels-overview.md)
