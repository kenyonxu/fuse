@tool
@icon("res://addons/fuse/icons/builtin/InputEventKey.png")
extends BaseCondition
class_name CheckInputDirection

## 检查当前输入方向（摇杆/键盘）
##
## 通过 Input.get_vector() 检查输入方向是否匹配预期方向。

## 方向枚举
enum Direction {
	UP,      ## 上
	DOWN,    ## 下
	LEFT,    ## 左
	RIGHT    ## 右
}

## 左移动动作名
var input_action_left: String = "move_left":
	set(value):
		input_action_left = value
		_update_resource_name()

## 右移动动作名
var input_action_right: String = "move_right":
	set(value):
		input_action_right = value
		_update_resource_name()

## 上移动动作名
var input_action_up: String = "move_up":
	set(value):
		input_action_up = value
		_update_resource_name()

## 下移动动作名
var input_action_down: String = "move_down":
	set(value):
		input_action_down = value
		_update_resource_name()

## 预期方向
var expected_direction: Direction = Direction.UP:
	set(value):
		expected_direction = value
		_update_resource_name()

## 容差（小于此值的输入被视为 0）
var tolerance: float = 0.3:
	set(value):
		tolerance = value
		_update_resource_name()

## 更新资源名称
func _update_resource_name() -> void:
	var dir_name = _get_direction_name(expected_direction)
	resource_name = FuseLocalization.translate_format("FUSE_CONDITION_INPUT_DIRECTION_FORMAT", {
		"direction": dir_name
	})

func _get_direction_name(dir: Direction) -> String:
	match dir:
		Direction.UP: return FuseLocalization.translate("FUSE_DIRECTION_UP")
		Direction.DOWN: return FuseLocalization.translate("FUSE_DIRECTION_DOWN")
		Direction.LEFT: return FuseLocalization.translate("FUSE_DIRECTION_LEFT")
		Direction.RIGHT: return FuseLocalization.translate("FUSE_DIRECTION_RIGHT")
	return "?"

## 评估条件
func _evaluate_condition(context: ExecutionContext) -> bool:
	var input_vector = Input.get_vector(input_action_left, input_action_right, input_action_up, input_action_down)

	# 检查输入是否超过容差
	if input_vector.length() < tolerance:
		return false

	match expected_direction:
		Direction.UP: return input_vector.y < -tolerance
		Direction.DOWN: return input_vector.y > tolerance
		Direction.LEFT: return input_vector.x < -tolerance
		Direction.RIGHT: return input_vector.x > tolerance

	return false

## 计算依赖
func _compute_dependencies() -> Array[String]:
	return []

## 获取条件类型
func get_condition_type() -> String:
	return "input_direction"

## 获取条件分类
func get_condition_category() -> String:
	return "input"

## 获取条件描述
func get_description() -> String:
	var dir_name = _get_direction_name(expected_direction)
	return FuseLocalization.translate_format("FUSE_CONDITION_INPUT_DIRECTION_DESCRIPTION", {
		"direction": dir_name
	})

## 验证条件
func validate() -> Array[String]:
	var errors = super.validate()
	if not InputMap.has_action(input_action_left) or not InputMap.has_action(input_action_right) or not InputMap.has_action(input_action_up) or not InputMap.has_action(input_action_down):
		# 静默跳过，因为默认动作可能未配置
		pass
	if tolerance < 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_TOLERANCE_INVALID"))
	return errors

## 获取参数
func get_parameters() -> Dictionary:
	return {
		"input_action_left": input_action_left,
		"input_action_right": input_action_right,
		"input_action_up": input_action_up,
		"input_action_down": input_action_down,
		"expected_direction": expected_direction,
		"tolerance": tolerance
	}

## 设置参数
func set_parameters(parameters: Dictionary):
	if parameters.has("input_action_left"):
		input_action_left = parameters["input_action_left"]
	if parameters.has("input_action_right"):
		input_action_right = parameters["input_action_right"]
	if parameters.has("input_action_up"):
		input_action_up = parameters["input_action_up"]
	if parameters.has("input_action_down"):
		input_action_down = parameters["input_action_down"]
	if parameters.has("expected_direction"):
		expected_direction = parameters["expected_direction"]
	if parameters.has("tolerance"):
		tolerance = parameters["tolerance"]

## 获取条件元数据
static func _get_condition_metadata() -> ConditionMetadata:
	var metadata = ConditionMetadata.new()
	metadata.name_key = "FUSE_CONDITION_INPUT_DIRECTION_NAME"
	metadata.category_key = "FUSE_CATEGORY_INPUT"
	metadata.description_key = "FUSE_CONDITION_INPUT_DIRECTION_DESC"
	metadata.keywords = ["输入", "input", "方向", "direction", "摇杆", "joystick", "键盘", "keyboard", "wasd", "移动"]
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
		name = "expected_direction",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Up, Down, Left",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})
	properties.append({
		name = "tolerance",
		type = TYPE_FLOAT,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})
	return properties
