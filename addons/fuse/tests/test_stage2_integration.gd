## Fuse 阶段 2 本地化集成测试
##
## 测试所有编辑器 UI 组件的本地化功能
## 在 Godot 编辑器中运行此场景进行验证

@tool
extends Node

## 测试结果统计
var test_results: Array[Dictionary] = []

## 当前测试索引
var current_test_index: int = 0

## FuseLocalization 类引用
var FuseLocalization_class


func _ready() -> void:
	var separator = "================================================================================"
	print("\n" + separator)
	print("Fuse 阶段 2 本地化集成测试")
	print(separator + "\n")

	# 动态加载 FuseLocalization 避免循环依赖
	FuseLocalization_class = load("res://addons/fuse/localization/fuse_localization.gd")

	if not FuseLocalization_class:
		push_error("无法加载 FuseLocalization 类")
		return

	# 初始化本地化系统
	if not FuseLocalization_class.has_method("init"):
		push_error("FuseLocalization 类缺少 init() 方法")
		return

	FuseLocalization_class.init()

	# 等待一帧后开始测试
	await get_tree().process_frame
	await get_tree().process_frame

	# 运行所有测试
	await run_all_tests()

	# 输出测试结果摘要
	print_test_summary()


## 运行所有测试
func run_all_tests() -> void:
	print("\n开始运行集成测试...\n")

	# 测试1: 指令选择器本地化
	await test_instruction_selector_localization()

	# 测试2: 输入键选择器本地化
	await test_input_key_selector_localization()

	# 测试3: 静态分析面板本地化
	await test_static_analysis_panel_localization()

	# 测试4: 调试可视化器本地化
	await test_debug_visualizer_localization()

	# 测试5: 执行跟踪器本地化
	await test_execution_tracker_localization()

	# 测试6: Inspector 插件本地化
	await test_inspector_plugin_localization()

	# 测试7: 翻译键覆盖率
	await test_translation_key_coverage()

	# 测试8: 参数化翻译
	await test_parameterized_translations()

	# 测试9: 语言切换
	await test_language_switching()

	# 测试10: 回退机制
	await test_fallback_mechanism()

	print("\n所有测试完成!\n")


