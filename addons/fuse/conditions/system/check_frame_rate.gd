@tool
@icon("res://addons/fuse/icons/builtin/Performance.png")
extends BaseCondition
class_name CheckFrameRate

## 检查当前帧率
##
## 通过 Engine.get_frames_per_second() 检查当前帧率是否满足比较条件。

## 比较类型枚举
enum CompareType {
	EQUAL,          ## ==
	NOT_EQUAL,      ## !=
	GREATER,        ## >
	LESS,           ## <
	GREATER_EQUAL,  ## >=
	LESS_EQUAL      ## <=
}

## 比较类型
var compare_type: CompareType = CompareType.GREATER:
	set(value):
		compare_type = value
		_update_resource_name()

## 阈值 FPS
var threshold_fps: float = 30.0:
	set(value):
		threshold_fps = value
		_update_resource_name()

## 更新资源名称
func _update_resource_name() -> void:
	var op = _get_compare_type_symbol()
	resource_name = FuseLocalization.translate_format("FUSE_CONDITION_FRAME_RATE_FORMAT", {
		"op": op,
		"fps": str(threshold_fps)
	})

func _get_compare_type_symbol() -> String:
	match compare_type:
		CompareType.EQUAL: return "=="
		CompareType.NOT_EQUAL: return "!="
		CompareType.GREATER: return ">"
		CompareType.LESS: return "<"
		CompareType.GREATER_EQUAL: return ">="
		CompareType.LESS_EQUAL: return "<="
	return "?"

## 评估条件
func _evaluate_condition(context: ExecutionContext) -> bool:
	var fps = Engine.get_frames_per_second()

	match compare_type:
		CompareType.EQUAL: return is_equal_approx(fps, threshold_fps)
		CompareType.NOT_EQUAL: return not is_equal_approx(fps, threshold_fps)
		CompareType.GREATER: return fps > threshold_fps
		CompareType.LESS: return fps < threshold_fps
		CompareType.GREATER_EQUAL: return fps >= threshold_fps
		CompareType.LESS_EQUAL: return fps <= threshold_fps

	return false

## 计算依赖
func _compute_dependencies() -> Array[String]:
	return []

## 获取条件类型
func get_condition_type() -> String:
	return "check_frame_rate"

## 获取条件分类
func get_condition_category() -> String:
	return "system"

## 获取条件描述
func get_description() -> String:
	var op = _get_compare_type_symbol()
	return FuseLocalization.translate_format("FUSE_CONDITION_FRAME_RATE_DESCRIPTION", {
		"op": op,
		"fps": str(threshold_fps)
	})

## 验证条件
func validate() -> Array[String]:
	var errors = super.validate()
	if threshold_fps < 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_FPS_INVALID"))
	return errors

## 获取参数
func get_parameters() -> Dictionary:
	return {
		"compare_type": compare_type,
		"threshold_fps": threshold_fps
	}

## 设置参数
func set_parameters(parameters: Dictionary):
	if parameters.has("compare_type"):
		compare_type = parameters["compare_type"]
	if parameters.has("threshold_fps"):
		threshold_fps = parameters["threshold_fps"]

## 获取条件元数据
static func _get_condition_metadata() -> ConditionMetadata:
	var metadata = ConditionMetadata.new()
	metadata.name_key = "FUSE_CONDITION_FRAME_RATE_NAME"
	metadata.category_key = "FUSE_CATEGORY_SYSTEM"
	metadata.description_key = "FUSE_CONDITION_FRAME_RATE_DESC"
	metadata.keywords = ["帧率", "framerate", "FPS", "性能", "performance", "帧", "frame", "检测", "check"]
	metadata.builtin_icon = "Performance"
	return metadata


# 补齐参数的属性注册——带自定义 setter 的脚本变量只有 SCRIPT_VARIABLE 位、无 STORAGE 位，
# 不注册则 Inspector 不可编辑、.tres/.tscn 序列化静默丢值、preset schema 提取器漏收录
# （同 9a90828 对 OnGroundStateChanged 的修法）
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	properties.append({
		name = "compare_type",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Equal, Not Equal, Greater, Less, Greater Equal",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})
	properties.append({
		name = "threshold_fps",
		type = TYPE_FLOAT,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})
	return properties
