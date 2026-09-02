@tool
@icon("res://addons/fuse/icons/builtin/InputEventMouseMotion.png")
extends BaseEvent
class_name OnMouseMove

## Event: OnMouseMove
##
## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - _last_mouse_position: Vector2 - 上次鼠标位置
## - _accumulated_distance: float - 累积移动距离
##
## 架构版本: 自声明状态模式 v2.0
## 相关文档: addons/fuse/docs/zh_CN/dev_docs/guides/runtime-instance-migration-guide.md

## 鼠标移动事件
##
## 监听鼠标移动事件，支持持续触发和阈值触发模式。

## 触发模式
enum TriggerMode {
	CONTINUOUS,  # 持续触发（每次移动都触发）
	ON_THRESHOLD  # 达到阈值触发（移动超过指定像素距离后触发）
}

## 触发模式
var trigger_mode: TriggerMode = TriggerMode.CONTINUOUS:
	set(value):
		trigger_mode = value
		_update_resource_name()

## 移动阈值（像素，仅用于 ON_THRESHOLD 模式）
@export var move_threshold: float = 10.0:
	set(value):
		move_threshold = value
		_update_resource_name()

## 是否需要悬停在控制节点上
@export var require_hovered: bool = false:
	set(value):
		require_hovered = value
		_update_resource_name()

## 目标节点（用于悬停检测，为空时使用 owner_node）
@export var target_node_path: NodePath = NodePath("")

# 缓存 Trigger Mode 本地化字符串
static var _cached_trigger_modes: Array[String] = []
static var _trigger_modes_cached: bool = false

## 初始化 Trigger Mode 本地化缓存
##
## 这个方法会缓存 Trigger Mode 的本地化字符串，避免在 _get_property_list() 中频繁调用翻译函数
static func _init_trigger_modes_cache() -> void:
	if _trigger_modes_cached:
		return

	_cached_trigger_modes = [
		FuseLocalization.translate("FUSE_EVENT_MOUSE_MOVE_CONTINUOUS"),
		FuseLocalization.translate("FUSE_EVENT_MOUSE_MOVE_THRESHOLD")
	]

	_trigger_modes_cached = true

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []

	# 初始化缓存（如果还没有初始化）
	_init_trigger_modes_cache()

	# 添加触发模式属性
	# 使用缓存的本地化字符串，避免在 _get_property_list() 中频繁调用翻译函数
	var trigger_modes_hint: String = ",".join(_cached_trigger_modes)
	properties.append({
		"name": "trigger_mode",
		"type": TYPE_INT,
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": trigger_modes_hint
	})

	return properties

# RuntimeInstance 引用已在 BaseEvent 中定义
var _target_node_ref: Node = null
var _owner_node_ref: Node = null

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["last_mouse_position"] = Vector2.INF
	base["accumulated_distance"] = 0.0
	return base

## 更新资源名称（必需）
func _update_resource_name():
	var mode_text = ""
	var threshold_text = ""
	var hovered_text = ""

	match trigger_mode:
		TriggerMode.CONTINUOUS:
			mode_text = FuseLocalization.translate("FUSE_EVENT_MOUSE_MOVE_CONTINUOUS")
		TriggerMode.ON_THRESHOLD:
			mode_text = FuseLocalization.translate("FUSE_EVENT_MOUSE_MOVE_THRESHOLD")
			threshold_text = " [%s]" % FuseLocalization.translate_format("FUSE_EVENT_MOUSE_MOVE_THRESHOLD_VALUE", {
				"value": str(move_threshold)
			})

	if require_hovered:
		hovered_text = " [%s]" % FuseLocalization.translate("FUSE_EVENT_MOUSE_MOVE_NEED_HOVER")

	resource_name = FuseLocalization.translate_format("FUSE_EVENT_MOUSE_MOVE_RESOURCE_NAME", {
		"mode": mode_text,
		"threshold": threshold_text
	}) + hovered_text

