@tool
@icon("res://addons/fuse/icons/builtin/LineEdit.png")
extends BaseEvent
class_name OnTextChanged

## Event: OnTextChanged
##
## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - _last_text: String - 上一次的文本内容
##
## 架构版本: 自声明状态模式 v2.0
## 相关文档: addons/fuse/docs/migration-guide-to-runtime-instance.md
##
## LineEdit/TextEdit 文本改变事件
##
## 监听 LineEdit 或 TextEdit 的文本改变事件，支持多种触发模式

## 触发模式
enum TriggerMode {
	ON_CHANGE,          ## 文本改变时触发
	ON_EMPTY,           ## 文本为空时触发
	ON_MAX_LENGTH,      ## 达到最大长度时触发
	ON_PATTERN_MATCH    ## 匹配正则表达式模式时触发
}

## 目标节点路径
@export var target_node_path: NodePath = NodePath(""):
	set(value):
		target_node_path = value
		_update_resource_name()

## 触发模式
@export var trigger_mode: TriggerMode = TriggerMode.ON_CHANGE:
	set(value):
		trigger_mode = value
		_update_resource_name()

## 正则表达式模式（用于 ON_PATTERN_MATCH 模式）
@export var pattern: String = "":
	set(value):
		pattern = value
		_update_resource_name()

## 最小长度（用于验证）
@export var min_length: int = 0:
	set(value):
		min_length = value
		_update_resource_name()

## 最大长度（用于 ON_MAX_LENGTH 模式）
@export var max_length: int = 100:
	set(value):
		max_length = value
		_update_resource_name()

## 是否发出新文本
@export var emit_new_text: bool = true

## 是否发出旧文本
@export var emit_old_text: bool = true

## 是否发出文本长度
@export var emit_length: bool = true

## 是否发出是否匹配模式标志
@export var emit_pattern_matched: bool = true

var _target_node_ref: Node = null
var _regex: RegEx = null

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["last_text"] = ""
	return base

## 更新资源名称（必需）
func _update_resource_name():
	var mode_key = ""
	match trigger_mode:
		TriggerMode.ON_CHANGE:
			mode_key = "FUSE_DESC_TEXT_CHANGE"
		TriggerMode.ON_EMPTY:
			mode_key = "FUSE_DESC_TEXT_EMPTY"
		TriggerMode.ON_MAX_LENGTH:
			mode_key = "FUSE_DESC_TEXT_MAX_LENGTH"
		TriggerMode.ON_PATTERN_MATCH:
			mode_key = "FUSE_DESC_TEXT_PATTERN_MATCH"

	var mode_text = FuseLocalization.translate(mode_key)
	if trigger_mode == TriggerMode.ON_MAX_LENGTH:
		mode_text = FuseLocalization.translate_format(mode_key, {"max": max_length})
	elif trigger_mode == TriggerMode.ON_PATTERN_MATCH:
		var pattern_text = pattern if not pattern.is_empty() else FuseLocalization.translate("FUSE_TEXT_NOT_SET")
		mode_text = FuseLocalization.translate_format(mode_key, {"pattern": pattern_text})

	resource_name = FuseLocalization.translate_format("FUSE_EVENT_ON_TEXT_CHANGED_RESOURCE_NAME", {
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

	# 验证节点类型
	if not _is_valid_target():
		_create_fuse_error_localized("FUSE_ERROR_INVALID_TARGET", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(target_node_path)})
		return

	# 编译正则表达式（如果需要）
	if trigger_mode == TriggerMode.ON_PATTERN_MATCH:
		if not pattern.is_empty():
			_regex = RegEx.new()
			var error = _regex.compile(pattern)
			if error != OK:
				_create_fuse_error_localized("FUSE_ERROR_INVALID_REGEX_PATTERN", FuseError.ErrorType.CONFIGURATION_ERROR, {"pattern": pattern})
				return

	# 获取初始文本
	var last_text = _get_current_text()
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("last_text", last_text)

	# 连接信号
	_connect_text_changed_signal()

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

	# 验证节点类型
	if not _is_valid_target():
		_create_fuse_error_localized("FUSE_ERROR_INVALID_TARGET", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(target_node_path)})
		return

	# 编译正则表达式（如果需要）
	if trigger_mode == TriggerMode.ON_PATTERN_MATCH:
		if not pattern.is_empty():
			_regex = RegEx.new()
			var error = _regex.compile(pattern)
			if error != OK:
				_create_fuse_error_localized("FUSE_ERROR_INVALID_REGEX_PATTERN", FuseError.ErrorType.CONFIGURATION_ERROR, {"pattern": pattern})
				return

	# 连接信号
	_connect_text_changed_signal()

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	# 清理 RuntimeEventInstance 状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("last_text", "")

	# 断开信号连接
	if _target_node_ref and is_instance_valid(_target_node_ref):
		_disconnect_text_changed_signal()

	# 清理引用
	_target_node_ref = null
	_regex = null

	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 连接文本改变信号
