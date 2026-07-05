# JuicyTimelineResource - Timeline系统核心资源类
# 作为Timeline系统的主要配置入口，管理多种类型的轨道和参数
# 为JuicyTimelineDriver提供必要的配置数据

@tool
class_name JuicyTimelineResource
extends JuicyFeedbackResource

# 循环模式枚举
enum LoopMode {
	NO_LOOP,        # 无循环
	LOOP,           # 循环
	PING_PONG        # 往返
}

# 轨道数组 - 管理多种类型的轨道

# 用户可见的统一轨道数组（序列化到 .tres 文件）
@export var timeline_tracks: Array[JuicyTrack] = []

# 内部轨道分组（运行时使用，不序列化）
@export_storage var _property_tracks: Array[JuicyPropertyTrack] = []
@export_storage var _feedback_tracks: Array[JuicyFeedbackTrack] = []
@export_storage var _method_tracks: Array[JuicyMethodTrack] = []
@export_storage var _event_tracks: Array[JuicyEventTrack] = []

# 同步状态标志（防止循环同步）
var _is_syncing: bool = false

# 时间轴配置
var auto_calculate_duration: bool = true    # 是否自动计算时长（根据所有Track的最大结束时间）
var timeline_duration: float = 5.0        # 时间轴总时长（仅在auto_calculate_duration=false时有效）
var loop_mode: LoopMode = LoopMode.NO_LOOP  # 循环模式
var loop_count: int = 0                   # 循环次数（0为无限）
var time_scale: float = 1.0               # 时间缩放

# 参数预设系统
@export var input_parameters: Array[String] = []   # 输入参数定义
@export var parameter_presets: Dictionary = {}    # 参数预设字典

# 编辑器支持
signal zoom_changed(new_zoom: float)  # 缩放变化信号

var _timeline_zoom: float = 1.0  # 内部存储
var timeline_zoom: float = 1.0:
	set(value):
		if _timeline_zoom != value:
			_timeline_zoom = value
			zoom_changed.emit(value)
	get:
		return _timeline_zoom

var snap_enabled: bool = true             # 吸附启用
var snap_step: float = 0.1                # 吸附步长

# 描述信息
@export var description: String = ""              # 时间轴描述

# 初始化
func _init():
	duration = timeline_duration

func _notification(what: int) -> void:
	"""处理 Godot 通知"""
	match what:
		NOTIFICATION_POSTINITIALIZE:
			# 🔥 资源加载完成后自动计算时长
			if auto_calculate_duration:
				call_deferred("recalculate_duration")

# 同步机制：将统一的 timeline_tracks 同步到类型分组数组
## 将统一的 timeline_tracks 同步到类型分组数组
func _sync_timeline_tracks_to_groups(tracks: Array[JuicyTrack]) -> void:
	"""
	将统一的 timeline_tracks 同步到类型分组数组

	@param tracks: 统一的轨道数组
	"""
	# 清空分组数组
	_property_tracks.clear()
	_feedback_tracks.clear()
	_method_tracks.clear()
	_event_tracks.clear()

	# 按类型分配轨道
	for track in tracks:
		if not track:
			continue

		match track.get_track_type():
			"Property":
				if track is JuicyPropertyTrack:
					_property_tracks.append(track)
			"Feedback":
				if track is JuicyFeedbackTrack:
					_feedback_tracks.append(track)
			"Method":
				if track is JuicyMethodTrack:
					_method_tracks.append(track)
			"Event":
				if track is JuicyEventTrack:
					_event_tracks.append(track)

## 将类型分组数组同步回统一的 timeline_tracks
func _sync_groups_to_timeline_tracks() -> void:
	"""
	将类型分组数组同步回统一的 timeline_tracks
	（当内部修改分组数组时调用）
	"""
	if _is_syncing:
		return

	_is_syncing = true

	# 合并所有分组数组到统一数组
	timeline_tracks.clear()
	timeline_tracks.append_array(_property_tracks)
	timeline_tracks.append_array(_feedback_tracks)
	timeline_tracks.append_array(_method_tracks)
	timeline_tracks.append_array(_event_tracks)

	_is_syncing = false

	# 触发变化信号
	emit_changed()

