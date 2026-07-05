# JuicySequenceDriver - 联觉序列化执行引擎
# 执行效果序列，支持顺序和并行执行模式，实现事件驱动的感官同步
# 超越死板的时间轴，实现感官之间的互相触发

class_name JuicySequenceDriver
extends JuicyDriver

# =============================================================================
# 内部状态类
# =============================================================================

# 序列化状态管理 - 优化版本
class SequenceState:
	var current_index: int = 0
	var item_start_time: float = -1.0  # -1表示未开始
	var completed_items: Array[int] = []
	var active_contexts: Array[String] = []
	var loop_count: int = 0
	var is_paused: bool = false
	var waiting_events: Dictionary = {}  # 联觉系统：等待的事件 item_index -> event_name
	var event_start_times: Dictionary = {}  # 联觉系统：事件开始时间
	var triggered_events: Array[String] = []  # 联觉系统：已触发的事件
	var event_handlers: Dictionary = {}  # 联觉系统：事件处理器映射 event_name -> handler_name
	
	# Timer-based延迟状态管理
	var delay_timer: Timer = null  # 延迟计时器
	var item_executed: bool = false  # 当前项是否已执行
	var timer_created: bool = false  # Timer是否已创建
	var delay_completed: bool = false  # 延迟是否已完成
	
	# 并行执行延迟管理
	var parallel_delay_timers: Dictionary = {}  # item_index -> Timer
	var parallel_delay_completed: Dictionary = {}  # item_index -> bool
	var parallel_items_executed: Array[int] = []  # 已执行的并行项索引
	
	func _init():
		current_index = 0
		item_start_time = -1.0
		completed_items = []
		active_contexts = []
		loop_count = 0
		is_paused = false
		waiting_events = {}
		event_start_times = {}
		triggered_events = []
		event_handlers = {}
		delay_timer = null
		item_executed = false
		timer_created = false
		parallel_delay_timers = {}
		parallel_delay_completed = {}
		parallel_items_executed = []

# =============================================================================
# 属性配置
# =============================================================================

var sequence_resource: JuicySequenceResource
var _sequence_states: Dictionary = {}  # context_id -> SequenceState

# =============================================================================
# 生命周期方法
# =============================================================================

func _init():
	driver_name = "JuicySequenceDriver"
	supported_properties = []  # 序列化驱动器不直接处理属性

func prepare(context: JuicyContext, delta: float, buffer: JuicyPropertyBuffer) -> void:
	# 验证序列资源
	if not sequence_resource:
		push_error("JuicySequenceDriver: sequence_resource is null")
		context.complete()
		return
	
	# 验证序列项
	var items = sequence_resource.get("sequence_items")
	if items.is_empty():
		push_warning("JuicySequenceDriver: sequence_items is empty")
		context.complete()
		return
	
	# 创建优化后的状态
	var state = SequenceState.new()
	state.current_index = 0
	
	# 重置上下文的时间计算，序列应该从第一项开始时才计时
	context.start_time = -1.0  # 标记为未开始
	context.current_time = 0.0
	context.progress = 0.0
	
	# 设置一个非常大的duration值，防止自动完成
	# 序列的完成将由序列驱动器自己管理，而不是时间计算
	context.duration = 999999.0
	
	# 如果启用随机顺序，初始打乱序列
	if sequence_resource.random_order:
		_shuffle_sequence_items()
	
	# 联觉系统：注册全局事件监听器
	if sequence_resource.enable_event_sync:
		_register_event_listeners(context, state)
	
	_sequence_states[context.context_id] = state
	
	print("JuicySequenceDriver: [OPTIMIZED] Prepared sequence with ", items.size(), " items")

func process(context: JuicyContext, delta: float, buffer: JuicyPropertyBuffer) -> void:
	var state = _sequence_states.get(context.context_id)
	if not state:
		# 修复：添加调试信息，帮助诊断状态丢失问题
		print("JuicySequenceDriver: [DEBUG] No state found for context ", context.context_id)
		print("JuicySequenceDriver: [DEBUG] Available states: ", _sequence_states.keys())
		print("JuicySequenceDriver: [DEBUG] Context is_active: ", context.is_active if context else "null")
		print("JuicySequenceDriver: [DEBUG] Context start_time: ", context.start_time if context else "null")
		return
	
	# 如果暂停，跳过处理
	if state.is_paused:
		return
	
	# 联觉系统：检查事件超时和处理新事件
	if sequence_resource.enable_event_sync:
		_check_event_timeouts(state)
		_process_pending_events(state)
		_process_event_handlers(context, state)
	
	if sequence_resource.parallel:
		_process_parallel_sequence(context, state, delta)
	else:
		_process_sequential_sequence(context, state, delta)

