# JuicyShakeResource - 震动资源类
# 定义震动效果的配置，支持多种震动参数和衰减类型
# 提供类型安全的配置方法和完整的编辑器支持

@tool
class_name JuicyShakeResource
extends JuicyFeedbackResource

# =============================================================================
# 资源属性
# =============================================================================

## 震动数据数组
@export var shake_data: Array[ShakeData] = []

## 是否循环播放
var loop: bool = false

## 循环延迟（秒）
var loop_delay: float = 0.0

# =============================================================================
# 资源接口实现
# =============================================================================

func create_drivers() -> Array[JuicyDriver]:
	"""
	创建并返回震动驱动器实例
	
	@return: 包含JuicyShakeDriver实例的数组
	"""
	var driver = JuicyShakeDriver.new()
	return [driver]

func validate_config() -> ValidationResult:
	"""
	验证资源配置的有效性
	
	@return: 验证结果
	"""
	var result = super.validate_config()
	
	# 检查震动数据
	if shake_data.is_empty():
		result.valid = false
		result.issues.append("Shake data cannot be empty")
	
	# 验证每个震动数据
	for i in range(shake_data.size()):
		var data = shake_data[i]
		if data == null:
			result.valid = false
			result.issues.append("Shake data at index %d is null" % i)
			continue
			
		var data_result = data.validate()
		
		if not data_result.valid:
			result.valid = false
			for issue in data_result.issues:
				result.issues.append("Shake data at index %d: %s" % [i, issue])
		
		for warning in data_result.warnings:
			result.warnings.append("Shake data at index %d: %s" % [i, warning])
	
	# 检查属性名重复
	var properties = {}
	for data in shake_data:
		if data == null:
			continue
		if data.property in properties:
			result.warnings.append("Duplicate property name: %s" % data.property)
		else:
			properties[data.property] = true
	
	return result

# =============================================================================
# 编辑器支持
# =============================================================================

func _get_property_list() -> Array[Dictionary]:
	"""
	获取自定义属性列表，用于编辑器显示
	
	@return: 属性列表
	"""
	var properties = []
	
	# 添加循环相关属性
	properties.append({
		"name": "loop",
		"type": TYPE_BOOL,
		"hint": PROPERTY_HINT_NONE,
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	properties.append({
		"name": "loop_delay",
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0,10,0.1,or_greater",
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	return properties

func _get_configuration_warning() -> String:
	"""
	获取配置警告信息
	
	@return: 警告信息字符串
	"""
	var result = validate_config()
	if not result.valid:
		return "Configuration errors: " + ", ".join(result.issues)
	
	if not result.warnings.is_empty():
		return "Configuration warnings: " + ", ".join(result.warnings)
	
	return ""

# =============================================================================
# 实用方法
# =============================================================================

func add_shake_data(property: String, amplitude: float = 10.0, frequency: float = 10.0,
				   duration: float = 1.0, falloff: int = 0, noise_seed: int = 0,
				   octaves: int = 1, persistence: float = 0.5, lacunarity: float = 2.0) -> ShakeData:
	"""
	添加新的震动数据
	
	@param property: 目标属性名称
	@param amplitude: 振幅
	@param frequency: 频率
	@param duration: 持续时间
	@param falloff: 衰减类型
	@param noise_seed: 噪声种子
	@param octaves: 八度音数量
	@param persistence: 持久性
	@param lacunarity: 间隙度
	
	@return: 创建的ShakeData实例
	"""
	var data = ShakeData.new()
	data.property = property
	data.amplitude = amplitude
	data.frequency = frequency
	data.duration = duration
	data.falloff = falloff
	data.noise_seed = noise_seed
	data.octaves = octaves
	data.persistence = persistence
	data.lacunarity = lacunarity
	
	shake_data.append(data)
	return data

# 批量添加shake_data
func batch_add_data(data_set: Array[ShakeData]) -> void:
	shake_data.append(data_set)



func remove_shake_data(index: int) -> bool:
	"""
	移除指定索引的震动数据
	
	@param index: 要移除的索引
	
	@return: 如果成功移除则返回true
	"""
	if index < 0 or index >= shake_data.size():
		return false
	
	shake_data.remove_at(index)
	return true

func clear_shake_data() -> void:
	"""
	清除所有震动数据
	"""
	shake_data.clear()

func get_shake_data_count() -> int:
	"""
	获取震动数据数量
	
	@return: 震动数据数量
	"""
	return shake_data.size()

func get_shake_data(index: int) -> ShakeData:
	"""
	获取指定索引的震动数据
	
	@param index: 索引
	
	@return: ShakeData实例，如果索引无效则返回null
	"""
	if index < 0 or index >= shake_data.size():
		return null
	
	return shake_data[index]

# =============================================================================
# 序列化支持
# =============================================================================

func _to_string() -> String:
	"""
	获取对象的字符串表示
	
	@return: 描述字符串
	"""
	var count = shake_data.size()
	var desc = "%s(shake_count=%d, duration=%.2f, loop=%s)" % [
		get_resource_type(), count, duration, str(loop)
	]
	
	if count > 0:
		desc += "\nShake data:"
		for i in range(min(3, count)):  # 最多显示前3个
			if shake_data[i] != null:
				desc += "\n  [%d] %s" % [i, shake_data[i].get_description()]
		if count > 3:
			desc += "\n  ... and %d more" % (count - 3)
	
	return desc

# =============================================================================
# 基类重写
# =============================================================================

func get_duration_source() -> DurationSource:
	"""
	返回震动资源的时长类型
	
	@return: EXACT - Shake duration 是用户明确设置的
	"""
	return DurationSource.EXACT

func get_duration() -> float:
	var max_duration := 0.0
	
	# 计算所有补间数据的最大完成时间
	for data in shake_data:
		if data != null:
			var total_time = data.duration
			max_duration = max(max_duration, total_time)
	
	# 如果支持循环
	if loop and loop_delay > 0.0:
		duration = max_duration + loop_delay
	else:
		duration = max_duration
	
	return duration


# 实现JuicyFeedbackResource的抽象方法
func get_data_count() -> int:
	return shake_data.size()  # TweenData本身是单个数据项

func get_data_at(index: int) -> JuicyFeedbackData:
	var item = shake_data.get(index)
	return item

func set_data_at(index: int, source: JuicyFeedbackData) -> void:
	var item = shake_data.get(index)

	item.property = source.property
	item.amplitude = source.amplitude
	item.frequency = source.frequency
	item.duration = source.duration
	item.falloff = source.falloff
	item.noise_seed = source.noise_seed
	item.persistence = source.persistence
	item.octaves = source.octaves
	item.lacunarity = source.lacunarity

func get_data() -> Array:
	return shake_data