func _connect_text_changed_signal():
	if not _target_node_ref or not is_instance_valid(_target_node_ref):
		return

	# LineEdit 和 TextEdit 都有 text_changed 信号
	if _target_node_ref.has_signal("text_changed"):
		if not _target_node_ref.text_changed.is_connected(_on_text_changed):
			_target_node_ref.text_changed.connect(_on_text_changed)

## 断开文本改变信号
func _disconnect_text_changed_signal():
	if not _target_node_ref or not is_instance_valid(_target_node_ref):
		return

	if _target_node_ref.has_signal("text_changed"):
		if _target_node_ref.text_changed.is_connected(_on_text_changed):
			_target_node_ref.text_changed.disconnect(_on_text_changed)

## 文本改变回调
func _on_text_changed(new_text: String):
	var last_text = ""
	if _runtime_instance_ref and _runtime_instance_ref.has_runtime_state("last_text"):
		last_text = _runtime_instance_ref.get_runtime_state("last_text")

	var old_text = last_text
	var text_length = new_text.length()
	var pattern_matched = _check_pattern_match(new_text)

	var should_trigger = false

	match trigger_mode:
		TriggerMode.ON_CHANGE:
			should_trigger = new_text != old_text

		TriggerMode.ON_EMPTY:
			should_trigger = new_text.is_empty() and not old_text.is_empty()

		TriggerMode.ON_MAX_LENGTH:
			should_trigger = text_length >= max_length and old_text.length() < max_length

		TriggerMode.ON_PATTERN_MATCH:
			should_trigger = pattern_matched

	if should_trigger:
		if _runtime_instance_ref:
			_runtime_instance_ref.set_runtime_state("last_text", new_text)

		var mode_name = _get_trigger_mode_name()
		var length_text = "，长度: %d" % text_length if emit_length else ""
		var pattern_text = ""
		if trigger_mode == TriggerMode.ON_PATTERN_MATCH:
			pattern_text = "，匹配: %s" % ("是" if pattern_matched else "否")

		_log_info_localized("FUSE_LOG_EVENT_TEXT_CHANGED", {
			"new_text": new_text,
			"old_text": old_text,
			"length": str(text_length),
			"mode": mode_name,
			"length_text": length_text,
			"pattern_text": pattern_text
		})

		# 创建上下文节点传递文本信息
		var context_node = Node.new()
		context_node.name = "TextChangedContext"

		if emit_new_text:
			context_node.set_meta("new_text", new_text)

		if emit_old_text:
			context_node.set_meta("old_text", old_text)

		if emit_length:
			context_node.set_meta("text_length", text_length)

		if emit_pattern_matched:
			context_node.set_meta("pattern_matched", pattern_matched)

		context_node.set_meta("target_node", _target_node_ref)
		context_node.set_meta("trigger_mode", TriggerMode.keys()[trigger_mode])

		triggered.emit(context_node)

		# 清理上下文节点
		context_node.queue_free()

## 获取当前文本
func _get_current_text() -> String:
	if not _target_node_ref or not is_instance_valid(_target_node_ref):
		return ""

	# 从 LineEdit 或 TextEdit 获取文本
	if _target_node_ref.has_method("get_text"):
		return _target_node_ref.call("get_text")

	if _target_node_ref.has_property("text"):
		return _target_node_ref.get("text")

	return ""

