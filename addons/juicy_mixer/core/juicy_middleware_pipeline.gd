# JuicyMiddlewarePipeline - 中间件管道管理系统
# 管理中间件的注册、排序、执行和生命周期
# 提供高性能的中间件链式执行机制

class_name JuicyMiddlewarePipeline
extends RefCounted

# =============================================================================
# 常量定义
# =============================================================================

## 管道状态枚举
enum PipelineState {
	IDLE,		  # 空闲状态
	BUILDING,	  # 构建中
	READY,		 # 准备就绪
	EXECUTING,	 # 执行中
	ERROR,		 # 错误状态
	DESTROYED	  # 已销毁
}

## 错误代码枚举
enum ErrorCode {
	NONE,						  # 无错误
	MIDDLEWARE_NOT_FOUND,		  # 中间件未找到
	MIDDLEWARE_ALREADY_EXISTS,	# 中间件已存在
	INVALID_MIDDLEWARE,			# 无效的中间件
	EXECUTION_FAILED,			  # 执行失败
	CONFIGURATION_ERROR,		   # 配置错误
	CONTEXT_INVALID,			   # Context无效
	PIPELINE_NOT_READY			 # 管道未准备就绪
}

# =============================================================================
# 信号定义
# =============================================================================

## 管道状态变化信号
## @param state: 新的管道状态
signal pipeline_state_changed(state: PipelineState)

## 中间件添加信号
## @param middleware: 添加的中间件
signal middleware_added(middleware: JuicyMiddleware)

## 中间件移除信号
## @param middleware: 移除的中间件
signal middleware_removed(middleware: JuicyMiddleware)

## 中间件激活状态变化信号
## @param middleware: 中间件
## @param active: 激活状态
signal middleware_activation_changed(middleware: JuicyMiddleware, active: bool)

## 管道执行开始信号
## @param context: 执行的Context
signal execution_started(context: JuicyContext)

## 管道执行完成信号
## @param context: 执行的Context
## @param success: 是否成功
signal execution_completed(context: JuicyContext, success: bool)

## 管道执行错误信号
## @param context: 执行的Context
## @param error: 错误信息
signal execution_error(context: JuicyContext, error: Dictionary)

# =============================================================================
# 管道配置
# =============================================================================

## 管道名称
var pipeline_name: String = "DefaultPipeline"

## 管道描述
var description: String = ""

## 管道版本
var version: String = "1.0.0"

## 管道状态
var _state: PipelineState = PipelineState.IDLE

## 是否启用性能监控
var enable_performance_monitoring: bool = true

## 是否启用调试日志
var enable_debug_logging: bool = true

## 是否启用错误恢复
var enable_error_recovery: bool = true

## 最大重试次数
var max_retry_attempts: int = 3

## 执行超时时间（毫秒）
var execution_timeout: float = 1000.0

# =============================================================================
# 中间件存储和管理
# =============================================================================

## 中间件字典，按名称索引
## key: middleware_name, value: JuicyMiddleware
var _middleware_dict: Dictionary = {}

## 中间件数组，按优先级排序
var _middleware_array: Array[JuicyMiddleware] = []

## 中间件名称集合，用于快速查找
var _middleware_names: Array[String] = []

## 中间件类注册表，用于自动发现
## key: middleware_name, value: Class
var _middleware_registry: Dictionary = {}

## 执行链缓存
var _execution_chain: Array[Callable] = []

## 执行链是否需要重建
var _execution_chain_dirty: bool = true

## 当前执行的Context
var _current_context: JuicyContext = null

## 当前执行的中间件索引
var _current_middleware_index: int = -1

# =============================================================================
# 性能统计
# =============================================================================

## 管道执行次数
var _execution_count: int = 0

## 管道总执行时间
var _total_execution_time: float = 0.0

## 最后一次执行时间
var _last_execution_time: float = 0.0

## 错误计数
var _error_count: int = 0

## 重试计数
var _retry_count: int = 0

## 性能统计开始时间
var _performance_start_time: float = 0.0

# =============================================================================
# 错误和日志管理
# =============================================================================

## 当前错误代码
var _last_error_code: ErrorCode = ErrorCode.NONE

## 错误消息
var _last_error_message: String = ""

## 错误详情
var _last_error_details: Dictionary = {}

## 错误日志
var _error_log: Array[Dictionary] = []

## 调试日志
var _debug_log: Array[Dictionary] = []

## 最大日志条目数
var _max_log_entries: int = 200

# =============================================================================
# 初始化和销毁
# =============================================================================

## 初始化管道
## @param config: 管道配置字典
## @return: bool，初始化是否成功
func initialize(config: Dictionary = {}) -> bool:
	"""
	初始化管道
	
	@param config: 管道配置字典
	@return: bool，初始化是否成功
	"""
	if _state != PipelineState.IDLE:
		_log_error(ErrorCode.CONFIGURATION_ERROR, "Pipeline already initialized", {"current_state": _state})
		return false
	
	# 应用配置
	_apply_configuration(config)
	
	# 注册内置中间件类
	_register_builtin_middleware_classes()
	
	# 初始化完成
	_state = PipelineState.READY
	_log_debug("Pipeline initialized", {"config": config})
	
	# 发送状态变化信号
	pipeline_state_changed.emit(_state)
	
	return true

