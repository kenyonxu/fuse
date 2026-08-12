@tool
@icon("res://addons/fuse/icons/builtin/Sprite2D.svg")
extends BaseInstruction
class_name AnimatedSprite2DIsPlaying

## 获取 AnimatedSprite2D 是否正在播放
##
## 调用 AnimatedSprite2D 节点的 is_playing 方法，将布尔结果保存到变量。

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

## 保存结果的变量名
var save_to_variable: String = "":
	set(value):
		save_to_variable = value
		_update_resource_name()

## 结果变量作用域
var save_to_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		save_to_scope = value
		_update_resource_name()
		notify_property_list_changed()

## 结果作用域来源（仅当 save_to_scope == SCOPE 时使用）
var save_to_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		save_to_scope_source = value
		_update_resource_name()
		notify_property_list_changed()

## 结果自定义作用域 ID（CUSTOM_ID 模式使用）
var save_to_custom_scope_id: String = "":
	set(value):
		save_to_custom_scope_id = value
		_update_resource_name()

## 结果目标节点路径（TARGET_NODE 模式使用）
var save_to_target_node_path: NodePath = NodePath(""):
	set(value):
		save_to_target_node_path = value
		_update_resource_name()

# =============================================
# 元数据
# =============================================

static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_ANIMATED_SPRITE_2D_IS_PLAYING_NAME"
	metadata.category_key = "FUSE_CATEGORY_ANIMATION"
	metadata.description_key = "FUSE_INSTRUCTION_ANIMATED_SPRITE_2D_IS_PLAYING_DESC"
	metadata.keywords = ["animatedsprite2d", "is_playing", "playing", "sprite", "是否播放", "动画", "精灵"]
	metadata.builtin_icon = "AnimatedSprite2D"
	return metadata

func _setup_metadata():
	pass

func get_variable_modes() -> Array[Dictionary]:
	var modes: Array[Dictionary] = []
	if use_variable_for_target:
		modes.append({"name": "target_variable", "mode": "read"})
	if not save_to_variable.is_empty():
		modes.append({"name": "save_to_variable", "mode": "write"})
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
		name = "Save To",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "save_to_variable",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "save_to_scope",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Local,Scope,Global",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if save_to_scope == BaseVariable.VariableScope.SCOPE:
		properties.append({
			name = "save_to_scope_source",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		if save_to_scope_source == ScopeSource.CUSTOM_ID:
			properties.append({
				name = "save_to_custom_scope_id",
				type = TYPE_STRING,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})
		elif save_to_scope_source == ScopeSource.TARGET_NODE:
			properties.append({
				name = "save_to_target_node_path",
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

	if save_to_scope != BaseVariable.VariableScope.SCOPE:
		if property.name in ["save_to_scope_source", "save_to_custom_scope_id", "save_to_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		var save_utils_scope_source = save_to_scope_source as VariableScopeUtils.ScopeSource
		VariableScopeUtils.validate_scope_source_property(property, save_utils_scope_source)

## 动态属性设置
func _set(property: StringName, value: Variant) -> bool:
	if property in ["use_variable_for_target", "target_scope", "target_scope_source", "save_to_scope", "save_to_scope_source"]:
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
			target_str = FuseLocalization.translate("FUSE_INSTRUCTION_ANIMATED_SPRITE_2D_IS_PLAYING_NO_TARGET")
		else:
			var target_scope_str := VariableScopeUtils.enum_to_string(target_scope).to_upper()
			if target_scope == BaseVariable.VariableScope.SCOPE:
				var target_utils_scope_source = target_scope_source as VariableScopeUtils.ScopeSource
				target_scope_str = VariableScopeUtils.get_scope_source_string(target_utils_scope_source, target_custom_scope_id, target_target_node_path)
			target_str = "%s [%s]" % [target_variable, target_scope_str]
	else:
		target_str = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_INSTRUCTION_ANIMATED_SPRITE_2D_IS_PLAYING_NO_TARGET")

	var save_str := ""
	if save_to_variable.is_empty():
		save_str = FuseLocalization.translate("FUSE_UI_NODE_NOT_SELECTED")
	else:
		var save_scope_str := VariableScopeUtils.enum_to_string(save_to_scope).to_upper()
		if save_to_scope == BaseVariable.VariableScope.SCOPE:
			var save_utils_scope_source = save_to_scope_source as VariableScopeUtils.ScopeSource
			save_scope_str = VariableScopeUtils.get_scope_source_string(save_utils_scope_source, save_to_custom_scope_id, save_to_target_node_path)
		save_str = "%s [%s]" % [save_to_variable, save_scope_str]

	resource_name = FuseLocalization.translate_format("FUSE_INSTRUCTION_ANIMATED_SPRITE_2D_IS_PLAYING_RESOURCE_NAME", {
		"target": target_str,
		"variable": save_str
	})

func get_description() -> String:
	var target_str := ""
	if use_variable_for_target:
		if target_variable.is_empty():
			target_str = FuseLocalization.translate("FUSE_INSTRUCTION_ANIMATED_SPRITE_2D_IS_PLAYING_NO_TARGET")
		else:
			target_str = target_variable
	else:
		target_str = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_INSTRUCTION_ANIMATED_SPRITE_2D_IS_PLAYING_NO_TARGET")

	var save_str := ""
	if save_to_variable.is_empty():
		save_str = FuseLocalization.translate("FUSE_UI_NODE_NOT_SELECTED")
	else:
		save_str = save_to_variable

	return FuseLocalization.translate_format("FUSE_INSTRUCTION_ANIMATED_SPRITE_2D_IS_PLAYING_DESC_FORMAT", {
		"target": target_str,
		"variable": save_str
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
	var sprite := node as AnimatedSprite2D

	if save_to_variable.is_empty():
		_log_error_localized("FUSE_ERROR_RESULT_VARIABLE_EMPTY", {})
		set_error_localized("FUSE_ERROR_RESULT_VARIABLE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	var result := sprite.is_playing()

	match save_to_scope:
		BaseVariable.VariableScope.LOCAL, BaseVariable.VariableScope.GLOBAL:
			VariableOperations.set_variable(context, save_to_variable, save_to_scope, result)
		BaseVariable.VariableScope.SCOPE:
			if save_to_scope_source == ScopeSource.NEAREST:
				VariableOperations.set_variable(context, save_to_variable, BaseVariable.VariableScope.SCOPE, result)
			else:
				var utils_scope_source = save_to_scope_source as VariableScopeUtils.ScopeSource
				var scope_container = VariableScopeUtils.get_scope_container_by_source(context, utils_scope_source, save_to_custom_scope_id, save_to_target_node_path)
				if scope_container == null:
					_log_error_localized("FUSE_ERROR_SCOPE_CONTAINER_NOT_FOUND", {})
					set_error_localized("FUSE_ERROR_SCOPE_CONTAINER_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {})
					finished.emit()
					return
				scope_container.set_variable(save_to_variable, result)

	_log_info_localized("FUSE_LOG_ANIMATED_SPRITE_2D_IS_PLAYING", {"node": node.name, "value": result})
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

	if save_to_variable.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_RESULT_VARIABLE_EMPTY"))

	if save_to_scope == BaseVariable.VariableScope.SCOPE:
		var save_utils_scope_source = save_to_scope_source as VariableScopeUtils.ScopeSource
		errors.append_array(VariableScopeUtils.validate_scope_source_params(
			save_utils_scope_source,
			save_to_custom_scope_id,
			save_to_target_node_path
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
