# JuicyMixer V3 Timeline系统迁移指南

## 概述

本指南帮助您从JuicyMixer V2的Sequence系统迁移到V3的Timeline系统。Timeline系统是Sequence系统的完全重写版本，提供了更强大的功能和更好的性能。

## 主要变化

### 1. 架构变化

| V2 (Sequence) | V3 (Timeline) | 说明 |
|---------------|---------------|------|
| `JuicySequence` | `JuicyTimelineResource` | 核心资源类重命名 |
| `JuicySequenceTrack` | `JuicyTrack` | 轨道基类重命名 |
| `JuicySequenceDriver` | `JuicyTimelineDriver` | 驱动器重命名 |
| `JuicySequenceKeyframe` | `JuicyKeyframe` | 关键帧类重命名 |

### 2. API变化

#### 播放API

**V2 (Sequence)**:
```gdscript
var sequence_id = JuicyMixer.play_sequence(sequence, target)
```

**V3 (Timeline)**:
```gdscript
var context_id = JuicyTimeline.play(timeline, target)
```

#### 控制API

**V2 (Sequence)**:
```gdscript
JuicyMixer.pause_sequence(sequence_id)
JuicyMixer.resume_sequence(sequence_id)
JuicyMixer.stop_sequence(sequence_id)
```

**V3 (Timeline)**:
```gdscript
JuicyTimeline.pause(context_id)
JuicyTimeline.resume(context_id)
JuicyTimeline.stop(context_id)
```

### 3. 轨道类型变化

| V2轨道类型 | V3轨道类型 | 迁移说明 |
|------------|------------|----------|
| `JuicyPropertySequenceTrack` | `JuicyPropertyTrack` | 直接替换 |
| `JuicyFeedbackSequenceTrack` | `JuicyFeedbackTrack` | 直接替换 |
| `JuicyMethodSequenceTrack` | `JuicyMethodTrack` | 直接替换 |
| `JuicyEventSequenceTrack` | `JuicyEventTrack` | 直接替换 |

### 4. 新增功能

Timeline系统引入了以下新功能：

- **参数映射系统**：支持动态参数绑定
- **轨道分组**：可以组织相关轨道
- **条件激活**：基于条件的轨道激活
- **高级插值**：更多插值类型和自定义曲线
- **性能优化**：更好的缓存和批处理机制

## 迁移步骤

### 步骤1：备份现有项目

在开始迁移之前，请确保：

1. 完整备份项目文件
2. 创建版本控制分支
3. 记录当前Sequence的使用情况

```gdscript
# 创建迁移前的清单
func create_migration_checklist():
    var sequences = find_all_sequences()
    var checklist = {
        "total_sequences": sequences.size(),
        "sequences_by_type": {},
        "custom_tracks": [],
        "integration_points": []
    }
    
    for sequence in sequences:
        var type = sequence.get_class()
        if not checklist.sequences_by_type.has(type):
            checklist.sequences_by_type[type] = 0
        checklist.sequences_by_type[type] += 1
    
    return checklist
```

### 步骤2：安装V3系统

1. 确保JuicyMixer V3已正确安装
2. 验证Timeline系统组件可用
3. 检查插件配置

```gdscript
# 验证V3安装
func verify_v3_installation():
    # 检查核心类是否存在
    assert(ClassDB.class_exists("JuicyTimelineResource"), "TimelineResource未找到")
    assert(ClassDB.class_exists("JuicyTimelineDriver"), "TimelineDriver未找到")
    assert(ClassDB.class_exists("JuicyTrack"), "Track基类未找到")
    
    # 检查轨道类型
    assert(ClassDB.class_exists("JuicyPropertyTrack"), "PropertyTrack未找到")
    assert(ClassDB.class_exists("JuicyFeedbackTrack"), "FeedbackTrack未找到")
    assert(ClassDB.class_exists("JuicyMethodTrack"), "MethodTrack未找到")
    assert(ClassDB.class_exists("JuicyEventTrack"), "EventTrack未找到")
    
    print("V3 Timeline系统验证成功")
```

