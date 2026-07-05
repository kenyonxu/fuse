@tool
@icon("res://addons/fuse/icons/builtin/Area2D.svg")
extends BaseCondition
class_name CheckOverlapArea

## 检查 Area2D / Area3D 是否与其他碰撞体重叠

# =============================================
# 属性定义
# =============================================

## 要检查的 Area2D/Area3D 节点
var area_node: NodePath = NodePath(""):
	set(value):
		area_node = value
		_update_resource_name()

## 过滤重叠体所属组（空 = 不过滤）
var check_group: String = "":
	set(value):
		check_group = value
		_update_resource_name()

## 将重叠体列表保存到变量（空 = 不保存）
var save_to_variable: String = "":
	set(value):
		save_to_variable = value
		_update_resource_name()

# =============================================
# 元数据（必需）
# =============================================
static func _get_condition_metadata() -> ConditionMetadata:
	var metadata = ConditionMetadata.new()
	metadata.name_key = "FUSE_CONDITION_CHECK_OVERLAP_AREA_NAME"
	metadata.category_key = "FUSE_CATEGORY_PHYSICS"
	metadata.description_key = "FUSE_CONDITION_CHECK_OVERLAP_AREA_DESC"
	metadata.keywords = ["重叠", "overlap", "area", "区域", "碰撞", "collision", "检测", "check", "物理", "physics", "body"]
	metadata.builtin_icon = "Area2D"
	return metadata

# =============================================
# 动态属性列表
# =============================================
func _get_property_list() -> Array[Dictionary]:
	var properties := []

	# Area 分类
	properties.append({
		name = "Area",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "area_node",
		type = TYPE_NODE_PATH,
		hint = PROPERTY_HINT_NODE_PATH_VALID_TYPES,
		hint_string = "Area2D,Area3D",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Filter 分类
	properties.append({
		name = "Filter",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "check_group",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Output 分类
	properties.append({
		name = "Output",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "save_to_variable",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

# =============================================
# 资源名称
# =============================================
func _update_resource_name() -> void:
	var area_str = _get_node_display_name(area_node) if not area_node.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")
	resource_name = FuseLocalization.translate_format("FUSE_CONDITION_CHECK_OVERLAP_AREA_FORMAT", {
		"area": area_str
	})

# =============================================
# 条件评估
# =============================================
func _evaluate_condition(context: ExecutionContext) -> bool:
	if area_node.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR)
		return false

	var node := context.get_node(area_node)
	if not node:
		return false

	var overlapping_bodies: Array = []
	var overlapping_areas: Array = []

	if node is Area2D:
		overlapping_bodies.assign((node as Area2D).get_overlapping_bodies())
		overlapping_areas.assign((node as Area2D).get_overlapping_areas())
	elif node is Area3D:
		overlapping_bodies.assign((node as Area3D).get_overlapping_bodies())
		overlapping_areas.assign((node as Area3D).get_overlapping_areas())
	else:
		_create_fuse_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", FuseError.ErrorType.RUNTIME_ERROR)
		return false

	# 按组过滤
	if not check_group.is_empty():
		var filtered_bodies: Array = []
		for b in overlapping_bodies:
			if b.is_in_group(check_group):
				filtered_bodies.append(b)
		overlapping_bodies = filtered_bodies

		var filtered_areas: Array = []
		for a in overlapping_areas:
			if a.is_in_group(check_group):
				filtered_areas.append(a)
		overlapping_areas = filtered_areas

	var has_overlap = not overlapping_bodies.is_empty() or not overlapping_areas.is_empty()

	# 保存到变量
	if has_overlap and not save_to_variable.is_empty():
		var all_overlaps: Array = []
		all_overlaps.append_array(overlapping_bodies)
		all_overlaps.append_array(overlapping_areas)
		VariableOperations.set_variable(context, save_to_variable, BaseVariable.VariableScope.LOCAL, all_overlaps)

	_log_debug("重叠检查: %s => %s" % [node.name, has_overlap])

	return has_overlap

# =============================================
# 依赖计算
# =============================================
func _compute_dependencies() -> Array[String]:
	var deps: Array[String] = []
	if not save_to_variable.is_empty():
		deps.append(save_to_variable)
	return deps

# =============================================
# 类型信息
# =============================================
func get_condition_type() -> String:
	return "check_overlap_area"

func get_condition_category() -> String:
	return "physics"

# =============================================
# 描述
# =============================================
func get_description() -> String:
	var area_str = _get_node_display_name(area_node) if not area_node.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")
	if not check_group.is_empty():
		return FuseLocalization.translate_format("FUSE_CONDITION_CHECK_OVERLAP_AREA_DESC_GROUP", {
			"area": area_str,
			"group": check_group
		})
	return FuseLocalization.translate_format("FUSE_CONDITION_CHECK_OVERLAP_AREA_DESCRIPTION", {
		"area": area_str
	})

# =============================================
# 验证
# =============================================
func validate() -> Array[String]:
	var errors = super.validate()
	if area_node.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))
	return errors

# =============================================
# 动态属性拦截
# =============================================
func _set(property: StringName, value: Variant) -> bool:
	if property in ["area_node", "check_group", "save_to_variable"]:
		set(property, value)
		_update_resource_name()
		return true
	return false
