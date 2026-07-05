class_name ActiveMusicState
extends RefCounted

## 活跃音乐状态
##
## 跟踪当前播放的音乐状态

## 音乐阶段枚举
enum MusicPhase {
	INTRO,      # 播放 Intro 段
	LOOP,       # 播放 Loop 段
	FADING_OUT, # 淡出中
	FADING_IN,  # 淡入中
	STOPPED     # 已停止
}

# =============================================================================
# 核心状态
# =============================================================================

var track_resource: MusicTrackResource
var current_stream_player: AudioStreamPlayer
var current_phase: MusicPhase = MusicPhase.STOPPED

# =============================================================================
# 播放状态
# =============================================================================

var playback_position: float = 0.0
var target_volume: float = 0.0
var current_volume: float = 0.0

# =============================================================================
# 叠加层
# =============================================================================

var active_layers: Dictionary = {}  # {layer_id: ActiveLayerState}

# =============================================================================
# 持久化状态
# =============================================================================

var persistence_key: String = ""
var scene_persistence_enabled: bool = false

# =============================================================================
# 中断处理状态
# =============================================================================

## 挂起状态枚举
enum SuspensionState {
	NONE,                   # 正在播放
	STOPPED,                # STOP_AND_RESTART 模式：已停止
	PAUSED,                 # PAUSE_AND_RESUME 模式：已暂停
	DUCKED                  # KEEP_PLAYING_SILENTLY 模式：已降低音量
}

var suspension_state: SuspensionState = SuspensionState.NONE

## PAUSE_AND_RESUME 模式：保存的播放位置
var saved_playback_position: float = 0.0

## PAUSE_AND_RESUME 模式：保存的播放器（保持引用但不播放）
var saved_stream_player: AudioStreamPlayer = null

## KEEP_PLAYING_SILENTLY 模式：原始音量（用于恢复）
var original_volume_db: float = 0.0

# =============================================================================
# 音乐层状态（内部类）
# =============================================================================

class ActiveLayerState:
	var layer_resource: MusicLayerResource
	var layer_player: AudioStreamPlayer
	var layer_phase: MusicPhase
	var current_volume: float = 0.0
	var target_volume: float = 0.0

# =============================================================================
# 初始化
# =============================================================================

static func create(track: MusicTrackResource, player: AudioStreamPlayer) -> ActiveMusicState:
	var state = ActiveMusicState.new()
	state.track_resource = track
	state.current_stream_player = player
	state.current_phase = MusicPhase.FADING_IN
	state.target_volume = 0.0  # 目标音量，根据资源设置
	state.current_volume = -60.0  # 从静音开始
	return state

# =============================================================================
# 状态查询
# =============================================================================

## 是否正在播放
func is_playing() -> bool:
	return current_phase != MusicPhase.STOPPED

## 是否在过渡中
func is_transitioning() -> bool:
	return current_phase in [MusicPhase.FADING_IN, MusicPhase.FADING_OUT]

## 是否播放 Intro
func is_intro_phase() -> bool:
	return current_phase == MusicPhase.INTRO

## 是否播放 Loop
func is_loop_phase() -> bool:
	return current_phase == MusicPhase.LOOP

## 获取播放进度（0.0-1.0）
func get_progress() -> float:
	if not track_resource or not current_stream_player:
		return 0.0

	var duration: float
	if is_intro_phase():
		duration = track_resource.get_intro_duration()
	else:
		duration = track_resource.get_loop_duration()

	if duration == 0.0:
		return 0.0

	return current_stream_player.get_playback_position() / duration

# =============================================================================
# 层管理
# =============================================================================

## 添加活跃层
func add_layer(layer_id: String, layer_state: ActiveLayerState):
	active_layers[layer_id] = layer_state

## 移除活跃层
func remove_layer(layer_id: String):
	active_layers.erase(layer_id)

## 获取活跃层数量
func get_layer_count() -> int:
	return active_layers.size()

## 是否有指定层
func has_layer(layer_id: String) -> bool:
	return layer_id in active_layers

# =============================================================================
# 循环控制器
# =============================================================================

var loop_controller: MusicLoopController = null

## 创建循环控制器
func create_loop_controller(music_manager: MusicManager) -> MusicLoopController:
	if not loop_controller:
		loop_controller = MusicLoopController.new(self, music_manager)
	return loop_controller

## 移除循环控制器
func remove_loop_controller():
	if loop_controller:
		loop_controller.cleanup()
		loop_controller = null

# =============================================================================
# 中断处理方法
# =============================================================================

## 当前是否被挂起
func is_suspended() -> bool:
	return suspension_state != SuspensionState.NONE

## 挂起状态
func suspend(mode: MusicTrackResource.InterruptionMode, player: AudioStreamPlayer) -> void:
	match mode:
		MusicTrackResource.InterruptionMode.STOP_AND_RESTART:
			suspension_state = SuspensionState.STOPPED
			# 保存状态但不保存播放器（会被清理）
		MusicTrackResource.InterruptionMode.PAUSE_AND_RESUME:
			suspension_state = SuspensionState.PAUSED
			saved_playback_position = player.get_playback_position()
			saved_stream_player = player  # 保留引用
		MusicTrackResource.InterruptionMode.KEEP_PLAYING_SILENTLY:
			suspension_state = SuspensionState.DUCKED
			original_volume_db = player.volume_db

## 恢复状态
func resume() -> MusicTrackResource.InterruptionMode:
	var mode := get_interruption_mode()
	suspension_state = SuspensionState.NONE
	return mode

