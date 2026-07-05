class_name JuicyMixerEnums

enum  tween_properties {
    custom,
    position,
    rotation,
    scale,
    modulate,
    self_modulate,
    skew,
    size,
    global_position,
    global_rotation,
    global_scale,
    pivot_offset,
    offset
}

## Shake效果常用属性
enum shake_properties  {
    custom,
    position,
    rotation,
    scale,
    offset,
    zoom,
    global_position,
    global_rotation,
    global_scale,
    pivot_offset,
    modulate
}

## Spring效果常用属性
enum spring_properties  {
    custom,
    position,
    rotation,
    scale,
    offset,
    zoom,
    global_position,
    global_rotation,
    global_scale,
    pivot_offset,
    modulate
}

## 中断策略枚举
enum InterruptionPolicy {
	STACK,              # 堆叠：新效果加入队列
	RESTART,            # 重启：立即重启效果
	IGNORE,             # 忽略：忽略新效果
	SMOOTH_TRANSITION,   # 平滑过渡：平滑过渡到新效果
	PRIORITY_OVERRIDE,   # 优先级覆盖：高优先级覆盖低优先级
	FADE_OUT_FADE_IN,   # 淡出淡入：当前效果淡出，新效果淡入
	PRIORITY_STACK      # 优先级堆叠：按优先级插入队列
}

# =============================================================================
# 实用函数
# =============================================================================

static func get_tween_property_name(enum_value: tween_properties) -> String:
	"""
	根据 tween_properties 枚举值获取对应的属性名称
	
	@param enum_value: tween_properties 枚举值
	@return: 对应的属性名称字符串
	"""
	match enum_value:
		tween_properties.custom:
			return "custom"
		tween_properties.position:
			return "position"  # Node2D, Control 等节点
		tween_properties.rotation:
			return "rotation"  # Node2D, Control 等节点
		tween_properties.scale:
			return "scale"  # Node2D, Control 等节点
		tween_properties.modulate:
			return "modulate"  # CanvasItem 节点 - 调制颜色和透明度(影响自身及子节点)
		tween_properties.self_modulate:
			return "self_modulate"  # Control 节点 - 调制颜色和透明度(仅影响自身)
		tween_properties.skew:
			return "skew"  # Node2D 节点
		tween_properties.size:
			return "size"  # Control 节点
		tween_properties.global_position:
			return "global_position"  # Node2D 节点
		tween_properties.global_rotation:
			return "global_rotation"  # Node2D 节点
		tween_properties.global_scale:
			return "global_scale"  # Node2D 节点
		tween_properties.pivot_offset:
			return "pivot_offset"  # Node2D, Control 节点
		tween_properties.offset:
			return "offset"  # Node2D, Control 等节点
		_:
			return ""

static func get_shake_property_name(enum_value: shake_properties) -> String:
	"""
	根据 shake_properties 枚举值获取对应的属性名称
	
	@param enum_value: shake_properties 枚举值
	@return: 对应的属性名称字符串
	"""
	match enum_value:
		shake_properties.custom:
			return "custom"
		shake_properties.position:
			return "position"  # Node2D, Control 等节点
		shake_properties.rotation:
			return "rotation"  # Node2D, Control 等节点
		shake_properties.scale:
			return "scale"  # Node2D, Control 等节点
		shake_properties.offset:
			return "offset"  # Node2D, Control 等节点
		shake_properties.zoom:
			return "zoom"  # Camera2D 节点
		shake_properties.global_position:
			return "global_position"  # Node2D 节点
		shake_properties.global_rotation:
			return "global_rotation"  # Node2D 节点
		shake_properties.global_scale:
			return "global_scale"  # Node2D 节点
		shake_properties.pivot_offset:
			return "pivot_offset"  # Node2D, Control 节点
		shake_properties.modulate:
			return "modulate"  # CanvasItem 节点 - 颜色震动效果
		_:
			return ""


