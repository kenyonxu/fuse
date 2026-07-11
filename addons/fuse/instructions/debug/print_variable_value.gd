@tool
@icon("res://addons/fuse/icons/builtin/FileList.png")
extends BaseInstruction
class_name PrintVariableValue

# 预加载工具类

# 关键：实现这个静态方法，用于指令选择器
static func _get_instruction_metadata() -> InstructionMetadata:
	metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_PRINT_VARIABLE_NAME"
	metadata.category_key = "FUSE_CATEGORY_DEBUG"
	metadata.description_key = "FUSE_INSTRUCTION_PRINT_VARIABLE_DESC"
	metadata.keywords = ["变量", "打印", "调试", "输出", "显示", "variable", "print", "debug", "output", "display"]
	metadata.builtin_icon = "FileList"
	return metadata

## 变量名称
var variable_name: String = "":
	set(value):
		variable_name = value
		_update_resource_name()

## 变量作用域
var variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		variable_scope = value
		_update_resource_name()
		notify_property_list_changed()

## 作用域来源枚举
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

## 作用域来源（仅当 variable_scope == SCOPE 时使用）
var scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		scope_source = value
		_update_resource_name()
		notify_property_list_changed()

## 自定义作用域 ID（CUSTOM_ID 模式使用）
var custom_scope_id: String = "":
	set(value):
		custom_scope_id = value
		_update_resource_name()

## 目标节点路径（TARGET_NODE 模式使用）
var target_node_path: NodePath = NodePath(""):
	set(value):
		target_node_path = value
		_update_resource_name()

