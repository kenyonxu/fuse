@tool
extends EditorScript

## 批量更新事件文件的 @icon 装饰器
##
## 前置条件：先运行 generate_builtin_icons.gd 生成图标文件
##
## 此脚本会：
## 1. 扫描所有事件文件
## 2. 读取它们的 builtin_icon 或 custom_icon 配置
## 3. 更新 @icon 装饰器指向对应的图标文件
##
## 优先级：builtin_icon > custom_icon > icon_name

const ICON_DIR = "res://addons/fuse/icons/builtin/"
const CUSTOM_ICON_DIR = "res://addons/fuse/icons/custom/"
const EVENTS_DIR = "res://addons/fuse/events/"

func _run():
	print("\n" + "=".repeat(60))
	print("更新事件 @icon 装饰器")
	print("=".repeat(60) + "\n")

	# 启用调试模式
	var debug_mode = false

	# 扫描所有事件文件
	var event_files = _scan_event_files(EVENTS_DIR)
	print("找到 %d 个事件文件\n" % event_files.size())

	var updated_count = 0
	var skipped_count = 0
	var error_count = 0

	# 处理每个事件文件
	for file_path in event_files:
		var result = _update_event_file(file_path, debug_mode)
		match result:
			0: # 已跳过
				skipped_count += 1
			1: # 已更新
				updated_count += 1
			-1: # 错误
				error_count += 1

	# 总结
	print("\n" + "=".repeat(60))
	print("更新完成！")
	print("  更新: %d 个文件" % updated_count)
	print("  跳过: %d 个文件（没有 icon_name 或已存在 @icon）" % skipped_count)
	print("  错误: %d 个文件" % error_count)
	print("=".repeat(60) + "\n")

	if updated_count > 0:
		print("⚠ 请在编辑器中重启脚本或重新加载项目以查看更改。")

## 递归扫描事件目录
func _scan_event_files(dir_path: String) -> Array[String]:
	var files: Array[String] = []
	var dir = DirAccess.open(dir_path)

	if not dir:
		push_error("无法打开目录: %s" % dir_path)
		return files

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		var full_path = dir_path.path_join(file_name)

		if dir.current_is_dir():
			# 递归扫描子目录
			files.append_array(_scan_event_files(full_path))
		elif file_name.ends_with(".gd"):
			files.append(full_path)

		file_name = dir.get_next()

	return files

