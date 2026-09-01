extends Node

## 阶段4集成测试
## 测试本地化系统的完整性和性能

func _ready():
	print("================================================================================")
	print("阶段4本地化集成测试")
	print("================================================================================")

	var test_count = 0
	var passed = 0

	# 测试1: 翻译键数量
	print("\n测试 1: 翻译键数量统计")
	test_count += 1
	if _test_translation_key_count():
		passed += 1
		print("  ✅ 通过")
	else:
		print("  ❌ 失败")

	# 测试2: 翻译完整性
	print("\n测试 2: 翻译完整性")
	test_count += 1
	if _test_translation_completeness():
		passed += 1
		print("  ✅ 通过")
	else:
		print("  ❌ 失败")

	# 测试3: 性能基准
	print("\n测试 3: 性能基准")
	test_count += 1
	if _test_performance():
		passed += 1
		print("  ✅ 通过")
	else:
		print("  ❌ 失败")

	# 测试4: 语言检测
	print("\n测试 4: 语言检测机制")
	test_count += 1
	if _test_locale_detection():
		passed += 1
		print("  ✅ 通过")
	else:
		print("  ❌ 失败")

	# 测试5: 参数化翻译
	print("\n测试 5: 参数化翻译功能")
	test_count += 1
	if _test_parameterized_translation():
		passed += 1
		print("  ✅ 通过")
	else:
		print("  ❌ 失败")

	# 测试6: 翻译覆盖率
	print("\n测试 6: 翻译覆盖率")
	test_count += 1
	if _test_coverage():
		passed += 1
		print("  ✅ 通过")
	else:
		print("  ❌ 失败")

	# 总结
	print("\n================================================================================")
	print("测试总结: %d/%d 通过 (%.1f%%)" % [passed, test_count, float(passed) / test_count * 100])
	print("================================================================================")

	# 退出
	await get_tree().process_frame
	get_tree().quit()


func _test_translation_key_count() -> bool:
	var FuseLocalization = load("res://addons/fuse/localization/fuse_localization.gd")
	FuseLocalization.init()
	var stats = FuseLocalization.get_translation_stats()

	print("  总翻译键数: %d" % stats.total_keys)
	print("  中文覆盖率: %.1f%%" % stats.zh_CN_coverage)
	print("  英文覆盖率: %.1f%%" % stats.en_US_coverage)

	return stats.total_keys >= 295 and stats.zh_CN_coverage == 100.0 and stats.en_US_coverage == 100.0


func _test_translation_completeness() -> bool:
	var FuseLocalization = load("res://addons/fuse/localization/fuse_localization.gd")
	FuseLocalization.init()
	var missing = FuseLocalization.get_missing_translations()

	if not missing.is_empty():
		print("  ⚠️  发现 %d 个缺失的翻译" % missing.size())
		for key in missing:
			print("    - %s" % key)
		return false

	print("  没有缺失的翻译")
	return true


func _test_performance() -> bool:
	var FuseLocalization = load("res://addons/fuse/localization/fuse_localization.gd")
	FuseLocalization.init()

	# 测试1000次翻译查询
	var iterations = 1000
	var start = Time.get_ticks_usec()
	for i in range(iterations):
		FuseLocalization.translate("FUSE_INSTRUCTION_PRINT_NAME")
	var elapsed = Time.get_ticks_usec() - start
	var avg_time = elapsed / float(iterations)

	print("  %d 次查询耗时: %d μs" % [iterations, elapsed])
	print("  平均时间: %.2f μs/次" % avg_time)
	print("  性能目标: < 1.0 μs/次")

	return avg_time < 1.0  # 小于1μs为优秀


func _test_locale_detection() -> bool:
	var FuseLocalization = load("res://addons/fuse/localization/fuse_localization.gd")

	# 测试重新加载
	FuseLocalization.reload_translations()
	var current_locale = FuseLocalization.get_current_locale()

	print("  当前语言: %s" % current_locale)
	print("  语言代码: %s" % FuseLocalization.get_locale_code())

	# 验证语言代码格式
	var locale_code = FuseLocalization.get_locale_code()
	var valid_codes = ["zh_CN", "en_US", "unknown"]

	if not locale_code in valid_codes:
		print("  ❌ 无效的语言代码: %s" % locale_code)
		return false

	return true


func _test_parameterized_translation() -> bool:
	var FuseLocalization = load("res://addons/fuse/localization/fuse_localization.gd")
	FuseLocalization.init()

	# 测试参数化翻译
	var result1 = FuseLocalization.translate_format("FUSE_ERROR_VAR_NOT_FOUND", {"name": "test_var"})
	var result2 = FuseLocalization.tr_format("FUSE_ERROR_VAR_NOT_FOUND", {"name": "my_var"})

	print("  参数化翻译1: %s" % result1)
	print("  参数化翻译2: %s" % result2)

	# 验证参数被替换
	if not "test_var" in result1:
		print("  ❌ 参数替换失败")
		return false

	if not "my_var" in result2:
		print("  ❌ tr_format 别名失败")
		return false

	return true


func _test_coverage() -> bool:
	var FuseLocalization = load("res://addons/fuse/localization/fuse_localization.gd")
	FuseLocalization.init()

	# 测试一些常见的翻译键
	var test_keys = [
		"FUSE_INSTRUCTION_PRINT_NAME",
		"FUSE_INSTRUCTION_PRINT_DESC",
		"FUSE_CATEGORY_DEBUG",
		"FUSE_ERROR_VAR_NAME_EMPTY",
		"FUSE_LOG_EXECUTION_STARTED",
		"FUSE_TYPE_BOOL",
		"FUSE_VARIABLE_SCOPE_LOCAL"
	]

	var missing_count = 0
	for key in test_keys:
		var translation = FuseLocalization.translate(key)
		if translation == key:
			# 返回了原键，说明翻译缺失
			print("  ⚠️  缺失翻译: %s" % key)
			missing_count += 1

	if missing_count > 0:
		print("  ❌ %d 个测试键缺失翻译" % missing_count)
		return false

	print("  所有测试键都有翻译")
	return true
