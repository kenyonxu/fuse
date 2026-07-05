# JuicyMixer V3 联觉组合系统重新设计文档

## 概述

本文档基于对JuicyMixer真实架构的深入分析，重新设计了联觉组合系统。新设计解决了原文档中的关键问题，确保与现有的Resource-Data架构保持一致，并实现真正的Context驱动参数映射和变体系统。

## 核心设计原则

### 1. Resource-Data分层架构
- **Resource层**：作为容器和管理器，负责驱动器创建和整体配置
- **Data层**：承载具体的反馈效果参数，是参数操作的目标

### 2. Resource配置 + Context执行的动态参数
- **Resource层面**：JuicyCompositeResource携带参数映射配置（静态配置）
- **Context层面**：Driver在运行时处理参数映射（动态执行）
- **执行流程**：Resource配置 → Driver读取 → Context执行
- 支持实时参数更新和混音台功能
- 保持Resource作为配置载体的设计理念

### 3. Composite组合系统
- 组合多个JuicyFeedbackResource
- 通过统一的JuicyCompositeDriver管理
- 支持权重、混合模式和条件执行

### 4. Data级别的变体系统
- Variant系统专门针对Composite Resource
- 通过Data覆盖实现变体，避免Resource嵌套
- 支持细粒度的属性覆盖和替换

## 系统架构图

```mermaid
graph TD
    A[JuicyCompositeResource] --> B[Array[JuicyCompositeItem]]
    B --> C[JuicyCompositeItem]
    C --> D[JuicyFeedbackResource]
    D --> E[Array[JuicyFeedbackData]]
    E --> F[具体Data类: ShakeData, TweenData等]
    
    G[JuicyCompositeDriver] --> H[Context参数管理]
    H --> I[动态参数映射]
    I --> F
    
    J[JuicyResourceVariant] --> K[DataOverride]
    K --> F
    
    L[JuicyParameterBinding] --> M[输入参数]
    M --> N[曲线映射]
    N --> F
```

## 核心组件设计

### 1. JuicyCompositeResource（组合资源）

**文件路径**：`addons/juicy_mixer/resources/juicy_composite_resource.gd`

**核心职责**：
- 定义效果组合的配置结构
- 管理多个JuicyFeedbackResource的组合
- 支持参数绑定系统
- 提供混合模式和权重控制

**详细实现**：

```gdscript
@tool
class_name JuicyCompositeResource
extends JuicyFeedbackResource

# 组合混合模式
enum CompositeBlendMode {
    ADDITIVE,           # 叠加
    MULTIPLICATIVE,     # 乘法
    OVERRIDE,          # 覆盖
    WEIGHTED_AVERAGE    # 加权平均
}

# 组合配置
@export var composite_items: Array[JuicyCompositeItem] = []
@export var blend_mode: CompositeBlendMode = CompositeBlendMode.ADDITIVE
@export var normalize_weights: bool = true
@export var dynamic_weight_adjustment: bool = false

# 联觉系统配置
@export var parameter_mappings: Array[JuicyParameterMapping] = []
@export var enable_parameter_mapping: bool = false
@export var auto_update_parameters: bool = true

func create_drivers() -> Array[JuicyDriver]:
    var driver = JuicyCompositeDriver.new()
    driver.composite_resource = self
    return [driver]

func validate_config() -> ValidationResult:
    var result = super.validate_config()
    
    if composite_items.is_empty():
        result.valid = false
        result.issues.append("Composite items cannot be empty")
    
    # 验证每个组合项
    for i in range(composite_items.size()):
        var item = composite_items[i]
        if not item.resource:
            result.valid = false
            result.issues.append("Resource cannot be null at index " + str(i))
        
        if item.weight < 0.0:
            result.valid = false
            result.issues.append("Weight cannot be negative at index " + str(i))
    
    # 验证参数映射
    if enable_parameter_mapping:
        for i in range(parameter_mappings.size()):
            var mapping = parameter_mappings[i]
            var mapping_error = mapping.validate_mapping()
            if not mapping_error.is_empty():
                result.valid = false
                result.issues.append("Parameter mapping error at index " + str(i) + ": " + mapping_error)
    
    return result
```

### 2. JuicyCompositeItem（组合项）

**文件路径**：`addons/juicy_mixer/resources/juicy_composite_item.gd`

```gdscript
@tool
class_name JuicyCompositeItem
extends Resource

# 组合项数据结构
@export var resource: JuicyFeedbackResource
@export var weight: float = 1.0
@export var condition: JuicyCondition = null    # 条件对象，用于动态控制是否启用该项
@export var enabled: bool = true
@export var priority: int = 0

func validate_item() -> String:
    if not resource:
        return "Resource cannot be null"
    
    if weight < 0.0:
        return "Weight cannot be negative"
    
    # 验证条件
    if condition:
        var condition_error = condition.validate_condition()
        if not condition_error.is_empty():
            return "Condition error: " + condition_error
    
    return ""  # 验证通过

func get_description() -> String:
    var desc = resource.resource_path if resource else "None"
    desc += " (weight: %.2f, priority: %d)" % [weight, priority]
    if condition:
        desc += " [condition: %s]" % condition.get_description()
    return desc
```