func cleanup(context: JuicyContext) -> void:
	var state = _sequence_states.get(context.context_id)
	if state:
		# 修复：添加调试信息，帮助诊断状态清理时机
		print("JuicySequenceDriver: [DEBUG] Cleaning up context ", context.context_id, " with state: ", state)
		
		# 停止所有活跃的子上下文
		for context_id in state.active_contexts:
			JuicyMixer.stop(context_id)
		
		# 清理延迟Timer
		_cleanup_delay_timer(state)
		
		# 清理并行延迟Timer
		for item_index in state.parallel_delay_timers.keys():
			_cleanup_parallel_delay_timer(state, item_index)
		state.parallel_delay_timers.clear()
		state.parallel_delay_completed.clear()
		state.parallel_items_executed.clear()
		
		# 联觉系统：注销事件监听器
		if sequence_resource.enable_event_sync:
			_unregister_event_listeners(context)
		
		# 修复：延迟清理状态，确保在所有操作完成后才清理
		_sequence_states.erase(context.context_id)
		
		print("JuicySequenceDriver: [DEBUG] Remaining states after cleanup: ", _sequence_states.keys())
	else:
		push_warning("JuicySequenceDriver: No state found for cleanup of context " + context.context_id)

# =============================================================================
# 序列化执行逻辑
# =============================================================================

# 顺序序列执行 - 优化版本
func _process_sequential_sequence(context: JuicyContext, state: SequenceState, delta: float) -> void:
	var items = sequence_resource.get("sequence_items")
	if not sequence_resource or state.current_index >= items.size():
		return
	
	var current_item = items[state.current_index]
	if not current_item:
		push_error("JuicySequenceDriver: Null item at index " + str(state.current_index))
		_move_to_next_item(state)
		return
	
	# 联觉系统：检查事件触发条件
	if sequence_resource.enable_event_sync:
		if not _check_item_trigger_condition(context, current_item, state):
			return
	
	# 优化后的延迟处理逻辑
	if current_item.trigger_mode == JuicySequenceItem.TriggerMode.TIME:
		if not _handle_delay_timing(context, state, current_item):
			return  # 延迟未完成，返回等待
	
	# 执行当前项（如果还未执行）
	if not state.item_executed:
		_execute_item_if_ready(context, state, current_item)
		return  # 等待下一帧检查完成状态
	
	# 检查当前项是否完成
	if _check_item_completed(state.active_contexts):
		# 优化：在移动到下一项之前先检查序列是否完成，避免额外检查
		var next_index = state.current_index + 1
		if next_index >= items.size():
			# 联觉系统：清除等待的事件
			if sequence_resource.enable_event_sync:
				state.waiting_events.erase(state.current_index - 1)
			
			# 检查序列是否完成
			if sequence_resource.loop_sequence:
				_handle_sequence_loop(context, state)
			else:
				# 联觉系统：发送序列完成事件
				if sequence_resource.enable_event_sync:
					_emit_sequence_event(context, JuicySequenceEventHandler.SequenceEventType.SEQUENCE_COMPLETED, -1)
				context.complete()
		else:
			# 只有在还有更多项时才移动到下一项
			_move_to_next_item(state)
			# 联觉系统：清除等待的事件
			if sequence_resource.enable_event_sync:
				state.waiting_events.erase(state.current_index - 1)

# Timer-based延迟处理函数
func _handle_delay_timing(context: JuicyContext, state: SequenceState, item: JuicySequenceItem) -> bool:
	# 如果延迟为0或负数，立即执行
	if item.delay <= 0.0:
		# 对于0延迟，直接标记为完成，避免Timer的帧延迟
		state.delay_completed = true
		return true
	
	# 如果延迟已完成，直接返回true
	if state.delay_completed:
		return true
	
	# 如果Timer还未创建，创建并启动Timer
	if not state.timer_created:
		_create_delay_timer(context, state, item)
		return false  # Timer刚开始，等待
	
	# 检查Timer是否仍在运行
	if state.delay_timer and state.delay_timer.time_left > 0.001:  # 添加小的容差值
		return false  # 延迟未完成，继续等待
	
	# Timer已完成或已清理，执行项目
	# 注意：这里不再清理Timer，因为Timer会在timeout回调中自动清理
	if state.delay_timer == null:
		# Timer已经被清理，说明延迟已完成
		print("JuicySequenceDriver: [TIMER-BASED] Delay completed for item ", state.current_index, " after ", item.delay, "s")
		return true
	
	# Timer存在但time_left为0或接近0，说明刚完成，清理并执行
	_cleanup_delay_timer(state)
	print("JuicySequenceDriver: [TIMER-BASED] Delay completed for item ", state.current_index, " after ", item.delay, "s")
	return true  # 延迟完成，可以执行

