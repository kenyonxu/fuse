@tool
class_name MusicLayerResource
extends Resource

## 音乐层资源
##
## 用于叠加的音乐层（如战斗强度层）

# =============================================================================
# 层定义
# =============================================================================

@export var layer_name: String = "Layer1"
@export var layer_stream: AudioStream

# =============================================================================
# 总线配置
# =============================================================================

@export_group("Audio Bus", "bus_")
@export var layer_bus_index: int = 0  # Music_Layer1, Music_Layer2, ...

# =============================================================================
# 音量控制
# =============================================================================

@export_group("Volume", "volume_")
@export_range(-60.0, 0.0, 0.1) var default_volume: float = -10.0  # dB
@export_range(0.0, 10.0, 0.1) var fade_in_time: float = 1.0
@export_range(0.0, 10.0, 0.1) var fade_out_time: float = 1.0

# =============================================================================
# 触发条件（可扩展）
# =============================================================================

@export_group("Trigger", "trigger_")
@export var trigger_tag: String = ""  # 例如 "combat_heavy"

# =============================================================================
# 公共方法
# =============================================================================

## 验证配置
func validate() -> Dictionary:
	var issues: Array[String] = []
	var warnings: Array[String] = []

	if not layer_stream:
		issues.append("需要 layer_stream")

	if layer_bus_index < 0:
		issues.append("layer_bus_index 不能为负数")

	return {
		"valid": issues.is_empty(),
		"issues": issues,
		"warnings": warnings
	}
