@tool
class_name AudioMixingConfig
extends Resource

## 音频混合配置
##
## 管理音频播放的实例限制和鸭霸规则
##
## 功能：
## - 播放实例限制：控制同类型音频的最大播放数量
## - 鸭霸规则：当特定事件播放时，自动降低目标总线音量
## - 优先级控制：基于优先级的播放管理
## - 淡入淡出控制：平滑的音量过渡

# =============================================================================
# 播放限制策略枚举
# =============================================================================

## 限制策略枚举（扩展为7种）
enum LimitPolicy {
    FIFO = 0,                  # First In First Out - 先进先出 (对应 STOP_OLDEST)
    LIFO = 1,                  # Last In First Out - 后进先出 (对应 STOP_NEWEST)
    PRIORITY = 2,              # 基于优先级 - 高优先级优先
    NEWEST_STEALS_OLDEST = 3,  # 新顶旧（推荐用于高频音效）
    FADE_OUT_OLDEST = 4,       # 淡出最老的（平滑过渡）
    FADE_IN_NEWEST = 5,        # 淡入新的（平滑过渡）
    CROSSFADE = 6              # 交叉淡入淡出（最平滑）
}

# =============================================================================
# 播放限制配置
# =============================================================================

## 最大播放实例数
@export var max_instances: int = 10

## 限制策略
@export var limit_policy: LimitPolicy = LimitPolicy.PRIORITY

## 优先级（值越高优先级越高）
@export_range(0, 10, 1) var priority: int = 1

# =============================================================================
# 鸭霸配置
# =============================================================================

## 鸭霸规则数组
@export var ducking_rules: Array[DuckingRule] = []

## 鸭霸淡入时间（秒）
@export_range(0.0, 2.0, 0.01) var ducking_fade_in: float = 0.1

## 鸭霸淡出时间（秒）
@export_range(0.0, 2.0, 0.01) var ducking_fade_out: float = 0.5

## 鸭霸目标总线名称
@export var ducking_bus: String = "Master"

# =============================================================================
# 私有变量
# =============================================================================

var _current_instances: int = 0
var _active_ducking: bool = false

# =============================================================================
# 公共方法
# =============================================================================

## 应用配置到音频播放器
func apply_to_player(player_node: Node) -> void:
    if player_node == null:
        push_error("AudioMixingConfig: Player node cannot be null")
        return

    # 验证配置
    var validation_result = validate()
    if not validation_result.valid:
        var error_msg = "AudioMixingConfig: Invalid configuration: %s" % validation_result.issues.join(", ")
        push_error(error_msg)
        return

    # 应用播放限制配置
    if not player_node.has_method("set_max_instances"):
        player_node.set("max_instances", max_instances)
    else:
        player_node.call_deferred("set_max_instances", max_instances)

    # 应用限制策略
    var policy_string = _get_policy_string(limit_policy)
    if not player_node.has_method("set_limit_policy"):
        player_node.set("limit_policy", policy_string)
    else:
        player_node.call_deferred("set_limit_policy", policy_string)

    # 应用优先级
    if not player_node.has_method("set_priority"):
        player_node.set("priority", priority)
    else:
        player_node.call_deferred("set_priority", priority)

    # 应用鸭霸配置
    if not player_node.has_method("set_ducking_config"):
        player_node.set("ducking_config", self)
    else:
        player_node.call_deferred("set_ducking_config", self)

## 获取指定事件的鸭霸规则
func get_ducking_rule_for_event(event_name: String) -> DuckingRule:
    for rule in ducking_rules:
        if rule.enabled and rule.matches(event_name):
            return rule
    return null

## 增加当前实例计数
func increment_instance_count() -> void:
    _current_instances += 1

## 减少当前实例计数
func decrement_instance_count() -> void:
    _current_instances = max(0, _current_instances - 1)

## 获取当前实例计数
func get_current_instance_count() -> int:
    return _current_instances

## 获取当前实例是否达到限制
func is_instance_limited() -> bool:
    return _current_instances >= max_instances

## 设置鸭霸状态
func set_ducking_active(active: bool) -> void:
    _active_ducking = active

## 获取鸭霸状态
func is_ducking_active() -> bool:
    return _active_ducking

## 获取限制策略字符串
func get_limit_policy_string() -> String:
    return _get_policy_string(limit_policy)

## 清除所有鸭霸规则
func clear_ducking_rules() -> void:
    ducking_rules.clear()
    _active_ducking = false

## 添加鸭霸规则
func add_ducking_rule(rule: DuckingRule) -> void:
    if rule != null:
        ducking_rules.append(rule)

