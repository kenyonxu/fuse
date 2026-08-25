@tool
@icon("res://addons/fuse/icons/builtin/ViewportSpeed.png")
extends BaseInstruction
class_name AddVelocity

## 叠加速度冲量
##
## 向物理体（CharacterBody2D/RigidBody2D 等含 velocity 属性的节点）叠加一个
## 速度冲量（加法而非覆盖，保留现有速度）。受击击退、弹板、击飞等场景用。
## 注意：若目标节点受移动锁（如 lock_movement 每帧清速度）控制，需配合
## 摩擦衰减式锁速才能保留冲量。

## 冲量值来源
enum ImpulseSource {
	DIRECT,    ## 直接设置
	VARIABLE   ## 从变量读取
}

## 作用域来源枚举
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

# =============================================
# 属性定义
# =============================================

## 目标物理体节点路径
var target_node: NodePath = NodePath(""):
	set(value):
		target_node = value
		_update_resource_name()

## 是否从变量获取目标节点
var use_variable_for_target: bool = false:
	set(value):
		use_variable_for_target = value
		_update_resource_name()
		notify_property_list_changed()

## 目标节点变量名
var target_variable: String = "":
	set(value):
		target_variable = value
		_update_resource_name()

## 目标节点变量作用域
var target_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		target_scope = value
		_update_resource_name()
		notify_property_list_changed()

## 目标节点作用域来源（仅当 target_scope == SCOPE 时使用）
var target_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		target_scope_source = value
		_update_resource_name()
		notify_property_list_changed()

## 目标节点自定义作用域 ID（CUSTOM_ID 模式使用）
var target_custom_scope_id: String = "":
	set(value):
		target_custom_scope_id = value
		_update_resource_name()

## 目标节点目标节点路径（TARGET_NODE 模式使用）
var target_target_node_path: NodePath = NodePath(""):
	set(value):
		target_target_node_path = value
		_update_resource_name()

## 应用模式
enum ReplaceMode {
	ADDITIVE,    ## 叠加（保留现有速度）
	REPLACE_X,   ## 覆盖 X 分量（Y 保留——击退：设定水平击退速度，重力/下落不受影响）
	REPLACE_Y    ## 覆盖 Y 分量（X 保留——弹板/击飞：设定垂直速度，水平移动不受影响）
}

## 冲量应用模式
var replace_mode: ReplaceMode = ReplaceMode.ADDITIVE:
	set(value):
		replace_mode = value
		_update_resource_name()

## 冲量值来源模式
var impulse_source: ImpulseSource = ImpulseSource.DIRECT:
	set(value):
		impulse_source = value
		_update_resource_name()
		notify_property_list_changed()

## 直接设置的冲量值（叠加到当前速度）
var impulse: Vector2 = Vector2.ZERO:
	set(value):
		impulse = value
		_update_resource_name()

## 冲量变量名（当 impulse_source == VARIABLE 时使用，值为 Vector2）
var impulse_variable: String = "":
	set(value):
		impulse_variable = value
		_update_resource_name()

## 冲量变量作用域
var impulse_variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		impulse_variable_scope = value
		_update_resource_name()
		notify_property_list_changed()

## 冲量作用域来源（仅当 impulse_variable_scope == SCOPE 时使用）
var impulse_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		impulse_scope_source = value
		_update_resource_name()
		notify_property_list_changed()

## 冲量自定义作用域 ID（CUSTOM_ID 模式使用）
var impulse_custom_scope_id: String = "":
	set(value):
		impulse_custom_scope_id = value
		_update_resource_name()

## 冲量目标节点路径（TARGET_NODE 模式使用）
var impulse_target_node_path: NodePath = NodePath(""):
	set(value):
		impulse_target_node_path = value
		_update_resource_name()

# =============================================
# 元数据
# =============================================

static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_ADD_VELOCITY_NAME"
	metadata.category_key = "FUSE_CATEGORY_PHYSICS"
	metadata.description_key = "FUSE_INSTRUCTION_ADD_VELOCITY_DESC"
	metadata.keywords = ["velocity", "impulse", "knockback", "击退", "冲量", "速度", "弹跳", "物理"]
	metadata.builtin_icon = "ViewportSpeed"
	return metadata

func _setup_metadata():
	pass

