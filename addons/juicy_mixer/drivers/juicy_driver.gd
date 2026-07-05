# JuicyDriver - 驱动器基类
# 定义所有Driver的通用接口和行为
# 提供无状态计算的基础框架，实现驱动器的生命周期管理
# 支持类型安全的属性操作和性能监控

@abstract
class_name JuicyDriver
extends RefCounted

# =============================================================================
# DRIVER 元信息
# =============================================================================

## Driver名称标识，用于注册和识别
var driver_name: String = ""

## Driver版本号，用于版本管理和兼容性检查
var driver_version: String = "1.0.0"

## 支持的属性列表，定义此Driver可以操作的Node属性
var supported_properties: Array[String] = []

## 必需的上下文数据键名列表，定义此Driver需要的Context数据
var required_context_data: Array[String] = []

## Driver激活状态，用于动态启用/禁用
var is_active: bool = true

# =============================================================================
# 性能统计
# =============================================================================

## 执行次数统计
var _execution_count: int = 0

## 总执行时间（毫秒）
var _total_execution_time: float = 0.0

## 最后一次执行时间（毫秒）
var _last_execution_time: float = 0.0

# =============================================================================
# 时间管理状态
# =============================================================================

## 驱动器时间状态：context_id -> {elapsed_time: float, start_time: float}
var _driver_time_states: Dictionary = {}

# =============================================================================
# 核心接口 - 子类必须实现
# =============================================================================

## 准备阶段，在效果开始前调用一次
## 用于初始化Driver特定的数据和状态
@abstract
func prepare(context: JuicyContext, delta: float, buffer: JuicyPropertyBuffer) -> void

## 处理阶段，每帧调用
## 实现Driver的核心逻辑，计算属性值并写入缓冲区
@abstract
func process(context: JuicyContext, delta: float, buffer: JuicyPropertyBuffer) -> void

## 清理阶段，在效果结束时调用
## 用于清理Driver特定的数据和状态
func cleanup(context: JuicyContext) -> void:
	"""
	清理阶段，在效果结束时调用
	
	@param context: JuicyContext实例，包含效果运行所需的所有数据
	"""
	pass

# =============================================================================
# 验证接口
# =============================================================================

## 验证Context是否适合此Driver
## 检查必需的上下文数据和目标节点属性支持
func validate_context(context: JuicyContext) -> Dictionary:
	"""
	验证Context是否适合此Driver
	
	@param context: 要验证的JuicyContext实例
	
	@return: 验证结果字典，包含：
		- valid: bool，是否有效
		- issues: Array[String]，错误信息列表
		- warnings: Array[String]，警告信息列表
	"""
	var result = {
		"valid": true,
		"issues": [],
		"warnings": []
	}
	
	# 检查必需的上下文数据
	for data_key in required_context_data:
		if context.get_driver_data(data_key) == null:
			result.valid = false
			result.issues.append("Missing required context data: " + data_key)
	
	# 检查目标节点是否支持所需属性
	if context.target:
		for property in supported_properties:
			if not property in context.target:
				result.warnings.append("Target doesn't have property: " + property)
	
	return result

## 获取此Driver需要的属性列表
func get_required_properties() -> Array[String]:
	"""
	获取此Driver需要的属性列表
	
	@return: 支持的属性名称数组
	"""
	return supported_properties.duplicate()

## 检查是否支持指定目标
## 验证目标节点是否至少支持一个所需属性
func supports_target(target: Node) -> bool:
	"""
	检查是否支持指定目标
	
	@param target: 要检查的目标Node实例
	
	@return: 如果目标支持至少一个所需属性则返回true
	"""
	if not target:
		return false
	
	for property in supported_properties:
		if property in target:
			return true
	
	return false

# =============================================================================
# 性能监控
# =============================================================================

## 获取性能统计信息
func get_performance_stats() -> Dictionary:
	"""
	获取性能统计信息
	
	@return: 性能统计字典，包含：
		- execution_count: int，总执行次数
		- total_execution_time: float，总执行时间（毫秒）
		- average_execution_time: float，平均执行时间（毫秒）
		- last_execution_time: float，最后一次执行时间（毫秒）
	"""
	return {
		"execution_count": _execution_count,
		"total_execution_time": _total_execution_time,
		"average_execution_time": _total_execution_time / max(_execution_count, 1),
		"last_execution_time": _last_execution_time
	}

## 重置性能统计
func reset_performance_stats() -> void:
	"""重置所有性能统计信息"""
	_execution_count = 0
	_total_execution_time = 0.0
	_last_execution_time = 0.0

# =============================================================================
# 内部方法 - 性能监控
# =============================================================================

## 开始执行计时
func _start_execution_timer() -> float:
	"""
	开始执行计时
	
	@return: 当前时间戳（微秒）
	"""
	return Time.get_ticks_usec()

## 结束执行计时并更新统计
func _end_execution_timer(start_time: float) -> void:
	"""
	结束执行计时并更新统计
	
	@param start_time: _start_execution_timer()返回的时间戳
	"""
	_last_execution_time = (Time.get_ticks_usec() - start_time) / 1000.0  # 转换为毫秒
	_execution_count += 1
	_total_execution_time += _last_execution_time

# =============================================================================
# 属性操作辅助方法
# =============================================================================

