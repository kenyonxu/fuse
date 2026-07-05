# 联觉组合系统开发计划

## 概述

本文档详细描述了JuicyMixer V3中联觉组合系统的开发计划。该系统不仅提供基础的效果组合功能，更专注于实现**参数映射的混音台功能**，通过单一输入驱动多个感官输出，实现真正的联觉体验。

系统的核心理念是从"简单的容器"进化为"智能的混音台"，通过参数映射机制，实现一个参数驱动多个输出的高度融合感官体验。

## 系统架构

联觉组合系统由以下核心组件构成：

- **JuicyCompositeResource** - 组合资源配置（支持参数绑定）
- **JuicyCompositeDriver** - 组合效果驱动器（实现混音台功能）
- **JuicyParameterBinding** - 参数映射系统
- **JuicyResourceVariant** - 动态覆盖与继承系统

## 联觉系统的核心概念

### 1. 参数映射 (Parameter Mapping)
联觉的核心在于"通感"——一个参数驱动多个感官。通过参数绑定系统，可以实现：
- **单一输入**：如充能量值 `charge_amount` (0.0 → 1.0)
- **多输出映射**：
  - 视觉：屏幕震动强度 0 → 10
  - 听觉：音效 Pitch 0.8 → 2.0，Volume -10dB → 0dB
  - 触觉：手柄震动频率低频→高频
  - 画面：Shader Glow 强度 0 → 5

### 2. 动态覆盖与继承 (Dynamic Override & Inheritance)
实现效果的变奏和复用：
- **基础模板**：创建标准效果模板（如标准受击反馈）
- **变体覆盖**：基于模板创建变体（如火焰受击）
- **细粒度控制**：精确控制哪些参数被覆盖

## 与现有系统的集成

### Director系统扩展
- 联觉系统需要完全集成到Director的执行流程中
- 参数映射状态需要与Director的生命周期同步

### Middleware管道增强
- 联觉Driver需要通过Middleware管道执行
- 参数映射需要支持中间件拦截和修改
- 组合Driver需要支持多种混合模式

### Context系统增强
- 联觉状态需要存储在Context中
- 参数映射的当前值需要实时更新到Context

### Driver系统协同
- 联觉Driver需要能够管理子Driver的执行
- 参数映射需要跨Driver传递参数值
- 所有Driver需要支持中断和状态还原

### 事件系统协同
- 联觉执行需要生成开始、进度、完成事件
- 参数映射变化需要触发相应的事件通知

## 开发时间线

**总体时间**：第11-14周（共4周）
- 第11-12周：基础组合系统
- 第13周：参数映射系统
- 第14周：动态覆盖与继承系统，集成测试与优化

### 详细时间安排

#### 第11-12周：基础组合系统
- **第11周第3天**：JuicyCompositeResource基础数据结构定义
- **第11周第4天**：JuicyCompositeResource配置参数和验证
- **第12周第1天**：JuicyCompositeDriver基础组合状态管理
- **第12周第2天**：JuicyCompositeDriver混合模式实现
- **第12周第3天**：基础系统单元测试和集成测试

#### 第13周：参数映射系统
- **第1天**：参数绑定系统实现（JuicyCompositeResource）
- **第2天**：混音台功能实现（JuicyCompositeDriver）
- **第3天**：参数映射实时更新系统
- **第4天**：混合模式与参数映射集成
- **第5天**：参数映射系统测试和优化

#### 第14周：动态覆盖与系统优化
- **第1天**：JuicyResourceVariant数据结构定义和覆盖模式实现
- **第2天**：属性路径解析和设置系统
- **第3天**：组合资源特殊处理和继承机制
- **第4天**：系统性能优化和内存管理
- **第5天**：完整系统集成测试和文档完善

## JuicyCompositeResource (组合资源)

**文件路径**：`addons/juicy_mixer/resources/juicy_composite_resource.gd`

**核心职责**：
- 定义效果组合的配置结构
- 支持多种混合模式
- 提供权重和条件控制
- 实现动态组合调整
- **新增**：支持参数映射系统，实现联觉体验

**详细实现计划**：

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

# 注意：JuicyParameterBinding已移至独立文件 addons/juicy_mixer/resources/juicy_parameter_binding.gd
# 注意：JuicyCompositeItem已移至独立文件 addons/juicy_mixer/resources/juicy_composite_item.gd

