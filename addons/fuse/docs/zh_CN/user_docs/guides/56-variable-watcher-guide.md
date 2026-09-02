# 变量监视器使用指南

`FuseVariableWatcher` 是嵌入在 Godot 编辑器底部 Dock 的**实时变量监视面板**，以 0.5 秒轮询频率展示 Fuse 运行时所有可见变量的名称、值与类型。支持双击编辑、录制折线图和静态声明快照补全。

**相关文件:** `addons/fuse/editor/debugging/variable_watcher.gd`

---

## 功能概览

| 特性 | 说明 |
|------|------|
| 轮询频率 | 0.5 秒（Timer 驱动） |
| 显示层级 | Local（本地） / Scope（作用域） / Global（全局） |
| 运行时数据源 | `FuseRuntimeBridge`（Autoload 节点推送） |
| 全局变量数据源 | `GlobalVariableService` |
| 历史记录 | 120 帧 = 60 秒滑动窗口（仅数值类型） |
| 搜索过滤 | 按变量名实时筛选 |

---

## 面板布局

变量监视器位于编辑器底部 Dock，布局分为四个区域：

```
+-----------------------------------------------------------+
| 刷新:0.5s                         Global:5  Runner:2 [📸快照] |
| [搜索变量...______________________________________________] |
| [变量           | 值             | 类型                    ] |
+-----------------------------------------------------------+
| Local (Runner1)                                           |
| [health         | 85             | int                    ] |
| [target_pos     | (120, 340)     | Vector2                ] |
|                                                           |
| Scope                                                      |
| [alert_level    | 50             | int                    ] |
| [current_state  | "patrol"       | String                 ] |
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
| 状态标签 | 显示轮询状态和变量统计，如 `Global:5  Runner:2` |
| 📸快照按钮 | 点击导出当前所有变量快照到 `user://fuse_watcher_snapshot_{时间戳}.json` |

### 搜索框

实时过滤所有分区的变量行，匹配变量名。空字符串显示全部。

### 列标题

三列布局：**变量** | **值** | **类型**

标题行带有深蓝色背景 (`COL_HEADER: Color(0.2, 0.3, 0.5)`)。

### 滚动内容区

按分区显示变量行，每行格式同列标题。

---

## 三层变量显示

### 1. Local（本地变量）

显示当前各 Runner（`ActionRunner`）实例中的本地（`local`）变量。每行标注所属 Runner 名称：

```
Local (Runner1)
  [health     | 85   | int]
  [target_pos | (120, 340) | Vector2]

Local (Runner2)
  [loop_count | 3    | int]
```

**运行时要求**：仅在场景运行后显示。未检测到运行时数据时显示提示 `(场景运行后可见)`。

### 2. Scope（作用域变量）

显示各 Runner 中声明为 `scope` 作用域的变量：

```
Scope
  [alert_level  | 50       | int]
  [current_state| "patrol" | String]
```

作用域变量通过 `FuseRuntimeBridge.get_cached_vars()` 获取，依赖运行时推送。

### 3. Global（全局变量）

通过 `GlobalVariableService.get_all_global_variables_info()` 获取所有注册在 `GlobalVariableManager` 中的全局变量：

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
3. 通过 _collect_runtime_variables() 收集 local + scope 变量
4. 通过 GlobalVariableService 收集 global 变量
5. 每行记录历史（仅 int/float）
6. 渲染 Local / Scope / Global 三个分区
7. 渲染静态声明分区（5 秒间隔刷新拓扑缓存）
8. 更新底部折线图
9. 更新状态标签
```

---

## Stage 7 功能

### 7a — 双击编辑

交互行（非笔记/非静态）支持双击编辑变量值：

| 作用域 | 编辑功能 | 写回目标 |
|--------|----------|----------|
| **Local** | 仅运行时可用 | `context.set_variable(name, coerced_value, "local")` |
| **Scope** | 仅运行时可用 | `context.set_variable(name, coerced_value, "scope")` |
| **Global** | 始终可用 | `GlobalVariableManager.add_variable(name, variable)` |

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
| 其他 | 最佳努力，原样返回 |

**安全保护**：
- 编辑中 `_editing = true`，`_refresh()` 跳过重建避免销毁 LineEdit
- Local/Scope 变量需要有效 `context`（运行时 context 不可用时编辑被阻止）

### 7b — 折线图

点击任意变量行可选中该变量，底部折线图区域显示其值历史：

- **历史窗口**：`HISTORY_MAX = 120` 帧（60 秒滑动窗口，`0.5s × 120 = 60s`）
- **记录范围**：仅 `int` 和 `float` 类型的变量（其他类型自动忽略）
- **存储键**：`"{scope}/{var_name}"`（如 `"global/player_score"`）

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
    "runners": [
        {
            "runner_name": "Runner1",
            "local": {
                "health": {"value": 85, "type": "int"},
                "target_pos": {"value": "(120, 340)", "type": "Vector2"}
            },
            "scope": {
                "alert_level": {"value": 50, "type": "int"}
            }
        }
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

- **FuseRuntimeBridge**：Autoload 单例，游戏运行期间主动推送 local/scope 变量缓存
- **GlobalVariableService**：从 `GlobalVariableManager` 读取全局变量
- **InstructionAnalyzer**：编辑器中分析 Trigger 拓扑，提供静态声明数据

---

## 常见问题

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| 面板空白 | 场景未运行或无 Fuse 节点 | 运行场景并确保有 Trigger/ActionRunner |
| Local/Scope 不显示 | `FuseRuntimeBridge` 未注册 | 检查 Autoload 配置 |
| 双击编辑无反应 | 需要运行时 context | 场景运行中才能编辑 local/scope 变量 |
| 折线图无数据 | 变量非数值类型 | 仅 `int`/`float` 类型记录历史 |
| 快照保存失败 | 路径权限不足 | 检查 `user://` 目录权限 |
| 编辑时面板闪烁 | 0.5s 轮询与编辑冲突 | Stage 7a 已保护（`_editing` 标志阻止刷新重建） |

---

**相关文档:**
- [调试系统指南](25-debugging-guide.md)
- [断点指南](26-breakpoint-guide.md)
- [全局变量管理指南](54-global-variables-guide.md)
- [编辑器面板总览](00-editor-panels-overview.md)
