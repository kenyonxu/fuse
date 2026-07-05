# JuicyFeedbackResource 中断相关API文档

## 概述

[`JuicyFeedbackResource`](../../resources/juicy_feedback_resource.gd:7) 是反馈资源基类，定义反馈效果的配置接口，提供类型安全的配置方法，支持资源序列化和反序列化，作为所有具体资源类型的基类。

## 类定义

```gdscript
@tool
@abstract
class_name JuicyFeedbackResource
extends Resource
```

## 属性

### 基础配置

| 属性名 | 类型 | 默认值 | 描述 |
|--------|------|--------|------|
| [`duration`](../../resources/juicy_feedback_resource.gd:11) | `float` | `1.0` | 效果持续时间（秒） |
| [`channel`](../../resources/juicy_feedback_resource.gd:12) | `String` | `""` | 效果所属通道 |
| [`priority`](../../resources/juicy_feedback_resource.gd:13) | `int` | `0` | 效果优先级 |
| [`time_group`](../../resources/juicy_feedback_resource.gd:14) | `String` | `""` | 时间组标识 |

### 中断策略配置

| 属性名 | 类型 | 默认值 | 描述 |
|--------|------|--------|------|
| [`interruption_policy`](../../resources/juicy_feedback_resource.gd:17) | `JuicyMixerEnms.InterruptionPolicy` | `STACK` | 中断策略 |
| [`interruption_priority`](../../resources/juicy_feedback_resource.gd:18) | `int` | `0` | 中断优先级，用于优先级相关的策略 |
| [`allow_interruption`](../../resources/juicy_feedback_resource.gd:21) | `bool` | `true` | 是否允许被中断 |
| [`can_interrupt_others`](../../resources/juicy_feedback_resource.gd:22) | `bool` | `true` | 是否可以中断其他效果 |
| [`interruption_fade_duration`](../../resources/juicy_feedback_resource.gd:23) | `float` | `0.1` | 中断时的淡入淡出时间 |

## 验证结果类

### ValidationResult

用于存储配置验证结果的内部类。

```gdscript
class ValidationResult:
    var valid: bool = true
    var issues: Array[String] = []
    var warnings: Array[String] = []
```

## 虚拟方法

### `create_drivers() -> Array`

创建驱动器，子类必须实现此方法。

**返回值:**
- `Array`: 驱动器数组

**注意:** 这是一个抽象方法，子类必须实现。

**示例:**
```gdscript
# 在子类中实现
func create_drivers() -> Array:
    var drivers = []
    # 创建具体的驱动器
    drivers.append(JuicyTweenDriver.new())
    drivers.append(JuicyShakeDriver.new())
    return drivers
```

### `validate_config() -> ValidationResult`

验证配置有效性。

**返回值:**
- `ValidationResult`: 验证结果

**示例:**
```gdscript
var result = resource.validate_config()
if result.valid:
    print("配置有效")
else:
    print("配置错误: ", result.issues)
if result.warnings.size() > 0:
    print("警告: ", result.warnings)
```

## 中断策略相关方法

### `get_interruption_policy() -> JuicyMixerEnms.InterruptionPolicy`

获取中断策略。

**返回值:**
- `JuicyMixerEnms.InterruptionPolicy`: 中断策略

**示例:**
```gdscript
var policy = resource.get_interruption_policy()
print("中断策略: ", JuicyMixerEnms.get_interruption_policy_name(policy))
```

### `set_interruption_policy(policy: JuicyMixerEnms.InterruptionPolicy) -> void`

设置中断策略。

**参数:**
- `policy` (JuicyMixerEnms.InterruptionPolicy): 中断策略

**示例:**
```gdscript
resource.set_interruption_policy(JuicyMixerEnms.InterruptionPolicy.PRIORITY_OVERRIDE)
```

### `get_interruption_priority() -> int`

获取中断优先级。

**返回值:**
- `int`: 中断优先级

**示例:**
```gdscript
var priority = resource.get_interruption_priority()
print("中断优先级: ", priority)
```

### `set_interruption_priority(priority: int) -> void`

设置中断优先级。

**参数:**
- `priority` (int): 中断优先级

**示例:**
```gdscript
resource.set_interruption_priority(10)
```

### `can_be_interrupted() -> bool`

检查是否允许被中断。

**返回值:**
- `bool`: 是否允许被中断

**示例:**
```gdscript
if resource.can_be_interrupted():
    print("此效果允许被中断")
else:
    print("此效果不允许被中断")
```

### `can_interrupt() -> bool`

