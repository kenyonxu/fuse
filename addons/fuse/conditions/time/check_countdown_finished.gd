@tool
@icon("res://addons/fuse/icons/builtin/Timer.png")
extends BaseCondition
class_name CheckCountdownFinished

## 倒计时结束条件
##
## 检查倒计时是否结束。通过变量存储开始时间，计算经过的时间。
##
## 重构变量系统: 2026-02-09 - 使用 VariableOperations 统一变量访问

## 作用域来源枚举
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

## 存储开始时间的变量名
@export_group("Countdown Timer")
@export var start_time_variable: String = "":
	set(value):
		start_time_variable = value
		clear_dependencies_cache()
		_update_resource_name()

## 变量作用域
@export var variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
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

## 倒计时时长（秒）
@export var duration: float = 1.0:
	set(value):
		duration = value
		_update_resource_name()

## 更新资源名称（必需）
func _update_resource_name() -> void:
	if start_time_variable.is_empty():
		resource_name = FuseLocalization.translate("FUSE_CONDITION_COUNTDOWN_NOT_SET")
	else:
		var scope_str = _get_scope_source_string()
		resource_name = FuseLocalization.translate_format("FUSE_CONDITION_COUNTDOWN_RESOURCE_NAME", {
			"variable": start_time_variable,
			"scope": scope_str,
			"duration": "%.2f" % duration
		})

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
	if start_time_variable.is_empty():
		var error_msg = FuseLocalization.translate("FUSE_ERROR_VAR_NAME_EMPTY")
		_log_error(error_msg)
		_create_fuse_error(error_msg, FuseError.ErrorType.VALIDATION_ERROR)
		return false

	# 验证时长
	if duration <= 0:
		var error_msg = FuseLocalization.translate("FUSE_ERROR_DURATION_MUST_BE_POSITIVE")
		_log_error(error_msg)
		_create_fuse_error(error_msg, FuseError.ErrorType.VALIDATION_ERROR)
		return false

	# 使用 VariableOperations 获取开始时间
	var start_time = null
	match variable_scope:
		BaseVariable.VariableScope.LOCAL:
			start_time = VariableOperations.get_variable(context, start_time_variable, BaseVariable.VariableScope.LOCAL, null)
		BaseVariable.VariableScope.SCOPE:
			if scope_source == ScopeSource.NEAREST:
				start_time = VariableOperations.get_variable(context, start_time_variable, BaseVariable.VariableScope.SCOPE, null)
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
				start_time = scope_container.get_variable(start_time_variable, null)
		BaseVariable.VariableScope.GLOBAL:
			start_time = VariableOperations.get_variable(context, start_time_variable, BaseVariable.VariableScope.GLOBAL, null)

	if start_time == null and not VariableOperations.has_variable(context, start_time_variable, variable_scope):
		var error_msg = FuseLocalization.translate_format("FUSE_ERROR_START_TIME_VAR_NOT_FOUND", {"var": start_time_variable})
		_log_error(error_msg)
		_create_fuse_error(error_msg, FuseError.ErrorType.RUNTIME_ERROR)
		return false

	# 验证开始时间类型
	if not (start_time is int or start_time is float):
		var error_msg = FuseLocalization.translate("FUSE_ERROR_START_TIME_VAR_MUST_BE_NUMERIC")
		_log_error(error_msg)
		_create_fuse_error(error_msg, FuseError.ErrorType.VALIDATION_ERROR)
		return false

	# 获取当前时间（毫秒）
	var current_time = Time.get_ticks_msec()

	# 计算经过的时间（秒）
	var elapsed_seconds = (current_time - float(start_time)) / 1000.0

	# 检查是否超过时长
	var is_finished = elapsed_seconds >= duration

	_log_debug(FuseLocalization.translate_format(
		"FUSE_CONDITION_LOG_COUNTDOWN_CHECK",
		{"elapsed": "%.2f" % elapsed_seconds, "duration": "%.2f" % duration, "status": FuseLocalization.translate("FUSE_CONDITION_COUNTDOWN_STATUS_FINISHED" if is_finished else "FUSE_CONDITION_COUNTDOWN_STATUS_ONGOING")}
	))

	return is_finished

## 计算依赖
func _compute_dependencies() -> Array[String]:
	if not start_time_variable.is_empty():
		return [start_time_variable]
	return []

## 获取条件类型
func get_condition_type() -> String:
	return "countdown_finished"

## 获取条件分类
func get_condition_category() -> String:
	return "time"

## 获取条件描述
func get_description() -> String:
	if start_time_variable.is_empty():
		return FuseLocalization.translate("FUSE_CONDITION_COUNTDOWN_DESC_NOT_SET")

	var scope_str = _get_scope_source_string()
	var desc = FuseLocalization.translate_format("FUSE_CONDITION_COUNTDOWN_DESC_FORMAT", {
		"variable": start_time_variable,
		"scope": scope_str,
		"duration": "%.2f" % duration
	})

	# 限制描述长度
	if desc.length() > 50:
		desc = desc.substr(0, 47) + "..."

	return desc

## 验证条件
func validate() -> Array[String]:
	var errors = super.validate()

	if start_time_variable.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_VAR_NAME_EMPTY"))

	if duration <= 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_DURATION_MUST_BE_POSITIVE"))

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
	var properties := []

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
		"start_time_variable": start_time_variable,
		"duration": duration
	}

## 设置参数
func set_parameters(parameters: Dictionary):
	if parameters.has("start_time_variable"):
		start_time_variable = parameters["start_time_variable"]
		clear_dependencies_cache()
	if parameters.has("duration"):
		duration = parameters["duration"]

## 获取条件元数据
static func _get_condition_metadata() -> ConditionMetadata:
	var metadata = ConditionMetadata.new()
	metadata.name_key = "FUSE_CONDITION_COUNTDOWN_FINISHED_NAME"
	metadata.category_key = "FUSE_CATEGORY_TIME"
	metadata.description_key = "FUSE_CONDITION_COUNTDOWN_FINISHED_DESC"
	metadata.keywords = ["倒计时", "countdown", "时间", "time", "结束", "finished", "timer"]
	metadata.builtin_icon = "Timer"
	return metadata
