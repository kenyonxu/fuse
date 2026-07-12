@tool
@icon("res://addons/fuse/icons/builtin/Dictionary.svg")
class_name CheckDictContainsKey extends BaseCondition
## 检查字典包含键条件类
##
## 用于检查字典是否包含指定的键。
## 支持键从变量获取或直接输入。
## 支持三种作用域 (LOCAL/SCOPE/GLOBAL)。
## SCOPE 作用域支持四种来源 (NEAREST/CUSTOM_ID/TRIGGER_SCOPE/TARGET_NODE)。

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

## 键是否来自变量
var use_key_from_variable: bool = false:
	set(value):
		if use_key_from_variable != value:
			use_key_from_variable = value
			_update_resource_name()
			notify_property_list_changed()

## 键源变量名（当 use_key_from_variable = true 时使用）
var key_from_variable: String = "":
	set(value):
		if key_from_variable != value:
			key_from_variable = value
			_update_resource_name()
			_log_debug("Key from variable set to: %s" % value)

## 键源变量作用域
var key_from_variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		if key_from_variable_scope != value:
			key_from_variable_scope = value
			_update_resource_name()
			notify_property_list_changed()

## 键源作用域来源（仅当 key_from_variable_scope == SCOPE 时使用）
var key_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		if key_scope_source != value:
			key_scope_source = value
			_update_resource_name()
			notify_property_list_changed()

## 键源自定义作用域 ID
var key_custom_scope_id: String = "":
	set(value):
		if key_custom_scope_id != value:
			key_custom_scope_id = value
			_update_resource_name()

## 键源目标节点路径
var key_target_node_path: NodePath = NodePath(""):
	set(value):
		if key_target_node_path != value:
			key_target_node_path = value
			_update_resource_name()

## 键值（直接输入，当 use_key_from_variable = false 时使用）
@export var key_value: Variant:
	set(value):
		key_value = value
		_update_resource_name()
		_log_debug("Key value set to: %s" % str(value))

