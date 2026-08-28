@tool
@icon("res://addons/fuse/icons/builtin/Duplicate.svg")
extends BaseInstruction
class_name CloneNode

## Clone Node 指令 - 运行时克隆目标节点并添加到场景

## 源节点路径
var source_node: NodePath = NodePath(""):
	set(value):
		source_node = value
		_update_resource_name()
		notify_property_list_changed()

## 父节点路径（空=源节点同级）
var parent_node: NodePath = NodePath(""):
	set(value):
		parent_node = value
		_update_resource_name()
		notify_property_list_changed()

## 保存克隆节点引用到变量
var save_to_variable: String = "":
	set(value):
		save_to_variable = value
		_update_resource_name()

## 获取指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_CLONE_NODE_NAME"
	metadata.category_key = "FUSE_CATEGORY_NODE_OPERATIONS"
	metadata.description_key = "FUSE_INSTRUCTION_CLONE_NODE_DESC"
	metadata.keywords = ["克隆", "clone", "复制", "duplicate", "节点", "node", "实例化", "instantiate", "场景"]
	metadata.builtin_icon = "Duplicate"
	return metadata

func _setup_metadata():
	pass

## 声明变量读写模式（save_to=write）
func get_variable_modes() -> Array[Dictionary]:
	return [{"name": "save_to_variable", "mode": "write"}]

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	properties.append({
		name = "Clone Node",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "source_node",
		type = TYPE_NODE_PATH,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "parent_node",
		type = TYPE_NODE_PATH,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "save_to_variable",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 更新资源名称
func _update_resource_name():
	var parts = []
	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_CLONE_NODE_NAME"))

	if not source_node.is_empty():
		parts.append("[%s]" % _get_node_display_name(source_node))

	if not save_to_variable.is_empty():
		parts.append("→ {0}".format([save_to_variable], "{}"))

	resource_name = " ".join(parts)

## 获取指令描述
func get_description() -> String:
	var source_desc = _get_node_display_name(source_node) if not source_node.is_empty() else FuseLocalization.translate("FUSE_COMMON_NO_NODE_SELECTED")
	var var_suffix = ""
	if not save_to_variable.is_empty():
		var_suffix = " → " + save_to_variable
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_CLONE_NODE_DESC_FORMAT", {"source": source_desc}) + var_suffix

## 执行指令
func execute(context: ExecutionContext) -> void:
	_start_execution(context)

	if source_node.is_empty():
		_log_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", {})
		set_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	var source = context.get_node(source_node)
	if source == null:
		_log_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(source_node)})
		set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"node": str(source_node)})
		finished.emit()
		return

	# 确定父节点
	var parent: Node
	if not parent_node.is_empty():
		parent = context.get_node(parent_node)
	else:
		parent = source.get_parent()

	if parent == null:
		_log_error_localized("FUSE_ERROR_PARENT_NODE_NOT_FOUND", {})
		set_error_localized("FUSE_ERROR_PARENT_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	# 克隆节点
	var clone = source.duplicate()
	parent.add_child(clone)

	# 保存到变量
	if not save_to_variable.is_empty():
		context.set_variable(save_to_variable, clone)

	_log_info_localized("FUSE_LOG_NODE_CLONED", {
		"source": source.name,
		"clone": clone.name
	})

	_on_execution_completed()

## 验证参数
func validate() -> Array[String]:
	var errors = super.validate()
	if source_node.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))
	return errors