### 3. JuicyCompositeDriver（组合驱动器）

**文件路径**：`addons/juicy_mixer/drivers/juicy_composite_driver.gd`

**核心职责**：
- 执行效果组合
- 管理混合模式和权重
- 处理动态参数映射
- 支持实时参数更新

**详细实现**：

```gdscript
class_name JuicyCompositeDriver
extends JuicyDriver

# 组合状态
class CompositeState:
    var active_contexts: Array[String] = []
    var item_weights: Dictionary = {}
    var blend_progress: float = 0.0
    var parameter_values: Dictionary = {}

var composite_resource: JuicyCompositeResource
var _composite_states: Dictionary = {}

func _init():
    driver_name = "JuicyCompositeDriver"
    supported_properties = []

func prepare(context: JuicyContext) -> void:
    var state = CompositeState.new()
    
    # 计算权重
    var total_weight = 0.0
    for item in composite_resource.composite_items:
        if item.enabled and item.resource:
            # 使用条件对象评估
            if item.condition and not item.condition.evaluate(context):
                continue
            total_weight += item.weight
    
    # 创建子上下文并初始化Data实例
    for i in range(composite_resource.composite_items.size()):
        var item = composite_resource.composite_items[i]
        if not item.enabled or not item.resource:
            continue
        
        # 动态条件检查
        if item.condition and not item.condition.evaluate(context):
            continue
        
        var item_context = _create_item_context(context, item)
        var context_id = JuicyMixer.play(item.resource, context.target)
        state.active_contexts.append(context_id)
        
        # 计算标准化权重
        var normalized_weight = item.weight / total_weight if total_weight > 0 else 0.0
        if composite_resource.normalize_weights:
            state.item_weights[context_id] = normalized_weight
        else:
            state.item_weights[context_id] = item.weight
        
        # 注意：不再需要Data实例管理，参数映射通过PropertyBuffer处理
    
    # 初始化参数映射（从Resource配置到Context执行）
    if composite_resource.enable_parameter_mapping:
        _setup_parameter_mappings_from_resource(context, state)
    
    _composite_states[context.context_id] = state

func process(context: JuicyContext, delta: float, buffer: JuicyPropertyBuffer) -> void:
    var state = _composite_states.get(context.context_id)
    if not state:
        return
    
    # 更新混合进度
    state.blend_progress = min(state.blend_progress + delta, 1.0)
    
    # 实时更新参数映射
    if composite_resource.enable_parameter_mapping and composite_resource.auto_update_parameters:
        _update_parameter_mappings(context, state, delta)
    
    # 应用混合模式
    _apply_blend_mode(context, state, buffer)

# 设置参数值（混音台核心功能）
func set_parameter(context_id: String, parameter_name: String, value: float) -> void:
    var context = JuicyMixer.get_context(context_id)
    if not context:
        return
    
    # 更新Context中的参数值
    context.set_parameter(parameter_name, value)
    
    # 立即应用参数映射到所有子上下文
    _apply_parameter_mappings(context, parameter_name, value)

# 从Resource配置设置参数映射到Context
func _setup_parameter_mappings_from_resource(context: JuicyContext, state: CompositeState) -> void:
    for mapping in composite_resource.parameter_mappings:
        if not mapping.enabled:
            continue
        
        if mapping.target_item_index >= composite_resource.composite_items.size():
            continue
        
        var item = composite_resource.composite_items[mapping.target_item_index]
        if not item.resource:
            continue
        
        # 为每个参数映射创建目标
        var target_context_id = state.active_contexts[mapping.target_item_index]
        context.add_parameter_mapping(
            mapping.input_parameter,
            target_context_id,
            mapping.target_property,
            mapping.curve
        )

# 应用参数映射到所有目标
func _apply_parameter_mappings(context: JuicyContext, parameter_name: String, value: float) -> void:
    var mappings = context._parameter_mappings.get(parameter_name, [])
    for target in mappings:
        if not target.enabled:
            continue
        
        var target_context = JuicyMixer.get_context(target.context_id)
        if not target_context or not target_context.property_buffer:
            continue
        
        # 使用曲线映射值
        var mapped_value = value
        if target.curve:
            mapped_value = target.curve.sample(value)
        
        # 通过PropertyBuffer设置属性
        target_context.property_buffer.add_middleware_sample(
            target_context.target,
            target.property_path,
            mapped_value,
            JuicyPropertyBuffer.BlendMode.OVERRIDE_BASE,
            "parameter_mapping",
            100  # 高优先级确保参数映射生效
        )

# 实时更新参数映射
func _update_parameter_mappings(context: JuicyContext, state: CompositeState, delta: float) -> void:
    # 动态检查条件变化
    _update_active_items_based_on_conditions(context, state)
    
    # 获取所有参数值并应用映射
    for parameter_name in context._dynamic_parameters:
        var value = context._dynamic_parameters[parameter_name]
        _apply_parameter_mappings(context, parameter_name, value)

# 动态更新基于条件的活跃项
func _update_active_items_based_on_conditions(context: JuicyContext, state: CompositeState) -> void:
    """根据条件变化动态更新活跃的组合项"""
    for i in range(composite_resource.composite_items.size()):
        var item = composite_resource.composite_items[i]
        if not item.enabled or not item.resource:
            continue
        
        var should_be_active = true
        if item.condition:
            should_be_active = item.condition.evaluate(context)
        
        # 检查当前状态并更新
        var context_id = state.active_contexts[i] if i < state.active_contexts.size() else ""
        var is_currently_active = not context_id.is_empty()
        
        if should_be_active and not is_currently_active:
            # 需要激活该项
            var item_context = _create_item_context(context, item)
            var new_context_id = JuicyMixer.play(item.resource, context.target)
            state.active_contexts[i] = new_context_id
        elif not should_be_active and is_currently_active:
            # 需要停用该项
            JuicyMixer.stop(context_id)
            state.active_contexts[i] = ""

func _apply_blend_mode(context: JuicyContext, state: CompositeState, buffer: JuicyPropertyBuffer) -> void:
    match composite_resource.blend_mode:
        JuicyCompositeResource.CompositeBlendMode.ADDITIVE:
            _apply_additive_blend(state, buffer)
        JuicyCompositeResource.CompositeBlendMode.MULTIPLICATIVE:
            _apply_multiplicative_blend(state, buffer)
        JuicyCompositeResource.CompositeBlendMode.OVERRIDE:
            _apply_override_blend(state, buffer)
        JuicyCompositeResource.CompositeBlendMode.WEIGHTED_AVERAGE:
            _apply_weighted_average_blend(state, buffer)

func _apply_additive_blend(state: CompositeState, buffer: JuicyPropertyBuffer) -> void:
    for context_id in state.active_contexts:
        var weight = state.item_weights.get(context_id, 1.0)
        var item_context = JuicyMixer.get_context(context_id)
        if item_context and item_context.property_buffer:
            buffer.add_buffer(item_context.property_buffer, weight)

func _apply_multiplicative_blend(state: CompositeState, buffer: JuicyPropertyBuffer) -> void:
    for context_id in state.active_contexts:
        var weight = state.item_weights.get(context_id, 1.0)
        var item_context = JuicyMixer.get_context(context_id)
        if item_context and item_context.property_buffer:
            buffer.multiply_buffer(item_context.property_buffer, weight)

func _apply_override_blend(state: CompositeState, buffer: JuicyPropertyBuffer) -> void:
    for context_id in state.active_contexts:
        var item_context = JuicyMixer.get_context(context_id)
        if item_context and item_context.property_buffer:
            buffer.copy_from(item_context.property_buffer)
            break  # 只使用第一个有效项

func _apply_weighted_average_blend(state: CompositeState, buffer: JuicyPropertyBuffer) -> void:
    var total_weight = 0.0
    for context_id in state.active_contexts:
        total_weight += state.item_weights.get(context_id, 1.0)
    
    if total_weight <= 0.0:
        return
    
    for context_id in state.active_contexts:
        var weight = state.item_weights.get(context_id, 1.0) / total_weight
        var item_context = JuicyMixer.get_context(context_id)
        if item_context and item_context.property_buffer:
            buffer.add_buffer(item_context.property_buffer, weight)

func cleanup(context: JuicyContext) -> void:
    var state = _composite_states.get(context.context_id)
    if state:
        # 停止所有活跃的子上下文
        for context_id in state.active_contexts:
            JuicyMixer.stop(context_id)
        
        _composite_states.erase(context.context_id)
    
    # 清理Context中的参数映射
    context.clear_parameter_mappings()
```