## 设置指令元数据
func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties := []

	# Variable 分类
	properties.append({
		name = "Variable",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 变量名
	properties.append({
		name = "variable_name",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 变量作用域
	properties.append({
		name = "variable_scope",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Local,Scope,Global",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 只在 variable_scope == SCOPE 时显示 ScopeSource 配置
	if variable_scope == BaseVariable.VariableScope.SCOPE:
		properties.append({
			name = "Scope Configuration",
			type = TYPE_NIL,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_CATEGORY
		})

		properties.append({
			name = "scope_source",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 根据作用域来源添加额外属性
		if scope_source == ScopeSource.CUSTOM_ID:
			properties.append({
				name = "custom_scope_id",
				type = TYPE_STRING,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})
		elif scope_source == ScopeSource.TARGET_NODE:
			properties.append({
				name = "target_node_path",
				type = TYPE_NODE_PATH,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

	return properties

## 更新资源名称
func _update_resource_name():
	# 作用域显示
	var scope_str = _get_scope_source_string()

	# 基础资源名称
	if not variable_name.is_empty():
		resource_name = FuseLocalization.translate_format("FUSE_INSTRUCTION_PRINT_VARIABLE_RESOURCE_NAME", {
			"name": variable_name,
			"scope": scope_str
		})
	else:
		resource_name = FuseLocalization.translate_format("FUSE_INSTRUCTION_PRINT_VARIABLE_RESOURCE_NAME_UNNAMED", {
			"scope": scope_str
		})

## 获取作用域来源字符串
func _get_scope_source_string() -> String:
	match variable_scope:
		BaseVariable.VariableScope.LOCAL:
			return FuseLocalization.translate("FUSE_VARIABLE_SCOPE_LOCAL_STR")
		BaseVariable.VariableScope.GLOBAL:
			return FuseLocalization.translate("FUSE_VARIABLE_SCOPE_GLOBAL_STR")
		BaseVariable.VariableScope.SCOPE:
			return VariableScopeUtils.get_scope_source_string(
				scope_source as VariableScopeUtils.ScopeSource,
				custom_scope_id,
				target_node_path
			)
		_:
			return FuseLocalization.translate("FUSE_VARIABLE_SCOPE_UNKNOWN")

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	# 验证参数
	var errors = validate()
	if not errors.is_empty():
		_log_error_localized("FUSE_ERROR_VALIDATION_FAILED", {"errors": ", ".join(errors)})
		set_error_localized("FUSE_ERROR_VALIDATION_FAILED", FuseError.ErrorType.VALIDATION_ERROR, {"errors": ", ".join(errors)})
		finished.emit()
		return

	# 使用 VariableOperations 获取变量值
	var value = null
	match variable_scope:
		BaseVariable.VariableScope.LOCAL:
			value = VariableOperations.get_variable(context, variable_name, BaseVariable.VariableScope.LOCAL, null)
		BaseVariable.VariableScope.SCOPE:
			if scope_source == ScopeSource.NEAREST:
				value = VariableOperations.get_variable(context, variable_name, BaseVariable.VariableScope.SCOPE, null)
			else:
				var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
				var scope_container = VariableScopeUtils.get_scope_container_by_source(
					context,
					utils_scope_source,
					custom_scope_id,
					target_node_path
				)
				if scope_container == null:
					_log_error_localized("FUSE_ERROR_SCOPE_CONTAINER_NOT_FOUND", {})
					set_error_localized("FUSE_ERROR_SCOPE_CONTAINER_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {})
					finished.emit()
					return
				value = scope_container.get_variable(variable_name, null)
		BaseVariable.VariableScope.GLOBAL:
			value = VariableOperations.get_variable(context, variable_name, BaseVariable.VariableScope.GLOBAL, null)

	# 打印变量值
	_print_variable_value(value)

	_on_execution_completed()

## 打印变量值
func _print_variable_value(value: Variant):
	# 转换值为字符串
	var value_str = _convert_value_to_string(value)
	var scope_str = VariableScopeUtils.enum_to_string(variable_scope).to_upper()

	# 打印到输出窗口
	var print_message = FuseLocalization.translate_format("FUSE_LOG_VARIABLE_VALUE", {
		"name": variable_name,
		"scope": scope_str,
		"value": value_str
	})
	print(print_message)

	_log_info_localized("FUSE_LOG_PRINTING_VARIABLE", {"name": variable_name, "value": str(value)})

## 转换值为字符串
func _convert_value_to_string(value: Variant) -> String:
	if value == null:
		return "null"

	# 特殊处理 BaseVariable 对象
	if value is BaseVariable:
		var variable = value as BaseVariable
		var actual_value = variable.value
		return _convert_actual_value_to_string(actual_value)

	var type_name = typeof(value)
	match type_name:
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "true" if value else "false"
		TYPE_INT:
			return str(value)
		TYPE_FLOAT:
			return str(value)
		TYPE_STRING:
			return '"%s"' % value
		TYPE_VECTOR2:
			return "Vector2(%.2f, %.2f)" % [value.x, value.y]
		TYPE_VECTOR3:
			return "Vector3(%.2f, %.2f, %.2f)" % [value.x, value.y, value.z]
		TYPE_COLOR:
			return "Color(%.2f, %.2f, %.2f, %.2f)" % [value.r, value.g, value.b, value.a]
		TYPE_ARRAY:
			return str(value)
		TYPE_DICTIONARY:
			return str(value)
		TYPE_OBJECT:
			if value is BaseVariable:
				return "BaseVariable(%s)" % value.variable_name
			else:
				return "Object(%s)" % value.get_class()
		_:
			return str(value)

## 转换实际值为字符串（处理从 BaseVariable 提取的值）
func _convert_actual_value_to_string(value: Variant) -> String:
	if value == null:
		return "null"

	var type_name = typeof(value)
	match type_name:
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "true" if value else "false"
		TYPE_INT:
			return str(value)
		TYPE_FLOAT:
			return str(value)
		TYPE_STRING:
			return '"%s"' % value
		TYPE_VECTOR2:
			return "Vector2(%.2f, %.2f)" % [value.x, value.y]
		TYPE_VECTOR3:
			return "Vector3(%.2f, %.2f, %.2f)" % [value.x, value.y, value.z]
		TYPE_COLOR:
			return "Color(%.2f, %.2f, %.2f, %.2f)" % [value.r, value.g, value.b, value.a]
		TYPE_ARRAY:
			return str(value)
		TYPE_OBJECT:
			return "Object(%s)" % value.get_class()
		_:
			return str(value)

## 声明变量读写模式（精确化静态分析）
func get_variable_modes() -> Array[Dictionary]:
	return [
		{"name": "variable_name", "mode": "read"},
	]

## 获取指令描述
func get_description() -> String:
	var desc_parts = []

	# 基础描述
	if not variable_name.is_empty():
		desc_parts.append(FuseLocalization.translate_format(
			"FUSE_INSTRUCTION_PRINT_VARIABLE_DESC_WITH_NAME",
			{"name": variable_name}
		))
	else:
		desc_parts.append(FuseLocalization.translate_format(
			"FUSE_INSTRUCTION_PRINT_VARIABLE_DESC_BASE",
			{}
		))
		desc_parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_PRINT_VARIABLE_DESC_NO_NAME"))

	# 作用域信息
	var scope_str = VariableScopeUtils.enum_to_string(variable_scope).to_upper()
	desc_parts.append("[%s]" % scope_str)

	return ", ".join(desc_parts)

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()

	# 验证变量名称
	if variable_name.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_VAR_NAME_EMPTY"))

	# 验证 SCOPE 作用域需要 ScopeVariableManager
	if variable_scope == BaseVariable.VariableScope.SCOPE:
		var manager = ScopeVariableManager.get_instance()
		if manager == null:
			errors.append(FuseLocalization.translate("FUSE_ERROR_SCOPE_MANAGER_NOT_FOUND"))

		# 验证 ScopeSource 参数
		var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
		errors.append_array(VariableScopeUtils.validate_scope_source_params(
			utils_scope_source,
			custom_scope_id,
			target_node_path
		))

	return errors

## 验证属性可见性
func _validate_property(property: Dictionary) -> void:
	# 只在 SCOPE 作用域时验证 ScopeSource 相关属性
	if variable_scope == BaseVariable.VariableScope.SCOPE:
		VariableScopeUtils.validate_scope_source_property(property, scope_source as VariableScopeUtils.ScopeSource)
	else:
		# 非 SCOPE 作用域时隐藏 ScopeSource 相关属性
		if property.name in ["scope_source", "custom_scope_id", "target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR

## 取消指令执行
func cancel():
	if is_running():
		_log_debug("取消打印变量值指令")
		super.cancel()

## 资源清理
func _cleanup_resources():
	super._cleanup_resources()
	_log_debug("PrintVariableValueInstruction 资源清理完成")

## 重置指令状态
func reset():
	super.reset()
	_log_debug("PrintVariableValueInstruction 状态已重置")

## 统一日志方法
func _log_debug(message: String):
	FuseLogger.log_debug("PrintVariableValueInstruction", log_level, message, variable_name)

func _log_info(message: String):
	FuseLogger.log_info("PrintVariableValueInstruction", log_level, message, variable_name)

func _log_warning(message: String):
	FuseLogger.log_warning("PrintVariableValueInstruction", log_level, message, variable_name)

func _log_error(message: String):
	FuseLogger.log_error("PrintVariableValueInstruction", log_level, message, variable_name)
