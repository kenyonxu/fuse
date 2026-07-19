@tool
@icon("res://addons/fuse/icons/builtin/Signals.png")
extends BaseEvent
class_name OnSignalEventTemplate

## 信号事件描述（简短说明事件的功能）
##
## 信号事件说明：
## - 监听特定节点的信号
## - 支持触发一次模式
## - 支持上下文数据传递
## - 使用 RuntimeEventInstance 管理运行时状态

# =============================================
# 参数定义
# =============================================

## 目标节点路径
@export var target_node_path: NodePath = NodePath(""):
	set(value):
		target_node_path = value
		_update_resource_name()

## 是否只触发一次
@export var trigger_once: bool = false:
	set(value):
		trigger_once = value
		_update_resource_name()

# =============================================
# 运行时状态
# =============================================

# 注：_runtime_instance_ref 已在 BaseEvent 中声明，子类无需重新声明
var _target_node: Node = null

## 获取默认运行时状态（新版核心方法）
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["has_triggered"] = false
	return base

# =============================================
# 元数据方法
# =============================================

## 获取事件元数据（必需）
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_ON_XXX_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_XXX"
	metadata.description_key = "FUSE_EVENT_ON_XXX_DESC"
	metadata.keywords = ["keyword1", "keyword2", "keyword3"]
	metadata.builtin_icon = "Signals"
	return metadata

# =============================================
# 资源名称和描述
# =============================================

## 更新资源名称（必需）
func _update_resource_name():
	var parts = []

	parts.append("事件名称")

	if not target_node_path.is_empty():
		parts.append("'%s'" % target_node_path)

	if trigger_once:
		parts.append("[仅一次]")

	resource_name = " ".join(parts)

## 获取事件描述
func get_description() -> String:
	var node_name = target_node_path if not target_node_path.is_empty() else "未指定"
	var once_text = "，仅触发一次" if trigger_once else ""
	return "当信号触发于 %s 时%s" % [node_name, once_text]

## 获取事件类型
func get_event_type() -> String:
	return "signal_event_type"

## 获取事件分类
func get_event_category() -> String:
	return "category_name"

# =============================================
# 生命周期方法
# =============================================

## 使用运行时实例初始化事件（推荐）
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		return

	# 保存 RuntimeEventInstance 引用
	_runtime_instance_ref = runtime_instance

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

	# ============================================
	# 1. 验证 owner_node
	# ============================================

	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# ============================================
	# 2. 验证目标节点路径
	# ============================================

	if target_node_path.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# ============================================
	# 3. 获取目标节点
	# ============================================

	_target_node = owner_node.get_node_or_null(target_node_path)
	if not _target_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(target_node_path)})
		return

	# ============================================
	# 4. 验证节点类型（如果需要）
	# ============================================

	# 示例：检查节点是否为特定类型
	# if not _target_node is Area2D:
	# 	_create_fuse_error_localized("FUSE_ERROR_INVALID_TARGET", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(target_node_path)})
	# 	return

	# ============================================
	# 5. 连接信号
	# ============================================

	if not _target_node.signal_name.is_connected(_on_signal):
		_target_node.signal_name.connect(_on_signal)

	_log_info_localized("FUSE_LOG_EVENT_SIGNAL_SOURCE", {"source": _target_node.name, "signal": "signal_name"})

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	# ============================================
	# 1. 断开信号连接
	# ============================================

	if _target_node and is_instance_valid(_target_node):
		if _target_node.signal_name.is_connected(_on_signal):
			_target_node.signal_name.disconnect(_on_signal)

	# ============================================
	# 2. 清理 RuntimeEventInstance 状态
	# ============================================

	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("has_triggered", false)

	# ============================================
	# 3. 清理引用
	# ============================================

	_target_node = null
	_runtime_instance_ref = null

	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

# =============================================
# 信号处理
# =============================================

## 信号回调函数
func _on_signal(...args):
	# ============================================
	# 1. 检查是否只触发一次（通过 RuntimeEventInstance 状态）
	# ============================================

	var has_triggered: bool = false
	if _runtime_instance_ref and _runtime_instance_ref.has_runtime_state("has_triggered"):
		has_triggered = _runtime_instance_ref.get_runtime_state("has_triggered")

	if trigger_once and has_triggered:
		_log_debug_localized("FUSE_LOG_EVENT_ALREADY_TRIGGERED", {})
		return

	# ============================================
	# 2. 检查其他条件（如果有）
	# ============================================

	if not _check_condition(args):
		return

	# ============================================
	# 3. 标记已触发（写入 RuntimeEventInstance 状态）
	# ============================================

	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("has_triggered", true)
		_runtime_instance_ref.update_trigger_stats()

	# ============================================
	# 4. 记录日志
	# ============================================

	_log_info_localized("FUSE_LOG_EVENT_TRIGGERED", {"event": get_event_type()})

	# ============================================
	# 5. 发出触发信号（使用 _emit_triggered 自动设置 trigger meta）
	# ============================================

	var context_node = args[0] if args.size() > 0 else _target_node
	_emit_triggered(context_node)  # 推荐：自动设置 trigger meta

# =============================================
# 验证和重置
# =============================================

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	if target_node_path.is_empty():
		errors.append("目标节点路径不能为空")

	return errors

## 重置事件状态
func reset() -> void:
	super.reset()

	# 重置 RuntimeEventInstance 状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("has_triggered", false)

	_log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})

# =============================================
# 辅助方法（可选）
# =============================================

## 检查触发条件（可选）
func _check_condition(args: Array) -> bool:
	# 在这里实现自定义的条件检查逻辑
	# 返回 true 表示条件满足，应该触发
	# 返回 false 表示条件不满足，不应该触发
	return true