# 组合配置
@export var composite_items: Array[JuicyCompositeItem] = []
@export var blend_mode: CompositeBlendMode = CompositeBlendMode.ADDITIVE
@export var normalize_weights: bool = true
@export var dynamic_weight_adjustment: bool = false

# 联觉系统配置
@export var parameter_bindings: Array[JuicyParameterBinding] = []
@export var enable_parameter_mapping: bool = false
@export var auto_update_parameters: bool = true

func create_drivers() -> Array[JuicyDriver]:
    var driver = JuicyCompositeDriver.new()
    driver.composite_resource = self
    return [driver]

# 联觉系统：设置参数值
func set_parameter(parameter_name: String, value: float) -> void:
    if not enable_parameter_mapping:
        return
    
    # 通过参数绑定更新所有相关子资源的属性
    for binding in parameter_bindings:
        if binding.enabled and binding.input_parameter == parameter_name:
            _apply_parameter_binding(binding, value)

# 联觉系统：应用参数绑定
func _apply_parameter_binding(binding: JuicyParameterBinding, input_value: float) -> void:
    if binding.target_item_index >= composite_items.size():
        return
    
    var item = composite_items[binding.target_item_index]
    if not item.resource or binding.target_property.is_empty():
        return
    
    # 使用曲线映射输入值
    var mapped_value = binding.curve.sample(input_value)
    
    # 动态设置资源属性
    _set_resource_property(item.resource, binding.target_property, mapped_value)

# 联觉系统：动态设置资源属性
func _set_resource_property(resource: JuicyFeedbackResource, property_name: String, value: Variant) -> void:
    # 使用反射设置属性值
    if resource.has_method("set_" + property_name):
        resource.call("set_" + property_name, value)
    elif property_name in resource:
        resource.set(property_name, value)

func validate_config() -> ValidationResult:
    var result = super.validate_config()
    
    if composite_items.is_empty():
        result.valid = false
        result.issues.append("Composite items cannot be empty")
    
    # 验证参数绑定
    if enable_parameter_mapping:
        for i in range(parameter_bindings.size()):
            var binding = parameter_bindings[i]
            if binding.target_item_index >= composite_items.size():
                result.valid = false
                result.issues.append("Parameter binding target_item_index out of range at index " + str(i))
            
            if binding.target_property.is_empty():
                result.valid = false
                result.issues.append("Parameter binding target_property cannot be empty at index " + str(i))
    
    var total_weight = 0.0
    for i in range(composite_items.size()):
        var item = composite_items[i]
        if not item.resource:
            result.valid = false
            result.issues.append("Resource cannot be null at index " + str(i))
        
        if item.weight < 0.0:
            result.valid = false
            result.issues.append("Weight cannot be negative at index " + str(i))
        
        total_weight += item.weight
    
    if normalize_weights and total_weight <= 0.0:
        result.valid = false
        result.issues.append("Total weight must be greater than 0 when normalize_weights is enabled")
    
    return result
```

**开发任务分解**：
- [ ] 第11周第3天：基础组合数据结构定义
- [ ] 第11周第4天：配置参数和验证
- [ ] 第13周第1天：参数绑定系统实现
- [ ] 第13周第3天：单元测试和文档

## JuicyCompositeDriver (组合驱动器)

**文件路径**：`addons/juicy_mixer/drivers/juicy_composite_driver.gd`

**核心职责**：
- 执行效果组合
- 管理混合模式和权重
- 处理动态调整
- 支持条件执行
- **新增**：实现混音台功能，支持参数映射的实时更新

**详细实现计划**：

```gdscript
class_name JuicyCompositeDriver
extends JuicyDriver

# 组合状态
class CompositeState:
    var active_contexts: Array[String] = []
    var item_weights: Dictionary = {}  # context_id -> weight
    var blend_progress: float = 0.0
    var parameter_values: Dictionary = {}  # 联觉系统：存储当前参数值

var composite_resource: JuicyCompositeResource
var _composite_states: Dictionary = {}  # context_id -> CompositeState

func _init():
    driver_name = "JuicyCompositeDriver"
    supported_properties = []  # 组合驱动器通过子Driver处理属性

