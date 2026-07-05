# Audio Manager 三层架构完整实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**目标:** 实现专业级音频管理器的三层限额架构（实例级、类别级、全局级），修复现有 bug，添加完整的虚声部系统、相位保护和智能优先级排序。

**架构策略:** 基于设计文档 `audio_manager_voice_management_enhanced.md`，分四个阶段实施：
1. **Phase 1 (P0)**: 修复关键枚举 bug 和虚声部属性缺失
2. **Phase 2 (P1)**: 扩展实例级策略（7种策略 + 相位保护）
3. **Phase 3 (P1)**: 实现类别级限额系统（AudioCategory + 智能排序）
4. **Phase 4 (P2)**: 实现全局级限额系统（GlobalAudioLimitConfig + VirtualVoiceManager）

**技术栈:** Godot 4.5, GDScript 2.0, Resource 系统, RefCounted, TDD 工作流

**重要提醒:** 每创建新类都要在 `plugin.gd` 中注册！

---

## Phase 1: 关键 Bug 修复 (P0 - 必须立即修复)

### Task 1.1: 修复枚举不匹配 Bug

**问题:** `AudioMixingConfig` 使用 `LimitPolicy`，但 `AudioMixingController` 期望 `InstanceLimitPolicy`，导致运行时错误。

**Files:**
- Modify: `addons/juicy_mixer/resources/audio/audio_mixing_config.gd:19-24`
- Modify: `addons/juicy_mixer/core/audio/audio_mixing_controller.gd:48-61`
- Test: `addons/juicy_mixer/tests/audio/test_audio_mixing_config.gd` (验证枚举值正确)

#### Step 1: 扩展 LimitPolicy 枚举为 7 种策略

在 `audio_mixing_config.gd` 中：

```gdscript
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
```

**替换位置:** 第 19-24 行，完全替换现有的 `enum LimitPolicy`

#### Step 2: 更新 _get_policy_string 方法

在 `audio_mixing_config.gd` 的 `_get_policy_string` 方法中：

```gdscript
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
```

**替换位置:** 第 273-282 行

#### Step 3: 验证枚举值

运行测试验证枚举正确：

```bash
# 在 Godot 编辑器中运行测试场景
# 或使用命令行（如果配置了）
```

**预期结果:** 枚举有 7 个值，值从 0 到 6

#### Step 4: 更新 AudioMixingController 匹配逻辑

在 `audio_mixing_controller.gd` 的 `can_play` 方法中，确保匹配所有 7 种策略：

```gdscript
# 超限处理
match config.limit_policy:
    config.LimitPolicy.FIFO:  # STOP_OLDEST
        _stop_oldest_in_instance(event_name)
        return true
    config.LimitPolicy.LIFO:  # STOP_NEWEST
        return false
    config.LimitPolicy.PRIORITY:
        _stop_lowest_priority_in_instance(event_name)
        return true
    config.LimitPolicy.NEWEST_STEALS_OLDEST:
        _stop_oldest_in_instance(event_name)
        return true
    config.LimitPolicy.FADE_OUT_OLDEST:
        _fade_out_oldest_in_instance(event_name, 0.1)
        return true
    config.LimitPolicy.FADE_IN_NEWEST:
        # 淡入需要异步处理，这里简化为直接播放
        return true
    config.LimitPolicy.CROSSFADE:
        # 暂时简化为直接播放（后续实现）
        return true
    _:
        return true
```

**替换位置:** 第 48-61 行

#### Step 5: 添加淡出辅助方法

在 `audio_mixing_controller.gd` 中添加：

```gdscript
## 淡出最老的实例
func _fade_out_oldest_in_instance(event_name: String, fade_duration: float) -> void:
    var instances = _active_instances.get(event_name, [])
    if instances.is_empty():
        return

    var oldest = instances[0]
    var player = oldest.player

    # 应用淡出效果
    if player.has_method("set_volume_db"):
        var original_volume = player.get("volume_db") if player.has_property("volume_db") else 0.0
        var tween = create_tween()
        tween.parallel().tween_property(player, "volume_db", -80.0, fade_duration)
        tween.tween_callback(_stop_player.bind(player))
```

**添加位置:** 在 `_stop_oldest_in_instance` 方法之后

#### Step 6: 提交修复

```bash
git add addons/juicy_mixer/resources/audio/audio_mixing_config.gd
git add addons/juicy_mixer/core/audio/audio_mixing_controller.gd
git commit -m "fix(audio): 修复枚举不匹配bug并扩展为7种策略

- 将 LimitPolicy 扩展为 7 种策略
- 添加 NEWEST_STEALS_OLDEST, FADE_OUT_OLDEST, FADE_IN_NEWEST, CROSSFADE
- 更新 _get_policy_string 方法支持所有新策略
- 修复 AudioMixingController 匹配逻辑
- 添加 _fade_out_oldest_in_instance 辅助方法

相关设计文档: audio_manager_voice_management_enhanced.md
Bug: AudioMixingConfig 和 AudioMixingController 枚举不匹配导致运行时错误

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 1.2: 添加缺失的虚声部属性

**问题:** `AudioMixingController.should_play_virtual` 引用了 `resource.virtual_voice_enabled`，但该属性不存在。

**Files:**
- Modify: `addons/juicy_mixer/resources/audio/audio_event_resource.gd:46` (在 mixing 配置后添加)
- Test: `addons/juicy_mixer/tests/audio/test_audio_event_resource.gd`

#### Step 1: 在 AudioEventResource 中添加虚声部属性

在 `audio_event_resource.gd` 的混音配置部分后添加：

```gdscript
# =============================================================================
# 虚声部配置
# =============================================================================

@export_group("Virtual Voice", "virtual_")
@export var virtual_voice_enabled: bool = true
@export var virtual_max_distance: float = 50.0
@export var virtual_min_importance: int = 30
```

**添加位置:** 第 46 行之后（`mixing: AudioMixingConfig = null` 之后）

#### Step 2: 添加验证方法

在 `AudioEventResource` 的 `validate()` 方法中添加虚声部验证：

```gdscript
func validate() -> Dictionary:
    var result = {
        "valid": true,
        "issues": [],
        "warnings": []
    }

    if audio_variants.is_empty():
        result.issues.append("No audio variants defined")
        result.valid = false

    # 验证虚声部配置
    if virtual_voice_enabled:
        if virtual_max_distance <= 0.0:
            result.warnings.append("virtual_max_distance should be positive")

        if virtual_min_importance < 0 or virtual_min_importance > 100:
            result.warnings.append("virtual_min_importance should be between 0 and 100")

    return result
```

**替换位置:** 第 77-88 行

#### Step 3: 编写测试验证虚声部属性

创建测试文件 `test_audio_event_resource.gd`：

```gdscript
extends Node

func test_virtual_voice_properties():
    var event = AudioEventResource.new()

    # 验证默认值
    assert(event.virtual_voice_enabled == true, "Default virtual_voice_enabled should be true")
    assert(event.virtual_max_distance == 50.0, "Default virtual_max_distance should be 50.0")
    assert(event.virtual_min_importance == 30, "Default virtual_min_importance should be 30")

    # 验证可以设置
    event.virtual_voice_enabled = false
    event.virtual_max_distance = 100.0
    event.virtual_min_importance = 50

    assert(event.virtual_voice_enabled == false, "virtual_voice_enabled should be false")
    assert(event.virtual_max_distance == 100.0, "virtual_max_distance should be 100.0")
    assert(event.virtual_min_importance == 50, "virtual_min_importance should be 50")

    print("test_virtual_voice_properties PASSED")