## 初始化事件监听（必需）
func initialize(owner_node: Node) -> void:
	# 验证 owner_node
	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	_owner_node_ref = owner_node

	# 获取目标节点（用于悬停检测）
	if not target_node_path.is_empty():
		_target_node_ref = owner_node.get_node_or_null(target_node_path)
		if not _target_node_ref:
			_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(target_node_path)})
			return
	else:
		_target_node_ref = owner_node

	# 设置输入处理
	if not owner_node.tree_entered.is_connected(_on_tree_entered):
		owner_node.tree_entered.connect(_on_tree_entered)

	if owner_node.is_inside_tree():
		_setup_input_processing()

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 使用 RuntimeInstance 初始化事件
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		return

	_runtime_instance_ref = runtime_instance

	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	_owner_node_ref = owner_node

	# 获取目标节点（用于悬停检测）
	if not target_node_path.is_empty():
		_target_node_ref = owner_node.get_node_or_null(target_node_path)
		if not _target_node_ref:
			_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(target_node_path)})
			return
	else:
		_target_node_ref = owner_node

	# 设置输入处理
	if not owner_node.tree_entered.is_connected(_on_tree_entered):
		owner_node.tree_entered.connect(_on_tree_entered)

	if owner_node.is_inside_tree():
		_setup_input_processing()

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 设置输入处理
func _setup_input_processing():
	if not _owner_node_ref:
		return
	_owner_node_ref.set_process_input(true)

## 节点进入场景树回调
func _on_tree_entered():
	_setup_input_processing()

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	# 断开 tree_entered 信号
	if owner_node and owner_node.tree_entered.is_connected(_on_tree_entered):
		owner_node.tree_entered.disconnect(_on_tree_entered)

	# 清理 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("last_mouse_position", Vector2.INF)
		_runtime_instance_ref.set_runtime_state("accumulated_distance", 0.0)
		_runtime_instance_ref = null

	# 清理引用
	_target_node_ref = null
	_owner_node_ref = null

	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 处理输入事件（由 Trigger._unhandled_input 转发——Resource 的 _input 回调引擎不调用）
func handle_input(event: InputEvent):
	# 只处理鼠标移动事件
	if not event is InputEventMouseMotion:
		return

	var mouse_event = event as InputEventMouseMotion

	# 检查是否需要悬停
	if require_hovered and not _is_hovered():
		return

	# 获取当前鼠标位置
	var current_position = mouse_event.position
	var relative_motion = mouse_event.relative

	# 处理不同的触发模式
	match trigger_mode:
		TriggerMode.CONTINUOUS:
			# 持续触发：每次移动都触发
			_on_mouse_move_triggered(current_position, relative_motion, Vector2.ZERO)

		TriggerMode.ON_THRESHOLD:
			# 阈值触发：移动距离超过阈值时触发
			var last_mouse_position = _runtime_instance_ref.get_runtime_state("last_mouse_position")
			if last_mouse_position == null:
				last_mouse_position = Vector2.INF

			if last_mouse_position == Vector2.INF:
				_runtime_instance_ref.set_runtime_state("last_mouse_position", current_position)
				return

			var distance = current_position.distance_to(last_mouse_position)
			var accumulated_distance = _runtime_instance_ref.get_runtime_state("accumulated_distance")
			if accumulated_distance == null:
				accumulated_distance = 0.0
			accumulated_distance += distance
			_runtime_instance_ref.set_runtime_state("accumulated_distance", accumulated_distance)

			if accumulated_distance >= move_threshold:
				# 触发事件，传递累积距离
				var total_motion = current_position - last_mouse_position
				_on_mouse_move_triggered(current_position, relative_motion, total_motion)
				_runtime_instance_ref.set_runtime_state("last_mouse_position", current_position)
				_runtime_instance_ref.set_runtime_state("accumulated_distance", 0.0)

