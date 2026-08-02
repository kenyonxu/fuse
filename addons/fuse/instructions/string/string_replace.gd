@tool
@icon("res://addons/fuse/icons/builtin/String.svg")
extends BaseInstruction
class_name StringReplace

## String Replace 指令 - 在字符串中查找替换子串，结果保存回变量

## 变量名（源和目标为同一变量）
var variable_name: String = "":
	set(value):
		variable_name = value
		_update_resource_name()

## 查找的子串
var search: String = "":
	set(value):
		search = value
		_update_resource_name()

## 替换为的子串
var replace: String = "":
	set(value):
		replace = value
		_update_resource_name()

## 获取指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_STRING_REPLACE_NAME"
	metadata.category_key = "FUSE_CATEGORY_STRING"
	metadata.description_key = "FUSE_INSTRUCTION_STRING_REPLACE_DESC"
	metadata.keywords = ["字符串", "string", "替换", "replace", "查找", "search", "修改", "modify"]
	metadata.builtin_icon = "String"
	return metadata

func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	properties.append({
		name = "String Replace",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "variable_name",
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
		name = "replace",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 更新资源名称
func _update_resource_name():
	var parts = []
	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_STRING_REPLACE_NAME"))

	if not variable_name.is_empty():
		parts.append("[%s]" % variable_name)
	else:
		parts.append("[%s]" % FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED"))

	resource_name = " ".join(parts)

## 获取指令描述
func get_description() -> String:
	var var_str = variable_name if not variable_name.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_STRING_REPLACE_DESC_FORMAT", {
		"variable": var_str,
		"search": search,
		"replace": replace
	})

## 执行指令
func execute(context: ExecutionContext) -> void:
	_start_execution(context)

	if variable_name.is_empty():
		_log_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", {})
		set_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	var source: String = str(context.get_local(variable_name))
	var result = source.replace(search, replace)
	context.set_local(variable_name, result)

	_log_info_localized("FUSE_LOG_STRING_REPLACE", {
		"variable": variable_name,
		"search": search,
		"replace": replace
	})

	_on_execution_completed()

## 验证参数
func validate() -> Array[String]:
	var errors = super.validate()
	if variable_name.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_VAR_NAME_EMPTY"))
	return errors
