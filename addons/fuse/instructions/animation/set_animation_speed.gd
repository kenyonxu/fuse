@tool
@icon("res://addons/fuse/icons/builtin/ViewportSpeed.png")
extends BaseInstruction
class_name SetAnimationSpeed


## 作用域来源枚举
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

## 设置 AnimationPlayer 的播放速度

# 目标 AnimationPlayer 节点路径
var target_node: NodePath = NodePath("")

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

# 播放速度（1.0 = 正常，0.5 = 半速，2.0 = 双倍速）
var speed_scale: float = 1.0

## 获取指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_SET_ANIMATION_SPEED_NAME"
	metadata.category_key = "FUSE_CATEGORY_ANIMATION"
	metadata.description_key = "FUSE_INSTRUCTION_SET_ANIMATION_SPEED_DESC"
	metadata.keywords = ["animation", "speed", "scale", "AnimationPlayer", "动画", "速度", "播放速度"]
	metadata.builtin_icon = "ViewportSpeed"
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
		name = "Animation",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})


	# 是否从变量获取目标节点
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
			hint_string = "AnimationPlayer",
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
		name = "Speed",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "speed_scale",
		type = TYPE_FLOAT,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "0.01,10,0.01,or_greater",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 更新资源名称
func _update_resource_name():
	var parts := []

	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_SET_ANIMATION_SPEED_SHORT"))

	if not target_node.is_empty():
		parts.append("→ %s" % _get_node_display_name(target_node))
	else:
		parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_SET_ANIMATION_SPEED_NO_TARGET"))

	parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_ANIMATION_SPEED_VALUE", {"speed": speed_scale}))

	resource_name = " ".join(parts)

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	# 验证速度值
	if speed_scale <= 0:
		_log_error_localized("FUSE_ERROR_SPEED_MUST_BE_POSITIVE", {})
		set_error_localized("FUSE_ERROR_SPEED_MUST_BE_POSITIVE", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

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
		finished.emit()
		return

	# 验证节点类型
	if not node is AnimationPlayer:
		_log_error_localized("FUSE_ERROR_NOT_ANIMATION_PLAYER", {})
		set_error_localized("FUSE_ERROR_NOT_ANIMATION_PLAYER", FuseError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	var anim_player := node as AnimationPlayer

	# 设置播放速度
	anim_player.speed_scale = speed_scale
	_log_info_localized("FUSE_LOG_SET_ANIMATION_SPEED", {"node": anim_player.name, "speed": str(speed_scale)})

	_on_execution_completed()

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()
	# 验证 目标节点
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


	if speed_scale <= 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_SPEED_MUST_BE_POSITIVE"))

	return errors

## 属性验证
func _validate_property(property: Dictionary) -> void:
	# 控制目标节点相关属性可见性
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
## 动态属性设置
func _set(property: StringName, value: Variant) -> bool:
	if property in ["use_variable_for_target", "target_scope", "target_scope_source"]:
		set(property, value)
		notify_property_list_changed()
		return true
	return false
## 获取指令描述
func get_description() -> String:
	var target_str := ""
	if use_variable_for_target:
		if target_variable.is_empty():
			target_str = FuseLocalization.translate("FUSE_INSTRUCTION_SET_ANIMATION_SPEED_NO_TARGET")
		else:
			var target_scope_str := VariableScopeUtils.enum_to_string(target_scope).to_upper()
			if target_scope == BaseVariable.VariableScope.SCOPE:
				var target_utils_scope_source = target_scope_source as VariableScopeUtils.ScopeSource
				target_scope_str = VariableScopeUtils.get_scope_source_string(target_utils_scope_source, target_custom_scope_id, target_target_node_path)
			target_str = "%s [%s]" % [target_variable, target_scope_str]
	else:
		target_str = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_INSTRUCTION_SET_ANIMATION_SPEED_NO_TARGET")
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_ANIMATION_SPEED_DESC_FORMAT", {"target": target_str, "speed": speed_scale})

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

