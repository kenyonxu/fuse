@tool
@icon("res://addons/fuse/icons/builtin/InputEventAction.png")
extends BaseEvent
class_name OnInputCombo

## Event: OnInputCombo
##
## 检测输入序列（搓招）。在时间窗口内按顺序检测一组输入动作。
## 通过 Timer 轮询检测 Input.is_action_just_pressed()。

# =============================================
# 属性定义
# =============================================

## 输入序列（如 ["ui_down","ui_right","ui_accept"]）
var combo_sequence: Array[String] = []:
	set(value):
		combo_sequence = value
		_update_resource_name()

## 整个序列的时间窗口（秒），从第一个输入开始计时
var time_window: float = 0.5:
	set(value):
		time_window = max(value, 0.05)
		_update_resource_name()

## 输入错误时是否重置序列
var reset_on_fail: bool = true:
	set(value):
		reset_on_fail = value
		_update_resource_name()

## 轮询间隔（秒）
var check_interval: float = 0.05:
	set(value):
		check_interval = max(value, 0.016)
		_update_resource_name()

# =============================================
# 运行时状态
# =============================================
var _check_timer: Timer = null
var _owner_node_ref: Node = null
var _combo_index: int = -1
var _combo_start_time: float = 0.0

# =============================================
# 默认运行时状态
# =============================================
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["combo_index"] = -1
	base["combo_start_time"] = 0.0
	return base

# =============================================
# 动态属性列表
# =============================================
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []

	# Combo Sequence
	properties.append({
		"name": "Combo Sequence",
		"type": TYPE_NIL,
		"hint": PROPERTY_HINT_NONE,
		"usage": PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		"name": "combo_sequence",
		"type": TYPE_ARRAY,
		"hint": PROPERTY_HINT_TYPE_STRING,
		"hint_string": "17/17:InputEventAction",
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
	})

	# Timing
	properties.append({
		"name": "Timing",
		"type": TYPE_NIL,
		"hint": PROPERTY_HINT_NONE,
		"usage": PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		"name": "time_window",
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0.05,5.0,0.01",
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
	})

	properties.append({
		"name": "check_interval",
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0.016,0.5,0.001",
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
	})

	# Behavior
	properties.append({
		"name": "Behavior",
		"type": TYPE_NIL,
		"hint": PROPERTY_HINT_NONE,
		"usage": PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		"name": "reset_on_fail",
		"type": TYPE_BOOL,
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
	})

	return properties

func _get(property: StringName):
	if property == "combo_sequence":
		return combo_sequence
	elif property == "time_window":
		return time_window
	elif property == "check_interval":
		return check_interval
	elif property == "reset_on_fail":
		return reset_on_fail
	return null

func _set(property: StringName, value) -> bool:
	if property == "combo_sequence":
		if value is Array:
			combo_sequence = value
		elif value is String:
			combo_sequence = [value]
		_update_resource_name()
		return true
	elif property == "time_window":
		time_window = value
		_update_resource_name()
		return true
	elif property == "check_interval":
		check_interval = value
		_update_resource_name()
		return true
	elif property == "reset_on_fail":
		reset_on_fail = value
		_update_resource_name()
		return true
	return false

# =============================================
# 元数据
# =============================================
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_ON_INPUT_COMBO_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_INPUT"
	metadata.description_key = "FUSE_EVENT_ON_INPUT_COMBO_DESC"
	metadata.keywords = ["输入", "input", "连招", "combo", "搓招", "sequence", "序列", "动作", "action", "格斗", "fighting"]
	metadata.builtin_icon = "InputEventAction"
	return metadata

# =============================================
# 资源名称
# =============================================
func _update_resource_name() -> void:
	var seq_str = ", ".join(combo_sequence) if not combo_sequence.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")
	resource_name = FuseLocalization.translate_format("FUSE_EVENT_ON_INPUT_COMBO_RESOURCE_NAME", {
		"sequence": seq_str,
		"window": time_window
	})

# =============================================
# 初始化
# =============================================
func initialize(owner_node: Node) -> void:
	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	_owner_node_ref = owner_node

	if combo_sequence.is_empty():
		_log_warning_localized("FUSE_ERROR_MISSING_PARAMETER", {"parameter": "combo_sequence"})
		return

	# 验证输入动作
	for action in combo_sequence:
		if not InputMap.has_action(action):
			_log_warning_localized("FUSE_ERROR_INPUT_ACTION_NOT_FOUND", {"action": action})

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		return
	_runtime_instance_ref = runtime_instance
	_combo_index = -1
	_combo_start_time = 0.0

	initialize(owner_node)

	if not owner_node:
		return

	# 创建轮询定时器
	_check_timer = Timer.new()
	_check_timer.name = "FuseComboTimer"
	_check_timer.wait_time = check_interval
	_check_timer.timeout.connect(_check_combo)
	owner_node.add_child(_check_timer)
	_check_timer.start()

	set_trigger_ref(owner_node)

