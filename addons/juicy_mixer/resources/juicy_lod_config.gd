@tool
class_name JuicyLODConfig
extends Resource

# LOD配置属性
@export var config_name: String = "default_lod"
@export var max_distance: float = 500.0
@export var distance_thresholds: Array = [100.0, 200.0, 300.0]
@export var intensity_multipliers: Array = [1.0, 0.75, 0.5, 0.25, 0.0]
@export var enable_frustum_culling: bool = true
@export var enable_distance_culling: bool = true
@export var description: String = ""

func _init():
	"""初始化LOD配置"""
	resource_name = "LODConfig: " + config_name

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
	
	if max_distance <= 0:
		result.valid = false
		result.issues.append("Max distance must be greater than 0")
	
	if distance_thresholds.size() + 1 != intensity_multipliers.size():
		result.valid = false
		result.issues.append("Intensity multipliers array must be one element larger than distance thresholds array")
	
	# 检查距离阈值是否递增
	for i in range(1, distance_thresholds.size()):
		if distance_thresholds[i] <= distance_thresholds[i-1]:
			result.valid = false
			result.issues.append("Distance thresholds must be in ascending order")
			break
	
	return result

# 获取配置描述
func get_description() -> String:
	"""获取配置的友好描述"""
	return "LOD '%s': max_dist=%.1f, thresholds=%d, frustum=%s, distance=%s" % [
		config_name,
		max_distance,
		distance_thresholds.size(),
		enable_frustum_culling,
		enable_distance_culling
	]

# 计算强度倍数
func calculate_intensity_multiplier(distance: float) -> float:
	"""根据距离计算强度倍数"""
	if distance > max_distance:
		return 0.0
	
	for i in range(distance_thresholds.size()):
		if distance <= distance_thresholds[i]:
			return intensity_multipliers[i]
	
	# 超出所有阈值但在最大距离内，返回最后一个有效的强度倍数
	if intensity_multipliers.size() > distance_thresholds.size():
		return intensity_multipliers[distance_thresholds.size()]
	
	return 0.0

# 编辑器支持
func _get_property_list() -> Array[Dictionary]:
	"""获取属性列表，用于编辑器显示"""
	var properties = []
	
	properties.append({
		"name": "distance_thresholds",
		"type": TYPE_ARRAY,
		"hint": PROPERTY_HINT_ARRAY_TYPE,
		"hint_string": "float",
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	properties.append({
		"name": "intensity_multipliers",
		"type": TYPE_ARRAY,
		"hint": PROPERTY_HINT_ARRAY_TYPE,
		"hint_string": "float",
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	return properties

# 序列化支持
func _to_string() -> String:
	"""获取字符串表示"""
	return get_description()