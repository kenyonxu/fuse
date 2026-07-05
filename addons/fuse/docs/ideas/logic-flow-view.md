# 逻辑流视图 Tab（Logic Flow View）

## 状态

提案

## 动机

当 Trigger 中的指令序列变长（10+ 条指令），或者 MultiEventTrigger 管理多个事件绑定时，用户在 Inspector 的列表视图中很难把握整体逻辑流。缺少可视化概览是当前最大的体验痛点之一。

## 核心设计

在 Godot 编辑器主界面增加一个 **Logic Flow** 标签页，与 2D、3D、Script 并列。

### 交互方式

**选中节点模式（V1）：**
1. 用户在 2D/3D 视图中选中一个带 Trigger/Runner 的节点
2. 切到 Logic Flow 标签 → 自动显示该节点的逻辑流
3. 左侧面板列出场景中所有含逻辑的节点，可点击快速切换
4. 嵌套的 PackedScene 实例显示为可展开的子图卡片

**全场景概览模式（V2，后续迭代）：**
- 缩小后看到整个场景所有 Trigger 节点的关系图
- 点击某个 Trigger 节点卡片 → 放大到该节点的详细逻辑流

### 渲染方案

使用 Godot 4.6 内置 **GraphEdit** 控件（只读模式）：

| 指令类型 | GraphNode 表现 |
|---------|---------------|
| 普通指令 | 单个矩形节点，显示名称+关键参数 |
| IfElse | 菱形/分支节点，true/false 两个输出端口 |
| ForLoop / WhileLoop | 循环框，内部嵌套子节点 |
| Wait / Delay | 虚线边框节点，标注等待时间 |
| 子 ActionRunner | 双层边框的可展开卡片 |

### 嵌套场景处理

遇到 PackedScene 实例节点时，递归扫描其内部的 Trigger/Runner，在流图中显示为可展开的分组。

### 技术方案

通过 EditorPlugin 注册为主视图 Tab：

```gdscript
func _enter_tree():
    _logic_flow_panel = preload("logic_flow_panel.tscn").instantiate()
    EditorInterface.get_editor_main_screen().add_child(_logic_flow_panel)
    _make_visible(false)

func _has_main_screen() -> bool:
    return true

func _get_plugin_name() -> String:
    return "Logic Flow"
```

数据源：直接从场景树读取 Trigger/Runner 节点的 Resource 配置，遍历 ActionRunner 的指令列表生成对应 GraphNode。

## 交付计划

### V1 - 选中节点视图

- [ ] 主视图 Tab 注册
- [ ] 选中节点的逻辑流渲染
- [ ] 左侧节点列表（扫描场景中所有 Trigger/Runner）
- [ ] 基础指令类型可视化（普通/分支/循环）
- [ ] 跟随选中节点自动刷新

### V2 - 全场景视图

- [ ] 全场景缩略图模式
- [ ] 跨节点信号连线（Trigger A 的指令触发 Trigger B）
- [ ] 运行时执行高亮（配合 DebugVisualizer）
- [ ] 导出为图片/PDF
