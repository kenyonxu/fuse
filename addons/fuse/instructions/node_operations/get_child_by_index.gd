@tool
@icon("res://addons/fuse/icons/builtin/Remotes.svg")
extends BaseInstruction
class_name GetChildByIndex

## 通过索引获取子节点指令
##
## 通过索引获取指定节点的子节点，并将结果保存到变量中。
## 支持负索引：-1 表示最后一个子节点，-2 表示倒数第二个，依此类推。
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

## 索引来源枚举
enum IndexSource {
	DIRECT,    ## 直接指定索引值
	VARIABLE   ## 从变量读取索引
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

## 索引来源
var index_source: IndexSource = IndexSource.DIRECT:
	set(value):
		if index_source != value:
			index_source = value
			_update_resource_name()
			notify_property_list_changed()

## 直接索引值（支持负数：-1 = 最后一个，-2 = 倒数第二个...）
var index: int = 0:
	set(value):
		if index != value:
			index = value
			_update_resource_name()

## 索引变量名（从变量读取索引时使用）
var index_variable: String = "":
	set(value):
		if index_variable != value:
			index_variable = value
			_update_resource_name()

## 索引变量作用域
var index_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		if index_scope != value:
			index_scope = value
			_update_resource_name()
			notify_property_list_changed()

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
	metadata.name_key = "FUSE_INSTRUCTION_GET_CHILD_BY_INDEX_NAME"
	metadata.category_key = "FUSE_CATEGORY_NODE_OPERATIONS"
	metadata.description_key = "FUSE_INSTRUCTION_GET_CHILD_BY_INDEX_DESC"
	metadata.keywords = ["child", "index", "get", "children", "子节点", "索引", "获取", "孩子"]
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

