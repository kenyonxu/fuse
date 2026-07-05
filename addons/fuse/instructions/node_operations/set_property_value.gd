@tool
@icon("res://addons/fuse/icons/builtin/MemberProperty.png")
extends BaseInstruction
class_name SetPropertyValue

## 设置节点属性值
##
## 重构变量系统: 2026-02-09 - 使用 VariableOperations 统一变量访问

## 作用域来源枚举
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

# 调试：确保日志级别为 DEBUG
func _init():
	super._init()
	
# 关键：实现这个静态方法，用于指令选择器
static func _get_instruction_metadata() -> InstructionMetadata:
	metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_SET_PROPERTY_VALUE_NAME"
	metadata.category_key = "FUSE_CATEGORY_NODE_OPERATIONS"
	metadata.description_key = "FUSE_INSTRUCTION_SET_PROPERTY_VALUE_DESC"
	metadata.keywords = ["属性", "设置", "节点", "值", "变量", "动态", "property", "set", "node", "value", "variable", "dynamic"]
	# 设置指令选择器图标
	metadata.builtin_icon = "MemberProperty"
	return metadata

## 节点配置
var target_node: NodePath = "":
	set(value):
		target_node = value
		# 清除缓存
		_cached_properties.clear()
		_cached_node = null
		_update_target_node_info()
		_update_resource_name()
		notify_property_list_changed()

var target_property: String = "":
	set(value):
		target_property = value
		_update_property_type_info()
		_update_resource_name()
		notify_property_list_changed()  # 确保属性列表更新

## 值配置
var set_with_variable: bool = false:
	set(value):
		set_with_variable = value
		_update_resource_name()
		notify_property_list_changed()

var new_value: Variant = "Select a property type first":
	set(value):
		new_value = value
		_update_resource_name()

## 变量配置
var variable_name: String = "":
	set(value):
		variable_name = value
		_update_resource_name()

var variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		variable_scope = value
		_update_resource_name()
		notify_property_list_changed()

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
		notify_property_list_changed()

## 作用域目标节点路径（TARGET_NODE 模式使用）
var scope_target_node_path: NodePath = NodePath(""):
	set(value):
		scope_target_node_path = value
		_update_resource_name()
		notify_property_list_changed()

## 运行时状态
var _target_node_instance: Node = null
var _current_property_info: PropertyInfo = null
var _current_property_type: int = TYPE_NIL
var _current_property_hint: int = PROPERTY_HINT_NONE
var _current_property_hint_string: String = ""
var _available_properties: Array[PropertyInfo] = []

## 缓存（避免重复计算属性列表）
var _cached_properties: Array[PropertyInfo] = []
var _cached_node: Node = null

## 设置指令元数据
func _setup_metadata():
	pass



## 更新目标节点信息
func _update_target_node_info():
	_target_node_instance = null
	_available_properties = []
	_current_property_info = null

	if target_node.is_empty():
		return

	# 尝试获取节点实例（编辑器模式下）
	if Engine.is_editor_hint():
		# 使用 FuseNodeUtils 工具类获取节点
		var editor_interface = Engine.get_singleton("EditorInterface")
		if editor_interface:
			var edited_root = editor_interface.get_edited_scene_root()
			if edited_root:
				# 使用 find_node_from_resource_context 方法支持 Resource 上下文中的相对路径
				_target_node_instance = FuseNodeUtils.find_node_from_resource_context(edited_root, self, target_node)

	if _target_node_instance:
		_available_properties = _get_available_properties()
		_update_property_type_info()
		_log_debug("成功获取目标节点: " + str(target_node) + " (类型: " + _target_node_instance.get_class() + ")")
		# 通知编辑器更新属性列表
		notify_property_list_changed()
	else:
		_log_debug("无法获取目标节点: " + str(target_node))
		# 即使获取失败也要通知更新属性列表（显示提示信息）
		notify_property_list_changed()

## 更新属性类型信息
func _update_property_type_info():
	_current_property_info = null
	_current_property_type = TYPE_NIL
	_current_property_hint = PROPERTY_HINT_NONE
	_current_property_hint_string = ""

	if _target_node_instance == null or target_property.is_empty():
		return

	# 如果属性列表为空（场景加载时），先构建属性列表
	# 这确保了在保存场景后重启编辑器时，属性选择不会丢失
	if _available_properties.is_empty():
		_update_target_node_info()
	
	# 使用 PropertyManager 获取属性信息
	_current_property_info = PropertyManager.find_property(_target_node_instance, target_property)
	
	if _current_property_info != null:
		_current_property_type = _current_property_info.type
		_current_property_hint = _current_property_info.hint
		_current_property_hint_string = _current_property_info.hint_string
	else:
		_log_warning_localized("FUSE_WARNING_PROPERTY_INFO_NOT_FOUND", {
			"property": target_property
		})

