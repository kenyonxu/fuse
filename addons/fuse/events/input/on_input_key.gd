@icon("res://addons/fuse/icons/builtin/InputEventKey.png")
# 文件：addons/fuse/events/on_input_key.gd
@tool
class_name OnInputKey extends BaseEvent

## 要监听的按键代码
@export var key_code: int = KEY_NONE:
	set(value):
		if key_code != value:
			key_code = value
			_update_resource_name()
			notify_property_list_changed()  # 触发检视器更新

## 按键事件类型
var key_event_type: int = 0:
	set(value):
		if key_event_type != value:
			key_event_type = value
			_update_resource_name()
			notify_property_list_changed()  # 触发检视器更新

## 初始化按键事件类型本地化缓存
##
## 这个方法会缓存按键事件类型的本地化字符串，避免在 _get_property_list() 中频繁调用翻译函数
static func _init_key_event_types_cache() -> void:
	if _key_event_types_cached:
		return

	_cached_key_event_types = FuseLocalization.translate("FUSE_ENUM_KEY_TRIGGER_MODE")
	_key_event_types_cached = true

func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []

	# 初始化缓存（如果还没有初始化）
	_init_key_event_types_cache()

	# 添加按键事件类型属性
	# 使用缓存的本地化字符串，避免在 _get_property_list() 中频繁调用翻译函数
	properties.append({
		"name": "key_event_type",
		"type": TYPE_INT,
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": _cached_key_event_types
	})

	return properties

## 持续按下事件的初始延迟（秒）
@export var held_initial_delay: float = 1.0:
	set(value):
		if held_initial_delay != value:
			held_initial_delay = value
			_update_resource_name()
			notify_property_list_changed()  # 触发检视器更新

## 持续按下事件的重复间隔（秒）
@export var held_repeat_interval: float = 0.2:
	set(value):
		if held_repeat_interval != value:
			held_repeat_interval = value
			_update_resource_name()
			notify_property_list_changed()  # 触发检视器更新

## 是否只触发一次（仅对 pressed 和 released 有效）
@export var trigger_once: bool = false:
	set(value):
		if trigger_once != value:
			trigger_once = value
			_update_resource_name()
			notify_property_list_changed()  # 触发检视器更新

## 自定义按键名称（用于显示）
@export var custom_key_name: String = "":
	set(value):
		if custom_key_name != value:
			custom_key_name = value
			_update_resource_name()
			notify_property_list_changed()  # 触发检视器更新

## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - _is_key_pressed: bool - 按键是否按下
## - _has_triggered: bool - 是否已触发
##
## 相关文档: addons/fuse/docs/zh_CN/dev_docs/guides/runtime-instance-migration-guide.md

# 缓存按键事件类型本地化字符串
static var _cached_key_event_types: String = ""
static var _key_event_types_cached: bool = false

## 🔧 Timer 对象仍在 Event 类中管理（不存储在 RuntimeEventInstance）
var _held_timer: Timer = null

## 🔧 信号连接注册表：为每个 Trigger 存储独立的连接信息
## key: owner_node.get_instance_id()
## value: { "timer": Timer, "owner": Node }
var _signal_connections: Dictionary = {}

## 🔧 缓存 owner_node 引用，用于访问节点
var _owner_node_ref: Node = null

# 实现条件化检视器显示（使用 _validate_property 方法）
func _validate_property(property: Dictionary) -> void:
	# 当按键事件类型不是持续按下时，禁用持续按下相关属性
	if key_event_type != 2:  # 不是持续按下事件
		if property.name == "held_initial_delay" or property.name == "held_repeat_interval":
			property.usage = PROPERTY_USAGE_READ_ONLY

	# 当按键事件类型是持续按下时，禁用 trigger_once 属性
	if key_event_type == 2:  # 持续按下事件
		if property.name == "trigger_once":
			property.usage = PROPERTY_USAGE_READ_ONLY

