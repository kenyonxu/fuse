@tool
@icon("res://addons/fuse/icons/builtin/InputEventMouseButton.png")
extends BaseEvent
class_name OnMouseButton

## 鼠标按键事件
##
## 监听鼠标按键事件，支持按下、释放、双击等触发模式。
##
## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - _last_click_time: float - 最近一次点击的时间戳
## - _click_count: int - 当前点击次数（用于双击检测）
##
## 相关文档: addons/fuse/docs/migration-guide-to-runtime-instance.md

## 鼠标按键类型
enum CustomMouseButton {
	LEFT,
	RIGHT,
	MIDDLE,
	WHEEL_UP,
	WHEEL_DOWN
}

## 触发模式
enum TriggerMode {
	PRESSED,
	RELEASED,
	DOUBLE_CLICKED
}

## 监听的鼠标按键
var mouse_button: CustomMouseButton = CustomMouseButton.LEFT:
	set(value):
		mouse_button = value
		_update_resource_name()

## 触发模式
var trigger_mode: TriggerMode = TriggerMode.PRESSED:
	set(value):
		trigger_mode = value
		_update_resource_name()

## 是否需要悬停在节点上
@export var require_hovered: bool = false:
	set(value):
		require_hovered = value
		_update_resource_name()

## 目标节点（用于悬停检测，为空时使用 owner_node）
@export var target_node: NodePath = NodePath("")

# 缓存鼠标按钮类型本地化字符串（静态变量，所有实例共享）
static var _cached_mouse_buttons: Array[String] = []
static var _mouse_buttons_cached: bool = false

# 缓存触发模式本地化字符串（静态变量，所有实例共享）
static var _cached_trigger_modes: Array[String] = []
static var _trigger_modes_cached: bool = false

## 初始化鼠标按钮类型本地化缓存
##
## 这个方法会缓存鼠标按钮类型的本地化字符串，避免在 _get_property_list() 中频繁调用翻译函数
static func _init_mouse_buttons_cache() -> void:
	if _mouse_buttons_cached:
		return

	_cached_mouse_buttons = [
		FuseLocalization.translate("FUSE_EVENT_MOUSE_BUTTON_LEFT"),
		FuseLocalization.translate("FUSE_EVENT_MOUSE_BUTTON_RIGHT"),
		FuseLocalization.translate("FUSE_EVENT_MOUSE_BUTTON_MIDDLE"),
		FuseLocalization.translate("FUSE_EVENT_MOUSE_BUTTON_WHEEL_UP"),
		FuseLocalization.translate("FUSE_EVENT_MOUSE_BUTTON_WHEEL_DOWN")
	]

	_mouse_buttons_cached = true

## 初始化触发模式本地化缓存
##
## 这个方法会缓存触发模式的本地化字符串，避免在 _get_property_list() 中频繁调用翻译函数
static func _init_trigger_modes_cache() -> void:
	if _trigger_modes_cached:
		return

	_cached_trigger_modes = [
		FuseLocalization.translate("FUSE_EVENT_MOUSE_BUTTON_MODE_PRESSED"),
		FuseLocalization.translate("FUSE_EVENT_MOUSE_BUTTON_MODE_RELEASED"),
		FuseLocalization.translate("FUSE_EVENT_MOUSE_BUTTON_MODE_DOUBLE_CLICK")
	]

	_trigger_modes_cached = true

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []

	# 初始化缓存（如果还没有初始化）
	_init_mouse_buttons_cache()
	_init_trigger_modes_cache()

	# 添加鼠标按键类型属性
	# 使用缓存的本地化字符串，避免在 _get_property_list() 中频繁调用翻译函数
	var mouse_buttons_hint: String = ",".join(_cached_mouse_buttons)
	properties.append({
		"name": "mouse_button",
		"type": TYPE_INT,
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": mouse_buttons_hint
	})

	# 添加触发模式属性
	# 使用缓存的本地化字符串，避免在 _get_property_list() 中频繁调用翻译函数
	var trigger_modes_hint: String = ",".join(_cached_trigger_modes)
	properties.append({
		"name": "trigger_mode",
		"type": TYPE_INT,
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": trigger_modes_hint
	})

	return properties

var _target_node_ref: Node = null
var _owner_node_ref: Node = null

## 更新资源名称（必需）
func _update_resource_name():
	var button_name = _get_mouse_button_name_localized()
	var mode_name = _get_trigger_mode_name_localized()
	var hovered_text = ""

	if require_hovered:
		hovered_text = " [%s]" % FuseLocalization.translate("FUSE_EVENT_MOUSE_BUTTON_REQUIRE_HOVERED")

	resource_name = FuseLocalization.translate_format("FUSE_EVENT_MOUSE_BUTTON_RESOURCE_NAME", {
		"button": button_name,
		"mode": mode_name
	}) + hovered_text

