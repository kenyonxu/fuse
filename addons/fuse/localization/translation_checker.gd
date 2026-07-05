@tool
extends EditorScript

## Fuse 本地化检查工具 v3.0
##
## 功能：
## 1. 统计翻译键数量（按类别）
## 2. 检查翻译完整性
## 3. 检查指令的本地化方法覆盖率
## 4. 检查事件的本地化方法覆盖率
## 5. 检查条件的本地化方法覆盖率
## 6. 检查翻译键命名规范
## 7. 检查代码中使用的翻译键是否在CSV中存在

const CSV_PATH := "res://addons/fuse/localization/translations.csv"
const INSTRUCTIONS_PATH := "res://addons/fuse/instructions/"
const EVENTS_PATH := "res://addons/fuse/events/"
const CONDITIONS_PATH := "res://addons/fuse/conditions/"

enum Category {
	ALL,
	LOG,
	UI,
	INSTRUCTION,
	EVENT,
	CONDITION,
	ERROR,
	VARIABLE,
	CATEGORY,
	SYSTEM
}

var _translation_data := {}
var _translation_keys_set := {}  # 用于快速查找

## 翻译键前缀映射
var _key_prefixes := {
	"LOG": "FUSE_LOG_",
	"UI": "FUSE_UI_",
	"INSTRUCTION": "FUSE_INSTRUCTION_",
	"EVENT": "FUSE_EVENT_",
	"CONDITION": "FUSE_CONDITION_",
	"ERROR": "FUSE_ERROR_",
	"VARIABLE": "FUSE_VARIABLE_",
	"CATEGORY": "FUSE_CATEGORY_",
	"SYSTEM": "FUSE_"
}

func _run() -> void:
	print("=== Fuse 本地化检查工具 v3.0 ===")
	print("")

	# 加载翻译数据
	if not _load_translations():
		return

	# 1. 分类统计翻译键
	_check_translation_keys_by_category()

	# 2. 检查翻译完整性
	_check_translation_completeness()

	# 3. 检查指令本地化
	_check_instructions_localization()

	# 4. 检查事件本地化
	_check_events_localization()

	# 5. 检查条件本地化
	_check_conditions_localization()

	# 6. 检查命名规范
	_check_naming_convention()

	# 7. 检查代码中使用的翻译键是否都在CSV中
	_check_translation_keys_exist_in_csv()

	print("")
	print("=== 检查完成 ===")

## 加载翻译数据
func _load_translations() -> bool:
	var file = FileAccess.open(CSV_PATH, FileAccess.READ)
	if not file:
		print("❌ 无法打开翻译文件: %s" % CSV_PATH)
		return false

	while not file.eof_reached():
		var line := file.get_line()
		if line.is_empty():
			continue

		# 过滤注释行
		var stripped := line.strip_edges()
		if stripped.begins_with("#"):
			continue

		var parts := line.split(",")
		if parts.size() < 2:
			continue

		var key := parts[0].strip_edges()
		if key.is_empty() or key.begins_with("#"):
			continue

		_translation_data[key] = parts.slice(1)
		_translation_keys_set[key] = true

	file.close()
	print("✓ 已加载 %d 个翻译键" % _translation_data.size())
	return true

## 分类统计翻译键
func _check_translation_keys_by_category() -> void:
	print("📊 翻译键分类统计:")

	var category_counts: Dictionary = {}
	for prefix_name in _key_prefixes:
		category_counts[prefix_name] = 0
	category_counts["OTHER"] = 0

	for key in _translation_data.keys():
		var categorized: bool = false
		for prefix_name in _key_prefixes:
			var prefix: String = _key_prefixes[prefix_name]
			if key.begins_with(prefix):
				category_counts[prefix_name] += 1
				categorized = true
				break

		if not categorized:
			category_counts["OTHER"] += 1

	var total: int = _translation_data.size()
	for prefix_name in _key_prefixes:
		var count: int = category_counts[prefix_name]
		if count > 0:
			var prefix: String = _key_prefixes[prefix_name]
			print("  %s: %d个" % [prefix.trim_suffix("_"), count])

	if category_counts["OTHER"] > 0:
		print("  其他: %d个" % category_counts["OTHER"])

	print("  总计: %d个" % total)
	print("  ✓ 达到目标（≥1000）" if total >= 1000 else "  ⚠ 未达到目标（<1000）")

