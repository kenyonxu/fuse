# 编辑器面板总览

Fuse 在 Godot 编辑器中集成了多个专属界面，分别覆盖：**Fuse Topology 主屏 Tab**（全场景 Trigger 拓扑总览 + 问题标注）、**Inspector 增强**（数据流卡片 + 预设操作）、**作用域变量编辑**、**底部变量监视器**（[56-variable-watcher-guide](56-variable-watcher-guide.md)）。本文档作为所有编辑器面板的入口参考。

---

## 目录

| 面板 | 文档章节 | 核心文件 |
|------|----------|----------|
| **Fuse Topology 主屏** | [Fuse Topology](#fuse-topology-主屏) | `editor/topology/fuse_topology.gd` |
| Inspector 插件 | 见本章 | `editor/fuse_inspector_plugin.gd` |
| Scope 变量编辑器 | [Scope 变量编辑器](#scope-变量编辑器) | `editor/scope_variable_container_plugin.gd` |
| 协作者 | [协作场景](#协作场景) | 多组件联动 |

---

## Fuse Topology 主屏

Fuse 插件在编辑器主屏注册了 **"Fuse" Tab**（与 2D / 3D / Script 并列），提供全场景的 Trigger 拓扑总览，是 Fuse 编辑器集成的**顶级入口**。

**文件:** `editor/topology/fuse_topology.gd`（依赖 `fuse_graph_builder.gd`、`fuse_graph_node.gd`、`analysis/instruction_analyzer.gd`）

### 注册机制

| 阶段 | 行为 |
|------|------|
| 插件启用 (`_enter_tree`) | `EditorInterface.get_editor_main_screen().add_child(_topology)` + `_make_visible(false)` 初始隐藏 |
| 用户切到 "Fuse" Tab | `_make_visible(true)` 显示 |
| 插件元信息 | `_has_main_screen() = true`；`_get_plugin_name()` → `"Fuse"`；图标 `VisualShader` |

### 界面布局

```
[Fuse 场景拓扑]                                    [🔄 刷新]
┌────────────────────────┬─────────────────────────────────┐
│ Trigger          事件   │  详情（BBCode 富文本）            │
│ ├ Trigger(OnKey)  on_key│  选中 Trigger → Trigger 概要     │
│ │  ├ SetVariable        │  选中指令   → 指令详情           │
│ │  ├ CompareVariable    │                                  │
│ │  └ EmitSignal         │  全局关联扫描                    │
│ └ Runner(OnTimer) timer │  （跨 Trigger 的变量/信号引用）   │
└────────────────────────┴─────────────────────────────────┘
```

### 功能

| 区域 | 说明 |
|------|------|
| **左侧 Trigger 树** | 扫描全场景，按 Trigger 分组展示嵌套指令链（含图标 + 分支标记）；第二列显示绑定事件 |
| **右侧详情面板** | BBCode 富文本：选中 Trigger 显示概要，选中指令显示指令详情（参数/依赖/引用） |
| **全局关联扫描** | `cross_ref_label` 标注跨 Trigger 的变量 / 信号 / 节点引用关联 |
| **刷新** | 重新扫描当前场景，重建 Trigger 树与详情 |

### 问题标注（静态分析）

Topology 刷新时自动跑指令序列分析（local 未声明变量检测），结果就地标注：

- **指令节点**：🔴 红色 = error / 🟡 黄色 = warning（文本前缀 + 着色）
- **Trigger 节点**：汇总子树问题计数（如 `(2🔴 1🟡)`），有 error 整行标红
- **选中节点** → 右侧详情面板显示该节点具体问题（BBCode 分级着色）
- **「导出问题报告」按钮**（顶部 banner）→ 全场景问题汇总写 `user://fuse_problems_report_*.txt`

分析由 `InstructionAnalyzer.analyze_problems` 提供（复用 `_extract_variables` 反射式提取，非独立引擎）。

### GraphEdit（降级保留）

代码中保留了 `FuseGraphEdit`（基于 Godot `GraphEdit` 的可视化节点图）与 `FuseGraphNode`，但当前**默认降级隐藏**（`visible = false`）。现阶段以 **Tree 树形视图**为主交互方式，GraphEdit 视图未启用，仅保留代码备查。

---

## Inspector 插件

`FuseInspectorPlugin`（`EditorInspectorPlugin`）是 Fuse 在 Inspector 面板的核心入口，在选中 Fuse 相关节点或资源时自动激活。

### 适用范围

对于以下类型，插件自动接管 Inspector 渲染：

| 类型 | 生效行为 |
|------|----------|
| `BaseInstruction` | 继承默认属性编辑 |
| `BaseEvent` | 添加「选择事件」按钮 |
| `BaseCondition` | 添加「选择条件」按钮 |
| `BaseVariable` | 继承默认属性编辑 |
| `ActionRunner` | 继承默认属性编辑 |
| `BaseTrigger` | **数据流卡片** + 导出/导入按钮 |
| 含 `instructions` / `event` / `condition` 属性的对象 | 按钮增强 |

**选择器按钮**用于快速替换事件/条件资源：

```
[ 点击以选择事件... ▼ ]   ← BaseEvent 属性
[ 点击以选择条件... ▼ ]   ← BaseCondition 属性
```

点击后打开 `ComponentSelector` 弹窗，展示注册表中所有可用组件供选择。

---

### Inspector 数据流卡片

当选中 **BaseTrigger** 节点（如 Trigger 或 MultiEventTrigger）时，Inspector 底部自动生成一张**可折叠的数据流信息卡**，直观展示该 Trigger 的指令链整体结构。

#### 触发器按钮

Inspector 底部出现一行按钮：

```
[📊 数据流: OnInterval (5指令, 3节点, 8变量, 2信号)]     ← 数据流汇总
[📦 导出 (Trigger/触发器)] [📥 导入预设]                  ← 预设操作
```

`📊 数据流` 按钮是**可点击折叠**的，点击展开/收起数据流卡片。

#### 数据流卡片内容

卡片以缩进文本形式展示分析结果：

```
数据流
  事件: OnInterval
  操作节点: Player, Enemy, ScoreLabel
  变量: [local] damage, cooldown | [scope] hp(../Player) | [global] score
  信号: score_changed(ScoreManager) | on_death(Player)
  指令链 (5 条)
    ┊ SetVariable → damage = 25
    ┊ CompareVariable → hp > 0 ?
    ┊ TweenMoveTo → 移动到 Enemy
    ┊ EmitSignal → score_changed
    ┊ LogInstruction → "攻击完成"
```

**数据来源**：`InstructionAnalyzer.build_topology()` 分析结果，包含：

| 字段 | 说明 |
|------|------|
| `event` | 事件资源名称 |
| `nodes` | 指令中引用到的所有操作节点路径 |
| `variables` | 按 local/scope/global 分类的变量信息 |
| `signals` | 指令链中所有 EmitSignal 引用的信号 |
| `instructions_flat` | 扁平化的指令链（含缩进前缀） |

---

### 预设操作

数据流卡片下方提供预设导出/导入按钮，详细操作见 [预设系统使用指南](55-preset-system-guide.md)。

#### 导出（Export）

- 自动检测当前节点的预设层级（L2/L3/L4）
- 按钮文本动态显示当前层级：`📦 导出 (Trigger/触发器)`
- 点击弹出 `PresetExportDialog`，配置名称/分类/描述后导出 `.tres` + `.json`

**前置验证**：导出按钮仅在以下条件满足时显示：

| 层级 | 条件 |
|------|------|
| L2 (Trigger) | `event_definition` 已配置 |
| L3 (Runner) | `action_runner` 已配置 |
| L4 (MultiEventTrigger) | 至少 1 个 `enabled` 的绑定 |

若验证不通过，导出按钮不显示（仅显示导入按钮）。

#### 导入（Import）

- 始终可用
- 点击打开 `FileDialog`，过滤 `.tres` / `.json`
- 根据预设层级创建对应节点（Trigger / Runner / MultiEventTrigger）
- 自动弹出 NodePath 映射确认对话框

---

### Inspector 属性识别流程

`_parse_property()` 的判断流程（主流程；指令数组委托给独立的 `instructions_array_inspector_plugin.gd`）：

```
1. 是否是指令数组属性？             → 委托 instructions_array_inspector_plugin
2. 类型为 OBJECT + PROPERTY_HINT_RESOURCE_TYPE
   + 类型字符串包含 "BaseEvent"     → 添加事件选择器按钮
3. 类型为 OBJECT + PROPERTY_HINT_RESOURCE_TYPE
   + 类型字符串包含 "BaseCondition"  → 添加条件选择器按钮
4. 否则 → 不处理，返回 false
```

---

## Scope 变量编辑器

`ScopeVariableContainerPlugin`（`EditorInspectorPlugin`）为 `ScopeVariableContainer` 节点提供专用的变量编辑面板。

**文件:** `editor/scope_variable_container_plugin.gd`
**目标节点:** `core/base/scope_variable_container.gd`

### 界面布局

选中场景中的 `ScopeVariableContainer` 节点后，Inspector 中显示：

```
+------------------------------------------------------+
| 作用域变量                                            |
+------------------------------------------------------|
| [────────────────────]                               |
|                                                       |
|   health = 100                                        |
|   mana = 50                                           |
|   current_state = "idle"                              |
|                                                       |
| [────────────────────]                               |
| [+ 添加变量]  [- 删除变量]  [↻ 刷新]                  |
+------------------------------------------------------+
```

### 功能

| 按钮 | 说明 |
|------|------|
| **添加变量** | 创建新变量，自动命名 `new_var_{索引}`，初始值 `0` |
| **删除变量** | 删除列表中选中的变量 |
| **刷新** | 重新从节点读取变量列表并更新显示 |

### 格式化显示

变量值按类型格式化显示：

| 值类型 | 显示格式 |
|--------|----------|
| null | `变量名 = null` |
| String | `变量名 = "文本内容"` |
| Array | `变量名 = [N elements]` |
| Dictionary | `变量名 = {N keys}` |
| 其他 | `变量名 = value` (直接调用 `str()`) |

### 编辑操作

所有修改（添加/删除/刷新）后自动调用 `notify_property_list_changed()`，同步更新 Inspector 其余属性的显示状态。

---

## 协作场景

三个面板在编辑器中的协作关系：

```
┌─────────────────────────────────────────────────────┐
│                     Godot Editor                    │
│                                                      │
│  ┌────────────────────┐  ┌────────────────────────┐│
│  │   Scene Dock       │  │  Inspector (Fuse 增强) ││
│  │                    │  │                        ││
│  │  ☐ Trigger (选中)  │  │  event: [选择事件 ▼]  ││
│  │    ├─ ActionRunner │  │  📊 数据流卡片         ││
│  │    └─ ...          │  │  📦 导出  📥 导入      ││
│  │                    │  │                        ││
│  │  ☐ ScopeVarContr. │  │  作用域变量编辑器       ││
│  │    (选中)          │  │  [+] [-] [↻]          ││
│  └────────────────────┘  └────────────────────────┘│
│                                                      │
│  ┌──────────────────────────────────────────────────┐│
│  │  Bottom Dock                                     ││
│  │                                                  ││
│  │  [VariableWatcher]                               ││
│  │                                                  ││
│  │  变量监视器（问题标注在 Fuse Topology 主屏查看）  ││
│  └──────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────┘
```

### 典型工作流

**调试流程：**
1. 在场景中选中 `Trigger` → Inspector 查看**数据流卡片**确认指令链
2. 运行场景 → 底部 **VariableWatcher** 实时观察变量变化
3. 发现问题 → **Fuse Topology 主屏**刷新自动标注指令序列问题（红=error/黄=warning）
4. 修复 → 从 Inspector 导出预设备份 → 继续迭代

**配置流程：**
1. 场景中添加 `ScopeVariableContainer` 节点
2. Inspector 中通过**作用域变量编辑器**添加变量初值
3. Trigger 中的指令引用这些 scope 变量
4. 运行后 **VariableWatcher** 显示 scope 变量的运行时值

---

## 常见问题

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| Inspector 未显示数据流卡片 | 选中节点不是 BaseTrigger | 选中 Trigger / MultiEventTrigger 节点 |
| Topology 中指令节点标红 | `analyze_problems` 检测到 error（如 local 未声明变量） | 选中该节点，右侧详情面板查看具体问题 |
| 作用域变量编辑器空白 | ScopeVariableContainer 无变量 | 点击「添加变量」创建 |
| 导出按钮不显示 | 前置验证未通过 | 检查 event_definition/action_runner 配置 |
| 本地化文本未生效 | 编辑器语言检测延迟 | 重启编辑器或切换语言 |

---

**相关文档:**
- [预设系统使用指南](55-preset-system-guide.md)
- [变量监视器使用指南](56-variable-watcher-guide.md)
- [变量系统指南](01-variable_system_guide.md)
- [调试系统指南](25-debugging-guide.md)
- [断点指南](26-breakpoint-guide.md)
