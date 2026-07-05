# JuicyTimelineDriver - Timeline系统驱动器
# 负责执行Timeline资源中的所有轨道
# 管理时间进度、循环和轨道状态
# 与JuicyMixer V3架构深度集成，支持参数映射和性能优化

class_name JuicyTimelineDriver
extends JuicyDriver

# =============================================================================
# DRIVER 元信息
# =============================================================================

func _init():
	driver_name = "JuicyTimelineDriver"
	driver_version = "1.0.0"
	supported_properties = []  # Timeline驱动器不直接操作属性，而是通过轨道间接操作
	required_context_data = ["timeline_resource", "current_time"]

# =============================================================================
# 时间轴状态管理
# =============================================================================

## Timeline 运行时状态类
class TimelineState:
	var current_time: float = 0.0
	var is_playing: bool = false
	var is_paused: bool = false
	var play_direction: int = 1  # 1为正向，-1为反向
	var current_loop: int = 0

	# 轨道状态跟踪
	var active_property_tracks: Array[JuicyPropertyTrack] = []
	var active_feedback_tracks: Array[JuicyFeedbackTrack] = []
	var active_method_tracks: Array[JuicyMethodTrack] = []
	var active_event_tracks: Array[JuicyEventTrack] = []

	# 触发状态记录
	var triggered_methods: Dictionary = {}  # method_track -> last_trigger_time
	var triggered_events: Dictionary = {}   # event_track -> last_trigger_time
	var active_sub_contexts: Dictionary = {}  # feedback_track -> context_id

	# 性能优化
	var property_batch_updates: Dictionary = {}  # property -> [value, mode]
	var last_processed_time: float = -1.0
	var track_cache_valid: bool = false

	# 性能统计
	var performance_stats: Dictionary = {
		"tracks_processed": 0,
		"properties_updated": 0,
		"sub_effects_triggered": 0,
		"methods_called": 0,
		"events_fired": 0
	}

# 引用Timeline资源
var timeline_resource: JuicyTimelineResource

## 按context_id隔离的Timeline状态
var _timeline_states: Dictionary = {}  # context_id -> TimelineState

# 调试和监控
var _debug_enabled: bool = false
var _performance_stats: Dictionary = {
	"tracks_processed": 0,
	"properties_updated": 0,
	"sub_effects_triggered": 0,
	"methods_called": 0,
	"events_fired": 0
}

# =============================================================================
# 核心接口实现 - JuicyDriver
# =============================================================================

## 准备阶段，初始化Timeline状态和轨道
func prepare(context: JuicyContext, delta: float, buffer: JuicyPropertyBuffer) -> void:
	"""
	准备阶段，初始化Timeline状态和轨道
	
	@param context: JuicyContext实例，包含效果运行所需的所有数据
	@param delta: 时间增量（秒）
	@param buffer: JuicyPropertyBuffer实例，用于属性缓冲
	"""
	# 获取Timeline资源
	timeline_resource = context.get_driver_data("timeline_resource") as JuicyTimelineResource
	
	# 如果driver_data中没有，尝试从context.resource获取（TimelineResource作为FeedbackResource播放时）
	if not timeline_resource:
		if context.resource and context.resource is JuicyTimelineResource:
			timeline_resource = context.resource as JuicyTimelineResource
		else:
			_log_error("Timeline resource not found in context")
			return
	
	# 🔥 Phase 3B: 确保时长自动计算在运行时生效
	if timeline_resource.auto_calculate_duration:
		timeline_resource.recalculate_duration()

	# ✅ 创建独立的 TimelineState
	var state = TimelineState.new()
	state.current_time = context.get_driver_data("current_time") if context.get_driver_data("current_time") != null else 0.0
	state.is_playing = true
	state.is_paused = false
	state.play_direction = 1
	state.current_loop = 0

	# 存储状态
	_timeline_states[context.context_id] = state

	# 初始化驱动器时间
	_initialize_driver_time(context)

	# 初始化轨道状态
	_initialize_track_states(context, state)

	# 初始化参数映射
	_initialize_parameter_mappings(context)
	
	# 重置性能统计
	_reset_performance_stats()
	
	_log_debug("Timeline driver prepared: " + timeline_resource.get_description())