## 私有属性
var _last_dict: Variant = null
var _last_key: Variant = null
var _last_contains_result: bool = false

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties := []

	# ========== Dictionary Configuration ==========
	properties.append({
		name = "Dictionary Configuration",
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
			name = "Dictionary Scope Configuration",
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

	# ========== Key Configuration ==========
	properties.append({
		name = "Key Configuration",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "use_key_from_variable",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 键值或键源变量
	if use_key_from_variable:
		properties.append({
			name = "key_from_variable",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		properties.append({
			name = "key_from_variable_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 只在 key_from_variable_scope == SCOPE 时显示 ScopeSource 配置
		if key_from_variable_scope == BaseVariable.VariableScope.SCOPE:
			properties.append({
				name = "Key Scope Configuration",
				type = TYPE_NIL,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_CATEGORY
			})

			properties.append({
				name = "key_scope_source",
				type = TYPE_INT,
				hint = PROPERTY_HINT_ENUM,
				hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

			# 根据作用域来源添加额外属性
			if key_scope_source == ScopeSource.CUSTOM_ID:
				properties.append({
					name = "key_custom_scope_id",
					type = TYPE_STRING,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})
			elif key_scope_source == ScopeSource.TARGET_NODE:
				properties.append({
					name = "key_target_node_path",
					type = TYPE_NODE_PATH,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})

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

	# 键变量相关属性
	if use_key_from_variable:
		if property.name == "key_value":
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		if property.name in ["key_from_variable", "key_from_variable_scope", "key_scope_source", "key_custom_scope_id", "key_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	# 键作用域相关属性
	if use_key_from_variable:
		if key_from_variable_scope == BaseVariable.VariableScope.SCOPE:
			if property.name == "key_scope_source":
				return  # 始终显示
			elif property.name == "key_custom_scope_id":
				if key_scope_source != ScopeSource.CUSTOM_ID:
					property.usage = PROPERTY_USAGE_NO_EDITOR
			elif property.name == "key_target_node_path":
				if key_scope_source != ScopeSource.TARGET_NODE:
					property.usage = PROPERTY_USAGE_NO_EDITOR
		else:
			if property.name in ["key_scope_source", "key_custom_scope_id", "key_target_node_path"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR

## 更新资源名称
func _update_resource_name():
	var dict_str := ""
	var key_str := ""

	# 字典信息
	if dict_variable.is_empty():
		dict_str = FuseLocalization.translate("FUSE_CONDITION_DICT_CONTAINS_KEY_NO_DICT")
	else:
		var scope_str = _get_dict_scope_source_string()
		dict_str = "%s [%s]" % [dict_variable, scope_str]

	# 键信息
	if use_key_from_variable:
		if key_from_variable.is_empty():
			key_str = FuseLocalization.translate("FUSE_CONDITION_DICT_CONTAINS_KEY_NO_KEY")
		else:
			key_str = "$%s" % key_from_variable
	else:
		var key_value_str = str(key_value)
		if key_value_str.length() > 15:
			key_value_str = key_value_str.substr(0, 12) + "..."
		key_str = key_value_str

	resource_name = FuseLocalization.translate_format(
		"FUSE_CONDITION_DICT_CONTAINS_KEY_FORMAT",
		{"dict": dict_str, "key": key_str}
	)

	_description = resource_name

## 获取字典作用域来源字符串
func _get_dict_scope_source_string() -> String:
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
	# 获取字典
	var dict_value := _get_dict(context)
	_last_dict = dict_value

	# 如果无法获取字典，返回 false
	if dict_value == null:
		_log_error("Failed to get dictionary")
		return false

	# 检查是否为字典类型
	if not dict_value is Dictionary:
		_log_warning("Value is not a dictionary type (type: %s)" % typeof(dict_value))
		return false

	# 获取键值
	var key: Variant = _get_key(context)
	_last_key = key

	# 记录调试信息
	_log_debug("Checking dict contains key: key=%s, dict_size=%d" % [
		str(key), dict_value.size()
	])

	# 执行包含检查
	var result: bool = dict_value.has(key)
	_last_contains_result = result

	_log_debug("Contains key check result: %s" % ("true" if result else "false"))
	return result

## 获取字典
func _get_dict(context: ExecutionContext) -> Variant:
	if dict_variable.is_empty():
		_log_error("Dict variable name is empty")
		return null

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
		return null

	return dict_value

## 获取键值
func _get_key(context: ExecutionContext) -> Variant:
	if use_key_from_variable:
		if key_from_variable.is_empty():
			_log_error("Key variable name is empty")
			return null

		var key: Variant = null

		match key_from_variable_scope:
			BaseVariable.VariableScope.LOCAL:
				key = VariableOperations.get_variable(context, key_from_variable, BaseVariable.VariableScope.LOCAL, null)

			BaseVariable.VariableScope.GLOBAL:
				key = VariableOperations.get_variable(context, key_from_variable, BaseVariable.VariableScope.GLOBAL, null)

			BaseVariable.VariableScope.SCOPE:
				if key_scope_source == ScopeSource.NEAREST:
					key = VariableOperations.get_variable(context, key_from_variable, BaseVariable.VariableScope.SCOPE, null)
				else:
					var utils_scope_source = key_scope_source as VariableScopeUtils.ScopeSource
					var scope_container = VariableScopeUtils.get_scope_container_by_source(
						context,
						utils_scope_source,
						key_custom_scope_id,
						key_target_node_path
					)
					if scope_container != null and scope_container.has_variable(key_from_variable):
						key = scope_container.get_variable(key_from_variable)

		return key
	else:
		return key_value

## 声明变量读写模式（精确化静态分析）
## dict_variable 仅 read（读取字典值并检查是否包含 key）
## key_from_variable 仅 read（当 use_key_from_variable=true 时读取键值）
func get_variable_modes() -> Array[Dictionary]:
	return [
		{"name": "dict_variable", "mode": "read"},
		{"name": "key_from_variable", "mode": "read"},
	]

## 获取条件类型
func get_condition_type() -> String:
	return "check_dict_contains_key"

## 获取条件分类
func get_condition_category() -> String:
	return "dictionaries"

## 获取条件描述
func get_description() -> String:
	var dict_str := ""
	var key_str := ""

	if dict_variable.is_empty():
		dict_str = FuseLocalization.translate("FUSE_CONDITION_DICT_CONTAINS_KEY_NO_DICT")
	else:
		var scope_str = _get_dict_scope_source_string()
		dict_str = "%s [%s]" % [dict_variable, scope_str]

	if use_key_from_variable:
		key_str = "$%s" % key_from_variable if not key_from_variable.is_empty() else "(no var)"
	else:
		key_str = str(key_value)

	return "Dict %s contains key %s" % [dict_str, key_str]

## 获取条件参数
func get_parameters() -> Dictionary:
	var params = {
		"dict_variable": dict_variable,
		"dict_scope": dict_scope,
		"use_key_from_variable": use_key_from_variable
	}

	if dict_scope == BaseVariable.VariableScope.SCOPE:
		params["dict_scope_source"] = dict_scope_source
		params["dict_custom_scope_id"] = dict_custom_scope_id
		params["dict_target_node_path"] = dict_target_node_path

	if use_key_from_variable:
		params["key_from_variable"] = key_from_variable
		params["key_from_variable_scope"] = key_from_variable_scope
		if key_from_variable_scope == BaseVariable.VariableScope.SCOPE:
			params["key_scope_source"] = key_scope_source
			params["key_custom_scope_id"] = key_custom_scope_id
			params["key_target_node_path"] = key_target_node_path
	else:
		params["key_value"] = key_value

	return params

## 计算条件依赖
func _compute_dependencies() -> Array[String]:
	var dependencies: Array[String] = []

	if not dict_variable.is_empty():
		dependencies.append(dict_variable)

	if use_key_from_variable and not key_from_variable.is_empty():
		dependencies.append(key_from_variable)

	return dependencies

## 验证条件
func validate() -> Array[String]:
	var errors = super.validate()

	# 验证字典变量名
	if dict_variable.is_empty():
		var error_msg = FuseLocalization.translate("FUSE_ERROR_DICT_VARIABLE_EMPTY")
		errors.append(error_msg)
		_create_fuse_error(error_msg, FuseError.ErrorType.VALIDATION_ERROR)

	# 验证字典 SCOPE 作用域参数
	if dict_scope == BaseVariable.VariableScope.SCOPE:
		var utils_scope_source = dict_scope_source as VariableScopeUtils.ScopeSource
		errors.append_array(VariableScopeUtils.validate_scope_source_params(
			utils_scope_source,
			dict_custom_scope_id,
			dict_target_node_path
		))

	# 验证键源
	if use_key_from_variable:
		if key_from_variable.is_empty():
			var error_msg = FuseLocalization.translate("FUSE_ERROR_DICT_KEY_EMPTY")
			errors.append(error_msg)
			_create_fuse_error(error_msg, FuseError.ErrorType.VALIDATION_ERROR)

		# 验证键 SCOPE 作用域参数
		if key_from_variable_scope == BaseVariable.VariableScope.SCOPE:
			var key_utils_scope_source = key_scope_source as VariableScopeUtils.ScopeSource
			errors.append_array(VariableScopeUtils.validate_scope_source_params(
				key_utils_scope_source,
				key_custom_scope_id,
				key_target_node_path
			))

	return errors

## 获取详细条件信息
func get_detailed_info() -> Dictionary:
	var info = super.get_detailed_info()
	info["dict_variable"] = dict_variable
	info["dict_scope"] = BaseVariable.VariableScope.keys()[dict_scope]
	info["use_key_from_variable"] = use_key_from_variable

	if dict_scope == BaseVariable.VariableScope.SCOPE:
		info["dict_scope_source"] = ScopeSource.keys()[dict_scope_source]
		info["dict_custom_scope_id"] = dict_custom_scope_id
		info["dict_target_node_path"] = str(dict_target_node_path)

	if use_key_from_variable:
		info["key_from_variable"] = key_from_variable
		info["key_from_variable_scope"] = BaseVariable.VariableScope.keys()[key_from_variable_scope]
		if key_from_variable_scope == BaseVariable.VariableScope.SCOPE:
			info["key_scope_source"] = ScopeSource.keys()[key_scope_source]
			info["key_custom_scope_id"] = key_custom_scope_id
			info["key_target_node_path"] = str(key_target_node_path)
	else:
		info["key_value"] = str(key_value)

	info["last_dict_size"] = _last_dict.size() if _last_dict != null and _last_dict is Dictionary else -1
	info["last_key"] = str(_last_key)
	info["last_contains_result"] = _last_contains_result

	return info

## 重置条件状态
func reset():
	super.reset()
	_last_dict = null
	_last_key = null
	_last_contains_result = false
	_log_debug("CheckDictContainsKey condition reset")

## 计算线程安全性
## CheckDictContainsKey 只有在 VARIABLE + LOCAL/GLOBAL 模式下才安全
## 同时键源也必须是 LOCAL/GLOBAL 作用域
func _compute_thread_safety() -> bool:
	if _thread_safety_computed:
		return _thread_safety_cached

	var is_safe := false

	# 检查字典作用域
	match dict_scope:
		BaseVariable.VariableScope.LOCAL, BaseVariable.VariableScope.GLOBAL:
			is_safe = true
		BaseVariable.VariableScope.SCOPE:
			is_safe = false

	# 如果使用变量键，检查键作用域
	if is_safe and use_key_from_variable:
		match key_from_variable_scope:
			BaseVariable.VariableScope.LOCAL, BaseVariable.VariableScope.GLOBAL:
				pass  # 保持安全
			BaseVariable.VariableScope.SCOPE:
				is_safe = false

	_thread_safety_cached = is_safe
	_thread_safety_computed = true
	return _thread_safety_cached

## 获取条件元数据
static func _get_condition_metadata() -> ConditionMetadata:
	var metadata = ConditionMetadata.new()
	metadata.name_key = "FUSE_CONDITION_DICT_CONTAINS_KEY_NAME"
	metadata.category_key = "FUSE_CATEGORY_DICTIONARIES"
	metadata.description_key = "FUSE_CONDITION_DICT_CONTAINS_KEY_DESC"
	metadata.keywords = ["dictionary", "字典", "key", "键", "contains", "包含", "has", "存在", "condition", "条件", "check", "检查"]
	metadata.builtin_icon = "Dictionary"
	return metadata
