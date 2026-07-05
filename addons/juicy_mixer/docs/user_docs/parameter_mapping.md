# JuicyMixer V3 参数映射系统使用指南

## 概述

JuicyMixer V3 的参数映射系统允许您将外部输入参数动态映射到轨道和效果的属性，实现真正的"联觉"效果。通过参数映射，您可以根据游戏状态、用户输入或其他动态变量实时调整效果参数。

## 核心概念

### JuicyParameterMapping

[`JuicyParameterMapping`](../resources/juicy_parameter_mapping.gd:6) 是参数映射的核心类，支持多种映射类型：

- **COMPOSITE_RESOURCE**: 映射到组合资源中的项（传统模式）
- **TRACK_PROPERTY**: 映射到轨道属性
- **TRACK_TIME**: 映射到轨道时间参数
- **TRACK_VALUE**: 映射到轨道值参数
- **METHOD_ARGUMENT**: 映射到方法参数
- **EVENT_PROPERTY**: 映射到事件属性
- **CUSTOM**: 自定义映射

### 映射类型详解

#### 1. 轨道属性映射 (TRACK_PROPERTY)

用于动态调整轨道的基础属性：

```gdscript
# 创建参数映射
var mapping = JuicyParameterMapping.new()
mapping.input_parameter = "player_health"
mapping.mapping_type = JuicyParameterMapping.MappingType.TRACK_PROPERTY
mapping.target_property = "intensity"
mapping.input_range = Vector2(0.0, 100.0)  # 玩家生命值范围
mapping.output_range = Vector2(0.0, 1.0)     # 映射到0-1范围
mapping.curve = intensity_curve                  # 可选的映射曲线
```

#### 2. 轨道时间映射 (TRACK_TIME)

用于动态调整轨道的时间参数：

```gdscript
var mapping = JuicyParameterMapping.new()
mapping.input_parameter = "game_speed"
mapping.mapping_type = JuicyParameterMapping.MappingType.TRACK_TIME
mapping.target_property = "time_scale"
mapping.input_range = Vector2(0.5, 2.0)  # 游戏速度范围
mapping.output_range = Vector2(0.5, 2.0)  # 时间缩放范围
```

#### 3. 轨道值映射 (TRACK_VALUE)

用于动态调整轨道的输出值：

```gdscript
var mapping = JuicyParameterMapping.new()
mapping.input_parameter = "combo_count"
mapping.mapping_type = JuicyParameterMapping.MappingType.TRACK_VALUE
mapping.target_property = "scale"
mapping.input_range = Vector2(0, 10)      # 连击数范围
mapping.output_range = Vector2(1.0, 2.0)   # 缩放范围
```

#### 4. 方法参数映射 (METHOD_ARGUMENT)

用于动态调整方法调用的参数：

```gdscript
var mapping = JuicyParameterMapping.new()
mapping.input_parameter = "damage_amount"
mapping.mapping_type = JuicyParameterMapping.MappingType.METHOD_ARGUMENT
mapping.target_argument_index = 0  # 第一个参数
mapping.input_range = Vector2(0, 100)
mapping.output_range = Vector2(0, 10)
```

#### 5. 事件属性映射 (EVENT_PROPERTY)

用于动态调整事件的属性：

```gdscript
var mapping = JuicyParameterMapping.new()
mapping.input_parameter = "distance_to_target"
mapping.mapping_type = JuicyParameterMapping.MappingType.EVENT_PROPERTY
mapping.target_property = "volume"
mapping.input_range = Vector2(0, 100)
mapping.output_range = Vector2(0.0, 1.0)
mapping.invert_mapping = true  # 距离越远，音量越小
```

#### 6. 自定义映射 (CUSTOM)

用于实现复杂的自定义逻辑：

```gdscript
var mapping = JuicyParameterMapping.new()
mapping.input_parameter = "custom_input"
mapping.mapping_type = JuicyParameterMapping.MappingType.CUSTOM
mapping.custom_handler = "handle_custom_mapping"
```

