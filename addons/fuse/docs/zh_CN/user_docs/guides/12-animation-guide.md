# 动画系统用户指南

Fuse 提供了一套完整的动画控制组件，包含 4 个指令和 6 个事件，覆盖 AnimationPlayer 播放控制和 AnimationTree 混合控制两大场景。

**分类:** Animation
**适用 Godot 节点:** AnimationPlayer, AnimationTree

---

## 指令 (Instructions)

### PlayAnimation -- 播放动画

在 AnimationPlayer 上播放指定动画。

**文件:** [play_animation.gd](../../../instructions/animation/play_animation.gd)
**图标:** AnimationPlayer

#### 属性

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| target_player | NodePath | "" | 目标 AnimationPlayer 节点路径 |
| animation_name | String | "" | 要播放的动画名称 |
| speed | float | 1.0 | 播放速度 (范围: 0.01 - 10.0+) |
| from_end | bool | false | 是否从结尾反向播放 |
| autoplay_only | bool | false | 是否仅自动播放 |

#### 基本用法

1. 将 PlayAnimation 指令添加到 ActionRunner 的指令列表中
2. 在 `target_player` 中指定 AnimationPlayer 的节点路径 (如 `%CharacterBody2D/AnimationPlayer`)
3. 在 `animation_name` 中填写要播放的动画名称 (如 "run"、"jump"、"attack")
4. 根据需要调整 `speed` 控制播放速度

#### 使用场景

**正向播放:**
```
target_player: %Player/AnimationPlayer
animation_name: "run"
speed: 1.0
from_end: false
```

**反向播放 (如倒放动画):**
```
target_player: %Player/AnimationPlayer
animation_name: "idle"
speed: 1.0
from_end: true
```

**慢动作播放:**
```
speed: 0.5    -- 半速播放
```

**快速播放:**
```
speed: 2.0    -- 双倍速播放
```

#### 验证规则

- target_player 不能为空
- animation_name 不能为空
- speed 必须 > 0
- 目标节点必须是 AnimationPlayer 类型
- 动画名称必须存在于 AnimationPlayer 的动画库中

---

### StopAnimation -- 停止动画

停止 AnimationPlayer 的动画播放。

**文件:** [stop_animation.gd](../../../instructions/animation/stop_animation.gd)
**图标:** Stop

#### 属性

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| target_node | NodePath | "" | 目标 AnimationPlayer 节点路径 |
| keep_position | bool | true | 是否保持当前动画位置 |

#### 行为说明

- `keep_position = true` (默认): 调用 `AnimationPlayer.pause()`，暂停但保持当前帧位置
- `keep_position = false`: 调用 `AnimationPlayer.stop()`，停止并重置到起始位置

#### 使用场景

**暂停动画 (保持姿势):**
```
target_node: %Player/AnimationPlayer
keep_position: true
```

**完全停止 (重置位置):**
```
target_node: %Player/AnimationPlayer
keep_position: false
```

#### 验证规则

- target_node 不能为空
- 目标节点必须是 AnimationPlayer 类型

---

### BlendAnimation -- 混合动画

设置 AnimationTree 混合轨道的值，支持直接值或变量驱动。

**文件:** [blend_animation.gd](../../../instructions/animation/blend_animation.gd)
**图标:** Blend

#### 属性

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| target_tree | NodePath | "" | 目标 AnimationTree 节点路径 |
| blend_path | String | "" | 混合路径 (如 "parameters/blend_position") |
| use_variable | bool | false | 是否使用变量控制混合量 |
| blend_amount | float | 0.5 | 直接混合量 (0.0 - 1.0) |
| blend_variable | String | "" | 混合量变量名 |
| blend_scope | enum | Local | 变量作用域 (Local/Scope/Global) |

#### 两种模式

**直接值模式 (use_variable = false):**

直接设置一个 0.0 到 1.0 之间的数值:
```
target_tree: %Player/AnimationTree
blend_path: "parameters/BlendSpace1D/blend_position"
blend_amount: 0.7
```

**变量驱动模式 (use_variable = true):**

