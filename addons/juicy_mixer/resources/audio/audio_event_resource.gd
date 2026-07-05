@tool
class_name AudioEventResource
extends JuicyEventResource

## 音频事件资源
##
## 定义音频播放的所有配置，继承自JuicyEventResource
## 音频特有的配置通过额外属性和event_data存储

# =============================================================================
# 音频特定配置
# =============================================================================

enum AudioPlayerType {
	AUTO_DETECT,
	PLAYER_2D,
	PLAYER_3D
}

@export var player_type: AudioPlayerType = AudioPlayerType.AUTO_DETECT
@export var audio_bus: String = "Master"
@export var max_distance: float = 100.0
@export var max_distance_db: float = -80.0

# =============================================================================
# 初始化
# =============================================================================

func _init():
	# 设置事件类型为音频播放
	event_type = JuicyEvent.EventType.AUDIO_PLAY

# =============================================================================
# 变体配置
# =============================================================================

@export var audio_variants: Array[AudioVariant] = []
@export var randomization: AudioRandomizationConfig = null
@export var no_repeat_enabled: bool = true
@export var no_repeat_memory: int = 3

# =============================================================================
# 类别配置
# =============================================================================

@export_group("Categories", "category_")
@export var categories: Array[AudioCategory] = []

## 类别级优先级覆盖（覆盖类别默认值）
@export_range(0, 100) var category_priority_override: int = 50

# =============================================================================
# 混音配置
# =============================================================================

@export var mixing: AudioMixingConfig = null

# =============================================================================
# 虚声部配置
# =============================================================================

@export_group("Virtual Voice", "virtual_")
@export var virtual_voice_enabled: bool = true
@export var virtual_max_distance: float = 50.0
@export var virtual_min_importance: int = 30

# =============================================================================
# 相位保护配置
# =============================================================================

@export_group("Phase Protection", "phase_")
@export var anti_phase_cancellation: bool = false
@export_range(0.001, 1.0, 0.001) var phase_cooldown: float = 0.05

# 运行时状态（不导出）
var _last_play_time: float = 0.0

# =============================================================================
# 公共方法
# =============================================================================

## 创建音频播放事件
func create_audio_play_event(target: Node) -> JuicyEvent:
	# 使用父类的event_name，或使用默认值
	var name = event_name if not event_name.is_empty() else "audio_play"

	# 创建基础事件（利用父类的方法）
	var event = JuicyEvent.new(JuicyEvent.EventType.AUDIO_PLAY)
	event.event_name = name

	if target:
		event.target = target

	# 将音频特有配置存储到event_data
	event.event_data["audio_event_resource"] = self
	event.event_data["player_type"] = player_type
	event.event_data["audio_bus"] = audio_bus
	event.event_data["max_distance"] = max_distance
	event.event_data["max_distance_db"] = max_distance_db

	return event

## 重写父类的create_event方法，提供更便捷的接口
func create_event(target: Node = null) -> JuicyEvent:
	return create_audio_play_event(target)

func validate() -> Dictionary:
	var result = {
		"valid": true,
		"issues": [],
		"warnings": []
	}

	if audio_variants.is_empty():
		result.issues.append("No audio variants defined")
		result.valid = false

	# 验证类别
	for i in range(categories.size()):
		var category = categories[i]
		if not category:
			result.warnings.append("Category at index %d is null" % i)
		else:
			var category_validation = category.validate()
			if not category_validation.valid:
				result.issues.append("Category at index %d: %s" % [i, category_validation.issues.join(", ")])
				result.valid = false

	# 验证虚声部配置
	if virtual_voice_enabled:
		if virtual_max_distance <= 0.0:
			result.warnings.append("virtual_max_distance should be positive")

		if virtual_min_importance < 0 or virtual_min_importance > 100:
			result.warnings.append("virtual_min_importance should be between 0 and 100")

	return result

func get_total_weight() -> float:
	var total = 0.0
	for variant in audio_variants:
		if variant:
			total += variant.weight
	return total

## 获取实际优先级（考虑类别和覆盖）
func get_effective_priority() -> int:
	"""获取实际优先级（考虑类别和覆盖）"""
	if categories.is_empty():
		return category_priority_override

	# 取所有类别中的最高优先级
	var highest_priority = 0
	for category in categories:
		if not category:
			continue
		var category_base = _category_priority_to_int(category.category_priority)
		highest_priority = max(highest_priority, category_base)

	return max(highest_priority, category_priority_override)

func _category_priority_to_int(priority: AudioCategory.AudioCategoryPriority) -> int:
	match priority:
		AudioCategory.AudioCategoryPriority.CRITICAL: return 90
		AudioCategory.AudioCategoryPriority.HIGH: return 70
		AudioCategory.AudioCategoryPriority.MEDIUM: return 50
		AudioCategory.AudioCategoryPriority.LOW: return 30
		AudioCategory.AudioCategoryPriority.VERY_LOW: return 10
		_: return 50