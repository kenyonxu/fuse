# Fuse Tween Instruction 开发路线图

**创建日期:** 2026-01-27
**Godot 版本:** 4.5+
**系统状态:** 设计阶段

## 概述

本文档定义了 Fuse 可视化编程系统中 Tween（补间动画）相关指令的开发路线图。Tween 动画是游戏开发中最常用的特效之一，涵盖 UI 动画、角色动作、反馈效果等大量场景。

**设计目标：**
- 提供基于 Godot Tween 系统的完整动画控制能力
- 支持常见的 39 种 Tween 使用模式（参考 [Tween 通用使用模式参考](../../../docs/tween-common-patterns.md)）
- 通过可视化编程简化 Tween 动画的创建和管理

**实现方式：**
所有 Tween 指令将通过封装 Godot 的 `Tween.tween_property()`、`tween_method()`、`tween_callback()` 等 API 实现，提供可视化配置界面。

---

## 指令分类概览

基于 [Tween 通用使用模式参考](../../../docs/tween-common-patterns.md)，我们将 Tween 指令分为 2 大类：

| 类别 | 指令数量 | 描述 | 优先级 |
|------|---------|------|--------|
| **基础属性动画** | 7 | 透明度、位置、缩放、旋转、颜色、通用属性动画 | P0-P3 |
| **预置动画** | 4 | 常见动画快捷方式 | P2-P3 |

**总计：** 11 个核心 Tween 指令

**Fuse Event：**
- **Tween Animation Completed** - Tween 动画完成事件（P1）

**设计原则：**
- ✅ **避免重复** - 不实现与 ActionRunner/For Loop/Wait 重复的功能
- ✅ **专注于 Tween** - 只提供 Tween 系统特有的功能
- ✅ **简洁高效** - 通过组合现有指令实现复杂动画
- ✅ **参数内置** - 不将参数（easing、trans、speed）单独实现为指令

**设计决策说明：**

**❌ 为什么删除 Tween Set Easing Type / Tween Set Transition Type？**
- 基础动画指令已内置 `easing_type` 和 `trans_type` 参数
- 单独指令增加配置复杂度，需要嵌套配置
- 与删除 Tween Auto Free 的逻辑一致 - 参数不应单独存在为指令
- 用户可以在创建动画时直接设置，更符合直觉

**❌ 为什么删除 Tween Set Speed？**
- `speed` 只是 `duration` 的另一种表达方式
- 增加概念复杂度，没有实际价值
- 数学转换简单：`duration = distance / speed`
- 统一使用 `duration` 参数更清晰

**❌ 为什么将 Tween On Complete 改为 Event？**
- 更符合 Fuse 的 Event-driven 架构
- Event 可以有多个监听器，支持一对多
- 复用现有 Event 系统，减少代码重复
- 可视化编程体验更好，可以在编辑器中连接
- 指令嵌套复杂，Event 连接简洁

**使用方式：**
```gdscript
# 并行 Tween 动画 - 使用 ActionRunner.PARALLEL
ActionRunner (execution_mode = PARALLEL):
  - Tween Fade In
  - Tween Move To
  - Tween Scale To

# 序列 Tween 动画 - 使用 ActionRunner.SEQUENTIAL（默认）
ActionRunner:
  - Tween Fade In
  - Wait (0.5 秒)
  - Tween Move To

# 循环 Tween 动画 - 使用 For Loop 指令
For Loop (10 次):
  - Tween Shake Animation
```

---

## 优先级评估体系

使用 **[Fuse 评估框架](./2026-01-25-fuse-evaluation-framework.md)** 对 Tween 指令进行 6 维评估：

1. **需求频率** - 该动画模式在游戏开发中的使用频率
2. **即用性** - 新建工程后能否直接使用
3. **开发复杂度** - 实现难度和工作量（取反评分）
4. **学习曲线** - 用户理解难度（取反评分）
5. **性能影响** - 运行时性能开销（取反评分）
6. **依赖性** - 被其他功能依赖的程度

**加权方案（方案 A - 平衡开发型）：**
```
总分 = 需求频率 × 4.5
     + 即用性 × 3.5
     + (开发复杂度取反) × 2.5
     + (学习曲线取反) × 1.5
     + (性能影响取反) × 1.0
     + 依赖性 × 2.5
```

