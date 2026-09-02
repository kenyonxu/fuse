@icon("res://addons/fuse/icons/builtin/CheckBox.png")
# 文件：addons/fuse/events/on_ready.gd
@tool
class_name OnReady extends BaseEvent

## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - _timer: Timer - 定时器节点（已迁移到 RuntimeInstance 状态）
##
## 相关文档: addons/fuse/docs/zh_CN/dev_docs/guides/runtime-instance-migration-guide.md

## 延迟触发时间（秒），0表示立即触发
@export var delay_seconds: float = 0.0:
	set(value):
		delay_seconds = value
		_update_resource_name()

# RuntimeInstance 引用 - 管理事件运行时状态（从 BaseEvent 继承）

## 获取默认的运行时状态
func get_default_runtime_state() -> Dictionary:
	return {
		"timer_node": null,  # Timer 节点引用
		"timer_connected": false,  # 定时器是否已连接
		"should_trigger_immediately": delay_seconds == 0.0  # 是否应该立即触发
	}

## 使用 RuntimeInstance 初始化事件
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	_runtime_instance_ref = runtime_instance

	# 检查 owner_node 是否有效
	if not owner_node:
		_log_error("Owner node is null in OnReady")
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 等待场景就绪后再触发
	if owner_node.is_inside_tree():
		# 如果已经在场景树中，立即开始延迟计时
		_start_timer_with_runtime_state(owner_node)
	else:
		# 如果不在场景树中，等待进入场景树后再开始延迟计时
		owner_node.tree_entered.connect(_on_owner_entered_tree.bind(owner_node))

# 根据属性设置更新在列表中的名称
func _update_resource_name():
	resource_name = FuseLocalization.translate_format("FUSE_EVENT_ON_READY_RESOURCE_NAME", {"delay": str(delay_seconds)})

# 'owner_node' 就是 Trigger (已弃用 - 使用 initialize_with_runtime_instance 替代)
func initialize(owner_node: Node) -> void:
	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

	# 使用 RuntimeInstance 初始化
	if _runtime_instance_ref:
		_runtime_instance_ref.runtime_state = get_default_runtime_state()
	else:
		_log_warning("RuntimeInstance 未设置，使用传统初始化")
		# 保持向后兼容性，但推荐使用 RuntimeInstance
		_runtime_instance_ref = RuntimeEventInstance.new(self, owner_node)
		_runtime_instance_ref.runtime_state = get_default_runtime_state()

	# 等待场景就绪后再触发
	if owner_node.is_inside_tree():
		# 如果已经在场景树中，立即开始延迟计时
		_start_timer_with_runtime_state(owner_node)
	else:
		# 如果不在场景树中，等待进入场景树后再开始延迟计时
		owner_node.tree_entered.connect(_on_owner_entered_tree.bind(owner_node))

func terminate(owner_node: Node) -> void:
	# 🔧 清理 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.runtime_state = get_default_runtime_state()

	# 断开 tree_entered 连接
	if owner_node and owner_node.tree_entered.is_connected(_on_owner_entered_tree):
		owner_node.tree_entered.disconnect(_on_owner_entered_tree)

	# 清理定时器
	if _runtime_instance_ref == null:
		return

	var timer_node = _runtime_instance_ref.runtime_state.get("timer_node")
	if timer_node:
		if timer_node.timeout.is_connected(_on_timer_timeout):
			timer_node.timeout.disconnect(_on_timer_timeout)
		if owner_node and is_instance_valid(owner_node):
			owner_node.remove_child(timer_node)
		timer_node.queue_free()
		_runtime_instance_ref.runtime_state["timer_node"] = null
		_runtime_instance_ref.runtime_state["timer_connected"] = false

	_runtime_instance_ref = null
	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

func _on_timer_timeout(owner_node: Node) -> void:
	_log_debug_localized("FUSE_LOG_EVENT_READY_TRIGGERED", {})
	_emit_triggered(owner_node, owner_node)

	# 清理定时器
	if _runtime_instance_ref == null:
		return

	var timer_node = _runtime_instance_ref.runtime_state.get("timer_node")
	if timer_node:
		if owner_node and is_instance_valid(owner_node):
			owner_node.remove_child(timer_node)
		timer_node.queue_free()
		_runtime_instance_ref.runtime_state["timer_node"] = null
		_runtime_instance_ref.runtime_state["timer_connected"] = false

## 开始计时器（使用 RuntimeInstance 状态）
func _start_timer_with_runtime_state(owner_node: Node) -> void:
	# 从 RuntimeInstance 获取是否应该立即触发
	var should_trigger_immediately = _runtime_instance_ref.runtime_state.get("should_trigger_immediately", false)

	if delay_seconds > 0:
		# 创建定时器延迟触发
		var timer = Timer.new()
		timer.wait_time = delay_seconds
		timer.one_shot = true
		timer.timeout.connect(_on_timer_timeout.bind(owner_node))
		owner_node.add_child(timer)
		timer.start()
		_runtime_instance_ref.runtime_state["timer_node"] = timer
		_runtime_instance_ref.runtime_state["timer_connected"] = true
		_log_debug_localized("FUSE_LOG_EVENT_READY_DELAY", {"delay": delay_seconds})
	else:
		# 使用 call_deferred 确保在下一帧触发，给信号连接留出时间
		_log_debug_localized("FUSE_LOG_EVENT_READY_TRIGGERED", {})
		call_deferred("_deferred_emit_triggered", owner_node)

# 保持向后兼容性的旧方法
func _start_timer(owner_node: Node) -> void:
	_start_timer_with_runtime_state(owner_node)

## 当owner节点进入场景树时
func _on_owner_entered_tree(owner_node: Node) -> void:
	_log_debug_localized("FUSE_LOG_EVENT_READY_DELAY", {"delay": delay_seconds})

	# 更新 RuntimeInstance 状态，确保立即触发状态正确
	if _runtime_instance_ref:
		_runtime_instance_ref.runtime_state["should_trigger_immediately"] = delay_seconds == 0.0

	_start_timer_with_runtime_state(owner_node)

## 延迟触发信号
func _deferred_emit_triggered(owner_node: Node) -> void:
	_log_debug_localized("FUSE_LOG_EVENT_READY_TRIGGERED", {})
	_emit_triggered(owner_node, owner_node)

func get_description() -> String:
	if delay_seconds > 0:
		return FuseLocalization.translate_format("FUSE_EVENT_ON_READY_DESC_WITH_DELAY", {"delay": str(delay_seconds)})
	else:
		return FuseLocalization.translate("FUSE_EVENT_ON_READY_DESC_IMMEDIATE")

func get_event_type() -> String:
	return "scene_ready"

func get_event_category() -> String:
	return "scene"

func reset() -> void:
	super.reset()

	# 🔧 重置 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.runtime_state = get_default_runtime_state()

		# 停止任何活动的计时器
		var timer_node = _runtime_instance_ref.runtime_state.get("timer_node")
		if timer_node and timer_node.is_inside_tree():
			timer_node.stop()
			# 重置立即触发的状态
			_runtime_instance_ref.runtime_state["should_trigger_immediately"] = delay_seconds == 0.0

	_log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_ON_READY_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_LIFECYCLE"
	metadata.description_key = "FUSE_EVENT_ON_READY_DESC"
	metadata.keywords = ["ready", "初始化", "启动", "start", "init", "scene", "场景", "lifecycle", "生命周期"]
	metadata.builtin_icon = "CheckBox"
	return metadata
