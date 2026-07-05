@tool
@icon("res://addons/fuse/icons/builtin/CollisionShape2D.png")
extends BaseEvent
class_name OnCollision

## Event: OnCollision
##
## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - 此 Event 主要通过信号机制工作，无需额外状态变量
## - 目标节点引用由 RuntimeInstance 管理生命周期
##
## 架构版本: 自声明状态模式 v2.0
## 相关文档: addons/fuse/docs/migration-guide-to-runtime-instance.md

## 碰撞事件
##
## 当物理体发生碰撞时触发，传递完整的碰撞信息。

## 目标物理体节点路径
@export var target_node: NodePath = NodePath(""):
	set(value):
		target_node = value
		_update_resource_name()

## 碰撞层过滤（位掩码，0 = 所有层）
@export var collision_mask: int = 0:
	set(value):
		collision_mask = value
		_update_resource_name()

## 是否传递碰撞信息
@export var emit_collision_info: bool = true

var _target_node_ref: Node = null

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	# OnCollision 主要通过信号机制工作，无需额外状态变量
	return base

## 更新资源名称（必需）
func _update_resource_name():
	var mask_display = ""
	var mask_text = ""
	if collision_mask != 0:
		mask_text = str(collision_mask)
		mask_display = FuseLocalization.translate_format("FUSE_EVENT_COLLISION_LAYER_MASK", {"mask": mask_text})

	var mask_display_full = mask_display if mask_display else ""
	resource_name = FuseLocalization.translate_format("FUSE_EVENT_COLLISION_RESOURCE_NAME", {
		"mask": mask_text
	})

## 使用 RuntimeInstance 初始化事件
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		return

	_runtime_instance_ref = runtime_instance

	# 验证 owner_node
	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 验证目标节点路径
	if target_node.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 获取目标节点
	_target_node_ref = owner_node.get_node_or_null(target_node)
	if not _target_node_ref:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(target_node)})
		return

	# 验证节点类型（2D 物理体）
	if not _is_valid_physics_body_2d(_target_node_ref):
		_create_fuse_error_localized("FUSE_ERROR_INVALID_TARGET", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(target_node)})
		return

	# 连接碰撞信号（使用 body_collide_shape 信号）
	if _target_node_ref.has_signal("body_collide_shape"):
		if not _target_node_ref.body_collide_shape.is_connected(_on_body_collide_shape):
			_target_node_ref.body_collide_shape.connect(_on_body_collide_shape)
	else:
		# 回退：使用标准的碰撞检测
		if _target_node_ref.has_signal("body_entered"):
			if not _target_node_ref.body_entered.is_connected(_on_body_entered):
				_target_node_ref.body_entered.connect(_on_body_entered)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 初始化事件监听（必需）- 向后兼容
func initialize(owner_node: Node) -> void:
	# 验证 owner_node
	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 验证目标节点路径
	if target_node.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 获取目标节点
	_target_node_ref = owner_node.get_node_or_null(target_node)
	if not _target_node_ref:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(target_node)})
		return

	# 验证节点类型（2D 物理体）
	if not _is_valid_physics_body_2d(_target_node_ref):
		_create_fuse_error_localized("FUSE_ERROR_INVALID_TARGET", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(target_node)})
		return

	# 连接碰撞信号（使用 body_collide_shape 信号）
	if _target_node_ref.has_signal("body_collide_shape"):
		if not _target_node_ref.body_collide_shape.is_connected(_on_body_collide_shape):
			_target_node_ref.body_collide_shape.connect(_on_body_collide_shape)
	else:
		# 回退：使用标准的碰撞检测
		if _target_node_ref.has_signal("body_entered"):
			if not _target_node_ref.body_entered.is_connected(_on_body_entered):
				_target_node_ref.body_entered.connect(_on_body_entered)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	# 断开信号连接
	if _target_node_ref and is_instance_valid(_target_node_ref):
		if _target_node_ref.has_signal("body_collide_shape"):
			if _target_node_ref.body_collide_shape.is_connected(_on_body_collide_shape):
				_target_node_ref.body_collide_shape.disconnect(_on_body_collide_shape)

		if _target_node_ref.has_signal("body_entered"):
			if _target_node_ref.body_entered.is_connected(_on_body_entered):
				_target_node_ref.body_entered.disconnect(_on_body_entered)

	# 清理引用
	_target_node_ref = null
	_runtime_instance_ref = null

	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 碰撞形状回调（Godot 4.2+）
