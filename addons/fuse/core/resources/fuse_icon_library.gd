# fuse_icon_library.gd
@tool
class_name FuseIconLibrary extends Resource

## Fuse 自定义图标库
##
## 集中管理所有自定义图标资源，提供统一的图标访问接口。

## 图标字典：图标名称 → 图标纹理
@export var icons: Dictionary[String, Texture2D] = {}

## 库的名称和描述
@export var library_name: String = "Default"
@export var library_description: String = "Fuse 自定义图标库"
@export var library_version: String = "1.0"

## 添加或更新图标
## returns: bool - true 如果是新添加，false 如果是更新已存在的图标
func add_icon(name: String, texture: Texture2D) -> bool:
	if name.is_empty():
		push_error("图标名称不能为空")
		return false

	if texture == null:
		push_error("图标纹理不能为空")
		return false

	var is_new = not icons.has(name)
	icons[name] = texture
	emit_changed()
	return is_new

## 添加图标（如果不存在）
## returns: bool - true 如果添加成功，false 如果图标已存在
func add_icon_if_missing(name: String, texture: Texture2D) -> bool:
	if icons.has(name):
		return false  # 已存在，跳过
	return add_icon(name, texture)  # 新添加

## 获取图标
func get_icon(name: String) -> Texture2D:
	if icons.has(name):
		return icons[name]
	return null

## 检查图标是否存在
func has_icon(name: String) -> bool:
	return icons.has(name)

## 移除图标
func remove_icon(name: String) -> void:
	if icons.has(name):
		icons.erase(name)
		emit_changed()

## 获取所有图标名称
func list_icons() -> Array[String]:
	var names: Array[String] = []
	for key in icons.keys():
		names.append(key)
	names.sort()
	return names

## 获取图标数量
func get_icon_count() -> int:
	return icons.size()

## 清空所有图标
func clear() -> void:
	icons.clear()
	emit_changed()

## 导出图标列表为 JSON
func export_to_json() -> String:
	var icon_list = []
	for name in icons.keys():
		icon_list.append({
			"name": name,
			"type": icons[name].get_class()
		})

	return JSON.stringify(icon_list, "\t")

## 从文件批量导入图标
##
## directory: 图标文件目录（支持 .svg, .png, .jpg 等）
## recursive: 是否递归扫描子目录
## skip_existing: 是否跳过已存在的图标（true=跳过，false=创建新名称如 icon_1, icon_2）
## returns: int - 实际导入的图标数量
func import_from_directory(directory: String, recursive: bool = false, skip_existing: bool = false) -> int:
	var dir = DirAccess.open(directory)
	if not dir:
		push_error("无法打开目录: %s" % directory)
		return 0

	var imported_count = 0
	var skipped_count = 0
	var files = _scan_image_files(directory, recursive)

	for file_path in files:
		var texture = load(file_path) as Texture2D
		if texture:
			# 从文件名生成图标名称（去掉扩展名和路径）
			var file_name = file_path.get_file().get_basename()
			# 转换为 snake_case（可选）
			var icon_name = _to_snake_case(file_name)

			# 处理已存在的图标
			if icons.has(icon_name):
				if skip_existing:
					# 跳过已存在的图标
					skipped_count += 1
					continue
				else:
					# 创建新名称避免覆盖
					var final_name = icon_name
					var counter = 1
					while icons.has(final_name):
						final_name = "%s_%d" % [icon_name, counter]
						counter += 1
					icon_name = final_name

			add_icon(icon_name, texture)
			imported_count += 1
		else:
			push_warning("无法加载图标: %s" % file_path)

	if skipped_count > 0:
		print("  跳过 %d 个已存在的图标" % skipped_count)

	return imported_count

## 扫描图像文件
func _scan_image_files(dir_path: String, recursive: bool) -> Array[String]:
	var files: Array[String] = []
	var dir = DirAccess.open(dir_path)

	if not dir:
		return files

	dir.list_dir_begin()
	var file_name = dir.get_next()

	var extensions = [".png", ".svg", ".jpg", ".jpeg", ".webp", ".tga"]

	while file_name != "":
		var full_path = dir_path.path_join(file_name)

		if dir.current_is_dir() and recursive:
			files.append_array(_scan_image_files(full_path, recursive))
		else:
			var extension = file_name.get_extension().to_lower()
			if extension in extensions:
				files.append(full_path)

		file_name = dir.get_next()

	return files

## 转换为 snake_case
func _to_snake_case(text: String) -> String:
	var result = ""
	for i in range(text.length()):
		var c = text[i]
		if c.to_upper() == c and c.to_lower() != c:
			# 大写字母
			if i > 0:
				result += "_"
			result += c.to_lower()
		else:
			# 小写字母或其他
			if c == " " or c == "-":
				c = "_"
			result += c

	return result
