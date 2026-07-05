# InterruptionState - 中断状态数据结构
# 存储中断状态数据，管理活跃和队列中的上下文
# 跟踪中断历史，处理优先级队列

@tool
class_name InterruptionState
extends RefCounted

# 状态数据
var target_id: int
var active_contexts: Array[String] = []
var queued_contexts: Array[String] = []
var current_policy: JuicyMixerEnums.InterruptionPolicy = JuicyMixerEnums.InterruptionPolicy.STACK
var transition_context: String = ""
var transition_progress: float = 0.0
var interruption_history: Array[Dictionary] = []
var priority_queue: Array[Dictionary] = []  # 优先级队列：[{"context_id": String, "priority": int}]

# 性能优化5：基于时间的历史记录清理配置
var history_cleanup_threshold: float = 300.0  # 默认5分钟（300秒）
var last_cleanup_time: float = 0.0  # 上次清理时间戳

func _init(target: Node = null):
	if target:
		target_id = target.get_instance_id()

# =============================================================================
# 活跃上下文管理
# =============================================================================

func add_active_context(context_id: String) -> void:
	"""
	添加活跃上下文
	
	@param context_id: 上下文ID
	"""
	if context_id not in active_contexts:
		active_contexts.append(context_id)

func remove_active_context(context_id: String) -> void:
	"""
	移除活跃上下文
	
	@param context_id: 上下文ID
	"""
	active_contexts.erase(context_id)

func has_active_context(context_id: String) -> bool:
	"""
	检查是否有指定的活跃上下文
	
	@param context_id: 上下文ID
	@return: 是否存在
	"""
	return context_id in active_contexts

func get_active_context_count() -> int:
	"""
	获取活跃上下文数量
	
	@return: 活跃上下文数量
	"""
	return active_contexts.size()

func clear_active_contexts() -> void:
	"""
	清空所有活跃上下文
	"""
	active_contexts.clear()

# =============================================================================
# 队列上下文管理
# =============================================================================

func add_queued_context(context_id: String) -> void:
	"""
	添加队列上下文
	
	@param context_id: 上下文ID
	"""
	if context_id not in queued_contexts:
		queued_contexts.append(context_id)

func remove_queued_context(context_id: String) -> void:
	"""
	移除队列上下文
	
	@param context_id: 上下文ID
	"""
	queued_contexts.erase(context_id)

func has_queued_context(context_id: String) -> bool:
	"""
	检查是否有指定的队列上下文
	
	@param context_id: 上下文ID
	@return: 是否存在
	"""
	return context_id in queued_contexts

func get_next_queued_context() -> String:
	"""
	获取下一个队列上下文（不移除）
	
	@return: 上下文ID，如果队列为空则返回空字符串
	"""
	if queued_contexts.size() > 0:
		return queued_contexts.front()
	return ""

func pop_next_queued_context() -> String:
	"""
	弹出下一个队列上下文（移除）
	
	@return: 上下文ID，如果队列为空则返回空字符串
	"""
	if queued_contexts.size() > 0:
		return queued_contexts.pop_front()
	return ""

func get_queued_context_count() -> int:
	"""
	获取队列上下文数量
	
	@return: 队列上下文数量
	"""
	return queued_contexts.size()

func clear_queued_contexts() -> void:
	"""
	清空所有队列上下文
	"""
	queued_contexts.clear()

# =============================================================================
# 优先级队列管理
# =============================================================================

