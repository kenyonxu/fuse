# JuicyObjectPool - 通用对象池
# 提供通用对象池功能，支持多种对象类型
# 实现自动扩容和收缩，提供性能统计

class_name JuicyObjectPool
extends RefCounted

# 池管理
var _pool_items: Array[JuicyPoolItem] = []
var _object_script: Script
var _pool_size: int = 50
var _max_pool_size: int = 200
var _min_pool_size: int = 10
var _auto_resize: bool = true
var _resize_threshold: float = 0.8

# 统计信息
var _total_created: int = 0
var _total_reused: int = 0
var _peak_usage: int = 0
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

# 对象类型信息
var _object_type_name: String = ""
var _object_base_class: String = ""

# 构造函数
func _init(script: Script, initial_size: int = 50):
	_object_script = script
	_pool_size = initial_size
	_pool_size = clamp(_pool_size, _min_pool_size, _max_pool_size)
	
	# 获取对象类型信息
	_object_type_name = script.get_global_name() if script.get_global_name() else script.resource_path.get_file()
	_object_base_class = _get_object_base_class(script)

# 获取对象
func get_object() -> Object:
	var pool_item: JuicyPoolItem = null
	var obj: Object = null
	
	# 查找可用的对象
	for item in _pool_items:
		if not item.in_use and item.is_valid():
			pool_item = item
			break
	
	if pool_item:
		# 重用现有对象
		pool_item.mark_used()
		obj = pool_item.object
		_total_reused += 1
		
		# 如果对象有reset方法，调用它
		if obj.has_method("reset"):
			obj.reset()
		
		if _enable_debug_logging:
			_log_debug("Reused object from pool", {
				"object_type": _object_type_name,
				"pool_item_id": pool_item.pool_item_id,
				"total_reused": _total_reused
			})
	else:
		# 没有可用对象，创建新对象
		if _pool_items.size() < _max_pool_size:
			obj = _object_script.new()
			if obj:
				pool_item = JuicyPoolItem.new(obj)
				pool_item.mark_used()
				_pool_items.append(pool_item)
				_total_created += 1
				
				if _enable_debug_logging:
					_log_debug("Created new object", {
						"object_type": _object_type_name,
						"pool_item_id": pool_item.pool_item_id,
						"total_created": _total_created
					})
		else:
			# 池已满且没有可用对象
			_log_warning("Pool exhausted, cannot create new object", {
				"object_type": _object_type_name,
				"pool_size": _pool_items.size(),
				"max_pool_size": _max_pool_size
			})
			return null
	
	# 更新峰值使用量
	var current_usage = _get_current_usage()
	if current_usage > _peak_usage:
		_peak_usage = current_usage
		
		if _enable_debug_logging:
			_log_debug("New peak usage", {
				"object_type": _object_type_name,
				"peak_usage": _peak_usage,
				"current_usage": current_usage
			})
	
	# 记录性能数据
	_record_performance_metrics()
	
	return obj

# 返回对象到池中
func return_object(obj: Object) -> void:
	if not obj:
		_log_warning("Attempted to return null object")
		return
	
	# 查找对应的池项
	for item in _pool_items:
		if item.object == obj:
			item.mark_unused()
			
			if _enable_debug_logging:
				_log_debug("Object returned to pool", {
					"object_type": _object_type_name,
					"pool_item_id": item.pool_item_id
				})
			return
	
	# 如果没找到对应的池项，可能是外部创建的对象
	_log_warning("Object not found in pool, creating new pool item", {
		"object_type": _object_type_name
	})
	
	var pool_item = JuicyPoolItem.new(obj)
	pool_item.mark_unused()
	_pool_items.append(pool_item)
	_total_created += 1

# 预热池
func warm_up(count: int) -> void:
	if _prewarmed:
		_log_debug("Pool already warmed up")
		return
	
	var actual_count = min(count, _pool_size)
	for i in range(actual_count):
		var obj = _object_script.new()
		if obj:
			var pool_item = JuicyPoolItem.new(obj)
			pool_item.mark_unused()
			_pool_items.append(pool_item)
			_total_created += 1
	
	_prewarmed = true
	
	_log_debug("Pool warmed up", {
		"object_type": _object_type_name,
		"warm_up_count": actual_count,
		"total_created": _total_created
	})

