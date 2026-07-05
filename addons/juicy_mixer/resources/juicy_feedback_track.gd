# JuicyFeedbackTrack - 反馈轨道
# 触发子效果，支持参数映射到子效果
# 处理编辑器和运行时环境的目标获取

@tool
class_name JuicyFeedbackTrack
extends JuicyTrack

# 基础配置
@export var resource: JuicyFeedbackResource      # 触发的子效果
@export var start_time: float = 0.0              # 开始时间
@export var duration: float = -1.0               # -1 表示使用资源自身时长，>0 表示手动设置的具体时长
@export var auto_sync_duration: bool = true       # 是否自动同步资源时长变化（仅在duration=-1时有效）
@export var time_scale_curve: Curve              # 可选：动态控制子效果的时间缩放
# condition 属性已在基类中定义，这里不需要重复定义

# 高级属性               # 可选：指定不同的目标
@export var inherit_time_scale: bool = true       # 是否继承Timeline的时间缩放
@export var interrupt_on_restart: bool = true    # 重新开始时是否中断之前的实例
@export var blend_in_time: float = 0.0          # 淡入时间
@export var blend_out_time: float = 0.0         # 淡出时间
@export var auto_start: bool = true              # 是否自动开始
@export var loop_sub_effect: bool = false        # 是否循环子效果

# 参数映射系统 - 轨道级别的参数绑定到子效果
@export var use_parameter_mapping: bool = false    # 参数映射开关，默认关闭
@export var parameter_mappings: Array[JuicyParameterMapping] = []

# 运行时状态
var _active_context_id: String = ""             # 当前活跃的子上下文ID
var _last_trigger_time: float = -1.0           # 上次触发时间
var _trigger_count: int = 0                     # 触发次数
var _has_entered_range: bool = false            # 是否已经进入过时间范围（防止每帧重复触发）

## 编辑器属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	
	# 添加目标节点路径（使用基类的 target）
	properties.append({
		"name": "target",
		"type": TYPE_NODE_PATH,
		"hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES,
		"hint_string": "Node",
		"default": NodePath(""),
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
	})

	return properties



func get_track_type() -> String:
	return "Feedback"

func validate_track() -> String:
	if not resource:
		return "Feedback resource cannot be null"
	
	if start_time < 0.0:
		return "Start time cannot be negative"
	
	if duration < -1.0:
		return "Duration cannot be less than -1"
	
	if blend_in_time < 0.0:
		return "Blend in time cannot be negative"
	
	if blend_out_time < 0.0:
		return "Blend out time cannot be negative"
	
	# 验证参数映射
	if use_parameter_mapping:
		for i in range(parameter_mappings.size()):
			var mapping = parameter_mappings[i]
			if not mapping:
				return "Parameter mapping at index " + str(i) + " cannot be null"
			
			var mapping_error = mapping.validate_mapping() if mapping.has_method("validate_mapping") else ""
			if not mapping_error.is_empty():
				return "Parameter mapping error at index " + str(i) + ": " + mapping_error
	
	return ""

# 获取实际持续时间
func get_actual_duration() -> float:
	"""
	获取实际持续时间
	
	@return: 持续时间（秒）
	"""
	if duration > 0:
		return duration
	elif resource and resource.has_method("get_duration"):
		return resource.get_duration()
	return 1.0

# 同步到资源的当前时长
func sync_to_resource_duration() -> void:
	"""
	同步到资源的当前时长
	将Track的duration设置为资源提供的时长
	"""
	if not resource:
		return
	
	var resource_duration = resource.get_duration()
	if resource_duration > 0:
		duration = resource_duration

# 设置手动时长
func set_manual_duration(new_duration: float) -> void:
	"""
	设置为手动时长
	
	@param new_duration: 新的时长值，必须大于0
	"""
	if new_duration <= 0:
		push_error("Manual duration must be positive")
		return
	
	duration = new_duration

