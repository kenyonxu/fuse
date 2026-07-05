# ChannelInterruptionConfig - 通道中断配置
# 配置通道级中断行为，管理中断策略参数
# 提供可编辑的配置选项，支持通道特定的优先级

@tool
class_name ChannelInterruptionConfig
extends Resource

# 通道配置
@export var channel_name: String = ""
@export var default_policy: JuicyMixerEnums.InterruptionPolicy = JuicyMixerEnums.InterruptionPolicy.STACK
@export var priority: int = 0
@export var max_queue_size: int = 10
@export var transition_duration: float = 0.2
@export var allow_preemption: bool = true  # 是否允许抢占

# 高级配置
@export var enable_priority_queue: bool = true
@export var enable_interruption_history: bool = true
@export var max_history_size: int = 100
@export var auto_cleanup_threshold: int = 50  # 队列大小超过此值时自动清理

# =============================================================================
# 生命周期方法
# =============================================================================

func _init():
	# 设置默认值
	if channel_name.is_empty():
		channel_name = "default"

# =============================================================================
# 策略配置方法
# =============================================================================

func set_policy(policy: JuicyMixerEnums.InterruptionPolicy) -> void:
	"""
	设置默认中断策略
	
	@param policy: 中断策略
	"""
	default_policy = policy

func get_policy() -> JuicyMixerEnums.InterruptionPolicy:
	"""
	获取默认中断策略
	
	@return: 中断策略
	"""
	return default_policy

func set_channel_priority(prio: int) -> void:
	"""
	设置通道优先级
	
	@param prio: 优先级数值
	"""
	priority = prio

func get_channel_priority() -> int:
	"""
	获取通道优先级
	
	@return: 优先级数值
	"""
	return priority

func set_max_queue_size(size: int) -> void:
	"""
	设置最大队列大小
	
	@param size: 队列大小
	"""
	max_queue_size = max(size, 1)

func get_max_queue_size() -> int:
	"""
	获取最大队列大小
	
	@return: 队列大小
	"""
	return max_queue_size

func set_transition_duration(duration: float) -> void:
	"""
	设置过渡持续时间
	
	@param duration: 持续时间（秒）
	"""
	transition_duration = max(duration, 0.0)

func get_transition_duration() -> float:
	"""
	获取过渡持续时间
	
	@return: 持续时间（秒）
	"""
	return transition_duration

func set_preemption_allowed(allowed: bool) -> void:
	"""
	设置是否允许抢占
	
	@param allowed: 是否允许
	"""
	allow_preemption = allowed

func is_preemption_allowed() -> bool:
	"""
	检查是否允许抢占
	
	@return: 是否允许
	"""
	return allow_preemption

# =============================================================================
# 功能开关方法
# =============================================================================

func enable_feature(feature: String, enabled: bool) -> void:
	"""
	启用/禁用特定功能
	
	@param feature: 功能名称
	@param enabled: 是否启用
	"""
	match feature:
		"priority_queue":
			enable_priority_queue = enabled
		"interruption_history":
			enable_interruption_history = enabled
		"auto_cleanup":
			auto_cleanup_threshold = 50 if enabled else 0

func is_feature_enabled(feature: String) -> bool:
	"""
	检查特定功能是否启用
	
	@param feature: 功能名称
	@return: 是否启用
	"""
	match feature:
		"priority_queue":
			return enable_priority_queue
		"interruption_history":
			return enable_interruption_history
		"auto_cleanup":
			return auto_cleanup_threshold > 0
	return false

# =============================================================================
# 配置验证
# =============================================================================

func validate_config() -> Dictionary:
	"""
	验证配置有效性
	
	@return: 验证结果字典，包含：
		- valid: bool，是否有效
		- issues: Array[String]，错误信息列表
	"""
	var issues = []
	
	if channel_name.is_empty():
		issues.append("Channel name cannot be empty")
	
	if max_queue_size < 1:
		issues.append("Max queue size must be at least 1")
	
	if transition_duration < 0.0:
		issues.append("Transition duration cannot be negative")
	
	if max_history_size < 10:
		issues.append("Max history size should be at least 10")
	
	return {
		"valid": issues.is_empty(),
		"issues": issues
	}

# =============================================================================
# 资源管理
# =============================================================================

func duplicate(subresources: bool = false) -> Resource:
	"""
	创建配置的副本
	
	@param subresources: 是否复制子资源
	@return: 新的配置实例
	"""
	var new_config = ChannelInterruptionConfig.new()
	new_config.channel_name = channel_name
	new_config.default_policy = default_policy
	new_config.priority = priority
	new_config.max_queue_size = max_queue_size
	new_config.transition_duration = transition_duration
	new_config.allow_preemption = allow_preemption
	new_config.enable_priority_queue = enable_priority_queue
	new_config.enable_interruption_history = enable_interruption_history
	new_config.max_history_size = max_history_size
	new_config.auto_cleanup_threshold = auto_cleanup_threshold
	
	return new_config

