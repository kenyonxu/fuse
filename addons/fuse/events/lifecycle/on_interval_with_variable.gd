@tool
@icon("res://addons/fuse/icons/builtin/Timer.png")
extends OnInterval
class_name OnIntervalWithVariable

## 变量控制间隔执行事件
##
## 从本地变量动态获取执行间隔，支持运行时修改间隔时间。
## 继承 OnInterval 的所有功能，增加变量读取支持。
##
## 特性：
## - 从本地变量读取间隔值（默认变量名："interval"）
## - 支持设置默认值（变量不存在时使用）
## - 支持自动初始化变量
## - 内置最小间隔保护（0.033秒，约30fps）
##
## 状态变量（继承自 OnInterval）：
## - _is_running: bool - 是否正在运行
## - _is_completed: bool - 是否已完成
## - _current_repeat_count: int - 当前重复次数
## - _last_input_time: float - 最近一次输入的时间戳
##
## 相关文档: addons/fuse/docs/zh_CN/dev_docs/guides/runtime-instance-migration-guide.md

## 内部常量：最小间隔时间（约30fps，防止过快触发导致性能问题）
const MIN_INTERVAL: float = 0.033

## 变量名（从该本地变量读取间隔值）
@export var variable_name: String = "interval":
	set(value):
		variable_name = value
		_update_resource_name()

## 变量作用域（从哪个作用域读取变量）
var variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		variable_scope = value
		_update_resource_name()
		notify_property_list_changed()

## 默认间隔值（当变量不存在或无效时使用，单位：秒）
@export var default_interval: float = 1.0:
	set(value):
		default_interval = value
		_update_resource_name()

## 是否在初始化时自动设置变量的默认值
## 如果变量不存在，会使用 default_interval 创建该变量
@export var initialize_variable: bool = true:
	set(value):
		initialize_variable = value
		_update_resource_name()

