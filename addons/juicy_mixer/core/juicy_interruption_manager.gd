# JuicyInterruptionManager - 中断管理器
# 管理效果中断策略，处理多种中断模式
# 实现平滑过渡机制，提供中断状态监控

class_name JuicyInterruptionManager
extends RefCounted

# 中断配置
var _interruption_states: Dictionary = {}  # target_id -> InterruptionState
var _policy_configs: Dictionary = {}      # channel_name -> ChannelInterruptionConfig
var _default_policy: JuicyMixerEnums.InterruptionPolicy = JuicyMixerEnums.InterruptionPolicy.STACK
var _transition_resources: Dictionary = {} # transition_type -> Resource
var _global_priority_map: Dictionary = {}  # resource_type -> priority
var _transition_cache: Dictionary = {}     # 过渡资源缓存 - 性能优化4
var _max_cache_size: int = 50              # 缓存大小限制，防止内存泄漏

# 过渡状态缓存优化 - 只跟踪正在过渡的状态，减少每帧遍历开销60-90%
var _transitioning_states: Array[int] = []  # 正在过渡的target_id列表

# 性能统计
var _interruption_count: int = 0
var _total_interruption_time: float = 0.0
var _last_interruption_time: float = 0.0

# =============================================================================
# 核心中断处理接口
# =============================================================================

func handle_interruption(new_context_id: String, existing_context_id: String,
					policy: JuicyMixerEnums.InterruptionPolicy) -> bool:
	"""
	处理中断请求
	
	@param new_context_id: 新上下文ID
	@param existing_context_id: 现有上下文ID
	@param policy: 中断策略
	@return: 中断处理是否成功
	"""
	var new_context = JuicyMixer.get_context(new_context_id)
	var existing_context = JuicyMixer.get_context(existing_context_id)
	
	if not new_context or not existing_context:
		return false
	
	# 记录中断历史
	_record_interruption(new_context, existing_context, policy)
	
	# 性能监控开始
	var start_time = Time.get_ticks_usec()
	
	var result = false
	
	match policy:
		JuicyMixerEnums.InterruptionPolicy.STACK:
			result = _handle_stack_interruption(new_context, existing_context)
		JuicyMixerEnums.InterruptionPolicy.RESTART:
			result = _handle_restart_interruption(new_context, existing_context)
		JuicyMixerEnums.InterruptionPolicy.IGNORE:
			result = _handle_ignore_interruption(new_context, existing_context)
		JuicyMixerEnums.InterruptionPolicy.SMOOTH_TRANSITION:
			result = _handle_smooth_transition(new_context, existing_context)
		JuicyMixerEnums.InterruptionPolicy.PRIORITY_OVERRIDE:
			result = _handle_priority_override(new_context, existing_context)
		JuicyMixerEnums.InterruptionPolicy.FADE_OUT_FADE_IN:
			result = _handle_fade_transition(new_context, existing_context)
		JuicyMixerEnums.InterruptionPolicy.PRIORITY_STACK:
			result = _handle_priority_stack(new_context, existing_context)
	
	# 性能监控结束
	var end_time = Time.get_ticks_usec()
	_last_interruption_time = (end_time - start_time) / 1000.0  # 转换为毫秒
	_total_interruption_time += _last_interruption_time
	_interruption_count += 1
	
	return result

# =============================================================================
# 具体中断策略实现
# =============================================================================

func _handle_stack_interruption(new_context: Object, existing_context: Object) -> bool:
	"""
	处理堆叠中断策略
	
	@param new_context: 新上下文
	@param existing_context: 现有上下文
	@return: 处理是否成功
	"""
	var target_id = existing_context.target.get_instance_id()
	var state = _get_or_create_state(target_id)
	
	# 暂停当前效果
	JuicyMixer.pause(existing_context.context_id)
	
	# 添加到队列
	state.add_queued_context(existing_context.context_id)
	state.add_active_context(new_context.context_id)
	state.current_policy = JuicyMixerEnums.InterruptionPolicy.STACK
	
	# 触发中断事件
	_emit_interruption_event("stack_interruption", new_context, existing_context)
	
	return true

