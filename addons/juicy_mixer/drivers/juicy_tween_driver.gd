# JuicyTweenDriver - 补间驱动器
# 实现平滑的属性补间动画，支持多种缓动曲线和过渡类型
# 处理多属性并行补间，提供灵活的补间配置

class_name JuicyTweenDriver
extends JuicyDriver

# =============================================================================
# 补间配置结构
# =============================================================================

## 补间配置类，定义单个属性的补间参数
class TweenConfig:
	## 起始值
	var from_value: Variant
	
	## 目标值
	var to_value: Variant
	
	## 缓动类型 (EASE_IN, EASE_OUT, EASE_IN_OUT)
	var ease_type: Tween.EaseType = Tween.EASE_IN_OUT
	
	## 过渡类型 (TRANS_LINEAR, TRANS_SINE, TRANS_QUAD等)
	var trans_type: Tween.TransitionType = Tween.TRANS_LINEAR
	
	## 延迟时间（秒）
	var delay: float = 0.0
	
	## 持续时间（秒）
	var duration: float = 1.0
	
	## 是否使用相对值
	var relative: bool = false
	
	## 复制配置
	func duplicate() -> TweenConfig:
		var config = TweenConfig.new()
		config.from_value = from_value
		config.to_value = to_value
		config.ease_type = ease_type
		config.trans_type = trans_type
		config.delay = delay
		config.duration = duration
		config.relative = relative
		return config

# =============================================================================
# 状态管理
# =============================================================================

## 补间属性配置：属性名 -> TweenConfig
var tween_properties: Dictionary = {}

## 属性状态：context_id -> {属性名: 状态字典}
var _property_states: Dictionary = {}

# =============================================================================
# 生命周期管理
# =============================================================================

func _init():
	"""
	初始化补间驱动器
	设置驱动器名称和支持的属性列表
	"""
	driver_name = "JuicyTweenDriver"
	supported_properties = ["position", "rotation", "scale", "modulate", "self_modulate", "size", "global_position", "global_rotation"]
	required_context_data = ["tween_data"]

func prepare(context: JuicyContext, delta: float, buffer: JuicyPropertyBuffer) -> void:
	"""
	准备补间数据，在效果开始前调用一次
	
	@param context: JuicyContext实例，包含效果运行所需的所有数据
	@param delta: 时间增量（秒）
	@param buffer: JuicyPropertyBuffer实例，用于写入属性值
	"""
	# 从Context中的Resource获取补间数据
	var tween_resource = context.resource
	if not tween_resource or not "tween_data" in tween_resource:
		push_warning("Invalid tween resource in context")
		return
	
	var tween_data = tween_resource.tween_data if "tween_data" in tween_resource else []
	if tween_data.is_empty():
		push_warning("No tween data found in resource")
		return
	
	# 初始化补间配置
	_initialize_tween_configs(context, tween_data)
	
	# 使用基类时间管理
	_initialize_driver_time(context)
	
	# 初始化属性状态
	_initialize_property_states(context)
	
	# 设置起始值
	_setup_start_values(context)

func process(context: JuicyContext, delta: float, buffer: JuicyPropertyBuffer) -> void:
	"""
	处理补间动画，每帧调用
	
	@param context: JuicyContext实例，包含效果运行所需的所有数据
	@param delta: 时间增量（秒）
	@param buffer: JuicyPropertyBuffer实例，用于写入属性值
	"""
	var start_time = _start_execution_timer()
	
	# 使用基类时间管理
	var effective_delta = _update_driver_time(context, delta)
	
	# 检查是否所有补间属性都已完成
	var all_properties_complete = true
	
	# 处理每个补间属性
	for property in tween_properties.keys():
		var config = tween_properties[property]
		var state = _get_property_state(context, property)
		
		# 检查补间是否完成（使用基类时间）
		var total_duration = config.delay + config.duration
		var is_complete = _is_time_based_complete(context, total_duration)
		if not is_complete:
			all_properties_complete = false
		
		# 检查延迟
		if _get_driver_elapsed_time(context) < config.delay:
			continue
		
		# 计算补间进度（使用基类时间）
		var elapsed = _get_driver_elapsed_time(context)
		var effective_elapsed = max(0.0, elapsed - config.delay)
		var progress = clamp(effective_elapsed / config.duration, 0.0, 1.0)
		
		# 应用缓动函数
		var eased_progress = _apply_easing(progress, config.ease_type, config.trans_type)
		
		# 计算当前值
		var current_value = _interpolate_value(config, eased_progress)
		
		# 更新状态
		state.current_value = current_value
		state.tween_progress = progress
		
		# 写入缓冲区
		_add_property_sample(buffer, context, property, current_value, JuicyPropertyBuffer.BlendMode.OVERRIDE_BASE)
	
	# 如果所有属性都已完成，标记上下文为完成
	if all_properties_complete:
		context.complete()
	
	_end_execution_timer(start_time)