# 监听资源时长变化
func _on_resource_duration_changed(new_duration: float) -> void:
	"""
	资源时长变化时的处理
	@param new_duration: 资源的新时长
	"""
	if auto_sync_duration and duration <= 0:
		# 自动同步模式下，只触发更新通知，不改变duration值
		# 通过timeline_changed信号通知编辑器刷新
		pass  # 在实际使用时，可以通过信号传递这个更新


# 检查是否应该触发
func should_trigger(time: float, context: JuicyContext) -> bool:
	"""
	检查是否应该触发子效果
	
	@param time: 当前时间
	@param context: JuicyContext实例
	@return: 是否应该触发
	"""
	# 检查基础条件
	if not enabled or muted:
		return false
	
	# 检查时间条件
	var end_time = start_time + get_actual_duration()
	if time < start_time or time >= end_time:
		# 超出范围，重置进入标志（为下次进入做准备）
		_has_entered_range = false
		return false
	
	# 检查是否已经进入过时间范围（防止每帧重复触发）
	if _has_entered_range:
		return false
	
	# 首次进入范围，设置标志
	_has_entered_range = true
	
	# 检查是否已经触发过
	if not interrupt_on_restart and _active_context_id != "":
		return false
	
	# 检查触发条件
	if condition and not condition.evaluate(context):
		return false
	
	return true

# 触发子效果
func trigger_sub_effect(context: JuicyContext) -> String:
	"""
	触发子效果
	
	@param context: JuicyContext实例
	@return: 子效果的上下文ID
	"""
	var target_node = get_target_node()
	return trigger_sub_effect_with_target(target_node, context)

# 使用指定目标节点触发子效果
func trigger_sub_effect_with_target(target_node: Node, context: JuicyContext) -> String:
	"""
	使用指定目标节点触发子效果
	
	@param target_node: 目标节点
	@param context: JuicyContext实例
	@return: 子效果的上下文ID
	"""
	# 如果已有活跃的子效果且需要中断
	if _active_context_id != "" and interrupt_on_restart:
		JuicyMixer.stop(_active_context_id)
		_active_context_id = ""
	
	# 创建子效果上下文
	var sub_context = JuicyContext.create(resource, target_node, context.owner)
	
	# 继承时间缩放
	if inherit_time_scale:
		sub_context.time_scale = context.time_scale
	
	# 应用时间缩放曲线
	if time_scale_curve:
		var progress = (context.current_time - start_time) / get_actual_duration()
		var scale = time_scale_curve.sample(clampf(progress, 0.0, 1.0))
		sub_context.time_scale *= scale
	
	# 设置参数映射到子效果上下文
	if use_parameter_mapping:
		setup_parameter_mappings(context, sub_context.context_id)
	
	# 播放子效果
	var context_id = JuicyMixer.play(resource, target_node, context.owner)
	
	# 记录活跃的上下文ID
	_active_context_id = context_id
	_last_trigger_time = context.current_time
	_trigger_count += 1
	
	return context_id

# 停止子效果
func stop_sub_effect() -> void:
	"""
	停止当前活跃的子效果
	"""
	if _active_context_id != "":
		JuicyMixer.stop(_active_context_id)
		_active_context_id = ""

# 暂停子效果
func pause_sub_effect() -> void:
	"""
	暂停当前活跃的子效果
	"""
	if _active_context_id != "":
		JuicyMixer.pause(_active_context_id)

# 恢复子效果
func resume_sub_effect() -> void:
	"""
	恢复当前活跃的子效果
	"""
	if _active_context_id != "":
		JuicyMixer.resume(_active_context_id)

# 更新子效果参数
func update_sub_effect_parameters(context: JuicyContext, progress: float) -> void:
	"""
	根据时间进度动态更新子效果参数
	
	@param context: Timeline的上下文
	@param progress: 时间进度 (0.0-1.0)
	"""
	if _active_context_id == "":
		return
	
	var sub_context = JuicyMixer.get_context(_active_context_id)
	if not sub_context:
		return
	
	# 应用时间缩放曲线
	if time_scale_curve:
		var scale = time_scale_curve.sample(clampf(progress, 0.0, 1.0))
		sub_context.time_scale = scale
	
	# 应用参数映射到子效果
	if use_parameter_mapping:
		apply_parameter_mappings_to_sub_effect(context, _active_context_id)

