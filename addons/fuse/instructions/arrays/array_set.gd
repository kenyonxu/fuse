@tool
@icon("res://addons/fuse/icons/builtin/Set.svg")
extends BaseInstruction
class_name ArraySet

## ArraySet 指令
##
## 设置数组中指定索引的元素值。
## 支持负索引（从末尾计数）。
## 支持从变量、节点子节点或节点组获取数组。
##
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

# 索引值（支持负索引）
var index_value: int = 0:
	set(value):
		index_value = value
		_update_resource_name()

# 元素值（要设置的值）- 使用 @export 使其在 Inspector 中可编辑
@export var element_value: Variant:
	set(value):
		element_value = value
		_update_resource_name()

## 元素值是否来自变量
var use_element_from_variable: bool = false:
	set(value):
		use_element_from_variable = value
		_update_resource_name()
		notify_property_list_changed()

## 元素源变量名（当 use_element_from_variable = true 时使用）
var element_from_variable: String = ""

## 元素源变量作用域
var element_from_variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		element_from_variable_scope = value
		_update_resource_name()
		notify_property_list_changed()

## 元素源作用域来源（仅当 element_from_variable_scope == SCOPE 时使用）
var element_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		element_scope_source = value
		_update_resource_name()
		notify_property_list_changed()

## 元素源自定义作用域 ID
var element_custom_scope_id: String = "":
	set(value):
		if element_custom_scope_id != value:
			element_custom_scope_id = value
			_update_resource_name()

## 元素源目标节点路径
var element_target_node_path: NodePath = NodePath(""):
	set(value):
		if element_target_node_path != value:
			element_target_node_path = value
			_update_resource_name()