### 步骤3：转换Sequence资源

#### 基本转换工具

```gdscript
# Sequence到Timeline转换器
extends Resource
class_name SequenceToTimelineConverter

static func convert_sequence(sequence: Resource) -> JuicyTimelineResource:
    var timeline = JuicyTimelineResource.new()
    
    # 基本属性转换
    timeline.timeline_name = sequence.sequence_name if sequence.has_method("get_sequence_name") else "ConvertedSequence"
    timeline.duration = sequence.duration if sequence.has_method("get_duration") else 1.0
    timeline.loop = sequence.loop if sequence.has_method("get_loop") else false
    
    # 转换轨道
    if sequence.has_method("get_tracks"):
        for sequence_track in sequence.get_tracks():
            var timeline_track = convert_track(sequence_track)
            if timeline_track:
                timeline.add_track(timeline_track)
    
    return timeline

static func convert_track(sequence_track: Resource) -> JuicyTrack:
    if sequence_track.get_class() == "JuicyPropertySequenceTrack":
        return convert_property_track(sequence_track)
    elif sequence_track.get_class() == "JuicyFeedbackSequenceTrack":
        return convert_feedback_track(sequence_track)
    elif sequence_track.get_class() == "JuicyMethodSequenceTrack":
        return convert_method_track(sequence_track)
    elif sequence_track.get_class() == "JuicyEventSequenceTrack":
        return convert_event_track(sequence_track)
    else:
        print("未知轨道类型: ", sequence_track.get_class())
        return null

static func convert_property_track(sequence_track: Resource) -> JuicyPropertyTrack:
    var track = JuicyPropertyTrack.new()
    
    # 基本属性
    track.track_name = sequence_track.track_name if sequence_track.has_method("get_track_name") else "PropertyTrack"
    track.enabled = sequence_track.enabled if sequence_track.has_method("get_enabled") else true
    track.start_time = sequence_track.start_time if sequence_track.has_method("get_start_time") else 0.0
    track.duration = sequence_track.duration if sequence_track.has_method("get_duration") else 1.0
    
    # 属性特定
    track.target_node_path = sequence_track.target_node_path if sequence_track.has_method("get_target_node_path") else NodePath(".")
    track.property_path = sequence_track.property_path if sequence_track.has_method("get_property_path") else "modulate"
    
    # 转换关键帧
    if sequence_track.has_method("get_keyframes"):
        for sequence_keyframe in sequence_track.get_keyframes():
            var keyframe = convert_keyframe(sequence_keyframe)
            if keyframe:
                track.add_keyframe(keyframe)
    
    return track

static func convert_keyframe(sequence_keyframe: Resource) -> JuicyKeyframe:
    var keyframe = JuicyKeyframe.new()
    
    keyframe.time = sequence_keyframe.time if sequence_keyframe.has_method("get_time") else 0.0
    keyframe.value = sequence_keyframe.value if sequence_keyframe.has_method("get_value") else null
    
    # 转换插值类型
    var interpolation_type = sequence_keyframe.interpolation_type if sequence_keyframe.has_method("get_interpolation_type") else 0
    keyframe.interpolation_type = convert_interpolation_type(interpolation_type)
    
    return keyframe

static func convert_interpolation_type(old_type: int) -> JuicyKeyframe.InterpolationType:
    match old_type:
        0: return JuicyKeyframe.InterpolationType.LINEAR
        1: return JuicyKeyframe.InterpolationType.EASE_IN
        2: return JuicyKeyframe.InterpolationType.EASE_OUT
        3: return JuicyKeyframe.InterpolationType.EASE_IN_OUT
        _: return JuicyKeyframe.InterpolationType.LINEAR
```

#### 批量转换脚本

