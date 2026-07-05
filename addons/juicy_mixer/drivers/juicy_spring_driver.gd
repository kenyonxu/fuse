# JuicySpringDriver - 弹簧驱动器
# 实现物理弹簧效果，支持可配置的弹簧参数
# 提供真实的物理模拟，处理阻尼和恢复力
# 基于胡克定律和牛顿运动定律实现

class_name JuicySpringDriver
extends JuicyDriver

# =============================================================================
# 弹簧配置结构
# =============================================================================

## 弹簧配置类，定义单个属性的弹簧参数
class SpringConfig:
	## 目标值
	var target_value: Variant
	
	## 刚度（弹簧常数k）
	var stiffness: float = 100.0
	
	## 阻尼系数（c）
	var damping: float = 10.0
	
	## 质量（m）
	var mass: float = 1.0
	
	## 初始速度
	var initial_velocity: Variant = 0.0
	
	## 稳定阈值（位置和速度都小于此值时认为稳定）
	var threshold: float = 0.01
	
	## 复制配置
	func duplicate() -> SpringConfig:
		var config = SpringConfig.new()
		config.target_value = target_value
		config.stiffness = stiffness
		config.damping = damping
		config.mass = mass
		config.initial_velocity = initial_velocity
		config.threshold = threshold
		return config

# =============================================================================
# 弹簧状态结构
# =============================================================================

## 弹簧状态类，维护单个属性的运行时状态
class SpringState:
	## 原始位置（弹簧开始时的位置）
	var original_position: Variant
	
	## 当前弹簧位置（相对于原始位置的偏移）
	var spring_position: Variant
	
	## 上一帧的弹簧位置（用于计算增量）
	var previous_spring_position: Variant
	
	## 当前速度
	var current_velocity: Variant
	
	## 目标位置（相对于原始位置的偏移）
	var target_position: Variant
	
	## 是否已稳定（位置和速度都低于阈值）
	var is_stable: bool = false
	
	## 复制状态
	func duplicate() -> SpringState:
		var state = SpringState.new()
		state.original_position = original_position
		state.spring_position = spring_position
		state.previous_spring_position = previous_spring_position
		state.current_velocity = current_velocity
		state.target_position = target_position
		state.is_stable = is_stable
		return state

# =============================================================================
# 状态管理
# =============================================================================

## 弹簧属性配置：属性名 -> SpringConfig
var spring_properties: Dictionary = {}

## 弹簧状态：context_id -> {属性名: SpringState}
var _spring_states: Dictionary = {}

# =============================================================================
# 生命周期管理
# =============================================================================

func _init():
	"""
	初始化弹簧驱动器
	设置驱动器名称和支持的属性列表
	"""
	driver_name = "JuicySpringDriver"
	supported_properties = ["position", "rotation", "scale", "global_position", "global_rotation"]
	required_context_data = ["spring_data"]

func prepare(context: JuicyContext, delta: float, buffer: JuicyPropertyBuffer) -> void:
	"""
	准备弹簧数据，在效果开始前调用一次
	
	@param context: JuicyContext实例，包含效果运行所需的所有数据
	@param delta: 时间增量（秒）
	@param buffer: JuicyPropertyBuffer实例，用于写入属性值
	"""
	# 从Context中的Resource获取弹簧数据
	var spring_resource = context.resource
	if not spring_resource or not "spring_data" in spring_resource:
		push_warning("Invalid spring resource in context")
		return
	
	var spring_data = spring_resource.spring_data if "spring_data" in spring_resource else []
	if spring_data.is_empty():
		push_warning("No spring data found in resource")
		return
	
	# 初始化弹簧配置
	_initialize_spring_configs(context, spring_data)
	
	# 初始化弹簧状态
	_initialize_spring_states(context)

