@tool
class_name AudioRandomizationConfig
extends Resource

## 全局音频随机化配置
##
## 应用于所有变体的全局随机化参数

# =============================================================================
# 全局随机化设置
# =============================================================================

## 是否启用随机化
@export var enabled: bool = true

# =============================================================================
# 全局音高随机化
# =============================================================================

@export_group("Global Pitch", "global_pitch_")

## 全局最小音高偏移（半音）
@export_range(-12.0, 12.0, 0.1) var global_pitch_min: float = -0.2

## 全局最大音高偏移（半音）
@export_range(-12.0, 12.0, 0.1) var global_pitch_max: float = 0.2

# =============================================================================
# 全局音量随机化
# =============================================================================

@export_group("Global Volume", "global_volume_")

## 全局最小音量倍数
@export_range(0.5, 1.5, 0.05) var global_volume_min: float = 0.95

## 全局最大音量倍数
@export_range(0.5, 1.5, 0.05) var global_volume_max: float = 1.05

# =============================================================================
# 高级设置
# =============================================================================

@export_group("Advanced", "advanced_")

## 随机种子（0 = 使用当前时间）
@export var random_seed: int = 0

## 是否使用固定种子
@export var use_fixed_seed: bool = false

# =============================================================================
# 私有变量
# =============================================================================

var _rng: RandomNumberGenerator = null

# =============================================================================
# 公共方法
# =============================================================================

## 初始化随机数生成器
func initialize_random() -> void:
    _rng = RandomNumberGenerator.new()

    if use_fixed_seed and random_seed != 0:
        _rng.seed = random_seed
    else:
        _rng.randomize()

## 获取全局音高偏移（半音）
func get_global_pitch_offset() -> float:
    if not enabled:
        return 0.0

    if _rng == null:
        initialize_random()

    # 检查边界条件
    if global_pitch_min > global_pitch_max:
        push_warning("AudioRandomizationConfig: global_pitch_min (%s) cannot be greater than global_pitch_max (%s). Using default 0.0" % [global_pitch_min, global_pitch_max])
        return 0.0

    return _rng.randf_range(global_pitch_min, global_pitch_max)

## 获取全局音量偏移（倍数）
func get_global_volume_offset() -> float:
    if not enabled:
        return 1.0

    if _rng == null:
        initialize_random()

    # 检查边界条件
    if global_volume_min > global_volume_max:
        push_warning("AudioRandomizationConfig: global_volume_min (%s) cannot be greater than global_volume_max (%s). Using default 1.0" % [global_volume_min, global_volume_max])
        return 1.0

    return _rng.randf_range(global_volume_min, global_volume_max)

## 验证配置
func validate() -> Dictionary:
    var result = {
        "valid": true,
        "issues": [],
        "warnings": []
    }

    # 检查音高范围
    if global_pitch_min > global_pitch_max:
        result.issues.append("global_pitch_min cannot be greater than global_pitch_max")
        result.valid = false

    # 检查音量范围
    if global_volume_min > global_volume_max:
        result.issues.append("global_volume_min cannot be greater than global_volume_max")
        result.valid = false

    # 检查random_seed是否为负数
    if random_seed < 0 and use_fixed_seed:
        result.issues.append("random_seed cannot be negative when use_fixed_seed is true")
        result.valid = false

    return result