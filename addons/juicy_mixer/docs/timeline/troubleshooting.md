# JuicyMixer V3 Timeline系统故障排除指南

## 概述

本文档提供了JuicyMixer V3 Timeline系统常见问题的诊断和解决方案，帮助您快速定位和修复Timeline相关的问题。

## 常见问题分类

### 1. 播放问题

#### Timeline不播放

**症状**：调用`JuicyTimeline.play()`后，Timeline没有开始播放。

**可能原因**：
- Timeline资源未正确配置
- 目标节点无效
- 轨道配置错误

**诊断步骤**：
```gdscript
# 1. 验证Timeline资源
var validation = timeline.validate()
if not validation.valid:
    print("Timeline验证失败: ", validation.issues)
    return

# 2. 检查目标节点
if not is_instance_valid(target):
    print("目标节点无效")
    return

# 3. 验证轨道配置
for track in timeline.tracks:
    if not track.enabled:
        continue
    
    if track is JuicyPropertyTrack:
        var node = target.get_node(track.target_node_path)
        if not node:
            print("属性轨道目标节点不存在: ", track.target_node_path)
            continue
        
        if not node.has_method("set"):
            print("目标节点不支持属性设置: ", node.get_path())
            continue

# 4. 尝试播放并检查结果
var context_id = JuicyTimeline.play(timeline, target)
if context_id.is_empty():
    print("Timeline播放失败")
    return

# 5. 检查播放状态
await get_tree().create_timer(0.1).timeout
var state = timeline_driver.get_timeline_state(context_id)
if not state.is_playing:
    print("Timeline未正常播放")
```

**解决方案**：
```gdscript
# 修复配置问题
func fix_timeline_configuration(timeline: JuicyTimelineResource):
    # 确保至少有一个轨道
    if timeline.tracks.is_empty():
        print("Timeline没有轨道，添加默认轨道")
        var default_track = JuicyPropertyTrack.new()
        default_track.track_name = "DefaultTrack"
        timeline.add_track(default_track)
    
    # 修复轨道配置
    for track in timeline.tracks:
        if track is JuicyPropertyTrack:
            var prop_track = track as JuicyPropertyTrack
            if prop_track.target_node_path.is_empty():
                prop_track.target_node_path = "."
            
            if prop_track.property_path.is_empty():
                prop_track.property_path = "modulate"
```

#### Timeline立即停止

**症状**：Timeline开始播放后立即停止。

**可能原因**：
- Timeline持续时间为0
- 所有轨道都被禁用
- 激活条件未满足

**诊断步骤**：
```gdscript
# 1. 检查Timeline持续时间
if timeline.duration <= 0:
    print("Timeline持续时间无效: ", timeline.duration)

# 2. 检查轨道状态
var active_tracks = 0
for track in timeline.tracks:
    if track.enabled:
        active_tracks += 1
        print("活跃轨道: ", track.track_name)

if active_tracks == 0:
    print("没有活跃的轨道")

# 3. 检查激活条件
for track in timeline.tracks:
    if track.enabled and track.activation_condition:
        var context = create_test_context()
        if not track.activation_condition.evaluate(context):
            print("轨道激活条件未满足: ", track.track_name)
```

**解决方案**：
```gdscript
# 修复持续时间问题
func fix_timeline_duration(timeline: JuicyTimelineResource):
    # 自动计算持续时间
    var max_duration = 0.0
    for track in timeline.tracks:
        if track.keyframes.is_empty():
            continue
        
        var last_keyframe = track.keyframes[-1]
        var track_end = last_keyframe.time + track.start_time
        max_duration = max(max_duration, track_end)
    
    if max_duration > timeline.duration:
        timeline.duration = max_duration
        print("自动调整Timeline持续时间为: ", timeline.duration)

# 启用轨道
func enable_tracks(timeline: JuicyTimelineResource):
    for track in timeline.tracks:
        if not track.enabled:
            track.enabled = true
            print("启用轨道: ", track.track_name)
```

### 2. 属性轨道问题

#### 属性不更新

**症状**：属性轨道播放时，目标属性值没有变化。

