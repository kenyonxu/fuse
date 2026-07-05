# ChannelMiddleware - 通道中间件
# 管理效果通道的调度规则，控制同通道效果的并发
# 职责：专注于通道级别的并发调度和队列管理，不处理中断决策
# 优先级：900（高优先级，但在InterruptionMiddleware之后执行）
# 注意：中断逻辑已移至InterruptionMiddleware，本中间件仅负责调度
# 优化：使用ContextStateManager进行状态协调，避免重复状态管理

class_name ChannelMiddleware
extends JuicyMiddleware

# 通道管理
var _channel_configs: Dictionary = {}  # channel_name -> JuicyChannelConfig
var _channel_states: Dictionary = {}   # channel_name -> ChannelState
var _context_channels: Dictionary = {} # context_id -> channel_name

# 状态协调管理器
var _state_manager: ContextStateManager

# 通道状态
class ChannelState:
	var active_contexts: Array[String] = []
	var queued_contexts: Array[String] = []
	var total_executed: int = 0

func _init():
	middleware_name = "ChannelMiddleware"
	priority = 900  # 高优先级，在验证后执行
	description = "Manages effect channel scheduling and concurrency"
	tags = ["channel", "scheduling", "concurrency", "core"]
	
	# 初始化状态协调管理器
	_state_manager = ContextStateManager.get_instance()

func process(context: JuicyContext, next: Callable) -> bool:
	"""处理通道调度"""
	var start_time = _start_execution_timer()
	
	var channel_name = "default"
	if context.resource and context.resource.has_method("get_channel"):
		channel_name = context.resource.get_channel()
	if channel_name.is_empty():
		channel_name = "default"
	
	# 获取或创建通道配置
	var channel_config = _get_channel_config(channel_name)
	
	# 获取或创建通道状态
	var channel_state = _get_channel_state(channel_name)
	
	# 检查是否可以调度
	if not _can_schedule(channel_config, channel_state, context):
		# 同步状态到状态协调器（状态为queued）
		_sync_to_state_manager(context, channel_name, "queued")
		_end_execution_timer(start_time)
		return false
	
	# 执行调度
	if not _schedule_context(channel_config, channel_state, context):
		_end_execution_timer(start_time)
		return false
	
	# 记录通道关联
	_context_channels[context.context_id] = channel_name
	
	# 同步状态到状态协调器（状态为active）
	_sync_to_state_manager(context, channel_name, "active")
	
	_end_execution_timer(start_time)
	return next.call()

func cleanup(context: JuicyContext) -> void:
	"""清理通道状态"""
	var channel_name = _context_channels.get(context.context_id)
	if channel_name:
		var channel_state = _channel_states.get(channel_name)
		if channel_state:
			channel_state.active_contexts.erase(context.context_id)
		
		_context_channels.erase(context.context_id)
		
		# 同步状态到状态协调器（状态为completed）
		_sync_to_state_manager(context, channel_name, "completed")
		
		# 处理队列中的下一个Context
		_process_queue(channel_name)

# 内部实现
func _get_channel_config(channel_name: String) -> JuicyChannelConfig:
	"""获取通道配置"""
	if not _channel_configs.has(channel_name):
		_channel_configs[channel_name] = _create_default_channel_config(channel_name)
	return _channel_configs[channel_name]

func _create_default_channel_config(channel_name: String) -> JuicyChannelConfig:
	"""创建默认通道配置"""
	var config = JuicyChannelConfig.new()
	config.channel_name = channel_name
	return config

func _get_channel_state(channel_name: String) -> ChannelState:
	"""获取通道状态"""
	if not _channel_states.has(channel_name):
		_channel_states[channel_name] = ChannelState.new()
	return _channel_states[channel_name]

func _can_schedule(config: JuicyChannelConfig, state: ChannelState, context: JuicyContext) -> bool:
	"""检查是否可以调度"""
	# 检查并发限制
	if config.max_concurrent > 0 and state.active_contexts.size() >= config.max_concurrent:
		_log_debug("并发限制达到，无法调度", {
			"channel": config.channel_name,
			"current_active": state.active_contexts.size(),
			"max_concurrent": config.max_concurrent
		})
		return false
	
	# 检查是否允许中断
	if not config.allow_interruption and not state.active_contexts.is_empty():
		_log_debug("不允许中断，无法调度", {
			"channel": config.channel_name,
			"current_active": state.active_contexts.size()
		})
		return false
	
	return true

func _schedule_context(config: JuicyChannelConfig, state: ChannelState, context: JuicyContext) -> bool:
	"""调度Context"""
	# 注意：中断逻辑已移至InterruptionMiddleware处理
	# ChannelMiddleware仅负责通道并发调度，不处理中断决策
	
	# 添加到活跃列表
	state.active_contexts.append(context.context_id)
	state.total_executed += 1
	
	return true

func _process_queue(channel_name: String) -> void:
	"""处理队列中的Context"""
	var config = _get_channel_config(channel_name)
	var state = _get_channel_state(channel_name)
	
	while not state.queued_contexts.is_empty() and _can_schedule(config, state, null):
		var context_id = _dequeue_context(config, state)
		if context_id.is_empty():
			break
		
		# 重新调度队列中的Context
		var context = JuicyMixer.get_context(context_id)
		if context:
			_schedule_context(config, state, context)
			# 同步状态到状态协调器（状态为active）
			_sync_to_state_manager(context, channel_name, "active")

