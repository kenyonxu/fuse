@tool
@icon("res://addons/fuse/icons/builtin/Node.png")
extends BaseCondition
class_name CheckIsChildOf

## 节点层次关系条件
##
## 检查节点是否是另一个节点的子节点。
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
# 子节点参数定义
# =============================================

## 子节点来源
var child_node_source: NodeSource = NodeSource.NODE_PATH:
	set(value):
		child_node_source = value
		_update_resource_name()
		notify_property_list_changed()

## 子节点路径
var child_node: NodePath = NodePath(""):
	set(value):
		child_node = value
		_update_resource_name()

## 子节点变量名（当 child_node_source == VARIABLE 时使用）
var child_variable_name: String = "":
	set(value):
		child_variable_name = value
		_update_resource_name()

## 子节点变量作用域（三层变量系统）
var child_variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		child_variable_scope = value
		_update_resource_name()
		notify_property_list_changed()

## 子节点变量作用域来源（仅当 child_variable_scope == SCOPE 时使用）
var child_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		child_scope_source = value
		_update_resource_name()
		notify_property_list_changed()

## 子节点变量自定义作用域 ID（仅当 child_scope_source == CUSTOM_ID 时使用）
var child_custom_scope_id: String = "":
	set(value):
		child_custom_scope_id = value
		_update_resource_name()

## 子节点变量目标节点路径（仅当 child_scope_source == TARGET_NODE 时使用）
var child_target_node_path: NodePath = NodePath(""):
	set(value):
		child_target_node_path = value
		_update_resource_name()

# =============================================
# 父节点参数定义
# =============================================

## 父节点来源
var parent_node_source: NodeSource = NodeSource.NODE_PATH:
	set(value):
		parent_node_source = value
		_update_resource_name()
		notify_property_list_changed()

## 父节点路径
var parent_node: NodePath = NodePath(""):
	set(value):
		parent_node = value
		_update_resource_name()

## 父节点变量名（当 parent_node_source == VARIABLE 时使用）
var parent_variable_name: String = "":
	set(value):
		parent_variable_name = value
		_update_resource_name()

## 父节点变量作用域（三层变量系统）
var parent_variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		parent_variable_scope = value
		_update_resource_name()
		notify_property_list_changed()

## 父节点变量作用域来源（仅当 parent_variable_scope == SCOPE 时使用）
var parent_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		parent_scope_source = value
		_update_resource_name()
		notify_property_list_changed()

## 父节点变量自定义作用域 ID（仅当 parent_scope_source == CUSTOM_ID 时使用）
var parent_custom_scope_id: String = "":
	set(value):
		parent_custom_scope_id = value
		_update_resource_name()

## 父节点变量目标节点路径（仅当 parent_scope_source == TARGET_NODE 时使用）
var parent_target_node_path: NodePath = NodePath(""):
	set(value):
		parent_target_node_path = value
		_update_resource_name()

