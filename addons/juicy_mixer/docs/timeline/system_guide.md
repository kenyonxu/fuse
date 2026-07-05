# JuicyMixer V3 Timeline系统使用指南

## 概述

JuicyMixer V3 的Timeline系统是一个强大的时间轴动画和效果管理系统，允许您在时间轴上精确控制各种效果的播放、参数变化和交互。Timeline系统与JuicyMixer V3的其他组件完美集成，提供了统一的接口来管理复杂的时序效果。

## 核心概念

### JuicyTimelineResource

[`JuicyTimelineResource`](../resources/juicy_timeline_resource.gd:6) 是Timeline系统的核心类，负责管理轨道、关键帧和播放控制：

- **轨道管理**：支持多种类型的轨道（属性、反馈、方法、事件）
- **关键帧系统**：精确控制属性值在特定时间点的变化
- **播放控制**：支持播放、暂停、停止、跳转等操作
- **参数映射**：与JuicyMixer V3的参数映射系统完全集成

### JuicyTrack

[`JuicyTrack`](../resources/juicy_track.gd:6) 是所有轨道类型的基类，定义了轨道的通用行为：

- **时间控制**：控制轨道的开始时间、持续时间和循环
- **启用状态**：可以单独启用或禁用轨道
- **参数映射**：支持动态参数映射

### JuicyKeyframe

[`JuicyKeyframe`](../resources/juicy_keyframe.gd:6) 定义了时间轴上的关键点：

- **时间位置**：关键帧在时间轴上的位置
- **值**：关键帧的值
- **插值类型**：控制关键帧之间的过渡方式

## 轨道类型详解

### 1. 属性轨道 (JuicyPropertyTrack)

属性轨道用于控制目标节点的属性值变化：

```gdscript
# 创建属性轨道
var property_track = JuicyPropertyTrack.new()
property_track.track_name = "ScaleAnimation"
property_track.target_node_path = "Sprite2D"
property_track.property_path = "scale"
property_track.duration = 2.0
property_track.enabled = true

# 添加关键帧
var keyframe1 = JuicyKeyframe.new()
keyframe1.time = 0.0
keyframe1.value = Vector2(1.0, 1.0)
keyframe1.interpolation_type = JuicyKeyframe.InterpolationType.LINEAR

var keyframe2 = JuicyKeyframe.new()
keyframe2.time = 1.0
keyframe2.value = Vector2(1.5, 1.5)
keyframe2.interpolation_type = JuicyKeyframe.InterpolationType.EASE_IN_OUT

property_track.add_keyframe(keyframe1)
property_track.add_keyframe(keyframe2)
```

### 2. 反馈轨道 (JuicyFeedbackTrack)

反馈轨道用于在特定时间点触发JuicyMixer反馈效果：

```gdscript
# 创建反馈轨道
var feedback_track = JuicyFeedbackTrack.new()
feedback_track.track_name = "ScreenShake"
feedback_track.resource = shake_resource
feedback_track.duration = 0.5
feedback_track.enabled = true

# 添加触发关键帧
var trigger_keyframe = JuicyKeyframe.new()
trigger_keyframe.time = 0.2
trigger_keyframe.value = true  # 触发值
trigger_keyframe.interpolation_type = JuicyKeyframe.InterpolationType.DISCRETE

feedback_track.add_keyframe(trigger_keyframe)
```

### 3. 方法轨道 (JuicyMethodTrack)

方法轨道用于在特定时间点调用目标节点的方法：

```gdscript
# 创建方法轨道
var method_track = JuicyMethodTrack.new()
method_track.track_name = "SoundEffects"
method_track.target_node_path = "AudioStreamPlayer2D"
method_track.method_name = "play"
method_track.duration = 1.0
method_track.enabled = true

# 添加调用关键帧
var call_keyframe = JuicyKeyframe.new()
call_keyframe.time = 0.0
call_keyframe.value = ["impact_sound.wav", 0.8]  # 参数数组
call_keyframe.interpolation_type = JuicyKeyframe.InterpolationType.DISCRETE

method_track.add_keyframe(call_keyframe)
```

### 4. 事件轨道 (JuicyEventTrack)

事件轨道用于在特定时间点触发JuicyMixer事件：

