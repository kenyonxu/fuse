# JuicyTimeline 实施指南

## 快速开始

### 1. 文件结构

创建以下文件结构来实现JuicyTimeline系统：

```
addons/juicy_mixer/
├── resources/
│   └── juicy_timeline_resource.gd
├── drivers/
│   └── juicy_timeline_driver.gd
├── tracks/
│   ├── juicy_track.gd
│   ├── juicy_property_track.gd
│   ├── juicy_feedback_track.gd
│   ├── juicy_method_track.gd
│   ├── juicy_event_track.gd
│   └── juicy_keyframe.gd
├── editor/
│   ├── juicy_timeline_plugin.gd
│   ├── timeline_panel.tscn
│   ├── timeline_panel.gd
│   └── timeline_canvas.gd
└── docs/
    ├── juicy_timeline_implementation_plan.md
    └── juicy_timeline_summary.md
```

### 2. 核心实现步骤

#### 步骤1：创建轨道基类

```gdscript
# tracks/juicy_track.gd
@tool
class_name JuicyTrack
extends Resource

@export var enabled: bool = true
@export var track_name: String = "Track"
@export var track_color: Color = Color.WHITE
@export var muted: bool = false
```

#### 步骤2：实现具体轨道类型

```gdscript
# tracks/juicy_property_track.gd
@tool
class_name JuicyPropertyTrack
extends JuicyTrack

@export var property_path: String      # 属性名 (e.g., "scale", "modulate:a")
@export var animation_curve: Curve     # 值变化曲线 (0-1)
@export var value_range: Vector2       # 映射范围 (Min, Max)
@export var relative: bool = true      # 是否是相对值(Additive)
@export var blend_mode: int = 1        # 0: Override, 1: Additive
@export var keyframes: Array[JuicyKeyframe] = []  # 关键帧数据

# 高级属性
@export var use_absolute_time: bool = false  # 使用绝对时间而非相对时间
@export var time_offset: float = 0.0         # 时间偏移
@export var time_scale: float = 1.0         # 时间缩放

# 参数映射系统 - 轨道级别的参数绑定
@export var use_parameter_mapping: bool = false  # 参数映射开关，默认关闭
@export var parameter_mappings: Array[JuicyParameterMapping] = []

func get_track_type() -> String:
    return "Property"

func validate_track() -> String:
    if property_path.is_empty():
        return "Property path cannot be empty"
    
    # 验证参数映射
    for mapping in parameter_mappings:
        var error = mapping.validate_mapping()
        if not error.is_empty():
            return "Parameter mapping error: " + error
    
    return ""
```

##### 反馈轨道

