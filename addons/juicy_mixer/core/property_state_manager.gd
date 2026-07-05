class_name PropertyStateManager
extends RefCounted

# 状态管理
var _state_snapshots: Dictionary = {}  # target_id -> Array[StateSnapshot]
var _restoration_queue: Array[StateSnapshot] = []
var _restoration_configs: Dictionary = {}  # context_id -> RestorationConfig
var _default_config: RestorationConfig
var _emergency_targets: Dictionary = {}  # target_id -> bool

# 统计信息
var _snapshot_count: int = 0
var _restoration_count: int = 0
var _failed_restorations: int = 0

func _init():
	_default_config = RestorationConfig.new()
	# 确保默认使用非阻塞模式以获得最佳性能
	_default_config.blocking_mode = false

func create_snapshot(target: Node, context_id: String = "", metadata: Dictionary = {}) -> String:
	var snapshot = StateSnapshot.new()
	snapshot.target_id = target.get_instance_id()
	snapshot.timestamp = Time.get_ticks_msec() / 1000.0
	snapshot.context_id = context_id
	snapshot.metadata = metadata
	
	# 获取还原配置
	var config = _get_restoration_config(context_id)
	
	# 调试输出已移除以提高性能
	
	# 应用还原模式到快照
	snapshot.restoration_mode = config.default_restoration_mode
	
	# 捕获所有可还原属性
	_capture_target_properties(target, snapshot, config)
	
	# 捕获子节点状态
	if config.auto_snapshot:
		_capture_children_states(target, snapshot, config)
	
	# 存储快照
	if not _state_snapshots.has(snapshot.target_id):
		_state_snapshots[snapshot.target_id] = []
	
	var snapshots = _state_snapshots[snapshot.target_id]
	snapshots.append(snapshot)
	
	# 限制快照数量
	if snapshots.size() > config.max_snapshots_per_target:
		snapshots.pop_front()
	
	_snapshot_count += 1
	
	# 触发快照事件
	_emit_state_event("snapshot_created", snapshot)
	
	return snapshot.context_id

func auto_restore_state(target: Node, context_id: String) -> bool:
	var target_id = target.get_instance_id()
	var snapshots = get_snapshots_for_target(target)
	
	# 查找相关快照 - 优化查找逻辑
	var target_snapshot: StateSnapshot = null
	for snapshot in snapshots:
		if snapshot.context_id == context_id:
			target_snapshot = snapshot
			break
	
	if not target_snapshot:
		return false
	
	# 获取配置以确定是否需要等待
	var config = _get_restoration_config(context_id)
	if config.blocking_mode:
		# 阻塞模式：需要等待
		return await restore_snapshot(target_snapshot)
	else:
		# 非阻塞模式：立即返回
		restore_snapshot(target_snapshot)
		return true

func restore_snapshot(snapshot: StateSnapshot) -> bool:
	if not snapshot or not snapshot.is_restorable:
		return false
	
	var target = instance_from_id(snapshot.target_id)
	if not target:
		return false
	
	# 获取还原配置
	var config = _get_restoration_config(snapshot.context_id)
	
	# 根据阻塞模式选择还原策略
	if config.blocking_mode:
		# 阻塞模式：等待还原完成
		return await _restore_snapshot_blocking(snapshot, target, config)
	else:
		# 非阻塞模式：立即返回，后台执行还原
		_start_background_restore(snapshot, target, config)
		return true

func _restore_snapshot_blocking(snapshot: StateSnapshot, target: Node, config: RestorationConfig) -> bool:
	# 阻塞还原：等待还原完成
	var success = true
	match snapshot.restoration_mode:
		JuicyMixerEnums.RestorationMode.SNAP:
			_snap_restore_properties(target, snapshot, config)
		JuicyMixerEnums.RestorationMode.EASE:
			success = await _ease_restore_properties(target, snapshot, config)
		JuicyMixerEnums.RestorationMode.CURVE:
			success = await _curve_restore_properties(target, snapshot, config)
	
	# 还原子节点状态
	if config.auto_snapshot:
		_restore_children_states(target, snapshot, config)
	
	_restoration_count += 1
	
	# 触发还原事件
	_emit_state_event("state_restored", snapshot)
	
	return success

func _start_background_restore(snapshot: StateSnapshot, target: Node, config: RestorationConfig) -> void:
	# 非阻塞后台还原
	# 在后台执行还原，不阻塞主流程
	_restore_snapshot_background(snapshot, target, config)

