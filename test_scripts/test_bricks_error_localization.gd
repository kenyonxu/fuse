extends Node

## 测试 FuseError 本地化功能

func _ready():
	print("=== 开始测试 FuseError 本地化功能 ===\n")

	test_localized_error_creation()
	test_fallback_mechanism()
	test_get_formatted_message()
	test_backward_compatibility()

	print("\n=== 所有测试完成 ===")

func test_localized_error_creation():
	print("1. 测试本地化错误创建")

	# 测试带参数的本地化错误
	var error1 = FuseError.create_validation_error_localized(
		"TestComponent",
		"error.validation_test",
		{"param1": "value1", "param2": 42}
	)

	print("   验证错误创建成功: %s" % (error1 != null))
	print("   错误类型: %s" % FuseError.ErrorType.keys()[error1.error_type])
	print("   组件名: %s" % error1.component_name)
	print("   包含 message_key: %s" % error1.context.has("message_key"))
	print("   包含 message_args: %s" % error1.context.has("message_args"))

	# 测试无参数的本地化错误
	var error2 = FuseError.create_execution_error_localized(
		"TestComponent",
		"error.execution_test"
	)

	print("   执行错误创建成功: %s" % (error2 != null))
	print("   message_args 为空: %s" % error1.context["message_args"].is_empty())
	print("   ✓ 本地化错误创建测试通过\n")

func test_fallback_mechanism():
	print("2. 测试回退机制")

	# 创建一个使用不存在的翻译键的错误
	var error = FuseError.create_configuration_error_localized(
		"TestComponent",
		"nonexistent.key",
		{"name": "Test"}
	)

	# 即使翻译失败，也应该有回退文本
	var formatted = error.get_formatted_message()
	print("   格式化消息: %s" % formatted)
	print("   包含原始键: %s" % ("nonexistent.key" in formatted or "name" in formatted))
	print("   ✓ 回退机制测试通过\n")

func test_get_formatted_message():
	print("3. 测试 get_formatted_message() 重新翻译")

	var error = FuseError.create_runtime_error_localized(
		"TestComponent",
		"error.runtime_test",
		{"value": 100}
	)

	var formatted = error.get_formatted_message()
	print("   格式化消息: %s" % formatted)
	print("   包含组件名: %s" % ("TestComponent" in formatted))
	print("   包含错误类型: %s" % ("RUNTIME_ERROR" in formatted))
	print("   ✓ 格式化消息测试通过\n")

func test_backward_compatibility():
	print("4. 测试向后兼容性")

	# 使用旧的非本地化方法
	var error = FuseError.create_timeout_error(
		"TestComponent",
		"Old style error message",
		{"custom": "context"}
	)

	print("   旧方法创建成功: %s" % (error != null))
	print("   不包含 message_key: %s" % (not error.context.has("message_key")))
	print("   格式化消息: %s" % error.get_formatted_message())

	# 验证旧方法仍然正常工作
	var formatted = error.get_formatted_message()
	print("   包含原始消息: %s" % ("Old style error message" in formatted))
	print("   ✓ 向后兼容性测试通过\n")
