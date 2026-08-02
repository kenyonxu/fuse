@tool
@icon("res://addons/fuse/icons/builtin/ArrowDown.png")
extends BaseCondition
class_name CheckIsFalling

## 正在下落条件
##
## 检查 CharacterBody2D/3D 节点是否正在下落。
##
## 支持两种节点来源：
## - NODE_PATH: 通过节点路径直接指定
## - VARIABLE: 从变量获取节点（支持三层变量作用域）

## 节点来源枚举
enum NodeSource {
	NODE_PATH,   ## 通过节点路径指定
	VARIABLE     ## 从变量获取节点
}

## 作用域来源枚举（仅在 node_variable_scope == SCOPE 时使用）
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

# =============================================
# 参数定义
# =============================================

## 节点来源
var node_source: NodeSource = NodeSource.NODE_PATH:
	set(value):
		node_source = value
		_update_resource_name()
		notify_property_list_changed()

## 要检查的 CharacterBody 节点路径
var target_node: NodePath = NodePath(""):
	set(value):
		target_node = value
		_update_resource_name()

## 节点变量名（当 node_source == VARIABLE 时使用）
var node_variable_name: String = "":
	set(value):
		node_variable_name = value
		_update_resource_name()

## 节点变量作用域（三层变量系统）
var node_variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		node_variable_scope = value
		_update_resource_name()
		notify_property_list_changed()

## 节点变量作用域来源（仅当 node_variable_scope == SCOPE 时使用）
var node_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		node_scope_source = value
		_update_resource_name()
		notify_property_list_changed()

## 节点变量自定义作用域 ID（仅当 node_scope_source == CUSTOM_ID 时使用）
var node_custom_scope_id: String = "":
	set(value):
		node_custom_scope_id = value
		_update_resource_name()

## 节点变量目标节点路径（仅当 node_scope_source == TARGET_NODE 时使用）
var node_target_node_path: NodePath = NodePath(""):
	set(value):
		node_target_node_path = value
		_update_resource_name()

