@tool
@icon("res://addons/fuse/icons/builtin/Performance.png")
extends BaseCondition
class_name CheckDirection

## 方位检测条件
##
## 检查目标相对于源节点的方位。
##
## 支持两种节点来源：
## - NODE_PATH: 通过节点路径直接指定
## - VARIABLE: 从变量获取节点（支持三层变量作用域）

## 节点来源枚举
enum NodeSource {
	NODE_PATH,   ## 通过节点路径指定
	VARIABLE     ## 从变量获取节点
}

## 作用域来源枚举（仅在 variable_scope == SCOPE 时使用）
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

# =============================================
# 源节点参数定义
# =============================================

## 源节点来源
var source_node_source: NodeSource = NodeSource.NODE_PATH:
	set(value):
		source_node_source = value
		_update_resource_name()
		notify_property_list_changed()

## 源节点路径
var source_node: NodePath = NodePath(""):
	set(value):
		source_node = value
		_update_resource_name()

## 源节点变量名（当 source_node_source == VARIABLE 时使用）
var source_variable_name: String = "":
	set(value):
		source_variable_name = value
		_update_resource_name()

## 源节点变量作用域（三层变量系统）
var source_variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		source_variable_scope = value
		_update_resource_name()
		notify_property_list_changed()

## 源节点变量作用域来源（仅当 source_variable_scope == SCOPE 时使用）
var source_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		source_scope_source = value
		_update_resource_name()
		notify_property_list_changed()

## 源节点变量自定义作用域 ID（仅当 source_scope_source == CUSTOM_ID 时使用）
var source_custom_scope_id: String = "":
	set(value):
		source_custom_scope_id = value
		_update_resource_name()

## 源节点变量目标节点路径（仅当 source_scope_source == TARGET_NODE 时使用）
var source_target_node_path: NodePath = NodePath(""):
	set(value):
		source_target_node_path = value
		_update_resource_name()

# =============================================
# 目标节点参数定义
# =============================================

## 目标节点来源
var target_node_source: NodeSource = NodeSource.NODE_PATH:
	set(value):
		target_node_source = value
		_update_resource_name()
		notify_property_list_changed()

## 目标节点路径
var target_node: NodePath = NodePath(""):
	set(value):
		target_node = value
		_update_resource_name()

## 目标节点变量名（当 target_node_source == VARIABLE 时使用）
var target_variable_name: String = "":
	set(value):
		target_variable_name = value
		_update_resource_name()

## 目标节点变量作用域（三层变量系统）
var target_variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		target_variable_scope = value
		_update_resource_name()
		notify_property_list_changed()

## 目标节点变量作用域来源（仅当 target_variable_scope == SCOPE 时使用）
var target_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		target_scope_source = value
		_update_resource_name()
		notify_property_list_changed()

## 目标节点变量自定义作用域 ID（仅当 target_scope_source == CUSTOM_ID 时使用）
var target_custom_scope_id: String = "":
	set(value):
		target_custom_scope_id = value
		_update_resource_name()

## 目标节点变量目标节点路径（仅当 target_scope_source == TARGET_NODE 时使用）
var target_target_node_path: NodePath = NodePath(""):
	set(value):
		target_target_node_path = value
		_update_resource_name()

# =============================================
# 方向检查参数定义
# =============================================

## 期望的方向
@export_enum("上:0", "下:1", "左:2", "右:3") var expected_direction: int = 0:
	set(value):
		expected_direction = value
		_update_resource_name()

## 方向容差（角度）
@export var tolerance: float = 45.0:
	set(value):
		tolerance = value
		_update_resource_name()

