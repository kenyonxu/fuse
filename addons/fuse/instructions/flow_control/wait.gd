@tool
@icon("res://addons/fuse/icons/builtin/Time.png")
extends BaseInstruction
class_name Wait

## 等待指令
##
## 一个异步等待指令，用于测试异步执行和超时功能。
## 可以模拟需要时间的操作，如网络请求、动画播放等。
## 支持直接设置等待时间或从变量中获取等待时间。

## 时间值来源
enum ValueSource {
	DIRECT,     ## 直接设置等待时间
	VARIABLE    ## 从变量获取等待时间
}

## 作用域来源（仅当 time_scope == SCOPE 时使用）
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

# 关键：实现这个静态方法，用于指令选择器
static func _get_instruction_metadata() -> InstructionMetadata:
	metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_WAIT_NAME"
	metadata.category_key = "FUSE_CATEGORY_FLOW_CONTROL"
	metadata.description_key = "FUSE_INSTRUCTION_WAIT_DESC"
	# 正确初始化 Array[String] 类型
	metadata.keywords = ["等待", "延时", "异步", "计时", "暂停", "wait", "delay", "async", "timer", "pause"]
	# 设置指令选择器图标
	metadata.builtin_icon = "Time"
	return metadata

## 时间值来源
var value_source: ValueSource = ValueSource.DIRECT:
	set(value):
		value_source = value
		_update_resource_name()
		notify_property_list_changed()

## 直接设置的等待时间（秒）
var wait_time: float = 1.0:
	set(value):
		wait_time = value
		_update_resource_name()

## 等待时间变量名（当 value_source == VARIABLE 时使用）
var wait_time_variable: String = "":
	set(value):
		wait_time_variable = value
		_update_resource_name()

## 等待时间变量作用域
var time_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		time_scope = value
		_update_resource_name()
		notify_property_list_changed()

## 作用域来源（仅当 time_scope == SCOPE 时使用）
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

## 内部计时器
var _timer: SceneTreeTimer

func _init():
	# 🔧 关键修复：明确声明此指令是异步的
	# Wait 指令使用回调机制（信号连接）而非 await，所以源码检测无法正确识别
	_is_synchronous_hint = false
	_sync_hint_manually_set = true

