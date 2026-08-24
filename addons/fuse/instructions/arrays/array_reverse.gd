@tool
@icon("res://addons/fuse/icons/builtin/Array.svg")
extends BaseInstruction
class_name ArrayReverse

## ArrayReverse 指令
##
## 反转数组（原地反转）。
## 支持从变量、节点子节点或节点组获取数组。
## 只在 VARIABLE 模式下保存回变量。

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

## 获取指令元数据（用于指令选择器）
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_ARRAY_REVERSE_NAME"
	metadata.category_key = "FUSE_CATEGORY_ARRAYS"
	metadata.description_key = "FUSE_INSTRUCTION_ARRAY_REVERSE_DESC"
	metadata.keywords = ["数组", "反转", "reverse", "array", "倒序", "翻转"]
	metadata.builtin_icon = "Array"
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

	return properties

## 更新资源名称
func _update_resource_name():
	var source_str := ""

	# 源信息
	match source_type:
		SourceType.VARIABLE:
			if array_variable.is_empty():
				source_str = FuseLocalization.translate("FUSE_INSTRUCTION_ARRAY_REVERSE_NO_ARRAY")
			else:
				source_str = FuseLocalization.translate_format("FUSE_INSTRUCTION_ARRAY_REVERSE_ARRAY", {"name": array_variable})
		SourceType.NODE_CHILDREN:
			source_str = FuseLocalization.translate("FUSE_INSTRUCTION_ARRAY_REVERSE_NODE_CHILDREN")
		SourceType.NODE_GROUP:
			if group_name.is_empty():
				source_str = FuseLocalization.translate("FUSE_INSTRUCTION_ARRAY_REVERSE_NO_GROUP")
			else:
				source_str = FuseLocalization.translate_format("FUSE_INSTRUCTION_ARRAY_REVERSE_GROUP", {"name": group_name})

	resource_name = "Array Reverse: %s" % source_str

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

	return false

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	_log_debug_localized("FUSE_LOG_INSTRUCTION_START", {"instruction": "ArrayReverse"})

	# 调试输出：打印当前全局变量信息
	_debug_print_global_variables()

	# 获取数组
	var target_array: Variant

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

			if target_array == null:
				_log_error_localized("FUSE_ERROR_NODE_GROUP_NOT_FOUND", {"name": group_name})
				set_error_localized("FUSE_ERROR_NODE_GROUP_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"name": group_name})
				finished.emit()
				return

	# 验证是否为数组
	if not target_array is Array:
		_log_error("目标不是数组类型 (类型: %s)" % typeof(target_array))
		set_error_localized("FUSE_ERROR_NOT_ARRAY", FuseError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	# 调试输出：反转前的数组状态
	var array_before := (target_array as Array).duplicate()
	_log_debug("数组反转前: 大小=%d, 内容=%s" % [target_array.size(), str(target_array)])

	# 反转数组（原地操作）
	target_array.reverse()

	# 获取作用域名称用于日志输出
	var scope_name_for_log := _get_scope_name_for_log()

	_log_debug("════════════════════════════════════════════════════")
	_log_debug("📤 ArrayReverse 执行结果:")
	_log_debug("  • 目标数组: '%s'" % array_variable)
	_log_debug("  • 作用域: %s" % scope_name_for_log)
	_log_debug("  • 反转前: %s" % str(array_before))
	_log_debug("  • 反转后: %s" % str(target_array))
	_log_debug("════════════════════════════════════════════════════")

	_log_info_localized("FUSE_LOG_ARRAY_REVERSED", {"array": array_variable})

	# 只在 VARIABLE 模式下触发变量变化通知
	# reverse() 修改的是数组内容而非引用，需要手动触发信号
	if source_type == SourceType.VARIABLE:
		if array_scope == BaseVariable.VariableScope.GLOBAL:
			var verified_array = VariableOperations.get_variable(context, array_variable, BaseVariable.VariableScope.GLOBAL, null)
			if verified_array is Array:
				_log_debug("🔍 全局变量 '%s' 最终验证: 大小=%d, 内容=%s" % [array_variable, verified_array.size(), str(verified_array)])
				# 触发变量变化通知
				_notify_global_variable_changed(array_variable)
			else:
				_log_error("❌ 全局变量 '%s' 验证失败: 不是数组类型 (类型: %s)" % [array_variable, typeof(verified_array)])

		elif array_scope == BaseVariable.VariableScope.SCOPE:
			# 触发 SCOPE 变量变化通知
			_notify_scope_variable_changed(context)

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
		# PackedArray 类型，转换为普通 Array
		_log_debug("变量 '%s' 是 PackedArray 类型，转换为普通 Array" % array_variable)
		var converted_array: Array = []
		for item in array_value:
			converted_array.append(item)
		# 更新存储的变量为普通 Array
		match array_scope:
			BaseVariable.VariableScope.LOCAL:
				VariableOperations.set_variable(context, array_variable, BaseVariable.VariableScope.LOCAL, converted_array)
			BaseVariable.VariableScope.SCOPE:
				if array_scope_source == ScopeSource.NEAREST:
					VariableOperations.set_variable(context, array_variable, BaseVariable.VariableScope.SCOPE, converted_array)
				else:
					var utils_scope_source = array_scope_source as VariableScopeUtils.ScopeSource
					var scope_container = VariableScopeUtils.get_scope_container_by_source(
						context,
						utils_scope_source,
						array_custom_scope_id,
						array_target_node_path
					)
					if scope_container:
						scope_container.set_variable(array_variable, converted_array)
			BaseVariable.VariableScope.GLOBAL:
				VariableOperations.set_variable(context, array_variable, BaseVariable.VariableScope.GLOBAL, converted_array)
		return converted_array

	return array_value

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
	# 获取节点树（context.get_tree()：tree 属性访问器，未设置时从当前场景回退，
	# 同构参照 get_nodes_in_group.gd；旧 get_node_tree() 在 ExecutionContext 上不存在）
	var node_tree = context.get_tree()
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

## 获取指令描述
func get_description() -> String:
	var source_str := ""

	match source_type:
		SourceType.VARIABLE:
			source_str = FuseLocalization.translate_format("FUSE_INSTRUCTION_ARRAY_REVERSE_DESC_ARRAY", {"name": array_variable}) if not array_variable.is_empty() else FuseLocalization.translate("FUSE_INSTRUCTION_ARRAY_REVERSE_DESC_NO_ARRAY")
		SourceType.NODE_CHILDREN:
			source_str = FuseLocalization.translate("FUSE_INSTRUCTION_ARRAY_REVERSE_DESC_NODE_CHILDREN")
		SourceType.NODE_GROUP:
			source_str = FuseLocalization.translate_format("FUSE_INSTRUCTION_ARRAY_REVERSE_DESC_GROUP", {"name": group_name}) if not group_name.is_empty() else FuseLocalization.translate("FUSE_INSTRUCTION_ARRAY_REVERSE_DESC_NO_GROUP")

	return "Array Reverse: %s" % source_str

## 重置指令状态
func reset():
	super.reset()
	_log_debug_localized("FUSE_LOG_ARRAY_REVERSE_RESET", {})

## 调试输出：打印当前全局变量信息
func _debug_print_global_variables():
	var assistant = GlobalVariableAssistant.get_instance()
	if assistant == null:
		_log_debug("⚠️ 无法获取全局变量助手")
		return

	var all_vars_info = assistant.get_all_global_variables_info()
	if all_vars_info.is_empty():
		_log_debug("📋 当前全局变量: (无)")
		return

	_log_debug("📋 当前全局变量列表 (%d 个):" % all_vars_info.size())
	for var_name in all_vars_info.keys():
		var var_info = all_vars_info[var_name]
		var type_name = var_info.get("type", "Unknown")
		var value_str = str(var_info.get("value", ""))
		var persistent_flag = var_info.get("persistent", false)
		# 如果值太长则截断
		if value_str.length() > 50:
			value_str = value_str.substr(0, 47) + "..."
		var persistent_mark = "📌" if persistent_flag else ""
		_log_debug("  • %s [%s] = %s%s" % [var_name, type_name, value_str, persistent_mark])

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

## 通知全局变量已变化（用于触发自动保存等）
## 由于 reverse() 修改的是数组内容而非引用，value_changed 信号不会自动触发
## 因此需要手动通知 GlobalVariableManager 变量已变化
func _notify_global_variable_changed(var_name: String) -> void:
	var manager = GlobalVariableManager.get_instance()
	if manager == null:
		_log_debug("⚠️ 无法获取全局变量管理器，跳过变化通知")
		return

	var variable = manager.get_variable(var_name)
	if variable == null:
		_log_debug("⚠️ 全局变量 '%s' 不存在，跳过变化通知" % var_name)
		return

	# 检查是否是持久化变量
	if variable.persistent:
		_log_debug("📌 持久化变量 '%s' 已修改，触发变化通知" % var_name)
		# 使用 GlobalVariableManager 提供的方法通知变量内容已变化
		manager.notify_variable_content_changed(var_name)
	else:
		_log_debug("变量 '%s' 不是持久化变量，跳过自动保存通知" % var_name)

## 通知 SCOPE 作用域变量已变化
## 由于 reverse() 修改的是数组内容而非引用，需要调用 notify_property_list_changed
## 让远程调试器能够观测到变量变化
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