func _restore_snapshot_background(snapshot: StateSnapshot, target: Node, config: RestorationConfig) -> void:
	# 后台还原执行 - 优化版本，减少调试输出
	
	# 检查目标是否仍然有效
	if not is_instance_valid(target):
		return
	
	var success = true
	match snapshot.restoration_mode:
		JuicyMixerEnums.RestorationMode.SNAP:
			# SNAP模式：立即执行，无等待
			_snap_restore_properties(target, snapshot, config)
			success = true
		JuicyMixerEnums.RestorationMode.EASE:
			# EASE模式：异步动画
			success = await _ease_restore_properties(target, snapshot, config)
		JuicyMixerEnums.RestorationMode.CURVE:
			# CURVE模式：异步动画
			success = await _curve_restore_properties(target, snapshot, config)
	
	# 还原子节点状态
	if config.auto_snapshot and is_instance_valid(target):
		_restore_children_states(target, snapshot, config)
	
	_restoration_count += 1
	
	# 触发还原事件
	_emit_state_event("state_restored", snapshot)

func _snap_restore_properties(target: Node, snapshot: StateSnapshot, config: RestorationConfig) -> void:
	# 立即还原属性值 - 优化版本，减少调试输出和循环开销
	var restored_count = 0
	var property_count = 0
	
	# 批量还原属性，减少函数调用开销
	for property_name in snapshot.property_values:
		property_count += 1
		if _should_restore_property(property_name, config):
			if property_name in target:
				var value = snapshot.property_values[property_name]
				# 直接设置，跳过额外的有效性检查（已在调用前验证）
				target.set(property_name, value)
				restored_count += 1
	
	# 性能优化：移除调试输出

func _ease_restore_properties(target: Node, snapshot: StateSnapshot, config: RestorationConfig) -> bool:
	# 使用缓动函数平滑还原 - 优化版本
	var tween = target.create_tween()
	tween.set_ease(snapshot.ease_type)
	tween.set_trans(snapshot.trans_type)
	tween.set_parallel(true)
	
	var animation_started = false
	var properties_to_animate = []
	
	# 预筛选需要动画的属性
	for property_name in snapshot.property_values:
		if _should_restore_property(property_name, config) and property_name in target:
			var target_value = snapshot.property_values[property_name]
			var current_value = target.get(property_name)
			
			# 只有当当前值与目标值不同时才进行动画
			if current_value != target_value:
				properties_to_animate.append({
					"name": property_name,
					"current": current_value,
					"target": target_value
				})
	
	# 如果没有属性需要动画，立即使用SNAP还原
	if properties_to_animate.is_empty():
		_snap_restore_properties(target, snapshot, config)
		return true
	
	# 创建动画
	for prop_data in properties_to_animate:
		tween.tween_property(target, prop_data.name, prop_data.target, snapshot.restoration_duration)
		animation_started = true
	
	# 等待动画完成 - 优化等待逻辑
	if animation_started:
		var tree = target.get_tree()
		if tree:
			var start_time = Time.get_ticks_msec() / 1000.0
			var timeout_duration = snapshot.restoration_duration + 0.5  # 减少超时时间
			
			# 使用更高效的等待循环
			var frame_count = 0
			var max_frames = int(timeout_duration * 60)  # 假设60fps
			
			while frame_count < max_frames:
				# 检查动画是否完成
				if not tween.is_valid():
					break
				
				# 短暂等待一帧
				await tree.process_frame
				frame_count += 1
	
	return true

func _curve_restore_properties(target: Node, snapshot: StateSnapshot, config: RestorationConfig) -> bool:
	# 使用自定义曲线平滑还原
	if not snapshot.restoration_curve:
		# 如果没有曲线，回退到缓动还原
		return await _ease_restore_properties(target, snapshot, config)
	
	# 验证曲线有效性
	if snapshot.restoration_curve.get_point_count() < 2:
		# 曲线点不足，回退到缓动还原
		return await _ease_restore_properties(target, snapshot, config)
	
	var tween = target.create_tween()
	tween.set_parallel(true)
	
	var successful_properties = 0
	var failed_properties = 0
	
	for property_name in snapshot.property_values:
		if _should_restore_property(property_name, config):
			if property_name in target:
				# 检查属性是否可访问
				if target.get(property_name) != null or target.has_method("get_" + property_name):
					var target_value = snapshot.property_values[property_name]
					var current_value = target.get(property_name)
					
					# 只有当当前值与目标值不同时才进行动画
					if current_value != target_value:
						# 使用tween_method进行曲线插值
						tween.tween_method(
							func(progress):
								var curve_value = snapshot.restoration_curve.sample(progress)
								var interpolated_value = _interpolate_value(current_value, target_value, curve_value)
								target.set(property_name, interpolated_value),
							0.0, 1.0, snapshot.restoration_duration
						)
						successful_properties += 1
				else:
					# 属性不可访问，记录失败
					failed_properties += 1
					push_warning("Failed to restore property '%s' using curve interpolation" % property_name)
	
	# 如果没有成功还原任何属性，回退到缓动还原
	if successful_properties == 0 and failed_properties > 0:
		return await _ease_restore_properties(target, snapshot, config)
	
	# 等待曲线动画完成
	if successful_properties > 0:
		var tree = target.get_tree()
		if tree:
			var start_time = Time.get_ticks_msec() / 1000.0
			var timeout_duration = snapshot.restoration_duration + 1.0
			
			# 手动更新动画直到完成
			while Time.get_ticks_msec() / 1000.0 - start_time < timeout_duration:
				# 在编辑器模式下手动处理tween更新
				if Engine.is_editor_hint():
					var delta = 0.016  # 假设60fps
					tween.step(delta)
				
				# 检查动画是否完成
				if not tween.is_valid():
					break
				
				# 短暂等待
				await tree.process_frame
	
	return successful_properties > 0