func process(context: JuicyContext, delta: float, buffer: JuicyPropertyBuffer) -> void:
	"""
	处理弹簧效果，每帧调用
	
	@param context: JuicyContext实例，包含效果运行所需的所有数据
	@param delta: 时间增量（秒）
	@param buffer: JuicyPropertyBuffer实例，用于写入属性值
	"""
	var start_time = _start_execution_timer()
	
	# 应用时间缩放
	var effective_delta = delta * context.time_scale
	
	# 检查是否所有弹簧属性都已稳定
	var all_properties_stable = true
	
	# 处理每个弹簧属性
	for property in spring_properties.keys():
		var config = spring_properties[property]
		var state = _get_spring_state(context, property)
		
		# 检查弹簧是否稳定
		if not is_spring_stable(context, property):
			all_properties_stable = false
		
		# 如果已经稳定，跳过计算
		if state.is_stable:
			continue
		
		# 计算弹簧力（胡克定律：F = -kx）
		var spring_force = _calculate_spring_force(state, config)
		
		# 计算阻尼力（F = -cv）
		var damping_force = _calculate_damping_force(state, config)
		
		# 计算总力
		var total_force = _add_values(spring_force, damping_force)
		
		# 计算弹簧物理
		
		# 更新速度（v = v + (F/m) * dt）
		state.current_velocity = _update_velocity(state.current_velocity, total_force, config.mass, effective_delta)
		
		# 保存上一帧的位置
		state.previous_spring_position = state.spring_position
		
		# 更新位置（x = x + v * dt）
		state.spring_position = _update_position(state.spring_position, state.current_velocity, effective_delta)
		
		# 检查稳定性
		state.is_stable = _check_stability(state, config)
		
		# 计算帧间变化量（当前帧偏移 - 上一帧偏移）
		var delta_offset = _calculate_delta_offset(state)
		
		# 应用帧间变化量
		
		# 写入缓冲区（使用ADDITIVE混合模式）
		_add_property_sample(buffer, context, property, delta_offset, JuicyPropertyBuffer.BlendMode.ADDITIVE)
	
	# 如果所有属性都已稳定，标记上下文为完成
	if all_properties_stable:
		print("JuicySpringDriver: [DEBUG] All spring properties stable, calling context.complete() for context ", context.context_id)
		context.complete()
	
	_end_execution_timer(start_time)

func cleanup(context: JuicyContext) -> void:
	"""
	清理弹簧数据，在效果结束时调用
	
	@param context: JuicyContext实例，包含效果运行所需的所有数据
	"""
	_spring_states.erase(context.context_id)

# =============================================================================
# 内部实现 - 初始化
# =============================================================================

func _initialize_spring_configs(context: JuicyContext, spring_data: Array) -> void:
	"""
	初始化弹簧配置
	
	@param context: JuicyContext实例
	@param spring_data: 弹簧数据数组
	"""
	spring_properties.clear()
	
	for data in spring_data:
		# 处理Resource对象格式
		if data is SpringData:
			if data.property.is_empty():
				push_warning("Invalid spring data: empty property name")
				continue
			
			var config = SpringConfig.new()
			config.target_value = data.target_value
			config.stiffness = data.stiffness
			config.damping = data.damping
			config.mass = data.mass
			config.initial_velocity = data.initial_velocity
			config.threshold = data.threshold
			
			spring_properties[data.property] = config
		else:
			push_warning("Invalid spring data: expected SpringData, got " + str(typeof(data)))
			continue

func _initialize_spring_states(context: JuicyContext) -> void:
	"""
	初始化弹簧状态
	
	@param context: JuicyContext实例
	"""
	var context_id = context.context_id
	_spring_states[context_id] = {}
	
	for property in spring_properties.keys():
		var config = spring_properties[property]
		var state = SpringState.new()
		
		# 获取当前值作为原始位置
		if property in context.target:
			state.original_position = context.target.get(property)
		else:
			# 如果属性不存在，使用目标值作为起始位置
			state.original_position = config.target_value
		
		# 计算目标位置相对于原始位置的偏移
		state.target_position = _subtract_values(config.target_value, state.original_position)
		
		# 弹簧位置从0开始（相对于原始位置）
		state.spring_position = _get_zero_value_for_property(property)
		state.previous_spring_position = _get_zero_value_for_property(property)
		state.current_velocity = config.initial_velocity
		state.is_stable = false
		
		_spring_states[context_id][property] = state

# =============================================================================
# 内部实现 - 物理计算
# =============================================================================

func _calculate_spring_force(state: SpringState, config: SpringConfig) -> Variant:
	"""
	计算弹簧力（胡克定律：F = -kx）
	其中x是位移（当前弹簧位置 - 目标位置）
	
	@param state: 弹簧状态
	@param config: 弹簧配置
	
	@return: 弹簧力
	"""
	# 位移 = 当前弹簧位置 - 目标位置
	var displacement = _subtract_values(state.spring_position, state.target_position)
	# 弹簧力 = -刚度 * 位移（指向目标位置）
	return _multiply_value(displacement, -config.stiffness)

func _calculate_damping_force(state: SpringState, config: SpringConfig) -> Variant:
	"""
	计算阻尼力（F = -cv）
	
	@param state: 弹簧状态
	@param config: 弹簧配置
	
	@return: 阻尼力
	"""
	return _multiply_value(state.current_velocity, -config.damping)