func cleanup(context: JuicyContext) -> void:
	"""
	清理补间数据，在效果结束时调用
	
	@param context: JuicyContext实例，包含效果运行所需的所有数据
	"""
	_cleanup_driver_time(context)
	_property_states.erase(context.context_id)

# =============================================================================
# 内部实现 - 初始化
# =============================================================================

func _initialize_tween_configs(context: JuicyContext, tween_data: Array) -> void:
	"""
	初始化补间配置
	
	@param context: JuicyContext实例
	@param tween_data: 补间数据数组
	"""
	tween_properties.clear()
	
	for data in tween_data:
		# 处理Resource对象格式
		if data is TweenData:
			if data.property.is_empty():
				push_warning("Invalid tween data: empty property name")
				continue
			
			var config = TweenConfig.new()
			config.from_value = data.from_value
			config.to_value = data.to_value
			config.ease_type = data.ease_type
			config.trans_type = data.trans_type
			config.delay = data.delay
			config.duration = data.duration
			config.relative = data.relative
			
			tween_properties[data.property] = config
		else:
			push_warning("Invalid tween data: expected TweenData, got " + str(typeof(data)))
			continue

func _initialize_property_states(context: JuicyContext) -> void:
	"""
	初始化属性状态
	
	@param context: JuicyContext实例
	"""
	var context_id = context.context_id
	_property_states[context_id] = {}
	
	for property in tween_properties.keys():
		_property_states[context_id][property] = {
			"current_value": null,
			"tween_progress": 0.0,
			"is_complete": false
		}

func _setup_start_values(context: JuicyContext) -> void:
	"""
	设置起始值，处理相对值逻辑
	
	@param context: JuicyContext实例
	"""
	for property in tween_properties.keys():
		var config = tween_properties[property]
		var state = _get_property_state(context, property)
		
		# 处理相对值
		if config.relative:
			var current_value = context.target.get(property)
			config.from_value = current_value
			
			# 根据类型处理相对值计算
			if config.to_value is Vector2 and current_value is Vector2:
				config.to_value = current_value + config.to_value
			elif config.to_value is Vector3 and current_value is Vector3:
				config.to_value = current_value + config.to_value
			elif config.to_value is Color and current_value is Color:
				# 颜色相对值处理：调整RGBA分量
				var current_color = current_value as Color
				var target_color = config.to_value as Color
				config.to_value = Color(
					current_color.r + target_color.r,
					current_color.g + target_color.g,
					current_color.b + target_color.b,
					current_color.a + target_color.a
				)
			elif config.to_value is float or config.to_value is int:
				config.to_value = current_value + config.to_value
		
		state.current_value = config.from_value

# =============================================================================
# 内部实现 - 补间计算
# =============================================================================

func _interpolate_value(config: TweenConfig, progress: float) -> Variant:
	"""
	插值计算当前值
	
	@param config: 补间配置
	@param progress: 补间进度（0.0-1.0）
	
	@return: 插值后的当前值
	"""
	var from = config.from_value
	var to = config.to_value
	
	# 根据数据类型进行相应的插值计算
	if from is Vector2 and to is Vector2:
		return from.lerp(to, progress)
	elif from is Vector3 and to is Vector3:
		return from.lerp(to, progress)
	elif from is Color and to is Color:
		return from.lerp(to, progress)
	elif from is float or from is int:
		return lerp(float(from), float(to), progress)
	elif from is String or to is String:
		# 字符串类型：进度小于0.5返回from，否则返回to
		return from if progress < 0.5 else to
	else:
		# 其他类型使用简单插值或返回起始值
		push_warning("Unsupported interpolation type: " + str(typeof(from)))
		return from

func _apply_easing(progress: float, ease_type: Tween.EaseType, trans_type: Tween.TransitionType) -> float:
	"""
	应用缓动函数
	
	@param progress: 原始进度（0.0-1.0）
	@param ease_type: 缓动类型
	@param trans_type: 过渡类型
	
	@return: 应用缓动后的进度
	"""
	# 根据缓动类型和过渡类型正确计算
	var final_progress: float
	match ease_type:
		Tween.EASE_IN:
			# EASE_IN: 正常应用过渡函数
			final_progress = _apply_transition(progress, trans_type)
		Tween.EASE_OUT:
			# EASE_OUT: 反转进度，然后应用过渡函数，再反转回来
			final_progress = 1.0 - _apply_transition(1.0 - progress, trans_type)
		Tween.EASE_IN_OUT:
			# EASE_IN_OUT: 前半部分 EASE_IN，后半部分 EASE_OUT
			if progress < 0.5:
				final_progress = _apply_transition(progress * 2.0, trans_type) * 0.5
			else:
				final_progress = 1.0 - _apply_transition((1.0 - progress) * 2.0, trans_type) * 0.5
		_:
			final_progress = _apply_transition(progress, trans_type)
	
	return final_progress

