# JuicyPropertyTrack - 属性轨道
# 控制节点属性变化，支持曲线和关键帧两种模式
# 实现参数映射系统，包含时间变换和缓动函数

@tool
class_name JuicyPropertyTrack
extends JuicyTrack

# Phase 3C: 预加载 Curve Factory
const JuicyCurveFactory = preload("res://addons/juicy_mixer/utils/juicy_curve_factory.gd")

## 编辑模式枚举
enum EditMode {
	CURVE_BASED,      # 基于曲线（默认，简单）
	KEYFRAME_BASED    # 基于关键帧（高级，精细）
}

# 混合模式枚举
enum BlendMode {
	OVERRIDE_BASE,    # 覆盖基础值
	ADDITIVE,         # 叠加偏移量
	MULTIPLICATIVE    # 乘法混合
}

# 属性路径 setter
var property_path: String = "":
	set(value):
		var old_path = property_path
		property_path = value

		# 更新属性类型信息
		_update_property_type_info()

		# 🔥 自动调整值域以匹配新属性类型
		_auto_adjust_value_range_for_property_type()

		notify_property_list_changed()

		# 如果属性路径改变了，更新所有已存在keyframe的value类型
		if old_path != value and not keyframes.is_empty():
			print("JuicyPropertyTrack: property_path从 '", old_path, "' 改变为 '", value, "'，更新", keyframes.size(), " 个keyframe的value类型")
			_update_keyframes_value_type()
	get:
		return property_path

## 🔥 主要编辑模式
var _edit_mode_value: EditMode = EditMode.CURVE_BASED  # 实际存储的值

var edit_mode: EditMode = EditMode.CURVE_BASED:
	set(value):
		var old_value = _edit_mode_value
		_edit_mode_value = value
		if old_value != value:
			notify_property_list_changed()
	get:
		return _edit_mode_value

## 🔥 时间范围（明确 curve 的时间映射）- 拆分为 start 和 end
var time_start: float = 0.0:  # 曲线起始时间（秒）
	set(value):
		time_start = value
	get:
		return time_start

var time_end: float = 1.0:    # 曲线结束时间（秒）
	set(value):
		time_end = value
	get:
		return time_end

## 向后兼容：保留旧的 time_range 属性
@export_storage var _legacy_time_range: Vector2 = Vector2(0.0, 1.0)

## 🔥 值域最小值（Variant 类型，根据属性类型自动调整）
var value_min: Variant = 0.0:
	set(value):
		value_min = value
		_notify_value_range_changed()
	get:
		return value_min

## 🔥 值域最大值（Variant 类型，根据属性类型自动调整）
var value_max: Variant = 1.0:
	set(value):
		value_max = value
		_notify_value_range_changed()
	get:
		return value_max

## 向后兼容：保留旧的 value_range 属性
@export_storage var _legacy_value_range: Vector2 = Vector2(0.0, 1.0)

var animation_curve: Curve                 # 值变化曲线 (0-1)

var value_range: Vector2 = Vector2(0.0, 1.0):  # 映射范围 (Min, Max) - 已废弃，保留用于向后兼容
	set(value):
		# 向后兼容：当设置旧属性时，同时设置新属性
		_legacy_value_range = value
		if _current_property_type in [TYPE_INT, TYPE_FLOAT]:
			value_min = value.x
			value_max = value.y
	get:
		# 返回旧值（用于兼容）
		return _legacy_value_range

@export var relative: bool = true                  # 是否是相对值(Additive)
@export var blend_mode: BlendMode = BlendMode.OVERRIDE_BASE  # 混合模式
var keyframes: Array[Resource] = []  # 关键帧数据

## 🔥 Phase 2: Bake 元数据
var keyframes_baked_from_curve: bool = false  # 标记关键帧是否从曲线 bake 而来
var _bake_keyframe_count: int = 0  # 记录 bake 时的关键帧数量（用于恢复）

# 内部变量：用于记录当前选择的属性类型
var _current_keyframe_value_type: int = TYPE_FLOAT  # 默认使用float类型

## 🔥 内部变量：缓存的属性类型
var _cached_property_type: int = -1  # 使用 -1 而不是 TYPE_NIL，确保初始化时会执行一次

# 高级属性
@export var use_absolute_time: bool = false        # 使用绝对时间而非相对时间
@export var time_offset: float = 0.0              # 时间偏移
@export var time_scale: float = 1.0               # 时间缩放
@export var wrap_mode: int = 0                    # 循环模式 (0: Clamp, 1: Loop, 2: PingPong)

# 参数映射系统 - 轨道级别的参数绑定
@export var use_parameter_mapping: bool = false    # 参数映射开关，默认关闭
@export var parameter_mappings: Array[JuicyParameterMapping] = []

# ============================================================================
# Phase 3C: Curve Preset System (替换 ease_preset)
# ============================================================================

## 临时存储用户选择的预设（Inspector UI 使用，不触发应用）
var _pending_curve_preset: int = -1  # -1 表示没有待应用的预设

## 调试采样计数器
var _debug_sample_count: int = 0  # 用于限制调试输出次数

## Curve Preset (25种预设，0-24)
@export_category("Curve Presets")
@export var curve_preset: int = 0:
	set(value):
		# 验证范围
		var valid_value = clamp(value, 0, 24)

		# 检查是否需要应用
		var should_apply = (curve_preset != valid_value) or (_pending_curve_preset == -2)

		if should_apply:
			curve_preset = valid_value
			# 只在需要时应用曲线
			# - _pending_curve_preset == -2：强制应用（右键菜单）
			# - _pending_curve_preset == -1：正常应用
			# - _pending_curve_preset >= 0：不自动应用（Inspector 选择中）
			if _pending_curve_preset < 0:
				_apply_curve_preset_smart(valid_value)
			notify_property_list_changed()
	get:
		return curve_preset

## 向后兼容：保留 ease_preset 作为存储别名
@export_storage var _legacy_ease_preset: int = 0:
	get:
		# 映射新值到旧值（0-3）
		if curve_preset <= 3:
			return curve_preset
		return 0  # 新预设返回0（None）
	set(value):
		# 从旧值迁移到新值
		if value >= 0 and value <= 3:
			curve_preset = value

# 内部变量 - 用于属性类型检测
var _target_node_instance: Node = null
var _current_property_info: Dictionary = {}
var _current_property_type: int = TYPE_NIL
var _current_property_hint: int = PROPERTY_HINT_NONE
var _current_property_hint_string: String = ""

# ============================================================================
# 状态管理（支持 relative 和 blend_mode）
# ============================================================================

## 轨道状态（每个 context 一个状态）
## Dictionary: context_id -> { base_value, previous_value, loop_base, loop_count }
var _track_states: Dictionary = {}

func get_track_type() -> String:
	return "Property"

## 初始化轨道状态
func initialize_track(context: JuicyContext) -> void:
	"""
	初始化轨道状态

	@param context: JuicyContext 实例
	"""
	if not context:
		return

	var context_id = context.context_id

	# 初始化状态
	if not _track_states.has(context_id):
		_track_states[context_id] = {
			"base_value": null,        # 起始值
			"previous_value": null,    # 上一帧的值
			"loop_base": null,         # 当前循环的起始值
			"loop_count": 0,           # 循环计数
			"initialized": false       # 是否已初始化
		}

## 清理轨道状态
func cleanup_track(context: JuicyContext) -> void:
	"""
	清理轨道状态

	@param context: JuicyContext 实例
	"""
	if not context:
		return

	var context_id = context.context_id
	_track_states.erase(context_id)

## 重置循环状态（Timeline 循环时调用）
func reset_loop_state(context: JuicyContext) -> void:
	"""
	重置循环状态

	当 Timeline 循环时，更新 loop_base 为上一循环结束值，
	支持 relative 模式（每次循环从当前位置继续）

	@param context: JuicyContext 实例
	"""
	if not context:
		return

	var context_id = context.context_id

	if _track_states.has(context_id):
		var state = _track_states[context_id]

		# 🔥 更新 loop_base 为上一帧的值（循环结束时的值）
		if state.previous_value != null:
			state.loop_base = state.previous_value

		state.loop_count += 1

