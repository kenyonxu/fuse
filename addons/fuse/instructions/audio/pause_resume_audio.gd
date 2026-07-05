@tool
@icon("res://addons/fuse/icons/builtin/Pause.png")
extends BaseInstruction
class_name PauseResumeAudio

## 暂停或恢复音频播放

# 操作模式
enum ActionMode {
	PAUSE,
	RESUME
}

var action_mode: ActionMode = ActionMode.PAUSE

# 目标模式
enum TargetMode {
	SPECIFIC_PLAYER,    # 指定的音频播放器
	BY_BUS,             # 按混音器总线
	BY_NAME_PATTERN,    # 按名称模式
	ALL_PLAYING         # 所有正在播放的音频
}

var target_mode: TargetMode = TargetMode.ALL_PLAYING

# 目标音频播放器路径（当 target_mode = SPECIFIC_PLAYER）
var target_player: NodePath = NodePath("")

# 混音器总线（当 target_mode = BY_BUS）
var bus: String = "Master"

# 名称模式（当 target_mode = BY_NAME_PATTERN）
var name_pattern: String = "Fuse_AudioPlayer_*"

## 获取指令元数据（用于指令选择器）
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_PAUSE_RESUME_AUDIO_NAME"
	metadata.category_key = "FUSE_CATEGORY_AUDIO"
	metadata.description_key = "FUSE_INSTRUCTION_PAUSE_RESUME_AUDIO_DESC"
	metadata.keywords = ["pause", "resume", "audio", "sound", "music", "暂停", "恢复"]
	metadata.builtin_icon = "Pause"
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties := []

	# Action 分类
	properties.append({
		name = "Action",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 操作模式
	properties.append({
		name = "action_mode",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Pause,Resume",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

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
		hint_string = "Specific Player,Bus,Name Pattern,All Playing",
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

	return properties

## 更新资源名称
func _update_resource_name():
	var parts = []

	var action_key = "FUSE_INSTRUCTION_PAUSE_RESUME_AUDIO_RESOURCE_PAUSE" if action_mode == ActionMode.PAUSE else "FUSE_INSTRUCTION_PAUSE_RESUME_AUDIO_RESOURCE_RESUME"
	parts.append(FuseLocalization.translate(action_key))

	match target_mode:
		TargetMode.SPECIFIC_PLAYER:
			if not target_player.is_empty():
				parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_PAUSE_RESUME_AUDIO_TARGET_SPECIFIC", {"player": str(target_player)}))
			else:
				parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_PAUSE_RESUME_AUDIO_TARGET_NO_PLAYER"))
		TargetMode.BY_BUS:
			parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_PAUSE_RESUME_AUDIO_TARGET_BUS", {"bus": bus}))
		TargetMode.BY_NAME_PATTERN:
			parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_PAUSE_RESUME_AUDIO_TARGET_PATTERN", {"pattern": name_pattern}))
		TargetMode.ALL_PLAYING:
			parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_PAUSE_RESUME_AUDIO_TARGET_ALL"))

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

		TargetMode.BY_BUS, TargetMode.BY_NAME_PATTERN, TargetMode.ALL_PLAYING:
			var bus_filter = ""
			var name_pattern_filter = ""
			var playing_only = false

			if target_mode == TargetMode.BY_BUS:
				bus_filter = bus
			elif target_mode == TargetMode.BY_NAME_PATTERN:
				name_pattern_filter = name_pattern
			elif target_mode == TargetMode.ALL_PLAYING:
				playing_only = true

			target_players = FuseAudioContainer.find_audio_players_filtered(bus_filter, name_pattern_filter, playing_only)

	if target_players.is_empty():
		_log_warning_localized("FUSE_INSTRUCTION_PAUSE_RESUME_AUDIO_LOG_NO_TARGET", {})
		_on_execution_completed()
		return

	# 执行暂停或恢复操作
	var action_key = "FUSE_INSTRUCTION_PAUSE_RESUME_AUDIO_LOG_PAUSED" if action_mode == ActionMode.PAUSE else "FUSE_INSTRUCTION_PAUSE_RESUME_AUDIO_LOG_RESUMED"
	var action_str = FuseLocalization.translate(action_key)
	var affected_count = 0

	for player in target_players:
		if action_mode == ActionMode.PAUSE:
			if player.playing:
				player.stream_paused = true
				affected_count += 1
		else:  # RESUME
			if player.stream_paused:
				player.stream_paused = false
				affected_count += 1

	_log_info_localized("FUSE_INSTRUCTION_PAUSE_RESUME_AUDIO_LOG_COUNT", {"action": action_str, "count": str(affected_count)})
	_on_execution_completed()

## 查找所有音频播放器
func _find_all_audio_players(node: Node, players: Array, bus_filter: String = "", name_pattern_filter: String = "", playing_only: bool = false) -> void:
	for child in node.get_children():
		if child is AudioStreamPlayer or child is AudioStreamPlayer2D or child is AudioStreamPlayer3D:
			var should_add = true

			if playing_only and not child.playing:
				should_add = false

			if not bus_filter.is_empty():
				if child.get_bus() != bus_filter:
					should_add = false

			if not name_pattern_filter.is_empty():
				if not _matches_pattern(child.name, name_pattern_filter):
					should_add = false

			if should_add:
				players.append(child)

		_find_all_audio_players(child, players, bus_filter, name_pattern_filter, playing_only)

## 匹配名称模式（支持通配符 *）
func _matches_pattern(name: String, pattern: String) -> bool:
	var regex_pattern = pattern.replace("*", ".*")
	var regex = RegEx.new()
	regex.compile("^%s$" % regex_pattern)

	var result = regex.search(name)
	return result != null

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()

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
	if property == "target_mode":
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

## 获取指令描述
func get_description() -> String:
	var action_key = "FUSE_INSTRUCTION_PAUSE_RESUME_AUDIO_RESOURCE_PAUSE" if action_mode == ActionMode.PAUSE else "FUSE_INSTRUCTION_PAUSE_RESUME_AUDIO_RESOURCE_RESUME"
	var action_str = FuseLocalization.translate(action_key)
	var target_desc = ""

	match target_mode:
		TargetMode.SPECIFIC_PLAYER:
			target_desc = str(target_player) if not target_player.is_empty() else FuseLocalization.translate("FUSE_INSTRUCTION_PAUSE_RESUME_AUDIO_DESC_SPECIFIED")
		TargetMode.BY_BUS:
			target_desc = FuseLocalization.translate_format("FUSE_INSTRUCTION_PAUSE_RESUME_AUDIO_DESC_BUS", {"bus": bus})
		TargetMode.BY_NAME_PATTERN:
			target_desc = FuseLocalization.translate_format("FUSE_INSTRUCTION_PAUSE_RESUME_AUDIO_DESC_NAME", {"name": name_pattern})
		TargetMode.ALL_PLAYING:
			target_desc = FuseLocalization.translate("FUSE_INSTRUCTION_PAUSE_RESUME_AUDIO_DESC_ALL")

	return FuseLocalization.translate_format("FUSE_INSTRUCTION_PAUSE_RESUME_AUDIO_DESC_ACTION_TARGET", {"action": action_str, "target": target_desc})
