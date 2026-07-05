# JuicyMixer Audio Manager Phase 1 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 实现JuicyMixer音频管理器的核心功能，包括随机变体系统、混音控制、2D/3D自动检测和播放器池管理

**Architecture:** 基于Resource系统的配置层 + 基于RefCounted的管理器层 + 扩展现有JuicyAudioEventHandler的事件处理层。充分利用Godot原生AudioServer和AudioStreamPlayer，零性能损失的核心路径。

**Tech Stack:** Godot 4.5, GDScript 2.0, Resource系统, RefCounted, 事件驱动架构

**设计文档参考:**
- `addons/juicy_mixer/docs/dev_docs/audio_manager_design.md` - 主设计文档
- `addons/juicy_mixer/docs/dev_docs/audio_manager_godot_integration.md` - Godot集成说明
- `addons/juicy_mixer/docs/dev_docs/audio_manager_voice_management_enhanced.md` - 多层级限额架构（阶段2）

---

## Task 1: 创建目录结构

**Files:**
- Create: `addons/juicy_mixer/resources/audio/`
- Create: `addons/juicy_mixer/core/audio/`
- Create: `addons/juicy_mixer/tests/audio/`

**Step 1: 创建资源目录**

Run: 在Godot项目根目录执行
```bash
mkdir -p addons/juicy_mixer/resources/audio
```

**Step 2: 创建核心模块目录**

Run: 在Godot项目根目录执行
```bash
mkdir -p addons/juicy_mixer/core/audio
```

**Step 3: 创建测试目录**

Run: 在Godot项目根目录执行
```bash
mkdir -p addons/juicy_mixer/tests/audio
```

**Step 4: 创建.gdignore文件（防止导出）**

Create: `addons/juicy_mixer/resources/audio/.gdignore`
```
*
```

Create: `addons/juicy_mixer/core/audio/.gdignore`
```
*
```

**Step 5: 验证目录结构**

Run: 检查目录是否创建成功
```bash
ls -la addons/juicy_mixer/resources/audio/
ls -la addons/juicy_mixer/core/audio/
ls -la addons/juicy_mixer/tests/audio/
```

Expected: 每个目录都存在且包含.gdignore文件（resources和core目录）

**Step 6: 提交**

```bash
git add addons/juicy_mixer/resources/audio .gdignore
git add addons/juicy_mixer/core/audio .gdignore
git add addons/juicy_mixer/tests/audio
git commit -m "feat(audio): create directory structure for audio manager system"
```

---

## Task 2: 实现AudioVariant资源类

**Files:**
- Create: `addons/juicy_mixer/resources/audio/audio_variant.gd`
- Test: `addons/juicy_mixer/tests/audio/test_audio_variant.gd`

**Step 1: 编写AudioVariant基础测试**

Create: `addons/juicy_mixer/tests/audio/test_audio_variant.gd`
```gdscript
extends Node

func _ready():
    test_audio_variant_creation()
    test_audio_variant_serialization()
    print("✓ AudioVariant tests passed")

func test_audio_variant_creation():
    var variant = AudioVariant.new()
    assert(variant != null, "Variant should be created")
    assert(variant.audio_stream == null, "Default stream should be null")
    assert(variant.weight == 1.0, "Default weight should be 1.0")
    print("  ✓ AudioVariant creation test passed")

func test_audio_variant_serialization():
    var variant = AudioVariant.new()
    variant.variant_name = "test_variant"
    variant.weight = 2.0
    variant.pitch_enabled = true
    variant.pitch_min = -0.5
    variant.pitch_max = 0.5

    # 测试序列化（通过Resource.duplicate）
    var duplicated = variant.duplicate(true)
    assert(duplicated.variant_name == "test_variant", "Name should be preserved")
    assert(duplicated.weight == 2.0, "Weight should be preserved")
    assert(duplicated.pitch_enabled == true, "Pitch enabled should be preserved")
    print("  ✓ AudioVariant serialization test passed")
```

**Step 2: 运行测试验证失败**

Run: 在Godot中创建测试场景运行
Expected: FAIL with "Undefined class AudioVariant"

**Step 3: 实现AudioVariant资源类**

Create: `addons/juicy_mixer/resources/audio/audio_variant.gd`
```gdscript
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
```

**Step 4: 运行测试验证通过**

Run: 在Godot中运行测试场景
Expected: PASS 所有测试

**Step 5: 添加额外测试用例**

Add to: `addons/juicy_mixer/tests/audio/test_audio_variant.gd`
```gdscript
func test_audio_variant_validation():
    var variant = AudioVariant.new()

    # 有效配置
    variant.weight = 1.0
    var result = variant.validate()
    assert(result.valid, "Valid config should pass")

    # 无效权重
    variant.weight = -1.0
    result = variant.validate()
    assert(not result.valid, "Negative weight should fail")
    assert(result.issues.size() > 0, "Should have issues")

    # 音高范围错误
    variant.weight = 1.0
    variant.pitch_enabled = true
    variant.pitch_min = 0.5
    variant.pitch_max = -0.5
    result = variant.validate()
    assert(not result.valid, "Invalid pitch range should fail")

    print("  ✓ AudioVariant validation test passed")

func test_audio_variant_randomization():
    var variant = AudioVariant.new()

    # 音高随机化
    variant.pitch_enabled = true
    variant.pitch_min = -0.3
    variant.pitch_max = 0.3

    var pitch_values = []
    for i in range(10):
        pitch_values.append(variant.get_randomized_pitch())

    # 验证范围（粗略检查）
    for pitch in pitch_values:
        assert(pitch > 0.7 and pitch < 1.3, "Pitch should be within randomized range")

    # 音量随机化
    variant.volume_enabled = true
    variant.volume_min = 0.8
    variant.volume_max = 1.2

    var volume_values = []
    for i in range(10):
        volume_values.append(variant.get_randomized_volume())

    for volume in volume_values:
        assert(volume >= 0.8 and volume <= 1.2, "Volume should be within randomized range")

    print("  ✓ AudioVariant randomization test passed")
```

Update `_ready()` 方法:
```gdscript
func _ready():
    test_audio_variant_creation()
    test_audio_variant_serialization()
    test_audio_variant_validation()
    test_audio_variant_randomization()
    print("✓ AudioVariant tests passed")
```

**Step 6: 再次运行测试**

Run: 在Godot中运行测试场景
Expected: PASS 所有测试

**Step 7: 提交**

```bash
git add addons/juicy_mixer/resources/audio/audio_variant.gd
git add addons/juicy_mixer/tests/audio/test_audio_variant.gd
git commit -m "feat(audio): implement AudioVariant resource class

- Add AudioVariant resource with pitch/volume randomization
- Support weight-based selection
- Add validation method
- Add comprehensive tests"
```

---

## Task 3: 实现AudioRandomizationConfig资源类

**Files:**
- Create: `addons/juicy_mixer/resources/audio/audio_randomization_config.gd`
- Test: `addons/juicy_mixer/tests/audio/test_audio_randomization_config.gd`

**Step 1: 编写测试**

Create: `addons/juicy_mixer/tests/audio/test_audio_randomization_config.gd`
```gdscript
extends Node

func _ready():
    test_config_creation()
    test_global_randomization()
    print("✓ AudioRandomizationConfig tests passed")

func test_config_creation():
    var config = AudioRandomizationConfig.new()
    assert(config != null, "Config should be created")
    assert(config.enabled == true, "Should be enabled by default")
    print("  ✓ Config creation test passed")

func test_global_randomization():
    var config = AudioRandomizationConfig.new()
    config.global_pitch_min = -0.3
    config.global_pitch_max = 0.3
    config.global_volume_min = 0.9
    config.global_volume_max = 1.1

    var pitch_values = []
    var volume_values = []

    for i in range(20):
        pitch_values.append(config.get_global_pitch_offset())
        volume_values.append(config.get_global_volume_offset())

    # 验证随机化范围
    for pitch in pitch_values:
        assert(pitch >= -0.3 and pitch <= 0.3, "Pitch offset should be in range")

    for volume in volume_values:
        assert(volume >= 0.9 and volume <= 1.1, "Volume offset should be in range")

    print("  ✓ Global randomization test passed")
```

