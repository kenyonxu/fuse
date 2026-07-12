@tool
@icon("res://addons/fuse/icons/builtin/Remove.png")
extends BaseInstruction
class_name DictRemoveKey

## DictRemoveKey 指令
##
## 从字典中移除指定的键。
## 如果键不存在则记录警告但不报错。
## 支持三种作用域 (LOCAL/SCOPE/GLOBAL)。
## 键名支持从变量获取或直接输入。
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

## 键名是否来自变量
var use_key_from_variable: bool = false:
	set(value):
		if use_key_from_variable != value:
			use_key_from_variable = value
			_update_resource_name()
			notify_property_list_changed()

## 键名（直接输入）
@export var key_value: Variant = ""

## 键名源变量名（当 use_key_from_variable = true 时使用）
var key_from_variable: String = ""

## 键名源变量作用域
var key_from_variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		if key_from_variable_scope != value:
			key_from_variable_scope = value
			_update_resource_name()
			notify_property_list_changed()

## 键名源作用域来源（仅当 key_from_variable_scope == SCOPE 时使用）
var key_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		if key_scope_source != value:
			key_scope_source = value
			_update_resource_name()
			notify_property_list_changed()

## 键名源自定义作用域 ID
var key_custom_scope_id: String = "":
	set(value):
		if key_custom_scope_id != value:
			key_custom_scope_id = value
			_update_resource_name()

## 键名源目标节点路径
var key_target_node_path: NodePath = NodePath(""):
	set(value):
		if key_target_node_path != value:
			key_target_node_path = value
			_update_resource_name()

## 获取指令元数据（用于指令选择器）
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_DICT_REMOVE_KEY_NAME"
	metadata.category_key = "FUSE_CATEGORY_DICTIONARIES"
	metadata.description_key = "FUSE_INSTRUCTION_DICT_REMOVE_KEY_DESC"
	metadata.keywords = ["字典", "移除", "删除", "键", "dictionary", "remove", "delete", "key"]
	metadata.builtin_icon = "Remove"
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

## 声明变量读写模式（dict=read 原地删除, key=read）
func get_variable_modes() -> Array[Dictionary]:
	return [
		{"name": "dict_variable", "mode": "read"},
		{"name": "key_from_variable", "mode": "read"},
	]

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

	# 字典作用域
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
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 键名或键名源变量
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
	# 注意：key_value 使用 @export 声明，不在 _get_property_list() 中添加
	# _validate_property() 会根据 use_key_from_variable 控制其可见性

	return properties

## 更新资源名称
func _update_resource_name():
	var dict_str := ""
	var key_str := ""

	# 字典信息
	if dict_variable.is_empty():
		dict_str = FuseLocalization.translate("FUSE_INSTRUCTION_DICT_REMOVE_KEY_NO_DICT")
	else:
		dict_str = FuseLocalization.translate_format("FUSE_INSTRUCTION_DICT_REMOVE_KEY_DICT", {"name": dict_variable})

	# 键名信息
	if use_key_from_variable:
		if key_from_variable.is_empty():
			key_str = FuseLocalization.translate("FUSE_INSTRUCTION_DICT_REMOVE_KEY_NO_KEY_VAR")
		else:
			key_str = FuseLocalization.translate_format("FUSE_INSTRUCTION_DICT_REMOVE_KEY_FROM_VAR", {"name": key_from_variable})
	else:
		var value_str = str(key_value)
		if value_str.length() > 15:
			value_str = value_str.substr(0, 12) + "..."
		key_str = value_str

	resource_name = " ".join(["Dict Remove Key", dict_str, "×", key_str])

