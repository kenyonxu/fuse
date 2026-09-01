@tool
@icon("res://addons/fuse/icons/builtin/Time.png")
extends BaseInstruction
class_name AsyncInstructionTemplate

## 异步指令描述（简短说明指令的功能）
##
## 异步指令说明：
## - 使用定时器或 Tween 实现延迟效果
## - 使用 RuntimeInstructionInstance 架构管理运行时状态
## - 支持暂停/恢复
## - 不在 execute() 中调用 _on_execution_completed()

# =============================================
# 参数定义
# =============================================

# 目标节点路径（如果需要）
var target_node: NodePath = NodePath("")

# 延迟时间（秒）
var delay: float = 1.0

# =============================================
# 执行模式配置
# =============================================

# 🔧 关键：异步指令在 _init() 中覆盖 execution_mode
func _init():
	execution_mode = ExecutionMode.FORCE_ASYNC

# =============================================
# 元数据方法
# =============================================

## 获取指令元数据（必需）
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_XXX_NAME"
	metadata.category_key = "FUSE_CATEGORY_XXX"
	metadata.description_key = "FUSE_INSTRUCTION_XXX_DESC"
	metadata.keywords = ["keyword1", "keyword2", "keyword3"]
	metadata.builtin_icon = "Time"  # 异步指令通常使用时间相关图标
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	# 添加分类
	properties.append({
		name = "Timing",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 延迟时间
	properties.append({
		name = "delay",
		type = TYPE_FLOAT,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "0.0,60.0,0.1,or_greater",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 动态属性设置
func _set(property: StringName, value: Variant) -> bool:
	if property == "delay":
		delay = value
		_update_resource_name()
		return true
	return false

# =============================================
# 资源名称和描述
# =============================================

## 更新资源名称（必需）
func _update_resource_name():
	var parts = []

	parts.append("异步操作")

	if not target_node.is_empty():
		parts.append("'%s'" % target_node)

	parts.append("延迟 %.1f 秒" % delay)

	resource_name = " ".join(parts)

## 获取指令描述（必需）
func get_description() -> String:
	return "延迟 %.1f 秒后操作 %s" % [delay, str(target_node)]

# =============================================
# RuntimeInstructionInstance 支持
# =============================================

## 获取默认运行时状态
##
## 声明指令需要的运行时状态。每个 RuntimeInstructionInstance 有独立的状态副本。
func get_default_runtime_state() -> Dictionary:
	var state = super.get_default_runtime_state()
	state["timer"] = null
	state["is_running"] = false
	state["pause_remaining_time"] = 0.0
	state["current_timer_callback"] = null
	return state

## 使用运行时实例执行（推荐模式）
func execute_with_runtime_instance(runtime_instance: RuntimeInstructionInstance) -> bool:
	_start_execution(runtime_instance.execution_context)
	var state = runtime_instance.runtime_state

	# 验证参数
	if delay <= 0:
		_log_error_localized("FUSE_ERROR_INVALID_DELAY", {})
		set_error_localized("FUSE_ERROR_INVALID_DELAY", FuseError.ErrorType.VALIDATION_ERROR, {})
		runtime_instance._complete_execution()
		return true

	# 获取 SceneTree
	var scene_tree = Engine.get_main_loop()
	if not scene_tree:
		_log_error_localized("FUSE_ERROR_CANNOT_GET_SCENETREE", {})
		set_error_localized("FUSE_ERROR_CANNOT_GET_SCENETREE", FuseError.ErrorType.RUNTIME_ERROR, {})
		runtime_instance._complete_execution()
		return true

	# 创建定时器并存储到运行时状态
	var timer = scene_tree.create_timer(delay)
	state["timer"] = timer
	state["is_running"] = true

	# 使用闭包创建回调（避免 bind 泄漏）
	var callback = _create_timer_callback(runtime_instance)
	timer.timeout.connect(callback)
	runtime_instance.register_timer_callback(callback)
	state["current_timer_callback"] = callback

	_log_info("定时器已创建，延迟 %.1f 秒" % delay)

	return false  # 异步执行，等待回调

## 创建定时器回调（避免 bind 泄漏）
func _create_timer_callback(runtime_instance: RuntimeInstructionInstance) -> Callable:
	var callback = func():
		_on_runtime_timer_timeout(runtime_instance)
	return callback

## 定时器超时回调
func _on_runtime_timer_timeout(runtime_instance: RuntimeInstructionInstance):
	# 关键：检查实例是否仍然有效
	if not runtime_instance or runtime_instance.is_completed():
		return

	var state = runtime_instance.runtime_state

	# 清理运行时状态
	state["timer"] = null
	state["is_running"] = false

	_log_info("定时器超时，开始执行操作")

	# ============================================
	# 在这里执行延迟后的操作
	# ============================================

	# 执行你的指令逻辑...
	# var node = runtime_instance.execution_context.get_node(target_node)
	# ...

	# ============================================
	# 完成执行（不要手动 finished.emit()）
	# ============================================

	runtime_instance._complete_execution()

# =============================================
# 暂停/恢复处理（可选）
# =============================================

## 暂停处理
func on_runtime_pause(runtime_instance: RuntimeInstructionInstance) -> void:
	var state = runtime_instance.runtime_state
	if state.has("timer") and state["timer"]:
		var timer = state["timer"]
		if timer is SceneTreeTimer:
			# SceneTreeTimer 无法暂停，记录剩余时间
			var elapsed = Time.get_ticks_msec() / 1000.0 - state.get("wait_start_time", 0.0)
			var remaining = delay - elapsed
			state["pause_remaining_time"] = max(0.0, remaining)

			# 使用存储的回调引用断开原计时器
			var callback = state.get("current_timer_callback")
			if callback and timer.timeout.is_connected(callback):
				timer.timeout.disconnect(callback)

			state["timer"] = null
			state["current_timer_callback"] = null

## 恢复处理
func on_runtime_resume(runtime_instance: RuntimeInstructionInstance) -> void:
	var state = runtime_instance.runtime_state
	var remaining = state.get("pause_remaining_time", 0.0)

	if remaining > 0:
		var scene_tree = Engine.get_main_loop()
		if scene_tree:
			var timer = scene_tree.create_timer(remaining)
			state["timer"] = timer
			state["wait_start_time"] = Time.get_ticks_msec() / 1000.0

			var callback = _create_timer_callback(runtime_instance)
			timer.timeout.connect(callback)
			runtime_instance.register_timer_callback(callback)
			state["current_timer_callback"] = callback

	state["pause_remaining_time"] = 0.0

# =============================================
# 传统 execute() 回退（向后兼容）
# =============================================

## 执行指令（传统模式，向后兼容）
func execute(context: ExecutionContext):
	_start_execution(context)

	# 验证参数
	if delay <= 0:
		_log_error_localized("FUSE_ERROR_INVALID_DELAY", {})
		set_error_localized("FUSE_ERROR_INVALID_DELAY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 获取 SceneTree
	var scene_tree = Engine.get_main_loop()
	if not scene_tree:
		_log_error_localized("FUSE_ERROR_CANNOT_GET_SCENETREE", {})
		set_error_localized("FUSE_ERROR_CANNOT_GET_SCENETREE", FuseError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	# 创建定时器（经典方式，无 RuntimeInstance）
	var _timer = scene_tree.create_timer(delay)
	_timer.timeout.connect(_on_timer_timeout)

	_log_info("定时器已创建，延迟 %.1f 秒" % delay)

## 定时器超时回调（传统模式）
func _on_timer_timeout():
	_log_info("定时器超时，开始执行操作")
	# 执行延迟后的操作...
	finished.emit()

# =============================================
# 验证
# =============================================

## 验证指令参数（必需）
func validate() -> Array[String]:
	var errors = super.validate()

	if delay <= 0:
		errors.append("延迟时间必须大于 0")

	return errors

# =============================================
# 资源清理（必需）
# =============================================

## 清理资源
func _cleanup_resources():
	# RuntimeInstance 模式下在回调中清理
	# 传统模式下使用此方法
	_log_debug("资源已清理")

## 重置指令状态（可选）
func reset():
	super.reset()
	_cleanup_resources()
	_log_debug("指令状态已重置")

# =============================================
# 使用 Tween 的替代方案
# =============================================

## 如果需要使用 Tween 而不是定时器
## 在 execute_with_runtime_instance() 中：
#
## var tween = scene_tree.create_tween()
## if not tween:
## 	_log_error_localized("FUSE_ERROR_CANNOT_CREATE_TWEEN", {})
## 	return true
##
## tween.tween_method(_tween_callback.bind(param), from_value, to_value, duration)
## tween.finished.connect(_on_tween_completed)

## func _tween_callback(param: Variant, value: float):
## 	# 处理插值
## 	pass

## func _on_tween_completed():
## 	runtime_instance._complete_execution()
