@tool
@icon("res://addons/fuse/icons/builtin/Pause.png")
extends BaseEvent
class_name OnNodePausedResumed

## Event: OnNodePausedResumed
##
## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - _timer: Timer - 定时器对象（用于周期性检查节点 process_mode）
## - _is_monitoring: bool - 是否正在监听节点状态变化
## - _last_process_mode: int - 最后记录的 process_mode 值
##
## 架构版本: 自声明状态模式 v2.0
## 相关文档: addons/fuse/docs/zh_CN/dev_docs/guides/runtime-instance-migration-guide.md

## 节点暂停/恢复事件
##
## 监听节点暂停模式变化，使用 Timer 定期检查 process_mode 属性

## 触发时机枚举
enum TriggerOn {
	Paused = 0,    # 仅在暂停时触发
	Resumed = 1,   # 仅在恢复时触发
	Both = 2       # 在暂停和恢复时都触发
}

## 目标节点路径
@export var target_node: NodePath = NodePath(""):
	set(value):
		target_node = value
		_update_resource_name()

## 触发时机
@export var trigger_on: TriggerOn = TriggerOn.Both:
	set(value):
		trigger_on = value
		_update_resource_name()

## 检查间隔（秒），默认 0.1 秒
@export var check_interval: float = 0.1:
	set(value):
		check_interval = value
		_update_resource_name()

var _timer: Timer = null
var _target_node_ref: Node = null
var _owner_node_ref: Node = null

# 本地状态变量（从 RuntimeInstance 状态读取）
var _is_monitoring: bool = false
var _last_process_mode: int = Node.ProcessMode.PROCESS_MODE_INHERIT

## 更新资源名称（必需）
func _update_resource_name():
	var node_text = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_TEXT_NODE_NOT_SPECIFIED")

	var trigger_key = ""
	match trigger_on:
		TriggerOn.Paused:
			trigger_key = "FUSE_DESC_TRIGGER_PAUSED"
		TriggerOn.Resumed:
			trigger_key = "FUSE_DESC_TRIGGER_RESUMED"
		TriggerOn.Both:
			trigger_key = "FUSE_DESC_TRIGGER_BOTH"

	var trigger_text = FuseLocalization.translate(trigger_key)
	resource_name = FuseLocalization.translate_format("FUSE_EVENT_ON_NODE_PAUSED_RESUMED_RESOURCE_NAME", {
		"node": node_text,
		"trigger": trigger_text
	})

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["is_monitoring"] = false
	base["last_process_mode"] = Node.ProcessMode.PROCESS_MODE_INHERIT
	return base

## 初始化事件监听（必需）
func initialize(owner_node: Node) -> void:
	if Engine.is_editor_hint():
		return

	_runtime_instance_ref = owner_node.get_meta("_fuse_runtime_instance") as RuntimeEventInstance
	if not _runtime_instance_ref:
		_create_fuse_error_localized("FUSE_ERROR_RUNTIME_INSTANCE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	initialize_with_runtime_instance(owner_node, _runtime_instance_ref)

## 使用 RuntimeInstance 初始化（必需）
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		return

	_runtime_instance_ref = runtime_instance

	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 验证 target_node
	if target_node.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 验证 check_interval
	if check_interval <= 0:
		_create_fuse_error_localized("FUSE_ERROR_CHECK_INTERVAL_INVALID", FuseError.ErrorType.CONFIGURATION_ERROR, {"interval": check_interval})
		return

	# 从 RuntimeInstance 恢复状态（无既有状态默认开始监控——初始化即监听）
	# 初始化即监听：无条件置真（get_default_runtime_state 播种的是 false，
	# 按状态恢复会让事件永远不监听）；重初始化场景如需恢复语义另行处理
	_is_monitoring = true
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("is_monitoring", true)

	if _runtime_instance_ref and _runtime_instance_ref.has_runtime_state("last_process_mode"):
		_last_process_mode = _runtime_instance_ref.get_runtime_state("last_process_mode")

	# 设置 owner_node 引用
	_owner_node_ref = owner_node

	# 获取目标节点
	_target_node_ref = owner_node.get_node_or_null(target_node)
	if not _target_node_ref:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(target_node)})
		return

	# 创建轮询定时器（默认即监听）
	_create_timer()

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {
		"event_type": get_event_type(),
		"target_node": str(target_node),
		"trigger_on": _get_trigger_on_name(),
		"check_interval": check_interval
	})

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	_is_monitoring = false

	# 清理定时器
	_cleanup_timer()

	# 清理引用
	_target_node_ref = null
	_owner_node_ref = null

	# 清理 RuntimeInstance 状态
	if _runtime_instance_ref:
		_runtime_instance_ref.reset_runtime_state()

	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 创建定时器
func _create_timer():
	if not _owner_node_ref:
		return

	_cleanup_timer()

	_timer = Timer.new()
	_timer.wait_time = check_interval
	_timer.one_shot = false
	# 轮询器必须 ALWAYS：默认 pausable 的话树一暂停 Timer 自身停摆，
	# 恰好盲掉要观测的暂停窗口（暂停期间无一次采样，恢复后才醒来）
	_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_timer.timeout.connect(_on_timer_timeout)
	_owner_node_ref.add_child(_timer)
	_timer.start()

## 清理定时器
func _cleanup_timer():
	if _timer:
		_timer.stop()

		if _timer.timeout.is_connected(_on_timer_timeout):
			_timer.timeout.disconnect(_on_timer_timeout)

		if _owner_node_ref and is_instance_valid(_owner_node_ref):
			_owner_node_ref.remove_child(_timer)

		_timer.queue_free()
		_timer = null

