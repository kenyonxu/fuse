@tool
@icon("res://addons/fuse/icons/builtin/KeyPosition.png")
extends BaseInstruction
class_name GetPosition

## 获取节点的位置（支持 2D/3D）
##
## 重构变量系统: 2026-02-14 - 使用 VariableOperations 统一变量访问
## 支持 ScopeSource 架构

## 作用域来源枚举
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

## 目标节点路径
var target: NodePath = NodePath(""):
	set(value):
		target = value
		_update_resource_name()

## 是否使用变量获取目标节点
var use_variable: bool = false:
	set(value):
		use_variable = value
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

## 保存到的变量名
var save_to_variable: String = "":
	set(value):
		save_to_variable = value
		_update_resource_name()

## 保存到的变量作用域
var save_to_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		save_to_scope = value
		_update_resource_name()
		notify_property_list_changed()

## 保存作用域来源（仅当 save_to_scope == SCOPE 时使用）
var scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		scope_source = value
		_update_resource_name()
		notify_property_list_changed()

## 保存自定义作用域 ID（CUSTOM_ID 模式使用）
var custom_scope_id: String = "":
	set(value):
		custom_scope_id = value
		_update_resource_name()

## 保存目标节点路径（TARGET_NODE 模式使用）
var save_target_node_path: NodePath = NodePath(""):
	set(value):
		save_target_node_path = value
		_update_resource_name()

## 是否使用全局坐标
var use_global_position: bool = true:
	set(value):
		use_global_position = value
		_update_resource_name()

## 获取指令元数据（用于指令选择器）
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_GET_POSITION_NAME"
	metadata.category_key = "FUSE_CATEGORY_TRANSFORM"
	metadata.description_key = "FUSE_INSTRUCTION_GET_POSITION_DESC"
	metadata.keywords = ["position", "get", "location", "transform", "获取位置", "读取位置", "坐标"]
	metadata.builtin_icon = "KeyPosition"
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