## 获取中断模式（从 suspension_state 推断）
func get_interruption_mode() -> MusicTrackResource.InterruptionMode:
	match suspension_state:
		SuspensionState.STOPPED:
			return MusicTrackResource.InterruptionMode.STOP_AND_RESTART
		SuspensionState.PAUSED:
			return MusicTrackResource.InterruptionMode.PAUSE_AND_RESUME
		SuspensionState.DUCKED:
			return MusicTrackResource.InterruptionMode.KEEP_PLAYING_SILENTLY
		_:
			return MusicTrackResource.InterruptionMode.STOP_AND_RESTART


# =============================================================================
# 音乐循环控制器（内部类）
# =============================================================================

class MusicLoopController:
	var state: ActiveMusicState
	var music_manager: MusicManager
	var is_monitoring: bool = false
	var current_variant_index: int = 0
	var is_crossfading: bool = false

	func _init(music_state: ActiveMusicState, manager: MusicManager):
		state = music_state
		music_manager = manager

	## 更新循环（每帧调用）
	func update(delta: float) -> void:
		if not is_monitoring or is_crossfading:
			return

		# 只在 LOOP 阶段处理循环
		if not state.is_loop_phase():
			return

		var player = state.current_stream_player
		if not player or not player.playing:
			return

		var track = state.track_resource
		var stream_length = track.get_loop_duration()
		if stream_length <= 0:
			return

		var current_pos = player.get_playback_position()
		var trigger_point = stream_length * track.loop_trigger_point

		# 检查是否到达触发点
		if current_pos >= trigger_point:
			print("[LoopController] 触发循环！位置: %.2f / %.2f (触发点: %.2f), 模式: %s" % [
				current_pos, stream_length, trigger_point, track.loop_mode])

			match track.loop_mode:
				MusicTrackResource.LoopMode.SEAMLESS:
					_handle_seamless_loop(player)
				MusicTrackResource.LoopMode.CROSSFADE:
					_handle_crossfade_loop(track, player)
				MusicTrackResource.LoopMode.CROSSFADE_VARIANT:
					_handle_variant_crossfade(track, player)

	## 处理无缝循环
	func _handle_seamless_loop(player: AudioStreamPlayer) -> void:
		# 对于 SEAMLESS 模式，使用 AudioStream 的内置 loop 属性
		var stream = player.stream
		if stream and "loop" in stream:
			if not stream.loop:
				stream.loop = true
				if "loop_offset" in stream:
					stream.loop_offset = 0.0

		# 停止监控，因为内置 loop 会处理
		is_monitoring = false

	## 处理交叉淡入淡出循环
	func _handle_crossfade_loop(track: MusicTrackResource, current_player: AudioStreamPlayer) -> void:
		_start_crossfade_to(track, track.loop_stream)

	## 处理变体交叉淡入淡出
	func _handle_variant_crossfade(track: MusicTrackResource, current_player: AudioStreamPlayer) -> void:
		if not track.has_loop_variants():
			# 没有变体，回退到普通 crossfade
			_handle_crossfade_loop(track, current_player)
			return

		# 根据模式选择下一个变体
		var next_variant: AudioStream
		match track.loop_variant_mode:
			MusicTrackResource.LoopVariantMode.RANDOM:
				next_variant = track.get_random_loop_variant()
			MusicTrackResource.LoopVariantMode.SEQUENTIAL:
				current_variant_index = (current_variant_index + 1) % track.loop_variants.size()
				next_variant = track.loop_variants[current_variant_index]
			_:
				next_variant = track.loop_stream

		_start_crossfade_to(track, next_variant)

	## 开始交叉淡入淡出
	func _start_crossfade_to(track: MusicTrackResource, next_stream: AudioStream) -> void:
		if is_crossfading:
			return

		is_crossfading = true
		var current_player = state.current_stream_player

		# 创建新播放器
		var new_player = music_manager.create_player()
		new_player.stream = next_stream
		new_player.bus = current_player.bus
		new_player.volume_db = -60.0
		new_player.play(0.0)

		# 调度交叉淡入淡出
		music_manager._transition_scheduler.schedule_crossfade(
			current_player,
			new_player,
			track.loop_crossfade_time
		)

		# 等待 crossfade 完成
		var transition_scheduler = music_manager._transition_scheduler
		if transition_scheduler.crossfade_completed.is_null():
			# 如果信号不存在，使用 timer 等待
			await music_manager.get_tree().create_timer(track.loop_crossfade_time).timeout
		else:
			# 连接信号并等待（注意：信号只有2个参数：out_player, in_player）
			var crossfade_done = false
			var callback = func(out_player: AudioStreamPlayer, in_player: AudioStreamPlayer):
				crossfade_done = true
			transition_scheduler.crossfade_completed.connect(callback, CONNECT_ONE_SHOT)
			await music_manager.get_tree().process_frame
			while not crossfade_done:
				await music_manager.get_tree().process_frame

		# 更新状态
		state.current_stream_player = new_player
		music_manager.return_player_to_pool(current_player)

		is_crossfading = false
		is_monitoring = true  # 重新开始监控

	## Crossfade 完成回调
	func _on_crossfade_complete(_old_player: AudioStreamPlayer, _out: AudioStreamPlayer, _in: AudioStreamPlayer):
		is_crossfading = false
		is_monitoring = true

	## 开始监控
	func start_monitoring():
		is_monitoring = true

	## 停止监控
	func stop_monitoring():
		is_monitoring = false

	## 清理
	func cleanup():
		stop_monitoring()
		state = null
		music_manager = null
