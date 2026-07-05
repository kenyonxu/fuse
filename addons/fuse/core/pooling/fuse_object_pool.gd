# FuseObjectPool - 通用对象池
# 支持自动扩容、收缩和性能监控
# 专门用于管理场景实例

class_name FuseObjectPool extends RefCounted

## 池管理
var _pool_items: Array[FusePoolItem] = []
var _scene_path: String = ""
var _pool_size: int = 20
var _max_pool_size: int = 100
var _min_pool_size: int = 5
var _auto_resize: bool = true
var _resize_threshold: float = 0.8

## 统计信息
var _total_created: int = 0
var _total_reused: int = 0
var _peak_usage: int = 0
var _cleanup_count: int = 0

## 性能配置
var _enable_debug: bool = false

## 构造函数
func _init(scene_path: String, initial_size: int = 20):
	_scene_path = scene_path
	_pool_size = initial_size
	_pool_size = clamp(_pool_size, _min_pool_size, _max_pool_size)

## 获取对象
##
## 从池中获取可用对象，如果没有可用对象则创建新对象
##
## 返回：
## - Node - 场景实例，如果池已满且无法创建则返回 null
func get_object() -> Node:
	var pool_item: FusePoolItem = null
	var obj: Node = null

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

		if _enable_debug:
			var obj_pos = obj.global_position if obj.has_method("global_position") else obj.position
			_log_debug("重用对象", {
				"scene_path": _scene_path,
				"pool_item_id": pool_item.pool_item_id,
				"total_reused": _total_reused,
				"object_name": obj.name,
				"current_position": str(obj_pos),
				"instance_id": obj.get_instance_id() if obj.has_method("get_instance_id") else 0
			})
	else:
		# 没有可用对象，创建新对象
		if _pool_items.size() < _max_pool_size:
			obj = _load_scene()
			if obj:
				pool_item = FusePoolItem.new(obj)
				pool_item.mark_used()
				_pool_items.append(pool_item)
				_total_created += 1

				if _enable_debug:
					_log_debug("创建新对象", {
						"scene_path": _scene_path,
						"pool_item_id": pool_item.pool_item_id,
						"total_created": _total_created
					})
		else:
			# 池已满且没有可用对象
			_log_warning("池已满，无法创建新对象", {
				"scene_path": _scene_path,
				"pool_size": _pool_items.size(),
				"max_pool_size": _max_pool_size
			})
			return null

	# 更新峰值使用量
	var current_usage = _get_current_usage()
	if current_usage > _peak_usage:
		_peak_usage = current_usage

		if _enable_debug:
			_log_debug("新的峰值使用量", {
				"scene_path": _scene_path,
				"peak_usage": _peak_usage,
				"current_usage": current_usage
			})

	return obj

## 通过实例 ID 查找池项
func _find_pool_item_by_instance_id(instance_id: int) -> FusePoolItem:
	for item in _pool_items:
		if item.object and item.object.get_instance_id() == instance_id:
			return item
	return null

## 归还对象到池中
##
## 将使用完毕的对象归还到池中，以便后续复用
##
## 参数：
## - obj: 要归还的场景实例
func return_object(obj: Node) -> void:
	if not obj:
		_log_warning("尝试归还 null 对象")
		return

	# 查找对应的池项
	for item in _pool_items:
		if item.object == obj:
			var obj_pos = obj.global_position if obj.has_method("global_position") else obj.position
			var was_in_tree = obj.get_parent() != null

			# 在从场景树移除之前，先停止 Trigger 的物理处理
			# 否则 Trigger 的 _physics_process 仍在运行，会导致状态混乱
			if was_in_tree:
				_terminate_fuse_triggers(obj)

			# 从场景树中移除（如果还在场景树中）
			# 使用 call_deferred 避免在物理回调中移除节点
			if was_in_tree:
				_schedule_safe_remove(obj)

			item.mark_unused()

			if _enable_debug:
				_log_debug("对象已归还到池", {
					"scene_path": _scene_path,
					"pool_item_id": item.pool_item_id,
					"object_name": obj.name,
					"position_at_recycle": str(obj_pos),
					"was_in_scene_tree": was_in_tree,
					"usage_count": item.usage_count
				})
			return

	# 如果没找到对应的池项，可能是外部创建的对象
	_log_warning("对象未在池中找到，创建新的池项", {
		"scene_path": _scene_path
	})

	var pool_item = FusePoolItem.new(obj)
	pool_item.mark_unused()
	_pool_items.append(pool_item)
	_total_created += 1