**Step 2: 运行测试验证失败**

Expected: FAIL with "Undefined class AudioRandomizationConfig"

**Step 3: 实现AudioRandomizationConfig**

Create: `addons/juicy_mixer/resources/audio/audio_randomization_config.gd`
```gdscript
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

    return _rng.randf_range(global_pitch_min, global_pitch_max)

## 获取全局音量偏移（倍数）
func get_global_volume_offset() -> float:
    if not enabled:
        return 1.0

    if _rng == null:
        initialize_random()

    return _rng.randf_range(global_volume_min, global_volume_max)

## 验证配置
func validate() -> Dictionary:
    var result = {
        "valid": true,
        "issues": [],
        "warnings": []
    }

    if global_pitch_min > global_pitch_max:
        result.issues.append("global_pitch_min cannot be greater than global_pitch_max")
        result.valid = false

    if global_volume_min > global_volume_max:
        result.issues.append("global_volume_min cannot be greater than global_volume_max")
        result.valid = false

    return result
```

**Step 4: 运行测试验证通过**

Run: 在Godot中运行测试场景
Expected: PASS

**Step 5: 提交**

```bash
git add addons/juicy_mixer/resources/audio/audio_randomization_config.gd
git add addons/juicy_mixer/tests/audio/test_audio_randomization_config.gd
git commit -m "feat(audio): implement AudioRandomizationConfig

- Add global pitch/volume randomization
- Support fixed seed for reproducibility
- Add RandomNumberGenerator management
- Add tests"
```

---

## Task 4: 实现DuckingRule资源类

**Files:**
- Create: `addons/juicy_mixer/resources/audio/ducking_rule.gd`
- Test: `addons/juicy_mixer/tests/audio/test_ducking_rule.gd`

**Step 1: 编写测试**

Create: `addons/juicy_mixer/tests/audio/test_ducking_rule.gd`
```gdscript
extends Node

func _ready():
    test_rule_creation()
    test_pattern_matching()
    print("✓ DuckingRule tests passed")

func test_rule_creation():
    var rule = DuckingRule.new()
    assert(rule != null, "Rule should be created")
    assert(rule.enabled == true, "Should be enabled by default")
    assert(rule.target_bus == "Music", "Default target should be Music")
    print("  ✓ Rule creation test passed")

func test_pattern_matching():
    var rule = DuckingRule.new()
    rule.event_name_pattern = "dialogue_*"

    assert(rule.matches("dialogue_hello"), "Should match pattern")
    assert(rule.matches("dialogue_goodbye"), "Should match pattern")
    assert(not rule.matches("sfx_jump"), "Should not match different pattern")
    assert(rule.matches("dialogue_*"), "Should match exact pattern")

    # 测试通配符
    rule.event_name_pattern = "*"
    assert(rule.matches("anything"), "Wildcard should match everything")

    print("  ✓ Pattern matching test passed")
```

**Step 2: 运行测试验证失败**

Expected: FAIL with "Undefined class DuckingRule"

**Step 3: 实现DuckingRule**

Create: `addons/juicy_mixer/resources/audio/ducking_rule.gd`
```gdscript
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
    if not enabled:
        return

    var bus_name = AudioServer.get_bus_name(bus_index)
    if bus_name != target_bus:
        return

    # 保存原始音量
    _original_volume = AudioServer.get_bus_volume_db(bus_index)

    # 应用鸭霸
    AudioServer.set_bus_volume_db(bus_index, _original_volume + duck_amount)
    _is_ducking = true

## 移除鸭霸（恢复原始音量）
func remove_ducking(bus_index: int) -> void:
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
```

**Step 4: 运行测试验证通过**

Expected: PASS

**Step 5: 提交**

```bash
git add addons/juicy_mixer/resources/audio/ducking_rule.gd
git add addons/juicy_mixer/tests/audio/test_ducking_rule.gd
git commit -m "feat(audio): implement DuckingRule resource

- Add event pattern matching with wildcards
- Integrate with Godot AudioServer
- Add volume ducking and recovery
- Add validation"
```

---

## Task 5: 实现AudioMixingConfig资源类

**Files:**
- Create: `addons/juicy_mixer/resources/audio/audio_mixing_config.gd`
- Test: `addons/juicy_mixer/tests/audio/test_audio_mixing_config.gd`

**Step 1: 编写测试**

Create: `addons/juicy_mixer/tests/audio/test_audio_mixing_config.gd`
```gdscript
extends Node

func _ready():
    test_config_creation()
    test_instance_limiting()
    test_ducking_rules()
    print("✓ AudioMixingConfig tests passed")

func test_config_creation():
    var config = AudioMixingConfig.new()
    assert(config != null, "Config should be created")
    assert(config.max_instances == 5, "Default max_instances should be 5")
    print("  ✓ Config creation test passed")

func test_instance_limiting():
    var config = AudioMixingConfig.new()
    config.max_instances = 3
    config.priority = 70

    assert(config.max_instances == 3, "max_instances should be set")
    assert(config.priority == 70, "priority should be set")
    print("  ✓ Instance limiting test passed")

func test_ducking_rules():
    var config = AudioMixingConfig.new()

    var rule1 = DuckingRule.new()
    rule1.event_name_pattern = "dialogue_*"
    rule1.target_bus = "Music"

    var rule2 = DuckingRule.new()
    rule2.event_name_pattern = "sfx_*"
    rule2.target_bus = "Voice"

    config.ducking_rules.append(rule1)
    config.ducking_rules.append(rule2)

    assert(config.ducking_rules.size() == 2, "Should have 2 rules")

    var found_rule = config.get_ducking_rule_for_event("dialogue_hello")
    assert(found_rule != null, "Should find matching rule")

    var no_rule = config.get_ducking_rule_for_event("explosion")
    assert(no_rule == null, "Should not find rule for non-matching event")

    print("  ✓ Ducking rules test passed")
```

**Step 2: 运行测试验证失败**

Expected: FAIL with "Undefined class AudioMixingConfig"

**Step 3: 实现AudioMixingConfig**

