@tool
@icon("res://addons/fuse/icons/builtin/Node2D.svg")
extends BaseInstruction
class_name GetNode

## 获取节点指令
##
## 按 NodePath 精确取节点对象，将 Node 引用存入变量。
## 变量存储节点对象本身（非路径），消费端（如 CameraFollow、SetPosition 等）
## 直接通过 _resolve_node 的 `is Node` 分支使用，不依赖路径解析基准，
## 跨 Action Runner / Context 稳定。
##
## 对比 SetVariable 存 NodePath：本指令解析一次，变量即节点引用，
## 避免相对路径基准问题与 Variant NodePath 的 Inspector 输入限制。
##
## 适用场景：在多个 Action Runner 间共享节点引用（如相机、玩家）。

## 作用域来源枚举（仅 result_scope == SCOPE 时使用）
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

## 要获取的节点路径（支持相对当前 context.target、场景唯一名 %、绝对路径 /root/...）
var node_path: NodePath = NodePath(""):
	set(value):
		if node_path != value:
			node_path = value
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
var target_node_path: NodePath = NodePath(""):
	set(value):
		if target_node_path != value:
			target_node_path = value
			_update_resource_name()

## 获取指令元数据（用于指令选择器）
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_GET_NODE_NAME"
	metadata.category_key = "FUSE_CATEGORY_NODE_OPERATIONS"
	metadata.description_key = "FUSE_INSTRUCTION_GET_NODE_DESC"
	metadata.keywords = ["get", "node", "获取", "节点", "引用", "reference", "nodepath", "路径", "path", "对象", "object", "store"]
	metadata.builtin_icon = "Node2D"
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

## 声明变量读写模式（result_variable = write）
func get_variable_modes() -> Array[Dictionary]:
	return [{"name": "result_variable", "mode": "write"}]

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []

	# Node Source 分类
	properties.append({
		name = "Node Source",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 节点路径（专门 NodePath 属性，Inspector 选择器正常支持 %/绝对路径）
	properties.append({
		name = "node_path",
		type = TYPE_NODE_PATH,
		hint = PROPERTY_HINT_NODE_PATH_VALID_TYPES,
		hint_string = "",  # 空 = 任意节点类型
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
				name = "target_node_path",
				type = TYPE_NODE_PATH,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

	return properties

## 更新资源名称
func _update_resource_name():
	var parts = []

	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_GET_NODE_RESOURCE_BASE"))

	if node_path.is_empty():
		parts.append(FuseLocalization.translate("FUSE_ERROR_GET_NODE_PATH_EMPTY"))
	else:
		parts.append("'%s'" % str(node_path))

	if result_variable.is_empty():
		parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_GET_NODE_NO_VARIABLE"))
	else:
		parts.append(FuseLocalization.translate_format(
			"FUSE_INSTRUCTION_GET_NODE_VAR_TEMPLATE",
			{"var_type": _get_scope_source_string(), "var": result_variable}
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
				target_node_path
			)
		_:
			return FuseLocalization.translate("FUSE_VARIABLE_SCOPE_UNKNOWN")

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	# 验证节点路径
	if node_path.is_empty():
		_log_error_localized("FUSE_ERROR_GET_NODE_PATH_EMPTY", {})
		set_error_localized("FUSE_ERROR_GET_NODE_PATH_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 验证结果变量名
	if result_variable.is_empty():
		_log_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", {})
		set_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 按 NodePath 解析节点（支持相对 / % 场景唯一名 / 绝对路径）
	var node = context.get_node(node_path)
	if not node:
		_log_error_localized("FUSE_ERROR_GET_NODE_NOT_FOUND", {"path": str(node_path)})
		set_error_localized("FUSE_ERROR_GET_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"path": str(node_path)})
		finished.emit()
		return

	# 存 Node 对象到变量（非路径字符串）
	var success = _save_result(context, node)
	if success:
		_log_info_localized("FUSE_LOG_GET_NODE_SAVED", {
			"node": node.name,
			"var": result_variable,
			"scope": _get_scope_source_string()
		})
	else:
		_log_error_localized("FUSE_LOG_GET_NODE_SAVE_FAILED", {
			"var": result_variable,
			"scope": _get_scope_source_string()
		})

	_on_execution_completed()

## 保存结果到变量
func _save_result(context: ExecutionContext, value: Variant) -> bool:
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
					target_node_path
				)
				if scope_container != null:
					success = scope_container.set_variable(result_variable, value)
				else:
					success = false
		BaseVariable.VariableScope.GLOBAL:
			success = VariableOperations.set_variable(context, result_variable, BaseVariable.VariableScope.GLOBAL, value)

	return success

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()

	if node_path.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_GET_NODE_PATH_EMPTY"))

	if result_variable.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_VAR_NAME_EMPTY"))

	# 验证 SCOPE 作用域的 ScopeSource 参数
	if result_scope == BaseVariable.VariableScope.SCOPE:
		var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
		errors.append_array(VariableScopeUtils.validate_scope_source_params(
			utils_scope_source,
			custom_scope_id,
			target_node_path
		))

	return errors

## 验证属性可见性
func _validate_property(property: Dictionary) -> void:
	# 只在 SCOPE 作用域时显示 ScopeSource 相关属性
	if result_scope == BaseVariable.VariableScope.SCOPE:
		VariableScopeUtils.validate_scope_source_property(property, scope_source as VariableScopeUtils.ScopeSource)
	else:
		# 非 SCOPE 作用域时隐藏 ScopeSource 相关属性
		if property.name in ["scope_source", "custom_scope_id", "target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR

## 动态属性设置（支持属性刷新）
func _set(property: StringName, value: Variant) -> bool:
	if property == "result_scope":
		result_scope = value
		notify_property_list_changed()
		return true
	if property == "scope_source":
		scope_source = value
		notify_property_list_changed()
		return true
	return false

## 获取指令描述
func get_description() -> String:
	return FuseLocalization.translate_format(
		"FUSE_INSTRUCTION_GET_NODE_DESC_FORMAT",
		{
			"path": str(node_path) if not node_path.is_empty() else "-",
			"var": result_variable if not result_variable.is_empty() else "-",
			"scope": _get_scope_source_string()
		}
	)
