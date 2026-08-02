@tool
@icon("res://addons/fuse/icons/builtin/GuiVisibilityXray.png")
extends BaseInstruction
class_name ShowHideUI

## 控制 UI 节点的可见性

# 目标 UI 节点路径
var target_node: NodePath = NodePath(""):
	set(node):
		target_node = node
		_update_resource_name()


# 动作类型
enum Action {
	SHOW,
	HIDE,
	TOGGLE
}
var action: Action = Action.SHOW

## 获取指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_SHOW_HIDE_UI_NAME"
	metadata.category_key = "FUSE_CATEGORY_UI"
	metadata.description_key = "FUSE_INSTRUCTION_SHOW_HIDE_UI_DESC"
	metadata.keywords = ["ui", "show", "hide", "visible", "toggle", "UI", "显示", "隐藏", "可见"]
	metadata.builtin_icon = "GuiVisibilityXray"
	return metadata

func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	# UI 分类
	properties.append({
		name = "UI",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 目标节点
	properties.append({
		name = "target_node",
		type = TYPE_NODE_PATH,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 动作类型
	properties.append({
		name = "action",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Show,Hide,Toggle",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 更新资源名称
func _update_resource_name():
	var parts = []

	var action_key = ""
	match action:
		Action.SHOW:
			action_key = "FUSE_UI_ACTION_SHOW"
		Action.HIDE:
			action_key = "FUSE_UI_ACTION_HIDE"
		Action.TOGGLE:
			action_key = "FUSE_UI_ACTION_TOGGLE"

	var action_name = FuseLocalization.translate(action_key)

	parts.append("%s UI" % action_name)

	if not target_node.is_empty():
		parts.append("→ %s" % _get_node_display_name(target_node))
	else:
		parts.append("→ %s" % FuseLocalization.translate("FUSE_UI_NODE_NOT_SELECTED"))

	resource_name = " ".join(parts)

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	# 获取目标节点
	var node := context.get_node(target_node)
	if not node:
		_log_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(target_node)})
		set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"node": str(target_node)})
		finished.emit()
		return

	# 验证是否为 Control 节点
	if not node is Control:
		_log_error_localized("FUSE_ERROR_UI_NODE_NOT_CONTROL", {})
		set_error_localized("FUSE_ERROR_UI_NODE_NOT_CONTROL", FuseError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	var control := node as Control

	# 执行动作
	# 使用 show()/hide() 方法而不是直接设置 visible 属性
	# 这在 Godot 4.6 中可能更可靠

	match action:
		Action.SHOW:
			if not control.visible:
				control.show()
				_log_info_localized("FUSE_LOG_SHOW_UI_NODE", {"node": control.name})
		Action.HIDE:
			if control.visible:
				control.hide()
				_log_info_localized("FUSE_LOG_HIDE_UI_NODE", {"node": control.name})
		Action.TOGGLE:
			if control.visible:
				control.hide()
				_log_info_localized("FUSE_LOG_TOGGLE_UI_NODE", {"node": control.name, "state": FuseLocalization.translate("FUSE_UI_STATE_HIDDEN")})
			else:
				control.show()
				_log_info_localized("FUSE_LOG_TOGGLE_UI_NODE", {"node": control.name, "state": FuseLocalization.translate("FUSE_UI_STATE_VISIBLE")})

	_on_execution_completed()

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()

	if target_node.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))

	return errors

## 获取指令描述
func get_description() -> String:
	var action_key = ""
	match action:
		Action.SHOW:
			action_key = "FUSE_UI_ACTION_SHOW"
		Action.HIDE:
			action_key = "FUSE_UI_ACTION_HIDE"
		Action.TOGGLE:
			action_key = "FUSE_UI_ACTION_TOGGLE"

	var action_name = FuseLocalization.translate(action_key)
	var node_str = _get_node_display_name(target_node) if not target_node.is_empty() else "(%s)" % FuseLocalization.translate("FUSE_UI_NODE_NOT_SELECTED")
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_SHOW_HIDE_UI_DESC_FORMAT", {"action": action_name, "node": node_str})
