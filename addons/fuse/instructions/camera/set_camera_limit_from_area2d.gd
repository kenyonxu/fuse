@tool
@icon("res://addons/fuse/icons/builtin/GridCoarse.svg")
extends BaseInstruction
class_name SetCameraLimitFromArea2D

## 根据 Area2D 的矩形碰撞形状自动设置 Camera2D 的边界限制
##
## 适用于横板动作游戏等需要限制相机视野不超出关卡边界的场景。
## 在场景中放置一个 Area2D，并为其添加 RectangleShape2D 的 CollisionShape2D，
## 本指令会读取该矩形的全局边界并应用到目标 Camera2D。

# =============================================
# 参数定义
# =============================================

## 目标 Camera2D 节点路径
var camera_node: NodePath = NodePath(""):
	set(value):
		camera_node = value
		_update_resource_name()

## 边界 Area2D 节点路径（需包含 RectangleShape2D 的 CollisionShape2D）
var bounds_area: NodePath = NodePath(""):
	set(value):
		bounds_area = value
		_update_resource_name()

## 边距（像素），会在计算出的边界基础上外扩/内缩
var margin: int = 0:
	set(value):
		margin = value
		_update_resource_name()

# =============================================
# 元数据方法
# =============================================

## 获取指令元数据（必需）
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_SET_CAMERA_LIMIT_FROM_AREA2D_NAME"
	metadata.category_key = "FUSE_CATEGORY_CAMERA"
	metadata.description_key = "FUSE_INSTRUCTION_SET_CAMERA_LIMIT_FROM_AREA2D_DESC"
	metadata.keywords = ["camera", "limit", "boundary", "area2d", "collision", "bounds", "相机", "边界", "区域", "碰撞"]
	metadata.builtin_icon = "GridCoarse"
	return metadata


## 设置指令元数据
func _setup_metadata() -> void:
	pass


## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []

	# Camera 分类
	properties.append({
		name = "Camera",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "camera_node",
		type = TYPE_NODE_PATH,
		hint = PROPERTY_HINT_NODE_PATH_VALID_TYPES,
		hint_string = "Camera2D",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Bounds 分类
	properties.append({
		name = "Bounds",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "bounds_area",
		type = TYPE_NODE_PATH,
		hint = PROPERTY_HINT_NODE_PATH_VALID_TYPES,
		hint_string = "Area2D",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Options 分类
	properties.append({
		name = "Options",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "margin",
		type = TYPE_INT,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "-1000,1000,1",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties


## 动态属性设置
func _set(property: StringName, value: Variant) -> bool:
	if property in ["camera_node", "bounds_area", "margin"]:
		set(property, value)
		_update_resource_name()
		if property == "margin":
			notify_property_list_changed()
		return true
	return false


# =============================================
# 资源名称和描述
# =============================================

## 更新资源名称（必需）
func _update_resource_name():
	var camera_str = _get_node_display_name(camera_node) if not camera_node.is_empty() else FuseLocalization.translate("FUSE_TEXT_NOT_SPECIFIED")
	var area_str = _get_node_display_name(bounds_area) if not bounds_area.is_empty() else FuseLocalization.translate("FUSE_TEXT_NOT_SPECIFIED")

	resource_name = FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_CAMERA_LIMIT_FROM_AREA2D_RESOURCE_NAME", {
		"camera": camera_str,
		"area": area_str
	})


## 获取指令描述（必需）
func get_description() -> String:
	var camera_str = _get_node_display_name(camera_node) if not camera_node.is_empty() else FuseLocalization.translate("FUSE_TEXT_NOT_SPECIFIED")
	var area_str = _get_node_display_name(bounds_area) if not bounds_area.is_empty() else FuseLocalization.translate("FUSE_TEXT_NOT_SPECIFIED")

	return FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_CAMERA_LIMIT_FROM_AREA2D_DESC_FORMAT", {
		"camera": camera_str,
		"area": area_str,
		"margin": str(margin)
	})


# =============================================
# 执行逻辑
# =============================================

## 执行指令（必需）
func execute(context: ExecutionContext) -> void:
	_start_execution(context)

	# ============================================
	# 1. 验证参数
	# ============================================

	if camera_node.is_empty():
		_log_error_localized("FUSE_ERROR_CAMERA_NODE_EMPTY", {})
		set_error_localized("FUSE_ERROR_CAMERA_NODE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	if bounds_area.is_empty():
		_log_error_localized("FUSE_ERROR_BOUNDS_AREA_EMPTY", {})
		set_error_localized("FUSE_ERROR_BOUNDS_AREA_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# ============================================
	# 2. 获取并验证相机节点
	# ============================================

	var camera := context.get_node(camera_node)
	if not camera:
		_log_error_localized("FUSE_ERROR_CAMERA_NODE_NOT_FOUND", {})
		set_error_localized("FUSE_ERROR_CAMERA_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	if not camera is Camera2D:
		_log_error_localized("FUSE_ERROR_CAMERA_NOT_CAMERA2D", {})
		set_error_localized("FUSE_ERROR_CAMERA_NOT_CAMERA2D", FuseError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	var camera_2d := camera as Camera2D

	# ============================================
	# 3. 获取并验证边界区域
	# ============================================

	var area := context.get_node(bounds_area)
	if not area:
		_log_error_localized("FUSE_ERROR_BOUNDS_AREA_NOT_FOUND", {})
		set_error_localized("FUSE_ERROR_BOUNDS_AREA_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	if not area is Area2D:
		_log_error_localized("FUSE_ERROR_BOUNDS_AREA_NOT_AREA2D", {"node": area.name})
		set_error_localized("FUSE_ERROR_BOUNDS_AREA_NOT_AREA2D", FuseError.ErrorType.RUNTIME_ERROR, {"node": area.name})
		finished.emit()
		return

	var area_2d := area as Area2D

	# ============================================
	# 4. 查找 CollisionShape2D 子节点
	# ============================================

	var collision_shape := _find_collision_shape(area_2d)
	if not collision_shape:
		_log_error_localized("FUSE_ERROR_BOUNDS_COLLISION_SHAPE_NOT_FOUND", {"area": area_2d.name})
		set_error_localized("FUSE_ERROR_BOUNDS_COLLISION_SHAPE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"area": area_2d.name})
		finished.emit()
		return

	# ============================================
	# 5. 验证形状类型并计算边界
	# ============================================

	var shape = collision_shape.shape
	if not shape is RectangleShape2D:
		_log_error_localized("FUSE_ERROR_BOUNDS_SHAPE_NOT_RECTANGLE", {
			"area": area_2d.name,
			"shape": shape.get_class() if shape else "null"
		})
		set_error_localized("FUSE_ERROR_BOUNDS_SHAPE_NOT_RECTANGLE", FuseError.ErrorType.RUNTIME_ERROR, {
			"area": area_2d.name,
			"shape": shape.get_class() if shape else "null"
		})
		finished.emit()
		return

	var rect_shape := shape as RectangleShape2D
	var center := collision_shape.global_position
	var extents := rect_shape.size / 2.0

	var limit_left := int(center.x - extents.x - margin)
	var limit_right := int(center.x + extents.x + margin)
	var limit_top := int(center.y - extents.y - margin)
	var limit_bottom := int(center.y + extents.y + margin)

	# ============================================
	# 6. 应用边界到 Camera2D
	# ============================================

	camera_2d.limit_left = limit_left
	camera_2d.limit_right = limit_right
	camera_2d.limit_top = limit_top
	camera_2d.limit_bottom = limit_bottom

	_log_info_localized("FUSE_LOG_SET_CAMERA_LIMIT_FROM_AREA2D", {
		"camera": camera_2d.name,
		"area": area_2d.name,
		"left": str(limit_left),
		"right": str(limit_right),
		"top": str(limit_top),
		"bottom": str(limit_bottom)
	})

	_on_execution_completed()


## 在 Area2D 下查找 CollisionShape2D 子节点
func _find_collision_shape(area: Area2D) -> CollisionShape2D:
	for child in area.get_children():
		if child is CollisionShape2D:
			return child
	return null


# =============================================
# 验证
# =============================================

## 验证指令参数（必需）
func validate() -> Array[String]:
	var errors := super.validate()

	if camera_node.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_CAMERA_NODE_EMPTY"))

	if bounds_area.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_BOUNDS_AREA_EMPTY"))

	return errors


# =============================================
# 变量模式声明
# =============================================

## 声明变量读写模式（本指令不读写变量，但仍需实现）
func get_variable_modes() -> Array[Dictionary]:
	return []
