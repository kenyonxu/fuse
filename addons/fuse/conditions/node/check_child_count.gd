@tool
@icon("res://addons/fuse/icons/builtin/Children.svg")
extends BaseCondition
class_name CheckChildCount

## 子节点数量检查条件
##
## 检查指定节点的子节点数量与期望值的比较关系。
##
## 支持两种节点路径来源：
## - NODE_PATH: 直接指定节点路径
## - VARIABLE: 从变量获取节点路径（支持三层变量作用域）
##
## 支持递归统计子节点数量。

## 节点路径来源枚举
enum NodePathSource {
	NODE_PATH,  ## 直接指定节点路径
	VARIABLE    ## 从变量获取节点路径
}

## 比较操作符枚举
enum ComparisonOperator {
	EQUALS,           ## 等于 (==)
	NOT_EQUALS,       ## 不等于 (!=)
	GREATER_THAN,     ## 大于 (>)
	LESS_THAN,        ## 小于 (<)
	GREATER_EQUAL,    ## 大于等于 (>=)
	LESS_EQUAL        ## 小于等于 (<=)
}

## 作用域来源枚举（仅在 node_variable_scope == SCOPE 时使用）
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

# =============================================
# 参数定义
# =============================================

## 节点路径来源
var node_path_source: NodePathSource = NodePathSource.NODE_PATH:
	set(value):
		node_path_source = value
		_update_resource_name()
		notify_property_list_changed()

## 目标节点路径（当 node_path_source == NODE_PATH 时使用）
var target_node_path: NodePath = NodePath(""):
	set(value):
		target_node_path = value
		_update_resource_name()

## 节点路径变量名（当 node_path_source == VARIABLE 时使用）
var node_variable_name: String = "":
	set(value):
		node_variable_name = value
		_update_resource_name()

## 节点路径变量作用域（三层变量系统）
var node_variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		node_variable_scope = value
		_update_resource_name()
		notify_property_list_changed()

## 节点路径变量作用域来源（仅当 node_variable_scope == SCOPE 时使用）
var node_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		node_scope_source = value
		_update_resource_name()
		notify_property_list_changed()

## 节点路径变量自定义作用域 ID（仅当 node_scope_source == CUSTOM_ID 时使用）
var node_custom_scope_id: String = "":
	set(value):
		node_custom_scope_id = value
		_update_resource_name()

## 节点路径变量目标节点路径（仅当 node_scope_source == TARGET_NODE 时使用）
var node_target_node_path: NodePath = NodePath(""):
	set(value):
		node_target_node_path = value
		_update_resource_name()

## 是否递归统计子节点
var recursive: bool = false:
	set(value):
		recursive = value
		_update_resource_name()

## 比较操作符
var comparison_operator: ComparisonOperator = ComparisonOperator.EQUALS:
	set(value):
		comparison_operator = value
		_update_resource_name()

## 比较值
var compare_value: int = 0:
	set(value):
		compare_value = value
		_update_resource_name()

