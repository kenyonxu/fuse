# Topology Tree 强化 + 指令详情 Spec

**日期:** 2026-07-04
**关联:** [roadmap Stage 8](2026-06-16-fuse-development-roadmap.md) · [Stage 8 plan](2026-06-29-stage8-plan.md)
**状态:** ✅ 完成（2026-07-04）。实现见 [plan](2026-07-04-topology-tree-enhance-plan.md)，验收通过（图标+分支标记+嵌套场景分组+MultiEventTrigger 展开+指令详情）。
**决策来源:** GraphEdit 评估 —— 指令链是树不是图，Tree 比 GraphEdit 更清晰

---

## 1. 背景

### 1.1 现状问题

[fuse_topology.gd](../../editor/topology/fuse_topology.gd) 当前：

| 问题 | 详情 |
|---|---|
| **指令不可选** | [line 130](../../editor/topology/fuse_topology.gd#L130) `set_selectable(0, false)` —— 用户只能选 Trigger，不能选单个指令 |
| **指令显示贫乏** | `📦 指令名`（纯文本，无图标/颜色/参数） |
| **右侧是整个 Trigger 概要** | 选中 Trigger → 显示该 Trigger 的全部数据流（事件/节点/变量/信号/指令链），不是选中指令的详情 |
| **GraphEdit 占位但不实用** | 有 instructions_tree 时显示 GraphEdit，但连线乱 + 占空间，用户觉得不如 Tree |

### 1.2 方向调整

**移除 GraphEdit 默认显示**，强化 Tree + 右侧详情：
- **左侧 Tree**：指令可选 + 图标 + 分类颜色 + 参数摘要 + if/else 分支标记
- **右侧详情**：选中指令 → 该指令的完整详情（参数/引用/上下文）

---

## 2. 设计

### 2.1 左侧 Tree 强化

#### 2.1a 指令项可选

```gdscript
# 当前（line 130）:
i_item.set_selectable(0, false)

# 改为:
i_item.set_selectable(0, true)
i_item.set_metadata(0, {"type": "instruction", "inst": inst_info, "report": report})
```

选中指令 → 右侧显示该指令详情。

#### 2.1b 指令图标

Tree 项加图标（`set_icon`）。**优先用 Godot builtin icon**（EditorIcons），回退用 emoji。

```
[icon] OnInputKey（事件触发）
[icon] 加载全局变量
[icon] 暂停游戏
[icon] If: health > 0
  [icon] MoveNode
  [icon] PlaySound
[icon] Wait 1.0s
```

**builtin icon（优先）：**
- 数据来源：组件 metadata 的 `builtin_icon` 字段（Stage 9 已补全，如 `"int"` / `"MoveNode"` / `"AudioStreamPlayer"` 等）
- 获取方式：`EditorInterface.get_editor_theme().get_icon(builtin_icon_name, "EditorIcons")`
- 主屏 @tool 环境下 EditorInterface 全局可用，无兼容性问题
- 视觉与 Inspector/选择器统一

**emoji 回退：**
- 无 builtin_icon 或 get_icon 返回空 → 用分类 emoji 前缀

| 分类 | emoji | 规则 |
|---|:--:|---|
| 变量 | 📊 | category 含 "变量" / "Variables" |
| 节点操作 | 🔧 | category 含 "节点" / "Node" |
| 流控 | 🔀 | If/Else/While/For/Loop/Break/Continue |
| 音频 | 🎵 | category 含 "音频" / "Audio" |
| UI | 🖼 | category 含 "UI" |
| 动画 | 🎬 | category 含 "动画" / "Animation" |
| 物理 | ⚙ | category 含 "物理" / "Physics" |
| Tween | ✨ | category 含 "Tween" |
| 相机 | 📷 | category 含 "相机" / "Camera" |
| 默认 | ▶ | 其他 |

> 数据需求：InstructionAnalyzer._analyze_instructions 需在 flat/tree 中存入 inst 引用（或 builtin_icon 名），Tree 构建时读取。

#### 2.1c if/else 分支标记

指令链有 `instructions_flat`（prefix 缩进）。利用 prefix 判断分支层级：
- prefix 空 → 顶层指令（▶）
- prefix 含缩进 + 在 if/else 下 → 分支标记

Tree 本身已用缩进（子项），但指令项都是 Trigger 的直接子项（prefix 文本缩进）。

**改进**：利用 `instructions_tree`（Stage 8b-0）构建真正的 Tree 层级（不是 prefix 文本）：

```
Trigger (Tree item)
  ├── OnInputKey (event)
  ├── 加载全局变量 (instruction)
  ├── 暂停游戏 (instruction)
  ├── If: health > 0 (branch)
  │   ├── [then] MoveNode
  │   └── [else] GameOver
  └── PlaySound (instruction)
```

用 instructions_tree 的 children（then/else/loop）构建嵌套 Tree item：
- then 子项前缀 `✓`
- else 子项前缀 `✗`
- loop 子项前缀 `↻`

#### 2.1d 参数摘要

指令项显示 `指令名(关键参数)`：
- SetIntVariable → `设置变量 health = 100`
- MoveNode → `移动节点 [Player] → (100, 200)`
- If → `如果 health > 0`

参数来源：指令实例的 `get_description()`（BaseInstruction 有此方法，返回关键参数描述）。

> 但 instructions_flat 只存 `{name, prefix}`，不含指令实例引用。需改为存 inst 引用（或用 instructions_tree 的 node_info.inst）。

### 2.2 右侧详情强化

选中单个指令 → 右侧 RichTextLabel 显示该指令详情：

```
┌─ 指令详情 ───────────────────────┐
│ 加载全局变量                       │
│ 分类: 变量操作                      │
│                                    │
│ 参数:                              │
│   target_variable: health          │
│   target_variable_scope: GLOBAL    │
│   new_value: 100                   │
│                                    │
│ 引用:                              │
│   变量: health (GLOBAL, write)     │
│   节点: (无)                       │
│   信号: (无)                       │
│                                    │
│ 上下文:                            │
│   所属 Trigger: OnInputKey         │
│   位置: 指令链第 2 条              │
│   嵌套: 顶层                       │
└────────────────────────────────────┘
```

数据来源：
- 参数：指令实例的 `get_property_list()`（反射，Stage 6.5 已有）
- 引用：InstructionAnalyzer._extract_nodepaths / _extract_variables（对单个指令）
- 上下文：report 的 trigger_name + 指令在 flat 中的 index + prefix/branch

### 2.3 GraphEdit 处理

- **移除 GraphEdit 默认显示**（_on_item_selected 不再调 _show_graph）
- GraphEdit 代码保留（fuse_graph_edit.gd / fuse_graph_builder.gd / fuse_graph_node.gd），不删（将来可选启用）
- 右侧统一用 RichTextLabel（强化版）

---

## 3. 不做

- ❌ 节点拖拽/重排序（Tree 只读）
- ❌ 内联编辑指令参数（只看不改）
- ❌ 多 Trigger 同时显示详情
- ❌ Godot builtin icon 集成（V1 用 builtin icon 优先 + emoji 回退）

---

## 4. 依赖

- Stage 6.5 InstructionAnalyzer（反射 + 命名启发式提取）
- Stage 8b-0 instructions_tree（Tree 层级构建）
- BaseInstruction.get_description()（参数摘要）

---

## 5. 验收

1. **左侧 Tree**：指令项可选 + 分类 emoji + then/else 标记 + 参数摘要
2. **选中指令**：右侧显示该指令详情（参数/引用/上下文）
3. **选中 Trigger**：右侧显示 Trigger 概要（事件/节点/变量/信号，现有 RichTextLabel 内容）
4. **GraphEdit 不默认显示**（右侧统一 RichTextLabel）
5. **回归**：Tree 导航 + 跨 Trigger 关联不受影响

---

**状态:** spec 待 Kai 审查。审查后写 plan。
