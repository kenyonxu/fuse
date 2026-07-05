# JuicyMixer V3 Timeline系统最佳实践指南

## 概述

本文档提供了使用JuicyMixer V3 Timeline系统的最佳实践建议，帮助您创建高效、可维护和高性能的时间轴效果。

## 设计原则

### 1. 模块化设计

将复杂的Timeline效果分解为多个独立的轨道和子Timeline：

```gdscript
# 好的做法：创建专门的轨道
var screen_effects_track = JuicyPropertyTrack.new()
var audio_effects_track = JuicyMethodTrack.new()
var particle_effects_track = JuicyEventTrack.new()

# 避免的做法：将所有效果混合在一个轨道中
var mixed_track = JuicyPropertyTrack.new()  # 不推荐
```

### 2. 可重用性

设计可重用的Timeline组件：

```gdscript
# 创建可重用的受击反应Timeline
func create_hit_reaction_timeline() -> JuicyTimelineResource:
    var timeline = JuicyTimelineResource.new()
    timeline.timeline_name = "HitReaction"
    
    # 标准化的受击效果轨道
    add_standard_screen_shake(timeline)
    add_standard_hit_sound(timeline)
    add_standard_hit_particles(timeline)
    
    return timeline

# 在不同场景中重用
func apply_hit_effect(target: Node, intensity: float = 1.0):
    var timeline = create_hit_reaction_timeline()
    var context_id = JuicyTimeline.play(timeline, target)
    
    # 根据需要调整强度
    var context = JuicyTimelineDriver.get_context(context_id)
    context.set_parameter("intensity", intensity)
```

### 3. 参数化设计

使用参数映射创建灵活的效果：

```gdscript
# 好的做法：使用参数映射
var health_mapping = JuicyParameterMapping.new()
health_mapping.input_parameter = "player_health"
health_mapping.mapping_type = JuicyParameterMapping.MappingType.TRACK_VALUE
health_mapping.input_range = Vector2(0, 100)
health_mapping.output_range = Vector2(0.5, 2.0)

# 避免的做法：硬编码值
keyframe.value = 1.5  # 不推荐，缺乏灵活性
```

## 性能优化

### 1. 轨道优化

#### 减少关键帧数量

```gdscript
# 好的做法：使用适当数量的关键帧
var keyframe1 = JuicyKeyframe.new()
keyframe1.time = 0.0
keyframe1.value = 0.0

var keyframe2 = JuicyKeyframe.new()
keyframe2.time = 1.0
keyframe2.value = 1.0

# 避免的做法：过多的关键帧
# 0.0 -> 0.1 -> 0.2 -> 0.3 -> ... -> 1.0 (不推荐)
```

#### 选择合适的插值类型

```gdscript
# 根据需要选择插值类型
keyframe.interpolation_type = JuicyKeyframe.InterpolationType.LINEAR  # 最快
keyframe.interpolation_type = JuicyKeyframe.InterpolationType.EASE_IN_OUT  # 平滑
keyframe.interpolation_type = JuicyKeyframe.InterpolationType.DISCRETE  # 无插值
```

#### 禁用不需要的轨道

```gdscript
# 动态启用/禁用轨道
func update_visual_effects(enabled: bool):
    for track in timeline.tracks:
        if track.track_name.begins_with("Visual"):
            track.enabled = enabled
```

### 2. 内存管理

#### 使用对象池

```gdscript
# 启用Timeline驱动器的缓存
timeline_driver.enable_caching = true

# 预加载常用Timeline
func preload_common_timelines():
    var common_timelines = [
        "hit_reaction",
        "level_complete",
        "power_up"
    ]
    
    for timeline_name in common_timelines:
        var timeline = load_timeline_resource(timeline_name)
        timeline_driver.preload_timeline(timeline)
```

#### 及时释放资源

```gdscript
# 在不需要时释放Timeline
func cleanup_timeline(context_id: String):
    if timeline_driver.stop(context_id):
        var context = timeline_driver.get_context(context_id)
        if context and context.timeline:
            timeline_driver.unload_timeline(context.timeline)
```

### 3. 批处理优化

```gdscript
# 批量添加关键帧
func add_keyframes_batch(track: JuicyTrack, keyframes: Array[JuicyKeyframe]):
    for keyframe in keyframes:
        track.add_keyframe(keyframe)
    
    # 批量处理优化
    track.optimize_keyframes()
```

## 组织结构

### 1. 命名约定

使用一致的命名约定：

```gdscript
# Timeline命名
"Player_Hit_Reaction"      # 使用下划线分隔
"Level_Complete_Cutscene"   # 描述性命名
"UI_Button_Hover"          # 包含上下文

# 轨道命名
"Screen_Shake"             # 动作_对象
"Hit_Sound_Effect"         # 效果类型_具体效果
"Player_Scale_Animation"    # 对象_属性_类型
```

### 2. 轨道分组

```gdscript
# 创建逻辑分组
var visual_effects_group = {
    "name": "VisualEffects",
    "tracks": [],
    "enabled": true
}

var audio_effects_group = {
    "name": "AudioEffects", 
    "tracks": [],
    "enabled": true
}

# 添加到Timeline
timeline.track_groups = [visual_effects_group, audio_effects_group]
```

