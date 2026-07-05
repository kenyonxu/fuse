# JuicySpringResource - 弹簧资源类
# 定义弹簧效果的配置，支持物理模拟参数
# 提供类型安全的配置方法和完整的编辑器支持

@tool
class_name JuicySpringResource
extends JuicyFeedbackResource

# =============================================================================
# 资源属性
# =============================================================================

## 弹簧数据数组
@export var spring_data: Array[SpringData] = []

## 是否循环播放
var loop: bool = false

## 循环延迟（秒）
var loop_delay: float = 0.0

# =============================================================================
# 资源接口实现
# =============================================================================

func create_drivers() -> Array[JuicyDriver]:
	"""
	创建并返回弹簧驱动器实例
	
	@return: 包含JuicySpringDriver实例的数组
	"""
	var driver = JuicySpringDriver.new()
	return [driver]

func validate_config() -> ValidationResult:
	"""
	验证资源配置的有效性
	
	@return: 验证结果
	"""
	var result = super.validate_config()
	
	# 检查弹簧数据
	if spring_data.is_empty():
		result.valid = false
		result.issues.append("Spring data cannot be empty")
	
	# 验证每个弹簧数据
	for i in range(spring_data.size()):
		var data = spring_data[i]
		if data == null:
			result.valid = false
			result.issues.append("Spring data at index %d is null" % i)
			continue
			
		var data_result = data.validate()
		
		if not data_result.valid:
			result.valid = false
			for issue in data_result.issues:
				result.issues.append("Spring data at index %d: %s" % [i, issue])
		
		for warning in data_result.warnings:
			result.warnings.append("Spring data at index %d: %s" % [i, warning])
	
	# 检查属性名重复
	var properties = {}
	for data in spring_data:
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

func add_spring_data(property: String, target_value: Variant,
					stiffness: float = 100.0, damping: float = 10.0,
					mass: float = 1.0, initial_velocity: Variant = 0.0,
					threshold: float = 0.01) -> SpringData:
	"""
	添加新的弹簧数据
	
	@param property: 目标属性名称
	@param target_value: 目标值
	@param stiffness: 刚度
	@param damping: 阻尼
	@param mass: 质量
	@param initial_velocity: 初始速度
	@param threshold: 稳定阈值
	
	@return: 创建的SpringData实例
	"""
	var data = SpringData.new()
	data.property = property
	data.target_value = target_value
	data.stiffness = stiffness
	data.damping = damping
	data.mass = mass
	data.initial_velocity = initial_velocity
	data.threshold = threshold
	
	spring_data.append(data)
	return data

# 批量添加spring_data
func batch_add_data(data_set: Array[SpringData]) -> void:
	spring_data.append(data_set)

func remove_spring_data(index: int) -> bool:
	"""
	移除指定索引的弹簧数据
	
	@param index: 要移除的索引
	
	@return: 如果成功移除则返回true
	"""
	if index < 0 or index >= spring_data.size():
		return false
	
	spring_data.remove_at(index)
	return true

func clear_spring_data() -> void:
	"""
	清除所有弹簧数据
	"""
	spring_data.clear()

func get_spring_data_count() -> int:
	"""
	获取弹簧数据数量
	
	@return: 弹簧数据数量
	"""
	return spring_data.size()

func get_spring_data(index: int) -> SpringData:
	"""
	获取指定索引的弹簧数据
	
	@param index: 索引
	
	@return: SpringData实例，如果索引无效则返回null
	"""
	if index < 0 or index >= spring_data.size():
		return null
	
	return spring_data[index]

# =============================================================================
# 序列化支持
# =============================================================================

func _to_string() -> String:
	"""
	获取对象的字符串表示
	
	@return: 描述字符串
	"""
	var count = spring_data.size()
	var desc = "%s(spring_count=%d, duration=%.2f, loop=%s)" % [
		get_resource_type(), count, duration, str(loop)
	]
	
	if count > 0:
		desc += "\nSpring data:"
		for i in range(min(3, count)):  # 最多显示前3个
			if spring_data[i] != null:
				desc += "\n  [%d] %s" % [i, spring_data[i].get_description()]
		if count > 3:
			desc += "\n  ... and %d more" % (count - 3)
	
	return desc

# =============================================================================
# 基类重写
# =============================================================================
func get_duration() -> float:	
	# 基于物理参数估算
	var estimated_time := 0.0
	for data in spring_data:
		if data != null:
			# 基于弹簧公式估算稳定时间
			# T ≈ 2π * sqrt(m/k)，考虑阻尼
			var natural_frequency = sqrt(data.stiffness / data.mass)
			var damping_ratio = data.damping / (2.0 * sqrt(data.stiffness * data.mass))
			
			# 更精确的估算公式
			var damping_ratio_safe = max(0.01, damping_ratio)  # 防止除零
			var estimated = 4.0 / (damping_ratio_safe * natural_frequency)
			estimated_time = max(estimated_time, estimated)
	
	return estimated_time

func get_duration_source() -> JuicyFeedbackResource.DurationSource:
	"""
	返回Spring资源的时长类型
	Spring资源提供估算时长，因为时长基于物理参数通过公式计算
	"""
	return JuicyFeedbackResource.DurationSource.ESTIMATED

func _notify_duration_changed():
	"""通知时长已变更，由子类在参数变化时调用"""
	var old_duration = duration
	duration = get_duration()
	if duration != old_duration:
		duration_changed.emit(duration)

# 实现JuicyFeedbackResource的抽象方法
func get_data_count() -> int:
	return spring_data.size()  # TweenData本身是单个数据项

func get_data_at(index: int) -> JuicyFeedbackData:
	var item = spring_data.get(index)
	return item

func set_data_at(index: int, source: JuicyFeedbackData) -> void:
	var item = spring_data.get(index)

	item.property = source.property
	item.target_value = source.target_value
	item.stiffness = source.stiffness
	item.damping = source.damping
	item.mass = source.mass
	item.initial_velocity = source.initial_velocity
	item.threshold = source.relative


func get_data() -> Array:
	return spring_data
