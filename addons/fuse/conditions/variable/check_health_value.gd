@tool
@icon("res://addons/fuse/icons/builtin/Heart.png")
extends BaseCondition
class_name CheckHealthValue

## 生命值检测条件
##
## 检查生命值变量是否等于指定值。
##
## 重构变量系统: 2026-02-09 - 使用 VariableOperations 统一变量访问

## 作用域来源枚举
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

## 生命值变量名
@export_group("Health Value Check")
@export var health_variable: String = "":
	set(value):
		health_variable = value
		clear_dependencies_cache()
		_update_resource_name()

## 变量作用域
var variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		if variable_scope != value:
			variable_scope = value
			_update_resource_name()
			notify_property_list_changed()

## 作用域来源（仅当 variable_scope == SCOPE 时使用）
var scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		if scope_source != value:
			scope_source = value
			_update_resource_name()
			notify_property_list_changed()

## 自定义作用域 ID（CUSTOM_ID 模式使用）
var custom_scope_id: String = "":
	set(value):
		if custom_scope_id != value:
			custom_scope_id = value
			_update_resource_name()

## 目标节点路径（TARGET_NODE 模式使用）
var target_node_path: NodePath = NodePath(""):
	set(value):
		if target_node_path != value:
			target_node_path = value
			_update_resource_name()

## 目标生命值
@export var target_value: float = 0.0:
	set(value):
		target_value = value
		_update_resource_name()

## 更新资源名称（必需）
func _update_resource_name() -> void:
	if health_variable.is_empty():
		resource_name = FuseLocalization.translate("FUSE_CONDITION_HEALTH_NOT_SET")
	else:
		var scope_str = _get_scope_source_string()
		resource_name = "%s [%s] HP == %s" % [
			health_variable,
			scope_str,
			str(target_value)
		]

## 获取作用域来源字符串
func _get_scope_source_string() -> String:
	match variable_scope:
		BaseVariable.VariableScope.LOCAL:
			return FuseLocalization.translate("FUSE_VARIABLE_SCOPE_LOCAL_STR")
		BaseVariable.VariableScope.GLOBAL:
			return FuseLocalization.translate("FUSE_VARIABLE_SCOPE_GLOBAL_STR")
		BaseVariable.VariableScope.SCOPE:
			return VariableScopeUtils.get_scope_source_string(
				scope_source as VariableScopeUtils.ScopeSource,
				custom_scope_id,
				target_node_path
			)
		_:
			return FuseLocalization.translate("FUSE_VARIABLE_SCOPE_UNKNOWN")

## 评估条件
func _evaluate_condition(context: ExecutionContext) -> bool:
	# 验证变量名
	if health_variable.is_empty():
		var error_msg = FuseLocalization.translate("FUSE_ERROR_HEALTH_VAR_NAME_EMPTY")
		_log_error(error_msg)
		_create_fuse_error(error_msg, FuseError.ErrorType.VALIDATION_ERROR)
		return false

	# 使用 VariableOperations 获取生命值
	var health = null
	match variable_scope:
		BaseVariable.VariableScope.LOCAL:
			health = VariableOperations.get_variable(context, health_variable, BaseVariable.VariableScope.LOCAL, null)
		BaseVariable.VariableScope.SCOPE:
			if scope_source == ScopeSource.NEAREST:
				health = VariableOperations.get_variable(context, health_variable, BaseVariable.VariableScope.SCOPE, null)
			else:
				var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
				var scope_container = VariableScopeUtils.get_scope_container_by_source(
					context,
					utils_scope_source,
					custom_scope_id,
					target_node_path
				)
				if scope_container == null:
					var error_msg = FuseLocalization.translate("FUSE_ERROR_SCOPE_CONTAINER_NOT_FOUND")
					_log_error(error_msg)
					_create_fuse_error(error_msg, FuseError.ErrorType.RUNTIME_ERROR)
					return false
				health = scope_container.get_variable(health_variable, null)
		BaseVariable.VariableScope.GLOBAL:
			health = VariableOperations.get_variable(context, health_variable, BaseVariable.VariableScope.GLOBAL, null)

	if health == null and not VariableOperations.has_variable(context, health_variable, variable_scope):
		var error_msg = FuseLocalization.translate_format("FUSE_ERROR_HEALTH_VAR_NOT_FOUND", {"var": health_variable})
		_log_error(error_msg)
		_create_fuse_error(error_msg, FuseError.ErrorType.RUNTIME_ERROR)
		return false

	# 类型检查和转换
	var health_float = 0.0
	if health is int or health is float:
		health_float = float(health)
	else:
		var error_msg = FuseLocalization.translate("FUSE_ERROR_HEALTH_VAR_MUST_BE_NUMERIC")
		_log_error(error_msg)
		_create_fuse_error(error_msg, FuseError.ErrorType.VALIDATION_ERROR)
		return false

	# 比较生命值
	var is_equal = is_equal_approx(health_float, target_value)

	_log_debug(FuseLocalization.translate_format(
		"FUSE_CONDITION_LOG_HEALTH_CHECK",
		{"var": health_variable, "value": health_float, "target": target_value, "result": "相等" if is_equal else "不相等"}
	))

	return is_equal

