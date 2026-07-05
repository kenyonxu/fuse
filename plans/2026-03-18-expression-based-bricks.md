# 基于 Godot Expression 的功能型 Bricks 组件

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Date:** 2026-03-18
**Status:** Brainstorm complete, implementation planned for items 1/2/3
**Branch:** Develop_brick

---

## 背景

Bricks 已实现 `MathExpression` 指令，基于 Godot 的 `Expression` 类执行数学表达式。该指令支持变量引用 (`{local:xxx}`, `{scope:xxx}`, `{global:xxx}`)、基础运算、向量字面量和类型转换输出。

但 Godot `Expression` 引擎的能力远不止于此——它还支持布尔运算、比较运算、三元运算符、字符串操作、三角函数、插值函数、随机函数等。本次讨论围绕如何利用这些未开发的能力，扩展 Bricks 系统的表达式功能。

**参考资料：**
- [Evaluating expressions - Godot Docs](https://docs.godotengine.org/en/stable/tutorials/scripting/evaluating_expressions.html)
- [Expression class - Godot Docs](https://docs.godotengine.org/en/stable/classes/class_expression.html)
- 现有实现：`addons/bricks/instructions/math/math_expression.gd`

---

## 提案总览

| # | 组件名 | 类型 | 优先级 | 状态 |
|:-:|--------|:----:|:------:|:----:|
| 1 | ExpressionCondition | Condition | P0 | 待实现 |
| 2 | StringExpression | Instruction | P1 | 待实现 |
| 3 | 增强 MathExpression | Instruction | P1 | 待实现 |
| 4 | NodePropertyExpression | Instruction | P2 | 记录，暂不实现 |
| 5 | FormulaPreset | Instruction | P3 | 记录，暂不实现 |
| 6 | ExpressionSwitch | Instruction | P3 | 记录，暂不实现 |

---

## 实现计划（#1 / #2 / #3）

### #1 ExpressionCondition — 通用布尔条件

**文件位置：** `addons/bricks/conditions/math/expression_condition.gd`
**分类：** `BRICKS_CATEGORY_MATH`（与 MathExpression 同类别）
**图标：** `Code`（与 MathExpression 共用图标）

**功能描述：**

用 Expression 表达式评估布尔值，替代大量专用条件组件。用户编写任意布尔表达式，系统解析并返回 true/false。

**表达式示例：**

```
# 变量比较
{local:health} > 50
{local:score} >= 1000

# 逻辑组合
{local:score} >= 1000 and {local:level} > 5
{local:is_alive} and {local:has_weapon} and not {local:is_stunned}

# 数值范围
{local:hp} >= 0 and {local:hp} <= {local:max_hp}

# 使用扩展 helper 函数
distance({local:position}, {local:target}) < 100
is_zero({local:velocity})
```

**实现要点：**

- 继承 `BaseCondition`，实现 `_evaluate_condition()` 返回 bool
- 复用 MathExpression 的变量替换逻辑（`{scope:var}` 正则替换模式）
- 扩展 `_ExprHelper`：添加 `distance(a, b)`, `is_zero(v)`, `is_nan(v)` 等辅助函数
- 支持 ScopeSource 配置（与 MathExpression 一致）
- 结果必须是 bool 类型，否则报错
- 静态分析：在编辑器验证表达式是否能解析

**关键接口：**

```gdscript
# 继承
extends BaseCondition
class_name ExpressionCondition

# 核心参数
var expression: String = ""              # 布尔表达式
var scope_source: ScopeSource = NEAREST   # 作用域来源
var custom_scope_id: String = ""         # 自定义作用域 ID
var target_node_path: NodePath           # 目标节点路径

# 核心方法
func _evaluate_condition(context: ExecutionContext) -> bool
```

---

### #2 StringExpression — 字符串表达式指令

**文件位置：** `addons/bricks/instructions/math/string_expression.gd`
**分类：** `BRICKS_CATEGORY_MATH`（或新建 `BRICKS_CATEGORY_STRING`）
**图标：** `Code`（或 `Text`）

**功能描述：**

用 Expression 表达式拼接和格式化字符串，填补 Bricks 系统字符串操作能力的空白。

**表达式示例：**

```
# 基础拼接
"Player " + str({local:player_id}) + " joined"

# 带条件的三元
{local:health} > 0 ? "HP: " + str({local:health}) : "DEAD"

# 复合格式
{local:name} + " Lv." + str({local:level}) + " [" + {local:class_name} + "]"

# 数值格式化（通过 helper）
format_num({local:score}, 0)     # 保留 0 位小数
format_num({local:damage}, 1)    # 保留 1 位小数
pad_left(str({local:gold}), 6, "0")  # 000123
```

**实现要点：**

- 继承 `BaseInstruction`，模式与 MathExpression 高度一致
- 输出类型固定为 `String`
- 复用变量替换逻辑
- `_ExprHelper` 扩展：`format_num(value, decimals)`, `pad_left(s, length, char)`, `pad_right(s, length, char)`, `upper(s)`, `lower(s)`, `substr(s, from, len)`
- 变量值在表达式中的处理：数值类型自动用 `str()` 包裹，字符串类型直接嵌入
- 保存到变量的逻辑与 MathExpression 一致

**关键接口：**

```gdscript
extends BaseInstruction
class_name StringExpression

# 核心参数
var expression: String = ""              # 字符串表达式
var save_to_variable: String = ""        # 保存到变量名
var save_to_scope: VariableScope = LOCAL # 保存到作用域
# ... scope source 相关参数同 MathExpression

func execute(context: ExecutionContext)
```

---

### #3 增强 MathExpression — 扩展游戏常用数学函数

**文件位置：** 修改 `addons/bricks/instructions/math/math_expression.gd`
**变更范围：** 仅修改 `_ExprHelper` 内部类，不改变外部接口

**新增辅助函数：**

| 函数 | 签名 | 用途 |
|------|------|------|
| `distance` | `distance(a, b)` | 两点距离（Vector2/Vector3 兼容） |
| `angle` | `angle(from, to)` | 两点之间角度（弧度） |
| `direction` | `direction(from, to)` | 归一化方向向量 |
| `remap` | `remap(value, istart, istop, ostart, ostop)` | 区间映射 |
| `inverse_lerp` | `inverse_lerp(from, to, weight)` | 逆向插值（返回 0-1） |
| `move_toward_val` | `move_toward_val(from, to, delta)` | 值趋近（避免与引擎内置冲突） |
| `snap` | `snap(value, step)` | 对齐到步长 |
| `deg2rad_val` | `deg2rad_val(degrees)` | 度转弧度（自定义版） |
| `rad2deg_val` | `rad2deg_val(radians)` | 弧度转度（自定义版） |

**实现要点：**

- 仅在 `_ExprHelper` 中添加新方法
- 向量函数同时支持 Vector2 和 Vector3
- 保持向后兼容：现有表达式不受影响
- 更新元数据 description 中列出所有可用函数

---

## 共享代码策略

三个组件共享以下代码模式，建议提取公共模块：

### 选项 A：提取 ExpressionBase 基类

```
addons/bricks/core/base/expression_base.gd  # 公共基类
├── VAR_PATTERN 常量
├── _replace_variables() 方法
├── _evaluate_expression() 方法
├── _get_variable_value() 方法
├── _escape_value_for_expression() 方法
├── scope_source 配置相关属性和方法
└── _ExprHelper 扩展（含所有游戏数学函数）
```

### 选项 B：提取 ExpressionHelper 工具类

```
addons/bricks/core/utils/expression_helper.gd  # 静态工具类
├── VAR_PATTERN 常量
├── static replace_variables(expr, context, scope_source, ...)
├── static evaluate(expr, helper_instance)
├── static escape_value(value)
└── class GameMathHelper extends RefCounted  # 共享 helper
    ├── vec2(), vec3(), normalize()
    ├── distance(), angle(), direction()
    ├── remap(), inverse_lerp(), snap()
    ├── format_num(), pad_left(), pad_right()
    └── upper(), lower(), substr()
```

**推荐选项 B** — 工具类方案更灵活，不需要改动继承结构。MathExpression 可逐步迁移到使用该工具类，ExpressionCondition 和 StringExpression 直接使用。

---

## 实现顺序

```
Phase 1: 共享基础设施
  ├── 创建 ExpressionHelper 工具类 + GameMathHelper
  └── 更新 MathExpression 使用共享代码（重构，不改变行为）

Phase 2: ExpressionCondition
  ├── 创建 expression_condition.gd
  ├── 添加本地化键
  └── 编写测试

Phase 3: StringExpression
  ├── 创建 string_expression.gd
  ├── 添加本地化键
  └── 编写测试
```

---

## 未来提案（记录）

以下想法已记录，优先级较低，可在后续迭代中评估：

### #4 NodePropertyExpression

通过 Expression 访问场景树节点属性。在 `_ExprHelper` 中暴露 `get_pos(path)`、`get_prop(path, prop)` 等方法。

**顾虑：** 节点操作安全性、编辑器中的路径验证复杂度较高。

### #5 FormulaPreset

带预设模板的公式指令（线性增长、衰减曲线、弹跳曲线等），降低非技术用户的使用门槛。

**顾虑：** 可用性待验证，需求不确定。

### #6 ExpressionSwitch

基于表达式结果的多分支指令，替代 if-else 嵌套。

**顾虑：** 现有 `if_then` / `if_else` 已能覆盖大部分场景，价值不够明确。
