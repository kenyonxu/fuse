# JuicyFeedbackResource - 反馈资源基类
# 定义反馈效果的配置接口，提供类型安全的配置方法
# 支持资源序列化和反序列化，作为所有具体资源类型的基类

@tool
@abstract
class_name JuicyFeedbackResource
extends Resource

# 时长类型枚举
enum DurationSource {
	MANUAL,      # 手动设置（由Track指定）
	EXACT,       # 资源提供精确时长（如Tween, Animation, Shake）
	ESTIMATED,   # 资源提供估算时长（如Spring）
	MIXED        # 混合时长（包含多个子资源，类型取决于子资源）
}

# 基础配置
var duration: float = 1.0
@export_group("Channel settings")
@export var channel: String = "default"
@export var priority: int = 0

@export_group("Time group configuration")
@export var time_group: String = ""

# 时长变更信号
signal duration_changed(new_duration: float)

# 中断策略配置
@export_group("Interruption Configuration")
@export var interruption_policy: JuicyMixerEnums.InterruptionPolicy = JuicyMixerEnums.InterruptionPolicy.STACK
@export var interruption_priority: int = 0  # 中断优先级，用于优先级相关的策略
# 高级中断配置
@export var allow_interruption: bool = true  # 是否允许被中断
@export var can_interrupt_others: bool = true  # 是否可以中断其他效果
@export var interruption_fade_duration: float = 0.1  # 中断时的淡入淡出时间

# 验证结果
class ValidationResult:
	var valid: bool = true
	var issues: Array[String] = []
	var warnings: Array[String] = []

# 虚拟方法 - 子类必须实现
func create_drivers() -> Array:
	push_error("create_drivers() must be implemented by subclass")
	return []

func validate_config() -> ValidationResult:
	var result = ValidationResult.new()
	
	# 基础验证
	if duration <= 0:
		result.valid = false
		result.issues.append("Duration must be greater than 0")
	
	if channel.is_empty():
		result.warnings.append("Empty channel name, using 'default'")
		channel = "default"
	
	# 中断策略验证
	if interruption_fade_duration < 0:
		result.valid = false
		result.issues.append("Interruption fade duration cannot be negative")
	
	return result

# 中断策略相关方法
func get_interruption_policy() -> JuicyMixerEnums.InterruptionPolicy:
	"""获取中断策略"""
	return interruption_policy

func set_interruption_policy(policy: JuicyMixerEnums.InterruptionPolicy) -> void:
	"""设置中断策略"""
	interruption_policy = policy

func get_interruption_priority() -> int:
	"""获取中断优先级"""
	return interruption_priority

func set_interruption_priority(priority: int) -> void:
	"""设置中断优先级"""
	interruption_priority = priority

func can_be_interrupted() -> bool:
	"""检查是否允许被中断"""
	return allow_interruption

func can_interrupt() -> bool:
	"""检查是否可以中断其他效果"""
	return can_interrupt_others

func get_fade_duration() -> float:
	"""获取中断淡入淡出时间"""
	return interruption_fade_duration

# 资源管理
func get_resource_type() -> String:
	return get_script().get_global_name()

func get_description() -> String:
	return "JuicyFeedbackResource: " + get_resource_type()

# 编辑器支持
func _get_property_list() -> Array[Dictionary]:
	var properties = []
	
	# 基础配置组
	properties.append({
		"name": "Base Configuration",
		"type": TYPE_NIL,
		"hint": PROPERTY_HINT_NONE,
		"usage": PROPERTY_USAGE_GROUP
	})
	
	# 中断策略组
	properties.append({
		"name": "Interruption Policy",
		"type": TYPE_NIL,
		"hint": PROPERTY_HINT_NONE,
		"usage": PROPERTY_USAGE_GROUP
	})
	
	return properties

# 获取时长
@abstract
func get_duration() -> float

# 获取时长来源类型
func get_duration_source() -> DurationSource:
	"""
	返回该资源时长的类型
	子类应该重写此方法以返回正确的时长类型
	"""
	push_error("get_duration_source() must be implemented by subclass")
	return DurationSource.EXACT

# 检查时长是否会随资源参数变化而变化
func is_duration_dynamic() -> bool:
	"""
	检查时长是否会随资源参数变化而变化
	@return: 如果时长是估算的，可能随参数变化，返回true
	"""
	return get_duration_source() == DurationSource.ESTIMATED

# 获取时长的描述信息，用于编辑器显示
func get_duration_description() -> String:
	"""
	获取时长的描述信息，用于编辑器显示
	@return: 包含时长类型和数值的描述字符串
	"""
	match get_duration_source():
		DurationSource.MANUAL:
			return "手动设置"
		DurationSource.EXACT:
			return "精确: %.2f秒" % get_duration()
		DurationSource.ESTIMATED:
			return "估算: ~%.2f秒" % get_duration()
		_:
			return "未知"

# 序列化支持
func _to_string() -> String:
	return "%s(duration=%.2f, channel='%s', policy=%s, priority=%d)" % [
		get_resource_type(),
		duration,
		channel,
		JuicyMixerEnums.get_interruption_policy_name(interruption_policy),
		interruption_priority
	]

# 配置序列化
func get_config_dict() -> Dictionary:
	"""获取配置字典，用于序列化"""
	return {
		"duration": duration,
		"channel": channel,
		"priority": priority,
		"time_group": time_group,
		"interruption_policy": JuicyMixerEnums.get_interruption_policy_name(interruption_policy),
		"interruption_priority": interruption_priority,
		"allow_interruption": allow_interruption,
		"can_interrupt_others": can_interrupt_others,
		"interruption_fade_duration": interruption_fade_duration
	}

func load_from_dict(config_dict: Dictionary) -> bool:
	"""从配置字典加载"""
	if not config_dict:
		return false
	
	# 基础配置
	if config_dict.has("duration"):
		duration = config_dict["duration"]
	if config_dict.has("channel"):
		channel = config_dict["channel"]
	if config_dict.has("priority"):
		priority = config_dict["priority"]
	if config_dict.has("time_group"):
		time_group = config_dict["time_group"]
	
	# 中断策略配置
	if config_dict.has("interruption_policy"):
		var policy_name = config_dict["interruption_policy"]
		interruption_policy = JuicyMixerEnums.get_interruption_policy_from_name(policy_name)
	if config_dict.has("interruption_priority"):
		interruption_priority = config_dict["interruption_priority"]
	if config_dict.has("allow_interruption"):
		allow_interruption = config_dict["allow_interruption"]
	if config_dict.has("can_interrupt_others"):
		can_interrupt_others = config_dict["can_interrupt_others"]
	if config_dict.has("interruption_fade_duration"):
		interruption_fade_duration = config_dict["interruption_fade_duration"]
	
	return true

# 获取数据数量
@abstract
func get_data_count() -> int

# 获取指定索引的数据
@abstract
func get_data_at(index: int) -> JuicyFeedbackData

# 设置指定索引的数据
@abstract
func set_data_at(index: int, source: JuicyFeedbackData) -> void

# 获取数据序列
@abstract
func get_data() -> Array
