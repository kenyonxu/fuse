# ChannelInterruptionConfig API文档

## 概述

[`ChannelInterruptionConfig`](../../resources/channel_interruption_config.gd:6) 是通道中断配置资源，用于配置通道级中断行为，管理中断策略参数，提供可编辑的配置选项，支持通道特定的优先级。

## 类定义

```gdscript
class_name ChannelInterruptionConfig
extends Resource
```

## 属性

### 基础配置

| 属性名 | 类型 | 默认值 | 描述 |
|--------|------|--------|------|
| [`channel_name`](../../resources/channel_interruption_config.gd:10) | `String` | `""` | 通道名称 |
| [`default_policy`](../../resources/channel_interruption_config.gd:11) | `JuicyMixerEnms.InterruptionPolicy` | `STACK` | 默认中断策略 |
| [`priority`](../../resources/channel_interruption_config.gd:12) | `int` | `0` | 通道优先级 |
| [`max_queue_size`](../../resources/channel_interruption_config.gd:13) | `int` | `10` | 最大队列大小 |
| [`transition_duration`](../../resources/channel_interruption_config.gd:14) | `float` | `0.2` | 过渡持续时间（秒） |
| [`allow_preemption`](../../resources/channel_interruption_config.gd:15) | `bool` | `true` | 是否允许抢占 |

### 高级配置

| 属性名 | 类型 | 默认值 | 描述 |
|--------|------|--------|------|
| [`enable_priority_queue`](../../resources/channel_interruption_config.gd:18) | `bool` | `true` | 启用优先级队列 |
| [`enable_interruption_history`](../../resources/channel_interruption_config.gd:19) | `bool` | `true` | 启用中断历史 |
| [`max_history_size`](../../resources/channel_interruption_config.gd:20) | `int` | `100` | 最大历史记录数 |
| [`auto_cleanup_threshold`](../../resources/channel_interruption_config.gd:21) | `int` | `50` | 队列大小超过此值时自动清理 |

## 构造函数

### `_init()`

创建新的通道中断配置实例，并设置默认值。

**示例:**
```gdscript
# 创建配置
var config = ChannelInterruptionConfig.new()
print("默认通道名: ", config.channel_name)  # 输出: "default"
```

## 策略配置方法

### `set_policy(policy: JuicyMixerEnms.InterruptionPolicy) -> void`

设置默认中断策略。

**参数:**
- `policy` (JuicyMixerEnms.InterruptionPolicy): 中断策略

**示例:**
```gdscript
config.set_policy(JuicyMixerEnms.InterruptionPolicy.PRIORITY_OVERRIDE)
```

### `get_policy() -> JuicyMixerEnms.InterruptionPolicy`

获取默认中断策略。

**返回值:**
- `JuicyMixerEnms.InterruptionPolicy`: 中断策略

**示例:**
```gdscript
var policy = config.get_policy()
print("当前策略: ", JuicyMixerEnms.get_interruption_policy_name(policy))
```

### `set_channel_priority(prio: int) -> void`

设置通道优先级。

**参数:**
- `prio` (int): 优先级数值

**示例:**
```gdscript
config.set_channel_priority(10)
```

### `get_channel_priority() -> int`

获取通道优先级。

**返回值:**
- `int`: 优先级数值

**示例:**
```gdscript
var priority = config.get_channel_priority()
print("通道优先级: ", priority)
```

### `set_max_queue_size(size: int) -> void`

设置最大队列大小。

**参数:**
- `size` (int): 队列大小

**示例:**
```gdscript
config.set_max_queue_size(20)
```

### `get_max_queue_size() -> int`

获取最大队列大小。

**返回值:**
- `int`: 队列大小

**示例:**
```gdscript
var size = config.get_max_queue_size()
print("最大队列大小: ", size)
```

### `set_transition_duration(duration: float) -> void`

设置过渡持续时间。

**参数:**
- `duration` (float): 持续时间（秒）

**示例:**
```gdscript
config.set_transition_duration(0.5)
```

### `get_transition_duration() -> float`

获取过渡持续时间。

**返回值:**
- `float`: 持续时间（秒）

**示例:**
```gdscript
var duration = config.get_transition_duration()
print("过渡持续时间: ", duration, " 秒")
```

