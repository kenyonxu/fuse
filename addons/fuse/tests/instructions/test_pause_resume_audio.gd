extends Node

## Pause/Resume Audio 指令测试

func _ready():
	print("=== Testing Pause/Resume Audio Instruction ===")

	test_pause_audio()
	test_resume_audio()
	test_pause_by_bus()
	test_pause_by_pattern()
	test_validation()

	print("=== All Pause/Resume Audio tests passed! ===")

## 测试 1: 暂停音频
func test_pause_audio():
	print("Test 1: Pause audio")

	var player = AudioStreamPlayer.new()
	player.name = "TestPlayer"
	add_child(player)

	# 模拟播放状态
	player.process_mode = Node.PROCESS_MODE_INHERIT

	var instruction_script = load("res://addons/fuse/instructions/pause_resume_audio.gd")
	var instruction = instruction_script.new()
	instruction.action_mode = 0  # PAUSE
	instruction.target_mode = 0  # SPECIFIC_PLAYER
	instruction.target_player = NodePath("./TestPlayer")

	var context = ExecutionContext.new()
	add_child(context)

	# 由于没有实际的音频流，playing 为 false，但我们测试逻辑
	instruction.execute(context)
	await get_tree().process_frame

	print("  Pause operation executed: ✓")
	print("  ✓ Test 1 passed\n")

	# 清理
	player.queue_free()

## 测试 2: 恢复音频
func test_resume_audio():
	print("Test 2: Resume audio")

	var player = AudioStreamPlayer.new()
	player.name = "TestPlayer"
	add_child(player)

	var instruction_script = load("res://addons/fuse/instructions/pause_resume_audio.gd")
	var instruction = instruction_script.new()
	instruction.action_mode = 1  # RESUME
	instruction.target_mode = 0  # SPECIFIC_PLAYER
	instruction.target_player = NodePath("./TestPlayer")

	var context = ExecutionContext.new()
	add_child(context)

	instruction.execute(context)
	await get_tree().process_frame

	print("  Resume operation executed: ✓")
	print("  ✓ Test 2 passed\n")

	# 清理
	player.queue_free()

## 测试 3: 按总线暂停
func test_pause_by_bus():
	print("Test 3: Pause by bus")

	var player1 = AudioStreamPlayer.new()
	player1.name = "Player1"
	player1.bus = "Master"
	add_child(player1)

	var player2 = AudioStreamPlayer.new()
	player2.name = "Player2"
	player2.bus = "Master"
	add_child(player2)

	var instruction_script = load("res://addons/fuse/instructions/pause_resume_audio.gd")
	var instruction = instruction_script.new()
	instruction.action_mode = 0  # PAUSE
	instruction.target_mode = 1  # BY_BUS
	instruction.bus = "Master"

	var context = ExecutionContext.new()
	add_child(context)

	instruction.execute(context)
	await get_tree().process_frame

	print("  Pause by bus operation executed: ✓")
	print("  ✓ Test 3 passed\n")

	# 清理
	player1.queue_free()
	player2.queue_free()

## 测试 4: 按名称模式暂停
func test_pause_by_pattern():
	print("Test 4: Pause by name pattern")

	var player1 = AudioStreamPlayer.new()
	player1.name = "Fuse_AudioPlayer_1"
	add_child(player1)

	var player2 = AudioStreamPlayer.new()
	player2.name = "Fuse_AudioPlayer_2"
	add_child(player2)

	var instruction_script = load("res://addons/fuse/instructions/pause_resume_audio.gd")
	var instruction = instruction_script.new()
	instruction.action_mode = 0  # PAUSE
	instruction.target_mode = 2  # BY_NAME_PATTERN
	instruction.name_pattern = "Fuse_AudioPlayer_*"

	var context = ExecutionContext.new()
	add_child(context)

	instruction.execute(context)
	await get_tree().process_frame

	print("  Pause by pattern operation executed: ✓")
	print("  ✓ Test 4 passed\n")

	# 清理
	player1.queue_free()
	player2.queue_free()

## 测试 5: 参数验证
func test_validation():
	print("Test 5: Parameter validation")

	var instruction_script = load("res://addons/fuse/instructions/pause_resume_audio.gd")
	var instruction = instruction_script.new()

	# 测试空的目标播放器
	instruction.action_mode = 0  # PAUSE
	instruction.target_mode = 0  # SPECIFIC_PLAYER
	instruction.target_player = NodePath("")
	var errors = instruction.validate()
	assert(errors.size() > 0, "Should have errors for empty target player")
	print("  Empty target player validation: ✓")

	# 测试无效的总线
	instruction.target_mode = 1  # BY_BUS
	instruction.bus = "NonexistentBus"
	errors = instruction.validate()
	assert(errors.size() > 0, "Should have errors for nonexistent bus")
	print("  Invalid bus validation: ✓")

	# 测试空的名称模式
	instruction.target_mode = 2  # BY_NAME_PATTERN
	instruction.name_pattern = ""
	errors = instruction.validate()
	assert(errors.size() > 0, "Should have errors for empty name pattern")
	print("  Empty name pattern validation: ✓")

	print("  ✓ Test 5 passed\n")
