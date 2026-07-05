# JuicySequenceEventHandler - 序列事件处理器
# 专门用于处理序列化系统中的事件同步，监听特定事件并通知序列状态

class_name JuicySequenceEventHandler
extends JuicyEventHandler

# 事件类型定义
enum SequenceEventType {
	SEQUENCE_STARTED,        # 序列开始
	SEQUENCE_COMPLETED,      # 序列完成
	SEQUENCE_ITEM_STARTED,   # 序列项开始
	SEQUENCE_ITEM_COMPLETED, # 序列项完成
	SEQUENCE_LOOPED,         # 序列循环
	SEQUENCE_INTERRUPTED,    # 序列中断
	SEQUENCE_RESUMED,        # 序列恢复
	CUSTOM_EVENT             # 自定义事件
}

var target_event_name: String = ""
var sequence_context_id: String = ""
var sequence_state: Object = null  # 使用Object类型避免循环依赖
var sequence_event_type: SequenceEventType = SequenceEventType.CUSTOM_EVENT
var _performance_stats: Dictionary = {}

func _init():
	handler_name = "SequenceEventHandler"
	supported_events = [JuicyEvent.EventType.CUSTOM_EVENT]
	description = "Handles custom events for sequence synchronization"
	_reset_performance_stats()

func handle_event(event: JuicyEvent) -> bool:
	var start_time = _start_handling_timer()
	var result = false
	
	if not event or not sequence_state:
		_record_failure()
		_end_handling_timer(start_time)
		return false
	
	# 检查事件名称匹配
	var event_name = ""
	if event.event_data.has("event_name"):
		event_name = event.event_data["event_name"]
	elif not event.event_name.is_empty():
		event_name = event.event_name
	
	# 检查序列事件类型匹配
	if sequence_event_type != SequenceEventType.CUSTOM_EVENT:
		var event_type = _get_sequence_event_type(event)
		if event_type != sequence_event_type:
			_end_handling_timer(start_time)
			return false
	
	if event_name == target_event_name:
		# 记录事件已触发 - 直接操作序列状态对象的属性
		print("SequenceEventHandler: Processing matching event - " + event_name + ", target: " + target_event_name)
		if sequence_state:
			# 直接访问triggered_events属性
			var triggered_events = sequence_state.triggered_events
			print("SequenceEventHandler: Current triggered events: ", triggered_events)
			if triggered_events is Array and not event_name in triggered_events:
				triggered_events.append(event_name)
				_record_success()
				result = true
				print("SequenceEventHandler: Event recorded - " + event_name)
			else:
				print("SequenceEventHandler: Event already recorded or invalid triggered_events")
		else:
			print("SequenceEventHandler: Cannot record event, state is null")
		
		# 记录性能统计
		_update_performance_stats(event_name, true)
		
		_log_debug("Event handled: " + event_name + " for context: " + sequence_context_id)
	else:
		_record_failure()
	
	_end_handling_timer(start_time)
	return result

func configure(config: Dictionary) -> void:
	super.configure(config)
	
	if config.has("target_event_name"):
		target_event_name = config["target_event_name"]
	
	if config.has("sequence_context_id"):
		sequence_context_id = config["sequence_context_id"]
	
	if config.has("sequence_state"):
		sequence_state = config["sequence_state"]
	
	if config.has("sequence_event_type"):
		sequence_event_type = config["sequence_event_type"]

func get_configuration() -> Dictionary:
	var config = super.get_configuration()
	config["target_event_name"] = target_event_name
	config["sequence_context_id"] = sequence_context_id
	config["sequence_event_type"] = sequence_event_type
	return config

# 私有方法
func _get_sequence_event_type(event: JuicyEvent) -> SequenceEventType:
	"""从事件中获取序列事件类型"""
	if not event or not event.event_data.has("sequence_event_type"):
		return SequenceEventType.CUSTOM_EVENT
	
	var event_type = event.event_data["sequence_event_type"]
	if event_type is int and event_type >= 0 and event_type <= SequenceEventType.CUSTOM_EVENT:
		return event_type
	
	return SequenceEventType.CUSTOM_EVENT

func _update_performance_stats(event_name: String, success: bool) -> void:
	"""更新性能统计"""
	if not _performance_stats.has(event_name):
		_performance_stats[event_name] = {
			"handled_count": 0,
			"failed_count": 0,
			"last_handled_time": 0.0
		}
	
	var stats = _performance_stats[event_name]
	if success:
		stats.handled_count += 1
	else:
		stats.failed_count += 1
	stats.last_handled_time = Time.get_ticks_msec() / 1000.0

func get_sequence_performance_stats() -> Dictionary:
	"""获取序列事件处理性能统计"""
	var total_handled = 0
	var total_failed = 0
	var event_stats = {}
	
	for event_name in _performance_stats.keys():
		var stats = _performance_stats[event_name]
		total_handled += stats.handled_count
		total_failed += stats.failed_count
		event_stats[event_name] = {
			"handled": stats.handled_count,
			"failed": stats.failed_count,
			"success_rate": float(stats.handled_count) / max(stats.handled_count + stats.failed_count, 1)
		}
	
	return {
		"total_events_handled": total_handled,
		"total_events_failed": total_failed,
		"overall_success_rate": float(total_handled) / max(total_handled + total_failed, 1),
		"event_stats": event_stats,
		"target_event": target_event_name,
		"context_id": sequence_context_id
	}

func _reset_performance_stats() -> void:
	"""重置性能统计"""
	_performance_stats.clear()
