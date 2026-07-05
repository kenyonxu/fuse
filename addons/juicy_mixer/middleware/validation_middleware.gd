# ValidationMiddleware - 验证中间件
# 验证Context和Resource的有效性，确保系统稳定性

class_name ValidationMiddleware
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
	tags = ["validation", "core", "stability"]
	enable_debug_logging = true  # 启用调试日志

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
	
	# 验证通过，设置验证信任标记
	# 让后续的中间件可以跳过重复的验证逻辑
	set_validation_passed(true)
	
	_end_execution_timer(start_time)
	return next.call()

# 验证实现
func _validate_basic_requirements(context: JuicyContext) -> bool:
	"""基础需求验证"""
	if not context:
		_log_error("Context is null")
		return false

	if not context.target:
		_log_error("Context target is null")
		return false

	# 使用 context_type 进行类型安全验证
	match context.context_type:
		JuicyContext.ContextType.EVENT:
			# 事件 Context 的验证
			if context.get_events().is_empty():
				_log_error("Event Context must have at least one event")
				return false
			_log_debug("Event Context validation passed (has %d events)" % context.get_events().size())

		JuicyContext.ContextType.FEEDBACK:
			# Feedback Context 的验证
			if not context.resource:
				_log_error("Feedback Context must have a resource")
				return false
			_log_debug("Feedback Context validation passed (has resource)")

		_:
			_log_error("Unknown context type: " + str(context.context_type))
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

	# 步骤1：检查基础属性
	if _check_basic_properties(target):
		return true

	# 步骤2：检查视觉节点类型
	if _is_visual_node_type(target):
		return _check_visual_properties(target)

	# 步骤3：对其他节点类型的宽松验证
	return _check_any_property_fallback(target)

## 检查基础属性
## @param target: 目标节点
## @return: 是否找到基础属性
func _check_basic_properties(target: Node) -> bool:
	var basic_properties = ["position", "rotation", "scale", "modulate"]

	for property in basic_properties:
		if property in target:
			_log_debug("目标节点支持基础属性", {
				"target_type": target.get_class()
			})
			return true

	return false

## 检查是否是视觉节点类型
## @param target: 目标节点
## @return: 是否是视觉节点
func _is_visual_node_type(target: Node) -> bool:
	var visual_node_types = ["Node2D", "Sprite2D", "Control", "AudioStreamPlayer2D", "GPUParticles2D"]

	for node_type in visual_node_types:
		if target.is_class(node_type):
			return true

	return false

## 检查视觉节点的属性
## @param target: 目标节点
## @return: 是否找到视觉属性
func _check_visual_properties(target: Node) -> bool:
	var visual_properties = ["position", "rotation", "scale", "modulate"]

	for property in visual_properties:
		if property in target:
			_log_debug("目标视觉节点支持相关属性", {
				"target_type": target.get_class()
			})
			return true

	return false

## 检查是否有任何属性的宽松验证
## @param target: 目标节点
## @return: 验证是否通过
func _check_any_property_fallback(target: Node) -> bool:
	# 遍历所有属性
	var target_properties = []
	for i in range(target.get_property_list().size()):
		var property_info = target.get_property_list()[i]
		target_properties.append(property_info.name)

	var has_any_property = target_properties.size() > 0

	if has_any_property:
		_log_debug("目标节点具有属性", {
			"target_type": target.get_class(),
			"properties": target_properties
		})
		return true
	elif strict_mode:
		_log_error("严格模式下，目标节点必须支持基础属性", {
			"target_type": target.get_class()
		})
		return false
	else:
		# 非严格模式下，只要节点有任何属性就通过
		_log_warning("目标节点类型未知，采用宽松验证", {
			"target_type": target.get_class(),
			"properties": target_properties
		})
		return true

func _validate_resource_config(context: JuicyContext) -> bool:
	"""资源配置验证"""
	# 使用 context_type 决定是否需要验证 resource
	match context.context_type:
		JuicyContext.ContextType.EVENT:
			# 事件 Context 不需要 resource，跳过验证
			_log_debug("Skipping resource config validation for Event Context")
			return true

		JuicyContext.ContextType.FEEDBACK:
			# Feedback Context 需要 resource 验证
			var resource = context.resource

			if not resource:
				_log_error("Feedback Context resource is null")
				return false

			if not resource.has_method("validate_config"):
				_log_warning("Resource doesn't have validate_config method")
				return true  # 如果资源不支持验证，跳过

			var validation = resource.validate_config()

			if not validation.valid:
				for issue in validation.issues:
					_log_error("Resource validation failed: " + issue)
				return false

			for warning in validation.warnings:
				_log_warning("Resource validation warning: " + warning)

			return true

		_:
			_log_error("Unknown context type: " + str(context.context_type))
			return false

func _validate_time_parameters(context: JuicyContext) -> bool:
	"""时间参数验证"""
	# 使用 context_type 决定是否需要验证时间参数
	match context.context_type:
		JuicyContext.ContextType.EVENT:
			# 事件 Context 不需要 duration 验证（事件立即处理）
			_log_debug("Skipping duration validation for Event Context")
			# 仍然需要验证 time_scale
			if context.time_scale < 0:
				_log_error("Time scale cannot be negative")
				return false
			return true

		JuicyContext.ContextType.FEEDBACK:
			# Feedback Context 需要验证 duration 和 time_scale
			var resource = context.resource

			if not resource:
				_log_error("Feedback Context resource is null")
				return false

			if resource.has_method("get_duration"):
				var duration = resource.get_duration()
				if duration <= 0:
					_log_error("Duration must be greater than 0")
					return false

			if context.time_scale < 0:
				_log_error("Time scale cannot be negative")
				return false

			return true

		_:
			_log_error("Unknown context type: " + str(context.context_type))
			return false

func _validate_custom_rules(context: JuicyContext) -> bool:
	"""自定义验证规则"""
	for validator in custom_validators:
		if not validator.call(context):
			_log_error("Custom validation failed")
			if strict_mode:
				return false
	
	return true

# 配置接口
func configure(config: Dictionary = {}) -> bool:
	var result = super.configure(config)
	
	if config.has("strict_mode"):
		strict_mode = config.strict_mode
	
	if config.has("validate_target_properties"):
		validate_target_properties = config.validate_target_properties
	
	if config.has("validate_resource_config"):
		validate_resource_config = config.validate_resource_config
	
	if config.has("validate_time_parameters"):
		validate_time_parameters = config.validate_time_parameters
	
	return result

func get_configuration() -> Dictionary:
	var base_config = super.get_configuration()
	var result = base_config.duplicate()
	result["strict_mode"] = strict_mode
	result["validate_target_properties"] = validate_target_properties
	result["validate_resource_config"] = validate_resource_config
	result["validate_time_parameters"] = validate_time_parameters
	result["custom_validators_count"] = custom_validators.size()
	return result

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

# 生命周期钩子
func on_context_created(context: JuicyContext) -> void:
	_log_debug("ValidationMiddleware Context created", {"context_id": context.context_id})

func on_context_destroyed(context: JuicyContext) -> void:
	_log_debug("ValidationMiddleware Context destroyed", {"context_id": context.context_id})

func cleanup(context: JuicyContext) -> void:
	_log_debug("ValidationMiddleware cleanup", {"context_id": context.context_id})