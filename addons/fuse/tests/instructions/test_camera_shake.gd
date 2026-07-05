extends Node2D

## Camera Shake 指令测试

func _ready():
	print("=== 开始测试 Camera Shake 指令 ===")
	await test_basic_shake()
	await test_different_intensities()
	await test_different_durations()
	await test_zero_duration_error()
	print("=== Camera Shake 指令测试完成 ===")

func test_basic_shake():
	print("\n[Test 1] 测试基本抖动效果")

	var instruction_script = load("res://addons/fuse/instructions/camera_shake.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath("../Camera2D")
	instruction.intensity = 0.5
	instruction.duration = 0.3

	var context = ExecutionContext.new()

	var camera = $Camera2D as Camera2D
	var original_offset = camera.offset

	# 连接完成信号
	var test_completed = false
	instruction.finished.connect(func():
		test_completed = true
	)

	instruction.execute(context)

	# 等待抖动完成
	await get_tree().create_timer(0.5).timeout
	await get_tree().process_frame

	assert(test_completed, "抖动应该完成")
	print("  ✓ 基本抖动效果测试通过")

func test_different_intensities():
	print("\n[Test 2] 测试不同强度")

	var camera = $Camera2D as Camera2D

	# 测试低强度
	var instruction1 = CameraShake.new()
	instruction1.target_node = NodePath("../Camera2D")
	instruction1.intensity = 0.2
	instruction1.duration = 0.2

	var context1 = ExecutionContext.new()

	var test1_completed = false
	instruction1.finished.connect(func():
		test1_completed = true
	)

	instruction1.execute(context1)
	await get_tree().create_timer(0.3).timeout
	await get_tree().process_frame

	assert(test1_completed, "低强度抖动应该完成")
	print("  ✓ 低强度抖动测试通过")

	# 测试高强度
	var instruction2 = CameraShake.new()
	instruction2.target_node = NodePath("../Camera2D")
	instruction2.intensity = 1.0
	instruction2.duration = 0.2

	var context2 = ExecutionContext.new()

	var test2_completed = false
	instruction2.finished.connect(func():
		test2_completed = true
	)

	instruction2.execute(context2)
	await get_tree().create_timer(0.3).timeout
	await get_tree().process_frame

	assert(test2_completed, "高强度抖动应该完成")
	print("  ✓ 高强度抖动测试通过")

func test_different_durations():
	print("\n[Test 3] 测试不同持续时间")

	var camera = $Camera2D as Camera2D

	# 测试短时间
	var instruction1 = CameraShake.new()
	instruction1.target_node = NodePath("../Camera2D")
	instruction1.intensity = 0.5
	instruction1.duration = 0.1

	var context1 = ExecutionContext.new()

	var test1_completed = false
	instruction1.finished.connect(func():
		test1_completed = true
	)

	instruction1.execute(context1)
	await get_tree().create_timer(0.2).timeout
	await get_tree().process_frame

	assert(test1_completed, "短时间抖动应该完成")
	print("  ✓ 短时间抖动测试通过")

	# 测试长时间
	var instruction2 = CameraShake.new()
	instruction2.target_node = NodePath("../Camera2D")
	instruction2.intensity = 0.5
	instruction2.duration = 0.5

	var context2 = ExecutionContext.new()

	var test2_completed = false
	instruction2.finished.connect(func():
		test2_completed = true
	)

	instruction2.execute(context2)
	await get_tree().create_timer(0.6).timeout
	await get_tree().process_frame

	assert(test2_completed, "长时间抖动应该完成")
	print("  ✓ 长时间抖动测试通过")

func test_zero_duration_error():
	print("\n[Test 4] 测试持续时间为 0 时的错误处理")

	var instruction = CameraShake.new()
	instruction.target_node = NodePath("../Camera2D")
	instruction.intensity = 0.5
	instruction.duration = 0.0  # 无效的持续时间

	# 验证应该失败
	var errors = instruction.validate()
	assert(errors.size() > 0, "应该有验证错误")
	assert("持续时间必须大于 0" in errors[0], "应该报告持续时间错误")
	print("  ✓ 持续时间为 0 的错误处理测试通过")