## 销毁管道
func destroy() -> void:
	"""
	销毁管道
	
	清理所有资源并重置状态
	"""
	if _state == PipelineState.DESTROYED:
		return
	
	# 停止任何正在执行的管道
	if _state == PipelineState.EXECUTING:
		_log_error(ErrorCode.EXECUTION_FAILED, "Destroying pipeline while executing", {"context_id": _current_context.context_id if _current_context else "null"})
	
	# 清理中间件
	for middleware in _middleware_array:
		if middleware and middleware._is_initialized:
			middleware.destroy()
	
	# 清理数据结构
	_middleware_dict.clear()
	_middleware_array.clear()
	_middleware_names.clear()
	_middleware_registry.clear()
	_execution_chain.clear()
	
	# 重置状态
	_state = PipelineState.DESTROYED
	_current_context = null
	_current_middleware_index = -1
	
	# 清理日志
	clear_logs()
	
	_log_debug("Pipeline destroyed")

## 应用配置
## @param config: 配置字典
func _apply_configuration(config: Dictionary) -> void:
	"""
	应用配置
	
	@param config: 配置字典
	"""
	pipeline_name = config.get("pipeline_name", pipeline_name)
	description = config.get("description", description)
	version = config.get("version", version)
	enable_performance_monitoring = config.get("enable_performance_monitoring", enable_performance_monitoring)
	enable_debug_logging = config.get("enable_debug_logging", enable_debug_logging)
	enable_error_recovery = config.get("enable_error_recovery", enable_error_recovery)
	max_retry_attempts = config.get("max_retry_attempts", max_retry_attempts)
	execution_timeout = config.get("execution_timeout", execution_timeout)
	_max_log_entries = config.get("max_log_entries", _max_log_entries)

# =============================================================================
# 中间件管理
# =============================================================================

## 添加中间件
## @param middleware: 要添加的中间件实例
## @param replace: 是否替换已存在的同名中间件
## @return: bool，添加是否成功
func add_middleware(middleware: JuicyMiddleware, replace: bool = false) -> bool:
	"""
	添加中间件到管道
	
	@param middleware: 要添加的中间件实例
	@param replace: 是否替换已存在的同名中间件
	@return: bool，添加是否成功
	"""
	if not middleware:
		_log_error(ErrorCode.INVALID_MIDDLEWARE, "Cannot add null middleware")
		return false
	
	# 验证中间件
	if not _validate_middleware(middleware):
		return false
	
	# 优化：移除调试输出，提高性能
	
	var middleware_name = middleware.middleware_name
	
	# 检查是否已存在
	if middleware_name in _middleware_names and not replace:
		_log_error(ErrorCode.MIDDLEWARE_ALREADY_EXISTS, "Middleware already exists", {"middleware_name": middleware_name})
		return false
	
	# 初始化中间件
	if not middleware.initialize():
		_log_error(ErrorCode.INVALID_MIDDLEWARE, "Failed to initialize middleware", {"middleware_name": middleware_name})
		return false
	
	# 如果存在同名中间件，先移除
	if middleware_name in _middleware_names:
		remove_middleware(middleware_name)
	
	# 调用中间件注册生命周期钩子
	if middleware.has_method("on_middleware_registered"):
		middleware.on_middleware_registered()
		_log_debug("Called on_middleware_registered lifecycle hook", {"middleware_name": middleware_name})
	
	# 添加到字典
	_middleware_dict[middleware_name] = middleware
	
	# 添加到数组
	_middleware_array.append(middleware)
	
	# 添加到名称集合
	_middleware_names.append(middleware_name)
	
	# 标记执行链需要重建
	_execution_chain_dirty = true
	
	# 按优先级重新排序
	_sort_middleware_by_priority()
	
	_log_debug("Middleware added", {
		"middleware_name": middleware_name,
		"priority": middleware.priority,
		"middleware_count": _middleware_array.size()
	})
	
	# 发送信号
	middleware_added.emit(middleware)
	
	return true

## 移除中间件
## @param middleware_name: 中间件名称
## @return: bool，移除是否成功
func remove_middleware(middleware_name: String) -> bool:
	"""
	从管道中移除中间件
	
	@param middleware_name: 中间件名称
	@return: bool，移除是否成功
	"""
	if middleware_name not in _middleware_names:
		_log_error(ErrorCode.MIDDLEWARE_NOT_FOUND, "Middleware not found", {"middleware_name": middleware_name})
		return false
	
	var middleware = _middleware_dict.get(middleware_name)
	
	# 调用中间件注销生命周期钩子（在销毁之前）
	if middleware and middleware.has_method("on_middleware_unregistered"):
		middleware.on_middleware_unregistered()
		_log_debug("Called on_middleware_unregistered lifecycle hook", {"middleware_name": middleware_name})
	
	# 从字典中移除
	_middleware_dict.erase(middleware_name)
	
	# 从数组中移除
	if middleware:
		_middleware_array.erase(middleware)
	
	# 从名称集合中移除
	_middleware_names.erase(middleware_name)
	
	# 销毁中间件
	if middleware and middleware._is_initialized:
		middleware.destroy()
	
	# 标记执行链需要重建
	_execution_chain_dirty = true
	
	_log_debug("Middleware removed", {
		"middleware_name": middleware_name,
		"middleware_count": _middleware_array.size()
	})
	
	# 发送信号
	if middleware:
		middleware_removed.emit(middleware)
	
	return true

