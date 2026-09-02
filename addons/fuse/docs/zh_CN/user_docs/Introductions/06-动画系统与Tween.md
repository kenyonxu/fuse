> 🌐 中文 | [**English**](../../../en_US/user_docs/Introductions/06-animation-and-tween.md)

# 《从动画播放到弹性补间：Fuse 动画全家桶与手感打磨》

看完这篇，你会把 Fuse 从"逻辑能跑"推进到"画面会动、手感到位"。角色攻击怎么播动画、受击怎么震动闪红、UI 弹窗怎么弹簧弹出、拾取物品怎么放大淡出、慢动作怎么靠改播放速度实现——这些决定一款游戏"手感好不好"的细节，Fuse 用 AnimationPlayer 控制（4 个指令 + 6 个事件）和 Tween 补间（13 个指令）两套体系全部覆盖。这一篇会讲清两套体系各自的定位，以及怎么把它们和前几篇的逻辑、表达式拼成有反馈的交互。

承接上一篇：流程控制和数据结构搭好了逻辑骨架，但骨架还不会动。逻辑说"敌人受击了"，画面却没有任何反应——因为受击反馈是动画和补间的活儿。这篇就是给骨架穿上会动的皮。

## 一、两套动画体系，各管一摊

Fuse 的动画能力分两层，先分清楚定位：

**AnimationPlayer 控制**，管的是"预制动画的播放"。你在 Godot 编辑器里用 Animation 面板做好的那些动画（run、jump、attack、idle），通过 Fuse 的指令去播放、停止、混合、变速。适合角色动作、过场动画、状态机驱动的动画切换。它还能监听 AnimationPlayer 发出的各种信号，做成事件——这是"动画驱动逻辑"的入口。

**Tween 补间**，管的是"运行时实时算出来的过渡"。你不用提前做动画资源，只要告诉它"把这个节点从 A 缩放到 B，用 0.3 秒，缓动用 Back"，它运行时自己算每一帧的值。适合 UI 动效、受击反馈、拾取特效这种"一次性、参数化、不需要做成完整动画"的过渡。

一句话区分：**AnimationPlayer 是"播做好的片"，Tween 是"实时算过渡"。** 真实项目里两者混用——角色跑动跳攻击用 AnimationPlayer，UI 和受击反馈用 Tween。

## 二、AnimationPlayer 控制：4 个指令

| 指令 | 作用 | 关键参数 |
|------|------|----------|
| **PlayAnimation**（播放动画） | 在 AnimationPlayer 上播指定动画 | `animation_name`、`speed`、`from_end` |
| **StopAnimation**（停止动画） | 停止播放 | `keep_position`（保持当前帧 or 重置到开头） |
| **BlendAnimation**（混合动画） | 设置 AnimationTree 混合轨道的值 | `blend_path`、`blend_amount` 或变量驱动 |
| **SetAnimationSpeed**（设置动画速度） | 改 AnimationPlayer 的全局速度缩放 | `speed_scale` |

`PlayAnimation` 最常用。填 `target_player` 指向 AnimationPlayer 节点（比如 `%Player/AnimationPlayer`），`animation_name` 填动画名（"run"、"attack"），就能播。`speed` 控制这次播放的速度，`from_end = true` 可以倒放——做"动画倒退回起始姿势"时有用。

`StopAnimation` 有个细节：`keep_position = true`（默认）是暂停、保持当前姿势；`keep_position = false` 是停止并重置到开头。角色死亡冻结姿势用前者，重置状态机用后者。

`SetAnimationSpeed` 和 `PlayAnimation.speed` 容易混。区别是：`PlayAnimation.speed` 只影响这一次播放调用；`SetAnimationSpeed` 直接改 AnimationPlayer 的 `speed_scale` 属性，**影响之后所有动画**。做全局慢动作用 `SetAnimationSpeed`，做单次变速播放用 `PlayAnimation.speed`。

实战：慢动作效果。受击时想让整个角色进入子弹时间：

```
受击事件 → SetAnimationSpeed(speed_scale: 0.3)   # 全局慢放到 30%
Wait(0.5 秒)
SetAnimationSpeed(speed_scale: 1.0)              # 恢复正常
```

## 三、BlendAnimation：动画树混合

如果你的角色用的是 AnimationTree（混合空间、状态机），`BlendAnimation` 是核心。它设置某个混合轨道的值，比如 `parameters/BlendSpace1D/blend_position`。有两种模式：直接给一个 0.0~1.0 的数值，或者用变量驱动。

变量驱动模式是和前面表达式、变量系统联动的关键：

```
BlendAnimation
  target_tree: %Player/AnimationTree
  blend_path:  "parameters/BlendSpace1D/blend_position"
  use_variable: true
  blend_variable: "move_speed"    # 从 move_speed 变量读混合量
  blend_scope: Local
```

