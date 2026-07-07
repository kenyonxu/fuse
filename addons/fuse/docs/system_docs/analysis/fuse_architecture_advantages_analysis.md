# Fuse 架构优势分析

## 核心设计理念

Fuse 采用 **Resource-based 可组合架构**，与其他可视化编程系统有本质区别。

### 三种架构模式对比

| 系统 | 架构模式 | 核心抽象 | 设计意图 |
|------|---------|---------|---------|
| **Fuse** | 事件触发器 + 指令序列 | ActionRunner (Resource) | 可组合的执行单元 |
| **Orchestrator** | 节点图系统 | OScriptGraph (GDExtension) | 替代 GDScript 的脚本系统 |
| **FlowKit** | 事件表系统 | EventSheet (Resource) | 类 Construct 的自动事件表 |

## 独特优势

### 1. 节点+检视器模式的原生集成

Fuse 利用 Godot 原生工作流，无需学习新界面。

```gdscript
# 场景树结构
Player (CharacterBody2D)
├── Sprite2D
├── CollisionShape2D
└── Trigger (Node)  # Fuse 事件触发器
    ├── event_definition: OnKeyEvent
    └── action_runner: AttackSequence
        └── instructions: [PlayAnim, DealDamage, PlayEffect]
```

**为什么这很重要：**

- 零学习成本：你已经知道如何添加节点、使用 Inspector
- 逻辑与场景紧密绑定：Trigger 在场景树中的位置就是逻辑的附着点
- 支持 Godot 原生特性：继承、实例化、可编辑子场景

**对比：**

Orchestrator 需要打开专门的编辑器窗口，逻辑与场景树分离。FlowKit 虽然也是基于场景，但事件表是自动执行的，不提供手动控制。

---

### 2. Resource-based 架构的可组合性

这是 Fuse 最核心的优势：**ActionRunner 是可序列化的可执行资源**。

```gdscript
class_name ActionRunner extends Resource

@export var instructions: Array[BaseInstruction] = []
@export var execution_mode: ExecutionMode = ExecutionMode.SEQUENTIAL

# 简单的执行接口
func run(context: ExecutionContext):
    # 执行指令序列
    await _run_sequential(context)
```

**这意味着什么？**

```gdscript
# 1. 可以被任何系统持有
class MyAISystem extends Node:
    @export var attack_actions: ActionRunner
    @export var defend_actions: ActionRunner

    func execute_attack():
        attack_actions.run(_create_context())

# 2. 可以在 Inspector 中配置
# 拖拽 .tres 资源到 @export 字段

# 3. 可以动态加载
var actions = load("res://actions/combat.tres")
actions.run(context)

# 4. 可以在多处重用
# 同一个 ActionRunner 可以被多个 Trigger 引用
```

**Orchestrator 对比：**

```gdscript
# Orchestrator 的 OScriptGraph 不是设计用来被调用的
# 它是一个完整的脚本系统，期望自己控制执行流

# 你不能这样做：
@export var logic_graph: OScriptGraph  # ❌ 不是为此设计
logic_graph.run()  # ❌ 没有这样的接口
```

---

### 3. 与复杂系统的集成能力

Fuse 的 ActionRunner 可以轻松嵌入其他系统。

#### 与 LimboAI 集成（行为树）

```gdscript
# res://ai/tasks/fuse_action.gd
@tool
extends BTAction

@export var action_runner: ActionRunner
@export var wait_for_completion: bool = true

var _execution_context: ExecutionContext = null
var _is_running: bool = false

func _enter() -> void:
    if not action_runner:
        return

    # 创建执行上下文
    _execution_context = ExecutionContext.new()
    _execution_context.set_agent(agent)
    _execution_context.set_scene_root(scene_root)

    # 连接信号
    if wait_for_completion:
        action_runner.execution_completed.connect(_on_completed)

    # 执行 Fuse 指令序列
    _is_running = true
    action_runner.run(_execution_context)

func _tick(delta: float) -> Status:
    if not wait_for_completion:
        return SUCCESS
    return RUNNING if _is_running else SUCCESS

func _exit() -> void:
    if wait_for_completion and action_runner:
        action_runner.execution_completed.disconnect(_on_completed)
    _is_running = false

func _on_completed():
    _is_running = false
```

