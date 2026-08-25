@tool
@icon("res://addons/fuse/icons/builtin/Signals.png")
class_name WaitForSignal extends BaseInstruction

## 等待节点信号指令
##
## 暂停执行直到目标节点发出指定信号；信号参数以 event_<参数名> 局部变量
## 暴露给后续指令。超时（0 = 无限）后以 TIMEOUT 错误失败终止。
## 只等待未来发出的信号（connect 前已发出的不追认）。

## 目标节点路径（相对 Trigger/Runner 解析）
var target_node: NodePath = NodePath(""):
	set(value):
		target_node = value
		_update_resource_name()
		if Engine.is_editor_hint() and not target_node.is_empty():
			call_deferred("_editor_refresh_signals")

## 目标信号名称
var target_signal: String = "":
	set(value):
		target_signal = value
		_update_resource_name()
		notify_property_list_changed()

## 超时秒数（0 = 无限等待）
var timeout: float = 10.0

## 是否启用信号参数过滤（true 时仅匹配过滤条件的信号才结束等待）
var filter_signal_args: bool = false:
	set(value):
		filter_signal_args = value
		notify_property_list_changed()

## 参数过滤期望值（{参数名: 期望值}——键存在即参与过滤，按名匹配）
var arg_filter_values: Dictionary = {}:
	set(value):
		arg_filter_values = value
		_update_resource_name()

# 运行时状态
var _bound_node: Node = null
var _signal_info: SignalInfo = null
var _wait_timeout_timer: SceneTreeTimer = null
var _runtime_instance_ref: RuntimeInstructionInstance = null
var _execution_context: ExecutionContext = null

# 编辑器信号缓存（仅编辑器会话，不序列化）
var _editor_available_signals: Array = []

func _init():
	# 回调式异步（connect + 回调），源码检测无法识别，必须手动声明
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

	if not _setup_target(context):
		return  # _setup_target 内部已 set_error + finished

	# 非 ONE_SHOT：参数过滤下不匹配的信号须保持连接继续等待，
	# 匹配路径由 _on_target_signal_emitted 内 _disconnect_signal() 手动断开
	_bound_node.connect(target_signal, _on_target_signal_emitted)
	_start_timeout_timer()
	_log_debug("WaitForSignal: 等待信号 %s" % target_signal)

## ==================== 执行：Runtime 路径 ===================

func execute_with_runtime_instance(runtime_instance: RuntimeInstructionInstance) -> bool:
	_start_execution(runtime_instance.execution_context)
	_execution_context = runtime_instance.execution_context
	_runtime_instance_ref = runtime_instance

	if not _setup_target(runtime_instance.execution_context):
		# 错误同步到实例（runner 层 stop_on_error 据此发 execution_failed 并
		# 阻断后续指令），对齐 BaseInstruction.execute_with_runtime_instance 默认实现
		runtime_instance._has_error = true
		runtime_instance._error_message = get_error_message()
		runtime_instance._complete_execution()
		return true

	# 同 execute 路径：非 ONE_SHOT，匹配才断开（见 _on_target_signal_emitted）
	_bound_node.connect(target_signal, _on_target_signal_emitted)

	_start_runtime_timeout_timer(runtime_instance, timeout)

	return false  # 异步

## ==================== 完成回调 ===================

func _on_target_signal_emitted(...args) -> void:
	# 参数过滤：不匹配则保持连接继续等待（SignalInfo.matches_arg 类型安全）
	if filter_signal_args and not _check_signal_args(args):
		_log_debug("WaitForSignal: 信号 %s 参数不匹配，继续等待" % target_signal)
		return

	_disconnect_signal()
	_stop_timeout_timer()

	# 参数捕获：event_<参数名> 局部变量（SignalInfo 参数名，缺失兜底 arg%d）
	if _execution_context != null:
		var named: Dictionary = _signal_info.create_arg_context(args) if _signal_info else {}
		for key in named:
			_execution_context.set_variable("event_" + str(key), named[key])

	if _runtime_instance_ref != null and is_instance_valid(_runtime_instance_ref):
		_runtime_instance_ref._complete_execution()
	else:
		_on_execution_completed()

