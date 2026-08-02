@tool
@icon("res://addons/fuse/icons/builtin/Dictionary.svg")
extends BaseInstruction
class_name DictFromJson

## DictFromJson 指令
##
## 从 JSON 字符串解析字典。
## JSON 字符串可来自直接输入或变量。
## 如果 JSON 格式无效则报错。
## 如果解析结果不是字典则报错。
## 将结果存储到目标字典变量。
##
## 使用 VariableOperations 统一变量访问 API

## 作用域来源枚举
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

## JSON 源类型
enum JsonSourceType {
	DIRECT_VALUE,   ## 直接输入 JSON 字符串
	FROM_VARIABLE   ## 从变量获取 JSON 字符串
}

# 目标字典变量名
var dict_variable: String = "":
	set(value):
		if dict_variable != value:
			dict_variable = value
			_update_resource_name()

# 目标字典变量作用域
var dict_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		if dict_scope != value:
			dict_scope = value
			_update_resource_name()
			notify_property_list_changed()

## 目标字典作用域来源（仅当 dict_scope == SCOPE 时使用）
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

## JSON 源类型
var json_source_type: JsonSourceType = JsonSourceType.DIRECT_VALUE:
	set(value):
		if json_source_type != value:
			json_source_type = value
			_update_resource_name()
			notify_property_list_changed()

## JSON 字符串（直接输入）
@export_multiline var json_string: String = "":
	set(value):
		if json_string != value:
			json_string = value
			_update_resource_name()

## JSON 源变量名（当 json_source_type == FROM_VARIABLE 时使用）
var json_source_variable: String = "":
	set(value):
		if json_source_variable != value:
			json_source_variable = value
			_update_resource_name()

## JSON 源变量作用域
var json_source_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		if json_source_scope != value:
			json_source_scope = value
			_update_resource_name()
			notify_property_list_changed()

## JSON 源作用域来源（仅当 json_source_scope == SCOPE 时使用）
var json_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		if json_scope_source != value:
			json_scope_source = value
			_update_resource_name()
			notify_property_list_changed()

## JSON 源自定义作用域 ID
var json_custom_scope_id: String = "":
	set(value):
		if json_custom_scope_id != value:
			json_custom_scope_id = value
			_update_resource_name()

## JSON 源目标节点路径
var json_target_node_path: NodePath = NodePath(""):
	set(value):
		if json_target_node_path != value:
			json_target_node_path = value
			_update_resource_name()

## 获取指令元数据（用于指令选择器）
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_DICT_FROM_JSON_NAME"
	metadata.category_key = "FUSE_CATEGORY_DICTIONARIES"
	metadata.description_key = "FUSE_INSTRUCTION_DICT_FROM_JSON_DESC"
	metadata.keywords = ["字典", "JSON", "解析", "dictionary", "json", "parse", "转换"]
	metadata.builtin_icon = "Dictionary"
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

