@tool
@icon("res://addons/fuse/icons/builtin/Variant.png")
extends BaseInstruction
class_name CreateVariable

# 预加载工具类

# 关键：实现这个静态方法，用于指令选择器
static func _get_instruction_metadata() -> InstructionMetadata:
	metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_CREATE_VARIABLE_NAME"
	metadata.category_key = "FUSE_CATEGORY_VARIABLES"
	metadata.description_key = "FUSE_INSTRUCTION_CREATE_VARIABLE_DESC"
	metadata.keywords = ["变量", "创建", "赋值", "存储", "全局", "局部", "variable", "create", "assign", "store", "global", "local"]
	metadata.builtin_icon = "Variant"
	return metadata

## 变量名称
@export var variable_name: String = "":
	set(value):
		variable_name = value
		_update_resource_name()

## 变量值 - 直接使用 Variant
@export var value: Variant:
	set(new_value):
		value = new_value
		_update_resource_name()
		_log_info("变量值已更新: %s" % str(new_value))

## 变量描述（可选）
@export var description: String = "":
	set(value):
		description = value
		_update_resource_name()

## 作用域来源（仅当 variable_scope == SCOPE 时生效）
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

## 变量作用域
@export var variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		if variable_scope != value:
			variable_scope = value
			_update_resource_name()
			notify_property_list_changed()  # 触发检视器更新
			_on_variable_scope_changed()

## 作用域来源（仅当 variable_scope == SCOPE 时使用）
var scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		scope_source = value
		_update_resource_name()
		notify_property_list_changed()

## 自定义作用域 ID（CUSTOM_ID 模式使用）
var custom_scope_id: String = "":
	set(value):
		custom_scope_id = value
		_update_resource_name()

## 目标节点路径（TARGET_NODE 模式使用）
var target_node_path: NodePath = NodePath(""):
	set(value):
		target_node_path = value
		_update_resource_name()

## 持久化设置（仅对全局变量有效）
@export var persistent: bool = false:
	set(value):
		persistent = value
		_update_resource_name()

## 资源管理设置
@export var auto_detect_assistant: bool = true:
	set(value):
		auto_detect_assistant = value
		_update_resource_name()

## 检测到的 GlobalVariableAssistant 节点（运行时设置）
var detected_assistant: GlobalVariableAssistant = null

