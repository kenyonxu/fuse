@tool
class_name JuicyCurveFactory
extends RefCounted

## Curve Factory - 专门创建和管理曲线预设
## 提供缓动函数的Curve实例创建、缓存和预设管理

# ============================================================================
# 枚举定义
# ============================================================================

## 曲线预设分类
enum CurvePresetCategory {
	BASIC = 0,        # 0-3: 基础缓动
	BACK = 1,         # 4-6: 超越缓动
	ELASTIC = 2,      # 7-9: 弹性缓动
	BOUNCE = 3,       # 10-12: 弹跳效果
	EXPONENTIAL = 4,  # 13-15: 指数效果
	SINE = 5,         # 16-18: 正弦效果
	QUADRATIC = 6,    # 19-21: 二次函数
	CUBIC = 7         # 22-24: 三次函数
}

## 曲线预设枚举（25种预设）
enum CurvePreset {
	# Basic (0-3) - 向后兼容 ease_preset
	LINEAR = 0,
	EASE_IN = 1,
	EASE_OUT = 2,
	EASE_IN_OUT = 3,

	# Back (4-6)
	EASE_IN_BACK = 4,
	EASE_OUT_BACK = 5,
	EASE_IN_OUT_BACK = 6,

	# Elastic (7-9)
	EASE_IN_ELASTIC = 7,
	EASE_OUT_ELASTIC = 8,
	EASE_IN_OUT_ELASTIC = 9,

	# Bounce (10-12)
	BOUNCE_IN = 10,
	BOUNCE_OUT = 11,
	BOUNCE_IN_OUT = 12,

	# Exponential (13-15)
	EASE_IN_EXPO = 13,
	EASE_OUT_EXPO = 14,
	EASE_IN_OUT_EXPO = 15,

	# Sine (16-18)
	EASE_IN_SINE = 16,
	EASE_OUT_SINE = 17,
	EASE_IN_OUT_SINE = 18,

	# Quadratic (19-21)
	EASE_IN_QUAD = 19,
	EASE_OUT_QUAD = 20,
	EASE_IN_OUT_QUAD = 21,

	# Cubic (22-24)
	EASE_IN_CUBIC = 22,
	EASE_OUT_CUBIC = 23,
	EASE_IN_OUT_CUBIC = 24
}

# ============================================================================
# 缓存系统
# ============================================================================

## 曲线缓存（预设ID -> Curve实例）
static var _curve_cache: Dictionary = {}

## 缓存统计
static var _cache_hits: int = 0
static var _cache_misses: int = 0

# ============================================================================
# 元数据系统
# ============================================================================

