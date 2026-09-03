@tool
@icon("res://addons/fuse/icons/builtin/BoneMapperHandleSelected.png")
extends BaseInstruction
class_name SetCameraLimit


## 作用域来源枚举
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

## 设置 Camera2D 的移动边界限制

# 边界值常量
const UNLIMITED_VALUE: int = -9999
const MIN_LIMIT: int = -9999
const MAX_LIMIT: int = 10000

# 目标 Camera2D 节点路径
var target_node: NodePath = NodePath("")

## 是否从变量获取相机节点
var use_variable_for_target: bool = false:
	set(value):
		use_variable_for_target = value
		_update_resource_name()
		notify_property_list_changed()

## 相机节点变量名
var target_variable: String = "":
	set(value):
		target_variable = value
		_update_resource_name()

## 相机节点变量作用域
var target_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		target_scope = value
		_update_resource_name()
		notify_property_list_changed()

## 相机节点作用域来源（仅当 target_scope == SCOPE 时使用）
var target_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		target_scope_source = value
		_update_resource_name()
		notify_property_list_changed()

## 相机节点自定义作用域 ID（CUSTOM_ID 模式使用）
var target_custom_scope_id: String = "":
	set(value):
		target_custom_scope_id = value
		_update_resource_name()

## 相机节点目标节点路径（TARGET_NODE 模式使用）
var target_target_node_path: NodePath = NodePath(""):
	set(value):
		target_target_node_path = value
		_update_resource_name()

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

## 声明变量读写模式
func get_variable_modes() -> Array[Dictionary]:
	var modes: Array[Dictionary] = []
	if use_variable_for_target:
		modes.append({"name": "target_variable", "mode": "read"})
	return modes


## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	properties.append({
		name = "Camera",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})


	# 是否从变量获取相机节点
	properties.append({
		name = "use_variable_for_target",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if not use_variable_for_target:
		# 直接指定节点路径
		properties.append({
			name = "target_node",
			type = TYPE_NODE_PATH,
			hint = PROPERTY_HINT_NODE_PATH_VALID_TYPES,
			hint_string = "Camera2D",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
	else:
		# 从变量获取节点
		properties.append({
			name = "target_variable",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		properties.append({
			name = "target_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		if target_scope == BaseVariable.VariableScope.SCOPE:
			properties.append({
				name = "target_scope_source",
				type = TYPE_INT,
				hint = PROPERTY_HINT_ENUM,
				hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

			if target_scope_source == ScopeSource.CUSTOM_ID:
				properties.append({
					name = "target_custom_scope_id",
					type = TYPE_STRING,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})
			elif target_scope_source == ScopeSource.TARGET_NODE:
				properties.append({
					name = "target_target_node_path",
					type = TYPE_NODE_PATH,
					hint = PROPERTY_HINT_NONE,
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

	# 获取目标节点
	var node := _resolve_node(
		context,
		use_variable_for_target,
		target_node,
		target_variable,
		target_scope,
		target_scope_source,
		target_custom_scope_id,
		target_target_node_path,
		"FUSE_ERROR_TARGET_VARIABLE_EMPTY",
		"FUSE_ERROR_TARGET_NODE_EMPTY",
		"FUSE_ERROR_TARGET_NODE_NOT_FOUND"
	)
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
	# 验证 相机节点
	if use_variable_for_target:
		if target_variable.is_empty():
			errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_VARIABLE_EMPTY"))
		if target_scope == BaseVariable.VariableScope.SCOPE:
			var target_utils_scope_source = target_scope_source as VariableScopeUtils.ScopeSource
			errors.append_array(VariableScopeUtils.validate_scope_source_params(
				target_utils_scope_source,
				target_custom_scope_id,
				target_target_node_path
			))
	else:
		if target_node.is_empty():
			errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))


	return errors

## 属性验证
func _validate_property(property: Dictionary) -> void:
	# 控制相机节点相关属性可见性
	if not use_variable_for_target:
		if property.name in ["target_variable", "target_scope", "target_scope_source", "target_custom_scope_id", "target_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		if property.name == "target_node":
			property.usage = PROPERTY_USAGE_NO_EDITOR

		if target_scope != BaseVariable.VariableScope.SCOPE:
			if property.name in ["target_scope_source", "target_custom_scope_id", "target_target_node_path"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR
		else:
			var target_utils_scope_source = target_scope_source as VariableScopeUtils.ScopeSource
			VariableScopeUtils.validate_scope_source_property(property, target_utils_scope_source)
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
	if property in ["use_variable_for_target", "target_scope", "target_scope_source"]:
		set(property, value_)
		notify_property_list_changed()
		return true
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
			_log_error_localized("FUSE_ERROR_VAR_NOT_FOUND", {"name": variable_name})
			set_error_localized("FUSE_ERROR_VAR_NOT_FOUND", FuseError.ErrorType.VALIDATION_ERROR, {"name": variable_name})
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