# 根据属性设置更新在列表中的名称
func _update_resource_name():
	var key_name = _get_key_name()
	var mode_key = ""
	var timing_text = ""

	match key_event_type:
		0:  # 按下
			mode_key = "FUSE_EVENT_INPUT_KEY_MODE_PRESSED"
			var once_key = "FUSE_EVENT_INPUT_KEY_TIMING_ONCE" if trigger_once else ""
			timing_text = FuseLocalization.translate(once_key) if trigger_once else ""
		1:  # 释放
			mode_key = "FUSE_EVENT_INPUT_KEY_MODE_RELEASED"
			var once_key = "FUSE_EVENT_INPUT_KEY_TIMING_ONCE" if trigger_once else ""
			timing_text = FuseLocalization.translate(once_key) if trigger_once else ""
		2:  # 持续按下
			mode_key = "FUSE_EVENT_INPUT_KEY_MODE_HELD"
			var delay_str = FuseLocalization.translate_format(
				"FUSE_EVENT_INPUT_KEY_TIMING_DELAY",
				{"delay": str(held_initial_delay)}
			)
			var interval_str = FuseLocalization.translate_format(
				"FUSE_EVENT_INPUT_KEY_TIMING_INTERVAL",
				{"interval": str(held_repeat_interval)}
			)
			timing_text = delay_str + ", " + interval_str

	var mode_text = FuseLocalization.translate(mode_key)
	resource_name = FuseLocalization.translate_format(
		"FUSE_EVENT_INPUT_KEY_RESOURCE_NAME",
		{"mode": mode_text, "key": key_name, "timing": timing_text}
	)

## 初始化事件监听（必需）- 向后兼容
func initialize(owner_node: Node) -> void:
	# 验证 owner_node
	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	_owner_node_ref = owner_node

	# 验证按键代码
	if key_code == KEY_NONE:
		_create_fuse_error_localized("FUSE_ERROR_MISSING_PARAMETER", FuseError.ErrorType.CONFIGURATION_ERROR, {"parameter": "key_code"})
		return

	# 连接输入处理
	if not owner_node.tree_entered.is_connected(_on_tree_entered):
		owner_node.tree_entered.connect(_on_tree_entered)

	# 如果已经在场景树中，立即设置输入处理
	if owner_node.is_inside_tree():
		_setup_input_processing(owner_node)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 🔧 使用 RuntimeEventInstance 初始化事件
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		_log_debug("编辑器模式下，跳过事件初始化")
		return

	# 验证 owner_node
	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	_owner_node_ref = owner_node

	# 验证按键代码
	if key_code == KEY_NONE:
		_create_fuse_error_localized("FUSE_ERROR_MISSING_PARAMETER", FuseError.ErrorType.CONFIGURATION_ERROR, {"parameter": "key_code"})
		return

	# 连接输入处理
	if not owner_node.tree_entered.is_connected(_on_tree_entered):
		owner_node.tree_entered.connect(_on_tree_entered)

	# 如果已经在场景树中，立即设置输入处理
	if owner_node.is_inside_tree():
		_setup_input_processing(owner_node)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

func terminate(owner_node: Node) -> void:
	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

	# 断开信号连接
	if owner_node:
		if owner_node.tree_entered.is_connected(_on_tree_entered):
			owner_node.tree_entered.disconnect(_on_tree_entered)

	# 清理定时器
	_cleanup_held_timer(owner_node)

	# 🔧 清理 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("is_key_pressed", false)
		_runtime_instance_ref.set_runtime_state("has_triggered", false)

	_owner_node_ref = null

	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

func _setup_input_processing(owner_node: Node):
	if not owner_node:
		return

	# 确保节点可以处理未处理的按键输入
	owner_node.set_process_unhandled_key_input(true)

func _on_tree_entered():
	if _owner_node_ref:
		_setup_input_processing(_owner_node_ref)

func _handle_key_pressed(owner_node: Node):
	_log_debug_localized("FUSE_LOG_EVENT_KEY_PRESSED", {"key": _get_key_name()})

	# 🔧 使用 RuntimeEventInstance 的状态
	var has_triggered = false
	if _runtime_instance_ref:
		has_triggered = _runtime_instance_ref.runtime_state.get("has_triggered", false)

	# 检查是否只触发一次
	if trigger_once and has_triggered:
		_log_debug_localized("FUSE_LOG_EVENT_INPUT_KEY_TRIGGERED", {"key": _get_key_name(), "status": "already_triggered"})
		return

	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("has_triggered", true)
		_runtime_instance_ref.update_trigger_stats()

	_log_info_localized("FUSE_LOG_EVENT_INPUT_KEY_TRIGGERED", {"key": _get_key_name()})

	var context_node = Node.new()
	context_node.name = "InputKeyContext"
	context_node.set_meta("trigger", owner_node)
	triggered.emit(context_node)
	context_node.queue_free()

