@tool
@icon("res://addons/fuse/icons/builtin/float.png")
extends BaseEvent
class_name OnValueChanged

## Event: OnValueChanged
##
## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - _last_value: float - 上一次的值
## - _was_threshold_reached: bool - 是否已达到阈值
##
## 架构版本: 自声明状态模式 v2.0
## 相关文档: addons/fuse/docs/migration-guide-to-runtime-instance.md
##
## Slider/SpinBox/ProgressBar 值改变事件
##
## 监听 Slider、SpinBox、ProgressBar 等控件的值改变事件，支持多种触发模式

## 触发模式
enum TriggerMode {
	ON_ANY_CHANGE,      ## 任何值变化都触发
	ON_THRESHOLD,       ## 值达到阈值时触发
	ON_MIN_REACHED,     ## 达到最小值时触发
	ON_MAX_REACHED      ## 达到最大值时触发
}

## 目标节点路径
@export var target_node_path: NodePath = NodePath(""):
	set(value):
		target_node_path = value
		_update_resource_name()

## 触发模式
@export var trigger_mode: TriggerMode = TriggerMode.ON_ANY_CHANGE:
	set(value):
		trigger_mode = value
		_update_resource_name()

## 阈值（用于 ON_THRESHOLD 模式）
@export var threshold_value: float = 0.5:
	set(value):
		threshold_value = value
		_update_resource_name()

## 最小值阈值（用于 ON_MIN_REACHED 模式）
@export var min_threshold: float = 0.0:
	set(value):
		min_threshold = value
		_update_resource_name()

## 最大值阈值（用于 ON_MAX_REACHED 模式）
@export var max_threshold: float = 100.0:
	set(value):
		max_threshold = value
		_update_resource_name()

## 是否发出当前值
@export var emit_current_value: bool = true

## 是否发出旧值
@export var emit_old_value: bool = true

## 是否发出变化量
@export var emit_delta: bool = true

## 是否发出是否达到阈值标志
@export var emit_threshold_reached: bool = true

var _target_node_ref: Node = null

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["last_value"] = 0.0
	base["was_threshold_reached"] = false
	return base

## 更新资源名称（必需）
func _update_resource_name():
	var mode_key = ""
	match trigger_mode:
		TriggerMode.ON_ANY_CHANGE:
			mode_key = "FUSE_DESC_VALUE_ANY_CHANGE"
		TriggerMode.ON_THRESHOLD:
			mode_key = "FUSE_DESC_VALUE_THRESHOLD"
		TriggerMode.ON_MIN_REACHED:
			mode_key = "FUSE_DESC_VALUE_MIN_REACHED"
		TriggerMode.ON_MAX_REACHED:
			mode_key = "FUSE_DESC_VALUE_MAX_REACHED"

	var mode_text = FuseLocalization.translate(mode_key)
	if trigger_mode == TriggerMode.ON_THRESHOLD:
		mode_text = FuseLocalization.translate_format(mode_key, {"threshold": "%.2f" % threshold_value})
	elif trigger_mode == TriggerMode.ON_MIN_REACHED:
		mode_text = FuseLocalization.translate_format(mode_key, {"min": "%.2f" % min_threshold})
	elif trigger_mode == TriggerMode.ON_MAX_REACHED:
		mode_text = FuseLocalization.translate_format(mode_key, {"max": "%.2f" % max_threshold})

	resource_name = FuseLocalization.translate_format("FUSE_EVENT_ON_VALUE_CHANGED_RESOURCE_NAME", {
		"path": _get_node_display_name(target_node_path),
		"mode": mode_text
	})

## 使用 RuntimeInstance 初始化（必需）
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		return

	_runtime_instance_ref = runtime_instance

	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 验证目标节点路径
	if target_node_path.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 获取目标节点
	_target_node_ref = owner_node.get_node_or_null(target_node_path)
	if not _target_node_ref:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(target_node_path)})
		return

	# 验证节点类型（支持 Slider、SpinBox、ProgressBar、Range 等）
	if not _is_valid_target():
		_create_fuse_error_localized("FUSE_ERROR_INVALID_TARGET", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(target_node_path)})
		return

	# 获取初始值
	var last_value = _get_current_value()
	var was_threshold_reached = _check_threshold(last_value)
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("last_value", last_value)
		_runtime_instance_ref.set_runtime_state("was_threshold_reached", was_threshold_reached)

	# 连接信号
	_connect_value_changed_signal()

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 初始化事件监听（必需）- 保留向后兼容
func initialize(owner_node: Node) -> void:
	# 验证 owner_node
	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 验证目标节点路径
	if target_node_path.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 获取目标节点
	_target_node_ref = owner_node.get_node_or_null(target_node_path)
	if not _target_node_ref:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(target_node_path)})
		return

	# 验证节点类型（支持 Slider、SpinBox、ProgressBar、Range 等）
	if not _is_valid_target():
		_create_fuse_error_localized("FUSE_ERROR_INVALID_TARGET", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(target_node_path)})
		return

	# 连接信号
	_connect_value_changed_signal()

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	# 清理 RuntimeEventInstance 状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("last_value", 0.0)
		_runtime_instance_ref.set_runtime_state("was_threshold_reached", false)

	# 断开信号连接
	if _target_node_ref and is_instance_valid(_target_node_ref):
		_disconnect_value_changed_signal()

	# 清理引用
	_target_node_ref = null

	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 连接值改变信号
