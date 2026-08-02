@tool
@icon("res://addons/fuse/icons/builtin/Bool.svg")
extends BaseInstruction
class_name ArrayContains

## ArrayContains 指令
##
## 检查数组是否包含指定元素，返回 true/false 存储到目标变量。
## 支持从变量、节点子节点或节点组获取数组。
##
## 这是只读操作，不会触发变量变化通知。
## 使用 VariableOperations 统一变量访问 API

## 作用域来源枚举
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

# 源类型
enum SourceType {
	VARIABLE,       # 数组变量
	NODE_CHILDREN,  # 节点子节点
	NODE_GROUP      # 节点组
}

# 源类型
var source_type: SourceType = SourceType.VARIABLE

# 数组变量名（当源类型为 VARIABLE 时使用）
var array_variable: String = ""

# 数组变量作用域
var array_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		if array_scope != value:
			array_scope = value
			_update_resource_name()
			notify_property_list_changed()

## 数组作用域来源（仅当 array_scope == SCOPE 时使用）
var array_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		if array_scope_source != value:
			array_scope_source = value
			_update_resource_name()
			notify_property_list_changed()

## 自定义数组作用域 ID（CUSTOM_ID 模式使用）
var array_custom_scope_id: String = "":
	set(value):
		if array_custom_scope_id != value:
			array_custom_scope_id = value
			_update_resource_name()

## 数组目标节点路径（TARGET_NODE 模式使用）
var array_target_node_path: NodePath = NodePath(""):
	set(value):
		if array_target_node_path != value:
			array_target_node_path = value
			_update_resource_name()

# 节点组名（当源类型为 NODE_GROUP 时使用）
var group_name: String = ""

# 目标节点路径（当源类型为 NODE_CHILDREN 时使用）
var target_node_path: NodePath = NodePath("")

# 搜索值（要查找的元素值）
@export var search_value: Variant:
	set(value):
		search_value = value
		_update_resource_name()

# 目标变量名（存储结果的变量）
var target_variable: String = "":
	set(value):
		target_variable = value
		_update_resource_name()

# 目标变量作用域
var target_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		if target_scope != value:
			target_scope = value
			_update_resource_name()
			notify_property_list_changed()

## 目标作用域来源（仅当 target_scope == SCOPE 时使用）
var target_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		if target_scope_source != value:
			target_scope_source = value
			_update_resource_name()
			notify_property_list_changed()

## 自定义目标作用域 ID
var target_custom_scope_id: String = "":
	set(value):
		if target_custom_scope_id != value:
			target_custom_scope_id = value
			_update_resource_name()

## 目标节点路径
var target_node_path_for_scope: NodePath = NodePath(""):
	set(value):
		if target_node_path_for_scope != value:
			target_node_path_for_scope = value
			_update_resource_name()

