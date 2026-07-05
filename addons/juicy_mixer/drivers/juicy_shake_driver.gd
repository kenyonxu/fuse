# JuicyShakeDriver - 震动驱动器
# 实现各种震动效果，支持多维震动（2D/3D）
# 提供可配置的震动参数和平滑的震动衰减
# 基于FastNoiseLite实现高质量的噪声生成

class_name JuicyShakeDriver
extends JuicyDriver

# =============================================================================
# 震动配置结构
# =============================================================================

## 震动配置类，定义单个属性的震动参数
class ShakeConfig:
	## 震动振幅（像素/弧度/缩放系数）
	var amplitude: float = 10.0
	
	## 震动频率（Hz）
	var frequency: float = 10.0
	
	## 震动持续时间（秒）
	var duration: float = 1.0
	
	## 衰减类型
	var falloff: ShakeFalloff = ShakeFalloff.LINEAR
	
	## 噪声种子（0表示随机种子）
	var noise_seed: int = 0
	
	## 八度音数量（用于细节层次）
	var octaves: int = 1
	
	## 持久性（控制八度音的强度衰减）
	var persistence: float = 0.5
	
	## 间隙度（控制八度音的频率增长）
	var lacunarity: float = 2.0
	
	## 复制配置
	func duplicate() -> ShakeConfig:
		var config = ShakeConfig.new()
		config.amplitude = amplitude
		config.frequency = frequency
		config.duration = duration
		config.falloff = falloff
		config.noise_seed = noise_seed
		config.octaves = octaves
		config.persistence = persistence
		config.lacunarity = lacunarity
		return config

# =============================================================================
# 震动衰减类型枚举
# =============================================================================

## 震动衰减模式枚举
enum ShakeFalloff {
	LINEAR,        ## 线性衰减：强度随时间线性减少
	EXPONENTIAL,   ## 指数衰减：强度随时间指数减少
	LOGARITHMIC,   ## 对数衰减：强度随时间对数减少
	NONE           ## 无衰减：强度保持不变
}

# =============================================================================
# 状态管理
# =============================================================================

## 震动属性配置：属性名 -> ShakeConfig
var shake_properties: Dictionary = {}

## 震动状态：context_id -> {属性名: 状态字典}
var _shake_states: Dictionary = {}

# =============================================================================
# 生命周期管理
# =============================================================================

func _init():
	"""
	初始化震动驱动器
	设置驱动器名称和支持的属性列表
	"""
	driver_name = "JuicyShakeDriver"
	supported_properties = ["position", "rotation", "scale", "global_position", "global_rotation"]
	required_context_data = ["shake_data"]

func prepare(context: JuicyContext, delta: float, buffer: JuicyPropertyBuffer) -> void:
	"""
	准备震动数据，在效果开始前调用一次
	
	@param context: JuicyContext实例，包含效果运行所需的所有数据
	@param delta: 时间增量（秒）
	@param buffer: JuicyPropertyBuffer实例，用于写入属性值
	"""
	# 从Context中的Resource获取震动数据
	var shake_resource = context.resource
	if not shake_resource or not "shake_data" in shake_resource:
		push_warning("Invalid shake resource in context")
		return
	
	var shake_data = shake_resource.shake_data if "shake_data" in shake_resource else []
	if shake_data.is_empty():
		push_warning("No shake data found in resource")
		return
	
	# 初始化震动配置
	_initialize_shake_configs(context, shake_data)

	# 使用基类时间管理
	_initialize_driver_time(context)

	# 初始化震动状态
	_initialize_shake_states(context)

