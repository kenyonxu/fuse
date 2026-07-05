# InterruptionMiddleware - 中断中间件
# 在Director执行流程中处理中断
# 协调不同中断策略的执行，提供中断决策的钩子函数
# 职责：处理所有中断相关的决策和逻辑，包括自动停止前一个效果
# 优先级：950（极高优先级，确保在ChannelMiddleware之前执行）
# 优化：使用ContextStateManager进行状态协调，确保状态一致性

class_name InterruptionMiddleware
extends JuicyMiddleware

var _interruption_manager: JuicyInterruptionManager
# 状态协调管理器
var _state_manager: ContextStateManager

# =============================================================================
# 生命周期方法
# =============================================================================

func _init():
	middleware_name = "InterruptionMiddleware"
	priority = 950  # 极高优先级，确保在ChannelMiddleware之前执行中断处理
	description = "Handles effect interruption policies during execution"
	author = "JuicyMixer Team"
	tags = ["interruption", "policy", "priority", "transition"]
	
	# 初始化状态协调管理器
	_state_manager = ContextStateManager.get_instance()

# =============================================================================
# 中间件接口实现
# =============================================================================

func initialize(config: Dictionary = {}) -> bool:
	"""
	初始化中间件
	
	@param config: 配置字典
	@return: 初始化是否成功
	"""
	var result = super.initialize(config)
	if result:
		_interruption_manager = JuicyInterruptionManager.new()
		_setup_default_configuration()
		
		# 验证状态一致性
		_validate_state_consistency()
	return result

func before_play(context: JuicyContext) -> bool:
	"""
	在播放前处理中断逻辑
	
	@param context: 上下文
	@return: 是否允许播放
	"""
	# 只保留中断特定的验证逻辑 - 验证目标节点是否存在
	if not context or not context.target:
		_log_warning("Context or target is null, skipping interruption check")
		return true  # 允许播放，让其他中间件处理这个问题
	
	# 同步Context状态到状态协调器
	_sync_context_to_state_manager(context, "pending")
	
	# 检查是否需要中断现有效果
	var existing_contexts = _get_active_contexts_for_target(context.target)
	
	for existing_context_id in existing_contexts:
		var existing_context = JuicyMixer.get_context(existing_context_id)
		if not existing_context:
			continue
		
		# 确定中断策略
		var policy = _determine_interruption_policy(context, existing_context)
		
		# 处理中断
		var interruption_result = _interruption_manager.handle_interruption(
			context.context_id, existing_context_id, policy
		)
		
		if not interruption_result:
			# 中断处理失败，拒绝播放
			_log_debug("Interruption failed, rejecting play request", {
				"new_context": context.context_id,
				"existing_context": existing_context_id,
				"policy": JuicyMixerEnums.get_interruption_policy_name(policy)
			})
			_sync_context_to_state_manager(context, "rejected")
			return false
		
		# 触发中断事件
		_emit_interruption_event("interruption_occurred", context, existing_context, policy)
	
	# 同步Context状态到状态协调器（状态为active）
	_sync_context_to_state_manager(context, "active")
	
	_log_debug("Interruption check passed", {"context_id": context.context_id})
	return true

func process(context: JuicyContext, next: Callable) -> bool:
	"""
	处理阶段，每帧调用
	
	@param context: 上下文
	@param next: 下一个中间件的回调函数
	@return: 执行是否成功
	"""
	# 处理过渡进度
	_interruption_manager.process_transition(0.016)  # 假设60fps，约16ms
	
	# 继续执行下一个中间件
	return next.call()

# 状态协调方法
func _sync_context_to_state_manager(context: JuicyContext, status: String) -> void:
	"""
	同步Context状态到状态协调管理器
	
	@param context: Context实例
	@param status: 状态字符串
	"""
	if not _state_manager or not context:
		return
	
	# 获取通道中间件实例进行状态协调
	var channel_middleware = null
	# 注意：这里需要通过JuicyMixer获取通道中间件实例
	# 由于循环依赖问题，我们暂时只同步中断状态
	_state_manager.sync_context_state(context, channel_middleware, self)

func _validate_state_consistency() -> void:
	"""
	验证状态一致性 - 检查内部状态与状态协调器的一致性
	"""
	if not _state_manager:
		return
	
	# 这里可以添加状态一致性验证逻辑
	# 例如：检查活跃Context数量是否匹配，状态是否同步等
	pass

func cleanup(context: JuicyContext) -> void:
	"""
	清理阶段，在效果结束时调用
	
	@param context: 上下文
	"""
	# 清理中断状态
	if context and context.target:
		var target = context.target
		if target:
			_interruption_manager.clear_interruption_state(target)
	
	# 不调用super.cleanup以避免类型检查问题
	# super.cleanup(context)

func destroy() -> void:
	"""
	销毁中间件
	"""
	if _interruption_manager:
		_interruption_manager = null
	
	super.destroy()

# =============================================================================
# 配置管理
# =============================================================================

