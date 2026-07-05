extends Node

## Fuse 本地化系统测试运行器
##
## 不依赖外部测试框架，可以直接运行

# 测试统计
var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0
var test_results: Array[Dictionary] = []

# 测试开始时间
var start_time: int = 0


func _ready():
	print("=".repeat(60))
	print("Fuse 本地化系统测试")
	print("=".repeat(60))
	print("")

	start_time = Time.get_ticks_msec()

	# 初始化本地化系统
	_initialize_localization()

	# 运行所有测试
	_run_all_tests()

	# 输出测试结果
	_print_results()

	# 退出
	get_tree().quit()


## 初始化本地化系统
func _initialize_localization():
	print("初始化本地化系统...")

	var FuseLocalization_class = load("res://addons/fuse/localization/fuse_localization.gd")
	if FuseLocalization_class and FuseLocalization_class.has_method("init"):
		FuseLocalization_class.init()
		print("✓ 本地化系统初始化成功")
		print("")

		# 输出翻译统计
		if FuseLocalization_class.has_method("get_translation_stats"):
			var stats = FuseLocalization_class.get_translation_stats()
			print("翻译统计:")
			print("  总翻译键: %d" % stats.total_keys)
			print("  中文覆盖率: %.1f%%" % stats.zh_CN_coverage)
			print("  英文覆盖率: %.1f%%" % stats.en_US_coverage)
			print("  当前语言: %s" % stats.current_locale)
			print("")
	else:
		print("✗ 本地化系统初始化失败")
		get_tree().quit()


## 运行所有测试
func _run_all_tests():
	print("开始运行测试...")
	print("")

	test_loading_translations()
	test_basic_translation_zh_cn()
	test_basic_translation_en_us()
	test_parameterized_translation()
	test_parameterized_translation_zh()
	test_language_switching()
	test_missing_translation()
	test_get_locale_display_name()
	test_get_locale_code()
	test_translation_coverage()
	test_instruction_metadata_localization()
	test_instruction_metadata_backward_compatibility()
	test_multiple_parameter_replacement()


## 测试：加载翻译
func test_loading_translations():
	var test_name = "加载翻译"
	var FuseLocalization_class = load("res://addons/fuse/localization/fuse_localization.gd")

	var stats = FuseLocalization_class.get_translation_stats()
	var passed = stats.total_keys > 0

	_record_test(test_name, passed, "应该加载至少一个翻译键", "总键数: %d" % stats.total_keys)


## 测试：中文翻译
func test_basic_translation_zh_cn():
	var test_name = "中文翻译"
	var FuseLocalization_class = load("res://addons/fuse/localization/fuse_localization.gd")

	FuseLocalization_class.set_locale("zh_CN")
	var result = FuseLocalization_class.translate("FUSE_INSTRUCTION_PRINT_NAME")
	var expected = "打印消息"
	var passed = result == expected

	_record_test(test_name, passed, "应该翻译为中文", "期望: '%s' | 实际: '%s'" % [expected, result])


## 测试：英文翻译
func test_basic_translation_en_us():
	var test_name = "英文翻译"
	var FuseLocalization_class = load("res://addons/fuse/localization/fuse_localization.gd")

	FuseLocalization_class.set_locale("en_US")
	var result = FuseLocalization_class.translate("FUSE_INSTRUCTION_PRINT_NAME")
	var expected = "Print Message"
	var passed = result == expected

	_record_test(test_name, passed, "应该翻译为英文", "期望: '%s' | 实际: '%s'" % [expected, result])


## 测试：参数化翻译（英文）
func test_parameterized_translation():
	var test_name = "参数化翻译(英文)"
	var FuseLocalization_class = load("res://addons/fuse/localization/fuse_localization.gd")

	FuseLocalization_class.set_locale("en_US")
	var result = FuseLocalization_class.translate_format("FUSE_ERROR_VAR_NOT_FOUND", {"name": "my_var"})
	var expected = "Variable 'my_var' not found"
	var passed = result == expected

	_record_test(test_name, passed, "应该正确格式化参数", "期望: '%s' | 实际: '%s'" % [expected, result])