**优先级分类：**
- **P0 (70-78 分)** - 紧急，核心基础功能
- **P1 (60-69 分)** - 高，主力功能
- **P2 (50-59 分)** - 中，重要功能
- **P3 (40-49 分)** - 低，锦上添花

---

## 一、基础属性动画类

控制节点基本属性的动画指令。

**设计原则：** 所有基础属性动画都支持 `easing_type` 和 `trans_type` 参数，确保：
- ✅ **API 一致性** - 所有动画指令的参数结构一致
- ✅ **灵活性** - 用户可以实现丰富的动画效果（如 Spring Fade、Bounce Move）
- ✅ **可扩展性** - 未来添加新属性动画时遵循相同模式

**默认值建议：**
- `easing_type`: 根据动画特性选择（Fade Out 用 In，Fade In 用 Out，Move 用 InOut）
- `trans_type`: 默认 `SINE`（自然平滑）

### 1.1 Tween Fade In（淡入）⭐ P0

**功能描述：** 让节点逐渐变为不透明

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| target_node | NodePath | 目标节点 |
| duration | float | 动画持续时间（秒） |
| from_alpha | float | 起始透明度（0-1），默认 0.0 |
| to_alpha | float | 目标透明度（0-1），默认 1.0 |
| easing_type | Enum | In/Out/InOut（可选，默认 Out）|
| trans_type | Enum | Linear/Sine/etc.（可选，默认 Sine）|

**使用场景：** UI 淡入、传送出现、场景切换

**评估：**
- 需求频率：**5/5** - 几乎每个游戏都需要
- 即用性：**5/5** - 完全即用
- 开发复杂度：**2/5** → 取反 **4/5** - 简单的属性补间
- 学习曲线：**1/5** → 取反 **5/5** - 概念极其简单
- 性能影响：**2/5** → 取反 **4/5** - 性能开销极小
- 依赖性：**4/5** - 被多个复合动画依赖

**总分：** 76.5 (P0 - 紧急)

**实现要点：**
```gdscript
func execute(context: ExecutionContext) -> void:
    var node = context.get_node(target_node)
    var tween = node.create_tween()
    node.modulate.a = from_alpha
    tween.tween_property(node, "modulate:a", to_alpha, duration)
    await tween.finished
    _finish(context)
```

---

### 1.2 Tween Fade Out（淡出）⭐ P0

**功能描述：** 让节点逐渐变为透明

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| target_node | NodePath | 目标节点 |
| duration | float | 动画持续时间（秒）|
| auto_free | bool | 动画结束后是否自动释放节点（默认 false）|
| easing_type | Enum | In/Out/InOut（可选，默认 In）|
| trans_type | Enum | Linear/Sine/etc.（可选，默认 Sine）|

**使用场景：** UI 淡出、物品消失、场景过渡

**auto_free 参数说明：**
- ✅ **常用场景：** 临时 UI 元素淡出后自动删除、收集物品消失、特效清理
- ✅ **实现方式：** 使用 `tween.tween_callback(node.queue_free)` 在动画结束后调用 `queue_free()`
- ✅ **性能优化：** 避免手动编写清理逻辑，减少内存泄漏风险

**评估：**
- 需求频率：**5/5**
- 即用性：**5/5**
- 开发复杂度：**2/5** → 取反 **4/5**
- 学习曲线：**1/5** → 取反 **5/5**
- 性能影响：**2/5** → 取反 **4/5**
- 依赖性：**4/5**

**总分：** 76.5 (P0 - 紧急)

---

### 1.3 Tween Move To（移动到）⭐ P0

**功能描述：** 平滑移动节点到目标位置

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| target_node | NodePath | 目标节点 |
| target_position | Vector2/Vector3 | 目标位置 |
| duration | float | 持续时间（秒）|
| space | Enum | Global/Local 坐标空间 |
| easing_type | Enum | 缓动类型 |
| trans_type | Enum | 过渡类型 |

**使用场景：** 角色移动、UI 滑入、平台移动

**评估：**
- 需求频率：**5/5**
- 即用性：**4/5** - 需要设置位置
- 开发复杂度：**2/5** → 取反 **4/5**
- 学习曲线：**2/5** → 取反 **4/5**
- 性能影响：**2/5** → 取反 **4/5**
- 依赖性：**5/5** - 被 Move By、Move By Animation 等依赖

**总分：** 75.0 (P0 - 紧急)

---