```gdscript
# 批量转换工具
extends EditorScript

func _run():
    var converter = SequenceToTimelineConverter.new()
    var sequence_files = find_all_sequence_files()
    
    print("找到 ", sequence_files.size(), " 个Sequence文件")
    
    for sequence_file in sequence_files:
        print("转换: ", sequence_file)
        
        # 加载Sequence
        var sequence = load(sequence_file)
        if not sequence:
            print("无法加载: ", sequence_file)
            continue
        
        # 转换为Timeline
        var timeline = converter.convert_sequence(sequence)
        
        # 保存Timeline
        var timeline_path = sequence_file.replace(".tres", "_timeline.tres")
        ResourceSaver.save(timeline, timeline_path)
        
        print("已保存: ", timeline_path)
    
    print("转换完成")

func find_all_sequence_files() -> Array[String]:
    var files = []
    var dir = DirAccess.open("res://")
    
    if dir:
        _scan_directory(dir, "res://", files)
    
    return files

func _scan_directory(dir: DirAccess, base_path: String, files: Array[String]):
    dir.list_dir_begin()
    var file_name = dir.get_next()
    
    while file_name != "":
        var full_path = base_path.path_join(file_name)
        
        if dir.current_is_dir():
            if not file_name.begins_with("."):
                var sub_dir = DirAccess.open(full_path)
                if sub_dir:
                    _scan_directory(sub_dir, full_path + "/", files)
        elif file_name.ends_with(".tres"):
            # 检查是否为Sequence文件
            var resource = load(full_path)
            if resource and resource.get_class().contains("Sequence"):
                files.append(full_path)
        
        file_name = dir.get_next()
    
    dir.list_dir_end()
```

### 步骤4：更新代码引用

#### 搜索和替换模式

```gdscript
# 代码更新工具
extends EditorScript

func _run():
    var script_files = find_all_script_files()
    
    for script_file in script_files:
        update_script_references(script_file)
    
    print("代码更新完成")

func update_script_references(script_path: String):
    var file = FileAccess.open(script_path, FileAccess.READ)
    if not file:
        return
    
    var content = file.get_as_text()
    file.close()
    
    var original_content = content
    
    # 更新类名引用
    content = content.replace("JuicySequence", "JuicyTimelineResource")
    content = content.replace("JuicySequenceTrack", "JuicyTrack")
    content = content.replace("JuicySequenceDriver", "JuicyTimelineDriver")
    content = content.replace("JuicySequenceKeyframe", "JuicyKeyframe")
    
    # 更新轨道类型
    content = content.replace("JuicyPropertySequenceTrack", "JuicyPropertyTrack")
    content = content.replace("JuicyFeedbackSequenceTrack", "JuicyFeedbackTrack")
    content = content.replace("JuicyMethodSequenceTrack", "JuicyMethodTrack")
    content = content.replace("JuicyEventSequenceTrack", "JuicyEventTrack")
    
    # 更新API调用
    content = content.replace("play_sequence", "play")
    content = content.replace("pause_sequence", "pause")
    content = content.replace("resume_sequence", "resume")
    content = content.replace("stop_sequence", "stop")
    
    # 更新变量名
    content = content.replace("sequence_id", "context_id")
    content = content.replace("sequence_driver", "timeline_driver")
    
    # 如果内容有变化，保存文件
    if content != original_content:
        var file_out = FileAccess.open(script_path, FileAccess.WRITE)
        if file_out:
            file_out.store_string(content)
            file_out.close()
            print("已更新: ", script_path)

func find_all_script_files() -> Array[String]:
    var files = []
    var dir = DirAccess.open("res://")
    
    if dir:
        _scan_for_scripts(dir, "res://", files)
    
    return files

func _scan_for_scripts(dir: DirAccess, base_path: String, files: Array[String]):
    dir.list_dir_begin()
    var file_name = dir.get_next()
    
    while file_name != "":
        var full_path = base_path.path_join(file_name)
        
        if dir.current_is_dir():
            if not file_name.begins_with("."):
                var sub_dir = DirAccess.open(full_path)
                if sub_dir:
                    _scan_for_scripts(sub_dir, full_path + "/", files)
        elif file_name.ends_with(".gd"):
            files.append(full_path)
        
        file_name = dir.get_next()
    
    dir.list_dir_end()
```

