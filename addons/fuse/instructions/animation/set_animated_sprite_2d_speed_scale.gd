@tool
@icon("res://addons/fuse/icons/builtin/ViewportSpeed.png")
extends BaseInstruction
class_name SetAnimatedSprite2DSpeedScale

## 设置 AnimatedSprite2D 播放速度缩放
##
## 设置 AnimatedSprite2D 节点的 speed_scale 属性，支持直接输入值或从变量读取。

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

## 目标 AnimatedSprite2D 节点路径
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

## 是否使用变量控制 speed_scale 值
var use_variable_for_speed: bool = false:
	set(value):
		use_variable_for_speed = value
		notify_property_list_changed()
		_update_resource_name()

## speed_scale 直接值
var speed_scale: float = 1.0:
	set(value):
		speed_scale = value
		_update_resource_name()

## speed_scale 变量名
var speed_variable: String = "":
	set(value):
		speed_variable = value
		_update_resource_name()

## speed_scale 变量作用域
var speed_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		speed_scope = value
		_update_resource_name()
		notify_property_list_changed()

## speed_scale 作用域来源（仅当 speed_scope == SCOPE 时使用）
var speed_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		speed_scope_source = value
		_update_resource_name()
		notify_property_list_changed()

## speed_scale 自定义作用域 ID（CUSTOM_ID 模式使用）
var speed_custom_scope_id: String = "":
	set(value):
		speed_custom_scope_id = value
		_update_resource_name()

## speed_scale 目标节点路径（TARGET_NODE 模式使用）
var speed_target_node_path: NodePath = NodePath(""):
	set(value):
		speed_target_node_path = value
		_update_resource_name()

# =============================================
# 元数据
# =============================================

static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_SET_ANIMATED_SPRITE_2D_SPEED_SCALE_NAME"
	metadata.category_key = "FUSE_CATEGORY_ANIMATION"
	metadata.description_key = "FUSE_INSTRUCTION_SET_ANIMATED_SPRITE_2D_SPEED_SCALE_DESC"
	metadata.keywords = ["animatedsprite2d", "speed_scale", "speed", "set", "速度", "设置", "动画", "精灵"]
	metadata.builtin_icon = "ViewportSpeed"
	return metadata

func _setup_metadata():
	pass