func prepare(context: JuicyContext) -> void:
    var state = CompositeState.new()
    
    # 计算权重
    var total_weight = 0.0
    for item in composite_resource.composite_items:
        if item.enabled and item.resource:
            total_weight += item.weight
    
    # 创建子上下文
    for item in composite_resource.composite_items:
        if not item.enabled or not item.resource:
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
    
    # 联觉系统：初始化参数值
    if composite_resource.enable_parameter_mapping:
        _initialize_parameter_values(state)
    
    _composite_states[context.context_id] = state

func process(context: JuicyContext, delta: float, buffer: JuicyPropertyBuffer) -> void:
    var state = _composite_states.get(context.context_id)
    if not state:
        return
    
    # 更新混合进度
    state.blend_progress = min(state.blend_progress + delta, 1.0)
    
    # 联觉系统：实时更新参数映射
    if composite_resource.enable_parameter_mapping and composite_resource.auto_update_parameters:
        _update_parameter_mappings(context, state, delta)
    
    # 应用混合模式
    _apply_blend_mode(context, state, buffer)

# 联觉系统：设置参数值（混音台核心功能）
func set_parameter(context_id: String, parameter_name: String, value: float) -> void:
    var state = _composite_states.get(context_id)
    if not state or not composite_resource.enable_parameter_mapping:
        return
    
    # 更新参数值
    state.parameter_values[parameter_name] = value
    
    # 立即应用到资源
    composite_resource.set_parameter(parameter_name, value)
    
    # 更新所有相关的子上下文
    _update_child_contexts(state, parameter_name, value)

# 联觉系统：初始化参数值
func _initialize_parameter_values(state: CompositeState) -> void:
    for binding in composite_resource.parameter_bindings:
        if binding.enabled:
            state.parameter_values[binding.input_parameter] = 0.0

# 联觉系统：实时更新参数映射
func _update_parameter_mappings(context: JuicyContext, state: CompositeState, delta: float) -> void:
    # 这里可以根据游戏逻辑动态计算参数值
    # 例如：从游戏状态获取充能量值、伤害值等
    for parameter_name in state.parameter_values:
        var current_value = state.parameter_values[parameter_name]
        # 可以在这里添加自动更新逻辑
        # 例如：current_value = _calculate_parameter_from_game_state(parameter_name, context)
        set_parameter(context.context_id, parameter_name, current_value)

# 联觉系统：更新子上下文
func _update_child_contexts(state: CompositeState, parameter_name: String, value: float) -> void:
    for context_id in state.active_contexts:
        var item_context = JuicyMixer.get_context(context_id)
        if item_context and item_context.property_buffer:
            # 通过中间件系统更新子上下文的属性
            _update_context_parameters(item_context, parameter_name, value)

# 联觉系统：更新上下文参数
func _update_context_parameters(item_context: JuicyContext, parameter_name: String, value: float) -> void:
    # 通过PropertyBuffer更新参数
    if item_context.property_buffer:
        item_context.property_buffer.set_property(parameter_name, value)

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
    # 叠加混合模式实现
    for context_id in state.active_contexts:
        var weight = state.item_weights.get(context_id, 1.0)
        var item_context = JuicyMixer.get_context(context_id)
        if item_context and item_context.property_buffer:
            buffer.add_buffer(item_context.property_buffer, weight)

func _apply_multiplicative_blend(state: CompositeState, buffer: JuicyPropertyBuffer) -> void:
    # 乘法混合模式实现
    for context_id in state.active_contexts:
        var weight = state.item_weights.get(context_id, 1.0)
        var item_context = JuicyMixer.get_context(context_id)
        if item_context and item_context.property_buffer:
            buffer.multiply_buffer(item_context.property_buffer, weight)

func _apply_override_blend(state: CompositeState, buffer: JuicyPropertyBuffer) -> void:
    # 覆盖混合模式实现
    for context_id in state.active_contexts:
        var item_context = JuicyMixer.get_context(context_id)
        if item_context and item_context.property_buffer:
            buffer.copy_from(item_context.property_buffer)
            break  # 只使用第一个有效项

func _apply_weighted_average_blend(state: CompositeState, buffer: JuicyPropertyBuffer) -> void:
    # 加权平均混合模式实现
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

func _create_item_context(parent_context: JuicyContext, item: JuicyCompositeItem) -> JuicyContext:
    var item_context = JuicyContext.create(item.resource, parent_context.target, parent_context.owner)
    item_context.time_scale = parent_context.time_scale
    return item_context