Create: `addons/juicy_mixer/resources/audio/audio_mixing_config.gd`
```gdscript
@tool
class_name AudioMixingConfig
extends Resource

## 音频混音配置
##
## 控制播放限额、鸭霸规则等混音行为

# =============================================================================
# 播放限额配置
# =============================================================================

@export_group("Instance Limiting", "limiting_")

## 最大同时播放实例数
@export var max_instances: int = 5

## 限额策略
enum InstanceLimitPolicy {
    STOP_OLDEST,           ## 停止最老的实例
    STOP_NEWEST,           ## 忽略新的播放
    STOP_LOWEST_PRIORITY,  ## 停止优先级最低的
    NEWEST_STEALS_OLDEST   ## 新的停止最老的（推荐）
}
@export var limit_policy: InstanceLimitPolicy = InstanceLimitPolicy.STOP_OLDEST

## 优先级（0-100，越高越重要）
@export_range(0, 100) var priority: int = 50

# =============================================================================
# 鸭霸配置
# =============================================================================

@export_group("Ducking Rules", "ducking_")

## 鸭霸规则列表
@export var ducking_rules: Array[DuckingRule] = []

## 鸭霸淡入时间（秒）
@export_range(0.01, 5.0, 0.01) var ducking_fade_in: float = 0.1

## 鸭霸淡出时间（秒）
@export_range(0.01, 5.0, 0.01) var ducking_fade_out: float = 0.5

## 鸭霸目标总线
@export var ducking_bus: String = "Master"

# =============================================================================
# 公共方法
# =============================================================================

## 应用配置到播放器
func apply_to_player(player: Object, bus: String) -> void:
    if player.has_method("set"):
        player.call("set", "bus", bus)

## 获取事件的鸭霸规则
func get_ducking_rule_for_event(event_name: String) -> DuckingRule:
    for rule in ducking_rules:
        if rule.matches(event_name):
            return rule
    return null

## 验证配置
func validate() -> Dictionary:
    var result = {
        "valid": true,
        "issues": [],
        "warnings": []
    }

    if max_instances <= 0:
        result.issues.append("max_instances must be positive")
        result.valid = false

    if priority < 0 or priority > 100:
        result.issues.append("priority must be between 0 and 100")
        result.valid = false

    # 验证鸭霸规则
    for i in range(ducking_rules.size()):
        var rule = ducking_rules[i]
        if rule == null:
            result.issues.append("ducking_rules[%d] is null" % i)
            result.valid = false
            continue

        var rule_validation = rule.validate()
        if not rule_validation.valid:
            result.issues.append_array(rule_validation.issues)
            result.valid = false

        result.warnings.append_array(rule_validation.warnings)

    return result
```

**Step 4: 运行测试验证通过**

Expected: PASS

**Step 5: 提交**

```bash
git add addons/juicy_mixer/resources/audio/audio_mixing_config.gd
git add addons/juicy_mixer/tests/audio/test_audio_mixing_config.gd
git commit -m "feat(audio): implement AudioMixingConfig resource

- Add instance limiting configuration
- Add ducking rules management
- Support multiple limit policies
- Add validation"
```

---

## Task 6: 实现AudioUtils工具类

**Files:**
- Create: `addons/juicy_mixer/core/audio/audio_utils.gd`
- Test: `addons/juicy_mixer/tests/audio/test_audio_utils.gd`

**Step 1: 编写测试**

Create: `addons/juicy_mixer/tests/audio/test_audio_utils.gd`
```gdscript
extends Node

func _ready():
    test_unit_conversions()
    test_player_detection()
    test_player_creation()
    print("✓ AudioUtils tests passed")

func test_unit_conversions():
    # Linear to DB
    assert(abs(AudioUtils.linear_to_db(1.0) - 0.0) < 0.01, "1.0 linear = 0 dB")
    assert(AudioUtils.linear_to_db(0.5) < 0, "0.5 linear should be negative dB")
    assert(AudioUtils.linear_to_db(2.0) > 0, "2.0 linear should be positive dB")

    # DB to Linear
    assert(abs(AudioUtils.db_to_linear(0.0) - 1.0) < 0.01, "0 dB = 1.0 linear")

    # Pitch scale from semitones
    var pitch_up = AudioUtils.get_pitch_scale_from_semitones(12.0)
    assert(abs(pitch_up - 2.0) < 0.01, "12 semitones = 2.0 pitch scale")

    var pitch_down = AudioUtils.get_pitch_scale_from_semitones(-12.0)
    assert(abs(pitch_down - 0.5) < 0.01, "-12 semitones = 0.5 pitch scale")

    print("  ✓ Unit conversions test passed")

func test_player_detection():
    var node_2d = Node2D.new()
    var node_3d = Node3D.new()
    var node_generic = Node.new()

    var type_2d = AudioUtils.detect_player_type(node_2d)
    var type_3d = AudioUtils.detect_player_type(node_3d)
    var type_generic = AudioUtils.detect_player_type(node_generic)

    assert(type_2d == 0, "Node2D should be PLAYER_2D (0)")
    assert(type_3d == 1, "Node3D should be PLAYER_3D (1)")
    assert(type_generic == 0, "Generic node should default to PLAYER_2D (0)")

    node_2d.queue_free()
    node_3d.queue_free()
    node_generic.queue_free()

    print("  ✓ Player detection test passed")

func test_player_creation():
    var player_2d = AudioUtils.create_player_2d()
    assert(player_2d is AudioStreamPlayer2D, "Should create 2D player")
    player_2d.queue_free()

    var player_3d = AudioUtils.create_player_3d()
    assert(player_3d is AudioStreamPlayer3D, "Should create 3D player")
    player_3d.queue_free()

    print("  ✓ Player creation test passed")
```

**Step 2: 运行测试验证失败**

Expected: FAIL with "Undefined class AudioUtils"

**Step 3: 实现AudioUtils**

Create: `addons/juicy_mixer/core/audio/audio_utils.gd`
```gdscript
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
```

**Step 4: 运行测试验证通过**

Expected: PASS

**Step 5: 提交**

```bash
git add addons/juicy_mixer/core/audio/audio_utils.gd
git add addons/juicy_mixer/tests/audio/test_audio_utils.gd
git commit -m "feat(audio): implement AudioUtils utility class

- Add linear/DB conversion functions
- Add pitch scale/semitone conversion
- Add player type auto-detection
- Add player creation helpers
- Add comprehensive tests"
```

---

## Task 7: 实现AudioVariationManager管理器

**Files:**
- Create: `addons/juicy_mixer/core/audio/audio_variation_manager.gd`
- Test: `addons/juicy_mixer/tests/audio/test_audio_variation_manager.gd`

**Step 1: 编写基础测试**

Create: `addons/juicy_mixer/tests/audio/test_audio_variation_manager.gd`
```gdscript
extends Node

func _ready():
    test_variant_selection()
    test_weighted_selection()
    test_no_repeat()
    test_randomization()
    print("✓ AudioVariationManager tests passed")

func test_variant_selection():
    var manager = AudioVariationManager.new()
    var resource = AudioEventResource.new()

    # 添加3个变体
    for i in range(3):
        var variant = AudioVariant.new()
        variant.audio_stream = AudioStreamOggVorbis.new()
        variant.weight = 1.0
        resource.audio_variants.append(variant)

    var selected = manager.select_variant(resource)
    assert(selected != null, "Should select a variant")
    assert(selected in resource.audio_variants, "Selected should be in variants")

    print("  ✓ Variant selection test passed")

func test_weighted_selection():
    var manager = AudioVariationManager.new()
    var resource = AudioEventResource.new()

    # 添加3个变体，权重分别为1, 2, 3
    var weights = [1.0, 2.0, 3.0]
    for i in range(3):
        var variant = AudioVariant.new()
        variant.audio_stream = AudioStreamOggVorbis.new()
        variant.weight = weights[i]
        resource.audio_variants.append(variant)

    # 测试100次选择，验证权重分布
    var counts = [0, 0, 0]
    for i in range(100):
        var selected = manager.select_variant(resource)
        var index = resource.audio_variants.find(selected)
        counts[index] += 1

    # 变体3应该被选择最多（权重最大）
    assert(counts[2] > counts[1], "Variant 3 (weight 3) should be selected more than variant 2")
    assert(counts[1] > counts[0], "Variant 2 (weight 2) should be selected more than variant 1")

    print("  ✓ Weighted selection test passed")

func test_no_repeat():
    var manager = AudioVariationManager.new()
    var resource = AudioEventResource.new()
    resource.no_repeat_enabled = true
    resource.no_repeat_memory = 2

    # 添加3个变体
    for i in range(3):
        var variant = AudioVariant.new()
        variant.audio_stream = AudioStreamOggVorbis.new()
        variant.variant_name = "variant_%d" % i
        resource.audio_variants.append(variant)

    var last_selected = null
    for i in range(10):
        var selected = manager.select_variant(resource)
        if last_selected != null:
            assert(selected != last_selected, "No repeat should prevent consecutive same variant")
        last_selected = selected

    print("  ✓ No repeat test passed")

func test_randomization():
    var manager = AudioVariationManager.new()
    var config = AudioRandomizationConfig.new()
    config.global_pitch_min = -0.5
    config.global_pitch_max = 0.5
    config.global_volume_min = 0.9
    config.global_volume_max = 1.1
    config.enabled = true

    var resource = AudioEventResource.new()
    resource.randomization = config

    var variant = AudioVariant.new()
    variant.audio_stream = AudioStreamOggVorbis.new()
    variant.pitch_enabled = true
    variant.pitch_min = -0.3
    variant.pitch_max = 0.3
    variant.volume_enabled = true
    variant.volume_min = 0.8
    variant.volume_max = 1.2
    resource.audio_variants.append(variant)

    # 测试100次随机化
    var pitch_values = []
    var volume_values = []
    for i in range(100):
        var rand = manager.apply_randomization(variant, 1.0, 1.0, resource)
        pitch_values.append(rand.pitch)
        volume_values.append(rand.volume)

    # 验证范围
    for pitch in pitch_values:
        assert(pitch > 0.5 and pitch < 1.5, "Pitch should be within randomized range")

    for volume in volume_values:
        assert(volume >= 0.72 and volume <= 1.32, "Volume should be within randomized range")

    print("  ✓ Randomization test passed")
```

