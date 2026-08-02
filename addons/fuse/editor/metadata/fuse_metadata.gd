# fuse_metadata.gd
class_name FuseMetadata extends Resource

## 动态属性列表
##
## 显式返回 Array[Dictionary]，避免 Godot 4.x 使用 Resource 基类的 Array 返回类型
## 触发 "_get_property_list() should return Array[Dictionary]" 兼容性警告。
func _get_property_list() -> Array[Dictionary]:
	return []

## Fuse 元数据基类
##
## 为 Event、Instruction、Condition 提供统一的元数据接口
## 包含本地化支持、图标管理等通用功能

# ============================================================
# 本地化支持字段
# ============================================================

## 翻译键（优先使用翻译键，回退到直接文本）
@export var name_key: String = "":
	set(value):
		name_key = value
		_invalidate_cache()

@export var category_key: String = "":
	set(value):
		category_key = value
		_invalidate_cache()

@export var description_key: String = "":
	set(value):
		description_key = value
		_invalidate_cache()

# ============================================================
# 直接文本字段（向后兼容）
# ============================================================

## 直接文本字段（用于向后兼容，已废弃）
## @deprecated 请使用 name_key 代替
@export var name: String = "":
	set(value):
		name = value
		_invalidate_cache()

## @deprecated 请使用 description_key 代替
@export var description: String = "":
	set(value):
		description = value
		_invalidate_cache()

## @deprecated 请使用 category_key 代替
@export var category: String = "":
	set(value):
		category = value
		_invalidate_cache()

# ============================================================
# 其他字段
# ============================================================

@export var keywords: Array = []

## 图标资源（向后兼容）
@export var icon: Texture2D = null:
	set(value):
		icon = value
		_invalidate_cache()

# ============================================================
# 图标系统字段（新架构）
# ============================================================

## Godot 内置图标名称（推荐用于内置图标）
## @deprecated 请使用 builtin_icon 代替，保留用于向后兼容
@export var icon_name: String = "":
	set(value):
		icon_name = value
		_invalidate_cache()

## Godot 内置图标名称（推荐）
@export var builtin_icon: String = "":
	set(value):
		builtin_icon = value
		_invalidate_cache()

## Fuse 自定义图标库中的图标名称（推荐用于自定义图标）
@export var custom_icon: String = "":
	set(value):
		custom_icon = value
		_invalidate_cache()

# ============================================================
# 缓存字段
# ============================================================

## 本地化缓存
var _cached_localized_name: String = ""
var _cached_localized_category: String = ""
var _cached_localized_description: String = ""
var _cache_locale: String = ""
var _cache_valid: bool = false
var _cached_instance_id: int = 0  ## 缓存的 instance ID，用于检测 duplicate

# ============================================================
# 本地化方法
# ============================================================

## 获取本地化的名称
##
## 优先使用翻译键，如果没有则回退到直接文本
func get_localized_name() -> String:
	# 确保翻译系统已初始化
	var FuseLocalization_class = load("res://addons/fuse/localization/fuse_localization.gd")
	if FuseLocalization_class and FuseLocalization_class.has_method("init"):
		FuseLocalization_class.init()

	_update_cache_if_needed()
	return _cached_localized_name


## 获取本地化的分类
func get_localized_category() -> String:
	# 确保翻译系统已初始化
	var FuseLocalization_class = load("res://addons/fuse/localization/fuse_localization.gd")
	if FuseLocalization_class and FuseLocalization_class.has_method("init"):
		FuseLocalization_class.init()

	_update_cache_if_needed()
	return _cached_localized_category


## 获取本地化的描述
func get_localized_description() -> String:
	# 确保翻译系统已初始化
	var FuseLocalization_class = load("res://addons/fuse/localization/fuse_localization.gd")
	if FuseLocalization_class and FuseLocalization_class.has_method("init"):
		FuseLocalization_class.init()

	_update_cache_if_needed()
	return _cached_localized_description