## 初始化事件监听（必需）
func initialize(owner_node: Node) -> void:
	# 验证 owner_node
	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	_owner_node_ref = owner_node

	# 获取目标节点（用于悬停检测）
	if not target_node.is_empty():
		_target_node_ref = owner_node.get_node_or_null(target_node)
		if not _target_node_ref:
			_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(target_node)})
			return
	else:
		_target_node_ref = owner_node

	# 连接输入处理（_input() 虚拟方法会自动调用，无需手动启用）
	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	# 🔧 清理 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("last_click_time", 0.0)
		_runtime_instance_ref.set_runtime_state("click_count", 0)

	# 清理引用
	_target_node_ref = null
	_owner_node_ref = null

	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 处理输入事件（由 Trigger._unhandled_input 转发——Resource 的 _input 回调引擎不调用）
func handle_input(event: InputEvent):
	# 只处理鼠标按钮事件
	if not event is InputEventMouseButton:
		return

	var mouse_event = event as InputEventMouseButton

	# 检查按键匹配
	if not _is_mouse_button_match(mouse_event):
		return

	# 检查触发模式
	if not _is_trigger_mode_match(mouse_event):
		return

	# 检查是否需要悬停
	if require_hovered and not _is_hovered():
		_log_debug_localized("FUSE_LOG_EVENT_MOUSE_NOT_HOVERED", {})
		return

	# 处理双击检测
	if trigger_mode == TriggerMode.DOUBLE_CLICKED:
		_handle_double_click(mouse_event)
		var click_count = 0
		if _runtime_instance_ref:
			click_count = _runtime_instance_ref.runtime_state.get("click_count", 0)
		if click_count < 2:
			return

	# 触发事件
	_on_mouse_button_triggered(mouse_event)

## 鼠标按钮触发回调
func _on_mouse_button_triggered(event: InputEventMouseButton):
	var button_name = _get_mouse_button_name()
	var mode_name = _get_trigger_mode_name()
	var position_text = " (%.0f, %.0f)" % [event.position.x, event.position.y]

	_log_info_localized("FUSE_LOG_EVENT_MOUSE_BUTTON_TRIGGERED", {
		"button": button_name,
		"mode": mode_name,
		"position": position_text
	})

	# 创建上下文节点传递事件信息
	var context_node = Node.new()
	context_node.name = "MouseButtonContext"
	context_node.set_meta("button_index", event.button_index)
	context_node.set_meta("position", event.position)
	context_node.set_meta("global_position", event.global_position)
	context_node.set_meta("double_click", event.double_click)
	context_node.set_meta("shift", event.shift_pressed)
	context_node.set_meta("alt", event.alt_pressed)
	context_node.set_meta("ctrl", event.ctrl_pressed)

	triggered.emit(context_node)

## 检查鼠标按钮是否匹配
func _is_mouse_button_match(event: InputEventMouseButton) -> bool:
	var godot_button = _get_godot_mouse_button()
	return event.button_index == godot_button

## 检查触发模式是否匹配
func _is_trigger_mode_match(event: InputEventMouseButton) -> bool:
	match trigger_mode:
		TriggerMode.PRESSED:
			return event.pressed
		TriggerMode.RELEASED:
			return not event.pressed
		TriggerMode.DOUBLE_CLICKED:
			return event.pressed and event.double_click
		_:
			return false

## 检查是否悬停在目标节点上
func _is_hovered() -> bool:
	if not _target_node_ref or not is_instance_valid(_target_node_ref):
		return false

	# 检查是否是 Control 节点
	if _target_node_ref is Control:
		var control = _target_node_ref as Control
		return control.is_hovered()

	# 检查是否是 CollisionObject2D
	if _target_node_ref is CollisionObject2D:
		var collision_object = _target_node_ref as CollisionObject2D
		# 使用 InputEvent 检测碰撞
		var viewport = _target_node_ref.get_viewport()
		if not viewport:
			return false

		var mouse_pos = viewport.get_mouse_position()
		var global_transform = _target_node_ref.get_global_transform()

		# 简单的距离检测（可以改进为精确的形状检测）
		var distance = global_transform.origin.distance_to(mouse_pos)
		return distance < 50.0  # 简化实现

	return false

## 处理双击检测
func _handle_double_click(event: InputEventMouseButton):
	var current_time = Time.get_ticks_msec() / 1000.0
	var double_click_interval = 0.5  # Godot 默认双击间隔

	# 🔧 使用 RuntimeEventInstance 的状态
	var last_click_time = 0.0
	var click_count = 0
	if _runtime_instance_ref:
		last_click_time = _runtime_instance_ref.runtime_state.get("last_click_time", 0.0)
		click_count = _runtime_instance_ref.runtime_state.get("click_count", 0)

	if current_time - last_click_time < double_click_interval:
		click_count += 1
	else:
		click_count = 1

	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("last_click_time", current_time)
		_runtime_instance_ref.set_runtime_state("click_count", click_count)

	# 重置点击计数（延迟）
	if click_count >= 2:
		await _owner_node_ref.get_tree().create_timer(double_click_interval).timeout
		if _runtime_instance_ref:
			_runtime_instance_ref.set_runtime_state("click_count", 0)