## 获取可用属性列表
func _get_available_properties() -> Array[PropertyInfo]:
	# 检查缓存：如果目标节点未改变且缓存不为空，直接返回缓存
	# 这避免了重复计算属性列表，提升性能
	if _cached_node == _target_node_instance and not _cached_properties.is_empty():
		return _cached_properties

	if _target_node_instance == null:
		return []

	# 使用通用类的过滤器获取可写属性
	var properties = PropertyManager.get_writable_properties(_target_node_instance)

	# 更新缓存
	_cached_properties = properties
	_cached_node = _target_node_instance

	return properties

## 获取属性列表用于编辑器显示
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []

	# 在编辑器模式下，如果节点实例为 null 但 target_node 不为空，尝试重新获取节点
	# 这解决了场景加载顺序问题：target_node 在 _target_node_instance 之前被设置
	if Engine.is_editor_hint() and _target_node_instance == null and not target_node.is_empty():
		_update_target_node_info()

	# 添加所有导出的属性定义
	# target_node - NodePath
	properties.append({
		"name": "target_node",
		"type": TYPE_NODE_PATH,
		"hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES,
		"hint_string": "Node",
		"default": NodePath("")
	})
	
	# target_property - String with enum hint
	var enum_string = _get_property_enum_string()
	properties.append({
		"name": "target_property",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": enum_string,
		"default": ""
	})
	
	# set_with_variable - bool
	properties.append({
		"name": "set_with_variable",
		"type": TYPE_BOOL,
		"hint": PROPERTY_HINT_NONE,
		"default": false
	})
	
	# new_value - 动态类型根据选择的属性
	var new_value_property = {
		"name": "new_value",
		"type": _current_property_type,
		"hint": _current_property_hint,
		"hint_string": _current_property_hint_string,
		"default": null
	}
	properties.append(new_value_property)
	
	# variable_name - String
	properties.append({
		"name": "variable_name",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_NONE,
		"default": ""
	})
	
	# variable_scope - enum (包含三层变量体系)
	properties.append({
		"name": "variable_scope",
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Local,Scope,Global",
		"default": 0
	})

	# 只在 variable_scope == SCOPE 时显示 ScopeSource 配置
	if variable_scope == BaseVariable.VariableScope.SCOPE:
		properties.append({
			"name": "scope_source",
			"type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Nearest,Custom ID,Trigger Scope,Target Node",
			"default": 0
		})

		# 根据作用域来源添加额外属性
		if scope_source == ScopeSource.CUSTOM_ID:
			properties.append({
				"name": "custom_scope_id",
				"type": TYPE_STRING,
				"hint": PROPERTY_HINT_NONE,
				"default": ""
			})
		elif scope_source == ScopeSource.TARGET_NODE:
			properties.append({
				"name": "scope_target_node_path",
				"type": TYPE_NODE_PATH,
				"hint": PROPERTY_HINT_NONE,
				"default": NodePath("")
			})

	return properties

## 获取属性枚举字符串
func _get_property_enum_string() -> String:
	if _target_node_instance == null:
		return FuseLocalization.translate("FUSE_INSTRUCTION_SET_PROPERTY_VALUE_SELECT_NODE_FIRST")

	var property_infos = _get_available_properties()
	var property_names = []

	for prop_info in property_infos:
		property_names.append(prop_info.name)

	if property_names.is_empty():
		return FuseLocalization.translate("FUSE_INSTRUCTION_SET_PROPERTY_VALUE_NO_PROPERTIES")

	return ",".join(property_names)

