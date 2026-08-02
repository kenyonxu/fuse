@tool
@icon("res://addons/fuse/icons/builtin/AudioStreamPlayer.png")
extends BaseInstruction
class_name PlayMusic

## 播放音乐

# 音乐资源路径
var music_path: String = "":
	set(path):
		if music_path != path:
			music_path = path
			_cached_audio_length = -1.0  # 清除缓存
			_update_resource_name()

# 音量（0.0 - 1.0）
var volume: float = 1.0

# 缓存的音频长度（秒）
var _cached_audio_length: float = -1.0

# 混音器总线
var bus: String = "Master"

# 是否淡入
var fade_in: bool = false

# 淡入时间（秒）
var fade_duration: float = 2.0

# 是否在游戏暂停时继续播放
var continue_during_pause: bool = false

func _init():
	# 🔧 关键修复：明确声明此指令是异步的
	# PlayMusic 指令使用回调机制（信号连接）而非 await，所以源码检测无法正确识别
	_is_synchronous_hint = false
	_sync_hint_manually_set = true

## 获取指令元数据（用于指令选择器）
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_PLAY_MUSIC_NAME"
	metadata.category_key = "FUSE_CATEGORY_AUDIO"
	metadata.description_key = "FUSE_INSTRUCTION_PLAY_MUSIC_DESC"
	metadata.keywords = ["play", "music", "bgm", "background", "播放", "音乐", "背景"]
	metadata.builtin_icon = "AudioStreamPlayer"
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	# Music 分类
	properties.append({
		name = "Music",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 音乐路径
	properties.append({
		name = "music_path",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_FILE,
		hint_string = "*.mp3,*.ogg,*.wav",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Settings 分类
	properties.append({
		name = "Settings",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 音量
	properties.append({
		name = "volume",
		type = TYPE_FLOAT,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "0,1,0.01",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 混音器总线
	var bus_names = []
	for i in range(AudioServer.get_bus_count()):
		bus_names.append(AudioServer.get_bus_name(i))
	properties.append({
		name = "bus",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_ENUM,
		hint_string = ",".join(bus_names),
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 暂停时继续播放
	properties.append({
		name = "continue_during_pause",
		type = TYPE_BOOL,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Fade 分类
	properties.append({
		name = "Fade In",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 是否淡入
	properties.append({
		name = "fade_in",
		type = TYPE_BOOL,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 淡入时间
	properties.append({
		name = "fade_duration",
		type = TYPE_FLOAT,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "0,10,0.1,or_greater",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 更新资源名称
func _update_resource_name():
	var parts = []

	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_PLAY_MUSIC_RESOURCE_BASE"))

	if not music_path.is_empty():
		parts.append("'%s'" % FuseNodeUtils.get_path_display_name(music_path))

		# 尝试获取音频长度（带缓存）
		if _cached_audio_length < 0:
			var audio_resource = load(music_path)
			if audio_resource and audio_resource is AudioStream:
				_cached_audio_length = audio_resource.get_length()
			else:
				_cached_audio_length = 0.0

		# 如果成功获取到长度，添加到资源名称
		if _cached_audio_length > 0:
			var length_str = str(snapped(_cached_audio_length, 0.01)) + "s"
			parts.append("[%s]" % length_str)
	else:
		parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_PLAY_MUSIC_RESOURCE_NO_MUSIC"))

	if volume < 1.0:
		parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_PLAY_MUSIC_RESOURCE_VOLUME", {"volume": snapped(volume * 100, 0.1)}))

	if fade_in:
		parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_PLAY_MUSIC_RESOURCE_FADE", {"duration": fade_duration}))

	if continue_during_pause:
		parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_PLAY_MUSIC_RESOURCE_CONTINUE_DURING_PAUSE"))

	resource_name = " ".join(parts)

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	# 验证音乐路径
	if music_path.is_empty():
		_log_error_localized("FUSE_ERROR_MUSIC_PATH_EMPTY", {})
		set_error_localized("FUSE_ERROR_MUSIC_PATH_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 加载音乐资源
	var loaded_resource = load(music_path)
	if not loaded_resource:
		_log_error_localized("FUSE_ERROR_FAILED_LOAD_MUSIC", {
			"music_path": music_path
		})
		set_error_localized("FUSE_ERROR_FAILED_LOAD_MUSIC", FuseError.ErrorType.RUNTIME_ERROR, {
			"music_path": music_path
		})
		finished.emit()
		return

	if not loaded_resource is AudioStream:
		_log_error_localized("FUSE_ERROR_NOT_AUDIO_STREAM", {
			"music_path": music_path
		})
		set_error_localized("FUSE_ERROR_NOT_AUDIO_STREAM", FuseError.ErrorType.RUNTIME_ERROR, {
			"music_path": music_path
		})
		finished.emit()
		return

	# 创建资源副本，避免修改原始共享资源
	_log_debug("创建音频资源副本...")
	var music_resource: AudioStream = loaded_resource.duplicate(true)
	_log_debug("duplicate 结果: %s" % (music_resource != null))

	# 配置音频流（禁用循环，仅播放一次）
	if music_resource is AudioStreamOggVorbis:
		music_resource.loop = false
	elif music_resource is AudioStreamMP3:
		music_resource.loop = false
	elif music_resource is AudioStreamWAV:
		music_resource.loop_mode = 0  # 禁用循环

	# 创建 AudioStreamPlayer
	_log_debug("创建 AudioStreamPlayer...")
	var audio_player = AudioStreamPlayer.new()
	audio_player.name = "Fuse_MusicPlayer"
	audio_player.autoplay = false  # 手动控制播放
	_log_debug("AudioStreamPlayer 创建成功, autoplay=%s" % audio_player.autoplay)

	# 配置音频播放器
	audio_player.stream = music_resource
	audio_player.bus = bus
	if continue_during_pause:
		audio_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_log_debug("配置 AudioStreamPlayer: bus=%s, stream=%s" % [bus, music_resource.get_class()])

	# 连接 finished 信号，播放完成后清理
	audio_player.finished.connect(_on_audio_finished.bind(audio_player))
	# 防护：播放器被意外销毁时确保指令完成
	audio_player.tree_exited.connect(_on_player_tree_exited)
	_log_debug("已连接 finished 信号")

	# 详细检查 AudioStream 状态
	if music_resource is AudioStreamWAV:
		_log_debug("WAV 详细信息: loop_mode=%d, length=%s 秒" % [music_resource.loop_mode, music_resource.get_length()])

	# 检查总线音量
	var bus_index = AudioServer.get_bus_index(bus)
	_log_debug("总线 '%s' 索引: %d, 音量: %s dB" % [bus, bus_index, AudioServer.get_bus_volume_db(bus_index)])
	_log_debug("总线 '%s' 是否静音: %s" % [bus, AudioServer.is_bus_mute(bus_index)])
	_log_debug("总线 '%s' 发送数量: %s" % [bus, AudioServer.get_bus_effect_count(bus_index)])

	# 检查 Master 总线
	var master_index = AudioServer.get_bus_index("Master")
	_log_debug("Master 总线音量: %s dB, 静音: %s" % [AudioServer.get_bus_volume_db(master_index), AudioServer.is_bus_mute(master_index)])

	# 添加到场景树
	var scene_tree = Engine.get_main_loop()
	_log_debug("获取场景树: %s" % (scene_tree != null))
	if scene_tree and scene_tree.current_scene:
		_log_debug("当前场景: %s" % scene_tree.current_scene.name)
		FuseAudioContainer.add_music_player(audio_player)
		_log_debug("AudioStreamPlayer 已添加到 FuseAudioContainer")

		# 设置音量
		if fade_in:
			# 从 -60 dB 开始淡入
			audio_player.volume_db = -60.0
			_log_debug("设置初始音量: -60 dB (淡入模式)")
		else:
			audio_player.volume_db = linear_to_db(volume)
			_log_debug("设置音量: %s dB (线性: %s)" % [audio_player.volume_db, volume])

		# 手动开始播放
		_log_debug("准备开始播放...")
		audio_player.play.call_deferred()
		_log_debug("已调度 play() 调用")

		# 淡入效果（在添加到场景树后）
		if fade_in:
			var target_db = linear_to_db(volume)
			_log_debug("淡入目标音量: %s dB (线性: %s)" % [target_db, volume])
			# 使用 call_deferred 确保在节点进入场景树后再创建 Tween
			_fade_in.call_deferred(audio_player, target_db)

		# 延迟检查
		_check_audio_status.call_deferred(audio_player)

		# 使用 Timer 延迟检查播放状态
		var check_timer = Timer.new()
		check_timer.wait_time = 0.1
		check_timer.one_shot = true
		check_timer.timeout.connect(_on_check_timeout.bind(audio_player))
		scene_tree.current_scene.add_child(check_timer)
		check_timer.start()

		_log_info_localized("FUSE_INSTRUCTION_PLAY_MUSIC_LOG_PLAYING", {"file": FuseNodeUtils.get_path_display_name(music_path)})
	else:
		_log_error_localized("FUSE_ERROR_CANNOT_GET_CURRENT_SCENE", {})
		finished.emit()
		return

## 音频播放完成回调
func _on_audio_finished(player: AudioStreamPlayer):
	# 播放完成，清理节点并标记指令完成
	_log_debug("音频播放完成，指令结束")
	player.finished.disconnect(_on_audio_finished)
	if player.tree_exited.is_connected(_on_player_tree_exited):
		player.tree_exited.disconnect(_on_player_tree_exited)
	player.queue_free()  # 清理音频播放器节点
	_on_execution_completed()

## 播放器被意外销毁时的防护回调
func _on_player_tree_exited():
	_log_debug("音频播放器被意外销毁，指令结束")
	_on_execution_completed()

## 延迟检查音频状态
func _check_audio_status(player: AudioStreamPlayer):
	_log_debug("延迟检查: playing=%s, 播放位置=%s 秒, stream有效=%s" % [player.playing, player.get_playback_position(), player.stream != null])
	if not player.playing:
		_log_debug("⚠️ 音频未播放！尝试自动播放模式...")
		# 尝试使用 autoplay
		player.autoplay = true
		# 重新设置 stream 触发 autoplay
		var old_stream = player.stream
		player.stream = null
		player.stream = old_stream

## 延迟检查播放状态
func _on_check_timeout(player: AudioStreamPlayer):
	_log_debug("延迟检查 (0.1秒后): playing=%s, 播放位置=%s 秒" % [player.playing, player.get_playback_position()])
	_log_debug("AudioStreamPlayer 是否在场景树中: %s" % (player.is_inside_tree()))
	_log_debug("AudioStreamPlayer 是否被暂停: %s" % (not player.playing and player.get_playback_position() > 0))
	if player.stream and player.stream is AudioStreamWAV:
		_log_debug("WAV loop_mode: %d" % player.stream.loop_mode)

## 淡入音量
func _fade_in(player: AudioStreamPlayer, target_db: float) -> void:
	var scene_tree = Engine.get_main_loop()
	if not scene_tree:
		_log_error_localized("FUSE_ERROR_CANNOT_CREATE_TWEEN", {})
		player.volume_db = target_db
		return

	_log_debug("创建淡入 Tween: 从 %s dB 到 %s dB, 耗时 %s 秒" % [player.volume_db, target_db, fade_duration])
	var tween = scene_tree.create_tween()

	# 暂停时继续播放：Tween 也不应被暂停
	if continue_during_pause:
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	_log_debug("Tween 创建: %s" % (tween != null))
	tween.tween_property(player, "volume_db", target_db, fade_duration)
	_log_debug("淡入 Tween 已设置")

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()

	if music_path.is_empty():
		errors.append(FuseLocalization.translate("FUSE_INSTRUCTION_PLAY_MUSIC_VALIDATE_PATH_EMPTY"))

	if volume < 0.0 or volume > 1.0:
		errors.append(FuseLocalization.translate("FUSE_INSTRUCTION_PLAY_MUSIC_VALIDATE_VOLUME_RANGE"))

	# 验证混音器总线是否存在
	var bus_names = []
	for i in range(AudioServer.get_bus_count()):
		bus_names.append(AudioServer.get_bus_name(i))
	if not bus in bus_names:
		errors.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_PLAY_MUSIC_VALIDATE_BUS_NOT_EXIST", {"bus": bus}))

	# 验证淡入时间
	if fade_in and fade_duration <= 0:
		errors.append(FuseLocalization.translate("FUSE_INSTRUCTION_PLAY_MUSIC_VALIDATE_FADE_DURATION"))

	return errors

## 动态属性设置（支持属性刷新）
func _set(property: StringName, value: Variant) -> bool:
	if property == "fade_in":
		set(property, value)
		notify_property_list_changed()
		return true
	return false

## 属性验证
func _validate_property(property: Dictionary) -> void:
	if property.name == "fade_duration" and not fade_in:
		property.usage = PROPERTY_USAGE_NO_EDITOR

## 获取指令描述
func get_description() -> String:
	var options = []

	if volume < 1.0:
		options.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_PLAY_MUSIC_DESC_VOLUME", {"volume": snapped(volume * 100, 0.1)}))

	if bus != "Master":
		options.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_PLAY_MUSIC_DESC_BUS", {"bus": bus}))

	if fade_in:
		options.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_PLAY_MUSIC_DESC_FADE", {"duration": fade_duration}))

	if continue_during_pause:
		options.append(FuseLocalization.translate("FUSE_INSTRUCTION_PLAY_MUSIC_DESC_CONTINUE_DURING_PAUSE"))

	var options_str = ""
	if options.size() > 0:
		options_str = " (" + ", ".join(options) + ")"

	var file_str = FuseNodeUtils.get_path_display_name(music_path) if not music_path.is_empty() else FuseLocalization.translate("FUSE_INSTRUCTION_PLAY_MUSIC_RESOURCE_NO_MUSIC")
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_PLAY_MUSIC_DESC_FILE", {"file": file_str, "options": options_str})

## ============================================================
## 运行时实例模式支持（RuntimeInstructionInstance 架构）
## ============================================================

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var state = super.get_default_runtime_state()
	state["audio_player"] = null
	state["tween"] = null
	state["tween_callback"] = null
	state["finished_callback"] = null
	state["is_running"] = false
	return state

## 使用运行时实例执行
func execute_with_runtime_instance(runtime_instance: RuntimeInstructionInstance) -> bool:
	_start_execution(runtime_instance.execution_context)

	var state = runtime_instance.runtime_state

	# 验证音乐路径
	if music_path.is_empty():
		_log_error_localized("FUSE_ERROR_MUSIC_PATH_EMPTY", {})
		set_error_localized("FUSE_ERROR_MUSIC_PATH_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		runtime_instance._complete_execution()
		return true

	# 加载音乐资源
	var loaded_resource = load(music_path)
	if not loaded_resource:
		_log_error_localized("FUSE_ERROR_FAILED_LOAD_MUSIC", {"music_path": music_path})
		set_error_localized("FUSE_ERROR_FAILED_LOAD_MUSIC", FuseError.ErrorType.RUNTIME_ERROR, {"music_path": music_path})
		runtime_instance._complete_execution()
		return true

	if not loaded_resource is AudioStream:
		_log_error_localized("FUSE_ERROR_NOT_AUDIO_STREAM", {"music_path": music_path})
		set_error_localized("FUSE_ERROR_NOT_AUDIO_STREAM", FuseError.ErrorType.RUNTIME_ERROR, {"music_path": music_path})
		runtime_instance._complete_execution()
		return true

	# 创建资源副本
	var music_resource: AudioStream = loaded_resource.duplicate(true)

	# 配置音频流
	if music_resource is AudioStreamOggVorbis:
		music_resource.loop = false
	elif music_resource is AudioStreamMP3:
		music_resource.loop = false
	elif music_resource is AudioStreamWAV:
		music_resource.loop_mode = 0

	# 创建 AudioStreamPlayer
	var audio_player = AudioStreamPlayer.new()
	audio_player.name = "Fuse_MusicPlayer_Runtime"
	audio_player.autoplay = false
	audio_player.stream = music_resource
	audio_player.bus = bus
	if continue_during_pause:
		audio_player.process_mode = Node.PROCESS_MODE_ALWAYS

	state["audio_player"] = audio_player

	# 获取场景树
	var scene_tree = Engine.get_main_loop()
	if not scene_tree or not scene_tree.current_scene:
		_log_error_localized("FUSE_ERROR_CANNOT_GET_CURRENT_SCENE", {})
		runtime_instance._complete_execution()
		return true

	# 添加到持久化容器
	FuseAudioContainer.add_music_player(audio_player)

	# 设置音量
	if fade_in:
		audio_player.volume_db = -60.0
	else:
		audio_player.volume_db = linear_to_db(volume)

	# 连接 finished 信号
	var finished_callback = _create_audio_finished_callback(runtime_instance)
	audio_player.finished.connect(finished_callback, CONNECT_ONE_SHOT)
	runtime_instance.register_timer_callback(finished_callback)
	state["finished_callback"] = finished_callback

	# 开始播放
	audio_player.play()
	state["is_running"] = true

	_log_info_localized("FUSE_INSTRUCTION_PLAY_MUSIC_LOG_PLAYING", {"file": FuseNodeUtils.get_path_display_name(music_path)})

	# 淡入效果
	if fade_in:
		var target_db = linear_to_db(volume)
		var tween = scene_tree.create_tween()
		if tween:
			tween.tween_property(audio_player, "volume_db", target_db, fade_duration)
			state["tween"] = tween

			var tween_callback = _create_tween_callback(runtime_instance)
			tween.finished.connect(tween_callback, CONNECT_ONE_SHOT)
			runtime_instance.register_timer_callback(tween_callback)
			state["tween_callback"] = tween_callback

	return false

## 创建音频播放完成回调
func _create_audio_finished_callback(runtime_instance: RuntimeInstructionInstance) -> Callable:
	var callback = func():
		_on_audio_finished_runtime(runtime_instance)
	return callback

## 音频播放完成回调（运行时实例版本）
func _on_audio_finished_runtime(runtime_instance: RuntimeInstructionInstance) -> void:
	if not runtime_instance or runtime_instance.is_completed():
		return

	var state = runtime_instance.runtime_state
	var audio_player = state.get("audio_player")

	if audio_player and is_instance_valid(audio_player):
		FuseAudioContainer.remove_music_player(audio_player)
		audio_player.queue_free()

	state["audio_player"] = null
	state["tween"] = null
	state["is_running"] = false
	state["finished_callback"] = null
	state["tween_callback"] = null

	runtime_instance._complete_execution()

## 创建 Tween 完成回调
func _create_tween_callback(runtime_instance: RuntimeInstructionInstance) -> Callable:
	var callback = func():
		# Tween 完成（淡入结束）
		pass
	return callback

## 暂停处理
func on_runtime_pause(runtime_instance: RuntimeInstructionInstance) -> void:
	if continue_during_pause:
		return

	var state = runtime_instance.runtime_state
	var audio_player = state.get("audio_player")
	var tween = state.get("tween")

	if audio_player and is_instance_valid(audio_player):
		audio_player.stream_paused = true

	if tween and is_instance_valid(tween):
		tween.pause()

	state["is_running"] = false

## 恢复处理
func on_runtime_resume(runtime_instance: RuntimeInstructionInstance) -> void:
	if continue_during_pause:
		return

	var state = runtime_instance.runtime_state
	var audio_player = state.get("audio_player")
	var tween = state.get("tween")

	if audio_player and is_instance_valid(audio_player):
		audio_player.stream_paused = false

	if tween and is_instance_valid(tween):
		tween.play()

	state["is_running"] = true