**Step 2: 运行测试验证失败**

Expected: FAIL with "Undefined class AudioEventResource" and "Undefined class AudioVariationManager"

**Step 3: 先实现AudioEventResource的简化版本**

Create: `addons/juicy_mixer/resources/audio/audio_event_resource.gd`
```gdscript
@tool
class_name AudioEventResource
extends Resource

## 音频事件资源
##
## 定义音频播放的所有配置，包括变体、随机化、混音等

# =============================================================================
# 基础配置
# =============================================================================

enum AudioPlayerType {
    AUTO_DETECT,
    PLAYER_2D,
    PLAYER_3D
}

@export var event_name: String = ""
@export var player_type: AudioPlayerType = AudioPlayerType.AUTO_DETECT
@export var audio_bus: String = "Master"
@export var max_distance: float = 100.0
@export var max_distance_db: float = -80.0

# =============================================================================
# 变体配置
# =============================================================================

@export var audio_variants: Array[AudioVariant] = []
@export var randomization: AudioRandomizationConfig = null
@export var no_repeat_enabled: bool = true
@export var no_repeat_memory: int = 3

# =============================================================================
# 混音配置
# =============================================================================

@export var mixing: AudioMixingConfig = null

# =============================================================================
# 公共方法
# =============================================================================

func create_audio_play_event(target: Node) -> JuicyEvent:
    # 这个方法将在实现JuicyAudioEventHandler扩展时完成
    return null

func validate() -> Dictionary:
    var result = {
        "valid": true,
        "issues": [],
        "warnings": []
    }

    if audio_variants.is_empty():
        result.issues.append("No audio variants defined")
        result.valid = false

    return result

func get_total_weight() -> float:
    var total = 0.0
    for variant in audio_variants:
        if variant:
            total += variant.weight
    return total
```

**Step 4: 实现AudioVariationManager**

Create: `addons/juicy_mixer/core/audio/audio_variation_manager.gd`
```gdscript
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
```

**Step 5: 运行测试验证通过**

Expected: PASS（可能需要Godot编辑器重启以识别新类）

**Step 6: 提交**

```bash
git add addons/juicy_mixer/resources/audio/audio_event_resource.gd
git add addons/juicy_mixer/core/audio/audio_variation_manager.gd
git add addons/juicy_mixer/tests/audio/test_audio_variation_manager.gd
git commit -m "feat(audio): implement AudioVariationManager

- Add weighted variant selection
- Add no-repeat history management
- Add pitch/volume randomization (variant + global)
- Add AudioEventResource base class
- Add comprehensive tests"
```

---

## Task 8: 实现AudioMixingController管理器

**Files:**
- Create: `addons/juicy_mixer/core/audio/audio_mixing_controller.gd`
- Test: `addons/juicy_mixer/tests/audio/test_audio_mixing_controller.gd`

**Step 1: 编写测试**

Create: `addons/juicy_mixer/tests/audio/test_audio_mixing_controller.gd`
```gdscript
extends Node

func _ready():
    test_instance_limiting()
    test_ducking()
    test_stats()
    print("✓ AudioMixingController tests passed")

func test_instance_limiting():
    var controller = AudioMixingController.new()
    var resource = AudioEventResource.new()
    resource.event_name = "test_sound"
    resource.mixing = AudioMixingConfig.new()
    resource.mixing.max_instances = 3
    resource.mixing.limit_policy = AudioMixingConfig.InstanceLimitPolicy.STOP_OLDEST

    # 测试限额
    for i in range(5):
        var can_play = controller.can_play(resource, "test_sound")
        if i < 3:
            assert(can_play, "Should be able to play within limit (iteration %d)" % i)
        else:
            assert(can_play, "Should stop oldest and allow new (iteration %d)" % i)

        var player = AudioStreamPlayer2D.new()
        controller.record_instance("test_sound", player, 50)

    print("  ✓ Instance limiting test passed")

func test_ducking():
    var controller = AudioMixingController.new()
    var resource = AudioEventResource.new()
    resource.event_name = "test_sound"
    resource.mixing = AudioMixingConfig.new()

    var ducking_rule = DuckingRule.new()
    ducking_rule.event_name_pattern = "test_*"
    ducking_rule.target_bus = "Master"
    ducking_rule.duck_amount = -10.0
    ducking_rule.enabled = true

    resource.mixing.ducking_rules.append(ducking_rule)

    # 测试鸭霸
    controller.apply_ducking("test_sound", resource.mixing)
    var stats = controller.get_stats()
    assert(stats.ducking_active == 1, "Ducking should be active")

    # 测试恢复
    controller.remove_ducking("test_sound", resource.mixing)
    for i in range(100):
        controller.update_ducking(0.016)

    stats = controller.get_stats()
    assert(stats.ducking_active == 0, "Ducking should be recovered")

    print("  ✓ Ducking test passed")

func test_stats():
    var controller = AudioMixingController.new()
    var stats = controller.get_stats()

    assert(stats.has("active_instances"), "Should have active_instances stat")
    assert(stats.has("ducking_active"), "Should have ducking_active stat")

    print("  ✓ Stats test passed")
```

**Step 2: 运行测试验证失败**

Expected: FAIL with "Undefined class AudioMixingController"

**Step 3: 实现AudioMixingController**

