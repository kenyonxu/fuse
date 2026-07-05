# ShakeData - 震动数据类
# 定义单个属性的震动参数，支持序列化和编辑器显示

@tool
class_name ShakeData
extends JuicyFeedbackData

# =============================================================================
# 属性定义
# =============================================================================

# 私有存储变量
@export_storage var _target_property: JuicyMixerEnums.shake_properties = JuicyMixerEnums.shake_properties.custom

# 目标属性选择
@export var target_property: JuicyMixerEnums.shake_properties = JuicyMixerEnums.shake_properties.custom:
	set(value):
		if _target_property != value:
			_target_property = value
			# 自动设置 property 值
			property = JuicyMixerEnums.get_shake_property_name(value)
	get:
		return _target_property

## 目标属性名称
@export var property: String = ""

## 震动振幅（像素/弧度/缩放系数）
@export_range(0.1, 100.0, 0.1, "or_greater") var amplitude: float = 10.0:
	set(value):
		amplitude = value
		# 注意：不在这里自动调整frequency，因为这会覆盖用户设置的值
		# frequency的默认值会在初始化时设置

## 震动频率（Hz）
@export_range(0.1, 50.0, 0.1, "or_greater") var frequency: float = 10.0

## 震动持续时间（秒）
@export_range(0.1, 10.0, 0.1, "or_greater") var duration: float = 1.0

## 衰减类型
@export_enum("LINEAR", "EXPONENTIAL", "LOGARITHMIC", "NONE") var falloff: int = 0  # ShakeFalloff.LINEAR

## 噪声种子（0表示随机种子）
@export var noise_seed: int = 0

## 八度音数量（用于细节层次）
@export_range(1, 8, 1, "or_greater") var octaves: int = 1

## 持久性（控制八度音的强度衰减）
@export_range(0.0, 1.0, 0.01) var persistence: float = 0.5

## 间隙度（控制八度音的频率增长）
@export_range(1.0, 4.0, 0.1) var lacunarity: float = 2.0

# =============================================================================
# 初始化方法
# =============================================================================

func _init():
	"""
	初始化函数，确保 property 值与 target_property 同步
	"""
	property = JuicyMixerEnums.get_shake_property_name(_target_property)
	# 根据property类型设置默认频率
	frequency = _get_default_frequency(property)

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
	
	if amplitude <= 0:
		result.valid = false
		result.issues.append("Amplitude must be greater than 0")
	
	if frequency <= 0:
		result.valid = false
		result.issues.append("Frequency must be greater than 0")
	
	if duration <= 0:
		result.valid = false
		result.issues.append("Duration must be greater than 0")
	
	if octaves < 1:
		result.valid = false
		result.issues.append("Octaves must be at least 1")
	
	if persistence < 0 or persistence > 1:
		result.valid = false
		result.issues.append("Persistence must be between 0 and 1")
	
	if lacunarity < 1:
		result.valid = false
		result.issues.append("Lacunarity must be at least 1")
	
	return result

# =============================================================================
# 类型辅助方法
# =============================================================================

func _get_default_frequency(prop_name: String) -> float:
	"""
	根据property名称自动生成合适的frequency默认值
	
	@param prop_name: 属性名称
	@return: 对应的频率值
	"""
	match prop_name:
		"position", "global_position", "offset", "pivot_offset":
			return 15.0  # 位置震动需要较高的频率
		"rotation", "global_rotation":
			return 20.0  # 旋转震动需要更高的频率
		"scale", "global_scale":
			return 10.0  # 缩放震动需要较低的频率
		"modulate", "self_modulate":
			return 5.0  # 颜色震动需要较低的频率
		"zoom":
			return 12.0  # 缩放震动需要中等频率
		_:
			return 10.0  # 默认频率

# =============================================================================
# 实用方法
# =============================================================================

func get_description() -> String:
	"""
	获取友好的描述字符串
	
	@return: 描述字符串
	"""
	var falloff_names = ["LINEAR", "EXPONENTIAL", "LOGARITHMIC", "NONE"]
	var falloff_name = falloff_names[falloff] if falloff < falloff_names.size() else "UNKNOWN"
	
	return "%s: amp=%.1f, freq=%.1f, dur=%.1fs, falloff=%s" % [
		property, amplitude, frequency, duration, falloff_name
	]

func duplicate_shake_data() -> ShakeData:
	"""
	复制当前实例
	
	@return: 新的ShakeData实例
	"""
	var new_data = ShakeData.new()
	new_data._target_property = _target_property  # 直接设置私有变量，避免重复触发setter
	new_data.property = property  # 同步property值
	new_data.amplitude = amplitude
	new_data.frequency = frequency
	new_data.duration = duration
	new_data.falloff = falloff
	new_data.noise_seed = noise_seed
	new_data.octaves = octaves
	new_data.persistence = persistence
	new_data.lacunarity = lacunarity
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
	var falloff_names = ["LINEAR", "EXPONENTIAL", "LOGARITHMIC", "NONE"]
	var falloff_name = falloff_names[falloff] if falloff < falloff_names.size() else "UNKNOWN"
	
	return "ShakeData(%s: amp=%.1f, freq=%.1f, dur=%.1fs, falloff=%s, seed=%d)" % [
		property, amplitude, frequency, duration, falloff_name, noise_seed
	]