### 步骤5：验证迁移结果

#### 验证工具

```gdscript
# 迁移验证工具
extends EditorScript

func _run():
    var validation_results = validate_migration()
    
    print("=== 迁移验证结果 ===")
    print("总Timeline数: ", validation_results.total_timelines)
    print("有效Timeline数: ", validation_results.valid_timelines)
    print("无效Timeline数: ", validation_results.invalid_timelines)
    print("警告数: ", validation_results.warnings.size())
    
    if validation_results.invalid_timelines > 0:
        print("\n=== 需要修复的Timeline ===")
        for issue in validation_results.issues:
            print(issue)
    
    if not validation_results.warnings.is_empty():
        print("\n=== 警告 ===")
        for warning in validation_results.warnings:
            print(warning)

func validate_migration() -> Dictionary:
    var results = {
        "total_timelines": 0,
        "valid_timelines": 0,
        "invalid_timelines": 0,
        "issues": [],
        "warnings": []
    }
    
    var timeline_files = find_all_timeline_files()
    results.total_timelines = timeline_files.size()
    
    for timeline_file in timeline_files:
        var timeline = load(timeline_file)
        if not timeline:
            results.issues.append("无法加载Timeline: " + timeline_file)
            results.invalid_timelines += 1
            continue
        
        var validation = validate_timeline(timeline)
        if validation.valid:
            results.valid_timelines += 1
        else:
            results.invalid_timelines += 1
            for issue in validation.issues:
                results.issues.append(timeline_file + ": " + issue)
        
        for warning in validation.warnings:
            results.warnings.append(timeline_file + ": " + warning)
    
    return results

func validate_timeline(timeline: JuicyTimelineResource) -> Dictionary:
    var result = {
        "valid": true,
        "issues": [],
        "warnings": []
    }
    
    # 检查基本属性
    if timeline.timeline_name.is_empty():
        result.issues.append("Timeline名称为空")
        result.valid = false
    
    if timeline.duration <= 0:
        result.issues.append("Timeline持续时间无效")
        result.valid = false
    
    if timeline.tracks.is_empty():
        result.warnings.append("Timeline没有轨道")
    
    # 检查轨道
    for track in timeline.tracks:
        var track_validation = validate_track(track)
        if not track_validation.valid:
            result.valid = false
            for issue in track_validation.issues:
                result.issues.append("轨道 " + track.track_name + ": " + issue)
        
        for warning in track_validation.warnings:
            result.warnings.append("轨道 " + track.track_name + ": " + warning)
    
    return result

func validate_track(track: JuicyTrack) -> Dictionary:
    var result = {
        "valid": true,
        "issues": [],
        "warnings": []
    }
    
    # 检查基本属性
    if track.track_name.is_empty():
        result.issues.append("轨道名称为空")
        result.valid = false
    
    if track.duration <= 0:
        result.issues.append("轨道持续时间无效")
        result.valid = false
    
    if track.keyframes.is_empty():
        result.warnings.append("轨道没有关键帧")
    
    # 检查特定轨道类型
    if track is JuicyPropertyTrack:
        var prop_track = track as JuicyPropertyTrack
        if prop_track.target_node_path.is_empty():
            result.issues.append("目标节点路径为空")
            result.valid = false
        
        if prop_track.property_path.is_empty():
            result.issues.append("属性路径为空")
            result.valid = false
    
    return result

func find_all_timeline_files() -> Array[String]:
    var files = []
    var dir = DirAccess.open("res://")
    
    if dir:
        _scan_for_timelines(dir, "res://", files)
    
    return files

func _scan_for_timelines(dir: DirAccess, base_path: String, files: Array[String]):
    dir.list_dir_begin()
    var file_name = dir.get_next()
    
    while file_name != "":
        var full_path = base_path.path_join(file_name)
        
        if dir.current_is_dir():
            if not file_name.begins_with("."):
                var sub_dir = DirAccess.open(full_path)
                if sub_dir:
                    _scan_for_timelines(sub_dir, full_path + "/", files)
        elif file_name.ends_with("_timeline.tres"):
            files.append(full_path)
        
        file_name = dir.get_next()
    
    dir.list_dir_end()
```

