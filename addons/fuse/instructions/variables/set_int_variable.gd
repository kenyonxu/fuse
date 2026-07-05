@icon("res://addons/fuse/icons/builtin/int.png")
@tool
extends BaseInstruction
class_name SetIntVariable

## 设置整数变量指令
##
## 设置或复制整数值到目标变量。
## 支持三层变量体系（LOCAL、SCOPE、GLOBAL）。
##
## 重构变量系统: 2026-02-09 - 使用 VariableOperations 统一变量访问

## 作用域来源枚举
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

# 预加载工具类

# 关键：实现这个静态方法，用于指令选择器
static func _get_instruction_metadata() -> InstructionMetadata:
	metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_SET_INT_VARIABLE_NAME"
	metadata.category_key = "FUSE_CATEGORY_VARIABLES"
	metadata.description_key = "FUSE_INSTRUCTION_SET_INT_VARIABLE_DESC"
	# 正确初始化 Array[String] 类型
	metadata.keywords = ["变量", "整数", "设置", "赋值", "复制", "variable", "integer", "set", "assign", "copy"]
	# 设置指令选择器图标
	metadata.builtin_icon = "int"
	return metadata

# 基础属性（始终显示）
@export var target_variable: String = "":
	set(value):
		if target_variable != value:
			target_variable = value
			_update_resource_name()

## 目标变量作用域（写入）
@export var target_variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		if target_variable_scope != value:
			target_variable_scope = value
			_update_resource_name()
			notify_property_list_changed()  # 触发检视器更新

## 目标作用域来源（仅当 target_variable_scope == SCOPE 时使用）
var target_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		if target_scope_source != value:
			target_scope_source = value
			_update_resource_name()
			notify_property_list_changed()

## 自定义目标作用域 ID（CUSTOM_ID 模式使用）
var target_custom_scope_id: String = "":
	set(value):
		if target_custom_scope_id != value:
			target_custom_scope_id = value
			_update_resource_name()

## 目标节点路径（TARGET_NODE 模式使用）
var target_target_node_path: NodePath = NodePath(""):
	set(value):
		if target_target_node_path != value:
			target_target_node_path = value
			_update_resource_name()

# 控制属性（带 setter）
@export var set_with_another_variable: bool = false:
	set(value):
		if set_with_another_variable != value:
			set_with_another_variable = value
			_update_resource_name()
			notify_property_list_changed()  # 触发检视器更新

# 条件属性（始终导出，但根据条件隐藏）
@export var from_variable: String = "":
	set(value):
		if from_variable != value:
			from_variable = value
			_update_resource_name()
			notify_property_list_changed()  # 触发检视器更新

@export var from_variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		if from_variable_scope != value:
			from_variable_scope = value
			_update_resource_name()
			notify_property_list_changed()  # 触发检视器更新

## 源作用域来源（仅当 from_variable_scope == SCOPE 时使用）
var from_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		if from_scope_source != value:
			from_scope_source = value
			_update_resource_name()
			notify_property_list_changed()

## 自定义源作用域 ID（CUSTOM_ID 模式使用）
var from_custom_scope_id: String = "":
	set(value):
		if from_custom_scope_id != value:
			from_custom_scope_id = value
			_update_resource_name()

## 源节点路径（TARGET_NODE 模式使用）
var from_target_node_path: NodePath = NodePath(""):
	set(value):
		if from_target_node_path != value:
			from_target_node_path = value
			_update_resource_name()
@export var new_value: int = 0:
	set(value):
		if new_value != value:
			new_value = value
			_update_resource_name()
			notify_property_list_changed()  # 触发检视器更新

