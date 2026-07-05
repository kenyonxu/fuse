# JuicyChannelConfig - 通道配置资源
# 定义通道的配置参数，提供可序列化的配置存储

@tool
class_name JuicyChannelConfig
extends Resource

# 通道配置属性
@export var channel_name: String = "default"
@export var max_concurrent: int = -1  # -1表示无限制
@export var priority_mode: int = 0  # 0=FIFO, 1=LIFO, 2=PRIORITY_BASED
@export var allow_interruption: bool = true
@export var auto_stop_previous: bool = false
@export var description: String = ""

func _init():
	"""初始化通道配置"""
	resource_name = "ChannelConfig: " + channel_name

# 验证配置
func validate() -> Dictionary:
	"""验证配置的有效性"""
	var result = {
		"valid": true,
		"issues": [],
		"warnings": []
	}
	
	if channel_name.is_empty():
		result.valid = false
		result.issues.append("Channel name cannot be empty")
	
	if max_concurrent < -1:
		result.valid = false
		result.issues.append("Max concurrent must be -1 or greater")
	
	return result

# 获取配置描述
func get_description() -> String:
	"""获取配置的友好描述"""
	var priority_names = ["FIFO", "LIFO", "PRIORITY_BASED"]
	var priority_name = priority_names[priority_mode] if priority_mode < priority_names.size() else "UNKNOWN"
	
	return "Channel '%s': max=%s, mode=%s, interrupt=%s" % [
		channel_name,
		"unlimited" if max_concurrent == -1 else str(max_concurrent),
		priority_name,
		allow_interruption
	]

# 编辑器支持
func _get_property_list() -> Array[Dictionary]:
	"""获取属性列表，用于编辑器显示"""
	var properties = []
	
	properties.append({
		"name": "priority_mode",
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "FIFO,LIFO,PRIORITY_BASED",
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	return properties

# 序列化支持
func _to_string() -> String:
	"""获取字符串表示"""
	return get_description()