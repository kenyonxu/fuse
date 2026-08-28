@tool
@icon("res://addons/fuse/icons/builtin/ProgressBar.png")
extends BaseEvent
class_name OnBackgroundLoadProgress

## Event: OnBackgroundLoadProgress
##
## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - _last_progress: float - 上次加载进度
## - _is_monitoring: bool - 是否正在监控加载状态
## - _load_started: bool - 是否已经开始加载
##
## 架构版本: 自声明状态模式 v2.0
## 相关文档: addons/fuse/docs/migration-guide-to-runtime-instance.md
##
## 后台加载进度事件
##
## 使用 ResourceLoader.load_threaded() 异步加载资源，定期检查加载进度并在超过阈值时触发。

## 资源路径
@export var load_resource_path: String = "":
	set(value):
		load_resource_path = value
		_update_resource_name()

## 检查间隔（秒）
@export var check_interval: float = 0.1:
	set(value):
		check_interval = value
		_update_resource_name()

## 进度阈值（0-1）
@export_range(0.0, 1.0) var progress_threshold: float = 0.1:
	set(value):
		progress_threshold = value
		_update_resource_name()

## 是否传递进度值
@export var emit_progress: bool = true

## 内部变量
var _timer: Timer = null

## 更新资源名称（必需）
func _update_resource_name():
	var path_text = load_resource_path if not load_resource_path.is_empty() else FuseLocalization.translate("FUSE_TEXT_NOT_SPECIFIED")
	resource_name = FuseLocalization.translate_format("FUSE_EVENT_ON_BACKGROUND_LOAD_PROGRESS_RESOURCE_NAME", {
		"path": path_text,
		"threshold": progress_threshold * 100
	})