## 检查是否匹配模式
func _check_pattern_match(text: String) -> bool:
	if not _regex:
		return false

	var result = _regex.search(text)
	return result != null

## 验证是否是有效的目标节点
func _is_valid_target() -> bool:
	if not _target_node_ref:
		return false

	# 支持的类型：LineEdit, TextEdit
	return (_target_node_ref is LineEdit or
			_target_node_ref is TextEdit)

## 获取触发模式名称
func _get_trigger_mode_name() -> String:
	match trigger_mode:
		TriggerMode.ON_CHANGE:
			return FuseLocalization.translate("FUSE_DESC_TEXT_CHANGE")
		TriggerMode.ON_EMPTY:
			return FuseLocalization.translate("FUSE_DESC_TEXT_EMPTY")
		TriggerMode.ON_MAX_LENGTH:
			return FuseLocalization.translate("FUSE_DESC_TEXT_MAX_LENGTH")
		TriggerMode.ON_PATTERN_MATCH:
			return FuseLocalization.translate("FUSE_DESC_TEXT_PATTERN_MATCH")
		_:
			return FuseLocalization.translate("FUSE_TEXT_UNKNOWN")

## 获取事件描述
func get_description() -> String:
	var node_name = target_node_path if not target_node_path.is_empty() else FuseLocalization.translate("FUSE_TEXT_NOT_SPECIFIED")
	var mode_key = ""
	match trigger_mode:
		TriggerMode.ON_CHANGE:
			mode_key = "FUSE_DESC_TEXT_CHANGE"
		TriggerMode.ON_EMPTY:
			mode_key = "FUSE_DESC_TEXT_EMPTY"
		TriggerMode.ON_MAX_LENGTH:
			mode_key = "FUSE_DESC_TEXT_MAX_LENGTH"
		TriggerMode.ON_PATTERN_MATCH:
			mode_key = "FUSE_DESC_TEXT_PATTERN_MATCH"

	var mode_text = FuseLocalization.translate(mode_key)

	var detail_text = ""
	if trigger_mode == TriggerMode.ON_MAX_LENGTH:
		detail_text = FuseLocalization.translate_format("FUSE_DESC_MAX_LENGTH_DETAIL", {"max": max_length})
	elif trigger_mode == TriggerMode.ON_PATTERN_MATCH:
		var pattern_text = pattern if not pattern.is_empty() else FuseLocalization.translate("FUSE_TEXT_NOT_SET")
		detail_text = FuseLocalization.translate_format("FUSE_DESC_PATTERN_DETAIL", {"pattern": pattern_text})

	return FuseLocalization.translate_format("FUSE_EVENT_ON_TEXT_CHANGED_DESC", {
		"node": node_name,
		"mode": mode_text,
		"detail": detail_text
	})

## 获取事件类型
func get_event_type() -> String:
	return "text_changed"

## 获取事件分类
func get_event_category() -> String:
	return "ui"

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	if target_node_path.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))

	if trigger_mode == TriggerMode.ON_PATTERN_MATCH and pattern.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_REGEX_PATTERN_EMPTY"))

	if max_length < 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_MAX_LENGTH_INVALID"))

	if min_length < 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_MIN_LENGTH_INVALID"))

	if min_length > max_length:
		errors.append(FuseLocalization.translate("FUSE_ERROR_MIN_LENGTH_GREATER_THAN_MAX"))

	return errors

## 重置事件状态
func reset() -> void:
	super.reset()
	var last_text = _get_current_text()
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("last_text", last_text)
	_log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_ON_TEXT_CHANGED_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_UI"
	metadata.description_key = "FUSE_EVENT_ON_TEXT_CHANGED_DESC"
	metadata.keywords = ["text", "文本", "changed", "改变", "lineedit", "textedit", "input", "输入", "ui", "control"]
	metadata.builtin_icon = "LineEdit"
	return metadata