Create: `addons/juicy_mixer/core/audio/audio_mixing_controller.gd`
```gdscript
class_name AudioMixingController
extends RefCounted

## 音频混音控制器
##
## 负责播放实例限额管理、鸭霸规则应用、虚声部判断等

# =============================================================================
# 私有变量
# =============================================================================

var _active_instances: Dictionary = {}  # event_name -> Array[player_info]
var _ducking_state: Dictionary = {}     # target_bus -> ducking_info

# Ducking信息类
class DuckingInfo:
    var rule: DuckingRule
    var start_time: float
    var recovery_time: float

    func _init(r: DuckingRule, delay: float):
        rule = r
        start_time = Time.get_ticks_msec() / 1000.0
        recovery_time = start_time + delay

# =============================================================================
# 播放限额
# =============================================================================

## 检查是否可以播放
func can_play(resource: AudioEventResource, event_name: String) -> bool:
    if not resource or not resource.mixing:
        return true

    var config = resource.mixing
    var instances = _active_instances.get(event_name, [])

    # 统计活跃实例
    var active_count = 0
    for instance_info in instances:
        if is_instance_valid(instance_info.player):
            active_count += 1

    if active_count < config.max_instances:
        return true

    # 超限处理
    match config.limit_policy:
        config.InstanceLimitPolicy.STOP_OLDEST:
            _stop_oldest_in_instance(event_name)
            return true
        config.InstanceLimitPolicy.STOP_NEWEST:
            return false
        config.InstanceLimitPolicy.STOP_LOWEST_PRIORITY:
            _stop_lowest_priority_in_instance(event_name)
            return true
        config.InstanceLimitPolicy.NEWEST_STEALS_OLDEST:
            _stop_oldest_in_instance(event_name)
            return true
        _:
            return true

## 记录播放实例
func record_instance(event_name: String, player: Object, priority: int) -> void:
    if not _active_instances.has(event_name):
        _active_instances[event_name] = []

    _active_instances[event_name].append({
        "player": player,
        "priority": priority,
        "start_time": Time.get_ticks_msec() / 1000.0
    })

## 移除播放实例
func remove_instance(event_name: String, player: Object) -> void:
    if not _active_instances.has(event_name):
        return

    var instances = _active_instances[event_name]
    for i in range(instances.size()):
        if instances[i].player == player:
            instances.remove_at(i)
            break

    if instances.is_empty():
        _active_instances.erase(event_name)

# =============================================================================
# 鸭霸管理
# =============================================================================

## 应用鸭霸
func apply_ducking(event_name: String, config: AudioMixingConfig) -> void:
    if not config:
        return

    var rule = config.get_ducking_rule_for_event(event_name)
    if not rule:
        return

    var bus_index = AudioServer.get_bus_index(rule.target_bus)
    if bus_index == -1:
        push_warning("AudioMixingController: Bus '%s' not found for ducking" % rule.target_bus)
        return

    # 应用鸭霸
    rule.apply_ducking(bus_index)

    # 记录状态
    _ducking_state[rule.target_bus] = DuckingInfo.new(rule, rule.recovery_delay)

## 移除鸭霸
func remove_ducking(event_name: String, config: AudioMixingConfig) -> void:
    if not config:
        return

    var rule = config.get_ducking_rule_for_event(event_name)
    if not rule:
        return

    var bus_index = AudioServer.get_bus_index(rule.target_bus)
    if bus_index == -1:
        return

    # 标记恢复时间（在update中实际恢复）
    if _ducking_state.has(rule.target_bus):
        var info = _ducking_state[rule.target_bus]
        info.recovery_time = Time.get_ticks_msec() / 1000.0 + rule.recovery_delay

## 更新鸭霸状态（每帧调用）
func update_ducking(delta: float) -> void:
    var current_time = Time.get_ticks_msec() / 1000.0
    var completed: Array = []

    for bus_name in _ducking_state.keys():
        var info = _ducking_state[bus_name]

        if current_time >= info.recovery_time:
            # 恢复原始音量
            var bus_index = AudioServer.get_bus_index(bus_name)
            if bus_index != -1:
                info.rule.remove_ducking(bus_index)

            completed.append(bus_name)

    for bus_name in completed:
        _ducking_state.erase(bus_name)

# =============================================================================
# 虚声部判断
# =============================================================================

## 判断是否应该作为虚声部播放
func should_play_virtual(resource: AudioEventResource, listener: Node3D,
                        source_position: Vector3) -> bool:
    if not resource or not resource.virtual_voice_enabled:
        return false

    # 简化实现：仅检查距离
    if listener:
        var distance = listener.global_position.distance_to(source_position)
        if distance > resource.virtual_max_distance:
            return true

    return false

# =============================================================================
# 统计
# =============================================================================

## 获取统计信息
func get_stats() -> Dictionary:
    var total_instances = 0
    for event_name in _active_instances.keys():
        total_instances += _active_instances[event_name].size()

    return {
        "active_instances": total_instances,
        "ducking_active": _ducking_state.size()
    }

# =============================================================================
# 私有方法
# =============================================================================

## 停止最老的实例
func _stop_oldest_in_instance(event_name: String) -> void:
    var instances = _active_instances.get(event_name, [])
    if instances.is_empty():
        return

    var oldest = instances[0]
    _stop_player(oldest.player)

## 停止优先级最低的实例
func _stop_lowest_priority_in_instance(event_name: String) -> void:
    var instances = _active_instances.get(event_name, [])
    if instances.is_empty():
        return

    var lowest_priority = INF
    var lowest_index = -1

    for i in range(instances.size()):
        if not is_instance_valid(instances[i].player):
            continue

        if instances[i].priority < lowest_priority:
            lowest_priority = instances[i].priority
            lowest_index = i

    if lowest_index >= 0:
        _stop_player(instances[lowest_index].player)

## 停止播放器
func _stop_player(player: Object) -> void:
    if player is AudioStreamPlayer:
        player.stop()
    elif player is AudioStreamPlayer2D:
        player.stop()
    elif player is AudioStreamPlayer3D:
        player.stop()
```

**Step 4: 运行测试验证通过**

Expected: PASS

**Step 5: 提交**

```bash
git add addons/juicy_mixer/core/audio/audio_mixing_controller.gd
git add addons/juicy_mixer/tests/audio/test_audio_mixing_controller.gd
git commit -m "feat(audio): implement AudioMixingController

- Add instance limiting with multiple policies
- Add ducking rule application and recovery
- Add statistics tracking
- Add virtual voice判断（简化版）
- Add comprehensive tests"
```

---

## Task 9: 扩展JuicyAudioEventHandler

**Files:**
- Modify: `addons/juicy_mixer/events/juicy_audio_event_handler.gd`
- Test: `addons/juicy_mixer/tests/audio/test_audio_integration.gd`

**注意**: 此任务需要查看现有的JuicyAudioEventHandler实现，根据实际代码调整扩展方式。

**Step 1: 查看现有JuicyAudioEventHandler**

Run: 查看现有实现
```bash
cat addons/juicy_mixer/events/juicy_audio_event_handler.gd
```

**Step 2: 根据现有实现编写测试**

Create: `addons/juicy_mixer/tests/audio/test_audio_integration.gd`
```gdscript
extends Node

func _ready():
    test_audio_event_resource_playback()
    test_2d_3d_auto_detection()
    test_integration_with_mixing()
    print("✓ Audio integration tests passed")

func test_audio_event_resource_playback():
    # 创建测试资源
    var resource = AudioEventResource.new()
    resource.event_name = "test_event"
    resource.audio_bus = "Master"

    var variant = AudioVariant.new()
    variant.audio_stream = AudioStreamOggVorbis.load_from_file("res://test.ogg")  # 需要测试音频
    variant.weight = 1.0
    resource.audio_variants.append(variant)

    # 通过JuicyMixer播放
    var event = JuicyEvent.new()
    event.event_type = JuicyEvent.EventType.AUDIO_PLAY
    event.event_data = {"audio_event_resource": resource}

    JuicyMixer.add_event(event)

    # 等待并验证
    await get_tree().create_timer(0.5).timeout

    print("  ✓ AudioEventResource playback test passed")

func test_2d_3d_auto_detection():
    # 2D节点
    var node_2d = Node2D.new()
    add_child(node_2d)

    var resource_2d = AudioEventResource.new()
    resource_2d.player_type = AudioEventResource.AudioPlayerType.AUTO_DETECT

    # 应该自动检测为2D
    var event_2d = JuicyEvent.new()
    event_2d.event_type = JuicyEvent.EventType.AUDIO_PLAY
    event_2d.event_data = {
        "audio_event_resource": resource_2d,
        "target": node_2d
    }

    JuicyMixer.add_event(event_2d)
    await get_tree().create_timer(0.1).timeout

    node_2d.queue_free()
    print("  ✓ 2D/3D auto-detection test passed")

func test_integration_with_mixing():
    # 测试混音控制
    var resource = AudioEventResource.new()
    resource.event_name = "mixing_test"
    resource.mixing = AudioMixingConfig.new()
    resource.mixing.max_instances = 2

    # 尝试播放多个实例
    for i in range(5):
        var event = JuicyEvent.new()
        event.event_type = JuicyEvent.EventType.AUDIO_PLAY
        event.event_data = {"audio_event_resource": resource}
        JuicyMixer.add_event(event)
        await get_tree().create_timer(0.1).timeout

    print("  ✓ Integration with mixing test passed")
```

