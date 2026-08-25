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
		notify_property_list_changed()

## 作用域来源（仅当 variable_scope == SCOPE 时使用）
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

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
var scope_target_node_path: NodePath = NodePath(""):
	set(value):
		scope_target_node_path = value
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

## 目标值类型（用于 ON_EQUAL、ON_GREATER、ON_LESS 模式）
enum TargetValueType {
	BOOL,
	INT,
	FLOAT,
	STRING
}

@export var target_value_type: TargetValueType = TargetValueType.INT:
	set(value):
		target_value_type = value
		_update_resource_name()
		notify_property_list_changed()

@export var target_bool_value: bool = false:
	set(value):
		target_bool_value = value
		_update_resource_name()

@export var target_int_value: int = 0:
	set(value):
		target_int_value = value
		_update_resource_name()

@export var target_float_value: float = 0.0:
	set(value):
		target_float_value = value
		_update_resource_name()

@export var target_string_value: String = "":
	set(value):
		target_string_value = value
		_update_resource_name()

## 按类型枚举解析目标值（@export Variant 为 null 时 Inspector 不可编辑——
## 项目内 Variant 值输入的验证模式是类型枚举+类型化字段，对齐 CheckNodeProperty）
func _resolve_target_value() -> Variant:
	match target_value_type:
		TargetValueType.BOOL:
			return target_bool_value
		TargetValueType.INT:
			return target_int_value
		TargetValueType.FLOAT:
			return target_float_value
		TargetValueType.STRING:
			return target_string_value
	return null

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

