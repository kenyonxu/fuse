class_name JuicyEventScheduler
extends RefCounted

# 事件处理器存储
var _event_handlers: Dictionary = {}  # EventType -> Array[JuicyEventHandler]
var _handler_priorities: Dictionary = {}  # handler_name -> priority

# 调度状态
var _is_processing: bool = false
var _processing_queue: Array = []
var _batch_size: int = 50
var _max_processing_time: float = 16.0  # 毫秒

# 性能统计
var _total_batches_processed: int = 0
var _total_events_handled: int = 0
var _total_processing_time: float = 0.0

# 事件处理器管理
func register_handler(handler: JuicyEventHandler, priority: int = 0) -> bool:
	"""注册事件处理器"""
	if not handler or not handler.handler_name:
		push_error("Invalid event handler")
		return false
	
	# 检查是否已注册
	if _handler_priorities.has(handler.handler_name):
		push_warning("Handler '" + handler.handler_name + "' already registered, updating priority")
	
	# 注册处理器
	for event_type in handler.supported_events:
		if not _event_handlers.has(event_type):
			_event_handlers[event_type] = []
		
		# 检查是否已存在
		var existing_index = -1
		for i in range(_event_handlers[event_type].size()):
			if _event_handlers[event_type][i].handler_name == handler.handler_name:
				existing_index = i
				break
		
		if existing_index >= 0:
			_event_handlers[event_type][existing_index] = handler
		else:
			_event_handlers[event_type].append(handler)
	
	_handler_priorities[handler.handler_name] = priority
	
	# 按优先级排序
	_sort_handlers_by_priority()
	
	print("Registered event handler: ", handler.handler_name, " for event types: ", handler.supported_events)
	return true

func unregister_handler(handler_name: String) -> bool:
	"""注销事件处理器"""
	if not _handler_priorities.has(handler_name):
		return false
	
	# 从所有事件类型中移除
	for event_type in _event_handlers.keys():
		for i in range(_event_handlers[event_type].size() - 1, -1, -1):
			if _event_handlers[event_type][i].handler_name == handler_name:
				_event_handlers[event_type].remove_at(i)
	
	_handler_priorities.erase(handler_name)
	
	print("Unregistered event handler: ", handler_name)
	return true

func get_handler(handler_name: String) -> JuicyEventHandler:
	"""获取指定处理器"""
	for event_type in _event_handlers.keys():
		for handler in _event_handlers[event_type]:
			if handler.handler_name == handler_name:
				return handler
	return null

func get_handlers_for_event(event_type: JuicyEvent.EventType) -> Array:
	"""获取处理指定事件类型的处理器"""
	var handlers = _event_handlers.get(event_type)
	if handlers == null:
		# 返回一个空的数组
		return []
	
	# 直接返回处理器数组（避免类型转换问题）
	return handlers

# 事件处理
func process_events(event_buffer: JuicyEventBuffer, delta: float) -> int:
	"""处理事件"""
	if _is_processing:
		return 0
	
	var start_time = Time.get_ticks_usec()
	_is_processing = true
	
	var processed_count = 0
	var events_processed_in_batch = 0
	
	# 获取准备处理的事件
	var ready_events = event_buffer.get_ready_events()
	
	# 分批处理事件
	while not ready_events.is_empty() and events_processed_in_batch < _batch_size:
		var batch_end_time = Time.get_ticks_usec() + (_max_processing_time * 1000)
		
		# 处理一批事件
		var batch_size = min(_batch_size, ready_events.size())
		var batch = ready_events.slice(0, batch_size)
		ready_events = ready_events.slice(batch_size)
		
		for event in batch:
			if Time.get_ticks_usec() >= batch_end_time:
				break
			
			if _process_single_event(event):
				processed_count += 1
				events_processed_in_batch += 1
		
		# 标记已处理的事件
		event_buffer.mark_events_processed(batch)
		
		_total_batches_processed += 1
	
	# 更新统计
	var processing_time = (Time.get_ticks_usec() - start_time) / 1000.0
	_total_processing_time += processing_time
	_total_events_handled += processed_count
	
	_is_processing = false
	return processed_count

func _process_single_event(event: JuicyEvent) -> bool:
	"""处理单个事件"""
	var handlers = get_handlers_for_event(event.event_type)
	
	if handlers.is_empty():
		print("EventScheduler: No handlers found for event type: " + str(event.event_type))
		return false
	
	var success_count = 0
	
	for handler in handlers:
		print("EventScheduler: Processing event with handler: " + handler.handler_name)
		var result = handler.handle_event(event)
		if result:
			success_count += 1
			print("EventScheduler: Handler succeeded: " + handler.handler_name)
		else:
			print("EventScheduler: Handler failed: " + handler.handler_name)
	
	var overall_success = success_count > 0
	print("EventScheduler: Event processing result: " + str(overall_success) + ", success count: " + str(success_count))
	return overall_success

# 内部实现
func _sort_handlers_by_priority() -> void:
	"""按优先级排序处理器"""
	for event_type in _event_handlers.keys():
		_event_handlers[event_type].sort_custom(func(a, b):
			var priority_a = _handler_priorities.get(a.handler_name, 0)
			var priority_b = _handler_priorities.get(b.handler_name, 0)
			return priority_a > priority_b
		)

# 配置管理
func set_batch_size(size: int) -> void:
	"""设置批处理大小"""
	_batch_size = max(1, size)

func set_max_processing_time(time_ms: float) -> void:
	"""设置最大处理时间"""
	_max_processing_time = max(1.0, time_ms)

# 统计和调试
func get_scheduler_stats() -> Dictionary:
	"""获取调度器统计信息"""
	return {
		"total_handlers": _handler_priorities.size(),
		"event_types_supported": _event_handlers.size(),
		"total_batches_processed": _total_batches_processed,
		"total_events_handled": _total_events_handled,
		"total_processing_time": _total_processing_time,
		"average_batch_time": _total_processing_time / max(_total_batches_processed, 1),
		"average_events_per_batch": float(_total_events_handled) / max(_total_batches_processed, 1),
		"is_processing": _is_processing
	}

func debug_print_handlers() -> void:
	"""打印处理器信息"""
	print("=== JuicyMixer Event Handlers ===")
	for event_type in _event_handlers.keys():
		print("Event Type: ", event_type)
		for handler in _event_handlers[event_type]:
			var priority = _handler_priorities.get(handler.handler_name, 0)
			print("  - ", handler.handler_name, " (priority: ", priority, ")")
