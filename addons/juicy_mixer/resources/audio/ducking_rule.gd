@tool
class_name DuckingRule
extends Resource

## 音频鸭霸规则
##
## 当特定事件播放时，自动降低目标总线的音量

# =============================================================================
# 鸭霸规则定义
# =============================================================================

## 事件名称模式（支持通配符 *）
@export var event_name_pattern: String = "*"

## 目标总线名称
@export var target_bus: String = "Music"

## 降低音量值（dB）
@export_range(0.0, -40.0, 0.1) var duck_amount: float = -10.0

## 恢复延迟（秒）
@export_range(0.0, 5.0, 0.1) var recovery_delay: float = 0.5

## 是否启用
@export var enabled: bool = true

# =============================================================================
# 私有变量
# =============================================================================

var _original_volume: float = 0.0
var _is_ducking: bool = false

# =============================================================================
# 公共方法
# =============================================================================

## 检查事件名称是否匹配模式
func matches(event_name: String) -> bool:
    if not enabled:
        return false

    # 精确匹配
    if event_name_pattern == event_name:
        return true

    # 通配符匹配
    if event_name_pattern.ends_with("*"):
        var prefix = event_name_pattern.substr(0, event_name_pattern.length() - 1)
        return event_name.begins_with(prefix)

    # 全匹配
    if event_name_pattern == "*":
        return true

    return false

## 应用鸭霸到总线
func apply_ducking(bus_index: int) -> void:
    # 总线索引验证
    if bus_index < 0 or bus_index >= AudioServer.get_bus_count():
        push_error("Invalid bus index: %d" % bus_index)
        return

    if not enabled:
        return

    var bus_name = AudioServer.get_bus_name(bus_index)
    if bus_name != target_bus:
        return

    # 保存原始音量
    _original_volume = AudioServer.get_bus_volume_db(bus_index)

    # 应用鸭霸，添加音量限制保护
    var final_volume = _original_volume + duck_amount
    # 防止音量过低
    final_volume = max(final_volume, -80.0)
    AudioServer.set_bus_volume_db(bus_index, final_volume)
    _is_ducking = true

## 移除鸭霸（恢复原始音量）
func remove_ducking(bus_index: int) -> void:
    # 总线索引验证
    if bus_index < 0 or bus_index >= AudioServer.get_bus_count():
        push_error("Invalid bus index: %d" % bus_index)
        return

    if not _is_ducking:
        return

    var bus_name = AudioServer.get_bus_name(bus_index)
    if bus_name != target_bus:
        return

    # 恢复原始音量
    AudioServer.set_bus_volume_db(bus_index, _original_volume)
    _is_ducking = false

## 验证配置
func validate() -> Dictionary:
    var result = {
        "valid": true,
        "issues": [],
        "warnings": []
    }

    if target_bus.is_empty():
        result.issues.append("target_bus cannot be empty")
        result.valid = false

    # 检查总线是否存在
    var bus_exists = false
    for i in range(AudioServer.get_bus_count()):
        if AudioServer.get_bus_name(i) == target_bus:
            bus_exists = true
            break

    if not bus_exists:
        result.warnings.append("Bus '%s' does not exist" % target_bus)

    if duck_amount > 0:
        result.warnings.append("duck_amount is usually negative (lowering volume)")

    return result