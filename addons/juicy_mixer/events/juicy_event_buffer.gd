class_name JuicyEventBuffer
extends RefCounted

# 事件缓冲区
var _event_queue: Array[JuicyEvent] = []
var _delayed_events: Array[JuicyEvent] = []
var _persistent_events: Array[JuicyEvent] = []
var _max_queue_size: int = 1000
var _max_delayed_events: int = 500
var _max_persistent_events: int = 100

# 性能统计
var _total_events_processed: int = 0
var _total_processing_time: float = 0.0

# 事件管理
func add_event(event: JuicyEvent) -> bool:
	"""添加事件到缓冲区"""
	if not event:
		return false
	
	# 生成事件ID
	if event.event_id.is_empty():
		event.event_id = _generate_event_id()
	
	# 设置时间戳
	event.timestamp = Time.get_ticks_msec() / 1000.0
	
	# 验证事件
	if not _validate_event(event):
		return false
	
	# 根据延迟分类存储
	if event.delay > 0.0:
		return _add_delayed_event(event)
	elif event.is_persistent:
		return _add_persistent_event(event)
	else:
		return _add_immediate_event(event)

func remove_event(event_id: String) -> bool:
	"""移除指定事件"""
	# 从立即队列中移除
	for i in range(_event_queue.size() - 1, -1, -1):
		if _event_queue[i].event_id == event_id:
			_event_queue.remove_at(i)
			return true
	
	# 从延迟队列中移除
	for i in range(_delayed_events.size() - 1, -1, -1):
		if _delayed_events[i].event_id == event_id:
			_delayed_events.remove_at(i)
			return true
	
	# 从持久事件中移除
	for i in range(_persistent_events.size() - 1, -1, -1):
		if _persistent_events[i].event_id == event_id:
			_persistent_events.remove_at(i)
			return true
	
	return false

func remove_context_events(context_id: String) -> int:
	"""移除指定Context的所有事件"""
	var removed_count = 0
	
	# 从立即队列中移除
	for i in range(_event_queue.size() - 1, -1, -1):
		if _event_queue[i].context_id == context_id:
			_event_queue.remove_at(i)
			removed_count += 1
	
	# 从延迟队列中移除
	for i in range(_delayed_events.size() - 1, -1, -1):
		if _delayed_events[i].context_id == context_id:
			_delayed_events.remove_at(i)
			removed_count += 1
	
	# 从持久事件中移除
	for i in range(_persistent_events.size() - 1, -1, -1):
		if _persistent_events[i].context_id == context_id:
			_persistent_events.remove_at(i)
			removed_count += 1
	
	return removed_count

func get_ready_events() -> Array[JuicyEvent]:
	"""获取准备处理的事件"""
	var ready_events: Array[JuicyEvent] = []
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# 处理延迟事件
	_process_delayed_events(current_time)
	
	# 获取立即事件（按优先级排序）
	_sort_events_by_priority()
	ready_events = _event_queue.duplicate()
	
	# 添加持久事件
	ready_events.append_array(_persistent_events)
	
	return ready_events

func mark_events_processed(events: Array[JuicyEvent]) -> void:
	"""标记事件为已处理"""
	var start_time = Time.get_ticks_usec()
	
	for event in events:
		if not event.is_persistent:
			event.is_processed = true
			_event_queue.erase(event)
		else:
			event.is_processed = true
	
	_total_events_processed += events.size()
	_total_processing_time += (Time.get_ticks_usec() - start_time) / 1000.0

# 内部实现
func _generate_event_id() -> String:
	"""生成唯一事件ID"""
	return "juicy_event_" + str(Time.get_ticks_msec()) + "_" + str(randi() % 10000)

func _validate_event(event: JuicyEvent) -> bool:
	"""验证事件有效性"""
	if not event:
		return false
	
	if event.event_type < 0 or event.event_type > JuicyEvent.EventType.CUSTOM_EVENT:
		return false
	
	if event.delay < 0.0:
		return false
	
	return true

func _add_immediate_event(event: JuicyEvent) -> bool:
	"""添加立即事件"""
	print("JuicyEventBuffer: Adding immediate event: ", event.event_name, " type: ", event.event_type)
	
	if _event_queue.size() >= _max_queue_size:
		push_warning("Event queue is full, dropping oldest event")
		_event_queue.pop_front()
	
	_event_queue.append(event)
	print("JuicyEventBuffer: Event queue size after add: ", _event_queue.size())
	return true

func _add_delayed_event(event: JuicyEvent) -> bool:
	"""添加延迟事件"""
	if _delayed_events.size() >= _max_delayed_events:
		push_warning("Delayed events queue is full, dropping oldest event")
		_delayed_events.pop_front()
	
	_delayed_events.append(event)
	return true

func _add_persistent_event(event: JuicyEvent) -> bool:
	"""添加持久事件"""
	if _persistent_events.size() >= _max_persistent_events:
		push_warning("Persistent events queue is full, dropping oldest event")
		_persistent_events.pop_front()
	
	_persistent_events.append(event)
	return true

func _process_delayed_events(current_time: float) -> void:
	"""处理延迟事件"""
	var events_to_move: Array[JuicyEvent] = []
	
	for i in range(_delayed_events.size() - 1, -1, -1):
		var event = _delayed_events[i]
		# 使用传入的当前时间进行延迟处理
		if event.timestamp + event.delay <= current_time:
			events_to_move.append(event)
			_delayed_events.remove_at(i)
	
	# 将准备好的延迟事件移到立即队列
	for event in events_to_move:
		_add_immediate_event(event)

func _sort_events_by_priority() -> void:
	"""按优先级排序事件"""
	_event_queue.sort_custom(func(a, b): return a.priority > b.priority)

# 统计和调试
func get_buffer_stats() -> Dictionary:
	"""获取缓冲区统计信息"""
	return {
		"immediate_events": _event_queue.size(),
		"delayed_events": _delayed_events.size(),
		"persistent_events": _persistent_events.size(),
		"total_events_processed": _total_events_processed,
		"total_processing_time": _total_processing_time,
		"average_processing_time": _total_processing_time / max(_total_events_processed, 1)
	}

func clear_all_events() -> void:
	"""清空所有事件"""
	_event_queue.clear()
	_delayed_events.clear()
	_persistent_events.clear()

func debug_print_events() -> void:
	"""打印事件信息"""
	print("=== JuicyMixer Event Buffer ===")
	print("Immediate events: ", _event_queue.size())
	print("Delayed events: ", _delayed_events.size())
	print("Persistent events: ", _persistent_events.size())
	print("Total processed: ", _total_events_processed)