func _apply_transition(progress: float, trans_type: Tween.TransitionType) -> float:
	"""
	应用过渡函数
	
	@param progress: 原始进度（0.0-1.0）
	@param trans_type: 过渡类型
	
	@return: 应用过渡后的进度
	"""
	match trans_type:
		Tween.TRANS_LINEAR:
			return progress
		
		Tween.TRANS_SINE:
			return 0.5 - 0.5 * cos(progress * PI)
		
		Tween.TRANS_QUAD:
			return progress * progress
		
		Tween.TRANS_CUBIC:
			return progress * progress * progress
		
		Tween.TRANS_QUART:
			return progress * progress * progress * progress
		
		Tween.TRANS_QUINT:
			return progress * progress * progress * progress * progress
		
		Tween.TRANS_EXPO:
			if progress == 0.0:
				return 0.0
			return pow(2.0, 10.0 * (progress - 1.0))
		
		Tween.TRANS_CIRC:
			return 1.0 - sqrt(1.0 - progress * progress)
		
		Tween.TRANS_BACK:
			var overshoot = 1.70158
			return progress * progress * ((overshoot + 1.0) * progress - overshoot)
		
		Tween.TRANS_BOUNCE:
			return _bounce_ease(progress)
		
		Tween.TRANS_ELASTIC:
			return _elastic_ease(progress)
		
		_:
			return progress

# =============================================================================
# 特殊缓动函数实现
# =============================================================================

func _bounce_ease(progress: float) -> float:
	"""
	弹跳缓动函数
	
	@param progress: 原始进度（0.0-1.0）
	
	@return: 弹跳缓动后的进度
	"""
	if progress < 1.0 / 2.75:
		return 7.5625 * progress * progress
	elif progress < 2.0 / 2.75:
		progress -= 1.5 / 2.75
		return 7.5625 * progress * progress + 0.75
	elif progress < 2.5 / 2.75:
		progress -= 2.25 / 2.75
		return 7.5625 * progress * progress + 0.9375
	else:
		progress -= 2.625 / 2.75
		return 7.5625 * progress * progress + 0.984375

func _elastic_ease(progress: float) -> float:
	"""
	弹性缓动函数
	
	@param progress: 原始进度（0.0-1.0）
	
	@return: 弹性缓动后的进度
	"""
	if progress == 0.0 or progress == 1.0:
		return progress
	
	var period = 0.3
	var s = period / 4.0
	progress -= 1.0
	return -(pow(2.0, 10.0 * progress) * sin((progress - s) * (2.0 * PI) / period))

# =============================================================================
# 工具方法
# =============================================================================

func _get_property_state(context: JuicyContext, property: String) -> Dictionary:
	"""
	获取属性状态
	
	@param context: JuicyContext实例
	@param property: 属性名称
	
	@return: 属性状态字典
	"""
	return _property_states[context.context_id][property]

func is_tween_complete(context: JuicyContext, property: String) -> bool:
	"""
	检查指定属性的补间是否完成
	
	@param context: JuicyContext实例
	@param property: 属性名称
	
	@return: 如果补间完成则返回true
	"""
	if not tween_properties.has(property):
		return true
	
	var config = tween_properties[property]
	
	# 使用基类时间管理和容差来避免浮点精度问题
	var total_duration = config.delay + config.duration
	return _is_time_based_complete(context, total_duration)

func get_tween_progress(context: JuicyContext, property: String) -> float:
	"""
	获取指定属性的补间进度
	
	@param context: JuicyContext实例
	@param property: 属性名称
	
	@return: 补间进度（0.0-1.0）
	"""
	if not tween_properties.has(property):
		return 1.0
	
	var config = tween_properties[property]
	
	var total_duration = config.delay + config.duration
	if total_duration <= 0.0:
		return 1.0
	
	var elapsed = _get_driver_elapsed_time(context)
	return clamp(elapsed / total_duration, 0.0, 1.0)

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
	
	# 检查补间数据
	var tween_data = _get_context_value(context, "tween_data")
	if tween_data == null:
		result.valid = false
		result.issues.append("Missing tween data in context")
	elif not tween_data is Array:
		result.valid = false
		result.issues.append("Tween data must be an array")
	elif tween_data.is_empty():
		result.valid = false
		result.issues.append("Tween data cannot be empty")
	
	# 检查补间数据的有效性
	if tween_data is Array:
		for i in range(tween_data.size()):
			var data = tween_data[i]
			if data == null or data.property == null or data.property.is_empty():
				result.valid = false
				result.issues.append("Property name cannot be empty at index " + str(i))
			
			if data == null or data.from_value == null or data.to_value == null:
				result.valid = false
				result.issues.append("Missing from_value or to_value at index " + str(i))
			
			if data == null or data.duration == null or float(data.duration) <= 0:
				result.valid = false
				result.issues.append("Duration must be greater than 0 at index " + str(i))
	
	return result
