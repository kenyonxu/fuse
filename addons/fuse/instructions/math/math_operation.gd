@tool
@icon("res://addons/fuse/icons/builtin/VisualShaderNodeTransformUniform.png")
extends BaseInstruction
class_name MathOperation

## 数学运算指令 - 执行基本四则运算
##
## 重构变量系统: 2026-02-09 - 使用 VariableOperations 统一变量访问

## 作用域来源
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

# 运算类型
enum OperationType {
	ADD,       # 加法
	SUBTRACT,  # 减法
	MULTIPLY,  # 乘法
	DIVIDE,    # 除法
	MODULO     # 取模
}

var operation_type: OperationType = OperationType.ADD:
	set(value_):
		operation_type = value_
		notify_property_list_changed()
		_update_resource_name()

# 操作数 A 来源
enum OperandASource {
	VALUE,
	VARIABLE
}
var operand_a_source: OperandASource = OperandASource.VALUE:
	set(value_):
		operand_a_source = value_
		notify_property_list_changed()
		_update_resource_name()

# 操作数 A 值
var operand_a_value: float = 0.0:
	set(value_):
		operand_a_value = value_
		_update_resource_name()

# 操作数 A 变量名
var operand_a_variable: String = "":
	set(value_):
		operand_a_variable = value_
		_update_resource_name()

# 操作数 A 变量作用域
var operand_a_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		operand_a_scope = value
		_update_resource_name()
		notify_property_list_changed()

## 操作数 A 作用域来源（仅当 operand_a_scope == SCOPE 时使用）
var operand_a_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		operand_a_scope_source = value
		_update_resource_name()
		notify_property_list_changed()

## 操作数 A 自定义作用域 ID（CUSTOM_ID 模式使用）
var operand_a_custom_scope_id: String = "":
	set(value):
		operand_a_custom_scope_id = value
		_update_resource_name()

## 操作数 A 目标节点路径（TARGET_NODE 模式使用）
var operand_a_target_node_path: NodePath = NodePath(""):
	set(value):
		operand_a_target_node_path = value
		_update_resource_name()

# 操作数 B 来源
enum OperandBSource {
	VALUE,
	VARIABLE
}
var operand_b_source: OperandBSource = OperandBSource.VALUE:
	set(value_):
		operand_b_source = value_
		notify_property_list_changed()
		_update_resource_name()

# 操作数 B 值
var operand_b_value: float = 0.0:
	set(value_):
		operand_b_value = value_
		_update_resource_name()

# 操作数 B 变量名
var operand_b_variable: String = "":
	set(value_):
		operand_b_variable = value_
		_update_resource_name()

# 操作数 B 变量作用域
var operand_b_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		operand_b_scope = value
		_update_resource_name()
		notify_property_list_changed()

## 操作数 B 作用域来源（仅当 operand_b_scope == SCOPE 时使用）
var operand_b_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		operand_b_scope_source = value
		_update_resource_name()
		notify_property_list_changed()

## 操作数 B 自定义作用域 ID（CUSTOM_ID 模式使用）
var operand_b_custom_scope_id: String = "":
	set(value):
		operand_b_custom_scope_id = value
		_update_resource_name()

## 操作数 B 目标节点路径（TARGET_NODE 模式使用）
var operand_b_target_node_path: NodePath = NodePath(""):
	set(value):
		operand_b_target_node_path = value
		_update_resource_name()

# 保存到变量
var save_to_variable: String = "math_result":
	set(value_):
		save_to_variable = value_
		_update_resource_name()

## 保存到作用域
var save_to_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		save_to_scope = value
		_update_resource_name()
		notify_property_list_changed()

## 作用域来源（仅当 save_to_scope == SCOPE 时使用）
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

## 获取指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_MATH_OPERATION_NAME"
	metadata.category_key = "FUSE_CATEGORY_MATH"
	metadata.description_key = "FUSE_INSTRUCTION_MATH_OPERATION_DESC"
	metadata.keywords = ["math", "arithmetic", "add", "subtract", "multiply", "divide", "modulo", "数学", "运算", "加减乘除"]
	metadata.builtin_icon = "VisualShaderNodeTransformUniform"
	return metadata