## 获取中间件
## @param middleware_name: 中间件名称
## @return: JuicyMiddleware，中间件实例，如果不存在则返回null
func get_middleware(middleware_name: String) -> JuicyMiddleware:
	"""
	获取指定名称的中间件
	
	@param middleware_name: 中间件名称
	@return: JuicyMiddleware，中间件实例，如果不存在则返回null
	"""
	return _middleware_dict.get(middleware_name)

## 获取所有中间件
## @return: Array[JuicyMiddleware]，所有中间件实例数组
func get_all_middleware() -> Array[JuicyMiddleware]:
	"""
	获取所有中间件实例
	
	@return: Array[JuicyMiddleware]，所有中间件实例数组
	"""
	return _middleware_array.duplicate()

## 获取中间件名称列表
## @return: Array[String]，中间件名称数组
func get_middleware_names() -> Array[String]:
	"""
	获取所有中间件名称
	
	@return: Array[String]，中间件名称数组
	"""
	return _middleware_names.duplicate()

## 检查中间件是否存在
## @param middleware_name: 中间件名称
## @return: bool，是否存在
func has_middleware(middleware_name: String) -> bool:
	"""
	检查指定名称的中间件是否存在
	
	@param middleware_name: 中间件名称
	@return: bool，是否存在
	"""
	return middleware_name in _middleware_names

## 获取中间件数量
## @return: int，中间件数量
func get_middleware_count() -> int:
	"""
	获取管道中的中间件数量
	
	@return: int，中间件数量
	"""
	return _middleware_array.size()

## 清空所有中间件
func clear_all_middleware() -> void:
	"""
	清空管道中的所有中间件
	"""
	for middleware in _middleware_array:
		if middleware and middleware._is_initialized:
			middleware.destroy()
	
	_middleware_dict.clear()
	_middleware_array.clear()
	_middleware_names.clear()
	_execution_chain.clear()
	_execution_chain_dirty = true
	
	_log_debug("All middleware cleared")

# =============================================================================
# 中间件状态管理
# =============================================================================

## 启用中间件
## @param middleware_name: 中间件名称
## @return: bool，是否成功
func enable_middleware(middleware_name: String) -> bool:
	"""
	启用指定名称的中间件
	
	@param middleware_name: 中间件名称
	@return: bool，是否成功
	"""
	var middleware = get_middleware(middleware_name)
	if not middleware:
		_log_error(ErrorCode.MIDDLEWARE_NOT_FOUND, "Middleware not found", {"middleware_name": middleware_name})
		return false
	
	var old_state = middleware.is_active
	middleware.set_active(true)
	
	if old_state != middleware.is_active:
		_log_debug("Middleware enabled", {"middleware_name": middleware_name})
		middleware_activation_changed.emit(middleware, true)
	
	return true

## 禁用中间件
## @param middleware_name: 中间件名称
## @return: bool，是否成功
func disable_middleware(middleware_name: String) -> bool:
	"""
	禁用指定名称的中间件
	
	@param middleware_name: 中间件名称
	@return: bool，是否成功
	"""
	var middleware = get_middleware(middleware_name)
	if not middleware:
		_log_error(ErrorCode.MIDDLEWARE_NOT_FOUND, "Middleware not found", {"middleware_name": middleware_name})
		return false
	
	var old_state = middleware.is_active
	middleware.set_active(false)
	
	if old_state != middleware.is_active:
		_log_debug("Middleware disabled", {"middleware_name": middleware_name})
		middleware_activation_changed.emit(middleware, false)
	
	return true

## 检查中间件是否激活
## @param middleware_name: 中间件名称
## @return: bool，是否激活
func is_middleware_active(middleware_name: String) -> bool:
	"""
	检查指定名称的中间件是否激活
	
	@param middleware_name: 中间件名称
	@return: bool，是否激活
	"""
	var middleware = get_middleware(middleware_name)
	return middleware and middleware.is_active

## 获取激活的中间件数量
## @return: int，激活的中间件数量
func get_active_middleware_count() -> int:
	"""
	获取激活状态的中间件数量
	
	@return: int，激活的中间件数量
	"""
	var count = 0
	for middleware in _middleware_array:
		if middleware and middleware.is_active:
			count += 1
	return count

## 获取激活的中间件列表
## @return: Array[JuicyMiddleware]，激活的中间件数组
func get_active_middleware() -> Array[JuicyMiddleware]:
	"""
	获取所有激活状态的中间件
	
	@return: Array[JuicyMiddleware]，激活的中间件数组
	"""
	var active_list: Array[JuicyMiddleware] = []
	for middleware in _middleware_array:
		if middleware and middleware.is_active:
			active_list.append(middleware)
	return active_list

# =============================================================================
# 中间件查询和枚举
# =============================================================================

