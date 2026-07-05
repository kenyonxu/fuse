@tool
@icon("res://addons/fuse/icons/builtin/Dictionary.svg")
extends BaseInstruction
class_name DictMathOp

## DictMathOp 指令
##
## 对字典中数值类型键进行数学运算。
## 支持乘法、除法、取模运算。
## 如果键不存在或值不是数值类型则报错。
## 除数为0时报错。
##
## 使用 VariableOperations 统一变量访问 API

## 操作类型枚举
enum OperationType {
	MULTIPLY,  ## 乘法 (*=)
	DIVIDE,    ## 除法 (/=)
	MODULO     ## 取模 (%=)
}

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

## 操作类型
var operation: OperationType = OperationType.MULTIPLY:
	set(value):
		if operation != value:
			operation = value
			_update_resource_name()

## 操作数是否来自变量
var use_operand_from_variable: bool = false:
	set(value):
		if use_operand_from_variable != value:
			use_operand_from_variable = value
			_update_resource_name()
			notify_property_list_changed()

## 操作数源变量名（当 use_operand_from_variable = true 时使用）
var operand_from_variable: String = ""

## 操作数源变量作用域
var operand_from_variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		if operand_from_variable_scope != value:
			operand_from_variable_scope = value
			_update_resource_name()
			notify_property_list_changed()

## 操作数源作用域来源（仅当 operand_from_variable_scope == SCOPE 时使用）
var operand_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		if operand_scope_source != value:
			operand_scope_source = value
			_update_resource_name()
			notify_property_list_changed()

## 操作数源自定义作用域 ID
var operand_custom_scope_id: String = "":
	set(value):
		if operand_custom_scope_id != value:
			operand_custom_scope_id = value
			_update_resource_name()

## 操作数源目标节点路径
var operand_target_node_path: NodePath = NodePath(""):
	set(value):
		if operand_target_node_path != value:
			operand_target_node_path = value
			_update_resource_name()

## 操作数值（直接输入，当 use_operand_from_variable = false 时使用）
@export var operand: float = 1.0:
	set(value):
		operand = value
		_update_resource_name()

