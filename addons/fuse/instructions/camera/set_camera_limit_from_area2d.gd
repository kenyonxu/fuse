@tool
@icon("res://addons/fuse/icons/builtin/GridCoarse.svg")
extends BaseInstruction
class_name SetCameraLimitFromArea2D

## 根据 Area2D 的矩形碰撞形状自动设置 Camera2D 的边界限制
##
## 适用于横板动作游戏等需要限制相机视野不超出关卡边界的场景。
## 在场景中放置一个 Area2D，并为其添加 RectangleShape2D 的 CollisionShape2D，
## 本指令会读取该矩形的全局边界并应用到目标 Camera2D。

## 作用域来源枚举
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

# =============================================
# 参数定义
# =============================================

## 目标 Camera2D 节点路径
var camera_node: NodePath = NodePath(""):
	set(value):
		camera_node = value
		_update_resource_name()

## 是否从变量获取 Camera2D
var use_variable_for_camera: bool = false:
	set(value):
		use_variable_for_camera = value
		_update_resource_name()
		notify_property_list_changed()

## Camera2D 变量名
var camera_variable: String = "":
	set(value):
		camera_variable = value
		_update_resource_name()

## Camera2D 变量作用域
var camera_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		camera_scope = value
		_update_resource_name()
		notify_property_list_changed()

## Camera2D 作用域来源（仅当 camera_scope == SCOPE 时使用）
var camera_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		camera_scope_source = value
		_update_resource_name()
		notify_property_list_changed()

## Camera2D 自定义作用域 ID（CUSTOM_ID 模式使用）
var camera_custom_scope_id: String = "":
	set(value):
		camera_custom_scope_id = value
		_update_resource_name()

## Camera2D 目标节点路径（TARGET_NODE 模式使用）
var camera_target_node_path: NodePath = NodePath(""):
	set(value):
		camera_target_node_path = value
		_update_resource_name()

## 边界 Area2D 节点路径（需包含 RectangleShape2D 的 CollisionShape2D）
var bounds_area: NodePath = NodePath(""):
	set(value):
		bounds_area = value
		_update_resource_name()

## 是否从变量获取边界 Area2D
var use_variable_for_bounds: bool = false:
	set(value):
		use_variable_for_bounds = value
		_update_resource_name()
		notify_property_list_changed()

## 边界 Area2D 变量名
var bounds_variable: String = "":
	set(value):
		bounds_variable = value
		_update_resource_name()

## 边界 Area2D 变量作用域
var bounds_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		bounds_scope = value
		_update_resource_name()
		notify_property_list_changed()

## 边界 Area2D 作用域来源（仅当 bounds_scope == SCOPE 时使用）
var bounds_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		bounds_scope_source = value
		_update_resource_name()
		notify_property_list_changed()

## 边界 Area2D 自定义作用域 ID（CUSTOM_ID 模式使用）
var bounds_custom_scope_id: String = "":
	set(value):
		bounds_custom_scope_id = value
		_update_resource_name()

## 边界 Area2D 目标节点路径（TARGET_NODE 模式使用）
var bounds_target_node_path: NodePath = NodePath(""):
	set(value):
		bounds_target_node_path = value
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


