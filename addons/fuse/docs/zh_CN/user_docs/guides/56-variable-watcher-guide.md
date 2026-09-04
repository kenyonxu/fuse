> 🌐 中文 | [**English**](../../../en_US/user_docs/guides/56-variable-watcher-guide.md)

# 变量监视器使用指南

`FuseVariableWatcher` 是嵌入在 Godot 编辑器底部 Dock 的**实时变量监视面板**，以 0.5 秒轮询频率展示 Fuse 运行时所有可见变量的名称、值与类型。支持双击编辑（运行中经 TCP 桥写回游戏进程）、录制折线图和静态声明快照补全。

**相关文件:** `addons/fuse/editor/debugging/variable_watcher.gd`

---

## 功能概览

| 特性 | 说明 |
|------|------|
| 轮询频率 | 0.5 秒（Timer 驱动） |
| 显示层级 | Local（本地，按宿主组件分组） / Scope（作用域，按容器分组） / Global（全局，平铺） |
| 运行时数据源 | `FuseRuntimeBridge`（Autoload 节点推送，协议 v3） |
| 全局变量数据源 | 游戏运行中：游戏侧实时快照；未运行：`GlobalVariableService` |
| 历史记录 | 120 帧 = 60 秒滑动窗口（仅数值类型） |
| 搜索过滤 | 按组路径 + 变量名实时筛选（不区分大小写） |

---

## 面板布局

变量监视器位于编辑器底部 Dock，布局分为四个区域：

```
+-----------------------------------------------------------+
| 刷新:0.5s                     Global:5  Unit:2  Ctn:1 [📸快照] |
| [搜索变量...______________________________________________] |
| [变量           | 值             | 类型                    ] |
+-----------------------------------------------------------+
| ▸ /Main/Runner1 [Runner] · 0.3s                           |
| [health         | 85             | int                    ] |
| [target_pos     | (120, 340)     | Vector2                ] |
|                                                           |
| ▸ /Enemies/Guard [Trigger] · 6.2s   （超时，灰显）           |
| [aggro          | true           | bool                   ] |
|                                                           |
| ▸ /World/LevelScope (level1)                              |
| [alert_level    | 50             | int                    ] |
|                                                           |
| Global                                                     |
| [player_score   | 2450           | int                    ] |
| [game_time      | 132.5          | float                  ] |
|                                                           |
| 指令引用(静态)                                              |
| [cooldown       | (静态)         |local · 读写 · 2处     ] |
+-----------------------------------------------------------+
| [=== 折线图区域 =====================================]   |
+-----------------------------------------------------------+
```

### 顶栏

| 控件 | 说明 |
|------|------|
| 状态标签 | 显示轮询状态和变量统计，如 `Global:5  Unit:2  Ctn:1`（global 行数 / 单元宿主数 / 容器数） |
| 📸快照按钮 | 点击导出当前所有变量快照到 `user://fuse_watcher_snapshot_{时间戳}.json` |

### 搜索框

实时过滤所有分区的变量行，匹配**组路径 + 变量名**（不区分大小写）。组内行全部被过滤时组头也隐藏；过滤激活时忽略折叠状态，命中行始终显示。空字符串显示全部。

### 列标题

三列布局：**变量** | **值** | **类型**

标题行带有深蓝色背景 (`COL_HEADER: Color(0.2, 0.3, 0.5)`)。

### 滚动内容区

按分区显示变量行，每行格式同列标题。

---

## 三层变量显示

### 1. Local（本地变量，按宿主组件分组）

显示各宿主组件（BaseTrigger / MultiEventTrigger / Runner）从其**最近执行上下文**上报的本地（`local`）变量。组头显示组件路径、类型与新鲜度：

```
▸ /Main/Runner1 [Runner] · 0.3s
  [health     | 85   | int]
  [target_pos | (120, 340) | Vector2]

▸ /Enemies/Guard [Trigger] · 6.2s      ← 超过 5s：灰显
  [aggro     | true | bool]
```

组头可点击折叠/展开，折叠状态跨刷新保持。组件首次执行后才会出现（此前没有执行上下文）。

### 2. Scope（作用域变量，按容器分组）

显示各 `ScopeVariableContainer` 的变量，按容器分组：

```
▸ /World/LevelScope (level1)
  [alert_level   | 50       | int]
  [current_state | "patrol" | String]
```

容器从整棵场景树收集，即使某个子树从未触发过，其容器的声明值（默认值）也可见。作用域变量通过 `FuseRuntimeBridge.get_cached_vars()` 获取，依赖运行时推送。

### 3. Global（全局变量）

全局变量按游戏是否运行自动切换数据源：