### 4. JuicyParameterMapping（参数映射配置）

**文件路径**：`addons/juicy_mixer/resources/juicy_parameter_mapping.gd`

```gdscript
@tool
class_name JuicyParameterMapping
extends Resource

# 参数映射配置 - Resource层面的静态配置
@export var input_parameter: String = "intensity"  # 外部输入的参数名
@export var target_item_index: int = 0           # 绑定到Composite中的哪个子Resource
@export var target_property: String = ""          # 绑定到Resource的哪个属性
@export var curve: Curve                         # 映射曲线
@export var enabled: bool = true

# 验证映射配置
func validate_mapping() -> String:
    if input_parameter.is_empty():
        return "Input parameter cannot be empty"
    
    if target_property.is_empty():
        return "Target property cannot be empty"
    
    if target_item_index < 0:
        return "Target item index cannot be negative"
    
    return ""  # 验证通过

# 获取映射的描述信息
func get_description() -> String:
    var desc = "%s -> item[%d].%s" % [
        input_parameter, target_item_index, target_property
    ]
    if curve:
        desc += " (with curve mapping)"
    return desc
```

### 5. JuicyResourceVariant（变体系统）

**文件路径**：`addons/juicy_mixer/resources/juicy_resource_variant.gd`

```gdscript
@tool
class_name JuicyResourceVariant
extends JuicyFeedbackResource

# 变体配置
@export var base_composite_resource: JuicyCompositeResource
@export var data_overrides: Array[DataOverride] = []
@export var inherit_parameter_bindings: bool = true

func create_drivers() -> Array[JuicyDriver]:
    # 创建变体化的CompositeResource
    var variant_composite = _create_variant_composite()
    return variant_composite.create_drivers()

func _create_variant_composite() -> JuicyCompositeResource:
    if not base_composite_resource:
        push_error("Base composite resource cannot be null")
        return null
    
    # 深拷贝基础CompositeResource
    var variant = base_composite_resource.duplicate(true)
    
    # 应用Data覆盖
    for override in data_overrides:
        if not override.enabled:
            continue
        _apply_data_override(variant, override)
    
    return variant

func _apply_data_override(composite: JuicyCompositeResource, override: DataOverride) -> void:
    match override.override_mode:
        DataOverride.OverrideMode.REPLACE_DATA:
            _replace_data(composite, override)
        DataOverride.OverrideMode.MODIFY_DATA:
            _modify_data(composite, override)
        DataOverride.OverrideMode.ADD_TO_COMPOSITE:
            _add_to_composite(composite, override)
        DataOverride.OverrideMode.REMOVE_FROM_COMPOSITE:
            _remove_from_composite(composite, override)

func _replace_data(composite: JuicyCompositeResource, override: DataOverride) -> void:
    if override.target_item_index >= composite.composite_items.size():
        return
    
    var item = composite.composite_items[override.target_item_index]
    if not item.resource:
        return
    
    var resource = item.resource
    var data_array = _get_data_array(resource)
    if override.target_data_index >= data_array.size():
        return
    
    # 替换Data实例
    data_array[override.target_data_index] = override.new_data.duplicate()

func _modify_data(composite: JuicyCompositeResource, override: DataOverride) -> void:
    if override.target_item_index >= composite.composite_items.size():
        return
    
    var item = composite.composite_items[override.target_item_index]
    if not item.resource:
        return
    
    var resource = item.resource
    var data_array = _get_data_array(resource)
    if override.target_data_index >= data_array.size():
        return
    
    # 修改Data属性
    var data = data_array[override.target_data_index]
    if data:
        for property_name in override.property_overrides:
            if property_name in data:
                data.set(property_name, override.property_overrides[property_name])

func _get_data_array(resource: JuicyFeedbackResource) -> Array:
    if resource is JuicyShakeResource:
        return resource.shake_data
    elif resource is JuicyTweenResource:
        return resource.tween_data
    elif resource is JuicySpringResource:
        return resource.spring_data
    elif resource is JuicyAnimationPlayResource:
        return resource.animation_data
    else:
        return []

func validate_config() -> ValidationResult:
    var result = super.validate_config()
    
    if not base_composite_resource:
        result.valid = false
        result.issues.append("Base composite resource cannot be null")
    
    for i in range(data_overrides.size()):
        var override = data_overrides[i]
        var override_error = override.validate_override()
        if not override_error.is_empty():
            result.valid = false
            result.issues.append("Data override error at index " + str(i) + ": " + override_error)
    
    return result
```

