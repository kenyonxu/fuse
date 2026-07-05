@tool
class_name JuicyTimeGroupConfig
extends Resource

# 时间组配置属性
@export var config_name: String = "default_time_groups"
@export var time_groups: Dictionary = {
	"default": 1.0,
	"player": 1.0,
	"enemies": 1.0,
	"npc": 1.0,
	"projectiles": 1.0,
	"ui": 1.0,
	"vfx": 1.0,
	"unscaled": 1.0
}
@export var description: String = ""

func _init():
	"""初始化时间组配置"""
	resource_name = "TimeGroupConfig: " + config_name

# 验证配置
func validate() -> Dictionary:
	"""验证配置的有效性"""
	var result = {
		"valid": true,
		"issues": [],
		"warnings": []
	}
	
	if config_name.is_empty():
		result.valid = false
		result.issues.append("Config name cannot be empty")
	
	if time_groups.is_empty():
		result.valid = false
		result.issues.append("Time groups dictionary cannot be empty")
	
	# 验证每个时间组的时间缩放值
	for group_name in time_groups.keys():
		var time_scale = time_groups[group_name]
		if typeof(time_scale) != TYPE_FLOAT:
			result.valid = false
			result.issues.append("Time scale for group '" + str(group_name) + "' must be a number")
		elif time_scale < 0.0:
			result.valid = false
			result.issues.append("Time scale for group '" + str(group_name) + "' cannot be negative")
	
	return result

# 获取配置描述
func get_description() -> String:
	"""获取配置的友好描述"""
	return "TimeGroups '%s': %d groups configured" % [
		config_name,
		time_groups.size()
	]

# 获取时间组缩放值
func get_time_scale(group_name: String) -> float:
	"""获取指定时间组的时间缩放值"""
	return time_groups.get(group_name, 1.0)

# 设置时间组缩放值
func set_time_scale(group_name: String, scale: float) -> void:
	"""设置指定时间组的时间缩放值"""
	time_groups[group_name] = max(0.0, scale)

# 移除时间组
func remove_time_group(group_name: String) -> void:
	"""移除指定的时间组"""
	time_groups.erase(group_name)

# 获取所有时间组名称
func get_time_group_names() -> Array[String]:
	"""获取所有时间组的名称"""
	var names: Array[String] = []
	for group_name in time_groups.keys():
		names.append(group_name)
	return names

# 检查时间组是否存在
func has_time_group(group_name: String) -> bool:
	"""检查指定的时间组是否存在"""
	return time_groups.has(group_name)

# 编辑器支持
func _get_property_list() -> Array[Dictionary]:
	"""获取属性列表，用于编辑器显示"""
	var properties = []
	
	properties.append({
		"name": "config_name",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_NONE,
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	properties.append({
		"name": "description",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_MULTILINE_TEXT,
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	properties.append({
		"name": "time_groups",
		"type": TYPE_DICTIONARY,
		"hint": PROPERTY_HINT_NONE,
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	return properties

# 序列化支持
func _to_string() -> String:
	"""获取字符串表示"""
	return get_description()

# 获取详细配置信息
func get_detailed_info() -> String:
	"""获取详细的配置信息"""
	var info = "TimeGroupConfig: " + config_name + "\n"
	if not description.is_empty():
		info += "Description: " + description + "\n"
	info += "Groups:\n"
	for group_name in time_groups.keys():
		info += "  " + group_name + ": " + str(time_groups[group_name]) + "\n"
	return info