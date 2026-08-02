@tool
@icon("res://addons/fuse/icons/builtin/List.svg")
extends BaseInstruction
class_name GetAllChildren

## 获取指定节点的所有子节点指令
##
## 从指定节点获取所有子节点（支持递归），并将节点引用数组保存到指定变量中。
##
## 重构变量系统: 2026-03-12 - 使用 VariableOperations 统一变量访问

## 作用域来源枚举
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

## 目标节点路径
var target_node: NodePath = NodePath(""):
	set(value):
		target_node = value
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

## 是否递归获取子节点
var recursive: bool = false:
	set(value):
		recursive = value
		_update_resource_name()

## 结果变量名
var result_variable: String = "":
	set(value):
		result_variable = value
		_update_resource_name()

## 结果变量作用域
var result_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		result_scope = value
		_update_resource_name()
		notify_property_list_changed()

## 作用域来源（仅当 result_scope == SCOPE 时使用）
var scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		scope_source = value
		_update_resource_name()
		notify_property_list_changed()

## 自定义作用域 ID（CUSTOM_ID 模式使用）
var custom_scope_id: String = "":
	set(value):
		custom_scope_id = value
		_update_resource_name()

## 目标节点路径（TARGET_NODE 模式使用，用于保存）
var save_target_node_path: NodePath = NodePath(""):
	set(value):
		save_target_node_path = value
		_update_resource_name()

