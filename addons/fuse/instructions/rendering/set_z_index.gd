@tool
@icon("res://addons/fuse/icons/builtin/CanvasItem.svg")
extends BaseInstruction
class_name SetZIndex

## 设置 CanvasItem 的 z_index 属性

# =============================================
# 属性定义
# =============================================

## 目标 CanvasItem 节点
var target_node: NodePath = NodePath(""):
	set(value):
		target_node = value
		_update_resource_name()

## Z 索引值
var z_index: int = 0:
	set(value):
		z_index = value
		_update_resource_name()

## 相对调整（true = 在当前基础上增减）
var relative: bool = false:
	set(value):
		relative = value
		_update_resource_name()

# =============================================
# 元数据
# =============================================
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_SET_Z_INDEX_NAME"
	metadata.category_key = "FUSE_CATEGORY_RENDERING"
	metadata.description_key = "FUSE_INSTRUCTION_SET_Z_INDEX_DESC"
	metadata.keywords = ["Z索引", "z_index", "层级", "layer", "深度", "depth", "渲染", "rendering", "排序", "order"]
	metadata.builtin_icon = "CanvasItem"
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
		hint_string = "CanvasItem",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "Z Index",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "z_index",
		type = TYPE_INT,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "relative",
		type = TYPE_BOOL,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

# =============================================
# 资源名称
# =============================================
func _update_resource_name():
	var target_str = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")
	var mode = FuseLocalization.translate("FUSE_TEXT_RELATIVE") if relative else FuseLocalization.translate("FUSE_TEXT_ABSOLUTE")
	resource_name = FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_Z_INDEX_RESOURCE_NAME", {
		"target": target_str,
		"z_index": z_index,
		"mode": mode
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

	if not node is CanvasItem:
		set_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", FuseError.ErrorType.RUNTIME_ERROR, {
			"node": node.name,
			"actual_type": node.get_class()
		})
		finished.emit()
		return

	var canvas_item := node as CanvasItem
	if relative:
		canvas_item.z_index += z_index
	else:
		canvas_item.z_index = z_index

	_log_info_localized("FUSE_LOG_Z_INDEX_SET", {
		"node": node.name,
		"z_index": canvas_item.z_index
	})
	_on_execution_completed()

# =============================================
# 描述
# =============================================
func get_description() -> String:
	var target_str = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")
	var mode = FuseLocalization.translate("FUSE_TEXT_RELATIVE") if relative else FuseLocalization.translate("FUSE_TEXT_ABSOLUTE")
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_Z_INDEX_DESCRIPTION", {
		"target": target_str,
		"z_index": z_index,
		"mode": mode
	})

# =============================================
# 验证
# =============================================
func validate() -> Array[String]:
	var errors = super.validate()
	if target_node.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))
	return errors