# 设置池大小
func set_pool_size(size: int) -> void:
	var old_size = _pool_size
	_pool_size = clamp(size, _min_pool_size, _max_pool_size)
	
	if old_size != _pool_size:
		_adjust_pool_size()
		_log_debug("Pool size changed", {
			"object_type": _object_type_name,
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
			"object_type": _object_type_name,
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
			"object_type": _object_type_name,
			"old_min": old_min,
			"new_min": _min_pool_size
		})

# 启用/禁用自动调整
func enable_auto_resize(enabled: bool) -> void:
	_auto_resize = enabled
	_log_debug("Auto resize " + ("enabled" if enabled else "disabled"), {
		"object_type": _object_type_name
	})

# 设置调整阈值
func set_resize_threshold(threshold: float) -> void:
	_resize_threshold = clamp(threshold, 0.1, 1.0)
	_log_debug("Resize threshold changed", {
		"object_type": _object_type_name,
		"threshold": _resize_threshold
	})

# 调整池大小
func _adjust_pool_size() -> void:
	# 移除多余的未使用对象
	var unused_items = []
	for item in _pool_items:
		if not item.in_use:
			unused_items.append(item)
	
	# 按效率评分排序，优先保留高效对象
	unused_items.sort_custom(JuicyPoolItem.compare_by_efficiency)
	
	# 移除超出池大小的对象
	while unused_items.size() > _pool_size and _pool_items.size() > _min_pool_size:
		var item_to_remove = unused_items.pop_back()  # 移除效率最低的对象
		_pool_items.erase(item_to_remove)
		_total_created -= 1
		
		if _enable_debug_logging:
			_log_debug("Removed object from pool", {
				"object_type": _object_type_name,
				"pool_item_id": item_to_remove.pool_item_id,
				"efficiency_score": item_to_remove.get_efficiency_score()
			})
	
	# 添加对象到池中（如果需要）
	while _get_unused_count() < _pool_size and _pool_items.size() < _max_pool_size:
		var obj = _object_script.new()
		if obj:
			var pool_item = JuicyPoolItem.new(obj)
			pool_item.mark_unused()
			_pool_items.append(pool_item)
			_total_created += 1
			
			if _enable_debug_logging:
				_log_debug("Added object to pool", {
					"object_type": _object_type_name,
					"pool_item_id": pool_item.pool_item_id
				})

# 处理自动调整
func process_auto_resize() -> void:
	if not _auto_resize:
		return
	
	var current_usage = _get_current_usage()
	var total_capacity = _pool_items.size()
	var usage_ratio = float(current_usage) / float(total_capacity) if total_capacity > 0 else 0.0
	
	# 如果使用率超过阈值，增加池大小
	if usage_ratio > _resize_threshold:
		var new_size = min(_pool_size * 2, _max_pool_size)
		if new_size != _pool_size:
			set_pool_size(new_size)
			_log_debug("Pool auto-expanded", {
				"object_type": _object_type_name,
				"usage_ratio": usage_ratio,
				"old_size": _pool_size / 2,
				"new_size": _pool_size
			})
	# 如果使用率很低，减少池大小
	elif usage_ratio < _resize_threshold * 0.5:
		var new_size = max(_pool_size / 2, _min_pool_size)
		if new_size != _pool_size:
			set_pool_size(new_size)
			_log_debug("Pool auto-shrunk", {
				"object_type": _object_type_name,
				"usage_ratio": usage_ratio,
				"old_size": _pool_size * 2,
				"new_size": _pool_size
			})

# 处理清理
func process_cleanup(delta: float) -> void:
	_last_cleanup_time += delta
	
	if _last_cleanup_time >= _cleanup_interval:
		_cleanup_expired_objects()
		_last_cleanup_time = 0.0

# 清理过期的对象
func _cleanup_expired_objects() -> void:
	if not _enable_smart_cleanup:
		return
	
	var expired_items: Array[JuicyPoolItem] = []
	
	for item in _pool_items:
		if not item.in_use and item.is_expired(_max_idle_time):
			expired_items.append(item)
	
	for item in expired_items:
		_pool_items.erase(item)
		_total_created -= 1
		_cleanup_count += 1
	
	if expired_items.size() > 0:
		_log_debug("Cleaned up expired objects", {
			"object_type": _object_type_name,
			"cleaned_count": expired_items.size(),
			"total_cleaned": _cleanup_count
		})