## 加载场景
func _load_scene() -> Node:
	if _scene_path.is_empty():
		return null

	var packed_scene = load(_scene_path)
	if not packed_scene:
		_log_error("加载场景失败", {
			"scene_path": _scene_path
		})
		return null

	if not (packed_scene is PackedScene):
		_log_error("资源不是 PackedScene", {
			"scene_path": _scene_path
		})
		return null

	var instance = packed_scene.instantiate()
	if not instance:
		_log_error("实例化场景失败", {
			"scene_path": _scene_path
		})
		return null

	return instance

## 重置对象状态
##
## 重置对象的基本属性，确保对象可安全复用
##
## 参数：
## - obj: 要重置的节点对象
func reset_object(obj: Node) -> void:
	# 如果对象有 reset 方法，调用它
	if obj.has_method("reset"):
		obj.reset()

	# 🔧 遍历所有子节点，重置 Fuse 组件状态
	# 这确保从对象池复用时，每个子弹的 Trigger 和变量都能正确重置
	_reset_fuse_components(obj)

	# 根据具体类型重置 transform（Node2D vs Node3D）
	if obj is Node2D:
		obj.position = Vector2.ZERO
		obj.rotation = 0.0
		obj.scale = Vector2.ONE
		if "z_index" in obj:
			obj.z_index = 0
	elif obj is Node3D:
		obj.position = Vector3.ZERO
		obj.rotation = Vector3.ZERO
		obj.scale = Vector3.ONE

	# 重新设置可见性
	if "visible" in obj:
		obj.visible = true

	# 清除物理状态（适用于 RigidBody2D/RigidBody3D）
	if obj.has_method("set_linear_velocity"):
		obj.set_linear_velocity(Vector2.ZERO if obj is RigidBody2D else Vector3.ZERO)
	if obj.has_method("set_angular_velocity"):
		obj.set_angular_velocity(0.0)

	# 重置 modulate 颜色（如果存在）
	if "modulate" in obj:
		obj.modulate = Color.WHITE
	if "self_modulate" in obj:
		obj.self_modulate = Color.WHITE

## 重置 Fuse 组件状态
##
## 递归重置节点树中所有 Fuse 组件的状态
## 包括 Trigger、ActionRunner、ScopeVariableContainer 等
##
## 参数：
## - node: 要重置的根节点
func _reset_fuse_components(node: Node) -> void:
	if not node:
		return

	# 遍历节点的所有子节点（包括自身）
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var current = stack.pop_back()

		# 重置 Trigger 节点
		if current is Trigger:
			# 调用 Trigger 的专用对象池重置方法
			# 让 Trigger 自己处理完整的重置逻辑（运行时实例重建、信号重连等）
			if current.has_method("pool_reset"):
				current.pool_reset()
			else:
				# 备用方案：调用标准重置
				current.reset()
				current.set_physics_process(true)
				current.set_process(true)

			if _enable_debug:
				_log_debug("重置 Trigger", {"node": current.name, "path": current.get_path()})

		# 🔧 重置 MultiEventTrigger 节点
		elif current is MultiEventTrigger:
			if current.has_method("pool_reset"):
				current.pool_reset()
			elif current.has_method("reset"):
				current.reset()

			if _enable_debug:
				_log_debug("重置 MultiEventTrigger", {"node": current.name, "path": current.get_path()})

		# 🔧 重置 ScopeVariableContainer 的变量
		# 检查是否是 ScopeVariableContainer 节点
		if current.get("variables") != null and current.has_method("get_variable"):
			var vars = current.get("variables")
			if vars is Dictionary:
				# 尝试获取保存的初始变量值
				var default_vars = current.get("_pool_default_variables")
				if default_vars == null:
					# 第一次重置：保存当前值作为默认值
					current.set("_pool_default_variables", vars.duplicate(true))
					if _enable_debug:
						_log_debug("保存默认变量", {"node": current.name, "variables": vars.keys()})
				else:
					# 后续重置：恢复默认值
					for key in default_vars.keys():
						vars[key] = default_vars[key]
					if _enable_debug:
						_log_debug("重置变量到默认值", {"node": current.name, "variables": vars.keys()})

		# 将子节点添加到栈中继续处理
		for i in range(current.get_child_count()):
			stack.append(current.get_child(i))