# 创建延迟Timer - 高性能优化版本
func _create_delay_timer(context: JuicyContext, state: SequenceState, item: JuicySequenceItem) -> void:
	# 确保清理之前的Timer
	_cleanup_delay_timer(state)
	
	# 优化：对于0延迟，跳过Timer创建，直接标记完成
	if item.delay <= 0.0:
		state.delay_completed = true
		print("JuicySequenceDriver: [TIMER-BASED] Zero delay for item ", state.current_index, ", skipping timer creation")
		return
	
	# 创建Timer节点
	state.delay_timer = Timer.new()
	state.delay_timer.wait_time = item.delay
	state.delay_timer.one_shot = true
	state.delay_timer.timeout.connect(_on_delay_timer_completed.bind(context, state))
	
	# 优化：直接获取场景树根节点，避免多层查找开销
	var scene_tree = Engine.get_main_loop() as SceneTree
	if scene_tree and scene_tree.current_scene:
		scene_tree.current_scene.add_child(state.delay_timer)
	else:
		push_warning("JuicySequenceDriver: Cannot find scene tree to add timer")
		return
	
	# 立即启动Timer
	state.delay_timer.start()
	state.timer_created = true
	
	# 优化：减少调试输出

# Timer完成回调 - 高性能优化版本
func _on_delay_timer_completed(context: JuicyContext, state: SequenceState) -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	# 标记延迟已完成，防止重复创建
	state.delay_completed = true
	# 立即清理Timer和状态，防止重复创建
	_cleanup_delay_timer(state)
	
	# 优化：立即在同帧内处理，避免额外一帧的延迟
	# 使用call_deferred确保在当前帧处理完成后立即执行
	call_deferred("_process_sequential_sequence", context, state, 0.0)

# 清理延迟Timer
func _cleanup_delay_timer(state: SequenceState) -> void:
	if state.delay_timer:
		if state.delay_timer.is_inside_tree():
			state.delay_timer.queue_free()
		state.delay_timer = null
	state.timer_created = false
	# 注意：不重置delay_completed，让它保持true直到下一项

# 执行项目（如果准备就绪）
func _execute_item_if_ready(context: JuicyContext, state: SequenceState, item: JuicySequenceItem) -> void:
	# 如果是第一项，启动序列计时
	if state.current_index == 0 and context.start_time < 0:
		context.start_time = Time.get_ticks_msec() / 1000.0
		print("JuicySequenceDriver: [OPTIMIZED] Started sequence timing at ", context.start_time)
		
		# 确保序列上下文的时间计算正确
		context.current_time = 0.0
		context.progress = 0.0
	
	# 联觉系统：发送序列项开始事件
	if sequence_resource.enable_event_sync:
		_emit_sequence_event(context, JuicySequenceEventHandler.SequenceEventType.SEQUENCE_ITEM_STARTED, state.current_index)
	
	_execute_sequence_item(context, item, state)
	state.item_executed = true
	# 优化：减少调试输出

# 移动到下一项
func _move_to_next_item(state: SequenceState) -> void:
	print("JuicySequenceDriver: [TIMER-BASED] Moving from item ", state.current_index, " to next")
	state.completed_items.append(state.current_index)
	state.current_index += 1
	state.active_contexts.clear()
	
	# 重置状态为下一项做准备（清理Timer）
	_cleanup_delay_timer(state)
	state.item_executed = false
	state.delay_completed = false  # 重置延迟完成状态
	state.timer_created = false  # 重置Timer创建状态

# 并行序列执行 - 优化版本（修复延迟处理）
func _process_parallel_sequence(context: JuicyContext, state: SequenceState, delta: float) -> void:
	if not sequence_resource:
		return
	
	var items = sequence_resource.get("sequence_items")
	
	# 如果是第一项，启动序列计时
	if state.current_index == 0 and context.start_time < 0:
		context.start_time = Time.get_ticks_msec() / 1000.0
		print("JuicySequenceDriver: [OPTIMIZED] Started parallel sequence timing at ", context.start_time)
	
	# 联觉系统：发送序列开始事件（只在开始时发送一次）
	if state.active_contexts.is_empty() and not state.timer_created:
		if sequence_resource.enable_event_sync:
			_emit_sequence_event(context, JuicySequenceEventHandler.SequenceEventType.SEQUENCE_STARTED, -1)
	
	# 并行延迟处理：为每个项创建独立的延迟Timer
	for i in range(items.size()):
		var item = items[i]
		if not item:
			push_error("JuicySequenceDriver: Null item at index " + str(i))
			continue
		
		# 跳过已完成的项
		if i in state.completed_items:
			continue
		
		# 跳过已执行的项（修复无限循环问题）
		if i in state.parallel_items_executed:
			continue
		
		# 联觉系统：检查事件触发条件
		if sequence_resource.enable_event_sync:
			if not _check_item_trigger_condition_for_parallel(context, item, state, i):
				continue
		
		# 处理延迟（使用独立的状态管理）
		if item.trigger_mode == JuicySequenceItem.TriggerMode.TIME:
			if not _handle_parallel_delay_timing(context, state, item, i):
				continue  # 延迟未完成，跳过此项
		
		# 执行项
		if _should_execute_item(item, context):
			_execute_parallel_sequence_item(context, item, state, i)
	
	# 检查所有项是否完成 - 修复完成检测逻辑
	var all_completed = false
	
	# 方法1：检查所有项是否都已执行
	if state.parallel_items_executed.size() >= items.size():
		# 所有项都已执行，检查它们的上下文是否完成
		all_completed = _check_all_parallel_items_completed(state.active_contexts)
	
	# 方法2：如果没有活跃上下文但所有项都已执行，说明完成了
	elif state.parallel_items_executed.size() >= items.size() and state.active_contexts.is_empty():
		# 所有项都已执行且没有活跃上下文，说明都完成了
		all_completed = true
	
	# 优化：移除调试输出，提高性能
	
	if all_completed:
		print("JuicySequenceDriver: [OPTIMIZED] All parallel items completed")
		if sequence_resource.loop_sequence:
			_handle_sequence_loop(context, state)
		else:
			# 联觉系统：发送序列完成事件
			if sequence_resource.enable_event_sync:
				_emit_sequence_event(context, JuicySequenceEventHandler.SequenceEventType.SEQUENCE_COMPLETED, -1)
			context.complete()

