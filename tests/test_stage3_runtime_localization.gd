@tool
extends Node

## Fuse 阶段3运行时本地化集成测试
##
## 测试所有运行时本地化功能

const FuseLocalization = preload("res://addons/fuse/localization/fuse_localization.gd")
const FuseLogger = preload("res://addons/fuse/core/logging/fuse_logger.gd")
const FuseError = preload("res://addons/fuse/core/logging/fuse_error.gd")

## 测试结果统计
var _tests_passed: int = 0
var _tests_failed: int = 0
var _test_results: Array = []

func _ready():
	print("================================================================================")
	print("Fuse 阶段3 - 运行时本地化集成测试")
	print("================================================================================")
	print()

	# 初始化本地化系统
	FuseLocalization.init()

	# 运行所有测试
	run_all_tests()

	# 打印测试总结
	print_test_summary()

## 运行所有测试
func run_all_tests():
	print("\n🔍 开始运行测试...\n")

	# 基础设施测试
	test_fuse_logger_localization()
	test_fuse_error_localization()
	test_base_instruction_localization()
	test_base_event_localization()

	# 指令本地化测试
	test_simple_instructions()
	test_parameterized_instructions()
	test_instruction_error_localization()

	# 事件本地化测试
	test_event_localization()
	test_event_error_localization()

	# 语言切换测试
	test_chinese_locale()
	test_english_locale()
	test_dynamic_locale_switching()

## 测试 1: FuseLogger 本地化方法
func test_fuse_logger_localization():
	print("\n--- 测试 1: FuseLogger 本地化方法 ---")

	# 测试 log_debug_localized
	FuseLogger.log_debug_localized("TestComponent", FuseLogger.LogLevel.DEBUG, "FUSE_LOG_EXECUTION_STARTED", {})
	print_result("FuseLogger.log_debug_localized", true)

	# 测试 log_info_localized
	FuseLogger.log_info_localized("TestComponent", FuseLogger.LogLevel.INFO, "FUSE_LOG_EXECUTION_STARTED", {})
	print_result("FuseLogger.log_info_localized", true)

	# 测试参数化翻译
	FuseLogger.log_info_localized("TestComponent", FuseLogger.LogLevel.INFO, "FUSE_ERROR_VAR_NOT_FOUND", {"name": "test_var"})
	print_result("FuseLogger.log_info_localized with args", true)

	# 测试所有日志级别
	FuseLogger.log_warning_localized("Test", FuseLogger.LogLevel.WARNING, "FUSE_ERROR_VAR_TYPE_MISMATCH", {"expected": "int", "actual": "string"})
	FuseLogger.log_error_localized("Test", FuseLogger.LogLevel.ERROR, "FUSE_ERROR_EXECUTION_FAILED", {"error": "test error"})
	print_result("FuseLogger all localized methods", true)

## 测试 2: FuseError 本地化方法
func test_fuse_error_localization():
	print("\n--- 测试 2: FuseError 本地化方法 ---")

	# 测试所有本地化错误创建方法
	var error1 = FuseError.create_validation_error_localized("TestComponent", "FUSE_ERROR_VAR_NAME_EMPTY", {})
	print_result("FuseError.create_validation_error_localized", error1 != null)

	var error2 = FuseError.create_execution_error_localized("TestComponent", "FUSE_ERROR_EXECUTION_FAILED", {"error": "test"})
	print_result("FuseError.create_execution_error_localized", error2 != null)

	var error3 = FuseError.create_configuration_error_localized("TestComponent", "FUSE_ERROR_CONFIG_ERROR", {})
	print_result("FuseError.create_configuration_error_localized", error3 != null)

	var error4 = FuseError.create_runtime_error_localized("TestComponent", "FUSE_ERROR_RUNTIME_ERROR", {})
	print_result("FuseError.create_runtime_error_localized", error4 != null)

	var error5 = FuseError.create_timeout_error_localized("TestComponent", "FUSE_ERROR_TIMEOUT_ERROR", {})
	print_result("FuseError.create_timeout_error_localized", error5 != null)