## 声明变量读写模式（target=read 节点路径, save_to=write）
func get_variable_modes() -> Array[Dictionary]:
	return [
		{"name": "target_variable", "mode": "read"},
		{"name": "save_to_variable", "mode": "write"},
	]

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	# Target 分类
	properties.append({
		name = "Target",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 是否使用变量获取目标节点
	properties.append({
		name = "use_variable",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 根据 use_variable 显示不同的属性
	if not use_variable:
		# 直接指定节点路径
		properties.append({
			name = "target",
			type = TYPE_NODE_PATH,
			hint = PROPERTY_HINT_NODE_PATH_VALID_TYPES,
			hint_string = "Node2D,Node3D",
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

		# 仅当 target_scope == SCOPE 时显示 target_scope_source 相关属性
		if target_scope == BaseVariable.VariableScope.SCOPE:
			properties.append({
				name = "target_scope_source",
				type = TYPE_INT,
				hint = PROPERTY_HINT_ENUM,
				hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

			# 根据 target_scope_source 添加额外属性
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

	# Save To 分类
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

	# 仅当 save_to_scope == SCOPE 时显示 scope_source 相关属性
	if save_to_scope == BaseVariable.VariableScope.SCOPE:
		properties.append({
			name = "scope_source",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 根据 scope_source 添加额外属性
		if scope_source == ScopeSource.CUSTOM_ID:
			properties.append({
				name = "custom_scope_id",
				type = TYPE_STRING,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})
		elif scope_source == ScopeSource.TARGET_NODE:
			properties.append({
				name = "save_target_node_path",
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
		name = "use_global_position",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 更新资源名称
func _update_resource_name():
	var parts := []

	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_GET_POSITION_BASE"))

	# 目标节点部分
	if use_variable:
		if target_variable.is_empty():
			parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_GET_POSITION_FROM_VARIABLE_EMPTY"))
		else:
			var scope_str = VariableScopeUtils.enum_to_string(target_scope).to_upper()
			parts.append("%s [%s]" % [target_variable, scope_str])
	else:
		if not target.is_empty():
			parts.append(_get_node_display_name(target))
		else:
			parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_GET_POSITION_NO_TARGET"))

	parts.append("→")

	# 保存变量部分
	if save_to_variable.is_empty():
		parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_GET_POSITION_NO_VARIABLE"))
	else:
		var scope_str = VariableScopeUtils.enum_to_string(save_to_scope).to_upper()
		parts.append("%s [%s]" % [save_to_variable, scope_str])

		# 如果是 SCOPE 作用域，添加 ScopeSource 信息
		if save_to_scope == BaseVariable.VariableScope.SCOPE:
			var scope_source_str = _get_scope_source_string(scope_source, custom_scope_id, save_target_node_path)
			parts.append("[%s]" % scope_source_str)

	resource_name = " ".join(parts)

## 获取作用域来源字符串
func _get_scope_source_string(source: ScopeSource, custom_id: String, node_path: NodePath) -> String:
	var utils_scope_source = source as VariableScopeUtils.ScopeSource
	return VariableScopeUtils.get_scope_source_string(
		utils_scope_source,
		custom_id,
		node_path
	)

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	# 获取目标节点
	var target_node: Node = null

	if use_variable:
		# 从变量获取节点
		if target_variable.is_empty():
			_log_error_localized("FUSE_ERROR_TARGET_VARIABLE_EMPTY", {})
			set_error_localized("FUSE_ERROR_TARGET_VARIABLE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
			finished.emit()
			return

		var node_value = VariableOperations.get_variable(
			context,
			target_variable,
			target_scope,
			null
		)

		if node_value == null and not VariableOperations.has_variable(context, target_variable, target_scope):
			_log_error_localized("FUSE_ERROR_VAR_NOT_FOUND", {"name": target_variable})
			set_error_localized("FUSE_ERROR_VAR_NOT_FOUND", FuseError.ErrorType.VALIDATION_ERROR, {"name": target_variable})
			finished.emit()
			return

		# 支持多种类型：Node、String（节点路径）、NodePath
		if node_value is Node:
			target_node = node_value
		elif node_value is String or node_value is NodePath:
			# 从字符串或 NodePath 解析节点
			var node_path = NodePath(node_value)
			target_node = context.get_node(node_path)
			if not target_node:
				_log_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(node_value)})
				set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"node": str(node_value)})
				finished.emit()
				return
		else:
			_log_error_localized("FUSE_ERROR_VAR_TYPE_NOT_NODE_OR_PATH", {"variable": target_variable, "actual_type": type_string(typeof(node_value))})
			set_error_localized("FUSE_ERROR_VAR_TYPE_NOT_NODE_OR_PATH", FuseError.ErrorType.VALIDATION_ERROR, {"variable": target_variable, "actual_type": type_string(typeof(node_value))})
			finished.emit()
			return
	else:
		# 直接从路径获取节点
		if target.is_empty():
			_log_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", {})
			set_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
			finished.emit()
			return

		target_node = context.get_node(target)
		if not target_node:
			_log_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(target)})
			set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"node": str(target)})
			finished.emit()
			return

	# 验证节点类型
	if not (target_node is Node2D or target_node is Node3D):
		var type_str = target_node.get_class()
		_log_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", {"node": target_node.name, "actual_type": type_str})
		set_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", FuseError.ErrorType.RUNTIME_ERROR, {"node": target_node.name, "actual_type": type_str})
		finished.emit()
		return

	# 获取位置
	var position_value: Variant

	if target_node is Node2D:
		if use_global_position:
			position_value = target_node.global_position
		else:
			position_value = target_node.position
	else:  # Node3D
		if use_global_position:
			position_value = target_node.global_position
		else:
			position_value = target_node.position

	# 保存到变量
	if save_to_variable.is_empty():
		_log_error_localized("FUSE_ERROR_SAVE_VARIABLE_EMPTY", {})
		set_error_localized("FUSE_ERROR_SAVE_VARIABLE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 根据 save_to_scope 保存变量
	match save_to_scope:
		BaseVariable.VariableScope.LOCAL:
			VariableOperations.set_variable(context, save_to_variable, BaseVariable.VariableScope.LOCAL, position_value)

		BaseVariable.VariableScope.SCOPE:
			if scope_source == ScopeSource.NEAREST:
				VariableOperations.set_variable(context, save_to_variable, BaseVariable.VariableScope.SCOPE, position_value)
			else:
				var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
				var scope_container = VariableScopeUtils.get_scope_container_by_source(
					context,
					utils_scope_source,
					custom_scope_id,
					save_target_node_path
				)

				if scope_container == null:
					_log_error_localized("FUSE_ERROR_SCOPE_CONTAINER_NOT_FOUND", {})
					set_error_localized("FUSE_ERROR_SCOPE_CONTAINER_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {})
					finished.emit()
					return

				scope_container.set_variable(save_to_variable, position_value)

		BaseVariable.VariableScope.GLOBAL:
			VariableOperations.set_variable(context, save_to_variable, BaseVariable.VariableScope.GLOBAL, position_value)

	# 记录日志
	if target_node is Node2D:
		_log_info_localized("FUSE_LOG_GET_POSITION_SUCCESS", {
			"node": target_node.name,
			"x": str(position_value.x),
			"y": str(position_value.y)
		})
	else:
		_log_info_localized("FUSE_LOG_GET_POSITION_SUCCESS_3D", {
			"node": target_node.name,
			"x": str(position_value.x),
			"y": str(position_value.y),
			"z": str(position_value.z)
		})

	_on_execution_completed()

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()

	# 验证保存变量名
	if save_to_variable.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_SAVE_VARIABLE_NAME_EMPTY"))

	# 验证目标节点设置
	if not use_variable:
		if target.is_empty():
			errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))
	else:
		if target_variable.is_empty():
			errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_VARIABLE_EMPTY"))

		# 验证 target_scope == SCOPE 时的 ScopeSource 参数
		if target_scope == BaseVariable.VariableScope.SCOPE:
			var utils_scope_source = target_scope_source as VariableScopeUtils.ScopeSource
			errors.append_array(VariableScopeUtils.validate_scope_source_params(
				utils_scope_source,
				target_custom_scope_id,
				target_target_node_path
			))

	# 验证 ScopeVariableManager（如果需要）
	if target_scope == BaseVariable.VariableScope.SCOPE or save_to_scope == BaseVariable.VariableScope.SCOPE:
		var manager = ScopeVariableManager.get_instance()
		if manager == null:
			errors.append(FuseLocalization.translate("FUSE_ERROR_SCOPE_MANAGER_NOT_FOUND"))

	# 验证 save_to_scope == SCOPE 时的 ScopeSource 参数
	if save_to_scope == BaseVariable.VariableScope.SCOPE:
		var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
		errors.append_array(VariableScopeUtils.validate_scope_source_params(
			utils_scope_source,
			custom_scope_id,
			save_target_node_path
		))

	return errors

## 属性验证
func _validate_property(property: Dictionary) -> void:
	# 控制目标节点相关属性的可见性
	if not use_variable:
		if property.name in ["target_variable", "target_scope", "target_scope_source", "target_custom_scope_id", "target_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		if property.name == "target":
			property.usage = PROPERTY_USAGE_NO_EDITOR

		# 控制 target_scope_source 相关属性
		if target_scope != BaseVariable.VariableScope.SCOPE:
			if property.name in ["target_scope_source", "target_custom_scope_id", "target_target_node_path"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR
		else:
			var utils_scope_source = target_scope_source as VariableScopeUtils.ScopeSource
			VariableScopeUtils.validate_scope_source_property(property, utils_scope_source)

	# 控制保存作用域相关属性的可见性
	if save_to_scope != BaseVariable.VariableScope.SCOPE:
		if property.name in ["scope_source", "custom_scope_id", "save_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
		VariableScopeUtils.validate_scope_source_property(property, utils_scope_source)

## 动态属性设置
func _set(property: StringName, value: Variant) -> bool:
	if property in ["use_variable", "target_scope", "save_to_scope", "target_scope_source", "scope_source", "use_global_position"]:
		set(property, value)
		notify_property_list_changed()
		return true
	return false

## 获取指令描述
func get_description() -> String:
	var target_desc := ""
	var save_desc := ""

	# 获取目标描述
	if use_variable:
		if target_variable.is_empty():
			target_desc = FuseLocalization.translate("FUSE_INSTRUCTION_GET_POSITION_TARGET_VARIABLE_EMPTY")
		else:
			var scope_str = VariableScopeUtils.enum_to_string(target_scope).to_upper()
			target_desc = FuseLocalization.translate_format("FUSE_INSTRUCTION_GET_POSITION_TARGET_VARIABLE", {
				"variable": "%s [%s]" % [target_variable, scope_str]
			})
	else:
		if target.is_empty():
			target_desc = FuseLocalization.translate("FUSE_INSTRUCTION_GET_POSITION_NO_TARGET")
		else:
			target_desc = FuseLocalization.translate_format("FUSE_INSTRUCTION_GET_POSITION_TARGET_NODE", {
				"node": _get_node_display_name(target)
			})

	# 获取保存描述
	if save_to_variable.is_empty():
		save_desc = FuseLocalization.translate("FUSE_INSTRUCTION_GET_POSITION_NO_VARIABLE")
	else:
		var scope_str = VariableScopeUtils.enum_to_string(save_to_scope).to_upper()
		save_desc = FuseLocalization.translate_format("FUSE_INSTRUCTION_GET_POSITION_SAVE_VARIABLE", {
			"variable": "%s [%s]" % [save_to_variable, scope_str]
		})

	var space_str = "global" if use_global_position else "local"

	return FuseLocalization.translate_format("FUSE_INSTRUCTION_GET_POSITION_DESC_FORMAT", {
		"target": target_desc,
		"variable": save_desc,
		"space": space_str
	})