func process(context: JuicyContext, delta: float, buffer: JuicyPropertyBuffer) -> void:
	"""
	处理震动效果，每帧调用
	
	@param context: JuicyContext实例，包含效果运行所需的所有数据
	@param delta: 时间增量（秒）
	@param buffer: JuicyPropertyBuffer实例，用于写入属性值
	"""
	var start_time = _start_execution_timer()
	
	# 使用基类时间管理
	var effective_delta = _update_driver_time(context, delta)
	
	# 检查是否所有震动属性都已完成
	var all_properties_complete = true
	
	# 处理每个震动属性
	for property in shake_properties.keys():
		var config = shake_properties[property]
		var state = _get_shake_state(context, property)

		# 检查是否完成（使用基类时间）
		if not _is_time_based_complete(context, config.duration):
			all_properties_complete = false
		else:
			continue

		# 计算进度（使用基类时间）
		var progress = _get_driver_elapsed_time(context) / config.duration

		# 计算衰减系数
		var falloff_factor = _calculate_falloff_factor(progress, config)

		if falloff_factor <= 0.0:
			continue

		# 创建噪声生成器（每次都创建新的，避免状态污染）
		var noise = _create_noise_generator(config, property, context.context_id)

		# 生成噪声值（使用基类时间管理）
		var noise_value = _generate_noise_value(noise, _get_driver_elapsed_time(context), config, property)
		
		# 应用振幅和衰减
		var shake_offset = _apply_amplitude_and_falloff(noise_value, config.amplitude, falloff_factor, property)
		
		# 计算偏移量差值
		var offset_delta = _calculate_offset_delta(state.last_offset, shake_offset, property)
		
		# 更新状态
		state.last_offset = shake_offset
		
		# 写入缓冲区（使用ADDITIVE混合模式）
		_add_property_sample(buffer, context, property, offset_delta, JuicyPropertyBuffer.BlendMode.ADDITIVE)
	
	# 如果所有属性都已完成，标记上下文为完成
	if all_properties_complete:
		print("JuicyShakeDriver: [DEBUG] All shake properties completed, calling context.complete() for context ", context.context_id)
		context.complete()
	
	_end_execution_timer(start_time)

func cleanup(context: JuicyContext) -> void:
	"""
	清理震动数据，在效果结束时调用
	
	@param context: JuicyContext实例，包含效果运行所需的所有数据
	"""
	_cleanup_driver_time(context)
	_shake_states.erase(context.context_id)

# =============================================================================
# 内部实现 - 初始化
# =============================================================================

func _initialize_shake_configs(context: JuicyContext, shake_data: Array) -> void:
	"""
	初始化震动配置
	
	@param context: JuicyContext实例
	@param shake_data: 震动数据数组
	"""
	shake_properties.clear()
	
	for data in shake_data:
		# 处理Resource对象格式
		if data is ShakeData:
			if data.property.is_empty():
				push_warning("Invalid shake data: empty property name")
				continue
			
			var config = ShakeConfig.new()
			config.amplitude = data.amplitude
			config.frequency = data.frequency
			config.duration = data.duration
			config.falloff = data.falloff
			config.noise_seed = data.noise_seed
			config.octaves = data.octaves
			config.persistence = data.persistence
			config.lacunarity = data.lacunarity
			
			shake_properties[data.property] = config
		else:
			push_warning("Invalid shake data: expected ShakeData, got " + str(typeof(data)))
			continue

func _create_noise_generator(config: ShakeConfig, property: String, context_id: String) -> FastNoiseLite:
	"""
	创建噪声生成器（每次都创建新的，避免状态污染）

	@param config: ShakeConfig实例
	@param property: 属性名称
	@param context_id: 上下文ID，用于生成唯一种子

	@return: 配置好的FastNoiseLite实例
	"""
	var noise = FastNoiseLite.new()

	# 配置噪声参数
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	# 使用 context_id 作为种子的一部分，确保每个播放有不同的噪声序列
	var seed = config.noise_seed if config.noise_seed > 0 else hash(context_id + property)
	noise.seed = seed
	noise.frequency = config.frequency * 0.1  # 缩放频率以适应噪声生成

	# 配置分形参数（用于八度音效果）
	if config.octaves > 1:
		noise.fractal_type = FastNoiseLite.FRACTAL_FBM
		noise.fractal_octaves = config.octaves
		noise.fractal_gain = config.persistence
		noise.fractal_lacunarity = config.lacunarity

	return noise

