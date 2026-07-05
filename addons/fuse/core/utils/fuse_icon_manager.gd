# fuse_icon_manager.gd
class_name FuseIconManager extends RefCounted

## 缓存系统
static var _icon_cache: Dictionary = {}
static var _editor_theme: Theme = null
static var _is_initialized: bool = false

## 自定义图标库
static var _custom_icon_library: Resource = null
static var _custom_icon_library_path: String = "res://addons/fuse/core/resources/default_icon_library.tres"

## 初始化图标管理器
static func init() -> void:
	if _is_initialized:
		return

	if Engine.is_editor_hint():
		_editor_theme = EditorInterface.get_editor_theme()

		# 加载自定义图标库
		_load_custom_icon_library()

		_is_initialized = true
		print("[FuseIconManager] 初始化完成")

## 加载自定义图标库
static func _load_custom_icon_library() -> void:
	if _custom_icon_library != null:
		return  # 已加载

	if FileAccess.file_exists(_custom_icon_library_path):
		_custom_icon_library = load(_custom_icon_library_path)
		if _custom_icon_library:
			var icons_dict = _custom_icon_library.get("icons")
			var icon_count = icons_dict.size() if icons_dict else 0
			print("[FuseIconManager] 自定义图标库已加载: %d 个图标" % icon_count)
		else:
			print_warning("无法加载自定义图标库")
	else:
		print_warning("自定义图标库文件不存在: %s" % _custom_icon_library_path)

## 清理缓存
static func cleanup() -> void:
	_icon_cache.clear()
	_editor_theme = null
	_is_initialized = false

## 获取 Godot 内置图标
static func get_builtin_icon(icon_name: String) -> Texture2D:
	if icon_name.is_empty():
		return null

	# 检查缓存
	if _icon_cache.has(icon_name):
		return _icon_cache[icon_name]

	# 确保已初始化
	if not _is_initialized:
		init()

	# 优先级：本地文件 > EditorTheme > 占位图标
	# （本地文件优先确保 at-icons 不会被同名 Godot 内置图标覆盖）
	var icon: Texture2D = null
	const BUILTIN_DIR := "res://addons/fuse/icons/builtin/"

	# 1. 优先从本地 builtin 目录加载（.svg 优先，.png 回退）
	var svg_path := BUILTIN_DIR.path_join(icon_name + ".svg")
	if ResourceLoader.exists(svg_path):
		icon = load(svg_path)
	else:
		var png_path := BUILTIN_DIR.path_join(icon_name + ".png")
		if ResourceLoader.exists(png_path):
			icon = load(png_path)

	# 2. 本地没有则从 EditorTheme 获取
	if icon == null and _editor_theme != null:
		icon = _editor_theme.get_icon(icon_name, "EditorIcons")

	# 3. 都没有则创建占位图标
	if icon == null:
		icon = _create_placeholder_icon(icon_name)
		print_warning("无法找到内置图标: %s，使用占位图标" % icon_name)

	# 缓存图标
	_icon_cache[icon_name] = icon

	return icon

## 获取自定义图标库中的图标
static func get_custom_icon(icon_name: String) -> Texture2D:
	if icon_name.is_empty():
		return null

	# 确保图标库已加载
	if _custom_icon_library == null:
		_load_custom_icon_library()

	if _custom_icon_library == null:
		print_warning("自定义图标库未加载")
		return null

	# 从图标库获取图标
	var icons_dict = _custom_icon_library.get("icons")
	if icons_dict == null:
		return null

	if icons_dict.has(icon_name):
		return icons_dict[icon_name]

	return null

## 检查自定义图标是否存在
static func has_custom_icon(icon_name: String) -> bool:
	if _custom_icon_library == null:
		_load_custom_icon_library()

	if _custom_icon_library == null:
		return false

	var icons_dict = _custom_icon_library.get("icons")
	if icons_dict == null:
		return false

	return icons_dict.has(icon_name)

## 智能获取图标（支持多种输入类型）
static func get_icon(icon_spec: Variant) -> Texture2D:
	if icon_spec == null:
		return null

	if icon_spec is String and icon_spec.is_empty():
		return null

	# 如果已经是 Texture2D，直接返回（向后兼容）
	if icon_spec is Texture2D:
		return icon_spec

	# 如果是字符串
	if icon_spec is String:
		# 1. 优先检查是否是文件路径
		if icon_spec.begins_with("res://"):
			return _load_custom_icon(icon_spec)

		# 2. 尝试从内置图标获取
		var builtin_icon = get_builtin_icon(icon_spec)
		if builtin_icon != null:
			return builtin_icon

		# 3. 尝试从自定义图标库获取
		var custom_icon = get_custom_icon(icon_spec)
		if custom_icon != null:
			return custom_icon

		# 4. 都找不到，返回占位图标
		print_warning("未找到图标: %s（内置、库、文件路径）" % icon_spec)
		return _create_placeholder_icon(icon_spec)

	print_warning("不支持的图标规格类型: %s" % typeof(icon_spec))
	return null

## 加载自定义图标文件
static func _load_custom_icon(icon_path: String) -> Texture2D:
	if _icon_cache.has(icon_path):
		return _icon_cache[icon_path]

	var icon: Texture2D = load(icon_path)

	if icon == null:
		print_error("无法加载自定义图标: %s" % icon_path)
		_icon_cache[icon_path] = null
		return null

	_icon_cache[icon_path] = icon
	return icon

## 创建占位图标
static func _create_placeholder_icon(icon_name: String) -> Texture2D:
	var image = Image.create(16, 16, false, Image.FORMAT_RGBA8)

	# 创建半透明灰色背景
	image.fill(Color(0.5, 0.5, 0.5, 0.3))

	# 在中心画一个小点（标记这是占位图标）
	image.set_pixel(7, 7, Color.RED)
	image.set_pixel(8, 7, Color.RED)
	image.set_pixel(7, 8, Color.RED)
	image.set_pixel(8, 8, Color.RED)

	var texture = ImageTexture.new()
	texture.set_image(image)

	return texture

## 检查图标是否存在
static func has_builtin_icon(icon_name: String) -> bool:
	if not _is_initialized:
		init()

	if _editor_theme == null:
		return false

	var icon = _editor_theme.get_icon(icon_name, "EditorIcons")
	return icon != null

## 日志方法
static func print_warning(message: String) -> void:
	push_warning("[FuseIconManager] WARNING: %s" % message)

static func print_error(message: String) -> void:
	push_error("[FuseIconManager] ERROR: %s" % message)
