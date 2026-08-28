@tool
@icon("res://addons/fuse/icons/builtin/ResourcePreloader.svg")
extends BaseInstruction
class_name LoadResourceByPath

## Load Resource By Path 指令 - 按文件路径加载 Resource 并保存到变量

## 资源文件路径（如 "res://scenes/player.tscn"）
var load_path: String = "":
	set(value):
		load_path = value
		_update_resource_name()

## 结果保存到的变量名
var save_to_variable: String = "":
	set(value):
		save_to_variable = value
		_update_resource_name()

## 获取指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_LOAD_RESOURCE_NAME"
	metadata.category_key = "FUSE_CATEGORY_SYSTEM"
	metadata.description_key = "FUSE_INSTRUCTION_LOAD_RESOURCE_DESC"
	metadata.keywords = ["资源", "resource", "加载", "load", "路径", "path", "文件", "file", "预加载", "preload"]
	metadata.builtin_icon = "ResourcePreloader"
	return metadata

func _setup_metadata():
	pass

## 声明变量读写模式（save_to=write）
func get_variable_modes() -> Array[Dictionary]:
	return [{"name": "save_to_variable", "mode": "write"}]

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	properties.append({
		name = "Load Resource",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "load_path",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_FILE,
		hint_string = "*.tscn,*.gd,*.res,*.tres,*.png,*.jpg,*.ogg,*.wav,*.mp3",
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
	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_LOAD_RESOURCE_NAME"))

	if not load_path.is_empty():
		var filename = load_path.get_file()
		parts.append("[%s]" % filename)
	else:
		parts.append("[%s]" % FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED"))

	if not save_to_variable.is_empty():
		parts.append("→ {0}".format([save_to_variable], "{}"))

	resource_name = " ".join(parts)

## 获取指令描述
func get_description() -> String:
	var path_str = load_path if not load_path.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")
	var var_str = save_to_variable if not save_to_variable.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_LOAD_RESOURCE_DESC_FORMAT", {
		"path": path_str,
		"variable": var_str
	})

## 执行指令
func execute(context: ExecutionContext) -> void:
	_start_execution(context)

	if load_path.is_empty():
		_log_error_localized("FUSE_ERROR_RESOURCE_PATH_EMPTY", {})
		set_error_localized("FUSE_ERROR_RESOURCE_PATH_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	if save_to_variable.is_empty():
		_log_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", {})
		set_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	if not ResourceLoader.exists(load_path):
		_log_error_localized("FUSE_ERROR_RESOURCE_NOT_FOUND", {"path": load_path})
		set_error_localized("FUSE_ERROR_RESOURCE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"path": load_path})
		finished.emit()
		return

	var resource = ResourceLoader.load(load_path)
	context.set_variable(save_to_variable, resource)

	_log_info_localized("FUSE_LOG_RESOURCE_LOADED", {
		"path": load_path,
		"variable": save_to_variable
	})

	_on_execution_completed()

## 验证参数
func validate() -> Array[String]:
	var errors = super.validate()
	if load_path.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_RESOURCE_PATH_EMPTY"))
	if save_to_variable.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_VAR_NAME_EMPTY"))
	return errors
