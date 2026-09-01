extends Control

## 测试 Set UI Progress 指令

func _ready():
	print("=== 开始测试 Set UI Progress 指令 ===")
	await test_set_progress_direct()
	await test_set_progress_from_variable()
	await test_invalid_progress_value()
	await test_error_handling()
	print("=== Set UI Progress 指令测试完成 ===")

## 测试 1: 直接设置进度值
func test_set_progress_direct():
	print("\n[Test 1] 测试直接设置进度值")

	var instruction_script = load("res://addons/fuse/instructions/set_ui_progress.gd")
	var instruction = instruction_script.new()
	var context = ExecutionContext.new()
	add_child(context)

	var progress_bar = get_node("TestProgressBar") as ProgressBar
	progress_bar.value = 0.0

	instruction.target_node = NodePath("TestProgressBar")
	instruction.value_source = 0  # DIRECT
	instruction.value = 0.75

	instruction.execute(context)

	await context.finished
	await get_tree().process_frame

	assert(progress_bar.value == 75.0, "ProgressBar 应该为 75%")
	print("✓ 直接设置进度值测试通过")

	context.queue_free()

## 测试 2: 从变量设置进度值
func test_set_progress_from_variable():
	print("\n[Test 2] 测试从变量设置进度值")

	var instruction_script = load("res://addons/fuse/instructions/set_ui_progress.gd")
	var instruction = instruction_script.new()
	var context = ExecutionContext.new()
	add_child(context)

	# 设置变量值
	context.set_variable("progress_var", 0.5)

	var progress_bar = get_node("TestProgressBar") as ProgressBar
	progress_bar.value = 0.0

	instruction.target_node = NodePath("TestProgressBar")
	instruction.value_source = 1  # VARIABLE
	instruction.value_variable = "progress_var"

	instruction.execute(context)

	await context.finished
	await get_tree().process_frame

	assert(progress_bar.value == 50.0, "ProgressBar 应该为 50%")
	print("✓ 从变量设置进度值测试通过")

	context.queue_free()

## 测试 3: 无效进度值
func test_invalid_progress_value():
	print("\n[Test 3] 测试无效进度值")

	var instruction_script = load("res://addons/fuse/instructions/set_ui_progress.gd")
	var instruction = instruction_script.new()
	var context = ExecutionContext.new()
	add_child(context)

	var progress_bar = get_node("TestProgressBar") as ProgressBar
	progress_bar.value = 50.0

	instruction.target_node = NodePath("TestProgressBar")
	instruction.value_source = 0  # DIRECT
	instruction.value = 1.5  # 无效值（> 1.0）

	instruction.execute(context)

	await context.finished
	await get_tree().process_frame

	assert(context.has_error(), "应该产生错误")
	assert(progress_bar.value == 50.0, "进度值应该保持不变")
	print("✓ 无效进度值测试通过")

	context.queue_free()

## 测试 4: 错误处理
func test_error_handling():
	print("\n[Test 4] 测试错误处理")

	var instruction_script = load("res://addons/fuse/instructions/set_ui_progress.gd")
	var instruction = instruction_script.new()
	var context = ExecutionContext.new()
	add_child(context)

	# 测试无效节点
	instruction.target_node = NodePath("InvalidNode")
	instruction.value_source = 0  # DIRECT
	instruction.value = 0.5

	instruction.execute(context)

	await context.finished
	await get_tree().process_frame

	assert(context.has_error(), "应该产生错误")
	print("✓ 错误处理测试通过")

	context.queue_free()
