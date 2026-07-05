# 阶段4：事件驱动系统详细开发计划

## 概述

**时间范围**：第9-10周（2周）
**主要目标**：实现统一的事件系统来处理音频、粒子、UI等非属性反馈
**优先级**：高 - 扩展系统功能，支持多感官反馈

---

## 基于阶段1-3开发内容的调整和新增

### 4.0.1 与现有系统的深度集成

基于阶段1-3实现的基础设施、Driver和Middleware系统，事件系统需要进行以下调整：

**Director集成**：
- 事件调度器需要完全集成到Director的主循环中
- 修改Director的`process()`方法，在Driver处理后添加事件处理
- 确保事件系统与Context生命周期保持同步

**Middleware协调**：
- 事件系统需要通过Middleware管道进行处理
- 新增EventMiddleware，处理事件相关的验证和优化
- 确保事件处理与现有中间件系统的协调

### 4.0.2 与JuicyContext的增强集成

基于阶段1实现的Context系统，事件系统需要进行以下增强：

**事件上下文管理**：
- 扩展Context以支持事件相关的数据存储
- 实现事件ID与Context ID的关联机制
- 添加事件状态到Context的生命周期管理

**时间同步**：
- 事件系统需要与Context的时间系统完全同步
- 实现事件延迟基于Context的time_scale
- 支持事件暂停和恢复与Context状态一致

### 4.0.3 与Driver系统的协同工作

基于阶段2实现的Driver系统，事件系统需要进行以下协调：

**Driver事件生成**：
- Driver需要能够生成事件并添加到事件缓冲区
- 实现Driver到事件处理器的通信机制
- 支持Driver特定的事件类型和参数

**资源协调**：
- 事件处理器需要与Driver资源共享资源池
- 实现音频和粒子资源的统一管理
- 确保事件处理不会与Driver处理冲突

### 4.0.4 与Middleware系统的集成优化

基于阶段3实现的Middleware系统，事件系统需要进行以下优化：

**事件中间件**：
- 新增EventValidationMiddleware，验证事件的有效性
- 实现EventPriorityMiddleware，管理事件优先级
- 添加EventPerformanceMiddleware，优化事件处理性能

**管道集成**：
- 事件处理需要通过Middleware管道
- 实现事件处理的条件执行和过滤
- 支持事件处理结果的中间件后处理

### 4.0.5 性能优化和资源管理

基于阶段1-3的性能基准，事件系统需要进行以下优化：

**批处理优化**：
- 实现事件的批处理机制，减少处理开销
- 添加事件类型分组，提高处理效率
- 优化事件调度器的执行性能

**资源池化**：
- 音频播放器和粒子系统需要使用对象池
- 实现事件对象的池化管理
- 添加资源使用监控和自动清理

### 4.0.6 新增事件类型和处理器

基于阶段1-3的系统需求，需要新增以下事件类型：

**Driver事件**：
- DriverStartEvent：Driver开始执行时触发
- DriverCompleteEvent：Driver完成时触发
- DriverErrorEvent：Driver出错时触发

**Middleware事件**：
- MiddlewareProcessEvent：中间件处理事件
- MiddlewareErrorEvent：中间件错误事件
- PipelineCompleteEvent：管道完成事件

**系统事件**：
- ContextCreatedEvent：Context创建事件
- ContextDestroyedEvent：Context销毁事件
- PerformanceWarningEvent：性能警告事件

### 4.0.7 调试和监控增强

基于阶段1-3的调试系统，事件系统需要增强：

**事件可视化**：
- 实现事件流程的可视化显示
- 添加事件处理的实时监控
- 支持事件历史的回放和分析

**性能监控**：
- 集成事件处理到现有性能监控系统
- 添加事件特定的性能指标
- 实现事件处理的性能预警机制

---

## 核心组件详细设计

### 4.1 JuicyEventBuffer (事件缓冲区)

**文件路径**：`addons/juicy_mixer/events/juicy_event_buffer.gd`

**核心职责**：
- 管理事件队列和缓冲
- 提供事件的优先级排序
- 支持延迟事件处理
- 实现事件的批量处理

**详细实现计划**：

