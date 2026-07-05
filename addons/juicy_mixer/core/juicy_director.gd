
# JuicyDirector - 调度核心
# 处理所有播放请求，管理Context生命周期
# 协调各个子系统的工作，提供统一的调度接口

class_name JuicyDirector
extends RefCounted

# 核心组件引用
var _context_pool: JuicyContextPool
var _property_buffer: JuicyPropertyBuffer
var _driver_registry: JuicyDriverRegistry
var _middleware_pipeline: JuicyMiddlewarePipeline
var _pool_manager: JuicyPoolManager

# 活跃上下文管理
var _active_contexts: Dictionary = {}  # context_id -> JuicyContext
var _context_targets: Dictionary = {}  # target_id -> Array[context_id]
var _target_contexts: Dictionary = {}  # target_id -> Array[context_id] - 反向映射优化

# 调度状态
var _is_processing: bool = false
var _process_queue: Array = []

func _init(property_buffer: JuicyPropertyBuffer,
		 driver_registry: JuicyDriverRegistry, middleware_pipeline: JuicyMiddlewarePipeline):
	_property_buffer = property_buffer
	_driver_registry = driver_registry
	_middleware_pipeline = middleware_pipeline
	
	# 初始化池管理器
	_pool_manager = JuicyPoolManager.instance
	_context_pool = _pool_manager.get_context_pool()

# 核心播放接口
func play(resource: JuicyFeedbackResource, target: Node, owner: Node = null) -> String:
	if OS.is_debug_build():
		print("[JuicyDirector] Playing resource: ", resource.get_class() if resource else "null")

	# 验证输入
	if not _validate_play_request(resource, target):
		if OS.is_debug_build():
			print("[JuicyDirector] Validation failed for resource: ", resource.get_class() if resource else "null")
		return ""

	# 从池中获取Context
	var context = _context_pool.get_context()
	if OS.is_debug_build():
		print("[JuicyDirector] Got context from pool: ", context.context_id)

	# 初始化Context（使用现有的属性设置方式）
	context.resource = resource
	context.target = target
	context.owner = owner if owner else target
	context.duration = resource.get_duration()
	context.context_type = JuicyContext.ContextType.FEEDBACK  # 标记为 Feedback 类型

	# 通过中间件管道处理
	if not _middleware_pipeline_execute(context):
		if OS.is_debug_build():
			print("[JuicyDirector] Middleware pipeline execution failed")
		# 返回Context到池中
		_context_pool.return_context(context)
		return ""

	# 注册上下文
	_register_context(context)

	# 激活上下文
	context.activate()

	if OS.is_debug_build():
		print("[JuicyDirector] Context activated: ", context.context_id)

	return context.context_id

## 播放事件（不依赖Resource）
##
## 与 play() 不同，此方法专门用于处理事件Context
## 事件Context 不需要 Resource，但会通过完整的中间件管道处理
##
## @param context: 事件专用的 JuicyContext（通过 JuicyContext.create_for_event() 创建）
## @return: context_id，失败返回空字符串
func play_event(context: JuicyContext) -> String:
	"""处理事件专用的播放方法"""
	# 验证事件 Context
	if not _validate_event_context(context):
		push_error("[Director] Invalid event context")
		return ""

	# 从池中获取 Context（复用池管理）
	var pooled_context = _context_pool.get_context()
	if not pooled_context:
		push_error("[Director] Failed to get context from pool")
		return ""

	# 复制事件数据到池中的 Context
	pooled_context.resource = null
	pooled_context.target = context.target
	pooled_context.owner = context.owner
	pooled_context.duration = 0.0
	pooled_context.context_id = context.context_id
	pooled_context.reset()
	pooled_context.context_type = JuicyContext.ContextType.EVENT  # 标记为 Event 类型

	# 复制事件
	for event in context.get_events():
		pooled_context.add_event(event)

	# 通过中间件管道处理
	if not _middleware_pipeline_execute(pooled_context):
		_context_pool.return_context(pooled_context)
		return ""

	# 注册上下文
	_register_context(pooled_context)

	# 激活上下文
	pooled_context.activate()

	return pooled_context.context_id

func stop(context_id: String) -> bool:
	var context = _active_contexts.get(context_id)
	if not context:
		if OS.is_debug_build():
			print("[JuicyDirector] Stop failed: context not found: ", context_id)
		return false

	if OS.is_debug_build():
		print("[JuicyDirector] Stopping context: ", context_id)

	# 触发中间件销毁钩子
	_trigger_middleware_hooks(context, "destroyed")

	# 调用驱动器的cleanup方法
	_cleanup_drivers(context)

	context.complete()
	_unregister_context(context)
	_context_pool.return_context(context)

	if OS.is_debug_build():
		print("[JuicyDirector] Context stopped and returned to pool: ", context_id)

	return true