## 预设元数据字典
static var _preset_metadata: Dictionary = {
	CurvePreset.LINEAR: {
		"name": "Linear",
		"description": "Linear interpolation (no easing)",
		"category": CurvePresetCategory.BASIC
	},
	CurvePreset.EASE_IN: {
		"name": "Ease In",
		"description": "Quadratic ease in (gradual start)",
		"category": CurvePresetCategory.BASIC
	},
	CurvePreset.EASE_OUT: {
		"name": "Ease Out",
		"description": "Quadratic ease out (gradual end)",
		"category": CurvePresetCategory.BASIC
	},
	CurvePreset.EASE_IN_OUT: {
		"name": "Ease In Out",
		"description": "Quadratic ease in and out",
		"category": CurvePresetCategory.BASIC
	},
	CurvePreset.EASE_IN_BACK: {
		"name": "Ease In Back",
		"description": "Overshoot at the beginning",
		"category": CurvePresetCategory.BACK
	},
	CurvePreset.EASE_OUT_BACK: {
		"name": "Ease Out Back",
		"description": "Overshoot at the end",
		"category": CurvePresetCategory.BACK
	},
	CurvePreset.EASE_IN_OUT_BACK: {
		"name": "Ease In Out Back",
		"description": "Overshoot at both ends",
		"category": CurvePresetCategory.BACK
	},
	CurvePreset.EASE_IN_ELASTIC: {
		"name": "Ease In Elastic",
		"description": "Elastic effect at the beginning",
		"category": CurvePresetCategory.ELASTIC
	},
	CurvePreset.EASE_OUT_ELASTIC: {
		"name": "Ease Out Elastic",
		"description": "Elastic effect at the end",
		"category": CurvePresetCategory.ELASTIC
	},
	CurvePreset.EASE_IN_OUT_ELASTIC: {
		"name": "Ease In Out Elastic",
		"description": "Elastic effect at both ends",
		"category": CurvePresetCategory.ELASTIC
	},
	CurvePreset.BOUNCE_IN: {
		"name": "Bounce In",
		"description": "Bounce effect at the beginning",
		"category": CurvePresetCategory.BOUNCE
	},
	CurvePreset.BOUNCE_OUT: {
		"name": "Bounce Out",
		"description": "Bounce effect at the end",
		"category": CurvePresetCategory.BOUNCE
	},
	CurvePreset.BOUNCE_IN_OUT: {
		"name": "Bounce In Out",
		"description": "Bounce effect at both ends",
		"category": CurvePresetCategory.BOUNCE
	},
	CurvePreset.EASE_IN_EXPO: {
		"name": "Ease In Expo",
		"description": "Exponential ease in (very gradual start)",
		"category": CurvePresetCategory.EXPONENTIAL
	},
	CurvePreset.EASE_OUT_EXPO: {
		"name": "Ease Out Expo",
		"description": "Exponential ease out (very gradual end)",
		"category": CurvePresetCategory.EXPONENTIAL
	},
	CurvePreset.EASE_IN_OUT_EXPO: {
		"name": "Ease In Out Expo",
		"description": "Exponential ease in and out",
		"category": CurvePresetCategory.EXPONENTIAL
	},
	CurvePreset.EASE_IN_SINE: {
		"name": "Ease In Sine",
		"description": "Sine wave ease in",
		"category": CurvePresetCategory.SINE
	},
	CurvePreset.EASE_OUT_SINE: {
		"name": "Ease Out Sine",
		"description": "Sine wave ease out",
		"category": CurvePresetCategory.SINE
	},
	CurvePreset.EASE_IN_OUT_SINE: {
		"name": "Ease In Out Sine",
		"description": "Sine wave ease in and out",
		"category": CurvePresetCategory.SINE
	},
	CurvePreset.EASE_IN_QUAD: {
		"name": "Ease In Quad",
		"description": "Quadratic ease in (t²)",
		"category": CurvePresetCategory.QUADRATIC
	},
	CurvePreset.EASE_OUT_QUAD: {
		"name": "Ease Out Quad",
		"description": "Quadratic ease out",
		"category": CurvePresetCategory.QUADRATIC
	},
	CurvePreset.EASE_IN_OUT_QUAD: {
		"name": "Ease In Out Quad",
		"description": "Quadratic ease in and out",
		"category": CurvePresetCategory.QUADRATIC
	},
	CurvePreset.EASE_IN_CUBIC: {
		"name": "Ease In Cubic",
		"description": "Cubic ease in (t³)",
		"category": CurvePresetCategory.CUBIC
	},
	CurvePreset.EASE_OUT_CUBIC: {
		"name": "Ease Out Cubic",
		"description": "Cubic ease out",
		"category": CurvePresetCategory.CUBIC
	},
	CurvePreset.EASE_IN_OUT_CUBIC: {
		"name": "Ease In Out Cubic",
		"description": "Cubic ease in and out",
		"category": CurvePresetCategory.CUBIC
	}
}

# ============================================================================
# 核心API
# ============================================================================

## 创建预设曲线
static func create_curve(preset: CurvePreset) -> Curve:
	"""创建指定预设的曲线实例（带缓存）

	Args:
		preset: 曲线预设枚举值

	Returns:
		Curve实例，如果失败则返回Linear曲线
	"""
	# 验证预设值
	if preset < 0 or preset > 24:
		push_error("Invalid curve preset: %d" % preset)
		return create_curve(CurvePreset.LINEAR)

	# 检查缓存
	if _curve_cache.has(preset):
		_cache_hits += 1
		return _curve_cache[preset].duplicate()

	# 缓存未命中
	_cache_misses += 1
	var curve = _create_curve_for_preset(preset)

	if not curve:
		push_error("Failed to create curve for preset: %d" % preset)
		return create_curve(CurvePreset.LINEAR)

	# 存入缓存并返回副本
	_curve_cache[preset] = curve
	return curve.duplicate()


