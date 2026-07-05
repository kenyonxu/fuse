# FusePoolItem - 池项包装器
# 跟踪池化对象的使用状态和时间信息
# 提供效率评分和过期检测功能

class_name FusePoolItem extends RefCounted

## 池化的对象
var object: Node

## 使用标记
var in_use: bool = false

## 唯一ID
var pool_item_id: int = 0

## 创建时间
var created_time: float = 0.0

## 最后使用时间
var last_used_time: float = 0.0

## 使用次数统计
var usage_count: int = 0

## 调试配置
var _enable_debug: bool = false
var _pool_manager_path: String = ""

## 静态ID生成器
static var _next_id: int = 1

## 构造函数
func _init(obj: Node):
	object = obj
	pool_item_id = _next_id
	_next_id += 1
	var current_time = Time.get_ticks_msec() / 1000.0
	created_time = current_time
	last_used_time = current_time

## 设置调试日志
func set_debug_logging(enabled: bool, pool_path: String = "") -> void:
	_enable_debug = enabled
	_pool_manager_path = pool_path

## 标记为使用中
func mark_used() -> void:
	in_use = true
	last_used_time = Time.get_ticks_msec() / 1000.0
	usage_count += 1

	if _enable_debug and object:
		var obj_pos = object.global_position if object.has_method("global_position") else object.position
		_log_debug("标记为使用中", {
			"item_id": pool_item_id,
			"object_name": object.name if object else "null",
			"position": str(obj_pos),
			"usage_count": usage_count,
			"pool_path": _pool_manager_path
		})

## 标记为未使用
func mark_unused() -> void:
	in_use = false

	if _enable_debug and object:
		var obj_pos = object.global_position if object.has_method("global_position") else object.position
		_log_debug("标记为未使用", {
			"item_id": pool_item_id,
			"object_name": object.name if object else "null",
			"position": str(obj_pos),
			"usage_count": usage_count,
			"pool_path": _pool_manager_path
		})

## 检查对象是否有效
func is_valid() -> bool:
	return object != null and is_instance_valid(object)

## 检查对象是否过期（空闲时间超过阈值）
##
## 参数：
## - max_idle_time: 最大空闲时间（秒）
##
## 返回：
## - bool - 是否过期
func is_expired(max_idle_time: float) -> bool:
	if in_use:
		return false

	var idle_time = Time.get_ticks_msec() / 1000.0 - last_used_time
	return idle_time > max_idle_time

## 计算效率评分
##
## 基于使用频率计算效率分数（用于池收缩时决定保留哪些对象）
##
## 返回：
## - float - 效率分数（越高越好）
func get_efficiency_score() -> float:
	if usage_count == 0:
		return 0.0

	var age = Time.get_ticks_msec() / 1000.0 - created_time
	if age <= 0:
		return 0.0

	# 效率 = 使用次数 / 存在时间
	return float(usage_count) / age

## 比较函数（用于排序）
##
## 按效率评分降序排列（效率高的优先）
static func compare_by_efficiency(a: FusePoolItem, b: FusePoolItem) -> bool:
	return a.get_efficiency_score() > b.get_efficiency_score()

## 获取统计信息
func get_statistics() -> Dictionary:
	var obj_pos = Vector3.ZERO
	if object and is_instance_valid(object):
		obj_pos = object.global_position if object.has_method("global_position") else object.position

	return {
		"pool_item_id": pool_item_id,
		"in_use": in_use,
		"object_name": object.name if object else "null",
		"usage_count": usage_count,
		"created_time": created_time,
		"last_used_time": last_used_time,
		"age_seconds": Time.get_ticks_msec() / 1000.0 - created_time,
		"efficiency_score": get_efficiency_score(),
		"current_position": str(obj_pos),
		"pool_path": _pool_manager_path
	}

## 调试日志方法
func _log_debug(message: String, data: Dictionary = {}) -> void:
	if _enable_debug:
		var prefix = "[FusePoolItem DEBUG] " + ("[%s] " % _pool_manager_path if not _pool_manager_path.is_empty() else "")
		print(prefix + message, " ", data)
