@tool
@icon("res://addons/fuse/icons/builtin/LocalVariable.png")
extends BaseEvent
class_name OnVariableChanged

## 变量变化监听事件
##
## 监听变量值的变化，支持多种检查模式和作用域
##
## 迁移到 RuntimeInstance: 2026-02-03
## 重构变量系统: 2026-02-08 - 使用 ExecutionContext 和 GlobalVariableAssistant 替代 VariableContainer
## 重构变量系统: 2026-02-09 - 使用 VariableOperations 统一变量访问
## 状态变量:
## - _check_timer: float - 检查计时器
## - _last_value: Variant - 上次的值
## - _is_monitoring: bool - 是否正在监听
##
## 相关文档: addons/fuse/docs/migration-guide-to-runtime-instance.md

# 预加载工具类

## 变量名
@export var variable_name: String = "":
	set(value):
		variable_name = value
		_update_resource_name()

## 变量作用域
@export var variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		variable_scope = value
		_update_resource_name()

## 检查模式
enum CheckMode {
	ON_CHANGE,   ## 值变化时触发
	ON_EQUAL,    ## 值等于目标值时触发
	ON_GREATER,  ## 值大于目标值时触发
	ON_LESS      ## 值小于目标值时触发
}

@export var check_mode: CheckMode = CheckMode.ON_CHANGE:
	set(value):
		check_mode = value
		_update_resource_name()

## 目标值（用于 ON_EQUAL、ON_GREATER、ON_LESS 模式）
@export var target_value: Variant = null

## 检查间隔（秒），默认 0.1 秒
@export var check_interval: float = 0.1:
	set(value):
		check_interval = value
		_update_resource_name()

## 是否发出旧值
@export var emit_old_value: bool = true

## 是否发出新值
@export var emit_new_value: bool = true

var _check_timer: float = 0.0
var _last_value: Variant = null
var _is_monitoring: bool = false
var _owner_node_ref: Node = null

## 更新资源名称（必需）
func _update_resource_name():
	var scope_str = VariableScopeUtils.enum_to_string(variable_scope).to_upper()
	var scope_text = "[%s]" % scope_str

	var mode_key = ""
	match check_mode:
		CheckMode.ON_CHANGE:
			mode_key = "FUSE_DESC_CHECK_MODE_CHANGE"
		CheckMode.ON_EQUAL:
			mode_key = "FUSE_DESC_CHECK_MODE_EQUAL"
		CheckMode.ON_GREATER:
			mode_key = "FUSE_DESC_CHECK_MODE_GREATER"
		CheckMode.ON_LESS:
			mode_key = "FUSE_DESC_CHECK_MODE_LESS"

	var mode_text = FuseLocalization.translate(mode_key)
	if check_mode == CheckMode.ON_EQUAL:
		mode_text = FuseLocalization.translate_format(mode_key, {"value": str(target_value)})
	elif check_mode == CheckMode.ON_GREATER:
		mode_text = FuseLocalization.translate_format(mode_key, {"value": str(target_value)})
	elif check_mode == CheckMode.ON_LESS:
		mode_text = FuseLocalization.translate_format(mode_key, {"value": str(target_value)})

	resource_name = FuseLocalization.translate_format("FUSE_EVENT_ON_VARIABLE_CHANGED_RESOURCE_NAME", {
		"variable": variable_name,
		"scope": scope_text,
		"mode": mode_text
	})