## 移除鸭霸规则
func remove_ducking_rule(index: int) -> void:
    if index >= 0 and index < ducking_rules.size():
        ducking_rules.remove_at(index)

## 克隆配置
func clone() -> Resource:
    var clone = AudioMixingConfig.new()
    clone.max_instances = max_instances
    clone.limit_policy = limit_policy
    clone.priority = priority
    clone.ducking_rules = []
    clone.ducking_fade_in = ducking_fade_in
    clone.ducking_fade_out = ducking_fade_out
    clone.ducking_bus = ducking_bus

    # 深度复制鸭霸规则
    for rule in ducking_rules:
        clone.ducking_rules.append(rule.duplicate(true))

    return clone

## 获取配置字典（用于序列化）
func get_config_dict() -> Dictionary:
    return {
        "max_instances": max_instances,
        "limit_policy": limit_policy,
        "priority": priority,
        "ducking_fade_in": ducking_fade_in,
        "ducking_fade_out": ducking_fade_out,
        "ducking_bus": ducking_bus
    }

## 从字典加载配置
func load_from_dict(config_dict: Dictionary) -> bool:
    if not config_dict.has("max_instances"):
        return false

    max_instances = config_dict.max_instances
    limit_policy = config_dict.get("limit_policy", LimitPolicy.PRIORITY)
    priority = config_dict.get("priority", 1)
    ducking_fade_in = config_dict.get("ducking_fade_in", 0.1)
    ducking_fade_out = config_dict.get("ducking_fade_out", 0.5)
    ducking_bus = config_dict.get("ducking_bus", "Master")

    return true

## 验证配置
func validate() -> Dictionary:
    var result = {
        "valid": true,
        "issues": [],
        "warnings": []
    }

    # 验证最大实例数
    if max_instances <= 0:
        result.issues.append("max_instances must be greater than 0")
        result.valid = false

    # 验证优先级
    if priority < 0 or priority > 10:
        result.issues.append("priority must be between 0 and 10")
        result.valid = false

    # 验证淡入淡出时间
    if ducking_fade_in < 0.0:
        result.issues.append("ducking_fade_in cannot be negative")
        result.valid = false

    if ducking_fade_out < 0.0:
        result.issues.append("ducking_fade_out cannot be negative")
        result.valid = false

    # 验证鸭霸总线
    if ducking_bus.is_empty():
        result.issues.append("ducking_bus cannot be empty")
        result.valid = false

    # 验证鸭霸规则
    var rule_index = 0
    for rule in ducking_rules:
        if rule == null:
            result.issues.append("Ducking rule at index %d is null" % rule_index)
            result.valid = false
        else:
            var rule_validation = rule.validate()
            if not rule_validation.valid:
                result.issues.append("Ducking rule at index %d: %s" % [rule_index, rule_validation.issues.join(", ")])
                result.valid = false

            # 检查总线是否存在
            var bus_exists = false
            for i in range(AudioServer.get_bus_count()):
                if AudioServer.get_bus_name(i) == rule.target_bus:
                    bus_exists = true
                    break

            if not bus_exists:
                result.warnings.append("Ducking rule at index %d references non-existent bus: %s" % [rule_index, rule.target_bus])

        rule_index += 1

    # 检查重复的总线
    var bus_usage = {}
    for rule in ducking_rules:
        if rule.enabled:
            if rule.target_bus in bus_usage:
                bus_usage[rule.target_bus] += 1
            else:
                bus_usage[rule.target_bus] = 1

    for bus in bus_usage:
        var count = bus_usage[bus]
        if count > 1:
            result.warnings.append("Multiple rules target the same bus: %s (%d rules)" % [bus, count])

    return result

# =============================================================================
# 私有方法
# =============================================================================

## 获取限制策略字符串表示
func _get_policy_string(policy: LimitPolicy) -> String:
    match policy:
        LimitPolicy.FIFO:
            return "fifo"
        LimitPolicy.LIFO:
            return "lifo"
        LimitPolicy.PRIORITY:
            return "priority"
        LimitPolicy.NEWEST_STEALS_OLDEST:
            return "newest_steals_oldest"
        LimitPolicy.FADE_OUT_OLDEST:
            return "fade_out_oldest"
        LimitPolicy.FADE_IN_NEWEST:
            return "fade_in_newest"
        LimitPolicy.CROSSFADE:
            return "crossfade"
        _:
            return "priority"

## 获取编辑器颜色
func get_editor_color() -> Color:
    return Color(0.2, 0.6, 0.9, 1.0)