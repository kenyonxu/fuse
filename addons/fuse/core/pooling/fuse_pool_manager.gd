# FusePoolManager - 全局池管理器
# 统一管理所有场景对象池，提供全局池化接口
# 支持池预热、性能监控和智能调整

class_name FusePoolManager extends RefCounted

## 单例实例
static var _instance: FusePoolManager = null

## 获取单例实例
static func get_instance() -> FusePoolManager:
	if not _instance:
		_instance = FusePoolManager.new()
	return _instance

## 场景池管理 (scene_path -> FuseObjectPool)
var _scene_pools: Dictionary = {}

## 活动的回收定时器（保持引用，防止被提前释放）
var _active_recycle_timers: Array[FuseRecycleTimer] = []

## 调试配置
var _enable_debug: bool = false

## 构造函数
func _init():
	_log_debug("FusePoolManager 初始化")

## 从池中实例化场景
##
## 使用对象池从指定路径实例化场景，如果没有可用对象则创建新的
##
## 参数：
## - scene_path: 场景文件路径
## - parent: 父节点
## - pool_config: 池配置字典（可选）
##   - initial_size: 初始池大小（默认 20）
##   - max_size: 最大池大小（默认 100）
##
## 返回：
## - Node: 场景实例，如果失败则返回 null
func instantiate_pooled(scene_path: String, parent: Node, pool_config: Dictionary = {}) -> Node:
	if scene_path.is_empty() or not parent:
		_log_error("参数无效", {
			"scene_path": scene_path,
			"parent": parent
		})
		return null

	# 获取或创建池
	var pool = _get_or_create_pool(scene_path, pool_config)
	if not pool:
		_log_error("创建对象池失败", {"scene_path": scene_path})
		return null

	# 从池中获取对象
	var instance = pool.get_object()
	if not instance:
		_log_error("从池中获取对象失败", {
			"scene_path": scene_path
		})
		return null

	# 添加到父节点
	parent.add_child(instance)

	# 在添加到场景树后重置对象状态（确保物理属性等能正确设置）
	pool.reset_object(instance)

	if _enable_debug:
		_log_debug("从池中实例化场景", {
			"scene_path": scene_path,
			"parent": parent.name,
			"instance": instance.name,
			"instance_id": instance.get_instance_id(),
			"position": instance.global_position if instance.has_method("global_position") else instance.position
		})

	return instance

## 获取池化实例（不添加到场景树）
##
## 从池中获取实例但不添加到场景树，由调用者负责添加。
## 用于需要延迟添加的场景（如物理回调中）。
##
## 参数：
## - scene_path: 场景文件路径
## - pool_config: 池配置字典（可选）
##
## 返回：
## - Dictionary: { "instance": Node, "pool": FuseObjectPool } 或空字典（失败时）
func get_pooled_instance(scene_path: String, pool_config: Dictionary = {}) -> Dictionary:
	if scene_path.is_empty():
		_log_error("场景路径无效", {"scene_path": scene_path})
		return {}

	# 获取或创建池
	var pool = _get_or_create_pool(scene_path, pool_config)
	if not pool:
		_log_error("创建对象池失败", {"scene_path": scene_path})
		return {}

	# 从池中获取对象
	var instance = pool.get_object()
	if not instance:
		_log_error("从池中获取对象失败", {"scene_path": scene_path})
		return {}

	if _enable_debug:
		_log_debug("获取池化实例（未添加到场景树）", {
			"scene_path": scene_path,
			"instance": instance.name,
			"instance_id": instance.get_instance_id()
		})

	return { "instance": instance, "pool": pool }