# =============================================
# 动态属性列表
# =============================================

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties := []

	# ========== 节点配置 ==========
	properties.append({
		name = "Node Configuration",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 节点路径来源
	properties.append({
		name = "node_path_source",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Node Path,Variable",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 根据节点路径来源显示不同属性
	if node_path_source == NodePathSource.NODE_PATH:
		# 直接指定节点路径
		properties.append({
			name = "target_node_path",
			type = TYPE_NODE_PATH,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
	else:
		# 变量模式
		properties.append({
			name = "node_variable_name",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 变量作用域
		properties.append({
			name = "node_variable_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 只在 node_variable_scope == SCOPE 时显示 ScopeSource 配置
		if node_variable_scope == BaseVariable.VariableScope.SCOPE:
			properties.append({
				name = "node_scope_source",
				type = TYPE_INT,
				hint = PROPERTY_HINT_ENUM,
				hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

			# 根据作用域来源添加额外属性
			if node_scope_source == ScopeSource.CUSTOM_ID:
				properties.append({
					name = "node_custom_scope_id",
					type = TYPE_STRING,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})
			elif node_scope_source == ScopeSource.TARGET_NODE:
				properties.append({
					name = "node_target_node_path",
					type = TYPE_NODE_PATH,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})

	# ========== 计数配置 ==========
	properties.append({
		name = "Count Configuration",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 递归开关
	properties.append({
		name = "recursive",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# ========== 比较配置 ==========
	properties.append({
		name = "Comparison Configuration",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 比较操作符
	properties.append({
		name = "comparison_operator",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Equals,Not Equals,Greater Than,Less Than,Greater Equal,Less Equal",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 比较值
	properties.append({
		name = "compare_value",
		type = TYPE_INT,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 验证属性可见性
func _validate_property(property: Dictionary) -> void:
	# 控制节点路径来源相关属性可见性
	if node_path_source == NodePathSource.NODE_PATH:
		# NODE_PATH 模式：隐藏变量相关属性
		if property.name in ["node_variable_name", "node_variable_scope", "node_scope_source", "node_custom_scope_id", "node_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		# VARIABLE 模式：隐藏节点路径属性
		if property.name == "target_node_path":
			property.usage = PROPERTY_USAGE_NO_EDITOR

		# 控制变量 ScopeSource 属性可见性
		if node_variable_scope == BaseVariable.VariableScope.SCOPE:
			VariableScopeUtils.validate_scope_source_property(property, node_scope_source as VariableScopeUtils.ScopeSource)
		else:
			# 非 SCOPE 作用域时隐藏 ScopeSource 相关属性
			if property.name in ["node_scope_source", "node_custom_scope_id", "node_target_node_path"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR

# =============================================
# 资源名称和描述
# =============================================

## 更新资源名称（必需）
func _update_resource_name() -> void:
	var node_str = _get_node_source_string()
	var op_str = _get_operator_string()
	var recursive_str = ""
	if recursive:
		recursive_str = FuseLocalization.translate("FUSE_RECURSIVE")

	if node_str.is_empty():
		resource_name = FuseLocalization.translate("FUSE_CONDITION_CHILD_COUNT_NOT_SET")
	else:
		resource_name = "%s.child_count%s %s %d" % [node_str, recursive_str, op_str, compare_value]

## 获取节点来源显示字符串
func _get_node_source_string() -> String:
	if node_path_source == NodePathSource.NODE_PATH:
		var path_str = _get_node_display_name(target_node_path)
		if path_str.is_empty():
			return ""
		if path_str.length() > 30:
			path_str = path_str.substr(0, 27) + "..."
		return path_str
	else:
		if node_variable_name.is_empty():
			return ""
		var scope_str = _get_node_scope_source_string()
		return "[%s] %s" % [scope_str, node_variable_name]

## 获取节点变量作用域来源字符串
func _get_node_scope_source_string() -> String:
	match node_variable_scope:
		BaseVariable.VariableScope.LOCAL:
			return FuseLocalization.translate("FUSE_SCOPE_LOCAL_STR")
		BaseVariable.VariableScope.SCOPE:
			return VariableScopeUtils.get_scope_source_string(
				node_scope_source as VariableScopeUtils.ScopeSource,
				node_custom_scope_id,
				node_target_node_path
			)
		BaseVariable.VariableScope.GLOBAL:
			return FuseLocalization.translate("FUSE_SCOPE_GLOBAL_STR")
		_:
			return FuseLocalization.translate("FUSE_SCOPE_UNKNOWN_STR")

## 获取操作符显示字符串
func _get_operator_string() -> String:
	match comparison_operator:
		ComparisonOperator.EQUALS:
			return "="
		ComparisonOperator.NOT_EQUALS:
			return "!="
		ComparisonOperator.GREATER_THAN:
			return ">"
		ComparisonOperator.LESS_THAN:
			return "<"
		ComparisonOperator.GREATER_EQUAL:
			return ">="
		ComparisonOperator.LESS_EQUAL:
			return "<="
		_:
			return "?"

# =============================================
# 条件评估
# =============================================

## 评估条件
func _evaluate_condition(context: ExecutionContext) -> bool:
	# 获取目标节点
	var node = _get_target_node(context)
	if node == null:
		var node_str = _get_node_source_string()
		var error_msg = FuseLocalization.translate("FUSE_ERROR_NODE_NOT_FOUND").format({"path": node_str})
		_log_error(error_msg)
		_create_fuse_error(error_msg, FuseError.ErrorType.VALIDATION_ERROR)
		return false

	# 获取子节点数量
	var actual_count: int
	if recursive:
		actual_count = _count_children_recursive(node)
	else:
		actual_count = node.get_child_count()

	# 执行比较
	var result = _perform_comparison(actual_count, compare_value)

	# 记录日志
	var mode_str = FuseLocalization.translate("FUSE_RECURSIVE_MODE") if recursive else FuseLocalization.translate("FUSE_DIRECT_MODE")
	_log_debug(FuseLocalization.translate_format(
		"FUSE_LOG_CHILD_COUNT_CHECK",
		{
			"node": _get_node_source_string(),
			"mode": mode_str,
			"count": actual_count,
			"op": _get_operator_string(),
			"expected": compare_value,
			"result": "true" if result else "false"
		}
	))

	return result

## 获取目标节点
func _get_target_node(context: ExecutionContext) -> Node:
	if node_path_source == NodePathSource.NODE_PATH:
		return _get_node_by_path(context)
	else:
		return _get_node_by_variable(context)

## 通过节点路径获取节点
func _get_node_by_path(context: ExecutionContext) -> Node:
	# 验证节点路径
	if target_node_path.is_empty():
		var error_msg = FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_PATH_EMPTY")
		_log_error(error_msg)
		_create_fuse_error(error_msg, FuseError.ErrorType.VALIDATION_ERROR)
		return null

	# 获取节点
	var node = context.get_node(target_node_path)
	return node

## 通过变量获取节点
func _get_node_by_variable(context: ExecutionContext) -> Node:
	# 验证变量名
	if node_variable_name.is_empty():
		var error_msg = FuseLocalization.translate("FUSE_ERROR_VAR_NAME_EMPTY")
		_log_error(error_msg)
		_create_fuse_error(error_msg, FuseError.ErrorType.VALIDATION_ERROR)
		return null

	# 获取变量值
	var node_value = _get_node_variable_value(context)

	# 验证变量值
	if node_value == null:
		return null

	# 处理不同类型的节点值
	var node: Node = null
	if node_value is Node:
		node = node_value
	elif node_value is NodePath:
		node = context.get_node(node_value)
	elif node_value is String and not node_value.is_empty():
		node = context.get_node(NodePath(node_value))
	else:
		var error_msg = FuseLocalization.translate_format("FUSE_ERROR_NODE_VARIABLE_INVALID_TYPE", {"name": node_variable_name, "type": str(typeof(node_value))})
		_log_error(error_msg)
		_create_fuse_error(error_msg, FuseError.ErrorType.RUNTIME_ERROR)
		return null

	return node

## 获取节点变量值
func _get_node_variable_value(context: ExecutionContext) -> Variant:
	var value: Variant = null

	match node_variable_scope:
		BaseVariable.VariableScope.LOCAL:
			value = VariableOperations.get_variable(context, node_variable_name, BaseVariable.VariableScope.LOCAL, null)

		BaseVariable.VariableScope.GLOBAL:
			value = VariableOperations.get_variable(context, node_variable_name, BaseVariable.VariableScope.GLOBAL, null)

		BaseVariable.VariableScope.SCOPE:
			if node_scope_source == ScopeSource.NEAREST:
				value = VariableOperations.get_variable(context, node_variable_name, BaseVariable.VariableScope.SCOPE, null)
			else:
				var utils_scope_source = node_scope_source as VariableScopeUtils.ScopeSource
				var scope_container = VariableScopeUtils.get_scope_container_by_source(
					context,
					utils_scope_source,
					node_custom_scope_id,
					node_target_node_path
				)

				if scope_container != null and scope_container.has_variable(node_variable_name):
					value = scope_container.get_variable(node_variable_name)

	return value

## 递归统计子节点数量
func _count_children_recursive(node: Node) -> int:
	var count := 0
	for child in node.get_children():
		count += 1
		count += _count_children_recursive(child)
	return count

## 执行比较
func _perform_comparison(actual: int, expected: int) -> bool:
	match comparison_operator:
		ComparisonOperator.EQUALS:
			return actual == expected
		ComparisonOperator.NOT_EQUALS:
			return actual != expected
		ComparisonOperator.GREATER_THAN:
			return actual > expected
		ComparisonOperator.LESS_THAN:
			return actual < expected
		ComparisonOperator.GREATER_EQUAL:
			return actual >= expected
		ComparisonOperator.LESS_EQUAL:
			return actual <= expected
		_:
			_log_error("未知的比较操作符: %s" % ComparisonOperator.keys()[comparison_operator])
			return false

# =============================================
# 依赖计算
# =============================================

## 计算依赖
func _compute_dependencies() -> Array[String]:
	var dependencies: Array[String] = []

	# 如果使用变量模式，添加变量依赖
	if node_path_source == NodePathSource.VARIABLE and not node_variable_name.is_empty():
		dependencies.append(node_variable_name)

	return dependencies

# =============================================
# 条件信息
# =============================================

## 获取条件类型
func get_condition_type() -> String:
	return "child_count_check"

## 获取条件分类
func get_condition_category() -> String:
	return "node"

## 获取条件描述
func get_description() -> String:
	var node_str = _get_node_source_string()

	if node_str.is_empty():
		return FuseLocalization.translate("FUSE_CONDITION_CHILD_COUNT_DESC_NOT_SET")

	var recursive_str = ""
	if recursive:
		recursive_str = FuseLocalization.translate("FUSE_RECURSIVE")

	return "%s.child_count%s %s %d" % [node_str, recursive_str, _get_operator_string(), compare_value]

# =============================================
# 验证
# =============================================

## 验证条件
func validate() -> Array[String]:
	var errors = super.validate()

	# 根据节点路径来源验证
	if node_path_source == NodePathSource.NODE_PATH:
		if target_node_path.is_empty():
			var error_msg = FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_PATH_EMPTY")
			errors.append(error_msg)
	else:
		# VARIABLE 模式验证
		if node_variable_name.is_empty():
			var error_msg = FuseLocalization.translate("FUSE_ERROR_VAR_NAME_EMPTY")
			errors.append(error_msg)

		# 验证 SCOPE 作用域时才验证 ScopeSource 参数
		if node_variable_scope == BaseVariable.VariableScope.SCOPE:
			var utils_scope_source = node_scope_source as VariableScopeUtils.ScopeSource
			errors.append_array(VariableScopeUtils.validate_scope_source_params(
				utils_scope_source,
				node_custom_scope_id,
				node_target_node_path
			))

	return errors

# =============================================
# 参数方法
# =============================================

## 获取参数
func get_parameters() -> Dictionary:
	var params = {
		"node_path_source": node_path_source,
		"recursive": recursive,
		"comparison_operator": comparison_operator,
		"compare_value": compare_value
	}

	if node_path_source == NodePathSource.NODE_PATH:
		params["target_node_path"] = target_node_path
	else:
		params["node_variable_name"] = node_variable_name
		params["node_variable_scope"] = node_variable_scope

		if node_variable_scope == BaseVariable.VariableScope.SCOPE:
			params["node_scope_source"] = node_scope_source
			params["node_custom_scope_id"] = node_custom_scope_id
			params["node_target_node_path"] = node_target_node_path

	return params

## 设置参数
func set_parameters(parameters: Dictionary):
	if parameters.has("node_path_source"):
		node_path_source = parameters["node_path_source"]
	if parameters.has("target_node_path"):
		target_node_path = parameters["target_node_path"]
	if parameters.has("node_variable_name"):
		node_variable_name = parameters["node_variable_name"]
	if parameters.has("node_variable_scope"):
		node_variable_scope = parameters["node_variable_scope"]
	if parameters.has("node_scope_source"):
		node_scope_source = parameters["node_scope_source"]
	if parameters.has("node_custom_scope_id"):
		node_custom_scope_id = parameters["node_custom_scope_id"]
	if parameters.has("node_target_node_path"):
		node_target_node_path = parameters["node_target_node_path"]
	if parameters.has("recursive"):
		recursive = parameters["recursive"]
	if parameters.has("comparison_operator"):
		comparison_operator = parameters["comparison_operator"]
	if parameters.has("compare_value"):
		compare_value = parameters["compare_value"]

# =============================================
# 元数据
# =============================================

## 获取条件元数据
static func _get_condition_metadata() -> ConditionMetadata:
	var metadata = ConditionMetadata.new()
	metadata.name_key = "FUSE_CONDITION_CHILD_COUNT_NAME"
	metadata.category_key = "FUSE_CATEGORY_NODE_OPERATIONS"
	metadata.description_key = "FUSE_CONDITION_CHILD_COUNT_DESC"
	metadata.keywords = ["子节点", "数量", "递归", "child", "count", "recursive", "检查", "check"]
	metadata.builtin_icon = "Children"
	return metadata
