extends SceneTree

## 简单的翻译完整性检查脚本

const CSV_PATH := "res://addons/fuse/localization/translations.csv"

func _init():
	print("=== Fuse 翻译完整性快速检查 ===")
	print("")

	var translation_data := {}
	var file := FileAccess.open(CSV_PATH, FileAccess.READ)

	if not file:
		print("❌ 无法打开翻译文件")
		quit(1)
		return

	# 读取翻译数据
	while not file.eof_reached():
		var line := file.get_line()
		if line.is_empty():
			continue

		var parts := line.split(",")
		if parts.size() < 2:
			continue

		var key := parts[0].strip_edges()
		if key.is_empty() or key.begins_with("#"):
			continue

		translation_data[key] = parts.slice(1)

	file.close()

	print("📊 翻译键统计:")
	print("  总翻译键数量: %d" % translation_data.size())

	# 分类统计
	var log_count := 0
	var error_count := 0
	var ui_count := 0
	var instruction_count := 0
	var event_count := 0
	var condition_count := 0
	var other_count := 0

	for key in translation_data:
		if key.begins_with("FUSE_LOG_"):
			log_count += 1
		elif key.begins_with("FUSE_ERROR_"):
			error_count += 1
		elif key.begins_with("FUSE_UI_"):
			ui_count += 1
		elif key.begins_with("FUSE_INSTRUCTION_"):
			instruction_count += 1
		elif key.begins_with("FUSE_EVENT_"):
			event_count += 1
		elif key.begins_with("FUSE_CONDITION_"):
			condition_count += 1
		else:
			other_count += 1

	print("\n📋 分类统计:")
	print("  日志 (LOG): %d" % log_count)
	print("  错误 (ERROR): %d" % error_count)
	print("  UI: %d" % ui_count)
	print("  指令 (INSTRUCTION): %d" % instruction_count)
	print("  事件 (EVENT): %d" % event_count)
	print("  条件 (CONDITION): %d" % condition_count)
	print("  其他: %d" % other_count)

	# 检查完整性
	print("\n🔍 完整性检查:")
	var incomplete := []
	var complete := 0

	for key in translation_data:
		var translations: Array = translation_data[key]
		if translations.size() >= 2 and not translations[0].is_empty() and not translations[1].is_empty():
			complete += 1
		else:
			incomplete.append(key)

	print("  完整翻译: %d" % complete)
	print("  不完整翻译: %d" % incomplete.size())

	if incomplete.size() > 0:
		print("\n⚠ 不完整的翻译键:")
		for key in incomplete:
			print("  - %s" % key)
	else:
		print("  ✓ 所有翻译键都完整！")

	print("\n=== 检查完成 ===")
	quit(0)
