class_name MusicEventHandler
extends JuicyEventHandler

## 音乐事件处理器
##
## 专门处理音乐事件的 Handler
## 注册到 EventHandlingMiddleware（优先级：10，高于音效的0）

# =============================================================================
# MusicManager 引用
# =============================================================================

var music_manager: MusicManager

# =============================================================================
# 事件类型定义
# =============================================================================

const EVENT_MUSIC_PLAY: String = "MUSIC_PLAY"
const EVENT_MUSIC_STOP: String = "MUSIC_STOP"
const EVENT_MUSIC_CROSSFADE: String = "MUSIC_CROSSFADE"
const EVENT_MUSIC_ADD_LAYER: String = "MUSIC_ADD_LAYER"
const EVENT_MUSIC_REMOVE_LAYER: String = "MUSIC_REMOVE_LAYER"
const EVENT_MUSIC_PAUSE_SNAPSHOT: String = "MUSIC_PAUSE_SNAPSHOT"
const EVENT_MUSIC_NORMAL_SNAPSHOT: String = "MUSIC_NORMAL_SNAPSHOT"

# =============================================================================
# 初始化
# =============================================================================

func _init():
	handler_name = "MusicEventHandler"
	supported_events = [
		EVENT_MUSIC_PLAY,
		EVENT_MUSIC_STOP,
		EVENT_MUSIC_CROSSFADE,
		EVENT_MUSIC_ADD_LAYER,
		EVENT_MUSIC_REMOVE_LAYER,
		EVENT_MUSIC_PAUSE_SNAPSHOT,
		EVENT_MUSIC_NORMAL_SNAPSHOT
	]
	description = "处理音乐播放、停止、过渡和层管理事件"

# =============================================================================
# JuicyEventHandler 接口实现
# =============================================================================

func handle_event(event) -> bool:
	"""处理音乐事件"""
	if not can_handle(event):
		return false

	if not music_manager:
		_log_error("MusicManager 未设置")
		return false

	var start_time = _start_handling_timer()

	# 处理不同类型的事件
	match event.event_type:
		EVENT_MUSIC_PLAY:
			_handle_music_play(event)
		EVENT_MUSIC_STOP:
			_handle_music_stop(event)
		EVENT_MUSIC_CROSSFADE:
			_handle_crossfade(event)
		EVENT_MUSIC_ADD_LAYER:
			_handle_add_layer(event)
		EVENT_MUSIC_REMOVE_LAYER:
			_handle_remove_layer(event)
		EVENT_MUSIC_PAUSE_SNAPSHOT:
			_handle_pause_snapshot(event)
		EVENT_MUSIC_NORMAL_SNAPSHOT:
			_handle_normal_snapshot(event)
		_:
			_log_warning("未知事件类型: %s" % event.event_type)
			_end_handling_timer(start_time)
			return false

	_end_handling_timer(start_time)
	_record_success()
	return true

# =============================================================================
# 事件处理实现
# =============================================================================

func _handle_music_play(event: JuicyEvent) -> void:
	"""处理音乐播放事件"""
	var track: MusicTrackResource = event.event_data.get("track_resource")
	if not track:
		_log_error("MUSIC_PLAY 事件缺少 track_resource")
		return

	var fade_in_time: float = event.event_data.get("fade_in_time", 0.0)
	var persistence_key: String = event.event_data.get("persistence_key", "")

	music_manager.play_music(track, fade_in_time, persistence_key)

func _handle_music_stop(event: JuicyEvent) -> void:
	"""处理音乐停止事件"""
	var fade_out_time: float = event.event_data.get("fade_out_time", 0.0)
	music_manager.stop_music(fade_out_time)

func _handle_crossfade(event: JuicyEvent) -> void:
	"""处理交叉淡入淡出事件"""
	var new_track: MusicTrackResource = event.event_data.get("track_resource")
	if not new_track:
		_log_error("MUSIC_CROSSFADE 事件缺少 track_resource")
		return

	var fade_time: float = event.event_data.get("fade_time", 1.0)
	music_manager.crossfade_to(new_track, fade_time)

func _handle_add_layer(event: JuicyEvent) -> void:
	"""处理添加音乐层事件"""
	var layer: MusicLayerResource = event.event_data.get("layer_resource")
	if not layer:
		_log_error("MUSIC_ADD_LAYER 事件缺少 layer_resource")
		return

	var fade_in_time: float = event.event_data.get("fade_in_time", 0.0)
	music_manager.add_music_layer(layer, fade_in_time)

func _handle_remove_layer(event: JuicyEvent) -> void:
	"""处理移除音乐层事件"""
	var layer_id: String = event.event_data.get("layer_id", "")
	var fade_out_time: float = event.event_data.get("fade_out_time", 0.0)

	if layer_id.is_empty():
		_log_error("MUSIC_REMOVE_LAYER 事件缺少 layer_id")
		return

	music_manager.remove_music_layer(layer_id, fade_out_time)

func _handle_pause_snapshot(event: JuicyEvent) -> void:
	"""处理暂停快照事件"""
	music_manager.apply_pause_snapshot()

func _handle_normal_snapshot(event: JuicyEvent) -> void:
	"""处理正常快照事件"""
	music_manager.apply_normal_snapshot()

# =============================================================================
# 生命周期钩子
# =============================================================================

func on_handler_registered() -> void:
	"""处理器注册时调用"""
	_log_debug("MusicEventHandler 已注册")

func on_handler_unregistered() -> void:
	"""处理器注销时调用"""
	_log_debug("MusicEventHandler 已注销")

func cleanup() -> void:
	"""清理处理器状态"""
	music_manager = null
