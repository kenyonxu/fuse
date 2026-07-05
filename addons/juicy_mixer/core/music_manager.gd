class_name MusicManager
extends Node

## 音乐管理器
##
## 场景级单例，管理所有背景音乐

# =============================================================================
# 信号
# =============================================================================

signal music_started(track_resource: MusicTrackResource)
signal music_stopped(track_resource: MusicTrackResource)
signal music_transition_started(from_track: MusicTrackResource, to_track: MusicTrackResource)

# =============================================================================
# 单例
# =============================================================================

static var _instance: MusicManager = null

# =============================================================================
# 组件
# =============================================================================

var _transition_scheduler: MusicTransitionScheduler
var _bus_controller: MusicBusController
var _music_event_handler: MusicEventHandler

# =============================================================================
# 状态管理
# =============================================================================

var _active_tracks: Dictionary = {}  # {track_id: ActiveMusicState}
var _active_layers: Dictionary = {}  # {layer_id: LayerState}
var _current_music_state: ActiveMusicState = null

# =============================================================================
# 单例访问
# =============================================================================

static func get_instance() -> MusicManager:
	"""获取 MusicManager 单例"""
	return _instance

static func ensure_exists() -> MusicManager:
	"""确保 MusicManager 存在，不存在则创建"""
	if _instance:
		return _instance

	# 在当前场景中创建
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if not tree or not tree.current_scene:
		push_error("[MusicManager] 无法获取当前场景")
		return null

	var manager: MusicManager = MusicManager.new()
	tree.current_scene.add_child(manager)
	return manager

# =============================================================================
# 生命周期
# =============================================================================

func _ready() -> void:
	"""初始化"""
	if _instance:
		push_warning("[MusicManager] 已存在实例，将替换")
		_instance.queue_free()

	_instance = self
	set_name("MusicManager")
	print("[MusicManager] 初始化")

	# 启用处理以支持循环控制器
	process_mode = Node.PROCESS_MODE_ALWAYS

	# 设置总线
	_bus_controller = MusicBusController.new()
	_bus_controller.setup_buses()

	# 创建过渡调度器
	_transition_scheduler = MusicTransitionScheduler.new()

	# 创建音乐事件处理器
	_music_event_handler = MusicEventHandler.new()
	_music_event_handler.music_manager = self

	# 注册到事件系统
	call_deferred("_register_to_event_middleware")
	# _register_to_event_middleware()

func _exit_tree() -> void:
	"""清理"""
	if _instance == self:
		_instance = null

	# 清理循环控制器
	if _current_music_state:
		_current_music_state.remove_loop_controller()

	print("[MusicManager] 清理完成")

## 每帧更新（用于循环控制）
func _process(delta: float) -> void:
	"""更新当前音乐的循环控制器"""
	if _current_music_state and _current_music_state.loop_controller:
		_current_music_state.loop_controller.update(delta)

# =============================================================================
# 事件系统集成
# =============================================================================

func _register_to_event_middleware() -> void:
	"""注册到 EventHandlingMiddleware"""
	# 查找 JuicyMixer
	var juicy_mixer = JuicyMixer.instance

	if not juicy_mixer:
		push_warning("[MusicManager] JuicyMixer 不存在，跳过事件注册")
		return

	# 获取 MiddlewarePipeline
	var middleware_pipeline = juicy_mixer.get_middleware_pipeline()
	if not middleware_pipeline:
		push_warning("[MusicManager] MiddlewarePipeline 不存在")
		return

	# 获取 EventHandlingMiddleware
	var event_middleware = middleware_pipeline.get_middleware("EventHandlingMiddleware")
	if not event_middleware:
		push_warning("[MusicManager] EventHandlingMiddleware 不存在")
		return

	# 注册处理器
	if event_middleware.register_event_handler(_music_event_handler, 10):
		print("[MusicManager] 已注册到 EventHandlingMiddleware (优先级 10)")
	else:
		push_warning("[MusicManager] EventHandlingMiddleware 没有 register_handler 方法")

# =============================================================================
# 核心 API（占位符，后续实现）
# =============================================================================