## 编辑器属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []

	# 添加目标节点路径（使用基类的 target）
	properties.append({
		"name": "target",
		"type": TYPE_NODE_PATH,
		"hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES,
		"hint_string": "Node",
		"default": NodePath(""),
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
	})

	# 添加属性路径选择器（使用枚举提示）
	var enum_string = _get_property_enum_string()
	properties.append({
		"name": "property_path",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM if not enum_string.is_empty() else PROPERTY_HINT_NONE,
		"hint_string": enum_string if not enum_string.is_empty() else "",
		"default": "",
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
	})

	# 🔥 添加编辑模式选择器
	properties.append({
		"name": "edit_mode",
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Curve Based,Keyframe Based",
		"default": EditMode.CURVE_BASED,
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
	})

	# 🔥 Phase 3B: 添加分隔符
	properties.append({
		"name": "time_range_section",
		"type": TYPE_NIL,
		"hint": PROPERTY_HINT_NONE,
		"usage": PROPERTY_USAGE_GROUP | PROPERTY_USAGE_EDITOR,
		"hint_string": "时间范围"
	})

	# 🔥 添加时间范围属性（拆分为 start 和 end）
	properties.append({
		"name": "time_start",
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0,100,0.01,or_greater",
		"default": 0.0,
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
	})

	properties.append({
		"name": "time_end",
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0,100,0.01,or_greater",
		"default": 1.0,
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
	})

	# 🔥 Phase 3B: 添加值域分隔符
	properties.append({
		"name": "value_range_section",
		"type": TYPE_NIL,
		"hint": PROPERTY_HINT_NONE,
		"usage": PROPERTY_USAGE_GROUP | PROPERTY_USAGE_EDITOR,
		"hint_string": "值域设置"
	})

	# 🔥 动态添加值域属性（根据属性类型显示不同的编辑器）
	# 参考 set_property_value.gd 的实现（line 175-182）
	match _current_property_type:
		TYPE_INT:
			# 整数类型：显示数值输入框
			properties.append({
				"name": "value_min",
				"type": TYPE_INT,
				"hint": PROPERTY_HINT_NONE,
				"default": 0,
				"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
			})
			properties.append({
				"name": "value_max",
				"type": TYPE_INT,
				"hint": PROPERTY_HINT_NONE,
				"default": 100,
				"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
			})

		TYPE_FLOAT:
			# 浮点类型：显示数值输入框
			properties.append({
				"name": "value_min",
				"type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE,
				"hint_string": "-10000,10000,0.001,or_less,or_greater",
				"default": 0.0,
				"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
			})
			properties.append({
				"name": "value_max",
				"type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE,
				"hint_string": "-10000,10000,0.001,or_less,or_greater",
				"default": 1.0,
				"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
			})

		TYPE_VECTOR2:
			# Vector2 类型：显示向量编辑器
			properties.append({
				"name": "value_min",
				"type": TYPE_VECTOR2,
				"hint": PROPERTY_HINT_NONE,
				"default": Vector2(0.0, 0.0),
				"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
			})
			properties.append({
				"name": "value_max",
				"type": TYPE_VECTOR2,
				"hint": PROPERTY_HINT_NONE,
				"default": Vector2(1.0, 1.0),
				"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
			})

		TYPE_VECTOR3:
			# Vector3 类型：显示向量编辑器
			properties.append({
				"name": "value_min",
				"type": TYPE_VECTOR3,
				"hint": PROPERTY_HINT_NONE,
				"default": Vector3(0.0, 0.0, 0.0),
				"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
			})
			properties.append({
				"name": "value_max",
				"type": TYPE_VECTOR3,
				"hint": PROPERTY_HINT_NONE,
				"default": Vector3(1.0, 1.0, 1.0),
				"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
			})

		TYPE_COLOR:
			# Color 类型：显示颜色选择器
			properties.append({
				"name": "value_min",
				"type": TYPE_COLOR,
				"hint": PROPERTY_HINT_COLOR_NO_ALPHA,
				"default": Color(0.0, 0.0, 0.0, 1.0),
				"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
			})
			properties.append({
				"name": "value_max",
				"type": TYPE_COLOR,
				"hint": PROPERTY_HINT_COLOR_NO_ALPHA,
				"default": Color(1.0, 1.0, 1.0, 1.0),
				"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
			})

		TYPE_BOOL:
			# bool 类型：显示复选框
			properties.append({
				"name": "value_min",
				"type": TYPE_BOOL,
				"hint": PROPERTY_HINT_NONE,
				"default": false,
				"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
			})
			properties.append({
				"name": "value_max",
				"type": TYPE_BOOL,
				"hint": PROPERTY_HINT_NONE,
				"default": true,
				"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
			})

		_:
			# 其他类型：使用默认的 float 编辑器
			properties.append({
				"name": "value_min",
				"type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE,
				"hint_string": "-10000,10000,0.001",
				"default": 0.0,
				"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
			})
			properties.append({
				"name": "value_max",
				"type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE,
				"hint_string": "-10000,10000,0.001",
				"default": 1.0,
				"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
			})

	# 🔥 Phase 3B: 始终定义 animation_curve 和 keyframes，根据 edit_mode 设置可见性
	# Curve Based 模式：显示 animation_curve，隐藏 keyframes
	if edit_mode == EditMode.CURVE_BASED:
		properties.append({
			"name": "animation_curve",
			"type": TYPE_OBJECT,
			"hint": PROPERTY_HINT_RESOURCE_TYPE,
			"hint_string": "Curve",
			"default": null,
			"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
		})

		properties.append({
			"name": "keyframes",
			"type": TYPE_ARRAY,
			"hint": PROPERTY_HINT_NONE,
			"default": [],
			"usage": PROPERTY_USAGE_STORAGE
		})

	# Keyframe Based 模式：显示 keyframes，隐藏 animation_curve
	else:  # EditMode.KEYFRAME_BASED
		properties.append({
			"name": "animation_curve",
			"type": TYPE_OBJECT,
			"hint": PROPERTY_HINT_RESOURCE_TYPE,
			"hint_string": "Curve",
			"default": null,
			"usage": PROPERTY_USAGE_STORAGE
		})

		properties.append({
			"name": "keyframes",
			"type": TYPE_ARRAY,
			"hint": PROPERTY_HINT_NONE,
			"default": [],
			"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
		})

	# 🔥 Phase 3B: 根据编辑模式添加不同的属性组
	match edit_mode:
		EditMode.CURVE_BASED:
			# Curve 模式：显示曲线编辑分组和 Bake 按钮
			properties.append({
				"name": "curve_section",
				"type": TYPE_NIL,
				"hint": PROPERTY_HINT_NONE,
				"usage": PROPERTY_USAGE_GROUP | PROPERTY_USAGE_EDITOR,
				"hint_string": "曲线编辑"
			})

			# 🔥 Phase 3B: 添加 Bake 按钮（虚拟属性）
			properties.append({
				"name": "bake_curve_to_keyframes_button",
				"type": TYPE_BOOL,
				"hint": PROPERTY_HINT_NONE,
				"default": false,
				"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_SCRIPT_DEFAULT_VALUE,
				"hint_string": "Bake Curve → Keyframes"
			})

		EditMode.KEYFRAME_BASED:
			# Keyframe 模式：显示关键帧编辑分组和 Bake Back 按钮
			properties.append({
				"name": "keyframes_section",
				"type": TYPE_NIL,
				"hint": PROPERTY_HINT_NONE,
				"usage": PROPERTY_USAGE_GROUP | PROPERTY_USAGE_EDITOR,
				"hint_string": "关键帧编辑"
			})

			# 🔥 Phase 3B: 添加 Bake Back 按钮（虚拟属性）
			properties.append({
				"name": "bake_keyframes_to_curve_button",
				"type": TYPE_BOOL,
				"hint": PROPERTY_HINT_NONE,
				"default": false,
				"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_SCRIPT_DEFAULT_VALUE,
				"hint_string": "Bake Keyframes → Curve"
			})

	# 🔥 Phase 3B: 显示 Bake 元数据（如果有关键帧是从 curve bake 的）
	if keyframes_baked_from_curve:
		properties.append({
			"name": "bake_metadata_section",
			"type": TYPE_NIL,
			"hint": PROPERTY_HINT_NONE,
			"usage": PROPERTY_USAGE_GROUP | PROPERTY_USAGE_EDITOR,
			"hint_string": "Bake 信息"
		})

		properties.append({
			"name": "bake_metadata",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_NONE,
			"default": "",
			"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY
		})

	return properties

## 🔥 Phase 3B: 属性设置和获取（处理 Bake 按钮和元数据）
func _set(property: StringName, value: Variant) -> bool:
	# 处理 Bake Curve → Keyframes 按钮
	if property == "bake_curve_to_keyframes_button":
		if value:  # 按钮被点击
			bake_curve_to_keyframes()
		return true

	# 处理 Bake Keyframes → Curve 按钮
	if property == "bake_keyframes_to_curve_button":
		if value:  # 按钮被点击
			bake_keyframes_to_curve()
		return true

	# 注意：edit_mode 和 property_path 有自定义 setter，不会经过 _set()
	return false

func _get(property: StringName) -> Variant:
	# 返回 Bake 元数据信息
	if property == "bake_metadata":
		if keyframes_baked_from_curve:
			return "从 Curve Bake 而来（%d 个关键帧）" % _bake_keyframe_count
		else:
			return "手动创建的关键帧"

	return null

## 验证属性
func _validate_property(property: Dictionary) -> void:
	"""验证属性值"""

	# 验证时间范围
	if property.name == "time_end":
		if time_end <= time_start:
			push_warning("time_end 必须大于 time_start")

	# 验证值范围（对数值类型）
	if property.name in ["value_min", "value_max"]:
		if _current_property_type in [TYPE_INT, TYPE_FLOAT]:
			# 数值类型验证
			var min_val = float(value_min)
			var max_val = float(value_max)
			if min_val >= max_val:
				push_warning("value_min 必须小于 value_max")