```gdscript
# tracks/juicy_feedback_track.gd
@tool
class_name JuicyFeedbackTrack
extends JuicyTrack

@export var resource: JuicyFeedbackResource  # 触发的子效果
@export var start_time: float = 0.0
@export var duration: float = -1.0     # -1 表示使用资源自身时长
@export var time_scale_curve: Curve    # 可选：动态控制子效果的时间缩放
@export var condition: JuicyCondition  # 触发条件

# 高级属性
@export var target_path: NodePath  # 可选：指定不同的目标
@export var inherit_time_scale: bool = true  # 是否继承Timeline的时间缩放
@export var interrupt_on_restart: bool = true  # 重新开始时是否中断之前的实例
@export var blend_in_time: float = 0.0  # 淡入时间
@export var blend_out_time: float = 0.0  # 淡出时间

# 参数映射系统 - 轨道级别的参数绑定到子效果
@export var use_parameter_mapping: bool = false  # 参数映射开关，默认关闭
@export var parameter_mappings: Array[JuicyParameterMapping] = []

func get_track_type() -> String:
    return "Feedback"

func validate_track() -> String:
    if not resource:
        return "Feedback resource cannot be null"
    
    # 验证参数映射
    for mapping in parameter_mappings:
        var error = mapping.validate_mapping()
        if not error.is_empty():
            return "Parameter mapping error: " + error
    
    return ""

# 获取实际持续时间
func get_actual_duration() -> float:
    if duration > 0:
        return duration
    elif resource and resource.has_method("get_duration"):
        return resource.get_duration()
    return 1.0

# 获取实际目标 - 支持编辑器和运行时环境
func get_actual_target(base_target: Node) -> Node:
    if target_path.is_empty():
        return base_target
    
    # 在编辑器环境下使用特殊处理
    if Engine.is_editor_hint():
        return _get_target_node_in_editor(base_target)
    else:
        return base_target.get_node(target_path)

# 编辑器环境下的节点获取
func _get_target_node_in_editor(base_target: Node) -> Node:
    var editor_interface = Engine.get_singleton("EditorInterface")
    if not editor_interface:
        return base_target.get_node(target_path)
    
    var edited_root = editor_interface.get_edited_scene_root()
    if not edited_root:
        return base_target.get_node(target_path)
    
    # 尝试直接获取节点
    var target_node = edited_root.get_node_or_null(target_path)
    if target_node:
        return target_node
    
    # 如果直接获取失败，尝试组合绝对路径
    var target_path_str = str(target_path)
    if target_path_str.begins_with("../"):
        var root_path = edited_root.get_path()
        var relative_part = target_path_str.substr(3)  # 移除 "../"
        var absolute_path = str(root_path) + "/" + relative_part
        target_node = edited_root.get_node(absolute_path)
    
    return target_node if target_node else base_target
```

##### 方法轨道

```gdscript
# tracks/juicy_method_track.gd
@tool
class_name JuicyMethodTrack
extends JuicyTrack

@export var trigger_time: float = 0.0
@export var method_name: String
@export var args: Array = []
@export var condition: JuicyCondition  # 触发条件

# 高级属性
@export var target_path: NodePath  # 可选：指定不同的目标
@export var trigger_once: bool = true  # 是否只触发一次
@export var delay: float = 0.0  # 触发后的延迟
@export var repeat_interval: float = -1.0  # 重复间隔，-1表示不重复
@export var max_repeats: int = -1  # 最大重复次数，-1表示无限

func get_track_type() -> String:
    return "Method"

func validate_track() -> String:
    if method_name.is_empty():
        return "Method name cannot be empty"
    return ""

# 获取实际目标 - 支持编辑器和运行时环境
func get_actual_target(base_target: Node) -> Node:
    if target_path.is_empty():
        return base_target
    
    # 在编辑器环境下使用特殊处理
    if Engine.is_editor_hint():
        return _get_target_node_in_editor(base_target)
    else:
        return base_target.get_node(target_path)

# 编辑器环境下的节点获取
func _get_target_node_in_editor(base_target: Node) -> Node:
    var editor_interface = Engine.get_singleton("EditorInterface")
    if not editor_interface:
        return base_target.get_node(target_path)
    
    var edited_root = editor_interface.get_edited_scene_root()
    if not edited_root:
        return base_target.get_node(target_path)
    
    # 尝试直接获取节点
    var target_node = edited_root.get_node_or_null(target_path)
    if target_node:
        return target_node
    
    # 如果直接获取失败，尝试组合绝对路径
    var target_path_str = str(target_path)
    if target_path_str.begins_with("../"):
        var root_path = edited_root.get_path()
        var relative_part = target_path_str.substr(3)  # 移除 "../"
        var absolute_path = str(root_path) + "/" + relative_part
        target_node = edited_root.get_node(absolute_path)
    
    return target_node if target_node else base_target
```

##### 事件轨道

