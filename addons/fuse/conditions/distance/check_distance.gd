@tool
@icon("res://addons/fuse/icons/builtin/Geometry3D.png")
extends BaseCondition
class_name CheckDistance

## 对象距离条件
##
## 检查两个节点之间的距离是否满足条件。用于触发器、范围检测等场景。
##
## 支持两种节点来源：
## - NODE_PATH: 通过节点路径直接指定
## - VARIABLE: 从变量获取节点（支持三层变量作用域）

## 比较操作符枚举
enum ComparisonOperator {
	GREATER_THAN,     ## 大于 (>)
	LESS_THAN,        ## 小于 (<)
	EQUAL             ## 等于 (≈)
}

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
# 距离检查参数定义
# =============================================

## 比较操作符
var comparison_operator: ComparisonOperator = ComparisonOperator.LESS_THAN:
	set(value):
		comparison_operator = value
		_update_resource_name()

## 距离阈值
var threshold: float = 100.0:
	set(value):
		threshold = value
		_update_resource_name()

## 是否使用平方距离（避免开方运算，性能优化）
var use_squared_distance: bool = false

## 等于比较的容差范围
var equality_tolerance: float = 1.0

## 私有属性
var _last_distance: float = 0.0

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

	# ========== 距离检查配置 ==========
	properties.append({
		name = "Distance Check",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_GROUP
	})

	# 比较操作符
	properties.append({
		name = "comparison_operator",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Greater Than,Less Than,Equal",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 距离阈值
	properties.append({
		name = "threshold",
		type = TYPE_FLOAT,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "0.0,10000.0,1.0",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 是否使用平方距离
	properties.append({
		name = "use_squared_distance",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		hint_string = "",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 等于比较的容差范围
	properties.append({
		name = "equality_tolerance",
		type = TYPE_FLOAT,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "0.0,100.0,0.1",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
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

	# 限制长度
	if source_str.length() > 20:
		source_str = source_str.substr(0, 17) + "..."
	if target_str.length() > 20:
		target_str = target_str.substr(0, 17) + "..."

	var operator_str = _get_operator_name()
	resource_name = FuseLocalization.translate_format("FUSE_CONDITION_DISTANCE_RESOURCE", {"source": source_str, "operator": operator_str, "threshold": threshold})

## 获取源节点来源显示字符串
func _get_source_node_source_string() -> String:
	if source_node_source == NodeSource.NODE_PATH:
		var path_str = _get_node_display_name(source_node)
		if path_str.is_empty():
			return FuseLocalization.translate("FUSE_CONDITION_NOT_SET")
		if path_str.length() > 40:
			path_str = path_str.substr(0, 37) + "..."
		return path_str
	else:
		if source_variable_name.is_empty():
			return FuseLocalization.translate("FUSE_CONDITION_NOT_SET")
		var scope_str = _get_source_scope_source_string()
		return "[%s] %s" % [scope_str, source_variable_name]

## 获取目标节点来源显示字符串
func _get_target_node_source_string() -> String:
	if target_node_source == NodeSource.NODE_PATH:
		var path_str = _get_node_display_name(target_node)
		if path_str.is_empty():
			return FuseLocalization.translate("FUSE_CONDITION_NOT_SET")
		if path_str.length() > 40:
			path_str = path_str.substr(0, 37) + "..."
		return path_str
	else:
		if target_variable_name.is_empty():
			return FuseLocalization.translate("FUSE_CONDITION_NOT_SET")
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

	# 检查节点是否有 global_position
	if not source.has_method("get") or not source.get("global_position"):
		var error_msg = FuseLocalization.translate("FUSE_CONDITION_ERROR_SOURCE_NO_GLOBAL_POSITION")
		_log_error(error_msg)
		_create_fuse_error(error_msg, FuseError.ErrorType.RUNTIME_ERROR)
		return false

	if not target.has_method("get") or not target.get("global_position"):
		var error_msg = FuseLocalization.translate("FUSE_CONDITION_ERROR_TARGET_NO_GLOBAL_POSITION")
		_log_error(error_msg)
		_create_fuse_error(error_msg, FuseError.ErrorType.RUNTIME_ERROR)
		return false

	# 计算距离
	var source_pos = source.global_position
	var target_pos = target.global_position

	var distance: float
	if use_squared_distance:
		# 使用平方距离（避免开方运算）
		distance = source_pos.distance_squared_to(target_pos)
		var threshold_squared = threshold * threshold
		_last_distance = sqrt(distance)  # 存储实际距离用于调试
	else:
		# 使用实际距离
		distance = source_pos.distance_to(target_pos)
		_last_distance = distance

	# 根据比较操作符进行判断
	var result = false
	match comparison_operator:
		ComparisonOperator.GREATER_THAN:
			var compare_threshold = threshold * threshold if use_squared_distance else threshold
			result = distance > compare_threshold
		ComparisonOperator.LESS_THAN:
			var compare_threshold = threshold * threshold if use_squared_distance else threshold
			result = distance < compare_threshold
		ComparisonOperator.EQUAL:
			var actual_distance = sqrt(distance) if use_squared_distance else distance
			result = abs(actual_distance - threshold) <= equality_tolerance
		_:
			_log_error(FuseLocalization.translate_format("FUSE_CONDITION_ERROR_UNKNOWN_OPERATOR", {"operator": comparison_operator}))
			return false

	_log_debug(FuseLocalization.translate_format(
		"FUSE_CONDITION_LOG_DISTANCE_CHECK",
		{"source": _get_source_node_source_string(), "target": _get_target_node_source_string(), "distance": _last_distance, "operator": _get_operator_name(), "result": "true" if result else "false"}
	))

	return result

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
		var error_msg = FuseLocalization.translate("FUSE_CONDITION_ERROR_SOURCE_NODE_EMPTY")
		_log_error(error_msg)
		_create_fuse_error(error_msg, FuseError.ErrorType.VALIDATION_ERROR)
		return null

	# 获取节点
	var node = context.get_node(source_node)
	if node == null:
		var error_msg = FuseLocalization.translate_format("FUSE_CONDITION_ERROR_SOURCE_NODE_NOT_FOUND", {"node": str(source_node)})
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
			var error_msg = FuseLocalization.translate("FUSE_CONDITION_ERROR_SOURCE_NODE_NOT_FOUND") % str(node_value)
			_log_error(error_msg)
			_create_fuse_error(error_msg, FuseError.ErrorType.RUNTIME_ERROR)
			return null
	elif node_value is String and not node_value.is_empty():
		# 尝试作为节点路径解析
		node = context.get_node(NodePath(node_value))
		if node == null:
			var error_msg = FuseLocalization.translate("FUSE_CONDITION_ERROR_SOURCE_NODE_NOT_FOUND") % node_value
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
		var error_msg = FuseLocalization.translate("FUSE_CONDITION_ERROR_TARGET_NODE_EMPTY")
		_log_error(error_msg)
		_create_fuse_error(error_msg, FuseError.ErrorType.VALIDATION_ERROR)
		return null

	# 获取节点
	var node = context.get_node(target_node)
	if node == null:
		var error_msg = FuseLocalization.translate_format("FUSE_CONDITION_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(target_node)})
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
			var error_msg = FuseLocalization.translate("FUSE_CONDITION_ERROR_TARGET_NODE_NOT_FOUND") % str(node_value)
			_log_error(error_msg)
			_create_fuse_error(error_msg, FuseError.ErrorType.RUNTIME_ERROR)
			return null
	elif node_value is String and not node_value.is_empty():
		# 尝试作为节点路径解析
		node = context.get_node(NodePath(node_value))
		if node == null:
			var error_msg = FuseLocalization.translate("FUSE_CONDITION_ERROR_TARGET_NODE_NOT_FOUND") % node_value
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
	return "distance"

## 获取条件分类
func get_condition_category() -> String:
	return "distance"

## 获取条件描述
func get_description() -> String:
	var source_str = _get_source_node_source_string()
	var target_str = _get_target_node_source_string()

	var desc = FuseLocalization.translate_format("FUSE_CONDITION_DISTANCE_DESC",
		{"source": source_str, "operator": _get_operator_symbol(), "target": target_str, "threshold": threshold})

	# 限制描述长度
	if desc.length() > 50:
		desc = desc.substr(0, 47) + "..."

	return desc

## 获取操作符名称
func _get_operator_name() -> String:
	match comparison_operator:
		ComparisonOperator.GREATER_THAN: return ">"
		ComparisonOperator.LESS_THAN: return "<"
		ComparisonOperator.EQUAL: return "≈"
		_: return "?"

## 获取操作符符号
func _get_operator_symbol() -> String:
	match comparison_operator:
		ComparisonOperator.GREATER_THAN: return ">"
		ComparisonOperator.LESS_THAN: return "<"
		ComparisonOperator.EQUAL: return "≈"
		_: return "?"

# =============================================
# 验证
# =============================================

## 验证条件
func validate() -> Array[String]:
	var errors = super.validate()

	# 根据源节点来源验证
	if source_node_source == NodeSource.NODE_PATH:
		if source_node.is_empty():
			errors.append(FuseLocalization.translate("FUSE_CONDITION_ERROR_SOURCE_NODE_EMPTY"))
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
			errors.append(FuseLocalization.translate("FUSE_CONDITION_ERROR_TARGET_NODE_EMPTY"))
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

	if threshold < 0:
		errors.append(FuseLocalization.translate("FUSE_CONDITION_ERROR_THRESHOLD_NEGATIVE"))

	if comparison_operator == ComparisonOperator.EQUAL and equality_tolerance < 0:
		errors.append(FuseLocalization.translate("FUSE_CONDITION_ERROR_TOLERANCE_NEGATIVE"))

	return errors

# =============================================
# 参数方法
# =============================================

## 获取参数
func get_parameters() -> Dictionary:
	var params = {
		"source_node_source": source_node_source,
		"target_node_source": target_node_source,
		"comparison_operator": comparison_operator,
		"threshold": threshold,
		"use_squared_distance": use_squared_distance,
		"equality_tolerance": equality_tolerance
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

	# 距离检查参数
	if parameters.has("comparison_operator"):
		comparison_operator = parameters["comparison_operator"]
	if parameters.has("threshold"):
		threshold = parameters["threshold"]
	if parameters.has("use_squared_distance"):
		use_squared_distance = parameters["use_squared_distance"]
	if parameters.has("equality_tolerance"):
		equality_tolerance = parameters["equality_tolerance"]

# =============================================
# 详细信息
# =============================================

## 获取详细条件信息
func get_detailed_info() -> Dictionary:
	var info = super.get_detailed_info()
	info["source_node_source"] = _get_source_node_source_string()
	info["target_node_source"] = _get_target_node_source_string()
	info["comparison_operator"] = _get_operator_name()
	info["threshold"] = threshold
	info["use_squared_distance"] = use_squared_distance
	info["equality_tolerance"] = equality_tolerance
	info["last_distance"] = _last_distance
	return info

## 重置条件状态
func reset():
	super.reset()
	_last_distance = 0.0
	_log_debug("ConditionDistance reset")

# =============================================
# 元数据
# =============================================

## 获取条件元数据
static func _get_condition_metadata() -> ConditionMetadata:
	var metadata = ConditionMetadata.new()
	metadata.name_key = "FUSE_CONDITION_DISTANCE_NAME"
	metadata.category_key = "FUSE_CATEGORY_DISTANCE"
	metadata.description_key = "FUSE_CONDITION_DISTANCE_DESC"
	metadata.keywords = ["距离", "distance", "position", "位置", "range", "范围", "trigger", "触发器", "proximity", "接近", "变量", "variable"]
	metadata.builtin_icon = "Geometry3D"
	return metadata
