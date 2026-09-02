@tool
@icon("res://addons/fuse/icons/builtin/Animation.png")
extends BaseEvent
class_name OnAnimationStarted

## Event: OnAnimationStarted
##
## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - _triggered_animations: Dictionary - 跟踪已触发的动画（key: 动画名, value: 是否已触发）
##
## 架构版本: 自声明状态模式 v2.0
## 相关文档: addons/fuse/docs/zh_CN/dev_docs/guides/runtime-instance-migration-guide.md

## 动画开始事件
##
## 当 AnimationPlayer 开始播放动画时触发。

## 目标 AnimationPlayer 节点路径
@export var target_node_path: NodePath = NodePath(""):
	set(value):
		target_node_path = value
		_update_resource_name()

## 动画名称（空字符串表示任意动画）
@export var animation_name: String = "":
	set(value):
		animation_name = value
		_update_resource_name()

## 每个动画只触发一次
@export var trigger_once_per_animation: bool = false:
	set(value):
		trigger_once_per_animation = value
		_update_resource_name()

## 是否传递动画名称
@export var emit_animation_name: bool = true

## 是否传递动画长度
@export var emit_animation_length: bool = true

## 是否传递动画循环模式
@export var emit_loop_mode: bool = false

var _anim_player_ref: Node = null
var _owner_node_ref: Node = null

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["triggered_animations"] = {}
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

	# 验证目标节点路径
	if target_node_path.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 获取目标节点（AnimationPlayer 或 AnimatedSprite2D）
	var _resolved_node: Node = owner_node.get_node_or_null(target_node_path)
	if not _resolved_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(target_node_path)})
		return

	_anim_player_ref = _resolved_node
	# 验证节点类型
	if not (_resolved_node is AnimationPlayer or _resolved_node is AnimatedSprite2D):
		_create_fuse_error_localized("FUSE_ERROR_INVALID_TARGET", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(target_node_path)})
		return

	_owner_node_ref = owner_node

	# 初始化 RuntimeEventInstance 状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("triggered_animations", {})

	# AnimationPlayer 有 animation_started；AnimatedSprite2D 无此信号，
	# 以 animation_changed（play 设置新动画时发射）近似"开始"
	if _anim_player_ref.has_signal("animation_started"):
		if not _anim_player_ref.animation_started.is_connected(_on_animation_started):
			_anim_player_ref.animation_started.connect(_on_animation_started)
	elif _anim_player_ref.has_signal("animation_changed"):
		if not _anim_player_ref.animation_changed.is_connected(_on_animation_started.bind("")):
			# animation_changed 无参信号，绑定空参适配 _on_animation_started(anim_name)
			_anim_player_ref.animation_changed.connect(_on_animation_started.bind(""))
		_log_debug_localized("FUSE_LOG_EVENT_ANIMATION_USING_SIGNAL", {"signal": "animation_started"})
	else:
		# 如果没有信号，使用轮询方式
		_log_debug_localized("FUSE_LOG_EVENT_ANIMATION_USING_POLLING", {})

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 更新资源名称（必需）
func _update_resource_name() -> void:
	var anim_text = animation_name if not animation_name.is_empty() else FuseLocalization.translate("FUSE_EVENT_ANIMATION_ANY")
	var once_key = "FUSE_EVENT_ANIMATION_ONCE_PER_ANIMATION" if trigger_once_per_animation else "FUSE_EVENT_ANIMATION_EACH"
	var once_text = " [%s]" % FuseLocalization.translate(once_key)

	var node_name = _get_node_display_name(target_node_path) if not target_node_path.is_empty() else FuseLocalization.translate("FUSE_EVENT_ANIMATION_CURRENT_PLAYER")

	resource_name = FuseLocalization.translate_format("FUSE_EVENT_ON_ANIMATION_STARTED_RESOURCE_NAME", {
		"target": node_name,
		"animation": anim_text,
		"timing": once_text
	})

## 初始化事件监听（必需）- 向后兼容
func initialize(owner_node: Node) -> void:
	# 验证 owner_node
	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 验证目标节点路径
	if target_node_path.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 获取目标节点（AnimationPlayer 或 AnimatedSprite2D）
	var _resolved_node: Node = owner_node.get_node_or_null(target_node_path)
	if not _resolved_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(target_node_path)})
		return

	_anim_player_ref = _resolved_node
	# 验证节点类型
	if not (_resolved_node is AnimationPlayer or _resolved_node is AnimatedSprite2D):
		_create_fuse_error_localized("FUSE_ERROR_INVALID_TARGET", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(target_node_path)})
		return

	_owner_node_ref = owner_node

	# AnimationPlayer 有 animation_started；AnimatedSprite2D 无此信号，
	# 以 animation_changed（play 设置新动画时发射）近似"开始"
	if _anim_player_ref.has_signal("animation_started"):
		if not _anim_player_ref.animation_started.is_connected(_on_animation_started):
			_anim_player_ref.animation_started.connect(_on_animation_started)
	elif _anim_player_ref.has_signal("animation_changed"):
		if not _anim_player_ref.animation_changed.is_connected(_on_animation_started.bind("")):
			# animation_changed 无参信号，绑定空参适配 _on_animation_started(anim_name)
			_anim_player_ref.animation_changed.connect(_on_animation_started.bind(""))
		_log_debug_localized("FUSE_LOG_EVENT_ANIMATION_USING_SIGNAL", {"signal": "animation_started"})
	else:
		# 如果没有信号，使用轮询方式
		_log_debug_localized("FUSE_LOG_EVENT_ANIMATION_USING_POLLING", {})

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	# 断开信号连接
	if _anim_player_ref and is_instance_valid(_anim_player_ref):
		if _anim_player_ref.has_signal("animation_started"):
			if _anim_player_ref.animation_started.is_connected(_on_animation_started):
				_anim_player_ref.animation_started.disconnect(_on_animation_started)

	# 清理 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("triggered_animations", {})

	# 清理引用
	_anim_player_ref = null
	_owner_node_ref = null
	_runtime_instance_ref = null

	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 每帧处理（用于轮询方式）