## 回收场景实例
##
## 将使用完毕的场景实例归还到对象池
##
## 参数：
## - scene_path: 场景文件路径（支持 res:// 或 uid:// 格式）
## - instance: 要回收的场景实例
##
## 返回：
## - bool: true 表示回收成功，false 表示回收失败
func recycle_pooled(scene_path: String, instance: Node) -> bool:
	# 🔍 性能追踪：开始回收
	FusePerformanceTracker.get_instance().start_track("FusePoolManager.recycle_pooled")

	if not instance:
		_log_warning("尝试回收 null 实例", {"scene_path": scene_path})
		FusePerformanceTracker.get_instance().stop_track("FusePoolManager.recycle_pooled")
		return false

	# 方法1：优先从实例获取 scene_file_path
	var final_scene_path = scene_path
	var instance_scene_path = instance.scene_file_path
	if instance_scene_path and not instance_scene_path.is_empty():
		final_scene_path = instance_scene_path
		_log_debug("从实例获取 scene_file_path: %s" % final_scene_path)

	# 方法2：尝试直接查找
	var pool = _scene_pools.get(final_scene_path)

	# 方法3：如果没找到，尝试通过实例 ID 在所有池中查找
	if not pool:
		pool = _find_pool_by_instance_id(instance)

	# 方法4：遍历所有池进行路径匹配
	if not pool:
		pool = _find_pool_by_any_path(final_scene_path)

	if not pool:
		_log_warning("未找到对应的池", {
			"scene_path": scene_path,
			"instance_scene_path": instance_scene_path,
			"instance_id": instance.get_instance_id(),
			"available_paths": _scene_pools.keys()
		})
		FusePerformanceTracker.get_instance().stop_track("FusePoolManager.recycle_pooled")
		return false

	pool.return_object(instance)

	# 🔍 性能追踪：结束回收
	FusePerformanceTracker.get_instance().stop_track("FusePoolManager.recycle_pooled")

	if _enable_debug:
		_log_debug("回收场景实例", {
			"scene_path": final_scene_path,
			"instance": instance.name,
			"instance_id": instance.get_instance_id(),
			"position_before_recycle": instance.global_position if instance.has_method("global_position") else instance.position,
			"in_scene_tree": instance.get_parent() != null
		})

	return true

## 通过实例 ID 在所有池中查找
func _find_pool_by_instance_id(instance: Node) -> FuseObjectPool:
	# 🔍 性能追踪：开始查找
	FusePerformanceTracker.get_instance().start_track("FusePoolManager._find_pool_by_instance_id")

	if not instance:
		FusePerformanceTracker.get_instance().stop_track("FusePoolManager._find_pool_by_instance_id")
		return null

	var instance_id = instance.get_instance_id()
	_log_debug("通过实例ID查找池: %d" % instance_id)

	# 遍历所有池，检查每个池的使用中对象
	for pool in _scene_pools.values():
		if pool._find_pool_item_by_instance_id(instance_id):
			_log_debug("通过实例ID找到池: %s" % pool._scene_path)
			FusePerformanceTracker.get_instance().stop_track("FusePoolManager._find_pool_by_instance_id")
			return pool

	FusePerformanceTracker.get_instance().stop_track("FusePoolManager._find_pool_by_instance_id")
	return null

## 通过实例的文件名查找池
func _find_pool_by_instance_filename(instance: Node) -> FuseObjectPool:
	if not instance:
		return null

	# 获取实例的场景路径
	var instance_scene_path = instance.scene_file_path
	if instance_scene_path and not instance_scene_path.is_empty():
		_log_debug("实例 scene_file_path: %s" % instance_scene_path)

		# 遍历所有池，尝试匹配
		for pool_path in _scene_pools.keys():
			# 方法1：精确匹配
			if pool_path == instance_scene_path:
				_log_debug("通过完整路径匹配找到池: %s" % pool_path)
				return _scene_pools[pool_path]

			# 方法2：比较文件名（不含扩展名）
			var instance_filename = FuseNodeUtils.get_path_display_name(instance_scene_path).get_basename()
			var pool_filename = FuseNodeUtils.get_path_display_name(pool_path).get_basename()
			if instance_filename == pool_filename:
				_log_debug("通过文件名匹配找到池: %s -> %s" % [instance_filename, pool_path])
				return _scene_pools[pool_path]

			# 方法3：如果实例场景路径是文件路径，尝试加载获取 UID
			if instance_scene_path.begins_with("res://"):
				var uid = _get_resource_uid_from_path(instance_scene_path)
				if not uid.is_empty():
					var uid_path = "uid://" + uid
					if pool_path == uid_path:
						_log_debug("通过 UID 匹配找到池: %s -> %s" % [instance_scene_path, uid_path])
						return _scene_pools[pool_path]

	return null

