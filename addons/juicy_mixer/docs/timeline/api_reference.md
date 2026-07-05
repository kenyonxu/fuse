# JuicyMixer V3 Timeline系统API参考

## 概述

本文档提供了JuicyMixer V3 Timeline系统的完整API参考，包括所有核心类、方法和属性的详细说明。

## 核心类

### JuicyTimelineResource

Timeline系统的核心资源类，管理轨道和播放配置。

#### 属性

| 属性名 | 类型 | 默认值 | 描述 |
|--------|------|--------|------|
| `timeline_name` | `String` | `""` | Timeline的名称 |
| `duration` | `float` | `1.0` | Timeline的总持续时间（秒） |
| `loop` | `bool` | `false` | 是否循环播放 |
| `auto_play` | `bool` | `false` | 是否自动播放 |
| `tracks` | `Array[JuicyTrack]` | `[]` | 轨道列表 |
| `track_groups` | `Array[Dictionary]` | `[]` | 轨道分组 |
| `parameter_mappings` | `Array[JuicyParameterMapping]` | `[]` | 参数映射列表 |

#### 方法

##### `func add_track(track: JuicyTrack) -> void`

添加轨道到Timeline。

**参数：**
- `track`: 要添加的轨道对象

**示例：**
```gdscript
var timeline = JuicyTimelineResource.new()
var track = JuicyPropertyTrack.new()
timeline.add_track(track)
```

##### `func remove_track(track: JuicyTrack) -> bool`

从Timeline中移除轨道。

**参数：**
- `track`: 要移除的轨道对象

**返回值：**
- `bool`: 成功移除返回`true`，否则返回`false`

##### `func get_track_by_name(name: String) -> JuicyTrack`

根据名称查找轨道。

**参数：**
- `name`: 轨道名称

**返回值：**
- `JuicyTrack`: 找到的轨道，未找到返回`null`

##### `func get_tracks_at_time(time: float) -> Array[JuicyTrack]`

获取指定时间点的活跃轨道。

**参数：**
- `time`: 时间点（秒）

**返回值：**
- `Array[JuicyTrack]`: 活跃轨道列表

##### `func validate() -> Dictionary`

验证Timeline配置。

**返回值：**
- `Dictionary`: 包含验证结果的字典
  - `valid`: `bool` - 是否有效
  - `issues`: `Array[String]` - 问题列表
  - `warnings`: `Array[String]` - 警告列表

---

### JuicyTrack

所有轨道类型的基类，定义轨道的通用行为。

#### 属性

| 属性名 | 类型 | 默认值 | 描述 |
|--------|------|--------|------|
| `track_name` | `String` | `""` | 轨道名称 |
| `enabled` | `bool` | `true` | 是否启用轨道 |
| `start_time` | `float` | `0.0` | 轨道开始时间 |
| `duration` | `float` | `1.0` | 轨道持续时间 |
| `weight` | `float` | `1.0` | 轨道权重 |
| `loop` | `bool` | `false` | 是否循环 |
| `keyframes` | `Array[JuicyKeyframe]` | `[]` | 关键帧列表 |
| `use_parameter_mapping` | `bool` | `false` | 是否使用参数映射 |
| `parameter_mappings` | `Array[JuicyParameterMapping]` | `[]` | 参数映射列表 |
| `activation_condition` | `JuicyCondition` | `null` | 激活条件 |

#### 方法

##### `func add_keyframe(keyframe: JuicyKeyframe) -> void`

添加关键帧到轨道。

**参数：**
- `keyframe`: 要添加的关键帧

##### `func remove_keyframe(keyframe: JuicyKeyframe) -> bool`

从轨道中移除关键帧。

**参数：**
- `keyframe`: 要移除的关键帧

**返回值：**
- `bool`: 成功移除返回`true`，否则返回`false`

##### `func get_keyframe_at_time(time: float) -> JuicyKeyframe`

获取指定时间点的关键帧。

**参数：**
- `time`: 时间点（秒）

**返回值：**
- `JuicyKeyframe`: 找到的关键帧，未找到返回`null`

##### `func evaluate_at_time(time: float) -> Variant`

评估轨道在指定时间点的值。

**参数：**
- `time`: 时间点（秒）

**返回值：**
- `Variant`: 评估结果

##### `func is_active_at_time(time: float) -> bool`

检查轨道在指定时间点是否活跃。

**参数：**
- `time`: 时间点（秒）

**返回值：**
- `bool`: 活跃返回`true`，否则返回`false`

---

### JuicyKeyframe

定义时间轴上的关键点。

#### 属性