```gdscript
# tracks/juicy_event_track.gd
@tool
class_name JuicyEventTrack
extends JuicyTrack

@export var trigger_time: float = 0.0
@export var juicy_event: JuicyEvent
@export var condition: JuicyCondition  # 触发条件

# 高级属性
@export var event_template: JuicyEvent  # 事件模板，用于动态创建事件
@export var event_data: Dictionary = {}  # 事件数据覆盖
@export var target_path: NodePath  # 可选：指定不同的目标
@export var trigger_once: bool = true  # 是否只触发一次
@export var delay: float = 0.0  # 触发后的延迟

func get_track_type() -> String:
    return "Event"

func validate_track() -> String:
    if not juicy_event and not event_template:
        return "Either juicy_event or event_template must be set"
    return ""

# 创建实际事件
func create_actual_event(base_target: Node) -> JuicyEvent:
    var actual_event: JuicyEvent
    
    if event_template:
        actual_event = event_template.duplicate()
    elif juicy_event:
        actual_event = juicy_event.duplicate()
    else:
        return null
    
    # 设置目标 - 支持编辑器和运行时环境
    var actual_target = base_target
    if not target_path.is_empty():
        if Engine.is_editor_hint():
            actual_target = _get_target_node_in_editor(base_target)
        else:
            actual_target = base_target.get_node(target_path)
    
    # 应用事件数据覆盖
    for key in event_data:
        actual_event.set(key, event_data[key])
    
    return actual_event

# 编辑器环境下的节点获取
func _get_target_node_in_editor(base_target: Node) -> Node:
    var editor_interface = Engine.get_singleton("EditorInterface")
    if not editor_interface:
        return base_target.get_node(target_path)
    
    var edited_root = editor_interface.get_edited_scene_root()
    if not edited_root:
        return base_target.get_node(target_path)
    
    # 尝试直接获取节点
    var target_node = edited_root.get_node_or_null(target_path)
    if target_node:
        return target_node
    
    # 如果直接获取失败，尝试组合绝对路径
    var target_path_str = str(target_path)
    if target_path_str.begins_with("../"):
        var root_path = edited_root.get_path()
        var relative_part = target_path_str.substr(3)  # 移除 "../"
        var absolute_path = str(root_path) + "/" + relative_part
        target_node = edited_root.get_node(absolute_path)
    
    return target_node if target_node else base_target
```

#### 步骤3：实现Timeline资源

```gdscript
# resources/juicy_timeline_resource.gd
@tool
class_name JuicyTimelineResource
extends JuicyFeedbackResource

# Timeline主体属性
@export_group("Timeline Settings")
@export var tracks: Array[JuicyTrack] = []
@export var duration: float = 5.0
@export var loop_mode: int = 0 # 0: None, 1: Loop, 2: PingPong
@export var loop_count: int = -1 # -1 = Infinite
@export var auto_play: bool = false

# 参数预设 - 仅用于提供默认值和预设
@export_group("Parameters")
@export var input_parameters: Dictionary = {} # "param_name" -> Default Value

# 参数预设
@export var parameter_presets: Dictionary = {}  # 预设名 -> 参数值字典

# 编辑器支持
@export_group("Editor")
@export var timeline_zoom: float = 100.0  # 像素/秒
@export var snap_enabled: bool = true
@export var snap_step: float = 0.1  # 吸附步长（秒）

func create_drivers() -> Array[JuicyDriver]:
    var driver = JuicyTimelineDriver.new()
    driver.timeline_resource = self
    return [driver]

func get_duration() -> float:
    return duration

# 应用参数预设
func apply_parameter_preset(context: JuicyContext, preset_name: String) -> void:
    if not parameter_presets.has(preset_name):
        return
    
    var preset = parameter_presets[preset_name]
    for param_name in preset:
        context.set_parameter(param_name, preset[param_name])

func validate_config() -> ValidationResult:
    var result = super.validate_config()
    if tracks.is_empty():
        result.warnings.append("Timeline has no tracks.")
    
    # 验证轨道配置
    for i in range(tracks.size()):
        var track = tracks[i]
        var track_error = track.validate_track()
        if not track_error.is_empty():
            result.issues.append("Track %d (%s): %s" % [i, track.track_name, track_error])
    
    return result
```

#### 步骤4：实现Timeline驱动器

