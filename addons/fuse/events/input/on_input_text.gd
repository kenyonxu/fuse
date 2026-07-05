@tool
@icon("res://addons/fuse/icons/builtin/TextEdit.png")
extends BaseEvent
class_name OnInputText

## Event: OnInputText
##
## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - _is_monitoring: bool - 是否正在监听输入
## - _current_length: int - 当前输入长度计数
##
## 架构版本: 自声明状态模式 v2.0
## 相关文档: addons/fuse/docs/migration-guide-to-runtime-instance.md

## 文本输入事件
##
## 监听文本输入事件。处理 InputEventText，过滤特定字符，限制输入长度。

## 字符过滤器（正则表达式）
@export var filter_characters: String = "":
	set(value):
		filter_characters = value
		_update_resource_name()

## 最大长度（0 = 无限制）
@export var max_length: int = 0:
	set(value):
		max_length = value
		_update_resource_name()

## 是否传递输入的文本
@export var emit_text: bool = true

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["is_monitoring"] = false
	base["current_length"] = 0
	return base

## 更新资源名称（必需）
func _update_resource_name() -> void:
	var filter_text = filter_characters if not filter_characters.is_empty() else FuseLocalization.translate("FUSE_TEXT_INPUT_NO_FILTER")
	var length_key = "FUSE_TEXT_INPUT_MAX_LENGTH" if max_length > 0 else "FUSE_TEXT_INPUT_UNLIMITED"
	var length_text = FuseLocalization.translate_format(length_key, {"max": str(max_length)}) if max_length > 0 else FuseLocalization.translate(length_key)

	resource_name = FuseLocalization.translate_format("FUSE_EVENT_ON_INPUT_TEXT_RESOURCE_NAME", {
		"filter": filter_text,
		"length": length_text
	})

## 使用 RuntimeInstance 初始化事件
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		return

	_runtime_instance_ref = runtime_instance

	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 设置初始状态
	_runtime_instance_ref.set_runtime_state("is_monitoring", true)
	_runtime_instance_ref.set_runtime_state("current_length", 0)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 初始化事件监听（必需）
func initialize(owner_node: Node) -> void:
	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 设置初始状态（通过 RuntimeInstance）
	get_runtime_instance().set_runtime_state("is_monitoring", true)
	get_runtime_instance().set_runtime_state("current_length", 0)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	# 清理 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("is_monitoring", false)
		_runtime_instance_ref.set_runtime_state("current_length", 0)
	_runtime_instance_ref = null

	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 输入处理
func _input(event: InputEvent) -> void:
	var is_monitoring: bool = false
	if _runtime_instance_ref and _runtime_instance_ref.has_runtime_state("is_monitoring"):
		is_monitoring = _runtime_instance_ref.get_runtime_state("is_monitoring")

	if not is_monitoring:
		return

	if event is InputEvent:
		_handle_text_input(event)

## 处理文本输入
func _handle_text_input(event: InputEvent) -> void:
	var text = event.text

	# 检查是否为空
	if text.is_empty():
		return

	# 应用字符过滤器
	if not filter_characters.is_empty():
		var regex = RegEx.new()
		var error = regex.compile(filter_characters)
		if error != OK:
			# 正则表达式编译失败，记录警告但不阻止输入
			push_warning("Invalid regex pattern: %s" % filter_characters)
		else:
			var result = regex.search(text)
			if not result:
				return  # 不匹配过滤器，不触发

	# 检查长度限制
	var current_length: int = 0
	if _runtime_instance_ref and _runtime_instance_ref.has_runtime_state("current_length"):
		current_length = _runtime_instance_ref.get_runtime_state("current_length")

	if max_length > 0 and current_length >= max_length:
		return  # 超过最大长度，不触发

	# 更新长度计数
	if max_length > 0:
		var new_length = current_length + text.length()
		if _runtime_instance_ref:
			_runtime_instance_ref.set_runtime_state("current_length", new_length)

	# 触发事件
	_trigger_event(text)

## 触发事件
func _trigger_event(text: String) -> void:
	_log_info_localized("FUSE_LOG_EVENT_INPUT_TEXT_TRIGGERED", {"text": text})

	# 创建上下文节点
	var context_node = Node.new()
	context_node.name = "InputTextContext"

	# 传递文本
	if emit_text:
		context_node.set_meta("text", text)

	triggered.emit(context_node)

	# 清理上下文节点
	context_node.queue_free()

## 重置长度计数
func reset() -> void:
	super.reset()
	# 重置 RuntimeInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("current_length", 0)
		_runtime_instance_ref.set_runtime_state("is_monitoring", false)
	_log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})

## 获取事件描述
func get_description() -> String:
	var parts = []
	parts.append(FuseLocalization.translate("FUSE_EVENT_INPUT_TEXT_MONITOR"))

	if not filter_characters.is_empty():
		parts.append(FuseLocalization.translate_format("FUSE_EVENT_INPUT_TEXT_FILTER", {"filter": filter_characters}))

	if max_length > 0:
		parts.append(FuseLocalization.translate_format("FUSE_EVENT_INPUT_TEXT_MAX_LENGTH", {"max": str(max_length)}))

	return ", ".join(parts)

## 获取事件类型
func get_event_type() -> String:
	return "input_text"

## 获取事件分类
func get_event_category() -> String:
	return "input"

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	if max_length < 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_MAX_LENGTH_NEGATIVE"))

	return errors

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_ON_INPUT_TEXT_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_INPUT"
	metadata.description_key = "FUSE_EVENT_ON_INPUT_TEXT_DESC"
	metadata.keywords = ["text", "文本", "input", "输入", "typing", "打字", "keyboard", "键盘"]
	metadata.builtin_icon = "TextEdit"
	return metadata
