@tool
@icon("res://addons/fuse/icons/builtin/Node.png")
extends BaseInstruction
class_name SetProcessMode

## 设置节点的 process_mode 属性，控制节点的处理行为

# =============================================
# 属性定义
# =============================================

## 目标节点
var target_node: NodePath = NodePath(""):
	set(value):
		target_node = value
		_update_resource_name()

## 处理模式
var process_mode: int = 0:  # Node.PROCESS_MODE_INHERIT
	set(value):
		process_mode = value
		_update_resource_name()

# =============================================
# 元数据（必需）
# =============================================
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_SET_PROCESS_MODE_NAME"
	metadata.category_key = "FUSE_CATEGORY_NODE_OPERATIONS"
	metadata.description_key = "FUSE_INSTRUCTION_SET_PROCESS_MODE_DESC"
	metadata.keywords = ["处理模式", "process", "mode", "process_mode", "节点", "node", "继承", "暂停", "禁用"]
	metadata.builtin_icon = "Node"
	return metadata

func _setup_metadata():
	pass

# =============================================
# 动态属性列表
# =============================================
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	# Target 分类
	properties.append({
		name = "Target",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "target_node",
		type = TYPE_NODE_PATH,
		hint = PROPERTY_HINT_NODE_PATH_VALID_TYPES,
		hint_string = "Node",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Settings 分类
	properties.append({
		name = "Settings",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "process_mode",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Inherit,Pausable,When Paused,Always,Disabled",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

# =============================================
# 资源名称
# =============================================
func _update_resource_name():
	var target_str = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")
	var mode_str = _get_mode_name()
	resource_name = FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_PROCESS_MODE_RESOURCE_NAME", {
		"target": target_str,
		"mode": mode_str
	})

func _get_mode_name() -> String:
	match process_mode:
		0: return FuseLocalization.translate("FUSE_ENUM_PROCESS_MODE_INHERIT")
		1: return FuseLocalization.translate("FUSE_ENUM_PROCESS_MODE_PAUSABLE")
		2: return FuseLocalization.translate("FUSE_ENUM_PROCESS_MODE_WHEN_PAUSED")
		3: return FuseLocalization.translate("FUSE_ENUM_PROCESS_MODE_ALWAYS")
		4: return FuseLocalization.translate("FUSE_ENUM_PROCESS_MODE_DISABLED")
		_: return str(process_mode)

# =============================================
# 执行
# =============================================
func execute(context: ExecutionContext):
	_start_execution(context)

	if target_node.is_empty():
		set_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	var node := context.get_node(target_node)
	if not node:
		set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"node": str(target_node)})
		finished.emit()
		return

	node.process_mode = process_mode as Node.ProcessMode

	_log_info_localized("FUSE_LOG_PROCESS_MODE_SET", {
		"node": node.name,
		"mode": _get_mode_name()
	})
	_on_execution_completed()

# =============================================
# 描述
# =============================================
func get_description() -> String:
	var target_str = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_PROCESS_MODE_DESCRIPTION", {
		"target": target_str,
		"mode": _get_mode_name()
	})

# =============================================
# 验证
# =============================================
func validate() -> Array[String]:
	var errors = super.validate()
	if target_node.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))
	return errors

# =============================================
# 动态属性拦截
# =============================================
func _set(property: StringName, value: Variant) -> bool:
	if property == "process_mode":
		set(property, value)
		_update_resource_name()
		return true
	return false
