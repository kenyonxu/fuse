@tool
@icon("res://addons/fuse/icons/builtin/Viewport.png")
extends BaseEvent
class_name OnScreenEnteredExited

## Event: OnScreenEnteredExited
##
## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - _was_on_screen: bool - 上次是否在屏幕上
##
## 架构版本: 自声明状态模式 v2.0
## 相关文档: addons/fuse/docs/migration-guide-to-runtime-instance.md

## 屏幕进入/离开事件
##
## 节点进入或离开摄像机视野时触发。使用 Timer 定期检查 is_on_screen() 方法

# =============================================
# 参数定义
# =============================================

## 目标节点路径
@export var target_node: NodePath = NodePath(""):
	set(value):
		target_node = value
		_update_resource_name()

## 相机节点路径（空 = 使用默认相机）
@export var camera: NodePath = NodePath("")

## 触发时机
enum TriggerOn {
	ENTER = 0,  # 进入时触发
	EXIT = 1,   # 离开时触发
	BOTH = 2    # 进入和离开都触发
}

@export var trigger_on: TriggerOn = TriggerOn.BOTH:
	set(value):
		trigger_on = value
		_update_resource_name()

## 边缘余量（像素）
@export var margin: float = 0.0

## 检查间隔（秒）
@export var check_interval: float = 0.1

# 运行时状态
var _target_node_ref: Node = null
var _camera_ref: Camera2D = null
var _timer: Timer = null
var _owner_node_ref: Node = null

# =============================================
# 元数据方法
# =============================================

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["was_on_screen"] = false
	return base

## 获取事件元数据（必需）
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_ON_SCREEN_ENTERED_EXITED_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_PHYSICS"
	metadata.description_key = "FUSE_EVENT_ON_SCREEN_ENTERED_EXITED_DESC"
	metadata.keywords = ["screen", "屏幕", "viewport", "视野", "camera", "相机", "visible", "可见", "entered", "进入", "exited", "离开", "on screen"]
	metadata.builtin_icon = "Viewport"
	return metadata

# =============================================
# 资源名称和描述
# =============================================

## 更新资源名称（必需）
func _update_resource_name():
	var trigger_key = ""
	match trigger_on:
		TriggerOn.ENTER:
			trigger_key = "FUSE_EVENT_ON_SCREEN_ENTERED_EXITED_TRIGGER_ENTER"
		TriggerOn.EXIT:
			trigger_key = "FUSE_EVENT_ON_SCREEN_ENTERED_EXITED_TRIGGER_EXIT"
		TriggerOn.BOTH:
			trigger_key = "FUSE_EVENT_ON_SCREEN_ENTERED_EXITED_TRIGGER_BOTH"

	var trigger_text = FuseLocalization.translate(trigger_key)

	resource_name = FuseLocalization.translate_format("FUSE_EVENT_ON_SCREEN_ENTERED_EXITED_RESOURCE_NAME", {
		"target": _get_node_display_name(target_node),
		"trigger": trigger_text
	})

## 获取事件描述
func get_description() -> String:
	var target_name = target_node if not target_node.is_empty() else FuseLocalization.translate("FUSE_EVENT_ON_SCREEN_ENTERED_EXITED_NOT_SPECIFIED")
	var margin_text = "" if margin == 0 else FuseLocalization.translate_format("FUSE_EVENT_ON_SCREEN_ENTERED_EXITED_MARGIN", {"margin": str(margin)})
	var interval_text = FuseLocalization.translate_format("FUSE_EVENT_ON_SCREEN_ENTERED_EXITED_INTERVAL", {"interval": str(check_interval)})

	var trigger_key = ""
	match trigger_on:
		TriggerOn.ENTER:
			trigger_key = "FUSE_EVENT_ON_SCREEN_ENTERED_EXITED_DESC_ENTER"
		TriggerOn.EXIT:
			trigger_key = "FUSE_EVENT_ON_SCREEN_ENTERED_EXITED_DESC_EXIT"
		TriggerOn.BOTH:
			trigger_key = "FUSE_EVENT_ON_SCREEN_ENTERED_EXITED_DESC_BOTH"

	var trigger_desc = FuseLocalization.translate(trigger_key)

	return FuseLocalization.translate_format("FUSE_EVENT_ON_SCREEN_ENTERED_EXITED_DESC", {
		"target": target_name,
		"margin": margin_text,
		"interval": interval_text,
		"trigger": trigger_desc
	})