### 6. DataOverride（数据覆盖）

**文件路径**：`addons/juicy_mixer/resources/data_override.gd`

```gdscript
@tool
class_name DataOverride
extends Resource

# 覆盖模式枚举
enum OverrideMode {
    REPLACE_DATA,        # 替换整个Data
    MODIFY_DATA,         # 修改Data的特定属性
    ADD_TO_COMPOSITE,    # 添加新的CompositeItem
    REMOVE_FROM_COMPOSITE # 从Composite移除Item
}

# 覆盖配置
@export var override_mode: OverrideMode = OverrideMode.REPLACE_DATA
@export var target_item_index: int = -1     # 目标CompositeItem索引
@export var target_data_index: int = -1      # 目标Data索引
@export var new_data: JuicyFeedbackData      # 新Data（用于REPLACE_DATA模式）
@export var property_overrides: Dictionary = {} # 属性覆盖（用于MODIFY_DATA模式）
@export var new_composite_item: JuicyCompositeItem # 新CompositeItem（用于ADD_TO_COMPOSITE）
@export var enabled: bool = true

func validate_override() -> String:
    if override_mode == OverrideMode.REPLACE_DATA and not new_data:
        return "New data cannot be null when override_mode is REPLACE_DATA"
    
    if override_mode == OverrideMode.ADD_TO_COMPOSITE and not new_composite_item:
        return "New composite item cannot be null when override_mode is ADD_TO_COMPOSITE"
    
    if target_item_index < 0 and override_mode != OverrideMode.ADD_TO_COMPOSITE:
        return "Target item index cannot be negative"
    
    if target_data_index < 0 and override_mode in [OverrideMode.REPLACE_DATA, OverrideMode.MODIFY_DATA]:
        return "Target data index cannot be negative"
    
    return ""  # 验证通过

func get_description() -> String:
    var desc = "%s" % OverrideMode.keys()[override_mode]
    match override_mode:
        OverrideMode.REPLACE_DATA:
            desc += " -> item[%d].data[%d]" % [target_item_index, target_data_index]
        OverrideMode.MODIFY_DATA:
            desc += " -> item[%d].data[%d].properties" % [target_item_index, target_data_index]
        OverrideMode.ADD_TO_COMPOSITE:
            desc += " -> new item"
        OverrideMode.REMOVE_FROM_COMPOSITE:
            desc += " -> item[%d]" % target_item_index
    return desc
```