## 获取指令元数据（用于指令选择器）
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_DICT_MATH_OP_NAME"
	metadata.category_key = "FUSE_CATEGORY_DICTIONARIES"
	metadata.description_key = "FUSE_INSTRUCTION_DICT_MATH_OP_DESC"
	metadata.keywords = ["字典", "数学", "运算", "乘法", "除法", "取模", "dictionary", "math", "multiply", "divide", "modulo"]
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
	else:
		properties.append({
			name = "key_value",
			type = TYPE_NIL,
			hint = PROPERTY_HINT_NONE,
			hint_string = "",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

	# Operation 分类
	properties.append({
		name = "Operation",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "operation",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Multiply (*),Divide (/),Modulo (%)",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Operand 分类
	properties.append({
		name = "Operand",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "use_operand_from_variable",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 操作数或操作数源变量
	if use_operand_from_variable:
		properties.append({
			name = "operand_from_variable",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		properties.append({
			name = "operand_from_variable_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 只在 operand_from_variable_scope == SCOPE 时显示 ScopeSource 配置
		if operand_from_variable_scope == BaseVariable.VariableScope.SCOPE:
			properties.append({
				name = "Operand Scope Configuration",
				type = TYPE_NIL,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_CATEGORY
			})

			properties.append({
				name = "operand_scope_source",
				type = TYPE_INT,
				hint = PROPERTY_HINT_ENUM,
				hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

			# 根据作用域来源添加额外属性
			if operand_scope_source == ScopeSource.CUSTOM_ID:
				properties.append({
					name = "operand_custom_scope_id",
					type = TYPE_STRING,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})
			elif operand_scope_source == ScopeSource.TARGET_NODE:
				properties.append({
					name = "operand_target_node_path",
					type = TYPE_NODE_PATH,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})
	else:
		properties.append({
			name = "operand",
			type = TYPE_FLOAT,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

	return properties

## 更新资源名称
func _update_resource_name():
	var dict_str := ""
	var key_str := ""
	var op_str := ""
	var operand_str := ""

	# 字典信息
	if dict_variable.is_empty():
		dict_str = FuseLocalization.translate("FUSE_INSTRUCTION_DICT_NO_DICT")
	else:
		dict_str = FuseLocalization.translate_format("FUSE_INSTRUCTION_DICT_DICT", {"name": dict_variable})

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

	# 操作符
	match operation:
		OperationType.MULTIPLY:
			op_str = "*="
		OperationType.DIVIDE:
			op_str = "/="
		OperationType.MODULO:
			op_str = "%="

	# 操作数信息
	if use_operand_from_variable:
		if operand_from_variable.is_empty():
			operand_str = "(no operand var)"
		else:
			operand_str = "$%s" % operand_from_variable
	else:
		operand_str = str(operand)

	resource_name = " ".join(["Dict Math", dict_str, "[%s]" % key_str, op_str, operand_str])

## 动态属性设置（支持属性刷新）
func _set(property: StringName, value: Variant) -> bool:
	if property == "dict_variable" or property == "key_value" or property == "operation" or property == "operand":
		_update_resource_name()
		return false

	if property == "key_from_variable" or property == "operand_from_variable":
		_update_resource_name()
		return false

	return false

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	_log_debug_localized("FUSE_LOG_INSTRUCTION_START", {"instruction": "DictMathOp"})

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

	# 获取操作数
	var operand_value_num: float
	if use_operand_from_variable:
		# 从变量获取操作数
		if operand_from_variable.is_empty():
			_log_error_localized("FUSE_ERROR_DICT_MATH_OP_OPERAND_EMPTY", {})
			set_error_localized("FUSE_ERROR_DICT_MATH_OP_OPERAND_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
			finished.emit()
			return

		var operand_variant = _get_variable_value(context, operand_from_variable, operand_from_variable_scope, operand_scope_source, operand_custom_scope_id, operand_target_node_path)
		if operand_variant == null:
			_log_error_localized("FUSE_ERROR_DICT_MATH_OP_OPERAND_EMPTY", {})
			set_error_localized("FUSE_ERROR_DICT_MATH_OP_OPERAND_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
			finished.emit()
			return

		# 验证操作数是否为数值类型
		if not _is_numeric_type(operand_variant):
			_log_error_localized("FUSE_ERROR_DICT_MATH_OP_OPERAND_NOT_NUMBER", {"type": _get_type_name(typeof(operand_variant))})
			set_error_localized("FUSE_ERROR_DICT_MATH_OP_OPERAND_NOT_NUMBER", FuseError.ErrorType.VALIDATION_ERROR, {"type": _get_type_name(typeof(operand_variant))})
			finished.emit()
			return

		operand_value_num = _to_float(operand_variant)
	else:
		# 使用直接值
		operand_value_num = operand

	# 检查除数是否为0（对于除法和取模）
	if (operation == OperationType.DIVIDE or operation == OperationType.MODULO) and is_zero_approx(operand_value_num):
		_log_error_localized("FUSE_ERROR_DICT_DIVISION_BY_ZERO", {})
		set_error_localized("FUSE_ERROR_DICT_DIVISION_BY_ZERO", FuseError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	# 获取字典
	var target_dict: Dictionary = _get_dict_variable(context)
	if target_dict.is_empty() and not _has_dict_variable(context):
		# 字典不存在
		_log_error_localized("FUSE_ERROR_DICT_NOT_FOUND", {"name": dict_variable})
		set_error_localized("FUSE_ERROR_DICT_NOT_FOUND", FuseError.ErrorType.VALIDATION_ERROR, {"name": dict_variable})
		finished.emit()
		return

	# 检查键是否存在
	if not target_dict.has(key):
		_log_error_localized("FUSE_ERROR_DICT_KEY_NOT_FOUND", {"key": str(key)})
		set_error_localized("FUSE_ERROR_DICT_KEY_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"key": str(key)})
		finished.emit()
		return

	# 获取当前值
	var current_value = target_dict[key]

	# 验证当前值是否为数值类型
	if not _is_numeric_type(current_value):
		_log_error_localized("FUSE_ERROR_DICT_VALUE_NOT_NUMBER", {"key": str(key), "type": _get_type_name(typeof(current_value))})
		set_error_localized("FUSE_ERROR_DICT_VALUE_NOT_NUMBER", FuseError.ErrorType.RUNTIME_ERROR, {"key": str(key), "type": _get_type_name(typeof(current_value))})
		finished.emit()
		return

	# 执行数学运算
	var new_value: float
	var old_value: float = _to_float(current_value)

	match operation:
		OperationType.MULTIPLY:
			new_value = old_value * operand_value_num
		OperationType.DIVIDE:
			new_value = old_value / operand_value_num
		OperationType.MODULO:
			new_value = fmod(old_value, operand_value_num)

	# 保持原有类型（int 或 float）
	if typeof(current_value) == TYPE_INT:
		target_dict[key] = int(new_value)
	else:
		target_dict[key] = new_value

	# 调试输出
	_log_debug("════════════════════════════════════════════════════")
	_log_debug("📤 DictMathOp 执行:")
	_log_debug("  • 目标字典: '%s'" % dict_variable)
	_log_debug("  • 作用域: %s" % _get_scope_name_for_log())
	_log_debug("  • 键: %s (类型: %s)" % [str(key), typeof(key)])
	_log_debug("  • 操作: %s" % _get_operation_symbol())
	_log_debug("  • 操作数: %s" % str(operand_value_num))
	_log_debug("  • 原值: %s -> 新值: %s" % [str(old_value), str(target_dict[key])])
	_log_debug("════════════════════════════════════════════════════")

	_log_info_localized("FUSE_LOG_DICT_MATH_OP", {
		"dict": dict_variable,
		"key": str(key),
		"op": _get_operation_symbol(),
		"operand": str(operand_value_num),
		"old": str(old_value),
		"new": str(target_dict[key])
	})

	# 触发变量变化通知
	if dict_scope == BaseVariable.VariableScope.GLOBAL:
		_notify_global_variable_changed(dict_variable)
	elif dict_scope == BaseVariable.VariableScope.SCOPE:
		_notify_scope_variable_changed(context)

	_on_execution_completed()

## 检查是否为数值类型
func _is_numeric_type(value: Variant) -> bool:
	var type := typeof(value)
	return type == TYPE_INT or type == TYPE_FLOAT

## 将值转换为 float
func _to_float(value: Variant) -> float:
	if typeof(value) == TYPE_INT:
		return float(value)
	return value as float

## 获取类型名称
func _get_type_name(type: int) -> String:
	match type:
		TYPE_NIL: return "null"
		TYPE_BOOL: return "bool"
		TYPE_INT: return "int"
		TYPE_FLOAT: return "float"
		TYPE_STRING: return "String"
		TYPE_ARRAY: return "Array"
		TYPE_DICTIONARY: return "Dictionary"
		_: return "type_%d" % type

## 获取操作符符号
func _get_operation_symbol() -> String:
	match operation:
		OperationType.MULTIPLY:
			return "*="
		OperationType.DIVIDE:
			return "/="
		OperationType.MODULO:
			return "%="
		_:
			return "?"

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

## 检查字典变量是否存在
func _has_dict_variable(context: ExecutionContext) -> bool:
	match dict_scope:
		BaseVariable.VariableScope.LOCAL:
			return VariableOperations.has_variable(context, dict_variable, BaseVariable.VariableScope.LOCAL)
		BaseVariable.VariableScope.SCOPE:
			if dict_scope_source == ScopeSource.NEAREST:
				return VariableOperations.has_variable(context, dict_variable, BaseVariable.VariableScope.SCOPE)
			else:
				var utils_scope_source = dict_scope_source as VariableScopeUtils.ScopeSource
				var scope_container = VariableScopeUtils.get_scope_container_by_source(
					context,
					utils_scope_source,
					dict_custom_scope_id,
					dict_target_node_path
				)
				if scope_container == null:
					return false
				return scope_container.has_variable(dict_variable)
		BaseVariable.VariableScope.GLOBAL:
			return VariableOperations.has_variable(context, dict_variable, BaseVariable.VariableScope.GLOBAL)

	return false

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
				if scope_container:
					dict_value = scope_container.get_variable(dict_variable, null)

		BaseVariable.VariableScope.GLOBAL:
			dict_value = VariableOperations.get_variable(context, dict_variable, BaseVariable.VariableScope.GLOBAL, null)

	if dict_value is Dictionary:
		return dict_value

	return {}

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

	# 验证操作数源
	if use_operand_from_variable:
		if operand_from_variable.is_empty():
			errors.append(FuseLocalization.translate("FUSE_ERROR_DICT_MATH_OP_OPERAND_EMPTY"))

		# 验证操作数 SCOPE 作用域
		if operand_from_variable_scope == BaseVariable.VariableScope.SCOPE:
			var manager = ScopeVariableManager.get_instance()
			if manager == null:
				errors.append(FuseLocalization.translate("FUSE_ERROR_SCOPE_MANAGER_NOT_FOUND"))

			# 验证 ScopeSource 参数
			var operand_utils_scope_source = operand_scope_source as VariableScopeUtils.ScopeSource
			errors.append_array(VariableScopeUtils.validate_scope_source_params(
				operand_utils_scope_source,
				operand_custom_scope_id,
				operand_target_node_path
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

	# 操作数变量相关属性
	if use_operand_from_variable:
		if property.name == "operand":
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		if property.name in ["operand_from_variable", "operand_from_variable_scope", "operand_scope_source", "operand_custom_scope_id", "operand_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	# 操作数作用域相关属性
	if use_operand_from_variable:
		if operand_from_variable_scope == BaseVariable.VariableScope.SCOPE:
			if property.name == "operand_scope_source":
				return  # 始终显示
			elif property.name == "operand_custom_scope_id":
				if operand_scope_source != ScopeSource.CUSTOM_ID:
					property.usage = PROPERTY_USAGE_NO_EDITOR
			elif property.name == "operand_target_node_path":
				if operand_scope_source != ScopeSource.TARGET_NODE:
					property.usage = PROPERTY_USAGE_NO_EDITOR
		else:
			if property.name in ["operand_scope_source", "operand_custom_scope_id", "operand_target_node_path"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR

## 获取指令描述
func get_description() -> String:
	var dict_str := ""
	var key_str := ""
	var op_str := ""
	var operand_str := ""

	if dict_variable.is_empty():
		dict_str = FuseLocalization.translate("FUSE_INSTRUCTION_DICT_NO_DICT")
	else:
		dict_str = FuseLocalization.translate_format("FUSE_INSTRUCTION_DICT_DICT", {"name": dict_variable})

	if use_key_from_variable:
		key_str = "$%s" % key_from_variable if not key_from_variable.is_empty() else "(no var)"
	else:
		key_str = str(key_value)

	match operation:
		OperationType.MULTIPLY:
			op_str = "*="
		OperationType.DIVIDE:
			op_str = "/="
		OperationType.MODULO:
			op_str = "%="

	if use_operand_from_variable:
		operand_str = "$%s" % operand_from_variable if not operand_from_variable.is_empty() else "(no var)"
	else:
		operand_str = str(operand)

	return "Dict Math: %s[%s] %s %s" % [dict_str, key_str, op_str, operand_str]

## 重置指令状态
func reset():
	super.reset()
	_log_debug_localized("FUSE_LOG_DICT_MATH_OP_RESET", {})

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
