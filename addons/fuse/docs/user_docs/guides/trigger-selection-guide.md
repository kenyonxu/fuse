# 触发器选型指南：Runner、Trigger 与 MultiEventTrigger

Fuse 提供了三种组件来响应事件并执行指令序列（ActionRunner）。它们各自擅长不同的场景，本指南帮助你在具体需求下做出选择。

## 快速选型

**选你需要的：**

- 快速监听一个信号、或从代码调用 → **Runner**
- 需要事件参数过滤、触发控制（trigger_once / 冷却） → **Trigger**
- 同一节点上有多个事件-动作绑定 → **MultiEventTrigger**

---

## 三者总览

| 特性 | Runner | Trigger | MultiEventTrigger |
|------|--------|---------|-------------------|
| 触发方式 | 信号绑定 / 代码调用 | Event 资源（可视化配置） | 多个 Event 资源 |
| await 支持 | `wait_completed()` | 不支持 | 不支持 |
| 触发控制 | 无 | trigger_once、冷却 | 每绑定独立控制 |
| 条件检查 | 无 | 无 | 每绑定可配条件 |
| 事件参数 | 不传递到上下文 | 传递到 ExecutionContext | 传递到 ExecutionContext |
| 节点数量 | 每动作一个节点 | 每事件一个节点 | 多事件共用一个节点 |
| 适合用户 | 程序员、快速原型 | 可视化编辑用户 | 有经验的编辑用户 |

---

## Runner：轻量信号绑定与代码调用

Runner 是 ActionRunner 的节点封装。它不做事件处理——只是"当一个信号触发时，跑一段指令"，或者"从代码里直接调用"。

### 适用场景

- **UI 交互**：按钮点击后执行指令
- **Timer 回调**：计时器结束后执行指令
- **代码编排**：在脚本中 `await runner.wait_completed()` 等待异步执行完成
- **组件间解耦**：监听自定义信号（如 `died`、`level_completed`）触发后续逻辑
- **快速原型**：不需要 Event 资源配置，直接选节点 + 选信号即可

### 不适用场景

- 需要信号参数过滤（如"仅当碰撞体在 Player 组时才触发"）
- 需要 trigger_once 或冷却机制
- 需要输入事件（键盘、鼠标、手柄）或物理碰撞事件
- 需要条件检查

### 示例

```
场景结构：
  Player
    Sprite2D
    Runner (OnDeath)
      target_node: ..
      signal_name: "died"
      action_runner: death_actions  ← 死亡处理指令序列
```

```gdscript
# 代码调用 + await
@onready var runner: Runner = $Runner

runner.run()
await runner.wait_completed()
print("死亡动画播放完毕，可以清理场景了")
```

> [!NOTE]
> Runner 的 `target_node` 和 `signal_name` 会自动列出目标节点的所有可用信号，编辑器中直接从下拉菜单选择即可。

---

## Trigger：带事件系统的单触发器

Trigger 是 Fuse 事件系统的标准单元。它通过 Event 资源定义触发条件，支持触发控制和事件参数传递。

### 适用场景

- **物理碰撞**：进入/离开 Area 时触发（支持按组过滤、按碰撞体去重）
- **输入事件**：键盘按键、鼠标点击、手柄输入
- **生命周期**：场景就绪、节点进入/退出树
- **动画事件**：动画完成、到达特定帧/标记点
- **需要触发控制**：trigger_once（只触发一次）、冷却时间
- **需要事件参数**：碰撞体引用、动画名称、输入向量等传入 ExecutionContext

### 不适用场景

- 只需要监听一个简单信号且不需要额外控制（Runner 更轻量）
- 同一节点上有多个独立的事件-动作绑定（MultiEventTrigger 更紧凑）
- 需要 await 等待执行完成（Runner 支持）

### 示例

```
场景结构：
  Player
    CollisionShape2D
    Trigger (OnHit)
      event_definition: OnBodyEntered
        target_group: "Enemy"       ← 仅敌人碰撞时触发
      action_runner: hurt_actions
      trigger_once: false
      cooldown_mode: GLOBAL_COOLDOWN
      cooldown_time: 0.5            ← 受伤 0.5 秒内不重复触发
```

> [!NOTE]
> Trigger 中的事件参数（如碰撞体、输入向量）会自动同步到 ExecutionContext，后续指令可以直接通过变量访问。

---

