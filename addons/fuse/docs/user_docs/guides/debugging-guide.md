# 调试系统用户指南

Fuse 提供了一套调试工具，帮助你在开发和运行时排查指令执行问题。调试系统包含 3 个指令和 2 个编辑器工具，覆盖从简单的日志输出到完整的断点调试。

**分类:** Debug
**相关文件:** `addons/fuse/instructions/debug/`, `addons/fuse/editor/debugging/`

---

## 调试指令概览

| 指令 | 用途 | 输出变量快照 | 暂停执行 | 条件触发 |
|------|------|:---:|:---:|:---:|
| Print | 输出自定义消息 | 否 | 否 | 否 |
| PrintVariableValue | 输出单个变量值 | 否 | 否 | 否 |
| BreakpointInstruction | 断点调试 | 是 | 是 (编辑器) | 是 |

---

## Print -- 打印消息

最基础的调试指令，将自定义消息输出到 Godot 输出窗口。

**文件:** [print.gd](../../../instructions/debug/print.gd)
**图标:** Debug

### 属性

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| message | String | "Hello, World!" | 要打印的消息文本 |

### 输出格式

Godot 输出窗口:
```
[PrintInstruction] 你的消息内容
```

同时通过 ExecutionContext 输出日志消息。

### 使用场景

**标记执行流程:**
在指令序列中插入 Print 来确认执行到了哪个位置:
```
message: "开始处理受伤逻辑"
```

**输出中间结果:**
```
message: "计算完成，伤害值为 25"
```

### 验证规则

- message 不能为空字符串

### 注意事项

- Print 是同步指令，执行后立即完成
- 消息会同时输出到 Godot 控制台和 ExecutionContext 日志
- 适用于快速调试，不需要条件判断或变量检查的场景

---

## PrintVariableValue -- 打印变量值

输出指定变量的名称、作用域和当前值。

**文件:** [print_variable_value.gd](../../../instructions/debug/print_variable_value.gd)
**图标:** FileList

### 属性

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| variable_name | String | "" | 变量名称 |
| variable_scope | enum | Local | 变量作用域 (Local/Scope/Global) |
| scope_source | enum | Nearest | 作用域来源 (仅 Scope 作用域) |
| custom_scope_id | String | "" | 自定义作用域 ID |
| target_node_path | NodePath | "" | 目标节点路径 |

### 作用域说明

| variable_scope | 说明 |
|----------------|------|
| Local | 从 ExecutionContext 的本地变量中读取 |
| Scope | 从作用域容器中读取 (需指定来源) |
| Global | 从全局变量中读取 |

使用 Scope 作用域时，可通过 scope_source 指定来源:

| scope_source | 效果 |
|-------------|------|
| Nearest | 最近的作用域容器 (默认) |
| Custom ID | 指定 custom_scope_id 对应的容器 |
| Trigger Scope | Trigger 节点上的作用域容器 |
| Target Node | target_node_path 指向的节点上的作用域容器 |

### 输出格式

Godot 输出窗口:
```
[LOCAL] 变量名: "变量值" (类型: String)
[SCOPE] 变量名: 42 (类型: int)
[GLOBAL] 变量名: Vector2(1.50, 2.30)
```

### 支持的类型格式化

| 类型 | 输出格式 |
|------|---------|
| bool | `true` / `false` |
| int | 直接输出数字 |
| float | 直接输出数字 |
| String | `"值"` (带引号) |
| Vector2 | `Vector2(x.xx, y.xx)` |
| Vector3 | `Vector3(x.xx, y.xx, z.xx)` |
| Color | `Color(r.xx, g.xx, b.xx, a.xx)` |
| BaseVariable | 输出其内部 value |
| null | `null` |

### 使用场景

**检查本地变量:**
```
variable_name: "health"
variable_scope: Local
```

**检查作用域变量:**
```
variable_name: "player_score"
variable_scope: Scope
scope_source: Trigger Scope
```