# 实现JuicyFeedbackResource的抽象方法
func create_drivers() -> Array:
	"""
	创建Timeline驱动器
	
	@return: 包含JuicyTimelineDriver实例的数组
	"""
	# 创建Timeline驱动器
	var driver = JuicyTimelineDriver.new()
	driver.timeline_resource = self
	return [driver]

func get_duration() -> float:
	"""
	获取时间轴实际时长
	
	@return: 时长（秒）
	"""
	return timeline_duration

func get_data_count() -> int:
	"""
	获取数据数量（Timeline不使用数据系统）
	
	@return: 数据数量
	"""
	return 0

func get_data_at(index: int) -> JuicyFeedbackData:
	"""
	获取指定索引的数据（Timeline不使用数据系统）
	
	@param index: 数据索引
	@return: 数据实例
	"""
	return null

func set_data_at(index: int, source: JuicyFeedbackData) -> void:
	"""
	设置指定索引的数据（Timeline不使用数据系统）
	
	@param index: 数据索引
	@param source: 数据源
	"""
	pass

func get_data() -> Array[JuicyFeedbackData]:
	"""
	获取数据数组（Timeline不使用数据系统）
	
	@return: 数据数组
	"""
	return []

# 轨道管理功能
func add_track(track: JuicyTrack, track_type: String = "") -> bool:
	"""
	添加轨道到时间轴

	@param track: 要添加的轨道
	@param track_type: 轨道类型（可选，如果不提供则自动检测）
	@return: 是否成功添加
	"""
	if not track:
		return false

	# 自动检测轨道类型
	if track_type.is_empty():
		track_type = track.get_track_type()

	# 添加到统一的 timeline_tracks
	_is_syncing = true  # 临时禁用同步
	timeline_tracks.append(track)
	_is_syncing = false

	# 同步到分组数组
	_sync_timeline_tracks_to_groups(timeline_tracks)

	# 自动重新计算时长
	if auto_calculate_duration:
		recalculate_duration()

	return true

func remove_track(track: JuicyTrack) -> bool:
	"""
	从时间轴移除轨道

	@param track: 要移除的轨道
	@return: 是否成功移除
	"""
	if not track:
		print("[TimelineResource] remove_track: ERROR - track is null")
		return false

	print("[TimelineResource] remove_track: Removing '", track.track_name, "'")

	# 从统一数组中移除
	var index = timeline_tracks.find(track)
	if index >= 0:
		_is_syncing = true
		timeline_tracks.remove_at(index)
		_is_syncing = false

		# 同步到分组数组
		_sync_timeline_tracks_to_groups(timeline_tracks)

		# 自动重新计算时长
		if auto_calculate_duration:
			recalculate_duration()

		print("[TimelineResource] remove_track: Result=true")
		return true

	print("[TimelineResource] remove_track: Result=false (track not found)")
	return false

func remove_track_at(index: int, track_type: String = "") -> bool:
	"""
	从统一数组中移除指定索引的轨道

	@param index: 轨道索引（在统一数组中的索引）
	@param track_type: 轨道类型（保留参数以保持兼容性，但不再使用）
	@return: 是否成功移除
	"""
	if index >= 0 and index < timeline_tracks.size():
		var track = timeline_tracks[index]
		return remove_track(track)  # 复用 remove_track 逻辑

	return false

func get_all_tracks() -> Array[JuicyTrack]:
	"""
	获取所有轨道

	@return: 所有轨道的数组
	"""
	# 直接返回 timeline_tracks 的副本（已包含所有轨道）
	return timeline_tracks.duplicate()