func pause(context_id: String) -> bool:
	var context = _active_contexts.get(context_id)
	if not context:
		return false
	
	# 触发中间件暂停钩子
	_trigger_middleware_hooks(context, "paused")
	
	context.pause()
	return true

func resume(context_id: String) -> bool:
	var context = _active_contexts.get(context_id)
	if not context:
		return false
	
	# 触发中间件恢复钩子
	_trigger_middleware_hooks(context, "resumed")
	
	context.resume()
	return true

# 每帧处理 - 优化版本
func process(delta: float) -> void:
	if _is_processing:
		return

	_is_processing = true

	# 优化：如果没有活跃上下文，直接返回
	if _active_contexts.is_empty():
		_is_processing = false
		return

	if OS.is_debug_build():
		if _active_contexts.size() > 0:
			print("[JuicyDirector] Processing ", _active_contexts.size(), " active contexts")

	# 处理所有活跃上下文
	var contexts_to_remove: Array = []
	
	# 修复：使用快照而不是直接迭代，避免迭代中修改字典导致的崩溃
	var context_ids = _active_contexts.keys()
	for context_id in context_ids:
		var context = _active_contexts.get(context_id)
		# 检查context是否已被移除
		if not context:
			continue
		
		# 优化：首先检查上下文是否已完成，如果完成则跳过所有处理
		if context.is_completed:
			contexts_to_remove.append(context_id)
			continue
		
		# 更新上下文
		# context.update(delta)
		
		# 再次检查上下文是否在更新后完成（防止在update中完成）
		if context.is_completed:
			contexts_to_remove.append(context_id)
			continue
		
		# 执行驱动器
		_execute_drivers(context, delta)
		
		# 优化：条件性事件处理（仅在有EventHandlingMiddleware时执行）
		if _has_event_middleware():
			_process_events(context, delta)
	
	# 每帧都应用属性缓冲区，确保平滑动画
	_property_buffer.flush_all_samples()

	# 优化：批量清理完成的上下文（使用 defer 避免在迭代中修改字典）
	if not contexts_to_remove.is_empty():
		call_deferred("_cleanup_contexts_deferred", contexts_to_remove.duplicate())

	# 处理池管理器更新
	_pool_manager.process(delta)

	_is_processing = false

## 延迟清理上下文（避免在迭代中修改字典）
## @param context_ids: 需要清理的上下文ID列表
func _cleanup_contexts_deferred(context_ids: Array) -> void:
	for context_id in context_ids:
		var context = _active_contexts.get(context_id)
		if not context:
			continue

		# 调用驱动器的cleanup方法
		_cleanup_drivers(context)
		_unregister_context(context)
		_context_pool.return_context(context)

# 内部方法
func _validate_play_request(resource: Object, target: Node) -> bool:
	# 优化：移除调试输出，提高性能

	if not resource or not is_instance_valid(target):
		# 优化：移除调试输出，提高性能
		return false

	# 检查资源是否有效
	if not is_instance_valid(resource):
		# 优化：移除调试输出，提高性能
		return false

	# 优化：移除调试输出，提高性能
	return true

func _validate_event_context(context: JuicyContext) -> bool:
	"""验证事件 Context 的有效性"""
	if not context or not is_instance_valid(context):
		return false
	if not context.target or not is_instance_valid(context.target):
		return false
	if context.get_events().is_empty():
		return false
	return true

func _middleware_pipeline_execute(context: Object) -> bool:
	# 优化：移除调试输出，提高性能
	
	# 执行中间件管道
	if not _middleware_pipeline:
		# 优化：移除调试输出，提高性能
		return true  # 如果没有中间件管道，直接通过
	
	if not _middleware_pipeline.has_method("execute"):
		# 优化：移除调试输出，提高性能
		return true
	
	# 验证Context
	if not context:
		# 优化：移除调试输出，提高性能
		return false
	
	if not context.has_method("get_context_id"):
		# 优化：移除调试输出，提高性能
		return false
	
	# 优化：移除调试输出，提高性能
	
	# 执行中间件管道
	var result = _middleware_pipeline.execute(context)
	
	# 优化：移除调试输出，提高性能
	
	# 如果执行失败，记录错误
	if not result:
		var error_code = _middleware_pipeline.get_last_error_code() if _middleware_pipeline.has_method("get_last_error_code") else "UNKNOWN"
		var error_message = _middleware_pipeline.get_last_error_message() if _middleware_pipeline.has_method("get_last_error_message") else "Middleware execution failed"
		print("[JuicyDirector] Middleware pipeline execution failed: ", error_message, " (code: ", error_code, ")")
	
	return result