## 检查翻译完整性
func _check_translation_completeness() -> void:
	print("")
	print("🔍 翻译完整性检查:")

	var incomplete_keys := []

	for key in _translation_data:
		var translations: Array = _translation_data[key]

		# 检查zh_CN和en是否都有翻译
		if translations.size() < 2 or translations[0].is_empty() or translations[1].is_empty():
			incomplete_keys.append(key)

	if incomplete_keys.is_empty():
		print("  ✓ 所有翻译键都有完整翻译（zh_CN, en_US）")
	else:
		print("  ⚠ 发现 %d 个不完整的翻译键:" % incomplete_keys.size())
		for key in incomplete_keys:
			print("    - %s" % key)

## 检查指令本地化
func _check_instructions_localization() -> void:
	print("")
	print("📋 指令本地化检查:")

	var dir := DirAccess.open(INSTRUCTIONS_PATH)
	if not dir:
		print("  ❌ 无法打开指令目录")
		return

	var stats := {
		total_files = 0,
		with_update_resource_name = 0,
		with_get_description = 0,
		with_localized_logs = 0,
		with_localized_errors = 0,
		with_metadata_keys = 0,
		uses_hardcoded_strings = []
	}

	# 遍历所有子目录
	_check_directory_recursive(dir, INSTRUCTIONS_PATH, stats, "instruction")

	var percentage := func(value: float, total: float) -> String:
		return "%.1f%%" % (value * 100.0 / total if total > 0 else 0) \
			if total > 0 else "N/A"

	print("  总指令文件数: %d" % stats.total_files)
	print("  实现了 _update_resource_name(): %d (%s)" % [
		stats.with_update_resource_name,
		percentage.call(float(stats.with_update_resource_name), float(stats.total_files))
	])
	print("  实现了 get_description(): %d (%s)" % [
		stats.with_get_description,
		percentage.call(float(stats.with_get_description), float(stats.total_files))
	])
	print("  使用本地化日志: %d (%s)" % [
		stats.with_localized_logs,
		percentage.call(float(stats.with_localized_logs), float(stats.total_files))
	])
	print("  使用本地化错误: %d (%s)" % [
		stats.with_localized_errors,
		percentage.call(float(stats.with_localized_errors), float(stats.total_files))
	])
	print("  使用元数据翻译键: %d (%s)" % [
		stats.with_metadata_keys,
		percentage.call(float(stats.with_metadata_keys), float(stats.total_files))
	])

	if not stats.uses_hardcoded_strings.is_empty():
		print("  ⚠ 可能有硬编码中文字符串的文件:")
		for file_info in stats.uses_hardcoded_strings:
			print("    - %s: %s" % [file_info.file, file_info.reason])

## 检查事件本地化
func _check_events_localization() -> void:
	print("")
	print("📋 事件本地化检查:")

	var dir := DirAccess.open(EVENTS_PATH)
	if not dir:
		print("  ❌ 无法打开事件目录")
		return

	var stats := {
		total_files = 0,
		with_update_resource_name = 0,
		with_get_description = 0,
		with_localized_validation = 0,
		with_metadata_keys = 0,
		uses_hardcoded_strings = []
	}

	_check_directory_recursive(dir, EVENTS_PATH, stats, "event")

	var percentage := func(value: float, total: float) -> String:
		return "%.1f%%" % (value * 100.0 / total if total > 0 else 0)

	print("  总事件文件数: %d" % stats.total_files)
	print("  实现了 _update_resource_name(): %d (%s)" % [
		stats.with_update_resource_name,
		percentage.call(float(stats.with_update_resource_name), float(stats.total_files))
	])
	print("  实现了 get_description(): %d (%s)" % [
		stats.with_get_description,
		percentage.call(float(stats.with_get_description), float(stats.total_files))
	])
	print("  使用本地化验证: %d (%s)" % [
		stats.with_localized_validation,
		percentage.call(float(stats.with_localized_validation), float(stats.total_files))
	])
	print("  使用元数据翻译键: %d (%s)" % [
		stats.with_metadata_keys,
		percentage.call(float(stats.with_metadata_keys), float(stats.total_files))
	])

	if not stats.uses_hardcoded_strings.is_empty():
		print("  ⚠ 可能有硬编码中文字符串的文件:")
		for file_info in stats.uses_hardcoded_strings:
			print("    - %s: %s" % [file_info.file, file_info.reason])

