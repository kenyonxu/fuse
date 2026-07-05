extends Node2D

# 简单的音频测试场景
# 用于验证JuicyAudioEventHandler在实际游戏环境中的工作情况

var _audio_handler: JuicyAudioEventHandler
var _test_audio_stream: AudioStream

func _ready():
	print("=== 音频测试场景启动 ===")

	if Engine.is_editor_hint():
		return

	# 创建音频事件处理器
	_audio_handler = JuicyAudioEventHandler.new()

	# 加载音频资源
	_test_audio_stream = preload("res://third_party_resources/Sword/Sword_On_Metal/Metal/Sword_On_Metal_Metal_1.wav")

	print("音频测试场景准备完成，点击按钮测试音频播放")

func _on_play_button_pressed():
	print("播放音频...")
	
	var play_event = JuicyEvent.create_audio_play_event(
		"Test",
		self, 
		_test_audio_stream,
		Vector2.ZERO,
		0.8
	)
	play_event.context_id = "test_audio"
	
	var success = _audio_handler.handle_event(play_event)
	if success:
		print("音频播放事件处理成功")
	else:
		print("音频播放事件处理失败")

func _on_stop_button_pressed():
	print("停止音频...")
	
	var stop_event = JuicyEvent.new(JuicyEvent.EventType.AUDIO_STOP)
	stop_event.context_id = "test_audio"
	stop_event.target = self
	
	var success = _audio_handler.handle_event(stop_event)
	if success:
		print("音频停止事件处理成功")
	else:
		print("音频停止事件处理失败")

func _on_stats_button_pressed():
	var stats = _audio_handler.get_audio_stats()
	var perf_stats = _audio_handler.get_performance_stats()
	
	print("=== 音频统计信息 ===")
	print("池大小: ", stats.pool_size)
	print("活跃播放器: ", stats.active_players)
	print("最大池大小: ", stats.max_pool_size)
	print("最大并发数: ", stats.max_concurrent_sounds)
	print("主音量: ", stats.master_volume)
	print("事件处理数: ", perf_stats.events_handled)
	print("事件失败数: ", perf_stats.events_failed)
	print("成功率: ", perf_stats.success_rate)
	print("===================")

func _exit_tree():
	if _audio_handler:
		_audio_handler.cleanup()
	print("音频测试场景清理完成")