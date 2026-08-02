@tool
@icon("res://addons/fuse/icons/builtin/Control.svg")
extends BaseInstruction
class_name AddRemoveUIChild

## Add/Remove UI Child 指令 - 动态添加/移除 Control 子节点

## UI 操作枚举
enum UIAction {
	ADD,    ## 添加子节点
	REMOVE  ## 移除子节点
}

## 父 Control 节点路径
var parent_node: NodePath = NodePath(""):
	set(value):
		parent_node = value
		_update_resource_name()
		notify_property_list_changed()

## 操作类型
var action: UIAction = UIAction.ADD:
	set(value):
		action = value
		_update_resource_name()
		notify_property_list_changed()

## 子场景路径（ADD 时使用）
var child_scene: String = "":
	set(value):
		child_scene = value
		_update_resource_name()

## 子节点名（REMOVE 时使用）
var child_name: String = "":
	set(value):
		child_name = value
		_update_resource_name()

## 获取指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_ADD_REMOVE_UI_CHILD_NAME"
	metadata.category_key = "FUSE_CATEGORY_UI"
	metadata.description_key = "FUSE_INSTRUCTION_ADD_REMOVE_UI_CHILD_DESC"
	metadata.keywords = ["UI", "界面", "添加", "add", "移除", "remove", "子节点", "child", "场景", "scene", "实例化", "instantiate"]
	metadata.builtin_icon = "Control"
	return metadata

func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	properties.append({
		name = "Add/Remove UI Child",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "parent_node",
		type = TYPE_NODE_PATH,
		hint = PROPERTY_HINT_NODE_PATH_VALID_TYPES,
		hint_string = "Control",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "action",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Add,Remove",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if action == UIAction.ADD:
		properties.append({
			name = "child_scene",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_FILE,
			hint_string = "*.tscn,*.scn",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
	else:
		properties.append({
			name = "child_name",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

	return properties

## 验证属性可见性
func _validate_property(property: Dictionary) -> void:
	if action == UIAction.ADD:
		if property.name == "child_name":
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		if property.name == "child_scene":
			property.usage = PROPERTY_USAGE_NO_EDITOR

## 更新资源名称
func _update_resource_name():
	var parts = []
	var action_str = FuseLocalization.translate("FUSE_UI_ACTION_ADD") if action == UIAction.ADD else FuseLocalization.translate("FUSE_UI_ACTION_REMOVE")
	parts.append(action_str)

	if not parent_node.is_empty():
		parts.append("[%s]" % _get_node_display_name(parent_node))

	resource_name = " ".join(parts)

## 获取指令描述
func get_description() -> String:
	var parent_desc = _get_node_display_name(parent_node) if not parent_node.is_empty() else FuseLocalization.translate("FUSE_COMMON_NO_NODE_SELECTED")
	if action == UIAction.ADD:
		var scene_name = child_scene.get_file() if not child_scene.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")
		return FuseLocalization.translate_format("FUSE_INSTRUCTION_ADD_REMOVE_UI_CHILD_DESC_ADD", {"parent": parent_desc, "scene": scene_name})
	else:
		var name_str = child_name if not child_name.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")
		return FuseLocalization.translate_format("FUSE_INSTRUCTION_ADD_REMOVE_UI_CHILD_DESC_REMOVE", {"parent": parent_desc, "child": name_str})

## 执行指令
func execute(context: ExecutionContext) -> void:
	_start_execution(context)

	if parent_node.is_empty():
		_log_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", {})
		set_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	var parent = context.get_node(parent_node)
	if parent == null:
		_log_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(parent_node)})
		set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"node": str(parent_node)})
		finished.emit()
		return

	if not parent is Control:
		_log_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", {"node": parent.name, "expected": "Control"})
		set_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", FuseError.ErrorType.RUNTIME_ERROR, {"node": parent.name, "expected": "Control"})
		finished.emit()
		return

	match action:
		UIAction.ADD:
			_add_child(context, parent)
		UIAction.REMOVE:
			_remove_child(context, parent)

	_on_execution_completed()

## 添加子节点
func _add_child(context: ExecutionContext, parent: Control) -> void:
	if child_scene.is_empty():
		_log_error_localized("FUSE_ERROR_SCENE_PATH_EMPTY", {})
		set_error_localized("FUSE_ERROR_SCENE_PATH_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	var scene = load(child_scene)
	if scene == null:
		_log_error_localized("FUSE_ERROR_SCENE_LOAD_FAILED", {"path": child_scene})
		set_error_localized("FUSE_ERROR_SCENE_LOAD_FAILED", FuseError.ErrorType.RUNTIME_ERROR, {"path": child_scene})
		finished.emit()
		return

	var instance = scene.instantiate()
	parent.add_child(instance)

	_log_info_localized("FUSE_LOG_UI_CHILD_ADDED", {
		"scene": child_scene.get_file(),
		"parent": parent.name
	})

## 移除子节点
func _remove_child(context: ExecutionContext, parent: Control) -> void:
	if child_name.is_empty():
		_log_error_localized("FUSE_ERROR_CHILD_NAME_EMPTY", {})
		set_error_localized("FUSE_ERROR_CHILD_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	var child = parent.get_node_or_null(child_name)
	if child == null:
		child = parent.find_child(child_name, true, false)

	if child == null:
		_log_error_localized("FUSE_ERROR_CHILD_NOT_FOUND", {"child": child_name, "parent": parent.name})
		set_error_localized("FUSE_ERROR_CHILD_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"child": child_name, "parent": parent.name})
		finished.emit()
		return

	child.queue_free()
	_log_info_localized("FUSE_LOG_UI_CHILD_REMOVED", {
		"child": child_name,
		"parent": parent.name
	})

## 动态属性拦截
func _set(property: StringName, value: Variant) -> bool:
	if property in ["parent_node", "action", "child_scene", "child_name"]:
		set(property, value)
		_update_resource_name()
		if property == "action":
			notify_property_list_changed()
		return true
	return false

## 验证参数
func validate() -> Array[String]:
	var errors = super.validate()
	if parent_node.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))
	if action == UIAction.ADD and child_scene.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_SCENE_PATH_EMPTY"))
	if action == UIAction.REMOVE and child_name.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_CHILD_NAME_EMPTY"))
	return errors