## 检查条件本地化
func _check_conditions_localization() -> void:
	print("")
	print("📋 条件本地化检查:")

	var dir := DirAccess.open(CONDITIONS_PATH)
	if not dir:
		print("  ❌ 无法打开条件目录")
		return

	var stats := {
		total_files = 0,
		with_update_resource_name = 0,
		with_metadata_keys = 0,
		uses_hardcoded_strings = []
	}

	_check_directory_recursive(dir, CONDITIONS_PATH, stats, "condition")

	var percentage := func(value: float, total: float) -> String:
		return "%.1f%%" % (value * 100.0 / total if total > 0 else 0)

	print("  总条件文件数: %d" % stats.total_files)
	print("  实现了 _update_resource_name(): %d (%s)" % [
		stats.with_update_resource_name,
		percentage.call(float(stats.with_update_resource_name), float(stats.total_files))
	])
	print("  使用元数据翻译键: %d (%s)" % [
		stats.with_metadata_keys,
		percentage.call(float(stats.with_metadata_keys), float(stats.total_files))
	])

	if not stats.uses_hardcoded_strings.is_empty():
		print("  ⚠ 可能有硬编码中文字符串的文件:")
		for file_info in stats.uses_hardcoded_strings:
			print("    - %s: %s" % [file_info.file, file_info.reason])

## 递归检查目录
func _check_directory_recursive(dir: DirAccess, base_path: String, stats: Dictionary, type: String) -> void:
	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue

		var full_path := base_path + file_name

		if dir.current_is_dir():
			var sub_dir := DirAccess.open(full_path)
			if sub_dir:
				_check_directory_recursive(sub_dir, full_path + "/", stats, type)
		elif file_name.ends_with(".gd"):
			_check_file_localization(full_path, stats, type)

		file_name = dir.get_next()

	dir.list_dir_end()