## 检查信号参数（与 OnTargetSignalEmit 同款 dict 按名语义；signal_info 取运行时缓存成员 _signal_info）
func _check_signal_args(args) -> bool:
	if _signal_info == null:
		return true  # 元数据缺失放行（fail-open，避免永久等待）
	if arg_filter_values.is_empty():
		return false
	var named: Dictionary = _signal_info.create_arg_context(args)
	for key in arg_filter_values:
		if not named.has(str(key)):
			return false
		if not SignalInfo.matches_arg(arg_filter_values[key], named[str(key)]):
			return false
	return true

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
	_disconnect_signal()
	_wait_timeout_timer = null
	set_error_localized("FUSE_ERROR_WAIT_FOR_SIGNAL_TIMEOUT", FuseError.ErrorType.TIMEOUT_ERROR, {})
	finished.emit()

func _on_runtime_timeout(runtime_instance: RuntimeInstructionInstance) -> void:
	if runtime_instance == null or not is_instance_valid(runtime_instance) or runtime_instance.is_completed():
		return
	_disconnect_signal()
	set_error_localized("FUSE_ERROR_WAIT_FOR_SIGNAL_TIMEOUT", FuseError.ErrorType.TIMEOUT_ERROR, {})
	# 超时错误同步到实例（同 _setup_target 失败分支），保证 runner 层
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

## ==================== 目标解析 ===================