## 播放音乐
func play_music(track: MusicTrackResource, fade_in_time: float = 0.0, persistence_key: String = "") -> String:
	"""
	播放音乐

	@param track: 音乐轨道资源
	@param fade_in_time: 淡入时间（秒）
	@param persistence_key: 持久化标识符
	@return: track_id
	"""
	print("[MusicManager] play_music 被调用")
	print("[MusicManager]   - track: ", track)
	print("[MusicManager]   - loop_stream: ", track.loop_stream)
	print("[MusicManager]   - fade_in_time: ", fade_in_time)

	# 验证资源
	var validation = track.validate()
	if not validation.valid:
		push_error("[MusicManager] 资源验证失败: %s" % validation.issues)
		return ""

	# 验证 loop_stream
	if not track.loop_stream:
		push_error("[MusicManager] loop_stream 为空，无法播放")
		return ""

	# 停止当前音乐（如果有）
	# 但不要停止已经被 MusicPlayer 挂起的状态（由 MusicPlayer 管理）
	if _current_music_state and _current_music_state.is_playing():
		# 检查是否被挂起，如果被挂起则不停止（MusicPlayer 会处理）
		if not _current_music_state.is_suspended():
			print("[MusicManager] 停止当前音乐")
			stop_music(0.0)

	# 创建播放器
	var player: AudioStreamPlayer = _create_player()
	if track.has_loop_variants():
		player.stream = track.get_random_loop_variant()
	else:
		player.stream = track.loop_stream
	player.bus = AudioServer.get_bus_name(_bus_controller.get_music_bus_index())
	player.autoplay = false

	# 设置音量
	if fade_in_time > 0:
		player.volume_db = -60.0
	else:
		player.volume_db = 0.0

	print("[MusicManager] 播放器配置完成:")
	print("[MusicManager]   - stream: ", player.stream)
	print("[MusicManager]   - bus: ", player.bus)
	print("[MusicManager]   - volume_db: ", player.volume_db)

	# 播放
	player.play(0.0)

	# 验证播放是否成功
	if not player.playing:
		push_error("[MusicManager] 播放器启动失败！")
		return ""

	print("[MusicManager] 播放器已启动，playing: ", player.playing)

	# 创建状态
	var track_id: String = str(track.get_instance_id())
	var state: ActiveMusicState = ActiveMusicState.create(track, player)
	state.persistence_key = persistence_key if not persistence_key.is_empty() else track.persistence_key
	_active_tracks[track_id] = state
	_current_music_state = state

	# 淡入
	if fade_in_time > 0:
		_transition_scheduler.schedule_fade(
			player, -60.0, 0.0, fade_in_time,
			_on_fade_in_complete.bind(state)
		)
		state.current_phase = ActiveMusicState.MusicPhase.FADING_IN
	else:
		state.current_phase = ActiveMusicState.MusicPhase.LOOP
		# 如果不是 INTRO_LOOP，立即启动循环控制器
		if track.music_type != MusicTrackResource.MusicType.INTRO_LOOP:
			_start_loop_controller(state)

	music_started.emit(track)
	print("[MusicManager] 播放音乐完成，track_id: ", track_id)

	# 处理 Intro-Loop
	if track.music_type == MusicTrackResource.MusicType.INTRO_LOOP and track.intro_stream:
		_play_intro_loop(track, state)

	return track_id

## 播放 Intro-Loop
func _play_intro_loop(track: MusicTrackResource, state: ActiveMusicState) -> void:
	"""播放 Intro 然后切换到 Loop"""
	if not track.intro_stream:
		return

	# 创建 Intro 播放器
	var intro_player: AudioStreamPlayer = _create_player()
	intro_player.stream = track.intro_stream
	intro_player.bus = AudioServer.get_bus_name(_bus_controller.get_music_bus_index())
	intro_player.volume_db = 0.0
	intro_player.play(0.0)

	state.current_phase = ActiveMusicState.MusicPhase.INTRO

	# 计算切换时间
	var intro_duration: float = track.get_intro_duration()
	var transition_start_time: float = intro_duration - track.intro_fade_out_time

	# 等待切换时机
	await get_tree().create_timer(transition_start_time).timeout

	# 开始淡出 Intro，淡入 Loop
	var loop_player: AudioStreamPlayer = state.current_stream_player
	loop_player.volume_db = -60.0
	loop_player.play(0.0)

	_transition_scheduler.schedule_crossfade(
		intro_player,
		loop_player,
		track.loop_fade_in_time
	)

	# 过渡完成后清理 Intro 播放器
	_transition_scheduler.crossfade_completed.connect(_on_intro_loop_crossfade_complete.bind(intro_player), CONNECT_ONE_SHOT)

	state.current_phase = ActiveMusicState.MusicPhase.LOOP
	print("[MusicManager] Intro-Loop 切换完成")

