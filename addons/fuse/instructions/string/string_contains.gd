@tool
@icon("res://addons/fuse/icons/builtin/String.svg")
extends BaseInstruction
class_name StringContainsInstruction

## String Contains 指令 - 检查字符串是否包含子串，结果保存到变量

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

## 结果保存到的变量名
var save_to_variable: String = "":
	set(value):
		save_to_variable = value
		_update_resource_name()

## 获取指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_STRING_CONTAINS_NAME"
	metadata.category_key = "FUSE_CATEGORY_STRING"
	metadata.description_key = "FUSE_INSTRUCTION_STRING_CONTAINS_DESC"
	metadata.keywords = ["字符串", "string", "包含", "contains", "查找", "search", "子串", "substring", "匹配", "match"]
	metadata.builtin_icon = "String"
	return metadata

func _setup_metadata():
	pass

## 声明变量读写模式（save_to=write, source=read）
func get_variable_modes() -> Array[Dictionary]:
	return [
		{"name": "save_to_variable", "mode": "write"},
		{"name": "source_variable", "mode": "read"},
	]

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties := []

	properties.append({
		name = "String Contains",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

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

	properties.append({
		name = "save_to_variable",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 更新资源名称
func _update_resource_name():
	var parts = []
	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_STRING_CONTAINS_NAME"))

	if not source_variable.is_empty():
		parts.append("[%s]" % source_variable)

	if not search.is_empty():
		parts.append("'{0}'".format([search], "{}"))

	resource_name = " ".join(parts)

## 获取指令描述
func get_description() -> String:
	var src = source_variable if not source_variable.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")
	var var_str = save_to_variable if not save_to_variable.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_STRING_CONTAINS_DESC_FORMAT", {
		"source": src,
		"search": search,
		"variable": var_str
	})

## 执行指令
func execute(context: ExecutionContext) -> void:
	_start_execution(context)

	if source_variable.is_empty():
		_log_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", {})
		set_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	if save_to_variable.is_empty():
		_log_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", {})
		set_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	var source: String = str(context.get_local(source_variable))
	var result: bool
	if case_sensitive:
		result = source.contains(search)
	else:
		result = source.to_lower().contains(search.to_lower())

	context.set_local(save_to_variable, result)

	_log_info_localized("FUSE_LOG_STRING_CONTAINS", {
		"source": source_variable,
		"search": search,
		"result": str(result),
		"variable": save_to_variable
	})

	_on_execution_completed()

## 验证参数
func validate() -> Array[String]:
	var errors = super.validate()
	if source_variable.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_VAR_NAME_EMPTY"))
	if save_to_variable.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_VAR_NAME_EMPTY"))
	return errors
