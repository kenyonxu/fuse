# JuicyPropertyBuffer 混合系统设计文档

**版本：** 1.0
**最后更新：** 2026-01-10
**作者：** Claude Code (AI Assistant)

---

## 目录

1. [概述](#概述)
2. [核心概念](#核心概念)
3. [三阶段混合过程](#三阶段混合过程)
4. [Context ID 系统](#context-id-系统)
5. [优先级系统](#优先级系统)
6. [类型支持](#类型支持)
7. [API 参考](#api-参考)
8. [使用示例](#使用示例)
9. [最佳实践](#最佳实践)
10. [故障排查](#故障排查)

---

## 概述

JuicyPropertyBuffer 是 JuicyMixer 的核心组件，负责集中管理来自多个来源（轨道、中间件）的属性修改。它提供了一个虚拟缓冲区，避免多次调用 `Node.set()`，并通过混合模式系统智能地组合多个属性修改。

**设计目标：**
- ✅ 避免重复的 `Node.set()` 调用
- ✅ 支持多个来源修改同一属性
- ✅ 提供灵活的混合模式（覆盖、加法、乘法）
- ✅ 防止同来源重复累积
- ✅ 类型安全的属性操作

---

## 核心概念

### BlendMode（混合模式）

PropertyBuffer 支持三种混合模式：

```gdscript
enum BlendMode {
    OVERRIDE_BASE,    # 覆盖基础值
    ADDITIVE,         # 叠加偏移量
    MULTIPLICATIVE    # 乘法混合
}
```

| 混合模式 | 用途 | 数学表达 | 典型场景 |
|---------|------|---------|---------|
| `OVERRIDE_BASE` | 完全覆盖原始值 | `final = value` | 设置绝对属性值 |
| `ADDITIVE` | 添加偏移 | `final = base + offset` | 震动、位置偏移 |
| `MULTIPLICATIVE` | 缩放 | `final = base × multiplier` | 缩放脉冲、淡入淡出 |

### PropertySample（属性样本）

单个属性修改的数据结构：

```gdscript
class PropertySample:
    var context_id: String        # 来源标识符
    var value: Variant            # 修改值
    var weight: float = 1.0       # 权重（保留）
    var priority: int = 0         # 优先级
    var timestamp: float          # 时间戳
    var alpha_mode: int = 0       # Color alpha 控制模式
```

---

## 三阶段混合过程

PropertyBuffer 使用确定的三阶段混合过程来组合多个来源的属性修改：

### 阶段1：基础值（OVERRIDE_BASE）

```
如果存在 OVERRIDE_BASE 样本：
    基础值 = 最后一个 OVERRIDE_BASE 样本的值
否则：
    基础值 = 节点的原始属性值
```

**特性：**
- 只有 OVERRIDE_BASE 样本时，直接返回其值（真正的覆盖）
- 多个 OVERRIDE_BASE 样本时，最后一个胜出

**示例：**
```gdscript
# 场景1：纯 OVERRIDE_BASE
原始值: 100
OVERRIDE_BASE: 200
最终值: 200  # 覆盖，不是 100 + 200

# 场景2：多个 OVERRIDE_BASE
OVERRIDE_BASE #1: 150 (priority=0)
OVERRIDE_BASE #2: 200 (priority=10)
最终值: 200  # 最后一个胜出
```

### 阶段2：乘法偏移（MULTIPLICATIVE）

```
如果存在 MULTIPLICATIVE 样本：
    乘法偏移 = 1.0 (单位值)
    对每个 MULTIPLICATIVE 样本:
        乘法偏移 *= 样本值
    乘法结果 = 基础值 × 乘法偏移
否则：
    乘法结果 = 基础值
```

**特性：**
- 支持类型安全的乘法（float、Vector2、Vector3、Color）
- Color 类型支持 alpha 控制模式

**Color Alpha 控制模式：**

```gdscript
# PropertySample.alpha_mode 可选值：
0 = 乘法 alpha（默认）     # final.a = base.a * sample.a
1 = 保留 alpha            # final.a = base.a
2 = 设置 alpha            # final.a = sample.a
```

**示例：**
```gdscript
# 场景1：Vector2 缩放
基础值: Vector2(10, 10)
MULTIPLICATIVE: Vector2(2.0, 2.0)
最终值: Vector2(20, 20)  # 10 * 2.0

# 场景2：多个 MULTIPLICATIVE
基础值: Vector2(10, 10)
MULTIPLICATIVE #1: Vector2(2.0, 2.0)
MULTIPLICATIVE #2: Vector2(1.5, 1.5)
最终值: Vector2(30, 30)  # 10 * 2.0 * 1.5

# 场景3：Color alpha 控制
基础值: Color(1, 1, 1, 0.5)  # 半透明白色
MULTIPLICATIVE (alpha_mode=0): Color(0.5, 0.5, 0.5, 0.8)
最终值: Color(0.5, 0.5, 0.5, 0.4)  # alpha = 0.5 * 0.8 = 0.4

MULTIPLICATIVE (alpha_mode=1): Color(0.5, 0.5, 0.5, 0.8)
最终值: Color(0.5, 0.5, 0.5, 0.5)  # alpha = 0.5 (保留原始)

MULTIPLICATIVE (alpha_mode=2): Color(0.5, 0.5, 0.5, 0.8)
最终值: Color(0.5, 0.5, 0.5, 0.8)  # alpha = 0.8 (设置新值)
```

### 阶段3：加法偏移（ADDITIVE）

```
如果存在 ADDITIVE 样本：
    加法偏移 = 0.0 (零值)
    对每个 ADDITIVE 样本:
        加法偏移 += 样本值
    最终值 = 乘法结果 + 加法偏移
否则：
    最终值 = 乘法结果
```

**特性：**
- Color 类型逐通道累积，alpha 使用最后一个样本
- 纯 ADDITIVE 样本时，从零值开始累积（对于 Color）

**示例：**
```gdscript
# 场景1：Vector2 加法
乘法结果: Vector2(100, 100)
ADDITIVE: Vector2(10, 20)
最终值: Vector2(110, 120)

# 场景2：Color 加法
原始值: Color(0.5, 0.5, 0.5, 1.0)
ADDITIVE #1: Color(0.2, 0.1, 0.0, 0.9)
ADDITIVE #2: Color(0.1, 0.2, 0.0, 0.8)
最终值: Color(0.8, 0.8, 0.5, 0.8)  # RGB 累积，alpha 使用最后一个

# 场景3：三阶段组合
原始值: 100
OVERRIDE_BASE: 200          # 阶段1: 基础值 = 200
MULTIPLICATIVE: 1.5         # 阶段2: 200 * 1.5 = 300
ADDITIVE: 50                # 阶段3: 300 + 50 = 350
最终值: 350
```

---

## Context ID 系统

### 目的

防止同一来源多次更新时重复累积。

### 工作原理

每个来源（轨道或中间件）都有唯一的 `context_id`：
- **轨道**: `"track_" + str(track_instance_id)`
- **中间件**: `"middleware_" + middleware_name`

对于 `ADDITIVE` 和 `MULTIPLICATIVE` 模式，新样本会替换相同 `context_id` 的旧样本。

### 示例

```gdscript
# 场景：同一轨道每帧更新多次
# 帧内第1次更新
buffer.add_sample(node, "position", Vector2(10, 0), ADDITIVE, "track_1234")
# 此时 position = original + 10

# 帧内第2次更新（同一轨道）
buffer.add_sample(node, "position", Vector2(20, 0), ADDITIVE, "track_1234")
# 旧样本 (10, 0) 被移除，新样本 (20, 0) 被添加
# 此时 position = original + 20（不是 original + 10 + 20！）
```

### 关键点

- ✅ **ADDITIVE/MULTIPLICATIVE** 样本会被替换
- ❌ **OVERRIDE_BASE** 样本不会被替换（多个 OVERRIDE_BASE 样本会共存，最后一个胜出）
- 📝 **为什么这样设计？** 防止同一轨道在单帧内多次调用导致值累积过大

---

## 优先级系统

### 重要：优先级的作用域

⚠️ **优先级只适用于每个混合模式内，不影响跨混合模式交互。**

### 工作原理

在每个混合模式内，样本按优先级排序（高优先级在前）：
- **OVERRIDE_BASE**: 高优先级的 OVERRIDE_BASE 样本先插入，但最后一个样本决定最终值
- **ADDITIVE/MULTIPLICATIVE**: 高优先级的样本先应用，但加法和乘法通常是可交换的

### 限制：跨混合模式

**优先级不会阻止低优先级样本影响结果。**

#### 示例场景

```gdscript
# 中间件 A：高优先级，想要覆盖
add_middleware_sample(node, "scale", Vector2(2, 2), OVERRIDE_BASE, "A", 10)

# 中间件 B：低优先级，添加偏移
add_middleware_sample(node, "scale", Vector2(1, 1), ADDITIVE, "B", 0)

# 预期：高优先级的 A 应该覆盖所有
# 实际：scale = 2.0 + 1.0 = 3.0
# 原因：三阶段混合过程
#   阶段1: 基础值 = 2.0 (A 的 OVERRIDE_BASE)
#   阶段2: 无 MULTIPLICATIVE
#   阶段3: 加法 = 2.0 + 1.0 (B 的 ADDITIVE)
```

### 解决方案

要真正覆盖所有效果，在最终中间件中使用 `OVERRIDE_BASE`：

```gdscript
# 中间件 A：设置基础
add_middleware_sample(node, "scale", Vector2(2, 2), OVERRIDE_BASE, "A", 10)

# 中间件 B：添加偏移
add_middleware_sample(node, "scale", Vector2(1, 1), ADDITIVE, "B", 0)

# 中间件 C：最终覆盖（高优先级）
add_middleware_sample(node, "scale", Vector2(5, 5), OVERRIDE_BASE, "C", 100)

# 结果：scale = 5.0（C 覆盖了所有之前的）
```

---

## 类型支持

### 支持的类型

| 类型 | OVERRIDE_BASE | ADDITIVE | MULTIPLICATIVE |
|------|--------------|----------|----------------|
| `float` | ✅ | ✅ | ✅ |
| `int` | ✅ | ✅ | ✅ |
| `Vector2` | ✅ | ✅ | ✅ |
| `Vector3` | ✅ | ✅ | ✅ |
| `Color` | ✅ | ✅ | ✅ (支持 alpha_mode) |

### 类型安全

PropertyBuffer 在混合前检查类型，不支持的操作会发出警告并返回合理的默认值。

#### Vector2/Vector3 乘法

```gdscript
# Vector2 * float: 标准 Godot 乘法
Vector2(10, 10) * 2.0 = Vector2(20, 20)

# Vector2 * Vector2: 逐分量乘法
Vector2(10, 10) * Vector2(2, 3) = Vector2(20, 30)

# 不支持的组合会发出警告
Vector2(10, 10) * "invalid"  # 警告：不支持的乘法类型
```

#### Color 运算

```gdscript
# Color ADDITIVE: 逐通道相加
Color(0.5, 0.5, 0.5, 1.0) + Color(0.2, 0.1, 0.0, 0.9)
= Color(0.7, 0.6, 0.5, 0.9)  # alpha 使用第二个值

# Color MULTIPLICATIVE (alpha_mode=0): 逐通道相乘
Color(1.0, 0.5, 0.5, 0.5) * Color(0.8, 0.8, 0.8, 0.8)
= Color(0.8, 0.4, 0.4, 0.4)  # alpha 也乘法
```

---

## API 参考

### 核心方法

#### `add_sample()`

添加一个属性样本。

```gdscript
func add_sample(
    target: Node,            # 目标节点
    property: String,        # 属性名
    value: Variant,          # 值
    mode: BlendMode,         # 混合模式
    context_id: String = ""  # 上下文ID（可选）
) -> void
```

**示例：**
```gdscript
buffer.add_sample(sprite, "position", Vector2(10, 0), BlendMode.ADDITIVE, "shake")
```

#### `add_middleware_sample()`

添加中间件样本（带优先级）。

```gdscript
func add_middleware_sample(
    target: Node,
    property: String,
    value: Variant,
    mode: BlendMode,
    middleware_name: String,
    priority: int = 0
) -> void
```

**示例：**
```gdscript
buffer.add_middleware_sample(sprite, "scale", Vector2(2, 2),
    BlendMode.OVERRIDE_BASE, "camera_zoom", 10)
```

#### `flush_all_samples()`

批处理应用所有样本到目标节点。

```gdscript
func flush_all_samples() -> void
```

**示例：**
```gdscript
# 添加多个样本
buffer.add_sample(node, "position", offset1, ADDITIVE, "track1")
buffer.add_sample(node, "scale", scale1, MULTIPLICATIVE, "track2")

# 一次性应用所有样本
buffer.flush_all_samples()
```

#### `flush_target_samples()`

应用特定目标的所有样本。

```gdscript
func flush_target_samples(target: Node) -> void
```

### 清理方法

#### `remove_middleware_samples()`

移除指定中间件的所有样本。

```gdscript
func remove_middleware_samples(middleware_name: String) -> void
```

#### `remove_middleware_samples_by_mode()` ✨新增

移除指定中间件的特定混合模式样本。

```gdscript
func remove_middleware_samples_by_mode(
    middleware_name: String,
    mode: BlendMode
) -> void
```

**示例：**
```gdscript
# 只移除 ADDITIVE 样本，保留 OVERRIDE_BASE 和 MULTIPLICATIVE
buffer.remove_middleware_samples_by_mode("camera_shake", BlendMode.ADDITIVE)
```

#### `remove_middleware_samples_for_property()` ✨新增

移除指定中间件对特定属性的所有样本。

```gdscript
func remove_middleware_samples_for_property(
    middleware_name: String,
    property: String
) -> void
```

**示例：**
```gdscript
# 只移除 position 属性的样本，保留其他属性
buffer.remove_middleware_samples_for_property("camera_shake", "position")
```

#### `clear_target_samples()`

清除特定目标的所有样本。

```gdscript
func clear_target_samples(target: Node) -> void
```

#### `clear_property_samples()`

清除特定目标的特定属性的所有样本。

```gdscript
func clear_property_samples(target: Node, property: String) -> void
```

### 查询方法

#### `get_buffer_stats()`

获取缓冲区统计信息。

```gdscript
func get_buffer_stats() -> Dictionary
```

**返回：**
```gdscript
{
    "total_targets": 5,       # 总目标数
    "total_properties": 12,   # 总属性数
    "total_samples": 35,      # 总样本数
    "dirty_targets": 3        # 待刷新的目标数
}
```

---

## 使用示例

### 示例1：简单的位置偏移

```gdscript
var buffer = JuicyPropertyBuffer.new()
var sprite = Sprite2D.new()
sprite.position = Vector2(100, 100)

# 添加位置偏移
buffer.add_sample(sprite, "position", Vector2(10, 0), BlendMode.ADDITIVE, "shake")
buffer.flush_all_samples()

# 结果：sprite.position = Vector2(110, 100)
```

### 示例2：缩放脉冲效果

```gdscript
# 使用 MULTIPLICATIVE 创建缩放脉冲
var time = Time.get_time_elapsed_from_scene()
var pulse = 1.0 + 0.5 * sin(time * 10.0)

buffer.add_sample(sprite, "scale", Vector2(pulse, pulse),
    BlendMode.MULTIPLICATIVE, "pulse_effect")
buffer.flush_all_samples()

# 结果：sprite.scale = original_scale * pulse
```

### 示例3：组合多个效果

```gdscript
# 组合 OVERRIDE_BASE + MULTIPLICATIVE + ADDITIVE
buffer.add_sample(sprite, "scale", Vector2(2, 2), BlendMode.OVERRIDE_BASE, "base")
buffer.add_sample(sprite, "scale", Vector2(1.5, 1.5), BlendMode.MULTIPLICATIVE, "multi")
buffer.add_sample(sprite, "scale", Vector2(0.5, 0.5), BlendMode.ADDITIVE, "add")
buffer.flush_all_samples()

# 结果：(2 * 1.5) + 0.5 = 3.5
```

### 示例4：Color alpha 控制

```gdscript
# 创建淡入效果但保持不透明度
sprite.modulate = Color(1, 1, 1, 1.0)

# 使用 MULTIPLICATIVE 模式，alpha_mode=1 保留原始 alpha
var sample = PropertySample.new()
sample.value = Color(0.5, 0.5, 0.5, 1.0)
sample.alpha_mode = 1  # 保留 alpha

# (通过 add_sample 并设置 alpha_mode)
# 结果：modulate = Color(0.5, 0.5, 0.5, 1.0) - RGB 变暗，alpha 保持 1.0
```

### 示例5：中间件优先级

```gdscript
# 两个中间件竞争控制同一属性
# 中间件 A：低优先级，设置基础值
buffer.add_middleware_sample(sprite, "scale", Vector2(2, 2),
    BlendMode.OVERRIDE_BASE, "middleware_A", 0)

# 中间件 B：高优先级，想要覆盖
buffer.add_middleware_sample(sprite, "scale", Vector2(5, 5),
    BlendMode.OVERRIDE_BASE, "middleware_B", 10)

buffer.flush_all_samples()

# 结果：scale = Vector2(5, 5)（高优先级的 B 胜出）
```

### 示例6：防止重复累积

```gdscript
# 场景：同一轨道在帧内更新多次
# 第一次更新
buffer.add_sample(node, "position", Vector2(10, 0),
    BlendMode.ADDITIVE, "track_1234")

# 第二次更新（同一帧）
buffer.add_sample(node, "position", Vector2(20, 0),
    BlendMode.ADDITIVE, "track_1234")

buffer.flush_all_samples()

# 结果：position = original + 20
# 旧值 10 被新值 20 替换，不会累积到 30
```

---

## 最佳实践

### 1. 选择正确的混合模式

| 目标 | 推荐模式 | relative 设置 |
|------|---------|---------------|
| 设置绝对值 | `OVERRIDE_BASE` | `false` |
| 添加偏移 | `ADDITIVE` | `true` |
| 缩放 | `MULTIPLICATIVE` | `true` |
| 补间动画 | `OVERRIDE_BASE` | `false` |
| 震动效果 | `ADDITIVE` | `true` |
| 淡入淡出 | `MULTIPLICATIVE` | `true` |

### 2. 使用 Context ID 防止累积

```gdscript
# ✅ 好的做法：使用唯一的 context_id
var track_id = "track_" + str(track.get_instance_id())
buffer.add_sample(node, "position", offset, ADDITIVE, track_id)

# ❌ 坏的做法：不使用 context_id
buffer.add_sample(node, "position", offset, ADDITIVE)
# 多次调用会累积！
```

### 3. 中间件优先级管理

```gdscript
# 定义优先级常量
const PRIORITY_CAMERA_HIGH = 100
const PRIORITY_CAMERA_LOW = 10
const PRIORITY_EFFECT = 0

# 高优先级相机效果
buffer.add_middleware_sample(node, "position", shake_offset,
    ADDITIVE, "camera_shake", PRIORITY_CAMERA_HIGH)

# 低优先级效果
buffer.add_middleware_sample(node, "scale", pulse_scale,
    MULTIPLICATIVE, "pulse", PRIORITY_EFFECT)
```

### 4. 批处理性能优化

```gdscript
# ✅ 好的做法：批处理
for i in range(100):
    buffer.add_sample(nodes[i], "position", offsets[i], ADDITIVE)
buffer.flush_all_samples()  # 一次刷新所有

# ❌ 坏的做法：逐个刷新
for i in range(100):
    buffer.add_sample(nodes[i], "position", offsets[i], ADDITIVE)
    buffer.flush_target_samples(nodes[i])  # 100 次刷新！
```

### 5. 正确的清理

```gdscript
# 在中间件停用时清理
func _on_middleware_stopped(middleware_name: String):
    # 清理所有样本
    buffer.remove_middleware_samples(middleware_name)

    # 或只清理特定模式
    buffer.remove_middleware_samples_by_mode(middleware_name, ADDITIVE)

    # 或只清理特定属性
    buffer.remove_middleware_samples_for_property(middleware_name, "position")
```

---

## 故障排查

### 问题1：值没有按预期累积

**症状：** 多次添加 ADDITIVE 样本但值没有累积

**原因：** 相同 `context_id` 的样本会相互替换

**解决方案：** 确保使用不同的 `context_id`
```gdscript
# ❌ 错误：相同 context_id
buffer.add_sample(node, "pos", offset1, ADDITIVE, "same_id")
buffer.add_sample(node, "pos", offset2, ADDITIVE, "same_id")
# 结果：只有 offset2 生效

# ✅ 正确：不同 context_id
buffer.add_sample(node, "pos", offset1, ADDITIVE, "source_1")
buffer.add_sample(node, "pos", offset2, ADDITIVE, "source_2")
# 结果：offset1 + offset2
```

### 问题2： OVERRIDE_BASE 没有覆盖

**症状：** OVERRIDE_BASE 后值仍然是原始值加偏移

**原因：** 混合模式按三阶段处理， OVERRIDE_BASE 只影响阶段1

**解决方案：** 确保没有其他阶段的样本
```gdscript
# ❌ 仍然受 ADDITIVE 影响
buffer.add_sample(node, "scale", Vector2(5, 5), OVERRIDE_BASE, "override")
buffer.add_sample(node, "scale", Vector2(1, 1), ADDITIVE, "add")
# 结果：5 + 1 = 6

# ✅ 真正覆盖
buffer.add_sample(node, "scale", Vector2(5, 5), OVERRIDE_BASE, "override")
buffer.flush_all_samples()
# 结果：5
```

### 问题3：类型不匹配错误

**症状：** `不支持的乘法类型` 警告

**原因：** 尝试不支持类型组合的乘法

**解决方案：** 确保类型兼容
```gdscript
# ❌ 错误：Color * Vector2
buffer.add_sample(node, "color", Color(1, 1, 1), MULTIPLICATIVE)
# 但 base_value 是 Vector2

# ✅ 正确：确保类型匹配
if base_value is Color:
    buffer.add_sample(node, "color", Color(0.5, 0.5, 0.5), MULTIPLICATIVE)
```

### 问题4： Color alpha 行为意外

**症状：** Color MULTIPLICATIVE 改变了不透明度

**原因：** 默认 `alpha_mode=0` 会乘法 alpha

**解决方案：** 使用 `alpha_mode=1` 保留 alpha
```gdscript
# 设置 alpha_mode（需要访问 PropertySample）
sample.alpha_mode = 1  # 保留原始 alpha
```

---

## 版本历史

### v1.0 (2026-01-10)
- ✅ 修复问题1：MULTIPLICATIVE 模式类型安全（null 处理）
- ✅ 修复问题2：Color alpha 控制（alpha_mode）
- ✅ 修复问题3：优先级系统文档说明
- ✅ 修复问题4：高级中间件清理 API
- ✅ 修复问题5：完整的混合系统文档

---

**文档结束**
