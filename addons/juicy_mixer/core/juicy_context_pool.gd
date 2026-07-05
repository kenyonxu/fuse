# JuicyContextPool - 上下文对象池
# 管理Context对象池，提供高效的Context分配
# 实现内存优化，支持池大小动态调整

class_name JuicyContextPool
extends RefCounted

# 对象池管理
var _available_contexts: Array[JuicyContext] = []
var _active_contexts: Dictionary = {}  # internal_id -> JuicyContext
var _context_to_internal_id: Dictionary = {}  # JuicyContext -> internal_id
var _next_internal_id: int = 1
var _pool_size: int = 100
var _max_pool_size: int = 500
var _min_pool_size: int = 10
var _auto_resize: bool = true
var _resize_threshold: float = 0.8

# 统计信息
var _total_allocated: int = 0
var _total_reused: int = 0
var _peak_usage: int = 0
var _resize_count: int = 0
var _cleanup_count: int = 0

# 池配置
var _warm_up_count: int = 20
var _cleanup_interval: float = 5.0  # 秒
var _last_cleanup_time: float = 0.0
var _prewarmed: bool = false  # 是否已预热

# 性能优化
var _enable_smart_cleanup: bool = true
var _max_idle_time: float = 60.0  # 最大空闲时间
var _enable_efficiency_tracking: bool = true

# 调试和监控
var _enable_debug_logging: bool = false
var _performance_history: Array[Dictionary] = []
var _max_history_size: int = 100

# 构造函数
func _init(initial_size: int = 100):
	_pool_size = initial_size
	_pool_size = clamp(_pool_size, _min_pool_size, _max_pool_size)

# 获取Context
func get_context() -> JuicyContext:
	var context: JuicyContext = null
	var internal_id: String = "internal_" + str(_next_internal_id)
	_next_internal_id += 1
	
	# 优先从可用池中获取
	if _available_contexts.size() > 0:
		context = _available_contexts.pop_back()
		context.reset()  # 重置会改变context_id，但我们使用内部ID跟踪
		_total_reused += 1
		
		if _enable_debug_logging:
			_log_debug("Reused context from pool", {
				"context_id": context.context_id,
				"internal_id": internal_id,
				"available_count": _available_contexts.size(),
				"total_reused": _total_reused
			})
	else:
		# 池为空，创建新Context
		context = JuicyContext.new()
		# 确保新Context有有效的ID
		if context.context_id.is_empty():
			context.context_id = _generate_context_id()
		_total_allocated += 1
		
		if _enable_debug_logging:
			_log_debug("Created new context", {
				"context_id": context.context_id,
				"internal_id": internal_id,
				"total_allocated": _total_allocated
			})
	
	# 注册到活跃列表（使用内部ID）
	_active_contexts[internal_id] = context
	_context_to_internal_id[context] = internal_id
	
	# 更新峰值使用量
	var current_usage = _active_contexts.size()
	if current_usage > _peak_usage:
		_peak_usage = current_usage
		
		if _enable_debug_logging:
			_log_debug("New peak usage", {
				"peak_usage": _peak_usage,
				"current_usage": current_usage
			})
	
	# 记录性能数据
	_record_performance_metrics()
	
	return context

# 返回Context到池中
func return_context(context: JuicyContext) -> void:
	if not context:
		_log_warning("Attempted to return null context")
		return
	
	# 使用内部ID查找
	var internal_id = _context_to_internal_id.get(context, "")
	if internal_id.is_empty() or not _active_contexts.has(internal_id):
		_log_warning("Context not found in active list", {
			"context_id": context.context_id,
			"internal_id": internal_id
		})
		return
	
	# 从活跃列表移除
	_active_contexts.erase(internal_id)
	_context_to_internal_id.erase(context)
	
	# 重置Context状态
	context.reset()
	
	# 返回池中
	if _available_contexts.size() < _pool_size:
		_available_contexts.append(context)
		
		if _enable_debug_logging:
			_log_debug("Context returned to pool", {
				"context_id": context.context_id,
				"internal_id": internal_id,
				"available_count": _available_contexts.size()
			})
	else:
		# 池已满，让GC回收
		if _enable_debug_logging:
			_log_debug("Pool full, context will be GC'd", {
				"context_id": context.context_id,
				"internal_id": internal_id,
				"pool_size": _pool_size
			})

# 预热池
func warm_up(count: int) -> void:
	if _prewarmed:
		_log_debug("Pool already warmed up")
		return
	
	var actual_count = min(count, _pool_size)
	for i in range(actual_count):
		var context = JuicyContext.new()
		# 确保新Context有有效的ID
		if context.context_id.is_empty():
			context.context_id = _generate_context_id()
		_available_contexts.append(context)
		_total_allocated += 1
	
	_prewarmed = true
	
	_log_debug("Pool warmed up", {
		"warm_up_count": actual_count,
		"total_allocated": _total_allocated
	})