# 检查所有并行项是否完成
func _check_all_parallel_items_completed(context_ids: Array[String]) -> bool:
	if context_ids.is_empty():
		return false
		
	for context_id in context_ids:
		var item_context = JuicyMixer.get_context(context_id)
		# 修复逻辑：找不到的上下文视为已完成（已被系统清理）
		if item_context and not item_context.is_completed:
			return false
	return true

# 执行序列项
func _execute_sequence_item(context: JuicyContext, item: JuicySequenceItem, state: SequenceState) -> void:
	if not item:
		push_error("JuicySequenceDriver: Cannot execute null item")
		return
		
	if not item.enabled:
		return
		
	if not item.resource:
		push_warning("JuicySequenceDriver: Item has no resource assigned")
		return
	
	# 验证资源配置
	var validation_result = item.resource.validate_config()
	if not validation_result.valid:
		push_error("JuicySequenceDriver: Item resource validation failed: " + str(validation_result.issues))
		return
	
	# 如果序列项指定了持续时间且资源是JuicyShakeResource，则更新ShakeData的duration
	if item.duration > 0.0 and item.resource is JuicyShakeResource:
		var shake_resource = item.resource as JuicyShakeResource
		for shake_data in shake_resource.shake_data:
			if shake_data and shake_data.duration != item.duration:
				print("JuicySequenceDriver: [DEBUG] Updating shake duration from ", shake_data.duration, " to ", item.duration)
				shake_data.duration = item.duration
	
	# 优化：创建子上下文并直接播放，减少函数调用开销
	var context_id = JuicyMixer.play(item.resource, context.target)
	if context_id:
		state.active_contexts.append(context_id)
		# 优化：内联上下文创建逻辑，减少函数调用开销
		var item_context = JuicyMixer.get_context(context_id)
		if item_context:
			item_context.time_scale = context.time_scale
	else:
		push_error("JuicySequenceDriver: Failed to play item resource")

# 检查项完成状态
func _check_item_completed(context_ids: Array[String]) -> bool:
	# 如果没有活跃的上下文，说明项还没有开始执行，不能算完成
	if not context_ids or context_ids.is_empty():
		print("JuicySequenceDriver: [DEBUG] _check_item_completed: no active contexts")
		return false
		
	for context_id in context_ids:
		var item_context = JuicyMixer.get_context(context_id)
		if not item_context:
			push_warning("JuicySequenceDriver: Context not found: " + str(context_id))
			continue
		
		# JuicyContext的is_completed属性已经包含了所有必要的检查：
		# 1. 只有当is_active=true且start_time>=0时才会更新progress
		# 2. 只有当progress>=1.0时才会设置is_completed=true
		if not item_context.is_completed:
			return false
	return true