| 属性名 | 类型 | 默认值 | 描述 |
|--------|------|--------|------|
| `time` | `float` | `0.0` | 关键帧时间位置 |
| `value` | `Variant` | `null` | 关键帧值 |
| `interpolation_type` | `InterpolationType` | `LINEAR` | 插值类型 |
| `custom_curve` | `Curve` | `null` | 自定义插值曲线 |
| `ease_in` | `float` | `0.0` | 缓入参数 |
| `ease_out` | `float` | `0.0` | 缓出参数 |

#### 插值类型枚举

```gdscript
enum InterpolationType {
    LINEAR,         # 线性插值
    EASE_IN,        # 缓入
    EASE_OUT,       # 缓出
    EASE_IN_OUT,    # 缓入缓出
    CUBIC_SPLINE,   # 三次样条
    DISCRETE,       # 离散（无插值）
    CUSTOM          # 自定义曲线
}
```

---

### JuicyPropertyTrack

属性轨道，用于控制目标节点的属性值变化。

#### 属性

| 属性名 | 类型 | 默认值 | 描述 |
|--------|------|--------|------|
| `target_node_path` | `NodePath` | `NodePath("")` | 目标节点路径 |
| `property_path` | `String` | `""` | 属性路径 |
| `property_type` | `Variant.Type` | `TYPE_NIL` | 属性类型 |
| `default_value` | `Variant` | `null` | 默认值 |

#### 方法

##### `func set_target(node_path: NodePath) -> void`

设置目标节点。

**参数：**
- `node_path`: 目标节点路径

##### `func set_property(property: String) -> void`

设置目标属性。

**参数：**
- `property`: 属性名称

##### `func get_property_value_at_time(time: float) -> Variant`

获取指定时间点的属性值。

**参数：**
- `time`: 时间点（秒）

**返回值：**
- `Variant`: 属性值

---

### JuicyFeedbackTrack

反馈轨道，用于在特定时间点触发JuicyMixer反馈效果。

#### 属性

| 属性名 | 类型 | 默认值 | 描述 |
|--------|------|--------|------|
| `resource` | `JuicyFeedbackResource` | `null` | 反馈资源 |
| `trigger_mode` | `TriggerMode` | `ON_KEYFRAME` | 触发模式 |
| `trigger_value` | `Variant` | `true` | 触发值 |

#### 触发模式枚举

```gdscript
enum TriggerMode {
    ON_KEYFRAME,    # 在关键帧触发
    ON_VALUE_TRUE,  # 当值为true时触发
    ON_VALUE_FALSE, # 当值为false时触发
    ON_CHANGE       # 值变化时触发
}
```

#### 方法

##### `func set_feedback_resource(resource: JuicyFeedbackResource) -> void`

设置反馈资源。

**参数：**
- `resource`: 反馈资源对象

##### `func trigger_feedback(context: JuicyContext) -> void`

触发反馈效果。

**参数：**
- `context`: JuicyMixer上下文

---

### JuicyMethodTrack

方法轨道，用于在特定时间点调用目标节点的方法。

#### 属性

| 属性名 | 类型 | 默认值 | 描述 |
|--------|------|--------|------|
| `target_node_path` | `NodePath` | `NodePath("")` | 目标节点路径 |
| `method_name` | `String` | `""` | 方法名称 |
| `args` | `Array[Variant]` | `[]` | 方法参数 |
| `call_mode` | `CallMode` | `ON_KEYFRAME` | 调用模式 |

#### 调用模式枚举

```gdscript
enum CallMode {
    ON_KEYFRAME,    # 在关键帧调用
    ON_VALUE_TRUE,  # 当值为true时调用
    ON_VALUE_FALSE, # 当值为false时调用
    ON_CHANGE       # 值变化时调用
}
```

#### 方法

##### `func set_target_method(node_path: NodePath, method: String) -> void`

设置目标方法。

**参数：**
- `node_path`: 目标节点路径
- `method`: 方法名称

##### `func set_arguments(args: Array[Variant]) -> void`

设置方法参数。

**参数：**
- `args`: 参数数组

##### `func call_method(context: JuicyContext) -> Variant`

调用方法。

**参数：**
- `context`: JuicyMixer上下文

**返回值：**
- `Variant`: 方法返回值

---

### JuicyEventTrack

事件轨道，用于在特定时间点触发JuicyMixer事件。

#### 属性

| 属性名 | 类型 | 默认值 | 描述 |
|--------|------|--------|------|
| `juicy_event` | `JuicyEvent` | `null` | JuicyMixer事件 |
| `event_mode` | `EventMode` | `ON_KEYFRAME` | 事件模式 |
| `event_parameters` | `Dictionary` | `{}` | 事件参数 |

#### 事件模式枚举

