@tool
@icon("res://addons/fuse/icons/builtin/Remotes.svg")
extends BaseInstruction
class_name GetRandomChild

## 获取随机子节点指令
##
## 从指定节点的子节点中随机获取一个，并将结果保存到变量中。
## 支持包含/排除内部节点（以 _ 开头的节点）。
## 支持本地、作用域和全局变量存储。
##
## 重构变量系统: 2026-03-03 - 使用 VariableOperations 统一变量访问

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
		if target_node != value:
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

## 是否包含内部节点（以 _ 开头的节点）
var include_internal: bool = true:
	set(value):
		if include_internal != value:
			include_internal = value
			_update_resource_name()

## 结果变量名
var result_variable: String = "":
	set(value):
		if result_variable != value:
			result_variable = value
			_update_resource_name()

## 结果变量作用域
var result_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		if result_scope != value:
			result_scope = value
			_update_resource_name()
			notify_property_list_changed()

## 作用域来源（仅当 result_scope == SCOPE 时使用）
var scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		if scope_source != value:
			scope_source = value
			_update_resource_name()
			notify_property_list_changed()

## 自定义作用域 ID（CUSTOM_ID 模式使用）
var custom_scope_id: String = "":
	set(value):
		if custom_scope_id != value:
			custom_scope_id = value
			_update_resource_name()

## 目标节点路径（TARGET_NODE 模式使用）
var scope_target_node_path: NodePath = NodePath(""):
	set(value):
		if scope_target_node_path != value:
			scope_target_node_path = value
			_update_resource_name()

## 获取指令元数据（用于指令选择器）
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_GET_RANDOM_CHILD_NAME"
	metadata.category_key = "FUSE_CATEGORY_NODE_OPERATIONS"
	metadata.description_key = "FUSE_INSTRUCTION_GET_RANDOM_CHILD_DESC"
	metadata.keywords = ["child", "random", "get", "children", "子节点", "随机", "获取"]
	metadata.builtin_icon = "Remotes"
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

## 声明变量读写模式
func get_variable_modes() -> Array[Dictionary]:
	var modes: Array[Dictionary] = []
	if use_variable_for_target:
		modes.append({"name": "target_variable", "mode": "read"})
	modes.append({"name": "result_variable", "mode": "write"})
	return modes


## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	# Target Node 分类
	properties.append({
		name = "Target Node",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 目标节点路径

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

	# Options 分类
	properties.append({
		name = "Options",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 是否包含内部节点
	properties.append({
		name = "include_internal",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Result Options 分类
	properties.append({
		name = "Result Options",
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

	# 只在 result_scope == SCOPE 时显示 ScopeSource 配置
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
				name = "scope_target_node_path",
				type = TYPE_NODE_PATH,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

	return properties

## 验证属性可见性
func _validate_property(property: Dictionary) -> void:
	# 只在 SCOPE 作用域时验证 ScopeSource 相关属性
	if result_scope == BaseVariable.VariableScope.SCOPE:
		VariableScopeUtils.validate_scope_source_property(property, scope_source as VariableScopeUtils.ScopeSource)
	else:
		# 非 SCOPE 作用域时隐藏 ScopeSource 相关属性
		if property.name in ["scope_source", "custom_scope_id", "scope_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
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
## 获取目标节点显示字符串（支持变量）
func _get_target_display() -> String:
	if use_variable_for_target:
		if target_variable.is_empty():
			return FuseLocalization.translate("FUSE_COMMON_NO_NODE_SELECTED")
		var scope_str := VariableScopeUtils.enum_to_string(target_scope).to_upper()
		if target_scope == BaseVariable.VariableScope.SCOPE:
			var target_utils_scope_source = target_scope_source as VariableScopeUtils.ScopeSource
			scope_str = VariableScopeUtils.get_scope_source_string(target_utils_scope_source, target_custom_scope_id, target_target_node_path)
		return "%s [%s]" % [target_variable, scope_str]
	return _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_COMMON_NO_NODE_SELECTED")

## 更新资源名称
func _update_resource_name():
	var parts = []

	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_GET_RANDOM_CHILD_RESOURCE_BASE"))

	if target_node.is_empty():
		parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_GET_RANDOM_CHILD_NO_TARGET"))
	else:
		parts.append("→ %s" % _get_target_display())

	if result_variable.is_empty():
		parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_GET_RANDOM_CHILD_NO_VARIABLE"))
	else:
		var scope_str = _get_scope_source_string()
		parts.append(FuseLocalization.translate_format(
			"FUSE_INSTRUCTION_GET_RANDOM_CHILD_VAR_TEMPLATE",
			{"var_type": scope_str, "var": result_variable}
		))

	resource_name = " ".join(parts)

## 获取作用域来源字符串
func _get_scope_source_string() -> String:
	match result_scope:
		BaseVariable.VariableScope.LOCAL:
			return FuseLocalization.translate("FUSE_VARIABLE_SCOPE_LOCAL_STR")
		BaseVariable.VariableScope.GLOBAL:
			return FuseLocalization.translate("FUSE_VARIABLE_SCOPE_GLOBAL_STR")
		BaseVariable.VariableScope.SCOPE:
			return VariableScopeUtils.get_scope_source_string(
				scope_source as VariableScopeUtils.ScopeSource,
				custom_scope_id,
				scope_target_node_path
			)
		_:
			return FuseLocalization.translate("FUSE_VARIABLE_SCOPE_UNKNOWN")

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	# 验证目标节点路径

	# 验证结果变量名
	if result_variable.is_empty():
		_log_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", {})
		set_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 获取目标节点
	var target := _resolve_node(
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
	if target == null:
		_log_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(target_node)})
		set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"node": str(target_node)})
		finished.emit()
		return

	# 获取随机子节点
	var child: Node = null
	if include_internal:
		var child_count = target.get_child_count()
		if child_count > 0:
			var random_index = randi() % child_count
			child = target.get_child(random_index)
	else:
		child = _get_random_non_internal_child(target)

	if child == null:
		_log_error_localized("FUSE_ERROR_NO_CHILDREN", {"node": target.name})
		set_error_localized("FUSE_ERROR_NO_CHILDREN", FuseError.ErrorType.RUNTIME_ERROR, {"node": target.name})
		finished.emit()
		return

	# 获取节点路径
	var child_path = str(child.get_path())

	# 记录结果
	_log_info_localized("FUSE_LOG_GET_RANDOM_CHILD_RESULT", {
		"node": target.name,
		"child": child.name
	})

	# 保存结果到变量（保存节点路径字符串）
	_save_result(context, child_path)

	_on_execution_completed()

## 获取随机非内部子节点
func _get_random_non_internal_child(parent: Node) -> Node:
	var non_internal_children: Array[Node] = []
	for child in parent.get_children():
		if not child.name.begins_with("_"):
			non_internal_children.append(child)

	if non_internal_children.is_empty():
		return null

	var random_index = randi() % non_internal_children.size()
	return non_internal_children[random_index]

## 保存结果到变量
func _save_result(context: ExecutionContext, value: String):
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
					scope_target_node_path
				)
				if scope_container != null:
					success = scope_container.set_variable(result_variable, value)
				else:
					success = false
		BaseVariable.VariableScope.GLOBAL:
			success = VariableOperations.set_variable(context, result_variable, BaseVariable.VariableScope.GLOBAL, value)

	if success:
		var scope_str = _get_scope_source_string()
		_log_info_localized("FUSE_LOG_GET_RANDOM_CHILD_SAVED", {
			"var": result_variable,
			"scope": scope_str,
			"path": value
		})
	else:
		_log_error_localized("FUSE_LOG_GET_RANDOM_CHILD_SAVE_FAILED", {
			"var": result_variable,
			"scope": _get_scope_source_string()
		})

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


	if result_variable.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_RESULT_VAR_EMPTY"))

	# 验证 SCOPE 作用域需要 ScopeVariableManager
	if result_scope == BaseVariable.VariableScope.SCOPE:
		var manager = ScopeVariableManager.get_instance()
		if manager == null:
			errors.append(FuseLocalization.translate("FUSE_ERROR_SCOPE_MANAGER_NOT_FOUND"))

		# 验证 ScopeSource 参数
		var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
		errors.append_array(VariableScopeUtils.validate_scope_source_params(
			utils_scope_source,
			custom_scope_id,
			scope_target_node_path
		))

	return errors

## 获取指令描述
func get_description() -> String:
	var scope_str = _get_scope_source_string()
	var target_str = _get_target_display()

	return FuseLocalization.translate_format(
		"FUSE_INSTRUCTION_GET_RANDOM_CHILD_DESC_FORMAT",
		{
			"target": target_str,
			"var": result_variable,
			"scope": scope_str
		}
	)

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

