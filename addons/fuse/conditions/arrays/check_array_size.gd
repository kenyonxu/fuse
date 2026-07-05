@tool
@icon("res://addons/fuse/icons/builtin/Array.svg")
class_name CheckArraySize extends BaseCondition
## 检查数组大小条件类
##
## 用于检查数组大小与给定值的比较结果。
## 支持从变量、节点子节点或节点组获取数组。
## 支持多种比较操作符。

## 比较操作符枚举
enum Comparison {
	EQUALS,           ## 等于 (==)
	NOT_EQUALS,       ## 不等于 (!=)
	GREATER_THAN,     ## 大于 (>)
	LESS_THAN,        ## 小于 (<)
	GREATER_OR_EQUAL, ## 大于等于 (>=)
	LESS_OR_EQUAL     ## 小于等于 (<=)
}

## 作用域来源枚举（仅在 array_scope == SCOPE 时使用）
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

## 源类型枚举
enum SourceType {
	VARIABLE,       ## 数组变量
	NODE_CHILDREN,  ## 节点子节点
	NODE_GROUP      ## 节点组
}

# 源类型
var source_type: SourceType = SourceType.VARIABLE:
	set(value):
		if source_type != value:
			source_type = value
			_update_resource_name()
			notify_property_list_changed()

# 数组变量名（当源类型为 VARIABLE 时使用）
var array_variable: String = "":
	set(value):
		if array_variable != value:
			array_variable = value
			_update_resource_name()
			_log_debug("Array variable set to: %s" % value)

# 数组变量作用域
var array_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		if array_scope != value:
			array_scope = value
			_update_resource_name()
			notify_property_list_changed()

## 数组作用域来源（仅当 array_scope == SCOPE 时使用）
var array_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		if array_scope_source != value:
			array_scope_source = value
			_update_resource_name()
			notify_property_list_changed()

## 自定义数组作用域 ID（CUSTOM_ID 模式使用）
var array_custom_scope_id: String = "":
	set(value):
		if array_custom_scope_id != value:
			array_custom_scope_id = value
			_update_resource_name()

## 数组目标节点路径（TARGET_NODE 模式使用）
var array_target_node_path: NodePath = NodePath(""):
	set(value):
		if array_target_node_path != value:
			array_target_node_path = value
			_update_resource_name()

# 节点组名（当源类型为 NODE_GROUP 时使用）
var group_name: String = "":
	set(value):
		if group_name != value:
			group_name = value
			_update_resource_name()

# 目标节点路径（当源类型为 NODE_CHILDREN 时使用）
var target_node_path: NodePath = NodePath(""):
	set(value):
		if target_node_path != value:
			target_node_path = value
			_update_resource_name()

# 比较操作符
var comparison: Comparison = Comparison.EQUALS:
	set(value):
		if comparison != value:
			comparison = value
			_update_resource_name()
			_log_debug("Comparison set to: %s" % Comparison.keys()[value])

# 比较值
@export var compare_value: int = 0:
	set(value):
		compare_value = value
		_update_resource_name()
		_log_debug("Compare value set to: %d" % value)

