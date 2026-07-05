# JuicyMixer Driver 状态污染审计报告

**日期**: 2026-02-03
**审计范围**: 所有 JuicyMixer Driver
**严重程度**: 高 - 发现多个潜在问题

## 审计结果汇总

| Driver | 状态隔离 | 严重程度 | 问题 |
|--------|---------|---------|------|
| **JuicyTimelineDriver** | ❌ | 高 | 成员变量存储运行时状态 |
| **JuicyShakeDriver** | ⚠️ | 中 | 噪声生成器未隔离 |
| **JuicyAnimationPlayDriver** | ✅ | 无 | 正确使用 context_id 隔离 |
| **JuicyCompositeDriver** | ✅ | 无 | 正确使用 context_id 隔离 |
| **JuicySpringDriver** | ✅ | 无 | 正确使用 context_id 隔离 |
| **JuicyTweenDriver** | ✅ | 无 | 正确使用 context_id 隔离 |
| **JuicyDriver** (基类) | ✅ | 无 | 时间状态正确隔离 |

---

## 详细分析

### ❌ 高危问题

#### 1. JuicyTimelineDriver - 严重状态污染

**文件**: [juicy_timeline_driver.gd](addons/juicy_mixer/drivers/juicy_timeline_driver.gd)

**问题代码** (line 26-42):
```gdscript
# 运行时状态 - 直接存储在 Driver 实例中
var current_time: float = 0.0
var is_playing: bool = false
var is_paused: bool = false
var play_direction: int = 1
var current_loop: int = 0

# 轨道状态跟踪
var _active_property_tracks: Array[JuicyPropertyTrack] = []
var _active_feedback_tracks: Array[JuicyFeedbackTrack] = []
var _active_method_tracks: Array[JuicyMethodTrack] = []

# 触发状态记录
var _triggered_methods: Dictionary = {}
var _triggered_events: Dictionary = {}
var _active_sub_contexts: Dictionary = {}
```

**问题场景**:
```
两个敌人同时播放相同的 Timeline 震动效果：
- 敌人A播放 Timeline, current_time = 0.5
- 敌人B播放相同 Timeline, current_time = 0.2  ❌ 覆盖了敌人A！
结果：两个敌人的 Timeline 播放互相干扰
```

**修复方案**: 参考 [JuicySequenceDriver](addons/juicy_mixer/drivers/juicy_sequence_driver.gd) 的正确实现：
```gdscript
# ✅ 按context_id隔离状态
var _timeline_states: Dictionary = {}  # context_id -> TimelineState

class TimelineState:
    var current_time: float = 0.0
    var is_playing: bool = false
    var is_paused: bool = false
    var play_direction: int = 1
    var current_loop: int = 0
```

---

### ⚠️ 中危问题

#### 2. JuicyShakeDriver - 噪声生成器未隔离

**文件**: [juicy_shake_driver.gd](addons/juicy_mixer/drivers/juicy_shake_driver.gd)

**问题代码** (line 72):
```gdscript
var _noise_generators: Dictionary = {}  # 属性名 -> FastNoiseLite
```

**问题描述**:
- 噪声生成器按属性名存储，未按 context_id 隔离
- 如果同一个 ShakeResource 被多个播放同时使用，噪声生成器会被共享
- 虽然每个播放使用不同的时间参数，但噪声生成器的种子和配置是共享的

**影响**:
- 相同效果的多个播放会使用相同的噪声生成器实例
- 可能导致噪声序列重复或相关性

**修复方案**:
```gdscript
# ❌ 当前实现
var _noise_generators: Dictionary = {}  # property -> FastNoiseLite

# ✅ 修复方案 1: 每次创建新的噪声生成器
func _initialize_noise_generators(context: JuicyContext) -> void:
    # 不缓存噪声生成器，每次都创建新的
    pass

func process(context: JuicyContext, delta: float, buffer: JuicyPropertyBuffer) -> void:
    for property in shake_properties.keys():
        var config = shake_properties[property]
        var noise = _create_noise_generator(config, context.context_id)
        # 使用噪声生成器...

# ✅ 修复方案 2: 按 context_id 隔离
var _noise_generators: Dictionary = {}  # context_id -> {property -> FastNoiseLite}
```

**优先级**: 中 - 虽然不会导致状态污染，但可能导致可预测性问题

---

### ✅ 正确实现参考

#### 3. JuicyAnimationPlayDriver - 正确的状态隔离

**文件**: [juicy_animation_play_driver.gd](addons/juicy_mixer/drivers/juicy_animation_play_driver.gd)

**正确代码** (line 31-32):
```gdscript
var animation_states: Dictionary = {}  # context_id -> [AnimationPlayState]
var current_animation_index: Dictionary = {}  # context_id -> int
```

**状态访问模式**:
```gdscript
func prepare(context: JuicyContext, delta: float, buffer: JuicyPropertyBuffer) -> void:
    animation_states[context.context_id] = states
    current_animation_index[context.context_id] = 0

func process(context: JuicyContext, delta: float, buffer: JuicyPropertyBuffer) -> void:
    var states = animation_states.get(context.context_id, [])
    var current_index = current_animation_index.get(context.context_id, 0)

func cleanup(context: JuicyContext) -> void:
    animation_states.erase(context.context_id)
    current_animation_index.erase(context.context_id)
```