### 1.4 Tween Scale To（缩放到）⭐ P1

**功能描述：** 平滑缩放节点

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| target_node | NodePath | 目标节点 |
| target_scale | Vector2/Vector3 | 目标缩放 |
| duration | float | 持续时间 |
| easing_type | Enum | 缓动类型 |
| trans_type | Enum | 过渡类型 |

**使用场景：** 弹出效果、按钮反馈、强调动画

**评估：**
- 需求频率：**4/5** - 大多数游戏用到
- 即用性：**4/5**
- 开发复杂度：**2/5** → 取反 **4/5**
- 学习曲线：**2/5** → 取反 **4/5**
- 性能影响：**2/5** → 取反 **4/5**
- 依赖性：**4/5**

**总分：** 70.5 (P0 - 紧急)

---

### 1.5 Tween Rotate To（旋转到）⭐ P1

**功能描述：** 平滑旋转节点到目标角度

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| target_node | NodePath | 目标节点 |
| target_rotation | float | 目标角度（度）|
| duration | float | 持续时间 |
| space | Enum | Global/Local |
| easing_type | Enum | 缓动类型 |

**使用场景：** 攻击挥动、门旋转、道具旋转

**评估：**
- 需求频率：**4/5**
- 即用性：**4/5**
- 开发复杂度：**2/5** → 取反 **4/5**
- 学习曲线：**2/5** → 取反 **4/5**
- 性能影响：**2/5** → 取反 **4/5**
- 依赖性：**4/5**

**总分：** 70.5 (P0 - 紧急)

---

### 1.6 Tween Color Transition（颜色过渡）⭐ P1

**功能描述：** 平滑改变节点颜色

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| target_node | NodePath | 目标节点 |
| target_color | Color | 目标颜色 |
| duration | float | 持续时间 |
| easing_type | Enum | In/Out/InOut（可选，默认 InOut）|
| trans_type | Enum | Linear/Sine/etc.（可选，默认 Sine）|

**使用场景：** 受伤变红、状态指示、UI 主题切换

**评估：**
- 需求频率：**3/5** - 约半数游戏用到
- 即用性：**4/5**
- 开发复杂度：**2/5** → 取反 **4/5**
- 学习曲线：**2/5** → 取反 **4/5**
- 性能影响：**2/5** → 取反 **4/5**
- 依赖性：**3/5**

**总分：** 62.5 (P1 - 高)

---

### 1.7 Tween Property（通用属性动画）⭐ P2

**功能描述：** 动画化任意属性（高级用户）

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| target_node | NodePath | 目标节点 |
| property_path | String | 属性路径（如 "position", "custom_value", "material:shader_parameter:value"）|
| to_value | Variant | 目标值 |
| duration | float | 持续时间 |
| auto_free | bool | 动画结束后是否自动释放节点（默认 false）|
| easing_type | Enum | In/Out/InOut（可选，默认 InOut）|
| trans_type | Enum | Linear/Sine/etc.（可选，默认 Sine）|

**使用场景：**
- 动画化自定义属性
- 动画化嵌套属性（如 "material:shader_parameter:value"）
- 高级用户的灵活需求
- 动画化不支持的具体属性

**auto_free 参数说明：**
- ✅ **高级用户功能：** 提供与 Tween Fade Out 相同的自动清理能力
- ✅ **Material 动画场景：** Material dissolve 动画完成后自动删除临时对象
- ✅ **实现方式：** 与 Tween Fade Out 使用相同的 `tween.tween_callback(node.queue_free)` 模式

**Material 动画支持：**
- ✅ **Shared Material** - 动画化共享材质（影响所有使用该材质的对象）
- ✅ **Material Override** - 动画化材质覆盖（只影响当前节点）
- ✅ **Shader 参数** - 支持 uniform 参数动画（color, dissolve, glow 等）

**技术实现要点：**
- ✅ **使用 PropertyManager** - 参考 `SetPropertyValue` 指令（`set_property_value.gd`）
- ✅ **动态属性列表** - 使用 `PropertyManager.get_writable_properties()` 获取可用属性
- ✅ **类型检查** - 使用 `PropertyInfo` 进行属性类型验证
- ✅ **编辑器集成** - 参考 `set_property_value.gd:148-206` 的 `_get_property_list()` 实现
- ✅ **属性验证** - 使用 `PropertyManager.validate_property_value()` 验证目标值
- ✅ **错误处理** - 参考 `set_property_value.gd:308-317` 的安全设置逻辑
- ✅ **Material 检测** - 自动检测节点是否有 Material，提供材质参数智能提示