# =============================================
# 清理
# =============================================
func terminate(owner_node: Node) -> void:
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("combo_index", -1)
		_runtime_instance_ref.set_runtime_state("combo_start_time", 0.0)

	if _check_timer and is_instance_valid(_check_timer):
		_check_timer.stop()
		_check_timer.queue_free()
	_check_timer = null

	_owner_node_ref = null
	_combo_index = -1
	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

# =============================================
# 重置
# =============================================
func reset() -> void:
	super.reset()
	_combo_index = -1
	_combo_start_time = 0.0
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("combo_index", -1)
		_runtime_instance_ref.set_runtime_state("combo_start_time", 0.0)
	_log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})

# =============================================
# 类型信息
# =============================================
func get_event_type() -> String:
	return "input_combo"

func get_event_category() -> String:
	return "input"

# =============================================
# 运行时逻辑 — 轮询检测连招
# =============================================
func _check_combo() -> void:
	if combo_sequence.is_empty():
		return

	var current_time = Time.get_ticks_msec() / 1000.0

	# 检查是否有超时
	if _combo_index >= 0:
		if current_time - _combo_start_time > time_window:
			# 时间窗口过期，重置
			_reset_combo()
			return

	# 检测下一个需要的输入
	var next_index = _combo_index + 1

	# 如果序列还未开始，检测第一个输入
	if _combo_index < 0:
		if Input.is_action_just_pressed(combo_sequence[0]):
			# 检测是否同时按下了其他 combo 中的键（防止误触）
			for i in range(1, combo_sequence.size()):
				if Input.is_action_just_pressed(combo_sequence[i]):
					# 有歧义，忽略
					return
			_combo_index = 0
			_combo_start_time = current_time

			# 如果只有一个元素的序列，直接完成
			if combo_sequence.size() == 1:
				_trigger_combo()
				_reset_combo()
			return
	else:
		# 序列进行中，检测下一个输入
		var expected_action = combo_sequence[next_index]

		if Input.is_action_just_pressed(expected_action):
			# 正确输入
			_combo_index = next_index

			# 检查是否序列完成
			if _combo_index >= combo_sequence.size() - 1:
				_trigger_combo()
				_reset_combo()
		else:
			# 检查是否有其他输入（非预期输入）
			if reset_on_fail:
				for action in combo_sequence:
					if Input.is_action_just_pressed(action) and action != expected_action:
						_reset_combo()
						# 检查这个新输入是否是序列的第一个
						if action == combo_sequence[0]:
							_combo_index = 0
							_combo_start_time = current_time
						return

func _trigger_combo() -> void:
	if _runtime_instance_ref:
		_runtime_instance_ref.update_trigger_stats()

	var owner_node: Node = null
	if _owner_node_ref:
		owner_node = _owner_node_ref

	var seq_str = ", ".join(combo_sequence)
	_log_info_localized("FUSE_LOG_COMBO_TRIGGERED", {
		"sequence": seq_str
	})
	_emit_triggered(owner_node)

func _reset_combo() -> void:
	_combo_index = -1
	_combo_start_time = 0.0
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("combo_index", -1)
		_runtime_instance_ref.set_runtime_state("combo_start_time", 0.0)

# =============================================
# 描述
# =============================================
func get_description() -> String:
	var seq_str = ", ".join(combo_sequence) if not combo_sequence.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")
	return FuseLocalization.translate_format("FUSE_EVENT_ON_INPUT_COMBO_DESCRIPTION", {
		"sequence": seq_str,
		"window": time_window
	})

# =============================================
# 验证
# =============================================
func validate() -> Array[String]:
	var errors: Array[String] = []

	if combo_sequence.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_MISSING_PARAMETER"))
		return errors

	for action in combo_sequence:
		if not InputMap.has_action(action):
			errors.append(FuseLocalization.translate_format("FUSE_ERROR_INPUT_ACTION_NOT_FOUND", {"action": action}))

	if time_window <= 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_DURATION_INVALID"))

	return errors
