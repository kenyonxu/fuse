> 🌐 中文 | [**English**](../../../en_US/user_docs/guides/43-animation-conditions-guide.md)

# Animation 条件指南

## 概述

Animation 条件用于在流程控制中判断动画播放状态和 AnimationTree 状态。共 **5 个条件**，位于 `conditions/animation/` 目录。

| 分类 | 条件 | class_name | 功能 |
|------|------|-----------|------|
| 播放状态 | CheckIsPlaying | CheckIsPlaying | 当前是否有动画在播放 |
| 播放状态 | CheckIsAnimation | CheckIsAnimation | 当前播放的是否为指定动画 |
| 播放状态 | CheckAnimationFinished | CheckAnimationFinished | 指定动画是否播放完成 |
| AnimationTree | CheckAnimationTreeState | CheckAnimationTreeState | 状态机节点是否在指定状态 |
| AnimationTree | CheckAnimationTreeParameter | CheckAnimationTreeParameter | 状态机参数检查 |

---

## 播放状态判断

### CheckIsPlaying

**文件：** `conditions/animation/check_is_playing.gd`
**class_name：** CheckIsPlaying

检查指定的 AnimationPlayer 当前是否有动画正在播放。

| 参数 | 类型 | 说明 |
|------|------|------|
| `target` | NodePath | AnimationPlayer 节点路径 |
| `expected_state` | bool | 期望的播放状态 |

**示例：** 播放中不中断

```
CheckIsPlaying → target: "Player/AnimationPlayer", expected_state: true
├── true → (动画播放中，不打断)
└── false → (空闲，可以播放新动画)
```

### CheckIsAnimation

**文件：** `conditions/animation/check_is_animation.gd`
**class_name：** CheckIsAnimation

检查当前正在播放的是否为指定的动画名称。

| 参数 | 类型 | 说明 |
|------|------|------|
| `target` | NodePath | AnimationPlayer 节点路径 |
| `animation_name` | String | 动画名称 |

**示例：** 根据动画状态切换技能

```
CheckIsAnimation → target: "Player/AnimationPlayer", animation_name: "attack_slash"
├── true → (正在播放斩击动画，允许连招输入)
└── false → CheckIsAnimation → target: "Player/AnimationPlayer", animation_name: "idle"
    └── true → (空闲状态，允许任何攻击)
```

### CheckAnimationFinished

**文件：** `conditions/animation/check_animation_finished.gd`
**class_name：** CheckAnimationFinished

检查指定的动画是否已播放完成。

| 参数 | 类型 | 说明 |
|------|------|------|
| `target` | NodePath | AnimationPlayer 节点路径 |
| `animation_name` | String | 动画名称 |

**示例：** 攻击后摇结束后才能移动

```
CheckAnimationFinished → target: "Player/AnimationPlayer", animation_name: "attack_heavy"
├── true → (攻击动画完成，恢复移动控制)
└── false → (动画未结束，锁定移动)
```

---

## AnimationTree 集成

### CheckAnimationTreeState

**文件：** `conditions/animation/check_animation_tree_state.gd`
**class_name：** CheckAnimationTreeState

检查 AnimationTree 的 `StateMachine` 节点是否处于指定状态。

| 参数 | 类型 | 说明 |
|------|------|------|
| `animation_tree` | NodePath | AnimationTree 节点路径 |
| `state_machine_path` | String | 状态机节点路径（如 `"parameters/StateMachine"`） |
| `state_name` | String | 期望的状态名称 |

**示例：** AI 行为驱动

```
CheckAnimationTreeState → animation_tree: "Enemy/AnimationTree", state_machine_path: "parameters/StateMachine", state_name: "attack"
├── true → (AI 处于攻击状态，执行攻击行为)
└── false → CheckAnimationTreeState → animation_tree: "Enemy/AnimationTree", state_machine_path: "parameters/StateMachine", state_name: "chase"
    └── true → (追踪状态，向玩家移动)
```

### CheckAnimationTreeParameter

**文件：** `conditions/animation/check_animation_tree_parameter.gd`
**class_name：** CheckAnimationTreeParameter

检查 AnimationTree 的指定参数值是否满足条件。适用于检查 blend position 等参数。

| 参数 | 类型 | 说明 |
|------|------|------|
| `animation_tree` | NodePath | AnimationTree 节点路径 |
| `parameter_path` | String | 参数路径（如 `"parameters/blend_position"`） |
| `operator` | CompareOperator | 比较运算符 |
| `value` | float | 比较值 |

**示例：** 混合方向判断

```
CheckAnimationTreeParameter → animation_tree: "Player/AnimationTree", parameter_path: "parameters/blend_position", operator: GREATER_THAN, value: 0.5
├── true → (混合靠右，触发右侧动画集)
└── false → (混合靠左，触发左侧动画集)
```

---

## 常见用例

### 攻击动画播放完后才能移动

```
OnInputAction → action_name: "move"
├── CheckIsPlaying → target: "Player/AnimationPlayer", expected_state: true
│   └── true → CheckAnimationFinished → target: "Player/AnimationPlayer", animation_name: "attack_heavy"
│       ├── true → (动画完成，处理移动输入)
│       └── false → (动画中，忽略移动输入)
└── false → (没有播放动画，直接移动)
```

### 根据动画状态切换技能

```
OnInputAction → action_name: "skill_1"
├── CheckIsAnimation → target: "Player/AnimationPlayer", animation_name: "idle"
│   └── true → (释放技能 1)
├── CheckIsAnimation → target: "Player/AnimationPlayer", animation_name: "attack_combo_1"
│   └── true → (衔接技能 1 连招)
└── (其他状态不允许释放)
```

### AnimationTree 状态机驱动 AI 行为

```
OnInterval → interval_seconds: 0.5
├── CheckAnimationTreeState → animation_tree: "Boss/AnimationTree", state_machine_path: "parameters/StateMachine", state_name: "idle"
│   └── true → (Boss 空闲，检测玩家位置决定下一步)
├── CheckAnimationTreeState → animation_tree: "Boss/AnimationTree", state_machine_path: "parameters/StateMachine", state_name: "attack"
│   └── true → (Boss 攻击中，检测攻击是否命中)
└── CheckAnimationTreeState → animation_tree: "Boss/AnimationTree", state_machine_path: "parameters/StateMachine", state_name: "stagger"
    └── true → (Boss 硬直中，允许玩家输出)
```

---

## 注意事项

0. **节点路径与变量二选一**：含 NodePath 参数的条件（如 CheckIsPlaying、CheckIsAnimation 等）既支持直接写死节点路径，也支持通过变量动态传入节点引用。
1. **AnimationTree 条件需要 AnimationTree 节点**：`CheckAnimationTreeState` 和 `CheckAnimationTreeParameter` 需要场景中有 `AnimationTree` 节点并配置了状态机。
2. **CheckIsAnimation 需要 AnimationPlayer**：该条件检查的是 `AnimationPlayer.current_animation`，因此目标节点必须是 `AnimationPlayer` 类型。
3. **CheckAnimationFinished 不会重置状态**：动画完成后，该条件返回 `true`，需要手动重置或等待播放新动画后状态更新。