func test_virtual_voice_validation():
    var event = AudioEventResource.new()
    event.audio_variants = [AudioVariant.new()]

    # 有效配置
    var result = event.validate()
    assert(result.valid == true, "Valid configuration should pass")
    assert(result.warnings.is_empty(), "Valid config should have no warnings")

    # 无效配置
    event.virtual_max_distance = -10.0
    result = event.validate()
    assert(result.warnings.size() > 0, "Invalid max_distance should generate warning")

    print("test_virtual_voice_validation PASSED")
```

**创建位置:** `addons/juicy_mixer/tests/audio/test_audio_event_resource.gd`

#### Step 4: 运行测试

在 Godot 编辑器中：
1. 打开测试场景 `addons/juicy_mixer/tests/audio/test_audio_event_resource.tscn`
2. 按 F5 运行场景
3. 检查控制台输出

**预期结果:**
```
test_virtual_voice_properties PASSED
test_virtual_voice_validation PASSED
```

#### Step 5: 提交

```bash
git add addons/juicy_mixer/resources/audio/audio_event_resource.gd
git add addons/juicy_mixer/tests/audio/test_audio_event_resource.gd
git commit -m "feat(audio): 添加虚声部配置属性到 AudioEventResource

- 添加 virtual_voice_enabled, virtual_max_distance, virtual_min_importance 属性
- 在 validate() 方法中添加虚声部配置验证
- 创建测试验证虚声部属性功能
- 修复 AudioMixingController.should_play_virtual 引用不存在的属性 bug

相关设计文档: audio_manager_voice_management_enhanced.md § 3.3.1

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Phase 2: 扩展实例级策略 (P1)

### Task 2.1: 实现相位保护机制

**目标:** 添加相位保护（anti-phase-cancellation），防止高频重复音效产生相位抵消。

**Files:**
- Modify: `addons/juicy_mixer/resources/audio/audio_event_resource.gd` (添加相位保护属性)
- Modify: `addons/juicy_mixer/core/audio/audio_mixing_controller.gd` (实现相位检查逻辑)
- Test: `addons/juicy_mixer/tests/audio/test_phase_protection.gd`

#### Step 1: 在 AudioEventResource 添加相位保护属性

在虚声部配置后添加：

```gdscript
# =============================================================================
# 相位保护配置
# =============================================================================

@export_group("Phase Protection", "phase_")
@export var anti_phase_cancellation: bool = false
@export_range(0.001, 1.0, 0.001) var phase_cooldown: float = 0.05

# 运行时状态（不导出）
var _last_play_time: float = 0.0
```

**添加位置:** `audio_event_resource.gd` 虚声部配置之后

#### Step 2: 在 AudioMixingController 实现相位检查

修改 `can_play` 方法，在实例级检查之前添加相位保护：

```gdscript
func can_play(resource: AudioEventResource, event_name: String) -> bool:
    if not resource or not resource.mixing:
        return true

    # 0. 相位保护检查（在实例级检查之前）
    if resource.anti_phase_cancellation:
        var current_time = Time.get_ticks_msec() / 1000.0
        var time_since_last = current_time - resource._last_play_time

        if time_since_last < resource.phase_cooldown:
            _log_debug("Phase cooldown active: %.3f < %.3f" % [time_since_last, resource.phase_cooldown])
            return false

        resource._last_play_time = current_time

    # 原有的实例级检查...
    var config = resource.mixing
    var instances = _active_instances.get(event_name, [])

    # 统计活跃实例
    var active_count = 0
    for instance_info in instances:
        if is_instance_valid(instance_info.player):
            active_count += 1

    if active_count < config.max_instances:
        return true

    # 超限处理...（保持原逻辑）
```

**修改位置:** `audio_mixing_controller.gd` 的 `can_play` 方法开头

#### Step 3: 添加 _log_debug 辅助方法

在 `AudioMixingController` 中添加：

```gdscript
func _log_debug(message: String) -> void:
    if OS.is_debug_build():
        print("[AudioMixingController] ", message)
```

**添加位置:** 类的私有方法区域

#### Step 4: 编写相位保护测试

创建 `test_phase_protection.gd`：

```gdscript
extends Node

func test_phase_cooldown_blocks_fast_repeats():
    var resource = AudioEventResource.new()
    resource.event_name = "test_phase"
    resource.anti_phase_cancellation = true
    resource.phase_cooldown = 0.1  # 100ms

    var config = AudioMixingConfig.new()
    config.max_instances = 10
    resource.mixing = config

    var controller = AudioMixingController.new()

    # 第一次播放应该通过
    assert(controller.can_play(resource, "test_phase") == true, "First play should pass")
    controller.record_instance("test_phase", AudioStreamPlayer2D.new(), 50)

    # 立即第二次播放应该被阻止
    assert(controller.can_play(resource, "test_phase") == false, "Immediate second play should be blocked")

    # 等待冷却时间后应该可以通过
    await get_tree().create_timer(0.15).timeout  # 等待 150ms
    assert(controller.can_play(resource, "test_phase") == true, "Play after cooldown should pass")

    print("test_phase_cooldown_blocks_fast_repeats PASSED")

func test_phase_protection_disabled():
    var resource = AudioEventResource.new()
    resource.event_name = "test_no_phase"
    resource.anti_phase_cancellation = false  # 禁用相位保护

    var config = AudioMixingConfig.new()
    config.max_instances = 10
    resource.mixing = config

    var controller = AudioMixingController.new()

    # 连续播放都应该通过
    assert(controller.can_play(resource, "test_no_phase") == true, "First play should pass")
    assert(controller.can_play(resource, "test_no_phase") == true, "Second play should also pass")
    assert(controller.can_play(resource, "test_no_phase") == true, "Third play should also pass")

    print("test_phase_protection_disabled PASSED")
```

**创建位置:** `addons/juicy_mixer/tests/audio/test_phase_protection.gd`

#### Step 5: 创建测试场景

创建 `test_phase_protection.tscn`：

```gdscript
[gd_scene load_steps=2 format=3 uid="uid://test_phase_protection"]

[ext_resource type="Script" path="res://addons/juicy_mixer/tests/audio/test_phase_protection.gd" id="1"]

[node name="TestPhaseProtection" type="Node"]
script = ExtResource("1")
```

**创建位置:** `addons/juicy_mixer/tests/audio/test_phase_protection.tscn`

#### Step 6: 运行测试

在 Godot 编辑器中运行测试场景。

**预期结果:**
```
test_phase_cooldown_blocks_fast_repeats PASSED
test_phase_protection_disabled PASSED
```

#### Step 7: 提交