```gdscript
enum EventMode {
    ON_KEYFRAME,    # 在关键帧触发
    ON_VALUE_TRUE,  # 当值为true时触发
    ON_VALUE_FALSE, # 当值为false时触发
    ON_CHANGE       # 值变化时触发
}
```

#### 方法

##### `func set_event(event: JuicyEvent) -> void`

设置事件。

**参数：**
- `event`: JuicyMixer事件对象

##### `func set_event_parameters(params: Dictionary) -> void`

设置事件参数。

**参数：**
- `params`: 参数字典

##### `func trigger_event(context: JuicyContext) -> void`

触发事件。

**参数：**
- `context`: JuicyMixer上下文

---

### JuicyTimelineDriver

Timeline驱动器，负责Timeline的播放和控制。

#### 属性

| 属性名 | 类型 | 默认值 | 描述 |
|--------|------|--------|------|
| `enable_debug` | `bool` | `false` | 是否启用调试 |
| `debug_level` | `DebugLevel` | `BASIC` | 调试级别 |
| `enable_caching` | `bool` | `true` | 是否启用缓存 |
| `enable_visualization` | `bool` | `false` | 是否启用可视化 |

#### 调试级别枚举

```gdscript
enum DebugLevel {
    BASIC,      # 基本调试信息
    VERBOSE,    # 详细调试信息
    TRACE       # 跟踪级别调试信息
}
```

#### 方法

##### `func play(timeline: JuicyTimelineResource, target: Node, owner: Node = null) -> String`

播放Timeline。

**参数：**
- `timeline`: Timeline资源
- `target`: 目标节点
- `owner`: 所有者节点（可选）

**返回值：**
- `String`: 上下文ID

##### `func pause(context_id: String) -> bool`

暂停Timeline播放。

**参数：**
- `context_id`: 上下文ID

**返回值：**
- `bool`: 成功暂停返回`true`，否则返回`false`

##### `func resume(context_id: String) -> bool`

恢复Timeline播放。

**参数：**
- `context_id`: 上下文ID

**返回值：**
- `bool`: 成功恢复返回`true`，否则返回`false`

##### `func stop(context_id: String) -> bool`

停止Timeline播放。

**参数：**
- `context_id`: 上下文ID

**返回值：**
- `bool`: 成功停止返回`true`，否则返回`false`

##### `func seek(context_id: String, time: float) -> bool`

跳转到指定时间。

**参数：**
- `context_id`: 上下文ID
- `time`: 目标时间（秒）

**返回值：**
- `bool`: 成功跳转返回`true`，否则返回`false`

##### `func get_context(context_id: String) -> JuicyContext`

获取Timeline上下文。

**参数：**
- `context_id`: 上下文ID

**返回值：**
- `JuicyContext`: 上下文对象，未找到返回`null`

##### `func get_timeline_state(context_id: String) -> Dictionary`

获取Timeline状态。

**参数：**
- `context_id`: 上下文ID

**返回值：**
- `Dictionary`: 状态信息
  - `current_time`: `float` - 当前时间
  - `is_playing`: `bool` - 是否正在播放
  - `is_paused`: `bool` - 是否已暂停
  - `active_tracks`: `Array[String]` - 活跃轨道名称列表

##### `func get_performance_stats() -> Dictionary`

获取性能统计信息。

**返回值：**
- `Dictionary`: 性能统计
  - `average_frame_time`: `float` - 平均帧时间
  - `memory_usage`: `int` - 内存使用量
  - `active_timelines`: `int` - 活跃Timeline数量
  - `total_tracks_processed`: `int` - 处理的轨道总数

##### `func preload_timeline(timeline: JuicyTimelineResource) -> void`

预加载Timeline资源。

**参数：**
- `timeline`: Timeline资源

##### `func unload_timeline(timeline: JuicyTimelineResource) -> void`

卸载Timeline资源。

**参数：**
- `timeline`: Timeline资源

---

## 静态API方法

### JuicyTimeline

全局Timeline API入口点。

#### 方法

##### `static func play(timeline: JuicyTimelineResource, target: Node, owner: Node = null) -> String`

播放Timeline的静态便捷方法。

**参数：**
- `timeline`: Timeline资源
- `target`: 目标节点
- `owner`: 所有者节点（可选）

**返回值：**
- `String`: 上下文ID

##### `static func stop(context_id: String) -> bool`

停止Timeline播放的静态便捷方法。

**参数：**
- `context_id`: 上下文ID

**返回值：**
- `bool`: 成功停止返回`true`，否则返回`false`

##### `static func pause(context_id: String) -> bool`

暂停Timeline播放的静态便捷方法。

**参数：**
- `context_id`: 上下文ID

