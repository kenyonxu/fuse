@tool
@icon("res://addons/fuse/icons/builtin/Terrain3D.svg")
extends BaseCondition
class_name CheckSlope

## 斜坡角度检查条件
##
## 检查 CharacterBody2D/3D 所在斜坡角度是否满足比较条件。

## 比较类型枚举
enum CompareType {
	GREATER_EQUAL,  ## >=
	LESS_EQUAL      ## <=
}

## 要检查的 CharacterBody 节点路径
var target_node: NodePath = NodePath(""):
	set(value):
		target_node = value
		_update_resource_name()

## 比较类型
var compare_type: CompareType = CompareType.LESS_EQUAL:
	set(value):
		compare_type = value
		_update_resource_name()

## 角度（度）
var angle_degrees: float = 45.0:
	set(value):
		angle_degrees = value
		_update_resource_name()

## 更新资源名称
func _update_resource_name() -> void:
	var node_str = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_COMMON_NO_NODE_SELECTED")
	var cmp = ">=" if compare_type == CompareType.GREATER_EQUAL else "<="
	resource_name = FuseLocalization.translate_format("FUSE_CONDITION_CHECK_SLOPE_FORMAT", {
		"node": node_str,
		"cmp": cmp,
		"angle": str(angle_degrees)
	})

## 评估条件
func _evaluate_condition(context: ExecutionContext) -> bool:
	if target_node.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		return false

	var node = context.get_node(target_node)
	if node == null:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"node": str(target_node)})
		return false

	var floor_normal: Variant = Vector3.UP

	if node is CharacterBody2D:
		var body := node as CharacterBody2D
		floor_normal = body.get_floor_normal() if body.is_on_floor() else Vector2.UP
	elif node is CharacterBody3D:
		var body := node as CharacterBody3D
		floor_normal = body.get_floor_normal() if body.is_on_floor() else Vector3.UP
	else:
		_create_fuse_error_localized("FUSE_ERROR_CHARACTER_BODY_REQUIRED", FuseError.ErrorType.VALIDATION_ERROR, {})
		return false

	# 计算斜坡角度（法线与向上的夹角）
	var angle_rad: float = 0.0
	if floor_normal is Vector3:
		angle_rad = (floor_normal as Vector3).angle_to(Vector3.UP)
	elif floor_normal is Vector2:
		angle_rad = (floor_normal as Vector2).angle_to(Vector2.UP)
	var angle := rad_to_deg(angle_rad)

	var result: bool
	match compare_type:
		CompareType.GREATER_EQUAL:
			result = angle >= angle_degrees
		CompareType.LESS_EQUAL:
			result = angle <= angle_degrees


	return result

## 计算依赖
func _compute_dependencies() -> Array[String]:
	return []

## 获取条件类型
func get_condition_type() -> String:
	return "check_slope"

## 获取条件分类
func get_condition_category() -> String:
	return "physics"

## 获取条件描述
func get_description() -> String:
	var node_str = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_COMMON_NO_NODE_SELECTED")
	var cmp = ">=" if compare_type == CompareType.GREATER_EQUAL else "<="
	return FuseLocalization.translate_format("FUSE_CONDITION_CHECK_SLOPE_DESCRIPTION", {
		"node": node_str,
		"cmp": cmp,
		"angle": str(angle_degrees)
	})

## 验证条件
func validate() -> Array[String]:
	var errors = super.validate()
	if target_node.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))
	return errors

## 获取参数
func get_parameters() -> Dictionary:
	return {
		"target_node": target_node,
		"compare_type": compare_type,
		"angle_degrees": angle_degrees
	}

## 设置参数
func set_parameters(parameters: Dictionary):
	if parameters.has("target_node"):
		target_node = parameters["target_node"]
	if parameters.has("compare_type"):
		compare_type = parameters["compare_type"]
	if parameters.has("angle_degrees"):
		angle_degrees = parameters["angle_degrees"]

## 获取条件元数据
static func _get_condition_metadata() -> ConditionMetadata:
	var metadata = ConditionMetadata.new()
	metadata.name_key = "FUSE_CONDITION_CHECK_SLOPE_NAME"
	metadata.category_key = "FUSE_CATEGORY_PHYSICS"
	metadata.description_key = "FUSE_CONDITION_CHECK_SLOPE_DESC"
	metadata.keywords = ["斜坡", "slope", "角度", "angle", "物理", "physics", "地面", "terrain"]
	metadata.builtin_icon = "Terrain3D"
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
	properties.append({
		name = "compare_type",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Greater Equal",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})
	properties.append({
		name = "angle_degrees",
		type = TYPE_FLOAT,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})
	return properties
