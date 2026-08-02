@tool
class_name GlobalVariableResource extends Resource

## 动态属性列表
##
## 显式返回 Array[Dictionary]，避免 Godot 4.x 使用 Resource 基类的 Array 返回类型
## 触发 "_get_property_list() should return Array[Dictionary]" 兼容性警告。
func _get_property_list() -> Array[Dictionary]:
	return []

## GlobalVariableResource 资源类 - 简化版本
## 作为全局变量存储的数据结构，提供简化的变量数据管理功能

## 日志级别配置
@export var log_level: FuseLogger.LogLevel = FuseLogger.LogLevel.INFO

## 核心属性
@export var variables: Dictionary = {}  ## 存储变量数据的字典
@export var description: String = ""  ## 资源描述
@export var created_time: float = 0.0  ## 创建时间戳
@export var last_modified: float = 0.0  ## 最后修改时间戳
@export var version: String = "2.0.0"  ## 版本信息
@export var author: String = ""  ## 作者信息
@export var tags: Array[String] = []  ## 标签分类数组

## 常量定义
const CURRENT_VERSION = "2.0.0"
const DEFAULT_DESCRIPTION = "全局变量资源"

## 错误处理
var _fuse_error: FuseError = null

## 初始化
func _init():
	if created_time == 0.0:
		created_time = Time.get_ticks_msec() / 1000.0
	if last_modified == 0.0:
		last_modified = created_time
	if description.is_empty():
		description = DEFAULT_DESCRIPTION
	if version.is_empty():
		version = CURRENT_VERSION

## 添加变量
## name: String - 变量名称
## variable_data: Variant - 变量数据（可以是字典格式或原始值）
## persistent: bool - 是否持久化（当 variable_data 是原始值时使用）
## returns: bool - 添加是否成功
func add_variable(name: String, variable_data: Variant, persistent: bool = true) -> bool:
	# 验证参数
	if name.is_empty():
		_log_error("变量名称不能为空")
		return false

	# 检查名称冲突
	if variables.has(name):
		_log_error("变量名称已存在: %s" % name)
		return false

	# 智能处理变量数据格式
	var normalized_data = _normalize_variable_data(variable_data, persistent)
	if normalized_data == null:
		_log_error("变量数据格式无效: %s" % name)
		return false

	# 添加变量
	variables[name] = normalized_data
	update_timestamp()

	_log_info("变量添加成功: %s" % name)
	return true

## 设置变量（添加或更新）
## name: String - 变量名称
## value: Variant - 变量值（可以是原始值、字典格式或完整结构）
## persistent: bool - 是否持久化（可选，默认 true）
## returns: bool - 设置是否成功
func set_variable(name: String, value: Variant, persistent: bool = true) -> bool:
	if name.is_empty():
		_log_error("变量名称不能为空")
		return false

	# 智能处理变量数据格式
	var normalized_data = _normalize_variable_data(value, persistent)
	if normalized_data == null:
		_log_error("变量数据格式无效: %s" % name)
		return false

	variables[name] = normalized_data
	update_timestamp()
	return true

## 获取变量
## name: String - 变量名称
## returns: Variant - 变量数据（标准化为字典格式），如果不存在则返回 null
func get_variable(name: String) -> Variant:
	if name.is_empty():
		_log_error("变量名称不能为空")
		return null

	if not variables.has(name):
		_log_warning("变量不存在: %s" % name)
		return null

	# 获取数据并标准化格式
	var data = variables[name]
	return _normalize_variable_data(data, true)

## 更新变量
## name: String - 变量名称
## variable_data: Variant - 新的变量数据（可以是字典或原始值）
## returns: bool - 更新是否成功
func update_variable(name: String, variable_data: Variant) -> bool:
	if name.is_empty():
		_log_error("变量名称不能为空")
		return false

	if not variables.has(name):
		_log_error("变量不存在，无法更新: %s" % name)
		return false

	# 获取现有变量的 persistent 设置
	var existing_data = variables[name]
	var existing_persistent = true
	if existing_data is Dictionary and existing_data.has("persistent"):
		existing_persistent = existing_data.get("persistent", true)

	# 智能处理变量数据格式
	var normalized_data = _normalize_variable_data(variable_data, existing_persistent)
	if normalized_data == null:
		_log_error("变量数据格式无效: %s" % name)
		return false

	# 更新变量
	variables[name] = normalized_data
	update_timestamp()

	_log_info("变量更新成功: %s" % name)
	return true