# 处理序列循环 - 高性能优化版本
func _handle_sequence_loop(context: JuicyContext, state: SequenceState) -> void:
	var loop_start_time = Time.get_ticks_msec() / 1000.0
	
	state.loop_count += 1
	
	# 联觉系统：发送序列循环事件
	if sequence_resource.enable_event_sync:
		_emit_sequence_event(context, JuicySequenceEventHandler.SequenceEventType.SEQUENCE_LOOPED, state.loop_count)
	
	if sequence_resource.loop_count > 0 and state.loop_count >= sequence_resource.loop_count:
		print("JuicySequenceDriver: [OPTIMIZED] Sequence loop completed after " + str(state.loop_count) + " loops")
		context.complete()
	else:
		# 高性能状态重置 - 减少循环切换开销
		# 优化1: 批量清理而不是逐个操作
		state.current_index = 0
		state.completed_items.clear()
		state.active_contexts.clear()
		
		# 优化2: 快速重置延迟状态（避免不必要的Timer清理）
		_cleanup_delay_timer(state)
		state.item_executed = false
		state.delay_completed = false
		
		# 优化3: 批量清理并行延迟状态
		for item_index in state.parallel_delay_timers.keys():
			_cleanup_parallel_delay_timer(state, item_index)
		state.parallel_delay_timers.clear()
		state.parallel_delay_completed.clear()
		state.parallel_items_executed.clear()
		
		# 优化4: 快速清理事件状态（避免字典操作开销）
		if sequence_resource.enable_event_sync:
			state.waiting_events.clear()
			state.event_start_times.clear()
		
		# 优化5: 只在需要时重新排序（避免不必要的数组操作）
		if sequence_resource.random_order:
			_shuffle_sequence_items()
			
		var loop_end_time = Time.get_ticks_msec() / 1000.0
		var loop_overhead = loop_end_time - loop_start_time
		
		# 优化6: 减少调试输出，只在必要时输出
		if loop_overhead > 0.01:  # 只在开销超过10ms时输出警告
			print("JuicySequenceDriver: [PERF] Loop transition overhead: ", loop_overhead, "s")

# =============================================================================
# 事件同步框架
# =============================================================================

# 检查项目触发条件
func _check_item_trigger_condition(context: JuicyContext, item: JuicySequenceItem, state: SequenceState) -> bool:
	match item.trigger_mode:
		JuicySequenceItem.TriggerMode.TIME:
			return true  # 时间触发总是满足条件
		
		JuicySequenceItem.TriggerMode.EVENT:
			# 检查是否已经等待这个事件
			if state.waiting_events.has(state.current_index):
				# 检查事件是否已经触发
				return _has_event_triggered(item.trigger_event, context)
			else:
				# 开始等待事件
				state.waiting_events[state.current_index] = item.trigger_event
				state.event_start_times[state.current_index] = Time.get_ticks_msec() / 1000.0
				print("JuicySequenceDriver: Started waiting for event '", item.trigger_event, "' at index ", state.current_index)
				return false
	
	return false

# 检查事件是否已触发
func _has_event_triggered(event_name: String, context: JuicyContext) -> bool:
	# 获取序列状态
	var state = _sequence_states.get(context.context_id)
	if not state:
		return false
	
	# 检查事件是否在已触发事件列表中
	if state.triggered_events is Array:
		if event_name in state.triggered_events:
			return true
	
	# 通过事件系统检查事件是否已处理
	var pipeline = JuicyMixer.get_middleware_pipeline()
	if pipeline:
		var event_middleware = pipeline.get_middleware("EventHandlingMiddleware")
		if event_middleware and event_middleware is EventHandlingMiddleware:
			# 检查事件缓冲区中是否有匹配的事件
			if event_middleware._event_buffer:
				var ready_events = event_middleware._event_buffer.get_ready_events()
				for event in ready_events:
					if event and event.event_name == event_name:
						# 找到匹配的事件，将其标记为已触发
						if not event_name in state.triggered_events:
							state.triggered_events.append(event_name)
						return true
	
	return false

# 处理待处理事件
func _process_pending_events(state: SequenceState) -> void:
	"""处理事件缓冲区中的事件，更新序列状态的触发事件列表"""
	var pipeline = JuicyMixer.get_middleware_pipeline()
	if not pipeline:
		return
	
	var event_middleware = pipeline.get_middleware("EventHandlingMiddleware")
	if not event_middleware or not event_middleware is EventHandlingMiddleware:
		return
	
	if not event_middleware._event_buffer:
		return
	
	# 获取所有事件（包括立即、延迟和持久事件）
	var all_events = []
	all_events.append_array(event_middleware._event_buffer._event_queue)
	all_events.append_array(event_middleware._event_buffer._delayed_events)
	all_events.append_array(event_middleware._event_buffer._persistent_events)
	
	for event in all_events:
		if event and event.event_name:
			if not event.event_name in state.triggered_events:
				state.triggered_events.append(event.event_name)