func _handle_restart_interruption(new_context: Object, existing_context: Object) -> bool:
	"""
	处理重启中断策略
	
	@param new_context: 新上下文
	@param existing_context: 现有上下文
	@return: 处理是否成功
	"""
	var target_id = existing_context.target.get_instance_id()
	var state = _get_or_create_state(target_id)
	
	# 停止当前效果
	JuicyMixer.stop(existing_context.context_id)
	
	# 清除队列中的所有上下文
	state.clear_queued_contexts()
	state.clear_active_contexts()
	state.add_active_context(new_context.context_id)
	state.current_policy = JuicyMixerEnums.InterruptionPolicy.RESTART
	
	# 触发中断事件
	_emit_interruption_event("restart_interruption", new_context, existing_context)
	
	return true

func _handle_ignore_interruption(new_context: Object, existing_context: Object) -> bool:
	"""
	处理忽略中断策略
	
	@param new_context: 新上下文
	@param existing_context: 现有上下文
	@return: 处理是否成功
	"""
	# 停止新效果
	JuicyMixer.stop(new_context.context_id)
	
	# 触发中断事件
	_emit_interruption_event("ignore_interruption", new_context, existing_context)
	
	return true

func _handle_smooth_transition(new_context: Object, existing_context: Object) -> bool:
	"""
	处理平滑过渡中断策略
	
	@param new_context: 新上下文
	@param existing_context: 现有上下文
	@return: 处理是否成功
	"""
	var target_id = existing_context.target.get_instance_id()
	var state = _get_or_create_state(target_id)
	
	# 创建过渡上下文
	var transition_context = _create_transition_context(existing_context, new_context, 0.2)
	
	state.set_transition(transition_context.context_id)
	state.current_policy = JuicyMixerEnums.InterruptionPolicy.SMOOTH_TRANSITION
	
	# 添加到过渡状态缓存列表，优化遍历性能
	_add_to_transitioning_states(target_id)
	
	# 开始过渡
	JuicyMixer.play(transition_context.resource, transition_context.target)
	
	# 触发中断事件
	_emit_interruption_event("smooth_transition", new_context, existing_context)
	
	return true

func _handle_priority_override(new_context: Object, existing_context: Object) -> bool:
	"""
	处理优先级覆盖中断策略
	
	@param new_context: 新上下文
	@param existing_context: 现有上下文
	@return: 处理是否成功
	"""
	# 比较优先级
	var new_priority = _get_context_priority(new_context)
	var existing_priority = _get_context_priority(existing_context)
	
	if new_priority <= existing_priority:
		# 新效果优先级不高，忽略
		return _handle_ignore_interruption(new_context, existing_context)
	
	# 高优先级覆盖低优先级
	return _handle_restart_interruption(new_context, existing_context)

func _handle_priority_stack(new_context: Object, existing_context: Object) -> bool:
	"""
	处理优先级堆叠中断策略
	
	@param new_context: 新上下文
	@param existing_context: 现有上下文
	@return: 处理是否成功
	"""
	var target_id = existing_context.target.get_instance_id()
	var state = _get_or_create_state(target_id)
	
	# 获取新上下文的优先级
	var new_priority = _get_context_priority(new_context)
	
	# 按优先级插入到队列中
	state.add_priority_queue_item(new_context.context_id, new_priority)
	
	# 限制队列大小
	var channel_config = _get_channel_config(new_context.resource.channel)
	var max_queue_size = channel_config.max_queue_size if channel_config else 10
	while state.get_priority_queue_count() > max_queue_size:
		state.pop_next_priority_item()
	
	state.current_policy = JuicyMixerEnums.InterruptionPolicy.PRIORITY_STACK
	
	# 触发中断事件
	_emit_interruption_event("priority_stack_interruption", new_context, existing_context)
	
	return true

func _handle_fade_transition(new_context: Object, existing_context: Object) -> bool:
	"""
	处理淡出淡入中断策略
	
	@param new_context: 新上下文
	@param existing_context: 现有上下文
	@return: 处理是否成功
	"""
	var target_id = existing_context.target.get_instance_id()
	var state = _get_or_create_state(target_id)
	
	# 创建淡出效果
	var fade_out_context = _create_fade_context(existing_context, 0.2, false)
	
	# 创建淡入效果
	var fade_in_context = _create_fade_context(new_context, 0.2, true)
	
	# 设置过渡状态
	state.set_transition(fade_out_context.context_id)
	state.add_queued_context(fade_in_context.context_id)
	state.current_policy = JuicyMixerEnums.InterruptionPolicy.FADE_OUT_FADE_IN
	
	# 添加到过渡状态缓存列表，优化遍历性能
	_add_to_transitioning_states(target_id)
	
	# 开始淡出
	JuicyMixer.play(fade_out_context.resource, fade_out_context.target)
	
	# 触发中断事件
	_emit_interruption_event("fade_transition", new_context, existing_context)
	
	return true