**检查全局变量:**
```
variable_name: "game_time"
variable_scope: Global
```

### 验证规则

- variable_name 不能为空
- 使用 Scope 作用域时需要 ScopeVariableManager 实例

---

## BreakpointInstruction -- 断点调试

功能最全面的调试指令。命中时输出所有变量快照，支持条件触发和执行暂停。

**文件:** [breakpoint_instruction.gd](../../../instructions/debug/breakpoint_instruction.gd)
**图标:** Debug

### 核心属性

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| label | String | "" | 自定义标签，标识断点 |
| ignore_count | int | 0 | 忽略前 N 次命中 |
| log_variables | bool | true | 命中时输出变量信息 |
| pause_execution | bool | true | 命中时暂停 (仅编辑器) |
| use_expression_condition | bool | false | 启用条件断点 |
| condition | String | "" | 条件表达式 |
| scope_source | enum | Nearest | 作用域变量来源 |

### 功能概述

- **变量快照**: 自动输出局部变量、作用域变量、全局变量
- **条件断点**: 支持表达式条件，只在满足条件时触发
- **忽略次数**: 跳过前 N 次命中，适合循环调试
- **暂停执行**: 编辑器模式下可暂停游戏，按 Enter 键恢复

### 详细用法

断点指令有完整的使用指南，请参阅:

**[断点指令详细指南](breakpoint-guide.md)**

该指南包含:
- 快速开始
- 属性详细说明
- 5 个使用场景 (检查变量、条件断点、跳过命中、暂停执行、指定作用域)
- 执行流程
- 输出格式说明

---

## 编辑器调试工具

### DebugVisualizer -- 调试可视化面板

提供图形化界面来查看执行历史、性能指标和调试信息。

**文件:** [debug_visualizer.gd](../../../editor/debugging/debug_visualizer.gd)

#### 功能

- **执行历史树**: 以树形结构展示指令执行记录，包含每一步的类型、结果和耗时
- **颜色编码**: 绿色表示成功，红色表示错误，黄色表示性能问题，浅蓝色表示开始
- **详情面板**: 点击树中的步骤查看详细信息 (执行结果、性能数据、变量状态)
- **自动刷新**: 可开启 1 秒间隔自动刷新
- **导出功能**: 将执行历史导出为 JSON 文件

#### 界面布局

```
+------------------------------------------+
| [刷新] [清除] [导出] [x 自动刷新]       |
+---------------------+--------------------+
| 执行历史 (树形)     | 详情面板           |
|  执行 #1 (0.35s)    | 基本信息            |
|    开始: Print       | 执行结果            |
|    完成: Print 0.01s | 性能数据            |
|    开始: MoveNode    | 变量状态            |
|    完成: MoveNode 0.3s|                   |
|  执行 #2 (0.12s)    |                    |
|    ...               |                    |
+---------------------+--------------------+
| 性能图表 (占位)                          |
+------------------------------------------+
```

#### 操作方式

1. 运行场景并触发一些指令执行
2. 打开 DebugVisualizer 面板
3. 点击左侧树中的执行记录或步骤
4. 右侧显示详细信息
5. 点击 "刷新" 手动更新，或勾选 "自动刷新"
6. 点击 "导出" 保存为 JSON 文件

---

### ExecutionTracker -- 执行追踪器

在后台记录指令执行的详细历史，提供数据给 DebugVisualizer 显示。

**文件:** [execution_tracker.gd](../../../editor/debugging/execution_tracker.gd)

#### 核心功能

| 功能 | 说明 |
|------|------|
| record_instruction_start() | 记录指令开始执行 |
| record_instruction_complete() | 记录指令完成执行 |
| record_custom_event() | 记录自定义事件 |
| record_error() | 记录执行错误 |
| record_performance_bottleneck() | 记录性能瓶颈 |
| start_tracking() / stop_tracking() | 开始/停止跟踪会话 |
| get_execution_history() | 获取执行历史 |
| get_execution_stats() | 获取执行统计 |
| export_execution_history() | 导出为 JSON |

