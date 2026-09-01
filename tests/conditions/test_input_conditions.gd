extends Node

## 测试输入检测条件
##
## 测试按键按下、释放、按住条件的功能。

func _ready():
	print("=== 输入检测条件测试开始 ===")
	test_input_pressed_condition()
	test_input_released_condition()
	test_input_held_condition()
	print("=== 输入检测条件测试完成 ===")

## 测试按键按下条件
func test_input_pressed_condition():
	print("\n--- 测试按键按下条件 ---")

	# 创建执行上下文
	var context = ExecutionContext.new()
	context.scene_context = self

	# 创建条件 - 使用 Godot 内置的 "ui_accept" 输入动作
	var condition = CheckInputPressed.new()
	condition.action_name = "ui_accept"

	# 验证条件
	var errors = condition.validate()
	if errors.is_empty():
		print("✓ 条件验证通过")
	else:
		print("✗ 条件验证失败:", errors)
		assert(false, "条件验证失败")

	# 测试检查
	print("提示: 请按 Space/Enter 键触发 'ui_accept' 动作")
	print("当前状态: ", condition.get_description())

	# 清理
	condition.queue_free()
	print("按键按下条件测试完成!")

## 测试按键释放条件
func test_input_released_condition():
	print("\n--- 测试按键释放条件 ---")

	# 创建执行上下文
	var context = ExecutionContext.new()
	context.scene_context = self

	# 创建条件 - 使用 Godot 内置的 "ui_accept" 输入动作
	var condition = CheckInputReleased.new()
	condition.action_name = "ui_accept"

	# 验证条件
	var errors = condition.validate()
	if errors.is_empty():
		print("✓ 条件验证通过")
	else:
		print("✗ 条件验证失败:", errors)
		assert(false, "条件验证失败")

	# 测试检查
	print("提示: 请按 Space/Enter 键触发 'ui_accept' 动作")
	print("当前状态: ", condition.get_description())

	# 清理
	condition.queue_free()
	print("按键释放条件测试完成!")

## 测试按键按住条件
func test_input_held_condition():
	print("\n--- 测试按键按住条件 ---")

	# 创建执行上下文
	var context = ExecutionContext.new()
	context.scene_context = self

	# 创建条件 - 使用 Godot 内置的 "ui_accept" 输入动作
	var condition = CheckInputHeld.new()
	condition.action_name = "ui_accept"
	condition.minimum_hold_time = 0.0  # 不需要最小按住时间

	# 验证条件
	var errors = condition.validate()
	if errors.is_empty():
		print("✓ 条件验证通过")
	else:
		print("✗ 条件验证失败:", errors)
		assert(false, "条件验证失败")

	# 测试检查 - 无最小时间
	print("测试 1: 无最小按住时间")
	print("提示: 请按住 Space/Enter 键")
	print("当前状态: ", condition.get_description())

	# 测试最小按住时间
	condition.minimum_hold_time = 1.0
	print("\n测试 2: 最小按住时间 1.0 秒")
	print("提示: 请按住 Space/Enter 键至少 1 秒")
	print("当前状态: ", condition.get_description())

	# 测试重置功能
	condition.reset()
	print("\n✓ 条件重置功能正常")

	# 清理
	condition.queue_free()
	print("按键按住条件测试完成!")

## 测试无效输入动作
func test_invalid_action():
	print("\n--- 测试无效输入动作 ---")

	var context = ExecutionContext.new()
	context.scene_context = self

	# 测试未定义的输入动作
	var condition_pressed = CheckInputPressed.new()
	condition_pressed.action_name = "invalid_action_name"

	var errors = condition_pressed.validate()
	assert(not errors.is_empty(), "应该检测到无效的输入动作")
	print("✓ 正确检测到无效输入动作")

	# 测试空动作名称
	var condition_released = CheckInputReleased.new()
	condition_released.action_name = ""

	errors = condition_released.validate()
	assert(not errors.is_empty(), "应该检测到空的动作名称")
	print("✓ 正确检测到空动作名称")

	# 清理
	condition_pressed.queue_free()
	condition_released.queue_free()

	print("无效输入动作测试完成!")

## 测试条件元数据
func test_condition_metadata():
	print("\n--- 测试条件元数据 ---")

	# 测试 CheckInputPressed 元数据
	var pressed_metadata = CheckInputPressed._get_condition_metadata()
	print("按键按下条件:")
	print("  - 分类:", pressed_metadata.category_key)
	print("  - 关键词数量:", pressed_metadata.keywords.size())
	assert(pressed_metadata.keywords.has("输入"), "应该包含'输入'关键词")
	print("  ✓ 元数据正常")

	# 测试 CheckInputReleased 元数据
	var released_metadata = CheckInputReleased._get_condition_metadata()
	print("按键释放条件:")
	print("  - 分类:", released_metadata.category_key)
	assert(released_metadata.keywords.has("释放"), "应该包含'释放'关键词")
	print("  ✓ 元数据正常")

	# 测试 CheckInputHeld 元数据
	var held_metadata = CheckInputHeld._get_condition_metadata()
	print("按键按住条件:")
	print("  - 分类:", held_metadata.category_key)
	assert(held_metadata.keywords.has("按住"), "应该包含'按住'关键词")
	print("  ✓ 元数据正常")

	print("条件元数据测试完成!")

## 测试序列化和反序列化
func test_condition_serialization():
	print("\n--- 测试条件序列化 ---")

	var context = ExecutionContext.new()
	context.scene_context = self

	# 测试 CheckInputHeld 序列化（包含最小按住时间）
	var condition = CheckInputHeld.new()
	condition.action_name = "ui_accept"
	condition.minimum_hold_time = 2.5

	# 获取参数
	var params = condition.get_parameters()
	print("序列化参数:", params)
	assert(params["action_name"] == "ui_accept", "动作名称应该正确")
	assert(params["minimum_hold_time"] == 2.5, "最小按住时间应该正确")
	print("  ✓ 序列化正常")

	# 设置参数
	var new_condition = CheckInputHeld.new()
	new_condition.set_parameters(params)
	assert(new_condition.action_name == "ui_accept", "动作名称应该被正确设置")
	assert(new_condition.minimum_hold_time == 2.5, "最小按住时间应该被正确设置")
	print("  ✓ 反序列化正常")

	# 清理
	condition.queue_free()
	new_condition.queue_free()

	print("条件序列化测试完成!")