## 应用预设到现有曲线
static func apply_preset(target_curve: Curve, preset: CurvePreset) -> bool:
	"""将预设的形状应用到现有曲线

	Args:
		target_curve: 目标曲线实例
		preset: 曲线预设枚举值

	Returns:
		成功返回true，失败返回false
	"""
	if not target_curve:
		push_error("Target curve is null")
		return false

	if preset < 0 or preset > 24:
		push_error("Invalid curve preset: %d" % preset)
		return false

	# 创建预设曲线
	var preset_curve = create_curve(preset)
	if not preset_curve:
		return false

	# 清除目标曲线的所有点
	target_curve.clear_points()

	# 复制预设曲线的所有点
	var point_count = preset_curve.get_point_count()
	for i in range(point_count):
		var pos = preset_curve.get_point_position(i)
		var left_tangent = preset_curve.get_point_left_tangent(i)
		var right_tangent = preset_curve.get_point_right_tangent(i)
		var left_mode = preset_curve.get_point_left_mode(i)
		var right_mode = preset_curve.get_point_right_mode(i)

		target_curve.add_point(pos, left_tangent, right_tangent, left_mode, right_mode)

	target_curve.bake()
	target_curve.notify_property_list_changed()
	target_curve.emit_changed()

	# 强制刷新 Inspector 缩略图：临时修改并恢复 bake_resolution
	var original_resolution = target_curve.bake_resolution
	target_curve.bake_resolution = original_resolution + 1
	target_curve.bake_resolution = original_resolution

	return true


## 获取预设名称
static func get_preset_name(preset: CurvePreset) -> String:
	"""获取预设的显示名称"""
	if _preset_metadata.has(preset):
		return _preset_metadata[preset]["name"]
	return "Unknown"


## 获取预设描述
static func get_preset_description(preset: CurvePreset) -> String:
	"""获取预设的描述文本"""
	if _preset_metadata.has(preset):
		return _preset_metadata[preset]["description"]
	return ""


## 获取预设分类
static func get_preset_category(preset: CurvePreset) -> CurvePresetCategory:
	"""获取预设所属的分类"""
	if _preset_metadata.has(preset):
		return _preset_metadata[preset]["category"]
	return CurvePresetCategory.BASIC


## 获取指定分类的所有预设
static func get_presets_in_category(category: CurvePresetCategory) -> Array[CurvePreset]:
	"""获取指定分类的所有预设列表"""
	match category:
		CurvePresetCategory.BASIC:
			return [
				CurvePreset.LINEAR, CurvePreset.EASE_IN,
				CurvePreset.EASE_OUT, CurvePreset.EASE_IN_OUT
			]
		CurvePresetCategory.BACK:
			return [
				CurvePreset.EASE_IN_BACK, CurvePreset.EASE_OUT_BACK,
				CurvePreset.EASE_IN_OUT_BACK
			]
		CurvePresetCategory.ELASTIC:
			return [
				CurvePreset.EASE_IN_ELASTIC, CurvePreset.EASE_OUT_ELASTIC,
				CurvePreset.EASE_IN_OUT_ELASTIC
			]
		CurvePresetCategory.BOUNCE:
			return [
				CurvePreset.BOUNCE_IN, CurvePreset.BOUNCE_OUT,
				CurvePreset.BOUNCE_IN_OUT
			]
		CurvePresetCategory.EXPONENTIAL:
			return [
				CurvePreset.EASE_IN_EXPO, CurvePreset.EASE_OUT_EXPO,
				CurvePreset.EASE_IN_OUT_EXPO
			]
		CurvePresetCategory.SINE:
			return [
				CurvePreset.EASE_IN_SINE, CurvePreset.EASE_OUT_SINE,
				CurvePreset.EASE_IN_OUT_SINE
			]
		CurvePresetCategory.QUADRATIC:
			return [
				CurvePreset.EASE_IN_QUAD, CurvePreset.EASE_OUT_QUAD,
				CurvePreset.EASE_IN_OUT_QUAD
			]
		CurvePresetCategory.CUBIC:
			return [
				CurvePreset.EASE_IN_CUBIC, CurvePreset.EASE_OUT_CUBIC,
				CurvePreset.EASE_IN_OUT_CUBIC
			]
		_:
			return []


