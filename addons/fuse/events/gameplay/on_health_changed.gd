@tool
@icon("res://addons/fuse/icons/builtin/Heart.png")
extends BaseEvent
class_name OnHealthChanged

## 生命值变化事件
##
## 监听目标节点的生命值变化，支持多级阈值触发。
##
## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - _last_health_value: float - 上次生命值
## - _has_triggered_low: bool - 是否已触发低生命值
## - _has_triggered_critical: bool - 是否已触发危急生命值
## - _has_triggered_depleted: bool - 是否已触发生命值耗尽
##
## 架构版本: 自声明状态模式 v2.0
## 相关文档: addons/fuse/docs/migration-guide-to-runtime-instance.md

## 触发模式
enum TriggerMode {
	ON_CHANGE,        # 任何变化
	ON_LOW,           # 低生命值
	ON_CRITICAL,      # 危急生命值
	ON_DEPLETED       # 生命值耗尽
}

## 目标节点路径
@export var target_node: NodePath = NodePath(""):
	set(value):
		target_node = value
		_update_resource_name()

## 生命值属性名
@export var health_property: String = "health":
	set(value):
		health_property = value
		_update_resource_name()

## 最大生命值属性名
@export var max_health_property: String = "max_health":
	set(value):
		max_health_property = value
		_update_resource_name()

## 触发模式
@export var trigger_mode: TriggerMode = TriggerMode.ON_CHANGE:
	set(value):
		trigger_mode = value
		_update_resource_name()

## 低生命值阈值（百分比 0-1）
@export_range(0.0, 1.0) var threshold_low: float = 0.3:
	set(value):
		threshold_low = value
		_update_resource_name()

## 危急生命值阈值（百分比 0-1）
@export_range(0.0, 1.0) var threshold_critical: float = 0.1:
	set(value):
		threshold_critical = value
		_update_resource_name()

## 检查间隔（秒）
@export var check_interval: float = 0.1:
	set(value):
		check_interval = value
		_update_resource_name()

## 是否传递当前生命值
@export var emit_health_value: bool = true

var _target_node_ref: Node = null
var _timer: Timer = null
var _owner_node_ref: Node = null

## 更新资源名称（必需）
func _update_resource_name():
	var mode_key = _get_trigger_mode_key()
	resource_name = FuseLocalization.translate_format("FUSE_EVENT_ON_HEALTH_CHANGED_RESOURCE_NAME", {
		"target": _get_node_display_name(target_node),
		"mode": FuseLocalization.translate(mode_key)
	})

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["last_health_value"] = 0.0
	base["has_triggered_low"] = false
	base["has_triggered_critical"] = false
	base["has_triggered_depleted"] = false
	return base

## 使用 RuntimeInstance 初始化事件
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		return

	# 保存 RuntimeEventInstance 引用
	_runtime_instance_ref = runtime_instance

	# 验证 owner_node
	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 验证目标节点路径
	if target_node.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 验证属性名
	if health_property.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_PROPERTY_NAME_EMPTY", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 获取目标节点
	_target_node_ref = owner_node.get_node_or_null(target_node)
	if not _target_node_ref:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(target_node)})
		return

	# 验证检查间隔
	if check_interval <= 0:
		_create_fuse_error_localized("FUSE_ERROR_CHECK_INTERVAL_INVALID", FuseError.ErrorType.CONFIGURATION_ERROR, {"interval": check_interval})
		return

	_owner_node_ref = owner_node

	# 获取初始生命值
	var last_health_value: float = 0.0
	if _runtime_instance_ref.has_runtime_state("last_health_value"):
		last_health_value = _runtime_instance_ref.get_runtime_state("last_health_value")
	else:
		last_health_value = _get_health_value()
		_runtime_instance_ref.set_runtime_state("last_health_value", last_health_value)

	# 创建定时器进行轮询检查
	_start_check_timer()

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	# 清理定时器
	_cleanup_timer()

	# 重置状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("has_triggered_low", false)
		_runtime_instance_ref.set_runtime_state("has_triggered_critical", false)
		_runtime_instance_ref.set_runtime_state("has_triggered_depleted", false)
		_runtime_instance_ref.set_runtime_state("last_health_value", 0.0)

	# 清理引用
	_target_node_ref = null
	_owner_node_ref = null

	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 启动检查定时器
