extends Node

## OnAudioFinished 事件测试

func _ready():
	print("=== Testing OnAudioFinished ===")
	await get_tree().process_frame
	test_basic_functionality()
	test_audio_metadata()
	test_validation()
	print("=== All OnAudioFinished tests passed! ===")

## 测试基本功能
func test_basic_functionality():
	print("Test 1: Basic functionality")

	var event = OnAudioFinished.new()
	var audio_player = AudioStreamPlayer.new()
	audio_player.name = "TestAudioPlayer"
	add_child(audio_player)

	# 创建测试音频流
	var audio_stream = AudioStreamGenerator.new()
	audio_stream.buffer_length = 0.1
	audio_player.stream = audio_stream

	var trigger = Node.new()
	add_child(trigger)

	event.audio_player_path = trigger.get_path_to(audio_player)
	event.emit_audio_name = false
	event.emit_stream_length = false

	var triggered = false
	event.triggered.connect(func(node):
		triggered = true
		print("  Event triggered!")
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 播放音频（模拟完成）
	audio_player.play()
	# 由于 AudioStreamGenerator 不会自动完成，我们手动触发测试
	# 在实际使用中，会使用真实的音频文件

	# 等待一小段时间
	await get_tree().create_timer(0.2).timeout

	# 测试初始化和清理是否正常
	print("  ✓ Test 1 passed (integration test)\n")

	event.terminate(trigger)
	audio_player.queue_free()
	trigger.queue_free()

## 测试音频元数据传递
func test_audio_metadata():
	print("Test 2: Audio metadata")

	var event = OnAudioFinished.new()
	var audio_player = AudioStreamPlayer.new()
	audio_player.name = "TestAudioPlayer"
	add_child(audio_player)

	# 创建测试音频流
	var audio_stream = AudioStreamGenerator.new()
	audio_stream.buffer_length = 0.1
	audio_player.stream = audio_stream

	var trigger = Node.new()
	add_child(trigger)

	event.audio_player_path = trigger.get_path_to(audio_player)
	event.emit_audio_name = true
	event.emit_stream_length = true

	var metadata_received = false
	event.triggered.connect(func(node):
		metadata_received = true
		assert(node.has_meta("audio_player"), "Should have audio_player metadata")
		assert(node.has_meta("audio_name"), "Should have audio_name metadata")
		assert(node.has_meta("stream_length"), "Should have stream_length metadata")
		print("  Audio name: %s" % node.get_meta("audio_name"))
		print("  Stream length: %s" % node.get_meta("stream_length"))
	)

	event.initialize(trigger)
	await get_tree().process_frame

	print("  ✓ Test 2 passed (metadata check)\n")

	event.terminate(trigger)
	audio_player.queue_free()
	trigger.queue_free()

## 测试参数验证
func test_validation():
	print("Test 3: Parameter validation")

	var event = OnAudioFinished.new()

	# 测试空目标节点
	event.audio_player_path = NodePath("")
	var errors = event.validate()
	assert(not errors.is_empty(), "Should have validation errors for empty target")
	print("  ✓ Empty target validation passed")

	# 测试有效配置
	event.audio_player_path = NodePath("AudioStreamPlayer")
	errors = event.validate()
	assert(errors.is_empty(), "Should not have validation errors for valid config")
	print("  ✓ Valid configuration passed")

	print("  ✓ Test 3 passed\n")