static func get_property_type_hint(property_name: String) -> String:
	"""
	获取属性的类型提示，用于编辑器显示
	
	@param property_name: 属性名称
	@return: 类型描述字符串
	"""
	match property_name:
		"position", "global_position", "offset", "pivot_offset":
			return "Vector2"
		"rotation", "global_rotation":
			return "float (radians)"
		"scale", "global_scale":
			return "Vector2"
		"modulate", "self_modulate":
			return "Color"
		"skew":
			return "float"
		"size":
			return "Vector2"
		"zoom":
			return "Vector2"
		"custom":
			return "自定义属性"
		_:
			return "未知类型"

static func get_spring_property_name(enum_value: spring_properties) -> String:
	"""
	根据 spring_properties 枚举值获取对应的属性名称
	
	@param enum_value: spring_properties 枚举值
	@return: 对应的属性名称字符串
	"""
	match enum_value:
		spring_properties.custom:
			return "custom"
		spring_properties.position:
			return "position"  # Node2D, Control 等节点
		spring_properties.rotation:
			return "rotation"  # Node2D, Control 等节点
		spring_properties.scale:
			return "scale"  # Node2D, Control 等节点
		spring_properties.offset:
			return "offset"  # Node2D, Control 等节点
		spring_properties.zoom:
			return "zoom"  # Camera2D 节点
		spring_properties.global_position:
			return "global_position"  # Node2D 节点
		spring_properties.global_rotation:
			return "global_rotation"  # Node2D 节点
		spring_properties.global_scale:
			return "global_scale"  # Node2D 节点
		spring_properties.pivot_offset:
			return "pivot_offset"  # Node2D, Control 节点
		spring_properties.modulate:
			return "modulate"  # CanvasItem 节点 - 颜色弹性效果
		_:
			return ""



# =============================================================================
# 属性验证函数
# =============================================================================

static func is_property_valid_for_node(property_name: String, node: Node) -> bool:
	"""
	检查给定的属性名称对于指定节点是否有效
	
	@param property_name: 属性名称
	@param node: 要检查的节点
	@return: 属性是否有效
	"""
	if property_name == "custom":
		return true  # 自定义属性总是有效的
	
	# 检查节点是否有该属性
	if not node or property_name.is_empty():
		return false
	
	# 获取节点的所有属性列表
	var props = node.get_property_list()
	for prop in props:
		if prop.has("name") and prop.name == property_name:
			return true
	
	return false

static func get_valid_properties_for_node(node: Node) -> Array[String]:
	"""
	获取指定节点支持的所有有效属性列表
	
	@param node: 要检查的节点
	@return: 支持的属性名称数组
	"""
	var valid_props: Array[String] = []
	
	if not node:
		return valid_props
	
	# 获取节点的所有属性
	var props = node.get_property_list()
	
	# 检查每个 tween_properties 枚举值
	for enum_value in tween_properties.values():
		var prop_name = get_tween_property_name(enum_value)
		if prop_name != "custom" and is_property_valid_for_node(prop_name, node):
			valid_props.append(prop_name)
	
	return valid_props

# =============================================================================
# 中断策略辅助函数
# =============================================================================

static func get_interruption_policy_name(policy: InterruptionPolicy) -> String:
	"""
	根据 InterruptionPolicy 枚举值获取对应的策略名称
	
	@param policy: InterruptionPolicy 枚举值
	@return: 对应的策略名称字符串
	"""
	match policy:
		InterruptionPolicy.STACK:
			return "stack"
		InterruptionPolicy.RESTART:
			return "restart"
		InterruptionPolicy.IGNORE:
			return "ignore"
		InterruptionPolicy.SMOOTH_TRANSITION:
			return "smooth_transition"
		InterruptionPolicy.PRIORITY_OVERRIDE:
			return "priority_override"
		InterruptionPolicy.FADE_OUT_FADE_IN:
			return "fade_out_fade_in"
		InterruptionPolicy.PRIORITY_STACK:
			return "priority_stack"
		_:
			return "unknown"

