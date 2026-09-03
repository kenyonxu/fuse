@tool
@icon("res://addons/fuse/icons/builtin/AudioStreamPlayer.png")
extends BaseInstruction
class_name CrossfadeToMusic

## 交叉淡入淡出播放音乐

func _init():
	# 🔧 关键修复：明确声明此指令是异步的
	# CrossfadeToMusic 指令使用回调机制（信号连接）而非 await，所以源码检测无法正确识别
	_is_synchronous_hint = false
	_sync_hint_manually_set = true

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

# 交叉淡入淡出时长（秒）
var crossfade_duration: float = 3.0

# 是否在游戏暂停时继续播放
var continue_during_pause: bool = false

## 获取指令元数据（用于指令选择器）
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_CROSSFADE_TO_MUSIC_NAME"
	metadata.category_key = "FUSE_CATEGORY_AUDIO"
	metadata.description_key = "FUSE_INSTRUCTION_CROSSFADE_TO_MUSIC_DESC"
	metadata.keywords = ["crossfade", "music", "bgm", "transition", "淡入淡出", "音乐", "切换"]
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

	# Crossfade 分类
	properties.append({
		name = "Crossfade",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 交叉淡入淡出时长
	properties.append({
		name = "crossfade_duration",
		type = TYPE_FLOAT,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "0.1,10,0.1,or_greater",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 更新资源名称
func _update_resource_name():
	var parts = []

	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_CROSSFADE_TO_MUSIC_RESOURCE_BASE"))

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
		parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_CROSSFADE_TO_MUSIC_RESOURCE_NO_MUSIC"))

	if volume < 1.0:
		parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_CROSSFADE_TO_MUSIC_RESOURCE_VOLUME", {"volume": snapped(volume * 100, 0.1)}))

	parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_CROSSFADE_TO_MUSIC_RESOURCE_CROSSFADE", {"duration": crossfade_duration}))

	if continue_during_pause:
		parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_CROSSFADE_TO_MUSIC_RESOURCE_CONTINUE_DURING_PAUSE"))

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

	# 查找当前正在播放的音乐播放器
	var old_player = _find_current_music_player()

	# 创建资源副本，避免修改原始共享资源
	var music_resource: AudioStream = loaded_resource.duplicate(true)

	# 配置音频流（禁用循环，仅播放一次）
	if music_resource is AudioStreamOggVorbis:
		music_resource.loop = false
	elif music_resource is AudioStreamMP3:
		music_resource.loop = false
	elif music_resource is AudioStreamWAV:
		music_resource.loop_mode = 0  # 禁用循环

	# 创建新的 AudioStreamPlayer
	var new_player = AudioStreamPlayer.new()
	# 名字必须唯一：容器中常有上一个未清理的同名播放器，add_child 同名冲突
	# 会被引擎改名为 @AudioStreamPlayer@N，导致后续按 Fuse_MusicPlayer* 查找的
	# 淡出/清理逻辑对它失效（旧曲漏淡出 → 新旧两曲叠加）
	new_player.name = "Fuse_MusicPlayer_Crossfade_%d" % Time.get_ticks_msec()
	new_player.bus = bus
	new_player.stream = music_resource
	new_player.volume_db = -60.0  # 从静音开始
	if continue_during_pause:
		new_player.process_mode = Node.PROCESS_MODE_ALWAYS

	# 获取场景树
	var scene_tree = Engine.get_main_loop()
	if not scene_tree or not scene_tree.current_scene:
		_log_error_localized("FUSE_ERROR_CANNOT_GET_CURRENT_SCENE", {})
		finished.emit()
		return

	# 添加到持久化容器
	FuseAudioContainer.add_music_player(new_player)

	# 开始播放新音乐
	new_player.play()
	_log_info_localized("FUSE_INSTRUCTION_CROSSFADE_TO_MUSIC_LOG_START", {"file": FuseNodeUtils.get_path_display_name(music_path)})

	# 执行交叉淡入淡出
	_perform_crossfade(old_player, new_player)

## 执行交叉淡入淡出
func _perform_crossfade(old_player: AudioStreamPlayer, new_player: AudioStreamPlayer):
	var scene_tree = Engine.get_main_loop()
	if not scene_tree:
		_log_error_localized("FUSE_ERROR_CANNOT_CREATE_TWEEN", {})
		_on_execution_completed()
		return

	var tween = scene_tree.create_tween()

	# 暂停时继续播放：Tween 也不应被暂停
	if continue_during_pause:
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	# 记录旧播放器的当前音量
	var old_volume_db = 0.0
	if old_player:
		old_volume_db = old_player.volume_db

	# 记录新播放器的目标音量
	var target_volume_db = linear_to_db(volume)

	# 同时执行淡入淡出
	if old_player:
		_log_debug("淡出旧音乐: 从 %s dB 到 -60 dB, 耗时 %s 秒" % [old_volume_db, crossfade_duration])
		tween.parallel().tween_property(old_player, "volume_db", -60.0, crossfade_duration)

	_log_debug("淡入新音乐: 从 -60 dB 到 %s dB, 耗时 %s 秒" % [target_volume_db, crossfade_duration])
	tween.parallel().tween_property(new_player, "volume_db", target_volume_db, crossfade_duration)

	# 等待淡入淡出完成
	tween.tween_callback(_on_crossfade_completed.bind(old_player, new_player))

## 交叉淡入淡出完成回调
func _on_crossfade_completed(old_player: AudioStreamPlayer, new_player: AudioStreamPlayer):
	_log_debug("交叉淡入淡出完成")

	# 清理旧播放器
	if old_player and not old_player.is_queued_for_deletion():
		_log_debug("清理旧音乐播放器")
		old_player.stop()
		FuseAudioContainer.remove_music_player(old_player)
		old_player.queue_free()

	# 连接新播放器的 finished 信号
	new_player.finished.connect(_on_audio_finished.bind(new_player))
	_log_info_localized("FUSE_INSTRUCTION_CROSSFADE_TO_MUSIC_LOG_COMPLETE", {})

## 音频播放完成回调
func _on_audio_finished(player: AudioStreamPlayer):
	_log_debug("音频播放完成，指令结束")
	player.finished.disconnect(_on_audio_finished)
	player.queue_free()
	_on_execution_completed()

## 查找当前正在播放的音乐播放器
func _find_current_music_player() -> AudioStreamPlayer:
	# 优先在持久化容器中查找
	var container = FuseAudioContainer.get_container()
	_log_debug("[DEBUG_FIND] 容器节点: %s, 是否有效: %s, 子节点数: %d" % [
		container.name if container else "null",
		is_instance_valid(container) if container else false,
		container.get_child_count() if container else -1])
	if container:
		for child in container.get_children():
			_log_debug("[DEBUG_FIND]   子节点: name=%s, type=%s, is_audio=%s, playing=%s" % [
				child.name, child.get_class(), child is AudioStreamPlayer, child.playing if child is AudioStreamPlayer else "N/A"])

	var players = FuseAudioContainer.find_music_players("Fuse_MusicPlayer*")

	# 选音量最大的 playing 播放器作为淡出目标：
	# 过渡窗口内新旧两个都在 playing，取第一个会误选已淡出到无声的旧播放器，
	# 导致真正在响的那个漏掉淡出（两曲叠加）
	var best: AudioStreamPlayer = null
	for player in players:
		if player.playing and (best == null or player.volume_db > best.volume_db):
			best = player
	if best:
		_log_debug("找到正在播放的音乐播放器: %s" % best.name)
		return best

	# 后备：在 current_scene 中查找（兼容旧版本）
	var scene_tree = Engine.get_main_loop()
	if scene_tree and scene_tree.current_scene:
		var scene_players = scene_tree.current_scene.find_children(
			"Fuse_MusicPlayer*",
			"AudioStreamPlayer",
			true
		)
		for player in scene_players:
			if player.playing:
				_log_debug("找到正在播放的音乐播放器(场景中): %s" % player.name)
				return player

	_log_debug("未找到正在播放的音乐播放器")
	return null

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()

	if music_path.is_empty():
		errors.append(FuseLocalization.translate("FUSE_INSTRUCTION_CROSSFADE_TO_MUSIC_VALIDATE_PATH_EMPTY"))

	if volume < 0.0 or volume > 1.0:
		errors.append(FuseLocalization.translate("FUSE_INSTRUCTION_CROSSFADE_TO_MUSIC_VALIDATE_VOLUME_RANGE"))

	# 验证混音器总线是否存在
	var bus_names = []
	for i in range(AudioServer.get_bus_count()):
		bus_names.append(AudioServer.get_bus_name(i))
	if not bus in bus_names:
		errors.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_CROSSFADE_TO_MUSIC_VALIDATE_BUS_NOT_EXIST", {"bus": bus}))

	# 验证交叉淡入淡出时间
	if crossfade_duration <= 0:
		errors.append(FuseLocalization.translate("FUSE_INSTRUCTION_CROSSFADE_TO_MUSIC_VALIDATE_CROSSFADE_DURATION"))

	return errors

## 获取指令描述
func get_description() -> String:
	var options = []

	if volume < 1.0:
		options.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_CROSSFADE_TO_MUSIC_DESC_VOLUME", {"volume": snapped(volume * 100, 0.1)}))

	if bus != "Master":
		options.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_CROSSFADE_TO_MUSIC_DESC_BUS", {"bus": bus}))

	options.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_CROSSFADE_TO_MUSIC_DESC_CROSSFADE", {"duration": crossfade_duration}))

	if continue_during_pause:
		options.append(FuseLocalization.translate("FUSE_INSTRUCTION_CROSSFADE_TO_MUSIC_DESC_CONTINUE_DURING_PAUSE"))

	var options_str = ""
	if options.size() > 0:
		options_str = " (" + ", ".join(options) + ")"

	var file_str = FuseNodeUtils.get_path_display_name(music_path) if not music_path.is_empty() else FuseLocalization.translate("FUSE_INSTRUCTION_CROSSFADE_TO_MUSIC_RESOURCE_NO_MUSIC")
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_CROSSFADE_TO_MUSIC_DESC_FILE", {"file": file_str, "options": options_str})

## ============================================================
## 运行时实例模式支持（RuntimeInstructionInstance 架构）
## ============================================================

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var state = super.get_default_runtime_state()
	state["old_player"] = null
	state["new_player"] = null
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
		# 错误同步到实例（runner 层 stop_on_error 据此发 execution_failed 并
		# 阻断后续指令），对齐 wait_for_signal 的同步模式
		runtime_instance._has_error = true
		runtime_instance._error_message = get_error_message()
		runtime_instance._complete_execution()
		return true

	# 加载音乐资源
	var loaded_resource = load(music_path)
	if not loaded_resource:
		_log_error_localized("FUSE_ERROR_FAILED_LOAD_MUSIC", {"music_path": music_path})
		set_error_localized("FUSE_ERROR_FAILED_LOAD_MUSIC", FuseError.ErrorType.RUNTIME_ERROR, {"music_path": music_path})
		# 错误同步到实例（同上）
		runtime_instance._has_error = true
		runtime_instance._error_message = get_error_message()
		runtime_instance._complete_execution()
		return true

	if not loaded_resource is AudioStream:
		_log_error_localized("FUSE_ERROR_NOT_AUDIO_STREAM", {"sound_path": music_path})
		set_error_localized("FUSE_ERROR_NOT_AUDIO_STREAM", FuseError.ErrorType.RUNTIME_ERROR, {"sound_path": music_path})
		# 错误同步到实例（同上）
		runtime_instance._has_error = true
		runtime_instance._error_message = get_error_message()
		runtime_instance._complete_execution()
		return true

	# 查找当前正在播放的音乐播放器
	var old_player = _find_current_music_player()
	state["old_player"] = old_player

	# 创建资源副本
	var music_resource: AudioStream = loaded_resource.duplicate(true)

	# 配置音频流（禁用循环）
	if music_resource is AudioStreamOggVorbis:
		music_resource.loop = false
	elif music_resource is AudioStreamMP3:
		music_resource.loop = false
	elif music_resource is AudioStreamWAV:
		music_resource.loop_mode = 0

	# 创建新的 AudioStreamPlayer
	var new_player = AudioStreamPlayer.new()
	# 名字必须唯一（同名冲突被引擎改名后会对淡出/清理逻辑隐形，见 execute 注释）
	new_player.name = "Fuse_MusicPlayer_Crossfade_%d" % Time.get_ticks_msec()
	new_player.bus = bus
	new_player.stream = music_resource
	new_player.volume_db = -60.0  # 从静音开始
	if continue_during_pause:
		new_player.process_mode = Node.PROCESS_MODE_ALWAYS

	# 获取场景树
	var scene_tree = Engine.get_main_loop()
	if not scene_tree or not scene_tree.current_scene:
		_log_error_localized("FUSE_ERROR_CANNOT_GET_CURRENT_SCENE", {})
		set_error_localized("FUSE_ERROR_CANNOT_GET_CURRENT_SCENE", FuseError.ErrorType.RUNTIME_ERROR, {})
		# 错误同步到实例（同上）
		runtime_instance._has_error = true
		runtime_instance._error_message = get_error_message()
		runtime_instance._complete_execution()
		return true

	# 添加到持久化容器
	FuseAudioContainer.add_music_player(new_player)
	state["new_player"] = new_player

	# 开始播放新音乐
	new_player.play()
	_log_info_localized("FUSE_INSTRUCTION_CROSSFADE_TO_MUSIC_LOG_START", {"file": FuseNodeUtils.get_path_display_name(music_path)})

	# 执行交叉淡入淡出
	_perform_crossfade_runtime(runtime_instance, old_player, new_player)

	return false  # 异步执行

## 执行交叉淡入淡出（运行时实例版本）
func _perform_crossfade_runtime(runtime_instance: RuntimeInstructionInstance, old_player: AudioStreamPlayer, new_player: AudioStreamPlayer) -> void:
	var state = runtime_instance.runtime_state
	var scene_tree = Engine.get_main_loop()

	if not scene_tree:
		_log_error_localized("FUSE_ERROR_CANNOT_CREATE_TWEEN", {})
		set_error_localized("FUSE_ERROR_CANNOT_CREATE_TWEEN", FuseError.ErrorType.RUNTIME_ERROR, {})
		# 错误同步到实例（同上）
		runtime_instance._has_error = true
		runtime_instance._error_message = get_error_message()
		runtime_instance._complete_execution()
		return

	var tween = scene_tree.create_tween()
	state["tween"] = tween
	state["is_running"] = true

	# 暂停时继续播放：Tween 也不应被暂停
	if continue_during_pause:
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	# 记录旧播放器的当前音量
	var old_volume_db = 0.0
	if old_player:
		old_volume_db = old_player.volume_db

	# 记录新播放器的目标音量
	var target_volume_db = linear_to_db(volume)

	# 同时执行淡入淡出
	if old_player:
		tween.parallel().tween_property(old_player, "volume_db", -60.0, crossfade_duration)

	tween.parallel().tween_property(new_player, "volume_db", target_volume_db, crossfade_duration)

	# 使用回调注册机制
	var callback = _create_crossfade_callback(runtime_instance)
	tween.finished.connect(callback, CONNECT_ONE_SHOT)
	runtime_instance.register_timer_callback(callback)
	state["tween_callback"] = callback

## 创建交叉淡入淡出完成回调
func _create_crossfade_callback(runtime_instance: RuntimeInstructionInstance) -> Callable:
	var callback = func():
		_on_crossfade_completed_runtime(runtime_instance)
	return callback

## 交叉淡入淡出完成回调（运行时实例版本）
func _on_crossfade_completed_runtime(runtime_instance: RuntimeInstructionInstance) -> void:
	# 资源善后（清理 old、接管 new 的播完释放）不依赖实例完成状态：
	# ON_START 完成时机的指令在启动瞬间就"完成"（不阻塞 runner，LoopMusic 续播依赖此语义），
	# 若在此处被 is_completed 挡板拦住，old 播放器会残留为无声 playing 僵尸；
	# 取消路径的清理由 on_runtime_cancel 接管，与这里的清理幂等共存
	if not runtime_instance:
		return

	var state = runtime_instance.runtime_state
	var old_player = state.get("old_player")
	var new_player = state.get("new_player")

	# 清理旧播放器
	if old_player and is_instance_valid(old_player) and not old_player.is_queued_for_deletion():
		old_player.stop()
		FuseAudioContainer.remove_music_player(old_player)
		old_player.queue_free()

	# 连接新播放器的 finished 信号（回调闭包直接持有播放器引用：
	# ON_START 下实例会被对象池快速回收复用，state 届时不可靠）
	if new_player and is_instance_valid(new_player):
		var finished_callback = _create_audio_finished_callback(new_player)
		new_player.finished.connect(finished_callback, CONNECT_ONE_SHOT)
		state["finished_callback"] = finished_callback

	_log_info_localized("FUSE_INSTRUCTION_CROSSFADE_TO_MUSIC_LOG_COMPLETE", {})

	# 清理状态
	state["tween"] = null
	state["old_player"] = null
	state["is_running"] = false
	state["tween_callback"] = null

## 创建音频播放完成回调（闭包直接持有播放器，不依赖可被池复用的实例 state）
func _create_audio_finished_callback(player: AudioStreamPlayer) -> Callable:
	var callback = func():
		_on_audio_finished_direct(player)
	return callback

## 音频播放完成处理：释放播放器（不触碰 runtime_instance——
## ON_START 时机的实例此时可能早已归还对象池并被复用）
func _on_audio_finished_direct(player: AudioStreamPlayer) -> void:
	if is_instance_valid(player):
		FuseAudioContainer.remove_music_player(player)
		player.queue_free()

## 取消处理（场景切换时 runner 被取消：清理过渡状态，保留已启动的新音乐）
## 不处理的话：tween 挂在 SceneTree 上继续跑，完成回调因实例已取消被跳过，
## 旧播放器残留为无声但 playing 状态的僵尸，被下一次 crossfade 误选为淡出目标
func on_runtime_cancel(runtime_instance: RuntimeInstructionInstance) -> void:
	var state = runtime_instance.runtime_state

	# 中止未完成的过渡 tween
	var tween = state.get("tween")
	if tween and is_instance_valid(tween):
		tween.kill()
	state["tween"] = null
	state["tween_callback"] = null

	# 旧播放器：正常路径 3 秒后淡出清理；取消时立即清理，避免僵尸残留
	var old_player = state.get("old_player")
	if old_player and is_instance_valid(old_player):
		old_player.stop()
		FuseAudioContainer.remove_music_player(old_player)
		old_player.queue_free()
	state["old_player"] = null

	# 新播放器：直接跳到目标音量并保留（音乐跨场景延续，由下一场景的
	# crossfade 找到并淡出）；断开绑定已取消实例的 finished 回调
	var new_player = state.get("new_player")
	if new_player and is_instance_valid(new_player):
		new_player.volume_db = linear_to_db(volume)
		var finished_cb = state.get("finished_callback")
		if finished_cb is Callable and new_player.finished.is_connected(finished_cb):
			new_player.finished.disconnect(finished_cb)
	state["finished_callback"] = null
	state["is_running"] = false

## 暂停处理
func on_runtime_pause(runtime_instance: RuntimeInstructionInstance) -> void:
	if continue_during_pause:
		return

	var state = runtime_instance.runtime_state
	var tween = state.get("tween")
	var new_player = state.get("new_player")

	if tween and is_instance_valid(tween):
		tween.pause()
		state["is_running"] = false

	if new_player and is_instance_valid(new_player):
		new_player.stream_paused = true

## 恢复处理
func on_runtime_resume(runtime_instance: RuntimeInstructionInstance) -> void:
	if continue_during_pause:
		return

	var state = runtime_instance.runtime_state
	var tween = state.get("tween")
	var new_player = state.get("new_player")

	if tween and is_instance_valid(tween):
		tween.play()
		state["is_running"] = true

	if new_player and is_instance_valid(new_player):
		new_player.stream_paused = false
