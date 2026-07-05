@tool
@icon("res://addons/fuse/icons/builtin/NavigationAgent2D.svg")
extends BaseCondition
class_name CheckPathAvailable

## 路径可用性检查条件
##
## 检查 NavigationAgent2D/3D 是否有到目标位置的有效路径。

## NavigationAgent 节点路径
var agent_node: NodePath = NodePath(""):
	set(value):
		agent_node = value
		_update_resource_name()

## 目标位置
var target_position: Vector2 = Vector2.ZERO:
	set(value):
		target_position = value
		_update_resource_name()

## 更新资源名称
func _update_resource_name() -> void:
	var agent_str = _get_node_display_name(agent_node) if not agent_node.is_empty() else FuseLocalization.translate("FUSE_COMMON_NO_NODE_SELECTED")
	resource_name = FuseLocalization.translate_format("FUSE_CONDITION_PATH_AVAILABLE_FORMAT", {
		"agent": agent_str,
		"pos": str(target_position)
	})

## 评估条件
func _evaluate_condition(context: ExecutionContext) -> bool:
	if agent_node.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		return false

	var agent = context.get_node(agent_node)
	if agent == null:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"node": str(agent_node)})
		return false

	if agent is NavigationAgent2D:
		var nav := agent as NavigationAgent2D
		return not nav.is_navigation_finished() and not nav.is_target_reached()
	elif agent is NavigationAgent3D:
		var nav := agent as NavigationAgent3D
		return not nav.is_navigation_finished() and not nav.is_target_reached()
	else:
		_create_fuse_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", FuseError.ErrorType.RUNTIME_ERROR, {"node": agent.name, "expected": "NavigationAgent2D or NavigationAgent3D"})
		return false

	return true

## 计算依赖
func _compute_dependencies() -> Array[String]:
	return []

## 获取条件类型
func get_condition_type() -> String:
	return "check_path_available"

## 获取条件分类
func get_condition_category() -> String:
	return "navigation"

## 获取条件描述
func get_description() -> String:
	var agent_str = _get_node_display_name(agent_node) if not agent_node.is_empty() else FuseLocalization.translate("FUSE_COMMON_NO_NODE_SELECTED")
	return FuseLocalization.translate_format("FUSE_CONDITION_PATH_AVAILABLE_DESCRIPTION", {
		"agent": agent_str,
		"pos": str(target_position)
	})

## 验证条件
func validate() -> Array[String]:
	var errors = super.validate()
	if agent_node.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))
	return errors

## 获取参数
func get_parameters() -> Dictionary:
	return {
		"agent_node": agent_node,
		"target_position": target_position
	}

## 设置参数
func set_parameters(parameters: Dictionary):
	if parameters.has("agent_node"):
		agent_node = parameters["agent_node"]
	if parameters.has("target_position"):
		if parameters["target_position"] is Vector2:
			target_position = parameters["target_position"]

## 获取条件元数据
static func _get_condition_metadata() -> ConditionMetadata:
	var metadata = ConditionMetadata.new()
	metadata.name_key = "FUSE_CONDITION_PATH_AVAILABLE_NAME"
	metadata.category_key = "FUSE_CATEGORY_NAVIGATION"
	metadata.description_key = "FUSE_CONDITION_PATH_AVAILABLE_DESC"
	metadata.keywords = ["路径", "path", "导航", "navigation", "可达", "reachable", "agent", "目标", "target"]
	metadata.builtin_icon = "NavigationAgent2D"
	return metadata