static func get_interruption_policy_from_name(name: String) -> InterruptionPolicy:
	"""
	根据策略名称字符串获取对应的 InterruptionPolicy 枚举值
	
	@param name: 策略名称字符串
	@return: 对应的 InterruptionPolicy 枚举值
	"""
	match name.to_lower():
		"stack":
			return InterruptionPolicy.STACK
		"restart":
			return InterruptionPolicy.RESTART
		"ignore":
			return InterruptionPolicy.IGNORE
		"smooth_transition":
			return InterruptionPolicy.SMOOTH_TRANSITION
		"priority_override":
			return InterruptionPolicy.PRIORITY_OVERRIDE
		"fade_out_fade_in":
			return InterruptionPolicy.FADE_OUT_FADE_IN
		"priority_stack":
			return InterruptionPolicy.PRIORITY_STACK
		_:
			return InterruptionPolicy.STACK  # 默认策略

static func get_all_interruption_policies() -> Array[String]:
	"""
	获取所有可用的中断策略名称
	
	@return: 策略名称字符串数组
	"""
	return [
		"stack",
		"restart", 
		"ignore",
		"smooth_transition",
		"priority_override",
		"fade_out_fade_in",
		"priority_stack"
	]

static func get_interruption_policy_description(policy: InterruptionPolicy) -> String:
	"""
	获取中断策略的描述信息
	
	@param policy: InterruptionPolicy 枚举值
	@return: 策略描述字符串
	"""
	match policy:
		InterruptionPolicy.STACK:
			return "堆叠：新效果加入队列，当前效果继续执行"
		InterruptionPolicy.RESTART:
			return "重启：立即停止当前效果，开始新效果"
		InterruptionPolicy.IGNORE:
			return "忽略：忽略新效果，保持当前效果"
		InterruptionPolicy.SMOOTH_TRANSITION:
			return "平滑过渡：平滑地从当前效果过渡到新效果"
		InterruptionPolicy.PRIORITY_OVERRIDE:
			return "优先级覆盖：高优先级效果覆盖低优先级效果"
		InterruptionPolicy.FADE_OUT_FADE_IN:
			return "淡出淡入：当前效果淡出，新效果淡入"
		InterruptionPolicy.PRIORITY_STACK:
			return "优先级堆叠：按优先级插入队列"
		_:
			return "未知策略"

# =============================================================================
# 状态管理枚举
# =============================================================================

## 状态还原模式
enum RestorationMode {
	SNAP,     # 立即还原：直接将属性设回原始快照值
	EASE,     # 缓动还原：使用内置缓动函数平滑过渡
	CURVE     # 曲线还原：使用自定义曲线进行平滑过渡
}

static func get_restoration_mode_name(mode: RestorationMode) -> String:
	"""
	根据 RestorationMode 枚举值获取对应的模式名称
	
	@param mode: RestorationMode 枚举值
	@return: 对应的模式名称字符串
	"""
	match mode:
		RestorationMode.SNAP:
			return "snap"
		RestorationMode.EASE:
			return "ease"
		RestorationMode.CURVE:
			return "curve"
		_:
			return "unknown"

static func get_restoration_mode_from_name(name: String) -> RestorationMode:
	"""
	根据模式名称字符串获取对应的 RestorationMode 枚举值
	
	@param name: 模式名称字符串
	@return: 对应的 RestorationMode 枚举值
	"""
	match name.to_lower():
		"snap":
			return RestorationMode.SNAP
		"ease":
			return RestorationMode.EASE
		"curve":
			return RestorationMode.CURVE
		_:
			return RestorationMode.SNAP  # 默认模式

static func get_restoration_mode_description(mode: RestorationMode) -> String:
	"""
	获取状态还原模式的描述信息
	
	@param mode: RestorationMode 枚举值
	@return: 模式描述字符串
	"""
	match mode:
		RestorationMode.SNAP:
			return "立即还原：直接将属性设回原始快照值"
		RestorationMode.EASE:
			return "缓动还原：使用内置缓动函数平滑过渡"
		RestorationMode.CURVE:
			return "曲线还原：使用自定义曲线进行平滑过渡"
		_:
			return "未知模式"