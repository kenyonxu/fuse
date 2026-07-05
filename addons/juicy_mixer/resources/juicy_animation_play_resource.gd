# JuicyAnimationPlayResource - 动画播放资源类
# 定义动画播放效果的配置，支持多种播放模式和状态还原
# 提供类型安全的配置方法和完整的编辑器支持

@tool
class_name JuicyAnimationPlayResource
extends JuicyFeedbackResource

# =============================================================================
# 资源属性
# =============================================================================

## 动画播放数据数组
@export var animation_data: Array[AnimationPlayData] = []

## 是否循环播放
var loop: bool = false

## 循环延迟（秒）
var loop_delay: float = 0.0

## 默认完成动作（当单个动画数据未指定时使用）
var default_on_complete_action: AnimationPlayData.OnCompleteAction = AnimationPlayData.OnCompleteAction.KEEP_LAST_FRAME

## 是否启用状态还原中间件集成
var enable_state_restoration: bool = true

# =============================================================================
# 资源接口实现
# =============================================================================

func create_drivers() -> Array[JuicyDriver]:
	"""
	创建并返回动画播放驱动器实例
	
	@return: 包含JuicyAnimationPlayDriver实例的数组
	"""
	var driver = JuicyAnimationPlayDriver.new()
	return [driver]

func validate_config() -> ValidationResult:
	"""
	验证资源配置的有效性
	
	@return: 验证结果
	"""
	var result = super.validate_config()
	
	# 检查动画数据
	if animation_data.is_empty():
		result.valid = false
		result.issues.append("Animation data cannot be empty")
	
	# 验证每个动画数据
	for i in range(animation_data.size()):
		var data = animation_data[i]
		if data == null:
			result.valid = false
			result.issues.append("Animation data at index %d is null" % i)
			continue
			
		var data_result = data.validate()
		
		if not data_result.valid:
			result.valid = false
			for issue in data_result.issues:
				result.issues.append("Animation data at index %d: %s" % [i, issue])
		
		for warning in data_result.warnings:
			result.warnings.append("Animation data at index %d: %s" % [i, warning])
	
	# 检查循环配置
	if loop and loop_delay < 0:
		result.valid = false
		result.issues.append("Loop delay cannot be negative")
	
	return result

# =============================================================================
# 编辑器支持
# =============================================================================