## 根据标签查找中间件
## @param tag: 标签名称
## @return: Array[JuicyMiddleware]，匹配的中间件数组
func find_middleware_by_tag(tag: String) -> Array[JuicyMiddleware]:
	"""
	根据标签查找中间件
	
	@param tag: 标签名称
	@return: Array[JuicyMiddleware]，匹配的中间件数组
	"""
	var result: Array[JuicyMiddleware] = []
	for middleware in _middleware_array:
		if middleware and tag in middleware.tags:
			result.append(middleware)
	return result

## 根据优先级范围查找中间件
## @param min_priority: 最小优先级
## @param max_priority: 最大优先级
## @return: Array[JuicyMiddleware]，匹配的中间件数组
func find_middleware_by_priority_range(min_priority: int, max_priority: int) -> Array[JuicyMiddleware]:
	"""
	根据优先级范围查找中间件
	
	@param min_priority: 最小优先级
	@param max_priority: 最大优先级
	@return: Array[JuicyMiddleware]，匹配的中间件数组
	"""
	var result: Array[JuicyMiddleware] = []
	for middleware in _middleware_array:
		if middleware and middleware.priority >= min_priority and middleware.priority <= max_priority:
			result.append(middleware)
	return result

## 获取中间件在执行链中的位置
## @param middleware_name: 中间件名称
## @return: int，位置索引，如果不存在返回-1
func get_middleware_index(middleware_name: String) -> int:
	"""
	获取中间件在执行链中的位置
	
	@param middleware_name: 中间件名称
	@return: int，位置索引，如果不存在返回-1
	"""
	for i in range(_middleware_array.size()):
		if _middleware_array[i].middleware_name == middleware_name:
			return i
	return -1

## 获取指定位置的中间件
## @param index: 位置索引
## @return: JuicyMiddleware，中间件实例，如果索引无效返回null
func get_middleware_at_index(index: int) -> JuicyMiddleware:
	"""
	获取指定位置的中间件
	
	@param index: 位置索引
	@return: JuicyMiddleware，中间件实例，如果索引无效返回null
	"""
	if index >= 0 and index < _middleware_array.size():
		return _middleware_array[index]
	return null

# =============================================================================
# 优先级排序
# =============================================================================

## 按优先级排序中间件
func _sort_middleware_by_priority() -> void:
	"""
	按优先级对中间件进行排序
	优先级数字越小，执行顺序越靠前
	"""
	_middleware_array.sort_custom(_sort_by_priority_func)

## 优先级排序函数
func _sort_by_priority_func(a: JuicyMiddleware, b: JuicyMiddleware) -> bool:
	"""
	优先级排序比较函数
	
	@param a: 第一个中间件
	@param b: 第二个中间件
	@return: bool，a是否应该在b前面
	"""
	if not a or not b:
		return false
	return a.priority < b.priority

## 设置中间件优先级
## @param middleware_name: 中间件名称
## @param priority: 新的优先级
## @return: bool，是否成功
func set_middleware_priority(middleware_name: String, priority: int) -> bool:
	"""
	设置中间件的优先级
	
	@param middleware_name: 中间件名称
	@param priority: 新的优先级
	@return: bool，是否成功
	"""
	var middleware = get_middleware(middleware_name)
	if not middleware:
		_log_error(ErrorCode.MIDDLEWARE_NOT_FOUND, "Middleware not found", {"middleware_name": middleware_name})
		return false
	
	var old_priority = middleware.priority
	middleware.priority = priority
	
	if old_priority != priority:
		_log_debug("Middleware priority changed", {
			"middleware_name": middleware_name,
			"old_priority": old_priority,
			"new_priority": priority
		})
		
		# 重新排序
		_sort_middleware_by_priority()
		_execution_chain_dirty = true
	
	return true

## 获取中间件优先级
## @param middleware_name: 中间件名称
## @return: int，优先级，如果不存在返回-1
func get_middleware_priority(middleware_name: String) -> int:
	"""
	获取中间件的优先级
	
	@param middleware_name: 中间件名称
	@return: int，优先级，如果不存在返回-1
	"""
	var middleware = get_middleware(middleware_name)
	return middleware.priority if middleware else -1

# =============================================================================
# 管道执行
# =============================================================================

## 执行管道
## @param context: JuicyContext实例
## @return: bool，执行是否成功
func execute(context: JuicyContext) -> bool:
	"""
	执行中间件管道
	
	@param context: JuicyContext实例
	@return: bool，执行是否成功
	"""
	# 检查管道状态
	if _state != PipelineState.READY:
		_log_error(ErrorCode.PIPELINE_NOT_READY, "Pipeline not ready", {"state": _state})
		return false
	
	# 验证Context
	if not _validate_context(context):
		return false
	
	# 设置当前Context
	_current_context = context
	
	# 开始执行
	_state = PipelineState.EXECUTING
	pipeline_state_changed.emit(_state)
	
	# 发送执行开始信号
	execution_started.emit(context)
	
	# 开始性能监控
	var start_time = _start_execution_timer()
	
	var success = false
	var retry_count = 0
	
	# 重试机制
	while retry_count <= max_retry_attempts:
		# 构建执行链
		if _execution_chain_dirty:
			if not _build_execution_chain():
				_log_error(ErrorCode.EXECUTION_FAILED, "Failed to build execution chain")
				break
			_execution_chain_dirty = false
		
		# 执行中间件链
		success = _execute_middleware_chain()
		
		if success or not enable_error_recovery:
			break
		
		# 检查是否达到重试上限
		if retry_count >= max_retry_attempts:
			var failed_info = _get_failed_middleware_info()
			_log_error(ErrorCode.EXECUTION_FAILED,
				"Execution failed after maximum retry attempts",
				{
					"retry_count": retry_count,
					"max_retries": max_retry_attempts,
					"failed_middleware_info": failed_info
				})
			break
		
		# 错误恢复
		retry_count += 1
		_retry_count += 1
		_log_warning("Execution failed, retrying", {
			"retry_count": retry_count,
			"max_retries": max_retry_attempts
		})
		
		# 移除await，让重试在同一帧内完成，避免串行化
		# await Engine.get_main_loop().process_frame
	
	# 结束性能监控
	_end_execution_timer(start_time)
	
	# 恢复管道状态
	_state = PipelineState.READY
	pipeline_state_changed.emit(_state)
	
	# 发送执行完成信号
	execution_completed.emit(context, success)
	
	# 重置当前Context
	_current_context = null
	
	return success

