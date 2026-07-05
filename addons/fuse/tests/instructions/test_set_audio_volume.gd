extends Node

## Set Audio Volume 指令测试

func _ready():
	print("=== Testing Set Audio Volume Instruction ===")

	test_set_volume_specific_player()
	test_set_volume_by_bus()
	test_set_volume_by_pattern()
	test_fade_volume()
	test_validation()

	print("=== All Set Audio Volume tests passed! ===")

## 测试 1: 设置指定播放器的音量
func test_set_volume_specific_player():
	print("Test 1: Set volume for specific player")

	# 创建音频播放器
	var player = AudioStreamPlayer.new()
	player.name = "TestPlayer"
	player.volume_db = 0.0  # 0 dB = 100% 线性
	add_child(player)

	var instruction_script = load("res://addons/fuse/instructions/set_audio_volume.gd")
	var instruction = instruction_script.new()
	instruction.target_mode = 0  # SPECIFIC_PLAYER
	instruction.target_player = NodePath("./TestPlayer")
	instruction.volume = 0.5  # 50%
	instruction.fade = false

	var context = ExecutionContext.new()
	add_child(context)

	instruction.execute(context)
	await get_tree().process_frame

	# 验证音量已设置（约 -6 dB）
	var expected_db = linear_to_db(0.5)
	assert(abs(player.volume_db - expected_db) < 0.1, "Volume should be ~50%")
	print("  Volume set to %.1f dB (expected %.1f dB)" % [player.volume_db, expected_db])
	print("  ✓ Test 1 passed\n")

	# 清理
	player.queue_free()

## 测试 2: 按总线设置音量
func test_set_volume_by_bus():
	print("Test 2: Set volume by bus")

	# 创建多个音频播放器
	var player1 = AudioStreamPlayer.new()
	player1.name = "Player1"
	player1.bus = "Master"
	add_child(player1)

	var player2 = AudioStreamPlayer.new()
	player2.name = "Player2"
	player2.bus = "Master"
	add_child(player2)

	var instruction_script = load("res://addons/fuse/instructions/set_audio_volume.gd")
	var instruction = instruction_script.new()
	instruction.target_mode = 1  # BY_BUS
	instruction.bus = "Master"
	instruction.volume = 0.7  # 70%
	instruction.fade = false

	var context = ExecutionContext.new()
	add_child(context)

	instruction.execute(context)
	await get_tree().process_frame

	# 验证播放器的音量已设置
	var expected_db = linear_to_db(0.7)
	assert(abs(player1.volume_db - expected_db) < 0.1, "Player1 volume should be ~70%")
	assert(abs(player2.volume_db - expected_db) < 0.1, "Player2 volume should be ~70%")
	print("  Both players volume set to %.1f dB" % expected_db)
	print("  ✓ Test 2 passed\n")

	# 清理
	player1.queue_free()
	player2.queue_free()

## 测试 3: 按名称模式设置音量
func test_set_volume_by_pattern():
	print("Test 3: Set volume by name pattern")

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

	var instruction_script = load("res://addons/fuse/instructions/set_audio_volume.gd")
	var instruction = instruction_script.new()
	instruction.target_mode = 2  # BY_NAME_PATTERN
	instruction.name_pattern = "Fuse_AudioPlayer_*"
	instruction.volume = 0.3  # 30%
	instruction.fade = false

	var context = ExecutionContext.new()
	add_child(context)

	instruction.execute(context)
	await get_tree().process_frame

	# 验证 Fuse 播放器音量已设置
	var expected_db = linear_to_db(0.3)
	assert(abs(player1.volume_db - expected_db) < 0.1, "Player1 volume should be ~30%")
	assert(abs(player2.volume_db - expected_db) < 0.1, "Player2 volume should be ~30%")
	print("  Fuse players volume set to %.1f dB" % expected_db)
	print("  ✓ Test 3 passed\n")

	# 清理
	player1.queue_free()
	player2.queue_free()
	player3.queue_free()

## 测试 4: 淡入淡出音量
func test_fade_volume():
	print("Test 4: Fade volume")

	var player = AudioStreamPlayer.new()
	player.name = "TestPlayer"
	player.volume_db = 0.0  # 开始 100%
	add_child(player)

	var instruction_script = load("res://addons/fuse/instructions/set_audio_volume.gd")
	var instruction = instruction_script.new()
	instruction.target_mode = 0  # SPECIFIC_PLAYER
	instruction.target_player = NodePath("./TestPlayer")
	instruction.volume = 0.2  # 20%
	instruction.fade = true
	instruction.fade_duration = 0.2  # 短淡出时间用于测试

	var context = ExecutionContext.new()
	add_child(context)

	instruction.execute(context)

	# 等待淡入淡出完成
	await get_tree().create_timer(0.3).timeout

	# 验证最终音量
	var expected_db = linear_to_db(0.2)
	assert(abs(player.volume_db - expected_db) < 0.1, "Volume should be faded to ~20%")
	print("  Volume faded to %.1f dB" % player.volume_db)
	print("  ✓ Test 4 passed\n")

	# 清理
	player.queue_free()

## 测试 5: 参数验证
func test_validation():
	print("Test 5: Parameter validation")

	var instruction_script = load("res://addons/fuse/instructions/set_audio_volume.gd")
	var instruction = instruction_script.new()

	# 测试超出范围的音量
	instruction.volume = 1.5
	var errors = instruction.validate()
	assert(errors.size() > 0, "Should have errors for volume > 1.0")
	print("  Volume > 1.0 validation: ✓")

	instruction.volume = -0.1
	errors = instruction.validate()
	assert(errors.size() > 0, "Should have errors for volume < 0.0")
	print("  Volume < 0.0 validation: ✓")

	# 测试无效的淡入淡出时间
	instruction.volume = 0.5
	instruction.fade = true
	instruction.fade_duration = -0.1
	errors = instruction.validate()
	assert(errors.size() > 0, "Should have errors for negative fade duration")
	print("  Invalid fade duration validation: ✓")

	# 测试无效的总线
	instruction.fade = false
	instruction.target_mode = 1  # BY_BUS
	instruction.bus = "NonexistentBus"
	errors = instruction.validate()
	assert(errors.size() > 0, "Should have errors for nonexistent bus")
	print("  Invalid bus validation: ✓")

	print("  ✓ Test 5 passed\n")
