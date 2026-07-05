extends SceneTree

## 调试脚本：检查不同来源的 locale 设置

func _init():
	print("================================================================================")
	print("Locale 调试信息")
	print("================================================================================")

	# 1. TranslationServer.get_locale() - 操作系统语言
	var os_locale = TranslationServer.get_locale()
	print("\n1. TranslationServer.get_locale():")
	print("   值: %s" % os_locale)

	# 2. 编辑器设置（如果可用）
	if ClassDB.class_exists("EditorInterface"):
		print("\n2. EditorInterface (编辑器环境):")
		var editor_settings = EditorInterface.get_editor_settings()
		if editor_settings:
			var editor_locale = editor_settings.get_setting("interface/editor/editor_language")
			print("   编辑器语言: %s" % editor_locale)
		else:
			print("   无法获取编辑器设置")
	else:
		print("\n2. EditorInterface: 不可用（运行时环境）")

	# 3. 项目设置
	print("\n3. 项目设置:")
	var project_settings = ProjectSettings.get_setting("internationalization/locale/locale")
	print("   项目 locale: %s" % str(project_settings))
	var test_locale = ProjectSettings.get_setting("internationalization/locale/test")
	print("   项目 test locale: %s" % str(test_locale))
	var fallback = ProjectSettings.get_setting("internationalization/locale/fallback")
	print("   项目 fallback locale: %s" % str(fallback))

	# 4. OS 检测
	print("\n4. OS 相关:")
	if OS.has_feature("editor"):
		print("   当前环境: 编辑器")
	else:
		print("   当前环境: 运行时")

	print("================================================================================")
	quit()
