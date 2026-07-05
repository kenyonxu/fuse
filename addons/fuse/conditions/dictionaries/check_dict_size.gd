@tool
@icon("res://addons/fuse/icons/builtin/Dictionary.svg")
class_name CheckDictSize extends BaseCondition
## 检查字典大小条件类
##
## 用于检查字典大小与给定值的比较结果。
## 支持从变量获取字典。
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

## 作用域来源枚举（仅在 dict_scope == SCOPE 时使用）
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

# 字典变量名
var dict_variable: String = "":
	set(value):
		if dict_variable != value:
			dict_variable = value
			_update_resource_name()
			_log_debug("Dict variable set to: %s" % value)

# 字典变量作用域
var dict_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		if dict_scope != value:
			dict_scope = value
			_update_resource_name()
			notify_property_list_changed()

## 字典作用域来源（仅当 dict_scope == SCOPE 时使用）
var dict_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		if dict_scope_source != value:
			dict_scope_source = value
			_update_resource_name()
			notify_property_list_changed()

## 自定义字典作用域 ID（CUSTOM_ID 模式使用）
var dict_custom_scope_id: String = "":
	set(value):
		if dict_custom_scope_id != value:
			dict_custom_scope_id = value
			_update_resource_name()

## 字典目标节点路径（TARGET_NODE 模式使用）
var dict_target_node_path: NodePath = NodePath(""):
	set(value):
		if dict_target_node_path != value:
			dict_target_node_path = value
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
var _last_dict_size: int = -1
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
		name = "dict_variable",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "dict_scope",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Local,Scope,Global",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 只在 dict_scope == SCOPE 时显示字典 ScopeSource 配置
	if dict_scope == BaseVariable.VariableScope.SCOPE:
		properties.append({
			name = "Dict Scope Configuration",
			type = TYPE_NIL,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_CATEGORY
		})

		properties.append({
			name = "dict_scope_source",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 根据作用域来源添加额外属性
		if dict_scope_source == ScopeSource.CUSTOM_ID:
			properties.append({
				name = "dict_custom_scope_id",
				type = TYPE_STRING,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})
		elif dict_scope_source == ScopeSource.TARGET_NODE:
			properties.append({
				name = "dict_target_node_path",
				type = TYPE_NODE_PATH,
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
	# 字典作用域相关属性
	if dict_scope == BaseVariable.VariableScope.SCOPE:
		if property.name == "dict_scope_source":
			return  # 始终显示
		elif property.name == "dict_custom_scope_id":
			if dict_scope_source != ScopeSource.CUSTOM_ID:
				property.usage = PROPERTY_USAGE_NO_EDITOR
		elif property.name == "dict_target_node_path":
			if dict_scope_source != ScopeSource.TARGET_NODE:
				property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		if property.name in ["dict_scope_source", "dict_custom_scope_id", "dict_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR

## 更新资源名称
func _update_resource_name():
	var scope_str := _get_scope_source_string()
	var comp_op: String = Comparison.keys()[comparison]

	if dict_variable.is_empty():
		resource_name = FuseLocalization.translate("FUSE_CONDITION_DICT_SIZE_NO_DICT")
	else:
		resource_name = FuseLocalization.translate_format(
			"FUSE_CONDITION_DICT_SIZE_FORMAT",
			{"source": "%s [%s]" % [dict_variable, scope_str], "op": comp_op, "value": str(compare_value)}
		)

	_description = resource_name

## 获取作用域来源字符串
func _get_scope_source_string() -> String:
	var scope_type_str: String
	match dict_scope:
		BaseVariable.VariableScope.LOCAL:
			scope_type_str = FuseLocalization.translate("FUSE_SCOPE_LOCAL_STR")
		BaseVariable.VariableScope.SCOPE:
			scope_type_str = VariableScopeUtils.get_scope_source_string(
				dict_scope_source as VariableScopeUtils.ScopeSource,
				dict_custom_scope_id,
				dict_target_node_path
			)
		BaseVariable.VariableScope.GLOBAL:
			scope_type_str = FuseLocalization.translate("FUSE_SCOPE_GLOBAL_STR")
		_:
			scope_type_str = FuseLocalization.translate("FUSE_SCOPE_UNKNOWN_STR")

	return scope_type_str

## 评估条件
func _evaluate_condition(context: ExecutionContext) -> bool:
	# 获取字典大小
	var dict_size := _get_dict_size(context)
	_last_dict_size = dict_size

	# 如果无法获取字典大小，返回 false
	if dict_size < 0:
		_log_error("Failed to get dict size")
		return false

	# 记录调试信息
	_log_debug("Checking dict size: actual=%d, compare=%d, operator=%s" % [
		dict_size, compare_value, Comparison.keys()[comparison]
	])

	# 执行比较
	var result := _perform_comparison(dict_size, compare_value)
	_last_comparison_result = result

	_log_debug("Comparison result: %s" % ("true" if result else "false"))
	return result

## 获取字典大小
func _get_dict_size(context: ExecutionContext) -> int:
	if dict_variable.is_empty():
		_log_error("Dict variable name is empty")
		return -1

	var dict_value: Variant = null

	match dict_scope:
		BaseVariable.VariableScope.LOCAL:
			dict_value = VariableOperations.get_variable(context, dict_variable, BaseVariable.VariableScope.LOCAL, null)

		BaseVariable.VariableScope.GLOBAL:
			dict_value = VariableOperations.get_variable(context, dict_variable, BaseVariable.VariableScope.GLOBAL, null)

		BaseVariable.VariableScope.SCOPE:
			if dict_scope_source == ScopeSource.NEAREST:
				dict_value = VariableOperations.get_variable(context, dict_variable, BaseVariable.VariableScope.SCOPE, null)
			else:
				var utils_scope_source = dict_scope_source as VariableScopeUtils.ScopeSource
				var scope_container = VariableScopeUtils.get_scope_container_by_source(
					context,
					utils_scope_source,
					dict_custom_scope_id,
					dict_target_node_path
				)
				if scope_container != null and scope_container.has_variable(dict_variable):
					dict_value = scope_container.get_variable(dict_variable)

	if dict_value == null:
		_log_debug("Dict variable '%s' is null" % dict_variable)
		return -1

	if dict_value is Dictionary:
		return dict_value.size()
	else:
		_log_warning("Variable '%s' is not a dictionary (type: %s)" % [dict_variable, typeof(dict_value)])
		return -1

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
	return "check_dict_size"

## 获取条件分类
func get_condition_category() -> String:
	return "dictionaries"

## 获取条件描述
func get_description() -> String:
	var scope_str = _get_scope_source_string()
	var comp_op: String = Comparison.keys()[comparison]

	if dict_variable.is_empty():
		return FuseLocalization.translate("FUSE_CONDITION_DICT_SIZE_NO_DICT")

	return "%s [%s] %s %d" % [dict_variable, scope_str, comp_op, compare_value]

## 获取条件参数
func get_parameters() -> Dictionary:
	var params = {
		"dict_variable": dict_variable,
		"dict_scope": dict_scope,
		"comparison": comparison,
		"compare_value": compare_value
	}

	if dict_scope == BaseVariable.VariableScope.SCOPE:
		params["dict_scope_source"] = dict_scope_source
		params["dict_custom_scope_id"] = dict_custom_scope_id
		params["dict_target_node_path"] = dict_target_node_path

	return params

## 计算条件依赖
func _compute_dependencies() -> Array[String]:
	var dependencies: Array[String] = []

	if not dict_variable.is_empty():
		dependencies.append(dict_variable)

	return dependencies

## 验证条件
func validate() -> Array[String]:
	var errors = super.validate()

	if dict_variable.is_empty():
		var error_msg = FuseLocalization.translate("FUSE_ERROR_DICT_VARIABLE_EMPTY")
		errors.append(error_msg)
		_create_fuse_error(error_msg, FuseError.ErrorType.VALIDATION_ERROR)

	# 验证 SCOPE 作用域时才验证 ScopeSource 参数
	if dict_scope == BaseVariable.VariableScope.SCOPE:
		var utils_scope_source = dict_scope_source as VariableScopeUtils.ScopeSource
		errors.append_array(VariableScopeUtils.validate_scope_source_params(
			utils_scope_source,
			dict_custom_scope_id,
			dict_target_node_path
		))

	return errors

## 获取详细条件信息
func get_detailed_info() -> Dictionary:
	var info = super.get_detailed_info()
	info["dict_variable"] = dict_variable
	info["dict_scope"] = BaseVariable.VariableScope.keys()[dict_scope]
	info["comparison"] = Comparison.keys()[comparison]
	info["compare_value"] = compare_value
	info["last_dict_size"] = _last_dict_size
	info["last_comparison_result"] = _last_comparison_result

	if dict_scope == BaseVariable.VariableScope.SCOPE:
		info["dict_scope_source"] = ScopeSource.keys()[dict_scope_source]
		info["dict_custom_scope_id"] = dict_custom_scope_id
		info["dict_target_node_path"] = str(dict_target_node_path)

	return info

## 重置条件状态
func reset():
	super.reset()
	_last_dict_size = -1
	_last_comparison_result = false
	_log_debug("CheckDictSize condition reset")

## 计算线程安全性
## CheckDictSize 只有在 VARIABLE + LOCAL/GLOBAL 模式下才安全
func _compute_thread_safety() -> bool:
	if _thread_safety_computed:
		return _thread_safety_cached

	var is_safe := false

	# 只有 LOCAL 和 GLOBAL 作用域是线程安全的
	match dict_scope:
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
	metadata.name_key = "FUSE_CONDITION_DICT_SIZE_NAME"
	metadata.category_key = "FUSE_CATEGORY_DICTIONARIES"
	metadata.description_key = "FUSE_CONDITION_DICT_SIZE_DESC"
	metadata.keywords = ["字典", "大小", "数量", "dictionary", "size", "count", "condition", "条件", "check", "检查"]
	metadata.builtin_icon = "Dictionary"
	return metadata
