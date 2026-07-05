# JuicyPoolManager - 全局池管理器
# 统一管理所有对象池，提供全局池化接口
# 支持池预热、性能监控和智能调整

class_name JuicyPoolManager
extends RefCounted

# 单例实例
static var _instance: JuicyPoolManager
static var instance: JuicyPoolManager: get = _get_instance

# 各种对象池
var _context_pool: JuicyContextPool
var _event_pool: JuicyObjectPool
var _driver_pools: Dictionary = {}  # driver_class_name -> JuicyObjectPool
var _resource_pools: Dictionary = {}  # resource_class_name -> JuicyObjectPool

# 池配置
var _pool_configs: Dictionary = {}
var _enable_auto_management: bool = true
var _global_cleanup_interval: float = 10.0  # 秒
var _last_cleanup_time: float = 0.0

# 性能监控
var _enable_performance_tracking: bool = true
var _performance_history: Array[Dictionary] = []
var _max_history_size: int = 100

# 调试和监控
var _enable_debug_logging: bool = false
var _pool_creation_count: int = 0

# 初始化
static func _get_instance() -> JuicyPoolManager:
	if not _instance:
		_instance = JuicyPoolManager.new()
		_instance._initialize()
	return _instance

func _initialize() -> void:
	print("Initializing JuicyPoolManager...")
	
	# 创建Context池
	_context_pool = JuicyContextPool.new(100)
	_context_pool.set_debug_logging(_enable_debug_logging)
	
	# 创建事件池
	_event_pool = JuicyObjectPool.new(JuicyEvent, 100)
	_event_pool.set_debug_logging(_enable_debug_logging)
	
	# 预热常用池
	_warm_up_common_pools()
	
	print("JuicyPoolManager initialized successfully")

# 预热常用池
func _warm_up_common_pools() -> void:
	# 预热Context池
	_context_pool.warm_up(50)
	
	# 预热事件池
	_event_pool.warm_up(50)
	
	print("Common pools warmed up successfully")

# 系统预热方法，用于游戏加载时调用
func warm_up_system() -> void:
	print("Warming up JuicyMixer pooling system...")
	
	# 预热Context池
	_context_pool.warm_up_system()
	
	# 预热事件池
	_event_pool.warm_up(100)
	
	# 预热所有已创建的池
	for pool in _driver_pools.values():
		pool.warm_up(30)
	
	for pool in _resource_pools.values():
		pool.warm_up(40)
	
	print("JuicyMixer pooling system warmed up successfully")

# 获取Context池
func get_context_pool() -> JuicyContextPool:
	return _context_pool

# 获取事件池
func get_event_pool() -> JuicyObjectPool:
	return _event_pool

# 获取或创建驱动器池
func get_driver_pool(driver_script: Script) -> JuicyObjectPool:
	return _get_or_create_driver_pool(driver_script, 20)

# 获取或创建资源池
func get_resource_pool(resource_script: Script) -> JuicyObjectPool:
	return _get_or_create_resource_pool(resource_script, 30)

# 内部方法：获取或创建驱动器池
func _get_or_create_driver_pool(driver_script: Script, default_size: int) -> JuicyObjectPool:
	if not driver_script:
		_log_warning("Invalid driver script")
		return null
	
	# 使用脚本实例作为键
	if not _driver_pools.has(driver_script):
		var pool = JuicyObjectPool.new(driver_script, default_size)
		pool.set_debug_logging(_enable_debug_logging)
		_driver_pools[driver_script] = pool
		_pool_creation_count += 1
		
		_log_debug("Created driver pool", {
			"driver_class": driver_script.get_global_name(),
			"pool_size": default_size
		})
	
	return _driver_pools[driver_script]

# 内部方法：获取或创建资源池
func _get_or_create_resource_pool(resource_script: Script, default_size: int) -> JuicyObjectPool:
	if not resource_script:
		_log_warning("Invalid resource script")
		return null
	
	# 使用脚本实例作为键
	if not _resource_pools.has(resource_script):
		var pool = JuicyObjectPool.new(resource_script, default_size)
		pool.set_debug_logging(_enable_debug_logging)
		_resource_pools[resource_script] = pool
		_pool_creation_count += 1
		
		_log_debug("Created resource pool", {
			"resource_class": resource_script.get_global_name(),
			"pool_size": default_size
		})
	
	return _resource_pools[resource_script]


