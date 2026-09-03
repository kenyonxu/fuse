@tool
@icon("res://addons/fuse/icons/builtin/LocalVariable.png")
extends BaseInstruction
class_name SetVariable

# 预加载工具类

# 关键：实现这个静态方法，用于指令选择器
static func _get_instruction_metadata() -> InstructionMetadata:
	metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_SET_VARIABLE_NAME"
	metadata.category_key = "FUSE_CATEGORY_VARIABLES"
	metadata.description_key = "FUSE_INSTRUCTION_SET_VARIABLE_DESC"
	metadata.keywords = ["变量", "设置", "赋值", "复制", "类型检查", "Variant", "variable", "set", "assign", "copy", "type check"]
	# 设置指令选择器图标
	metadata.builtin_icon = "LocalVariable"
	return metadata

## 作用域来源
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

# 基础属性（始终显示）
@export var target_variable: String = "":
	set(value):
		target_variable = value
		_update_resource_name()

## 目标变量作用域
var target_variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		target_variable_scope = value
		_update_resource_name()
		notify_property_list_changed()

## 目标作用域来源（仅当 target_variable_scope == SCOPE 时使用）
var scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		scope_source = value
		_update_resource_name()
		notify_property_list_changed()

## 目标自定义作用域 ID
var custom_scope_id: String = "":
	set(value):
		custom_scope_id = value
		_update_resource_name()

## 目标节点路径
var target_node_path: NodePath = NodePath(""):
	set(value):
		target_node_path = value
		_update_resource_name()

# 控制属性（带 setter）
@export var set_with_another_variable: bool = false:
	set(value):
		set_with_another_variable = value
		_update_resource_name()
		notify_property_list_changed()  # 触发检视器更新

# 条件属性（始终导出，但根据条件隐藏）
@export var from_variable: String = "":
	set(value):
		from_variable = value
		_update_resource_name()

## 源变量作用域（仅当 set_with_another_variable = true 时使用）
var from_variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		from_variable_scope = value
		_update_resource_name()
		notify_property_list_changed()

## 源作用域来源（仅当 from_variable_scope == SCOPE 时使用）
var from_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		from_scope_source = value
		_update_resource_name()
		notify_property_list_changed()

## 源自定义作用域 ID
var from_custom_scope_id: String = "":
	set(value):
		from_custom_scope_id = value
		_update_resource_name()

## 源节点路径
var from_target_node_path: NodePath = NodePath(""):
	set(value):
		from_target_node_path = value
		_update_resource_name()

