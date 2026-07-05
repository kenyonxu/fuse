# JuicyContext - 数据载体
# 作为强类型的运行时数据容器，替代V2中的字典传递机制
# 管理效果的生命周期状态，提供类型安全的数据访问方法
# 支持事件系统集成，提供向后兼容的事件API

class_name JuicyContext
extends RefCounted

## Context 类型枚举
##
## 用于区分不同类型的 Context，使验证逻辑更清晰
enum ContextType {
	FEEDBACK,  # Feedback Resource 的 Context（需要 resource）
	EVENT,    # 事件的 Context（resource 为 null，需要 events）
	# 未来可扩展：
	# SEQUENCE,  # 序列动画的 Context
	# TIMELINE,  # 时间线控制的 Context
}

# 生命周期信号
signal execute_complete(context_id)

# Context 类型标识（类型安全的设计）
var context_type: ContextType = ContextType.FEEDBACK

# 静态数据引用（不可变）
var resource: JuicyFeedbackResource
var target: Node
var owner: Node

# 运行时状态（可变）
var progress: float = 0.0
var time_scale: float = 1.0
var is_active: bool = false
var is_paused: bool = false
var is_completed: bool = false
var start_time: float = 0.0
var current_time: float = 0.0
var duration: float = 0.0

# 驱动器数据缓存
var driver_cache: Dictionary = {}
var property_cache: Dictionary = {}

# 中间件专用数据存储区域
var middleware_data: Dictionary = {}  # middleware_name: { data_dict }
var middleware_property_overrides: Dictionary = {}  # property: { middleware_name: value }

# 生命周期管理
var context_id: String = ""
var creation_time: float = 0.0
var last_update_time: float = 0.0

# 序列化系统支持
var item_index: int = -1  # 序列项索引（用于并行执行跟踪）

# 事件系统支持（可选功能）
var _events: Array = []  # 存储与此Context关联的事件

# 动态参数存储（联觉系统支持）
var _dynamic_parameters: Dictionary = {}  # 参数名 -> 参数值

# 参数映射配置（由Driver从Resource设置）
var _parameter_mappings: Dictionary = {}  # parameter_name -> Array[MappingTarget]

# =============================================================================
# 内部类定义
# =============================================================================

# 映射目标定义 - 用于参数映射系统
class MappingTarget:
	var context_id: String          # 目标子上下文ID
	var property_path: String       # 属性路径（如"amplitude", "volume_db"）
	var curve: Curve              # 映射曲线
	var enabled: bool = true        # 是否启用此映射目标

	func _init(p_context_id: String = "", p_property_path: String = "", p_curve: Curve = null):
		context_id = p_context_id
		property_path = p_property_path
		curve = p_curve
		enabled = true

	func is_valid() -> bool:
		"""检查映射目标是否有效"""
		return not context_id.is_empty() and not property_path.is_empty() and enabled

# 静态工厂方法
static func create(resource: JuicyFeedbackResource, target: Node, owner: Node = null) -> JuicyContext:
	var context = JuicyContext.new()
	context.resource = resource
	context.target = target
	context.owner = owner if owner else target
	context.context_id = _generate_unique_id()
	context.creation_time = Time.get_ticks_msec() / 1000.0
	context.duration = resource.get_duration()
	context.context_type = ContextType.FEEDBACK  # 标记为 Feedback 类型
	return context

## 创建专用于事件的 Context
##
## 与 create() 不同，此方法不依赖 Resource，适用于纯事件流程
##
## @param target: 目标节点
## @param owner: 拥有者节点（可选）
## @return: JuicyContext 实例，resource 为 null，duration 为 0
static func create_for_event(target: Node, owner: Node = null) -> JuicyContext:
	var context = JuicyContext.new()
	context.resource = null  # 事件不需要 resource
	context.target = target
	context.owner = owner if owner else target
	context.context_id = _generate_unique_id()
	context.creation_time = Time.get_ticks_msec() / 1000.0
	context.duration = 0.0  # 事件立即处理，不需要持续时间
	context.context_type = ContextType.EVENT  # 标记为 Event 类型
	return context

# 强类型访问方法
func get_driver_data(driver_type: String) -> Variant:
	return driver_cache.get(driver_type, null)

func set_driver_data(driver_type: String, data: Variant) -> void:
	driver_cache[driver_type] = data

func get_property_override(property: String, default: Variant) -> Variant:
	return property_cache.get(property, default)

func set_property_override(property: String, value: Variant) -> void:
	property_cache[property] = value

# 中间件数据访问方法
func get_middleware_data(middleware_name: String, key: String, default: Variant = null) -> Variant:
	if not middleware_data.has(middleware_name):
		return default
	return middleware_data[middleware_name].get(key, default)

