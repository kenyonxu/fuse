@tool
class_name GlobalVariableAssistant extends Node

## 全局变量助手节点 - 简化版本
## 用于在场景树中管理全局变量资源的简化功能节点

## 单例实例
static var _instance: GlobalVariableAssistant = null

## 持有的服务层引用（SceneTree 中有节点时 = self，无场景时 = Service 实例）
var _service: GlobalVariableService = null

## 简化的属性
@export var current_resource: GlobalVariableResource = null
@export var resource_path: String = ""
@export var auto_save: bool = true
@export var auto_load_on_ready: bool = true
@export var cleanup_on_exit: bool = true

## 自动保存配置
@export var auto_save_on_change: bool = false  ## 当持久化变量变化时自动保存（默认关闭，推荐通过 SaveGlobalVariables 指令手动保存）
@export var auto_save_delay: float = 1.0  ## 自动保存延迟（秒）

## 节点配置
@export var auto_register: bool = true

## 日志级别配置
@export var log_level: FuseLogger.LogLevel = FuseLogger.LogLevel.INFO

## 节点状态
var _is_registered: bool = false
var _is_initialized: bool = false
var _fuse_error: FuseError = null
## 性能优化：缓存 FuseLocalization 类引用
static var _fuse_localization_class: RefCounted = null
var _save_timer: Timer = null
var _pending_save: bool = false

## 信号定义
signal resource_changed(old_resource: Resource, new_resource: Resource)
signal variable_added(name: String, variable_data: Dictionary)
signal variable_removed(name: String)
signal variable_modified(name: String, old_data: Dictionary, new_data: Dictionary)
signal save_completed(success: bool, path: String)
signal load_completed(success: bool, path: String, resource: Resource)

## 单例管理方法
static func get_instance() -> GlobalVariableAssistant:
	# 优先查找场景树中的 GlobalVariableAssistant 节点
	var scene_tree = Engine.get_main_loop() as SceneTree
	if scene_tree != null and scene_tree.current_scene != null:
		var assistant_nodes = scene_tree.current_scene.find_children("*", "GlobalVariableAssistant")
		if assistant_nodes.size() > 0:
			var scene_assistant = assistant_nodes[0] as GlobalVariableAssistant
			if scene_assistant != null and scene_assistant != _instance:
				_instance = scene_assistant
			return _instance

	# 场景中找不到节点时，创建一个「无场景」的 Assistant 实例
	# 其 _service 引用 = GlobalVariableService（RefCounted），保证变量 CRUD 可用
	# 这个实例不在树中，auto_load/auto_save/cleanup 不会生效
	if _instance == null:
		_instance = GlobalVariableAssistant.new()
		_instance._service = GlobalVariableService.new()
	return _instance

static func has_instance() -> bool:
	return _instance != null

## 初始化
func _init():
	# 只有当节点在场景树中时才设置单例引用
	if is_inside_tree():
		if _instance == null or not is_instance_valid(_instance):
			_instance = self
	# 确保 _service 引用可用（SceneTree 中时 = self，_ready 后会完整设置）
	if _service == null:
		_service = GlobalVariableService.new()

