@tool
@icon("res://addons/fuse/icons/builtin/LineEdit.png")
extends BaseEvent
class_name OnFocus

## Event: OnFocus
##
## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - _is_monitoring: bool - 监控状态
##
## 架构版本: 自声明状态模式 v2.0
## 相关文档: addons/fuse/docs/migration-guide-to-runtime-instance.md
##
## 监听 Control 节点焦点进入/离开

## 目标 Control 节点路径
@export var target_node_path: NodePath = NodePath(""):
	set(value):
		target_node_path = value
		_update_resource_name()

## 监听模式
enum FocusMode {
	ON_ENTERED,     ## 仅焦点进入
	ON_EXITED,      ## 仅焦点离开
	ON_BOTH         ## 焦点进入和离开
}

@export var focus_mode: FocusMode = FocusMode.ON_BOTH:
	set(value):
		focus_mode = value
		_update_resource_name()

var _target_node: Control = null
var _owner_node_ref: Node = null

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["is_monitoring"] = false
	return base

## 更新资源名称（必需）
func _update_resource_name() -> void:
	var node_text: String
	if target_node_path.is_empty():
		node_text = FuseLocalization.translate("FUSE_EVENT_FOCUS_NOT_SPECIFIED")
	else:
		node_text = _get_node_display_name(target_node_path)

	var mode_text = ""
	match focus_mode:
		FocusMode.ON_ENTERED:
			mode_text = FuseLocalization.translate("FUSE_EVENT_FOCUS_MODE_ENTERED_ONLY")
		FocusMode.ON_EXITED:
			mode_text = FuseLocalization.translate("FUSE_EVENT_FOCUS_MODE_EXITED_ONLY")
		FocusMode.ON_BOTH:
			mode_text = FuseLocalization.translate("FUSE_EVENT_FOCUS_MODE_BOTH")

	resource_name = FuseLocalization.translate_format("FUSE_EVENT_FOCUS_RESOURCE_NAME", {
		"node": node_text,
		"mode": mode_text
	})

## 使用 RuntimeInstance 初始化（必需）
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		return

	_runtime_instance_ref = runtime_instance

	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	_owner_node_ref = owner_node

	# 获取目标节点
	if target_node_path.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	_target_node = owner_node.get_node_or_null(target_node_path) as Control

	if not _target_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 验证节点类型
	if not _target_node is Control:
		_create_fuse_error_localized("FUSE_ERROR_INVALID_TARGET", FuseError.ErrorType.CONFIGURATION_ERROR, {
			"node_path": str(target_node_path),
			"expected_types": "Control"
		})
		return

	# 连接焦点信号
	if not _target_node.focus_entered.is_connected(_on_focus_entered):
		_target_node.focus_entered.connect(_on_focus_entered)

	if not _target_node.focus_exited.is_connected(_on_focus_exited):
		_target_node.focus_exited.connect(_on_focus_exited)

	# 设置监控状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("is_monitoring", true)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 初始化事件监听（必需）- 保留向后兼容
func initialize(owner_node: Node) -> void:
	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	_owner_node_ref = owner_node

	# 获取目标节点
	if target_node_path.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	_target_node = owner_node.get_node_or_null(target_node_path) as Control

	if not _target_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 验证节点类型
	if not _target_node is Control:
		_create_fuse_error_localized("FUSE_ERROR_INVALID_TARGET", FuseError.ErrorType.CONFIGURATION_ERROR, {
			"node_path": str(target_node_path),
			"expected_types": "Control"
		})
		return

	# 连接焦点信号
	if not _target_node.focus_entered.is_connected(_on_focus_entered):
		_target_node.focus_entered.connect(_on_focus_entered)

	if not _target_node.focus_exited.is_connected(_on_focus_exited):
		_target_node.focus_exited.connect(_on_focus_exited)

	# 注意：旧版本 initialize() 不使用 RuntimeInstance，直接设置状态
	# 新版本应使用 initialize_with_runtime_instance()
	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 焦点进入
func _on_focus_entered() -> void:
	var is_monitoring = false
	if _runtime_instance_ref and _runtime_instance_ref.has_runtime_state("is_monitoring"):
		is_monitoring = _runtime_instance_ref.get_runtime_state("is_monitoring")

	if not is_monitoring:
		return

	if focus_mode == FocusMode.ON_EXITED:
		return

	_log_debug_localized("FUSE_LOG_EVENT_FOCUS_ENTERED", {})

	# triggered(context: Node) 信号签名——Dictionary 直传会触发转换错误，
	# 按惯例用上下文节点携带元数据（node/action）
	var context_node = Node.new()
	context_node.name = "FocusContext"
	context_node.set_meta("focus_node", _target_node)
	context_node.set_meta("action", "entered")
	triggered.emit(context_node)
	context_node.queue_free()

## 焦点离开
func _on_focus_exited() -> void:
	var is_monitoring = false
	if _runtime_instance_ref and _runtime_instance_ref.has_runtime_state("is_monitoring"):
		is_monitoring = _runtime_instance_ref.get_runtime_state("is_monitoring")

	if not is_monitoring:
		return

	if focus_mode == FocusMode.ON_ENTERED:
		return

	_log_debug_localized("FUSE_LOG_EVENT_FOCUS_EXITED", {})

	var exit_node = Node.new()
	exit_node.name = "FocusContext"
	exit_node.set_meta("focus_node", _target_node)
	exit_node.set_meta("action", "exited")
	triggered.emit(exit_node)
	exit_node.queue_free()

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	# 清理 RuntimeEventInstance 状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("is_monitoring", false)

	if _target_node and is_instance_valid(_target_node):
		if _target_node.focus_entered.is_connected(_on_focus_entered):
			_target_node.focus_entered.disconnect(_on_focus_entered)
		if _target_node.focus_exited.is_connected(_on_focus_exited):
			_target_node.focus_exited.disconnect(_on_focus_exited)

	_target_node = null
	_owner_node_ref = null

	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 获取事件描述
func get_description() -> String:
	var mode_text = ""
	match focus_mode:
		FocusMode.ON_ENTERED:
			mode_text = FuseLocalization.translate("FUSE_EVENT_FOCUS_DESC_ENTERED_ONLY")
		FocusMode.ON_EXITED:
			mode_text = FuseLocalization.translate("FUSE_EVENT_FOCUS_DESC_EXITED_ONLY")
		FocusMode.ON_BOTH:
			mode_text = FuseLocalization.translate("FUSE_EVENT_FOCUS_DESC_BOTH")

	return FuseLocalization.translate("FUSE_EVENT_ON_FOCUS_NAME") + ": " + mode_text

## 获取事件类型
func get_event_type() -> String:
	return "focus"

## 获取事件分类
func get_event_category() -> String:
	return "ui"

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	if target_node_path.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))

	return errors

## 重置事件状态
func reset() -> void:
	super.reset()
	# 焦点事件不需要重置状态
	_log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_ON_FOCUS_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_UI"
	metadata.description_key = "FUSE_EVENT_ON_FOCUS_DESC"
	metadata.keywords = ["focus", "焦点", "ui", "keyboard", "键盘", "navigation", "导航", "tab", "tabulation"]
	metadata.builtin_icon = "LineEdit"
	return metadata
