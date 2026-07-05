## 指令选择器本地化测试
##
## 验证指令选择器对话框的标题和搜索框占位符是否正确本地化

extends SceneTree


func _init():
	print("=== 指令选择器本地化测试 ===")
	# 先初始化系统，避免未初始化警告
	test_localization_system_initialization()
	# 然后测试其他功能
	test_localization_keys_exist()
	test_instruction_selector_localization()
	test_fallback_text()
	print("\n=== 测试完成 ===")
	quit()

## 测试1: 验证翻译键是否存在
func test_localization_keys_exist() -> void:
	print("\n[测试1] 验证翻译键是否存在...")

	var FuseLocalization_class = load("res://addons/fuse/localization/fuse_localization.gd")
	assert(FuseLocalization_class != null, "FuseLocalization 类加载失败")

	# 检查翻译键
	var title_key = "FUSE_UI_INSTRUCTION_SELECTOR_TITLE"
	var search_key = "FUSE_UI_SEARCH_PLACEHOLDER"

	var title_zh = FuseLocalization_class.translate(title_key)
	var search_zh = FuseLocalization_class.translate(search_key)

	assert(title_zh != title_key, "指令选择器标题键未找到翻译")
	assert(search_zh != search_key, "搜索框占位符键未找到翻译")

	print("  ✓ 指令选择器标题（中文）: ", title_zh)
	print("  ✓ 搜索框占位符（中文）: ", search_zh)

## 测试2: 验证本地化系统初始化
func test_localization_system_initialization() -> void:
	print("\n[测试2] 验证本地化系统初始化...")

	var FuseLocalization_class = load("res://addons/fuse/localization/fuse_localization.gd")

	# 测试中文翻译
	FuseLocalization_class.init()
	FuseLocalization_class.set_locale("zh_CN")
	var locale_code = FuseLocalization_class.get_locale_code()
	assert(locale_code == "zh_CN", "语言设置失败，期望 zh_CN，实际 " + locale_code)

	print("  ✓ 本地化系统已初始化")
	print("  ✓ 当前语言: ", locale_code)

## 测试3: 测试指令选择器本地化
func test_instruction_selector_localization() -> void:
	print("\n[测试3] 测试指令选择器本地化...")

	var FuseLocalization_class = load("res://addons/fuse/localization/fuse_localization.gd")

	# 测试中文翻译
	FuseLocalization_class.set_locale("zh_CN")
	var title_zh = FuseLocalization_class.translate("FUSE_UI_INSTRUCTION_SELECTOR_TITLE")
	var search_zh = FuseLocalization_class.translate("FUSE_UI_SEARCH_PLACEHOLDER")

	assert(title_zh == "指令选择器", "中文标题翻译错误: " + title_zh)
	assert(search_zh == "搜索指令...", "中文搜索框占位符翻译错误: " + search_zh)

	print("  ✓ 中文标题: ", title_zh)
	print("  ✓ 中文搜索框: ", search_zh)

	# 测试英文翻译
	FuseLocalization_class.set_locale("en_US")
	var title_en = FuseLocalization_class.translate("FUSE_UI_INSTRUCTION_SELECTOR_TITLE")
	var search_en = FuseLocalization_class.translate("FUSE_UI_SEARCH_PLACEHOLDER")

	assert(title_en == "Instruction Selector", "英文标题翻译错误: " + title_en)
	assert(search_en == "Search instructions...", "英文搜索框占位符翻译错误: " + search_en)

	print("  ✓ 英文标题: ", title_en)
	print("  ✓ 英文搜索框: ", search_en)

## 测试4: 验证回退文本
func test_fallback_text() -> void:
	print("\n[测试4] 验证回退文本...")

	# 测试不存在的翻译键
	var FuseLocalization_class = load("res://addons/fuse/localization/fuse_localization.gd")
	var missing_key = "FUSE_UI_NONEXISTENT_KEY"
	var fallback = FuseLocalization_class.translate(missing_key)

	assert(fallback == missing_key, "回退文本应该返回原始键")
	print("  ✓ 回退文本机制正常工作")

## 运行所有测试
func run_all_tests():
	test_localization_keys_exist()
	test_localization_system_initialization()
	test_instruction_selector_localization()
	test_fallback_text()
	print("\n=== 所有测试通过 ===")
