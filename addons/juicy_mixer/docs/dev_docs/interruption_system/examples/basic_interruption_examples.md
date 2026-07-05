# 基础中断策略使用示例

## 概述

本文档提供了JuicyMixer中断策略系统的基础使用示例，帮助开发者快速理解和应用不同的中断策略。

## 准备工作

在开始使用中断策略之前，确保已经正确初始化了JuicyMixer系统：

```gdscript
# 在游戏启动时初始化JuicyMixer
func _ready():
    # JuicyMixer会自动初始化
    print("JuicyMixer已初始化")
```

## 基本中断策略示例

### 1. 堆叠策略 (STACK)

堆叠策略会将新效果加入队列，当前效果继续执行。

```gdscript
# 创建一个使用堆叠策略的反馈资源
var stack_resource = JuicyFeedbackResource.new()
stack_resource.duration = 1.0
stack_resource.channel = "ui_effects"
stack_resource.set_interruption_policy(JuicyMixerEnms.InterruptionPolicy.STACK)

# 播放第一个效果
var context_id1 = JuicyMixer.play(stack_resource, button1)
print("播放效果1: ", context_id1)

# 播放第二个效果（会被加入队列）
var context_id2 = JuicyMixer.play(stack_resource, button2)
print("播放效果2: ", context_id2)

# 播放第三个效果（会被加入队列）
var context_id3 = JuicyMixer.play(stack_resource, button3)
print("播放效果3: ", context_id3)

# 效果会按顺序执行：效果1 -> 效果2 -> 效果3
```

### 2. 重启策略 (RESTART)

重启策略会立即停止当前效果，开始新效果。

```gdscript
# 创建一个使用重启策略的反馈资源
var restart_resource = JuicyFeedbackResource.new()
restart_resource.duration = 2.0
restart_resource.channel = "critical_effects"
restart_resource.set_interruption_policy(JuicyMixerEnms.InterruptionPolicy.RESTART)

# 播放第一个效果
var context_id1 = JuicyMixer.play(restart_resource, target_node)
print("播放长时间效果: ", context_id1)

# 等待一段时间
await get_tree().create_timer(0.5).timeout

# 播放第二个效果（会立即中断第一个效果）
var context_id2 = JuicyMixer.play(restart_resource, target_node)
print("播放紧急效果: ", context_id2)

# 第一个效果会被立即停止，第二个效果开始执行
```

### 3. 忽略策略 (IGNORE)

忽略策略会忽略新效果，保持当前效果继续执行。

```gdscript
# 创建一个使用忽略策略的反馈资源
var ignore_resource = JuicyFeedbackResource.new()
ignore_resource.duration = 3.0
ignore_resource.channel = "important_effects"
ignore_resource.set_interruption_policy(JuicyMixerEnms.InterruptionPolicy.IGNORE)
ignore_resource.allow_interruption = false  # 确保不被中断

# 播放重要效果
var context_id1 = JuicyMixer.play(ignore_resource, important_target)
print("播放重要效果: ", context_id1)

# 尝试播放其他效果（会被忽略）
var context_id2 = JuicyMixer.play(ignore_resource, same_target)
print("尝试播放其他效果: ", context_id2)

# 第二个效果会被立即忽略，第一个效果继续执行
```

### 4. 平滑过渡策略 (SMOOTH_TRANSITION)

平滑过渡策略会平滑地从当前效果过渡到新效果。

```gdscript
# 创建一个使用平滑过渡策略的反馈资源
var smooth_resource = JuicyFeedbackResource.new()
smooth_resource.duration = 1.5
smooth_resource.channel = "visual_effects"
smooth_resource.set_interruption_policy(JuicyMixerEnms.InterruptionPolicy.SMOOTH_TRANSITION)
smooth_resource.interruption_fade_duration = 0.3

# 播放第一个效果
var context_id1 = JuicyMixer.play(smooth_resource, target_node)
print("播放第一个视觉效果: ", context_id1)

# 等待一段时间
await get_tree().create_timer(0.5).timeout

# 播放第二个效果（会平滑过渡）
var context_id2 = JuicyMixer.play(smooth_resource, target_node)
print("播放第二个视觉效果: ", context_id2)

# 第一个效果会平滑过渡到第二个效果
```

