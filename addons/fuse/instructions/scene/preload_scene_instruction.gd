@tool
@icon("res://addons/fuse/icons/builtin/Load.png")
extends BaseInstruction
class_name PreloadSceneInstruction

## 预加载场景指令
##
## 使用 ResourceLoader.load_threaded_request() 在后台加载场景。
## 可以选择阻塞等待或异步加载。
##
## 重构变量系统: 2026-03-16 - 使用 VariableOperations 统一变量访问

## 预加载模式
enum PreloadMode {
	ASYNC_NOW,    ## 立即开始异步加载，阻塞等待完成
	ASYNC_LATER   ## 开始异步加载，立即返回（不阻塞）
}

func _init():
	# 🔧 关键修复：明确声明此指令是异步的
	# PreloadSceneInstruction 在 ASYNC_NOW 模式下使用定时器轮询等待
	_is_synchronous_hint = false
	_sync_hint_manually_set = true

## 场景路径
var scene_path: String = "":
	set(value):
		scene_path = value
		_update_resource_name()

## 预加载模式
var preload_mode: PreloadMode = PreloadMode.ASYNC_NOW:
	set(value):
		preload_mode = value
		_update_resource_name()

## 超时时间（秒）
var timeout: float = 5.0

## 保存加载状态到变量名
var status_variable: String = "preload_scene_status"

## 定时器（用于轮询加载状态）
var _timer: SceneTreeTimer = null

## 保存定时器回调的 Callable 引用（用于断开连接）
var _timer_callback: Callable = Callable()

## 加载开始时间
var _load_start_time: float = 0.0