func _interpolate_value(from: Variant, to: Variant, weight: float) -> Variant:
	# 插值计算函数 - 支持多种数据类型
	if weight <= 0.0:
		return from
	if weight >= 1.0:
		return to
	
	# 检查类型兼容性
	if typeof(from) != typeof(to):
		# 类型不匹配，在权重超过0.5时返回目标值
		return to if weight > 0.5 else from
	
	# 数值类型插值
	if from is float and to is float:
		# 检查是否为旋转属性
		if _is_rotation_property(from, to):
			return _lerp_angle(from, to, weight)
		else:
			return lerpf(from, to, weight)
	elif from is int and to is int:
		return int(lerpf(float(from), float(to), weight))
	
	# 向量类型插值
	elif from is Vector2 and to is Vector2:
		return from.lerp(to, weight)
	elif from is Vector3 and to is Vector3:
		return from.lerp(to, weight)
	elif from is Vector4 and to is Vector4:
		return from.lerp(to, weight)
	
	# 颜色类型插值
	elif from is Color and to is Color:
		return from.lerp(to, weight)
	
	# 其他类型，在权重超过0.5时返回目标值
	else:
		return to if weight > 0.5 else from

func _lerp_angle(from: float, to: float, weight: float) -> float:
	# 角度插值，处理环绕问题
	var diff = fmod(to - from + PI, 2.0 * PI) - PI
	return from + diff * weight

func _is_rotation_property(from: float, to: float) -> bool:
	# 简单的启发式方法判断是否为旋转属性
	# 如果值在合理范围内且差值较大，可能是旋转
	var diff = abs(to - from)
	return diff > PI or diff > 3.0  # 差值大于PI或3弧度

func emergency_restore(target: Node) -> bool:
	var target_id = target.get_instance_id()
	var snapshots = get_snapshots_for_target(target)
	
	if snapshots.is_empty():
		return false
	
	# 使用最新的快照进行紧急恢复
	var latest_snapshot = snapshots.back()
	return await restore_snapshot(latest_snapshot)

func _capture_target_properties(target: Node, snapshot: StateSnapshot, config: RestorationConfig) -> void:
	# 获取目标对象的所有属性
	var property_list = target.get_property_list()
	
	for property in property_list:
		var property_name = property.name
		
		# 检查属性是否应该被捕获
		if not _should_capture_property(property_name, config):
			continue
		
		# 跳过只读属性和方法
		if property.usage & PROPERTY_USAGE_READ_ONLY or property.usage & PROPERTY_USAGE_CATEGORY:
			continue
		
		# 捕获属性值
		if property_name in target:
			var value = target.get(property_name)
			
			# 检查值是否可序列化
			if _is_value_serializable(value):
				snapshot.property_values[property_name] = value

func _capture_children_states(target: Node, snapshot: StateSnapshot, config: RestorationConfig) -> void:
	for child in target.get_children():
		if child is Node:
			var child_snapshot = StateSnapshot.new()
			child_snapshot.target_id = child.get_instance_id()
			child_snapshot.context_id = snapshot.context_id
			child_snapshot.version = snapshot.version
			
			_capture_target_properties(child, child_snapshot, config)
			snapshot.children_snapshots.append(child_snapshot)

func _restore_target_properties(target: Node, snapshot: StateSnapshot, config: RestorationConfig) -> void:
	for property_name in snapshot.property_values:
		# 检查属性是否应该被还原
		if not _should_restore_property(property_name, config):
			continue
		
		# 检查属性是否存在
		if property_name in target:
			var value = snapshot.property_values[property_name]
			target.set(property_name, value)

func _restore_children_states(target: Node, snapshot: StateSnapshot, config: RestorationConfig) -> void:
	for child_snapshot in snapshot.children_snapshots:
		var child = target.get_child(child_snapshot.get_index())
		if child and child.get_instance_id() == child_snapshot.target_id:
			_restore_target_properties(child, child_snapshot, config)

func _should_capture_property(property_name: String, config: RestorationConfig) -> bool:
	# 检查白名单
	if config.property_whitelist.size() > 0:
		return property_name in config.property_whitelist
	
	# 检查黑名单
	if config.property_blacklist.size() > 0:
		return not (property_name in config.property_blacklist)
	
	return true

func _should_restore_property(property_name: String, config: RestorationConfig) -> bool:
	return _should_capture_property(property_name, config)

func _is_value_serializable(value) -> bool:
	# 检查值是否可序列化
	if value is Object:
		return false
	
	if value is Callable:
		return false
	
	return true