这样角色的待机→走→跑过渡，就完全由 `move_speed` 变量驱动——你在移动逻辑里更新这个变量，动画混合自动跟上。这就是"数据驱动动画"的标准做法。配合表里的 `SetAnimationBlendPosition`（设置动画混合位置）和 `SetAnimationTreeParameter`（设置动画树参数），AnimationTree 的各种参数都能从可视化逻辑里控制。

## 四、6 个动画事件：让动画反过来驱动逻辑

AnimationPlayer 会发出各种信号，Fuse 把它们做成了 6 个事件，这是"动画播放到某个点 → 触发某段逻辑"的入口：

| 事件 | 触发时机 |
|------|----------|
| **OnAnimationStarted**（动画开始） | 开始播放某动画时 |
| **OnAnimationFinished**（动画完成） | 播放完成时 |
| **OnAnimationLoop**（动画循环） | 循环动画每绕一圈时 |
| **OnAnimationFrameReached**（动画帧到达） | 播放到指定帧时 |
| **OnAnimationMarker**（动画标记） | 经过动画里打的标记点时 |
| **OnAnimationBlend**（动画混合） | AnimationTree 混合权重越过阈值时 |

最常用的是 `OnAnimationFinished`。经典模式：攻击动画播完切回待机：

```
事件: OnAnimationFinished(animation_name: "attack")
指令: PlayAnimation(animation_name: "idle")
```

`OnAnimationFrameReached` 和 `OnAnimationMarker` 是做"精确时机判定"的利器。比如攻击动画第 12 帧才是真正挥刀命中的瞬间，你在那一帧触发伤害判定，比用 `Wait` 猜时间精准得多。`OnAnimationMarker` 更灵活——你在 Godot 的 Animation 面板里给关键帧打上字符串标记（如 "hit"、"footstep"），动画播到那里就触发，可以同时驱动音效（脚步声）和逻辑（伤害判定）。

`OnAnimationBlend` 适合检测"混合空间切换是否完成"。比如角色从走过渡到跑，混合权重越过 0.8 时才触发"跑步扬尘粒子"，避免过渡中途就误触发。

这些事件还通过 `set_meta()` 把动画名、当前帧、播放位置等参数塞进上下文，下游指令能用 `context.get_meta("animation_name")` 之类的取出来用。

## 五、Tween 全家桶：13 个补间指令

Tween 这边指令更多，分三组：

**基础属性动画**（7 个）：`TweenFadeIn`（淡入）、`TweenFadeOut`（淡出）、`TweenMoveTo`（移动到）、`TweenScaleTo`（缩放到）、`TweenRotateTo`（旋转到）、`TweenColorTransition`（颜色过渡）、`TweenPropertyInstruction`（属性动画，通用）。

**预置特效动画**（4 个）：`TweenPopAnimation`（弹出动画）、`TweenShakeAnimation`（震动动画）、`TweenBounceAnimation`（弹跳动画）、`TweenPulseAnimation`（脉冲动画）。

**控制**（2 个）：`TweenPause`（暂停 Tween）、`TweenResume`（恢复 Tween）。

基础组里前六个是"把某个属性平滑过渡到目标值"，参数都包含目标节点、目标值、持续时间、缓动类型（Easing）、过渡类型（Trans）。`TweenPropertyInstruction` 是兜底的通用款，能动画化任意属性，包括 Material 和 Shader 参数——比如 `modulate:a`（透明度）、`material:shader_param/glow_intensity`（着色器参数），前六个专用指令覆盖不到的，用它。

预置组是"开箱即用的手感特效"，不用自己调缓动曲线：

`TweenPopAnimation` 用弹簧缓动从 0 弹到目标大小，适合弹窗、宝箱、气泡。

`TweenShakeAnimation` 是受击反馈的主力，参数有强度、次数、轴向（X/Y/XY）。角色被打一下就 `TweenShakeAnimation`（强度 10、次数 3、XY），立刻有打击感。

`TweenBounceAnimation` 模拟掉落反弹，物品掉地用它。

`TweenPulseAnimation` 是呼吸/脉冲，缩放在 min/max 之间往复，`loop_count = 0` 无限循环——给"可交互的 NPC 头顶提示图标"加一个持续的呼吸效果，玩家一眼就知道能点。

## 六、缓动与过渡的搭配

Tween 的手感好坏，八成取决于缓动（Easing）和过渡（Trans）曲线选得对不对。这是 Fuse 帮你把 Godot 原生 Tween 的全部曲线都暴露出来的地方。

缓动类型控制速度变化方式：`In`（慢起快收，适合下落）、`Out`（快起慢收，适合减速停止）、`InOut`（两头慢，适合平滑移动）、`OutIn`（两头快）。