```gdscript
class_name JuicyEventBuffer
extends RefCounted

# 事件类型定义
enum EventType {
	AUDIO_PLAY,        # 音频播放
	AUDIO_STOP,        # 音频停止
	PARTICLE_SPAWN,    # 粒子生成
	PARTICLE_STOP,      # 粒子停止
	UI_UPDATE,         # UI更新
	SCREEN_SHAKE,      # 屏幕震动
	VIBRATION,         # 手柄震动
	CUSTOM_EVENT       # 自定义事件
}

# 事件数据结构
class JuicyEvent:
	var event_id: String = ""
	var event_type: EventType
	var context_id: String = ""
	var target: Node
	var event_data: Dictionary = {}
	var priority: int = 0
	var timestamp: float = 0.0
	var delay: float = 0.0
	var is_processed: bool = false
	var is_persistent: bool = false

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
	
	if event.event_type < 0 or event.event_type >= EventType.CUSTOM_EVENT:
		return false
	
	if event.delay < 0.0:
		return false
	
	return true

func _add_immediate_event(event: JuicyEvent) -> bool:
	"""添加立即事件"""
	if _event_queue.size() >= _max_queue_size:
		push_warning("Event queue is full, dropping oldest event")
		_event_queue.pop_front()
	
	_event_queue.append(event)
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
		event.delay -= get_process_delta_time()
		
		if event.delay <= 0.0:
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
```

**开发任务分解**：
- [ ] 第9周第1天：事件数据结构定义
- [ ] 第9周第1天：事件缓冲区基础功能
- [ ] 第9周第2天：延迟事件处理
- [ ] 第9周第2天：持久事件管理
- [ ] 第9周第3天：优先级排序和批量处理
- [ ] 第9周第3天：统计和调试功能
- [ ] 第9周第4天：单元测试

**验收标准**：
- 事件队列管理正确
- 延迟事件准确触发
- 优先级排序有效
- 单元测试覆盖率100%

---

### 4.2 JuicyEventScheduler (事件调度器)

**文件路径**：`addons/juicy_mixer/events/juicy_event_scheduler.gd`

**核心职责**：
- 协调事件的分发和处理
- 管理事件处理器的注册
- 提供事件处理的优先级控制
- 实现事件处理的性能优化

**详细实现计划**：

```gdscript
class_name JuicyEventScheduler
extends RefCounted

# 事件处理器存储
var _event_handlers: Dictionary = {}  # EventType -> Array[JuicyEventHandler]
var _handler_priorities: Dictionary = {}  # handler_name -> priority

# 调度状态
var _is_processing: bool = false
var _processing_queue: Array[JuicyEvent] = []
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
	
	print("Registered event handler: ", handler.handler_name)
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

func get_handlers_for_event(event_type: JuicyEventBuffer.EventType) -> Array[JuicyEventHandler]:
	"""获取处理指定事件类型的处理器"""
	return _event_handlers.get(event_type, []).duplicate()

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
		return false
	
	var success_count = 0
	
	for handler in handlers:
		try:
			if handler.handle_event(event):
				success_count += 1
		except:
			push_error("Event handler '" + handler.handler_name + "' failed to process event")
	
	return success_count > 0

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
```

**开发任务分解**：
- [ ] 第9周第4天：处理器注册和管理
- [ ] 第9周第5天：事件处理逻辑
- [ ] 第10周第1天：批处理和性能优化
- [ ] 第10周第1天：优先级控制
- [ ] 第10周第2天：统计和调试功能
- [ ] 第10周第2天：单元测试

**验收标准**：
- 处理器注册管理正确
- 事件分发准确
- 批处理性能良好
- 单元测试覆盖率100%

---

### 4.3 JuicyEventHandler (事件处理器基类)

**文件路径**：`addons/juicy_mixer/events/juicy_event_handler.gd`

**核心职责**：
- 定义事件处理器的通用接口
- 提供事件处理的基础框架
- 支持事件类型过滤
- 实现处理器的生命周期管理

**详细实现计划**：