## 鼠标移动触发回调
func _on_mouse_move_triggered(position: Vector2, relative: Vector2, total_motion: Vector2):
	var position_text = " (%.0f, %.0f)" % [position.x, position.y]
	var motion_text = ""
	var threshold_text = ""

	# 模板已带"移动："前缀，此处只给数值（原实现自带前缀致双"移动："）
	if trigger_mode == TriggerMode.ON_THRESHOLD:
		motion_text = "%.1fpx" % total_motion.length()
	else:
		# CONTINUOUS 模式同样有单帧位移（relative）——不留空模板参数
		motion_text = "%.1fpx" % relative.length()

	_log_info_localized("FUSE_LOG_EVENT_MOUSE_MOVE_TRIGGERED", {
		"position": position_text,
		"motion": motion_text
	})

	# 创建上下文节点传递事件信息
	var context_node = Node.new()
	context_node.name = "MouseMoveContext"
	context_node.set_meta("position", position)
	context_node.set_meta("relative", relative)
	context_node.set_meta("total_motion", total_motion)
	context_node.set_meta("speed", relative.length())
	context_node.set_meta("trigger_mode", trigger_mode)

	triggered.emit(context_node)
	context_node.queue_free()

## 检查是否悬停在目标节点上
func _is_hovered() -> bool:
	if not _target_node_ref or not is_instance_valid(_target_node_ref):
		return false

	# 检查是否是 Control 节点
	if _target_node_ref is Control:
		var control = _target_node_ref as Control
		return control.is_hovered()

	# 对于非 Control 节点，使用简单的鼠标位置检测
	var viewport = _target_node_ref.get_viewport()
	if not viewport:
		return false

	var mouse_pos = viewport.get_mouse_position()

	# 如果是 CollisionObject2D，检测形状碰撞
	if _target_node_ref is CollisionObject2D:
		# 使用全局坐标转换
		var global_transform = _target_node_ref.get_global_transform()
		var local_mouse_pos = global_transform.affine_inverse() * mouse_pos

		# 简单检测：鼠标在节点附近
		var distance = global_transform.origin.distance_to(mouse_pos)
		return distance < 50.0

	return false

## 获取事件描述
func get_description() -> String:
	var mode_text = ""

	match trigger_mode:
		TriggerMode.CONTINUOUS:
			mode_text = FuseLocalization.translate("FUSE_EVENT_ON_MOUSE_MOVE_MODE_CONTINUOUS")
		TriggerMode.ON_THRESHOLD:
			mode_text = FuseLocalization.translate_format("FUSE_EVENT_ON_MOUSE_MOVE_MODE_THRESHOLD", {
				"value": str(move_threshold)
			})

	var hovered_text = ""
	if require_hovered:
		hovered_text = " " + FuseLocalization.translate("FUSE_EVENT_ON_MOUSE_MOVE_HOVERED")

	return FuseLocalization.translate_format("FUSE_EVENT_ON_MOUSE_MOVE_DESC", {
		"mode": mode_text,
		"hovered": hovered_text
	})

## 获取事件类型
func get_event_type() -> String:
	return "mouse_move"

## 获取事件分类
func get_event_category() -> String:
	return "input"

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	# 验证 trigger_mode 值
	if trigger_mode < 0 or trigger_mode >= TriggerMode.size():
		errors.append(FuseLocalization.translate("FUSE_ERROR_EVENT_INVALID_TRIGGER_MODE"))

	# 验证阈值参数
	if trigger_mode == TriggerMode.ON_THRESHOLD:
		if move_threshold <= 0:
			errors.append(FuseLocalization.translate("FUSE_ERROR_EVENT_MOVE_THRESHOLD_POSITIVE"))

		if move_threshold < 1.0:
			errors.append(FuseLocalization.translate("FUSE_WARNING_EVENT_MOVE_THRESHOLD_TOO_SMALL"))

	return errors

## 重置事件状态
func reset() -> void:
	super.reset()
	# 重置 RuntimeInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("last_mouse_position", Vector2.INF)
		_runtime_instance_ref.set_runtime_state("accumulated_distance", 0.0)
	_log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_ON_MOUSE_MOVE_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_INPUT"
	metadata.description_key = "FUSE_EVENT_ON_MOUSE_MOVE_DESC"
	metadata.keywords = ["mouse", "鼠标", "move", "移动", "motion", "运动", "input", "输入", "cursor", "光标"]
	metadata.builtin_icon = "InputEventMouseMotion"
	return metadata