## 获取指令元数据（用于指令选择器）
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_ARRAY_SET_NAME"
	metadata.category_key = "FUSE_CATEGORY_ARRAYS"
	metadata.description_key = "FUSE_INSTRUCTION_ARRAY_SET_DESC"
	metadata.keywords = ["数组", "设置", "修改", "array", "set", "assign", "索引"]
	metadata.builtin_icon = "Set"
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties := []

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

			# 根据作用域来源添加额外属性
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

	# Index 分类
	properties.append({
		name = "Index",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "index_value",
		type = TYPE_INT,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Element 分类
	properties.append({
		name = "Element",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "use_element_from_variable",
		type = TYPE_BOOL,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 元素值或元素源变量
	if use_element_from_variable:
		properties.append({
			name = "element_from_variable",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		properties.append({
			name = "element_from_variable_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 只在 element_from_variable_scope == SCOPE 时显示 ScopeSource 配置
		if element_from_variable_scope == BaseVariable.VariableScope.SCOPE:
			properties.append({
				name = "Element Scope Configuration",
				type = TYPE_NIL,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_CATEGORY
			})

			properties.append({
				name = "element_scope_source",
				type = TYPE_INT,
				hint = PROPERTY_HINT_ENUM,
				hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

			# 根据作用域来源添加额外属性
			if element_scope_source == ScopeSource.CUSTOM_ID:
				properties.append({
					name = "element_custom_scope_id",
					type = TYPE_STRING,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})
			elif element_scope_source == ScopeSource.TARGET_NODE:
				properties.append({
					name = "element_target_node_path",
					type = TYPE_NODE_PATH,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})
	# 注意：element_value 使用 @export 声明，不在 _get_property_list() 中添加
	# _validate_property() 会根据 use_element_from_variable 控制其可见性

	return properties

## 更新资源名称
func _update_resource_name():
	var source_str := ""
	var element_str := ""

	# 源信息
	match source_type:
		SourceType.VARIABLE:
			if array_variable.is_empty():
				source_str = FuseLocalization.translate("FUSE_INSTRUCTION_ARRAY_SET_NO_ARRAY")
			else:
				source_str = FuseLocalization.translate_format("FUSE_INSTRUCTION_ARRAY_SET_ARRAY", {"name": array_variable})
		SourceType.NODE_CHILDREN:
			source_str = FuseLocalization.translate("FUSE_INSTRUCTION_ARRAY_SET_NODE_CHILDREN")
		SourceType.NODE_GROUP:
			if group_name.is_empty():
				source_str = FuseLocalization.translate("FUSE_INSTRUCTION_ARRAY_SET_NO_GROUP")
			else:
				source_str = FuseLocalization.translate_format("FUSE_INSTRUCTION_ARRAY_SET_GROUP", {"name": group_name})

	# 元素信息
	if use_element_from_variable:
		if element_from_variable.is_empty():
			element_str = FuseLocalization.translate("FUSE_INSTRUCTION_ARRAY_SET_NO_ELEMENT_VAR")
		else:
			element_str = FuseLocalization.translate_format("FUSE_INSTRUCTION_ARRAY_SET_FROM_VAR", {"name": element_from_variable})
	else:
		var value_str = str(element_value)
		if value_str.length() > 15:
			value_str = value_str.substr(0, 12) + "..."
		element_str = value_str

	resource_name = " ".join(["Array Set", source_str, "[%d]" % index_value, "=", element_str])

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

	if property == "index_value" or property == "element_value" or property == "element_from_variable":
		_update_resource_name()
		return false

	return false

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	_log_debug_localized("FUSE_LOG_INSTRUCTION_START", {"instruction": "ArraySet"})

	# 获取要设置的元素值
	var element: Variant
	if use_element_from_variable:
		# 从变量获取元素值
		if element_from_variable.is_empty():
			_log_error_localized("FUSE_ERROR_ELEMENT_VAR_EMPTY", {})
			set_error_localized("FUSE_ERROR_ELEMENT_VAR_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
			finished.emit()
			return

		match element_from_variable_scope:
			BaseVariable.VariableScope.LOCAL:
				element = VariableOperations.get_variable(context, element_from_variable, BaseVariable.VariableScope.LOCAL, null)
			BaseVariable.VariableScope.SCOPE:
				if element_scope_source == ScopeSource.NEAREST:
					element = VariableOperations.get_variable(context, element_from_variable, BaseVariable.VariableScope.SCOPE, null)
				else:
					var utils_scope_source = element_scope_source as VariableScopeUtils.ScopeSource
					var scope_container = VariableScopeUtils.get_scope_container_by_source(
						context,
						utils_scope_source,
						element_custom_scope_id,
						element_target_node_path
					)
					if scope_container == null:
						_log_error_localized("FUSE_ERROR_SCOPE_CONTAINER_NOT_FOUND", {})
						set_error_localized("FUSE_ERROR_SCOPE_CONTAINER_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {})
						finished.emit()
						return
					element = scope_container.get_variable(element_from_variable, null)
			BaseVariable.VariableScope.GLOBAL:
				element = VariableOperations.get_variable(context, element_from_variable, BaseVariable.VariableScope.GLOBAL, null)
	else:
		# 使用直接值
		element = element_value

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

			# 调试输出：显示数组变量的作用域信息
			_debug_log_array_scope_info()

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

	# 获取索引（支持负索引）
	var idx := index_value
	if idx < 0:
		idx = target_array.size() + idx

	# 验证索引范围
	if idx < 0 or idx >= target_array.size():
		_log_error_localized("FUSE_ERROR_ARRAY_INDEX_OUT_OF_RANGE", {"index": index_value, "size": target_array.size()})
		set_error_localized("FUSE_ERROR_ARRAY_INDEX_OUT_OF_RANGE", FuseError.ErrorType.RUNTIME_ERROR, {"index": index_value, "size": target_array.size()})
		finished.emit()
		return

	# 设置元素值
	var old_value = target_array[idx]
	target_array[idx] = element

	# 保存回变量（如果是 VARIABLE 模式）
	if source_type == SourceType.VARIABLE:
		_save_array_to_variable(context, target_array)

	_log_info_localized("FUSE_LOG_ARRAY_SET", {"index": index_value, "old": str(old_value), "new": str(element)})

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
		# PackedArray 类型需要转换为普通 Array
		_log_debug("变量 '%s' 是 PackedArray 类型，转换为普通 Array" % array_variable)
		var converted_array: Array = []
		for item in array_value:
			converted_array.append(item)
		# 更新存储的变量为普通 Array
		_save_array_to_variable(context, converted_array)
		return converted_array

	return null

## 保存数组到变量
func _save_array_to_variable(context: ExecutionContext, array_ref: Array):
	match array_scope:
		BaseVariable.VariableScope.LOCAL:
			VariableOperations.set_variable(context, array_variable, BaseVariable.VariableScope.LOCAL, array_ref)
		BaseVariable.VariableScope.SCOPE:
			if array_scope_source == ScopeSource.NEAREST:
				VariableOperations.set_variable(context, array_variable, BaseVariable.VariableScope.SCOPE, array_ref)
			else:
				var utils_scope_source = array_scope_source as VariableScopeUtils.ScopeSource
				var scope_container = VariableScopeUtils.get_scope_container_by_source(
					context,
					utils_scope_source,
					array_custom_scope_id,
					array_target_node_path
				)
				if scope_container:
					scope_container.set_variable(array_variable, array_ref)
			# 触发 SCOPE 变量变化通知
			_notify_scope_variable_changed(context)
		BaseVariable.VariableScope.GLOBAL:
			VariableOperations.set_variable(context, array_variable, BaseVariable.VariableScope.GLOBAL, array_ref)
			# 触发全局变量变化通知
			_notify_global_variable_changed(array_variable)

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

## 调试输出：显示数组变量的作用域信息
func _debug_log_array_scope_info():
	var scope_name := ""
	match array_scope:
		BaseVariable.VariableScope.LOCAL:
			scope_name = "LOCAL（本地）"
		BaseVariable.VariableScope.SCOPE:
			scope_name = "SCOPE（作用域）"
		BaseVariable.VariableScope.GLOBAL:
			scope_name = "GLOBAL（全局）"

	if array_scope == BaseVariable.VariableScope.SCOPE:
		var source_name := ""
		match array_scope_source:
			ScopeSource.NEAREST:
				source_name = "NEAREST（最近的作用域容器）"
			ScopeSource.CUSTOM_ID:
				source_name = "CUSTOM_ID（自定义ID: %s）" % array_custom_scope_id
			ScopeSource.TRIGGER_SCOPE:
				source_name = "TRIGGER_SCOPE（Trigger节点作用域）"
			ScopeSource.TARGET_NODE:
				source_name = "TARGET_NODE（目标节点: %s）" % str(array_target_node_path)
		_log_debug("📍 目标数组: '%s' | 作用域: %s | 来源: %s" % [array_variable, scope_name, source_name])
	else:
		_log_debug("📍 目标数组: '%s' | 作用域: %s" % [array_variable, scope_name])

## 获取作用域名称（用于日志输出）
func _get_scope_name_for_log() -> String:
	match array_scope:
		BaseVariable.VariableScope.LOCAL:
			return "LOCAL（本地）"
		BaseVariable.VariableScope.SCOPE:
			var source_name := ""
			match array_scope_source:
				ScopeSource.NEAREST:
					source_name = "NEAREST"
				ScopeSource.CUSTOM_ID:
					source_name = "CUSTOM_ID[%s]" % array_custom_scope_id
				ScopeSource.TRIGGER_SCOPE:
					source_name = "TRIGGER_SCOPE"
				ScopeSource.TARGET_NODE:
					source_name = "TARGET_NODE[%s]" % str(array_target_node_path)
			return "SCOPE（作用域）- %s" % source_name
		BaseVariable.VariableScope.GLOBAL:
			return "GLOBAL（全局）"
	return "UNKNOWN"

## 通知全局变量已变化
func _notify_global_variable_changed(var_name: String) -> void:
	var manager = GlobalVariableManager.get_instance()
	if manager == null:
		return

	var variable = manager.get_variable(var_name)
	if variable == null:
		return

	if variable.persistent:
		_log_debug("持久化变量 '%s' 已修改，触发变化通知" % var_name)
		manager.notify_variable_content_changed(var_name)

## 通知 SCOPE 作用域变量已变化
func _notify_scope_variable_changed(context: ExecutionContext) -> void:
	var utils_scope_source = array_scope_source as VariableScopeUtils.ScopeSource
	var scope_container = VariableScopeUtils.get_scope_container_by_source(
		context,
		utils_scope_source,
		array_custom_scope_id,
		array_target_node_path
	)

	if scope_container == null:
		_log_debug("⚠️ 无法获取 ScopeVariableContainer，跳过变化通知")
		return

	_log_debug("📌 SCOPE 变量 '%s' 已修改，触发 notify_property_list_changed" % array_variable)
	scope_container.notify_property_list_changed()

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()

	# 验证源类型
	match source_type:
		SourceType.VARIABLE:
			if array_variable.is_empty():
				errors.append(FuseLocalization.translate("FUSE_ERROR_ARRAY_VARIABLE_EMPTY"))

			# 验证数组 SCOPE 作用域需要 ScopeVariableManager
			if array_scope == BaseVariable.VariableScope.SCOPE:
				var manager = ScopeVariableManager.get_instance()
				if manager == null:
					errors.append(FuseLocalization.translate("FUSE_ERROR_SCOPE_MANAGER_NOT_FOUND"))

				# 验证 ScopeSource 参数
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

	# 验证元素源
	if use_element_from_variable:
		if element_from_variable.is_empty():
			errors.append(FuseLocalization.translate("FUSE_ERROR_ELEMENT_VAR_EMPTY"))

		# 验证元素 SCOPE 作用域需要 ScopeVariableManager
		if element_from_variable_scope == BaseVariable.VariableScope.SCOPE:
			var manager = ScopeVariableManager.get_instance()
			if manager == null:
				errors.append(FuseLocalization.translate("FUSE_ERROR_SCOPE_MANAGER_NOT_FOUND"))

			# 验证 ScopeSource 参数
			var element_utils_scope_source = element_scope_source as VariableScopeUtils.ScopeSource
			errors.append_array(VariableScopeUtils.validate_scope_source_params(
				element_utils_scope_source,
				element_custom_scope_id,
				element_target_node_path
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
				return  # 始终显示
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

	# 元素变量相关属性
	if use_element_from_variable:
		if property.name == "element_value":
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		if property.name in ["element_from_variable", "element_from_variable_scope", "element_scope_source", "element_custom_scope_id", "element_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	# 元素作用域相关属性
	if use_element_from_variable:
		if element_from_variable_scope == BaseVariable.VariableScope.SCOPE:
			if property.name == "element_scope_source":
				return  # 始终显示
			elif property.name == "element_custom_scope_id":
				if element_scope_source != ScopeSource.CUSTOM_ID:
					property.usage = PROPERTY_USAGE_NO_EDITOR
			elif property.name == "element_target_node_path":
				if element_scope_source != ScopeSource.TARGET_NODE:
					property.usage = PROPERTY_USAGE_NO_EDITOR
		else:
			if property.name in ["element_scope_source", "element_custom_scope_id", "element_target_node_path"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR

## 获取指令描述
func get_description() -> String:
	var source_str := ""

	match source_type:
		SourceType.VARIABLE:
			source_str = FuseLocalization.translate_format("FUSE_INSTRUCTION_ARRAY_SET_DESC_ARRAY", {"name": array_variable}) if not array_variable.is_empty() else FuseLocalization.translate("FUSE_INSTRUCTION_ARRAY_SET_DESC_NO_ARRAY")
		SourceType.NODE_CHILDREN:
			source_str = FuseLocalization.translate("FUSE_INSTRUCTION_ARRAY_SET_DESC_NODE_CHILDREN")
		SourceType.NODE_GROUP:
			source_str = FuseLocalization.translate_format("FUSE_INSTRUCTION_ARRAY_SET_DESC_GROUP", {"name": group_name}) if not group_name.is_empty() else FuseLocalization.translate("FUSE_INSTRUCTION_ARRAY_SET_DESC_NO_GROUP")

	var element_str := ""
	if use_element_from_variable:
		element_str = FuseLocalization.translate_format("FUSE_INSTRUCTION_ARRAY_SET_DESC_FROM_VAR", {"name": element_from_variable}) if not element_from_variable.is_empty() else FuseLocalization.translate("FUSE_INSTRUCTION_ARRAY_SET_DESC_NO_VAR")
	else:
		element_str = str(element_value)

	return "Array Set: %s[%d] = %s" % [source_str, index_value, element_str]

## 重置指令状态
func reset():
	super.reset()
	_log_debug_localized("FUSE_LOG_ARRAY_SET_RESET", {})