## 移除变量
## name: String - 变量名称
## returns: bool - 移除是否成功
func remove_variable(name: String) -> bool:
	if name.is_empty():
		_log_error("变量名称不能为空")
		return false
	
	if not variables.has(name):
		_log_warning("尝试移除不存在的变量: %s" % name)
		return false
	
	variables.erase(name)
	update_timestamp()
	
	_log_info("变量移除成功: %s" % name)
	return true

## 检查变量是否存在
## name: String - 变量名称
## returns: bool - 变量是否存在
func has_variable(name: String) -> bool:
	if name.is_empty():
		return false
	return variables.has(name)

## 获取所有变量
## returns: Dictionary - 所有变量的副本
func get_all_variables() -> Dictionary:
	# 返回所有变量的深拷贝
	var result = {}
	for name in variables:
		result[name] = variables[name].duplicate(true)
	return result

## 获取所有变量名称
## returns: Array[String] - 变量名称数组
func get_variable_names() -> Array[String]:
	var names: Array[String] = []
	for name in variables:
		names.append(name)
	return names

## 清空所有变量
func clear_variables() -> void:
	var count = variables.size()
	variables.clear()
	update_timestamp()
	_log_info("所有变量已清空，共清除 %d 个变量" % count)

## 获取变量数量
## returns: int - 变量数量
func get_variable_count() -> int:
	return variables.size()

## 检查是否为空
## returns: bool - 是否没有变量
func is_empty() -> bool:
	return variables.size() == 0

## 更新时间戳
func update_timestamp() -> void:
	last_modified = Time.get_ticks_msec() / 1000.0

## 序列化支持 - 转换为字符串
## returns: String - 资源的字符串表示
func _to_string() -> String:
	return "GlobalVariableResource(%d variables, v%s, modified: %s)" % [
		variables.size(), 
		version, 
		_format_timestamp(last_modified)
	]

## 序列化支持 - 转换为字典
## returns: Dictionary - 资源的字典表示
func _to_dict() -> Dictionary:
	var data = {
		"variables": get_all_variables(),  # 使用深拷贝
		"description": description,
		"created_time": created_time,
		"last_modified": last_modified,
		"version": version,
		"author": author,
		"tags": tags.duplicate()  # 复制数组
	}
	return data

## 从字典反序列化
## data: Dictionary - 包含资源数据的字典
## returns: GlobalVariableResource - 新的资源实例
static func from_dict(data: Dictionary) -> GlobalVariableResource:
	var resource = GlobalVariableResource.new()
	
	if data.has("variables") and data["variables"] is Dictionary:
		resource.variables = _deep_copy_dict(data["variables"])
	
	if data.has("description"):
		resource.description = str(data["description"])
	
	if data.has("created_time"):
		resource.created_time = float(data["created_time"])
	else:
		resource.created_time = Time.get_ticks_msec() / 1000.0
	
	if data.has("last_modified"):
		resource.last_modified = float(data["last_modified"])
	else:
		resource.last_modified = resource.created_time
	
	if data.has("version"):
		resource.version = str(data["version"])
	
	if data.has("author"):
		resource.author = str(data["author"])
	
	if data.has("tags") and data["tags"] is Array:
		resource.tags = data["tags"].duplicate()
	
	return resource

## 验证资源状态
## returns: Array[String] - 错误信息数组
func validate() -> Array[String]:
	var errors: Array[String] = []
	
	# 验证基本属性
	if version.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_GLOBAL_VAR_VERSION_EMPTY"))
	
	if created_time <= 0.0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_GLOBAL_VAR_CREATED_TIME_INVALID"))
	
	if last_modified < created_time:
		errors.append(FuseLocalization.translate("FUSE_ERROR_GLOBAL_VAR_MODIFIED_TIME_EARLIER"))
	
	# 验证变量数据
	for name in variables:
		if not _is_valid_variable_name(name):
			errors.append(FuseLocalization.translate_format("FUSE_ERROR_GLOBAL_VAR_INVALID_NAME", {"name": name}))
		
		if not _is_valid_variable_data(variables[name]):
			errors.append(FuseLocalization.translate_format("FUSE_ERROR_GLOBAL_VAR_INVALID_DATA", {"name": name}))
	
	# 验证标签
	for tag in tags:
		if tag.is_empty():
			errors.append(FuseLocalization.translate("FUSE_ERROR_TAG_EMPTY"))
	
	return errors

## 清理无效变量
## returns: int - 清理的变量数量
func cleanup_invalid_variables() -> int:
	var invalid_names: Array[String] = []
	
	# 找出无效变量
	for name in variables:
		if not _is_valid_variable_name(name) or not _is_valid_variable_data(variables[name]):
			invalid_names.append(name)
	
	# 移除无效变量
	for name in invalid_names:
		variables.erase(name)
	
	if invalid_names.size() > 0:
		update_timestamp()
		_log_info("清理了 %d 个无效变量" % invalid_names.size())
	
	return invalid_names.size()

