@icon("res://addons/fuse/icons/builtin/InputEventAction.png")
# 文件：addons/fuse/events/input/on_input_action_composite.gd
@tool
class_name OnInputActionComposite extends BaseEvent

## Event: OnInputActionComposite
##
## 监听多个 InputAction，当其中任意一个有输入时触发
## 发出合并后的输入向量，支持对角线移动
##
## 架构版本: 自声明状态模式 v2.0
## 相关文档: addons/fuse/docs/migration-guide-to-runtime-instance.md

## 向上移动的 InputAction 名称
var action_up: String = "":
	set(value):
		action_up = value
		if Engine.is_editor_hint():
			_update_resource_name()

## 向下移动的 InputAction 名称
var action_down: String = "":
	set(value):
		action_down = value
		if Engine.is_editor_hint():
			_update_resource_name()

## 向左移动的 InputAction 名称
var action_left: String = "":
	set(value):
		action_left = value
		if Engine.is_editor_hint():
			_update_resource_name()

## 向右移动的 InputAction 名称
var action_right: String = "":
	set(value):
		action_right = value
		if Engine.is_editor_hint():
			_update_resource_name()

## 触发帧率，控制事件触发频率
## 较高的帧率会让移动更流畅，但会增加系统负载
## 较低的帧率会降低性能开销，但可能感觉卡顿
enum TriggerRate {
	FPS_60 = 0,  ## 60 FPS，最流畅（每 16ms 触发一次）
	FPS_30 = 1,  ## 30 FPS，性能平衡（每 33ms 触发一次）
	FPS_20 = 2,  ## 20 FPS，低性能设备（每 50ms 触发一次）
	FPS_10 = 3,  ## 10 FPS，不推荐，会有明显卡顿（每 100ms 触发一次）
}

@export var trigger_rate: TriggerRate = TriggerRate.FPS_60:
	set(value):
		trigger_rate = value
		var interval_ms = _get_trigger_interval_ms()
		if _runtime_instance_ref:
			_runtime_instance_ref.set_runtime_state("trigger_cooldown", interval_ms)
		if Engine.is_editor_hint():
			_update_resource_name()

## 是否在输入归零时触发事件
## 启用后，当用户释放所有方向键时会触发一次事件，指令可以获取零向量
@export var trigger_on_zero: bool = false:
	set(value):
		trigger_on_zero = value
		if Engine.is_editor_hint():
			_update_resource_name()

## 虚拟属性：使用提示（仅用于 Inspector 显示）
var _usage_hint: String = "":
	set(value):
		pass  # 忽略设置，这是只读的提示信息
	get:
		# 动态返回翻译后的提示文本
		return FuseLocalization.translate("FUSE_EVENT_INPUT_ACTION_COMPOSITE_USAGE_HINT")

# 防止 _update_resource_name() 递归调用
var _is_updating_name: bool = false

# 缓存 Input Actions 列表（静态变量，所有实例共享）
static var _cached_input_actions: Array[String] = []
static var _input_actions_cached: bool = false
static var _cached_none_text: String = ""

## 根据触发帧率获取对应的毫秒间隔
func _get_trigger_interval_ms() -> int:
	match trigger_rate:
		TriggerRate.FPS_60:
			return 16
		TriggerRate.FPS_30:
			return 33
		TriggerRate.FPS_20:
			return 50
		TriggerRate.FPS_10:
			return 100
		_:
			return 16  # 默认 60 FPS

# --- 核心实现：动态下拉菜单 ---

## 初始化 Input Actions 缓存
static func _init_input_actions_cache() -> void:
	if _input_actions_cached:
		return

	# 缓存 "None" 翻译文本
	_cached_none_text = FuseLocalization.translate("FUSE_INPUT_ACTION_NONE")

	var property_list = ProjectSettings.get_property_list()

	for prop in property_list:
		if prop.has("name"):
			var prop_name = String(prop.name)
			if prop_name.begins_with("input/"):
				var action_name = prop_name.substr(6)
				if not action_name.begins_with("ui_") and not action_name.begins_with("spatial_"):
					if action_name not in _cached_input_actions:
						_cached_input_actions.append(action_name)

	_cached_input_actions.sort()

	# 在排序后，将 "None" 选项（空字符串）插入到开头
	_cached_input_actions.push_front("")

	_input_actions_cached = true
	FuseLogger.log_debug_localized("OnInputActionComposite", FuseLogger.LogLevel.DEBUG, "FUSE_LOG_INPUT_ACTIONS_CACHED", {"count": _cached_input_actions.size()})

