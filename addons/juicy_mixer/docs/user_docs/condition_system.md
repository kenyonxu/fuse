# 条件系统使用指南

## 概述

条件系统是JuicyMixer V3的核心功能之一，它允许根据游戏状态、时间进度或参数值来控制效果的激活和执行。条件系统提供了灵活的机制来创建动态、响应式的游戏反馈效果。

### 主要特性

- **参数条件**：基于Context中的参数值进行判断
- **时间条件**：基于效果的时间进度进行判断
- **复合条件**：组合多个条件形成复杂的逻辑表达式
- **性能优化**：内置缓存机制，避免重复计算
- **验证系统**：完整的配置验证和错误报告

## 基础概念

### 条件系统架构

```
JuicyCondition (抽象基类)
├── JuicyParameterCondition (参数条件)
├── JuicyTimeCondition (时间条件)
└── JuicyCompositeCondition (复合条件)
    ├── JuicyParameterCondition
    ├── JuicyTimeCondition
    └── JuicyCompositeCondition (支持嵌套)
```

### 条件评估流程

```
用户触发效果 → 创建Context → 评估条件 → 条件满足？ → 执行效果
                                    ↓
                              条件不满足 → 跳过效果
```

## 条件类型详解

### 1. JuicyParameterCondition (参数条件)

参数条件用于比较Context中的参数值与目标值，支持多种比较操作符。

#### 属性配置

| 属性名 | 类型 | 描述 |
|--------|------|------|
| `parameter_name` | String | 要检查的参数名称 |
| `operator` | ComparisonOperator | 比较操作符 |
| `target_value` | float | 目标比较值 |
| `tolerance` | float | 浮点数比较容差 |
| `enabled` | bool | 是否启用条件 |

#### 比较操作符

| 操作符 | 描述 | 示例 |
|--------|------|------|
| `GREATER_THAN` | 大于 | `health > 50` |
| `LESS_THAN` | 小于 | `mana < 20` |
| `GREATER_EQUAL` | 大于等于 | `level >= 5` |
| `LESS_EQUAL` | 小于等于 | `distance <= 3.0` |
| `EQUAL` | 等于 | `combo == 3` |
| `NOT_EQUAL` | 不等于 | `state != 0` |

#### 使用示例

```gdscript
# 创建参数条件
var condition = JuicyParameterCondition.new()
condition.parameter_name = "player_health"
condition.operator = JuicyParameterCondition.ComparisonOperator.LESS_THAN
condition.target_value = 30.0  # 血量低于30%
condition.enabled = true

# 在组合项中使用
var item = JuicyCompositeItem.new()
item.resource = shake_resource
item.condition = condition
```

### 2. JuicyTimeCondition (时间条件)

时间条件用于基于效果的时间进度进行判断，支持多种时间相关的操作。

#### 属性配置

| 属性名 | 类型 | 描述 |
|--------|------|------|
| `time_operator` | TimeOperator | 时间操作符 |
| `target_time` | float | 目标时间值 |
| `use_progress` | bool | 使用进度而非绝对时间 |
| `enabled` | bool | 是否启用条件 |

#### 时间操作符

| 操作符 | 描述 | 示例 |
|--------|------|------|
| `AFTER_START` | 效果开始后 | `current_time >= 1.0` |
| `BEFORE_END` | 效果结束前 | `current_time <= (duration - 1.0)` |
| `DURATION_GREATER` | 持续时间大于 | `duration > 2.0` |
| `DURATION_LESS` | 持续时间小于 | `duration < 5.0` |
| `PROGRESS_GREATER` | 进度大于 | `progress > 0.5` |
| `PROGRESS_LESS` | 进度小于 | `progress < 0.8` |

#### 使用示例

```gdscript
# 创建时间条件
var condition = JuicyTimeCondition.new()
condition.time_operator = JuicyTimeCondition.TimeOperator.AFTER_START
condition.target_time = 0.5  # 效果开始0.5秒后
condition.enabled = true

# 创建时间窗口条件
var time_window = JuicyCompositeCondition.new()
time_window.operator = JuicyCompositeCondition.LogicalOperator.AND

# 开始后1秒
var after_start = JuicyTimeCondition.new()
after_start.time_operator = JuicyTimeCondition.TimeOperator.AFTER_START
after_start.target_time = 1.0
time_window.conditions.append(after_start)

# 结束前1秒
var before_end = JuicyTimeCondition.new()
before_end.time_operator = JuicyTimeCondition.TimeOperator.BEFORE_END
before_end.target_time = 1.0
time_window.conditions.append(before_end)
```

