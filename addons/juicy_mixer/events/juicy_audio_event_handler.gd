class_name JuicyAudioEventHandler
extends JuicyEventHandler

# 音频播放器池
var _player_pool_2d: Array[AudioStreamPlayer2D] = []
var _player_pool_3d: Array[AudioStreamPlayer3D] = []
var _active_players: Dictionary = {}  # player_id -> player_info
var _max_pool_size: int = 50

# 音频配置
var _master_volume: float = 1.0
var _audio_bus: String = "Master"
var _spatial_audio_enabled: bool = true

# 新增：音频系统管理器
var _variation_manager: AudioVariationManager = null
var _mixing_controller: AudioMixingController = null

# 全局配置
var _global_config: GlobalAudioLimitConfig = null
var _virtual_voice_manager: VirtualVoiceManager = null

func _init():
	handler_name = "AudioEventHandler"
	supported_events = [
		JuicyEvent.EventType.AUDIO_PLAY,
		JuicyEvent.EventType.AUDIO_STOP
	]
	description = "Handles audio playback and control events"

	# 初始化管理器
	_variation_manager = AudioVariationManager.new()
	_mixing_controller = AudioMixingController.new()
	_virtual_voice_manager = VirtualVoiceManager.new()

	# 初始化默认全局配置
	_global_config = GlobalAudioLimitConfig.new()

func handle_event(event: JuicyEvent) -> bool:
	"""处理音频事件"""
	var start_time = _start_handling_timer()

	var success = false

	match event.event_type:
		JuicyEvent.EventType.AUDIO_PLAY:
			success = _handle_audio_play(event)
		JuicyEvent.EventType.AUDIO_STOP:
			success = _handle_audio_stop(event)
		_:
			_log_warning("Unsupported event type: " + str(event.event_type))

	_end_handling_timer(start_time)

	if success:
		_record_success()
	else:
		_record_failure()

	return success

# 音频播放处理
func _handle_audio_play(event: JuicyEvent) -> bool:
	"""处理音频播放事件"""

	# 检查是否为新的音频系统
	var audio_resource = event.event_data.get("audio_event_resource")
	if audio_resource is AudioEventResource:
		return _handle_audio_resource_play(audio_resource, event)
	else:
		# 向后兼容：使用原有逻辑
		return _handle_audio_play_legacy(event)

func _handle_audio_resource_play(resource: AudioEventResource, event: JuicyEvent) -> bool:
	# 1. 变体选择
	var variant = _variation_manager.select_variant(resource)
	if not variant:
		_log_error("Failed to select audio variant for: " + resource.event_name)
		return false

	# 2. 应用随机化
	var randomization = _variation_manager.apply_randomization(
		variant, 1.0, _master_volume, resource
	)

	# 3. 实例级检查
	if not _mixing_controller.can_play(resource, resource.event_name):
		_log_debug("Instance level check failed")
		return false

	# 4. 类别级检查（已集成到 AudioMixingController）
	# （通过传递 resource 实现已集成）

	# 5. 全局级检查
	if _global_config and _virtual_voice_manager:
		# 资源验证
		if not resource:
			_log_error("Resource is null in global level check")
			return false

		# 获取 position，处理 Vector2/Vector3 类型
		var position_raw = event.event_data.get("position", Vector3.ZERO)
		var position = Vector3.ZERO

		# 类型转换：Vector2 -> Vector3
		if position_raw is Vector2:
			position = Vector3(position_raw.x, position_raw.y, 0.0)
		elif position_raw is Vector3:
			position = position_raw

		var importance = resource.get_effective_priority()

		var virtual_info = _virtual_voice_manager.check_virtual_voice(
			resource, position, importance, _global_config
		)

		if virtual_info and virtual_info.is_virtual:
			_log_debug("Sound '%s' converted to virtual voice (pos: %s, importance: %d)" % [
				resource.event_name, position, importance
			])
			return false  # 虚声部不实际播放

	# 6. 获取播放器
	var player = _get_audio_player_for_resource(resource, event)
	if not player:
		_log_error("Failed to get audio player")
		return false

	# 7. 配置播放器
	_configure_player_for_resource(player, resource, variant, randomization, event)

	# 8. 应用鸭霸
	if resource.mixing:
		_mixing_controller.apply_ducking(resource.event_name, resource.mixing)

	# 9. 播放音频
	if player is AudioStreamPlayer:
		player.play(variant.start_offset)
	elif player is AudioStreamPlayer2D:
		player.play(variant.start_offset)
	elif player is AudioStreamPlayer3D:
		player.play(variant.start_offset)

	# 10. 记录实例
	var priority = resource.mixing.priority if resource.mixing else 50
	_mixing_controller.record_instance(resource.event_name, player, priority)

	# 11. 连接完成信号
	_connect_player_finished(player, resource, event)

	return true

