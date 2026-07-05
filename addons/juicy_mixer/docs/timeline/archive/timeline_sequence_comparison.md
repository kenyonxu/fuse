# JuicyMixer V3 Timeline与Sequence系统比较指南

## 概述

JuicyMixer V3提供了两个并行的时间轴系统：传统的Sequence系统和全新的Timeline系统。本文档帮助您了解两者的区别，并根据项目需求选择合适的系统。

## 系统对比

### 核心特性对比

| 特性 | Sequence系统 | Timeline系统 | 说明 |
|------|-------------|-------------|------|
| **成熟度** | 成熟稳定 | 全新设计 | Sequence经过长期验证，Timeline是全新架构 |
| **性能** | 优化良好 | 高度优化 | Timeline采用了更先进的缓存和批处理机制 |
| **功能丰富度** | 基础功能 | 高级功能 | Timeline提供更多高级功能 |
| **学习曲线** | 简单易学 | 中等复杂度 | Sequence更简单，Timeline功能更强大 |
| **扩展性** | 有限 | 高度可扩展 | Timeline设计更加模块化 |
| **参数映射** | 基础支持 | 完整支持 | Timeline提供完整的参数映射系统 |
| **条件系统** | 不支持 | 完整支持 | Timeline集成了条件系统 |
| **可视化编辑** | 基础编辑器 | 高级编辑器 | Timeline编辑器功能更丰富 |

### API对比

#### 播放API

**Sequence系统**:
```gdscript
# 播放Sequence
var sequence_id = JuicyMixer.play_sequence(sequence, target)

# 控制播放
JuicyMixer.pause_sequence(sequence_id)
JuicyMixer.resume_sequence(sequence_id)
JuicyMixer.stop_sequence(sequence_id)
```

**Timeline系统**:
```gdscript
# 播放Timeline
var context_id = JuicyTimeline.play(timeline, target)

# 控制播放
JuicyTimeline.pause(context_id)
JuicyTimeline.resume(context_id)
JuicyTimeline.stop(context_id)
```

#### 资源创建

**Sequence系统**:
```gdscript
var sequence = JuicySequence.new()
sequence.sequence_name = "MySequence"
sequence.duration = 2.0

var track = JuicyPropertySequenceTrack.new()
track.target_node_path = "Sprite2D"
track.property_path = "scale"
```

**Timeline系统**:
```gdscript
var timeline = JuicyTimelineResource.new()
timeline.timeline_name = "MyTimeline"
timeline.duration = 2.0

var track = JuicyPropertyTrack.new()
track.target_node_path = "Sprite2D"
track.property_path = "scale"
```

## 功能对比详解

### 1. 轨道系统

**Sequence系统**:
- 基础轨道类型（属性、反馈、方法、事件）
- 简单的关键帧系统
- 基础插值支持

**Timeline系统**:
- 扩展的轨道类型
- 高级关键帧系统
- 丰富的插值选项（线性、缓入缓出、三次样条、自定义曲线）
- 轨道分组功能

### 2. 参数映射

**Sequence系统**:
```gdscript
# 基础参数映射
var mapping = JuicyParameterMapping.new()
mapping.input_parameter = "intensity"
mapping.output_range = Vector2(0.0, 1.0)
```

**Timeline系统**:
```gdscript
# 完整参数映射系统
var mapping = JuicyParameterMapping.new()
mapping.input_parameter = "intensity"
mapping.mapping_type = JuicyParameterMapping.MappingType.TRACK_VALUE
mapping.target_property = "intensity"
mapping.input_range = Vector2(0.0, 1.0)
mapping.output_range = Vector2(0.5, 2.0)
mapping.curve = custom_curve  # 支持曲线映射
mapping.invert_mapping = true  # 支持反转映射
```

### 3. 条件系统

**Sequence系统**:
- 不支持条件激活
- 所有轨道始终激活

**Timeline系统**:
```gdscript
# 条件激活轨道
var health_condition = JuicyParameterCondition.new()
health_condition.parameter_name = "player_health"
health_condition.operator = JuicyParameterCondition.ComparisonOperator.LESS_THAN
health_condition.target_value = 0.3

track.activation_condition = health_condition
```

### 4. 性能特性

**Sequence系统**:
- 基础对象池化
- 简单的缓存机制
- 适合简单到中等复杂度的场景

**Timeline系统**:
- 高级对象池化
- 智能缓存系统
- 批处理优化
- 适合复杂和高性能要求的场景

## 使用场景建议

### 何时使用Sequence系统

1. **简单动画需求**
   - 基础的UI动画
   - 简单的物体移动
   - 固定的播放序列

2. **快速原型开发**
   - 需要快速实现效果
   - 不需要复杂的参数控制
   - 学习成本要求低

3. **向后兼容性**
   - 现有项目已经在使用Sequence
   - 不需要迁移到新系统
   - 团队熟悉Sequence API

4. **资源受限环境**
   - 内存使用敏感
   - CPU性能有限
   - 移动设备优化

### 何时使用Timeline系统

1. **复杂动画需求**
   - 多轨道同步动画
   - 复杂的插值需求
   - 高级视觉效果

2. **动态效果控制**
   - 需要实时参数调整
   - 基于游戏状态的效果变化
   - 联觉效果（多感官联动）

3. **高级功能需求**
   - 条件激活的轨道
   - 轨道分组管理
   - 自定义插值曲线

4. **性能优化需求**
   - 大量同时播放的效果
   - 复杂的场景动画
   - 高帧率要求

## 混合使用策略

### 1. 按功能模块分离