func get_tracks_by_type(track_type: String) -> Array[JuicyTrack]:
	"""
	按类型获取轨道

	@param track_type: 轨道类型
	@return: 指定类型的轨道数组
	"""
	match track_type:
		"Property":
			var result: Array[JuicyTrack] = []
			result.append_array(_property_tracks)
			return result
		"Feedback":
			var result: Array[JuicyTrack] = []
			result.append_array(_feedback_tracks)
			return result
		"Method":
			var result: Array[JuicyTrack] = []
			result.append_array(_method_tracks)
			return result
		"Event":
			var result: Array[JuicyTrack] = []
			result.append_array(_event_tracks)
			return result
		_:
			return []

## 向后兼容：按类型获取轨道（返回副本）
func get_property_tracks() -> Array[JuicyPropertyTrack]:
	return _property_tracks.duplicate()

func get_feedback_tracks() -> Array[JuicyFeedbackTrack]:
	return _feedback_tracks.duplicate()

func get_method_tracks() -> Array[JuicyMethodTrack]:
	return _method_tracks.duplicate()

func get_event_tracks() -> Array[JuicyEventTrack]:
	return _event_tracks.duplicate()

func move_track(track: JuicyTrack, new_index: int, track_type: String = "") -> bool:
	"""
	移动轨道到新位置（在统一数组中）

	@param track: 要移动的轨道
	@param new_index: 新索引位置（在统一数组中的索引）
	@param track_type: 轨道类型（保留参数以保持兼容性，但不再使用）
	@return: 是否成功移动
	"""
	if not track:
		return false

	var current_index = timeline_tracks.find(track)
	if current_index == -1:
		return false

	# 调整索引范围
	new_index = clamp(new_index, 0, timeline_tracks.size() - 1)

	# 移除并插入到新位置
	_is_syncing = true
	timeline_tracks.remove_at(current_index)
	timeline_tracks.insert(new_index, track)
	_is_syncing = false

	# 同步到分组数组
	_sync_timeline_tracks_to_groups(timeline_tracks)

	return true

func set_track_enabled(track: JuicyTrack, enabled: bool) -> bool:
	"""
	设置轨道启用状态
	
	@param track: 目标轨道
	@param enabled: 启用状态
	@return: 是否成功设置
	"""
	if not track:
		return false
	
	track.enabled = enabled
	return true

func set_track_muted(track: JuicyTrack, muted: bool) -> bool:
	"""
	设置轨道静音状态
	
	@param track: 目标轨道
	@param muted: 静音状态
	@return: 是否成功设置
	"""
	if not track:
		return false
	
	track.muted = muted
	return true

# 时间轴配置功能
func calculate_timeline_duration() -> float:
	"""
	计算所有Track的最大结束时间
	
	@return: 最大结束时间（秒）
	"""
	var max_end_time = 0.0
	
	# 遍历所有轨道，找到最大结束时间
	for track in get_all_tracks():
		if not track:
			continue
		
		var end_time = track.get_end_time()
		if end_time > max_end_time:
			max_end_time = end_time
	
	# 确保最小时长为1秒
	return max(1.0, max_end_time)

func recalculate_duration() -> void:
	"""
	重新计算时间轴时长（仅当auto_calculate_duration=true时有效）
	"""
	if not auto_calculate_duration:
		return

	var new_duration = calculate_timeline_duration()
	if abs(new_duration - timeline_duration) > 0.001:
		timeline_duration = new_duration
		emit_changed()

func get_total_duration() -> float:
	"""
	计算总时长（考虑循环）
	
	@return: 总时长（秒）
	"""
	if loop_mode == LoopMode.NO_LOOP or loop_count == 0:
		# 如果启用自动计算，实时计算
		if auto_calculate_duration:
			return calculate_timeline_duration()
		return timeline_duration
	
	# 考虑循环
	var single_loop_duration = calculate_timeline_duration() if auto_calculate_duration else timeline_duration
	return single_loop_duration * loop_count

