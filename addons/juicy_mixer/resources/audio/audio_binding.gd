@tool
class_name AudioBinding
extends Resource

## 音频绑定资源
##
## 将信号映射到音频事件,支持冷却、延迟和音量覆盖等高级选项

# =============================================================================
# 基础配置
# =============================================================================

## 要监听的信号名称
@export var signal_name: String = ""

## 要播放的音频事件资源
@export var audio_event: AudioEventResource

# =============================================================================
# 高级配置
# =============================================================================

@export_group("Advanced", "adv_")

## 冷却时间(秒),防止同一音频频繁播放
@export var adv_cooldown: float = 0.0

## 播放延迟(秒)
@export var adv_delay: float = 0.0

## 音量覆盖(0.0表示不覆盖)
@export_range(0.0, 2.0, 0.01) var adv_volume_override: float = 0.0

# =============================================================================
# 运行时状态(不序列化)
# =============================================================================

var _last_play_time: float = -9999.0

# =============================================================================
# 冷却控制
# =============================================================================

## 检查是否可以播放(考虑冷却时间)
func can_play() -> bool:
	# 如果没有设置冷却时间,总是可以播放
	if adv_cooldown <= 0.0:
		return true

	var current_time = Time.get_ticks_msec() / 1000.0
	return (current_time - _last_play_time) >= adv_cooldown

## 标记音频已播放
func mark_played() -> void:
	_last_play_time = Time.get_ticks_msec() / 1000.0

## 重置冷却计时器
func reset_cooldown() -> void:
	_last_play_time = -9999.0

# =============================================================================
# 序列化支持
# =============================================================================

## 获取配置字典(用于保存)
func get_config_dict() -> Dictionary:
	return {
		"signal_name": signal_name,
		"audio_event": audio_event,
		"adv_cooldown": adv_cooldown,
		"adv_delay": adv_delay,
		"adv_volume_override": adv_volume_override
	}

## 从配置字典加载
func load_from_dict(config_dict: Dictionary) -> bool:
	if not config_dict.has("signal_name"):
		return false

	signal_name = config_dict.signal_name
	audio_event = config_dict.get("audio_event", null)
	adv_cooldown = config_dict.get("adv_cooldown", 0.0)
	adv_delay = config_dict.get("adv_delay", 0.0)
	adv_volume_override = config_dict.get("adv_volume_override", 0.0)

	return true

# =============================================================================
# 验证
# =============================================================================

## 验证绑定配置是否有效
func validate() -> Dictionary:
	var result = {
		"valid": true,
		"issues": [],
		"warnings": []
	}

	if signal_name.is_empty():
		result.issues.append("Signal name is empty")
		result.valid = false

	if not audio_event:
		result.issues.append("Audio event is not assigned")
		result.valid = false

	if adv_cooldown < 0.0:
		result.warnings.append("Negative cooldown has no effect")

	if adv_delay < 0.0:
		result.warnings.append("Negative delay has no effect")

	return result