# =============================================
# 动态属性列表
# =============================================

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties := []

	# ========== 子节点配置 ==========
	properties.append({
		name = "Child Node Configuration",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 子节点来源
	properties.append({
		name = "child_node_source",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Node Path,Variable",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 根据子节点来源显示不同属性
	if child_node_source == NodeSource.NODE_PATH:
		# 节点路径模式
		properties.append({
			name = "child_node",
			type = TYPE_NODE_PATH,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
	else:
		# 变量模式
		properties.append({
			name = "child_variable_name",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 变量作用域
		properties.append({
			name = "child_variable_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 只在 child_variable_scope == SCOPE 时显示 ScopeSource 配置
		if child_variable_scope == BaseVariable.VariableScope.SCOPE:
			properties.append({
				name = "child_scope_source",
				type = TYPE_INT,
				hint = PROPERTY_HINT_ENUM,
				hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

			# 根据作用域来源添加额外属性
			if child_scope_source == ScopeSource.CUSTOM_ID:
				properties.append({
					name = "child_custom_scope_id",
					type = TYPE_STRING,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})
			elif child_scope_source == ScopeSource.TARGET_NODE:
				properties.append({
					name = "child_target_node_path",
					type = TYPE_NODE_PATH,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})

	# ========== 父节点配置 ==========
	properties.append({
		name = "Parent Node Configuration",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 父节点来源
	properties.append({
		name = "parent_node_source",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Node Path,Variable",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 根据父节点来源显示不同属性
	if parent_node_source == NodeSource.NODE_PATH:
		# 节点路径模式
		properties.append({
			name = "parent_node",
			type = TYPE_NODE_PATH,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
	else:
		# 变量模式
		properties.append({
			name = "parent_variable_name",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 变量作用域
		properties.append({
			name = "parent_variable_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 只在 parent_variable_scope == SCOPE 时显示 ScopeSource 配置
		if parent_variable_scope == BaseVariable.VariableScope.SCOPE:
			properties.append({
				name = "parent_scope_source",
				type = TYPE_INT,
				hint = PROPERTY_HINT_ENUM,
				hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

			# 根据作用域来源添加额外属性
			if parent_scope_source == ScopeSource.CUSTOM_ID:
				properties.append({
					name = "parent_custom_scope_id",
					type = TYPE_STRING,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})
			elif parent_scope_source == ScopeSource.TARGET_NODE:
				properties.append({
					name = "parent_target_node_path",
					type = TYPE_NODE_PATH,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})

	return properties

## 验证属性可见性
func _validate_property(property: Dictionary) -> void:
	# 控制子节点相关属性可见性
	if child_node_source == NodeSource.NODE_PATH:
		# NODE_PATH 模式：隐藏子节点变量相关属性
		if property.name in ["child_variable_name", "child_variable_scope", "child_scope_source", "child_custom_scope_id", "child_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		# VARIABLE 模式：隐藏子节点路径属性
		if property.name == "child_node":
			property.usage = PROPERTY_USAGE_NO_EDITOR

		# 控制子节点变量 ScopeSource 属性可见性
		if child_variable_scope == BaseVariable.VariableScope.SCOPE:
			# 手动处理子节点的 ScopeSource 属性可见性
			match child_scope_source:
				ScopeSource.CUSTOM_ID:
					# CUSTOM_ID 模式：只显示 child_custom_scope_id，隐藏 child_target_node_path
					if property.name == "child_target_node_path":
						property.usage = PROPERTY_USAGE_NO_EDITOR
				ScopeSource.TARGET_NODE:
					# TARGET_NODE 模式：只显示 child_target_node_path，隐藏 child_custom_scope_id
					if property.name == "child_custom_scope_id":
						property.usage = PROPERTY_USAGE_NO_EDITOR
				_:
					# 其他模式（NEAREST, TRIGGER_SCOPE）：隐藏两个额外属性
					if property.name in ["child_custom_scope_id", "child_target_node_path"]:
						property.usage = PROPERTY_USAGE_NO_EDITOR
		else:
			# 非 SCOPE 作用域时隐藏子节点 ScopeSource 相关属性
			if property.name in ["child_scope_source", "child_custom_scope_id", "child_target_node_path"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR

	# 控制父节点相关属性可见性
	if parent_node_source == NodeSource.NODE_PATH:
		# NODE_PATH 模式：隐藏父节点变量相关属性
		if property.name in ["parent_variable_name", "parent_variable_scope", "parent_scope_source", "parent_custom_scope_id", "parent_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		# VARIABLE 模式：隐藏父节点路径属性
		if property.name == "parent_node":
			property.usage = PROPERTY_USAGE_NO_EDITOR

		# 控制父节点变量 ScopeSource 属性可见性
		if parent_variable_scope == BaseVariable.VariableScope.SCOPE:
			# 手动处理父节点的 ScopeSource 属性可见性
			match parent_scope_source:
				ScopeSource.CUSTOM_ID:
					# CUSTOM_ID 模式：只显示 parent_custom_scope_id，隐藏 parent_target_node_path
					if property.name == "parent_target_node_path":
						property.usage = PROPERTY_USAGE_NO_EDITOR
				ScopeSource.TARGET_NODE:
					# TARGET_NODE 模式：只显示 parent_target_node_path，隐藏 parent_custom_scope_id
					if property.name == "parent_custom_scope_id":
						property.usage = PROPERTY_USAGE_NO_EDITOR
				_:
					# 其他模式（NEAREST, TRIGGER_SCOPE）：隐藏两个额外属性
					if property.name in ["parent_custom_scope_id", "parent_target_node_path"]:
						property.usage = PROPERTY_USAGE_NO_EDITOR
		else:
			# 非 SCOPE 作用域时隐藏父节点 ScopeSource 相关属性
			if property.name in ["parent_scope_source", "parent_custom_scope_id", "parent_target_node_path"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR

# =============================================
# 资源名称和描述
# =============================================

## 更新资源名称（必需）
func _update_resource_name() -> void:
	var child_str = _get_child_node_source_string()
	var parent_str = _get_parent_node_source_string()

	if child_str.is_empty() or parent_str.is_empty():
		resource_name = FuseLocalization.translate("FUSE_CONDITION_HIERARCHY_NOT_SET")
	else:
		# 限制长度
		if child_str.length() > 20:
			child_str = child_str.substr(0, 17) + "..."
		if parent_str.length() > 20:
			parent_str = parent_str.substr(0, 17) + "..."
		resource_name = FuseLocalization.translate_format("FUSE_CONDITION_IS_CHILD_OF_FORMAT", {
			"child": child_str,
			"parent": parent_str
		})

## 获取子节点来源显示字符串
func _get_child_node_source_string() -> String:
	if child_node_source == NodeSource.NODE_PATH:
		var path_str = _get_node_display_name(child_node)
		if path_str.is_empty():
			return ""
		if path_str.length() > 40:
			path_str = path_str.substr(0, 37) + "..."
		return path_str
	else:
		if child_variable_name.is_empty():
			return ""
		var scope_str = _get_child_scope_source_string()
		return "[%s] %s" % [scope_str, child_variable_name]

## 获取父节点来源显示字符串
func _get_parent_node_source_string() -> String:
	if parent_node_source == NodeSource.NODE_PATH:
		var path_str = _get_node_display_name(parent_node)
		if path_str.is_empty():
			return ""
		if path_str.length() > 40:
			path_str = path_str.substr(0, 37) + "..."
		return path_str
	else:
		if parent_variable_name.is_empty():
			return ""
		var scope_str = _get_parent_scope_source_string()
		return "[%s] %s" % [scope_str, parent_variable_name]

## 获取子节点变量作用域来源字符串
func _get_child_scope_source_string() -> String:
	match child_variable_scope:
		BaseVariable.VariableScope.LOCAL:
			return FuseLocalization.translate("FUSE_SCOPE_LOCAL_STR")
		BaseVariable.VariableScope.SCOPE:
			return VariableScopeUtils.get_scope_source_string(
				child_scope_source as VariableScopeUtils.ScopeSource,
				child_custom_scope_id,
				child_target_node_path
			)
		BaseVariable.VariableScope.GLOBAL:
			return FuseLocalization.translate("FUSE_SCOPE_GLOBAL_STR")
		_:
			return FuseLocalization.translate("FUSE_SCOPE_UNKNOWN_STR")

## 获取父节点变量作用域来源字符串
func _get_parent_scope_source_string() -> String:
	match parent_variable_scope:
		BaseVariable.VariableScope.LOCAL:
			return FuseLocalization.translate("FUSE_SCOPE_LOCAL_STR")
		BaseVariable.VariableScope.SCOPE:
			return VariableScopeUtils.get_scope_source_string(
				parent_scope_source as VariableScopeUtils.ScopeSource,
				parent_custom_scope_id,
				parent_target_node_path
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
	# 获取子节点
	var child = _get_child_node(context)
	if child == null:
		return false

	# 获取父节点
	var parent = _get_parent_node(context)
	if parent == null:
		return false

	# 检查层次关系
	var is_child = child.get_parent() == parent

	var log_msg = FuseLocalization.translate_format("FUSE_LOG_HIERARCHY_CHECK", {
		"child": _get_child_node_source_string(),
		"parent": _get_parent_node_source_string(),
		"result": "是" if is_child else "否"
	})
	_log_debug(log_msg)

	return is_child

## 获取子节点
func _get_child_node(context: ExecutionContext) -> Node:
	if child_node_source == NodeSource.NODE_PATH:
		return _get_child_node_by_path(context)
	else:
		return _get_child_node_by_variable(context)

## 获取父节点
func _get_parent_node(context: ExecutionContext) -> Node:
	if parent_node_source == NodeSource.NODE_PATH:
		return _get_parent_node_by_path(context)
	else:
		return _get_parent_node_by_variable(context)

## 通过节点路径获取子节点
func _get_child_node_by_path(context: ExecutionContext) -> Node:
	# 验证节点路径
	if child_node.is_empty():
		var error_msg = FuseLocalization.translate("FUSE_ERROR_CHILD_NODE_EMPTY")
		_log_error(error_msg)
		_create_fuse_error(error_msg, FuseError.ErrorType.VALIDATION_ERROR)
		return null

	# 获取节点
	var node = context.get_node(child_node)
	if node == null:
		var error_msg = FuseLocalization.translate("FUSE_ERROR_CHILD_NOT_FOUND") % str(child_node)
		_log_error(error_msg)
		_create_fuse_error(error_msg, FuseError.ErrorType.RUNTIME_ERROR)
		return null

	return node

## 通过变量获取子节点
func _get_child_node_by_variable(context: ExecutionContext) -> Node:
	# 验证变量名
	if child_variable_name.is_empty():
		var error_msg = FuseLocalization.translate("FUSE_ERROR_VAR_NAME_EMPTY")
		_log_error(error_msg)
		_create_fuse_error(error_msg, FuseError.ErrorType.VALIDATION_ERROR)
		return null

	# 获取变量值
	var node_value = _get_child_node_variable_value(context)

	# 验证变量值
	if node_value == null:
		var error_msg = FuseLocalization.translate_format("FUSE_ERROR_NODE_VARIABLE_IS_NULL", {"name": child_variable_name})
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
			var error_msg = FuseLocalization.translate("FUSE_ERROR_CHILD_NOT_FOUND") % str(node_value)
			_log_error(error_msg)
			_create_fuse_error(error_msg, FuseError.ErrorType.RUNTIME_ERROR)
			return null
	elif node_value is String and not node_value.is_empty():
		# 尝试作为节点路径解析
		node = context.get_node(NodePath(node_value))
		if node == null:
			var error_msg = FuseLocalization.translate("FUSE_ERROR_CHILD_NOT_FOUND") % node_value
			_log_error(error_msg)
			_create_fuse_error(error_msg, FuseError.ErrorType.RUNTIME_ERROR)
			return null
	else:
		var error_msg = FuseLocalization.translate_format("FUSE_ERROR_NODE_VARIABLE_INVALID_TYPE", {"name": child_variable_name, "type": str(typeof(node_value))})
		_log_error(error_msg)
		_create_fuse_error(error_msg, FuseError.ErrorType.RUNTIME_ERROR)
		return null

	return node

## 通过节点路径获取父节点
func _get_parent_node_by_path(context: ExecutionContext) -> Node:
	# 验证节点路径
	if parent_node.is_empty():
		var error_msg = FuseLocalization.translate("FUSE_ERROR_PARENT_NODE_EMPTY")
		_log_error(error_msg)
		_create_fuse_error(error_msg, FuseError.ErrorType.VALIDATION_ERROR)
		return null

	# 获取节点
	var node = context.get_node(parent_node)
	if node == null:
		var error_msg = FuseLocalization.translate("FUSE_ERROR_PARENT_NOT_FOUND") % str(parent_node)
		_log_error(error_msg)
		_create_fuse_error(error_msg, FuseError.ErrorType.RUNTIME_ERROR)
		return null

	return node

## 通过变量获取父节点
func _get_parent_node_by_variable(context: ExecutionContext) -> Node:
	# 验证变量名
	if parent_variable_name.is_empty():
		var error_msg = FuseLocalization.translate("FUSE_ERROR_VAR_NAME_EMPTY")
		_log_error(error_msg)
		_create_fuse_error(error_msg, FuseError.ErrorType.VALIDATION_ERROR)
		return null

	# 获取变量值
	var node_value = _get_parent_node_variable_value(context)

	# 验证变量值
	if node_value == null:
		var error_msg = FuseLocalization.translate_format("FUSE_ERROR_NODE_VARIABLE_IS_NULL", {"name": parent_variable_name})
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
			var error_msg = FuseLocalization.translate("FUSE_ERROR_PARENT_NOT_FOUND") % str(node_value)
			_log_error(error_msg)
			_create_fuse_error(error_msg, FuseError.ErrorType.RUNTIME_ERROR)
			return null
	elif node_value is String and not node_value.is_empty():
		# 尝试作为节点路径解析
		node = context.get_node(NodePath(node_value))
		if node == null:
			var error_msg = FuseLocalization.translate("FUSE_ERROR_PARENT_NOT_FOUND") % node_value
			_log_error(error_msg)
			_create_fuse_error(error_msg, FuseError.ErrorType.RUNTIME_ERROR)
			return null
	else:
		var error_msg = FuseLocalization.translate_format("FUSE_ERROR_NODE_VARIABLE_INVALID_TYPE", {"name": parent_variable_name, "type": str(typeof(node_value))})
		_log_error(error_msg)
		_create_fuse_error(error_msg, FuseError.ErrorType.RUNTIME_ERROR)
		return null

	return node

## 获取子节点变量值
func _get_child_node_variable_value(context: ExecutionContext) -> Variant:
	var value: Variant = null

	match child_variable_scope:
		BaseVariable.VariableScope.LOCAL:
			# LOCAL 模式：使用 VariableOperations
			value = VariableOperations.get_variable(context, child_variable_name, BaseVariable.VariableScope.LOCAL, null)

		BaseVariable.VariableScope.GLOBAL:
			# GLOBAL 模式：使用 VariableOperations
			value = VariableOperations.get_variable(context, child_variable_name, BaseVariable.VariableScope.GLOBAL, null)

		BaseVariable.VariableScope.SCOPE:
			# SCOPE 模式：根据 ScopeSource 获取作用域容器
			if child_scope_source == ScopeSource.NEAREST:
				# NEAREST 模式：使用 VariableOperations
				value = VariableOperations.get_variable(context, child_variable_name, BaseVariable.VariableScope.SCOPE, null)
			else:
				# 其他模式：获取指定作用域容器并读取变量
				var utils_scope_source = child_scope_source as VariableScopeUtils.ScopeSource
				var scope_container = VariableScopeUtils.get_scope_container_by_source(
					context,
					utils_scope_source,
					child_custom_scope_id,
					child_target_node_path
				)

				if scope_container != null and scope_container.has_variable(child_variable_name):
					value = scope_container.get_variable(child_variable_name)

	return value

## 获取父节点变量值
func _get_parent_node_variable_value(context: ExecutionContext) -> Variant:
	var value: Variant = null

	match parent_variable_scope:
		BaseVariable.VariableScope.LOCAL:
			# LOCAL 模式：使用 VariableOperations
			value = VariableOperations.get_variable(context, parent_variable_name, BaseVariable.VariableScope.LOCAL, null)

		BaseVariable.VariableScope.GLOBAL:
			# GLOBAL 模式：使用 VariableOperations
			value = VariableOperations.get_variable(context, parent_variable_name, BaseVariable.VariableScope.GLOBAL, null)

		BaseVariable.VariableScope.SCOPE:
			# SCOPE 模式：根据 ScopeSource 获取作用域容器
			if parent_scope_source == ScopeSource.NEAREST:
				# NEAREST 模式：使用 VariableOperations
				value = VariableOperations.get_variable(context, parent_variable_name, BaseVariable.VariableScope.SCOPE, null)
			else:
				# 其他模式：获取指定作用域容器并读取变量
				var utils_scope_source = parent_scope_source as VariableScopeUtils.ScopeSource
				var scope_container = VariableScopeUtils.get_scope_container_by_source(
					context,
					utils_scope_source,
					parent_custom_scope_id,
					parent_target_node_path
				)

				if scope_container != null and scope_container.has_variable(parent_variable_name):
					value = scope_container.get_variable(parent_variable_name)

	return value

# =============================================
# 依赖计算
# =============================================

## 计算依赖
func _compute_dependencies() -> Array[String]:
	var dependencies: Array[String] = []

	# 如果子节点使用变量模式，添加变量依赖
	if child_node_source == NodeSource.VARIABLE and not child_variable_name.is_empty():
		dependencies.append(child_variable_name)

	# 如果父节点使用变量模式，添加变量依赖
	if parent_node_source == NodeSource.VARIABLE and not parent_variable_name.is_empty():
		dependencies.append(parent_variable_name)

	return dependencies

# =============================================
# 条件信息
# =============================================

## 获取条件类型
func get_condition_type() -> String:
	return "is_child_of"

## 获取条件分类
func get_condition_category() -> String:
	return "node"

## 获取条件描述
func get_description() -> String:
	var child_str = _get_child_node_source_string()
	var parent_str = _get_parent_node_source_string()

	if child_str.is_empty() or parent_str.is_empty():
		return FuseLocalization.translate("FUSE_CONDITION_HIERARCHY_NOT_SET")

	var desc = FuseLocalization.translate_format("FUSE_CONDITION_IS_CHILD_OF_FORMAT", {
		"child": child_str,
		"parent": parent_str
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

	# 根据子节点来源验证
	if child_node_source == NodeSource.NODE_PATH:
		if child_node.is_empty():
			errors.append(FuseLocalization.translate("FUSE_ERROR_CHILD_NODE_EMPTY"))
	else:
		# VARIABLE 模式验证
		if child_variable_name.is_empty():
			errors.append(FuseLocalization.translate("FUSE_ERROR_VAR_NAME_EMPTY"))

		# 验证 SCOPE 作用域时才验证 ScopeSource 参数
		if child_variable_scope == BaseVariable.VariableScope.SCOPE:
			var utils_scope_source = child_scope_source as VariableScopeUtils.ScopeSource
			errors.append_array(VariableScopeUtils.validate_scope_source_params(
				utils_scope_source,
				child_custom_scope_id,
				child_target_node_path
			))

	# 根据父节点来源验证
	if parent_node_source == NodeSource.NODE_PATH:
		if parent_node.is_empty():
			errors.append(FuseLocalization.translate("FUSE_ERROR_PARENT_NODE_EMPTY"))
	else:
		# VARIABLE 模式验证
		if parent_variable_name.is_empty():
			errors.append(FuseLocalization.translate("FUSE_ERROR_VAR_NAME_EMPTY"))

		# 验证 SCOPE 作用域时才验证 ScopeSource 参数
		if parent_variable_scope == BaseVariable.VariableScope.SCOPE:
			var utils_scope_source = parent_scope_source as VariableScopeUtils.ScopeSource
			errors.append_array(VariableScopeUtils.validate_scope_source_params(
				utils_scope_source,
				parent_custom_scope_id,
				parent_target_node_path
			))

	return errors

# =============================================
# 参数方法
# =============================================

## 获取参数
func get_parameters() -> Dictionary:
	var params = {
		"child_node_source": child_node_source,
		"parent_node_source": parent_node_source
	}

	# 子节点参数
	if child_node_source == NodeSource.NODE_PATH:
		params["child_node"] = child_node
	else:
		params["child_variable_name"] = child_variable_name
		params["child_variable_scope"] = child_variable_scope

		# 只在 SCOPE 作用域时添加 ScopeSource 参数
		if child_variable_scope == BaseVariable.VariableScope.SCOPE:
			params["child_scope_source"] = child_scope_source
			params["child_custom_scope_id"] = child_custom_scope_id
			params["child_target_node_path"] = child_target_node_path

	# 父节点参数
	if parent_node_source == NodeSource.NODE_PATH:
		params["parent_node"] = parent_node
	else:
		params["parent_variable_name"] = parent_variable_name
		params["parent_variable_scope"] = parent_variable_scope

		# 只在 SCOPE 作用域时添加 ScopeSource 参数
		if parent_variable_scope == BaseVariable.VariableScope.SCOPE:
			params["parent_scope_source"] = parent_scope_source
			params["parent_custom_scope_id"] = parent_custom_scope_id
			params["parent_target_node_path"] = parent_target_node_path

	return params

## 设置参数
func set_parameters(parameters: Dictionary):
	# 子节点参数
	if parameters.has("child_node_source"):
		child_node_source = parameters["child_node_source"]
	if parameters.has("child_node"):
		child_node = parameters["child_node"]
	if parameters.has("child_variable_name"):
		child_variable_name = parameters["child_variable_name"]
	if parameters.has("child_variable_scope"):
		child_variable_scope = parameters["child_variable_scope"]
	if parameters.has("child_scope_source"):
		child_scope_source = parameters["child_scope_source"]
	if parameters.has("child_custom_scope_id"):
		child_custom_scope_id = parameters["child_custom_scope_id"]
	if parameters.has("child_target_node_path"):
		child_target_node_path = parameters["child_target_node_path"]

	# 父节点参数
	if parameters.has("parent_node_source"):
		parent_node_source = parameters["parent_node_source"]
	if parameters.has("parent_node"):
		parent_node = parameters["parent_node"]
	if parameters.has("parent_variable_name"):
		parent_variable_name = parameters["parent_variable_name"]
	if parameters.has("parent_variable_scope"):
		parent_variable_scope = parameters["parent_variable_scope"]
	if parameters.has("parent_scope_source"):
		parent_scope_source = parameters["parent_scope_source"]
	if parameters.has("parent_custom_scope_id"):
		parent_custom_scope_id = parameters["parent_custom_scope_id"]
	if parameters.has("parent_target_node_path"):
		parent_target_node_path = parameters["parent_target_node_path"]

# =============================================
# 元数据
# =============================================

## 获取条件元数据
static func _get_condition_metadata() -> ConditionMetadata:
	var metadata = ConditionMetadata.new()
	metadata.name_key = "FUSE_CONDITION_IS_CHILD_OF_NAME"
	metadata.category_key = "FUSE_CATEGORY_NODE"
	metadata.description_key = "FUSE_CONDITION_IS_CHILD_OF_DESC"
	metadata.keywords = ["子节点", "child", "父节点", "parent", "层次", "hierarchy", "is_child_of", "变量", "variable"]
	metadata.builtin_icon = "Node"
	return metadata