## MultiEventTrigger：多事件合并触发器

MultiEventTrigger 将多个事件-动作绑定合并到一个节点中，减少场景树节点数量，每个绑定拥有独立的控制。

### 适用场景

- **同一逻辑实体的多个事件**：一个敌人同时监听"被击中"、"死亡"、"AI 状态切换"
- **减少节点数量**：多个相关触发事件合并为一个节点，保持场景树整洁
- **每绑定独立条件**：每个 EventBinding 可以配置不同的条件检查
- **动态启用/禁用**：运行时单独开关某个绑定

### 不适用场景

- 只有一个事件（直接用 Trigger 更直观）
- 需要 await 等待执行完成（Runner 支持）
- 不需要事件系统的额外控制（Runner 更轻量）

### 示例

```
场景结构：
  Player
    MultiEventTrigger (PlayerEvents)
      EventBinding[0]:              # 场景就绪
        event: OnSceneReady
        action_runner: init_actions
        trigger_once: true
      EventBinding[1]:              # 受伤
        event: OnBodyEntered
        action_runner: hurt_actions
        cooldown_mode: GLOBAL_COOLDOWN
        cooldown_time: 1.0
      EventBinding[2]:              # 死亡
        event: OnHealthZero
        action_runner: death_actions
        trigger_once: true
```

> [!NOTE]
> MultiEventTrigger 支持从多个现有 Trigger 节点合并而来（场景树中右键 → 合并为 MultiEventTrigger），也支持拆分回独立 Trigger 节点。

---

## 决策流程

```
需要响应事件并执行指令？
│
├─ 需要输入事件（键盘/鼠标/手柄）或物理事件？
│  └─ 是 → Trigger 或 MultiEventTrigger
│
├─ 需要 trigger_once 或冷却控制？
│  └─ 是 → Trigger 或 MultiEventTrigger
│
├─ 需要事件参数（碰撞体、动画名等）？
│  └─ 是 → Trigger 或 MultiEventTrigger
│
├─ 需要 await 等待执行完成？
│  └─ 是 → Runner
│
├─ 从代码调用而非事件驱动？
│  └─ 是 → Runner
│
├─ 只需监听一个简单信号？
│  └─ 是 → Runner
│
├─ 同一节点有多个事件-动作绑定？
│  └─ 是 → MultiEventTrigger
│
└─ 其他 → Trigger
```

---

## 常见场景对照

| 场景 | 推荐组件 | 原因 |
|------|---------|------|
| 按钮点击打开设置面板 | Runner | 简单信号绑定，无需额外控制 |
| Timer 计时结束生成敌人 | Runner | 纯信号转发 |
| 自定义信号 `died` 触发死亡 | Runner | 信号驱动，足够简单 |
| 代码中 await 执行完成 | Runner | 唯一支持 await 的组件 |
| 按空格键跳跃 | Trigger | 输入事件 + 需要条件（如：是否在地面） |
| 碰到敌人受伤（带冷却） | Trigger | 物理事件 + group 过滤 + 冷却 |
| 动画播放到某帧触发特效 | Trigger | 动画帧事件 + 参数传递 |
| 场景就绪时初始化 | Trigger (trigger_once) | 一次性初始化 |
| 一个 NPC 的多个行为 | MultiEventTrigger | 多事件合并，减少节点 |
| 需要运行时动态启用/禁用 | MultiEventTrigger | 每绑定独立控制 |
| 监听一组中所有节点的信号 | Trigger (OnSignalFromGroup) | 组信号监听 |

---

## 功能矩阵

| 功能 | Runner | Trigger | MultiEventTrigger |
|------|--------|---------|-------------------|
| 信号绑定 | target_node + signal_name | 通过 Event 资源 | 通过 Event 资源 |
| 代码调用 `run()` | 支持 | `trigger_manually()` | `trigger_binding(index)` |
| await 等待完成 | `wait_completed()` | - | - |
| trigger_once | - | 支持 | 每绑定支持 |
| 冷却时间 | - | 支持 | 每绑定独立 |
| 条件检查 | - | - | 每绑定支持 |
| 事件参数传递 | - | 支持 | 支持 |
| 动态启用/禁用 | - | - | `set_binding_enabled()` |
| 场景树右键合并 | - | → MultiEventTrigger | → 多个 Trigger |
| UndoRedo 支持 | - | - | 合并/拆分支持 |
