@tool
@icon("res://addons/fuse/icons/builtin/LocalVariable.png")
extends BaseInstruction
class_name SetScopeVariable

## 设置作用域变量指令
## 在指定的作用域容器中设置变量值

# 预加载工具类

# 关键：实现这个静态方法，用于指令选择器
static func _get_instruction_metadata() -> InstructionMetadata:
	metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_SET_SCOPE_VARIABLE_NAME"
	metadata.category_key = "FUSE_CATEGORY_SCOPE_VARIABLES"
	metadata.description_key = "FUSE_INSTRUCTION_SET_SCOPE_VARIABLE_DESC"
	metadata.keywords = ["作用域", "变量", "设置", "赋值", "scope", "variable", "set", "assign"]
	# 设置指令选择器图标
	metadata.builtin_icon = "LocalVariable"
	return metadata

## 作用域来源
enum ScopeSource {
	NEAREST,        # 最近的作用域容器（默认）
	CUSTOM_ID,      # 指定 scope_id
	TRIGGER_SCOPE,  # Trigger 节点上的作用域
	TARGET_NODE     # Target 节点上的作用域
}

## 基础属性
@export var variable_name: String = "":
	set(value):
		variable_name = value
		_update_resource_name()

@export var scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		scope_source = value
		_update_resource_name()
		notify_property_list_changed()

## 条件属性
@export var custom_scope_id: String = "":
	set(value):
		custom_scope_id = value
		_update_resource_name()

@export var target_node_path: NodePath = NodePath(""):
	set(value):
		target_node_path = value
		_update_resource_name()

## 新值
@export var new_value: Variant:
	set(value):
		new_value = value
		_update_resource_name()

## 缓存的作用域容器
var _cached_scope_container: ScopeVariableContainer = null

func _setup_metadata():
	pass

