@tool
@icon("res://addons/fuse/icons/builtin/LocalVariable.png")
extends BaseInstruction
class_name GetScopeVariable

## 获取作用域变量指令
## 从指定的作用域容器中获取变量值，并存储到本地变量

# 预加载工具类

# 关键：实现这个静态方法，用于指令选择器
static func _get_instruction_metadata() -> InstructionMetadata:
	metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_GET_SCOPE_VARIABLE_NAME"
	metadata.category_key = "FUSE_CATEGORY_SCOPE_VARIABLES"
	metadata.description_key = "FUSE_INSTRUCTION_GET_SCOPE_VARIABLE_DESC"
	metadata.keywords = ["作用域", "变量", "获取", "读取", "scope", "variable", "get", "read"]
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
@export var source_variable_name: String = "":
	set(value):
		source_variable_name = value
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

## 目标变量（存储到ExecutionContext的local变量）
@export var target_variable: String = "":
	set(value):
		target_variable = value
		_update_resource_name()

## 默认值
@export var default_value: Variant:
	set(value):
		default_value = value
		_update_resource_name()

## 缓存的作用域容器
var _cached_scope_container: ScopeVariableContainer = null

func _setup_metadata():
	pass

func execute(context: ExecutionContext):
	_start_execution(context)

	# 参数验证
	if source_variable_name.is_empty():
		_log_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", {})
		set_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	if target_variable.is_empty():
		_log_error_localized("FUSE_ERROR_TARGET_VAR_NAME_EMPTY", {})
		set_error_localized("FUSE_ERROR_TARGET_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 获取作用域容器
	var scope_container = _get_scope_container_via_operations(context)
	var value = default_value

	if scope_container != null:
		# 从作用域容器获取变量
		if scope_container.has_variable(source_variable_name):
			value = scope_container.get_variable(source_variable_name, default_value)
			_log_debug_localized("FUSE_LOG_SCOPE_VAR_FOUND", {
				"scope": scope_container.scope_id,
				"variable": source_variable_name,
				"value": str(value)
			})
		else:
			_log_debug_localized("FUSE_LOG_SCOPE_VAR_NOT_FOUND", {
				"scope": scope_container.scope_id,
				"variable": source_variable_name
			})
	else:
		_log_debug_localized("FUSE_LOG_SCOPE_VAR_NOT_FOUND", {"scope": "default"})

	# 使用 VariableOperations 存储到本地变量
	var success = VariableOperations.set_variable(context, target_variable, BaseVariable.VariableScope.LOCAL, value)
	if not success:
		_log_error_localized("FUSE_ERROR_SET_LOCAL_VARIABLE_FAILED", {"name": target_variable})
		set_error_localized("FUSE_ERROR_SET_LOCAL_VARIABLE_FAILED", FuseError.ErrorType.RUNTIME_ERROR, {"name": target_variable})
		finished.emit()
		return

	# 记录成功信息
	_log_info_localized("FUSE_LOG_GET_SCOPE_VARIABLE", {
		"source": source_variable_name,
		"target": target_variable,
		"value": str(value)
	})

	_on_execution_completed()

## 获取作用域容器（使用 VariableOperations 工具类）
func _get_scope_container_via_operations(context: ExecutionContext) -> ScopeVariableContainer:
	var manager = ScopeVariableManager.get_instance()
	if manager == null:
		_log_error_localized("FUSE_ERROR_SCOPE_MANAGER_NOT_FOUND", {})
		return null

	match scope_source:
		ScopeSource.NEAREST:
			# 使用工具类查找最近的作用域
			return VariableOperations.get_scope_container(context)

		ScopeSource.CUSTOM_ID:
			if custom_scope_id.is_empty():
				_log_warning_localized("FUSE_WARNING_SCOPE_ID_EMPTY", {})
				return null
			return manager.get_scope_by_id(custom_scope_id)

		ScopeSource.TRIGGER_SCOPE:
			if context.trigger != null:
				return VariableOperations.get_scope_container(context, context.trigger)
			return null

		ScopeSource.TARGET_NODE:
			if target_node_path.is_empty():
				_log_warning_localized("FUSE_WARNING_TARGET_NODE_PATH_EMPTY", {})
				return null
			var node = context.get_node(target_node_path)
			if node == null:
				_log_warning_localized("FUSE_WARNING_NODE_NOT_FOUND", {"path": str(target_node_path)})
				return null
			# 使用工具类从目标节点查找作用域
			return VariableOperations.get_scope_container(context, node)

	return null

func _update_resource_name():
	var parts = []

	# 基础信息
	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_GET_SCOPE_VARIABLE_RESOURCE"))

	# 作用域来源信息
	var scope_str = _get_scope_source_string()
	parts.append("[%s]" % scope_str)

	# 源变量名称
	if not source_variable_name.is_empty():
		parts.append("'%s'" % source_variable_name)
	else:
		parts.append(FuseLocalization.translate("FUSE_VARIABLE_UNNAMED"))

	# 箭头
	parts.append("→")

	# 目标变量名称
	if not target_variable.is_empty():
		parts.append("'%s'" % target_variable)
	else:
		parts.append(FuseLocalization.translate("FUSE_VARIABLE_UNNAMED"))

	# 默认值
	parts.append("(默认: %s)" % str(default_value))

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
			return "节点:%s" % target_node_path
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

	if source_variable_name.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_SOURCE_VAR_NAME_EMPTY"))

	if target_variable.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_VAR_NAME_EMPTY"))

	if scope_source == ScopeSource.CUSTOM_ID and custom_scope_id.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_SCOPE_ID_EMPTY"))

	if scope_source == ScopeSource.TARGET_NODE and target_node_path.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_PATH_EMPTY"))

	return errors

func get_description() -> String:
	var scope_str = _get_scope_source_string()
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_GET_SCOPE_VARIABLE_DESC_FORMAT", {
		"source": source_variable_name if not source_variable_name.is_empty() else FuseLocalization.translate("FUSE_VARIABLE_UNNAMED"),
		"target": target_variable if not target_variable.is_empty() else FuseLocalization.translate("FUSE_VARIABLE_UNNAMED"),
		"scope": scope_str,
		"default": str(default_value)
	})

func _cleanup_resources():
	super._cleanup_resources()
	_cached_scope_container = null
	_log_debug_localized("FUSE_LOG_CLEANUP_COMPLETE", {"component": "GetScopeVariable"})

func reset():
	super.reset()
	_cached_scope_container = null
	_log_debug_localized("FUSE_LOG_RESET_COMPLETE", {"component": "GetScopeVariable"})

## 统一日志方法
func _log_debug(message: String):
	FuseLogger.log_debug("GetScopeVariable", log_level, message, source_variable_name)

func _log_info(message: String):
	FuseLogger.log_info("GetScopeVariable", log_level, message, source_variable_name)

func _log_warning(message: String):
	FuseLogger.log_warning("GetScopeVariable", log_level, message, source_variable_name)

func _log_error(message: String):
	FuseLogger.log_error("GetScopeVariable", log_level, message, source_variable_name)
