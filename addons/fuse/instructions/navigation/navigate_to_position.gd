@tool
@icon("res://addons/fuse/icons/builtin/NavigationAgent2D.svg")
extends BaseInstruction
class_name NavigateToPosition

## 使用 NavigationAgent2D/3D 将节点导航到目标位置（异步操作）

# =============================================
# 属性定义
# =============================================

## NavigationAgent2D/3D 节点
var agent_node: NodePath = NodePath(""):
	set(value):
		agent_node = value
		_update_resource_name()

## 目标位置（2D）
var target_position: Vector2 = Vector2.ZERO:
	set(value):
		target_position = value
		_update_resource_name()

## 目标位置（3D）
var target_position_3d: Vector3 = Vector3.ZERO:
	set(value):
		target_position_3d = value
		_update_resource_name()

## 是否使用 3D 导航
var use_3d: bool = false:
	set(value):
		use_3d = value
		_update_resource_name()
		notify_property_list_changed()

## 从变量读取目标位置
var target_from_variable: bool = false:
	set(value):
		target_from_variable = value
		_update_resource_name()
		notify_property_list_changed()

## 目标位置变量名
var target_variable: String = "":
	set(value):
		target_variable = value
		_update_resource_name()

# =============================================
# 运行时状态
# =============================================
var _navigation_agent: Node = null

# =============================================
# 异步执行标志
# =============================================
func _init():
	_is_synchronous_hint = false
	_sync_hint_manually_set = true

# =============================================
# 元数据（必需）
# =============================================
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_NAVIGATE_TO_POS_NAME"
	metadata.category_key = "FUSE_CATEGORY_NAVIGATION"
	metadata.description_key = "FUSE_INSTRUCTION_NAVIGATE_TO_POS_DESC"
	metadata.keywords = ["导航", "navigation", "寻路", "pathfinding", "agent", "代理", "移动", "move", "位置", "position", "目标", "target"]
	metadata.builtin_icon = "NavigationAgent2D"
	return metadata

func _setup_metadata():
	pass