## 目标资源路径（运行时获取）
var target_resource_path: String = ""

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties := []

	# 添加 ScopeSource 相关属性（仅当 variable_scope == SCOPE 时显示）
	if variable_scope == BaseVariable.VariableScope.SCOPE:
		properties.append({
			name = "Scope Configuration",
			type = TYPE_NIL,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_CATEGORY
		})

		properties.append({
			name = "scope_source",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 根据作用域来源添加额外属性
		if scope_source == ScopeSource.CUSTOM_ID:
			properties.append({
				name = "custom_scope_id",
				type = TYPE_STRING,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})
		elif scope_source == ScopeSource.TARGET_NODE:
			properties.append({
				name = "target_node_path",
				type = TYPE_NODE_PATH,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

	return properties

## 实现条件化检视器显示（使用 _validate_property 方法）
func _validate_property(property: Dictionary) -> void:
	# 当作用域为 LOCAL 或 GLOBAL 时，禁用 ScopeSource 相关属性
	# 只有 SCOPE 变量使用 ScopeSource
	if variable_scope != BaseVariable.VariableScope.SCOPE:
		if property.name in ["scope_source", "custom_scope_id", "target_node_path"]:
			property.usage = PROPERTY_USAGE_READ_ONLY

	# 当作用域为 LOCAL 或 SCOPE 时，禁用 persistent 和 auto_detect_assistant 属性
	# 只有 GLOBAL 变量支持持久化
	if variable_scope == BaseVariable.VariableScope.LOCAL or variable_scope == BaseVariable.VariableScope.SCOPE:
		if property.name == "persistent":
			property.usage = PROPERTY_USAGE_READ_ONLY
		elif property.name == "auto_detect_assistant":
			property.usage = PROPERTY_USAGE_READ_ONLY

## 变量作用域变化时的处理
func _on_variable_scope_changed() -> void:
	# 当作用域改变时，自动调整相关设置
	if variable_scope == BaseVariable.VariableScope.LOCAL or variable_scope == BaseVariable.VariableScope.SCOPE:
		# 局部变量和作用域变量自动禁用持久化和自动检测
		persistent = false
		auto_detect_assistant = false
		var scope_name = "局部" if variable_scope == BaseVariable.VariableScope.LOCAL else "作用域"
		_log_debug("切换到%s作用域，已禁用持久化和自动检测功能" % scope_name)

## 创建的变量实例
var _created_variable: BaseVariable = null

## 设置指令元数据
func _setup_metadata():
	pass

## 更新资源名称
func _update_resource_name():
	var parts = []

	# 基础信息
	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_CREATE_VARIABLE_RESOURCE"))

	# 作用域信息
	var scope_str = VariableScopeUtils.enum_to_string(variable_scope)
	parts.append("[%s]" % scope_str.to_upper())

	# 变量名称
	if not variable_name.is_empty():
		parts.append(variable_name)
	else:
		parts.append(FuseLocalization.translate("FUSE_VARIABLE_UNNAMED"))

	# 值信息（截断显示）
	if value != null:
		var value_str = str(value)
		if value_str.length() > 15:
			value_str = value_str.substr(0, 12) + "..."
		parts.append("= %s" % value_str)

	# 全局变量特定信息
	if variable_scope == BaseVariable.VariableScope.GLOBAL:
		# 显示持久化状态
		if persistent:
			parts.append(FuseLocalization.translate("FUSE_VARIABLE_PERSISTENT"))

		# 显示自动检测状态
		if auto_detect_assistant:
			parts.append(FuseLocalization.translate("FUSE_VARIABLE_AUTO_DETECT"))

		detected_assistant = GlobalVariableAssistant.get_instance()
		if detected_assistant != null:
			pass
		elif not target_resource_path.is_empty():
			parts.append("→ %s" % FuseNodeUtils.get_path_display_name(target_resource_path))
		else:
			parts.append("→ %s" % FuseLocalization.translate("FUSE_VARIABLE_RESOURCE_NOT_DETECTED"))

	# 作用域变量特定信息
	elif variable_scope == BaseVariable.VariableScope.SCOPE:
		var scope_info = _get_scope_source_string()
		parts.append("[%s]" % scope_info)

	# 组合最终名称
	resource_name = " ".join(parts)

## 获取作用域来源字符串
func _get_scope_source_string() -> String:
	return VariableScopeUtils.get_scope_source_string(
		scope_source as VariableScopeUtils.ScopeSource,
		custom_scope_id,
		target_node_path
	)

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	# 验证参数
	var errors = validate()
	if not errors.is_empty():
		var error_message = FuseLocalization.translate_format("FUSE_ERROR_VALIDATION_FAILED", {"errors": ", ".join(errors)})
		_log_error_localized("FUSE_ERROR_VALIDATION_FAILED", {"errors": ", ".join(errors)})
		set_error_localized("FUSE_ERROR_VALIDATION_FAILED", FuseError.ErrorType.VALIDATION_ERROR, {"errors": ", ".join(errors)})
		finished.emit()
		return

	# 对于全局变量，检测 GlobalVariableAssistant
	if variable_scope == BaseVariable.VariableScope.GLOBAL:
		if not _detect_and_validate_assistant():
			_log_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", {"node": "GlobalVariableAssistant"})
			set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"node": "GlobalVariableAssistant"})
			finished.emit()
			return

	# 尝试创建变量
	_created_variable = _create_variable()
	if not _created_variable:
		_log_error_localized("FUSE_ERROR_EXECUTION_FAILED", {"instruction": "CreateVariable"})
		set_error_localized("FUSE_ERROR_EXECUTION_FAILED", FuseError.ErrorType.RUNTIME_ERROR, {"instruction": "CreateVariable"})
		finished.emit()
		return

	# 检查变量是否有效创建
	if not _created_variable.is_initialized:
		_log_error_localized("FUSE_ERROR_EXECUTION_FAILED", {"instruction": "CreateVariable - initialization"})
		set_error_localized("FUSE_ERROR_EXECUTION_FAILED", FuseError.ErrorType.RUNTIME_ERROR, {"instruction": "CreateVariable - initialization"})
		finished.emit()
		return

	_add_to_context(_created_variable, context)
	_log_info_localized("FUSE_LOG_CREATING_VARIABLE", {"name": variable_name, "value": str(value)})
	_on_execution_completed()

## 创建变量（简化版本）
func _create_variable() -> BaseVariable:
	# 验证变量名称
	if variable_name.is_empty():
		_log_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", {})
		return null

	# 使用新的 create 方法创建变量
	var variable = BaseVariable.create(
		variable_name,
		value,
		variable_scope
	)

	# 设置描述（如果提供）
	if not description.is_empty():
		# 可以通过自定义属性或元数据存储描述
		variable.set_meta("description", description)

	# 设置持久化属性
	variable.persistent = persistent

	return variable

## 检测并验证 GlobalVariableAssistant（简化版本 - 使用单例）
func _detect_and_validate_assistant() -> bool:
	if not auto_detect_assistant:
		_log_warning_localized("FUSE_WARNING_AUTO_DETECT_DISABLED", {})
		return false

	# 直接使用单例实例
	detected_assistant = GlobalVariableAssistant.get_instance()
	if detected_assistant == null:
		_log_error_localized("FUSE_ERROR_ASSISTANT_NOT_FOUND", {})
		set_error_localized("FUSE_ERROR_ASSISTANT_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return false

	# 检查 current_resource
	if detected_assistant.current_resource == null:
		_log_error_localized("FUSE_ERROR_ASSISTANT_NO_RESOURCE", {"node": detected_assistant.name})
		set_error_localized("FUSE_ERROR_ASSISTANT_NO_RESOURCE", FuseError.ErrorType.CONFIGURATION_ERROR, {"node": detected_assistant.name})
		return false

	# 使用 current_resource 的实际路径
	target_resource_path = detected_assistant.current_resource.resource_path
	if target_resource_path.is_empty():
		_log_warning_localized("FUSE_WARNING_ASSISTANT_NO_RESOURCE_PATH", {})

	_log_info_localized("FUSE_LOG_ASSISTANT_FOUND", {"node": detected_assistant.name, "path": target_resource_path})

	return true

## 检测场景中的 GlobalVariableAssistant 节点（简化版本 - 使用单例）
func _detect_global_variable_assistant() -> GlobalVariableAssistant:
	# 直接使用单例，简化检测逻辑
	return GlobalVariableAssistant.get_instance()

## 将变量添加到上下文（使用 VariableOperations 工具类）
func _add_to_context(variable: BaseVariable, context: ExecutionContext):
	if not context:
		_log_error_localized("FUSE_ERROR_CONTEXT_EMPTY", {})
		return

	# 根据作用域处理变量添加
	match variable_scope:
		BaseVariable.VariableScope.LOCAL:
			# 使用 VariableOperations 设置局部变量
			var success = VariableOperations.set_variable(context, variable_name, BaseVariable.VariableScope.LOCAL, variable.value)
			if not success:
				_log_error_localized("FUSE_ERROR_LOCAL_VAR_ADD_FAILED", {"name": variable_name})
				return

			_log_info_localized("FUSE_LOG_LOCAL_VAR_ADDED", {"name": variable_name})

		BaseVariable.VariableScope.SCOPE:
			# 根据 ScopeSource 设置作用域变量
			if scope_source == ScopeSource.NEAREST:
				# NEAREST 模式：使用 VariableOperations 的默认行为
				var success = VariableOperations.set_variable(context, variable_name, BaseVariable.VariableScope.SCOPE, variable.value)
				if not success:
					_log_error_localized("FUSE_ERROR_SCOPE_VAR_ADD_FAILED", {"name": variable_name})
					return
				_log_info_localized("FUSE_LOG_SCOPE_VAR_ADDED", {"name": variable_name})
			else:
				# 其他模式：获取指定作用域容器并设置变量
				var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
				var scope_container = VariableScopeUtils.get_scope_container_by_source(
					context,
					utils_scope_source,
					custom_scope_id,
					target_node_path
				)

				if scope_container == null:
					_log_error_localized("FUSE_ERROR_SCOPE_CONTAINER_NOT_FOUND", {})
					return

				# 设置作用域变量
				var success = scope_container.set_variable(variable_name, variable.value)
				if not success:
					_log_error_localized("FUSE_ERROR_SET_SCOPE_VARIABLE_FAILED", {"name": variable_name})
					return

				_log_info_localized("FUSE_LOG_SCOPE_VAR_ADDED", {"name": variable_name})

		BaseVariable.VariableScope.GLOBAL:
			# 全局变量需要通过 GlobalVariableAssistant 处理（支持持久化）
			if not _add_global_variable_to_resource(variable):
				_log_error_localized("FUSE_ERROR_GLOBAL_VAR_ADD_FAILED", {"name": variable_name})
				return

			# 同时设置到 ExecutionContext 的全局变量引用
			var success = VariableOperations.set_variable(context, variable_name, BaseVariable.VariableScope.GLOBAL, variable.value)
			if not success:
				_log_warning_localized("FUSE_WARNING_GLOBAL_VAR_CONTEXT_SET_FAILED", {"name": variable_name})

			_log_info_localized("FUSE_LOG_GLOBAL_VAR_ADDED_TO_CONTEXT", {"name": variable_name})

## 将全局变量添加到资源（重构版本 - 使用 GlobalVariableAssistant 的 add_global_variable 方法）
func _add_global_variable_to_resource(variable: BaseVariable) -> bool:
	if detected_assistant == null:
		_log_error_localized("FUSE_ERROR_ASSISTANT_NOT_DETECTED", {})
		return false

	# 使用 GlobalVariableAssistant 的 add_global_variable 方法添加变量
	var success = detected_assistant.add_global_variable(variable_name, variable)
	if not success:
		_log_error_localized("FUSE_ERROR_ASSISTANT_ADD_FAILED", {"name": variable_name})
		# 获取 GlobalVariableAssistant 的错误信息以提供更详细的错误描述
		if detected_assistant.has_method("get_fuse_error") and detected_assistant.has_fuse_error():
			var assistant_error = detected_assistant.get_fuse_error()
			_log_error_localized("FUSE_ERROR_ASSISTANT_ERROR_DETAILS", {"details": assistant_error.get_message()})
		return false

	_log_info_localized("FUSE_LOG_GLOBAL_VAR_ADDED_TO_RESOURCE", {"name": variable_name, "resource": target_resource_path})
	return true

## 获取指令描述
func get_description() -> String:
	var desc_parts = []

	# 基础描述
	var scope_str = VariableScopeUtils.enum_to_string(variable_scope)
	desc_parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_CREATE_VARIABLE_DESC_BASE", {"scope": VariableScopeUtils.enum_to_display_name(variable_scope)}))

	# 变量名称
	if not variable_name.is_empty():
		desc_parts.append("'%s'" % variable_name)
	else:
		desc_parts.append(FuseLocalization.translate("FUSE_VARIABLE_NOT_SPECIFIED"))

	# 值信息
	if value != null:
		desc_parts.append(FuseLocalization.translate_format("FUSE_VARIABLE_VALUE_FORMAT", {"value": str(value)}))

	# 描述信息
	if not description.is_empty():
		desc_parts.append(FuseLocalization.translate_format("FUSE_VARIABLE_DESCRIPTION_FORMAT", {"description": description}))

	# 全局变量资源信息
	if variable_scope == BaseVariable.VariableScope.GLOBAL:
		if detected_assistant != null:
			desc_parts.append(FuseLocalization.translate_format("FUSE_VARIABLE_RESOURCE_NODE_FORMAT", {"node": detected_assistant.name}))
			if not target_resource_path.is_empty():
				desc_parts.append(FuseLocalization.translate_format("FUSE_VARIABLE_RESOURCE_FILE_FORMAT", {"file": target_resource_path}))
		elif auto_detect_assistant:
			desc_parts.append(FuseLocalization.translate("FUSE_VARIABLE_AUTO_DETECT_NODE"))
		else:
			desc_parts.append(FuseLocalization.translate("FUSE_VARIABLE_RESOURCE_NOT_CONFIGURED"))

	return ", ".join(desc_parts)

## 验证指令参数（优化版本）
func validate() -> Array[String]:
	var errors = super.validate()
	
	# 验证基础属性
	_validate_basic_properties(errors)
	
	# 验证作用域设置
	_validate_scope_settings(errors)
	
	return errors

## 验证基础属性
func _validate_basic_properties(errors: Array[String]) -> void:
	"""验证变量名称、类型和默认值等基础属性"""
	# 验证变量名称
	if variable_name.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_VAR_NAME_EMPTY"))
	elif not _is_valid_variable_name(variable_name):
		errors.append(FuseLocalization.translate("FUSE_ERROR_VAR_NAME_INVALID"))

## 验证作用域设置
func _validate_scope_settings(errors: Array[String]) -> void:
	"""验证作用域相关的设置，包括持久化和资源依赖"""
	# 验证作用域和持久化设置（只有 GLOBAL 支持持久化）
	if (variable_scope == BaseVariable.VariableScope.LOCAL or variable_scope == BaseVariable.VariableScope.SCOPE) and persistent:
		var scope_name = "局部" if variable_scope == BaseVariable.VariableScope.LOCAL else "作用域"
		errors.append(FuseLocalization.translate_format("FUSE_ERROR_SCOPE_NOT_SUPPORT_PERSISTENT", {"scope": scope_name}))

	# 验证 SCOPE 作用域的 ScopeSource 参数
	if variable_scope == BaseVariable.VariableScope.SCOPE:
		var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
		errors.append_array(VariableScopeUtils.validate_scope_source_params(
			utils_scope_source,
			custom_scope_id,
			target_node_path
		))

	# 验证全局变量的资源依赖（重构版本 - 仅检测 GlobalVariableAssistant）
	if variable_scope == BaseVariable.VariableScope.GLOBAL:
		if auto_detect_assistant:
			# 检查是否可以获取到 GlobalVariableAssistant 单例
			var test_assistant = GlobalVariableAssistant.get_instance()
			if test_assistant == null:
				errors.append(FuseLocalization.translate("FUSE_ERROR_ASSISTANT_NOT_FOUND"))
			else:
				# 只需要检测 GlobalVariableAssistant 单例
				detected_assistant = test_assistant
		else:
			errors.append(FuseLocalization.translate("FUSE_ERROR_GLOBAL_VAR_AUTO_DETECT_REQUIRED"))

## 验证变量名称
func _is_valid_variable_name(name: String) -> bool:
	if name.is_empty():
		return false

	# 去除前后空格后检查
	var trimmed_name = name.strip_edges()
	if trimmed_name != name:
		_log_warning("变量名包含前后空格: '%s'" % name)
		return false

	# 检查是否以字母或下划线开头
	var first_char = name[0]
	# 首字符必须是字母或下划线（不能是数字）
	if not (first_char.is_valid_identifier() and not first_char.is_valid_int()):
		_log_warning("变量名首字符必须是字母或下划线: '%s' (字符代码: %d)" % [first_char, first_char.unicode_at(0)])
		return false

	# 检查是否只包含有效字符（字母、数字、下划线）
	for i in range(1, name.length()):
		var char = name[i]
		# 允许字母、数字和下划线
		var is_valid_char = char.is_valid_identifier() or char.is_valid_int()
		if not is_valid_char:
			_log_warning("变量名包含无效字符: '%s' (位置: %d, 字符代码: %d)" % [char, i, char.unicode_at(0)])
			return false

	return true

## 取消指令执行
func cancel():
	if is_running():
		_log_debug("取消变量创建指令")
		super.cancel()

## 资源清理
func _cleanup_resources():
	super._cleanup_resources()
	_created_variable = null
	detected_assistant = null
	target_resource_path = ""
	_log_debug("CreateVariableInstruction 资源清理完成")

## 重置指令状态
func reset():
	super.reset()
	_created_variable = null
	detected_assistant = null
	target_resource_path = ""
	_log_debug("CreateVariableInstruction 状态已重置")

## 获取创建的变量
func get_created_variable() -> BaseVariable:
	return _created_variable

## 获取检测到的助手节点信息
func get_assistant_info() -> Dictionary:
	if detected_assistant == null:
		return {}
	
	return {
		"name": detected_assistant.name,
		"resource_path": target_resource_path,
		"has_current_resource": detected_assistant.current_resource != null,
		"auto_save": detected_assistant.auto_save,
		"is_registered": detected_assistant._is_registered if detected_assistant.has_method("_get_is_registered") else false
	}

## 检查资源状态
func check_resource_status() -> Dictionary:
	var status = {
		"has_assistant": detected_assistant != null,
		"has_resource_path": not target_resource_path.is_empty(),
		"resource_exists": false,
		"resource_valid": false,
		"assistant_name": "",
		"resource_info": {}
	}
	
	if detected_assistant != null:
		status["assistant_name"] = detected_assistant.name
		
		if not target_resource_path.is_empty():
			status["resource_exists"] = FileAccess.file_exists(target_resource_path)
			
			if detected_assistant.current_resource != null:
				status["resource_valid"] = detected_assistant.current_resource is GlobalVariableResource
				status["resource_info"] = detected_assistant.get_current_resource_info()
	
	return status

## 使用父类的 FuseError 处理机制
## BaseInstruction 已经提供了完整的 FuseError 支持

## 统一日志方法
func _log_debug(message: String):
	FuseLogger.log_debug("CreateVariableInstruction", log_level, message, variable_name)

func _log_info(message: String):
	FuseLogger.log_info("CreateVariableInstruction", log_level, message, variable_name)

func _log_warning(message: String):
	FuseLogger.log_warning("CreateVariableInstruction", log_level, message, variable_name)

func _log_error(message: String):
	FuseLogger.log_error("CreateVariableInstruction", log_level, message, variable_name)

## 记录变量创建过程（新增 - 智能日志记录）
func _log_creation_process(context: ExecutionContext):
	"""记录变量创建的详细过程，包含上下文信息"""
	_log_info("开始创建变量: %s (作用域: %s)" % [
		variable_name,
		VariableScopeUtils.enum_to_string(variable_scope).to_upper()
	])
	
	if value == null:
		_log_debug("使用 null 值")
	else:
		_log_debug("使用用户指定的值: %s" % str(value))
	
	# 记录全局变量的资源信息
	if variable_scope == BaseVariable.VariableScope.GLOBAL:
		if detected_assistant != null:
			_log_debug("检测到 GlobalVariableAssistant: %s" % detected_assistant.name)
			if not target_resource_path.is_empty():
				_log_debug("目标资源路径: %s" % target_resource_path)
		else:
			_log_debug("未检测到 GlobalVariableAssistant，将尝试自动检测")

## 记录验证性能（新增 - 性能监控）
func _record_validation_performance(start_time: float):
	"""记录验证性能，如果验证耗时过长则发出警告"""
	var validation_time = Time.get_ticks_msec() / 1000.0 - start_time
	if validation_time > 0.1:  # 超过100ms记录警告
		_log_warning("验证耗时过长: %.2f ms" % (validation_time * 1000))
	else:
		_log_debug("验证完成，耗时: %.2f ms" % (validation_time * 1000))