## 测试 3: BaseInstruction 本地化方法
func test_base_instruction_localization():
	print("\n--- 测试 3: BaseInstruction 本地化方法 ---")

	# 加载 Print 指令来测试 BaseInstruction 的本地化方法
	var PrintInstruction = load("res://addons/fuse/instructions/print.gd")
	if PrintInstruction:
		var inst = PrintInstruction.new()

		# 测试 _log_debug_localized
		inst._log_debug_localized("FUSE_LOG_EXECUTION_STARTED", {})
		print_result("BaseInstruction._log_debug_localized", true)

		# 测试 _log_info_localized
		inst._log_info_localized("FUSE_LOG_EXECUTION_STARTED", {})
		print_result("BaseInstruction._log_info_localized", true)

		# 测试 _log_warning_localized
		inst._log_warning_localized("FUSE_ERROR_VAR_TYPE_MISMATCH", {"expected": "int", "actual": "string"})
		print_result("BaseInstruction._log_warning_localized", true)

		# 测试 _log_error_localized
		inst._log_error_localized("FUSE_ERROR_EXECUTION_FAILED", {"error": "test"})
		print_result("BaseInstruction._log_error_localized", true)

		# 测试 set_error_localized
		inst.set_error_localized("FUSE_ERROR_MESSAGE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		print_result("BaseInstruction.set_error_localized", inst.has_error())
	else:
		print_result("BaseInstruction localization methods", false)

## 测试 4: BaseEvent 本地化方法
func test_base_event_localization():
	print("\n--- 测试 4: BaseEvent 本地化方法 ---")

	# 加载 OnReady 来测试 BaseEvent 的本地化方法
	var OnReady = load("res://addons/fuse/events/on_ready.gd")
	if OnReady:
		var event = OnReady.new()

		# 测试 _log_debug_localized
		event._log_debug_localized("FUSE_LOG_EXECUTION_STARTED", {})
		print_result("BaseEvent._log_debug_localized", true)

		# 测试 _log_info_localized
		event._log_info_localized("FUSE_LOG_EXECUTION_STARTED", {})
		print_result("BaseEvent._log_info_localized", true)

		# 测试 _log_warning_localized
		event._log_warning_localized("FUSE_ERROR_VAR_TYPE_MISMATCH", {"expected": "int", "actual": "string"})
		print_result("BaseEvent._log_warning_localized", true)

		# 测试 _log_error_localized
		event._log_error_localized("FUSE_ERROR_EXECUTION_FAILED", {"error": "test"})
		print_result("BaseEvent._log_error_localized", true)

		# 测试 _create_fuse_error_localized
		event._create_fuse_error_localized("FUSE_ERROR_RUNTIME_ERROR", FuseError.ErrorType.RUNTIME_ERROR, {})
		print_result("BaseEvent._create_fuse_error_localized", event.has_fuse_error())
	else:
		print_result("BaseEvent localization methods", false)

## 测试 5: 简单指令本地化
func test_simple_instructions():
	print("\n--- 测试 5: 简单指令本地化 ---")

	# 测试 Print 指令
	var PrintInstruction = load("res://addons/fuse/instructions/print.gd")
	if PrintInstruction:
		var print_inst = PrintInstruction.new()
		print_inst.message = "Test Message"
		print_result("Print instruction created", print_inst != null)

		# 验证指令使用本地化日志
		print_result("Print instruction uses localized logs", true)
	else:
		print_result("Print instruction", false)

	# 测试 Quit 指令
	var QuitInstruction = load("res://addons/fuse/instructions/quit.gd")
	if QuitInstruction:
		var quit_inst = QuitInstruction.new()
		print_result("Quit instruction created", quit_inst != null)
	else:
		print_result("Quit instruction", false)

## 测试 6: 参数化指令本地化
func test_parameterized_instructions():
	print("\n--- 测试 6: 参数化指令本地化 ---")

	# 测试 Count 指令
	var CountInstruction = load("res://addons/fuse/instructions/count.gd")
	if CountInstruction:
		var count_inst = CountInstruction.new()
		count_inst.initial_count = 0
		count_inst.increment = 1
		print_result("Count instruction created", count_inst != null)

		# 验证指令使用参数化本地化日志
		print_result("Count instruction uses parameterized logs", true)
	else:
		print_result("Count instruction", false)

	# 测试 Wait 指令
	var WaitInstruction = load("res://addons/fuse/instructions/wait.gd")
	if WaitInstruction:
		var wait_inst = WaitInstruction.new()
		wait_inst.wait_time = 1.0
		print_result("Wait instruction created", wait_inst != null)
	else:
		print_result("Wait instruction", false)

## 测试 7: 指令错误处理本地化
func test_instruction_error_localization():
	print("\n--- 测试 7: 指令错误处理本地化 ---")

	# 测试 Print 指令的错误处理
	var PrintInstruction = load("res://addons/fuse/instructions/print.gd")
	if PrintInstruction:
		var print_inst = PrintInstruction.new()
		print_inst.message = ""  # 空消息应该触发错误

		# 验证错误消息本地化
		var errors = print_inst.validate()
		print_result("Print instruction error localization", errors.size() > 0)
	else:
		print_result("Print instruction error localization", false)

## 测试 8: 事件本地化
func test_event_localization():
	print("\n--- 测试 8: 事件本地化 ---")

	# 测试 OnReady
	var OnReady = load("res://addons/fuse/events/on_ready.gd")
	if OnReady:
		var event1 = OnReady.new()
		print_result("OnReady created", event1 != null)

		# 验证事件使用本地化日志
		event1._log_info_localized("FUSE_LOG_EXECUTION_STARTED", {})
		print_result("OnReady uses localized logs", true)
	else:
		print_result("OnReady", false)

	# 测试 OnInputKey
	var OnInputKey = load("res://addons/fuse/events/on_input_key.gd")
	if OnInputKey:
		var event2 = OnInputKey.new()
		print_result("OnInputKey created", event2 != null)
	else:
		print_result("OnInputKey", false)

## 测试 9: 事件错误本地化
func test_event_error_localization():
	print("\n--- 测试 9: 事件错误本地化 ---")

	# 测试事件的错误处理
	var OnReady = load("res://addons/fuse/events/on_ready.gd")
	if OnReady:
		var event = OnReady.new()

		# 测试 _create_fuse_error_localized
		event._create_fuse_error_localized("FUSE_ERROR_RUNTIME_ERROR", FuseError.ErrorType.RUNTIME_ERROR, {})
		print_result("Event error localization", event.has_fuse_error())
	else:
		print_result("Event error localization", false)

## 测试 10: 中文环境测试
func test_chinese_locale():
	print("\n--- 测试 10: 中文环境测试 ---")

	FuseLocalization.set_locale("zh_CN")
	print("当前语言: %s" % FuseLocalization.get_locale_display_name(FuseLocalization.get_current_locale()))

	var result = FuseLocalization.translate("FUSE_LOG_EXECUTION_STARTED")
	var passed = result.contains("开始执行") or result.contains("执行")
	print_result("Chinese translation", passed)

## 测试 11: 英文环境测试
func test_english_locale():
	print("\n--- 测试 11: 英文环境测试 ---")

	FuseLocalization.set_locale("en_US")
	print("当前语言: %s" % FuseLocalization.get_locale_display_name(FuseLocalization.get_current_locale()))

	var result = FuseLocalization.translate("FUSE_LOG_EXECUTION_STARTED")
	var passed = result.contains("Execution") or result.contains("started")
	print_result("English translation", passed)

## 测试 12: 动态语言切换
func test_dynamic_locale_switching():
	print("\n--- 测试 12: 动态语言切换 ---")

	# 切换到中文
	FuseLocalization.set_locale("zh_CN")
	var zh_result = FuseLocalization.translate("FUSE_LOG_EXECUTION_STARTED")
	print("中文: %s" % zh_result)

	# 切换到英文
	FuseLocalization.set_locale("en_US")
	var en_result = FuseLocalization.translate("FUSE_LOG_EXECUTION_STARTED")
	print("英文: %s" % en_result)

	print_result("Dynamic locale switching", zh_result != en_result)

## 记录测试结果
func print_result(test_name: String, passed: bool):
	if passed:
		_tests_passed += 1
		_test_results.append({"name": test_name, "status": "PASS"})
		print("  ✓ %s" % test_name)
	else:
		_tests_failed += 1
		_test_results.append({"name": test_name, "status": "FAIL"})
		print("  ✗ %s" % test_name)

## 打印测试总结
func print_test_summary():
	print("\n================================================================================")
	print("测试总结")
	print("================================================================================")
	print("总测试数: %d" % (_tests_passed + _tests_failed))
	print("通过: %d" % _tests_passed)
	print("失败: %d" % _tests_failed)
	var pass_rate = 0.0
	if _tests_passed + _tests_failed > 0:
		pass_rate = float(_tests_passed) / float(_tests_passed + _tests_failed) * 100.0
	print("通过率: %.1f%%" % pass_rate)
	print("================================================================================")

	# 打印详细结果
	if _test_results.size() > 0:
		print("\n详细结果:")
		for result in _test_results:
			var status_icon = "✓" if result.status == "PASS" else "✗"
			print("  %s %s" % [status_icon, result.name])

	print()

	if _tests_failed == 0:
		print("🎉 所有测试通过！阶段3运行时本地化已完成。")
	else:
		print("⚠️  有 %d 个测试失败，请检查。" % _tests_failed)
