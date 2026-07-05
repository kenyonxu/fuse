@tool
@icon("res://addons/fuse/icons/builtin/Sprite2D.svg")
extends BaseInstruction
class_name SetSpriteFlip

## 设置 Sprite2D / AnimatedSprite2D 的水平/垂直翻转

# =============================================
# 枚举定义
# =============================================
enum FlipMode {
	HORIZONTAL,  # 仅水平翻转
	VERTICAL,    # 仅垂直翻转
	BOTH         # 双方向翻转
}

# =============================================
# 属性定义
# =============================================

## 目标 Sprite2D/AnimatedSprite2D 节点
var target_node: NodePath = NodePath(""):
	set(value):
		target_node = value
		_update_resource_name()

## 是否水平翻转
var flip_h: bool = false:
	set(value):
		flip_h = value
		_update_resource_name()

## 是否垂直翻转
var flip_v: bool = false:
	set(value):
		flip_v = value
		_update_resource_name()

## 翻转模式
var flip_mode: FlipMode = FlipMode.BOTH:
	set(value):
		flip_mode = value
		_update_resource_name()

# =============================================
# 元数据（必需）
# =============================================
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_SET_SPRITE_FLIP_NAME"
	metadata.category_key = "FUSE_CATEGORY_ANIMATION"
	metadata.description_key = "FUSE_INSTRUCTION_SET_SPRITE_FLIP_DESC"
	metadata.keywords = ["精灵", "sprite", "翻转", "flip", "水平", "horizontal", "垂直", "vertical", "2D", "动画"]
	metadata.builtin_icon = "Sprite2D"
	return metadata

func _setup_metadata():
	pass

# =============================================
# 动态属性列表
# =============================================
func _get_property_list() -> Array[Dictionary]:
	var properties := []

	# Target 分类
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

	# Flip 分类
	properties.append({
		name = "Flip Settings",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "flip_mode",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Horizontal,Vertical,Both",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "flip_h",
		type = TYPE_BOOL,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "flip_v",
		type = TYPE_BOOL,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

# =============================================
# 资源名称
# =============================================
func _update_resource_name():
	var target_str = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")
	resource_name = FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_SPRITE_FLIP_RESOURCE_NAME", {
		"target": target_str,
		"h": flip_h,
		"v": flip_v
	})

# =============================================
# 条件属性可见性
# =============================================
func _validate_property(property: Dictionary) -> void:
	# 根据 flip_mode 隐藏不需要的属性
	if flip_mode == FlipMode.HORIZONTAL:
		if property.name == "flip_v":
			property.usage = PROPERTY_USAGE_NO_EDITOR
	elif flip_mode == FlipMode.VERTICAL:
		if property.name == "flip_h":
			property.usage = PROPERTY_USAGE_NO_EDITOR

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

	# 根据节点类型设置 flip
	if node is Sprite2D:
		var sprite := node as Sprite2D
		if flip_mode == FlipMode.HORIZONTAL or flip_mode == FlipMode.BOTH:
			sprite.flip_h = flip_h
		if flip_mode == FlipMode.VERTICAL or flip_mode == FlipMode.BOTH:
			sprite.flip_v = flip_v
	elif node is AnimatedSprite2D:
		var anim := node as AnimatedSprite2D
		if flip_mode == FlipMode.HORIZONTAL or flip_mode == FlipMode.BOTH:
			anim.flip_h = flip_h
		if flip_mode == FlipMode.VERTICAL or flip_mode == FlipMode.BOTH:
			anim.flip_v = flip_v
	else:
		set_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", FuseError.ErrorType.RUNTIME_ERROR, {
			"node": node.name,
			"actual_type": node.get_class()
		})
		finished.emit()
		return

	_log_info_localized("FUSE_LOG_SPRITE_FLIP_SET", {
		"node": node.name,
		"h": flip_h,
		"v": flip_v
	})
	_on_execution_completed()

# =============================================
# 描述
# =============================================
func get_description() -> String:
	var target_str = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_SPRITE_FLIP_DESCRIPTION", {
		"target": target_str,
		"h": flip_h,
		"v": flip_v
	})

# =============================================
# 验证
# =============================================
func validate() -> Array[String]:
	var errors = super.validate()
	if target_node.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))
	return errors

# =============================================
# 动态属性拦截
# =============================================
func _set(property: StringName, value: Variant) -> bool:
	if property in ["flip_mode", "flip_h", "flip_v"]:
		set(property, value)
		_update_resource_name()
		if property == "flip_mode":
			notify_property_list_changed()
		return true
	return false
