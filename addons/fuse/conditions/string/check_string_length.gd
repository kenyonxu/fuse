@tool
@icon("res://addons/fuse/icons/builtin/GuiRadioChecked.png")
extends BaseCondition
class_name CheckStringLength

## 检查字符串长度
##
## 从变量中读取字符串，检查其长度是否满足比较条件。

## 比较类型枚举
enum CompareType {
	EQUAL,          ## ==
	NOT_EQUAL,      ## !=
	GREATER,        ## >
	LESS,           ## <
	GREATER_EQUAL,  ## >=
	LESS_EQUAL      ## <=
}

## 源字符串变量名
var source_variable: String = "":
	set(value):
		source_variable = value
		_update_resource_name()

## 比较类型
var compare_type: CompareType = CompareType.GREATER:
	set(value):
		compare_type = value
		_update_resource_name()

## 阈值
var threshold: int = 0:
	set(value):
		threshold = value
		_update_resource_name()

## 更新资源名称
func _update_resource_name() -> void:
	var src = source_variable if not source_variable.is_empty() else "?"
	var op = _get_compare_type_symbol()
	resource_name = FuseLocalization.translate_format("FUSE_CONDITION_STRING_LENGTH_FORMAT", {
		"source": src,
		"op": op,
		"threshold": str(threshold)
	})

## 获取比较符号
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
	if source_variable.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		return false

	var source: String = str(context.get_local(source_variable))
	var length := source.length()

	match compare_type:
		CompareType.EQUAL: return length == threshold
		CompareType.NOT_EQUAL: return length != threshold
		CompareType.GREATER: return length > threshold
		CompareType.LESS: return length < threshold
		CompareType.GREATER_EQUAL: return length >= threshold
		CompareType.LESS_EQUAL: return length <= threshold

	return false

## 计算依赖
func _compute_dependencies() -> Array[String]:
	return [source_variable]

## 获取条件类型
func get_condition_type() -> String:
	return "string_length"

## 获取条件分类
func get_condition_category() -> String:
	return "string"

## 获取条件描述
func get_description() -> String:
	var src = source_variable if not source_variable.is_empty() else "?"
	var op = _get_compare_type_symbol()
	return FuseLocalization.translate_format("FUSE_CONDITION_STRING_LENGTH_DESCRIPTION", {
		"source": src,
		"op": op,
		"threshold": str(threshold)
	})

## 验证条件
func validate() -> Array[String]:
	var errors = super.validate()
	if source_variable.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_VAR_NAME_EMPTY"))
	return errors

## 获取参数
func get_parameters() -> Dictionary:
	return {
		"source_variable": source_variable,
		"compare_type": compare_type,
		"threshold": threshold
	}

## 设置参数
func set_parameters(parameters: Dictionary):
	if parameters.has("source_variable"):
		source_variable = parameters["source_variable"]
	if parameters.has("compare_type"):
		compare_type = parameters["compare_type"]
	if parameters.has("threshold"):
		threshold = parameters["threshold"]

## 获取条件元数据
static func _get_condition_metadata() -> ConditionMetadata:
	var metadata = ConditionMetadata.new()
	metadata.name_key = "FUSE_CONDITION_STRING_LENGTH_NAME"
	metadata.category_key = "FUSE_CATEGORY_STRING"
	metadata.description_key = "FUSE_CONDITION_STRING_LENGTH_DESC"
	metadata.keywords = ["字符串", "string", "长度", "length", "比较", "compare", "大小", "size", "计数", "count"]
	metadata.builtin_icon = "GuiRadioChecked"
	return metadata