func _connect_value_changed_signal():
	if not _target_node_ref or not is_instance_valid(_target_node_ref):
		return

	# 根据节点类型连接不同的信号
	if _target_node_ref.has_signal("value_changed"):
		if not _target_node_ref.value_changed.is_connected(_on_value_changed):
			_target_node_ref.value_changed.connect(_on_value_changed)
	elif _target_node_ref is Slider:
		if not _target_node_ref.drag_ended.is_connected(_on_slider_drag_ended):
			_target_node_ref.drag_ended.connect(_on_slider_drag_ended)

## 断开值改变信号
func _disconnect_value_changed_signal():
	if not _target_node_ref or not is_instance_valid(_target_node_ref):
		return

	if _target_node_ref.has_signal("value_changed"):
		if _target_node_ref.value_changed.is_connected(_on_value_changed):
			_target_node_ref.value_changed.disconnect(_on_value_changed)

	if _target_node_ref is Slider:
		if _target_node_ref.drag_ended.is_connected(_on_slider_drag_ended):
			_target_node_ref.drag_ended.disconnect(_on_slider_drag_ended)

## 值改变回调
func _on_value_changed(value: float):
	_handle_value_change(value)

## Slider 拖动结束回调
func _on_slider_drag_ended():
	if _target_node_ref is Slider:
		var value = (_target_node_ref as Slider).value
		_handle_value_change(value)

## 处理值变化
func _handle_value_change(new_value: float):
	var last_value = 0.0
	var was_threshold_reached = false

	if _runtime_instance_ref and _runtime_instance_ref.has_runtime_state("last_value"):
		last_value = _runtime_instance_ref.get_runtime_state("last_value")
	if _runtime_instance_ref and _runtime_instance_ref.has_runtime_state("was_threshold_reached"):
		was_threshold_reached = _runtime_instance_ref.get_runtime_state("was_threshold_reached")

	var old_value = last_value
	var delta = new_value - old_value
	var threshold_reached = _check_threshold(new_value)

	var should_trigger = false

	match trigger_mode:
		TriggerMode.ON_ANY_CHANGE:
			should_trigger = true

		TriggerMode.ON_THRESHOLD:
			# 检查是否跨越阈值
			var was_below = old_value < threshold_value
			var is_above = new_value >= threshold_value
			var was_above = old_value >= threshold_value
			var is_below = new_value < threshold_value

			should_trigger = (was_below and is_above) or (was_above and is_below)

		TriggerMode.ON_MIN_REACHED:
			should_trigger = new_value <= min_threshold and old_value > min_threshold

		TriggerMode.ON_MAX_REACHED:
			should_trigger = new_value >= max_threshold and old_value < max_threshold

	if should_trigger:
		if _runtime_instance_ref:
			_runtime_instance_ref.set_runtime_state("last_value", new_value)
			_runtime_instance_ref.set_runtime_state("was_threshold_reached", threshold_reached)

		var mode_name = _get_trigger_mode_name()
		var threshold_text = ""
		match trigger_mode:
			TriggerMode.ON_THRESHOLD:
				threshold_text = "，阈值: %.2f" % threshold_value
			TriggerMode.ON_MIN_REACHED:
				threshold_text = "，最小值: %.2f" % min_threshold
			TriggerMode.ON_MAX_REACHED:
				threshold_text = "，最大值: %.2f" % max_threshold

		_log_info_localized("FUSE_LOG_EVENT_VALUE_CHANGED", {
			"current": str(new_value),
			"old": str(old_value),
			"delta": str(delta),
			"mode": mode_name,
			"threshold_text": threshold_text
		})

		# 创建上下文节点传递值
		var context_node = Node.new()
		context_node.name = "ValueChangedContext"

		if emit_current_value:
			context_node.set_meta("current_value", new_value)

		if emit_old_value:
			context_node.set_meta("old_value", old_value)

		if emit_delta:
			context_node.set_meta("delta", delta)

		if emit_threshold_reached:
			context_node.set_meta("threshold_reached", threshold_reached)

		context_node.set_meta("target_node", _target_node_ref)
		context_node.set_meta("trigger_mode", TriggerMode.keys()[trigger_mode])

		triggered.emit(context_node)

		# 清理上下文节点
		context_node.queue_free()