**可能原因**：
- 目标节点路径错误
- 属性名称错误
- 属性类型不匹配
- 关键帧值无效

**诊断步骤**：
```gdscript
# 1. 验证节点路径
var track = timeline.get_track_by_name("ProblemTrack") as JuicyPropertyTrack
if not track:
    print("找不到指定的属性轨道")
    return

var target_node = get_node_or_null(track.target_node_path)
if not target_node:
    print("目标节点不存在: ", track.target_node_path)
    return

# 2. 验证属性
var property_info = target_node.get_property_list()
var property_found = false
for prop in property_info:
    if prop.name == track.property_path:
        property_found = true
        print("找到属性: ", prop.name, " 类型: ", prop.type)
        break

if not property_found:
    print("属性不存在: ", track.property_path)
    return

# 3. 验证关键帧
for keyframe in track.keyframes:
    print("关键帧 - 时间: ", keyframe.time, " 值: ", keyframe.value, " 类型: ", typeof(keyframe.value))
```

**解决方案**：
```gdscript
# 修复属性轨道
func fix_property_track(track: JuicyPropertyTrack, target_node: Node):
    # 自动修正节点路径
    if track.target_node_path.is_empty():
        track.target_node_path = target_node.get_path()
    
    # 验证并修正属性值
    for keyframe in track.keyframes:
        var current_value = target_node.get(track.property_path)
        if current_value != null:
            # 尝试类型转换
            if typeof(keyframe.value) != typeof(current_value):
                print("类型不匹配，尝试转换")
                keyframe.value = convert_value(keyframe.value, typeof(current_value))
```

#### 插值不工作

**症状**：属性值在关键帧之间没有平滑过渡。

**可能原因**：
- 插值类型设置为DISCRETE
- 只有一个关键帧
- 关键帧时间相同

**诊断步骤**：
```gdscript
# 检查插值设置
for keyframe in track.keyframes:
    print("关键帧插值类型: ", keyframe.interpolation_type)

# 检查关键帧数量
if track.keyframes.size() < 2:
    print("关键帧数量不足，无法插值")

# 检查关键帧时间
var times = []
for keyframe in track.keyframes:
    times.append(keyframe.time)

if times.has_duplicates():
    print("关键帧时间重复")
```

**解决方案**：
```gdscript
# 修复插值设置
func fix_interpolation(track: JuicyPropertyTrack):
    # 确保有足够的关键帧
    if track.keyframes.size() < 2:
        print("添加默认关键帧")
        var start_keyframe = JuicyKeyframe.new()
        start_keyframe.time = 0.0
        start_keyframe.value = track.default_value if track.default_value != null else 0.0
        start_keyframe.interpolation_type = JuicyKeyframe.InterpolationType.LINEAR
        
        var end_keyframe = JuicyKeyframe.new()
        end_keyframe.time = track.duration
        end_keyframe.value = track.default_value if track.default_value != null else 1.0
        end_keyframe.interpolation_type = JuicyKeyframe.InterpolationType.LINEAR
        
        track.add_keyframe(start_keyframe)
        track.add_keyframe(end_keyframe)
    
    # 修复插值类型
    for keyframe in track.keyframes:
        if keyframe.interpolation_type == JuicyKeyframe.InterpolationType.DISCRETE:
            keyframe.interpolation_type = JuicyKeyframe.InterpolationType.LINEAR
```

### 3. 反馈轨道问题

#### 反馈效果不触发

**症状**：反馈轨道在指定时间点没有触发效果。

**可能原因**：
- 反馈资源未设置
- 触发条件不满足
- 触发值不正确

**诊断步骤**：
```gdscript
# 1. 检查反馈资源
var feedback_track = track as JuicyFeedbackTrack
if not feedback_track.resource:
    print("反馈轨道未设置资源")
    return

# 2. 验证资源
var validation = feedback_track.resource.validate()
if not validation.valid:
    print("反馈资源验证失败: ", validation.issues)

# 3. 检查触发关键帧
for keyframe in feedback_track.keyframes:
    print("触发关键帧 - 时间: ", keyframe.time, " 值: ", keyframe.value)
```