func _setup_default_configuration() -> void:
	"""
	设置默认配置
	"""
	_default_configuration = {
		"enable_performance_monitoring": true,
		"enable_debug_logging": false,
		"priority": 100,
		"max_log_entries": 100,
		"enable_auto_cleanup": true,
		"cleanup_threshold": 50
	}
	
	# 设置配置模式
	set_configuration_schema({
		"enable_performance_monitoring": {"type": "bool"},
		"enable_debug_logging": {"type": "bool"},
		"priority": {"type": "int"},
		"max_log_entries": {"type": "int"},
		"enable_auto_cleanup": {"type": "bool"},
		"cleanup_threshold": {"type": "int"}
	})

# =============================================================================
# 中断决策逻辑
# =============================================================================

func _get_active_contexts_for_target(target: Node) -> Array[String]:
	"""
	获取目标的所有活跃上下文
	
	@param target: 目标节点
	@return: 活跃上下文ID数组
	"""
	var active_contexts: Array[String] = []
	
	if not target:
		return active_contexts
	
	# 性能优化：使用Director的反向映射进行O(1)查找
	var context_ids = JuicyMixer.instance._director.get_contexts_by_target(target)
	
	# 验证上下文是否仍然活跃
	var active_contexts_dict = JuicyMixer.instance._director.get_active_contexts()
	for context_id in context_ids:
		if active_contexts_dict.has(context_id):
			active_contexts.append(context_id)
	
	return active_contexts

func _determine_interruption_policy(new_context: Object, existing_context: Object) -> JuicyMixerEnums.InterruptionPolicy:
	"""
	确定中断策略
	
	@param new_context: 新上下文
	@param existing_context: 现有上下文
	@return: 中断策略
	"""
	# 从资源获取中断策略
	if new_context.resource and new_context.resource.has_method("get_interruption_policy"):
		var policy_name = new_context.resource.get_interruption_policy()
		if policy_name and not policy_name.is_empty():
			return JuicyMixerEnums.get_interruption_policy_from_name(policy_name)
	
	# 从通道获取中断策略
	var channel_policy = _get_channel_policy(new_context.resource.channel if new_context.resource else "")
	if channel_policy != null:
		return channel_policy
	
	# 使用默认策略
	return _interruption_manager.get_default_policy()

func _get_channel_policy(channel: String) -> JuicyMixerEnums.InterruptionPolicy:
	"""
	获取通道策略
	
	@param channel: 通道名称
	@return: 中断策略，如果不存在则返回null
	"""
	var config = _interruption_manager._get_channel_config(channel)
	if config:
		return config.get_policy()
	return JuicyMixerEnums.InterruptionPolicy.STACK

# =============================================================================
# 上下文生命周期事件处理
# =============================================================================

func on_context_created(context: JuicyContext) -> void:
	"""
	上下文创建时调用
	
	@param context: 新创建的上下文
	"""
	# 不调用super.on_context_created以避免类型检查问题
	# super.on_context_created(context)
	
	_log_debug("Context created, checking for interruption opportunities", {
		"context_id": context.context_id if context and context.context_id else "unknown"
	})
	
	# 同步Context状态到状态协调器
	if context:
		_sync_context_to_state_manager(context, "created")

func on_context_destroyed(context: JuicyContext) -> void:
	"""
	上下文销毁时调用
	
	@param context: 即将被销毁的上下文
	"""
	# 不调用super.on_context_destroyed以避免类型检查问题
	# super.on_context_destroyed(context)
	
	# 清理相关的中断状态
	if context and context.target:
		var target = context.target
		if target:
			var state = _interruption_manager.get_interruption_state(target)
			if state:
				# 从活跃列表中移除
				if state.has_active_context(context.context_id):
					state.remove_active_context(context.context_id)
				
				# 从队列中移除
				if state.has_queued_context(context.context_id):
					state.remove_queued_context(context.context_id)
	
	# 从状态协调器中移除
	if context and context.context_id:
		_state_manager.remove_context_sync(context.context_id)
	
	_log_debug("Context destroyed, cleaned up interruption state", {
		"context_id": context.context_id if context and context.context_id else "unknown"
	})

func on_context_paused(context: JuicyContext) -> void:
	"""
	上下文暂停时调用
	
	@param context: 被暂停的上下文
	"""
	# 不调用super.on_context_paused以避免类型检查问题
	# super.on_context_paused(context)
	
	# 同步Context状态到状态协调器
	if context:
		_sync_context_to_state_manager(context, "paused")
	
	_log_debug("Context paused", {
		"context_id": context.context_id if context and context.context_id else "unknown"
	})

func on_context_resumed(context: JuicyContext) -> void:
	"""
	上下文恢复时调用
	
	@param context: 被恢复的上下文
	"""
	# 不调用super.on_context_resumed以避免类型检查问题
	# super.on_context_resumed(context)
	
	# 同步Context状态到状态协调器
	if context:
		_sync_context_to_state_manager(context, "resumed")
	
	_log_debug("Context resumed", {
		"context_id": context.context_id if context and context.context_id else "unknown"
	})

# =============================================================================
# 配置管理
# =============================================================================

