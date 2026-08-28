@tool
@icon("res://addons/fuse/icons/builtin/PlayCustom.png")
extends BaseInstruction
class_name ChangeScene

## 切换场景

# 目标场景路径
var scene_path: String = "":
	set(value):
		scene_path = value
		_update_resource_name()

# 延迟切换时间（秒）
var delay: float = 0.0:
	set(value):
		delay = value
		_update_resource_name()

# 定时器
var _timer: SceneTreeTimer = null

func _init():
	# 🔧 关键修复：明确声明此指令是异步的
	# ChangeScene 指令使用回调机制（信号连接）而非 await，所以源码检测无法正确识别
	_is_synchronous_hint = false
	_sync_hint_manually_set = true

## 获取指令元数据（用于指令选择器）
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_CHANGE_SCENE_NAME"
	metadata.category_key = "FUSE_CATEGORY_SCENE_MANAGEMENT"
	metadata.description_key = "FUSE_INSTRUCTION_CHANGE_SCENE_DESC"
	metadata.keywords = ["change scene", "load scene", "switch", "transition", "切换", "加载"]
	metadata.builtin_icon = "PlayCustom"
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	# Scene 分类
	properties.append({
		name = "Scene",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 场景路径
	properties.append({
		name = "scene_path",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_FILE,
		hint_string = "*.tscn,*.scn",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 延迟时间
	properties.append({
		name = "delay",
		type = TYPE_FLOAT,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "0,10,0.1,or_greater",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 更新资源名称
func _update_resource_name():
	var parts = []

	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_CHANGE_SCENE_RESOURCE_NAME"))

	if not scene_path.is_empty():
		parts.append("'%s'" % FuseNodeUtils.get_path_display_name(scene_path))
	else:
		parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_CHANGE_SCENE_NO_SCENE"))

	if delay > 0.0:
		var delay_template = FuseLocalization.translate("FUSE_INSTRUCTION_CHANGE_SCENE_DELAY")
		parts.append("(" + delay_template.format({"delay": "%.1f" % delay}) + ")")

	resource_name = " ".join(parts)

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	# 验证场景路径
	if scene_path.is_empty():
		_log_error_localized("FUSE_ERROR_SCENE_PATH_EMPTY", {})
		set_error_localized("FUSE_ERROR_SCENE_PATH_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 验证场景文件是否存在
	if not ResourceLoader.exists(scene_path):
		_log_error_localized("FUSE_ERROR_SCENE_NOT_EXISTS", {
			"scene_path": scene_path
		})
		set_error_localized("FUSE_ERROR_SCENE_NOT_EXISTS", FuseError.ErrorType.RUNTIME_ERROR, {
			"scene_path": scene_path
		})
		finished.emit()
		return

	if delay <= 0.0:
		# 立即切换
		_change_scene()
	else:
		# 延迟切换（异步）
		var scene_tree = Engine.get_main_loop()
		if scene_tree:
			_timer = scene_tree.create_timer(delay)
			_timer.timeout.connect(_on_timer_timeout)
			_log_info_localized("FUSE_INFO_CHANGE_SCENE_DELAYED", {
				"delay": "%.1f" % delay,
				"scene_path": scene_path
			})
		else:
			_log_error_localized("FUSE_ERROR_CANNOT_CREATE_TIMER", {})
			finished.emit()

## 切换场景
func _change_scene() -> void:
	var scene_tree = Engine.get_main_loop()
	if not scene_tree:
		_log_error_localized("FUSE_ERROR_CANNOT_GET_SCENETREE", {})
		finished.emit()
		return

	# 经 EventBus 广播切换预告——OnSceneAboutToChange 订阅此事件
	# （SceneTree 无原生切换前信号，此前事件挂在幻觉信号名上从未触发过）
	var _bus: Node = scene_tree.root.get_node_or_null("FuseEventBus")
	if _bus:
		_bus.send_event("Fuse_SceneAboutToChange", {"scene_path": scene_path})
	var error_code = scene_tree.change_scene_to_file(scene_path)

	if error_code != OK:
		_log_error_localized("FUSE_ERROR_FAILED_CHANGE_SCENE", {
			"scene_path": scene_path,
			"error": error_string(error_code)
		})
		set_error_localized("FUSE_ERROR_FAILED_CHANGE_SCENE", FuseError.ErrorType.RUNTIME_ERROR, {
			"scene_path": scene_path,
			"error": error_string(error_code)
		})
		finished.emit()
		return

	_log_info_localized("FUSE_INFO_CHANGE_SCENE_SUCCESS", {
		"scene_path": scene_path
	})
	_on_execution_completed()

## 定时器超时回调
func _on_timer_timeout() -> void:
	_change_scene()

## 清理资源
func _cleanup_resources() -> void:
	if _timer and is_instance_valid(_timer):
		if _timer.timeout.is_connected(_on_timer_timeout):
			_timer.timeout.disconnect(_on_timer_timeout)
		_timer = null

## ============================================================
## 运行时实例模式支持（RuntimeInstructionInstance 架构）
## ============================================================

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var state = super.get_default_runtime_state()
	state["timer"] = null
	state["timer_callback"] = null
	state["is_running"] = false
	state["remaining_time"] = 0.0  # 用于暂停时记录剩余时间
	state["start_time"] = 0.0     # 用于计算剩余时间
	return state

## 使用运行时实例执行
func execute_with_runtime_instance(runtime_instance: RuntimeInstructionInstance) -> bool:
	_start_execution(runtime_instance.execution_context)

	var state = runtime_instance.runtime_state

	# 验证场景路径
	if scene_path.is_empty():
		_log_error_localized("FUSE_ERROR_SCENE_PATH_EMPTY", {})
		set_error_localized("FUSE_ERROR_SCENE_PATH_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		runtime_instance._complete_execution()
		return true

	# 验证场景文件是否存在
	if not ResourceLoader.exists(scene_path):
		_log_error_localized("FUSE_ERROR_SCENE_NOT_EXISTS", {"scene_path": scene_path})
		set_error_localized("FUSE_ERROR_SCENE_NOT_EXISTS", FuseError.ErrorType.RUNTIME_ERROR, {"scene_path": scene_path})
		runtime_instance._complete_execution()
		return true

	if delay <= 0.0:
		# 立即切换
		_change_scene_runtime(runtime_instance)
		return true
	else:
		# 延迟切换（异步）
		var scene_tree = Engine.get_main_loop()
		if scene_tree:
			var timer = scene_tree.create_timer(delay)
			state["timer"] = timer
			state["is_running"] = true
			state["start_time"] = Time.get_ticks_msec() / 1000.0
			state["remaining_time"] = delay

			var callback = _create_timer_callback(runtime_instance)
			timer.timeout.connect(callback, CONNECT_ONE_SHOT)
			runtime_instance.register_timer_callback(callback)
			state["timer_callback"] = callback

			_log_info_localized("FUSE_INFO_CHANGE_SCENE_DELAYED", {
				"delay": "%.1f" % delay,
				"scene_path": scene_path
			})
			return false
		else:
			_log_error_localized("FUSE_ERROR_CANNOT_CREATE_TIMER", {})
			runtime_instance._complete_execution()
			return true

## 创建定时器回调
func _create_timer_callback(runtime_instance: RuntimeInstructionInstance) -> Callable:
	var callback = func():
		_on_timer_timeout_runtime(runtime_instance)
	return callback

## 定时器超时回调（运行时实例版本）
func _on_timer_timeout_runtime(runtime_instance: RuntimeInstructionInstance) -> void:
	if not runtime_instance or runtime_instance.is_completed():
		return

	var state = runtime_instance.runtime_state
	state["timer"] = null
	state["timer_callback"] = null
	state["is_running"] = false

	_change_scene_runtime(runtime_instance)

## 切换场景（运行时实例版本）
func _change_scene_runtime(runtime_instance: RuntimeInstructionInstance) -> void:
	var scene_tree = Engine.get_main_loop()
	if not scene_tree:
		_log_error_localized("FUSE_ERROR_CANNOT_GET_SCENETREE", {})
		runtime_instance._complete_execution()
		return

	# 经 EventBus 广播切换预告——OnSceneAboutToChange 订阅此事件
	# （SceneTree 无原生切换前信号，此前事件挂在幻觉信号名上从未触发过）
	var _bus: Node = scene_tree.root.get_node_or_null("FuseEventBus")
	if _bus:
		_bus.send_event("Fuse_SceneAboutToChange", {"scene_path": scene_path})
	var error_code = scene_tree.change_scene_to_file(scene_path)

	if error_code != OK:
		_log_error_localized("FUSE_ERROR_FAILED_CHANGE_SCENE", {
			"scene_path": scene_path,
			"error": error_string(error_code)
		})
		set_error_localized("FUSE_ERROR_FAILED_CHANGE_SCENE", FuseError.ErrorType.RUNTIME_ERROR, {
			"scene_path": scene_path,
			"error": error_string(error_code)
		})
		runtime_instance._complete_execution()
		return

	_log_info_localized("FUSE_INFO_CHANGE_SCENE_SUCCESS", {
		"scene_path": scene_path
	})
	runtime_instance._complete_execution()

## 暂停处理
## 注意：SceneTreeTimer 不支持暂停，需要取消并记录剩余时间
func on_runtime_pause(runtime_instance: RuntimeInstructionInstance) -> void:
	var state = runtime_instance.runtime_state
	var timer = state.get("timer")

	if timer and is_instance_valid(timer):
		# 计算剩余时间
		var current_time = Time.get_ticks_msec() / 1000.0
		var elapsed = current_time - state.get("start_time", 0.0)
		var remaining = state.get("remaining_time", delay) - elapsed
		state["remaining_time"] = max(0.0, remaining)

		# 断开信号连接
		var callback = state.get("timer_callback")
		if callback and timer.timeout.is_connected(callback):
			timer.timeout.disconnect(callback)

		state["timer"] = null
		state["timer_callback"] = null
		state["is_running"] = false

## 恢复处理
## 注意：SceneTreeTimer 不支持暂停，需要创建新定时器
func on_runtime_resume(runtime_instance: RuntimeInstructionInstance) -> void:
	var state = runtime_instance.runtime_state
	var remaining = state.get("remaining_time", 0.0)

	if remaining <= 0.0:
		return

	var scene_tree = Engine.get_main_loop()
	if not scene_tree:
		return

	# 创建新定时器
	var timer = scene_tree.create_timer(remaining)
	state["timer"] = timer
	state["start_time"] = Time.get_ticks_msec() / 1000.0
	state["is_running"] = true

	var callback = _create_timer_callback(runtime_instance)
	timer.timeout.connect(callback, CONNECT_ONE_SHOT)
	runtime_instance.register_timer_callback(callback)
	state["timer_callback"] = callback

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()

	if scene_path.is_empty():
		errors.append(FuseLocalization.translate("FUSE_VALIDATION_SCENE_PATH_EMPTY"))

	if delay < 0.0:
		errors.append(FuseLocalization.translate("FUSE_VALIDATION_DELAY_NEGATIVE"))

	return errors

## 获取指令描述
func get_description() -> String:
	var scene_name = FuseNodeUtils.get_path_display_name(scene_path) if not scene_path.is_empty() else FuseLocalization.translate("FUSE_INSTRUCTION_CHANGE_SCENE_NO_SCENE")

	if delay > 0.0:
		var delay_template = FuseLocalization.translate("FUSE_INSTRUCTION_CHANGE_SCENE_DELAY_DESC")
		var delay_str = delay_template.format({"delay": "%.1f" % delay})
		var desc_template = FuseLocalization.translate("FUSE_INSTRUCTION_CHANGE_SCENE_DESC_WITH_DELAY")
		return desc_template.format({"scene": scene_name, "delay": delay_str})
	else:
		var desc_template = FuseLocalization.translate("FUSE_INSTRUCTION_CHANGE_SCENE_DESC_IMMEDIATE")
		return desc_template.format({"scene": scene_name})
