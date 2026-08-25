@tool
@icon("res://addons/fuse/icons/builtin/Animation.png")
extends BaseEvent
class_name OnAnimationLoop

## Event: OnAnimationLoop
##
## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - _loop_counts: Dictionary - 跟踪每个动画的循环次数 {anim_name: count}
## - _last_positions: Dictionary - 跟踪每个动画的上次位置 {anim_name: position}
## - _has_looped: Dictionary - 跟踪动画是否已循环 {anim_name: bool}
##
## 架构版本: 自声明状态模式 v2.0
## 相关文档: addons/fuse/docs/migration-guide-to-runtime-instance.md

## 动画循环事件
##
## 当动画循环播放时触发（播放到末尾重新开始）。

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

## 循环次数阈值（0 表示不限制）
@export var loop_count_threshold: int = 0:
	set(value):
		loop_count_threshold = value
		_update_resource_name()

## 触发模式
enum TriggerMode {
	ON_EVERY_LOOP,         ## 每次循环都触发
	ON_THRESHOLD_REACHED   ## 达到阈值时触发
}

@export var trigger_mode: TriggerMode = TriggerMode.ON_EVERY_LOOP:
	set(value):
		trigger_mode = value
		_update_resource_name()

## 是否传递动画名称
@export var emit_animation_name: bool = true

## 是否传递当前循环次数
@export var emit_current_loop: bool = true

## 是否传递总循环次数
@export var emit_total_loops: bool = false

## 是否传递动画进度
@export var emit_animation_progress: bool = true

var _anim_player_ref: AnimationPlayer = null

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["loop_counts"] = {}
	base["last_positions"] = {}
	base["has_looped"] = {}
	return base

## 使用 RuntimeInstance 初始化事件
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		return

	_runtime_instance_ref = runtime_instance

	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 验证目标节点路径
	if target_node_path.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 获取目标节点
	_anim_player_ref = owner_node.get_node_or_null(target_node_path)
	if not _anim_player_ref:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(target_node_path)})
		return

	# 验证节点类型
	if not _anim_player_ref is AnimationPlayer:
		_create_fuse_error_localized("FUSE_ERROR_INVALID_TARGET", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(target_node_path)})
		return

	# 验证参数
	if loop_count_threshold < 0:
		_create_fuse_error_localized("FUSE_ERROR_LOOP_THRESHOLD_INVALID", FuseError.ErrorType.CONFIGURATION_ERROR, {"threshold": loop_count_threshold})
		return

	# 初始化状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("loop_counts", {})
		_runtime_instance_ref.set_runtime_state("last_positions", {})
		_runtime_instance_ref.set_runtime_state("has_looped", {})

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 更新资源名称（必需）
func _update_resource_name() -> void:
	var anim_text = animation_name if not animation_name.is_empty() else FuseLocalization.translate("FUSE_EVENT_ANIMATION_ANY")
	var node_name = _get_node_display_name(target_node_path) if not target_node_path.is_empty() else FuseLocalization.translate("FUSE_EVENT_ANIMATION_CURRENT_PLAYER")

	var mode_key = ""
	var threshold_text = ""

	match trigger_mode:
		TriggerMode.ON_EVERY_LOOP:
			mode_key = "FUSE_EVENT_ANIMATION_LOOP_EACH"
			if loop_count_threshold > 0:
				threshold_text = " [%s]" % FuseLocalization.translate_format("FUSE_EVENT_ANIMATION_LOOP_THRESHOLD", {"threshold": str(loop_count_threshold)})

		TriggerMode.ON_THRESHOLD_REACHED:
			if loop_count_threshold > 0:
				mode_key = "FUSE_EVENT_ANIMATION_LOOP_THRESHOLD_REACHED"
				threshold_text = " [%s]" % FuseLocalization.translate_format("FUSE_EVENT_ANIMATION_LOOP_THRESHOLD", {"threshold": str(loop_count_threshold)})
			else:
				mode_key = "FUSE_EVENT_ANIMATION_LOOP_UNLIMITED"

	resource_name = FuseLocalization.translate_format("FUSE_EVENT_ON_ANIMATION_LOOP_RESOURCE_NAME", {
		"target": node_name,
		"animation": anim_text,
		"mode": FuseLocalization.translate(mode_key),
		"threshold": threshold_text
	})

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	# 清理 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("loop_counts", {})
		_runtime_instance_ref.set_runtime_state("last_positions", {})
		_runtime_instance_ref.set_runtime_state("has_looped", {})
	_runtime_instance_ref = null

	# 清理引用
	_anim_player_ref = null

	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 每帧处理（用于检测循环）