- **游戏运行中**：显示游戏进程推送的实时标量快照（经 `FuseRuntimeBridge`），分区标题带"（运行游戏）"后缀
- **未运行**：通过 `GlobalVariableService.get_all_global_variables_info()` 读取编辑器侧定义

```
Global
  [player_score  | 2450       | int]
  [game_time     | 132.5      | float]
  [is_game_over  | false      | bool]
```

全局变量**持久化**，即使场景切换也不会丢失，适用于跨场景调试。

---

## 轮询机制

面板通过一个 `Timer` 驱动 0.5 秒的刷新循环：

```gdscript
_timer.wait_time = 0.5
_timer.autostart = true
_timer.timeout.connect(_on_timer)
```

每次刷新 (`_refresh()`) 执行以下流程：

```
1. 检查 _editing 标志（编辑中则跳过，避免销毁 LineEdit）
2. 清空内容区
3. 通过 _collect_runtime_variables() 从桥缓存收集 local + scope 行（v3 键："containers" → Scope 行按容器分组，"units" → Local 行按宿主分组；字段缺失降级为空集）
4. 收集 global 变量（游戏运行中取游戏侧实时快照，否则取 `GlobalVariableService`）
5. 每行记录历史（仅 int/float）
6. 渲染 Local / Scope / Global 三个分区（Local/Scope 分组，Global 平铺）
7. 渲染静态声明分区（5 秒间隔刷新拓扑缓存）
8. 更新底部折线图
9. 更新状态标签（`Global:N  Unit:M  Ctn:K`）
```

---

## Stage 7 功能

### 7a — 双击编辑

交互行（非笔记/非静态）支持双击编辑变量值：

| 作用域 | 编辑功能 | 写回目标 |
|--------|----------|----------|
| **Local** | **运行中可用**（标量类型） | `bridge.send_set_var("unit", id, name, value)` → 运行游戏应用（写宿主组件的最近执行上下文） |
| **Scope** | **运行中可用**（标量类型） | `bridge.send_set_var("container", id, name, value)` → 运行游戏应用（写容器变量） |
| **Global** | 恒可用，按数据源分流 | 游戏运行中：`send_set_var("global", ...)` → 运行游戏（仅已存在的变量）；未运行：编辑器侧定义 `set_variable_value_thread_safe`（保留元数据，不存在才新建） |

**可编辑类型**：仅限 JSON 标量（`int` / `float` / `bool` / `String`）。非标量值以 `{"__complex": ..., "ty": "Vector2"}` 包装到达——这类行只读（值列显示截断字符串，类型列显示真实类型名），双击无反应。

**运行中 Global 数据源**：游戏运行时 Global 区标题带"（运行游戏）"后缀，值来自游戏进程的实时快照；停止运行后回落为编辑器侧定义。

**操作方式**：
1. 双击值列 → 替换为 `LineEdit`
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
- 编辑中 `_editing = true`，`_refresh()` 跳过重建避免销毁 LineEdit
- Local/Scope 行需来自运行中游戏（行携带的 target id 能在游戏侧定位到宿主/容器才可编辑）
- 写回失败（连接断开）恢复原显示值并警告；类型转换失败静默恢复原值（输入问题，不警告）

### 7b — 折线图

点击任意变量行可选中该变量，底部折线图区域显示其值历史：

- **历史窗口**：`HISTORY_MAX = 120` 帧（60 秒滑动窗口，`0.5s × 120 = 60s`）
- **记录范围**：仅 `int` 和 `float` 类型的变量（其他类型自动忽略）
- **存储键**（v3，按宿主/容器区分，同名变量互不污染）：`local:<单元路径>/<名>`、`scope:<容器路径>/<名>`、`global/<名>`（如 `"global/player_score"`）

**HistoryGraph 组件**：
- 嵌套类 `HistoryGraph extends Control`
- 绘制逻辑：归一化到 `[0, 1]` 范围绘制折线
- 无数据时显示灰色占位文本 `(无数值历史)`
- 选中新变量时自动切换显示

```
# 选中 "global/player_score"
# 折线图显示最近 60 秒的分数变化趋势
  ▁▂▃▅▇▆▅▄▃▂▁▂▃▄▅▆▇▆▅▄▃▂▁
  ↑                          ↑
  min=2100               max=2600
```

### 7c — 静态声明

在编辑器模式下，面板会扫描场景中所有 Trigger 的指令链拓扑，汇总**变量声明信息**并以独立分区展示：

```
指令引用(静态)
  [cooldown        | (静态) | local · 读写 · 2处]
  [player_health   | (静态) | scope · 读写 · 1处]
  [level_score     | (静态) | global · 读 · 3处]
```