## 私有方法 - 标准化变量数据格式
## 将原始值或旧格式转换为新格式: {"value": ..., "scope": ..., "persistent": ..., "description": ...}
func _normalize_variable_data(data: Variant, persistent: bool = true) -> Variant:
	if data == null:
		return null

	# 如果已经是新格式字典，确保有所有必需字段
	if data is Dictionary and data.has("value"):
		var normalized = data.duplicate(true)
		if not normalized.has("scope"):
			normalized["scope"] = 0  # LOCAL
		if not normalized.has("persistent"):
			normalized["persistent"] = persistent
		if not normalized.has("description"):
			normalized["description"] = ""
		return normalized

	# 原始值：包装为新格式
	if _is_serializable_value(data):
		return {
			"value": data,
			"scope": 0,  # LOCAL
			"persistent": persistent,
			"description": ""
		}

	# 无法处理的格式
	return null

## 私有方法 - 验证变量名称
func _is_valid_variable_name(name: String) -> bool:
	if name.is_empty():
		return false
	# 检查是否只包含字母、数字、下划线
	return name.is_valid_identifier()

## 私有方法 - 验证变量数据（支持原始值和字典格式）
func _is_valid_variable_data(data: Variant) -> bool:
	if data == null:
		return false

	# 字典格式：需要有 value 键
	if data is Dictionary:
		if not data.has("value"):
			return false
		return _is_serializable_value(data["value"])

	# 原始值：检查是否可序列化
	return _is_serializable_value(data)

## 私有方法 - 检查值是否可序列化
func _is_serializable_value(val) -> bool:
	# 检查基本类型
	if val == null:
		return true
	
	var val_type = typeof(val)
	match val_type:
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return true
		TYPE_VECTOR2, TYPE_VECTOR3, TYPE_VECTOR4, TYPE_RECT2, TYPE_COLOR:
			return true
		TYPE_ARRAY:
			# 递归检查数组元素
			for element in val:
				if not _is_serializable_value(element):
					return false
			return true
		TYPE_DICTIONARY:
			# 递归检查字典值
			for key in val:
				if not _is_serializable_value(val[key]):
					return false
			return true
		_:
			return false

## 私有方法 - 深拷贝字典
static func _deep_copy_dict(original: Dictionary) -> Dictionary:
	var copy = {}
	for key in original:
		copy[key] = _deep_copy_value(original[key])
	return copy

## 私有方法 - 深拷贝值
static func _deep_copy_value(val):
	if val is Dictionary:
		return _deep_copy_dict(val)
	elif val is Array:
		var copy = []
		for element in val:
			copy.append(_deep_copy_value(element))
		return copy
	else:
		return val

## 私有方法 - 格式化时间戳
func _format_timestamp(timestamp: float) -> String:
	if timestamp <= 0.0:
		return "从未"
	
	var current_time = Time.get_ticks_msec() / 1000.0
	var diff = current_time - timestamp
	
	if diff < 60:
		return "%d秒前" % int(diff)
	elif diff < 3600:
		return "%d分钟前" % int(diff / 60)
	elif diff < 86400:
		return "%d小时前" % int(diff / 3600)
	else:
		return "%d天前" % int(diff / 86400)

## 创建 FuseError 实例
func _create_fuse_error(message: String, error_type: FuseError.ErrorType = FuseError.ErrorType.RUNTIME_ERROR, context: Dictionary = {}):
	var error_context = context.duplicate()
	error_context["component"] = "GlobalVariableResource"
	error_context["resource_description"] = description
	error_context["resource_version"] = version
	error_context["variable_count"] = variables.size()
	error_context["is_empty"] = is_empty()
	
	_fuse_error = FuseError.create_with_context(error_type, "GlobalVariableResource", message, error_context)

## 获取 FuseError 实例
func get_fuse_error() -> FuseError:
	return _fuse_error

## 检查是否有 FuseError
func has_fuse_error() -> bool:
	return _fuse_error != null

## 统一日志方法
func _log_debug(message: String):
	FuseLogger.log_debug("GlobalVariableResource", log_level, message)

func _log_info(message: String):
	FuseLogger.log_info("GlobalVariableResource", log_level, message)

func _log_warning(message: String):
	FuseLogger.log_warning("GlobalVariableResource", log_level, message)

func _log_error(message: String):
	FuseLogger.log_error("GlobalVariableResource", log_level, message)