### 3. JuicyCompositeCondition (复合条件)

复合条件允许组合多个条件形成复杂的逻辑表达式，支持AND和OR逻辑操作。

#### 属性配置

| 属性名 | 类型 | 描述 |
|--------|------|------|
| `operator` | LogicalOperator | 逻辑操作符 |
| `conditions` | Array[JuicyCondition] | 子条件数组 |
| `enabled` | bool | 是否启用条件 |

#### 逻辑操作符

| 操作符 | 描述 | 评估规则 |
|--------|------|----------|
| `AND` | 逻辑与 | 所有子条件都必须满足 |
| `OR` | 逻辑或 | 至少一个子条件满足 |

#### 短路评估优化

复合条件支持短路评估，提高性能：
- **AND操作**：遇到第一个false条件时立即返回false
- **OR操作**：遇到第一个true条件时立即返回true

#### 使用示例

```gdscript
# 创建复合条件
var composite = JuicyCompositeCondition.new()
composite.operator = JuicyCompositeCondition.LogicalOperator.AND

# 条件1：血量低
var health_condition = JuicyParameterCondition.new()
health_condition.parameter_name = "health"
health_condition.operator = JuicyParameterCondition.ComparisonOperator.LESS_THAN
health_condition.target_value = 30.0
composite.conditions.append(health_condition)

# 条件2：连击数高
var combo_condition = JuicyParameterCondition.new()
combo_condition.parameter_name = "combo_count"
combo_condition.operator = JuicyParameterCondition.ComparisonOperator.GREATER_EQUAL
combo_condition.target_value = 5.0
composite.conditions.append(combo_condition)

# 条件3：时间窗口
var time_condition = JuicyTimeCondition.new()
time_condition.time_operator = JuicyTimeCondition.TimeOperator.PROGRESS_GREATER
time_condition.target_time = 0.5
composite.conditions.append(time_condition)
```

## 实际应用场景

### 1. 技能系统条件

```gdscript
# 基础技能解锁条件
func create_basic_skill_condition() -> JuicyParameterCondition:
    var condition = JuicyParameterCondition.new()
    condition.parameter_name = "player_level"
    condition.operator = JuicyParameterCondition.ComparisonOperator.GREATER_EQUAL
    condition.target_value = 5.0
    return condition

# 高级技能组合条件
func create_advanced_skill_condition() -> JuicyCompositeCondition:
    var composite = JuicyCompositeCondition.new()
    composite.operator = JuicyCompositeCondition.LogicalOperator.AND
    
    # 等级要求
    var level_condition = JuicyParameterCondition.new()
    level_condition.parameter_name = "player_level"
    level_condition.operator = JuicyParameterCondition.ComparisonOperator.GREATER_EQUAL
    level_condition.target_value = 10.0
    composite.conditions.append(level_condition)
    
    # 魔法值要求
    var mana_condition = JuicyParameterCondition.new()
    mana_condition.parameter_name = "mana"
    mana_condition.operator = JuicyParameterCondition.ComparisonOperator.GREATER_EQUAL
    mana_condition.target_value = 50.0
    composite.conditions.append(mana_condition)
    
    # 连击数要求
    var combo_condition = JuicyParameterCondition.new()
    combo_condition.parameter_name = "combo_count"
    combo_condition.operator = JuicyParameterCondition.ComparisonOperator.GREATER_EQUAL
    combo_condition.target_value = 3.0
    composite.conditions.append(combo_condition)
    
    return composite
```

### 2. 环境效果条件

```gdscript
# 雨天效果条件
func create_rain_condition() -> JuicyParameterCondition:
    var condition = JuicyParameterCondition.new()
    condition.parameter_name = "weather"
    condition.operator = JuicyParameterCondition.ComparisonOperator.EQUAL
    condition.target_value = 2.0  # 2=雨天
    return condition

# 夜晚效果条件
func create_night_condition() -> JuicyCompositeCondition:
    var composite = JuicyCompositeCondition.new()
    composite.operator = JuicyCompositeCondition.LogicalOperator.OR
    
    # 早晨（6点前）
    var morning = JuicyParameterCondition.new()
    morning.parameter_name = "time_of_day"
    morning.operator = JuicyParameterCondition.ComparisonOperator.LESS_THAN
    morning.target_value = 6.0
    composite.conditions.append(morning)
    
    # 晚上（20点后）
    var evening = JuicyParameterCondition.new()
    evening.parameter_name = "time_of_day"
    evening.operator = JuicyParameterCondition.ComparisonOperator.GREATER_EQUAL
    evening.target_value = 20.0
    composite.conditions.append(evening)
    
    return composite
```

