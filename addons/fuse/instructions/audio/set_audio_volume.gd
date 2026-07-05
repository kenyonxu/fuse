@tool
@icon("res://addons/fuse/icons/builtin/Line2D.png")
extends BaseInstruction
class_name SetAudioVolume

## 设置音频音量

# 目标模式
enum TargetMode {
	SPECIFIC_PLAYER,    # 指定的音频播放器
	BY_BUS,             # 按混音器总线
	BY_NAME_PATTERN     # 按名称模式
}

var target_mode: TargetMode = TargetMode.SPECIFIC_PLAYER

# 目标音频播放器路径（当 target_mode = SPECIFIC_PLAYER）
var target_player: NodePath = NodePath("")

# 混音器总线（当 target_mode = BY_BUS）
var bus: String = "Master"

# 名称模式（当 target_mode = BY_NAME_PATTERN）
var name_pattern: String = "Fuse_AudioPlayer_*"

# 音量（0.0 - 1.0）
var volume: float = 1.0

# 是否淡入淡出
var fade: bool = false

# 淡入淡出时间（秒）
var fade_duration: float = 0.5

## 获取指令元数据（用于指令选择器）
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_SET_AUDIO_VOLUME_NAME"
	metadata.category_key = "FUSE_CATEGORY_AUDIO"
	metadata.description_key = "FUSE_INSTRUCTION_SET_AUDIO_VOLUME_DESC"
	metadata.keywords = ["volume", "audio", "sound", "gain", "音量", "音频"]
	metadata.builtin_icon = "Line2D"
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties := []

	# Target Mode 分类
	properties.append({
		name = "Target Mode",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 目标模式
	properties.append({
		name = "target_mode",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Specific Player,Bus,Name Pattern",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Target 分类
	properties.append({
		name = "Target",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 目标音频播放器
	properties.append({
		name = "target_player",
		type = TYPE_NODE_PATH,
		hint = PROPERTY_HINT_NODE_PATH_VALID_TYPES,
		hint_string = "AudioStreamPlayer,AudioStreamPlayer2D,AudioStreamPlayer3D",
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

	# 名称模式
	properties.append({
		name = "name_pattern",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Volume 分类
	properties.append({
		name = "Volume",
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

	# Fade 分类
	properties.append({
		name = "Fade",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 是否淡入淡出
	properties.append({
		name = "fade",
		type = TYPE_BOOL,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 淡入淡出时间
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

	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_SET_AUDIO_VOLUME_RESOURCE_BASE"))

	var target_str = ""
	match target_mode:
		TargetMode.SPECIFIC_PLAYER:
			if not target_player.is_empty():
				target_str = FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_AUDIO_VOLUME_TARGET_SPECIFIC", {"player": str(target_player)})
			else:
				target_str = FuseLocalization.translate("FUSE_INSTRUCTION_SET_AUDIO_VOLUME_TARGET_NO_PLAYER")
		TargetMode.BY_BUS:
			target_str = FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_AUDIO_VOLUME_TARGET_BUS", {"bus": bus})
		TargetMode.BY_NAME_PATTERN:
			target_str = FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_AUDIO_VOLUME_TARGET_PATTERN", {"pattern": name_pattern})

	parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_AUDIO_VOLUME_RESOURCE_TARGET_VOLUME", {"target": target_str, "volume": snapped(volume * 100, 0.1)}))

	if fade:
		parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_AUDIO_VOLUME_RESOURCE_FADE", {"duration": fade_duration}))

	resource_name = " ".join(parts)

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	var target_players = []

	# 获取目标音频播放器列表
	match target_mode:
		TargetMode.SPECIFIC_PLAYER:
			if target_player.is_empty():
				_log_error_localized("FUSE_ERROR_TARGET_PLAYER_EMPTY", {})
				set_error_localized("FUSE_ERROR_TARGET_PLAYER_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
				finished.emit()
				return

			var player := context.get_node(target_player)
			if not player:
				_log_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(target_player)})
				set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"node": str(target_player)})
				finished.emit()
				return

			if not (player is AudioStreamPlayer or player is AudioStreamPlayer2D or player is AudioStreamPlayer3D):
				_log_error_localized("FUSE_ERROR_NOT_AUDIO_PLAYER", {"node": player.name})
				set_error_localized("FUSE_ERROR_NOT_AUDIO_PLAYER", FuseError.ErrorType.RUNTIME_ERROR, {"node": player.name})
				finished.emit()
				return

			target_players.append(player)

		TargetMode.BY_BUS:
			target_players = FuseAudioContainer.find_audio_players_filtered(bus)

		TargetMode.BY_NAME_PATTERN:
			target_players = FuseAudioContainer.find_audio_players_filtered("", name_pattern)

	if target_players.is_empty():
		_log_warning_localized("FUSE_INSTRUCTION_SET_AUDIO_VOLUME_LOG_NO_TARGET", {})
		_on_execution_completed()
		return

	# 设置音量
	var volume_db = linear_to_db(volume)

	for player in target_players:
		if fade:
			_fade_volume(player, volume_db)
		else:
			player.volume_db = volume_db

	_log_info_localized("FUSE_INSTRUCTION_SET_AUDIO_VOLUME_LOG_SET_VOLUME", {"count": str(target_players.size()), "volume": snapped(volume * 100, 0.1)})
	_on_execution_completed()

## 查找所有音频播放器
func _find_all_audio_players(node: Node, players: Array, bus_filter: String = "", name_pattern_filter: String = "") -> void:
	for child in node.get_children():
		if child is AudioStreamPlayer or child is AudioStreamPlayer2D or child is AudioStreamPlayer3D:
			var should_add = true

			if not bus_filter.is_empty():
				if child.get_bus() != bus_filter:
					should_add = false

			if not name_pattern_filter.is_empty():
				if not _matches_pattern(child.name, name_pattern_filter):
					should_add = false

			if should_add:
				players.append(child)

		_find_all_audio_players(child, players, bus_filter, name_pattern_filter)

## 匹配名称模式（支持通配符 *）
func _matches_pattern(name: String, pattern: String) -> bool:
	var regex_pattern = pattern.replace("*", ".*")
	var regex = RegEx.new()
	regex.compile("^%s$" % regex_pattern)

	var result = regex.search(name)
	return result != null

## 淡入淡出音量
func _fade_volume(player: AudioStreamPlayer, target_db: float) -> void:
	var scene_tree = Engine.get_main_loop()
	if not scene_tree:
		_log_error_localized("FUSE_ERROR_CANNOT_CREATE_TWEEN", {})
		player.volume_db = target_db
		return

	var tween = scene_tree.create_tween()
	tween.tween_property(player, "volume_db", target_db, fade_duration)

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()

	# 验证音量范围
	if volume < 0.0 or volume > 1.0:
		errors.append(FuseLocalization.translate("FUSE_INSTRUCTION_SET_AUDIO_VOLUME_VALIDATE_VOLUME_RANGE"))

	# 验证淡入淡出时间
	if fade and fade_duration <= 0:
		errors.append(FuseLocalization.translate("FUSE_INSTRUCTION_SET_AUDIO_VOLUME_VALIDATE_FADE_DURATION"))

	# 验证目标模式参数
	match target_mode:
		TargetMode.SPECIFIC_PLAYER:
			if target_player.is_empty():
				errors.append(FuseLocalization.translate("FUSE_INSTRUCTION_SET_AUDIO_VOLUME_VALIDATE_TARGET_EMPTY"))
		TargetMode.BY_BUS:
			var bus_names = []
			for i in range(AudioServer.get_bus_count()):
				bus_names.append(AudioServer.get_bus_name(i))
			if not bus in bus_names:
				errors.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_AUDIO_VOLUME_VALIDATE_BUS_NOT_EXIST", {"bus": bus}))
		TargetMode.BY_NAME_PATTERN:
			if name_pattern.is_empty():
				errors.append(FuseLocalization.translate("FUSE_INSTRUCTION_SET_AUDIO_VOLUME_VALIDATE_PATTERN_EMPTY"))

	return errors

## 动态属性设置（支持属性刷新）
func _set(property: StringName, value: Variant) -> bool:
	if property == "target_mode" or property == "fade":
		set(property, value)
		notify_property_list_changed()
		return true
	return false

## 属性验证
func _validate_property(property: Dictionary) -> void:
	if property.name == "target_player" and target_mode != TargetMode.SPECIFIC_PLAYER:
		property.usage = PROPERTY_USAGE_NO_EDITOR

	if property.name == "bus" and target_mode != TargetMode.BY_BUS:
		property.usage = PROPERTY_USAGE_NO_EDITOR

	if property.name == "name_pattern" and target_mode != TargetMode.BY_NAME_PATTERN:
		property.usage = PROPERTY_USAGE_NO_EDITOR

	if property.name == "fade_duration" and not fade:
		property.usage = PROPERTY_USAGE_NO_EDITOR

## 获取指令描述
func get_description() -> String:
	var target_desc = ""

	match target_mode:
		TargetMode.SPECIFIC_PLAYER:
			target_desc = str(target_player) if not target_player.is_empty() else FuseLocalization.translate("FUSE_INSTRUCTION_SET_AUDIO_VOLUME_DESC_SPECIFIED")
		TargetMode.BY_BUS:
			target_desc = FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_AUDIO_VOLUME_DESC_BUS", {"bus": bus})
		TargetMode.BY_NAME_PATTERN:
			target_desc = FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_AUDIO_VOLUME_DESC_NAME", {"name": name_pattern})

	var fade_desc = ""
	if fade:
		fade_desc = FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_AUDIO_VOLUME_DESC_FADE_ONLY", {"duration": fade_duration})

	return FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_AUDIO_VOLUME_DESC_TARGET_FADE", {
		"target": target_desc,
		"volume": snapped(volume * 100, 0.1),
		"fade": fade_desc
	})
