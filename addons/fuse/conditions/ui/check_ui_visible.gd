@tool
@icon("res://addons/fuse/icons/builtin/GuiVisibilityXray.png")
extends BaseCondition
class_name CheckUIVisible

## UI 可见性检查条件
##
## 检查 Control 节点是否可见（visible 属性为 true）。

## 目标 Control 节点路径
var target_node: NodePath = NodePath(""):
	set(value):
		target_node = value
		_update_resource_name()

## 更新资源名称
func _update_resource_name() -> void:
	var node_str = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_COMMON_NO_NODE_SELECTED")
	resource_name = FuseLocalization.translate_format("FUSE_CONDITION_UI_VISIBLE_FORMAT", {"node": node_str})

## 评估条件
func _evaluate_condition(context: ExecutionContext) -> bool:
	if target_node.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		return false

	var node = context.get_node(target_node)
	if node == null:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"node": str(target_node)})
		return false

	if not node is CanvasItem:
		_create_fuse_error_localized("FUSE_ERROR_NODE_TYPE_EXPECTED", FuseError.ErrorType.RUNTIME_ERROR, {"node": node.name, "expected": "CanvasItem or Control"})
		return false

	var canvas := node as CanvasItem
	var is_visible = canvas.visible


	return is_visible

## 计算依赖
func _compute_dependencies() -> Array[String]:
	return []

## 获取条件类型
func get_condition_type() -> String:
	return "check_ui_visible"

## 获取条件分类
func get_condition_category() -> String:
	return "ui"

## 获取条件描述
func get_description() -> String:
	var node_str = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_COMMON_NO_NODE_SELECTED")
	return FuseLocalization.translate_format("FUSE_CONDITION_UI_VISIBLE_DESCRIPTION", {"node": node_str})

## 验证条件
func validate() -> Array[String]:
	var errors = super.validate()
	if target_node.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))
	return errors

## 获取参数
func get_parameters() -> Dictionary:
	return {"target_node": target_node}

## 设置参数
func set_parameters(parameters: Dictionary):
	if parameters.has("target_node"):
		target_node = parameters["target_node"]

## 获取条件元数据
static func _get_condition_metadata() -> ConditionMetadata:
	var metadata = ConditionMetadata.new()
	metadata.name_key = "FUSE_CONDITION_UI_VISIBLE_NAME"
	metadata.category_key = "FUSE_CATEGORY_UI"
	metadata.description_key = "FUSE_CONDITION_UI_VISIBLE_DESC"
	metadata.keywords = ["UI", "可见", "visible", "隐藏", "hidden", "显示", "show", "界面", "control"]
	metadata.builtin_icon = "GuiVisibilityXray"
	return metadata


# 补齐参数的属性注册——带自定义 setter 的脚本变量只有 SCRIPT_VARIABLE 位、无 STORAGE 位，
# 不注册则 Inspector 不可编辑、.tres/.tscn 序列化静默丢值、preset schema 提取器漏收录
# （同 9a90828 对 OnGroundStateChanged 的修法）
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	properties.append({
		name = "target_node",
		type = TYPE_NODE_PATH,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})
	return properties