## 验证预设是否有效
static func is_valid_preset(preset: int) -> bool:
	"""检查预设值是否在有效范围内"""
	return preset >= 0 and preset <= 24


## 清除缓存
static func clear_cache():
	"""清除所有缓存的曲线"""
	_curve_cache.clear()
	_cache_hits = 0
	_cache_misses = 0


## 获取缓存大小
static func get_cache_size() -> int:
	"""获取当前缓存的曲线数量"""
	return _curve_cache.size()


## 获取缓存统计
static func get_cache_stats() -> Dictionary:
	"""获取缓存命中/未命中统计"""
	return {
		"hits": _cache_hits,
		"misses": _cache_misses,
		"size": _curve_cache.size()
	}

# ============================================================================
# 内部实现 - 曲线创建函数
# ============================================================================

## 计算数值导数（用于复杂预设的 tangent 计算）
static func _calculate_derivative(func_ref: Callable, t: float, delta: float = 0.001) -> float:
	"""使用中心差分法计算数值导数
	Args:
		func_ref: 函数引用，接受 t 参数并返回 float
		t: 计算导数的点
		delta: 差分步长，越小越精确
	Returns:
		数值导数 f'(t)
	"""
	var f_plus = func_ref.call(t + delta)
	var f_minus = func_ref.call(t - delta)
	return (f_plus - f_minus) / (2.0 * delta)


## 添加带有自动计算切线的点
static func _add_point_with_tangent(curve: Curve, t: float, value_func: Callable, delta: float = 0.001):
	"""添加点到曲线并自动计算切线
	Args:
		curve: 曲线对象
		t: 时间位置 (0-1)
		value_func: 函数引用，接受 t 参数并返回值
		delta: 数值导数的差分步长
	"""
	var value = value_func.call(t)
	var tangent = _calculate_derivative(value_func, t, delta)
	curve.add_point(Vector2(t, value), 0, tangent)


## 根据预设创建曲线（内部方法）
static func _create_curve_for_preset(preset: CurvePreset) -> Curve:
	"""根据预设枚举创建对应的曲线（内部方法）"""
	var curve = Curve.new()

	match preset:
		# Basic presets (0-3)
		CurvePreset.LINEAR:
			_create_linear(curve)
		CurvePreset.EASE_IN:
			_create_ease_in(curve)
		CurvePreset.EASE_OUT:
			_create_ease_out(curve)
		CurvePreset.EASE_IN_OUT:
			_create_ease_in_out(curve)

		# Back presets (4-6)
		CurvePreset.EASE_IN_BACK:
			_create_ease_in_back(curve)
		CurvePreset.EASE_OUT_BACK:
			_create_ease_out_back(curve)
		CurvePreset.EASE_IN_OUT_BACK:
			_create_ease_in_out_back(curve)

		# Elastic presets (7-9)
		CurvePreset.EASE_IN_ELASTIC:
			_create_ease_in_elastic(curve)
		CurvePreset.EASE_OUT_ELASTIC:
			_create_ease_out_elastic(curve)
		CurvePreset.EASE_IN_OUT_ELASTIC:
			_create_ease_in_out_elastic(curve)

		# Bounce presets (10-12)
		CurvePreset.BOUNCE_IN:
			_create_bounce_in(curve)
		CurvePreset.BOUNCE_OUT:
			_create_bounce_out(curve)
		CurvePreset.BOUNCE_IN_OUT:
			_create_bounce_in_out(curve)

		# Exponential presets (13-15)
		CurvePreset.EASE_IN_EXPO:
			_create_ease_in_expo(curve)
		CurvePreset.EASE_OUT_EXPO:
			_create_ease_out_expo(curve)
		CurvePreset.EASE_IN_OUT_EXPO:
			_create_ease_in_out_expo(curve)

		# Sine presets (16-18)
		CurvePreset.EASE_IN_SINE:
			_create_ease_in_sine(curve)
		CurvePreset.EASE_OUT_SINE:
			_create_ease_out_sine(curve)
		CurvePreset.EASE_IN_OUT_SINE:
			_create_ease_in_out_sine(curve)

		# Quadratic presets (19-21)
		CurvePreset.EASE_IN_QUAD:
			_create_ease_in_quad(curve)
		CurvePreset.EASE_OUT_QUAD:
			_create_ease_out_quad(curve)
		CurvePreset.EASE_IN_OUT_QUAD:
			_create_ease_in_out_quad(curve)

		# Cubic presets (22-24)
		CurvePreset.EASE_IN_CUBIC:
			_create_ease_in_cubic(curve)
		CurvePreset.EASE_OUT_CUBIC:
			_create_ease_out_cubic(curve)
		CurvePreset.EASE_IN_OUT_CUBIC:
			_create_ease_in_out_cubic(curve)

		_:
			_create_linear(curve)

	return curve