func _on_intro_loop_crossfade_complete(intro_player: AudioStreamPlayer, _out_player: AudioStreamPlayer, _in_player: AudioStreamPlayer) -> void:
	"""Intro-Loop 交叉淡入淡出完成回调

	参数说明：
	- intro_player: Intro 播放器（通过 bind 传递）
	- _out_player: 信号发出的淡出播放器（与 intro_player 相同，未使用）
	- _in_player: 信号发出的淡入播放器（未使用）
	"""
	_return_player_to_pool(intro_player)

	# Intro-Loop 过渡完成，启动循环控制器
	if _current_music_state:
		_start_loop_controller(_current_music_state)

## 启动循环控制器
func _start_loop_controller(state: ActiveMusicState) -> void:
	"""为指定状态启动循环控制器"""
	if not state.loop_controller:
		state.create_loop_controller(self)

	var track = state.track_resource
	var controller = state.loop_controller

	print("[MusicManager] 启动循环控制器")
	print("  - 阶段: %s" % state.current_phase)
	print("  - 循环模式: %s" % track.loop_mode)
	print("  - 触发点: %.2f" % track.loop_trigger_point)

	# 只在 LOOP 阶段且不是 SEAMLESS 模式时启动监控
	if state.current_phase == ActiveMusicState.MusicPhase.LOOP:
		if track.loop_mode != MusicTrackResource.LoopMode.SEAMLESS:
			controller.start_monitoring()
			print("  ✓ 已启动监控")
		else:
			# SEAMLESS 模式：设置 AudioStream 的 loop 属性
			var player = state.current_stream_player
			if player and player.stream:
				var stream = player.stream
				if "loop" in stream and stream is AudioStream:
					stream.loop = true
					if "loop_offset" in stream:
						stream.loop_offset = 0.0
					print("  ✓ 已设置 AudioStream.loop = true")

## 停止音乐
func stop_music(fade_out_time: float = 0.0):
	"""停止当前音乐"""
	if not _current_music_state:
		return

	var state: ActiveMusicState = _current_music_state
	var player: AudioStreamPlayer = state.current_stream_player

	if fade_out_time > 0:
		# 淡出
		_transition_scheduler.schedule_fade(
			player,
			player.volume_db,
			-60.0,
			fade_out_time,
			_on_stop_fade_complete.bind(state)
		)
		state.current_phase = ActiveMusicState.MusicPhase.FADING_OUT
	else:
		# 立即停止
		_stop_immediate(state)

## 停止指定的音乐状态
func stop_music_by_state(state: ActiveMusicState, fade_out_time: float = 0.0):
	"""停止指定的音乐状态（用于中断处理）"""
	if not state:
		return

	var player: AudioStreamPlayer = state.current_stream_player
	if not player:
		return

	if fade_out_time > 0:
		# 淡出
		_transition_scheduler.schedule_fade(
			player,
			player.volume_db,
			-60.0,
			fade_out_time,
			_on_stop_fade_complete.bind(state)
		)
		state.current_phase = ActiveMusicState.MusicPhase.FADING_OUT
	else:
		# 立即停止
		_stop_immediate(state)

func _stop_immediate(state: ActiveMusicState) -> void:
	"""立即停止播放"""
	if not state:
		return

	# 检查状态是否被挂起（用于 MusicPlayer 的虚拟化系统）
	if state.is_suspended():
		# 停止播放但不删除 state，保留给 MusicPlayer 恢复使用
		if state.current_stream_player and state.current_stream_player.playing:
			state.current_stream_player.stop()
		# 不返回播放器到池，也不从 _active_tracks 删除
		# 不发送 music_stopped 信号，因为音乐只是暂停不是真正停止
		return

	# 清理循环控制器
	state.remove_loop_controller()

	var track_id: String = str(state.track_resource.get_instance_id())
	_active_tracks.erase(track_id)
	_return_player_to_pool(state.current_stream_player)

	if _current_music_state == state:
		_current_music_state = null

	music_stopped.emit(state.track_resource)