func _start_check_timer():
	if not _owner_node_ref:
		return

	_cleanup_timer()

	_timer = Timer.new()
	_timer.wait_time = check_interval
	_timer.autostart = true
	_timer.timeout.connect(_on_check_timeout)

	_owner_node_ref.add_child(_timer)
	_timer.start()

	_log_debug_localized("FUSE_LOG_EVENT_HEALTH_CHECK_STARTED", {"interval": check_interval})

## 清理定时器
func _cleanup_timer():
	if _timer:
		_timer.stop()

		if _timer.timeout.is_connected(_on_check_timeout):
			_timer.timeout.disconnect(_on_check_timeout)

		if _owner_node_ref and is_instance_valid(_owner_node_ref):
			_owner_node_ref.remove_child(_timer)

		_timer.queue_free()
		_timer = null

## 定时器超时回调
func _on_check_timeout():
	if not _target_node_ref or not is_instance_valid(_target_node_ref):
		return

	var current_health = _get_health_value()
	var last_health_value: float = 0.0

	if _runtime_instance_ref.has_runtime_state("last_health_value"):
		last_health_value = _runtime_instance_ref.get_runtime_state("last_health_value")

	# 检查生命值是否变化
	if current_health != last_health_value:
		_on_health_changed(current_health)
		_runtime_instance_ref.set_runtime_state("last_health_value", current_health)

## 生命值变化处理
func _on_health_changed(current_health: float):
	var max_health = _get_max_health_value()
	var health_percentage = 0.0

	if max_health > 0:
		health_percentage = current_health / max_health
	else:
		health_percentage = 0.0

	# 根据触发模式检查是否应该触发
	var should_trigger = false
	var trigger_reason = ""

	var has_triggered_low: bool = false
	var has_triggered_critical: bool = false
	var has_triggered_depleted: bool = false

	if _runtime_instance_ref.has_runtime_state("has_triggered_low"):
		has_triggered_low = _runtime_instance_ref.get_runtime_state("has_triggered_low")
	if _runtime_instance_ref.has_runtime_state("has_triggered_critical"):
		has_triggered_critical = _runtime_instance_ref.get_runtime_state("has_triggered_critical")
	if _runtime_instance_ref.has_runtime_state("has_triggered_depleted"):
		has_triggered_depleted = _runtime_instance_ref.get_runtime_state("has_triggered_depleted")

	match trigger_mode:
		TriggerMode.ON_CHANGE:
			should_trigger = true
			trigger_reason = "changed"

		TriggerMode.ON_LOW:
			if health_percentage <= threshold_low and not has_triggered_low:
				should_trigger = true
				_runtime_instance_ref.set_runtime_state("has_triggered_low", true)
				trigger_reason = "low"
			elif health_percentage > threshold_low:
				# 重置低生命值触发标记
				_runtime_instance_ref.set_runtime_state("has_triggered_low", false)

		TriggerMode.ON_CRITICAL:
			if health_percentage <= threshold_critical and not has_triggered_critical:
				should_trigger = true
				_runtime_instance_ref.set_runtime_state("has_triggered_critical", true)
				trigger_reason = "critical"
			elif health_percentage > threshold_critical:
				# 重置危急生命值触发标记
				_runtime_instance_ref.set_runtime_state("has_triggered_critical", false)

		TriggerMode.ON_DEPLETED:
			if health_percentage <= 0.0 and not has_triggered_depleted:
				should_trigger = true
				_runtime_instance_ref.set_runtime_state("has_triggered_depleted", true)
				trigger_reason = "depleted"

	# 触发事件
	if should_trigger:
		var last_health_value: float = 0.0
		if _runtime_instance_ref.has_runtime_state("last_health_value"):
			last_health_value = _runtime_instance_ref.get_runtime_state("last_health_value")

		_log_info_localized("FUSE_LOG_EVENT_HEALTH_CHANGED_TRIGGERED", {
			"health": current_health,
			"max_health": max_health,
			"percentage": "%.1f%%" % (health_percentage * 100),
			"reason": trigger_reason
		})

		# 创建上下文节点传递生命值信息
		if emit_health_value:
			var context_node = Node.new()
			context_node.name = "HealthChangedContext"
			context_node.set_meta("health", current_health)
			context_node.set_meta("max_health", max_health)
			context_node.set_meta("percentage", health_percentage)
			context_node.set_meta("previous_health", last_health_value)
			context_node.set_meta("change", current_health - last_health_value)
			context_node.set_meta("trigger_reason", trigger_reason)
			triggered.emit(context_node)
		else:
			triggered.emit(null)

