@tool
@icon("res://addons/fuse/icons/builtin/AnimationTree.png")
extends BaseCondition
class_name CheckAnimationTreeParameter

## AnimationTree 参数检查条件
##
## 检查 AnimationTree 的指定参数值是否满足比较条件。

## 比较类型枚举
enum CompareType {
	EQUAL,          ## ==
	NOT_EQUAL,      ## !=
	GREATER,        ## >
	LESS,           ## <
	GREATER_EQUAL,  ## >=
	LESS_EQUAL      ## <=
}

## 参数类型枚举
enum ParamType {
	FLOAT,   ## 浮点
	BOOL,    ## 布尔
	STRING   ## 字符串
}

## AnimationTree 节点路径
var target_node: NodePath = NodePath(""):
	set(value):
		target_node = value
		_update_resource_name()

## 参数名
var parameter_name: String = "":
	set(value):
		parameter_name = value
		_update_resource_name()

## 比较类型
var compare_type: CompareType = CompareType.EQUAL:
	set(value):
		compare_type = value
		_update_resource_name()

## 比较值 (float)
var compare_value: float = 0.0:
	set(value):
		compare_value = value
		_update_resource_name()

## 参数类型
var parameter_type: ParamType = ParamType.FLOAT:
	set(value):
		parameter_type = value
		_update_resource_name()

## 更新资源名称
func _update_resource_name() -> void:
	var node_str = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_COMMON_NO_NODE_SELECTED")
	var param_str = parameter_name if not parameter_name.is_empty() else "?"
	resource_name = FuseLocalization.translate_format("FUSE_CONDITION_ANIM_TREE_PARAM_FORMAT", {
		"node": node_str,
		"param": param_str,
		"value": str(compare_value)
	})

## 评估条件
func _evaluate_condition(context: ExecutionContext) -> bool:
	if target_node.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		return false

	if parameter_name.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_MISSING_PARAMETER", FuseError.ErrorType.VALIDATION_ERROR, {"parameter": "parameter_name"})
		return false

	var node = context.get_node(target_node)
	if node == null:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"node": str(target_node)})
		return false

	if not node is AnimationTree:
		_create_fuse_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", FuseError.ErrorType.RUNTIME_ERROR, {"node": node.name, "expected": "AnimationTree"})
		return false

	var tree := node as AnimationTree
	var value: Variant

	match parameter_type:
		ParamType.FLOAT:
			value = tree.get("parameters/" + parameter_name)
			if value == null:
				return false
		ParamType.BOOL:
			value = tree.get("parameters/" + parameter_name)
			if value == null:
				return false
		ParamType.STRING:
			value = tree.get("parameters/" + parameter_name)
			if value == null:
				return false

	var result := false
	match compare_type:
		CompareType.EQUAL:
			match parameter_type:
				ParamType.FLOAT: result = is_equal_approx(float(value), compare_value)
				ParamType.BOOL: result = bool(value) == bool(compare_value >= 0.5)
				ParamType.STRING: result = str(value) == str(compare_value)
		CompareType.NOT_EQUAL:
			match parameter_type:
				ParamType.FLOAT: result = not is_equal_approx(float(value), compare_value)
				ParamType.BOOL: result = bool(value) != bool(compare_value >= 0.5)
				ParamType.STRING: result = str(value) != str(compare_value)
		CompareType.GREATER:
			result = float(value) > compare_value
		CompareType.LESS:
			result = float(value) < compare_value
		CompareType.GREATER_EQUAL:
			result = float(value) >= compare_value
		CompareType.LESS_EQUAL:
			result = float(value) <= compare_value


	return result

## 计算依赖
func _compute_dependencies() -> Array[String]:
	return []

## 获取条件类型
func get_condition_type() -> String:
	return "check_animation_tree_parameter"

## 获取条件分类
func get_condition_category() -> String:
	return "animation"

## 获取条件描述
func get_description() -> String:
	var node_str = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_COMMON_NO_NODE_SELECTED")
	return FuseLocalization.translate_format("FUSE_CONDITION_ANIM_TREE_PARAM_DESCRIPTION", {
		"node": node_str,
		"param": parameter_name,
		"value": str(compare_value)
	})

## 验证条件
func validate() -> Array[String]:
	var errors = super.validate()
	if target_node.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))
	if parameter_name.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_MISSING_PARAMETER"))
	return errors

## 获取参数
func get_parameters() -> Dictionary:
	return {
		"target_node": target_node,
		"parameter_name": parameter_name,
		"compare_type": compare_type,
		"compare_value": compare_value,
		"parameter_type": parameter_type
	}

## 设置参数
func set_parameters(parameters: Dictionary):
	if parameters.has("target_node"):
		target_node = parameters["target_node"]
	if parameters.has("parameter_name"):
		parameter_name = parameters["parameter_name"]
	if parameters.has("compare_type"):
		compare_type = parameters["compare_type"]
	if parameters.has("compare_value"):
		compare_value = parameters["compare_value"]
	if parameters.has("parameter_type"):
		parameter_type = parameters["parameter_type"]

## 获取条件元数据
static func _get_condition_metadata() -> ConditionMetadata:
	var metadata = ConditionMetadata.new()
	metadata.name_key = "FUSE_CONDITION_ANIM_TREE_PARAM_NAME"
	metadata.category_key = "FUSE_CATEGORY_ANIMATION"
	metadata.description_key = "FUSE_CONDITION_ANIM_TREE_PARAM_DESC"
	metadata.keywords = ["动画树", "AnimationTree", "参数", "parameter", "混合", "blend", "状态", "state", "动画", "animation"]
	metadata.builtin_icon = "AnimationTree"
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
		name = "parameter_name",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})
	properties.append({
		name = "compare_type",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Equal, Not Equal, Greater, Less, Greater Equal",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})
	properties.append({
		name = "compare_value",
		type = TYPE_FLOAT,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})
	properties.append({
		name = "parameter_type",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Float, Bool",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})
	return properties