# =============================================
# 动态属性列表
# =============================================

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties := []

	# ========== 源节点配置 ==========
	properties.append({
		name = "Source Node Configuration",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 源节点来源
	properties.append({
		name = "source_node_source",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Node Path,Variable",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 根据源节点来源显示不同属性
	if source_node_source == NodeSource.NODE_PATH:
		# 节点路径模式
		properties.append({
			name = "source_node",
			type = TYPE_NODE_PATH,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
	else:
		# 变量模式
		properties.append({
			name = "source_variable_name",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 变量作用域
		properties.append({
			name = "source_variable_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 只在 source_variable_scope == SCOPE 时显示 ScopeSource 配置
		if source_variable_scope == BaseVariable.VariableScope.SCOPE:
			properties.append({
				name = "source_scope_source",
				type = TYPE_INT,
				hint = PROPERTY_HINT_ENUM,
				hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

			# 根据作用域来源添加额外属性
			if source_scope_source == ScopeSource.CUSTOM_ID:
				properties.append({
					name = "source_custom_scope_id",
					type = TYPE_STRING,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})
			elif source_scope_source == ScopeSource.TARGET_NODE:
				properties.append({
					name = "source_target_node_path",
					type = TYPE_NODE_PATH,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})

	# ========== 目标节点配置 ==========
	properties.append({
		name = "Target Node Configuration",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 目标节点来源
	properties.append({
		name = "target_node_source",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Node Path,Variable",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 根据目标节点来源显示不同属性
	if target_node_source == NodeSource.NODE_PATH:
		# 节点路径模式
		properties.append({
			name = "target_node",
			type = TYPE_NODE_PATH,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
	else:
		# 变量模式
		properties.append({
			name = "target_variable_name",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 变量作用域
		properties.append({
			name = "target_variable_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 只在 target_variable_scope == SCOPE 时显示 ScopeSource 配置
		if target_variable_scope == BaseVariable.VariableScope.SCOPE:
			properties.append({
				name = "target_scope_source",
				type = TYPE_INT,
				hint = PROPERTY_HINT_ENUM,
				hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

			# 根据作用域来源添加额外属性
			if target_scope_source == ScopeSource.CUSTOM_ID:
				properties.append({
					name = "target_custom_scope_id",
					type = TYPE_STRING,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})
			elif target_scope_source == ScopeSource.TARGET_NODE:
				properties.append({
					name = "target_target_node_path",
					type = TYPE_NODE_PATH,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})

	# ========== 方向检查配置 ==========
	properties.append({
		name = "Direction Check",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_GROUP
	})

	return properties

## 验证属性可见性
func _validate_property(property: Dictionary) -> void:
	# 控制源节点相关属性可见性
	if source_node_source == NodeSource.NODE_PATH:
		# NODE_PATH 模式：隐藏源节点变量相关属性
		if property.name in ["source_variable_name", "source_variable_scope", "source_scope_source", "source_custom_scope_id", "source_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		# VARIABLE 模式：隐藏源节点路径属性
		if property.name == "source_node":
			property.usage = PROPERTY_USAGE_NO_EDITOR

		# 控制源节点变量 ScopeSource 属性可见性
		if source_variable_scope == BaseVariable.VariableScope.SCOPE:
			# 手动处理源节点的 ScopeSource 属性可见性
			match source_scope_source:
				ScopeSource.CUSTOM_ID:
					# CUSTOM_ID 模式：只显示 source_custom_scope_id，隐藏 source_target_node_path
					if property.name == "source_target_node_path":
						property.usage = PROPERTY_USAGE_NO_EDITOR
				ScopeSource.TARGET_NODE:
					# TARGET_NODE 模式：只显示 source_target_node_path，隐藏 source_custom_scope_id
					if property.name == "source_custom_scope_id":
						property.usage = PROPERTY_USAGE_NO_EDITOR
				_:
					# 其他模式（NEAREST, TRIGGER_SCOPE）：隐藏两个额外属性
					if property.name in ["source_custom_scope_id", "source_target_node_path"]:
						property.usage = PROPERTY_USAGE_NO_EDITOR
		else:
			# 非 SCOPE 作用域时隐藏源节点 ScopeSource 相关属性
			if property.name in ["source_scope_source", "source_custom_scope_id", "source_target_node_path"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR

	# 控制目标节点相关属性可见性
	if target_node_source == NodeSource.NODE_PATH:
		# NODE_PATH 模式：隐藏目标节点变量相关属性
		if property.name in ["target_variable_name", "target_variable_scope", "target_scope_source", "target_custom_scope_id", "target_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		# VARIABLE 模式：隐藏目标节点路径属性
		if property.name == "target_node":
			property.usage = PROPERTY_USAGE_NO_EDITOR

		# 控制目标节点变量 ScopeSource 属性可见性
		if target_variable_scope == BaseVariable.VariableScope.SCOPE:
			# 手动处理目标节点的 ScopeSource 属性可见性
			match target_scope_source:
				ScopeSource.CUSTOM_ID:
					# CUSTOM_ID 模式：只显示 target_custom_scope_id，隐藏 target_target_node_path
					if property.name == "target_target_node_path":
						property.usage = PROPERTY_USAGE_NO_EDITOR
				ScopeSource.TARGET_NODE:
					# TARGET_NODE 模式：只显示 target_target_node_path，隐藏 target_custom_scope_id
					if property.name == "target_custom_scope_id":
						property.usage = PROPERTY_USAGE_NO_EDITOR
				_:
					# 其他模式（NEAREST, TRIGGER_SCOPE）：隐藏两个额外属性
					if property.name in ["target_custom_scope_id", "target_target_node_path"]:
						property.usage = PROPERTY_USAGE_NO_EDITOR
		else:
			# 非 SCOPE 作用域时隐藏目标节点 ScopeSource 相关属性
			if property.name in ["target_scope_source", "target_custom_scope_id", "target_target_node_path"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR

# =============================================
# 资源名称和描述
# =============================================

## 更新资源名称（必需）
func _update_resource_name() -> void:
	var source_str = _get_source_node_source_string()
	var target_str = _get_target_node_source_string()

	if source_str.is_empty() or target_str.is_empty():
		resource_name = FuseLocalization.translate("FUSE_CONDITION_DIRECTION_NOT_SET")
	else:
		var dir_name = _get_direction_name()
		# 限制长度
		if source_str.length() > 20:
			source_str = source_str.substr(0, 17) + "..."
		if target_str.length() > 20:
			target_str = target_str.substr(0, 17) + "..."
		resource_name = FuseLocalization.translate_format("FUSE_CONDITION_DIRECTION_FORMAT", {
			"source": source_str,
			"target": target_str,
			"direction": dir_name
		})

## 获取源节点来源显示字符串
func _get_source_node_source_string() -> String:
	if source_node_source == NodeSource.NODE_PATH:
		var path_str = str(source_node)
		if path_str.is_empty():
			return ""
		if path_str.length() > 40:
			path_str = path_str.substr(0, 37) + "..."
		return path_str
	else:
		if source_variable_name.is_empty():
			return ""
		var scope_str = _get_source_scope_source_string()
		return "[%s] %s" % [scope_str, source_variable_name]

## 获取目标节点来源显示字符串
func _get_target_node_source_string() -> String:
	if target_node_source == NodeSource.NODE_PATH:
		var path_str = _get_node_display_name(target_node)
		if path_str.is_empty():
			return ""
		if path_str.length() > 40:
			path_str = path_str.substr(0, 37) + "..."
		return path_str
	else:
		if target_variable_name.is_empty():
			return ""
		var scope_str = _get_target_scope_source_string()
		return "[%s] %s" % [scope_str, target_variable_name]

## 获取源节点变量作用域来源字符串
func _get_source_scope_source_string() -> String:
	match source_variable_scope:
		BaseVariable.VariableScope.LOCAL:
			return FuseLocalization.translate("FUSE_SCOPE_LOCAL_STR")
		BaseVariable.VariableScope.SCOPE:
			return VariableScopeUtils.get_scope_source_string(
				source_scope_source as VariableScopeUtils.ScopeSource,
				source_custom_scope_id,
				source_target_node_path
			)
		BaseVariable.VariableScope.GLOBAL:
			return FuseLocalization.translate("FUSE_SCOPE_GLOBAL_STR")
		_:
			return FuseLocalization.translate("FUSE_SCOPE_UNKNOWN_STR")

## 获取目标节点变量作用域来源字符串
func _get_target_scope_source_string() -> String:
	match target_variable_scope:
		BaseVariable.VariableScope.LOCAL:
			return FuseLocalization.translate("FUSE_SCOPE_LOCAL_STR")
		BaseVariable.VariableScope.SCOPE:
			return VariableScopeUtils.get_scope_source_string(
				target_scope_source as VariableScopeUtils.ScopeSource,
				target_custom_scope_id,
				target_target_node_path
			)
		BaseVariable.VariableScope.GLOBAL:
			return FuseLocalization.translate("FUSE_SCOPE_GLOBAL_STR")
		_:
			return FuseLocalization.translate("FUSE_SCOPE_UNKNOWN_STR")

# =============================================
# 条件评估
# =============================================

## 评估条件
func _evaluate_condition(context: ExecutionContext) -> bool:
	# 获取源节点
	var source = _get_source_node(context)
	if source == null:
		return false

	# 获取目标节点
	var target = _get_target_node(context)
	if target == null:
		return false

	# 获取位置
	var source_pos = source.get("global_position")
	var target_pos = target.get("global_position")

	if source_pos == null or target_pos == null:
		_log_error(FuseLocalization.translate("FUSE_ERROR_NO_GLOBAL_POSITION"))
		_create_fuse_error(FuseLocalization.translate("FUSE_ERROR_NODE_TYPE_2D_3D_REQUIRED"), FuseError.ErrorType.VALIDATION_ERROR)
		return false

	# 计算方向向量
	var direction_vector: Vector2
	if source_pos is Vector2 and target_pos is Vector2:
		direction_vector = (target_pos - source_pos).normalized()
	elif source_pos is Vector3 and target_pos is Vector3:
		var dir_3d = (target_pos - source_pos).normalized()
		direction_vector = Vector2(dir_3d.x, dir_3d.y)
	else:
		_log_error(FuseLocalization.translate("FUSE_ERROR_POSITION_TYPE_ERROR"))
		_create_fuse_error(FuseLocalization.translate("FUSE_ERROR_POSITION_TYPE_VECTOR"), FuseError.ErrorType.VALIDATION_ERROR)
		return false

	# 检查方向
	var is_match = _check_direction(direction_vector)

	var log_msg = FuseLocalization.translate_format("FUSE_LOG_DIRECTION_CHECK", {
		"target": _get_target_node_source_string(),
		"source": _get_source_node_source_string(),
		"direction": _get_direction_name(),
		"result": "匹配" if is_match else "不匹配"
	})
	_log_debug(log_msg)

	return is_match

## 获取源节点
func _get_source_node(context: ExecutionContext) -> Node:
	if source_node_source == NodeSource.NODE_PATH:
		return _get_source_node_by_path(context)
	else:
		return _get_source_node_by_variable(context)

## 获取目标节点
func _get_target_node(context: ExecutionContext) -> Node:
	if target_node_source == NodeSource.NODE_PATH:
		return _get_target_node_by_path(context)
	else:
		return _get_target_node_by_variable(context)

## 通过节点路径获取源节点
func _get_source_node_by_path(context: ExecutionContext) -> Node:
	# 验证节点路径
	if source_node.is_empty():
		var error_msg = FuseLocalization.translate("FUSE_ERROR_SOURCE_NODE_EMPTY")
		_log_error(error_msg)
		_create_fuse_error(error_msg, FuseError.ErrorType.VALIDATION_ERROR)
		return null

	# 获取节点
	var node = context.get_node(source_node)
	if node == null:
		var error_msg = FuseLocalization.translate("FUSE_ERROR_SOURCE_NODE_NOT_FOUND") % str(source_node)
		_log_error(error_msg)
		_create_fuse_error(error_msg, FuseError.ErrorType.RUNTIME_ERROR)
		return null

	return node

## 通过变量获取源节点
func _get_source_node_by_variable(context: ExecutionContext) -> Node:
	# 验证变量名
	if source_variable_name.is_empty():
		var error_msg = FuseLocalization.translate("FUSE_ERROR_VAR_NAME_EMPTY")
		_log_error(error_msg)
		_create_fuse_error(error_msg, FuseError.ErrorType.VALIDATION_ERROR)
		return null

	# 获取变量值
	var node_value = _get_source_node_variable_value(context)

	# 验证变量值
	if node_value == null:
		var error_msg = FuseLocalization.translate_format("FUSE_ERROR_NODE_VARIABLE_IS_NULL", {"name": source_variable_name})
		_log_error(error_msg)
		_create_fuse_error(error_msg, FuseError.ErrorType.RUNTIME_ERROR)
		return null

	# 处理不同类型的节点值
	var node: Node = null
	if node_value is Node:
		node = node_value
	elif node_value is NodePath:
		node = context.get_node(node_value)
		if node == null:
			var error_msg = FuseLocalization.translate("FUSE_ERROR_SOURCE_NODE_NOT_FOUND") % str(node_value)
			_log_error(error_msg)
			_create_fuse_error(error_msg, FuseError.ErrorType.RUNTIME_ERROR)
			return null
	elif node_value is String and not node_value.is_empty():
		# 尝试作为节点路径解析
		node = context.get_node(NodePath(node_value))
		if node == null:
			var error_msg = FuseLocalization.translate("FUSE_ERROR_SOURCE_NODE_NOT_FOUND") % node_value
			_log_error(error_msg)
			_create_fuse_error(error_msg, FuseError.ErrorType.RUNTIME_ERROR)
			return null
	else:
		var error_msg = FuseLocalization.translate_format("FUSE_ERROR_NODE_VARIABLE_INVALID_TYPE", {"name": source_variable_name, "type": str(typeof(node_value))})
		_log_error(error_msg)
		_create_fuse_error(error_msg, FuseError.ErrorType.RUNTIME_ERROR)
		return null

	return node

## 通过节点路径获取目标节点
func _get_target_node_by_path(context: ExecutionContext) -> Node:
	# 验证节点路径
	if target_node.is_empty():
		var error_msg = FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY")
		_log_error(error_msg)
		_create_fuse_error(error_msg, FuseError.ErrorType.VALIDATION_ERROR)
		return null

	# 获取节点
	var node = context.get_node(target_node)
	if node == null:
		var error_msg = FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_NOT_FOUND") % str(target_node)
		_log_error(error_msg)
		_create_fuse_error(error_msg, FuseError.ErrorType.RUNTIME_ERROR)
		return null

	return node

## 通过变量获取目标节点
func _get_target_node_by_variable(context: ExecutionContext) -> Node:
	# 验证变量名
	if target_variable_name.is_empty():
		var error_msg = FuseLocalization.translate("FUSE_ERROR_VAR_NAME_EMPTY")
		_log_error(error_msg)
		_create_fuse_error(error_msg, FuseError.ErrorType.VALIDATION_ERROR)
		return null

	# 获取变量值
	var node_value = _get_target_node_variable_value(context)

	# 验证变量值
	if node_value == null:
		var error_msg = FuseLocalization.translate_format("FUSE_ERROR_NODE_VARIABLE_IS_NULL", {"name": target_variable_name})
		_log_error(error_msg)
		_create_fuse_error(error_msg, FuseError.ErrorType.RUNTIME_ERROR)
		return null

	# 处理不同类型的节点值
	var node: Node = null
	if node_value is Node:
		node = node_value
	elif node_value is NodePath:
		node = context.get_node(node_value)
		if node == null:
			var error_msg = FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_NOT_FOUND") % str(node_value)
			_log_error(error_msg)
			_create_fuse_error(error_msg, FuseError.ErrorType.RUNTIME_ERROR)
			return null
	elif node_value is String and not node_value.is_empty():
		# 尝试作为节点路径解析
		node = context.get_node(NodePath(node_value))
		if node == null:
			var error_msg = FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_NOT_FOUND") % node_value
			_log_error(error_msg)
			_create_fuse_error(error_msg, FuseError.ErrorType.RUNTIME_ERROR)
			return null
	else:
		var error_msg = FuseLocalization.translate_format("FUSE_ERROR_NODE_VARIABLE_INVALID_TYPE", {"name": target_variable_name, "type": str(typeof(node_value))})
		_log_error(error_msg)
		_create_fuse_error(error_msg, FuseError.ErrorType.RUNTIME_ERROR)
		return null

	return node

## 获取源节点变量值
func _get_source_node_variable_value(context: ExecutionContext) -> Variant:
	var value: Variant = null

	match source_variable_scope:
		BaseVariable.VariableScope.LOCAL:
			# LOCAL 模式：使用 VariableOperations
			value = VariableOperations.get_variable(context, source_variable_name, BaseVariable.VariableScope.LOCAL, null)

		BaseVariable.VariableScope.GLOBAL:
			# GLOBAL 模式：使用 VariableOperations
			value = VariableOperations.get_variable(context, source_variable_name, BaseVariable.VariableScope.GLOBAL, null)

		BaseVariable.VariableScope.SCOPE:
			# SCOPE 模式：根据 ScopeSource 获取作用域容器
			if source_scope_source == ScopeSource.NEAREST:
				# NEAREST 模式：使用 VariableOperations
				value = VariableOperations.get_variable(context, source_variable_name, BaseVariable.VariableScope.SCOPE, null)
			else:
				# 其他模式：获取指定作用域容器并读取变量
				var utils_scope_source = source_scope_source as VariableScopeUtils.ScopeSource
				var scope_container = VariableScopeUtils.get_scope_container_by_source(
					context,
					utils_scope_source,
					source_custom_scope_id,
					source_target_node_path
				)

				if scope_container != null and scope_container.has_variable(source_variable_name):
					value = scope_container.get_variable(source_variable_name)

	return value

## 获取目标节点变量值
func _get_target_node_variable_value(context: ExecutionContext) -> Variant:
	var value: Variant = null

	match target_variable_scope:
		BaseVariable.VariableScope.LOCAL:
			# LOCAL 模式：使用 VariableOperations
			value = VariableOperations.get_variable(context, target_variable_name, BaseVariable.VariableScope.LOCAL, null)

		BaseVariable.VariableScope.GLOBAL:
			# GLOBAL 模式：使用 VariableOperations
			value = VariableOperations.get_variable(context, target_variable_name, BaseVariable.VariableScope.GLOBAL, null)

		BaseVariable.VariableScope.SCOPE:
			# SCOPE 模式：根据 ScopeSource 获取作用域容器
			if target_scope_source == ScopeSource.NEAREST:
				# NEAREST 模式：使用 VariableOperations
				value = VariableOperations.get_variable(context, target_variable_name, BaseVariable.VariableScope.SCOPE, null)
			else:
				# 其他模式：获取指定作用域容器并读取变量
				var utils_scope_source = target_scope_source as VariableScopeUtils.ScopeSource
				var scope_container = VariableScopeUtils.get_scope_container_by_source(
					context,
					utils_scope_source,
					target_custom_scope_id,
					target_target_node_path
				)

				if scope_container != null and scope_container.has_variable(target_variable_name):
					value = scope_container.get_variable(target_variable_name)

	return value

# =============================================
# 方向检查逻辑
# =============================================

## 检查方向
func _check_direction(direction: Vector2) -> bool:
	var angle = rad_to_deg(direction.angle())
	match expected_direction:
		0:  # 上
			return abs(angle) <= tolerance or abs(angle - 360) <= tolerance
		1:  # 下
			return abs(abs(angle) - 180) <= tolerance
		2:  # 左
			return abs(angle - 90) <= tolerance or abs(angle + 270) <= tolerance
		3:  # 右
			return abs(angle + 90) <= tolerance or abs(angle - 270) <= tolerance
		_:
			return false

## 获取方向名称
func _get_direction_name() -> String:
	match expected_direction:
		0: return FuseLocalization.translate("FUSE_DIRECTION_UP")
		1: return FuseLocalization.translate("FUSE_DIRECTION_DOWN")
		2: return FuseLocalization.translate("FUSE_DIRECTION_LEFT")
		3: return FuseLocalization.translate("FUSE_DIRECTION_RIGHT")
		_: return FuseLocalization.translate("FUSE_DIRECTION_UNKNOWN")

# =============================================
# 依赖计算
# =============================================

## 计算依赖
func _compute_dependencies() -> Array[String]:
	var dependencies: Array[String] = []

	# 如果源节点使用变量模式，添加变量依赖
	if source_node_source == NodeSource.VARIABLE and not source_variable_name.is_empty():
		dependencies.append(source_variable_name)

	# 如果目标节点使用变量模式，添加变量依赖
	if target_node_source == NodeSource.VARIABLE and not target_variable_name.is_empty():
		dependencies.append(target_variable_name)

	return dependencies

# =============================================
# 条件信息
# =============================================

## 获取条件类型
func get_condition_type() -> String:
	return "direction"

## 获取条件分类
func get_condition_category() -> String:
	return "node"

## 声明变量读写模式（精确化静态分析）
## source/target_variable_name 仅 read（VARIABLE 来源读取存节点引用的变量）
func get_variable_modes() -> Array[Dictionary]:
	return [
		{"name": "source_variable_name", "mode": "read"},
		{"name": "target_variable_name", "mode": "read"},
	]

## 获取条件描述
func get_description() -> String:
	var source_str = _get_source_node_source_string()
	var target_str = _get_target_node_source_string()

	if source_str.is_empty() or target_str.is_empty():
		return FuseLocalization.translate("FUSE_CONDITION_DIRECTION_NOT_SET")

	var dir_name = _get_direction_name()
	var desc = FuseLocalization.translate_format("FUSE_CONDITION_DIRECTION_DESC_FORMAT", {
		"target": target_str,
		"source": source_str,
		"direction": dir_name
	})

	# 限制描述长度
	if desc.length() > 50:
		desc = desc.substr(0, 47) + "..."

	return desc

# =============================================
# 验证
# =============================================

## 验证条件
func validate() -> Array[String]:
	var errors = super.validate()

	# 根据源节点来源验证
	if source_node_source == NodeSource.NODE_PATH:
		if source_node.is_empty():
			errors.append(FuseLocalization.translate("FUSE_ERROR_SOURCE_NODE_EMPTY"))
	else:
		# VARIABLE 模式验证
		if source_variable_name.is_empty():
			errors.append(FuseLocalization.translate("FUSE_ERROR_VAR_NAME_EMPTY"))

		# 验证 SCOPE 作用域时才验证 ScopeSource 参数
		if source_variable_scope == BaseVariable.VariableScope.SCOPE:
			var utils_scope_source = source_scope_source as VariableScopeUtils.ScopeSource
			errors.append_array(VariableScopeUtils.validate_scope_source_params(
				utils_scope_source,
				source_custom_scope_id,
				source_target_node_path
			))

	# 根据目标节点来源验证
	if target_node_source == NodeSource.NODE_PATH:
		if target_node.is_empty():
			errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))
	else:
		# VARIABLE 模式验证
		if target_variable_name.is_empty():
			errors.append(FuseLocalization.translate("FUSE_ERROR_VAR_NAME_EMPTY"))

		# 验证 SCOPE 作用域时才验证 ScopeSource 参数
		if target_variable_scope == BaseVariable.VariableScope.SCOPE:
			var utils_scope_source = target_scope_source as VariableScopeUtils.ScopeSource
			errors.append_array(VariableScopeUtils.validate_scope_source_params(
				utils_scope_source,
				target_custom_scope_id,
				target_target_node_path
			))

	if tolerance < 0 or tolerance > 180:
		errors.append(FuseLocalization.translate("FUSE_ERROR_TOLERANCE_RANGE"))

	return errors

# =============================================
# 参数方法
# =============================================

## 获取参数
func get_parameters() -> Dictionary:
	var params = {
		"source_node_source": source_node_source,
		"target_node_source": target_node_source,
		"expected_direction": expected_direction,
		"tolerance": tolerance
	}

	# 源节点参数
	if source_node_source == NodeSource.NODE_PATH:
		params["source_node"] = source_node
	else:
		params["source_variable_name"] = source_variable_name
		params["source_variable_scope"] = source_variable_scope

		# 只在 SCOPE 作用域时添加 ScopeSource 参数
		if source_variable_scope == BaseVariable.VariableScope.SCOPE:
			params["source_scope_source"] = source_scope_source
			params["source_custom_scope_id"] = source_custom_scope_id
			params["source_target_node_path"] = source_target_node_path

	# 目标节点参数
	if target_node_source == NodeSource.NODE_PATH:
		params["target_node"] = target_node
	else:
		params["target_variable_name"] = target_variable_name
		params["target_variable_scope"] = target_variable_scope

		# 只在 SCOPE 作用域时添加 ScopeSource 参数
		if target_variable_scope == BaseVariable.VariableScope.SCOPE:
			params["target_scope_source"] = target_scope_source
			params["target_custom_scope_id"] = target_custom_scope_id
			params["target_target_node_path"] = target_target_node_path

	return params

## 设置参数
func set_parameters(parameters: Dictionary):
	# 源节点参数
	if parameters.has("source_node_source"):
		source_node_source = parameters["source_node_source"]
	if parameters.has("source_node"):
		source_node = parameters["source_node"]
	if parameters.has("source_variable_name"):
		source_variable_name = parameters["source_variable_name"]
	if parameters.has("source_variable_scope"):
		source_variable_scope = parameters["source_variable_scope"]
	if parameters.has("source_scope_source"):
		source_scope_source = parameters["source_scope_source"]
	if parameters.has("source_custom_scope_id"):
		source_custom_scope_id = parameters["source_custom_scope_id"]
	if parameters.has("source_target_node_path"):
		source_target_node_path = parameters["source_target_node_path"]

	# 目标节点参数
	if parameters.has("target_node_source"):
		target_node_source = parameters["target_node_source"]
	if parameters.has("target_node"):
		target_node = parameters["target_node"]
	if parameters.has("target_variable_name"):
		target_variable_name = parameters["target_variable_name"]
	if parameters.has("target_variable_scope"):
		target_variable_scope = parameters["target_variable_scope"]
	if parameters.has("target_scope_source"):
		target_scope_source = parameters["target_scope_source"]
	if parameters.has("target_custom_scope_id"):
		target_custom_scope_id = parameters["target_custom_scope_id"]
	if parameters.has("target_target_node_path"):
		target_target_node_path = parameters["target_target_node_path"]

	# 方向检查参数
	if parameters.has("expected_direction"):
		expected_direction = parameters["expected_direction"]
	if parameters.has("tolerance"):
		tolerance = parameters["tolerance"]

# =============================================
# 元数据
# =============================================

## 获取条件元数据
static func _get_condition_metadata() -> ConditionMetadata:
	var metadata = ConditionMetadata.new()
	metadata.name_key = "FUSE_CONDITION_DIRECTION_NAME"
	metadata.category_key = "FUSE_CATEGORY_NODE"
	metadata.description_key = "FUSE_CONDITION_DIRECTION_DESC"
	metadata.keywords = ["方位", "direction", "方向", "位置", "position", "相对", "relative", "变量", "variable"]
	metadata.builtin_icon = "Performance"
	return metadata