**解决方案**：
```gdscript
# 修复反馈轨道
func fix_feedback_track(track: JuicyFeedbackTrack):
    # 设置默认资源
    if not track.resource:
        print("设置默认反馈资源")
        track.resource = create_default_feedback_resource()
    
    # 添加触发关键帧
    if track.keyframes.is_empty():
        var trigger_keyframe = JuicyKeyframe.new()
        trigger_keyframe.time = 0.0
        trigger_keyframe.value = true
        trigger_keyframe.interpolation_type = JuicyKeyframe.InterpolationType.DISCRETE
        track.add_keyframe(trigger_keyframe)
```

### 4. 方法轨道问题

#### 方法不调用

**症状**：方法轨道在指定时间点没有调用目标方法。

**可能原因**：
- 目标节点路径错误
- 方法名称错误
- 方法参数不匹配

**诊断步骤**：
```gdscript
# 1. 验证目标节点和方法
var method_track = track as JuicyMethodTrack
var target_node = get_node_or_null(method_track.target_node_path)
if not target_node:
    print("目标节点不存在: ", method_track.target_node_path)
    return

if not target_node.has_method(method_track.method_name):
    print("方法不存在: ", method_track.method_name)
    return

# 2. 检查方法参数
print("方法参数: ", method_track.args)
```

**解决方案**：
```gdscript
# 修复方法轨道
func fix_method_track(track: JuicyMethodTrack, target_node: Node):
    # 自动修正节点路径
    if track.target_node_path.is_empty():
        track.target_node_path = target_node.get_path()
    
    # 验证方法存在
    if not target_node.has_method(track.method_name):
        print("方法不存在，尝试查找相似方法")
        var method_list = target_node.get_method_list()
        for method in method_list:
            if method.name.to_lower().contains(track.method_name.to_lower()):
                print("找到相似方法: ", method.name)
                track.method_name = method.name
                break
```

### 5. 事件轨道问题

#### 事件不触发

**症状**：事件轨道在指定时间点没有触发事件。

**可能原因**：
- 事件对象未设置
- 事件参数无效
- 事件处理器未注册

**诊断步骤**：
```gdscript
# 1. 检查事件对象
var event_track = track as JuicyEventTrack
if not event_track.juicy_event:
    print("事件轨道未设置事件对象")
    return

# 2. 验证事件处理器
if not JuicyMixer.has_event_handler(event_track.juicy_event.event_type):
    print("事件处理器未注册: ", event_track.juicy_event.event_type)

# 3. 检查事件参数
print("事件参数: ", event_track.event_parameters)
```

**解决方案**：
```gdscript
# 修复事件轨道
func fix_event_track(track: JuicyEventTrack):
    # 设置默认事件
    if not track.juicy_event:
        print("设置默认事件")
        track.juicy_event = create_default_event()
    
    # 添加触发关键帧
    if track.keyframes.is_empty():
        var trigger_keyframe = JuicyKeyframe.new()
        trigger_keyframe.time = 0.0
        trigger_keyframe.value = {}
        trigger_keyframe.interpolation_type = JuicyKeyframe.InterpolationType.DISCRETE
        track.add_keyframe(trigger_keyframe)
```

### 6. 性能问题

#### Timeline播放卡顿

**症状**：Timeline播放时出现明显的性能下降。

**可能原因**：
- 过多的关键帧
- 复杂的插值计算
- 频繁的属性更新

**诊断步骤**：
```gdscript
# 1. 检查关键帧数量
var total_keyframes = 0
for track in timeline.tracks:
    total_keyframes += track.keyframes.size()

print("总关键帧数量: ", total_keyframes)
if total_keyframes > 1000:
    print("关键帧数量过多，可能导致性能问题")

# 2. 检查性能统计
var stats = timeline_driver.get_performance_stats()
print("平均帧时间: ", stats.average_frame_time, "ms")
print("内存使用: ", stats.memory_usage, "bytes")
```