# 获取当前使用量
func _get_current_usage() -> int:
	var count = 0
	for item in _pool_items:
		if item.in_use:
			count += 1
	return count

# 获取未使用对象数量
func _get_unused_count() -> int:
	var count = 0
	for item in _pool_items:
		if not item.in_use:
			count += 1
	return count

# 获取统计信息
func get_statistics() -> Dictionary:
	var reuse_ratio = float(_total_reused) / max(_total_created, 1)
	var efficiency_score = _calculate_efficiency_score()
	
	return {
		"object_type": _object_type_name,
		"object_base_class": _object_base_class,
		"total_created": _total_created,
		"total_reused": _total_reused,
		"pool_size": _pool_items.size(),
		"current_usage": _get_current_usage(),
		"unused_count": _get_unused_count(),
		"peak_usage": _peak_usage,
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
	var reuse_ratio = float(_total_reused) / max(_total_created, 1)
	score += reuse_ratio * 0.4
	
	# 池利用率权重（30%）
	var utilization = float(_get_current_usage()) / max(_pool_items.size(), 1)
	score += utilization * 0.3
	
	# 峰值使用率权重（20%）
	var peak_ratio = float(_peak_usage) / max(_pool_items.size(), 1)
	score += peak_ratio * 0.2
	
	# 自动调整效率权重（10%）
	var resize_efficiency = 1.0 - min(float(_cleanup_count) / max(_total_created, 1) * 10.0, 1.0)
	score += resize_efficiency * 0.1
	
	return score

# 清空池
func clear_pool() -> void:
	_pool_items.clear()
	_total_created = 0
	_total_reused = 0
	_peak_usage = 0
	_cleanup_count = 0
	_prewarmed = false
	_performance_history.clear()
	
	_log_debug("Pool cleared", {"object_type": _object_type_name})

# 记录性能指标
func _record_performance_metrics() -> void:
	if not _enable_efficiency_tracking:
		return
	
	var metrics = {
		"timestamp": Time.get_ticks_msec() / 1000.0,
		"current_usage": _get_current_usage(),
		"unused_count": _get_unused_count(),
		"total_created": _total_created,
		"total_reused": _total_reused,
		"reuse_ratio": float(_total_reused) / max(_total_created, 1)
	}
	
	_performance_history.append(metrics)
	
	# 限制历史记录大小
	if _performance_history.size() > _max_history_size:
		_performance_history.pop_front()

# 获取性能历史
func get_performance_history() -> Array[Dictionary]:
	return _performance_history.duplicate()

# 获取对象基类
func _get_object_base_class(script: Script) -> String:
	# 尝试获取脚本的基类信息
	if script.get_base_script():
		return script.get_base_script().get_global_name()
	
	# 如果无法获取基类，返回空字符串
	return ""

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
		print("[JuicyObjectPool DEBUG] ", message, " ", data)

func _log_warning(message: String, data: Dictionary = {}) -> void:
	print("[JuicyObjectPool WARNING] ", message, " ", data)

# 获取详细状态信息
func get_detailed_status() -> Dictionary:
	var status = get_statistics()
	status["performance_history"] = get_performance_history()
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
	
	# 添加池项详细信息
	var pool_items_info = []
	for item in _pool_items:
		pool_items_info.append(item.get_statistics())
	status["pool_items"] = pool_items_info
	
	return status

# 强制回收所有活跃对象
func force_return_all_active() -> int:
	var returned_count = 0
	
	for item in _pool_items:
		if item.in_use:
			item.mark_unused()
			returned_count += 1
	
	_log_debug("Force returned all active objects", {
		"object_type": _object_type_name,
		"returned_count": returned_count
	})
	
	return returned_count

# 获取对象类型信息
func get_object_type_info() -> Dictionary:
	return {
		"type_name": _object_type_name,
		"base_class": _object_base_class,
		"script_path": _object_script.resource_path if _object_script else ""
	}