func get_variable_modes() -> Array[Dictionary]:
	var modes: Array[Dictionary] = []
	if use_variable_for_target:
		modes.append({"name": "target_variable", "mode": "read"})
	if impulse_source == ImpulseSource.VARIABLE:
		modes.append({"name": "impulse_variable", "mode": "read"})
	return modes

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
		name = "use_variable_for_target",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if not use_variable_for_target:
		properties.append({
			name = "target_node",
			type = TYPE_NODE_PATH,
			hint = PROPERTY_HINT_NODE_PATH_VALID_TYPES,
			hint_string = "Node",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
	else:
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
		name = "Impulse",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "replace_mode",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Additive,Replace X Only,Replace Y Only",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "impulse_source",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Direct,Variable",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if impulse_source == ImpulseSource.DIRECT:
		properties.append({
			name = "impulse",
			type = TYPE_VECTOR2,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
	else:
		properties.append({
			name = "impulse_variable",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
		properties.append({
			name = "impulse_variable_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
		if impulse_variable_scope == BaseVariable.VariableScope.SCOPE:
			properties.append({
				name = "impulse_scope_source",
				type = TYPE_INT,
				hint = PROPERTY_HINT_ENUM,
				hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})
			if impulse_scope_source == ScopeSource.CUSTOM_ID:
				properties.append({
					name = "impulse_custom_scope_id",
					type = TYPE_STRING,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})
			elif impulse_scope_source == ScopeSource.TARGET_NODE:
				properties.append({
					name = "impulse_target_node_path",
					type = TYPE_NODE_PATH,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})

	return properties

# =============================================
# 属性验证
# =============================================

func _validate_property(property: Dictionary) -> void:
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

	if impulse_source == ImpulseSource.DIRECT:
		if property.name in ["impulse_variable", "impulse_variable_scope", "impulse_scope_source", "impulse_custom_scope_id", "impulse_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		if property.name == "impulse":
			property.usage = PROPERTY_USAGE_NO_EDITOR
		if impulse_variable_scope != BaseVariable.VariableScope.SCOPE:
			if property.name in ["impulse_scope_source", "impulse_custom_scope_id", "impulse_target_node_path"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR
		else:
			var impulse_utils_scope_source = impulse_scope_source as VariableScopeUtils.ScopeSource
			VariableScopeUtils.validate_scope_source_property(property, impulse_utils_scope_source)

## 动态属性设置
func _set(property: StringName, value: Variant) -> bool:
	if property in ["use_variable_for_target", "target_scope", "target_scope_source", "impulse_source", "impulse_variable_scope", "impulse_scope_source", "replace_mode"]:
		set(property, value)
		notify_property_list_changed()
		return true
	return false

# =============================================
# 资源名称和描述
# =============================================

func _update_resource_name():
	var target_str := ""
	if use_variable_for_target:
		if target_variable.is_empty():
			target_str = FuseLocalization.translate("FUSE_INSTRUCTION_ADD_VELOCITY_NO_TARGET")
		else:
			target_str = target_variable
	else:
		target_str = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_INSTRUCTION_ADD_VELOCITY_NO_TARGET")

	var impulse_str := ""
	if impulse_source == ImpulseSource.DIRECT:
		impulse_str = str(impulse)
	else:
		impulse_str = impulse_variable if not impulse_variable.is_empty() else "-"

	resource_name = FuseLocalization.translate_format("FUSE_INSTRUCTION_ADD_VELOCITY_RESOURCE_NAME", {
		"target": target_str,
		"impulse": impulse_str
	})

func get_description() -> String:
	var target_str := ""
	if use_variable_for_target:
		target_str = target_variable
	else:
		target_str = _get_node_display_name(target_node) if not target_node.is_empty() else "-"

	var impulse_str := str(impulse) if impulse_source == ImpulseSource.DIRECT else impulse_variable

	return FuseLocalization.translate_format("FUSE_INSTRUCTION_ADD_VELOCITY_DESC_FORMAT", {
		"target": target_str,
		"impulse": impulse_str
	})

# =============================================
# 执行逻辑
# =============================================

func execute(context: ExecutionContext):
	_start_execution(context)

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
		finished.emit()
		return

	# 验证目标含 velocity 属性（CharacterBody2D/RigidBody2D 等）
	if not ("velocity" in node):
		_log_error_localized("FUSE_ERROR_NO_VELOCITY_PROPERTY", {"node": node.name, "actual_type": node.get_class()})
		set_error_localized("FUSE_ERROR_NO_VELOCITY_PROPERTY", FuseError.ErrorType.RUNTIME_ERROR, {"node": node.name, "actual_type": node.get_class()})
		finished.emit()
		return

	var impulse_value := _get_impulse(context)
	if impulse_value == null:
		finished.emit()
		return

	# 按应用模式写入速度（ADDITIVE 叠加；REPLACE_X/Y 半覆盖——另一轴留给物理）
	var current: Vector2 = node.get("velocity")
	var new_velocity: Vector2
	match replace_mode:
		ReplaceMode.ADDITIVE:
			new_velocity = current + impulse_value
		ReplaceMode.REPLACE_X:
			new_velocity = Vector2(impulse_value.x, current.y)
		ReplaceMode.REPLACE_Y:
			new_velocity = Vector2(current.x, impulse_value.y)
	node.set("velocity", new_velocity)

	_log_info_localized("FUSE_LOG_ADD_VELOCITY", {
		"node": node.name,
		"impulse": str(impulse_value),
		"from": str(current),
		"to": str(new_velocity)
	})
	_on_execution_completed()

## 解析冲量值（VARIABLE 模式读变量；失败返回 null 由调用方报错）
func _get_impulse(context: ExecutionContext) -> Variant:
	if impulse_source == ImpulseSource.DIRECT:
		return impulse

	if impulse_variable.is_empty():
		_log_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", {})
		set_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		return null

	var var_value: Variant
	if impulse_variable_scope == BaseVariable.VariableScope.SCOPE:
		if impulse_scope_source == ScopeSource.NEAREST:
			var_value = VariableOperations.get_variable(context, impulse_variable, BaseVariable.VariableScope.SCOPE, null)
		else:
			var utils_scope_source = impulse_scope_source as VariableScopeUtils.ScopeSource
			var scope_container = VariableScopeUtils.get_scope_container_by_source(
				context,
				utils_scope_source,
				impulse_custom_scope_id,
				impulse_target_node_path
			)
			if scope_container == null:
				_log_error_localized("FUSE_ERROR_SCOPE_CONTAINER_NOT_FOUND", {})
				set_error_localized("FUSE_ERROR_SCOPE_CONTAINER_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {})
				return null
			var_value = scope_container.get_variable(impulse_variable, null)
	else:
		var_value = VariableOperations.get_variable(context, impulse_variable, impulse_variable_scope, null)

	if var_value == null:
		_log_error_localized("FUSE_ERROR_VAR_NOT_FOUND", {"variable": impulse_variable})
		set_error_localized("FUSE_ERROR_VAR_NOT_FOUND", FuseError.ErrorType.VALIDATION_ERROR, {"variable": impulse_variable})
		return null

	if var_value is Vector2:
		return var_value

	_log_error_localized("FUSE_ERROR_IMPULSE_NOT_VECTOR2", {"variable": impulse_variable, "actual_type": type_string(typeof(var_value))})
	set_error_localized("FUSE_ERROR_IMPULSE_NOT_VECTOR2", FuseError.ErrorType.VALIDATION_ERROR, {"variable": impulse_variable, "actual_type": type_string(typeof(var_value))})
	return null

# =============================================
# 验证
# =============================================

func validate() -> Array[String]:
	var errors = super.validate()

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

	if impulse_source == ImpulseSource.DIRECT:
		if impulse == Vector2.ZERO:
			errors.append(FuseLocalization.translate("FUSE_ERROR_IMPULSE_ZERO"))
	else:
		if impulse_variable.is_empty():
			errors.append(FuseLocalization.translate("FUSE_ERROR_VAR_NAME_EMPTY"))
		if impulse_variable_scope == BaseVariable.VariableScope.SCOPE:
			var impulse_utils_scope_source = impulse_scope_source as VariableScopeUtils.ScopeSource
			errors.append_array(VariableScopeUtils.validate_scope_source_params(
				impulse_utils_scope_source,
				impulse_custom_scope_id,
				impulse_target_node_path
			))

	return errors

# =============================================
# 辅助方法
# =============================================

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