**Material 动画示例：**
```gdscript
# Shared Material 动画（影响所有使用该材质的对象）
Tween Property (
  target_node: Sprite2D,
  property_path: "material:shader_parameter:albedo_color",
  to_value: Color.RED,
  duration: 0.3
)

# Material Override 动画（只影响当前节点）
Tween Property (
  target_node: Sprite2D,
  property_path: "material_override:shader_parameter:dissolve_value",
  to_value: 1.0,
  duration: 0.5
)

# UI Dissolve 效果
Tween Property (
  target_node: Control,
  property_path: "material:shader_parameter:dissolve",
  to_value: 1.0,
  duration: 0.3
)
```

**实现参考：**
```gdscript
# 参考 set_property_value.gd 的实现模式
extends BaseInstruction
class_name TweenPropertyInstruction

var target_node: NodePath
var property_path: String  # 使用 PropertyManager 获取可用属性列表
var to_value: Variant
var duration: float
var auto_free: bool = false  # ✅ 新增：自动释放参数

# 运行时状态
var _target_node_instance: Node = null
var _current_property_info: PropertyInfo = null
var _available_properties: Array[PropertyInfo] = []

func _get_property_list() -> Array[Dictionary]:
    # 参考 set_property_value.gd:148-206
    # 使用 PropertyManager.get_writable_properties() 生成动态属性枚举
    pass

func execute(context: ExecutionContext) -> void:
    var target = context.get_node(target_node)

    # 使用 PropertyManager 验证属性
    var validation = PropertyManager.validate_property_value(target, property_path, to_value)
    if not validation.valid:
        _log_error("属性验证失败: " + validation.error)
        return

    # 创建 Tween 并动画化
    var tween = target.create_tween()
    tween.tween_property(target, property_path, to_value, duration)

    # ✅ 如果 auto_free 为 true，在动画结束后释放节点
    if auto_free:
        tween.tween_callback(target.queue_free)

    await tween.finished
    _finish(context)
```

**评估：**
- 需求频率：**2/5** - 高级用法
- 即用性：**3/5** - 需要知道属性名
- 开发复杂度：**3/5** → 取反 **3/5** - 需要 PropertyManager 集成
- 学习曲线：**4/5** → 取反 **2/5** - 需要理解属性系统
- 性能影响：**2/5** → 取反 **4/5**
- 依赖性：**2/5**

**总分：** 43.0 (P2 - 中)

**文件命名：**
- 指令类：`TweenPropertyInstruction`
- 文件名：`addons/fuse/instructions/tween/tween_property.gd`
- 图标：参考 `set_property_value.gd` 使用 `MemberProperty.png`

---

## 二、Fuse Event

Tween 相关的事件，用于响应动画完成等状态变化。

### 2.1 Tween Animation Completed（Tween 动画完成）⭐ P1

**功能描述：** 当 Tween 动画完成时触发

**事件参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| tween_instruction | Instruction | 触发事件的 Tween 指令 |
| target_node | Node | 动画目标节点 |
| duration | float | 动画持续时间 |

**使用场景：**
- 动画完成后播放音效
- 动画完成后触发下一个事件
- 动画完成后更新 UI 状态
- 连锁动画序列
- 对象清理和状态重置

**评估：**
- 需求频率：**5/5** - 动画完成回调是常见需求
- 即用性：**5/5** - 完全即用
- 开发复杂度：**3/5** → 取反 **3/5** - 需要集成 Event 系统
- 学习曲线：**2/5** → 取反 **4/5** - 概念简单
- 性能影响：**1/5** → 取反 **5/5** - 事件触发开销极小
- 依赖性：**5/5** - 被所有动画指令依赖

**总分：** 70.5 (P1 - 高)

**实现要点：**
```gdscript
# Event 类定义
extends BaseEvent
class_name TweenAnimationCompletedEvent

signal animation_completed(tween_instruction: BaseInstruction, target_node: Node, duration: float)

# 在 Tween 指令中触发事件
func _on_tween_finished(tween: Tween, context: ExecutionContext):
    animation_completed.emit(self, target_node, duration)
```