func _get_restoration_config(context_id: String) -> RestorationConfig:
	if context_id in _restoration_configs:
		return _restoration_configs[context_id]
	
	return _default_config

func set_restoration_config(context_id: String, config: RestorationConfig) -> void:
	_restoration_configs[context_id] = config
	
	# 应用配置限制到现有快照
	_apply_config_limits_to_existing_snapshots(context_id, config)

func get_snapshots_for_target(target: Node) -> Array[StateSnapshot]:
	var target_id = target.get_instance_id()
	var snapshots = _state_snapshots.get(target_id, [])
	
	# 确保返回正确的类型
	var typed_snapshots: Array[StateSnapshot] = []
	for snapshot in snapshots:
		if snapshot is StateSnapshot:
			typed_snapshots.append(snapshot)
	
	return typed_snapshots

func clear_snapshots_for_target(target: Node) -> void:
	var target_id = target.get_instance_id()
	_state_snapshots.erase(target_id)

func clear_all_snapshots() -> void:
	_state_snapshots.clear()
	_snapshot_count = 0

func get_statistics() -> Dictionary:
	# 获取详细的统计信息
	var stats = {
		"snapshot_count": _snapshot_count,
		"restoration_count": _restoration_count,
		"failed_restorations": _failed_restorations,
		"active_targets": _state_snapshots.size(),
		"total_snapshots": _calculate_total_snapshots(),
		"emergency_targets": _emergency_targets.size(),
		"restoration_configs": _restoration_configs.size(),
		"restoration_queue_size": _restoration_queue.size(),
		"memory_usage_estimate": _estimate_memory_usage(),
		"average_snapshot_age": _calculate_average_snapshot_age(),
		"snapshot_creation_rate": _calculate_snapshot_creation_rate(),
		"restoration_success_rate": _calculate_restoration_success_rate()
	}
	
	return stats

func _estimate_memory_usage() -> int:
	# 估算内存使用量（字节）
	var total_memory = 0
	
	# 计算快照内存使用
	for snapshots in _state_snapshots.values():
		for snapshot in snapshots:
			# 基础快照数据
			total_memory += 128  # 基础对象开销
			total_memory += snapshot.property_values.size() * 64  # 属性值估算
			total_memory += snapshot.metadata.size() * 32  # 元数据估算
			total_memory += snapshot.children_snapshots.size() * 64  # 子快照估算
	
	# 计算配置内存使用
	for config in _restoration_configs.values():
		total_memory += 256  # 配置对象开销
		total_memory += config.property_blacklist.size() * 32
		total_memory += config.property_whitelist.size() * 32
	
	return total_memory

func _calculate_average_snapshot_age() -> float:
	# 计算平均快照年龄
	var total_age = 0.0
	var snapshot_count = 0
	var current_time = Time.get_ticks_msec() / 1000.0
	
	for target_id in _state_snapshots.keys():
		var snapshots = get_snapshots_for_target_id(target_id)
		for snapshot in snapshots:
			total_age += current_time - snapshot.timestamp
			snapshot_count += 1
	
	return total_age / snapshot_count if snapshot_count > 0 else 0.0

func _calculate_snapshot_creation_rate() -> float:
	# 计算快照创建速率（每秒）
	var current_time = Time.get_ticks_msec() / 1000.0
	var time_window = 60.0  # 60秒时间窗口
	
	var recent_snapshots = 0
	for target_id in _state_snapshots.keys():
		var snapshots = get_snapshots_for_target_id(target_id)
		for snapshot in snapshots:
			if current_time - snapshot.timestamp <= time_window:
				recent_snapshots += 1
	
	return recent_snapshots / time_window

func _calculate_restoration_success_rate() -> float:
	# 计算还原成功率
	var total_restorations = _restoration_count + _failed_restorations
	return float(_restoration_count) / total_restorations if total_restorations > 0 else 1.0

func _calculate_total_snapshots() -> int:
	var total = 0
	for target_id in _state_snapshots.keys():
		var snapshots = get_snapshots_for_target_id(target_id)
		total += snapshots.size()
	return total

# 辅助方法：通过target_id获取快照
func get_snapshots_for_target_id(target_id: int) -> Array[StateSnapshot]:
	var snapshots = _state_snapshots.get(target_id, [])
	
	# 确保返回正确的类型
	var typed_snapshots: Array[StateSnapshot] = []
	for snapshot in snapshots:
		if snapshot is StateSnapshot:
			typed_snapshots.append(snapshot)
	
	return typed_snapshots