### `set_preemption_allowed(allowed: bool) -> void`

设置是否允许抢占。

**参数:**
- `allowed` (bool): 是否允许

**示例:**
```gdscript
config.set_preemption_allowed(false)
```

### `is_preemption_allowed() -> bool`

检查是否允许抢占。

**返回值:**
- `bool`: 是否允许

**示例:**
```gdscript
if config.is_preemption_allowed():
    print("允许抢占")
else:
    print("不允许抢占")
```

## 功能开关方法

### `enable_feature(feature: String, enabled: bool) -> void`

启用/禁用特定功能。

**参数:**
- `feature` (String): 功能名称
  - `"priority_queue"`: 优先级队列
  - `"interruption_history"`: 中断历史
  - `"auto_cleanup"`: 自动清理
- `enabled` (bool): 是否启用

**示例:**
```gdscript
config.enable_feature("priority_queue", true)
config.enable_feature("interruption_history", false)
config.enable_feature("auto_cleanup", true)
```

### `is_feature_enabled(feature: String) -> bool`

检查特定功能是否启用。

**参数:**
- `feature` (String): 功能名称

**返回值:**
- `bool`: 是否启用

**示例:**
```gdscript
if config.is_feature_enabled("priority_queue"):
    print("优先级队列已启用")

if config.is_feature_enabled("auto_cleanup"):
    print("自动清理已启用")
```

## 配置验证

### `validate_config() -> Dictionary`

验证配置有效性。

**返回值:**
- `Dictionary`: 验证结果字典，包含：
  - `valid` (bool): 是否有效
  - `issues` (Array[String]): 错误信息列表

**示例:**
```gdscript
var result = config.validate_config()
if result.valid:
    print("配置有效")
else:
    print("配置无效: ", result.issues)
```

## 资源管理

### `duplicate(subresources: bool = false) -> Resource`

创建配置的副本。

**参数:**
- `subresources` (bool, 可选): 是否复制子资源

**返回值:**
- `Resource`: 新的配置实例

**示例:**
```gdscript
var new_config = config.duplicate()
new_config.channel_name = "ui_effects"
```

## 编辑器支持

### `_get_property_list() -> Array`

获取自定义属性列表，用于编辑器显示。

**返回值:**
- `Array`: 属性列表

此方法主要用于Godot编辑器，自定义属性分组显示。

### `_to_string() -> String`

获取字符串表示。

**返回值:**
- `String`: 配置字符串

**示例:**
```gdscript
print(config._to_string())
# 输出: ChannelInterruptionConfig[channel=default, policy=stack, priority=0]
```

## 配置序列化

### `get_config_dict() -> Dictionary`

获取配置字典，用于序列化。

**返回值:**
- `Dictionary`: 配置字典

**示例:**
```gdscript
var config_dict = config.get_config_dict()
print("配置字典: ", config_dict)
```

### `load_from_dict(config_dict: Dictionary) -> bool`

从配置字典加载。

**参数:**
- `config_dict` (Dictionary): 配置字典

**返回值:**
- `bool`: 是否成功加载

**示例:**
```gdscript
var config_data = {
    "channel_name": "ui_effects",
    "default_policy": "priority_override",
    "priority": 10,
    "max_queue_size": 20
}
var success = config.load_from_dict(config_data)
if success:
    print("配置加载成功")
```

### `serialize_resource() -> Dictionary`

序列化资源配置。

**返回值:**
- `Dictionary`: 序列化后的配置字典

**示例:**
```gdscript
var serialized = config.serialize_resource()
print("序列化数据: ", serialized)
```

### `deserialize_resource(data: Dictionary) -> bool`

从序列化数据恢复资源配置。

**参数:**
- `data` (Dictionary): 序列化数据

**返回值:**
- `bool`: 是否成功恢复

**示例:**
```gdscript
var success = config.deserialize_resource(serialized_data)
if success:
    print("资源恢复成功")
```

### `validate_serialization_data(data: Dictionary) -> Dictionary`

验证序列化数据的有效性。

**参数:**
- `data` (Dictionary): 要验证的序列化数据

**返回值:**
- `Dictionary`: 验证结果字典 {valid: bool, issues: Array[String]}

**示例:**
```gdscript
var result = config.validate_serialization_data(data)
if result.valid:
    print("序列化数据有效")
else:
    print("序列化数据无效: ", result.issues)
```