**使用示例：**
```gdscript
# 在编辑器中配置事件
Event: Tween Animation Completed
  Target: Tween Fade Out (duration: 0.5)
  Instructions:
    - Log Message (text: "Fade out completed")
    - Play Sound (sound: "pop.wav")
    - Set Property (target: UI_Button, property: "visible", value: true)
```

---

## 三、预置动画类

常见动画效果的快捷方式。

### 3.1 Tween Shake Animation（震动动画）⭐ P2

**功能描述：** 震动效果（内置震动模式）

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| target_node | NodePath | 目标节点 |
| intensity | float | 震动强度 |
| duration | float | 持续时间 |
| shake_axis | Enum | X/Y/XY 震动轴向 |

**使用场景：** 受击震动、爆炸震动、相机震动

**评估：**
- 需求频率：**3/5**
- 即用性：**5/5** - 完全即用
- 开发复杂度：**3/5** → 取反 **3/5**
- 学习曲线：**2/5** → 取反 **4/5**
- 性能影响：**3/5** → 取反 **3/5** - 循环动画
- 依赖性：**2/5**

**总分：** 54.0 (P2 - 中)

---

### 3.2 Tween Bounce Animation（弹跳动画）⭐ P2

**功能描述：** 弹跳效果（内置弹跳模式）

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| target_node | NodePath | 目标节点 |
| height | float | 弹跳高度 |
| bounce_count | int | 弹跳次数 |
| duration | float | 持续时间 |

**使用场景：** 物品掉落、落地效果

**评估：**
- 需求频率：**3/5**
- 即用性：**5/5**
- 开发复杂度：**3/5** → 取反 **3/5**
- 学习曲线：**2/5** → 取反 **4/5**
- 性能影响：**3/5** → 取反 **3/5**
- 依赖性：**2/5**

**总分：** 54.0 (P2 - 中)

---

### 3.3 Tween Pop Animation（弹出动画）⭐ P2

**功能描述：** 弹出效果（缩放 + 弹簧）

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| target_node | NodePath | 目标节点 |
| target_scale | Vector2/Vector3 | 目标缩放 |
| duration | float | 持续时间 |

**使用场景：** 弹出框、气泡提示、宝箱打开

**评估：**
- 需求频率：**3/5**
- 即用性：**5/5**
- 开发复杂度：**2/5** → 取反 **4/5**
- 学习曲线：**1/5** → 取反 **5/5**
- 性能影响：**2/5** → 取反 **4/5**
- 依赖性：**2/5**

**总分：** 57.5 (P2 - 中)

---

### 3.4 Tween Pulse Animation（脉冲动画）⭐ P3

**功能描述：** 呼吸/脉冲效果

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| target_node | NodePath | 目标节点 |
| min_scale | Vector2/Vector3 | 最小缩放 |
| max_scale | Vector2/Vector3 | 最大缩放 |
| duration | float | 单次循环时间 |

**使用场景：** 待机动画、呼吸效果、可交互提示

**评估：**
- 需求频率：**2/5**
- 即用性：**4/5**
- 开发复杂度：**3/5** → 取反 **3/5**
- 学习曲线：**2/5** → 取反 **4/5**
- 性能影响：**4/5** → 取反 **2/5** - 持续循环
- 依赖性：**1/5**

**总分：** 45.5 (P3 - 低)

---

## 优先级总结

### P0 级（紧急）- 5 个指令
1. **Tween Fade In** (76.5) - 淡入动画
2. **Tween Fade Out** (76.5) - 淡出动画
3. **Tween Move To** (75.0) - 移动动画
4. **Tween Scale To** (70.5) - 缩放动画
5. **Tween Rotate To** (70.5) - 旋转动画

### P1 级（高）- 2 个
6. **Tween Color Transition** (62.5) - 颜色过渡
7. **Tween Animation Completed** (70.5) - 动画完成事件 ⭐

### P2 级（中）- 3 个指令
8. **Tween Pop Animation** (57.5) - 弹出动画
9. **Tween Shake Animation** (54.0) - 震动动画
10. **Tween Bounce Animation** (54.0) - 弹跳动画

### P3 级（低）- 2 个指令
11. **Tween Pulse Animation** (45.5) - 脉冲动画
12. **Tween Property** (43.0) - 通用属性动画