```gdscript
class_name JuicyEventHandler
extends RefCounted

# 处理器元信息
var handler_name: String = ""
var handler_version: String = "1.0.0"
var supported_events: Array[JuicyEventBuffer.EventType] = []
var enabled: bool = true
var description: String = ""

# 性能统计
var _events_handled: int = 0
var _events_failed: int = 0
var _total_handling_time: float = 0.0
var _last_handling_time: float = 0.0

# 核心接口 - 子类必须实现
func can_handle(event: JuicyEvent) -> bool:
	"""检查是否可以处理指定事件"""
	return event.event_type in supported_events

func handle_event(event: JuicyEvent) -> bool:
	"""处理事件，子类必须实现"""
	push_error("handle_event() must be implemented by subclass")
	return false

func cleanup() -> void:
	"""清理处理器状态"""
	pass

# 生命周期钩子
func on_handler_registered() -> void:
	"""处理器注册时调用"""
	pass

func on_handler_unregistered() -> void:
	"""处理器注销时调用"""
	pass

func on_event_buffer_cleared() -> void:
	"""事件缓冲区清空时调用"""
	pass

# 验证接口
func validate_event(event: JuicyEvent) -> Dictionary:
	"""验证事件是否适合此处理器"""
	var result = {
		"valid": true,
		"issues": [],
		"warnings": []
	}
	
	if not event:
		result.valid = false
		result.issues.append("Event is null")
		return result
	
	if not can_handle(event):
		result.valid = false
		result.issues.append("Event type not supported: " + str(event.event_type))
	
	return result

# 配置接口
func configure(config: Dictionary) -> void:
	"""配置处理器参数"""
	for key in config.keys():
		if key in self:
			self.set(key, config[key])

func get_configuration() -> Dictionary:
	"""获取当前配置"""
	return {}

# 性能监控
func get_performance_stats() -> Dictionary:
	return {
		"events_handled": _events_handled,
		"events_failed": _events_failed,
		"success_rate": float(_events_handled) / max(_events_handled + _events_failed, 1),
		"total_handling_time": _total_handling_time,
		"average_handling_time": _total_handling_time / max(_events_handled, 1),
		"last_handling_time": _last_handling_time
	}

func reset_performance_stats() -> void:
	_events_handled = 0
	_events_failed = 0
	_total_handling_time = 0.0
	_last_handling_time = 0.0

# 内部方法
func _start_handling_timer() -> float:
	return Time.get_ticks_usec()

func _end_handling_timer(start_time: float) -> void:
	_last_handling_time = (Time.get_ticks_usec() - start_time) / 1000.0
	_total_handling_time += _last_handling_time

func _record_success() -> void:
	_events_handled += 1

func _record_failure() -> void:
	_events_failed += 1

func _log_debug(message: String) -> void:
	if OS.is_debug_build():
		print("[", handler_name, "] ", message)

func _log_warning(message: String) -> void:
	push_warning("[" + handler_name + "] " + message)

func _log_error(message: String) -> void:
	push_error("[" + handler_name + "] " + message)
	_record_failure()

# 事件创建辅助方法
func _create_audio_play_event(context_id: String, target: Node, audio_stream: AudioStream, 
							 position: Vector2 = Vector2.ZERO, volume: float = 1.0) -> JuicyEvent:
	"""创建音频播放事件"""
	var event = JuicyEvent.new()
	event.event_type = JuicyEventBuffer.EventType.AUDIO_PLAY
	event.context_id = context_id
	event.target = target
	event.event_data = {
		"audio_stream": audio_stream,
		"position": position,
		"volume": volume
	}
	return event

func _create_particle_spawn_event(context_id: String, target: Node, particle_scene: PackedScene,
							   amount: int = 10, position: Vector2 = Vector2.ZERO) -> JuicyEvent:
	"""创建粒子生成事件"""
	var event = JuicyEvent.new()
	event.event_type = JuicyEventBuffer.EventType.PARTICLE_SPAWN
	event.context_id = context_id
	event.target = target
	event.event_data = {
		"particle_scene": particle_scene,
		"amount": amount,
		"position": position
	}
	return event

func _create_ui_update_event(context_id: String, target: Node, property: String, value: Variant) -> JuicyEvent:
	"""创建UI更新事件"""
	var event = JuicyEvent.new()
	event.event_type = JuicyEventBuffer.EventType.UI_UPDATE
	event.context_id = context_id
	event.target = target
	event.event_data = {
		"property": property,
		"value": value
	}
	return event
```

**开发任务分解**：
- [ ] 第10周第2天：基础类结构和接口定义
- [ ] 第10周第3天：验证和性能监控
- [ ] 第10周第3天：配置和生命周期管理
- [ ] 第10周第4天：事件创建辅助方法
- [ ] 第10周第4天：单元测试