## 声明变量读写模式
func get_variable_modes() -> Array[Dictionary]:
	var modes: Array[Dictionary] = []
	if use_variable_for_camera:
		modes.append({"name": "camera_variable", "mode": "read"})
	if use_variable_for_bounds:
		modes.append({"name": "bounds_variable", "mode": "read"})
	return modes


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
		name = "use_variable_for_camera",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if not use_variable_for_camera:
		properties.append({
			name = "camera_node",
			type = TYPE_NODE_PATH,
			hint = PROPERTY_HINT_NODE_PATH_VALID_TYPES,
			hint_string = "Camera2D",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
	else:
		properties.append({
			name = "camera_variable",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		properties.append({
			name = "camera_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		if camera_scope == BaseVariable.VariableScope.SCOPE:
			properties.append({
				name = "camera_scope_source",
				type = TYPE_INT,
				hint = PROPERTY_HINT_ENUM,
				hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

			if camera_scope_source == ScopeSource.CUSTOM_ID:
				properties.append({
					name = "camera_custom_scope_id",
					type = TYPE_STRING,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})
			elif camera_scope_source == ScopeSource.TARGET_NODE:
				properties.append({
					name = "camera_target_node_path",
					type = TYPE_NODE_PATH,
					hint = PROPERTY_HINT_NONE,
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
		name = "use_variable_for_bounds",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if not use_variable_for_bounds:
		properties.append({
			name = "bounds_area",
			type = TYPE_NODE_PATH,
			hint = PROPERTY_HINT_NODE_PATH_VALID_TYPES,
			hint_string = "Area2D",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
	else:
		properties.append({
			name = "bounds_variable",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		properties.append({
			name = "bounds_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		if bounds_scope == BaseVariable.VariableScope.SCOPE:
			properties.append({
				name = "bounds_scope_source",
				type = TYPE_INT,
				hint = PROPERTY_HINT_ENUM,
				hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

			if bounds_scope_source == ScopeSource.CUSTOM_ID:
				properties.append({
					name = "bounds_custom_scope_id",
					type = TYPE_STRING,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})
			elif bounds_scope_source == ScopeSource.TARGET_NODE:
				properties.append({
					name = "bounds_target_node_path",
					type = TYPE_NODE_PATH,
					hint = PROPERTY_HINT_NONE,
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


## 属性验证
func _validate_property(property: Dictionary) -> void:
	# 控制 Camera 相关节点属性可见性
	if not use_variable_for_camera:
		if property.name in ["camera_variable", "camera_scope", "camera_scope_source", "camera_custom_scope_id", "camera_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		if property.name == "camera_node":
			property.usage = PROPERTY_USAGE_NO_EDITOR

		if camera_scope != BaseVariable.VariableScope.SCOPE:
			if property.name in ["camera_scope_source", "camera_custom_scope_id", "camera_target_node_path"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR
		else:
			var camera_utils_scope_source = camera_scope_source as VariableScopeUtils.ScopeSource
			VariableScopeUtils.validate_scope_source_property(property, camera_utils_scope_source)

	# 控制 Bounds 相关节点属性可见性
	if not use_variable_for_bounds:
		if property.name in ["bounds_variable", "bounds_scope", "bounds_scope_source", "bounds_custom_scope_id", "bounds_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		if property.name == "bounds_area":
			property.usage = PROPERTY_USAGE_NO_EDITOR

		if bounds_scope != BaseVariable.VariableScope.SCOPE:
			if property.name in ["bounds_scope_source", "bounds_custom_scope_id", "bounds_target_node_path"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR
		else:
			var bounds_utils_scope_source = bounds_scope_source as VariableScopeUtils.ScopeSource
			VariableScopeUtils.validate_scope_source_property(property, bounds_utils_scope_source)


## 动态属性设置
func _set(property: StringName, value: Variant) -> bool:
	if property in ["use_variable_for_camera", "camera_scope", "camera_scope_source", "use_variable_for_bounds", "bounds_scope", "bounds_scope_source"]:
		set(property, value)
		_update_resource_name()
		notify_property_list_changed()
		return true
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
	var camera_str := _get_camera_display()
	var area_str := _get_bounds_display()

	resource_name = FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_CAMERA_LIMIT_FROM_AREA2D_RESOURCE_NAME", {
		"camera": camera_str,
		"area": area_str
	})


## 获取 Camera 显示字符串
func _get_camera_display() -> String:
	if use_variable_for_camera:
		if camera_variable.is_empty():
			return FuseLocalization.translate("FUSE_TEXT_NOT_SPECIFIED")
		var scope_str := VariableScopeUtils.enum_to_string(camera_scope).to_upper()
		if camera_scope == BaseVariable.VariableScope.SCOPE:
			var camera_utils_scope_source = camera_scope_source as VariableScopeUtils.ScopeSource
			scope_str = VariableScopeUtils.get_scope_source_string(camera_utils_scope_source, camera_custom_scope_id, camera_target_node_path)
		return "%s [%s]" % [camera_variable, scope_str]
	return _get_node_display_name(camera_node) if not camera_node.is_empty() else FuseLocalization.translate("FUSE_TEXT_NOT_SPECIFIED")


## 获取 Bounds 显示字符串
func _get_bounds_display() -> String:
	if use_variable_for_bounds:
		if bounds_variable.is_empty():
			return FuseLocalization.translate("FUSE_TEXT_NOT_SPECIFIED")
		var scope_str := VariableScopeUtils.enum_to_string(bounds_scope).to_upper()
		if bounds_scope == BaseVariable.VariableScope.SCOPE:
			var bounds_utils_scope_source = bounds_scope_source as VariableScopeUtils.ScopeSource
			scope_str = VariableScopeUtils.get_scope_source_string(bounds_utils_scope_source, bounds_custom_scope_id, bounds_target_node_path)
		return "%s [%s]" % [bounds_variable, scope_str]
	return _get_node_display_name(bounds_area) if not bounds_area.is_empty() else FuseLocalization.translate("FUSE_TEXT_NOT_SPECIFIED")


## 获取指令描述（必需）
func get_description() -> String:
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_CAMERA_LIMIT_FROM_AREA2D_DESC_FORMAT", {
		"camera": _get_camera_display(),
		"area": _get_bounds_display(),
		"margin": str(margin)
	})


# =============================================
# 执行逻辑
# =============================================

## 执行指令（必需）
func execute(context: ExecutionContext) -> void:
	_start_execution(context)

	# ============================================
	# 1. 获取并验证相机节点
	# ============================================

	var camera := _resolve_node(
		context,
		use_variable_for_camera,
		camera_node,
		camera_variable,
		camera_scope,
		camera_scope_source,
		camera_custom_scope_id,
		camera_target_node_path,
		"FUSE_ERROR_CAMERA_NODE_EMPTY",
		"FUSE_ERROR_CAMERA_NODE_EMPTY",
		"FUSE_ERROR_CAMERA_NODE_NOT_FOUND"
	)
	if not camera:
		finished.emit()
		return

	if not camera is Camera2D:
		_log_error_localized("FUSE_ERROR_CAMERA_NOT_CAMERA2D", {})
		set_error_localized("FUSE_ERROR_CAMERA_NOT_CAMERA2D", FuseError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	var camera_2d := camera as Camera2D

	# ============================================
	# 2. 获取并验证边界区域
	# ============================================

	var area := _resolve_node(
		context,
		use_variable_for_bounds,
		bounds_area,
		bounds_variable,
		bounds_scope,
		bounds_scope_source,
		bounds_custom_scope_id,
		bounds_target_node_path,
		"FUSE_ERROR_BOUNDS_AREA_EMPTY",
		"FUSE_ERROR_BOUNDS_AREA_EMPTY",
		"FUSE_ERROR_BOUNDS_AREA_NOT_FOUND"
	)
	if not area:
		finished.emit()
		return

	if not area is Area2D:
		_log_error_localized("FUSE_ERROR_BOUNDS_AREA_NOT_AREA2D", {"node": area.name})
		set_error_localized("FUSE_ERROR_BOUNDS_AREA_NOT_AREA2D", FuseError.ErrorType.RUNTIME_ERROR, {"node": area.name})
		finished.emit()
		return

	var area_2d := area as Area2D

	# ============================================
	# 3. 查找 CollisionShape2D 子节点
	# ============================================

	var collision_shape := _find_collision_shape(area_2d)
	if not collision_shape:
		_log_error_localized("FUSE_ERROR_BOUNDS_COLLISION_SHAPE_NOT_FOUND", {"area": area_2d.name})
		set_error_localized("FUSE_ERROR_BOUNDS_COLLISION_SHAPE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"area": area_2d.name})
		finished.emit()
		return

	# ============================================
	# 4. 验证形状类型并计算边界
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
	# 5. 应用边界到 Camera2D
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

	if use_variable_for_camera:
		if camera_variable.is_empty():
			errors.append(FuseLocalization.translate("FUSE_ERROR_CAMERA_NODE_EMPTY"))
		if camera_scope == BaseVariable.VariableScope.SCOPE:
			var camera_utils_scope_source = camera_scope_source as VariableScopeUtils.ScopeSource
			errors.append_array(VariableScopeUtils.validate_scope_source_params(
				camera_utils_scope_source,
				camera_custom_scope_id,
				camera_target_node_path
			))
	else:
		if camera_node.is_empty():
			errors.append(FuseLocalization.translate("FUSE_ERROR_CAMERA_NODE_EMPTY"))

	if use_variable_for_bounds:
		if bounds_variable.is_empty():
			errors.append(FuseLocalization.translate("FUSE_ERROR_BOUNDS_AREA_EMPTY"))
		if bounds_scope == BaseVariable.VariableScope.SCOPE:
			var bounds_utils_scope_source = bounds_scope_source as VariableScopeUtils.ScopeSource
			errors.append_array(VariableScopeUtils.validate_scope_source_params(
				bounds_utils_scope_source,
				bounds_custom_scope_id,
				bounds_target_node_path
			))
	else:
		if bounds_area.is_empty():
			errors.append(FuseLocalization.translate("FUSE_ERROR_BOUNDS_AREA_EMPTY"))

	return errors


# =============================================
# 节点解析
# =============================================

## 从变量或节点路径解析节点
func _resolve_node(
	context: ExecutionContext,
	use_variable: bool,
	node_path: NodePath,
	variable_name: String,
	variable_scope: BaseVariable.VariableScope,
	scope_source: ScopeSource,
	custom_scope_id: String,
	target_node_path: NodePath,
	empty_variable_error_key: String,
	empty_node_error_key: String,
	not_found_error_key: String
) -> Node:
	if use_variable:
		if variable_name.is_empty():
			_log_error_localized(empty_variable_error_key, {})
			set_error_localized(empty_variable_error_key, FuseError.ErrorType.VALIDATION_ERROR, {})
			return null

		var node_value = VariableOperations.get_variable(
			context,
			variable_name,
			variable_scope,
			null
		)

		if node_value == null and not VariableOperations.has_variable(context, variable_name, variable_scope):
			_log_error_localized("FUSE_ERROR_VAR_NOT_FOUND", {"variable": variable_name})
			set_error_localized("FUSE_ERROR_VAR_NOT_FOUND", FuseError.ErrorType.VALIDATION_ERROR, {"variable": variable_name})
			return null

		# 支持多种类型：Node、String（节点路径）、NodePath
		if node_value is Node:
			return node_value
		elif node_value is String or node_value is NodePath:
			var resolved_path = NodePath(node_value)
			var resolved_node = context.get_node(resolved_path)
			if not resolved_node:
				_log_error_localized(not_found_error_key, {"node": str(node_value)})
				set_error_localized(not_found_error_key, FuseError.ErrorType.RUNTIME_ERROR, {"node": str(node_value)})
				return null
			return resolved_node
		else:
			_log_error_localized("FUSE_ERROR_VAR_TYPE_NOT_NODE_OR_PATH", {"variable": variable_name, "actual_type": type_string(typeof(node_value))})
			set_error_localized("FUSE_ERROR_VAR_TYPE_NOT_NODE_OR_PATH", FuseError.ErrorType.VALIDATION_ERROR, {"variable": variable_name, "actual_type": type_string(typeof(node_value))})
			return null
	else:
		if node_path.is_empty():
			_log_error_localized(empty_node_error_key, {})
			set_error_localized(empty_node_error_key, FuseError.ErrorType.VALIDATION_ERROR, {})
			return null

		var resolved_node = context.get_node(node_path)
		if not resolved_node:
			_log_error_localized(not_found_error_key, {"node": str(node_path)})
			set_error_localized(not_found_error_key, FuseError.ErrorType.RUNTIME_ERROR, {"node": str(node_path)})
			return null
		return resolved_node
