extends Node2D

## Set Camera Limit 指令测试

func _ready():
	print("=== 开始测试 Set Camera Limit 指令 ===")
	await test_set_top_limit()
	await test_set_bottom_limit()
	await test_set_left_limit()
	await test_set_right_limit()
	await test_unset_limit()
	print("=== Set Camera Limit 指令测试完成 ===")

func test_set_top_limit():
	print("\n[Test 1] 测试设置上边界")

	var instruction_script = load("res://addons/fuse/instructions/set_camera_limit.gd")
	var instruction = instruction_script.new()
	var context = ExecutionContext.new()

	var camera = $TestCamera as Camera2D

	instruction.target_node = NodePath("TestCamera")
	instruction.limit_side = SetCameraLimit.LimitSide.TOP
	instruction.limit_value = 100

	instruction.execute(context)
	await context.finished

	assert(camera.limit_top == 100, "上边界应该被设置为 100")
	print("✓ 设置上边界测试通过")

func test_set_bottom_limit():
	print("\n[Test 2] 测试设置下边界")

	var instruction_script = load("res://addons/fuse/instructions/set_camera_limit.gd")
	var instruction = instruction_script.new()
	var context = ExecutionContext.new()

	var camera = $TestCamera as Camera2D

	instruction.target_node = NodePath("TestCamera")
	instruction.limit_side = SetCameraLimit.LimitSide.BOTTOM
	instruction.limit_value = -100

	instruction.execute(context)
	await context.finished

	assert(camera.limit_bottom == -100, "下边界应该被设置为 -100")
	print("✓ 设置下边界测试通过")

func test_set_left_limit():
	print("\n[Test 3] 测试设置左边界")

	var instruction_script = load("res://addons/fuse/instructions/set_camera_limit.gd")
	var instruction = instruction_script.new()
	var context = ExecutionContext.new()

	var camera = $TestCamera as Camera2D

	instruction.target_node = NodePath("TestCamera")
	instruction.limit_side = SetCameraLimit.LimitSide.LEFT
	instruction.limit_value = 200

	instruction.execute(context)
	await context.finished

	assert(camera.limit_left == 200, "左边界应该被设置为 200")
	print("✓ 设置左边界测试通过")

func test_set_right_limit():
	print("\n[Test 4] 测试设置右边界")

	var instruction_script = load("res://addons/fuse/instructions/set_camera_limit.gd")
	var instruction = instruction_script.new()
	var context = ExecutionContext.new()

	var camera = $TestCamera as Camera2D

	instruction.target_node = NodePath("TestCamera")
	instruction.limit_side = SetCameraLimit.LimitSide.RIGHT
	instruction.limit_value = -200

	instruction.execute(context)
	await context.finished

	assert(camera.limit_right == -200, "右边界应该被设置为 -200")
	print("✓ 设置右边界测试通过")

func test_unset_limit():
	print("\n[Test 5] 测试取消边界限制")

	var instruction_script = load("res://addons/fuse/instructions/set_camera_limit.gd")
	var instruction = instruction_script.new()
	var context = ExecutionContext.new()

	var camera = $TestCamera as Camera2D

	# 先设置一个限制
	camera.limit_top = 100

	instruction.target_node = NodePath("TestCamera")
	instruction.limit_side = SetCameraLimit.LimitSide.TOP
	instruction.limit_value = -9999  # -9999 表示无限制

	instruction.execute(context)
	await context.finished

	assert(camera.limit_top == -9999, "上边界应该被设置为无限制")
	print("✓ 取消边界限制测试通过")
