extends Node

# 简单的音频测试脚本
# 可以直接在Godot中运行来验证音频播放

func _ready():
	print("=== 简单音频测试开始 ===")
	
	# 创建音频事件处理器
	var audio_handler = JuicyAudioEventHandler.new()
	
	# 加载音频资源
	var audio_stream = preload("res://third_party_resources/Sword/Sword_On_Metal/Metal/Sword_On_Metal_Metal_1.wav")
	
	# 创建测试UI
	_create_ui(audio_handler, audio_stream)
	
	print("音频测试准备完成，请在编辑器中运行此场景")

func _create_ui(audio_handler: JuicyAudioEventHandler, audio_stream: AudioStream):
	var control = Control.new()
	add_child(control)
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var vbox = VBoxContainer.new()
	control.add_child(vbox)
	vbox.position = Vector2(100, 100)
	
	# 播放按钮
	var play_btn = Button.new()
	play_btn.text = "播放剑击音效"
	play_btn.pressed.connect(_on_play_pressed.bind(audio_handler, audio_stream))
	vbox.add_child(play_btn)
	
	# 停止按钮
	var stop_btn = Button.new()
	stop_btn.text = "停止所有音效"
	stop_btn.pressed.connect(_on_stop_pressed.bind(audio_handler))
	vbox.add_child(stop_btn)
	
	# 统计按钮
	var stats_btn = Button.new()
	stats_btn.text = "显示统计"
	stats_btn.pressed.connect(_on_stats_pressed.bind(audio_handler))
	vbox.add_child(stats_btn)

func _on_play_pressed(audio_handler: JuicyAudioEventHandler, audio_stream: AudioStream):
	print("播放音频...")
	
	var play_event = JuicyEvent.create_audio_play_event(
		"Test",
		self, 
		audio_stream,
		Vector2.ZERO,
		0.8
	)
	play_event.context_id = "test_audio"
	
	var success = audio_handler.handle_event(play_event)
	print("音频播放结果: ", success)

func _on_stop_pressed(audio_handler: JuicyAudioEventHandler):
	print("停止音频...")
	
	var stop_event = JuicyEvent.new(JuicyEvent.EventType.AUDIO_STOP)
	stop_event.context_id = "test_audio"
	stop_event.target = self
	
	var success = audio_handler.handle_event(stop_event)
	print("音频停止结果: ", success)

func _on_stats_pressed(audio_handler: JuicyAudioEventHandler):
	var stats = audio_handler.get_audio_stats()
	var perf_stats = audio_handler.get_performance_stats()
	
	print("=== 音频统计 ===")
	print("池大小: ", stats.pool_size)
	print("活跃播放器: ", stats.active_players)
	print("最大池大小: ", stats.max_pool_size)
	print("最大并发数: ", stats.max_concurrent_sounds)
	print("主音量: ", stats.master_volume)
	print("事件处理数: ", perf_stats.events_handled)
	print("事件失败数: ", perf_stats.events_failed)
	print("成功率: ", perf_stats.success_rate)
	print("===============")

func _exit_tree():
	print("音频测试清理")