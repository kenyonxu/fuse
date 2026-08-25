@icon("res://addons/fuse/icons/builtin/InputEventAction.png")
# 文件：addons/fuse/events/on_input_action.gd
@tool
class_name OnInputAction extends BaseEvent

## Event: OnInputAction
##
## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - owner_node_ref: WeakRef - owner_node 的弱引用
##
## 架构版本: 自声明状态模式 v2.0
## 相关文档: addons/fuse/docs/migration-guide-to-runtime-instance.md

## 触发模式选项
enum TriggerMode {
	JUST_PRESSED,    # 刚按下
	JUST_RELEASED,   # 刚释放
	HOLD,            # 持续按下
	PRESSED_OR_RELEASED  # 按下或释放
}

## 目标 Input Action
## 我们不使用 @export，因为我们将通过 _get_property_list() 来定义它
var target_input_action: String = "":
	set(value):
		target_input_action = value
		if Engine.is_editor_hint():
			_update_resource_name()

## 触发模式
var trigger_mode: TriggerMode = TriggerMode.JUST_PRESSED:
	set(value):
		trigger_mode = value
		_update_resource_name()

# 防止 _update_resource_name() 递归调用
var _is_updating_name: bool = false

# 缓存 Input Actions 列表（静态变量，所有实例共享）
static var _cached_input_actions: Array[String] = []
static var _input_actions_cached: bool = false

# 缓存 Trigger Mode 本地化字符串
static var _cached_trigger_modes: Array[String] = []
static var _trigger_modes_cached: bool = false

# --- 核心实现：动态下拉菜单 ---

## 初始化 Input Actions 缓存
##
## 这个方法会在编辑器中安全地从 ProjectSettings 加载 InputMap 数据
static func _init_input_actions_cache() -> void:
	if _input_actions_cached:
		return

	# 从 ProjectSettings 获取所有属性
	var property_list = ProjectSettings.get_property_list()

	for prop in property_list:
		if prop.has("name"):
			var prop_name = String(prop.name)
			# 输入映射的格式是 "input/action_name"
			if prop_name.begins_with("input/"):
				var action_name = prop_name.substr(6)  # 移除 "input/" 前缀
				# 过滤掉内置的 ui_* 和 spatial_ actions
				if not action_name.begins_with("ui_") and not action_name.begins_with("spatial_"):
					# 避免重复添加
					if action_name not in _cached_input_actions:
						_cached_input_actions.append(action_name)

	# 排序以便查看
	_cached_input_actions.sort()

	_input_actions_cached = true
	print("OnInputAction: Cached %d input actions: %s" % [_cached_input_actions.size(), _cached_input_actions])


## 初始化 Trigger Mode 本地化缓存
##
## 这个方法会缓存 Trigger Mode 的本地化字符串，避免在 _get_property_list() 中频繁调用翻译函数
static func _init_trigger_modes_cache() -> void:
	if _trigger_modes_cached:
		return

	_cached_trigger_modes = [
		FuseLocalization.translate("FUSE_TRIGGER_MODE_JUST_PRESSED"),
		FuseLocalization.translate("FUSE_TRIGGER_MODE_JUST_RELEASED"),
		FuseLocalization.translate("FUSE_TRIGGER_MODE_HOLD"),
		FuseLocalization.translate("FUSE_TRIGGER_MODE_PRESSED_OR_RELEASED")
	]

	_trigger_modes_cached = true


## 刷新 Input Actions 缓存
##
## 当项目设置中的 Input Actions 发生变化时，可以调用此方法刷新缓存
static func refresh_input_actions_cache() -> void:
	_cached_input_actions.clear()
	_input_actions_cached = false
	_init_input_actions_cache()
	print("OnInputAction: Refreshed input actions cache")

func _get_property_list() -> Array[Dictionary]:
	# Resource 类没有 _get_property_list() 方法，所以我们直接创建属性列表
	var properties: Array[Dictionary] = []

	# 初始化缓存（如果还没有初始化）
	_init_input_actions_cache()
	_init_trigger_modes_cache()

	# 使用缓存的 Input Actions
	var hint_string: String = ",".join(_cached_input_actions)

	# 添加目标输入动作属性
	properties.append({
		"name": "target_input_action",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": hint_string
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

# 因为我们没有使用 @export，所以需要提供 _get 和 _set

func _get(property: StringName):
	if property == "target_input_action":
		return target_input_action
	elif property == "trigger_mode":
		return trigger_mode
	return null

func _set(property: StringName, value) -> bool:
	if property == "target_input_action":
		target_input_action = value
		if Engine.is_editor_hint():
			_update_resource_name()
		return true
	elif property == "trigger_mode":
		if value is int:
			trigger_mode = value
		else:
			trigger_mode = int(value)
		if Engine.is_editor_hint():
			_update_resource_name()
		return true
	return false


# --- BaseEvent 接口实现 ---

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["owner_node_ref"] = null
	return base

## 使用 RuntimeInstance 初始化事件
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		return

	# 保存 RuntimeEventInstance 引用
	_runtime_instance_ref = runtime_instance

	# 验证参数
	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		push_error("[Fuse] Owner node is null for OnInputAction")
		return

	# 存储 owner_node 的弱引用到 RuntimeInstance 状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("owner_node_ref", weakref(owner_node))

	# 如果目标动作为空，记录警告
	if target_input_action.is_empty():
		_log_warning_localized("FUSE_ERROR_MISSING_PARAMETER", {"parameter": "target_input_action"})

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

func terminate(owner_node: Node) -> void:
	if Engine.is_editor_hint():
		return

	# 清理 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("owner_node_ref", null)
		_runtime_instance_ref = null

	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 重置事件状态
func reset() -> void:
	super.reset()
	# 重置 RuntimeInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("owner_node_ref", null)
	_log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})