func _on_body_collide_shape(body: Node2D, body_shape_index: int, local_shape_index: int):
	# 检查碰撞层过滤
	if collision_mask != 0:
		if not _check_collision_layer(body, collision_mask):
			_log_debug_localized("FUSE_LOG_EVENT_COLLISION_LAYER_FILTERED", {
				"body": body.name,
				"mask": collision_mask
			})
			return

	_log_info_localized("FUSE_LOG_EVENT_COLLISION_TRIGGERED", {
		"body": body.name,
		"body_shape": body_shape_index,
		"local_shape": local_shape_index
	})

	# 创建上下文节点传递碰撞信息
	if emit_collision_info:
		var context_node = Node.new()
		context_node.name = "CollisionContext"
		context_node.set_meta("collider", body)
		context_node.set_meta("collider_shape_index", body_shape_index)
		context_node.set_meta("local_shape_index", local_shape_index)
		context_node.set_meta("target_node", _target_node_ref)

		# 尝试获取碰撞位置和法线（需要 PhysicsDirectSpaceState2D）
		_collision_info_extend(context_node, body, body_shape_index, local_shape_index)

		triggered.emit(context_node)
	else:
		triggered.emit(body)

## 物体进入回调（兼容模式）
func _on_body_entered(body: Node2D):
	# 检查碰撞层过滤
	if collision_mask != 0:
		if not _check_collision_layer(body, collision_mask):
			return

	_log_info_localized("FUSE_LOG_EVENT_COLLISION_TRIGGERED", {
		"body": body.name,
		"mode": "body_entered"
	})

	# 创建上下文节点传递基本信息
	if emit_collision_info:
		var context_node = Node.new()
		context_node.name = "CollisionContext"
		context_node.set_meta("collider", body)
		context_node.set_meta("target_node", _target_node_ref)
		triggered.emit(context_node)
	else:
		triggered.emit(body)

## 扩展碰撞信息
func _collision_info_extend(context_node: Node, body: Node2D, body_shape_index: int, local_shape_index: int):
	# 获取 PhysicsDirectSpaceState2D
	if not _target_node_ref or not _target_node_ref.is_inside_tree():
		return

	var space_state = _target_node_ref.get_world_2d().direct_space_state
	if not space_state:
		return

	# 获取碰撞形状
	var target_shape_owner = _target_node_ref.shape_find_owner(local_shape_index)
	var target_shape = _target_node_ref.shape_owner_get_shape(target_shape_owner, local_shape_index)

	if body is PhysicsBody2D and body.shape_find_owner(body_shape_index) != -1:
		var body_shape_owner = body.shape_find_owner(body_shape_index)
		var body_shape = body.shape_owner_get_shape(body_shape_owner, body_shape_index)

		# 获取形状变换
		var target_transform = _target_node_ref.global_transform
		var body_transform = body.global_transform

		# 存储形状信息
		context_node.set_meta("target_shape", target_shape)
		context_node.set_meta("body_shape", body_shape)
		context_node.set_meta("target_transform", target_transform)
		context_node.set_meta("body_transform", body_transform)

		# 如果是 CharacterBody2D，获取速度
		if body is CharacterBody2D:
			var char_body = body as CharacterBody2D
			context_node.set_meta("collider_velocity", char_body.velocity)

## 检查碰撞层
func _check_collision_layer(body: Node2D, mask: int) -> bool:
	if not body is PhysicsBody2D:
		return true

	var physics_body = body as PhysicsBody2D
	return (physics_body.collision_layer & mask) != 0

## 检查是否是有效的 2D 物理体
func _is_valid_physics_body_2d(node: Node) -> bool:
	return node is PhysicsBody2D or node is CharacterBody2D

## 获取事件描述
func get_description() -> String:
	var node_name = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_EVENT_ON_COLLISION_NOT_SPECIFIED")

	var mask_text = ""
	if collision_mask != 0:
		mask_text = FuseLocalization.translate_format("FUSE_EVENT_ON_COLLISION_WITH_MASK", {"mask": str(collision_mask)})

	return FuseLocalization.translate_format("FUSE_EVENT_ON_COLLISION_DESC", {
		"node": node_name,
		"mask": mask_text
	})

## 获取事件类型
func get_event_type() -> String:
	return "collision"

## 获取事件分类
func get_event_category() -> String:
	return "physics"

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	if target_node.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))

	# 验证碰撞层掩码范围
	if collision_mask < 0 or collision_mask > 0xFFFFFFFF:
		errors.append(FuseLocalization.translate("FUSE_ERROR_COLLISION_LAYER_MASK_INVALID"))

	return errors

## 重置事件状态
func reset() -> void:
	super.reset()
	# OnCollision 主要通过信号机制工作，无需重置额外状态
	_log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_ON_COLLISION_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_PHYSICS"
	metadata.description_key = "FUSE_EVENT_ON_COLLISION_DESC"
	metadata.keywords = ["collision", "碰撞", "physics", "物理", "body", "物体", "shape", "形状", "contact", "接触"]
	metadata.builtin_icon = "CollisionShape2D"
	return metadata