func on_process(delta: float, event_instance: RuntimeEventInstance = null) -> void:
	if not _anim_player_ref or not is_instance_valid(_anim_player_ref):
		return

	# 检查是否正在播放
	if not _anim_player_ref.is_playing():
		return

	var current_anim = _anim_player_ref.current_animation
	if current_anim.is_empty():
		return

	# 检查是否匹配指定动画
	if not animation_name.is_empty() and current_anim != animation_name:
		return

	# 获取动画资源
	var animation = _anim_player_ref.get_animation(current_anim)
	if not animation:
		return

	# 检查动画是否循环
	if animation.loop_mode == Animation.LOOP_NONE:
		return

	var current_position = _anim_player_ref.current_animation_position
	var anim_length = animation.length

	# 获取状态字典
	var loop_counts = {}
	var last_positions = {}
	var has_looped = {}

	if _runtime_instance_ref:
		if _runtime_instance_ref.has_runtime_state("loop_counts"):
			loop_counts = _runtime_instance_ref.get_runtime_state("loop_counts")
		if _runtime_instance_ref.has_runtime_state("last_positions"):
			last_positions = _runtime_instance_ref.get_runtime_state("last_positions")
		if _runtime_instance_ref.has_runtime_state("has_looped"):
			has_looped = _runtime_instance_ref.get_runtime_state("has_looped")

	# 初始化跟踪数据
	if not loop_counts.has(current_anim):
		loop_counts[current_anim] = 0
		last_positions[current_anim] = 0.0
		has_looped[current_anim] = false

		if _runtime_instance_ref:
			_runtime_instance_ref.set_runtime_state("loop_counts", loop_counts)
			_runtime_instance_ref.set_runtime_state("last_positions", last_positions)
			_runtime_instance_ref.set_runtime_state("has_looped", has_looped)

	var last_position = last_positions[current_anim]

	# 检测循环：位置从接近末尾跳回到接近起始
	var epsilon = 0.1  # 容差
	var was_near_end = last_position > (anim_length - epsilon)
	var is_near_start = current_position < epsilon

	# 检测循环
	if was_near_end and is_near_start:
		loop_counts[current_anim] += 1
		has_looped[current_anim] = true
		last_positions[current_anim] = current_position

		if _runtime_instance_ref:
			_runtime_instance_ref.set_runtime_state("loop_counts", loop_counts)
			_runtime_instance_ref.set_runtime_state("has_looped", has_looped)
			_runtime_instance_ref.set_runtime_state("last_positions", last_positions)

		# 检查是否应该触发
		_check_and_trigger_loop(current_anim, animation)
	else:
		# 更新位置
		last_positions[current_anim] = current_position

		if _runtime_instance_ref:
			_runtime_instance_ref.set_runtime_state("last_positions", last_positions)

		# 如果已经不在起始位置，重置循环标志
		if current_position > epsilon * 2:
			has_looped[current_anim] = false

			if _runtime_instance_ref:
				_runtime_instance_ref.set_runtime_state("has_looped", has_looped)

