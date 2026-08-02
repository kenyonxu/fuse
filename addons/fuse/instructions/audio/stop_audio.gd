@tool
@icon("res://addons/fuse/icons/builtin/Stop.png")
extends BaseInstruction
class_name StopAudio

## 停止音频播放

# 停止模式
enum StopMode {
	ALL_AUDIO,          # 停止所有音频
	BY_BUS,             # 停止指定总线的音频
	BY_NAME_PATTERN     # 停止匹配名称模式的音频
}

var stop_mode: StopMode = StopMode.ALL_AUDIO

# 混音器总线（当 stop_mode = BY_BUS）
var bus: String = "Master"

# 名称模式（当 stop_mode = BY_NAME_PATTERN）
var name_pattern: String = "Fuse_AudioPlayer_*"

# 是否淡出
var fade_out: bool = false

# 淡出时间（秒）
var fade_duration: float = 0.5

## 获取指令元数据（用于指令选择器）
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_STOP_AUDIO_NAME"
	metadata.category_key = "FUSE_CATEGORY_AUDIO"
	metadata.description_key = "FUSE_INSTRUCTION_STOP_AUDIO_DESC"
	metadata.keywords = ["stop", "audio", "sound", "music", "silence", "停止", "音频", "静音"]
	metadata.builtin_icon = "Stop"
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	# Stop Mode 分类
	properties.append({
		name = "Stop Mode",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 停止模式
	properties.append({
		name = "stop_mode",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "All Audio,Bus,Name Pattern",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Target 分类
	properties.append({
		name = "Target",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
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

	# 名称模式
	properties.append({
		name = "name_pattern",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Fade Options 分类
	properties.append({
		name = "Fade Options",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 是否淡出
	properties.append({
		name = "fade_out",
		type = TYPE_BOOL,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 淡出时间
	properties.append({
		name = "fade_duration",
		type = TYPE_FLOAT,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "0,5,0.1,or_greater",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 更新资源名称
func _update_resource_name():
	var parts = []

	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_STOP_AUDIO_RESOURCE_BASE"))

	match stop_mode:
		StopMode.ALL_AUDIO:
			parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_STOP_AUDIO_TARGET_ALL"))
		StopMode.BY_BUS:
			parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_STOP_AUDIO_TARGET_BUS", {"bus": bus}))
		StopMode.BY_NAME_PATTERN:
			parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_STOP_AUDIO_TARGET_PATTERN", {"pattern": name_pattern}))

	if fade_out:
		parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_STOP_AUDIO_RESOURCE_FADE", {"duration": fade_duration}))

	resource_name = " ".join(parts)

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	var scene_tree = Engine.get_main_loop()
	if not scene_tree or not scene_tree.current_scene:
		_log_error_localized("FUSE_ERROR_CANNOT_GET_CURRENT_SCENE", {})
		finished.emit()
		return

	var stopped_count = 0

	# 遍历所有音频播放器（容器 + current_scene）
	var audio_players = FuseAudioContainer.find_all_audio_players()

	for player in audio_players:
		if _should_stop_player(player):
			if fade_out and player is AudioStreamPlayer:
				_fade_out_and_stop(player)
				stopped_count += 1
			else:
				player.stop()
				stopped_count += 1

	_log_info_localized("FUSE_INSTRUCTION_STOP_AUDIO_LOG_STOPPED", {"count": str(stopped_count)})
	_on_execution_completed()

## 查找所有音频播放器
func _find_all_audio_players(node: Node, players: Array) -> void:
	for child in node.get_children():
		if child is AudioStreamPlayer or child is AudioStreamPlayer2D or child is AudioStreamPlayer3D:
			players.append(child)

		_find_all_audio_players(child, players)

## 判断是否应该停止该播放器
func _should_stop_player(player) -> bool:
	match stop_mode:
		StopMode.ALL_AUDIO:
			return true

		StopMode.BY_BUS:
			if player.has_method("get_bus"):
				return player.get_bus() == bus
			return false

		StopMode.BY_NAME_PATTERN:
			return _matches_pattern(player.name, name_pattern)

		_:
			return false

## 匹配名称模式（支持通配符 *）
func _matches_pattern(name: String, pattern: String) -> bool:
	# 将通配符 * 转换为正则表达式
	var regex_pattern = pattern.replace("*", ".*")
	var regex = RegEx.new()
	regex.compile("^%s$" % regex_pattern)

	var result = regex.search(name)
	return result != null

## 淡出并停止
func _fade_out_and_stop(player: AudioStreamPlayer) -> void:
	var scene_tree = Engine.get_main_loop()
	if not scene_tree:
		_log_error_localized("FUSE_ERROR_CANNOT_CREATE_TWEEN", {})
		player.stop()
		return

	var tween = scene_tree.create_tween()
	var original_volume = player.volume_db

	# 淡出到 -60 dB（接近静音）
	tween.tween_property(player, "volume_db", -60.0, fade_duration)

	# 淡出完成后停止并清理
	tween.tween_callback(func():
		if is_instance_valid(player):
			player.stop()
			player.volume_db = original_volume  # 恢复原始音量
	)

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()

	# 验证混音器总线是否存在
	if stop_mode == StopMode.BY_BUS:
		var bus_names = []
		for i in range(AudioServer.get_bus_count()):
			bus_names.append(AudioServer.get_bus_name(i))
		if not bus in bus_names:
			errors.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_STOP_AUDIO_VALIDATE_BUS_NOT_EXIST", {"bus": bus}))

	# 验证名称模式不为空
	if stop_mode == StopMode.BY_NAME_PATTERN and name_pattern.is_empty():
		errors.append(FuseLocalization.translate("FUSE_INSTRUCTION_STOP_AUDIO_VALIDATE_PATTERN_EMPTY"))

	# 验证淡出时间
	if fade_out and fade_duration <= 0:
		errors.append(FuseLocalization.translate("FUSE_INSTRUCTION_STOP_AUDIO_VALIDATE_FADE_DURATION"))

	return errors

## 动态属性设置（支持属性刷新）
func _set(property: StringName, value: Variant) -> bool:
	if property == "stop_mode" or property == "fade_out":
		set(property, value)
		notify_property_list_changed()
		return true
	return false

## 属性验证
func _validate_property(property: Dictionary) -> void:
	if property.name == "bus" and stop_mode != StopMode.BY_BUS:
		property.usage = PROPERTY_USAGE_NO_EDITOR

	if property.name == "name_pattern" and stop_mode != StopMode.BY_NAME_PATTERN:
		property.usage = PROPERTY_USAGE_NO_EDITOR

	if property.name == "fade_duration" and not fade_out:
		property.usage = PROPERTY_USAGE_NO_EDITOR

## 获取指令描述
func get_description() -> String:
	var target_desc = ""

	match stop_mode:
		StopMode.ALL_AUDIO:
			target_desc = FuseLocalization.translate("FUSE_INSTRUCTION_STOP_AUDIO_DESC_ALL")
		StopMode.BY_BUS:
			target_desc = FuseLocalization.translate_format("FUSE_INSTRUCTION_STOP_AUDIO_DESC_BUS", {"bus": bus})
		StopMode.BY_NAME_PATTERN:
			target_desc = FuseLocalization.translate_format("FUSE_INSTRUCTION_STOP_AUDIO_DESC_PATTERN", {"pattern": name_pattern})

	var fade_desc = ""
	if fade_out:
		fade_desc = FuseLocalization.translate_format("FUSE_INSTRUCTION_STOP_AUDIO_DESC_FADE", {"duration": fade_duration})

	return FuseLocalization.translate_format("FUSE_INSTRUCTION_STOP_AUDIO_DESC_TARGET_FADE", {"target": target_desc, "fade": fade_desc})