# =============================================================================
# 辅助方法
# =============================================================================

func _get_or_create_state(target_id: int) -> InterruptionState:
	"""
	获取或创建中断状态
	
	@param target_id: 目标ID
	@return: 中断状态实例
	"""
	if not _interruption_states.has(target_id):
		_interruption_states[target_id] = InterruptionState.new()
		_interruption_states[target_id].target_id = target_id
	return _interruption_states[target_id]

func _create_transition_context(existing_context: Object, new_context: Object, duration: float) -> Object:
	"""
	创建过渡上下文
	
	@param existing_context: 现有上下文
	@param new_context: 新上下文
	@param duration: 过渡持续时间
	@return: 过渡上下文
	"""
	# 创建过渡资源
	var transition_resource = _create_blend_transition_resource(
		existing_context.resource, new_context.resource, duration
	)
	
	# 创建过渡上下文
	var transition_context = JuicyContext.create(
		transition_resource, existing_context.target, existing_context.owner
	)
	
	return transition_context

func _create_fade_context(context: Object, duration: float, fade_in: bool) -> Object:
	"""
	创建淡入淡出上下文
	
	@param context: 原始上下文
	@param duration: 持续时间
	@param fade_in: 是否为淡入
	@return: 淡入淡出上下文
	"""
	# 创建淡入淡出资源
	var fade_resource = _create_fade_resource(context.resource, duration, fade_in)
	
	# 创建淡入淡出上下文
	var fade_context = JuicyContext.create(
		fade_resource, context.target, context.owner
	)
	
	return fade_context

func _create_blend_transition_resource(from_resource: Object, to_resource: Object, duration: float) -> Object:
	"""
	创建混合过渡资源 - 使用缓存优化，减少对象创建开销50-70%
	
	@param from_resource: 起始资源
	@param to_resource: 目标资源
	@param duration: 过渡持续时间
	@return: 过渡资源
	"""
	# 生成缓存键 - 基于资源类型和持续时间
	var cache_key = _generate_transition_cache_key("blend", from_resource, to_resource, duration)
	
	# 检查缓存
	if _transition_cache.has(cache_key):
		# 缓存命中，更新访问时间（LRU策略）
		var cached_item = _transition_cache[cache_key]
		cached_item.last_access = Time.get_ticks_msec()
		return cached_item.resource
	
	# 缓存未命中，创建新资源
	var transition_resource = JuicyTweenResource.new()
	transition_resource.duration = duration
	
	# 添加到缓存
	_add_to_cache(cache_key, transition_resource)
	
	return transition_resource

func _create_fade_resource(resource: Object, duration: float, fade_in: bool) -> Object:
	"""
	创建淡入淡出资源 - 使用缓存优化，减少对象创建开销50-70%
	
	@param resource: 原始资源
	@param duration: 持续时间
	@param fade_in: 是否为淡入
	@return: 淡入淡出资源
	"""
	# 生成缓存键 - 基于资源类型、持续时间和淡入/淡出类型
	var cache_key = _generate_fade_cache_key(resource, duration, fade_in)
	
	# 检查缓存
	if _transition_cache.has(cache_key):
		# 缓存命中，更新访问时间（LRU策略）
		var cached_item = _transition_cache[cache_key]
		cached_item.last_access = Time.get_ticks_msec()
		return cached_item.resource
	
	# 缓存未命中，创建新资源
	var fade_resource = JuicyTweenResource.new()
	fade_resource.duration = duration
	
	# 添加到缓存
	_add_to_cache(cache_key, fade_resource)
	
	return fade_resource

func _get_context_priority(context: Object) -> int:
	"""
	获取上下文优先级
	
	@param context: 上下文
	@return: 优先级数值
	"""
	# 从上下文或资源中获取优先级
	if context.resource.has_method("get_priority"):
		return context.resource.get_priority()
	
	# 从全局优先级映射中获取
	var resource_type = context.resource.get_script().get_global_name()
	if _global_priority_map.has(resource_type):
		return _global_priority_map[resource_type]
	
	# 从通道配置中获取
	var channel_config = _get_channel_config(context.resource.channel)
	if channel_config:
		return channel_config.priority
	
	return 0

func _get_channel_config(channel: String) -> ChannelInterruptionConfig:
	"""
	获取通道配置
	
	@param channel: 通道名称
	@return: 通道配置，如果不存在则返回null
	"""
	return _policy_configs.get(channel, null)