func _handle_key_released(owner_node: Node):
	_log_debug_localized("FUSE_LOG_EVENT_KEY_PRESSED", {"key": _get_key_name(), "action": "released"})

	# 🔧 使用 RuntimeEventInstance 的状态
	var has_triggered = false
	if _runtime_instance_ref:
		has_triggered = _runtime_instance_ref.runtime_state.get("has_triggered", false)

	# 检查是否只触发一次
	if trigger_once and has_triggered:
		_log_debug_localized("FUSE_LOG_EVENT_INPUT_KEY_TRIGGERED", {"key": _get_key_name(), "status": "already_triggered"})
		return

	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("has_triggered", true)
		_runtime_instance_ref.update_trigger_stats()

	_log_info_localized("FUSE_LOG_EVENT_INPUT_KEY_TRIGGERED", {"key": _get_key_name(), "action": "released"})

	var context_node = Node.new()
	context_node.name = "InputKeyContext"
	context_node.set_meta("trigger", owner_node)
	triggered.emit(context_node)
	context_node.queue_free()

	# 按键释放后重置触发状态，允许下次按键再次触发
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("has_triggered", false)

func _handle_key_held_start(owner_node: Node):
	# 🔧 使用 RuntimeEventInstance 的状态
	var is_key_pressed = false
	if _runtime_instance_ref:
		is_key_pressed = _runtime_instance_ref.runtime_state.get("is_key_pressed", false)

	if is_key_pressed:
		return  # 已经在按下状态

	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("is_key_pressed", true)

	_log_debug_localized("FUSE_LOG_EVENT_KEY_PRESSED", {"key": _get_key_name(), "action": "held_start"})

	# 创建定时器
	_create_held_timer(owner_node)

	# 立即触发一次（持续按下事件不受 trigger_once 限制）
	if _runtime_instance_ref:
		_runtime_instance_ref.update_trigger_stats()

	_log_info_localized("FUSE_LOG_EVENT_INPUT_KEY_TRIGGERED", {"key": _get_key_name(), "action": "held"})

	var context_node = Node.new()
	context_node.name = "InputKeyContext"
	context_node.set_meta("trigger", owner_node)
	triggered.emit(context_node)
	context_node.queue_free()

func _handle_key_held_end(owner_node: Node):
	# 🔧 使用 RuntimeEventInstance 的状态
	var is_key_pressed = false
	if _runtime_instance_ref:
		is_key_pressed = _runtime_instance_ref.runtime_state.get("is_key_pressed", false)

	if not is_key_pressed:
		return

	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("is_key_pressed", false)

	_log_debug_localized("FUSE_LOG_EVENT_KEY_PRESSED", {"key": _get_key_name(), "action": "held_end"})

	# 清理定时器
	_cleanup_held_timer(owner_node)

func _create_held_timer(owner_node: Node):
	if not owner_node:
		return

	_cleanup_held_timer(owner_node)

	var owner_id = owner_node.get_instance_id()

	var timer = Timer.new()
	timer.wait_time = held_initial_delay
	timer.one_shot = false
	timer.timeout.connect(_on_held_timer_timeout.bind(owner_node))
	owner_node.add_child(timer)
	timer.start()

	# 保存连接信息
	_signal_connections[owner_id] = {
		"timer": timer,
		"owner": owner_node
	}

func _on_held_timer_timeout(owner_node: Node):
	_log_debug_localized("FUSE_LOG_EVENT_KEY_PRESSED", {"key": _get_key_name(), "action": "repeat"})

	var owner_id = owner_node.get_instance_id()
	if _signal_connections.has(owner_id):
		var conn_info = _signal_connections[owner_id]
		var timer = conn_info.get("timer")

		if timer:
			# 更新定时器间隔为重复间隔
			if timer.wait_time != held_repeat_interval:
				timer.wait_time = held_repeat_interval

	# 触发事件
	if _runtime_instance_ref:
		_runtime_instance_ref.update_trigger_stats()

	_log_info_localized("FUSE_LOG_EVENT_INPUT_KEY_TRIGGERED", {"key": _get_key_name(), "action": "repeat"})

	var context_node = Node.new()
	context_node.name = "InputKeyContext"
	context_node.set_meta("trigger", owner_node)
	triggered.emit(context_node)
	context_node.queue_free()