## 更新缓存
func _update_cache_if_needed() -> void:
	# 检查 instance ID 是否变化（说明是 duplicate 后的新实例）
	var current_instance_id = get_instance_id()
	if _cached_instance_id != current_instance_id:
		# 新实例，强制重建缓存
		_cached_instance_id = current_instance_id
		_cache_valid = false

	# 检查是否需要重建缓存
	if not _cache_valid:
		_rebuild_cache()
		return

	# 即使缓存有效，也要检查语言是否变化
	var FuseLocalization_class = load("res://addons/fuse/localization/fuse_localization.gd")
	if FuseLocalization_class and FuseLocalization_class.has_method("get_current_locale"):
		var current_locale = FuseLocalization_class.get_current_locale()
		# 如果语言变化，强制重建缓存
		if current_locale != null and current_locale != _cache_locale:
			_cache_valid = false
			_rebuild_cache()


## 重建缓存
func _rebuild_cache() -> void:
	# 尝试加载 FuseLocalization
	var FuseLocalization_class = load("res://addons/fuse/localization/fuse_localization.gd")
	var current_locale = ""

	# 确保翻译系统已初始化
	if FuseLocalization_class and FuseLocalization_class.has_method("init"):
		FuseLocalization_class.init()

	# 检查 FuseLocalization 是否可用并已初始化
	if FuseLocalization_class and FuseLocalization_class.has_method("get_current_locale"):
		current_locale = FuseLocalization_class.get_current_locale()

	# 总是更新缓存语言标记
	_cache_locale = current_locale

	# 尝试使用翻译键
	if not name_key.is_empty():
		if FuseLocalization_class and FuseLocalization_class.has_method("translate"):
			_cached_localized_name = FuseLocalization_class.translate(name_key)
		else:
			_cached_localized_name = name_key
	else:
		# 回退到旧字段
		_cached_localized_name = name

	if not category_key.is_empty():
		if FuseLocalization_class and FuseLocalization_class.has_method("translate"):
			_cached_localized_category = FuseLocalization_class.translate(category_key)
		else:
			_cached_localized_category = category_key
	else:
		_cached_localized_category = category

	if not description_key.is_empty():
		if FuseLocalization_class and FuseLocalization_class.has_method("translate"):
			_cached_localized_description = FuseLocalization_class.translate(description_key)
		else:
			_cached_localized_description = description_key
	else:
		_cached_localized_description = description

	_cache_valid = true


## 使缓存失效
func _invalidate_cache() -> void:
	_cache_valid = false


## 清除本地化缓存（静态方法，用于语言切换时调用）
static func clear_localization_cache() -> void:
	# 注意：这个静态方法无法访问实例缓存
	# 实际的缓存清除会在 _update_cache_if_needed 中通过检查 _cache_locale 来实现
	pass


## 验证元数据
func validate() -> Array[String]:
	var errors = []

	# 检查是否有名称（翻译键或直接文本）
	if name_key.is_empty() and name.is_empty():
		errors.append("Metadata name or name_key cannot be empty")

	# 检查是否有分类（翻译键或直接文本）
	if category_key.is_empty() and category.is_empty():
		errors.append("Metadata category or category_key cannot be empty")

	return errors


## 获取图标（智能模式）
##
## 优先级：builtin_icon > custom_icon > icon_name > icon
##
## 返回：
## - Texture2D - 图标资源，如果没有则返回 null
func get_icon_texture() -> Texture2D:
	# 1. 优先使用 builtin_icon（新的推荐方式 - Godot 内置图标）
	if not builtin_icon.is_empty():
		return FuseIconManager.get_builtin_icon(builtin_icon)

	# 2. 使用 custom_icon（新的推荐方式 - Fuse 自定义图标库）
	if not custom_icon.is_empty():
		return FuseIconManager.get_custom_icon(custom_icon)

	# 3. 向后兼容：icon_name（映射到 builtin_icon）
	if not icon_name.is_empty():
		# 如果 icon_name 在自定义库中存在，优先使用自定义库
		if FuseIconManager.has_custom_icon(icon_name):
			return FuseIconManager.get_custom_icon(icon_name)
		# 否则作为内置图标
		return FuseIconManager.get_builtin_icon(icon_name)

	# 4. 向后兼容：icon 字段（直接 Texture2D）
	if icon != null:
		return icon

	# 5. 都没有，返回 null
	return null