### 3. 层次结构

```gdscript
# 创建主Timeline和子Timeline
var main_timeline = JuicyTimelineResource.new()
main_timeline.timeline_name = "ComplexScene"

# 子Timeline：角色动画
var character_timeline = create_character_animation_timeline()
var character_track = JuicyFeedbackTrack.new()
character_track.resource = character_timeline

# 子Timeline：环境效果
var environment_timeline = create_environment_effects_timeline()
var environment_track = JuicyFeedbackTrack.new()
environment_track.resource = environment_timeline

main_timeline.add_track(character_track)
main_timeline.add_track(environment_track)
```

## 错误处理

### 1. 验证配置

```gdscript
# 在使用前验证Timeline
func validate_and_play(timeline: JuicyTimelineResource, target: Node) -> String:
    var validation = timeline.validate()
    
    if not validation.valid:
        print("Timeline验证失败: ", validation.issues)
        return ""
    
    # 验证目标节点
    if not is_instance_valid(target):
        print("无效的目标节点")
        return ""
    
    return JuicyTimeline.play(timeline, target)
```

### 2. 安全的属性访问

```gdscript
# 安全的属性设置
func safe_set_property(track: JuicyPropertyTrack, target: Node, value: Variant):
    if not track or not target:
        return
    
    var node = target.get_node(track.target_node_path)
    if not node:
        print("目标节点不存在: ", track.target_node_path)
        return
    
    if not node.has_method("set") or not node.get(track.property_path) != null:
        print("属性不存在: ", track.property_path)
        return
    
    node.set(track.property_path, value)
```

### 3. 异常恢复

```gdscript
# 带有错误恢复的播放
func safe_play_timeline(timeline: JuicyTimelineResource, target: Node) -> String:
    var context_id = ""
    
    try:
        context_id = JuicyTimeline.play(timeline, target)
        
        # 设置错误处理回调
        var context = JuicyTimelineDriver.get_context(context_id)
        if context:
            context.connect("timeline_error", _on_timeline_error)
    
    except:
        print("Timeline播放失败: ", timeline.timeline_name)
        cleanup_on_error()
    
    return context_id

func _on_timeline_error(context_id: String, error: String):
    print("Timeline错误: ", error)
    # 执行错误恢复逻辑
    cleanup_timeline(context_id)
```

## 调试和监控

### 1. 调试配置

```gdscript
# 开发时启用调试
func setup_debug_mode():
    timeline_driver.enable_debug = true
    timeline_driver.debug_level = JuicyTimelineDriver.DebugLevel.VERBOSE
    
    # 连接调试信号
    timeline_driver.connect("timeline_started", _on_timeline_started)
    timeline_driver.connect("track_started", _on_track_started)
```

### 2. 性能监控

```gdscript
# 定期检查性能
func check_timeline_performance():
    var stats = timeline_driver.get_performance_stats()
    
    if stats.average_frame_time > 16.0:  # 超过16ms
        print("Timeline性能警告: 平均帧时间 ", stats.average_frame_time, "ms")
    
    if stats.memory_usage > MEMORY_THRESHOLD:
        print("Timeline内存使用警告: ", stats.memory_usage, " bytes")
```

### 3. 可视化调试

```gdscript
# 启用Timeline可视化
func enable_timeline_visualization():
    timeline_driver.enable_visualization = true
    
    # 创建调试UI
    var debug_ui = create_timeline_debug_ui()
    debug_ui.connect("timeline_seek", _on_debug_seek)
```

## 扩展和自定义

### 1. 自定义轨道类型

```gdscript
# 创建自定义轨道
extends JuicyTrack
class_name CustomShakeTrack

var shake_pattern: Curve
var shake_intensity: float = 1.0

func _init():
    track_name = "CustomShakeTrack"

func evaluate_at_time(time: float) -> Variant:
    if not shake_pattern:
        return Vector2.ZERO
    
    var t = time / duration
    var intensity = shake_pattern.sample(t) * shake_intensity
    return Vector2.RIGHT.rotated(time * 10.0) * intensity
```

### 2. 自定义插值器

```gdscript
# 创建自定义插值器
extends Resource
class_name BounceInterpolator

static func interpolate(from: Variant, to: Variant, t: float, data: Dictionary) -> Variant:
    # 弹跳插值
    var bounce = 1.0 - abs(sin(t * PI * 4.0)) * (1.0 - t)
    return from.lerp(to, bounce)
```

### 3. 中间件集成

```gdscript
# 创建Timeline专用中间件
extends JuicyMiddleware
class_name TimelineMiddleware

func _init():
    middleware_name = "TimelineMiddleware"
    priority = 50

func on_before_play(context: JuicyContext) -> void:
    if context.resource is JuicyTimelineResource:
        print("开始播放Timeline: ", context.resource.timeline_name)
        # Timeline特定的预处理逻辑

func on_after_play(context: JuicyContext) -> void:
    if context.resource is JuicyTimelineResource:
        print("Timeline播放完成: ", context.resource.timeline_name)
        # Timeline特定的后处理逻辑
```