# ============================================================================
# Basic Presets (0-3)
# ============================================================================

## Linear: f(t) = t
static func _create_linear(curve: Curve):
	curve.add_point(Vector2(0, 0), 0, 0, Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR)
	curve.add_point(Vector2(1, 1), 1, 1, Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR)


## Ease In: f(t) = t², f'(t) = 2t
static func _create_ease_in(curve: Curve):
	# 起点: f(0)=0, f'(0)=0
	# 终点: f(1)=1, f'(1)=2
	curve.add_point(Vector2(0, 0), 0, 0)
	curve.add_point(Vector2(1, 1), 2, 0)
	curve.bake()


## Ease Out: f(t) = 1-(1-t)², f'(t) = 2(1-t)
static func _create_ease_out(curve: Curve):
	# 起点: f(0)=0, f'(0)=2
	# 终点: f(1)=1, f'(1)=0
	curve.add_point(Vector2(0, 0), 0, 2)
	curve.add_point(Vector2(1, 1), 0, 0)
	curve.bake()


## Ease In Out: f(t) = 2t² (t<0.5), 1-2(1-t)² (t≥0.5)
## f'(t) = 4t (t<0.5), 4(1-t) (t≥0.5)
static func _create_ease_in_out(curve: Curve):
	# 起点: f(0)=0, f'(0)=0
	# 中点: f(0.5)=0.5, f'(0.5)=2
	# 终点: f(1)=1, f'(1)=0
	curve.add_point(Vector2(0, 0), 0, 0)
	curve.add_point(Vector2(0.5, 0.5), 2, 2)
	curve.add_point(Vector2(1, 1), 0, 0)
	curve.bake()


# ============================================================================
# Back Presets (4-6)
# ============================================================================

## Ease In Back: f(t) = t²((c+1)t-c), c=1.70158
## f'(t) = 3(c+1)t² - 2ct
static func _create_ease_in_back(curve: Curve):
	var c: float = 1.70158
	# 起点: f(0)=0, f'(0)=0
	# 终点: f(1)=1, f'(1)=3(c+1)-2c = c+3 ≈ 4.70
	var end_tangent = 3.0 * (c + 1.0) - 2.0 * c
	curve.add_point(Vector2(0, 0), 0, 0)
	curve.add_point(Vector2(1, 1), end_tangent, 0)
	curve.bake()


## Ease Out Back: f(t) = 1-(1-t)²((c+1)(1-t)+c), c=1.70158
## 通过对称性：f'(t) 与 Ease In Back 相反
static func _create_ease_out_back(curve: Curve):
	var c: float = 1.70158
	# 起点: f(0)=0, f'(0)=c+3 ≈ 4.70
	# 终点: f(1)=1, f'(1)=0
	var start_tangent = 3.0 * (c + 1.0) - 2.0 * c
	curve.add_point(Vector2(0, 0), 0, start_tangent)
	curve.add_point(Vector2(1, 1), 0, 0)
	curve.bake()


## Ease In Out Back: 分段 Back 函数
## 每半段都是缩放的 Back 函数
static func _create_ease_in_out_back(curve: Curve):
	var c: float = 1.70158 * 1.525
	# 起点: f(0)=0, f'(0)=0
	# 中点: f(0.5)=0.5, f'(0.5) 需要缩放计算
	# 终点: f(1)=1, f'(1)=0
	#
	# 对于 t<0.5 的半段：缩放因子为 0.5
	# t2 = 2t, f(t) = 0.5 * f_in(t2)
	# f'(t) = f_in'(t2)
	# 在 t=0.5: t2=1, f'(0.5) = f_in'(1) = 3(c+1)-2c
	var mid_tangent = 3.0 * (c + 1.0) - 2.0 * c
	curve.add_point(Vector2(0, 0), 0, 0)
	curve.add_point(Vector2(0.5, 0.5), mid_tangent, mid_tangent)
	curve.add_point(Vector2(1, 1), 0, 0)
	curve.bake()


