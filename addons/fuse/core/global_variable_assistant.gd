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
	_log_info("=== READY 通知触发 ===")
	_log_info("节点准备完成 - name: %s, is_inside_tree: %s, auto_register: %s" % [name, is_inside_tree(), auto_register])

	# 创建自动保存计时器
	_setup_save_timer()

	if auto_register:
		_log_info("开始注册到管理器")
		register_to_manager()
	else:
		_log_info("跳过注册 - auto_register: %s" % auto_register)

	# 加载资源：优先使用 resource_path，如果为空则检查 current_resource
	if auto_load_on_ready:
		if not resource_path.is_empty():
			_log_info("自动加载资源（从路径）: %s" % resource_path)
			load_resource(resource_path)
		elif current_resource != null:
			_log_info("自动加载资源（从 current_resource）: %s" % current_resource.resource_path)
			_load_from_current_resource()
		else:
			_log_info("跳过自动加载 - resource_path 为空且 current_resource 未设置")
	else:
		_log_info("跳过自动加载 - auto_load_on_ready: %s" % auto_load_on_ready)

	_is_initialized = true
	_log_info("=== READY 通知处理完成 ===")

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
	_log_info("自动保存计时器已创建，延迟: %s 秒" % auto_save_delay)

## 保存计时器超时回调
func _on_save_timer_timeout() -> void:
	if not _pending_save:
		return

	_pending_save = false
	_log_info("延迟保存触发，开始保存持久化变量")
	_save_persistent_variables()

## 请求延迟保存
func _request_delayed_save() -> void:
	if not auto_save_on_change or resource_path.is_empty():
		return

	_pending_save = true

	# 如果计时器存在且未运行，启动计时器
	if _save_timer != null and _save_timer.is_stopped():
		_save_timer.start()
		_log_debug("已请求延迟保存，将在 %.1f 秒后执行" % auto_save_delay)

## 注册到全局变量管理器
func register_to_manager() -> bool:
	var manager = GlobalVariableManager.get_instance()
	if manager == null:
		_log_error("无法获取全局变量管理器实例")
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
	_log_info("成功注册到全局变量管理器")
	return true

## 从全局变量管理器注销
func unregister_from_manager() -> bool:
	var manager = GlobalVariableManager.get_instance()
	if manager == null:
		_log_warning("注销时无法获取全局变量管理器实例")
		return false

	# 断开管理器信号
	if manager.variable_added.is_connected(_on_manager_variable_added):
		manager.variable_added.disconnect(_on_manager_variable_added)
	if manager.variable_removed.is_connected(_on_manager_variable_removed):
		manager.variable_removed.disconnect(_on_manager_variable_removed)
	if manager.variable_changed.is_connected(_on_manager_variable_changed):
		manager.variable_changed.disconnect(_on_manager_variable_changed)

	_is_registered = false
	_log_info("成功从全局变量管理器注销")
	return true

## 全局变量变化回调
func on_global_variables_changed() -> void:
	_log_debug("全局变量已变化")

## 管理器信号处理方法
func _on_manager_variable_added(name: String, variable: BaseVariable) -> void:
	_log_debug("管理器变量添加: %s" % name)
	variable_added.emit(name, {"name": name, "value": variable.value, "type": variable.get_type_name()})

	# 如果是持久化变量，触发延迟保存
	if variable.persistent:
		_log_debug("持久化变量 '%s' 已添加，请求延迟保存" % name)
		_request_delayed_save()

func _on_manager_variable_removed(name: String) -> void:
	_log_debug("管理器变量移除: %s" % name)
	variable_removed.emit(name)

func _on_manager_variable_changed(name: String, old_value: Variant, new_value: Variant) -> void:
	_log_debug("管理器变量变化: %s (%s -> %s)" % [name, str(old_value), str(new_value)])
	variable_modified.emit(name, {"value": old_value}, {"value": new_value})

	# 检查是否是持久化变量，如果是则触发延迟保存
	var manager = GlobalVariableManager.get_instance()
	if manager != null:
		var variable = manager.get_variable(name)
		if variable != null and variable.persistent:
			_log_debug("持久化变量 '%s' 已变化，请求延迟保存" % name)
			_request_delayed_save()

## 核心方法

## 设置当前资源
func set_current_resource(resource: Resource) -> void:
	if resource == current_resource:
		return

	var old_resource = current_resource
	current_resource = resource

	resource_changed.emit(old_resource, current_resource)
	_log_info("资源已切换: %s -> %s" % [old_resource, current_resource])

