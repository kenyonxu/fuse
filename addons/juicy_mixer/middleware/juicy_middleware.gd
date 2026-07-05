# JuicyMiddleware - 中间件基类
# 定义所有中间件的通用接口和行为
# 提供生命周期管理、性能监控、配置管理和错误处理的基础框架

@abstract
class_name JuicyMiddleware
extends RefCounted

# =============================================================================
# 中间件元信息
# =============================================================================

## 中间件名称标识，用于注册和识别
var middleware_name: String = ""

## 中间件版本号，用于版本管理和兼容性检查
var middleware_version: String = "1.0.0"

## 中间件优先级，决定执行顺序（数字越小优先级越高）
var priority: int = 0

## 中间件描述信息
var description: String = ""

## 中间件作者信息
var author: String = ""

## 中间件标签，用于分类和筛选
var tags: Array[String] = []

## 中间件激活状态，用于动态启用/禁用
var is_active: bool = true

## 是否启用性能监控
var enable_performance_monitoring: bool = true

## 是否启用调试日志
var enable_debug_logging: bool = false

# =============================================================================
# 配置管理
# =============================================================================

## 中间件配置字典
var _configuration: Dictionary = {}

## 默认配置
var _default_configuration: Dictionary = {}

## 配置模式定义
var _configuration_schema: Dictionary = {}

# =============================================================================
# 性能统计
# =============================================================================

## 执行次数统计
var _execution_count: int = 0

## 总执行时间（毫秒）
var _total_execution_time: float = 0.0

## 最后一次执行时间（毫秒）
var _last_execution_time: float = 0.0

## 错误计数
var _error_count: int = 0

## 警告计数
var _warning_count: int = 0

## 性能统计开始时间
var _performance_start_time: float = 0.0

# =============================================================================
# 错误和日志记录
# =============================================================================

## 错误日志
var _error_log: Array[Dictionary] = []

## 调试日志
var _debug_log: Array[Dictionary] = []

## 最大日志条目数
var _max_log_entries: int = 100

# =============================================================================
# 生命周期状态
# =============================================================================

## 当前上下文引用
var _current_context: JuicyContext = null

## 是否已初始化
var _is_initialized: bool = false

## 是否已配置
var _is_configured: bool = false

## 上下文计数器
var _context_count: int = 0

## 验证信任机制 - 标记前置验证是否通过
var _validation_passed: bool = false

# =============================================================================
# 核心接口 - 子类必须实现
# =============================================================================

## 处理阶段，每帧调用
## 实现中间件的核心逻辑，可以对Context进行预处理或后处理
## @param context: JuicyContext实例，包含效果运行所需的所有数据
## @param next: 下一个中间件的回调函数，用于链式执行
## @return: bool，如果返回false则中断管道执行
@abstract
func process(context: JuicyContext, next: Callable) -> bool

## 清理阶段，在效果结束时调用
## 用于清理中间件特定的数据和状态
## @param context: JuicyContext实例
func cleanup(context: JuicyContext) -> void:
	"""
	清理阶段，在效果结束时调用
	
	用于清理中间件特定的数据和状态
	
	@param context: JuicyContext实例
	"""
	pass

## 上下文创建时调用
## 在Context被创建时触发，用于初始化中间件特定的上下文数据
## @param context: 新创建的JuicyContext实例
func on_context_created(context: JuicyContext) -> void:
	"""
	上下文创建时调用
	
	在Context被创建时触发，用于初始化中间件特定的上下文数据
	
	@param context: 新创建的 JuicyContext 实例
	"""
	pass

## 上下文销毁时调用
## 在Context被销毁时触发，用于清理中间件特定的上下文数据
## @param context: 即将被销毁的JuicyContext实例
func on_context_destroyed(context: JuicyContext) -> void:
	"""
	上下文销毁时调用
	
	在Context被销毁时触发，用于清理中间件特定的上下文数据
	
	@param context: 即将被销毁的 JuicyContext 实例
	"""
	pass

## 上下文暂停时调用
## 在Context被暂停时触发，用于暂停中间件特定的处理逻辑
## @param context: 被暂停的JuicyContext实例
func on_context_paused(context: JuicyContext) -> void:
	"""
	上下文暂停时调用
	
	在Context被暂停时触发，用于暂停中间件特定的处理逻辑
	
	@param context: 被暂停的 JuicyContext 实例
	"""
	pass

