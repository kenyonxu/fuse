@tool
class_name MusicTrackResource
extends JuicyEventResource

## 音乐轨道资源
##
## 定义音乐播放的所有配置，包括 Intro-Loop 结构、过渡参数、总线配置等

## 音乐类型枚举
enum MusicType {
	STANDARD,      # 标准音乐（直接播放）
	INTRO_LOOP,    # Intro + Loop 结构
	LAYERED,       # 可叠加的音乐层
	TRANSITIONAL   # 过渡音乐
}

## 循环模式枚举
enum LoopMode {
	SEAMLESS,           # 无缝循环（使用 AudioStream.loop）
	CROSSFADE,          # 每次循环时交叉淡入淡出
	CROSSFADE_VARIANT   # 交叉淡入淡出到变体
}

## Loop 变体模式枚举
enum LoopVariantMode {
	NONE,        # 不使用变体
	RANDOM,      # 每次循环随机选择
	SEQUENTIAL   # 按顺序循环变体
}

## 中断模式枚举
enum InterruptionMode {
	STOP_AND_RESTART,      # 彻底停止，回来时重播
	PAUSE_AND_RESUME,      # 暂停并记录位置，回来继续
	KEEP_PLAYING_SILENTLY  # 继续播放但降低音量（ducking）
}

# =============================================================================
# 音乐类型配置
# =============================================================================

@export var music_type: MusicType = MusicType.INTRO_LOOP

# =============================================================================
# 音乐段定义
# =============================================================================

@export_group("Audio Streams", "stream_")
@export var intro_stream: AudioStream
@export var loop_stream: AudioStream:
	set(value):
		loop_stream = value
		_update_resource_name()

@export var loop_variants: Array[AudioStream] = []

# =============================================================================
# 过渡参数
# =============================================================================

@export_group("Transitions", "transition_")
@export_range(0.0, 10.0, 0.1) var intro_fade_out_time: float = 2.0
@export_range(0.0, 10.0, 0.1) var loop_fade_in_time: float = 2.0
@export_range(0.0, 10.0, 0.1) var transition_fade_time: float = 1.0

# =============================================================================
# 循环配置
# =============================================================================

@export_group("Loop Configuration", "loop_")
@export var loop_mode: LoopMode = LoopMode.SEAMLESS
@export var loop_variant_mode: LoopVariantMode = LoopVariantMode.NONE
@export_range(0.0, 1.0, 0.05) var loop_trigger_point: float = 0.95  ## 95% 处触发循环
@export_range(0.1, 5.0, 0.1) var loop_crossfade_time: float = 1.0

# =============================================================================
# 总线配置
# =============================================================================

@export_group("Audio Bus", "bus_")
@export var music_bus: StringName = &"Music"
@export var use_lpf_on_pause: bool = true

# =============================================================================
# 持久化配置
# =============================================================================

@export_group("Persistence", "persist_")
@export var persist_across_scenes: bool = true
@export var persistence_key: String = ""

# =============================================================================
# 中断配置
# =============================================================================

@export_group("Interruption", "interruption_")
@export var interruption_mode: InterruptionMode = InterruptionMode.STOP_AND_RESTART

## 中断时淡出时间（秒）
@export_range(0.0, 10.0, 0.1) var interruption_fade_out_time: float = 1.0

## 恢复时淡入时间（秒）
@export_range(0.0, 10.0, 0.1) var interruption_fade_in_time: float = 1.0

## Ducking 时的音量（dB），仅用于 KEEP_PLAYING_SILENTLY 模式
@export_range(-80.0, 0.0, 1.0) var ducked_volume_db: float = -60.0

# =============================================================================
# 初始化
# =============================================================================

func _init():
	# 音乐事件使用自定义事件类型
	event_type = JuicyEvent.EventType.CUSTOM_EVENT

# =============================================================================
# 公共方法
# =============================================================================

## 获取 Intro 时长
func get_intro_duration() -> float:
	if not intro_stream:
		return 0.0
	return intro_stream.get_length()

## 获取 Loop 时长
func get_loop_duration() -> float:
	if not loop_stream:
		return 0.0
	return loop_stream.get_length()

## 是否有 Loop 变体
func has_loop_variants() -> bool:
	return not loop_variants.is_empty()

## 获取随机 Loop 变体
func get_random_loop_variant() -> AudioStream:
	if not has_loop_variants():
		return loop_stream
	return loop_variants.pick_random()

## 验证配置
func validate() -> Dictionary:
	var issues: Array[String] = []
	var warnings: Array[String] = []

	# 检查音乐类型
	if music_type == MusicType.INTRO_LOOP:
		if not intro_stream:
			issues.append("INTRO_LOOP 类型需要 intro_stream")
		if not loop_stream and loop_variants.is_empty():
			issues.append("INTRO_LOOP 类型需要 loop_stream 或 loop_variants")
	elif music_type == MusicType.STANDARD:
		if not loop_stream:
			issues.append("STANDARD 类型需要 loop_stream")

	return {
		"valid": issues.is_empty(),
		"issues": issues,
		"warnings": warnings
	}

# =============================================================================
# 私有方法
# =============================================================================

func _update_resource_name():
	if loop_stream:
		resource_name = loop_stream.resource_path.get_file().get_basename()
	else:
		if loop_variants.size()> 0:
			resource_name = loop_variants[0].resource_path.get_file().get_basename()