func set_loop_mode(mode: LoopMode, count: int = 0) -> void:
	"""
	设置循环模式
	
	@param mode: 循环模式
	@param count: 循环次数（0为无限）
	"""
	loop_mode = mode
	loop_count = count

func is_looping() -> bool:
	"""
	检查是否启用循环
	
	@return: 是否循环
	"""
	return loop_mode != LoopMode.NO_LOOP and loop_count != 1

# 参数预设系统
func add_parameter_preset(name: String, values: Dictionary) -> bool:
	"""
	添加参数预设
	
	@param name: 预设名称
	@param values: 参数值字典
	@return: 是否成功添加
	"""
	if name.is_empty():
		return false
	
	parameter_presets[name] = values.duplicate()
	return true

func remove_parameter_preset(name: String) -> bool:
	"""
	移除参数预设
	
	@param name: 预设名称
	@return: 是否成功移除
	"""
	if parameter_presets.has(name):
		parameter_presets.erase(name)
		return true
	return false

func apply_parameter_preset(name: String, context: JuicyContext) -> bool:
	"""
	应用参数预设到上下文
	
	@param name: 预设名称
	@param context: JuicyContext实例
	@return: 是否成功应用
	"""
	if not parameter_presets.has(name):
		return false
	
	var preset = parameter_presets[name]
	for param_name in preset:
		context.set_parameter(param_name, preset[param_name])
	
	return true

func get_parameter_preset_names() -> Array[String]:
	"""
	获取所有参数预设名称
	
	@return: 预设名称数组
	"""
	var names: Array[String] = []
	for name in parameter_presets.keys():
		names.append(name)
	return names

# 验证机制
func validate_config() -> ValidationResult:
	"""
	验证时间轴配置
	
	@return: 验证结果
	"""
	var result = super.validate_config()
	
	# 验证时间轴配置
	if timeline_duration <= 0:
		result.valid = false
		result.issues.append("Timeline duration must be greater than 0")
	
	if time_scale <= 0:
		result.valid = false
		result.issues.append("Time scale must be greater than 0")
	
	if loop_count < 0:
		result.valid = false
		result.issues.append("Loop count cannot be negative")
	
	if snap_step <= 0:
		result.valid = false
		result.issues.append("Snap step must be greater than 0")
	
	# 验证轨道配置
	var track_validation = _validate_all_tracks()
	if not track_validation.is_empty():
		result.valid = false
		result.issues.append_array(track_validation)
	
	# 验证参数预设
	var preset_validation = _validate_parameter_presets()
	if not preset_validation.is_empty():
		result.valid = false
		result.issues.append_array(preset_validation)
	
	return result

func _validate_all_tracks() -> Array[String]:
	"""
	验证所有轨道配置

	@return: 错误信息数组
	"""
	var errors: Array[String] = []

	# 验证统一数组中的所有轨道
	for i in range(timeline_tracks.size()):
		var track = timeline_tracks[i]
		if not track:
			errors.append("Track at index " + str(i) + " cannot be null")
			continue

		var track_error = track.validate_track()
		if not track_error.is_empty():
			errors.append("Track at index " + str(i) + " (" + track.get_track_type() + "): " + track_error)

	return errors

func _validate_parameter_presets() -> Array[String]:
	"""
	验证参数预设配置
	
	@return: 错误信息数组
	"""
	var errors: Array[String] = []
	
	for preset_name in parameter_presets:
		var preset = parameter_presets[preset_name]
		if not preset is Dictionary:
			errors.append("Parameter preset '" + preset_name + "' must be a dictionary")
			continue
		
		# 验证预设中的参数是否在输入参数定义中
		for param_name in preset:
			if param_name not in input_parameters:
				errors.append("Parameter '" + param_name + "' in preset '" + preset_name + "' is not defined in input parameters")
	
	return errors