## 刷新 Input Actions 缓存
static func refresh_input_actions_cache() -> void:
	_cached_input_actions.clear()
	_input_actions_cached = false
	_init_input_actions_cache()
	FuseLogger.log_debug_localized("OnInputActionComposite", FuseLogger.LogLevel.DEBUG, "FUSE_LOG_INPUT_ACTIONS_CACHE_REFRESHED", {})

func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []

	_init_input_actions_cache()

	# 构建 hint_string，第一个选项是 "None"（使用缓存的翻译文本）
	var hint_string: String = _cached_none_text + "," + ",".join(_cached_input_actions)

	# ===== 添加使用提示信息区域 =====
	properties.append({
		"name": "_usage_info_section",
		"type": TYPE_NIL,
		"usage": PROPERTY_USAGE_CATEGORY | PROPERTY_USAGE_EDITOR,
	})

	# 注意：这个属性用于显示使用提示，实际内容通过 getter 提供
	properties.append({
		"name": "_usage_hint",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY,
		"hint": PROPERTY_HINT_MULTILINE_TEXT
	})
	# ==================================

	# 添加四个方向的动作属性
	properties.append({
		"name": "action_up",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": hint_string
	})

	properties.append({
		"name": "action_down",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": hint_string
	})

	properties.append({
		"name": "action_left",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": hint_string
	})

	properties.append({
		"name": "action_right",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": hint_string
	})

	# 添加 trigger_on_zero 配置项
	properties.append({
		"name": "trigger_on_zero",
		"type": TYPE_BOOL,
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR,
		"hint": PROPERTY_HINT_NONE,
		"hint_string": FuseLocalization.translate("FUSE_EVENT_INPUT_ACTION_COMPOSITE_TRIGGER_ON_ZERO_DESC")
	})

	return properties

# --- BaseEvent 接口实现 ---

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["owner_node_ref"] = null
	base["last_input_vector"] = Vector2.ZERO
	return base

## 使用 RuntimeInstance 初始化事件
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		return

	_runtime_instance_ref = runtime_instance

	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		push_error("[Fuse] Owner node is null for OnInputActionComposite")
		return

	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("owner_node_ref", weakref(owner_node))
		_runtime_instance_ref.set_runtime_state("trigger_cooldown", _get_trigger_interval_ms())

	# 获取 "无" 选项的本地化文本
	var none_option = FuseLocalization.translate("FUSE_INPUT_ACTION_NONE")

	# 检查是否至少配置了一个动作（允许某些方向为 "None"/空字符串）
	if action_up.is_empty() and action_down.is_empty() and action_left.is_empty() and action_right.is_empty():
		_log_warning_localized("FUSE_ERROR_INPUT_ACTION_COMPOSITE_NO_ACTIONS")

	# 检查是否所有方向都是 "None"
	if (action_up.is_empty() or action_up == none_option) and \
	   (action_down.is_empty() or action_down == none_option) and \
	   (action_left.is_empty() or action_left == none_option) and \
	   (action_right.is_empty() or action_right == none_option):
		_log_warning_localized("FUSE_ERROR_INPUT_ACTION_COMPOSITE_NO_ACTIONS")

	# 启用 processing 以接收 NOTIFICATION_PROCESS
	_log_debug("OnInputActionComposite: Calling set_process(true) on owner_node")
	owner_node.set_process(true)
	_log_debug("OnInputActionComposite: Process enabled successfully")

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 处理 PROCESS 通知
func handle_process_notification() -> void:
	_process_inputs()