**使用示例：**

```
LimboAI 行为树
├─ Sequence (巡逻逻辑)
│  ├─ SelectPatrolPoint
│  ├─ MoveToTarget
│  └─ FuseAction  # ← 执行 Fuse 指令序列
│     └─ action_runner: PlayJuicyEffect + UpdateAnimation
│
└─ Selector (战斗逻辑)
   ├─ CheckPlayerVisible
   ├─ FuseAction  # ← 攻击序列
   │  └─ action_runner: AttackEffect + DealDamage + UpdateUI
   └─ FuseAction  # ← 防御序列
      └─ action_runner: ShieldEffect + PlayDefendAnim
```

#### 与状态机集成

```gdscript
# res://ai/states/fuse_state.gd
extends LimboState

@export var on_enter_actions: ActionRunner
@export var on_update_actions: ActionRunner
@export var on_exit_actions: ActionRunner

func _enter() -> void:
    if on_enter_actions:
        on_enter_actions.run(_create_context())

func _update(delta: float) -> void:
    if on_update_actions and not on_update_actions.is_running:
        on_update_actions.run(_create_context())

func _exit() -> void:
    if on_exit_actions:
        on_exit_actions.run(_create_context())

func _create_context() -> ExecutionContext:
    var context = ExecutionContext.new()
    context.set_agent(agent)
    context.set_scene_root(scene_root)
    return context
```

**为什么这很重要？**

- **职责分离**：LimboAI 处理高层决策，Fuse 处理具体动作
- **渐进式复杂度**：简单逻辑用 Trigger，复杂逻辑用行为树 + Fuse
- **可重用性**：同一个 ActionRunner 可以在行为树和状态机中共享

**Orchestrator 对比：**

Orchestrator 的 OScriptGraph 是一个完整的脚本系统，试图自己解决所有问题。与 LimboAI 集成会导致职责重叠：你什么时候用行为树决策？什么时候用节点图决策？

---

### 4. 与 JuicyMixer 的深度集成

Fuse 从设计之初就考虑了与 JuicyMixer 的集成。

```gdscript
# 播放 Juicy 效果指令
class_name PlayJuicyEffectTask extends BaseInstruction

@export var feedback_resource: JuicyFeedback
@export var target_mode: TargetMode = TargetMode.AGENT

enum TargetMode {
    AGENT,
    CUSTOM_NODE
}

@export var custom_target: NodePath

func execute(context: ExecutionContext):
    var target: Node = null

    match target_mode:
        TargetMode.AGENT:
            target = context.get_agent()
        TargetMode.CUSTOM_NODE:
            target = context.get_scene_root().get_node(custom_target)

    if target and feedback_resource:
        JuicyMixer.play(feedback_resource, target)

    finished.emit()
```

**使用示例：**

```gdscript
# attack_sequence.tres
[extends Resource]
script = ActionRunner

instructions = [
    PlayJuicyEffectTask,  # 攻击特效（震动 + 屏幕冲击）
    PlayAnimationTask,    # 攻击动画
    WaitTask,             # 等待 0.5 秒
    DealDamageTask,       # 造成伤害
    PlayJuicyEffectTask,  # 命中特效（粒子 + 音效）
]
```

**为什么这很重要？**

- 统一的资源管理：ActionRunner 和 JuicyFeedback 都是 Resource
- 时间线同步：JuicyMixer 的 Timeline 可以与指令序列精确配合
- 参数映射：JuicyMixer 的参数可以与 Fuse 变量系统联动

**其他系统对比：**

Orchestrator 和 FlowKit 都没有内置的特效系统集成，需要手动桥接。

---

### 5. 内存优化设计

Fuse 使用 RuntimeEventInstance 避免不必要的资源复制。

```gdscript
# trigger.gd
class_name Trigger extends Node

var _runtime_event_instance: RuntimeEventInstance = null

func _ready() -> void:
    # 使用轻量级运行时实例，避免复制整个 Event 资源
    _runtime_event_instance = RuntimeEventInstance.new(event_definition, self)
    event_definition.initialize_with_runtime_instance(self, _runtime_event_instance)

    event_definition.triggered.connect(_on_event_fired)
```

