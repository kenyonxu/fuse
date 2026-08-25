@tool
@icon("res://addons/fuse/icons/builtin/Vector3.png")
extends BaseInstruction
class_name VectorOperation

## 向量运算指令 - 执行向量运算（加减、缩放、归一化、长度、距离）
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
	VECTOR_ADD,       # 向量加法
	VECTOR_SUBTRACT,  # 向量减法
	SCALE,            # 向量缩放 (向量 * 标量)
	NORMALIZE,        # 归一化
	LENGTH,           # 向量长度
	DISTANCE          # 两点距离
}

var operation_type: OperationType = OperationType.VECTOR_ADD:
	set(value):
		operation_type = value
		notify_property_list_changed()
		_update_resource_name()

# 向量类型
enum VectorType {
	VECTOR2,
	VECTOR3
}

var vector_type: VectorType = VectorType.VECTOR2:
	set(value):
		vector_type = value
		notify_property_list_changed()
		_update_resource_name()

# ========== Vector A 属性（必须使用变量）==========
# 向量 A 变量名
var vector_a_variable: String = "":
	set(value):
		vector_a_variable = value
		_update_resource_name()

# 向量 A 变量作用域
var vector_a_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		vector_a_scope = value
		_update_resource_name()
		notify_property_list_changed()

# 向量 A 作用域来源（仅当 scope == SCOPE 时使用）
var vector_a_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		vector_a_scope_source = value
		_update_resource_name()
		notify_property_list_changed()

# 向量 A 自定义作用域 ID
var vector_a_scope_id: String = "":
	set(value):
		vector_a_scope_id = value
		_update_resource_name()

# ========== Vector B 属性 ==========
# 向量 B 值（直接输入）
var vector_b_value: Variant = null:
	set(value):
		vector_b_value = value
		_update_resource_name()

# 向量 B 使用变量
var vector_b_use_variable: bool = false:
	set(value):
		vector_b_use_variable = value
		notify_property_list_changed()
		_update_resource_name()

# 向量 B 变量名
var vector_b_variable: String = "":
	set(value):
		vector_b_variable = value
		_update_resource_name()

# 向量 B 变量作用域
var vector_b_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		vector_b_scope = value
		_update_resource_name()
		notify_property_list_changed()

# 向量 B 作用域来源（仅当 scope == SCOPE 时使用）
var vector_b_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		vector_b_scope_source = value
		_update_resource_name()
		notify_property_list_changed()

# 向量 B 自定义作用域 ID
var vector_b_scope_id: String = "":
	set(value):
		vector_b_scope_id = value
		_update_resource_name()

# ========== Scalar 属性 ==========
# 标量值（直接输入）
var scalar_value: float = 1.0:
	set(value):
		scalar_value = value
		_update_resource_name()

# 标量使用变量
var scalar_use_variable: bool = false:
	set(value):
		scalar_use_variable = value
		notify_property_list_changed()
		_update_resource_name()

# 标量变量名
var scalar_variable: String = "":
	set(value):
		scalar_variable = value
		_update_resource_name()

# 标量变量作用域
var scalar_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		scalar_scope = value
		notify_property_list_changed()
		_update_resource_name()

# 标量作用域来源（仅当 scope == SCOPE 时使用）
var scalar_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		scalar_scope_source = value
		_update_resource_name()
		notify_property_list_changed()

# 标量自定义作用域 ID
var scalar_scope_id: String = "":
	set(value):
		scalar_scope_id = value
		_update_resource_name()

# ========== Output 属性 ==========
# 保存到变量
var save_to_variable: String = "vector_result":
	set(value):
		save_to_variable = value
		_update_resource_name()

# 保存到作用域
var save_to_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		save_to_scope = value
		_update_resource_name()
		notify_property_list_changed()

# 作用域来源（仅当 save_to_scope == SCOPE 时使用）
var scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		scope_source = value
		_update_resource_name()
		notify_property_list_changed()

# 自定义作用域 ID
var scope_id: String = "":
	set(value):
		scope_id = value
		_update_resource_name()

