@tool
@icon("res://addons/fuse/icons/builtin/Animation.png")
extends BaseEvent
class_name OnAnimationMarker

## Event: OnAnimationMarker
##
## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - _triggered_markers: Dictionary - 跟踪已触发的标记 {anim_name: {marker_name: true}}
## - _last_position: float - 上次播放位置
##
## 架构版本: 自声明状态模式 v2.0
## 相关文档: addons/fuse/docs/migration-guide-to-runtime-instance.md

## 动画标记到达事件
##
## 当动画播放到达指定标记点时触发。

## 目标 AnimationPlayer 节点路径
@export var target_node_path: NodePath = NodePath(""):
	set(value):
		target_node_path = value
		_update_resource_name()

## 标记名称（空字符串表示任意标记）
@export var marker_name: String = "":
	set(value):
		marker_name = value
		_update_resource_name()

## 动画名称（空字符串表示任意动画）
@export var animation_name: String = "":
	set(value):
		animation_name = value
		_update_resource_name()

## 每次播放只触发一次
@export var trigger_once_per_play: bool = false:
	set(value):
		trigger_once_per_play = value
		_update_resource_name()

## 是否传递动画名称
@export var emit_animation_name: bool = true

## 是否传递标记名称
@export var emit_marker_name: bool = true

## 是否传递标记位置
@export var emit_marker_position: bool = true

## 是否传递当前播放位置
@export var emit_current_position: bool = true

# 运行时引用
var _anim_player_ref: AnimationPlayer = null
var _owner_node_ref: Node = null

## 更新资源名称（必需）
func _update_resource_name() -> void:
	var marker_text = marker_name if not marker_name.is_empty() else FuseLocalization.translate("FUSE_EVENT_ANIMATION_ANY_MARKER")
	var anim_text = animation_name if not animation_name.is_empty() else FuseLocalization.translate("FUSE_EVENT_ANIMATION_ANY")
	var once_key = "FUSE_EVENT_ANIMATION_ONCE_PER_PLAY" if trigger_once_per_play else "FUSE_EVENT_ANIMATION_EACH"
	var once_text = " [%s]" % FuseLocalization.translate(once_key)

	var node_name = _get_node_display_name(target_node_path) if not target_node_path.is_empty() else FuseLocalization.translate("FUSE_EVENT_ANIMATION_CURRENT_PLAYER")

	resource_name = FuseLocalization.translate_format("FUSE_EVENT_ON_ANIMATION_MARKER_RESOURCE_NAME", {
		"target": node_name,
		"animation": anim_text,
		"marker": marker_text,
		"timing": once_text
	})

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["triggered_markers"] = {}  # 跟踪已触发的标记 {anim_name: {marker_name: true}}
	base["last_position"] = -1.0
	return base

## 使用运行时实例初始化事件
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		return

	_runtime_instance_ref = runtime_instance

	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	if target_node_path.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	_anim_player_ref = owner_node.get_node_or_null(target_node_path)
	if not _anim_player_ref:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(target_node_path)})
		return

	if not _anim_player_ref is AnimationPlayer:
		_create_fuse_error_localized("FUSE_ERROR_INVALID_TARGET", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(target_node_path)})
		return

	_owner_node_ref = owner_node

	# 初始化状态
	_runtime_instance_ref.set_runtime_state("triggered_markers", {})
	_runtime_instance_ref.set_runtime_state("last_position", -1.0)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 初始化事件监听（必需）- 向后兼容
func initialize(owner_node: Node) -> void:
	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	if target_node_path.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	_anim_player_ref = owner_node.get_node_or_null(target_node_path)
	if not _anim_player_ref:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(target_node_path)})
		return

	if not _anim_player_ref is AnimationPlayer:
		_create_fuse_error_localized("FUSE_ERROR_INVALID_TARGET", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(target_node_path)})
		return

	_owner_node_ref = owner_node

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	# 清理引用
	_anim_player_ref = null
	_owner_node_ref = null

	# 清理 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("triggered_markers", {})
		_runtime_instance_ref.set_runtime_state("last_position", -1.0)
	_runtime_instance_ref = null

	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 每帧处理（用于检测标记）
