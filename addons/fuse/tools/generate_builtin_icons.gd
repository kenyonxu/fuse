@tool
extends EditorScript

## 从 Godot 编辑器主题提取实际使用的图标并保存为文件
##
## 使用方法：
## 1. 在编辑器中点击 Project → Tools → Execute Script
## 2. 选择此脚本并运行
## 3. 脚本会自动扫描 events、instructions 和 conditions 目录
## 4. 收集所有使用的 builtin_icon 值
## 5. 提取对应的图标并保存
## 6. 同时导入到 FuseIconLibrary（如果 IMPORT_TO_LIBRARY = true）

const OUTPUT_DIR = "res://addons/fuse/icons/builtin/"
const EVENTS_DIR = "res://addons/fuse/events/"
const INSTRUCTIONS_DIR = "res://addons/fuse/instructions/"
const CONDITIONS_DIR = "res://addons/fuse/conditions/"

## 是否同时导入到 FuseIconLibrary
const IMPORT_TO_LIBRARY = true

func _run():
	print("\n" + "=".repeat(60))
	print("提取 Godot 内置图标（自动扫描）")
	print("=".repeat(60) + "\n")

	# 用于临时保存纹理，绕过文件系统缓存
	var temp_textures: Dictionary = {}

	# 步骤 1: 扫描目录收集所有使用的 builtin_icon
	print("步骤 1: 扫描 events、instructions 和 conditions 目录...")
	var builtin_icons = _collect_builtin_icons()
	print("  发现 %d 个使用的图标\n" % builtin_icons.size())

	if builtin_icons.is_empty():
		print("⚠ 没有发现任何 builtin_icon 配置")
		print("  提示：在 Event、Instruction 或 Condition 的 metadata 中使用 builtin_icon 字段")
		return

	print("  使用的图标:")
	for icon_name in builtin_icons:
		print("    - %s" % icon_name)
	print()

	# 确保输出目录存在
	DirAccess.make_dir_absolute(OUTPUT_DIR)

	# 获取编辑器主题
	var editor_theme = EditorInterface.get_editor_theme()
	if not editor_theme:
		push_error("无法获取编辑器主题")
		return

	var success_count = 0
	var fail_count = 0
	var imported_to_library_count = 0

	# 如果需要导入到图标库，先加载图标库
	var icon_library = null
	if IMPORT_TO_LIBRARY:
		icon_library = load("res://addons/fuse/core/resources/default_icon_library.tres")
		if not icon_library:
			push_warning("无法加载 FuseIconLibrary，跳过导入到库")

	# 步骤 2: 提取每个图标
	print("\n步骤 2: 提取图标...")
	var skipped_files_count = 0
	var skipped_library_count = 0

	for icon_name in builtin_icons:
		var icon = editor_theme.get_icon(icon_name, "EditorIcons")

		if icon:
			# 保存为 PNG 文件
			var icon_path = OUTPUT_DIR.path_join(icon_name + ".png")

			# 检查文件是否已存在
			if FileAccess.file_exists(icon_path):
				print("⊘ 跳过文件: %s (已存在)" % icon_name)
				skipped_files_count += 1

				# 即使文件已存在，也尝试导入到 library（如果需要）
				if IMPORT_TO_LIBRARY and icon_library and icon_library.has_method("add_icon"):
					var loaded_icon = load(icon_path)
					if loaded_icon:
						# 检查 library 是否已有该图标
						if icon_library.has_icon(icon_name):
							print("  ⊘ Library 中也已存在，跳过")
							skipped_library_count += 1
						else:
							var is_new = icon_library.add_icon(icon_name, loaded_icon)
							if is_new:
								print("  ✓ 已添加到 library")
								imported_to_library_count += 1

				continue

			# 文件不存在，保存
			var result = _save_icon_as_png_and_create_texture(icon, icon_path)
			var success = result[0]
			var texture = result[1]

			if success:
				print("✓ 已保存: %s → %s" % [icon_name, icon_path])
				success_count += 1

				# 保存纹理到临时列表，绕过文件系统缓存
				if IMPORT_TO_LIBRARY and icon_library and icon_library.has_method("add_icon"):
					temp_textures[icon_name] = texture
			else:
				print("✗ 保存失败: %s" % icon_name)
				fail_count += 1
		else:
			print("✗ 未找到: %s" % icon_name)
			fail_count += 1

	# 从临时纹理列表导入到图标库（绕过文件系统缓存）
	if IMPORT_TO_LIBRARY and icon_library and icon_library.has_method("add_icon") and not temp_textures.is_empty():
		print("\n导入图标到 library...")
		for icon_name in temp_textures:
			var texture = temp_textures[icon_name]
			if texture:
				var is_new = icon_library.add_icon(icon_name, texture)
				if is_new:
					print("  ✓ 已添加: %s" % icon_name)
					imported_to_library_count += 1
				else:
					print("  ⊘ 已存在: %s" % icon_name)

	# 保存图标库（如果有修改）
	if IMPORT_TO_LIBRARY and icon_library and imported_to_library_count > 0:
		var save_error = ResourceSaver.save(icon_library, "res://addons/fuse/core/resources/default_icon_library.tres")
		if save_error != OK:
			push_error("保存图标库失败: %s" % error_string(save_error))

	# 刷新文件系统，使新文件被正确导入
	if success_count > 0:
		print("\n正在刷新文件系统...")
		EditorInterface.get_resource_filesystem().scan()

	# 总结
	print("\n" + "=".repeat(60))
	print("完成！")
	print("  新增: %d 个" % success_count)
	print("  跳过（已存在）: %d 个" % skipped_files_count)
	print("  失败: %d 个" % fail_count)
	if IMPORT_TO_LIBRARY:
		print("\n图标库统计:")
		print("  新增到库: %d 个" % imported_to_library_count)
		print("  跳过（库中已有）: %d 个" % skipped_library_count)
	print("\n图标保存位置: %s" % OUTPUT_DIR)
	print("=".repeat(60) + "\n")

	print("下一步：")
	print("1. 运行 update_instruction_icon_decorators.gd 更新指令的 @icon 装饰器")
	print("2. 运行 update_event_icon_decorators.gd 更新事件的 @icon 装饰器")
	print("3. 运行 update_condition_icon_decorators.gd 更新条件的 @icon 装饰器")
	print("4. 重启编辑器查看效果")