## 常见迁移问题

### 1. 插值类型不匹配

**问题**：V2和V3的插值类型枚举值不同。

**解决方案**：
```gdscript
# 使用转换器中的插值类型转换函数
static func convert_interpolation_type(old_type: int) -> JuicyKeyframe.InterpolationType:
    match old_type:
        0: return JuicyKeyframe.InterpolationType.LINEAR
        1: return JuicyKeyframe.InterpolationType.EASE_IN
        2: return JuicyKeyframe.InterpolationType.EASE_OUT
        3: return JuicyKeyframe.InterpolationType.EASE_IN_OUT
        _: return JuicyKeyframe.InterpolationType.LINEAR
```

### 2. 属性路径变化

**问题**：V3中某些属性路径可能需要调整。

**解决方案**：
```gdscript
# 属性路径映射表
var property_path_mappings = {
    "modulate.r": "modulate:r",
    "modulate.g": "modulate:g",
    "modulate.b": "modulate:b",
    "modulate.a": "modulate:a"
}

func update_property_path(old_path: String) -> String:
    if property_path_mappings.has(old_path):
        return property_path_mappings[old_path]
    return old_path
```

### 3. 事件系统变化

**问题**：V3的事件系统有所变化。

**解决方案**：
```gdscript
# 事件转换函数
static func convert_event(old_event: Resource) -> JuicyEvent:
    var new_event = JuicyEvent.new()
    
    # 转换事件类型
    if old_event.has_method("get_event_type"):
        new_event.event_type = convert_event_type(old_event.get_event_type())
    
    # 转换事件参数
    if old_event.has_method("get_parameters"):
        new_event.parameters = old_event.get_parameters()
    
    return new_event
```

## 迁移后优化

### 1. 利用新功能

迁移完成后，可以考虑使用Timeline系统的新功能：

```gdscript
# 添加参数映射
func add_parameter_mapping(timeline: JuicyTimelineResource):
    for track in timeline.tracks:
        if track is JuicyPropertyTrack:
            var prop_track = track as JuicyPropertyTrack
            
            # 添加强度映射
            var intensity_mapping = JuicyParameterMapping.new()
            intensity_mapping.input_parameter = "intensity"
            intensity_mapping.mapping_type = JuicyParameterMapping.MappingType.TRACK_VALUE
            intensity_mapping.target_property = "intensity"
            intensity_mapping.input_range = Vector2(0.0, 1.0)
            intensity_mapping.output_range = Vector2(0.5, 2.0)
            
            prop_track.use_parameter_mapping = true
            prop_track.parameter_mappings.append(intensity_mapping)
```

### 2. 性能优化

```gdscript
# 优化Timeline性能
func optimize_timeline(timeline: JuicyTimelineResource):
    # 启用缓存
    timeline.set_meta("enable_caching", true)
    
    # 优化关键帧
    for track in timeline.tracks:
        if track.keyframes.size() > 20:
            simplify_keyframes(track)
```

### 3. 添加轨道分组

