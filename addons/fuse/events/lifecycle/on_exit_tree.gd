@tool
@icon("res://addons/fuse/icons/builtin/ReflectionProbe.png")
extends BaseEvent
class_name OnExitTree

## 节点退出场景树事件
##
## 当节点退出场景树时触发此事件。通过监听 Node.tree_exited 信号实现。

## 是否清理资源
@export var cleanup_resources: bool = false:
	set(value):
		cleanup_resources = value
		_update_resource_name()

# ============================================================================
# MIGRATED: 此事件已迁移到 RuntimeInstance 自声明状态模式
# 状态管理已从实例变量改为 RuntimeInstance 管理状态
# ============================================================================

# ============================================================================
# 核心方法（RuntimeInstance 状态模式必需）
# ============================================================================

## 获取默认运行时状态（必需）
func get_default_runtime_state() -> Dictionary:
	var base_state = super.get_default_runtime_state()
	base_state["event_states"] = {
		"owner_node_ref": null,
		"is_monitoring": false
	}
	return base_state

## 使用 RuntimeInstance 初始化（必需）
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 保存到运行时状态
	var state = runtime_instance.get_state()
	state.event_states["owner_node_ref"] = owner_node
	state.event_states["is_monitoring"] = false

	# 连接 tree_exited 信号
	if not owner_node.tree_exited.is_connected(_on_tree_exited):
		owner_node.tree_exited.connect(_on_tree_exited)

	state.event_states["is_monitoring"] = true

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 更新资源名称（必需）
func _update_resource_name() -> void:
	if cleanup_resources:
		resource_name = FuseLocalization.translate("FUSE_EVENT_ON_EXIT_TREE_NAME_WITH_CLEANUP")
	else:
		resource_name = FuseLocalization.translate("FUSE_EVENT_ON_EXIT_TREE_NAME")

## 初始化事件监听（必需）
## 注意：实际初始化通过 initialize_with_runtime_instance() 进行
func initialize(owner_node: Node) -> void:
	# 这个方法保留用于向后兼容，实际初始化在 initialize_with_runtime_instance() 中进行
	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	var runtime_instance = _runtime_instance_ref
	if runtime_instance:
		var state = runtime_instance.get_state()

		# 断开信号连接
		if owner_node and owner_node.tree_exited.is_connected(_on_tree_exited):
			owner_node.tree_exited.disconnect(_on_tree_exited)

		# 清理状态
		state.event_states["is_monitoring"] = false
		state.event_states["owner_node_ref"] = null

	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## tree_exited 信号回调
func _on_tree_exited() -> void:
	var runtime_instance = _runtime_instance_ref
	if not runtime_instance:
		return

	var state = runtime_instance.get_state()
	if not state.event_states.get("is_monitoring", false):
		return

	_log_info_localized("FUSE_LOG_EVENT_EXIT_TREE_TRIGGERED", {})

	# 获取 owner_node 引用
	var owner_node = state.event_states.get("owner_node_ref", null)

	# 创建上下文节点
	var context_node = Node.new()
	context_node.name = "ExitTreeContext"

	# 设置清理标志
	context_node.set_meta("cleanup_resources", cleanup_resources)

	_emit_triggered(context_node, owner_node)

	# 清理上下文节点
	context_node.queue_free()

	# 更新触发计数
	state["trigger_count"] = state.get("trigger_count", 0) + 1
	state["last_trigger_time"] = Time.get_ticks_msec() / 1000.0

## 获取事件描述
func get_description() -> String:
	if cleanup_resources:
		return FuseLocalization.translate("FUSE_EVENT_ON_EXIT_TREE_DESC_WITH_CLEANUP")
	else:
		return FuseLocalization.translate("FUSE_EVENT_ON_EXIT_TREE_DESC")

## 获取事件类型
func get_event_type() -> String:
	return "exit_tree"

## 获取事件分类
func get_event_category() -> String:
	return "lifecycle"

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []
	# 此事件参数无需验证
	return errors

## 重置事件状态（必需）
func reset() -> void:
	super.reset()

	# 清理运行时状态
	var runtime_instance = _runtime_instance_ref
	if runtime_instance:
		var state = runtime_instance.get_state()
		state.event_states["owner_node_ref"] = null
		state.event_states["is_monitoring"] = false

# ============================================================================
# MIGRATION COMPLETE: OnExitTree 已成功迁移到 RuntimeInstance 自声明状态模式
# ============================================================================
# 主要变更：
# 1. 删除了状态变量 _owner_node_ref 和 _is_monitoring
# 2. 实现了 get_default_runtime_state() 方法
# 3. 实现了 initialize_with_runtime_instance() 方法
# 4. 修改所有状态访问使用 RuntimeInstance.get_state()
# 5. 在 terminate() 和 reset() 中清理状态
# 6. 保持了向后兼容性
# ============================================================================

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_ON_EXIT_TREE_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_LIFECYCLE"
	metadata.description_key = "FUSE_EVENT_ON_EXIT_TREE_DESC"
	metadata.keywords = ["tree", "树", "exit", "退出", "scene", "场景", "lifecycle", "生命周期", "cleanup", "清理"]
	metadata.builtin_icon = "ReflectionProbe"
	return metadata