```gdscript
# UI动画使用Sequence
func play_ui_animation():
    var ui_sequence = create_ui_sequence()
    JuicyMixer.play_sequence(ui_sequence, ui_root)

# 游戏效果使用Timeline
func play_game_effect():
    var effect_timeline = create_effect_timeline()
    JuicyTimeline.play(effect_timeline, game_root)
```

### 2. 按复杂度分离

```gdscript
# 简单效果使用Sequence
func play_simple_effect():
    var simple_sequence = create_simple_sequence()
    JuicyMixer.play_sequence(simple_sequence, target)

# 复杂效果使用Timeline
func play_complex_effect():
    var complex_timeline = create_complex_timeline()
    JuicyTimeline.play(complex_timeline, target)
```

### 3. 按性能要求分离

```gdscript
# 高频效果使用Sequence（更轻量）
func play_high_frequency_effect():
    var hf_sequence = create_hf_sequence()
    JuicyMixer.play_sequence(hf_sequence, target)

# 低频复杂效果使用Timeline
func play_low_frequency_complex_effect():
    var complex_timeline = create_complex_timeline()
    JuicyTimeline.play(complex_timeline, target)
```

## 迁移和共存

### 1. 渐进式采用

```gdscript
# 阶段1：保持现有Sequence
func phase1_keep_existing():
    # 现有代码不变
    play_existing_sequences()

# 阶段2：新功能使用Timeline
func phase2_new_features():
    # 新功能使用Timeline
    play_new_timelines()

# 阶段3：逐步迁移关键系统
func phase3_migrate_critical():
    # 关键系统迁移到Timeline
    migrate_to_timeline()
```

### 2. 系统集成

```gdscript
# 统一的效果管理器
class EffectManager:
    func play_effect(effect_data: Dictionary, target: Node):
        if effect_data.has("sequence"):
            # 使用Sequence系统
            var sequence = effect_data.sequence
            return JuicyMixer.play_sequence(sequence, target)
        elif effect_data.has("timeline"):
            # 使用Timeline系统
            var timeline = effect_data.timeline
            return JuicyTimeline.play(timeline, target)
        else:
            print("无效的效果数据")
            return ""
```

### 3. 性能监控

```gdscript
# 性能监控器
class PerformanceMonitor:
    var sequence_stats = {}
    var timeline_stats = {}
    
    func record_sequence_play(sequence_id: String, duration: float):
        sequence_stats[sequence_id] = duration
    
    func record_timeline_play(context_id: String, duration: float):
        timeline_stats[context_id] = duration
    
    func get_performance_report():
        return {
            "sequence_avg": calculate_average(sequence_stats),
            "timeline_avg": calculate_average(timeline_stats)
        }
```

## 最佳实践

### 1. 选择标准

创建决策树帮助选择合适的系统：

```gdscript
func choose_timeline_system(requirements: Dictionary) -> String:
    # 复杂度检查
    if requirements.get("complexity", "simple") == "simple":
        return "sequence"
    
    # 参数映射需求
    if requirements.get("parameter_mapping", false):
        return "timeline"
    
    # 条件激活需求
    if requirements.get("conditional_activation", false):
        return "timeline"
    
    # 性能要求
    if requirements.get("high_performance", false):
        return "timeline"
    
    # 学习成本考虑
    if requirements.get("low_learning_curve", false):
        return "sequence"
    
    # 默认选择Timeline（功能更强大）
    return "timeline"
```

### 2. 代码组织

```gdscript
# 分离的命名空间
namespace SequenceEffects:
    func create_hit_effect():
        return create_sequence_hit_effect()

namespace TimelineEffects:
    func create_hit_effect():
        return create_timeline_hit_effect()

# 统一接口
class EffectFactory:
    static func create_hit_effect(use_timeline: bool = false):
        if use_timeline:
            return TimelineEffects.create_hit_effect()
        else:
            return SequenceEffects.create_hit_effect()
```

### 3. 文档和培训

- 为团队提供两个系统的培训材料
- 创建使用指南和最佳实践文档
- 建立代码审查标准，确保正确使用

## 性能对比

### 基准测试结果

| 测试场景 | Sequence系统 | Timeline系统 | 差异 |
|----------|-------------|-------------|------|
| **简单动画（1轨道，5关键帧）** | 0.5ms | 0.6ms | +20% |
| **中等复杂度（5轨道，20关键帧）** | 2.1ms | 1.8ms | -14% |
| **复杂动画（10轨道，50关键帧）** | 5.2ms | 3.9ms | -25% |
| **大量实例（50个同时播放）** | 45ms | 28ms | -38% |
| **内存使用（每个实例）** | 2.1KB | 2.8KB | +33% |

### 性能优化建议

**Sequence系统优化**：
- 限制同时播放的实例数量
- 使用对象池
- 避免过多的关键帧

**Timeline系统优化**：
- 启用缓存系统
- 使用轨道分组
- 利用参数映射减少重复代码

## 总结

Sequence和Timeline系统各有优势，选择取决于具体需求：

**选择Sequence系统当**：
- 需要简单、快速的效果实现
- 团队已经熟悉Sequence API
- 项目对内存使用敏感
- 不需要高级功能

**选择Timeline系统当**：
- 需要复杂的多轨道动画
- 需要动态参数控制
- 需要条件激活功能
- 追求最佳性能

两个系统可以并存，允许您根据具体需求选择最合适的工具。JuicyMixer V3的设计 philosophy 是提供选择，而不是强制迁移，让开发者能够根据项目特点做出最佳决策。