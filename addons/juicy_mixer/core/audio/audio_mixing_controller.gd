class_name AudioMixingController
extends RefCounted

## 音频混音控制器
##
## 负责播放实例限额管理、鸭霸规则应用、虚声部判断等

# =============================================================================
# 私有变量
# =============================================================================

var _active_instances: Dictionary = {}  # event_name -> Array[player_info]
var _category_instances: Dictionary = {}  # category_name -> Array[player_info]
var _ducking_state: Dictionary = {}	 # target_bus -> ducking_info

# Ducking信息类
class DuckingInfo:
	var rule: DuckingRule
	var start_time: float
	var recovery_time: float

	func _init(r: DuckingRule, delay: float):
		rule = r
		start_time = Time.get_ticks_msec() / 1000.0
		recovery_time = start_time + delay

# =============================================================================
# 播放限额
# =============================================================================

## 检查是否可以播放
func can_play(resource: AudioEventResource, event_name: String, new_player: Variant = null,
			new_position: Vector3 = Vector3.ZERO, new_importance: int = 50) -> bool:
	"""检查是否可以播放（支持三层限额）"""

	if not resource or not resource.mixing:
		return true

	# 0. 相位保护检查（在实例级检查之前）
	if resource.anti_phase_cancellation:
		var current_time = Time.get_ticks_msec() / 1000.0
		var time_since_last = current_time - resource._last_play_time

		if time_since_last < resource.phase_cooldown:
			_log_debug("Phase cooldown active: %.3f < %.3f" % [time_since_last, resource.phase_cooldown])
			return false

		resource._last_play_time = current_time

	var config = resource.mixing
	var instances = _active_instances.get(event_name, [])

	# 统计活跃实例
	var active_count = 0
	for instance_info in instances:
		if is_instance_valid(instance_info.player):
			active_count += 1

	# 第一层：实例级别检查
	if active_count < config.max_instances:
		# 实例级未超限，检查类别级
		pass
	else:
		# 实例级超限处理
		match config.limit_policy:
			config.LimitPolicy.FIFO:  # STOP_OLDEST
				_stop_oldest_in_instance(event_name)
				# 继续检查类别级
			config.LimitPolicy.LIFO:  # STOP_NEWEST
				return false
			config.LimitPolicy.PRIORITY:
				_stop_lowest_priority_in_instance(event_name)
				# 继续检查类别级
			config.LimitPolicy.NEWEST_STEALS_OLDEST:
				_stop_oldest_in_instance(event_name)
				# 继续检查类别级
			config.LimitPolicy.FADE_OUT_OLDEST:
				_fade_out_oldest_in_instance(event_name, config.ducking_fade_out)
				# 继续检查类别级
			config.LimitPolicy.FADE_IN_NEWEST:
				# 淡入需要异步处理，这里简化为直接播放
				pass
			config.LimitPolicy.CROSSFADE:
				# 暂时简化为直接播放（后续实现）
				pass
			_:
				pass

	# 第二层：类别级别检查
	return _check_category_level(resource, new_player, new_position, new_importance)

## 记录播放实例
func record_instance(event_name: String, player: Object, priority: int,
					resource: AudioEventResource = null, position: Vector3 = Vector3.ZERO) -> void:
	"""记录播放实例（支持三层限额）"""

	# 第一层：实例级别
	if not _active_instances.has(event_name):
		_active_instances[event_name] = []

	_active_instances[event_name].append({
		"player": player,
		"priority": priority,
		"start_time": Time.get_ticks_msec() / 1000.0,
		"position": position,
		"importance": priority
	})

	# 第二层：类别级别
	if resource:
		for category in resource.categories:
			if not category:
				continue

			if not _category_instances.has(category.category_name):
				_category_instances[category.category_name] = []

			_category_instances[category.category_name].append({
				"player": player,
				"priority": priority,
				"start_time": Time.get_ticks_msec() / 1000.0,
				"position": position,
				"importance": priority
			})

## 移除播放实例
func remove_instance(event_name: String, player: Object, resource: AudioEventResource = null) -> void:
	"""移除播放实例（支持三层限额）"""

	# 第一层：实例级别
	if not event_name.is_empty() and _active_instances.has(event_name):
		var instances = _active_instances[event_name]
		for i in range(instances.size()):
			if instances[i].player == player:
				instances.remove_at(i)
				break

		if instances.is_empty():
			_active_instances.erase(event_name)

	# 第二层：类别级别
	if resource:
		for category in resource.categories:
			if not category:
				continue

			if _category_instances.has(category.category_name):
				var instances = _category_instances[category.category_name]
				for i in range(instances.size()):
					if instances[i].player == player:
						instances.remove_at(i)
						break

				if instances.is_empty():
					_category_instances.erase(category.category_name)