func _update_velocity(velocity: Variant, force: Variant, mass: float, delta: float) -> Variant:
	"""
	更新速度（v = v + (F/m) * dt）
	
	@param velocity: 当前速度
	@param force: 总力
	@param mass: 质量
	@param delta: 时间增量
	
	@return: 更新后的速度
	"""
	var acceleration = _divide_value(force, mass)
	var delta_velocity = _multiply_value(acceleration, delta)
	return _add_values(velocity, delta_velocity)

func _update_position(position: Variant, velocity: Variant, delta: float) -> Variant:
	"""
	更新位置（x = x + v * dt）
	
	@param position: 当前位置
	@param velocity: 当前速度
	@param delta: 时间增量
	
	@return: 更新后的位置
	"""
	var delta_position = _multiply_value(velocity, delta)
	return _add_values(position, delta_position)

func _check_stability(state: SpringState, config: SpringConfig) -> bool:
	"""
	检查弹簧是否稳定
	
	@param state: 弹簧状态
	@param config: 弹簧配置
	
	@return: 如果位置和速度都低于阈值则返回true
	"""
	var position_error = _abs_value(_subtract_values(state.spring_position, state.target_position))
	var velocity_error = _abs_value(state.current_velocity)
	
	# 对于向量类型，检查长度是否小于阈值
	var position_magnitude = _get_magnitude(position_error)
	var velocity_magnitude = _get_magnitude(velocity_error)
	
	return position_magnitude < config.threshold and velocity_magnitude < config.threshold

func _calculate_delta_offset(state: SpringState) -> Variant:
	"""
	计算帧间变化量（当前帧相对于上一帧的偏移变化）
	这是应该应用到目标对象的增量偏移
	
	@param state: 弹簧状态
	
	@return: 帧间变化量
	"""
	# 返回当前帧与上一帧的偏移差
	return _subtract_values(state.spring_position, state.previous_spring_position)

func _calculate_offset(state: SpringState) -> Variant:
	"""
	计算总偏移量（相对于原始位置的总偏移）
	用于调试和状态查询
	
	@param state: 弹簧状态
	
	@return: 总偏移量
	"""
	# 返回相对于原始位置的总偏移
	return state.spring_position

# =============================================================================
# 数学运算辅助方法
# =============================================================================

func _add_values(a: Variant, b: Variant) -> Variant:
	"""
	两个值相加，支持多种数据类型
	
	@param a: 第一个值
	@param b: 第二个值
	
	@return: 相加结果
	"""
	# 处理Vector2类型
	if a is Vector2:
		if b is Vector2:
			return a + b
		elif b is float or b is int:
			return a + Vector2(float(b), float(b))
	# 处理Vector3类型
	elif a is Vector3:
		if b is Vector3:
			return a + b
		elif b is float or b is int:
			return a + Vector3(float(b), float(b), float(b))
	# 处理数值类型
	elif a is float or a is int:
		if b is float or b is int:
			return float(a) + float(b)
		elif b is Vector2:
			return Vector2(float(a), float(a)) + b
		elif b is Vector3:
			return Vector3(float(a), float(a), float(a)) + b
	else:
		push_warning("Unsupported addition types: " + str(typeof(a)) + " and " + str(typeof(b)))
		return a
	
	# 如果都不匹配，返回a
	return a

func _subtract_values(a: Variant, b: Variant) -> Variant:
	"""
	两个值相减，支持多种数据类型
	
	@param a: 被减数
	@param b: 减数
	
	@return: 相减结果
	"""
	# 处理Vector2类型
	if a is Vector2:
		if b is Vector2:
			return a - b
		elif b is float or b is int:
			return a - Vector2(float(b), float(b))
	# 处理Vector3类型
	elif a is Vector3:
		if b is Vector3:
			return a - b
		elif b is float or b is int:
			return a - Vector3(float(b), float(b), float(b))
	# 处理数值类型
	elif a is float or a is int:
		if b is float or b is int:
			return float(a) - float(b)
		elif b is Vector2:
			return Vector2(float(a), float(a)) - b
		elif b is Vector3:
			return Vector3(float(a), float(a), float(a)) - b
	else:
		push_warning("Unsupported subtraction types: " + str(typeof(a)) + " and " + str(typeof(b)))
		return a
	
	# 如果都不匹配，返回a
	return a

func _multiply_value(value: Variant, multiplier: float) -> Variant:
	"""
	值与标量相乘，支持多种数据类型
	
	@param value: 要乘的值
	@param multiplier: 乘数
	
	@return: 相乘结果
	"""
	if value is Vector2:
		return value * multiplier
	elif value is Vector3:
		return value * multiplier
	elif value is float or value is int:
		return float(value) * multiplier
	else:
		push_warning("Unsupported multiplication type: " + str(typeof(value)))
		return value