func get_variable_modes() -> Array[Dictionary]:
	var modes: Array[Dictionary] = []
	if use_variable_for_target:
		modes.append({"name": "target_variable", "mode": "read"})
	if use_variable_for_speed:
		modes.append({"name": "speed_variable", "mode": "read"})
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
			hint_string = "AnimatedSprite2D",
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
		name = "Speed Scale",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "use_variable_for_speed",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if not use_variable_for_speed:
		properties.append({
			name = "speed_scale",
			type = TYPE_FLOAT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.01,10,0.01,or_greater",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
	else:
		properties.append({
			name = "speed_variable",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		properties.append({
			name = "speed_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		if speed_scope == BaseVariable.VariableScope.SCOPE:
			properties.append({
				name = "speed_scope_source",
				type = TYPE_INT,
				hint = PROPERTY_HINT_ENUM,
				hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

			if speed_scope_source == ScopeSource.CUSTOM_ID:
				properties.append({
					name = "speed_custom_scope_id",
					type = TYPE_STRING,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})
			elif speed_scope_source == ScopeSource.TARGET_NODE:
				properties.append({
					name = "speed_target_node_path",
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

	if not use_variable_for_speed:
		if property.name in ["speed_variable", "speed_scope", "speed_scope_source", "speed_custom_scope_id", "speed_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		if property.name == "speed_scale":
			property.usage = PROPERTY_USAGE_NO_EDITOR

		if speed_scope != BaseVariable.VariableScope.SCOPE:
			if property.name in ["speed_scope_source", "speed_custom_scope_id", "speed_target_node_path"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR
		else:
			var speed_utils_scope_source = speed_scope_source as VariableScopeUtils.ScopeSource
			VariableScopeUtils.validate_scope_source_property(property, speed_utils_scope_source)

## 动态属性设置
func _set(property: StringName, value: Variant) -> bool:
	if property in ["use_variable_for_target", "target_scope", "target_scope_source", "use_variable_for_speed", "speed_scope", "speed_scope_source"]:
		set(property, value)
		notify_property_list_changed()
		return true
	return false

# =============================================
# 资源名称和描述
# =============================================

func _update_resource_name():
	var parts: Array[String] = []
	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_SET_ANIMATED_SPRITE_2D_SPEED_SCALE_SHORT"))

	var target_str := ""
	if use_variable_for_target:
		if target_variable.is_empty():
			target_str = FuseLocalization.translate("FUSE_INSTRUCTION_SET_ANIMATED_SPRITE_2D_SPEED_SCALE_NO_TARGET")
		else:
			var target_scope_str := VariableScopeUtils.enum_to_string(target_scope).to_upper()
			if target_scope == BaseVariable.VariableScope.SCOPE:
				var target_utils_scope_source = target_scope_source as VariableScopeUtils.ScopeSource
				target_scope_str = VariableScopeUtils.get_scope_source_string(target_utils_scope_source, target_custom_scope_id, target_target_node_path)
			target_str = "%s [%s]" % [target_variable, target_scope_str]
	else:
		target_str = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_INSTRUCTION_SET_ANIMATED_SPRITE_2D_SPEED_SCALE_NO_TARGET")
	parts.append("→ %s" % target_str)

	var speed_str := ""
	if use_variable_for_speed:
		if speed_variable.is_empty():
			speed_str = FuseLocalization.translate("FUSE_VALUE_VARIABLE_EMPTY")
		else:
			var speed_scope_str := VariableScopeUtils.enum_to_string(speed_scope).to_upper()
			if speed_scope == BaseVariable.VariableScope.SCOPE:
				var speed_utils_scope_source = speed_scope_source as VariableScopeUtils.ScopeSource
				speed_scope_str = VariableScopeUtils.get_scope_source_string(speed_utils_scope_source, speed_custom_scope_id, speed_target_node_path)
			speed_str = "%s [%s]" % [speed_variable, speed_scope_str]
	else:
		speed_str = FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_ANIMATED_SPRITE_2D_SPEED_SCALE_VALUE", {"speed": speed_scale})
	parts.append("(%s)" % speed_str)

	resource_name = " ".join(parts)

func get_description() -> String:
	var target_str := ""
	if use_variable_for_target:
		if target_variable.is_empty():
			target_str = FuseLocalization.translate("FUSE_INSTRUCTION_SET_ANIMATED_SPRITE_2D_SPEED_SCALE_NO_TARGET")
		else:
			target_str = target_variable
	else:
		target_str = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_INSTRUCTION_SET_ANIMATED_SPRITE_2D_SPEED_SCALE_NO_TARGET")

	var speed_str := ""
	if use_variable_for_speed:
		if speed_variable.is_empty():
			speed_str = FuseLocalization.translate("FUSE_VALUE_VARIABLE_EMPTY")
		else:
			speed_str = speed_variable
	else:
		speed_str = str(speed_scale)

	return FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_ANIMATED_SPRITE_2D_SPEED_SCALE_DESC_FORMAT", {
		"target": target_str,
		"speed": speed_str
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

	if not node is AnimatedSprite2D:
		_log_error_localized("FUSE_ERROR_NOT_ANIMATED_SPRITE_2D", {"node": node.name, "actual_type": node.get_class()})
		set_error_localized("FUSE_ERROR_NOT_ANIMATED_SPRITE_2D", FuseError.ErrorType.RUNTIME_ERROR, {"node": node.name, "actual_type": node.get_class()})
		finished.emit()
		return

	var speed_value := speed_scale
	if use_variable_for_speed:
		speed_value = _resolve_float_variable(
			context,
			speed_variable,
			speed_scope,
			speed_scope_source,
			speed_custom_scope_id,
			speed_target_node_path,
			"FUSE_ERROR_SPEED_VAR_NOT_FOUND"
		)
		if speed_value == null:
			finished.emit()
			return

	if speed_value <= 0.0:
		_log_error_localized("FUSE_ERROR_SPEED_MUST_BE_POSITIVE", {})
		set_error_localized("FUSE_ERROR_SPEED_MUST_BE_POSITIVE", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	node.speed_scale = speed_value
	_log_info_localized("FUSE_LOG_SET_ANIMATED_SPRITE_2D_SPEED_SCALE", {"node": node.name, "speed": speed_value})
	_on_execution_completed()

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

	if use_variable_for_speed:
		if speed_variable.is_empty():
			errors.append(FuseLocalization.translate("FUSE_ERROR_SPEED_VAR_NAME_EMPTY"))
		if speed_scope == BaseVariable.VariableScope.SCOPE:
			var speed_utils_scope_source = speed_scope_source as VariableScopeUtils.ScopeSource
			errors.append_array(VariableScopeUtils.validate_scope_source_params(
				speed_utils_scope_source,
				speed_custom_scope_id,
				speed_target_node_path
			))
	else:
		if speed_scale <= 0.0:
			errors.append(FuseLocalization.translate("FUSE_ERROR_SPEED_MUST_BE_POSITIVE"))

	return errors

# =============================================
# 辅助方法
# =============================================

func _resolve_float_variable(
	context: ExecutionContext,
	variable_name: String,
	variable_scope: BaseVariable.VariableScope,
	scope_source: ScopeSource,
	custom_scope_id: String,
	target_node_path: NodePath,
	not_found_error_key: String
) -> Variant:
	if variable_name.is_empty():
		_log_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", {})
		set_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		return null

	var value: Variant = null

	match variable_scope:
		BaseVariable.VariableScope.LOCAL, BaseVariable.VariableScope.GLOBAL:
			if not VariableOperations.has_variable(context, variable_name, variable_scope):
				_log_error_localized(not_found_error_key, {"variable": variable_name})
				set_error_localized(not_found_error_key, FuseError.ErrorType.RUNTIME_ERROR, {"variable": variable_name})
				return null
			value = VariableOperations.get_variable(context, variable_name, variable_scope, null)
		BaseVariable.VariableScope.SCOPE:
			if scope_source == ScopeSource.NEAREST:
				if not VariableOperations.has_variable(context, variable_name, variable_scope):
					_log_error_localized(not_found_error_key, {"variable": variable_name})
					set_error_localized(not_found_error_key, FuseError.ErrorType.RUNTIME_ERROR, {"variable": variable_name})
					return null
				value = VariableOperations.get_variable(context, variable_name, variable_scope, null)
			else:
				var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
				var scope_container = VariableScopeUtils.get_scope_container_by_source(context, utils_scope_source, custom_scope_id, target_node_path)
				if scope_container == null:
					_log_error_localized("FUSE_ERROR_SCOPE_CONTAINER_NOT_FOUND", {})
					set_error_localized("FUSE_ERROR_SCOPE_CONTAINER_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {})
					return null
				value = scope_container.get_variable(variable_name, null)

	if value == null:
		_log_error_localized(not_found_error_key, {"variable": variable_name})
		set_error_localized(not_found_error_key, FuseError.ErrorType.RUNTIME_ERROR, {"variable": variable_name})
		return null

	return float(value)

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