func _setup_target(context: ExecutionContext) -> bool:
	var base_node: Node = context.trigger if context.trigger != null else context.target
	if base_node == null:
		set_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		finished.emit()
		return false

	# 多策略解析（相对路径兜底：起始节点失败时从场景根/按名递归查找），
	# 对齐 OnTargetSignalEmit 的运行时解析语义
	_bound_node = FuseNodeUtils.find_node_at_runtime(base_node, target_node)
	if _bound_node == null:
		set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(target_node)})
		finished.emit()
		return false

	if target_signal.is_empty() or not SignalManager.has_signal_named(_bound_node, target_signal):
		set_error_localized("FUSE_ERROR_SIGNAL_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"signal_name": target_signal})
		finished.emit()
		return false

	# 解析 SignalInfo（参数名捕获用）
	for sig_info in SignalManager.get_node_signals(_bound_node):
		if sig_info.name == target_signal:
			_signal_info = sig_info
			break
	return true

## ==================== 清理 ===================

func cancel() -> void:
	_disconnect_signal()
	_stop_timeout_timer()
	super.cancel()

func _cleanup_resources() -> void:
	_disconnect_signal()
	_stop_timeout_timer()
	_bound_node = null
	_signal_info = null
	_runtime_instance_ref = null
	_execution_context = null

func _disconnect_signal() -> void:
	if _bound_node != null and is_instance_valid(_bound_node) and _bound_node.is_connected(target_signal, _on_target_signal_emitted):
		_bound_node.disconnect(target_signal, _on_target_signal_emitted)

func _stop_timeout_timer() -> void:
	_wait_timeout_timer = null  # SceneTreeTimer 无法取消，回调侧以状态检查兜底

## ==================== 编辑器 ===================

func _editor_refresh_signals() -> void:
	_editor_available_signals.clear()
	var edited_root = EditorInterface.get_edited_scene_root() if Engine.is_editor_hint() else null
	if edited_root == null:
		notify_property_list_changed()
		return
	# 资源上下文解析：target_node 相对资源宿主（Trigger/Runner），直接从场景根
	# 解析 "../Sibling" 形态必然失败——这正是编辑器信号下拉不出现的根因
	var target = FuseNodeUtils.find_node_from_resource_context(edited_root, self, target_node)
	if target:
		_editor_available_signals = SignalManager.get_node_signals(target)
	notify_property_list_changed()

## 获取编辑器当前选中信号的信息（供 per-arg 过滤字段生成；运行时该缓存为空，运行时过滤走 _signal_info 成员）
func _get_editor_signal_info():
	if target_signal.is_empty():
		return null
	for sig_info in _editor_available_signals:
		if sig_info.name == target_signal:
			return sig_info
	return null

func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	# target_node：无条件声明（PresetValueCodec 按 STORAGE usage 序列化，
	# 缺声明会导致 preset 保存丢失该配置；声明方式参照 runner.gd）
	properties.append({
		"name": "target_node",
		"type": TYPE_NODE_PATH,
		"hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES,
		"hint_string": "Node",
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})
	# target_signal：双态（同 runner.gd signal_name 模式）——编辑器有信号
	# 缓存时下拉选择；否则文本输入。两态均带 STORAGE usage 保证可序列化。
	var signal_names: Array[String] = []
	for sig_info in _editor_available_signals:
		signal_names.append(sig_info.name)
	if not signal_names.is_empty():
		properties.append({
			"name": "target_signal",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": ",".join(signal_names),
			"usage": PROPERTY_USAGE_DEFAULT
		})
	else:
		properties.append({
			"name": "target_signal",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_NONE,
			"hint_string": "",
			"usage": PROPERTY_USAGE_DEFAULT
		})
	properties.append({
		"name": "timeout",
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0,120,0.1",
		"usage": PROPERTY_USAGE_DEFAULT
	})
	# 过滤开关与期望值字典：无条件声明（DEFAULT 含 STORAGE，保证 preset 序列化不丢失）
	properties.append({
		"name": "filter_signal_args",
		"type": TYPE_BOOL,
		"usage": PROPERTY_USAGE_DEFAULT
	})
	properties.append({
		"name": "arg_filter_values",
		"type": TYPE_DICTIONARY,
		"usage": PROPERTY_USAGE_DEFAULT
	})
	# 门控开启且编辑器有选中信号信息时，按参数名生成 per-arg 过滤字段
	if filter_signal_args:
		var sig_info = _get_editor_signal_info()
		if sig_info:
			properties.append_array(sig_info.get_arg_property_list())
	return properties

## 属性验证和显示控制（对齐 OnTargetSignalEmit 模式）
func _validate_property(property: Dictionary) -> void:
	# 门控关闭时隐藏 arg_filter_values（含 per-arg 子字段——它们仅门控开启时声明）
	# NO_EDITOR 而非 NONE：保留 STORAGE 位——preset AI schema 提取器与序列化
	# 均以 STORAGE 位为口径，NONE 会让 arg_filter_values 在任何状态下都不可见
	if not filter_signal_args and property.name == "arg_filter_values":
		property.usage = PROPERTY_USAGE_NO_EDITOR

## Inspector 子属性桥接（arg_filter_values/<参数名>）——引擎不支持 dict 子路径，手动分发
func _set(property: StringName, value: Variant) -> bool:
	var s := String(property)
	if s.begins_with("arg_filter_values/"):
		var key := s.substr("arg_filter_values/".length())
		if value == null:
			arg_filter_values.erase(key)
		else:
			arg_filter_values[key] = value
		# dict 原位修改不触发 arg_filter_values setter，补偿 resource_name 刷新
		_update_resource_name()
		return true
	return super._set(property, value)

func _get(property: StringName) -> Variant:
	var s := String(property)
	if s.begins_with("arg_filter_values/"):
		return arg_filter_values.get(s.substr("arg_filter_values/".length()))
	return null

## ==================== 元数据与校验 ===================

static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_WAIT_FOR_SIGNAL_NAME"
	metadata.category_key = "FUSE_CATEGORY_FLOW_CONTROL"
	metadata.description_key = "FUSE_INSTRUCTION_WAIT_FOR_SIGNAL_DESC"
	metadata.keywords = ["wait", "signal", "等待", "信号", "暂停", "suspend"]
	metadata.builtin_icon = "Signals"
	return metadata

func get_description() -> String:
	return "等待信号: %s::%s" % [str(target_node), target_signal]

func _update_resource_name() -> void:
	resource_name = "等待信号 %s::%s" % [str(target_node), target_signal]

func validate() -> Array[String]:
	var errors = super.validate()
	if target_node.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_SIGNAL_NODE_REQUIRED"))
	if target_signal.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_SIGNAL_SIGNAL_REQUIRED"))
	return errors

func reset() -> void:
	super.reset()
	_cleanup_resources()