## 定时器超时回调
func _on_timer_timeout():
	if not _is_monitoring:
		return

	# 检查目标节点是否仍然有效
	if not _target_node_ref or not is_instance_valid(_target_node_ref):
		_log_warning("目标节点已失效，停止监听")
		_is_monitoring = false
		return

	var current_process_mode = _target_node_ref.process_mode

	# 检查 process_mode 是否变化
	if current_process_mode != _last_process_mode:
		var old_mode = _last_process_mode
		_last_process_mode = current_process_mode

		# 更新 RuntimeInstance 状态
		if _runtime_instance_ref:
			_runtime_instance_ref.set_runtime_state("last_process_mode", current_process_mode)

		# 判断是否暂停（根据 process_mode 值）
		var is_paused = _is_process_mode_paused(current_process_mode)
		var was_paused = _is_process_mode_paused(old_mode)

		# 检查触发时机
		var should_trigger = false
		var trigger_type = ""

		if is_paused and not was_paused:
			# 从运行变为暂停
			if trigger_on == TriggerOn.Paused or trigger_on == TriggerOn.Both:
				should_trigger = true
				trigger_type = "paused"
		elif not is_paused and was_paused:
			# 从暂停变为运行
			if trigger_on == TriggerOn.Resumed or trigger_on == TriggerOn.Both:
				should_trigger = true
				trigger_type = "resumed"

		if should_trigger:
			# 更新 RuntimeInstance 状态
			if _runtime_instance_ref:
				_runtime_instance_ref.set_runtime_state("is_monitoring", true)

			_log_debug_localized("FUSE_LOG_EVENT_NODE_PAUSED_RESUMED", {
				"node": _target_node_ref.name,
				"trigger_type": trigger_type,
				"old_mode": str(old_mode),
				"new_mode": str(current_process_mode)
			})

			# 创建上下文节点传递事件信息
			var context_node = Node.new()
			context_node.name = "NodePausedResumedContext"
			context_node.set_meta("trigger_type", trigger_type)
			context_node.set_meta("old_process_mode", old_mode)
			context_node.set_meta("new_process_mode", current_process_mode)
			context_node.set_meta("is_paused", is_paused)
			context_node.set_meta("target_node", _target_node_ref)

			triggered.emit(context_node)

			# 清理上下文节点
			context_node.queue_free()

## 获取触发时机名称
func _get_trigger_on_name() -> String:
	match trigger_on:
		TriggerOn.Paused:
			return "Paused"
		TriggerOn.Resumed:
			return "Resumed"
		TriggerOn.Both:
			return "Both"
		_:
			return "Unknown"

## 判断 process_mode 是否为暂停状态
func _is_process_mode_paused(mode: int) -> bool:
	# PROCESS_MODE_INHERIT (0) - 继承父节点，需要检查父节点
	# PROCESS_MODE_PAUSABLE (1) - 可暂停（受暂停影响）
	# PROCESS_MODE_WHEN_PAUSED (2) - 仅在暂停时处理
	# PROCESS_MODE_ALWAYS (3) - 总是处理（不受暂停影响）
	# PROCESS_MODE_DISABLED (4) - 禁用处理

	# 简化判断：如果模式是 DISABLED，视为暂停
	if mode == Node.ProcessMode.PROCESS_MODE_DISABLED:
		return true

	# 如果模式是 ALWAYS，视为未暂停
	if mode == Node.ProcessMode.PROCESS_MODE_ALWAYS:
		return false

	# 其他情况需要检查场景树暂停状态
	if _target_node_ref and _target_node_ref.is_inside_tree():
		var tree = _target_node_ref.get_tree()
		if tree:
			return tree.paused

	return false

## 获取事件描述
func get_description() -> String:
	var node_text = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_TEXT_NOT_SPECIFIED")

	var trigger_key = ""
	match trigger_on:
		TriggerOn.Paused:
			trigger_key = "FUSE_DESC_TRIGGER_PAUSED_ONLY"
		TriggerOn.Resumed:
			trigger_key = "FUSE_DESC_TRIGGER_RESUMED_ONLY"
		TriggerOn.Both:
			trigger_key = "FUSE_DESC_TRIGGER_BOTH"

	var trigger_desc = FuseLocalization.translate(trigger_key)

	return FuseLocalization.translate_format("FUSE_EVENT_ON_NODE_PAUSED_RESUMED_DESC", {
		"node": node_text,
		"interval": check_interval,
		"trigger": trigger_desc
	})

## 获取事件类型
func get_event_type() -> String:
	return "node_paused_resumed"

## 获取事件分类
func get_event_category() -> String:
	return "scene"

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	if target_node.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))

	if check_interval <= 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_CHECK_INTERVAL_INVALID"))

	return errors

## 重置事件状态
func reset() -> void:
	super.reset()

	# 从 RuntimeInstance 恢复状态
	if _runtime_instance_ref:
		_is_monitoring = _runtime_instance_ref.get_runtime_state("is_monitoring")
		_last_process_mode = _runtime_instance_ref.get_runtime_state("last_process_mode")

	if _target_node_ref and is_instance_valid(_target_node_ref):
		_last_process_mode = _target_node_ref.process_mode

	_cleanup_timer()
	_create_timer()

	_is_monitoring = true

	# 更新 RuntimeInstance 状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("is_monitoring", true)
		_runtime_instance_ref.set_runtime_state("last_process_mode", _last_process_mode)

	_log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_ON_NODE_PAUSED_RESUMED_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_SCENE"
	metadata.description_key = "FUSE_EVENT_ON_NODE_PAUSED_RESUMED_DESC"
	metadata.keywords = ["node", "节点", "paused", "暂停", "resumed", "恢复", "process", "处理", "mode", "模式", "pause", "暂停", "resume", "继续", "state", "状态"]
	metadata.builtin_icon = "Pause"
	return metadata