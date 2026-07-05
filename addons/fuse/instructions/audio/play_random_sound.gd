@tool
@icon("res://addons/fuse/icons/builtin/AudioStreamRandomizer.svg")
extends BaseInstruction
class_name PlayRandomSound

## 从音效池中随机选择一个播放

# 音频资源路径列表
var sound_paths: Array[String] = []

# 音量（0.0 - 1.0）
var volume: float = 1.0:
	set(value):
		if volume != value:
			volume = value
			_update_resource_name()

# 音调偏移
var pitch_scale: float = 1.0:
	set(value):
		if pitch_scale != value:
			pitch_scale = value
			_update_resource_name()

# 随机音高范围（在 pitch_scale 基础上随机偏移 ±range，0 表示不随机）
var pitch_random_range: float = 0.0:
	set(value):
		if pitch_random_range != value:
			pitch_random_range = value
			_update_resource_name()

# 混音器总线
var bus: String = "Master":
	set(value):
		if bus != value:
			bus = value
			_update_resource_name()

func _set(property: StringName, value: Variant) -> bool:
	if property == "sound_paths":
		sound_paths = value
		_update_resource_name()
		return true
	return false

## 获取指令元数据（用于指令选择器）
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_PLAY_RANDOM_SOUND_NAME"
	metadata.category_key = "FUSE_CATEGORY_AUDIO"
	metadata.description_key = "FUSE_INSTRUCTION_PLAY_RANDOM_SOUND_DESC"
	metadata.keywords = ["random", "sound", "audio", "sfx", "pool", "随机", "音效", "声音"]
	metadata.builtin_icon = "AudioStreamRandomizer"
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties := []

	# Audio 分类
	properties.append({
		name = "Audio",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 音频路径列表
	properties.append({
		name = "sound_paths",
		type = TYPE_ARRAY,
		hint = PROPERTY_HINT_TYPE_STRING,
		hint_string = "%d/%d:*.mp3,*.ogg,*.wav" % [TYPE_STRING, PROPERTY_HINT_FILE],
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

	# 音调
	properties.append({
		name = "pitch_scale",
		type = TYPE_FLOAT,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "0.01,4,0.01,or_greater",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 随机音高范围
	properties.append({
		name = "pitch_random_range",
		type = TYPE_FLOAT,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "0,2,0.01,or_greater",
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

	return properties

## 更新资源名称
func _update_resource_name():
	var parts = []

	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_PLAY_RANDOM_SOUND_RESOURCE_BASE"))

	if sound_paths.size() > 0:
		parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_PLAY_RANDOM_SOUND_RESOURCE_COUNT", {"count": sound_paths.size()}))
	else:
		parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_PLAY_RANDOM_SOUND_RESOURCE_NO_SOUND"))

	if volume < 1.0:
		parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_PLAY_SOUND_RESOURCE_VOLUME", {"volume": snapped(volume * 100, 0.1)}))

	if pitch_scale != 1.0:
		parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_PLAY_SOUND_RESOURCE_PITCH", {"pitch": pitch_scale}))

	if pitch_random_range > 0.0:
		parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_PLAY_SOUND_RESOURCE_PITCH_RANDOM", {"range": pitch_random_range}))

	resource_name = " ".join(parts)

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	# 验证音频路径列表
	if sound_paths.size() == 0:
		_log_error_localized("FUSE_INSTRUCTION_PLAY_RANDOM_SOUND_ERROR_PATHS_EMPTY", {})
		set_error_localized("FUSE_INSTRUCTION_PLAY_RANDOM_SOUND_ERROR_PATHS_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 随机选择一个音频路径
	var chosen_path: String = sound_paths[randi() % sound_paths.size()]

	# 加载音频资源
	var sound_resource = load(chosen_path)
	if not sound_resource:
		_log_error_localized("FUSE_ERROR_FAILED_LOAD_SOUND", {
			"sound_path": chosen_path
		})
		set_error_localized("FUSE_ERROR_FAILED_LOAD_SOUND", FuseError.ErrorType.RUNTIME_ERROR, {
			"sound_path": chosen_path
		})
		finished.emit()
		return

	if not sound_resource is AudioStream:
		_log_error_localized("FUSE_ERROR_NOT_AUDIO_STREAM", {
			"sound_path": chosen_path
		})
		set_error_localized("FUSE_ERROR_NOT_AUDIO_STREAM", FuseError.ErrorType.RUNTIME_ERROR, {
			"sound_path": chosen_path
		})
		finished.emit()
		return

	# 创建 AudioStreamPlayer
	var audio_player = AudioStreamPlayer.new()
	audio_player.name = "Fuse_AudioPlayer_" + str(randi())

	# 配置音频播放器
	audio_player.stream = sound_resource
	audio_player.volume_db = linear_to_db(volume)
	audio_player.pitch_scale = pitch_scale + randf_range(-pitch_random_range, pitch_random_range)
	audio_player.bus = bus

	# 添加到场景树
	var scene_tree = Engine.get_main_loop()
	if scene_tree and scene_tree.current_scene:
		scene_tree.current_scene.add_child(audio_player)

		# 连接播放完成信号，播放完成后自动清理
		audio_player.finished.connect(_on_sound_finished.bind(audio_player))

		# 播放音频
		audio_player.play()
		_log_info_localized("FUSE_INSTRUCTION_PLAY_RANDOM_SOUND_LOG_PLAYING", {"file": FuseNodeUtils.get_path_display_name(chosen_path)})
	else:
		_log_error_localized("FUSE_ERROR_CANNOT_GET_CURRENT_SCENE", {})
		finished.emit()
		return

	_on_execution_completed()

## 音频播放完成回调
func _on_sound_finished(audio_player: AudioStreamPlayer) -> void:
	if is_instance_valid(audio_player):
		audio_player.queue_free()

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()

	if sound_paths.size() == 0:
		errors.append(FuseLocalization.translate("FUSE_INSTRUCTION_PLAY_RANDOM_SOUND_VALIDATE_PATHS_EMPTY"))

	if volume < 0.0 or volume > 1.0:
		errors.append(FuseLocalization.translate("FUSE_INSTRUCTION_PLAY_SOUND_VALIDATE_VOLUME_RANGE"))

	if pitch_scale <= 0.0:
		errors.append(FuseLocalization.translate("FUSE_INSTRUCTION_PLAY_SOUND_VALIDATE_PITCH_POSITIVE"))

	# 验证混音器总线是否存在
	var bus_names = []
	for i in range(AudioServer.get_bus_count()):
		bus_names.append(AudioServer.get_bus_name(i))
	if not bus in bus_names:
		errors.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_PLAY_SOUND_VALIDATE_BUS_NOT_EXIST", {"bus": bus}))

	return errors

## 获取指令描述
func get_description() -> String:
	var options = []

	if volume < 1.0:
		options.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_PLAY_SOUND_DESC_VOLUME", {"volume": snapped(volume * 100, 0.1)}))

	if pitch_scale != 1.0:
		options.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_PLAY_SOUND_DESC_PITCH", {"pitch": pitch_scale}))

	if pitch_random_range > 0.0:
		options.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_PLAY_SOUND_DESC_PITCH_RANDOM", {"range": pitch_random_range}))

	if bus != "Master":
		options.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_PLAY_SOUND_DESC_BUS", {"bus": bus}))

	var options_str = ""
	if options.size() > 0:
		options_str = " (" + ", ".join(options) + ")"

	var count_str = str(sound_paths.size()) if sound_paths.size() > 0 else FuseLocalization.translate("FUSE_INSTRUCTION_PLAY_RANDOM_SOUND_RESOURCE_NO_SOUND")
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_PLAY_RANDOM_SOUND_DESC_COUNT", {"count": count_str, "options": options_str})
