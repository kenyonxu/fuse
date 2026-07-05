# JuicyMixer V3 API 参考文档

## 概述

JuicyMixer V3 是一个为Godot引擎设计的高级游戏反馈效果管理系统，提供模块化、可扩展的架构来管理游戏中的各种反馈效果。本文档提供了完整的API参考，包括所有核心类、方法和属性的详细说明。

## 目录

1. [核心系统](#核心系统)
2. [资源系统](#资源系统)
3. [驱动器系统](#驱动器系统)
4. [事件系统](#事件系统)
5. [中间件系统](#中间件系统)
6. [参数映射系统](#参数映射系统)
7. [变体系统](#变体系统)
8. [条件系统](#条件系统)
9. [工具类](#工具类)

---

## 核心系统

### JuicyMixer (全局入口)

JuicyMixer是系统的全局入口点，提供静态API来管理整个反馈效果系统。

#### 静态方法

##### `play(resource: JuicyFeedbackResource, target: Node, owner: Node = null) -> String`

播放一个反馈效果。

**参数：**
- `resource`: 要播放的反馈资源
- `target`: 效果的目标节点
- `owner`: 效果的所有者节点（可选，默认为target）

**返回：**
- `String`: 上下文ID，用于后续操作（如停止、暂停等）

**示例：**
```gdscript
var context_id = JuicyMixer.play(shake_resource, player_node)
```

##### `stop(context_id: String) -> bool`

停止指定上下文的反馈效果。

**参数：**
- `context_id`: 要停止的效果上下文ID

**返回：**
- `bool`: 是否成功停止

**示例：**
```gdscript
JuicyMixer.stop(context_id)
```

##### `pause(context_id: String) -> bool`

暂停指定上下文的反馈效果。

**参数：**
- `context_id`: 要暂停的效果上下文ID

**返回：**
- `bool`: 是否成功暂停

**示例：**
```gdscript
JuicyMixer.pause(context_id)
```

##### `resume(context_id: String) -> bool`

恢复指定上下文的反馈效果。

**参数：**
- `context_id`: 要恢复的效果上下文ID

**返回：**
- `bool`: 是否成功恢复

**示例：**
```gdscript
JuicyMixer.resume(context_id)
```

##### `play_event(event: JuicyEvent, target: Node, owner: Node = null) -> String`

播放一个事件（推荐使用）。

此方法通过 Director 和 MiddlewarePipeline 处理事件，确保架构一致性。

**参数：**
- `event`: 要播放的事件
- `target`: 事件的目标节点
- `owner`: 事件的所有者节点（可选，默认为target）

**返回：**
- `String`: 上下文ID，用于后续操作（如停止、暂停等）

**示例：**
```gdscript
var audio_event = JuicyEvent.create_audio_play_event("explosion_sound", player, sound_stream, position)
var context_id = JuicyMixer.play_event(audio_event, player)
```

##### `get_context(context_id: String) -> JuicyContext`

获取指定上下文ID的JuicyContext实例。

**参数：**
- `context_id`: 上下文ID

**返回：**
- `JuicyContext`: 上下文实例，如果不存在则返回null

**示例：**
```gdscript
var context = JuicyMixer.get_context(context_id)
if context:
	context.set_parameter("intensity", 0.8)
```

##### `add_event(event: JuicyEvent) -> bool` ⚠️ **已废弃**

> **注意**: 此方法已废弃，请使用 `play_event()` 代替。

此方法绕过了 Director 和 MiddlewarePipeline，可能导致事件不被正确处理。

**参数：**
- `event`: 要添加的事件

**返回：**
- `bool`: 是否成功添加

**替代方法：**
请使用 `play_event(event: JuicyEvent, target: Node, owner: Node = null) -> String`

**示例：**
```gdscript
# ❌ 旧方法（不推荐）
var audio_event = JuicyEvent.create_audio_play_event("audio_event", player, sound, position)
JuicyMixer.add_event(audio_event)

# ✅ 新方法（推荐）
var audio_event = JuicyEvent.create_audio_play_event("audio_event", player, sound, position)
JuicyMixer.play_event(audio_event, player)
```

---

### JuicyContext (数据载体)

JuicyContext是强类型的运行时数据容器，管理效果的生命周期状态，提供类型安全的数据访问方法。

#### 属性

| 属性名 | 类型 | 描述 |
|--------|------|------|
| `resource` | JuicyFeedbackResource | 静态数据引用（不可变） |
| `target` | Node | 效果目标节点 |
| `owner` | Node | 效果所有者节点 |
| `progress` | float | 执行进度（0.0-1.0） |
| `time_scale` | float | 时间缩放（1.0为正常速度） |
| `is_active` | bool | 是否处于活跃状态 |
| `is_paused` | bool | 是否处于暂停状态 |
| `is_completed` | bool | 是否已完成 |
| `start_time` | float | 开始时间 |
| `current_time` | float | 当前时间 |
| `duration` | float | 效果持续时间 |
| `context_id` | String | 唯一上下文ID |

#### 信号

##### `execute_complete(context_id: String)`

当效果执行完成时发出。

**参数：**
- `context_id`: 完成的上下文ID

#### 方法

##### `get_driver_data(driver_type: String) -> Variant`

获取指定驱动器类型的数据。

**参数：**
- `driver_type`: 驱动器类型名称

**返回：**
- `Variant`: 驱动器数据，如果不存在则返回null

##### `set_driver_data(driver_type: String, data: Variant) -> void`

设置指定驱动器类型的数据。

**参数：**
- `driver_type`: 驱动器类型名称
- `data`: 要设置的数据

##### `get_property_override(property: String, default: Variant) -> Variant`

获取属性覆盖值。

**参数：**
- `property`: 属性名称
- `default`: 默认值

**返回：**
- `Variant`: 属性覆盖值或默认值

##### `set_property_override(property: String, value: Variant) -> void`

设置属性覆盖值。

**参数：**
- `property`: 属性名称
- `value`: 要设置的值

##### `activate() -> void`

激活上下文，开始执行效果。

##### `update(delta: float) -> void`

更新上下文状态。

**参数：**
- `delta`: 时间增量（秒）

##### `pause() -> void`

暂停效果执行。

##### `resume() -> void`

恢复效果执行。

##### `complete() -> void`

标记效果为已完成。

##### `reset() -> void`

重置上下文到初始状态。

#### 参数管理方法

##### `set_parameter(parameter_name: String, value: float) -> void`

设置参数值。

**参数：**
- `parameter_name`: 参数名称
- `value`: 参数值

**示例：**
```gdscript
context.set_parameter("intensity", 0.8)
```

##### `get_parameter(parameter_name: String, default_value: float = 0.0) -> float`

获取参数值。

**参数：**
- `parameter_name`: 参数名称
- `default_value`: 默认值（如果参数不存在）

**返回：**
- `float`: 参数值或默认值

**示例：**
```gdscript
var intensity = context.get_parameter("intensity", 0.5)
```

##### `has_parameter(parameter_name: String) -> bool`

检查参数是否存在。

**参数：**
- `parameter_name`: 参数名称

**返回：**
- `bool`: 参数是否存在

##### `remove_parameter(parameter_name: String) -> void`

移除参数。

**参数：**
- `parameter_name`: 参数名称

##### `get_parameter_names() -> Array`

获取所有参数名称。

**返回：**
- `Array`: 参数名称数组

#### 参数映射方法

##### `add_parameter_mapping(parameter_name: String, target_context_id: String, property_path: String, curve: Curve = null) -> void`

添加参数映射。

**参数：**
- `parameter_name`: 参数名称
- `target_context_id`: 目标子上下文ID
- `property_path`: 属性路径（如"amplitude", "volume_db"）
- `curve`: 映射曲线（可选）

##### `get_parameter_mapping_targets(parameter_name: String) -> Array`

获取指定参数的所有映射目标。

**参数：**
- `parameter_name`: 参数名称

**返回：**
- `Array`: MappingTarget数组

##### `clear_parameter_mappings() -> void`

清理所有参数映射。

#### 中间件数据方法

##### `get_middleware_data(middleware_name: String, key: String, default: Variant = null) -> Variant`

获取中间件数据。

**参数：**
- `middleware_name`: 中间件名称
- `key`: 数据键
- `default`: 默认值

**返回：**
- `Variant`: 中间件数据或默认值

##### `set_middleware_data(middleware_name: String, key: String, value: Variant) -> void`

设置中间件数据。

**参数：**
- `middleware_name`: 中间件名称
- `key`: 数据键
- `value`: 数据值

#### 静态方法

##### `create(resource: JuicyFeedbackResource, target: Node, owner: Node = null) -> JuicyContext`

创建新的JuicyContext实例。

**参数：**
- `resource`: 反馈资源
- `target`: 目标节点
- `owner`: 所有者节点（可选）

**返回：**
- `JuicyContext`: 新创建的上下文实例

---

## 资源系统

### JuicyFeedbackResource (资源基类)

所有反馈资源的基类，定义了通用的配置接口和行为。

#### 属性

| 属性名 | 类型 | 描述 |
|--------|------|------|
| `interruption_policy` | InterruptionPolicy | 中断策略 |
| `interruption_priority` | int | 中断优先级 |
| `allow_interruption` | bool | 是否允许被中断 |
| `can_interrupt_others` | bool | 是否可以中断其他效果 |
| `interruption_fade_duration` | float | 中断淡出持续时间 |

#### 方法

##### `validate_config() -> ValidationResult`

验证资源配置。

**返回：**
- `ValidationResult`: 验证结果，包含有效性和问题列表

##### `create_drivers() -> Array`

创建驱动器实例。

**返回：**
- `Array`: 驱动器实例数组

##### `get_duration() -> float`

获取效果持续时间。

**返回：**
- `float`: 持续时间（秒）

---

### JuicyCompositeResource (组合资源)

定义效果组合的配置结构，管理多个JuicyFeedbackResource的组合。

#### 属性

| 属性名 | 类型 | 描述 |
|--------|------|------|
| `composite_items` | Array[JuicyCompositeItem] | 组合项数组 |
| `blend_mode` | CompositeBlendMode | 混合模式 |
| `normalize_weights` | bool | 是否标准化权重 |
| `dynamic_weight_adjustment` | bool | 是否动态调整权重 |
| `parameter_mappings` | Array[JuicyParameterMapping] | 参数映射数组 |
| `enable_parameter_mapping` | bool | 是否启用参数映射 |
| `auto_update_parameters` | bool | 是否自动更新参数 |

#### 枚举

##### `CompositeBlendMode`

组合混合模式。

| 值 | 描述 |
|----|------|
| `ADDITIVE` | 叠加模式 |
| `MULTIPLICATIVE` | 乘法模式 |
| `OVERRIDE` | 覆盖模式 |
| `WEIGHTED_AVERAGE` | 加权平均模式 |

#### 方法

##### `get_item_count() -> int`

获取组合项数量。

**返回：**
- `int`: 组合项数量

##### `add_composite_item(item: JuicyCompositeItem) -> void`

添加组合项。

**参数：**
- `item`: 要添加的组合项

##### `remove_composite_item(index: int) -> void`

移除指定索引的组合项。

**参数：**
- `index`: 要移除的项索引

##### `clear_composite_items() -> void`

清空所有组合项。

##### `add_parameter_mapping(mapping: JuicyParameterMapping) -> void`

添加参数映射。

**参数：**
- `mapping`: 要添加的参数映射

##### `remove_parameter_mapping(index: int) -> void`

移除指定索引的参数映射。

**参数：**
- `index`: 要移除的映射索引

##### `clear_parameter_mappings() -> void`

清空所有参数映射。

##### `get_total_weight() -> float`

获取总权重。

**返回：**
- `float`: 所有启用项的权重总和

##### `get_normalized_weights() -> Array[float]`

获取标准化权重数组。

**返回：**
- `Array[float]`: 标准化权重数组

##### `get_description() -> String`

获取描述信息。

**返回：**
- `String`: 描述字符串

---

### JuicyCompositeItem (组合项)

定义组合效果中的单个项，包含资源引用、权重、条件等配置。

#### 属性

| 属性名 | 类型 | 描述 |
|--------|------|------|
| `resource` | JuicyFeedbackResource | 反馈资源 |
| `weight` | float | 权重值 |
| `condition` | JuicyCondition | 激活条件（可选） |
| `enabled` | bool | 是否启用 |
| `priority` | int | 优先级 |

#### 方法

##### `validate_item() -> String`

验证组合项配置。

**返回：**
- `String`: 错误信息，如果验证通过则返回空字符串

##### `get_description() -> String`

获取组合项的描述信息。

**返回：**
- `String`: 描述字符串

##### `get_resource_type() -> String`

获取资源类型。

**返回：**
- `String`: 资源类型字符串

##### `get_config_dict() -> Dictionary`

获取配置的字典表示，用于序列化。

**返回：**
- `Dictionary`: 包含所有配置属性的字典

##### `load_from_dict(config_dict: Dictionary) -> bool`

从字典加载配置，用于反序列化。

**参数：**
- `config_dict`: 包含配置属性的字典

**返回：**
- `bool`: 加载是否成功

---

### JuicyParameterMapping (参数映射)

定义参数映射的配置，用于将外部输入参数映射到组合效果中的特定属性。

#### 属性

| 属性名 | 类型 | 描述 |
|--------|------|------|
| `input_parameter` | String | 外部输入的参数名 |
| `target_item_index` | int | 绑定到Composite中的哪个子Resource |
| `target_property` | String | 绑定到Resource的哪个属性 |
| `curve` | Curve | 映射曲线 |
| `enabled` | bool | 是否启用此映射 |

#### 方法

##### `validate_mapping() -> String`

验证映射配置的有效性。

**返回：**
- `String`: 错误信息，如果验证通过则返回空字符串

##### `get_description() -> String`

获取映射配置的描述信息。

**返回：**
- `String`: 描述字符串

##### `apply_mapping(input_value: float) -> float`

应用参数映射，使用曲线进行值转换。

**参数：**
- `input_value`: 输入参数值

**返回：**
- `float`: 映射后的参数值

##### `get_config_dict() -> Dictionary`

获取映射配置的字典表示，用于序列化。

**返回：**
- `Dictionary`: 包含所有配置属性的字典

##### `load_from_dict(config_dict: Dictionary) -> bool`

从字典加载映射配置，用于反序列化。

**参数：**
- `config_dict`: 包含配置属性的字典

**返回：**
- `bool`: 加载是否成功

---

### JuicyResourceVariant (变体资源)

基于基础组合资源创建变体，支持数据覆盖和参数绑定继承。

#### 属性

| 属性名 | 类型 | 描述 |
|--------|------|------|
| `base_composite_resource` | JuicyCompositeResource | 基础组合资源 |
| `data_overrides` | Array[DataOverride] | 数据覆盖数组 |
| `inherit_parameter_bindings` | bool | 是否继承参数绑定 |

#### 方法

##### `_create_variant_composite() -> JuicyCompositeResource`

创建变体组合资源（内部方法）。

**返回：**
- `JuicyCompositeResource`: 变体组合资源

##### `validate_config() -> ValidationResult`

验证变体配置。

**返回：**
- `ValidationResult`: 验证结果

---

### DataOverride (数据覆盖)

定义如何覆盖组合资源中的数据。

#### 属性

| 属性名 | 类型 | 描述 |
|--------|------|------|
| `override_mode` | OverrideMode | 覆盖模式 |
| `target_item_index` | int | 目标项索引 |
| `target_data_index` | int | 目标数据索引 |
| `property_overrides` | Dictionary | 属性覆盖字典 |
| `new_data` | Resource | 新数据（用于替换模式） |
| `new_composite_item` | JuicyCompositeItem | 新组合项（用于添加模式） |
| `enabled` | bool | 是否启用此覆盖 |

#### 枚举

##### `OverrideMode`

覆盖模式。

| 值 | 描述 |
|----|------|
| `MODIFY_DATA` | 修改现有数据 |
| `REPLACE_DATA` | 替换现有数据 |
| `ADD_TO_COMPOSITE` | 添加到组合 |
| `REMOVE_FROM_COMPOSITE` | 从组合中移除 |

#### 方法

##### `validate_override() -> String`

验证覆盖配置的有效性。

**返回：**
- `String`: 错误信息，如果验证通过则返回空字符串

---

## 条件系统

### JuicyCondition (条件基类)

所有条件类型的基类，定义了条件评估的通用接口。

#### 属性

| 属性名 | 类型 | 描述 |
|--------|------|------|
| `enabled` | bool | 条件是否启用 |

#### 方法

##### `evaluate(context: JuicyContext) -> bool`

评估条件是否满足（抽象方法，子类必须实现）。

**参数：**
- `context`: JuicyContext实例

**返回：**
- `bool`: 条件是否满足

##### `get_description() -> String`

获取条件描述（抽象方法，子类必须实现）。

**返回：**
- `String`: 条件描述字符串

##### `validate_condition() -> String`

验证条件配置（抽象方法，子类必须实现）。

**返回：**
- `String`: 错误信息，如果验证通过则返回空字符串

##### `on_parameter_changed(parameter_name: String, old_value: float, new_value: float) -> void`

参数变化回调（抽象方法，子类可选实现）。

**参数：**
- `parameter_name`: 变化的参数名
- `old_value`: 参数旧值
- `new_value`: 参数新值

---

### JuicyParameterCondition (参数条件)

基于参数值的条件判断，支持多种比较操作符。

#### 属性

| 属性名 | 类型 | 描述 |
|--------|------|------|
| `parameter_name` | String | 要比较的参数名 |
| `operator` | ComparisonOperator | 比较操作符 |
| `target_value` | float | 目标值 |
| `tolerance` | float | 浮点数比较容差 |

#### 枚举

##### `ComparisonOperator`

比较操作符类型。

| 值 | 描述 |
|----|------|
| `GREATER_THAN` | 大于 (>) |
| `LESS_THAN` | 小于 (<) |
| `GREATER_EQUAL` | 大于等于 (>=) |
| `LESS_EQUAL` | 小于等于 (<=) |
| `EQUAL` | 等于 (==) |
| `NOT_EQUAL` | 不等于 (!=) |

#### 方法

##### `evaluate(context: JuicyContext) -> bool`

评估参数条件。

**参数：**
- `context`: JuicyContext实例

**返回：**
- `bool`: 条件是否满足

**示例：**
```gdscript
# 创建条件：当生命值低于30%时触发
var condition = JuicyParameterCondition.new()
condition.parameter_name = "health_percentage"
condition.operator = JuicyParameterCondition.ComparisonOperator.LESS_THAN
condition.target_value = 0.3

# 在上下文中评估
var is_low_health = condition.evaluate(context)
```

##### `get_description() -> String`

获取条件描述。

**返回：**
- `String`: 条件描述字符串

##### `validate_condition() -> String`

验证条件配置。

**返回：**
- `String`: 错误信息，如果验证通过则返回空字符串

##### `on_parameter_changed(parameter_name: String, old_value: float, new_value: float) -> void`

参数变化回调，清除相关缓存。

**参数：**
- `parameter_name`: 变化的参数名
- `old_value`: 参数旧值
- `new_value`: 参数新值

---

### JuicyTimeCondition (时间条件)

基于时间的条件判断，支持多种时间比较操作。

#### 属性

| 属性名 | 类型 | 描述 |
|--------|------|------|
| `time_operator` | TimeOperator | 时间操作符 |
| `target_time` | float | 目标时间值 |
| `use_progress` | bool | 是否使用进度而非绝对时间 |

#### 枚举

##### `TimeOperator`

时间操作符类型。

| 值 | 描述 |
|----|------|
| `AFTER_START` | 效果开始后 |
| `BEFORE_END` | 效果结束前 |
| `DURATION_GREATER` | 持续时间大于 |
| `DURATION_LESS` | 持续时间小于 |
| `PROGRESS_GREATER` | 进度大于 |
| `PROGRESS_LESS` | 进度小于 |

#### 方法

##### `evaluate(context: JuicyContext) -> bool`

评估时间条件。

**参数：**
- `context`: JuicyContext实例

**返回：**
- `bool`: 条件是否满足

**示例：**
```gdscript
# 创建条件：效果播放超过50%时触发
var condition = JuicyTimeCondition.new()
condition.time_operator = JuicyTimeCondition.TimeOperator.PROGRESS_GREATER
condition.target_time = 0.5

# 在上下文中评估
var is_halfway = condition.evaluate(context)
```

##### `get_description() -> String`

获取条件描述。

**返回：**
- `String`: 条件描述字符串

##### `validate_condition() -> String`

验证条件配置。

**返回：**
- `String`: 错误信息，如果验证通过则返回空字符串

##### `on_parameter_changed(parameter_name: String, old_value: float, new_value: float) -> void`

参数变化回调（时间条件不依赖参数，此方法为空实现）。

**参数：**
- `parameter_name`: 变化的参数名
- `old_value`: 参数旧值
- `new_value`: 参数新值

---

### JuicyCompositeCondition (复合条件)

组合多个条件形成复杂的逻辑表达式，支持AND/OR逻辑操作。

#### 属性

| 属性名 | 类型 | 描述 |
|--------|------|------|
| `operator` | LogicalOperator | 逻辑操作符 |
| `conditions` | Array[JuicyCondition] | 子条件数组 |

#### 枚举

##### `LogicalOperator`

逻辑操作符类型。

| 值 | 描述 |
|----|------|
| `AND` | 所有条件都必须满足 |
| `OR` | 至少一个条件满足 |

#### 方法

##### `evaluate(context: JuicyContext) -> bool`

评估复合条件，使用短路评估优化。

**参数：**
- `context`: JuicyContext实例

**返回：**
- `bool`: 条件是否满足

**示例：**
```gdscript
# 创建复合条件：生命值低于30% 且 效果播放超过50%
var health_condition = JuicyParameterCondition.new()
health_condition.parameter_name = "health_percentage"
health_condition.operator = JuicyParameterCondition.ComparisonOperator.LESS_THAN
health_condition.target_value = 0.3

var time_condition = JuicyTimeCondition.new()
time_condition.time_operator = JuicyTimeCondition.TimeOperator.PROGRESS_GREATER
time_condition.target_time = 0.5

var composite_condition = JuicyCompositeCondition.new()
composite_condition.operator = JuicyCompositeCondition.LogicalOperator.AND
composite_condition.conditions = [health_condition, time_condition]

# 在上下文中评估
var should_trigger = composite_condition.evaluate(context)
```

##### `get_description() -> String`

获取条件描述。

**返回：**
- `String`: 条件描述字符串

##### `validate_condition() -> String`

验证条件配置。

**返回：**
- `String`: 错误信息，如果验证通过则返回空字符串

##### `clear_cache() -> void`

清除缓存，当参数变化时调用。

##### `on_parameter_changed(parameter_name: String, old_value: float, new_value: float) -> void`

参数变化回调，清除缓存。

**参数：**
- `parameter_name`: 变化的参数名
- `old_value`: 参数旧值
- `new_value`: 参数新值

---

## 驱动器系统

### JuicyDriver (驱动器基类)

所有驱动器的基类，定义了通用的接口和行为。

#### 属性

| 属性名 | 类型 | 描述 |
|--------|------|------|
| `driver_name` | String | 驱动器名称 |
| `supported_properties` | Array[String] | 支持的属性列表 |
| `required_context_data` | Array[String] | 需要的上下文数据 |

#### 方法

##### `prepare(context: JuicyContext, delta: float, buffer: JuicyPropertyBuffer) -> void`

准备阶段，在效果开始前调用一次。

**参数：**
- `context`: JuicyContext实例
- `delta`: 时间增量（秒）
- `buffer`: JuicyPropertyBuffer实例

##### `process(context: JuicyContext, delta: float, buffer: JuicyPropertyBuffer) -> void`

处理阶段，每帧调用。

**参数：**
- `context`: JuicyContext实例
- `delta`: 时间增量（秒）
- `buffer`: JuicyPropertyBuffer实例

##### `cleanup(context: JuicyContext) -> void`

清理阶段，在效果结束时调用。

**参数：**
- `context`: JuicyContext实例

---

### JuicyCompositeDriver (组合驱动器)

实现多效果组合的混音台功能，支持参数映射和实时更新。

#### 属性

| 属性名 | 类型 | 描述 |
|--------|------|------|
| `composite_resource` | JuicyCompositeResource | 组合资源配置 |

#### 方法

##### `set_parameter(context_id: String, parameter_name: String, value: float) -> void`

设置参数值（混音台核心功能）。

**参数：**
- `context_id`: 上下文ID
- `parameter_name`: 参数名称
- `value`: 参数值

---

## 事件系统

### JuicyEvent (事件数据结构)

独立的事件类，用于在JuicyMixer系统中传递事件信息。

#### 属性

| 属性名 | 类型 | 描述 |
|--------|------|------|
| `event_type` | EventType | 事件类型 |
| `target` | Node | 事件目标 |
| `context_id` | String | 关联的上下文ID |
| `priority` | int | 事件优先级 |
| `delay` | float | 事件延迟（秒） |
| `data` | Dictionary | 事件数据 |

#### 枚举

##### `EventType`

事件类型。

| 值 | 描述 |
|----|------|
| `AUDIO_PLAY` | 音频播放 |
| `AUDIO_STOP` | 音频停止 |
| `PARTICLE_SPAWN` | 粒子生成 |
| `SCREEN_SHAKE` | 屏幕震动 |
| `VIBRATION` | 手柄震动 |
| `INTERRUPTION_OCCURRED` | 中断发生 |
| `INTERRUPTION_RESOLVED` | 中断解决 |
| `TRANSITION_STARTED` | 过渡开始 |
| `TRANSITION_COMPLETED` | 过渡完成 |
| `CUSTOM_EVENT` | 自定义事件 |

#### 静态方法

##### `create_audio_play_event(name: String, target: Node, audio_stream: AudioStream, position: Vector2 = Vector2.ZERO, volume: float = 1.0) -> JuicyEvent`

创建音频播放事件。

**参数：**
- `name`: 事件名称（用于标识）
- `target`: 事件目标
- `audio_stream`: 音频流
- `position`: 播放位置（可选）
- `volume`: 音量（可选）

**返回：**
- `JuicyEvent`: 音频播放事件

##### `create_particle_spawn_event(name: String, target: Node, particle_scene: PackedScene, count: int = 10, position: Vector2 = Vector2.ZERO) -> JuicyEvent`

创建粒子生成事件。

**参数：**
- `name`: 事件名称（用于标识）
- `target`: 事件目标
- `particle_scene`: 粒子场景
- `count`: 粒子数量（可选）
- `position`: 生成位置（可选）

**返回：**
- `JuicyEvent`: 粒子生成事件

---

### JuicyEventHandler (事件处理器基类)

定义所有事件处理器的通用接口和行为。

#### 属性

| 属性名 | 类型 | 描述 |
|--------|------|------|
| `handler_name` | String | 处理器名称 |
| `supported_events` | Array[EventType] | 支持的事件类型 |
| `description` | String | 处理器描述 |

#### 方法

##### `handle_event(event: JuicyEvent) -> bool`

处理事件。

**参数：**
- `event`: 要处理的事件

**返回：**
- `bool`: 是否成功处理

##### `can_handle_event(event: JuicyEvent) -> bool`

检查是否可以处理指定事件。

**参数：**
- `event`: 要检查的事件

**返回：**
- `bool`: 是否可以处理

---

### JuicyAudioEventHandler (音频事件处理器)

处理音频播放和停止事件，管理音频播放器池，支持空间音频效果。

#### 方法

##### `play_audio(audio_stream: AudioStream, position: Vector2 = Vector2.ZERO, volume: float = 1.0) -> String`

播放音频。

**参数：**
- `audio_stream`: 音频流
- `position`: 播放位置（可选）
- `volume`: 音量（可选）

**返回：**
- `String`: 播放器ID

##### `stop_audio(player_id: String) -> bool`

停止音频播放。

**参数：**
- `player_id`: 播放器ID

**返回：**
- `bool`: 是否成功停止

---

### JuicyParticleEventHandler (粒子事件处理器)

处理粒子生成和停止事件，管理粒子系统池，支持粒子效果配置。

#### 方法

##### `spawn_particles(particle_scene: PackedScene, count: int = 10, position: Vector2 = Vector2.ZERO) -> String`

生成粒子效果。

**参数：**
- `particle_scene`: 粒子场景
- `count`: 粒子数量（可选）
- `position`: 生成位置（可选）

**返回：**
- `String`: 粒子系统ID

##### `stop_particles(system_id: String) -> bool`

停止粒子系统。

**参数：**
- `system_id`: 粒子系统ID

**返回：**
- `bool`: 是否成功停止

---

## 中间件系统

### JuicyMiddleware (中间件基类)

定义所有中间件的通用接口和行为。

#### 属性

| 属性名 | 类型 | 描述 |
|--------|------|------|
| `middleware_name` | String | 中间件名称 |
| `priority` | int | 执行优先级 |
| `enabled` | bool | 是否启用 |

#### 方法

##### `on_before_play(context: JuicyContext) -> void`

播放前钩子。

**参数：**
- `context`: 上下文实例

##### `on_after_play(context: JuicyContext) -> void`

播放后钩子。

**参数：**
- `context`: 上下文实例

##### `on_before_stop(context: JuicyContext) -> void`

停止前钩子。

**参数：**
- `context`: 上下文实例

##### `on_after_stop(context: JuicyContext) -> void`

停止后钩子。

**参数：**
- `context`: 上下文实例

---

### JuicyMiddlewarePipeline (中间件管道)

管理中间件的注册、排序、执行和生命周期。

#### 方法

##### `register_middleware(middleware: JuicyMiddleware) -> bool`

注册中间件。

**参数：**
- `middleware`: 要注册的中间件

**返回：**
- `bool`: 是否成功注册

##### `unregister_middleware(middleware_name: String) -> bool`

注销中间件。

**参数：**
- `middleware_name`: 中间件名称

**返回：**
- `bool`: 是否成功注销

##### `get_all_middleware() -> Array`

获取所有已注册的中间件。

**返回：**
- `Array`: 中间件数组

##### `execute_before_play_hooks(context: JuicyContext) -> void`

执行播放前钩子。

**参数：**
- `context`: 上下文实例

##### `execute_after_play_hooks(context: JuicyContext) -> void`

执行播放后钩子。

**参数：**
- `context`: 上下文实例

---

## 工具类

### JuicyPropertyBuffer (属性缓冲)

集中管理所有属性修改，避免多次Node.set()调用，处理属性混合和冲突解决。

#### 枚举

##### `BlendMode`

混合模式。

| 值 | 描述 |
|----|------|
| `OVERRIDE_BASE` | 覆盖基础值 |
| `ADDITIVE` | 叠加偏移量 |
| `MULTIPLICATIVE` | 乘法混合 |

#### 方法

##### `add_sample(target: Node, property: String, value: Variant, mode: BlendMode, source: String = "", priority: int = 0) -> void`

添加属性采样。

**参数：**
- `target`: 目标节点
- `property`: 属性名称
- `value`: 属性值
- `mode`: 混合模式
- `source`: 来源标识（可选）
- `priority`: 优先级（可选）

##### `add_middleware_sample(target: Node, property: String, value: Variant, mode: BlendMode, middleware_name: String, priority: int = 0) -> void`

添加中间件专用属性采样。

**参数：**
- `target`: 目标节点
- `property`: 属性名称
- `value`: 属性值
- `mode`: 混合模式
- `middleware_name`: 中间件名称
- `priority`: 优先级（可选）

##### `apply_samples() -> void`

应用所有采样到目标节点。

##### `clear_samples() -> void`

清空所有采样。

---

## 使用示例

### 基本使用

```gdscript
# 创建震动资源
var shake_resource = JuicyShakeResource.new()
var shake_data = ShakeData.new()
shake_data.property = "position"
shake_data.amplitude = 10.0
shake_data.frequency = 5.0
shake_data.duration = 1.0
shake_resource.shake_data = [shake_data]

# 播放效果
var context_id = JuicyMixer.play(shake_resource, player_node)

# 停止效果
await get_tree().create_timer(2.0).timeout
JuicyMixer.stop(context_id)
```

### 组合效果使用

```gdscript
# 创建组合资源
var composite = JuicyCompositeResource.new()

# 添加震动效果
var shake_resource = JuicyShakeResource.new()
# ... 配置震动资源 ...
var shake_item = JuicyCompositeItem.new()
shake_item.resource = shake_resource
shake_item.weight = 1.0

# 添加弹簧效果
var spring_resource = JuicySpringResource.new()
# ... 配置弹簧资源 ...
var spring_item = JuicyCompositeItem.new()
spring_item.resource = spring_resource
spring_item.weight = 0.5

# 设置组合项
composite.composite_items = [shake_item, spring_item]
composite.blend_mode = JuicyCompositeResource.CompositeBlendMode.ADDITIVE

# 播放组合效果
var context_id = JuicyMixer.play(composite, player_node)
```

### 参数映射使用

```gdscript
# 启用参数映射
composite.enable_parameter_mapping = true

# 创建参数映射
var mapping = JuicyParameterMapping.new()
mapping.input_parameter = "intensity"
mapping.target_item_index = 0
mapping.target_property = "amplitude"

# 添加曲线映射
var curve = Curve.new()
curve.add_point(Vector2(0, 0))
curve.add_point(Vector2(1, 20))
mapping.curve = curve

composite.parameter_mappings = [mapping]

# 播放并控制参数
var context = JuicyMixer.play(composite, player_node)
context.set_parameter("intensity", 0.5)  # 50%强度
```

### 变体系统使用

```gdscript
# 创建基础组合
var base_composite = JuicyCompositeResource.new()
# ... 配置基础组合 ...

# 创建变体
var variant = JuicyResourceVariant.new()
variant.base_composite_resource = base_composite
variant.inherit_parameter_bindings = true

# 添加数据覆盖
var override = DataOverride.new()
override.override_mode = DataOverride.OverrideMode.MODIFY_DATA
override.target_item_index = 0
override.target_data_index = 0
override.property_overrides = {"amplitude": 15.0, "frequency": 8.0}

variant.data_overrides = [override]

# 播放变体效果
var context_id = JuicyMixer.play(variant, player_node)
```

### 条件系统使用

```gdscript
# 创建参数条件
var health_condition = JuicyParameterCondition.new()
health_condition.parameter_name = "health_percentage"
health_condition.operator = JuicyParameterCondition.ComparisonOperator.LESS_THAN
health_condition.target_value = 0.3

# 创建时间条件
var time_condition = JuicyTimeCondition.new()
time_condition.time_operator = JuicyTimeCondition.TimeOperator.PROGRESS_GREATER
time_condition.target_time = 0.5

# 创建复合条件
var composite_condition = JuicyCompositeCondition.new()
composite_condition.operator = JuicyCompositeCondition.LogicalOperator.AND
composite_condition.conditions = [health_condition, time_condition]

# 创建组合项并设置条件
var item = JuicyCompositeItem.new()
item.resource = shake_resource
item.weight = 1.0
item.condition = composite_condition

# 添加到组合资源
var composite = JuicyCompositeResource.new()
composite.add_composite_item(item)

# 播放效果（只有当条件满足时才会激活）
var context_id = JuicyMixer.play(composite, player_node)
```

### 事件系统使用

```gdscript
# 播放音频事件（推荐方式）
var audio_event = JuicyEvent.create_audio_play_event(
	"explosion_sound",  # 事件名称
	player_node,
	preload("res://sounds/hit.wav"),
	player_node.position,
	0.8
)
var context_id = JuicyMixer.play_event(audio_event, player_node)

# 生成粒子事件
var particle_event = JuicyEvent.create_particle_spawn_event(
	"explosion_particles",  # 事件名称
	player_node,
	preload("res://particles/explosion.tscn"),
	30,
	player_node.position
)
var particle_context_id = JuicyMixer.play_event(particle_event, player_node)
```

---

## 📋 待补充文档说明

以下文档在后续版本中需要补充：

### 核心系统架构
- [ ] **JuicyDirector** - 主要调度器的完整文档
- [ ] **JuicyPoolManager** - 对象池管理系统文档
- [ ] **JuicyContextPool** - 上下文池管理文档
- [ ] **JuicyDriverRegistry** - 驱动器注册表文档

### 中间件系统
- [ ] **ValidationMiddleware** - 验证中间件详细文档
- [ ] **InterruptionMiddleware** - 中断中间件详细文档
- [ ] **ChannelMiddleware** - 通道中间件详细文档
- [ ] **StateRestorationMiddleware** - 状态还原中间件详细文档
- [ ] **EventHandlingMiddleware** - 事件处理中间件详细文档

### 新增功能
- [ ] **Timeline 系统** - 时间线控制系统完整文档
- [ ] **序列系统** - JuicySequenceResource 使用文档
- [ ] **方法轨迹** - JuicyMethodTrack 使用文档
- [ ] **音频管理系统** - AudioManager、MusicManager、MusicPlayer 完整文档

### 开发指南
- [ ] **自定义驱动器开发指南** - 如何创建新的驱动器
- [ ] **自定义中间件开发指南** - 如何创建新的中间件
- [ ] **性能优化最佳实践** - 详细的性能优化建议
- [ ] **调试工具使用指南** - 调试和监控工具说明

---

## 版本信息

- **版本**: JuicyMixer V3
- **Godot版本**: 4.x
- **最后更新**: 2025-12-07

---

## 许可证

本API文档遵循与JuicyMixer项目相同的许可证。