# =============================================
# 动态属性列表
# =============================================
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	# Agent 分类
	properties.append({
		name = "Agent",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "agent_node",
		type = TYPE_NODE_PATH,
		hint = PROPERTY_HINT_NODE_PATH_VALID_TYPES,
		hint_string = "NavigationAgent2D,NavigationAgent3D",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "use_3d",
		type = TYPE_BOOL,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Target 分类
	properties.append({
		name = "Target",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "target_from_variable",
		type = TYPE_BOOL,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if target_from_variable:
		properties.append({
			name = "target_variable",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
	else:
		if use_3d:
			properties.append({
				name = "target_position_3d",
				type = TYPE_VECTOR3,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})
		else:
			properties.append({
				name = "target_position",
				type = TYPE_VECTOR2,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

	return properties

# =============================================
# 条件属性可见性
# =============================================
func _validate_property(property: Dictionary) -> void:
	if target_from_variable:
		if property.name in ["target_position", "target_position_3d"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		if property.name == "target_variable":
			property.usage = PROPERTY_USAGE_NO_EDITOR
		if use_3d:
			if property.name == "target_position":
				property.usage = PROPERTY_USAGE_NO_EDITOR
		else:
			if property.name == "target_position_3d":
				property.usage = PROPERTY_USAGE_NO_EDITOR

# =============================================
# 资源名称
# =============================================
func _update_resource_name():
	var agent_str = _get_node_display_name(agent_node) if not agent_node.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")
	var target_str = _get_target_display_str()
	resource_name = FuseLocalization.translate_format("FUSE_INSTRUCTION_NAVIGATE_TO_POS_RESOURCE_NAME", {
		"agent": agent_str,
		"target": target_str
	})

func _get_target_display_str() -> String:
	if target_from_variable and not target_variable.is_empty():
		return target_variable
	elif use_3d:
		return str(target_position_3d)
	else:
		return str(target_position)

# =============================================
# 默认运行时状态
# =============================================
func get_default_runtime_state() -> Dictionary:
	var state = super.get_default_runtime_state()
	state["agent_node"] = agent_node
	state["is_navigating"] = false
	return state

# =============================================
# 执行（异步）
# =============================================
func execute(context: ExecutionContext):
	_start_execution(context)

	if agent_node.is_empty():
		set_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	var agent := context.get_node(agent_node)
	if not agent:
		set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"node": str(agent_node)})
		finished.emit()
		return

	# 确定目标位置
	var target: Variant
	if target_from_variable and not target_variable.is_empty():
		target = VariableOperations.get_variable(context, target_variable, BaseVariable.VariableScope.LOCAL, null)
		if target == null:
			set_error_localized("FUSE_ERROR_VAR_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"variable": target_variable})
			finished.emit()
			return
	else:
		target = target_position_3d if use_3d else target_position

	# 设置目标并开始导航
	if use_3d and agent is NavigationAgent3D:
		var ag := agent as NavigationAgent3D
		ag.target_position = target as Vector3
		if not ag.navigation_finished.is_connected(_on_navigation_finished):
			ag.navigation_finished.connect(_on_navigation_finished, CONNECT_ONE_SHOT)
		_navigation_agent = ag
	elif agent is NavigationAgent2D:
		var ag := agent as NavigationAgent2D
		ag.target_position = target as Vector2
		if not ag.navigation_finished.is_connected(_on_navigation_finished):
			ag.navigation_finished.connect(_on_navigation_finished, CONNECT_ONE_SHOT)
		_navigation_agent = ag
	else:
		set_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", FuseError.ErrorType.RUNTIME_ERROR, {
			"node": agent.name,
			"actual_type": agent.get_class()
		})
		finished.emit()
		return

	_log_info_localized("FUSE_LOG_NAVIGATION_STARTED", {"target": str(target)})

# =============================================
# 导航完成回调
# =============================================
func _on_navigation_finished():
	_log_info_localized("FUSE_LOG_NAVIGATION_FINISHED", {})
	_navigation_agent = null
	_on_execution_completed()

# =============================================
# 取消
# =============================================
func cancel():
	if _navigation_agent:
		if _navigation_agent is NavigationAgent2D:
			var ag := _navigation_agent as NavigationAgent2D
			if ag.navigation_finished.is_connected(_on_navigation_finished):
				ag.navigation_finished.disconnect(_on_navigation_finished)
		elif _navigation_agent is NavigationAgent3D:
			var ag := _navigation_agent as NavigationAgent3D
			if ag.navigation_finished.is_connected(_on_navigation_finished):
				ag.navigation_finished.disconnect(_on_navigation_finished)
		_navigation_agent = null
	super.cancel()

# =============================================
# 资源清理
# =============================================
func _cleanup_resources():
	super._cleanup_resources()
	if _navigation_agent:
		if _navigation_agent is NavigationAgent2D:
			var ag := _navigation_agent as NavigationAgent2D
			if ag.navigation_finished.is_connected(_on_navigation_finished):
				ag.navigation_finished.disconnect(_on_navigation_finished)
		elif _navigation_agent is NavigationAgent3D:
			var ag := _navigation_agent as NavigationAgent3D
			if ag.navigation_finished.is_connected(_on_navigation_finished):
				ag.navigation_finished.disconnect(_on_navigation_finished)
	_navigation_agent = null

# =============================================
# 描述
# =============================================
func get_description() -> String:
	var agent_str = _get_node_display_name(agent_node) if not agent_node.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")
	var target_str = _get_target_display_str()
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_NAVIGATE_TO_POS_DESCRIPTION", {
		"agent": agent_str,
		"target": target_str
	})

# =============================================
# 验证
# =============================================
func validate() -> Array[String]:
	var errors = super.validate()
	if agent_node.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))
	if target_from_variable and target_variable.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_VAR_NAME_EMPTY"))
	return errors

# =============================================
# 动态属性拦截
# =============================================
func _set(property: StringName, value: Variant) -> bool:
	if property in ["agent_node", "target_position", "target_position_3d", "use_3d", "target_from_variable", "target_variable"]:
		set(property, value)
		_update_resource_name()
		if property in ["use_3d", "target_from_variable"]:
			notify_property_list_changed()
		return true
	return false