# 实用方法
func get_description() -> String:
	"""
	获取时间轴描述信息
	
	@return: 描述字符串
	"""
	var desc = "JuicyTimelineResource: "
	desc += "duration=%.2fs, " % timeline_duration
	desc += "tracks=%d, " % get_all_tracks().size()
	desc += "loop_mode=%s, " % LoopMode.keys()[loop_mode]
	
	if loop_count > 0:
		desc += "loop_count=%d, " % loop_count
	else:
		desc += "infinite_loop, "
	
	desc += "time_scale=%.2f" % time_scale
	
	if not description.is_empty():
		desc += " (%s)" % description
	
	return desc

func clone() -> JuicyTimelineResource:
	"""
	克隆时间轴资源

	@return: 克隆的时间轴资源实例
	"""
	var cloned_timeline = JuicyTimelineResource.new()

	# 复制基础属性
	cloned_timeline.timeline_duration = timeline_duration
	cloned_timeline.loop_mode = loop_mode
	cloned_timeline.loop_count = loop_count
	cloned_timeline.time_scale = time_scale
	cloned_timeline.input_parameters = input_parameters.duplicate()
	cloned_timeline.parameter_presets = parameter_presets.duplicate()
	cloned_timeline.timeline_zoom = timeline_zoom
	cloned_timeline.snap_enabled = snap_enabled
	cloned_timeline.snap_step = snap_step
	cloned_timeline.description = description

	# 克隆轨道（从 timeline_tracks 克隆）
	cloned_timeline.timeline_tracks.clear()
	for track in timeline_tracks:
		if track and track.has_method("clone"):
			cloned_timeline.timeline_tracks.append(track.clone())

	# 同步到分组数组（在 cloned_timeline 中）
	cloned_timeline._sync_timeline_tracks_to_groups(cloned_timeline.timeline_tracks)

	return cloned_timeline

# 序列化支持
func get_config_dict() -> Dictionary:
	"""
	获取配置字典（用于序列化）

	@return: 配置字典
	"""
	var config = super.get_config_dict()

	# 时间轴配置
	config["auto_calculate_duration"] = auto_calculate_duration
	config["timeline_duration"] = timeline_duration
	config["loop_mode"] = LoopMode.keys()[loop_mode]
	config["loop_count"] = loop_count
	config["time_scale"] = time_scale

	# 参数预设
	config["input_parameters"] = input_parameters
	config["parameter_presets"] = parameter_presets

	# 编辑器配置
	config["timeline_zoom"] = timeline_zoom
	config["snap_enabled"] = snap_enabled
	config["snap_step"] = snap_step
	config["description"] = description

	# 轨道数据（序列化 timeline_tracks，不序列化分组数组）
	config["timeline_tracks"] = []
	for track in timeline_tracks:
		if track and track.has_method("get_config_dict"):
			config["timeline_tracks"].append(track.get_config_dict())

	return config

func load_from_dict(config_dict: Dictionary) -> bool:
	"""
	从配置字典加载

	@param config_dict: 配置字典
	@return: 是否成功加载
	"""
	if not super.load_from_dict(config_dict):
		return false

	# 加载时间轴配置
	if config_dict.has("auto_calculate_duration"):
		auto_calculate_duration = config_dict["auto_calculate_duration"]
	if config_dict.has("timeline_duration"):
		timeline_duration = config_dict["timeline_duration"]
	if config_dict.has("loop_mode"):
		var mode_name = config_dict["loop_mode"]
		for i in range(LoopMode.values().size()):
			if LoopMode.keys()[i] == mode_name:
				loop_mode = LoopMode.values()[i]
				break
	if config_dict.has("loop_count"):
		loop_count = config_dict["loop_count"]
	if config_dict.has("time_scale"):
		time_scale = config_dict["time_scale"]

	# 加载参数预设
	if config_dict.has("input_parameters"):
		input_parameters = config_dict["input_parameters"]
	if config_dict.has("parameter_presets"):
		parameter_presets = config_dict["parameter_presets"]

	# 加载编辑器配置
	if config_dict.has("timeline_zoom"):
		timeline_zoom = config_dict["timeline_zoom"]
	if config_dict.has("snap_enabled"):
		snap_enabled = config_dict["snap_enabled"]
	if config_dict.has("snap_step"):
		snap_step = config_dict["snap_step"]
	if config_dict.has("description"):
		description = config_dict["description"]

	# 🔧 向后兼容：检测旧格式并迁移
	if config_dict.has("property_tracks") or config_dict.has("feedback_tracks"):
		_migrate_legacy_format(config_dict)
	# 新格式：加载统一轨道数组
	elif config_dict.has("timeline_tracks"):
		timeline_tracks.clear()
		for track_dict in config_dict["timeline_tracks"]:
			var track = _create_track_from_dict(track_dict)
			if track:
				timeline_tracks.append(track)

		# 同步到分组数组
		_sync_timeline_tracks_to_groups(timeline_tracks)

	# 加载完成后自动计算时长
	if auto_calculate_duration:
		recalculate_duration()

	return true

