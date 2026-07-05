# JuicyEventResource - 事件配置资源
# 作为 JuicyEvent 的可序列化配置，用于编辑器中的 @export 和保存
# 运行时转换为 JuicyEvent 实例

@tool
class_name JuicyEventResource
extends Resource

# 事件类型
@export var event_type: int = 0  # JuicyEvent.EventType

# 事件标识
@export var event_id: String = ""
@export var event_name: String = ""

# 目标路径（运行时解析）
@export var target_path: NodePath = NodePath("")

# 优先级和延迟
@export var priority: int = 0
@export var delay: float = 0.0

# 事件数据（所有自定义配置存储在这里）
@export var event_data: Dictionary = {}

# 创建 JuicyEvent 实例
func create_event(target: Node = null) -> JuicyEvent:
	var event = JuicyEvent.new(event_type)
	
	event.event_id = event_id
	event.event_name = event_name
	
	if target:
		event.target = target
	elif not target_path.is_empty():
		event.target_path = target_path
	
	event.priority = priority
	event.delay = delay
	
	for key in event_data:
		event.event_data[key] = event_data[key]
	
	return event

# 从 JuicyEvent 创建资源
static func from_event(event: JuicyEvent) -> JuicyEventResource:
	var resource = JuicyEventResource.new()
	
	resource.event_type = event.event_type
	resource.event_id = event.event_id
	resource.event_name = event.event_name
	resource.priority = event.priority
	resource.delay = event.delay
	resource.event_data = event.event_data.duplicate()
	
	if event.has_property("target_path"):
		resource.target_path = event.target_path
	
	return resource

# 验证配置
func validate() -> Dictionary:
	var result = {
		"valid": true,
		"issues": [],
		"warnings": []
	}
	
	if event_name.is_empty():
		result.issues.append("Event name cannot be empty")
		result.valid = false
	
	return result