# 设置参数映射到子效果上下文
func setup_parameter_mappings(context: JuicyContext, sub_context_id: String) -> void:
	"""
	将轨道的参数映射设置到子效果的上下文中
	允许Timeline级别的参数直接控制子效果的属性
	
	@param context: Timeline的上下文
	@param sub_context_id: 子效果的上下文ID
	"""
	if not use_parameter_mapping:
		return
		
	var sub_context = JuicyMixer.get_context(sub_context_id)
	if not sub_context:
		return
	
	# 为每个参数映射创建目标并添加到子上下文
	for mapping in parameter_mappings:
		if not mapping.enabled:
			continue
		
		# 根据映射类型设置不同的参数映射
		match mapping.mapping_type:
			JuicyParameterMapping.MappingType.COMPOSITE_RESOURCE:
				# 传统组合资源映射
				sub_context.add_parameter_mapping(
					mapping.input_parameter,
					"",  # 子效果内部处理，不需要指定上下文ID
					mapping.target_property,
					mapping.curve
				)
			
			JuicyParameterMapping.MappingType.TRACK_PROPERTY, JuicyParameterMapping.MappingType.TRACK_VALUE:
				# 轨道级属性映射
				sub_context.add_parameter_mapping(
					mapping.input_parameter,
					"",  # 子效果内部处理
					mapping.target_property,
					mapping.curve
				)
			
			JuicyParameterMapping.MappingType.CUSTOM:
				# 自定义映射，直接在轨道中处理，不需要传递到子上下文
				pass

# 应用参数映射到子效果
func apply_parameter_mappings_to_sub_effect(context: JuicyContext, sub_context_id: String) -> void:
	"""
	将Timeline上下文中的参数值应用到子效果
	
	@param context: Timeline的上下文
	@param sub_context_id: 子效果的上下文ID
	"""
	if not use_parameter_mapping:
		return
		
	var sub_context = JuicyMixer.get_context(sub_context_id)
	if not sub_context:
		return
	
	# 获取子效果的PropertyBuffer
	var property_buffer = sub_context.get_property_buffer() if sub_context.has_method("get_property_buffer") else null
	if not property_buffer:
		return
	
	# 应用所有参数映射
	for mapping in parameter_mappings:
		if not mapping.enabled:
			continue
		
		# 根据映射类型处理
		match mapping.mapping_type:
			JuicyParameterMapping.MappingType.COMPOSITE_RESOURCE:
				# 传统组合资源映射
				_apply_composite_resource_mapping(context, sub_context, property_buffer, mapping)
			
			JuicyParameterMapping.MappingType.TRACK_PROPERTY, JuicyParameterMapping.MappingType.TRACK_VALUE:
				# 轨道级属性映射
				_apply_track_property_mapping(context, sub_context, property_buffer, mapping)
			
			JuicyParameterMapping.MappingType.CUSTOM:
				# 自定义映射
				_apply_custom_mapping(context, sub_context, property_buffer, mapping)

# 应用组合资源映射
func _apply_composite_resource_mapping(context: JuicyContext, sub_context: JuicyContext, property_buffer: Object, mapping: JuicyParameterMapping) -> void:
	"""应用组合资源映射"""
	# 从Timeline上下文获取参数值
	var param_value = context.get_parameter(mapping.input_parameter, 1.0)
	
	# 应用映射曲线
	var mapped_value = mapping.apply_mapping(param_value)
	
	# 通过PropertyBuffer设置属性
	if property_buffer and property_buffer.has_method("add_middleware_sample"):
		property_buffer.add_middleware_sample(
			sub_context.target,
			mapping.target_property,
			mapped_value,
			JuicyPropertyBuffer.BlendMode.OVERRIDE_BASE,
			"timeline_feedback_track",
			100  # 高优先级确保参数映射生效
		)