```gdscript
# 创建事件轨道
var event_track = JuicyEventTrack.new()
event_track.track_name = "ParticleEffects"
event_track.juicy_event = particle_event
event_track.duration = 3.0
event_track.enabled = true

# 添加事件关键帧
var event_keyframe = JuicyKeyframe.new()
event_keyframe.time = 0.5
event_keyframe.value = {"intensity": 1.0, "color": Color.RED}  # 事件参数
event_keyframe.interpolation_type = JuicyKeyframe.InterpolationType.DISCRETE

event_track.add_keyframe(event_keyframe)
```

## Timeline创建和配置

### 基本Timeline创建

```gdscript
# 创建Timeline资源
var timeline = JuicyTimelineResource.new()
timeline.timeline_name = "PlayerHitReaction"
timeline.duration = 2.0
timeline.loop = false
timeline.auto_play = false

# 添加轨道
timeline.add_track(property_track)
timeline.add_track(feedback_track)
timeline.add_track(method_track)
timeline.add_track(event_track)
```

### 使用Timeline驱动器

```gdscript
# 获取或创建Timeline驱动器
var timeline_driver = JuicyTimelineDriver.new()

# 播放Timeline
var context_id = timeline_driver.play(timeline, target_node, owner_node)

# 控制播放
timeline_driver.pause(context_id)
timeline_driver.resume(context_id)
timeline_driver.stop(context_id)

# 跳转到特定时间
timeline_driver.seek(context_id, 1.0)
```

## 参数映射集成

Timeline系统与JuicyMixer V3的参数映射系统完全集成，允许动态调整轨道参数：

### 在轨道中使用参数映射

```gdscript
# 为属性轨道添加参数映射
property_track.use_parameter_mapping = true

# 创建强度映射
var intensity_mapping = JuicyParameterMapping.new()
intensity_mapping.input_parameter = "player_health"
intensity_mapping.mapping_type = JuicyParameterMapping.MappingType.TRACK_VALUE
intensity_mapping.target_property = "intensity"
intensity_mapping.input_range = Vector2(0, 100)
intensity_mapping.output_range = Vector2(0.5, 2.0)

property_track.parameter_mappings = [intensity_mapping]
```

### 运行时参数更新

```gdscript
# 获取Timeline上下文
var context = timeline_driver.get_context(context_id)

# 更新参数
context.set_parameter("player_health", 50.0)  # 50%生命值
```

## 高级功能

### 1. 轨道混合和权重

```gdscript
# 设置轨道权重
property_track.weight = 0.8  # 80%影响
feedback_track.weight = 1.2  # 120%影响
```

### 2. 轨道分组

```gdscript
# 创建轨道组
var track_group = {
    "name": "VisualEffects",
    "tracks": [property_track, feedback_track],
    "enabled": true
}

timeline.add_track_group(track_group)
```

### 3. 条件激活

```gdscript
# 创建激活条件
var health_condition = JuicyParameterCondition.new()
health_condition.parameter_name = "player_health"
health_condition.operator = JuicyParameterCondition.ComparisonOperator.LESS_THAN
health_condition.target_value = 0.3

# 附加到轨道
property_track.activation_condition = health_condition
```

### 4. 自定义插值

```gdscript
# 创建自定义插值曲线
var custom_curve = Curve.new()
custom_curve.add_point(Vector2(0, 0))
custom_curve.add_point(Vector2(0.5, 0.2))
custom_curve.add_point(Vector2(1, 1))

# 应用到关键帧
keyframe.custom_curve = custom_curve
keyframe.interpolation_type = JuicyKeyframe.InterpolationType.CUBIC_SPLINE
```

## 性能优化

### 1. 轨道优化

```gdscript
# 禁用不需要的轨道
property_track.enabled = false

# 使用适当的插值类型
keyframe.interpolation_type = JuicyKeyframe.InterpolationType.LINEAR  # 最快
```

### 2. 批量操作

```gdscript
# 批量添加关键帧
var keyframes = [keyframe1, keyframe2, keyframe3]
property_track.add_keyframes_batch(keyframes)
```

### 3. 预加载和缓存

```gdscript
# 预加载Timeline资源
timeline_driver.preload_timeline(timeline)

# 启用缓存
timeline_driver.enable_caching = true
```

## 调试和监控

### 1. 启用调试模式

```gdscript
# 启用Timeline驱动器调试
timeline_driver.enable_debug(true)

# 启用详细日志
timeline_driver.debug_level = JuicyTimelineDriver.DebugLevel.VERBOSE
```

### 2. 监控性能

```gdscript
# 获取性能统计
var stats = timeline_driver.get_performance_stats()
print("平均帧时间: ", stats.average_frame_time)
print("内存使用: ", stats.memory_usage)
```