func _emit_state_event(event_type: String, data: Variant) -> void:
	# 发送状态事件
	var event_data = {}
	
	if data is StateSnapshot:
		var snapshot = data as StateSnapshot
		event_data = {
			"type": event_type,
			"target_id": snapshot.target_id,
			"context_id": snapshot.context_id,
			"timestamp": snapshot.timestamp,
			"version": snapshot.version
		}
	elif data is Dictionary:
		event_data = data
		event_data["type"] = event_type
	else:
		event_data = {
			"type": event_type,
			"timestamp": Time.get_ticks_msec() / 1000.0
		}
	
	# 通过事件系统发送状态事件
	# JuicyEventBus.emit_signal("state_event", event_data)  # 暂时注释，等待事件系统实现
	
	# 临时日志记录
	if event_type in ["runtime_failure", "state_restored"]:
		print("[PropertyStateManager] Event: %s, Data: %s" % [event_type, str(event_data)])

func process_auto_snapshots(delta: float) -> void:
	# 处理自动快照逻辑
	for context_id in _restoration_configs.keys():
		var config = _restoration_configs[context_id]
		if not config.auto_snapshot:
			continue
		
		# 获取上下文
		var context = JuicyMixer.get_context(context_id)
		if not context or not context.target:
			continue
		
		# 检查是否需要创建快照
		var last_snapshot_time = _get_last_snapshot_time(context.target)
		var current_time = Time.get_ticks_msec() / 1000.0
		
		if current_time - last_snapshot_time >= config.snapshot_frequency:
			create_snapshot(context.target, context_id, {
				"phase": "auto_snapshot",
				"timestamp": current_time,
				"delta": delta
			})

func _get_last_snapshot_time(target: Node) -> float:
	var snapshots = get_snapshots_for_target(target)
	
	if snapshots.is_empty():
		return 0.0
	
	return snapshots.back().timestamp

func register_emergency_target(target: Node) -> void:
	var target_id = target.get_instance_id()
	_emergency_targets[target_id] = true

func unregister_emergency_target(target: Node) -> void:
	var target_id = target.get_instance_id()
	_emergency_targets.erase(target_id)

func is_emergency_target(target: Node) -> bool:
	var target_id = target.get_instance_id()
	return target_id in _emergency_targets

func handle_runtime_failure(context_id: String, failure_type: String) -> bool:
	# 处理运行时异常，恢复相关对象状态
	var context = JuicyMixer.get_context(context_id)
	if not context or not context.target:
		_log_runtime_error("Invalid context or target for runtime failure handling", {
			"context_id": context_id,
			"failure_type": failure_type
		})
		# 对于测试，如果context无效，尝试直接从快照中恢复
		return await _attempt_direct_snapshot_recovery(context_id, failure_type)
	
	# 记录失败信息
	_failed_restorations += 1
	
	# 识别异常类型并确定恢复策略
	var failure_analysis = _analyze_failure_type(failure_type, context)
	var recovery_strategy = failure_analysis.recovery_strategy
	var severity_level = failure_analysis.severity_level
	
	# 触发失败事件
	_emit_state_event("runtime_failure", {
		"target_id": context.target.get_instance_id(),
		"context_id": context_id,
		"failure_type": failure_type,
		"severity_level": severity_level,
		"recovery_strategy": recovery_strategy,
		"timestamp": Time.get_ticks_msec() / 1000.0,
		"analysis": failure_analysis
	})
	
	# 根据恢复策略执行相应的恢复操作
	var restored = false
	
	match recovery_strategy:
		"auto_restore":
			# 尝试自动恢复到最近的稳定状态
			restored = await auto_restore_state(context.target, context_id)
			
		"emergency_restore":
			# 尝试紧急恢复到最新快照
			restored = await emergency_restore(context.target)
			
		"selective_restore":
			# 选择性恢复关键属性
			restored = _perform_selective_restore(context.target, context_id, failure_analysis)
			
		"graceful_degradation":
			# 优雅降级：重置到安全状态
			restored = _perform_graceful_degradation(context.target, context_id)
			
		"fail_safe":
			# 故障安全：完全重置对象状态
			restored = _perform_fail_safe_restore(context.target, context_id)
	
	# 如果主要恢复策略失败，尝试备用策略
	if not restored:
		restored = await _attempt_fallback_recovery(context.target, context_id, recovery_strategy)
	
	# 记录恢复结果
	_log_recovery_result(context.target, context_id, restored, recovery_strategy, failure_type)
	
	return restored

