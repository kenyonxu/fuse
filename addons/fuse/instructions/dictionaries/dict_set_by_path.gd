@tool
@icon("res://addons/fuse/icons/builtin/Dictionary.svg")
extends BaseInstruction
class_name DictSetByPath

## DictSetByPath 指令
##
## 通过嵌套路径设置字典中的值。
## 路径格式: "player/stats/hp" 表示 dict["player"]["stats"]["hp"] = value
## 如果路径中间层不存在，自动创建空字典。

## 作用域来源枚举
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

# 路径字符串
var path_string: String = "":
	set(value):
		if path_string != value:
			path_string = value
			_update_resource_name()

# 路径分隔符
var path_separator: String = "/":
	set(value):
		if path_separator != value:
			path_separator = value
			_update_resource_name()

# 路径是否来自变量
var use_path_from_variable: bool = false:
	set(value):
		if use_path_from_variable != value:
			use_path_from_variable = value
			_update_resource_name()
			notify_property_list_changed()

# 路径变量名
var path_from_variable: String = "":
	set(value):
		if path_from_variable != value:
			path_from_variable = value
			_update_resource_name()

# 路径变量作用域
var path_variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL

# 要设置的值
@export var value_to_set: Variant:
	set(value):
		value_to_set = value
		_update_resource_name()

# 值是否来自变量
var use_value_from_variable: bool = false:
	set(value):
		if use_value_from_variable != value:
			use_value_from_variable = value
			_update_resource_name()
			notify_property_list_changed()

# 值变量名
var value_from_variable: String = "":
	set(value):
		if value_from_variable != value:
			value_from_variable = value
			_update_resource_name()

# 值变量作用域
var value_variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL

## 获取指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_DICT_SET_BY_PATH_NAME"
	metadata.category_key = "FUSE_CATEGORY_DICTIONARIES"
	metadata.description_key = "FUSE_INSTRUCTION_DICT_SET_BY_PATH_DESC"
	metadata.keywords = ["字典", "路径", "设置", "嵌套", "dictionary", "path", "set", "nested"]
	metadata.builtin_icon = "Dictionary"
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties := []

	# Dictionary Configuration
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

	# Path Configuration
	properties.append({
		name = "Path Configuration",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "path_string",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "path_separator",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "use_path_from_variable",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if use_path_from_variable:
		properties.append({
			name = "path_from_variable",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		properties.append({
			name = "path_variable_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

	# Value Configuration
	properties.append({
		name = "Value Configuration",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "use_value_from_variable",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if use_value_from_variable:
		properties.append({
			name = "value_from_variable",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		properties.append({
			name = "value_variable_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

	return properties

## 验证属性可见性
func _validate_property(property: Dictionary) -> void:
	# 字典作用域相关
	if dict_scope != BaseVariable.VariableScope.SCOPE:
		if property.name in ["dict_scope_source", "dict_custom_scope_id", "dict_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		if property.name == "dict_custom_scope_id" and dict_scope_source != ScopeSource.CUSTOM_ID:
			property.usage = PROPERTY_USAGE_NO_EDITOR
		if property.name == "dict_target_node_path" and dict_scope_source != ScopeSource.TARGET_NODE:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	# 路径配置相关
	if not use_path_from_variable:
		if property.name in ["path_from_variable", "path_variable_scope"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	# 值配置相关
	if not use_value_from_variable:
		if property.name in ["value_from_variable", "value_variable_scope"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		if property.name == "value_to_set":
			property.usage = PROPERTY_USAGE_NO_EDITOR

## 更新资源名称
func _update_resource_name():
	var dict_str = dict_variable if not dict_variable.is_empty() else FuseLocalization.translate("FUSE_DICT_NO_DICT")
	var path_str = path_string if not path_string.is_empty() else FuseLocalization.translate("FUSE_DICT_PATH_UNSET")
	var value_str = str(value_to_set)
	if value_str.length() > 15:
		value_str = value_str.substr(0, 12) + "..."

	resource_name = "Dict SetByPath: %s[%s] = %s" % [dict_str, path_str, value_str]

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	_log_debug_localized("FUSE_LOG_INSTRUCTION_START", {"instruction": "DictSetByPath"})

	# 验证字典变量名
	if dict_variable.is_empty():
		_log_error_localized("FUSE_ERROR_DICT_VARIABLE_EMPTY", {})
		set_error_localized("FUSE_ERROR_DICT_VARIABLE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 获取路径
	var actual_path: String
	if use_path_from_variable:
		if path_from_variable.is_empty():
			_log_error_localized("FUSE_ERROR_DICT_PATH_INVALID", {"path": "<empty>"})
			set_error_localized("FUSE_ERROR_DICT_PATH_INVALID", FuseError.ErrorType.VALIDATION_ERROR, {"path": "<empty>"})
			finished.emit()
			return
		actual_path = VariableOperations.get_variable(context, path_from_variable, path_variable_scope, "")
	else:
		actual_path = path_string

	if actual_path.is_empty():
		_log_error_localized("FUSE_ERROR_DICT_PATH_INVALID", {"path": "<empty>"})
		set_error_localized("FUSE_ERROR_DICT_PATH_INVALID", FuseError.ErrorType.VALIDATION_ERROR, {"path": "<empty>"})
		finished.emit()
		return

	# 获取值
	var actual_value: Variant
	if use_value_from_variable:
		if value_from_variable.is_empty():
			actual_value = null
		else:
			actual_value = VariableOperations.get_variable(context, value_from_variable, value_variable_scope, null)
	else:
		actual_value = value_to_set

	# 获取字典
	var target_dict: Dictionary = _get_or_create_dict(context)

	if target_dict == null:
		_log_error_localized("FUSE_ERROR_DICT_VARIABLE_NOT_FOUND", {"name": dict_variable})
		set_error_localized("FUSE_ERROR_DICT_VARIABLE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"name": dict_variable})
		finished.emit()
		return

	# 分割路径
	var segments = actual_path.split(path_separator)

	# 导航到倒数第二层， 创建中间层字典
	var current: Variant = target_dict

	for i in range(segments.size() - 1):
		var segment = segments[i]
		if segment.is_empty():
			continue

		if current is Dictionary:
			if not current.has(segment):
				current[segment] = {}
			var next = current[segment]
			if next is not Dictionary:
				_log_error_localized("FUSE_ERROR_DICT_PATH_SEGMENT_NOT_DICT", {"segment": segment})
				set_error_localized("FUSE_ERROR_DICT_PATH_SEGMENT_NOT_DICT", FuseError.ErrorType.RUNTIME_ERROR, {"segment": segment})
				finished.emit()
				return
			current = next
		else:
			_log_error_localized("FUSE_ERROR_DICT_PATH_SEGMENT_NOT_DICT", {"segment": segment})
			set_error_localized("FUSE_ERROR_DICT_PATH_SEGMENT_NOT_DICT", FuseError.ErrorType.RUNTIME_ERROR, {"segment": segment})
			finished.emit()
			return

	# 设置最后一层的值
	var last_key = segments[-1]
	if last_key.is_empty():
		_log_error_localized("FUSE_ERROR_DICT_PATH_INVALID", {"path": actual_path})
		set_error_localized("FUSE_ERROR_DICT_PATH_INVALID", FuseError.ErrorType.RUNTIME_ERROR, {"path": actual_path})
		finished.emit()
		return

	current[last_key] = actual_value

	_log_info_localized("FUSE_LOG_DICT_SET_BY_PATH", {
		"dict": dict_variable,
		"path": actual_path,
		"value": str(actual_value)
	})

	# 通知变量变化
	_notify_dict_changed(context)

	_on_execution_completed()

## 获取或创建字典
func _get_or_create_dict(context: ExecutionContext) -> Variant:
	var dict_value: Variant = null

	match dict_scope:
		BaseVariable.VariableScope.LOCAL:
			if VariableOperations.has_variable(context, dict_variable, BaseVariable.VariableScope.LOCAL):
				dict_value = VariableOperations.get_variable(context, dict_variable, BaseVariable.VariableScope.LOCAL, null)
			else:
				dict_value = {}
				VariableOperations.set_variable(context, dict_variable, BaseVariable.VariableScope.LOCAL, dict_value)
				return dict_value

		BaseVariable.VariableScope.SCOPE:
			if dict_scope_source == ScopeSource.NEAREST:
				dict_value = VariableOperations.get_variable(context, dict_variable, BaseVariable.VariableScope.SCOPE, null)
				if dict_value == null:
					dict_value = {}
					VariableOperations.set_variable(context, dict_variable, BaseVariable.VariableScope.SCOPE, dict_value)
					return dict_value
			else:
				var utils_scope_source = dict_scope_source as VariableScopeUtils.ScopeSource
				var scope_container = VariableScopeUtils.get_scope_container_by_source(
					context,
					utils_scope_source,
					dict_custom_scope_id,
					dict_target_node_path
				)
				if scope_container == null:
					return null
				if scope_container.has_variable(dict_variable):
					dict_value = scope_container.get_variable(dict_variable, null)
				else:
					dict_value = {}
					scope_container.set_variable(dict_variable, dict_value)
					return dict_value

		BaseVariable.VariableScope.GLOBAL:
			dict_value = VariableOperations.get_variable(context, dict_variable, BaseVariable.VariableScope.GLOBAL, null)
			if dict_value == null:
				dict_value = {}
				VariableOperations.set_variable(context, dict_variable, BaseVariable.VariableScope.GLOBAL, dict_value)
				return dict_value

	if dict_value is Dictionary:
		return dict_value
	else:
		_log_debug("Variable '%s' is not a dictionary (type: %s), creating new dict" % [dict_variable, typeof(dict_value)])
		var new_dict: Dictionary = {}
		match dict_scope:
			BaseVariable.VariableScope.LOCAL:
				VariableOperations.set_variable(context, dict_variable, BaseVariable.VariableScope.LOCAL, new_dict)
			BaseVariable.VariableScope.SCOPE:
				if dict_scope_source == ScopeSource.NEAREST:
					VariableOperations.set_variable(context, dict_variable, BaseVariable.VariableScope.SCOPE, new_dict)
				else:
					var utils_scope_source = dict_scope_source as VariableScopeUtils.ScopeSource
					var scope_container = VariableScopeUtils.get_scope_container_by_source(
						context,
						utils_scope_source,
						dict_custom_scope_id,
						dict_target_node_path
					)
					if scope_container:
						scope_container.set_variable(dict_variable, new_dict)
			BaseVariable.VariableScope.GLOBAL:
				VariableOperations.set_variable(context, dict_variable, BaseVariable.VariableScope.GLOBAL, new_dict)
		return new_dict

## 通知字典变化
func _notify_dict_changed(context: ExecutionContext) -> void:
	if dict_scope == BaseVariable.VariableScope.GLOBAL:
		var manager = GlobalVariableManager.get_instance()
		if manager:
			var variable = manager.get_variable(dict_variable)
			if variable and variable.persistent:
				manager.notify_variable_content_changed(dict_variable)
	elif dict_scope == BaseVariable.VariableScope.SCOPE:
		if dict_scope_source != ScopeSource.NEAREST:
			var utils_scope_source = dict_scope_source as VariableScopeUtils.ScopeSource
			var scope_container = VariableScopeUtils.get_scope_container_by_source(
				context,
				utils_scope_source,
				dict_custom_scope_id,
				dict_target_node_path
			)
			if scope_container:
				scope_container.notify_property_list_changed()

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()

	if dict_variable.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_DICT_VARIABLE_EMPTY"))

	if dict_scope == BaseVariable.VariableScope.SCOPE:
		var utils_scope_source = dict_scope_source as VariableScopeUtils.ScopeSource
		errors.append_array(VariableScopeUtils.validate_scope_source_params(
			utils_scope_source,
			dict_custom_scope_id,
			dict_target_node_path
		))

	return errors

## 获取指令描述
func get_description() -> String:
	var dict_str = dict_variable if not dict_variable.is_empty() else "NoDict"
	var path_str = path_string if not path_string.is_empty() else "NoPath"
	return "Dict SetByPath: %s[%s] = %s" % [dict_str, path_str, str(value_to_set)]

## 重置指令状态
func reset():
	super.reset()
	_log_debug("DictSetByPath reset")
