@tool
@icon("res://addons/fuse/icons/builtin/InterpCubic.png")
extends BaseInstruction
class_name Lerp

## 线性插值计算
##
## 重构变量系统: 2026-02-09 - 使用 VariableOperations 统一变量访问

## 作用域来源
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

# 起始值来源
enum FromSource {
	DIRECT,
	VARIABLE
}
var from_source: FromSource = FromSource.DIRECT:
	set(value_):
		from_source = value_
		notify_property_list_changed()
		_update_resource_name()

# 起始值
var from_value: float = 0.0:
	set(value_):
		from_value = value_
		_update_resource_name()

# 起始值变量名
var from_variable: String = "":
	set(value_):
		from_variable = value_
		_update_resource_name()

# 起始值变量作用域
@export var from_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		from_scope = value
		_update_resource_name()

# 目标值来源
enum ToSource {
	DIRECT,
	VARIABLE
}
var to_source: ToSource = ToSource.DIRECT:
	set(value_):
		to_source = value_
		notify_property_list_changed()
		_update_resource_name()

# 目标值
var to_value: float = 100.0:
	set(value_):
		to_value = value_
		_update_resource_name()

# 目标值变量名
var to_variable: String = "":
	set(value_):
		to_variable = value_
		_update_resource_name()

# 目标值变量作用域
@export var to_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		to_scope = value
		_update_resource_name()

# 插值因子（0.0 - 1.0）
var weight: float = 0.5:
	set(value_):
		weight = value_
		_update_resource_name()

# 权重来源
enum WeightSource {
	DIRECT,
	VARIABLE
}
var weight_source: WeightSource = WeightSource.DIRECT:
	set(value_):
		weight_source = value_
		notify_property_list_changed()
		_update_resource_name()

# 权重变量名
var weight_variable: String = "":
	set(value_):
		weight_variable = value_
		_update_resource_name()

# 权重变量作用域
@export var weight_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		weight_scope = value
		_update_resource_name()

# 保存到变量
var save_to_variable: String = "lerped_value":
	set(value_):
		save_to_variable = value_
		_update_resource_name()

## 保存到作用域
@export var save_to_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
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
	metadata.name_key = "FUSE_INSTRUCTION_LERP_NAME"
	metadata.category_key = "FUSE_CATEGORY_MATH"
	metadata.description_key = "FUSE_INSTRUCTION_LERP_DESC"
	metadata.keywords = ["lerp", "interpolate", "linear", "blend", "插值", "线性", "混合"]
	metadata.builtin_icon = "InterpCubic"
	return metadata

func _setup_metadata():
	pass

