extends Node

## 测试本地化日志功能
## 验证 FuseLogger 的本地化方法是否正常工作

# 显式加载 FuseLocalization 类（避免 class_name 识别问题）
func _ready() -> void:
	print("=== 开始测试本地化日志功能 ===\n")

	# 初始化本地化系统
	FuseLocalization.init()

	# 测试基本本地化（先检查是否有测试数据）
	_test_basic_translation()

	# 测试本地化日志方法
	_test_localized_logging()

	print("\n=== 本地化日志测试完成 ===")


func _test_basic_translation() -> void:
	print("--- 测试基本翻译 ---")

	# 测试简单翻译
	var test_key = "test.message"
	var translated = FuseLocalization.translate(test_key)
	print("翻译 '%s': %s" % [test_key, translated])

	# 测试带参数的翻译
	var translated_format = FuseLocalization.translate_format("test.format", {"value": 42})
	print("翻译格式化 '%s': %s" % ["test.format({value})", translated_format])

	print()


func _test_localized_logging() -> void:
	print("--- 测试本地化日志方法 ---")

	# 设置日志级别为 DEBUG 以显示所有日志
	var log_level = FuseLogger.LogLevel.DEBUG

	# 测试 Debug 级别
	FuseLogger.log_debug_localized("TestComponent", log_level, "test.debug", {}, "TestContext")

	# 测试 Info 级别
	FuseLogger.log_info_localized("TestComponent", log_level, "test.info", {"user": "Player1"}, "UserInfo")

	# 测试 Warning 级别
	FuseLogger.log_warning_localized("TestComponent", log_level, "test.warning", {"count": 5}, "Validation")

	# 测试 Error 级别
	FuseLogger.log_error_localized("TestComponent", log_level, "test.error", {"code": "ERR_001"}, "SystemCheck")

	# 测试不存在的翻译键（应该回退到键本身）
	print("\n--- 测试回退机制 ---")
	FuseLogger.log_info_localized("TestComponent", log_level, "nonexistent.key", {"param": "value"}, "FallbackTest")

	print()
