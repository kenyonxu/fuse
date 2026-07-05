@tool
@icon("res://addons/fuse/icons/builtin/TouchScreenButton.png")
extends BaseEvent
class_name OnTouch

## Event: OnTouch
##
## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - 无运行时状态（纯输入事件处理，状态由触摸事件本身携带）
##
## 架构版本: 自声明状态模式 v2.0
## 相关文档: addons/fuse/docs/migration-guide-to-runtime-instance.md

## 监听触摸屏输入事件

## 触摸索引（-1 = 所有索引）
@export_range(-1, 9) var touch_index: int = -1:
	set(value):
		touch_index = value
		_update_resource_name()

## 监听动作
enum TouchAction {
	ON_PRESSED,     ## 仅按下
	ON_RELEASED,    ## 仅释放
	ON_BOTH         ## 按下和释放
}

@export var touch_action: TouchAction = TouchAction.ON_BOTH:
	set(value):
		touch_action = value
		_update_resource_name()

# RuntimeInstance 引用已在 BaseEvent 中定义

## 更新资源名称（必需）
func _update_resource_name() -> void:
	var index_key = "FUSE_DESC_TOUCH_INDEX_N" if touch_index >= 0 else "FUSE_DESC_TOUCH_ANY_INDEX"
	var index_text = FuseLocalization.translate_format(index_key, {"index": str(touch_index)}) if touch_index >= 0 else FuseLocalization.translate(index_key)

	var action_key = ""
	match touch_action:
		TouchAction.ON_PRESSED:
			action_key = "FUSE_DESC_TOUCH_ON_PRESSED"
		TouchAction.ON_RELEASED:
			action_key = "FUSE_DESC_TOUCH_ON_RELEASED"
		TouchAction.ON_BOTH:
			action_key = "FUSE_DESC_TOUCH_ON_BOTH"

	var action_text = FuseLocalization.translate(action_key)

	resource_name = FuseLocalization.translate_format("FUSE_EVENT_ON_TOUCH_RESOURCE_NAME", {
		"index": index_text,
		"action": action_text
	})

## 使用运行时实例初始化事件
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		return

	_runtime_instance_ref = runtime_instance

	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	if not owner_node.tree_entered.is_connected(_on_tree_entered):
		owner_node.tree_entered.connect(_on_tree_entered)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 初始化事件监听（必需）- 向后兼容
func initialize(owner_node: Node) -> void:
	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	if not owner_node.tree_entered.is_connected(_on_tree_entered):
		owner_node.tree_entered.connect(_on_tree_entered)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 当节点进入场景树
## 输入事件由 Trigger 通过 handle_input() 处理，无需额外监听
func _on_tree_entered() -> void:
	pass

## 输入处理（使用 BaseEvent 定义的接口）
func handle_input(event: InputEvent) -> void:
	if not event is InputEventScreenTouch:
		return

	var touch_event = event as InputEventScreenTouch

	# 检查触摸索引
	if touch_index >= 0 and touch_event.index != touch_index:
		return

	# 检查动作类型
	var should_trigger = false
	if touch_event.pressed:
		should_trigger = touch_action == TouchAction.ON_PRESSED or touch_action == TouchAction.ON_BOTH
	else:
		should_trigger = touch_action == TouchAction.ON_RELEASED or touch_action == TouchAction.ON_BOTH

	if should_trigger:
		_trigger_event(touch_event)

## 触发事件
func _trigger_event(touch_event: InputEventScreenTouch) -> void:
	var action_text = ""
	if touch_event.pressed:
		action_text = FuseLocalization.translate("FUSE_TEXT_TOUCH_PRESSED")
	else:
		action_text = FuseLocalization.translate("FUSE_TEXT_TOUCH_RELEASED")

	_log_debug_localized("FUSE_LOG_EVENT_TOUCH_TRIGGERED", {
		"position": str(touch_event.position),
		"index": str(touch_event.index),
		"action": action_text
	})

	# 创建上下文节点传递事件信息
	var context_node = Node.new()
	context_node.name = "TouchContext"
	context_node.set_meta("position", touch_event.position)
	context_node.set_meta("index", touch_event.index)
	context_node.set_meta("pressed", touch_event.pressed)
	context_node.set_meta("double_tap", touch_event.double_tap)

	triggered.emit(context_node)

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	if owner_node and is_instance_valid(owner_node):
		if owner_node.tree_entered.is_connected(_on_tree_entered):
			owner_node.tree_entered.disconnect(_on_tree_entered)

	# 清理 RuntimeEventInstance 引用
	_runtime_instance_ref = null

	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 获取事件描述
func get_description() -> String:
	var index_text = ""
	if touch_index >= 0:
		index_text = FuseLocalization.translate_format("FUSE_EVENT_TOUCH_DESC_INDEX_N", {"index": str(touch_index)})
	else:
		index_text = FuseLocalization.translate("FUSE_EVENT_TOUCH_DESC_ANY_INDEX")

	var action_text = ""
	match touch_action:
		TouchAction.ON_PRESSED:
			action_text = FuseLocalization.translate("FUSE_EVENT_TOUCH_DESC_ON_PRESSED")
		TouchAction.ON_RELEASED:
			action_text = FuseLocalization.translate("FUSE_EVENT_TOUCH_DESC_ON_RELEASED")
		TouchAction.ON_BOTH:
			action_text = FuseLocalization.translate("FUSE_EVENT_TOUCH_DESC_ON_BOTH")

	return FuseLocalization.translate_format("FUSE_EVENT_TOUCH_DESC_MONITOR_FORMAT", {
		"index": index_text,
		"action": action_text
	})

## 获取事件类型
func get_event_type() -> String:
	return "touch"

## 获取事件分类
func get_event_category() -> String:
	return "input"

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	if touch_index < -1 or touch_index > 9:
		errors.append(FuseLocalization.translate("FUSE_ERROR_TOUCH_INDEX_INVALID"))

	return errors

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_ON_TOUCH_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_INPUT"
	metadata.description_key = "FUSE_EVENT_ON_TOUCH_DESC"
	metadata.keywords = ["touch", "触摸", "screen", "屏幕", "mobile", "移动", "finger", "手指", "tap", "点击"]
	metadata.builtin_icon = "TouchScreenButton"
	return metadata
