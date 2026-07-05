# JuicyMixerEnums 中断策略枚举 API文档

## 概述

[`JuicyMixerEnms`](../../core/juicy_mixer_enums.gd:1) 提供了JuicyMixer系统中使用的各种枚举类型和辅助函数，包括中断策略、Tween属性、Shake属性和Spring属性等。

## 中断策略枚举

### InterruptionPolicy

中断策略枚举定义了效果中断时的处理方式。

```gdscript
enum InterruptionPolicy {
    STACK,              # 堆叠：新效果加入队列
    RESTART,            # 重启：立即重启效果
    IGNORE,             # 忽略：忽略新效果
    SMOOTH_TRANSITION,   # 平滑过渡：平滑过渡到新效果
    PRIORITY_OVERRIDE,   # 优先级覆盖：高优先级覆盖低优先级效果
    FADE_OUT_FADE_IN,   # 淡出淡入：当前效果淡出，新效果淡入
    PRIORITY_STACK      # 优先级堆叠：按优先级插入队列
}
```

#### 策略详细说明

| 策略 | 值 | 描述 | 适用场景 |
|------|----|-----|----------|
| `STACK` | 0 | 新效果加入队列，当前效果继续执行 | UI反馈、非关键效果 |
| `RESTART` | 1 | 立即停止当前效果，开始新效果 | 关键反馈、紧急响应 |
| `IGNORE` | 2 | 忽略新效果，保持当前效果 | 重要效果保护 |
| `SMOOTH_TRANSITION` | 3 | 平滑地从当前效果过渡到新效果 | 视觉效果、动画 |
| `PRIORITY_OVERRIDE` | 4 | 高优先级效果覆盖低优先级效果 | 分层反馈系统 |
| `FADE_OUT_FADE_IN` | 5 | 当前效果淡出，新效果淡入 | 音频效果、渐变 |
| `PRIORITY_STACK` | 6 | 按优先级插入队列 | 复杂效果管理 |

## 中断策略辅助函数

### `get_interruption_policy_name(policy: InterruptionPolicy) -> String`

根据中断策略枚举值获取对应的策略名称。

**参数:**
- `policy` (InterruptionPolicy): 中断策略枚举值

**返回值:**
- `String`: 对应的策略名称字符串

**示例:**
```gdscript
var name = JuicyMixerEnms.get_interruption_policy_name(JuicyMixerEnms.InterruptionPolicy.STACK)
print(name)  # 输出: "stack"

var name2 = JuicyMixerEnms.get_interruption_policy_name(JuicyMixerEnms.InterruptionPolicy.PRIORITY_OVERRIDE)
print(name2)  # 输出: "priority_override"
```

### `get_interruption_policy_from_name(name: String) -> InterruptionPolicy`

根据策略名称字符串获取对应的中断策略枚举值。

**参数:**
- `name` (String): 策略名称字符串

**返回值:**
- `InterruptionPolicy`: 对应的中断策略枚举值

**示例:**
```gdscript
var policy = JuicyMixerEnms.get_interruption_policy_from_name("stack")
print(policy)  # 输出: 0 (InterruptionPolicy.STACK)

var policy2 = JuicyMixerEnms.get_interruption_policy_from_name("priority_override")
print(policy2)  # 输出: 4 (InterruptionPolicy.PRIORITY_OVERRIDE)

# 大小写不敏感
var policy3 = JuicyMixerEnms.get_interruption_policy_from_name("PRIORITY_STACK")
print(policy3)  # 输出: 6 (InterruptionPolicy.PRIORITY_STACK)
```

### `get_all_interruption_policies() -> Array[String]`

获取所有可用的中断策略名称。

**返回值:**
- `Array[String]`: 策略名称字符串数组

**示例:**
```gdscript
var policies = JuicyMixerEnms.get_all_interruption_policies()
print(policies)  # 输出: ["stack", "restart", "ignore", "smooth_transition", "priority_override", "fade_out_fade_in", "priority_stack"]

# 在编辑器中创建下拉菜单
for policy_name in policies:
    add_item(policy_name)
```

### `get_interruption_policy_description(policy: InterruptionPolicy) -> String`

获取中断策略的描述信息。

**参数:**
- `policy` (InterruptionPolicy): 中断策略枚举值

**返回值:**
- `String`: 策略描述字符串

**示例:**
```gdscript
var desc = JuicyMixerEnms.get_interruption_policy_description(JuicyMixerEnms.InterruptionPolicy.STACK)
print(desc)  # 输出: "堆叠：新效果加入队列，当前效果继续执行"

var desc2 = JuicyMixerEnms.get_interruption_policy_description(JuicyMixerEnms.InterruptionPolicy.PRIORITY_OVERRIDE)
print(desc2)  # 输出: "优先级覆盖：高优先级效果覆盖低优先级效果"
```