## 终止 Fuse Trigger
##
## 在对象回收时停止所有 Trigger 的物理处理
## 防止 Trigger 在对象离开场景树后继续运行
##
## 参数：
## - node: 要处理的根节点
func _terminate_fuse_triggers(node: Node) -> void:
	if not node:
		return

	# 遍历节点的所有子节点
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var current = stack.pop_back()

		# 停止 Trigger 节点的物理处理
		if current is Trigger:
			# 禁用物理处理
			current.set_physics_process(false)
			current.set_process(false)

			# 调用 terminate 清理事件监听
			if current.get("event_definition") != null:
				var event_def = current.get("event_definition")
				if event_def and event_def.has_method("terminate"):
					event_def.terminate(current)

			if _enable_debug:
				_log_debug("终止 Trigger", {"node": current.name, "path": current.get_path()})

		# 🔧 停止 MultiEventTrigger 节点的处理
		elif current is MultiEventTrigger:
			current.set_physics_process(false)
			current.set_process(false)

			# 终止所有事件监听
			var bindings = current.get("event_bindings")
			if bindings:
				for binding in bindings:
					if binding and binding.get("event") != null:
						var event = binding.get("event")
						if event.has_method("terminate"):
							event.terminate(current)

			if _enable_debug:
				_log_debug("终止 MultiEventTrigger", {"node": current.name, "path": current.get_path()})

		# 将子节点添加到栈中继续处理
		for i in range(current.get_child_count()):
			stack.append(current.get_child(i))

## 安全地移除节点（延迟执行，避免物理回调冲突）
func _schedule_safe_remove(obj: Node) -> void:
	if not obj:
		return
	# 延迟一帧后执行，确保在物理回调之外
	obj.get_tree().create_timer(0.0).timeout.connect(_do_safe_remove.bind(obj))

## 执行安全移除
func _do_safe_remove(obj: Node) -> void:
	if not obj or not is_instance_valid(obj):
		return
	if obj.get_parent():
		obj.get_parent().remove_child(obj)

## 预热池
##
## 预先创建指定数量的对象放入池中，减少运行时创建开销
##
## 参数：
## - count: 要预热的对象数量
func warm_up(count: int) -> void:
	var actual_count = min(count, _pool_size)
	for i in range(actual_count):
		var obj = _load_scene()
		if obj:
			var pool_item = FusePoolItem.new(obj)
			pool_item.mark_unused()
			_pool_items.append(pool_item)
			_total_created += 1

	if _enable_debug:
		_log_debug("池已预热", {
			"scene_path": _scene_path,
			"warm_up_count": actual_count,
			"total_created": _total_created
		})

## 设置池大小
func set_pool_size(size: int) -> void:
	var old_size = _pool_size
	_pool_size = clamp(size, _min_pool_size, _max_pool_size)

	if old_size != _pool_size:
		_adjust_pool_size()
		_log_debug("池大小已更改", {
			"scene_path": _scene_path,
			"old_size": old_size,
			"new_size": _pool_size
		})

## 设置最大池大小
func set_max_pool_size(size: int) -> void:
	var old_max = _max_pool_size
	_max_pool_size = max(size, _min_pool_size)
	_pool_size = min(_pool_size, _max_pool_size)

	if old_max != _max_pool_size:
		_adjust_pool_size()
		_log_debug("最大池大小已更改", {
			"scene_path": _scene_path,
			"old_max": old_max,
			"new_max": _max_pool_size
		})

## 设置最小池大小
func set_min_pool_size(size: int) -> void:
	var old_min = _min_pool_size
	_min_pool_size = max(size, 1)
	_pool_size = max(_pool_size, _min_pool_size)

	if old_min != _min_pool_size:
		_adjust_pool_size()
		_log_debug("最小池大小已更改", {
			"scene_path": _scene_path,
			"old_min": old_min,
			"new_min": _min_pool_size
		})

## 启用/禁用自动调整
func enable_auto_resize(enabled: bool) -> void:
	_auto_resize = enabled
	_log_debug("自动调整 " + ("启用" if enabled else "禁用"), {
		"scene_path": _scene_path
	})