func _on_stop_fade_complete(state: ActiveMusicState) -> void:
	"""淡出完成回调"""
	_stop_immediate(state)

func _on_fade_in_complete(state: ActiveMusicState) -> void:
	"""淡入完成回调"""
	if state and state.track_resource.music_type != MusicTrackResource.MusicType.INTRO_LOOP:
		state.current_phase = ActiveMusicState.MusicPhase.LOOP
		_start_loop_controller(state)

# =============================================================================
# 中断处理 API
# =============================================================================

## 获取活跃音乐状态
func get_active_state(track_id: String) -> ActiveMusicState:
	"""根据 track_id 获取活跃的音乐状态"""
	if track_id in _active_tracks:
		return _active_tracks[track_id]
	return null

## 暂停音乐（PAUSE_AND_RESUME 模式）
func pause_music(state: ActiveMusicState, fade_time: float) -> void:
	"""暂停音乐但保存状态"""
	if not state or not state.current_stream_player:
		return

	var player := state.current_stream_player

	# 淡出到静音
	if fade_time > 0:
		_transition_scheduler.schedule_fade(
			player,
			player.volume_db,
			-60.0,
			fade_time,
			_on_pause_fade_complete.bind(state)
		)
	else:
		_on_pause_fade_complete(state)

func _on_pause_fade_complete(state: ActiveMusicState) -> void:
	"""暂停淡出完成回调"""
	if state.current_stream_player:
		state.current_stream_player.stream_paused = true

## 恢复音乐（PAUSE_AND_RESUME 模式）
func resume_music(state: ActiveMusicState, fade_time: float) -> void:
	"""从暂停位置恢复播放"""
	if not state:
		return

	var track := state.track_resource

	# 创建新播放器
	var player := create_player()
	player.stream = track.loop_stream
	player.bus = AudioServer.get_bus_name(_bus_controller.get_music_bus_index())
	player.volume_db = -60.0

	# 从保存的位置开始播放
	player.play(state.saved_playback_position)
	state.current_stream_player = player

	# 淡入到正常音量
	if fade_time > 0:
		_transition_scheduler.schedule_fade(player, -60.0, 0.0, fade_time)
	else:
		player.volume_db = 0.0

## 降低音量（KEEP_PLAYING_SILENTLY 模式）
func duck_music(state: ActiveMusicState, target_volume_db: float, fade_time: float) -> void:
	"""降低音乐音量但不停止"""
	if not state or not state.current_stream_player:
		return

	var player := state.current_stream_player

	# 淡出到目标音量
	if fade_time > 0:
		_transition_scheduler.schedule_fade(
			player,
			player.volume_db,
			target_volume_db,
			fade_time
		)
	else:
		player.volume_db = target_volume_db

## 恢复音量（KEEP_PLAYING_SILENTLY 模式）
func unduck_music(state: ActiveMusicState, target_volume_db: float, fade_time: float) -> void:
	"""恢复音乐音量"""
	if not state or not state.current_stream_player:
		return

	var player := state.current_stream_player

	# 淡入到目标音量
	if fade_time > 0:
		_transition_scheduler.schedule_fade(
			player,
			player.volume_db,
			target_volume_db,
			fade_time
		)
	else:
		player.volume_db = target_volume_db