## 检查单个文件的本地化
func _check_file_localization(file_path: String, stats: Dictionary, type: String) -> void:
	var content := _read_file(file_path)
	if content.is_empty():
		return

	var relative_path := file_path.replace("res://addons/fuse/", "")
	stats.total_files += 1

	# 检查 _update_resource_name
	if content.contains("func _update_resource_name()"):
		stats.with_update_resource_name += 1
		# 更精确地检查：提取 _update_resource_name() 函数内容
		var func_content := _extract_function_content(content, "_update_resource_name")
		if not func_content.is_empty() and not func_content.contains("FuseLocalization.translate"):
			# 进一步检查：是否真的硬编码了中文
			var chinese_pattern := RegEx.new()
			chinese_pattern.compile("[一-龥]+")
			if chinese_pattern.search(func_content):
				stats.uses_hardcoded_strings.append({
					file = relative_path,
					reason = "_update_resource_name() 包含硬编码中文字符串"
				})

	# 检查 get_description
	if type in ["instruction", "event", "condition"]:
		if content.contains("func get_description()"):
			stats.with_get_description = stats.get("with_get_description", 0) + 1
			# 更精确地检查：提取 get_description() 函数内容
			var func_content := _extract_function_content(content, "get_description")
			if not func_content.is_empty() and not func_content.contains("FuseLocalization.translate"):
				# 进一步检查：是否真的硬编码了中文
				var chinese_pattern := RegEx.new()
				chinese_pattern.compile("[一-龥]+")
				if chinese_pattern.search(func_content):
					stats.uses_hardcoded_strings.append({
						file = relative_path,
						reason = "get_description() 包含硬编码中文字符串"
					})

	# 检查本地化日志（仅指令）
	if type == "instruction":
		if content.contains("_log_info_localized") or \
		   content.contains("_log_debug_localized") or \
		   content.contains("_log_warning_localized") or \
		   content.contains("_log_error_localized"):
			stats.with_localized_logs = stats.get("with_localized_logs", 0) + 1

	# 检查本地化错误
	if type == "instruction":
		if content.contains("_set_error_localized") or content.contains("set_error_localized"):
			stats.with_localized_errors = stats.get("with_localized_errors", 0) + 1

	# 检查本地化验证（事件）
	if type == "event":
		if content.contains("FuseLocalization.translate") and content.contains("validate"):
			stats.with_localized_validation = stats.get("with_localized_validation", 0) + 1

	# 检查元数据翻译键
	if content.contains("name_key") and content.contains("category_key"):
		stats.with_metadata_keys = stats.get("with_metadata_keys", 0) + 1

	# 检查硬编码中文字符串（改进版 v2 - 大幅减少误报）
	var chinese_pattern := RegEx.new()
	chinese_pattern.compile("[一-龥]+")

	# 只在特定函数中检查硬编码中文
	var target_functions := ["_update_resource_name", "get_description", "validate", "_get_property_list"]
	var has_hardcoded_chinese := false
	var hardcoded_reasons := []

	for func_name in target_functions:
		var func_content := _extract_function_content(content, func_name)
		if func_content.is_empty():
			continue

		# 跳过 metadata 块（metadata 中的中文关键词是符合规范的）
		var lines := func_content.split("\n")
		var in_metadata := false
		var metadata_indent := -1

		for i in range(lines.size()):
			var line := lines[i]
			var stripped := line.strip_edges()

			# 检测 metadata 块的开始
			if stripped.begins_with("metadata."):
				# 计算 metadata 的缩进级别
				metadata_indent = 0
				var j := 0
				while j < line.length() and (line[j] == '\t' or line[j] == ' '):
					if line[j] == '\t':
						metadata_indent += 1
					j += 1
				in_metadata = true
				continue

			# 检测 metadata 块的结束
			if in_metadata:
				var current_indent := 0
				var j := 0
				while j < line.length() and (line[j] == '\t' or line[j] == ' '):
					if line[j] == '\t':
						current_indent += 1
					j += 1
				# 如果缩进小于或等于 metadata 的缩进，说明已退出 metadata 块
				if current_indent <= metadata_indent and not stripped.begins_with("metadata."):
					in_metadata = false
				else:
					# 仍在 metadata 块中，跳过
					continue

			# 跳过空行和纯注释行
			if stripped.is_empty() or stripped.begins_with("#"):
				continue

			# 移除行尾注释
			var code_part := line
			if line.find("#") > 0:
				code_part = line.substr(0, line.find("#"))

			# 检查代码部分是否包含中文
			if chinese_pattern.search(code_part):
				# 排除已经使用本地化的情况（包括 translate 和 translate_format）
				if not code_part.contains("FuseLocalization.translate") and \
				   not code_part.contains("FuseLocalization.translate_format") and \
				   not code_part.contains("tr("):  # 排除内置的 tr() 函数
					# 检查是否真的在字符串字面量中（有引号）
					if code_part.contains("\"") or code_part.contains("'"):
						has_hardcoded_chinese = true
						hardcoded_reasons.append({
							function = func_name,
							line = i + 1,
							content = stripped.substr(0, 60) + ("..." if stripped.length() > 60 else "")
						})
						break

		if has_hardcoded_chinese:
			break

	if has_hardcoded_chinese:
		var reason_str = "包含硬编码中文字符串:"
		for reason_info in hardcoded_reasons:
			reason_str += "\n    在 %s() 第 %d 行: %s" % [reason_info.function, reason_info.line, reason_info.content]
		stats.uses_hardcoded_strings.append({
			file = relative_path,
			reason = reason_str
		})

	# 特别检查 _get_property_list() 中的本地化问题
	if content.contains("func _get_property_list()"):
		var property_list_content := _extract_function_content(content, "_get_property_list")
		if not property_list_content.is_empty():
			var property_lines := property_list_content.split("\n")

			for line in property_lines:
				var stripped_line := line.strip_edges()

				# 问题1：在 hint_string 中直接调用翻译函数（性能问题）
				if stripped_line.contains("hint_string") and stripped_line.contains("FuseLocalization.translate"):
					# 检查是否不是使用缓存（即直接调用而不是 join 缓存数组）
					if not stripped_line.contains("join("):
						stats.uses_hardcoded_strings.append({
							file = relative_path,
							reason = "_get_property_list() 中直接调用 FuseLocalization.translate()，应使用静态缓存"
						})
						break

				# 问题2：hint_string 包含硬编码中文枚举值
				if stripped_line.contains("hint_string"):
					if chinese_pattern.search(stripped_line):
						# 如果包含中文但没有使用缓存（没有 join 或 translate）
						if not stripped_line.contains("FuseLocalization.translate") and not stripped_line.contains("join("):
							# 检查是否是硬编码的枚举值（通常用逗号分隔）
							if stripped_line.contains(",") and (stripped_line.contains("\"") or stripped_line.contains("'")):
								stats.uses_hardcoded_strings.append({
									file = relative_path,
									reason = "_get_property_list() 中的 hint_string 包含硬编码中文枚举值"
								})
								break