```bash
git add addons/juicy_mixer/resources/audio/audio_event_resource.gd
git add addons/juicy_mixer/core/audio/audio_mixing_controller.gd
git add addons/juicy_mixer/tests/audio/test_phase_protection.gd
git add addons/juicy_mixer/tests/audio/test_phase_protection.tscn
git commit -m "feat(audio): 实现相位保护机制防止高频音效相位抵消

- 添加 anti_phase_cancellation 和 phase_cooldown 属性
- 在 can_play() 中实现相位冷却检查
- 添加 _last_play_time 运行时状态追踪
- 创建完整测试验证相位保护功能
- 添加 _log_debug 辅助方法

适用场景：机枪、连招、高频脚步声等快速重复音效
相关设计文档: audio_manager_voice_management_enhanced.md § 3.1.2

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 2.2: 实现 FADE_OUT_OLDEST 完整逻辑

**目标:** 完整实现淡出最老实例的策略（Task 1.1 中只添加了占位代码）。

**Files:**
- Modify: `addons/juicy_mixer/core/audio/audio_mixing_controller.gd`
- Test: `addons/juicy_mixer/tests/audio/test_fade_strategies.gd`

#### Step 1: 实现 _fade_out_oldest_in_instance 方法

替换之前添加的占位方法：

```gdscript
## 淡出最老的实例
func _fade_out_oldest_in_instance(event_name: String, fade_duration: float) -> void:
    var instances = _active_instances.get(event_name, [])
    if instances.is_empty():
        return

    # 找到最老的活跃实例
    for instance_info in instances:
        if is_instance_valid(instance_info.player):
            var player = instance_info.player

            # 创建 Tween 实现淡出
            var tween = create_tween()

            # 获取当前音量
            var current_volume_db = 0.0
            if player.has_method("get_volume_db"):
                current_volume_db = player.get_volume_db()
            elif player.has_property("volume_db"):
                current_volume_db = player.get("volume_db")

            # 淡出到 -80dB（无声）
            tween.parallel().tween_property(player, "volume_db", -80.0, fade_duration)
            tween.tween_callback(_stop_player.bind(player))

            _log_debug("Fading out oldest instance over %.2f seconds" % fade_duration)
            break
```

**替换位置:** `audio_mixing_controller.gd` 中的 `_fade_out_oldest_in_instance` 方法

#### Step 2: 添加 Tween 创建辅助方法

```gdscript
func create_tween() -> Tween:
    var tween = Tween.new()
    var scene_root = Engine.get_main_loop().current_scene
    scene_root.add_child(tween)
    return tween
```

**添加位置:** `audio_mixing_controller.gd` 私有方法区域

#### Step 3: 编写淡出策略测试

创建 `test_fade_strategies.gd`：

```gdscript
extends Node

func test_fade_out_oldest_strategy():
    var resource = AudioEventResource.new()
    resource.event_name = "test_fade"

    var config = AudioMixingConfig.new()
    config.max_instances = 2
    config.limit_policy = AudioMixingConfig.LimitPolicy.FADE_OUT_OLDEST
    resource.mixing = config

    var controller = AudioMixingController.new()

    # 添加两个实例
    var player1 = AudioStreamPlayer2D.new()
    var player2 = AudioStreamPlayer2D.new()
    controller.record_instance("test_fade", player1, 50)
    controller.record_instance("test_fade", player2, 50)

    # 第三个实例应该触发淡出最老的
    assert(controller.can_play(resource, "test_fade") == true, "Should allow play with fade strategy")

    print("test_fade_out_oldest_strategy PASSED")
```

**创建位置:** `addons/juicy_mixer/tests/audio/test_fade_strategies.gd`

#### Step 4: 运行测试

**预期结果:** 测试通过，控制台显示 "Fading out oldest instance..."

#### Step 5: 提交

```bash
git add addons/juicy_mixer/core/audio/audio_mixing_controller.gd
git add addons/juicy_mixer/tests/audio/test_fade_strategies.gd
git commit -m "feat(audio): 实现完整的淡出策略

- 完善 _fade_out_oldest_in_instance 方法实现
- 添加 create_tween 辅助方法创建 Tween
- 自动淡出到 -80dB 后停止播放
- 创建测试验证淡出策略

相关设计文档: audio_manager_voice_management_enhanced.md § 3.1.1

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Phase 3: 类别级限额系统 (P1)

### Task 3.1: 创建 AudioCategory 资源类

**目标:** 实现类别管理，允许对相似音效（如"爆炸"、"脚步声"）统一管理限额。

**Files:**
- Create: `addons/juicy_mixer/resources/audio/audio_category.gd`
- Create: `addons/juicy_mixer/tests/audio/test_audio_category.gd`
- Modify: `addons/juicy_mixer/plugin.gd` (注册新类)

#### Step 1: 创建 AudioCategory 类

创建 `audio_category.gd`：

```gdscript
@tool
class_name AudioCategory
extends Resource

## 音频类别配置
##
## 用于对相似音效进行分组管理（如爆炸、脚步声、受击等）
## 实现类别级别的播放限额和智能优先级排序

# =============================================================================
# 枚举
# =============================================================================

## 类别优先级
enum AudioCategoryPriority {
    CRITICAL = 90,   # 关键（对白、UI 反馈）
    HIGH = 70,       # 高（玩家受击、重要音效）
    MEDIUM = 50,     # 中（环境音效、次要音效）
    LOW = 30,        # 低（背景噪音、装饰音效）
    VERY_LOW = 10    # 极低（碎片、杂物）
}

# =============================================================================
# 类别配置
# =============================================================================

@export_group("Category Configuration")

## 类别名称（如 "Explosions", "Footsteps", "Hit"）
@export var category_name: String = ""

## 类别最大播放实例数
@export_range(1, 50, 1) var max_instances: int = 5

## 类别优先级
@export var category_priority: AudioCategoryPriority = AudioCategoryPriority.MEDIUM

# =============================================================================
# 智能排序配置
# =============================================================================

@export_group("Priority Factors")

## 距离权重（0.0 - 1.0）
@export_range(0.0, 1.0, 0.05) var distance_weight: float = 0.4

## 重要性权重（0.0 - 1.0）
@export_range(0.0, 1.0, 0.05) var importance_weight: float = 0.4

## 最近播放时间权重（0.0 - 1.0）
@export_range(0.0, 1.0, 0.05) var recency_weight: float = 0.2

## 共享总线（可选）
@export var shared_bus: String = ""

# =============================================================================
# 公共方法
# =============================================================================

## 获取优先级因子的字典表示
func get_priority_factors() -> Dictionary:
    return {
        "distance_weight": distance_weight,
        "importance_weight": importance_weight,
        "recency_weight": recency_weight
    }

## 验证类别配置
func validate() -> Dictionary:
    var result = {
        "valid": true,
        "issues": [],
        "warnings": []
    }

    if category_name.is_empty():
        result.issues.append("Category name cannot be empty")
        result.valid = false

    if max_instances <= 0:
        result.issues.append("max_instances must be positive")
        result.valid = false

    # 验证权重总和
    var weight_sum = distance_weight + importance_weight + recency_weight
    if abs(weight_sum - 1.0) > 0.01:
        result.warnings.append("Priority weights should sum to 1.0 (current: %.2f)" % weight_sum)

    return result

## 克隆类别
func clone() -> AudioCategory:
    var clone = AudioCategory.new()
    clone.category_name = category_name
    clone.max_instances = max_instances
    clone.category_priority = category_priority
    clone.distance_weight = distance_weight
    clone.importance_weight = importance_weight
    clone.recency_weight = recency_weight
    clone.shared_bus = shared_bus
    return clone
```

**创建位置:** `addons/juicy_mixer/resources/audio/audio_category.gd`

#### Step 2: 在 plugin.gd 中注册 AudioCategory

在 `plugin.gd` 的 `_enter_tree()` 方法中，音频管理器资源类型部分添加：

```gdscript
# 在 AudioEventResource 注册之后添加

add_custom_type(
    "AudioCategory",
    "Resource",
    preload("res://addons/juicy_mixer/resources/audio/audio_category.gd"),
    preload("res://icon.svg")
)
```

**添加位置:** `plugin.gd` 第 287 行之后（AudioEventResource 注册之后）

#### Step 3: 在 plugin.gd 的 _exit_tree() 中添加移除代码

在 `_exit_tree()` 方法中，音频管理器资源类型部分添加：