### 3. 战斗系统条件

```gdscript
# 处决技能条件
func create_execute_condition() -> JuicyCompositeCondition:
    var composite = JuicyCompositeCondition.new()
    composite.operator = JuicyCompositeCondition.LogicalOperator.AND
    
    # 敌人血量低
    var enemy_health = JuicyParameterCondition.new()
    enemy_health.parameter_name = "enemy_health"
    enemy_health.operator = JuicyParameterCondition.ComparisonOperator.LESS_THAN
    enemy_health.target_value = 20.0
    composite.conditions.append(enemy_health)
    
    # 距离近
    var distance = JuicyParameterCondition.new()
    distance.parameter_name = "distance"
    distance.operator = JuicyParameterCondition.ComparisonOperator.LESS_EQUAL
    distance.target_value = 3.0
    composite.conditions.append(distance)
    
    # 战斗中期
    var combat_time = JuicyTimeCondition.new()
    combat_time.time_operator = JuicyTimeCondition.TimeOperator.AFTER_START
    combat_time.target_time = 1.0
    composite.conditions.append(combat_time)
    
    return composite
```

## 性能优化

### 1. 条件缓存

条件系统内置了缓存机制，避免重复计算：

```gdscript
# 参数条件缓存
var last_parameter_value: float = 0.0
var last_evaluation: bool = false

func evaluate(context: JuicyContext) -> bool:
    var current_value = context.get_parameter(parameter_name, 0.0)
    
    # 缓存优化：如果参数值没有变化，返回上次结果
    if abs(current_value - last_parameter_value) < tolerance:
        return last_evaluation
    
    # 重新计算并缓存
    last_parameter_value = current_value
    last_evaluation = perform_comparison(current_value)
    return last_evaluation
```

### 2. 短路评估

复合条件使用短路评估优化：

```gdscript
# AND短路评估
for condition in conditions:
    if not condition.evaluate(context):
        return false  # 短路：遇到false立即返回

# OR短路评估
for condition in conditions:
    if condition.evaluate(context):
        return true  # 短路：遇到true立即返回
```

### 3. 性能建议

1. **合理使用复合条件**：避免过深的嵌套
2. **优化条件顺序**：将最可能失败的条件放在AND前面
3. **使用容差值**：避免浮点数精确比较
4. **禁用不需要的条件**：设置`enabled = false`

## 最佳实践

### 1. 条件设计原则

- **明确性**：条件名称和描述要清晰
- **简洁性**：避免过于复杂的条件逻辑
- **可测试性**：确保条件可以独立验证
- **性能考虑**：避免在条件中进行复杂计算

### 2. 错误处理

```gdscript
# 验证条件配置
func validate_condition_setup(condition: JuicyCondition) -> bool:
    var errors = condition.validate_condition()
    if not errors.is_empty():
        push_error("条件配置错误: " + errors)
        return false
    return true

# 安全评估
func safe_evaluate(condition: JuicyCondition, context: JuicyContext) -> bool:
    if not condition or not condition.enabled:
        return false
    
    try:
        return condition.evaluate(context)
    except:
        push_error("条件评估失败")
        return false
```

### 3. 调试技巧

```gdscript
# 条件调试信息
func debug_condition(condition: JuicyCondition, context: JuicyContext) -> void:
    print("条件描述: ", condition.get_description())
    print("条件类型: ", condition.get_class())
    print("启用状态: ", condition.enabled)
    
    if condition is JuicyParameterCondition:
        var param_cond = condition as JuicyParameterCondition
        var param_value = context.get_parameter(param_cond.parameter_name, 0.0)
        print("参数值: ", param_value, " 目标值: ", param_cond.target_value)
    
    var result = condition.evaluate(context)
    print("评估结果: ", result)
```

## 高级用法

### 1. 动态条件修改

```gdscript
# 运行时修改条件
func update_condition_dynamically(context: JuicyContext):
    var condition = context.get_parameter("skill_condition") as JuicyParameterCondition
    
    # 根据玩家等级动态调整要求
    var player_level = context.get_parameter("player_level", 1.0)
    condition.target_value = player_level * 10.0
    
    # 通知条件变化
    condition.on_parameter_changed("player_level", player_level - 1.0, player_level)
```