func _ready():
	_log_info(FuseLocalization.translate("FUSE_LOG_GLOBAL_VAR_READY_STARTED"))
	_log_info(FuseLocalization.translate_format(
		"FUSE_LOG_GLOBAL_VAR_NODE_READY",
		{"name": name, "inside_tree": is_inside_tree(), "auto_register": auto_register}
	))

	# 创建自动保存计时器
	_setup_save_timer()

	if auto_register:
		_log_info(FuseLocalization.translate("FUSE_LOG_GLOBAL_VAR_REGISTERING"))
		register_to_manager()
	else:
		_log_info(FuseLocalization.translate_format(
			"FUSE_LOG_GLOBAL_VAR_REGISTER_SKIPPED",
			{"auto_register": auto_register}
		))

	# 加载资源：优先使用 resource_path，如果为空则检查 current_resource
	if auto_load_on_ready:
		if not resource_path.is_empty():
			_log_info(FuseLocalization.translate_format(
				"FUSE_LOG_GLOBAL_VAR_AUTO_LOAD_FROM_PATH",
				{"path": resource_path}
			))
			load_resource(resource_path)
		elif current_resource != null:
			_log_info(FuseLocalization.translate_format(
				"FUSE_LOG_GLOBAL_VAR_AUTO_LOAD_FROM_RESOURCE",
				{"path": current_resource.resource_path}
			))
			_load_from_current_resource()
		else:
			_log_info(FuseLocalization.translate(
				"FUSE_LOG_GLOBAL_VAR_AUTO_LOAD_SKIPPED_NO_SOURCE"
			))
	else:
		_log_info(FuseLocalization.translate_format(
			"FUSE_LOG_GLOBAL_VAR_AUTO_LOAD_SKIPPED",
			{"auto_load": auto_load_on_ready}
		))

	_is_initialized = true
	_log_info(FuseLocalization.translate("FUSE_LOG_GLOBAL_VAR_READY_DONE"))

## 设置自动保存计时器
func _setup_save_timer() -> void:
	if not auto_save_on_change:
		return

	# 创建延迟保存计时器
	_save_timer = Timer.new()
	_save_timer.wait_time = auto_save_delay
	_save_timer.one_shot = true
	_save_timer.autostart = false
	# 让 Timer 在游戏暂停时也能运行，确保保存能完成
	_save_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_save_timer)
	_save_timer.timeout.connect(_on_save_timer_timeout)
	_log_info(FuseLocalization.translate_format(
		"FUSE_LOG_GLOBAL_VAR_SAVE_TIMER_CREATED",
		{"delay": auto_save_delay}
	))

## 保存计时器超时回调
func _on_save_timer_timeout() -> void:
	if not _pending_save:
		return

	_pending_save = false
	_log_info(FuseLocalization.translate("FUSE_LOG_GLOBAL_VAR_DELAYED_SAVE_TRIGGERED"))
	_save_persistent_variables()

## 请求延迟保存
func _request_delayed_save() -> void:
	if not auto_save_on_change or resource_path.is_empty():
		return

	_pending_save = true

	# 如果计时器存在且未运行，启动计时器
	if _save_timer != null and _save_timer.is_stopped():
		_save_timer.start()
		_log_debug(FuseLocalization.translate_format(
			"FUSE_LOG_GLOBAL_VAR_DELAYED_SAVE_REQUESTED",
			{"delay": auto_save_delay}
		))