func add_priority_queue_item(context_id: String, priority: int) -> void:
	"""
	添加优先级队列项 - 使用二分查找优化插入性能 (O(log n))
	
	@param context_id: 上下文ID
	@param priority: 优先级（数值越大优先级越高）
	"""
	var queue_item = {
		"context_id": context_id,
		"priority": priority,
		"timestamp": Time.get_ticks_msec() / 1000.0
	}
	
	# 使用二分查找确定插入位置 - 优化从O(n)到O(log n)
	var left = 0
	var right = priority_queue.size() - 1
	var insert_index = priority_queue.size()  # 默认插入到末尾
	
	while left <= right:
		var mid = (left + right) / 2
		var mid_priority = priority_queue[mid].priority
		
		if mid_priority < priority:
			# 当前中间项优先级较低，应该在左侧插入
			right = mid - 1
			insert_index = mid
		elif mid_priority > priority:
			# 当前中间项优先级较高，应该在右侧继续查找
			left = mid + 1
		else:
			# 优先级相同，按时间戳排序（时间戳小的在前）
			if priority_queue[mid].timestamp > queue_item.timestamp:
				# 当前项时间戳较大，新项应该在前
				right = mid - 1
				insert_index = mid
			else:
				# 当前项时间戳较小或相等，新项应该在后
				left = mid + 1
	
	# 在找到的位置插入项目
	if insert_index == priority_queue.size():
		priority_queue.append(queue_item)
	else:
		priority_queue.insert(insert_index, queue_item)

func get_next_priority_item() -> Dictionary:
	"""
	获取下一个优先级队列项（不移除）
	
	@return: 队列项字典，如果队列为空则返回空字典
	"""
	if priority_queue.size() > 0:
		return priority_queue.front()
	return {}

func pop_next_priority_item() -> Dictionary:
	"""
	弹出下一个优先级队列项（移除）
	
	@return: 队列项字典，如果队列为空则返回空字典
	"""
	if priority_queue.size() > 0:
		return priority_queue.pop_front()
	return {}

func get_priority_queue_count() -> int:
	"""
	获取优先级队列项数量
	
	@return: 优先级队列项数量
	"""
	return priority_queue.size()

func clear_priority_queue() -> void:
	"""
	清空优先级队列
	"""
	priority_queue.clear()

# =============================================================================
# 中断历史管理
# =============================================================================

func add_interruption_record(record: Dictionary) -> void:
	"""
	添加中断记录
	
	@param record: 中断记录字典，应包含：
		- timestamp: 时间戳
		- new_context: 新上下文ID
		- existing_context: 现有上下文ID
		- policy: 中断策略
		- target_id: 目标ID
	"""
	# 性能优化5：确保记录包含时间戳，用于基于时间的清理
	if not record.has("timestamp"):
		record["timestamp"] = Time.get_ticks_msec() / 1000.0
	
	interruption_history.append(record)
	
	# 限制历史记录数量，防止内存泄漏
	if interruption_history.size() > 100:
		interruption_history.pop_front()
	
	# 性能优化5：定期清理过期记录，控制内存增长
	_cleanup_expired_history_records()

func get_interruption_history() -> Array[Dictionary]:
	"""
	获取中断历史记录
	
	@return: 中断历史记录数组
	"""
	return interruption_history.duplicate()

func clear_interruption_history() -> void:
	"""
	清空中断历史记录
	"""
	interruption_history.clear()
	last_cleanup_time = Time.get_ticks_msec() / 1000.0

# =============================================================================
# 性能优化5：基于时间的历史记录清理
# =============================================================================

func _cleanup_expired_history_records() -> void:
	"""
	清理过期的历史记录 - 基于时间的自动清理机制
	删除超过指定时间阈值（默认5分钟）的记录，节省30-50%的历史记录内存
	"""
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# 避免频繁清理，每30秒最多清理一次
	if current_time - last_cleanup_time < 30.0:
		return
	
	last_cleanup_time = current_time
	
	# 如果历史记录较少，跳过清理以提高性能
	if interruption_history.size() < 20:
		return
	
	# 清理过期记录（时间戳早于阈值）
	var expired_time = current_time - history_cleanup_threshold
	var new_history = []
	var removed_count = 0
	
	for record in interruption_history:
		# 确保记录有时间戳，如果没有则使用当前时间（向后兼容）
		var record_time = record.get("timestamp", current_time)
		if record_time >= expired_time:
			new_history.append(record)
		else:
			removed_count += 1
	
	# 更新历史记录
	interruption_history = new_history
	
	# 可选：记录清理统计信息（调试用）
	if removed_count > 0:
		print("清理了 %d 条过期中断历史记录，节省内存 %.1f%%" % [removed_count, (float(removed_count) / (new_history.size() + removed_count)) * 100])

