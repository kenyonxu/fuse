> 🌐 中文 | [**English**](../../../en_US/user_docs/best_practices/custom_condition.md)

# 自定义 Condition 创建最佳实践指南

## 概述

本指南基于 Fuse Visual Programming 系统中的 Condition 架构，提供了创建自定义 Condition 类的完整最佳实践。通过遵循这些实践，您可以创建高效、可靠且易于维护的自定义条件。

条件是三类砖块中唯一要求"只读"语义的一类：它回答"是不是真的该做"，自身不应改变任何游戏状态。这个定位决定了本指南的大部分实践——从线程安全到缓存再到复合传播。

## 目录

1. [Condition 架构基础](#condition-架构基础)
2. [核心方法实现](#核心方法实现)
3. [生命周期管理](#生命周期管理)
4. [错误处理和日志](#错误处理和日志)
5. [性能优化](#性能优化)
6. [常见实现模式](#常见实现模式)
7. [完整示例](#完整示例)
8. [测试和验证](#测试和验证)

---

## Condition 架构基础

### BaseCondition 核心职责

`BaseCondition` 是所有条件类的基类，提供以下核心功能：

- **模板方法执行**：`check(context)` 统一处理缓存、取反和日志，子类只需实现真正的判断逻辑
- **缓存机制**：`enable_cache` 系列配置，高频条件可按时间与上下文哈希失效缓存
- **线程安全声明**：`is_thread_safe` 属性驱动多线程条件评估器决定并行或回落主线程
- **批量检查**：`check_batch()` / `check_dependencies_batch()` 支持批量场景
- **元数据**：条件名称、分类和关键词信息（通过 `ConditionMetadata` 类）
- **依赖声明**：`get_affected_variables()` 声明条件影响的变量，供静态分析与竞态预警使用

### 命名规范

- **文件名**：`check_` 或 `compare_` 前缀 + snake_case（如 `check_health_value.gd`、`compare_variable.gd`）
- **类名**：`Check` 或 `Compare` 前缀 + PascalCase（如 `CheckHealthValue`、`CompareVariable`），**不加 `Condition` 后缀**
- 命名描述"判断什么"，而不是"怎么判断"——`CheckNodeExists` 优于 `CheckGetNodeOrNull`

### 只读契约

条件在一条 Trigger 逻辑里可能每帧都被求值，也可能被并行评估器搬到工作线程。因此：

- `check()` 及其内部**不得修改**变量、节点属性或任何游戏状态
- 需要副作用的是 Instruction，不是 Condition——判断和执行分离是整个模型的地基
- 如果判断本身开销大且允许过期（如射线检测），用缓存机制而不是"把结果写进变量"

---

## 核心方法实现

### check() 是模板方法——不要重写它

`BaseCondition.check(context)` 内部依次处理：缓存命中判断 → 调用子类逻辑 → `negate_result` 取反 → 日志。自定义条件**重写 `_evaluate_condition()`**：

```gdscript
extends BaseCondition
class_name CheckManaFull

@export var mana_variable: String = "mana"
@export var max_mana: float = 100.0

func _evaluate_condition(context: ExecutionContext) -> bool:
    var current: float = context.get_local_variable(mana_variable)
    return current >= max_mana
```

要点：

1. **返回值必须是 `bool`**——不要返回 Variant 或 null，错误处理走异常路径而不是返回非布尔
2. **`negate_result` 由系统处理**——不要在子类里自己取反；用户在 Inspector 勾"取反"即可让 `CheckA` 变成"非 A"，这正是"判断描述"式命名的价值
3. **空值防御放判断内**：目标节点/变量可能不存在，返回 `false` 并记日志，而不是让脚本错误中断执行

### 元数据：_get_condition_metadata()

静态方法返回 `ConditionMetadata`（继承 `FuseMetadata` 全部字段）：

```gdscript
static func _get_condition_metadata() -> ConditionMetadata:
    var metadata := ConditionMetadata.new()
    metadata.name_key = "FUSE_CONDITION_CHECK_MANA_FULL_NAME"
    metadata.category_key = "FUSE_CATEGORY_VARIABLES"
    metadata.description_key = "FUSE_CONDITION_CHECK_MANA_FULL_DESC"
    metadata.keywords = ["法力", "满", "mana", "check", "蓝量"]
    metadata.builtin_icon = "ResourcePreloader"
    return metadata
```

三条硬约定：

1. **必须实现**，否则组件扫描注册与 preset AI 上下文 dump 都会**静默跳过**你的条件
2. `category_key` 从现有分类枚举中选择（如 `FUSE_CATEGORY_VARIABLES` / `FUSE_CATEGORY_PHYSICS`），不要发明新 key——分类的本地化翻译按 key 查表
3. `keywords` 建议中英混合并包含用户会搜的同义词——指令/条件选择器的搜索与 AI 生成 preset 时的组件匹配都依赖它

---

## 生命周期管理

条件是 `Resource`，比 Trigger 节点活得久（会被复制、跨项目复用），生命周期实践围绕"无状态"展开：

- **优先无状态**：所有信息来自 `@export` 配置和 `check()` 收到的 `context`，不在条件实例上存可变运行时数据
- 必须有运行时状态时（如缓存计数），实现 `reset()` 并保证可重复调用
- 条件配置变更会影响线程安全判定时，调用 `reset_thread_safety_cache()` 让判定重算
- 不要在条件里缓存 Node 引用——用 NodePath 每次 `context` 解析（与指令侧同一规范），避免节点销毁后悬空

---

## 错误处理和日志

```gdscript
func _evaluate_condition(context: ExecutionContext) -> bool:
    var node := context.get_node_or_null(target_node)
    if node == null:
        push_warning("CheckNodeActive: 目标节点不存在 %s" % target_node)
        return false
    return node.is_active
```

- **失败 = false，不是错误**："节点不存在所以条件不成立"是正常业务语义，用 `push_warning` 记录即可；真正异常（配置结构坏了）才 `push_error`
- 日志走 `log_level` 分级，跟随条件实例的配置输出，不要直接 `print`
- 静态分析器会扫条件的问题（空路径、未声明变量）——`get_affected_variables()` 返回真实影响的变量名列表，能让 Topology 面板和竞态预警把你的条件算进去

---

## 性能优化

### 线程安全：默认不安全，显式声明

`BaseCondition._compute_thread_safety()` **默认返回 false**——不重写它，你的条件永远在主线程串行执行。这是保守正确的默认值：并行评估器（`ParallelConditionEvaluator`）会把标记安全的条件搬进工作线程，不安全的留在主线程。

声明安全要满足两个前提：`_evaluate_condition()` 内部只读、且不触碰只能在主线程访问的 API（场景树遍历、节点属性、信号发射等）。纯变量/数学判断可以放心声明：

```gdscript
func _compute_thread_safety() -> bool:
    return true  # 只读 context 变量做比较，无场景树访问
```

### 缓存：高频条件的止损阀

每帧触发 + 判断昂贵的场景（射线、距离查询）开启缓存：

| 配置 | 建议值 | 说明 |
|------|--------|------|
| `enable_cache` | 按需 | 默认关闭；判断开销小于 0.1ms 的不要开 |
| `cache_duration` | 0.1~0.5s | 过期时间；竞速类玩法调小 |
| `cache_context_changes` | true | 上下文变化即失效，保证正确性 |
| `hash_all_variables` | false | 默认只哈希依赖变量；声明了 `get_affected_variables()` 才能精确失效 |

缓存由 `check()` 模板方法统一管理，子类无感知——`get_cache_info()` 可查命中状态用于调试。

### 复合条件的传播语义

复合条件（`CheckAll` / `CheckAny` / `CheckNot`）的线程安全是**传播判定**：所有子条件都安全，复合才安全（`CheckAll._compute_thread_safety()` 逐个检查并在首个不安全处短路）。因此：

- 你声明安全的一个条件，会让所有包含它的复合条件获得并行资格——声明前想清楚
- 自定义复合条件时沿用同样的传播逻辑，不要自作主张返回 true

---

## 常见实现模式

### 模式一：变量比较型

最常见也最该做线程安全的类型。参照 `CompareVariable`：参数走变量绑定双轨（直接值/变量来源），作用域可配。写这类条件时把"比较什么"拆成清晰的 `@export`，把枚举（EQUAL/GREATER/LESS）暴露给 Inspector。

### 模式二：场景查询型

查节点状态（存在性、分组、属性）。特征是必须访问场景树——**不要声明线程安全**；开销大就配缓存。参照 `CheckNodeExists` / `CheckNodeProperty`。

### 模式三：复合逻辑型

聚合子条件数组。除线程安全传播外，注意 `@export var conditions: Array[BaseCondition]` 在 Inspector 里的嵌套编辑体验——保持子条件零耦合，取反、启用开关这些交给基类和用户。

### 模式四：表达式委托型

一行 `ExpressionCondition` 能顶多个基础比较时，不必写新条件——先评估是否真的需要自定义类；表达式条件本身支持变量绑定，多数"临时判断"不该沉淀为类。

---

## 完整示例

一个带缓存、线程安全、依赖声明的完整条件：

```gdscript
@tool
extends BaseCondition
class_name CheckDistanceLessThan

@export var source_variable: String = "player_pos"
@export var target_variable: String = "boss_pos"
@export var max_distance: float = 200.0

@export_group("Cache")
@export var enable_cache: bool = true:
    set(value):
        enable_cache = value
@export var cache_duration: float = 0.2

func _evaluate_condition(context: ExecutionContext) -> bool:
    var a: Vector2 = context.get_local_variable(source_variable)
    var b: Vector2 = context.get_local_variable(target_variable)
    return a.distance_to(b) < max_distance

func _compute_thread_safety() -> bool:
    return true  # 纯变量数学比较

func get_affected_variables() -> Array[String]:
    return [source_variable, target_variable]

static func _get_condition_metadata() -> ConditionMetadata:
    var metadata := ConditionMetadata.new()
    metadata.name_key = "FUSE_CONDITION_CHECK_DISTANCE_LESS_THAN_NAME"
    metadata.category_key = "FUSE_CATEGORY_DISTANCE"
    metadata.description_key = "FUSE_CONDITION_CHECK_DISTANCE_LESS_THAN_DESC"
    metadata.keywords = ["距离", "distance", "小于", "接近", "near"]
    metadata.builtin_icon = "Node2D"
    return metadata
```

配套本地化条目加入 `addons/fuse/localization/translations.csv`（key、中文、英文三列），否则 Inspector 显示原始 key。

---

## 测试和验证

自定义条件的最小验证清单：

1. **真/假/边界三态**：条件成立、不成立、边界值（等于阈值）各测一次
2. **取反组合**：勾选 `negate_result` 后结果镜像
3. **空值路径**：目标变量/节点不存在时返回 false 而非脚本错误
4. **缓存行为**（若启用）：同上下文重复 check 不重复计算，上下文变化后失效
5. **元数据注册**：重启编辑器后在条件选择器对应分类下能找到、搜索 keywords 能命中
6. **本地化**：中英文 Inspector 名称正常显示

验证清单通过后，参照 [条件生成 skill](../../../../agent_skills/fuse-condition-generator/SKILL.md) 的完整规范（模板、命名禁则与验证 gate）做最终对齐——该 skill 是条件组件规范的最终权威，本指南是其架构原理的详述。

---

**相关文档：**

- [自定义 Event 创建最佳实践](custom_event.md)
- [自定义 Instruction 创建最佳实践](custom_instruction.md)
- [条件系统指南](../guides/46-comprehensive-conditions-guide.md)
- [多线程优化指南](../guides/52-multithreading-optimization.md)