检查是否可以中断其他效果。

**返回值:**
- `bool`: 是否可以中断其他效果

**示例:**
```gdscript
if resource.can_interrupt():
    print("此效果可以中断其他效果")
else:
    print("此效果不能中断其他效果")
```

### `get_fade_duration() -> float`

获取中断淡入淡出时间。

**返回值:**
- `float`: 淡入淡出时间（秒）

**示例:**
```gdscript
var duration = resource.get_fade_duration()
print("淡入淡出时间: ", duration, " 秒")
```

## 资源管理方法

### `get_resource_type() -> String`

获取资源类型名称。

**返回值:**
- `String`: 资源类型名称

**示例:**
```gdscript
var type = resource.get_resource_type()
print("资源类型: ", type)
```

### `get_description() -> String`

获取资源描述。

**返回值:**
- `String`: 资源描述字符串

**示例:**
```gdscript
var desc = resource.get_description()
print("资源描述: ", desc)
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
- `String`: 资源字符串

**示例:**
```gdscript
print(resource._to_string())
# 输出: JuicyTweenResource(duration=1.00, channel='ui', policy=priority_override, priority=10)
```

## 配置序列化

### `get_config_dict() -> Dictionary`

获取配置字典，用于序列化。

**返回值:**
- `Dictionary`: 配置字典

**示例:**
```gdscript
var config_dict = resource.get_config_dict()
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
    "duration": 2.0,
    "channel": "combat_effects",
    "priority": 15,
    "interruption_policy": "priority_override",
    "interruption_priority": 10,
    "allow_interruption": true,
    "can_interrupt_others": true,
    "interruption_fade_duration": 0.2
}
var success = resource.load_from_dict(config_data)
if success:
    print("配置加载成功")
```

## 使用示例

### 基本配置

```gdscript
# 创建反馈资源
var resource = JuicyFeedbackResource.new()

# 设置基础配置
resource.duration = 1.5
resource.channel = "ui_effects"
resource.priority = 5
resource.time_group = "button_clicks"

# 设置中断策略
resource.set_interruption_policy(JuicyMixerEnms.InterruptionPolicy.PRIORITY_OVERRIDE)
resource.set_interruption_priority(10)
resource.allow_interruption = true
resource.can_interrupt_others = true
resource.interruption_fade_duration = 0.2

# 验证配置
var validation = resource.validate_config()
if not validation.valid:
    print("配置错误: ", validation.issues)

# 播放效果
JuicyMixer.play(resource, target_node)
```

### 高级中断配置

```gdscript
# 创建关键UI效果资源
var critical_ui_effect = JuicyFeedbackResource.new()
critical_ui_effect.duration = 0.5
critical_ui_effect.channel = "critical_ui"
critical_ui_effect.priority = 20
critical_ui_effect.time_group = "critical_notifications"

# 设置中断策略为优先级覆盖
critical_ui_effect.set_interruption_policy(JuicyMixerEnms.InterruptionPolicy.PRIORITY_OVERRIDE)
critical_ui_effect.set_interruption_priority(20)
critical_ui_effect.allow_interruption = false  # 关键效果不允许被中断
critical_ui_effect.can_interrupt_others = true  # 但可以中断其他效果
critical_ui_effect.interruption_fade_duration = 0.1  # 快速过渡

# 创建背景效果资源
var background_effect = JuicyFeedbackResource.new()
background_effect.duration = 3.0
background_effect.channel = "ambient_effects"
background_effect.priority = 1
background_effect.time_group = "environment"

# 设置中断策略为堆叠
background_effect.set_interruption_policy(JuicyMixerEnms.InterruptionPolicy.STACK)
background_effect.set_interruption_priority(1)
background_effect.allow_interruption = true  # 允许被中断
background_effect.can_interrupt_others = false  # 不中断其他效果
background_effect.interruption_fade_duration = 0.5  # 缓慢过渡
```

### 配置序列化和恢复

```gdscript
# 创建资源并配置
var resource = JuicyFeedbackResource.new()
resource.duration = 2.0
resource.channel = "combat_effects"
resource.set_interruption_policy(JuicyMixerEnms.InterruptionPolicy.FADE_OUT_FADE_IN)
resource.set_interruption_priority(15)

# 序列化配置
var config_dict = resource.get_config_dict()

# 保存到文件
var file = FileAccess.open("user://effect_config.json", FileAccess.WRITE)
file.store_string(JSON.stringify(config_dict))
file.close()

# 从文件加载
var load_file = FileAccess.open("user://effect_config.json", FileAccess.READ)
var json_string = load_file.get_as_text()
load_file.close()