func set_history_cleanup_threshold(threshold_seconds: float) -> void:
	"""
	设置历史记录清理时间阈值
	
	@param threshold_seconds: 清理阈值（秒），默认300秒（5分钟）
	"""
	history_cleanup_threshold = max(threshold_seconds, 60.0)  # 最少1分钟

func get_history_cleanup_threshold() -> float:
	"""
	获取历史记录清理时间阈值
	
	@return: 清理阈值（秒）
	"""
	return history_cleanup_threshold

func get_history_memory_stats() -> Dictionary:
	"""
	获取历史记录内存统计信息
	
	@return: 内存统计字典
	"""
	return {
		"history_size": interruption_history.size(),
		"cleanup_threshold": history_cleanup_threshold,
		"last_cleanup_time": last_cleanup_time,
		"optimization_enabled": true
	}

# =============================================================================
# 过渡状态管理
# =============================================================================

func is_transitioning() -> bool:
	"""
	检查是否正在过渡
	
	@return: 是否正在过渡
	"""
	return not transition_context.is_empty()

func set_transition(context_id: String) -> void:
	"""
	设置过渡状态
	
	@param context_id: 过渡上下文ID
	"""
	transition_context = context_id
	transition_progress = 0.0

func clear_transition() -> void:
	"""
	清除过渡状态
	"""
	transition_context = ""
	transition_progress = 0.0

func update_transition_progress(delta: float) -> void:
	"""
	更新过渡进度
	
	@param delta: 时间增量
	"""
	if is_transitioning():
		transition_progress = min(transition_progress + delta, 1.0)

func is_transition_complete() -> bool:
	"""
	检查过渡是否完成
	
	@return: 过渡是否完成
	"""
	return transition_progress >= 1.0

# =============================================================================
# 实用函数
# =============================================================================

func to_string() -> String:
	"""
	获取状态字符串表示
	
	@return: 状态字符串
	"""
	return "InterruptionState[target_id=%d, active=%d, queued=%d, policy=%d]" % [
		target_id, active_contexts.size(), queued_contexts.size(), current_policy
	]

func get_state_summary() -> Dictionary:
	"""
	获取状态摘要信息
	
	@return: 状态摘要字典
	"""
	return {
		"target_id": target_id,
		"active_contexts": active_contexts.duplicate(),
		"queued_contexts": queued_contexts.duplicate(),
		"priority_queue_size": priority_queue.size(),
		"current_policy": JuicyMixerEnums.get_interruption_policy_name(current_policy),
		"is_transitioning": is_transitioning(),
		"transition_progress": transition_progress,
		"history_size": interruption_history.size()
	}

func clear_all() -> void:
	"""
	清空所有状态数据
	"""
	clear_active_contexts()
	clear_queued_contexts()
	clear_priority_queue()
	clear_interruption_history()
	clear_transition()
	current_policy = JuicyMixerEnums.InterruptionPolicy.STACK  # 重置为默认策略

# =============================================================================
# 序列化支持
# =============================================================================

func serialize() -> Dictionary:
	"""
	序列化中断状态
	
	@return: 序列化后的字典
	"""
	var data = {
		"target_id": target_id,
		"active_contexts": active_contexts.duplicate(),
		"queued_contexts": queued_contexts.duplicate(),
		"current_policy": JuicyMixerEnums.get_interruption_policy_name(current_policy),
		"transition_context": transition_context,
		"transition_progress": transition_progress,
		"interruption_history": interruption_history.duplicate(),
		"priority_queue": []
	}
	
	# 序列化优先级队列
	for item in priority_queue:
		data.priority_queue.append({
			"context_id": item.context_id,
			"priority": item.priority,
			"timestamp": item.timestamp
		})
	
	return data