## 在不同轨道类型中使用参数映射

### 属性轨道 (JuicyPropertyTrack)

```gdscript
# 创建属性轨道
var property_track = JuicyPropertyTrack.new()
property_track.property_path = "scale"
property_track.use_parameter_mapping = true

# 添加强度映射
var intensity_mapping = JuicyParameterMapping.new()
intensity_mapping.input_parameter = "player_speed"
intensity_mapping.mapping_type = JuicyParameterMapping.MappingType.TRACK_VALUE
intensity_mapping.target_property = "intensity"
intensity_mapping.input_range = Vector2(0, 10)
intensity_mapping.output_range = Vector2(0.5, 2.0)

# 添加时间缩放映射
var time_mapping = JuicyParameterMapping.new()
time_mapping.input_parameter = "slow_motion_factor"
time_mapping.mapping_type = JuicyParameterMapping.MappingType.TRACK_TIME
time_mapping.target_property = "time_scale"

property_track.parameter_mappings = [intensity_mapping, time_mapping]
```

### 反馈轨道 (JuicyFeedbackTrack)

```gdscript
# 创建反馈轨道
var feedback_track = JuicyFeedbackTrack.new()
feedback_track.resource = shake_resource
feedback_track.use_parameter_mapping = true

# 添加强度映射到子效果
var intensity_mapping = JuicyParameterMapping.new()
intensity_mapping.input_parameter = "impact_force"
intensity_mapping.mapping_type = JuicyParameterMapping.MappingType.TRACK_PROPERTY
intensity_mapping.target_property = "intensity"
intensity_mapping.input_range = Vector2(0, 1000)
intensity_mapping.output_range = Vector2(0.0, 1.0)

feedback_track.parameter_mappings = [intensity_mapping]
```

### 方法轨道 (JuicyMethodTrack)

```gdscript
# 创建方法轨道
var method_track = JuicyMethodTrack.new()
method_track.method_name = "play_sound"
method_track.args = ["$impact_sound", 1.0]  # 使用占位符
method_track.use_parameter_mapping = true

# 添加音量参数映射
var volume_mapping = JuicyParameterMapping.new()
volume_mapping.input_parameter = "distance"
volume_mapping.mapping_type = JuicyParameterMapping.MappingType.METHOD_ARGUMENT
volume_mapping.target_argument_index = 1
volume_mapping.input_range = Vector2(0, 50)
volume_mapping.output_range = Vector2(1.0, 0.1)
volume_mapping.invert_mapping = true

method_track.parameter_mappings = [volume_mapping]
```

### 事件轨道 (JuicyEventTrack)

```gdscript
# 创建事件轨道
var event_track = JuicyEventTrack.new()
event_track.juicy_event = sound_event
event_track.use_parameter_mapping = true

# 添加音高映射
var pitch_mapping = JuicyParameterMapping.new()
pitch_mapping.input_parameter = "vehicle_speed"
pitch_mapping.mapping_type = JuicyParameterMapping.MappingType.EVENT_PROPERTY
pitch_mapping.target_property = "pitch"
pitch_mapping.input_range = Vector2(0, 200)
pitch_mapping.output_range = Vector2(0.5, 2.0)

event_track.parameter_mappings = [pitch_mapping]
```

## 高级功能

### 曲线映射

使用曲线可以实现非线性的参数转换：

```gdscript
# 创建S型曲线
var curve = Curve.new()
curve.add_point(Vector2(0, 0))
curve.add_point(Vector2(0.5, 0.2))
curve.add_point(Vector2(1, 1))

var mapping = JuicyParameterMapping.new()
mapping.curve = curve
```

### 输入/输出范围

```gdscript
# 将0-100的范围映射到0.2-1.5的范围
mapping.input_range = Vector2(0, 100)
mapping.output_range = Vector2(0.2, 1.5)
```

### 反转映射

```gdscript
# 输入值越大，输出值越小
mapping.invert_mapping = true
```