func _initialize_shake_states(context: JuicyContext) -> void:
	"""
	初始化震动状态
	
	@param context: JuicyContext实例
	"""
	var context_id = context.context_id
	_shake_states[context_id] = {}
	
	for property in shake_properties.keys():
		var config = shake_properties[property]
		var initial_offset = _get_initial_offset_for_property(property)
		
		_shake_states[context_id][property] = {
			"last_offset": initial_offset
		}

# =============================================================================
# 内部实现 - 震动计算
# =============================================================================

func _calculate_falloff_factor(progress: float, config: ShakeConfig) -> float:
	"""
	计算衰减系数
	
	@param progress: 进度（0.0-1.0）
	@param config: 震动配置
	
	@return: 衰减系数（0.0-1.0）
	"""
	match config.falloff:
		ShakeFalloff.LINEAR:
			return 1.0 - progress
		
		ShakeFalloff.EXPONENTIAL:
			# 使用指数衰减，系数3.0提供明显的衰减效果
			return exp(-3.0 * progress)
		
		ShakeFalloff.LOGARITHMIC:
			# 对数衰减，确保在progress=1.0时为0
			if progress >= 1.0:
				return 0.0
			return 1.0 - log(1.0 + progress) / log(2.0)
		
		ShakeFalloff.NONE:
			return 1.0
		
		_:
			return 1.0 - progress

func _generate_noise_value(noise: FastNoiseLite, time: float, config: ShakeConfig, property: String) -> Variant:
	"""
	生成噪声值
	
	@param noise: FastNoiseLite噪声生成器
	@param time: 当前时间
	@param config: 震动配置
	@param property: 属性名称
	
	@return: 生成的噪声值
	"""
	var noise_time = time * config.frequency
	
	match property:
		"position", "global_position":
			# 2D位置震动：生成x和y两个噪声值
			var x_noise = noise.get_noise_2d(noise_time, 0.0)
			var y_noise = noise.get_noise_2d(noise_time, 1000.0)  # 使用不同的偏移量
			return Vector2(x_noise, y_noise)
		
		"rotation", "global_rotation":
			# 旋转震动：生成单个噪声值
			return noise.get_noise_1d(noise_time)
		
		"scale":
			# 缩放震动：生成统一的缩放噪声
			var scale_noise = noise.get_noise_1d(noise_time)
			return Vector2(scale_noise, scale_noise)
		
		_:
			# 默认：生成单个噪声值
			return noise.get_noise_1d(noise_time)

func _apply_amplitude_and_falloff(noise_value: Variant, amplitude: float, falloff_factor: float, property: String) -> Variant:
	"""
	应用振幅和衰减到噪声值
	
	@param noise_value: 原始噪声值
	@param amplitude: 振幅
	@param falloff_factor: 衰减系数
	@param property: 属性名称
	
	@return: 应用后的震动偏移值
	"""
	var final_amplitude = amplitude * falloff_factor
	
	match property:
		"position", "global_position":
			if noise_value is Vector2:
				# 确保噪声值在[-1, 1]范围内，然后应用振幅
				var clamped_noise = Vector2(clamp(noise_value.x, -1.0, 1.0), clamp(noise_value.y, -1.0, 1.0))
				return clamped_noise * final_amplitude
			else:
				return Vector2.ZERO
		
		"rotation", "global_rotation":
			if noise_value is float:
				# 确保噪声值在[-1, 1]范围内，然后应用振幅
				var clamped_noise = clamp(noise_value, -1.0, 1.0)
				return clamped_noise * final_amplitude
			else:
				return 0.0
		
		"scale":
			if noise_value is Vector2:
				# 缩放震动：基于1.0的相对缩放，确保噪声值在合理范围内
				var clamped_noise = Vector2(clamp(noise_value.x, -1.0, 1.0), clamp(noise_value.y, -1.0, 1.0))
				return Vector2(1.0, 1.0) + (clamped_noise * final_amplitude * 0.1)  # 缩放影响较小
			else:
				return Vector2(1.0, 1.0)
		
		_:
			if noise_value is float:
				# 确保噪声值在[-1, 1]范围内，然后应用振幅
				var clamped_noise = clamp(noise_value, -1.0, 1.0)
				return clamped_noise * final_amplitude
			else:
				return 0.0