```gdscript
# 添加轨道分组
func organize_tracks(timeline: JuicyTimelineResource):
    var visual_tracks = []
    var audio_tracks = []
    var effect_tracks = []
    
    for track in timeline.tracks:
        if track is JuicyPropertyTrack:
            visual_tracks.append(track)
        elif track is JuicyMethodTrack and track.method_name.contains("play"):
            audio_tracks.append(track)
        else:
            effect_tracks.append(track)
    
    timeline.track_groups = [
        {"name": "Visual", "tracks": visual_tracks, "enabled": true},
        {"name": "Audio", "tracks": audio_tracks, "enabled": true},
        {"name": "Effects", "tracks": effect_tracks, "enabled": true}
    ]
```

## 测试迁移结果

### 1. 功能测试

```gdscript
# 功能测试脚本
extends Node

func test_migrated_timeline(timeline_path: String):
    print("测试Timeline: ", timeline_path)
    
    # 加载Timeline
    var timeline = load(timeline_path)
    if not timeline:
        print("无法加载Timeline")
        return false
    
    # 创建测试目标
    var test_target = create_test_target()
    
    # 播放Timeline
    var context_id = JuicyTimeline.play(timeline, test_target)
    if context_id.is_empty():
        print("Timeline播放失败")
        return false
    
    # 等待播放完成
    await get_tree().create_timer(timeline.duration + 0.5).timeout
    
    # 检查结果
    var state = timeline_driver.get_timeline_state(context_id)
    if state.is_playing:
        print("Timeline未正常停止")
        return false
    
    print("Timeline测试通过")
    return true

func create_test_target() -> Node:
    var target = Node2D.new()
    var sprite = Sprite2D.new()
    sprite.texture = load("res://icon.svg")
    target.add_child(sprite)
    get_tree().current_scene.add_child(target)
    return target
```

### 2. 性能测试

```gdscript
# 性能测试脚本
extends Node

func test_timeline_performance(timeline_path: String):
    var timeline = load(timeline_path)
    if not timeline:
        return
    
    var test_targets = []
    for i in range(10):
        test_targets.append(create_test_target())
    
    # 记录开始时间
    var start_time = Time.get_ticks_msec()
    
    # 同时播放多个Timeline
    var context_ids = []
    for target in test_targets:
        var context_id = JuicyTimeline.play(timeline, target)
        context_ids.append(context_id)
    
    # 等待完成
    await get_tree().create_timer(timeline.duration + 0.5).timeout
    
    # 记录结束时间
    var end_time = Time.get_ticks_msec()
    var duration = end_time - start_time
    
    print("10个Timeline实例播放时间: ", duration, "ms")
    
    # 清理
    for context_id in context_ids:
        JuicyTimeline.stop(context_id)
    
    for target in test_targets:
        target.queue_free()
```

## 回滚计划

如果迁移过程中遇到问题，可以使用以下回滚策略：

### 1. 部分回滚

```gdscript
# 保留V2和V3系统并存
func enable_dual_system():
    # 注册V2系统
    if ClassDB.class_exists("JuicySequence"):
        register_legacy_system()
    
    # 注册V3系统
    register_timeline_system()
```

### 2. 完全回滚

```gdscript
# 回滚到V2系统
func rollback_to_v2():
    # 禁用V3系统
    disable_timeline_system()
    
    # 恢复V2系统
    enable_sequence_system()
    
    # 恢复备份文件
    restore_backup_files()
```

## 总结

从Sequence系统迁移到Timeline系统是一个重要的升级，提供了更强大的功能和更好的性能。通过遵循本指南的步骤，您可以顺利完成迁移：

1. **备份项目**：确保有完整的项目备份
2. **安装V3系统**：验证Timeline系统组件可用
3. **转换资源**：使用提供的转换工具
4. **更新代码**：搜索和替换API引用
5. **验证结果**：确保迁移正确性
6. **优化和测试**：利用新功能并进行全面测试

迁移完成后，您将能够利用Timeline系统的所有新功能，包括参数映射、轨道分组、条件激活等，为您的游戏提供更强大的效果控制能力。