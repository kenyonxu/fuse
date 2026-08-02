@tool
@icon("res://addons/fuse/icons/builtin/Sprite2D.svg")
extends BaseInstruction
class_name SetSpriteFrame

## 直接设置 Sprite2D/AnimatedSprite2D 的帧

# =============================================
# 属性定义
# =============================================

## 目标 Sprite2D/AnimatedSprite2D 节点
var target_node: NodePath = NodePath(""):
	set(value):
		target_node = value
		_update_resource_name()

## 帧索引
var frame: int = 0:
	set(value):
		frame = value
		_update_resource_name()

# =============================================
# 元数据
# =============================================
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_SET_SPRITE_FRAME_NAME"
	metadata.category_key = "FUSE_CATEGORY_ANIMATION"
	metadata.description_key = "FUSE_INSTRUCTION_SET_SPRITE_FRAME_DESC"
	metadata.keywords = ["精灵", "sprite", "帧", "frame", "动画", "animation", "2D", "图片", "image"]
	metadata.builtin_icon = "Sprite2D"
	return metadata

func _setup_metadata():
	pass

# =============================================
# 动态属性列表
# =============================================
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	properties.append({
		name = "Target",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "target_node",
		type = TYPE_NODE_PATH,
		hint = PROPERTY_HINT_NODE_PATH_VALID_TYPES,
		hint_string = "Sprite2D,AnimatedSprite2D",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "Frame",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "frame",
		type = TYPE_INT,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

# =============================================
# 资源名称
# =============================================
func _update_resource_name():
	var target_str = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")
	resource_name = FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_SPRITE_FRAME_RESOURCE_NAME", {
		"target": target_str,
		"frame": frame
	})

# =============================================
# 执行
# =============================================
func execute(context: ExecutionContext):
	_start_execution(context)

	if target_node.is_empty():
		set_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	var node := context.get_node(target_node)
	if not node:
		set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"node": str(target_node)})
		finished.emit()
		return

	# 支持 Sprite2D 和 AnimatedSprite2D
	if node is Sprite2D:
		var sprite := node as Sprite2D
		sprite.frame = frame
	elif node is AnimatedSprite2D:
		var anim := node as AnimatedSprite2D
		anim.frame = frame
	else:
		set_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", FuseError.ErrorType.RUNTIME_ERROR, {
			"node": node.name,
			"actual_type": node.get_class()
		})
		finished.emit()
		return

	_log_info_localized("FUSE_LOG_SPRITE_FRAME_SET", {
		"node": node.name,
		"frame": frame
	})
	_on_execution_completed()

# =============================================
# 描述
# =============================================
func get_description() -> String:
	var target_str = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_SPRITE_FRAME_DESCRIPTION", {
		"target": target_str,
		"frame": frame
	})

# =============================================
# 验证
# =============================================
func validate() -> Array[String]:
	var errors = super.validate()
	if target_node.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))
	return errors