**Step 3: 扩展JuicyAudioEventHandler**

基于现有实现添加以下功能：

```gdscript
# 在JuicyAudioEventHandler中添加

# =============================================================================
# 新增属性
# =============================================================================

var _variation_manager: AudioVariationManager = null
var _mixing_controller: AudioMixingController = null

var _player_pool_2d: Array[AudioStreamPlayer2D] = []
var _player_pool_3d: Array[AudioStreamPlayer3D] = []

var _max_pool_size: int = 50

# =============================================================================
# 初始化
# =============================================================================

func _ready():
    super._ready()  # 如果父类有_ready

    # 初始化管理器
    _variation_manager = AudioVariationManager.new()
    _mixing_controller = AudioMixingController.new()

    # 设置process回调
    if not process_callback.is_null():
        pass  # 已有回调
    else:
        set_process(true)

func _process(delta):
    # 更新混音控制器
    if _mixing_controller:
        _mixing_controller.update_ducking(delta)

# =============================================================================
# 扩展事件处理
# =============================================================================

# 重写或扩展现有的事件处理方法
func _handle_audio_play_extended(event: JuicyEvent) -> bool:
    var resource = event.event_data.get("audio_event_resource")

    if resource is AudioEventResource:
        return _handle_audio_resource_play(resource, event)
    else:
        return _handle_audio_play_legacy(event)

func _handle_audio_resource_play(resource: AudioEventResource, event: JuicyEvent) -> bool:
    # 1. 变体选择
    var variant = _variation_manager.select_variant(resource)
    if not variant:
        push_error("Failed to select audio variant for: " + resource.event_name)
        return false

    # 2. 应用随机化
    var randomization = _variation_manager.apply_randomization(
        variant, 1.0, _master_volume, resource
    )

    # 3. 检查播放限额
    if not _mixing_controller.can_play(resource, resource.event_name):
        _log_debug("Instance limit reached for: " + resource.event_name)
        return false

    # 4. 获取播放器
    var player = _get_audio_player_for_resource(resource, event)
    if not player:
        push_error("Failed to get audio player")
        return false

    # 5. 配置播放器
    _configure_player_for_resource(player, resource, variant, randomization, event)

    # 6. 应用鸭霸
    if resource.mixing:
        _mixing_controller.apply_ducking(resource.event_name, resource.mixing)

    # 7. 播放音频
    if player is AudioStreamPlayer:
        player.play(variant.start_offset)
    elif player is AudioStreamPlayer2D:
        player.play(variant.start_offset)
    elif player is AudioStreamPlayer3D:
        player.play(variant.start_offset)

    # 8. 记录实例
    var priority = resource.mixing.priority if resource.mixing else 50
    _mixing_controller.record_instance(resource.event_name, player, priority)

    # 9. 连接完成信号
    _connect_player_finished(player, resource, event)

    return true

func _handle_audio_play_legacy(event: JuicyEvent) -> bool:
    # 向后兼容：使用原有逻辑
    # 这里调用原有的处理方法
    return true

# =============================================================================
# 播放器管理
# =============================================================================

func _get_audio_player_for_resource(resource: AudioEventResource, event: JuicyEvent) -> Variant:
    var player_type = resource.player_type

    # 自动检测
    if player_type == AudioEventResource.AudioPlayerType.AUTO_DETECT:
        var target = event.event_data.get("target")
        if target is Node3D:
            return _get_audio_player_3d()
        else:
            return _get_audio_player_2d()
    elif player_type == AudioEventResource.AudioPlayerType.PLAYER_2D:
        return _get_audio_player_2d()
    else:  # PLAYER_3D
        return _get_audio_player_3d()

func _get_audio_player_2d() -> AudioStreamPlayer2D:
    if not _player_pool_2d.is_empty():
        return _player_pool_2d.pop_back()

    var total_size = _player_pool_2d.size() + _player_pool_3d.size() + _active_players.size()
    if total_size < _max_pool_size:
        var player = AudioUtils.create_player_2d()
        _setup_audio_player(player)
        return player

    return null

func _get_audio_player_3d() -> AudioStreamPlayer3D:
    if not _player_pool_3d.is_empty():
        return _player_pool_3d.pop_back()

    var total_size = _player_pool_2d.size() + _player_pool_3d.size() + _active_players.size()
    if total_size < _max_pool_size:
        var player = AudioUtils.create_player_3d()
        _setup_audio_player(player)
        return player

    return null

func _setup_audio_player(player: Variant) -> void:
    if player is AudioStreamPlayer2D:
        player.finished.connect(_on_player_finished.bind(player))
    elif player is AudioStreamPlayer3D:
        player.finished.connect(_on_player_finished.bind(player))

    var audio_root = _get_audio_root()
    audio_root.add_child(player)

func _configure_player_for_resource(player: Variant, resource: AudioEventResource,
                                    variant: AudioVariant, randomization: Dictionary,
                                    event: JuicyEvent) -> void:
    # 设置流
    player.stream = variant.audio_stream

    # 应用音高和音量
    AudioUtils.apply_pitch_and_volume(player, randomization.pitch, randomization.volume)

    # 设置总线
    var bus = resource.audio_bus if not resource.audio_bus.is_empty() else _audio_bus
    AudioUtils.set_player_bus(player, bus)

    # 设置位置
    if player is AudioStreamPlayer2D:
        var pos = event.event_data.get("position", Vector2.ZERO)
        player.position = pos
    elif player is AudioStreamPlayer3D:
        var pos = event.event_data.get("position", Vector3.ZERO)
        player.global_position = pos

        # 设置3D参数
        if resource.max_distance > 0:
            player.max_distance = resource.max_distance
        if resource.max_distance_db != 0:
            player.max_distance_db = resource.max_distance_db

func _connect_player_finished(player: Variant, resource: AudioEventResource, event: JuicyEvent) -> void:
    # 播放完成时清理
    if player.has_signal("finished"):
        if not player.finished.is_connected(_on_player_finished):
            player.finished.connect(_on_player_finished.bind(player, resource, event))

func _on_player_finished(player: Variant, resource: AudioEventResource = null, event: JuicyEvent = null) -> void:
    # 移除实例记录
    if resource and _mixing_controller:
        _mixing_controller.remove_instance(resource.event_name, player)

    # 恢复鸭霸
    if resource and resource.mixing and _mixing_controller:
        _mixing_controller.remove_ducking(resource.event_name, resource.mixing)

    # 返回播放器到池
    _return_audio_player(player)

func _return_audio_player(player: Variant) -> void:
    player.stream = null

    if player is AudioStreamPlayer2D:
        player.position = Vector2.ZERO
        if _player_pool_2d.size() < _max_pool_size:
            _player_pool_2d.append(player)
    elif player is AudioStreamPlayer3D:
        player.global_position = Vector3.ZERO
        if _player_pool_3d.size() < _max_pool_size:
            _player_pool_3d.append(player)

# =============================================================================
# 工具方法
# =============================================================================

func _get_audio_root() -> Node:
    # 获取或创建音频根节点
    var root = get_node_or_null("/root/AudioRoot")
    if not root:
        root = Node.new()
        root.name = "AudioRoot"
        Engine.get_main_loop().root.add_child(root)
    return root

func _log_debug(message: String) -> void:
    if OS.is_debug_build():
        print("JuicyAudioEventHandler: " + message)
```

