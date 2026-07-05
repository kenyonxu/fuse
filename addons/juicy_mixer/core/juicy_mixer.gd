# JuicyMixer - 全局入口
# 提供全局单例访问点，初始化和管理所有子系统
# 提供简化的API接口，处理Autoload集成

@tool
class_name JuicyMixer
extends RefCounted

# 单例实例
static var _instance: JuicyMixer
static var instance: JuicyMixer: get = _get_instance

# 核心组件
var _director: JuicyDirector  # JuicyDirector
var _context_pool: JuicyContextPool  # JuicyContextPool
var _property_buffer: JuicyPropertyBuffer  # JuicyPropertyBuffer
var _driver_registry: JuicyDriverRegistry  # JuicyDriverRegistry
var _middleware_pipeline: JuicyMiddlewarePipeline  # JuicyMiddlewarePipeline
var _pool_manager: JuicyPoolManager  # JuicyPoolManager

# 性能统计
var _performance_metrics: Dictionary = {}
var _active_contexts: Dictionary = {}  # 临时存储活跃context

# 初始化
static func _get_instance() -> JuicyMixer:
	if not _instance:
		_instance = JuicyMixer.new()
		_instance._initialize()
	return _instance

func _initialize() -> void:
	print("Initializing JuicyMixer V3...")
	
	# 创建核心组件
	_property_buffer = JuicyPropertyBuffer.new()
	_driver_registry = JuicyDriverRegistry.new()
	
	# 创建中间件管道
	_middleware_pipeline = JuicyMiddlewarePipeline.new()
	_middleware_pipeline.initialize({
		"pipeline_name": "JuicyMixerMainPipeline",
		"description": "Main middleware pipeline for JuicyMixer",
		"enable_performance_monitoring": true,
		"enable_debug_logging": false
	})

	_setup_default_middlewares()

	# 初始化池管理器
	_pool_manager = JuicyPoolManager.instance
	
	# 创建调度器
	_director = JuicyDirector.new(_property_buffer, _driver_registry, _middleware_pipeline)
	
	# 自动发现驱动器
	_driver_registry.auto_discover_drivers()
	
	# 预热池系统
	_pool_manager.warm_up_system()
	
	print("JuicyMixer V3 initialized successfully")

# 静态便捷API
static func play(resource: JuicyFeedbackResource, target: Node, owner: Node = null) -> String:
	return instance._director.play(resource, target, owner)

static func stop(context_id: String) -> bool:
	return instance._director.stop(context_id)

static func pause(context_id: String) -> bool:
	return instance._director.pause(context_id)

static func resume(context_id: String) -> bool:
	return instance._director.resume(context_id)

static func stop_all() -> void:
	var active_contexts = instance._director.get_active_contexts().keys()
	for context_id in active_contexts:
		instance._director.stop(context_id)

# 批处理API
static func play_batch(resources: Array, targets: Array) -> Array:
	var context_ids: Array = []
	
	for i in range(min(resources.size(), targets.size())):
		var context_id = play(resources[i], targets[i])
		if not context_id.is_empty():
			context_ids.append(context_id)
	
	return context_ids

# 查询API
static func get_context(context_id: String) -> Object:
	return instance._director.get_context(context_id)

static func get_director() -> JuicyDirector:
	return instance._director

static func is_context_active(context_id: String) -> bool:
	var context = get_context(context_id)
	return context != null and context.is_active

static func get_active_contexts_count() -> int:
	return instance._director.get_active_contexts_count()

# 性能监控
static func get_performance_metrics() -> Dictionary:
	return instance._performance_metrics.duplicate()

static func get_buffer_stats() -> Dictionary:
	# 这里需要调用_property_buffer的get_buffer_stats方法
	# return instance._property_buffer.get_buffer_stats()
	
	# 临时实现
	return {"total_targets": 0, "total_properties": 0, "total_samples": 0, "dirty_targets": 0}

# 中间件系统访问方法
static func get_middleware_pipeline() -> Object:
	"""
	获取中间件管道实例
	
	@return: JuicyMiddlewarePipeline，中间件管道实例
	"""
	return instance._middleware_pipeline

static func add_middleware(middleware: Object) -> bool:
	"""
	添加中间件到管道
	
	@param middleware: 要添加的中间件实例
	@return: bool，添加是否成功
	"""
	print("[DEBUG] Adding middleware: ", middleware.get_class() if middleware else "null")
	
	if not instance._middleware_pipeline:
		print("[DEBUG] Middleware pipeline is null")
		return false
	
	if not instance._middleware_pipeline.has_method("add_middleware"):
		print("[DEBUG] Pipeline doesn't have add_middleware method")
		return false
	
	var result = instance._middleware_pipeline.add_middleware(middleware)
	print("[DEBUG] Add middleware result: ", result)
	return result