过渡类型控制数学曲线形状：`Linear`（匀速，简单移动）、`Sine`（正弦，自然过渡）、`Back`（回弹，UI 滑入）、`Spring`（弹簧，弹性弹出）、`Bounce`（弹跳，落地）、`Elastic`（弹性拉伸，夸张特效）。

几组经典搭配记住就能覆盖大部分场景：

- UI 交互（按钮悬停、弹窗）：`Out` + `Back` 或 `Spring`，有那种"略微超过再回弹"的弹性感。
- 自然移动（角色滑行、相机跟随）：`InOut` + `Sine`，平滑加减速。
- 掉落落地（物品下落）：`Out` + `Bounce`，落地反弹。
- 弹性强调（得分跳出、成就弹出）：`Out` + `Elastic`，夸张的拉伸回弹。

预置指令已经帮你选好了曲线（Pop 用 Spring、Bounce 用 Bounce），你直接用就行；基础指令需要自己挑搭配，记住上面四组就够。

## 七、一个能跑的受击反馈案例

把 AnimationPlayer 和 Tween 拼起来，做一个完整的受击反馈。这是游戏手感最经典的打磨点。角色受击时：闪红 + 震动 + 慢动作 0.2 秒 + 播受击动画。

```
事件: OnHealthChanged（hp 下降时）或自定义受击信号
指令:
  → PlayAnimation(animation_name: "hurt")          # 播受击动画
  → TweenColorTransition(target: 角色, color: 红色, duration: 0.1)  # 闪红
  → TweenShakeAnimation(target: 角色, intensity: 10, count: 3, axis: XY)  # 震动
  → SetAnimationSpeed(speed_scale: 0.3)            # 慢动作
  → Wait(0.2 秒)
  → SetAnimationSpeed(speed_scale: 1.0)            # 恢复
  → TweenColorTransition(target: 角色, color: 白色, duration: 0.2)  # 恢复颜色
```

这一串跑下来，角色被打会先闪一下红、身体震动三下、整个进入慢动作 0.2 秒再恢复——这就是动作游戏里那种"有分量的打击感"。每一步都是前面讲过的指令，组合起来效果完全不一样。改几个参数（震动强度、慢放倍率、持续时长）就能调出截然不同的手感，而且全程在 Inspector 里拖拽试错，不用反复改代码重编译。

再补一个 UI 弹窗的例子。任务完成的弹窗从 0 弹出：

```
事件: 任务完成（自定义信号或 OnVariableChanged）
指令:
  → TweenPopAnimation(target: 弹窗, target_scale: 1.0, duration: 0.4)
```

一行，弹窗就带着弹簧效果从零弹到完整大小。如果还想强调，加个 `TweenPulseAnimation`（loop: 3）让它弹完后脉冲三下提示玩家注意。

## 八、手感打磨的几条经验

最后给几条做手感时的实战经验，都是从 Tween 指南的最佳实践里提炼的：

**时长分级。** 快速反馈（点击、闪烁）0.05~0.15 秒；UI 动画（淡入、滑入）0.2~0.5 秒；角色动作（移动、攻击）0.3~0.8 秒；过场（场景切换）0.5~2.0 秒。时长不对，缓动再好也救不了——0.5 秒的按钮悬停反馈会显得迟钝，0.1 秒的场景切换会显得突兀。

**auto_free 自动清理。** `TweenFadeOut` 和 `TweenPropertyInstruction` 支持 `auto_free` 参数，动画播完自动释放节点。拾取物品"放大+淡出"后用 `auto_free = true`，节点自动消失，不用手动 `QueueFreeNode`。

**无限循环要记得停。** `TweenPulseAnimation`（脉冲动画）的 `loop_count = 0` 是无限循环，玩家接受任务后一定要手动停止（`TweenPause` 或取消），否则那个提示图标会一直闪到关游戏。

**别同时跑太多。** 同时运行的 Tween 建议控制在 50 个以内。大量对象需要动画时（比如一百个粒子），考虑用对象池（`InstantiateScene` + `WarmUpPool`，那是后面工程化篇的内容）而不是给每个都挂 Tween。

## 九、下一篇：让角色真正受控

动画会播了、补间会做了、受击反馈有手感了。但现在的角色还是"播动画却不真的移动"——你按右键，它播跑动画，却停在原地。因为真正的角色控制，是输入事件 + 物理移动 + 物理条件的组合，那是另一套体系。

**下一篇，我会讲角色操控实战：输入事件怎么接键鼠手柄，`MoveCharacterBody2DComposite` 怎么做基础和平滑移动，物理条件（CheckOnFloor / CheckOnWall / CheckInAir / CheckIsFalling）怎么搭出跳跃、二段跳、攀墙、滑铲。** 到那一步，你的角色才算真正"活着"——能动、能跳、能攀墙，而且全程可视化搭建。
