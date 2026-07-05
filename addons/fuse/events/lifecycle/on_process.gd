@tool
@icon("res://addons/fuse/icons/builtin/Loop.png")
extends BaseEvent
class_name OnProcess

## 每渲染帧触发的事件（⚠️ 性能影响极高）
##
## 此事件使用 _process(delta) 虚拟函数
## 建议仅在必要时使用，优先考虑 OnTimer 事件
## 如需物理帧处理，请使用 OnPhysicsProcess 事件
##
## 🔄 迁移状态：已迁移到 RuntimeInstance 自声明状态模式
## 🔄 迁移日期：2025-02-03
## 🔄 简化改造：2026-03-13 - 移除 physics_process 模式，专注于 _process

## 执行间隔（秒），默认 0.016 秒（60 FPS）
## ⚠️ 重要：此参数用于控制性能，默认值已优化，不建议设置过低
@export_range(0.0, 10.0, 0.001) var execution_interval: float = 0.016:
	set(value):
		execution_interval = value
		_update_resource_name()

## 获取默认运行时状态
##
## 运行时状态自声明模式，避免不必要的变量复制
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["time_since_last_trigger"] = 0.0
	base["owner_node_ref"] = null
	base["is_processing"] = false
	base["is_monitoring"] = false
	return base

## 更新资源名称（必需）
func _update_resource_name() -> void:
	var interval_text = ""
	if execution_interval > 0.0:
		interval_text = FuseLocalization.translate_format("FUSE_DESC_PROCESS_MONITOR", {"interval": str(execution_interval)})
	else:
		interval_text = FuseLocalization.translate("FUSE_DESC_PROCESS_EVERY")

	resource_name = FuseLocalization.translate_format("FUSE_EVENT_ON_PROCESS_RESOURCE_NAME", {"interval": interval_text})

## 使用 RuntimeInstance 初始化事件
##
## 运行时实例优化模式，避免不必要的资源复制
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 🔧 通过 RuntimeInstance 获取状态引用
	var runtime_state = runtime_instance.runtime_state
	runtime_state["owner_node_ref"] = owner_node

	# 🔧 启用 Trigger 节点的进程处理（必须显式启用）
	# Trigger 的 _process 会调用 on_process 方法
	owner_node.set_process(true)

	# 设置进程处理
	_setup_processing_with_runtime_state(runtime_state)
	runtime_state["is_monitoring"] = true

	if not owner_node.tree_entered.is_connected(_on_tree_entered):
		owner_node.tree_entered.connect(_on_tree_entered)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 初始化事件监听（必需） - 向后兼容
func initialize(owner_node: Node) -> void:
	# 🔧 创建临时 RuntimeInstance 以支持遗留代码
	var temp_runtime_instance = RuntimeEventInstance.new(self, owner_node)
	initialize_with_runtime_instance(owner_node, temp_runtime_instance)

## 设置进程处理 - 兼容版本（使用旧变量）
func _setup_processing() -> void:
	var runtime_state = get_runtime_state()
	if not runtime_state.get("owner_node_ref"):
		return

	runtime_state["is_processing"] = true

## 设置进程处理 - 运行时状态版本
func _setup_processing_with_runtime_state(runtime_state: Dictionary) -> void:
	if not runtime_state.get("owner_node_ref"):
		return

	runtime_state["is_processing"] = true

## 获取运行时状态辅助方法
func get_runtime_state(runtime_instance: RuntimeEventInstance = null) -> Dictionary:
	var rt = get_runtime_instance_with_fallback(runtime_instance)
	if rt and rt.runtime_state:
		return rt.runtime_state
	return {}

## 当节点进入场景树
func _on_tree_entered() -> void:
	_setup_processing()

## 🔧 帧处理（由 Trigger._process 调用）
##
## Trigger 节点的 _process(delta) 会调用此方法
## 这是正确的方法：通过 Trigger 转发帧回调到 Event 资源
## 🔧 runtime_instance 参数让 Event 使用正确的运行时状态
func on_process(delta: float, runtime_instance: RuntimeEventInstance = null) -> void:
	# 🔧 编辑器模式下跳过
	if Engine.is_editor_hint():
		return

	# 🔍 性能追踪：开始
	_start_performance_track("on_process")

	var runtime_state = get_runtime_state(runtime_instance)
	var is_monitoring = runtime_state.get("is_monitoring", false)
	var is_processing = runtime_state.get("is_processing", false)

	if not is_monitoring or not is_processing:
		# 🔍 性能追踪：结束（未监控）
		_stop_performance_track("on_process")
		return

	# 检查执行间隔
	if execution_interval > 0.0:
		var time_since_last_trigger = runtime_state.get("time_since_last_trigger", 0.0)
		time_since_last_trigger += delta
		if time_since_last_trigger < execution_interval:
			runtime_state["time_since_last_trigger"] = time_since_last_trigger
			# 🔍 性能追踪：结束（间隔未到）
			_stop_performance_track("on_process")
			return
		runtime_state["time_since_last_trigger"] = 0.0

	_trigger_event(delta, runtime_instance)

	# 🔍 性能追踪：结束
	_stop_performance_track("on_process")

