@tool
@icon("res://addons/fuse/icons/builtin/AnimationTree.png")
extends BaseEvent
class_name OnAnimationBlend

## Event: OnAnimationBlend
##
## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - _is_monitoring: bool - 是否正在监控
## - _last_weight: float - 上次权重值
##
## 架构版本: 自声明状态模式 v2.0
## 相关文档: addons/fuse/docs/migration-guide-to-runtime-instance.md

## 检测 AnimationTree 混合权重变化
##
## 当 AnimationTree 的 blend 节点权重达到指定阈值时触发。

## 目标 AnimationTree 节点路径
@export var animation_tree_path: NodePath = NodePath(""):
	set(value):
		animation_tree_path = value
		_update_resource_name()

## 混合路径（AnimationTree 的 blend 节点路径）
@export var blend_path: NodePath = NodePath(""):
	set(value):
		blend_path = value
		_update_resource_name()

## 权重阈值（0-1）
@export_range(0.0, 1.0, 0.01) var threshold: float = 0.5:
	set(value):
		threshold = value
		_update_resource_name()

## 比较方式
enum Comparison {
	GREATER_OR_EQUAL,  ## 大于等于
	LESS_OR_EQUAL,     ## 小于等于
	EQUAL              ## 等于
}

@export var comparison: Comparison = Comparison.GREATER_OR_EQUAL:
	set(value):
		comparison = value
		_update_resource_name()

# RuntimeInstance 引用已在 BaseEvent 中定义
var _animation_tree: AnimationTree = null
var _owner_node_ref: Node = null
var _process_timer: Timer = null

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["is_monitoring"] = false
	base["last_weight"] = -1.0
	return base

## 更新资源名称（必需）
func _update_resource_name() -> void:
	var path_text = str(blend_path) if not blend_path.is_empty() else FuseLocalization.translate("FUSE_TEXT_NOT_SPECIFIED")
	var comp_key = ""
	match comparison:
		Comparison.GREATER_OR_EQUAL:
			comp_key = "FUSE_TEXT_COMPARISON_GREATER_OR_EQUAL"
		Comparison.LESS_OR_EQUAL:
			comp_key = "FUSE_TEXT_COMPARISON_LESS_OR_EQUAL"
		Comparison.EQUAL:
			comp_key = "FUSE_TEXT_COMPARISON_EQUAL"

	resource_name = FuseLocalization.translate_format("FUSE_EVENT_ON_ANIMATION_BLEND_RESOURCE_NAME", {
		"path": path_text,
		"threshold": "%.2f" % threshold,
		"comparison": FuseLocalization.translate(comp_key)
	})

## 使用 RuntimeInstance 初始化事件
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		return

	_runtime_instance_ref = runtime_instance

	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	_owner_node_ref = owner_node

	if animation_tree_path.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	if blend_path.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_BLEND_PATH_INVALID", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	_animation_tree = owner_node.get_node_or_null(animation_tree_path) as AnimationTree

	if not _animation_tree:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(animation_tree_path)})
		return

	# 验证节点类型
	if not _animation_tree is AnimationTree:
		_create_fuse_error_localized("FUSE_ERROR_INVALID_TARGET", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(animation_tree_path)})
		return

	# 创建检测定时器
	_process_timer = Timer.new()
	_process_timer.wait_time = 0.1  # 每 0.1 秒检查一次
	_process_timer.timeout.connect(_on_process_timeout)
	_process_timer.autostart = false
	owner_node.add_child(_process_timer)
	_process_timer.start()

	# 设置初始状态
	get_runtime_instance().set_runtime_state("is_monitoring", true)
	get_runtime_instance().set_runtime_state("last_weight", -1.0)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 初始化事件监听（必需）- 向后兼容
func initialize(owner_node: Node) -> void:
	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	_owner_node_ref = owner_node

	if animation_tree_path.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	if blend_path.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_BLEND_PATH_INVALID", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	_animation_tree = owner_node.get_node_or_null(animation_tree_path) as AnimationTree

	if not _animation_tree:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(animation_tree_path)})
		return

	# 验证节点类型
	if not _animation_tree is AnimationTree:
		_create_fuse_error_localized("FUSE_ERROR_INVALID_TARGET", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(animation_tree_path)})
		return

	# 创建检测定时器
	_process_timer = Timer.new()
	_process_timer.wait_time = 0.1  # 每 0.1 秒检查一次
	_process_timer.timeout.connect(_on_process_timeout)
	_process_timer.autostart = false
	owner_node.add_child(_process_timer)
	_process_timer.start()

	# 设置初始状态
	get_runtime_instance().set_runtime_state("is_monitoring", true)
	get_runtime_instance().set_runtime_state("last_weight", -1.0)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 定时检查混合权重