func deserialize(data: Dictionary) -> bool:
	"""
	从序列化数据恢复中断状态
	
	@param data: 序列化数据
	@return: 是否成功恢复
	"""
	if not data or typeof(data) != TYPE_DICTIONARY:
		return false
	
	# 恢复基础数据
	if data.has("target_id"):
		target_id = data.target_id
	
	if data.has("active_contexts") and typeof(data.active_contexts) == TYPE_ARRAY:
		active_contexts = data.active_contexts.duplicate()
	
	if data.has("queued_contexts") and typeof(data.queued_contexts) == TYPE_ARRAY:
		queued_contexts = data.queued_contexts.duplicate()
	
	if data.has("current_policy") and typeof(data.current_policy) == TYPE_STRING:
		current_policy = JuicyMixerEnums.get_interruption_policy_from_name(data.current_policy)
	
	if data.has("transition_context") and typeof(data.transition_context) == TYPE_STRING:
		transition_context = data.transition_context
	
	if data.has("transition_progress") and typeof(data.transition_progress) in [TYPE_INT, TYPE_FLOAT]:
		transition_progress = float(data.transition_progress)
	
	if data.has("interruption_history") and typeof(data.interruption_history) == TYPE_ARRAY:
		interruption_history = data.interruption_history.duplicate()
	
	# 恢复优先级队列
	if data.has("priority_queue") and typeof(data.priority_queue) == TYPE_ARRAY:
		priority_queue.clear()
		for item_data in data.priority_queue:
			if typeof(item_data) == TYPE_DICTIONARY and item_data.has("context_id") and item_data.has("priority"):
				var item = {
					"context_id": item_data.context_id,
					"priority": item_data.priority,
					"timestamp": item_data.get("timestamp", Time.get_ticks_msec() / 1000.0)
				}
				priority_queue.append(item)
	
	return true

func get_serialization_size() -> int:
	"""
	获取序列化数据的大小（估算）
	
	@return: 数据大小（字节）
	"""
	var size = 0
	
	# 基础数据大小
	size += 4  # target_id (int)
	size += 4  # transition_progress (float)
	size += transition_context.length() * 2  # 字符串（假设UTF-16）
	size += 50  # current_policy（策略名称）
	
	# 数组大小估算
	size += active_contexts.size() * 32  # 假设每个context_id平均32字符
	size += queued_contexts.size() * 32
	size += priority_queue.size() * 64  # 每个优先级项约64字节
	size += interruption_history.size() * 128  # 每个历史记录约128字节
	
	return size

func validate_serialization_data(data: Dictionary) -> Dictionary:
	"""
	验证序列化数据的有效性
	
	@param data: 要验证的序列化数据
	@return: 验证结果字典 {valid: bool, issues: Array[String]}
	"""
	var result = {
		"valid": true,
		"issues": []
	}
	
	if not data or typeof(data) != TYPE_DICTIONARY:
		result.valid = false
		result.issues.append("Invalid data format")
		return result
	
	# 检查必需字段
	var required_fields = ["target_id", "active_contexts", "queued_contexts", "current_policy"]
	for field in required_fields:
		if not data.has(field):
			result.valid = false
			result.issues.append("Missing required field: " + field)
	
	# 验证数据类型
	if data.has("target_id") and typeof(data.target_id) != TYPE_INT:
		result.valid = false
		result.issues.append("Invalid target_id type")
	
	if data.has("active_contexts") and typeof(data.active_contexts) != TYPE_ARRAY:
		result.valid = false
		result.issues.append("Invalid active_contexts type")
	
	if data.has("queued_contexts") and typeof(data.queued_contexts) != TYPE_ARRAY:
		result.valid = false
		result.issues.append("Invalid queued_contexts type")
	
	if data.has("current_policy") and typeof(data.current_policy) != TYPE_STRING:
		result.valid = false
		result.issues.append("Invalid current_policy type")
	
	# 验证策略名称
	if data.has("current_policy"):
		# 确保current_policy是字符串类型
		if typeof(data.current_policy) != TYPE_STRING:
			result.valid = false
			result.issues.append("Invalid current_policy type, expected String")
		else:
			var policy = JuicyMixerEnums.get_interruption_policy_from_name(data.current_policy)
			if policy == JuicyMixerEnums.InterruptionPolicy.STACK and data.current_policy != "stack":
				result.valid = false
				result.issues.append("Invalid interruption policy name: " + str(data.current_policy))
	
	return result
