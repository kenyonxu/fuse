@tool
@icon("res://addons/fuse/icons/builtin/Signal.svg")
class_name WaitForEvent extends BaseInstruction

## 等待事件指令
##
## 暂停执行直到 FuseEventBus 上指定事件发出；事件 args 以 event_<键名> 局部变量
## 暴露给后续指令。超时（0 = 无限）后以 TIMEOUT 错误失败终止。
## 只等待未来发出的事件（订阅前已发出的不追认）。

## 要等待的事件名称（FuseEventBus 命名事件）
@export var event_name: String = "":
	set(value):
		event_name = value
		_update_resource_name()

## 超时秒数（0 = 无限等待）
var timeout: float = 10.0

# 运行时状态
var _subscription: FuseEventBus.Subscription = null
var _wait_timeout_timer: SceneTreeTimer = null
var _runtime_instance_ref: RuntimeInstructionInstance = null
var _execution_context: ExecutionContext = null

func _init():
	# 回调式异步（subscribe + 回调），源码检测无法识别，必须手动声明
	_is_synchronous_hint = false
	_sync_hint_manually_set = true

## 设置指令元数据（静态 metadata 模式下由 _get_instruction_metadata 提供）
func _setup_metadata() -> void:
	pass

## ==================== 执行：遗留路径 ====================

func execute(context: ExecutionContext) -> void:
	_runtime_instance_ref = null  # 跨路径复用资源时防止完成投递给旧 runtime 实例
	_start_execution(context)
	_execution_context = context

	if not _setup_subscription():
		return  # _setup_subscription 内部已 set_error + finished

	_start_timeout_timer()
	_log_debug("WaitForEvent: 等待事件 %s" % event_name)

## ==================== 执行：Runtime 路径 ===================

func execute_with_runtime_instance(runtime_instance: RuntimeInstructionInstance) -> bool:
	_start_execution(runtime_instance.execution_context)
	_execution_context = runtime_instance.execution_context
	_runtime_instance_ref = runtime_instance

	if not _setup_subscription():
		# 错误同步到实例（runner 层 stop_on_error 据此发 execution_failed 并
		# 阻断后续指令），对齐 BaseInstruction.execute_with_runtime_instance 默认实现
		runtime_instance._has_error = true
		runtime_instance._error_message = get_error_message()
		runtime_instance._complete_execution()
		return true

	# 超时计时器（暂停停表见 on_runtime_pause/on_runtime_resume）
	_start_runtime_timeout_timer(runtime_instance, timeout)

	return false  # 异步

## ==================== 完成回调 ===================

func _on_event_received(args: Dictionary) -> void:
	_unsubscribe()
	_stop_timeout_timer()

	# 参数捕获：event_<键名> 局部变量
	if _execution_context != null:
		for key in args:
			_execution_context.set_variable("event_" + str(key), args[key])

	if _runtime_instance_ref != null and is_instance_valid(_runtime_instance_ref):
		_runtime_instance_ref._complete_execution()
	else:
		_on_execution_completed()

## ==================== 超时 ===================

func _start_timeout_timer() -> void:
	if timeout <= 0.0:
		return
	var scene_tree = Engine.get_main_loop()
	if scene_tree:
		# 身份守卫：容器（IfElse/ForLoop/ForEach）以 reset+execute 复用本资源时，
		# 第 1 轮的陈旧计时器会在第 2 轮 RUNNING 期间触发，仅凭状态检查
		# （_on_timeout 的 RUNNING 守卫）无法区分轮次而伪超时；闭包捕获自身，
		# 仅当本计时器仍是当前一轮的计时器时才允许触发
		var t: SceneTreeTimer = scene_tree.create_timer(timeout)
		_wait_timeout_timer = t
		t.timeout.connect(func():
			if _wait_timeout_timer == t:
				_on_timeout()
		)

func _on_timeout() -> void:
	if execution_status != BaseInstruction.ExecutionStatus.RUNNING:
		return
	_unsubscribe()
	_wait_timeout_timer = null
	set_error_localized("FUSE_ERROR_WAIT_FOR_EVENT_TIMEOUT", FuseError.ErrorType.TIMEOUT_ERROR, {})
	finished.emit()

func _on_runtime_timeout(runtime_instance: RuntimeInstructionInstance) -> void:
	if runtime_instance == null or not is_instance_valid(runtime_instance) or runtime_instance.is_completed():
		return
	_unsubscribe()
	set_error_localized("FUSE_ERROR_WAIT_FOR_EVENT_TIMEOUT", FuseError.ErrorType.TIMEOUT_ERROR, {})
	# 超时错误同步到实例（同 _setup_subscription 失败分支），保证 runner 层
	# stop_on_error 生效：发 execution_failed 且不执行后续指令
	runtime_instance._has_error = true
	runtime_instance._error_message = get_error_message()
	runtime_instance._complete_execution()

