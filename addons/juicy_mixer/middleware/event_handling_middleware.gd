# EventHandlingMiddleware - 可选事件处理中间件
# 作为事件系统的统一入口点，协调事件调度器与中间件管道的集成
# 实现事件系统的自动启用/禁用机制，提供向后兼容性保证

class_name EventHandlingMiddleware
extends JuicyMiddleware

# 事件系统组件
var _event_scheduler: JuicyEventScheduler = null
var _event_buffer: JuicyEventBuffer = null
var _event_system_enabled: bool = false

func _init():
	middleware_name = "EventHandlingMiddleware"
	priority = 500  # 中等优先级，在其他中间件后执行
	description = "Optional event processing and dispatching middleware"

# 中间件生命周期钩子 - 由 JuicyMiddlewarePipeline 自动调用
func on_middleware_registered() -> void:
	"""中间件注册时自动启用事件系统"""
	print("[EventHandlingMiddleware] on_middleware_registered called")
	_enable_event_system()
	_initialize_event_components()

func on_middleware_unregistered() -> void:
	"""中间件注销时自动禁用事件系统"""
	print("[EventHandlingMiddleware] on_middleware_unregistered called")
	_disable_event_system()
	_cleanup_event_components()

func process(context: JuicyContext, next: Callable) -> bool:
	"""处理事件（仅在事件系统启用时执行）"""
	var start_time = _start_execution_timer()
	
	# 只有在事件系统启用时才处理事件
	if _event_system_enabled:
		_process_context_events(context)
	
	_end_execution_timer(start_time)
	return next.call()

# 事件系统管理
func _enable_event_system() -> void:
	"""启用事件系统"""
	_event_system_enabled = true
	_log_debug("Event system enabled")

func _disable_event_system() -> void:
	"""禁用事件系统"""
	_event_system_enabled = false
	_log_debug("Event system disabled")

func _initialize_event_components() -> void:
	"""初始化事件组件"""
	if not _event_buffer:
		_event_buffer = JuicyEventBuffer.new()
	
	if not _event_scheduler:
		_event_scheduler = JuicyEventScheduler.new()
		_setup_default_handlers()

func _cleanup_event_components() -> void:
	"""清理事件组件"""
	if _event_scheduler:
		_event_scheduler.cleanup()
		_event_scheduler = null
	
	_event_buffer = null

func _process_context_events(context: JuicyContext) -> void:
	"""处理与Context关联的事件"""
	if not _event_buffer or not _event_scheduler:
		print("EventHandlingMiddleware: Event system not initialized")
		return
	
	# 获取与Context关联的事件
	var events = _get_context_events(context)
	print("EventHandlingMiddleware: Found " + str(events.size()) + " events for context")
	
	if not events.is_empty():
		# 将事件添加到缓冲区
		for event in events:
			print("EventHandlingMiddleware: Adding event to buffer: " + event.event_name)
			_event_buffer.add_event(event)
		
		# 处理事件 - 获取主循环的处理时间
		var delta = Engine.get_main_loop().root.get_process_delta_time()
		var processed_count = _event_scheduler.process_events(_event_buffer, delta)
		print("EventHandlingMiddleware: Processed " + str(processed_count) + " events")

func _get_context_events(context: JuicyContext) -> Array:
	"""获取与Context关联的事件"""
	var events: Array = []
	
	# 从Context中获取事件
	if context.has_method("get_events"):
		events = context.get_events()
	
	# 从Resource中获取事件
	if events.is_empty() and context.resource and context.resource.has_method("get_events"):
		events = context.resource.get_events()
	
	return events

func add_event(event: JuicyEvent) -> bool:
	"""直接添加事件到缓冲区（公共API）"""
	if not _event_system_enabled:
		push_warning("Event system is not enabled")
		return false
	
	if not _event_buffer:
		push_error("Event buffer not initialized")
		return false
	
	return _event_buffer.add_event(event)

func process_events_manually(delta: float) -> int:
	"""手动处理事件（用于测试和特殊场景）"""
	if not _event_system_enabled:
		return 0
	
	if not _event_scheduler or not _event_buffer:
		return 0
	
	return _event_scheduler.process_events(_event_buffer, delta)

func register_event_handler(handler: JuicyEventHandler, priority: int = 0) -> bool:
	"""注册事件处理器到调度器"""
	if not _event_scheduler:
		_log_warning("Event scheduler not initialized, cannot register handler")
		return false
	
	if not handler or not handler.handler_name:
		_log_error("Invalid event handler")
		return false
	
	return _event_scheduler.register_handler(handler, priority)

func unregister_event_handler(handler_name: String) -> bool:
	"""从调度器注销事件处理器"""
	if not _event_scheduler:
		_log_warning("Event scheduler not initialized, cannot unregister handler")
		return false
	
	return _event_scheduler.unregister_handler(handler_name)

func get_event_handler(handler_name: String) -> JuicyEventHandler:
	"""获取指定的事件处理器"""
	if not _event_scheduler:
		return null
	
	return _event_scheduler.get_handler(handler_name)

func _setup_default_handlers() -> void:
	"""设置默认事件处理器"""
	# 注意：具体的音频、粒子、UI事件处理器将在后续阶段实现
	# 这里提供注册机制，允许用户注册自定义事件处理器
	_log_debug("Default event handlers will be set up when specific handlers are implemented")

# 统计和调试
func get_event_system_stats() -> Dictionary:
	"""获取事件系统统计信息"""
	if not _event_system_enabled:
		return {"enabled": false}
	
	var stats = {
		"enabled": true,
		"buffer_stats": {},
		"scheduler_stats": {}
	}
	
	if _event_buffer:
		stats.buffer_stats = _event_buffer.get_buffer_stats()
	
	if _event_scheduler:
		stats.scheduler_stats = _event_scheduler.get_scheduler_stats()
	
	return stats

func is_event_system_enabled() -> bool:
	"""检查事件系统是否启用"""
	return _event_system_enabled

# 公共API - 用于测试和外部访问
func add_event_directly(event: JuicyEvent) -> bool:
	"""直接添加事件到缓冲区（公共API）"""
	if not _event_buffer:
		push_warning("Event buffer not initialized")
		return false
	
	return _event_buffer.add_event(event)

func process_events_now(delta: float) -> int:
	"""立即处理事件（用于测试）"""
	if not _event_scheduler or not _event_buffer:
		return 0
	
	return _event_scheduler.process_events(_event_buffer, delta)

func get_event_buffer_stats() -> Dictionary:
	"""获取缓冲区统计信息（公共API）"""
	if not _event_buffer:
		return {"error": "buffer_not_initialized"}
	
	return _event_buffer.get_buffer_stats()
