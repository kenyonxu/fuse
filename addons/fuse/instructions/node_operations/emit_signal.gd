@tool
@icon("res://addons/fuse/icons/builtin/Signal.svg")
extends BaseInstruction
class_name EmitSignal

## Emit Signal 指令 - 在目标节点上发射自定义信号

## 目标节点路径（空=当前执行上下文的目标节点）
var target_node: NodePath = NodePath(""):
	set(value):
		target_node = value
		_update_resource_name()

## 信号名
var signal_name: String = "":
	set(value):
		signal_name = value
		_update_resource_name()

## 信号参数
var signal_args: Array = []:
	set(value):
		signal_args = value
		_update_resource_name()

## 获取指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_EMIT_SIGNAL_NAME"
	metadata.category_key = "FUSE_CATEGORY_NODE_OPERATIONS"
	metadata.description_key = "FUSE_INSTRUCTION_EMIT_SIGNAL_DESC"
	metadata.keywords = ["信号", "signal", "发射", "emit", "事件", "event", "通知", "notify"]
	metadata.builtin_icon = "Signal"
	return metadata

func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	properties.append({
		name = "Emit Signal",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "target_node",
		type = TYPE_NODE_PATH,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "signal_name",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# signal_args 在 Inspector 中不直接编辑，通过 Array 编辑器处理
	# 这里用 TYPE_NIL 避免 inspector 中显示错误
	properties.append({
		name = "signal_args",
		type = TYPE_ARRAY,
		hint = PROPERTY_HINT_TYPE_STRING,
		hint_string = "Variant",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 更新资源名称
func _update_resource_name():
	var parts = []
	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_EMIT_SIGNAL_NAME"))

	if not signal_name.is_empty():
		parts.append("'%s'" % signal_name)

	if not target_node.is_empty():
		parts.append("[%s]" % _get_node_display_name(target_node))

	resource_name = " ".join(parts)

## 获取指令描述
func get_description() -> String:
	var target_desc = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_COMMON_CURRENT_NODE")
	var sig = signal_name if not signal_name.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_EMIT_SIGNAL_DESC_FORMAT", {
		"signal": sig,
		"target": target_desc
	})

## 执行指令
func execute(context: ExecutionContext) -> void:
	_start_execution(context)

	if signal_name.is_empty():
		_log_error_localized("FUSE_ERROR_SIGNAL_NAME_EMPTY", {})
		set_error_localized("FUSE_ERROR_SIGNAL_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	var node: Node
	if target_node.is_empty():
		node = context.target
	else:
		node = context.get_node(target_node)

	if node == null:
		_log_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(target_node)})
		set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"node": str(target_node)})
		finished.emit()
		return

	# 检查信号是否存在
	if not node.has_signal(signal_name):
		_log_error_localized("FUSE_ERROR_SIGNAL_NOT_FOUND", {"signal": signal_name, "node": node.name})
		set_error_localized("FUSE_ERROR_SIGNAL_NOT_FOUND", FuseError.ErrorType.VALIDATION_ERROR, {"signal": signal_name, "node": node.name})
		finished.emit()
		return

	# 发射信号
	var args: Array = [signal_name]
	args.append_array(signal_args)
	node.callv(&"emit_signal", args)

	_log_info_localized("FUSE_LOG_SIGNAL_EMITTED", {
		"signal": signal_name,
		"node": node.name
	})

	_on_execution_completed()

## 验证参数
func validate() -> Array[String]:
	var errors = super.validate()
	if signal_name.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_SIGNAL_NAME_EMPTY"))
	return errors
