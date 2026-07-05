# 文件：addons/fuse/editor/input_key_selector/test_input_key_selector_localization.gd
@tool
extends EditorScript

## 测试输入键选择器本地化功能
##
## 使用方法：
## 1. 在 Godot 编辑器中，点击 Project -> Tools -> Execute Script
## 2. 选择此测试脚本
## 3. 查看控制台输出验证本地化是否正常工作

func _run() -> void:
	print("========================================")
	print("输入键选择器本地化测试")
	print("========================================")

	# 加载本地化类
	var localization_path = "res://addons/fuse/localization/fuse_localization.gd"
	var localization_class = load(localization_path)

	if not localization_class:
		print("❌ 错误: 无法加载本地化类")
		return

	print("✅ 本地化类加载成功")

	# 初始化本地化系统
	if localization_class.has_method("init"):
		localization_class.init()
		print("✅ 本地化系统已初始化")
		print("   当前语言: ", localization_class.get_locale_code())

	# 测试所有输入键选择器相关的翻译键
	var test_keys = [
		"FUSE_UI_INPUT_KEY_SELECTOR_TITLE",
		"FUSE_UI_BTN_SELECT_KEY",
		"FUSE_UI_KEY_LABEL",
		"FUSE_UI_INSTRUCTION_CLICK_TO_START",
		"FUSE_UI_BTN_START_CAPTURE",
		"FUSE_UI_WAITING_FOR_KEY"
	]

	print("\n----------------------------------------")
	print("翻译键测试:")
	print("----------------------------------------")

	for key in test_keys:
		var translation = localization_class.translate(key) if localization_class.has_method("translate") else key
		var status = "✅" if (translation != key) else "⚠️"
		print("%s %s: %s" % [status, key, translation])

	# 测试中英文切换
	print("\n----------------------------------------")
	print("语言切换测试:")
	print("----------------------------------------")

	# 切换到中文
	if localization_class.has_method("set_locale"):
		localization_class.set_locale("zh_CN")
		print("切换到中文:")
		print("  对话框标题: %s" % localization_class.translate("FUSE_UI_INPUT_KEY_SELECTOR_TITLE"))
		print("  按键标签: %s" % localization_class.translate("FUSE_UI_KEY_LABEL"))

		# 切换到英文
		localization_class.set_locale("en_US")
		print("切换到英文:")
		print("  对话框标题: %s" % localization_class.translate("FUSE_UI_INPUT_KEY_SELECTOR_TITLE"))
		print("  按键标签: %s" % localization_class.translate("FUSE_UI_KEY_LABEL"))

	# 测试回退文本
	print("\n----------------------------------------")
	print("回退文本测试:")
	print("----------------------------------------")

	var missing_key = "FUSE_UI_NONEXISTENT_KEY"
	var fallback = localization_class.translate(missing_key) if localization_class.has_method("translate") else missing_key
	print("不存在的键 '%s' 返回: %s" % [missing_key, fallback])
	if fallback == missing_key:
		print("✅ 回退机制正常")
	else:
		print("❌ 回退机制异常")

	print("\n========================================")
	print("测试完成")
	print("========================================")
	print("\n提示: 如果所有测试都显示 ✅，说明本地化功能正常。")
	print("可以在编辑器中打开 InputKeySelector 查看实际效果。")