func execute(context: ExecutionContext):
	_start_execution(context)

	# 参数验证
	if variable_name.is_empty():
		_log_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", {})
		set_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 使用工具类获取作用域容器
	var scope_container: ScopeVariableContainer = null

	match scope_source:
		ScopeSource.NEAREST:
			scope_container = VariableOperations.get_scope_container(context)

		ScopeSource.CUSTOM_ID:
			if custom_scope_id.is_empty():
				_log_warning_localized("FUSE_WARNING_SCOPE_ID_EMPTY", {})
			else:
				var manager = ScopeVariableManager.get_instance()
				if manager != null:
					scope_container = manager.get_scope_by_id(custom_scope_id)

		ScopeSource.TRIGGER_SCOPE:
			scope_container = VariableOperations.get_scope_container(context, context.trigger)

		ScopeSource.TARGET_NODE:
			if not target_node_path.is_empty():
				var node = context.get_node(target_node_path)
				if node != null:
					scope_container = VariableOperations.get_scope_container(context, node)
			else:
				_log_warning_localized("FUSE_WARNING_TARGET_NODE_PATH_EMPTY", {})

	if scope_container == null:
		_log_error_localized("FUSE_ERROR_SCOPE_CONTAINER_NOT_FOUND", {})
		set_error_localized("FUSE_ERROR_SCOPE_CONTAINER_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	# 设置变量
	var success = scope_container.set_variable(variable_name, new_value)
	if not success:
		_log_error_localized("FUSE_ERROR_SET_SCOPE_VARIABLE_FAILED", {"name": variable_name})
		set_error_localized("FUSE_ERROR_SET_SCOPE_VARIABLE_FAILED", FuseError.ErrorType.RUNTIME_ERROR, {"name": variable_name})
		finished.emit()
		return

	# 记录成功信息
	_log_info_localized("FUSE_LOG_SET_SCOPE_VARIABLE", {
		"name": variable_name,
		"value": str(new_value),
		"scope_id": scope_container.scope_id
	})

	_on_execution_completed()

func _update_resource_name():
	var parts = []

	# 基础信息
	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_SET_SCOPE_VARIABLE_RESOURCE"))

	# 作用域来源信息
	var scope_str = _get_scope_source_string()
	parts.append("[%s]" % scope_str)

	# 变量名称
	if not variable_name.is_empty():
		parts.append("'%s'" % variable_name)
	else:
		parts.append(FuseLocalization.translate("FUSE_VARIABLE_UNNAMED"))

	# 设置值
	var value_str = str(new_value)
	if value_str.length() > 15:
		value_str = value_str.substr(0, 12) + "..."
	parts.append("= %s" % value_str)

	# 组合最终名称
	resource_name = " ".join(parts)

## 获取作用域来源字符串
func _get_scope_source_string() -> String:
	match scope_source:
		ScopeSource.NEAREST:
			return FuseLocalization.translate("FUSE_SCOPE_SOURCE_NEAREST_STR")
		ScopeSource.CUSTOM_ID:
			if custom_scope_id.is_empty():
				return FuseLocalization.translate("FUSE_SCOPE_SOURCE_CUSTOM_ID_UNSET")
			return "ID:%s" % custom_scope_id
		ScopeSource.TRIGGER_SCOPE:
			return FuseLocalization.translate("FUSE_SCOPE_SOURCE_TRIGGER_SCOPE_STR")
		ScopeSource.TARGET_NODE:
			if target_node_path.is_empty():
				return FuseLocalization.translate("FUSE_SCOPE_SOURCE_TARGET_NODE_UNSET")
			return "%s:%s" % [FuseLocalization.translate("FUSE_SCOPE_SOURCE_TARGET_NODE_STR"), target_node_path]
		_:
			return FuseLocalization.translate("FUSE_SCOPE_SOURCE_UNKNOWN")

func _validate_property(property: Dictionary) -> void:
	# 根据 scope_source 控制属性可见性
	match scope_source:
		ScopeSource.CUSTOM_ID:
			if property.name == "target_node_path":
				property.usage = PROPERTY_USAGE_NO_EDITOR
		ScopeSource.TARGET_NODE:
			if property.name == "custom_scope_id":
				property.usage = PROPERTY_USAGE_NO_EDITOR
		_:
			# NEAREST 和 TRIGGER_SCOPE 不需要这两个参数
			if property.name == "custom_scope_id" or property.name == "target_node_path":
				property.usage = PROPERTY_USAGE_NO_EDITOR

func validate() -> Array[String]:
	var errors = super.validate()

	if variable_name.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_VAR_NAME_EMPTY"))

	if scope_source == ScopeSource.CUSTOM_ID and custom_scope_id.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_SCOPE_ID_EMPTY"))

	if scope_source == ScopeSource.TARGET_NODE and target_node_path.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_PATH_EMPTY"))

	return errors

func get_description() -> String:
	var scope_str = _get_scope_source_string()
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_SCOPE_VARIABLE_DESC_FORMAT", {
		"variable": variable_name if not variable_name.is_empty() else FuseLocalization.translate("FUSE_VARIABLE_UNNAMED"),
		"scope": scope_str,
		"value": str(new_value)
	})

func _cleanup_resources():
	super._cleanup_resources()
	_cached_scope_container = null
	_log_debug("SetScopeVariable 资源清理完成")

func reset():
	super.reset()
	_cached_scope_container = null
	_log_debug("SetScopeVariable 状态已重置")

## 统一日志方法
func _log_debug(message: String):
	FuseLogger.log_debug("SetScopeVariable", log_level, message, variable_name)

func _log_info(message: String):
	FuseLogger.log_info("SetScopeVariable", log_level, message, variable_name)

func _log_warning(message: String):
	FuseLogger.log_warning("SetScopeVariable", log_level, message, variable_name)

func _log_error(message: String):
	FuseLogger.log_error("SetScopeVariable", log_level, message, variable_name)