## 初始化事件监听（必需）
func initialize(owner_node: Node) -> void:
	# 验证 owner_node
	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 验证 variable_name
	if variable_name.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_VARIABLE_NAME_EMPTY", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 验证 check_interval
	if check_interval <= 0:
		_create_fuse_error_localized("FUSE_ERROR_CHECK_INTERVAL_INVALID", FuseError.ErrorType.CONFIGURATION_ERROR, {"interval": check_interval})
		return

	_owner_node_ref = owner_node

	# 获取 GlobalVariableAssistant 单例（用于监听全局变量变化）
	var assistant = GlobalVariableAssistant.get_instance()
	if not assistant:
		_create_fuse_error_localized("FUSE_ERROR_ASSISTANT_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 🔧 使用 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("is_monitoring", true)
		_runtime_instance_ref.set_runtime_state("check_timer", 0.0)
		_runtime_instance_ref.set_runtime_state("last_value", _get_variable_value())

	# 检查变量是否存在
	if _last_value == null and not _variable_exists():
		_log_debug_localized("FUSE_LOG_EVENT_VARIABLE_NOT_FOUND", {"variable": variable_name, "scope": VariableScopeUtils.enum_to_string(variable_scope)})

	_log_debug_localized("FUSE_LOG_EVENT_VARIABLE_MONITORING_STARTED", {
		"variable": variable_name,
		"scope": VariableScopeUtils.enum_to_string(variable_scope),
		"mode": CheckMode.keys()[check_mode],
		"interval": check_interval
	})

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	# 🔧 清理 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("is_monitoring", false)
		_runtime_instance_ref.set_runtime_state("check_timer", 0.0)
		_runtime_instance_ref.set_runtime_state("last_value", null)

	_owner_node_ref = null

	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 每帧处理（由 Trigger 调用）
func on_process(delta: float) -> void:
	# 🔧 使用 RuntimeEventInstance 的状态
	var is_monitoring = false
	if _runtime_instance_ref:
		is_monitoring = _runtime_instance_ref.runtime_state.get("is_monitoring", false)

	if not is_monitoring:
		return

	var check_timer = 0.0
	if _runtime_instance_ref:
		check_timer = _runtime_instance_ref.runtime_state.get("check_timer", 0.0)

	check_timer += delta

	if check_timer >= check_interval:
		check_timer -= check_interval
		if _runtime_instance_ref:
			_runtime_instance_ref.set_runtime_state("check_timer", check_timer)
		_check_variable()

## 检查变量变化
func _check_variable():
	var current_value = _get_variable_value()

	# 如果变量不存在，跳过检查
	if current_value == null and not _variable_exists():
		return

	var should_trigger = false

	match check_mode:
		CheckMode.ON_CHANGE:
			# 值变化时触发
			if not _are_values_equal(current_value, _last_value):
				should_trigger = true

		CheckMode.ON_EQUAL:
			# 值等于目标值时触发
			if _are_values_equal(current_value, target_value):
				should_trigger = true

		CheckMode.ON_GREATER:
			# 值大于目标值时触发
			if _compare_values(current_value, target_value) > 0:
				should_trigger = true

		CheckMode.ON_LESS:
			# 值小于目标值时触发
			if _compare_values(current_value, target_value) < 0:
				should_trigger = true

	if should_trigger:
		var old_val = _last_value
		_last_value = current_value

		_log_info_localized("FUSE_LOG_EVENT_VARIABLE_CHANGED", {
			"variable": variable_name,
			"old_value": str(old_val) if emit_old_value else "(未发出)",
			"new_value": str(current_value) if emit_new_value else "(未发出)",
			"mode": CheckMode.keys()[check_mode]
		})

		# 创建上下文节点传递值
		var context_node = Node.new()
		context_node.name = "VariableChangedContext"
		if emit_old_value:
			context_node.set_meta("old_value", old_val)
		if emit_new_value:
			context_node.set_meta("new_value", current_value)
		context_node.set_meta("variable_name", variable_name)
		context_node.set_meta("variable_scope", VariableScopeUtils.enum_to_string(variable_scope))

		triggered.emit(context_node)

		# 清理上下文节点
		context_node.queue_free()

## 获取变量值（使用 VariableOperations 工具类）
func _get_variable_value() -> Variant:
	# 使用 VariableOperations 获取变量值
	var value = VariableOperations.get_variable(_create_temp_context(), variable_name, variable_scope, null)
	return value

## 检查变量是否存在（使用 VariableOperations 工具类）
func _variable_exists() -> bool:
	# 使用 VariableOperations 检查变量是否存在
	return VariableOperations.has_variable(_create_temp_context(), variable_name, variable_scope)

## 创建临时上下文（用于在初始化阶段访问变量）
func _create_temp_context() -> ExecutionContext:
	# 创建一个临时的 ExecutionContext 用于变量访问
	# 注意：这个方法只在 initialize() 阶段使用，此时还没有真实的执行上下文
	var temp_context = ExecutionContext.new()

	# 如果有 owner_node_ref，设置为 trigger
	if _owner_node_ref:
		temp_context.trigger = _owner_node_ref

	return temp_context


## 比较两个值是否相等
func _are_values_equal(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b):
		return false

	return a == b

## 比较两个值的大小
func _compare_values(a: Variant, b: Variant) -> int:
	# 检查是否可以比较
	if typeof(a) != typeof(b):
		_log_warning("变量值类型不一致，无法比较: %s vs %s" % [type_string(typeof(a)), type_string(typeof(b))])
		return 0

	# 支持数值比较
	if a is float or a is int:
		if a < b:
			return -1
		elif a > b:
			return 1
		else:
			return 0

	# 其他类型不支持比较
	_log_warning("不支持的比较类型: %s" % type_string(typeof(a)))
	return 0

## 获取事件描述
func get_description() -> String:
	var scope_key = "FUSE_DESC_GLOBAL"
	var scope_text = FuseLocalization.translate(scope_key)

	var mode_key = ""
	match check_mode:
		CheckMode.ON_CHANGE:
			mode_key = "FUSE_DESC_CHECK_MODE_CHANGE_TRIGGER"
		CheckMode.ON_EQUAL:
			mode_key = "FUSE_DESC_CHECK_MODE_EQUAL_TRIGGER"
		CheckMode.ON_GREATER:
			mode_key = "FUSE_DESC_CHECK_MODE_GREATER_TRIGGER"
		CheckMode.ON_LESS:
			mode_key = "FUSE_DESC_CHECK_MODE_LESS_TRIGGER"

	var mode_text = FuseLocalization.translate(mode_key)
	if check_mode == CheckMode.ON_EQUAL:
		mode_text = FuseLocalization.translate_format(mode_key, {"value": str(target_value)})
	elif check_mode == CheckMode.ON_GREATER:
		mode_text = FuseLocalization.translate_format(mode_key, {"value": str(target_value)})
	elif check_mode == CheckMode.ON_LESS:
		mode_text = FuseLocalization.translate_format(mode_key, {"value": str(target_value)})

	var value_key = ""
	if emit_old_value and emit_new_value:
		value_key = "FUSE_DESC_EMIT_BOTH_VALUES"
	elif emit_old_value:
		value_key = "FUSE_DESC_EMIT_OLD_VALUE"
	elif emit_new_value:
		value_key = "FUSE_DESC_EMIT_NEW_VALUE"

	var value_text = FuseLocalization.translate(value_key)

	return FuseLocalization.translate_format("FUSE_EVENT_ON_VARIABLE_CHANGED_DESC", {
		"scope": scope_text,
		"variable": variable_name,
		"mode": mode_text,
		"interval": "%.2f" % check_interval,
		"value": value_text
	})

## 获取事件类型
func get_event_type() -> String:
	return "variable_changed"

## 获取事件分类
func get_event_category() -> String:
	return "state"

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	if variable_name.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_VARIABLE_NAME_EMPTY"))

	if check_interval <= 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_CHECK_INTERVAL_INVALID"))

	return errors

## 重置事件状态
func reset() -> void:
	super.reset()
	_check_timer = 0.0
	_last_value = _get_variable_value()
	_log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["check_timer"] = 0.0
	base["last_value"] = null
	base["is_monitoring"] = false
	return base

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_ON_VARIABLE_CHANGED_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_STATE"
	metadata.description_key = "FUSE_EVENT_ON_VARIABLE_CHANGED_DESC"
	metadata.keywords = ["variable", "变量", "change", "变化", "monitor", "监听", "watch", "观察", "value", "值"]
	metadata.builtin_icon = "LocalVariable"
	return metadata