### 输出限制

```gdscript
# 限制输出值在指定范围内
mapping.clamp_output = true
mapping.output_range = Vector2(0.0, 1.0)
```

## 自定义处理函数

对于CUSTOM类型的映射，您可以定义自定义处理函数：

```gdscript
# 在轨道类中定义自定义处理函数
func handle_custom_mapping(input_value: float, mapping: JuicyParameterMapping) -> float:
    # 实现自定义逻辑
    var result = input_value * 2.0
    
    # 可以根据映射的配置调整结果
    if mapping.invert_mapping:
        result = 1.0 - result
    
    return result
```

## 性能优化建议

1. **禁用未使用的映射**: 将不需要的映射的`enabled`属性设为`false`
2. **使用简单的映射**: 尽可能使用线性映射而非复杂的曲线
3. **缓存映射结果**: 对于复杂的自定义映射，考虑缓存计算结果
4. **批量更新**: Timeline驱动器会自动批量处理属性更新

## 调试和验证

### 验证映射配置

```gdscript
var error = mapping.validate_mapping()
if not error.is_empty():
    print("映射配置错误: ", error)
```

### 获取调试信息

```gdscript
print(mapping.get_debug_info())
```

### 启用Timeline驱动器调试

```gdscript
timeline_driver.enable_debug(true)
```

## 最佳实践

1. **命名规范**: 使用描述性的参数名称，如`player_health`而非`param1`
2. **范围设置**: 合理设置输入和输出范围，避免意外的极值
3. **文档记录**: 为复杂的自定义映射添加注释说明
4. **测试验证**: 使用测试场景验证参数映射的效果
5. **性能监控**: 监控参数映射对性能的影响

## 示例：完整的联觉效果

```gdscript
# 创建一个根据玩家状态动态调整的Timeline
var timeline = JuicyTimelineResource.new()

# 属性轨道：根据生命值调整屏幕效果
var health_track = JuicyPropertyTrack.new()
health_track.property_path = "modulate:a"
health_track.use_parameter_mapping = true

var health_mapping = JuicyParameterMapping.new()
health_mapping.input_parameter = "player_health"
health_mapping.mapping_type = JuicyParameterMapping.MappingType.TRACK_VALUE
health_mapping.target_property = "intensity"
health_mapping.input_range = Vector2(0, 100)
health_mapping.output_range = Vector2(0.3, 1.0)
health_mapping.curve = health_curve

health_track.parameter_mappings = [health_mapping]

# 反馈轨道：根据速度调整震动强度
var shake_track = JuicyFeedbackTrack.new()
shake_track.resource = shake_resource
shake_track.use_parameter_mapping = true

var speed_mapping = JuicyParameterMapping.new()
speed_mapping.input_parameter = "player_speed"
speed_mapping.mapping_type = JuicyParameterMapping.MappingType.TRACK_PROPERTY
speed_mapping.target_property = "intensity"
speed_mapping.input_range = Vector2(0, 20)
speed_mapping.output_range = Vector2(0.0, 1.0)

shake_track.parameter_mappings = [speed_mapping]

# 事件轨道：根据连击数调整音效
var sound_track = JuicyEventTrack.new()
sound_track.juicy_event = hit_sound_event
sound_track.use_parameter_mapping = true

var combo_mapping = JuicyParameterMapping.new()
combo_mapping.input_parameter = "combo_count"
combo_mapping.mapping_type = JuicyParameterMapping.MappingType.EVENT_PROPERTY
combo_mapping.target_property = "pitch"
combo_mapping.input_range = Vector2(0, 20)
combo_mapping.output_range = Vector2(0.8, 1.5)

sound_track.parameter_mappings = [combo_mapping]

# 添加所有轨道到Timeline
timeline.add_track(health_track)
timeline.add_track(shake_track)
timeline.add_track(sound_track)
```

通过这种方式，您可以创建真正动态和响应式的效果系统，实现游戏状态与视听效果的完美同步。