## 处理阶段，每帧更新和时间推进
func process(context: JuicyContext, delta: float, buffer: JuicyPropertyBuffer) -> void:
	"""
	处理阶段，每帧更新和时间推进
	
	@param context: JuicyContext实例，包含效果运行所需的所有数据
	@param delta: 时间增量（秒）
	@param buffer: JuicyPropertyBuffer实例，用于属性缓冲
	"""
	# ✅ 获取状态
	var state = _timeline_states.get(context.context_id)
	if not state:
		_log_error("No timeline state found for context: " + context.context_id)
		return

	if not timeline_resource or not state.is_playing or state.is_paused:
		return

	# 开始性能计时
	var start_time = _start_execution_timer()

	# 更新驱动器时间
	var effective_delta = _update_driver_time(context, delta)

	# ✅ 使用 state.current_time 和 state.play_direction
	state.current_time += effective_delta * state.play_direction * timeline_resource.time_scale

	# 处理循环（暂时传递 state，Task 5 会完全修复）
	var loop_completed = _handle_looping(state)

	# 🔥 如果循环完成，重置 PropertyTrack 的状态（支持 relative 和 additive）
	if loop_completed:
		_reset_property_track_states(context)

	# 处理所有轨道
	_process_all_tracks(context, buffer, state)

	# 批处理属性更新
	_flush_property_updates(buffer, state)

	# 更新上下文时间
	context.current_time = state.current_time
	context.progress = get_progress(state)

	# 更新性能统计
	_end_execution_timer(start_time)
	_update_performance_stats(state)

	# 检查是否完成
	if not state.is_playing:
		print("[JuicyTimelineDriver] Timeline completed - current_time: ", state.current_time, ", timeline_duration: ", timeline_resource.timeline_duration)
		context.complete()

	_log_debug("Timeline processed: time=%.3f, progress=%.2f" % [state.current_time, context.progress])

## 清理阶段，清理资源和子效果
func cleanup(context: JuicyContext) -> void:
	"""
	清理阶段，清理资源和子效果

	@param context: JuicyContext实例，包含效果运行所需的所有数据
	"""
	# ✅ 获取并清理状态
	var state = _get_timeline_state(context)
	if not state:
		_log_warning("No timeline state found for cleanup: " + context.context_id)
		return

	# 停止所有活跃的子效果
	_cleanup_sub_effects(state)

	# 清理轨道状态
	_cleanup_track_states(state)

	# 清理驱动器时间
	_cleanup_driver_time(context)

	# ✅ 移除状态
	_timeline_states.erase(context.context_id)

	_log_debug("Timeline driver cleaned up")

## 获取 Timeline 状态（辅助方法）
func _get_timeline_state(context: JuicyContext) -> TimelineState:
	return _timeline_states.get(context.context_id)

## 确保 Timeline 状态存在（辅助方法）
func _ensure_timeline_state(context: JuicyContext) -> TimelineState:
	var state = _timeline_states.get(context.context_id)
	if not state:
		state = TimelineState.new()
		_timeline_states[context.context_id] = state
	return state

# =============================================================================
# 轨道处理逻辑
# =============================================================================

## 处理所有轨道
func _process_all_tracks(context: JuicyContext, buffer: JuicyPropertyBuffer, state: TimelineState = null) -> void:
	"""
	处理所有轨道

	@param context: JuicyContext实例
	@param buffer: JuicyPropertyBuffer实例
	@param state: Timeline运行时状态（可选，待迁移）
	"""
	if not state:
		state = _get_timeline_state(context)
		if not state:
			return

	# 如果时间没有变化，跳过处理
	if state.current_time == state.last_processed_time:
		return

	# 更新活跃轨道列表（如果需要）
	if not state.track_cache_valid:
		_update_active_track_lists(state)
		state.track_cache_valid = true

	# 处理属性轨道
	for track in state.active_property_tracks:
		_process_property_track(track, context, buffer, state)

	# 处理反馈轨道
	for track in state.active_feedback_tracks:
		_process_feedback_track(track, context, state)

	# 处理方法轨道
	for track in state.active_method_tracks:
		_process_method_track(track, context, state)

	# 处理事件轨道
	for track in state.active_event_tracks:
		_process_event_track(track, context, state)

	state.last_processed_time = state.current_time

