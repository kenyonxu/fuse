@tool
class_name StateSnapshot
extends RefCounted

# 快照数据
var target_id: int
var property_values: Dictionary = {}
var timestamp: float
var context_id: String = ""
var is_restorable: bool = true
var version: int = 1
var metadata: Dictionary = {}
var children_snapshots: Array[StateSnapshot] = []

# 还原配置
var restoration_mode: JuicyMixerEnums.RestorationMode = JuicyMixerEnums.RestorationMode.SNAP
var restoration_duration: float = 0.2  # 平滑还原持续时间
var restoration_curve: Curve  # 自定义还原曲线
var ease_type: Tween.EaseType = Tween.EaseType.EASE_OUT  # 缓动类型
var trans_type: Tween.TransitionType = Tween.TRANS_CUBIC  # 过渡类型

func _init(target: Node = null):
	if target:
		target_id = target.get_instance_id()
		timestamp = Time.get_ticks_msec() / 1000.0

func add_child_snapshot(child_snapshot: StateSnapshot) -> void:
	children_snapshots.append(child_snapshot)

func remove_child_snapshot(child_snapshot: StateSnapshot) -> void:
	children_snapshots.erase(child_snapshot)

func get_child_snapshot_count() -> int:
	return children_snapshots.size()

func is_expired(max_age: float = 60.0) -> bool:
	var current_time = Time.get_ticks_msec() / 1000.0
	return current_time - timestamp > max_age

func get_age() -> float:
	var current_time = Time.get_ticks_msec() / 1000.0
	return current_time - timestamp

func set_property(property_name: String, value: Variant) -> void:
	property_values[property_name] = value

func get_property(property_name: String) -> Variant:
	return property_values.get(property_name, null)

func has_property(property_name: String) -> bool:
	return property_name in property_values

func clear_property(property_name: String) -> void:
	property_values.erase(property_name)

func clear_all_properties() -> void:
	property_values.clear()

func get_property_count() -> int:
	return property_values.size()

func add_metadata(key: String, value: Variant) -> void:
	metadata[key] = value

func get_metadata(key: String) -> Variant:
	return metadata.get(key, null)

func has_metadata(key: String) -> bool:
	return key in metadata

func clear_metadata(key: String) -> void:
	metadata.erase(key)

func clear_all_metadata() -> void:
	metadata.clear()

func get_metadata_count() -> int:
	return metadata.size()

func clone() -> StateSnapshot:
	var new_snapshot = StateSnapshot.new()
	new_snapshot.target_id = target_id
	new_snapshot.property_values = property_values.duplicate()
	new_snapshot.timestamp = timestamp
	new_snapshot.context_id = context_id
	new_snapshot.is_restorable = is_restorable
	new_snapshot.version = version
	new_snapshot.metadata = metadata.duplicate()
	new_snapshot.restoration_mode = restoration_mode
	new_snapshot.restoration_duration = restoration_duration
	new_snapshot.restoration_curve = restoration_curve
	new_snapshot.ease_type = ease_type
	new_snapshot.trans_type = trans_type
	
	# 克隆子快照
	for child_snapshot in children_snapshots:
		new_snapshot.add_child_snapshot(child_snapshot.clone())
	
	return new_snapshot

func to_string() -> String:
	return "StateSnapshot[target_id=%d, context_id=%s, properties=%d, children=%d]" % [
		target_id, context_id, property_values.size(), children_snapshots.size()
	]