# JuicyPoolItem - 对象池项数据结构
# 表示对象池中的单个项，跟踪对象使用状态
# 提供生命周期管理，支持过期检测

class_name JuicyPoolItem
extends RefCounted

# 对象池项数据结构
var object: Object
var in_use: bool = false
var last_used: float = 0.0
var creation_time: float = 0.0
var usage_count: int = 0

# 扩展属性
var pool_item_id: String = ""
var expiration_time: float = 0.0  # 对象过期时间（0表示永不过期）
var priority: int = 0  # 优先级，用于智能回收
var metadata: Dictionary = {}  # 自定义元数据

# 性能统计
var total_use_time: float = 0.0  # 总使用时间
var last_use_duration: float = 0.0  # 最后一次使用时长
var average_use_duration: float = 0.0  # 平均使用时长

# 状态标志
var is_persistent: bool = false  # 是否持久对象（不会被回收）
var is_dirty: bool = false  # 是否需要重置
var is_locked: bool = false  # 是否被锁定（临时禁止回收）

# 构造函数
func _init(obj: Object = null):
	object = obj
	creation_time = Time.get_ticks_msec() / 1000.0
	last_used = creation_time
	pool_item_id = _generate_unique_id()
	
	# 如果对象有reset方法，标记为需要重置
	if obj and obj.has_method("reset"):
		is_dirty = true

# 标记为使用中
func mark_used() -> void:
	in_use = true
	last_used = Time.get_ticks_msec() / 1000.0
	usage_count += 1
	
	# 记录使用开始时间
	if not metadata.has("use_start_time"):
		metadata["use_start_time"] = last_used

# 标记为未使用
func mark_unused() -> void:
	in_use = false
	last_used = Time.get_ticks_msec() / 0.0
	
	# 计算使用时长
	if metadata.has("use_start_time"):
		last_use_duration = last_used - metadata["use_start_time"]
		total_use_time += last_use_duration
		average_use_duration = total_use_time / usage_count
		metadata.erase("use_start_time")
	
	# 标记为需要重置
	if object and object.has_method("reset"):
		is_dirty = true

# 重置对象状态
func reset() -> void:
	if object and object.has_method("reset"):
		object.reset()
	
	in_use = false
	last_used = 0.0
	usage_count = 0
	total_use_time = 0.0
	last_use_duration = 0.0
	average_use_duration = 0.0
	is_dirty = false
	metadata.clear()

# 检查是否过期
func is_expired(max_idle_time: float = 60.0) -> bool:
	if in_use or is_persistent or is_locked:
		return false
	
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# 检查是否超过最大空闲时间
	if max_idle_time > 0 and (current_time - last_used) > max_idle_time:
		return true
	
	# 检查是否超过固定过期时间
	if expiration_time > 0 and current_time > expiration_time:
		return true
	
	return false

# 获取对象生命周期时长
func get_lifetime() -> float:
	var current_time = Time.get_ticks_msec() / 1000.0
	return current_time - creation_time

# 获取空闲时间
func get_idle_time() -> float:
	if in_use:
		return 0.0
	var current_time = Time.get_ticks_msec() / 1000.0
	return current_time - last_used

# 获取使用率
func get_usage_rate() -> float:
	if get_lifetime() <= 0:
		return 0.0
	return float(usage_count) / get_lifetime()

# 获取效率评分（用于智能回收）
func get_efficiency_score() -> float:
	var score = 0.0
	
	# 使用频率权重（40%）
	score += get_usage_rate() * 0.4
	
	# 平均使用时长权重（30%）
	var normalized_duration = min(average_use_duration / 10.0, 1.0)  # 假设10秒为理想使用时长
	score += normalized_duration * 0.3
	
	# 最近使用权重（20%）
	var idle_time = get_idle_time()
	var recency_score = max(0.0, 1.0 - idle_time / 300.0)  # 5分钟内使用为满分
	score += recency_score * 0.2
	
	# 优先级权重（10%）
	var priority_score = min(priority / 100.0, 1.0)  # 假设100为最高优先级
	score += priority_score * 0.1
	
	return score

# 设置过期时间
func set_expiration_time(time: float) -> void:
	expiration_time = time

# 设置优先级
func set_priority(p: int) -> void:
	priority = p

# 设置持久标志
func set_persistent(persistent: bool) -> void:
	is_persistent = persistent

# 设置锁定标志
func set_locked(locked: bool) -> void:
	is_locked = locked

# 添加元数据
func set_metadata(key: String, value: Variant) -> void:
	metadata[key] = value

# 获取元数据
func get_metadata(key: String, default: Variant = null) -> Variant:
	return metadata.get(key, default)

# 检查对象是否有效
func is_valid() -> bool:
	return object != null and is_instance_valid(object)

# 获取对象类型
func get_object_type() -> String:
	if not is_valid():
		return ""
	return object.get_class()

# 获取详细统计信息
func get_statistics() -> Dictionary:
	return {
		"pool_item_id": pool_item_id,
		"object_type": get_object_type(),
		"in_use": in_use,
		"usage_count": usage_count,
		"creation_time": creation_time,
		"last_used": last_used,
		"lifetime": get_lifetime(),
		"idle_time": get_idle_time(),
		"usage_rate": get_usage_rate(),
		"efficiency_score": get_efficiency_score(),
		"total_use_time": total_use_time,
		"last_use_duration": last_use_duration,
		"average_use_duration": average_use_duration,
		"is_persistent": is_persistent,
		"is_dirty": is_dirty,
		"is_locked": is_locked,
		"priority": priority,
		"expiration_time": expiration_time,
		"metadata": metadata.duplicate()
	}

# 转换为字符串表示
func to_string() -> String:
	return "JuicyPoolItem[id=" + pool_item_id + ", type=" + get_object_type() + \
		   ", in_use=" + str(in_use) + ", usage_count=" + str(usage_count) + \
		   ", efficiency_score=" + str(get_efficiency_score()) + "]"

# 生成唯一ID
func _generate_unique_id() -> String:
	return "pool_item_" + str(Time.get_ticks_msec()) + "_" + str(randi() % 10000)

# 比较函数，用于排序
static func compare_by_priority(a: JuicyPoolItem, b: JuicyPoolItem) -> bool:
	if not a or not b:
		return false
	return a.priority > b.priority  # 优先级高的在前

static func compare_by_efficiency(a: JuicyPoolItem, b: JuicyPoolItem) -> bool:
	if not a or not b:
		return false
	return a.get_efficiency_score() > b.get_efficiency_score()  # 效率高的在前

static func compare_by_usage_count(a: JuicyPoolItem, b: JuicyPoolItem) -> bool:
	if not a or not b:
		return false
	return a.usage_count > b.usage_count  # 使用次数多的在前

static func compare_by_last_used(a: JuicyPoolItem, b: JuicyPoolItem) -> bool:
	if not a or not b:
		return false
	return a.last_used > b.last_used  # 最近使用的在前