func set_middleware_data(middleware_name: String, key: String, value: Variant) -> void:
	if not middleware_data.has(middleware_name):
		middleware_data[middleware_name] = {}
	middleware_data[middleware_name][key] = value

func has_middleware_data(middleware_name: String) -> bool:
	return middleware_data.has(middleware_name)

func get_middleware_data_dict(middleware_name: String) -> Dictionary:
	return middleware_data.get(middleware_name, {}).duplicate()

# 中间件属性覆盖方法
func get_middleware_property_override(property: String, middleware_name: String, default: Variant = null) -> Variant:
	if not middleware_property_overrides.has(property):
		return default
	return middleware_property_overrides[property].get(middleware_name, default)

func set_middleware_property_override(property: String, middleware_name: String, value: Variant) -> void:
	if not middleware_property_overrides.has(property):
		middleware_property_overrides[property] = {}
	middleware_property_overrides[property][middleware_name] = value

func remove_middleware_property_override(property: String, middleware_name: String) -> void:
	if middleware_property_overrides.has(property):
		middleware_property_overrides[property].erase(middleware_name)
		if middleware_property_overrides[property].is_empty():
			middleware_property_overrides.erase(property)

func get_all_middleware_property_overrides(property: String) -> Dictionary:
	return middleware_property_overrides.get(property, {}).duplicate()

# 生命周期方法
func activate() -> void:
	is_active = true
	start_time = Time.get_ticks_msec() / 1000.0
	last_update_time = start_time

func update(delta: float) -> void:
	if not is_active or is_paused or is_completed:
		return
	
	last_update_time = Time.get_ticks_msec() / 1000.0
	
	# 如果start_time为负数，表示还未开始计时，不更新时间
	if start_time < 0:
		current_time = 0.0
		progress = 0.0
		return
	
	current_time = (last_update_time - start_time) * time_scale
	progress = clamp(current_time / duration, 0.0, 1.0)
	
	if progress >= 1.0:
		complete()

func pause() -> void:
	is_paused = true

func resume() -> void:
	is_paused = false

func complete() -> void:
	is_completed = true
	is_active = false
	execute_complete.emit(context_id)

func reset() -> void:
	progress = 0.0
	current_time = 0.0
	is_active = false
	is_paused = false
	is_completed = false
	driver_cache.clear()
	property_cache.clear()
	middleware_data.clear()
	middleware_property_overrides.clear()
	_events.clear()  # 清理事件数组，确保事件与Context生命周期绑定
	
	# 清理参数管理数据（联觉系统）
	_dynamic_parameters.clear()
	_parameter_mappings.clear()
	
	# 重新生成context_id，确保重置后仍然有有效的ID
	context_id = _generate_unique_id()

# 事件API方法（向后兼容设计）
func add_event(event: Variant) -> bool:
	"""安全地添加事件到Context"""
	# 检查事件系统是否可用
	if not _is_event_system_available():
		_log_debug("Event system not available, event ignored")
		return false
	
	# 验证事件对象
	if not event:
		_log_debug("Invalid event object")
		return false
	
	# 确保事件类型正确 - 检查是否为有效的事件对象
	# 由于JuicyEvent在Godot中可能被识别为RefCounted，我们使用更宽松的验证
	var event_is_valid = false
	
	# 检查事件对象是否有必需的属性和方法
	var has_event_type = event.has_method("get_event_type")
	var has_target = event.has_method("get_target")
	var has_context_id_method = event.has_method("set_context_id") or event.has_method("get_context_id")
	
	if has_event_type and has_target and has_context_id_method:
		event_is_valid = true
		_log_debug("Valid event object detected with required properties")
	elif event.has_method("is_valid"):
		# 备用检查：是否有is_valid方法
		if event.is_valid():
			event_is_valid = true
			_log_debug("Valid event detected via is_valid()")
	
	if not event_is_valid:
		_log_debug("Invalid event type - missing required properties. Has event_type: " + str(has_event_type) +
				  ", Has target: " + str(has_target) + ", Has context_id methods: " + str(has_context_id_method))
		return false
	
	# 设置事件的context_id并添加到数组
	if event.has_method("set_context_id"):
		event.set_context_id(context_id)
	elif event.has_method("set"):
		event.set("context_id", context_id)
	
	_events.append(event)
	_log_debug("Event added to context: " + str(event))
	return true

func get_events() -> Array:
	"""获取Context中的事件列表"""
	if not _is_event_system_available():
		return []
	
	return _events.duplicate()

# 事件系统可用性检查
func _is_event_system_available() -> bool:
	"""检查事件系统是否可用"""
	# 通过JuicyMixer实例检查EventHandlingMiddleware是否存在
	var juicy_mixer = JuicyMixer.instance
	if not juicy_mixer:
		return false
	
	# 检查中间件管道中是否有事件处理中间件
	var pipeline = juicy_mixer.get_middleware_pipeline()
	if not pipeline:
		return false
	
	var middlewares = pipeline.get_all_middleware()
	for middleware in middlewares:
		if middleware:
			if middleware.middleware_name == "EventHandlingMiddleware":
				return true
	
	return false