## 上下文恢复时调用
## 在Context被恢复时触发，用于恢复中间件特定的处理逻辑
## @param context: 被恢复的JuicyContext实例
func on_context_resumed(context: JuicyContext) -> void:
	"""
	上下文恢复时调用
	
	在Context被恢复时触发，用于恢复中间件特定的处理逻辑
	
	@param context: 被恢复的 JuicyContext 实例
	"""
	pass

# 中间件注册时调用
func on_middleware_registered() -> void:
	pass

# 中间件移除注册时调用
func on_middleware_unregistered() -> void:
	pass

# =============================================================================
# 配置管理接口
# =============================================================================

## 配置中间件
## @param config: 配置字典
## @return: bool，配置是否成功
func configure(config: Dictionary = {}) -> bool:
	"""
	配置中间件
	
	@param config: 配置字典
	@return: bool，配置是否成功
	"""
	if not _validate_configuration(config):
		_log_error("Configuration validation failed", {"config": config})
		return false
	
	# 合并配置
	_configuration = _merge_dictionaries(_default_configuration, config)
	_is_configured = true
	
	_log_debug("Middleware configured", {"config": _configuration})
	return true

## 获取当前配置
## @return: 配置字典
func get_configuration() -> Dictionary:
	"""
	获取当前配置
	
	@return: 配置字典
	"""
	return _configuration.duplicate()

## 获取默认配置
## @return: 默认配置字典
func get_default_configuration() -> Dictionary:
	"""
	获取默认配置
	
	@return: 默认配置字典
	"""
	return _default_configuration.duplicate()

## 设置配置模式
## @param schema: 配置模式字典
func set_configuration_schema(schema: Dictionary) -> void:
	"""
	设置配置模式
	
	@param schema: 配置模式字典
	"""
	_configuration_schema = schema

## 验证配置
## @param config: 要验证的配置字典
## @return: bool，配置是否有效
func _validate_configuration(config: Dictionary) -> bool:
	"""
	验证配置
	
	@param config: 要验证的配置字典
	@return: bool，配置是否有效
	"""
	if _configuration_schema.is_empty():
		return true
	
	for key in config.keys():
		if key not in _configuration_schema:
			_log_warning("Unknown configuration key: " + key)
			continue
		
		var expected_type = _configuration_schema[key].get("type", "Variant")
		var value = config[key]
		
		if not _validate_value_type(value, expected_type):
			_log_error("Invalid configuration value type for key: " + key, {
				"key": key,
				"expected_type": expected_type,
				"actual_value": value,
				"actual_type": typeof(value)
			})
			return false
	
	return true

## 验证值类型
## @param value: 要验证的值
## @param expected_type: 期望的类型
## @return: bool，类型是否匹配
func _validate_value_type(value: Variant, expected_type: String) -> bool:
	"""
	验证值类型
	
	@param value: 要验证的值
	@param expected_type: 期望的类型
	@return: bool，类型是否匹配
	"""
	match expected_type:
		"int":
			return value is int
		"float":
			return value is float
		"bool":
			return value is bool
		"String":
			return value is String
		"Array":
			return value is Array
		"Dictionary":
			return value is Dictionary
		"Variant":
			return true
		_:
			return typeof(value) == expected_type.to_int()

## 合并字典
## @param dict1: 第一个字典
## @param dict2: 第二个字典
## @return: 合并后的字典
func _merge_dictionaries(dict1: Dictionary, dict2: Dictionary) -> Dictionary:
	"""
	合并字典
	
	@param dict1: 第一个字典
	@param dict2: 第二个字典
	@return: 合并后的字典
	"""
	var result = dict1.duplicate()
	for key in dict2.keys():
		result[key] = dict2[key]
	return result

# =============================================================================
# 验证接口
# =============================================================================

## 验证Context是否适合此中间件
## @param context: 要验证的JuicyContext实例
## @return: 验证结果字典
func validate_context(context: JuicyContext) -> Dictionary:
	"""
	验证Context是否适合此中间件
	
	@param context: 要验证的JuicyContext实例
	
	@return: 验证结果字典，包含：
		- valid: bool，是否有效
		- issues: Array[String]，错误信息列表
		- warnings: Array[String]，警告信息列表
	"""
	var result = {
		"valid": true,
		"issues": [],
		"warnings": []
	}
	
	# 检查Context是否有效
	if not context:
		result.valid = false
		result.issues.append("Context is null")
		return result
	
	# 检查必需的Context数据
	if not _validate_required_context_data(context):
		result.valid = false
	
	# 检查目标节点
	if not _validate_target_node(context):
		result.warnings.append("Target node validation failed")
	
	return result

