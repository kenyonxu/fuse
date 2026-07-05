@tool
@icon("res://addons/fuse/icons/builtin/Animation.png")
extends BaseEvent
class_name OnAnimationFinished

## Event: OnAnimationFinished
##
## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - 无额外状态变量（纯信号转发事件）
##
## 架构版本: 自声明状态模式 v2.0
## 相关文档: addons/fuse/docs/migration-guide-to-runtime-instance.md

## 动画完成事件
##
## 当 AnimationPlayer 播放完成指定动画时触发。

## 目标 AnimationPlayer 节点路径
@export var animation_player: NodePath = NodePath(""):
	set(value):
		animation_player = value
		_update_resource_name()

## 动画名称（空字符串表示任意动画）
@export var animation_name: String = "":
	set(value):
		animation_name = value
		_update_resource_name()

## 是否传递动画名称
@export var emit_animation_name: bool = true

# RuntimeInstance 引用已在 BaseEvent 中定义
var _anim_player_ref: AnimationPlayer = null

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	# 此事件是纯信号转发，无需额外状态变量
	return base

## 使用 RuntimeInstance 初始化事件
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		return

	# 保存 RuntimeEventInstance 引用
	_runtime_instance_ref = runtime_instance

	# 验证 owner_node
	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 🔧 保存 Trigger 引用，用于 _emit_triggered
	set_trigger_ref(owner_node)

	# 验证目标节点路径
	if animation_player.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 获取目标节点
	_anim_player_ref = owner_node.get_node_or_null(animation_player)
	if not _anim_player_ref:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(animation_player)})
		return

	# 验证节点类型
	if not _anim_player_ref is AnimationPlayer:
		_create_fuse_error_localized("FUSE_ERROR_INVALID_TARGET", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(animation_player)})
		return

	# 连接信号
	if not _anim_player_ref.animation_finished.is_connected(_on_animation_finished):
		_anim_player_ref.animation_finished.connect(_on_animation_finished)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 更新资源名称（必需）
func _update_resource_name():
	var anim_text = animation_name if not animation_name.is_empty() else FuseLocalization.translate("FUSE_EVENT_ANIMATION_ANY")
	var node_name = str(animation_player) if not animation_player.is_empty() else FuseLocalization.translate("FUSE_EVENT_ANIMATION_CURRENT_PLAYER")

	resource_name = FuseLocalization.translate_format("FUSE_EVENT_ON_ANIMATION_FINISHED_RESOURCE_NAME", {
		"target": node_name,
		"animation": anim_text
	})

## 初始化事件监听（必需）
func initialize(owner_node: Node) -> void:
	# 验证 owner_node
	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 验证目标节点路径
	if animation_player.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 获取目标节点
	_anim_player_ref = owner_node.get_node_or_null(animation_player)
	if not _anim_player_ref:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(animation_player)})
		return

	# 验证节点类型
	if not _anim_player_ref is AnimationPlayer:
		_create_fuse_error_localized("FUSE_ERROR_INVALID_TARGET", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(animation_player)})
		return

	# 连接信号
	if not _anim_player_ref.animation_finished.is_connected(_on_animation_finished):
		_anim_player_ref.animation_finished.connect(_on_animation_finished)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	# 断开信号连接
	if _anim_player_ref and is_instance_valid(_anim_player_ref):
		if _anim_player_ref.animation_finished.is_connected(_on_animation_finished):
			_anim_player_ref.animation_finished.disconnect(_on_animation_finished)

	# 清理引用
	_anim_player_ref = null

	# 清理 RuntimeEventInstance 引用
	_runtime_instance_ref = null

	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 动画完成回调
func _on_animation_finished(anim_name: String):
	# 检查是否匹配指定动画
	if not animation_name.is_empty() and anim_name != animation_name:
		_log_debug_localized("FUSE_LOG_EVENT_ANIMATION_FINISHED", {
			"animation": anim_name,
			"expected": animation_name,
			"status": "skipped"
		})
		return

	_log_info_localized("FUSE_LOG_EVENT_ANIMATION_FINISHED_TRIGGERED", {"animation": anim_name})

	# 传递动画名称（如果需要）
	if emit_animation_name:
		# 创建临时节点来传递参数
		var context_node = Node.new()
		context_node.name = "AnimationContext"
		context_node.set_meta("animation_name", anim_name)
		context_node.set_meta("animation_player", _anim_player_ref)
		_emit_triggered(context_node)
		# 注意：context_node 会在指令执行完后被 Trigger 清理
	else:
		triggered.emit(null)

## 获取事件描述
func get_description() -> String:
	var node_name = str(animation_player) if not animation_player.is_empty() else FuseLocalization.translate("FUSE_EVENT_ANIMATION_CURRENT_PLAYER")

	if animation_name.is_empty():
		return FuseLocalization.translate_format("FUSE_EVENT_ON_ANIMATION_FINISHED_DESC_ANY", {
			"target": node_name
		})
	else:
		return FuseLocalization.translate_format("FUSE_EVENT_ON_ANIMATION_FINISHED_DESC_SPECIFIC", {
			"target": node_name,
			"animation": animation_name
		})

## 获取事件类型
func get_event_type() -> String:
	return "animation_finished"

## 获取事件分类
func get_event_category() -> String:
	return "signal"

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	if animation_player.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))

	return errors

## 重置事件状态
func reset() -> void:
	super.reset()
	_log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_ON_ANIMATION_FINISHED_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_ANIMATION"
	metadata.description_key = "FUSE_EVENT_ON_ANIMATION_FINISHED_DESC"
	metadata.keywords = ["animation", "动画", "finished", "完成", "player", "播放器", "complete", "结束"]
	metadata.builtin_icon = "Animation"
	return metadata