# 便捷方法：获取驱动器实例
func get_driver(driver_script: Script) -> Object:
	var pool = get_driver_pool(driver_script)
	return pool.get_object() if pool else null

# 便捷方法：返回驱动器实例
func return_driver(driver: Object) -> void:
	if not driver:
		return
	
	var driver_script = driver.get_script()
	if _driver_pools.has(driver_script):
		_driver_pools[driver_script].return_object(driver)

# 便捷方法：获取资源实例
func get_resource(resource_script: Script) -> Object:
	var pool = get_resource_pool(resource_script)
	return pool.get_object() if pool else null

# 便捷方法：返回资源实例
func return_resource(resource: Object) -> void:
	if not resource:
		return
	
	var resource_script = resource.get_script()
	if _resource_pools.has(resource_script):
		_resource_pools[resource_script].return_object(resource)

# 处理全局更新
func process(delta: float) -> void:
	if not _enable_auto_management:
		return
	
	_last_cleanup_time += delta
	
	# 定期清理和调整
	if _last_cleanup_time >= _global_cleanup_interval:
		_process_all_pools()
		_last_cleanup_time = 0.0
	
	# 记录性能数据
	_record_global_performance_metrics()

# 处理所有池
func _process_all_pools() -> void:
	# 处理Context池
	_context_pool.process_auto_resize()
	_context_pool.process_cleanup(_global_cleanup_interval)
	
	# 处理事件池
	_event_pool.process_auto_resize()
	_event_pool.process_cleanup(_global_cleanup_interval)
	
	# 处理驱动器池
	for pool in _driver_pools.values():
		pool.process_auto_resize()
		pool.process_cleanup(_global_cleanup_interval)
	
	# 处理资源池
	for pool in _resource_pools.values():
		pool.process_auto_resize()
		pool.process_cleanup(_global_cleanup_interval)

# 获取所有池统计信息
func get_all_pool_statistics() -> Dictionary:
	var stats = {}
	
	# Context池统计
	stats["context_pool"] = _context_pool.get_statistics()
	
	# 事件池统计
	stats["event_pool"] = _event_pool.get_statistics()
	
	# 驱动器池统计
	stats["driver_pools"] = {}
	for driver_script in _driver_pools.keys():
		var type_name = driver_script.get_global_name()
		if not type_name:
			type_name = str(driver_script)
		stats["driver_pools"][type_name] = _driver_pools[driver_script].get_statistics()
	
	# 资源池统计
	stats["resource_pools"] = {}
	for resource_script in _resource_pools.keys():
		var type_name = resource_script.get_global_name()
		if not type_name:
			type_name = str(resource_script)
		stats["resource_pools"][type_name] = _resource_pools[resource_script].get_statistics()
	
	# 全局统计
	stats["global"] = {
		"total_pools": _pool_creation_count,
		"driver_pool_count": _driver_pools.size(),
		"resource_pool_count": _resource_pools.size(),
		"enable_auto_management": _enable_auto_management,
		"global_cleanup_interval": _global_cleanup_interval
	}
	
	return stats

# 计算全局效率评分
func get_global_efficiency_score() -> float:
	var total_score = 0.0
	var pool_count = 0
	
	# Context池评分
	total_score += _context_pool.get_statistics().get("efficiency_score", 0.0)
	pool_count += 1
	
	# 事件池评分
	total_score += _event_pool.get_statistics().get("efficiency_score", 0.0)
	pool_count += 1
	
	# 驱动器池评分
	for pool in _driver_pools.values():
		total_score += pool.get_statistics().get("efficiency_score", 0.0)
		pool_count += 1
	
	# 资源池评分
	for pool in _resource_pools.values():
		total_score += pool.get_statistics().get("efficiency_score", 0.0)
		pool_count += 1
	
	return total_score / max(pool_count, 1)

# 清空所有池
func clear_all_pools() -> void:
	_context_pool.clear_pool()
	_event_pool.clear_pool()
	
	for pool in _driver_pools.values():
		pool.clear_pool()
	
	for pool in _resource_pools.values():
		pool.clear_pool()
	
	_log_debug("All pools cleared")