## 初始化事件监听（必需）
func initialize(owner_node: Node) -> void:
	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

	# 验证 owner_node
	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 验证资源路径
	if load_resource_path.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_RESOURCE_PATH_EMPTY", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 验证文件是否存在
	if not FileAccess.file_exists(load_resource_path):
		_create_fuse_error_localized("FUSE_ERROR_RESOURCE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"resource_path": load_resource_path})
		return

	# 验证检查间隔
	if check_interval <= 0:
		_create_fuse_error_localized("FUSE_ERROR_INVALID_CHECK_INTERVAL", FuseError.ErrorType.CONFIGURATION_ERROR, {"check_interval": check_interval})
		return

	# 启动后台加载
	_start_background_load(owner_node)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 初始化 RuntimeInstance（必需）
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		return

	_runtime_instance_ref = runtime_instance

	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 从 RuntimeInstance 初始化状态
	if _runtime_instance_ref:
		# get_runtime_state 返回 Variant（默认态是 float/bool 等标量），
		# 判存在须用 has_runtime_state——对取值调 is_valid() 是类型混淆必崩
		if not _runtime_instance_ref.has_runtime_state("last_progress"):
			_runtime_instance_ref.set_runtime_state("last_progress", 0.0)
		if not _runtime_instance_ref.has_runtime_state("is_monitoring"):
			_runtime_instance_ref.set_runtime_state("is_monitoring", false)
		if not _runtime_instance_ref.has_runtime_state("load_started"):
			_runtime_instance_ref.set_runtime_state("load_started", false)

	# 运行时路径与旧入口对齐：校验 + 启动后台加载与轮询 Timer
	# （迁移 RuntimeInstance 时漏移植启动逻辑，事件此前在此路径下永不监控）
	initialize(owner_node)

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	# 清理 RuntimeEventInstance 状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("is_monitoring", false)
		_runtime_instance_ref.set_runtime_state("load_started", false)
		_runtime_instance_ref.set_runtime_state("last_progress", 0.0)

	# 清理定时器
	_cleanup_timer(owner_node)

	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 启动后台加载
func _start_background_load(owner_node: Node) -> void:
	# 请求后台加载
	ResourceLoader.load_threaded_request(load_resource_path)

	# 更新 RuntimeInstance 状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("load_started", true)
		_runtime_instance_ref.set_runtime_state("is_monitoring", true)
		_runtime_instance_ref.set_runtime_state("last_progress", 0.0)

	# 创建定时器定期检查进度
	_cleanup_timer(owner_node)

	_timer = Timer.new()
	_timer.wait_time = check_interval
	_timer.one_shot = false
	_timer.timeout.connect(_on_timer_timeout)
	_timer.autostart = true

	owner_node.add_child(_timer)
	_timer.start()

	_log_debug_localized("FUSE_LOG_EVENT_BACKGROUND_LOAD_STARTED", {
		"resource_path": load_resource_path,
		"check_interval": check_interval
	})

## 清理定时器
func _cleanup_timer(owner_node: Node) -> void:
	if _timer:
		_timer.stop()

		if _timer.timeout.is_connected(_on_timer_timeout):
			_timer.timeout.disconnect(_on_timer_timeout)

		if owner_node and is_instance_valid(owner_node):
			owner_node.remove_child(_timer)

		_timer.queue_free()
		_timer = null

## 定时器超时回调
func _on_timer_timeout():
	# 从 RuntimeInstance 获取状态
	var is_monitoring = false
	var load_started = false

	if _runtime_instance_ref:
		is_monitoring = _runtime_instance_ref.get_runtime_state("is_monitoring")
		load_started = _runtime_instance_ref.get_runtime_state("load_started")

	if not is_monitoring or not load_started:
		return

	# 检查加载状态
	var status = ResourceLoader.load_threaded_get_status(load_resource_path)
	var progress: float = 0.0

	# 根据状态判断进度
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			# 加载中，由于无法直接获取进度，使用估算值
			# 每次检查增加一个小进度，直到完成
			var last_progress = 0.0
			if _runtime_instance_ref:
				last_progress = _runtime_instance_ref.get_runtime_state("last_progress")

			progress = min(last_progress + progress_threshold, 0.95)

			# 更新 RuntimeInstance 状态
			if _runtime_instance_ref:
				_runtime_instance_ref.set_runtime_state("last_progress", progress)

			# 触发进度更新（如果需要）
			if progress >= progress_threshold:
				_trigger_with_progress(progress)
		ResourceLoader.THREAD_LOAD_LOADED:
			# 加载完成
			progress = 1.0
			_trigger_with_progress(progress)

			# 更新 RuntimeInstance 状态
			if _runtime_instance_ref:
				_runtime_instance_ref.set_runtime_state("is_monitoring", false)
		ResourceLoader.THREAD_LOAD_FAILED:
			# 加载失败
			_log_warning_localized("FUSE_LOG_EVENT_BACKGROUND_LOAD_FAILED", {"resource_path": load_resource_path})

			# 更新 RuntimeInstance 状态
			if _runtime_instance_ref:
				_runtime_instance_ref.set_runtime_state("is_monitoring", false)
		_:
			# 其他状态（THREAD_LOAD_INVALID_RESOURCE 或 THREAD_LOAD_IN_PROGRESS）
			pass

## 触发事件并传递进度值
func _trigger_with_progress(progress: float):
	# 从 RuntimeInstance 获取状态
	var is_monitoring = true
	if _runtime_instance_ref:
		is_monitoring = _runtime_instance_ref.get_runtime_state("is_monitoring")

	if not is_monitoring:
		return

	_log_info_localized("FUSE_LOG_EVENT_BACKGROUND_LOAD_PROGRESS", {
		"resource_path": load_resource_path,
		"progress": progress * 100
	})

	# 更新上次进度
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("last_progress", progress)

	# 传递进度值（如果需要）
	if emit_progress:
		# 创建一个临时节点来传递进度值
		var context_node = Node.new()
		context_node.name = "ProgressContext"
		context_node.set_meta("progress", progress)
		context_node.set_meta("resource_path", load_resource_path)
		triggered.emit(context_node)
		# 临时节点会在 Trigger 中被释放
	else:
		triggered.emit(null)

## 获取事件描述
func get_description() -> String:
	var threshold_text = "%.0f%%" % (progress_threshold * 100)
	var interval_text = "%.2fs" % check_interval
	return FuseLocalization.translate_format("FUSE_EVENT_ON_BACKGROUND_LOAD_PROGRESS_DESC_FORMAT", {
		"resource_path": load_resource_path,
		"threshold": threshold_text,
		"interval": interval_text
	})

## 获取事件类型
func get_event_type() -> String:
	return "background_load_progress"

## 获取事件分类
func get_event_category() -> String:
	return "scene"

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	# 验证资源路径
	if load_resource_path.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_RESOURCE_PATH_EMPTY"))

	# 验证检查间隔
	if check_interval <= 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_INVALID_CHECK_INTERVAL"))

	# 验证进度阈值范围
	if progress_threshold < 0.0 or progress_threshold > 1.0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_INVALID_PROGRESS_THRESHOLD"))

	return errors

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["last_progress"] = 0.0
	base["is_monitoring"] = false
	base["load_started"] = false
	return base

## 重置事件状态
func reset() -> void:
	super.reset()
	# 清理 RuntimeEventInstance 状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("last_progress", 0.0)
		_runtime_instance_ref.set_runtime_state("is_monitoring", false)
		_runtime_instance_ref.set_runtime_state("load_started", false)
	_log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_ON_BACKGROUND_LOAD_PROGRESS_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_SCENE"
	metadata.description_key = "FUSE_EVENT_ON_BACKGROUND_LOAD_PROGRESS_DESC"
	metadata.keywords = ["background", "后台", "load", "加载", "progress", "进度", "async", "异步", "threaded", "线程", "resource", "资源"]
	metadata.builtin_icon = "ProgressBar"
	return metadata
