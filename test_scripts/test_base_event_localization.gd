extends Node

## 测试 BaseEvent 本地化方法

func _ready():
	print("=== BaseEvent 本地化方法测试 ===\n")
	test_localized_methods()
	print("\n=== 测试完成 ===")

func test_localized_methods():
	# 创建一个测试事件实例
	var test_event = TestEvent.new()

	print("✓ TestEvent 实例创建成功")

	# 测试便捷本地化日志方法
	print("\n--- 测试便捷本地化日志方法 ---")

	# 设置日志级别为 DEBUG 以显示所有日志
	test_event.log_level = FuseLogger.LogLevel.DEBUG

	# 测试 _log_debug_localized
	print("\n测试 _log_debug_localized:")
	test_event._log_debug_localized("test.debug_message", {"param1": "value1"})

	# 测试 _log_info_localized
	print("\n测试 _log_info_localized:")
	test_event._log_info_localized("test.info_message", {"param2": "value2"})

	# 测试 _log_warning_localized
	print("\n测试 _log_warning_localized:")
	test_event._log_warning_localized("test.warning_message", {"param3": "value3"})

	# 测试 _log_error_localized
	print("\n测试 _log_error_localized:")
	test_event._log_error_localized("test.error_message", {"param4": "value4"})

	# 测试 _create_fuse_error_localized
	print("\n--- 测试 _create_fuse_error_localized ---")
	test_event._create_fuse_error_localized(
		"test.error_with_args",
		FuseError.ErrorType.RUNTIME_ERROR,
		{"error_code": 500}
	)

	if test_event.has_fuse_error():
		print("✓ FuseError 创建成功")
		var error_details = test_event.get_fuse_error().get_error_details()
		print("  错误详情: %s" % error_details)
	else:
		print("✗ FuseError 创建失败")

	print("\n✓ 所有本地化方法测试完成")

## 测试用事件类
class TestEvent extends BaseEvent:

	func _update_resource_name():
		resource_name = "TestEvent"

	func initialize(owner_node: Node) -> void:
		# 测试实现
		_log_info_localized("test.initialized", {"owner": owner_node.name})

	func terminate(owner_node: Node) -> void:
		# 测试实现
		_log_info_localized("test.terminated", {"owner": owner_node.name})

	func get_event_type() -> String:
		return "test_event"

	func get_description() -> String:
		return "Test Event for Localization"
