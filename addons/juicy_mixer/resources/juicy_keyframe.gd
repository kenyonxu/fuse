# JuicyKeyframe - 关键帧数据结构
# 定义关键帧的时间、值和插值类型
# 支持缓动参数和自定义插值

@tool
class_name JuicyKeyframe
extends Resource

# 插值类型枚举
enum InterpolationType {
	LINEAR,         # 线性插值
	EASE_IN,        # 缓入
	EASE_OUT,       # 缓出
	EASE_IN_OUT,    # 缓入缓出
	STEP,           # 阶跃
	CUSTOM          # 自定义
}

# 基础属性
@export var time: float = 0.0                      # 时间点（秒）
var value: Variant = 0.0                           # 值（动态类型）
@export var interpolation: InterpolationType = InterpolationType.LINEAR  # 插值类型

# 内部属性：用于编辑器显示
var _property_type: int = TYPE_FLOAT                # 值的属性类型（用于编辑器）

# 缓动参数
@export var ease_in: float = 0.0                   # 缓入强度 (0.0-1.0)
@export var ease_out: float = 0.0                  # 缓出强度 (0.0-1.0)
@export var ease_power: float = 2.0                # 缓动幂次

# 高级属性
@export var tangent_in: float = 0.0                # 入切线斜率
@export var tangent_out: float = 0.0               # 出切线斜率
@export var break_tangent: bool = false            # 断开切线
@export var locked: bool = false                   # 锁定关键帧

# 自定义插值函数（仅当interpolation为CUSTOM时使用）
@export var custom_interpolation: Callable          # 自定义插值函数

## 编辑器属性列表
func _get_property_list() -> Array[Dictionary]:
	"""根据属性类型动态生成属性列表"""
	var properties: Array[Dictionary] = []
	
	# 添加基础属性
	properties.append({
		"name": "time",
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_NONE,
		"default": 0.0,
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
	})
	
	# 根据属性类型动态定义value属性
	# 修复：优先使用_property_type，而不是typeof(value)
	# 这确保当property_path改变时，value属性类型正确更新
	var value_type = _property_type
	
	# 如果存储的类型和实际value类型不匹配，重置value为默认值
	# 这发生在property_path改变时：_property_type已更新但value仍是旧类型
	if typeof(value) != _property_type:
		print("[JuicyKeyframe._get_property_list] 类型不匹配，重置value: typeof(value)=", typeof(value), " _property_type=", _property_type)
		value = _get_default_value_for_type(_property_type)
	
	var value_property = {
		"name": "value",
		"type": value_type,  # ← 使用_property_type
		"hint": PROPERTY_HINT_NONE,
		"default": _get_default_value_for_type(value_type),
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
	}
	properties.append(value_property)
	print("[JuicyKeyframe._get_property_list] value类型: ", value_type, " value: ", value)
	
	# 添加插值类型属性
	properties.append({
		"name": "interpolation",
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Linear,Ease In,Ease Out,Ease In Out,Step,Custom",
		"default": InterpolationType.LINEAR,
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
	})
	
	# 添加其他属性
	properties.append({
		"name": "ease_in",
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0.0,1.0,0.01",
		"default": 0.0,
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
	})
	
	properties.append({
		"name": "ease_out",
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0.0,1.0,0.01",
		"default": 0.0,
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
	})
	
	properties.append({
		"name": "ease_power",
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0.1,10.0,0.1",
		"default": 2.0,
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
	})
	
	properties.append({
		"name": "tangent_in",
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_NONE,
		"default": 0.0,
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
	})
	
	properties.append({
		"name": "tangent_out",
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_NONE,
		"default": 0.0,
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
	})
	
	properties.append({
		"name": "break_tangent",
		"type": TYPE_BOOL,
		"hint": PROPERTY_HINT_NONE,
		"default": false,
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
	})
	
	properties.append({
		"name": "locked",
		"type": TYPE_BOOL,
		"hint": PROPERTY_HINT_NONE,
		"default": false,
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
	})
	
	properties.append({
		"name": "custom_interpolation",
		"type": TYPE_CALLABLE,
		"hint": PROPERTY_HINT_NONE,
		"default": Callable(),
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
	})
	
	return properties

