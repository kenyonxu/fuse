@tool
@icon("res://addons/fuse/icons/builtin/Array.svg")
class_name CheckArrayContains extends BaseCondition
## 检查数组包含元素条件类
##
## 用于检查数组是否包含指定的元素值。
## 支持从变量、节点子节点或节点组获取数组。
## 支持 Variant 类型的搜索值。

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

# 搜索值（要在数组中查找的元素）
@export var search_value: Variant:
	set(value):
		search_value = value
		_update_resource_name()
		_log_debug("Search value set to: %s" % str(value))

## 私有属性
var _last_array: Variant = null
var _last_contains_result: bool = false

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
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

	# ========== Search Configuration ==========
	properties.append({
		name = "Search Configuration",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 注意：search_value 使用 @export 声明，不在 _get_property_list() 中添加

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
	var search_str := str(search_value)
	if search_str.length() > 15:
		search_str = search_str.substr(0, 12) + "..."

	match source_type:
		SourceType.VARIABLE:
			if array_variable.is_empty():
				source_str = FuseLocalization.translate("FUSE_CONDITION_ARRAY_CONTAINS_NO_ARRAY")
			else:
				var scope_str = _get_scope_source_string()
				source_str = "%s [%s]" % [array_variable, scope_str]
		SourceType.NODE_CHILDREN:
			if target_node_path.is_empty():
				source_str = FuseLocalization.translate("FUSE_CONDITION_ARRAY_CONTAINS_NO_NODE")
			else:
				source_str = FuseLocalization.translate_format("FUSE_CONDITION_ARRAY_CONTAINS_NODE_CHILDREN", {"path": _get_node_display_name(target_node_path)})
		SourceType.NODE_GROUP:
			if group_name.is_empty():
				source_str = FuseLocalization.translate("FUSE_CONDITION_ARRAY_CONTAINS_NO_GROUP")
			else:
				source_str = FuseLocalization.translate_format("FUSE_CONDITION_ARRAY_CONTAINS_GROUP", {"name": group_name})

	resource_name = FuseLocalization.translate_format(
		"FUSE_CONDITION_ARRAY_CONTAINS_FORMAT",
		{"source": source_str, "value": search_str}
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
	# 获取数组
	var array_value := _get_array(context)
	_last_array = array_value

	# 如果无法获取数组，返回 false
	if array_value == null:
		_log_error("Failed to get array")
		return false

	# 检查是否为数组类型
	if not _is_array_type(array_value):
		_log_warning("Value is not an array type (type: %s)" % typeof(array_value))
		return false

	# 记录调试信息
	_log_debug("Checking array contains: search_value=%s, array_size=%d" % [
		str(search_value), array_value.size()
	])

	# 执行包含检查
	var result := _check_contains(array_value)
	_last_contains_result = result

	_log_debug("Contains check result: %s" % ("true" if result else "false"))
	return result

## 获取数组
func _get_array(context: ExecutionContext) -> Variant:
	match source_type:
		SourceType.VARIABLE:
			return _get_variable_array(context)
		SourceType.NODE_CHILDREN:
			return _get_node_children_array(context)
		SourceType.NODE_GROUP:
			return _get_node_group_array(context)

	return null

## 获取变量数组
func _get_variable_array(context: ExecutionContext) -> Variant:
	if array_variable.is_empty():
		_log_error("Array variable name is empty")
		return null

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
		return null

	return array_value

## 检查是否为数组类型
func _is_array_type(value: Variant) -> bool:
	return value is Array or _is_packed_array(value)

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

## 获取节点子节点数组
func _get_node_children_array(context: ExecutionContext) -> Variant:
	if target_node_path.is_empty():
		_log_error("Target node path is empty")
		return null

	var trigger = context.trigger
	if trigger == null:
		_log_error("Trigger is null")
		return null

	var target_node = trigger.get_node(target_node_path)
	if target_node == null:
		_log_error("Target node not found: %s" % str(target_node_path))
		return null

	return target_node.get_children()

## 获取节点组数组
func _get_node_group_array(context: ExecutionContext) -> Variant:
	if group_name.is_empty():
		_log_error("Group name is empty")
		return null

	var node_tree = context.get_node_tree()
	if not node_tree:
		_log_error("Cannot get scene tree")
		return null

	return node_tree.get_nodes_in_group(group_name)

## 执行包含检查
func _check_contains(array_value: Variant) -> bool:
	# 使用 `in` 操作符检查元素是否存在
	# 对于 Array 和 PackedArray 都支持
	return search_value in array_value

## 获取条件类型
func get_condition_type() -> String:
	return "check_array_contains"

## 获取条件分类
func get_condition_category() -> String:
	return "arrays"

## 声明变量读写模式（精确化静态分析）
## array_variable 仅 read（_evaluate_condition 中读取数组并查找 search_value）
func get_variable_modes() -> Array[Dictionary]:
	return [
		{"name": "array_variable", "mode": "read"},
	]

## 获取条件描述
func get_description() -> String:
	var source_str := ""
	var search_str := str(search_value)

	match source_type:
		SourceType.VARIABLE:
			if array_variable.is_empty():
				source_str = FuseLocalization.translate("FUSE_CONDITION_ARRAY_CONTAINS_NO_ARRAY")
			else:
				var scope_str = _get_scope_source_string()
				source_str = "%s [%s]" % [array_variable, scope_str]
		SourceType.NODE_CHILDREN:
			source_str = FuseLocalization.translate("FUSE_CONDITION_ARRAY_CONTAINS_NODE_CHILDREN")
		SourceType.NODE_GROUP:
			if group_name.is_empty():
				source_str = FuseLocalization.translate("FUSE_CONDITION_ARRAY_CONTAINS_NO_GROUP")
			else:
				source_str = "Group:%s" % group_name

	return "%s contains %s" % [source_str, search_str]

## 获取条件参数
func get_parameters() -> Dictionary:
	var params = {
		"source_type": source_type,
		"search_value": search_value
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
	info["search_value"] = str(search_value)
	info["last_array_size"] = _last_array.size() if _last_array != null and _is_array_type(_last_array) else -1
	info["last_contains_result"] = _last_contains_result

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
	_last_array = null
	_last_contains_result = false
	_log_debug("CheckArrayContains condition reset")

## 计算线程安全性
## CheckArrayContains 只有在 VARIABLE + LOCAL/GLOBAL 模式下才安全
func _compute_thread_safety() -> bool:
	if _thread_safety_computed:
		return _thread_safety_cached

	var is_safe := false

	if source_type == SourceType.VARIABLE:
		match array_scope:
			BaseVariable.VariableScope.LOCAL, BaseVariable.VariableScope.GLOBAL:
				is_safe = true
			BaseVariable.VariableScope.SCOPE:
				is_safe = false

	_thread_safety_cached = is_safe
	_thread_safety_computed = true
	return _thread_safety_cached

## 获取条件元数据
static func _get_condition_metadata() -> ConditionMetadata:
	var metadata = ConditionMetadata.new()
	metadata.name_key = "FUSE_CONDITION_ARRAY_CONTAINS_NAME"
	metadata.category_key = "FUSE_CATEGORY_ARRAYS"
	metadata.description_key = "FUSE_CONDITION_ARRAY_CONTAINS_DESC"
	metadata.keywords = ["array", "数组", "contains", "包含", "has", "存在", "search", "搜索", "condition", "条件", "check", "检查"]
	metadata.builtin_icon = "Array"
	return metadata