func cleanup(context: JuicyContext) -> void:
    var state = _composite_states.get(context.context_id)
    if state:
        # 停止所有活跃的子上下文
        for context_id in state.active_contexts:
            JuicyMixer.stop(context_id)
        
        _composite_states.erase(context.context_id)
```

**开发任务分解**：
- [ ] 第12周第3天：基础组合状态管理
- [ ] 第13周第1天：混音台功能实现
- [ ] 第13周第2天：参数映射实时更新系统
- [ ] 第13周第3天：混合模式与参数映射集成
- [ ] 第13周第4天：单元测试和集成测试

## JuicyResourceVariant (动态覆盖与继承系统)

**文件路径**：`addons/juicy_mixer/resources/juicy_resource_variant.gd`

**核心职责**：
- 实现效果的变奏和复用
- 支持基于模板的细粒度覆盖
- 提供类似Prefab Variant的功能
- 实现高效的资源继承机制

**详细实现计划**：

```gdscript
@tool
class_name JuicyResourceVariant
extends JuicyFeedbackResource

# 覆盖模式和资源覆盖项
# 注意：OverrideMode和ResourceOverride已移至独立文件 addons/juicy_mixer/resources/resource_override.gd

# 变体配置
@export var base_resource: JuicyFeedbackResource  # 基础资源模板
@export var resource_overrides: Array[ResourceOverride] = []
@export var inherit_parameters: bool = true      # 是否继承参数绑定
@export var inherit_event_sync: bool = true      # 是否继承事件同步

func create_drivers() -> Array[JuicyDriver]:
    # 创建变体资源
    var variant_resource = _create_variant_resource()
    return variant_resource.create_drivers()

# 联觉系统：创建变体资源
func _create_variant_resource() -> JuicyFeedbackResource:
    if not base_resource:
        push_error("Base resource cannot be null")
        return null
    
    # 深拷贝基础资源
    var variant = base_resource.duplicate(true)
    
    # 应用覆盖
    for override in resource_overrides:
        if not override.enabled:
            continue
        
        _apply_override(variant, override)
    
    return variant

# 联觉系统：应用覆盖
func _apply_override(resource: JuicyFeedbackResource, override: ResourceOverride) -> void:
    match override.override_mode:
        OverrideMode.REPLACE:
            _apply_replace_override(resource, override)
        OverrideMode.MODIFY:
            _apply_modify_override(resource, override)
        OverrideMode.ADD_TO_COMPOSITE:
            _apply_add_to_composite_override(resource, override)
        OverrideMode.REMOVE_FROM_COMPOSITE:
            _apply_remove_from_composite_override(resource, override)

# 联觉系统：应用替换覆盖
func _apply_replace_override(resource: JuicyFeedbackResource, override: ResourceOverride) -> void:
    var target = _get_target_property(resource, override.target_path)
    if target and override.new_resource:
        _set_target_property(resource, override.target_path, override.new_resource)

# 联觉系统：应用修改覆盖
func _apply_modify_override(resource: JuicyFeedbackResource, override: ResourceOverride) -> void:
    var target = _get_target_property(resource, override.target_path)
    if target:
        for property_name in override.property_overrides:
            if property_name in target:
                target.set(property_name, override.property_overrides[property_name])

# 联觉系统：应用添加到组合覆盖
func _apply_add_to_composite_override(resource: JuicyFeedbackResource, override: ResourceOverride) -> void:
    if resource is JuicyCompositeResource and override.new_resource:
        var new_item = JuicyCompositeItem.new()
        new_item.resource = override.new_resource
        resource.composite_items.append(new_item)

# 联觉系统：应用从组合移除覆盖
func _apply_remove_from_composite_override(resource: JuicyFeedbackResource, override: ResourceOverride) -> void:
    if resource is JuicyCompositeResource:
        var index = override.target_path.trim_prefix("composite_items[").trim_suffix("]").to_int()
        if index >= 0 and index < resource.composite_items.size():
            resource.composite_items.remove_at(index)

# 联觉系统：获取目标属性
func _get_target_property(resource: JuicyFeedbackResource, path: String) -> Variant:
    var parts = path.split(".")
    var current = resource
    
    for part in parts:
        if part.ends_with("]"):
            # 数组访问
            var array_parts = part.split("[")
            var array_name = array_parts[0]
            var index = array_parts[1].trim_suffix("]").to_int()
            
            if array_name in current and current[array_name] is Array:
                current = current[array_name][index]
            else:
                return null
        else:
            # 属性访问
            if part in current:
                current = current[part]
            else:
                return null
    
    return current