func validate_track() -> String:
	if property_path.is_empty():
		return "Property path cannot be empty"

	# 验证动画曲线（使用 get_point_count() 而不是 has_point()）
	if animation_curve and animation_curve.get_point_count() == 0:
		return "Animation curve must have at least one point"

	# 验证关键帧
	if not keyframes.is_empty():
		for i in range(keyframes.size()):
			var keyframe = keyframes[i]
			if not keyframe:
				return "Keyframe at index " + str(i) + " cannot be null"

			var keyframe_error = keyframe.validate_keyframe()
			if not keyframe_error.is_empty():
				return "Keyframe at index " + str(i) + ": " + keyframe_error

	# 验证参数映射
	if use_parameter_mapping:
		for i in range(parameter_mappings.size()):
			var mapping = parameter_mappings[i]
			if not mapping:
				return "Parameter mapping at index " + str(i) + " cannot be null"

			var mapping_error = mapping.validate_mapping() if mapping.has_method("validate_mapping") else ""
			if not mapping_error.is_empty():
				return "Parameter mapping error at index " + str(i) + ": " + mapping_error
	# 验证值范围
	if value_range.x > value_range.y:
		return "Value range minimum cannot be greater than maximum"
	
	# 验证时间缩放
	if time_scale <= 0.0:
		return "Time scale must be positive"
	
	return ""

# 获取当前时间点的值
func get_value_at_time(time: float, context: JuicyContext) -> Variant:
	"""
	获取当前时间点的值

	根据 edit_mode 自动选择采样方式：
	- CURVE_BASED: 使用 animation_curve
	- KEYFRAME_BASED: 使用 keyframes

	根据 blend_mode 返回正确的值：
	- OVERRIDE_BASE: 返回绝对值
	- ADDITIVE: 返回相对于 base_value 的偏移量
	- MULTIPLICATIVE: 返回乘法因子（暂未实现）

	@param time: 时间点（秒）
	@param context: JuicyContext 实例
	@return: 计算后的值
	"""
	# 1. 应用时间变换（time_offset, time_scale, wrap_mode）
	var transformed_time = _apply_time_transform(time)

	# 2. 应用参数映射到时间（如果启用）
	if use_parameter_mapping:
		transformed_time = _apply_time_parameter_mapping(transformed_time, context)

	# 3. 根据编辑模式采样原始值
	var raw_value: Variant
	match edit_mode:
		EditMode.CURVE_BASED:
			raw_value = _sample_from_curve(transformed_time, context)
		EditMode.KEYFRAME_BASED:
			raw_value = _sample_from_keyframes(transformed_time, context)
		_:
			# 默认使用 curve 模式
			raw_value = _sample_from_curve(transformed_time, context)

	# 4. 根据 blend_mode 处理值
	return _apply_blend_mode(raw_value, context)

## 应用混合模式
func _apply_blend_mode(raw_value: Variant, context: JuicyContext) -> Variant:
	"""
	根据 blend_mode 和 relative 处理原始值

	@param raw_value: 原始采样值
	@param context: JuicyContext 实例
	@return: 处理后的值
	"""
	if not context:
		return raw_value

	var context_id = context.context_id

	# 初始化状态（如果不存在）
	if not _track_states.has(context_id):
		_track_states[context_id] = {
			"base_value": null,
			"original_value": null,  # ADDITIVE 模式的原始值
			"previous_value": null,
			"loop_base": null,
			"loop_count": 0,
			"initialized": false
		}

	var state = _track_states[context_id]

	# 第一次访问时，初始化 base_value
	if not state.initialized:
		var target_node = get_target_node()

		if relative:
			# relative = true: 获取目标当前值作为 base_value
			# value_min/max 表示相对于当前位置的偏移量
			if target_node and property_path in target_node:
				state.base_value = target_node.get(property_path)
			else:
				state.base_value = _get_zero_value_for_type(raw_value)
		else:
			# relative = false: value_min/max 是绝对坐标
			state.base_value = _get_zero_value_for_type(raw_value)

		# 保存原始值（用于 ADDITIVE 模式）
		if target_node and property_path in target_node:
			state.original_value = target_node.get(property_path)
		else:
			state.original_value = _get_zero_value_for_type(raw_value)

		state.loop_base = state.base_value
		state.previous_value = raw_value
		state.initialized = true

	# 根据 blend_mode 和 relative 处理
	match blend_mode:
		BlendMode.ADDITIVE:
			# ADDITIVE: 返回 original_value + offset
			# 这样 PropertyBuffer 会替换上一帧的 sample，不会累加
			var curve_start_value = _get_curve_value_at_time(time_start, context)
			var offset_from_start = _subtract_values(raw_value, curve_start_value)

			if relative:
				# 🔥 特殊处理：Color 类型在 relative 模式下的 ADDITIVE 叠加
				if typeof(state.original_value) == TYPE_COLOR:
					# ADDITIVE + relative 模式：原始值 + (value_min ~ value_max 的插值)
					var original_color = state.original_value as Color
					var min_color: Color
					var max_color: Color

					# 解析 value_min（作为偏移量的起点）
					if value_min != null and value_min is Color:
						min_color = value_min as Color
					elif value_min != null and typeof(value_min) == TYPE_FLOAT:
						var brightness_scale = float(value_min)
						min_color = Color(brightness_scale, brightness_scale, brightness_scale, 1.0)
					else:
						# 默认：无偏移（黑色）
						min_color = Color(0.0, 0.0, 0.0, 1.0)

					# 解析 value_max（作为偏移量的终点）
					if value_max != null and value_max is Color:
						max_color = value_max as Color
					elif value_max != null and typeof(value_max) == TYPE_FLOAT:
						var brightness_scale = float(value_max)
						max_color = Color(brightness_scale, brightness_scale, brightness_scale, 1.0)
					else:
						# 默认：无偏移（黑色）
						max_color = Color(0.0, 0.0, 0.0, 1.0)

					# 计算偏移量：从 value_min 插值到 value_max
					var lerp_ratio = raw_value.r
					var offset = min_color.lerp(max_color, lerp_ratio)

					# ADDITIVE 叠加：原始值 + 偏移量
					# 注意：对于 modulate 属性，alpha 不应该叠加（保持原始 alpha）
					var final_value = Color(
						original_color.r + offset.r,
						original_color.g + offset.g,
						original_color.b + offset.b,
						original_color.a  # alpha 保持原值
					)

					return final_value
				else:
					# 非颜色类型：original_value + offset_from_start
					var final_value = _add_values(state.original_value, offset_from_start)
					state.previous_value = raw_value
					return final_value
			else:
				# relative = false: original_value + offset_from_start
				var final_value = _add_values(state.original_value, offset_from_start)
				state.previous_value = raw_value
				return final_value

		BlendMode.OVERRIDE_BASE:
			# OVERRIDE_BASE: 覆盖基础值
			if relative:
				# relative = true: base_value + (raw_value - curve_start_value)
				var curve_start_value = _get_curve_value_at_time(time_start, context)
				var offset_from_start = _subtract_values(raw_value, curve_start_value)
				var final_value = _add_values(state.base_value, offset_from_start)
				state.previous_value = raw_value
				return final_value
			else:
				# relative = false: 返回绝对值
				# 🔥 特殊处理：Color 类型使用插值
				if typeof(raw_value) == TYPE_COLOR:
					var min_color: Color
					var max_color: Color

					# 解析 value_min
					if value_min != null and value_min is Color:
						min_color = value_min as Color
					elif value_min != null and typeof(value_min) == TYPE_FLOAT:
						var brightness_scale = float(value_min)
						min_color = Color(brightness_scale, brightness_scale, brightness_scale, 1.0)
					else:
						# 默认黑色
						min_color = Color(0.0, 0.0, 0.0, 1.0)

					# 解析 value_max
					if value_max != null and value_max is Color:
						max_color = value_max as Color
					elif value_max != null and typeof(value_max) == TYPE_FLOAT:
						var brightness_scale = float(value_max)
						max_color = Color(brightness_scale, brightness_scale, brightness_scale, 1.0)
					else:
						# 默认白色
						max_color = Color(1.0, 1.0, 1.0, 1.0)

					# 使用 raw_value.r 作为插值因子
					var lerp_ratio = raw_value.r
					var final_value = min_color.lerp(max_color, lerp_ratio)

					state.previous_value = raw_value
					return final_value
				else:
					# 非颜色类型：直接返回 raw_value
					state.previous_value = raw_value
					return raw_value

		BlendMode.MULTIPLICATIVE:
			# MULTIPLICATIVE: 返回乘法因子（暂未实现）
			state.previous_value = raw_value
			return raw_value

		_:
			# 默认：返回绝对值
			state.previous_value = raw_value
			return raw_value

## 获取曲线在指定时间的值（用于计算相对偏移）
func _get_curve_value_at_time(time: float, context: JuicyContext) -> Variant:
	"""
	获取曲线在指定时间的值（不经过 blend_mode 处理）

	用于计算 relative 模式下的偏移量：
	- 获取曲线起点值（time_start）
	- 计算当前值相对于起点的偏移

	@param time: 时间点
	@param context: JuicyContext 实例
	@return: 原始曲线值
	"""
	# 应用时间变换
	var transformed_time = _apply_time_transform(time)

	# 根据编辑模式采样
	match edit_mode:
		EditMode.CURVE_BASED:
			return _sample_from_curve(transformed_time, context)
		EditMode.KEYFRAME_BASED:
			return _sample_from_keyframes(transformed_time, context)
		_:
			return _sample_from_curve(transformed_time, context)

