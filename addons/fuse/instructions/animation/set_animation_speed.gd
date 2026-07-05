@tool
@icon("res://addons/fuse/icons/builtin/ViewportSpeed.png")
extends BaseInstruction
class_name SetAnimationSpeed

## 设置 AnimationPlayer 的播放速度

# 目标 AnimationPlayer 节点路径
var target_node: NodePath = NodePath("")

# 播放速度（1.0 = 正常，0.5 = 半速，2.0 = 双倍速）
var speed_scale: float = 1.0

## 获取指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_SET_ANIMATION_SPEED_NAME"
	metadata.category_key = "FUSE_CATEGORY_ANIMATION"
	metadata.description_key = "FUSE_INSTRUCTION_SET_ANIMATION_SPEED_DESC"
	metadata.keywords = ["animation", "speed", "scale", "AnimationPlayer", "动画", "速度", "播放速度"]
	metadata.builtin_icon = "ViewportSpeed"
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
		name = "Speed",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "speed_scale",
		type = TYPE_FLOAT,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "0.01,10,0.01,or_greater",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 更新资源名称
func _update_resource_name():
	var parts := []

	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_SET_ANIMATION_SPEED_SHORT"))

	if not target_node.is_empty():
		parts.append("→ %s" % _get_node_display_name(target_node))
	else:
		parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_SET_ANIMATION_SPEED_NO_TARGET"))

	parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_ANIMATION_SPEED_VALUE", {"speed": speed_scale}))

	resource_name = " ".join(parts)

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	# 验证速度值
	if speed_scale <= 0:
		_log_error_localized("FUSE_ERROR_SPEED_MUST_BE_POSITIVE", {})
		set_error_localized("FUSE_ERROR_SPEED_MUST_BE_POSITIVE", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

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

	# 设置播放速度
	anim_player.speed_scale = speed_scale
	_log_info_localized("FUSE_LOG_SET_ANIMATION_SPEED", {"node": anim_player.name, "speed": str(speed_scale)})

	_on_execution_completed()

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()

	if target_node.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))

	if speed_scale <= 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_SPEED_MUST_BE_POSITIVE"))

	return errors

## 获取指令描述
func get_description() -> String:
	var target_str = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_INSTRUCTION_SET_ANIMATION_SPEED_NO_TARGET")
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_ANIMATION_SPEED_DESC_FORMAT", {"target": target_str, "speed": speed_scale})