### 2. 条件组合模式

```gdscript
# 创建可重用的条件模板
func create_health_threshold_condition(threshold: float) -> JuicyParameterCondition:
    var condition = JuicyParameterCondition.new()
    condition.parameter_name = "health"
    condition.operator = JuicyParameterCondition.ComparisonOperator.LESS_THAN
    condition.target_value = threshold
    return condition

# 使用模板创建不同难度的条件
func create_difficulty_conditions(difficulty: int) -> JuicyCompositeCondition:
    var composite = JuicyCompositeCondition.new()
    composite.operator = JuicyCompositeCondition.LogicalOperator.AND
    
    # 根据难度调整血量阈值
    var health_threshold = 50.0 - (difficulty * 10.0)
    composite.conditions.append(create_health_threshold_condition(health_threshold))
    
    # 添加其他条件...
    
    return composite
```

### 3. 条件序列化

```gdscript
# 保存条件配置
func serialize_condition(condition: JuicyCondition) -> Dictionary:
    var data = {
        "type": condition.get_class(),
        "enabled": condition.enabled
    }
    
    if condition is JuicyParameterCondition:
        var param_cond = condition as JuicyParameterCondition
        data["parameter_name"] = param_cond.parameter_name
        data["operator"] = param_cond.operator
        data["target_value"] = param_cond.target_value
        data["tolerance"] = param_cond.tolerance
    
    elif condition is JuicyTimeCondition:
        var time_cond = condition as JuicyTimeCondition
        data["time_operator"] = time_cond.time_operator
        data["target_time"] = time_cond.target_time
        data["use_progress"] = time_cond.use_progress
    
    elif condition is JuicyCompositeCondition:
        var comp_cond = condition as JuicyCompositeCondition
        data["operator"] = comp_cond.operator
        data["conditions"] = []
        for sub_cond in comp_cond.conditions:
            data["conditions"].append(serialize_condition(sub_cond))
    
    return data

# 加载条件配置
func deserialize_condition(data: Dictionary) -> JuicyCondition:
    var condition: JuicyCondition
    
    match data["type"]:
        "JuicyParameterCondition":
            condition = JuicyParameterCondition.new()
            condition.parameter_name = data["parameter_name"]
            condition.operator = data["operator"]
            condition.target_value = data["target_value"]
            condition.tolerance = data.get("tolerance", 0.0001)
        
        "JuicyTimeCondition":
            condition = JuicyTimeCondition.new()
            condition.time_operator = data["time_operator"]
            condition.target_time = data["target_time"]
            condition.use_progress = data.get("use_progress", false)
        
        "JuicyCompositeCondition":
            condition = JuicyCompositeCondition.new()
            condition.operator = data["operator"]
            for sub_data in data["conditions"]:
                condition.conditions.append(deserialize_condition(sub_data))
    
    if condition:
        condition.enabled = data.get("enabled", true)
    
    return condition
```

## 常见问题与解决方案

### 1. 条件不触发

**问题**：条件配置正确但效果不触发

**解决方案**：
1. 检查条件是否启用（`enabled = true`）
2. 验证参数名称是否正确
3. 确认参数值是否在预期范围内
4. 使用调试信息查看评估过程

### 2. 性能问题

**问题**：复杂条件导致性能下降

**解决方案**：
1. 优化条件顺序，将最可能失败的条件放在前面
2. 使用短路评估机制
3. 减少嵌套层级
4. 启用条件缓存

### 3. 条件验证失败

**问题**：条件配置验证不通过

**解决方案**：
1. 检查参数名称是否为空
2. 确认时间值是否为负数
3. 验证复合条件是否包含子条件
4. 使用`validate_condition()`方法检查具体错误

## 总结

条件系统为JuicyMixer V3提供了强大的动态控制能力，使游戏反馈效果能够根据游戏状态和上下文信息进行智能响应。通过合理使用参数条件、时间条件和复合条件，开发者可以创建出丰富、动态且高性能的游戏效果。

关键要点：
- 选择合适的条件类型
- 利用性能优化机制
- 遵循最佳实践
- 进行充分的测试和调试

条件系统是构建响应式游戏反馈的重要工具，掌握其使用方法将大大提升游戏的表现力和玩家体验。