## 条件系统设计

### 1. JuicyCondition（条件基类）

**文件路径**：`addons/juicy_mixer/conditions/juicy_condition.gd`

```gdscript
# JuicyCondition - 条件基类
# 定义所有条件类型的通用接口，提供条件评估的基础框架

@tool
@abstract
class_name JuicyCondition
extends Resource

# 条件启用状态
@export var enabled: bool = true

# 虚拟方法 - 子类必须实现
@abstract
func evaluate(context: JuicyContext) -> bool

# 获取条件描述
@abstract
func get_description() -> String

# 验证条件配置
@abstract
func validate_condition() -> String

# 条件变化通知（可选实现）
@abstract
func on_parameter_changed(parameter_name: String, old_value: float, new_value: float) -> void
```

### 2. JuicyParameterCondition（参数条件类）

**文件路径**：`addons/juicy_mixer/conditions/juicy_parameter_condition.gd`

```gdscript
# JuicyParameterCondition - 参数条件类
# 用于比较Context中的参数值与目标值

@tool
class_name JuicyParameterCondition
extends JuicyCondition

# 参数比较操作符
enum ComparisonOperator {
    GREATER_THAN,        # >
    LESS_THAN,           # <
    GREATER_EQUAL,       # >=
    LESS_EQUAL,          # <=
    EQUAL,               # ==
    NOT_EQUAL            # !=
}

# 条件配置
@export var parameter_name: String = ""           # 参数名
@export var operator: ComparisonOperator = ComparisonOperator.EQUAL
@export var target_value: float = 0.0           # 目标值
@export var tolerance: float = 0.0001           # 浮点数比较容差

# 上次评估结果（用于缓存优化）
var _last_evaluation: bool = false
var _last_parameter_value: float = 0.0

func evaluate(context: JuicyContext) -> bool:
    if not enabled or parameter_name.is_empty():
        return false
    
    # 从Context获取参数值
    var current_value = context.get_parameter(parameter_name, 0.0)
    
    # 缓存优化：如果参数值没有变化，返回上次结果
    if abs(current_value - _last_parameter_value) < tolerance:
        return _last_evaluation
    
    _last_parameter_value = current_value
    
    # 执行比较
    match operator:
        ComparisonOperator.GREATER_THAN:
            _last_evaluation = current_value > target_value
        ComparisonOperator.LESS_THAN:
            _last_evaluation = current_value < target_value
        ComparisonOperator.GREATER_EQUAL:
            _last_evaluation = current_value >= target_value
        ComparisonOperator.LESS_EQUAL:
            _last_evaluation = current_value <= target_value
        ComparisonOperator.EQUAL:
            _last_evaluation = abs(current_value - target_value) <= tolerance
        ComparisonOperator.NOT_EQUAL:
            _last_evaluation = abs(current_value - target_value) > tolerance
        _:
            _last_evaluation = false
    
    return _last_evaluation

func get_description() -> String:
    var op_str = ""
    match operator:
        ComparisonOperator.GREATER_THAN:
            op_str = ">"
        ComparisonOperator.LESS_THAN:
            op_str = "<"
        ComparisonOperator.GREATER_EQUAL:
            op_str = ">="
        ComparisonOperator.LESS_EQUAL:
            op_str = "<="
        ComparisonOperator.EQUAL:
            op_str = "=="
        ComparisonOperator.NOT_EQUAL:
            op_str = "!="
    
    return "%s %s %.3f" % [parameter_name, op_str, target_value]

func validate_condition() -> String:
    if parameter_name.is_empty():
        return "Parameter name cannot be empty"
    return ""

func on_parameter_changed(parameter_name: String, old_value: float, new_value: float) -> void:
    # 如果是相关参数，清除缓存
    if parameter_name == self.parameter_name:
        _last_parameter_value = float.NAN  # 强制重新评估
```

### 3. JuicyCompositeCondition（复合条件类）

**文件路径**：`addons/juicy_mixer/conditions/juicy_composite_condition.gd`

