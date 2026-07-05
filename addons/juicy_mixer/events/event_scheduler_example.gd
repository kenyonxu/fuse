extends Node

# 示例：如何使用JuicyEventScheduler

# 自定义音频事件处理器
class AudioEventHandler:
	extends JuicyEventHandler
	
	func _init():
		handler_name = "AudioEventHandler"
		supported_events = [JuicyEvent.EventType.AUDIO_PLAY, JuicyEvent.EventType.AUDIO_STOP]
		description = "Handles audio playback events"
	
	func handle_event(event) -> bool:
		var start_time = _start_handling_timer()
		
		match event.event_type:
			JuicyEvent.EventType.AUDIO_PLAY:
				return _handle_audio_play(event, start_time)
			JuicyEvent.EventType.AUDIO_STOP:
				return _handle_audio_stop(event, start_time)
			_:
				_log_warning("Unsupported event type: " + str(event.event_type))
				_record_failure()
				return false
	
	func _handle_audio_play(event, start_time) -> bool:
		var audio_stream = event.event_data.get("audio_stream")
		var volume = event.event_data.get("volume", 1.0)
		var position = event.event_data.get("position", Vector2.ZERO)
		
		if not audio_stream:
			_log_error("No audio stream provided")
			return false
		
		# 这里应该实现实际的音频播放逻辑
		print("Playing audio: ", audio_stream.resource_path, " at volume: ", volume)
		
		_end_handling_timer(start_time)
		_record_success()
		return true
	
	func _handle_audio_stop(event, start_time) -> bool:
		var audio_id = event.event_data.get("audio_id")
		
		if not audio_id:
			_log_error("No audio ID provided")
			return false
		
		# 这里应该实现实际的音频停止逻辑
		print("Stopping audio: ", audio_id)
		
		_end_handling_timer(start_time)
		_record_success()
		return true

# 自定义UI事件处理器
class UIEventHandler:
	extends JuicyEventHandler
	
	func _init():
		handler_name = "UIEventHandler"
		supported_events = [JuicyEvent.EventType.UI_UPDATE]
		description = "Handles UI update events"
	
	func handle_event(event) -> bool:
		var start_time = _start_handling_timer()
		
		var property = event.event_data.get("property")
		var value = event.event_data.get("value")
		var target = event.target
		
		if not property or not target:
			_log_error("Missing property or target")
			_record_failure()
			return false
		
		# 这里应该实现实际的UI更新逻辑
		if target.has_method("set_" + property):
			target.call("set_" + property, value)
			print("Updated UI: ", property, " = ", value)
		else:
			_log_warning("Target does not have property: " + property)
		
		_end_handling_timer(start_time)
		_record_success()
		return true

# 示例使用
func _ready():
	print("=== JuicyEventScheduler Usage Example ===")
	
	# 创建事件系统组件
	var scheduler = JuicyEventScheduler.new()
	var buffer = JuicyEventBuffer.new()
	
	# 注册事件处理器
	var audio_handler = AudioEventHandler.new()
	var ui_handler = UIEventHandler.new()
	
	scheduler.register_handler(audio_handler, 100)  # 高优先级
	scheduler.register_handler(ui_handler, 80)     # 中等优先级
	
	# 创建音频播放事件
	var audio_event = JuicyEvent.new()
	audio_event.event_type = JuicyEvent.EventType.AUDIO_PLAY
	audio_event.context_id = "gameplay_sfx"
	audio_event.target = self
	audio_event.priority = 50
	audio_event.event_data = {
		"audio_stream": null,  # 在实际使用中使用有效的音频资源
		"volume": 0.8,
		"position": Vector2(100, 200)
	}
	
	# 创建UI更新事件
	var ui_event = JuicyEvent.new()
	ui_event.event_type = JuicyEvent.EventType.UI_UPDATE
	ui_event.context_id = "hud_update"
	ui_event.target = self
	ui_event.priority = 30
	ui_event.event_data = {
		"property": "text",
		"value": "Score: 1000"
	}
	
	# 添加事件到缓冲区
	buffer.add_event(audio_event)
	buffer.add_event(ui_event)
	
	# 处理事件
	print("\nProcessing events...")
	var processed = scheduler.process_events(buffer, 0.016)
	print("Processed ", processed, " events")
	
	# 查看性能统计
	print("\nPerformance Statistics:")
	var audio_stats = audio_handler.get_performance_stats()
	var ui_stats = ui_handler.get_performance_stats()
	var scheduler_stats = scheduler.get_scheduler_stats()
	
	print("Audio Handler: ", audio_stats)
	print("UI Handler: ", ui_stats)
	print("Scheduler: ", scheduler_stats)
	
	# 调试信息
	print("\nRegistered Handlers:")
	scheduler.debug_print_handlers()
	
	print("\n=== Example completed ===")

# 实际使用场景示例
var _scheduler: JuicyEventScheduler
var _buffer: JuicyEventBuffer
var _audio_handler: AudioEventHandler
var _ui_handler: UIEventHandler

func _init():
	# 初始化事件系统
	_scheduler = JuicyEventScheduler.new()
	_buffer = JuicyEventBuffer.new()
	_audio_handler = AudioEventHandler.new()
	_ui_handler = UIEventHandler.new()
	
	_scheduler.register_handler(_audio_handler, 100)
	_scheduler.register_handler(_ui_handler, 80)

func play_sound_effect(sound_path: String, volume: float = 1.0):
	"""播放音效的事件驱动方法"""
	var event = _audio_handler._create_audio_play_event(
		"gameplay",
		self,
		load(sound_path),
		Vector2.ZERO,
		volume
	)
	
	_buffer.add_event(event)
	print("Created sound effect event: ", sound_path)

func update_ui_element(element: Node, property: String, value: Variant):
	"""更新UI元素的事件驱动方法"""
	var event = _ui_handler._create_ui_update_event(
		"ui_updates",
		element,
		property,
		value
	)
	
	_buffer.add_event(event)
	print("Created UI update event: ", property, " = ", value)

func process_events(delta: float):
	"""在游戏循环中调用以处理事件"""
	_scheduler.process_events(_buffer, delta)