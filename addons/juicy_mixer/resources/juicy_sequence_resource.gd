# JuicySequenceResource - 序列化资源配置
# 定义效果序列的配置结构，支持顺序和并行执行模式
# 提供条件执行、随机选择、循环重复机制，以及事件同步功能

@tool
class_name JuicySequenceResource
extends JuicyFeedbackResource

# 序列化配置
@export var sequence_items: Array[JuicySequenceItem] = []
@export var parallel: bool = false
@export var random_order: bool = false
@export var loop_sequence: bool = false
@export var loop_count: int = -1  # -1表示无限循环
@export var shuffle_items: bool = false

# 事件同步配置
@export var enable_event_sync: bool = false
@export var global_event_listeners: Array[String] = []  # 全局事件监听器
@export var event_timeout: float = 10.0  # 事件等待超时时间

# 创建驱动器
func create_drivers() -> Array:
	var driver = JuicySequenceDriver.new()
	driver.sequence_resource = self
	return [driver]

# 获取时长来源类型
func get_duration_source() -> DurationSource:
	"""
	返回序列资源的时长来源类型
	
	@return: 
		- EXACT: 如果所有序列项都是精确时长
		- ESTIMATED: 如果有任何序列项是估算时长
	"""
	var items = get("sequence_items")
	if items.is_empty():
		return DurationSource.EXACT
	
	# 检查所有序列项的时长类型
	for item in items:
		if not item or not item.enabled:
			continue
		if item.resource and item.resource.has_method("get_duration_source"):
			var source = item.resource.get_duration_source()
			if source == DurationSource.ESTIMATED:
				# 如果有任何子资源是估算时长，返回估算（保守估计）
				return DurationSource.ESTIMATED
	
	# 所有子资源都是精确时长
	return DurationSource.EXACT

# 获取持续时间 - 重写基类方法
func get_duration() -> float:
	"""计算序列的总持续时间"""
	var items = get("sequence_items")
	if items.is_empty():
		return 1.0  # 默认持续时间
	
	var total_duration = 0.0
	for item in items:
		if not item or not item.enabled:
			continue
		
		# 添加延迟时间
		if item.delay > 0:
			total_duration += item.delay
		
		# 添加持续时间
		var item_duration = item.duration
		if item_duration <= 0:
			# 如果项持续时间未设置或无效，使用资源的默认持续时间
			if item.resource and item.resource.has_method("get_duration"):
				item_duration = item.resource.get_duration()
			else:
				item_duration = 1.0  # 默认持续时间
		
		total_duration += item_duration
	
	return total_duration

# 联觉系统：检查事件触发条件
func should_trigger_by_event(item: JuicySequenceItem, event_name: String) -> bool:
	if not enable_event_sync or item.trigger_mode != JuicySequenceItem.TriggerMode.EVENT:
		return false
	
	return item.trigger_event == event_name

# 验证配置
func validate_config() -> ValidationResult:
	var result = super.validate_config()
	
	# 验证序列化项
	var actual_items = get("sequence_items")
	if actual_items.is_empty():
		result.valid = false
		result.issues.append("Sequence items cannot be empty")
	
	for i in range(actual_items.size()):
		var item = actual_items[i]
		var item_issues = item.validate()
		
		# 检查是否有验证问题
		if not item_issues.is_empty():
			result.valid = false
			for issue in item_issues:
				result.issues.append("Item " + str(i) + ": " + issue)
		
		# 验证事件同步配置
		if enable_event_sync:
			if item.trigger_mode == JuicySequenceItem.TriggerMode.EVENT and item.trigger_event.is_empty():
				result.valid = false
				result.issues.append("Item " + str(i) + ": Trigger event cannot be empty when trigger_mode is EVENT")
	
	# 验证循环配置
	if loop_sequence and loop_count == 0:
		result.valid = false
		result.issues.append("Loop count cannot be 0 when loop_sequence is enabled")
	
	# 验证事件同步配置
	if enable_event_sync:
		if event_timeout <= 0:
			result.valid = false
			result.issues.append("Event timeout must be greater than 0")
	
	return result

# 获取序列化类型
func get_sequence_type() -> String:
	if parallel:
		return "parallel"
	else:
		return "sequential"

# 获取事件同步状态
func get_event_sync_status() -> String:
	if not enable_event_sync:
		return "disabled"
	
	var event_count = 0
	var current_items = get("sequence_items")
	for item in current_items:
		if item.trigger_mode == JuicySequenceItem.TriggerMode.EVENT:
			event_count += 1
	
	return str(event_count) + " event-triggered items"