	# Index Configuration 分类
	properties.append({
		name = "Index Configuration",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 索引来源
	properties.append({
		name = "index_source",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Direct,Variable",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 根据索引来源显示不同属性
	if index_source == IndexSource.DIRECT:
		# 直接索引值
		properties.append({
			name = "index",
			type = TYPE_INT,
			hint = PROPERTY_HINT_NONE,
			hint_string = "",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
	else:
		# 索引变量名
		properties.append({
			name = "index_variable",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 索引变量作用域
		properties.append({
			name = "index_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
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
	# 根据索引来源控制属性可见性
	if index_source == IndexSource.DIRECT:
		if property.name in ["index_variable", "index_scope"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		if property.name == "index":
			property.usage = PROPERTY_USAGE_NO_EDITOR

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
	return _get_target_display() if not target_node.is_empty() else FuseLocalization.translate("FUSE_COMMON_NO_NODE_SELECTED")

## 更新资源名称
func _update_resource_name():
	var parts = []

	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_GET_CHILD_BY_INDEX_RESOURCE_BASE"))

	if target_node.is_empty():
		parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_GET_CHILD_BY_INDEX_NO_TARGET"))
	else:
		parts.append("→ %s" % _get_target_display())

	# 显示索引信息
	if index_source == IndexSource.DIRECT:
		parts.append("[%d]" % index)
	else:
		if index_variable.is_empty():
			parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_GET_CHILD_BY_INDEX_NO_INDEX_VAR"))
		else:
			parts.append("[%s]" % index_variable)

	if result_variable.is_empty():
		parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_GET_CHILD_BY_INDEX_NO_VARIABLE"))
	else:
		var scope_str = _get_scope_source_string()
		parts.append(FuseLocalization.translate_format(
			"FUSE_INSTRUCTION_GET_CHILD_BY_INDEX_VAR_TEMPLATE",
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

	# 获取实际索引值
	var actual_index: int
	if index_source == IndexSource.DIRECT:
		actual_index = index
	else:
		# 从变量读取索引
		if index_variable.is_empty():
			_log_error_localized("FUSE_ERROR_INDEX_VAR_EMPTY", {})
			set_error_localized("FUSE_ERROR_INDEX_VAR_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
			finished.emit()
			return

		var var_value = VariableOperations.get_variable(context, index_variable, index_scope)
		if var_value == null:
			_log_error_localized("FUSE_ERROR_INDEX_VAR_NOT_FOUND", {"var": index_variable})
			set_error_localized("FUSE_ERROR_INDEX_VAR_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"var": index_variable})
			finished.emit()
			return

		if not (var_value is int or var_value is float):
			_log_error_localized("FUSE_ERROR_INDEX_VAR_NOT_NUMBER", {"var": index_variable, "type": typeof(var_value)})
			set_error_localized("FUSE_ERROR_INDEX_VAR_NOT_NUMBER", FuseError.ErrorType.RUNTIME_ERROR, {"var": index_variable, "type": typeof(var_value)})
			finished.emit()
			return

		actual_index = int(var_value)

	# 获取子节点
	var child: Node = null
	if include_internal:
		# 直接获取子节点
		child = _get_child_by_index(target, actual_index)
	else:
		# 只获取非内部节点
		child = _get_non_internal_child_by_index(target, actual_index)

	if child == null:
		_log_error_localized("FUSE_ERROR_CHILD_INDEX_OUT_OF_RANGE", {
			"index": actual_index,
			"node": target.name
		})
		set_error_localized("FUSE_ERROR_CHILD_INDEX_OUT_OF_RANGE", FuseError.ErrorType.RUNTIME_ERROR, {
			"index": actual_index,
			"node": target.name
		})
		finished.emit()
		return

	# 获取节点路径
	var child_path = str(child.get_path())

	# 记录结果
	_log_info_localized("FUSE_LOG_GET_CHILD_BY_INDEX_RESULT", {
		"node": target.name,
		"index": actual_index,
		"child": child.name
	})

	# 保存结果到变量（保存节点路径字符串）
	_save_result(context, child_path)

	_on_execution_completed()

## 通过索引获取子节点（支持负索引）
func _get_child_by_index(parent: Node, idx: int) -> Node:
	var child_count = parent.get_child_count()
	if child_count == 0:
		return null

	# 处理负索引
	var actual_idx: int
	if idx < 0:
		actual_idx = child_count + idx
	else:
		actual_idx = idx

	# 边界检查
	if actual_idx < 0 or actual_idx >= child_count:
		return null

	return parent.get_child(actual_idx)

## 通过索引获取非内部子节点（支持负索引）
func _get_non_internal_child_by_index(parent: Node, idx: int) -> Node:
	# 获取所有非内部子节点
	var non_internal_children: Array[Node] = []
	for child in parent.get_children():
		if not child.name.begins_with("_"):
			non_internal_children.append(child)

	var child_count = non_internal_children.size()
	if child_count == 0:
		return null

	# 处理负索引
	var actual_idx: int
	if idx < 0:
		actual_idx = child_count + idx
	else:
		actual_idx = idx

	# 边界检查
	if actual_idx < 0 or actual_idx >= child_count:
		return null

	return non_internal_children[actual_idx]

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
		_log_info_localized("FUSE_LOG_GET_CHILD_BY_INDEX_SAVED", {
			"var": result_variable,
			"scope": scope_str,
			"path": value
		})
	else:
		_log_error_localized("FUSE_LOG_GET_CHILD_BY_INDEX_SAVE_FAILED", {
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

	# 验证从变量读取索引时的参数
	if index_source == IndexSource.VARIABLE:
		if index_variable.is_empty():
			errors.append(FuseLocalization.translate("FUSE_ERROR_INDEX_VAR_EMPTY"))

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

	var index_str: String
	if index_source == IndexSource.DIRECT:
		index_str = str(index)
	else:
		index_str = index_variable if not index_variable.is_empty() else FuseLocalization.translate("FUSE_INSTRUCTION_GET_CHILD_BY_INDEX_NO_INDEX_VAR")

	return FuseLocalization.translate_format(
		"FUSE_INSTRUCTION_GET_CHILD_BY_INDEX_DESC_FORMAT",
		{
			"target": target_str,
			"index": index_str,
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

