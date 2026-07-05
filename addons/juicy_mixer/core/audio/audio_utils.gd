class_name AudioUtils
extends RefCounted

## 音频工具类
##
## 提供静态工具方法用于音频单位转换、播放器创建等

# =============================================================================
# 常量
# =============================================================================

const DB_TO_LINEAR_RATIO: float = 20.0
const LOG_10: float = 2.3025850929940459

# =============================================================================
# 单位转换
# =============================================================================

## 线性值转分贝
static func linear_to_db(linear: float) -> float:
    if linear <= 0.0:
        return -80.0  # Godot的最小dB值
    return DB_TO_LINEAR_RATIO * log(linear)

## 分贝转线性值
static func db_to_linear(db: float) -> float:
    return exp(db / DB_TO_LINEAR_RATIO * LOG_10)

## 从半音获取音高缩放
static func get_pitch_scale_from_semitones(semitones: float) -> float:
    return pow(2.0, semitones / 12.0)

## 从音高缩放获取半音
static func get_semitones_from_pitch_scale(pitch_scale: float) -> float:
    return 12.0 * log(pitch_scale) / log(2.0)

# =============================================================================
# 播放器类型检测
# =============================================================================

## 自动检测播放器类型
enum AudioPlayerType {
    AUTO_DETECT,
    PLAYER_2D,
    PLAYER_3D
}

static func detect_player_type(target: Node) -> int:
    if target is Node3D:
        return AudioPlayerType.PLAYER_3D
    else:
        return AudioPlayerType.PLAYER_2D

# =============================================================================
# 播放器创建
# =============================================================================

## 创建2D播放器
static func create_player_2d() -> AudioStreamPlayer2D:
    var player = AudioStreamPlayer2D.new()
    return player

## 创建3D播放器
static func create_player_3d() -> AudioStreamPlayer3D:
    var player = AudioStreamPlayer3D.new()
    return player

# =============================================================================
# 播放器配置
# =============================================================================

## 应用音高和音量到播放器
static func apply_pitch_and_volume(player: Variant, pitch: float, volume: float) -> void:
    if player is AudioStreamPlayer:
        player.pitch_scale = pitch
        player.volume_db = linear_to_db(volume)
    elif player is AudioStreamPlayer2D:
        player.pitch_scale = pitch
        player.volume_db = linear_to_db(volume)
    elif player is AudioStreamPlayer3D:
        player.pitch_scale = pitch
        player.volume_db = linear_to_db(volume)

## 设置播放器总线
static func set_player_bus(player: Variant, bus_name: String) -> void:
    if player is AudioStreamPlayer:
        player.bus = bus_name
    elif player is AudioStreamPlayer2D:
        player.bus = bus_name
    elif player is AudioStreamPlayer3D:
        player.bus = bus_name

# =============================================================================
# 验证
# =============================================================================

## 验证音频流
static func validate_audio_stream(stream: AudioStream) -> bool:
    return stream != null and stream is AudioStream

## 获取音频时长
static func get_audio_duration(stream: AudioStream) -> float:
    if not validate_audio_stream(stream):
        return 0.0

    return stream.get_length()