```gdscript
# JuicyCompositeCondition - 复合条件类
# 用于组合多个条件形成复杂的逻辑表达式

@tool
class_name JuicyCompositeCondition
extends JuicyCondition

# 逻辑操作符
enum LogicalOperator {
    AND,    # 所有条件都必须满足
    OR       # 至少一个条件满足
}

# 复合条件配置
@export var operator: LogicalOperator = LogicalOperator.AND
@export var conditions: Array[JuicyCondition] = []

# 短路评估优化
var _short_circuit_result: Dictionary = {}

func evaluate(context: JuicyContext) -> bool:
    if not enabled or conditions.is_empty():
        return true
    
    # 生成上下文唯一标识（用于短路评估缓存）
    var context_key = _generate_context_key(context)
    
    # 检查缓存
    if _short_circuit_result.has(context_key):
        return _short_circuit_result[context_key]
    
    var result = false
    
    match operator:
        LogicalOperator.AND:
            # 所有条件都必须满足（短路评估）
            result = true
            for condition in conditions:
                if not condition.evaluate(context):
                    result = false
                    break  # 短路：只要有一个条件不满足，整个AND表达式为false
        
        LogicalOperator.OR:
            # 至少一个条件满足（短路评估）
            result = false
            for condition in conditions:
                if condition.evaluate(context):
                    result = true
                    break  # 短路：只要有一个条件满足，整个OR表达式为true
        
        _:
            result = false
    
    # 缓存结果
    _short_circuit_result[context_key] = result
    return result

func get_description() -> String:
    var op_str = operator == LogicalOperator.AND ? "AND" : "OR"
    var descriptions = []
    for condition in conditions:
        descriptions.append(condition.get_description())
    return "(%s)" % (" %s " % op_str).join(descriptions)

func validate_condition() -> String:
    if conditions.is_empty():
        return "Composite condition must have at least one sub-condition"
    
    for i in range(conditions.size()):
        var condition = conditions[i]
        if not condition:
            return "Condition at index %d is null" % i
        
        var error = condition.validate_condition()
        if not error.is_empty():
            return "Sub-condition %d error: %s" % [i, error]
    
    return ""

# 清除缓存（当参数变化时调用）
func clear_cache() -> void:
    _short_circuit_result.clear()
    
    # 递归清除子条件缓存
    for condition in conditions:
        if condition.has_method("clear_cache"):
            condition.clear_cache()

func _generate_context_key(context: JuicyContext) -> String:
    """生成用于缓存的上下文唯一标识"""
    var key_parts = [context.context_id]
    
    # 添加相关参数值到key中
    for condition in conditions:
        if condition is JuicyParameterCondition:
            var param_cond = condition as JuicyParameterCondition
            var param_value = context.get_parameter(param_cond.parameter_name, 0.0)
            key_parts.append("%s:%.3f" % [param_cond.parameter_name, param_value])
    
    return "|".join(key_parts)
```

### 4. JuicyTimeCondition（时间条件类）

**文件路径**：`addons/juicy_mixer/conditions/juicy_time_condition.gd`

```gdscript
# JuicyTimeCondition - 时间条件类
# 用于基于时间的条件判断

@tool
class_name JuicyTimeCondition
extends JuicyCondition

# 时间比较操作符
enum TimeOperator {
    AFTER_START,        # 效果开始后
    BEFORE_END,         # 效果结束前
    DURATION_GREATER,   # 持续时间大于
    DURATION_LESS,       # 持续时间小于
    PROGRESS_GREATER,    # 进度大于
    PROGRESS_LESS        # 进度小于
}

# 时间条件配置
@export var time_operator: TimeOperator = TimeOperator.AFTER_START
@export var target_time: float = 0.0
@export var use_progress: bool = false  # 使用进度而非绝对时间

func evaluate(context: JuicyContext) -> bool:
    if not enabled:
        return false
    
    match time_operator:
        TimeOperator.AFTER_START:
            return context.current_time >= target_time
        TimeOperator.BEFORE_END:
            return context.current_time <= (context.duration - target_time)
        TimeOperator.DURATION_GREATER:
            return context.duration > target_time
        TimeOperator.DURATION_LESS:
            return context.duration < target_time
        TimeOperator.PROGRESS_GREATER:
            return context.progress > target_time
        TimeOperator.PROGRESS_LESS:
            return context.progress < target_time
        _:
            return false

func get_description() -> String:
    var op_str = ""
    match time_operator:
        TimeOperator.AFTER_START:
            op_str = "after %.2fs"
        TimeOperator.BEFORE_END:
            op_str = "before end by %.2fs"
        TimeOperator.DURATION_GREATER:
            op_str = "duration > %.2fs"
        TimeOperator.DURATION_LESS:
            op_str = "duration < %.2fs"
        TimeOperator.PROGRESS_GREATER:
            op_str = "progress > %.1f%%"
        TimeOperator.PROGRESS_LESS:
            op_str = "progress < %.1f%%"
    
    return "time %s" % op_str

func validate_condition() -> String:
    if target_time < 0:
        return "Target time cannot be negative"
    return ""
```

## Context系统扩展

### JuicyContext增强

为了支持动态参数映射，需要扩展JuicyContext：

```gdscript
# JuicyContext中的参数管理扩展
class_name JuicyContext
extends RefCounted

# 动态参数存储
var _dynamic_parameters: Dictionary = {}

# 参数映射配置（由Driver从Resource设置）
var _parameter_mappings: Dictionary = {}  # parameter_name -> Array[MappingTarget]

# 映射目标定义
class MappingTarget:
    var context_id: String          # 目标子上下文ID
    var property_path: String       # 属性路径（如"amplitude", "volume_db"）
    var curve: Curve              # 映射曲线
    var enabled: bool = true

# 设置参数值
func set_parameter(parameter_name: String, value: float) -> void:
    _dynamic_parameters[parameter_name] = value
    # 注意：不再在这里直接应用映射，由Driver统一处理

# 获取参数值
func get_parameter(parameter_name: String, default_value: float = 0.0) -> float:
    return _dynamic_parameters.get(parameter_name, default_value)

# 添加参数映射（由Driver调用）
func add_parameter_mapping(parameter_name: String, target_context_id: String,
                         property_path: String, curve: Curve = null) -> void:
    if not _parameter_mappings.has(parameter_name):
        _parameter_mappings[parameter_name] = []
    
    var target = MappingTarget.new()
    target.context_id = target_context_id
    target.property_path = property_path
    target.curve = curve
    
    _parameter_mappings[parameter_name].append(target)
```