func _cleanup_held_timer(owner_node: Node):
	if not owner_node:
		return

	var owner_id = owner_node.get_instance_id()

	if _signal_connections.has(owner_id):
		var conn_info = _signal_connections[owner_id]
		var timer = conn_info.get("timer")

		if timer and is_instance_valid(timer):
			# 先停止定时器
			timer.stop()

			if timer.timeout.is_connected(_on_held_timer_timeout.bind(owner_node)):
				timer.timeout.disconnect(_on_held_timer_timeout.bind(owner_node))

			if owner_node and is_instance_valid(owner_node):
				owner_node.remove_child(timer)

			timer.queue_free()

		_signal_connections.erase(owner_id)

func _get_key_name() -> String:
	if not custom_key_name.is_empty():
		return custom_key_name

	if key_code == KEY_NONE:
		return "未设置"

	return OS.get_keycode_string(key_code)

func get_description() -> String:
	var key_name = _get_key_name()
	var mode_key = ""
	var timing_key = ""

	match key_event_type:
		0:  # 按下
			mode_key = "FUSE_EVENT_INPUT_KEY_MODE_PRESSED"
			timing_key = "FUSE_EVENT_ON_INPUT_KEY_MODE_ONCE" if trigger_once else ""
		1:  # 释放
			mode_key = "FUSE_EVENT_INPUT_KEY_MODE_RELEASED"
			timing_key = "FUSE_EVENT_ON_INPUT_KEY_MODE_ONCE" if trigger_once else ""
		2:  # 持续按下
			mode_key = "FUSE_EVENT_INPUT_KEY_MODE_HELD"
			timing_key = "FUSE_EVENT_ON_INPUT_KEY_MODE_DELAY"

	var mode_text = FuseLocalization.translate(mode_key)
	var timing_text = ""

	if key_event_type == 2:  # 持续按下
		timing_text = FuseLocalization.translate_format(
			"FUSE_EVENT_ON_INPUT_KEY_MODE_INTERVAL",
			{"interval": str(held_repeat_interval)}
		)
	elif trigger_once and timing_key != "":
		timing_text = FuseLocalization.translate(timing_key)

	return FuseLocalization.translate_format(
		"FUSE_EVENT_ON_INPUT_KEY_DESC",
		{"mode": mode_text, "key": key_name, "timing": timing_text}
	)

func get_event_type() -> String:
	return "input_key"

func get_event_category() -> String:
	return "input"

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["is_key_pressed"] = false
	base["has_triggered"] = false
	return base

func validate() -> Array[String]:
	var errors: Array[String] = []

	# 验证按键代码
	if key_code == KEY_NONE:
		errors.append(FuseLocalization.translate("FUSE_ERROR_KEY_CODE_NOT_SET"))

	# 验证持续按下参数
	if key_event_type == 2:  # 持续按下
		if held_initial_delay < 0:
			errors.append(FuseLocalization.translate("FUSE_ERROR_KEY_DELAY_NEGATIVE"))

		if held_repeat_interval < 0.1:
			errors.append(FuseLocalization.translate("FUSE_ERROR_KEY_INTERVAL_TOO_SMALL"))

	return errors

func reset() -> void:
	super.reset()

	# 🔧 重置 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("is_key_pressed", false)
		_runtime_instance_ref.set_runtime_state("has_triggered", false)

	if _owner_node_ref:
		_cleanup_held_timer(_owner_node_ref)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 处理输入事件
## 这个方法由 Trigger 的 _unhandled_input 虚函数调用
func handle_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return

	if event.keycode != key_code:
		return

	# 标记事件已处理，避免被其他节点处理
	if _owner_node_ref and is_instance_valid(_owner_node_ref):
		_owner_node_ref.get_viewport().set_input_as_handled()

	match key_event_type:
		0:  # 按下
			if event.pressed and not event.is_echo():
				if _owner_node_ref:
					_handle_key_pressed(_owner_node_ref)
		1:  # 释放
			if not event.pressed:
				if _owner_node_ref:
					_handle_key_released(_owner_node_ref)
		2:  # 持续按下
			if event.pressed:
				if not event.is_echo():
					if _owner_node_ref:
						_handle_key_held_start(_owner_node_ref)
			else:
				if _owner_node_ref:
					_handle_key_held_end(_owner_node_ref)

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_ON_INPUT_KEY_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_INPUT"
	metadata.description_key = "FUSE_EVENT_ON_INPUT_KEY_DESC"
	metadata.keywords = ["key", "按键", "input", "输入", "keyboard", "键盘", "press", "按下", "release", "释放"]
	metadata.builtin_icon = "InputEventKey"
	return metadata
