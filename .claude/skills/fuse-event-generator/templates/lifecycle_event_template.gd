@tool
@icon("res://addons/fuse/icons/builtin/Timer.png")
extends BaseEvent
class_name OnLifecycleEventTemplate

## 生命周期事件描述（简短说明事件的功能）
##
## 生命周期事件说明：
## - 不依赖外部信号
## - 使用定时器或延迟触发
## - 支持场景就绪时触发
## - 使用 RuntimeEventInstance 管理运行时状态

# =============================================
# 参数定义
# =============================================

## 延迟时间（秒）
@export var delay_seconds: float = 0.0:
	set(value):
		delay_seconds = value
		_update_resource_name()

## 是否只触发一次
@export var trigger_once: bool = true:
	set(value):
		trigger_once = value
		_update_resource_name()

# =============================================
# 运行时状态
# =============================================

# 注：_runtime_instance_ref 已在 BaseEvent 中声明，子类无需重新声明
var _timer: Timer = null  # Timer 对象保留在 Event 中（不存入 RuntimeEventInstance）

## 获取默认运行时状态（新版核心方法）
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["has_triggered"] = false
	return base

# =============================================
# 元数据方法
# =============================================

## 获取事件元数据（必需）
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_ON_XXX_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_LIFECYCLE"
	metadata.description_key = "FUSE_EVENT_ON_XXX_DESC"
	metadata.keywords = ["keyword1", "keyword2", "keyword3"]
	metadata.builtin_icon = "Timer"
	return metadata

# =============================================
# 资源名称和描述
# =============================================

## 更新资源名称（必需）
func _update_resource_name():
	var parts = []

	parts.append("生命周期事件")

	if delay_seconds > 0:
		parts.append("延迟 %.1f 秒" % delay_seconds)

	if trigger_once:
		parts.append("[仅一次]")

	resource_name = " ".join(parts)

## 获取事件描述
func get_description() -> String:
	var delay_text = ""
	if delay_seconds > 0:
		delay_text = "，延迟 %.1f 秒" % delay_seconds

	var once_text = "，仅触发一次" if trigger_once else ""

	return "事件触发%s%s" % [delay_text, once_text]

## 获取事件类型
func get_event_type() -> String:
	return "lifecycle_event_type"

## 获取事件分类
func get_event_category() -> String:
	return "lifecycle"

# =============================================
# 生命周期方法
# =============================================

## 使用运行时实例初始化事件（推荐）
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		return

	# 保存 RuntimeEventInstance 引用
	_runtime_instance_ref = runtime_instance

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

	# ============================================
	# 1. 验证 owner_node
	# ============================================

	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# ============================================
	# 2. 检查场景状态
	# ============================================

	if owner_node.is_inside_tree():
		_start_timer(owner_node)
	else:
		owner_node.tree_entered.connect(_on_owner_entered_tree.bind(owner_node))

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	# ============================================
	# 1. 断开 tree_entered 连接
	# ============================================

	if owner_node and owner_node.tree_entered.is_connected(_on_owner_entered_tree):
		owner_node.tree_entered.disconnect(_on_owner_entered_tree)

	# ============================================
	# 2. 清理定时器
	# ============================================

	if _timer:
		if _timer.timeout.is_connected(_on_timer_timeout):
			_timer.timeout.disconnect(_on_timer_timeout)
		if owner_node and is_instance_valid(owner_node):
			owner_node.remove_child(_timer)
		_timer.queue_free()
		_timer = null

	# ============================================
	# 3. 清理 RuntimeEventInstance 状态
	# ============================================

	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("has_triggered", false)

	_runtime_instance_ref = null

	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

# =============================================
# 定时器管理
# =============================================

## 开始计时器
func _start_timer(owner_node: Node) -> void:
	if delay_seconds > 0:
		# 创建定时器延迟触发
		_timer = Timer.new()
		_timer.wait_time = delay_seconds
		_timer.one_shot = trigger_once
		_timer.timeout.connect(_on_timer_timeout.bind(owner_node))
		owner_node.add_child(_timer)
		_timer.start()
		_log_debug_localized("FUSE_LOG_EVENT_READY_DELAY", {"delay": delay_seconds})
	else:
		# 使用 call_deferred 确保在下一帧触发
		call_deferred("_deferred_emit_triggered", owner_node)

## 定时器超时回调
func _on_timer_timeout(owner_node: Node) -> void:
	_log_debug_localized("FUSE_LOG_EVENT_TRIGGERED", {"event": get_event_type()})

	# 检查是否只触发一次（通过 RuntimeEventInstance 状态）
	var has_triggered: bool = false
	if _runtime_instance_ref and _runtime_instance_ref.has_runtime_state("has_triggered"):
		has_triggered = _runtime_instance_ref.get_runtime_state("has_triggered")

	if trigger_once and has_triggered:
		_log_debug_localized("FUSE_LOG_EVENT_ALREADY_TRIGGERED", {})
		return

	# 标记已触发（写入 RuntimeEventInstance 状态）
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("has_triggered", true)
		_runtime_instance_ref.update_trigger_stats()

	# 发出触发信号（使用 _emit_triggered 自动设置 trigger meta）
	_emit_triggered(owner_node)

	# 如果不是仅触发一次，重启定时器
	if not trigger_once:
		_timer.start()

## 当 owner 节点进入场景树时
func _on_owner_entered_tree(owner_node: Node) -> void:
	_log_debug_localized("FUSE_LOG_EVENT_READY_DELAY", {"delay": delay_seconds})
	_start_timer(owner_node)

## 延迟触发信号
func _deferred_emit_triggered(owner_node: Node) -> void:
	_log_debug_localized("FUSE_LOG_EVENT_TRIGGERED", {"event": get_event_type()})

	# 检查是否只触发一次（通过 RuntimeEventInstance 状态）
	var has_triggered: bool = false
	if _runtime_instance_ref and _runtime_instance_ref.has_runtime_state("has_triggered"):
		has_triggered = _runtime_instance_ref.get_runtime_state("has_triggered")

	if trigger_once and has_triggered:
		_log_debug_localized("FUSE_LOG_EVENT_ALREADY_TRIGGERED", {})
		return

	# 标记已触发
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("has_triggered", true)
		_runtime_instance_ref.update_trigger_stats()

	# 发出触发信号
	_emit_triggered(owner_node)

# =============================================
# 验证和重置
# =============================================

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	if delay_seconds < 0:
		errors.append("延迟时间不能为负数")

	return errors

## 重置事件状态
func reset() -> void:
	super.reset()

	# 停止定时器
	if _timer:
		_timer.stop()

	# 重置 RuntimeEventInstance 状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("has_triggered", false)

	_log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})
