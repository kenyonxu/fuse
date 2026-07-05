extends Node

## Crossfade to Music 指令测试

func _ready():
	print("=== Testing Crossfade to Music Instruction ===")

	test_music_path_validation()
	test_volume_validation()
	test_bus_validation()
	test_crossfade_duration_validation()
	test_invalid_music_path()

	print("=== All Crossfade to Music tests passed! ===")

## 测试 1: 音乐路径验证
func test_music_path_validation():
	print("Test 1: Music path validation")

	var instruction_script = load("res://addons/fuse/instructions/audio/crossfade_to_music.gd")
	var instruction = instruction_script.new()

	# 测试空路径
	instruction.music_path = ""
	var errors = instruction.validate()
	assert(errors.size() > 0, "Should have errors for empty music path")
	print("  Empty path validation: ✓")

	# 测试有效路径
	instruction.music_path = "res://test.ogg"
	errors = instruction.validate()
	assert(not "音乐路径不能为空" in errors, "Should not have empty path error")
	print("  Valid path validation: ✓")
	print("  ✓ Test 1 passed\n")

## 测试 2: 音量验证
func test_volume_validation():
	print("Test 2: Volume validation")

	var instruction_script = load("res://addons/fuse/instructions/audio/crossfade_to_music.gd")
	var instruction = instruction_script.new()
	instruction.music_path = "res://test.ogg"

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
	instruction.volume = 0.8
	errors = instruction.validate()
	assert(not ("音量必须在" in errors and "0.0 到 1.0 之间" in errors), "Should not have volume range error")
	print("  Valid volume validation: ✓")
	print("  ✓ Test 2 passed\n")

## 测试 3: 混音器总线验证
func test_bus_validation():
	print("Test 3: Bus validation")

	var instruction_script = load("res://addons/fuse/instructions/audio/crossfade_to_music.gd")
	var instruction = instruction_script.new()
	instruction.music_path = "res://test.ogg"

	# 测试不存在的总线
	instruction.bus = "NonexistentBus"
	var errors = instruction.validate()
	assert(errors.size() > 0, "Should have errors for nonexistent bus")
	print("  Nonexistent bus validation: ✓")

	# 测试有效总线
	instruction.bus = "Master"
	errors = instruction.validate()
	assert(not ("总线" in errors and "不存在" in errors), "Should not have bus error for Master")
	print("  Valid bus validation: ✓")
	print("  ✓ Test 3 passed\n")

## 测试 4: 交叉淡入淡出时间验证
func test_crossfade_duration_validation():
	print("Test 4: Crossfade duration validation")

	var instruction_script = load("res://addons/fuse/instructions/audio/crossfade_to_music.gd")
	var instruction = instruction_script.new()
	instruction.music_path = "res://test.ogg"

	# 测试无效的交叉淡入淡出时间
	instruction.crossfade_duration = 0
	var errors = instruction.validate()
	assert(errors.size() > 0, "Should have errors for zero crossfade duration")
	print("  Zero crossfade duration validation: ✓")

	instruction.crossfade_duration = -1.0
	errors = instruction.validate()
	assert(errors.size() > 0, "Should have errors for negative crossfade duration")
	print("  Negative crossfade duration validation: ✓")

	# 测试有效的交叉淡入淡出时间
	instruction.crossfade_duration = 3.0
	errors = instruction.validate()
	assert(not "交叉淡入淡出时间必须大于 0" in errors, "Should not have crossfade duration error")
	print("  Valid crossfade duration validation: ✓")
	print("  ✓ Test 4 passed\n")

## 测试 5: 无效音乐路径
func test_invalid_music_path():
	print("Test 5: Invalid music path")

	var instruction_script = load("res://addons/fuse/instructions/audio/crossfade_to_music.gd")
	var instruction = instruction_script.new()
	instruction.music_path = "res://nonexistent_music.ogg"
	instruction.volume = 0.9

	var context = ExecutionContext.new()
	add_child(context)

	print("  Executing with invalid music path...")
	instruction.execute(context)
	await get_tree().process_frame

	# 验证应该记录错误
	assert(context.had_error(), "Should have error for invalid music path")
	print("  ✓ Test 5 passed (should log error)\n")
