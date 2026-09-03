@icon("res://addons/fuse/icons/builtin/InputEventAction.png")
@tool
class_name OnInputBuffered extends BaseEvent

## 监测输入缓冲：在缓冲窗口内检测输入动作并触发事件

# =============================================
# 属性定义
# =============================================

## 要监听的输入动作名列表
var input_actions: Array[String] = []:
	set(value):
		input_actions = value
		_update_resource_name()

## 缓冲时间窗口（秒）
var buffer_window: float = 0.15:
	set(value):
		buffer_window = value
		_update_resource_name()

## 是否消耗输入事件
var consume_input: bool = true:
	set(value):
		consume_input = value
		_update_resource_name()

## 优先级（越高越先处理）
var priority: int = 0:
	set(value):
		priority = value
		_update_resource_name()

# =============================================
# 运行时状态
# =============================================
var _owner_node_ref: Node = null
var _is_updating_name: bool = false

# =============================================
# 动态属性列表
# =============================================
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []

	# Input Actions（使用字符串，逗号分隔）
	properties.append({
		"name": "input_actions",
		"type": TYPE_ARRAY,
		"hint": PROPERTY_HINT_TYPE_STRING,
		"hint_string": "17/17:InputEventAction",
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
	})

	# Buffer 配置
	properties.append({
		"name": "buffer_window",
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0.01,2.0,0.01",
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
	})

	properties.append({
		"name": "consume_input",
		"type": TYPE_BOOL,
		"hint": PROPERTY_HINT_NONE,
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
	})

	properties.append({
		"name": "priority",
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_NONE,
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
	})

	return properties

func _get(property: StringName):
	if property == "input_actions":
		return input_actions
	elif property == "buffer_window":
		return buffer_window
	elif property == "consume_input":
		return consume_input
	elif property == "priority":
		return priority
	return null

func _set(property: StringName, value) -> bool:
	if property == "input_actions":
		if value is Array:
			input_actions = value
		elif value is String:
			input_actions = [value]
		_update_resource_name()
		return true
	elif property == "buffer_window":
		buffer_window = value
		_update_resource_name()
		return true
	elif property == "consume_input":
		consume_input = value
		_update_resource_name()
		return true
	elif property == "priority":
		priority = value
		_update_resource_name()
		return true
	return false

# =============================================
# 元数据（必需）
# =============================================
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_ON_INPUT_BUFFERED_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_INPUT"
	metadata.description_key = "FUSE_EVENT_ON_INPUT_BUFFERED_DESC"
	metadata.keywords = ["输入", "input", "缓冲", "buffer", "动作", "action", "按键", "key", "连招", "combo"]
	metadata.builtin_icon = "InputEventAction"
	return metadata

# =============================================
# 资源名称
# =============================================
func _update_resource_name() -> void:
	if _is_updating_name:
		return
	_is_updating_name = true

	var actions_str = ", ".join(input_actions) if not input_actions.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")
	resource_name = FuseLocalization.translate_format("FUSE_EVENT_ON_INPUT_BUFFERED_RESOURCE_NAME", {
		"actions": actions_str,
		"window": buffer_window
	})

	_is_updating_name = false

# =============================================
# 初始化
# =============================================
func initialize(owner_node: Node) -> void:
	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return
	_owner_node_ref = owner_node

	# 验证输入动作
	if input_actions.is_empty():
		_log_warning_localized("FUSE_ERROR_MISSING_PARAMETER", {"param": "input_actions"})
		return

	# 检查 InputMap 中的动作
	for action in input_actions:
		if not InputMap.has_action(action):
			_log_warning_localized("FUSE_ERROR_INPUT_ACTION_NOT_FOUND", {"action": action})

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

# =============================================
# 运行时实例初始化
# =============================================
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		return
	_runtime_instance_ref = runtime_instance
	initialize(owner_node)

# =============================================
# 清理
# =============================================
func terminate(owner_node: Node) -> void:
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("buffered_inputs", [])
	_owner_node_ref = null
	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

# =============================================
# 默认运行时状态
# =============================================
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["buffered_inputs"] = []  # Array[Dictionary]
	base["last_processed_time"] = 0.0
	return base

# =============================================
# 类型信息
# =============================================
func get_event_type() -> String:
	return "input_buffered"

func get_event_category() -> String:
	return "input"

# =============================================
# 运行时逻辑 — 处理输入事件
# =============================================
func handle_input(event: InputEvent) -> void:
	if input_actions.is_empty():
		return

	# 确定动作名称
	var action_name = ""
	if event is InputEventAction:
		action_name = (event as InputEventAction).action
	elif event is InputEventKey:
		for action in input_actions:
			if InputMap.event_is_action(event, action):
				action_name = action
				break

	if action_name.is_empty() or not action_name in input_actions:
		return

	# 获取运行时状态中的缓冲列表
	var buffered_inputs: Array = []
	if _runtime_instance_ref:
		var state = _runtime_instance_ref.get_runtime_state("buffered_inputs")
		if state is Array:
			buffered_inputs = state

	# 记录输入时间戳
	buffered_inputs.append({
		"action": action_name,
		"timestamp": Time.get_ticks_msec() / 1000.0,
		"pressed": event.is_pressed()
	})

	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("buffered_inputs", buffered_inputs)

	# 处理缓冲
	_process_buffer()

func _process_buffer() -> void:
	var buffered_inputs: Array = []
	if _runtime_instance_ref:
		var state = _runtime_instance_ref.get_runtime_state("buffered_inputs")
		if state is Array:
			buffered_inputs = state

	var current_time = Time.get_ticks_msec() / 1000.0
	var valid_inputs: Array = []
	var has_triggered_signal := false

	for entry in buffered_inputs:
		if entry is Dictionary:
			if current_time - entry.get("timestamp", 0.0) <= buffer_window:
				valid_inputs.append(entry)
				if entry.get("pressed", false) and not has_triggered_signal:
					has_triggered_signal = true
					# 触发事件
					if _runtime_instance_ref:
						_runtime_instance_ref.update_trigger_stats()

					var owner_node: Node = null
					if _owner_node_ref:
						owner_node = _owner_node_ref

					_log_info_localized("FUSE_LOG_EVENT_INPUT_ACTION_TRIGGERED", {
						"action": entry.get("action", ""),
						"mode": "buffered"
					})
					_emit_triggered(owner_node)

	# 更新缓冲（移除过期的）
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("buffered_inputs", valid_inputs)

# =============================================
# 重置事件状态
# =============================================
func reset() -> void:
	super.reset()
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("buffered_inputs", [])
	_log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})

# =============================================
# 描述
# =============================================
func get_description() -> String:
	var actions_str = ", ".join(input_actions) if not input_actions.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")
	return FuseLocalization.translate_format("FUSE_EVENT_ON_INPUT_BUFFERED_DESCRIPTION", {
		"actions": actions_str,
		"window": buffer_window
	})

# =============================================
# 验证
# =============================================
func validate() -> Array[String]:
	var errors: Array[String] = []

	if input_actions.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_MISSING_PARAMETER"))
		return errors

	for action in input_actions:
		if not InputMap.has_action(action):
			errors.append(FuseLocalization.translate_format("FUSE_ERROR_INPUT_ACTION_NOT_FOUND", {"action": action}))

	return errors