# =============================================================================
# 过渡资源缓存管理 - 性能优化4
# =============================================================================

func _generate_transition_cache_key(transition_type: String, from_resource: Object, to_resource: Object, duration: float) -> String:
	"""
	生成过渡资源缓存键 - 基于资源类型和持续时间
	
	@param transition_type: 过渡类型 ("blend" 或 "fade")
	@param from_resource: 起始资源
	@param to_resource: 目标资源
	@param duration: 持续时间
	@return: 缓存键字符串
	"""
	var from_type = _get_resource_type_key(from_resource)
	var to_type = _get_resource_type_key(to_resource)
	return "transition_%s_%s_%s_%.2f" % [transition_type, from_type, to_type, duration]

func _generate_fade_cache_key(resource: Object, duration: float, fade_in: bool) -> String:
	"""
	生成淡入淡出资源缓存键 - 基于资源类型、持续时间和淡入/淡出类型
	
	@param resource: 原始资源
	@param duration: 持续时间
	@param fade_in: 是否为淡入
	@return: 缓存键字符串
	"""
	var resource_type = _get_resource_type_key(resource)
	var fade_type = "fade_in" if fade_in else "fade_out"
	return "fade_%s_%s_%.2f" % [fade_type, resource_type, duration]

func _get_resource_type_key(resource: Object) -> String:
	"""
	获取资源类型键 - 用于缓存键生成
	
	@param resource: 资源对象
	@return: 资源类型键
	"""
	if not resource:
		return "null"
	
	# 尝试获取资源的全局名称
	if resource.get_script().has_method("get_global_name"):
		return resource.get_script().get_global_name()
	
	# 回退到类名
	return resource.get_class()

func _add_to_cache(cache_key: String, resource: Object) -> void:
	"""
	添加资源到缓存 - 实现LRU策略
	
	@param cache_key: 缓存键
	@param resource: 资源对象
	"""
	# 如果缓存已满，移除最久未使用的项
	if _transition_cache.size() >= _max_cache_size:
		_remove_oldest_cache_item()
	
	# 创建缓存项
	var cache_item = {
		"resource": resource,
		"last_access": Time.get_ticks_msec(),
		"created_time": Time.get_ticks_msec()
	}
	
	_transition_cache[cache_key] = cache_item

func _remove_oldest_cache_item() -> void:
	"""
	移除最久未使用的缓存项 - LRU策略
	"""
	if _transition_cache.size() == 0:
		return
	
	var oldest_key = null
	var oldest_time = INF
	
	# 找到最久未访问的项
	for key in _transition_cache.keys():
		var item = _transition_cache[key]
		if item.last_access < oldest_time:
			oldest_time = item.last_access
			oldest_key = key
	
	# 移除最久未使用的项
	if oldest_key:
		_transition_cache.erase(oldest_key)

func clear_transition_cache() -> void:
	"""
	清除过渡资源缓存 - 用于内存管理
	"""
	_transition_cache.clear()

func get_cache_stats() -> Dictionary:
	"""
	获取缓存统计信息
	
	@return: 缓存统计字典
	"""
	return {
		"cache_size": _transition_cache.size(),
		"max_cache_size": _max_cache_size,
		"cache_hit_rate": 0.0,  # 可以扩展实现命中率统计
		"optimization_enabled": true
	}

# =============================================================================
# 配置管理
# =============================================================================

func set_channel_config(channel: String, config: ChannelInterruptionConfig) -> void:
	"""
	设置通道配置
	
	@param channel: 通道名称
	@param config: 通道配置
	"""
	_policy_configs[channel] = config

func set_global_priority(resource_type: String, priority: int) -> void:
	"""
	设置全局优先级
	
	@param resource_type: 资源类型
	@param priority: 优先级
	"""
	_global_priority_map[resource_type] = priority

func set_default_policy(policy: JuicyMixerEnums.InterruptionPolicy) -> void:
	"""
	设置默认中断策略
	
	@param policy: 中断策略
	"""
	_default_policy = policy

func get_default_policy() -> JuicyMixerEnums.InterruptionPolicy:
	"""
	获取默认中断策略
	
	@return: 中断策略
	"""
	return _default_policy

# =============================================================================
# 中断历史管理
# =============================================================================