## 声明变量读写模式（save_to=write, from/to/weight=read）
func get_variable_modes() -> Array[Dictionary]:
	return [
		{"name": "save_to_variable", "mode": "write"},
		{"name": "from_variable", "mode": "read"},
		{"name": "to_variable", "mode": "read"},
		{"name": "weight_variable", "mode": "read"},
	]

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties := []

	properties.append({
		name = "From",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "from_source",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Direct,Variable",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if from_source == FromSource.DIRECT:
		properties.append({
			name = "from_value",
			type = TYPE_FLOAT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "-99999,99999,0.1,or_less,or_greater",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
	else:
		properties.append({
			name = "from_variable",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		properties.append({
			name = "from_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

	properties.append({
		name = "To",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "to_source",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Direct,Variable",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if to_source == ToSource.DIRECT:
		properties.append({
			name = "to_value",
			type = TYPE_FLOAT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "-99999,99999,0.1,or_less,or_greater",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
	else:
		properties.append({
			name = "to_variable",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		properties.append({
			name = "to_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

	properties.append({
		name = "Weight",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "weight_source",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Direct,Variable",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if weight_source == WeightSource.DIRECT:
		properties.append({
			name = "weight",
			type = TYPE_FLOAT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0,1,0.01",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
	else:
		properties.append({
			name = "weight_variable",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		properties.append({
			name = "weight_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
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

	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_LERP_RESOURCE_NAME"))

	var from_str = ""
	var to_str = ""
	var weight_str = ""

	if from_source == FromSource.DIRECT:
		from_str = "%.1f" % from_value
	else:
		var scope_str = VariableScopeUtils.enum_to_string(from_scope).to_upper()
		var var_name = FuseLocalization.translate("FUSE_VALUE_VARIABLE_EMPTY") if from_variable.is_empty() else from_variable
		from_str = "%s [%s]" % [var_name, scope_str]

	if to_source == ToSource.DIRECT:
		to_str = "%.1f" % to_value
	else:
		var scope_str = VariableScopeUtils.enum_to_string(to_scope).to_upper()
		var var_name = FuseLocalization.translate("FUSE_VALUE_VARIABLE_EMPTY") if to_variable.is_empty() else to_variable
		to_str = "%s [%s]" % [var_name, scope_str]

	if weight_source == WeightSource.DIRECT:
		weight_str = "%.2f" % weight
	else:
		var scope_str = VariableScopeUtils.enum_to_string(weight_scope).to_upper()
		var var_name = FuseLocalization.translate("FUSE_VALUE_VARIABLE_EMPTY") if weight_variable.is_empty() else weight_variable
		weight_str = "%s [%s]" % [var_name, scope_str]

	parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_LERP_RESOURCE_NAME_FORMAT", {"from": from_str, "to": to_str, "weight": weight_str}))

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

	# 获取起始值
	var from := 0.0
	if from_source == FromSource.DIRECT:
		from = from_value
	else:
		if from_variable.is_empty():
			_log_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", {})
			set_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
			finished.emit()
			return
		from = float(VariableOperations.get_variable(context, from_variable, from_scope, null))

	# 获取目标值
	var to := 0.0
	if to_source == ToSource.DIRECT:
		to = to_value
	else:
		if to_variable.is_empty():
			_log_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", {})
			set_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
			finished.emit()
			return
		to = float(VariableOperations.get_variable(context, to_variable, to_scope, null))

	# 获取权重
	var w := 0.0
	if weight_source == WeightSource.DIRECT:
		w = weight
	else:
		if weight_variable.is_empty():
			_log_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", {})
			set_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
			finished.emit()
			return
		w = float(VariableOperations.get_variable(context, weight_variable, weight_scope, null))

	# 计算插值
	var lerped_value = lerp(from, to, w)

	# 保存到变量
	match save_to_scope:
		BaseVariable.VariableScope.LOCAL:
			# 保存到 LOCAL 变量
			var success = VariableOperations.set_variable(context, save_to_variable, BaseVariable.VariableScope.LOCAL, lerped_value)
			if not success:
				_log_error_localized("FUSE_ERROR_SET_LOCAL_VARIABLE_FAILED", {"name": save_to_variable})
				set_error_localized("FUSE_ERROR_SET_LOCAL_VARIABLE_FAILED", FuseError.ErrorType.RUNTIME_ERROR, {"name": save_to_variable})
				finished.emit()
				return

		BaseVariable.VariableScope.SCOPE:
			# 保存到 SCOPE 变量
			if scope_source == ScopeSource.NEAREST:
				# NEAREST 模式：使用 VariableOperations 的默认行为
				VariableOperations.set_variable(context, save_to_variable, BaseVariable.VariableScope.SCOPE, lerped_value)
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
				var success = scope_container.set_variable(save_to_variable, lerped_value)
				if not success:
					_log_error_localized("FUSE_ERROR_SET_SCOPE_VARIABLE_FAILED", {"name": save_to_variable})
					set_error_localized("FUSE_ERROR_SET_SCOPE_VARIABLE_FAILED", FuseError.ErrorType.RUNTIME_ERROR, {"name": save_to_variable})
					finished.emit()
					return

		BaseVariable.VariableScope.GLOBAL:
			# 保存到 GLOBAL 变量
			var success = VariableOperations.set_variable(context, save_to_variable, BaseVariable.VariableScope.GLOBAL, lerped_value)
			if not success:
				_log_error_localized("FUSE_ERROR_SET_GLOBAL_VARIABLE_FAILED", {"name": save_to_variable})
				set_error_localized("FUSE_ERROR_SET_GLOBAL_VARIABLE_FAILED", FuseError.ErrorType.RUNTIME_ERROR, {"name": save_to_variable})
				finished.emit()
				return

	_log_info_localized("FUSE_LOG_LERP", {"from": from, "to": to, "weight": w, "result": lerped_value})
	_on_execution_completed()

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()

	if save_to_variable.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_VAR_NAME_EMPTY"))

	if from_source == FromSource.VARIABLE and from_variable.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_FROM_VAR_NAME_EMPTY"))

	if to_source == ToSource.VARIABLE and to_variable.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TO_VAR_NAME_EMPTY"))

	if weight_source == WeightSource.VARIABLE and weight_variable.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_WEIGHT_VAR_NAME_EMPTY"))

	# 验证 SCOPE 作用域需要 ScopeVariableManager
	if from_source == FromSource.VARIABLE and from_scope == BaseVariable.VariableScope.SCOPE:
		var manager = ScopeVariableManager.get_instance()
		if manager == null:
			errors.append(FuseLocalization.translate("FUSE_ERROR_SCOPE_MANAGER_NOT_FOUND"))

	if to_source == ToSource.VARIABLE and to_scope == BaseVariable.VariableScope.SCOPE:
		var manager = ScopeVariableManager.get_instance()
		if manager == null:
			errors.append(FuseLocalization.translate("FUSE_ERROR_SCOPE_MANAGER_NOT_FOUND"))

	if weight_source == WeightSource.VARIABLE and weight_scope == BaseVariable.VariableScope.SCOPE:
		var manager = ScopeVariableManager.get_instance()
		if manager == null:
			errors.append(FuseLocalization.translate("FUSE_ERROR_SCOPE_MANAGER_NOT_FOUND"))

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
	# 只在 SCOPE 作用域时验证 ScopeSource 相关属性
	if save_to_scope == BaseVariable.VariableScope.SCOPE:
		VariableScopeUtils.validate_scope_source_property(property, scope_source as VariableScopeUtils.ScopeSource)
	else:
		# 非 SCOPE 作用域时隐藏 ScopeSource 相关属性
		if property.name in ["scope_source", "custom_scope_id", "target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR

## 获取指令描述
func get_description() -> String:
	var scope_str = _get_scope_source_string()
	return "Lerp → %s [%s]" % [save_to_variable, scope_str]

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