func _handle_audio_play_legacy(event: JuicyEvent) -> bool:
	"""向后兼容：处理旧的音频事件格式"""
	var audio_stream = event.event_data.get("audio_stream")
	var position = event.event_data.get("position", Vector2.ZERO)
	var volume = event.event_data.get("volume", 1.0)

	if not audio_stream:
		_log_error("Audio stream is null")
		return false

	# 检查并发限制
	if _active_players.size() >= _max_pool_size:
		_log_warning("Maximum concurrent sounds reached, stopping oldest")
		_stop_oldest_player()

	# 获取播放器
	var player = _get_audio_player_legacy()
	if not player:
		_log_error("Failed to get audio player")
		return false

	# 配置播放器
	player.stream = audio_stream
	player.position = position
	player.volume_db = _linear_to_db(volume * _master_volume)
	player.bus = _audio_bus

	# 播放音频
	player.play()

	# 记录活跃播放器
	var player_id = player.get_instance_id()
	_active_players[player_id] = {
		"player": player,
		"context_id": event.context_id,
		"event_id": event.event_id,
		"start_time": Time.get_ticks_msec() / 1000.0
	}

	return true

func _handle_audio_stop(event: JuicyEvent) -> bool:
	"""处理音频停止事件"""
	var context_id = event.context_id
	var event_id = event.event_id

	var players_to_stop: Array = []

	# 查找要停止的播放器
	for player_id in _active_players.keys():
		var player_info = _active_players[player_id]
		if player_info.context_id == context_id or player_info.event_id == event_id:
			players_to_stop.append(player_info.player)

	# 停止播放器
	for player in players_to_stop:
		_stop_audio_player(player)

	return players_to_stop.size() > 0

# 播放器管理 - 新音频系统
func _get_audio_player_for_resource(resource: AudioEventResource, event: JuicyEvent) -> Variant:
	var player_type = resource.player_type

	# 自动检测
	if player_type == AudioEventResource.AudioPlayerType.AUTO_DETECT:
		var target = event.event_data.get("target")
		if target is Node3D:
			return _get_audio_player_3d()
		else:
			return _get_audio_player_2d()
	elif player_type == AudioEventResource.AudioPlayerType.PLAYER_2D:
		return _get_audio_player_2d()
	else:  # PLAYER_3D
		return _get_audio_player_3d()

func _get_audio_player_2d() -> AudioStreamPlayer2D:
	if not _player_pool_2d.is_empty():
		return _player_pool_2d.pop_back()

	var total_size = _player_pool_2d.size() + _player_pool_3d.size() + _active_players.size()
	if total_size < _max_pool_size:
		var player = AudioUtils.create_player_2d()
		_setup_audio_player(player)
		return player

	return null

func _get_audio_player_3d() -> AudioStreamPlayer3D:
	if not _player_pool_3d.is_empty():
		return _player_pool_3d.pop_back()

	var total_size = _player_pool_2d.size() + _player_pool_3d.size() + _active_players.size()
	if total_size < _max_pool_size:
		var player = AudioUtils.create_player_3d()
		_setup_audio_player(player)
		return player

	return null

func _setup_audio_player(player: Variant) -> void:
	if player is AudioStreamPlayer2D:
		player.finished.connect(_on_player_finished.bind(player))
	elif player is AudioStreamPlayer3D:
		player.finished.connect(_on_player_finished.bind(player))

	var audio_root = _get_audio_root()
	audio_root.add_child(player)