```gdscript
# 在 AudioEventResource 之后添加

remove_custom_type("AudioCategory")
```

**添加位置:** `plugin.gd` 第 443 行之后

#### Step 4: 编写 AudioCategory 测试

创建 `test_audio_category.gd`：

```gdscript
extends Node

func test_category_creation():
    var category = AudioCategory.new()

    # 设置类别
    category.category_name = "Explosions"
    category.max_instances = 3
    category.category_priority = AudioCategory.AudioCategoryPriority.HIGH

    # 验证
    assert(category.category_name == "Explosions", "Category name should be Explosions")
    assert(category.max_instances == 3, "Max instances should be 3")
    assert(category.category_priority == AudioCategory.AudioCategoryPriority.HIGH, "Priority should be HIGH")

    print("test_category_creation PASSED")

func test_category_validation():
    var category = AudioCategory.new()

    # 空名称应该失败
    var result = category.validate()
    assert(result.valid == false, "Empty category name should be invalid")
    assert(result.issues.size() > 0, "Should have issues")

    # 有效配置
    category.category_name = "Footsteps"
    category.max_instances = 5
    result = category.validate()
    assert(result.valid == true, "Valid category should pass")

    print("test_category_validation PASSED")

func test_priority_factors():
    var category = AudioCategory.new()

    # 设置权重
    category.distance_weight = 0.5
    category.importance_weight = 0.3
    category.recency_weight = 0.2

    var factors = category.get_priority_factors()
    assert(factors.distance_weight == 0.5, "Distance weight should be 0.5")
    assert(factors.importance_weight == 0.3, "Importance weight should be 0.3")
    assert(factors.recency_weight == 0.2, "Recency weight should be 0.2")

    print("test_priority_factors PASSED")
```

**创建位置:** `addons/juicy_mixer/tests/audio/test_audio_category.gd`

#### Step 5: 创建测试场景

创建 `test_audio_category.tscn`：

```gdscript
[gd_scene load_steps=2 format=3 uid="uid://test_audio_category"]

[ext_resource type="Script" path="res://addons/juicy_mixer/tests/audio/test_audio_category.gd" id="1"]

[node name="TestAudioCategory" type="Node"]
script = ExtResource("1")
```

#### Step 6: 运行测试

**预期结果:**
```
test_category_creation PASSED
test_category_validation PASSED
test_priority_factors PASSED
```

#### Step 7: 提交

```bash
git add addons/juicy_mixer/resources/audio/audio_category.gd
git add addons/juicy_mixer/plugin.gd
git add addons/juicy_mixer/tests/audio/test_audio_category.gd
git add addons/juicy_mixer/tests/audio/test_audio_category.tscn
git commit -m "feat(audio): 创建 AudioCategory 资源类实现类别级限额

- 添加 AudioCategory 类支持类别分组管理
- 实现 AudioCategoryPriority 枚举（CRITICAL 到 VERY_LOW）
- 添加可配置的优先级因子（距离、重要性、时间权重）
- 在 plugin.gd 中注册 AudioCategory 类
- 创建完整测试验证类别功能

相关设计文档: audio_manager_voice_management_enhanced.md § 3.2.1
用途: 对爆炸、脚步声等相似音效统一管理播放限额

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 3.2: 在 AudioEventResource 中集成类别系统

**目标:** 允许 AudioEventResource 关联一个或多个 AudioCategory。

**Files:**
- Modify: `addons/juicy_mixer/resources/audio/audio_event_resource.gd`
- Test: `addons/juicy_mixer/tests/audio/test_event_category_integration.gd`

#### Step 1: 在 AudioEventResource 添加类别属性

在混音配置之前添加：

```gdscript
# =============================================================================
# 类别配置
# =============================================================================

@export_group("Categories", "category_")
@export var categories: Array[AudioCategory] = []

## 类别级优先级覆盖（覆盖类别默认值）
@export_range(0, 100) var category_priority_override: int = 50
```

**添加位置:** `audio_event_resource.gd` 混音配置之前（第 42 行之前）

#### Step 2: 添加优先级计算方法

```gdscript
## 获取实际优先级（考虑类别和覆盖）
func get_effective_priority() -> int:
    """获取实际优先级（考虑类别和覆盖）"""
    if categories.is_empty():
        return category_priority_override

    # 取所有类别中的最高优先级
    var highest_priority = 0
    for category in categories:
        if not category:
            continue
        var category_base = _category_priority_to_int(category.category_priority)
        highest_priority = max(highest_priority, category_base)

    return max(highest_priority, category_priority_override)

func _category_priority_to_int(priority: AudioCategory.AudioCategoryPriority) -> int:
    match priority:
        AudioCategory.AudioCategoryPriority.CRITICAL: return 90
        AudioCategory.AudioCategoryPriority.HIGH: return 70
        AudioCategory.AudioCategoryPriority.MEDIUM: return 50
        AudioCategory.AudioCategoryPriority.LOW: return 30
        AudioCategory.AudioCategoryPriority.VERY_LOW: return 10
        _: return 50
```

**添加位置:** `audio_event_resource.gd` 公共方法区域

#### Step 3: 更新 validate() 方法

```gdscript
func validate() -> Dictionary:
    var result = {
        "valid": true,
        "issues": [],
        "warnings": []
    }

    if audio_variants.is_empty():
        result.issues.append("No audio variants defined")
        result.valid = false

    # 验证类别
    for i in range(categories.size()):
        var category = categories[i]
        if not category:
            result.warnings.append("Category at index %d is null" % i)
        else:
            var category_validation = category.validate()
            if not category_validation.valid:
                result.issues.append("Category at index %d: %s" % [i, category_validation.issues.join(", ")])
                result.valid = false

    # 验证虚声部配置（如果有）
    if virtual_voice_enabled:
        if virtual_max_distance <= 0.0:
            result.warnings.append("virtual_max_distance should be positive")

        if virtual_min_importance < 0 or virtual_min_importance > 100:
            result.warnings.append("virtual_min_importance should be between 0 and 100")

    return result
```

**替换位置:** `audio_event_resource.gd` 的 `validate()` 方法

#### Step 4: 编写集成测试

创建 `test_event_category_integration.gd`：

```gdscript
extends Node

func test_event_with_category():
    var resource = AudioEventResource.new()
    resource.event_name = "explosion"

    # 创建类别
    var category = AudioCategory.new()
    category.category_name = "Explosions"
    category.max_instances = 3
    category.category_priority = AudioCategory.AudioCategoryPriority.HIGH

    # 关联类别
    resource.categories.append(category)

    # 验证
    assert(resource.categories.size() == 1, "Should have 1 category")
    assert(resource.get_effective_priority() == 70, "Priority should be 70 (HIGH)")

    print("test_event_with_category PASSED")

func test_priority_override():
    var resource = AudioEventResource.new()

    # 创建中优先级类别
    var category = AudioCategory.new()
    category.category_name = "Footsteps"
    category.category_priority = AudioCategory.AudioCategoryPriority.MEDIUM

    resource.categories.append(category)
    resource.category_priority_override = 80

    # 覆盖值应该更高
    assert(resource.get_effective_priority() == 80, "Override should take precedence")

    print("test_priority_override PASSED")

func test_multiple_categories():
    var resource = AudioEventResource.new()

    var category1 = AudioCategory.new()
    category1.category_priority = AudioCategory.AudioCategoryPriority.MEDIUM

    var category2 = AudioCategory.new()
    category2.category_priority = AudioCategory.AudioCategoryPriority.HIGH

    resource.categories.append(category1)
    resource.categories.append(category2)

    # 应该取最高优先级
    assert(resource.get_effective_priority() == 70, "Should use highest category priority")

    print("test_multiple_categories PASSED")