func _get_property_list() -> Array[Dictionary]:
	"""
	获取自定义属性列表，用于编辑器显示
	
	@return: 属性列表
	"""
	var properties = super._get_property_list()
	
	# 动画配置组
	properties.append({
		"name": "Animation Configuration",
		"type": TYPE_NIL,
		"hint": PROPERTY_HINT_NONE,
		"usage": PROPERTY_USAGE_GROUP
	})
	
	# 循环配置组
	properties.append({
		"name": "Loop Configuration",
		"type": TYPE_NIL,
		"hint": PROPERTY_HINT_NONE,
		"usage": PROPERTY_USAGE_GROUP
	})
	
	# 循环播放
	properties.append({
		"name": "loop",
		"type": TYPE_BOOL,
		"hint": PROPERTY_HINT_NONE,
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	# 循环延迟
	properties.append({
		"name": "loop_delay",
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0,10,0.1,or_greater",
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	# 默认完成动作
	properties.append({
		"name": "default_on_complete_action",
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "RESTORE_STATE,KEEP_LAST_FRAME,RESET_TRACKS",
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	# 状态还原开关
	properties.append({
		"name": "enable_state_restoration",
		"type": TYPE_BOOL,
		"hint": PROPERTY_HINT_NONE,
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

func add_animation_data(target: NodePath, animation: String, 
					   play_mode: AnimationPlayData.PlayMode = AnimationPlayData.PlayMode.NORMAL,
					   end_at: float = 1.0, blend_in: float = 0.1) -> AnimationPlayData:
	"""
	添加新的动画播放数据
	
	@param target: 目标节点路径
	@param animation: 动画名称
	@param play_mode: 播放模式
	@param end_at: 停止位置
	@param blend_in: 混入时间
	@return: 创建的AnimationPlayData实例
	"""
	var data = AnimationPlayData.new()
	data.target = target
	data.target_animation = animation
	data.play_mode = play_mode
	data.end_at = end_at
	data.blend_in_time = blend_in
	data.on_complete_action = default_on_complete_action  # 使用默认值
	
	animation_data.append(data)
	return data

func remove_animation_data(index: int) -> bool:
	"""
	移除指定索引的动画数据
	
	@param index: 要移除的索引
	@return: 如果成功移除则返回true
	"""
	if index < 0 or index >= animation_data.size():
		return false
	
	animation_data.remove_at(index)
	return true

func clear_animation_data() -> void:
	"""
	清除所有动画数据
	"""
	animation_data.clear()

func get_animation_data_count() -> int:
	"""
	获取动画数据数量
	
	@return: 动画数据数量
	"""
	return animation_data.size()

func get_animation_data(index: int) -> AnimationPlayData:
	"""
	获取指定索引的动画数据
	
	@param index: 索引
	@return: AnimationPlayData实例，如果索引无效则返回null
	"""
	if index < 0 or index >= animation_data.size():
		return null
	
	return animation_data[index]

# =============================================================================
# 序列化支持
# =============================================================================

func _to_string() -> String:
	"""
	获取对象的字符串表示
	
	@return: 描述字符串
	"""
	var count = animation_data.size()
	var desc = "%s(animation_count=%d, duration=%.2f, loop=%s)" % [
		get_resource_type(), count, duration, str(loop)
	]
	
	if count > 0:
		desc += "\nAnimation data:"
		for i in range(min(3, count)):  # 最多显示前3个
			if animation_data[i] != null:
				desc += "\n  [%d] %s" % [i, animation_data[i].get_description()]
		if count > 3:
			desc += "\n  ... and %d more" % (count - 3)
	
	return desc

# =============================================================================
# 基类重写
# =============================================================================

func get_duration_source() -> DurationSource:
	"""
	返回动画播放资源的时长类型
	
	@return: EXACT - 动画时长是精确的
	"""
	return DurationSource.EXACT

func get_duration() -> float:
	"""
	计算资源的总持续时间
	
	@return: 总持续时间（秒）
	"""
	if animation_data.is_empty():
		return 1.0
	
	var total_duration = 0.0
	
	for data in animation_data:
		if data == null:
			continue
		
		# 计算单个动画的实际播放时间
		var anim_duration = _calculate_animation_duration(data)
		total_duration += anim_duration
	
	# 如果启用循环，添加循环延迟
	if loop and loop_delay > 0:
		duration = total_duration + loop_delay
	else:
		duration = total_duration
	
	# 确保duration不为0或负数
	if duration <= 0:
		duration = 1.0
	
	return duration

func _calculate_animation_duration(data: AnimationPlayData) -> float:
	"""
	计算单个动画数据的播放时长
	
	@param data: 动画播放数据
	@return: 播放时长（秒）
	"""
	# 使用不依赖 context_node 的方法获取动画长度
	var length = data.get_animation_length()

	return length  # 默认值，将在驱动器中重新计算

# 实现JuicyFeedbackResource的抽象方法
func get_data_count() -> int:
	return animation_data.size()  # TweenData本身是单个数据项

func get_data_at(index: int) -> JuicyFeedbackData:
	var item = animation_data.get(index)
	return item

func set_data_at(index: int, source: JuicyFeedbackData) -> void:
	var item = animation_data.get(index)

	item.target = source.target
	item.target_animation = source.target_animation
	item.play_mode = source.play_mode
	item.end_at = source.end_at
	item.blend_in_time = source.blend_in_time
	item.on_complete_action = source.on_complete_action

func get_data() -> Array:
	return animation_data
