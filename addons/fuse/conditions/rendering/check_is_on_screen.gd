@tool
@icon("res://addons/fuse/icons/builtin/VisibleOnScreenNotifier2D.svg")
extends BaseCondition
class_name CheckIsOnScreen

## 检查节点是否在屏幕视口内可见

# =============================================
# 属性定义
# =============================================

## 要检查的节点
var target_node: NodePath = NodePath(""):
	set(value):
		target_node = value
		_update_resource_name()

## 是否使用 VisibleOnScreenNotifier（true）或手动计算（false）
var use_notifier: bool = true:
	set(value):
		use_notifier = value
		_update_resource_name()
		notify_property_list_changed()

## 视口边缘余量（手动模式，正值为向内收缩）
var margin: float = 0.0:
	set(value):
		margin = value
		_update_resource_name()

# =============================================
# 元数据（必需）
# =============================================
static func _get_condition_metadata() -> ConditionMetadata:
	var metadata = ConditionMetadata.new()
	metadata.name_key = "FUSE_CONDITION_CHECK_IS_ON_SCREEN_NAME"
	metadata.category_key = "FUSE_CATEGORY_RENDERING"
	metadata.description_key = "FUSE_CONDITION_CHECK_IS_ON_SCREEN_DESC"
	metadata.keywords = ["屏幕", "screen", "可见", "visible", "视口", "viewport", "渲染", "rendering", "检查", "check"]
	metadata.builtin_icon = "VisibleOnScreenNotifier2D"
	return metadata

# =============================================
# 动态属性列表
# =============================================
func _get_property_list() -> Array[Dictionary]:
	var properties := []

	# Node 分类
	properties.append({
		name = "Node",
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

	# Detection 分类
	properties.append({
		name = "Detection",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "use_notifier",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if not use_notifier:
		properties.append({
			name = "margin",
			type = TYPE_FLOAT,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

	return properties

# =============================================
# 条件属性可见性
# =============================================
func _validate_property(property: Dictionary) -> void:
	if use_notifier and property.name == "margin":
		property.usage = PROPERTY_USAGE_NO_EDITOR

# =============================================
# 资源名称
# =============================================
func _update_resource_name() -> void:
	var node_str = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")
	resource_name = FuseLocalization.translate_format("FUSE_CONDITION_CHECK_IS_ON_SCREEN_FORMAT", {
		"node": node_str
	})

# =============================================
# 条件评估
# =============================================
func _evaluate_condition(context: ExecutionContext) -> bool:
	if target_node.is_empty():
		return false

	var node := context.get_node(target_node)
	if not node:
		return false

	# 方式 1：使用 VisibleOnScreenNotifier
	if use_notifier:
		if node is VisibleOnScreenNotifier2D:
			return (node as VisibleOnScreenNotifier2D).is_on_screen()
		elif node is VisibleOnScreenNotifier3D:
			return (node as VisibleOnScreenNotifier3D).is_on_screen()
		elif node is CanvasItem:
			var canvas_item := node as CanvasItem
			return canvas_item.visible and canvas_item.is_visible_in_tree()
		return false

	# 方式 2：手动计算（基于 viewport bounds）
	var viewport = node.get_viewport()
	if not viewport:
		return false

	var screen_size = viewport.get_visible_rect().size
	var pos: Vector2

	if node is Node2D:
		var transform = viewport.get_final_transform()
		pos = transform * (node as Node2D).global_position
	elif node is Node3D:
		var cam = viewport.get_camera_3d()
		if cam:
			pos = cam.unproject_position((node as Node3D).global_position)
		else:
			return false
	elif node is Control:
		pos = (node as Control).global_position
	else:
		return false

	return pos.x >= -margin and pos.x <= screen_size.x + margin and \
		   pos.y >= -margin and pos.y <= screen_size.y + margin

# =============================================
# 依赖计算
# =============================================
func _compute_dependencies() -> Array[String]:
	return []

# =============================================
# 类型信息
# =============================================
func get_condition_type() -> String:
	return "is_on_screen"

func get_condition_category() -> String:
	return "rendering"

# =============================================
# 描述
# =============================================
func get_description() -> String:
	var node_str = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")
	return FuseLocalization.translate_format("FUSE_CONDITION_CHECK_IS_ON_SCREEN_DESCRIPTION", {
		"node": node_str
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
	if property in ["target_node", "use_notifier", "margin"]:
		set(property, value)
		_update_resource_name()
		if property == "use_notifier":
			notify_property_list_changed()
		return true
	return false