**优势：**

- 大型 Event 资源不会每帧复制
- 运行时状态与资源定义分离
- 支持对象池复用

---

## 固有劣势

### 1. 可视化程度较低

Fuse 主要依赖 Inspector 面板配置，逻辑流向不够直观。

```gdscript
# Inspector 面板视图
▼ ActionRunner
  ▼ instructions: Array[BaseInstruction] x
    [0] PlayJuicyEffectTask
    [1] MoveNodeInstruction
    [2] ChangeVariableInstruction
    [3] CheckConditionInstruction
```

**问题：**

- 无法直观看到分支和循环结构
- 难以快速理解指令之间的依赖关系
- 条件判断的逻辑不够清晰

**对比：**

Orchestrator 的节点图可以一目了然地看到整个逻辑流程：

```
[OnBodyEntered] → [CheckTag: "Player"] → [PlayEffect]
                                      ↓
                                  [DealDamage]
```

**缓解方案：**

- 对于简单逻辑（< 10 个指令），Inspector 足够清晰
- 对于复杂逻辑，考虑使用 LimboAI + FuseAction 组合
- 未来可以添加可选的可视化编辑器（作为 Inspector 的补充视图）

---

### 2. 调试支持较弱

Fuse 缺少可视化的断点和执行跟踪。

```gdscript
# 当前调试方式
@export var log_level: FuseLogger.LogLevel = FuseLogger.LogLevel.DEBUG

# 在指令中打印日志
func execute(context: ExecutionContext):
    context.print_message("执行指令，当前生命值: %s" % current_hp)
    # ...
```

**对比：**

Orchestrator 提供完整的可视化调试器：
- 高亮正在执行的节点
- 显示数据流
- 断点和单步执行

**缓解方案：**

- 使用 execution_completed 信号追踪执行
- 在关键指令添加日志输出
- 使用 ActionRunner 的 get_execution_status() 查询进度
- 未来可以添加执行历史查看器

---

### 3. 参数配置繁琐

Inspector 配置需要多次点击展开，缺少智能提示。

```gdscript
# 配置一个指令需要：
# 1. 点击 instructions 数组
# 2. 点击添加元素
# 3. 在下拉菜单中选择指令类型
# 4. 展开指令属性
# 5. 逐个配置参数
```

**对比：**

Orchestrator 的节点搜索和连线更快捷：
- 右键菜单搜索节点
- 拖拽建立连接
- 智能类型推断

**缓解方案：**

- 使用资源模板：预定义常用的指令序列
- 使用 @export @onready 参数提供默认值
- 未来可以添加指令快速选择器（类似 Orchestrator 的节点搜索）

---

### 4. 复杂控制流支持有限

ActionRunner 只支持 SEQUENTIAL 和 PARALLEL 两种模式。

```gdscript
enum ExecutionMode {
    SEQUENTIAL,  # 顺序执行
    PARALLEL     # 并行执行
}
```

**无法直接表达：**

- 条件分支（if-else）
- 循环（for, while）
- 复杂的异步流程

**变通方案：**

```gdscript
# 使用条件指令模拟分支
instructions = [
    CheckVariableInstruction,  # 检查变量
    # 如果条件成立，跳过接下来 2 个指令
    SkipInstructionsInstruction.new({ count = 2 }),
    # else 分支
    ElseBranchInstructions,
    # if 分支
    IfBranchInstructions,
]
```

**更好的方案：**

对于复杂控制流，使用 LimboAI + FuseAction：

```
BTSelector
├─ BTCondition: 检查玩家可见
│  ├─ FuseAction: 攻击序列
│  └─ FuseAction: 巡逻序列
└─ BTCondition: 检查生命值
   └─ FuseAction: 逃跑序列
```

---

## 适用场景

### Fuse 最适合的场景

1. **简单到中等复杂度的游戏逻辑**
   - 交互事件（开门、拾取物品）
   - 简单的状态机（闲置、巡逻、攻击）
   - UI 交互逻辑

