@tool
extends EditorScript

## 批量导入自定义图标到 FuseIconLibrary
##
## 使用方法：
## 1. 在编辑器中点击 Project → Tools → Execute Script
## 2. 选择此脚本 (import_custom_icons.gd)
## 3. 点击运行
## 4. 在弹出的文件夹选择对话框中选择图标目录

const ICON_LIBRARY_PATH = "res://addons/fuse/core/resources/default_icon_library.tres"

## 支持的文件扩展名
const SUPPORTED_EXTENSIONS = [".png", ".svg", ".jpg", ".jpeg", ".webp", ".tga", ".bmp"]

func _run():
	print("\n" + "=".repeat(60))
	print("Fuse 自定义图标导入工具")
	print("=".repeat(60) + "\n")

	# 加载图标库
	var icon_library = load(ICON_LIBRARY_PATH)
	if not icon_library:
		push_error("无法加载图标库: %s" % ICON_LIBRARY_PATH)
		return

	print("当前图标库有 %d 个图标\n" % icon_library.get("icons").size())

	# 打开文件夹选择对话框
	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	dialog.title = "选择图标目录"
	dialog.access = FileDialog.ACCESS_FILESYSTEM

	# 连接信号
	dialog.file_selected.connect(_on_directory_selected.bind(icon_library))
	dialog.canceled.connect(_on_dialog_canceled)

	# 显示对话框
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered()

	print("\n请在弹出的对话框中选择包含图标文件的目录...")
	print("支持的格式: %s" % str(SUPPORTED_EXTENSIONS))

## 目录选择完成
func _on_directory_selected(icon_library: Resource, dir_path: String) -> void:
	print("\n选择的目录: %s\n" % dir_path)

	# 导入图标（递归扫描子目录，跳过已存在的图标）
	var imported_count = _import_icons_from_directory(icon_library, dir_path, true, true)

	# 保存图标库
	var save_error = ResourceSaver.save(icon_library, ICON_LIBRARY_PATH)
	if save_error != OK:
		push_error("保存图标库失败: %s" % error_string(save_error))
		return

	# 总结
	print("\n" + "=".repeat(60))
	print("导入完成！")
	print("  成功导入: %d 个图标" % imported_count)
	print("  图标库总计: %d 个图标" % icon_library.get("icons").size())
	print("  保存位置: %s" % ICON_LIBRARY_PATH)
	print("=".repeat(60) + "\n")

	# 列出所有图标
	_list_all_icons(icon_library)

	print("\n下一步：")
	print("1. 在指令的 metadata 中使用 custom_icon = \"图标名称\"")
	print("2. 例如: metadata.custom_icon = \"my_custom_icon\"")

## 对话框取消
func _on_dialog_canceled() -> void:
	print("\n操作已取消")

## 从目录导入图标
## skip_existing: 是否跳过已存在的图标（默认 true）
func _import_icons_from_directory(icon_library: Resource, dir_path: String, recursive: bool, skip_existing: bool = true) -> int:
	if not icon_library.has_method("import_from_directory"):
		push_error("图标库不支持 import_from_directory 方法")
		return 0

	return icon_library.import_from_directory(dir_path, recursive, skip_existing)

## 列出所有图标
func _list_all_icons(icon_library: Resource) -> void:
	var icons_dict = icon_library.get("icons")
	if not icons_dict:
		return

	var icon_names = []
	for key in icons_dict.keys():
		icon_names.append(key)

	icon_names.sort()

	if icon_names.is_empty():
		print("  (无图标)")
		return

	print("\n图标列表:")
	for i in range(icon_names.size()):
		var name = icon_names[i]
		print("  %2d. %s" % [i + 1, name])