## 值加法（支持多种类型）
func _add_values(a: Variant, b: Variant) -> Variant:
	"""
	计算两个值的和（a + b）

	@param a: 被加数
	@param b: 加数
	@return: 和
	"""
	if a == null:
		return b
	if b == null:
		return a

	match typeof(a):
		TYPE_FLOAT, TYPE_INT:
			return float(a) + float(b)
		TYPE_VECTOR2:
			return a as Vector2 + (b as Vector2)
		TYPE_VECTOR3:
			return a as Vector3 + (b as Vector3)
		TYPE_COLOR:
			# 🔥 Godot Color 支持加法！
			return a as Color + (b as Color)
		_:
			return a

## 值减法（支持多种类型）
func _subtract_values(a: Variant, b: Variant) -> Variant:
	"""
	计算两个值的差（a - b）

	@param a: 被减数
	@param b: 减数
	@return: 差值
	"""
	if a == null or b == null:
		return _get_zero_value_for_type(a)

	match typeof(a):
		TYPE_FLOAT, TYPE_INT:
			return float(a) - float(b)
		TYPE_VECTOR2:
			return a as Vector2 - (b as Vector2)
		TYPE_VECTOR3:
			return a as Vector3 - (b as Vector3)
		TYPE_COLOR:
			# 🔥 Godot Color 支持减法！
			return a as Color - (b as Color)
		_:
			return _get_zero_value_for_type(a)

## 获取类型的零值
func _get_zero_value_for_type(value: Variant) -> Variant:
	"""
	获取指定类型的零值

	@param value: 参考值
	@return: 对应类型的零值
	"""
	if value == null:
		return 0.0

	match typeof(value):
		TYPE_FLOAT:
			return 0.0
		TYPE_INT:
			return 0
		TYPE_VECTOR2:
			return Vector2.ZERO
		TYPE_VECTOR3:
			return Vector3.ZERO
		TYPE_COLOR:
			return Color.TRANSPARENT
		_:
			return 0.0

# 应用时间变换
func _apply_time_transform(time: float) -> float:
	"""应用时间变换"""
	var transformed_time = time
	
	if not use_absolute_time:
		transformed_time -= time_offset
	
	transformed_time *= time_scale
	
	# 应用循环模式
	transformed_time = _apply_wrap_mode(transformed_time)
	
	return transformed_time

# 应用循环模式
func _apply_wrap_mode(time: float) -> float:
	"""应用循环模式"""
	var result: float
	match wrap_mode:
		0:  # Clamp - 移除Clamp限制，允许时间超出1.0
			result = time
		1:  # Loop
			result = fmod(time, 1.0)
		2:  # PingPong
			var cycle = fmod(time, 2.0)
			result = cycle if cycle <= 1.0 else 2.0 - cycle
		_:
			result = time
	return result

# 应用时间参数映射
func _apply_time_parameter_mapping(time: float, context: JuicyContext) -> float:
	"""应用时间参数映射"""
	var time_multiplier = 1.0
	var time_offset = 0.0
	
	for mapping in parameter_mappings:
		if not mapping.enabled:
			continue
		
		# 根据映射类型处理
		match mapping.mapping_type:
			JuicyParameterMapping.MappingType.TRACK_TIME, JuicyParameterMapping.MappingType.TRACK_PROPERTY:
				var param_value = context.get_parameter(mapping.input_parameter, 1.0)
				var mapped_value = mapping.apply_mapping(param_value)
				
				match mapping.target_property:
					"time_scale":
						time_multiplier *= mapped_value
					"time_offset":
						time_offset += mapped_value
			JuicyParameterMapping.MappingType.CUSTOM:
				var param_value = context.get_parameter(mapping.input_parameter, 1.0)
				var mapped_value = mapping.apply_custom_mapping(param_value, self)
				time_multiplier *= mapped_value
	
	return (time + time_offset) * time_multiplier

# 应用值参数映射
func _apply_value_parameter_mapping(value: Variant, context: JuicyContext) -> Variant:
	"""应用值参数映射"""
	var result = value
	var value_type = typeof(value)
	
	# 参数映射只对float类型有意义（强度、偏移量、缩放等）
	# 对于Vector2/Vector3/Color等类型，暂时不支持参数映射
	if value_type != TYPE_FLOAT:
		return result
	
	for mapping in parameter_mappings:
		if not mapping.enabled:
			continue
		
			# 根据映射类型处理
		match mapping.mapping_type:
			JuicyParameterMapping.MappingType.TRACK_VALUE, JuicyParameterMapping.MappingType.TRACK_PROPERTY:
				var param_value = context.get_parameter(mapping.input_parameter, 1.0)
				var mapped_value = mapping.apply_mapping(param_value)
				
				# 根据目标属性应用映射
				match mapping.target_property:
					"intensity":
						result *= mapped_value
					"offset":
						result += mapped_value
					"scale":
						result *= mapped_value
					"override":
						result = mapped_value
					"value_range_min":
						var max_val = value_range.y
						result = lerp(mapped_value, max_val, (result - value_range.x) / (value_range.y - value_range.x))
					"value_range_max":
						var min_val = value_range.x
						result = lerp(min_val, mapped_value, (result - value_range.x) / (value_range.y - value_range.x))
			
			JuicyParameterMapping.MappingType.CUSTOM:
				var param_value = context.get_parameter(mapping.input_parameter, 1.0)
				result = mapping.apply_custom_mapping(param_value, self)
	
	return result

# 采样动画曲线
func _sample_animation_curve(time: float) -> float:
	"""采样动画曲线（旧版，保留用于向后兼容）"""
	if not animation_curve:
		return 0.0

	# 应用缓动预设
	var adjusted_time = _apply_easing_preset(time)

	return animation_curve.sample(clampf(adjusted_time, 0.0, 1.0))

## 🔥 从曲线采样（使用新的值域系统）
func _sample_from_curve(time: float, context: JuicyContext) -> Variant:
	"""
	从 animation_curve 采样值（使用类型自适应的值域）

	流程：
	1. 归一化时间到 0-1
	2. 采样曲线
	3. 🔥 使用类型自适应的映射函数
	4. 应用参数映射

	@param time: 实际时间（秒）
	@param context: JuicyContext 实例
	@return: 计算后的值
	"""
	if not animation_curve:
		# 没有曲线时返回最小值
		return value_min

	# 🔥 Phase 3B: 确保属性类型已正确检测（运行时首次访问）
	if _current_property_type == TYPE_NIL or _current_property_type != _cached_property_type:
		_ensure_property_type_detected()

	# 1. 归一化时间
	var normalized_time = _normalize_time(time)

	# 2. 采样曲线（应用缓动预设）
	var adjusted_time = _apply_easing_preset(normalized_time)
	var curve_val = animation_curve.sample(adjusted_time)

	# 🔥 调试输出（每个 curve_preset 显示前3次采样）
	if _debug_sample_count < 3:
		print("[_sample_from_curve] curve_preset=%d (%s), time=%.3f, normalized_time=%.3f, adjusted_time=%.3f, curve_val=%.3f" %
			  [curve_preset, JuicyCurveFactory.get_preset_name(curve_preset), time, normalized_time, adjusted_time, curve_val])
		_debug_sample_count += 1

	# 3. 🔥 使用类型自适应的映射函数
	var final_value = _map_curve_value_to_property_type(curve_val)

	# 4. 应用参数映射（仅对 float 类型有效）
	if use_parameter_mapping and typeof(final_value) == TYPE_FLOAT:
		final_value = _apply_value_parameter_mapping(final_value, context)

	return final_value

## 🔥 从关键帧采样
func _sample_from_keyframes(time: float, context: JuicyContext) -> Variant:
	"""
	从 keyframes 采样值

	@param time: 实际时间（秒）
	@param context: JuicyContext 实例
	@return: 计算后的值
	"""
	if keyframes.is_empty():
		# 如果没有关键帧，回退到曲线模式
		return _sample_from_curve(time, context)

	# 使用原有的关键帧采样逻辑
	var keyframe_value = _sample_keyframes(keyframes, time)

	# 如果关键帧返回的是Variant（非float），直接返回
	if typeof(keyframe_value) != TYPE_FLOAT:
		# 应用参数映射到最终值
		if use_parameter_mapping:
			keyframe_value = _apply_value_parameter_mapping(keyframe_value, context)
		return keyframe_value

	# 如果是 float，应用参数映射
	if use_parameter_mapping:
		keyframe_value = _apply_value_parameter_mapping(keyframe_value, context)

	return keyframe_value

# ============================================================================
# Phase 3C: Curve Preset 智能应用
# ============================================================================

## 应用待应用的曲线预设（由 Inspector 的 Apply 按钮调用）
func apply_pending_curve_preset() -> void:
	"""应用用户在 Inspector 中选择的曲线预设

	- 如果有待应用的预设（_pending_curve_preset >= 0）
	- 应用该预设到 curve_preset 属性
	- 清除待应用状态
	"""
	if _pending_curve_preset >= 0:
		var preset_to_apply = _pending_curve_preset
		_pending_curve_preset = -1  # 清除待应用状态
		# 直接设置 curve_preset，由于 _pending_curve_preset 已清除，
		# setter 会调用 _apply_curve_preset_smart
		curve_preset = preset_to_apply
	else:
		# 没有待应用的预设，重新应用当前 curve_preset
		_apply_curve_preset_smart(curve_preset)

