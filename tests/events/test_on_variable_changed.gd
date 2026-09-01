extends Node

## OnVariableChanged 事件测试
##
## 重构版本 - 2026-02-08
## 使用 GlobalVariableAssistant 替代 VariableContainer

func _ready():
	print("=== Testing OnVariableChanged (Refactored) ===")
	await get_tree().process_frame

	# 创建 GlobalVariableAssistant
	var assistant = GlobalVariableAssistant.new()
	add_child(assistant)

	# 创建全局变量资源
	var global_resource = GlobalVariableResource.new()
	assistant.current_resource = global_resource

	test_basic_functionality(assistant)
	test_check_modes(assistant)
	test_validation()

	assistant.queue_free()
	print("=== All OnVariableChanged tests passed! ===")

## 测试基本功能
func test_basic_functionality(assistant: GlobalVariableAssistant):
	print("Test 1: Basic functionality (Global variables only)")

	# 创建测试变量
	var test_var = BaseVariable.create("test_var", 0, BaseVariable.VariableScope.GLOBAL)
	assistant.add_global_variable("test_var", test_var)

	var trigger = Node.new()
	add_child(trigger)

	var event = OnVariableChanged.new()
	event.variable_name = "test_var"
	event.variable_scope = BaseVariable.VariableScope.GLOBAL
	event.check_mode = OnVariableChanged.CheckMode.ON_CHANGE
	event.check_interval = 0.1

	var triggered = false
	var new_value = null
	event.triggered.connect(func(context):
		triggered = true
		new_value = context.get_meta("new_value")
		print("  Variable changed event triggered! New value: %s" % new_value)
	)

	event.initialize(trigger)

	# 修改变量值
	await get_tree().create_timer(0.05).timeout
	test_var.set_value(42)

	# 等待事件触发
	await get_tree().create_timer(0.2).timeout

	assert(triggered, "Event should trigger on variable change")
	assert(new_value == 42, "New value should be 42")
	print("  ✓ Test 1 passed\n")

	event.terminate(trigger)
	trigger.queue_free()

## 测试检查模式
func test_check_modes(assistant: GlobalVariableAssistant):
	print("Test 2: Check modes")

	var trigger = Node.new()
	add_child(trigger)

	# 测试 ON_EQUAL 模式
	var test_equal = BaseVariable.create("test_equal", 0, BaseVariable.VariableScope.GLOBAL)
	assistant.add_global_variable("test_equal", test_equal)

	var event1 = OnVariableChanged.new()
	event1.variable_name = "test_equal"
	event1.variable_scope = BaseVariable.VariableScope.GLOBAL
	event1.check_mode = OnVariableChanged.CheckMode.ON_EQUAL
	event1.target_value = 100
	event1.check_interval = 0.1

	var equal_triggered = false
	event1.triggered.connect(func(context):
		equal_triggered = true
		print("  ON_EQUAL triggered!")
	)

	event1.initialize(trigger)

	await get_tree().process_frame
	test_equal.set_value(100)
	await get_tree().create_timer(0.2).timeout

	assert(equal_triggered, "ON_EQUAL should trigger when value equals target")
	print("  ✓ ON_EQUAL mode passed")

	event1.terminate(trigger)

	# 测试 ON_GREATER 模式
	var test_greater = BaseVariable.create("test_greater", 0, BaseVariable.VariableScope.GLOBAL)
	assistant.add_global_variable("test_greater", test_greater)

	var event2 = OnVariableChanged.new()
	event2.variable_name = "test_greater"
	event2.variable_scope = BaseVariable.VariableScope.GLOBAL
	event2.check_mode = OnVariableChanged.CheckMode.ON_GREATER
	event2.target_value = 50
	event2.check_interval = 0.1

	var greater_triggered = false
	event2.triggered.connect(func(context):
		greater_triggered = true
		print("  ON_GREATER triggered!")
	)

	event2.initialize(trigger)

	await get_tree().process_frame
	test_greater.set_value(100)
	await get_tree().create_timer(0.2).timeout

	assert(greater_triggered, "ON_GREATER should trigger when value is greater than target")
	print("  ✓ ON_GREATER mode passed")

	event2.terminate(trigger)
	trigger.queue_free()

	print("  ✓ Test 2 passed\n")

## 测试参数验证
func test_validation():
	print("Test 3: Parameter validation")

	var event = OnVariableChanged.new()

	# 测试空的 variable_name
	event.variable_name = ""
	var errors = event.validate()
	assert(not errors.is_empty(), "Should have validation errors for empty variable name")
	print("  ✓ Empty variable name validation passed")

	# 测试无效的 check_interval
	event.variable_name = "test_var"
	event.check_interval = -0.01
	errors = event.validate()
	assert(not errors.is_empty(), "Should have validation errors for negative interval")
	print("  ✓ Negative interval validation passed")

	# 测试有效配置
	event.check_interval = 0.1
	errors = event.validate()
	assert(errors.is_empty(), "Valid configuration should pass validation")
	print("  ✓ Valid configuration passed")

	print("  ✓ Test 3 passed\n")