var json = JSON.new()
var parse_result = json.parse(json_string)
if parse_result == OK:
    var new_resource = JuicyFeedbackResource.new()
    var success = new_resource.load_from_dict(json.data)
    if success:
        print("资源配置恢复成功")
        JuicyMixer.play(new_resource, target_node)
```

### 动态配置调整

```gdscript
# 根据游戏状态动态调整中断策略
func adjust_effect_interruption(resource: JuicyFeedbackResource, game_state: String):
    match game_state:
        "menu":
            # 菜单状态：使用平滑过渡
            resource.set_interruption_policy(JuicyMixerEnms.InterruptionPolicy.SMOOTH_TRANSITION)
            resource.set_interruption_priority(5)
            resource.interruption_fade_duration = 0.3
        
        "combat":
            # 战斗状态：使用优先级覆盖
            resource.set_interruption_policy(JuicyMixerEnms.InterruptionPolicy.PRIORITY_OVERRIDE)
            resource.set_interruption_priority(15)
            resource.interruption_fade_duration = 0.1
        
        "cinematic":
            # 电影模式：不允许中断
            resource.set_interruption_policy(JuicyMixerEnms.InterruptionPolicy.IGNORE)
            resource.allow_interruption = false
            resource.can_interrupt_others = false
        
        "exploration":
            # 探索模式：使用堆叠
            resource.set_interruption_policy(JuicyMixerEnms.InterruptionPolicy.STACK)
            resource.set_interruption_priority(8)
            resource.interruption_fade_duration = 0.2

# 使用示例
var effect = JuicyFeedbackResource.new()
adjust_effect_interruption(effect, "combat")
JuicyMixer.play(effect, target_node)
```

### 批量配置管理

```gdscript
# 创建效果配置模板
func create_effect_template(template_name: String) -> JuicyFeedbackResource:
    var resource = JuicyFeedbackResource.new()
    
    match template_name:
        "ui_critical":
            resource.channel = "ui_critical"
            resource.priority = 20
            resource.set_interruption_policy(JuicyMixerEnms.InterruptionPolicy.PRIORITY_OVERRIDE)
            resource.set_interruption_priority(20)
            resource.allow_interruption = false
            resource.interruption_fade_duration = 0.1
        
        "ui_normal":
            resource.channel = "ui_normal"
            resource.priority = 10
            resource.set_interruption_policy(JuicyMixerEnms.InterruptionPolicy.PRIORITY_STACK)
            resource.set_interruption_priority(10)
            resource.allow_interruption = true
            resource.interruption_fade_duration = 0.2
        
        "ambient":
            resource.channel = "ambient"
            resource.priority = 5
            resource.set_interruption_policy(JuicyMixerEnms.InterruptionPolicy.FADE_OUT_FADE_IN)
            resource.set_interruption_priority(5)
            resource.allow_interruption = true
            resource.can_interrupt_others = false
            resource.interruption_fade_duration = 0.5
    
    return resource

# 使用模板创建效果
var critical_effect = create_effect_template("ui_critical")
critical_effect.duration = 0.8
JuicyMixer.play(critical_effect, critical_button)

var normal_effect = create_effect_template("ui_normal")
normal_effect.duration = 0.5
JuicyMixer.play(normal_effect, normal_button)
```

## 最佳实践

1. **通道命名**: 使用描述性的通道名称，如"ui_critical"、"combat_effects"、"ambient"
2. **优先级设置**: 为不同类型的效果设置合理的优先级，确保重要反馈不被忽略
3. **中断策略**: 根据效果的重要性和类型选择合适的中断策略
4. **过渡时间**: 根据效果类型设置合适的过渡时间，保证视觉流畅性
5. **配置验证**: 在使用前验证配置有效性，避免运行时错误

## 注意事项

1. **抽象类**: 这是一个抽象类，不能直接实例化，需要子类实现
2. **资源类型**: 此类继承自Resource，可以作为资源文件保存
3. **线程安全**: 配置修改不是线程安全的，应在主线程中进行
4. **验证**: 建议在应用配置前先验证配置有效性

## 相关类

- [`InterruptionState`](InterruptionState.md) - 中断状态
- [`ChannelInterruptionConfig`](ChannelInterruptionConfig.md) - 通道中断配置
- [`JuicyInterruptionManager`](JuicyInterruptionManager.md) - 中断管理器
- [`JuicyMixerEnms.InterruptionPolicy`](JuicyMixerEnums.md) - 中断策略枚举