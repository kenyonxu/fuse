extends Node

## Resume Game 指令测试

func _ready():
	print("=== Testing Resume Game ===")

	test_resume_simple()
	test_resume_with_menu_close()
	test_resume_with_custom_time_scale()
	test_pause_resume_cycle()

	print("=== All Resume Game tests passed! ===")

## 测试 1: 简单恢复（不关闭菜单）
func test_resume_simple():
	print("Test 1: 简单恢复（不关闭菜单）")

	var instruction_script = load("res://addons/fuse/instructions/resume_game.gd")
	var instruction = instruction_script.new()
	instruction.close_pause_menu = false
	instruction.custom_time_scale = 1.0

	var context = ExecutionContext.new()

	# 先暂停游戏
	Engine.time_scale = 0.0
	assert(Engine.time_scale == 0.0, "游戏应该已暂停")

	# 执行恢复指令
	instruction.execute(context)
	await get_tree().process_frame

	# 验证结果
	assert(Engine.time_scale == 1.0, "游戏应该已恢复")
	print("  ✓ Test 1 passed\n")

## 测试 2: 恢复并关闭菜单
func test_resume_with_menu_close():
	print("Test 2: 恢复并关闭菜单")

	# 获取场景中的 PauseMenu 节点
	var pause_menu = $PauseMenu
	assert(pause_menu != null, "PauseMenu 节点应该存在于场景中")

	var instruction_script = load("res://addons/fuse/instructions/resume_game.gd")
	var instruction = instruction_script.new()
	instruction.close_pause_menu = true
	# 使用相对路径（从当前节点）
	instruction.pause_menu_node = NodePath("PauseMenu")
	instruction.custom_time_scale = 1.0

	var context = ExecutionContext.new()
	context.target = self  # 设置 target 为当前节点，以便解析相对路径

	# 先暂停游戏
	Engine.time_scale = 0.0
	assert(Engine.time_scale == 0.0, "游戏应该已暂停")
	assert(is_instance_valid(pause_menu), "暂停菜单应该存在")

	# 执行恢复指令
	instruction.execute(context)
	await get_tree().process_frame

	# 验证结果
	assert(Engine.time_scale == 1.0, "游戏应该已恢复")

	# 注意：queue_free 是异步的，需要等待几帧
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	# 验证菜单已标记为删除
	assert(not is_instance_valid(pause_menu) or pause_menu.is_queued_for_deletion(), "暂停菜单应该已删除")

	print("  ✓ Test 2 passed\n")

## 测试 3: 恢复到自定义时间缩放
func test_resume_with_custom_time_scale():
	print("Test 3: 恢复到自定义时间缩放")

	var instruction_script = load("res://addons/fuse/instructions/resume_game.gd")

	# 测试慢动作（0.5x）
	var instruction1 = instruction_script.new()
	instruction1.close_pause_menu = false
	instruction1.custom_time_scale = 0.5

	var context1 = ExecutionContext.new()

	Engine.time_scale = 0.0
	instruction1.execute(context1)
	await get_tree().process_frame

	assert(Engine.time_scale == 0.5, "游戏应该设置为慢动作")

	# 测试快进（2.0x）
	var instruction2 = instruction_script.new()
	instruction2.close_pause_menu = false
	instruction2.custom_time_scale = 2.0

	var context2 = ExecutionContext.new()

	instruction2.execute(context2)
	await get_tree().process_frame

	assert(Engine.time_scale == 2.0, "游戏应该设置为快进")

	# 恢复正常速度
	var instruction3 = instruction_script.new()
	instruction3.close_pause_menu = false
	instruction3.custom_time_scale = 1.0

	var context3 = ExecutionContext.new()

	instruction3.execute(context3)
	await get_tree().process_frame

	assert(Engine.time_scale == 1.0, "游戏应该恢复正常速度")
	print("  ✓ Test 3 passed\n")

## 测试 4: 暂停-恢复循环
func test_pause_resume_cycle():
	print("Test 4: 暂停-恢复循环")

	var pause_script = load("res://addons/fuse/instructions/pause_game.gd")
	var resume_script = load("res://addons/fuse/instructions/resume_game.gd")

	var pause_instruction = pause_script.new()
	pause_instruction.show_pause_menu = false

	var resume_instruction = resume_script.new()
	resume_instruction.close_pause_menu = false
	resume_instruction.custom_time_scale = 1.0

	# 初始状态：正常速度
	Engine.time_scale = 1.0
	assert(Engine.time_scale == 1.0, "初始状态应该是正常速度")

	# 第一次暂停
	var context1 = ExecutionContext.new()
	pause_instruction.execute(context1)
	await get_tree().process_frame
	assert(Engine.time_scale == 0.0, "第一次暂停后应该停止")

	# 第一次恢复
	var context2 = ExecutionContext.new()
	resume_instruction.execute(context2)
	await get_tree().process_frame
	assert(Engine.time_scale == 1.0, "第一次恢复后应该正常")

	# 第二次暂停
	var context3 = ExecutionContext.new()
	pause_instruction.execute(context3)
	await get_tree().process_frame
	assert(Engine.time_scale == 0.0, "第二次暂停后应该停止")

	# 第二次恢复
	var context4 = ExecutionContext.new()
	resume_instruction.execute(context4)
	await get_tree().process_frame
	assert(Engine.time_scale == 1.0, "第二次恢复后应该正常")

	print("  ✓ Test 4 passed\n")
