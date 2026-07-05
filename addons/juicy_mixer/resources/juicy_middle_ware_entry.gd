# =============================================================================
# MiddlewareEntry类
# =============================================================================
@tool
class_name MiddlewareEntry
extends Resource

## 单个中间件配置条目
## 中间件类名（从下拉列表选择）
var middleware_class_name: String = "":
	set(value):
		middleware_class_name = value
		_update_script_from_class_name()
		notify_property_list_changed()
		# 确保属性列表更新，包括路径显示
		if Engine.is_editor_hint():
			call_deferred("_deferred_property_update")
			_update_resource_name()

## 中间件脚本文件（类型安全的引用）
var middleware_script: Script:
	set(value):
		middleware_script = value
		_update_default_config()
		notify_property_list_changed()

## 是否启用此中间件
@export var enabled: bool = true:
	set(value):
		enabled = value
		if Engine.is_editor_hint():
			_update_resource_name()

## 优先级（数字越小优先级越高）
@export var priority: int = 0:
	set(value):
		priority = value
		if Engine.is_editor_hint():
			_update_resource_name()

## 配置数据（覆盖默认值）
@export var config_data: Dictionary = {}

# 内部状态
var _default_config: Dictionary = {}
var _config_schema: Dictionary = {}

# 缓存可用的中间件类
static var _available_middlewares: Dictionary = {}
static var _scan_completed: bool = false

# =============================================================================
# 属性列表生成
# =============================================================================

