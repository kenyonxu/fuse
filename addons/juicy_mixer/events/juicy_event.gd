# JuicyEvent - 事件数据结构
# 独立的事件类，用于在JuicyMixer系统中传递事件信息
# 提供类型安全的事件创建和访问方法

class_name JuicyEvent
extends RefCounted

# 事件类型定义
enum EventType {
	AUDIO_PLAY,        # 音频播放
	AUDIO_STOP,        # 音频停止
	PARTICLE_SPAWN,    # 粒子生成
	PARTICLE_STOP,      # 粒子停止
	UI_UPDATE,         # UI更新
	SCREEN_SHAKE,      # 屏幕震动
	VIBRATION,         # 手柄震动
	INTERRUPTION_OCCURRED,     # 中断发生
	INTERRUPTION_RESOLVED,     # 中断解决
	TRANSITION_STARTED,        # 过渡开始
	TRANSITION_COMPLETED,      # 过渡完成
	CUSTOM_EVENT       # 自定义事件
}

# 事件属性
var event_id: String = ""
var event_name: String = ""
var event_type: EventType
var context_id: String = ""
var target: Node
var target_path: NodePath = NodePath("")
var event_data: Dictionary = {}
var priority: int = 0
var timestamp: float = 0.0
var delay: float = 0.0
var is_processed: bool = false
var is_persistent: bool = false

# 构造函数
func _init(type: EventType = EventType.CUSTOM_EVENT):
	event_type = type
	timestamp = Time.get_ticks_msec() / 1000.0

# 静态工厂方法
static func create_audio_play_event(name: String, target: Node, audio_stream: AudioStream, 
								position: Vector2 = Vector2.ZERO, volume: float = 1.0) -> JuicyEvent:
	var event = JuicyEvent.new(EventType.AUDIO_PLAY)
	event.event_name = name
	event.target = target
	event.event_data = {
		"audio_stream": audio_stream,
		"position": position,
		"volume": volume
	}
	return event

static func create_particle_spawn_event(name: String, target: Node, particle_scene: PackedScene,
								   amount: int = 10, position: Vector2 = Vector2.ZERO) -> JuicyEvent:
	var event = JuicyEvent.new(EventType.PARTICLE_SPAWN)
	event.event_name = name
	event.target = target
	event.event_data = {
		"particle_scene": particle_scene,
		"amount": amount,
		"position": position
	}
	return event

static func create_ui_update_event(name: String, target: Node, property: String, value: Variant) -> JuicyEvent:
	var event = JuicyEvent.new(EventType.UI_UPDATE)
	event.event_name = name
	event.target = target
	event.event_data = {
		"property": property,
		"value": value
	}
	return event

static func create_screen_shake_event(name: String, target: Node, intensity: float = 1.0, 
									duration: float = 0.5) -> JuicyEvent:
	var event = JuicyEvent.new(EventType.SCREEN_SHAKE)
	event.event_name = name
	event.target = target
	event.event_data = {
		"intensity": intensity,
		"duration": duration
	}
	return event

static func create_vibration_event(name: String, target: Node, intensity: float = 1.0, 
								duration: float = 0.5) -> JuicyEvent:
	var event = JuicyEvent.new(EventType.VIBRATION)
	event.event_name = name
	event.target = target
	event.event_data = {
		"intensity": intensity,
		"duration": duration
	}
	return event

static func create_interruption_event(name: String, target: Node, interruption_type: String,
								new_context_id: String, existing_context_id: String,
								policy: JuicyMixerEnums.InterruptionPolicy) -> JuicyEvent:
	"""创建中断事件"""
	var event = JuicyEvent.new(EventType.INTERRUPTION_OCCURRED)
	event.event_name = name
	event.target = target
	event.event_data = {
		"interruption_type": interruption_type,
		"new_context_id": new_context_id,
		"existing_context_id": existing_context_id,
		"policy": JuicyMixerEnums.get_interruption_policy_name(policy),
		"policy_enum": policy,
		"timestamp": Time.get_ticks_msec() / 1000.0
	}
	return event

static func create_interruption_resolved_event(name: String, target: Node, context_id: String,
									  resolution_type: String) -> JuicyEvent:
	"""创建中断解决事件"""
	var event = JuicyEvent.new(EventType.INTERRUPTION_RESOLVED)
	event.event_name = name
	event.target = target
	event.event_data = {
		"context_id": context_id,
		"resolution_type": resolution_type,
		"timestamp": Time.get_ticks_msec() / 1000.0
	}
	return event

static func create_transition_event(name: String, target: Node, transition_type: String,
							 context_id: String, from_context_id: String = "",
							 duration: float = 0.0) -> JuicyEvent:
	"""创建过渡事件"""
	var event_type = EventType.TRANSITION_STARTED if transition_type == "started" else EventType.TRANSITION_COMPLETED
	var event = JuicyEvent.new(event_type)
	event.event_name = name
	event.target = target
	event.event_data = {
		"transition_type": transition_type,
		"context_id": context_id,
		"from_context_id": from_context_id,
		"duration": duration,
		"timestamp": Time.get_ticks_msec() / 1000.0
	}
	return event

static func create_custom_event(name: String, target: Node, custom_data: Dictionary) -> JuicyEvent:
	var event = JuicyEvent.new(EventType.CUSTOM_EVENT)
	event.event_name = name
	event.target = target
	event.event_data = custom_data
	return event

static func from_resource(resource: JuicyEventResource, target: Node = null) -> JuicyEvent:
	return resource.create_event(target)

# 实用方法
func set_context_id(id: String) -> void:
	context_id = id

func get_context_id() -> String:
	return context_id

func get_event_type() -> EventType:
	return event_type

func get_target() ->Node:
	return target

func is_valid() -> bool:
	return event_type >= 0 and event_type < EventType.CUSTOM_EVENT + 1 and target != null

func to_string() -> String:
	return "JuicyEvent[type=" + str(event_type) + ", target=" + str(target) + \
		   ", context_id=" + context_id + ", priority=" + str(priority) + "]"