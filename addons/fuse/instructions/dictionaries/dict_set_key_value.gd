@tool
@icon("res://addons/fuse/icons/builtin/Dictionary.svg")
extends BaseInstruction
class_name DictSetKeyValue

## DictSetKeyValue 指令
##
## 设置字典中指定键的值。
## 如果字典不存在则自动创建新字典。
## 如果键不存在则创建，存在则覆盖。
##
## 使用 VariableOperations 统一变量访问 API

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

## 键值是否来自变量
var use_key_from_variable: bool = false:
	set(value):
		if use_key_from_variable != value:
			use_key_from_variable = value
			_update_resource_name()
			notify_property_list_changed()

## 键源变量名（当 use_key_from_variable = true 时使用）
var key_from_variable: String = ""

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

## 值是否来自变量
var use_value_from_variable: bool = false:
	set(value):
		if use_value_from_variable != value:
			use_value_from_variable = value
			_update_resource_name()
			notify_property_list_changed()

## 值源变量名（当 use_value_from_variable = true 时使用）
var value_from_variable: String = ""

## 值源变量作用域
var value_from_variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		if value_from_variable_scope != value:
			value_from_variable_scope = value
			_update_resource_name()
			notify_property_list_changed()

## 值源作用域来源（仅当 value_from_variable_scope == SCOPE 时使用）
var value_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		if value_scope_source != value:
			value_scope_source = value
			_update_resource_name()
			notify_property_list_changed()

## 值源自定义作用域 ID
var value_custom_scope_id: String = "":
	set(value):
		if value_custom_scope_id != value:
			value_custom_scope_id = value
			_update_resource_name()

## 值源目标节点路径
var value_target_node_path: NodePath = NodePath(""):
	set(value):
		if value_target_node_path != value:
			value_target_node_path = value
			_update_resource_name()

## 要设置的值（直接输入，当 use_value_from_variable = false 时使用）
@export var to_value: Variant:
	set(value):
		to_value = value
		_update_resource_name()