## 交叉淡入淡出
func crossfade_to(new_track: MusicTrackResource, fade_time: float = 1.0) -> String:
	"""
	淡入新音乐，淡出旧音乐

	@param new_track: 新音乐轨道
	@param fade_time: 过渡时间
	@return: track_id
	"""
	print("[MusicManager] crossfade_to 被调用")
	print("[MusicManager]   - new_track: ", new_track)
	print("[MusicManager]   - new_track.loop_stream: ", new_track.loop_stream)
	print("[MusicManager]   - fade_time: ", fade_time)

	# 验证 new_track.loop_stream
	if not new_track.loop_stream:
		push_error("[MusicManager] new_track.loop_stream 为空，无法 crossfade")
		return ""

	# 如果没有当前音乐，直接播放新音乐
	if not _current_music_state:
		print("[MusicManager] 没有当前音乐，直接播放新音乐")
		play_music(new_track, fade_time)
		return str(new_track.get_instance_id())

	var old_state: ActiveMusicState = _current_music_state
	var old_player: AudioStreamPlayer = old_state.current_stream_player

	print("[MusicManager] 当前音乐状态:")
	print("[MusicManager]   - old_state 存在: ", old_state != null)
	print("[MusicManager]   - old_player 有效: ", is_instance_valid(old_player))
	if is_instance_valid(old_player):
		print("[MusicManager]   - old_player.volume_db: ", old_player.volume_db)
		print("[MusicManager]   - old_player.playing: ", old_player.playing)

	# 创建新播放器
	var new_player: AudioStreamPlayer = _create_player()
	new_player.stream = new_track.loop_stream
	new_player.bus = AudioServer.get_bus_name(_bus_controller.get_music_bus_index())
	new_player.volume_db = -60.0
	new_player.play(0.0)

	print("[MusicManager] 新播放器配置:")
	print("[MusicManager]   - stream: ", new_player.stream)
	print("[MusicManager]   - bus: ", new_player.bus)
	print("[MusicManager]   - volume_db: ", new_player.volume_db)
	print("[MusicManager]   - playing: ", new_player.playing)

	# 验证新播放器是否成功启动
	if not new_player.playing:
		push_error("[MusicManager] 新播放器启动失败！")
		_return_player_to_pool(new_player)
		return ""

	# 交叉淡入淡出
	print("[MusicManager] 开始调度 crossfade...")
	_transition_scheduler.schedule_crossfade(old_player, new_player, fade_time)

	# 创建新状态
	var track_id: String = str(new_track.get_instance_id())
	var new_state: ActiveMusicState = ActiveMusicState.create(new_track, new_player)
	_active_tracks[track_id] = new_state
	_current_music_state = new_state

	# 过渡完成后清理旧状态
	_transition_scheduler.crossfade_completed.connect(_on_crossfade_complete.bind(old_player), CONNECT_ONE_SHOT)

	music_transition_started.emit(old_state.track_resource, new_track)
	print("[MusicManager] Crossfade 调度完成，track_id: ", track_id)

	return track_id

func _on_crossfade_complete(old_player: AudioStreamPlayer, _out_player: AudioStreamPlayer, _in_player: AudioStreamPlayer) -> void:
	"""交叉淡入淡出完成回调

	参数说明：
	- old_player: 旧播放器（通过 bind 传递）
	- _out_player: 信号发出的淡出播放器（与 old_player 相同，未使用）
	- _in_player: 信号发出的淡入播放器（未使用）

	注意：不通过 bind 传递 old_state，而是通过 _active_tracks 查找，避免 RefCounted 类型转换问题
	"""
	# 查找并移除旧音乐状态
	for track_id in _active_tracks:
		var state: ActiveMusicState = _active_tracks[track_id]
		if state.current_stream_player == old_player:
			_active_tracks.erase(track_id)
			break

	_return_player_to_pool(old_player)
	print("[MusicManager] Crossfade 清理完成")

## 添加音乐层
func add_music_layer(layer: MusicLayerResource, fade_in_time: float = 0.0) -> String:
	"""
	添加叠加音乐层

	@param layer: 音乐层资源
	@param fade_in_time: 淡入时间（秒）
	@return: layer_id
	"""
	# 验证资源
	var validation = layer.validate()
	if not validation.valid:
		push_error("[MusicManager] Layer validation failed: %s" % validation.issues)
		return ""

	# 创建独立的播放器
	var layer_player: AudioStreamPlayer = _get_player_from_pool()
	layer_player.stream = layer.layer_stream
	layer_player.bus = AudioServer.get_bus_name(_bus_controller.get_layer_bus(layer.layer_bus_index))
	layer_player.volume_db = -60.0  # 从静音开始
	layer_player.play(0.0)

	# 淡入
	if fade_in_time > 0:
		_transition_scheduler.schedule_fade(
			layer_player,
			-60.0,
			layer.default_volume,
			fade_in_time
		)
	else:
		layer_player.volume_db = layer.default_volume

	# 记录活跃层
	var layer_id: String = str(layer.get_instance_id())
	var layer_state = ActiveMusicState.ActiveLayerState.new()
	layer_state.layer_resource = layer
	layer_state.layer_player = layer_player
	layer_state.layer_phase = ActiveMusicState.MusicPhase.FADING_IN if fade_in_time > 0 else ActiveMusicState.MusicPhase.LOOP
	layer_state.target_volume = layer.default_volume
	layer_state.current_volume = layer_player.volume_db

	_active_layers[layer_id] = layer_state

	if _current_music_state:
		_current_music_state.add_layer(layer_id, layer_state)

	print("[MusicManager] 添加音乐层: ", layer.layer_name, " (ID: ", layer_id, ")")
	return layer_id