**验收标准**：
- 基类接口定义完整
- 验证机制正确工作
- 性能监控功能正常
- 单元测试覆盖率100%

---

### 4.4 JuicyAudioEventHandler (音频事件处理器)

**文件路径**：`addons/juicy_mixer/events/juicy_audio_event_handler.gd`

**核心职责**：
- 处理音频播放和停止事件
- 管理音频播放器池
- 支持空间音频效果
- 提供音频混音和淡入淡出

**详细实现计划**：

```gdscript
class_name JuicyAudioEventHandler
extends JuicyEventHandler

# 音频播放器池
var _player_pool: Array[AudioStreamPlayer2D] = []
var _active_players: Dictionary = {}  # player_id -> player_info
var _max_pool_size: int = 50
var _max_concurrent_sounds: int = 20

# 音频配置
var _master_volume: float = 1.0
var _audio_bus: String = "Master"
var _spatial_audio_enabled: bool = true

func _init():
	handler_name = "AudioEventHandler"
	supported_events = [
		JuicyEventBuffer.EventType.AUDIO_PLAY,
		JuicyEventBuffer.EventType.AUDIO_STOP
	]
	description = "Handles audio playback and control events"

func handle_event(event: JuicyEvent) -> bool:
	"""处理音频事件"""
	var start_time = _start_handling_timer()
	
	var success = false
	
	match event.event_type:
		JuicyEventBuffer.EventType.AUDIO_PLAY:
			success = _handle_audio_play(event)
		JuicyEventBuffer.EventType.AUDIO_STOP:
			success = _handle_audio_stop(event)
		_:
			_log_warning("Unsupported event type: " + str(event.event_type))
	
	_end_handling_timer(start_time)
	
	if success:
		_record_success()
	else:
		_record_failure()
	
	return success

# 音频播放处理
func _handle_audio_play(event: JuicyEvent) -> bool:
	"""处理音频播放事件"""
	var audio_stream = event.event_data.get("audio_stream")
	var position = event.event_data.get("position", Vector2.ZERO)
	var volume = event.event_data.get("volume", 1.0)
	
	if not audio_stream:
		_log_error("Audio stream is null")
		return false
	
	# 检查并发限制
	if _active_players.size() >= _max_concurrent_sounds:
		_log_warning("Maximum concurrent sounds reached, stopping oldest")
		_stop_oldest_player()
	
	# 获取播放器
	var player = _get_audio_player()
	if not player:
		_log_error("Failed to get audio player")
		return false
	
	# 配置播放器
	player.stream = audio_stream
	player.position = position
	player.volume_db = _linear_to_db(volume * _master_volume)
	player.bus = _audio_bus
	
	# 播放音频
	player.play()
	
	# 记录活跃播放器
	var player_id = player.get_instance_id()
	_active_players[player_id] = {
		"player": player,
		"context_id": event.context_id,
		"event_id": event.event_id,
		"start_time": Time.get_ticks_msec() / 1000.0
	}
	
	return true

func _handle_audio_stop(event: JuicyEvent) -> bool:
	"""处理音频停止事件"""
	var context_id = event.context_id
	var event_id = event.event_id
	
	var players_to_stop: Array[AudioStreamPlayer2D] = []
	
	# 查找要停止的播放器
	for player_id in _active_players.keys():
		var player_info = _active_players[player_id]
		if player_info.context_id == context_id or player_info.event_id == event_id:
			players_to_stop.append(player_info.player)
	
	# 停止播放器
	for player in players_to_stop:
		_stop_audio_player(player)
	
	return players_to_stop.size() > 0

# 播放器管理
func _get_audio_player() -> AudioStreamPlayer2D:
	"""获取音频播放器"""
	# 从池中获取
	if not _player_pool.is_empty():
		return _player_pool.pop_back()
	
	# 创建新的播放器
	if _player_pool.size() + _active_players.size() < _max_pool_size:
		var player = AudioStreamPlayer2D.new()
		_setup_audio_player(player)
		return player
	
	return null

func _setup_audio_player(player: AudioStreamPlayer2D) -> void:
	"""设置音频播放器"""
	player.finished.connect(_on_player_finished.bind(player))
	
	# 添加到场景树
	var audio_root = _get_audio_root()
	audio_root.add_child(player)

func _stop_audio_player(player: AudioStreamPlayer2D) -> void:
	"""停止音频播放器"""
	if not player or not is_instance_valid(player):
		return
	
	player.stop()
	_return_audio_player(player)

func _return_audio_player(player: AudioStreamPlayer2D) -> void:
	"""归还音频播放器到池"""
	var player_id = player.get_instance_id()
	
	# 从活跃列表中移除
	_active_players.erase(player_id)
	
	# 重置播放器状态
	player.stream = null
	player.position = Vector2.ZERO
	player.volume_db = 0.0
	
	# 返回到池
	if _player_pool.size() < _max_pool_size:
		_player_pool.append(player)
	else:
		player.queue_free()

func _stop_oldest_player() -> void:
	"""停止最老的播放器"""
	var oldest_time = INF
	var oldest_player_id = ""
	
	for player_id in _active_players.keys():
		var player_info = _active_players[player_id]
		if player_info.start_time < oldest_time:
			oldest_time = player_info.start_time
			oldest_player_id = player_id
	
	if not oldest_player_id.is_empty():
		var player_info = _active_players[oldest_player_id]
		_stop_audio_player(player_info.player)

# 回调处理
func _on_player_finished(player: AudioStreamPlayer2D) -> void:
	"""播放器完成回调"""
	_return_audio_player(player)

# 工具方法
func _get_audio_root() -> Node:
	"""获取音频根节点"""
	# 尝试获取现有的音频根节点
	var scene_root = Engine.get_main_loop().current_scene
	var audio_root = scene_root.get_node_or_null("JuicyAudioRoot")
	
	if not audio_root:
		audio_root = Node.new("JuicyAudioRoot")
		scene_root.add_child(audio_root)
	
	return audio_root

func _linear_to_db(linear: float) -> float:
	"""线性值转分贝"""
	if linear <= 0.0:
		return -80.0
	return 20.0 * log(linear) / log(10.0)

# 配置管理
func configure(config: Dictionary) -> void:
	super.configure(config)
	
	if config.has("max_pool_size"):
		_max_pool_size = config.max_pool_size
	
	if config.has("max_concurrent_sounds"):
		_max_concurrent_sounds = config.max_concurrent_sounds
	
	if config.has("master_volume"):
		_master_volume = clamp(config.master_volume, 0.0, 1.0)
	
	if config.has("audio_bus"):
		_audio_bus = config.audio_bus
	
	if config.has("spatial_audio_enabled"):
		_spatial_audio_enabled = config.spatial_audio_enabled

func get_configuration() -> Dictionary:
	return super.get_configuration().merge({
		"max_pool_size": _max_pool_size,
		"max_concurrent_sounds": _max_concurrent_sounds,
		"master_volume": _master_volume,
		"audio_bus": _audio_bus,
		"spatial_audio_enabled": _spatial_audio_enabled
	})

# 统计和调试
func get_audio_stats() -> Dictionary:
	"""获取音频统计信息"""
	return {
		"pool_size": _player_pool.size(),
		"active_players": _active_players.size(),
		"max_pool_size": _max_pool_size,
		"max_concurrent_sounds": _max_concurrent_sounds,
		"master_volume": _master_volume
	}

func cleanup() -> void:
	"""清理音频处理器"""
	# 停止所有活跃播放器
	for player_id in _active_players.keys():
		var player_info = _active_players[player_id]
		_stop_audio_player(player_info.player)
	
	# 清空播放器池
	for player in _player_pool:
		if is_instance_valid(player):
			player.queue_free()
	_player_pool.clear()
```