#### 跟踪配置

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| max_history_size | 100 | 最大历史记录数 |
| track_performance_metrics | true | 是否记录性能指标 |
| track_memory_usage | false | 是否记录内存使用 |
| track_variable_changes | true | 是否记录变量变化 |

#### 执行统计

调用 `get_execution_stats()` 获取:

```json
{
  "total_executions": 15,
  "total_time": 2340.0,
  "average_time": 156.0,
  "average_instructions": 8.5,
  "total_errors": 1,
  "performance_issues": 2,
  "instruction_counts": [8, 9, 10],
  "error_counts": [0, 1, 0]
}
```

#### 导出格式

执行历史导出为 JSON 文件，包含:
- export_time: 导出时间
- execution_history: 完整执行记录
- stats: 执行统计

---

## 调试工作流

### 工作流 1: 快速排查问题

1. 在可疑位置插入 **Print** 指令，标记执行流程
2. 运行场景，观察输出窗口确认执行顺序
3. 使用 **PrintVariableValue** 检查关键变量的值
4. 定位问题后移除调试指令

### 工作流 2: 断点调试

1. 在关键位置插入 **BreakpointInstruction**
2. 设置标签便于识别 (如 "受伤前检查")
3. 运行场景，观察输出窗口中的变量快照
4. 如需暂停，开启 `pause_execution`
5. 在输出窗口中分析变量状态，按 Enter 继续
6. 详细用法参阅 [断点指南](breakpoint-guide.md)

### 工作流 3: 性能分析

1. 确保 ExecutionTracker 正在跟踪 (DebugVisualizer 自动管理)
2. 运行场景，执行需要分析的指令序列
3. 打开 DebugVisualizer，查看执行历史
4. 关注红色 (错误) 和黄色 (性能问题) 的执行记录
5. 点击具体步骤查看详细性能数据
6. 使用 "导出" 保存完整记录用于离线分析

### 工作流 4: 条件断点调试

1. 插入 **BreakpointInstruction**
2. 开启 `use_expression_condition`
3. 编写条件表达式，如 `{scope:health} < 30`
4. 运行场景，断点只在血量低于 30 时触发
5. 检查变量快照，分析问题原因

---

## 调试指令对比

| 特性 | Print | PrintVariableValue | BreakpointInstruction |
|------|:-----:|:------------------:|:--------------------:|
| 自定义消息 | 支持 | 不支持 (自动格式化) | 通过 label |
| 输出变量值 | 不支持 | 单个变量 | 所有变量快照 |
| 条件触发 | 不支持 | 不支持 | 表达式条件 |
| 暂停执行 | 不支持 | 不支持 | 支持 (编辑器) |
| 忽略次数 | 不支持 | 不支持 | 支持 |
| 编辑器影响 | 无 | 无 | 可暂停游戏 |
| 导出构建 | 正常工作 | 正常工作 | 降级为仅日志 |
| 性能开销 | 极低 | 低 | 中等 |

---

## 最佳实践

1. **开发阶段多用断点，发布前清理**: BreakpointInstruction 在导出构建中会降级为日志输出，但建议发布前移除所有调试指令
2. **使用标签标识断点**: 给每个 BreakpointInstruction 设置有意义的 label，便于在输出窗口中识别
3. **利用条件断点减少噪音**: 循环中调试时，使用条件断点只在特定条件下触发
4. **定期导出执行历史**: DebugVisualizer 的导出功能可以保存 JSON 记录，方便追踪间歇性问题
5. **组合使用**: Print 标记流程 + PrintVariableValue 检查变量 + BreakpointInstruction 深入分析

---

**文档维护**: Fuse 开发团队
**最后更新**: 2026-03-19
**版本**: 1.0.0
