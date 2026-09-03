@tool
@icon("res://addons/fuse/icons/builtin/Sprite2D.svg")
extends BaseInstruction
class_name AnimatedSprite2DPlay

## 播放 AnimatedSprite2D 动画
##
## 调用 AnimatedSprite2D 节点的 play 方法，支持直接指定动画名称或从变量读取。

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

## 是否使用变量控制动画名称
var use_variable_for_name: bool = false:
	set(value):
		use_variable_for_name = value
		notify_property_list_changed()
		_update_resource_name()

## 动画名称（直接值）
var animation_name: String = "":
	set(value):
		animation_name = value
		_update_resource_name()

## 动画名称变量名
var name_variable: String = "":
	set(value):
		name_variable = value
		_update_resource_name()

## 动画名称变量作用域
var name_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		name_scope = value
		_update_resource_name()
		notify_property_list_changed()

## 动画名称作用域来源（仅当 name_scope == SCOPE 时使用）
var name_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		name_scope_source = value
		_update_resource_name()
		notify_property_list_changed()

## 动画名称自定义作用域 ID（CUSTOM_ID 模式使用）
var name_custom_scope_id: String = "":
	set(value):
		name_custom_scope_id = value
		_update_resource_name()

## 动画名称目标节点路径（TARGET_NODE 模式使用）
var name_target_node_path: NodePath = NodePath(""):
	set(value):
		name_target_node_path = value
		_update_resource_name()

## 播放速度缩放（1.0 = 正常）
var custom_speed: float = 1.0:
	set(value):
		custom_speed = value
		_update_resource_name()

## 是否从结尾反向播放
var from_end: bool = false:
	set(value):
		from_end = value
		_update_resource_name()

# =============================================
# 元数据
# =============================================

## 获取指令元数据（必需）
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_ANIMATED_SPRITE_2D_PLAY_NAME"
	metadata.category_key = "FUSE_CATEGORY_ANIMATION"
	metadata.description_key = "FUSE_INSTRUCTION_ANIMATED_SPRITE_2D_PLAY_DESC"
	metadata.keywords = ["animatedsprite2d", "play", "animation", "sprite", "播放", "动画", "精灵"]
	metadata.builtin_icon = "AnimatedSprite2D"
	return metadata

func _setup_metadata():
	pass