**解决方案**：
```gdscript
# 优化Timeline性能
func optimize_timeline_performance(timeline: JuicyTimelineResource):
    # 减少关键帧数量
    for track in timeline.tracks:
        if track.keyframes.size() > 50:
            print("简化轨道: ", track.track_name)
            simplify_track_keyframes(track)
    
    # 启用缓存
    timeline_driver.enable_caching = true
    
    # 批量处理属性更新
    timeline_driver.enable_batch_processing = true

func simplify_track_keyframes(track: JuicyTrack):
    # 移除冗余关键帧
    var simplified_keyframes = []
    for i in range(track.keyframes.size()):
        var keyframe = track.keyframes[i]
        
        # 保留第一个和最后一个关键帧
        if i == 0 or i == track.keyframes.size() - 1:
            simplified_keyframes.append(keyframe)
            continue
        
        # 检查是否可以移除
        var prev_keyframe = track.keyframes[i - 1]
        var next_keyframe = track.keyframes[i + 1]
        
        if keyframe.value == prev_keyframe.value and keyframe.value == next_keyframe.value:
            print("移除冗余关键帧: ", keyframe.time)
            continue
        
        simplified_keyframes.append(keyframe)
    
    track.keyframes = simplified_keyframes
```

#### 内存泄漏

**症状**：长时间运行后内存使用持续增长。

**可能原因**：
- Timeline资源未正确释放
- 上下文对象未清理
- 循环引用

**诊断步骤**：
```gdscript
# 1. 检查活跃上下文数量
var stats = timeline_driver.get_performance_stats()
print("活跃Timeline数量: ", stats.active_timelines)

# 2. 检查内存使用
print("当前内存使用: ", OS.get_static_memory_usage_by_type())

# 3. 检查资源引用
for context_id in active_contexts:
    var context = timeline_driver.get_context(context_id)
    if context:
        print("上下文引用计数: ", context.get_reference_count())
```

**解决方案**：
```gdscript
# 修复内存泄漏
func fix_memory_leaks():
    # 清理完成的Timeline
    for context_id in active_contexts.duplicate():
        var state = timeline_driver.get_timeline_state(context_id)
        if not state.is_playing:
            timeline_driver.stop(context_id)
            active_contexts.erase(context_id)
    
    # 强制垃圾回收
    call_deferred("_force_garbage_collection")

func _force_garbage_collection():
    # 清理对象池
    JuicyPoolManager.cleanup_pools()
    
    # 强制垃圾回收
    GC.gc()
```

### 7. 参数映射问题

#### 参数映射不工作

**症状**：参数映射没有正确影响轨道行为。

**可能原因**：
- 参数未设置
- 映射配置错误
- 范围设置不正确

**诊断步骤**：
```gdscript
# 1. 检查参数值
var context = timeline_driver.get_context(context_id)
if context:
    for param_name in ["intensity", "speed", "volume"]:
        var value = context.get_parameter(param_name)
        print("参数 ", param_name, " = ", value)

# 2. 检查映射配置
for track in timeline.tracks:
    if track.use_parameter_mapping:
        for mapping in track.parameter_mappings:
            print("映射: ", mapping.input_parameter, " -> ", mapping.target_property)
            print("输入范围: ", mapping.input_range)
            print("输出范围: ", mapping.output_range)
```

**解决方案**：
```gdscript
# 修复参数映射
func fix_parameter_mapping(timeline: JuicyTimelineResource):
    for track in timeline.tracks:
        if not track.use_parameter_mapping:
            continue
        
        # 验证映射配置
        for mapping in track.parameter_mappings:
            if mapping.input_range.x == mapping.input_range.y:
                print("修正输入范围")
                mapping.input_range = Vector2(0.0, 1.0)
            
            if mapping.output_range.x == mapping.output_range.y:
                print("修正输出范围")
                mapping.output_range = Vector2(0.0, 1.0)
```

## 调试工具

### 1. Timeline调试器