func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties := []

	properties.append({
		name = "Operation",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "operation_type",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Add,Subtract,Multiply,Divide,Modulo",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "Operand A",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "operand_a_source",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "VALUE,Variable",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if operand_a_source == OperandASource.VALUE:
		properties.append({
			name = "operand_a_value",
			type = TYPE_FLOAT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "-99999,99999,0.001,or_less,or_greater",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
	else:
		properties.append({
			name = "operand_a_variable",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		properties.append({
			name = "operand_a_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 只在 operand_a_scope == SCOPE 时显示 ScopeSource 配置
		if operand_a_scope == BaseVariable.VariableScope.SCOPE:
			properties.append({
				name = "operand_a_scope_source",
				type = TYPE_INT,
				hint = PROPERTY_HINT_ENUM,
				hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

			# 根据作用域来源添加额外属性
			if operand_a_scope_source == ScopeSource.CUSTOM_ID:
				properties.append({
					name = "operand_a_custom_scope_id",
					type = TYPE_STRING,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})
			elif operand_a_scope_source == ScopeSource.TARGET_NODE:
				properties.append({
					name = "operand_a_target_node_path",
					type = TYPE_NODE_PATH,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})

	properties.append({
		name = "Operand B",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "operand_b_source",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "VALUE,Variable",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if operand_b_source == OperandBSource.VALUE:
		properties.append({
			name = "operand_b_value",
			type = TYPE_FLOAT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "-99999,99999,0.001,or_less,or_greater",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
	else:
		properties.append({
			name = "operand_b_variable",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		properties.append({
			name = "operand_b_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 只在 operand_b_scope == SCOPE 时显示 ScopeSource 配置
		if operand_b_scope == BaseVariable.VariableScope.SCOPE:
			properties.append({
				name = "operand_b_scope_source",
				type = TYPE_INT,
				hint = PROPERTY_HINT_ENUM,
				hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

			# 根据作用域来源添加额外属性
			if operand_b_scope_source == ScopeSource.CUSTOM_ID:
				properties.append({
					name = "operand_b_custom_scope_id",
					type = TYPE_STRING,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})
			elif operand_b_scope_source == ScopeSource.TARGET_NODE:
				properties.append({
					name = "operand_b_target_node_path",
					type = TYPE_NODE_PATH,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})

	properties.append({
		name = "Output",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "save_to_variable",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "save_to_scope",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Local,Scope,Global",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 只在 save_to_scope == SCOPE 时显示 ScopeSource 配置
	if save_to_scope == BaseVariable.VariableScope.SCOPE:
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

## 更新资源名称
func _update_resource_name():
	var parts := []

	var op_key = ""
	match operation_type:
		OperationType.ADD:
			op_key = "FUSE_MATH_OP_ADD"
		OperationType.SUBTRACT:
			op_key = "FUSE_MATH_OP_SUBTRACT"
		OperationType.MULTIPLY:
			op_key = "FUSE_MATH_OP_MULTIPLY"
		OperationType.DIVIDE:
			op_key = "FUSE_MATH_OP_DIVIDE"
		OperationType.MODULO:
			op_key = "FUSE_MATH_OP_MODULO"
		_:
			op_key = "FUSE_MATH_OP_UNKNOWN"

	var op_symbol = FuseLocalization.translate(op_key)

	var a_str = ""
	var b_str = ""

	if operand_a_source == OperandASource.VALUE:
		a_str = _format_float_value(operand_a_value)
	else:
		var scope_str = VariableScopeUtils.enum_to_string(operand_a_scope).to_upper()
		var var_name = FuseLocalization.translate("FUSE_VALUE_VARIABLE_EMPTY") if operand_a_variable.is_empty() else operand_a_variable
		a_str = "%s [%s]" % [var_name, scope_str]

	if operand_b_source == OperandBSource.VALUE:
		b_str = _format_float_value(operand_b_value)
	else:
		var scope_str = VariableScopeUtils.enum_to_string(operand_b_scope).to_upper()
		var var_name = FuseLocalization.translate("FUSE_VALUE_VARIABLE_EMPTY") if operand_b_variable.is_empty() else operand_b_variable
		b_str = "%s [%s]" % [var_name, scope_str]

	parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_MATH_OPERATION_RESOURCE_NAME", {"a": a_str, "op": op_symbol, "b": b_str}))

	resource_name = " ".join(parts)

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	# 验证变量名
	if save_to_variable.is_empty():
		_log_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", {})
		set_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 获取操作数 A
	var operand_a := 0.0
	if operand_a_source == OperandASource.VALUE:
		operand_a = operand_a_value
	else:
		if operand_a_variable.is_empty():
			_log_error_localized("FUSE_ERROR_OPERAND_A_EMPTY", {})
			set_error_localized("FUSE_ERROR_OPERAND_A_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
			finished.emit()
			return

		# 根据作用域类型获取变量值
		if operand_a_scope == BaseVariable.VariableScope.SCOPE:
			# SCOPE 作用域：根据 scope_source 获取变量
			if operand_a_scope_source == ScopeSource.NEAREST:
				# NEAREST 模式：使用 VariableOperations 的默认行为
				operand_a = TypeConverter.safe_convert_to_float(VariableOperations.get_variable(context, operand_a_variable, BaseVariable.VariableScope.SCOPE, null))
			else:
				# 其他模式：获取指定作用域容器并读取变量
				var utils_scope_source = operand_a_scope_source as VariableScopeUtils.ScopeSource
				var scope_container = VariableScopeUtils.get_scope_container_by_source(
					context,
					utils_scope_source,
					operand_a_custom_scope_id,
					operand_a_target_node_path
				)

				if scope_container == null:
					_log_error_localized("FUSE_ERROR_OPERAND_A_SCOPE_CONTAINER_NOT_FOUND", {})
					set_error_localized("FUSE_ERROR_OPERAND_A_SCOPE_CONTAINER_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {})
					finished.emit()
					return

				operand_a = TypeConverter.safe_convert_to_float(scope_container.get_variable(operand_a_variable, 0.0))
		else:
			# LOCAL 或 GLOBAL 作用域：使用 VariableOperations
			operand_a = TypeConverter.safe_convert_to_float(VariableOperations.get_variable(context, operand_a_variable, operand_a_scope, null))

	# 获取操作数 B
	var operand_b := 0.0
	if operand_b_source == OperandBSource.VALUE:
		operand_b = operand_b_value
	else:
		if operand_b_variable.is_empty():
			_log_error_localized("FUSE_ERROR_OPERAND_B_EMPTY", {})
			set_error_localized("FUSE_ERROR_OPERAND_B_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
			finished.emit()
			return

		# 根据作用域类型获取变量值
		if operand_b_scope == BaseVariable.VariableScope.SCOPE:
			# SCOPE 作用域：根据 scope_source 获取变量
			if operand_b_scope_source == ScopeSource.NEAREST:
				# NEAREST 模式：使用 VariableOperations 的默认行为
				operand_b = TypeConverter.safe_convert_to_float(VariableOperations.get_variable(context, operand_b_variable, BaseVariable.VariableScope.SCOPE, null))
			else:
				# 其他模式：获取指定作用域容器并读取变量
				var utils_scope_source = operand_b_scope_source as VariableScopeUtils.ScopeSource
				var scope_container = VariableScopeUtils.get_scope_container_by_source(
					context,
					utils_scope_source,
					operand_b_custom_scope_id,
					operand_b_target_node_path
				)

				if scope_container == null:
					_log_error_localized("FUSE_ERROR_OPERAND_B_SCOPE_CONTAINER_NOT_FOUND", {})
					set_error_localized("FUSE_ERROR_OPERAND_B_SCOPE_CONTAINER_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {})
					finished.emit()
					return

				operand_b = TypeConverter.safe_convert_to_float(scope_container.get_variable(operand_b_variable, 0.0))
		else:
			# LOCAL 或 GLOBAL 作用域：使用 VariableOperations
			operand_b = TypeConverter.safe_convert_to_float(VariableOperations.get_variable(context, operand_b_variable, operand_b_scope, null))

	# 执行运算
	var result := 0.0

	match operation_type:
		OperationType.ADD:
			result = operand_a + operand_b
			_log_info_localized("FUSE_LOG_MATH_ADD", {"a": operand_a, "b": operand_b, "result": result})

		OperationType.SUBTRACT:
			result = operand_a - operand_b
			_log_info_localized("FUSE_LOG_MATH_SUBTRACT", {"a": operand_a, "b": operand_b, "result": result})

		OperationType.MULTIPLY:
			result = operand_a * operand_b
			_log_info_localized("FUSE_LOG_MATH_MULTIPLY", {"a": operand_a, "b": operand_b, "result": result})

		OperationType.DIVIDE:
			if is_zero_approx(operand_b):
				_log_error_localized("FUSE_ERROR_DIVISION_BY_ZERO", {})
				set_error_localized("FUSE_ERROR_DIVISION_BY_ZERO", FuseError.ErrorType.RUNTIME_ERROR, {})
				finished.emit()
				return
			result = operand_a / operand_b
			_log_info_localized("FUSE_LOG_MATH_DIVIDE", {"a": operand_a, "b": operand_b, "result": result})

		OperationType.MODULO:
			if is_zero_approx(operand_b):
				_log_error_localized("FUSE_ERROR_DIVISION_BY_ZERO", {})
				set_error_localized("FUSE_ERROR_DIVISION_BY_ZERO", FuseError.ErrorType.RUNTIME_ERROR, {})
				finished.emit()
				return
			result = fmod(operand_a, operand_b)
			_log_info_localized("FUSE_LOG_MATH_MODULO", {"a": operand_a, "b": operand_b, "result": result})

		_:
			_log_error_localized("FUSE_ERROR_OPERATION_TYPE_INVALID", {})
			set_error_localized("FUSE_ERROR_OPERATION_TYPE_INVALID", FuseError.ErrorType.RUNTIME_ERROR, {})
			finished.emit()
			return

	# 保存到变量 - 保持原始类型
	var final_result = _convert_result_to_original_type(context, result, save_to_variable, save_to_scope)

	match save_to_scope:
		BaseVariable.VariableScope.LOCAL:
			# 保存到 LOCAL 变量
			var success = VariableOperations.set_variable(context, save_to_variable, BaseVariable.VariableScope.LOCAL, final_result)
			if not success:
				_log_error_localized("FUSE_ERROR_SET_LOCAL_VARIABLE_FAILED", {"name": save_to_variable})
				set_error_localized("FUSE_ERROR_SET_LOCAL_VARIABLE_FAILED", FuseError.ErrorType.RUNTIME_ERROR, {"name": save_to_variable})
				finished.emit()
				return

		BaseVariable.VariableScope.SCOPE:
			# 保存到 SCOPE 变量
			if scope_source == ScopeSource.NEAREST:
				# NEAREST 模式：使用 VariableOperations 的默认行为
				VariableOperations.set_variable(context, save_to_variable, BaseVariable.VariableScope.SCOPE, final_result)
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
				var success = scope_container.set_variable(save_to_variable, final_result)
				if not success:
					_log_error_localized("FUSE_ERROR_SET_SCOPE_VARIABLE_FAILED", {"name": save_to_variable})
					set_error_localized("FUSE_ERROR_SET_SCOPE_VARIABLE_FAILED", FuseError.ErrorType.RUNTIME_ERROR, {"name": save_to_variable})
					finished.emit()
					return

		BaseVariable.VariableScope.GLOBAL:
			# 保存到 GLOBAL 变量
			var success = VariableOperations.set_variable(context, save_to_variable, BaseVariable.VariableScope.GLOBAL, final_result)
			if not success:
				_log_error_localized("FUSE_ERROR_SET_GLOBAL_VARIABLE_FAILED", {"name": save_to_variable})
				set_error_localized("FUSE_ERROR_SET_GLOBAL_VARIABLE_FAILED", FuseError.ErrorType.RUNTIME_ERROR, {"name": save_to_variable})
				finished.emit()
				return

	_on_execution_completed()

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()

	if save_to_variable.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_VAR_NAME_EMPTY"))

	if operand_a_source == OperandASource.VARIABLE and operand_a_variable.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_OPERAND_A_EMPTY"))

	if operand_b_source == OperandBSource.VARIABLE and operand_b_variable.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_OPERAND_B_EMPTY"))

	# 验证 SCOPE 作用域需要 ScopeVariableManager
	if operand_a_source == OperandASource.VARIABLE and operand_a_scope == BaseVariable.VariableScope.SCOPE:
		var manager = ScopeVariableManager.get_instance()
		if manager == null:
			errors.append(FuseLocalization.translate("FUSE_ERROR_SCOPE_MANAGER_NOT_FOUND"))

	if operand_b_source == OperandBSource.VARIABLE and operand_b_scope == BaseVariable.VariableScope.SCOPE:
		var manager = ScopeVariableManager.get_instance()
		if manager == null:
			errors.append(FuseLocalization.translate("FUSE_ERROR_SCOPE_MANAGER_NOT_FOUND"))

	# 验证操作数 A 的 ScopeSource 相关参数
	if operand_a_source == OperandASource.VARIABLE and operand_a_scope == BaseVariable.VariableScope.SCOPE:
		var utils_scope_source = operand_a_scope_source as VariableScopeUtils.ScopeSource
		errors.append_array(VariableScopeUtils.validate_scope_source_params(
			utils_scope_source,
			operand_a_custom_scope_id,
			operand_a_target_node_path
		))

	# 验证操作数 B 的 ScopeSource 相关参数
	if operand_b_source == OperandBSource.VARIABLE and operand_b_scope == BaseVariable.VariableScope.SCOPE:
		var utils_scope_source = operand_b_scope_source as VariableScopeUtils.ScopeSource
		errors.append_array(VariableScopeUtils.validate_scope_source_params(
			utils_scope_source,
			operand_b_custom_scope_id,
			operand_b_target_node_path
		))

	# 只在 SCOPE 作用域时验证 ScopeSource 相关参数
	if save_to_scope == BaseVariable.VariableScope.SCOPE:
		var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
		errors.append_array(VariableScopeUtils.validate_scope_source_params(
			utils_scope_source,
			custom_scope_id,
			target_node_path
		))

	return errors

## 验证属性可见性
func _validate_property(property: Dictionary) -> void:
	# 处理 save_to_scope 的 ScopeSource 相关属性
	if save_to_scope == BaseVariable.VariableScope.SCOPE:
		VariableScopeUtils.validate_scope_source_property(property, scope_source as VariableScopeUtils.ScopeSource)
	else:
		# 非 SCOPE 作用域时隐藏 ScopeSource 相关属性
		if property.name in ["scope_source", "custom_scope_id", "target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	# 处理 operand_a_scope 的 ScopeSource 相关属性
	var operand_a_show_scope_source = operand_a_source == OperandASource.VARIABLE and operand_a_scope == BaseVariable.VariableScope.SCOPE
	if not operand_a_show_scope_source:
		if property.name in ["operand_a_scope_source", "operand_a_custom_scope_id", "operand_a_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	elif operand_a_scope_source != ScopeSource.CUSTOM_ID:
		if property.name == "operand_a_custom_scope_id":
			property.usage = PROPERTY_USAGE_NO_EDITOR
	elif operand_a_scope_source != ScopeSource.TARGET_NODE:
		if property.name == "operand_a_target_node_path":
			property.usage = PROPERTY_USAGE_NO_EDITOR

	# 处理 operand_b_scope 的 ScopeSource 相关属性
	var operand_b_show_scope_source = operand_b_source == OperandBSource.VARIABLE and operand_b_scope == BaseVariable.VariableScope.SCOPE
	if not operand_b_show_scope_source:
		if property.name in ["operand_b_scope_source", "operand_b_custom_scope_id", "operand_b_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	elif operand_b_scope_source != ScopeSource.CUSTOM_ID:
		if property.name == "operand_b_custom_scope_id":
			property.usage = PROPERTY_USAGE_NO_EDITOR
	elif operand_b_scope_source != ScopeSource.TARGET_NODE:
		if property.name == "operand_b_target_node_path":
			property.usage = PROPERTY_USAGE_NO_EDITOR

## 获取指令描述
func get_description() -> String:
	var op_key = ""
	match operation_type:
		OperationType.ADD:
			op_key = "FUSE_MATH_OP_ADD_NAME"
		OperationType.SUBTRACT:
			op_key = "FUSE_MATH_OP_SUBTRACT_NAME"
		OperationType.MULTIPLY:
			op_key = "FUSE_MATH_OP_MULTIPLY_NAME"
		OperationType.DIVIDE:
			op_key = "FUSE_MATH_OP_DIVIDE_NAME"
		OperationType.MODULO:
			op_key = "FUSE_MATH_OP_MODULO_NAME"
		_:
			op_key = "FUSE_MATH_OP_UNKNOWN_NAME"

	var op_name = FuseLocalization.translate(op_key)
	var scope_str = _get_scope_source_string()
	return "%s → %s [%s]" % [op_name, save_to_variable, scope_str]

## 获取作用域来源字符串
func _get_scope_source_string() -> String:
	# 根据 save_to_scope 返回不同的作用域字符串
	match save_to_scope:
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

## 将结果转换为目标变量的原始类型
## 保持变量类型一致性，避免整数被意外转换为浮点数
func _convert_result_to_original_type(
	context: ExecutionContext,
	result: float,
	variable_name: String,
	scope: BaseVariable.VariableScope
) -> Variant:
	# 获取变量原始值以检测类型
	var original_value: Variant = null

	match scope:
		BaseVariable.VariableScope.LOCAL:
			if context.has_variable(variable_name):
				original_value = context.get_variable(variable_name, null)
		BaseVariable.VariableScope.SCOPE:
			# 根据作用域来源获取原始值
			if scope_source == ScopeSource.NEAREST:
				original_value = VariableOperations.get_variable(context, variable_name, BaseVariable.VariableScope.SCOPE, null)
			else:
				var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
				var scope_container = VariableScopeUtils.get_scope_container_by_source(
					context,
					utils_scope_source,
					custom_scope_id,
					target_node_path
				)
				if scope_container != null and scope_container.has_variable(variable_name):
					original_value = scope_container.get_variable(variable_name, null)
		BaseVariable.VariableScope.GLOBAL:
			original_value = VariableOperations.get_variable(context, variable_name, BaseVariable.VariableScope.GLOBAL, null)

	# 如果变量已存在，转换为原始类型；否则保持 float 类型
	if original_value != null:
		var original_type = typeof(original_value)
		# 只对数值类型进行转换（INT, FLOAT, BOOL）
		if original_type == TYPE_INT:
			return int(result)
		elif original_type == TYPE_BOOL:
			return result != 0.0
		elif original_type == TYPE_FLOAT:
			return result
		else:
			# 其他类型保持 float
			return result

	# 新变量，保持 float 类型
	return result

## 格式化浮点数，去除尾部多余零
func _format_float_value(value: float) -> String:
	var s := "%.4f" % value
	if s.contains("."):
		s = s.rstrip("0")
		if s.ends_with("."):
			s += "0"
	return s
