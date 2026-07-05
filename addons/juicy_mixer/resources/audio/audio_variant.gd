@tool
class_name AudioVariant
extends Resource

## 音频变体资源，用于随机化播放
##
## 支持音高、音量、循环等参数的独立配置

# =============================================================================
# 基础属性
# =============================================================================

## 音频流资源
@export var audio_stream: AudioStream = null

## 变体名称（用于调试）
@export var variant_name: String = ""

## 播放权重（越高越容易被选中）
@export_range(0.1, 10.0, 0.1) var weight: float = 1.0

# =============================================================================
# 音高随机化
# =============================================================================

@export_group("Pitch Randomization", "pitch_")

## 是否启用音高随机化
@export var pitch_enabled: bool = false

## 最小音高偏移（半音）
@export_range(-12.0, 12.0, 0.1) var pitch_min: float = -0.5

## 最大音高偏移（半音）
@export_range(-12.0, 12.0, 0.1) var pitch_max: float = 0.5

# =============================================================================
# 音量随机化
# =============================================================================

@export_group("Volume Randomization", "volume_")

## 是否启用音量随机化
@export var volume_enabled: bool = false

## 最小音量倍数
@export_range(0.0, 2.0, 0.05) var volume_min: float = 0.9

## 最大音量倍数
@export_range(0.0, 2.0, 0.05) var volume_max: float = 1.1

# =============================================================================
# 其他参数
# =============================================================================

@export_group("Other", "other_")

## 起始偏移时间（秒）
@export_range(0.0, 10.0, 0.1) var start_offset: float = 0.0

## 是否循环播放
@export var loop: bool = false

## 循环起始点（秒）
@export var loop_start: float = 0.0

## 循环结束点（秒）
@export var loop_end: float = 0.0

# =============================================================================
# 公共方法
# =============================================================================

## 获取随机化的音高缩放
func get_randomized_pitch() -> float:
    if not pitch_enabled:
        return 1.0

    var pitch_offset = randf_range(pitch_min, pitch_max)
    return AudioUtils.get_pitch_scale_from_semitones(pitch_offset) if ClassDB.class_exists("AudioUtils") else (1.0 + pitch_offset * 0.05)

## 获取随机化的音量倍数
func get_randomized_volume() -> float:
    if not volume_enabled:
        return 1.0

    return randf_range(volume_min, volume_max)

## 验证配置
func validate() -> Dictionary:
    var result = {
        "valid": true,
        "issues": [],
        "warnings": []
    }

    if audio_stream == null:
        result.warnings.append("audio_stream is null")

    if weight <= 0:
        result.issues.append("Weight must be positive")
        result.valid = false

    if pitch_enabled and pitch_min > pitch_max:
        result.issues.append("pitch_min cannot be greater than pitch_max")
        result.valid = false

    if volume_enabled and volume_min > volume_max:
        result.issues.append("volume_min cannot be greater than volume_max")
        result.valid = false

    if loop and loop_start >= loop_end:
        result.warnings.append("loop_start should be less than loop_end")

    return result