## 处理属性轨道
func _process_property_track(track: JuicyPropertyTrack, context: JuicyContext, buffer: JuicyPropertyBuffer, state: TimelineState = null) -> void:
	"""
	处理属性轨道

	@param track: 属性轨道实例
	@param context: JuicyContext实例
	@param buffer: JuicyPropertyBuffer实例
	"""
	# 检查轨道是否在当前时间活跃
	var is_active = track.is_active_at_time(state.current_time, context)
	if not is_active:
		return

	# 检查轨道时间范围
	var in_time_range = not (state.current_time < track.get_start_time() or state.current_time > track.get_end_time())
	if not in_time_range:
		return

	# 获取轨道的目标节点
	var track_target = track.get_target_node()
	if not track_target:
		_log_warning("Failed to get target node for property track: " + track.track_name)
		return

	# 获取属性值
	var property_value = track.get_value_at_time(state.current_time, context)

	# 应用参数映射
	if track.use_parameter_mapping:
		property_value = track.apply_parameter_mappings(context, property_value)
		_log_debug("Applied parameter mappings for track '" + track.track_name + "': " + str(property_value))

	# 添加到批处理更新（使用轨道的目标节点）
	_add_property_batch_update(track_target, track.property_path, property_value, track.blend_mode, track, state)

	state.performance_stats.properties_updated += 1
	_log_debug("Property track processed: %s.%s = %s" % [track_target.name, track.property_path, property_value])

## 处理反馈轨道
func _process_feedback_track(track: JuicyFeedbackTrack, context: JuicyContext, state: TimelineState = null) -> void:
	"""
	处理反馈轨道

	@param track: 反馈轨道实例
	@param context: JuicyContext实例
	"""
	# 检查是否应该触发
	if not track.should_trigger(state.current_time, context):
		return

	# 获取轨道的目标节点
	var track_target = track.get_target_node()
	if not track_target:
		_log_warning("Failed to get target node for feedback track: " + track.track_name)
		return

	# 触发子效果（使用轨道的目标节点）
	var sub_context_id = track.trigger_sub_effect_with_target(track_target, context)
	if sub_context_id != "":
		state.active_sub_contexts[track] = sub_context_id
		state.performance_stats.sub_effects_triggered += 1
		_log_debug("Feedback track triggered: " + track.track_name + " on target: " + track_target.name)

	# 更新子效果参数
	if track in state.active_sub_contexts:
		var progress = (state.current_time - track.start_time) / track.get_actual_duration()
		track.update_sub_effect_parameters(context, progress)
		
		# 记录子效果参数更新
		_log_debug("Updated sub-effect parameters for track '" + track.track_name + "' at progress: " + str(progress))

## 处理方法轨道
func _process_method_track(track: JuicyMethodTrack, context: JuicyContext, state: TimelineState = null) -> void:
	"""
	处理方法轨道

	@param track: 方法轨道实例
	@param context: JuicyContext实例
	"""
	# 检查是否应该触发
	if not track.should_trigger(state.current_time, context):
		return

	# 获取轨道的目标节点
	var track_target = track.get_target_node()
	if not track_target:
		_log_warning("Failed to get target node for method track: " + track.track_name)
		return

	# 触发方法调用（使用轨道的目标节点）
	track.trigger_method_with_target(track_target, context)
	state.triggered_methods[track] = state.current_time
	state.performance_stats.methods_called += 1
	_log_debug("Method track triggered: " + track.method_name + " on target: " + track_target.name + " with parameter mappings")

	# 处理待处理的调用
	track.process_pending_calls(context)

