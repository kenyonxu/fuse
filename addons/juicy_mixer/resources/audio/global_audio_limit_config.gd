@tool
class_name GlobalAudioLimitConfig
extends Resource

## 全局音频限额配置
##
## 管理全局声部限制、虚声部系统、总线级限制和硬件监控

# =============================================================================
# 全局限额配置
# =============================================================================

@export_group("Global Voice Limits")

## 最大真实声部数
@export_range(1, 256, 1) var max_total_voices: int = 64

## 最大虚声部数
@export_range(1, 512, 1) var max_virtual_voices: int = 128

## 虚声部距离阈值（归一化）
@export_range(0.0, 1.0, 0.05) var virtual_voice_threshold: float = 0.3

# =============================================================================
# 虚声部配置
# =============================================================================

@export_group("Virtual Voices")

## 是否启用虚声部
@export var virtual_voice_enabled: bool = true

## 虚声部最大距离
@export_range(10.0, 200.0, 5.0) var virtual_max_distance: float = 50.0

## 虚声部最小重要性阈值
@export_range(0, 100, 5) var virtual_min_importance: int = 30

# =============================================================================
# 总线级别限制
# =============================================================================

@export_group("Bus Limits")

## 各总线播放限额
@export var bus_limits: Dictionary = {
	"Master": 64,
	"Music": 2,
	"SFX": 40,
	"Voice": 4
}

# =============================================================================
# 硬件监控
# =============================================================================

@export_group("Hardware Monitoring")

## 是否启用硬件监控
@export var enable_hardware_monitoring: bool = true

## CPU 使用率阈值 (%）
@export_range(50.0, 100.0, 5.0) var cpu_usage_threshold: float = 80.0

## 内存使用阈值 (MB)
@export_range(128.0, 2048.0, 64.0) var memory_usage_threshold: float = 512.0

# =============================================================================
# 公共方法
# =============================================================================

## 验证配置
func validate() -> Dictionary:
	var result = {
		"valid": true,
		"issues": [],
		"warnings": []
	}

	# 验证全局限额
	if max_total_voices <= 0:
		result.issues.append("max_total_voices must be positive")
		result.valid = false

	# 虚声部应该大于真实声部才能发挥效用
	if max_virtual_voices <= max_total_voices:
		result.issues.append("max_virtual_voices must be larger than max_total_voices for virtual voices to be effective")
		result.valid = false

	# 验证虚声部配置
	if virtual_voice_enabled:
		if virtual_max_distance <= 0.0:
			result.issues.append("virtual_max_distance must be positive when virtual voices are enabled")
			result.valid = false

		if virtual_min_importance < 0 or virtual_min_importance > 100:
			result.issues.append("virtual_min_importance must be between 0 and 100")
			result.valid = false

	# 验证总线限额
	for bus_name in bus_limits.keys():
		# 类型安全检查
		if not typeof(bus_limits[bus_name]) == TYPE_INT:
			result.issues.append("Bus '%s' limit must be an integer, got %s" % [bus_name, typeof(bus_limits[bus_name])])
			result.valid = false
			continue

		var limit: int = bus_limits[bus_name]
		if limit <= 0:
			result.issues.append("Bus '%s' has invalid limit: %d (must be positive)" % [bus_name, limit])
			result.valid = false

		# 检查总线是否存在
		var bus_exists = false
		for i in range(AudioServer.get_bus_count()):
			if AudioServer.get_bus_name(i) == bus_name:
				bus_exists = true
				break

		if not bus_exists:
			result.warnings.append("Bus '%s' does not exist in AudioServer" % bus_name)

	# 验证硬件监控阈值
	if enable_hardware_monitoring:
		if cpu_usage_threshold < 50.0 or cpu_usage_threshold > 100.0:
			result.issues.append("cpu_usage_threshold must be between 50.0 and 100.0")
			result.valid = false

		if memory_usage_threshold < 128.0 or memory_usage_threshold > 2048.0:
			result.issues.append("memory_usage_threshold must be between 128.0 and 2048.0")
			result.valid = false

	return result

## 克隆配置
func clone() -> GlobalAudioLimitConfig:
	var clone = GlobalAudioLimitConfig.new()
	clone.max_total_voices = max_total_voices
	clone.max_virtual_voices = max_virtual_voices
	clone.virtual_voice_threshold = virtual_voice_threshold
	clone.virtual_voice_enabled = virtual_voice_enabled
	clone.virtual_max_distance = virtual_max_distance
	clone.virtual_min_importance = virtual_min_importance
	clone.bus_limits = bus_limits.duplicate()
	clone.enable_hardware_monitoring = enable_hardware_monitoring
	clone.cpu_usage_threshold = cpu_usage_threshold
	clone.memory_usage_threshold = memory_usage_threshold
	return clone

## 获取总线限额
func get_bus_limit(bus_name: String) -> int:
	if bus_limits.has(bus_name):
		var limit = bus_limits[bus_name]
		# 类型安全检查
		if typeof(limit) == TYPE_INT:
			return limit
		else:
			push_error("Bus '%s' limit has invalid type: %s" % [bus_name, typeof(limit)])
			return max_total_voices
	return max_total_voices  # 默认返回全局限额

## 设置总线限额
func set_bus_limit(bus_name: String, limit: int) -> void:
	# 类型安全检查
	if typeof(limit) != TYPE_INT:
		push_error("Bus limit must be an integer, got: %s" % typeof(limit))
		return

	if limit <= 0:
		push_error("Bus limit must be positive, got: %d" % limit)
		return

	bus_limits[bus_name] = limit
