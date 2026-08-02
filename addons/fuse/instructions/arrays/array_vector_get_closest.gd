@tool
@icon("res://addons/fuse/icons/builtin/ArrowRight.png")
extends BaseInstruction
class_name ArrayVectorGetClosest

## ArrayVectorGetClosest 指令
##
## 获取向量数组中距离参考点最近的向量并存储到目标变量。
## 支持 Vector2 和 Vector3 类型的数组。
## 支持从变量、节点子节点或节点组获取数组。
## 参考点可以从变量读取或直接设置。
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

# 向量类型
enum VectorType {
	VECTOR2,  # Vector2 数组
	VECTOR3   # Vector3 数组
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

# 向量类型
var vector_type: VectorType = VectorType.VECTOR3:
	set(value):
		if vector_type != value:
			vector_type = value
			_update_resource_name()

## 参考点是否来自变量
var use_reference_from_variable: bool = false:
	set(value):
		if use_reference_from_variable != value:
			use_reference_from_variable = value
			_update_resource_name()
			notify_property_list_changed()

# 参考点（直接值）- 使用 @export 使其在 Inspector 中可编辑
@export var reference_position: Variant:
	set(value):
		reference_position = value
		_update_resource_name()

## 参考点变量名
var reference_variable: String = "":
	set(value):
		if reference_variable != value:
			reference_variable = value
			_update_resource_name()

## 参考点变量作用域
var reference_variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		if reference_variable_scope != value:
			reference_variable_scope = value
			_update_resource_name()
			notify_property_list_changed()

## 参考点作用域来源（仅当 reference_variable_scope == SCOPE 时使用）
var reference_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		if reference_scope_source != value:
			reference_scope_source = value
			_update_resource_name()
			notify_property_list_changed()

## 参考点自定义作用域 ID
var reference_custom_scope_id: String = "":
	set(value):
		if reference_custom_scope_id != value:
			reference_custom_scope_id = value
			_update_resource_name()

## 参考点目标节点路径
var reference_target_node_path: NodePath = NodePath(""):
	set(value):
		if reference_target_node_path != value:
			reference_target_node_path = value
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
	metadata.name_key = "FUSE_INSTRUCTION_ARRAY_VECTOR_CLOSEST_NAME"
	metadata.category_key = "FUSE_CATEGORY_ARRAYS"
	metadata.description_key = "FUSE_INSTRUCTION_ARRAY_VECTOR_CLOSEST_DESC"
	metadata.keywords = ["数组", "向量", "最近", "距离", "array", "vector", "closest", "distance", "Vector2", "Vector3"]
	metadata.builtin_icon = "ArrowRight"
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