## 获取 Godot 鼠标按钮常量
func _get_godot_mouse_button() -> int:
	match mouse_button:
		CustomMouseButton.LEFT:
			return MOUSE_BUTTON_LEFT
		CustomMouseButton.RIGHT:
			return MOUSE_BUTTON_RIGHT
		CustomMouseButton.MIDDLE:
			return MOUSE_BUTTON_MIDDLE
		CustomMouseButton.WHEEL_UP:
			return MOUSE_BUTTON_WHEEL_UP
		CustomMouseButton.WHEEL_DOWN:
			return MOUSE_BUTTON_WHEEL_DOWN
		_:
			return MOUSE_BUTTON_LEFT

## 获取鼠标按钮名称（本地化）
func _get_mouse_button_name_localized() -> String:
	match mouse_button:
		CustomMouseButton.LEFT:
			return FuseLocalization.translate("FUSE_EVENT_MOUSE_BUTTON_LEFT")
		CustomMouseButton.RIGHT:
			return FuseLocalization.translate("FUSE_EVENT_MOUSE_BUTTON_RIGHT")
		CustomMouseButton.MIDDLE:
			return FuseLocalization.translate("FUSE_EVENT_MOUSE_BUTTON_MIDDLE")
		CustomMouseButton.WHEEL_UP:
			return FuseLocalization.translate("FUSE_EVENT_MOUSE_BUTTON_WHEEL_UP")
		CustomMouseButton.WHEEL_DOWN:
			return FuseLocalization.translate("FUSE_EVENT_MOUSE_BUTTON_WHEEL_DOWN")
		_:
			return FuseLocalization.translate("FUSE_EVENT_MOUSE_BUTTON_LEFT")

## 获取鼠标按钮名称（非本地化，用于日志）
func _get_mouse_button_name() -> String:
	return _get_mouse_button_name_localized()

## 获取触发模式名称（本地化）
func _get_trigger_mode_name_localized() -> String:
	match trigger_mode:
		TriggerMode.PRESSED:
			return FuseLocalization.translate("FUSE_EVENT_MOUSE_BUTTON_MODE_PRESSED")
		TriggerMode.RELEASED:
			return FuseLocalization.translate("FUSE_EVENT_MOUSE_BUTTON_MODE_RELEASED")
		TriggerMode.DOUBLE_CLICKED:
			return FuseLocalization.translate("FUSE_EVENT_MOUSE_BUTTON_MODE_DOUBLE_CLICK")
		_:
			return FuseLocalization.translate("FUSE_EVENT_MOUSE_BUTTON_MODE_PRESSED")

## 获取触发模式名称（非本地化，用于日志）
func _get_trigger_mode_name() -> String:
	return _get_trigger_mode_name_localized()

## 获取事件描述
func get_description() -> String:
	var button_name = _get_mouse_button_name_localized()
	var mode_name = _get_trigger_mode_name_localized()

	# require_hovered=false 的语义是"任意位置点击均触发"，与一次性检测无关——
	# 原文案键 TIMING_ONCE（"仅检测一次"）严重误导，用户以为有 once 行为
	var timing_key = "FUSE_EVENT_ON_MOUSE_BUTTON_TIMING_HOVERED" if require_hovered else "FUSE_EVENT_ON_MOUSE_BUTTON_TIMING_ANYWHERE"
	var timing_text = FuseLocalization.translate(timing_key)

	return FuseLocalization.translate_format("FUSE_EVENT_ON_MOUSE_BUTTON_DESC", {
		"button": button_name,
		"mode": mode_name,
		"timing": timing_text
	})

## 获取事件类型
func get_event_type() -> String:
	return "mouse_button"

## 获取事件分类
func get_event_category() -> String:
	return "input"

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	# 验证 trigger_mode 值
	if trigger_mode < 0 or trigger_mode >= TriggerMode.size():
		errors.append(FuseLocalization.translate("FUSE_ERROR_EVENT_INVALID_TRIGGER_MODE"))

	# 验证 mouse_button 值
	if mouse_button < 0 or mouse_button >= CustomMouseButton.size():
		errors.append(FuseLocalization.translate("FUSE_ERROR_EVENT_INVALID_MOUSE_BUTTON"))

	return errors

## 重置事件状态
func reset() -> void:
	super.reset()

	# 🔧 重置 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("last_click_time", 0.0)
		_runtime_instance_ref.set_runtime_state("click_count", 0)

	_log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["last_click_time"] = 0.0
	base["click_count"] = 0
	return base

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_ON_MOUSE_BUTTON_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_INPUT"
	metadata.description_key = "FUSE_EVENT_ON_MOUSE_BUTTON_DESC"
	metadata.keywords = ["mouse", "鼠标", "button", "按键", "click", "点击", "press", "按下", "input", "输入"]
	metadata.builtin_icon = "InputEventMouseButton"
	return metadata
