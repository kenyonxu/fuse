# JuicyMixer 状态污染问题分析报告

**日期**: 2026-02-03
**分析范围**: JuicyMixer V3 架构核心组件
**严重程度**: 高 - 可能导致运行时状态混乱

## 问题概述

JuicyMixer V3 的部分驱动器使用成员变量存储运行时状态，当同一个资源被多次播放时会共享同一个 Driver 实例，导致状态污染。

## 核心问题

### JuicyTimelineDriver 的状态污染

**文件**: `addons/juicy_mixer/drivers/juicy_timeline_driver.gd`

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

### 问题场景

```
场景：两个敌人同时受伤，播放相同的 Timeline 震动效果

TimelineResource [shared]
    ↓
创建 Driver 实例
    ↓
JuicyTimelineDriver [single_instance]
    ├─ current_time = 0.5  # 敌人A的播放时间
    └─ current_time = 0.2  # ❌ 敌人B覆盖了敌人A！

结果：两个敌人的 Timeline 播放互相干扰，状态混乱
```

### 为什么会发生

1. **资源共享**: JuicyDirector 使用 Context 池化管理，但 Driver 是从 Resource 创建的单例
2. **成员变量存储**: 运行时状态直接存储在 Driver 实例的成员变量中
3. **缺少隔离**: 没有按 `context_id` 隔离状态的机制

## 正确实现参考

### JuicySequenceDriver 的正确模式

**文件**: `addons/juicy_mixer/drivers/juicy_sequence_driver.gd`

**正确代码** (line 59):
```gdscript
# 按 context_id 隔离状态 ✅
var _sequence_states: Dictionary = {}  # context_id -> SequenceState
```

**状态隔离实现**:
```gdscript
func prepare(context: JuicyContext, delta: float, buffer: JuicyPropertyBuffer) -> void:
    var state = SequenceState.new()
    _sequence_states[context.context_id] = state  # ✅ 独立状态

func process(context: JuicyContext, delta: float, buffer: JuicyPropertyBuffer) -> void:
    var state = _sequence_states.get(context.context_id)  # ✅ 获取独立状态

func cleanup(context: JuicyContext) -> void:
    _sequence_states.erase(context.context_id)  # ✅ 清理状态
```

这是与 Bricks `ExecutionContext.custom_data` 相同的状态隔离模式。

## 组件对比

| 组件 | 状态存储方式 | 是否存在问题 | 原因 |
|------|------------|------------|------|
| **JuicyTimelineDriver** | Driver 成员变量 | ❌ 有问题 | 多个播放共享同一个 Driver 实例 |
| **JuicySequenceDriver** | `_sequence_states[context_id]` | ✅ 正确 | 每个播放都有独立的状态 |
| **Bricks ForLoop（旧）** | Instruction 成员变量 | ❌ 有问题（已修复） | 多个 Trigger 共享同一个 Instruction |
| **Bricks ForLoop（新）** | `ExecutionContext.custom_data` | ✅ 正确 | 每个 Trigger 都有独立的 ExecutionContext |

## 统计变量问题

### Driver 基类统计

**文件**: `addons/juicy_mixer/drivers/juicy_driver.gd` (line 34-40)
```gdscript
var _execution_count: int = 0
var _total_execution_time: float = 0.0
var _last_execution_time: float = 0.0
```

### Middleware 基类统计

**文件**: `addons/juicy_middleware/juicy_middleware.gd` (line 58-73)
```gdscript
var _execution_count: int = 0
var _total_execution_time: float = 0.0
var _error_count: int = 0
var _context_count: int = 0  # ⚠️ 尤其有问题
```

### 问题分析

这些统计变量跨所有播放累积，导致：
- 无法区分每个播放的性能指标
- `_context_count` 统计混乱
- 性能监控数据不准确

**建议修复**: 在 `prepare()` 中重置统计，或使用 Context 存储每个播放的统计。

## 修复方案

### 方案 1: 使用 Context 存储运行时状态（推荐）

参考 `JuicySequenceDriver` 的正确实现：