func _analyze_failure_type(failure_type: String, context: JuicyContext) -> Dictionary:
	# 分析失败类型并确定恢复策略
	var analysis = {
		"failure_type": failure_type,
		"severity_level": "medium",
		"recovery_strategy": "auto_restore",
		"description": "",
		"suggested_actions": []
	}
	
	# 根据失败类型进行分类处理
	match failure_type.to_lower():
		# 属性访问错误
		"property_access", "property_missing", "property_type_mismatch":
			analysis.severity_level = "low"
			analysis.recovery_strategy = "selective_restore"
			analysis.description = "Property access failure detected"
			analysis.suggested_actions = ["skip_problematic_properties", "validate_property_list"]
			
		# 对象状态损坏
		"state_corruption", "invalid_state", "snapshot_corruption":
			analysis.severity_level = "high"
			analysis.recovery_strategy = "emergency_restore"
			analysis.description = "Object state corruption detected"
			analysis.suggested_actions = ["use_emergency_snapshot", "validate_state_integrity"]
			
		# 内存相关问题
		"memory_error", "out_of_memory", "memory_leak":
			analysis.severity_level = "critical"
			analysis.recovery_strategy = "graceful_degradation"
			analysis.description = "Memory-related failure detected"
			analysis.suggested_actions = ["reduce_memory_usage", "cleanup_snapshots", "limit_restoration_scope"]
			
		# 性能问题
		"performance_degradation", "timeout", "slow_operation":
			analysis.severity_level = "medium"
			analysis.recovery_strategy = "graceful_degradation"
			analysis.description = "Performance degradation detected"
			analysis.suggested_actions = ["reduce_restoration_complexity", "use_simpler_interpolation"]
			
		# 系统资源问题
		"resource_unavailable", "system_error", "external_dependency":
			analysis.severity_level = "high"
			analysis.recovery_strategy = "fail_safe"
			analysis.description = "System resource failure detected"
			analysis.suggested_actions = ["reset_to_safe_state", "notify_system_admin"]
			
		# 未知或通用错误
		_:
			analysis.severity_level = "medium"
			analysis.recovery_strategy = "auto_restore"
			analysis.description = "Unknown failure type, using default recovery strategy"
			analysis.suggested_actions = ["attempt_standard_restore", "log_detailed_error"]
	
	return analysis

func _perform_selective_restore(target: Node, context_id: String, failure_analysis: Dictionary) -> bool:
	# 执行选择性恢复，只恢复关键属性
	var target_id = target.get_instance_id()
	var snapshots = get_snapshots_for_target(target)
	
	if snapshots.is_empty():
		return false
	
	# 获取最新的快照
	var latest_snapshot = snapshots.back()
	if not latest_snapshot.is_restorable:
		return false
	
	# 识别关键属性（基于失败分析）
	var critical_properties = _identify_critical_properties(target, latest_snapshot, failure_analysis)
	if critical_properties.is_empty():
		return false
	
	# 只恢复关键属性
	var restore_success = true
	for property_name in critical_properties:
		if property_name in target and property_name in latest_snapshot.property_values:
			# 检查属性是否可写
			var property_list = target.get_property_list()
			var property_info = null
			
			for prop_info in property_list:
				if prop_info.name == property_name:
					property_info = prop_info
					break
			
			# 跳过只读属性
			if property_info and (property_info.usage & PROPERTY_USAGE_READ_ONLY):
				continue
			
			# 尝试恢复属性
			var value = latest_snapshot.property_values[property_name]
			var current_value = target.get(property_name)
			
			# 检查类型兼容性
			if typeof(current_value) == typeof(value) or _can_convert_type(typeof(current_value), typeof(value)):
				target.set(property_name, value)
			else:
				# 类型不匹配，记录警告
				_log_runtime_warning("Failed to restore property '%s' during selective restore - type mismatch" % property_name, {
					"target": target.name,
					"property": property_name,
					"current_type": typeof(current_value),
					"snapshot_type": typeof(value)
				})
				restore_success = false
	
	return restore_success

func _identify_critical_properties(target: Node, snapshot: StateSnapshot, failure_analysis: Dictionary) -> Array[String]:
	# 识别关键属性进行选择性恢复
	var critical_properties: Array[String] = []
	
	# 基础变换属性总是关键的
	var transform_properties = ["position", "rotation", "scale", "global_position", "global_rotation", "global_scale"]
	for prop in transform_properties:
		if prop in snapshot.property_values:
			critical_properties.append(prop)
	
	# 可见性和基础渲染属性
	var visual_properties = ["visible", "modulate", "self_modulate", "z_index"]
	for prop in visual_properties:
		if prop in snapshot.property_values:
			critical_properties.append(prop)
	
	# 根据失败类型添加特定属性
	match failure_analysis.failure_type.to_lower():
		"property_access", "property_missing":
			# 对于属性访问失败，避免恢复可能有问题的属性
			var problematic_properties = failure_analysis.get("problematic_properties", [])
			for prop in snapshot.property_values.keys():
				if prop not in problematic_properties:
					critical_properties.append(prop)
			
		"state_corruption":
			# 对于状态损坏，优先恢复基础属性
			critical_properties = transform_properties + ["visible"]
			
		"memory_error":
			# 对于内存问题，只恢复最必要的属性
			critical_properties = ["position", "rotation", "scale", "visible"]
	
	# 去重并返回
	var unique_properties = []
	for prop in critical_properties:
		if prop not in unique_properties and prop in snapshot.property_values:
			unique_properties.append(prop)
	
	return unique_properties