func _on_process_timeout() -> void:
	if not _animation_tree or not is_instance_valid(_animation_tree):
		return

	var is_monitoring = get_runtime_instance().get_runtime_state("is_monitoring")
	if not is_monitoring:
		return

	# 获取混合权重（在 Godot 4.6 中使用 get() 方法）
	# blend_path 应该类似 "parameters/BlendSpace1D/blend_position"
	var weight = _animation_tree.get(StringName(str(blend_path)))

	if weight == null:
		return

	var last_weight = get_runtime_instance().get_runtime_state("last_weight")

	# 检查是否应该触发
	var should_trigger = false
	match comparison:
		Comparison.GREATER_OR_EQUAL:
			should_trigger = weight >= threshold and last_weight < threshold
		Comparison.LESS_OR_EQUAL:
			should_trigger = weight <= threshold and last_weight > threshold
		Comparison.EQUAL:
			should_trigger = abs(weight - threshold) < 0.01 and abs(last_weight - threshold) >= 0.01

	if should_trigger:
		_trigger_event(weight)

	get_runtime_instance().set_runtime_state("last_weight", weight)

## 触发事件
func _trigger_event(weight: float) -> void:
	_log_info_localized("FUSE_LOG_EVENT_ANIMATION_BLEND_TRIGGERED", {
		"path": str(blend_path),
		"weight": str(weight)
	})

	# 创建上下文节点传递参数
	var context_node = Node.new()
	context_node.name = "AnimationBlendContext"

	context_node.set_meta("blend_path", str(blend_path))
	context_node.set_meta("weight", weight)
	context_node.set_meta("threshold", threshold)
	context_node.set_meta("comparison", comparison)
	context_node.set_meta("animation_tree", _animation_tree)

	_emit_triggered(context_node, _owner_node_ref)

	# 清理上下文节点
	context_node.queue_free()

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	# 清理 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("is_monitoring", false)
		_runtime_instance_ref.set_runtime_state("last_weight", -1.0)

	if _process_timer:
		_process_timer.stop()
		if _process_timer.timeout.is_connected(_on_process_timeout):
			_process_timer.timeout.disconnect(_on_process_timeout)
		if owner_node and is_instance_valid(owner_node):
			owner_node.remove_child(_process_timer)
		_process_timer.queue_free()
		_process_timer = null

	_animation_tree = null
	_owner_node_ref = null
	_runtime_instance_ref = null

	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 获取事件描述
func get_description() -> String:
	var path_text = str(blend_path) if not blend_path.is_empty() else FuseLocalization.translate("FUSE_TEXT_NOT_SPECIFIED")
	var comp_key = ""
	match comparison:
		Comparison.GREATER_OR_EQUAL:
			comp_key = "FUSE_TEXT_COMPARISON_GREATER_OR_EQUAL"
		Comparison.LESS_OR_EQUAL:
			comp_key = "FUSE_TEXT_COMPARISON_LESS_OR_EQUAL"
		Comparison.EQUAL:
			comp_key = "FUSE_TEXT_COMPARISON_EQUAL"

	return FuseLocalization.translate_format("FUSE_EVENT_ON_ANIMATION_BLEND_DESC", {
		"path": path_text,
		"threshold": "%.2f" % threshold,
		"comparison": FuseLocalization.translate(comp_key)
	})

## 获取事件类型
func get_event_type() -> String:
	return "animation_blend"

## 获取事件分类
func get_event_category() -> String:
	return "animation"

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	if animation_tree_path.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))

	if blend_path.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_BLEND_PATH_INVALID"))

	if threshold < 0.0 or threshold > 1.0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_THRESHOLD_INVALID"))

	return errors

## 重置事件状态
func reset() -> void:
	super.reset()
	# 重置 RuntimeInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("last_weight", -1.0)
		_runtime_instance_ref.set_runtime_state("is_monitoring", true)
	if _owner_node_ref and is_instance_valid(_owner_node_ref):
		initialize(_owner_node_ref)
	_log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_ON_ANIMATION_BLEND_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_ANIMATION"
	metadata.description_key = "FUSE_EVENT_ON_ANIMATION_BLEND_DESC"
	metadata.keywords = ["animation", "动画", "blend", "混合", "weight", "权重", "tree", "树", "blend_space", "混合空间"]
	metadata.builtin_icon = "AnimationTree"
	return metadata