```

**创建位置:** `addons/juicy_mixer/tests/audio/test_event_category_integration.gd`

#### Step 5: 运行测试

**预期结果:** 所有测试通过

#### Step 6: 提交

```bash
git add addons/juicy_mixer/resources/audio/audio_event_resource.gd
git add addons/juicy_mixer/tests/audio/test_event_category_integration.gd
git commit -m "feat(audio): 在 AudioEventResource 中集成类别系统

- 添加 categories 数组支持多个 AudioCategory
- 添加 category_priority_override 属性
- 实现 get_effective_priority() 方法计算实际优先级
- 更新 validate() 方法验证类别配置
- 创建测试验证类别集成功能

相关设计文档: audio_manager_voice_management_enhanced.md § 3.2.3
用途: 允许音效事件关联类别，实现类别级限额管理

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 3.3: 在 AudioMixingController 实现类别级检查

**目标:** 实现完整的类别级限额检查，包括智能优先级排序。

**Files:**
- Modify: `addons/juicy_mixer/core/audio/audio_mixing_controller.gd`
- Test: `addons/juicy_mixer/tests/audio/test_category_level_limiting.gd`

#### Step 1: 添加类别实例追踪

在 `AudioMixingController` 中添加私有变量：

```gdscript
var _category_instances: Dictionary = {}  # category_name -> Array[player_info]
```

**添加位置:** 类的私有变量区域（`_active_instances` 之后）

#### Step 2: 添加类别级检查方法

```gdscript
## 检查类别级别限制
func _check_category_level(resource: AudioEventResource, new_player: Variant,
                          new_position: Vector3, new_importance: int) -> bool:
    """检查类别级别限制"""

    if resource.categories.is_empty():
        return true  # 没有类别，跳过检查

    for category in resource.categories:
        if not category:
            continue

        var instances = _category_instances.get(category.category_name, [])

        # 统计活跃实例
        var active_count = 0
        var active_instances: Array = []

        for instance_info in instances:
            if is_instance_valid(instance_info.player):
                active_count += 1
                active_instances.append(instance_info)

        if active_count < category.max_instances:
            continue  # 该类别未超限，检查下一个类别

        # 超限处理：智能排序
        var new_score = _calculate_instance_score(
            new_position, new_importance, category.get_priority_factors()
        )

        # 找到优先级最低的实例
        var lowest_score = INF
        var lowest_index = -1

        for i in range(active_instances.size()):
            var instance_info = active_instances[i]
            var score = _calculate_instance_score(
                instance_info.position, instance_info.importance, category.get_priority_factors()
            )

            if score < lowest_score:
                lowest_score = score
                lowest_index = i

        # 比较新实例和最差实例
        if new_score > lowest_score:
            # 新实例优先级更高，停止最差的
            var worst_instance = active_instances[lowest_index]
            _stop_player(worst_instance.player)
            _log_debug("New instance (score: %.2f) steals worst category instance (score: %.2f)"
                       % [new_score, lowest_score])
            return true
        else:
            # 新实例优先级较低，忽略
            _log_debug("New instance (score: %.2f) ignored, lower than worst category instance (score: %.2f)"
                       % [new_score, lowest_score])
            return false

    return true
```

**添加位置:** `audio_mixing_controller.gd` 实例级检查方法之后

#### Step 3: 添加实例分数计算方法

```gdscript
## 计算实例的综合分数（越高越重要）
func _calculate_instance_score(position: Vector3, importance: float,
                               factors: Dictionary) -> float:
    """计算实例的综合分数（越高越重要）"""

    var listener_position = _get_listener_position()
    var distance = listener_position.distance_to(position)

    # 归一化距离（0-100米映射到 0-1）
    var distance_score = clamp(1.0 - distance / 100.0, 0.0, 1.0)

    # 归一化重要性（0-100 映射到 0-1）
    var importance_score = clamp(importance / 100.0, 0.0, 1.0)

    # 最近播放时间（越近分数越高）
    var recency_score = 0.5  # 简化处理

    # 加权计算
    var distance_weight = factors.get("distance_weight", 0.4)
    var importance_weight = factors.get("importance_weight", 0.4)
    var recency_weight = factors.get("recency_weight", 0.2)

    var total_score = (
        distance_score * distance_weight +
        importance_score * importance_weight +
        recency_score * recency_weight
    )

    return total_score * 100.0  # 返回 0-100 的分数
```

**添加位置:** `audio_mixing_controller.gd` 私有方法区域

#### Step 4: 添加监听器位置获取方法

```gdscript
## 获取监听器位置
func _get_listener_position() -> Vector3:
    """获取监听器位置（通常是主相机）"""
    var scene_root = Engine.get_main_loop().current_scene
    if not scene_root:
        return Vector3.ZERO

    # 查找 Camera3D（假设是主监听器）
    var cameras = scene_root.find_children("*", "Camera3D", true, false)
    if cameras.size() > 0:
        return cameras[0].global_position

    # 默认返回原点
    return Vector3.ZERO
```

**添加位置:** `audio_mixing_controller.gd` 私有方法区域

#### Step 5: 集成类别级检查到 can_play

修改 `can_play` 方法：

```gdscript
func can_play(resource: AudioEventResource, event_name: String) -> bool:
    if not resource or not resource.mixing:
        return true

    # 0. 相位保护检查
    if resource.anti_phase_cancellation:
        var current_time = Time.get_ticks_msec() / 1000.0
        var time_since_last = current_time - resource._last_play_time

        if time_since_last < resource.phase_cooldown:
            _log_debug("Phase cooldown active: %.3f < %.3f" % [time_since_last, resource.phase_cooldown])
            return false

        resource._last_play_time = current_time

    # 1. 实例级检查
    var config = resource.mixing
    var instances = _active_instances.get(event_name, [])

    var active_count = 0
    for instance_info in instances:
        if is_instance_valid(instance_info.player):
            active_count += 1

    if active_count < config.max_instances:
        pass  # 继续检查类别
    else:
        # 实例级超限处理（保持原有逻辑）
        match config.limit_policy:
            # ... 原有逻辑 ...
            _: return true

    # 2. 类别级检查（新增）
    var new_position = Vector3.ZERO  # TODO: 从事件中获取
    var new_importance = resource.get_effective_priority()

    if not _check_category_level(resource, null, new_position, new_importance):
        _log_debug("Category level check failed")
        return false

    return true
```

**注意:** 这需要从 `JuicyAudioEventHandler` 传递更多信息，这里先简化处理。

#### Step 6: 更新 record_instance 方法

```gdscript
func record_instance(event_name: String, player: Object, priority: int,
                    resource: AudioEventResource = null, position: Vector3 = Vector3.ZERO) -> void:
    """记录播放实例（支持三层限额）"""

    # 第一层：实例级别
    if not _active_instances.has(event_name):
        _active_instances[event_name] = []

    _active_instances[event_name].append({
        "player": player,
        "priority": priority,
        "start_time": Time.get_ticks_msec() / 1000.0,
        "position": position,
        "importance": priority
    })

    # 第二层：类别级别
    if resource:
        for category in resource.categories:
            if not category:
                continue

            if not _category_instances.has(category.category_name):
                _category_instances[category.category_name] = []

            _category_instances[category.category_name].append({
                "player": player,
                "priority": priority,
                "start_time": Time.get_ticks_msec() / 1000.0,
                "position": position,
                "importance": priority
            })
```