func _perform_graceful_degradation(target: Node, context_id: String) -> bool:
	# 执行优雅降级，重置到安全状态
	# 设置基础安全属性
	var degradation_success = true
	
	if "position" in target:
		target.set("position", Vector2.ZERO)
	if "rotation" in target:
		target.set("rotation", 0.0)
	if "scale" in target:
		target.set("scale", Vector2.ONE)
	if "visible" in target:
		target.set("visible", true)
	if "modulate" in target:
		target.set("modulate", Color.WHITE)
	
	# 清理可能的问题状态
	var cleanup_success = _cleanup_problematic_state(target)
	
	return degradation_success and cleanup_success

func _perform_fail_safe_restore(target: Node, context_id: String) -> bool:
	# 执行故障安全恢复，完全重置对象状态
	# 尝试获取目标的类默认值
	var target_class = target.get_class()
	var default_values = _get_class_default_values(target_class)
	
	# 应用默认值
	for property_name in default_values.keys():
		if property_name in target:
			target.set(property_name, default_values[property_name])
	
	# 清理所有快照（因为它们可能已损坏）
	clear_snapshots_for_target(target)
	
	return true

func _get_class_default_values(target_class: String) -> Dictionary:
	# 获取类的默认属性值
	var defaults = {
		"position": Vector2.ZERO,
		"rotation": 0.0,
		"scale": Vector2.ONE,
		"visible": true,
		"modulate": Color.WHITE,
		"self_modulate": Color.WHITE,
		"z_index": 0,
		"z_as_relative": true
	}
	
	# 根据类类型添加特定默认值
	match target_class:
		"Node2D":
			defaults["position"] = Vector2.ZERO
			defaults["rotation"] = 0.0
			defaults["scale"] = Vector2.ONE
		"Control":
			defaults["size"] = Vector2(40, 40)
			defaults["mouse_filter"] = 0  # MOUSE_FILTER_STOP
		"Sprite2D":
			defaults["flip_h"] = false
			defaults["flip_v"] = false
	
	return defaults

func _attempt_fallback_recovery(target: Node, context_id: String, failed_strategy: String) -> bool:
	# 尝试备用恢复策略
	var fallback_strategies = {
		"auto_restore": "emergency_restore",
		"emergency_restore": "selective_restore",
		"selective_restore": "graceful_degradation",
		"graceful_degradation": "fail_safe",
		"fail_safe": "emergency_restore"  # 最后循环回紧急恢复
	}
	
	var fallback_strategy = fallback_strategies.get(failed_strategy)
	if not fallback_strategy or fallback_strategy == failed_strategy:
		return false
	
	_log_runtime_info("Attempting fallback recovery strategy", {
		"target": target.name,
		"from_strategy": failed_strategy,
		"to_strategy": fallback_strategy
	})
	
	# 执行备用策略
	match fallback_strategy:
		"emergency_restore":
			return await emergency_restore(target)
		"selective_restore":
			var dummy_analysis = {"failure_type": "fallback"}
			return _perform_selective_restore(target, context_id, dummy_analysis)
		"graceful_degradation":
			return _perform_graceful_degradation(target, context_id)
		"fail_safe":
			return _perform_fail_safe_restore(target, context_id)
	
	return false

func _cleanup_problematic_state(target: Node) -> bool:
	# 清理可能导致问题的状态
	var cleanup_success = true
	
	# 停止所有动画
	if target.has_method("get_child_count"):
		for i in range(target.get_child_count()):
			var child = target.get_child(i)
			if child and child.has_method("stop"):
				child.call("stop")
	
	# 清理定时器
	if target.has_method("get_tree"):
		var tree = target.get_tree()
		if tree:
			# 延迟清理，给系统时间处理
			var timer = tree.create_timer(0.1)
			if timer:
				timer.timeout.connect(_finalize_cleanup.bind(target))
	
	return cleanup_success

func _can_convert_type(from_type: int, to_type: int) -> bool:
	# 检查类型是否可以转换
	# 数值类型之间可以转换
	var numeric_types = [TYPE_INT, TYPE_FLOAT]
	if from_type in numeric_types and to_type in numeric_types:
		return true
	
	# Vector类型之间不能转换
	if from_type in [TYPE_VECTOR2, TYPE_VECTOR3, TYPE_VECTOR4] and to_type in [TYPE_VECTOR2, TYPE_VECTOR3, TYPE_VECTOR4]:
		return from_type == to_type
	
	# 其他类型需要完全匹配
	return from_type == to_type

func _finalize_cleanup(target: Node) -> void:
	# 最终清理工作
	if target and is_instance_valid(target) and not target.is_queued_for_deletion():
		# 确保目标处于稳定状态
		pass

func _log_runtime_error(message: String, data: Dictionary) -> void:
	# 记录运行时错误
	push_error("[PropertyStateManager] %s: %s" % [message, str(data)])
	_emit_state_event("runtime_error", {
		"message": message,
		"data": data,
		"timestamp": Time.get_ticks_msec() / 1000.0
	})

func _log_runtime_warning(message: String, data: Dictionary) -> void:
	# 记录运行时警告
	push_warning("[PropertyStateManager] %s: %s" % [message, str(data)])
	_emit_state_event("runtime_warning", {
		"message": message,
		"data": data,
		"timestamp": Time.get_ticks_msec() / 1000.0
	})