```gdscript
# drivers/juicy_timeline_driver.gd
class_name JuicyTimelineDriver
extends JuicyDriver

var timeline_resource: JuicyTimelineResource

func _init():
    driver_name = "JuicyTimelineDriver"

func prepare(context: JuicyContext, delta: float, buffer: JuicyPropertyBuffer) -> void:
    var state = {
        "time": 0.0,
        "active_subs": {},
        "last_time": -0.001,
        "loops": 0
    }
    context.set_driver_data("timeline_state", state)

func process(context: JuicyContext, delta: float, buffer: JuicyPropertyBuffer) -> void:
    var state = context.get_driver_data("timeline_state")
    var prev_time = state.time
    var dt = delta * context.time_scale
    state.time += dt
    
    # 处理所有轨道
    for i in range(timeline_resource.tracks.size()):
        var track = timeline_resource.tracks[i]
        if not track.enabled or track.muted:
            continue
        _process_track(context, track, i, state, prev_time, buffer)
    
    state.last_time = state.time

func _process_track(context: JuicyContext, track: JuicyTrack, track_idx: int,
                   state: Dictionary, prev_time: float, buffer: JuicyPropertyBuffer) -> void:
    if track is JuicyPropertyTrack:
        _process_property_track(context, track, state.time, buffer)
    elif track is JuicyFeedbackTrack:
        _process_feedback_track(context, track, track_idx, state)
    # ... 其他轨道类型处理

# 处理属性轨道
func _process_property_track(context: JuicyContext, track: JuicyPropertyTrack,
                            time: float, buffer: JuicyPropertyBuffer) -> void:
    # 计算采样点 (0.0 - 1.0)
    var t = clamp(time / timeline_resource.duration, 0.0, 1.0)
    
    # 采样曲线
    var curve_val = track.animation_curve.sample(t)
    
    # 映射到数值范围
    var final_val = lerp(track.value_range.x, track.value_range.y, curve_val)
    
    # 应用参数映射
    if track.use_parameter_mapping:
        for mapping in track.parameter_mappings:
            if not mapping.enabled:
                continue
            
            var param_value = context.get_parameter(mapping.input_parameter, 1.0)
            var mapped_value = mapping.apply_mapping(param_value)
            
            # 将映射值应用到最终值
            if mapping.target_property == track.property_path:
                final_val *= mapped_value
    
    # 写入缓冲区
    buffer.add_sample(
        context.target,
        track.property_path,
        final_val,
        track.blend_mode
    )

# 处理反馈轨道
func _process_feedback_track(context: JuicyContext, track: JuicyFeedbackTrack,
                             track_idx: int, state: Dictionary) -> void:
    var current_time = state.time
    var end_time = track.start_time + track.get_actual_duration()
    
    var is_inside_range = current_time >= track.start_time and current_time < end_time
    var sub_id = state.active_subs.get(track_idx)
    
    # A. 触发开始
    if is_inside_range and sub_id == null:
        var actual_target = track.get_actual_target(context.target)
        
        # 创建子上下文
        var sub_context = JuicyContext.create(track.resource, actual_target)
        
        # 应用参数映射到子上下文
        if track.use_parameter_mapping:
            for mapping in track.parameter_mappings:
                if not mapping.enabled:
                    continue
                
                var param_value = context.get_parameter(mapping.input_parameter, 0.0)
                var mapped_value = mapping.apply_mapping(param_value)
                
                # 将参数映射到子效果的属性
                sub_context.set_parameter(mapping.target_property, mapped_value)
        
        # 播放子效果
        var new_id = JuicyMixer.play(track.resource, actual_target, context.owner)
        state.active_subs[track_idx] = new_id
    
    # B. 持续更新
    if is_inside_range and sub_id != null:
        # 动态更新参数
        if track.use_parameter_mapping:
            for mapping in track.parameter_mappings:
                if not mapping.enabled:
                    continue
                
                var param_value = context.get_parameter(mapping.input_parameter, 0.0)
                var mapped_value = mapping.apply_mapping(param_value)
                
                # 更新子上下文参数
                JuicyMixer.set_context_parameter(sub_id, mapping.target_property, mapped_value)
    
    # C. 触发结束
    if not is_inside_range and sub_id != null:
        JuicyMixer.stop(sub_id)
        state.active_subs.erase(track_idx)

func cleanup(context: JuicyContext) -> void:
    var state = context.get_driver_data("timeline_state")
    if state:
        for sub_context_id in state.active_subs.values():
            if sub_context_id:
                JuicyMixer.stop(sub_context_id)
```