# 应用轨道属性映射
func _apply_track_property_mapping(context: JuicyContext, sub_context: JuicyContext, property_buffer: Object, mapping: JuicyParameterMapping) -> void:
	"""应用轨道属性映射"""
	# 从Timeline上下文获取参数值
	var param_value = context.get_parameter(mapping.input_parameter, 1.0)
	
	# 应用映射
	var mapped_value = mapping.apply_mapping(param_value)
	
	# 根据目标属性应用不同的处理
	match mapping.target_property:
		"intensity", "volume", "pitch":
			# 直接属性映射
			if property_buffer and property_buffer.has_method("add_middleware_sample"):
				property_buffer.add_middleware_sample(
					sub_context.target,
					mapping.target_property,
					mapped_value,
					JuicyPropertyBuffer.BlendMode.OVERRIDE_BASE,
					"timeline_feedback_track",
					100
				)
		"time_scale":
			# 时间缩放映射
			sub_context.time_scale *= mapped_value
		"position":
			# 位置映射（需要特殊处理）
			if property_buffer and property_buffer.has_method("add_middleware_sample"):
				property_buffer.add_middleware_sample(
					sub_context.target,
					"position",
					mapped_value,
					JuicyPropertyBuffer.BlendMode.OVERRIDE_BASE,
					"timeline_feedback_track",
					100
				)

# 应用自定义映射
func _apply_custom_mapping(context: JuicyContext, sub_context: JuicyContext, property_buffer: Object, mapping: JuicyParameterMapping) -> void:
	"""应用自定义映射"""
	# 从Timeline上下文获取参数值
	var param_value = context.get_parameter(mapping.input_parameter, 1.0)
	
	# 应用自定义映射
	var mapped_value = mapping.apply_custom_mapping(param_value, self)
	
	# 通过PropertyBuffer设置属性
	if property_buffer and property_buffer.has_method("add_middleware_sample"):
		property_buffer.add_middleware_sample(
			sub_context.target,
			mapping.target_property,
			mapped_value,
			JuicyPropertyBuffer.BlendMode.OVERRIDE_BASE,
			"timeline_feedback_track",
			100
		)

# 获取轨道的开始时间
func get_start_time() -> float:
	return start_time

# 获取轨道的结束时间
func get_end_time() -> float:
	return start_time + get_actual_duration()

# 获取时长来源类型
func get_duration_source() -> int:
	"""
	获取当前轨道的时长来源类型
	
	@return: JuicyFeedbackResource.DurationSource 枚举值
	"""
	# 如果手动设置了具体时长
	if duration > 0:
		return JuicyFeedbackResource.DurationSource.MANUAL
	
	# 否则使用资源的时长类型
	if resource and resource.has_method("get_duration_source"):
		return resource.get_duration_source()
	
	# 默认返回精确时长
	return JuicyFeedbackResource.DurationSource.EXACT

# 检查是否跟随资源时长
func is_using_resource_duration() -> bool:
	"""
	检查当前是否使用资源的时长（即 duration = -1）
	
	@return: 如果使用资源时长返回 true，否则返回 false
	"""
	return duration <= 0

# 重置为资源时长
func reset_to_resource_duration() -> void:
	"""
	重置为使用资源的时长（设置 duration = -1）
	"""
	duration = -1.0
	# 注意：timeline_changed信号由编辑器监听，这里不直接发射
	# 编辑器需要监听resource的duration_changed信号

# 检查时长是否为估算类型
func is_duration_estimated() -> bool:
	"""
	检查当前时长是否为估算类型
	
	@return: 如果是估算时长返回 true，否则返回 false
	"""
	var source = get_duration_source()
	return source == JuicyFeedbackResource.DurationSource.ESTIMATED

# 获取时长描述
func get_duration_description() -> String:
	"""
	获取当前时长的描述字符串
	
	@return: 描述字符串，格式为 "类型: 时长"
	"""
	var source = get_duration_source()
	var actual_duration = get_actual_duration()
	var duration_str = ""
	
	# 格式化时长字符串
	if actual_duration >= 1.0:
		duration_str = "%.2f秒" % actual_duration
	else:
		duration_str = "%.3f秒" % actual_duration
	
	# 根据来源类型返回不同描述
	match source:
		JuicyFeedbackResource.DurationSource.MANUAL:
			return "手动: " + duration_str
		JuicyFeedbackResource.DurationSource.EXACT:
			return "精确: " + duration_str
		JuicyFeedbackResource.DurationSource.ESTIMATED:
			return "估算: ~" + duration_str
		_:
			return "未知: " + duration_str