# ============================================================================
# Elastic Presets (7-9)
# ============================================================================

## Ease In Elastic
static func _create_ease_in_elastic(curve: Curve):
	var amplitude: float = 1.0
	var period: float = 0.3

	# 定义函数
	var elastic_in_func = func(t: float) -> float:
		if t == 0: return 0.0
		if t == 1: return 1.0
		var s = period / 4.0
		var t_adj = t - 1.0
		return -amplitude * pow(2.0, 10.0 * t_adj) * sin((t_adj - s) * (2.0 * PI) / period)

	# 使用较少的点（31个），每个点都计算切线
	for i in range(31):
		var t = float(i) / 30.0
		_add_point_with_tangent(curve, t, elastic_in_func)
	curve.bake()


## Ease Out Elastic
static func _create_ease_out_elastic(curve: Curve):
	var amplitude: float = 1.0
	var period: float = 0.3

	# 定义函数
	var elastic_out_func = func(t: float) -> float:
		if t == 0: return 0.0
		if t == 1: return 1.0
		var s = period / 4.0
		return amplitude * pow(2.0, -10.0 * t) * sin((t - s) * (2.0 * PI) / period) + 1.0

	# 使用较少的点（31个），每个点都计算切线
	for i in range(31):
		var t = float(i) / 30.0
		_add_point_with_tangent(curve, t, elastic_out_func)
	curve.bake()


## Ease In Out Elastic
static func _create_ease_in_out_elastic(curve: Curve):
	var amplitude: float = 1.0
	var period: float = 0.5

	# 定义函数
	var elastic_inout_func = func(t: float) -> float:
		if t == 0: return 0.0
		if t == 1: return 1.0
		var s = period / 4.0
		if t < 0.5:
			var t_adj = t * 2.0 - 1.0
			return -0.5 * amplitude * pow(2.0, 10.0 * t_adj) * sin((t_adj - s) * (2.0 * PI) / period)
		else:
			var t_adj = t * 2.0 - 1.0
			return 0.5 * amplitude * pow(2.0, -10.0 * t_adj) * sin((t_adj - s) * (2.0 * PI) / period) + 1.0

	# 使用较少的点（31个），每个点都计算切线
	for i in range(31):
		var t = float(i) / 30.0
		_add_point_with_tangent(curve, t, elastic_inout_func)
	curve.bake()


# ============================================================================
# Bounce Presets (10-12)
# ============================================================================

## Bounce Out
static func _create_bounce_out(curve: Curve):
	# 定义函数
	var bounce_out_func = func(t: float) -> float:
		var value: float
		if t < 1.0 / 2.75:
			value = 7.5625 * t * t
		elif t < 2.0 / 2.75:
			var t2 = t - 1.5 / 2.75
			value = 7.5625 * t2 * t2 + 0.75
		elif t < 2.5 / 2.75:
			var t2 = t - 2.25 / 2.75
			value = 7.5625 * t2 * t2 + 0.9375
		else:
			var t2 = t - 2.625 / 2.75
			value = 7.5625 * t2 * t2 + 0.984375
		return clamp(value, 0.0, 1.2)

	# 使用较少的点（41个），每个点都计算切线
	for i in range(41):
		var t = float(i) / 40.0
		_add_point_with_tangent(curve, t, bounce_out_func)
	curve.bake()


## Bounce In (反向Bounce Out)
static func _create_bounce_in(curve: Curve):
	# 定义函数
	var bounce_in_func = func(t: float) -> float:
		# Bounce In = 1 - BounceOut(1-t)
		var t_rev = 1.0 - t
		var value: float
		if t_rev < 1.0 / 2.75:
			value = 7.5625 * t_rev * t_rev
		elif t_rev < 2.0 / 2.75:
			var t2 = t_rev - 1.5 / 2.75
			value = 7.5625 * t2 * t2 + 0.75
		elif t_rev < 2.5 / 2.75:
			var t2 = t_rev - 2.25 / 2.75
			value = 7.5625 * t2 * t2 + 0.9375
		else:
			var t2 = t_rev - 2.625 / 2.75
			value = 7.5625 * t2 * t2 + 0.984375
		return clamp(1.0 - clamp(value, 0.0, 1.2), 0.0, 1.0)

	# 使用较少的点（41个），每个点都计算切线
	for i in range(41):
		var t = float(i) / 40.0
		_add_point_with_tangent(curve, t, bounce_in_func)
	curve.bake()