2. **与 JuicyMixer 的特效集成**
   - 攻击/命中/死亡特效序列
   - 技能释放流程
   - 环境交互反馈

3. **作为其他 AI 系统的动作执行器**
   - LimboAI 行为树的叶子节点
   - 状态机状态的 enter/exit 动作
   - 对话系统的回调动作

4. **快速原型开发**
   - 无需编写代码即可实现常见逻辑
   - 利用 Inspector 快速配置
   - 支持热重载

### Fuse 不太适合的场景

1. **复杂的算法逻辑**
   - 寻路算法（使用专门的寻路系统）
   - 复杂的数学计算（使用 GDScript）
   - 大规模数据结构操作

2. **高度可视化的逻辑**
   - 需要频繁展示给设计师的逻辑（考虑 Orchestrator）
   - 需要可视化的数据流（考虑节点图系统）

3. **极致性能要求的热路径**
   - 每帧执行数千次的逻辑（使用 GDScript/C++）
   - 紧密的循环（考虑直接编写代码）

---

## 设计权衡总结

| 设计选择 | 优势 | 劣势 |
|---------|------|------|
| **节点+检视器模式** | 零学习成本，原生集成 | 可视化程度低 |
| **Resource-based 架构** | 可组合，可序列化，易于集成 | 需要理解 Resource 系统 |
| **事件触发器设计** | 逻辑与场景紧密绑定 | 配置分散在多个节点 |
| **指令序列执行器** | 简单，可预测 | 控制流支持有限 |
| **与 JuicyMixer 集成** | 统一资源管理，深度集成 | 耦合度较高 |

**核心理念：**

Fuse 不是试图成为"完整的脚本系统"（像 Orchestrator），而是设计为**可组合的逻辑构建块**。它承认自己不会解决所有问题，而是专注于：
- 与 Godot 原生工作流集成
- 与其他系统协作
- 提供可重用的执行单元

这种"知道自己边界"的设计，使得 Fuse 在实际项目中更有价值。

---

## 对比总结表

| 维度 | Fuse | Orchestrator | FlowKit |
|------|--------|-------------|---------|
| **学习曲线** | 低（复用 Godot 知识） | 中高（需学习节点图） | 低（事件表直观） |
| **开发成本** | 低（利用原生 UI） | 高（需开发专用编辑器） | 中（需事件表编辑器） |
| **可视化程度** | 低 | 高 | 中 |
| **调试能力** | 弱 | 强 | 中 |
| **逻辑可视性** | 低 | 高 | 中 |
| **系统集成** | **强**（Resource-based） | **弱**（完整脚本系统） | **中**（自动执行） |
| **与 JuicyMixer 集成** | **深度集成** | 需手动桥接 | 需手动桥接 |
| **与 LimboAI 集成** | **简单**（BTAction 包装） | 困难（职责重叠） | 可能 |
| **可组合性** | **高**（可被调用） | 低（独立系统） | 中 |
| **适用场景** | 中等逻辑 + 系统集成 | 复杂逻辑 + 可视化 | 快速原型 + 事件驱动 |

**选择建议：**

- ✅ 使用 Fuse：需要与其他系统（JuicyMixer、LimboAI）集成，追求与 Godot 原生体验
- ✅ 使用 Orchestrator：需要完整的可视化脚本系统，逻辑复杂需要全局视图
- ✅ 使用 FlowKit：快速原型，简单的交互逻辑，非程序员友好

**最佳实践：**

Fuse 可以与 Orchestrator/FlowKit 互补使用：
- Orchestrator 处理复杂的 AI 决策逻辑
- Fuse 处理具体的动作执行（播放特效、更新 UI、触发音效）
- 两者各司其职，发挥各自优势

---

## 相关文档

- [Fuse 架构分析](./fuse_architecture_analysis.md)
- [ActionRunner 分析](./action_runner_analysis.md)
- [指令系统设计](../architecture/instruction_system_design.md)
- [触发器系统设计](../../archive/archive/trigger_system_design.md)
- [Tween 补间动画使用指南](../../user_docs/guides/tween-animation-guide.md)