## 测试：参数化翻译（中文）
func test_parameterized_translation_zh():
	var test_name = "参数化翻译(中文)"
	var FuseLocalization_class = load("res://addons/fuse/localization/fuse_localization.gd")

	FuseLocalization_class.set_locale("zh_CN")
	var result = FuseLocalization_class.translate_format("FUSE_ERROR_VAR_NOT_FOUND", {"name": "my_var"})
	var expected = "未找到变量：my_var"
	var passed = result == expected

	_record_test(test_name, passed, "应该正确格式化中文参数", "期望: '%s' | 实际: '%s'" % [expected, result])


## 测试：语言切换
func test_language_switching():
	var test_name = "语言切换"
	var FuseLocalization_class = load("res://addons/fuse/localization/fuse_localization.gd")

	var all_passed = true
	var details = []

	# 切换到中文
	FuseLocalization_class.set_locale("zh_CN")
	var zh_result = FuseLocalization_class.translate("FUSE_INSTRUCTION_PRINT_NAME")
	if zh_result != "打印消息":
		all_passed = false
		details.append("中文失败: '%s'" % zh_result)

	# 切换到英文
	FuseLocalization_class.set_locale("en_US")
	var en_result = FuseLocalization_class.translate("FUSE_INSTRUCTION_PRINT_NAME")
	if en_result != "Print Message":
		all_passed = false
		details.append("英文失败: '%s'" % en_result)

	# 切换回中文
	FuseLocalization_class.set_locale("zh_CN")
	var zh_result2 = FuseLocalization_class.translate("FUSE_INSTRUCTION_PRINT_NAME")
	if zh_result2 != "打印消息":
		all_passed = false
		details.append("切换回中文失败: '%s'" % zh_result2)

	if details.is_empty():
		details.append("语言切换正常")

	_record_test(test_name, all_passed, "应该正确切换语言", ", ".join(details))


## 测试：缺失翻译回退
func test_missing_translation():
	var test_name = "缺失翻译回退"
	var FuseLocalization_class = load("res://addons/fuse/localization/fuse_localization.gd")

	var result = FuseLocalization_class.translate("NONEXISTENT_KEY")
	var passed = result == "NONEXISTENT_KEY"

	_record_test(test_name, passed, "缺失翻译时应该返回原始键", "返回: '%s'" % result)


## 测试：语言显示名称
func test_get_locale_display_name():
	var test_name = "语言显示名称"
	var FuseLocalization_class = load("res://addons/fuse/localization/fuse_localization.gd")

	var zh_name = FuseLocalization_class.get_locale_display_name("zh_CN")
	var en_name = FuseLocalization_class.get_locale_display_name("en_US")

	var passed = zh_name == "简体中文" and en_name == "English"

	_record_test(test_name, passed, "应该返回正确的显示名称", "中文: '%s' | 英文: '%s'" % [zh_name, en_name])


## 测试：语言代码
func test_get_locale_code():
	var test_name = "语言代码"
	var FuseLocalization_class = load("res://addons/fuse/localization/fuse_localization.gd")

	FuseLocalization_class.set_locale("zh_CN")
	var zh_code = FuseLocalization_class.get_locale_code()

	FuseLocalization_class.set_locale("en_US")
	var en_code = FuseLocalization_class.get_locale_code()

	var passed = zh_code == "zh_CN" and en_code == "en_US"

	_record_test(test_name, passed, "应该返回正确的语言代码", "中文: '%s' | 英文: '%s'" % [zh_code, en_code])


## 测试：翻译覆盖率
func test_translation_coverage():
	var test_name = "翻译覆盖率"
	var FuseLocalization_class = load("res://addons/fuse/localization/fuse_localization.gd")

	var stats = FuseLocalization_class.get_translation_stats()
	var passed = stats.total_keys > 100 and stats.zh_CN_coverage == 100.0 and stats.en_US_coverage == 100.0

	_record_test(test_name, passed, "应该有超过100个键且100%覆盖", "总键: %d | 中文: %.1f%% | 英文: %.1f%%" % [stats.total_keys, stats.zh_CN_coverage, stats.en_US_coverage])


