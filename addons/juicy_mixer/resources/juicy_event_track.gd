# JuicyEventTrack - 事件轨道
# 在特定时间点触发JuicyEvent
# 支持事件模板和数据覆盖

@tool
class_name JuicyEventTrack
extends JuicyTrack

# 基础配置
@export var trigger_time: float = 0.0            # 触发时间
@export var juicy_event: JuicyEventResource     # 事件配置资源

# 高级属性
@export var event_template: JuicyEventResource  # 事件模板，用于动态创建事件
@export var event_data: Dictionary = {}          # 事件数据覆盖
@export var target_path: NodePath               # 可选：指定不同的目标
@export var trigger_once: bool = true           # 是否只触发一次
@export var delay: float = 0.0                # 触发后的延迟

# 参数映射系统
@export var use_parameter_mapping: bool = false    # 参数映射开关，默认关闭
@export var parameter_mappings: Array[JuicyParameterMapping] = []

# 运行时状态
var _triggered: bool = false                    # 是否已触发
var _trigger_count: int = 0                     # 触发次数
var _pending_events: Array = []                 # 待处理的事件

func get_track_type() -> String:
	return "Event"

func validate_track() -> String:
	if not juicy_event and not event_template:
		return "Either juicy_event or event_template must be set"
	
	if trigger_time < 0.0:
		return "Trigger time cannot be negative"
	
	if delay < 0.0:
		return "Delay cannot be negative"
	
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

# 创建实际事件
func create_actual_event(base_target: Node, context: JuicyContext) -> JuicyEvent:
	"""
	创建实际事件

	@param base_target: 基础目标节点
	@param context: JuicyContext实例
	@return: 创建的事件实例
	"""
	var event_resource: JuicyEventResource
	
	if event_template:
		event_resource = event_template.duplicate(true)
	elif juicy_event:
		event_resource = juicy_event.duplicate(true)
	else:
		return null
	
	# 设置目标 - 支持编辑器和运行时环境
	var actual_target = base_target
	if not target_path.is_empty():
		if Engine.is_editor_hint():
			actual_target = _get_target_node_in_editor(base_target)
		else:
			actual_target = base_target.get_node(target_path)
	
	# 从资源创建 JuicyEvent
	var actual_event = JuicyEvent.from_resource(event_resource, actual_target)
	
	# 应用事件数据覆盖
	_apply_event_data_overrides(actual_event, context)
	
	return actual_event

# 应用事件数据覆盖
func _apply_event_data_overrides(event: JuicyEvent, context: JuicyContext) -> void:
	"""
	应用事件数据覆盖

	@param event: 事件实例
	@param context: JuicyContext实例
	"""
	# 应用静态数据覆盖
	for key in event_data:
		event.event_data[key] = event_data[key]
	
	# 应用参数映射
	if use_parameter_mapping:
		_apply_parameter_mappings(event, context)

# 应用参数映射
func _apply_parameter_mappings(event: JuicyEvent, context: JuicyContext) -> void:
	"""
	应用参数映射到事件

	@param event: 事件实例
	@param context: JuicyContext实例
	"""
	for mapping in parameter_mappings:
		if not mapping.enabled:
			continue
		
		# 根据映射类型处理
		match mapping.mapping_type:
			JuicyParameterMapping.MappingType.EVENT_PROPERTY:
				# 事件属性映射
				_apply_event_property_mapping(event, context, mapping)
			
			JuicyParameterMapping.MappingType.TRACK_PROPERTY, JuicyParameterMapping.MappingType.TRACK_VALUE:
				# 轨道属性映射
				_apply_track_property_mapping(event, context, mapping)
			
			JuicyParameterMapping.MappingType.CUSTOM:
				# 自定义映射
				_apply_custom_mapping(event, context, mapping)

# 应用事件属性映射
func _apply_event_property_mapping(event: JuicyEvent, context: JuicyContext, mapping: JuicyParameterMapping) -> void:
	"""应用事件属性映射"""
	var param_value = context.get_parameter(mapping.input_parameter, 1.0)
	var mapped_value = mapping.apply_mapping(param_value)
	
	# 根据目标属性应用映射
	match mapping.target_property:
		"volume":
			_set_event_property(event, "volume", mapped_value)
		"pitch":
			_set_event_property(event, "pitch", mapped_value)
		"position":
			_set_event_property(event, "position", mapped_value)
		"intensity":
			_set_event_property(event, "intensity", mapped_value)
		"duration":
			_set_event_property(event, "duration", mapped_value)
		_:
			# 尝试直接设置属性
			_set_event_property(event, mapping.target_property, mapped_value)

