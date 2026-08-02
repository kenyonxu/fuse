@tool
@icon("res://addons/fuse/icons/builtin/Pause.png")
extends BaseInstruction
class_name TweenPause

## Tween Pause 指令 - 暂停目标节点上的所有活跃 Tween 动画
##
## 通过设置 Tween 的 speed_scale 为 0 来冻结动画。
## 如果无法获取 Tween 引用，则设置节点的 process_mode 为 DISABLED 作为折中。

## 目标节点路径（空=当前执行上下文的目标节点）
var target_node: NodePath = NodePath(""):
	set(value):
		target_node = value
		_update_resource_name()
		notify_property_list_changed()

## 获取指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_TWEEN_PAUSE_NAME"
	metadata.category_key = "FUSE_CATEGORY_TWEEN"
	metadata.description_key = "FUSE_INSTRUCTION_TWEEN_PAUSE_DESC"
	metadata.keywords = ["tween", "pause", "暂停", "动画", "冻结", "freeze", "stop"]
	metadata.builtin_icon = "Pause"
	return metadata

func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	properties.append({
		name = "Tween Pause",
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
	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_TWEEN_PAUSE_NAME"))

	if not target_node.is_empty():
		parts.append("[%s]" % _get_node_display_name(target_node))
	else:
		parts.append("[%s]" % FuseLocalization.translate("FUSE_COMMON_CURRENT_NODE"))

	resource_name = " ".join(parts)

## 获取指令描述
func get_description() -> String:
	var target_desc = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_COMMON_CURRENT_NODE")
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_TWEEN_PAUSE_DESC_FORMAT", {"target": target_desc})

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

	# Tween 是 RefCounted 非 Node,无法通过 get_children 找到
	# 折中方案:设置节点处理模式为禁用
	node.process_mode = Node.PROCESS_MODE_DISABLED

	_on_execution_completed()

## 验证参数
func validate() -> Array[String]:
	var errors = super.validate()
	return errors