### 5. 优先级覆盖策略 (PRIORITY_OVERRIDE)

优先级覆盖策略允许高优先级效果覆盖低优先级效果。

```gdscript
# 创建低优先级效果
var low_priority_resource = JuicyFeedbackResource.new()
low_priority_resource.duration = 2.0
low_priority_resource.channel = "ui_effects"
low_priority_resource.set_interruption_policy(JuicyMixerEnms.InterruptionPolicy.PRIORITY_OVERRIDE)
low_priority_resource.set_interruption_priority(5)

# 创建高优先级效果
var high_priority_resource = JuicyFeedbackResource.new()
high_priority_resource.duration = 1.0
high_priority_resource.channel = "ui_effects"
high_priority_resource.set_interruption_policy(JuicyMixerEnms.InterruptionPolicy.PRIORITY_OVERRIDE)
high_priority_resource.set_interruption_priority(10)

# 播放低优先级效果
var context_id1 = JuicyMixer.play(low_priority_resource, button)
print("播放低优先级效果: ", context_id1)

# 等待一段时间
await get_tree().create_timer(0.5).timeout

# 播放高优先级效果（会覆盖低优先级效果）
var context_id2 = JuicyMixer.play(high_priority_resource, button)
print("播放高优先级效果: ", context_id2)

# 高优先级效果会覆盖低优先级效果
```

### 6. 淡出淡入策略 (FADE_OUT_FADE_IN)

淡出淡入策略会让当前效果淡出，然后新效果淡入。

```gdscript
# 创建一个使用淡出淡入策略的反馈资源
var fade_resource = JuicyFeedbackResource.new()
fade_resource.duration = 1.0
fade_resource.channel = "audio_effects"
fade_resource.set_interruption_policy(JuicyMixerEnms.InterruptionPolicy.FADE_OUT_FADE_IN)
fade_resource.interruption_fade_duration = 0.2

# 播放第一个音频效果
var context_id1 = JuicyMixer.play(fade_resource, audio_player)
print("播放第一个音频效果: ", context_id1)

# 等待一段时间
await get_tree().create_timer(0.5).timeout

# 播放第二个音频效果（会淡出淡入）
var context_id2 = JuicyMixer.play(fade_resource, audio_player)
print("播放第二个音频效果: ", context_id2)

# 第一个效果会淡出，然后第二个效果淡入
```

### 7. 优先级堆叠策略 (PRIORITY_STACK)

优先级堆叠策略会按优先级插入队列。

```gdscript
# 创建不同优先级的效果
var priority_5_resource = JuicyFeedbackResource.new()
priority_5_resource.duration = 1.0
priority_5_resource.channel = "combat_effects"
priority_5_resource.set_interruption_policy(JuicyMixerEnms.InterruptionPolicy.PRIORITY_STACK)
priority_5_resource.set_interruption_priority(5)

var priority_10_resource = JuicyFeedbackResource.new()
priority_10_resource.duration = 1.0
priority_10_resource.channel = "combat_effects"
priority_10_resource.set_interruption_policy(JuicyMixerEnms.InterruptionPolicy.PRIORITY_STACK)
priority_10_resource.set_interruption_priority(10)

var priority_7_resource = JuicyFeedbackResource.new()
priority_7_resource.duration = 1.0
priority_7_resource.channel = "combat_effects"
priority_7_resource.set_interruption_policy(JuicyMixerEnms.InterruptionPolicy.PRIORITY_STACK)
priority_7_resource.set_interruption_priority(7)

# 按顺序播放效果
var context_id1 = JuicyMixer.play(priority_5_resource, target)
print("播放优先级5效果: ", context_id1)

var context_id2 = JuicyMixer.play(priority_7_resource, target)
print("播放优先级7效果: ", context_id2)

var context_id3 = JuicyMixer.play(priority_10_resource, target)
print("播放优先级10效果: ", context_id3)

# 效果会按优先级顺序执行：优先级10 -> 优先级7 -> 优先级5
```