## 实际使用示例

### 1. 创建基础组合效果

```gdscript
# 创建一个充能效果的组合资源
var charge_composite = JuicyCompositeResource.new()

# 添加视觉效果
var shake_resource = JuicyShakeResource.new()
var shake_data = ShakeData.new()
shake_data.property = "position"
shake_data.amplitude = 5.0
shake_data.frequency = 15.0
shake_data.duration = 1.0
shake_resource.shake_data = [shake_data]

var shake_item = JuicyCompositeItem.new()
shake_item.resource = shake_resource
shake_item.weight = 1.0

# 添加音效
var audio_resource = JuicyAudioResource.new()
var audio_data = AudioData.new()
audio_data.volume_db = -10.0
audio_resource.audio_data = [audio_data]

var audio_item = JuicyCompositeItem.new()
audio_item.resource = audio_resource
audio_item.weight = 1.0

# 添加弹簧效果
var spring_resource = JuicySpringResource.new()
var spring_data = SpringData.new()
spring_data.property = "scale"
spring_data.target_value = Vector2(1.2, 1.2)
spring_data.stiffness = 200.0
spring_data.damping = 15.0
spring_resource.spring_data = [spring_data]

var spring_item = JuicyCompositeItem.new()
spring_item.resource = spring_resource
spring_item.weight = 1.0

charge_composite.composite_items = [shake_item, audio_item, spring_item]
```

### 2. 配置参数映射

```gdscript
# 启用参数映射
charge_composite.enable_parameter_mapping = true

# 在Resource层面配置参数映射
var charge_to_shake = JuicyParameterMapping.new()
charge_to_shake.input_parameter = "charge_amount"
charge_to_shake.target_item_index = 0  # 震动效果
charge_to_shake.target_property = "amplitude"
charge_to_shake.curve = preload("res://curves/charge_to_shake.tres")  # 0-1 -> 0-10

var charge_to_audio = JuicyParameterMapping.new()
charge_to_audio.input_parameter = "charge_amount"
charge_to_audio.target_item_index = 1  # 音效
charge_to_audio.target_property = "volume_db"
charge_to_audio.curve = preload("res://curves/charge_to_audio.tres")  # 0-1 -> -10到0

var charge_to_spring = JuicyParameterMapping.new()
charge_to_spring.input_parameter = "charge_amount"
charge_to_spring.target_item_index = 2  # 弹簧效果
charge_to_spring.target_property = "target_value"
charge_to_spring.curve = preload("res://curves/charge_to_scale.tres")  # 0-1 -> 1.0-1.5

charge_composite.parameter_mappings = [
    charge_to_shake,
    charge_to_audio,
    charge_to_spring
]

# 播放效果（Driver会自动处理参数映射和条件）
var context_id = JuicyMixer.play(charge_composite, player)
```

### 4. 运行时使用

```gdscript
# 在游戏中使用（参数映射已在Resource中配置）
func update_charge(amount: float):
    var context = JuicyMixer.get_context(context_id)
    if context:
        # 设置参数值（Driver会自动处理映射）
        context.set_parameter("charge_amount", amount)
        # Driver会自动将charge_amount映射到：
        # - 震动效果的amplitude属性
        # - 音效的volume_db属性
        # - 弹簧效果的target_value属性
```

### 4. 创建变体效果

```gdscript
# 创建火焰充能变体
var fire_charge_variant = JuicyResourceVariant.new()
fire_charge_variant.base_composite_resource = charge_composite

# 替换震动Data为更强力版本
var strong_shake_data = ShakeData.new()
strong_shake_data.property = "position"
strong_shake_data.amplitude = 8.0
strong_shake_data.frequency = 20.0

var shake_override = DataOverride.new()
shake_override.override_mode = DataOverride.OverrideMode.REPLACE_DATA
shake_override.target_item_index = 0  # 震动项
shake_override.target_data_index = 0   # 第一个震动数据
shake_override.new_data = strong_shake_data

# 修改音效属性
var audio_override = DataOverride.new()
audio_override.override_mode = DataOverride.OverrideMode.MODIFY_DATA
audio_override.target_item_index = 1  # 音效项
audio_override.target_data_index = 0   # 第一个音频数据
audio_override.property_overrides = {"volume_db": -5.0}  # 增强音量

# 添加新的火焰粒子效果
var particle_resource = JuicyParticleResource.new()
var particle_data = ParticleData.new()
particle_data.count = 50
particle_data.lifetime = 2.0
particle_resource.particle_data = [particle_data]

var particle_item = JuicyCompositeItem.new()
particle_item.resource = particle_resource
particle_item.weight = 0.5

var particle_override = DataOverride.new()
particle_override.override_mode = DataOverride.OverrideMode.ADD_TO_COMPOSITE
particle_override.new_composite_item = particle_item

fire_charge_variant.data_overrides = [
    shake_override,
    audio_override,
    particle_override
]

# 使用变体效果
var fire_context_id = JuicyMixer.play(fire_charge_variant, player)

# 变体效果通过继承自动支持参数映射
# 因为JuicyResourceVariant.inherit_parameter_bindings = true
# 所以变体会自动继承基础Composite的参数映射配置
```