**修改位置:** `audio_mixing_controller.gd` 的 `record_instance` 方法

#### Step 7: 更新 remove_instance 方法

```gdscript
func remove_instance(event_name: String, player: Object, resource: AudioEventResource = null) -> void:
    """移除播放实例（支持三层限额）"""

    # 第一层：实例级别
    if not event_name.is_empty() and _active_instances.has(event_name):
        var instances = _active_instances[event_name]
        for i in range(instances.size()):
            if instances[i].player == player:
                instances.remove_at(i)
                break

        if instances.is_empty():
            _active_instances.erase(event_name)

    # 第二层：类别级别
    if resource:
        for category in resource.categories:
            if not category:
                continue

            if _category_instances.has(category.category_name):
                var instances = _category_instances[category.category_name]
                for i in range(instances.size()):
                    if instances[i].player == player:
                        instances.remove_at(i)
                        break

                if instances.is_empty():
                    _category_instances.erase(category.category_name)
```

**修改位置:** `audio_mixing_controller.gd` 的 `remove_instance` 方法

#### Step 8: 编写类别级限额测试

创建 `test_category_level_limiting.gd`：

```gdscript
extends Node

func test_category_limit_blocks_over_limit():
    var resource = AudioEventResource.new()
    resource.event_name = "explosion"

    # 创建类别（限制为 2 个实例）
    var category = AudioCategory.new()
    category.category_name = "Explosions"
    category.max_instances = 2
    category.category_priority = AudioCategory.AudioCategoryPriority.HIGH

    resource.categories.append(category)

    var config = AudioMixingConfig.new()
    config.max_instances = 10  # 实例级限额较大
    resource.mixing = config

    var controller = AudioMixingController.new()

    # 添加 2 个类别实例
    controller.record_instance("explosion", AudioStreamPlayer2D.new(), 50, resource, Vector3(10, 0, 0))
    controller.record_instance("explosion", AudioStreamPlayer2D.new(), 50, resource, Vector3(20, 0, 0))

    # 第 3 个应该被类别限额阻止
    assert(controller.can_play(resource, "explosion") == false, "Should be blocked by category limit")

    print("test_category_limit_blocks_over_limit PASSED")

func test_smart_priority_sorting():
    var resource = AudioEventResource.new()
    resource.event_name = "explosion"

    var category = AudioCategory.new()
    category.category_name = "Explosions"
    category.max_instances = 2
    category.distance_weight = 1.0  # 只考虑距离
    category.importance_weight = 0.0
    category.recency_weight = 0.0

    resource.categories.append(category)

    var config = AudioMixingConfig.new()
    config.max_instances = 10
    config.limit_policy = AudioMixingConfig.LimitPolicy.FIFO
    resource.mixing = config

    var controller = AudioMixingController.new()

    # 添加 2 个远距离实例
    controller.record_instance("explosion", AudioStreamPlayer2D.new(), 50, resource, Vector3(100, 0, 0))
    controller.record_instance("explosion", AudioStreamPlayer2D.new(), 50, resource, Vector3(100, 0, 0))

    # 第 3 个近距离实例应该替换远距离的
    var can_play = controller.can_play(resource, "explosion")
    # 由于距离更近，应该允许播放并停止最远的实例
    assert(can_play == true, "Nearby instance should replace distant one")

    print("test_smart_priority_sorting PASSED")
```

**创建位置:** `addons/juicy_mixer/tests/audio/test_category_level_limiting.gd`

#### Step 9: 运行测试

**预期结果:** 所有测试通过

#### Step 10: 提交

```bash
git add addons/juicy_mixer/core/audio/audio_mixing_controller.gd
git add addons/juicy_mixer/tests/audio/test_category_level_limiting.gd
git commit -m "feat(audio): 实现类别级限额检查和智能优先级排序

- 添加 _category_instances 字典追踪类别实例
- 实现 _check_category_level() 方法进行类别级限额检查
- 实现 _calculate_instance_score() 计算综合优先级分数
- 实现 _get_listener_position() 获取监听器位置
- 更新 record_instance() 和 remove_instance() 支持类别
- 添加智能排序：距离、重要性、时间权重综合评分

相关设计文档: audio_manager_voice_management_enhanced.md § 3.2.4
用途: 对爆炸、脚步声等同类音效统一管理，基于智能排序决定播放优先级

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Phase 4: 全局级限额系统 (P2)

### Task 4.1: 创建 GlobalAudioLimitConfig 资源类

**目标:** 实现全局级限额配置，包括总线级限制、虚声部系统、硬件监控。

**Files:**
- Create: `addons/juicy_mixer/resources/audio/global_audio_limit_config.gd`
- Modify: `addons/juicy_mixer/plugin.gd` (注册新类)
- Test: `addons/juicy_mixer/tests/audio/test_global_audio_limit_config.gd`

#### Step 1: 创建 GlobalAudioLimitConfig 类

创建 `global_audio_limit_config.gd`：

```gdscript
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

    if max_total_voices <= 0:
        result.issues.append("max_total_voices must be positive")
        result.valid = false

    if max_virtual_voices <= max_total_voices:
        result.warnings.append("max_virtual_voices should be larger than max_total_voices")

    # 验证总线限额
    for bus_name in bus_limits.keys():
        var limit = bus_limits[bus_name]
        if limit <= 0:
            result.warnings.append("Bus '%s' has invalid limit: %d" % [bus_name, limit])

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
        return bus_limits[bus_name]
    return max_total_voices  # 默认返回全局限额

## 设置总线限额
func set_bus_limit(bus_name: String, limit: int) -> void:
    bus_limits[bus_name] = limit
```

**创建位置:** `addons/juicy_mixer/resources/audio/global_audio_limit_config.gd`

#### Step 2: 在 plugin.gd 中注册

在 `_enter_tree()` 中添加：

```gdscript
add_custom_type(
    "GlobalAudioLimitConfig",
    "Resource",
    preload("res://addons/juicy_mixer/resources/audio/global_audio_limit_config.gd"),
    preload("res://icon.svg")
)
```

在 `_exit_tree()` 中添加：

```gdscript
remove_custom_type("GlobalAudioLimitConfig")
```

#### Step 3: 编写测试

创建 `test_global_audio_limit_config.gd`：

```gdscript
extends Node

func test_global_config_creation():
    var config = GlobalAudioLimitConfig.new()

    assert(config.max_total_voices == 64, "Default max_total_voices should be 64")
    assert(config.max_virtual_voices == 128, "Default max_virtual_voices should be 128")
    assert(config.virtual_voice_enabled == true, "Virtual voices should be enabled by default")

    print("test_global_config_creation PASSED")

func test_bus_limits():
    var config = GlobalAudioLimitConfig.new()

    assert(config.get_bus_limit("Master") == 64, "Master bus limit should be 64")
    assert(config.get_bus_limit("Music") == 2, "Music bus limit should be 2")
    assert(config.get_bus_limit("SFX") == 40, "SFX bus limit should be 40")

    # 设置自定义限额
    config.set_bus_limit("Custom", 20)
    assert(config.get_bus_limit("Custom") == 20, "Custom bus limit should be 20")

    print("test_bus_limits PASSED")

func test_validation():
    var config = GlobalAudioLimitConfig.new()
    config.max_total_voices = -10  # 无效

    var result = config.validate()
    assert(result.valid == false, "Invalid max_total_voices should fail validation")

    # 修复
    config.max_total_voices = 64
    result = config.validate()
    assert(result.valid == true, "Valid config should pass")

    print("test_validation PASSED")