# 联觉系统：设置目标属性
func _set_target_property(resource: JuicyFeedbackResource, path: String, value: Variant) -> void:
    var parts = path.split(".")
    var current = resource
    
    # 导航到父级
    for i in range(parts.size() - 1):
        var part = parts[i]
        if part.ends_with("]"):
            var array_parts = part.split("[")
            var array_name = array_parts[0]
            var index = array_parts[1].trim_suffix("]").to_int()
            
            if array_name in current and current[array_name] is Array:
                current = current[array_name][index]
            else:
                return
        else:
            if part in current:
                current = current[part]
            else:
                return
    
    # 设置最终值
    var final_part = parts[-1]
    if final_part.ends_with("]"):
        var array_parts = final_part.split("[")
        var array_name = array_parts[0]
        var index = array_parts[1].trim_suffix("]").to_int()
        
        if array_name in current and current[array_name] is Array:
            current[array_name][index] = value
    else:
        if final_part in current:
            current[final_part] = value

func validate_config() -> ValidationResult:
    var result = super.validate_config()
    
    if not base_resource:
        result.valid = false
        result.issues.append("Base resource cannot be null")
    
    for i in range(resource_overrides.size()):
        var override = resource_overrides[i]
        if override.target_path.is_empty():
            result.valid = false
            result.issues.append("Override target path cannot be empty at index " + str(i))
        
        if override.override_mode == OverrideMode.REPLACE and not override.new_resource:
            result.valid = false
            result.issues.append("New resource cannot be null when override_mode is REPLACE at index " + str(i))
    
    return result
```

**开发任务分解**：
- [ ] 第14周第1天：资源变体数据结构定义
- [ ] 第14周第1天：覆盖模式实现
- [ ] 第14周第2天：属性路径解析和设置
- [ ] 第14周第3天：组合资源特殊处理
- [ ] 第14周第4天：单元测试和文档

## 性能优化

### 内存管理
- 组合系统需要使用对象池
- 资源变体需要智能缓存机制

### 执行效率
- 组合计算需要考虑性能开销
- 参数映射需要优化曲线采样

## 测试计划

### 单元测试
- JuicyCompositeResource配置验证测试
- JuicyCompositeDriver混合模式测试
- JuicyResourceVariant覆盖机制测试

### 集成测试
- 组合系统集成测试
- 参数映射集成测试
- 动态覆盖与继承系统测试
- 与Director系统集成测试
- 与Middleware系统集成测试

### 性能测试
- 1000个组合项混合性能测试
- 参数映射实时更新性能测试
- 资源变体创建和执行性能测试
- 内存使用优化验证

## 交付检查清单

### 代码交付
- [ ] JuicyCompositeResource和JuicyCompositeDriver
- [ ] JuicyResourceVariant
- [ ] 单元测试和集成测试
- [ ] 性能基准测试

### 文档交付
- [ ] 组合系统使用文档
- [ ] 参数映射系统文档
- [ ] 动态覆盖系统文档
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
1. **参数映射复杂性**：复杂的参数映射逻辑可能难以调试
   - 缓解措施：提供详细的调试信息和参数可视化

2. **组合计算性能**：复杂的混合模式可能影响性能
   - 缓解措施：实现计算缓存和批处理优化

3. **资源变体复杂性**：动态覆盖机制可能增加系统复杂性
   - 缓解措施：设计清晰的覆盖规则和验证机制

### 进度风险
1. **参数映射实现**：参数映射系统可能比预期复杂
   - 缓解措施：优先实现核心功能，后续扩展

2. **动态覆盖实现**：资源变体系统可能需要更多时间
   - 缓解措施：分阶段实现，先支持基础覆盖模式

## 参数映射使用示例

### 大招充能效果

```gdscript
# 创建一个充能效果的组合资源
var charge_composite = JuicyCompositeResource.new()

# 添加视觉效果
var visual_shake = JuicyShakeResource.new()
visual_shake.amplitude = 5.0
var visual_item = JuicyCompositeItem.new()
visual_item.resource = visual_shake
visual_item.weight = 1.0