# =============================================
# 动态属性列表
# =============================================

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	# ========== 节点配置 ==========
	properties.append({
		name = "Node Configuration",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 节点来源
	properties.append({
		name = "node_source",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Node Path,Variable",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 根据节点来源显示不同属性
	if node_source == NodeSource.NODE_PATH:
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
			name = "node_variable_name",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 变量作用域
		properties.append({
			name = "node_variable_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 只在 node_variable_scope == SCOPE 时显示 ScopeSource 配置
		if node_variable_scope == BaseVariable.VariableScope.SCOPE:
			properties.append({
				name = "node_scope_source",
				type = TYPE_INT,
				hint = PROPERTY_HINT_ENUM,
				hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

			# 根据作用域来源添加额外属性
			if node_scope_source == ScopeSource.CUSTOM_ID:
				properties.append({
					name = "node_custom_scope_id",
					type = TYPE_STRING,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})
			elif node_scope_source == ScopeSource.TARGET_NODE:
				properties.append({
					name = "node_target_node_path",
					type = TYPE_NODE_PATH,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})

	return properties

## 验证属性可见性
func _validate_property(property: Dictionary) -> void:
	# 控制节点来源相关属性可见性
	if node_source == NodeSource.NODE_PATH:
		# NODE_PATH 模式：隐藏变量相关属性
		if property.name in ["node_variable_name", "node_variable_scope", "node_scope_source", "node_custom_scope_id", "node_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		# VARIABLE 模式：隐藏节点路径属性
		if property.name == "target_node":
			property.usage = PROPERTY_USAGE_NO_EDITOR

		# 控制变量 ScopeSource 属性可见性
		if node_variable_scope == BaseVariable.VariableScope.SCOPE:
			VariableScopeUtils.validate_scope_source_property(property, node_scope_source as VariableScopeUtils.ScopeSource)
		else:
			# 非 SCOPE 作用域时隐藏 ScopeSource 相关属性
			if property.name in ["node_scope_source", "node_custom_scope_id", "node_target_node_path"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR

# =============================================
# 资源名称和描述
# =============================================

## 更新资源名称（必需）
func _update_resource_name() -> void:
	var node_str = _get_node_source_string()

	if node_str.is_empty():
		resource_name = FuseLocalization.translate("FUSE_CONDITION_IS_FALLING_NOT_SET")
	else:
		var path_str = node_str
		# 限制长度
		if path_str.length() > 35:
			path_str = path_str.substr(0, 32) + "..."
		resource_name = FuseLocalization.translate_format("FUSE_CONDITION_IS_FALLING_FORMAT", {"path": path_str})

## 获取节点来源显示字符串
func _get_node_source_string() -> String:
	if node_source == NodeSource.NODE_PATH:
		var path_str = _get_node_display_name(target_node)
		if path_str.is_empty():
			return ""
		if path_str.length() > 40:
			path_str = path_str.substr(0, 37) + "..."
		return path_str
	else:
		if node_variable_name.is_empty():
			return ""
		var scope_str = _get_node_scope_source_string()
		return "[%s] %s" % [scope_str, node_variable_name]

## 获取节点变量作用域来源字符串
func _get_node_scope_source_string() -> String:
	match node_variable_scope:
		BaseVariable.VariableScope.LOCAL:
			return FuseLocalization.translate("FUSE_SCOPE_LOCAL_STR")
		BaseVariable.VariableScope.SCOPE:
			return VariableScopeUtils.get_scope_source_string(
				node_scope_source as VariableScopeUtils.ScopeSource,
				node_custom_scope_id,
				node_target_node_path
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
	# 获取节点
	var node = _get_target_node(context)
	if node == null:
		return false

	# 检查节点类型
	var is_character_body = node is CharacterBody2D or node is CharacterBody3D
	if not is_character_body:
		var error_msg = FuseLocalization.translate("FUSE_ERROR_CHARACTER_BODY_REQUIRED")
		_log_error(error_msg)
		_create_fuse_error(error_msg, FuseError.ErrorType.VALIDATION_ERROR)
		return false

	# 检查是否正在下落（velocity.y > 0）
	var is_falling = false

	if node is CharacterBody2D:
		var velocity = node.get("velocity")
		if velocity is Vector2:
			is_falling = velocity.y > 0
	elif node is CharacterBody3D:
		var velocity = node.get("velocity")
		if velocity is Vector3:
			is_falling = velocity.y > 0

	var result_text = "下落中" if is_falling else "未下落"
	var debug_msg = FuseLocalization.translate_format("FUSE_LOG_FALLING_CHECK", {"path": _get_node_source_string(), "result": result_text})
	_log_debug(debug_msg)

	return is_falling

## 获取目标节点
func _get_target_node(context: ExecutionContext) -> Node:
	if node_source == NodeSource.NODE_PATH:
		return _get_node_by_path(context)
	else:
		return _get_node_by_variable(context)

## 通过节点路径获取节点
func _get_node_by_path(context: ExecutionContext) -> Node:
	# 验证节点路径
	if target_node.is_empty():
		var error_msg = FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY")
		_log_error(error_msg)
		_create_fuse_error(error_msg, FuseError.ErrorType.VALIDATION_ERROR)
		return null

	# 获取节点
	var node = context.get_node(target_node)
	if node == null:
		var error_msg = FuseLocalization.translate_format("FUSE_ERROR_NODE_NOT_FOUND", {"path": str(target_node)})
		_log_error(error_msg)
		_create_fuse_error(error_msg, FuseError.ErrorType.RUNTIME_ERROR)
		return null

	return node

## 通过变量获取节点
func _get_node_by_variable(context: ExecutionContext) -> Node:
	# 验证变量名
	if node_variable_name.is_empty():
		var error_msg = FuseLocalization.translate("FUSE_ERROR_VAR_NAME_EMPTY")
		_log_error(error_msg)
		_create_fuse_error(error_msg, FuseError.ErrorType.VALIDATION_ERROR)
		return null

	# 获取变量值
	var node_value = _get_node_variable_value(context)

	# 验证变量值
	if node_value == null:
		# 变量值为空，节点不存在
		var error_msg = FuseLocalization.translate_format("FUSE_ERROR_NODE_VARIABLE_NULL", {"var": node_variable_name})
		_log_error(error_msg)
		_create_fuse_error(error_msg, FuseError.ErrorType.RUNTIME_ERROR)
		return null

	# 处理不同类型的节点值
	var node: Node = null
	if node_value is Node:
		node = node_value
	elif node_value is NodePath:
		node = context.get_node(node_value)
	elif node_value is String and not node_value.is_empty():
		# 尝试作为节点路径解析
		node = context.get_node(NodePath(node_value))
	else:
		# 无效类型
		var error_msg = FuseLocalization.translate_format("FUSE_ERROR_NODE_VARIABLE_INVALID_TYPE", {"name": node_variable_name, "type": str(typeof(node_value))})
		_log_error(error_msg)
		_create_fuse_error(error_msg, FuseError.ErrorType.RUNTIME_ERROR)
		return null

	if node == null:
		var error_msg = FuseLocalization.translate_format("FUSE_ERROR_NODE_VARIABLE_NOT_FOUND", {"var": node_variable_name})
		_log_error(error_msg)
		_create_fuse_error(error_msg, FuseError.ErrorType.RUNTIME_ERROR)
		return null

	return node

## 获取节点变量值
func _get_node_variable_value(context: ExecutionContext) -> Variant:
	var value: Variant = null

	match node_variable_scope:
		BaseVariable.VariableScope.LOCAL:
			# LOCAL 模式：使用 VariableOperations
			value = VariableOperations.get_variable(context, node_variable_name, BaseVariable.VariableScope.LOCAL, null)

		BaseVariable.VariableScope.GLOBAL:
			# GLOBAL 模式：使用 VariableOperations
			value = VariableOperations.get_variable(context, node_variable_name, BaseVariable.VariableScope.GLOBAL, null)

		BaseVariable.VariableScope.SCOPE:
			# SCOPE 模式：根据 ScopeSource 获取作用域容器
			if node_scope_source == ScopeSource.NEAREST:
				# NEAREST 模式：使用 VariableOperations
				value = VariableOperations.get_variable(context, node_variable_name, BaseVariable.VariableScope.SCOPE, null)
			else:
				# 其他模式：获取指定作用域容器并读取变量
				var utils_scope_source = node_scope_source as VariableScopeUtils.ScopeSource
				var scope_container = VariableScopeUtils.get_scope_container_by_source(
					context,
					utils_scope_source,
					node_custom_scope_id,
					node_target_node_path
				)

				if scope_container != null and scope_container.has_variable(node_variable_name):
					value = scope_container.get_variable(node_variable_name)

	return value

# =============================================
# 依赖计算
# =============================================

## 计算依赖
func _compute_dependencies() -> Array[String]:
	var dependencies: Array[String] = []

	# 如果使用变量模式，添加变量依赖
	if node_source == NodeSource.VARIABLE and not node_variable_name.is_empty():
		dependencies.append(node_variable_name)

	return dependencies

# =============================================
# 条件信息
# =============================================

## 声明变量读写模式（精确化静态分析）
## node_variable_name 仅 read（_evaluate_condition 中通过变量解析 CharacterBody 节点并读取 velocity）
func get_variable_modes() -> Array[Dictionary]:
	return [
		{"name": "node_variable_name", "mode": "read"},
	]

## 获取条件类型
func get_condition_type() -> String:
	return "is_falling"

## 获取条件分类
func get_condition_category() -> String:
	return "physics"

## 获取条件描述
func get_description() -> String:
	var node_str = _get_node_source_string()

	if node_str.is_empty():
		return FuseLocalization.translate("FUSE_CONDITION_FALLING_DESC_NOT_SET")

	var desc = FuseLocalization.translate_format("FUSE_CONDITION_IS_FALLING_FORMAT", {"path": node_str})

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

	# 根据节点来源验证
	if node_source == NodeSource.NODE_PATH:
		if target_node.is_empty():
			errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))
	else:
		# VARIABLE 模式验证
		if node_variable_name.is_empty():
			errors.append(FuseLocalization.translate("FUSE_ERROR_VAR_NAME_EMPTY"))

		# 验证 SCOPE 作用域时才验证 ScopeSource 参数
		if node_variable_scope == BaseVariable.VariableScope.SCOPE:
			var utils_scope_source = node_scope_source as VariableScopeUtils.ScopeSource
			errors.append_array(VariableScopeUtils.validate_scope_source_params(
				utils_scope_source,
				node_custom_scope_id,
				node_target_node_path
			))

	return errors

# =============================================
# 参数方法
# =============================================

## 获取参数
func get_parameters() -> Dictionary:
	var params = {
		"node_source": node_source
	}

	if node_source == NodeSource.NODE_PATH:
		params["target_node"] = target_node
	else:
		params["node_variable_name"] = node_variable_name
		params["node_variable_scope"] = node_variable_scope

		# 只在 SCOPE 作用域时添加 ScopeSource 参数
		if node_variable_scope == BaseVariable.VariableScope.SCOPE:
			params["node_scope_source"] = node_scope_source
			params["node_custom_scope_id"] = node_custom_scope_id
			params["node_target_node_path"] = node_target_node_path

	return params

## 设置参数
func set_parameters(parameters: Dictionary):
	if parameters.has("node_source"):
		node_source = parameters["node_source"]
	if parameters.has("target_node"):
		target_node = parameters["target_node"]
	if parameters.has("node_variable_name"):
		node_variable_name = parameters["node_variable_name"]
	if parameters.has("node_variable_scope"):
		node_variable_scope = parameters["node_variable_scope"]
	if parameters.has("node_scope_source"):
		node_scope_source = parameters["node_scope_source"]
	if parameters.has("node_custom_scope_id"):
		node_custom_scope_id = parameters["node_custom_scope_id"]
	if parameters.has("node_target_node_path"):
		node_target_node_path = parameters["node_target_node_path"]

# =============================================
# 元数据
# =============================================

## 获取条件元数据
static func _get_condition_metadata() -> ConditionMetadata:
	var metadata = ConditionMetadata.new()
	metadata.name_key = "FUSE_CONDITION_IS_FALLING_NAME"
	metadata.category_key = "FUSE_CATEGORY_PHYSICS"
	metadata.description_key = "FUSE_CONDITION_IS_FALLING_DESC"
	metadata.keywords = ["下落", "falling", "垂直速度", "velocity", "CharacterBody", "重力", "变量", "variable"]
	metadata.builtin_icon = "ArrowDown"
	return metadata
