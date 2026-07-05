extends Control

## 测试 Set UI Text 指令

func _ready():
	print("=== 开始测试 Set UI Text 指令 ===")
	await test_set_label_text()
	await test_set_rich_text_label_text()
	await test_set_text_from_variable()
	await test_error_handling()
	print("=== Set UI Text 指令测试完成 ===")

## 测试 1: 设置 Label 文本
func test_set_label_text():
	print("\n[Test 1] 测试设置 Label 文本")

	var instruction_script = load("res://addons/fuse/instructions/set_ui_text.gd")
	var instruction = instruction_script.new()
	var context = ExecutionContext.new()
	add_child(context)

	var label = get_node("TestLabel") as Label
	label.text = "初始文本"

	instruction.target_node = NodePath("TestLabel")
	instruction.text_source = 0  # DIRECT
	instruction.text = "新的标签文本"

	instruction.execute(context)

	await context.finished
	await get_tree().process_frame

	assert(label.text == "新的标签文本", "Label 文本应该被更新")
	print("✓ 设置 Label 文本测试通过")

	context.queue_free()

## 测试 2: 设置 RichTextLabel 文本
func test_set_rich_text_label_text():
	print("\n[Test 2] 测试设置 RichTextLabel 文本")

	var instruction_script = load("res://addons/fuse/instructions/set_ui_text.gd")
	var instruction = instruction_script.new()
	var context = ExecutionContext.new()
	add_child(context)

	var rich_label = get_node("TestRichTextLabel") as RichTextLabel
	rich_label.text = "[b]初始富文本[/b]"

	instruction.target_node = NodePath("TestRichTextLabel")
	instruction.text_source = 0  # DIRECT
	instruction.text = "[color=red]红色富文本[/color]"

	instruction.execute(context)

	await context.finished
	await get_tree().process_frame

	assert(rich_label.text == "[color=red]红色富文本[/color]", "RichTextLabel 文本应该被更新")
	print("✓ 设置 RichTextLabel 文本测试通过")

	context.queue_free()

## 测试 3: 从变量设置文本
func test_set_text_from_variable():
	print("\n[Test 3] 测试从变量设置文本")

	var instruction_script = load("res://addons/fuse/instructions/set_ui_text.gd")
	var instruction = instruction_script.new()
	var context = ExecutionContext.new()
	add_child(context)

	# 设置变量值
	context.set_variable("test_var", "来自变量的文本")

	var label = get_node("TestLabel") as Label
	label.text = "初始文本"

	instruction.target_node = NodePath("TestLabel")
	instruction.text_source = 1  # VARIABLE
	instruction.text_variable = "test_var"

	instruction.execute(context)

	await context.finished
	await get_tree().process_frame

	assert(label.text == "来自变量的文本", "Label 文本应该从变量更新")
	print("✓ 从变量设置文本测试通过")

	context.queue_free()

## 测试 4: 错误处理
func test_error_handling():
	print("\n[Test 4] 测试错误处理")

	var instruction_script = load("res://addons/fuse/instructions/set_ui_text.gd")
	var instruction = instruction_script.new()
	var context = ExecutionContext.new()
	add_child(context)

	# 测试无效节点
	instruction.target_node = NodePath("InvalidNode")
	instruction.text_source = 0  # DIRECT
	instruction.text = "测试文本"

	instruction.execute(context)

	await context.finished
	await get_tree().process_frame

	assert(context.has_error(), "应该产生错误")
	print("✓ 错误处理测试通过")

	context.queue_free()
