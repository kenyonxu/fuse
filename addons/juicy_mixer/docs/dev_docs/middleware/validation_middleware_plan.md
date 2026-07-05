# 验证中间件开发计划

## 系统集成与优化要求

### 与Driver系统的协同优化
**Driver执行优化**：
- ValidationMiddleware需要验证Driver的兼容性和可用性
- 确保在Driver执行前检测潜在的资源冲突或不支持的属性

## 核心组件详细设计

### 3. ValidationMiddleware (验证中间件)

**文件路径**：`addons/juicy_mixer/middleware/validation_middleware.gd`

**核心职责**：
- 验证Context和Resource的有效性
- 检查目标节点的兼容性
- 提供详细的错误信息
- 支持自定义验证规则

**详细实现计划**：

```gdscript
class_name JuicyValidationMiddleware
extends JuicyMiddleware

# 验证配置
var strict_mode: bool = false
var validate_target_properties: bool = true
var validate_resource_config: bool = true
var validate_time_parameters: bool = true

# 自定义验证规则
var custom_validators: Array[Callable] = []

func _init():
    middleware_name = "ValidationMiddleware"
    priority = 1000  # 最高优先级，最先执行
    description = "Validates context and resource parameters"

func process(context: JuicyContext, next: Callable) -> bool:
    """执行验证"""
    var start_time = _start_execution_timer()
    
    # 基础验证
    if not _validate_basic_requirements(context):
        _end_execution_timer(start_time)
        return false
    
    # 目标节点验证
    if validate_target_properties and not _validate_target_node(context):
        _end_execution_timer(start_time)
        return false
    
    # 资源配置验证
    if validate_resource_config and not _validate_resource_config(context):
        _end_execution_timer(start_time)
        return false
    
    # 时间参数验证
    if validate_time_parameters and not _validate_time_parameters(context):
        _end_execution_timer(start_time)
        return false
    
    # 自定义验证
    if not _validate_custom_rules(context):
        _end_execution_timer(start_time)
        return false
    
    _end_execution_timer(start_time)
    return next.call(context)

# 验证实现
func _validate_basic_requirements(context: JuicyContext) -> bool:
    """基础需求验证"""
    if not context:
        _log_error("Context is null")
        return false
    
    if not context.target:
        _log_error("Context target is null")
        return false
    
    if not context.resource:
        _log_error("Context resource is null")
        return false
    
    if not is_instance_valid(context.target):
        _log_error("Context target is not valid")
        return false
    
    return true

func _validate_target_node(context: JuicyContext) -> bool:
    """目标节点验证"""
    var target = context.target
    var resource = context.resource
    
    # 检查节点是否在场景树中
    if not target.is_inside_tree():
        _log_warning("Target node is not inside scene tree")
        if strict_mode:
            return false
    
    # 检查节点是否支持所需属性
    var drivers = resource.create_drivers()
    for driver in drivers:
        for property in driver.supported_properties:
            if not property in target:
                var message = "Target node doesn't support property: " + property
                if strict_mode:
                    _log_error(message)
                    return false
                else:
                    _log_warning(message)
    
    return true

func _validate_resource_config(context: JuicyContext) -> bool:
    """资源配置验证"""
    var resource = context.resource
    var validation = resource.validate_config()
    
    if not validation.valid:
        for issue in validation.issues:
            _log_error("Resource validation failed: " + issue)
        return false
    
    for warning in validation.warnings:
        _log_warning("Resource validation warning: " + warning)
    
    return true

func _validate_time_parameters(context: JuicyContext) -> bool:
    """时间参数验证"""
    var resource = context.resource
    
    if resource.duration <= 0:
        _log_error("Duration must be greater than 0")
        return false
    
    if context.time_scale < 0:
        _log_error("Time scale cannot be negative")
        return false
    
    return true

func _validate_custom_rules(context: JuicyContext) -> bool:
    """自定义验证规则"""
    for validator in custom_validators:
        if not validator.call(context):
            _log_error("Custom validation failed")
            if strict_mode:
                return false
    
    return true

# 配置接口
func configure(config: Dictionary) -> void:
    super.configure(config)
    
    if config.has("strict_mode"):
        strict_mode = config.strict_mode
    
    if config.has("validate_target_properties"):
        validate_target_properties = config.validate_target_properties
    
    if config.has("validate_resource_config"):
        validate_resource_config = config.validate_resource_config
    
    if config.has("validate_time_parameters"):
        validate_time_parameters = config.validate_time_parameters

func get_configuration() -> Dictionary:
    return super.get_configuration().merge({
        "strict_mode": strict_mode,
        "validate_target_properties": validate_target_properties,
        "validate_resource_config": validate_resource_config,
        "validate_time_parameters": validate_time_parameters,
        "custom_validators_count": custom_validators.size()
    })

# 自定义验证器管理
func add_custom_validator(validator: Callable) -> void:
    """添加自定义验证器"""
    custom_validators.append(validator)

func remove_custom_validator(validator: Callable) -> void:
    """移除自定义验证器"""
    custom_validators.erase(validator)

func clear_custom_validators() -> void:
    """清除所有自定义验证器"""
    custom_validators.clear()
```

**开发任务分解**：
- [ ] 第8周第1天：基础验证逻辑
- [ ] 第8周第1天：目标节点验证
- [ ] 第8周第2天：资源配置验证
- [ ] 第8周第2天：自定义验证规则
- [ ] 第8周第3天：配置管理和单元测试

**验收标准**：
- 验证逻辑全面准确
- 错误信息详细清晰
- 支持灵活配置
- 单元测试覆盖率100%
---

## 测试计划

### 测试场景2：验证中间件功能测试
```gdscript
func test_validation_middleware():
    var middleware = JuicyValidationMiddleware.new()
    middleware.strict_mode = true
    
    # 测试有效Context
    var valid_context = _create_valid_context()
    assert_true(middleware.process(valid_context, func(ctx): return true))
    
    # 测试无效Context
    var invalid_context = JuicyContext.create(null, null)
    assert_false(middleware.process(invalid_context, func(ctx): return true))
```