## 使用示例

### 基本配置

```gdscript
# 创建配置
var config = ChannelInterruptionConfig.new()
config.channel_name = "ui_effects"
config.set_policy(JuicyMixerEnms.InterruptionPolicy.PRIORITY_OVERRIDE)
config.set_channel_priority(10)
config.set_max_queue_size(20)
config.set_transition_duration(0.3)

# 验证配置
var validation = config.validate_config()
if not validation.valid:
    print("配置错误: ", validation.issues)

# 应用配置
JuicyMixer.set_channel_interruption_config("ui_effects", config)
```

### 高级配置

```gdscript
# 创建高级配置
var config = ChannelInterruptionConfig.new()
config.channel_name = "combat_effects"

# 设置基础参数
config.set_policy(JuicyMixerEnms.InterruptionPolicy.PRIORITY_STACK)
config.set_channel_priority(15)
config.set_max_queue_size(30)
config.set_transition_duration(0.1)

# 配置高级功能
config.enable_feature("priority_queue", true)
config.enable_feature("interruption_history", true)
config.enable_feature("auto_cleanup", true)

# 设置历史记录大小
config.max_history_size = 200
config.auto_cleanup_threshold = 100

# 应用配置
JuicyMixer.set_channel_interruption_config("combat_effects", config)
```

### 配置序列化和恢复

```gdscript
# 创建配置
var config = ChannelInterruptionConfig.new()
config.channel_name = "audio_effects"
config.set_policy(JuicyMixerEnms.InterruptionPolicy.FADE_OUT_FADE_IN)
config.set_channel_priority(5)

# 序列化配置
var serialized = config.serialize_resource()

# 保存到文件
var file = FileAccess.open("user://channel_config.json", FileAccess.WRITE)
file.store_string(JSON.stringify(serialized))
file.close()

# 从文件加载
var load_file = FileAccess.open("user://channel_config.json", FileAccess.READ)
var json_string = load_file.get_as_text()
load_file.close()

var json = JSON.new()
var parse_result = json.parse(json_string)
if parse_result == OK:
    var new_config = ChannelInterruptionConfig.new()
    var success = new_config.deserialize_resource(json.data)
    if success:
        print("配置恢复成功")
```

### 配置验证和错误处理

```gdscript
func setup_channel_config(channel_name: String, policy: String, priority: int) -> bool:
    var config = ChannelInterruptionConfig.new()
    config.channel_name = channel_name
    
    # 设置策略
    var policy_enum = JuicyMixerEnms.get_interruption_policy_from_name(policy)
    config.set_policy(policy_enum)
    
    # 设置优先级
    config.set_channel_priority(priority)
    
    # 验证配置
    var validation = config.validate_config()
    if not validation.valid:
        print("配置验证失败: ", validation.issues)
        return false
    
    # 应用配置
    JuicyMixer.set_channel_interruption_config(channel_name, config)
    print("通道配置设置成功: ", channel_name)
    return true

# 使用示例
setup_channel_config("ui_effects", "priority_override", 10)
setup_channel_config("combat_effects", "priority_stack", 15)
```

## 最佳实践

1. **通道命名**: 使用描述性的通道名称，如"ui_effects"、"combat_effects"、"audio_effects"
2. **优先级设置**: 为不同类型的通道设置合理的优先级，确保重要效果能够正确中断
3. **队列大小**: 根据游戏需求设置合适的队列大小，避免内存浪费
4. **过渡时间**: 根据效果类型设置合适的过渡时间，保证视觉流畅性
5. **功能开关**: 根据性能需求启用或禁用高级功能

## 注意事项

1. **资源类型**: 此类继承自Resource，可以作为资源文件保存
2. **线程安全**: 配置修改不是线程安全的，应在主线程中进行
3. **性能考虑**: 启用中断历史会增加内存使用，根据需求调整历史记录大小
4. **验证**: 应用配置前建议先验证配置有效性

## 相关类

- [`JuicyInterruptionManager`](JuicyInterruptionManager.md) - 中断管理器
- [`InterruptionState`](InterruptionState.md) - 中断状态
- [`JuicyMixerEnms.InterruptionPolicy`](JuicyMixerEnums.md) - 中断策略枚举