### 3. 编辑器集成

#### 步骤5：创建编辑器插件

```gdscript
# editor/juicy_timeline_plugin.gd
@tool
extends EditorPlugin

const TimelinePanel = preload("res://addons/juicy_mixer/editor/timeline_panel.tscn")
var timeline_panel_instance

func _enter_tree():
    timeline_panel_instance = TimelinePanel.instantiate()
    add_control_to_bottom_panel(timeline_panel_instance, "Juicy Timeline")
    _make_visible(false)

func _exit_tree():
    if timeline_panel_instance:
        remove_control_from_bottom_panel(timeline_panel_instance)
        timeline_panel_instance.queue_free()

func _handles(object):
    return object is JuicyTimelineResource

func _edit(object):
    if object is JuicyTimelineResource:
        timeline_panel_instance.set_current_timeline(object)

func _make_visible(visible):
    if timeline_panel_instance:
        timeline_panel_instance.visible = visible
        if visible:
            make_bottom_panel_item_visible(timeline_panel_instance)
```

#### 步骤6：创建时间轴面板

```gdscript
# editor/timeline_panel.gd
extends Control

var current_timeline: JuicyTimelineResource
var zoom_scale: float = 100.0
var playhead_time: float = 0.0

func set_current_timeline(timeline: JuicyTimelineResource):
    current_timeline = timeline
    queue_redraw()

func _draw():
    if not current_timeline:
        return
    
    # 绘制标尺
    _draw_ruler()
    
    # 绘制轨道
    _draw_tracks()
    
    # 绘制播放头
    _draw_playhead()

func _draw_ruler():
    var ruler_height = 20
    draw_rect(Rect2(0, 0, size.x, ruler_height), Color.DARK_GRAY)
    
    var duration = current_timeline.duration
    var step = _get_ruler_step()
    
    for t in range(0, int(duration / step) + 1):
        var x = t * step * zoom_scale
        draw_line(Vector2(x, 0), Vector2(x, ruler_height), Color.WHITE)
        
        if t % 2 == 0:
            var font = get_theme_font("font", "Label")
            draw_string(font, Vector2(x + 5, 15), str(t * step) + "s")

func _draw_tracks():
    var y = 20  # 标尺高度
    var track_height = 30
    
    for i in range(current_timeline.tracks.size()):
        var track = current_timeline.tracks[i]
        
        # 绘制轨道背景
        var track_rect = Rect2(0, y, size.x, track_height)
        var bg_color = Color(0.1, 0.1, 0.1)
        if track.muted:
            bg_color = Color(0.1, 0.05, 0.05)
        draw_rect(track_rect, bg_color)
        
        # 绘制轨道内容
        if track is JuicyPropertyTrack:
            _draw_property_track(track, y, track_height)
        elif track is JuicyFeedbackTrack:
            _draw_feedback_track(track, y, track_height)
        
        y += track_height

func _draw_playhead():
    var x = playhead_time * zoom_scale
    draw_line(Vector2(x, 0), Vector2(x, size.y), Color.RED, 2.0)
```

### 4. 使用示例

#### 基本使用

```gdscript
# 创建时间轴资源
var timeline = JuicyTimelineResource.new()
timeline.duration = 3.0

# 添加属性轨道
var scale_track = JuicyPropertyTrack.new()
scale_track.track_name = "Scale"
scale_track.property_path = "scale"
scale_track.animation_curve = Curve.new()
scale_track.animation_curve.add_point(Vector2(0, 0))
scale_track.animation_curve.add_point(Vector2(0.5, 1))
scale_track.animation_curve.add_point(Vector2(1, 0))
scale_track.value_range = Vector2(1.0, 2.0)
timeline.tracks.append(scale_track)

# 播放时间轴
var context_id = JuicyMixer.play(timeline, player_node)
```

