@tool
@icon("res://addons/fuse/icons/builtin/LocalVariable.png")
extends BaseInstruction
class_name LoadGlobalVariables

# 静态元数据 - 指令选择器使用
static func _get_instruction_metadata() -> InstructionMetadata:
	metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_LOAD_GLOBAL_VARIABLES_NAME"
	metadata.category_key = "FUSE_CATEGORY_VARIABLES"
	metadata.description_key = "FUSE_INSTRUCTION_LOAD_GLOBAL_VARIABLES_DESC"
	metadata.keywords = ["加载", "全局", "变量", "资源", "存档", "读档", "load", "global", "variable", "resource", "save file"]
	metadata.builtin_icon = "LocalVariable"
	return metadata

## 加载来源
enum LoadSource {
	ASSISTANT_RESOURCE,  ## 使用 Assistant 配置的资源路径
	CUSTOM_PATH          ## 使用自定义路径
}

## 加载来源配置
var load_source: LoadSource = LoadSource.ASSISTANT_RESOURCE:
	set(value):
		load_source = value
		_update_resource_name()
		notify_property_list_changed()

## 自定义资源路径（仅当 load_source == CUSTOM_PATH 时使用）
var custom_path: String = "":
	set(value):
		custom_path = value
		_update_resource_name()

## 运行时检测到的 Assistant 实例
var detected_assistant: GlobalVariableAssistant = null

func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	properties.append({
		name = "Load Source Configuration",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "load_source",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Assistant Resource,Custom Path",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if load_source == LoadSource.CUSTOM_PATH:
		properties.append({
			name = "custom_path",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_FILE,
			hint_string = "*.tres",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

	return properties

## 条件化属性显示
func _validate_property(property: Dictionary) -> void:
	if property.name == "custom_path" and load_source != LoadSource.CUSTOM_PATH:
		property.usage = PROPERTY_USAGE_NO_EDITOR

func execute(context: ExecutionContext):
	_start_execution(context)

	# 1. 检测并验证 Assistant
	if not _detect_and_validate_assistant():
		finished.emit()
		return

	# 2. 确定加载路径
	var resolved_path: String = _resolve_path()
	if resolved_path.is_empty():
		finished.emit()
		return

	# 3. 通过 Manager 执行加载
	var manager = GlobalVariableManager.get_instance()
	if manager == null:
		_log_error_localized("FUSE_ERROR_GLOBAL_VAR_MANAGER_NOT_FOUND", {})
		set_error_localized("FUSE_ERROR_GLOBAL_VAR_MANAGER_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		finished.emit()
		return

	var success = manager.load_from_resource(resolved_path)

	if success:
		var var_count = manager.get_variable_count()
		_log_info_localized("FUSE_LOG_GLOBAL_VARS_LOADED", {"count": var_count})
	else:
		_log_error_localized("FUSE_ERROR_RESOURCE_LOAD_FAILED", {"path": resolved_path})
		set_error_localized("FUSE_ERROR_RESOURCE_LOAD_FAILED", FuseError.ErrorType.RUNTIME_ERROR, {"path": resolved_path})

	finished.emit()

## 检测并验证 GlobalVariableAssistant
func _detect_and_validate_assistant() -> bool:
	detected_assistant = GlobalVariableAssistant.get_instance()
	if detected_assistant == null:
		_log_error_localized("FUSE_ERROR_ASSISTANT_NOT_FOUND", {})
		set_error_localized("FUSE_ERROR_ASSISTANT_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return false

	if not is_instance_valid(detected_assistant):
		detected_assistant = null
		_log_error_localized("FUSE_ERROR_ASSISTANT_NOT_FOUND", {})
		set_error_localized("FUSE_ERROR_ASSISTANT_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return false

	return true

## 根据加载来源解析路径
func _resolve_path() -> String:
	match load_source:
		LoadSource.ASSISTANT_RESOURCE:
			if detected_assistant.resource_path.is_empty():
				_log_error_localized("FUSE_ERROR_RESOURCE_PATH_NOT_CONFIGURED", {})
				set_error_localized("FUSE_ERROR_RESOURCE_PATH_NOT_CONFIGURED", FuseError.ErrorType.CONFIGURATION_ERROR, {})
				return ""
			return detected_assistant.resource_path

		LoadSource.CUSTOM_PATH:
			if custom_path.is_empty():
				_log_error_localized("FUSE_ERROR_RESOURCE_PATH_NOT_CONFIGURED", {})
				set_error_localized("FUSE_ERROR_RESOURCE_PATH_NOT_CONFIGURED", FuseError.ErrorType.VALIDATION_ERROR, {})
				return ""
			return custom_path

		_:
			return ""

func _update_resource_name():
	var parts: Array[String] = []

	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_LOAD_GLOBAL_VARIABLES_RESOURCE"))

	match load_source:
		LoadSource.ASSISTANT_RESOURCE:
			parts.append("[%s]" % FuseLocalization.translate("FUSE_GLOBAL_VARS_TARGET_ASSISTANT"))
		LoadSource.CUSTOM_PATH:
			parts.append("[%s]" % FuseLocalization.translate("FUSE_GLOBAL_VARS_TARGET_CUSTOM"))
			if not custom_path.is_empty():
				var display_path = FuseNodeUtils.get_path_display_name(custom_path)
				parts.append("'%s'" % display_path)
			else:
				parts.append(FuseLocalization.translate("FUSE_ERROR_RESOURCE_PATH_NOT_CONFIGURED"))

	resource_name = " ".join(parts)

func validate() -> Array[String]:
	var errors = super.validate()

	if load_source == LoadSource.CUSTOM_PATH and custom_path.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_RESOURCE_PATH_NOT_CONFIGURED"))

	return errors

func get_description() -> String:
	var source_str: String
	match load_source:
		LoadSource.ASSISTANT_RESOURCE:
			source_str = FuseLocalization.translate("FUSE_GLOBAL_VARS_TARGET_ASSISTANT")
		LoadSource.CUSTOM_PATH:
			source_str = "'%s'" % FuseNodeUtils.get_path_display_name(custom_path) if not custom_path.is_empty() else FuseLocalization.translate("FUSE_ERROR_RESOURCE_PATH_NOT_CONFIGURED")
		_:
			source_str = ""

	return FuseLocalization.translate_format("FUSE_GLOBAL_VARS_LOAD_FROM", {"source": source_str})

func _cleanup_resources():
	super._cleanup_resources()
	detected_assistant = null

func reset():
	super.reset()
	detected_assistant = null