**开发任务分解**：
- [ ] 第10周第4天：音频播放器池管理
- [ ] 第10周第5天：音频播放和停止处理
- [ ] 第10周第5天：空间音频和混音
- [ ] 第10周第5天：配置管理和统计
- [ ] 第10周第5天：单元测试

**验收标准**：
- 音频播放和停止正常
- 播放器池管理有效
- 空间音频支持良好
- 单元测试覆盖率100%

---

### 4.5 JuicyParticleEventHandler (粒子事件处理器)

**文件路径**：`addons/juicy_mixer/events/juicy_particle_event_handler.gd`

**核心职责**：
- 处理粒子生成和停止事件
- 管理粒子系统池
- 支持粒子效果配置
- 提供粒子性能优化

**详细实现计划**：

```gdscript
class_name JuicyParticleEventHandler
extends JuicyEventHandler

# 粒子系统池
var _particle_pool: Array[GPUParticles2D] = []
var _active_particles: Dictionary = {}  # particle_id -> particle_info
var _max_pool_size: int = 30
var _max_concurrent_systems: int = 15

# 粒子配置
var _particle_root: Node
var _auto_cleanup_time: float = 10.0

func _init():
	handler_name = "ParticleEventHandler"
	supported_events = [
		JuicyEventBuffer.EventType.PARTICLE_SPAWN,
		JuicyEventBuffer.EventType.PARTICLE_STOP
	]
	description = "Handles particle system events"

func handle_event(event: JuicyEvent) -> bool:
	"""处理粒子事件"""
	var start_time = _start_handling_timer()
	
	var success = false
	
	match event.event_type:
		JuicyEventBuffer.EventType.PARTICLE_SPAWN:
			success = _handle_particle_spawn(event)
		JuicyEventBuffer.EventType.PARTICLE_STOP:
			success = _handle_particle_stop(event)
		_:
			_log_warning("Unsupported event type: " + str(event.event_type))
	
	_end_handling_timer(start_time)
	
	if success:
		_record_success()
	else:
		_record_failure()
	
	return success

# 粒子生成处理
func _handle_particle_spawn(event: JuicyEvent) -> bool:
	"""处理粒子生成事件"""
	var particle_scene = event.event_data.get("particle_scene")
	var amount = event.event_data.get("amount", 10)
	var position = event.event_data.get("position", Vector2.ZERO)
	
	if not particle_scene:
		_log_error("Particle scene is null")
		return false
	
	# 检查并发限制
	if _active_particles.size() >= _max_concurrent_systems:
		_log_warning("Maximum concurrent particle systems reached, stopping oldest")
		_stop_oldest_particles()
	
	# 获取粒子系统
	var particles = _get_particle_system()
	if not particles:
		_log_error("Failed to get particle system")
		return false
	
	# 配置粒子系统
	_setup_particle_system(particles, particle_scene, amount, position)
	
	# 启动粒子系统
	particles.emitting = true
	
	# 记录活跃粒子系统
	var particle_id = particles.get_instance_id()
	_active_particles[particle_id] = {
		"particles": particles,
		"context_id": event.context_id,
		"event_id": event.event_id,
		"start_time": Time.get_ticks_msec() / 1000.0,
		"auto_cleanup_time": _auto_cleanup_time
	}
	
	return true

func _handle_particle_stop(event: JuicyEvent) -> bool:
	"""处理粒子停止事件"""
	var context_id = event.context_id
	var event_id = event.event_id
	
	var particles_to_stop: Array[GPUParticles2D] = []
	
	# 查找要停止的粒子系统
	for particle_id in _active_particles.keys():
		var particle_info = _active_particles[particle_id]
		if particle_info.context_id == context_id or particle_info.event_id == event_id:
			particles_to_stop.append(particle_info.particles)
	
	# 停止粒子系统
	for particles in particles_to_stop:
		_stop_particle_system(particles)
	
	return particles_to_stop.size() > 0

# 粒子系统管理
func _get_particle_system() -> GPUParticles2D:
	"""获取粒子系统"""
	# 从池中获取
	if not _particle_pool.is_empty():
		return _particle_pool.pop_back()
	
	# 创建新的粒子系统
	if _particle_pool.size() + _active_particles.size() < _max_pool_size:
		var particles = GPUParticles2D.new()
		_setup_particle_system_defaults(particles)
		return particles
	
	return null

func _setup_particle_system_defaults(particles: GPUParticles2D) -> void:
	"""设置粒子系统默认值"""
	particles.emitting = false
	particles.explosiveness = 0.0
	particles.amount = 50
	particles.lifetime = 2.0
	particles.one_shot = true
	
	# 添加到场景树
	var particle_root = _get_particle_root()
	particle_root.add_child(particles)

func _setup_particle_system(particles: GPUParticles2D, particle_scene: PackedScene, 
						   amount: int, position: Vector2) -> void:
	"""设置粒子系统参数"""
	particles.position = position
	particles.amount = amount
	
	# 如果有粒子场景，设置其属性
	if particle_scene:
		# 这里可以根据需要配置粒子场景
		pass

func _stop_particle_system(particles: GPUParticles2D) -> void:
	"""停止粒子系统"""
	if not particles or not is_instance_valid(particles):
		return
	
	particles.emitting = false
	_return_particle_system(particles)

func _return_particle_system(particles: GPUParticles2D) -> void:
	"""归还粒子系统到池"""
	var particle_id = particles.get_instance_id()
	
	# 从活跃列表中移除
	_active_particles.erase(particle_id)
	
	# 重置粒子系统状态
	particles.emitting = false
	particles.position = Vector2.ZERO
	particles.amount = 50
	particles.lifetime = 2.0
	
	# 返回到池
	if _particle_pool.size() < _max_pool_size:
		_particle_pool.append(particles)
	else:
		particles.queue_free()

func _stop_oldest_particles() -> void:
	"""停止最老的粒子系统"""
	var oldest_time = INF
	var oldest_particle_id = ""
	
	for particle_id in _active_particles.keys():
		var particle_info = _active_particles[particle_id]
		if particle_info.start_time < oldest_time:
			oldest_time = particle_info.start_time
			oldest_particle_id = particle_id
	
	if not oldest_particle_id.is_empty():
		var particle_info = _active_particles[oldest_particle_id]
		_stop_particle_system(particle_info.particles)

# 自动清理
func update_auto_cleanup(delta: float) -> void:
	"""更新自动清理"""
	var particles_to_cleanup: Array[GPUParticles2D] = []
	
	for particle_id in _active_particles.keys():
		var particle_info = _active_particles[particle_id]
		particle_info.auto_cleanup_time -= delta
		
		if particle_info.auto_cleanup_time <= 0.0:
			particles_to_cleanup.append(particle_info.particles)
	
	# 清理到期的粒子系统
	for particles in particles_to_cleanup:
		_stop_particle_system(particles)

# 工具方法
func _get_particle_root() -> Node:
	"""获取粒子根节点"""
	if not _particle_root:
		var scene_root = Engine.get_main_loop().current_scene
		_particle_root = Node.new("JuicyParticleRoot")
		scene_root.add_child(_particle_root)
	
	return _particle_root

# 配置管理
func configure(config: Dictionary) -> void:
	super.configure(config)
	
	if config.has("max_pool_size"):
		_max_pool_size = config.max_pool_size
	
	if config.has("max_concurrent_systems"):
		_max_concurrent_systems = config.max_concurrent_systems
	
	if config.has("auto_cleanup_time"):
		_auto_cleanup_time = config.auto_cleanup_time

func get_configuration() -> Dictionary:
	return super.get_configuration().merge({
		"max_pool_size": _max_pool_size,
		"max_concurrent_systems": _max_concurrent_systems,
		"auto_cleanup_time": _auto_cleanup_time
	})

# 统计和调试
func get_particle_stats() -> Dictionary:
	"""获取粒子统计信息"""
	return {
		"pool_size": _particle_pool.size(),
		"active_particles": _active_particles.size(),
		"max_pool_size": _max_pool_size,
		"max_concurrent_systems": _max_concurrent_systems
	}

func cleanup() -> void:
	"""清理粒子处理器"""
	# 停止所有活跃粒子系统
	for particle_id in _active_particles.keys():
		var particle_info = _active_particles[particle_id]
		_stop_particle_system(particle_info.particles)
	
	# 清空粒子系统池
	for particles in _particle_pool:
		if is_instance_valid(particles):
			particles.queue_free()
	_particle_pool.clear()
```