## 获取当前值
func _get_current_value() -> float:
	if not _target_node_ref or not is_instance_valid(_target_node_ref):
		return 0.0

	# 尝试从不同类型的控件获取值
	if _target_node_ref.has_method("get_value"):
		return _target_node_ref.call("get_value")

	if _target_node_ref.has_property("value"):
		return _target_node_ref.get("value")

	return 0.0

## 检查是否达到阈值
func _check_threshold(value: float) -> bool:
	match trigger_mode:
		TriggerMode.ON_THRESHOLD:
			return value >= threshold_value
		TriggerMode.ON_MIN_REACHED:
			return value <= min_threshold
		TriggerMode.ON_MAX_REACHED:
			return value >= max_threshold
		_:
			return false

## 验证是否是有效的目标节点
func _is_valid_target() -> bool:
	if not _target_node_ref:
		return false

	# 支持的类型：Slider, SpinBox, ProgressBar, Range, HSlider, VSlider
	return (_target_node_ref is Slider or
			_target_node_ref is SpinBox or
			_target_node_ref is ProgressBar or
			_target_node_ref is Range)

## 获取触发模式名称
func _get_trigger_mode_name() -> String:
	match trigger_mode:
		TriggerMode.ON_ANY_CHANGE:
			return FuseLocalization.translate("FUSE_DESC_VALUE_ANY_CHANGE")
		TriggerMode.ON_THRESHOLD:
			return FuseLocalization.translate("FUSE_DESC_VALUE_THRESHOLD_TRIGGER")
		TriggerMode.ON_MIN_REACHED:
			return FuseLocalization.translate("FUSE_DESC_VALUE_MIN_TRIGGER")
		TriggerMode.ON_MAX_REACHED:
			return FuseLocalization.translate("FUSE_DESC_VALUE_MAX_TRIGGER")
		_:
			return FuseLocalization.translate("FUSE_TEXT_UNKNOWN")

## 获取事件描述
func get_description() -> String:
	var node_name = target_node_path if not target_node_path.is_empty() else FuseLocalization.translate("FUSE_TEXT_NOT_SPECIFIED")
	var mode_text = _get_trigger_mode_name()

	var threshold_text = ""
	if trigger_mode == TriggerMode.ON_THRESHOLD:
		threshold_text = FuseLocalization.translate_format("FUSE_DESC_THRESHOLD_DETAIL", {"threshold": "%.2f" % threshold_value})
	elif trigger_mode == TriggerMode.ON_MIN_REACHED:
		threshold_text = FuseLocalization.translate_format("FUSE_DESC_MIN_THRESHOLD_DETAIL", {"min": "%.2f" % min_threshold})
	elif trigger_mode == TriggerMode.ON_MAX_REACHED:
		threshold_text = FuseLocalization.translate_format("FUSE_DESC_MAX_THRESHOLD_DETAIL", {"max": "%.2f" % max_threshold})

	return FuseLocalization.translate_format("FUSE_EVENT_ON_VALUE_CHANGED_DESC", {
		"node": node_name,
		"mode": mode_text,
		"threshold": threshold_text
	})

## 获取事件类型
func get_event_type() -> String:
	return "value_changed"

## 获取事件分类
func get_event_category() -> String:
	return "ui"

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	if target_node_path.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))

	return errors

## 重置事件状态
func reset() -> void:
	super.reset()
	var last_value = _get_current_value()
	var was_threshold_reached = _check_threshold(last_value)
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("last_value", last_value)
		_runtime_instance_ref.set_runtime_state("was_threshold_reached", was_threshold_reached)
	_log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_ON_VALUE_CHANGED_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_UI"
	metadata.description_key = "FUSE_EVENT_ON_VALUE_CHANGED_DESC"
	metadata.keywords = ["value", "值", "changed", "改变", "slider", "slider", "spinbox", "progress", "ui", "control"]
	metadata.builtin_icon = "float"
	return metadata
