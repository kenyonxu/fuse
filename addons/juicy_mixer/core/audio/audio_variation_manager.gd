class_name AudioVariationManager
extends RefCounted

## 音频变体管理器
##
## 负责变体选择、随机化、防重复等逻辑

# =============================================================================
# 私有变量
# =============================================================================

var _no_repeat_history: Dictionary = {}  # event_name -> Array[last_played_indices]
var _randomization_config: AudioRandomizationConfig = null
var _rng: RandomNumberGenerator = null

# =============================================================================
# 初始化
# =============================================================================

func _init(randomization_config: AudioRandomizationConfig = null):
    _randomization_config = randomization_config
    _rng = RandomNumberGenerator.new()
    _rng.randomize()

# =============================================================================
# 变体选择
# =============================================================================

## 选择音频变体
func select_variant(resource: AudioEventResource) -> AudioVariant:
    if resource.audio_variants.is_empty():
        return null

    # 初始化随机数生成器
    if resource.randomization:
        resource.randomization.initialize_random()

    var available_variants = _get_available_variants(resource)
    if available_variants.is_empty():
        # 所有变体都被排除，回退到第一个
        return resource.audio_variants[0]

    # 计算总权重
    var total_weight = 0.0
    for variant_index in available_variants:
        total_weight += resource.audio_variants[variant_index].weight

    # 权重随机选择
    var random_value = _rng.randf() * total_weight
    var current_weight = 0.0

    for variant_index in available_variants:
        var variant = resource.audio_variants[variant_index]
        current_weight += variant.weight
        if random_value <= current_weight:
            # 更新历史
            _update_history(resource, variant_index)
            return variant

    # 回退到最后一个
    var last_index = available_variants[-1]
    _update_history(resource, last_index)
    return resource.audio_variants[last_index]

## 应用随机化
func apply_randomization(variant: AudioVariant, base_pitch: float = 1.0,
                         base_volume: float = 1.0, resource: AudioEventResource = null) -> Dictionary:
    var result = {
        "pitch": base_pitch,
        "volume": base_volume
    }

    # 变体级随机化
    if variant.pitch_enabled:
        var pitch_offset = variant.get_randomized_pitch()
        result.pitch = base_pitch * pitch_offset

    if variant.volume_enabled:
        var volume_mult = variant.get_randomized_volume()
        result.volume = base_volume * volume_mult

    # 全局随机化
    if resource and resource.randomization and resource.randomization.enabled:
        var global_pitch_offset = resource.randomization.get_global_pitch_offset()
        var global_pitch_scale = AudioUtils.get_pitch_scale_from_semitones(global_pitch_offset)
        result.pitch *= global_pitch_scale

        var global_volume_mult = resource.randomization.get_global_volume_offset()
        result.volume *= global_volume_mult

    return result

# =============================================================================
# 历史管理
# =============================================================================

## 清除事件历史
func clear_history(event_name: String) -> void:
    if _no_repeat_history.has(event_name):
        _no_repeat_history.erase(event_name)

## 清除所有历史
func clear_all_history() -> void:
    _no_repeat_history.clear()

# =============================================================================
# 私有方法
# =============================================================================

## 获取可用变体索引（考虑防重复）
func _get_available_variants(resource: AudioEventResource) -> Array:
    var indices = []
    for i in range(resource.audio_variants.size()):
        indices.append(i)

    # 如果未启用防重复，返回所有
    if not resource.no_repeat_enabled:
        return indices

    # 获取历史
    var event_name = resource.event_name if not resource.event_name.is_empty() else "default"
    var history = _no_repeat_history.get(event_name, [])

    # 排除最近播放的
    var available = []
    for i in indices:
        if i not in history:
            available.append(i)

    # 如果全部被排除，返回所有
    return available if not available.is_empty() else indices

## 更新播放历史
func _update_history(resource: AudioEventResource, variant_index: int) -> void:
    if not resource.no_repeat_enabled:
        return

    var event_name = resource.event_name if not resource.event_name.is_empty() else "default"

    if not _no_repeat_history.has(event_name):
        _no_repeat_history[event_name] = []

    var history = _no_repeat_history[event_name]
    history.append(variant_index)

    # 保持历史长度
    while history.size() > resource.no_repeat_memory:
        history.pop_front()