# Fuse 快速开始指南

欢迎使用 Fuse 可视化编程系统！本指南将帮助你在 5 分钟内上手 Fuse 的基本功能。

## 目录

1. [系统简介](#系统简介)
2. [5 分钟上手](#5-分钟上手)
3. [基本概念](#基本概念)
4. [常见任务](#常见任务)
5. [下一步学习](#下一步学习)

---

## 系统简介

Fuse 是一个功能强大的可视化编程系统，让你无需编写代码就能创建复杂的游戏逻辑。

### 核心特性

- **可视化编程**：通过拖放和配置创建逻辑
- **事件驱动**：响应游戏事件（按键、碰撞、信号等）
- **指令系统**：丰富的内置指令库
- **变量管理**：全局和局部变量支持
- **易于扩展**：创建自定义事件和指令

### 适用场景

- 游戏逻辑控制
- UI 交互处理
- 关卡事件触发
- 玩家状态管理
- 音效和特效触发

---

## 5 分钟上手

### 步骤 1：选择触发器类型

Fuse 提供三种组件来响应事件并执行指令。根据你的需求选择：

| 组件 | 适合场景 | 复杂度 |
|------|---------|--------|
| **Runner** | 监听一个信号、从代码调用 | 低 |
| **Trigger** | 需要事件过滤、触发控制（trigger_once / 冷却） | 中 |
| **MultiEventTrigger** | 同一节点上有多个事件-动作绑定 | 高 |

> 不确定用哪个？查阅 [触发器选型指南](guides/trigger-selection-guide.md)。

### 步骤 2：添加节点到场景

1. 在 Godot 编辑器中，选择场景中合适的父节点
2. 添加子节点，搜索并选择对应的组件名称
3. 命名节点，例如 "OnButtonPress" 或 "PlayerEvents"

```
# Runner — 最简单的入门方式
场景树：
  UI
    Button
    Runner
      action_runner: (你创建的 ActionRunner 资源)
      target_node: ../Button
      signal_name: "pressed"
```

```
# Trigger — 需要更多控制时
场景树：
  Player
    CollisionShape2D
    Trigger (OnHit)
      event_definition: OnBodyEntered (Event 资源)
      action_runner: (你创建的 ActionRunner 资源)
```

### 步骤 3：创建动作序列

动作序列（ActionRunner）定义了要执行的一系列指令。

1. 选中刚创建的触发器节点
2. 在 Inspector 面板中，找到 **action_runner** 属性
3. 点击下拉菜单，选择 **New ActionRunner**
4. 双击新创建的 ActionRunner 资源进行编辑

### 步骤 4：添加指令

指令（Instruction）是具体的操作单元。

1. 在 ActionRunner 资源编辑器中，找到 **instructions** 属性
2. 点击数组右侧的 `[+]` 按钮添加指令
3. 选择要执行的指令类型，例如：
   - `PrintVariableValue` — 打印变量值（调试用）
   - `SetVariable` — 设置变量值
   - `RunTargetNodeFunction` — 调用节点方法
   - `ChangeScene` — 切换场景

### 步骤 5：配置指令参数

每个指令都有可配置的参数。以 `PrintVariableValue` 为例：

1. 在对应字段输入参数值
2. 可以使用变量占位符，例如 `"{player_name} 得分了！"`
3. 配置其他可选参数

### 步骤 6：测试运行

1. 保存场景
2. 按 F5 运行游戏
3. 触发事件（点击按钮、按键、碰撞等）
4. 在控制台查看输出结果

**恭喜！你已经创建了第一个 Fuse 逻辑！**

---

## 基本概念

### 事件 (Event)

事件是触发动作的条件。Fuse 提供了丰富的事件类型：

| 分类 | 示例 |
|------|------|
| 生命周期 | OnSceneReady、OnEnterTree、OnExitTree |
| 输入 | OnInputKey、OnMouseEnter、OnMouseExit |
| 物理 | OnBodyEntered、OnArea2DEnter |
| 动画 | OnAnimationFinished、OnAnimationStarted |
| 音频 | OnAudioFinished、OnAudioStarted |
| UI | OnButtonPressed、OnTextChanged、OnValueChanged |
| 自定义 | OnTargetSignalEmit（监听任意节点信号） |

### 指令 (Instruction)

指令是要执行的操作单元：

| 分类 | 示例 |
|------|------|
| 控制流 | IfElse、ForLoop、While、Wait |
| 变量 | SetVariable、GetVariable、MathOperation |
| 节点操作 | MoveNode、RotateNode、SetProperty |
| 补间动画 | TweenProperty |
| 音频 | PlayAudio、StopAudio |
| 场景 | ChangeScene、InstantiateScene |

### 变量 (Variable)

变量用于存储和传递数据：

- **全局变量**：在整个游戏中访问，支持持久化
- **局部变量**：在触发器范围内访问
- **执行上下文变量**：在指令执行链中传递（如事件参数）

### 条件 (Condition)

条件用于控制指令是否执行：

| 类型 | 说明 |
|------|------|
| CompareVariable | 比较变量值（大于、等于等） |
| CheckVariable | 检查变量布尔值 |
| CheckNodeProperty | 检查节点属性 |
| 复合条件 | AND / OR 组合多个条件 |

### 触发器组件

Fuse 提供三种触发器组件，详见 [触发器选型指南](guides/trigger-selection-guide.md)：

| 组件 | 说明 | 详细文档 |
|------|------|---------|
| **Runner** | 轻量信号绑定 + 代码调用 | [Runner 指南](guides/runner-guide.md) |
| **Trigger** | 带 Event 的标准触发器 | — |
| **MultiEventTrigger** | 多事件合并触发器 | [MultiEventTrigger 指南](guides/multi-event-trigger-guide.md) |

---

## 常见任务

### 任务 1：按钮点击执行指令（Runner 方式）

最快的方式——无需 Event 资源：

1. 场景中添加 Button 节点和 Runner 节点
2. 配置 Runner：
   - **action_runner**: 创建一个 ActionRunner，添加你想执行的指令
   - **target_node**: 指向 Button 节点
   - **signal_name**: 选择 `pressed`
3. 运行游戏，点击按钮

### 任务 2：按键触发逻辑（Trigger 方式）

创建一个按空格键时执行指令的逻辑：

1. 添加 Trigger 节点
2. 配置 **event_definition**: 创建 OnInputKey Event 资源
3. 配置 **action_runner**: 创建 ActionRunner，添加指令
4. 在 OnInputKey 中设置 input_action 为 `ui_accept`
5. 运行游戏，按空格键触发

### 任务 3：碰撞检测触发（Trigger 方式）

1. 确保 Player 有 CollisionShape2D
2. 添加 Trigger 节点
3. 配置 **event_definition**: 创建 OnBodyEntered Event 资源
4. 配置 **action_runner**: 添加受伤处理指令
5. 可选：设置 **trigger_once** 或 **cooldown** 防止重复触发

### 任务 4：多事件合并（MultiEventTrigger 方式）

当一个节点需要响应多个事件时：

1. 添加 MultiEventTrigger 节点
2. 在 **event_bindings** 数组中添加多个 EventBinding
3. 每个绑定独立配置 event、action_runner、trigger_once 等
4. 或者：先创建多个 Trigger 节点，在场景树中右键 → **合并为 MultiEventTrigger**

---

## 下一步学习

### 指南文档

- [触发器选型指南](guides/trigger-selection-guide.md) — Runner / Trigger / MultiEventTrigger 怎么选
- [Runner 使用指南](guides/runner-guide.md) — 信号绑定与代码调用详解
- [MultiEventTrigger 使用指南](guides/multi-event-trigger-guide.md) — 多事件合并与拆分

### 系统指南

- [输入事件指南](guides/input-events-guide.md) — 键盘、鼠标、手柄
- [物理系统指南](guides/physics-guide.md) — 碰撞、射线检测
- [动画系统指南](guides/animation-guide.md) — 动画事件与控制
- [UI 系统指南](guides/ui-guide.md) — 按钮焦点、文本输入、值变化
- [Tween 补间动画指南](guides/tween-animation-guide.md) — 渐变、弹性动画
- [音频系统指南](guides/audio-guide.md) — 音效播放与控制
- [流程控制指南](guides/flow-control-guide.md) — 条件分支、循环、等待
- [断点指令指南](guides/breakpoint-guide.md) — 调试用断点指令

### 变量与表达式

- [全局变量管理器](guides/global_variable_manager_v2.md) — 全局变量系统
- [全局变量持久化](guides/global-variable-persistence-guide.md) — 存档与读取
- [表达式系统](guides/expression-guide.md) — 运行时表达式计算
- [Event Bus 指南](guides/event_bus_guide.md) — 跨场景事件通信

### 最佳实践

- [创建自定义指令](best_practices/custom_instruction.md) — 扩展指令系统
- [创建自定义事件](best_practices/custom_event.md) — 扩展事件系统

### 系统文档

- [可视化编程系统架构](../system_docs/architecture/visual_programming_complete_design_summary.md) — 系统设计概览
- [指令系统设计](../system_docs/architecture/instruction_system_design.md) — 指令执行机制

---

## 常见问题

### Q: Runner 和 Trigger 该用哪个？

**A**: 简单信号绑定用 Runner，需要事件过滤或触发控制用 Trigger。详见 [触发器选型指南](guides/trigger-selection-guide.md)。

### Q: 如何调试 Fuse 逻辑？

**A**: 在 Trigger 或 Runner 的 **log_level** 属性中设置 `DEBUG`，运行时会在控制台输出详细日志。也可以在 ActionRunner 中插入 `PrintVariableValue` 指令打印变量值。

### Q: 变量不更新怎么办？

**A**: 检查以下几点：

1. 变量名是否拼写正确
2. 变量作用域是否正确（全局 / 局部 / 执行上下文）
3. 查看控制台是否有错误信息

### Q: 如何从代码调用 Fuse 指令？

**A**: 使用 Runner 节点：

```gdscript
@onready var runner: Runner = $Runner

runner.run()
await runner.wait_completed()  # 等待执行完成
```

### Q: 指令执行顺序是什么？

**A**: 默认按顺序执行（SEQUENTIAL），可以通过 ActionRunner 的 execution_mode 修改：

- `SEQUENTIAL` — 顺序执行（默认）
- `PARALLEL` — 并行执行

---

## 获取帮助

### 文档资源

- [用户文档索引](README.md) — 所有用户文档
- [系统文档](../system_docs/README.md) — 深入技术文档
- [开发文档](../dev_docs/README.md) — 开发者文档

### 示例项目

- [演示场景](../../../demos/) — 功能演示

### 参考资源

- [Godot 官方文档](https://docs.godotengine.org/)
- [Game Creator 文档](https://gamecreator.io/)

---

**开始你的 Fuse 之旅吧！**

如有任何问题，欢迎查阅文档或联系开发团队。

---

**最后更新**: 2026-03-21