```

#### Step 4: 运行测试

#### Step 5: 提交

```bash
git add addons/juicy_mixer/resources/audio/global_audio_limit_config.gd
git add addons/juicy_mixer/plugin.gd
git add addons/juicy_mixer/tests/audio/test_global_audio_limit_config.gd
git commit -m "feat(audio): 创建 GlobalAudioLimitConfig 实现全局级限额

- 添加全局声部上限配置（max_total_voices, max_virtual_voices）
- 实现虚声部系统配置（距离阈值、重要性阈值）
- 添加总线级限制配置（Master, Music, SFX, Voice）
- 实现硬件监控配置（CPU/内存阈值）
- 在 plugin.gd 中注册新类
- 创建测试验证全局配置功能

相关设计文档: audio_manager_voice_management_enhanced.md § 3.3.1
用途: 管理全局音频资源，保护硬件性能

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 4.2: 创建 VirtualVoiceManager 类

**目标:** 实现完整的虚声部管理系统，包括虚声部创建、更新、统计。

**Files:**
- Create: `addons/juicy_mixer/core/audio/virtual_voice_manager.gd`
- Modify: `addons/juicy_mixer/plugin.gd` (注册新类)
- Test: `addons/juicy_mixer/tests/audio/test_virtual_voice_manager.gd`

#### Step 1: 创建 VirtualVoiceManager 类

创建 `virtual_voice_manager.gd`：

```gdscript
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
        instance_id = randi()
        resource = res
        start_time = Time.get_ticks_msec() / 1000.0
        position = pos
        duration = _estimate_duration(res)
        is_virtual = force_virtual

    func _estimate_duration(res: AudioEventResource) -> float:
        """估算音频时长"""
        if not res or res.audio_variants.is_empty():
            return 1.0

        var total = 0.0
        for variant in res.audio_variants:
            if variant and variant.audio_stream:
                total += variant.audio_stream.get_length()

        return total / float(res.audio_variants.size()) if res.audio_variants.size() > 0 else 1.0

# =============================================================================
# 私有变量
# =============================================================================

var _virtual_voices: Dictionary = {}  # voice_id -> VirtualVoiceInfo

# =============================================================================
# 虚声部检查
# =============================================================================

## 检查是否应该使用虚声部
func check_virtual_voice(resource: AudioEventResource, position: Vector3,
                          importance: int, global_config: GlobalAudioLimitConfig) -> VirtualVoiceInfo:
    """检查是否应该使用虚声部"""

    if not resource or not global_config or not global_config.virtual_voice_enabled:
        return null

    # 1. 检查距离
    var listener = _get_listener_position()
    var distance = listener.distance_to(position)

    if distance > global_config.virtual_max_distance:
        return _create_virtual_voice(resource, position, true)

    # 2. 检查重要性
    if importance < global_config.virtual_min_importance:
        return _create_virtual_voice(resource, position, true)

    # 3. 检查总声部数
    var total_real_voices = _get_total_real_voices()
    if total_real_voices >= global_config.max_total_voices:
        return _create_virtual_voice(resource, position, true)

    return null  # 不需要虚声部

## 创建虚声部
func _create_virtual_voice(resource: AudioEventResource, position: Vector3, force_virtual: bool) -> VirtualVoiceInfo:
    """创建虚声部"""
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
    """获取监听器位置"""
    var scene_root = Engine.get_main_loop().current_scene
    if not scene_root:
        return Vector3.ZERO

    var cameras = scene_root.find_children("*", "Camera3D", true, false)
    if cameras.size() > 0:
        return cameras[0].global_position

    return Vector3.ZERO
```

**创建位置:** `addons/juicy_mixer/core/audio/virtual_voice_manager.gd`

#### Step 2: 在 plugin.gd 中注册

#### Step 3: 编写测试

创建 `test_virtual_voice_manager.gd`：

```gdscript
extends Node

func test_virtual_voice_creation():
    var resource = AudioEventResource.new()

    var manager = VirtualVoiceManager.new()

    # 创建虚声部
    var info = manager.check_virtual_voice(resource, Vector3(1000, 0, 0), 50, null)
    # 由于没有 global_config，应该返回 null
    assert(info == null, "Should return null without global config")

    print("test_virtual_voice_creation PASSED")

func test_virtual_voice_updates():
    var manager = VirtualVoiceManager.new()

    # 模拟虚声部
    var resource = AudioEventResource.new()
    var info = manager._create_virtual_voice(resource, Vector3.ZERO, true)

    # 更新虚声部
    manager.update_virtual_voices(0.5)  # 500ms

    # 检查统计
    var stats = manager.get_virtual_voice_stats()
    assert(stats.total_virtual_voices == 1, "Should have 1 virtual voice")

    print("test_virtual_voice_updates PASSED")
```

#### Step 4: 运行测试

#### Step 5: 提交

```bash
git add addons/juicy_mixer/core/audio/virtual_voice_manager.gd
git add addons/juicy_mixer/plugin.gd
git add addons/juicy_mixer/tests/audio/test_virtual_voice_manager.gd
git commit -m "feat(audio): 创建 VirtualVoiceManager 实现虚声部系统

- 实现 VirtualVoiceInfo 内部类管理虚声部状态
- 添加 check_virtual_voice() 方法判断是否使用虚声部
- 实现基于距离、重要性、全局限额的虚声部判断
- 添加 update_virtual_voices() 方法更新虚声部时间
- 实现虚声部统计功能
- 估算音频时长用于虚声部生命周期管理

相关设计文档: audio_manager_voice_management_enhanced.md § 3.3.2
用途: 节省 CPU 资源，远距离或低优先级音效转为虚声部

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 4.3: 集成全局配置到 JuicyAudioEventHandler

**目标:** 在事件处理器中集成全局配置和虚声部管理器。

**Files:**
- Modify: `addons/juicy_mixer/events/juicy_audio_event_handler.gd`
- Test: `addons/juicy_mixer/tests/audio/test_global_integration.gd`

#### Step 1: 添加全局配置支持

在 `JuicyAudioEventHandler` 中添加：

```gdscript
# 全局配置
var _global_config: GlobalAudioLimitConfig = null
var _virtual_voice_manager: VirtualVoiceManager = null
```

**添加位置:** 类的私有变量区域

#### Step 2: 在 _init() 中初始化

```gdscript
func _init():
    handler_name = "AudioEventHandler"
    supported_events = [
        JuicyEvent.EventType.AUDIO_PLAY,
        JuicyEvent.EventType.AUDIO_STOP
    ]
    description = "Handles audio playback and control events"

    # 初始化管理器
    _variation_manager = AudioVariationManager.new()
    _mixing_controller = AudioMixingController.new()
    _virtual_voice_manager = VirtualVoiceManager.new()  # 新增

    # 初始化默认全局配置
    _global_config = GlobalAudioLimitConfig.new()