## 构建执行链
## @return: bool，构建是否成功
func _build_execution_chain() -> bool:
	"""
	构建中间件执行链
	
	@return: bool，构建是否成功
	"""
	_execution_chain.clear()
	
	# 为每个激活的中间件创建执行函数
	for i in range(_middleware_array.size()):
		var middleware = _middleware_array[i]
		if middleware and middleware.is_active and middleware.is_ready():
			var execution_func = _create_middleware_execution_func(middleware, i)
			_execution_chain.append(execution_func)
		else:
			_log_debug("Skipping middleware", {
				"middleware_name": middleware.middleware_name if middleware else "null",
				"active": middleware.is_active if middleware else false,
				"ready": middleware.is_ready() if middleware else false
			})
	
	_log_debug("Execution chain built", {
		"chain_length": _execution_chain.size(),
		"total_middleware": _middleware_array.size()
	})
	
	return true

## 创建中间件执行函数
## @param middleware: 中间件实例
## @param middleware_index: 中间件在执行链中的索引
## @return: Callable，执行函数
func _create_middleware_execution_func(middleware: JuicyMiddleware, middleware_index: int) -> Callable:
	"""
	创建中间件的执行函数
	
	@param middleware: 中间件实例
	@param middleware_index: 中间件在执行链中的索引
	@return: Callable，执行函数
	"""
	# 创建闭包来捕获中间件引用和索引
	return func(context: JuicyContext) -> bool:
		# 优化：移除调试输出，提高性能
		
		# 处理Context生命周期事件
		middleware.handle_context_event(context, "created")
		
		# 创建下一个中间件的回调函数
		var next_func = func() -> bool:
			var next_index = middleware_index + 1
			if next_index < _execution_chain.size():
				# 优化：移除调试输出，提高性能
				return _execution_chain[next_index].call(context)
			else:
				# 优化：移除调试输出，提高性能
				return true
		
		# 执行中间件处理逻辑
		var result = middleware.execute(context, next_func)
		
		# 优化：移除调试输出，提高性能
		
		# 如果执行失败，清理Context
		if not result:
			middleware.handle_context_event(context, "destroyed")
		
		return result

## 创建下一个中间件的回调函数
## @return: Callable，回调函数
func _create_next_func() -> Callable:
	"""
	创建下一个中间件的回调函数
	
	@return: Callable，回调函数
	"""
	var current_index = -1  # 从-1开始，第一次调用会变成0
	
	return func() -> bool:
		current_index += 1
		
		# 如果还有下一个中间件，执行它
		if current_index < _execution_chain.size():
			# 优化：移除调试输出，提高性能
			return _execution_chain[current_index].call(_current_context)
		
		# 所有中间件执行完成
		# 优化：移除调试输出，提高性能
		return true

## 执行中间件链
## @return: bool，执行是否成功
func _execute_middleware_chain() -> bool:
	"""
	执行完整的中间件链
	
	@return: bool，执行是否成功
	"""
	if _execution_chain.is_empty():
		_log_error(ErrorCode.EXECUTION_FAILED, "Execution chain is empty")
		return false
	
	# 优化：移除调试输出，提高性能
	
	var success = true
	
	# 执行第一个中间件
	success = _execution_chain[0].call(_current_context)
	
	# 优化：移除调试输出，提高性能
	
	# 如果执行成功，清理所有中间件
	if success:
		for middleware in _middleware_array:
			if middleware and middleware.is_active:
				middleware.cleanup(_current_context)
				middleware.handle_context_event(_current_context, "destroyed")
	
	return success

## 验证Context
## @param context: 要验证的Context
## @return: bool，是否有效
func _validate_context(context: JuicyContext) -> bool:
	"""
	验证Context是否有效
	
	@param context: 要验证的Context
	@return: bool，是否有效
	"""
	if not context:
		_log_error(ErrorCode.CONTEXT_INVALID, "Context is null")
		return false
	
	# 对于中间件系统，Context的基本结构就足够了
	# 不强制要求resource和target，因为有些中间件可能不需要这些
	# 中间件可以在执行过程中自己验证所需的数据
	
	# 只检查Context的基本结构
	if not context.has_method("reset"):
		_log_error(ErrorCode.CONTEXT_INVALID, "Context missing required methods")
		return false
	
	return true