static func remove_middleware(middleware_name: String) -> bool:
	"""
	从管道中移除中间件
	
	@param middleware_name: 中间件名称
	@return: bool，移除是否成功
	"""
	if not instance._middleware_pipeline or not instance._middleware_pipeline.has_method("remove_middleware"):
		return false
	return instance._middleware_pipeline.remove_middleware(middleware_name)

static func get_middleware(middleware_name: String) -> Object:
	"""
	获取指定名称的中间件
	
	@param middleware_name: 中间件名称
	@return: JuicyMiddleware，中间件实例，如果不存在则返回null
	"""
	if not instance._middleware_pipeline or not instance._middleware_pipeline.has_method("get_middleware"):
		return null
	return instance._middleware_pipeline.get_middleware(middleware_name)

static func get_all_middleware() -> Array:
	"""
	获取所有中间件实例
	
	@return: Array[JuicyMiddleware]，所有中间件实例数组
	"""
	if not instance._middleware_pipeline or not instance._middleware_pipeline.has_method("get_all_middleware"):
		return []
	return instance._middleware_pipeline.get_all_middleware()

static func enable_middleware(middleware_name: String) -> bool:
	"""
	启用指定名称的中间件
	
	@param middleware_name: 中间件名称
	@return: bool，是否成功
	"""
	if not instance._middleware_pipeline or not instance._middleware_pipeline.has_method("enable_middleware"):
		return false
	return instance._middleware_pipeline.enable_middleware(middleware_name)

static func disable_middleware(middleware_name: String) -> bool:
	"""
	禁用指定名称的中间件
	
	@param middleware_name: 中间件名称
	@return: bool，是否成功
	"""
	if not instance._middleware_pipeline or not instance._middleware_pipeline.has_method("disable_middleware"):
		return false
	return instance._middleware_pipeline.disable_middleware(middleware_name)

static func get_middleware_performance_stats() -> Dictionary:
	"""
	获取中间件性能统计信息
	
	@return: Dictionary，包含管道和中间件的性能统计
	"""
	var stats = {
		"pipeline_stats": {},
		"middleware_stats": []
	}
	
	if instance._middleware_pipeline and instance._middleware_pipeline.has_method("get_performance_stats"):
		stats.pipeline_stats = instance._middleware_pipeline.get_performance_stats()
	
	if instance._middleware_pipeline and instance._middleware_pipeline.has_method("get_middleware_performance_stats"):
		stats.middleware_stats = instance._middleware_pipeline.get_middleware_performance_stats()
	
	return stats

static func get_registry_stats() -> Dictionary:
	# 这里需要调用_driver_registry的get_registry_stats方法
	# return instance._driver_registry.get_registry_stats()
	
	# 临时实现
	return {"total_drivers": 0, "active_drivers": 0, "mapped_properties": 0, "total_property_mappings": 0}

# 调试功能
static func debug_print_active_contexts() -> void:
	print("=== JuicyMixer Active Contexts ===")
	print("Total: ", get_active_contexts_count())
	
	# 这里需要调用_director的get_active_contexts方法
	# for context_id in instance._director.get_active_contexts().keys():
	#     var context = get_context(context_id)
	#     if context:
	#         print("- ", context_id, ": ", context.resource.get_resource_type(), 
	#               " (", context.progress * 100, "%)")

# 事件API支持
## 播放事件（使用与 Feedback 相同的完整流程）
##
## 通过 Director 和 MiddlewarePipeline 处理事件，确保架构一致性
##
## @param event: JuicyEvent事件对象
## @param target: 目标节点
## @param owner: 拥有者节点（可选）
## @return: String，context_id，失败返回空字符串
static func play_event(event: JuicyEvent, target: Node, owner: Node = null) -> String:
	if not _has_event_middleware():
		_log_warning("Event system not enabled, use play() instead")
		return ""

	# 验证事件对象
	if not event:
		_log_warning("Invalid event object")
		return ""

	# 创建事件专用的 Context
	var context = JuicyContext.create_for_event(target, owner)

	# 添加事件到 Context
	if not context.add_event(event):
		push_error("[JuicyMixer] Failed to add event to context")
		return ""

	# 通过 Director 处理事件（使用与 Feedback 相同的完整流程）
	return instance._director.play_event(context)

