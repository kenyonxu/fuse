@tool
@icon("res://addons/fuse/icons/builtin/InputEventKey.png")
extends BaseCondition
class_name CheckInputMagnitude

## 输入向量大小检查条件
##
## 检查输入向量的大小（走/跑区分），用于检测玩家输入强度。

## 比较类型枚举
enum CompareType {
	GREATER,        ## >
	LESS,           ## <
	GREATER_EQUAL,  ## >=
	LESS_EQUAL      ## <=
}

## 输入动作名（如 "move_left", "move_right", "move_up", "move_down" 的基础前缀）
## 使用 Input.get_vector() 获取组合方向向量
var input_action_left: String = "move_left":
	set(value):
		input_action_left = value
		_update_resource_name()

var input_action_right: String = "move_right":
	set(value):
		input_action_right = value
		_update_resource_name()

var input_action_up: String = "move_up":
	set(value):
		input_action_up = value
		_update_resource_name()

var input_action_down: String = "move_down":
	set(value):
		input_action_down = value
		_update_resource_name()

## 比较类型
var compare_type: CompareType = CompareType.GREATER:
	set(value):
		compare_type = value
		_update_resource_name()

## 阈值 (0-1)
var threshold: float = 0.5:
	set(value):
		threshold = value
		_update_resource_name()

## 更新资源名称
func _update_resource_name() -> void:
	var cmp_str = ""
	match compare_type:
		CompareType.GREATER: cmp_str = ">"
		CompareType.LESS: cmp_str = "<"
		CompareType.GREATER_EQUAL: cmp_str = ">="
		CompareType.LESS_EQUAL: cmp_str = "<="

	resource_name = FuseLocalization.translate_format("FUSE_CONDITION_INPUT_MAGNITUDE_FORMAT", {
		"cmp": cmp_str,
		"threshold": str(threshold)
	})

## 评估条件
func _evaluate_condition(context: ExecutionContext) -> bool:
	var input_vector = Input.get_vector(input_action_left, input_action_right, input_action_up, input_action_down)
	var magnitude = input_vector.length()

	var result: bool
	match compare_type:
		CompareType.GREATER:
			result = magnitude > threshold
		CompareType.LESS:
			result = magnitude < threshold
		CompareType.GREATER_EQUAL:
			result = magnitude >= threshold
		CompareType.LESS_EQUAL:
			result = magnitude <= threshold


	return result

## 计算依赖
func _compute_dependencies() -> Array[String]:
	return []

## 获取条件类型
func get_condition_type() -> String:
	return "check_input_magnitude"

## 获取条件分类
func get_condition_category() -> String:
	return "input"

## 获取条件描述
func get_description() -> String:
	var cmp_str = ""
	match compare_type:
		CompareType.GREATER: cmp_str = ">"
		CompareType.LESS: cmp_str = "<"
		CompareType.GREATER_EQUAL: cmp_str = ">="
		CompareType.LESS_EQUAL: cmp_str = "<="

	return FuseLocalization.translate_format("FUSE_CONDITION_INPUT_MAGNITUDE_DESCRIPTION", {
		"cmp": cmp_str,
		"threshold": str(threshold)
	})

## 验证条件
func validate() -> Array[String]:
	var errors = super.validate()
	return errors

## 获取参数
func get_parameters() -> Dictionary:
	return {
		"input_action_left": input_action_left,
		"input_action_right": input_action_right,
		"input_action_up": input_action_up,
		"input_action_down": input_action_down,
		"compare_type": compare_type,
	}

## 设置参数
func set_parameters(parameters: Dictionary):
	if parameters.has("input_action_left"): input_action_left = parameters["input_action_left"]
	if parameters.has("input_action_right"): input_action_right = parameters["input_action_right"]
	if parameters.has("input_action_up"): input_action_up = parameters["input_action_up"]
	if parameters.has("input_action_down"): input_action_down = parameters["input_action_down"]
	if parameters.has("compare_type"): compare_type = parameters["compare_type"]
	if parameters.has("threshold"): threshold = parameters["threshold"]

## 获取条件元数据
static func _get_condition_metadata() -> ConditionMetadata:
	var metadata = ConditionMetadata.new()
	metadata.name_key = "FUSE_CONDITION_INPUT_MAGNITUDE_NAME"
	metadata.category_key = "FUSE_CATEGORY_INPUT"
	metadata.description_key = "FUSE_CONDITION_INPUT_MAGNITUDE_DESC"
	metadata.keywords = ["输入", "input", "大小", "magnitude", "强度", "intensity", "方向", "direction", "走", "跑", "walk", "run"]
	metadata.builtin_icon = "InputEventKey"
	return metadata


# 补齐参数的属性注册——带自定义 setter 的脚本变量只有 SCRIPT_VARIABLE 位、无 STORAGE 位，
# 不注册则 Inspector 不可编辑、.tres/.tscn 序列化静默丢值、preset schema 提取器漏收录
# （同 9a90828 对 OnGroundStateChanged 的修法）
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	properties.append({
		name = "input_action_left",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})
	properties.append({
		name = "input_action_right",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})
	properties.append({
		name = "input_action_up",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})
	properties.append({
		name = "input_action_down",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})
	properties.append({
		name = "compare_type",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Greater, Less, Greater Equal",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})
	properties.append({
		name = "threshold",
		type = TYPE_FLOAT,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})
	return properties