## 保存图标为 PNG 文件，并返回 ImageTexture
func _save_icon_as_png_and_create_texture(icon: Texture2D, path: String) -> Array:
	# 返回 [成功: bool, texture: ImageTexture]
	# 获取图标的 Image 数据
	var image: Image

	if icon is ImageTexture:
		image = icon.get_data()
	elif icon is AtlasTexture:
		# AtlasTexture 需要特殊处理
		var atlas = icon as AtlasTexture
		image = atlas.get_atlas().get_data()
		var region = atlas.region
		image = image.get_region(region)
	elif icon.get_class() == "DPITexture":
		# DPITexture 是 Godot 4 的高 DPI 纹理包装器
		if icon.has_method("get_image"):
			var img = icon.call("get_image")
			if img and img is Image:
				image = img
			else:
				return [false, null]
		else:
			return [false, null]
	else:
		# 对于其他类型的 Texture，尝试获取图像
		return [false, null]

	if not image:
		return [false, null]

	# 保存为 PNG
	image.save_png(path)

	# 使用 DirAccess 检查文件是否真的创建了（绕过文件系统缓存）
	var dir = DirAccess.open(path.get_base_dir())
	var file_exists = false

	if dir:
		dir.list_dir_begin()
		var check_name = dir.get_next()
		while check_name != "":
			if check_name == path.get_file():
				file_exists = true
				break
			check_name = dir.get_next()

	if not file_exists:
		return [false, null]

	# 从 Image 创建 ImageTexture（绕过文件系统导入）
	var texture = ImageTexture.new()
	texture.set_image(image)

	return [true, texture]

## 扫描 events、instructions 和 conditions 目录，收集所有使用的 builtin_icon
func _collect_builtin_icons() -> Array[String]:
	var icons_set: Dictionary = {}  # 使用 Dictionary 去重

	# 扫描 events 目录
	if DirAccess.dir_exists_absolute(EVENTS_DIR):
		_scan_directory_for_builtin_icons(EVENTS_DIR, icons_set)

	# 扫描 instructions 目录
	if DirAccess.dir_exists_absolute(INSTRUCTIONS_DIR):
		_scan_directory_for_builtin_icons(INSTRUCTIONS_DIR, icons_set)

	# 扫描 conditions 目录
	if DirAccess.dir_exists_absolute(CONDITIONS_DIR):
		_scan_directory_for_builtin_icons(CONDITIONS_DIR, icons_set)

	# 转换为排序后的数组
	var icons_array: Array[String] = []
	for key in icons_set.keys():
		icons_array.append(key)
	icons_array.sort()

	return icons_array

## 递归扫描目录查找 builtin_icon
func _scan_directory_for_builtin_icons(dir_path: String, icons_set: Dictionary) -> void:
	var dir = DirAccess.open(dir_path)
	if not dir:
		push_error("无法打开目录: %s" % dir_path)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		var full_path = dir_path.path_join(file_name)

		if dir.current_is_dir():
			# 递归扫描子目录
			_scan_directory_for_builtin_icons(full_path, icons_set)
		elif file_name.ends_with(".gd"):
			# 扫描 .gd 文件
			_scan_file_for_builtin_icons(full_path, icons_set)

		file_name = dir.get_next()

## 扫描单个文件查找 builtin_icon
func _scan_file_for_builtin_icons(file_path: String, icons_set: Dictionary) -> void:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return

	var content = file.get_as_text()
	file.close()

	# 查找 builtin_icon = "xxx" 或 metadata.builtin_icon = "xxx"
	# 支持两种格式：
	# 1. metadata.builtin_icon = "IconName"
	# 2. builtin_icon: String = "IconName"（类型注解格式）
	var regex = RegEx.new()
	regex.compile('(?m)^[ \\t]*metadata\\.builtin_icon\\s*=\\s*"([\\w]+)"')

	var result = regex.search(content)
	if result:
		var icon_name = result.get_string(1)
		icons_set[icon_name] = true