# 应用轨道属性映射
func _apply_track_property_mapping(event: JuicyEvent, context: JuicyContext, mapping: JuicyParameterMapping) -> void:
	"""应用轨道属性映射"""
	var param_value = context.get_parameter(mapping.input_parameter, 1.0)
	var mapped_value = mapping.apply_mapping(param_value)
	
	# 根据目标属性应用映射
	match mapping.target_property:
		"volume":
			_set_event_property(event, "volume", mapped_value)
		"pitch":
			_set_event_property(event, "pitch", mapped_value)
		"position":
			_set_event_property(event, "position", mapped_value)
		"intensity":
			_set_event_property(event, "intensity", mapped_value)
		_:
			# 尝试直接设置属性
			_set_event_property(event, mapping.target_property, mapped_value)

# 应用自定义映射
func _apply_custom_mapping(event: JuicyEvent, context: JuicyContext, mapping: JuicyParameterMapping) -> void:
	"""应用自定义映射"""
	var param_value = context.get_parameter(mapping.input_parameter, 1.0)
	var mapped_value = mapping.apply_custom_mapping(param_value, self)
	
	# 设置事件属性
	_set_event_property(event, mapping.target_property, mapped_value)

# 设置事件属性
func _set_event_property(event: JuicyEvent, property_name: String, value: Variant) -> void:
	"""
	设置事件属性的通用方法

	@param event: 事件实例
	@param property_name: 属性名称
	@param value: 属性值
	"""
	event.event_data[property_name] = value

# 检查是否应该触发
func should_trigger(time: float, context: JuicyContext) -> bool:
	"""
	检查是否应该触发事件
	
	@param time: 当前时间
	@param context: JuicyContext实例
	@return: 是否应该触发
	"""
	# 检查基础条件
	if not enabled or muted:
		return false
	
	# 检查触发条件
	if condition and not condition.evaluate(context):
		return false
	
	# 检查是否已经触发过
	if trigger_once and _triggered:
		return false
	
	# 检查触发时间
	if time < trigger_time:
		return false
	
	return true

# 触发事件
func trigger_event(base_target: Node, context: JuicyContext) -> void:
	"""
	触发事件
	
	@param base_target: 基础目标节点
	@param context: JuicyContext实例
	"""
	var actual_event = create_actual_event(base_target, context)
	trigger_event_with_target(base_target, context, actual_event)

# 使用指定目标节点触发事件
func trigger_event_with_target(target_node: Node, context: JuicyContext, event: JuicyEvent = null) -> void:
	"""
	使用指定目标节点触发事件

	@param target_node: 目标节点
	@param context: JuicyContext实例
	@param event: 可选的事件实例，如果为null则创建新事件
	"""
	var actual_event = event
	if not actual_event:
		actual_event = create_actual_event(target_node, context)
	
	if not actual_event:
		return
	
	# 如果有延迟，创建延迟事件
	if delay > 0.0:
		_schedule_delayed_event(actual_event, context)
	else:
		# 立即触发
		_fire_event(actual_event, context)
	
	# 更新状态
	_triggered = true
	_trigger_count += 1

# 调度延迟事件
func _schedule_delayed_event(event: JuicyEvent, context: JuicyContext) -> void:
	"""
	调度延迟事件

	@param event: 事件实例
	@param context: JuicyContext实例
	"""
	var event_data = {
		"event": event,
		"trigger_time": context.current_time + delay,
		"context_id": context.context_id
	}
	
	_pending_events.append(event_data)

# 触发事件
func _fire_event(event: JuicyEvent, context: JuicyContext) -> void:
	"""
	触发事件

	@param event: 事件实例
	@param context: JuicyContext实例
	"""
	event.context_id = context.context_id
	context.add_event(event)

# 处理待处理的事件
func process_pending_events(context: JuicyContext) -> void:
	"""
	处理待处理的延迟事件
	
	@param context: JuicyContext实例
	"""
	var events_to_remove = []
	
	for i in range(_pending_events.size()):
		var event_data = _pending_events[i]
		
		# 检查是否到了触发时间
		if context.current_time >= event_data.trigger_time:
			_fire_event(event_data.event, context)
			events_to_remove.append(i)
	
	# 移除已触发的事件
	for i in range(events_to_remove.size() - 1, -1, -1):
		_pending_events.remove_at(events_to_remove[i])