## Bounce In Out
static func _create_bounce_in_out(curve: Curve):
	# 定义函数
	var bounce_inout_func = func(t: float) -> float:
		var value: float
		if t < 0.5:
			# 前半段：使用 Bounce In
			var t_rev = 1.0 - t * 2.0
			var bounce_val: float
			if t_rev < 1.0 / 2.75:
				bounce_val = 7.5625 * t_rev * t_rev
			elif t_rev < 2.0 / 2.75:
				var t2 = t_rev - 1.5 / 2.75
				bounce_val = 7.5625 * t2 * t2 + 0.75
			elif t_rev < 2.5 / 2.75:
				var t2 = t_rev - 2.25 / 2.75
				bounce_val = 7.5625 * t2 * t2 + 0.9375
			else:
				var t2 = t_rev - 2.625 / 2.75
				bounce_val = 7.5625 * t2 * t2 + 0.984375
			value = (1.0 - clamp(bounce_val, 0.0, 1.2)) * 0.5
		else:
			# 后半段：使用 Bounce Out
			var t_fwd = t * 2.0 - 1.0
			var bounce_val: float
			if t_fwd < 1.0 / 2.75:
				bounce_val = 7.5625 * t_fwd * t_fwd
			elif t_fwd < 2.0 / 2.75:
				var t2 = t_fwd - 1.5 / 2.75
				bounce_val = 7.5625 * t2 * t2 + 0.75
			elif t_fwd < 2.5 / 2.75:
				var t2 = t_fwd - 2.25 / 2.75
				bounce_val = 7.5625 * t2 * t2 + 0.9375
			else:
				var t2 = t_fwd - 2.625 / 2.75
				bounce_val = 7.5625 * t2 * t2 + 0.984375
			value = clamp(bounce_val, 0.0, 1.2) * 0.5 + 0.5
		return clamp(value, 0.0, 1.2)

	# 使用较少的点（41个），每个点都计算切线
	for i in range(41):
		var t = float(i) / 40.0
		_add_point_with_tangent(curve, t, bounce_inout_func)
	curve.bake()


# ============================================================================
# Exponential Presets (13-15)
# ============================================================================

## Ease In Expo: f(t) = 2^(10t-10), f'(t) = 10·log(2)·2^(10t-10)
static func _create_ease_in_expo(curve: Curve):
	# 起点: f(0)=0, f'(0)≈0 (几乎为0)
	# 终点: f(1)=1, f'(1)=10·log(2) ≈ 6.93
	var log2 = log(2.0)
	var end_tangent = 10.0 * log2
	curve.add_point(Vector2(0, 0), 0, 0)
	curve.add_point(Vector2(1, 1), end_tangent, 0)
	curve.bake()


## Ease Out Expo: f(t) = 1-2^(-10t), f'(t) = 10·log(2)·2^(-10t)
static func _create_ease_out_expo(curve: Curve):
	# 起点: f(0)=0, f'(0)=10·log(2) ≈ 6.93
	# 终点: f(1)=1, f'(1)≈0 (几乎为0)
	var log2 = log(2.0)
	var start_tangent = 10.0 * log2
	curve.add_point(Vector2(0, 0), 0, start_tangent)
	curve.add_point(Vector2(1, 1), 0, 0)
	curve.bake()


## Ease In Out Expo: 分段指数函数
## t<0.5: f(t) = 2^(20t-10)/2, f'(t) = 10·log(2)·2^(20t-10)
## t≥0.5: f(t) = 1-2^(-20t+10)/2, f'(t) = 10·log(2)·2^(-20t+10)
static func _create_ease_in_out_expo(curve: Curve):
	# 起点: f(0)=0, f'(0)≈0
	# 中点: f(0.5)=0.5, f'(0.5)=10·log(2) ≈ 6.93
	# 终点: f(1)=1, f'(1)≈0
	var log2 = log(2.0)
	var mid_tangent = 10.0 * log2
	curve.add_point(Vector2(0, 0), 0, 0)
	curve.add_point(Vector2(0.5, 0.5), mid_tangent, mid_tangent)
	curve.add_point(Vector2(1, 1), 0, 0)
	curve.bake()