```gdscript
class_name JuicyTimelineDriver
extends JuicyDriver

# ❌ 删除成员变量
# var current_time: float = 0.0
# var is_playing: bool = false

# ✅ 在 prepare() 中初始化到 Context
func prepare(context: JuicyContext, delta: float, buffer: JuicyPropertyBuffer) -> void:
    timeline_resource = context.get_driver_data("timeline_resource") as JuicyTimelineResource

    # 初始化运行时状态到 Context
    context.set_driver_data("current_time", 0.0)
    context.set_driver_data("is_playing", true)
    context.set_driver_data("is_paused", false)
    context.set_driver_data("play_direction", 1)
    context.set_driver_data("current_loop", 0)
    context.set_driver_data("active_tracks", {})

# ✅ 在 process() 中从 Context 读取
func process(context: JuicyContext, delta: float, buffer: JuicyPropertyBuffer) -> void:
    var current_time = context.get_driver_data("current_time")
    var is_playing = context.get_driver_data("is_playing")

    if not is_playing:
        return

    # 更新状态
    current_time += delta * timeline_resource.time_scale
    context.set_driver_data("current_time", current_time)

# ✅ 在 cleanup() 中清理
func cleanup(context: JuicyContext) -> void:
    context.set_driver_data("current_time", null)
    context.set_driver_data("is_playing", null)
    context.set_driver_data("active_tracks", null)
```

### 方案 2: 使用内部字典隔离状态

```gdscript
class_name JuicyTimelineDriver
extends JuicyDriver

# ✅ 按context_id隔离状态
var _timeline_states: Dictionary = {}  # context_id -> TimelineState

class TimelineState:
    var current_time: float = 0.0
    var is_playing: bool = false
    var is_paused: bool = false
    var play_direction: int = 1
    var current_loop: int = 0

func prepare(context: JuicyContext, delta: float, buffer: JuicyPropertyBuffer) -> void:
    var state = TimelineState.new()
    _timeline_states[context.context_id] = state

func process(context: JuicyContext, delta: float, buffer: JuicyPropertyBuffer) -> void:
    var state = _timeline_states.get(context.context_id)
    if not state:
        return

    state.current_time += delta

func cleanup(context: JuicyContext) -> void:
    _timeline_states.erase(context.context_id)
```

## 对比 Bricks 的修复经验

Bricks 系统刚完成了相同问题的修复：

### 修复前（Bricks ForLoop）
```gdscript
var _current_index: int = 0  # ❌ 多个 Trigger 共享

for i in range(count):
    _current_index = i  # ❌ 状态污染
```

### 修复后（Bricks ForLoop）
```gdscript
# 删除成员变量

for i in range(count):
    context.set_custom_data("loop_forloop_current_index", i)  # ✅ 状态隔离
```

### 迁移文档
- [循环指令状态迁移完成报告](../plans/2025-02-03-loop-instructions-execution-context-migration-complete.md)
- [RuntimeInstance 架构文档](../../addons/bricks/docs/architecture/runtime-instance-pattern.md)

## 影响评估

### 严重性

- **高风险**: 当多个对象同时播放相同效果时，会导致不可预测的行为
- **常见场景**: 多个敌人使用相同的受伤效果、多个 UI 元素使用相同的动画

### 影响范围

- **受影响组件**: JuicyTimelineDriver, JuicyDriver, JuicyMiddleware
- **不受影响组件**: JuicySequenceDriver（已正确实现）

## 建议优先级

1. **高优先级**: 修复 JuicyTimelineDriver 状态污染问题
2. **中优先级**: 修复统计变量累积问题
3. **低优先级**: 检查其他 Driver 是否有类似问题

## 参考文档

- [JuicyMixer 架构分析](../../addons/juicy_mixer/docs/system_docs/architecture_analysis.md)
- [Bricks 循环指令迁移方案](../plans/2025-02-03-loop-instructions-execution-context-migration-plan.md)
- [RuntimeInstance 模式文档](../../addons/bricks/docs/architecture/runtime-instance-pattern.md)

## 总结

JuicyTimelineDriver 的状态污染问题与 Bricks 循环指令的问题本质上相同：**成员变量存储运行时状态导致资源共享时的状态污染**。

JuicySequenceDriver 已经正确实现了状态隔离，可以作为修复参考。建议优先修复 JuicyTimelineDriver，确保多个播放能够独立运行而不互相干扰。