# 获取轨道的开始时间
func get_start_time() -> float:
	return trigger_time

# 获取轨道的结束时间
func get_end_time() -> float:
	return trigger_time

# 初始化轨道
func initialize_track(context: JuicyContext) -> void:
	super.initialize_track(context)
	_triggered = false
	_trigger_count = 0
	_pending_events.clear()

# 清理轨道
func cleanup_track(context: JuicyContext) -> void:
	super.cleanup_track(context)
	_pending_events.clear()

# 获取轨道的编辑器图标
func get_editor_icon() -> String:
	return "Signals"

# 获取轨道的编辑器颜色
func get_editor_color() -> Color:
	return track_color

# 克隆轨道
func clone() -> JuicyTrack:
	var cloned_track = super.clone() as JuicyEventTrack
	
	# 复制事件轨道特有属性
	cloned_track.trigger_time = trigger_time
	cloned_track.juicy_event = juicy_event
	cloned_track.event_template = event_template
	cloned_track.event_data = event_data.duplicate()
	cloned_track.target_path = target_path
	cloned_track.trigger_once = trigger_once
	cloned_track.delay = delay
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
	
	# 添加事件轨道特有配置
	config["trigger_time"] = trigger_time
	config["event_data"] = event_data
	config["target_path"] = target_path
	config["trigger_once"] = trigger_once
	config["delay"] = delay
	config["use_parameter_mapping"] = use_parameter_mapping
	
	# 保存事件配置（序列化为字典）
	if juicy_event:
		config["juicy_event_config"] = {
			"event_type": juicy_event.event_type,
			"event_id": juicy_event.event_id,
			"event_name": juicy_event.event_name,
			"target_path": juicy_event.target_path,
			"priority": juicy_event.priority,
			"delay": juicy_event.delay,
			"event_data": juicy_event.event_data
		}
	if event_template:
		config["event_template_config"] = {
			"event_type": event_template.event_type,
			"event_id": event_template.event_id,
			"event_name": event_template.event_name,
			"target_path": event_template.target_path,
			"priority": event_template.priority,
			"delay": event_template.delay,
			"event_data": event_template.event_data
		}
	
	return config

# 从配置字典加载
func load_from_dict(config_dict: Dictionary) -> bool:
	if not super.load_from_dict(config_dict):
		return false
	
	# 加载事件轨道特有配置
	if config_dict.has("trigger_time"):
		trigger_time = config_dict["trigger_time"]
	if config_dict.has("event_data"):
		event_data = config_dict["event_data"]
	if config_dict.has("target_path"):
		target_path = config_dict["target_path"]
	if config_dict.has("trigger_once"):
		trigger_once = config_dict["trigger_once"]
	if config_dict.has("delay"):
		delay = config_dict["delay"]
	if config_dict.has("use_parameter_mapping"):
		use_parameter_mapping = config_dict["use_parameter_mapping"]
	
	# 加载事件配置
	if config_dict.has("juicy_event_config"):
		var event_config = config_dict["juicy_event_config"]
		juicy_event = JuicyEventResource.new()
		juicy_event.event_type = event_config.get("event_type", 0)
		juicy_event.event_id = event_config.get("event_id", "")
		juicy_event.event_name = event_config.get("event_name", "")
		juicy_event.target_path = event_config.get("target_path", NodePath(""))
		juicy_event.priority = event_config.get("priority", 0)
		juicy_event.delay = event_config.get("delay", 0.0)
		juicy_event.event_data = event_config.get("event_data", {})
	
	if config_dict.has("event_template_config"):
		var template_config = config_dict["event_template_config"]
		event_template = JuicyEventResource.new()
		event_template.event_type = template_config.get("event_type", 0)
		event_template.event_id = template_config.get("event_id", "")
		event_template.event_name = template_config.get("event_name", "")
		event_template.target_path = template_config.get("target_path", NodePath(""))
		event_template.priority = template_config.get("priority", 0)
		event_template.delay = template_config.get("delay", 0.0)
		event_template.event_data = template_config.get("event_data", {})
	
	return true