## 属性验证和显示控制
func _validate_property(property: Dictionary) -> void:
	# 根据模式控制属性显示
	if not set_with_variable:
		# 直接值模式：隐藏变量相关属性
		if property.name in ["variable_name", "variable_scope", "scope_source", "custom_scope_id", "scope_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		# 变量值模式：隐藏直接值属性
		if property.name == "new_value":
			property.usage = PROPERTY_USAGE_NO_EDITOR

		# 只在 SCOPE 作用域时验证 ScopeSource 相关属性
		if variable_scope == BaseVariable.VariableScope.SCOPE:
			VariableScopeUtils.validate_scope_source_property(property, scope_source as VariableScopeUtils.ScopeSource)
		else:
			# 非 SCOPE 作用域时隐藏 ScopeSource 相关属性
			if property.name in ["scope_source", "custom_scope_id", "scope_target_node_path"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	# 验证参数
	var errors = _validate_parameters()
	if not errors.is_empty():
		_log_error_localized("FUSE_ERROR_VALIDATION_FAILED", {"errors": ", ".join(errors)})
		set_error_localized("FUSE_ERROR_VALIDATION_FAILED", FuseError.ErrorType.VALIDATION_ERROR, {"errors": ", ".join(errors)})
		finished.emit()
		return

	# 获取目标节点
	var target = _get_target_node()
	if target == null:
		_log_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(target_node)})
		set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"node": str(target_node)})
		finished.emit()
		return

	# 获取要设置的值
	var value_to_set = _get_value_to_set(context)
	if value_to_set == null and not set_with_variable:
		_log_error_localized("FUSE_ERROR_INVALID_PARAMETER", {"parameter": "value"})
		set_error_localized("FUSE_ERROR_INVALID_PARAMETER", FuseError.ErrorType.VALIDATION_ERROR, {"parameter": "value"})
		finished.emit()
		return

	# 设置属性值
	var success = _set_property_value(target, value_to_set)
	if not success:
		_log_error_localized("FUSE_ERROR_PROPERTY_NOT_WRITABLE", {"property": target_property})
		set_error_localized("FUSE_ERROR_PROPERTY_NOT_WRITABLE", FuseError.ErrorType.RUNTIME_ERROR, {"property": target_property})
		finished.emit()
		return

	_log_info_localized("FUSE_LOG_SETTING_PROPERTY", {
		"node": target.name,
		"property": target_property,
		"value": str(value_to_set)
	})

	_on_execution_completed()

## 获取目标节点
func _get_target_node() -> Node:
	# 获取场景根节点
	var scene_root = Engine.get_main_loop().current_scene

	# 使用 FuseNodeUtils 工具类查找节点
	return FuseNodeUtils.find_node_at_runtime(scene_root, target_node)

## 获取要设置的值
func _get_value_to_set(context: ExecutionContext) -> Variant:
	if set_with_variable:
		# 从变量获取值
		if variable_name.is_empty():
			_log_error_localized("FUSE_ERROR_VARIABLE_NAME_EMPTY", {})
			return null

		var value = _get_variable_value(context)
		_log_debug("从变量获取值: " + variable_name + " = " + str(value) + " (类型: " + str(typeof(value)) + ")")
		return value
	else:
		# 使用直接值
		_log_debug("使用直接值: " + str(new_value) + " (类型: " + str(typeof(new_value)) + ")")
		return new_value

## 设置属性值（使用通用类）
func _set_property_value(target: Node, value: Variant) -> bool:
	# 使用 PropertyManager 的安全设置方法
	var result = PropertyManager.set_property_safe(target, target_property, value)

	if result.success:
		_log_info_localized("FUSE_LOG_PROPERTY_SET_SUCCESS", {
			"property": target_property,
			"value": str(result.value)
		})
		return true
	else:
		_log_error_localized("FUSE_ERROR_SET_PROPERTY_FAILED", {
			"error": result.error
		})
		return false

## 获取变量值（使用 VariableOperations 统一访问）
func _get_variable_value(context: ExecutionContext) -> Variant:
	if context == null:
		_log_error_localized("FUSE_ERROR_CONTEXT_NULL", {})
		return null

	# 根据作用域类型读取变量
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
					scope_target_node_path
				)

				if scope_container == null:
					_log_error_localized("FUSE_ERROR_SCOPE_CONTAINER_NOT_FOUND", {})
					return null

				value = scope_container.get_variable(variable_name, null)

		BaseVariable.VariableScope.GLOBAL:
			value = VariableOperations.get_variable(context, variable_name, BaseVariable.VariableScope.GLOBAL, null)

	# 检查变量是否存在
	if value == null and not VariableOperations.has_variable(context, variable_name, variable_scope):
		_log_error_localized("FUSE_ERROR_VAR_NOT_FOUND", {"variable": variable_name})
		return null

	# 如果是 BaseVariable 对象，获取其值
	if value is BaseVariable:
		return value.get_value()
	else:
		# 直接返回值（SCOPE 变量可能直接返回值）
		return value