## 获取指令元数据（用于指令选择器）
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_PRELOAD_SCENE_NAME"
	metadata.category_key = "FUSE_CATEGORY_SCENE"
	metadata.description_key = "FUSE_INSTRUCTION_PRELOAD_SCENE_DESC"
	metadata.keywords = ["preload", "scene", "load", "async", "background", "预加载", "场景", "加载", "异步", "后台"]
	metadata.builtin_icon = "Load"
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties := []

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

	# Mode 分类
	properties.append({
		name = "Mode",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 预加载模式
	properties.append({
		name = "preload_mode",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Async Now (Wait),Async Later (No Wait)",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Options 分类
	properties.append({
		name = "Options",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 超时时间
	properties.append({
		name = "timeout",
		type = TYPE_FLOAT,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "0.1,30.0,0.1",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Variable 分类
	properties.append({
		name = "Variable",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 状态变量名
	properties.append({
		name = "status_variable",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 更新资源名称
func _update_resource_name():
	var parts = []

	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_PRELOAD_SCENE_BASE"))

	if not scene_path.is_empty():
		parts.append("'%s'" % FuseNodeUtils.get_path_display_name(scene_path))
	else:
		parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_PRELOAD_SCENE_NO_SCENE"))

	if preload_mode == PreloadMode.ASYNC_NOW:
		parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_PRELOAD_SCENE_MODE_WAIT"))
	else:
		parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_PRELOAD_SCENE_MODE_NOWAIT"))

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

	# 检查资源是否存在
	if not ResourceLoader.exists(scene_path):
		_log_error_localized("FUSE_ERROR_SCENE_NOT_FOUND", {"scene": scene_path})
		set_error_localized("FUSE_ERROR_SCENE_NOT_FOUND", FuseError.ErrorType.VALIDATION_ERROR, {"scene": scene_path})
		finished.emit()
		return

	# 检查是否已加载
	var current_status = ResourceLoader.load_threaded_get_status(scene_path)
	if current_status == ResourceLoader.THREAD_LOAD_LOADED:
		# 已加载，直接完成（不调用 load_threaded_get()，保留线程缓存供 CheckPreloadStatus 检测）
		VariableOperations.set_variable(context, status_variable, BaseVariable.VariableScope.LOCAL, "loaded")
		_log_info_localized("FUSE_INFO_SCENE_PRELOADED", {"scene": FuseNodeUtils.get_path_display_name(scene_path)})
		finished.emit()
		return

	# 开始后台加载
	ResourceLoader.load_threaded_request(scene_path)
	_load_start_time = Time.get_ticks_msec() / 1000.0

	_log_info_localized("FUSE_INFO_SCENE_PRELOADING", {"scene": FuseNodeUtils.get_path_display_name(scene_path)})

	if preload_mode == PreloadMode.ASYNC_NOW:
		# 阻塞等待加载完成
		_start_load_polling(context)
	else:
		# 非阻塞，立即完成
		VariableOperations.set_variable(context, "preload_scene_path", BaseVariable.VariableScope.LOCAL, scene_path)
		VariableOperations.set_variable(context, status_variable, BaseVariable.VariableScope.LOCAL, "loading")
		_log_info_localized("FUSE_INFO_SCENE_PRELOAD_STARTED", {"scene": FuseNodeUtils.get_path_display_name(scene_path)})
		finished.emit()

## 开始加载轮询
func _start_load_polling(context: ExecutionContext) -> void:
	var scene_tree = Engine.get_main_loop()
	if not scene_tree:
		_log_error_localized("FUSE_ERROR_CANNOT_CREATE_TIMER", {})
		_cleanup_resources()
		finished.emit()
		return

	# 创建轮询计时器（每 0.1 秒检查一次）
	_timer = scene_tree.create_timer(0.1)
	_timer_callback = _check_load_status.bind(context)
	_timer.timeout.connect(_timer_callback)

## 检查加载状态
func _check_load_status(context: ExecutionContext):
	var status = ResourceLoader.load_threaded_get_status(scene_path)

	# 检查超时
	var elapsed = Time.get_ticks_msec() / 1000.0 - _load_start_time
	if elapsed > timeout:
		_log_error_localized("FUSE_ERROR_SCENE_PRELOAD_TIMEOUT", {"scene": scene_path, "timeout": str(timeout)})
		set_error_localized("FUSE_ERROR_SCENE_PRELOAD_TIMEOUT", FuseError.ErrorType.RUNTIME_ERROR, {"scene": scene_path, "timeout": str(timeout)})
		VariableOperations.set_variable(context, status_variable, BaseVariable.VariableScope.LOCAL, "timeout")
		_cleanup_resources()
		finished.emit()
		return

	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			# 加载完成（不调用 load_threaded_get()，保留线程缓存供 CheckPreloadStatus 检测）
			VariableOperations.set_variable(context, status_variable, BaseVariable.VariableScope.LOCAL, "loaded")
			_log_info_localized("FUSE_INFO_SCENE_PRELOADED", {"scene": FuseNodeUtils.get_path_display_name(scene_path)})
			_cleanup_resources()
			finished.emit()

		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			# 继续等待
			var scene_tree = Engine.get_main_loop()
			if scene_tree:
				_timer = scene_tree.create_timer(0.1)
				_timer_callback = _check_load_status.bind(context)
				_timer.timeout.connect(_timer_callback)
			else:
				_log_error_localized("FUSE_ERROR_CANNOT_CREATE_TIMER", {})
				_cleanup_resources()
				finished.emit()

		ResourceLoader.THREAD_LOAD_FAILED:
			# 加载失败
			_log_error_localized("FUSE_ERROR_CANNOT_LOAD_SCENE", {"scene": scene_path})
			set_error_localized("FUSE_ERROR_CANNOT_LOAD_SCENE", FuseError.ErrorType.RUNTIME_ERROR, {"scene": scene_path})
			VariableOperations.set_variable(context, status_variable, BaseVariable.VariableScope.LOCAL, "failed")
			_cleanup_resources()
			finished.emit()

		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			# 无效资源
			_log_error_localized("FUSE_ERROR_INVALID_RESOURCE", {"scene": scene_path})
			set_error_localized("FUSE_ERROR_INVALID_RESOURCE", FuseError.ErrorType.RUNTIME_ERROR, {"scene": scene_path})
			VariableOperations.set_variable(context, status_variable, BaseVariable.VariableScope.LOCAL, "invalid")
			_cleanup_resources()
			finished.emit()

## 清理资源
func _cleanup_resources() -> void:
	if _timer and is_instance_valid(_timer):
		# 使用保存的 Callable 引用来断开连接
		if not _timer_callback.is_null() and _timer.timeout.is_connected(_timer_callback):
			_timer.timeout.disconnect(_timer_callback)
		_timer = null
		_timer_callback = Callable()

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()

	if scene_path.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_SCENE_PATH_EMPTY"))

	if not scene_path.is_empty() and not ResourceLoader.exists(scene_path):
		errors.append(FuseLocalization.translate_format("FUSE_ERROR_SCENE_NOT_FOUND", {"scene": scene_path}))

	return errors

## 获取指令描述
func get_description() -> String:
	var mode_str = ""
	if preload_mode == PreloadMode.ASYNC_NOW:
		mode_str = FuseLocalization.translate("FUSE_INSTRUCTION_PRELOAD_SCENE_MODE_WAIT")
	else:
		mode_str = FuseLocalization.translate("FUSE_INSTRUCTION_PRELOAD_SCENE_MODE_NOWAIT")

	return FuseLocalization.translate_format("FUSE_INSTRUCTION_PRELOAD_SCENE_DESC_FORMAT", {
		"scene": FuseNodeUtils.get_path_display_name(scene_path) if not scene_path.is_empty() else FuseLocalization.translate("FUSE_TEXT_NOT_SPECIFIED"),
		"mode": mode_str,
		"timeout": str(timeout)
	})

## ============================================================
## 运行时实例模式支持（RuntimeInstructionInstance 架构）
## ============================================================

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var state = super.get_default_runtime_state()
	state["timer"] = null
	state["timer_callback"] = null
	state["load_start_time"] = 0.0
	return state

## 使用运行时实例执行（推荐模式）
func execute_with_runtime_instance(runtime_instance: RuntimeInstructionInstance) -> bool:
	_start_execution(runtime_instance.execution_context)

	# 验证场景路径
	if scene_path.is_empty():
		_log_error_localized("FUSE_ERROR_SCENE_PATH_EMPTY", {})
		set_error_localized("FUSE_ERROR_SCENE_PATH_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		runtime_instance._complete_execution()
		return true

	# 检查资源是否存在
	if not ResourceLoader.exists(scene_path):
		_log_error_localized("FUSE_ERROR_SCENE_NOT_FOUND", {"scene": scene_path})
		set_error_localized("FUSE_ERROR_SCENE_NOT_FOUND", FuseError.ErrorType.VALIDATION_ERROR, {"scene": scene_path})
		runtime_instance._complete_execution()
		return true

	var state = runtime_instance.runtime_state
	var context = runtime_instance.execution_context

	# 检查是否已加载
	var current_status = ResourceLoader.load_threaded_get_status(scene_path)
	if current_status == ResourceLoader.THREAD_LOAD_LOADED:
		# 已加载，直接完成（不调用 load_threaded_get()，保留线程缓存供 CheckPreloadStatus 检测）
		VariableOperations.set_variable(context, status_variable, BaseVariable.VariableScope.LOCAL, "loaded")
		_log_info_localized("FUSE_INFO_SCENE_PRELOADED", {"scene": FuseNodeUtils.get_path_display_name(scene_path)})
		runtime_instance._complete_execution()
		return true

	# 开始后台加载
	ResourceLoader.load_threaded_request(scene_path)
	state["load_start_time"] = Time.get_ticks_msec() / 1000.0

	_log_info_localized("FUSE_INFO_SCENE_PRELOADING", {"scene": FuseNodeUtils.get_path_display_name(scene_path)})

	if preload_mode == PreloadMode.ASYNC_NOW:
		# 阻塞等待
		_start_runtime_load_polling(runtime_instance)
		return false
	else:
		# 非阻塞，立即完成
		VariableOperations.set_variable(context, "preload_scene_path", BaseVariable.VariableScope.LOCAL, scene_path)
		VariableOperations.set_variable(context, status_variable, BaseVariable.VariableScope.LOCAL, "loading")
		_log_info_localized("FUSE_INFO_SCENE_PRELOAD_STARTED", {"scene": FuseNodeUtils.get_path_display_name(scene_path)})
		runtime_instance._complete_execution()
		return true

## 创建加载状态检查回调（避免 bind）
func _create_runtime_load_callback(runtime_instance: RuntimeInstructionInstance) -> Callable:
	var callback = func():
		_on_runtime_load_poll(runtime_instance)
	return callback

## 开始运行时加载轮询
func _start_runtime_load_polling(runtime_instance: RuntimeInstructionInstance) -> void:
	var state = runtime_instance.runtime_state
	var scene_tree = Engine.get_main_loop()
	if not scene_tree:
		_log_error_localized("FUSE_ERROR_CANNOT_CREATE_TIMER", {})
		runtime_instance._complete_execution()
		return

	var timer = scene_tree.create_timer(0.1)
	state["timer"] = timer

	var callback = _create_runtime_load_callback(runtime_instance)
	timer.timeout.connect(callback)
	runtime_instance.register_timer_callback(callback)
	state["timer_callback"] = callback

## 运行时加载轮询回调
func _on_runtime_load_poll(runtime_instance: RuntimeInstructionInstance) -> void:
	if not runtime_instance or runtime_instance.is_completed():
		return

	var state = runtime_instance.runtime_state
	var context = runtime_instance.execution_context
	var status = ResourceLoader.load_threaded_get_status(scene_path)

	# 检查超时
	var elapsed = Time.get_ticks_msec() / 1000.0 - state.get("load_start_time", 0.0)
	if elapsed > timeout:
		_log_error_localized("FUSE_ERROR_SCENE_PRELOAD_TIMEOUT", {"scene": scene_path, "timeout": str(timeout)})
		set_error_localized("FUSE_ERROR_SCENE_PRELOAD_TIMEOUT", FuseError.ErrorType.RUNTIME_ERROR, {"scene": scene_path, "timeout": str(timeout)})
		VariableOperations.set_variable(context, status_variable, BaseVariable.VariableScope.LOCAL, "timeout")
		_cleanup_runtime_load_timer(runtime_instance)
		runtime_instance._complete_execution()
		return

	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			# 加载完成（不调用 load_threaded_get()，保留线程缓存供 CheckPreloadStatus 检测）
			VariableOperations.set_variable(context, status_variable, BaseVariable.VariableScope.LOCAL, "loaded")
			_log_info_localized("FUSE_INFO_SCENE_PRELOADED", {"scene": FuseNodeUtils.get_path_display_name(scene_path)})
			_cleanup_runtime_load_timer(runtime_instance)
			runtime_instance._complete_execution()

		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_start_runtime_load_polling(runtime_instance)

		ResourceLoader.THREAD_LOAD_FAILED:
			_log_error_localized("FUSE_ERROR_CANNOT_LOAD_SCENE", {"scene": scene_path})
			set_error_localized("FUSE_ERROR_CANNOT_LOAD_SCENE", FuseError.ErrorType.RUNTIME_ERROR, {"scene": scene_path})
			VariableOperations.set_variable(context, status_variable, BaseVariable.VariableScope.LOCAL, "failed")
			_cleanup_runtime_load_timer(runtime_instance)
			runtime_instance._complete_execution()

		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_log_error_localized("FUSE_ERROR_INVALID_RESOURCE", {"scene": scene_path})
			set_error_localized("FUSE_ERROR_INVALID_RESOURCE", FuseError.ErrorType.RUNTIME_ERROR, {"scene": scene_path})
			VariableOperations.set_variable(context, status_variable, BaseVariable.VariableScope.LOCAL, "invalid")
			_cleanup_runtime_load_timer(runtime_instance)
			runtime_instance._complete_execution()

## 清理运行时加载计时器
func _cleanup_runtime_load_timer(runtime_instance: RuntimeInstructionInstance) -> void:
	var state = runtime_instance.runtime_state

	if state.has("timer") and state["timer"]:
		var timer = state["timer"]
		var callback = state.get("timer_callback")
		if callback and timer.timeout.is_connected(callback):
			timer.timeout.disconnect(callback)
		state["timer"] = null
		state["timer_callback"] = null

## 暂停处理
func on_runtime_pause(runtime_instance: RuntimeInstructionInstance) -> void:
	var state = runtime_instance.runtime_state

	# 断开轮询计时器
	if state.has("timer") and state["timer"]:
		var timer = state["timer"]
		var callback = state.get("timer_callback")
		if callback and timer.timeout.is_connected(callback):
			timer.timeout.disconnect(callback)
		state["timer"] = null
		state["timer_callback"] = null

## 恢复处理
func on_runtime_resume(runtime_instance: RuntimeInstructionInstance) -> void:
	var state = runtime_instance.runtime_state
	var context = runtime_instance.execution_context

	# 检查加载状态
	var status = ResourceLoader.load_threaded_get_status(scene_path)

	if status == ResourceLoader.THREAD_LOAD_LOADED:
		# 加载完成（不调用 load_threaded_get()，保留线程缓存供 CheckPreloadStatus 检测）
		VariableOperations.set_variable(context, status_variable, BaseVariable.VariableScope.LOCAL, "loaded")
		_log_info_localized("FUSE_INFO_SCENE_PRELOADED", {"scene": FuseNodeUtils.get_path_display_name(scene_path)})
		runtime_instance._complete_execution()
	elif status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		_start_runtime_load_polling(runtime_instance)
	else:
		_log_error_localized("FUSE_ERROR_CANNOT_LOAD_SCENE", {"scene": scene_path})
		set_error_localized("FUSE_ERROR_CANNOT_LOAD_SCENE", FuseError.ErrorType.RUNTIME_ERROR, {"scene": scene_path})
		VariableOperations.set_variable(context, status_variable, BaseVariable.VariableScope.LOCAL, "failed")
		runtime_instance._complete_execution()

## 检查场景是否已加载
static func is_scene_loaded(path: String) -> bool:
	var status = ResourceLoader.load_threaded_get_status(path)
	return status == ResourceLoader.THREAD_LOAD_LOADED

## 获取已加载的场景
static func get_loaded_scene(path: String) -> Resource:
	if is_scene_loaded(path):
		return ResourceLoader.load_threaded_get(path)
	return null