## 获取当前生命值
func _get_health_value() -> float:
	if not _target_node_ref or not is_instance_valid(_target_node_ref):
		return 0.0

	# Object 无 has_property 方法（Godot 4.7 Object API）——用 get() 判存在：
	# 属性缺失时 get 返回 null，取到值（含 0）视为存在
	var value: Variant = _target_node_ref.get(health_property)
	if value != null:
		return float(value)

	return 0.0

## 获取最大生命值
func _get_max_health_value() -> float:
	if not _target_node_ref or not is_instance_valid(_target_node_ref):
		return 100.0  # 默认值

	# 同 _get_health_value：get() 判存在（Object 无 has_property 方法）
	var max_value: Variant = _target_node_ref.get(max_health_property)
	if max_value != null and float(max_value) > 0:
		return float(max_value)

	return 100.0  # 默认值

## 获取触发模式键
func _get_trigger_mode_key() -> String:
	match trigger_mode:
		TriggerMode.ON_CHANGE:
			return "FUSE_EVENT_HEALTH_MODE_ANY"
		TriggerMode.ON_LOW:
			return "FUSE_EVENT_HEALTH_MODE_LOW"
		TriggerMode.ON_CRITICAL:
			return "FUSE_EVENT_HEALTH_MODE_CRITICAL"
		TriggerMode.ON_DEPLETED:
			return "FUSE_EVENT_HEALTH_MODE_DEPLETED"
		_:
			return "FUSE_EVENT_HEALTH_MODE_ANY"

## 获取事件描述
func get_description() -> String:
	var node_name = target_node if not target_node.is_empty() else FuseLocalization.translate("FUSE_TEXT_NOT_SPECIFIED")
	var mode_key = _get_trigger_mode_desc_key()
	var mode_desc = FuseLocalization.translate_format(mode_key, {
		"low_threshold": "%.0f%%" % (threshold_low * 100),
		"critical_threshold": "%.0f%%" % (threshold_critical * 100)
	})

	return FuseLocalization.translate_format("FUSE_EVENT_ON_HEALTH_CHANGED_DESC", {
		"target": node_name,
		"mode": mode_desc,
		"interval": "%.2f" % check_interval
	})

## 获取触发模式描述键
func _get_trigger_mode_desc_key() -> String:
	match trigger_mode:
		TriggerMode.ON_CHANGE:
			return "FUSE_EVENT_HEALTH_DESC_ANY"
		TriggerMode.ON_LOW:
			return "FUSE_EVENT_HEALTH_DESC_LOW"
		TriggerMode.ON_CRITICAL:
			return "FUSE_EVENT_HEALTH_DESC_CRITICAL"
		TriggerMode.ON_DEPLETED:
			return "FUSE_EVENT_HEALTH_DESC_DEPLETED"
		_:
			return "FUSE_EVENT_HEALTH_DESC_ANY"

## 获取事件类型
func get_event_type() -> String:
	return "health_changed"

## 获取事件分类
func get_event_category() -> String:
	return "state"

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	if target_node.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))

	if health_property.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_PROPERTY_NAME_EMPTY"))

	if check_interval <= 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_CHECK_INTERVAL_INVALID"))

	if threshold_low < 0.0 or threshold_low > 1.0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_HEALTH_THRESHOLD_LOW_INVALID"))

	if threshold_critical < 0.0 or threshold_critical > 1.0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_HEALTH_THRESHOLD_CRITICAL_INVALID"))

	if threshold_critical > threshold_low:
		errors.append(FuseLocalization.translate("FUSE_ERROR_HEALTH_THRESHOLD_INVALID_RELATION"))

	return errors

## 重置事件状态
func reset() -> void:
	super.reset()

	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("has_triggered_low", false)
		_runtime_instance_ref.set_runtime_state("has_triggered_critical", false)
		_runtime_instance_ref.set_runtime_state("has_triggered_depleted", false)
		_runtime_instance_ref.set_runtime_state("last_health_value", _get_health_value())

	if _timer:
		_timer.start()

	_log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_ON_HEALTH_CHANGED_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_STATE"
	metadata.description_key = "FUSE_EVENT_ON_HEALTH_CHANGED_DESC"
	metadata.keywords = ["health", "生命值", "hp", "change", "变化", "low", "低", "critical", "危急", "depleted", "耗尽", "state", "状态"]
	metadata.builtin_icon = "Heart"
	return metadata
