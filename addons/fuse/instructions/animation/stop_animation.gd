@tool
@icon("res://addons/fuse/icons/builtin/Stop.png")
extends BaseInstruction
class_name StopAnimation

## 停止 AnimationPlayer 的动画播放

# 目标 AnimationPlayer 节点路径
var target_node: NodePath = NodePath("")

# 是否保持当前动画位置
var keep_position: bool = true

## 获取指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_STOP_ANIMATION_NAME"
	metadata.category_key = "FUSE_CATEGORY_ANIMATION"
	metadata.description_key = "FUSE_INSTRUCTION_STOP_ANIMATION_DESC"
	metadata.keywords = ["stop", "animation", "AnimationPlayer", "pause", "停止", "动画", "暂停"]
	metadata.builtin_icon = "Stop"
	return metadata

func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties := []

	properties.append({
		name = "Animation",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "target_node",
		type = TYPE_NODE_PATH,
		hint = PROPERTY_HINT_NODE_PATH_VALID_TYPES,
		hint_string = "AnimationPlayer",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "Options",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "keep_position",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 更新资源名称
func _update_resource_name():
	var parts := []

	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_STOP_ANIMATION_SHORT"))

	if not target_node.is_empty():
		parts.append("→ %s" % _get_node_display_name(target_node))
	else:
		parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_STOP_ANIMATION_NO_TARGET"))

	if keep_position:
		parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_STOP_ANIMATION_KEEP_POSITION"))

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

	# 验证节点类型
	if not node is AnimationPlayer:
		_log_error_localized("FUSE_ERROR_NOT_ANIMATION_PLAYER", {})
		set_error_localized("FUSE_ERROR_NOT_ANIMATION_PLAYER", FuseError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	var anim_player := node as AnimationPlayer

	# 停止动画
	if keep_position:
		anim_player.pause()  # 暂停但保持位置
		_log_info_localized("FUSE_LOG_PAUSE_ANIMATION", {"name": anim_player.name})
	else:
		anim_player.stop()  # 停止并重置
		_log_info_localized("FUSE_LOG_STOP_ANIMATION", {"name": anim_player.name})

	_on_execution_completed()

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()

	if target_node.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))

	return errors

## 获取指令描述
func get_description() -> String:
	var action_key = "FUSE_INSTRUCTION_STOP_ANIMATION_PAUSE" if keep_position else "FUSE_INSTRUCTION_STOP_ANIMATION_STOP"
	var action_str = FuseLocalization.translate(action_key)
	var target_str = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_INSTRUCTION_STOP_ANIMATION_NO_TARGET")
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_STOP_ANIMATION_DESC_FORMAT", {"action": action_str, "target": target_str})
