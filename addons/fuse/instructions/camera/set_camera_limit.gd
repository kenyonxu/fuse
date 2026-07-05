@tool
@icon("res://addons/fuse/icons/builtin/BoneMapperHandleSelected.png")
extends BaseInstruction
class_name SetCameraLimit

## 设置 Camera2D 的移动边界限制

# 边界值常量
const UNLIMITED_VALUE: int = -9999
const MIN_LIMIT: int = -9999
const MAX_LIMIT: int = 10000

# 目标 Camera2D 节点路径
var target_node: NodePath = NodePath("")

# 边界类型
enum LimitSide {
	TOP,
	BOTTOM,
	LEFT,
	RIGHT
}
var limit_side: LimitSide = LimitSide.TOP:
	set(value_):
		limit_side = value_
		_update_resource_name()

# 边界值（-9999 表示无限制）
var limit_value: int = -9999:
	set(value_):
		limit_value = value_
		_update_resource_name()

## 获取指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_SET_CAMERA_LIMIT_NAME"
	metadata.category_key = "FUSE_CATEGORY_CAMERA"
	metadata.description_key = "FUSE_INSTRUCTION_SET_CAMERA_LIMIT_DESC"
	metadata.keywords = ["camera", "limit", "boundary", "top", "bottom", "left", "right", "相机", "限制", "边界"]
	metadata.builtin_icon = "BoneMapperHandleSelected"
	return metadata

func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties := []

	properties.append({
		name = "Camera",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "target_node",
		type = TYPE_NODE_PATH,
		hint = PROPERTY_HINT_NODE_PATH_VALID_TYPES,
		hint_string = "Camera2D",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "Limit",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "limit_side",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Top,Bottom,Left,Right",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "limit_value",
		type = TYPE_INT,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "-9999,10000,1",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 更新资源名称
func _update_resource_name():
	var parts := []

	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_SET_CAMERA_LIMIT_BASE_NAME"))

	parts.append(_get_side_name())

	if limit_value == UNLIMITED_VALUE:
		parts.append(FuseLocalization.translate("FUSE_CAMERA_LIMIT_UNLIMITED"))
	else:
		parts.append(FuseLocalization.translate_format("FUSE_CAMERA_LIMIT_VALUE", {"value": str(limit_value)}))

	resource_name = " ".join(parts)

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	# 验证目标节点
	if target_node.is_empty():
		_log_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", {})
		set_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 获取目标节点
	var node := context.get_node(target_node)
	if not node:
		_log_error_localized("FUSE_ERROR_CAMERA_NODE_NOT_FOUND", {})
		set_error_localized("FUSE_ERROR_CAMERA_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	# 验证节点类型
	if not node is Camera2D:
		_log_error_localized("FUSE_ERROR_CAMERA_NOT_CAMERA2D", {})
		set_error_localized("FUSE_ERROR_CAMERA_NOT_CAMERA2D", FuseError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	var camera := node as Camera2D

	# 验证边界值
	if limit_value < MIN_LIMIT or limit_value > MAX_LIMIT:
		_log_error_localized("FUSE_ERROR_LIMIT_OUT_OF_RANGE", {})
		set_error_localized("FUSE_ERROR_CAMERA_LIMIT_OUT_OF_RANGE", FuseError.ErrorType.VALIDATION_ERROR, {"value": str(limit_value), "min": str(MIN_LIMIT), "max": str(MAX_LIMIT)})
		finished.emit()
		return

	# 设置边界值
	match limit_side:
		LimitSide.TOP:
			camera.limit_top = limit_value
		LimitSide.BOTTOM:
			camera.limit_bottom = limit_value
		LimitSide.LEFT:
			camera.limit_left = limit_value
		LimitSide.RIGHT:
			camera.limit_right = limit_value

	var side_name := _get_side_name()
	var value_str := "无限制" if limit_value == UNLIMITED_VALUE else str(limit_value)
	_log_info_localized("FUSE_LOG_SET_CAMERA_LIMIT", {"side": side_name, "value": value_str})
	_on_execution_completed()

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()

	if target_node.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_CAMERA_NODE_EMPTY"))

	return errors

## 获取指令描述
func get_description() -> String:
	var side_name := _get_side_name()
	var value_str := FuseLocalization.translate("FUSE_CAMERA_LIMIT_UNLIMITED") if limit_value == UNLIMITED_VALUE else "%d" % limit_value
	var target_str := _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_CAMERA_TARGET_NOT_SELECTED")
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_CAMERA_LIMIT_DESC_FORMAT", {
		"target": target_str,
		"side": side_name,
		"value": value_str
	})

## 动态属性设置
func _set(property: StringName, value_: Variant) -> bool:
	if property == "limit_side" or property == "limit_value":
		set(property, value_)
		_update_resource_name()
		return true
	return false

## 获取边界侧边的中文名称
func _get_side_name() -> String:
	match limit_side:
		LimitSide.TOP: return FuseLocalization.translate("FUSE_CAMERA_LIMIT_SIDE_TOP")
		LimitSide.BOTTOM: return FuseLocalization.translate("FUSE_CAMERA_LIMIT_SIDE_BOTTOM")
		LimitSide.LEFT: return FuseLocalization.translate("FUSE_CAMERA_LIMIT_SIDE_LEFT")
		LimitSide.RIGHT: return FuseLocalization.translate("FUSE_CAMERA_LIMIT_SIDE_RIGHT")
	return ""