func _configure_player_for_resource(player: Variant, resource: AudioEventResource,
									variant: AudioVariant, randomization: Dictionary,
									event: JuicyEvent) -> void:
	# 设置流
	player.stream = variant.audio_stream

	# 应用音高和音量
	AudioUtils.apply_pitch_and_volume(player, randomization.pitch, randomization.volume)

	# 设置总线
	var bus = resource.audio_bus if not resource.audio_bus.is_empty() else _audio_bus
	AudioUtils.set_player_bus(player, bus)

	# 设置位置
	if player is AudioStreamPlayer2D:
		var pos = event.event_data.get("position", Vector2.ZERO)
		player.position = pos
	elif player is AudioStreamPlayer3D:
		var pos = event.event_data.get("position", Vector3.ZERO)
		player.global_position = pos

		# 设置3D参数
		if resource.max_distance > 0:
			player.max_distance = resource.max_distance
		if resource.max_distance_db != 0:
			player.max_distance_db = resource.max_distance_db

func _connect_player_finished(player: Variant, resource: AudioEventResource, event: JuicyEvent) -> void:
	# 播放完成时清理
	if player.has_signal("finished"):
		if not player.finished.is_connected(_on_player_finished):
			player.finished.connect(_on_player_finished.bind(player, resource, event))

func _on_player_finished(player: Variant, resource: AudioEventResource = null, event: JuicyEvent = null) -> void:
	# 移除实例记录
	if resource and _mixing_controller:
		_mixing_controller.remove_instance(resource.event_name, player)

	# 恢复鸭霸
	if resource and resource.mixing and _mixing_controller:
		_mixing_controller.remove_ducking(resource.event_name, resource.mixing)

	# 返回播放器到池
	_return_audio_player(player)

func _return_audio_player(player: Variant) -> void:
	player.stream = null

	if player is AudioStreamPlayer2D:
		player.position = Vector2.ZERO
		if _player_pool_2d.size() < _max_pool_size:
			_player_pool_2d.append(player)
	elif player is AudioStreamPlayer3D:
		player.global_position = Vector3.ZERO
		if _player_pool_3d.size() < _max_pool_size:
			_player_pool_3d.append(player)

# 播放器管理 - 向后兼容
func _get_audio_player_legacy() -> AudioStreamPlayer2D:
	# 从池中获取
	if not _player_pool_2d.is_empty():
		return _player_pool_2d.pop_back()

	# 创建新的播放器
	if _player_pool_2d.size() + _active_players.size() < _max_pool_size:
		var player = AudioStreamPlayer2D.new()
		_setup_audio_player_legacy(player)
		return player

	return null

func _setup_audio_player_legacy(player: AudioStreamPlayer2D) -> void:
	player.finished.connect(_on_player_finished.bind(player))

	# 添加到场景树
	var audio_root = _get_audio_root()
	audio_root.add_child(player)

func _stop_audio_player(player) -> void:
	if not player or not is_instance_valid(player):
		return

	player.stop()
	if player is AudioStreamPlayer2D:
		_return_audio_player_legacy(player)
	else:
		# 新音频系统的播放器清理已在_on_player_finished中处理
		pass

func _return_audio_player_legacy(player: AudioStreamPlayer2D) -> void:
	var player_id = player.get_instance_id()

	# 从活跃列表中移除
	_active_players.erase(player_id)

	# 重置播放器状态
	player.stream = null
	player.position = Vector2.ZERO
	player.volume_db = 0.0

	# 返回到池
	if _player_pool_2d.size() < _max_pool_size:
		_player_pool_2d.append(player)
	else:
		player.queue_free()

func _stop_oldest_player() -> void:
	var oldest_time = INF
	var oldest_player_id = -1

	for player_id in _active_players.keys():
		var player_info = _active_players[player_id]
		if player_info.start_time < oldest_time:
			oldest_time = player_info.start_time
			oldest_player_id = player_id

	if oldest_player_id != -1:
		var player_info = _active_players[oldest_player_id]
		_stop_audio_player(player_info.player)

# 更新鸭霸状态（每帧调用）
func _process(delta: float) -> void:
	if _mixing_controller:
		_mixing_controller.update_ducking(delta)

	if _virtual_voice_manager:
		_virtual_voice_manager.update_virtual_voices(delta)


# 工具方法
func _get_audio_root() -> Node:
	"""获取音频根节点"""
	# 尝试获取现有的音频根节点
	var scene_root = Engine.get_main_loop().current_scene
	var audio_root = scene_root.get_node_or_null("JuicyAudioRoot")

	if not audio_root:
		audio_root = Node.new()
		audio_root.name = "JuicyAudioRoot"
		scene_root.add_child(audio_root)

	return audio_root

