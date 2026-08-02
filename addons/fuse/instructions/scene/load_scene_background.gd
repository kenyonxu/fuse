@tool
@icon("res://addons/fuse/icons/builtin/Load.png")
extends BaseInstruction
class_name LoadSceneBackground

## 后台加载场景
##
## 在后台异步加载场景（不立即切换），完成后保存到变量。
##
## 重构变量系统: 2026-02-09 - 使用 VariableOperations 统一变量访问

func _init():
	# 🔧 关键修复：明确声明此指令是异步的
	# LoadSceneBackground 指令使用回调机制（定时器轮询）而非 await，所以源码检测无法正确识别
	_is_synchronous_hint = false
	_sync_hint_manually_set = true

# 场景文件路径
var scene_path: String = ""

# 保存加载的场景到变量名
var save_to_variable: String = "loaded_scene"

# 变量作用域
var save_to_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		save_to_scope = value
		_update_resource_name()
		notify_property_list_changed()

## 作用域来源枚举
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

## 作用域来源（仅当 save_to_scope == SCOPE 时使用）
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

# 定时器（用于轮询加载状态）
var _timer: SceneTreeTimer = null

# 保存定时器回调的 Callable 引用（用于断开连接）
var _timer_callback: Callable = Callable()

# 是否正在加载
var _is_loading: bool = false

## 获取指令元数据（用于指令选择器）
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_LOAD_SCENE_BACKGROUND_NAME"
	metadata.category_key = "FUSE_CATEGORY_SCENE"
	metadata.description_key = "FUSE_INSTRUCTION_LOAD_SCENE_BACKGROUND_DESC"
	metadata.keywords = ["scene", "load", "background", "async", "preload", "场景", "加载", "后台", "异步", "预加载"]
	metadata.builtin_icon = "Load"
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

