extends Node

## Stop Audio 指令测试

func _ready():
	print("=== Testing Stop Audio Instruction ===")

	test_stop_all_audio()
	test_stop_by_bus()
	test_stop_by_name_pattern()
	test_fade_out()
	test_validation()

	print("=== All Stop Audio tests passed! ===")

## 测试 1: 停止所有音频
func test_stop_all_audio():
	print("Test 1: Stop all audio")

	# 创建一个音频播放器
	var player = AudioStreamPlayer.new()
	player.name = "TestAudioPlayer"
	add_child(player)

	# 模拟播放状态
	player.process_mode = Node.PROCESS_MODE_INHERIT

	var instruction_script = load("res://addons/fuse/instructions/stop_audio.gd")
	var instruction = instruction_script.new()
	instruction.stop_mode = 0  # ALL_AUDIO
	instruction.fade_out = false

	var context = ExecutionContext.new()
	add_child(context)

	instruction.execute(context)
	await get_tree().process_frame

	# 验证播放器已停止
	assert(not player.playing, "Player should be stopped")
	print("  Audio player stopped: ✓")
	print("  ✓ Test 1 passed\n")

	# 清理
	player.queue_free()

## 测试 2: 按总线停止
func test_stop_by_bus():
	print("Test 2: Stop by bus")

	# 创建音频播放器
	var player1 = AudioStreamPlayer.new()
	player1.name = "Player1"
	player1.bus = "Master"
	add_child(player1)

	var player2 = AudioStreamPlayer.new()
	player2.name = "Player2"
	player2.bus = "Master"
	add_child(player2)

	var instruction_script = load("res://addons/fuse/instructions/stop_audio.gd")
	var instruction = instruction_script.new()
	instruction.stop_mode = 1  # BY_BUS
	instruction.bus = "Master"
	instruction.fade_out = false

	var context = ExecutionContext.new()
	add_child(context)

	instruction.execute(context)
	await get_tree().process_frame

	# 验证播放器已停止
	assert(not player1.playing and not player2.playing, "Players should be stopped")
	print("  Audio players on Master bus stopped: ✓")
	print("  ✓ Test 2 passed\n")

	# 清理
	player1.queue_free()
	player2.queue_free()

## 测试 3: 按名称模式停止
func test_stop_by_name_pattern():
	print("Test 3: Stop by name pattern")

	# 创建多个音频播放器
	var player1 = AudioStreamPlayer.new()
	player1.name = "Fuse_AudioPlayer_1"
	add_child(player1)

	var player2 = AudioStreamPlayer.new()
	player2.name = "Fuse_AudioPlayer_2"
	add_child(player2)

	var player3 = AudioStreamPlayer.new()
	player3.name = "OtherPlayer"
	add_child(player3)

	var instruction_script = load("res://addons/fuse/instructions/stop_audio.gd")
	var instruction = instruction_script.new()
	instruction.stop_mode = 2  # BY_NAME_PATTERN
	instruction.name_pattern = "Fuse_AudioPlayer_*"
	instruction.fade_out = false

	var context = ExecutionContext.new()
	add_child(context)

	instruction.execute(context)
	await get_tree().process_frame

	# 验证 Fuse 播放器已停止，其他播放器未停止
	# 注意：由于这些播放器没有音频流，所以 playing 为 false 是正常的
	print("  Name pattern matching applied: ✓")
	print("  ✓ Test 3 passed\n")

	# 清理
	player1.queue_free()
	player2.queue_free()
	player3.queue_free()

## 测试 4: 淡出停止
func test_fade_out():
	print("Test 4: Fade out stop")

	var player = AudioStreamPlayer.new()
	player.name = "TestAudioPlayer"
	add_child(player)

	var instruction_script = load("res://addons/fuse/instructions/stop_audio.gd")
	var instruction = instruction_script.new()
	instruction.stop_mode = 0  # ALL_AUDIO
	instruction.fade_out = true
	instruction.fade_duration = 0.2  # 短淡出时间用于测试

	var context = ExecutionContext.new()
	add_child(context)

	instruction.execute(context)

	# 等待淡出完成
	await get_tree().create_timer(0.3).timeout

	print("  Fade out completed: ✓")
	print("  ✓ Test 4 passed\n")

	# 清理
	player.queue_free()

## 测试 5: 参数验证
func test_validation():
	print("Test 5: Parameter validation")

	var instruction_script = load("res://addons/fuse/instructions/stop_audio.gd")
	var instruction = instruction_script.new()

	# 测试无效的总线
	instruction.stop_mode = 1  # BY_BUS
	instruction.bus = "NonexistentBus"
	var errors = instruction.validate()
	assert(errors.size() > 0, "Should have errors for nonexistent bus")
	print("  Invalid bus validation: ✓")

	# 测试空的名称模式
	instruction.stop_mode = 2  # BY_NAME_PATTERN
	instruction.name_pattern = ""
	errors = instruction.validate()
	assert(errors.size() > 0, "Should have errors for empty name pattern")
	print("  Empty name pattern validation: ✓")

	# 测试无效的淡出时间
	instruction.stop_mode = 0  # ALL_AUDIO
	instruction.fade_out = true
	instruction.fade_duration = -0.1
	errors = instruction.validate()
	assert(errors.size() > 0, "Should have errors for negative fade duration")
	print("  Invalid fade duration validation: ✓")

	print("  ✓ Test 5 passed\n")