## 检查翻译键是否在CSV中存在
func _check_translation_keys_exist_in_csv() -> void:
	print("")
	print("🔑 检查代码中使用的翻译键是否在CSV中:")

	var all_keys_found := true
	var missing_keys := []  # 存储缺失的键及其位置

	# 搜索所有 GD 文件中的翻译键
	var search_paths := [
		"res://addons/fuse/instructions/",
		"res://addons/fuse/events/",
		"res://addons/fuse/conditions/"
	]

	for search_path in search_paths:
		var dir := DirAccess.open(search_path)
		if not dir:
			continue

		_search_keys_in_directory_recursive(dir, search_path, missing_keys)

	if missing_keys.is_empty():
		print("  ✓ 代码中使用的所有翻译键都在CSV中")
	else:
		all_keys_found = false
		print("  ⚠ 发现 %d 个缺失的翻译键:" % missing_keys.size())
		# 去重并显示
		var unique_keys := {}
		for key_info in missing_keys:
			var key = key_info.key
			if not unique_keys.has(key):
				unique_keys[key] = []
				print("    - %s (在 %s 中使用)" % [key, key_info.file])
			else:
				unique_keys[key].append(key_info.file)

## 递归搜索目录中的翻译键
func _search_keys_in_directory_recursive(dir: DirAccess, base_path: String, missing_keys: Array) -> void:
	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue

		var full_path := base_path + file_name

		if dir.current_is_dir():
			var sub_dir := DirAccess.open(full_path)
			if sub_dir:
				_search_keys_in_directory_recursive(sub_dir, full_path + "/", missing_keys)
		elif file_name.ends_with(".gd"):
			_extract_translation_keys_from_file(full_path, missing_keys)

		file_name = dir.get_next()

	dir.list_dir_end()

## 从文件中提取翻译键
func _extract_translation_keys_from_file(file_path: String, missing_keys: Array) -> void:
	var content := _read_file(file_path)
	if content.is_empty():
		return

	var relative_path := file_path.replace("res://addons/fuse/", "")

	# 匹配 FuseLocalization.translate("KEY") 或 translate_format("KEY", ...)
	var key_pattern := RegEx.new()
	key_pattern.compile("FuseLocalization\\.translate(?:_format)?\\s*\\(\\s*\"([A-Z_][A-Z0-9_]+)\"")

	var results := key_pattern.search_all(content)
	for result in results:
		var key := result.get_string(1)
		if key.begins_with("FUSE_") and not _translation_keys_set.has(key):
			missing_keys.append({
				key = key,
				file = relative_path
			})

## 检查命名规范
func _check_naming_convention() -> void:
	print("")
	print("🔤 命名规范检查:")

	var invalid_keys := []

	for key in _translation_data.keys():
		# 检查是否以FUSE_开头
		if not key.begins_with("FUSE_"):
			invalid_keys.append(key)
			continue

		# 检查是否使用大写字母和下划线
		var uppercase_key: String = key.to_upper()
		if key != uppercase_key:
			invalid_keys.append(key)

	if invalid_keys.is_empty():
		print("  ✓ 所有翻译键符合命名规范")
	else:
		print("  ⚠ 发现 %d 个不符合规范的翻译键:" % invalid_keys.size())
		for key in invalid_keys:
			print("    - %s" % key)

## 提取函数内容
##
## 从文件内容中提取特定函数的代码块
func _extract_function_content(content: String, func_name: String) -> String:
	var lines := content.split("\n")
	var in_target_func := false
	var func_content := []
	var indent_level := 0

	for line in lines:
		var stripped := line.strip_edges()

		# 找到目标函数
		if not in_target_func:
			if stripped.begins_with("func " + func_name + "("):
				in_target_func = true
				# 计算缩进级别
				var i := 0
				while i < line.length() and line[i] == '\t':
					indent_level += 1
					i += 1
				while i < line.length() and line[i] == ' ':
					i += 1
			continue

		# 在目标函数内
		# 检查是否遇到下一个函数（同级或更高级缩进）
		if stripped.begins_with("func ") or stripped.begins_with("static func "):
			# 计算当前行的缩进
			var current_indent := 0
			var i := 0
			while i < line.length() and (line[i] == '\t' or line[i] == ' '):
				if line[i] == '\t':
					current_indent += 1
				i += 1

			# 如果缩进小于或等于函数定义的缩进，说明函数已结束
			if current_indent <= indent_level:
				break

		# 收集函数内容
		func_content.append(line)

	return "\n".join(func_content)

## 读取文件内容
func _read_file(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return ""
	var content := file.get_as_text()
	file.close()
	return content