## Tween属性枚举

### tween_properties

Tween效果常用属性枚举，用于指定Tween动画的目标属性。

```gdscript
enum tween_properties {
    custom,          # 自定义属性
    position,        # 位置
    rotation,        # 旋转
    scale,           # 缩放
    modulate,        # 调制颜色和透明度(影响自身及子节点)
    self_modulate,   # 调制颜色和透明度(仅影响自身)
    skew,            # 倾斜
    size,            # 大小
    global_position, # 全局位置
    global_rotation, # 全局旋转
    global_scale,   # 全局缩放
    pivot_offset,   # 轴心偏移
    offset          # 偏移
}
```

### Tween属性辅助函数

#### `get_tween_property_name(enum_value: tween_properties) -> String`

根据tween_properties枚举值获取对应的属性名称。

**参数:**
- `enum_value` (tween_properties): tween_properties枚举值

**返回值:**
- `String`: 对应的属性名称字符串

**示例:**
```gdscript
var name = JuicyMixerEnms.get_tween_property_name(JuicyMixerEnms.tween_properties.position)
print(name)  # 输出: "position"

var name2 = JuicyMixerEnms.get_tween_property_name(JuicyMixerEnms.tween_properties.modulate)
print(name2)  # 输出: "modulate"
```

## Shake属性枚举

### shake_properties

Shake效果常用属性枚举，用于指定震动效果的目标属性。

```gdscript
enum shake_properties {
    custom,          # 自定义属性
    position,        # 位置
    rotation,        # 旋转
    scale,           # 缩放
    offset,          # 偏移
    zoom,            # 缩放（Camera2D）
    global_position, # 全局位置
    global_rotation, # 全局旋转
    global_scale,   # 全局缩放
    pivot_offset,   # 轴心偏移
    modulate        # 颜色震动效果
}
```

### Shake属性辅助函数

#### `get_shake_property_name(enum_value: shake_properties) -> String`

根据shake_properties枚举值获取对应的属性名称。

**参数:**
- `enum_value` (shake_properties): shake_properties枚举值

**返回值:**
- `String`: 对应的属性名称字符串

**示例:**
```gdscript
var name = JuicyMixerEnms.get_shake_property_name(JuicyMixerEnms.shake_properties.position)
print(name)  # 输出: "position"

var name2 = JuicyMixerEnms.get_shake_property_name(JuicyMixerEnms.shake_properties.zoom)
print(name2)  # 输出: "zoom"
```

## Spring属性枚举

### spring_properties

Spring效果常用属性枚举，用于指定弹性效果的目标属性。

```gdscript
enum spring_properties {
    custom,          # 自定义属性
    position,        # 位置
    rotation,        # 旋转
    scale,           # 缩放
    offset,          # 偏移
    zoom,            # 缩放（Camera2D）
    global_position, # 全局位置
    global_rotation, # 全局旋转
    global_scale,   # 全局缩放
    pivot_offset,   # 轴心偏移
    modulate        # 颜色弹性效果
}
```

### Spring属性辅助函数

#### `get_spring_property_name(enum_value: spring_properties) -> String`

根据spring_properties枚举值获取对应的属性名称。

**参数:**
- `enum_value` (spring_properties): spring_properties枚举值

**返回值:**
- `String`: 对应的属性名称字符串

**示例:**
```gdscript
var name = JuicyMixerEnms.get_spring_property_name(JuicyMixerEnms.spring_properties.position)
print(name)  # 输出: "position"

var name2 = JuicyMixerEnms.get_spring_property_name(JuicyMixerEnms.spring_properties.modulate)
print(name2)  # 输出: "modulate"
```

## 属性类型提示函数

### `get_property_type_hint(property_name: String) -> String`

获取属性的类型提示，用于编辑器显示。

**参数:**
- `property_name` (String): 属性名称

**返回值:**
- `String`: 类型描述字符串

**示例:**
```gdscript
var type1 = JuicyMixerEnms.get_property_type_hint("position")
print(type1)  # 输出: "Vector2"

var type2 = JuicyMixerEnms.get_property_type_hint("rotation")
print(type2)  # 输出: "float (radians)"

var type3 = JuicyMixerEnms.get_property_type_hint("modulate")
print(type3)  # 输出: "Color"
```

## 属性验证函数

### `is_property_valid_for_node(property_name: String, node: Node) -> bool`

检查给定的属性名称对于指定节点是否有效。

**参数:**
- `property_name` (String): 属性名称
- `node` (Node): 要检查的节点

**返回值:**
- `bool`: 属性是否有效