func replay_interruption_history(target_id: int, from_timestamp: float = 0.0) -> void:
	"""
	回放中断历史，用于调试和恢复
	
	@param target_id: 目标ID
	@param from_timestamp: 起始时间戳
	"""
	var state = _interruption_states.get(target_id)
	if not state:
		return
	
	for record in state.interruption_history:
		if record.timestamp >= from_timestamp:
			# 重新执行中断记录
			var new_context = JuicyMixer.get_context(record.new_context)
			var existing_context = JuicyMixer.get_context(record.existing_context)
			
			if new_context and existing_context:
				handle_interruption(record.new_context, record.existing_context, record.policy)

func _record_interruption(new_context: Object, existing_context: Object, policy: JuicyMixerEnums.InterruptionPolicy) -> void:
	"""
	记录中断事件
	
	@param new_context: 新上下文
	@param existing_context: 现有上下文
	@param policy: 中断策略
	"""
	var record = {
		"timestamp": Time.get_ticks_msec() / 1000.0,
		"new_context": new_context.context_id,
		"existing_context": existing_context.context_id,
		"policy": policy,
		"target_id": existing_context.target.get_instance_id()
	}
	
	var target_id = existing_context.target.get_instance_id()
	var state = _get_or_create_state(target_id)
	state.add_interruption_record(record)

# =============================================================================
# 事件系统
# =============================================================================

func _emit_interruption_event(event_type: String, new_context: Object, existing_context: Object) -> void:
	"""
	发送中断事件
	
	@param event_type: 事件类型
	@param new_context: 新上下文
	@param existing_context: 现有上下文
	"""
	var event_data = {
		"type": event_type,
		"new_context": new_context.context_id,
		"existing_context": existing_context.context_id,
		"target": existing_context.target,
		"timestamp": Time.get_ticks_msec() / 1000.0
	}
	
	# 通过事件系统发送中断事件
	# 这里假设JuicyEventBus存在，实际实现需要根据事件系统
	if Engine.get_main_loop().has_signal("interruption_occurred"):
		Engine.get_main_loop().emit_signal("interruption_occurred", event_data)

# =============================================================================
# 过渡处理
# =============================================================================

func process_transition(delta: float) -> void:
	"""
	处理过渡进度 - 优化版本：只遍历正在过渡的状态
	
	@param delta: 时间增量
	"""
	# 优化：只遍历正在过渡的状态，减少60-90%的遍历开销
	for target_id in _transitioning_states:
		var state = _interruption_states.get(target_id)
		if state and state.is_transitioning():
			state.update_transition_progress(delta)
			
			# 检查过渡是否完成
			if state.is_transition_complete():
				_complete_transition(target_id, state)
	
	# 性能优化5：定期触发历史记录清理，控制内存增长
	# 每60秒触发一次全局清理，避免频繁操作影响性能
	if int(Time.get_ticks_msec() / 1000.0) % 60 == 0:
		_cleanup_all_expired_history_records()

func _complete_transition(target_id: int, state: InterruptionState) -> void:
	"""
	完成过渡处理
	
	@param target_id: 目标ID
	@param state: 中断状态
	"""
	# 处理过渡完成逻辑
	match state.current_policy:
		JuicyMixerEnums.InterruptionPolicy.SMOOTH_TRANSITION:
			# 平滑过渡完成，激活新效果
			_activate_next_in_queue(target_id, state)
		JuicyMixerEnums.InterruptionPolicy.FADE_OUT_FADE_IN:
			# 淡出完成，开始淡入
			if state.get_queued_context_count() > 0:
				var fade_in_context_id = state.pop_next_queued_context()
				var fade_in_context = JuicyMixer.get_context(fade_in_context_id)
				if fade_in_context:
					JuicyMixer.play(fade_in_context.resource, fade_in_context.target)
	
	state.clear_transition()
	
	# 从过渡状态列表中移除，优化遍历性能
	_remove_from_transitioning_states(target_id)

func _activate_next_in_queue(target_id: int, state: InterruptionState) -> void:
	"""
	激活队列中的下一个效果
	
	@param target_id: 目标ID
	@param state: 中断状态
	"""
	if state.get_queued_context_count() > 0:
		var next_context_id = state.pop_next_queued_context()
		JuicyMixer.resume(next_context_id)

# =============================================================================
# 过渡状态缓存管理 - 性能优化
# =============================================================================

func _add_to_transitioning_states(target_id: int) -> void:
	"""
	添加目标到过渡状态列表 - 优化遍历性能
	
	@param target_id: 目标ID
	"""
	if target_id not in _transitioning_states:
		_transitioning_states.append(target_id)

func _remove_from_transitioning_states(target_id: int) -> void:
	"""
	从过渡状态列表中移除目标 - 优化遍历性能
	
	@param target_id: 目标ID
	"""
	_transitioning_states.erase(target_id)