## 声明变量读写模式
func get_variable_modes() -> Array[Dictionary]:
	var modes: Array[Dictionary] = []
	if use_variable_for_target:
		modes.append({"name": "target_variable", "mode": "read"})
	if use_variable_for_name:
		modes.append({"name": "name_variable", "mode": "read"})
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
		name = "Animation",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "use_variable_for_name",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if not use_variable_for_name:
		properties.append({
			name = "animation_name",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
	else:
		properties.append({
			name = "name_variable",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		properties.append({
			name = "name_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		if name_scope == BaseVariable.VariableScope.SCOPE:
			properties.append({
				name = "name_scope_source",
				type = TYPE_INT,
				hint = PROPERTY_HINT_ENUM,
				hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

			if name_scope_source == ScopeSource.CUSTOM_ID:
				properties.append({
					name = "name_custom_scope_id",
					type = TYPE_STRING,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})
			elif name_scope_source == ScopeSource.TARGET_NODE:
				properties.append({
					name = "name_target_node_path",
					type = TYPE_NODE_PATH,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})

	properties.append({
		name = "Playback",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "custom_speed",
		type = TYPE_FLOAT,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "0.01,10,0.01,or_greater",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "from_end",
		type = TYPE_BOOL,
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

	if not use_variable_for_name:
		if property.name in ["name_variable", "name_scope", "name_scope_source", "name_custom_scope_id", "name_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		if property.name == "animation_name":
			property.usage = PROPERTY_USAGE_NO_EDITOR

		if name_scope != BaseVariable.VariableScope.SCOPE:
			if property.name in ["name_scope_source", "name_custom_scope_id", "name_target_node_path"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR
		else:
			var name_utils_scope_source = name_scope_source as VariableScopeUtils.ScopeSource
			VariableScopeUtils.validate_scope_source_property(property, name_utils_scope_source)

## 动态属性设置
func _set(property: StringName, value: Variant) -> bool:
	if property in ["use_variable_for_target", "target_scope", "target_scope_source", "use_variable_for_name", "name_scope", "name_scope_source"]:
		set(property, value)
		notify_property_list_changed()
		return true
	return false

# =============================================
# 资源名称和描述
# =============================================

func _update_resource_name():
	var parts: Array[String] = []
	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_ANIMATED_SPRITE_2D_PLAY_SHORT"))

	var target_str := ""
	if use_variable_for_target:
		if target_variable.is_empty():
			target_str = FuseLocalization.translate("FUSE_INSTRUCTION_ANIMATED_SPRITE_2D_PLAY_NO_TARGET")
		else:
			var target_scope_str := VariableScopeUtils.enum_to_string(target_scope).to_upper()
			if target_scope == BaseVariable.VariableScope.SCOPE:
				var target_utils_scope_source = target_scope_source as VariableScopeUtils.ScopeSource
				target_scope_str = VariableScopeUtils.get_scope_source_string(target_utils_scope_source, target_custom_scope_id, target_target_node_path)
			target_str = "%s [%s]" % [target_variable, target_scope_str]
	else:
		target_str = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_INSTRUCTION_ANIMATED_SPRITE_2D_PLAY_NO_TARGET")
	parts.append("→ %s" % target_str)

	var name_str := ""
	if use_variable_for_name:
		if name_variable.is_empty():
			name_str = FuseLocalization.translate("FUSE_INSTRUCTION_ANIMATED_SPRITE_2D_PLAY_NO_ANIMATION")
		else:
			var name_scope_str := VariableScopeUtils.enum_to_string(name_scope).to_upper()
			if name_scope == BaseVariable.VariableScope.SCOPE:
				var name_utils_scope_source = name_scope_source as VariableScopeUtils.ScopeSource
				name_scope_str = VariableScopeUtils.get_scope_source_string(name_utils_scope_source, name_custom_scope_id, name_target_node_path)
			name_str = "%s [%s]" % [name_variable, name_scope_str]
	else:
		name_str = animation_name if not animation_name.is_empty() else FuseLocalization.translate("FUSE_INSTRUCTION_ANIMATED_SPRITE_2D_PLAY_NO_ANIMATION")
	parts.append("'%s'" % name_str)

	if custom_speed != 1.0:
		parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_ANIMATED_SPRITE_2D_PLAY_WITH_SPEED", {"speed": custom_speed}))

	if from_end:
		parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_ANIMATED_SPRITE_2D_PLAY_FROM_END"))

	resource_name = " ".join(parts)

func get_description() -> String:
	var options: Array[String] = []
	if custom_speed != 1.0:
		options.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_ANIMATED_SPRITE_2D_PLAY_SPEED", {"speed": custom_speed}))
	if from_end:
		options.append(FuseLocalization.translate("FUSE_INSTRUCTION_ANIMATED_SPRITE_2D_PLAY_REVERSE"))

	var options_str := ""
	if options.size() > 0:
		options_str = " (" + ", ".join(options) + ")"

	var name_str := ""
	if use_variable_for_name:
		if name_variable.is_empty():
			name_str = FuseLocalization.translate("FUSE_INSTRUCTION_ANIMATED_SPRITE_2D_PLAY_NO_ANIMATION")
		else:
			name_str = name_variable
	else:
		name_str = animation_name if not animation_name.is_empty() else FuseLocalization.translate("FUSE_INSTRUCTION_ANIMATED_SPRITE_2D_PLAY_NO_ANIMATION")

	return FuseLocalization.translate_format("FUSE_INSTRUCTION_ANIMATED_SPRITE_2D_PLAY_DESC_FORMAT", {"animation": name_str, "options": options_str})

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

	var sprite := node as AnimatedSprite2D

	var animation_name_val := animation_name
	if use_variable_for_name:
		animation_name_val = _resolve_string_variable(
			context,
			name_variable,
			name_scope,
			name_scope_source,
			name_custom_scope_id,
			name_target_node_path,
			"FUSE_ERROR_ANIMATION_NAME_VAR_NOT_FOUND"
		)
		if animation_name_val == null:
			finished.emit()
			return

	if custom_speed <= 0.0:
		_log_error_localized("FUSE_ERROR_INVALID_SPEED", {})
		set_error_localized("FUSE_ERROR_INVALID_SPEED", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	if from_end:
		sprite.play_backwards(animation_name_val)
		_log_info("反向播放动画 '%s'，速度 %.2fx" % [animation_name_val, custom_speed])
	else:
		sprite.play(animation_name_val, custom_speed)
		_log_info("播放动画 '%s'，速度 %.2fx" % [animation_name_val, custom_speed])

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

	if use_variable_for_name:
		if name_variable.is_empty():
			errors.append(FuseLocalization.translate("FUSE_ERROR_ANIMATION_NAME_VAR_NAME_EMPTY"))
		if name_scope == BaseVariable.VariableScope.SCOPE:
			var name_utils_scope_source = name_scope_source as VariableScopeUtils.ScopeSource
			errors.append_array(VariableScopeUtils.validate_scope_source_params(
				name_utils_scope_source,
				name_custom_scope_id,
				name_target_node_path
			))

	if custom_speed <= 0.0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_INVALID_SPEED"))

	return errors

# =============================================
# 辅助方法
# =============================================

func _resolve_string_variable(
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

	return str(value)

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