**开发任务分解**：
- [ ] 第10周第5天：粒子系统池管理
- [ ] 第10周第5天：粒子生成和停止处理
- [ ] 第10周第5天：自动清理机制
- [ ] 第10周第5天：配置管理和统计
- [ ] 第10周第5天：单元测试

**验收标准**：
- 粒子生成和停止正常
- 粒子系统池管理有效
- 自动清理机制工作
- 单元测试覆盖率100%

---

## 集成测试计划

### 测试场景1：事件缓冲区基础功能测试
```gdscript
func test_event_buffer_basic():
	var buffer = JuicyEventBuffer.new()
	
	# 创建测试事件
	var event = JuicyEvent.new()
	event.event_type = JuicyEventBuffer.EventType.AUDIO_PLAY
	event.context_id = "test_context"
	event.priority = 10
	
	# 添加事件
	assert_true(buffer.add_event(event))
	
	# 获取准备处理的事件
	var ready_events = buffer.get_ready_events()
	assert_eq(ready_events.size(), 1)
	assert_eq(ready_events[0].event_type, JuicyEventBuffer.EventType.AUDIO_PLAY)
	
	# 标记已处理
	buffer.mark_events_processed(ready_events)
	
	# 验证缓冲区状态
	var stats = buffer.get_buffer_stats()
	assert_eq(stats.total_events_processed, 1)
```