## 动态属性列表：SCOPE 四态子来源 + target_value 可编辑 Variant
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	if variable_scope == BaseVariable.VariableScope.SCOPE:
		properties.append({
			name = "scope_source",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
		if scope_source == ScopeSource.CUSTOM_ID:
			properties.append({
				name = "custom_scope_id",
				type = TYPE_STRING,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})
		elif scope_source == ScopeSource.TARGET_NODE:
			properties.append({
				name = "scope_target_node_path",
				type = TYPE_NODE_PATH,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

	# 值字段由 @export 自动列出，此处不重复声明（避免同名双条目）；
	# 只显示当前类型的字段靠 _validate_property 隐藏其余
	return properties

## 属性可见性：非 SCOPE 隐藏子来源；NEAREST 隐藏子参数
func _validate_property(property: Dictionary) -> void:
	# 隐藏非当前类型的值字段
	var active_value_field := "target_%s_value" % ["bool", "int", "float", "string"][target_value_type]
	for field in ["target_bool_value", "target_int_value", "target_float_value", "target_string_value"]:
		if field == active_value_field:
			continue
		if property.name == field:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	if variable_scope != BaseVariable.VariableScope.SCOPE:
		if property.name in ["scope_source", "custom_scope_id", "scope_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	elif scope_source == ScopeSource.NEAREST:
		if property.name in ["custom_scope_id", "scope_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
		VariableScopeUtils.validate_scope_source_property(property, utils_scope_source)

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
		mode_text = FuseLocalization.translate_format(mode_key, {"value": str(_resolve_target_value())})
	elif check_mode == CheckMode.ON_GREATER:
		mode_text = FuseLocalization.translate_format(mode_key, {"value": str(_resolve_target_value())})
	elif check_mode == CheckMode.ON_LESS:
		mode_text = FuseLocalization.translate_format(mode_key, {"value": str(_resolve_target_value())})

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

	# 🔧 使用 RuntimeEventInstance 的状态（last_value 与 _check_variable 走同一 helper，
	# 避免历史上成员变量与 runtime_state 两套状态脱节导致的初始化假触发）
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("is_monitoring", true)
		_runtime_instance_ref.set_runtime_state("check_timer", 0.0)
		_runtime_instance_ref.set_runtime_state("last_value", _get_variable_value())

	# 检查变量是否存在
	if _get_state().get("last_value", null) == null and not _variable_exists():
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
func on_process(delta: float, event_instance: RuntimeEventInstance = null) -> void:
	var state := _get_state(event_instance)
	if not state.get("is_monitoring", false):
		return

	# 每帧写回累计值——历史上只在到点时写回，未到点时累计结果丢失，永不触发
	var check_timer: float = state.get("check_timer", 0.0) + delta
	if check_timer >= check_interval:
		check_timer -= check_interval
		state["check_timer"] = check_timer
		_check_variable(event_instance)
	else:
		state["check_timer"] = check_timer

## 取运行时状态字典（优先显式实例，回退成员引用——兼容两条调用路径）
func _get_state(event_instance: RuntimeEventInstance = null) -> Dictionary:
	if event_instance:
		return event_instance.runtime_state
	if _runtime_instance_ref:
		return _runtime_instance_ref.runtime_state
	return {}

## 检查变量变化
func _check_variable(event_instance: RuntimeEventInstance = null):
	var state := _get_state(event_instance)
	var current_value = _get_variable_value()

	# 如果变量不存在，跳过检查
	if current_value == null and not _variable_exists():
		return

	var should_trigger = false

	match check_mode:
		CheckMode.ON_CHANGE:
			# 值变化时触发（读 state 的 last_value——历史上读成员变量恒 null，
			# 与 initialize 写入的 runtime_state 脱节，导致每次轮询都假触发）
			if not _are_values_equal(current_value, state.get("last_value", null)):
				should_trigger = true

		CheckMode.ON_EQUAL:
			# 值等于目标值时触发
			if _are_values_equal(current_value, _resolve_target_value()):
				should_trigger = true

		CheckMode.ON_GREATER:
			# 值大于目标值时触发
			if _compare_values(current_value, _resolve_target_value()) > 0:
				should_trigger = true

		CheckMode.ON_LESS:
			# 值小于目标值时触发
			if _compare_values(current_value, _resolve_target_value()) < 0:
				should_trigger = true

	if should_trigger:
		var old_val = state.get("last_value", null)
		state["last_value"] = current_value

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

		# 桥接到 last_event_args（宿主 Trigger 同步为 event_<参数名> 局部变量，
		# 与 OnTargetSignalEmit/OnReceiveEvent 的 A1 桥接同款）
		if _runtime_instance_ref:
			var args: Dictionary = {"variable_name": variable_name}
			if emit_old_value:
				args["old_value"] = old_val
			if emit_new_value:
				args["new_value"] = current_value
			_runtime_instance_ref.set_runtime_state("last_event_args", args)

		triggered.emit(context_node)

		# 清理上下文节点
		context_node.queue_free()

## 获取变量值（SCOPE 时按 scope_source 分子来源解析容器）
func _get_variable_value() -> Variant:
	var context = _create_temp_context()
	if variable_scope == BaseVariable.VariableScope.SCOPE and scope_source != ScopeSource.NEAREST:
		var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
		var scope_container = VariableScopeUtils.get_scope_container_by_source(
			context, utils_scope_source, custom_scope_id, scope_target_node_path)
		if scope_container == null:
			return null
		if not scope_container.has_variable(variable_name):
			return null
		return scope_container.get_variable(variable_name)
	return VariableOperations.get_variable(context, variable_name, variable_scope, null)

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


## 比较两个值是否相等（数值 int/float 与 String/StringName 宽松互转）
func _are_values_equal(a: Variant, b: Variant) -> bool:
	var ta := typeof(a)
	var tb := typeof(b)
	if ta == tb:
		return a == b
	if (ta == TYPE_INT or ta == TYPE_FLOAT) and (tb == TYPE_INT or tb == TYPE_FLOAT):
		return float(a) == float(b)
	if (ta == TYPE_STRING and tb == TYPE_STRING_NAME) or (ta == TYPE_STRING_NAME and tb == TYPE_STRING):
		return String(a) == String(b)
	return false

## 比较两个值的大小
func _compare_values(a: Variant, b: Variant) -> int:
	# 数值互转后可比较（int/float）
	if (a is int or a is float) and (b is int or b is float):
		if a < b:
			return -1
		elif a > b:
			return 1
		return 0

	# 类型不同且非数值族，无法比较
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
		mode_text = FuseLocalization.translate_format(mode_key, {"value": str(_resolve_target_value())})
	elif check_mode == CheckMode.ON_GREATER:
		mode_text = FuseLocalization.translate_format(mode_key, {"value": str(_resolve_target_value())})
	elif check_mode == CheckMode.ON_LESS:
		mode_text = FuseLocalization.translate_format(mode_key, {"value": str(_resolve_target_value())})

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

	if variable_scope == BaseVariable.VariableScope.SCOPE:
		var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
		errors.append_array(VariableScopeUtils.validate_scope_source_params(
			utils_scope_source, custom_scope_id, scope_target_node_path))

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
