# 表达式系统使用指南

Fuse 提供三个基于 Godot `Expression` 引擎的表达式组件，覆盖数学计算、字符串处理和条件判断。

## 组件概览

| 组件 | 类型 | 用途 | 输出 |
|------|------|------|------|
| MathExpression | 指令 | 数学计算 | Float / Int / Vector2 / Vector3 |
| StringExpression | 指令 | 字符串拼接与格式化 | String |
| ExpressionCondition | 条件 | 布尔表达式判断 | bool |

## 变量引用语法

三个组件共享相同的变量引用语法，支持三种作用域：

```
{local:变量名}     - 本地变量（ExecutionContext 上的变量）
{scope:变量名}     - 作用域变量（VariableScopeContainer 上的变量）
{global:变量名}    - 全局变量
```

变量名规则：以字母或下划线开头，只能包含字母、数字和下划线。

> 提示：参数只需要**引用**一个变量而不需要计算时，不必走表达式——指令参数的变量绑定双轨更直接，见[变量绑定使用指南](07-variable-binding-guide.md)。

```
# 合法
{local:hp}  {scope:player_name}  {global:max_count}  {local:_temp}

# 非法
{local:123}  {scope:player-name}  {global:player name}
```

未找到的变量在数学上下文中替换为 `0`，不会报错。

## Scope 来源配置

当表达式中使用 `{scope:xxx}` 时，需要指定从哪个作用域容器读取变量。通过 `scope_source` 属性选择：

| 值 | 说明 |
|----|------|
| Nearest | 最近的作用域容器（默认） |
| Custom ID | 指定 scope_id |
| Trigger Scope | Trigger 节点上的作用域 |
| Target Node | 目标节点路径上的作用域 |

选择 Custom ID 时需要填写 `custom_scope_id`，选择 Target Node 时需要填写 `target_node_path`。

---

## MathExpression

数学表达式指令，执行数学运算并将结果保存到变量。

**文件:** [math_expression.gd](../../../../instructions/math/math_expression.gd)
**分类:** Math
**图标:** Code

### 基础用法

```
表达式: {local:hp} + {local:heal_amount}
输出类型: Float
保存到变量: hp
保存到作用域: Local
```

### 输出类型

| 类型 | 说明 | 示例 |
|------|------|------|
| Float | 浮点数（默认） | 3.14 |
| Int | 整数（截断小数） | 42 |
| Vector2 | 2D 向量 | vec2(1, 2) |
| Vector3 | 3D 向量 | vec3(1, 2, 3) |

类型转换规则：
- Float → Int：直接截断（3.9 → 3）
- Vector3 → Vector2：取 x, y 分量
- 数值 → Vector2：转为 (值, 0)
- 数值 → Vector3：转为 (值, 0, 0)

### 运算符

```
# 算术
{local:a} + {local:b}        # 加
{local:a} - {local:b}        # 减
{local:a} * {local:b}        # 乘
{local:a} / {local:b}        # 除
{local:a} % {local:b}        # 取模

# 括号优先级
({local:a} + {local:b}) * {local:c}
```

### 可用函数

**Godot 内置：**

```
abs(-5)           # 绝对值 → 5.0
min(3, 7)         # 最小值 → 3.0
max(3, 7)         # 最大值 → 7.0
round(3.6)        # 四舍五入 → 4.0
floor(3.6)        # 向下取整 → 3.0
ceil(3.2)         # 向上取整 → 4.0
sqrt(16)          # 平方根 → 4.0
pow(2, 3)         # 幂运算 → 8.0
clamp(5, 0, 10)   # 范围限制 → 5.0
sin(0)            # 正弦（弧度）
cos(0)            # 余弦
tan(0)            # 正切
```

**游戏扩展函数：**