## 测试：InstructionMetadata 本地化
func test_instruction_metadata_localization():
	var test_name = "InstructionMetadata 本地化"
	var InstructionMetadata_class = load("res://addons/fuse/editor/instruction_selector/instructions_metadata.gd")
	var FuseLocalization_class = load("res://addons/fuse/localization/fuse_localization.gd")

	var metadata = InstructionMetadata_class.new()
	metadata.name_key = "FUSE_INSTRUCTION_PRINT_NAME"
	metadata.category_key = "FUSE_CATEGORY_DEBUG"
	metadata.description_key = "FUSE_INSTRUCTION_PRINT_DESC"

	var all_passed = true
	var details = []

	# 测试中文
	FuseLocalization_class.set_locale("zh_CN")
	var zh_name = metadata.get_localized_name()
	var zh_category = metadata.get_localized_category()

	if zh_name != "打印消息":
		all_passed = false
		details.append("中文名称失败: '%s'" % zh_name)

	if zh_category != "调试":
		all_passed = false
		details.append("中文分类失败: '%s'" % zh_category)

	# 测试英文
	FuseLocalization_class.set_locale("en_US")
	var en_name = metadata.get_localized_name()
	var en_category = metadata.get_localized_category()

	if en_name != "Print Message":
		all_passed = false
		details.append("英文名称失败: '%s'" % en_name)

	if en_category != "Debug":
		all_passed = false
		details.append("英文分类失败: '%s'" % en_category)

	if details.is_empty():
		details.append("元数据本地化正常")

	_record_test(test_name, all_passed, "元数据应该正确本地化", ", ".join(details))


## 测试：InstructionMetadata 向后兼容
func test_instruction_metadata_backward_compatibility():
	var test_name = "InstructionMetadata 向后兼容"
	var InstructionMetadata_class = load("res://addons/fuse/editor/instruction_selector/instructions_metadata.gd")

	var metadata = InstructionMetadata_class.new()
	metadata.name = "Test Instruction"
	metadata.category = "Test Category"
	metadata.description = "Test Description"

	var name_ok = metadata.get_localized_name() == "Test Instruction"
	var category_ok = metadata.get_localized_category() == "Test Category"
	var desc_ok = metadata.get_localized_description() == "Test Description"

	var passed = name_ok and category_ok and desc_ok

	_record_test(test_name, passed, "应该回退到旧字段", "名称: %s | 分类: %s | 描述: %s" % [name_ok, category_ok, desc_ok])


## 测试：多参数替换
func test_multiple_parameter_replacement():
	var test_name = "多参数替换"
	var FuseLocalization_class = load("res://addons/fuse/localization/fuse_localization.gd")

	FuseLocalization_class.set_locale("en_US")
	var result = FuseLocalization_class.translate_format("FUSE_ERROR_VAR_NOT_FOUND", {"name": "var1"})
	var passed = result.contains("var1")

	_record_test(test_name, passed, "应该正确替换参数", "结果: '%s'" % result)


## 记录测试结果
func _record_test(name: String, passed: bool, description: String, details: String = ""):
	total_tests += 1

	if passed:
		passed_tests += 1
		print("✓ %s" % name)
	else:
		failed_tests += 1
		print("✗ %s" % name)

	print("  %s" % description)
	if not details.is_empty():
		print("  %s" % details)
	print("")

	test_results.append({
		"name": name,
		"passed": passed,
		"description": description,
		"details": details
	})


## 打印测试结果
func _print_results():
	var elapsed_time = (Time.get_ticks_msec() - start_time) / 1000.0

	print("")
	print("=".repeat(60))
	print("测试完成")
	print("=".repeat(60))
	print("")
	print("总测试数: %d" % total_tests)
	print("通过: %d" % passed_tests)
	print("失败: %d" % failed_tests)
	print("耗时: %.3f 秒" % elapsed_time)

	if failed_tests == 0:
		print("")
		print("🎉 所有测试通过！")
	else:
		print("")
		print("⚠️  有 %d 个测试失败" % failed_tests)
		print("")
		print("失败的测试:")
		for result in test_results:
			if not result.passed:
				print("  - %s: %s" % [result.name, result.details])

	print("")
	print("=".repeat(60))