func _get_initial_offset_for_property(property: String) -> Variant:
	"""
	获取属性的初始偏移值
	
	@param property: 属性名称
	
	@return: 初始偏移值
	"""
	match property:
		"position", "global_position":
			return Vector2.ZERO
		
		"rotation", "global_rotation":
			return 0.0
		
		"scale":
			return Vector2(1.0, 1.0)
		
		_:
			return 0.0

# =============================================================================
# 工具方法
# =============================================================================

func _calculate_offset_delta(last_offset: Variant, current_offset: Variant, property: String) -> Variant:
	"""
	计算偏移量差值（Delta），用于防止位置漂移
	
	@param last_offset: 上一帧的偏移量
	@param current_offset: 当前帧的偏移量
	@param property: 属性名称
	
	@return: 偏移量差值
	"""
	match property:
		"position", "global_position":
			if last_offset is Vector2 and current_offset is Vector2:
				return current_offset - last_offset
			else:
				return Vector2.ZERO
		
		"rotation", "global_rotation":
			if last_offset is float and current_offset is float:
				return current_offset - last_offset
			else:
				return 0.0
		
		"scale":
			if last_offset is Vector2 and current_offset is Vector2:
				# 对于缩放，计算相对变化
				return Vector2(
					current_offset.x - last_offset.x,
					current_offset.y - last_offset.y
				)
			else:
				return Vector2.ZERO
		
		_:
			if last_offset is float and current_offset is float:
				return current_offset - last_offset
			else:
				return 0.0

func _get_shake_state(context: JuicyContext, property: String) -> Dictionary:
	"""
	获取震动状态
	
	@param context: JuicyContext实例
	@param property: 属性名称
	
	@return: 震动状态字典
	"""
	return _shake_states[context.context_id][property]

func get_shake_progress(context: JuicyContext, property: String) -> float:
	"""
	获取指定属性的震动进度
	
	@param context: JuicyContext实例
	@param property: 属性名称
	
	@return: 震动进度（0.0-1.0）
	"""
	if not shake_properties.has(property):
		return 1.0
	
	var config = shake_properties[property]
	
	if config.duration <= 0.0:
		return 1.0
	
	var elapsed = _get_driver_elapsed_time(context)
	return clamp(elapsed / config.duration, 0.0, 1.0)

func is_shake_complete(context: JuicyContext, property: String) -> bool:
	"""
	检查指定属性的震动是否完成
	
	@param context: JuicyContext实例
	@param property: 属性名称
	
	@return: 如果震动完成则返回true
	"""
	if not shake_properties.has(property):
		return true
	
	var config = shake_properties[property]
	return _is_time_based_complete(context, config.duration)

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
	
	# 检查震动资源
	var shake_resource = context.resource
	if not shake_resource or not "shake_data" in shake_resource:
		result.valid = false
		result.issues.append("Missing shake resource in context")
		return result
	
	var shake_data = shake_resource.shake_data if "shake_data" in shake_resource else []
	if shake_data.is_empty():
		result.valid = false
		result.issues.append("Shake data cannot be empty")
		return result
	
	# 检查震动数据的有效性
	for i in range(shake_data.size()):
		var data = shake_data[i]
		if not data is ShakeData:
			result.valid = false
			result.issues.append("Expected ShakeData at index " + str(i))
			continue
		
		if data.property.is_empty():
			result.valid = false
			result.issues.append("Property name cannot be empty at index " + str(i))
		
		if data.amplitude <= 0:
			result.valid = false
			result.issues.append("Amplitude must be greater than 0 at index " + str(i))
		
		if data.frequency <= 0:
			result.valid = false
			result.issues.append("Frequency must be greater than 0 at index " + str(i))
		
		if data.duration <= 0:
			result.valid = false
			result.issues.append("Duration must be greater than 0 at index " + str(i))
	
	return result