通过变量动态控制混合量:
```
target_tree: %Player/AnimationTree
blend_path: "parameters/BlendSpace1D/blend_position"
use_variable: true
blend_variable: "move_speed"
blend_scope: Local
```

当使用 Scope 作用域时，还可以指定作用域来源:
- **Nearest** -- 最近的作用域容器 (默认)
- **Custom ID** -- 指定 custom_scope_id 对应的容器
- **Trigger Scope** -- Trigger 节点上的作用域
- **Target Node** -- 目标节点上的作用域

#### 验证规则

- target_tree 不能为空
- blend_path 不能为空
- 使用变量时 blend_variable 不能为空
- 变量值必须可转换为 float 类型
- 最终混合量会被 clamp 到 [0.0, 1.0]

---

### SetAnimationSpeed -- 设置播放速度

设置 AnimationPlayer 的全局播放速度缩放。

**文件:** [set_animation_speed.gd](../../../instructions/animation/set_animation_speed.gd)
**图标:** ViewportSpeed

#### 属性

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| target_node | NodePath | "" | 目标 AnimationPlayer 节点路径 |
| speed_scale | float | 1.0 | 播放速度缩放 (范围: 0.01 - 10.0+) |

#### 速度值参考

| speed_scale | 效果 |
|-------------|------|
| 0.25 | 四分之一速 (超慢动作) |
| 0.5 | 半速 (慢动作) |
| 1.0 | 正常速度 |
| 2.0 | 双倍速 |
| 3.0 | 三倍速 (快速回放) |

#### 使用场景

**全局慢动作效果:**
```
target_node: %Player/AnimationPlayer
speed_scale: 0.3
```

**快速回放动画:**
```
target_node: %Cutscene/AnimationPlayer
speed_scale: 3.0
```

#### 与 PlayAnimation 的区别

- `PlayAnimation.speed`: 仅影响当前这次播放调用，且仅在 execute 时设置
- `SetAnimationSpeed.speed_scale`: 直接修改 AnimationPlayer.speed_scale 属性，影响后续所有动画播放

#### 验证规则

- target_node 不能为空
- speed_scale 必须 > 0
- 目标节点必须是 AnimationPlayer 类型

---

## 事件 (Events)

### OnAnimationStarted -- 动画开始事件

当 AnimationPlayer 开始播放动画时触发。

**文件:** [on_animation_started.gd](../../../events/animation/on_animation_started.gd)
**图标:** Animation

#### 属性

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| target_node_path | NodePath | "" | 目标 AnimationPlayer 节点路径 |
| animation_name | String | "" | 动画名称 (空 = 任意动画) |
| trigger_once_per_animation | bool | false | 每个动画只触发一次 |
| emit_animation_name | bool | true | 是否传递动画名称 |
| emit_animation_length | bool | true | 是否传递动画长度 |
| emit_loop_mode | bool | false | 是否传递循环模式 |

#### 传递的上下文参数

| Meta 键 | 类型 | 说明 |
|---------|------|------|
| animation_name | StringName | 动画名称 |
| animation_length | float | 动画时长 (秒) |
| loop_mode | int | 循环模式 |
| animation_player | AnimationPlayer | AnimationPlayer 引用 |

#### 检测机制

Godot 4.7+ 优先使用 `animation_started` 信号。如果信号不存在，则通过轮询方式检测 (检查播放位置 < 0.1 秒来判断是否刚开始)。

---

### OnAnimationFinished -- 动画完成事件

当 AnimationPlayer 播放完成指定动画时触发。

**文件:** [on_animation_finished.gd](../../../events/animation/on_animation_finished.gd)
**图标:** Animation

#### 属性

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| animation_player | NodePath | "" | 目标 AnimationPlayer 节点路径 |
| animation_name | String | "" | 动画名称 (空 = 任意动画) |
| emit_animation_name | bool | true | 是否传递动画名称 |

#### 传递的上下文参数

| Meta 键 | 类型 | 说明 |
|---------|------|------|
| animation_name | String | 完成的动画名称 |
| animation_player | AnimationPlayer | AnimationPlayer 引用 |

#### 常见用法