## 声明变量读写模式（dict=write 从 JSON 创建, json_source=read）
func get_variable_modes() -> Array[Dictionary]:
	return [
		{"name": "dict_variable", "mode": "write"},
		{"name": "json_source_variable", "mode": "read"},
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

	# JSON Source 分类
	properties.append({
		name = "JSON Source",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "json_source_type",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Direct Value,From Variable",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 根据源类型显示不同属性
	if json_source_type == JsonSourceType.DIRECT_VALUE:
		properties.append({
			name = "json_string",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_MULTILINE_TEXT,
			hint_string = "",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
	else:
		properties.append({
			name = "json_source_variable",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		properties.append({
			name = "json_source_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 只在 json_source_scope == SCOPE 时显示 ScopeSource 配置
		if json_source_scope == BaseVariable.VariableScope.SCOPE:
			properties.append({
				name = "JSON Source Scope Configuration",
				type = TYPE_NIL,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_CATEGORY
			})

			properties.append({
				name = "json_scope_source",
				type = TYPE_INT,
				hint = PROPERTY_HINT_ENUM,
				hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

			# 根据作用域来源添加额外属性
			if json_scope_source == ScopeSource.CUSTOM_ID:
				properties.append({
					name = "json_custom_scope_id",
					type = TYPE_STRING,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})
			elif json_scope_source == ScopeSource.TARGET_NODE:
				properties.append({
					name = "json_target_node_path",
					type = TYPE_NODE_PATH,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})

	return properties

## 更新资源名称
func _update_resource_name():
	var dict_str := ""
	var source_str := ""

	# 字典信息
	if dict_variable.is_empty():
		dict_str = FuseLocalization.translate("FUSE_INSTRUCTION_DICT_SET_NO_DICT")
	else:
		dict_str = FuseLocalization.translate_format("FUSE_INSTRUCTION_DICT_SET_DICT", {"name": dict_variable})

	# JSON 源信息
	if json_source_type == JsonSourceType.DIRECT_VALUE:
		var json_preview := json_string
		if json_preview.length() > 20:
			json_preview = json_preview.substr(0, 17) + "..."
		source_str = "\"%s\"" % json_preview
	else:
		if json_source_variable.is_empty():
			source_str = "(no var)"
		else:
			source_str = "$%s" % json_source_variable

	resource_name = " ".join(["Dict From JSON", dict_str, "<=", source_str])

## 动态属性设置（支持属性刷新）
func _set(property: StringName, value: Variant) -> bool:
	if property == "dict_variable" or property == "json_string" or property == "json_source_variable":
		_update_resource_name()
		return false

	return false

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	_log_debug_localized("FUSE_LOG_INSTRUCTION_START", {"instruction": "DictFromJson"})

	# 验证字典变量名
	if dict_variable.is_empty():
		_log_error_localized("FUSE_ERROR_DICT_VARIABLE_EMPTY", {})
		set_error_localized("FUSE_ERROR_DICT_VARIABLE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 获取 JSON 字符串
	var json_str: String
	if json_source_type == JsonSourceType.DIRECT_VALUE:
		json_str = json_string
	else:
		# 从变量获取 JSON 字符串
		if json_source_variable.is_empty():
			_log_error_localized("FUSE_ERROR_DICT_JSON_SOURCE_EMPTY", {})
			set_error_localized("FUSE_ERROR_DICT_JSON_SOURCE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
			finished.emit()
			return

		var json_value = _get_variable_value(
			context,
			json_source_variable,
			json_source_scope,
			json_scope_source,
			json_custom_scope_id,
			json_target_node_path
		)

		if json_value == null:
			_log_error_localized("FUSE_ERROR_DICT_JSON_SOURCE_NOT_FOUND", {"var": json_source_variable})
			set_error_localized("FUSE_ERROR_DICT_JSON_SOURCE_NOT_FOUND", FuseError.ErrorType.VALIDATION_ERROR, {"var": json_source_variable})
			finished.emit()
			return

		if not json_value is String:
			_log_error_localized("FUSE_ERROR_DICT_JSON_SOURCE_NOT_STRING", {"var": json_source_variable, "type": typeof(json_value)})
			set_error_localized("FUSE_ERROR_DICT_JSON_SOURCE_NOT_STRING", FuseError.ErrorType.VALIDATION_ERROR, {"var": json_source_variable, "type": typeof(json_value)})
			finished.emit()
			return

		json_str = json_value

	# 验证 JSON 字符串不为空
	if json_str.is_empty():
		_log_error_localized("FUSE_ERROR_DICT_JSON_EMPTY", {})
		set_error_localized("FUSE_ERROR_DICT_JSON_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 解析 JSON
	var json = JSON.new()
	var parse_error = json.parse(json_str)

	if parse_error != OK:
		var error_msg = json.get_error_message()
		var error_line = json.get_error_line()
		_log_error_localized("FUSE_ERROR_DICT_JSON_PARSE_FAILED", {"error": error_msg, "line": error_line})
		set_error_localized("FUSE_ERROR_DICT_JSON_PARSE_FAILED", FuseError.ErrorType.EXECUTION_ERROR, {"error": error_msg, "line": error_line})
		finished.emit()
		return

	var data = json.get_data()

	# 验证解析结果是字典
	if not data is Dictionary:
		_log_error_localized("FUSE_ERROR_DICT_JSON_NOT_DICT", {"type": typeof(data)})
		set_error_localized("FUSE_ERROR_DICT_JSON_NOT_DICT", FuseError.ErrorType.EXECUTION_ERROR, {"type": typeof(data)})
		finished.emit()
		return

	# 调试输出
	_log_debug("════════════════════════════════════════════════════")
	_log_debug("📤 DictFromJson 执行:")
	_log_debug("  • 目标字典: '%s'" % dict_variable)
	_log_debug("  • 作用域: %s" % _get_scope_name_for_log())
	_log_debug("  • JSON 源: %s" % ("直接输入" if json_source_type == JsonSourceType.DIRECT_VALUE else "变量 $%s" % json_source_variable))
	_log_debug("  • 解析结果: %d 个键" % data.size())
	_log_debug("════════════════════════════════════════════════════")

	# 设置字典变量
	_set_dict_variable(context, data)

	_log_info_localized("FUSE_LOG_DICT_FROM_JSON", {"dict": dict_variable, "count": data.size()})

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

## 设置字典变量
func _set_dict_variable(context: ExecutionContext, dict_value: Dictionary) -> void:
	match dict_scope:
		BaseVariable.VariableScope.LOCAL:
			VariableOperations.set_variable(context, dict_variable, BaseVariable.VariableScope.LOCAL, dict_value)

		BaseVariable.VariableScope.SCOPE:
			if dict_scope_source == ScopeSource.NEAREST:
				VariableOperations.set_variable(context, dict_variable, BaseVariable.VariableScope.SCOPE, dict_value)
			else:
				var utils_scope_source = dict_scope_source as VariableScopeUtils.ScopeSource
				var scope_container = VariableScopeUtils.get_scope_container_by_source(
					context,
					utils_scope_source,
					dict_custom_scope_id,
					dict_target_node_path
				)
				if scope_container != null:
					scope_container.set_variable(dict_variable, dict_value)

		BaseVariable.VariableScope.GLOBAL:
			VariableOperations.set_variable(context, dict_variable, BaseVariable.VariableScope.GLOBAL, dict_value)

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

	# 验证 JSON 源
	if json_source_type == JsonSourceType.FROM_VARIABLE:
		if json_source_variable.is_empty():
			errors.append(FuseLocalization.translate("FUSE_ERROR_DICT_JSON_SOURCE_EMPTY"))

		# 验证 JSON 源 SCOPE 作用域需要 ScopeVariableManager
		if json_source_scope == BaseVariable.VariableScope.SCOPE:
			var manager = ScopeVariableManager.get_instance()
			if manager == null:
				errors.append(FuseLocalization.translate("FUSE_ERROR_SCOPE_MANAGER_NOT_FOUND"))

			# 验证 ScopeSource 参数
			var json_utils_scope_source = json_scope_source as VariableScopeUtils.ScopeSource
			errors.append_array(VariableScopeUtils.validate_scope_source_params(
				json_utils_scope_source,
				json_custom_scope_id,
				json_target_node_path
			))
	else:
		# 验证直接输入的 JSON
		if json_string.is_empty():
			errors.append(FuseLocalization.translate("FUSE_ERROR_DICT_JSON_EMPTY"))
		else:
			# 尝试解析 JSON 以验证格式
			var json = JSON.new()
			var parse_error = json.parse(json_string)
			if parse_error != OK:
				var error_msg = json.get_error_message()
				errors.append(FuseLocalization.translate_format("FUSE_ERROR_DICT_JSON_PARSE_FAILED", {"error": error_msg, "line": json.get_error_line()}))
			elif not json.get_data() is Dictionary:
				errors.append(FuseLocalization.translate("FUSE_ERROR_DICT_JSON_NOT_DICT"))

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

	# JSON 源类型相关属性
	if json_source_type == JsonSourceType.DIRECT_VALUE:
		# 直接输入模式：隐藏变量相关属性
		if property.name in ["json_source_variable", "json_source_scope", "json_scope_source", "json_custom_scope_id", "json_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		# 变量模式：隐藏直接输入属性
		if property.name == "json_string":
			property.usage = PROPERTY_USAGE_NO_EDITOR

		# JSON 源作用域相关属性
		if json_source_scope == BaseVariable.VariableScope.SCOPE:
			if property.name == "json_scope_source":
				return  # 始终显示
			elif property.name == "json_custom_scope_id":
				if json_scope_source != ScopeSource.CUSTOM_ID:
					property.usage = PROPERTY_USAGE_NO_EDITOR
			elif property.name == "json_target_node_path":
				if json_scope_source != ScopeSource.TARGET_NODE:
					property.usage = PROPERTY_USAGE_NO_EDITOR
		else:
			if property.name in ["json_scope_source", "json_custom_scope_id", "json_target_node_path"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR

## 获取指令描述
func get_description() -> String:
	var dict_str := ""
	var source_str := ""

	if dict_variable.is_empty():
		dict_str = FuseLocalization.translate("FUSE_INSTRUCTION_DICT_SET_NO_DICT")
	else:
		dict_str = FuseLocalization.translate_format("FUSE_INSTRUCTION_DICT_SET_DICT", {"name": dict_variable})

	if json_source_type == JsonSourceType.DIRECT_VALUE:
		var json_preview := json_string
		if json_preview.length() > 30:
			json_preview = json_preview.substr(0, 27) + "..."
		source_str = "\"%s\"" % json_preview
	else:
		source_str = "$%s" % json_source_variable if not json_source_variable.is_empty() else "(no var)"

	return "Dict From JSON: %s <= %s" % [dict_str, source_str]

## 重置指令状态
func reset():
	super.reset()
	_log_debug_localized("FUSE_LOG_DICT_FROM_JSON_RESET", {})

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