## 获取事件类型
func get_event_type() -> String:
	return "screen_entered_exited"

## 获取事件分类
func get_event_category() -> String:
	return "physics"

# =============================================
# 生命周期方法
# =============================================

## 使用 RuntimeInstance 初始化事件
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		return

	_runtime_instance_ref = runtime_instance

	# ============================================
	# 1. 验证 owner_node
	# ============================================

	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# ============================================
	# 2. 验证目标节点
	# ============================================

	if target_node.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	_target_node_ref = owner_node.get_node_or_null(target_node)
	if not _target_node_ref:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(target_node)})
		return

	# 验证节点类型（需要支持 is_on_screen 方法）
	if not (_target_node_ref is Node2D or _target_node_ref is Control):
		_create_fuse_error_localized("FUSE_ERROR_INVALID_TARGET", FuseError.ErrorType.CONFIGURATION_ERROR, {
			"node_path": str(target_node),
			"expected": "Node2D or Control"
		})
		return

	# ============================================
	# 3. 获取相机
	# ============================================

	if not camera.is_empty():
		_camera_ref = owner_node.get_node_or_null(camera) as Camera2D
		if not _camera_ref:
			_create_fuse_error_localized("FUSE_ERROR_CAMERA_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(camera)})
			return

	# ============================================
	# 4. 初始化屏幕状态
	# ============================================

	var was_on_screen = _check_is_on_screen()
	_runtime_instance_ref.set_runtime_state("was_on_screen", was_on_screen)

	# ============================================
	# 5. 创建定时器
	# ============================================

	_owner_node_ref = owner_node

	if owner_node.is_inside_tree():
		_start_timer()
	else:
		# 等待进入场景树后再启动
		owner_node.tree_entered.connect(_on_tree_entered)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 初始化事件监听（必需）- 向后兼容
func initialize(owner_node: Node) -> void:
	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

	# ============================================
	# 1. 验证 owner_node
	# ============================================

	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# ============================================
	# 2. 验证目标节点
	# ============================================

	if target_node.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	_target_node_ref = owner_node.get_node_or_null(target_node)
	if not _target_node_ref:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(target_node)})
		return

	# 验证节点类型（需要支持 is_on_screen 方法）
	if not (_target_node_ref is Node2D or _target_node_ref is Control):
		_create_fuse_error_localized("FUSE_ERROR_INVALID_TARGET", FuseError.ErrorType.CONFIGURATION_ERROR, {
			"node_path": str(target_node),
			"expected": "Node2D or Control"
		})
		return

	# ============================================
	# 3. 获取相机
	# ============================================

	if not camera.is_empty():
		_camera_ref = owner_node.get_node_or_null(camera) as Camera2D
		if not _camera_ref:
			_create_fuse_error_localized("FUSE_ERROR_CAMERA_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(camera)})
			return

	# ============================================
	# 4. 初始化屏幕状态（使用临时变量）
	# ============================================

	var _was_on_screen = _check_is_on_screen()

	# ============================================
	# 5. 创建定时器
	# ============================================

	_owner_node_ref = owner_node

	if owner_node.is_inside_tree():
		_start_timer()
	else:
		# 等待进入场景树后再启动
		owner_node.tree_entered.connect(_on_tree_entered)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	# 断开 tree_entered 连接
	if owner_node and owner_node.tree_entered.is_connected(_on_tree_entered):
		owner_node.tree_entered.disconnect(_on_tree_entered)

	# 清理定时器
	_cleanup_timer()

	# 清理 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("was_on_screen", false)

	# 清理引用
	_target_node_ref = null
	_camera_ref = null
	_owner_node_ref = null
	_runtime_instance_ref = null

	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

# =============================================
# 定时器管理
# =============================================

## 开始定时器
func _start_timer() -> void:
	if not _owner_node_ref:
		return

	_cleanup_timer()

	# 验证检查间隔
	if check_interval <= 0:
		_create_fuse_error_localized("FUSE_ERROR_CHECK_INTERVAL_INVALID", FuseError.ErrorType.CONFIGURATION_ERROR, {"interval": check_interval})
		return

	_timer = Timer.new()
	_timer.wait_time = check_interval
	_timer.one_shot = false
	_timer.timeout.connect(_on_timer_timeout)
	_timer.autostart = true
	_owner_node_ref.add_child(_timer)

	_log_debug_localized("FUSE_LOG_EVENT_SCREEN_CHECK_STARTED", {"interval": check_interval})

## 清理定时器
func _cleanup_timer() -> void:
	if _timer:
		_timer.stop()

		if _timer.timeout.is_connected(_on_timer_timeout):
			_timer.timeout.disconnect(_on_timer_timeout)

		if _owner_node_ref and is_instance_valid(_owner_node_ref):
			_owner_node_ref.remove_child(_timer)

		_timer.queue_free()
		_timer = null

## 当节点进入场景树时
func _on_tree_entered() -> void:
	_start_timer()

## 定时器超时回调
func _on_timer_timeout() -> void:
	# 检查当前屏幕状态
	var is_on_screen: bool = _check_is_on_screen()

	# 从 RuntimeInstance 获取之前的状态
	var was_on_screen: bool = false
	if _runtime_instance_ref and _runtime_instance_ref.has_runtime_state("was_on_screen"):
		was_on_screen = _runtime_instance_ref.get_runtime_state("was_on_screen")

	# 检测状态变化
	if is_on_screen != was_on_screen:
		# 根据触发时机决定是否触发
		var should_trigger = false

		if is_on_screen and (trigger_on == TriggerOn.ENTER or trigger_on == TriggerOn.BOTH):
			# 进入屏幕
			should_trigger = true
			_log_info_localized("FUSE_LOG_EVENT_SCREEN_ENTERED", {
				"node": _target_node_ref.name if _target_node_ref else "Unknown"
			})

		elif not is_on_screen and (trigger_on == TriggerOn.EXIT or trigger_on == TriggerOn.BOTH):
			# 离开屏幕
			should_trigger = true
			_log_info_localized("FUSE_LOG_EVENT_SCREEN_EXITED", {
				"node": _target_node_ref.name if _target_node_ref else "Unknown"
			})

		if should_trigger:
			# 创建上下文节点传递事件信息
			var context_node = Node.new()
			context_node.name = "ScreenEventContext"

			if _target_node_ref:
				context_node.set_meta("target_node", _target_node_ref)

			context_node.set_meta("is_on_screen", is_on_screen)
			context_node.set_meta("was_on_screen", was_on_screen)
			context_node.set_meta("event_type", "entered" if is_on_screen else "exited")

			_emit_triggered(context_node, _owner_node_ref)

			# 清理上下文节点
			context_node.queue_free()

		# 更新 RuntimeInstance 的状态
		if _runtime_instance_ref:
			_runtime_instance_ref.set_runtime_state("was_on_screen", is_on_screen)

# =============================================
# 辅助方法
# =============================================

## 检查节点是否在屏幕上
func _check_is_on_screen() -> bool:
	if not _target_node_ref or not is_instance_valid(_target_node_ref):
		return false

	# 节点类型已在 initialize() 中验证为 Node2D 或 Control
	# 这两种类型都有 is_on_screen() 方法
	if margin == 0 or not _camera_ref:
		return _target_node_ref.is_on_screen()
	else:
		# 如果有相机和余量，需要手动检查
		return _check_is_on_screen_with_margin()

## 带余量检查屏幕可见性
func _check_is_on_screen_with_margin() -> bool:
	if not _target_node_ref or not _camera_ref:
		return false

	# 获取节点位置
	var node_pos: Vector2
	if _target_node_ref is Node2D:
		node_pos = _target_node_ref.global_position
	elif _target_node_ref is Control:
		node_pos = _target_node_ref.global_position

	# 转换到屏幕空间
	var screen_pos = _camera_ref.get_screen_center_position()
	var viewport_size = _target_node_ref.get_viewport().get_visible_rect().size
	var viewport_rect = Rect2(screen_pos - viewport_size / 2, viewport_size)

	# 应用余量
	var check_rect = viewport_rect.grow(margin)

	# 检查是否在矩形内
	return check_rect.has_point(node_pos)

# =============================================
# 验证和重置
# =============================================

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	if target_node.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))

	if check_interval <= 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_CHECK_INTERVAL_INVALID"))

	return errors

## 重置事件状态
func reset() -> void:
	super.reset()

	if _timer:
		_timer.stop()

	if _runtime_instance_ref and _target_node_ref and is_instance_valid(_target_node_ref):
		var was_on_screen = _check_is_on_screen()
		_runtime_instance_ref.set_runtime_state("was_on_screen", was_on_screen)

	_log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})