### 3. 可视化调试

```gdscript
# 启用Timeline可视化
timeline_driver.enable_visualization = true

# 获取Timeline状态
var state = timeline_driver.get_timeline_state(context_id)
print("当前时间: ", state.current_time)
print("活跃轨道: ", state.active_tracks)
```

## 最佳实践

### 1. 组织和命名

- 使用描述性的轨道名称
- 按功能分组轨道
- 保持一致的命名约定

### 2. 性能考虑

- 避免过多的关键帧
- 使用适当的插值类型
- 定期清理不需要的轨道

### 3. 错误处理

- 始终验证轨道配置
- 处理目标节点不存在的情况
- 提供合理的默认值

### 4. 资源管理

- 重用Timeline资源
- 使用对象池
- 及时释放不需要的资源

## 示例：完整的战斗反应Timeline

```gdscript
# 创建战斗反应Timeline
func create_combat_reaction_timeline() -> JuicyTimelineResource:
    var timeline = JuicyTimelineResource.new()
    timeline.timeline_name = "CombatReaction"
    timeline.duration = 1.5
    timeline.loop = false
    
    # 1. 屏幕闪烁轨道
    var flash_track = JuicyPropertyTrack.new()
    flash_track.track_name = "ScreenFlash"
    flash_track.target_node_path = "CanvasModulate"
    flash_track.property_path = "color"
    flash_track.duration = 0.3
    
    var flash_in = JuicyKeyframe.new()
    flash_in.time = 0.0
    flash_in.value = Color.WHITE
    flash_in.interpolation_type = JuicyKeyframe.InterpolationType.DISCRETE
    
    var flash_out = JuicyKeyframe.new()
    flash_out.time = 0.3
    flash_out.value = Color.WHITE
    flash_out.interpolation_type = JuicyKeyframe.InterpolationType.LINEAR
    
    flash_track.add_keyframe(flash_in)
    flash_track.add_keyframe(flash_out)
    
    # 2. 屏幕震动轨道
    var shake_track = JuicyFeedbackTrack.new()
    shake_track.track_name = "ScreenShake"
    shake_track.resource = shake_resource
    shake_track.duration = 0.5
    
    var shake_trigger = JuicyKeyframe.new()
    shake_trigger.time = 0.1
    shake_trigger.value = true
    shake_trigger.interpolation_type = JuicyKeyframe.InterpolationType.DISCRETE
    
    shake_track.add_keyframe(shake_trigger)
    
    # 3. 受击音效轨道
    var sound_track = JuicyMethodTrack.new()
    sound_track.track_name = "HitSound"
    sound_track.target_node_path = "AudioStreamPlayer2D"
    sound_track.method_name = "play"
    sound_track.duration = 0.1
    
    var sound_trigger = JuicyKeyframe.new()
    sound_trigger.time = 0.0
    sound_trigger.value = ["hit_sound.wav", 1.0]
    sound_trigger.interpolation_type = JuicyKeyframe.InterpolationType.DISCRETE
    
    sound_track.add_keyframe(sound_trigger)
    
    # 4. 粒子效果轨道
    var particle_track = JuicyEventTrack.new()
    particle_track.track_name = "HitParticles"
    particle_track.juicy_event = hit_particle_event
    particle_track.duration = 1.0
    
    var particle_trigger = JuicyKeyframe.new()
    particle_trigger.time = 0.05
    particle_trigger.value = {"count": 20, "spread": 45.0}
    particle_trigger.interpolation_type = JuicyKeyframe.InterpolationType.DISCRETE
    
    particle_track.add_keyframe(particle_trigger)
    
    # 添加所有轨道
    timeline.add_track(flash_track)
    timeline.add_track(shake_track)
    timeline.add_track(sound_track)
    timeline.add_track(particle_track)
    
    return timeline

# 使用Timeline
func play_combat_reaction():
    var timeline = create_combat_reaction_timeline()
    var timeline_driver = JuicyTimelineDriver.new()
    var context_id = timeline_driver.play(timeline, get_tree().current_scene, self)
    
    # 可选：根据玩家生命值调整效果强度
    var context = timeline_driver.get_context(context_id)
    var health_percentage = get_health_percentage()
    context.set_parameter("intensity", health_percentage)
```

通过这种方式，您可以创建复杂、精确且高度可定制的时间轴效果，完美集成到JuicyMixer V3的生态系统中。