# =============================================================================
# 鸭霸管理
# =============================================================================

## 应用鸭霸
func apply_ducking(event_name: String, config: AudioMixingConfig) -> void:
	if not config:
		return

	var rule = config.get_ducking_rule_for_event(event_name)
	if not rule:
		return

	var bus_index = AudioServer.get_bus_index(rule.target_bus)
	if bus_index == -1:
		push_warning("AudioMixingController: Bus '%s' not found for ducking" % rule.target_bus)
		return

	# 应用鸭霸
	rule.apply_ducking(bus_index)

	# 记录状态
	_ducking_state[rule.target_bus] = DuckingInfo.new(rule, rule.recovery_delay)

## 移除鸭霸
func remove_ducking(event_name: String, config: AudioMixingConfig) -> void:
	if not config:
		return

	var rule = config.get_ducking_rule_for_event(event_name)
	if not rule:
		return

	var bus_index = AudioServer.get_bus_index(rule.target_bus)
	if bus_index == -1:
		return

	# 标记恢复时间（在update中实际恢复）
	if _ducking_state.has(rule.target_bus):
		var info = _ducking_state[rule.target_bus]
		info.recovery_time = Time.get_ticks_msec() / 1000.0 + rule.recovery_delay

## 更新鸭霸状态（每帧调用）
func update_ducking(delta: float) -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	var completed: Array = []

	for bus_name in _ducking_state.keys():
		var info = _ducking_state[bus_name]

		if current_time >= info.recovery_time:
			# 恢复原始音量
			var bus_index = AudioServer.get_bus_index(bus_name)
			if bus_index != -1:
				info.rule.remove_ducking(bus_index)

			completed.append(bus_name)

	for bus_name in completed:
		_ducking_state.erase(bus_name)

# =============================================================================
# 虚声部判断
# =============================================================================

## 判断是否应该作为虚声部播放
func should_play_virtual(resource: AudioEventResource, listener: Node3D,
						source_position: Vector3) -> bool:
	if not resource or not resource.virtual_voice_enabled:
		return false

	# 简化实现：仅检查距离
	if listener:
		var distance = listener.global_position.distance_to(source_position)
		if distance > resource.virtual_max_distance:
			return true

	return false

# =============================================================================
# 统计
# =============================================================================

## 获取统计信息
func get_stats() -> Dictionary:
	var total_instances = 0
	for event_name in _active_instances.keys():
		total_instances += _active_instances[event_name].size()

	return {
		"active_instances": total_instances,
		"ducking_active": _ducking_state.size()
	}

# =============================================================================
# 私有方法
# =============================================================================

## 停止最老的实例
func _stop_oldest_in_instance(event_name: String) -> void:
	var instances = _active_instances.get(event_name, [])
	if instances.is_empty():
		return

	var oldest = instances[0]
	_stop_player(oldest.player)

## 淡出最老的实例
func _fade_out_oldest_in_instance(event_name: String, fade_duration: float) -> void:
	var instances = _active_instances.get(event_name, [])
	if instances.is_empty():
		return

	# 找到最老的活跃实例
	for instance_info in instances:
		if is_instance_valid(instance_info.player):
			var player = instance_info.player

			# 创建 Tween 实现淡出
			var tween = create_tween()
			if not tween:
				return  # Tween 创建失败

			# 获取当前音量
			var current_volume_db = 0.0
			if player.has_method("get_volume_db"):
				current_volume_db = player.get_volume_db()
			elif player.has_property("volume_db"):
				current_volume_db = player.get("volume_db")

			# 淡出到 -80dB（无声）
			tween.parallel().tween_property(player, "volume_db", -80.0, fade_duration)
			tween.tween_callback(_stop_player.bind(player))

			_log_debug("Fading out oldest instance over %.2f seconds" % fade_duration)
			break

## 停止优先级最低的实例
func _stop_lowest_priority_in_instance(event_name: String) -> void:
	var instances = _active_instances.get(event_name, [])
	if instances.is_empty():
		return

	var lowest_priority = INF
	var lowest_index = -1

	for i in range(instances.size()):
		if not is_instance_valid(instances[i].player):
			continue

		if instances[i].priority < lowest_priority:
			lowest_priority = instances[i].priority
			lowest_index = i

	if lowest_index >= 0:
		_stop_player(instances[lowest_index].player)