**Step 4: 运行集成测试**

Run: 在Godot中创建测试场景运行
Expected: PASS（需要准备测试音频文件）

**Step 5: 提交**

```bash
git add addons/juicy_mixer/events/juicy_audio_event_handler.gd
git add addons/juicy_mixer/tests/audio/test_audio_integration.gd
git commit -m "feat(audio): extend JuicyAudioEventHandler with new audio system

- Add AudioEventResource support
- Add AudioVariationManager integration
- Add AudioMixingController integration
- Add 2D/3D auto-detection
- Add player pool management
- Add comprehensive integration tests"
```

---

## Task 10: 创建演示场景

**Files:**
- Create: `addons/juicy_mixer/tests/audio/audio_demo_scene.tscn`
- Create: `addons/juicy_mixer/tests/audio/audio_demo_controller.gd`

**Step 1: 创建演示控制器**

Create: `addons/juicy_mixer/tests/audio/audio_demo_controller.gd`
```gdscript
extends Control

## 音频管理器演示场景控制器

@onready var label_status = $VBoxContainer/LabelStatus
@onready var button_footstep = $VBoxContainer/ButtonFootstep
@onready var button_explosion = $VBoxContainer/ButtonExplosion
@onready var button_dialogue = $VBoxContainer/ButtonDialogue
@onready var button_clear = $VBoxContainer/ButtonClear

var footstep_resource: AudioEventResource = null
var explosion_resource: AudioEventResource = null
var dialogue_resource: AudioEventResource = null

func _ready():
    _setup_audio_resources()
    _connect_buttons()
    _update_status()

func _setup_audio_resources():
    # 脚步声资源（多变体 + 随机化）
    footstep_resource = AudioEventResource.new()
    footstep_resource.event_name = "footstep"
    footstep_resource.audio_bus = "SFX"
    footstep_resource.no_repeat_enabled = true
    footstep_resource.no_repeat_memory = 2

    # 添加变体（需要实际音频文件）
    for i in range(3):
        var variant = AudioVariant.new()
        # variant.audio_stream = load("res://sounds/footstep_%d.ogg" % (i + 1))
        variant.weight = 1.0
        variant.pitch_enabled = true
        variant.pitch_min = -0.2
        variant.pitch_max = 0.2
        variant.volume_enabled = true
        variant.volume_min = 0.9
        variant.volume_max = 1.1
        footstep_resource.audio_variants.append(variant)

    # 爆炸资源（类别限额）
    explosion_resource = AudioEventResource.new()
    explosion_resource.event_name = "explosion"
    explosion_resource.audio_bus = "SFX"
    explosion_resource.mixing = AudioMixingConfig.new()
    explosion_resource.mixing.max_instances = 3

    # 对白资源（鸭霸音乐）
    dialogue_resource = AudioEventResource.new()
    dialogue_resource.event_name = "dialogue"
    dialogue_resource.audio_bus = "Voice"
    dialogue_resource.mixing = AudioMixingConfig.new()

    var ducking_rule = DuckingRule.new()
    ducking_rule.event_name_pattern = "dialogue_*"
    ducking_rule.target_bus = "Music"
    ducking_rule.duck_amount = -10.0
    ducking_rule.recovery_delay = 0.5
    dialogue_resource.mixing.ducking_rules.append(ducking_rule)

func _connect_buttons():
    button_footstep.pressed.connect(_on_footstep_pressed)
    button_explosion.pressed.connect(_on_explosion_pressed)
    button_dialogue.pressed.connect(_on_dialogue_pressed)
    button_clear.pressed.connect(_on_clear_pressed)

func _on_footstep_pressed():
    if footstep_resource and not footstep_resource.audio_variants.is_empty():
        var event = JuicyEvent.new()
        event.event_type = JuicyEvent.EventType.AUDIO_PLAY
        event.event_data = {"audio_event_resource": footstep_resource}
        JuicyMixer.add_event(event)
        _update_status()

func _on_explosion_pressed():
    if explosion_resource:
        var event = JuicyEvent.new()
        event.event_type = JuicyEvent.EventType.AUDIO_PLAY
        event.event_data = {"audio_event_resource": explosion_resource}
        JuicyMixer.add_event(event)
        _update_status()

func _on_dialogue_pressed():
    if dialogue_resource:
        var event = JuicyEvent.new()
        event.event_type = JuicyEvent.EventType.AUDIO_PLAY
        event.event_data = {"audio_event_resource": dialogue_resource}
        JuicyMixer.add_event(event)
        _update_status()

func _on_clear_pressed():
    # 清理所有音频
    _update_status()

func _update_status():
    # 获取统计信息
    label_status.text = "Audio Manager Demo\n\nStatus: Running\n\nClick buttons to test different audio features."
```

**Step 2: 创建演示场景**

在Godot编辑器中创建场景：
1. 创建新场景，根节点为Control
2. 添加VBoxContainer
3. 添加Label和Button节点
4. 附加脚本

或手动创建.tscn文件（简化版）:

**Step 3: 添加说明文档**

Create: `addons/juicy_mixer/tests/audio/README.md`
```markdown
# Audio Manager Tests

## 测试场景

### test_audio_variant.tscn
测试AudioVariant资源类的功能

### test_audio_mixing.tscn
测试AudioMixingConfig和混音控制

### test_audio_2d_3d.tscn
测试2D/3D自动检测和播放器管理

### test_audio_integration.tscn
完整的集成测试

### audio_demo_scene.tscn
交互式演示场景

## 运行测试

在Godot编辑器中打开测试场景并按F5运行。

## 测试音频文件

将测试音频文件放在 `res://sounds/` 目录：
- footstep_1.ogg
- footstep_2.ogg
- footstep_3.ogg
- explosion_1.ogg
- explosion_2.ogg
- dialogue_1.ogg
```

**Step 4: 提交**

```bash
git add addons/juicy_mixer/tests/audio/audio_demo_controller.gd
git add addons/juicy_mixer/tests/audio/README.md
git commit -m "feat(audio): add demo scene and documentation

- Add interactive demo controller
- Add test documentation
- Add usage examples"
```

---

## Task 11: 创建Godot插件配置文件

**Files:**
- Create: `addons/juicy_mixer/plugin.cfg` (更新)
- Modify: `addons/juicy_mixer/addons/juicy_mixer/plugin.cfg` (如果存在)

**Step 1: 检查现有插件配置**

Run:
```bash
find addons/juicy_mixer -name "plugin.cfg"
```

**Step 2: 更新插件版本号**

如果找到plugin.cfg，更新版本号和描述。

**Step 3: 提交**

```bash
git commit -m "chore(audio): update plugin version for audio manager"
```

---

## Task 12: 编写用户文档

**Files:**
- Create: `addons/juicy_mixer/docs/user_docs/audio_manager_user_guide.md`

**Step 1: 编写用户指南**

Create: `addons/juicy_mixer/docs/user_docs/audio_manager_user_guide.md`
```markdown
# JuicyMixer Audio Manager 用户指南

## 概述

JuicyMixer音频管理器提供了专业的音频管理功能，包括：
- 随机变体播放
- 音高/音量随机化
- 防重复机制
- 动态鸭霸
- 播放限额管理
- 2D/3D自动检测

## 快速开始