func _get_property_list() -> Array[Dictionary]:
	var properties = []
	
	# 扫描中间件目录
	_scan_middlewares()
	
	# 生成枚举字符串
	var enum_string = ""
	var keys = _available_middlewares.keys()
	for i in range(keys.size()):
		var key_name = keys[i]
		if not enum_string.is_empty():
			enum_string += ","
		enum_string += key_name
	
	# 添加中间件类名选择
	properties.append({
		"name": "middleware_class_name",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": enum_string,
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	# 移除路径显示，保持简洁
	# 用户可以从下拉列表直接选择，不需要额外的路径显示
	
	# 如果选择了脚本，动态生成配置属性
	if middleware_script:
		_generate_config_properties(properties)
	
	return properties

# 编辑器中的初始化
func _init():
	# 总是强制扫描一次，确保在编辑器和运行时都能工作
	_scan_middlewares()
	if Engine.is_editor_hint():
		print("[MiddlewareEntry] 编辑器初始化，发现 ", _available_middlewares.size(), " 个中间件")

## 生成配置属性
func _generate_config_properties(properties: Array) -> void:
	if not middleware_script:
		return
	
	# 创建临时实例获取配置模式
	var temp_instance = _create_temp_instance()
	if not temp_instance:
		return
	
	# 获取配置模式
	var schema = {}
	if temp_instance.has_method("get_configuration_schema"):
		schema = temp_instance.get_configuration_schema()
	elif temp_instance.has_method("get_configuration_schema"):
		schema = temp_instance.get_configuration_schema()
	
	# 为每个配置项生成属性
	for key in schema.keys():
		var config_info = schema[key]
		var property_info = {
			"name": "config_data." + str(key),
			"type": _get_godot_type(config_info.get("type", "Variant")),
			"hint": _get_property_hint(config_info.get("hint", "none")),
			"hint_string": config_info.get("hint_string", ""),
			"usage": PROPERTY_USAGE_DEFAULT
		}
		properties.append(property_info)
	
	# RefCounted 对象不需要手动释放
	# temp_instance.free()  # 注释掉，RefCounted 会自动管理

# =============================================================================
# 配置管理
# =============================================================================

## 更新默认配置
func _update_default_config() -> void:
	if not middleware_script:
		_default_config.clear()
		_config_schema.clear()
		config_data.clear()
		return
	
	# 创建临时实例获取默认配置
	var temp_instance = _create_temp_instance()
	if not temp_instance:
		return
	
	# 获取默认配置
	if temp_instance.has_method("get_default_configuration"):
		_default_config = temp_instance.get_default_configuration()
	elif temp_instance.has_method("_setup_default_configuration"):
		temp_instance._setup_default_configuration()
		if temp_instance.has_method("get_default_configuration"):
			_default_config = temp_instance.get_default_configuration()
	
	# 获取配置模式
	if temp_instance.has_method("get_configuration_schema"):
		_config_schema = temp_instance.get_configuration_schema()
	elif temp_instance.has_method("get_configuration_schema"):
		_config_schema = temp_instance.get_configuration_schema()
	
	# 初始化config_data为默认值
	config_data = _default_config.duplicate()
	
	# RefCounted 对象不需要手动释放
	# temp_instance.free()  # 注释掉，RefCounted 会自动管理

## 创建临时实例（安全方式）
func _create_temp_instance() -> JuicyMiddleware:
	if not middleware_script:
		return null
	
	# GDScript 使用不同的错误处理机制
	var instance = middleware_script.new()
	if not instance:
		push_error("Failed to create instance from script: " + middleware_script.resource_path)
		return null
	
	if not (instance is JuicyMiddleware):
		push_error("Script is not a JuicyMiddleware subclass: " + middleware_script.resource_path)
		instance.free()
		return null
	
	return instance

# =============================================================================
# 中间件创建
# =============================================================================

## 创建中间件实例
func create_middleware() -> JuicyMiddleware:
	if not middleware_script:
		return null
	
	# GDScript 使用不同的错误处理机制
	var middleware = middleware_script.new()
	if not middleware:
		push_error("Failed to create instance from script: " + middleware_script.resource_path)
		return null
	
	if not (middleware is JuicyMiddleware):
		push_error("Script is not a JuicyMiddleware subclass: " + middleware_script.resource_path)
		middleware.free()
		return null
	
	# 应用配置
	if not config_data.is_empty():
		middleware.configure(config_data)
	
	return middleware

## 获取中间件名称
func get_middleware_name() -> String:
	if not middleware_script:
		return "Unknown"
	
	# 尝试从脚本名称获取
	var script_name = middleware_script.resource_path.get_file().get_basename()
	
	# 创建临时实例获取名称
	var temp_instance = _create_temp_instance()
	if temp_instance and temp_instance.has_method("get_middleware_info"):
		var info = temp_instance.get_middleware_info()
		if info.has("name") and not info.name.is_empty():
			script_name = info.name
	
	# RefCounted 对象不需要手动释放，会自动管理
	# temp_instance.free()  # 注释掉，避免错误
	
	return script_name

# =============================================================================
# 自动扫描功能
# =============================================================================

## 扫描中间件目录
func _scan_middlewares():
	if _scan_completed:
		return  # 已经扫描过
	
	var search_paths = [
		"res://addons/juicy_mixer/middleware/",
		"res://middleware/",  # 用户自定义中间件
		"res://game/middleware/"  # 游戏特定中间件
	]
	
	for path in search_paths:
		_scan_directory(path)
	
	_scan_completed = true

## 扫描指定目录
func _scan_directory(dir_path: String):
	var dir = DirAccess.open(dir_path)
	if not dir:
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while not file_name.is_empty():
		if file_name.ends_with(".gd") and not file_name.begins_with("_"):
			var full_path = dir_path + file_name
			var key_name = file_name.get_basename()
			
			# 跳过基类文件
			if key_name == "juicy_middleware":
				file_name = dir.get_next()
				continue
			
			# 验证脚本
			if _validate_middleware_script(full_path):
				_available_middlewares[key_name] = full_path
		
		file_name = dir.get_next()
	
	dir.list_dir_end()

## 验证脚本是否继承自 JuicyMiddleware
func _validate_middleware_script(path: String) -> bool:
	var script = load(path)
	if not script:
		return false
	
	# 创建临时实例验证继承关系
	var instance = script.new()
	if not instance:
		return false
	
	var is_valid = instance is JuicyMiddleware
	
	if not is_valid:
		pass
	
	# RefCounted 对象不需要手动释放，会自动管理
	# instance.free()  # 注释掉，避免错误
	
	return is_valid

## 根据类名更新脚本
func _update_script_from_class_name():
	if middleware_class_name.is_empty():
		return
	
	if _available_middlewares.has(middleware_class_name):
		var script_path = _available_middlewares[middleware_class_name]
		middleware_script = load(script_path)
		
		# 获取中间件的默认优先级
		_update_default_priority()
		
		# 在编辑器中触发属性更新，确保路径显示也更新
		if Engine.is_editor_hint():
			notify_property_list_changed()

## 更新默认优先级
func _update_default_priority():
	if not middleware_script:
		return
	
	# 创建临时实例获取默认优先级
	var temp_instance = _create_temp_instance()
	if temp_instance:
		# 获取中间件的默认优先级
		var default_priority = temp_instance.priority
		if default_priority != priority:
			priority = default_priority
			
			# 在编辑器中触发资源名称更新
			if Engine.is_editor_hint():
				_update_resource_name()
	
	# RefCounted 对象不需要手动释放，会自动管理
	# temp_instance.free()  # 注释掉，避免错误

## 延迟属性更新（用于编辑器）
func _deferred_property_update():
	# 在下一帧触发属性更新，确保编辑器能正确显示
	notify_property_list_changed()

## 调试方法
func debug_print_available_middlewares():
	print("=== 可用中间件调试信息 ===")
	print("扫描完成状态: ", _scan_completed)
	print("可用中间件数量: ", _available_middlewares.size())
	for key in _available_middlewares.keys():
		print("  - ", key, " -> ", _available_middlewares[key])
	print("=== 调试信息结束 ===")

## 强制刷新属性列表
func force_refresh_property_list():
	if Engine.is_editor_hint():
		_scan_completed = false  # 强制重新扫描
		notify_property_list_changed()

## 清除扫描缓存（用于重新扫描）
static func clear_scan_cache():
	_available_middlewares.clear()
	_scan_completed = false

## 手动重新扫描
static func rescan_middlewares():
	clear_scan_cache()
	# 创建临时实例来触发扫描
	var temp_instance = MiddlewareEntry.new()
	temp_instance._scan_middlewares()
	print("[MiddlewareEntry] 重新扫描完成，可用中间件: ", _available_middlewares.keys())

# =============================================================================
# 工具方法
# =============================================================================

## 获取Godot类型常量
func _get_godot_type(type_string: String) -> int:
	match type_string:
		"int": return TYPE_INT
		"float": return TYPE_FLOAT
		"bool": return TYPE_BOOL
		"String": return TYPE_STRING
		"Array": return TYPE_ARRAY
		"Dictionary": return TYPE_DICTIONARY
		"Vector2": return TYPE_VECTOR2
		"Vector3": return TYPE_VECTOR3
		"Color": return TYPE_COLOR
		_: return TYPE_NIL

## 获取属性提示
func _get_property_hint(hint_string: String) -> PropertyHint:
	match hint_string:
		"enum": return PROPERTY_HINT_ENUM
		"range": return PROPERTY_HINT_RANGE
		"multiline": return PROPERTY_HINT_MULTILINE_TEXT
		"file": return PROPERTY_HINT_FILE
		"dir": return PROPERTY_HINT_DIR
		_: return PROPERTY_HINT_NONE

## 获取配置统计
func get_config_stats() -> Dictionary:
	return {
		"has_script": middleware_script != null,
		"enabled": enabled,
		"priority": priority,
		"config_keys": config_data.keys(),
		"default_keys": _default_config.keys()
	}

## 更新资源名称显示
func _to_string() -> String:
	var middleware_name = get_middleware_name()
	var status_icon = "✓" if enabled else "✗"
	return "[%s] Priority: %d %s" % [middleware_name, priority, status_icon]

## 触发资源名称更新
func _update_resource_name():
	if Engine.is_editor_hint():
		# 在编辑器中触发资源更新，以显示新的名称
		emit_changed()
		resource_name = _to_string()