## 移除音乐层
func remove_music_layer(layer_id: String, fade_out_time: float = 0.0):
	"""
	移除音乐层

	@param layer_id: 层ID
	@param fade_out_time: 淡出时间（秒）
	"""
	if not layer_id in _active_layers:
		push_warning("[MusicManager] Layer not found: ", layer_id)
		return

	var layer_state: ActiveMusicState.ActiveLayerState = _active_layers[layer_id]
	var player: AudioStreamPlayer = layer_state.layer_player

	# 淡出
	if fade_out_time > 0:
		_transition_scheduler.schedule_fade(
			player,
			player.volume_db,
			-60.0,
			fade_out_time,
			_on_layer_removed.bind(layer_id)
		)
	else:
		_remove_layer_immediate(layer_id)


# =============================================================================
# 辅助方法
# =============================================================================

## 创建播放器
## 创建新的 AudioStreamPlayer（公开供循环控制器使用）
func create_player() -> AudioStreamPlayer:
	"""创建新的 AudioStreamPlayer"""
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	add_child(player)
	return player

## 从池获取播放器
func _get_player_from_pool() -> AudioStreamPlayer:
	"""从对象池获取播放器（当前直接创建新实例）"""
	return create_player()

## 返回播放器到池（公开供循环控制器使用）
func return_player_to_pool(player: AudioStreamPlayer) -> void:
	"""清理播放器"""
	if not player:
		return

	player.stop()
	player.queue_free()

## 兼容旧代码（内部使用）
func _create_player() -> AudioStreamPlayer:
	return create_player()

func _return_player_to_pool(player: AudioStreamPlayer) -> void:
	return_player_to_pool(player)

## 立即移除音乐层
func _remove_layer_immediate(layer_id: String) -> void:
	"""立即移除音乐层"""
	if not layer_id in _active_layers:
		return

	var layer_state = _active_layers[layer_id]
	_return_player_to_pool(layer_state.layer_player)

	if _current_music_state:
		_current_music_state.remove_layer(layer_id)

	_active_layers.erase(layer_id)
	print("[MusicManager] 移除音乐层: ", layer_id)

## 音乐层淡出完成回调
func _on_layer_removed(layer_id: String) -> void:
	"""音乐层淡出完成回调"""
	_remove_layer_immediate(layer_id)

# =============================================================================
# LPF 快照功能
# =============================================================================

## 应用暂停快照（LPF 效果）
func apply_pause_snapshot() -> void:
	"""应用暂停快照，音乐变"闷"效果"""
	if not _current_music_state:
		push_warning("[MusicManager] 没有活跃音乐，无法应用暂停快照")
		return

	# 主音乐播放器路由到 LPF 总线
	if _current_music_state.current_stream_player:
		var player = _current_music_state.current_stream_player
		if is_instance_valid(player):
			player.bus = AudioServer.get_bus_name(_bus_controller.get_lpf_bus_index())
			print("[MusicManager] 主音乐路由到 LPF 总线")

	# 所有活跃层也路由到 LPF 总线
	for layer_id in range(_current_music_state.get_layer_count()):
		var layer_state: ActiveMusicState.ActiveLayerState = _current_music_state.get_layer_by_index(layer_id)
		if layer_state and layer_state.layer_player:
			if is_instance_valid(layer_state.layer_player):
				layer_state.layer_player.bus = AudioServer.get_bus_name(_bus_controller.get_lpf_bus_index())

	# 设置 LPF 参数（例如：1000Hz 截止频率）
	_bus_controller.set_lpf_cutoff(1000.0)
	_bus_controller.set_lpf_enabled(true)

	print("[MusicManager] 暂停快照已应用")

