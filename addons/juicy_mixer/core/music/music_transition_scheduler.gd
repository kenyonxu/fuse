class_name MusicTransitionScheduler
extends RefCounted

## 音乐过渡调度器
##
## 管理所有音乐过渡动画（淡入淡出、交叉淡入淡出）

# =============================================================================
# 过渡请求定义
# =============================================================================

class TransitionRequest:
	var target_player: AudioStreamPlayer
	var from_volume: float
	var to_volume: float
	var duration: float
	var elapsed: float = 0.0
	var on_complete: Callable
	var tween: Tween  # 每个 transition 有自己的 tween

	func _init(player: AudioStreamPlayer, from: float, to: float, dur: float, callback: Callable = Callable()):
		target_player = player
		from_volume = from
		to_volume = to
		duration = dur
		on_complete = callback
		tween = null

# =============================================================================
# 过渡状态
# =============================================================================

var _active_transitions: Array[TransitionRequest] = []

# =============================================================================
# 信号
# =============================================================================

signal transition_completed(player: AudioStreamPlayer)
signal crossfade_completed(out_player: AudioStreamPlayer, in_player: AudioStreamPlayer)

# =============================================================================
# 初始化
# =============================================================================

func _init():
	pass

# =============================================================================
# 调度 API
# =============================================================================

## 调度淡入淡出
func schedule_fade(player: AudioStreamPlayer, from_vol: float, to_vol: float, duration: float, on_complete: Callable = Callable()) -> void:
	"""
	调度单个播放器的淡入淡出

	@param player: 目标播放器
	@param from_vol: 起始音量 (dB)
	@param to_vol: 目标音量 (dB)
	@param duration: 过渡时间 (秒)
	@param on_complete: 完成回调
	"""
	print("[MusicTransitionScheduler] schedule_fade 被调用")
	print("[MusicTransitionScheduler]   - player: ", player)
	print("[MusicTransitionScheduler]   - from_vol: ", from_vol)
	print("[MusicTransitionScheduler]   - to_vol: ", to_vol)
	print("[MusicTransitionScheduler]   - duration: ", duration)
	print("[MusicTransitionScheduler]   - player.volume_db (当前): ", player.volume_db if is_instance_valid(player) else "无效")

	var request: TransitionRequest = TransitionRequest.new(player, from_vol, to_vol, duration, on_complete)
	_active_transitions.append(request)

	# 立即处理每个 transition（每个都有独立的 Tween，可以并行）
	print("[MusicTransitionScheduler] 开始处理过渡请求")
	_process_transition_immediate(request)

## 调度交叉淡入淡出
func schedule_crossfade(out_player: AudioStreamPlayer, in_player: AudioStreamPlayer, duration: float) -> void:
	"""
	调度两个播放器的交叉淡入淡出

	@param out_player: 淡出的播放器
	@param in_player: 淡入的播放器
	@param duration: 过渡时间 (秒)
	"""
	print("[MusicTransitionScheduler] schedule_crossfade 被调用")
	print("[MusicTransitionScheduler]   - out_player: ", out_player)
	print("[MusicTransitionScheduler]   - in_player: ", in_player)
	print("[MusicTransitionScheduler]   - duration: ", duration)

	# 淡出旧播放器
	var out_volume: float = out_player.volume_db if is_instance_valid(out_player) else 0.0
	print("[MusicTransitionScheduler] 淡出旧播放器: ", out_volume, " -> -60.0")
	schedule_fade(out_player, out_volume, -60.0, duration)

	# 淡入新播放器
	var in_start_vol: float = -60.0
	var in_target_vol: float = 0.0  # 可以从资源配置
	print("[MusicTransitionScheduler] 淡入新播放器: ", in_start_vol, " -> ", in_target_vol)
	schedule_fade(in_player, in_start_vol, in_target_vol, duration, _on_crossfade_fade_in_complete.bind(out_player, in_player))

# =============================================================================
# 处理逻辑
# =============================================================================

func _process_transition_immediate(request: TransitionRequest) -> void:
	"""立即处理过渡请求（使用 Tween）"""
	print("[MusicTransitionScheduler] _process_transition_immediate 被调用")
	print("[MusicTransitionScheduler]   - target_player: ", request.target_player)
	print("[MusicTransitionScheduler]   - from_volume: ", request.from_volume)
	print("[MusicTransitionScheduler]   - to_volume: ", request.to_volume)
	print("[MusicTransitionScheduler]   - duration: ", request.duration)

	if not is_instance_valid(request.target_player):
		push_error("[MusicTransitionScheduler] 播放器无效，无法创建 Tween")
		_on_transition_complete(request)
		return

	# 如果 duration <= 0，直接设置音量（不使用 Tween）
	if request.duration <= 0.0:
		print("[MusicTransitionScheduler] duration 为 0，直接设置音量: ", request.to_volume)
		request.target_player.volume_db = request.to_volume
		_on_transition_complete(request)
		return

	# 为这个 transition 创建独立的 Tween
	request.tween = request.target_player.create_tween()

	if not request.tween:
		push_error("[MusicTransitionScheduler] 创建 Tween 失败！")
		_on_transition_complete(request)
		return

	print("[MusicTransitionScheduler] Tween 创建成功: ", request.tween, " (独立)")
	request.tween.set_parallel(false)
	request.tween.tween_property(
		request.target_player,
		"volume_db",
		request.to_volume,
		request.duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	print("[MusicTransitionScheduler] Tween 属性动画已设置")

	# 连接完成信号
	request.tween.tween_callback(_on_transition_complete.bind(request))
	print("[MusicTransitionScheduler] 过渡已调度 (独立 Tween)")

func _on_transition_complete(request: TransitionRequest) -> void:
	"""过渡完成回调"""
	_active_transitions.erase(request)
	transition_completed.emit(request.target_player)

	if request.on_complete.is_valid():
		request.on_complete.call()

func _on_crossfade_fade_in_complete(out_player: AudioStreamPlayer, in_player: AudioStreamPlayer) -> void:
	"""交叉淡入淡出完成回调"""
	crossfade_completed.emit(out_player, in_player)

# =============================================================================
# 取消
# =============================================================================

## 取消所有活跃过渡
func cancel_all_transitions() -> void:
	"""取消所有活跃的过渡"""
	for transition in _active_transitions:
		if transition.tween and transition.tween.is_valid():
			transition.tween.kill()

	_active_transitions.clear()

## 取消指定播放器的过渡
func cancel_transition(player: AudioStreamPlayer) -> void:
	"""取消指定播放器的过渡"""
	for i in range(_active_transitions.size() - 1, -1, -1):
		var request: TransitionRequest = _active_transitions[i]
		if request.target_player == player:
			_active_transitions.remove_at(i)

# =============================================================================
# 状态查询
# =============================================================================

## 获取活跃过渡数量
func get_active_transition_count() -> int:
	return _active_transitions.size()

## 是否有活跃过渡
func has_active_transitions() -> bool:
	return not _active_transitions.is_empty()