## 获取类型的默认值
func _get_default_value_for_type(type: int) -> Variant:
	"""根据类型获取默认值"""
	match type:
		TYPE_INT:
			return 0
		TYPE_FLOAT:
			return 0.0
		TYPE_VECTOR2:
			return Vector2.ZERO
		TYPE_VECTOR3:
			return Vector3.ZERO
		TYPE_COLOR:
			return Color.WHITE
		TYPE_BOOL:
			return false
		_:
			return 0.0

## 设置属性类型
func set_property_type(type: int):
	"""设置值属性的类型（用于编辑器显示）"""
	_property_type = type
	notify_property_list_changed()

# 验证关键帧配置
func validate_keyframe() -> String:
	"""
	验证关键帧配置
	
	@return: 错误信息字符串，空字符串表示无错误
	"""
	if time < 0.0:
		return "Time cannot be negative"
	
	if ease_in < 0.0 or ease_in > 1.0:
		return "Ease in must be between 0.0 and 1.0"
	
	if ease_out < 0.0 or ease_out > 1.0:
		return "Ease out must be between 0.0 and 1.0"
	
	if ease_power <= 0.0:
		return "Ease power must be positive"
	
	if interpolation == InterpolationType.CUSTOM and not custom_interpolation.is_valid():
		return "Custom interpolation function is not valid"
	
	return ""

# 获取插值权重
func get_interpolation_weight(t: float) -> float:
	"""
	获取插值权重
	
	@param t: 插值参数 (0.0-1.0)
	@return: 插值权重
	"""
	match interpolation:
		InterpolationType.LINEAR:
			return t
		
		InterpolationType.EASE_IN:
			return _ease_in(t)
		
		InterpolationType.EASE_OUT:
			return _ease_out(t)
		
		InterpolationType.EASE_IN_OUT:
			return _ease_in_out(t)
		
		InterpolationType.STEP:
			return 0.0 if t < 1.0 else 1.0
		
		InterpolationType.CUSTOM:
			if custom_interpolation.is_valid():
				return custom_interpolation.call(t)
			else:
				return t
		
		_:
			return t

# 应用缓动函数
func _ease_in(t: float) -> float:
	"""应用缓入函数"""
	if ease_in == 0.0:
		return t
	
	# 使用缓入强度调整
	var adjusted_t = t * ease_in + (1.0 - ease_in) * t
	return pow(adjusted_t, ease_power)

func _ease_out(t: float) -> float:
	"""应用缓出函数"""
	if ease_out == 0.0:
		return t
	
	# 使用缓出强度调整
	var adjusted_t = t * ease_out + (1.0 - ease_out) * t
	return 1.0 - pow(1.0 - adjusted_t, ease_power)

func _ease_in_out(t: float) -> float:
	"""应用缓入缓出函数"""
	if ease_in == 0.0 and ease_out == 0.0:
		return t
	
	# 混合缓入和缓出
	var ease_in_weight = ease_in / (ease_in + ease_out) if (ease_in + ease_out) > 0.0 else 0.5
	var ease_out_weight = ease_out / (ease_in + ease_out) if (ease_in + ease_out) > 0.0 else 0.5
	
	if t < 0.5:
		# 前半段使用缓入
		var adjusted_t = t * 2.0 * ease_in_weight + (1.0 - ease_in_weight) * t * 2.0
		return 0.5 * pow(adjusted_t, ease_power)
	else:
		# 后半段使用缓出
		var adjusted_t = (t - 0.5) * 2.0 * ease_out_weight + (1.0 - ease_out_weight) * (t - 0.5) * 2.0
		return 0.5 + 0.5 * (1.0 - pow(1.0 - adjusted_t, ease_power))

# 获取贝塞尔控制点
func get_bezier_control_points() -> Array:
	"""
	获取贝塞尔控制点（用于编辑器显示）
	
	@return: 控制点数组 [control_in, control_out]
	"""
	var control_in = Vector2(time - 0.1, value - tangent_in * 0.1)
	var control_out = Vector2(time + 0.1, value + tangent_out * 0.1)
	
	return [control_in, control_out]