# 调试支持
func _log_debug(message: String) -> void:
	"""提供调试日志功能（仅在调试模式下输出）"""
	if OS.is_debug_build():
		print("[JuicyContext:", context_id, "] ", message)

# 公共方法
func get_context_id() -> String:
	return context_id

# =============================================================================
# 参数管理方法（联觉系统）
# =============================================================================

# 设置参数值
func set_parameter(parameter_name: String, value: float) -> void:
	"""
	设置参数值
	
	@param parameter_name: 参数名称
	@param value: 参数值
	"""
	if parameter_name.is_empty():
		_log_debug("Parameter name cannot be empty")
		return
	
	_dynamic_parameters[parameter_name] = value
	_log_debug("Parameter set: " + parameter_name + " = " + str(value))

# 获取参数值
func get_parameter(parameter_name: String, default_value: float = 0.0) -> float:
	"""
	获取参数值
	
	@param parameter_name: 参数名称
	@param default_value: 默认值（如果参数不存在）
	@return: 参数值或默认值
	"""
	if parameter_name.is_empty():
		_log_debug("Parameter name cannot be empty, returning default value")
		return default_value
	
	return _dynamic_parameters.get(parameter_name, default_value)

# 添加参数映射（由Driver调用）
func add_parameter_mapping(parameter_name: String, target_context_id: String,
						  property_path: String, curve: Curve = null) -> void:
	"""
	添加参数映射
	
	@param parameter_name: 参数名称
	@param target_context_id: 目标子上下文ID
	@param property_path: 属性路径（如"amplitude", "volume_db"）
	@param curve: 映射曲线（可选）
	"""
	if parameter_name.is_empty():
		_log_debug("Parameter name cannot be empty, mapping not added")
		return
	
	if target_context_id.is_empty():
		_log_debug("Target context ID cannot be empty, mapping not added")
		return
	
	if property_path.is_empty():
		_log_debug("Property path cannot be empty, mapping not added")
		return
	
	# 确保参数映射数组存在
	if not _parameter_mappings.has(parameter_name):
		_parameter_mappings[parameter_name] = []
	
	# 创建映射目标
	var target = MappingTarget.new(target_context_id, property_path, curve)
	
	# 添加到映射数组
	_parameter_mappings[parameter_name].append(target)
	
	_log_debug("Parameter mapping added: " + parameter_name + " -> " + target_context_id + "." + property_path)

# 清理参数映射
func clear_parameter_mappings() -> void:
	"""
	清理所有参数映射
	"""
	_parameter_mappings.clear()
	_log_debug("All parameter mappings cleared")

# 获取所有参数映射
func get_parameter_mappings() -> Dictionary:
	"""
	获取所有参数映射配置
	
	@return: 参数字典（parameter_name -> Array[MappingTarget]）
	"""
	# 返回副本以避免外部修改
	var mappings_copy = {}
	for parameter_name in _parameter_mappings:
		mappings_copy[parameter_name] = _parameter_mappings[parameter_name].duplicate()
	return mappings_copy

# 获取指定参数的所有映射目标
func get_parameter_mapping_targets(parameter_name: String) -> Array:
	"""
	获取指定参数的所有映射目标
	
	@param parameter_name: 参数名称
	@return: MappingTarget数组
	"""
	if parameter_name.is_empty():
		return []
	
	return _parameter_mappings.get(parameter_name, []).duplicate()

# 检查参数是否存在
func has_parameter(parameter_name: String) -> bool:
	"""
	检查参数是否存在
	
	@param parameter_name: 参数名称
	@return: 是否存在
	"""
	if parameter_name.is_empty():
		return false
	
	return _dynamic_parameters.has(parameter_name)

# 获取所有参数名称
func get_parameter_names() -> Array:
	"""
	获取所有参数名称
	
	@return: 参数名称数组
	"""
	return _dynamic_parameters.keys()

# 移除参数
func remove_parameter(parameter_name: String) -> void:
	"""
	移除参数
	
	@param parameter_name: 参数名称
	"""
	if parameter_name.is_empty():
		return
	
	if _dynamic_parameters.has(parameter_name):
		_dynamic_parameters.erase(parameter_name)
		_log_debug("Parameter removed: " + parameter_name)

# =============================================================================
# 私有方法
# =============================================================================

# 生成唯一ID
static func _generate_unique_id() -> String:
	return "juicy_ctx_" + str(Time.get_ticks_msec()) + "_" + str(randi() % 10000)