监听攻击动画结束后恢复到空闲状态:
```
animation_player: %Player/AnimationPlayer
animation_name: "attack"
```

---

### OnAnimationLoop -- 动画循环事件

当动画循环播放时触发 (播放到末尾重新开始)。

**文件:** [on_animation_loop.gd](../../../events/animation/on_animation_loop.gd)
**图标:** Animation

#### 属性

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| target_node_path | NodePath | "" | 目标 AnimationPlayer 节点路径 |
| animation_name | String | "" | 动画名称 (空 = 任意动画) |
| trigger_mode | enum | ON_EVERY_LOOP | 触发模式 |
| loop_count_threshold | int | 0 | 循环次数阈值 (0 = 不限制) |
| emit_animation_name | bool | true | 是否传递动画名称 |
| emit_current_loop | bool | true | 是否传递当前循环次数 |
| emit_total_loops | bool | false | 是否传递总循环次数 |
| emit_animation_progress | bool | true | 是否传递动画进度 |

#### 触发模式

| 模式 | 说明 |
|------|------|
| ON_EVERY_LOOP | 每次循环都触发 |
| ON_THRESHOLD_REACHED | 仅在达到 loop_count_threshold 时触发 |

#### 使用场景

**统计循环次数:**
```
animation_name: "run"
trigger_mode: ON_EVERY_LOOP
emit_current_loop: true
```

**在第 3 次循环后触发特殊事件:**
```
animation_name: "idle"
trigger_mode: ON_THRESHOLD_REACHED
loop_count_threshold: 3
```

#### 传递的上下文参数

| Meta 键 | 类型 | 说明 |
|---------|------|------|
| animation_name | String | 动画名称 |
| current_loop | int | 当前循环次数 |
| total_loops | int | 总循环次数 |
| animation_progress | float | 动画进度 (0.0 - 1.0) |
| animation_player | AnimationPlayer | AnimationPlayer 引用 |

---

### OnAnimationFrameReached -- 动画帧到达事件

当动画播放到达指定帧时触发。

**文件:** [on_animation_frame_reached.gd](../../../events/animation/on_animation_frame_reached.gd)
**图标:** AnimationPlayer

#### 属性

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| animation_player_path | NodePath | "" | 目标 AnimationPlayer 节点路径 |
| target_frame | int | 0 | 目标帧索引 (0 - 10000) |
| animation_name | String | "" | 动画名称 (空 = 当前动画) |
| emit_animation_name | bool | true | 是否传递动画名称 |
| emit_current_frame | bool | true | 是否传递当前帧 |
| emit_position | bool | true | 是否传递播放位置 (秒) |

#### 行为说明

- 使用 60 FPS 定时器 (~16ms) 检测当前帧是否达到 target_frame
- 默认只触发一次 (has_triggered 状态)，调用 reset() 可重置
- 帧索引根据动画的 frame_rate 计算: `current_frame = position * fps`

#### 传递的上下文参数

| Meta 键 | 类型 | 说明 |
|---------|------|------|
| animation_name | String | 动画名称 |
| current_frame | int | 当前帧索引 |
| position | float | 播放位置 (秒) |
| target_frame | int | 目标帧 |
| animation_player | AnimationPlayer | AnimationPlayer 引用 |

---

### OnAnimationMarker -- 动画标记事件

当动画播放经过指定标记点时触发。

**文件:** [on_animation_marker.gd](../../../events/animation/on_animation_marker.gd)
**图标:** Animation

#### 属性

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| target_node_path | NodePath | "" | 目标 AnimationPlayer 节点路径 |
| marker_name | String | "" | 标记名称 (空 = 任意标记) |
| animation_name | String | "" | 动画名称 (空 = 任意动画) |
| trigger_once_per_play | bool | false | 每次播放只触发一次 |
| emit_animation_name | bool | true | 是否传递动画名称 |
| emit_marker_name | bool | true | 是否传递标记名称 |
| emit_marker_position | bool | true | 是否传递标记位置 |
| emit_current_position | bool | true | 是否传递当前播放位置 |

#### 标记检测机制