func set_channel_config(channel: String, config: ChannelInterruptionConfig) -> void:
	"""
	设置通道配置
	
	@param channel: 通道名称
	@param config: 通道配置
	"""
	if _interruption_manager:
		_interruption_manager.set_channel_config(channel, config)
		_log_debug("Channel configuration set", {"channel": channel})

func set_global_priority(resource_type: String, priority: int) -> void:
	"""
	设置全局优先级
	
	@param resource_type: 资源类型
	@param priority: 优先级
	"""
	if _interruption_manager:
		_interruption_manager.set_global_priority(resource_type, priority)
		_log_debug("Global priority set", {"resource_type": resource_type, "priority": priority})

func set_default_policy(policy: JuicyMixerEnums.InterruptionPolicy) -> void:
	"""
	设置默认中断策略
	
	@param policy: 中断策略
	"""
	if _interruption_manager:
		_interruption_manager.set_default_policy(policy)
		_log_debug("Default interruption policy set", {"policy": JuicyMixerEnums.get_interruption_policy_name(policy)})

# =============================================================================
# 状态查询
# =============================================================================

func get_interruption_state(target: Node) -> Object:
	"""
	获取目标的中断状态
	
	@param target: 目标节点
	@return: 中断状态，如果不存在则返回null
	"""
	if _interruption_manager:
		return _interruption_manager.get_interruption_state(target)
	return null

func get_interruption_stats() -> Dictionary:
	"""
	获取中断统计信息
	
	@return: 统计信息字典
	"""
	if _interruption_manager:
		return _interruption_manager.get_performance_stats()
	return {}

# =============================================================================
# 验证接口
# =============================================================================
# 移除了重复的 _validate_required_context_data() 和 _validate_target_node() 方法
# 这些验证逻辑现在由 ValidationMiddleware 统一处理
# 此中间件只保留中断特定的验证逻辑

# =============================================================================
# 性能监控
# =============================================================================

func get_performance_stats() -> Dictionary:
	"""
	获取性能统计信息
	
	@return: 性能统计字典
	"""
	var base_stats = super.get_performance_stats()
	var interruption_stats = get_interruption_stats()
	
	# 合并统计信息
	var combined_stats = base_stats.duplicate()
	for key in interruption_stats.keys():
		combined_stats["interruption_" + key] = interruption_stats[key]
	
	return combined_stats

# =============================================================================
# 事件系统集成
# =============================================================================

func _emit_interruption_event(event_type: String, new_context: Object, existing_context: Object, policy: JuicyMixerEnums.InterruptionPolicy) -> void:
	"""
	触发中断事件
	
	@param event_type: 事件类型
	@param new_context: 新上下文
	@param existing_context: 现有上下文
	@param policy: 中断策略
	"""
	if not new_context or not existing_context:
		return
	
	# 创建中断事件
	var event = JuicyEvent.create_interruption_event(
		"",
		existing_context.target,
		event_type,
		new_context.context_id,
		existing_context.context_id,
		policy
	)
	
	# 设置事件优先级
	event.priority = max(new_context.resource.priority if new_context.resource else 0,
						existing_context.resource.priority if existing_context.resource else 0)
	
	# 通过JuicyMixer的公共API添加事件
	JuicyMixer.add_event(event)
	
	_log_debug("Emitted interruption event", {
		"event_type": event_type,
		"new_context": new_context.context_id,
		"existing_context": existing_context.context_id,
		"policy": JuicyMixerEnums.get_interruption_policy_name(policy)
	})

func _emit_interruption_resolved_event(context: Object, resolution_type: String) -> void:
	"""
	触发中断解决事件
	
	@param context: 上下文
	@param resolution_type: 解决类型
	"""
	if not context:
		return
	
	# 创建中断解决事件
	var event = JuicyEvent.create_interruption_resolved_event(
		"",
		context.target,
		context.context_id,
		resolution_type
	)
	
	# 设置事件优先级
	event.priority = context.resource.priority if context.resource else 0
	
	# 通过JuicyMixer的公共API添加事件
	JuicyMixer.add_event(event)
	
	_log_debug("Emitted interruption resolved event", {
		"context_id": context.context_id,
		"resolution_type": resolution_type
	})

func _emit_transition_event(transition_type: String, context: Object, from_context: Object = null, duration: float = 0.0) -> void:
	"""
	触发过渡事件
	
	@param transition_type: 过渡类型 (started/completed)
	@param context: 上下文
	@param from_context: 源上下文（可选）
	@param duration: 过渡持续时间
	"""
	if not context:
		return
	
	# 创建过渡事件
	var event = JuicyEvent.create_transition_event(
		"",
		context.target,
		transition_type,
		context.context_id,
		from_context.context_id if from_context else "",
		duration
	)
	
	# 设置事件优先级
	event.priority = context.resource.priority if context.resource else 0
	
	# 通过JuicyMixer的公共API添加事件
	JuicyMixer.add_event(event)
	
	_log_debug("Emitted transition event", {
		"transition_type": transition_type,
		"context_id": context.context_id,
		"from_context_id": from_context.context_id if from_context else "none",
		"duration": duration
	})