## 智能应用曲线预设
func _apply_curve_preset_smart(preset: int) -> void:
	"""智能应用曲线预设

	- 如果有 animation_curve：应用形状到现有曲线
	- 如果没有 animation_curve：创建新曲线实例
	- 🔥 所有预设（0-24）都使用预制曲线，_apply_easing_preset 会跳过所有数学公式
	"""
	# 验证预设值
	if preset < 0 or preset > 24:
		push_error("Invalid curve preset: %d" % preset)
		return

	# 🔥 直接使用预设对应的曲线（所有预设都是预制曲线）
	var curve_preset_enum = preset as JuicyCurveFactory.CurvePreset

	# 🔥 总是创建新的 Curve 实例以确保 Inspector 缩略图正确刷新
	# （修改现有 Curve 不会触发缩略图更新，创建新对象会）
	var new_curve = JuicyCurveFactory.create_curve(curve_preset_enum)
	if new_curve:
		animation_curve = new_curve
		print("[JuicyPropertyTrack] 应用曲线预设: %s (curve_preset=%d)" %
			  [JuicyCurveFactory.get_preset_name(curve_preset_enum), preset])
		# 🔥 重置调试计数器，以便显示新预设的采样信息
		_debug_sample_count = 0
	else:
		push_error("Failed to create curve with preset: %d" % preset)

	emit_changed()
	notify_property_list_changed()  # 强制 Inspector 重新解析属性列表，更新缩略图

# ============================================================================
# 缓动预设应用（保留用于向后兼容和运行时优化）
# ============================================================================

# 应用缓动预设
func _apply_easing_preset(t: float) -> float:
	"""应用缓动预设（Phase 3C: 更新为使用 curve_preset）

	🔥 双重缓动修复：
	- 所有预设（0-24）都使用预制曲线，跳过数学公式
	- animation_curve 已经包含了正确的缓动形状，直接返回 t 即可
	"""
	# 🔥 所有预设（0-24）都直接返回 t
	# 因为 animation_curve 已经包含了正确的缓动形状
	# 不需要再应用数学公式，避免双重缓动
	return t

## 🔥 时间归一化函数
func _normalize_time(time: float) -> float:
	"""
	将实际时间归一化到 0-1 范围，用于 curve 采样

	@param time: 实际时间（秒）
	@return: 归一化时间 (0-1)
	"""
	var range_size = time_end - time_start

	# 避免除零
	if range_size <= 0.0:
		push_warning("time_end 必须大于 time_start")
		return 0.0

	var normalized = (time - time_start) / range_size
	return clampf(normalized, 0.0, 1.0)

## 🔥 反归一化函数（用于 bake keyframes）
func _denormalize_time(normalized_time: float) -> float:
	"""
	将归一化时间 (0-1) 转换回实际时间

	@param normalized_time: 归一化时间 (0-1)
	@return: 实际时间（秒）
	"""
	return lerp(time_start, time_end, normalized_time)

## 🔥 通用的值映射函数（支持所有类型）
func _map_curve_value_to_property_type(curve_value: float) -> Variant:
	"""
	将 curve 的 0-1 值映射到属性类型的值域

	@param curve_value: curve 采样值 (0-1)
	@return: 映射后的属性值
	"""
	# 🔥 如果属性类型为 NIL（未初始化），使用 FLOAT 作为默认类型
	var effective_type = _current_property_type
	if effective_type == TYPE_NIL:
		effective_type = TYPE_FLOAT

	match effective_type:
		TYPE_INT:
			# 整数：线性插值后四舍五入
			var min_val: float = 0.0
			var max_val: float = 100.0
			if value_min != null:
				if typeof(value_min) == TYPE_FLOAT:
					min_val = value_min
				elif typeof(value_min) == TYPE_INT:
					min_val = float(value_min)
			if value_max != null:
				if typeof(value_max) == TYPE_FLOAT:
					max_val = value_max
				elif typeof(value_max) == TYPE_INT:
					max_val = float(value_max)
			return round(lerp(min_val, max_val, curve_value))

		TYPE_FLOAT:
			# 浮点数：标准线性插值
			var min_val: float = 0.0
			var max_val: float = 1.0
			if value_min != null:
				if typeof(value_min) == TYPE_FLOAT:
					min_val = value_min
				elif typeof(value_min) == TYPE_INT:
					min_val = float(value_min)
			if value_max != null:
				if typeof(value_max) == TYPE_FLOAT:
					max_val = value_max
				elif typeof(value_max) == TYPE_INT:
					max_val = float(value_max)
			return lerp(min_val, max_val, curve_value)

		TYPE_VECTOR2:
			# Vector2：逐通道插值
			var min_vec = value_min if value_min != null and value_min is Vector2 else Vector2(0.0, 0.0)
			var max_vec = value_max if value_max != null and value_max is Vector2 else Vector2(1.0, 1.0)
			return min_vec.lerp(max_vec, curve_value)

		TYPE_VECTOR3:
			# Vector3：逐通道插值
			var min_vec = value_min if value_min != null and value_min is Vector3 else Vector3(0.0, 0.0, 0.0)
			var max_vec = value_max if value_max != null and value_max is Vector3 else Vector3(1.0, 1.0, 1.0)
			return min_vec.lerp(max_vec, curve_value)

		TYPE_COLOR:
			# Color：逐通道插值
			var min_color = value_min if value_min != null and value_min is Color else Color(0.0, 0.0, 0.0, 1.0)
			var max_color = value_max if value_max != null and value_max is Color else Color(1.0, 1.0, 1.0, 1.0)
			return min_color.lerp(max_color, curve_value)

		TYPE_BOOL:
			# bool：基于阈值
			var min_val = value_min if value_min != null else false
			var max_val = value_max if value_max != null else true
			return min_val if curve_value < 0.5 else max_val
		_:
			# 其他类型：返回最小值（不支持插值）
			push_warning("不支持的属性类型: " + str(_current_property_type))
			return value_min if value_min != null else 0.0

# 采样关键帧
func _sample_keyframes(keyframes: Array[Resource], time: float) -> Variant:
	"""采样关键帧"""
	if keyframes.is_empty():
		return 0.0
	
	# 排序关键帧（确保时间顺序）
	var sorted_keyframes = keyframes.duplicate()
	sorted_keyframes.sort_custom(func(a, b): return a.time < b.time)
	
	# 找到时间点前后的关键帧
	var prev_frame: Resource = null
	var next_frame: Resource = null
	
	for frame in sorted_keyframes:
		if frame.time <= time:
			prev_frame = frame
		elif frame.time > time and not next_frame:
			next_frame = frame
			break
	
	# 处理边界情况
	if not prev_frame:
		return next_frame.value if next_frame else 0.0
	if not next_frame:
		return prev_frame.value
	
	# 计算插值
	var t = (time - prev_frame.time) / (next_frame.time - prev_frame.time)
	
	# 获取值类型
	var value_type = typeof(prev_frame.value)
	
	# 根据值类型进行插值
	match value_type:
		TYPE_FLOAT:
			# float类型使用线性插值
			var prev_val = prev_frame.value as float
			var next_val = next_frame.value as float
			return lerp(prev_val, next_val, t)
		TYPE_VECTOR2:
			# Vector2类型使用线性插值
			var prev_val = prev_frame.value as Vector2
			var next_val = next_frame.value as Vector2
			return prev_val.lerp(next_val, t)
		TYPE_VECTOR3:
			# Vector3类型使用线性插值
			var prev_val = prev_frame.value as Vector3
			var next_val = next_frame.value as Vector3
			return prev_val.lerp(next_val, t)
		TYPE_COLOR:
			# Color类型使用线性插值
			var prev_val = prev_frame.value as Color
			var next_val = next_frame.value as Color
			return prev_val.lerp(next_val, t)
		TYPE_BOOL:
			# bool类型根据时间阈值决定
			return prev_frame.value if t < 0.5 else next_frame.value
		TYPE_INT:
			# int类型使用线性插值后四舍五入
			var prev_val = prev_frame.value as int
			var next_val = next_frame.value as int
			return round(lerp(float(prev_val), float(next_val), t))
		_:
			# 其他类型不支持插值，返回前一个关键帧的值
			return prev_frame.value

# 设置参数映射到上下文
func setup_parameter_mappings(context: JuicyContext) -> void:
	"""
	将轨道的参数映射设置到上下文中
	这些映射将在每帧更新时被应用
	
	@param context: JuicyContext实例
	"""
	if not use_parameter_mapping:
		return
		
	for mapping in parameter_mappings:
		if not mapping.enabled:
			continue
		
		# 为属性轨道添加特殊的参数映射处理
		# 这里我们使用自定义的处理逻辑，因为属性轨道直接修改值而不是通过PropertyBuffer
		context.set_custom_data("property_track_" + str(get_instance_id()) + "_" + mapping.input_parameter, mapping)