**说明：**
- ✅ 不包含与 ActionRunner/For Loop/Wait 重复的功能
- ✅ 不包含参数型指令（easing_type、trans_type、speed 已内置）
- ✅ 使用 Event 系统替代回调指令
- ✅ 专注于 Tween 系统特有的功能
- ✅ 用户可通过组合现有指令实现复杂动画

---

## 实施建议

### Phase 0A：核心基础（P0）- 1-2 周
优先开发 5 个 P0 级指令：
1. Tween Fade In / Tween Fade Out
2. Tween Move To
3. Tween Scale To
4. Tween Rotate To

**预期成果：**
- 支持基本的属性动画
- 覆盖 80% 的简单动画需求
- 提供清晰的编辑器界面

### Phase 1：完善功能（P1-P2）- 2-3 周
开发 P1 和 P2 级指令和事件：
1. Tween Color Transition
2. Tween Animation Completed Event（重点）
3. 预置动画（Tween Shake、Tween Bounce、Tween Pop）

**预期成果：**
- 完整的 Tween 动画系统
- 覆盖 90% 的游戏动画需求
- 支持动画完成事件
- 良好的开发体验
- Tween Fade Out 和 Tween Property 支持 auto_free 参数

### Phase 2：高级功能（P3）- 1 周
开发 P3 级指令：
1. Tween Pulse Animation
2. Tween Property（通用属性动画）

**预期成果：**
- 支持高级动画需求
- 完整的 Tween 指令集（11 个指令 + 1 个事件）

**组合使用示例：**
```gdscript
# 并行动画示例（使用 ActionRunner.PARALLEL）
ActionRunner (execution_mode = PARALLEL):
  - Tween Fade In (duration: 0.5)
  - Tween Move To (target_position: Vector2(100, 0), duration: 0.5)

# 序列动画示例（使用 ActionRunner.SEQUENTIAL）
ActionRunner:
  - Tween Fade In (duration: 0.5)
  - Wait (duration: 0.3)
  - Tween Move To (target_position: Vector2(100, 0), duration: 0.5)

# 循环动画示例（使用 For Loop）
For Loop (loop_count: 3):
  - Tween Shake Animation (intensity: 5.0, duration: 0.3)

# Event 回调示例（使用 Tween Animation Completed Event）
Event: Tween Animation Completed
  Target Tween: Tween Fade Out
  Instructions:
    - Log Message (text: "Fade out completed!")
    - Play Sound (sound: "pop.wav")
```

**发布说明：**
- Fuse Tween 指令独立于 JuicyMixer 插件
- 两个插件可以同时安装，互不冲突
- Tween 指令使用 Godot 原生 Tween 系统

---

## 技术要点

### 1. 指令元数据
每个 Tween 指令需要实现元数据：
```gdscript
static func _get_instruction_metadata() -> InstructionMetadata:
    var metadata = InstructionMetadata.new()
    metadata.name_key = "FUSE_INSTRUCTION_TWEEN_FADE_IN_NAME"
    metadata.category_key = "FUSE_CATEGORY_TWEEN"
    metadata.description_key = "FUSE_INSTRUCTION_TWEEN_FADE_IN_DESC"
    metadata.keywords = ["tween", "fade", "opacity", "alpha", "淡入", "透明度"]
    return metadata
```

### 2. 异步执行
所有 Tween 指令都是异步的：
```gdscript
extends BaseInstruction
class_name TweenFadeInInstruction

func _init():
    _is_async = true

func execute(context: ExecutionContext) -> void:
    var node = context.get_node(target_node)
    var tween = node.create_tween()

    # 设置动画
    tween.tween_property(node, "modulate:a", to_alpha, duration)

    # 保存 tween 引用以便后续操作
    context.current_tween = tween

    # 等待完成
    await tween.finished

    _finish(context)
```

### 3. 取消支持
实现取消逻辑：
```gdscript
func cancel(context: ExecutionContext) -> void:
    if context.current_tween and context.current_tween.is_valid():
        context.current_tween.kill()
    super.cancel(context)
```

### 4. 资源清理
实现资源清理：
```gdscript
func _cleanup_resources(context: ExecutionContext) -> void:
    if context.current_tween and context.current_tween.is_valid():
        context.current_tween.kill()
        context.current_tween = null
```

### 5. 编辑器集成
- 在 Inspector 中显示缓动类型和过渡类型的可视化预览
- 支持拖拽节点选择目标
- 提供动画时长滑块
- 显示参数说明和示例