## 注册到全局变量管理器
func register_to_manager() -> bool:
	var manager = GlobalVariableManager.get_instance()
	if manager == null:
		_log_error(FuseLocalization.translate("FUSE_ERROR_GLOBAL_VAR_MANAGER_NOT_FOUND"))
		_create_fuse_error_localized("FUSE_ERROR_GLOBAL_VAR_MANAGER_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR)
		return false

	# 连接管理器信号
	if not manager.variable_added.is_connected(_on_manager_variable_added):
		manager.variable_added.connect(_on_manager_variable_added)
	if not manager.variable_removed.is_connected(_on_manager_variable_removed):
		manager.variable_removed.connect(_on_manager_variable_removed)
	if not manager.variable_changed.is_connected(_on_manager_variable_changed):
		manager.variable_changed.connect(_on_manager_variable_changed)

	_is_registered = true
	_log_info(FuseLocalization.translate("FUSE_LOG_GLOBAL_VAR_REGISTERED"))
	return true

## 从全局变量管理器注销
func unregister_from_manager() -> bool:
	var manager = GlobalVariableManager.get_instance()
	if manager == null:
		_log_warning(FuseLocalization.translate(
			"FUSE_LOG_GLOBAL_VAR_UNREGISTER_MANAGER_NOT_FOUND"
		))
		return false

	# 断开管理器信号
	if manager.variable_added.is_connected(_on_manager_variable_added):
		manager.variable_added.disconnect(_on_manager_variable_added)
	if manager.variable_removed.is_connected(_on_manager_variable_removed):
		manager.variable_removed.disconnect(_on_manager_variable_removed)
	if manager.variable_changed.is_connected(_on_manager_variable_changed):
		manager.variable_changed.disconnect(_on_manager_variable_changed)

	_is_registered = false
	_log_info(FuseLocalization.translate("FUSE_LOG_GLOBAL_VAR_UNREGISTERED"))
	return true

## 全局变量变化回调
func on_global_variables_changed() -> void:
	_log_debug(FuseLocalization.translate("FUSE_LOG_GLOBAL_VAR_VARIABLES_CHANGED"))

## 管理器信号处理方法
func _on_manager_variable_added(name: String, variable: BaseVariable) -> void:
	_log_debug(FuseLocalization.translate_format(
		"FUSE_LOG_GLOBAL_VAR_MANAGER_VARIABLE_ADDED",
		{"name": name}
	))
	variable_added.emit(name, {"name": name, "value": variable.value, "type": variable.get_type_name()})

	# 如果是持久化变量，触发延迟保存
	if variable.persistent:
		_log_debug(FuseLocalization.translate_format(
			"FUSE_LOG_GLOBAL_VAR_PERSISTENT_ADDED_DELAYED_SAVE",
			{"name": name}
		))
		_request_delayed_save()

func _on_manager_variable_removed(name: String) -> void:
	_log_debug(FuseLocalization.translate_format(
		"FUSE_LOG_GLOBAL_VAR_MANAGER_VARIABLE_REMOVED",
		{"name": name}
	))
	variable_removed.emit(name)

func _on_manager_variable_changed(name: String, old_value: Variant, new_value: Variant) -> void:
	_log_debug(FuseLocalization.translate_format(
		"FUSE_LOG_GLOBAL_VAR_MANAGER_VARIABLE_CHANGED",
		{"name": name, "old": str(old_value), "new": str(new_value)}
	))
	variable_modified.emit(name, {"value": old_value}, {"value": new_value})

	# 检查是否是持久化变量，如果是则触发延迟保存
	var manager = GlobalVariableManager.get_instance()
	if manager != null:
		var variable = manager.get_variable(name)
		if variable != null and variable.persistent:
			_log_debug(FuseLocalization.translate_format(
				"FUSE_LOG_GLOBAL_VAR_PERSISTENT_CHANGED_DELAYED_SAVE",
				{"name": name}
			))
			_request_delayed_save()

## 核心方法

## 设置当前资源
func set_current_resource(resource: Resource) -> void:
	if resource == current_resource:
		return

	var old_resource = current_resource
	current_resource = resource

	resource_changed.emit(old_resource, current_resource)
	_log_info(FuseLocalization.translate_format(
		"FUSE_LOG_GLOBAL_VAR_RESOURCE_SWITCHED",
		{"old": old_resource, "new": current_resource}
	))

## 加载资源文件
func load_resource(path: String) -> bool:
	if path.is_empty():
		_log_error(FuseLocalization.translate("FUSE_ERROR_RESOURCE_PATH_EMPTY"))
		_create_fuse_error_localized("FUSE_ERROR_RESOURCE_PATH_EMPTY", FuseError.ErrorType.VALIDATION_ERROR)
		return false

	var manager = GlobalVariableManager.get_instance()
	if manager == null:
		_log_error(FuseLocalization.translate("FUSE_ERROR_GLOBAL_VAR_MANAGER_NOT_FOUND"))
		_create_fuse_error_localized("FUSE_ERROR_GLOBAL_VAR_MANAGER_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR)
		return false

	var success = manager.load_from_resource(path)
	load_completed.emit(success, path, current_resource)

	if success:
		resource_path = path
		_log_info(FuseLocalization.translate_format(
			"FUSE_LOG_GLOBAL_VAR_RESOURCE_LOADED_SIMPLE",
			{"path": path}
		))
	else:
		_log_error(FuseLocalization.translate_format(
			"FUSE_ERROR_RESOURCE_LOAD_FAILED",
			{"path": path}
		))

	return success

## 从 current_resource 加载变量到管理器
func _load_from_current_resource() -> bool:
	_log_info(FuseLocalization.translate(
		"FUSE_LOG_GLOBAL_VAR_CURRENT_RESOURCE_LOAD_STARTED"
	))
	_log_info("current_resource: %s" % str(current_resource))

	if current_resource == null:
		_log_error(FuseLocalization.translate(
			"FUSE_LOG_GLOBAL_VAR_CURRENT_RESOURCE_NOT_SET"
		))
		return false

	var manager = GlobalVariableManager.get_instance()
	if manager == null:
		_log_error(FuseLocalization.translate("FUSE_ERROR_GLOBAL_VAR_MANAGER_NOT_FOUND"))
		return false

	# 检查是否是 GlobalVariableResource 类型
	var gvr: GlobalVariableResource = null
	if current_resource is GlobalVariableResource:
		gvr = current_resource
		_log_info(FuseLocalization.translate(
			"FUSE_LOG_GLOBAL_VAR_CURRENT_RESOURCE_TYPE_OK"
		))
	else:
		_log_error(FuseLocalization.translate_format(
			"FUSE_LOG_GLOBAL_VAR_CURRENT_RESOURCE_WRONG_TYPE",
			{"class_name": current_resource.get_class()}
		))
		return false

	# 清空现有变量
	_log_info(FuseLocalization.translate("FUSE_LOG_GLOBAL_VAR_CLEARING_EXISTING"))
	manager.clear_all_variables()

	# 从 GlobalVariableResource 加载变量
	var var_names = gvr.get_variable_names()
	_log_info(FuseLocalization.translate_format(
		"FUSE_LOG_GLOBAL_VAR_RESOURCE_VARIABLE_LIST",
		{"names": str(var_names), "count": var_names.size()}
	))

	for var_name in var_names:
		var var_data = gvr.get_variable(var_name)
		_log_info(FuseLocalization.translate_format(
			"FUSE_LOG_GLOBAL_VAR_LOADING_VARIABLE",
			{"name": var_name, "type": typeof(var_data), "data": str(var_data)}
		))

		var variable = BaseVariable.new()
		variable.variable_name = var_name

		# 向后兼容：处理两种格式
		if var_data is Dictionary and var_data.has("value"):
			# 新格式：字典结构 {"value": ..., "scope": ..., ...}
			variable.value = var_data.get("value", null)
			variable.scope = var_data.get("scope", BaseVariable.VariableScope.LOCAL)
			variable.persistent = var_data.get("persistent", false)
			variable.description = var_data.get("description", "")
			_log_info("  -> " + FuseLocalization.translate_format(
				"FUSE_LOG_GLOBAL_VAR_NEW_FORMAT",
				{
					"value": str(variable.value),
					"scope": variable.scope,
					"persistent": variable.persistent
				}
			))
		else:
			# 旧格式：直接存储原始值
			variable.value = var_data
			variable.scope = BaseVariable.VariableScope.LOCAL
			variable.persistent = false
			variable.description = ""
			_log_info("  -> " + FuseLocalization.translate_format(
				"FUSE_LOG_GLOBAL_VAR_LEGACY_FORMAT",
				{"value": str(variable.value)}
			))

		manager.add_variable(var_name, variable)

	# 更新资源路径（如果可用）
	if not current_resource.resource_path.is_empty():
		resource_path = current_resource.resource_path
		_log_info(FuseLocalization.translate_format(
			"FUSE_LOG_GLOBAL_VAR_RESOURCE_PATH_UPDATED",
			{"path": resource_path}
		))

	_log_info(FuseLocalization.translate_format(
		"FUSE_LOG_GLOBAL_VAR_CURRENT_RESOURCE_LOAD_DONE",
		{"count": var_names.size()}
	))

	# 验证加载结果
	var loaded_names = manager.get_all_variable_names()
	_log_info(FuseLocalization.translate_format(
		"FUSE_LOG_GLOBAL_VAR_VERIFY_MANAGER_VARIABLES",
		{"names": str(loaded_names)}
	))

	return true

## 保存当前资源
func save_current_resource() -> bool:
	if current_resource == null:
		_log_error(FuseLocalization.translate("FUSE_ERROR_NO_CURRENT_RESOURCE_TO_SAVE"))
		_create_fuse_error_localized("FUSE_ERROR_NO_CURRENT_RESOURCE_TO_SAVE", FuseError.ErrorType.VALIDATION_ERROR)
		return false

	if resource_path.is_empty():
		_log_error(FuseLocalization.translate("FUSE_ERROR_RESOURCE_PATH_EMPTY"))
		_create_fuse_error_localized("FUSE_ERROR_RESOURCE_PATH_EMPTY", FuseError.ErrorType.VALIDATION_ERROR)
		return false

	var manager = GlobalVariableManager.get_instance()
	if manager == null:
		_log_error(FuseLocalization.translate("FUSE_ERROR_GLOBAL_VAR_MANAGER_NOT_FOUND"))
		_create_fuse_error_localized("FUSE_ERROR_GLOBAL_VAR_MANAGER_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR)
		return false

	var success = manager.save_to_resource(resource_path)
	save_completed.emit(success, resource_path)

	if success:
		_log_info(FuseLocalization.translate_format(
			"FUSE_LOG_GLOBAL_VAR_RESOURCE_SAVED",
			{"path": resource_path}
		))
	else:
		_log_error(FuseLocalization.translate_format(
			"FUSE_ERROR_RESOURCE_SAVE_FAILED",
			{"path": resource_path}
		))
		_create_fuse_error_localized("FUSE_ERROR_RESOURCE_SAVE_FAILED", FuseError.ErrorType.RUNTIME_ERROR, {"path": resource_path})

	return success

## 变量 CRUD（全部委托 _service → Manager）

func add_global_variable(name: String, variable: BaseVariable) -> bool:
	var ok = _service.add_global_variable(name, variable)
	if ok:
		variable_added.emit(name, {"name": name, "value": variable.value, "type": variable.get_type_name()})
	return ok

func remove_global_variable(name: String) -> bool:
	var ok = _service.remove_global_variable(name)
	if ok:
		variable_removed.emit(name)
	return ok

func get_global_variable(name: String) -> BaseVariable:
	return _service.get_global_variable(name)

func has_global_variable(name: String) -> bool:
	return _service.has_global_variable(name)

func get_all_global_variable_names() -> Array[String]:
	return _service.get_all_global_variable_names()

func get_all_global_variables_info() -> Dictionary:
	return _service.get_all_global_variables_info()

func get_current_resource_info() -> Dictionary:
	return {
		"path": resource_path,
		"variable_count": _service.get_variable_count(),
		"is_empty": _service.get_variable_count() == 0
	}

## 生命周期管理
func _enter_tree() -> void:
	_log_info(FuseLocalization.translate("FUSE_LOG_GLOBAL_VAR_ENTER_TREE_STARTED"))
	_log_info(FuseLocalization.translate_format(
		"FUSE_LOG_GLOBAL_VAR_NODE_ENTERED_TREE",
		{"name": name, "inside_tree": is_inside_tree()}
	))

	# 确保场景中的节点成为单例（优先级最高）
	if _instance == null or not is_instance_valid(_instance):
		_instance = self
		_log_info(FuseLocalization.translate_format(
			"FUSE_LOG_GLOBAL_VAR_INSTANCE_SET_IN_ENTER_TREE",
			{"name": name}
		))

	_log_info(FuseLocalization.translate("FUSE_LOG_GLOBAL_VAR_ENTER_TREE_DONE"))

func _exit_tree() -> void:
	_log_info(FuseLocalization.translate("FUSE_LOG_GLOBAL_VAR_EXIT_TREE_STARTED"))
	_log_info(FuseLocalization.translate_format(
		"FUSE_LOG_GLOBAL_VAR_NODE_EXITING_TREE",
		{"cleanup": cleanup_on_exit, "editor_hint": Engine.is_editor_hint()}
	))
	_log_info(FuseLocalization.translate_format(
		"FUSE_LOG_GLOBAL_VAR_EXIT_TREE_STATE",
		{"name": name, "inside_tree": is_inside_tree(), "path": resource_path}
	))

	# 执行保存和清理
	_perform_save_and_cleanup()

	_log_info(FuseLocalization.translate("FUSE_LOG_GLOBAL_VAR_EXIT_TREE_DONE"))

## 执行保存和清理操作
func _perform_save_and_cleanup() -> void:
	# 自动保存持久化变量（在清理之前）
	if auto_save and not resource_path.is_empty():
		_log_info(FuseLocalization.translate_format(
			"FUSE_LOG_GLOBAL_VAR_AUTO_SAVING",
			{"path": resource_path}
		))
		var save_success = _save_persistent_variables()
		if save_success:
			_log_info(FuseLocalization.translate("FUSE_LOG_GLOBAL_VAR_AUTO_SAVE_SUCCESS"))
		else:
			_log_error(FuseLocalization.translate("FUSE_LOG_GLOBAL_VAR_AUTO_SAVE_FAILED"))
	else:
		_log_info(FuseLocalization.translate_format(
			"FUSE_LOG_GLOBAL_VAR_AUTO_SAVE_SKIPPED",
			{"auto_save": auto_save, "path": resource_path}
		))

	# 清理非持久化变量（简化方案核心功能）
	if cleanup_on_exit:
		_log_info(FuseLocalization.translate("FUSE_LOG_GLOBAL_VAR_CLEANUP_CONDITION_MET"))
		_cleanup_non_persistent_variables()
	else:
		_log_info(FuseLocalization.translate_format(
			"FUSE_LOG_GLOBAL_VAR_CLEANUP_CONDITION_NOT_MET",
			{"cleanup": cleanup_on_exit, "editor_hint": Engine.is_editor_hint()}
		))

	if _is_registered:
		_log_info(FuseLocalization.translate("FUSE_LOG_GLOBAL_VAR_UNREGISTERING"))
		unregister_from_manager()
	else:
		_log_info(FuseLocalization.translate("FUSE_LOG_GLOBAL_VAR_UNREGISTER_SKIPPED"))

## 手动保存持久化变量（可在任意时刻调用）
func save_persistent_variables() -> bool:
	if resource_path.is_empty():
		_log_error(FuseLocalization.translate("FUSE_LOG_GLOBAL_VAR_RESOURCE_PATH_EMPTY_SAVE"))
		return false

	_log_info(FuseLocalization.translate_format(
		"FUSE_LOG_GLOBAL_VAR_MANUAL_SAVE",
		{"path": resource_path}
	))
	return _save_persistent_variables()

## 保存持久化变量到资源配置文件
func _save_persistent_variables() -> bool:
	_log_info(FuseLocalization.translate("FUSE_LOG_GLOBAL_VAR_SAVE_STARTED"))
	_log_info("resource_path: %s" % resource_path)

	var manager = GlobalVariableManager.get_instance()
	if manager == null:
		_log_error(FuseLocalization.translate("FUSE_LOG_GLOBAL_VAR_SAVE_MANAGER_NOT_FOUND"))
		return false

	# 统计持久化变量数量并打印详情
	var persistent_count = 0
	var variable_names = manager.get_all_variable_names()
	_log_info(FuseLocalization.translate_format(
		"FUSE_LOG_GLOBAL_VAR_MANAGER_VARIABLE_COUNT",
		{"count": variable_names.size()}
	))

	for variable_name in variable_names:
		var variable = manager.get_variable(variable_name)
		if variable != null:
			var is_persistent = variable.persistent
			_log_info("  " + FuseLocalization.translate_format(
				"FUSE_LOG_GLOBAL_VAR_VARIABLE_DETAIL",
				{"name": variable_name, "persistent": is_persistent, "value": str(variable.value)}
			))
			if is_persistent:
				persistent_count += 1

	if persistent_count == 0:
		_log_info(FuseLocalization.translate("FUSE_LOG_GLOBAL_VAR_NO_PERSISTENT_TO_SAVE"))
		return true

	_log_info(FuseLocalization.translate_format(
		"FUSE_LOG_GLOBAL_VAR_READY_TO_SAVE",
		{"count": persistent_count, "path": resource_path}
	))

	# 仅保存持久化变量，不保存运行时临时变量
	return manager.save_persistent_to_resource(resource_path)

## 清理非持久化变量（简化方案核心功能）
func _cleanup_non_persistent_variables() -> void:
	_log_info(FuseLocalization.translate("FUSE_LOG_GLOBAL_VAR_CLEANUP_STARTED"))

	var manager = GlobalVariableManager.get_instance()
	if manager == null:
		_log_error(FuseLocalization.translate("FUSE_LOG_GLOBAL_VAR_CLEANUP_MANAGER_NOT_FOUND"))
		return

	# 获取所有变量名称
	var variable_names = manager.get_all_variable_names()
	if variable_names.is_empty():
		_log_info(FuseLocalization.translate("FUSE_LOG_GLOBAL_VAR_NO_VARIABLES_TO_CLEAN"))
		return

	# 收集需要删除的非持久化变量
	var variables_to_remove: Array[String] = []

	for variable_name in variable_names:
		var variable = manager.get_variable(variable_name)
		if variable != null and not variable.persistent:
			variables_to_remove.append(variable_name)

	if variables_to_remove.is_empty():
		_log_info(FuseLocalization.translate("FUSE_LOG_GLOBAL_VAR_NO_NON_PERSISTENT_TO_CLEAN"))
		return

	_log_info(FuseLocalization.translate_format(
		"FUSE_LOG_GLOBAL_VAR_CLEANUP_BEGIN",
		{"count": variables_to_remove.size()}
	))

	# 删除非持久化变量
	var removal_errors: Array[String] = []
	for variable_name in variables_to_remove:
		if not manager.remove_variable(variable_name):
			removal_errors.append(variable_name)
			_log_error(FuseLocalization.translate_format(
				"FUSE_LOG_GLOBAL_VAR_REMOVE_FAILED",
				{"name": variable_name}
			))
		else:
			_log_debug(FuseLocalization.translate_format(
				"FUSE_LOG_GLOBAL_VAR_VARIABLE_CLEANED",
				{"name": variable_name}
			))

	if removal_errors.is_empty():
		_log_info(FuseLocalization.translate("FUSE_LOG_GLOBAL_VAR_CLEANUP_DONE"))
	else:
		_log_warning(FuseLocalization.translate_format(
			"FUSE_LOG_GLOBAL_VAR_CLEANUP_PARTIAL_FAILED",
			{"count": removal_errors.size()}
		))

	_log_info(FuseLocalization.translate("FUSE_LOG_GLOBAL_VAR_CLEANUP_FINISHED"))

## 辅助方法

## 创建新资源文件
func create_new_resource(path: String, description: String) -> bool:
	if path.is_empty():
		_log_error(FuseLocalization.translate("FUSE_ERROR_RESOURCE_PATH_EMPTY"))
		_create_fuse_error_localized("FUSE_ERROR_RESOURCE_PATH_EMPTY", FuseError.ErrorType.VALIDATION_ERROR)
		return false

	var manager = GlobalVariableManager.get_instance()
	if manager == null:
		_log_error(FuseLocalization.translate("FUSE_ERROR_GLOBAL_VAR_MANAGER_NOT_FOUND"))
		_create_fuse_error_localized("FUSE_ERROR_GLOBAL_VAR_MANAGER_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR)
		return false

	# 创建新资源
	var resource = Resource.new()
	resource.set_meta("description", description)
	resource.set_meta("version", "2.0")
	resource.set_meta("created_time", Time.get_ticks_msec() / 1000.0)

	# 保存资源
	var error = ResourceSaver.save(resource, path)
	if error != OK:
		_log_error(FuseLocalization.translate_format(
			"FUSE_ERROR_RESOURCE_CREATE_FAILED",
			{"path": path, "error_code": error}
		))
		_create_fuse_error_localized("FUSE_ERROR_RESOURCE_CREATE_FAILED", FuseError.ErrorType.RUNTIME_ERROR, {"path": path, "error_code": error})
		return false

	resource_path = path
	current_resource = resource
	_log_info(FuseLocalization.translate_format(
		"FUSE_LOG_GLOBAL_VAR_RESOURCE_CREATED",
		{"path": path}
	))
	return true

## 创建 FuseError 实例
func _create_fuse_error(message: String, error_type: FuseError.ErrorType = FuseError.ErrorType.RUNTIME_ERROR, context: Dictionary = {}):
	var error_context = context.duplicate()
	error_context["component"] = "GlobalVariableAssistant"
	error_context["node_name"] = name if is_inside_tree() else "未命名节点"
	error_context["resource_path"] = resource_path
	error_context["has_current_resource"] = current_resource != null
	error_context["is_registered"] = _is_registered

	_fuse_error = FuseError.create_with_context(error_type, "GlobalVariableAssistant", message, error_context)

## 创建本地化 FuseError 实例
##
## 参数：
## - message_key: String - 翻译键
## - error_type: FuseError.ErrorType - 错误类型
## - args: Dictionary - 翻译参数（可选）
## - context: Dictionary - 错误上下文（可选）
func _create_fuse_error_localized(
	message_key: String,
	error_type: FuseError.ErrorType = FuseError.ErrorType.RUNTIME_ERROR,
	args: Dictionary = {},
	context: Dictionary = {}
) -> void:
	# 尝试本地化错误消息
	var localized_message = message_key
	if _fuse_localization_class == null:
		_fuse_localization_class = load("res://addons/fuse/localization/fuse_localization.gd")

	# 确保翻译系统已初始化
	if _fuse_localization_class and _fuse_localization_class.has_method("init"):
		_fuse_localization_class.init()

	if _fuse_localization_class and _fuse_localization_class.has_method("translate_format"):
		if args.is_empty():
			localized_message = _fuse_localization_class.translate(message_key)
		else:
			localized_message = _fuse_localization_class.translate_format(message_key, args)
	else:
		# 回退：手动替换参数
		for key in args:
			localized_message = localized_message.replace("{%s}" % key, str(args[key]))

	# 创建 FuseError 实例
	var error_context = context.duplicate()
	error_context["message_key"] = message_key
	error_context["message_args"] = args
	error_context["component"] = "GlobalVariableAssistant"
	error_context["node_name"] = name if is_inside_tree() else "未命名节点"
	error_context["resource_path"] = resource_path
	error_context["has_current_resource"] = current_resource != null
	error_context["is_registered"] = _is_registered

	_fuse_error = FuseError.create_with_context(error_type, "GlobalVariableAssistant", localized_message, error_context)

## 获取 FuseError 实例
func get_fuse_error() -> FuseError:
	return _fuse_error

## 检查是否有 FuseError
func has_fuse_error() -> bool:
	return _fuse_error != null

## 日志方法 - 使用 FuseLogger 统一过滤，不再重复检查 log_level
func _log_debug(message: String) -> void:
	FuseLogger.log_debug("GlobalVariableAssistant", log_level, message, name if is_inside_tree() else "未命名节点")

func _log_info(message: String) -> void:
	FuseLogger.log_info("GlobalVariableAssistant", log_level, message, name if is_inside_tree() else "未命名节点")

func _log_warning(message: String) -> void:
	FuseLogger.log_warning("GlobalVariableAssistant", log_level, message, name if is_inside_tree() else "未命名节点")

func _log_error(message: String) -> void:
	FuseLogger.log_error("GlobalVariableAssistant", log_level, message, name if is_inside_tree() else "未命名节点")

## 析构函数
func _notification(what: int):
	# 处理窗口关闭请求 - 这在编辑器停止运行时更可靠
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_log_info(FuseLocalization.translate("FUSE_LOG_GLOBAL_VAR_WM_CLOSE_STARTED"))
		_perform_save_and_cleanup()
		return

	if what == NOTIFICATION_PREDELETE:
		if _is_registered:
			unregister_from_manager()
		# 清理 FuseError
		_fuse_error = null