# 记录全局性能指标
func _record_global_performance_metrics() -> void:
	if not _enable_performance_tracking:
		return
	
	var metrics = {
		"timestamp": Time.get_ticks_msec() / 1000.0,
		"global_efficiency_score": get_global_efficiency_score(),
		"total_pools": _pool_creation_count,
		"driver_pool_count": _driver_pools.size(),
		"resource_pool_count": _resource_pools.size()
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
	_context_pool.set_debug_logging(enabled)
	_event_pool.set_debug_logging(enabled)
	
	for pool in _driver_pools.values():
		pool.set_debug_logging(enabled)
	
	for pool in _resource_pools.values():
		pool.set_debug_logging(enabled)

# 设置自动管理
func set_auto_management(enabled: bool) -> void:
	_enable_auto_management = enabled

# 设置全局清理间隔
func set_global_cleanup_interval(interval: float) -> void:
	_global_cleanup_interval = max(interval, 1.0)

# 日志方法
func _log_debug(message: String, data: Dictionary = {}) -> void:
	if _enable_debug_logging:
		print("[JuicyPoolManager DEBUG] ", message, " ", data)

func _log_warning(message: String, data: Dictionary = {}) -> void:
	print("[JuicyPoolManager WARNING] ", message, " ", data)

# 获取详细状态信息
func get_detailed_status() -> Dictionary:
	var status = get_all_pool_statistics()
	status["performance_history"] = get_performance_history()
	status["global_efficiency_score"] = get_global_efficiency_score()
	status["config"] = {
		"enable_auto_management": _enable_auto_management,
		"global_cleanup_interval": _global_cleanup_interval,
		"enable_performance_tracking": _enable_performance_tracking,
		"enable_debug_logging": _enable_debug_logging
	}
	
	return status

# 强制回收所有活跃对象
func force_return_all_active() -> Dictionary:
	var results = {}
	
	results["context_pool"] = _context_pool.force_return_all_active()
	results["event_pool"] = _event_pool.force_return_all_active()
	
	results["driver_pools"] = {}
	for driver_script in _driver_pools.keys():
		var type_name = driver_script.get_global_name()
		if not type_name:
			type_name = str(driver_script)
		results["driver_pools"][type_name] = _driver_pools[driver_script].force_return_all_active()
	
	results["resource_pools"] = {}
	for resource_script in _resource_pools.keys():
		var type_name = resource_script.get_global_name()
		if not type_name:
			type_name = str(resource_script)
		results["resource_pools"][type_name] = _resource_pools[resource_script].force_return_all_active()
	
	_log_debug("Force returned all active objects", {"results": results})
	
	return results

# 清理未使用的池
func cleanup_unused_pools() -> int:
	var cleaned_count = 0
	
	# 清理驱动器池
	var unused_driver_pools = []
	for driver_script in _driver_pools.keys():
		var pool = _driver_pools[driver_script]
		var stats = pool.get_statistics()
		if stats.get("current_usage", 0) == 0 and stats.get("total_created", 0) == 0:
			unused_driver_pools.append(driver_script)
	
	for driver_script in unused_driver_pools:
		_driver_pools.erase(driver_script)
		cleaned_count += 1
	
	# 清理资源池
	var unused_resource_pools = []
	for resource_script in _resource_pools.keys():
		var pool = _resource_pools[resource_script]
		var stats = pool.get_statistics()
		if stats.get("current_usage", 0) == 0 and stats.get("total_created", 0) == 0:
			unused_resource_pools.append(resource_script)
	
	for resource_script in unused_resource_pools:
		_resource_pools.erase(resource_script)
		cleaned_count += 1
	
	_log_debug("Cleaned up unused pools", {"cleaned_count": cleaned_count})
	
	return cleaned_count

# 注册驱动器类
func register_driver_class(driver_script: Script) -> bool:
	if not driver_script:
		_log_warning("Invalid driver script")
		return false
	
	# 预创建池以注册类
	_get_or_create_driver_pool(driver_script, 20)
	
	_log_debug("Registered driver class", {"class_name": driver_script.get_global_name()})
	return true

# 注册资源类
func register_resource_class(resource_script: Script) -> bool:
	if not resource_script:
		_log_warning("Invalid resource script")
		return false
	
	# 预创建池以注册类
	_get_or_create_resource_pool(resource_script, 30)
	
	_log_debug("Registered resource class", {"class_name": resource_script.get_global_name()})
	return true