## 设置指令元数据
func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	# Time Settings 分类
	properties.append({
		name = "Time Settings",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 时间值来源
	properties.append({
		name = "value_source",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Direct,Variable",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if value_source == ValueSource.DIRECT:
		# 直接设置的等待时间
		properties.append({
			name = "wait_time",
			type = TYPE_FLOAT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.1,60.0,0.1,or_greater",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
	else:
		# Variable 分类
		properties.append({
			name = "Variable",
			type = TYPE_NIL,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_CATEGORY
		})

		# 等待时间变量名
		properties.append({
			name = "wait_time_variable",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 等待时间变量作用域
		properties.append({
			name = "time_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 只在 time_scope == SCOPE 时显示 ScopeSource 配置
		if time_scope == BaseVariable.VariableScope.SCOPE:
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
	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_WAIT_RESOURCE_BASE"))

	if value_source == ValueSource.DIRECT:
		parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_WAIT_TIME_FORMAT", {"time": "%.1f" % wait_time}))
	else:
		if wait_time_variable.is_empty():
			parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_WAIT_NO_VARIABLE"))
		else:
			var scope_str = _get_scope_source_string()
			parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_WAIT_FROM_VARIABLE", {
				"variable": wait_time_variable,
				"scope": scope_str
			}))

	resource_name = " ".join(parts)

## 获取作用域来源字符串
func _get_scope_source_string() -> String:
	match time_scope:
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

## 执行指令
func execute(context: ExecutionContext):
	# 调用基类的执行初始化方法
	_start_execution(context)

	_log_debug_localized("FUSE_LOG_INSTRUCTION_START", {"instruction": "Wait"})

	# 获取实际等待时间
	var actual_wait_time: float = 0.0

	if value_source == ValueSource.DIRECT:
		actual_wait_time = wait_time
	else:
		# 从变量获取等待时间
		if wait_time_variable.is_empty():
			_log_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", {})
			set_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
			finished.emit()
			return

		# 根据作用域来源获取变量值
		var var_value: Variant
		if time_scope == BaseVariable.VariableScope.SCOPE:
			match scope_source:
				ScopeSource.NEAREST:
					var_value = VariableOperations.get_variable(context, wait_time_variable, BaseVariable.VariableScope.SCOPE, null)
				_:
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

					var_value = scope_container.get_variable(wait_time_variable, null)
		else:
			var_value = VariableOperations.get_variable(context, wait_time_variable, time_scope, null)

		# 检查变量是否存在
		if var_value == null:
			_log_error_localized("FUSE_ERROR_VAR_NOT_FOUND", {"name": wait_time_variable})
			set_error_localized("FUSE_ERROR_VAR_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"name": wait_time_variable})
			finished.emit()
			return

		# 转换为浮点数
		actual_wait_time = TypeConverter.safe_convert_to_float(var_value)

	# 检查等待时间是否有效（允许 0 秒等待，会立即继续执行）
	if actual_wait_time < 0:
		_log_error_localized("FUSE_ERROR_INVALID_PARAMETER", {"name": "wait_time", "value": str(actual_wait_time)})
		set_error_localized("FUSE_ERROR_INVALID_PARAMETER", FuseError.ErrorType.VALIDATION_ERROR, {"name": "wait_time", "value": str(actual_wait_time)})
		finished.emit()
		return

	# 如果提供了执行上下文，输出等待信息
	if context:
		var wait_message = FuseLocalization.translate_format("FUSE_LOG_WAITING_START", {"duration": "%.2f" % actual_wait_time})
		context.print_message(wait_message)

	# 创建计时器进行异步等待
	var scene_tree = Engine.get_main_loop()
	if scene_tree:
		_timer = scene_tree.create_timer(actual_wait_time)
		_timer.timeout.connect(_on_timer_timeout)
		_log_debug_localized("FUSE_INSTRUCTION_WAIT_TIMER_STARTED", {})
	else:
		_log_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", {"node": "SceneTree"})
		set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"node": "SceneTree"})
		finished.emit()

## 计时器超时回调
func _on_timer_timeout():
	_log_debug_localized("FUSE_LOG_WAITING_COMPLETE", {})

	# 清理计时器
	_timer = null

	# 标记指令完成
	_on_execution_completed()

## 获取指令描述
func get_description() -> String:
	if value_source == ValueSource.DIRECT:
		return FuseLocalization.translate_format("FUSE_INSTRUCTION_WAIT_DYNAMIC_DESC", {"time": "%.2f" % wait_time})
	else:
		var scope_str = _get_scope_source_string()
		return FuseLocalization.translate_format("FUSE_INSTRUCTION_WAIT_VARIABLE_DESC", {
			"variable": wait_time_variable if not wait_time_variable.is_empty() else FuseLocalization.translate("FUSE_VARIABLE_UNNAMED"),
			"scope": scope_str
		})

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()

	# 验证变量模式
	if value_source == ValueSource.VARIABLE:
		if wait_time_variable.is_empty():
			errors.append(FuseLocalization.translate("FUSE_ERROR_VAR_NAME_EMPTY"))

		# 验证 SCOPE 作用域需要 ScopeVariableManager
		if time_scope == BaseVariable.VariableScope.SCOPE:
			var manager = ScopeVariableManager.get_instance()
			if manager == null:
				errors.append(FuseLocalization.translate("FUSE_ERROR_SCOPE_MANAGER_NOT_FOUND"))

			# 验证 ScopeSource 相关参数
			var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
			errors.append_array(VariableScopeUtils.validate_scope_source_params(
				utils_scope_source,
				custom_scope_id,
				target_node_path
			))
	else:
		# 直接模式验证等待时间（允许 0 秒等待）
		if wait_time < 0:
			errors.append(FuseLocalization.translate("FUSE_INSTRUCTION_WAIT_ERROR_INVALID_TIME"))

	return errors

## 验证属性可见性
func _validate_property(property: Dictionary) -> void:
	# 只在 SCOPE 作用域时验证 ScopeSource 相关属性
	if value_source == ValueSource.VARIABLE and time_scope == BaseVariable.VariableScope.SCOPE:
		VariableScopeUtils.validate_scope_source_property(property, scope_source as VariableScopeUtils.ScopeSource)
	else:
		# 非 SCOPE 作用域时隐藏 ScopeSource 相关属性
		if property.name in ["scope_source", "custom_scope_id", "target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR

## 取消指令执行
func cancel():
	if _timer:
		# 在 Godot 4 中，SceneTreeTimer 无法直接取消
		# 我们只能断开连接并清理引用
		if _timer.timeout.is_connected(_on_timer_timeout):
			_timer.timeout.disconnect(_on_timer_timeout)
		_timer = null
		_log_debug_localized("FUSE_LOG_INSTRUCTION_CANCELLED", {"instruction": "Wait"})

	super.cancel()

## 资源清理
func _cleanup_resources():
	super._cleanup_resources()

	if _timer:
		if _timer.timeout.is_connected(_on_timer_timeout):
			_timer.timeout.disconnect(_on_timer_timeout)
		_timer = null
		_log_debug_localized("FUSE_INSTRUCTION_WAIT_CLEANUP_COMPLETE", {})

## ============================================================
## 运行时实例模式支持（RuntimeInstructionInstance 架构）
## ============================================================

## 获取默认运行时状态
##
## 声明 Wait 指令需要的运行时状态。
## 这些状态会在 RuntimeInstructionInstance 初始化时被复制。
func get_default_runtime_state() -> Dictionary:
	var state = super.get_default_runtime_state()
	state["timer"] = null  # 每个 RuntimeInstance 有自己的 timer
	state["wait_time"] = wait_time  # 复制配置值
	state["remaining_time"] = 0.0
	state["pause_remaining_time"] = 0.0  # 暂停时剩余时间
	state["current_timer_callback"] = null  # 存储当前计时器回调引用（用于暂停时断开）
	return state

## 使用运行时实例执行（推荐模式）
##
## 这种模式下，所有状态存储在 runtime_instance.runtime_state 中，
## 确保多个执行实例互不干扰。
##
## 使用 runtime_instance 管理信号连接，避免 bind 泄漏
func execute_with_runtime_instance(runtime_instance: RuntimeInstructionInstance) -> bool:
	_start_execution(runtime_instance.execution_context)

	_log_debug_localized("FUSE_LOG_INSTRUCTION_START", {"instruction": "Wait"})

	# 获取运行时状态
	var state = runtime_instance.runtime_state

	# 获取等待时间
	var actual_wait_time: float = _get_wait_time(runtime_instance.execution_context)

	if actual_wait_time < 0:
		_log_error_localized("FUSE_ERROR_INVALID_PARAMETER", {"name": "wait_time", "value": str(actual_wait_time)})
		set_error_localized("FUSE_ERROR_INVALID_PARAMETER", FuseError.ErrorType.VALIDATION_ERROR, {"name": "wait_time", "value": str(actual_wait_time)})
		# 错误同步到实例（runner 层 stop_on_error 据此发 execution_failed 并
		# 阻断后续指令），对齐 wait_for_signal 的同步模式
		runtime_instance._has_error = true
		runtime_instance._error_message = get_error_message()
		runtime_instance._complete_execution()
		return true

	# 输出等待信息
	if runtime_instance.execution_context:
		var wait_message = FuseLocalization.translate_format("FUSE_LOG_WAITING_START", {"duration": "%.2f" % actual_wait_time})
		runtime_instance.execution_context.print_message(wait_message)

	# 创建计时器并存储到运行时状态
	var scene_tree = Engine.get_main_loop()
	if scene_tree:
		var timer = scene_tree.create_timer(actual_wait_time)
		state["timer"] = timer  # 存储到独立的运行时状态
		state["is_running"] = true
		state["wait_start_time"] = Time.get_ticks_msec() / 1000.0
		state["actual_wait_time"] = actual_wait_time

		# 使用 Callable 并注册到 runtime_instance
		var callback = _create_timer_callback(runtime_instance)
		timer.timeout.connect(callback)
		runtime_instance.register_timer_callback(callback)
		state["current_timer_callback"] = callback  # 存储引用，用于暂停时断开

		_log_debug_localized("FUSE_INSTRUCTION_WAIT_TIMER_STARTED", {})
		return false  # 异步执行
	else:
		_log_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", {"node": "SceneTree"})
		set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"node": "SceneTree"})
		# 错误同步到实例（runner 层 stop_on_error 据此发 execution_failed 并
		# 阻断后续指令），对齐 wait_for_signal 的同步模式
		runtime_instance._has_error = true
		runtime_instance._error_message = get_error_message()
		runtime_instance._complete_execution()
		return true

## 创建计时器回调（避免 bind）
##
## 使用 Callable 和闭包，但存储引用以便清理
func _create_timer_callback(runtime_instance: RuntimeInstructionInstance) -> Callable:
	var callback = func():
		_on_runtime_timer_timeout(runtime_instance)
	return callback

## 运行时计时器超时回调
##
## 检查实例是否仍然有效，然后完成执行
func _on_runtime_timer_timeout(runtime_instance: RuntimeInstructionInstance):
	# 检查实例是否仍然有效
	if not runtime_instance or runtime_instance.is_completed():
		return

	var state = runtime_instance.runtime_state

	_log_debug_localized("FUSE_LOG_WAITING_COMPLETE", {})

	# 清理运行时状态
	state["timer"] = null
	state["is_running"] = false

	# 标记完成
	runtime_instance._complete_execution()

## 暂停处理
##
## 当运行时实例被暂停时，记录剩余时间并断开原计时器
func on_runtime_pause(runtime_instance: RuntimeInstructionInstance) -> void:
	var state = runtime_instance.runtime_state
	if state.has("timer") and state["timer"]:
		var timer = state["timer"]
		if timer is SceneTreeTimer:
			# SceneTreeTimer 无法暂停，记录剩余时间
			var elapsed = Time.get_ticks_msec() / 1000.0 - state.get("wait_start_time", 0.0)
			var remaining = state.get("actual_wait_time", 0.0) - elapsed
			state["pause_remaining_time"] = max(0.0, remaining)

			# 使用存储的回调引用断开原计时器（关键修复！）
			var callback = state.get("current_timer_callback")
			if callback and timer.timeout.is_connected(callback):
				timer.timeout.disconnect(callback)

			state["timer"] = null
			state["current_timer_callback"] = null  # 清除回调引用

## 恢复处理
##
## 当运行时实例被恢复时，为剩余时间创建新计时器
func on_runtime_resume(runtime_instance: RuntimeInstructionInstance) -> void:
	var state = runtime_instance.runtime_state
	var remaining = state.get("pause_remaining_time", 0.0)

	if remaining > 0:
		# 创建新计时器用于剩余时间
		var scene_tree = Engine.get_main_loop()
		if scene_tree:
			var timer = scene_tree.create_timer(remaining)
			state["timer"] = timer
			state["wait_start_time"] = Time.get_ticks_msec() / 1000.0
			state["actual_wait_time"] = remaining

			var callback = _create_timer_callback(runtime_instance)
			timer.timeout.connect(callback)
			runtime_instance.register_timer_callback(callback)
			state["current_timer_callback"] = callback  # 存储回调引用

	state["pause_remaining_time"] = 0.0

## 获取等待时间（提取为独立方法）
##
## 根据配置获取实际等待时间，支持直接设置和变量模式
func _get_wait_time(context: ExecutionContext) -> float:
	if value_source == ValueSource.DIRECT:
		return wait_time
	else:
		# 从变量获取等待时间
		if wait_time_variable.is_empty():
			return -1.0

		var var_value: Variant
		if time_scope == BaseVariable.VariableScope.SCOPE:
			match scope_source:
				ScopeSource.NEAREST:
					var_value = VariableOperations.get_variable(context, wait_time_variable, BaseVariable.VariableScope.SCOPE, null)
				_:
					var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
					var scope_container = VariableScopeUtils.get_scope_container_by_source(
						context,
						utils_scope_source,
						custom_scope_id,
						target_node_path
					)

					if scope_container == null:
						return -1.0

					var_value = scope_container.get_variable(wait_time_variable, null)
		else:
			var_value = VariableOperations.get_variable(context, wait_time_variable, time_scope, null)

		if var_value == null:
			return -1.0

		return TypeConverter.safe_convert_to_float(var_value)