# 实现条件化检视器显示（使用 _validate_property 方法）
func _validate_property(property: Dictionary) -> void:
	# 当 set_with_another_variable = false 时，禁用源变量属性
	if not set_with_another_variable:
		if property.name in ["from_variable", "from_variable_scope", "from_scope_source", "from_custom_scope_id", "from_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	# 当 set_with_another_variable = true 时，禁用新值属性
	if set_with_another_variable and property.name == "new_value":
		property.usage = PROPERTY_USAGE_NO_EDITOR

	# 目标作用域相关属性
	if target_variable_scope == BaseVariable.VariableScope.SCOPE:
		VariableScopeUtils.validate_scope_source_property(property, target_scope_source as VariableScopeUtils.ScopeSource)
	else:
		if property.name in ["target_scope_source", "target_custom_scope_id", "target_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	# 源作用域相关属性（仅在使用另一个变量时）
	if set_with_another_variable:
		if from_variable_scope == BaseVariable.VariableScope.SCOPE:
			VariableScopeUtils.validate_scope_source_property(property, from_scope_source as VariableScopeUtils.ScopeSource)
		else:
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
	var value_to_set: int
	if set_with_another_variable:
		if from_variable.is_empty():
			_log_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", {})
			set_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
			finished.emit()
			return

		# 根据源作用域类型读取变量
		var value = null
		match from_variable_scope:
			BaseVariable.VariableScope.LOCAL:
				value = VariableOperations.get_variable(context, from_variable, BaseVariable.VariableScope.LOCAL, null)

			BaseVariable.VariableScope.SCOPE:
				if from_scope_source == ScopeSource.NEAREST:
					value = VariableOperations.get_variable(context, from_variable, BaseVariable.VariableScope.SCOPE, null)
				else:
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

					value = scope_container.get_variable(from_variable, null)

			BaseVariable.VariableScope.GLOBAL:
				value = VariableOperations.get_variable(context, from_variable, BaseVariable.VariableScope.GLOBAL, null)

		# 检查变量是否存在
		if value == null and not VariableOperations.has_variable(context, from_variable, from_variable_scope):
			_log_error_localized("FUSE_ERROR_VAR_NOT_FOUND", {"variable": from_variable})
			set_error_localized("FUSE_ERROR_VAR_NOT_FOUND", FuseError.ErrorType.VALIDATION_ERROR, {"variable": from_variable})
			finished.emit()
			return

		# 确保是整数类型
		if typeof(value) != TYPE_INT:
			_log_warning("变量 %s 的类型不是整数，当前类型: %s" % [from_variable, typeof(value)])
			set_error_localized("FUSE_ERROR_VARIABLE_TYPE_MISMATCH", FuseError.ErrorType.VALIDATION_ERROR, {"expected": "int", "got": type_string(typeof(value))})
			finished.emit()
			return

		value_to_set = value
	else:
		value_to_set = new_value

	# 根据目标作用域类型保存变量
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
			if target_scope_source == ScopeSource.NEAREST:
				VariableOperations.set_variable(context, target_variable, BaseVariable.VariableScope.SCOPE, value_to_set)
			else:
				var utils_scope_source = target_scope_source as VariableScopeUtils.ScopeSource
				var scope_container = VariableScopeUtils.get_scope_container_by_source(
					context,
					utils_scope_source,
					target_custom_scope_id,
					target_target_node_path
				)

				if scope_container == null:
					_log_error_localized("FUSE_ERROR_SCOPE_CONTAINER_NOT_FOUND", {})
					set_error_localized("FUSE_ERROR_SCOPE_CONTAINER_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {})
					finished.emit()
					return

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
	_log_info_localized("FUSE_LOG_SETTING_INT_VARIABLE", {
		"operation": operation_type,
		"variable": target_variable,
		"value": str(value_to_set)
	})

	_on_execution_completed()

func _update_resource_name():
	var parts = []

	# 基础信息
	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_SET_INT_VARIABLE_RESOURCE"))

	# 目标作用域信息
	var target_scope_str = _get_target_scope_source_string()
	parts.append("[%s]" % target_scope_str)

	# 变量名称
	if not target_variable.is_empty():
		parts.append("'%s'" % target_variable)
	else:
		parts.append(FuseLocalization.translate("FUSE_VARIABLE_UNNAMED"))

	# 操作类型
	if set_with_another_variable:
		if from_variable.is_empty():
			parts.append(FuseLocalization.translate("FUSE_VARIABLE_COPY_FROM_UNspecified"))
		else:
			var from_scope_str = _get_from_scope_source_string()
			parts.append(FuseLocalization.translate_format("FUSE_VARIABLE_COPY_FROM_WITH_SCOPE", {"name": from_variable, "scope": from_scope_str}))
	else:
		parts.append("= %d" % new_value)

	# 组合最终名称
	resource_name = " ".join(parts)

## 获取目标作用域来源字符串
func _get_target_scope_source_string() -> String:
	match target_variable_scope:
		BaseVariable.VariableScope.LOCAL:
			return FuseLocalization.translate("FUSE_VARIABLE_SCOPE_LOCAL_STR")
		BaseVariable.VariableScope.GLOBAL:
			return FuseLocalization.translate("FUSE_VARIABLE_SCOPE_GLOBAL_STR")
		BaseVariable.VariableScope.SCOPE:
			return VariableScopeUtils.get_scope_source_string(
				target_scope_source as VariableScopeUtils.ScopeSource,
				target_custom_scope_id,
				target_target_node_path
			)
		_:
			return FuseLocalization.translate("FUSE_VARIABLE_SCOPE_UNKNOWN")

## 获取源作用域来源字符串
func _get_from_scope_source_string() -> String:
	match from_variable_scope:
		BaseVariable.VariableScope.LOCAL:
			return FuseLocalization.translate("FUSE_VARIABLE_SCOPE_LOCAL_STR")
		BaseVariable.VariableScope.GLOBAL:
			return FuseLocalization.translate("FUSE_VARIABLE_SCOPE_GLOBAL_STR")
		BaseVariable.VariableScope.SCOPE:
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

	# 验证目标 SCOPE 作用域需要 ScopeVariableManager
	if target_variable_scope == BaseVariable.VariableScope.SCOPE:
		var manager = ScopeVariableManager.get_instance()
		if manager == null:
			errors.append(FuseLocalization.translate("FUSE_ERROR_SCOPE_MANAGER_NOT_FOUND"))

		# 验证 ScopeSource 参数
		var target_utils_scope_source = target_scope_source as VariableScopeUtils.ScopeSource
		errors.append_array(VariableScopeUtils.validate_scope_source_params(
			target_utils_scope_source,
			target_custom_scope_id,
			target_target_node_path
		))

	# 验证源 SCOPE 作用域（仅在使用另一个变量时）
	if set_with_another_variable and from_variable_scope == BaseVariable.VariableScope.SCOPE:
		var manager = ScopeVariableManager.get_instance()
		if manager == null:
			errors.append(FuseLocalization.translate("FUSE_ERROR_SCOPE_MANAGER_NOT_FOUND"))

		# 验证 ScopeSource 参数
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

	var target_scope_str = _get_target_scope_source_string()
	return "%s → %s [%s]" % [operation_type, target_variable, target_scope_str]

func _cleanup_resources():
	super._cleanup_resources()
	_log_debug("SetIntVariableInstruction 资源清理完成")

func reset():
	super.reset()
	_log_debug("SetIntVariableInstruction 状态已重置")

## 统一日志方法
func _log_debug(message: String):
	FuseLogger.log_debug("SetIntVariableInstruction", log_level, message, target_variable)

func _log_info(message: String):
	FuseLogger.log_info("SetIntVariableInstruction", log_level, message, target_variable)

func _log_warning(message: String):
	FuseLogger.log_warning("SetIntVariableInstruction", log_level, message, target_variable)

func _log_error(message: String):
	FuseLogger.log_error("SetIntVariableInstruction", log_level, message, target_variable)
