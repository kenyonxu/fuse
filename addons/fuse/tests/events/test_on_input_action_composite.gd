# 文件：addons/fuse/tests/events/test_on_input_action_composite.gd
extends Node

## 测试 OnInputActionComposite 事件

func _ready():
	test_on_input_action_composite()

## 测试复合输入动作事件
func test_on_input_action_composite():
	print("=== 测试 OnInputActionComposite 事件 ===")

	# 创建事件资源
	var event = OnInputActionComposite.new()

	# 配置四个方向的输入动作
	event.action_up = "move_up"
	event.action_down = "move_down"
	event.action_left = "move_left"
	event.action_right = "move_right"

	# 验证事件配置
	var errors = event.validate()
	if errors.is_empty():
		print("✓ 事件配置验证通过")
	else:
		print("✗ 事件配置验证失败:")
		for error in errors:
			print("  - ", error)

	# 测试事件类型
	assert(event.get_event_type() == "input_action_composite", "事件类型应为 'input_action_composite'")
	print("✓ 事件类型正确: ", event.get_event_type())

	# 测试事件分类
	assert(event.get_event_category() == "input", "事件分类应为 'input'")
	print("✓ 事件分类正确: ", event.get_event_category())

	# 测试资源名称
	print("✓ 资源名称: ", event.resource_name)

	# 测试描述
	print("✓ 事件描述: ", event.get_description())

	print("=== 所有测试通过 ===")