## 验证中间件
## @param middleware: 要验证的中间件
## @return: bool，是否有效
func _validate_middleware(middleware: JuicyMiddleware) -> bool:
	"""
	验证中间件是否有效
	
	@param middleware: 要验证的中间件
	@return: bool，是否有效
	"""
	if not middleware:
		_log_error(ErrorCode.INVALID_MIDDLEWARE, "Middleware is null")
		return false
	
	if middleware.middleware_name.is_empty():
		_log_error(ErrorCode.INVALID_MIDDLEWARE, "Middleware name is empty")
		return false
	
	if middleware in _middleware_array:
		_log_error(ErrorCode.MIDDLEWARE_ALREADY_EXISTS, "Middleware already in pipeline", {"middleware_name": middleware.middleware_name})
		return false
	
	return true

# =============================================================================
# 性能监控
# =============================================================================

## 开始执行计时
## @return: float，开始时间戳
func _start_execution_timer() -> float:
	"""
	开始执行计时
	
	@return: float，开始时间戳
	"""
	if enable_performance_monitoring:
		_performance_start_time = Time.get_ticks_usec()
	return _performance_start_time

## 结束执行计时
## @param start_time: 开始时间戳
func _end_execution_timer(start_time: float) -> void:
	"""
	结束执行计时并更新统计
	
	@param start_time: 开始时间戳
	"""
	if enable_performance_monitoring and start_time > 0:
		_last_execution_time = (Time.get_ticks_usec() - start_time) / 1000.0  # 转换为毫秒
		_execution_count += 1
		_total_execution_time += _last_execution_time

## 获取管道性能统计
## @return: Dictionary，性能统计字典
func get_performance_stats() -> Dictionary:
	"""
	获取管道性能统计信息
	
	@return: Dictionary，性能统计字典
	"""
	return {
		"pipeline_name": pipeline_name,
		"version": version,
		"execution_count": _execution_count,
		"total_execution_time": _total_execution_time,
		"average_execution_time": _total_execution_time / max(_execution_count, 1),
		"last_execution_time": _last_execution_time,
		"error_count": _error_count,
		"retry_count": _retry_count,
		"middleware_count": get_middleware_count(),
		"active_middleware_count": get_active_middleware_count(),
		"state": _state
	}

## 重置性能统计
func reset_performance_stats() -> void:
	"""
	重置所有性能统计信息
	"""
	_execution_count = 0
	_total_execution_time = 0.0
	_last_execution_time = 0.0
	_error_count = 0
	_retry_count = 0
	
	_log_debug("Performance stats reset")

## 获取中间件性能统计
## @return: Array[Dictionary]，中间件性能统计数组
func get_middleware_performance_stats() -> Array[Dictionary]:
	"""
	获取所有中间件的性能统计
	
	@return: Array[Dictionary]，中间件性能统计数组
	"""
	var stats: Array[Dictionary] = []
	for middleware in _middleware_array:
		if middleware:
			stats.append(middleware.get_performance_stats())
	return stats

# =============================================================================
# 错误处理
# =============================================================================

## 获取最后错误代码
## @return: ErrorCode，错误代码
func get_last_error_code() -> ErrorCode:
	"""
	获取最后错误代码
	
	@return: ErrorCode，错误代码
	"""
	return _last_error_code

## 获取最后错误消息
## @return: String，错误消息
func get_last_error_message() -> String:
	"""
	获取最后错误消息
	
	@return: String，错误消息
	"""
	return _last_error_message

## 获取最后错误详情
## @return: Dictionary，错误详情
func get_last_error_details() -> Dictionary:
	"""
	获取最后错误详情
	
	@return: Dictionary，错误详情
	"""
	return _last_error_details.duplicate()

## 清除错误状态
func clear_error_state() -> void:
	"""
	清除错误状态
	"""
	_last_error_code = ErrorCode.NONE
	_last_error_message = ""
	_last_error_details.clear()

## 记录错误
## @param error_code: 错误代码
## @param message: 错误消息
## @param details: 错误详情
func _log_error(error_code: ErrorCode, message: String, details: Dictionary = {}) -> void:
	"""
	记录错误
	
	@param error_code: 错误代码
	@param message: 错误消息
	@param details: 错误详情
	"""
	_last_error_code = error_code
	_last_error_message = message
	_last_error_details = details.duplicate()
	
	_error_count += 1
	
	var log_entry = {
		"timestamp": Time.get_datetime_string_from_system(),
		"level": "ERROR",
		"error_code": error_code,
		"message": message,
		"details": details,
		"pipeline": pipeline_name,
		"state": _state
	}
	
	_error_log.append(log_entry)
	
	# 限制日志条目数
	if _error_log.size() > _max_log_entries:
		_error_log.pop_front()
	
	if enable_debug_logging:
		printerr("[JuicyMiddlewarePipeline ERROR] " + pipeline_name + ": " + message)
		if not details.is_empty():
			printerr("  Details: " + str(details))
	
	# 发送错误信号
	if _current_context:
		execution_error.emit(_current_context, log_entry)