## 处理事件轨道
func _process_event_track(track: JuicyEventTrack, context: JuicyContext, state: TimelineState = null) -> void:
	"""
	处理事件轨道
	
	@param track: 事件轨道实例
	@param context: JuicyContext实例
	"""
	# 检查是否应该触发
	if not track.should_trigger(state.current_time, context):
		return

	# 获取轨道的目标节点
	var track_target = track.get_target_node()
	if not track_target:
		_log_warning("Failed to get target node for event track: " + track.track_name)
		return

	# 触发事件（使用轨道的目标节点）
	track.trigger_event_with_target(track_target, context)
	state.triggered_events[track] = state.current_time
	state.performance_stats.events_fired += 1
	_log_debug("Event track triggered: " + track.track_name + " on target: " + track_target.name + " with parameter mappings")
	
	# 处理待处理的事件
	track.process_pending_events(context)

# =============================================================================
# 生命周期管理
# =============================================================================

## 初始化轨道状态
func _initialize_track_states(context: JuicyContext, state: TimelineState) -> void:
	"""
	初始化轨道状态

	@param context: JuicyContext实例
	@param state: Timeline运行时状态
	"""
	if not timeline_resource:
		return

	# 初始化所有轨道
	for track in timeline_resource.get_all_tracks():
		track.initialize_track(context)

	# 更新活跃轨道列表
	_update_active_track_lists(state)
	state.track_cache_valid = true

	# 清理触发状态
	state.triggered_methods.clear()
	state.triggered_events.clear()
	state.active_sub_contexts.clear()

## 清理轨道状态
func _cleanup_track_states(state: TimelineState) -> void:
	"""
	清理轨道状态

	@param state: Timeline运行时状态
	"""
	if not timeline_resource:
		return

	# 创建临时上下文用于清理
	var temp_context = JuicyContext.create(timeline_resource, null)

	# 清理所有轨道
	for track in timeline_resource.get_all_tracks():
		track.cleanup_track(temp_context)

	# 清理活跃轨道列表
	state.active_property_tracks.clear()
	state.active_feedback_tracks.clear()
	state.active_method_tracks.clear()
	state.active_event_tracks.clear()
	state.track_cache_valid = false

## 更新活跃轨道列表
func _update_active_track_lists(state: TimelineState) -> void:
	"""
	更新活跃轨道列表

	@param state: Timeline运行时状态
	"""
	if not timeline_resource:
		return

	# 清空现有列表
	state.active_property_tracks.clear()
	state.active_feedback_tracks.clear()
	state.active_method_tracks.clear()
	state.active_event_tracks.clear()

	# 按优先级排序轨道
	var all_tracks = timeline_resource.get_all_tracks()
	all_tracks.sort_custom(func(a, b): return a.priority > b.priority)

	# 分类轨道
	for track in all_tracks:
		if not track.enabled:
			continue

		match track.get_track_type():
			"Property":
				state.active_property_tracks.append(track as JuicyPropertyTrack)
			"Feedback":
				state.active_feedback_tracks.append(track as JuicyFeedbackTrack)
			"Method":
				state.active_method_tracks.append(track as JuicyMethodTrack)
			"Event":
				state.active_event_tracks.append(track as JuicyEventTrack)

## 清理子效果
func _cleanup_sub_effects(state: TimelineState) -> void:
	"""
	清理所有活跃的子效果

	@param state: Timeline运行时状态
	"""
	for track in state.active_sub_contexts.keys():
		var context_id = state.active_sub_contexts[track]
		if context_id != "":
			JuicyMixer.stop(context_id)

	state.active_sub_contexts.clear()

# =============================================================================
# 循环处理
# =============================================================================

