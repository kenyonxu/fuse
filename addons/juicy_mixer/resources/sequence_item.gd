# JuicySequenceItem - 序列化项数据结构
# 定义序列中单个效果项的配置，支持时间和事件触发模式

@tool
class_name JuicySequenceItem
extends Resource

# 触发模式枚举
enum TriggerMode {
	TIME,               # 基于时间延迟
	EVENT               # 等待特定事件
}

# 基础配置
@export var resource: JuicyFeedbackResource
@export var delay: float = 0.0
@export var duration: float = -1.0  # -1表示使用资源默认持续时间
@export var condition: String = ""   # 可选的执行条件
@export var weight: float = 1.0       # 用于随机选择
@export var enabled: bool = true

# 事件同步配置
@export var trigger_mode: TriggerMode = TriggerMode.TIME
@export var trigger_event: String = ""           # 等待的事件名称（如"audio_beat_1", "explosion_peak"等）

# 验证配置
func validate() -> Array[String]:
	var issues: Array[String] = []
	
	if not resource:
		issues.append("Resource cannot be null")
	
	if duration < -1.0:
		issues.append("Duration cannot be less than -1")
	
	if weight < 0.0:
		issues.append("Weight cannot be negative")
	
	# 验证事件同步配置
	if trigger_mode == TriggerMode.EVENT and trigger_event.is_empty():
		issues.append("Trigger event cannot be empty when trigger_mode is EVENT")
	
	return issues

# 获取验证结果
func is_valid() -> bool:
	return validate().is_empty()

# 获取配置摘要
func get_summary() -> String:
	var summary = "JuicySequenceItem("
	if resource:
		summary += "resource=" + resource.get_resource_type()
	else:
		summary += "resource=null"
	
	summary += ", delay=" + str(delay)
	summary += ", duration=" + str(duration)
	summary += ", weight=" + str(weight)
	summary += ", enabled=" + str(enabled)
	summary += ", trigger_mode=" + TriggerMode.keys()[trigger_mode]
	
	if trigger_mode == TriggerMode.EVENT:
		summary += ", trigger_event='" + trigger_event + "'"
	
	summary += ")"
	return summary