```

**修改位置:** `_init()` 方法

#### Step 3: 在 _handle_audio_resource_play 中添加全局级检查

```gdscript
func _handle_audio_resource_play(resource: AudioEventResource, event: JuicyEvent) -> bool:
    # 1. 变体选择
    var variant = _variation_manager.select_variant(resource)
    if not variant:
        _log_error("Failed to select audio variant for: " + resource.event_name)
        return false

    # 2. 应用随机化
    var randomization = _variation_manager.apply_randomization(
        variant, 1.0, _master_volume, resource
    )

    # 3. 实例级检查
    if not _mixing_controller.can_play(resource, resource.event_name):
        _log_debug("Instance level check failed")
        return false

    # 4. 类别级检查（已集成到 AudioMixingController）
    # （通过传递 resource 实现已集成）

    # 5. 全局级检查（新增）
    if _global_config:
        var position = event.event_data.get("position", Vector3.ZERO)
        var importance = resource.get_effective_priority()

        var virtual_info = _virtual_voice_manager.check_virtual_voice(
            resource, position, importance, _global_config
        )

        if virtual_info and virtual_info.is_virtual:
            _log_debug("Sound converted to virtual voice (distance or importance)")
            return false  # 虚声部不实际播放

    # 6. 获取播放器
    var player = _get_audio_player_for_resource(resource, event)
    if not player:
        _log_error("Failed to get audio player")
        return false

    # ... 继续原有逻辑
```

#### Step 4: 添加配置方法

```gdscript
## 设置全局配置
func set_global_config(config: GlobalAudioLimitConfig) -> void:
    _global_config = config

## 获取全局配置
func get_global_config() -> GlobalAudioLimitConfig:
    return _global_config

## 更新虚声部（在 _process 中调用）
func _process(delta: float) -> void:
    if _mixing_controller:
        _mixing_controller.update_ducking(delta)

    if _virtual_voice_manager:
        _virtual_voice_manager.update_virtual_voices(delta)  # 新增
```

#### Step 5: 编写集成测试

#### Step 6: 运行测试

#### Step 7: 提交

```bash
git add addons/juicy_mixer/events/juicy_audio_event_handler.gd
git add addons/juicy_mixer/tests/audio/test_global_integration.gd
git commit -m "feat(audio): 在 JuicyAudioEventHandler 中集成全局配置

- 添加 _global_config 和 _virtual_voice_manager 成员
- 在 _handle_audio_resource_play() 中添加全局级检查
- 实现虚声部判断逻辑（距离、重要性、全局限额）
- 添加 set_global_config() 和 get_global_config() 方法
- 在 _process() 中更新虚声部状态

相关设计文档: audio_manager_voice_management_enhanced.md § 4.1
完成三层架构：实例级 → 类别级 → 全局级

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## 总结和验证

### Task 5.1: 创建完整的端到端测试

**目标:** 创建一个完整的演示场景，测试所有三层限额系统。

**Files:**
- Create: `addons/juicy_mixer/tests/audio/test_three_tier_demo.tscn`
- Create: `addons/juicy_mixer/tests/audio/test_three_tier_demo.gd`

#### Step 1: 创建演示脚本

创建完整的测试场景，验证：
1. 实例级限额和策略（7种）
2. 类别级限额和智能排序
3. 全局级限额和虚声部
4. 相位保护机制

#### Step 2: 运行完整测试

#### Step 3: 提交

```bash
git commit -m "test(audio): 创建三层架构完整端到端测试

- 创建 test_three_tier_demo 测试场景
- 验证实例级、类别级、全局级限额协同工作
- 测试所有 7 种实例级策略
- 验证智能优先级排序
- 验证虚声部系统
- 验证相位保护机制

相关设计文档: audio_manager_voice_management_enhanced.md

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 5.2: 更新文档

**目标:** 更新相关文档反映完整实现。

**Files:**
- Modify: `addons/juicy_mixer/docs/dev_docs/audio_manager_design.md`
- Modify: `addons/juicy_mixer/docs/user_docs/audio_manager_user_guide.md`
- Create: `addons/juicy_mixer/docs/dev_docs/AUDIO_MANAGER_PHASE2.md`

#### Step 1: 更新设计文档

添加完整的三层架构实现说明。

#### Step 2: 更新用户指南

添加类别级和全局级配置的使用说明。

#### Step 3: 创建 Phase 2 实施总结文档

记录所有实施的内容和注意事项。

#### Step 4: 提交文档更新

```bash
git commit -m "docs(audio): 更新文档反映三层架构完整实现

- audio_manager_design.md: 标记 Phase 2 功能为已实现
- audio_manager_user_guide.md: 添加类别级和全局级配置指南
- 创建 AUDIO_MANAGER_PHASE2.md 实施总结

完成功能：
✅ 三层限额架构（实例、类别、全局）
✅ 7种实例级策略
✅ 相位保护机制
✅ 智能优先级排序
✅ 虚声部系统
✅ 总线级限制
✅ 硬件监控框架

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## 实施检查清单

在完成所有任务后，验证以下内容：

### 枚举和策略
- [ ] `AudioMixingConfig.LimitPolicy` 有 7 个值（0-6）
- [ ] `AudioMixingController.can_play` 正确匹配所有 7 种策略
- [ ] 淡出策略正确实现 Tween 淡出

### 相位保护
- [ ] `AudioEventResource` 有 `anti_phase_cancellation` 和 `phase_cooldown` 属性
- [ ] `AudioMixingController` 在实例级检查之前进行相位冷却检查
- [ ] 测试验证高频重复音效被正确阻止

### 类别级系统
- [ ] `AudioCategory` 类创建并注册到 plugin.gd
- [ ] `AudioEventResource` 有 `categories` 数组
- [ ] `AudioEventResource.get_effective_priority()` 正确计算优先级
- [ ] `AudioMixingController` 有 `_category_instances` 追踪
- [ ] `_check_category_level()` 正确实现智能排序
- [ ] `_calculate_instance_score()` 综合距离、重要性、时间权重

### 全局级系统
- [ ] `GlobalAudioLimitConfig` 类创建并注册
- [ ] `VirtualVoiceManager` 类创建并注册
- [ ] `JuicyAudioEventHandler` 集成全局配置
- [ ] 虚声部基于距离、重要性、全局限额正确判断
- [ ] `update_virtual_voices()` 正确更新虚声部时间

### 测试覆盖
- [ ] 所有新类都有对应的测试文件
- [ ] 所有测试场景都能运行
- [ ] 端到端测试验证三层架构协同工作

### 文档
- [ ] 设计文档更新
- [ ] 用户指南更新
- [ ] 代码注释完整

### 注册检查
- [ ] AudioCategory 在 plugin.gd 中注册
- [ ] GlobalAudioLimitConfig 在 plugin.gd 中注册
- [ ] VirtualVoiceManager 在 plugin.gd 中注册
- [ ] 所有注册都在 `_exit_tree()` 中正确移除

---

## 预期提交历史

实施完成后，应该有以下 git commits：

1. `fix(audio): 修复枚举不匹配bug并扩展为7种策略`
2. `feat(audio): 添加虚声部配置属性到 AudioEventResource`
3. `feat(audio): 实现相位保护机制防止高频音效相位抵消`
4. `feat(audio): 实现完整的淡出策略`
5. `feat(audio): 创建 AudioCategory 资源类实现类别级限额`
6. `feat(audio): 在 AudioEventResource 中集成类别系统`
7. `feat(audio): 实现类别级限额检查和智能优先级排序`
8. `feat(audio): 创建 GlobalAudioLimitConfig 实现全局级限额`
9. `feat(audio): 创建 VirtualVoiceManager 实现虚声部系统`
10. `feat(audio): 在 JuicyAudioEventHandler 中集成全局配置`
11. `test(audio): 创建三层架构完整端到端测试`
12. `docs(audio): 更新文档反映三层架构完整实现`

---

**计划完成！** 🎉

所有任务都已详细规划，包括：
- 完整的代码实现
- 测试步骤
- 提交信息
- 文件路径
- 检查清单

准备好实施了！