## 动态属性设置（支持属性刷新）
func _set(property: StringName, value: Variant) -> bool:
	if property == "dict_variable" or property == "key_from_variable":
		_update_resource_name()
		return false

	if property == "key_value":
		_update_resource_name()
		return false

	return false

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	_log_debug_localized("FUSE_LOG_INSTRUCTION_START", {"instruction": "DictRemoveKey"})

	# 验证字典变量名
	if dict_variable.is_empty():
		_log_error_localized("FUSE_ERROR_DICT_VARIABLE_EMPTY", {})
		set_error_localized("FUSE_ERROR_DICT_VARIABLE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 调试输出：显示字典变量的作用域信息
	_debug_log_dict_scope_info()

	# 获取字典变量
	var target_dict = _get_dict_variable(context)

	if target_dict == null:
		_log_warning_localized("FUSE_WARNING_DICT_NOT_FOUND", {"name": dict_variable})
		# 字典不存在，直接完成
		_on_execution_completed()
		return

	# 检查是否为字典类型
	if not target_dict is Dictionary:
		_log_error_localized("FUSE_ERROR_NOT_A_DICTIONARY", {"name": dict_variable})
		set_error_localized("FUSE_ERROR_NOT_A_DICTIONARY", FuseError.ErrorType.RUNTIME_ERROR, {"name": dict_variable})
		finished.emit()
		return

	# 获取要移除的键
	var key: Variant = _get_key_value(context)

	# 检查键是否存在
	if target_dict.has(key):
		var removed_value = target_dict[key]
		target_dict.erase(key)
		_log_info_localized("FUSE_LOG_DICT_KEY_REMOVED", {"key": str(key), "value": str(removed_value)})
	else:
		_log_warning_localized("FUSE_WARNING_DICT_KEY_NOT_FOUND", {"key": str(key)})

	_on_execution_completed()

## 获取字典变量
func _get_dict_variable(context: ExecutionContext) -> Variant:
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
					return null
				if scope_container.has_variable(dict_variable):
					dict_value = scope_container.get_variable(dict_variable, null)

		BaseVariable.VariableScope.GLOBAL:
			dict_value = VariableOperations.get_variable(context, dict_variable, BaseVariable.VariableScope.GLOBAL, null)

	return dict_value

## 获取键值
func _get_key_value(context: ExecutionContext) -> Variant:
	var key: Variant

	if use_key_from_variable:
		# 从变量获取键名
		if key_from_variable.is_empty():
			_log_error_localized("FUSE_ERROR_KEY_VAR_EMPTY", {})
			set_error_localized("FUSE_ERROR_KEY_VAR_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
			return ""

		match key_from_variable_scope:
			BaseVariable.VariableScope.LOCAL:
				key = VariableOperations.get_variable(context, key_from_variable, BaseVariable.VariableScope.LOCAL, "")
			BaseVariable.VariableScope.SCOPE:
				if key_scope_source == ScopeSource.NEAREST:
					key = VariableOperations.get_variable(context, key_from_variable, BaseVariable.VariableScope.SCOPE, "")
				else:
					var utils_scope_source = key_scope_source as VariableScopeUtils.ScopeSource
					var scope_container = VariableScopeUtils.get_scope_container_by_source(
						context,
						utils_scope_source,
						key_custom_scope_id,
						key_target_node_path
					)
					if scope_container == null:
						_log_error_localized("FUSE_ERROR_SCOPE_CONTAINER_NOT_FOUND", {})
						set_error_localized("FUSE_ERROR_SCOPE_CONTAINER_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {})
						return ""
					key = scope_container.get_variable(key_from_variable, "")
			BaseVariable.VariableScope.GLOBAL:
				key = VariableOperations.get_variable(context, key_from_variable, BaseVariable.VariableScope.GLOBAL, "")
	else:
		# 使用直接值
		key = key_value

	return key

## 调试输出：显示字典变量的作用域信息
func _debug_log_dict_scope_info():
	var scope_name := ""
	match dict_scope:
		BaseVariable.VariableScope.LOCAL:
			scope_name = "LOCAL（本地）"
		BaseVariable.VariableScope.SCOPE:
			scope_name = "SCOPE（作用域）"
		BaseVariable.VariableScope.GLOBAL:
			scope_name = "GLOBAL（全局）"

	if dict_scope == BaseVariable.VariableScope.SCOPE:
		var source_name := ""
		match dict_scope_source:
			ScopeSource.NEAREST:
				source_name = "NEAREST（最近的作用域容器）"
			ScopeSource.CUSTOM_ID:
				source_name = "CUSTOM_ID（自定义ID: %s）" % dict_custom_scope_id
			ScopeSource.TRIGGER_SCOPE:
				source_name = "TRIGGER_SCOPE（Trigger节点作用域）"
			ScopeSource.TARGET_NODE:
				source_name = "TARGET_NODE（目标节点: %s）" % str(dict_target_node_path)
		_log_debug("📍 目标字典: '%s' | 作用域: %s | 来源: %s" % [dict_variable, scope_name, source_name])
	else:
		_log_debug("📍 目标字典: '%s' | 作用域: %s" % [dict_variable, scope_name])

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

	# 验证键名来自变量时的参数
	if use_key_from_variable:
		if key_from_variable.is_empty():
			errors.append(FuseLocalization.translate("FUSE_ERROR_KEY_VAR_EMPTY"))

		# 验证键名 SCOPE 作用域需要 ScopeVariableManager
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

	# 键名变量相关属性
	if use_key_from_variable:
		if property.name == "key_value":
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		if property.name in ["key_from_variable", "key_from_variable_scope", "key_scope_source", "key_custom_scope_id", "key_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	# 键名作用域相关属性
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

## 获取指令描述
func get_description() -> String:
	var dict_str := ""
	var key_str := ""

	if dict_variable.is_empty():
		dict_str = FuseLocalization.translate("FUSE_INSTRUCTION_DICT_REMOVE_KEY_DESC_NO_DICT")
	else:
		dict_str = FuseLocalization.translate_format("FUSE_INSTRUCTION_DICT_REMOVE_KEY_DESC_DICT", {"name": dict_variable})

	if use_key_from_variable:
		if key_from_variable.is_empty():
			key_str = FuseLocalization.translate("FUSE_INSTRUCTION_DICT_REMOVE_KEY_DESC_NO_VAR")
		else:
			key_str = FuseLocalization.translate_format("FUSE_INSTRUCTION_DICT_REMOVE_KEY_DESC_FROM_VAR", {"name": key_from_variable})
	else:
		key_str = str(key_value)

	return "Dict Remove Key: %s × %s" % [dict_str, key_str]

## 重置指令状态
func reset():
	super.reset()
	_log_debug_localized("FUSE_LOG_DICT_REMOVE_KEY_RESET", {})