# 添加音效
var audio_effect = JuicyAudioResource.new()
audio_effect.volume_db = -10.0
var audio_item = JuicyCompositeItem.new()
audio_item.resource = audio_effect
audio_item.weight = 1.0

# 添加手柄震动
var haptic_effect = JuicyHapticResource.new()
haptic_effect.frequency = 50.0
var haptic_item = JuicyCompositeItem.new()
haptic_item.resource = haptic_effect
haptic_item.weight = 1.0

charge_composite.composite_items = [visual_item, audio_item, haptic_item]

# 启用参数映射
charge_composite.enable_parameter_mapping = true

# 创建参数绑定：充能量值 -> 多感官输出
var intensity_to_visual = JuicyParameterBinding.new()
intensity_to_visual.input_parameter = "charge_amount"
intensity_to_visual.target_item_index = 0  # 视觉效果
intensity_to_visual.target_property = "amplitude"
intensity_to_visual.curve = preload("res://curves/charge_to_visual.tres")  # 0-1 -> 0-10

var intensity_to_audio = JuicyParameterBinding.new()
intensity_to_audio.input_parameter = "charge_amount"
intensity_to_audio.target_item_index = 1  # 音效
intensity_to_audio.target_property = "volume_db"
intensity_to_audio.curve = preload("res://curves/charge_to_audio.tres")  # 0-1 -> -10到0

var intensity_to_haptic = JuicyParameterBinding.new()
intensity_to_haptic.input_parameter = "charge_amount"
intensity_to_haptic.target_item_index = 2  # 手柄震动
intensity_to_haptic.target_property = "frequency"
intensity_to_haptic.curve = preload("res://curves/charge_to_haptic.tres")  # 0-1 -> 50-200

charge_composite.parameter_bindings = [intensity_to_visual, intensity_to_audio, intensity_to_haptic]

# 在游戏中使用
var context_id = JuicyMixer.play(charge_composite, player)

# 更新充能量值，所有感官会同步响应
func update_charge(amount: float):
    var driver = JuicyMixer.get_driver(context_id)
    if driver is JuicyCompositeDriver:
        driver.set_parameter(context_id, "charge_amount", amount)
```

## 动态覆盖使用示例

### 火焰受击变体

```gdscript
# 创建基础受击效果
var base_hit_effect = JuicyCompositeResource.new()
# ... 配置基础受击效果（声音A + 震动A）

# 创建火焰受击变体
var fire_hit_variant = JuicyResourceVariant.new()
fire_hit_variant.base_resource = base_hit_effect

# 覆盖声音为火焰声
var fire_audio = JuicyAudioResource.new()
fire_audio.stream = preload("res://sounds/fire_hit.wav")
var sound_override = ResourceOverride.new()
sound_override.target_path = "composite_items[0].resource"  # 替换第一个项（声音）
sound_override.override_mode = OverrideMode.REPLACE
sound_override.new_resource = fire_audio

# 增强震动强度
var shake_override = ResourceOverride.new()
shake_override.target_path = "composite_items[1].resource.amplitude"  # 修改震动幅度
shake_override.override_mode = OverrideMode.MODIFY
shake_override.property_overrides = {"amplitude": 8.0}  # 增加20%震动

fire_hit_variant.resource_overrides = [sound_override, shake_override]

# 使用变体效果
var context_id = JuicyMixer.play(fire_hit_variant, enemy)
```

## 总结

联觉组合系统是JuicyMixer V3的核心创新功能，它将传统的效果组合系统升级为智能的混音台系统。通过参数映射和动态覆盖机制，实现了：

**技术突破**：
- 从"简单容器"到"智能混音台"的架构进化
- 单一输入驱动多个感官输出的联觉体验
- 高度可复用的资源变体系统
- 实时参数映射和动态属性更新机制

**开发体验提升**：
- 直观的参数映射配置界面
- 强大的混音台调试和监控工具
- 完善的变体创建和管理界面
- 丰富的参数映射和覆盖使用示例

**性能优化**：
- 智能的参数缓存和批处理机制
- 高效的混合算法和内存使用
- 可配置的映射曲线和更新频率
- 针对不同场景的优化策略

联觉组合系统将为JuicyMixer V3用户提供前所未有的感官体验控制能力，使复杂的多感官效果创建变得简单直观，真正实现"牵一发而动全身"的联觉设计理念。

## 附录：独立类定义

### JuicyParameterBinding 类定义

**文件路径**：`addons/juicy_mixer/resources/juicy_parameter_binding.gd`

```gdscript
@tool
class_name JuicyParameterBinding
extends RefCounted