# 处理事件处理器
func _process_event_handlers(context: JuicyContext, state: SequenceState) -> void:
	"""手动触发事件处理器来处理事件缓冲区中的事件"""
	var pipeline = JuicyMixer.get_middleware_pipeline()
	if not pipeline:
		return
	
	var event_middleware = pipeline.get_middleware("EventHandlingMiddleware")
	if not event_middleware or not event_middleware is EventHandlingMiddleware:
		return
	
	if not event_middleware._event_scheduler:
		return
	
	# 获取事件调度器并手动处理事件
	var scheduler = event_middleware._event_scheduler
	var ready_events = []
	
	# 从缓冲区获取就绪事件
	if event_middleware._event_buffer:
		ready_events = event_middleware._event_buffer.get_ready_events()
	
	# 手动处理每个就绪事件
	for event in ready_events:
		if event and event.event_name:
			# 查找匹配的事件处理器
			for event_name in state.event_handlers.keys():
				if event.event_name == event_name:
					var handler_name = state.event_handlers[event_name]
					var handler = scheduler.get_handler(handler_name)
					if handler:
						print("JuicySequenceDriver: Manually processing event with handler: ", handler_name)
						handler.handle_event(event)

# 检查事件超时 - 优化版本
func _check_event_timeouts(state: SequenceState) -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# 检查等待的事件是否超时
	for item_index in state.event_start_times.keys():
		var start_time = state.event_start_times[item_index]
		var elapsed_time = current_time - start_time
		
		if elapsed_time > sequence_resource.event_timeout:
			# 事件超时，跳过该项
			var event_name = state.waiting_events.get(item_index, "unknown")
			print("JuicySequenceDriver: [OPTIMIZED] Event timeout for item " + str(item_index) + " (event: " + event_name + ") after " + str(elapsed_time) + "s")
			
			# 从等待列表中移除
			state.waiting_events.erase(item_index)
			state.event_start_times.erase(item_index)
			
			# 将当前索引标记为完成，并移动到下一项
			if not item_index in state.completed_items:
				state.completed_items.append(item_index)
				
				# 如果是当前项正在等待，则跳过它
				if state.current_index == item_index:
					_move_to_next_item(state)

# 注册事件监听器
func _register_event_listeners(context: JuicyContext, state: SequenceState) -> void:
	var pipeline = JuicyMixer.get_middleware_pipeline()
	if not pipeline:
		push_warning("JuicySequenceDriver: Middleware pipeline not found")
		return
	
	var event_middleware = pipeline.get_middleware("EventHandlingMiddleware")
	if not event_middleware or not event_middleware is EventHandlingMiddleware:
		push_warning("JuicySequenceDriver: EventHandlingMiddleware not found")
		return
	
	# 为每个全局事件监听器注册序列事件处理器
	for event_name in sequence_resource.global_event_listeners:
		# 创建序列事件处理器
		var handler = JuicySequenceEventHandler.new()
		var handler_name = "SequenceEventHandler_" + context.context_id + "_" + event_name
		handler.handler_name = handler_name
		handler.configure({
			"target_event_name": event_name,
			"sequence_context_id": context.context_id,
			"sequence_state": state,
			"sequence_event_type": JuicySequenceEventHandler.SequenceEventType.CUSTOM_EVENT
		})
		
		# 记录处理器映射
		state.event_handlers[event_name] = handler_name
		
		# 注册到事件调度器
		if event_middleware.register_event_handler(handler, 100):  # 高优先级
			print("JuicySequenceDriver: Registered event listener for: " + event_name)
		else:
			push_error("JuicySequenceDriver: Failed to register event listener for: " + event_name)
	
	# 联觉系统：发送序列开始事件
	_emit_sequence_event(context, JuicySequenceEventHandler.SequenceEventType.SEQUENCE_STARTED, -1)

# 注销事件监听器
func _unregister_event_listeners(context: JuicyContext) -> void:
	var state = _sequence_states.get(context.context_id)
	if not state:
		return
	
	var pipeline = JuicyMixer.get_middleware_pipeline()
	if not pipeline:
		return
	
	var event_middleware = pipeline.get_middleware("EventHandlingMiddleware")
	if not event_middleware or not event_middleware is EventHandlingMiddleware:
		return
	
	# 注销所有序列事件处理器
	for event_name in state.event_handlers.keys():
		var handler_name = state.event_handlers[event_name]
		if event_middleware.unregister_event_handler(handler_name):
			print("JuicySequenceDriver: Unregistered event listener for: " + event_name)
	
	# 清空处理器映射
	state.event_handlers.clear()

# 发送序列事件
func _emit_sequence_event(context: JuicyContext, event_type: JuicySequenceEventHandler.SequenceEventType, item_index: int = -1) -> void:
	"""发送序列相关事件"""
	var event = JuicyEvent.new(JuicyEvent.EventType.CUSTOM_EVENT)
	event.context_id = context.context_id
	event.target = context.target
	event.event_name = _get_sequence_event_name(event_type)
	event.event_data = {
		"sequence_event_type": event_type,
		"context_id": context.context_id,
		"item_index": item_index,
		"timestamp": Time.get_ticks_msec() / 1000.0
	}
	
	# 将事件添加到事件系统
	var pipeline = JuicyMixer.get_middleware_pipeline()
	if pipeline:
		var event_middleware = pipeline.get_middleware("EventHandlingMiddleware")
		if event_middleware and event_middleware is EventHandlingMiddleware:
			if event_middleware._event_buffer:
				event_middleware._event_buffer.add_event(event)
				print("JuicySequenceDriver: Emitted sequence event: " + event.event_name)

