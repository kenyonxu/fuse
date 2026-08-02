@tool
@icon("res://addons/fuse/icons/builtin/AnimationPlayer.png")
extends BaseInstruction
class_name PlayAnimation

## 播放 AnimationPlayer 中的指定动画

# 目标 AnimationPlayer 节点路径
var target_player: NodePath = NodePath("")

# 动画名称
var animation_name: String = ""

# 播放速度
var speed: float = 1.0

# 是否从结尾开始反向播放
var from_end: bool = false

# 是否仅自动播放
var autoplay_only: bool = false

## 获取指令元数据（用于指令选择器）
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_PLAY_ANIMATION_NAME"
	metadata.category_key = "FUSE_CATEGORY_ANIMATION"
	metadata.description_key = "FUSE_INSTRUCTION_PLAY_ANIMATION_DESC"
	metadata.keywords = ["animation", "play", "animate", "播放", "动画"]
	metadata.builtin_icon = "AnimationPlayer"
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	# Animation 分类
	properties.append({
		name = "Animation",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 目标 AnimationPlayer
	properties.append({
		name = "target_player",
		type = TYPE_NODE_PATH,
		hint = PROPERTY_HINT_NODE_PATH_VALID_TYPES,
		hint_string = "AnimationPlayer",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 动画名称
	properties.append({
		name = "animation_name",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Playback 分类
	properties.append({
		name = "Playback",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 播放速度
	properties.append({
		name = "speed",
		type = TYPE_FLOAT,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "0.01,10,0.01,or_greater",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 是否从结尾开始反向播放
	properties.append({
		name = "from_end",
		type = TYPE_BOOL,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 是否仅自动播放
	properties.append({
		name = "autoplay_only",
		type = TYPE_BOOL,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 更新资源名称
func _update_resource_name():
	var parts = []

	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_PLAY_ANIMATION_SHORT"))

	if not target_player.is_empty():
		parts.append("'%s'" % target_player)
	else:
		parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_PLAY_ANIMATION_NO_PLAYER"))

	if not animation_name.is_empty():
		parts.append("'%s'" % animation_name)
	else:
		parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_PLAY_ANIMATION_NO_ANIMATION"))

	if speed != 1.0:
		parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_PLAY_ANIMATION_WITH_SPEED", {"speed": speed}))

	if from_end:
		parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_PLAY_ANIMATION_FROM_END"))

	if autoplay_only:
		parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_PLAY_ANIMATION_AUTOPLAY_ONLY"))

	resource_name = " ".join(parts)

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	# 验证目标节点
	if target_player.is_empty():
		_log_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", {})
		set_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 获取 AnimationPlayer 节点
	var node := context.get_node(target_player)
	if not node:
		_log_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(target_player)})
		set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"node": str(target_player)})
		finished.emit()
		return

	# 验证节点类型
	if not node is AnimationPlayer:
		var type_str = node.get_class()
		_log_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", {"node": node.name, "actual_type": type_str})
		set_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", FuseError.ErrorType.RUNTIME_ERROR, {"node": node.name, "actual_type": type_str})
		finished.emit()
		return

	var animation_player := node as AnimationPlayer

	# 验证动画名称
	if animation_name.is_empty():
		_log_error_localized("FUSE_ERROR_ANIMATION_NAME_EMPTY", {})
		set_error_localized("FUSE_ERROR_ANIMATION_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 验证动画是否存在
	if not animation_player.has_animation(animation_name):
		_log_error_localized("FUSE_ERROR_ANIMATION_NOT_FOUND", {"animation": animation_name})
		set_error_localized("FUSE_ERROR_ANIMATION_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"animation": animation_name})
		finished.emit()
		return

	# 验证速度值
	if speed <= 0.0:
		_log_error_localized("FUSE_ERROR_INVALID_SPEED", {})
		set_error_localized("FUSE_ERROR_INVALID_SPEED", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 播放动画
	if from_end:
		animation_player.play_backwards(animation_name, -1.0)
		_log_info("反向播放动画 '%s'，速度 %.2fx" % [animation_name, speed])
	else:
		animation_player.play(animation_name, -1.0, speed)
		_log_info("播放动画 '%s'，速度 %.2fx" % [animation_name, speed])

	# 应用速度缩放
	animation_player.speed_scale = speed

	_on_execution_completed()

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()

	if target_player.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))

	if animation_name.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_ANIMATION_NAME_EMPTY"))

	if speed <= 0.0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_INVALID_SPEED"))

	return errors

## 获取指令描述
func get_description() -> String:
	var options = []

	if speed != 1.0:
		options.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_PLAY_ANIMATION_SPEED", {"speed": speed}))

	if from_end:
		options.append(FuseLocalization.translate("FUSE_INSTRUCTION_PLAY_ANIMATION_REVERSE"))

	if autoplay_only:
		options.append(FuseLocalization.translate("FUSE_INSTRUCTION_PLAY_ANIMATION_AUTOPLAY_ONLY_SHORT"))

	var options_str = ""
	if options.size() > 0:
		options_str = " (" + ", ".join(options) + ")"

	var anim_name = animation_name if not animation_name.is_empty() else FuseLocalization.translate("FUSE_INSTRUCTION_PLAY_ANIMATION_NO_ANIMATION")
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_PLAY_ANIMATION_DESC_FORMAT", {"animation": anim_name, "options": options_str})
