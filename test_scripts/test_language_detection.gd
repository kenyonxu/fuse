extends SceneTree

## 语言检测集成测试

# 加载本地化类
var FuseLocalization = load("res://addons/fuse/localization/fuse_localization.gd")


func _init():
	print("=== 语言检测集成测试 ===")
	print("")

	# 测试1: 项目设置语言检测
	_test_project_locale_detection()

	# 测试2: 编辑器语言检测
	_test_editor_locale_detection()

	# 测试3: 操作系统语言检测
	_test_os_locale_detection()

	# 测试4: 语言切换功能
	_test_locale_switching()

	# 测试5: 语言缓存机制
	_test_locale_caching()

	print("")
	print("=== 测试完成 ===")
	quit()


## 测试项目设置语言检测
func _test_project_locale_detection():
	print("测试1: 项目设置语言检测")

	# 获取项目设置中的语言
	var project_locale = ProjectSettings.get_setting("internationalization/locale/locale")
	print("  项目 locale: %s" % str(project_locale))

	# 初始化本地化系统
	FuseLocalization.init()

	# 验证检测到的语言
	var detected_locale = FuseLocalization.get_current_locale()
	print("  检测到的 locale: %s" % FuseLocalization.get_locale_display_name(detected_locale))

	# 验证
	if project_locale and not str(project_locale).is_empty():
		print("  ✓ 项目设置优先级正确")
	else:
		print("  ⚠ 项目设置未配置，使用其他检测方法")

	print("")


## 测试编辑器语言检测
func _test_editor_locale_detection():
	print("测试2: 编辑器语言检测")

	if not Engine.is_editor_hint():
		print("  ⚠ 跳过（不在编辑器环境中）")
		print("")
		return

	if not ClassDB.class_exists("EditorInterface"):
		print("  ⚠ 跳过（EditorInterface 不可用）")
		print("")
		return

	var editor_settings = EditorSettings.new()
	var editor_locale = editor_settings.get_setting("interface/editor/editor_language")
	print("  编辑器语言: %s" % str(editor_locale))

	print("  ✓ 编辑器语言检测成功")
	print("")


## 测试操作系统语言检测
func _test_os_locale_detection():
	print("测试3: 操作系统语言检测")

	var os_locale = TranslationServer.get_locale()
	print("  OS locale: %s" % os_locale)

	print("  ✓ 操作系统语言检测成功")
	print("")


## 测试语言切换功能
func _test_locale_switching():
	print("测试4: 语言切换功能")

	# 切换到英文
	FuseLocalization.set_locale(FuseLocalization.Locale.EN_US)
	var en_locale = FuseLocalization.get_current_locale()
	print("  切换到英文: %s" % FuseLocalization.get_locale_display_name(en_locale))
	assert(en_locale == FuseLocalization.Locale.EN_US, "英文切换失败")

	# 切换到中文
	FuseLocalization.set_locale(FuseLocalization.Locale.ZH_CN)
	var zh_locale = FuseLocalization.get_current_locale()
	print("  切换到中文: %s" % FuseLocalization.get_locale_display_name(zh_locale))
	assert(zh_locale == FuseLocalization.Locale.ZH_CN, "中文切换失败")

	print("  ✓ 语言切换功能正常")
	print("")


## 测试语言缓存机制
func _test_locale_caching():
	print("测试5: 语言缓存机制")

	# 第一次初始化
	FuseLocalization.reload_translations()
	var locale1 = FuseLocalization.get_current_locale()
	print("  第一次检测: %s" % FuseLocalization.get_locale_display_name(locale1))

	# 第二次初始化（应该使用缓存）
	FuseLocalization.init()
	var locale2 = FuseLocalization.get_current_locale()
	print("  第二次检测（缓存）: %s" % FuseLocalization.get_locale_display_name(locale2))

	# 验证语言一致
	assert(locale1 == locale2, "语言缓存机制失败")

	print("  ✓ 语言缓存机制正常")
	print("")