func _log_runtime_info(message: String, data: Dictionary) -> void:
	# 记录运行时信息
	print("[PropertyStateManager] INFO: %s: %s" % [message, str(data)])
	_emit_state_event("runtime_info", {
		"message": message,
		"data": data,
		"timestamp": Time.get_ticks_msec() / 1000.0
	})

func _log_recovery_result(target: Node, context_id: String, success: bool, strategy: String, failure_type: String) -> void:
	# 记录恢复结果
	var result_data = {
		"target": target.name if target else "unknown",
		"context_id": context_id,
		"success": success,
		"strategy": strategy,
		"failure_type": failure_type,
		"timestamp": Time.get_ticks_msec() / 1000.0
	}
	
	if success:
		_log_runtime_info("Recovery successful", result_data)
	else:
		_log_runtime_error("Recovery failed", result_data)

func validate_state_integrity(target: Node, context_id: String = "") -> Dictionary:
	# 验证状态完整性
	var target_id = target.get_instance_id()
	var validation_result = {
		"is_valid": true,
		"errors": [],
		"warnings": [],
		"target_id": target_id,
		"context_id": context_id
	}
	
	var snapshots = get_snapshots_for_target(target)
	
	if snapshots.is_empty():
		validation_result.warnings.append("No snapshots found for target")
		return validation_result
	
	# 获取最新的快照
	var latest_snapshot = snapshots.back()
	
	# 验证快照基本属性
	if not latest_snapshot.is_restorable:
		validation_result.is_valid = false
		validation_result.errors.append("Latest snapshot is not restorable")
	
	if latest_snapshot.target_id != target_id:
		validation_result.is_valid = false
		validation_result.errors.append("Snapshot target ID mismatch")
	
	# 验证属性值
	for property_name in latest_snapshot.property_values:
		if not (property_name in target):
			validation_result.warnings.append("Property '%s' not found in target" % property_name)
			continue
		
		var current_value = target.get(property_name)
		var snapshot_value = latest_snapshot.property_values[property_name]
		
		# 检查属性类型是否匹配
		if typeof(current_value) != typeof(snapshot_value):
			validation_result.warnings.append("Property '%s' type mismatch: current=%s, snapshot=%s" % [
				property_name, typeof(current_value), typeof(snapshot_value)
			])
	
	# 验证子节点状态
	for child_snapshot in latest_snapshot.children_snapshots:
		var child = target.get_node(child_snapshot.get_index())
		if not child or child.get_instance_id() != child_snapshot.target_id:
			validation_result.warnings.append("Child node mismatch in snapshot")
	
	return validation_result

func get_state_validation_report(target: Node, context_id: String = "") -> String:
	# 获取状态验证报告
	var validation = validate_state_integrity(target, context_id)
	var report = "State Validation Report for target '%s':\n" % target.name
	
	report += "Valid: %s\n" % validation.is_valid
	report += "Errors: %d\n" % validation.errors.size()
	report += "Warnings: %d\n" % validation.warnings.size()
	
	if validation.errors.size() > 0:
		report += "Errors:\n"
		for error in validation.errors:
			report += "  - %s\n" % error
	
	if validation.warnings.size() > 0:
		report += "Warnings:\n"
		for warning in validation.warnings:
			report += "  - %s\n" % warning
	
	return report

# 尝试直接从快照中恢复（用于测试环境）
func _attempt_direct_snapshot_recovery(context_id: String, failure_type: String) -> bool:
	# 查找所有快照
	for target_id in _state_snapshots.keys():
		var snapshots = _state_snapshots[target_id]
		if not snapshots is Array:
			continue
			
		for snapshot in snapshots:
			if snapshot is StateSnapshot and snapshot.context_id == context_id:
				# 尝试恢复这个快照
				var target = instance_from_id(snapshot.target_id)
				if target:
					# 调试输出已移除
					return await restore_snapshot(snapshot)
	
	return false

# 应用配置限制到现有快照
func _apply_config_limits_to_existing_snapshots(context_id: String, config: RestorationConfig) -> void:
	# 应用配置限制到现有快照 - 移除调试输出以提高性能
	
	# 查找所有使用此context_id的快照
	for target_id in _state_snapshots.keys():
		var snapshots = _state_snapshots[target_id]
		if not snapshots is Array:
			continue
			
		# 过滤出使用此context_id的快照
		var context_snapshots: Array[StateSnapshot] = []
		for snapshot in snapshots:
			if snapshot is StateSnapshot and snapshot.context_id == context_id:
				context_snapshots.append(snapshot)
		
		# 如果快照数量超过限制，移除最旧的快照
		while context_snapshots.size() > config.max_snapshots_per_target:
			var oldest_snapshot = context_snapshots[0]
			snapshots.erase(oldest_snapshot)
			context_snapshots.erase(oldest_snapshot)