## 触发事件
func _trigger_event(delta: float, runtime_instance: RuntimeEventInstance = null) -> void:
	# 🔍 性能追踪：开始（追踪实际触发次数）
	_start_performance_track("_trigger_event")

	var interval_text = ""
	if execution_interval > 0.0:
		interval_text = str(execution_interval)
	else:
		interval_text = FuseLocalization.translate("FUSE_DESC_PROCESS_EVERY")

	_log_debug_localized("FUSE_LOG_EVENT_PROCESS_TRIGGERED", {
		"delta": str(delta),
		"interval": interval_text
	})

	# 🔧 发出 owner node 作为上下文，并设置 meta 数据
	# 🔧 修复：使用传入的 runtime_instance 获取正确的运行时状态
	var owner_node_ref = get_runtime_state(runtime_instance).get("owner_node_ref")
	if owner_node_ref:
		# 使用 set_meta 将 delta 传递给 Trigger
		owner_node_ref.set_meta("delta_time", delta)
		owner_node_ref.set_meta("trigger", owner_node_ref)

		triggered.emit(owner_node_ref)

	# 🔍 性能追踪：结束
	_stop_performance_track("_trigger_event")

## 清理事件监听（必需）
##
## 🔧 修复说明：
## 在对象池场景中，Trigger._on_pool_reset() 会在调用此方法之前设置正确的 _runtime_instance_ref
## 因此这里直接使用 get_runtime_state() 即可获取正确的运行时状态
func terminate(owner_node: Node) -> void:
	# 断开信号连接（检查 owner_node 和信号是否有效）
	if owner_node and is_instance_valid(owner_node):
		if owner_node.tree_entered.is_connected(_on_tree_entered):
			owner_node.tree_entered.disconnect(_on_tree_entered)
		# 🔧 禁用 Trigger 节点的进程处理
		owner_node.set_process(false)

	# 🔧 使用 get_runtime_state() 获取运行时状态
	# 由于 Trigger._on_pool_reset() 已预先设置 _runtime_instance_ref，
	# 这里会正确地操作对应 Trigger 的运行时实例状态
	if _runtime_instance_ref != null:
		var runtime_state = get_runtime_state()
		runtime_state["is_monitoring"] = false
		runtime_state["is_processing"] = false
		runtime_state["time_since_last_trigger"] = 0.0
		runtime_state["owner_node_ref"] = null

		_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 获取事件描述
func get_description() -> String:
	var interval_text = ""
	if execution_interval > 0.0:
		interval_text = FuseLocalization.translate_format("FUSE_DESC_PROCESS_INTERVAL_FRAME", {"interval": str(execution_interval)})
	else:
		interval_text = FuseLocalization.translate("FUSE_DESC_PROCESS_EVERY_FRAME")

	return FuseLocalization.translate_format("FUSE_EVENT_ON_PROCESS_DESC", {"interval": interval_text})

## 获取事件类型
func get_event_type() -> String:
	return "process"

## 获取事件分类
func get_event_category() -> String:
	return "lifecycle"

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	if execution_interval < 0.0:
		errors.append(FuseLocalization.translate_format("FUSE_ERROR_PROCESS_INTERVAL_INVALID", {"interval": str(execution_interval)}))

	return errors

## 重置事件状态
##
## 🔧 修复说明：
## 在对象池场景中，Trigger._on_pool_reset() 会在调用此方法之前设置正确的 _runtime_instance_ref
## 因此这里直接使用 get_runtime_state() 即可获取正确的运行时状态
func reset() -> void:
	super.reset()

	# 🔧 使用 get_runtime_state() 获取运行时状态
	# 由于 Trigger._on_pool_reset() 已预先设置 _runtime_instance_ref，
	# 这里会正确地操作对应 Trigger 的运行时实例状态
	if _runtime_instance_ref != null:
		var runtime_state = get_runtime_state()
		runtime_state["is_monitoring"] = false
		runtime_state["time_since_last_trigger"] = 0.0
		runtime_state["is_processing"] = false

		# 重新设置进程处理
		var owner_node_ref = runtime_state.get("owner_node_ref")
		if owner_node_ref and is_instance_valid(owner_node_ref):
			_setup_processing_with_runtime_state(runtime_state)

		_log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_ON_PROCESS_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_LIFECYCLE"
	metadata.description_key = "FUSE_EVENT_ON_PROCESS_DESC"
	metadata.keywords = ["process", "处理", "frame", "帧", "update", "更新", "loop", "循环", "tick", "计时"]
	metadata.builtin_icon = "Loop"
	return metadata
