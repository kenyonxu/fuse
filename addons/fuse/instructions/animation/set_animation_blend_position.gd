@tool
@icon("res://addons/fuse/icons/builtin/AnimationTree.png")
extends BaseInstruction
class_name SetAnimationBlendPosition

## 设置 AnimationTree 的 BlendSpace2D/1D 位置

# =============================================
# 属性定义
# =============================================

## 目标 AnimationTree 节点
var target_node: NodePath = NodePath(""):
	set(value):
		target_node = value
		_update_resource_name()

## BlendSpace 节点路径（如 "parameters/IdleWalk/blend_position"）
var blend_node: String = "":
	set(value):
		blend_node = value
		_update_resource_name()

## X 混合值
var x: float = 0.0:
	set(value):
		x = value
		_update_resource_name()

## Y 混合值（1D 忽略）
var y: float = 0.0:
	set(value):
		y = value
		_update_resource_name()

# =============================================
# 元数据
# =============================================
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_SET_ANIM_BLEND_POS_NAME"
	metadata.category_key = "FUSE_CATEGORY_ANIMATION"
	metadata.description_key = "FUSE_INSTRUCTION_SET_ANIM_BLEND_POS_DESC"
	metadata.keywords = ["动画", "animation", "混合", "blend", "AnimationTree", "BlendSpace", "位置", "position", "2D", "1D"]
	metadata.builtin_icon = "AnimationTree"
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
		hint_string = "AnimationTree",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "blend_node",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "Blend Values",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "x",
		type = TYPE_FLOAT,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "y",
		type = TYPE_FLOAT,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

# =============================================
# 资源名称
# =============================================
func _update_resource_name():
	var target_str = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")
	var blend_str = blend_node if not blend_node.is_empty() else "?"
	resource_name = FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_ANIM_BLEND_POS_RESOURCE_NAME", {
		"target": target_str,
		"blend": blend_str,
		"x": x,
		"y": y
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

	if blend_node.is_empty():
		set_error_localized("FUSE_ERROR_MISSING_PARAMETER", FuseError.ErrorType.VALIDATION_ERROR, {"parameter": "blend_node"})
		finished.emit()
		return

	var node := context.get_node(target_node)
	if not node:
		set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"node": str(target_node)})
		finished.emit()
		return

	if not node is AnimationTree:
		set_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", FuseError.ErrorType.RUNTIME_ERROR, {
			"node": node.name,
			"actual_type": node.get_class()
		})
		finished.emit()
		return

	var tree := node as AnimationTree
	tree.set(blend_node, Vector2(x, y))

	_log_info_localized("FUSE_LOG_ANIM_BLEND_POS_SET", {
		"node": node.name,
		"blend": blend_node,
		"x": str(x),
		"y": str(y)
	})
	_on_execution_completed()

# =============================================
# 描述
# =============================================
func get_description() -> String:
	var target_str = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_ANIM_BLEND_POS_DESCRIPTION", {
		"target": target_str,
		"blend": blend_node,
		"x": x,
		"y": y
	})

# =============================================
# 验证
# =============================================
func validate() -> Array[String]:
	var errors = super.validate()
	if target_node.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))
	if blend_node.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_MISSING_PARAMETER"))
	return errors