# 参数绑定数据结构 - 联觉系统的核心
# 用于实现一个输入参数驱动多个感官输出的映射机制

@export var input_parameter: String = "intensity"  # 外部输入的参数名
@export var target_item_index: int = 0           # 绑定到Composite中的哪个子Resource
@export var target_property: String = ""          # 绑定到子Resource的哪个属性
@export var curve: Curve                         # 映射曲线 (例如输入0-1，映射到输出0-100)
@export var enabled: bool = true

# 应用参数绑定到目标资源
func apply_to_resource(resource: JuicyFeedbackResource, input_value: float) -> void:
	if not enabled or target_property.is_empty():
		return
	
	# 使用曲线映射输入值
	var mapped_value = curve.sample(input_value) if curve else input_value
	
	# 动态设置资源属性
	_set_resource_property(resource, target_property, mapped_value)

# 使用反射设置资源属性
func _set_resource_property(resource: JuicyFeedbackResource, property_name: String, value: Variant) -> void:
	# 使用反射设置属性值
	if resource.has_method("set_" + property_name):
		resource.call("set_" + property_name, value)
	elif property_name in resource:
		resource.set(property_name, value)

# 验证绑定配置
func validate_binding() -> String:
	if input_parameter.is_empty():
		return "Input parameter cannot be empty"
	
	if target_property.is_empty():
		return "Target property cannot be empty"
	
	if target_item_index < 0:
		return "Target item index cannot be negative"
	
	return ""  # 验证通过

# 获取绑定的描述信息
func get_description() -> String:
	var desc = "%s -> item[%d].%s" % [input_parameter, target_item_index, target_property]
	if curve:
		desc += " (with curve mapping)"
	return desc
```

### JuicyCompositeItem 类定义

**文件路径**：`addons/juicy_mixer/resources/juicy_composite_item.gd`

```gdscript
@tool
class_name JuicyCompositeItem
extends RefCounted

# 组合项数据结构
@export var resource: JuicyFeedbackResource
@export var weight: float = 1.0
@export var condition: String = ""
@export var enabled: bool = true
@export var priority: int = 0

# 验证组合项配置
func validate_item() -> String:
	if not resource:
		return "Resource cannot be null"
	
	if weight < 0.0:
		return "Weight cannot be negative"
	
	return ""  # 验证通过

# 获取项的描述信息
func get_description() -> String:
	var desc = resource.resource_path if resource else "None"
	desc += " (weight: %.2f, priority: %d)" % [weight, priority]
	if not condition.is_empty():
		desc += " [condition: %s]" % condition
	return desc
```

### ResourceOverride 类定义

**文件路径**：`addons/juicy_mixer/resources/resource_override.gd`

```gdscript
@tool
class_name ResourceOverride
extends RefCounted

# 覆盖模式枚举
enum OverrideMode {
	REPLACE,              # 替换整个资源
	MODIFY,               # 修改资源的特定属性
	ADD_TO_COMPOSITE,      # 添加到组合资源
	REMOVE_FROM_COMPOSITE  # 从组合资源移除
}

# 资源覆盖项数据结构
@export var override_mode: OverrideMode = OverrideMode.REPLACE
@export var target_path: String = ""              # 目标属性路径（如 "composite_items[0].resource"）
@export var new_resource: JuicyFeedbackResource  # 新资源（用于REPLACE模式）
@export var property_overrides: Dictionary = {}   # 属性覆盖（用于MODIFY模式）
@export var enabled: bool = true

# 验证覆盖配置
func validate_override() -> String:
	if target_path.is_empty():
		return "Target path cannot be empty"
	
	if override_mode == OverrideMode.REPLACE and not new_resource:
		return "New resource cannot be null when override_mode is REPLACE"
	
	return ""  # 验证通过

# 获取覆盖的描述信息
func get_description() -> String:
	var desc = "%s -> %s" % [OverrideMode.keys()[override_mode], target_path]
	if override_mode == OverrideMode.REPLACE and new_resource:
		desc += " (resource: %s)" % new_resource.resource_path
	elif override_mode == OverrideMode.MODIFY and not property_overrides.is_empty():
		desc += " (properties: %s)" % str(property_overrides.keys())
	return desc
```