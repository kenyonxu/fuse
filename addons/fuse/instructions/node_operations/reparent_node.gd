@tool
@icon("res://addons/fuse/icons/builtin/Node.png")
extends BaseInstruction
class_name ReparentNode

## 重父化节点
##
## 将节点从一个父节点移动到另一个父节点，可选择保持全局变换。

# 要移动的节点路径
var target_node: NodePath = NodePath("")

# 新父节点路径
var new_parent: NodePath = NodePath("")

# 是否保持全局变换
var keep_global_transform: bool = true

## 获取指令元数据（用于指令选择器）
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_REPARENT_NODE_NAME"
	metadata.category_key = "FUSE_CATEGORY_NODE_OPERATIONS"
	metadata.description_key = "FUSE_INSTRUCTION_REPARENT_NODE_DESC"
	metadata.keywords = ["reparent", "parent", "move", "node", "重父化", "父节点", "移动", "节点"]
	metadata.builtin_icon = "Node"
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	# Nodes 分类
	properties.append({
		name = "Nodes",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 要移动的节点
	properties.append({
		name = "target_node",
		type = TYPE_NODE_PATH,
		hint = PROPERTY_HINT_NODE_PATH_VALID_TYPES,
		hint_string = "Node",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 新父节点
	properties.append({
		name = "new_parent",
		type = TYPE_NODE_PATH,
		hint = PROPERTY_HINT_NODE_PATH_VALID_TYPES,
		hint_string = "Node",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Options 分类
	properties.append({
		name = "Options",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 是否保持全局变换
	properties.append({
		name = "keep_global_transform",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 更新资源名称
func _update_resource_name():
	var parts = []

	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_REPARENT_NODE_ACTION"))

	if not target_node.is_empty():
		parts.append("'%s'" % target_node)
	else:
		parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_REPARENT_NODE_NO_SPECIFIED"))

	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_REPARENT_NODE_TO"))

	if not new_parent.is_empty():
		parts.append("'%s'" % new_parent)
	else:
		parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_REPARENT_NODE_NO_SPECIFIED"))

	resource_name = " ".join(parts)

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	# 验证目标节点路径
	if target_node.is_empty():
		_log_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", {})
		set_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 验证新父节点路径
	if new_parent.is_empty():
		_log_error_localized("FUSE_ERROR_NEW_PARENT_NODE_EMPTY", {})
		set_error_localized("FUSE_ERROR_NEW_PARENT_NODE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 获取目标节点
	var node := context.get_node(target_node)
	if not node:
		_log_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(target_node)})
		set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"node": str(target_node)})
		finished.emit()
		return

	# 获取新父节点
	var parent_node := context.get_node(new_parent)
	if not parent_node:
		_log_error_localized("FUSE_ERROR_PARENT_NODE_NOT_FOUND", {})
		set_error_localized("FUSE_ERROR_PARENT_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	# 检查是否重父化到自身
	if node == parent_node:
		_log_error_localized("FUSE_ERROR_CANNOT_REPARENT_TO_SELF", {})
		set_error_localized("FUSE_ERROR_CANNOT_REPARENT_TO_SELF", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 检查是否重父化到子孙节点
	var current = parent_node
	while current:
		if current == node:
			_log_error_localized("FUSE_ERROR_CANNOT_REPARENT_TO_DESCENDANT", {})
			set_error_localized("FUSE_ERROR_CANNOT_REPARENT_TO_DESCENDANT", FuseError.ErrorType.VALIDATION_ERROR, {})
			finished.emit()
			return
		current = current.get_parent()

	# 执行重父化
	var old_parent = node.get_parent()
	node.reparent(parent_node, keep_global_transform)

	if old_parent:
		_log_info_localized("FUSE_LOG_REPARENT_FROM_OLD", {
			"node": node.name,
			"old_parent": old_parent.name,
			"new_parent": parent_node.name
		})
	else:
		_log_info_localized("FUSE_LOG_REPARENT_NO_OLD", {
			"node": node.name,
			"new_parent": parent_node.name
		})

	_on_execution_completed()

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()

	if target_node.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_PATH_EMPTY"))

	if new_parent.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_NEW_PARENT_PATH_CANNOT_BE_EMPTY"))

	return errors

## 获取指令描述
func get_description() -> String:
	var transform_key = "FUSE_INSTRUCTION_REPARENT_KEEP_TRANSFORM" if keep_global_transform else "FUSE_INSTRUCTION_REPARENT_NO_KEEP_TRANSFORM"
	var transform_str = FuseLocalization.translate(transform_key)
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_REPARENT_DESC_FORMAT", {
		"target": _get_node_display_name(target_node),
		"parent": str(new_parent),
		"transform": transform_str
	})