```gdscript
# Timeline调试器类
extends Node
class_name TimelineDebugger

static func debug_timeline(timeline: JuicyTimelineResource, target: Node):
    print("=== Timeline调试信息 ===")
    print("名称: ", timeline.timeline_name)
    print("持续时间: ", timeline.duration)
    print("轨道数量: ", timeline.tracks.size())
    
    for track in timeline.tracks:
        print("\n--- 轨道: ", track.track_name, " ---")
        print("类型: ", track.get_class())
        print("启用: ", track.enabled)
        print("关键帧数量: ", track.keyframes.size())
        
        for keyframe in track.keyframes:
            print("  时间: ", keyframe.time, " 值: ", keyframe.value)
    
    print("=== 调试信息结束 ===")

static func debug_context(context_id: String):
    var driver = JuicyTimelineDriver.new()
    var state = driver.get_timeline_state(context_id)
    
    print("=== 上下文调试信息 ===")
    print("上下文ID: ", context_id)
    print("当前时间: ", state.current_time)
    print("是否播放: ", state.is_playing)
    print("是否暂停: ", state.is_paused)
    print("活跃轨道: ", state.active_tracks)
    print("=== 调试信息结束 ===")
```

### 2. 性能监视器

```gdscript
# 性能监视器类
extends Node
class_name TimelinePerformanceMonitor

var _performance_history = []
var _max_history_size = 100

func _ready():
    # 定期收集性能数据
    var timer = Timer.new()
    timer.wait_time = 1.0
    timer.timeout.connect(_collect_performance_data)
    timer.autostart = true
    add_child(timer)

func _collect_performance_data():
    var driver = JuicyTimelineDriver.new()
    var stats = driver.get_performance_stats()
    
    var data_point = {
        "timestamp": Time.get_unix_time_from_system(),
        "frame_time": stats.average_frame_time,
        "memory_usage": stats.memory_usage,
        "active_timelines": stats.active_timelines
    }
    
    _performance_history.append(data_point)
    
    # 限制历史记录大小
    if _performance_history.size() > _max_history_size:
        _performance_history.pop_front()
    
    # 检查性能警告
    if stats.average_frame_time > 16.0:
        print("性能警告: 帧时间超过16ms")
    
    if stats.active_timelines > 50:
        print("性能警告: 活跃Timeline数量过多")

func get_performance_report() -> Dictionary:
    if _performance_history.is_empty():
        return {}
    
    var avg_frame_time = 0.0
    var max_frame_time = 0.0
    var avg_memory = 0.0
    var max_timelines = 0
    
    for data in _performance_history:
        avg_frame_time += data.frame_time
        max_frame_time = max(max_frame_time, data.frame_time)
        avg_memory += data.memory_usage
        max_timelines = max(max_timelines, data.active_timelines)
    
    avg_frame_time /= _performance_history.size()
    avg_memory /= _performance_history.size()
    
    return {
        "average_frame_time": avg_frame_time,
        "max_frame_time": max_frame_time,
        "average_memory": avg_memory,
        "max_concurrent_timelines": max_timelines,
        "data_points": _performance_history.size()
    }
```

## 常见错误代码

| 错误代码 | 描述 | 解决方案 |
|----------|------|----------|
| `ERR_INVALID_PARAMETER` | 参数无效 | 检查传入的参数类型和值 |
| `ERR_DOES_NOT_EXIST` | 资源不存在 | 验证资源路径和加载状态 |
| `ERR_ALREADY_EXISTS` | 资源已存在 | 检查是否重复创建或添加 |
| `ERR_INVALID_DATA` | 数据无效 | 验证数据格式和完整性 |
| `ERR_OUT_OF_MEMORY` | 内存不足 | 优化内存使用，释放不需要的资源 |

## 预防措施

### 1. 开发阶段

- 始终验证Timeline配置
- 使用调试模式进行测试
- 实施全面的单元测试
- 定期进行性能分析

### 2. 运行时

- 监控性能指标
- 实施错误恢复机制
- 提供用户反馈
- 记录详细的错误日志

### 3. 维护阶段

- 定期更新和优化
- 清理不需要的资源
- 监控内存使用
- 实施预防性检查

## 联系支持

如果遇到无法解决的问题，请提供以下信息：

1. **错误描述**：详细描述问题现象
2. **重现步骤**：提供重现问题的步骤
3. **系统信息**：Godot版本、操作系统等
4. **调试日志**：相关的调试输出
5. **Timeline配置**：问题Timeline的配置信息

通过遵循本指南，您可以快速诊断和解决Timeline系统的大多数问题，确保游戏效果的稳定运行。