#### 参数映射使用

```gdscript
# 为属性轨道设置参数映射
var scale_track = JuicyPropertyTrack.new()
scale_track.track_name = "Scale"
scale_track.property_path = "scale"
scale_track.animation_curve = Curve.new()
scale_track.animation_curve.add_point(Vector2(0, 0))
scale_track.animation_curve.add_point(Vector2(0.5, 1))
scale_track.animation_curve.add_point(Vector2(1, 0))
scale_track.value_range = Vector2(1.0, 2.0)

# 启用参数映射
scale_track.use_parameter_mapping = true

# 创建强度映射
var intensity_mapping = JuicyParameterMapping.new()
intensity_mapping.input_parameter = "intensity"
intensity_mapping.target_property = "scale"  # 映射到scale属性
intensity_mapping.curve = Curve.new()
intensity_mapping.curve.add_point(Vector2(0, 0.5))  # 0%强度 -> 0.5倍
intensity_mapping.curve.add_point(Vector2(1, 2.0))  # 100%强度 -> 2.0倍

scale_track.parameter_mappings.append(intensity_mapping)
timeline.tracks.append(scale_track)

# 为反馈轨道设置参数映射
var feedback_track = JuicyFeedbackTrack.new()
feedback_track.track_name = "Shake Effect"
feedback_track.resource = shake_resource
feedback_track.start_time = 0.5
feedback_track.use_parameter_mapping = true

# 创建振幅映射
var amplitude_mapping = JuicyParameterMapping.new()
amplitude_mapping.input_parameter = "intensity"
amplitude_mapping.target_property = "amplitude"  # 映射到子效果的amplitude属性
amplitude_mapping.curve = Curve.new()
amplitude_mapping.curve.add_point(Vector2(0, 5.0))   # 0%强度 -> 5.0振幅
amplitude_mapping.curve.add_point(Vector2(1, 20.0))  # 100%强度 -> 20.0振幅

feedback_track.parameter_mappings.append(amplitude_mapping)
timeline.tracks.append(feedback_track)

# 播放时间轴并设置参数
var context_id = JuicyMixer.play(timeline, player_node)
var context = JuicyMixer.get_context(context_id)
context.set_parameter("intensity", 0.8)  # 80%强度，影响所有轨道
```

### 5. 最佳实践

#### 性能优化

1. **避免过多轨道**：合并相似的属性变化
2. **合理使用关键帧**：简单线性变化使用曲线
3. **条件优化**：将最可能失败的条件放在前面

#### 组织结构

1. **按功能分组**：视觉效果、音频效果、逻辑回调
2. **命名规范**：使用清晰的轨道名称
3. **颜色编码**：为不同类型轨道设置不同颜色

#### 调试技巧

1. **轨道静音**：临时禁用某些轨道
2. **参数调试**：通过参数映射实时调整
3. **事件日志**：启用事件系统日志

### 6. 常见问题

#### Q: 如何处理复杂的属性路径？

A: 使用点号分隔的属性路径，如"modulate:a"表示透明度的alpha通道。对于嵌套属性，可以使用"node:property"格式。

#### Q: 如何实现轨道间的依赖关系？

A: 使用条件系统和参数映射。一个轨道的输出可以作为参数影响其他轨道。

#### Q: 如何优化大量轨道的性能？

A: 1) 使用对象池化 2) 批处理属性更新 3) 合并相似的轨道 4) 使用条件禁用不需要的轨道

#### Q: 如何实现时间轴的嵌套？

A: 使用Feedback轨道播放另一个Timeline资源，实现时间轴的嵌套和组合。

### 7. 扩展开发

#### 自定义轨道类型