## 设置调整阈值
func set_resize_threshold(threshold: float) -> void:
	_resize_threshold = clamp(threshold, 0.1, 1.0)
	_log_debug("调整阈值已更改", {
		"scene_path": _scene_path,
		"threshold": _resize_threshold
	})

## 调整池大小
func _adjust_pool_size() -> void:
	# 移除多余的未使用对象
	var unused_items: Array[FusePoolItem] = []
	for item in _pool_items:
		if not item.in_use:
			unused_items.append(item)

	# 按效率评分排序，优先保留高效对象
	unused_items.sort_custom(FusePoolItem.compare_by_efficiency)

	# 移除超出池大小的对象
	while unused_items.size() > _pool_size and _pool_items.size() > _min_pool_size:
		var item_to_remove = unused_items.pop_back()  # 移除效率最低的对象
		_pool_items.erase(item_to_remove)

		# 释放对象
		if item_to_remove.object and is_instance_valid(item_to_remove.object):
			item_to_remove.object.queue_free()

		_total_created -= 1

		if _enable_debug:
			_log_debug("从池中移除对象", {
				"scene_path": _scene_path,
				"pool_item_id": item_to_remove.pool_item_id,
				"efficiency_score": item_to_remove.get_efficiency_score()
			})

## 处理自动调整
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
			_log_debug("池自动扩容", {
				"scene_path": _scene_path,
				"usage_ratio": usage_ratio,
				"old_size": _pool_size / 2,
				"new_size": _pool_size
			})
	# 如果使用率很低，减少池大小
	elif usage_ratio < _resize_threshold * 0.5:
		var new_size = max(_pool_size / 2, _min_pool_size)
		if new_size != _pool_size:
			set_pool_size(new_size)
			_log_debug("池自动收缩", {
				"scene_path": _scene_path,
				"usage_ratio": usage_ratio,
				"old_size": _pool_size * 2,
				"new_size": _pool_size
			})

## 获取当前使用量
func _get_current_usage() -> int:
	var count = 0
	for item in _pool_items:
		if item.in_use:
			count += 1
	return count

## 获取未使用对象数量
func _get_unused_count() -> int:
	var count = 0
	for item in _pool_items:
		if not item.in_use:
			count += 1
	return count

## 获取统计信息
func get_statistics() -> Dictionary:
	var reuse_ratio = float(_total_reused) / max(_total_created, 1)
	var efficiency_score = _calculate_efficiency_score()

	return {
		"scene_path": _scene_path,
		"total_created": _total_created,
		"total_reused": _total_reused,
		"pool_size": _pool_items.size(),
		"current_usage": _get_current_usage(),
		"unused_count": _get_unused_count(),
		"peak_usage": _peak_usage,
		"reuse_ratio": reuse_ratio,
		"efficiency_score": efficiency_score,
		"auto_resize": _auto_resize,
		"resize_threshold": _resize_threshold
	}

## 计算效率评分
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

	return score

## 清空池
func clear_pool() -> void:
	# 释放所有对象
	for item in _pool_items:
		if item.object and is_instance_valid(item.object):
			item.object.queue_free()

	_pool_items.clear()
	_total_created = 0
	_total_reused = 0
	_peak_usage = 0

	_log_debug("池已清空", {"scene_path": _scene_path})

## 设置调试日志
func set_debug_logging(enabled: bool) -> void:
	_enable_debug = enabled

## 获取详细状态信息
func get_detailed_status() -> Dictionary:
	var status = get_statistics()
	status["pool_config"] = {
		"min_pool_size": _min_pool_size,
		"max_pool_size": _max_pool_size,
		"auto_resize": _auto_resize,
		"resize_threshold": _resize_threshold
	}

	# 添加池项详细信息
	var pool_items_info = []
	for item in _pool_items:
		pool_items_info.append(item.get_statistics())
	status["pool_items"] = pool_items_info

	return status

## 日志方法
func _log_debug(message: String, data: Dictionary = {}) -> void:
	if _enable_debug:
		print("[FuseObjectPool DEBUG] ", message, " ", data)

func _log_warning(message: String, data: Dictionary = {}) -> void:
	print("[FuseObjectPool WARNING] ", message, " ", data)

func _log_error(message: String, data: Dictionary = {}) -> void:
	print("[FuseObjectPool ERROR] ", message, " ", data)