# 系统预热方法，用于游戏加载时调用
# 注意：此方法应在全局池管理器中调用
func warm_up_system() -> void:
	# 预热Context池
	warm_up(50)
	
	print("JuicyContextPool warmed up successfully")

# 设置池大小
func set_pool_size(size: int) -> void:
	var old_size = _pool_size
	_pool_size = clamp(size, _min_pool_size, _max_pool_size)
	
	if old_size != _pool_size:
		_adjust_pool_size()
		_log_debug("Pool size changed", {
			"old_size": old_size,
			"new_size": _pool_size
		})

# 设置最大池大小
func set_max_pool_size(size: int) -> void:
	var old_max = _max_pool_size
	_max_pool_size = max(size, _min_pool_size)
	_pool_size = min(_pool_size, _max_pool_size)
	
	if old_max != _max_pool_size:
		_adjust_pool_size()
		_log_debug("Max pool size changed", {
			"old_max": old_max,
			"new_max": _max_pool_size
		})

# 设置最小池大小
func set_min_pool_size(size: int) -> void:
	var old_min = _min_pool_size
	_min_pool_size = max(size, 1)
	_pool_size = max(_pool_size, _min_pool_size)
	
	if old_min != _min_pool_size:
		_adjust_pool_size()
		_log_debug("Min pool size changed", {
			"old_min": old_min,
			"new_min": _min_pool_size
		})

# 启用/禁用自动调整
func enable_auto_resize(enabled: bool) -> void:
	_auto_resize = enabled
	_log_debug("Auto resize " + ("enabled" if enabled else "disabled"))

# 设置调整阈值
func set_resize_threshold(threshold: float) -> void:
	_resize_threshold = clamp(threshold, 0.1, 1.0)
	_log_debug("Resize threshold changed", {"threshold": _resize_threshold})

# 调整池大小
func _adjust_pool_size() -> void:
	# 调整池大小
	while _available_contexts.size() > _pool_size:
		var removed_context = _available_contexts.pop_back()
		_total_allocated -= 1
		_log_debug("Removed context from pool", {
			"context_id": removed_context.context_id,
			"available_count": _available_contexts.size()
		})
	
	while _available_contexts.size() < _pool_size and _total_allocated < _max_pool_size:
		var context = JuicyContext.new()
		# 确保新Context有有效的ID
		if context.context_id.is_empty():
			context.context_id = _generate_context_id()
		_available_contexts.append(context)
		_total_allocated += 1
		_log_debug("Added context to pool", {
			"context_id": context.context_id,
			"available_count": _available_contexts.size()
		})

# 处理自动调整
func process_auto_resize() -> void:
	if not _auto_resize:
		return
	
	var current_usage = _active_contexts.size()
	var total_capacity = _available_contexts.size() + current_usage
	var usage_ratio = float(current_usage) / float(total_capacity) if total_capacity > 0 else 0.0
	
	# 如果使用率超过阈值，增加池大小
	if usage_ratio > _resize_threshold:
		var new_size = min(_pool_size * 2, _max_pool_size)
		if new_size != _pool_size:
			set_pool_size(new_size)
			_resize_count += 1
			_log_debug("Pool auto-expanded", {
				"usage_ratio": usage_ratio,
				"old_size": _pool_size / 2,
				"new_size": _pool_size
			})
	# 如果使用率很低，减少池大小
	elif usage_ratio < _resize_threshold * 0.5:
		var new_size = max(_pool_size / 2, _min_pool_size)
		if new_size != _pool_size:
			set_pool_size(new_size)
			_resize_count += 1
			_log_debug("Pool auto-shrunk", {
				"usage_ratio": usage_ratio,
				"old_size": _pool_size * 2,
				"new_size": _pool_size
			})

# 处理清理
func process_cleanup(delta: float) -> void:
	_last_cleanup_time += delta
	
	if _last_cleanup_time >= _cleanup_interval:
		_cleanup_expired_contexts()
		_last_cleanup_time = 0.0

# 清理过期的Context
func _cleanup_expired_contexts() -> void:
	if not _enable_smart_cleanup:
		return
	
	var current_time = Time.get_ticks_msec() / 1000.0
	var expired_contexts: Array[JuicyContext] = []
	
	for context in _available_contexts:
		# 检查Context是否过期（基于创建时间）
		var context_age = current_time - context.creation_time
		if context_age > _max_idle_time:
			expired_contexts.append(context)
	
	for context in expired_contexts:
		_available_contexts.erase(context)
		_total_allocated -= 1
		_cleanup_count += 1
	
	if expired_contexts.size() > 0:
		_log_debug("Cleaned up expired contexts", {
			"cleaned_count": expired_contexts.size(),
			"total_cleaned": _cleanup_count
		})

# 获取统计信息
func get_statistics() -> Dictionary:
	var reuse_ratio = float(_total_reused) / max(_total_allocated, 1)
	var efficiency_score = _calculate_efficiency_score()
	
	return {
		"total_allocated": _total_allocated,
		"total_reused": _total_reused,
		"active_contexts": _active_contexts.size(),
		"available_contexts": _available_contexts.size(),
		"pool_size": _pool_size,
		"peak_usage": _peak_usage,
		"resize_count": _resize_count,
		"cleanup_count": _cleanup_count,
		"reuse_ratio": reuse_ratio,
		"efficiency_score": efficiency_score,
		"prewarmed": _prewarmed,
		"auto_resize": _auto_resize,
		"resize_threshold": _resize_threshold
	}