## 开发时间线

**总体时间**：第11-14周（共4周）
- 第11-12周：基础组合系统
- 第13周：参数映射系统
- 第14周：变体系统，集成测试与优化

### 详细时间安排

#### 第11-12周：基础组合系统
- **第11周第3天**：JuicyCompositeResource基础数据结构定义
- **第11周第4天**：JuicyCompositeItem和基础配置验证
- **第12周第1天**：JuicyCompositeDriver基础组合状态管理
- **第12周第2天**：混合模式实现和Data实例管理
- **第12周第3天**：基础系统单元测试和集成测试

#### 第13周：参数映射系统
- **第1天**：JuicyParameterMapping重新设计和实现
- **第2天**：Context系统扩展和参数管理
- **第3天**：CompositeDriver参数映射集成
- **第4天**：实时参数更新和混音台功能
- **第5天**：参数映射系统测试和优化

#### 第14周：变体系统和优化
- **第1天**：JuicyResourceVariant和DataOverride重新设计
- **第2天**：Data级别的覆盖机制实现
- **第3天**：变体系统与组合系统集成
- **第4天**：系统性能优化和内存管理
- **第5天**：完整系统集成测试和文档完善

## 性能优化策略

### 1. 内存管理
- Data实例的智能缓存和复用
- 参数映射结果的缓存机制
- 变体资源的延迟加载

### 2. 执行效率
- 参数绑定的批量更新
- 混合计算的优化算法
- 条件执行的早期退出

### 3. 编辑器性能
- Data实例的序列化优化
- 参数曲线的预计算
- 变体预览的增量更新

## 测试计划

### 单元测试
- JuicyCompositeResource配置验证测试
- JuicyCompositeDriver混合模式测试
- JuicyParameterMapping映射计算测试
- JuicyResourceVariant覆盖机制测试
- JuicyCondition条件系统测试
- JuicyParameterCondition参数比较测试
- JuicyCompositeCondition复合条件测试
- JuicyCondition条件系统测试
- JuicyParameterCondition参数比较测试
- JuicyCompositeCondition复合条件测试

### 集成测试
- 组合系统集成测试
- 参数映射实时更新测试
- 变体系统创建和执行测试
- 与Director系统集成测试

### 性能测试
- 1000个组合项混合性能测试
- 参数映射实时更新性能测试
- 变体资源创建和执行性能测试
- 内存使用优化验证

## 交付检查清单

### 代码交付
- [ ] JuicyCompositeResource和JuicyCompositeItem
- [ ] JuicyCompositeDriver
- [ ] JuicyParameterMapping
- [ ] JuicyResourceVariant和DataOverride
- [ ] JuicyCondition条件系统（JuicyCondition、JuicyParameterCondition、JuicyCompositeCondition）
- [ ] Context系统扩展
- [ ] 单元测试和集成测试
- [ ] 性能基准测试

### 文档交付
- [ ] 组合系统使用文档
- [ ] 参数映射系统文档
- [ ] 变体系统文档
- [ ] API参考文档
- [ ] 性能优化指南

### 验收标准
- [ ] 所有单元测试通过（覆盖率100%）
- [ ] 所有集成测试通过
- [ ] 性能基准测试达标
- [ ] 代码审查通过
- [ ] 文档完整准确

## 风险管控

### 技术风险
1. **Data实例管理复杂性**：运行时Data实例的创建和管理可能复杂
   - 缓解措施：实现智能缓存池和生命周期管理

2. **参数映射性能**：实时参数更新可能影响性能
   - 缓解措施：实现批量更新和计算缓存

3. **变体系统复杂性**：Data级别的覆盖机制可能增加系统复杂性
   - 缓解措施：设计清晰的覆盖规则和验证机制

### 进度风险
1. **参数映射实现**：Context系统集成可能比预期复杂
   - 缓解措施：优先实现核心功能，后续扩展

2. **变体系统实现**：Data级别的覆盖可能需要更多时间
   - 缓解措施：分阶段实现，先支持基础覆盖模式

## 总结

重新设计的联觉组合系统解决了原文档中的关键问题：

1. **正确的架构理解**：基于真实的Resource-Data分层架构
2. **动态参数映射**：通过Context驱动的实时参数传递
3. **Data级别变体**：针对Data实例的精确覆盖机制
4. **性能优化**：智能缓存和批量处理策略

新设计将为JuicyMixer V3提供强大、灵活且高效的联觉体验支持，真正实现"牵一发而动全身"的混音台功能。