## 创建 runtime 路径超时计时器（duration 允许传剩余时间，暂停恢复复用）
##
## 注：实例 cancel 侧的自动断开（_cleanup_runtime_resources）只作用于
## runtime_state["timer"] 键的计时器，本指令未写该键——超时回调的实际安全性
## 来自 _on_runtime_timeout 开头的 is_completed 守卫（实例进入终态后陈旧触发
## 无害），register_timer_callback 仅作连接追踪，不提供清理保证。
func _start_runtime_timeout_timer(runtime_instance: RuntimeInstructionInstance, duration: float) -> void:
	if duration <= 0.0:
		return
	var scene_tree = Engine.get_main_loop()
	if scene_tree == null:
		return
	var state = runtime_instance.runtime_state
	var callback = func(): _on_runtime_timeout(runtime_instance)
	var t: SceneTreeTimer = scene_tree.create_timer(duration)
	_wait_timeout_timer = t
	state["wait_timeout_timer"] = t
	state["current_timeout_callback"] = callback
	state["timeout_start_time"] = Time.get_ticks_msec() / 1000.0
	t.timeout.connect(callback)
	runtime_instance.register_timer_callback(callback)

## ==================== 暂停/恢复（runtime 路径停表）====================

## 暂停：SceneTreeTimer 无法暂停，记录剩余超时并断开计时器回调
func on_runtime_pause(runtime_instance: RuntimeInstructionInstance) -> void:
	var state = runtime_instance.runtime_state
	var timer = state.get("wait_timeout_timer")
	if timer is SceneTreeTimer:
		var elapsed: float = Time.get_ticks_msec() / 1000.0 - state.get("timeout_start_time", 0.0)
		state["pause_remaining_timeout"] = max(0.0, timeout - elapsed)
		var callback = state.get("current_timeout_callback")
		if callback and timer.timeout.is_connected(callback):
			timer.timeout.disconnect(callback)
		state["wait_timeout_timer"] = null
		state["current_timeout_callback"] = null
		_wait_timeout_timer = null

## 恢复：为暂停时的剩余超时重建计时器（复用身份安全路径：新计时器经
## state["wait_timeout_timer"] 重新登记，旧计时器已断开不再触发）
func on_runtime_resume(runtime_instance: RuntimeInstructionInstance) -> void:
	var state = runtime_instance.runtime_state
	var remaining: float = state.get("pause_remaining_timeout", 0.0)
	if remaining > 0.0:
		_start_runtime_timeout_timer(runtime_instance, remaining)
	state["pause_remaining_timeout"] = 0.0

## ==================== 订阅管理 ===================

func _setup_subscription() -> bool:
	if event_name.is_empty():
		set_error_localized("FUSE_ERROR_EVENT_NAME_EMPTY", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		finished.emit()
		return false

	var bus = Engine.get_main_loop().root.get_node_or_null("FuseEventBus")
	if bus == null:
		set_error_localized("FUSE_ERROR_EVENT_BUS_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		finished.emit()
		return false

	_subscription = bus.subscribe(event_name, _on_event_received)
	return true

## ==================== 清理 ===================

func cancel() -> void:
	_unsubscribe()
	_stop_timeout_timer()
	super.cancel()

func _cleanup_resources() -> void:
	_unsubscribe()
	_stop_timeout_timer()
	_subscription = null
	_runtime_instance_ref = null
	_execution_context = null

func _unsubscribe() -> void:
	if _subscription != null:
		var bus = Engine.get_main_loop().root.get_node_or_null("FuseEventBus")
		if bus != null:
			bus.unsubscribe(_subscription)
		_subscription = null

func _stop_timeout_timer() -> void:
	_wait_timeout_timer = null  # SceneTreeTimer 无法取消，回调侧以状态检查兜底

## ==================== 编辑器 ===================

func _get_property_list() -> Array[Dictionary]:
	# event_name 为 @export 纯文本属性（无下拉），此处只声明 timeout 的 range hint
	var properties: Array[Dictionary] = []
	properties.append({
		"name": "timeout",
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0,120,0.1",
		"usage": PROPERTY_USAGE_DEFAULT
	})
	return properties

## ==================== 元数据与校验 ===================

static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_WAIT_FOR_EVENT_NAME"
	metadata.category_key = "FUSE_CATEGORY_FLOW_CONTROL"
	metadata.description_key = "FUSE_INSTRUCTION_WAIT_FOR_EVENT_DESC"
	metadata.keywords = ["wait", "event", "bus", "等待", "事件"]
	metadata.builtin_icon = "Signal"
	return metadata

func get_description() -> String:
	return "等待事件: %s" % event_name

func _update_resource_name() -> void:
	resource_name = "等待事件 %s" % event_name

func validate() -> Array[String]:
	var errors = super.validate()
	if event_name.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_EVENT_NAME_EMPTY"))
	return errors

func reset() -> void:
	super.reset()
	_cleanup_resources()