func _dequeue_context(config: JuicyChannelConfig, state: ChannelState) -> String:
	"""从队列中取出Context"""
	if state.queued_contexts.is_empty():
		return ""
	
	match config.priority_mode:
		0:  # FIFO
			return state.queued_contexts.pop_front()
		1:  # LIFO
			return state.queued_contexts.pop_back()
		2:  # PRIORITY_BASED
			# 按优先级排序后取出
			state.queued_contexts.sort_custom(func(a, b):
				var context_a = JuicyMixer.get_context(a)
				var context_b = JuicyMixer.get_context(b)
				if not context_a or not context_b:
					return false
				return context_a.resource.priority > context_b.resource.priority
			)
			return state.queued_contexts.pop_front()
		_:
			return state.queued_contexts.pop_front()

# 状态协调方法
func _sync_to_state_manager(context: JuicyContext, channel_name: String, status: String) -> void:
	"""
	同步状态到状态协调管理器
	
	@param context: Context实例
	@param channel_name: 通道名称
	@param status: 状态字符串 ("pending", "active", "queued", "completed")
	"""
	if not _state_manager or not context:
		return
	
	# 获取中断中间件实例进行状态协调
	var interruption_middleware = null
	# 注意：这里需要通过JuicyMixer获取中断中间件实例
	# 由于循环依赖问题，我们暂时只同步通道状态
	_state_manager.sync_context_state(context, self, interruption_middleware)

# 通道配置管理
func set_channel_config(channel_name: String, config: JuicyChannelConfig) -> void:
	"""设置通道配置"""
	_channel_configs[channel_name] = config

func get_channel_config(channel_name: String) -> JuicyChannelConfig:
	"""获取通道配置"""
	return _get_channel_config(channel_name)

func load_channel_config(resource_path: String) -> JuicyChannelConfig:
	"""从文件加载通道配置"""
	if ResourceLoader.exists(resource_path):
		return load(resource_path) as JuicyChannelConfig
	return null

func save_channel_config(config: JuicyChannelConfig, resource_path: String) -> bool:
	"""保存通道配置到文件"""
	return ResourceSaver.save(config, resource_path) == OK

func get_channel_state(channel_name: String) -> ChannelState:
	"""获取通道状态"""
	return _get_channel_state(channel_name)

# 统计和调试
func get_channel_stats() -> Dictionary:
	"""获取通道统计信息"""
	var stats = {}
	
	for channel_name in _channel_states.keys():
		var state = _channel_states[channel_name]
		var config = _channel_configs[channel_name]
		
		stats[channel_name] = {
			"active_contexts": state.active_contexts.size(),
			"queued_contexts": state.queued_contexts.size(),
			"max_concurrent": config.max_concurrent,
			"priority_mode": config.priority_mode,
			"total_executed": state.total_executed
		}
	
	return stats

func debug_print_channels() -> void:
	"""打印通道信息"""
	print("=== JuicyMixer Channel States ===")
	var stats = get_channel_stats()
	
	for channel_name in stats.keys():
		var stat = stats[channel_name]
		print("Channel: ", channel_name)
		print("  Active: ", stat.active_contexts, "/", stat.max_concurrent)
		print("  Queued: ", stat.queued_contexts)
		print("  Priority Mode: ", stat.priority_mode)
		print("  Total Executed: ", stat.total_executed)

# 生命周期钩子
func on_context_created(context: JuicyContext) -> void:
	"""Context创建时的生命周期钩子"""
	_log_debug("ChannelMiddleware Context created", {"context_id": context.context_id})
	
	# 同步状态到状态协调器（初始状态为pending）
	if context and context.context_id:
		var channel_name = "default"
		if context.resource and context.resource.has_method("get_channel"):
			channel_name = context.resource.get_channel()
		if channel_name.is_empty():
			channel_name = "default"
		_sync_to_state_manager(context, channel_name, "pending")

func on_context_destroyed(context: JuicyContext) -> void:
	"""Context销毁时的生命周期钩子"""
	_log_debug("ChannelMiddleware Context destroyed", {"context_id": context.context_id})
	
	# 从状态协调器中移除
	if context and context.context_id:
		_state_manager.remove_context_sync(context.context_id)

# 配置管理
func _setup_default_configuration() -> void:
	# 调用父类的默认配置设置
	super._setup_default_configuration()
	
	# 添加通道中间件特定的默认配置
	_default_configuration["enable_channel_monitoring"] = true
	_default_configuration["log_channel_events"] = false
	_default_configuration["auto_create_default_channels"] = true
	
	# 更新配置模式
	set_configuration_schema({
		"enable_performance_monitoring": {"type": "bool"},
		"enable_debug_logging": {"type": "bool"},
		"priority": {"type": "int"},
		"max_log_entries": {"type": "int"},
		"enable_channel_monitoring": {"type": "bool"},
		"log_channel_events": {"type": "bool"},
		"auto_create_default_channels": {"type": "bool"}
	})