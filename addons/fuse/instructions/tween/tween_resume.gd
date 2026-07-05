@tool
@icon("res://addons/fuse/icons/builtin/Play.png")
extends BaseInstruction
class_name TweenResume

## Tween Resume 指令 - 恢复目标节点上所有被暂停的 Tween 动画
##
## 将 Tween 的 speed_scale 恢复为 1.0，或恢复节点的 process_mode。

## 目标节点路径（空=当前执行上下文的目标节点）
var target_node: NodePath = NodePath(""):
	set(value):
		target_node = value
		_update_resource_name()
		notify_property_list_changed()

## 获取指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_TWEEN_RESUME_NAME"
	metadata.category_key = "FUSE_CATEGORY_TWEEN"
	metadata.description_key = "FUSE_INSTRUCTION_TWEEN_RESUME_DESC"
	metadata.keywords = ["tween", "resume", "恢复", "动画", "播放", "continue", "play"]
	metadata.builtin_icon = "Play"
	return metadata

func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties := []

	properties.append({
		name = "Tween Resume",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "target_node",
		type = TYPE_NODE_PATH,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 更新资源名称
func _update_resource_name():
	var parts = []
	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_TWEEN_RESUME_NAME"))

	if not target_node.is_empty():
		parts.append("[%s]" % _get_node_display_name(target_node))
	else:
		parts.append("[%s]" % FuseLocalization.translate("FUSE_COMMON_CURRENT_NODE"))

	resource_name = " ".join(parts)

## 获取指令描述
func get_description() -> String:
	var target_desc = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_COMMON_CURRENT_NODE")
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_TWEEN_RESUME_DESC_FORMAT", {"target": target_desc})

## 执行指令
func execute(context: ExecutionContext) -> void:
	_start_execution(context)

	var node: Node
	if target_node.is_empty():
		node = context.target
	else:
		node = context.get_node(target_node)

	if node == null:
		_log_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(target_node)})
		set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"node": str(target_node)})
		finished.emit()
		return

	# 折中方案:恢复节点处理模式
	node.process_mode = Node.PROCESS_MODE_INHERIT
	_on_execution_completed()

## 验证参数
func validate() -> Array[String]:
	var errors = super.validate()
	return errors