### 6. 参数默认值策略
为简化使用，提供合理的默认值：
```gdscript
# Fade In - 默认逐渐显现
easing_type = EASE_OUT
trans_type = TRANS_SINE

# Fade Out - 默认逐渐消失
easing_type = EASE_IN
trans_type = TRANS_SINE

# Move To - 默认平滑移动
easing_type = EASE_IN_OUT
trans_type = TRANS_SINE

# Scale To - 默认弹出效果
easing_type = EASE_OUT
trans_type = TRANS_BACK

# Rotate To - 默认平滑旋转
easing_type = EASE_IN_OUT
trans_type = TRANS_SINE

# Color Transition - 默认平滑过渡
easing_type = EASE_IN_OUT
trans_type = TRANS_SINE
```

---

## 测试策略

### 单元测试
每个指令创建独立测试：
```
addons/fuse/tests/tween/test_tween_fade_in.tscn
addons/fuse/tests/tween/test_tween_fade_in_instruction.gd
```

### 测试内容
1. **基本功能：** 动画是否正确播放
2. **参数验证：** 参数是否正确应用
3. **异步行为：** 是否正确等待完成
4. **取消测试：** 取消是否正常工作
5. **性能测试：** 多个动画同时运行

### 集成测试
测试复合动画：
- Parallel + Sequence 组合
- Loop + Delay 组合
- 回调链测试

---

## 文档要求

### 1. 用户文档
在 `addons/fuse/docs/user_docs/guides/` 下创建：
- `tween-animation-guide.md` - Tween 动画指南
- `tween-best-practices.md` - Tween 最佳实践
- `tween-examples.md` - Tween 示例合集

### 2. 开发文档
在 `addons/fuse/docs/system_docs/architecture/` 下创建：
- `tween-instruction-architecture.md` - Tween 指令架构
- `tween-implementation-guide.md` - Tween 实现指南

### 3. 本地化
在 `translations.csv` 中添加：
```
key,zh_CN,en
FUSE_CATEGORY_TWEEN,补间动画,Tween Animation
FUSE_INSTRUCTION_TWEEN_FADE_IN_NAME,淡入,Fade In
FUSE_INSTRUCTION_TWEEN_FADE_IN_DESC,让节点逐渐变为不透明,Gradually make node opaque
FUSE_INSTRUCTION_TWEEN_FADE_OUT_NAME,淡出,Fade Out
FUSE_INSTRUCTION_TWEEN_FADE_OUT_DESC,让节点逐渐变为透明,Gradually make node transparent
FUSE_INSTRUCTION_TWEEN_MOVE_TO_NAME,移动到,Move To
FUSE_INSTRUCTION_TWEEN_MOVE_TO_DESC,平滑移动节点到目标位置,Smoothly move node to target position
FUSE_INSTRUCTION_TWEEN_PROPERTY_NAME,属性动画,Property Animation
FUSE_INSTRUCTION_TWEEN_PROPERTY_DESC,动画化节点的任意属性,Animate any property of a node
...
```

---

## 参考资源

### 内部文档
- [Tween 通用使用模式参考](../../../docs/tween-common-patterns.md) - 39 种 Tween 模式详细说明
- [Fuse Instruction Roadmap](./2026-01-24-fuse-instruction-roadmap.md) - 主路线图
- [评估框架](./2026-01-25-fuse-evaluation-framework.md) - 评估体系