@export var new_value: Variant:
	set(value):
		new_value = value
		_update_resource_name()
		# 注意：不调用 notify_property_list_changed()，避免输入框失去焦点
		# new_value 的改变不会影响属性列表的结构

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	# 目标作用域配置
	properties.append({
		name = "Target Scope Configuration",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "target_variable_scope",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Local,Scope,Global",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 只在 target_variable_scope == SCOPE 时显示 ScopeSource 配置
	if target_variable_scope == BaseVariable.VariableScope.SCOPE:
		properties.append({
			name = "scope_source",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 根据目标作用域来源添加额外属性
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

	# 源作用域配置（仅当 set_with_another_variable = true 时显示）
	if set_with_another_variable:
		properties.append({
			name = "Source Scope Configuration",
			type = TYPE_NIL,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_CATEGORY
		})

		properties.append({
			name = "from_variable_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 只在 from_variable_scope == SCOPE 时显示 ScopeSource 配置
		if from_variable_scope == BaseVariable.VariableScope.SCOPE:
			properties.append({
				name = "from_scope_source",
				type = TYPE_INT,
				hint = PROPERTY_HINT_ENUM,
				hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

			# 根据源作用域来源添加额外属性
			if from_scope_source == ScopeSource.CUSTOM_ID:
				properties.append({
					name = "from_custom_scope_id",
					type = TYPE_STRING,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})
			elif from_scope_source == ScopeSource.TARGET_NODE:
				properties.append({
					name = "from_target_node_path",
					type = TYPE_NODE_PATH,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})

	return properties

# 实现条件化检视器显示（使用 _validate_property 方法）
func _validate_property(property: Dictionary) -> void:
	# 当 set_with_another_variable = false 时，禁用源变量属性
	if not set_with_another_variable:
		if property.name in ["from_variable", "from_variable_scope", "from_scope_source", "from_custom_scope_id", "from_target_node_path"]:
			property.usage = PROPERTY_USAGE_READ_ONLY

	# 当 set_with_another_variable = true 时，禁用新值属性
	if set_with_another_variable and property.name == "new_value":
		property.usage = PROPERTY_USAGE_READ_ONLY

	# 控制目标作用域属性可见性
	if target_variable_scope == BaseVariable.VariableScope.SCOPE:
		VariableScopeUtils.validate_scope_source_property(property, scope_source as VariableScopeUtils.ScopeSource)
	else:
		# 非 SCOPE 作用域时隐藏 ScopeSource 相关属性
		if property.name in ["scope_source", "custom_scope_id", "target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	# 控制源作用域属性可见性
	if set_with_another_variable:
		if from_variable_scope == BaseVariable.VariableScope.SCOPE:
			VariableScopeUtils.validate_scope_source_property(property, from_scope_source as VariableScopeUtils.ScopeSource)
		else:
			# 非 SCOPE 作用域时隐藏 ScopeSource 相关属性
			if property.name in ["from_scope_source", "from_custom_scope_id", "from_target_node_path"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR

func _setup_metadata():
	pass

func execute(context: ExecutionContext):
	_start_execution(context)

	# 参数验证
	if target_variable.is_empty():
		_log_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", {})
		set_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 确定要设置的值
	var value_to_set: Variant
	if set_with_another_variable:
		# 从另一个变量获取值
		if from_variable.is_empty():
			_log_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", {})
			set_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
			finished.emit()
			return

		# 根据源作用域类型获取变量值
		match from_variable_scope:
			BaseVariable.VariableScope.LOCAL:
				value_to_set = VariableOperations.get_variable(context, from_variable, BaseVariable.VariableScope.LOCAL, null)
				if value_to_set == null and not VariableOperations.has_variable(context, from_variable, BaseVariable.VariableScope.LOCAL):
					_log_error_localized("FUSE_ERROR_VAR_NOT_FOUND", {"name": from_variable})
					set_error_localized("FUSE_ERROR_VAR_NOT_FOUND", FuseError.ErrorType.VALIDATION_ERROR, {"name": from_variable})
					finished.emit()
					return

			BaseVariable.VariableScope.SCOPE:
				# 根据源 ScopeSource 获取变量值
				if from_scope_source == ScopeSource.NEAREST:
					# NEAREST 模式：使用 VariableOperations
					value_to_set = VariableOperations.get_variable(context, from_variable, BaseVariable.VariableScope.SCOPE, null)
				else:
					# 其他模式：获取指定作用域容器并读取变量
					var utils_scope_source = from_scope_source as VariableScopeUtils.ScopeSource
					var scope_container = VariableScopeUtils.get_scope_container_by_source(
						context,
						utils_scope_source,
						from_custom_scope_id,
						from_target_node_path
					)

					if scope_container == null:
						_log_error_localized("FUSE_ERROR_SCOPE_CONTAINER_NOT_FOUND", {})
						set_error_localized("FUSE_ERROR_SCOPE_CONTAINER_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {})
						finished.emit()
						return

					# 检查变量是否存在
					if not scope_container.has_variable(from_variable):
						_log_error_localized("FUSE_ERROR_VAR_NOT_FOUND", {"name": from_variable})
						set_error_localized("FUSE_ERROR_VAR_NOT_FOUND", FuseError.ErrorType.VALIDATION_ERROR, {"name": from_variable})
						finished.emit()
						return

					value_to_set = scope_container.get_variable(from_variable)

				if value_to_set == null:
					_log_error_localized("FUSE_ERROR_VAR_NOT_FOUND", {"name": from_variable})
					set_error_localized("FUSE_ERROR_VAR_NOT_FOUND", FuseError.ErrorType.VALIDATION_ERROR, {"name": from_variable})
					finished.emit()
					return

			BaseVariable.VariableScope.GLOBAL:
				value_to_set = VariableOperations.get_variable(context, from_variable, BaseVariable.VariableScope.GLOBAL, null)
				if value_to_set == null and not VariableOperations.has_variable(context, from_variable, BaseVariable.VariableScope.GLOBAL):
					_log_error_localized("FUSE_ERROR_VAR_NOT_FOUND", {"name": from_variable})
					set_error_localized("FUSE_ERROR_VAR_NOT_FOUND", FuseError.ErrorType.VALIDATION_ERROR, {"name": from_variable})
					finished.emit()
					return
	else:
		# 使用新值
		value_to_set = new_value

	# 根据目标作用域类型设置变量
	match target_variable_scope:
		BaseVariable.VariableScope.LOCAL:
			# 保存到 LOCAL 变量
			var success = VariableOperations.set_variable(context, target_variable, BaseVariable.VariableScope.LOCAL, value_to_set)
			if not success:
				_log_error_localized("FUSE_ERROR_SET_LOCAL_VARIABLE_FAILED", {"name": target_variable})
				set_error_localized("FUSE_ERROR_SET_LOCAL_VARIABLE_FAILED", FuseError.ErrorType.RUNTIME_ERROR, {"name": target_variable})
				finished.emit()
				return

		BaseVariable.VariableScope.SCOPE:
			# 保存到 SCOPE 变量
			if scope_source == ScopeSource.NEAREST:
				# NEAREST 模式：使用 VariableOperations
				var success = VariableOperations.set_variable(context, target_variable, BaseVariable.VariableScope.SCOPE, value_to_set)
				if not success:
					_log_error_localized("FUSE_ERROR_INSTRUCTION_EXECUTION", {"instruction": "SetVariable"})
					set_error_localized("FUSE_ERROR_INSTRUCTION_EXECUTION", FuseError.ErrorType.RUNTIME_ERROR, {"instruction": "SetVariable"})
					finished.emit()
					return
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
					set_error_localized("FUSE_ERROR_SCOPE_CONTAINER_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {})
					finished.emit()
					return

				# 设置作用域变量
				var success = scope_container.set_variable(target_variable, value_to_set)
				if not success:
					_log_error_localized("FUSE_ERROR_SET_SCOPE_VARIABLE_FAILED", {"name": target_variable})
					set_error_localized("FUSE_ERROR_SET_SCOPE_VARIABLE_FAILED", FuseError.ErrorType.RUNTIME_ERROR, {"name": target_variable})
					finished.emit()
					return

		BaseVariable.VariableScope.GLOBAL:
			# 保存到 GLOBAL 变量
			var success = VariableOperations.set_variable(context, target_variable, BaseVariable.VariableScope.GLOBAL, value_to_set)
			if not success:
				_log_error_localized("FUSE_ERROR_SET_GLOBAL_VARIABLE_FAILED", {"name": target_variable})
				set_error_localized("FUSE_ERROR_SET_GLOBAL_VARIABLE_FAILED", FuseError.ErrorType.RUNTIME_ERROR, {"name": target_variable})
				finished.emit()
				return

	# 记录成功信息
	var operation_type = "复制" if set_with_another_variable else "设置"
	_log_info_localized("FUSE_LOG_SETTING_VARIABLE", {
		"name": target_variable,
		"value": str(value_to_set)
	})

	_on_execution_completed()

func _update_resource_name():
	var parts = []

	# 基础信息
	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_SET_VARIABLE_RESOURCE"))

	# 目标作用域信息
	var scope_str = _get_scope_source_string()
	parts.append("[%s]" % scope_str)

	# 变量名称
	if not target_variable.is_empty():
		parts.append("'%s'" % target_variable)
	else:
		parts.append(FuseLocalization.translate("FUSE_VARIABLE_UNNAMED"))

	# 操作类型
	if set_with_another_variable:
		if from_variable.is_empty():
			parts.append(FuseLocalization.translate_format("FUSE_VARIABLE_COPY_FROM", {"name": FuseLocalization.translate("FUSE_VALUE_VARIABLE_EMPTY")}))
		else:
			var from_scope_str = _get_from_scope_source_string()
			parts.append(FuseLocalization.translate_format("FUSE_VARIABLE_COPY_FROM", {"name": "%s [%s]" % [from_variable, from_scope_str]}))
	else:
		var value_str = str(new_value)
		if value_str.length() > 15:
			value_str = value_str.substr(0, 12) + "..."
		parts.append("= %s" % value_str)

	# 组合最终名称
	resource_name = " ".join(parts)

## 获取目标作用域来源字符串
func _get_scope_source_string() -> String:
	# 根据目标作用域类型返回不同的字符串
	match target_variable_scope:
		BaseVariable.VariableScope.LOCAL:
			return FuseLocalization.translate("FUSE_VARIABLE_SCOPE_LOCAL_STR")
		BaseVariable.VariableScope.GLOBAL:
			return FuseLocalization.translate("FUSE_VARIABLE_SCOPE_GLOBAL_STR")
		BaseVariable.VariableScope.SCOPE:
			# SCOPE 作用域时，使用 ScopeSource 获取具体域信息
			return VariableScopeUtils.get_scope_source_string(
				scope_source as VariableScopeUtils.ScopeSource,
				custom_scope_id,
				target_node_path
			)
		_:
			return FuseLocalization.translate("FUSE_VARIABLE_SCOPE_UNKNOWN")

## 获取源作用域来源字符串
func _get_from_scope_source_string() -> String:
	# 根据源作用域类型返回不同的字符串
	match from_variable_scope:
		BaseVariable.VariableScope.LOCAL:
			return FuseLocalization.translate("FUSE_VARIABLE_SCOPE_LOCAL_STR")
		BaseVariable.VariableScope.GLOBAL:
			return FuseLocalization.translate("FUSE_VARIABLE_SCOPE_GLOBAL_STR")
		BaseVariable.VariableScope.SCOPE:
			# SCOPE 作用域时，使用 ScopeSource 获取具体域信息
			return VariableScopeUtils.get_scope_source_string(
				from_scope_source as VariableScopeUtils.ScopeSource,
				from_custom_scope_id,
				from_target_node_path
			)
		_:
			return FuseLocalization.translate("FUSE_VARIABLE_SCOPE_UNKNOWN")

func validate() -> Array[String]:
	var errors = super.validate()

	if target_variable.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_VAR_NAME_EMPTY"))

	if set_with_another_variable and from_variable.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_SOURCE_VAR_NAME_EMPTY"))

	# 验证目标 ScopeSource 相关参数（仅当 target_variable_scope == SCOPE 时）
	if target_variable_scope == BaseVariable.VariableScope.SCOPE:
		var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
		errors.append_array(VariableScopeUtils.validate_scope_source_params(
			utils_scope_source,
			custom_scope_id,
			target_node_path
		))

	# 验证源 ScopeSource 相关参数（仅当使用源变量且 from_variable_scope == SCOPE 时）
	if set_with_another_variable and from_variable_scope == BaseVariable.VariableScope.SCOPE:
		var from_utils_scope_source = from_scope_source as VariableScopeUtils.ScopeSource
		errors.append_array(VariableScopeUtils.validate_scope_source_params(
			from_utils_scope_source,
			from_custom_scope_id,
			from_target_node_path
		))

	return errors

func get_description() -> String:
	var operation_key = "FUSE_VARIABLE_OPERATION_COPY" if set_with_another_variable else "FUSE_VARIABLE_OPERATION_SET"
	var operation_type = FuseLocalization.translate(operation_key)
	var source_desc = from_variable if set_with_another_variable else str(new_value)

	var from_prefix = FuseLocalization.translate("FUSE_VARIABLE_FROM") if set_with_another_variable else ""
	var scope_str = _get_scope_source_string()

	return "%s %s → %s [%s]" % [
		operation_type,
		source_desc,
		target_variable,
		scope_str
	]

func _cleanup_resources():
	super._cleanup_resources()
	_log_debug("SetVariableInstruction 资源清理完成")

func reset():
	super.reset()
	_log_debug("SetVariableInstruction 状态已重置")

## 统一日志方法
func _log_debug(message: String):
	FuseLogger.log_debug("SetVariableInstruction", log_level, message, target_variable)

func _log_info(message: String):
	FuseLogger.log_info("SetVariableInstruction", log_level, message, target_variable)

func _log_warning(message: String):
	FuseLogger.log_warning("SetVariableInstruction", log_level, message, target_variable)

func _log_error(message: String):
	FuseLogger.log_error("SetVariableInstruction", log_level, message, target_variable)