# 应用参数映射到属性值
func apply_parameter_mappings(context: JuicyContext, base_value: Variant) -> Variant:
	"""
	应用所有参数映射到基础值
	
	@param context: JuicyContext实例
	@param base_value: 基础属性值
	@return: 应用参数映射后的值
	"""
	if not use_parameter_mapping:
		return base_value
		
	var result = base_value
	var value_type = typeof(base_value)
	
	# 参数映射只对float类型有意义（强度、偏移量、缩放等）
	# 对于Vector2/Vector3/Color等类型，暂时不支持参数映射
	if value_type != TYPE_FLOAT:
		return result
	
	for mapping in parameter_mappings:
		if not mapping.enabled:
			continue
		
		# 根据映射类型处理
		match mapping.mapping_type:
			JuicyParameterMapping.MappingType.TRACK_VALUE, JuicyParameterMapping.MappingType.TRACK_PROPERTY:
				var param_value = context.get_parameter(mapping.input_parameter, 1.0)
				var mapped_value = mapping.apply_mapping(param_value)
				
				# 根据目标属性应用映射
				match mapping.target_property:
					"intensity":
						result *= mapped_value
					"offset":
						result += mapped_value
					"scale":
						result *= mapped_value
					"override":
						result = mapped_value
			
			JuicyParameterMapping.MappingType.CUSTOM:
				var param_value = context.get_parameter(mapping.input_parameter, 1.0)
				result = mapping.apply_custom_mapping(param_value, self)
	
	return result

# 获取轨道的开始时间
func get_start_time() -> float:
	# 🔥 Phase 3B: 对于 Curve Based 模式或空关键帧，使用 time_start
	if edit_mode == EditMode.CURVE_BASED or keyframes.is_empty():
		return time_start

	# 当使用绝对时间时，使用 time_offset
	if use_absolute_time:
		return time_offset

	# 否则，基于关键帧的实际时间计算时间范围
	# 找到最早的关键帧时间
	var min_time = keyframes[0].time
	for kf in keyframes:
		if kf.time < min_time:
			min_time = kf.time

	# 应用时间变换（偏移和缩放）
	var transformed = _apply_time_transform(min_time)
	return transformed

# 获取轨道的结束时间
func get_end_time() -> float:
	# 🔥 Phase 3B: 对于 Curve Based 模式或空关键帧，使用 time_end
	if edit_mode == EditMode.CURVE_BASED or keyframes.is_empty():
		return time_end

	# 当使用绝对时间时，使用固定的持续时间
	if use_absolute_time:
		return time_offset + (1.0 / time_scale)

	# 否则，基于关键帧的实际时间计算时间范围
	# 找到最晚的关键帧时间
	var max_time = keyframes[0].time
	for kf in keyframes:
		if kf.time > max_time:
			max_time = kf.time

	# 应用时间变换（偏移和缩放）
	var transformed = _apply_time_transform(max_time)
	return transformed

# 获取轨道的编辑器图标
func get_editor_icon() -> String:
	return "EditKey"

# 获取轨道的编辑器颜色
func get_editor_color() -> Color:
	return track_color

# 克隆轨道
func clone() -> JuicyTrack:
	var cloned_track = super.clone() as JuicyPropertyTrack
	
	# 复制属性轨道特有属性
	cloned_track.property_path = property_path
	cloned_track.animation_curve = animation_curve
	cloned_track.value_range = value_range
	cloned_track.relative = relative
	cloned_track.blend_mode = blend_mode
	cloned_track.use_absolute_time = use_absolute_time
	cloned_track.time_offset = time_offset
	cloned_track.time_scale = time_scale
	cloned_track.wrap_mode = wrap_mode
	cloned_track.use_parameter_mapping = use_parameter_mapping
	cloned_track.curve_preset = curve_preset  # Phase 3C: 使用 curve_preset
	
	# 复制关键帧
	cloned_track.keyframes.clear()
	for keyframe in keyframes:
		if keyframe:
			cloned_track.keyframes.append(keyframe.clone())
	
	# 复制参数映射
	cloned_track.parameter_mappings.clear()
	for mapping in parameter_mappings:
		if mapping:
			cloned_track.parameter_mappings.append(mapping.duplicate(true))
	
	return cloned_track

# 序列化支持
func get_config_dict() -> Dictionary:
	var config = super.get_config_dict()
	
	# 添加属性轨道特有配置
	config["property_path"] = property_path
	config["value_range"] = {"x": value_range.x, "y": value_range.y}
	config["relative"] = relative
	config["blend_mode"] = BlendMode.keys()[blend_mode]
	config["use_absolute_time"] = use_absolute_time
	config["time_offset"] = time_offset
	config["time_scale"] = time_scale
	config["wrap_mode"] = wrap_mode
	config["use_parameter_mapping"] = use_parameter_mapping
	config["curve_preset"] = curve_preset  # Phase 3C: 使用 curve_preset
	
	return config

# 从配置字典加载
func load_from_dict(config_dict: Dictionary) -> bool:
	if not super.load_from_dict(config_dict):
		return false
	
	# 加载属性轨道特有配置
	if config_dict.has("property_path"):
		property_path = config_dict["property_path"]
	if config_dict.has("value_range"):
		var range_dict = config_dict["value_range"]
		value_range = Vector2(range_dict.get("x", 0.0), range_dict.get("y", 1.0))
	if config_dict.has("relative"):
		relative = config_dict["relative"]
	if config_dict.has("blend_mode"):
		var mode_name = config_dict["blend_mode"]
		for i in range(BlendMode.values().size()):
			if BlendMode.keys()[i] == mode_name:
				blend_mode = BlendMode.values()[i]
				break
	if config_dict.has("use_absolute_time"):
		use_absolute_time = config_dict["use_absolute_time"]
	if config_dict.has("time_offset"):
		time_offset = config_dict["time_offset"]
	if config_dict.has("time_scale"):
		time_scale = config_dict["time_scale"]
	if config_dict.has("wrap_mode"):
		wrap_mode = config_dict["wrap_mode"]
	if config_dict.has("use_parameter_mapping"):
		use_parameter_mapping = config_dict["use_parameter_mapping"]

	# Phase 3C: 加载曲线预设（支持新旧格式）
	if config_dict.has("curve_preset"):
		curve_preset = config_dict["curve_preset"]
	elif config_dict.has("ease_preset"):
		# 向后兼容：旧的 ease_preset (0-3)
		var old_preset = config_dict["ease_preset"]
		if old_preset >= 0 and old_preset <= 3:
			curve_preset = old_preset
	
	# 向后兼容：尝试加载旧的 target_node_path
	if config_dict.has("target_node_path"):
		var old_path = config_dict["target_node_path"]
		target = NodePath(old_path)
		print("JuicyPropertyTrack: 从旧配置迁移 target_node_path: ", old_path)
	
	# 在加载完成后，重新获取目标节点信息以恢复正确的属性类型
	# 这确保 _current_property_type 在资源加载后被正确设置
	if Engine.is_editor_hint():
		print("JuicyPropertyTrack: 延迟恢复属性类型信息")
		# 修复：在延迟调用之前，立即更新属性类型信息
		# 这确保 keyframes 加载时使用正确的类型
		if not property_path.is_empty():
			# 立即更新属性类型信息（不需要节点实例）
			# 只需要知道属性名称就可以从目标节点获取类型
			var editor_interface = Engine.get_singleton("EditorInterface")
			if editor_interface:
				var edited_root = editor_interface.get_edited_scene_root()
				if edited_root:
					var target_node_str = str(target)
					var node_found = false
					
					# 尝试获取节点实例
					_target_node_instance = edited_root.get_node_or_null(target)
					if _target_node_instance:
						print("JuicyPropertyTrack: 立即获取节点：", _target_node_instance.get_path())
						node_found = true
					else:
						# 尝试绝对路径
						if target_node_str.begins_with("../"):
							var root_path = edited_root.get_path()
							var relative_part = target_node_str.substr(3)
							var absolute_path = str(root_path) + "/" + relative_part
							_target_node_instance = edited_root.get_node_or_null(absolute_path)
							if _target_node_instance:
								print("JuicyPropertyTrack: 立即获取节点（绝对路径）：", _target_node_instance.get_path())
								node_found = true
					
					# 如果节点获取成功，立即更新属性类型信息
					if node_found and _target_node_instance:
						_update_property_type_info()
		
		# 同时也延迟调用，确保在编辑器环境中节点信息被正确更新
		call_deferred("_update_target_node_info")
	
	return true

