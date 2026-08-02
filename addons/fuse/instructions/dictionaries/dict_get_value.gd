@tool
@icon("res://addons/fuse/icons/builtin/Get.svg")
extends BaseInstruction
class_name DictGetValue

## DictGetValue 指令
##
## 从字典中获取指定键的值并存储到目标变量。
## 支持默认值（键不存在时返回默认值）。
## 支持从变量获取键名。
##
## 使用 VariableOperations 统一变量访问 API

## 作用域来源枚举
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

# 键来源类型
enum KeySourceType {
	DIRECT,         # 直接输入键名
	FROM_VARIABLE   # 从变量获取键名
}

# 字典变量名
var dict_variable: String = ""

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

# 键来源类型
var key_source_type: KeySourceType = KeySourceType.DIRECT:
	set(value):
		if key_source_type != value:
			key_source_type = value
			_update_resource_name()
			notify_property_list_changed()

# 键名（直接输入）
var key_value: String = "":
	set(value):
		key_value = value
		_update_resource_name()

# 键变量名（从变量获取）
var key_variable: String = "":
	set(value):
		key_variable = value
		_update_resource_name()

# 键变量作用域
var key_variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		if key_variable_scope != value:
			key_variable_scope = value
			_update_resource_name()
			notify_property_list_changed()

## 键变量作用域来源（仅当 key_variable_scope == SCOPE 时使用）
var key_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		if key_scope_source != value:
			key_scope_source = value
			_update_resource_name()
			notify_property_list_changed()

## 自定义键变量作用域 ID
var key_custom_scope_id: String = "":
	set(value):
		if key_custom_scope_id != value:
			key_custom_scope_id = value
			_update_resource_name()

## 键变量目标节点路径
var key_target_node_path_for_scope: NodePath = NodePath(""):
	set(value):
		if key_target_node_path_for_scope != value:
			key_target_node_path_for_scope = value
			_update_resource_name()

# 默认值（键不存在时返回）
var default_value: Variant = null:
	set(value):
		default_value = value
		_update_resource_name()

# 目标变量名（存储结果的变量）
var target_variable: String = "":
	set(value):
		target_variable = value
		_update_resource_name()

# 目标变量作用域
var target_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		if target_scope != value:
			target_scope = value
			_update_resource_name()
			notify_property_list_changed()

## 目标作用域来源（仅当 target_scope == SCOPE 时使用）
var target_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		if target_scope_source != value:
			target_scope_source = value
			_update_resource_name()
			notify_property_list_changed()

## 自定义目标作用域 ID
var target_custom_scope_id: String = "":
	set(value):
		if target_custom_scope_id != value:
			target_custom_scope_id = value
			_update_resource_name()

## 目标节点路径
var target_node_path_for_scope: NodePath = NodePath(""):
	set(value):
		if target_node_path_for_scope != value:
			target_node_path_for_scope = value
			_update_resource_name()

## 获取指令元数据（用于指令选择器）
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_DICT_GET_VALUE_NAME"
	metadata.category_key = "FUSE_CATEGORY_DICTIONARIES"
	metadata.description_key = "FUSE_INSTRUCTION_DICT_GET_VALUE_DESC"
	metadata.keywords = ["字典", "获取", "读取", "dictionary", "dict", "get", "value", "键"]
	metadata.builtin_icon = "Get"
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