func on_process(delta: float, event_instance: RuntimeEventInstance = null) -> void:
	if not _anim_player_ref or not is_instance_valid(_anim_player_ref):
		return

	var last_position = -1.0
	if _runtime_instance_ref and _runtime_instance_ref.has_runtime_state("last_position"):
		last_position = _runtime_instance_ref.get_runtime_state("last_position")

	# 检查是否正在播放
	if not _anim_player_ref.is_playing():
		if _runtime_instance_ref:
			_runtime_instance_ref.set_runtime_state("last_position", -1.0)
		return

	var current_anim = _anim_player_ref.current_animation
	if current_anim.is_empty():
		if _runtime_instance_ref:
			_runtime_instance_ref.set_runtime_state("last_position", -1.0)
		return

	# 检查是否匹配指定动画
	if not animation_name.is_empty() and current_anim != animation_name:
		if _runtime_instance_ref:
			_runtime_instance_ref.set_runtime_state("last_position", -1.0)
		return

	# 获取动画资源
	var animation = _anim_player_ref.get_animation(current_anim)
	if not animation:
		return

	var current_position = _anim_player_ref.current_animation_position

	# 检查标记点
	_check_markers(animation, current_anim, current_position)

	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("last_position", current_position)

## 检查标记点
func _check_markers(animation: Animation, anim_name: String, current_pos: float) -> void:
	# 遍历所有轨道查找标记
	for track_idx in animation.get_track_count():
		var track_type = animation.track_get_type(track_idx)

		# 只处理值轨道——track_get_type 返回枚举 int（Godot 3 返回字符串，历史代码误用）
		if track_type != Animation.TYPE_VALUE:
			continue

		# 检查轨道上的所有关键帧
		var key_count = animation.track_get_key_count(track_idx)
		for key_idx in key_count:
			var key_time = animation.track_get_key_time(track_idx, key_idx)
			var key_value = animation.track_get_key_value(track_idx, key_idx)

			# 检查是否是标记（通常标记存储在特定的轨道或关键帧中）
			# AnimationPlayer 在 Godot 4 中没有专门的标记系统
			# 但我们可以检查关键帧的元数据或特定值
			if key_value is String and not key_value.is_empty():
				# 假设标记是字符串值
				_check_marker_passed(anim_name, key_value, key_time, current_pos)
			elif animation.track_get_key_value(track_idx, key_idx) is Dictionary:
				# 检查是否是标记字典
				var marker_data = animation.track_get_key_value(track_idx, key_idx)
				if marker_data.has("marker"):
					_check_marker_passed(anim_name, marker_data.marker, key_time, current_pos)

## 检查标记是否被经过
func _check_marker_passed(anim_name: String, marker: String, marker_pos: float, current_pos: float) -> void:
	# 检查是否匹配指定标记
	if not marker_name.is_empty() and marker != marker_name:
		return

	var triggered_markers = {}
	if _runtime_instance_ref and _runtime_instance_ref.has_runtime_state("triggered_markers"):
		triggered_markers = _runtime_instance_ref.get_runtime_state("triggered_markers")

	# 检查是否已经触发过
	if trigger_once_per_play:
		if not triggered_markers.has(anim_name):
			triggered_markers[anim_name] = {}
		if triggered_markers.has(anim_name) and triggered_markers[anim_name].has(marker):
			return

	# 检查是否刚刚经过标记点（使用容差）
	var epsilon = 0.02  # 2 帧容差
	var last_position = -1.0
	if _runtime_instance_ref and _runtime_instance_ref.has_runtime_state("last_position"):
		last_position = _runtime_instance_ref.get_runtime_state("last_position")

	var was_before = last_position < marker_pos - epsilon
	var is_after = current_pos >= marker_pos - epsilon

	# 处理循环情况
	if current_pos < last_position:
		# 动画循环了，重置触发状态
		if trigger_once_per_play and triggered_markers.has(anim_name):
			triggered_markers[anim_name].clear()
			if _runtime_instance_ref:
				_runtime_instance_ref.set_runtime_state("triggered_markers", triggered_markers)
		was_before = true  # 假设经过了标记

	if was_before and is_after:
		# 触发事件
		_trigger_marker_reached(anim_name, marker, marker_pos, current_pos)