# 获取配置摘要
func get_summary() -> String:
	var summary = "JuicySequenceResource("
	summary += "type=" + get_sequence_type()
	var current_items = get("sequence_items")
	summary += ", items=" + str(current_items.size())
	summary += ", loop=" + str(loop_sequence)
	
	if loop_sequence:
		summary += "(" + str(loop_count) + ")"
	
	if enable_event_sync:
		summary += ", event_sync=" + get_event_sync_status()
	
	summary += ")"
	return summary

# 编辑器属性分组
func _get_property_list() -> Array[Dictionary]:
	var properties = super._get_property_list()
	
	# 序列化配置组
	properties.append({
		"name": "Sequence Configuration",
		"type": TYPE_NIL,
		"hint": PROPERTY_HINT_NONE,
		"usage": PROPERTY_USAGE_GROUP
	})
	
	# 事件同步配置组
	if enable_event_sync:
		properties.append({
			"name": "Event Sync Configuration",
			"type": TYPE_NIL,
			"hint": PROPERTY_HINT_NONE,
			"usage": PROPERTY_USAGE_GROUP
		})
	
	return properties

# 序列化支持
func _to_string() -> String:
	return get_summary()

# 配置序列化
func get_config_dict() -> Dictionary:
	var config = super.get_config_dict()
	
	# 序列化配置
	config["sequence_items"] = []
	var current_items = get("sequence_items")
	for item in current_items:
		config["sequence_items"].append({
			"resource": item.resource.get_path() if item.resource else "",
			"delay": item.delay,
			"duration": item.duration,
			"condition": item.condition,
			"weight": item.weight,
			"enabled": item.enabled,
			"trigger_mode": JuicySequenceItem.TriggerMode.keys()[item.trigger_mode],
			"trigger_event": item.trigger_event
		})
	
	config["parallel"] = parallel
	config["random_order"] = random_order
	config["loop_sequence"] = loop_sequence
	config["loop_count"] = loop_count
	config["shuffle_items"] = shuffle_items
	
	# 事件同步配置
	config["enable_event_sync"] = enable_event_sync
	config["global_event_listeners"] = global_event_listeners
	config["event_timeout"] = event_timeout
	
	return config

# 从配置字典加载
func load_from_dict(config_dict: Dictionary) -> bool:
	if not super.load_from_dict(config_dict):
		return false
	
	# 加载序列化项
	if config_dict.has("sequence_items"):
		sequence_items.clear()
		var items_config = config_dict["sequence_items"]
		for item_config in items_config:
			var item = JuicySequenceItem.new()
			
			# 加载资源引用
			if item_config.has("resource") and not item_config["resource"].is_empty():
				# 这里需要实现资源加载逻辑
				# item.resource = load(item_config["resource"])
				pass
			
			if item_config.has("delay"):
				item.delay = item_config["delay"]
			if item_config.has("duration"):
				item.duration = item_config["duration"]
			if item_config.has("condition"):
				item.condition = item_config["condition"]
			if item_config.has("weight"):
				item.weight = item_config["weight"]
			if item_config.has("enabled"):
				item.enabled = item_config["enabled"]
			if item_config.has("trigger_mode"):
				var mode_name = item_config["trigger_mode"]
				item.trigger_mode = JuicySequenceItem.TriggerMode[mode_name]
			if item_config.has("trigger_event"):
				item.trigger_event = item_config["trigger_event"]
			
			sequence_items.append(item)
	
	# 加载序列化配置
	if config_dict.has("parallel"):
		parallel = config_dict["parallel"]
	if config_dict.has("random_order"):
		random_order = config_dict["random_order"]
	if config_dict.has("loop_sequence"):
		loop_sequence = config_dict["loop_sequence"]
	if config_dict.has("loop_count"):
		loop_count = config_dict["loop_count"]
	if config_dict.has("shuffle_items"):
		shuffle_items = config_dict["shuffle_items"]
	
	# 加载事件同步配置
	if config_dict.has("enable_event_sync"):
		enable_event_sync = config_dict["enable_event_sync"]
	if config_dict.has("global_event_listeners"):
		global_event_listeners = config_dict["global_event_listeners"]
	if config_dict.has("event_timeout"):
		event_timeout = config_dict["event_timeout"]
	
	return true

# 实现JuicyFeedbackResource的抽象方法
func get_data_count() -> int:
	return 0

func get_data_at(index: int) -> JuicyFeedbackData:
	return null

func set_data_at(index: int, source: JuicyFeedbackData) -> void:
	pass

func get_data() -> Array:
	return []