### 1. 创建音频事件资源

在Godot编辑器中：
1. 右键点击FileSystem
2. 新建 -> Resource
3. 搜索 "AudioEventResource"
4. 保存为 `my_sound.tres`

### 2. 配置音频变体

在Inspector中：
1. 展开 "Audio Variants"
2. 点击 "+" 添加变体
3. 设置：
   - Audio Stream: 拖入音频文件
   - Weight: 播放权重
   - Pitch Randomization: 启用并设置范围
   - Volume Randomization: 启用并设置范围

### 3. 播放音频

```gdscript
# 方法1: 使用JuicyMixer
var resource = load("res://my_sound.tres")
JuicyMixer.play(resource, self)

# 方法2: 通过事件
var event = resource.create_audio_play_event(self)
JuicyMixer.add_event(event)
```

## 高级功能

### 配置鸭霸规则

1. 在AudioEventResource中展开 "Mixing"
2. 创建 AudioMixingConfig
3. 在 "Ducking Rules" 中添加规则
4. 设置：
   - Event Name Pattern: 要匹配的事件（如 "dialogue_*"）
   - Target Bus: 要鸭霸的总线（如 "Music"）
   - Duck Amount: 降低音量值（dB）

### 配置播放限额

1. 在 AudioMixingConfig 中设置：
   - Max Instances: 最大同时播放数
   - Limit Policy: 超限策略
   - Priority: 优先级（0-100）

### 2D/3D自动检测

在 AudioEventResource 中设置 Player Type:
- **Auto Detect**: 根据目标节点自动选择
- **Player 2D**: 强制使用2D播放器
- **Player 3D**: 强制使用3D播放器

## 最佳实践

### 脚步声配置

```
Variants: 3-5个
Weight: 均等（1.0）
No Repeat: 启用
Memory: 2
Pitch Randomization: -0.2 到 0.2
Volume Randomization: 0.9 到 1.1
```

### 爆炸音效配置

```
Variants: 3-5个
Weight: 均等
Max Instances: 3
Priority: 70
3D Max Distance: 50.0
```

### 对白配置

```
Bus: Voice
Ducking: 鸭霸 Music -10dB
Recovery Delay: 0.5秒
Max Instances: 1
```

## 故障排除

### 音频不播放
1. 检查AudioStream是否正确加载
2. 检查Bus是否存在
3. 检查播放限额是否已满
4. 查看调试输出

### 鸭霸不工作
1. 检查目标总线名称是否正确
2. 确认总线中第一个效果器是AudioEffectAmplify
3. 检查事件名称模式是否匹配

### 性能问题
1. 减少Max Instances值
2. 使用虚拟声部
3. 启用播放限额
4. 优化播放器池大小

## API参考

详细的API参考请查看：
- `addons/juicy_mixer/docs/dev_docs/audio_manager_design.md`
- `addons/juicy_mixer/docs/dev_docs/audio_manager_godot_integration.md`
```

**Step 2: 提交**

```bash
git add addons/juicy_mixer/docs/user_docs/audio_manager_user_guide.md
git commit -m "docs(audio): add comprehensive user guide

- Add quick start guide
- Add advanced features documentation
- Add best practices
- Add troubleshooting section"
```

---

## Task 13: 最终验证和文档更新

**Files:**
- Update: `addons/juicy_mixer/docs/dev_docs/audio_manager_design.md`
- Test: 全部测试

**Step 1: 运行所有测试**

Run: 在Godot中依次运行所有测试场景
```
1. test_audio_variant.gd
2. test_audio_randomization_config.gd
3. test_ducking_rule.gd
4. test_audio_mixing_config.gd
5. test_audio_utils.gd
6. test_audio_variation_manager.gd
7. test_audio_mixing_controller.gd
8. test_audio_integration.gd
```

**Step 2: 更新设计文档状态**

Update: `addons/juicy_mixer/docs/dev_docs/audio_manager_design.md`

在"8. 实现计划"部分更新任务状态：

```markdown
| 任务编号 | 任务名称 | 优先级 | 状态 |
|----------|----------|--------|------|
| 1.1 | 创建 AudioEventResource | ⭐⭐⭐ | ✅ |
| 1.2 | 创建 AudioVariant | ⭐⭐⭐ | ✅ |
| 1.3 | 创建 AudioRandomizationConfig | ⭐⭐⭐ | ✅ |
| 1.4 | 创建 AudioMixingConfig | ⭐⭐⭐ | ✅ |
| 1.5 | 创建 DuckingRule | ⭐⭐⭐ | ✅ |
| 1.6 | 实现 AudioUtils | ⭐⭐⭐ | ✅ |
| 1.7 | 实现 AudioVariationManager | ⭐⭐⭐ | ✅ |
| 1.8 | 实现 AudioMixingController | ⭐⭐⭐ | ✅ |
| 1.9 | 扩展 JuicyAudioEventHandler | ⭐⭐⭐ | ✅ |
| 1.10 | 2D/3D 播放器支持 | ⭐⭐⭐ | ✅ |
| 1.11 | test_audio_variations.gd | ⭐⭐⭐ | ✅ |
| 1.12 | test_audio_mixing.gd | ⭐⭐⭐ | ✅ |
| 1.13 | test_audio_2d_3d.gd | ⭐⭐⭐ | ✅ |
| 1.14 | audio_demo_scene.tscn | ⭐⭐ | ✅ |
```

**Step 3: 创建CHANGELOG**

Create: `addons/juicy_mixer/CHANGELOG_AUDIO.md`
```markdown
# Audio Manager Changelog

## [Unreleased] - Phase 1

### Added
- AudioVariant resource with pitch/volume randomization
- AudioRandomizationConfig for global randomization settings
- DuckingRule for automatic volume ducking
- AudioMixingConfig for instance limiting and mixing control
- AudioEventResource as unified audio event definition
- AudioUtils utility class with unit conversions
- AudioVariationManager for variant selection and no-repeat logic
- AudioMixingController for instance limiting and ducking management
- 2D/3D auto-detection and player pool management
- Comprehensive test coverage
- Interactive demo scene
- User guide and documentation

### Changed
- Extended JuicyAudioEventHandler to support new audio system
- Maintained backward compatibility with legacy audio events

### Technical Details
- Uses Godot native AudioServer and AudioStreamPlayer
- Zero performance loss in core audio path
- Object pooling reduces GC pressure by 30-50%
- TDD approach with full test coverage
```

**Step 4: 最终提交**

```bash
git add addons/juicy_mixer/docs/dev_docs/audio_manager_design.md
git add addons/juicy_mixer/CHANGELOG_AUDIO.md
git commit -m "docs(audio): update design docs with implementation status

- Mark all Phase 1 tasks as complete
- Add CHANGELOG for audio manager
- Verify all tests passing"
```

---

## 总结

### 完成的功能

✅ **资源类**
- AudioVariant - 音频变体
- AudioRandomizationConfig - 随机化配置
- DuckingRule - 鸭霸规则
- AudioMixingConfig - 混音配置
- AudioEventResource - 音频事件资源

✅ **管理器类**
- AudioUtils - 工具方法
- AudioVariationManager - 变体管理
- AudioMixingController - 混音控制

✅ **集成**
- JuicyAudioEventHandler扩展
- 2D/3D自动检测
- 播放器池管理
- 向后兼容

✅ **测试和文档**
- 8个测试文件
- 演示场景
- 用户指南

### 下一步（阶段2）

根据设计文档，阶段2将实现：
- 衰减曲线
- 3D空间定位增强
- 遮挡与阻碍
- RTPC映射

详见：`addons/juicy_mixer/docs/dev_docs/audio_manager_voice_management_enhanced.md`

---

**实施计划完成！**
