@tool
@icon("res://addons/fuse/icons/builtin/Button.png")
extends BaseEvent
class_name OnButtonPressed

## Event: OnButtonPressed
##
## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - 无（此事件是纯信号转发，无需额外状态变量）
##
## 架构版本: 自声明状态模式 v2.0
## 相关文档: addons/fuse/docs/zh_CN/dev_docs/guides/runtime-instance-migration-guide.md
##
## UI 按钮按下事件
##
## 当 Button 节点被按下时触发。

## 目标 Button 节点路径
@export var target_button: NodePath = NodePath(""):
	set(value):
		target_button = value
		_update_resource_name()

## 是否要求按钮可用（非禁用状态）
@export var require_enabled: bool = true:
	set(value):
		require_enabled = value
		_update_resource_name()

## 是否传递按钮节点
@export var emit_button: bool = true

var _button_ref: Button = null

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	# 此事件是纯信号转发，无需额外状态变量
	return base

## 更新资源名称（必需）
func _update_resource_name():
	var enabled_text = ""
	if require_enabled:
		enabled_text = FuseLocalization.translate("FUSE_DESC_REQUIRE_ENABLED")
	resource_name = FuseLocalization.translate_format("FUSE_EVENT_ON_BUTTON_PRESSED_RESOURCE_NAME", {
		"button": str(target_button),
		"enabled": enabled_text
	})

## 使用 RuntimeInstance 初始化（必需）
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		return

	_runtime_instance_ref = runtime_instance

	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 🔧 保存 Trigger 引用，用于 _emit_triggered
	set_trigger_ref(owner_node)

	# 验证目标节点路径
	if target_button.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 获取目标节点
	_button_ref = owner_node.get_node_or_null(target_button)
	if not _button_ref:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(target_button)})
		return

	# 验证节点类型
	if not _button_ref is Button:
		_create_fuse_error_localized("FUSE_ERROR_INVALID_TARGET", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(target_button)})
		return

	# 连接信号
	if not _button_ref.pressed.is_connected(_on_button_pressed):
		_button_ref.pressed.connect(_on_button_pressed)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 初始化事件监听（必需）- 保留向后兼容
func initialize(owner_node: Node) -> void:
	# 验证 owner_node
	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 验证目标节点路径
	if target_button.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 获取目标节点
	_button_ref = owner_node.get_node_or_null(target_button)
	if not _button_ref:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(target_button)})
		return

	# 验证节点类型
	if not _button_ref is Button:
		_create_fuse_error_localized("FUSE_ERROR_INVALID_TARGET", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(target_button)})
		return

	# 连接信号
	if not _button_ref.pressed.is_connected(_on_button_pressed):
		_button_ref.pressed.connect(_on_button_pressed)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	# 清理 RuntimeEventInstance 状态
	if _runtime_instance_ref:
		pass  # 此事件无需额外状态清理

	# 断开信号连接
	if _button_ref and is_instance_valid(_button_ref):
		if _button_ref.pressed.is_connected(_on_button_pressed):
			_button_ref.pressed.disconnect(_on_button_pressed)

	# 清理引用
	_button_ref = null

	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 按钮按下回调
func _on_button_pressed():
	# 检查是否要求按钮可用
	if require_enabled and _button_ref.disabled:
		_log_debug_localized("FUSE_LOG_EVENT_BUTTON_DISABLED", {"button": _button_ref.name})
		return

	_log_info_localized("FUSE_LOG_EVENT_BUTTON_PRESSED", {"button": _button_ref.name})

	# 传递按钮节点（如果需要）
	if emit_button:
		_emit_triggered(_button_ref)
	else:
		triggered.emit(null)

## 获取事件描述
func get_description() -> String:
	var button_name = target_button if not target_button.is_empty() else FuseLocalization.translate("FUSE_TEXT_NOT_SPECIFIED")
	var enabled_text = ""
	if require_enabled:
		enabled_text = FuseLocalization.translate("FUSE_DESC_BUTTON_ENABLED")
	return FuseLocalization.translate_format("FUSE_EVENT_ON_BUTTON_PRESSED_DESC", {
		"button": button_name,
		"enabled": enabled_text
	})

## 获取事件类型
func get_event_type() -> String:
	return "button_pressed"

## 获取事件分类
func get_event_category() -> String:
	return "ui"

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	if target_button.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))

	return errors

## 重置事件状态
func reset() -> void:
	super.reset()
	_log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_ON_BUTTON_PRESSED_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_UI"
	metadata.description_key = "FUSE_EVENT_ON_BUTTON_PRESSED_DESC"
	metadata.keywords = ["button", "按钮", "press", "按下", "click", "点击", "ui", "interface", "interface"]
	metadata.builtin_icon = "Button"
	return metadata