## 加载资源文件
func load_resource(path: String) -> bool:
	if path.is_empty():
		_log_error("资源路径不能为空")
		_create_fuse_error_localized("FUSE_ERROR_RESOURCE_PATH_EMPTY", FuseError.ErrorType.VALIDATION_ERROR)
		return false

	var manager = GlobalVariableManager.get_instance()
	if manager == null:
		_log_error("无法获取全局变量管理器实例")
		_create_fuse_error_localized("FUSE_ERROR_GLOBAL_VAR_MANAGER_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR)
		return false

	var success = manager.load_from_resource(path)
	load_completed.emit(success, path, current_resource)

	if success:
		resource_path = path
		_log_info("资源加载成功: %s" % path)
	else:
		_log_error("资源加载失败: %s" % path)

	return success

## 从 current_resource 加载变量到管理器
func _load_from_current_resource() -> bool:
	_log_info("=== 开始从 current_resource 加载变量 ===")
	_log_info("current_resource: %s" % str(current_resource))

	if current_resource == null:
		_log_error("current_resource 未设置")
		return false

	var manager = GlobalVariableManager.get_instance()
	if manager == null:
		_log_error("无法获取全局变量管理器实例")
		return false

	# 检查是否是 GlobalVariableResource 类型
	var gvr: GlobalVariableResource = null
	if current_resource is GlobalVariableResource:
		gvr = current_resource
		_log_info("current_resource 类型验证通过: GlobalVariableResource")
	else:
		_log_error("current_resource 不是 GlobalVariableResource 类型: %s" % current_resource.get_class())
		return false

	# 清空现有变量
	_log_info("清空现有变量...")
	manager.clear_all_variables()

	# 从 GlobalVariableResource 加载变量
	var var_names = gvr.get_variable_names()
	_log_info("资源中的变量列表: %s (共 %d 个)" % [str(var_names), var_names.size()])

	for var_name in var_names:
		var var_data = gvr.get_variable(var_name)
		_log_info("加载变量 '%s', 数据类型: %s, 数据内容: %s" % [var_name, typeof(var_data), str(var_data)])

		var variable = BaseVariable.new()
		variable.variable_name = var_name

		# 向后兼容：处理两种格式
		if var_data is Dictionary and var_data.has("value"):
			# 新格式：字典结构 {"value": ..., "scope": ..., ...}
			variable.value = var_data.get("value", null)
			variable.scope = var_data.get("scope", BaseVariable.VariableScope.LOCAL)
			variable.persistent = var_data.get("persistent", false)
			variable.description = var_data.get("description", "")
			_log_info("  -> 新格式: value=%s, scope=%s, persistent=%s" % [str(variable.value), variable.scope, variable.persistent])
		else:
			# 旧格式：直接存储原始值
			variable.value = var_data
			variable.scope = BaseVariable.VariableScope.LOCAL
			variable.persistent = false
			variable.description = ""
			_log_info("  -> 旧格式: value=%s" % str(variable.value))

		manager.add_variable(var_name, variable)

	# 更新资源路径（如果可用）
	if not current_resource.resource_path.is_empty():
		resource_path = current_resource.resource_path
		_log_info("更新 resource_path: %s" % resource_path)

	_log_info("=== 从 current_resource 加载完成，共 %d 个变量 ===" % var_names.size())

	# 验证加载结果
	var loaded_names = manager.get_all_variable_names()
	_log_info("验证 - GlobalVariableManager 中的变量: %s" % str(loaded_names))

	return true

## 保存当前资源
func save_current_resource() -> bool:
	if current_resource == null:
		_log_error("没有当前资源可保存")
		_create_fuse_error_localized("FUSE_ERROR_NO_CURRENT_RESOURCE_TO_SAVE", FuseError.ErrorType.VALIDATION_ERROR)
		return false

	if resource_path.is_empty():
		_log_error("资源路径为空")
		_create_fuse_error_localized("FUSE_ERROR_RESOURCE_PATH_EMPTY", FuseError.ErrorType.VALIDATION_ERROR)
		return false

	var manager = GlobalVariableManager.get_instance()
	if manager == null:
		_log_error("无法获取全局变量管理器实例")
		_create_fuse_error_localized("FUSE_ERROR_GLOBAL_VAR_MANAGER_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR)
		return false

	var success = manager.save_to_resource(resource_path)
	save_completed.emit(success, resource_path)

	if success:
		_log_info("资源保存成功: %s" % resource_path)
	else:
		_log_error("资源保存失败: %s" % resource_path)
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
	_log_info("=== ENTER_TREE 通知触发 ===")
	_log_info("节点进入场景树 - name: %s, is_inside_tree: %s" % [name, is_inside_tree()])

	# 确保场景中的节点成为单例（优先级最高）
	if _instance == null or not is_instance_valid(_instance):
		_instance = self
		_log_info("在 _enter_tree() 中设置场景节点为单例: %s" % name)

	_log_info("=== ENTER_TREE 通知处理完成 ===")

func _exit_tree() -> void:
	_log_info("=== EXIT_TREE 通知触发 ===")
	_log_info("节点即将退出场景树 - cleanup_on_exit: %s, is_editor_hint: %s" % [cleanup_on_exit, Engine.is_editor_hint()])
	_log_info("当前节点状态 - name: %s, is_inside_tree: %s, resource_path: %s" % [name, is_inside_tree(), resource_path])

	# 执行保存和清理
	_perform_save_and_cleanup()

	_log_info("=== EXIT_TREE 通知处理完成 ===")

## 执行保存和清理操作
func _perform_save_and_cleanup() -> void:
	# 自动保存持久化变量（在清理之前）
	if auto_save and not resource_path.is_empty():
		_log_info("自动保存持久化变量到: %s" % resource_path)
		var save_success = _save_persistent_variables()
		if save_success:
			_log_info("自动保存成功")
		else:
			_log_error("自动保存失败")
	else:
		_log_info("跳过自动保存 - auto_save: %s, resource_path: %s" % [auto_save, resource_path])

	# 清理非持久化变量（简化方案核心功能）
	if cleanup_on_exit:
		_log_info("条件满足，开始清理非持久化变量")
		_cleanup_non_persistent_variables()
	else:
		_log_info("清理条件不满足 - cleanup_on_exit: %s, is_editor_hint: %s" % [cleanup_on_exit, Engine.is_editor_hint()])

	if _is_registered:
		_log_info("节点已注册，开始注销")
		unregister_from_manager()
	else:
		_log_info("节点未注册，跳过注销")

## 手动保存持久化变量（可在任意时刻调用）
func save_persistent_variables() -> bool:
	if resource_path.is_empty():
		_log_error("资源路径为空，无法保存")
		return false

	_log_info("手动保存持久化变量到: %s" % resource_path)
	return _save_persistent_variables()

## 保存持久化变量到资源配置文件
func _save_persistent_variables() -> bool:
	_log_info("=== _save_persistent_variables() 开始 ===")
	_log_info("resource_path: %s" % resource_path)

	var manager = GlobalVariableManager.get_instance()
	if manager == null:
		_log_error("无法获取全局变量管理器实例，跳过保存")
		return false

	# 统计持久化变量数量并打印详情
	var persistent_count = 0
	var variable_names = manager.get_all_variable_names()
	_log_info("管理器中共有 %d 个变量" % variable_names.size())

	for variable_name in variable_names:
		var variable = manager.get_variable(variable_name)
		if variable != null:
			var is_persistent = variable.persistent
			_log_info("  变量 '%s': persistent=%s, value=%s" % [variable_name, is_persistent, str(variable.value)])
			if is_persistent:
				persistent_count += 1

	if persistent_count == 0:
		_log_info("没有持久化变量需要保存")
		return true

	_log_info("准备保存 %d 个持久化变量到: %s" % [persistent_count, resource_path])

	# 仅保存持久化变量，不保存运行时临时变量
	return manager.save_persistent_to_resource(resource_path)

## 清理非持久化变量（简化方案核心功能）
func _cleanup_non_persistent_variables() -> void:
	_log_info("=== 开始清理非持久化变量 ===")

	var manager = GlobalVariableManager.get_instance()
	if manager == null:
		_log_error("无法获取全局变量管理器实例，跳过清理")
		return

	# 获取所有变量名称
	var variable_names = manager.get_all_variable_names()
	if variable_names.is_empty():
		_log_info("没有变量需要清理")
		return

	# 收集需要删除的非持久化变量
	var variables_to_remove: Array[String] = []

	for variable_name in variable_names:
		var variable = manager.get_variable(variable_name)
		if variable != null and not variable.persistent:
			variables_to_remove.append(variable_name)

	if variables_to_remove.is_empty():
		_log_info("没有非持久化变量需要清理")
		return

	_log_info("开始清理非持久化变量，共 %d 个" % variables_to_remove.size())

	# 删除非持久化变量
	var removal_errors: Array[String] = []
	for variable_name in variables_to_remove:
		if not manager.remove_variable(variable_name):
			removal_errors.append(variable_name)
			_log_error("无法移除变量: %s" % variable_name)
		else:
			_log_debug("成功清理非持久化变量: %s" % variable_name)

	if removal_errors.is_empty():
		_log_info("非持久化变量清理完成")
	else:
		_log_warning("部分变量清理失败: %d 个" % removal_errors.size())

	_log_info("=== 清理非持久化变量完成 ===")

## 辅助方法

## 创建新资源文件
func create_new_resource(path: String, description: String) -> bool:
	if path.is_empty():
		_log_error("资源路径不能为空")
		_create_fuse_error_localized("FUSE_ERROR_RESOURCE_PATH_EMPTY", FuseError.ErrorType.VALIDATION_ERROR)
		return false

	var manager = GlobalVariableManager.get_instance()
	if manager == null:
		_log_error("无法获取全局变量管理器实例")
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
		_log_error("资源创建失败: %s (错误码: %d)" % [path, error])
		_create_fuse_error_localized("FUSE_ERROR_RESOURCE_CREATE_FAILED", FuseError.ErrorType.RUNTIME_ERROR, {"path": path, "error_code": error})
		return false

	resource_path = path
	current_resource = resource
	_log_info("资源创建成功: %s" % path)
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
		_log_info("=== WM_CLOSE_REQUEST 通知触发 ===")
		_perform_save_and_cleanup()
		return

	if what == NOTIFICATION_PREDELETE:
		if _is_registered:
			unregister_from_manager()
		# 清理 FuseError
		_fuse_error = null