### 外部资源
- [Godot Tween 官方文档](https://docs.godotengine.org/en/stable/classes/class_tween.html)
- [Feel 插件文档](https://feel-docs.mopipi.com/) - Unity Tween 参考实现

---

## 总结

本路线图定义了 **11 个** Tween 指令和 **1 个** Fuse Event（均以 Tween 前缀命名），分为 3 大类，覆盖了游戏开发中最常见的动画需求。

**删除的重复功能（使用现有指令替代）：**
- ❌ Tween Parallel → 使用 `ActionRunner.PARALLEL`
- ❌ Tween Sequence → 使用 `ActionRunner.SEQUENTIAL`
- ❌ Tween Loop → 使用 `For Loop`
- ❌ Tween Delay → 使用 `Wait`
- ❌ Tween Wait → 使用 `Wait`
- ❌ Tween Method → 高级功能，暂不实现
- ❌ Tween Multi Target → 使用 `For Loop` + Tween 指令
- ❌ **Tween Auto Free** → **使用 `auto_free` 参数**（Tween Fade Out 和 Tween Property）
- ❌ **Tween Set Easing Type** → **使用内置 `easing_type` 参数**（所有基础动画指令）
- ❌ **Tween Set Transition Type** → **使用内置 `trans_type` 参数**（所有基础动画指令）
- ❌ **Tween Set Speed** → **使用 `duration` 参数控制**（可通过计算转换）
- ❌ **Tween On Complete** → **使用 `Tween Animation Completed` Event**（更符合 Fuse 架构）

**新增的通用指令：**
- ✅ **Tween Property** - 通用属性动画，使用 PropertyManager 和 PropertyInfo

**新增的 Fuse Event：**
- ✅ **Tween Animation Completed** - Tween 动画完成事件，P1 级优先级

**优化的参数设计：**
- ✅ **auto_free 参数** - 整合到 Tween Fade Out 和 Tween Property 指令中
- ✅ **easing_type 参数** - 所有基础动画指令内置，避免单独指令
- ✅ **trans_type 参数** - 所有基础动画指令内置，避免单独指令
- ✅ **duration 参数** - 统一使用时间控制，避免速度模式复杂性

**核心优势：**
1. ✅ **完整覆盖** - 支持 39 种常见 Tween 模式
2. ✅ **易于使用** - 可视化配置，无需编写代码
3. ✅ **性能优化** - 基于原生 Tween 系统
4. ✅ **独立运行** - 不依赖其他插件，可单独发布
5. ✅ **避免重复** - 复用 ActionRunner/For Loop/Wait 等现有功能
6. ✅ **系统评估** - 基于 6 维评估体系
7. ✅ **参数内置** - 所有动画指令内置 easing/trans 参数，避免重复指令
8. ✅ **Event 驱动** - 使用 Fuse Event 系统，符合可视化编程架构

**核心优势：**
1. ✅ **完整覆盖** - 支持 39 种常见 Tween 模式
2. ✅ **易于使用** - 可视化配置，无需编写代码
3. ✅ **性能优化** - 基于原生 Tween 系统
4. ✅ **独立运行** - 不依赖其他插件，可单独发布
5. ✅ **系统评估** - 基于 6 维评估体系

**预期成果：**
- **Phase 0A-0B 完成后：** 支持 80% 的简单动画需求
- **Phase 1 完成后：** 完整的 Tween 动画系统，覆盖 90% 需求
- **Phase 2 完成后：** 全功能 Tween 系统，支持高级动画

**与其他系统的集成：**
- **Event 系统：** 支持事件触发动画
- **其他 Instruction：** 支持与其他指令组合使用

---

**文档版本:** 1.4
**最后更新:** 2026-01-27
**更新内容:**
- **删除 4 个重复指令**（总计减少 4 个指令）：
  - ❌ Tween Set Easing Type → 使用内置 `easing_type` 参数
  - ❌ Tween Set Transition Type → 使用内置 `trans_type` 参数
  - ❌ Tween Set Speed → 使用 `duration` 参数控制
  - ❌ Tween On Complete → 改为 Fuse Event
- **新增 Fuse Event**：
  - ✅ **Tween Animation Completed** - Tween 动画完成事件（P1）
- 优化指令清单，从 15 个减少到 **11 个指令 + 1 个事件**
- 更新章节结构：从 5 类减少到 **3 类**
  - 删除"二、时序控制类"
  - 删除"三、缓动控制类"
  - 删除"四、回调类"
  - 新增"二、Fuse Event"
- 更新实施建议，调整开发优先级
- 之前的更新（v1.3）：
  - 删除 Tween Auto Free 指令，改为参数
  - 优化指令清单，从 16 个减少到 15 个
- 之前的更新（v1.2）：
  - 删除与现有功能重复的指令（7 个）
  - 优化指令清单，从 22 个减少到 16 个

**下一步行动：**
1. 评审本路线图，确认指令清单和命名规范
2. 开始 Phase 0A 开发（5 个 P0 指令：Tween Fade In/Out、Tween Move To、Tween Scale To、Tween Rotate To）
3. 开发 Tween Animation Completed Event（P1，高优先级）
4. 创建 Tween Instruction 开发指南
5. 在文档中添加组合使用示例和 Event 使用示例