## 记录警告
## @param message: 警告消息
## @param details: 警告详情
func _log_warning(message: String, details: Dictionary = {}) -> void:
	"""
	记录警告
	
	@param message: 警告消息
	@param details: 警告详情
	"""
	var log_entry = {
		"timestamp": Time.get_datetime_string_from_system(),
		"level": "WARNING",
		"message": message,
		"details": details,
		"pipeline": pipeline_name
	}
	
	_debug_log.append(log_entry)
	
	# 限制日志条目数
	if _debug_log.size() > _max_log_entries:
		_debug_log.pop_front()
	
	if enable_debug_logging:
		print("[JuicyMiddlewarePipeline WARNING] " + pipeline_name + ": " + message)
		if not details.is_empty():
			print("  Details: " + str(details))

## 记录调试信息
## @param message: 调试消息
## @param details: 调试详情
func _log_debug(message: String, details: Dictionary = {}) -> void:
	"""
	记录调试信息
	
	@param message: 调试消息
	@param details: 调试详情
	"""
	if not enable_debug_logging:
		return
	
	var log_entry = {
		"timestamp": Time.get_datetime_string_from_system(),
		"level": "DEBUG",
		"message": message,
		"details": details,
		"pipeline": pipeline_name
	}
	
	_debug_log.append(log_entry)
	
	# 限制日志条目数
	if _debug_log.size() > _max_log_entries:
		_debug_log.pop_front()
	
	print("[JuicyMiddlewarePipeline DEBUG] " + pipeline_name + ": " + message)
	if not details.is_empty():
		print("  Details: " + str(details))

# =============================================================================
# 日志管理
# =============================================================================

## 获取错误日志
## @return: Array[Dictionary]，错误日志数组
func get_error_log() -> Array[Dictionary]:
	"""
	获取错误日志
	
	@return: Array[Dictionary]，错误日志数组
	"""
	return _error_log.duplicate()

## 获取调试日志
## @return: Array[Dictionary]，调试日志数组
func get_debug_log() -> Array[Dictionary]:
	"""
	获取调试日志
	
	@return: Array[Dictionary]，调试日志数组
	"""
	return _debug_log.duplicate()

## 清除所有日志
func clear_logs() -> void:
	"""
	清除所有日志
	"""
	_error_log.clear()
	_debug_log.clear()
	_log_debug("Logs cleared")

## 导出日志到文件
## @param file_path: 文件路径
## @return: bool，是否成功
func export_logs(file_path: String) -> bool:
	"""
	导出日志到文件
	
	@param file_path: 文件路径
	@return: bool，是否成功
	"""
	var logs = _error_log + _debug_log
	logs.sort_custom(_sort_logs_by_timestamp)
	
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		_log_error(ErrorCode.CONFIGURATION_ERROR, "Failed to open file for export", {"file_path": file_path})
		return false
	
	for log_entry in logs:
		file.store_line(JSON.stringify(log_entry))
	
	file.close()
	
	_log_debug("Logs exported", {"file_path": file_path, "entry_count": logs.size()})
	return true

## 日志时间戳排序函数
func _sort_logs_by_timestamp(a: Dictionary, b: Dictionary) -> bool:
	"""
	日志时间戳排序比较函数
	
	@param a: 第一个日志条目
	@param b: 第二个日志条目
	@return: bool，a是否应该在b前面
	"""
	return a.timestamp < b.timestamp

# =============================================================================
# 配置管理
# =============================================================================

## 获取管道配置
## @return: Dictionary，配置字典
func get_configuration() -> Dictionary:
	"""
	获取管道配置
	
	@return: Dictionary，配置字典
	"""
	return {
		"pipeline_name": pipeline_name,
		"description": description,
		"version": version,
		"enable_performance_monitoring": enable_performance_monitoring,
		"enable_debug_logging": enable_debug_logging,
		"enable_error_recovery": enable_error_recovery,
		"max_retry_attempts": max_retry_attempts,
		"execution_timeout": execution_timeout,
		"middleware_count": get_middleware_count(),
		"active_middleware_count": get_active_middleware_count()
	}

## 设置管道配置
## @param config: 配置字典
## @return: bool，是否成功
func set_configuration(config: Dictionary) -> bool:
	"""
	设置管道配置
	
	@param config: 配置字典
	@return: bool，是否成功
	"""
	if _state == PipelineState.EXECUTING:
		_log_error(ErrorCode.CONFIGURATION_ERROR, "Cannot configure pipeline while executing")
		return false
	
	# 应用配置
	_apply_configuration(config)
	
	_log_debug("Pipeline configuration updated", {"config": config})
	return true

## 重置到默认配置
func reset_to_default_configuration() -> void:
	"""
	重置到默认配置
	"""
	var default_config = {
		"pipeline_name": "DefaultPipeline",
		"description": "",
		"version": "1.0.0",
		"enable_performance_monitoring": true,
		"enable_debug_logging": false,
		"enable_error_recovery": true,
		"max_retry_attempts": 3,
		"execution_timeout": 1000.0
	}
	
	set_configuration(default_config)

# =============================================================================
# 状态查询
# =============================================================================

## 获取管道状态
## @return: PipelineState，管道状态
func get_state() -> PipelineState:
	"""
	获取管道状态
	
	@return: PipelineState，管道状态
	"""
	return _state