## 安全地添加属性采样到缓冲区
## 自动处理属性存在性检查和混合模式
func _add_property_sample(buffer: JuicyPropertyBuffer, context: JuicyContext, 
						 property: String, value: Variant, mode: int) -> void:
	"""
	安全地添加属性采样到缓冲区
	
	@param buffer: JuicyPropertyBuffer实例
	@param context: JuicyContext实例
	@param property: 属性名称
	@param value: 属性值
	@param mode: 混合模式（JuicyPropertyBuffer.BlendMode）
	"""
	if property in context.target:
		buffer.add_sample(context.target, property, value, mode, context.context_id)

## 获取Context中的驱动器数据
## 使用阶段1提供的强类型访问方法
func _get_context_value(context: JuicyContext, key: String, default: Variant = null) -> Variant:
	"""
	获取Context中的驱动器数据
	
	@param context: JuicyContext实例
	@param key: 数据键名
	@param default: 默认值（可选）
	
	@return: 存储在Context中的数据值
	"""
	return context.get_driver_data(key)

## 设置Context中的驱动器数据
## 使用阶段1提供的强类型访问方法
func _set_context_value(context: JuicyContext, key: String, value: Variant) -> void:
	"""
	设置Context中的驱动器数据
	
	@param context: JuicyContext实例
	@param key: 数据键名
	@param value: 要存储的数据值
	"""
	context.set_driver_data(key, value)

## 获取属性覆盖值
## 用于处理高优先级的效果覆盖
func _get_property_override(context: JuicyContext, property: String, default: Variant) -> Variant:
	"""
	获取属性覆盖值
	
	@param context: JuicyContext实例
	@param property: 属性名称
	@param default: 默认值
	
	@return: 属性覆盖值，如果没有覆盖则返回默认值
	"""
	return context.get_property_override(property, default)

## 设置属性覆盖值
## 用于设置高优先级的效果覆盖
func _set_property_override(context: JuicyContext, property: String, value: Variant) -> void:
	"""
	设置属性覆盖值
	
	@param context: JuicyContext实例
	@param property: 属性名称
	@param value: 覆盖值
	"""
	context.set_property_override(property, value)

# =============================================================================
# 标准时间管理接口
# =============================================================================

## 初始化驱动器时间状态
func _initialize_driver_time(context: JuicyContext) -> void:
	"""
	初始化驱动器时间状态
	
	@param context: JuicyContext实例，包含效果运行所需的所有数据
	"""
	var context_id = context.context_id
	_driver_time_states[context_id] = {
		"elapsed_time": 0.0,
		"start_time": Time.get_ticks_msec() / 1000.0
	}

## 更新驱动器时间并返回有效增量
func _update_driver_time(context: JuicyContext, delta: float) -> float:
	"""
	更新驱动器时间并返回有效增量
	
	@param context: JuicyContext实例，包含效果运行所需的所有数据
	@param delta: 时间增量（秒）
	
	@return: 有效时间增量（考虑时间缩放）
	"""
	var context_id = context.context_id
	var time_state = _driver_time_states[context_id]
	
	var effective_delta = delta * context.time_scale
	time_state.elapsed_time += effective_delta
	
	return effective_delta

## 获取驱动器经过时间
func _get_driver_elapsed_time(context: JuicyContext) -> float:
	"""
	获取驱动器经过时间
	
	@param context: JuicyContext实例，包含效果运行所需的所有数据
	
	@return: 经过的时间（秒）
	"""
	var context_id = context.context_id
	if not _driver_time_states.has(context_id):
		return 0.0
	return _driver_time_states[context_id].elapsed_time

## 基于时间的完成判断
func _is_time_based_complete(context: JuicyContext, target_duration: float) -> bool:
	"""
	基于时间的完成判断
	
	@param context: JuicyContext实例，包含效果运行所需的所有数据
	@param target_duration: 目标持续时间（秒）
	
	@return: 如果达到目标时间则返回true
	"""
	var elapsed = _get_driver_elapsed_time(context)
	return elapsed >= target_duration - 0.001  # 1ms容差

## 清理驱动器时间状态
func _cleanup_driver_time(context: JuicyContext) -> void:
	"""
	清理驱动器时间状态
	
	@param context: JuicyContext实例，包含效果运行所需的所有数据
	"""
	_driver_time_states.erase(context.context_id)

# =============================================================================
# 工具方法
# =============================================================================

## 获取Driver的静态信息
## 用于注册和调试
func get_driver_info() -> Dictionary:
	"""
	获取Driver的静态信息
	
	@return: Driver信息字典，包含：
		- name: String，Driver名称
		- version: String，版本号
		- properties: Array[String]，支持的属性
		- required_data: Array[String]，必需的上下文数据
		- active: bool，激活状态
	"""
	return {
		"name": driver_name,
		"version": driver_version,
		"properties": supported_properties.duplicate(),
		"required_data": required_context_data.duplicate(),
		"active": is_active
	}

## 检查Driver是否准备好执行
## 验证所有必需条件是否满足
func is_ready(context: JuicyContext) -> bool:
	"""
	检查Driver是否准备好执行
	
	@param context: JuicyContext实例
	
	@return: 如果所有必需条件都满足则返回true
	"""
	# 检查Driver是否激活
	if not is_active:
		return false
	
	# 验证Context
	var validation = validate_context(context)
	if not validation.valid:
		return false
	
	# 检查目标支持
	if not supports_target(context.target):
		return false
	
	return true