func terminate(owner_node: Node) -> void:
	if Engine.is_editor_hint():
		return

	# 禁用 processing
	if owner_node:
		owner_node.set_process(false)

	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("owner_node_ref", null)
		_runtime_instance_ref.set_runtime_state("input_vector", Vector2.ZERO)
		_runtime_instance_ref = null

	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 重置事件状态
func reset() -> void:
	super.reset()
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("owner_node_ref", null)
		_runtime_instance_ref.set_runtime_state("last_input_vector", Vector2.ZERO)
		_runtime_instance_ref.set_runtime_state("input_vector", Vector2.ZERO)
		_runtime_instance_ref.set_runtime_state("last_trigger_time", null)
		_runtime_instance_ref.set_runtime_state("trigger_cooldown", _get_trigger_interval_ms())
	_log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})

## 每帧处理输入事件
func _process_inputs() -> void:
	if not _runtime_instance_ref:
		_log_debug("OnInputActionComposite._process_inputs: No runtime instance ref")
		return

	_log_debug("OnInputActionComposite._process_inputs: Checking inputs...")

	# 计算输入向量（使用 Godot 标准方法）
	var input_vector = _get_input_vector()
	_log_debug("OnInputActionComposite._process_inputs: Input vector = " + str(input_vector))

	# 检查输入向量是否改变
	var last_vector = _runtime_instance_ref.get_runtime_state("last_input_vector")
	if last_vector == null:
		last_vector = Vector2.ZERO

	# 更新 last_input_vector
	_runtime_instance_ref.set_runtime_state("last_input_vector", input_vector)

	# 从 RuntimeInstance 获取 owner_node 引用
	var owner_node: Node = null
	var owner_ref = _runtime_instance_ref.get_runtime_state("owner_node_ref")
	if owner_ref and owner_ref.get_ref():
		owner_node = owner_ref.get_ref()

	# 只有非零输入向量才触发事件
	if input_vector != Vector2.ZERO:
		# 将 input_vector 存储到 runtime_state，供指令使用
		_runtime_instance_ref.set_runtime_state("input_vector", input_vector)

		# 检查是否需要限制触发频率
		var current_time = Time.get_ticks_msec()
		var last_trigger_time = _runtime_instance_ref.get_runtime_state("last_trigger_time")
		if last_trigger_time == null:
			last_trigger_time = 0
		var trigger_cooldown = _runtime_instance_ref.get_runtime_state("trigger_cooldown")
		if trigger_cooldown == null:
			trigger_cooldown = _get_trigger_interval_ms()  # 使用配置的值

		# 如果输入向量改变了，或者超过了冷却时间，则触发
		if input_vector != last_vector or (current_time - last_trigger_time >= trigger_cooldown):
			_runtime_instance_ref.set_runtime_state("last_trigger_time", current_time)

			_log_info_localized("FUSE_LOG_INPUT_ACTION_COMPOSITE_TRIGGERED", {"vector": str(input_vector)})
			# 发出信号，传递输入向量和上下文节点
			triggered.emit(owner_node)
	else:
		# 输入向量为零时，保存零向量
		_runtime_instance_ref.set_runtime_state("input_vector", Vector2.ZERO)

		# 如果启用了 trigger_on_zero，且上一帧是非零向量，则触发归零事件
		if trigger_on_zero and last_vector != Vector2.ZERO:
			_log_info_localized("FUSE_LOG_INPUT_ACTION_COMPOSITE_ZERO", {})
			triggered.emit(owner_node)

## 计算输入向量
func _get_input_vector() -> Vector2:
	var x = 0.0
	var y = 0.0

	# 获取 "无" 选项的本地化文本
	var none_option = FuseLocalization.translate("FUSE_INPUT_ACTION_NONE")

	# 只有当方向不为空且不为 "None" 时才检查输入
	if not action_right.is_empty() and action_right != none_option and Input.is_action_pressed(action_right):
		x += 1.0
	if not action_left.is_empty() and action_left != none_option and Input.is_action_pressed(action_left):
		x -= 1.0
	if not action_down.is_empty() and action_down != none_option and Input.is_action_pressed(action_down):
		y += 1.0
	if not action_up.is_empty() and action_up != none_option and Input.is_action_pressed(action_up):
		y -= 1.0

	return Vector2(x, y)