## 从文件路径获取资源的 UID
func _get_resource_uid_from_path(file_path: String) -> String:
	if file_path.is_empty() or not file_path.begins_with("res://"):
		_log_debug("获取UID失败: 路径不以res://开头: %s" % file_path)
		return ""

	# 方法1: 使用 ResourceLoader.get_resource_uid() 获取 UID (返回 int)
	var uid_int = ResourceLoader.get_resource_uid(file_path)
	if uid_int != 0:  # 0 表示无效 UID
		_log_debug("通过get_resource_uid获取UID(int): %s -> %d" % [file_path, uid_int])
		# 转换为字符串格式
		return str(uid_int)

	# 方法2: 尝试加载资源获取其真实路径
	var res = load(file_path)
	if not res:
		_log_debug("获取UID失败: 无法加载资源: %s" % file_path)
		return ""

	var res_path = res.get_path()
	_log_debug("加载后的资源路径: %s" % res_path)

	# 如果加载后的路径是 UID 格式，提取 UID
	if res_path.begins_with("uid://"):
		# uid://bmfgotihlmfkw 或 uid://bmfgotihlmfkw/xxx
		# 提取中间部分
		var extracted_uid = res_path.get_slice("/", 2)  # uid://bmfgotihlmfkw -> bmfgotihlmfkw
		_log_debug("从路径提取UID: %s" % extracted_uid)
		return extracted_uid
	else:
		_log_debug("加载后的路径不是UID格式: %s" % res_path)

	return ""

## 通过任意路径格式查找池
func _find_pool_by_any_path(search_path: String) -> FuseObjectPool:
	# 如果已经是池的 key，直接返回
	if _scene_pools.has(search_path):
		return _scene_pools[search_path]

	# 遍历所有池进行匹配
	for pool_path in _scene_pools.keys():
		# 方法1：精确匹配
		if pool_path == search_path:
			return _scene_pools[pool_path]

		# 方法2：如果 search_path 是文件路径，尝试匹配池中任意一个
		if search_path.begins_with("res://") or search_path.begins_with("uid://"):
			# 获取不带扩展名的文件名进行比较
			var search_name = FuseNodeUtils.get_path_display_name(search_path).get_basename()
			var pool_name = FuseNodeUtils.get_path_display_name(pool_path).get_basename()
			if search_name == pool_name:
				_log_debug("通过文件名匹配找到池: %s -> %s" % [search_path, pool_path])
				return _scene_pools[pool_path]

	# 如果都失败，尝试加载资源获取其 UID
	if search_path.begins_with("res://"):
		var uid = _get_resource_uid(search_path)
		if not uid.is_empty():
			var uid_path = "uid://" + uid
			if _scene_pools.has(uid_path):
				return _scene_pools[uid_path]

	return null

## 获取资源的 UID
func _get_resource_uid(file_path: String) -> String:
	if file_path.is_empty() or not file_path.begins_with("res://"):
		return ""

	# 尝试加载资源来获取 UID
	var res = load(file_path)
	if res:
		# 使用 Resource 的 get_path() 方法获取路径
		var res_path = res.get_path()
		if res_path.begins_with("uid://"):
			return res_path.get_slice("/", 2)

	return ""

## 注册回收定时器
##
## 将回收定时器添加到管理器中，防止被提前释放
##
## 参数：
## - timer: FuseRecycleTimer 实例
func register_recycle_timer(timer: FuseRecycleTimer) -> void:
	if timer:
		_active_recycle_timers.append(timer)
		_log_debug("注册回收定时器", {"timer_count": _active_recycle_timers.size()})

## 注销回收定时器
##
## 当回收完成后，移除定时器引用
##
## 参数：
## - timer: FuseRecycleTimer 实例
func unregister_recycle_timer(timer: FuseRecycleTimer) -> void:
	if timer and timer in _active_recycle_timers:
		_active_recycle_timers.erase(timer)
		_log_debug("注销回收定时器", {"timer_count": _active_recycle_timers.size()})

## 检查实例是否在使用中
##
## 用于回收定时器检查实例是否已被其他方式回收
##
## 参数：
## - scene_path: 场景文件路径
## - instance: 要检查的实例
##
## 返回：
## - bool: true 表示实例正在使用中，false 表示实例未在使用（已被回收）或未找到
func is_instance_in_use(scene_path: String, instance: Node) -> bool:
	if not instance:
		return false

	# 查找池
	var pool = _scene_pools.get(scene_path)
	if not pool:
		pool = _find_pool_by_instance_id(instance)
		if not pool:
			return false

	# 在池中查找对应的池项
	var instance_id = instance.get_instance_id()
	for item in pool._pool_items:
		if item.object and item.object.get_instance_id() == instance_id:
			return item.in_use

	return false