### 测试场景2：事件调度器处理测试
```gdscript
func test_event_scheduler_processing():
	var buffer = JuicyEventBuffer.new()
	var scheduler = JuicyEventScheduler.new()
	
	# 注册测试处理器
	var handler = TestAudioEventHandler.new()
	scheduler.register_handler(handler, 100)
	
	# 添加测试事件
	var event = _create_test_audio_event()
	buffer.add_event(event)
	
	# 处理事件
	var processed_count = scheduler.process_events(buffer, 0.016)
	
	# 验证处理结果
	assert_eq(processed_count, 1)
	assert_eq(handler.get_performance_stats().events_handled, 1)
```

### 测试场景3：音频处理器功能测试
```gdscript
func test_audio_event_handler():
	var handler = JuicyAudioEventHandler.new()
	
	# 创建音频播放事件
	var event = handler._create_audio_play_event(
		"test_context", null, test_audio_stream
	)
	
	# 处理事件
	assert_true(handler.handle_event(event))
	
	# 验证统计信息
	var stats = handler.get_audio_stats()
	assert_gt(stats.active_players, 0)
	
	# 创建停止事件
	var stop_event = JuicyEvent.new()
	stop_event.event_type = JuicyEventBuffer.EventType.AUDIO_STOP
	stop_event.context_id = "test_context"
	
	# 处理停止事件
	assert_true(handler.handle_event(stop_event))
```