func _linear_to_db(linear: float) -> float:
	"""线性值转分贝"""
	if linear <= 0.0:
		return -80.0
	return 20.0 * log(linear) / log(10.0)

# 配置管理
func configure(config: Dictionary) -> void:
	super.configure(config)

	if config.has("max_pool_size"):
		_max_pool_size = config.max_pool_size

	if config.has("master_volume"):
		_master_volume = clamp(config.master_volume, 0.0, 1.0)

	if config.has("audio_bus"):
		_audio_bus = config.audio_bus

	if config.has("spatial_audio_enabled"):
		_spatial_audio_enabled = config.spatial_audio_enabled

func get_configuration() -> Dictionary:
	var config = super.get_configuration()
	config["max_pool_size"] = _max_pool_size
	config["master_volume"] = _master_volume
	config["audio_bus"] = _audio_bus
	config["spatial_audio_enabled"] = _spatial_audio_enabled
	return config

## 设置全局配置
func set_global_config(config: GlobalAudioLimitConfig) -> void:
	if config:
		var validation = config.validate()
		if not validation.valid:
			push_warning("GlobalAudioLimitConfig validation failed: %s" % validation.issues.join(", "))
	_global_config = config

## 获取全局配置
func get_global_config() -> GlobalAudioLimitConfig:
	return _global_config

## 注册音频类别
##
## 此方法为 AudioManager 提供类别注册接口。
## TODO: 在 AudioMixingController 中实现完整的类别管理系统
##
## 参数:
## category: 要注册的音频类别
func register_category(category: AudioCategory) -> void:
	if not category:
		push_warning("JuicyAudioEventHandler.register_category: category is null")
		return

	if not _mixing_controller:
		push_warning("JuicyAudioEventHandler.register_category: mixing_controller not initialized")
		return

	# TODO: 实现类别注册逻辑
	# 需要在 AudioMixingController 中添加:
	# - register_category() 方法
	# - 类别优先级管理
	# - 类别限额管理
	pass

# 统计和调试
func get_audio_stats() -> Dictionary:
	"""获取音频统计信息"""
	var mixing_stats = {}
	if _mixing_controller:
		mixing_stats = _mixing_controller.get_stats()

	return {
		"pool_size_2d": _player_pool_2d.size(),
		"pool_size_3d": _player_pool_3d.size(),
		"active_players": _active_players.size(),
		"max_pool_size": _max_pool_size,
		"master_volume": _master_volume,
		"mixing_stats": mixing_stats
	}

func cleanup() -> void:
	"""清理音频处理器"""
	# 停止所有活跃播放器
	for player_id in _active_players.keys():
		var player_info = _active_players[player_id]
		_stop_audio_player(player_info.player)

	# 清空播放器池
	for player in _player_pool_2d:
		if is_instance_valid(player):
			player.queue_free()
	_player_pool_2d.clear()

	for player in _player_pool_3d:
		if is_instance_valid(player):
			player.queue_free()
	_player_pool_3d.clear()

## 直接播放音频事件（用于 JuicyAudioPlayer 等便捷播放场景）
##
## @param resource: 要播放的音频事件资源
## @param target: 目标节点（用于获取位置等）
## @return: 是否成功开始播放
func play_audio_event_direct(resource: AudioEventResource, target: Node) -> bool:
	if not resource:
		_log_error("AudioEventResource is null")
		return false

	# 创建 JuicyEvent 用于内部播放
	var juicy_event = JuicyEvent.new()
	juicy_event.event_type = JuicyEvent.EventType.AUDIO_PLAY
	juicy_event.event_data = {
		"audio_event_resource": resource,
		"target": target,
		"position": _get_target_position(target)
	}

	return handle_event(juicy_event)

## 获取目标节点的位置（用于3D音频）
func _get_target_position(target: Node) -> Variant:
	if target is Node3D:
		return target.global_position
	elif target is Node2D:
		return target.global_position
	else:
		# 对于普通 Node，返回 Vector2.ZERO（2D 播放器默认值）
		return Vector2.ZERO

func _log_debug(message: String) -> void:
	if OS.is_debug_build():
		print("[", handler_name, "] ", message)