## 获取实例的使用计数（usage_count）
##
## 用于回收定时器检测对象是否已被复用
##
## 参数：
## - scene_path: 场景文件路径
## - instance: 要检查的实例
##
## 返回：
## - int: usage_count，如果未找到返回 -1
func get_instance_usage_count(scene_path: String, instance: Node) -> int:
	if not instance:
		return -1

	# 查找池
	var pool = _scene_pools.get(scene_path)
	if not pool:
		pool = _find_pool_by_instance_id(instance)
		if not pool:
			return -1

	# 在池中查找对应的池项
	var instance_id = instance.get_instance_id()
	for item in pool._pool_items:
		if item.object and item.object.get_instance_id() == instance_id:
			return item.usage_count

	return -1

## 预热场景池
##
## 预先创建指定数量的场景对象放入池中，减少运行时创建开销
##
## 参数：
## - scene_path: 场景文件路径
## - count: 要预热的对象数量
## - pool_config: 池配置字典（可选）
func warm_up_pool(scene_path: String, count: int, pool_config: Dictionary = {}) -> void:
	if scene_path.is_empty():
		_log_warning("场景路径为空，无法预热")
		return

	# 获取或创建池
	var pool = _get_or_create_pool(scene_path, pool_config)
	if not pool:
		_log_error("创建对象池失败", {"scene_path": scene_path})
		return

	pool.warm_up(count)

	if _enable_debug:
		_log_debug("场景池已预热", {
			"scene_path": scene_path,
			"count": count
		})

## 清理所有池
##
## 清空所有对象池，释放所有池化对象
func clear_all_pools() -> void:
	for scene_path in _scene_pools.keys():
		_scene_pools[scene_path].clear_pool()

	_scene_pools.clear()

	_log_debug("所有池已清空")

## 获取或创建池
##
## 内部方法：获取现有池或创建新池
func _get_or_create_pool(scene_path: String, config: Dictionary = {}) -> FuseObjectPool:
	if _scene_pools.has(scene_path):
		return _scene_pools[scene_path]

	# 从配置中读取参数
	var initial_size = config.get("initial_size", 20)
	var max_size = config.get("max_size", 100)

	# 创建新池
	var pool = FuseObjectPool.new(scene_path, initial_size)
	pool.set_max_pool_size(max_size)
	pool.set_debug_logging(_enable_debug)

	_scene_pools[scene_path] = pool

	if _enable_debug:
		_log_debug("创建新池", {
			"scene_path": scene_path,
			"initial_size": initial_size,
			"max_size": max_size
		})

	return pool

## 获取池统计信息
##
## 获取指定场景路径的池统计信息，或获取所有池的统计信息
##
## 参数：
## - scene_path: 场景文件路径（如果为空，则返回所有池的统计）
##
## 返回：
## - Dictionary: 统计信息字典
func get_statistics(scene_path: String = "") -> Dictionary:
	if scene_path.is_empty():
		# 返回所有池的统计
		var all_stats = {}
		for sp in _scene_pools.keys():
			all_stats[sp] = _scene_pools[sp].get_statistics()
		return all_stats
	else:
		# 返回指定池的统计
		if _scene_pools.has(scene_path):
			return _scene_pools[scene_path].get_statistics()
		return {}

## 获取所有池状态
##
## 获取管理器的详细状态信息，包括所有池的配置和统计
func get_detailed_status() -> Dictionary:
	var status = {
		"total_pools": _scene_pools.size(),
		"scene_paths": _scene_pools.keys(),
		"enable_debug": _enable_debug
	}

	# 添加所有池的统计
	var pool_stats = {}
	for scene_path in _scene_pools.keys():
		pool_stats[scene_path] = _scene_pools[scene_path].get_statistics()

	status["pool_statistics"] = pool_stats

	return status

## 设置调试日志
##
## 启用或禁用调试日志输出
##
## 参数：
## - enabled: 是否启用调试日志
func set_debug_logging(enabled: bool) -> void:
	_enable_debug = enabled

	# 更新所有池的调试设置
	for pool in _scene_pools.values():
		pool.set_debug_logging(enabled)

	_log_debug("调试日志 " + ("启用" if enabled else "禁用"))

## 日志方法
func _log_debug(message: String, data: Dictionary = {}) -> void:
	if _enable_debug:
		print("[FusePoolManager DEBUG] ", message, " ", data)

func _log_warning(message: String, data: Dictionary = {}) -> void:
	print("[FusePoolManager WARNING] ", message, " ", data)

func _log_error(message: String, data: Dictionary = {}) -> void:
	print("[FusePoolManager ERROR] ", message, " ", data)