---

## 性能基准测试

### 基准1：事件缓冲区操作性能
- **目标**：10000次事件添加 < 16ms
- **测试方法**：批量添加事件并测量时间
- **验收标准**：平均添加时间 < 0.0016ms

### 基准2：事件调度器处理性能
- **目标**：1000个事件处理 < 16ms
- **测试方法**：批量处理事件并测量时间
- **验收标准**：平均处理时间 < 0.016ms

### 基准3：音频处理器性能
- **目标**：100个并发音频播放 < 16ms
- **测试方法**：批量播放音频并测量时间
- **验收标准**：平均播放时间 < 0.16ms

---

## 风险管控

### 技术风险
1. **音频资源管理**：音频播放器可能泄漏
   - 缓解措施：实现严格的资源池管理和清理机制
   
2. **粒子系统性能**：大量粒子可能影响性能
   - 缓解措施：实现粒子系统池和自动清理

### 进度风险
1. **事件系统复杂性**：事件类型和处理逻辑复杂
   - 缓解措施：分阶段实现，先实现基础功能

2. **跨平台兼容性**：音频和粒子在不同平台表现可能不同
   - 缓解措施：提供平台特定的配置和测试

---

## 交付检查清单

### 代码交付
- [ ] JuicyEventBuffer事件缓冲区完整实现
- [ ] JuicyEventScheduler事件调度器完整实现
- [ ] JuicyEventHandler事件处理器基类完整实现
- [ ] JuicyAudioEventHandler音频处理器完整实现
- [ ] JuicyParticleEventHandler粒子处理器完整实现

### 文档交付
- [ ] 事件系统API文档
- [ ] 事件处理器开发指南
- [ ] 性能基准报告
- [ ] 集成测试报告

### 验收标准
- [ ] 所有单元测试通过（覆盖率100%）
- [ ] 所有集成测试通过
- [ ] 性能基准测试达标
- [ ] 代码审查通过
- [ ] 文档完整准确

---

## 总结

阶段4实现了JuicyMixer V3的事件驱动系统，提供了统一的非属性反馈处理机制。通过事件缓冲区、调度器和专门的处理器，支持音频、粒子等多种反馈类型。

**关键成就**：
- 建立了统一的事件处理框架
- 实现了高效的音频和粒子处理
- 提供了灵活的事件调度机制
- 确保了良好的性能表现

**下一步**：进入阶段5，实现序列化与组合系统，支持复杂的效果编排。