## 处理循环逻辑
func _handle_looping(state: TimelineState) -> bool:
	"""
	处理循环逻辑

	@param state: Timeline运行时状态
	@return: 是否完成了一次循环
	"""
	if not timeline_resource or not state:
		return false

	var duration = timeline_resource.timeline_duration
	var loop_completed = false

	match timeline_resource.loop_mode:
		JuicyTimelineResource.LoopMode.NO_LOOP:
			# 无循环，检查是否结束
			if state.current_time >= duration:
				state.current_time = duration
				state.is_playing = false
			elif state.current_time < 0:
				state.current_time = 0
				state.is_playing = false

		JuicyTimelineResource.LoopMode.LOOP:
			# 循环播放
			if state.current_time >= duration:
				state.current_time = fmod(state.current_time, duration)
				state.current_loop += 1
				loop_completed = true
			elif state.current_time < 0:
				state.current_time = duration - fmod(abs(state.current_time), duration)
				state.current_loop += 1
				loop_completed = true

		JuicyTimelineResource.LoopMode.PING_PONG:
			# 往返播放
			if state.current_time >= duration:
				state.current_time = duration - (state.current_time - duration)
				state.play_direction = -1
				state.current_loop += 1
				loop_completed = true
			elif state.current_time < 0:
				state.current_time = -state.current_time
				state.play_direction = 1
				state.current_loop += 1
				loop_completed = true

	# 检查循环次数限制
	if timeline_resource.loop_count > 0 and state.current_loop >= timeline_resource.loop_count:
		state.is_playing = false

	# 重置触发状态（如果完成了一次循环）
	if loop_completed:
		_reset_trigger_states(state)

	return loop_completed

## 重置触发状态
func _reset_trigger_states(state: TimelineState) -> void:
	"""
	重置触发状态

	@param state: Timeline运行时状态
	"""
	# 重置Feedback Track的范围进入状态（支持循环时重新触发）
	for track in state.active_feedback_tracks:
		if track and track.has_method("_has_entered_range"):
			track._has_entered_range = false

	# 清理方法触发状态
	var methods_to_remove = []
	for track in state.triggered_methods.keys():
		if track.trigger_once:
			methods_to_remove.append(track)

	for track in methods_to_remove:
		state.triggered_methods.erase(track)

	# 清理事件触发状态
	var events_to_remove = []
	for track in state.triggered_events.keys():
		if track.trigger_once:
			events_to_remove.append(track)

	for track in events_to_remove:
		state.triggered_events.erase(track)

## 重置 PropertyTrack 状态（循环时调用）
func _reset_property_track_states(context: JuicyContext) -> void:
	"""
	重置 PropertyTrack 状态

	在 Timeline 循环时调用，通知所有 PropertyTrack 重置状态，
	支持 relative 和 additive 模式的正确行为。

	@param context: JuicyContext 实例
	"""
	if not timeline_resource:
		return

	# 遍历所有 PropertyTrack 并重置状态
	for track in timeline_resource.get_all_tracks():
		if track is JuicyPropertyTrack:
			track.reset_loop_state(context)

# =============================================================================
# 参数映射集成
# =============================================================================

## 初始化参数映射
func _initialize_parameter_mappings(context: JuicyContext) -> void:
	"""
	初始化参数映射
	
	@param context: JuicyContext实例
	"""
	if not timeline_resource:
		return
	
	# 应用参数预设
	for preset_name in timeline_resource.parameter_presets.keys():
		timeline_resource.apply_parameter_preset(preset_name, context)
	
	# 验证轨道的参数映射配置
	for track in timeline_resource.get_all_tracks():
		_validate_track_parameter_mappings(track, context)

## 验证轨道参数映射
func _validate_track_parameter_mappings(track: JuicyTrack, context: JuicyContext) -> void:
	"""
	验证轨道的参数映射配置
	
	@param track: 轨道实例
	@param context: JuicyContext实例
	"""
	if not track.has_method("get") or not track.get("use_parameter_mapping"):
		return
	
	if not track.use_parameter_mapping:
		return
	
	if not track.has_method("get") or not track.get("parameter_mappings"):
		return
	
	var parameter_mappings = track.parameter_mappings
	for i in range(parameter_mappings.size()):
		var mapping = parameter_mappings[i]
		if not mapping:
			continue
		
		# 验证映射配置
		var validation_error = mapping.validate_mapping()
		if not validation_error.is_empty():
			_log_warning("Parameter mapping validation failed in track '" + track.track_name + "' at index " + str(i) + ": " + validation_error)
			# 可以选择禁用无效的映射
			mapping.enabled = false