func _register_context(context: Object) -> void:
	_active_contexts[context.context_id] = context
	
	var target_id = context.target.get_instance_id()
	if not _context_targets.has(target_id):
		_context_targets[target_id] = []
	_context_targets[target_id].append(context.context_id)
	
	# 反向映射优化：target_id -> context_id
	if not _target_contexts.has(target_id):
		_target_contexts[target_id] = []
	_target_contexts[target_id].append(context.context_id)

func _unregister_context(context: Object) -> void:
	_active_contexts.erase(context.context_id)
	
	# 安全检查：确保target仍然有效
	if context and context.target and is_instance_valid(context.target):
		var target_id = context.target.get_instance_id()
		if _context_targets.has(target_id):
			var context_ids = _context_targets[target_id]
			context_ids.erase(context.context_id)
			
			if context_ids.is_empty():
				_context_targets.erase(target_id)
		
		# 反向映射优化：移除target_id -> context_id的映射
		if _target_contexts.has(target_id):
			var target_context_ids = _target_contexts[target_id]
			target_context_ids.erase(context.context_id)
			
			if target_context_ids.is_empty():
				_target_contexts.erase(target_id)

func _execute_drivers(context: Object, delta: float) -> void:
	# 检查是否已经有缓存的驱动器实例
	if not context.has_meta("cached_drivers"):
		var drivers = context.resource.create_drivers()
		context.set_meta("cached_drivers", drivers)
		
		# 为新创建的驱动器调用prepare方法
		for driver in drivers:
			if driver.has_method("prepare"):
				driver.prepare(context, delta, _property_buffer)
	
	var drivers = context.get_meta("cached_drivers")
	
	for driver in drivers:
		if not driver.is_active:
			continue
		
		# 调用process方法
		if driver.has_method("process"):
			driver.process(context, delta, _property_buffer)

# 事件处理相关方法
func _has_event_middleware() -> bool:
	"""检查是否注册了事件处理中间件"""
	if not _middleware_pipeline:
		return false
	
	# 检查中间件管道是否有get_all_middleware方法
	if not _middleware_pipeline.has_method("get_all_middleware"):
		return false
	
	# 获取所有中间件并检查是否有EventHandlingMiddleware
	var middleware_list = _middleware_pipeline.get_all_middleware()
	for middleware in middleware_list:
		if middleware and middleware.get_class() == "JuicyEventHandlingMiddleware":
			return true
	
	return false

func _process_events(context: Object, delta: float) -> void:
	"""处理事件（通过中间件管道）"""
	# 通过中间件管道处理事件
	# 注意：这里不需要手动调用_middleware_pipeline.execute，因为事件处理中间件
	# 会在其process方法中自动处理事件。我们只需要确保中间件管道被执行即可。
	# 实际上，中间件管道的执行已经在_middleware_pipeline_execute中处理，
	# 所以这里可以留空或添加额外的日志记录
	pass

# 查询方法
func get_context(context_id: String) -> Object:
	return _active_contexts.get(context_id)

func get_active_contexts_count() -> int:
	return _active_contexts.size()

func get_target_contexts(target: Node) -> Array:
	var target_id = target.get_instance_id()
	var context_ids = _context_targets.get(target_id, [])
	var contexts: Array = []
	
	for context_id in context_ids:
		var context = _active_contexts.get(context_id)
		if context:
			contexts.append(context)
	
	return contexts

func get_active_contexts() -> Dictionary:
	return _active_contexts.duplicate()

# 反向映射优化：通过target_id快速获取context_id列表
func get_contexts_by_target(target: Node) -> Array:
	"""
	通过目标节点快速获取所有关联的上下文ID
	
	@param target: 目标节点
	@return: 上下文ID数组，如果没有找到则返回空数组
	"""
	if not target or not is_instance_valid(target):
		return []
	
	var target_id = target.get_instance_id()
	return _target_contexts.get(target_id, []).duplicate()

# 中间件钩子触发
func _trigger_middleware_hooks(context: Object, event: String) -> void:
	"""
	触发中间件生命周期钩子
	
	@param context: JuicyContext实例
	@param event: 生命周期事件类型 (created, destroyed, paused, resumed)
	"""
	if not _middleware_pipeline or not _middleware_pipeline.has_method("get_all_middleware"):
		return
	
	# 获取所有中间件并触发相应的事件
	var middleware_list = _middleware_pipeline.get_all_middleware()
	for middleware in middleware_list:
		if middleware and middleware.has_method("handle_context_event"):
			middleware.handle_context_event(context, event)

# 清理驱动器
func _cleanup_drivers(context: Object) -> void:
	"""清理所有驱动器"""
	if not context:
		return
	
	# 使用缓存的驱动器实例进行清理
	if context.has_meta("cached_drivers"):
		var drivers = context.get_meta("cached_drivers")
		for driver in drivers:
			if driver and driver.has_method("cleanup"):
				driver.cleanup(context)
		
		# 清理缓存的驱动器
		context.remove_meta("cached_drivers")
