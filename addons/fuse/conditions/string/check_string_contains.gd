@tool
@icon("res://addons/fuse/icons/builtin/GuiRadioChecked.png")
extends BaseCondition
class_name CheckStringContains

## 检查字符串是否包含子串
##
## 从变量中读取字符串，检查是否包含指定子串。支持大小写敏感选项。

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

## 查找的子串
var search: String = "":
	set(value):
		search = value
		_update_resource_name()

## 是否区分大小写
var case_sensitive: bool = true:
	set(value):
		case_sensitive = value
		_update_resource_name()

## 更新资源名称
func _update_resource_name() -> void:
	var src = source_variable if not source_variable.is_empty() else "?"
	var srch = search if not search.is_empty() else "?"
	resource_name = FuseLocalization.translate_format("FUSE_CONDITION_STRING_CONTAINS_FORMAT", {
		"source": src,
		"search": srch
	})

## 评估条件
func _evaluate_condition(context: ExecutionContext) -> bool:
	if source_variable.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		return false

	var source: String = str(context.get_variable(source_variable))

	if case_sensitive:
		return source.contains(search)
	else:
		return source.to_lower().contains(search.to_lower())

## 计算依赖
func _compute_dependencies() -> Array[String]:
	return [source_variable]

## 声明变量读写模式（精确化静态分析）
## source_variable 仅 read（_evaluate_condition 中读取字符串变量并检查是否包含子串）
func get_variable_modes() -> Array[Dictionary]:
	return [
		{"name": "source_variable", "mode": "read"},
	]

## 获取条件类型
func get_condition_type() -> String:
	return "string_contains"

## 获取条件分类
func get_condition_category() -> String:
	return "string"

## 获取条件描述
func get_description() -> String:
	var src = source_variable if not source_variable.is_empty() else "?"
	return FuseLocalization.translate_format("FUSE_CONDITION_STRING_CONTAINS_DESCRIPTION", {
		"source": src,
		"search": search
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
		"search": search,
		"case_sensitive": case_sensitive
	}

## 设置参数
func set_parameters(parameters: Dictionary):
	if parameters.has("source_variable"):
		source_variable = parameters["source_variable"]
	if parameters.has("search"):
		search = parameters["search"]
	if parameters.has("case_sensitive"):
		case_sensitive = parameters["case_sensitive"]

## 获取条件元数据
static func _get_condition_metadata() -> ConditionMetadata:
	var metadata = ConditionMetadata.new()
	metadata.name_key = "FUSE_CONDITION_STRING_CONTAINS_NAME"
	metadata.category_key = "FUSE_CATEGORY_STRING"
	metadata.description_key = "FUSE_CONDITION_STRING_CONTAINS_DESC"
	metadata.keywords = ["字符串", "string", "包含", "contains", "查找", "search", "子串", "substring", "匹配", "match"]
	metadata.builtin_icon = "GuiRadioChecked"
	return metadata


# 补齐参数的属性注册——带自定义 setter 的脚本变量只有 SCRIPT_VARIABLE 位、无 STORAGE 位，
# 不注册则 Inspector 不可编辑、.tres/.tscn 序列化静默丢值、preset schema 提取器漏收录
# （同 9a90828 对 OnGroundStateChanged 的修法）
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	properties.append({
		name = "source_variable",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})
	properties.append({
		name = "search",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})
	properties.append({
		name = "case_sensitive",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})
	return properties