# 计算效率评分
func _calculate_efficiency_score() -> float:
	var score = 0.0
	
	# 重用率权重（40%）
	var reuse_ratio = float(_total_reused) / max(_total_allocated, 1)
	score += reuse_ratio * 0.4
	
	# 池利用率权重（30%）
	var utilization = float(_active_contexts.size()) / max(_pool_size, 1)
	score += utilization * 0.3
	
	# 峰值使用率权重（20%）
	var peak_ratio = float(_peak_usage) / max(_pool_size, 1)
	score += peak_ratio * 0.2
	
	# 自动调整效率权重（10%）
	var resize_efficiency = 1.0 - min(float(_resize_count) / max(_total_allocated, 1) * 10.0, 1.0)
	score += resize_efficiency * 0.1
	
	return score

# 清空池
func clear_pool() -> void:
	_available_contexts.clear()
	_active_contexts.clear()
	_context_to_internal_id.clear()
	_total_allocated = 0
	_total_reused = 0
	_peak_usage = 0
	_resize_count = 0
	_cleanup_count = 0
	_prewarmed = false
	_performance_history.clear()
	_next_internal_id = 1
	
	_log_debug("Pool cleared")

# 获取活跃Context
func get_active_contexts() -> Dictionary:
	return _active_contexts.duplicate()

# 获取可用Context
func get_available_contexts() -> Array[JuicyContext]:
	return _available_contexts.duplicate()

# 检查Context是否在池中
func has_context(context: JuicyContext) -> bool:
	var internal_id = _context_to_internal_id.get(context, "")
	return not internal_id.is_empty() and _active_contexts.has(internal_id)

# 获取Context的内部ID
func get_internal_id(context: JuicyContext) -> String:
	return _context_to_internal_id.get(context, "")

# 通过内部ID获取Context
func get_context_by_internal_id(internal_id: String) -> JuicyContext:
	return _active_contexts.get(internal_id)

# 强制回收所有活跃Context
func force_return_all_active() -> int:
	var returned_count = 0
	var internal_ids = _active_contexts.keys()
	
	for internal_id in internal_ids:
		var context = _active_contexts[internal_id]
		return_context(context)
		returned_count += 1
	
	_log_debug("Force returned all active contexts", {"returned_count": returned_count})
	return returned_count

# 记录性能指标
func _record_performance_metrics() -> void:
	if not _enable_efficiency_tracking:
		return
	
	var metrics = {
		"timestamp": Time.get_ticks_msec() / 1000.0,
		"active_count": _active_contexts.size(),
		"available_count": _available_contexts.size(),
		"total_allocated": _total_allocated,
		"total_reused": _total_reused,
		"reuse_ratio": float(_total_reused) / max(_total_allocated, 1)
	}
	
	_performance_history.append(metrics)
	
	# 限制历史记录大小
	if _performance_history.size() > _max_history_size:
		_performance_history.pop_front()

# 获取性能历史
func get_performance_history() -> Array[Dictionary]:
	return _performance_history.duplicate()

# 设置调试日志
func set_debug_logging(enabled: bool) -> void:
	_enable_debug_logging = enabled

# 设置智能清理
func set_smart_cleanup(enabled: bool) -> void:
	_enable_smart_cleanup = enabled

# 设置最大空闲时间
func set_max_idle_time(time: float) -> void:
	_max_idle_time = max(time, 0.0)

# 日志方法
func _log_debug(message: String, data: Dictionary = {}) -> void:
	if _enable_debug_logging:
		print("[JuicyContextPool DEBUG] ", message, " ", data)

func _log_warning(message: String, data: Dictionary = {}) -> void:
	print("[JuicyContextPool WARNING] ", message, " ", data)

# 获取详细状态信息
func get_detailed_status() -> Dictionary:
	var status = get_statistics()
	status["performance_history"] = get_performance_history()
	status["active_internal_ids"] = _active_contexts.keys()
	status["available_context_count"] = _available_contexts.size()
	status["pool_config"] = {
		"min_pool_size": _min_pool_size,
		"max_pool_size": _max_pool_size,
		"warm_up_count": _warm_up_count,
		"cleanup_interval": _cleanup_interval,
		"max_idle_time": _max_idle_time
	}
	status["debug_config"] = {
		"enable_debug_logging": _enable_debug_logging,
		"enable_smart_cleanup": _enable_smart_cleanup,
		"enable_efficiency_tracking": _enable_efficiency_tracking
	}
	
	return status

# 生成Context ID的辅助方法
func _generate_context_id() -> String:
	return "juicy_ctx_" + str(Time.get_ticks_msec()) + "_" + str(randi() % 10000)