## 获取属性列表（动态显示作用域属性）
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []

	# 变量作用域
	properties.append({
		"name": "variable_scope",
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Local,Scope,Global",
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 更新资源名称（重写父类方法）
func _update_resource_name():
	# 作用域文本
	var scope_text = ""
	match variable_scope:
		BaseVariable.VariableScope.LOCAL:
			scope_text = FuseLocalization.translate("FUSE_VARIABLE_SCOPE_LOCAL_STR")
		BaseVariable.VariableScope.SCOPE:
			scope_text = FuseLocalization.translate("FUSE_VARIABLE_SCOPE_SCOPE_STR")
		BaseVariable.VariableScope.GLOBAL:
			scope_text = FuseLocalization.translate("FUSE_VARIABLE_SCOPE_GLOBAL_STR")

	var var_text = FuseLocalization.translate_format(
		"FUSE_EVENT_ON_INTERVAL_WITH_VARIABLE_VAR",
		{"name": variable_name}
	)
	var default_text = FuseLocalization.translate_format(
		"FUSE_EVENT_ON_INTERVAL_WITH_VARIABLE_DEFAULT",
		{"value": str(default_interval)}
	)
	var init_text_key = "FUSE_EVENT_ON_INTERVAL_WITH_VARIABLE_INIT_ENABLED" if initialize_variable else "FUSE_EVENT_ON_INTERVAL_WITH_VARIABLE_INIT_DISABLED"
	var init_text = FuseLocalization.translate(init_text_key)

	# 重复次数文本
	var repeat_text_key = "FUSE_EVENT_ON_INTERVAL_REPEAT_INFINITE" if max_repeats == 0 else "FUSE_EVENT_ON_INTERVAL_REPEAT_COUNT"
	var repeat_text = FuseLocalization.translate(repeat_text_key)
	if max_repeats > 0:
		repeat_text = FuseLocalization.translate_format("FUSE_EVENT_ON_INTERVAL_REPEAT_COUNT_FORMAT", {"count": max_repeats})

	# 自动开始文本
	var auto_text_key = "FUSE_EVENT_ON_INTERVAL_AUTO_START" if auto_start else "FUSE_EVENT_ON_INTERVAL_MANUAL_START"
	var auto_text = FuseLocalization.translate(auto_text_key)

	# 触发时机文本
	var trigger_text_key = "FUSE_EVENT_ON_INTERVAL_TRIGGER_ON_START" if trigger_on_start else "FUSE_EVENT_ON_INTERVAL_TRIGGER_AFTER_INTERVAL"
	var trigger_text = FuseLocalization.translate(trigger_text_key)

	# 停止条件文本
	var stop_condition_text = ""
	if stop_condition:
		stop_condition_text = FuseLocalization.translate_format("FUSE_EVENT_ON_INTERVAL_WITH_STOP_CONDITION", {
			"condition": stop_condition.get_description()
		})

	resource_name = FuseLocalization.translate_format("FUSE_EVENT_ON_INTERVAL_WITH_VARIABLE_RESOURCE_NAME", {
		"var": var_text,
		"scope": scope_text,
		"default": default_text,
		"init": init_text,
		"repeat": repeat_text,
		"auto": auto_text,
		"trigger": trigger_text,
		"stop_condition": stop_condition_text
	})

## 初始化事件监听（重写父类方法）
func initialize(owner_node: Node) -> void:
	# 验证 variable_name
	if variable_name.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_VARIABLE_NAME_EMPTY", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 验证 default_interval
	if default_interval < MIN_INTERVAL:
		_log_warning_localized("FUSE_EVENT_ON_INTERVAL_WITH_VARIABLE_DEFAULT_TOO_SMALL", {
			"default": default_interval,
			"min": MIN_INTERVAL
		})
		default_interval = MIN_INTERVAL

	# 调用父类初始化
	super.initialize(owner_node)

	# 如果启用自动初始化变量，设置默认值
	if initialize_variable and _runtime_instance_ref:
		_ensure_variable_exists(owner_node)

## 使用 RuntimeEventInstance 初始化事件（重写父类方法）
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	# 验证 variable_name
	if variable_name.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_VARIABLE_NAME_EMPTY", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 验证 default_interval
	if default_interval < MIN_INTERVAL:
		_log_warning_localized("FUSE_EVENT_ON_INTERVAL_WITH_VARIABLE_DEFAULT_TOO_SMALL", {
			"default": default_interval,
			"min": MIN_INTERVAL
		})
		default_interval = MIN_INTERVAL

	# 调用父类初始化
	super.initialize_with_runtime_instance(owner_node, runtime_instance)

	# 如果启用自动初始化变量，设置默认值
	if initialize_variable and _runtime_instance_ref:
		_ensure_variable_exists(owner_node)

## 确保变量存在（如果不存在则创建）
func _ensure_variable_exists(owner_node: Node) -> void:
	# 根据作用域类型初始化变量
	match variable_scope:
		BaseVariable.VariableScope.LOCAL:
			# LOCAL 作用域：写入 Trigger 节点的 meta 数据
			# 这是 Event 和 ExecutionContext 之间共享 LOCAL 变量的变通方案
			var meta_key = _get_local_variable_meta_key()
			if not owner_node.has_meta(meta_key):
				owner_node.set_meta(meta_key, default_interval)
				_log_debug_localized("FUSE_EVENT_ON_INTERVAL_WITH_VARIABLE_INITIALIZED", {
					"variable": variable_name,
					"value": default_interval
				})

		BaseVariable.VariableScope.SCOPE:
			# SCOPE 作用域：使用 ScopeVariableManager
			var scope = _get_scope_container(owner_node)
			if scope == null:
				# 如果没有作用域容器，创建一个并添加到节点
				scope = _create_scope_container(owner_node)

			if scope == null:
				return

			# 检查变量是否存在
			if not scope.has_variable(variable_name):
				# 设置默认值
				scope.set_variable(variable_name, default_interval)
				_log_debug_localized("FUSE_EVENT_ON_INTERVAL_WITH_VARIABLE_INITIALIZED", {
					"variable": variable_name,
					"value": default_interval
				})

		BaseVariable.VariableScope.GLOBAL:
			# GLOBAL 作用域：使用 GlobalVariableManager
			var manager = GlobalVariableManager.get_instance()
			if manager != null:
				var global_var = manager.get_global_variable(variable_name)
				if global_var == null:
					# 创建新的全局变量
					var new_var = BaseVariable.create(variable_name, default_interval, BaseVariable.VariableScope.GLOBAL)
					manager.register_global_variable(new_var)
					_log_debug_localized("FUSE_EVENT_ON_INTERVAL_WITH_VARIABLE_INITIALIZED", {
						"variable": variable_name,
						"value": default_interval
					})

## 获取下一次间隔时间（重写父类方法）
## 从变量读取间隔值，并确保不小于最小值
func _get_next_interval() -> float:
	var tracker = FusePerformanceTracker.get_instance()
	tracker.start_track("OnIntervalWithVariable._get_next_interval")

	var interval = _get_interval_from_variable()
	# 确保间隔不小于最小值
	var result = maxf(interval, MIN_INTERVAL)

	tracker.stop_track("OnIntervalWithVariable._get_next_interval")
	return result

## 从变量获取间隔值（根据 variable_scope 使用不同的获取方式）
func _get_interval_from_variable() -> float:
	var owner_node = _owner_node_ref
	if owner_node == null:
		_log_debug_localized("FUSE_EVENT_ON_INTERVAL_WITH_VARIABLE_USE_DEFAULT", {
			"variable": variable_name,
			"default": default_interval
		})
		return default_interval

	var value = null

	# 根据作用域类型获取变量值
	match variable_scope:
		BaseVariable.VariableScope.LOCAL:
			# LOCAL 作用域：从 Trigger 节点的 meta 数据获取
			# 这是 Event 和 ExecutionContext 之间共享 LOCAL 变量的变通方案
			var meta_key = _get_local_variable_meta_key()
			if owner_node.has_meta(meta_key):
				value = owner_node.get_meta(meta_key)

		BaseVariable.VariableScope.SCOPE:
			# SCOPE 作用域：从 ScopeVariableContainer 获取
			var scope = _get_scope_container(owner_node)
			if scope != null:
				value = scope.get_variable(variable_name, null)

		BaseVariable.VariableScope.GLOBAL:
			# GLOBAL 作用域：从 GlobalVariableManager 获取
			var manager = GlobalVariableManager.get_instance()
			if manager != null:
				var global_var = manager.get_global_variable(variable_name)
				if global_var != null and global_var is BaseVariable:
					value = global_var.get_value()

	# 检查是否获取到有效值
	if value != null:
		# 类型检查
		if value is float or value is int:
			var float_value = float(value)
			# 范围检查
			if float_value >= MIN_INTERVAL:
				_log_debug_localized("FUSE_EVENT_ON_INTERVAL_WITH_VARIABLE_GOT_VALUE", {
					"variable": variable_name,
					"value": float_value
				})
				return float_value
			else:
				_log_warning_localized("FUSE_EVENT_ON_INTERVAL_WITH_VARIABLE_VALUE_TOO_SMALL", {
					"variable": variable_name,
					"value": float_value,
					"min": MIN_INTERVAL
				})
				return default_interval
		else:
			_log_warning_localized("FUSE_EVENT_ON_INTERVAL_WITH_VARIABLE_INVALID_TYPE", {
				"variable": variable_name,
				"type": type_string(typeof(value))
			})
			return default_interval

	# 变量不存在或无效，使用默认值
	_log_debug_localized("FUSE_EVENT_ON_INTERVAL_WITH_VARIABLE_USE_DEFAULT", {
		"variable": variable_name,
		"default": default_interval
	})
	return default_interval

## 获取 LOCAL 变量的 meta 键名
func _get_local_variable_meta_key() -> String:
	return "local_variable_%s" % variable_name

## 获取作用域容器（使用 ScopeVariableManager）
func _get_scope_container(node: Node) -> ScopeVariableContainer:
	if node == null:
		return null

	var manager = ScopeVariableManager.get_instance()
	if manager == null:
		return null

	return manager.find_nearest_scope(node)

## 创建作用域容器并添加到节点
func _create_scope_container(node: Node) -> ScopeVariableContainer:
	if node == null:
		return null

	var scope = ScopeVariableContainer.new()
	scope.name = "ScopeVariables"
	scope.scope_id = node.get_instance_id()
	node.add_child(scope)

	_log_debug_localized("FUSE_EVENT_ON_INTERVAL_WITH_VARIABLE_SCOPE_CREATED", {
		"node": node.name
	})
	return scope

## 创建定时器（重写父类方法，使用 one-shot 模式以支持动态间隔）
func _create_timer(owner_node: Node):
	if not owner_node:
		return

	var owner_id = owner_node.get_instance_id()

	# 清理旧的 timer
	_cleanup_timer(owner_node)

	# 创建新的 timer
	var timer = Timer.new()
	timer.wait_time = _get_next_interval()
	timer.one_shot = true  # 🔧 使用 one-shot 模式，每次触发后手动设置新间隔
	timer.timeout.connect(_on_timer_timeout.bind(owner_node))
	owner_node.add_child(timer)

	# 保存连接信息
	_signal_connections[owner_id] = {
		"timer": timer,
		"owner": owner_node
	}

	# 🔧 初始化 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("current_repeat_count", 0)
		_runtime_instance_ref.set_runtime_state("is_completed", false)

## 定时器超时回调（重写父类方法，添加动态间隔更新）
func _on_timer_timeout(owner_node: Node):
	# 🔧 使用 RuntimeEventInstance 的状态
	var current_repeat_count = 0
	var is_running = false
	var is_completed = false

	if _runtime_instance_ref:
		current_repeat_count = _runtime_instance_ref.runtime_state.get("current_repeat_count", 0)
		is_running = _runtime_instance_ref.runtime_state.get("is_running", false)
		is_completed = _runtime_instance_ref.runtime_state.get("is_completed", false)

	# 检查是否达到最大重复次数
	if max_repeats > 0 and current_repeat_count >= max_repeats:
		# 停止定时器
		_cleanup_timer(owner_node)

		if _runtime_instance_ref:
			_runtime_instance_ref.set_runtime_state("is_running", false)
			_runtime_instance_ref.set_runtime_state("is_completed", true)

		_log_debug_localized("FUSE_LOG_EVENT_INTERVAL_MAX_REACHED", {"max_repeats": max_repeats})

		# 通知事件停止
		notify_stopped(STOP_REASON_MAX_REPEATS, {
			"repeat_count": current_repeat_count,
			"max_repeats": max_repeats
		})
		return

	# 递增计数
	current_repeat_count += 1
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("current_repeat_count", current_repeat_count)

	# 检查停止条件
	if stop_condition and _check_stop_condition(owner_node):
		# 停止定时器
		_cleanup_timer(owner_node)

		if _runtime_instance_ref:
			_runtime_instance_ref.set_runtime_state("is_running", false)
			_runtime_instance_ref.set_runtime_state("is_completed", true)

		_log_info_localized("FUSE_LOG_EVENT_INTERVAL_STOP_CONDITION_MET", {
			"repeat_count": current_repeat_count,
			"condition": stop_condition.get_description() if stop_condition else "unknown"
		})

		# 通知事件停止
		notify_stopped(STOP_REASON_CONDITION_MET, {
			"repeat_count": current_repeat_count,
			"condition": stop_condition.get_description() if stop_condition else "unknown"
		})
		return

	# 检查是否是最后一次触发
	var is_last_trigger = false
	if max_repeats > 0 and current_repeat_count >= max_repeats:
		is_last_trigger = true

		if _runtime_instance_ref:
			_runtime_instance_ref.set_runtime_state("is_running", false)
			_runtime_instance_ref.set_runtime_state("is_completed", true)

		var owner_id = owner_node.get_instance_id()
		if _signal_connections.has(owner_id):
			var conn_info = _signal_connections[owner_id]
			var timer = conn_info.get("timer")
			if timer:
				timer.stop()

	# 获取当前间隔值（从变量读取）
	var current_interval = _get_next_interval()

	_log_info_localized("FUSE_LOG_EVENT_INTERVAL_TRIGGERED", {
		"count": current_repeat_count,
		"interval_seconds": current_interval
	})

	# 更新触发统计
	if _runtime_instance_ref:
		_runtime_instance_ref.update_trigger_stats()

	# 创建上下文节点传递事件信息
	var context_node = Node.new()
	context_node.name = "IntervalContext"

	if emit_repeat_count:
		context_node.set_meta("repeat_count", current_repeat_count)

	context_node.set_meta("max_repeats", max_repeats)
	context_node.set_meta("is_completed", is_last_trigger)
	context_node.set_meta("is_last_trigger", is_last_trigger)
	context_node.set_meta("trigger", owner_node)

	triggered.emit(context_node)

	# 清理上下文节点
	context_node.queue_free()

	# 🔧 如果不是最后一次触发，使用动态间隔重新启动定时器
	if not is_last_trigger:
		var owner_id = owner_node.get_instance_id()
		if _signal_connections.has(owner_id):
			var conn_info = _signal_connections[owner_id]
			var timer = conn_info.get("timer")
			if timer and is_instance_valid(timer):
				var next_interval = _get_next_interval()  # 🔧 每次都重新从变量获取间隔
				timer.wait_time = next_interval
				timer.start()
				_log_debug_localized("FUSE_LOG_EVENT_INTERVAL_RANDOM_NEXT", {
					"next_interval": next_interval
				})

## 获取事件描述（重写父类方法）
func get_description() -> String:
	# 作用域文本
	var scope_text = ""
	match variable_scope:
		BaseVariable.VariableScope.LOCAL:
			scope_text = FuseLocalization.translate("FUSE_VARIABLE_SCOPE_LOCAL_STR")
		BaseVariable.VariableScope.SCOPE:
			scope_text = FuseLocalization.translate("FUSE_VARIABLE_SCOPE_SCOPE_STR")
		BaseVariable.VariableScope.GLOBAL:
			scope_text = FuseLocalization.translate("FUSE_VARIABLE_SCOPE_GLOBAL_STR")

	var var_text = FuseLocalization.translate_format(
		"FUSE_EVENT_ON_INTERVAL_WITH_VARIABLE_VAR",
		{"name": "%s [%s]" % [variable_name, scope_text]}
	)

	var repeat_text_key = ""
	if max_repeats == 0:
		repeat_text_key = "FUSE_EVENT_ON_INTERVAL_REPEAT_INFINITE"
	elif max_repeats == 1:
		repeat_text_key = "FUSE_EVENT_ON_INTERVAL_ONCE"
	else:
		repeat_text_key = "FUSE_EVENT_ON_INTERVAL_REPEAT_COUNT_FORMAT"

	var repeat_text = FuseLocalization.translate(repeat_text_key)
	if max_repeats > 1:
		repeat_text = FuseLocalization.translate_format("FUSE_EVENT_ON_INTERVAL_REPEAT_COUNT_FORMAT", {"count": max_repeats})

	var auto_text_key = "FUSE_EVENT_ON_INTERVAL_AUTO_START" if auto_start else "FUSE_EVENT_ON_INTERVAL_MANUAL_START"
	var auto_text = FuseLocalization.translate(auto_text_key)

	var init_text_key = "FUSE_EVENT_ON_INTERVAL_WITH_VARIABLE_INIT_ENABLED" if initialize_variable else "FUSE_EVENT_ON_INTERVAL_WITH_VARIABLE_INIT_DISABLED"
	var init_text = FuseLocalization.translate(init_text_key)

	var desc = FuseLocalization.translate_format("FUSE_EVENT_ON_INTERVAL_WITH_VARIABLE_DESC", {
		"var": var_text,
		"default": str(default_interval),
		"repeat": repeat_text,
		"auto": auto_text,
		"init": init_text
	})

	# 添加停止条件信息
	if stop_condition:
		desc += "\n" + FuseLocalization.translate_format("FUSE_EVENT_ON_INTERVAL_STOP_CONDITION_DESC", {
			"condition": stop_condition.get_description()
		})

	return desc

## 获取事件类型（重写父类方法）
func get_event_type() -> String:
	return "interval_with_variable"

## 验证事件配置（重写父类方法）
func validate() -> Array[String]:
	var errors: Array[String] = []

	# 调用父类验证
	errors.append_array(super.validate())

	# 验证 variable_name
	if variable_name.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_VARIABLE_NAME_EMPTY"))

	# 验证 default_interval
	if default_interval < MIN_INTERVAL:
		errors.append(FuseLocalization.translate("FUSE_EVENT_ON_INTERVAL_WITH_VARIABLE_ERROR_DEFAULT_TOO_SMALL"))

	return errors

## 获取默认运行时状态（继承自 OnInterval，无需修改）
func get_default_runtime_state() -> Dictionary:
	return super.get_default_runtime_state()

## 触发时自动提供的 LOCAL 变量
## 仅当 variable_scope == LOCAL 且 initialize_variable == true 时，
## 事件初始化阶段会创建 variable_name 到 owner_node meta（LOCAL 作用域）。
## 其他作用域（SCOPE/GLOBAL）不属于 LOCAL，不在此白名单。
func get_provided_local_variables() -> Array[String]:
	if variable_scope == BaseVariable.VariableScope.LOCAL and initialize_variable and not variable_name.is_empty():
		return [variable_name]
	return []

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_ON_INTERVAL_WITH_VARIABLE_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_LIFECYCLE"
	metadata.description_key = "FUSE_EVENT_ON_INTERVAL_WITH_VARIABLE_DESC"
	metadata.keywords = ["interval", "间隔", "variable", "变量", "timer", "定时器", "repeat", "重复", "dynamic", "动态"]
	metadata.builtin_icon = "Timer"
	return metadata