遍历动画轨道中所有关键帧，查找字符串值或带有 "marker" 键的字典作为标记。通过比较上次播放位置和当前播放位置来判断是否经过标记点 (容差 0.02 秒)。

动画循环时，如果 trigger_once_per_play 开启，会自动重置标记触发状态。

#### 传递的上下文参数

| Meta 键 | 类型 | 说明 |
|---------|------|------|
| animation_name | String | 动画名称 |
| marker_name | String | 标记名称 |
| marker_position | float | 标记位置 (秒) |
| current_position | float | 当前播放位置 (秒) |
| animation_player | AnimationPlayer | AnimationPlayer 引用 |

---

### OnAnimationBlend -- 动画混合权重变化事件

当 AnimationTree 的混合节点权重达到指定阈值时触发。

**文件:** [on_animation_blend.gd](../../../events/animation/on_animation_blend.gd)
**图标:** AnimationTree

#### 属性

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| animation_tree_path | NodePath | "" | 目标 AnimationTree 节点路径 |
| blend_path | NodePath | "" | 混合路径 |
| threshold | float | 0.5 | 权重阈值 (0.0 - 1.0) |
| comparison | enum | GREATER_OR_EQUAL | 比较方式 |

#### 比较方式

| 比较方式 | 说明 |
|---------|------|
| GREATER_OR_EQUAL | 权重 >= 阈值时触发 (从低于变为高于) |
| LESS_OR_EQUAL | 权重 <= 阈值时触发 (从高于变为低于) |
| EQUAL | 权重接近阈值时触发 (容差 0.01) |

#### 行为说明

- 使用 100ms 定时器检测混合权重变化
- 仅在权重从一侧穿越到另一侧时触发一次，不会持续触发
- 例如 GREATER_OR_EQUAL 模式: 仅当权重从 < threshold 变为 >= threshold 时触发

#### 使用场景

**检测混合空间切换完成:**
```
animation_tree_path: %Player/AnimationTree
blend_path: "parameters/BlendSpace1D/blend_position"
threshold: 0.8
comparison: GREATER_OR_EQUAL
```

**检测动画过渡到特定状态:**
```
animation_tree_path: %Player/AnimationTree
blend_path: "parameters/StateMachine/conditions/is_running"
threshold: 0.5
comparison: GREATER_OR_EQUAL
```

#### 传递的上下文参数

| Meta 键 | 类型 | 说明 |
|---------|------|------|
| blend_path | String | 混合路径 |
| weight | float | 当前权重值 |
| threshold | float | 阈值 |
| comparison | int | 比较方式枚举值 |
| animation_tree | AnimationTree | AnimationTree 引用 |

---

## 常见工作流

### 场景 1: 角色动画状态机

使用事件监听驱动动画状态切换:

```
OnAnimationFinished("attack")  -->  PlayAnimation("idle")
OnAnimationStarted("run")      -->  SetAnimationSpeed(1.0)
```

### 场景 2: 过场动画序列

使用帧到达和标记事件编排过场:

```
OnAnimationFrameReached(frame=120)  -->  PlayAnimation("scene2")
OnAnimationMarker("show_dialog")    -->  ShowDialog(...)
```

### 场景 3: 动画混合控制

使用 BlendAnimation 配合变量驱动混合:

```
# 移动时设置混合
SetVariable("move_direction", 0.8)
BlendAnimation(use_variable=true, blend_variable="move_direction")

# 监听混合完成
OnAnimationBlend(threshold=0.9)  -->  EnableMovement()
```

### 场景 4: 慢动作效果

游戏暂停或受击时的慢动作:

```
# 受击时
SetAnimationSpeed(0.2)

# 恢复时
SetAnimationSpeed(1.0)
```

---

## 所有动画事件共享的上下文参数传递模式

动画事件通过创建临时 Node 作为上下文，使用 `set_meta()` 传递参数。下游指令可以通过 `context.get_meta("key")` 获取这些参数。

临时 Node 在事件处理完成后会自动清理 (通过 `queue_free()`)。

---

**文档维护**: Fuse 开发团队
**最后更新**: 2026-03-19
**版本**: 1.0.0
