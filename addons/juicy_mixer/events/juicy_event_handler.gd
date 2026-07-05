class_name JuicyEventHandler
extends RefCounted

# 处理器元信息
var handler_name: String = ""
var handler_version: String = "1.0.0"
var supported_events: Array = []  # Array[JuicyEvent.EventType]
var enabled: bool = true
var description: String = ""

# 性能统计
var _events_handled: int = 0
var _events_failed: int = 0
var _total_handling_time: float = 0.0
var _last_handling_time: float = 0.0

# 核心接口 - 子类必须实现
func can_handle(event) -> bool:
	"""检查是否可以处理指定事件"""
	if not event:
		return false
	return event.event_type in supported_events

func handle_event(event) -> bool:
	"""处理事件，子类必须实现"""
	push_error("handle_event() must be implemented by subclass")
	return false

func cleanup() -> void:
	"""清理处理器状态"""
	pass

# 生命周期钩子
func on_handler_registered() -> void:
	"""处理器注册时调用"""
	pass

func on_handler_unregistered() -> void:
	"""处理器注销时调用"""
	pass

func on_event_buffer_cleared() -> void:
	"""事件缓冲区清空时调用"""
	pass

# 验证接口
func validate_event(event) -> Dictionary:
	"""验证事件是否适合此处理器"""
	var result = {
		"valid": true,
		"issues": [],
		"warnings": []
	}
	
	if not event:
		result.valid = false
		result.issues.append("Event is null")
		return result
	
	if not can_handle(event):
		result.valid = false
		result.issues.append("Event type not supported: " + str(event.event_type))
	
	return result

# 配置接口
func configure(config: Dictionary) -> void:
	"""配置处理器参数"""
	for key in config.keys():
		if key in self:
			self.set(key, config[key])

func get_configuration() -> Dictionary:
	"""获取当前配置"""
	return {}

# 性能监控
func get_performance_stats() -> Dictionary:
	return {
		"events_handled": _events_handled,
		"events_failed": _events_failed,
		"success_rate": float(_events_handled) / max(_events_handled + _events_failed, 1),
		"total_handling_time": _total_handling_time,
		"average_handling_time": _total_handling_time / max(_events_handled, 1),
		"last_handling_time": _last_handling_time
	}

func reset_performance_stats() -> void:
	_events_handled = 0
	_events_failed = 0
	_total_handling_time = 0.0
	_last_handling_time = 0.0

# 内部方法
func _start_handling_timer() -> float:
	return Time.get_ticks_usec()

func _end_handling_timer(start_time: float) -> void:
	_last_handling_time = (Time.get_ticks_usec() - start_time) / 1000.0
	_total_handling_time += _last_handling_time

func _record_success() -> void:
	_events_handled += 1

func _record_failure() -> void:
	_events_failed += 1

func _log_debug(message: String) -> void:
	if OS.is_debug_build():
		print("[", handler_name, "] ", message)

func _log_warning(message: String) -> void:
	push_warning("[" + handler_name + "] " + message)

func _log_error(message: String) -> void:
	push_error("[" + handler_name + "] " + message)
	_record_failure()

# 事件创建辅助方法
func _create_audio_play_event(context_id: String, target: Node, audio_stream: AudioStream,
							 position: Vector2 = Vector2.ZERO, volume: float = 1.0):
	"""创建音频播放事件"""
	var event = JuicyEvent.new()
	event.event_type = JuicyEvent.EventType.AUDIO_PLAY
	event.context_id = context_id
	event.target = target
	event.event_data = {
		"audio_stream": audio_stream,
		"position": position,
		"volume": volume
	}
	return event

func _create_interruption_event(context_id: String, target: Node, interruption_type: String,
						 new_context_id: String, existing_context_id: String,
						 policy: JuicyMixerEnums.InterruptionPolicy):
	"""创建中断事件"""
	var event = JuicyEvent.new()
	event.event_type = JuicyEvent.EventType.INTERRUPTION_OCCURRED
	event.context_id = context_id
	event.target = target
	event.event_data = {
		"interruption_type": interruption_type,
		"new_context_id": new_context_id,
		"existing_context_id": existing_context_id,
		"policy": JuicyMixerEnums.get_interruption_policy_name(policy),
		"policy_enum": policy,
		"timestamp": Time.get_ticks_msec() / 1000.0
	}
	return event

func _create_interruption_resolved_event(context_id: String, target: Node,
								  resolution_context_id: String, resolution_type: String):
	"""创建中断解决事件"""
	var event = JuicyEvent.new()
	event.event_type = JuicyEvent.EventType.INTERRUPTION_RESOLVED
	event.context_id = context_id
	event.target = target
	event.event_data = {
		"context_id": resolution_context_id,
		"resolution_type": resolution_type,
		"timestamp": Time.get_ticks_msec() / 1000.0
	}
	return event

func _create_transition_event(context_id: String, target: Node, transition_type: String,
						 transition_context_id: String, from_context_id: String = "",
						 duration: float = 0.0):
	"""创建过渡事件"""
	var event_type = JuicyEvent.EventType.TRANSITION_STARTED if transition_type == "started" else JuicyEvent.EventType.TRANSITION_COMPLETED
	var event = JuicyEvent.new()
	event.event_type = event_type
	event.context_id = context_id
	event.target = target
	event.event_data = {
		"transition_type": transition_type,
		"context_id": transition_context_id,
		"from_context_id": from_context_id,
		"duration": duration,
		"timestamp": Time.get_ticks_msec() / 1000.0
	}
	return event

func _create_particle_spawn_event(context_id: String, target: Node, particle_scene: PackedScene,
							   amount: int = 10, position: Vector2 = Vector2.ZERO):
	"""创建粒子生成事件"""
	var event = JuicyEvent.new()
	event.event_type = JuicyEvent.EventType.PARTICLE_SPAWN
	event.context_id = context_id
	event.target = target
	event.event_data = {
		"particle_scene": particle_scene,
		"amount": amount,
		"position": position
	}
	return event

func _create_ui_update_event(context_id: String, target: Node, property: String, value: Variant):
	"""创建UI更新事件"""
	var event = JuicyEvent.new()
	event.event_type = JuicyEvent.EventType.UI_UPDATE
	event.context_id = context_id
	event.target = target
	event.event_data = {
		"property": property,
		"value": value
	}
	return event
