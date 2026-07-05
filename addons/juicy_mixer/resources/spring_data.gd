# SpringData - 弹簧数据类
# 定义单个属性的弹簧参数，支持序列化和编辑器显示

@tool
class_name SpringData
extends JuicyFeedbackData

# =============================================================================
# 属性定义
# =============================================================================

# 私有存储变量
@export_storage var _target_property: JuicyMixerEnums.spring_properties = JuicyMixerEnums.spring_properties.custom

# 目标属性选择
@export var target_property: JuicyMixerEnums.spring_properties = JuicyMixerEnums.spring_properties.custom:
	set(value):
		if _target_property != value:
			_target_property = value
			# 自动设置 property 值
			property = JuicyMixerEnums.get_spring_property_name(value)
	get:
		return _target_property

## 目标属性名称
@export var property: String = ""

## 目标值
@export var target_value: Variant:
	set(value):
		target_value = value
		# 根据target_value类型自动设置initial_velocity的默认值
		initial_velocity = _get_default_initial_velocity(value)

## 刚度（弹簧常数k）
@export_range(0.1, 1000.0, 1.0, "or_greater") var stiffness: float = 100.0

## 阻尼系数（c）
@export_range(0.0, 100.0, 0.1, "or_greater") var damping: float = 10.0

## 质量（m）
@export_range(0.1, 10.0, 0.1, "or_greater") var mass: float = 1.0

## 初始速度
@export var initial_velocity: Variant = 0.0

## 稳定阈值（位置和速度都小于此值时认为稳定）
@export_range(0.001, 1.0, 0.001, "or_greater") var threshold: float = 0.01

# =============================================================================
# 初始化方法
# =============================================================================

func _init():
	"""
	初始化函数，确保 property 值与 target_property 同步
	"""
	property = JuicyMixerEnums.get_spring_property_name(_target_property)

# =============================================================================
# 验证方法
# =============================================================================

func validate() -> Dictionary:
	"""
	验证数据有效性
	
	@return: 验证结果字典，包含valid、issues和warnings
	"""
	var result = {
		"valid": true,
		"issues": [],
		"warnings": []
	}
	
	if property.is_empty():
		result.valid = false
		result.issues.append("Property name cannot be empty")
	
	if stiffness <= 0:
		result.valid = false
		result.issues.append("Stiffness must be greater than 0")
	
	if damping < 0:
		result.valid = false
		result.issues.append("Damping must be non-negative")
	
	if mass <= 0:
		result.valid = false
		result.issues.append("Mass must be greater than 0")
	
	if threshold <= 0:
		result.valid = false
		result.issues.append("Threshold must be greater than 0")
	
	return result

# =============================================================================
# 类型辅助方法
# =============================================================================

func _get_default_initial_velocity(target_val: Variant) -> Variant:
	"""
	根据target_value的值自动生成合适的initial_velocity默认值
	
	@param target_val: 目标值
	@return: 对应的初始速度
	"""
	match typeof(target_val):
		TYPE_VECTOR2:
			return Vector2(50, 50)  # 较大的初始速度
		TYPE_VECTOR3:
			return Vector3(50, 50, 50)  # 较大的初始速度
		TYPE_COLOR:
			return Color(0.5, 0.5, 0.5, 0.5)  # 中等初始速度
		TYPE_BOOL:
			return 1.0  # 布尔值的初始速度
		TYPE_INT:
			return 10  # 整数的初始速度
		TYPE_FLOAT:
			return 10.0  # 浮点数的初始速度
		TYPE_STRING:
			return 0.0  # 文本的初始速度
		_:
			return 0.0  # 其他类型的默认初始速度

# =============================================================================
# 实用方法
# =============================================================================

func get_description() -> String:
	"""
	获取友好的描述字符串
	
	@return: 描述字符串
	"""
	return "%s: →%s (k=%.1f, c=%.1f, m=%.1f)" % [
		property, str(target_value), stiffness, damping, mass
	]

func duplicate_spring_data() -> SpringData:
	"""
	复制当前实例
	
	@return: 新的SpringData实例
	"""
	var new_data = SpringData.new()
	new_data._target_property = _target_property  # 直接设置私有变量，避免重复触发setter
	new_data.property = property  # 同步property值
	new_data.target_value = target_value
	new_data.stiffness = stiffness
	new_data.damping = damping
	new_data.mass = mass
	new_data.initial_velocity = initial_velocity
	new_data.threshold = threshold
	return new_data

# =============================================================================
# 编辑器支持
# =============================================================================

func _get_configuration_warning() -> String:
	"""
	获取配置警告信息
	
	@return: 警告信息字符串
	"""
	var result = validate()
	if not result.valid:
		return "Configuration errors: " + ", ".join(result.issues)
	
	if not result.warnings.is_empty():
		return "Configuration warnings: " + ", ".join(result.warnings)
	
	return ""

# =============================================================================
# 序列化支持
# =============================================================================

func _to_string() -> String:
	"""
	获取对象的字符串表示
	
	@return: 描述字符串
	"""
	return "SpringData(%s: →%s, k=%.1f, c=%.1f, m=%.1f, threshold=%.3f)" % [
		property, str(target_value), stiffness, damping, mass, threshold
	]