## 更新单个事件文件
## 返回: 1 = 已更新, 0 = 已跳过, -1 = 错误
func _update_event_file(file_path: String, debug_mode: bool = false) -> int:
	# 读取文件内容
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("无法读取文件: %s" % file_path)
		return -1

	var content = file.get_as_text()
	file.close()

	# 检查是否是事件文件（通过检查是否 extends BaseEvent）
	var is_event = "extends BaseEvent" in content

	if not is_event:
		if debug_mode:
			print("  [DEBUG] 跳过 %s (不是事件类)" % file_path.get_file())
		return 0

	if debug_mode:
		print("  [DEBUG] 处理文件: %s" % file_path.get_file())

	# 确定图标名称和路径（优先级：builtin_icon > custom_icon > icon_name）
	var icon_name = ""
	var icon_path = ""

	# 1. 查找 builtin_icon
	var builtin_regex = RegEx.new()
	builtin_regex.compile('metadata\\.builtin_icon\\s*=\\s*"(\\w+)"')
	var builtin_result = builtin_regex.search(content)

	if debug_mode:
		print("    [DEBUG] 查找 builtin_icon...")
		if builtin_result:
			print("    [DEBUG]   找到: %s" % builtin_result.get_string(1))
		else:
			print("    [DEBUG]   未找到")

	if builtin_result:
		icon_name = builtin_result.get_string(1)
		# 优先 .svg（at-icons），回退 .png（EditorTheme 提取）
		var svg_path = ICON_DIR.path_join(icon_name + ".svg")
		if FileAccess.file_exists(svg_path):
			icon_path = svg_path
		else:
			icon_path = ICON_DIR.path_join(icon_name + ".png")
	else:
		# 2. 查找 custom_icon
		var custom_regex = RegEx.new()
		custom_regex.compile('metadata\\.custom_icon\\s*=\\s*"(\\w+)"')
		var custom_result = custom_regex.search(content)

		if debug_mode:
			print("    [DEBUG] 查找 custom_icon...")
			if custom_result:
				print("    [DEBUG]   找到: %s" % custom_result.get_string(1))
			else:
				print("    [DEBUG]   未找到")

		if custom_result:
			icon_name = custom_result.get_string(1)
			icon_path = CUSTOM_ICON_DIR.path_join(icon_name + ".svg")

			# 对于 custom_icon，文件可能不存在，给出提示
			if not FileAccess.file_exists(icon_path):
				print("⚠ 跳过: %s (custom_icon 文件不存在: %s)" % [file_path.get_file(), icon_path])
				print("   提示：请先运行 import_custom_icons.gd 导入自定义图标")
				return 0
		else:
			# 3. 查找 icon_name（向后兼容）
			var icon_regex = RegEx.new()
			icon_regex.compile('icon_name:\\s*String\\s*=\\s*"(\\w+)"')
			var icon_result = icon_regex.search(content)

			if debug_mode:
				print("    [DEBUG] 查找 icon_name（向后兼容）...")
				if icon_result:
					print("    [DEBUG]   找到: %s" % icon_result.get_string(1))
				else:
					print("    [DEBUG]   未找到")

			if icon_result:
				icon_name = icon_result.get_string(1)
				# 优先 .svg（at-icons），回退 .png（EditorTheme 提取）
				var svg_path = ICON_DIR.path_join(icon_name + ".svg")
				if FileAccess.file_exists(svg_path):
					icon_path = svg_path
				else:
					icon_path = ICON_DIR.path_join(icon_name + ".png")

				# 检查图标文件是否存在
				if not FileAccess.file_exists(icon_path):
					print("✗ 图标文件不存在: %s (需要先运行 generate_builtin_icons.gd 或使用 at-icons)" % icon_path)
					return -1
			else:
				# 没有找到任何图标配置
				if debug_mode:
					print("    [DEBUG] 没有找到任何图标配置，跳过")
				return 0

	# 检查是否已有 @icon 装饰器
	if "@icon" in content:
		if debug_mode:
			print("    [DEBUG] 文件包含 @icon 装饰器")

		# 提取现有的 @icon 路径
		var icon_regex = RegEx.new()
		icon_regex.compile('@icon\\("([^"]+)"\\)')
		var icon_result = icon_regex.search(content)

		if icon_result:
			var existing_path = icon_result.get_string(1)
			var existing_icon_name = existing_path.get_file().get_basename()

			if debug_mode:
				print("    [DEBUG]   现有 @icon: %s" % existing_path)
				print("    [DEBUG]   现有图标名: %s" % existing_icon_name)
				print("    [DEBUG]   目标图标名: %s" % icon_name)
				print("    [DEBUG]   图标名相同: %s" % (existing_icon_name == icon_name))

			# 只有当 @icon 指向的图标名等于 metadata.builtin_icon 或 metadata.custom_icon 时才跳过
			# 从现有 @icon 路径中提取图标文件名（不含扩展名）

			if existing_icon_name == icon_name:
				# 图标名相同，说明已经正确配置，跳过
				if debug_mode:
					print("    [DEBUG]   图标名相同，跳过更新")
				return 0
			# 图标名不同，需要更新
			if debug_mode:
				print("    [DEBUG]   图标名不同，需要更新")
		else:
			if debug_mode:
				print("    [DEBUG]   无法解析 @icon 路径")

		# 替换现有的 @icon
		content = icon_regex.sub(content, '@icon("%s")' % icon_path, true)
	else:
		# 在文件开头添加 @icon
		var lines = content.split("\n")
		var insert_pos = 0

		# 跳过 shebang 和空行
		for i in range(lines.size()):
			var line = lines[i].strip_edges()
			if line.is_empty() or line.begins_with("#!"):
				insert_pos = i + 1
			else:
				break

		lines.insert(insert_pos, '@icon("%s")' % icon_path)
		content = "\n".join(lines)

	# 写回文件
	var file_out = FileAccess.open(file_path, FileAccess.WRITE)
	if not file_out:
		push_error("无法写入文件: %s" % file_path)
		return -1

	file_out.store_string(content)
	file_out.close()

	var icon_type = "builtin" if builtin_result else ("custom" if icon_path.contains("custom") else "legacy")

	if debug_mode:
		print("    [DEBUG] ✓ 已更新: %s → %s (%s)" % [file_path.get_file(), icon_name, icon_type])
	else:
		print("✓ 已更新: %s → %s (%s)" % [file_path.get_file(), icon_name, icon_type])

	return 1