## 获取指令元数据（用于指令选择器）
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_DICT_SET_NAME"
	metadata.category_key = "FUSE_CATEGORY_DICTIONARIES"
	metadata.description_key = "FUSE_INSTRUCTION_DICT_SET_DESC"
	metadata.keywords = ["字典", "设置", "键值", "dictionary", "set", "key", "value", "映射"]
	metadata.builtin_icon = "Dictionary"
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties := []

	# Dictionary 分类
	properties.append({
		name = "Dictionary",
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

	# Key 分类
	properties.append({
		name = "Key",
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

	# Value 分类
	properties.append({
		name = "Value",
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

	# 值或值源变量
	if use_value_from_variable:
		properties.append({
			name = "value_from_variable",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		properties.append({
			name = "value_from_variable_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 只在 value_from_variable_scope == SCOPE 时显示 ScopeSource 配置
		if value_from_variable_scope == BaseVariable.VariableScope.SCOPE:
			properties.append({
				name = "Value Scope Configuration",
				type = TYPE_NIL,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_CATEGORY
			})

			properties.append({
				name = "value_scope_source",
				type = TYPE_INT,
				hint = PROPERTY_HINT_ENUM,
				hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

			# 根据作用域来源添加额外属性
			if value_scope_source == ScopeSource.CUSTOM_ID:
				properties.append({
					name = "value_custom_scope_id",
					type = TYPE_STRING,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})
			elif value_scope_source == ScopeSource.TARGET_NODE:
				properties.append({
					name = "value_target_node_path",
					type = TYPE_NODE_PATH,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})

	return properties

## 更新资源名称
func _update_resource_name():
	var dict_str := ""
	var key_str := ""
	var value_str := ""

	# 字典信息
	if dict_variable.is_empty():
		dict_str = FuseLocalization.translate("FUSE_INSTRUCTION_DICT_SET_NO_DICT")
	else:
		dict_str = FuseLocalization.translate_format("FUSE_INSTRUCTION_DICT_SET_DICT", {"name": dict_variable})

	# 键信息
	if use_key_from_variable:
		if key_from_variable.is_empty():
			key_str = "(no key var)"
		else:
			key_str = "$%s" % key_from_variable
	else:
		var key_value_str = str(key_value)
		if key_value_str.length() > 15:
			key_value_str = key_value_str.substr(0, 12) + "..."
		key_str = key_value_str

	# 值信息
	if use_value_from_variable:
		if value_from_variable.is_empty():
			value_str = "(no value var)"
		else:
			value_str = "$%s" % value_from_variable
	else:
		var value_value_str = str(to_value)
		if value_value_str.length() > 15:
			value_value_str = value_value_str.substr(0, 12) + "..."
		value_str = value_value_str

	resource_name = " ".join(["Dict Set", dict_str, "[%s]" % key_str, "=", value_str])

## 动态属性设置（支持属性刷新）
func _set(property: StringName, value: Variant) -> bool:
	if property == "dict_variable" or property == "key_value" or property == "to_value":
		_update_resource_name()
		return false

	if property == "key_from_variable" or property == "value_from_variable":
		_update_resource_name()
		return false

	return false

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	_log_debug_localized("FUSE_LOG_INSTRUCTION_START", {"instruction": "DictSetKeyValue"})

	# 验证字典变量名
	if dict_variable.is_empty():
		_log_error_localized("FUSE_ERROR_DICT_VARIABLE_EMPTY", {})
		set_error_localized("FUSE_ERROR_DICT_VARIABLE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 获取键值
	var key: Variant
	if use_key_from_variable:
		# 从变量获取键值
		if key_from_variable.is_empty():
			_log_error_localized("FUSE_ERROR_DICT_KEY_EMPTY", {})
			set_error_localized("FUSE_ERROR_DICT_KEY_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
			finished.emit()
			return

		key = _get_variable_value(context, key_from_variable, key_from_variable_scope, key_scope_source, key_custom_scope_id, key_target_node_path)
		if key == null and not _variable_exists(context, key_from_variable, key_from_variable_scope, key_scope_source, key_custom_scope_id, key_target_node_path):
			_log_error_localized("FUSE_ERROR_DICT_KEY_EMPTY", {})
			set_error_localized("FUSE_ERROR_DICT_KEY_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
			finished.emit()
			return
	else:
		# 使用直接值
		key = key_value

	# 获取要设置的值
	var value: Variant
	if use_value_from_variable:
		# 从变量获取值
		if value_from_variable.is_empty():
			value = null
		else:
			value = _get_variable_value(context, value_from_variable, value_from_variable_scope, value_scope_source, value_custom_scope_id, value_target_node_path)
	else:
		# 使用直接值
		value = to_value

	# 获取或创建字典
	var target_dict: Dictionary = _get_or_create_dict_variable(context)

	# 调试输出
	_log_debug("════════════════════════════════════════════════════")
	_log_debug("📤 DictSetKeyValue 执行:")
	_log_debug("  • 目标字典: '%s'" % dict_variable)
	_log_debug("  • 作用域: %s" % _get_scope_name_for_log())
	_log_debug("  • 键: %s (类型: %s)" % [str(key), typeof(key)])
	_log_debug("  • 值: %s (类型: %s)" % [str(value), typeof(value)])
	_log_debug("════════════════════════════════════════════════════")

	# 设置键值
	target_dict[key] = value

	_log_info_localized("FUSE_LOG_DICT_SET", {"dict": dict_variable, "key": str(key), "value": str(value)})

	# 触发变量变化通知
	if dict_scope == BaseVariable.VariableScope.GLOBAL:
		_notify_global_variable_changed(dict_variable)
	elif dict_scope == BaseVariable.VariableScope.SCOPE:
		_notify_scope_variable_changed(context)

	_on_execution_completed()

## 获取变量值
func _get_variable_value(
	context: ExecutionContext,
	var_name: String,
	scope: BaseVariable.VariableScope,
	scope_source: ScopeSource,
	custom_scope_id: String,
	target_node_path: NodePath
) -> Variant:
	match scope:
		BaseVariable.VariableScope.LOCAL:
			return VariableOperations.get_variable(context, var_name, BaseVariable.VariableScope.LOCAL, null)
		BaseVariable.VariableScope.SCOPE:
			if scope_source == ScopeSource.NEAREST:
				return VariableOperations.get_variable(context, var_name, BaseVariable.VariableScope.SCOPE, null)
			else:
				var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
				var scope_container = VariableScopeUtils.get_scope_container_by_source(
					context,
					utils_scope_source,
					custom_scope_id,
					target_node_path
				)
				if scope_container == null:
					return null
				return scope_container.get_variable(var_name, null)
		BaseVariable.VariableScope.GLOBAL:
			return VariableOperations.get_variable(context, var_name, BaseVariable.VariableScope.GLOBAL, null)

	return null

## 检查变量是否存在
func _variable_exists(
	context: ExecutionContext,
	var_name: String,
	scope: BaseVariable.VariableScope,
	scope_source: ScopeSource,
	custom_scope_id: String,
	target_node_path: NodePath
) -> bool:
	match scope:
		BaseVariable.VariableScope.LOCAL:
			return VariableOperations.has_variable(context, var_name, BaseVariable.VariableScope.LOCAL)
		BaseVariable.VariableScope.SCOPE:
			if scope_source == ScopeSource.NEAREST:
				return VariableOperations.has_variable(context, var_name, BaseVariable.VariableScope.SCOPE)
			else:
				var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
				var scope_container = VariableScopeUtils.get_scope_container_by_source(
					context,
					utils_scope_source,
					custom_scope_id,
					target_node_path
				)
				if scope_container == null:
					return false
				return scope_container.has_variable(var_name)
		BaseVariable.VariableScope.GLOBAL:
			return VariableOperations.has_variable(context, var_name, BaseVariable.VariableScope.GLOBAL)

	return false

## 获取或创建字典变量
func _get_or_create_dict_variable(context: ExecutionContext) -> Dictionary:
	var dict_value: Variant = null

	match dict_scope:
		BaseVariable.VariableScope.LOCAL:
			if VariableOperations.has_variable(context, dict_variable, BaseVariable.VariableScope.LOCAL):
				dict_value = VariableOperations.get_variable(context, dict_variable, BaseVariable.VariableScope.LOCAL, null)
			else:
				# 创建新字典
				dict_value = {}
				VariableOperations.set_variable(context, dict_variable, BaseVariable.VariableScope.LOCAL, dict_value)
				return dict_value

		BaseVariable.VariableScope.SCOPE:
			if dict_scope_source == ScopeSource.NEAREST:
				dict_value = VariableOperations.get_variable(context, dict_variable, BaseVariable.VariableScope.SCOPE, null)
				if dict_value == null:
					# 创建新字典
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
					return {}

				if scope_container.has_variable(dict_variable):
					dict_value = scope_container.get_variable(dict_variable, null)
				else:
					# 创建新字典
					dict_value = {}
					scope_container.set_variable(dict_variable, dict_value)
					return dict_value

		BaseVariable.VariableScope.GLOBAL:
			dict_value = VariableOperations.get_variable(context, dict_variable, BaseVariable.VariableScope.GLOBAL, null)
			if dict_value == null:
				# 创建新字典
				dict_value = {}
				VariableOperations.set_variable(context, dict_variable, BaseVariable.VariableScope.GLOBAL, dict_value)
				return dict_value

	if dict_value is Dictionary:
		return dict_value
	else:
		# 变量存在但不是字典，创建新字典并覆盖
		_log_debug("变量 '%s' 不是字典类型 (类型: %s)，创建新字典" % [dict_variable, typeof(dict_value)])
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

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()

	# 验证字典变量名
	if dict_variable.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_DICT_VARIABLE_EMPTY"))

	# 验证字典 SCOPE 作用域需要 ScopeVariableManager
	if dict_scope == BaseVariable.VariableScope.SCOPE:
		var manager = ScopeVariableManager.get_instance()
		if manager == null:
			errors.append(FuseLocalization.translate("FUSE_ERROR_SCOPE_MANAGER_NOT_FOUND"))

		# 验证 ScopeSource 参数
		var dict_utils_scope_source = dict_scope_source as VariableScopeUtils.ScopeSource
		errors.append_array(VariableScopeUtils.validate_scope_source_params(
			dict_utils_scope_source,
			dict_custom_scope_id,
			dict_target_node_path
		))

	# 验证键源
	if use_key_from_variable:
		if key_from_variable.is_empty():
			errors.append(FuseLocalization.translate("FUSE_ERROR_DICT_KEY_EMPTY"))

		# 验证键 SCOPE 作用域需要 ScopeVariableManager
		if key_from_variable_scope == BaseVariable.VariableScope.SCOPE:
			var manager = ScopeVariableManager.get_instance()
			if manager == null:
				errors.append(FuseLocalization.translate("FUSE_ERROR_SCOPE_MANAGER_NOT_FOUND"))

			# 验证 ScopeSource 参数
			var key_utils_scope_source = key_scope_source as VariableScopeUtils.ScopeSource
			errors.append_array(VariableScopeUtils.validate_scope_source_params(
				key_utils_scope_source,
				key_custom_scope_id,
				key_target_node_path
			))

	# 验证值源 SCOPE 作用域
	if use_value_from_variable:
		if value_from_variable_scope == BaseVariable.VariableScope.SCOPE:
			var manager = ScopeVariableManager.get_instance()
			if manager == null:
				errors.append(FuseLocalization.translate("FUSE_ERROR_SCOPE_MANAGER_NOT_FOUND"))

			# 验证 ScopeSource 参数
			var value_utils_scope_source = value_scope_source as VariableScopeUtils.ScopeSource
			errors.append_array(VariableScopeUtils.validate_scope_source_params(
				value_utils_scope_source,
				value_custom_scope_id,
				value_target_node_path
			))

	return errors

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

	# 值变量相关属性
	if use_value_from_variable:
		if property.name == "to_value":
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		if property.name in ["value_from_variable", "value_from_variable_scope", "value_scope_source", "value_custom_scope_id", "value_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	# 值作用域相关属性
	if use_value_from_variable:
		if value_from_variable_scope == BaseVariable.VariableScope.SCOPE:
			if property.name == "value_scope_source":
				return  # 始终显示
			elif property.name == "value_custom_scope_id":
				if value_scope_source != ScopeSource.CUSTOM_ID:
					property.usage = PROPERTY_USAGE_NO_EDITOR
			elif property.name == "value_target_node_path":
				if value_scope_source != ScopeSource.TARGET_NODE:
					property.usage = PROPERTY_USAGE_NO_EDITOR
		else:
			if property.name in ["value_scope_source", "value_custom_scope_id", "value_target_node_path"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR

## 获取指令描述
func get_description() -> String:
	var dict_str := ""
	var key_str := ""
	var value_str := ""

	if dict_variable.is_empty():
		dict_str = FuseLocalization.translate("FUSE_INSTRUCTION_DICT_SET_NO_DICT")
	else:
		dict_str = FuseLocalization.translate_format("FUSE_INSTRUCTION_DICT_SET_DICT", {"name": dict_variable})

	if use_key_from_variable:
		key_str = "$%s" % key_from_variable if not key_from_variable.is_empty() else "(no var)"
	else:
		key_str = str(key_value)

	if use_value_from_variable:
		value_str = "$%s" % value_from_variable if not value_from_variable.is_empty() else "(no var)"
	else:
		value_str = str(to_value)

	return "Dict Set: %s[%s] = %s" % [dict_str, key_str, value_str]

## 重置指令状态
func reset():
	super.reset()
	_log_debug_localized("FUSE_LOG_DICT_SET_RESET", {})

## 获取作用域名称（用于日志输出）
func _get_scope_name_for_log() -> String:
	match dict_scope:
		BaseVariable.VariableScope.LOCAL:
			return "LOCAL（本地）"
		BaseVariable.VariableScope.SCOPE:
			var source_name := ""
			match dict_scope_source:
				ScopeSource.NEAREST:
					source_name = "NEAREST"
				ScopeSource.CUSTOM_ID:
					source_name = "CUSTOM_ID[%s]" % dict_custom_scope_id
				ScopeSource.TRIGGER_SCOPE:
					source_name = "TRIGGER_SCOPE"
				ScopeSource.TARGET_NODE:
					source_name = "TARGET_NODE[%s]" % str(dict_target_node_path)
			return "SCOPE（作用域）- %s" % source_name
		BaseVariable.VariableScope.GLOBAL:
			return "GLOBAL（全局）"
	return "UNKNOWN"

## 通知全局变量已变化（用于触发自动保存等）
func _notify_global_variable_changed(var_name: String) -> void:
	var manager = GlobalVariableManager.get_instance()
	if manager == null:
		_log_debug("无法获取全局变量管理器，跳过变化通知")
		return

	var variable = manager.get_variable(var_name)
	if variable == null:
		_log_debug("全局变量 '%s' 不存在，跳过变化通知" % var_name)
		return

	# 检查是否是持久化变量
	if variable.persistent:
		_log_debug("持久化变量 '%s' 已修改，触发变化通知" % var_name)
		# 使用 GlobalVariableManager 提供的方法通知变量内容已变化
		manager.notify_variable_content_changed(var_name)
	else:
		_log_debug("变量 '%s' 不是持久化变量，跳过自动保存通知" % var_name)

## 通知 SCOPE 作用域变量已变化
func _notify_scope_variable_changed(context: ExecutionContext) -> void:
	var utils_scope_source = dict_scope_source as VariableScopeUtils.ScopeSource
	var scope_container = VariableScopeUtils.get_scope_container_by_source(
		context,
		utils_scope_source,
		dict_custom_scope_id,
		dict_target_node_path
	)

	if scope_container == null:
		_log_debug("无法获取 ScopeVariableContainer，跳过变化通知")
		return

	_log_debug("SCOPE 变量 '%s' 已修改，触发 notify_property_list_changed" % dict_variable)
	scope_container.notify_property_list_changed()
