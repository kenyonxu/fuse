@tool
@icon("res://addons/fuse/icons/builtin/Reload.png")
extends BaseEvent
class_name OnEnterTree

## 节点进入场景树事件
##
## 当节点进入场景树时触发此事件。通过监听 Node.tree_entered 信号实现。
##
## 🔄 MIGRATED TO RUNTIME INSTANCE SELF-DECLARED STATE MODE
##
## 此事件已迁移到 RuntimeInstance 自声明状态模式。
##
## 状态管理变更：
## - 旧模式：将 _owner_node_ref 和 _is_monitoring 作为类成员变量存储
## - 新模式：这些状态现在存储在 RuntimeInstance.runtime_state 中
##
## 关键变更：
## 1. 添加了 get_default_runtime_state() 方法声明运行时状态
## 2. 添加了 _initialize_runtime_state() 方法同步运行时状态
## 3. 修改了所有状态访问以同时更新运行时状态
## 4. 在 terminate() 和 reset() 中清理运行时状态
##
## 运行时状态结构：
## {
##     "initialized": true,           # 基础状态（由基类提供）
##     "trigger_count": 0,            # 基础状态（由基类提供）
##     "last_trigger_time": 0.0,       # 基础状态（由基类提供）
##     "owner_node": null,            # 被监控的节点引用
##     "is_monitoring": false         # 监控状态标志
## }

# 私有变量用于存储运行时数据（从运行时状态同步）
var _owner_node_ref: Node = null
var _is_monitoring: bool = false

## 更新资源名称（必需）
func _update_resource_name() -> void:
	resource_name = FuseLocalization.translate("FUSE_EVENT_ON_ENTER_TREE_NAME")

## 初始化事件监听（必需）
func initialize(owner_node: Node) -> void:
	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 设置私有变量
	_owner_node_ref = owner_node

	# 连接 tree_entered 信号
	if not owner_node.tree_entered.is_connected(_on_tree_entered):
		owner_node.tree_entered.connect(_on_tree_entered)

	_is_monitoring = true

	# 如果有运行时实例，更新运行时状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("owner_node", owner_node)
		_runtime_instance_ref.set_runtime_state("is_monitoring", true)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	_is_monitoring = false

	# 断开信号连接
	if owner_node and owner_node.tree_entered.is_connected(_on_tree_entered):
		owner_node.tree_entered.disconnect(_on_tree_entered)

	_owner_node_ref = null

	# 如果有运行时实例，清理运行时状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("is_monitoring", false)

	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## tree_entered 信号回调
func _on_tree_entered() -> void:
	if not _is_monitoring:
		return

	_log_info_localized("FUSE_LOG_EVENT_ENTER_TREE_TRIGGERED", {})

	# 如果有运行时实例，更新触发统计
	if _runtime_instance_ref:
		_runtime_instance_ref.update_trigger_stats()

	_emit_triggered(_owner_node_ref, _owner_node_ref)

## 获取事件描述
func get_description() -> String:
	return FuseLocalization.translate("FUSE_EVENT_ON_ENTER_TREE_DESC")

## 获取事件类型
func get_event_type() -> String:
	return "enter_tree"

## 获取事件分类
func get_event_category() -> String:
	return "lifecycle"

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []
	# 此事件无需验证参数
	return errors

## 获取默认运行时状态
##
## 提供事件的默认运行时状态声明
##
## 返回：
## - Dictionary: 默认运行时状态字典
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["owner_node"] = null  # 被监控的节点引用
	base["is_monitoring"] = false  # 监控状态标志
	return base

## 初始化运行时状态
##
## 重写此方法来初始化特定的运行时状态
func _initialize_runtime_state(runtime_instance: RuntimeEventInstance) -> void:
	# 从运行时状态获取必要的数据
	var owner_node = runtime_instance.get_runtime_state("owner_node")
	if owner_node:
		# 如果运行时状态中有节点引用，使用它
		_owner_node_ref = owner_node
		# 连接 tree_entered 信号
		if not owner_node.tree_entered.is_connected(_on_tree_entered):
			owner_node.tree_entered.connect(_on_tree_entered)

		_is_monitoring = runtime_instance.get_runtime_state("is_monitoring")

## 重置事件状态
## 重写此方法来清理特定状态
func reset() -> void:
	super.reset()  # 调用基类的 reset 方法

	# 清理特定状态
	_owner_node_ref = null
	_is_monitoring = false

	# 清理运行时状态中的特定键
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("owner_node", null)
		_runtime_instance_ref.set_runtime_state("is_monitoring", false)

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_ON_ENTER_TREE_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_LIFECYCLE"
	metadata.description_key = "FUSE_EVENT_ON_ENTER_TREE_DESC"
	metadata.keywords = ["tree", "树", "enter", "进入", "scene", "场景", "lifecycle", "生命周期"]
	metadata.builtin_icon = "Reload"
	return metadata