## 通道级配置示例

### 设置通道默认策略

```gdscript
# 创建UI效果通道配置
var ui_config = ChannelInterruptionConfig.new()
ui_config.channel_name = "ui_effects"
ui_config.set_policy(JuicyMixerEnms.InterruptionPolicy.PRIORITY_OVERRIDE)
ui_config.set_channel_priority(10)
ui_config.set_max_queue_size(5)

# 创建战斗效果通道配置
var combat_config = ChannelInterruptionConfig.new()
combat_config.channel_name = "combat_effects"
combat_config.set_policy(JuicyMixerEnms.InterruptionPolicy.PRIORITY_STACK)
combat_config.set_channel_priority(15)
combat_config.set_max_queue_size(10)

# 创建音频效果通道配置
var audio_config = ChannelInterruptionConfig.new()
audio_config.channel_name = "audio_effects"
audio_config.set_policy(JuicyMixerEnms.InterruptionPolicy.FADE_OUT_FADE_IN)
audio_config.set_transition_duration(0.3)
audio_config.set_channel_priority(5)

# 应用通道配置
JuicyMixer.set_channel_interruption_config("ui_effects", ui_config)
JuicyMixer.set_channel_interruption_config("combat_effects", combat_config)
JuicyMixer.set_channel_interruption_config("audio_effects", audio_config)
```

### 使用通道配置的效果

```gdscript
# 创建使用通道配置的效果
var ui_effect = JuicyFeedbackResource.new()
ui_effect.duration = 0.5
ui_effect.channel = "ui_effects"  # 使用UI通道配置
# 不需要单独设置中断策略，会使用通道默认策略

var combat_effect = JuicyFeedbackResource.new()
combat_effect.duration = 1.0
combat_effect.channel = "combat_effects"  # 使用战斗通道配置

var audio_effect = JuicyFeedbackResource.new()
audio_effect.duration = 2.0
audio_effect.channel = "audio_effects"  # 使用音频通道配置

# 播放效果
JuicyMixer.play(ui_effect, ui_button)
JuicyMixer.play(combat_effect, combat_character)
JuicyMixer.play(audio_effect, audio_source)
```

## 全局优先级设置示例

```gdscript
# 设置全局资源类型优先级
JuicyMixer.set_resource_interruption_priority("JuicyShakeResource", 10)
JuicyMixer.set_resource_interruption_priority("JuicyTweenResource", 5)
JuicyMixer.set_resource_interruption_priority("JuicySpringResource", 7)
JuicyMixer.set_resource_interruption_priority("JuicyParticleResource", 8)

# 创建不同类型的资源
var shake_effect = JuicyShakeResource.new()
shake_effect.channel = "effects"

var tween_effect = JuicyTweenResource.new()
tween_effect.channel = "effects"

# 播放效果（会根据全局优先级处理中断）
JuicyMixer.play(tween_effect, target)  # 优先级5
JuicyMixer.play(shake_effect, target)  # 优先级10，会覆盖tween效果
```

## 实际游戏场景示例

### UI按钮点击效果

```gdscript
# UI按钮点击处理
func _on_button_pressed():
    # 创建按钮点击效果
    var click_effect = JuicyFeedbackResource.new()
    click_effect.duration = 0.3
    click_effect.channel = "ui_feedback"
    click_effect.set_interruption_policy(JuicyMixerEnms.InterruptionPolicy.STACK)
    
    # 播放效果
    JuicyMixer.play(click_effect, self)
```

### 角色受伤效果