# ============================================================================
# Sine Presets (16-18)
# ============================================================================

## Ease In Sine: f(t) = -cos(t·π/2) + 1, f'(t) = sin(t·π/2) · (π/2)
static func _create_ease_in_sine(curve: Curve):
	# 起点: f(0)=0, f'(0)=0
	# 终点: f(1)=1, f'(1)=π/2 ≈ 1.57
	var pi_half = PI / 2.0
	curve.add_point(Vector2(0, 0), 0, 0)
	curve.add_point(Vector2(1, 1), pi_half, 0)
	curve.bake()


## Ease Out Sine: f(t) = sin(t·π/2), f'(t) = cos(t·π/2) · (π/2)
static func _create_ease_out_sine(curve: Curve):
	# 起点: f(0)=0, f'(0)=π/2 ≈ 1.57
	# 终点: f(1)=1, f'(1)=0
	var pi_half = PI / 2.0
	curve.add_point(Vector2(0, 0), 0, pi_half)
	curve.add_point(Vector2(1, 1), 0, 0)
	curve.bake()


## Ease In Out Sine: f(t) = -0.5·(cos(π·t) - 1), f'(t) = 0.5·π·sin(π·t)
static func _create_ease_in_out_sine(curve: Curve):
	# 起点: f(0)=0, f'(0)=0
	# 中点: f(0.5)=0.5, f'(0.5)=π/2 ≈ 1.57
	# 终点: f(1)=1, f'(1)=0
	var pi_half = PI / 2.0
	curve.add_point(Vector2(0, 0), 0, 0)
	curve.add_point(Vector2(0.5, 0.5), pi_half, pi_half)
	curve.add_point(Vector2(1, 1), 0, 0)
	curve.bake()


# ============================================================================
# Quadratic Presets (19-21)
# ============================================================================

## Ease In Quad: f(t) = t² (same as Ease In)
static func _create_ease_in_quad(curve: Curve):
	_create_ease_in(curve)


## Ease Out Quad: f(t) = -t² + 2t, f'(t) = 2 - 2t
static func _create_ease_out_quad(curve: Curve):
	# 起点: f(0)=0, f'(0)=2
	# 终点: f(1)=1, f'(1)=0
	curve.add_point(Vector2(0, 0), 0, 2)
	curve.add_point(Vector2(1, 1), 0, 0)
	curve.bake()


## Ease In Out Quad (same as Ease In Out)
static func _create_ease_in_out_quad(curve: Curve):
	_create_ease_in_out(curve)


# ============================================================================
# Cubic Presets (22-24)
# ============================================================================

## Ease In Cubic: f(t) = t³, f'(t) = 3t²
static func _create_ease_in_cubic(curve: Curve):
	# 起点: f(0)=0, f'(0)=0
	# 终点: f(1)=1, f'(1)=3
	curve.add_point(Vector2(0, 0), 0, 0)
	curve.add_point(Vector2(1, 1), 3, 0)
	curve.bake()


## Ease Out Cubic: f(t) = 1-(1-t)³, f'(t) = 3(1-t)²
static func _create_ease_out_cubic(curve: Curve):
	# 起点: f(0)=0, f'(0)=3
	# 终点: f(1)=1, f'(1)=0
	curve.add_point(Vector2(0, 0), 0, 3)
	curve.add_point(Vector2(1, 1), 0, 0)
	curve.bake()


## Ease In Out Cubic: f(t) = 4t³ (t<0.5), 1-4(1-t)³ (t≥0.5)
## f'(t) = 12t² (t<0.5), 12(1-t)² (t≥0.5)
static func _create_ease_in_out_cubic(curve: Curve):
	# 起点: f(0)=0, f'(0)=0
	# 中点: f(0.5)=0.5, f'(0.5)=3
	# 终点: f(1)=1, f'(1)=0
	curve.add_point(Vector2(0, 0), 0, 0)
	curve.add_point(Vector2(0.5, 0.5), 3, 3)
	curve.add_point(Vector2(1, 1), 0, 0)
	curve.bake()