	# Vector Type 分类
	properties.append({
		name = "Vector Type",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "vector_type",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Vector2,Vector3",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Reference Point 分类
	properties.append({
		name = "Reference Point",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "use_reference_from_variable",
		type = TYPE_BOOL,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 参考点变量或直接值
	if use_reference_from_variable:
		properties.append({
			name = "reference_variable",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		properties.append({
			name = "reference_variable_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 只在 reference_variable_scope == SCOPE 时显示配置
		if reference_variable_scope == BaseVariable.VariableScope.SCOPE:
			properties.append({
				name = "Reference Scope Configuration",
				type = TYPE_NIL,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_CATEGORY
			})

			properties.append({
				name = "reference_scope_source",
				type = TYPE_INT,
				hint = PROPERTY_HINT_ENUM,
				hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

			if reference_scope_source == ScopeSource.CUSTOM_ID:
				properties.append({
					name = "reference_custom_scope_id",
					type = TYPE_STRING,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})
			elif reference_scope_source == ScopeSource.TARGET_NODE:
				properties.append({
					name = "reference_target_node_path",
					type = TYPE_NODE_PATH,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})
	else:
		# reference_position 使用 @export 声明，不在 _get_property_list() 中添加
		pass

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
	var ref_str := ""
	var target_str := ""

	# 源信息
	match source_type:
		SourceType.VARIABLE:
			if array_variable.is_empty():
				source_str = FuseLocalization.translate("FUSE_INSTRUCTION_ARRAY_VECTOR_CLOSEST_NO_ARRAY")
			else:
				source_str = FuseLocalization.translate_format("FUSE_INSTRUCTION_ARRAY_VECTOR_CLOSEST_ARRAY", {"name": array_variable})
		SourceType.NODE_CHILDREN:
			source_str = FuseLocalization.translate("FUSE_INSTRUCTION_ARRAY_VECTOR_CLOSEST_NODE_CHILDREN")
		SourceType.NODE_GROUP:
			if group_name.is_empty():
				source_str = FuseLocalization.translate("FUSE_INSTRUCTION_ARRAY_VECTOR_CLOSEST_NO_GROUP")
			else:
				source_str = FuseLocalization.translate_format("FUSE_INSTRUCTION_ARRAY_VECTOR_CLOSEST_GROUP", {"name": group_name})

	# 参考点信息
	if use_reference_from_variable:
		if reference_variable.is_empty():
			ref_str = FuseLocalization.translate("FUSE_INSTRUCTION_ARRAY_VECTOR_CLOSEST_NO_REFERENCE")
		else:
			ref_str = reference_variable
	else:
		if reference_position != null:
			ref_str = str(reference_position)
		else:
			ref_str = FuseLocalization.translate("FUSE_INSTRUCTION_ARRAY_VECTOR_CLOSEST_NO_REFERENCE")

	# 目标信息
	if target_variable.is_empty():
		target_str = FuseLocalization.translate("FUSE_INSTRUCTION_ARRAY_VECTOR_CLOSEST_NO_TARGET")
	else:
		target_str = FuseLocalization.translate_format("FUSE_INSTRUCTION_ARRAY_VECTOR_CLOSEST_TARGET", {"name": target_variable})

	var type_str := "V2" if vector_type == VectorType.VECTOR2 else "V3"
	resource_name = " ".join(["Closest %s" % type_str, source_str, "@", ref_str, "→", target_str])

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

	if property == "reference_variable" or property == "target_variable" or property == "reference_position":
		_update_resource_name()
		return false

	return false

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	_log_debug_localized("FUSE_LOG_INSTRUCTION_START", {"instruction": "ArrayVectorGetClosest"})

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

	# 获取参考点
	var ref_point: Variant = _get_reference_point(context)

	if ref_point == null:
		_log_error_localized("FUSE_ERROR_REFERENCE_POINT_INVALID", {})
		set_error_localized("FUSE_ERROR_REFERENCE_POINT_INVALID", FuseError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	# 验证参考点类型
	var expected_type := "Vector3" if vector_type == VectorType.VECTOR3 else "Vector2"
	if vector_type == VectorType.VECTOR3 and not (ref_point is Vector3):
		_log_error("参考点类型错误: 期望 Vector3，实际 %s" % typeof(ref_point))
		set_error_localized("FUSE_ERROR_REFERENCE_POINT_TYPE_MISMATCH", FuseError.ErrorType.RUNTIME_ERROR, {"expected": expected_type})
		finished.emit()
		return
	elif vector_type == VectorType.VECTOR2 and not (ref_point is Vector2):
		_log_error("参考点类型错误: 期望 Vector2，实际 %s" % typeof(ref_point))
		set_error_localized("FUSE_ERROR_REFERENCE_POINT_TYPE_MISMATCH", FuseError.ErrorType.RUNTIME_ERROR, {"expected": expected_type})
		finished.emit()
		return

	# 获取最近的向量
	var closest: Variant = _get_closest_vector(target_array, ref_point)

	if closest == null:
		_log_error_localized("FUSE_ERROR_ARRAY_NOT_VECTOR", {})
		set_error_localized("FUSE_ERROR_ARRAY_NOT_VECTOR", FuseError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	# 存储到目标变量
	_set_target_variable(context, closest)

	var type_str := "Vector3" if vector_type == VectorType.VECTOR3 else "Vector2"
	_log_info_localized("FUSE_LOG_ARRAY_VECTOR_CLOSEST", {"vector": str(closest), "type": type_str, "target": target_variable})

	_on_execution_completed()

## 获取参考点
func _get_reference_point(context: ExecutionContext) -> Variant:
	if use_reference_from_variable:
		# 从变量获取参考点
		if reference_variable.is_empty():
			return null

		match reference_variable_scope:
			BaseVariable.VariableScope.LOCAL:
				return VariableOperations.get_variable(context, reference_variable, BaseVariable.VariableScope.LOCAL, null)
			BaseVariable.VariableScope.SCOPE:
				if reference_scope_source == ScopeSource.NEAREST:
					return VariableOperations.get_variable(context, reference_variable, BaseVariable.VariableScope.SCOPE, null)
				else:
					var utils_scope_source = reference_scope_source as VariableScopeUtils.ScopeSource
					var scope_container = VariableScopeUtils.get_scope_container_by_source(
						context,
						utils_scope_source,
						reference_custom_scope_id,
						reference_target_node_path
					)
					if scope_container == null:
						return null
					return scope_container.get_variable(reference_variable, null)
			BaseVariable.VariableScope.GLOBAL:
				return VariableOperations.get_variable(context, reference_variable, BaseVariable.VariableScope.GLOBAL, null)
		return null
	else:
		# 使用直接值
		return reference_position

## 获取距离参考点最近的向量
func _get_closest_vector(arr: Array, ref_point: Variant) -> Variant:
	var closest: Variant = null
	var min_distance: float = INF

	for item in arr:
		var distance: float

		if vector_type == VectorType.VECTOR3:
			if item is Vector3 and ref_point is Vector3:
				distance = item.distance_to(ref_point)
			else:
				_log_debug("数组包含非 Vector3 元素: %s (类型: %s)" % [str(item), typeof(item)])
				return null
		else:  # VECTOR2
			if item is Vector2 and ref_point is Vector2:
				distance = item.distance_to(ref_point)
			else:
				_log_debug("数组包含非 Vector2 元素: %s (类型: %s)" % [str(item), typeof(item)])
				return null

		if distance < min_distance:
			min_distance = distance
			closest = item

	return closest

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

	if array_value == null:
		return null

	if array_value is Array:
		return array_value

	if _is_packed_vector_array(array_value):
		# PackedVectorArray 需要转换为普通 Array
		var converted: Array = []
		for item in array_value:
			converted.append(item)
		return converted

	return null

## 检查是否为向量类型的 PackedArray
func _is_packed_vector_array(value: Variant) -> bool:
	return value is PackedVector2Array or value is PackedVector3Array

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

	# 验证参考点
	if use_reference_from_variable:
		if reference_variable.is_empty():
			errors.append(FuseLocalization.translate("FUSE_ERROR_REFERENCE_VARIABLE_EMPTY"))

		if reference_variable_scope == BaseVariable.VariableScope.SCOPE:
			var manager = ScopeVariableManager.get_instance()
			if manager == null:
				errors.append(FuseLocalization.translate("FUSE_ERROR_SCOPE_MANAGER_NOT_FOUND"))

			var reference_utils_scope_source = reference_scope_source as VariableScopeUtils.ScopeSource
			errors.append_array(VariableScopeUtils.validate_scope_source_params(
				reference_utils_scope_source,
				reference_custom_scope_id,
				reference_target_node_path
			))

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

	# 参考点相关属性
	if use_reference_from_variable:
		if property.name == "reference_position":
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		if property.name in ["reference_variable", "reference_variable_scope", "reference_scope_source", "reference_custom_scope_id", "reference_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	# 参考点作用域相关属性
	if use_reference_from_variable:
		if reference_variable_scope == BaseVariable.VariableScope.SCOPE:
			if property.name == "reference_scope_source":
				return
			elif property.name == "reference_custom_scope_id":
				if reference_scope_source != ScopeSource.CUSTOM_ID:
					property.usage = PROPERTY_USAGE_NO_EDITOR
			elif property.name == "reference_target_node_path":
				if reference_scope_source != ScopeSource.TARGET_NODE:
					property.usage = PROPERTY_USAGE_NO_EDITOR
		else:
			if property.name in ["reference_scope_source", "reference_custom_scope_id", "reference_target_node_path"]:
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
	var type_str := "Vector2" if vector_type == VectorType.VECTOR2 else "Vector3"

	match source_type:
		SourceType.VARIABLE:
			source_str = array_variable if not array_variable.is_empty() else "No Array"
		SourceType.NODE_CHILDREN:
			source_str = "Children"
		SourceType.NODE_GROUP:
			source_str = "Group:%s" % group_name if not group_name.is_empty() else "No Group"

	var ref_str := ""
	if use_reference_from_variable:
		ref_str = reference_variable if not reference_variable.is_empty() else "No Ref"
	else:
		ref_str = str(reference_position) if reference_position != null else "No Ref"

	var target_str = target_variable if not target_variable.is_empty() else "No Target"

	return "Get Closest %s: %s nearest to %s → %s" % [type_str, source_str, ref_str, target_str]

## 重置指令状态
func reset():
	super.reset()
	_log_debug_localized("FUSE_LOG_ARRAY_VECTOR_CLOSEST_RESET", {})