static func add_event_to_context(context_id: String, event: Object) -> bool:
	"""
	向指定上下文添加事件（需要事件系统支持）
	
	@param context_id: 上下文ID
	@param event: JuicyEvent事件对象
	@return: bool，是否成功添加
	"""
	if not _has_event_middleware():
		_log_warning("Event system not enabled")
		return false
	
	var context = get_context(context_id)
	if not context:
		_log_warning("Context not found: " + context_id)
		return false
	
	# 检查Context是否有add_event方法
	if not context.has_method("add_event"):
		_log_warning("Context does not support events")
		return false
	
	return context.add_event(event)

# 事件中间件检测
static func _has_event_middleware() -> bool:
	"""检查是否注册了事件处理中间件"""
	var pipeline = instance.get_middleware_pipeline()
	if not pipeline:
		return false

	# 检查中间件管道是否有get_all_middleware方法
	if not pipeline.has_method("get_all_middleware"):
		return false

	# 获取所有中间件并检查是否有EventHandlingMiddleware
	var middleware_list = pipeline.get_all_middleware()
	for middleware in middleware_list:
		# 使用 'is' 关键字检查类型，更可靠
		if middleware is EventHandlingMiddleware:
			return true

	return false

# 调试支持
static func _log_warning(message: String) -> void:
	"""提供警告日志功能"""
	push_warning("[JuicyMixer] " + message)

# 池化系统API
static func get_pool_manager() -> JuicyPoolManager:
	"""
	获取池管理器实例
	
	@return: JuicyPoolManager，池管理器实例
	"""
	return instance._pool_manager

static func get_pool_statistics() -> Dictionary:
	"""
	获取所有池的统计信息
	
	@return: Dictionary，包含所有池的统计信息
	"""
	return instance._pool_manager.get_all_pool_statistics()

static func get_pool_efficiency_score() -> float:
	"""
	获取全局池效率评分
	
	@return: float，效率评分（0.0-1.0）
	"""
	return instance._pool_manager.get_global_efficiency_score()

static func warm_up_pools() -> void:
	"""
	预热所有池
	"""
	instance._pool_manager.warm_up_system()

static func clear_all_pools() -> void:
	"""
	清空所有池
	"""
	instance._pool_manager.clear_all_pools()

# 清理
static func cleanup() -> void:
	if _instance:
		stop_all()
		# 清理池系统
		if _instance._pool_manager:
			_instance._pool_manager.clear_all_pools()
		_instance = null

# 中断系统API
static func get_interruption_state(target: Node) -> Object:
	"""
	获取目标的中断状态
	
	@param target: 目标节点
	@return: InterruptionState，中断状态，如果不存在则返回null
	"""
	var interruption_middleware = get_middleware("InterruptionMiddleware")
	if interruption_middleware and interruption_middleware.has_method("get_interruption_state"):
		return interruption_middleware.get_interruption_state(target)
	return null

static func set_channel_interruption_config(channel: String, config: ChannelInterruptionConfig) -> bool:
	"""
	设置通道中断配置
	
	@param channel: 通道名称
	@param config: 通道中断配置
	@return: bool，设置是否成功
	"""
	var interruption_middleware = get_middleware("InterruptionMiddleware")
	if interruption_middleware and interruption_middleware.has_method("set_channel_config"):
		interruption_middleware.set_channel_config(channel, config)
		return true
	return false

static func get_channel_interruption_config(channel: String) -> ChannelInterruptionConfig:
	"""
	获取通道中断配置
	
	@param channel: 通道名称
	@return: ChannelInterruptionConfig，通道配置，如果不存在则返回null
	"""
	var interruption_middleware = get_middleware("InterruptionMiddleware")
	if interruption_middleware and interruption_middleware.has_method("_get_channel_config"):
		return interruption_middleware._get_channel_config(channel)
	return null

static func set_global_interruption_policy(policy: JuicyMixerEnums.InterruptionPolicy) -> bool:
	"""
	设置全局中断策略
	
	@param policy: 中断策略
	@return: bool，设置是否成功
	"""
	var interruption_middleware = get_middleware("InterruptionMiddleware")
	if interruption_middleware and interruption_middleware.has_method("set_default_policy"):
		interruption_middleware.set_default_policy(policy)
		return true
	return false

static func get_interruption_history(target: Node, max_entries: int = 100) -> Array:
	"""
	获取目标的中断历史
	
	@param target: 目标节点
	@param max_entries: 最大历史记录数
	@return: Array，中断历史记录数组
	"""
	var interruption_state = get_interruption_state(target)
	if interruption_state and interruption_state.has_method("get_interruption_history"):
		var history = interruption_state.get_interruption_history()
		if history.size() > max_entries:
			return history.slice(history.size() - max_entries, history.size())
		return history
	return []

