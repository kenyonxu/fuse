# JuicyTweenResource - 补间资源类
# 定义补间效果的配置，支持多种缓动曲线和过渡类型
# 提供类型安全的配置方法和完整的编辑器支持

@tool
class_name JuicyTweenResource
extends JuicyFeedbackResource

# =============================================================================
# 资源属性
# =============================================================================

## 补间数据数组
@export var tween_data: Array[TweenData] = []

## 是否循环播放
var loop: bool = false

## 循环延迟（秒）
var loop_delay: float = 0.0

# =============================================================================
# 资源接口实现
# =============================================================================

func create_drivers() -> Array[JuicyDriver]:
	"""
	创建并返回补间驱动器实例
	
	@return: 包含JuicyTweenDriver实例的数组
	"""
	var driver = JuicyTweenDriver.new()
	return [driver]

func validate_config() -> ValidationResult:
	"""
	验证资源配置的有效性
	
	@return: 验证结果
	"""
	var result = super.validate_config()
	
	# 检查补间数据
	if tween_data.is_empty():
		result.valid = false
		result.issues.append("Tween data cannot be empty")
	
	# 验证每个补间数据
	for i in range(tween_data.size()):
		var data = tween_data[i]
		if data == null:
			result.valid = false
			result.issues.append("Tween data at index %d is null" % i)
			continue
			
		var data_result = data.validate()
		
		if not data_result.valid:
			result.valid = false
			for issue in data_result.issues:
				result.issues.append("Tween data at index %d: %s" % [i, issue])
		
		for warning in data_result.warnings:
			result.warnings.append("Tween data at index %d: %s" % [i, warning])
	
	# 检查属性名重复
	var properties = {}
	for data in tween_data:
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

func add_tween_data(property: String, from_value: Variant, to_value: Variant, 
				   duration: float = 1.0, delay: float = 0.0, 
				   ease_type: int = Tween.EASE_IN_OUT, trans_type: int = Tween.TRANS_LINEAR,
				   relative: bool = false) -> TweenData:
	"""
	添加新的补间数据
	
	@param property: 目标属性名称
	@param from_value: 起始值
	@param to_value: 目标值
	@param duration: 持续时间（秒）
	@param delay: 延迟时间（秒）
	@param ease_type: 缓动类型
	@param trans_type: 过渡类型
	@param relative: 是否使用相对值
	
	@return: 创建的TweenData实例
	"""
	var data = TweenData.new()
	data.property = property
	data.from_value = from_value
	data.to_value = to_value
	data.duration = duration
	data.delay = delay
	data.ease_type = ease_type
	data.trans_type = trans_type
	data.relative = relative
	
	tween_data.append(data)
	return data

# 批量添加tween_data
func batch_add_data(data_set: Array[TweenData]) -> void:
	tween_data.append(data_set)

func remove_tween_data(index: int) -> bool:
	"""
	移除指定索引的补间数据
	
	@param index: 要移除的索引
	
	@return: 如果成功移除则返回true
	"""
	if index < 0 or index >= tween_data.size():
		return false
	
	tween_data.remove_at(index)
	return true

func clear_tween_data() -> void:
	"""
	清除所有补间数据
	"""
	tween_data.clear()

func get_tween_data_count() -> int:
	"""
	获取补间数据数量
	
	@return: 补间数据数量
	"""
	return tween_data.size()

func get_tween_data(index: int) -> TweenData:
	"""
	获取指定索引的补间数据
	
	@param index: 索引
	
	@return: TweenData实例，如果索引无效则返回null
	"""
	if index < 0 or index >= tween_data.size():
		return null
	
	return tween_data[index]

# =============================================================================
# 序列化支持
# =============================================================================

func _to_string() -> String:
	"""
	获取对象的字符串表示
	
	@return: 描述字符串
	"""
	var count = tween_data.size()
	var desc = "%s(tween_count=%d, duration=%.2f, loop=%s)" % [
		get_resource_type(), count, duration, str(loop)
	]
	
	if count > 0:
		desc += "\nTween data:"
		for i in range(min(3, count)):  # 最多显示前3个
			if tween_data[i] != null:
				desc += "\n  [%d] %s" % [i, tween_data[i].get_description()]
		if count > 3:
			desc += "\n  ... and %d more" % (count - 3)
	
	return desc

# =============================================================================
# 基类重写
# =============================================================================
func get_duration() -> float:
	var max_duration := 0.0
	
	# 计算所有补间数据的最大完成时间
	for data in tween_data:
		if data != null:
			var total_time = data.delay + data.duration
			max_duration = max(max_duration, total_time)
	
	# 如果支持循环
	if loop and loop_delay > 0.0:
		duration = max_duration + loop_delay
	else:
		duration = max_duration
	
	return duration

func get_duration_source() -> JuicyFeedbackResource.DurationSource:
	"""
	返回Tween资源的时长类型
	Tween资源提供精确时长，因为每个TweenData都有明确的duration字段
	"""
	return JuicyFeedbackResource.DurationSource.EXACT

# 实现JuicyFeedbackResource的抽象方法
func get_data_count() -> int:
	return tween_data.size()  # TweenData本身是单个数据项

func get_data_at(index: int) -> JuicyFeedbackData:
	var item = tween_data.get(index)
	return item

func set_data_at(index: int, source: JuicyFeedbackData) -> void:
	var item = tween_data.get(index)

	item.property = source.property
	item.from_value = source.from_value
	item.to_value = source.to_value
	item.ease_type = source.ease_type
	item.trans_type = source.trans_type
	item.delay = source.delay
	item.duration = source.duration
	item.relative = source.relative

func get_data() -> Array[JuicyFeedbackData]:
	return tween_data as Array[JuicyFeedbackData]