## 获取目标节点实例
func _update_target_node_info():
	_target_node_instance = null
	
	if target.is_empty():
		print("JuicyPropertyTrack: target为空，跳过节点获取")
		return
	
	# 在编辑器模式下获取节点实例
	if Engine.is_editor_hint():
		print("JuicyPropertyTrack: 尝试获取节点实例 - target: ", target)
		var editor_interface = Engine.get_singleton("EditorInterface")
		if editor_interface:
			var edited_root = editor_interface.get_edited_scene_root()
			if edited_root:
				print("JuicyPropertyTrack: edited_root: ", edited_root.get_path())
				var target_node_str = str(target)
				
				# 使用 try-catch 保护节点获取操作
				# 捕获可能的线程安全错误
				var node_found = false
				
				# 尝试直接获取节点
				_target_node_instance = edited_root.get_node_or_null(target)
				if _target_node_instance:
					print("JuicyPropertyTrack: 成功获取节点（直接路径）: ", _target_node_instance.get_path(), " 类型: ", _target_node_instance.get_class())
					node_found = true
				else:
					print("JuicyPropertyTrack: 直接路径获取失败，尝试绝对路径组合")
				
				# 如果直接获取失败，尝试组合绝对路径（支持相对路径）
				if not node_found and target_node_str.begins_with("../"):
					var root_path = edited_root.get_path()
					var relative_part = target_node_str.substr(3)  # 移除 "../"
					var absolute_path = str(root_path) + "/" + relative_part
					print("JuicyPropertyTrack: 尝试绝对路径: ", absolute_path)
					
					# 使用 get_node_or_null 避免错误抛出
					_target_node_instance = edited_root.get_node_or_null(absolute_path)
					if _target_node_instance:
						print("JuicyPropertyTrack: 成功获取节点（绝对路径）: ", _target_node_instance.get_path(), " 类型: ", _target_node_instance.get_class())
						node_found = true
					else:
						print("JuicyPropertyTrack: 绝对路径获取失败")
				
				# 如果节点获取成功，更新属性类型信息
				if node_found and _target_node_instance:
					_update_property_type_info()
				else:
					print("JuicyPropertyTrack: 无法获取节点实例")
	
	if _target_node_instance:
		print("JuicyPropertyTrack: 节点实例已获取，更新属性类型信息")
		_update_property_type_info()
	else:
		print("JuicyPropertyTrack: 无法获取节点实例，通知编辑器更新属性列表")

## 更新所有已存在keyframe的value类型（当property_path改变时）
func _update_keyframes_value_type():
	"""当property_path改变时，更新所有已存在keyframe的value类型"""
	# 遍历所有keyframe，更新它们的value类型
	for keyframe in keyframes:
		if keyframe:
			keyframe.set_property_type(_current_property_type)
			# 关键修复：通知每个keyframe刷新属性列表
			# 这确保Inspector能够重新生成value属性，使用新的类型
			if keyframe.has_method("notify_property_list_changed"):
				keyframe.notify_property_list_changed()

## 🔥 确保属性类型已检测（运行时调用）
func _ensure_property_type_detected():
	"""
	确保属性类型已正确检测（运行时首次访问时调用）

	如果在编辑器初始化时类型检测失败（因为目标节点为null），
	则在运行时重新检测
	"""
	# 如果已经有有效的类型信息，跳过
	if _current_property_type != TYPE_NIL and _current_property_type == _cached_property_type:
		return

	# 尝试获取目标节点并更新类型信息
	if _target_node_instance == null and not property_path.is_empty():
		_target_node_instance = get_target_node()

	if _target_node_instance != null and not property_path.is_empty():
		_update_property_type_info()

## 更新属性类型信息
func _update_property_type_info():
	_current_property_info = {}
	_current_property_type = TYPE_NIL
	_current_property_hint = PROPERTY_HINT_NONE
	_current_property_hint_string = ""

	# 修复：如果目标节点为空，尝试通过基类方法获取节点
	if _target_node_instance == null and not property_path.is_empty():
		_target_node_instance = get_target_node()

	if _target_node_instance == null or property_path.is_empty():
		return

	# 使用 JuicyPropertyManager 获取属性信息
	_current_property_info = JuicyPropertyManager.find_property(_target_node_instance, property_path)

	if not _current_property_info.is_empty():
		_current_property_type = _current_property_info.type
		_current_property_hint = _current_property_info.hint
		_current_property_hint_string = _current_property_info.hint_string

	# 根据属性类型设置keyframe value类型
	_update_keyframes_value_type()

## 创建新关键帧（根据当前属性类型）
func create_keyframe(time: float, value: Variant = null) -> JuicyKeyframe:
	"""
	创建新的关键帧，根据当前属性类型设置合适的默认值
	
	@param time: 关键帧时间
	@param value: 关键帧值（如果为null，则使用默认值）
	@return: 创建的关键帧
	"""
	var keyframe = JuicyKeyframe.new()
	keyframe.time = time
	
	# 确保目标节点信息已正确更新（解决编辑器重启后属性类型丢失的问题）
	_update_property_type_info()
	
	# 设置关键帧的属性类型（用于编辑器显示）
	keyframe.set_property_type(_current_property_type)
	
	# 根据属性类型设置默认值
	if value == null:
		value = _get_default_keyframe_value()
	
	keyframe.value = value
	
	return keyframe

## 获取关键帧默认值
func _get_default_keyframe_value() -> Variant:
	"""
	根据当前属性类型获取关键帧的默认值

	@return: 默认值
	"""
	# 🔥 如果属性类型为 NIL（未初始化），使用 FLOAT 作为默认类型
	var effective_type = _current_property_type
	if effective_type == TYPE_NIL:
		effective_type = TYPE_FLOAT

	match effective_type:
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

## 检查类型兼容性
func _are_types_compatible(old_type: int, new_type: int) -> bool:
	"""检查两种类型是否兼容，可以转换值而不丢失数据"""
	# Color 和 Vector2 之间可以转换
	if old_type == TYPE_COLOR and new_type == TYPE_VECTOR2:
		# Color(r,g,b,a) -> Vector2(x,y)
		return true
	if old_type == TYPE_VECTOR2 and new_type == TYPE_COLOR:
		# Vector2(x,y) -> Color(r,g,b,a)
		return true
	
	# Vector2 和 Vector3 之间可以转换（丢失z）
	if old_type == TYPE_VECTOR2 and new_type == TYPE_VECTOR3:
		return true
	if old_type == TYPE_VECTOR3 and new_type == TYPE_VECTOR2:
		return true  # z被设为0
	
	# 其他类型不兼容
	return false

## 根据属性类型调整值范围
func _adjust_value_range_for_property_type():
	if _current_property_info.is_empty():
		return

	# 使用 JuicyPropertyManager 获取默认值范围
	value_range = JuicyPropertyManager.get_default_value_range(_current_property_type)

## 🔥 通知值域改变（用于更新 Inspector）
func _notify_value_range_changed():
	notify_property_list_changed()

## 🔥 自动调整值域（根据属性类型）
func _auto_adjust_value_range_for_property_type():
	"""
	根据当前属性类型自动设置合理的默认值域

	类型映射：
	- TYPE_INT: (0, 100)
	- TYPE_FLOAT: (0.0, 1.0)
	- TYPE_VECTOR2: (Vector2(0,0), Vector2(1,1))
	- TYPE_VECTOR3: (Vector3(0,0,0), Vector3(1,1,1))
	- TYPE_COLOR: (Color(0,0,0,1), Color(1,1,1,1))
	"""
	if _current_property_type == _cached_property_type:
		return  # 类型未改变，跳过

	_cached_property_type = _current_property_type

	# 🔥 如果属性类型为 NIL（未初始化），使用 FLOAT 作为默认类型
	var effective_type = _current_property_type
	if effective_type == TYPE_NIL:
		effective_type = TYPE_FLOAT

	match effective_type:
		TYPE_INT:
			value_min = 0
			value_max = 100

		TYPE_FLOAT:
			value_min = 0.0
			value_max = 1.0

		TYPE_VECTOR2:
			value_min = Vector2(0.0, 0.0)
			value_max = Vector2(1.0, 1.0)

		TYPE_VECTOR3:
			value_min = Vector3(0.0, 0.0, 0.0)
			value_max = Vector3(1.0, 1.0, 1.0)

		TYPE_COLOR:
			value_min = Color(0.0, 0.0, 0.0, 1.0)  # 不透明黑色
			value_max = Color(1.0, 1.0, 1.0, 1.0)  # 不透明白色

		TYPE_BOOL:
			value_min = false
			value_max = true

		_:
			# 其他类型使用默认值
			value_min = 0.0
			value_max = 1.0

	print("[JuicyPropertyTrack] 值域已自动调整以匹配属性类型 ", effective_type)
	print("  value_min: ", value_min)
	print("  value_max: ", value_max)

## 获取属性枚举字符串（用于下拉菜单）
func _get_property_enum_string() -> String:
	# 如果目标节点实例已获取，直接返回属性列表
	if _target_node_instance != null:
		# 使用 JuicyPropertyManager 获取可写属性（与set_property_value.gd保持一致）
		var property_infos = JuicyPropertyManager.get_writable_properties(_target_node_instance)
		var property_names = []
		
		for prop_info in property_infos:
			# 过滤掉内部属性和不适用的属性
			if not prop_info.name.begins_with("_") and _is_valid_property_for_track(prop_info):
				property_names.append(prop_info.name)
		
		if property_names.is_empty():
			return "无可用的属性"
		
		return ",".join(property_names)
	
	# 如果target为空，提示用户先选择目标节点
	if target.is_empty():
		return "请先选择目标节点"
	
	# 在编辑器环境中，尝试延迟获取节点（避免线程安全问题）
	if Engine.is_editor_hint():
		# 返回加载中提示，延迟获取节点
		# 使用 call_deferred 在主线程上获取节点
		call_deferred("_update_target_node_info_safe")
		return "正在加载..."
	
	return "请先选择目标节点"

## 安全地更新目标节点信息（线程安全）
func _update_target_node_info_safe():
	"""安全地更新目标节点信息，避免线程安全问题"""
	_update_target_node_info()
	notify_property_list_changed()

## 检查属性是否适用于 Property Track
func _is_valid_property_for_track(prop_info: Dictionary) -> bool:
	# Property Track 可以控制所有可写属性（与set_property_value.gd保持一致）
	return prop_info.is_writable