func _get_sequence_event_name(event_type: JuicySequenceEventHandler.SequenceEventType) -> String:
	"""获取序列事件名称"""
	match event_type:
		JuicySequenceEventHandler.SequenceEventType.SEQUENCE_STARTED:
			return "sequence_started"
		JuicySequenceEventHandler.SequenceEventType.SEQUENCE_COMPLETED:
			return "sequence_completed"
		JuicySequenceEventHandler.SequenceEventType.SEQUENCE_ITEM_STARTED:
			return "sequence_item_started"
		JuicySequenceEventHandler.SequenceEventType.SEQUENCE_ITEM_COMPLETED:
			return "sequence_item_completed"
		JuicySequenceEventHandler.SequenceEventType.SEQUENCE_LOOPED:
			return "sequence_looped"
		JuicySequenceEventHandler.SequenceEventType.SEQUENCE_INTERRUPTED:
			return "sequence_interrupted"
		JuicySequenceEventHandler.SequenceEventType.SEQUENCE_RESUMED:
			return "sequence_resumed"
		_:
			return "custom_sequence_event"

# 随机排序序列项 - 修复Godot 4泛型数组问题
func _shuffle_sequence_items() -> void:
	if not sequence_resource:
		return
		
	var items = sequence_resource.get("sequence_items")
	if items.is_empty():
		return
	
	# 修复：使用临时变量而不是直接调用swap方法
	for i in range(items.size() - 1, 0, -1):
		var j = randi() % (i + 1)
		var temp = items[i]
		items[i] = items[j]
		items[j] = temp

# =============================================================================
# 工具方法
# =============================================================================

# 检查是否应该执行项
func _should_execute_item(item: JuicySequenceItem, context: JuicyContext) -> bool:
	if not item.enabled or not item.resource:
		return false
	
	if not item.condition.is_empty():
		# 这里可以添加条件表达式解析逻辑
		# 例如：return context.evaluate_expression(item.condition)
		pass
	
	return true

# =============================================================================
# 并行执行专用函数
# =============================================================================

# 并行延迟处理函数
func _handle_parallel_delay_timing(context: JuicyContext, state: SequenceState, item: JuicySequenceItem, item_index: int) -> bool:
	# 如果延迟为0或负数，立即执行
	if item.delay <= 0.0:
		state.parallel_delay_completed[item_index] = true
		print("JuicySequenceDriver: [PARALLEL] Zero delay for item ", item_index, ", executing immediately")
		return true
	
	# 如果延迟已完成，直接返回true
	if state.parallel_delay_completed.get(item_index, false):
		return true
	
	# 如果Timer还未创建，创建并启动Timer
	if not state.parallel_delay_timers.has(item_index):
		_create_parallel_delay_timer(context, state, item, item_index)
		return false  # Timer刚开始，等待
	
	# 检查Timer是否仍在运行
	var timer = state.parallel_delay_timers.get(item_index)
	if timer and timer.time_left > 0.001:  # 添加小的容差值
		return false  # 延迟未完成，继续等待
	
	# Timer已完成或已清理，执行项目
	if timer == null:
		# Timer已经被清理，说明延迟已完成
		print("JuicySequenceDriver: [PARALLEL] Delay completed for item ", item_index, " after ", item.delay, "s")
		return true
	
	# Timer存在但time_left为0或接近0，说明刚完成，清理并执行
	_cleanup_parallel_delay_timer(state, item_index)
	print("JuicySequenceDriver: [PARALLEL] Delay completed for item ", item_index, " after ", item.delay, "s")
	return true  # 延迟完成，可以执行

# 创建并行延迟Timer
func _create_parallel_delay_timer(context: JuicyContext, state: SequenceState, item: JuicySequenceItem, item_index: int) -> void:
	# 确保清理之前的Timer
	_cleanup_parallel_delay_timer(state, item_index)
	
	# 优化：对于0延迟，跳过Timer创建，直接标记完成
	if item.delay <= 0.0:
		state.parallel_delay_completed[item_index] = true
		print("JuicySequenceDriver: [PARALLEL] Zero delay for item ", item_index, ", skipping timer creation")
		return
	
	# 创建Timer节点
	var timer = Timer.new()
	timer.wait_time = item.delay
	timer.one_shot = true
	timer.timeout.connect(_on_parallel_delay_timer_completed.bind(context, state, item_index))
	
	# 优化：直接获取场景树根节点，避免多层查找开销
	var scene_tree = Engine.get_main_loop() as SceneTree
	if scene_tree and scene_tree.current_scene:
		scene_tree.current_scene.add_child(timer)
	else:
		push_warning("JuicySequenceDriver: Cannot find scene tree to add parallel timer")
		return
	
	# 立即启动Timer
	timer.start()
	state.parallel_delay_timers[item_index] = timer
	
	print("JuicySequenceDriver: [PARALLEL] Created delay timer for item ", item_index, " (", item.delay, "s)")