## 检查管道是否就绪
## @return: bool，是否就绪
func is_ready() -> bool:
	"""
	检查管道是否就绪
	
	@return: bool，是否就绪
	"""
	return _state == PipelineState.READY

## 检查管道是否正在执行
## @return: bool，是否正在执行
func is_executing() -> bool:
	"""
	检查管道是否正在执行
	
	@return: bool，是否正在执行
	"""
	return _state == PipelineState.EXECUTING

## 检查管道是否有错误
## @return: bool，是否有错误
func has_error() -> bool:
	"""
	检查管道是否有错误
	
	@return: bool，是否有错误
	"""
	return _last_error_code != ErrorCode.NONE

## 获取管道信息
## @return: Dictionary，管道信息字典
func get_pipeline_info() -> Dictionary:
	"""
	获取管道信息
	
	@return: Dictionary，管道信息字典
	"""
	return {
		"name": pipeline_name,
		"description": description,
		"version": version,
		"state": _state,
		"middleware_count": get_middleware_count(),
		"active_middleware_count": get_active_middleware_count(),
		"execution_count": _execution_count,
		"error_count": _error_count,
		"ready": is_ready(),
		"executing": is_executing(),
		"has_error": has_error()
	}

# =============================================================================
# 内部方法和工具
# =============================================================================

## 注册内置中间件类
func _register_builtin_middleware_classes() -> void:
	"""
	注册内置中间件类
	"""
	# 这里可以注册系统内置的中间件类
	# 例如：_middleware_registry["ValidationMiddleware"] = preload("validation_middleware.gd")
	pass

## 获取堆栈跟踪
## @return: String，堆栈跟踪字符串
func get_stack_trace() -> String:
	"""
	获取堆栈跟踪
	
	@return: String，堆栈跟踪字符串
	"""
	var stack = get_stack()
	var result = ""
	for i in range(1, min(stack.size(), 10)):  # 跳过当前方法，最多显示10层
		result += str(i) + ". " + stack[i] + "\n"
	return result

## 转换状态为字符串
## @param state: 管道状态
## @return: String，状态字符串
func state_to_string(state: PipelineState) -> String:
	"""
	转换状态为字符串
	
	@param state: 管道状态
	@return: String，状态字符串
	"""
	match state:
		PipelineState.IDLE:
			return "IDLE"
		PipelineState.BUILDING:
			return "BUILDING"
		PipelineState.READY:
			return "READY"
		PipelineState.EXECUTING:
			return "EXECUTING"
		PipelineState.ERROR:
			return "ERROR"
		PipelineState.DESTROYED:
			return "DESTROYED"
		_:
			return "UNKNOWN"

## 获取执行失败的中间件详细信息
## @return: Dictionary，失败的中间件信息
func _get_failed_middleware_info() -> Dictionary:
	"""
	获取执行失败的中间件详细信息
	
	@return: Dictionary，失败的中间件信息
	"""
	var failed_info = {
		"current_middleware_index": _current_middleware_index,
		"total_middleware_count": _middleware_array.size(),
		"failed_middleware": null,
		"execution_chain_length": _execution_chain.size(),
		"pipeline_state": state_to_string(_state)
	}
	
	# 获取当前失败的中间件信息
	if _current_middleware_index >= 0 and _current_middleware_index < _middleware_array.size():
		var failed_middleware = _middleware_array[_current_middleware_index]
		if failed_middleware:
			failed_info["failed_middleware"] = {
				"name": failed_middleware.middleware_name,
				"priority": failed_middleware.priority,
				"active": failed_middleware.is_active,
				"ready": failed_middleware.is_ready(),
				"tags": failed_middleware.tags
			}
	
	# 添加激活的中间件列表
	var active_middleware = []
	for middleware in _middleware_array:
		if middleware and middleware.is_active:
			active_middleware.append({
				"name": middleware.middleware_name,
				"priority": middleware.priority
			})
	failed_info["active_middleware"] = active_middleware
	
	# 添加错误状态信息
	failed_info["error_code"] = error_code_to_string(_last_error_code)
	failed_info["error_message"] = _last_error_message
	failed_info["error_details"] = _last_error_details
	
	return failed_info

## 转换错误代码为字符串
## @param error_code: 错误代码
## @return: String，错误代码字符串
func error_code_to_string(error_code: ErrorCode) -> String:
	"""
	转换错误代码为字符串
	
	@param error_code: 错误代码
	@return: String，错误代码字符串
	"""
	match error_code:
		ErrorCode.NONE:
			return "NONE"
		ErrorCode.MIDDLEWARE_NOT_FOUND:
			return "MIDDLEWARE_NOT_FOUND"
		ErrorCode.MIDDLEWARE_ALREADY_EXISTS:
			return "MIDDLEWARE_ALREADY_EXISTS"
		ErrorCode.INVALID_MIDDLEWARE:
			return "INVALID_MIDDLEWARE"
		ErrorCode.EXECUTION_FAILED:
			return "EXECUTION_FAILED"
		ErrorCode.CONFIGURATION_ERROR:
			return "CONFIGURATION_ERROR"
		ErrorCode.CONTEXT_INVALID:
			return "CONTEXT_INVALID"
		ErrorCode.PIPELINE_NOT_READY:
			return "PIPELINE_NOT_READY"
		_:
			return "UNKNOWN"