```gdscript
# 角色受伤处理
func take_damage(amount: int):
    # 创建受伤效果
    var damage_effect = JuicyFeedbackResource.new()
    damage_effect.duration = 0.8
    damage_effect.channel = "character_effects"
    damage_effect.set_interruption_policy(JuicyMixerEnms.InterruptionPolicy.PRIORITY_OVERRIDE)
    damage_effect.set_interruption_priority(15)  # 高优先级
    
    # 播放效果
    JuicyMixer.play(damage_effect, character_sprite)
    
    # 如果伤害严重，添加屏幕震动
    if amount > 50:
        var screen_shake = JuicyShakeResource.new()
        screen_shake.channel = "screen_effects"
        screen_shake.set_interruption_policy(JuicyMixerEnms.InterruptionPolicy.PRIORITY_OVERRIDE)
        screen_shake.set_interruption_priority(20)
        
        JuicyMixer.play(screen_shake, camera)
```

### 环境音效管理

```gdscript
# 环境音效管理
func play_ambient_sound(sound_resource: Resource):
    # 创建环境音效
    var ambient_effect = JuicyFeedbackResource.new()
    ambient_effect.duration = 5.0
    ambient_effect.channel = "ambient_audio"
    ambient_effect.set_interruption_policy(JuicyMixerEnms.InterruptionPolicy.FADE_OUT_FADE_IN)
    ambient_effect.interruption_fade_duration = 1.0
    
    # 播放效果
    JuicyMixer.play(ambient_effect, audio_player)

# 切换环境音效
func change_ambient_sound(new_sound: Resource):
    # 新音效会平滑地替换旧音效
    play_ambient_sound(new_sound)
```

## 中断状态监控示例

```gdscript
# 监控特定目标的中断状态
func monitor_interruption_state(target: Node):
    var state = JuicyMixer.get_interruption_state(target)
    if not state:
        print("目标没有中断状态")
        return
    
    print("=== 中断状态 ===")
    print("活跃上下文数量: ", state.get_active_context_count())
    print("队列上下文数量: ", state.get_queued_context_count())
    print("当前策略: ", JuicyMixerEnms.get_interruption_policy_name(state.current_policy))
    
    if state.is_transitioning():
        print("正在过渡，进度: ", state.transition_progress)
    
    # 显示活跃上下文
    for context_id in state.active_contexts:
        print("活跃上下文: ", context_id)
    
    # 显示队列上下文
    for context_id in state.queued_contexts:
        print("队列上下文: ", context_id)

# 定期监控
func _process(delta):
    if Input.is_action_just_pressed("debug_interruption"):
        monitor_interruption_state(player_character)
```

## 最佳实践

1. **策略选择**: 根据效果类型选择合适的中断策略
   - UI反馈: 使用STACK或PRIORITY_OVERRIDE
   - 关键效果: 使用RESTART或IGNORE
   - 视觉效果: 使用SMOOTH_TRANSITION
   - 音频效果: 使用FADE_OUT_FADE_IN

2. **通道管理**: 为不同类型的效果创建专用通道
   - `ui_effects`: UI相关效果
   - `combat_effects`: 战斗相关效果
   - `ambient_effects`: 环境效果
   - `audio_effects`: 音频效果

3. **优先级设置**: 合理设置优先级，确保重要效果能够正确中断其他效果

4. **过渡时间**: 根据效果类型设置合适的过渡时间，保证视觉流畅性

## 常见问题

### Q: 如何让某个效果不被中断？
A: 设置`allow_interruption = false`并使用IGNORE策略。

### Q: 如何让高优先级效果立即播放？
A: 使用PRIORITY_OVERRIDE策略并设置高优先级。

### Q: 如何实现效果的平滑切换？
A: 使用SMOOTH_TRANSITION或FADE_OUT_FADE_IN策略。

### Q: 如何管理大量效果的播放顺序？
A: 使用PRIORITY_STACK策略并设置合适的优先级。

## 相关文档

- [高级中断配置示例](advanced_interruption_examples.md)
- [自定义中断策略示例](custom_interruption_examples.md)
- [中断事件处理示例](interruption_event_examples.md)
- [性能优化示例](performance_optimization_examples.md)
- [API文档](../api/)