# ==============================================================================
# Phase 2: 双向 Bake 系统
# ==============================================================================

## 🔥 将曲线烘焙为关键帧（使用 Curve 的实际控制点）
func bake_curve_to_keyframes() -> void:
	"""
	将 animation_curve 烘焙为关键帧数组

	使用 Curve 的实际控制点，而不是均匀采样

	工作流程：
	1. 验证 curve 存在
	2. 获取 curve 的控制点数量
	3. 为每个控制点创建一个关键帧
	4. 切换到 KEYFRAME_BASED 模式
	"""
	if not animation_curve:
		push_error("[JuicyPropertyTrack] 无法 bake：没有 animation_curve")
		return

	var point_count = animation_curve.get_point_count()
	if point_count == 0:
		push_error("[JuicyPropertyTrack] 无法 bake：curve 没有控制点")
		return

	print("[JuicyPropertyTrack] Bake curve to keyframes: %d points" % point_count)

	# 清空现有关键帧
	keyframes.clear()

	# 为每个 curve 控制点创建关键帧
	for i in range(point_count):
		# 获取控制点数据
		var point_data = animation_curve.get_point_position(i)

		# 提取归一化时间和值
		var t = point_data.x
		var curve_val = point_data.y

		# 反归一化到实际时间
		var time = _denormalize_time(t)

		# 🔥 使用类型自适应的映射函数
		var value = _map_curve_value_to_property_type(curve_val)

		# 创建关键帧（延迟设置类型，避免在循环中触发 Inspector 刷新）
		var keyframe = JuicyKeyframe.new()
		keyframe.time = time
		keyframe.value = value
		keyframes.append(keyframe)

	# 🔥 批量设置所有 keyframe 的类型（避免在循环中触发 notify_property_list_changed）
	for keyframe in keyframes:
		keyframe.set_property_type(_current_property_type)

	# 标记元数据
	keyframes_baked_from_curve = true
	_bake_keyframe_count = point_count

	# 切换编辑模式
	edit_mode = EditMode.KEYFRAME_BASED

	print("[JuicyPropertyTrack] Bake 完成：创建了 %d 个关键帧" % keyframes.size())
	notify_property_list_changed()

## 🔥 从关键帧反向烘焙到曲线
func bake_keyframes_to_curve() -> void:
	"""
	将关键帧数组转换回 animation_curve

	工作流程：
	1. 验证 keyframes 不为空
	2. 排序关键帧
	3. 创建或清空 animation_curve
	4. 将关键帧的值归一化并添加到曲线
	5. 切换到 CURVE_BASED 模式

	注意：
	- 关键帧的 custom interpolation 会丢失（curve 无法表示）
	- 非均匀分布的关键帧会被映射到均匀的曲线点
	"""
	if keyframes.is_empty():
		push_error("[JuicyPropertyTrack] 无法 bake：没有 keyframes")
		return

	print("[JuicyPropertyTrack] Bake keyframes to curve...")

	# 创建新曲线（如果不存在）
	if not animation_curve:
		animation_curve = Curve.new()
	else:
		animation_curve.clear_points()

	# 排序关键帧
	var sorted_kfs = keyframes.duplicate()
	sorted_kfs.sort_custom(func(a, b): return a.time < b.time)

	# 将关键帧转换为曲线点
	for kf in sorted_kfs:
		# 归一化时间到 0-1
		var normalized_time = _normalize_time(kf.time)

		# 🔥 归一化值到 0-1（需要根据属性类型处理）
		var normalized_value = _normalize_value(kf.value)

		# 添加到曲线
		animation_curve.add_point(Vector2(normalized_time, normalized_value))

	# 如果只有一个关键帧，添加端点
	if sorted_kfs.size() == 1:
		animation_curve.add_point(Vector2(1.0, animation_curve.sample(1.0)))

	# 标记元数据
	keyframes_baked_from_curve = false

	# 切换编辑模式
	edit_mode = EditMode.CURVE_BASED

	print("[JuicyPropertyTrack] Bake 完成：创建了 %d 个曲线点" % animation_curve.get_point_count())
	notify_property_list_changed()

## 🔥 将属性值归一化到 0-1（用于 bake keyframes to curve）
func _normalize_value(value: Variant) -> float:
	"""
	将属性值归一化到 0-1 范围

	@param value: 属性值
	@return: 归一化值 (0-1)
	"""
	# 🔥 如果属性类型为 NIL（未初始化），使用 FLOAT 作为默认类型
	var effective_type = _current_property_type
	if effective_type == TYPE_NIL:
		effective_type = TYPE_FLOAT

	match effective_type:
		TYPE_INT:
			var min_val: float = 0.0
			var max_val: float = 100.0
			if value_min != null:
				if typeof(value_min) == TYPE_FLOAT:
					min_val = value_min
				elif typeof(value_min) == TYPE_INT:
					min_val = float(value_min)
			if value_max != null:
				if typeof(value_max) == TYPE_FLOAT:
					max_val = value_max
				elif typeof(value_max) == TYPE_INT:
					max_val = float(value_max)
			if max_val - min_val > 0.0:
				return (float(value) - min_val) / (max_val - min_val)
			return 0.0

		TYPE_FLOAT:
			var min_val: float = 0.0
			var max_val: float = 1.0
			if value_min != null:
				if typeof(value_min) == TYPE_FLOAT:
					min_val = value_min
				elif typeof(value_min) == TYPE_INT:
					min_val = float(value_min)
			if value_max != null:
				if typeof(value_max) == TYPE_FLOAT:
					max_val = value_max
				elif typeof(value_max) == TYPE_INT:
					max_val = float(value_max)
			if max_val - min_val > 0.0:
				return (float(value) - min_val) / (max_val - min_val)
			return 0.0

		TYPE_VECTOR2:
			var min_vec = value_min if value_min != null else Vector2(0.0, 0.0)
			var max_vec = value_max if value_max != null else Vector2(1.0, 1.0)
			var vec = value if value != null else Vector2(0.0, 0.0)
			# 对于 Vector2，分别归一化每个通道，然后对有变化的通道取平均
			var normalized_values = []

			if max_vec.x - min_vec.x > 0.0:
				normalized_values.append((vec.x - min_vec.x) / (max_vec.x - min_vec.x))

			if max_vec.y - min_vec.y > 0.0:
				normalized_values.append((vec.y - min_vec.y) / (max_vec.y - min_vec.y))

			# 返回有变化通道的平均归一化值（如果没有变化的通道，返回 0.0）
			if normalized_values.is_empty():
				return 0.0
			var sum = 0.0
			for v in normalized_values:
				sum += v
			return sum / normalized_values.size()

		TYPE_VECTOR3:
			var min_vec = value_min if value_min != null else Vector3(0.0, 0.0, 0.0)
			var max_vec = value_max if value_max != null else Vector3(1.0, 1.0, 1.0)
			var vec = value if value != null else Vector3(0.0, 0.0, 0.0)
			# 对于 Vector3，分别归一化每个通道，然后对有变化的通道取平均
			var normalized_values = []

			if max_vec.x - min_vec.x > 0.0:
				normalized_values.append((vec.x - min_vec.x) / (max_vec.x - min_vec.x))

			if max_vec.y - min_vec.y > 0.0:
				normalized_values.append((vec.y - min_vec.y) / (max_vec.y - min_vec.y))

			if max_vec.z - min_vec.z > 0.0:
				normalized_values.append((vec.z - min_vec.z) / (max_vec.z - min_vec.z))

			# 返回有变化通道的平均归一化值（如果没有变化的通道，返回 0.0）
			if normalized_values.is_empty():
				return 0.0
			var sum = 0.0
			for v in normalized_values:
				sum += v
			return sum / normalized_values.size()

		TYPE_COLOR:
			var min_color = value_min if value_min != null else Color(0.0, 0.0, 0.0, 1.0)
			var max_color = value_max if value_max != null else Color(1.0, 1.0, 1.0, 1.0)
			var color = value if value != null else Color(0.0, 0.0, 0.0, 1.0)
			# 对于 Color，分别归一化每个通道，然后对有变化的通道取平均
			var normalized_values = []

			if max_color.r - min_color.r > 0.0:
				normalized_values.append((color.r - min_color.r) / (max_color.r - min_color.r))

			if max_color.g - min_color.g > 0.0:
				normalized_values.append((color.g - min_color.g) / (max_color.g - min_color.g))

			if max_color.b - min_color.b > 0.0:
				normalized_values.append((color.b - min_color.b) / (max_color.b - min_color.b))

			if max_color.a - min_color.a > 0.0:
				normalized_values.append((color.a - min_color.a) / (max_color.a - min_color.a))

			# 返回有变化通道的平均归一化值（如果没有变化的通道，返回 0.0）
			if normalized_values.is_empty():
				return 0.0
			var sum = 0.0
			for v in normalized_values:
				sum += v
			return sum / normalized_values.size()

		TYPE_BOOL:
			# bool 类型：false -> 0.0, true -> 1.0
			return 1.0 if value else 0.0

		_:
			# 其他类型：默认返回 0.0
			push_warning("不支持的属性类型: " + str(_current_property_type))
			return 0.0
