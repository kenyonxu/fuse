@tool
class_name RestorationConfig
extends Resource

# 基础配置
@export var auto_snapshot: bool = true
@export var snapshot_frequency: float = 0.1  # 秒
@export var max_snapshots_per_target: int = 10
@export var emergency_restoration_enabled: bool = true

# 属性过滤
@export var property_blacklist: Array[String] = []
@export var property_whitelist: Array[String] = []

# 还原配置
@export var default_restoration_mode: JuicyMixerEnums.RestorationMode = JuicyMixerEnums.RestorationMode.EASE
@export var validate_restoration: bool = true  # 是否验证还原结果
@export var hierarchy_snapshot: bool = true  # 是否捕获Context层次结构

# 还原行为配置
@export var blocking_mode: bool = false  # 是否使用阻塞模式（true=阻塞等待完成，false=非阻塞后台执行）

# 还原参数（可在编辑器中调整）
@export var default_restoration_duration: float = 0.2
@export var default_ease_type: Tween.EaseType = Tween.EASE_OUT
@export var default_trans_type: Tween.TransitionType = Tween.TRANS_CUBIC
@export var default_restoration_curve: Curve

func _init():
	# 创建默认还原曲线
	if not default_restoration_curve:
		default_restoration_curve = Curve.new()
		default_restoration_curve.add_point(Vector2(0.0, 0.0))
		default_restoration_curve.add_point(Vector2(1.0, 1.0))

func add_property_to_blacklist(property_name: String) -> void:
	if property_name not in property_blacklist:
		property_blacklist.append(property_name)

func remove_property_from_blacklist(property_name: String) -> void:
	property_blacklist.erase(property_name)

func clear_property_blacklist() -> void:
	property_blacklist.clear()

func is_property_blacklisted(property_name: String) -> bool:
	return property_name in property_blacklist

func add_property_to_whitelist(property_name: String) -> void:
	if property_name not in property_whitelist:
		property_whitelist.append(property_name)

func remove_property_from_whitelist(property_name: String) -> void:
	property_whitelist.erase(property_name)

func clear_property_whitelist() -> void:
	property_whitelist.clear()

func is_property_whitelisted(property_name: String) -> bool:
	return property_name in property_whitelist

func should_capture_property(property_name: String) -> bool:
	# 检查白名单
	if property_whitelist.size() > 0:
		return property_name in property_whitelist
	
	# 检查黑名单
	if property_blacklist.size() > 0:
		return not (property_name in property_blacklist)
	
	return true

func set_default_restoration_curve(curve: Curve) -> void:
	default_restoration_curve = curve

func get_default_restoration_curve() -> Curve:
	return default_restoration_curve

func duplicate(subresources: bool = false) -> Resource:
	var new_config = RestorationConfig.new()
	new_config.auto_snapshot = auto_snapshot
	new_config.snapshot_frequency = snapshot_frequency
	new_config.max_snapshots_per_target = max_snapshots_per_target
	new_config.emergency_restoration_enabled = emergency_restoration_enabled
	new_config.property_blacklist = property_blacklist.duplicate()
	new_config.property_whitelist = property_whitelist.duplicate()
	new_config.default_restoration_mode = default_restoration_mode
	new_config.validate_restoration = validate_restoration
	new_config.hierarchy_snapshot = hierarchy_snapshot
	new_config.blocking_mode = blocking_mode
	new_config.default_restoration_duration = default_restoration_duration
	new_config.default_ease_type = default_ease_type
	new_config.default_trans_type = default_trans_type
	new_config.default_restoration_curve = default_restoration_curve
	
	return new_config

func _to_string() -> String:
	return "RestorationConfig[auto=%s, mode=%d, blacklist=%d, whitelist=%d]" % [
		auto_snapshot, default_restoration_mode, property_blacklist.size(), property_whitelist.size()
	]