| 函数 | 说明 | 示例 |
|------|------|------|
| vec2(x, y) | 构造 2D 向量 | `vec2({local:x}, {local:y})` |
| vec3(x, y, z) | 构造 3D 向量 | `vec3(1, 2, 3)` |
| normalize(v) | 归一化 | `normalize({local:vel})` |
| distance(a, b) | 计算距离 | `distance(vec2(0,0), {local:pos})` |
| direction(a, b) | 计算方向 | `direction(vec2(0,0), {local:target})` |
| angle(a, b) | 计算角度（弧度） | `angle(vec2(0,0), {local:pos})` |
| remap(v, a, b, c, d) | 重新映射值域 | `remap({local:x}, 0, 100, 0, 1)` |
| inverse_lerp(a, b, v) | 反向插值 | `inverse_lerp(0, 10, {local:hp})` |
| snap(v, step) | 对齐到步长 | `snap({local:x}, 0.5)` |
| move_toward_val(from, to, delta) | 向目标移动 | `move_toward_val({local:val}, 100, 5)` |
| is_zero(v) | 是否接近零 | `is_zero({local:velocity})` |
| format_num(v, d) | 格式化数字为字符串 | `format_num(3.14159, 2)` → "3.14" |
| pad_left(s, len, c) | 左填充 | `pad_left("42", 6, "0")` → "000042" |
| pad_right(s, len, c) | 右填充 | `pad_right("hi", 5, "!")` → "hi!!!" |

> `move_toward_val` 使用 `_val` 后缀是因为 Godot Expression 内置了 `move_toward` 函数。效果相同但支持自动类型转换。

### 实际示例

```
# 伤害计算
表达式: ({local:attack} - {local:defense}) * {local:multiplier}
输出类型: Float
保存到变量: damage

# 将 HP 映射到 0~1 范围
表达式: remap({local:hp}, 0, {local:max_hp}, 0, 1)
输出类型: Float
保存到变量: hp_ratio

# 计算玩家到目标的方向向量
表达式: direction(vec2(0, 0), vec2({local:tx}, {local:ty}))
输出类型: Vector2
保存到变量: move_dir
```

### 变量类型在数学上下文中的处理

MathExpression 使用数值模式处理变量引用：
- 数值变量：直接使用（`42` → `42`）
- 向量变量：转为构造调用（`Vector2(1,2)` → `vec2(1, 2)`）
- bool 变量：转为浮点数（`true` → `1`，`false` → `0`）
- 字符串变量：尝试转为浮点数（`"42"` → `42.0`，`"hello"` → `0.0`）

---

## StringExpression

字符串表达式指令，用表达式拼接和格式化字符串。

**文件:** [string_expression.gd](../../../../instructions/math/string_expression.gd)
**分类:** Math
**图标:** Code

### 基础用法

```
表达式: "Hello" + " " + "World"
保存到变量: greeting
保存到作用域: Local
```

### 字符串拼接

```
# 基础拼接
"Score: " + str({local:score})

# 多段拼接
"Player " + str({local:id}) + " - HP: " + str({local:hp}) + "/" + str({local:max_hp})
```

### 变量插值

StringExpression 使用字符串模式处理变量引用：
- 字符串变量：保留为字符串字面量（`"hello"` → `"hello"`）
- 数值变量：保留数值形式（`42` → `42`，需要 `str()` 转换）
- bool 变量：转为 true/false（`true` → `true`）
- 向量变量：转为构造调用（`Vector2(1,2)` → `vec2(1, 2)`）

```
# 数值变量需要用 str() 转换
"HP: " + str({local:hp})

# 字符串变量直接使用
{local:player_name} + " joined the game"

# bool 变量
"is alive: " + str({local:hp} > 0)
```

### 三元运算

```
# 条件文本
{local:hp} > 0 ? "Alive" : "Dead"

# 分级显示
{local:score} > 90 ? "S" : ({local:score} > 70 ? "A" : "B")
```

### 格式化函数

```
# 保留 2 位小数
format_num({local:hp}, 2)
# hp=3.14159 → "3.14"

# 数字补零
pad_left(str({local:level}), 3, "0")
# level=5 → "005"

# 右对齐
pad_right({local:item_name}, 20, ".")
# item_name="剑" → "剑................"
```

### 实际示例

```
# 构建伤害飘字
表达式: "-" + str({local:damage}) + " HP"
保存到变量: damage_text

# 构建进度条
表达式: "[" + pad_left("", {local:percent}, "#") + pad_left("", 100 - {local:percent}, "-") + "] " + str({local:percent}) + "%"
保存到变量: progress_bar

# 构建状态信息
表达式: {local:name} + " | HP: " + str({local:hp}) + "/" + str({local:max_hp}) + " | " + ({local:alive} ? "ALIVE" : "DEAD")
保存到变量: status_text
```

