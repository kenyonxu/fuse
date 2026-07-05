@tool
@icon("res://addons/fuse/icons/builtin/String.svg")
extends BaseInstruction
class_name StringFormat

## String Format 指令 - 使用变量值格式化字符串模板
##
## 解析模板中的 {var_name} 占位符，从上下文查找变量值替换，结果保存到变量。
## RPG 对话/HUD 文本必备。

## 模板字符串，用 {var_name} 占位
var template: String = "":
	set(value):
		template = value
		_update_resource_name()

## 结果保存到的变量名
var save_to_variable: String = "":
	set(value):
		save_to_variable = value
		_update_resource_name()

## 获取指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_STRING_FORMAT_NAME"
	metadata.category_key = "FUSE_CATEGORY_STRING"
	metadata.description_key = "FUSE_INSTRUCTION_STRING_FORMAT_DESC"
	metadata.keywords = ["字符串", "string", "格式化", "format", "模板", "template", "文本", "text", "对话", "dialogue", "HUD"]
	metadata.builtin_icon = "String"
	return metadata

func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties := []

	properties.append({
		name = "String Format",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "template",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_MULTILINE_TEXT,
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
	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_STRING_FORMAT_NAME"))

	if not save_to_variable.is_empty():
		parts.append("→ {0}".format([save_to_variable], "{}"))
	else:
		parts.append("[%s]" % FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED"))

	resource_name = " ".join(parts)

## 获取指令描述
func get_description() -> String:
	var tmpl = template
	if tmpl.length() > 40:
		tmpl = tmpl.substr(0, 37) + "..."
	var var_str = save_to_variable if not save_to_variable.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_STRING_FORMAT_DESC_FORMAT", {
		"template": tmpl,
		"variable": var_str
	})

## 执行指令
func execute(context: ExecutionContext) -> void:
	_start_execution(context)

	if template.is_empty():
		_log_error_localized("FUSE_ERROR_TEMPLATE_EMPTY", {})
		set_error_localized("FUSE_ERROR_TEMPLATE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	if save_to_variable.is_empty():
		_log_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", {})
		set_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 解析模板中的 {var_name} 占位符
	var result = template
	var regex = RegEx.new()
	regex.compile("\\{(\\w+)\\}")
	var matches = regex.search_all(template)

	for match_obj in matches:
		var var_name = match_obj.get_string(1)
		var value = _get_variable_value(context, var_name)
		var replacement = str(value) if value != null else "{" + var_name + "}"
		result = result.replace("{" + var_name + "}", replacement)

	# 保存结果
	context.set_local(save_to_variable, result)

	_log_info_localized("FUSE_LOG_STRING_FORMAT", {
		"template": template.substr(0, 50),
		"result": result.substr(0, 50),
		"variable": save_to_variable
	})

	_on_execution_completed()

## 从上下文获取变量值
func _get_variable_value(context: ExecutionContext, var_name: String) -> Variant:
	# 按优先级查找：局部 → 全局
	var value = context.get_local(var_name)
	if value != null:
		return value

	# 尝试全局变量
	if context.global_variables and context.global_variables.has_variable(var_name):
		return context.global_variables.get_variable(var_name)

	return null

## 验证参数
func validate() -> Array[String]:
	var errors = super.validate()
	if template.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TEMPLATE_EMPTY"))
	if save_to_variable.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_VAR_NAME_EMPTY"))
	return errors