**返回值：**
- `bool`: 成功暂停返回`true`，否则返回`false`

##### `static func resume(context_id: String) -> bool`

恢复Timeline播放的静态便捷方法。

**参数：**
- `context_id`: 上下文ID

**返回值：**
- `bool`: 成功恢复返回`true`，否则返回`false`

##### `static func seek(context_id: String, time: float) -> bool`

跳转到指定时间的静态便捷方法。

**参数：**
- `context_id`: 上下文ID
- `time`: 目标时间（秒）

**返回值：**
- `bool`: 成功跳转返回`true`，否则返回`false`

---

## 信号

### JuicyTimelineResource

| 信号名 | 参数 | 描述 |
|--------|------|------|
| `timeline_started` | `context_id: String` | Timeline开始播放时触发 |
| `timeline_paused` | `context_id: String` | Timeline暂停时触发 |
| `timeline_resumed` | `context_id: String` | Timeline恢复时触发 |
| `timeline_stopped` | `context_id: String` | Timeline停止时触发 |
| `timeline_completed` | `context_id: String` | Timeline完成时触发 |
| `track_started` | `track_name: String, context_id: String` | 轨道开始时触发 |
| `track_completed` | `track_name: String, context_id: String` | 轨道完成时触发 |

### JuicyTrack

| 信号名 | 参数 | 描述 |
|--------|------|------|
| `keyframe_reached` | `keyframe: JuicyKeyframe, time: float` | 到达关键帧时触发 |
| `track_activated` | `time: float` | 轨道激活时触发 |
| `track_deactivated` | `time: float` | 轨道停用时触发 |

---

## 常量

### 插值类型

```gdscript
const INTERPOLATION_LINEAR = 0
const INTERPOLATION_EASE_IN = 1
const INTERPOLATION_EASE_OUT = 2
const INTERPOLATION_EASE_IN_OUT = 3
const INTERPOLATION_CUBIC_SPLINE = 4
const INTERPOLATION_DISCRETE = 5
const INTERPOLATION_CUSTOM = 6
```

### 触发模式

```gdscript
const TRIGGER_ON_KEYFRAME = 0
const TRIGGER_ON_VALUE_TRUE = 1
const TRIGGER_ON_VALUE_FALSE = 2
const TRIGGER_ON_CHANGE = 3
```

### 调试级别

```gdscript
const DEBUG_BASIC = 0
const DEBUG_VERBOSE = 1
const DEBUG_TRACE = 2
```

---

## 错误代码

| 错误代码 | 描述 |
|----------|------|
| `OK` | 操作成功 |
| `ERR_INVALID_PARAMETER` | 无效参数 |
| `ERR_DOES_NOT_EXIST` | 资源不存在 |
| `ERR_ALREADY_EXISTS` | 资源已存在 |
| `ERR_INVALID_DATA` | 无效数据 |
| `ERR_OUT_OF_MEMORY` | 内存不足 |
| `ERR_FILE_NOT_FOUND` | 文件未找到 |
| `ERR_FILE_BAD_DRIVE` | 驱动器错误 |
| `ERR_FILE_BAD_PATH` | 路径错误 |
| `ERR_ALREADY_IN_USE` | 资源已被使用 |

---

## 性能考虑

### 内存管理

- Timeline资源使用引用计数管理
- 关键帧数据在内部进行优化存储
- 使用对象池减少内存分配

### 执行优化

- 轨道按时间范围进行预筛选
- 关键帧查找使用二分搜索
- 批量处理属性更新

### 缓存策略

- 插值结果自动缓存
- 轨道状态信息缓存
- 参数映射结果缓存

---

## 扩展接口

### 自定义轨道类型

```gdscript
extends JuicyTrack
class_name CustomTrack

func _init():
    track_name = "CustomTrack"

func evaluate_at_time(time: float) -> Variant:
    # 实现自定义评估逻辑
    return custom_value

func process_at_time(time: float, context: JuicyContext) -> void:
    # 实现自定义处理逻辑
    pass
```

### 自定义插值器

```gdscript
extends Resource
class_name CustomInterpolator

static func interpolate(from: Variant, to: Variant, t: float, data: Dictionary) -> Variant:
    # 实现自定义插值逻辑
    return from + (to - from) * t
```

---

## 版本历史

### v3.0.0
- 初始版本
- 基本Timeline功能
- 四种轨道类型支持
- 参数映射集成
- 性能优化

### v3.1.0
- 添加轨道分组功能
- 改进插值算法
- 增强调试功能
- 性能优化

### v3.2.0
- 添加可视化支持
- 改进缓存机制
- 增强错误处理
- 扩展API接口