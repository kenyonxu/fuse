> 🌐 中文 | [**English**](../../../en_US/user_docs/guides/26-breakpoint-guide.md)

# 断点指令使用指南

BreakpointInstruction 是 Fuse 的调试工具指令。将它插入指令列表中，执行到该位置时会输出变量快照到 Godot 输出窗口，可选暂停执行以检查状态。

**文件:** [breakpoint_instruction.gd](../../../../instructions/debug/breakpoint_instruction.gd)
**分类:** Debug
**图标:** Debug

## 快速开始

在 ActionRunner 的指令列表中，找到目标指令的位置，在它之前插入一条 BreakpointInstruction：

1. 点击指令列表上方的添加按钮
2. 在指令选择器中搜索「断点」或「Breakpoint」
3. 插入后运行场景，断点命中时输出窗口会显示变量信息

```
输出窗口输出示例：

[BREAKPOINT] "检查血量" — 命中 #1
  作用域变量: {"health": 45, "max_health": 100}
  全局变量: {"player_score": 1200}
```

## 属性

### Condition 分组

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| use_expression_condition | bool | false | 启用条件断点 |
| condition | String | "" | 条件表达式（启用条件断点后显示） |

### 基础属性

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| label | String | "" | 自定义标签，用于在输出中标识断点 |
| ignore_count | int | 0 | 忽略前 N 次命中 |
| log_variables | bool | true | 命中时输出变量信息到输出窗口 |
| pause_execution | bool | true | 命中时暂停执行（仅编辑器模式有效） |

### Scope Source Config 分组

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| scope_source | enum | Nearest | 作用域变量的来源 |
| custom_scope_id | String | "" | 自定义作用域 ID（scope_source = Custom ID 时显示） |
| target_node_path | NodePath | "" | 目标节点路径（scope_source = Target Node 时显示） |

scope_source 同时控制两件事：
- 变量输出时从哪个作用域容器读取作用域变量
- 条件表达式中 `{scope:xxx}` 引用的变量来源

## 使用场景

### 场景 1：检查变量状态

最简单的用法——查看某个时刻的变量值。插入断点，设置标签，运行场景：

```
label: "受伤前"
log_variables: true
pause_execution: false
```

输出：
```
[BREAKPOINT] "受伤前" — 命中 #1
  局部变量: {"damage": 25, "is_critical": true}
  作用域变量: {"health": 100, "max_health": 100}
```

### 场景 2：条件断点

只在特定条件下触发断点，避免被无关命中淹没输出。

开启 `use_expression_condition`，在 `condition` 中写入表达式：

```
use_expression_condition: true
condition: {scope:health} < 30
```

输出（仅血量低于 30 时触发）：
```
[BREAKPOINT] "低血量检查" — 命中 #1
  条件: {scope:health} < 30 → true
  作用域变量: {"health": 28, "max_health": 100}
```

条件表达式支持与 MathExpression 相同的变量引用语法：

```
{local:变量名}     - 本地变量
{scope:变量名}     - 作用域变量
{global:变量名}    - 全局变量
```

条件评估失败时会降级为无条件断点，输出警告但不会中断执行。

### 场景 3：跳过前 N 次命中

循环中插入断点时，用 `ignore_count` 跳过前几次迭代：

```
ignore_count: 3
```

第 1-3 次命中被跳过，第 4 次开始输出变量信息。

命中计数在每次 ActionRunner 执行开始时自动重置，不需要手动管理。

### 场景 4：暂停执行

在关键位置暂停运行时，检查输出窗口中的变量状态后按 Enter 键继续：

```
pause_execution: true
```

暂停时屏幕中央会显示提示面板，变量信息输出在 Godot 输出窗口中。

按 **Enter** 键恢复运行。恢复后后续指令正常执行。

> **注意：** 暂停功能仅在编辑器模式下有效。导出构建中会自动降级为仅日志输出。

### 场景 5：指定作用域来源

默认从最近的作用域容器读取变量。如果你的项目有多个作用域容器，可以通过 `scope_source` 指定读取哪个：

```
scope_source: Trigger Scope
```

| scope_source 值 | 效果 |
|-----------------|------|
| Nearest | 最近的作用域容器（默认） |
| Custom ID | 指定 `custom_scope_id` 对应的容器 |
| Trigger Scope | Trigger 节点上的作用域容器 |
| Target Node | `target_node_path` 指向的节点上的作用域容器 |

## 执行流程

```
execute()
  ① 检测新执行周期 → 重置命中计数
  ② _hit_count += 1
  ③ ignore_count 检查 → 未满足则跳过
  ④ use_expression_condition 且 condition 非空 → 评估表达式
     → false → 跳过断点
     → 评估失败 → 降级为无条件，继续
  ⑤ log_variables == true → 输出变量快照到输出窗口
  ⑥ pause_execution == true 且编辑器模式 → 显示提示面板 → 等待 Enter 键
     → 导出构建 → 降级为仅日志输出 + 警告
  ⑦ 完成
```

## 输出格式

命中时输出到 Godot 输出窗口（带颜色格式化）：

```
[BREAKPOINT] "检查血量" — 命中 #2
  条件: {scope:health} < 50 → true
  局部变量: {"counter": 5, "temp": "test"}
  作用域变量: {"health": 45, "max_health": 100}
  全局变量: {"player_score": 1200}
```

- 只显示非空的变量类别
- 标签为空时显示「未命名」

## 与其他调试指令的区别

| 指令 | 用途 | 暂停 | 条件 |
|------|------|------|------|
| BreakpointInstruction | 检查变量快照 | Enter 键恢复 | 表达式条件 |
| Print | 输出自定义消息 | 不支持 | 不支持 |
| PrintVariable | 输出单个变量 | 不支持 | 不支持 |

---

**文档维护**: Fuse 开发团队
**最后更新**: 2026-03-19
**版本**: 1.0.0