func on_process(delta: float, event_instance: RuntimeEventInstance = null) -> void:
	if not _anim_player_ref or not is_instance_valid(_anim_player_ref):
		return

	# 如果已经有 animation_started 信号，不需要轮询
	if _anim_player_ref.has_signal("animation_started"):
		return

	# AnimatedSprite2D 无 current_animation 属性且已由 animation_changed 信号驱动——跳过轮询
	if _anim_player_ref is AnimatedSprite2D:
		return

	# 轮询检测动画开始
	var current_anim = _anim_player_ref.current_animation
	if current_anim.is_empty():
		return

	# 检查是否匹配指定动画
	if not animation_name.is_empty() and current_anim != animation_name:
		return

	# 检查是否已经触发过
	if trigger_once_per_animation and _runtime_instance_ref:
		var triggered_animations = _runtime_instance_ref.get_runtime_state("triggered_animations")
		if triggered_animations and triggered_animations.has(current_anim):
			return

	# 检查是否正在播放
	if not _anim_player_ref.is_playing():
		return

	# 检查播放位置，判断是否刚开始
	var playback_position = _anim_player_ref.current_animation_position
	if playback_position > 0.1:  # 不是刚开始
		return

	# 触发事件
	_trigger_animation_started(current_anim)

## 动画开始回调
func _on_animation_started(anim_name: StringName):
	# 检查是否匹配指定动画
	if not animation_name.is_empty() and anim_name != animation_name:
		_log_debug_localized("FUSE_LOG_EVENT_ANIMATION_STARTED", {
			"animation": anim_name,
			"expected": animation_name,
			"status": "skipped"
		})
		return

	# 检查是否已经触发过
	if trigger_once_per_animation and _runtime_instance_ref:
		var triggered_animations = _runtime_instance_ref.get_runtime_state("triggered_animations")
		if triggered_animations and triggered_animations.has(anim_name):
			_log_debug_localized("FUSE_LOG_EVENT_ANIMATION_ALREADY_TRIGGERED", {"animation": anim_name})
			return

	_trigger_animation_started(anim_name)

## 触发动画开始事件
func _trigger_animation_started(anim_name: StringName):
	# 标记为已触发
	if trigger_once_per_animation and _runtime_instance_ref:
		var triggered_animations = _runtime_instance_ref.get_runtime_state("triggered_animations")
		if not triggered_animations:
			triggered_animations = {}
		triggered_animations[anim_name] = true
		_runtime_instance_ref.set_runtime_state("triggered_animations", triggered_animations)

	_log_info_localized("FUSE_LOG_EVENT_ANIMATION_STARTED_TRIGGERED", {"animation": anim_name})

	# 创建上下文节点传递参数
	var context_node = Node.new()
	context_node.name = "AnimationStartedContext"

	if emit_animation_name:
		context_node.set_meta("animation_name", anim_name)

	if emit_animation_length or emit_loop_mode:
		var animation = _anim_player_ref.get_animation(anim_name)
		if animation:
			if emit_animation_length:
				context_node.set_meta("animation_length", animation.length)
			if emit_loop_mode:
				context_node.set_meta("loop_mode", animation.loop_mode)

	context_node.set_meta("animation_player", _anim_player_ref)

	triggered.emit(context_node)

	# 清理上下文节点
	context_node.queue_free()

## 获取事件描述
func get_description() -> String:
	var node_name = _get_node_display_name(target_node_path) if not target_node_path.is_empty() else FuseLocalization.translate("FUSE_EVENT_ANIMATION_CURRENT_PLAYER")
	var once_key = "FUSE_EVENT_ANIMATION_ONCE_PER_ANIMATION" if trigger_once_per_animation else "FUSE_EVENT_ANIMATION_EACH"
	var once_text = FuseLocalization.translate(once_key)

	var animation_key = "FUSE_EVENT_ANIMATION_ANY" if animation_name.is_empty() else "FUSE_EVENT_ANIMATION_SPECIFIC"
	var animation_text = FuseLocalization.translate(animation_key)

	if animation_name.is_empty():
		return FuseLocalization.translate_format("FUSE_EVENT_ON_ANIMATION_STARTED_DESC_ANY", {
			"target": node_name,
			"timing": once_text
		})
	else:
		return FuseLocalization.translate_format("FUSE_EVENT_ON_ANIMATION_STARTED_DESC_SPECIFIC", {
			"target": node_name,
			"animation": animation_name,
			"timing": once_text
		})

## 获取事件类型
func get_event_type() -> String:
	return "animation_started"

## 获取事件分类
func get_event_category() -> String:
	return "signal"

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	if target_node_path.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))

	# 可选：验证动画名称是否存在
	if not target_node_path.is_empty() and not animation_name.is_empty():
		# 注意：无法在编辑器中验证，因为节点可能不存在
		pass

	return errors

## 重置事件状态
func reset() -> void:
	super.reset()
	# 重置 RuntimeInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("triggered_animations", {})
	_log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_ON_ANIMATION_STARTED_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_ANIMATION"
	metadata.description_key = "FUSE_EVENT_ON_ANIMATION_STARTED_DESC"
	metadata.keywords = ["animation", "动画", "started", "开始", "player", "播放器", "begin", "启动", "play", "播放"]
	metadata.builtin_icon = "Animation"
	return metadata