## 声明变量读写模式（dict=read, key=read, target=write 取值结果）
func get_variable_modes() -> Array[Dictionary]:
	return [
		{"name": "dict_variable", "mode": "read"},
		{"name": "key_variable", "mode": "read"},
		{"name": "target_variable", "mode": "write"},
	]

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
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
		name = "key_source_type",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Direct,FromVariable",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 键名（直接输入模式）
	if key_source_type == KeySourceType.DIRECT:
		properties.append({
			name = "key_value",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

	# 键变量（从变量获取模式）
	if key_source_type == KeySourceType.FROM_VARIABLE:
		properties.append({
			name = "key_variable",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		properties.append({
			name = "key_variable_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 只在 key_variable_scope == SCOPE 时显示键变量 ScopeSource 配置
		if key_variable_scope == BaseVariable.VariableScope.SCOPE:
			properties.append({
				name = "Key Variable Scope Configuration",
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

			if key_scope_source == ScopeSource.CUSTOM_ID:
				properties.append({
					name = "key_custom_scope_id",
					type = TYPE_STRING,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})
			elif key_scope_source == ScopeSource.TARGET_NODE:
				properties.append({
					name = "key_target_node_path_for_scope",
					type = TYPE_NODE_PATH,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})

	# Default Value 分类
	properties.append({
		name = "Default Value",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "default_value",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Target Variable 分类
	properties.append({
		name = "Target Variable",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

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

	# 只在 target_scope == SCOPE 时显示目标 ScopeSource 配置
	if target_scope == BaseVariable.VariableScope.SCOPE:
		properties.append({
			name = "Target Scope Configuration",
			type = TYPE_NIL,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_CATEGORY
		})

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
				name = "target_node_path_for_scope",
				type = TYPE_NODE_PATH,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

	return properties

## 更新资源名称
func _update_resource_name():
	var dict_str := ""
	var key_str := ""
	var target_str := ""

	# 字典信息
	if dict_variable.is_empty():
		dict_str = FuseLocalization.translate("FUSE_INSTRUCTION_DICT_NO_DICT")
	else:
		dict_str = FuseLocalization.translate_format("FUSE_INSTRUCTION_DICT_DICT", {"name": dict_variable})

	# 键信息
	match key_source_type:
		KeySourceType.DIRECT:
			if key_value.is_empty():
				key_str = FuseLocalization.translate("FUSE_INSTRUCTION_DICT_NO_KEY")
			else:
				key_str = "\"%s\"" % key_value
		KeySourceType.FROM_VARIABLE:
			if key_variable.is_empty():
				key_str = FuseLocalization.translate("FUSE_INSTRUCTION_DICT_NO_KEY_VAR")
			else:
				key_str = FuseLocalization.translate_format("FUSE_INSTRUCTION_DICT_KEY_VAR", {"name": key_variable})

	# 目标信息
	if target_variable.is_empty():
		target_str = FuseLocalization.translate("FUSE_INSTRUCTION_DICT_NO_TARGET")
	else:
		target_str = target_variable

	resource_name = " ".join(["Dict Get", dict_str, "[%s]" % key_str, "→", target_str])

## 动态属性设置（支持属性刷新）
func _set(property: StringName, value: Variant) -> bool:
	if property == "key_source_type":
		key_source_type = value
		notify_property_list_changed()
		_update_resource_name()
		return true

	if property in ["dict_variable", "key_value", "key_variable", "target_variable"]:
		_update_resource_name()
		return false

	return false

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	_log_debug_localized("FUSE_LOG_INSTRUCTION_START", {"instruction": "DictGetValue"})

	# 验证字典变量名
	if dict_variable.is_empty():
		_log_error_localized("FUSE_ERROR_DICT_VARIABLE_EMPTY", {})
		set_error_localized("FUSE_ERROR_DICT_VARIABLE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 获取字典
	var target_dict: Dictionary = _get_dict_variable(context)

	if target_dict.is_empty():
		# 检查是否是 null（变量不存在）还是空字典
		if not VariableOperations.has_variable(context, dict_variable, dict_scope):
			_log_error_localized("FUSE_ERROR_DICT_VARIABLE_NOT_FOUND", {"name": dict_variable})
			set_error_localized("FUSE_ERROR_DICT_VARIABLE_NOT_FOUND", FuseError.ErrorType.VALIDATION_ERROR, {"name": dict_variable})
			finished.emit()
			return

	# 获取键
	var key: Variant = _get_key(context)

	if key == null and key_source_type == KeySourceType.FROM_VARIABLE:
		if not key_variable.is_empty():
			_log_error_localized("FUSE_ERROR_KEY_VARIABLE_NOT_FOUND", {"name": key_variable})
			set_error_localized("FUSE_ERROR_KEY_VARIABLE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"name": key_variable})
			finished.emit()
			return

	# 验证目标变量名
	if target_variable.is_empty():
		_log_error_localized("FUSE_ERROR_TARGET_VARIABLE_EMPTY", {})
		set_error_localized("FUSE_ERROR_TARGET_VARIABLE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 获取值（如果键不存在则使用默认值）
	var value: Variant
	if target_dict.has(key):
		value = target_dict[key]
		_log_info_localized("FUSE_LOG_DICT_GET_VALUE", {"key": str(key), "value": str(value), "target": target_variable})
	else:
		value = default_value
		_log_info_localized("FUSE_LOG_DICT_GET_VALUE_DEFAULT", {"key": str(key), "default": str(default_value), "target": target_variable})

	# 存储到目标变量
	_set_target_variable(context, value)

	_on_execution_completed()

## 获取字典变量
func _get_dict_variable(context: ExecutionContext) -> Dictionary:
	var dict_value: Variant = null

	match dict_scope:
		BaseVariable.VariableScope.LOCAL:
			if VariableOperations.has_variable(context, dict_variable, BaseVariable.VariableScope.LOCAL):
				dict_value = VariableOperations.get_variable(context, dict_variable, BaseVariable.VariableScope.LOCAL, null)

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
				if scope_container == null:
					return {}
				if scope_container.has_variable(dict_variable):
					dict_value = scope_container.get_variable(dict_variable, null)

		BaseVariable.VariableScope.GLOBAL:
			dict_value = VariableOperations.get_variable(context, dict_variable, BaseVariable.VariableScope.GLOBAL, null)

	if dict_value is Dictionary:
		return dict_value

	return {}

## 获取键
func _get_key(context: ExecutionContext) -> Variant:
	match key_source_type:
		KeySourceType.DIRECT:
			return key_value

		KeySourceType.FROM_VARIABLE:
			if key_variable.is_empty():
				return null

			match key_variable_scope:
				BaseVariable.VariableScope.LOCAL:
					return VariableOperations.get_variable(context, key_variable, BaseVariable.VariableScope.LOCAL, null)

				BaseVariable.VariableScope.SCOPE:
					if key_scope_source == ScopeSource.NEAREST:
						return VariableOperations.get_variable(context, key_variable, BaseVariable.VariableScope.SCOPE, null)
					else:
						var utils_scope_source = key_scope_source as VariableScopeUtils.ScopeSource
						var scope_container = VariableScopeUtils.get_scope_container_by_source(
							context,
							utils_scope_source,
							key_custom_scope_id,
							key_target_node_path_for_scope
						)
						if scope_container == null:
							return null
						if scope_container.has_variable(key_variable):
							return scope_container.get_variable(key_variable, null)

				BaseVariable.VariableScope.GLOBAL:
					return VariableOperations.get_variable(context, key_variable, BaseVariable.VariableScope.GLOBAL, null)

	return null

## 设置目标变量
func _set_target_variable(context: ExecutionContext, value: Variant):
	match target_scope:
		BaseVariable.VariableScope.LOCAL:
			VariableOperations.set_variable(context, target_variable, BaseVariable.VariableScope.LOCAL, value)
		BaseVariable.VariableScope.SCOPE:
			if target_scope_source == ScopeSource.NEAREST:
				VariableOperations.set_variable(context, target_variable, BaseVariable.VariableScope.SCOPE, value)
			else:
				var utils_scope_source = target_scope_source as VariableScopeUtils.ScopeSource
				var scope_container = VariableScopeUtils.get_scope_container_by_source(
					context,
					utils_scope_source,
					target_custom_scope_id,
					target_node_path_for_scope
				)
				if scope_container:
					scope_container.set_variable(target_variable, value)
		BaseVariable.VariableScope.GLOBAL:
			VariableOperations.set_variable(context, target_variable, BaseVariable.VariableScope.GLOBAL, value)
			_notify_global_variable_changed(target_variable)

## 通知全局变量已变化
func _notify_global_variable_changed(var_name: String) -> void:
	var manager = GlobalVariableManager.get_instance()
	if manager == null:
		return

	var variable = manager.get_variable(var_name)
	if variable == null:
		return

	if variable.persistent:
		_log_debug("持久化变量 '%s' 已修改，触发变化通知" % var_name)
		manager.notify_variable_content_changed(var_name)

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()

	# 验证字典变量名
	if dict_variable.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_DICT_VARIABLE_EMPTY"))

	if dict_scope == BaseVariable.VariableScope.SCOPE:
		var manager = ScopeVariableManager.get_instance()
		if manager == null:
			errors.append(FuseLocalization.translate("FUSE_ERROR_SCOPE_MANAGER_NOT_FOUND"))

		var dict_utils_scope_source = dict_scope_source as VariableScopeUtils.ScopeSource
		errors.append_array(VariableScopeUtils.validate_scope_source_params(
			dict_utils_scope_source,
			dict_custom_scope_id,
			dict_target_node_path
		))

	# 验证键配置
	match key_source_type:
		KeySourceType.DIRECT:
			if key_value.is_empty():
				errors.append(FuseLocalization.translate("FUSE_ERROR_KEY_VALUE_EMPTY"))

		KeySourceType.FROM_VARIABLE:
			if key_variable.is_empty():
				errors.append(FuseLocalization.translate("FUSE_ERROR_KEY_VARIABLE_EMPTY"))

			if key_variable_scope == BaseVariable.VariableScope.SCOPE:
				var key_utils_scope_source = key_scope_source as VariableScopeUtils.ScopeSource
				errors.append_array(VariableScopeUtils.validate_scope_source_params(
					key_utils_scope_source,
					key_custom_scope_id,
					key_target_node_path_for_scope
				))

	# 验证目标变量
	if target_variable.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_VARIABLE_EMPTY"))

	if target_scope == BaseVariable.VariableScope.SCOPE:
		var manager = ScopeVariableManager.get_instance()
		if manager == null:
			errors.append(FuseLocalization.translate("FUSE_ERROR_SCOPE_MANAGER_NOT_FOUND"))

		var target_utils_scope_source = target_scope_source as VariableScopeUtils.ScopeSource
		errors.append_array(VariableScopeUtils.validate_scope_source_params(
			target_utils_scope_source,
			target_custom_scope_id,
			target_node_path_for_scope
		))

	return errors

## 验证属性可见性
func _validate_property(property: Dictionary) -> void:
	# 字典作用域相关属性
	if dict_scope == BaseVariable.VariableScope.SCOPE:
		if property.name == "dict_scope_source":
			return
		elif property.name == "dict_custom_scope_id":
			if dict_scope_source != ScopeSource.CUSTOM_ID:
				property.usage = PROPERTY_USAGE_NO_EDITOR
		elif property.name == "dict_target_node_path":
			if dict_scope_source != ScopeSource.TARGET_NODE:
				property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		if property.name in ["dict_scope_source", "dict_custom_scope_id", "dict_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	# 键来源相关属性
	if key_source_type == KeySourceType.DIRECT:
		if property.name in ["key_variable", "key_variable_scope", "key_scope_source", "key_custom_scope_id", "key_target_node_path_for_scope"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	elif key_source_type == KeySourceType.FROM_VARIABLE:
		if property.name == "key_value":
			property.usage = PROPERTY_USAGE_NO_EDITOR

		# 键变量作用域相关属性
		if key_variable_scope == BaseVariable.VariableScope.SCOPE:
			if property.name == "key_scope_source":
				return
			elif property.name == "key_custom_scope_id":
				if key_scope_source != ScopeSource.CUSTOM_ID:
					property.usage = PROPERTY_USAGE_NO_EDITOR
			elif property.name == "key_target_node_path_for_scope":
				if key_scope_source != ScopeSource.TARGET_NODE:
					property.usage = PROPERTY_USAGE_NO_EDITOR
		else:
			if property.name in ["key_scope_source", "key_custom_scope_id", "key_target_node_path_for_scope"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR

	# 目标作用域相关属性
	if target_scope == BaseVariable.VariableScope.SCOPE:
		if property.name == "target_scope_source":
			return
		elif property.name == "target_custom_scope_id":
			if target_scope_source != ScopeSource.CUSTOM_ID:
				property.usage = PROPERTY_USAGE_NO_EDITOR
		elif property.name == "target_node_path_for_scope":
			if target_scope_source != ScopeSource.TARGET_NODE:
				property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		if property.name in ["target_scope_source", "target_custom_scope_id", "target_node_path_for_scope"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR

## 获取指令描述
func get_description() -> String:
	var dict_str = dict_variable if not dict_variable.is_empty() else "No Dict"

	var key_str := ""
	match key_source_type:
		KeySourceType.DIRECT:
			key_str = "\"%s\"" % key_value if not key_value.is_empty() else "No Key"
		KeySourceType.FROM_VARIABLE:
			key_str = "var:%s" % key_variable if not key_variable.is_empty() else "No Key Var"

	var target_str = target_variable if not target_variable.is_empty() else "No Target"

	return "Dict Get: %s[%s] → %s" % [dict_str, key_str, target_str]

## 重置指令状态
func reset():
	super.reset()
	_log_debug_localized("FUSE_LOG_DICT_GET_VALUE_RESET", {})