## 获取指令元数据（用于指令选择器）
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_GET_ALL_CHILDREN_NAME"
	metadata.category_key = "FUSE_CATEGORY_NODE_OPERATIONS"
	metadata.description_key = "FUSE_INSTRUCTION_GET_ALL_CHILDREN_DESC"
	metadata.keywords = ["children", "nodes", "get", "child", "子节点", "获取", "递归"]
	metadata.builtin_icon = "List"
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

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
			name = "target_node",
			type = TYPE_NODE_PATH,
			hint = PROPERTY_HINT_NODE_PATH_VALID_TYPES,
			hint_string = "Node",
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

	# Options 分类
	properties.append({
		name = "Options",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 是否递归
	properties.append({
		name = "recursive",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Result 分类
	properties.append({
		name = "Result",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 结果变量名
	properties.append({
		name = "result_variable",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 结果变量作用域
	properties.append({
		name = "result_scope",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Local,Scope,Global",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 仅当 result_scope == SCOPE 时显示 scope_source 相关属性
	if result_scope == BaseVariable.VariableScope.SCOPE:
		properties.append({
			name = "Scope Configuration",
			type = TYPE_NIL,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_CATEGORY
		})

		properties.append({
			name = "scope_source",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 根据作用域来源添加额外属性
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

	return properties

## 验证属性可见性
func _validate_property(property: Dictionary) -> void:
	# 控制目标节点相关属性的可见性
	if not use_variable:
		if property.name in ["target_variable", "target_scope", "target_scope_source", "target_custom_scope_id", "target_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		if property.name == "target_node":
			property.usage = PROPERTY_USAGE_NO_EDITOR

		# 控制 target_scope_source 相关属性
		if target_scope != BaseVariable.VariableScope.SCOPE:
			if property.name in ["target_scope_source", "target_custom_scope_id", "target_target_node_path"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR
		else:
			var utils_scope_source = target_scope_source as VariableScopeUtils.ScopeSource
			VariableScopeUtils.validate_scope_source_property(property, utils_scope_source)

	# 控制保存作用域相关属性的可见性
	if result_scope != BaseVariable.VariableScope.SCOPE:
		if property.name in ["scope_source", "custom_scope_id", "save_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
		VariableScopeUtils.validate_scope_source_property(property, utils_scope_source)

## 动态属性设置
func _set(property: StringName, value: Variant) -> bool:
	if property in ["use_variable", "target_scope", "target_scope_source", "result_scope", "scope_source", "recursive"]:
		set(property, value)
		notify_property_list_changed()
		return true
	return false

## 更新资源名称
func _update_resource_name():
	var parts := []

	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_GET_ALL_CHILDREN_RESOURCE_BASE"))

	# 目标节点部分
	if use_variable:
		if target_variable.is_empty():
			parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_GET_ALL_CHILDREN_NO_TARGET"))
		else:
			var scope_str = VariableScopeUtils.enum_to_string(target_scope).to_upper()
			parts.append("%s [%s]" % [target_variable, scope_str])
	else:
		if not target_node.is_empty():
			parts.append(_get_node_display_name(target_node))
		else:
			parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_GET_ALL_CHILDREN_NO_TARGET"))

	# 递归标记
	if recursive:
		parts.append("[%s]" % FuseLocalization.translate("FUSE_INSTRUCTION_GET_ALL_CHILDREN_RECURSIVE"))

	parts.append("→")

	# 保存变量部分
	if result_variable.is_empty():
		parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_GET_ALL_CHILDREN_NO_VARIABLE"))
	else:
		var scope_str = VariableScopeUtils.enum_to_string(result_scope).to_upper()
		parts.append("%s [%s]" % [result_variable, scope_str])

		# 如果是 SCOPE 作用域，添加 ScopeSource 信息
		if result_scope == BaseVariable.VariableScope.SCOPE:
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
	var target: Node = null

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
			_log_error_localized("FUSE_ERROR_VAR_NOT_FOUND", {"variable": target_variable})
			set_error_localized("FUSE_ERROR_VAR_NOT_FOUND", FuseError.ErrorType.VALIDATION_ERROR, {"variable": target_variable})
			finished.emit()
			return

		# 支持多种类型：Node、String（节点路径）、NodePath
		if node_value is Node:
			target = node_value
		elif node_value is String or node_value is NodePath:
			# 从字符串或 NodePath 解析节点
			var node_path = NodePath(node_value)
			target = context.get_node(node_path)
			if not target:
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
		if target_node.is_empty():
			_log_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", {})
			set_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
			finished.emit()
			return

		target = context.get_node(target_node)
		if not target:
			_log_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(target_node)})
			set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"node": str(target_node)})
			finished.emit()
			return

	# 验证结果变量名
	if result_variable.is_empty():
		_log_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", {})
		set_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 获取子节点
	var children: Array = []
	if recursive:
		children = _get_all_children_recursive(target)
	else:
		children.assign(target.get_children())

	# 记录结果
	if children.is_empty():
		_log_info_localized("FUSE_LOG_GET_ALL_CHILDREN_EMPTY", {"node": target.name})
	else:
		_log_info_localized("FUSE_LOG_GET_ALL_CHILDREN_FOUND", {
			"node": target.name,
			"count": children.size()
		})

	# 保存结果到变量
	_save_result(context, children)

	_on_execution_completed()

## 递归获取所有子节点
func _get_all_children_recursive(node: Node) -> Array:
	var result: Array = []
	for child in node.get_children():
		result.append(child)
		var sub_children = _get_all_children_recursive(child)
		result.append_array(sub_children)
	return result

## 保存结果到变量
func _save_result(context: ExecutionContext, value: Array):
	var success = false
	match result_scope:
		BaseVariable.VariableScope.LOCAL:
			success = VariableOperations.set_variable(context, result_variable, BaseVariable.VariableScope.LOCAL, value)
		BaseVariable.VariableScope.SCOPE:
			if scope_source == ScopeSource.NEAREST:
				success = VariableOperations.set_variable(context, result_variable, BaseVariable.VariableScope.SCOPE, value)
			else:
				var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
				var scope_container = VariableScopeUtils.get_scope_container_by_source(
					context,
					utils_scope_source,
					custom_scope_id,
					save_target_node_path
				)
				if scope_container != null:
					success = scope_container.set_variable(result_variable, value)
				else:
					success = false
		BaseVariable.VariableScope.GLOBAL:
			success = VariableOperations.set_variable(context, result_variable, BaseVariable.VariableScope.GLOBAL, value)

	if success:
		var scope_str = _get_result_scope_string()
		_log_info_localized("FUSE_LOG_GET_ALL_CHILDREN_SAVED", {
			"var": result_variable,
			"scope": scope_str,
			"count": value.size()
		})
	else:
		_log_error_localized("FUSE_LOG_GET_ALL_CHILDREN_SAVE_FAILED", {
			"var": result_variable,
			"scope": _get_result_scope_string()
		})

## 获取结果作用域字符串
func _get_result_scope_string() -> String:
	match result_scope:
		BaseVariable.VariableScope.LOCAL:
			return FuseLocalization.translate("FUSE_VARIABLE_SCOPE_LOCAL_STR")
		BaseVariable.VariableScope.GLOBAL:
			return FuseLocalization.translate("FUSE_VARIABLE_SCOPE_GLOBAL_STR")
		BaseVariable.VariableScope.SCOPE:
			return VariableScopeUtils.get_scope_source_string(
				scope_source as VariableScopeUtils.ScopeSource,
				custom_scope_id,
				save_target_node_path
			)
		_:
			return FuseLocalization.translate("FUSE_VARIABLE_SCOPE_UNKNOWN")

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()

	# 验证结果变量名
	if result_variable.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_RESULT_VAR_EMPTY"))

	# 验证目标节点设置
	if not use_variable:
		if target_node.is_empty():
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
	if target_scope == BaseVariable.VariableScope.SCOPE or result_scope == BaseVariable.VariableScope.SCOPE:
		var manager = ScopeVariableManager.get_instance()
		if manager == null:
			errors.append(FuseLocalization.translate("FUSE_ERROR_SCOPE_MANAGER_NOT_FOUND"))

	# 验证 result_scope == SCOPE 时的 ScopeSource 参数
	if result_scope == BaseVariable.VariableScope.SCOPE:
		var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
		errors.append_array(VariableScopeUtils.validate_scope_source_params(
			utils_scope_source,
			custom_scope_id,
			save_target_node_path
		))

	return errors

## 获取指令描述
func get_description() -> String:
	var target_desc := ""
	var save_desc := ""

	# 获取目标描述
	if use_variable:
		if target_variable.is_empty():
			target_desc = FuseLocalization.translate("FUSE_INSTRUCTION_GET_ALL_CHILDREN_TARGET_VARIABLE_EMPTY")
		else:
			var scope_str = VariableScopeUtils.enum_to_string(target_scope).to_upper()
			target_desc = FuseLocalization.translate_format("FUSE_INSTRUCTION_GET_ALL_CHILDREN_TARGET_VARIABLE", {
				"variable": "%s [%s]" % [target_variable, scope_str]
			})
	else:
		if target_node.is_empty():
			target_desc = FuseLocalization.translate("FUSE_INSTRUCTION_GET_ALL_CHILDREN_NO_TARGET")
		else:
			target_desc = FuseLocalization.translate_format("FUSE_INSTRUCTION_GET_ALL_CHILDREN_TARGET_NODE", {
				"node": _get_node_display_name(target_node)
			})

	# 获取保存描述
	if result_variable.is_empty():
		save_desc = FuseLocalization.translate("FUSE_INSTRUCTION_GET_ALL_CHILDREN_NO_VARIABLE")
	else:
		var scope_str = VariableScopeUtils.enum_to_string(result_scope).to_upper()
		save_desc = FuseLocalization.translate_format("FUSE_INSTRUCTION_GET_ALL_CHILDREN_SAVE_VARIABLE", {
			"variable": "%s [%s]" % [result_variable, scope_str]
		})

	var recursive_str = FuseLocalization.translate("FUSE_INSTRUCTION_GET_ALL_CHILDREN_RECURSIVE") if recursive else ""

	return FuseLocalization.translate_format("FUSE_INSTRUCTION_GET_ALL_CHILDREN_DESC_FORMAT", {
		"target": target_desc,
		"variable": save_desc,
		"recursive": recursive_str
	})