## 检查并触发循环事件
func _check_and_trigger_loop(anim_name: String, animation: Animation) -> void:
	var loop_counts = {}
	if _runtime_instance_ref and _runtime_instance_ref.has_runtime_state("loop_counts"):
		loop_counts = _runtime_instance_ref.get_runtime_state("loop_counts")

	var loop_count = loop_counts.get(anim_name, 0)
	var should_trigger = false

	match trigger_mode:
		TriggerMode.ON_EVERY_LOOP:
			should_trigger = true

		TriggerMode.ON_THRESHOLD_REACHED:
			if loop_count_threshold > 0 and loop_count >= loop_count_threshold:
				should_trigger = true
				# 达到阈值后，可以继续触发或停止
				# 这里选择继续触发，以便用户知道超过阈值

	if should_trigger:
		_trigger_animation_loop(anim_name, loop_count, animation)

## 触发动画循环事件
func _trigger_animation_loop(anim_name: String, current_loop: int, animation: Animation) -> void:
	var anim_length = animation.length
	var current_pos = _anim_player_ref.current_animation_position
	var progress = 0.0
	if anim_length > 0:
		progress = current_pos / anim_length

	_log_info_localized("FUSE_LOG_EVENT_ANIMATION_LOOP_TRIGGERED", {
		"animation": anim_name,
		"loop_count": current_loop
	})

	# 创建上下文节点传递参数
	var context_node = Node.new()
	context_node.name = "AnimationLoopContext"

	if emit_animation_name:
		context_node.set_meta("animation_name", anim_name)

	if emit_current_loop:
		context_node.set_meta("current_loop", current_loop)

	if emit_total_loops:
		context_node.set_meta("total_loops", current_loop)

	if emit_animation_progress:
		context_node.set_meta("animation_progress", progress)

	context_node.set_meta("animation_player", _anim_player_ref)

	triggered.emit(context_node)

	# 清理上下文节点
	context_node.queue_free()

## 获取事件描述
func get_description() -> String:
	var node_name = _get_node_display_name(target_node_path) if not target_node_path.is_empty() else FuseLocalization.translate("FUSE_EVENT_ANIMATION_CURRENT_PLAYER")
	var anim_text = animation_name if not animation_name.is_empty() else FuseLocalization.translate("FUSE_EVENT_ANIMATION_ANY")

	var mode_key = ""
	var threshold_text = ""

	match trigger_mode:
		TriggerMode.ON_EVERY_LOOP:
			mode_key = "FUSE_EVENT_ANIMATION_LOOP_EACH"
			if loop_count_threshold > 0:
				threshold_text = FuseLocalization.translate_format("FUSE_EVENT_ANIMATION_LOOP_DESC_THRESHOLD", {
					"threshold": str(loop_count_threshold)
				})

		TriggerMode.ON_THRESHOLD_REACHED:
			if loop_count_threshold > 0:
				mode_key = "FUSE_EVENT_ANIMATION_LOOP_THRESHOLD_REACHED"
				threshold_text = FuseLocalization.translate_format("FUSE_EVENT_ANIMATION_LOOP_DESC_THRESHOLD", {
					"threshold": str(loop_count_threshold)
				})
			else:
				mode_key = "FUSE_EVENT_ANIMATION_LOOP_UNLIMITED"

	return FuseLocalization.translate_format("FUSE_EVENT_ON_ANIMATION_LOOP_DESC", {
		"target": node_name,
		"animation": anim_text,
		"mode": FuseLocalization.translate(mode_key),
		"threshold": threshold_text
	})

## 获取事件类型
func get_event_type() -> String:
	return "animation_loop"

## 获取事件分类
func get_event_category() -> String:
	return "signal"

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	if target_node_path.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))

	if loop_count_threshold < 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_LOOP_THRESHOLD_INVALID"))

	return errors

## 重置事件状态
func reset() -> void:
	super.reset()
	# 重置 RuntimeInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("loop_counts", {})
		_runtime_instance_ref.set_runtime_state("last_positions", {})
		_runtime_instance_ref.set_runtime_state("has_looped", {})
	_log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_ON_ANIMATION_LOOP_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_ANIMATION"
	metadata.description_key = "FUSE_EVENT_ON_ANIMATION_LOOP_DESC"
	metadata.keywords = ["animation", "动画", "loop", "循环", "player", "播放器", "repeat", "重复", "iterate", "迭代"]
	metadata.builtin_icon = "Animation"
	return metadata