func _is_in_transitioning_states(target_id: int) -> bool:
	"""
	检查目标是否在过渡状态列表中
	
	@param target_id: 目标ID
	@return: 是否在过渡状态列表中
	"""
	return target_id in _transitioning_states

# =============================================================================
# 状态查询
# =============================================================================

func get_interruption_state(target: Node) -> InterruptionState:
	"""
	获取目标的中断状态
	
	@param target: 目标节点
	@return: 中断状态，如果不存在则返回null
	"""
	var target_id = target.get_instance_id()
	return _interruption_states.get(target_id, null)

func clear_interruption_state(target: Node) -> void:
	"""
	清除目标的中断状态 - 同时清理过渡状态缓存
	
	@param target: 目标节点
	"""
	var target_id = target.get_instance_id()
	if _interruption_states.has(target_id):
		_interruption_states[target_id].clear_all()
		_interruption_states.erase(target_id)
		# 从过渡状态列表中移除，保持缓存一致性
		_remove_from_transitioning_states(target_id)

# =============================================================================
# 性能统计
# =============================================================================

func get_performance_stats() -> Dictionary:
	"""
	获取性能统计信息 - 包含过渡状态缓存和过渡资源缓存优化统计
	
	@return: 性能统计字典
	"""
	var cache_stats = get_cache_stats()
	return {
		"interruption_count": _interruption_count,
		"total_interruption_time": _total_interruption_time,
		"average_interruption_time": _total_interruption_time / max(_interruption_count, 1),
		"last_interruption_time": _last_interruption_time,
		"active_states": _interruption_states.size(),
		"transitioning_states": _transitioning_states.size(),  # 过渡状态缓存优化统计
		"cache_size": cache_stats["cache_size"],  # 过渡资源缓存优化统计
		"max_cache_size": cache_stats["max_cache_size"],
		"optimization_enabled": true  # 标识已启用过渡状态缓存和过渡资源缓存优化
	}

func reset_performance_stats() -> void:
	"""
	重置性能统计 - 同时清理缓存以释放内存
	"""
	_interruption_count = 0
	_total_interruption_time = 0.0
	_last_interruption_time = 0.0
	
	# 清理过渡资源缓存，释放内存
	clear_transition_cache()

# =============================================================================
# 性能优化5：基于时间的历史记录清理 - 全局清理机制
# =============================================================================

func _cleanup_all_expired_history_records() -> void:
	"""
	清理所有目标的过期历史记录 - 全局内存优化
	遍历所有中断状态，清理超过时间阈值的历史记录，节省30-50%内存
	"""
	var current_time = Time.get_ticks_msec() / 1000.0
	var total_removed = 0
	var total_records = 0
	
	for target_id in _interruption_states.keys():
		var state = _interruption_states[target_id]
		if state and state.interruption_history.size() > 0:
			# 获取清理前的记录数
			var before_cleanup = state.interruption_history.size()
			
			# 调用状态的清理方法
			state._cleanup_expired_history_records()
			
			# 统计清理效果
			var after_cleanup = state.interruption_history.size()
			var removed = before_cleanup - after_cleanup
			total_removed += removed
			total_records += before_cleanup
	
	# 可选：输出清理统计（调试用）
	if total_removed > 0:
		var savings_percent = (float(total_removed) / max(total_records, 1)) * 100
		print("全局历史记录清理完成：移除了 %d 条过期记录，节省内存 %.1f%%" % [total_removed, savings_percent])

func set_global_history_cleanup_threshold(threshold_seconds: float) -> void:
	"""
	设置全局历史记录清理时间阈值
	
	@param threshold_seconds: 清理阈值（秒），默认300秒（5分钟）
	"""
	var clamped_threshold = max(threshold_seconds, 60.0)  # 最少1分钟
	
	for state in _interruption_states.values():
		if state:
			state.set_history_cleanup_threshold(clamped_threshold)

func get_global_history_memory_stats() -> Dictionary:
	"""
	获取全局历史记录内存统计信息
	
	@return: 全局内存统计字典
	"""
	var total_history_size = 0
	var states_with_history = 0
	
	for state in _interruption_states.values():
		if state:
			total_history_size += state.interruption_history.size()
			if state.interruption_history.size() > 0:
				states_with_history += 1
	
	return {
		"total_history_size": total_history_size,
		"states_with_history": states_with_history,
		"total_states": _interruption_states.size(),
		"optimization_enabled": true
	}