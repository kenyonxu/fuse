extends Node

## Play Sound 指令测试

func _ready():
	print("=== Testing Play Sound Instruction ===")

	test_sound_path_validation()
	test_volume_validation()
	test_pitch_validation()
	test_bus_validation()
	test_invalid_sound_path()

	print("=== All Play Sound tests passed! ===")

## 测试 1: 音频路径验证
func test_sound_path_validation():
	print("Test 1: Sound path validation")

	var instruction_script = load("res://addons/fuse/instructions/play_sound.gd")
	var instruction = instruction_script.new()

	# 测试空路径
	instruction.sound_path = ""
	var errors = instruction.validate()
	assert(errors.size() > 0, "Should have errors for empty sound path")
	print("  Empty path validation: ✓")

	# 测试有效路径
	instruction.sound_path = "res://test.wav"
	errors = instruction.validate()
	# 应该没有"音频路径不能为空"的错误
	assert(not "音频路径不能为空" in errors, "Should not have empty path error")
	print("  Valid path validation: ✓")
	print("  ✓ Test 1 passed\n")

## 测试 2: 音量验证
func test_volume_validation():
	print("Test 2: Volume validation")

	var instruction_script = load("res://addons/fuse/instructions/play_sound.gd")
	var instruction = instruction_script.new()
	instruction.sound_path = "res://test.wav"

	# 测试超出范围的音量
	instruction.volume = 1.5
	var errors = instruction.validate()
	assert(errors.size() > 0, "Should have errors for volume > 1.0")
	print("  Volume > 1.0 validation: ✓")

	instruction.volume = -0.1
	errors = instruction.validate()
	assert(errors.size() > 0, "Should have errors for volume < 0.0")
	print("  Volume < 0.0 validation: ✓")

	# 测试有效音量
	instruction.volume = 0.7
	errors = instruction.validate()
	assert(not ("音量必须在" in errors and "0.0 到 1.0 之间" in errors), "Should not have volume range error")
	print("  Valid volume validation: ✓")
	print("  ✓ Test 2 passed\n")

## 测试 3: 音调验证
func test_pitch_validation():
	print("Test 3: Pitch scale validation")

	var instruction_script = load("res://addons/fuse/instructions/play_sound.gd")
	var instruction = instruction_script.new()
	instruction.sound_path = "res://test.wav"

	# 测试无效音调
	instruction.pitch_scale = 0.0
	var errors = instruction.validate()
	assert(errors.size() > 0, "Should have errors for pitch_scale <= 0")
	print("  Pitch <= 0 validation: ✓")

	# 测试有效音调
	instruction.pitch_scale = 1.5
	errors = instruction.validate()
	assert(not "音调缩放必须大于 0" in errors, "Should not have pitch error")
	print("  Valid pitch validation: ✓")
	print("  ✓ Test 3 passed\n")

## 测试 4: 混音器总线验证
func test_bus_validation():
	print("Test 4: Bus validation")

	var instruction_script = load("res://addons/fuse/instructions/play_sound.gd")
	var instruction = instruction_script.new()
	instruction.sound_path = "res://test.wav"

	# 测试不存在的总线
	instruction.bus = "NonexistentBus"
	var errors = instruction.validate()
	assert(errors.size() > 0, "Should have errors for nonexistent bus")
	print("  Nonexistent bus validation: ✓")

	# 测试有效总线（Master 总是存在）
	instruction.bus = "Master"
	errors = instruction.validate()
	assert(not ("总线" in errors and "不存在" in errors), "Should not have bus error for Master")
	print("  Valid bus validation: ✓")
	print("  ✓ Test 4 passed\n")

## 测试 5: 无效音频路径
func test_invalid_sound_path():
	print("Test 5: Invalid sound path")

	var instruction_script = load("res://addons/fuse/instructions/play_sound.gd")
	var instruction = instruction_script.new()
	instruction.sound_path = "res://nonexistent_sound.wav"
	instruction.volume = 0.8

	var context = ExecutionContext.new()
	add_child(context)

	print("  Executing with invalid sound path...")
	instruction.execute(context)
	await get_tree().process_frame

	# 验证应该记录错误
	assert(context.had_error(), "Should have error for invalid sound path")
	print("  ✓ Test 5 passed (should log error)\n")