# 设置切线
func set_tangents(in_tangent: float, out_tangent: float) -> void:
	"""
	设置切线
	
	@param in_tangent: 入切线斜率
	@param out_tangent: 出切线斜率
	"""
	tangent_in = in_tangent
	tangent_out = out_tangent
	
	if not break_tangent:
		# 如果没有断开切线，保持对称
		tangent_out = tangent_in

# 获取描述信息
func get_description() -> String:
	"""
	获取关键帧描述信息
	
	@return: 描述字符串
	"""
	var desc = "JuicyKeyframe: "
	desc += "time=" + str(time)
	desc += ", value=" + str(value)
	desc += ", interpolation=" + InterpolationType.keys()[interpolation]
	
	if interpolation != InterpolationType.LINEAR and interpolation != InterpolationType.STEP:
		desc += ", ease_in=" + str(ease_in)
		desc += ", ease_out=" + str(ease_out)
		desc += ", ease_power=" + str(ease_power)
	
	if tangent_in != 0.0 or tangent_out != 0.0:
		desc += ", tangents=(" + str(tangent_in) + ", " + str(tangent_out) + ")"
	
	return desc

# 序列化支持
func get_config_dict() -> Dictionary:
	"""
	获取配置字典（用于序列化）
	
	@return: 配置字典
	"""
	return {
		"time": time,
		"value": value,
		"interpolation": InterpolationType.keys()[interpolation],
		"ease_in": ease_in,
		"ease_out": ease_out,
		"ease_power": ease_power,
		"tangent_in": tangent_in,
		"tangent_out": tangent_out,
		"break_tangent": break_tangent,
		"locked": locked,
		"_property_type": _property_type  # 关键修复：持久化属性类型
	}

# 从配置字典加载
func load_from_dict(config_dict: Dictionary) -> bool:
	"""
	从配置字典加载
	
	@param config_dict: 配置字典
	@return: 是否成功加载
	"""
	if not config_dict:
		return false
	
	if config_dict.has("time"):
		time = config_dict["time"]
	if config_dict.has("value"):
		value = config_dict["value"]
		# 推断并设置属性类型（解决编辑器重启后类型丢失的问题）
		var value_type = typeof(value)
		_property_type = value_type
		print("[JuicyKeyframe.load_from_dict] 推断类型: ", value_type, " value: ", value)
	if config_dict.has("interpolation"):
		var interp_name = config_dict["interpolation"]
		for i in range(InterpolationType.values().size()):
			if InterpolationType.keys()[i] == interp_name:
				interpolation = InterpolationType.values()[i]
				break
	if config_dict.has("ease_in"):
		ease_in = config_dict["ease_in"]
	if config_dict.has("ease_out"):
		ease_out = config_dict["ease_out"]
	if config_dict.has("ease_power"):
		ease_power = config_dict["ease_power"]
	if config_dict.has("tangent_in"):
		tangent_in = config_dict["tangent_in"]
	if config_dict.has("tangent_out"):
		tangent_out = config_dict["tangent_out"]
	if config_dict.has("break_tangent"):
		break_tangent = config_dict["break_tangent"]
	if config_dict.has("locked"):
		locked = config_dict["locked"]
	
	return true

# 克隆关键帧
func clone() -> JuicyKeyframe:
	"""
	克隆关键帧
	
	@return: 克隆的关键帧实例
	"""
	var cloned_keyframe = JuicyKeyframe.new()
	
	# 复制所有属性
	cloned_keyframe.time = time
	cloned_keyframe.value = value
	cloned_keyframe.interpolation = interpolation
	cloned_keyframe.ease_in = ease_in
	cloned_keyframe.ease_out = ease_out
	cloned_keyframe.ease_power = ease_power
	cloned_keyframe.tangent_in = tangent_in
	cloned_keyframe.tangent_out = tangent_out
	cloned_keyframe.break_tangent = break_tangent
	cloned_keyframe.locked = locked
	cloned_keyframe.custom_interpolation = custom_interpolation
	
	return cloned_keyframe

# 比较关键帧（用于排序）
static func compare_time(a: JuicyKeyframe, b: JuicyKeyframe) -> bool:
	"""
	比较关键帧时间（用于排序）
	
	@param a: 第一个关键帧
	@param b: 第二个关键帧
	@return: 如果a的时间小于b的时间则返回true
	"""
	return a.time < b.time