## 触发标记到达事件
func _trigger_marker_reached(anim_name: String, marker: String, marker_pos: float, current_pos: float) -> void:
	# 标记为已触发
	if trigger_once_per_play and _runtime_instance_ref:
		var triggered_markers = {}
		if _runtime_instance_ref.has_runtime_state("triggered_markers"):
			triggered_markers = _runtime_instance_ref.get_runtime_state("triggered_markers")

		if not triggered_markers.has(anim_name):
			triggered_markers[anim_name] = {}
		triggered_markers[anim_name][marker] = true

		_runtime_instance_ref.set_runtime_state("triggered_markers", triggered_markers)

	_log_info_localized("FUSE_LOG_EVENT_ANIMATION_MARKER_TRIGGERED", {
		"animation": anim_name,
		"marker": marker,
		"position": marker_pos
	})

	# 创建上下文节点传递参数
	var context_node = Node.new()
	context_node.name = "AnimationMarkerContext"

	if emit_animation_name:
		context_node.set_meta("animation_name", anim_name)

	if emit_marker_name:
		context_node.set_meta("marker_name", marker)

	if emit_marker_position:
		context_node.set_meta("marker_position", marker_pos)

	if emit_current_position:
		context_node.set_meta("current_position", current_pos)

	context_node.set_meta("animation_player", _anim_player_ref)

	triggered.emit(context_node)

	# 清理上下文节点
	context_node.queue_free()

## 获取事件描述
func get_description() -> String:
	var node_name = _get_node_display_name(target_node_path) if not target_node_path.is_empty() else FuseLocalization.translate("FUSE_EVENT_ANIMATION_CURRENT_PLAYER")
	var marker_text = marker_name if not marker_name.is_empty() else FuseLocalization.translate("FUSE_EVENT_ANIMATION_ANY_MARKER")
	var anim_text = animation_name if not animation_name.is_empty() else FuseLocalization.translate("FUSE_EVENT_ANIMATION_ANY")
	var once_key = "FUSE_EVENT_ANIMATION_ONCE_PER_PLAY" if trigger_once_per_play else "FUSE_EVENT_ANIMATION_EACH"
	var once_text = FuseLocalization.translate(once_key)

	return FuseLocalization.translate_format("FUSE_EVENT_ON_ANIMATION_MARKER_DESC", {
		"target": node_name,
		"animation": anim_text,
		"marker": marker_text,
		"timing": once_text
	})

## 获取事件类型
func get_event_type() -> String:
	return "animation_marker"

## 获取事件分类
func get_event_category() -> String:
	return "signal"

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	if target_node_path.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))

	# 可选：验证动画名称和标记名称
	# 注意：无法在编辑器中验证，因为节点可能不存在

	return errors

## 重置事件状态
func reset() -> void:
	super.reset()

	# 重置 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("triggered_markers", {})
		_runtime_instance_ref.set_runtime_state("last_position", -1.0)

	_log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_ON_ANIMATION_MARKER_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_ANIMATION"
	metadata.description_key = "FUSE_EVENT_ON_ANIMATION_MARKER_DESC"
	metadata.keywords = ["animation", "动画", "marker", "标记", "player", "播放器", "track", "轨道", "keyframe", "关键帧", "cue", "提示点"]
	metadata.builtin_icon = "Animation"
	return metadata