## 从旧格式迁移（property_tracks, feedback_tracks, etc.）
func _migrate_legacy_format(config_dict: Dictionary) -> void:
	"""
	从旧格式迁移（property_tracks, feedback_tracks, etc.）
	"""
	print("[TimelineResource] 检测到旧格式资源，开始迁移...")

	timeline_tracks.clear()

	# 迁移 property_tracks
	if config_dict.has("property_tracks"):
		for track_dict in config_dict["property_tracks"]:
			var track = _create_track_from_dict(track_dict, "Property")
			if track:
				timeline_tracks.append(track)

	# 迁移 feedback_tracks
	if config_dict.has("feedback_tracks"):
		for track_dict in config_dict["feedback_tracks"]:
			var track = _create_track_from_dict(track_dict, "Feedback")
			if track:
				timeline_tracks.append(track)

	# 迁移 method_tracks
	if config_dict.has("method_tracks"):
		for track_dict in config_dict["method_tracks"]:
			var track = _create_track_from_dict(track_dict, "Method")
			if track:
				timeline_tracks.append(track)

	# 迁移 event_tracks
	if config_dict.has("event_tracks"):
		for track_dict in config_dict["event_tracks"]:
			var track = _create_track_from_dict(track_dict, "Event")
			if track:
				timeline_tracks.append(track)

	# 同步到分组数组
	_sync_timeline_tracks_to_groups(timeline_tracks)

	print("[TimelineResource] 迁移完成，共 %d 条轨道" % timeline_tracks.size())

	# 🔥 自动保存迁移后的资源
	if Engine.is_editor_hint():
		call_deferred("_save_migrated_resource")

## 保存迁移后的资源
func _save_migrated_resource() -> void:
	"""
	自动保存迁移后的资源
	"""
	var save_path = resource_path
	if not save_path.is_empty():
		var result = ResourceSaver.save(self, save_path)
		if result == OK:
			print("[TimelineResource] ✅ 已自动保存迁移后的资源: ", save_path)
		else:
			push_error("[TimelineResource] ❌ 保存迁移后的资源失败: ", result)

## 从字典创建轨道
func _create_track_from_dict(track_dict: Dictionary, track_type: String = "") -> JuicyTrack:
	"""
	从字典创建轨道实例

	@param track_dict: 轨道配置字典
	@param track_type: 轨道类型（如果不提供则从字典读取）
	@return: 轨道实例
	"""
	if not track_dict.has("track_type"):
		# 尝试从字典推断类型
		if track_dict.has("target_path"):
			track_type = "Property"
		elif track_dict.has("feedback_name"):
			track_type = "Feedback"
		elif track_dict.has("method_name"):
			track_type = "Method"
		elif track_dict.has("event_name"):
			track_type = "Event"
		else:
			return null

	var type = track_type if not track_type.is_empty() else track_dict.get("track_type", "")
	var track: JuicyTrack

	match type:
		"Property":
			track = JuicyPropertyTrack.new()
		"Feedback":
			track = JuicyFeedbackTrack.new()
		"Method":
			track = JuicyMethodTrack.new()
		"Event":
			track = JuicyEventTrack.new()
		_:
			return null

	if track and track.has_method("load_from_dict"):
		track.load_from_dict(track_dict)

	return track

