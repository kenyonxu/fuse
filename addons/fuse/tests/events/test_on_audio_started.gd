extends Node

## OnAudioStarted 事件测试

func _ready():
	print("=== Testing OnAudioStarted ===")
	test_audio_start_detection()
	test_loop_triggering()
	test_not_triggered_when_already_playing()
	cleanup()
	print("=== All OnAudioStarted tests passed! ===")

func test_audio_start_detection():
	print("Test 1: Audio start detection")

	var event_script = load("res://addons/fuse/events/audio/on_audio_started.gd")
	var event = event_script.new()
	event.audio_player_path = NodePath("AudioPlayer")
	event.check_interval = 0.05

	var audio_player = $AudioPlayer
	var trigger = Node.new()
	add_child(trigger)

	var triggered = false
	var received_context = null
	event.triggered.connect(func(context):
		triggered = true
		received_context = context
	)

	# 初始化事件
	event.initialize(trigger)
	await get_tree().process_frame
	await get_tree().process_frame  # 等待定时器第一次检查

	# 启动音频播放
	audio_player.stream = load("res://addons/fuse/tests/test_audio.ogg")  # 需要测试音频
	audio_player.play()

	# 等待事件触发
	await get_tree().create_timer(0.2).timeout
	assert(triggered, "Event should trigger when audio starts")
	assert(received_context == audio_player, "Context should be the audio player")
	print("  ✓ Test 1 passed: Audio start detected\n")

	# 清理
	event.terminate(trigger)
	trigger.queue_free()

func test_loop_triggering():
	print("Test 2: Loop triggering control")

	var event_script = load("res://addons/fuse/events/audio/on_audio_started.gd")
	var event = event_script.new()
	event.audio_player_path = NodePath("AudioPlayer")
	event.trigger_on_loop = false  # 循环时不触发
	event.check_interval = 0.05

	var audio_player = $AudioPlayer
	var trigger = Node.new()
	add_child(trigger)

	var trigger_count = 0
	event.triggered.connect(func(_context):
		trigger_count += 1
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 模拟音频播放状态变化
	audio_player.play()
	await get_tree().create_timer(0.2).timeout
	assert(trigger_count == 1, "Should trigger once on start")

	# 模拟循环（状态保持 playing）
	audio_player.play(0.5)  # 从中间位置继续播放
	await get_tree().create_timer(0.2).timeout
	assert(trigger_count == 1, "Should not trigger again on loop")

	print("  ✓ Test 2 passed: Loop control works\n")

	event.terminate(trigger)
	trigger.queue_free()

func test_not_triggered_when_already_playing():
	print("Test 3: Not triggered when already playing")

	var event_script = load("res://addons/fuse/events/audio/on_audio_started.gd")
	var event = event_script.new()
	event.audio_player_path = NodePath("AudioPlayer")
	event.check_interval = 0.05

	var audio_player = $AudioPlayer
	var trigger = Node.new()
	add_child(trigger)

	var triggered = false
	event.triggered.connect(func(_context):
		triggered = true
	)

	# 先播放音频
	audio_player.stream = load("res://addons/fuse/tests/test_audio.ogg")
	audio_player.play()
	await get_tree().process_frame

	# 再初始化事件
	event.initialize(trigger)
	await get_tree().create_timer(0.2).timeout

	# 应该不触发（因为已经播放中）
	assert(not triggered, "Should not trigger when audio is already playing")

	print("  ✓ Test 3 passed: No false trigger on already playing audio\n")

	event.terminate(trigger)
	trigger.queue_free()

func cleanup():
	# 清理测试资源
	if $AudioPlayer:
		$AudioPlayer.stop()