**每项含义**：

| 字段 | 说明 |
|------|------|
| 变量名 | 声明的变量名称 |
| 值 | 固定为 `(静态)`，非实时值 |
| 类型 | `{作用域} · {访问模式} · {引用处数}` |

**访问模式**：
- `读写` — 既有读也有写操作
- `写` — 仅有 SetVariable 等写入操作
- `读` — 仅有 GetVariable 等读取操作

**缓存机制**：拓扑扫描每 5 秒执行一次（`STATIC_REFRESH_INTERVAL_MS = 5000`），避免 0.5 秒高频扫描开销。

### 7d — 快照补全

点击 **📸快照** 按钮，导出当前时刻所有变量的完整快照到 JSON 文件：

```json
{
    "timestamp": 1234.567,
    "global": {
        "player_score": {"value": 2450, "type": "int"},
        "game_time": {"value": 132.5, "type": "float"}
    },
    "containers": [
        {"id": 99001, "path": "/World/LevelScope", "scope_id": "level1",
         "vars": {"alert_level": {"value": 50, "type": "int"}}}
    ],
    "units": [
        {"id": 123456, "path": "/Main/Runner1", "kind": "runner", "ago_ms": 5,
         "local": {
            "health": {"value": 85, "type": "int"},
            "target_pos": {"value": "(120, 340)", "type": "Vector2"}
         }}
    ]
}
```

导出路径：`user://fuse_watcher_snapshot_{时间戳}.json`

---

## 颜色方案

| 区域 | 颜色 | RGB |
|------|------|-----|
| 变量名 | 深蓝 | `(0.1, 0.15, 0.3)` |
| 值 | 深绿 | `(0.1, 0.25, 0.15)` |
| 类型 | 浅黑 | `(0.15, 0.15, 0.15)` |
| 分区标题 | 中蓝 | `(0.2, 0.3, 0.5)` |
| 字体色（Label） | 浅灰 | `(0.85, 0.85, 0.85)` |
| 折线图线条 | 淡蓝 | `(0.4, 0.8, 1.0)` |

---

## 数据源架构

```
┌─────────────────────────────────────────────┐
│          FuseVariableWatcher (Dock)          │
│                                              │
│  ┌──────────────┐   ┌───────────────────┐   │
│  │ 0.5s Timer    │   │ get_snapshot()    │   │
│  └──────┬───────┘   └────────┬──────────┘   │
│         │                     │              │
│         ▼                     ▼              │
│  ┌──────────────┐   ┌───────────────────┐   │
│  │ _refresh()   │   │ GlobalVariableSvc │   │
│  └──┬───────┬───┘   └───────────────────┘   │
│     │       │                                │
│     ▼       ▼                                │
│  ┌────┐ ┌──────┐                             │
│  │L/S │ │Global│                             │
│  └──┬─┘ └──────┘                             │
│     │                                        │
│     ▼                                        │
│  FuseRuntimeBridge (Autoload)                │
└─────────────────────────────────────────────┘
```

- **FuseRuntimeBridge**：Autoload 单例，游戏运行期间主动推送变量缓存（v3：按宿主/容器的 `containers` + `units` 条目，外加 global 标量）
- **GlobalVariableService**：未运行时从 `GlobalVariableManager` 读取编辑器侧全局变量定义；游戏运行中改读游戏侧实时快照（经 `FuseRuntimeBridge`）
- **InstructionAnalyzer**：编辑器中分析 Trigger 拓扑，提供静态声明数据

---

## 常见问题

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| 面板空白 | 场景未运行或无 Fuse 节点 | 运行场景并确保有 Trigger/ActionRunner |
| Local/Scope 不显示 | `FuseRuntimeBridge` 未注册 | 检查 Autoload 配置 |
| 双击编辑无反应 | 需要运行中游戏 | 场景运行中才出现 Local/Scope 行（宿主首次执行后上报）；复杂值（Vector2 等，只读显示）不可编辑 |
| 折线图无数据 | 变量非数值类型 | 仅 `int`/`float` 类型记录历史 |
| 快照保存失败 | 路径权限不足 | 检查 `user://` 目录权限 |
| 编辑时面板闪烁 | 0.5s 轮询与编辑冲突 | Stage 7a 已保护（`_editing` 标志阻止刷新重建） |

---

**相关文档:**
- [调试系统指南](25-debugging-guide.md)
- [断点指南](26-breakpoint-guide.md)
- [全局变量管理指南](54-global-variables-guide.md)
- [编辑器面板总览](00-editor-panels-overview.md)