## 验证必需的Context数据
## @param context: 要验证的JuicyContext实例
## @return: bool，验证是否通过
func _validate_required_context_data(context: JuicyContext) -> bool:
	"""
	验证必需的Context数据
	
	@param context: 要验证的JuicyContext实例
	@return: bool，验证是否通过
	"""
	# 子类可以重写此方法来验证特定的Context数据
	return true

## 验证目标节点
## @param context: 要验证的JuicyContext实例
## @return: bool，验证是否通过
func _validate_target_node(context: JuicyContext) -> bool:
	"""
	验证目标节点
	
	@param context: 要验证的JuicyContext实例
	@return: bool，验证是否通过
	"""
	if not context.target:
		return false
	
	# 子类可以重写此方法来验证特定的目标节点属性
	return true

# =============================================================================
# 性能监控
# =============================================================================

## 获取性能统计信息
## @return: 性能统计字典
func get_performance_stats() -> Dictionary:
	"""
	获取性能统计信息
	
	@return: 性能统计字典，包含：
		- execution_count: int，总执行次数
		- total_execution_time: float，总执行时间（毫秒）
		- average_execution_time: float，平均执行时间（毫秒）
		- last_execution_time: float，最后一次执行时间（毫秒）
		- error_count: int，错误计数
		- warning_count: int，警告计数
	"""
	return {
		"middleware_name": middleware_name,
		"middleware_version": middleware_version,
		"execution_count": _execution_count,
		"total_execution_time": _total_execution_time,
		"average_execution_time": _total_execution_time / max(_execution_count, 1),
		"last_execution_time": _last_execution_time,
		"error_count": _error_count,
		"warning_count": _warning_count,
		"context_count": _context_count
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
	_warning_count = 0
	_context_count = 0
	
	_log_debug("Performance stats reset")

## 开始执行计时
func _start_execution_timer() -> float:
	"""
	开始执行计时
	总是记录开始时间，避免标志在执行过程中改变导致计时错误

	@return: 当前时间戳（微秒）
	"""
	_performance_start_time = Time.get_ticks_usec()
	return _performance_start_time

## 结束执行计时并更新统计
func _end_execution_timer(start_time: float) -> void:
	"""
	结束执行计时并更新统计
	只在启用性能监控时更新统计，但总是计算经过的时间

	@param start_time: _start_execution_timer()返回的时间戳
	"""
	var elapsed = (Time.get_ticks_usec() - start_time) / 1000.0  # 转换为毫秒

	if enable_performance_monitoring:
		_last_execution_time = elapsed
		_execution_count += 1
		_total_execution_time += elapsed

# =============================================================================
# 日志记录方法
# =============================================================================

## 记录错误
## @param message: 错误消息
## @param data: 附加数据字典
func _log_error(message: String, data: Dictionary = {}) -> void:
	"""
	记录错误
	
	@param message: 错误消息
	@param data: 附加数据字典
	"""
	_error_count += 1
	
	var log_entry = {
		"timestamp": Time.get_datetime_string_from_system(),
		"level": "ERROR",
		"message": message,
		"data": data,
		"middleware": middleware_name
	}
	
	_error_log.append(log_entry)
	
	# 限制日志条目数
	if _error_log.size() > _max_log_entries:
		_error_log.pop_front()
	
	if enable_debug_logging:
		printerr("[JuicyMiddleware ERROR] " + middleware_name + ": " + message)
		if not data.is_empty():
			printerr("  Data: " + str(data))

## 记录警告
## @param message: 警告消息
## @param data: 附加数据字典
func _log_warning(message: String, data: Dictionary = {}) -> void:
	"""
	记录警告
	
	@param message: 警告消息
	@param data: 附加数据字典
	"""
	_warning_count += 1
	
	var log_entry = {
		"timestamp": Time.get_datetime_string_from_system(),
		"level": "WARNING",
		"message": message,
		"data": data,
		"middleware": middleware_name
	}
	
	_debug_log.append(log_entry)
	
	# 限制日志条目数
	if _debug_log.size() > _max_log_entries:
		_debug_log.pop_front()
	
	if enable_debug_logging:
		print("[JuicyMiddleware WARNING] " + middleware_name + ": " + message)
		if not data.is_empty():
			print("  Data: " + str(data))

## 记录调试信息
## @param message: 调试消息
## @param data: 附加数据字典
func _log_debug(message: String, data: Dictionary = {}) -> void:
	"""
	记录调试信息
	
	@param message: 调试消息
	@param data: 附加数据字典
	"""
	if not enable_debug_logging:
		return
	
	var log_entry = {
		"timestamp": Time.get_datetime_string_from_system(),
		"level": "DEBUG",
		"message": message,
		"data": data,
		"middleware": middleware_name
	}
	
	_debug_log.append(log_entry)
	
	# 限制日志条目数
	if _debug_log.size() > _max_log_entries:
		_debug_log.pop_front()
	
	print("[JuicyMiddleware DEBUG] " + middleware_name + ": " + message)
	if not data.is_empty():
		print("  Data: " + str(data))

## 获取错误日志
## @return: 错误日志数组
func get_error_log() -> Array[Dictionary]:
	"""
	获取错误日志
	
	@return: 错误日志数组
	"""
	return _error_log.duplicate()

## 获取调试日志
## @return: 调试日志数组
func get_debug_log() -> Array[Dictionary]:
	"""
	获取调试日志
	
	@return: 调试日志数组
	"""
	return _debug_log.duplicate()

## 清除日志
func clear_logs() -> void:
	"""
	清除所有日志
	"""
	_error_log.clear()
	_debug_log.clear()
	_log_debug("Logs cleared")

# =============================================================================
# 生命周期管理
# =============================================================================

## 初始化中间件
## @param config: 初始配置字典
func initialize(config: Dictionary = {}) -> bool:
	"""
	初始化中间件
	
	@param config: 初始配置字典
	@return: bool，初始化是否成功
	"""
	if _is_initialized:
		_log_warning("Middleware already initialized")
		return true
	
	# 设置默认配置
	_setup_default_configuration()
	
	# 配置中间件
	if not configure(config):
		return false
	
	_is_initialized = true
	_log_debug("Middleware initialized", {"config": _configuration})
	
	return true

## 设置默认配置
## 子类可以重写此方法来设置特定的默认配置
func _setup_default_configuration() -> void:
	"""
	设置默认配置
	
	子类可以重写此方法来设置特定的默认配置
	"""
	_default_configuration = {
		"enable_performance_monitoring": true,
		"enable_debug_logging": false,
		"priority": 0,
		"max_log_entries": 100
	}
	
	# 设置配置模式
	set_configuration_schema({
		"enable_performance_monitoring": {"type": "bool"},
		"enable_debug_logging": {"type": "bool"},
		"priority": {"type": "int"},
		"max_log_entries": {"type": "int"}
	})

## 销毁中间件
func destroy() -> void:
	"""
	销毁中间件
	
	清理所有资源并重置状态
	"""
	if not _is_initialized:
		return
	
	# 清理日志
	clear_logs()
	
	# 重置状态
	_configuration.clear()
	_default_configuration.clear()
	_configuration_schema.clear()
	_current_context = null
	_is_initialized = false
	_is_configured = false
	
	_log_debug("Middleware destroyed")

## 处理Context生命周期事件
## @param context: JuicyContext实例
## @param event: 生命周期事件类型
func handle_context_event(context: JuicyContext, event: String) -> void:
	"""
	处理Context生命周期事件
	
	@param context: JuicyContext实例
	@param event: 生命周期事件类型
	"""
	_current_context = context
	
	match event:
		"created":
			_context_count += 1
			on_context_created(context)
			_log_debug("Context created", {"context_id": context.context_id})
		
		"destroyed":
			on_context_destroyed(context)
			_log_debug("Context destroyed", {"context_id": context.context_id})
		
		"paused":
			on_context_paused(context)
			_log_debug("Context paused", {"context_id": context.context_id})
		
		"resumed":
			on_context_resumed(context)
			_log_debug("Context resumed", {"context_id": context.context_id})

## 执行处理逻辑
## @param context: JuicyContext实例
## @param next: 下一个中间件的回调函数
## @return: bool，执行是否成功
func execute(context: JuicyContext, next: Callable) -> bool:
	"""
	执行处理逻辑
	
	@param context: JuicyContext实例
	@param next: 下一个中间件的回调函数
	@return: bool，执行是否成功
	"""
	if not _is_initialized:
		_log_error("Middleware not initialized")
		return false
	
	if not is_active:
		_log_debug("Middleware is not active, skipping")
		return next.call()
	
	# 验证信任机制：让非ValidationMiddleware中间件可以信任前置验证结果
	# 如果当前是ValidationMiddleware，则执行完整的验证逻辑
	# 否则，如果_validation_passed为true，则跳过重复验证
	if not _should_skip_validation():
		# 验证Context
		var validation = validate_context(context)
		if not validation.valid:
			_log_error("Context validation failed", {"validation": validation})
			return false
	
	# 开始性能监控
	var start_time = _start_execution_timer()
	
	# 执行处理逻辑
	var result = true
	var error_occurred = false
	
	# 执行处理逻辑并捕获错误
	result = process(context, next)
	if not result:
		error_occurred = true
		_log_error("Middleware execution returned false", {"context_id": context.context_id})
	
	# 结束性能监控
	_end_execution_timer(start_time)
	
	if error_occurred:
		_log_error("Middleware execution failed", {"context_id": context.context_id})
	
	return result

# =============================================================================
# 工具方法
# =============================================================================

## 获取中间件信息
## @return: 中间件信息字典
func get_middleware_info() -> Dictionary:
	"""
	获取中间件信息
	
	@return: 中间件信息字典，包含：
		- name: String，中间件名称
		- version: String，版本号
		- priority: int，优先级
		- description: String，描述
		- author: String，作者
		- tags: Array[String]，标签
		- active: bool，激活状态
		- configured: bool，已配置状态
		- initialized: bool，已初始化状态
	"""
	return {
		"name": middleware_name,
		"version": middleware_version,
		"priority": priority,
		"description": description,
		"author": author,
		"tags": tags.duplicate(),
		"active": is_active,
		"configured": _is_configured,
		"initialized": _is_initialized
	}

## 检查中间件是否准备好执行
## @return: bool，是否准备好执行
func is_ready() -> bool:
	"""
	检查中间件是否准备好执行
	
	@return: bool，是否准备好执行
	"""
	return _is_initialized and _is_configured and is_active

## 获取当前上下文
## @return: 当前JuicyContext实例
func get_current_context() -> JuicyContext:
	"""
	获取当前上下文
	
	@return: 当前JuicyContext实例
	"""
	return _current_context

## 设置激活状态
## @param active: 激活状态
func set_active(active: bool) -> void:
	"""
	设置激活状态
	
	@param active: 激活状态
	"""
	var old_state = is_active
	is_active = active
	
	if old_state != active:
		_log_debug("Activation state changed", {"old": old_state, "new": active})

## 设置调试日志状态
## @param enabled: 是否启用调试日志
func set_debug_logging(enabled: bool) -> void:
	"""
	设置调试日志状态
	
	@param enabled: 是否启用调试日志
	"""
	enable_debug_logging = enabled
	_log_debug("Debug logging " + ("enabled" if enabled else "disabled"))

## 设置性能监控状态
## @param enabled: 是否启用性能监控
func set_performance_monitoring(enabled: bool) -> void:
	"""
	设置性能监控状态
	
	@param enabled: 是否启用性能监控
	"""
	enable_performance_monitoring = enabled
	_log_debug("Performance monitoring " + ("enabled" if enabled else "disabled"))

## 获取堆栈跟踪
## @return: 堆栈跟踪字符串
func get_stack_trace() -> String:
	"""
	获取堆栈跟踪
	
	@return: 堆栈跟踪字符串
	"""
	var stack = get_stack()
	var result = ""
	for i in range(1, min(stack.size(), 10)):  # 跳过当前方法，最多显示10层
		result += str(i) + ". " + stack[i] + "\n"
	return result

## 验证信任机制 - 判断是否应该跳过验证
## @return: bool，是否应该跳过验证
func _should_skip_validation() -> bool:
	"""
	验证信任机制 - 判断是否应该跳过验证
	
	@return: bool，是否应该跳过验证
	"""
	# 如果当前是ValidationMiddleware，则不跳过验证
	if self is ValidationMiddleware:
		return false
	
	# 如果前置验证已经通过，则跳过重复验证
	if _validation_passed:
		return true
	
	# 默认不跳过验证
	return false

## 设置验证通过状态
## @param passed: 验证是否通过
func set_validation_passed(passed: bool) -> void:
	"""
	设置验证通过状态
	
	@param passed: 验证是否通过
	"""
	_validation_passed = passed
	_log_debug("Validation state updated", {"passed": passed})