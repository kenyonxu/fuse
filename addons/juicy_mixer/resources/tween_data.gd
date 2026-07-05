# TweenData - 补间数据类
# 定义单个属性的补间参数，支持序列化和编辑器显示

@tool
class_name TweenData
extends JuicyFeedbackData

# =============================================================================
# 属性定义
# =============================================================================

# 私有存储变量
@export_storage var _target_property: JuicyMixerEnums.tween_properties = JuicyMixerEnums.tween_properties.custom

# 目标属性选择
@export var target_property: JuicyMixerEnums.tween_properties = JuicyMixerEnums.tween_properties.custom:
	set(value):
		if _target_property != value:
			_target_property = value
			# 自动设置 property 值
			property = JuicyMixerEnums.get_tween_property_name(value)
	get:
		return _target_property

## 目标属性名称
@export var property: String = ""

## 起始值
@export var from_value: Variant:
	set(value):
		from_value = value
		# 根据from_value类型自动设置to_value的默认值
		to_value = _get_default_to_value(value)

## 目标值
@export var to_value: Variant

## 缓动类型 (EASE_IN, EASE_OUT, EASE_IN_OUT)
@export_enum("EASE_IN", "EASE_OUT", "EASE_IN_OUT") var ease_type: int = Tween.EASE_IN_OUT

## 过渡类型 (LINEAR, SINE, QUAD, CUBIC等)
@export_enum(
	"LINEAR", "SINE", "QUAD", "CUBIC", "QUART", "QUINT", 
	"EXPO", "CIRC", "BACK", "BOUNCE", "ELASTIC"
) var trans_type: int = Tween.TRANS_LINEAR

## 延迟时间（秒）
@export_range(0.0, 10.0, 0.1, "or_greater") var delay: float = 0.0

## 持续时间（秒）
@export_range(0.1, 60.0, 0.1, "or_greater") var duration: float = 1.0

## 是否使用相对值
@export var relative: bool = false

# =============================================================================
# 初始化方法
# =============================================================================

func _init():
	"""
	初始化函数，确保 property 值与 target_property 同步
	"""
	property = JuicyMixerEnums.get_tween_property_name(_target_property)

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
	
	if duration <= 0:
		result.valid = false
		result.issues.append("Duration must be greater than 0")
	
	if delay < 0:
		result.valid = false
		result.issues.append("Delay cannot be negative")
	
	# 验证值类型兼容性
	if typeof(from_value) != typeof(to_value):
		result.warnings.append("from_value and to_value have different types")
	
	return result

# =============================================================================
# 类型辅助方法
# =============================================================================

func _get_default_to_value(from_val: Variant) -> Variant:
	"""
	根据from_value的值自动生成合适的to_value默认值
	
	@param from_val: 起始值
	@return: 对应的目标值
	"""
	match typeof(from_val):
		TYPE_VECTOR2:
			return from_val + Vector2(10, 10)  # 位置向右下方偏移
		TYPE_VECTOR3:
			return from_val + Vector3(10, 10, 10)  # 位置向右下方偏移
		TYPE_COLOR:
			return Color(1.0, 1.0, 1.0, 1.0)  # 白色
		TYPE_BOOL:
			return !from_val  # 布尔值取反
		TYPE_INT:
			return from_val + 10  # 整数增加10
		TYPE_FLOAT:
			return from_val + 10.0  # 浮点数增加10.0
		TYPE_STRING:
			return "New Text"  # 默认文本
		_:
			return from_val  # 其他类型保持不变

# =============================================================================
# 实用方法
# =============================================================================

func get_description() -> String:
	"""
	获取友好的描述字符串
	
	@return: 描述字符串
	"""
	return "%s: %s→%s (%.1fs)" % [property, str(from_value), str(to_value), duration]

func duplicate_tween_data() -> TweenData:
	"""
	复制当前实例
	
	@return: 新的TweenData实例
	"""
	var new_data = TweenData.new()
	new_data._target_property = _target_property  # 直接设置私有变量，避免重复触发setter
	new_data.property = property  # 同步property值
	new_data.from_value = from_value
	new_data.to_value = to_value
	new_data.ease_type = ease_type
	new_data.trans_type = trans_type
	new_data.delay = delay
	new_data.duration = duration
	new_data.relative = relative
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
	return "TweenData(%s: %s→%s, %.1fs, %s/%s)" % [
		property, str(from_value), str(to_value), duration,
		_get_ease_type_name(ease_type), _get_trans_type_name(trans_type)
	]

func _get_ease_type_name(ease_type: int) -> String:
	"""
	获取缓动类型名称
	
	@param ease_type: 缓动类型枚举值
	
	@return: 名称字符串
	"""
	match ease_type:
		Tween.EASE_IN: return "EASE_IN"
		Tween.EASE_OUT: return "EASE_OUT"
		Tween.EASE_IN_OUT: return "EASE_IN_OUT"
		_: return "UNKNOWN"

func _get_trans_type_name(trans_type: int) -> String:
	"""
	获取过渡类型名称
	
	@param trans_type: 过渡类型枚举值
	
	@return: 名称字符串
	"""
	match trans_type:
		Tween.TRANS_LINEAR: return "LINEAR"
		Tween.TRANS_SINE: return "SINE"
		Tween.TRANS_QUAD: return "QUAD"
		Tween.TRANS_CUBIC: return "CUBIC"
		Tween.TRANS_QUART: return "QUART"
		Tween.TRANS_QUINT: return "QUINT"
		Tween.TRANS_EXPO: return "EXPO"
		Tween.TRANS_CIRC: return "CIRC"
		Tween.TRANS_BACK: return "BACK"
		Tween.TRANS_BOUNCE: return "BOUNCE"
		Tween.TRANS_ELASTIC: return "ELASTIC"
		_: return "UNKNOWN"