## 私有属性
var _last_array_size: int = -1
var _last_comparison_result: bool = false

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties := []

	# ========== Source Configuration ==========
	properties.append({
		name = "Source Configuration",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "source_type",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Variable,NodeChildren,NodeGroup",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 数组变量名（当源类型为 VARIABLE 时显示）
	if source_type == SourceType.VARIABLE:
		properties.append({
			name = "array_variable",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 数组作用域
		properties.append({
			name = "array_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 只在 array_scope == SCOPE 时显示数组 ScopeSource 配置
		if array_scope == BaseVariable.VariableScope.SCOPE:
			properties.append({
				name = "Array Scope Configuration",
				type = TYPE_NIL,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_CATEGORY
			})

			properties.append({
				name = "array_scope_source",
				type = TYPE_INT,
				hint = PROPERTY_HINT_ENUM,
				hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

			# 根据作用域来源添加额外属性
			if array_scope_source == ScopeSource.CUSTOM_ID:
				properties.append({
					name = "array_custom_scope_id",
					type = TYPE_STRING,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})
			elif array_scope_source == ScopeSource.TARGET_NODE:
				properties.append({
					name = "array_target_node_path",
					type = TYPE_NODE_PATH,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})

	# 节点路径（当源类型为 NODE_CHILDREN 时显示）
	if source_type == SourceType.NODE_CHILDREN:
		properties.append({
			name = "target_node_path",
			type = TYPE_NODE_PATH,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

	# 节点组名（当源类型为 NODE_GROUP 时显示）
	if source_type == SourceType.NODE_GROUP:
		properties.append({
			name = "group_name",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

	# ========== Comparison Configuration ==========
	properties.append({
		name = "Comparison Configuration",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "comparison",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Equals,Not Equals,Greater Than,Less Than,Greater Or Equal,Less Or Equal",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 注意：compare_value 使用 @export 声明，不在 _get_property_list() 中添加

	return properties

## 验证属性可见性
func _validate_property(property: Dictionary) -> void:
	# 当源类型为 VARIABLE 时隐藏节点相关属性
	if source_type == SourceType.VARIABLE:
		if property.name in ["group_name", "target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	# 当源类型为 NODE_CHILDREN 时隐藏变量和组名
	if source_type == SourceType.NODE_CHILDREN:
		if property.name in ["array_variable", "array_scope", "group_name", "array_scope_source", "array_custom_scope_id", "array_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	# 当源类型为 NODE_GROUP 时隐藏变量名和节点路径
	if source_type == SourceType.NODE_GROUP:
		if property.name in ["array_variable", "array_scope", "target_node_path", "array_scope_source", "array_custom_scope_id", "array_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	# 数组作用域相关属性
	if source_type == SourceType.VARIABLE:
		if array_scope == BaseVariable.VariableScope.SCOPE:
			if property.name == "array_scope_source":
				return  # 始终显示
			elif property.name == "array_custom_scope_id":
				if array_scope_source != ScopeSource.CUSTOM_ID:
					property.usage = PROPERTY_USAGE_NO_EDITOR
			elif property.name == "array_target_node_path":
				if array_scope_source != ScopeSource.TARGET_NODE:
					property.usage = PROPERTY_USAGE_NO_EDITOR
		else:
			if property.name in ["array_scope_source", "array_custom_scope_id", "array_target_node_path"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		if property.name.begins_with("array_"):
			property.usage = PROPERTY_USAGE_NO_EDITOR

## 更新资源名称
func _update_resource_name():
	var source_str := ""
	var comp_op: String = Comparison.keys()[comparison]

	match source_type:
		SourceType.VARIABLE:
			if array_variable.is_empty():
				source_str = FuseLocalization.translate("FUSE_CONDITION_ARRAY_SIZE_NO_ARRAY")
			else:
				var scope_str = _get_scope_source_string()
				source_str = "%s [%s]" % [array_variable, scope_str]
		SourceType.NODE_CHILDREN:
			if target_node_path.is_empty():
				source_str = FuseLocalization.translate("FUSE_CONDITION_ARRAY_SIZE_NO_NODE")
			else:
				source_str = FuseLocalization.translate_format("FUSE_CONDITION_ARRAY_SIZE_NODE_CHILDREN", {"path": _get_node_display_name(target_node_path)})
		SourceType.NODE_GROUP:
			if group_name.is_empty():
				source_str = FuseLocalization.translate("FUSE_CONDITION_ARRAY_SIZE_NO_GROUP")
			else:
				source_str = FuseLocalization.translate_format("FUSE_CONDITION_ARRAY_SIZE_GROUP", {"name": group_name})

	resource_name = FuseLocalization.translate_format(
		"FUSE_CONDITION_ARRAY_SIZE_FORMAT",
		{"source": source_str, "op": comp_op, "value": str(compare_value)}
	)

	_description = resource_name

## 获取作用域来源字符串
func _get_scope_source_string() -> String:
	var scope_type_str: String
	match array_scope:
		BaseVariable.VariableScope.LOCAL:
			scope_type_str = FuseLocalization.translate("FUSE_SCOPE_LOCAL_STR")
		BaseVariable.VariableScope.SCOPE:
			scope_type_str = VariableScopeUtils.get_scope_source_string(
				array_scope_source as VariableScopeUtils.ScopeSource,
				array_custom_scope_id,
				array_target_node_path
			)
		BaseVariable.VariableScope.GLOBAL:
			scope_type_str = FuseLocalization.translate("FUSE_SCOPE_GLOBAL_STR")
		_:
			scope_type_str = FuseLocalization.translate("FUSE_SCOPE_UNKNOWN_STR")

	return scope_type_str

## 评估条件
func _evaluate_condition(context: ExecutionContext) -> bool:
	# 获取数组大小
	var array_size := _get_array_size(context)
	_last_array_size = array_size

	# 如果无法获取数组大小，返回 false
	if array_size < 0:
		_log_error("Failed to get array size")
		return false

	# 记录调试信息
	_log_debug("Checking array size: actual=%d, compare=%d, operator=%s" % [
		array_size, compare_value, Comparison.keys()[comparison]
	])

	# 执行比较
	var result := _perform_comparison(array_size, compare_value)
	_last_comparison_result = result

	_log_debug("Comparison result: %s" % ("true" if result else "false"))
	return result

## 获取数组大小
func _get_array_size(context: ExecutionContext) -> int:
	match source_type:
		SourceType.VARIABLE:
			return _get_variable_array_size(context)
		SourceType.NODE_CHILDREN:
			return _get_node_children_count(context)
		SourceType.NODE_GROUP:
			return _get_node_group_count(context)

	return -1

## 获取变量数组大小
func _get_variable_array_size(context: ExecutionContext) -> int:
	if array_variable.is_empty():
		_log_error("Array variable name is empty")
		return -1

	var array_value: Variant = null

	match array_scope:
		BaseVariable.VariableScope.LOCAL:
			array_value = VariableOperations.get_variable(context, array_variable, BaseVariable.VariableScope.LOCAL, null)

		BaseVariable.VariableScope.GLOBAL:
			array_value = VariableOperations.get_variable(context, array_variable, BaseVariable.VariableScope.GLOBAL, null)

		BaseVariable.VariableScope.SCOPE:
			if array_scope_source == ScopeSource.NEAREST:
				array_value = VariableOperations.get_variable(context, array_variable, BaseVariable.VariableScope.SCOPE, null)
			else:
				var utils_scope_source = array_scope_source as VariableScopeUtils.ScopeSource
				var scope_container = VariableScopeUtils.get_scope_container_by_source(
					context,
					utils_scope_source,
					array_custom_scope_id,
					array_target_node_path
				)
				if scope_container != null and scope_container.has_variable(array_variable):
					array_value = scope_container.get_variable(array_variable)

	if array_value == null:
		_log_debug("Array variable '%s' is null" % array_variable)
		return -1

	if array_value is Array:
		return array_value.size()
	elif _is_packed_array(array_value):
		return array_value.size()
	else:
		_log_warning("Variable '%s' is not an array type (type: %s)" % [array_variable, typeof(array_value)])
		return -1

## 检查是否为 PackedArray 类型
func _is_packed_array(value: Variant) -> bool:
	return value is PackedInt32Array or \
		value is PackedInt64Array or \
		value is PackedFloat32Array or \
		value is PackedFloat64Array or \
		value is PackedByteArray or \
		value is PackedVector2Array or \
		value is PackedVector3Array or \
		value is PackedColorArray or \
		value is PackedStringArray

## 获取节点子节点数量
func _get_node_children_count(context: ExecutionContext) -> int:
	if target_node_path.is_empty():
		_log_error("Target node path is empty")
		return -1

	var trigger = context.trigger
	if trigger == null:
		_log_error("Trigger is null")
		return -1

	var target_node = trigger.get_node(target_node_path)
	if target_node == null:
		_log_error("Target node not found: %s" % str(target_node_path))
		return -1

	return target_node.get_child_count()

## 获取节点组数量
func _get_node_group_count(context: ExecutionContext) -> int:
	if group_name.is_empty():
		_log_error("Group name is empty")
		return -1

	var node_tree = context.get_node_tree()
	if not node_tree:
		_log_error("Cannot get scene tree")
		return -1

	var items: Array = node_tree.get_nodes_in_group(group_name)
	return items.size()

## 执行比较
func _perform_comparison(actual: int, expected: int) -> bool:
	match comparison:
		Comparison.EQUALS:
			return actual == expected
		Comparison.NOT_EQUALS:
			return actual != expected
		Comparison.GREATER_THAN:
			return actual > expected
		Comparison.LESS_THAN:
			return actual < expected
		Comparison.GREATER_OR_EQUAL:
			return actual >= expected
		Comparison.LESS_OR_EQUAL:
			return actual <= expected
		_:
			_log_error("Unknown comparison operator: %s" % Comparison.keys()[comparison])
			return false

## 获取条件类型
func get_condition_type() -> String:
	return "check_array_size"

## 获取条件分类
func get_condition_category() -> String:
	return "arrays"

## 获取条件描述
func get_description() -> String:
	var source_str := ""
	var comp_op: String = Comparison.keys()[comparison]

	match source_type:
		SourceType.VARIABLE:
			if array_variable.is_empty():
				source_str = FuseLocalization.translate("FUSE_CONDITION_ARRAY_SIZE_NO_ARRAY")
			else:
				var scope_str = _get_scope_source_string()
				source_str = "%s [%s]" % [array_variable, scope_str]
		SourceType.NODE_CHILDREN:
			source_str = FuseLocalization.translate("FUSE_CONDITION_ARRAY_SIZE_NODE_CHILDREN")
		SourceType.NODE_GROUP:
			if group_name.is_empty():
				source_str = FuseLocalization.translate("FUSE_CONDITION_ARRAY_SIZE_NO_GROUP")
			else:
				source_str = "Group:%s" % group_name

	return "%s %s %d" % [source_str, comp_op, compare_value]

## 获取条件参数
func get_parameters() -> Dictionary:
	var params = {
		"source_type": source_type,
		"comparison": comparison,
		"compare_value": compare_value
	}

	if source_type == SourceType.VARIABLE:
		params["array_variable"] = array_variable
		params["array_scope"] = array_scope
		if array_scope == BaseVariable.VariableScope.SCOPE:
			params["array_scope_source"] = array_scope_source
			params["array_custom_scope_id"] = array_custom_scope_id
			params["array_target_node_path"] = array_target_node_path
	elif source_type == SourceType.NODE_CHILDREN:
		params["target_node_path"] = target_node_path
	elif source_type == SourceType.NODE_GROUP:
		params["group_name"] = group_name

	return params

## 计算条件依赖
func _compute_dependencies() -> Array[String]:
	var dependencies: Array[String] = []

	if source_type == SourceType.VARIABLE and not array_variable.is_empty():
		dependencies.append(array_variable)

	return dependencies

## 验证条件
func validate() -> Array[String]:
	var errors = super.validate()

	match source_type:
		SourceType.VARIABLE:
			if array_variable.is_empty():
				var error_msg = FuseLocalization.translate("FUSE_ERROR_ARRAY_VARIABLE_EMPTY")
				errors.append(error_msg)
				_create_fuse_error(error_msg, FuseError.ErrorType.VALIDATION_ERROR)

			# 验证 SCOPE 作用域时才验证 ScopeSource 参数
			if array_scope == BaseVariable.VariableScope.SCOPE:
				var utils_scope_source = array_scope_source as VariableScopeUtils.ScopeSource
				errors.append_array(VariableScopeUtils.validate_scope_source_params(
					utils_scope_source,
					array_custom_scope_id,
					array_target_node_path
				))

		SourceType.NODE_CHILDREN:
			if target_node_path.is_empty():
				var error_msg = FuseLocalization.translate("FUSE_ERROR_NODE_PATH_EMPTY")
				errors.append(error_msg)
				_create_fuse_error(error_msg, FuseError.ErrorType.VALIDATION_ERROR)

		SourceType.NODE_GROUP:
			if group_name.is_empty():
				var error_msg = FuseLocalization.translate("FUSE_ERROR_GROUP_NAME_EMPTY")
				errors.append(error_msg)
				_create_fuse_error(error_msg, FuseError.ErrorType.VALIDATION_ERROR)

	return errors

## 获取详细条件信息
func get_detailed_info() -> Dictionary:
	var info = super.get_detailed_info()
	info["source_type"] = SourceType.keys()[source_type]
	info["comparison"] = Comparison.keys()[comparison]
	info["compare_value"] = compare_value
	info["last_array_size"] = _last_array_size
	info["last_comparison_result"] = _last_comparison_result

	if source_type == SourceType.VARIABLE:
		info["array_variable"] = array_variable
		info["array_scope"] = BaseVariable.VariableScope.keys()[array_scope]
		if array_scope == BaseVariable.VariableScope.SCOPE:
			info["array_scope_source"] = ScopeSource.keys()[array_scope_source]
			info["array_custom_scope_id"] = array_custom_scope_id
			info["array_target_node_path"] = str(array_target_node_path)
	elif source_type == SourceType.NODE_CHILDREN:
		info["target_node_path"] = str(target_node_path)
	elif source_type == SourceType.NODE_GROUP:
		info["group_name"] = group_name

	return info

## 重置条件状态
func reset():
	super.reset()
	_last_array_size = -1
	_last_comparison_result = false
	_log_debug("CheckArraySize condition reset")

## 计算线程安全性
## CheckArraySize 只有在 VARIABLE + LOCAL/GLOBAL 模式下才安全
## NODE_CHILDREN 和 NODE_GROUP 模式需要访问节点或 SceneTree
func _compute_thread_safety() -> bool:
	if _thread_safety_computed:
		return _thread_safety_cached

	var is_safe := false

	if source_type == SourceType.VARIABLE:
		# 只有 LOCAL 和 GLOBAL 作用域是线程安全的
		match array_scope:
			BaseVariable.VariableScope.LOCAL, BaseVariable.VariableScope.GLOBAL:
				is_safe = true
			BaseVariable.VariableScope.SCOPE:
				is_safe = false  # SCOPE 需要 ExecutionContext

	_thread_safety_cached = is_safe
	_thread_safety_computed = true
	return _thread_safety_cached

## 获取条件元数据
static func _get_condition_metadata() -> ConditionMetadata:
	var metadata = ConditionMetadata.new()
	metadata.name_key = "FUSE_CONDITION_ARRAY_SIZE_NAME"
	metadata.category_key = "FUSE_CATEGORY_ARRAYS"
	metadata.description_key = "FUSE_CONDITION_ARRAY_SIZE_DESC"
	metadata.keywords = ["array", "数组", "size", "大小", "length", "长度", "count", "数量", "condition", "条件", "check", "检查"]
	metadata.builtin_icon = "Array"
	return metadata
