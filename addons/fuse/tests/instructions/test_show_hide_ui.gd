extends Control

## 测试 Show/Hide UI 指令

func _ready():
	print("=== 开始测试 Show/Hide UI 指令 ===")
	await test_show_ui()
	await test_hide_ui()
	await test_toggle_ui()
	await test_error_handling()
	print("=== Show/Hide UI 指令测试完成 ===")

## 测试 1: 显示 UI
func test_show_ui():
	print("\n[Test 1] 测试显示 UI")

	# 加载指令脚本
	var instruction_script = load("res://addons/fuse/instructions/show_hide_ui.gd")
	var instruction = instruction_script.new()
	var context = ExecutionContext.new()
	add_child(context)  # 将 context 添加到场景树

	# 设置测试场景
	var label = get_node("TestLabel") as Label
	label.visible = false

	instruction.target_node = NodePath("TestLabel")
	instruction.action = 0  # SHOW

	instruction.execute(context)

	await context.finished
	await get_tree().process_frame  # 等待一帧确保节点更新

	assert(label.visible == true, "Label 应该可见")
	print("✓ 显示 UI 测试通过")

	context.queue_free()  # 清理 context

## 测试 2: 隐藏 UI
func test_hide_ui():
	print("\n[Test 2] 测试隐藏 UI")

	# 加载指令脚本
	var instruction_script = load("res://addons/fuse/instructions/show_hide_ui.gd")
	var instruction = instruction_script.new()
	var context = ExecutionContext.new()
	add_child(context)  # 将 context 添加到场景树

	var label = get_node("TestLabel") as Label
	label.visible = true

	instruction.target_node = NodePath("TestLabel")
	instruction.action = 1  # HIDE

	instruction.execute(context)

	await context.finished
	await get_tree().process_frame  # 等待一帧确保节点更新

	assert(label.visible == false, "Label 应该不可见")
	print("✓ 隐藏 UI 测试通过")

	context.queue_free()  # 清理 context

## 测试 3: 切换 UI
func test_toggle_ui():
	print("\n[Test 3] 测试切换 UI")

	# 加载指令脚本
	var instruction_script = load("res://addons/fuse/instructions/show_hide_ui.gd")
	var instruction = instruction_script.new()
	var context = ExecutionContext.new()
	add_child(context)  # 将 context 添加到场景树

	var label = get_node("TestLabel") as Label
	label.visible = false

	instruction.target_node = NodePath("TestLabel")
	instruction.action = 2  # TOGGLE

	instruction.execute(context)

	await context.finished
	await get_tree().process_frame  # 等待一帧确保节点更新

	assert(label.visible == true, "第一次切换后应该可见")

	# 再次切换
	instruction.execute(context)
	await context.finished
	await get_tree().process_frame  # 等待一帧确保节点更新

	assert(label.visible == false, "第二次切换后应该不可见")
	print("✓ 切换 UI 测试通过")

	context.queue_free()  # 清理 context

## 测试 4: 错误处理
func test_error_handling():
	print("\n[Test 4] 测试错误处理")

	# 加载指令脚本
	var instruction_script = load("res://addons/fuse/instructions/show_hide_ui.gd")
	var instruction = instruction_script.new()
	var context = ExecutionContext.new()
	add_child(context)  # 将 context 添加到场景树

	# 测试无效节点
	instruction.target_node = NodePath("InvalidNode")
	instruction.action = 0  # SHOW

	instruction.execute(context)

	await context.finished
	await get_tree().process_frame  # 等待一帧确保节点更新

	assert(context.error != null, "应该产生错误")
	print("✓ 错误处理测试通过")

	context.queue_free()  # 清理 context
