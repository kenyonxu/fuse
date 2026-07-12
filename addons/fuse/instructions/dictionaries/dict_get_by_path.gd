@tool
@icon("res://addons/fuse/icons/builtin/Get.svg")
extends BaseInstruction
class_name DictGetByPath

## DictGetByPath 指令
##
## 通过嵌套路径访问字典中的值并存储到目标变量。
## 路径格式: "player/stats/hp" 表示 dict["player"]["stats"]["hp"]
## path_separator 参数控制路径分隔符（默认 "/"）。
## 支持默认值（路径不存在时返回）。
## 支持从变量获取路径。
##
## 使用 VariableOperations 统一变量访问 API

## 作用域来源枚举
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

# 路径来源类型
enum PathSourceType {
	DIRECT,         # 直接输入路径
	FROM_VARIABLE   # 从变量获取路径
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

# 路径来源类型
var path_source_type: PathSourceType = PathSourceType.DIRECT:
	set(value):
		if path_source_type != value:
			path_source_type = value
			_update_resource_name()
			notify_property_list_changed()

# 路径值（直接输入）
var path_value: String = "":
	set(value):
		path_value = value
		_update_resource_name()

# 路径变量名（从变量获取）
var path_variable: String = "":
	set(value):
		path_variable = value
		_update_resource_name()

# 路径变量作用域
var path_variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		if path_variable_scope != value:
			path_variable_scope = value
			_update_resource_name()
			notify_property_list_changed()

## 路径变量作用域来源（仅当 path_variable_scope == SCOPE 时使用）
var path_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		if path_scope_source != value:
			path_scope_source = value
			_update_resource_name()
			notify_property_list_changed()

## 自定义路径变量作用域 ID
var path_custom_scope_id: String = "":
	set(value):
		if path_custom_scope_id != value:
			path_custom_scope_id = value
			_update_resource_name()

## 路径变量目标节点路径
var path_target_node_path_for_scope: NodePath = NodePath(""):
	set(value):
		if path_target_node_path_for_scope != value:
			path_target_node_path_for_scope = value
			_update_resource_name()

# 路径分隔符
var path_separator: String = "/":
	set(value):
		path_separator = value
		_update_resource_name()

# 默认值（路径不存在时返回）
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
	metadata.name_key = "FUSE_INSTRUCTION_DICT_GET_BY_PATH_NAME"
	metadata.category_key = "FUSE_CATEGORY_DICTIONARIES"
	metadata.description_key = "FUSE_INSTRUCTION_DICT_GET_BY_PATH_DESC"
	metadata.keywords = ["字典", "路径", "获取", "读取", "dictionary", "dict", "path", "get", "嵌套"]
	metadata.builtin_icon = "Get"
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

## 声明变量读写模式（dict=read, path=read, target=write 取值结果）
func get_variable_modes() -> Array[Dictionary]:
	return [
		{"name": "dict_variable", "mode": "read"},
		{"name": "path_variable", "mode": "read"},
		{"name": "target_variable", "mode": "write"},
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

	# Path 分类
	properties.append({
		name = "Path",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "path_source_type",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Direct,FromVariable",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 路径（直接输入模式）
	if path_source_type == PathSourceType.DIRECT:
		properties.append({
			name = "path_value",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

	# 路径变量（从变量获取模式）
	if path_source_type == PathSourceType.FROM_VARIABLE:
		properties.append({
			name = "path_variable",
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

		# 只在 path_variable_scope == SCOPE 时显示路径变量 ScopeSource 配置
		if path_variable_scope == BaseVariable.VariableScope.SCOPE:
			properties.append({
				name = "Path Variable Scope Configuration",
				type = TYPE_NIL,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_CATEGORY
			})

			properties.append({
				name = "path_scope_source",
				type = TYPE_INT,
				hint = PROPERTY_HINT_ENUM,
				hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

			if path_scope_source == ScopeSource.CUSTOM_ID:
				properties.append({
					name = "path_custom_scope_id",
					type = TYPE_STRING,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})
			elif path_scope_source == ScopeSource.TARGET_NODE:
				properties.append({
					name = "path_target_node_path_for_scope",
					type = TYPE_NODE_PATH,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})

	# 路径分隔符（始终显示）
	properties.append({
		name = "path_separator",
		type = TYPE_STRING,
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
	var path_str := ""
	var target_str := ""

	# 字典信息
	if dict_variable.is_empty():
		dict_str = FuseLocalization.translate("FUSE_INSTRUCTION_DICT_NO_DICT")
	else:
		dict_str = FuseLocalization.translate_format("FUSE_INSTRUCTION_DICT_DICT", {"name": dict_variable})

	# 路径信息
	match path_source_type:
		PathSourceType.DIRECT:
			if path_value.is_empty():
				path_str = FuseLocalization.translate("FUSE_INSTRUCTION_DICT_NO_PATH")
			else:
				path_str = "\"%s\"" % path_value
		PathSourceType.FROM_VARIABLE:
			if path_variable.is_empty():
				path_str = FuseLocalization.translate("FUSE_INSTRUCTION_DICT_NO_PATH_VAR")
			else:
				path_str = FuseLocalization.translate_format("FUSE_INSTRUCTION_DICT_PATH_VAR", {"name": path_variable})

	# 目标信息
	if target_variable.is_empty():
		target_str = FuseLocalization.translate("FUSE_INSTRUCTION_DICT_NO_TARGET")
	else:
		target_str = target_variable

	resource_name = " ".join(["Dict Get Path", dict_str, "[%s]" % path_str, "→", target_str])

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	_log_debug_localized("FUSE_LOG_INSTRUCTION_START", {"instruction": "DictGetByPath"})

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

	# 获取路径
	var path: String = _get_path(context)

	if path.is_empty():
		_log_error_localized("FUSE_INSTRUCTION_DICT_NO_PATH", {})
		set_error_localized("FUSE_INSTRUCTION_DICT_NO_PATH", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 验证目标变量名
	if target_variable.is_empty():
		_log_error_localized("FUSE_ERROR_TARGET_VARIABLE_EMPTY", {})
		set_error_localized("FUSE_ERROR_TARGET_VARIABLE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 验证路径分隔符
	if path_separator.is_empty():
		_log_error_localized("FUSE_ERROR_PATH_SEPARATOR_EMPTY", {})
		set_error_localized("FUSE_ERROR_PATH_SEPARATOR_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 通过路径获取值
	var result = _get_value_by_path(target_dict, path, path_separator)

	# 存储到目标变量
	_set_target_variable(context, result.value)

	if result.found:
		_log_info_localized("FUSE_LOG_DICT_GET_BY_PATH", {"path": path, "value": str(result.value), "target": target_variable})
	else:
		_log_info_localized("FUSE_LOG_DICT_GET_BY_PATH_DEFAULT", {"path": path, "default": str(default_value), "target": target_variable})

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

## 获取路径
func _get_path(context: ExecutionContext) -> String:
	match path_source_type:
		PathSourceType.DIRECT:
			return path_value

		PathSourceType.FROM_VARIABLE:
			if path_variable.is_empty():
				return ""

			var path_result: Variant = null
			match path_variable_scope:
				BaseVariable.VariableScope.LOCAL:
					path_result = VariableOperations.get_variable(context, path_variable, BaseVariable.VariableScope.LOCAL, null)

				BaseVariable.VariableScope.SCOPE:
					if path_scope_source == ScopeSource.NEAREST:
						path_result = VariableOperations.get_variable(context, path_variable, BaseVariable.VariableScope.SCOPE, null)
					else:
						var utils_scope_source = path_scope_source as VariableScopeUtils.ScopeSource
						var scope_container = VariableScopeUtils.get_scope_container_by_source(
							context,
							utils_scope_source,
							path_custom_scope_id,
							path_target_node_path_for_scope
						)
						if scope_container == null:
							return ""
						if scope_container.has_variable(path_variable):
							path_result = scope_container.get_variable(path_variable, null)

				BaseVariable.VariableScope.GLOBAL:
					path_result = VariableOperations.get_variable(context, path_variable, BaseVariable.VariableScope.GLOBAL, null)

			if path_result is String:
				return path_result
			return ""

	return ""

## 通过路径获取值
## 返回 Dictionary: {"found": bool, "value": Variant}
func _get_value_by_path(dict: Dictionary, path: String, separator: String) -> Dictionary:
	if path.is_empty():
		return {"found": false, "value": default_value}

	var keys = path.split(separator)
	var current: Variant = dict

	for key in keys:
		# 跳过空键（处理连续分隔符）
		if key.is_empty():
			continue

		# 检查当前值是否为字典
		if not current is Dictionary:
			return {"found": false, "value": default_value}

		# 检查键是否存在
		if not current.has(key):
			return {"found": false, "value": default_value}

		# 继续深入
		current = current[key]

	return {"found": true, "value": current}

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

	# 验证路径配置
	match path_source_type:
		PathSourceType.DIRECT:
			if path_value.is_empty():
				errors.append(FuseLocalization.translate("FUSE_INSTRUCTION_DICT_NO_PATH"))

		PathSourceType.FROM_VARIABLE:
			if path_variable.is_empty():
				errors.append(FuseLocalization.translate("FUSE_ERROR_PATH_VARIABLE_EMPTY"))

			if path_variable_scope == BaseVariable.VariableScope.SCOPE:
				var path_utils_scope_source = path_scope_source as VariableScopeUtils.ScopeSource
				errors.append_array(VariableScopeUtils.validate_scope_source_params(
					path_utils_scope_source,
					path_custom_scope_id,
					path_target_node_path_for_scope
				))

	# 验证路径分隔符
	if path_separator.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_PATH_SEPARATOR_EMPTY"))

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

	# 路径来源相关属性
	if path_source_type == PathSourceType.DIRECT:
		if property.name in ["path_variable", "path_variable_scope", "path_scope_source", "path_custom_scope_id", "path_target_node_path_for_scope"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	elif path_source_type == PathSourceType.FROM_VARIABLE:
		if property.name == "path_value":
			property.usage = PROPERTY_USAGE_NO_EDITOR

		# 路径变量作用域相关属性
		if path_variable_scope == BaseVariable.VariableScope.SCOPE:
			if property.name == "path_scope_source":
				return
			elif property.name == "path_custom_scope_id":
				if path_scope_source != ScopeSource.CUSTOM_ID:
					property.usage = PROPERTY_USAGE_NO_EDITOR
			elif property.name == "path_target_node_path_for_scope":
				if path_scope_source != ScopeSource.TARGET_NODE:
					property.usage = PROPERTY_USAGE_NO_EDITOR
		else:
			if property.name in ["path_scope_source", "path_custom_scope_id", "path_target_node_path_for_scope"]:
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

	var path_str := ""
	match path_source_type:
		PathSourceType.DIRECT:
			path_str = "\"%s\"" % path_value if not path_value.is_empty() else "No Path"
		PathSourceType.FROM_VARIABLE:
			path_str = "var:%s" % path_variable if not path_variable.is_empty() else "No Path Var"

	var target_str = target_variable if not target_variable.is_empty() else "No Target"

	return "Dict Get Path: %s[%s] → %s" % [dict_str, path_str, target_str]

## 重置指令状态
func reset():
	super.reset()
	_log_debug_localized("FUSE_LOG_DICT_GET_BY_PATH_RESET", {})