static func clear_interruption_history(target: Node) -> bool:
	"""
	清除目标的中断历史
	
	@param target: 目标节点
	@return: bool，清除是否成功
	"""
	var interruption_state = get_interruption_state(target)
	if interruption_state and interruption_state.has_method("clear_interruption_history"):
		interruption_state.clear_interruption_history()
		return true
	return false

static func get_interruption_stats() -> Dictionary:
	"""
	获取中断系统统计信息
	
	@return: Dictionary，包含中断系统的统计信息
	"""
	var interruption_middleware = get_middleware("InterruptionMiddleware")
	if interruption_middleware and interruption_middleware.has_method("get_interruption_stats"):
		return interruption_middleware.get_interruption_stats()
	return {}

static func set_resource_interruption_priority(resource_type: String, priority: int) -> bool:
	"""
	设置资源类型的中断优先级
	
	@param resource_type: 资源类型名称
	@param priority: 优先级数值
	@return: bool，设置是否成功
	"""
	var interruption_middleware = get_middleware("InterruptionMiddleware")
	if interruption_middleware and interruption_middleware.has_method("set_global_priority"):
		interruption_middleware.set_global_priority(resource_type, priority)
		return true
	return false

static func replay_interruption_history(target: Node, from_timestamp: float = 0.0) -> bool:
	"""
	回放中断历史
	
	@param target: 目标节点
	@param from_timestamp: 开始时间戳
	@return: bool，回放是否成功
	"""
	var interruption_middleware = get_middleware("InterruptionMiddleware")
	if interruption_middleware and interruption_middleware.has_method("replay_interruption_history"):
		interruption_middleware.replay_interruption_history(target.get_instance_id(), from_timestamp)
		return true
	return false

# 事件系统API
static func get_event_buffer_stats() -> Dictionary:
	"""
	获取事件缓冲区统计信息
	
	@return: Dictionary，事件缓冲区统计
	"""
	# 这里需要访问事件缓冲区，可能需要通过事件中间件
	var event_middleware = get_middleware("EventHandlingMiddleware")
	if event_middleware and event_middleware.has_method("get_event_buffer_stats"):
		return event_middleware.get_event_buffer_stats()
	return {}

## 添加事件到事件系统（已废弃）
##
## @deprecated 请使用 play_event() 代替，以获得完整的中介件管道处理
## 此方法绕过了 Director 和 MiddlewarePipeline，可能导致事件不被处理
##
## @param event: JuicyEvent事件对象
## @return: bool，添加是否成功
static func add_event(event: JuicyEvent) -> bool:
	push_warning("[JuicyMixer] add_event() is deprecated, use play_event() instead")
	var event_middleware = get_middleware("EventHandlingMiddleware")
	if event_middleware and event_middleware.has_method("add_event"):
		return event_middleware.add_event(event)
	return false

static func remove_event(event_id: String) -> bool:
	"""
	从事件系统中移除事件
	
	@param event_id: 事件ID
	@return: bool，移除是否成功
	"""
	var event_middleware = get_middleware("EventHandlingMiddleware")
	if event_middleware and event_middleware.has_method("remove_event"):
		return event_middleware.remove_event(event_id)
	return false

static func process_events(delta: float) -> int:
	"""
	处理事件
	
	@param delta: 时间增量
	@return: int，处理的事件数量
	"""
	var event_middleware = get_middleware("EventHandlingMiddleware")
	if event_middleware and event_middleware.has_method("process_events"):
		return event_middleware.process_events(delta)
	return 0

func _setup_default_middlewares() -> void:
	var validatior = ValidationMiddleware.new()
	if add_middleware(validatior):
		print("Validation middleware added")
	else:
		print("Cannot add validation middleware, something is wrong")
	
	# 添加中断中间件
	var interruption_middleware = InterruptionMiddleware.new()
	if add_middleware(interruption_middleware):
		print("Interruption middleware added")
	else:
		print("Cannot add interruption middleware, something is wrong")
	
	# 添加通道中间件
	var channel_middleware = ChannelMiddleware.new()
	if add_middleware(channel_middleware):
		print("Channel middleware added")
	else:
		print("Cannot add channel middleware, something is wrong")

	# 添加通道中间件
	var restoration_middleware = StateRestorationMiddleware.new()
	if add_middleware(restoration_middleware):
		print("Restoration middleware added")
	else:
		print("Cannot add restoration middleware, something is wrong")

	# 添加事件处理中间件
	var event_middleware = EventHandlingMiddleware.new()
	if add_middleware(event_middleware):
		print("Event handling middleware added")
	else:
		print("Cannot add event handling middleware, something is wrong")
