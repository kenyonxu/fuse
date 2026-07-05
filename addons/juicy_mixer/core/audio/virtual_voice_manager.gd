class_name VirtualVoiceManager
extends RefCounted

## 虚声部管理器
##
## 管理虚声部（virtual voices）- 只计算时间不实际播放的音频
## 用于节省 CPU 资源，同时保持音频时间线的一致性

# =============================================================================
# 虚声部信息类
# =============================================================================

class VirtualVoiceInfo:
	extends RefCounted

	var instance_id: int
	var resource: AudioEventResource
	var start_time: float
	var duration: float
	var elapsed_time: float = 0.0
	var is_virtual: bool = true
	var position: Vector3

	func _init(res: AudioEventResource, pos: Vector3, force_virtual: bool):
		# I3: 添加 null 检查
		if not res:
			push_error("VirtualVoiceInfo: AudioEventResource cannot be null")
			duration = 1.0  # 设置默认时长
			return

		instance_id = randi()
		resource = res
		start_time = Time.get_ticks_msec() / 1000.0
		position = pos
		duration = _estimate_duration(res)
		is_virtual = force_virtual

	func _estimate_duration(res: AudioEventResource) -> float:
		"""估算音频时长

		V2 修复: 增强空值检查，处理 get_length() 返回 0 或负数的情况
		"""
		if not res or res.audio_variants.is_empty():
			return 1.0

		var valid_count = 0
		var total = 0.0

		for variant in res.audio_variants:
			# V2: 检查 variant 和 audio_stream 是否为 null
			if not variant or not variant.audio_stream:
				continue

			var length = variant.audio_stream.get_length()
			# V2: 处理 get_length() 返回 0 或负数的情况
			if length > 0.0:
				total += length
				valid_count += 1

		# V2: 使用有效计数而不是总计数
		return total / float(valid_count) if valid_count > 0 else 1.0

# =============================================================================
# 私有变量
# =============================================================================

var _virtual_voices: Dictionary = {}  # voice_id -> VirtualVoiceInfo
var _listener_position_cache: Vector3 = Vector3.ZERO  # I1: 监听器位置缓存
var _listener_cache_time: float = 0.0  # I1: 缓存时间戳
const LISTENER_CACHE_DURATION: float = 0.1  # I1: 缓存持续时间（秒）

# =============================================================================
# 虚声部检查
# =============================================================================

## 检查是否应该使用虚声部
func check_virtual_voice(resource: AudioEventResource, position: Vector3,
						importance: int, global_config: GlobalAudioLimitConfig) -> VirtualVoiceInfo:
	"""检查是否应该使用虚声部

	V1 修复: 增强边界检查，验证 global_config 的属性值
	"""

	# 基本验证
	if not resource or not global_config or not global_config.virtual_voice_enabled:
		return null

	# V1: 验证配置属性的有效性
	if global_config.virtual_max_distance <= 0.0:
		push_warning("VirtualVoiceManager: virtual_max_distance <= 0, using default 50.0")
		return null

	if global_config.virtual_min_importance < 0 or global_config.virtual_min_importance > 100:
		push_warning("VirtualVoiceManager: virtual_min_importance out of range [0, 100], using default 30")
		return null

	if global_config.max_total_voices <= 0:
		push_error("VirtualVoiceManager: max_total_voices <= 0")
		return null

	# 1. 检查距离
	var listener = _get_listener_position()
	var distance = listener.distance_to(position)

	if distance > global_config.virtual_max_distance:
		return _create_virtual_voice(resource, position, true, global_config)

	# 2. 检查重要性
	if importance < global_config.virtual_min_importance:
		return _create_virtual_voice(resource, position, true, global_config)

	# 3. 检查总声部数
	var total_real_voices = _get_total_real_voices()
	if total_real_voices >= global_config.max_total_voices:
		return _create_virtual_voice(resource, position, true, global_config)

	return null  # 不需要虚声部

## 创建虚声部
func _create_virtual_voice(resource: AudioEventResource, position: Vector3, force_virtual: bool,
						global_config: GlobalAudioLimitConfig) -> VirtualVoiceInfo:
	"""创建虚声部

	V3 修复: 添加 max_virtual_voices 限制检查
	"""

	# V3: 检查虚声部数量限制
	if global_config and _virtual_voices.size() >= global_config.max_virtual_voices:
		push_warning("VirtualVoiceManager: Max virtual voices reached (%d)" % global_config.max_virtual_voices)
		return null

	var info = VirtualVoiceInfo.new(resource, position, force_virtual)
	_virtual_voices[info.instance_id] = info
	return info

## 更新虚声部
func update_virtual_voices(delta: float) -> void:
	"""更新虚声部（每帧调用）"""
	var completed: Array = []

	for voice_id in _virtual_voices.keys():
		var info = _virtual_voices[voice_id]
		info.elapsed_time += delta

		if info.elapsed_time >= info.duration:
			completed.append(voice_id)

	for voice_id in completed:
		_virtual_voices.erase(voice_id)

# =============================================================================
# 统计
# =============================================================================

## 获取虚声部统计
func get_virtual_voice_stats() -> Dictionary:
	"""获取虚声部统计"""
	var total = _virtual_voices.size()
	var actually_virtual = 0

	for voice_id in _virtual_voices.keys():
		var info = _virtual_voices[voice_id]
		if info.is_virtual:
			actually_virtual += 1

	return {
		"total_virtual_voices": total,
		"actually_virtual": actually_virtual,
		"simulation_count": total - actually_virtual
	}

## 获取总真实声部数（简化实现）
func _get_total_real_voices() -> int:
	"""获取总真实声部数（从 AudioMixingController 获取）"""
	# TODO: 与 AudioMixingController 集成
	return 0

# =============================================================================
# 辅助方法
# =============================================================================

## 获取监听器位置
func _get_listener_position() -> Vector3:
	"""获取监听器位置

	I1 修复: 实现监听器位置缓存机制，避免每帧调用 find_children()
	"""
	var current_time = Time.get_ticks_msec() / 1000.0

	# 检查缓存是否有效
	if current_time - _listener_cache_time < LISTENER_CACHE_DURATION:
		return _listener_position_cache

	# 缓存过期，更新监听器位置
	var scene_root = Engine.get_main_loop().current_scene
	if not scene_root:
		_listener_position_cache = Vector3.ZERO
		_listener_cache_time = current_time
		return Vector3.ZERO

	var cameras = scene_root.find_children("*", "Camera3D", true, false)
	if cameras.size() > 0:
		_listener_position_cache = cameras[0].global_position
	else:
		_listener_position_cache = Vector3.ZERO

	_listener_cache_time = current_time
	return _listener_position_cache