### 非字符串结果自动转换

如果表达式返回非字符串结果（如数值），会自动调用 `str()` 转换：

```
表达式: {local:a} + {local:b}
# a=10, b=20 → 保存为字符串 "30"
```

---

## ExpressionCondition

表达式条件，用布尔表达式进行条件判断。

**文件:** [expression_condition.gd](../../../../conditions/math/expression_condition.gd)
**分类:** Math
**图标:** Code

### 基础用法

```
表达式: {local:hp} > 0
```

当表达式计算结果为 `true` 时条件通过，`false` 时不通过。结果不是布尔值（如数值或字符串）会导致错误并返回 false。

### 比较运算符

```
{local:hp} > 0           # 大于
{local:hp} >= 100        # 大于等于
{local:hp} < 0           # 小于
{local:hp} <= 100        # 小于等于
{local:level} == 10      # 等于
{local:state} != "dead"  # 不等于
```

### 逻辑运算符

```
# AND
{local:hp} > 0 and {local:alive}

# OR
{local:has_key} or {local:has_pickaxe}

# NOT
not {local:is_cooling_down}

# 组合
{local:hp} > 0 and {local:mp} > 10 and not {local:stunned}
```

### 三元运算

表达式引擎支持 Godot 的三元语法 `a if b else c`：

```
# 返回布尔值
1 if {local:hp} > 0 else 0

# 嵌套
1 if {local:hp} > 50 else (1 if {local:hp} > 0 else 0)
```

### 辅助函数

```
# 距离判断
distance(vec2(0, 0), vec2({local:px}, {local:py})) < {local:range}

# 接近零判断
is_zero({local:velocity})

# 范围检查
{local:hp} >= {local:min_hp} and {local:hp} <= {local:max_hp}
```

### 实际示例

```
# 死亡检测
表达式: {local:hp} <= 0

# 技能冷却完毕
表达式: {local:cooldown_timer} <= 0

# 敌人在攻击范围内
表达式: distance(vec2({local:px}, {local:py}), vec2({local:tx}, {local:ty})) < {local:attack_range}

# 可以释放技能
表达式: {local:mp} >= {local:skill_cost} and not {local:silenced} and {local:cooldown} <= 0

# 物品栏已满
表达式: {local:item_count} >= {local:max_slots}
```

### 结果类型要求

表达式**必须**返回布尔值（`true` / `false`）。以下写法会报错：

```
# 错误：返回数值
{local:hp} + {local:mp}       # 返回 float

# 正确：返回布尔
{local:hp} + {local:mp} > 0   # 返回 bool
```

---

## 作用域输出配置

MathExpression 和 StringExpression 支持将结果保存到不同作用域：

| 保存到作用域 | 说明 |
|-------------|------|
| Local | 保存到 ExecutionContext（默认） |
| Scope | 保存到作用域容器 |
| Global | 保存到全局变量 |

选择 Scope 时，会出现额外的 `save_scope_source` 配置，用法与读取的 `scope_source` 相同。

---

## 常见问题

### 表达式中的字符串需要用引号

```
# StringExpression 中
"Hello" + " " + "World"    # 正确
Hello + " " + World        # 错误：Hello 和 World 会被当作变量名

# ExpressionCondition 中
{local:state} == "idle"    # 正确
{local:state} == idle      # 错误：idle 会被当作变量名
```

### move_toward_val vs move_toward

`move_toward_val` 是游戏扩展函数，支持自动类型转换（参数会强制转 float）。`move_toward` 是 Godot Expression 内置函数。两者功能相同，推荐使用 `move_toward_val` 以获得更好的类型兼容性。

### 变量未找到不会中断执行

如果引用的变量不存在，在数学上下文中会替换为 `0` 继续执行（并输出警告日志）。如果你想确保变量存在，请搭配 SetVariable 指令或 CreateVariable 指令先初始化变量。

### 除以零

Godot Expression 中除以零会返回 `inf` 或 `nan`，不会报错。建议使用 `clamp` 或条件判断来避免：

```
# 安全除法
{local:b} != 0 ? {local:a} / {local:b} : 0
```
