@tool
class_name MusicStateMap
extends Resource

## 音乐状态映射资源
##
## 将游戏状态名称映射到对应的音乐轨道资源
## 用于 MusicPlayer 的状态查找

# =============================================================================
# 状态映射
# =============================================================================

@export_group("State Mapping", "state_")
## 状态映射表：StringName → MusicTrackResource
## 键是状态名称（如 &"exploring", &"combat"）
## 值是对应的音乐轨道资源
@export var state_map: Dictionary[StringName, MusicTrackResource] = {}

# 示例配置（在 Inspector 中可见）：
# state_map = {
#     &"menu": null,
#     &"exploring": null,
#     &"combat": null,
#     &"boss": null,
#     &"victory": null
# }

# =============================================================================
# 初始化
# =============================================================================

func _init():
	resource_local_to_scene = false  # 可跨场景共享

# =============================================================================
# 公共 API
# =============================================================================

## 获取指定状态的音乐轨道
func get_track(state: StringName) -> MusicTrackResource:
	"""
	获取指定状态对应的音乐轨道

	@param state: 状态名称（如 &"exploring"）
	@return: 对应的 MusicTrackResource，如果不存在返回 null
	"""
	if state_map.is_empty():
		push_warning("[MusicStateMap] 状态映射表为空")
		return null

	if not state_map.has(state):
		push_warning("[MusicStateMap] 未找到状态: '%s'" % state)
		return null

	return state_map[state] as MusicTrackResource

## 检查是否包含指定状态
func has_state(state: StringName) -> bool:
	"""检查映射表中是否包含指定状态"""
	return state_map.has(state)

## 获取所有状态名称
func get_all_states() -> Array[StringName]:
	"""获取映射表中所有的状态名称"""
	var states: Array[StringName] = []
	for key in state_map.keys():
		if key is StringName:
			states.append(key as StringName)
	return states

## 注册或更新状态
func register_state(state: StringName, track: MusicTrackResource) -> void:
	"""
	注册或更新一个状态映射

	@param state: 状态名称
	@param track: 音乐轨道资源
	"""
	state_map[state] = track
	emit_changed()

## 移除状态
func unregister_state(state: StringName) -> void:
	"""
	移除一个状态映射

	@param state: 要移除的状态名称
	"""
	if state_map.has(state):
		state_map.erase(state)
		emit_changed()

## 清空所有状态
func clear() -> void:
	"""清空所有状态映射"""
	state_map.clear()
	emit_changed()

## 获取状态数量
func get_state_count() -> int:
	"""获取映射表中的状态数量"""
	return state_map.size()

# =============================================================================
# 验证
# =============================================================================

## 验证配置
func validate() -> Dictionary:
	"""
	验证状态映射配置的有效性

	@return: 包含 valid, issues, warnings 的字典
	"""
	var issues: Array[String] = []
	var warnings: Array[String] = []

	if state_map.is_empty():
		warnings.append("状态映射表为空")

	# 检查所有音乐轨道资源
	for state in state_map:
		var track = state_map[state]
		if not track or not track is MusicTrackResource:
			issues.append("状态 '%s' 的值不是有效的 MusicTrackResource" % state)
		elif track is MusicTrackResource:
			var track_validation = track.validate()
			if not track_validation.valid:
				for issue in track_validation.issues:
					issues.append("状态 '%s': %s" % [state, issue])
			for warning in track_validation.warnings:
				warnings.append("状态 '%s': %s" % [state, warning])

	return {
		"valid": issues.is_empty(),
		"issues": issues,
		"warnings": warnings
	}

# =============================================================================
# 工具方法
# =============================================================================

## 获取状态信息（用于调试）
func get_state_info() -> String:
	"""获取所有状态的详细信息（调试用）"""
	if state_map.is_empty():
		return "状态映射表为空"

	var info: String = ""
	info += "状态映射表 (%d 个状态):\n" % state_map.size()

	for state in state_map:
		var track = state_map[state]
		var track_name = "null"
		if track is MusicTrackResource:
			track_name = track.resource_path.get_file()
		info += "  - %s → %s\n" % [state, track_name]

	return info

## 从字典加载状态
func load_from_dict(dict: Dictionary) -> void:
	"""
	从字典加载状态映射

	@param dict: 状态映射字典 {StringName: MusicTrackResource}
	"""
	state_map = dict.duplicate()
	emit_changed()

## 导出为字典
func to_dict() -> Dictionary:
	"""
	导出状态映射为字典

	@return: 状态映射字典的副本
	"""
	return state_map.duplicate()
# =============================================================================
# 字符串表示
# =============================================================================

func _to_string() -> String:
	return "MusicStateMap (%d states)" % state_map.size()