**评价**: 完美的状态隔离实现！✅

---

#### 4. JuicyCompositeDriver - 正确的状态隔离

**文件**: [juicy_composite_driver.gd](addons/juicy_mixer/drivers/juicy_composite_driver.gd)

**正确代码** (line 27):
```gdscript
var _composite_states: Dictionary = {}  # context_id -> CompositeState

class CompositeState:
    var active_contexts: Array[String] = []
    var item_weights: Dictionary = {}
    var blend_progress: float = 0.0
    var parameter_values: Dictionary = {}
```

**评价**: 使用内部类管理状态，清晰且正确！✅

---

#### 5. JuicySpringDriver - 正确的状态隔离

**文件**: [juicy_spring_driver.gd](addons/juicy_mixer/drivers/juicy_spring_driver.gd)

**正确代码** (line 87):
```gdscript
var _spring_states: Dictionary = {}  # context_id -> {property: SpringState}

class SpringState:
    var original_position: Variant
    var spring_position: Variant
    var current_velocity: Variant
    var target_position: Variant
    var is_stable: bool = false
```

**评价**: 状态结构设计合理，隔离正确！✅

---

#### 6. JuicyTweenDriver - 正确的状态隔离

**文件**: [juicy_tween_driver.gd](addons/juicy_mixer/drivers/juicy_tween_driver.gd)

**正确代码** (line 55):
```gdscript
var _property_states: Dictionary = {}  # context_id -> {property: state_dict}
```

**评价**: 简洁且正确的状态隔离！✅

---

#### 7. JuicyDriver (基类) - 时间状态正确隔离

**文件**: [juicy_driver.gd](addons/juicy_mixer/drivers/juicy_driver.gd)

**正确代码** (line 47):
```gdscript
var _driver_time_states: Dictionary = {}  # context_id -> {elapsed_time, start_time}
```

**统计变量说明** (line 34-40):
```gdscript
var _execution_count: int = 0
var _total_execution_time: float = 0.0
var _last_execution_time: float = 0.0
```

**说明**:
- 统计变量是全局的，用于性能监控，设计上就是跨所有播放累积
- 这些不是运行时状态，不会导致状态污染
- 时间状态 `_driver_time_states` 正确使用了 context_id 隔离

**评价**: 统计变量设计合理，时间状态隔离正确！✅

---

## 修复优先级

### 高优先级
1. **修复 JuicyTimelineDriver 状态污染** - 严重问题，必须在多播放场景下修复

### 中优先级
2. **修复 JuicyShakeDriver 噪声生成器隔离** - 改善可预测性和随机性

### 低优先级
3. **检查 Middleware 是否有类似问题** - 扩展审计范围

---

## 正确模式总结

### ✅ 正确的状态隔离模式

```gdscript
class_name MyDriver
extends JuicyDriver

# ✅ 正确：按 context_id 隔离状态
var _driver_states: Dictionary = {}  # context_id -> DriverState

class DriverState:
    var runtime_var_1: float = 0.0
    var runtime_var_2: bool = false

func prepare(context: JuicyContext, delta: float, buffer: JuicyPropertyBuffer) -> void:
    var state = DriverState.new()
    _driver_states[context.context_id] = state

func process(context: JuicyContext, delta: float, buffer: JuicyPropertyBuffer) -> void:
    var state = _driver_states.get(context.context_id)
    if not state:
        return

    # 使用 state.runtime_var_1 等

func cleanup(context: JuicyContext) -> void:
    _driver_states.erase(context.context_id)
```

### ❌ 错误的状态存储模式

```gdscript
class_name MyDriver
extends JuicyDriver

# ❌ 错误：直接使用成员变量存储运行时状态
var runtime_var_1: float = 0.0
var runtime_var_2: bool = false

func process(context: JuicyContext, delta: float, buffer: JuicyPropertyBuffer) -> void:
    # 多个播放会共享这些变量，导致状态污染！
    runtime_var_1 += delta
```

---

## 参考文档

- [JuicyMixer 状态污染问题分析报告](juicy_mixer_state_pollution_analysis.md)
- [Bricks 循环指令状态迁移完成报告](../plans/2025-02-03-loop-instructions-execution-context-migration-complete.md)
- [RuntimeInstance 架构文档](../addons/bricks/docs/architecture/runtime-instance-pattern.md)

---

## 总结

JuicyMixer 的大部分 Driver（5/6）已经正确实现了状态隔离，只有 **JuicyTimelineDriver** 存在严重的状态污染问题。

**JuicyTimelineDriver** 的问题与 Bricks 系统刚修复的循环指令问题本质上相同：**成员变量存储运行时状态导致资源共享时的状态污染**。

建议立即修复 JuicyTimelineDriver，确保多个播放能够独立运行而不互相干扰。