## 获取指令元数据（用于指令选择器）
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_ARRAY_CONTAINS_NAME"
	metadata.category_key = "FUSE_CATEGORY_ARRAYS"
	metadata.description_key = "FUSE_INSTRUCTION_ARRAY_CONTAINS_DESC"
	metadata.keywords = ["数组", "包含", "检查", "存在", "array", "contains", "has", "check"]
	metadata.builtin_icon = "Bool"
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	# Source 分类
	properties.append({
		name = "Source",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "source_type",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Variable,NodeChildren,NodeGroup",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 数组变量名（当源类型为 VARIABLE 时显示）
	if source_type == SourceType.VARIABLE:
		properties.append({
			name = "array_variable",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 数组作用域
		properties.append({
			name = "array_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 只在 array_scope == SCOPE 时显示数组 ScopeSource 配置
		if array_scope == BaseVariable.VariableScope.SCOPE:
			properties.append({
				name = "Array Scope Configuration",
				type = TYPE_NIL,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_CATEGORY
			})

			properties.append({
				name = "array_scope_source",
				type = TYPE_INT,
				hint = PROPERTY_HINT_ENUM,
				hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

			if array_scope_source == ScopeSource.CUSTOM_ID:
				properties.append({
					name = "array_custom_scope_id",
					type = TYPE_STRING,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})
			elif array_scope_source == ScopeSource.TARGET_NODE:
				properties.append({
					name = "array_target_node_path",
					type = TYPE_NODE_PATH,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})

	# 节点路径（当源类型为 NODE_CHILDREN 时显示）
	if source_type == SourceType.NODE_CHILDREN:
		properties.append({
			name = "target_node_path",
			type = TYPE_NODE_PATH,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

	# 节点组名（当源类型为 NODE_GROUP 时显示）
	if source_type == SourceType.NODE_GROUP:
		properties.append({
			name = "group_name",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

	# Search 分类
	properties.append({
		name = "Search",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "search_value",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_TYPE_STRING,
		hint_string = "Variant",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Target 分类
	properties.append({
		name = "Target Variable",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "target_variable",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "target_scope",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Local,Scope,Global",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 只在 target_scope == SCOPE 时显示目标 ScopeSource 配置
	if target_scope == BaseVariable.VariableScope.SCOPE:
		properties.append({
			name = "Target Scope Configuration",
			type = TYPE_NIL,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_CATEGORY
		})

		properties.append({
			name = "target_scope_source",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		if target_scope_source == ScopeSource.CUSTOM_ID:
			properties.append({
				name = "target_custom_scope_id",
				type = TYPE_STRING,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})
		elif target_scope_source == ScopeSource.TARGET_NODE:
			properties.append({
				name = "target_node_path_for_scope",
				type = TYPE_NODE_PATH,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

	return properties

## 更新资源名称
func _update_resource_name():
	var source_str := ""
	var target_str := ""

	# 源信息
	match source_type:
		SourceType.VARIABLE:
			if array_variable.is_empty():
				source_str = FuseLocalization.translate("FUSE_INSTRUCTION_ARRAY_ADD_NO_ARRAY")
			else:
				source_str = FuseLocalization.translate_format("FUSE_INSTRUCTION_ARRAY_ADD_ARRAY", {"name": array_variable})
		SourceType.NODE_CHILDREN:
			source_str = FuseLocalization.translate("FUSE_INSTRUCTION_ARRAY_ADD_NODE_CHILDREN")
		SourceType.NODE_GROUP:
			if group_name.is_empty():
				source_str = FuseLocalization.translate("FUSE_INSTRUCTION_ARRAY_ADD_NO_GROUP")
			else:
				source_str = FuseLocalization.translate_format("FUSE_INSTRUCTION_ARRAY_ADD_GROUP", {"name": group_name})

	# 目标信息
	if target_variable.is_empty():
		target_str = FuseLocalization.translate("FUSE_INSTRUCTION_ARRAY_ADD_NO_ELEMENT_VAR")
	else:
		target_str = target_variable

	resource_name = " ".join(["Array Contains", source_str, "→", target_str])

## 动态属性设置（支持属性刷新）
func _set(property: StringName, value: Variant) -> bool:
	if property == "source_type":
		source_type = value
		notify_property_list_changed()
		_update_resource_name()
		return true

	if property == "array_variable" or property == "group_name" or property == "target_node_path":
		_update_resource_name()
		return false

	if property == "search_value" or property == "target_variable":
		_update_resource_name()
		return false

	return false

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	_log_debug_localized("FUSE_LOG_INSTRUCTION_START", {"instruction": "ArrayContains"})

	# 获取数组
	var target_array: Array

	match source_type:
		SourceType.VARIABLE:
			# 验证数组变量名
			if array_variable.is_empty():
				_log_error_localized("FUSE_ERROR_ARRAY_VARIABLE_EMPTY", {})
				set_error_localized("FUSE_ERROR_ARRAY_VARIABLE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
				finished.emit()
				return

			# 获取数组变量
			target_array = _get_array_variable(context)

			if target_array == null:
				_log_error_localized("FUSE_ERROR_ARRAY_VARIABLE_NOT_FOUND", {"name": array_variable})
				set_error_localized("FUSE_ERROR_ARRAY_VARIABLE_NOT_FOUND", FuseError.ErrorType.VALIDATION_ERROR, {"name": array_variable})
				finished.emit()
				return

		SourceType.NODE_CHILDREN:
			# 获取节点子节点数组
			target_array = _get_node_children_array(context)

			if target_array == null:
				_log_error_localized("FUSE_ERROR_NODE_PATH_INVALID", {})
				set_error_localized("FUSE_ERROR_NODE_PATH_INVALID", FuseError.ErrorType.RUNTIME_ERROR, {})
				finished.emit()
				return

		SourceType.NODE_GROUP:
			# 验证组名
			if group_name.is_empty():
				_log_error_localized("FUSE_ERROR_GROUP_NAME_EMPTY", {})
				set_error_localized("FUSE_ERROR_GROUP_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
				finished.emit()
				return

			# 获取节点组数组
			target_array = _get_node_group_array(context)

			if target_array == null or target_array.is_empty():
				_log_warning_localized("FUSE_WARNING_GROUP_EMPTY", {"name": group_name})
				finished.emit()
				return

	# 检查数组是否为空
	if target_array.is_empty():
		_log_error_localized("FUSE_ERROR_ARRAY_EMPTY", {})
		set_error_localized("FUSE_ERROR_ARRAY_EMPTY", FuseError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	# 验证目标变量名
	if target_variable.is_empty():
		_log_error_localized("FUSE_ERROR_TARGET_VARIABLE_EMPTY", {})
		set_error_localized("FUSE_ERROR_TARGET_VARIABLE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 检查元素是否存在
	var contains_result: bool = search_value in target_array

	# 存储到目标变量
	_set_target_variable(context, contains_result)

	_log_info_localized("FUSE_LOG_ARRAY_CONTAINS", {"value": str(search_value), "result": str(contains_result), "target": target_variable})

	_on_execution_completed()

## 获取数组变量
func _get_array_variable(context: ExecutionContext) -> Variant:
	var array_value: Variant = null

	match array_scope:
		BaseVariable.VariableScope.LOCAL:
			if VariableOperations.has_variable(context, array_variable, BaseVariable.VariableScope.LOCAL):
				array_value = VariableOperations.get_variable(context, array_variable, BaseVariable.VariableScope.LOCAL, null)

		BaseVariable.VariableScope.SCOPE:
			if array_scope_source == ScopeSource.NEAREST:
				array_value = VariableOperations.get_variable(context, array_variable, BaseVariable.VariableScope.SCOPE, null)
			else:
				var utils_scope_source = array_scope_source as VariableScopeUtils.ScopeSource
				var scope_container = VariableScopeUtils.get_scope_container_by_source(
					context,
					utils_scope_source,
					array_custom_scope_id,
					array_target_node_path
				)
				if scope_container == null:
					return null
				if scope_container.has_variable(array_variable):
					array_value = scope_container.get_variable(array_variable, null)

		BaseVariable.VariableScope.GLOBAL:
			array_value = VariableOperations.get_variable(context, array_variable, BaseVariable.VariableScope.GLOBAL, null)

	if array_value is Array:
		return array_value
	elif _is_packed_array(array_value):
		return array_value  # PackedArray 也支持 has 方法

	return null

## 设置目标变量
func _set_target_variable(context: ExecutionContext, value: Variant):
	match target_scope:
		BaseVariable.VariableScope.LOCAL:
			VariableOperations.set_variable(context, target_variable, BaseVariable.VariableScope.LOCAL, value)
		BaseVariable.VariableScope.SCOPE:
			if target_scope_source == ScopeSource.NEAREST:
				VariableOperations.set_variable(context, target_variable, BaseVariable.VariableScope.SCOPE, value)
			else:
				var utils_scope_source = target_scope_source as VariableScopeUtils.ScopeSource
				var scope_container = VariableScopeUtils.get_scope_container_by_source(
					context,
					utils_scope_source,
					target_custom_scope_id,
					target_node_path_for_scope
				)
				if scope_container:
					scope_container.set_variable(target_variable, value)
		BaseVariable.VariableScope.GLOBAL:
			VariableOperations.set_variable(context, target_variable, BaseVariable.VariableScope.GLOBAL, value)
			# 注意：这是只读操作，不需要调用 _notify_global_variable_changed

## 检查是否为 PackedArray 类型
func _is_packed_array(value: Variant) -> bool:
	return value is PackedInt32Array or \
		value is PackedInt64Array or \
		value is PackedFloat32Array or \
		value is PackedFloat64Array or \
		value is PackedByteArray or \
		value is PackedVector2Array or \
		value is PackedVector3Array or \
		value is PackedColorArray or \
		value is PackedStringArray

## 获取节点子节点数组
func _get_node_children_array(context: ExecutionContext) -> Variant:
	if target_node_path.is_empty():
		return null

	var trigger = context.trigger
	if trigger == null:
		return null

	var target_node = trigger.get_node(target_node_path)
	if target_node == null:
		return null

	var children: Array = target_node.get_children()
	return children

## 获取节点组数组
func _get_node_group_array(context: ExecutionContext) -> Variant:
	var node_tree = context.get_node_tree()
	if not node_tree:
		_log_error_localized("FUSE_ERROR_NO_SCENE_TREE", {})
		return null

	var items: Array = node_tree.get_nodes_in_group(group_name)
	return items

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()

	# 验证源类型
	match source_type:
		SourceType.VARIABLE:
			if array_variable.is_empty():
				errors.append(FuseLocalization.translate("FUSE_ERROR_ARRAY_VARIABLE_EMPTY"))

			if array_scope == BaseVariable.VariableScope.SCOPE:
				var manager = ScopeVariableManager.get_instance()
				if manager == null:
					errors.append(FuseLocalization.translate("FUSE_ERROR_SCOPE_MANAGER_NOT_FOUND"))

				var array_utils_scope_source = array_scope_source as VariableScopeUtils.ScopeSource
				errors.append_array(VariableScopeUtils.validate_scope_source_params(
					array_utils_scope_source,
					array_custom_scope_id,
					array_target_node_path
				))

		SourceType.NODE_CHILDREN:
			if target_node_path.is_empty():
				errors.append(FuseLocalization.translate("FUSE_ERROR_NODE_PATH_EMPTY"))

		SourceType.NODE_GROUP:
			if group_name.is_empty():
				errors.append(FuseLocalization.translate("FUSE_ERROR_GROUP_NAME_EMPTY"))

	# 验证目标变量
	if target_variable.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_VARIABLE_EMPTY"))

	if target_scope == BaseVariable.VariableScope.SCOPE:
		var manager = ScopeVariableManager.get_instance()
		if manager == null:
			errors.append(FuseLocalization.translate("FUSE_ERROR_SCOPE_MANAGER_NOT_FOUND"))

		var target_utils_scope_source = target_scope_source as VariableScopeUtils.ScopeSource
		errors.append_array(VariableScopeUtils.validate_scope_source_params(
			target_utils_scope_source,
			target_custom_scope_id,
			target_node_path_for_scope
		))

	return errors

## 验证属性可见性
func _validate_property(property: Dictionary) -> void:
	# 当源类型为 VARIABLE 时隐藏节点相关属性
	if source_type == SourceType.VARIABLE:
		if property.name in ["group_name", "target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	# 当源类型为 NODE_CHILDREN 时隐藏变量和组名
	if source_type == SourceType.NODE_CHILDREN:
		if property.name in ["array_variable", "array_scope", "group_name", "array_scope_source", "array_custom_scope_id", "array_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	# 当源类型为 NODE_GROUP 时隐藏变量名
	if source_type == SourceType.NODE_GROUP:
		if property.name in ["array_variable", "array_scope", "target_node_path", "array_scope_source", "array_custom_scope_id", "array_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	# 数组作用域相关属性
	if source_type == SourceType.VARIABLE:
		if array_scope == BaseVariable.VariableScope.SCOPE:
			if property.name == "array_scope_source":
				return
			elif property.name == "array_custom_scope_id":
				if array_scope_source != ScopeSource.CUSTOM_ID:
					property.usage = PROPERTY_USAGE_NO_EDITOR
			elif property.name == "array_target_node_path":
				if array_scope_source != ScopeSource.TARGET_NODE:
					property.usage = PROPERTY_USAGE_NO_EDITOR
		else:
			if property.name in ["array_scope_source", "array_custom_scope_id", "array_target_node_path"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		if property.name.begins_with("array_"):
			property.usage = PROPERTY_USAGE_NO_EDITOR

	# 目标作用域相关属性
	if target_scope == BaseVariable.VariableScope.SCOPE:
		if property.name == "target_scope_source":
			return
		elif property.name == "target_custom_scope_id":
			if target_scope_source != ScopeSource.CUSTOM_ID:
				property.usage = PROPERTY_USAGE_NO_EDITOR
		elif property.name == "target_node_path_for_scope":
			if target_scope_source != ScopeSource.TARGET_NODE:
				property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		if property.name in ["target_scope_source", "target_custom_scope_id", "target_node_path_for_scope"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR

## 获取指令描述
func get_description() -> String:
	var source_str := ""

	match source_type:
		SourceType.VARIABLE:
			source_str = array_variable if not array_variable.is_empty() else "No Array"
		SourceType.NODE_CHILDREN:
			source_str = "Children"
		SourceType.NODE_GROUP:
			source_str = "Group:%s" % group_name if not group_name.is_empty() else "No Group"

	var target_str = target_variable if not target_variable.is_empty() else "No Target"

	return "Array Contains: %s.has(%s) → %s" % [source_str, str(search_value), target_str]

## 重置指令状态
func reset():
	super.reset()
	_log_debug_localized("FUSE_LOG_ARRAY_CONTAINS_RESET", {})
