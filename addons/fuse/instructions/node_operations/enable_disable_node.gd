@tool
@icon("res://addons/fuse/icons/builtin/GuiVisibilityXray.png")
extends BaseInstruction
class_name EnableDisableNode

## 启用或禁用节点

# 控制模式
enum ControlMode {
	PROCESSING,  # 控制处理模式
	VISIBLE      # 控制可见性
}

# 目标节点路径
var target_node: NodePath = NodePath("")

# 是否启用
var enable: bool = true

# 控制模式
var mode: ControlMode = ControlMode.PROCESSING

## 获取指令元数据（用于指令选择器）
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_ENABLE_DISABLE_NODE_NAME"
	metadata.category_key = "FUSE_CATEGORY_NODE_OPERATIONS"
	metadata.description_key = "FUSE_INSTRUCTION_ENABLE_DISABLE_NODE_DESC"
	metadata.keywords = ["enable", "disable", "visible", "processing", "启用", "禁用", "可见", "处理"]
	# 设置指令选择器图标
	metadata.builtin_icon = "GuiVisibilityXray"
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties := []

	# Node Operation 分类
	properties.append({
		name = "Node Operation",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 目标节点
	properties.append({
		name = "target_node",
		type = TYPE_NODE_PATH,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 是否启用
	properties.append({
		name = "enable",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 控制模式
	properties.append({
		name = "mode",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Processing,Visible",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 更新资源名称
func _update_resource_name():
	var parts = []

	var action_key = "FUSE_INSTRUCTION_ENABLE_DISABLE_NODE_ENABLE" if enable else "FUSE_INSTRUCTION_ENABLE_DISABLE_NODE_DISABLE"
	parts.append(FuseLocalization.translate(action_key))
	parts.append(_get_mode_string())

	if not target_node.is_empty():
		parts.append("'%s'" % target_node)
	else:
		parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_ENABLE_DISABLE_NODE_NO_NODE"))

	resource_name = " ".join(parts)

## 获取模式字符串
func _get_mode_string() -> String:
	match mode:
		ControlMode.PROCESSING:
			return FuseLocalization.translate("FUSE_INSTRUCTION_ENABLE_DISABLE_NODE_PROCESSING_MODE")
		ControlMode.VISIBLE:
			return FuseLocalization.translate("FUSE_INSTRUCTION_ENABLE_DISABLE_NODE_VISIBILITY")
		_:
			return FuseLocalization.translate("FUSE_INSTRUCTION_ENABLE_DISABLE_NODE_UNKNOWN")

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	# 验证目标节点
	if target_node.is_empty():
		_log_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", {})
		set_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 获取目标节点
	var node := context.get_node(target_node)
	if not node:
		_log_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(target_node)})
		set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"node": str(target_node)})
		finished.emit()
		return

	match mode:
		ControlMode.PROCESSING:
			_set_processing_mode(node, enable)
		ControlMode.VISIBLE:
			_set_visible(node, enable)

	var action_key = "FUSE_LOG_NODE_ENABLED" if enable else "FUSE_LOG_NODE_DISABLED"
	_log_info_localized(action_key, {"node": node.name})

	_on_execution_completed()

## 设置处理模式
func _set_processing_mode(node: Node, enabled: bool) -> void:
	if enabled:
		node.process_mode = Node.PROCESS_MODE_INHERIT
	else:
		node.process_mode = Node.PROCESS_MODE_DISABLED

## 设置可见性
func _set_visible(node: Node, visible: bool) -> void:
	if node is CanvasItem:
		node.visible = visible
	else:
		_log_error_localized("FUSE_ERROR_NODE_NOT_CANVAS_ITEM", {
			"node_name": node.name
		})
		set_error_localized("FUSE_ERROR_NODE_NOT_CANVAS_ITEM", FuseError.ErrorType.RUNTIME_ERROR, {
			"node_name": node.name
		})

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()

	if target_node.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_PATH_EMPTY"))

	return errors

## 获取指令描述
func get_description() -> String:
	var action_key = "FUSE_INSTRUCTION_ENABLE_DISABLE_NODE_ENABLE" if enable else "FUSE_INSTRUCTION_ENABLE_DISABLE_NODE_DISABLE"
	var mode_str = _get_mode_string()
	var action_str = FuseLocalization.translate(action_key)
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_ENABLE_DISABLE_NODE_DESC_FORMAT", {
		"action": action_str,
		"node": _get_node_display_name(target_node),
		"mode": mode_str
	})