```gdscript
# 自定义轨道示例
class_name JuicyParticleTrack
extends JuicyTrack

@export var particle_system_path: NodePath  # 粒子系统节点路径
@export var emission_curve: Curve
@export var base_emission: float = 100.0

# 参数映射系统
@export var use_parameter_mapping: bool = false
@export var parameter_mappings: Array[JuicyParameterMapping] = []

func get_track_type() -> String:
    return "Particle"

func validate_track() -> String:
    if particle_system_path.is_empty():
        return "Particle system path cannot be empty"
    
    # 验证参数映射
    for mapping in parameter_mappings:
        var error = mapping.validate_mapping()
        if not error.is_empty():
            return "Parameter mapping error: " + error
    
    return ""

# 获取实际粒子系统 - 支持编辑器和运行时环境
func get_actual_particle_system(base_target: Node) -> GPUParticles2D:
    if particle_system_path.is_empty():
        return null
    
    # 在编辑器环境下使用特殊处理
    if Engine.is_editor_hint():
        return _get_particle_system_in_editor(base_target)
    else:
        return base_target.get_node(particle_system_path) as GPUParticles2D

# 编辑器环境下的节点获取
func _get_particle_system_in_editor(base_target: Node) -> GPUParticles2D:
    var editor_interface = Engine.get_singleton("EditorInterface")
    if not editor_interface:
        return base_target.get_node(particle_system_path) as GPUParticles2D
    
    var edited_root = editor_interface.get_edited_scene_root()
    if not edited_root:
        return base_target.get_node(particle_system_path) as GPUParticles2D
    
    # 尝试直接获取节点
    var particle_system = edited_root.get_node_or_null(particle_system_path) as GPUParticles2D
    if particle_system:
        return particle_system
    
    # 如果直接获取失败，尝试组合绝对路径
    var path_str = str(particle_system_path)
    if path_str.begins_with("../"):
        var root_path = edited_root.get_path()
        var relative_part = path_str.substr(3)  # 移除 "../"
        var absolute_path = str(root_path) + "/" + relative_part
        particle_system = edited_root.get_node(absolute_path) as GPUParticles2D
    
    return particle_system

# 在TimelineDriver中添加处理逻辑
func _process_particle_track(context: JuicyContext, track: JuicyParticleTrack,
                           time: float, buffer: JuicyPropertyBuffer) -> void:
    var particle_system = track.get_actual_particle_system(context.target)
    if not particle_system:
        return
    
    var t = time / timeline_resource.duration
    var emission_rate = track.emission_curve.sample(t) * track.base_emission
    
    # 应用参数映射
    if track.use_parameter_mapping:
        for mapping in track.parameter_mappings:
            if not mapping.enabled:
                continue
            
            var param_value = context.get_parameter(mapping.input_parameter, 1.0)
            var mapped_value = mapping.apply_mapping(param_value)
            
            # 将映射值应用到发射率
            if mapping.target_property == "emission":
                emission_rate *= mapped_value
    
    particle_system.emission = emission_rate
```

#### 自定义事件处理器

```gdscript
class_name JuicyTimelineEventHandler
extends JuicyEventHandler

func _init():
    handler_name = "JuicyTimelineEventHandler"
    supported_events = [JuicyEvent.EventType.CUSTOM_EVENT]

func handle_event(event: JuicyEvent) -> bool:
    if event.event_name == "timeline_marker_reached":
        _handle_timeline_marker(event)
        return true
    return false
```

## 总结

JuicyTimeline系统为JuicyMixer V3提供了强大的时间轴控制能力，通过遵循本指南，开发者可以：

1. 快速实现基本的Timeline功能
2. 根据需求扩展自定义轨道类型
3. 集成编辑器支持，提供可视化编辑体验
4. 利用参数映射实现联觉效果
5. 遵循最佳实践，确保性能和可维护性

通过Timeline系统，游戏开发者可以创建复杂、精确且富有表现力的游戏手感序列，将游戏体验提升到新的高度。