## 应用正常快照（恢复播放）
func apply_normal_snapshot() -> void:
	"""恢复正常播放"""
	if not _current_music_state:
		push_warning("[Manager] 没有活跃音乐，无法恢复快照")
		return

	# 主音乐播放器路由回正常总线
	if _current_music_state.current_stream_player:
		var player = _current_music_state.current_stream_player
		if is_instance_valid(player):
			player.bus = AudioServer.get_bus_name(_bus_controller.get_music_bus_index())
			print("[MusicManager] 主音乐路由到 Music 总线")

	# 所有活跃层也路由回正常 Music 总线
	for layer_id in range(_current_music_state.get_layer_count()):
		var layer_state: ActiveMusicState.ActiveLayerState = _current_music_state.get_layer_by_index(layer_id)
		if layer_state and layer_state.layer_player:
			if is_instance_valid(layer_state.layer_player):
				layer_state.layer_player.bus = AudioServer.get_bus_name(_bus_controller.get_music_bus_index())

	# 禁用 LPF 效果
	_bus_controller.set_lpf_enabled(false)

	print("[MusicManager] 正常快照已应用")

# =============================================================================
# 场景持久化功能
# =============================================================================

## 准备场景切换
func prepare_for_scene_change() -> Dictionary:
	"""
	准备场景切换，返回持久化状态

	@return: 包含所有必要信息的字典
	"""
	if not _current_music_state:
		return {}

	var state: Dictionary = {}
	var track_id: String = str(_current_music_state.track_resource.get_instance_id())

	# 基本信息
	state["track_id"] = track_id
	state["persistence_key"] = _current_music_state.persistence_key
	state["current_phase"] = _current_music_state.current_phase

	# 播放位置和音量
	state["playback_position"] = _current_music_state.current_stream_player.get_playback_position()
	state["volume"] = _current_music_state.current_stream_player.volume_db

	# 活跃层序列化
	var layers_data: Array = []
	for layer_id in _active_layers:
		var layer_state: ActiveMusicState.ActiveLayerState = _active_layers[layer_id]
		var layer_data: Dictionary = {}
		layer_data["layer_id"] = layer_id
		layer_data["layer_resource"] = layer_state.layer_resource
		layer_data["volume"] = layer_state.current_volume
		layer_data["layer_phase"] = layer_state.layer_phase
		layers_data.append(layer_data)

	state["active_layers"] = layers_data

	print("[MusicManager] 准备场景切换，状态已保存")
	return state

## 从状态恢复
func restore_from_state(state: Dictionary) -> void:
	"""
	从状态恢复音乐播放

	@param state: prepare_for_scene_change() 返回的状态字典
	"""
	if state.is_empty():
		return

	# 检查是否需要恢复（同一个资源）
	var track_id: String = state.get("track_id", "")
	if track_id.is_empty():
		push_error("[MusicManager] State missing track_id")
		return

	# 如果资源相同且标记为持久化，保持播放
	if _current_music_state and str(_current_music_state.track_resource.get_instance_id()) == track_id:
		print("[MusicManager] 资源未变，保持当前播放")
		return

	# 创建新的播放器（场景切换后，播放器已销毁）
	var player: AudioStreamPlayer = _get_player_from_pool()
	player.autoplay = false

	# 获取资源（从 track_id 查找，需要时重新加载）
	var track_resource = _current_music_state.track_resource  # 已经有引用，无需重新加载
	if not track_resource:
		push_error("[MusicManager] 无法找到 track_resource")
		_return_player_to_pool(player)
		return

	player.stream = track_resource.loop_stream
	player.volume_db = state.get("volume", 0.0)
	player.play(state.get("playback_position", 0.0))

	# 创建新状态
	var new_state: ActiveMusicState = ActiveMusicState.create(track_resource, player)
	new_state.persistence_key = state.get("persistence_key", "")
	new_state.current_phase = state.get("current_phase", ActiveMusicState.MusicPhase.LOOP)

	_current_music_state = new_state

	print("[MusicManager] 从状态恢复音乐播放，位置: ", player.get_playback_position())
	print("[MusicManager] 播放器已切换")