## 参数验证
func _validate_parameters() -> Array[String]:
	var errors: Array[String] = []

	# 验证目标节点路径
	if target_node.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_PATH_EMPTY"))

	# 验证目标属性
	if target_property.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_PROPERTY_CANNOT_BE_EMPTY"))
	elif _target_node_instance != null:
		if not PropertyManager.has_property(_target_node_instance, target_property):
			errors.append(FuseLocalization.translate_format("FUSE_ERROR_PROPERTY_NOT_EXIST", {
				"property": target_property
			}))
		elif not PropertyManager.is_property_writable(_target_node_instance, target_property):
			errors.append(FuseLocalization.translate_format("FUSE_ERROR_PROPERTY_NOT_WRITABLE_DETAIL", {
				"property": target_property
			}))

	# 验证值设置
	if set_with_variable:
		if variable_name.is_empty():
			errors.append(FuseLocalization.translate("FUSE_ERROR_VARIABLE_NAME_REQUIRED"))

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
				scope_target_node_path
			))
	else:
		# 验证直接值类型兼容性
		if _current_property_info != null:
			if not _is_value_compatible_with_property(new_value):
				errors.append(FuseLocalization.translate("FUSE_ERROR_VALUE_TYPE_INCOMPATIBLE"))

	return errors

## 检查值与属性类型兼容性（使用通用类）
func _is_value_compatible_with_property(value: Variant) -> bool:
	if _current_property_info == null:
		return true  # 如果没有属性信息，假设兼容
	
	return TypeConverter.is_compatible(typeof(value), _current_property_info.type)

## 更新资源名称
func _update_resource_name():
	var parts = []

	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_SET_PROPERTY_VALUE_ACTION"))

	# 目标节点信息
	if not target_node.is_empty():
		parts.append("[" + _get_node_display_name(target_node) + "]")
	else:
		parts.append("[" + FuseLocalization.translate("FUSE_INSTRUCTION_SET_PROPERTY_VALUE_NO_NODE") + "]")

	# 属性信息
	if not target_property.is_empty():
		parts.append("." + target_property)
	else:
		parts.append(".[" + FuseLocalization.translate("FUSE_INSTRUCTION_SET_PROPERTY_VALUE_NO_PROPERTY") + "]")

	# 值信息
	if set_with_variable:
		if not variable_name.is_empty():
			parts.append("= [" + variable_name + "]")
		else:
			parts.append("= [" + FuseLocalization.translate("FUSE_INSTRUCTION_SET_PROPERTY_VALUE_NO_VAR") + "]")
	else:
		var value_str = str(new_value)
		if value_str.length() > 15:
			value_str = value_str.substr(0, 12) + "..."
		parts.append("= " + value_str)

	resource_name = " ".join(parts)

## 获取指令描述
func get_description() -> String:
	var target_desc = target_node if not target_node.is_empty() else FuseLocalization.translate("FUSE_INSTRUCTION_SET_PROPERTY_VALUE_NO_NODE_SELECTED")
	var prop_desc = target_property if not target_property.is_empty() else FuseLocalization.translate("FUSE_INSTRUCTION_SET_PROPERTY_VALUE_NO_PROPERTY_SELECTED")

	if set_with_variable:
		var var_desc = variable_name if not variable_name.is_empty() else FuseLocalization.translate("FUSE_INSTRUCTION_SET_PROPERTY_VALUE_NO_VAR_SPECIFIED")
		return FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_PROPERTY_VALUE_DESC_WITH_VAR", {
			"node": target_desc,
			"property": prop_desc,
			"variable": var_desc
		})
	else:
		return FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_PROPERTY_VALUE_DESC_WITH_VALUE", {
			"node": target_desc,
			"property": prop_desc,
			"value": str(new_value)
		})

## 取消指令执行
func cancel():
	if is_running():
		_log_debug("取消设置属性值指令")
		super.cancel()

## 资源清理
func _cleanup_resources():
	super._cleanup_resources()
	_target_node_instance = null
	_current_property_info = null
	_available_properties = []
	_log_debug("SetPropertyValue 指令资源清理完成")

## 重置指令状态
func reset():
	super.reset()
	_target_node_instance = null
	_current_property_info = null
	_available_properties = []
	_log_debug("SetPropertyValue 指令状态已重置")

## 统一日志方法
func _log_debug(message: String):
	FuseLogger.log_debug("SetPropertyValue", log_level, message, target_property)

func _log_info(message: String):
	FuseLogger.log_info("SetPropertyValue", log_level, message, target_property)

func _log_warning(message: String):
	FuseLogger.log_warning("SetPropertyValue", log_level, message, target_property)

func _log_error(message: String):
	FuseLogger.log_error("SetPropertyValue", log_level, message, target_property)