## 测试策略

### 1. 单元测试

```gdscript
# 测试轨道功能
func test_property_track():
    var track = JuicyPropertyTrack.new()
    track.property_path = "scale"
    
    # 添加测试关键帧
    var keyframe1 = JuicyKeyframe.new()
    keyframe1.time = 0.0
    keyframe1.value = Vector2.ONE
    
    var keyframe2 = JuicyKeyframe.new()
    keyframe2.time = 1.0
    keyframe2.value = Vector2(2.0, 2.0)
    
    track.add_keyframe(keyframe1)
    track.add_keyframe(keyframe2)
    
    # 验证插值
    var mid_value = track.evaluate_at_time(0.5)
    assert(mid_value == Vector2(1.5, 1.5), "线性插值测试失败")
```

### 2. 集成测试

```gdscript
# 测试Timeline集成
func test_timeline_integration():
    var timeline = create_test_timeline()
    var test_node = create_test_target()
    
    var context_id = JuicyTimeline.play(timeline, test_node)
    
    # 验证播放状态
    await get_tree().create_timer(0.5).timeout
    var state = timeline_driver.get_timeline_state(context_id)
    assert(state.is_playing, "Timeline未正常播放")
    
    # 清理
    timeline_driver.stop(context_id)
```

### 3. 性能测试

```gdscript
# 测试Timeline性能
func test_timeline_performance():
    var timeline = create_complex_timeline()
    var test_nodes = create_test_targets(100)  # 100个目标
    
    var start_time = Time.get_ticks_msec()
    
    for target in test_nodes:
        JuicyTimeline.play(timeline, target)
    
    var end_time = Time.get_ticks_msec()
    var duration = end_time - start_time
    
    print("100个Timeline实例创建时间: ", duration, "ms")
    assert(duration < 100, "Timeline创建性能不达标")
```

## 常见陷阱和解决方案

### 1. 内存泄漏

**问题**：未正确释放Timeline资源导致内存泄漏。

**解决方案**：
```gdscript
# 正确的资源管理
func cleanup_timeline_resources():
    for context_id in active_contexts:
        timeline_driver.stop(context_id)
        
        var context = timeline_driver.get_context(context_id)
        if context and context.timeline:
            timeline_driver.unload_timeline(context.timeline)
    
    active_contexts.clear()
```

### 2. 性能下降

**问题**：大量同时播放的Timeline导致性能下降。

**解决方案**：
```gdscript
# 限制同时播放的Timeline数量
const MAX_CONCURRENT_TIMELINES = 50

func play_with_limit(timeline: JuicyTimelineResource, target: Node) -> String:
    var active_count = timeline_driver.get_performance_stats().active_timelines
    
    if active_count >= MAX_CONCURRENT_TIMELINES:
        print("达到Timeline播放限制，跳过新播放")
        return ""
    
    return JuicyTimeline.play(timeline, target)
```

### 3. 同步问题

**问题**：多个Timeline之间的同步出现问题。

**解决方案**：
```gdscript
# 使用主Timeline同步子Timeline
func create_synchronized_timelines():
    var main_timeline = JuicyTimelineResource.new()
    
    # 创建同步点
    var sync_marker = JuicyKeyframe.new()
    sync_marker.time = 2.0
    sync_marker.value = "sync_point"
    
    # 在所有子Timeline中添加相同的同步点
    for sub_timeline in sub_timelines:
        var sync_track = JuicyEventTrack.new()
        sync_track.add_keyframe(sync_marker)
        sub_timeline.add_track(sync_track)
    
    return main_timeline
```

## 版本控制

### 1. Timeline版本管理

```gdscript
# 为Timeline添加版本信息
var timeline = JuicyTimelineResource.new()
timeline.set_meta("version", "1.0.0")
timeline.set_meta("created_by", "TimelineEditor")
timeline.set_meta("last_modified", Time.get_datetime_string_from_system())
```

### 2. 向后兼容

```gdscript
# 处理版本兼容性
func load_timeline_with_compatibility(path: String) -> JuicyTimelineResource:
    var timeline = load(path) as JuicyTimelineResource
    
    if not timeline:
        return null
    
    var version = timeline.get_meta("version", "1.0.0")
    
    if version < "1.2.0":
        # 升级旧版本Timeline
        upgrade_legacy_timeline(timeline)
    
    return timeline
```

## 总结

遵循这些最佳实践，您可以创建高效、可维护和高性能的Timeline效果。关键要点：

1. **模块化设计**：将复杂效果分解为简单组件
2. **性能优化**：注意关键帧数量、插值类型和内存管理
3. **错误处理**：始终验证配置并提供错误恢复机制
4. **测试策略**：实施全面的单元测试和集成测试
5. **文档记录**：为复杂的Timeline添加详细的注释和文档

通过遵循这些指南，您可以充分利用JuicyMixer V3 Timeline系统的强大功能，创建出色的游戏效果。