# =============================================================================
# 编辑器支持
# =============================================================================

func _get_property_list() -> Array[Dictionary]:
	"""
	获取自定义属性列表，用于编辑器显示
	"""
	var properties = []
	
	# 基础配置组
	properties.append({
		"name": "Base Configuration",
		"type": TYPE_NIL,
		"hint": PROPERTY_HINT_NONE,
		"usage": PROPERTY_USAGE_GROUP
	})
	
	# 高级配置组
	properties.append({
		"name": "Advanced Configuration",
		"type": TYPE_NIL,
		"hint": PROPERTY_HINT_NONE,
		"usage": PROPERTY_USAGE_GROUP
	})
	
	return properties

func _to_string() -> String:
	"""
	获取字符串表示
	
	@return: 配置字符串
	"""
	return "ChannelInterruptionConfig[channel=%s, policy=%s, priority=%d]" % [
		channel_name, JuicyMixerEnums.get_interruption_policy_name(default_policy), priority
	]

# =============================================================================
# 配置序列化
# =============================================================================

func get_config_dict() -> Dictionary:
	"""
	获取配置字典，用于序列化
	
	@return: 配置字典
	"""
	return {
		"channel_name": channel_name,
		"default_policy": JuicyMixerEnums.get_interruption_policy_name(default_policy),
		"priority": priority,
		"max_queue_size": max_queue_size,
		"transition_duration": transition_duration,
		"allow_preemption": allow_preemption,
		"enable_priority_queue": enable_priority_queue,
		"enable_interruption_history": enable_interruption_history,
		"max_history_size": max_history_size,
		"auto_cleanup_threshold": auto_cleanup_threshold
	}

func load_from_dict(config_dict: Dictionary) -> bool:
	"""
	从配置字典加载
	
	@param config_dict: 配置字典
	@return: 是否成功加载
	"""
	if not config_dict:
		# 空字典应该被视为成功加载，保持现有值
		return true
	
	# 基础配置
	if config_dict.has("channel_name"):
		channel_name = config_dict["channel_name"]
	if config_dict.has("default_policy"):
		var policy_name = config_dict["default_policy"]
		default_policy = JuicyMixerEnums.get_interruption_policy_from_name(policy_name)
	if config_dict.has("priority"):
		priority = config_dict["priority"]
	if config_dict.has("max_queue_size"):
		max_queue_size = config_dict["max_queue_size"]
	if config_dict.has("transition_duration"):
		transition_duration = config_dict["transition_duration"]
	if config_dict.has("allow_preemption"):
		allow_preemption = config_dict["allow_preemption"]
	
	# 高级配置
	if config_dict.has("enable_priority_queue"):
		enable_priority_queue = config_dict["enable_priority_queue"]
	if config_dict.has("enable_interruption_history"):
		enable_interruption_history = config_dict["enable_interruption_history"]
	if config_dict.has("max_history_size"):
		max_history_size = config_dict["max_history_size"]
	if config_dict.has("auto_cleanup_threshold"):
		auto_cleanup_threshold = config_dict["auto_cleanup_threshold"]
	
	return true

# 资源序列化支持
func serialize_resource() -> Dictionary:
	"""
	序列化资源配置
	
	@return: 序列化后的配置字典
	"""
	return {
		"resource_type": "ChannelInterruptionConfig",
		"version": "1.0",
		"data": get_config_dict()
	}

func deserialize_resource(data: Dictionary) -> bool:
	"""
	从序列化数据恢复资源配置
	
	@param data: 序列化数据
	@return: 是否成功恢复
	"""
	if not data or not data.has("data"):
		return false
	
	if data.has("version") and data.version != "1.0":
		push_warning("ChannelInterruptionConfig version mismatch: expected 1.0, got " + str(data.version))
	
	return load_from_dict(data.data)

func validate_serialization_data(data: Dictionary) -> Dictionary:
	"""
	验证序列化数据的有效性
	
	@param data: 要验证的序列化数据
	@return: 验证结果字典 {valid: bool, issues: Array[String]}
	"""
	var result = {
		"valid": true,
		"issues": []
	}
	
	if not data or typeof(data) != TYPE_DICTIONARY:
		result.valid = false
		result.issues.append("Invalid data format")
		return result
	
	# 检查必需字段
	var required_fields = ["resource_type", "version", "data"]
	for field in required_fields:
		if not data.has(field):
			result.valid = false
			result.issues.append("Missing required field: " + field)
	
	# 验证资源类型
	if data.has("resource_type") and data.resource_type != "ChannelInterruptionConfig":
		result.valid = false
		result.issues.append("Invalid resource type")
	
	# 验证版本
	if data.has("version") and data.version != "1.0":
		result.issues.append("Version mismatch: expected 1.0, got " + str(data.version))
	
	# 验证配置数据
	if data.has("data"):
		var config_result = validate_config()
		if not config_result.valid:
			result.valid = false
			result.issues.append_array(config_result.issues)
	
	return result