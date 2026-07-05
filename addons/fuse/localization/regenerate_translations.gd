@tool
extends EditorScript

## 从 translations.csv 重新生成 .translation 文件
## 在翻译条目变更后运行此脚本,使新翻译键在编辑器中生效
##
## 运行方式: Godot 编辑器 → Script 编辑器 → File → Run(或 File > Run Script)

const CSV_PATH = "res://addons/fuse/localization/translations.csv"
const ZH_PATH = "res://addons/fuse/localization/fuse.zh_CN.translation"
const EN_PATH = "res://addons/fuse/localization/fuse.en_US.translation"


func _run() -> void:
	print("=== 重新生成 .translation 文件 ===")

	var file = FileAccess.open(CSV_PATH, FileAccess.READ)
	if not file:
		printerr("无法打开翻译文件: %s" % CSV_PATH)
		return

	# 跳过标题
	file.get_line()

	var zh = Translation.new()
	zh.locale = "zh_CN"
	var en = Translation.new()
	en.locale = "en_US"
	var count := 0

	while not file.eof_reached():
		var line = file.get_line()
		if line.is_empty() or line.strip_edges().begins_with("#"):
			continue
		var parts = _parse_csv(line)
		if parts.size() < 3:
			continue
		var key = parts[0].strip_edges()
		zh.add_message(key, parts[1].strip_edges().replace('"', ""))
		en.add_message(key, parts[2].strip_edges().replace('"', ""))
		count += 1

	file.close()

	var err_zh = ResourceSaver.save(zh, ZH_PATH)
	var err_en = ResourceSaver.save(en, EN_PATH)
	if err_zh == OK and err_en == OK:
		print("✓ 成功生成 %d 条翻译 → fuse.zh_CN.translation + fuse.en_US.translation" % count)
		# 通知文件系统刷新
		var eds = EditorInterface.get_resource_filesystem()
		if eds:
			eds.scan()
	else:
		printerr("❌ 保存失败 zh=%d en=%d" % [err_zh, err_en])


func _parse_csv(line: String) -> Array:
	var result = []
	var current = ""
	var in_quotes = false
	for i in range(line.length()):
		var c = line[i]
		if c == '"':
			in_quotes = not in_quotes
		elif c == ',' and not in_quotes:
			result.append(current)
			current = ""
		else:
			current += c
	if not current.is_empty() or in_quotes:
		result.append(current)
	return result