## 测试1: 指令选择器本地化
func test_instruction_selector_localization() -> void:
	current_test_index = 1
	print("测试 %d: 指令选择器本地化" % current_test_index)

	var test_pass: bool = true
	var errors: Array[String] = []

	# 检查必要的翻译键
	var required_keys = [
		"FUSE_UI_INSTRUCTION_SELECTOR_TITLE",
		"FUSE_UI_SEARCH_PLACEHOLDER",
		"FUSE_UI_NO_INSTRUCTIONS_FOUND",
		"FUSE_UI_BTN_CLICK_TO_ADD_INSTRUCTION"
	]

	for key in required_keys:
		var zh_result = FuseLocalization_class.translate(key)
		if zh_result == key:
			test_pass = false
			errors.append("  - 翻译键缺失或无效: %s" % key)

	# 检查文件是否存在
	var selector_file = "res://addons/fuse/editor/instruction_selector/instructions_selector.gd"
	if not FileAccess.file_exists(selector_file):
		test_pass = false
		errors.append("  - 指令选择器文件不存在")

	# 检查文件是否使用 translate()
	var file = FileAccess.open(selector_file, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		if "FuseLocalization_class.translate" in content or "translate(" in content:
			print("  ✓ 指令选择器已使用本地化 API")
		else:
			test_pass = false
			errors.append("  - 指令选择器未使用本地化 API")

	# 记录结果
	var result = {
		"test_name": "指令选择器本地化",
		"index": current_test_index,
		"passed": test_pass,
		"errors": errors
	}
	test_results.append(result)

	# 输出结果
	if test_pass:
		print("  ✓ 测试通过\n")
	else:
		print("  ✗ 测试失败")
		for error in errors:
			print(error)
		print()

	await get_tree().process_frame


## 测试2: 输入键选择器本地化
func test_input_key_selector_localization() -> void:
	current_test_index = 2
	print("测试 %d: 输入键选择器本地化" % current_test_index)

	var test_pass: bool = true
	var errors: Array[String] = []

	# 检查必要的翻译键
	var required_keys = [
		"FUSE_UI_INPUT_KEY_SELECTOR_TITLE",
		"FUSE_UI_BTN_SELECT_KEY",
		"FUSE_UI_KEY_LABEL",
		"FUSE_UI_INSTRUCTION_CLICK_TO_START",
		"FUSE_UI_BTN_START_CAPTURE",
		"FUSE_UI_WAITING_FOR_KEY"
	]

	for key in required_keys:
		var result = FuseLocalization_class.translate(key)
		if result == key:
			test_pass = false
			errors.append("  - 翻译键缺失或无效: %s" % key)

	# 检查文件是否存在
	var dialog_file = "res://addons/fuse/editor/input_key_selector/input_key_dialog.gd"
	if not FileAccess.file_exists(dialog_file):
		test_pass = false
		errors.append("  - 输入键对话框文件不存在")

	# 检查文件是否使用 translate()
	var file = FileAccess.open(dialog_file, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		if "translate(" in content:
			print("  ✓ 输入键对话框已使用本地化 API")
		else:
			test_pass = false
			errors.append("  - 输入键对话框未使用本地化 API")

	# 记录结果
	var result = {
		"test_name": "输入键选择器本地化",
		"index": current_test_index,
		"passed": test_pass,
		"errors": errors
	}
	test_results.append(result)

	# 输出结果
	if test_pass:
		print("  ✓ 测试通过\n")
	else:
		print("  ✗ 测试失败")
		for error in errors:
			print(error)
		print()

	await get_tree().process_frame


## 测试3: 静态分析面板本地化
func test_static_analysis_panel_localization() -> void:
	current_test_index = 3
	print("测试 %d: 静态分析面板本地化" % current_test_index)

	var test_pass: bool = true
	var errors: Array[String] = []

	# 检查必要的翻译键（抽样检查）
	var sample_keys = [
		"FUSE_UI_STATIC_ANALYSIS_TITLE",
		"FUSE_UI_BTN_ANALYZE_INSTRUCTIONS",
		"FUSE_UI_BTN_CLEAR_RESULTS",
		"FUSE_UI_STATUS_READY",
		"FUSE_UI_WELCOME_TITLE"
	]

	for key in sample_keys:
		var result = FuseLocalization_class.translate(key)
		if result == key:
			test_pass = false
			errors.append("  - 翻译键缺失或无效: %s" % key)

	# 检查文件是否存在
	var panel_file = "res://addons/fuse/editor/static_analysis/static_analysis_panel.gd"
	if not FileAccess.file_exists(panel_file):
		test_pass = false
		errors.append("  - 静态分析面板文件不存在")

	# 检查文件是否使用 translate()
	var file = FileAccess.open(panel_file, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		if "translate(" in content:
			print("  ✓ 静态分析面板已使用本地化 API")
		else:
			test_pass = false
			errors.append("  - 静态分析面板未使用本地化 API")

	# 记录结果
	var result = {
		"test_name": "静态分析面板本地化",
		"index": current_test_index,
		"passed": test_pass,
		"errors": errors
	}
	test_results.append(result)

	# 输出结果
	if test_pass:
		print("  ✓ 测试通过\n")
	else:
		print("  ✗ 测试失败")
		for error in errors:
			print(error)
		print()

	await get_tree().process_frame


## 测试4: 调试可视化器本地化
func test_debug_visualizer_localization() -> void:
	current_test_index = 4
	print("测试 %d: 调试可视化器本地化" % current_test_index)

	var test_pass: bool = true
	var errors: Array[String] = []

	# 检查必要的翻译键（抽样检查）
	var sample_keys = [
		"FUSE_UI_DEBUG_WELCOME_TITLE",
		"FUSE_UI_DEBUG_WELCOME_DESCRIPTION",
		"FUSE_UI_DEBUG_FEATURE_1",
		"FUSE_UI_DEBUG_NO_HISTORY"
	]

	for key in sample_keys:
		var result = FuseLocalization_class.translate(key)
		if result == key:
			test_pass = false
			errors.append("  - 翻译键缺失或无效: %s" % key)

	# 检查文件是否存在
	var visualizer_file = "res://addons/fuse/editor/debugging/debug_visualizer.gd"
	if not FileAccess.file_exists(visualizer_file):
		test_pass = false
		errors.append("  - 调试可视化器文件不存在")

	# 检查文件是否使用 translate()
	var file = FileAccess.open(visualizer_file, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		if "translate(" in content:
			print("  ✓ 调试可视化器已使用本地化 API")
		else:
			test_pass = false
			errors.append("  - 调试可视化器未使用本地化 API")

	# 记录结果
	var result = {
		"test_name": "调试可视化器本地化",
		"index": current_test_index,
		"passed": test_pass,
		"errors": errors
	}
	test_results.append(result)

	# 输出结果
	if test_pass:
		print("  ✓ 测试通过\n")
	else:
		print("  ✗ 测试失败")
		for error in errors:
			print(error)
		print()

	await get_tree().process_frame


## 测试5: 执行跟踪器本地化
func test_execution_tracker_localization() -> void:
	current_test_index = 5
	print("测试 %d: 执行跟踪器本地化" % current_test_index)

	var test_pass: bool = true
	var errors: Array[String] = []

	# 检查日志消息翻译键（抽样检查）
	var sample_keys = [
		"FUSE_LOG_TRACKING_STARTED",
		"FUSE_LOG_RECORD_INSTRUCTION_START",
		"FUSE_LOG_TRACKING_COMPLETED",
		"FUSE_LOG_EXECUTION_HISTORY_CLEARED"
	]

	for key in sample_keys:
		var result = FuseLocalization_class.translate(key)
		if result == key:
			test_pass = false
			errors.append("  - 翻译键缺失或无效: %s" % key)

	# 检查文件是否存在
	var tracker_file = "res://addons/fuse/editor/debugging/execution_tracker.gd"
	if not FileAccess.file_exists(tracker_file):
		test_pass = false
		errors.append("  - 执行跟踪器文件不存在")

	# 检查文件是否使用 translate()
	var file = FileAccess.open(tracker_file, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		if "translate(" in content or "translate_format(" in content:
			print("  ✓ 执行跟踪器已使用本地化 API")
		else:
			test_pass = false
			errors.append("  - 执行跟踪器未使用本地化 API")

	# 记录结果
	var result = {
		"test_name": "执行跟踪器本地化",
		"index": current_test_index,
		"passed": test_pass,
		"errors": errors
	}
	test_results.append(result)

	# 输出结果
	if test_pass:
		print("  ✓ 测试通过\n")
	else:
		print("  ✗ 测试失败")
		for error in errors:
			print(error)
		print()

	await get_tree().process_frame


## 测试6: Inspector 插件本地化
func test_inspector_plugin_localization() -> void:
	current_test_index = 6
	print("测试 %d: Inspector 插件本地化" % current_test_index)

	var test_pass: bool = true
	var errors: Array[String] = []

	# 检查必要的翻译键
	var required_keys = [
		"FUSE_UI_LABEL_INSTRUCTIONS",
		"FUSE_UI_LABEL_NAME",
		"FUSE_UI_LABEL_TYPE",
		"FUSE_UI_BTN_CLICK_TO_ADD_INSTRUCTION"
	]

	for key in required_keys:
		var result = FuseLocalization_class.translate(key)
		if result == key:
			test_pass = false
			errors.append("  - 翻译键缺失或无效: %s" % key)

	# 检查文件是否存在
	var inspector_file = "res://addons/fuse/editor/instruction_selector/instructions_array_inspector_plugin.gd"
	if not FileAccess.file_exists(inspector_file):
		test_pass = false
		errors.append("  - Inspector 插件文件不存在")

	# 检查文件是否使用 translate()
	var file = FileAccess.open(inspector_file, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		if "translate(" in content:
			print("  ✓ Inspector 插件已使用本地化 API")
		else:
			test_pass = false
			errors.append("  - Inspector 插件未使用本地化 API")

	# 记录结果
	var result = {
		"test_name": "Inspector 插件本地化",
		"index": current_test_index,
		"passed": test_pass,
		"errors": errors
	}
	test_results.append(result)

	# 输出结果
	if test_pass:
		print("  ✓ 测试通过\n")
	else:
		print("  ✗ 测试失败")
		for error in errors:
			print(error)
		print()

	await get_tree().process_frame


## 测试7: 翻译键覆盖率
func test_translation_key_coverage() -> void:
	current_test_index = 7
	print("测试 %d: 翻译键覆盖率" % current_test_index)

	var test_pass: bool = true
	var errors: Array[String] = []

	# 获取翻译统计
	var stats = FuseLocalization_class.get_translation_stats()

	print("  - 翻译键总数: %d" % stats.total_keys)
	print("  - 中文覆盖率: %.1f%%" % stats.zh_CN_coverage)
	print("  - 英文覆盖率: %.1f%%" % stats.en_US_coverage)

	# 检查覆盖率
	if stats.total_keys < 200:
		test_pass = false
		errors.append("  - 翻译键数量不足 (当前: %d, 期望: ≥200)" % stats.total_keys)

	if stats.zh_CN_coverage < 95.0:
		test_pass = false
		errors.append("  - 中文覆盖率不足 (当前: %.1f%%, 期望: ≥95%%)" % stats.zh_CN_coverage)

	if stats.en_US_coverage < 95.0:
		test_pass = false
		errors.append("  - 英文覆盖率不足 (当前: %.1f%%, 期望: ≥95%%)" % stats.en_US_coverage)

	# 检查是否有缺失的翻译
	var missing = FuseLocalization_class.get_missing_translations()
	if not missing.is_empty():
		print("  - 缺失的翻译数量: %d" % missing.size())

	# 记录结果
	var result = {
		"test_name": "翻译键覆盖率",
		"index": current_test_index,
		"passed": test_pass,
		"errors": errors
	}
	test_results.append(result)

	# 输出结果
	if test_pass:
		print("  ✓ 测试通过\n")
	else:
		print("  ✗ 测试失败")
		for error in errors:
			print(error)
		print()

	await get_tree().process_frame


## 测试8: 参数化翻译
func test_parameterized_translations() -> void:
	current_test_index = 8
	print("测试 %d: 参数化翻译" % current_test_index)

	var test_pass: bool = true
	var errors: Array[String] = []

	# 测试参数化翻译
	var test_cases = [
		{
			"key": "FUSE_ERROR_VAR_NOT_FOUND",
			"args": {"name": "my_variable"},
			"should_contain_zh": "my_variable"
		},
		{
			"key": "FUSE_LOG_EXECUTION_STARTED",
			"args": {},
			"should_not_be_key": true
		}
	]

	for test_case in test_cases:
		var key = test_case["key"]
		var args = test_case["args"]

		var result = FuseLocalization_class.translate_format(key, args)

		# 检查是否返回了原始键（表示翻译失败）
		if test_case.has("should_not_be_key") and result == key:
			test_pass = false
			errors.append("  - 参数化翻译失败，返回原始键: %s" % key)

		# 检查是否包含预期的内容
		if test_case.has("should_contain_zh"):
			if not (test_case["should_contain_zh"] in result):
				test_pass = false
				errors.append("  - 参数替换失败: %s (结果: %s)" % [key, result])

	print("  ✓ 参数化翻译功能正常")

	# 记录结果
	var result = {
		"test_name": "参数化翻译",
		"index": current_test_index,
		"passed": test_pass,
		"errors": errors
	}
	test_results.append(result)

	# 输出结果
	if test_pass:
		print("  ✓ 测试通过\n")
	else:
		print("  ✗ 测试失败")
		for error in errors:
			print(error)
		print()

	await get_tree().process_frame


## 测试9: 语言切换
func test_language_switching() -> void:
	current_test_index = 9
	print("测试 %d: 语言切换" % current_test_index)

	var test_pass: bool = true
	var errors: Array[String] = []

	# 切换到英文
	FuseLocalization_class.set_locale("en_US")
	var en_result = FuseLocalization_class.translate("FUSE_UI_INSTRUCTION_SELECTOR_TITLE")

	if en_result == "Instruction Selector":
		print("  ✓ 英文切换成功: %s" % en_result)
	else:
		test_pass = false
		errors.append("  - 英文切换失败: %s" % en_result)

	# 切换到中文
	FuseLocalization_class.set_locale("zh_CN")
	var zh_result = FuseLocalization_class.translate("FUSE_UI_INSTRUCTION_SELECTOR_TITLE")

	if zh_result == "指令选择器":
		print("  ✓ 中文切换成功: %s" % zh_result)
	else:
		test_pass = false
		errors.append("  - 中文切换失败: %s" % zh_result)

	# 记录结果
	var result = {
		"test_name": "语言切换",
		"index": current_test_index,
		"passed": test_pass,
		"errors": errors
	}
	test_results.append(result)

	# 输出结果
	if test_pass:
		print("  ✓ 测试通过\n")
	else:
		print("  ✗ 测试失败")
		for error in errors:
			print(error)
		print()

	await get_tree().process_frame


## 测试10: 回退机制
func test_fallback_mechanism() -> void:
	current_test_index = 10
	print("测试 %d: 回退机制" % current_test_index)

	var test_pass: bool = true
	var errors: Array[String] = []

	# 测试不存在的翻译键
	var fake_key = "FUSE_FAKE_TRANSLATION_KEY_12345"
	var result = FuseLocalization_class.translate(fake_key)

	# 应该返回原始键
	if result == fake_key:
		print("  ✓ 缺失翻译键回退正常: 返回原始键")
	else:
		test_pass = false
		errors.append("  - 缺失翻译键回退失败: 期望 '%s', 实际 '%s'" % [fake_key, result])

	# 记录结果
	var result_dict = {
		"test_name": "回退机制",
		"index": current_test_index,
		"passed": test_pass,
		"errors": errors
	}
	test_results.append(result_dict)

	# 输出结果
	if test_pass:
		print("  ✓ 测试通过\n")
	else:
		print("  ✗ 测试失败")
		for error in errors:
			print(error)
		print()

	await get_tree().process_frame


## 打印测试摘要
func print_test_summary() -> void:
	print("\n================================================================================")
	print("测试摘要")
	print("================================================================================\n")

	var passed_count: int = 0
	var failed_count: int = 0

	for result in test_results:
		if result["passed"]:
			passed_count += 1
		else:
			failed_count += 1

	var total_count: int = test_results.size()
	var pass_rate: float = float(passed_count) / float(total_count) * 100.0

	print("总测试数: %d" % total_count)
	print("通过: %d" % passed_count)
	print("失败: %d" % failed_count)
	print("通过率: %.1f%%" % pass_rate)
	print()

	if failed_count > 0:
		print("失败的测试:")
		for result in test_results:
			if not result["passed"]:
				print("  - 测试 %d: %s" % [result["index"], result["test_name"]])
				for error in result["errors"]:
					print("    %s" % error)
		print()

	print("================================================================================")
	if pass_rate == 100.0:
		print("✓ 所有测试通过!")
	else:
		print("✗ 部分测试失败，请检查上述错误信息")
	print("================================================================================\n")

	# 输出翻译统计
	print("\n翻译统计:")
	var stats = FuseLocalization_class.get_translation_stats()
	print("  - 翻译键总数: %d" % stats.total_keys)
	print("  - 当前语言: %s" % stats.current_locale)
	print("  - 中文覆盖率: %.1f%%" % stats.zh_CN_coverage)
	print("  - 英文覆盖率: %.1f%%" % stats.en_US_coverage)
	print()