# 初始化轨道
func initialize_track(context: JuicyContext) -> void:
	super.initialize_track(context)
	_active_context_id = ""
	_last_trigger_time = -1.0
	_trigger_count = 0
	_has_entered_range = false  # 重置范围进入标志

# 清理轨道
func cleanup_track(context: JuicyContext) -> void:
	super.cleanup_track(context)
	stop_sub_effect()

# 获取轨道的编辑器图标
func get_editor_icon() -> String:
	return "AudioStream"

# 获取轨道的编辑器颜色
func get_editor_color() -> Color:
	return track_color

# 克隆轨道
func clone() -> JuicyTrack:
	var cloned_track = super.clone() as JuicyFeedbackTrack
	
	# 复制反馈轨道特有属性
	cloned_track.resource = resource
	cloned_track.start_time = start_time
	cloned_track.duration = duration
	cloned_track.auto_sync_duration = auto_sync_duration
	cloned_track.time_scale_curve = time_scale_curve
	cloned_track.target = target
	cloned_track.inherit_time_scale = inherit_time_scale
	cloned_track.interrupt_on_restart = interrupt_on_restart
	cloned_track.blend_in_time = blend_in_time
	cloned_track.blend_out_time = blend_out_time
	cloned_track.auto_start = auto_start
	cloned_track.loop_sub_effect = loop_sub_effect
	cloned_track.use_parameter_mapping = use_parameter_mapping
	
	# 复制参数映射
	cloned_track.parameter_mappings.clear()
	for mapping in parameter_mappings:
		if mapping:
			cloned_track.parameter_mappings.append(mapping.duplicate(true))
	
	return cloned_track

# 序列化支持
func get_config_dict() -> Dictionary:
	var config = super.get_config_dict()
	
	# 添加反馈轨道特有配置
	config["start_time"] = start_time
	config["duration"] = duration
	config["auto_sync_duration"] = auto_sync_duration
	config["target"] = target
	config["inherit_time_scale"] = inherit_time_scale
	config["interrupt_on_restart"] = interrupt_on_restart
	config["blend_in_time"] = blend_in_time
	config["blend_out_time"] = blend_out_time
	config["auto_start"] = auto_start
	config["loop_sub_effect"] = loop_sub_effect
	config["use_parameter_mapping"] = use_parameter_mapping
	
	# 保存资源路径
	if resource:
		config["resource_path"] = resource.resource_path
	
	return config

# 从配置字典加载
func load_from_dict(config_dict: Dictionary) -> bool:
	if not super.load_from_dict(config_dict):
		return false
	
	# 加载反馈轨道特有配置
	if config_dict.has("start_time"):
		start_time = config_dict["start_time"]
	if config_dict.has("duration"):
		duration = config_dict["duration"]
	if config_dict.has("target"):
		target = config_dict["target"]
	if config_dict.has("inherit_time_scale"):
		inherit_time_scale = config_dict["inherit_time_scale"]
	if config_dict.has("interrupt_on_restart"):
		interrupt_on_restart = config_dict["interrupt_on_restart"]
	if config_dict.has("blend_in_time"):
		blend_in_time = config_dict["blend_in_time"]
	if config_dict.has("blend_out_time"):
		blend_out_time = config_dict["blend_out_time"]
	if config_dict.has("auto_start"):
		auto_start = config_dict["auto_start"]
	if config_dict.has("loop_sub_effect"):
		loop_sub_effect = config_dict["loop_sub_effect"]
	if config_dict.has("use_parameter_mapping"):
		use_parameter_mapping = config_dict["use_parameter_mapping"]
	if config_dict.has("auto_sync_duration"):
		auto_sync_duration = config_dict["auto_sync_duration"]
	
	# 注意：资源引用的实际加载需要在更高层处理
	# 这里只保存配置数据
	
	return true