# =============================================================================
# 性能优化
# =============================================================================

## 添加属性批处理更新
func _add_property_batch_update(target_node: Node, property: String, value: Variant, mode: int, track: JuicyTrack = null, state: TimelineState = null) -> void:
	"""
	添加属性批处理更新

	@param target_node: 目标节点
	@param property: 属性名称
	@param value: 属性值
	@param mode: 混合模式
	@param track: 轨道实例（用于生成唯一的 context_id）
	@param state: Timeline运行时状态
	"""
	# 使用节点ID作为键，支持多个目标节点
	var node_id = target_node.get_instance_id()

	if not state.property_batch_updates.has(node_id):
		state.property_batch_updates[node_id] = {}

	# 🔥 使用 track 的唯一标识符作为 context_id，避免不同 track 互相覆盖
	var context_id = "timeline_driver"
	if track:
		context_id = "track_" + str(track.get_instance_id())

	# 🔥 修改数据结构：支持同一属性的多个轨道更新（使用数组）
	if not state.property_batch_updates[node_id].has(property):
		state.property_batch_updates[node_id][property] = []

	state.property_batch_updates[node_id][property].append({"value": value, "mode": mode, "context_id": context_id})

## 批处理属性更新
func _flush_property_updates(buffer: JuicyPropertyBuffer, state: TimelineState) -> void:
	"""
	批处理属性更新

	@param buffer: JuicyPropertyBuffer实例
	@param state: Timeline运行时状态
	"""
	if state.property_batch_updates.is_empty():
		return

	# 应用所有属性更新到各个目标节点
	for node_id in state.property_batch_updates:
		var node = instance_from_id(node_id) as Node
		if not node:
			continue

		var properties = state.property_batch_updates[node_id]
		for property in properties:
			var updates_array = properties[property]  # ← 现在是数组
			# 🔥 遍历所有轨道的更新
			for update_data in updates_array:
				buffer.add_sample(node, property, update_data.value, update_data.mode, update_data.context_id)

	# 清空批处理
	state.property_batch_updates.clear()

## 获取目标节点
func _get_target_node() -> Node:
	"""
	获取目标节点
	
	@return: 目标节点实例
	"""
	# 这里应该从Context获取目标节点
	# 由于Timeline驱动器的特殊性，我们需要特殊处理
	# 在实际实现中，可能需要从上下文或全局管理器获取
	return null  # 临时返回null，需要根据实际情况实现

## 重置性能统计
func _reset_performance_stats() -> void:
	"""
	重置性能统计
	"""
	_performance_stats = {
		"tracks_processed": 0,
		"properties_updated": 0,
		"sub_effects_triggered": 0,
		"methods_called": 0,
		"events_fired": 0
	}

## 更新性能统计
func _update_performance_stats(state: TimelineState = null) -> void:
	"""
	更新性能统计

	@param state: Timeline运行时状态
	"""
	state.performance_stats.tracks_processed = (
		state.active_property_tracks.size() +
		state.active_feedback_tracks.size() +
		state.active_method_tracks.size() +
		state.active_event_tracks.size()
	)

# =============================================================================
# 错误处理
# =============================================================================

## 验证轨道配置
func _validate_tracks() -> Array[String]:
	"""
	验证轨道配置
	
	@return: 错误信息数组
	"""
	var errors: Array[String] = []
	
	if not timeline_resource:
		errors.append("Timeline resource is null")
		return errors
	
	# 验证所有轨道
	var validation_result = timeline_resource.validate_config()
	if not validation_result.valid:
		errors.append_array(validation_result.issues)
	
	return errors