# 编辑器支持
func _get_property_list() -> Array[Dictionary]:
	var properties = super._get_property_list()
	
	# 时间轴配置组
	properties.append({
		"name": "Timeline Configuration",
		"type": TYPE_NIL,
		"hint": PROPERTY_HINT_NONE,
		"usage": PROPERTY_USAGE_GROUP
	})
	
	# 自动计算时长
	properties.append({
		"name": "auto_calculate_duration",
		"type": TYPE_BOOL,
		"hint": PROPERTY_HINT_NONE,
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
	})
	
	# 时间轴时长（仅在auto_calculate_duration=false时可编辑）
	properties.append({
		"name": "timeline_duration",
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0.1,3600,0.1,or_greater",
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
	})
	
	# 循环模式
	properties.append({
		"name": "loop_mode",
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "No Loop:0,Loop:1,Ping Pong:2",
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
	})
	
	# 循环次数
	properties.append({
		"name": "loop_count",
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0,1000,1",
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
	})
	
	# 时间缩放
	properties.append({
		"name": "time_scale",
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0.01,10.0,0.01",
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
	})
	
	# 吸附设置
	properties.append({
		"name": "snap_enabled",
		"type": TYPE_BOOL,
		"hint": PROPERTY_HINT_NONE,
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
	})
	
	properties.append({
		"name": "snap_step",
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0.01,1.0,0.01",
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
	})
	
	# 添加重新计算时长按钮（仅在编辑器中使用）
	properties.append({
		"name": "recalculate_duration",
		"type": TYPE_NIL,
		"hint": PROPERTY_HINT_NONE,
		"usage": PROPERTY_USAGE_EDITOR,
		"hint_string": "Recalculate Duration"
	})
	
	# 轨道管理组
	properties.append({
		"name": "Track Management",
		"type": TYPE_NIL,
		"hint": PROPERTY_HINT_NONE,
		"usage": PROPERTY_USAGE_GROUP
	})
	
	# 参数预设组
	properties.append({
		"name": "Parameter Presets",
		"type": TYPE_NIL,
		"hint": PROPERTY_HINT_NONE,
		"usage": PROPERTY_USAGE_GROUP
	})
	
	# 编辑器设置组
	properties.append({
		"name": "Editor Settings",
		"type": TYPE_NIL,
		"hint": PROPERTY_HINT_NONE,
		"usage": PROPERTY_USAGE_GROUP
	})
	
	return properties

func _property_can_revert(property_name: StringName) -> bool:
	match property_name:
		"auto_calculate_duration":
			return true
		"timeline_duration":
			return true
		"loop_mode":
			return true
		"loop_count":
			return true
		"time_scale":
			return true
		"timeline_zoom":
			return true
		"snap_enabled":
			return true
		"snap_step":
			return true
		_:
			return false

func _property_get_revert(property_name: StringName):
	match property_name:
		"auto_calculate_duration":
			return true
		"timeline_duration":
			return 5.0
		"loop_mode":
			return LoopMode.NO_LOOP
		"loop_count":
			return 0
		"time_scale":
			return 1.0
		"timeline_zoom":
			return 1.0
		"snap_enabled":
			return true
		"snap_step":
			return 0.1
		_:
			return null

func _set(property_name: StringName, value: Variant) -> bool:
	"""
	处理属性设置（支持编辑器按钮）

	@param property_name: 属性名称
	@param value: 属性值
	@return: 是否成功设置
	"""
	# 处理编辑器按钮点击
	if property_name == "recalculate_duration":
		recalculate_duration()
		return true

	# 其他属性使用默认处理
	return false