**示例:**
```gdscript
var sprite = Sprite2D.new()
var is_valid = JuicyMixerEnms.is_property_valid_for_node("position", sprite)
print(is_valid)  # 输出: true

var is_valid2 = JuicyMixerEnms.is_property_valid_for_node("zoom", sprite)
print(is_valid2)  # 输出: false (Sprite2D没有zoom属性)

var camera = Camera2D.new()
var is_valid3 = JuicyMixerEnms.is_property_valid_for_node("zoom", camera)
print(is_valid3)  # 输出: true (Camera2D有zoom属性)
```

### `get_valid_properties_for_node(node: Node) -> Array[String]`

获取指定节点支持的所有有效属性列表。

**参数:**
- `node` (Node): 要检查的节点

**返回值:**
- `Array[String]`: 支持的属性名称数组

**示例:**
```gdscript
var sprite = Sprite2D.new()
var valid_props = JuicyMixerEnms.get_valid_properties_for_node(sprite)
print(valid_props)  # 输出: ["position", "rotation", "scale", "modulate", ...]

var camera = Camera2D.new()
var valid_props2 = JuicyMixerEnms.get_valid_properties_for_node(camera)
print(valid_props2)  # 输出: ["position", "rotation", "offset", "zoom", ...]
```

## 使用示例

### 中断策略使用

```gdscript
# 设置中断策略
var feedback_resource = JuicyFeedbackResource.new()
feedback_resource.interruption_policy = JuicyMixerEnms.InterruptionPolicy.PRIORITY_OVERRIDE

# 从字符串获取策略
var policy_name = "smooth_transition"
var policy = JuicyMixerEnms.get_interruption_policy_from_name(policy_name)
feedback_resource.interruption_policy = policy

# 获取策略描述
var description = JuicyMixerEnms.get_interruption_policy_description(policy)
print("策略描述: ", description)

# 遍历所有策略
for policy_name in JuicyMixerEnms.get_all_interruption_policies():
    var policy_enum = JuicyMixerEnms.get_interruption_policy_from_name(policy_name)
    var desc = JuicyMixerEnms.get_interruption_policy_description(policy_enum)
    print(policy_name, ": ", desc)
```

### 属性验证和使用

```gdscript
# 创建Tween资源并设置属性
var tween_resource = JuicyTweenResource.new()
var target_node = Sprite2D.new()

# 检查属性有效性
var property_name = "position"
if JuicyMixerEnms.is_property_valid_for_node(property_name, target_node):
    print("属性有效: ", property_name)
    
    # 获取属性类型提示
    var type_hint = JuicyMixerEnms.get_property_type_hint(property_name)
    print("属性类型: ", type_hint)
    
    # 设置Tween属性
    tween_resource.property = JuicyMixerEnms.tween_properties.position

# 获取节点的所有有效属性
var valid_props = JuicyMixerEnms.get_valid_properties_for_node(target_node)
print("有效属性: ", valid_props)
```

### 编辑器集成

```gdscript
# 在自定义资源编辑器中创建属性选择下拉菜单
func _create_property_selector():
    var option_button = OptionButton.new()
    
    # 添加所有有效的Tween属性
    for prop_value in JuicyMixerEnms.tween_properties.values():
        var prop_name = JuicyMixerEnms.get_tween_property_name(prop_value)
        if prop_name != "custom":
            option_button.add_item(prop_name, prop_value)
    
    return option_button

# 在自定义资源编辑器中创建中断策略选择器
func _create_policy_selector():
    var option_button = OptionButton.new()
    
    # 添加所有中断策略
    var policies = JuicyMixerEnms.get_all_interruption_policies()
    for i in range(policies.size()):
        var policy_name = policies[i]
        option_button.add_item(policy_name, i)
        
        # 添加工具提示
        var policy_enum = JuicyMixerEnms.get_interruption_policy_from_name(policy_name)
        var description = JuicyMixerEnms.get_interruption_policy_description(policy_enum)
        option_button.set_item_tooltip(i, description)
    
    return option_button
```

## 最佳实践

1. **策略选择**: 根据游戏类型和效果重要性选择合适的中断策略
2. **属性验证**: 在设置效果属性前验证目标节点的属性有效性
3. **类型提示**: 使用类型提示函数为编辑器提供更好的用户体验
4. **枚举转换**: 使用提供的辅助函数进行枚举和字符串之间的转换

## 注意事项

1. **枚举值**: 枚举值是整数，不要直接依赖数值，使用枚举名称
2. **大小写**: 策略名称转换函数是大小写不敏感的
3. **属性检查**: 不同节点类型支持的属性可能不同
4. **自定义属性**: "custom"属性总是有效的，但需要手动处理

## 相关类

- [`InterruptionState`](InterruptionState.md) - 中断状态
- [`ChannelInterruptionConfig`](ChannelInterruptionConfig.md) - 通道中断配置
- [`JuicyInterruptionManager`](JuicyInterruptionManager.md) - 中断管理器
- [`InterruptionMiddleware`](InterruptionMiddleware.md) - 中断中间件