## 处理轨道错误
func _handle_track_error(track: JuicyTrack, error: String) -> void:
	"""
	处理轨道错误
	
	@param track: 出错的轨道
	@param error: 错误信息
	"""
	_log_error("Track error in '" + track.track_name + "': " + error)
	
	# 可以在这里实现错误恢复逻辑
	# 例如：禁用出错的轨道、使用默认值等

# =============================================================================
# 调试支持
# =============================================================================

## 启用调试模式
func enable_debug(enabled: bool) -> void:
	"""
	启用调试模式
	
	@param enabled: 是否启用调试
	"""
	_debug_enabled = enabled

## 获取调试信息
func get_debug_info(context: JuicyContext) -> Dictionary:
	"""
	获取调试信息

	@param context: JuicyContext实例
	@return: 调试信息字典
	"""
	var state = _get_timeline_state(context)

	return {
		"timeline_resource": timeline_resource.get_description() if timeline_resource else "null",
		"current_time": state.current_time if state else 0.0,
		"is_playing": state.is_playing if state else false,
		"is_paused": state.is_paused if state else false,
		"play_direction": state.play_direction if state else 1,
		"current_loop": state.current_loop if state else 0,
		"active_tracks": {
			"property": state.active_property_tracks.size() if state else 0,
			"feedback": state.active_feedback_tracks.size() if state else 0,
			"method": state.active_method_tracks.size() if state else 0,
			"event": state.active_event_tracks.size() if state else 0
		},
		"performance_stats": state.performance_stats.duplicate() if state else {},
		"driver_performance": get_performance_stats()
	}

## 记录调试日志
func _log_debug(message: String) -> void:
	"""
	记录调试日志
	
	@param message: 日志消息
	"""
	if _debug_enabled:
		print("[JuicyTimelineDriver] ", message)

## 记录警告日志
func _log_warning(message: String) -> void:
	"""
	记录警告日志
	
	@param message: 警告消息
	"""
	print("[JuicyTimelineDriver WARNING] ", message)

## 记录错误日志
func _log_error(message: String) -> void:
	"""
	记录错误日志
	
	@param message: 错误消息
	"""
	print("[JuicyTimelineDriver ERROR] ", message)

# =============================================================================
# 公共接口
# =============================================================================

## 获取播放进度（0.0-1.0）
func get_progress(state: TimelineState) -> float:
	"""
	获取播放进度

	@param state: Timeline运行时状态
	@return: 播放进度（0.0-1.0）
	"""
	if not timeline_resource or timeline_resource.timeline_duration <= 0:
		return 0.0

	return clampf(state.current_time / timeline_resource.timeline_duration, 0.0, 1.0)

## 设置播放时间
func set_time(context: JuicyContext, time: float) -> void:
	"""
	设置播放时间

	@param context: JuicyContext实例
	@param time: 时间值（秒）
	"""
	var state = _get_timeline_state(context)
	if not state:
		_log_warning("No timeline state found in set_time(): " + context.context_id)
		return

	if timeline_resource:
		state.current_time = clampf(time, 0.0, timeline_resource.timeline_duration)
		state.track_cache_valid = false  # 时间变化可能影响活跃轨道

## 获取当前循环次数
func get_current_loop(context: JuicyContext) -> int:
	"""
	获取当前循环次数

	@param context: JuicyContext实例
	@return: 循环次数
	"""
	var state = _get_timeline_state(context)
	return state.current_loop if state else 0

## 检查是否正在播放
func is_timeline_active(context: JuicyContext) -> bool:
	"""
	检查是否正在播放

	@param context: JuicyContext实例
	@return: 是否正在播放
	"""
	var state = _get_timeline_state(context)
	if not state:
		return false
	return state.is_playing and not state.is_paused

## 获取播放状态描述
func get_playback_state(context: JuicyContext) -> String:
	"""
	获取播放状态描述

	@param context: JuicyContext实例
	@return: 状态描述字符串
	"""
	var state = _get_timeline_state(context)
	if not state:
		return "Unknown"
	if not state.is_playing:
		return "Stopped"
	elif state.is_paused:
		return "Paused"
	else:
		return "Playing"