## 停止播放器
func _stop_player(player: Object) -> void:
	if not is_instance_valid(player):
		return

	if player.has_method("stop"):
		player.stop()

## 检查实例是否有效
func is_instance_valid(player: Object) -> bool:
	if not player:
		return false

	# 检查节点是否仍然有效
	if player is Node:
		return is_instance_valid(player as Node)

	# 检查播放器是否正在播放
	if player.has_method("is_playing"):
		return player.is_playing()

	return true

## 创建 Tween 对象
func create_tween() -> Tween:
	var tween = Tween.new()
	var scene_root = Engine.get_main_loop().current_scene

	if not scene_root:
		push_error("AudioMixingController: Cannot create tween - no valid scene root")
		tween.queue_free()
		return null

	scene_root.add_child(tween)
	tween.finished.connect(_on_tween_finished.bind(tween))
	return tween

## Tween 完成回调
func _on_tween_finished(tween: Tween) -> void:
	if tween and is_instance_valid(tween):
		tween.queue_free()

## 调试日志输出
func _log_debug(message: String) -> void:
	if OS.is_debug_build():
		print("[AudioMixingController] ", message)

# =============================================================================
# 类别级限额检查
# =============================================================================

## 检查类别级别限制
func _check_category_level(resource: AudioEventResource, new_player: Variant,
						new_position: Vector3, new_importance: int) -> bool:
	"""检查类别级别限制"""

	if resource.categories.is_empty():
		return true  # 没有类别，跳过检查

	for category in resource.categories:
		if not category:
			continue

		var instances = _category_instances.get(category.category_name, [])

		# 统计活跃实例
		var active_count = 0
		var active_instances: Array = []

		for instance_info in instances:
			if is_instance_valid(instance_info.player):
				active_count += 1
				active_instances.append(instance_info)

		if active_count < category.max_instances:
			continue  # 该类别未超限，检查下一个类别

		# 超限处理：智能排序
		var new_score = _calculate_instance_score(
			new_position, new_importance, category.get_priority_factors()
		)

		# 找到优先级最低的实例
		var lowest_score = INF
		var lowest_index = -1

		for i in range(active_instances.size()):
			var instance_info = active_instances[i]
			var score = _calculate_instance_score(
				instance_info.position, instance_info.importance, category.get_priority_factors()
			)

			if score < lowest_score:
				lowest_score = score
				lowest_index = i

		# 比较新实例和最差实例
		if new_score > lowest_score:
			# 新实例优先级更高，停止最差的
			var worst_instance = active_instances[lowest_index]
			_stop_player(worst_instance.player)
			_log_debug("New instance (score: %.2f) steals worst category instance (score: %.2f)"
					   % [new_score, lowest_score])
			return true
		else:
			# 新实例优先级较低，忽略
			_log_debug("New instance (score: %.2f) ignored, lower than worst category instance (score: %.2f)"
					   % [new_score, lowest_score])
			return false

	return true

## 计算实例的综合分数（越高越重要）
func _calculate_instance_score(position: Vector3, importance: float,
						   factors: Dictionary) -> float:
	"""计算实例的综合分数（越高越重要）"""

	var listener_position = _get_listener_position()
	var distance = listener_position.distance_to(position)

	# 归一化距离（0-100米映射到 0-1）
	var distance_score = clamp(1.0 - distance / 100.0, 0.0, 1.0)

	# 归一化重要性（0-100 映射到 0-1）
	var importance_score = clamp(importance / 100.0, 0.0, 1.0)

	# 最近播放时间（越近分数越高）
	var recency_score = 0.5  # 简化处理

	# 加权计算
	var distance_weight = factors.get("distance_weight", 0.4)
	var importance_weight = factors.get("importance_weight", 0.4)
	var recency_weight = factors.get("recency_weight", 0.2)

	var total_score = (
		distance_score * distance_weight +
		importance_score * importance_weight +
		recency_score * recency_weight
	)

	return total_score * 100.0  # 返回 0-100 的分数

## 获取监听器位置
func _get_listener_position() -> Vector3:
	"""获取监听器位置（通常是主相机）"""
	var scene_root = Engine.get_main_loop().current_scene
	if not scene_root:
		return Vector3.ZERO

	# 查找 Camera3D（假设是主监听器）
	var cameras = scene_root.find_children("*", "Camera3D", true, false)
	if cameras.size() > 0:
		return cameras[0].global_position

	# 默认返回原点
	return Vector3.ZERO