## 计算依赖
func _compute_dependencies() -> Array[String]:
	if not health_variable.is_empty():
		return [health_variable]
	return []

## 获取条件类型
func get_condition_type() -> String:
	return "health_value"

## 获取条件分类
func get_condition_category() -> String:
	return "variable"

## 声明变量读写模式（精确化静态分析）
## health_variable 仅 read（_evaluate_condition 中读取血量比较）
func get_variable_modes() -> Array[Dictionary]:
	return [
		{"name": "health_variable", "mode": "read"},
	]

## 获取条件描述
func get_description() -> String:
	if health_variable.is_empty():
		return FuseLocalization.translate("FUSE_CONDITION_HEALTH_DESC_NOT_SET")

	var scope_str = _get_scope_source_string()
	var desc = "%s [%s] HP == %s" % [
		health_variable,
		scope_str,
		str(target_value)
	]

	# 限制描述长度
	if desc.length() > 50:
		desc = desc.substr(0, 47) + "..."

	return desc

## 验证条件
func validate() -> Array[String]:
	var errors = super.validate()

	if health_variable.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_HEALTH_VAR_NAME_EMPTY"))

	# 验证 SCOPE 作用域需要 ScopeVariableManager
	if variable_scope == BaseVariable.VariableScope.SCOPE:
		var manager = ScopeVariableManager.get_instance()
		if manager == null:
			errors.append(FuseLocalization.translate("FUSE_ERROR_SCOPE_MANAGER_NOT_FOUND"))

		# 验证 ScopeSource 参数
		var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
		errors.append_array(VariableScopeUtils.validate_scope_source_params(
			utils_scope_source,
			custom_scope_id,
			target_node_path
		))

	return errors

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	# 始终显示 variable_scope
	properties.append({
		name = "variable_scope",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Local,Scope,Global",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 只在 variable_scope == SCOPE 时显示 ScopeSource
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

		# 根据 scope_source 添加额外属性
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

## 验证属性可见性
func _validate_property(property: Dictionary) -> void:
	# 只在 SCOPE 作用域时验证 ScopeSource 相关属性
	if variable_scope == BaseVariable.VariableScope.SCOPE:
		VariableScopeUtils.validate_scope_source_property(property, scope_source as VariableScopeUtils.ScopeSource)
	else:
		# 非 SCOPE 作用域时隐藏 ScopeSource 相关属性
		if property.name in ["scope_source", "custom_scope_id", "target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR

## 获取参数
func get_parameters() -> Dictionary:
	return {
		"health_variable": health_variable,
		"target_value": target_value
	}

## 设置参数
func set_parameters(parameters: Dictionary):
	if parameters.has("health_variable"):
		health_variable = parameters["health_variable"]
		clear_dependencies_cache()
	if parameters.has("target_value"):
		target_value = parameters["target_value"]

## 获取条件元数据
static func _get_condition_metadata() -> ConditionMetadata:
	var metadata = ConditionMetadata.new()
	metadata.name_key = "FUSE_CONDITION_HEALTH_VALUE_NAME"
	metadata.category_key = "FUSE_CATEGORY_VARIABLES"
	metadata.description_key = "FUSE_CONDITION_HEALTH_VALUE_DESC"
	metadata.keywords = ["生命值", "health", "HP", "变量", "variable", "等于"]
	metadata.builtin_icon = "Heart"
	return metadata