func _divide_value(value: Variant, divisor: float) -> Variant:
	"""
	值与标量相除，支持多种数据类型
	
	@param value: 被除数
	@param divisor: 除数
	
	@return: 相除结果
	"""
	if divisor == 0.0:
		push_warning("Division by zero")
		return value
	
	if value is Vector2:
		return value / divisor
	elif value is Vector3:
		return value / divisor
	elif value is float or value is int:
		return float(value) / divisor
	else:
		push_warning("Unsupported division type: " + str(typeof(value)))
		return value

func _abs_value(value: Variant) -> Variant:
	"""
	计算绝对值，支持多种数据类型
	
	@param value: 要计算绝对值的值
	
	@return: 绝对值
	"""
	if value is Vector2:
		return Vector2(abs(value.x), abs(value.y))
	elif value is Vector3:
		return Vector3(abs(value.x), abs(value.y), abs(value.z))
	elif value is float or value is int:
		return abs(float(value))
	else:
		push_warning("Unsupported abs type: " + str(typeof(value)))
		return value

func _get_magnitude(value: Variant) -> float:
	"""
	获取值的幅度（长度），支持多种数据类型
	
	@param value: 要计算幅度的值
	
	@return: 幅度值
	"""
	if value is Vector2:
		return value.length()
	elif value is Vector3:
		return value.length()
	elif value is float or value is int:
		return abs(float(value))
	else:
		push_warning("Unsupported magnitude type: " + str(typeof(value)))
		return 0.0

# =============================================================================
# 工具方法
# =============================================================================

func _get_spring_state(context: JuicyContext, property: String) -> SpringState:
	"""
	获取弹簧状态
	
	@param context: JuicyContext实例
	@param property: 属性名称
	
	@return: 弹簧状态
	"""
	return _spring_states[context.context_id][property]

func is_spring_stable(context: JuicyContext, property: String) -> bool:
	"""
	检查指定属性的弹簧是否已稳定
	
	@param context: JuicyContext实例
	@param property: 属性名称
	
	@return: 如果弹簧已稳定则返回true
	"""
	if not spring_properties.has(property):
		return true
	
	var state = _get_spring_state(context, property)
	var config = spring_properties[property]
	
	return state.is_stable

func get_spring_offset(context: JuicyContext, property: String) -> Variant:
	"""
	获取指定属性的当前弹簧偏移量
	
	@param context: JuicyContext实例
	@param property: 属性名称
	
	@return: 当前偏移量
	"""
	if not spring_properties.has(property):
		return _get_zero_value_for_property(property)
	
	var state = _get_spring_state(context, property)
	return _calculate_offset(state)

func _get_zero_value_for_property(property: String) -> Variant:
	"""
	获取属性的零值
	
	@param property: 属性名称
	
	@return: 对应类型的零值
	"""
	match property:
		"position", "global_position":
			return Vector2.ZERO
		"rotation", "global_rotation":
			return 0.0
		"scale":
			return Vector2.ZERO
		_:
			return 0.0

# =============================================================================
# 验证接口实现
# =============================================================================

func validate_context(context: JuicyContext) -> Dictionary:
	"""
	验证Context是否适合此Driver
	
	@param context: 要验证的JuicyContext实例
	
	@return: 验证结果字典
	"""
	var result = super.validate_context(context)
	
	# 检查弹簧资源
	var spring_resource = context.resource
	if not spring_resource or not "spring_data" in spring_resource:
		result.valid = false
		result.issues.append("Missing spring resource in context")
		return result
	
	var spring_data = spring_resource.spring_data if "spring_data" in spring_resource else []
	if spring_data.is_empty():
		result.valid = false
		result.issues.append("Spring data cannot be empty")
		return result
	
	# 检查弹簧数据的有效性
	for i in range(spring_data.size()):
		var data = spring_data[i]
		if not data is SpringData:
			result.valid = false
			result.issues.append("Expected SpringData at index " + str(i))
			continue
		
		if data.property.is_empty():
			result.valid = false
			result.issues.append("Property name cannot be empty at index " + str(i))
		
		if data.stiffness <= 0:
			result.valid = false
			result.issues.append("Stiffness must be greater than 0 at index " + str(i))
		
		if data.damping < 0:
			result.valid = false
			result.issues.append("Damping must be non-negative at index " + str(i))
		
		if data.mass <= 0:
			result.valid = false
			result.issues.append("Mass must be greater than 0 at index " + str(i))
		
		if data.threshold <= 0:
			result.valid = false
			result.issues.append("Threshold must be greater than 0 at index " + str(i))
	
	return result
