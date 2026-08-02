@tool
@icon("res://addons/fuse/icons/builtin/GroupList.svg")
extends BaseCondition
class_name CheckGroupCount

## 组成员数量检查条件
##
## 检查指定 SceneTree 组中的成员数量与期望值的比较关系。
##
## 支持两种组名来源：
## - DIRECT: 直接输入组名
## - VARIABLE: 从变量获取组名（支持三层变量作用域）

## 组名来源枚举
enum GroupNameSource {
	DIRECT,    ## 直接输入组名
	VARIABLE   ## 从变量获取组名
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

## 作用域来源枚举（仅在 group_variable_scope == SCOPE 时使用）
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

# =============================================
# 参数定义
# =============================================

## 组名来源
var group_name_source: GroupNameSource = GroupNameSource.DIRECT:
	set(value):
		group_name_source = value
		_update_resource_name()
		notify_property_list_changed()

## 组名（当 group_name_source == DIRECT 时使用）
var group_name: String = "":
	set(value):
		group_name = value
		_update_resource_name()

## 组名变量名（当 group_name_source == VARIABLE 时使用）
var group_variable_name: String = "":
	set(value):
		group_variable_name = value
		_update_resource_name()

## 组名变量作用域（三层变量系统）
var group_variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		group_variable_scope = value
		_update_resource_name()
		notify_property_list_changed()

## 组名变量作用域来源（仅当 group_variable_scope == SCOPE 时使用）
var group_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		group_scope_source = value
		_update_resource_name()
		notify_property_list_changed()

## 组名变量自定义作用域 ID（仅当 group_scope_source == CUSTOM_ID 时使用）
var group_custom_scope_id: String = "":
	set(value):
		group_custom_scope_id = value
		_update_resource_name()

## 组名变量目标节点路径（仅当 group_scope_source == TARGET_NODE 时使用）
var group_target_node_path: NodePath = NodePath(""):
	set(value):
		group_target_node_path = value
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
	var properties: Array[Dictionary] = []
	# ========== 组配置 ==========
	properties.append({
		name = "Group Configuration",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 组名来源
	properties.append({
		name = "group_name_source",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Direct,Variable",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 根据组名来源显示不同属性
	if group_name_source == GroupNameSource.DIRECT:
		# 直接输入组名
		properties.append({
			name = "group_name",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
	else:
		# 变量模式
		properties.append({
			name = "group_variable_name",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 变量作用域
		properties.append({
			name = "group_variable_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 只在 group_variable_scope == SCOPE 时显示 ScopeSource 配置
		if group_variable_scope == BaseVariable.VariableScope.SCOPE:
			properties.append({
				name = "group_scope_source",
				type = TYPE_INT,
				hint = PROPERTY_HINT_ENUM,
				hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

			# 根据作用域来源添加额外属性
			if group_scope_source == ScopeSource.CUSTOM_ID:
				properties.append({
					name = "group_custom_scope_id",
					type = TYPE_STRING,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})
			elif group_scope_source == ScopeSource.TARGET_NODE:
				properties.append({
					name = "group_target_node_path",
					type = TYPE_NODE_PATH,
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
	# 控制组名来源相关属性可见性
	if group_name_source == GroupNameSource.DIRECT:
		# DIRECT 模式：隐藏变量相关属性
		if property.name in ["group_variable_name", "group_variable_scope", "group_scope_source", "group_custom_scope_id", "group_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		# VARIABLE 模式：隐藏组名属性
		if property.name == "group_name":
			property.usage = PROPERTY_USAGE_NO_EDITOR

		# 控制变量 ScopeSource 属性可见性
		if group_variable_scope == BaseVariable.VariableScope.SCOPE:
			VariableScopeUtils.validate_scope_source_property(property, group_scope_source as VariableScopeUtils.ScopeSource)
		else:
			# 非 SCOPE 作用域时隐藏 ScopeSource 相关属性
			if property.name in ["group_scope_source", "group_custom_scope_id", "group_target_node_path"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR

# =============================================
# 资源名称和描述
# =============================================

## 更新资源名称（必需）
func _update_resource_name() -> void:
	var group_str = _get_group_source_string()
	var op_str = _get_operator_string()

	if group_str.is_empty():
		resource_name = FuseLocalization.translate("FUSE_CONDITION_GROUP_COUNT_NOT_SET")
	else:
		resource_name = "%s %s %d" % [group_str, op_str, compare_value]

## 获取组名来源显示字符串
func _get_group_source_string() -> String:
	if group_name_source == GroupNameSource.DIRECT:
		if group_name.is_empty():
			return ""
		return "Group('%s')" % group_name
	else:
		if group_variable_name.is_empty():
			return ""
		var scope_str = _get_group_scope_source_string()
		return "Group([%s] %s)" % [scope_str, group_variable_name]

## 获取组名变量作用域来源字符串
func _get_group_scope_source_string() -> String:
	match group_variable_scope:
		BaseVariable.VariableScope.LOCAL:
			return FuseLocalization.translate("FUSE_SCOPE_LOCAL_STR")
		BaseVariable.VariableScope.SCOPE:
			return VariableScopeUtils.get_scope_source_string(
				group_scope_source as VariableScopeUtils.ScopeSource,
				group_custom_scope_id,
				group_target_node_path
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
	# 获取组名
	var actual_group_name = _get_group_name(context)
	if actual_group_name.is_empty():
		var error_msg = FuseLocalization.translate("FUSE_ERROR_GROUP_NAME_EMPTY")
		_log_error(error_msg)
		_create_fuse_error(error_msg, FuseError.ErrorType.VALIDATION_ERROR)
		return false

	# 获取场景树
	var tree = _get_scene_tree(context)
	if tree == null:
		var error_msg = FuseLocalization.translate("FUSE_ERROR_SCENE_TREE_NOT_FOUND")
		_log_error(error_msg)
		_create_fuse_error(error_msg, FuseError.ErrorType.RUNTIME_ERROR)
		return false

	# 获取组中的节点数量
	var nodes_in_group = tree.get_nodes_in_group(actual_group_name)
	var actual_count = nodes_in_group.size()

	# 执行比较
	var result = _perform_comparison(actual_count, compare_value)

	# 记录日志
	_log_debug(FuseLocalization.translate_format(
		"FUSE_LOG_GROUP_COUNT_CHECK",
		{
			"group": actual_group_name,
			"count": actual_count,
			"op": _get_operator_string(),
			"expected": compare_value,
			"result": "true" if result else "false"
		}
	))

	return result

## 获取组名
func _get_group_name(context: ExecutionContext) -> String:
	if group_name_source == GroupNameSource.DIRECT:
		return group_name
	else:
		return _get_group_name_from_variable(context)

## 从变量获取组名
func _get_group_name_from_variable(context: ExecutionContext) -> String:
	if group_variable_name.is_empty():
		return ""

	var value = _get_group_variable_value(context)

	if value == null:
		return ""

	if value is String:
		return value
	elif value is StringName:
		return str(value)
	else:
		_log_warning("组名变量类型无效: %s (期望 String)" % str(typeof(value)))
		return ""

## 获取组名变量值
func _get_group_variable_value(context: ExecutionContext) -> Variant:
	var value: Variant = null

	match group_variable_scope:
		BaseVariable.VariableScope.LOCAL:
			value = VariableOperations.get_variable(context, group_variable_name, BaseVariable.VariableScope.LOCAL, null)

		BaseVariable.VariableScope.GLOBAL:
			value = VariableOperations.get_variable(context, group_variable_name, BaseVariable.VariableScope.GLOBAL, null)

		BaseVariable.VariableScope.SCOPE:
			if group_scope_source == ScopeSource.NEAREST:
				value = VariableOperations.get_variable(context, group_variable_name, BaseVariable.VariableScope.SCOPE, null)
			else:
				var utils_scope_source = group_scope_source as VariableScopeUtils.ScopeSource
				var scope_container = VariableScopeUtils.get_scope_container_by_source(
					context,
					utils_scope_source,
					group_custom_scope_id,
					group_target_node_path
				)

				if scope_container != null and scope_container.has_variable(group_variable_name):
					value = scope_container.get_variable(group_variable_name)

	return value

## 获取场景树
func _get_scene_tree(context: ExecutionContext) -> SceneTree:
	if context == null:
		return null

	# 尝试从 context 获取场景树
	if context.trigger != null and context.trigger.is_inside_tree():
		return context.trigger.get_tree()

	if context.target != null and context.target.is_inside_tree():
		return context.target.get_tree()

	# 回退到 Engine
	var engine_tree = Engine.get_main_loop()
	if engine_tree is SceneTree:
		return engine_tree

	return null

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
	if group_name_source == GroupNameSource.VARIABLE and not group_variable_name.is_empty():
		dependencies.append(group_variable_name)

	return dependencies

# =============================================
# 条件信息
# =============================================

## 声明变量读写模式（精确化静态分析）
## group_variable_name 仅 read（_evaluate_condition 中读取组名变量并查询组成员数）
func get_variable_modes() -> Array[Dictionary]:
	return [
		{"name": "group_variable_name", "mode": "read"},
	]

## 获取条件类型
func get_condition_type() -> String:
	return "group_count_check"

## 获取条件分类
func get_condition_category() -> String:
	return "node"

## 获取条件描述
func get_description() -> String:
	var group_str = _get_group_source_string()

	if group_str.is_empty():
		return FuseLocalization.translate("FUSE_CONDITION_GROUP_COUNT_DESC_NOT_SET")

	return "%s %s %d" % [group_str, _get_operator_string(), compare_value]

# =============================================
# 验证
# =============================================

## 验证条件
func validate() -> Array[String]:
	var errors = super.validate()

	# 根据组名来源验证
	if group_name_source == GroupNameSource.DIRECT:
		if group_name.is_empty():
			var error_msg = FuseLocalization.translate("FUSE_ERROR_GROUP_NAME_EMPTY")
			errors.append(error_msg)
	else:
		# VARIABLE 模式验证
		if group_variable_name.is_empty():
			var error_msg = FuseLocalization.translate("FUSE_ERROR_VAR_NAME_EMPTY")
			errors.append(error_msg)

		# 验证 SCOPE 作用域时才验证 ScopeSource 参数
		if group_variable_scope == BaseVariable.VariableScope.SCOPE:
			var utils_scope_source = group_scope_source as VariableScopeUtils.ScopeSource
			errors.append_array(VariableScopeUtils.validate_scope_source_params(
				utils_scope_source,
				group_custom_scope_id,
				group_target_node_path
			))

	return errors

# =============================================
# 参数方法
# =============================================

## 获取参数
func get_parameters() -> Dictionary:
	var params = {
		"group_name_source": group_name_source,
		"comparison_operator": comparison_operator,
		"compare_value": compare_value
	}

	if group_name_source == GroupNameSource.DIRECT:
		params["group_name"] = group_name
	else:
		params["group_variable_name"] = group_variable_name
		params["group_variable_scope"] = group_variable_scope

		if group_variable_scope == BaseVariable.VariableScope.SCOPE:
			params["group_scope_source"] = group_scope_source
			params["group_custom_scope_id"] = group_custom_scope_id
			params["group_target_node_path"] = group_target_node_path

	return params

## 设置参数
func set_parameters(parameters: Dictionary):
	if parameters.has("group_name_source"):
		group_name_source = parameters["group_name_source"]
	if parameters.has("group_name"):
		group_name = parameters["group_name"]
	if parameters.has("group_variable_name"):
		group_variable_name = parameters["group_variable_name"]
	if parameters.has("group_variable_scope"):
		group_variable_scope = parameters["group_variable_scope"]
	if parameters.has("group_scope_source"):
		group_scope_source = parameters["group_scope_source"]
	if parameters.has("group_custom_scope_id"):
		group_custom_scope_id = parameters["group_custom_scope_id"]
	if parameters.has("group_target_node_path"):
		group_target_node_path = parameters["group_target_node_path"]
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
	metadata.name_key = "FUSE_CONDITION_GROUP_COUNT_NAME"
	metadata.category_key = "FUSE_CATEGORY_NODE_OPERATIONS"
	metadata.description_key = "FUSE_CONDITION_GROUP_COUNT_DESC"
	metadata.keywords = ["组", "数量", "成员", "group", "count", "members", "检查", "check"]
	metadata.builtin_icon = "GroupList"
	return metadata