# 并行Timer完成回调
func _on_parallel_delay_timer_completed(context: JuicyContext, state: SequenceState, item_index: int) -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	# 标记延迟已完成
	state.parallel_delay_completed[item_index] = true
	# 立即清理Timer
	_cleanup_parallel_delay_timer(state, item_index)
	
	print("JuicySequenceDriver: [PARALLEL] Delay timer completed for item ", item_index, " at ", current_time)

# 清理并行延迟Timer
func _cleanup_parallel_delay_timer(state: SequenceState, item_index: int) -> void:
	if state.parallel_delay_timers.has(item_index):
		var timer = state.parallel_delay_timers[item_index]
		if timer and timer.is_inside_tree():
			timer.queue_free()
		state.parallel_delay_timers.erase(item_index)

# 并行事件触发条件检查
func _check_item_trigger_condition_for_parallel(context: JuicyContext, item: JuicySequenceItem, state: SequenceState, item_index: int) -> bool:
	match item.trigger_mode:
		JuicySequenceItem.TriggerMode.TIME:
			return true  # 时间触发总是满足条件
		
		JuicySequenceItem.TriggerMode.EVENT:
			# 检查是否已经等待这个事件
			if state.waiting_events.has(item_index):
				# 检查事件是否已经触发
				return _has_event_triggered(item.trigger_event, context)
			else:
				# 开始等待事件
				state.waiting_events[item_index] = item.trigger_event
				state.event_start_times[item_index] = Time.get_ticks_msec() / 1000.0
				print("JuicySequenceDriver: [PARALLEL] Started waiting for event '", item.trigger_event, "' at index ", item_index)
				return false
	
	return false

# 执行并行序列项
func _execute_parallel_sequence_item(context: JuicyContext, item: JuicySequenceItem, state: SequenceState, item_index: int) -> void:
	if not item:
		push_error("JuicySequenceDriver: Cannot execute null item")
		return
		
	if not item.enabled:
		return
		
	if not item.resource:
		push_warning("JuicySequenceDriver: Item has no resource assigned")
		return
	
	# 验证资源配置
	var validation_result = item.resource.validate_config()
	if not validation_result.valid:
		push_error("JuicySequenceDriver: Item resource validation failed: " + str(validation_result.issues))
		return
	
	# 如果序列项指定了持续时间且资源是JuicyShakeResource，则更新ShakeData的duration
	if item.duration > 0.0 and item.resource is JuicyShakeResource:
		var shake_resource = item.resource as JuicyShakeResource
		for shake_data in shake_resource.shake_data:
			if shake_data and shake_data.duration != item.duration:
				print("JuicySequenceDriver: [PARALLEL] Updating shake duration from ", shake_data.duration, " to ", item.duration)
				shake_data.duration = item.duration
	
	# 优化：直接播放并内联上下文创建逻辑
	var context_id = JuicyMixer.play(item.resource, context.target)
	if context_id:
		state.active_contexts.append(context_id)
		state.parallel_items_executed.append(item_index)
		
		# 优化：内联上下文创建逻辑，减少函数调用开销
		var item_context = JuicyMixer.get_context(context_id)
		if item_context:
			item_context.time_scale = context.time_scale
			item_context.item_index = item_index
	else:
		push_error("JuicySequenceDriver: Failed to play item resource")

# 创建并行子上下文 - 保留用于向后兼容，但不再在主要路径中使用
func _create_parallel_item_context(parent_context: JuicyContext, item: JuicySequenceItem, item_index: int) -> JuicyContext:
	if not item or not item.resource:
		push_error("JuicySequenceDriver: Cannot create context for null item or resource")
		return null
		
	var item_context = JuicyContext.create(item.resource, parent_context.target, parent_context.owner)
	if item_context:
		item_context.time_scale = parent_context.time_scale
		# 为并行项设置索引标识
		item_context.item_index = item_index
	return item_context

# =============================================================================
# 工具方法
# =============================================================================

# 创建子上下文 - 保留用于向后兼容，但不再在主要路径中使用
func _create_item_context(parent_context: JuicyContext, item: JuicySequenceItem) -> JuicyContext:
	if not item or not item.resource:
		push_error("JuicySequenceDriver: Cannot create context for null item or resource")
		return null
		
	var item_context = JuicyContext.create(item.resource, parent_context.target, parent_context.owner)
	if item_context:
		item_context.time_scale = parent_context.time_scale
	return item_context