func validate() -> Array[String]:
	var errors: Array[String] = []

	# 获取 "无" 选项的本地化文本
	var none_option = FuseLocalization.translate("FUSE_INPUT_ACTION_NONE")

	# 检查是否至少配置了一个动作（允许某些方向为 "None"/空字符串）
	if action_up.is_empty() and action_down.is_empty() and action_left.is_empty() and action_right.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_INPUT_ACTION_COMPOSITE_NO_ACTIONS"))
		return errors

	# 检查 InputMap 是否可用
	if not InputMap:
		errors.append(FuseLocalization.translate("FUSE_ERROR_INPUTMAP_NOT_AVAILABLE"))
		return errors

	# 检查每个配置的动作是否存在（跳过空字符串/"None"）
	var actions = [action_up, action_down, action_left, action_right]

	for action in actions:
		if not action.is_empty() and action != none_option:
			if not InputMap.has_action(action):
				errors.append(FuseLocalization.translate_format(
					"FUSE_ERROR_INPUT_ACTION_NOT_EXISTS",
					{"action": action}
				))
			else:
				var events = InputMap.action_get_events(action)
				if events.is_empty():
					errors.append(FuseLocalization.translate_format(
						"FUSE_ERROR_INPUT_ACTION_NO_EVENTS",
						{"action": action}
					))

	return errors

func _update_resource_name() -> void:
	if _is_updating_name:
		return
	_is_updating_name = true

	# 获取 "无" 选项的本地化文本
	var none_option = FuseLocalization.translate("FUSE_INPUT_ACTION_NONE")

	var parts = []
	if not action_up.is_empty() and action_up != none_option:
		parts.append(FuseLocalization.translate("FUSE_EVENT_INPUT_ACTION_COMPOSITE_UP"))
	if not action_down.is_empty() and action_down != none_option:
		parts.append(FuseLocalization.translate("FUSE_EVENT_INPUT_ACTION_COMPOSITE_DOWN"))
	if not action_left.is_empty() and action_left != none_option:
		parts.append(FuseLocalization.translate("FUSE_EVENT_INPUT_ACTION_COMPOSITE_LEFT"))
	if not action_right.is_empty() and action_right != none_option:
		parts.append(FuseLocalization.translate("FUSE_EVENT_INPUT_ACTION_COMPOSITE_RIGHT"))

	if parts.is_empty():
		resource_name = FuseLocalization.translate("FUSE_EVENT_ON_INPUT_ACTION_COMPOSITE_NAME")
	else:
		# 获取帧率文本
		var fps_text = ""
		match trigger_rate:
			TriggerRate.FPS_60:
				fps_text = "60 FPS"
			TriggerRate.FPS_30:
				fps_text = "30 FPS"
			TriggerRate.FPS_20:
				fps_text = "20 FPS"
			TriggerRate.FPS_10:
				fps_text = "10 FPS"

		resource_name = FuseLocalization.translate_format(
			"FUSE_EVENT_ON_INPUT_ACTION_COMPOSITE_DESC",
			{}
		) + " [" + ", ".join(parts) + "] (%s)" % fps_text

	_is_updating_name = false

func get_description() -> String:
	return FuseLocalization.translate("FUSE_EVENT_ON_INPUT_ACTION_COMPOSITE_DESC")

func get_event_type() -> String:
	return "input_action_composite"

func get_event_category() -> String:
	return "input"

func get_event_icon() -> Texture2D:
	return null

## 处理输入事件（虚函数，由 Trigger 的 _unhandled_input 调用）
func handle_input(event: InputEvent) -> void:
	# 复合输入事件使用 _process_inputs() 而不是 handle_input()
	# 这个方法保留用于兼容性，但不执行任何操作
	pass

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_ON_INPUT_ACTION_COMPOSITE_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_INPUT"
	metadata.description_key = "FUSE_EVENT_ON_INPUT_ACTION_COMPOSITE_DESC"
	metadata.keywords = ["action", "动作", "input", "输入", "composite", "复合", "movement", "移动"]
	metadata.builtin_icon = "InputEventAction"
	return metadata
