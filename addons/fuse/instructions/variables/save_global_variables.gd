@tool
@icon("res://addons/fuse/icons/builtin/LocalVariable.png")
extends BaseInstruction
class_name SaveGlobalVariables

# 静态元数据 - 指令选择器使用
static func _get_instruction_metadata() -> InstructionMetadata:
	metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_SAVE_GLOBAL_VARIABLES_NAME"
	metadata.category_key = "FUSE_CATEGORY_VARIABLES"
	metadata.description_key = "FUSE_INSTRUCTION_SAVE_GLOBAL_VARIABLES_DESC"
	metadata.keywords = ["保存", "全局", "变量", "资源", "存档", "持久化", "save", "global", "variable", "resource", "persistent"]
	metadata.builtin_icon = "LocalVariable"
	return metadata

## 保存目标
enum SaveTarget {
	ASSISTANT_RESOURCE,  ## 保存到 Assistant 配置的资源路径
	CUSTOM_PATH          ## 保存到自定义路径
}

## 保存范围
enum SaveScope {
	ALL,                 ## 保存所有变量
	PERSISTENT_ONLY      ## 仅保存持久化变量
}

## 保存目标配置
var save_target: SaveTarget = SaveTarget.ASSISTANT_RESOURCE:
	set(value):
		save_target = value
		_update_resource_name()
		notify_property_list_changed()

## 自定义资源路径（仅当 save_target == CUSTOM_PATH 时使用）
var custom_path: String = "":
	set(value):
		custom_path = value
		_update_resource_name()

## 保存范围配置
var save_scope: SaveScope = SaveScope.ALL:
	set(value):
		save_scope = value
		_update_resource_name()

## 运行时检测到的 Assistant 实例
var detected_assistant: GlobalVariableAssistant = null

func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	properties.append({
		name = "Save Target Configuration",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "save_target",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Assistant Resource,Custom Path",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if save_target == SaveTarget.CUSTOM_PATH:
		properties.append({
			name = "custom_path",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_FILE,
			hint_string = "*.tres",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

	properties.append({
		name = "Save Scope Configuration",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "save_scope",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "All Variables,Persistent Only",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 条件化属性显示
func _validate_property(property: Dictionary) -> void:
	if property.name == "custom_path" and save_target != SaveTarget.CUSTOM_PATH:
		property.usage = PROPERTY_USAGE_NO_EDITOR

func execute(context: ExecutionContext):
	_start_execution(context)

	# 1. 检测并验证 Assistant
	if not _detect_and_validate_assistant():
		finished.emit()
		return

	# 2. 确定保存路径
	var resolved_path: String = _resolve_path()
	if resolved_path.is_empty():
		finished.emit()
		return

	# 3. 通过 Manager 执行保存
	var manager = GlobalVariableManager.get_instance()
	if manager == null:
		_log_error_localized("FUSE_ERROR_GLOBAL_VAR_MANAGER_NOT_FOUND", {})
		set_error_localized("FUSE_ERROR_GLOBAL_VAR_MANAGER_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		finished.emit()
		return

	var success: bool
	match save_scope:
		SaveScope.ALL:
			success = manager.save_to_resource(resolved_path)
		SaveScope.PERSISTENT_ONLY:
			success = manager.save_persistent_to_resource(resolved_path)
		_:
			success = false

	if success:
		var var_count = manager.get_variable_count()
		if save_scope == SaveScope.PERSISTENT_ONLY:
			_log_info_localized("FUSE_LOG_GLOBAL_VARS_PERSISTENT_SAVED", {"count": var_count})
		else:
			_log_info_localized("FUSE_LOG_GLOBAL_VARS_SAVED", {"count": var_count})
	else:
		_log_error_localized("FUSE_ERROR_RESOURCE_SAVE_FAILED", {"path": resolved_path})
		set_error_localized("FUSE_ERROR_RESOURCE_SAVE_FAILED", FuseError.ErrorType.RUNTIME_ERROR, {"path": resolved_path})

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

## 根据保存目标解析路径
func _resolve_path() -> String:
	match save_target:
		SaveTarget.ASSISTANT_RESOURCE:
			if detected_assistant.resource_path.is_empty():
				_log_error_localized("FUSE_ERROR_RESOURCE_PATH_NOT_CONFIGURED", {})
				set_error_localized("FUSE_ERROR_RESOURCE_PATH_NOT_CONFIGURED", FuseError.ErrorType.CONFIGURATION_ERROR, {})
				return ""
			return detected_assistant.resource_path

		SaveTarget.CUSTOM_PATH:
			if custom_path.is_empty():
				_log_error_localized("FUSE_ERROR_RESOURCE_PATH_NOT_CONFIGURED", {})
				set_error_localized("FUSE_ERROR_RESOURCE_PATH_NOT_CONFIGURED", FuseError.ErrorType.VALIDATION_ERROR, {})
				return ""
			return custom_path

		_:
			return ""

func _update_resource_name():
	var parts: Array[String] = []

	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_SAVE_GLOBAL_VARIABLES_RESOURCE"))

	# 目标
	match save_target:
		SaveTarget.ASSISTANT_RESOURCE:
			parts.append("[%s]" % FuseLocalization.translate("FUSE_GLOBAL_VARS_TARGET_ASSISTANT"))
		SaveTarget.CUSTOM_PATH:
			parts.append("[%s]" % FuseLocalization.translate("FUSE_GLOBAL_VARS_TARGET_CUSTOM"))
			if not custom_path.is_empty():
				parts.append("'%s'" % FuseNodeUtils.get_path_display_name(custom_path))
			else:
				parts.append(FuseLocalization.translate("FUSE_ERROR_RESOURCE_PATH_NOT_CONFIGURED"))

	# 范围
	match save_scope:
		SaveScope.ALL:
			parts.append("[%s]" % FuseLocalization.translate("FUSE_GLOBAL_VARS_SCOPE_ALL"))
		SaveScope.PERSISTENT_ONLY:
			parts.append("[%s]" % FuseLocalization.translate("FUSE_GLOBAL_VARS_SCOPE_PERSISTENT"))

	resource_name = " ".join(parts)

func validate() -> Array[String]:
	var errors = super.validate()

	if save_target == SaveTarget.CUSTOM_PATH and custom_path.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_RESOURCE_PATH_NOT_CONFIGURED"))

	return errors

func get_description() -> String:
	var target_str: String
	match save_target:
		SaveTarget.ASSISTANT_RESOURCE:
			target_str = FuseLocalization.translate("FUSE_GLOBAL_VARS_TARGET_ASSISTANT")
		SaveTarget.CUSTOM_PATH:
			target_str = "'%s'" % FuseNodeUtils.get_path_display_name(custom_path) if not custom_path.is_empty() else FuseLocalization.translate("FUSE_ERROR_RESOURCE_PATH_NOT_CONFIGURED")
		_:
			target_str = ""

	var scope_str: String
	match save_scope:
		SaveScope.ALL:
			scope_str = FuseLocalization.translate("FUSE_GLOBAL_VARS_SCOPE_ALL")
		SaveScope.PERSISTENT_ONLY:
			scope_str = FuseLocalization.translate("FUSE_GLOBAL_VARS_SCOPE_PERSISTENT")
		_:
			scope_str = ""

	return "%s [%s]" % [
		FuseLocalization.translate_format("FUSE_GLOBAL_VARS_SAVE_TO", {"target": target_str}),
		scope_str
	]

func _cleanup_resources():
	super._cleanup_resources()
	detected_assistant = null

func reset():
	super.reset()
	detected_assistant = null