func validate() -> Array[String]:
	var errors: Array[String] = []

	if target_input_action.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_INPUT_ACTION_NOT_SET"))
		return errors

	# 检查 InputMap 是否可用
	if not InputMap:
		errors.append(FuseLocalization.translate("FUSE_ERROR_INPUTMAP_NOT_AVAILABLE"))
		return errors

	# 检查 action 是否存在
	if not InputMap.has_action(target_input_action):
		errors.append(FuseLocalization.translate_format("FUSE_ERROR_INPUT_ACTION_NOT_EXISTS", {"action": target_input_action}))
		return errors

	# 检查 action 是否有绑定的事件
	var events = InputMap.action_get_events(target_input_action)
	if events.is_empty():
		errors.append(FuseLocalization.translate_format("FUSE_ERROR_INPUT_ACTION_NO_EVENTS", {"action": target_input_action}))

	return errors

func _update_resource_name() -> void:
	# 防止递归调用
	if _is_updating_name:
		return
	_is_updating_name = true

	var display_name = FuseLocalization.translate("FUSE_EVENT_INPUT_ACTION_NOT_SET")

	if not target_input_action.is_empty():
		display_name = target_input_action

		# 添加事件数量信息
		if InputMap and InputMap.has_action(target_input_action):
			var events = InputMap.action_get_events(target_input_action)
			if not events.is_empty():
				display_name = FuseLocalization.translate_format(
					"FUSE_EVENT_INPUT_ACTION_WITH_COUNT",
					{"action": target_input_action, "count": str(events.size())}
				)
			else:
				display_name = FuseLocalization.translate_format(
					"FUSE_EVENT_INPUT_ACTION_RESOURCE_NAME",
					{"action": target_input_action}
				)

	var mode_key = ""
	match trigger_mode:
		TriggerMode.JUST_PRESSED:
			mode_key = "FUSE_TRIGGER_MODE_JUST_PRESSED"
		TriggerMode.JUST_RELEASED:
			mode_key = "FUSE_TRIGGER_MODE_JUST_RELEASED"
		TriggerMode.HOLD:
			mode_key = "FUSE_TRIGGER_MODE_HOLD"
		TriggerMode.PRESSED_OR_RELEASED:
			mode_key = "FUSE_TRIGGER_MODE_PRESSED_OR_RELEASED"

	var mode_desc = FuseLocalization.translate(mode_key)

	resource_name = FuseLocalization.translate_format(
		"FUSE_EVENT_INPUT_ACTION_RESOURCE_NAME",
		{"action": display_name + " [" + mode_desc + "]"}
	)

	_is_updating_name = false

func get_description() -> String:
	var mode_key = ""
	match trigger_mode:
		TriggerMode.JUST_PRESSED:
			mode_key = "FUSE_TRIGGER_MODE_JUST_PRESSED"
		TriggerMode.JUST_RELEASED:
			mode_key = "FUSE_TRIGGER_MODE_JUST_RELEASED"
		TriggerMode.HOLD:
			mode_key = "FUSE_TRIGGER_MODE_HOLD"
		TriggerMode.PRESSED_OR_RELEASED:
			mode_key = "FUSE_TRIGGER_MODE_PRESSED_OR_RELEASED"

	var mode_desc = FuseLocalization.translate(mode_key)
	var action = target_input_action if not target_input_action.is_empty() else FuseLocalization.translate("FUSE_EVENT_INPUT_ACTION_NOT_SET")

	return FuseLocalization.translate_format(
		"FUSE_EVENT_ON_INPUT_ACTION_DESC_WHEN",
		{"action": action, "mode": mode_desc}
	)

func get_event_type() -> String:
	return "input_action"

func get_event_category() -> String:
	return "input"

func get_event_icon() -> Texture2D:
	# 简化图标处理，避免依赖 EditorNode
	return null

# --- 运行时逻辑 ---

## 处理输入事件
## 这个方法由 Trigger 的 _unhandled_input 虚函数调用
func handle_input(event: InputEvent) -> void:
	if target_input_action.is_empty():
		return

	# 使用 is_action 方法检查是否是目标动作的事件
	if not event.is_action(target_input_action):
		return

	var should_trigger = false
	match trigger_mode:
		TriggerMode.JUST_PRESSED:
			should_trigger = Input.is_action_just_pressed(target_input_action)
		TriggerMode.JUST_RELEASED:
			should_trigger = Input.is_action_just_released(target_input_action)
		TriggerMode.HOLD:
			should_trigger = Input.is_action_pressed(target_input_action)
		TriggerMode.PRESSED_OR_RELEASED:
			should_trigger = Input.is_action_just_pressed(target_input_action) or Input.is_action_just_released(target_input_action)

	if should_trigger:
		# 从 RuntimeInstance 获取 owner_node 引用
		var owner_node: Node = null
		if _runtime_instance_ref:
			var owner_ref = _runtime_instance_ref.get_runtime_state("owner_node_ref")
			if owner_ref and owner_ref.get_ref():
				owner_node = owner_ref.get_ref()

		_log_info_localized("FUSE_LOG_EVENT_INPUT_ACTION_TRIGGERED", {"action": target_input_action, "mode": TriggerMode.keys()[trigger_mode]})
		# 'context' 可以是 owner_node，或 null
		triggered.emit(owner_node)

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_ON_INPUT_ACTION_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_INPUT"
	metadata.description_key = "FUSE_EVENT_ON_INPUT_ACTION_DESC"
	metadata.keywords = ["action", "动作", "input", "输入", "inputmap", "输入映射", "trigger", "触发"]
	metadata.builtin_icon = "InputEventAction"
	return metadata