## 获取指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_VECTOR_OPERATION_NAME"
	metadata.category_key = "FUSE_CATEGORY_MATH"
	metadata.description_key = "FUSE_INSTRUCTION_VECTOR_OPERATION_DESC"
	metadata.keywords = ["vector", "math", "add", "subtract", "normalize", "length", "distance", "scale", "向量", "运算", "归一化", "长度", "距离", "缩放"]
	metadata.builtin_icon = "Vector3"
	return metadata

func _setup_metadata():
	pass

## 声明变量读写模式（save_to=write, vector_a/b/scalar=read）
func get_variable_modes() -> Array[Dictionary]:
	return [
		{"name": "save_to_variable", "mode": "write"},
		{"name": "vector_a_variable", "mode": "read"},
		{"name": "vector_b_variable", "mode": "read"},
		{"name": "scalar_variable", "mode": "read"},
	]

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	# ========== Operation Configuration ==========
	properties.append({
		name = "Operation Configuration",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "operation_type",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Vector Add,Vector Subtract,Scale,Normalize,Length,Distance",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "vector_type",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Vector2,Vector3",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# ========== Vector A Input ==========
	properties.append({
		name = "Vector A Input",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "vector_a_variable",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "vector_a_scope",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Local,Scope,Global",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if vector_a_scope == BaseVariable.VariableScope.SCOPE:
		properties.append({
			name = "vector_a_scope_source",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

	if vector_a_scope_source == ScopeSource.CUSTOM_ID:
		properties.append({
			name = "vector_a_scope_id",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

	# ========== Vector B Input ==========
	properties.append({
		name = "Vector B Input",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "vector_b_use_variable",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if !vector_b_use_variable:
		if vector_type == VectorType.VECTOR2:
			properties.append({
				name = "vector_b_value",
				type = TYPE_VECTOR2,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})
		else:
			properties.append({
				name = "vector_b_value",
				type = TYPE_VECTOR3,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

	else:
		properties.append({
			name = "vector_b_variable",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		properties.append({
			name = "vector_b_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		if vector_b_scope == BaseVariable.VariableScope.SCOPE:
			properties.append({
				name = "vector_b_scope_source",
				type = TYPE_INT,
				hint = PROPERTY_HINT_ENUM,
				hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

			if vector_b_scope_source == ScopeSource.CUSTOM_ID:
				properties.append({
					name = "vector_b_scope_id",
					type = TYPE_STRING,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})

	# ========== Scalar Input ==========
	properties.append({
		name = "Scalar Input",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "scalar_use_variable",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if !scalar_use_variable:
		properties.append({
			name = "scalar_value",
			type = TYPE_FLOAT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "-99999,99999,0.1,or_less,or_greater",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
	else:
		properties.append({
			name = "scalar_variable",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		properties.append({
			name = "scalar_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		properties.append({
			name = "scalar_scope_source",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		properties.append({
			name = "scalar_scope_id",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

	# ========== Output ==========
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

	properties.append({
		name = "scope_source",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "scope_id",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 判断是否需要向量 B
func _needs_vector_b() -> bool:
	return operation_type in [OperationType.VECTOR_ADD, OperationType.VECTOR_SUBTRACT, OperationType.DISTANCE]

## 判断是否需要标量
func _needs_scalar() -> bool:
	return operation_type == OperationType.SCALE

## 获取变量（支持 SCOPE 的 scope_source 参数）
## 统一处理 LOCAL/SCOPE/GLOBAL 三种作用域，SCOPE 时支持 scope_source 指定容器
## 返回字典：{ value: Variant, success: bool, error_key: String, error_params: Dictionary }
func _get_variable_with_scope_source(
	context: ExecutionContext,
	variable_name: String,
	scope: BaseVariable.VariableScope,
	scope_source: ScopeSource,
	scope_id: String
) -> Dictionary:
	if scope == BaseVariable.VariableScope.SCOPE:
		# SCOPE 作用域需要根据 scope_source 选择容器
		var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
		var scope_container = VariableScopeUtils.get_scope_container_by_source(
			context, utils_scope_source, scope_id, ""
		)
		if scope_container == null:
			return { value = null, success = false, error_key = "FUSE_ERROR_SCOPE_CONTAINER_NOT_FOUND", error_params = {} }

		var value = scope_container.get_variable(variable_name, null)
		if value == null and not scope_container.has_variable(variable_name):
			return { value = null, success = false, error_key = "FUSE_ERROR_VAR_NOT_FOUND", error_params = {"variable": variable_name} }

		return { value = value, success = true, error_key = "", error_params = {} }
	else:
		# LOCAL 或 GLOBAL 作用域，使用标准方法
		var value = VariableOperations.get_variable(context, variable_name, scope, null)
		if value == null:
			return { value = null, success = false, error_key = "FUSE_ERROR_VAR_NOT_FOUND", error_params = {"variable": variable_name} }
		return { value = value, success = true, error_key = "", error_params = {} }

## 更新资源名称
func _update_resource_name():
	var parts := []

	var op_key = ""
	match operation_type:
		OperationType.VECTOR_ADD:
			op_key = "FUSE_VECTOR_OP_ADD"
		OperationType.VECTOR_SUBTRACT:
			op_key = "FUSE_VECTOR_OP_SUBTRACT"
		OperationType.SCALE:
			op_key = "FUSE_VECTOR_OP_SCALE"
		OperationType.NORMALIZE:
			op_key = "FUSE_VECTOR_OP_NORMALIZE"
		OperationType.LENGTH:
			op_key = "FUSE_VECTOR_OP_LENGTH"
		OperationType.DISTANCE:
			op_key = "FUSE_VECTOR_OP_DISTANCE"
		_:
			op_key = "FUSE_VECTOR_OP_UNKNOWN"

	var op_name = FuseLocalization.translate(op_key)
	var type_str = "Vector2" if vector_type == VectorType.VECTOR2 else "Vector3"

	var scope_str = _get_scope_source_string()

	parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_VECTOR_OPERATION_RESOURCE_NAME", {"op": op_name, "type": type_str}))
	parts.append("→ %s [%s]" % [save_to_variable, scope_str])

	resource_name = " ".join(parts)

## 获取作用域来源字符串
func _get_scope_source_string() -> String:
	match save_to_scope:
		BaseVariable.VariableScope.LOCAL:
			return FuseLocalization.translate("FUSE_VARIABLE_SCOPE_LOCAL_STR")
		BaseVariable.VariableScope.GLOBAL:
			return FuseLocalization.translate("FUSE_VARIABLE_SCOPE_GLOBAL_STR")
		BaseVariable.VariableScope.SCOPE:
			return VariableScopeUtils.get_scope_source_string(
				scope_source as VariableScopeUtils.ScopeSource,
				scope_id,
				""  # Output scope 不使用 target_node_path
			)
		_:
			return FuseLocalization.translate("FUSE_VARIABLE_SCOPE_UNKNOWN")

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	# 验证变量名
	if save_to_variable.is_empty():
		_log_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", {})
		set_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 获取向量 A
	var result_a = _get_variable_with_scope_source(
		context, vector_a_variable, vector_a_scope, vector_a_scope_source, vector_a_scope_id
	)
	if not result_a.success:
		_log_error_localized(result_a.error_key, result_a.error_params)
		set_error_localized(result_a.error_key, FuseError.ErrorType.RUNTIME_ERROR, result_a.error_params)
		finished.emit()
		return
	var vector_a: Variant = result_a.value

	# 验证向量 A 类型
	var is_valid_a = false
	if vector_type == VectorType.VECTOR2:
		is_valid_a = vector_a is Vector2
	else:
		is_valid_a = vector_a is Vector3

	if not is_valid_a:
		var type_str = type_string(typeof(vector_a))
		_log_error_localized("FUSE_ERROR_VECTOR_TYPE_INVALID", {"actual_type": type_str})
		set_error_localized("FUSE_ERROR_VECTOR_TYPE_INVALID", FuseError.ErrorType.RUNTIME_ERROR, {"actual_type": type_str})
		finished.emit()
		return

	# 获取向量 B（如果需要）
	var vector_b = null
	if _needs_vector_b():
		if vector_b_use_variable:
			var result_b = _get_variable_with_scope_source(
				context, vector_b_variable, vector_b_scope, vector_b_scope_source, vector_b_scope_id
			)
			if not result_b.success:
				_log_error_localized(result_b.error_key, result_b.error_params)
				set_error_localized(result_b.error_key, FuseError.ErrorType.RUNTIME_ERROR, result_b.error_params)
				finished.emit()
				return
			vector_b = result_b.value
		else:
			vector_b = vector_b_value

		# 验证向量 B 类型
		if vector_b != null:
			var is_valid_b = false
			if vector_type == VectorType.VECTOR2:
				is_valid_b = vector_b is Vector2
			else:
				is_valid_b = vector_b is Vector3

			if not is_valid_b:
				var type_str = type_string(typeof(vector_b))
				_log_error_localized("FUSE_ERROR_VECTOR_TYPE_INVALID", {"actual_type": type_str})
				set_error_localized("FUSE_ERROR_VECTOR_TYPE_INVALID", FuseError.ErrorType.RUNTIME_ERROR, {"actual_type": type_str})
				finished.emit()
				return

	# 获取标量（如果需要）
	var scalar = null
	if _needs_scalar():
		if scalar_use_variable:
			var result_s = _get_variable_with_scope_source(
				context, scalar_variable, scalar_scope, scalar_scope_source, scalar_scope_id
			)
			if not result_s.success:
				_log_error_localized(result_s.error_key, result_s.error_params)
				set_error_localized(result_s.error_key, FuseError.ErrorType.RUNTIME_ERROR, result_s.error_params)
				finished.emit()
				return
			scalar = result_s.value
		else:
			scalar = scalar_value

		# 验证标量类型
		if scalar != null and not (scalar is float or scalar is int):
			var type_str = type_string(typeof(scalar))
			_log_error_localized("FUSE_ERROR_SCALAR_TYPE_INVALID", {"actual_type": type_str})
			set_error_localized("FUSE_ERROR_SCALAR_TYPE_INVALID", FuseError.ErrorType.RUNTIME_ERROR, {"actual_type": type_str})
			finished.emit()
			return

	# 执行运算
	var result = null

	match operation_type:
		OperationType.VECTOR_ADD:
			result = vector_a + vector_b
			_log_info_localized("FUSE_LOG_VECTOR_ADD", {"a": str(vector_a), "b": str(vector_b), "result": str(result)})

		OperationType.VECTOR_SUBTRACT:
			result = vector_a - vector_b
			_log_info_localized("FUSE_LOG_VECTOR_SUBTRACT", {"a": str(vector_a), "b": str(vector_b), "result": str(result)})

		OperationType.SCALE:
			if vector_type == VectorType.VECTOR2:
				result = (vector_a as Vector2) * scalar
			else:
				result = (vector_a as Vector3) * scalar
			_log_info_localized("FUSE_LOG_VECTOR_SCALE", {"vector": str(vector_a), "scalar": scalar, "result": str(result)})

		OperationType.NORMALIZE:
			var length = 0.0
			if vector_type == VectorType.VECTOR2:
				length = (vector_a as Vector2).length()
			else:
				length = (vector_a as Vector3).length()

			if is_zero_approx(length):
				_log_warning_localized("FUSE_WARNING_ZERO_VECTOR_NORMALIZE", {})
				result = Vector2(0, 0) if vector_type == VectorType.VECTOR2 else Vector3(0, 0, 0)
			else:
				result = vector_a.normalized()
				_log_info_localized("FUSE_LOG_VECTOR_NORMALIZE", {"input": str(vector_a), "result": str(result), "length": length})

		OperationType.LENGTH:
			var length = 0.0
			if vector_type == VectorType.VECTOR2:
				length = (vector_a as Vector2).length()
			else:
				length = (vector_a as Vector3).length()
			result = length
			_log_info_localized("FUSE_LOG_VECTOR_LENGTH", {"vector": str(vector_a), "length": length})

		OperationType.DISTANCE:
			var dist = 0.0
			if vector_type == VectorType.VECTOR2:
				dist = (vector_a as Vector2).distance_to(vector_b)
			else:
				dist = (vector_a as Vector3).distance_to(vector_b)
			result = dist
			_log_info_localized("FUSE_LOG_VECTOR_DISTANCE", {"a": str(vector_a), "b": str(vector_b), "distance": dist})

		_:
			_log_error_localized("FUSE_ERROR_VECTOR_OPERATION_INVALID", {})
			set_error_localized("FUSE_ERROR_VECTOR_OPERATION_INVALID", FuseError.ErrorType.RUNTIME_ERROR, {})
			finished.emit()
			return

	# 保存到变量
	match save_to_scope:
		BaseVariable.VariableScope.LOCAL:
			# 保存到 LOCAL 变量
			var success = VariableOperations.set_variable(context, save_to_variable, BaseVariable.VariableScope.LOCAL, result)
			if not success:
				_log_error_localized("FUSE_ERROR_SET_LOCAL_VARIABLE_FAILED", {"name": save_to_variable})
				set_error_localized("FUSE_ERROR_SET_LOCAL_VARIABLE_FAILED", FuseError.ErrorType.RUNTIME_ERROR, {"name": save_to_variable})
				finished.emit()
				return

		BaseVariable.VariableScope.SCOPE:
			# 保存到 SCOPE 变量
			var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
			var scope_container = VariableScopeUtils.get_scope_container_by_source(
				context,
				utils_scope_source,
				scope_id,
				""  # Output scope 不使用 target_node_path
			)

			if scope_container == null:
				_log_error_localized("FUSE_ERROR_SCOPE_CONTAINER_NOT_FOUND", {})
				set_error_localized("FUSE_ERROR_SCOPE_CONTAINER_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {})
				finished.emit()
				return

			# 设置作用域变量
			var success = scope_container.set_variable(save_to_variable, result)
			if not success:
				_log_error_localized("FUSE_ERROR_SET_SCOPE_VARIABLE_FAILED", {"name": save_to_variable})
				set_error_localized("FUSE_ERROR_SET_SCOPE_VARIABLE_FAILED", FuseError.ErrorType.RUNTIME_ERROR, {"name": save_to_variable})
				finished.emit()
				return

		BaseVariable.VariableScope.GLOBAL:
			# 保存到 GLOBAL 变量
			var success = VariableOperations.set_variable(context, save_to_variable, BaseVariable.VariableScope.GLOBAL, result)
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

	# 验证 Vector A
	if vector_a_variable.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_VECTOR_A_EMPTY"))

	# 验证 Vector B
	if _needs_vector_b() and vector_b_use_variable and vector_b_variable.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_VECTOR_B_EMPTY"))

	# 验证 Scalar
	if _needs_scalar() and scalar_use_variable and scalar_variable.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_SCALAR_EMPTY"))

	# 验证 SCOPE 作用域需要 ScopeVariableManager
	if vector_a_scope == BaseVariable.VariableScope.SCOPE:
		var manager = ScopeVariableManager.get_instance()
		if manager == null:
			errors.append(FuseLocalization.translate("FUSE_ERROR_SCOPE_MANAGER_NOT_FOUND"))

	if _needs_vector_b() and vector_b_use_variable and vector_b_scope == BaseVariable.VariableScope.SCOPE:
		var manager = ScopeVariableManager.get_instance()
		if manager == null:
			errors.append(FuseLocalization.translate("FUSE_ERROR_SCOPE_MANAGER_NOT_FOUND"))

	if _needs_scalar() and scalar_use_variable and scalar_scope == BaseVariable.VariableScope.SCOPE:
		var manager = ScopeVariableManager.get_instance()
		if manager == null:
			errors.append(FuseLocalization.translate("FUSE_ERROR_SCOPE_MANAGER_NOT_FOUND"))

	# 验证 Output 的 SCOPE 作用域
	if save_to_scope == BaseVariable.VariableScope.SCOPE:
		var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
		errors.append_array(VariableScopeUtils.validate_scope_source_params(
			utils_scope_source,
			scope_id,
			""
		))

	return errors

## 验证属性可见性
func _validate_property(property: Dictionary) -> void:
	match property.name:
		# ========== Operation Configuration ==========
		"operation_type", "vector_type":
			return  # 始终显示

		# ========== Vector A Input ==========
		"vector_a_variable", "vector_a_scope", "vector_a_scope_source", "vector_a_scope_id":
			return  # Vector A 始终显示（必须使用变量）

		# ========== Vector B Input ==========
		"vector_b_value":
			if not _needs_vector_b():
				property.usage = PROPERTY_USAGE_NO_EDITOR

		"vector_b_use_variable":
			if not _needs_vector_b():
				property.usage = PROPERTY_USAGE_NO_EDITOR

		"vector_b_variable", "vector_b_scope":
			if not _needs_vector_b() or not vector_b_use_variable:
				property.usage = PROPERTY_USAGE_NO_EDITOR

		"vector_b_scope_source":
			if not _needs_vector_b() or not vector_b_use_variable or vector_b_scope != BaseVariable.VariableScope.SCOPE:
				property.usage = PROPERTY_USAGE_NO_EDITOR

		"vector_b_scope_id":
			if not _needs_vector_b() or not vector_b_use_variable or vector_b_scope_source != VariableScopeUtils.ScopeSource.CUSTOM_ID:
				property.usage = PROPERTY_USAGE_NO_EDITOR

		# ========== Scalar Input ==========
		"scalar_value":
			if not _needs_scalar():
				property.usage = PROPERTY_USAGE_NO_EDITOR

		"scalar_use_variable":
			if not _needs_scalar():
				property.usage = PROPERTY_USAGE_NO_EDITOR

		"scalar_variable", "scalar_scope":
			if not _needs_scalar() or not scalar_use_variable:
				property.usage = PROPERTY_USAGE_NO_EDITOR

		"scalar_scope_source":
			if not _needs_scalar() or not scalar_use_variable or scalar_scope != BaseVariable.VariableScope.SCOPE:
				property.usage = PROPERTY_USAGE_NO_EDITOR

		"scalar_scope_id":
			if not _needs_scalar() or not scalar_use_variable or scalar_scope_source != VariableScopeUtils.ScopeSource.CUSTOM_ID:
				property.usage = PROPERTY_USAGE_NO_EDITOR

		# ========== Output ==========
		"save_to_variable", "save_to_scope":
			return  # 始终显示

		"scope_source":
			# 仅在 save_to_scope == SCOPE 时显示
			if save_to_scope != BaseVariable.VariableScope.SCOPE:
				property.usage = PROPERTY_USAGE_NO_EDITOR
			else:
				VariableScopeUtils.validate_scope_source_property(property, scope_source as VariableScopeUtils.ScopeSource)

		"scope_id":
			# 仅在 save_to_scope == SCOPE 且 scope_source == CUSTOM_ID 时显示
			if save_to_scope != BaseVariable.VariableScope.SCOPE or scope_source != VariableScopeUtils.ScopeSource.CUSTOM_ID:
				property.usage = PROPERTY_USAGE_NO_EDITOR

## 获取指令描述
func get_description() -> String:
	var op_key = ""
	match operation_type:
		OperationType.VECTOR_ADD:
			op_key = "FUSE_VECTOR_OP_ADD"
		OperationType.VECTOR_SUBTRACT:
			op_key = "FUSE_VECTOR_OP_SUBTRACT"
		OperationType.SCALE:
			op_key = "FUSE_VECTOR_OP_SCALE"
		OperationType.NORMALIZE:
			op_key = "FUSE_VECTOR_OP_NORMALIZE"
		OperationType.LENGTH:
			op_key = "FUSE_VECTOR_OP_LENGTH"
		OperationType.DISTANCE:
			op_key = "FUSE_VECTOR_OP_DISTANCE"
		_:
			op_key = "FUSE_VECTOR_OP_UNKNOWN"

	var op_name = FuseLocalization.translate(op_key)
	var type_str = "Vector2" if vector_type == VectorType.VECTOR2 else "Vector3"
	var scope_str = _get_scope_source_string()
	return "%s (%s) → %s [%s]" % [op_name, type_str, save_to_variable, scope_str]