## 声明变量读写模式（save_to=write）
func get_variable_modes() -> Array[Dictionary]:
	return [{"name": "save_to_variable", "mode": "write"}]

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

	# Variable 分类
	properties.append({
		name = "Variable",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 变量名
	properties.append({
		name = "save_to_variable",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 变量作用域
	properties.append({
		name = "save_to_scope",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Local,Scope,Global",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 只在 save_to_scope == SCOPE 时显示 ScopeSource 配置
	if save_to_scope == BaseVariable.VariableScope.SCOPE:
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
	var parts = []

	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_LOAD_SCENE_BACKGROUND_BASE"))

	if not scene_path.is_empty():
		parts.append("'%s'" % FuseNodeUtils.get_path_display_name(scene_path))
	else:
		parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_LOAD_SCENE_BACKGROUND_NO_SCENE"))

	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_LOAD_SCENE_BACKGROUND_TO_VARIABLE"))

	if not save_to_variable.is_empty():
		parts.append("'%s'" % save_to_variable)
		var scope_str = _get_scope_source_string()
		parts.append("(%s)" % scope_str)
	else:
		parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_LOAD_SCENE_BACKGROUND_NO_VARIABLE"))

	resource_name = " ".join(parts)

## 获取作用域来源字符串
func _get_scope_source_string() -> String:
	match save_to_scope:
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
	_start_execution(context)

	# 验证场景路径
	if scene_path.is_empty():
		_log_error_localized("FUSE_ERROR_SCENE_PATH_EMPTY", {})
		set_error_localized("FUSE_ERROR_SCENE_PATH_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 验证变量名
	if save_to_variable.is_empty():
		_log_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", {})
		set_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 开始异步加载
	ResourceLoader.load_threaded_request(scene_path)
	_is_loading = true

	_log_info_localized("FUSE_INFO_SCENE_LOADING", {})

	# 创建定时器轮询加载状态
	var scene_tree = Engine.get_main_loop()
	if not scene_tree:
		_log_error_localized("FUSE_ERROR_CANNOT_CREATE_TIMER", {})
		_cleanup_resources()
		finished.emit()
		return

	_timer = scene_tree.create_timer(0.1)  # 每 0.1 秒检查一次
	_timer_callback = _check_load_status.bind(context)  # 保存 Callable 引用
	_timer.timeout.connect(_timer_callback)
	# 不调用 _on_execution_completed()，等待加载完成

## 检查加载状态
func _check_load_status(context: ExecutionContext):
	var status = ResourceLoader.load_threaded_get_status(scene_path)

	if status == ResourceLoader.THREAD_LOAD_LOADED:
		# 加载完成
		var packed_scene = ResourceLoader.load_threaded_get(scene_path)
		if packed_scene is PackedScene:
			# 保存到变量
			match save_to_scope:
				BaseVariable.VariableScope.LOCAL:
					VariableOperations.set_variable(context, save_to_variable, BaseVariable.VariableScope.LOCAL, packed_scene)
				BaseVariable.VariableScope.SCOPE:
					if scope_source == ScopeSource.NEAREST:
						VariableOperations.set_variable(context, save_to_variable, BaseVariable.VariableScope.SCOPE, packed_scene)
					else:
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
							_cleanup_resources()
							finished.emit()
							return
						scope_container.set_variable(save_to_variable, packed_scene)
				BaseVariable.VariableScope.GLOBAL:
					VariableOperations.set_variable(context, save_to_variable, BaseVariable.VariableScope.GLOBAL, packed_scene)

			_log_info_localized("FUSE_INFO_SCENE_LOADED", {"var": save_to_variable})
		else:
			_log_error_localized("FUSE_ERROR_CANNOT_LOAD_SCENE", {"scene": scene_path})
			set_error_localized("FUSE_ERROR_CANNOT_LOAD_SCENE", FuseError.ErrorType.RUNTIME_ERROR, {"scene": scene_path})

		_cleanup_resources()
		finished.emit()

	elif status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		# 继续等待
		var scene_tree = Engine.get_main_loop()
		if scene_tree:
			_timer = scene_tree.create_timer(0.1)
			_timer_callback = _check_load_status.bind(context)  # 更新 Callable 引用
			_timer.timeout.connect(_timer_callback)
		else:
			_log_error_localized("FUSE_ERROR_CANNOT_CREATE_TIMER", {})
			_cleanup_resources()
			finished.emit()

	else:
		# 加载失败（THREAD_LOAD_INVALID_RESOURCE 或 THREAD_LOAD_FAILED）
		_log_error_localized("FUSE_ERROR_CANNOT_LOAD_SCENE", {"scene": scene_path})
		set_error_localized("FUSE_ERROR_CANNOT_LOAD_SCENE", FuseError.ErrorType.RUNTIME_ERROR, {"scene": scene_path})
		_cleanup_resources()
		finished.emit()

## 清理资源
func _cleanup_resources() -> void:
	_is_loading = false

	if _timer and is_instance_valid(_timer):
		# 使用保存的 Callable 引用来断开连接
		if not _timer_callback.is_null() and _timer.timeout.is_connected(_timer_callback):
			_timer.timeout.disconnect(_timer_callback)
		_timer = null
		_timer_callback = Callable()  # 清空引用

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()

	if scene_path.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_SCENE_PATH_EMPTY"))

	if save_to_variable.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_VAR_NAME_EMPTY"))

	# 验证 SCOPE 作用域需要 ScopeVariableManager
	if save_to_scope == BaseVariable.VariableScope.SCOPE:
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

	# 验证作用域
	if save_to_scope == BaseVariable.VariableScope.GLOBAL:
		# 检查是否可以获取到 GlobalVariableAssistant 单例
		var test_assistant = GlobalVariableAssistant.get_instance()
		if test_assistant == null:
			errors.append(FuseLocalization.translate("FUSE_ERROR_ASSISTANT_NOT_FOUND"))

	return errors

## 验证属性可见性
func _validate_property(property: Dictionary) -> void:
	# 只在 SCOPE 作用域时验证 ScopeSource 相关属性
	if save_to_scope == BaseVariable.VariableScope.SCOPE:
		VariableScopeUtils.validate_scope_source_property(property, scope_source as VariableScopeUtils.ScopeSource)
	else:
		# 非 SCOPE 作用域时隐藏 ScopeSource 相关属性
		if property.name in ["scope_source", "custom_scope_id", "target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR

## 获取指令描述
func get_description() -> String:
	var scope_str = _get_scope_source_string()
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_LOAD_SCENE_BACKGROUND_DESC_FORMAT", {"scene": FuseNodeUtils.get_path_display_name(scene_path), "variable": save_to_variable, "scope": scope_str})

## ============================================================
## 运行时实例模式支持（RuntimeInstructionInstance 架构）
## ============================================================

## 获取默认运行时状态
##
## 声明 LoadSceneBackground 指令需要的运行时状态。
## 这些状态会在 RuntimeInstructionInstance 初始化时被复制。
func get_default_runtime_state() -> Dictionary:
	var state = super.get_default_runtime_state()
	state["timer"] = null  # 轮询计时器
	state["timer_callback"] = null  # 计时器回调引用（用于暂停时断开）
	state["is_loading"] = false  # 加载状态
	state["load_start_time"] = 0.0  # 开始加载时间
	state["pause_elapsed_time"] = 0.0  # 暂停时已用时间
	return state

## 使用运行时实例执行（推荐模式）
##
## 这种模式下，所有状态存储在 runtime_instance.runtime_state 中，
## 确保多个执行实例互不干扰。
##
## 使用 runtime_instance 管理信号连接，避免 bind 泄漏
func execute_with_runtime_instance(runtime_instance: RuntimeInstructionInstance) -> bool:
	_start_execution(runtime_instance.execution_context)

	# 验证场景路径
	if scene_path.is_empty():
		_log_error_localized("FUSE_ERROR_SCENE_PATH_EMPTY", {})
		set_error_localized("FUSE_ERROR_SCENE_PATH_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		runtime_instance._complete_execution()
		return true

	# 验证变量名
	if save_to_variable.is_empty():
		_log_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", {})
		set_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		runtime_instance._complete_execution()
		return true

	var state = runtime_instance.runtime_state

	# 开始异步加载
	ResourceLoader.load_threaded_request(scene_path)
	state["is_loading"] = true
	state["load_start_time"] = Time.get_ticks_msec() / 1000.0

	_log_info_localized("FUSE_INFO_SCENE_LOADING", {})

	# 创建定时器轮询加载状态
	var scene_tree = Engine.get_main_loop()
	if not scene_tree:
		_log_error_localized("FUSE_ERROR_CANNOT_CREATE_TIMER", {})
		runtime_instance._complete_execution()
		return true

	# 开始轮询
	_start_load_polling(runtime_instance)

	return false  # 异步执行

## 创建加载状态检查回调（避免 bind）
##
## 使用 Callable 和闭包，但存储引用以便清理
func _create_load_callback(runtime_instance: RuntimeInstructionInstance) -> Callable:
	var callback = func():
		_on_runtime_load_poll(runtime_instance)
	return callback

## 开始加载轮询
func _start_load_polling(runtime_instance: RuntimeInstructionInstance) -> void:
	var state = runtime_instance.runtime_state
	var scene_tree = Engine.get_main_loop()
	if not scene_tree:
		_log_error_localized("FUSE_ERROR_CANNOT_CREATE_TIMER", {})
		runtime_instance._complete_execution()
		return

	# 创建轮询计时器（每 0.1 秒检查一次）
	var timer = scene_tree.create_timer(0.1)
	state["timer"] = timer

	# 使用回调注册机制
	var callback = _create_load_callback(runtime_instance)
	timer.timeout.connect(callback)
	runtime_instance.register_timer_callback(callback)
	state["timer_callback"] = callback  # 存储引用，用于暂停时断开

## 运行时加载轮询回调
##
## 检查加载状态，直到完成或失败
func _on_runtime_load_poll(runtime_instance: RuntimeInstructionInstance) -> void:
	# 检查实例是否仍然有效
	if not runtime_instance or runtime_instance.is_completed():
		return

	var state = runtime_instance.runtime_state
	var status = ResourceLoader.load_threaded_get_status(scene_path)

	if status == ResourceLoader.THREAD_LOAD_LOADED:
		# 加载完成
		var packed_scene = ResourceLoader.load_threaded_get(scene_path)
		if packed_scene is PackedScene:
			# 保存到变量
			_save_scene_to_variable(runtime_instance, packed_scene)
			_log_info_localized("FUSE_INFO_SCENE_LOADED", {"var": save_to_variable})
		else:
			_log_error_localized("FUSE_ERROR_CANNOT_LOAD_SCENE", {"scene": scene_path})
			set_error_localized("FUSE_ERROR_CANNOT_LOAD_SCENE", FuseError.ErrorType.RUNTIME_ERROR, {"scene": scene_path})

		_cleanup_load_timer(runtime_instance)
		state["is_loading"] = false
		runtime_instance._complete_execution()

	elif status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		# 继续等待，重新启动轮询
		_start_load_polling(runtime_instance)

	else:
		# 加载失败（THREAD_LOAD_INVALID_RESOURCE 或 THREAD_LOAD_FAILED）
		_log_error_localized("FUSE_ERROR_CANNOT_LOAD_SCENE", {"scene": scene_path})
		set_error_localized("FUSE_ERROR_CANNOT_LOAD_SCENE", FuseError.ErrorType.RUNTIME_ERROR, {"scene": scene_path})
		_cleanup_load_timer(runtime_instance)
		state["is_loading"] = false
		runtime_instance._complete_execution()

## 保存场景到变量
##
## 根据作用域设置保存 PackedScene 到变量
func _save_scene_to_variable(runtime_instance: RuntimeInstructionInstance, packed_scene: PackedScene) -> void:
	var context = runtime_instance.execution_context

	match save_to_scope:
		BaseVariable.VariableScope.LOCAL:
			VariableOperations.set_variable(context, save_to_variable, BaseVariable.VariableScope.LOCAL, packed_scene)
		BaseVariable.VariableScope.SCOPE:
			if scope_source == ScopeSource.NEAREST:
				VariableOperations.set_variable(context, save_to_variable, BaseVariable.VariableScope.SCOPE, packed_scene)
			else:
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
					return
				scope_container.set_variable(save_to_variable, packed_scene)
		BaseVariable.VariableScope.GLOBAL:
			VariableOperations.set_variable(context, save_to_variable, BaseVariable.VariableScope.GLOBAL, packed_scene)

## 清理运行时加载计时器
func _cleanup_load_timer(runtime_instance: RuntimeInstructionInstance) -> void:
	var state = runtime_instance.runtime_state

	if state.has("timer") and state["timer"]:
		var timer = state["timer"]
		var callback = state.get("timer_callback")
		if callback and timer.timeout.is_connected(callback):
			timer.timeout.disconnect(callback)
		state["timer"] = null
		state["timer_callback"] = null

## 暂停处理
##
## 当运行时实例被暂停时，断开轮询计时器
func on_runtime_pause(runtime_instance: RuntimeInstructionInstance) -> void:
	var state = runtime_instance.runtime_state

	# 记录已用时间
	if state.get("load_start_time", 0.0) > 0:
		var elapsed = Time.get_ticks_msec() / 1000.0 - state.get("load_start_time", 0.0)
		state["pause_elapsed_time"] = elapsed

	# 断开轮询计时器
	if state.has("timer") and state["timer"]:
		var timer = state["timer"]
		var callback = state.get("timer_callback")
		if callback and timer.timeout.is_connected(callback):
			timer.timeout.disconnect(callback)
		state["timer"] = null
		state["timer_callback"] = null

## 恢复处理
##
## 当运行时实例被恢复时，重新开始轮询
func on_runtime_resume(runtime_instance: RuntimeInstructionInstance) -> void:
	var state = runtime_instance.runtime_state

	# 恢复开始时间（减去已用时间，保持时间连续性）
	var elapsed = state.get("pause_elapsed_time", 0.0)
	if elapsed > 0:
		state["load_start_time"] = Time.get_ticks_msec() / 1000.0 - elapsed

	# 如果仍在加载，重新开始轮询
	if state.get("is_loading", false):
		# 检查加载状态
		var status = ResourceLoader.load_threaded_get_status(scene_path)

		if status == ResourceLoader.THREAD_LOAD_LOADED:
			# 已完成加载（暂停期间完成）
			var packed_scene = ResourceLoader.load_threaded_get(scene_path)
			if packed_scene is PackedScene:
				_save_scene_to_variable(runtime_instance, packed_scene)
				_log_info_localized("FUSE_INFO_SCENE_LOADED", {"var": save_to_variable})
			else:
				_log_error_localized("FUSE_ERROR_CANNOT_LOAD_SCENE", {"scene": scene_path})
				set_error_localized("FUSE_ERROR_CANNOT_LOAD_SCENE", FuseError.ErrorType.RUNTIME_ERROR, {"scene": scene_path})

			state["is_loading"] = false
			runtime_instance._complete_execution()
		elif status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			# 仍在加载，继续轮询
			_start_load_polling(runtime_instance)
		else:
			# 加载失败
			_log_error_localized("FUSE_ERROR_CANNOT_LOAD_SCENE", {"scene": scene_path})
			set_error_localized("FUSE_ERROR_CANNOT_LOAD_SCENE", FuseError.ErrorType.RUNTIME_ERROR, {"scene": scene_path})
			state["is_loading"] = false
			runtime_instance._complete_execution()

	# 清除暂停状态
	state["pause_elapsed_time"] = 0.0
