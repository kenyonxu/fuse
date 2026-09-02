> 🌐 中文 | [**English**](../../../en_US/user_docs/Introductions/04-expression-system.md)

# 《不写一行代码算伤害公式：Fuse 表达式系统实战》

看完这篇，你会拿到 Fuse 里最"像写代码"却全程不碰代码的一块——表达式引擎。一个 RPG 的伤害结算 `(攻击-防御)*暴击倍率`、一段飘字 `"-15 HP"`、一条 ASCII 进度条 `[####----] 45%`、一个 `score > 90 ? "S" : "A"` 的评级判断，在传统可视化工具里要么得拆成一长串"加法节点→减法节点→乘法节点→条件节点"的流水线，要么干脆写不出来、只能退回 `.gd` 文件。Fuse 用 **MathExpression / StringExpression / ExpressionCondition 三件套**加一套统一的 `{local:hp}` 变量引用语法，把这件事一次性解决。这一块正是它和同类可视化工具拉开身位的核心护城河，这篇我会加重笔墨讲透。

承接上一篇：我们刚把 LOCAL / SCOPE / GLOBAL 三层变量讲完。变量解决了"数据存哪儿"，但变量本身只是仓库，真正让数据动起来、算出伤害、拼出文本、做出判断的，是计算——而计算的终极形态就是表达式。

## 一、为什么"表达式"是可视化系统的试金石

先说一个很多人才踩过坑才意识到的痛点。可视化编程工具里，赋值、移动、播动画这些"动作"都好做，但只要碰到一条略带数学味的逻辑，体验就急转直下。

举个真实场景：你要算最终伤害，公式是 `(attack - defense) * crit_multiplier`，其中暴击倍率还要先掷一次随机数判定。在纯节点式的工具里，这意味着你要拖三个运算节点、连线、再拖一个随机数节点、一个比较节点、一个选择节点……光是为了算一个伤害，屏幕上就爬满了十几个节点。更麻烦的是字符串：想把伤害拼成 `"-15 HP"` 显示到飘字上，又得拖一串"字符串拼接"节点。逻辑一旦稍微复杂，可视化的图就糊成一团，反而比读代码还累。

Fuse 的解法很直接：**把一个完整的数学表达式塞进一个组件里**。你只要在 Inspector 里填一行 `(attack - defense) * crit_multiplier`，它背后调的是 Godot 引擎自带的 `Expression` 计算引擎，所以你写的语法、能用的函数，和你在 GDScript 里写的几乎一模一样——区别只在于，这一行不用写进 `.gd`、不用编译、改完立刻生效。

这不是一个"勉强能用"的计算器，而是 Fuse 三件套里我觉得设计得最干净、也最值得单独成篇强调的一块。它有三个真正构成护城河的特性，我先讲完用法，最后单独拎出来加重讲。

## 二、三件套：一个公式、一段文本、一个判断

Fuse 的表达式系统一共三个组件，分工极其清晰：

| 组件 | 类型 | 干什么 | 输出 |
|------|------|--------|------|
| **MathExpression**（数学表达式） | 指令 | 算一个数学公式 | Float / Int / Vector2 / Vector3 |
| **StringExpression**（字符串表达式） | 指令 | 拼接和格式化一段文本 | String |
| **ExpressionCondition**（表达式条件） | 条件 | 算一个布尔判断 | bool |

注意它们的归属：前两个是指令（Instruction，回答"做什么"），后一个是条件（Condition，回答"满足什么才做"）。三者背后跑的是同一套表达式引擎，所以**变量引用语法完全一致**——这是第一个护城河特性，先记着，待会展开。

它们都长在 Inspector 的 Math 分类下，图标是一个 `Code` 符号。找到 MathExpression 加进指令列表，你会看到一个 `表达式` 文本框、一个 `输出类型` 下拉、一个 `保存到变量` 和 `保存到作用域` 的输出配置。StringExpression 和 ExpressionCondition 的面板类似。

## 三、统一变量引用语法：三件套共用一把钥匙

这是整篇最该记住的东西。三个组件引用变量的语法是同一套花括号标记：

```
{local:hp}        # 本地变量（ExecutionContext 上的）
{scope:name}      # 作用域变量（VariableScopeContainer 上的）
{global:max_hp}   # 全局变量
```

变量名规则很常规：字母或下划线开头，只能含字母、数字、下划线。`{local:hp}`、`{scope:player_name}`、`{global:max_count}` 都合法；`{local:123}`、`{scope:player-name}`（带连字符）、`{global:player name}`（带空格）都不行。

为什么说"统一"是护城河？因为这意味着你写伤害公式时引用的 `{local:attack}`，和你在 StringExpression 里拼飘字时引用的 `{local:attack}`，是同一个变量、同一种写法。你不用在"数学节点"和"文本节点"之间学两套变量寻址方式，也不用担心数据类型对不上。

当表达式中出现 `{scope:xxx}` 时，还需要告诉它从哪个作用域容器取值。Fuse 提供四种 `scope_source`：

| 来源 | 说明 |
|------|------|
| Nearest | 最近的作用域容器（默认） |
| Custom ID | 指定一个 scope_id |
| Trigger Scope | Trigger 节点身上的作用域 |
| Target Node | 目标节点路径上的作用域 |

这一步看着多余，其实是 Fuse 作用域模型严谨性的体现——作用域变量可以挂在很多个容器上，引擎需要知道你指哪一个。

## 四、MathExpression：把伤害公式塞进一行

MathExpression 负责算数学，算完把结果存到指定作用域的变量里。

它的算术运算符和函数，跟 GDScript 几乎一致。算术有 `+ - * / %` 和括号，函数直接能用 Godot 内置的那一批：

```
abs(-5)          # 绝对值 → 5.0
min(3, 7)        # 最小值 → 3.0
max(3, 7)        # 最大值 → 7.0
round(3.6)       # 四舍五入 → 4.0
floor(3.6)       # 向下取整 → 3.0
ceil(3.2)        # 向上取整 → 4.0
sqrt(16)         # 平方根 → 4.0
pow(2, 3)        # 幂运算 → 8.0
clamp(5, 0, 10)  # 限幅 → 5.0
sin(0)           # 正弦（弧度）
```

**实战例 1：伤害计算。** 这是公式 `(攻击 - 防御) * 倍率` 的完整表达：

```
表达式:    ({local:attack} - {local:defense}) * {local:multiplier}
输出类型:  Float
保存到:    damage（Local）
```

就这一行。如果 `attack=20, defense=5, multiplier=2`，结果 `damage=30.0`。你不用拖三个运算节点，不用画三条连线。

**实战例 2：HP 归一化。** 血条要做百分比，需要把 `hp` 从 `0~max_hp` 映射到 `0~1`：

```
表达式:    remap({local:hp}, 0, {local:max_hp}, 0, 1)
输出类型:  Float
保存到:    hp_ratio（Local）
```

注意这里用了 `remap`。这不是 Godot 内置函数，而是 Fuse 给表达式引擎额外注入的**游戏扩展函数**。这是第二个护城河特性，下面单独讲。除它之外，常用的扩展函数还有：

| 函数 | 作用 | 例子 |
|------|------|------|
| `vec2(x, y)` / `vec3(x,y,z)` | 构造向量 | `vec2({local:x}, {local:y})` |
| `normalize(v)` | 归一化 | `normalize({local:vel})` |
| `distance(a, b)` | 两点距离 | `distance(vec2(0,0), {local:pos})` |
| `direction(a, b)` | 方向向量 | `direction(vec2(0,0), {local:target})` |
| `remap(v, a, b, c, d)` | 重映射值域 | `remap({local:hp}, 0, 100, 0, 1)` |
| `inverse_lerp(a, b, v)` | 反向插值 | `inverse_lerp(0, 10, {local:hp})` |
| `snap(v, step)` | 对齐到步长 | `snap({local:x}, 0.5)` |
| `format_num(v, d)` | 数字格式化 | `format_num(3.14159, 2)` → `"3.14"` |
| `pad_left(s, len, c)` | 左填充 | `pad_left("42", 6, "0")` → `"000042"` |

MathExpression 还支持四种输出类型：Float（默认）、Int（截断小数）、Vector2、Vector3。向量类型可以写 `vec2(1, 2)` 这种构造，配合 `direction()` 算移动方向：

```
表达式:    direction(vec2(0, 0), vec2({local:tx}, {local:ty}))
输出类型:  Vector2
保存到:    move_dir（Local）
```

## 五、StringExpression：飘字、进度条、补零，都是拼接

StringExpression 专管文本，输出一定是 String。它的核心能力是"变量插值 + 拼接 + 格式化函数"。

**实战例 3：伤害飘字。** 受击后要在头顶飘出 `-15 HP` 这种字：

```
表达式:    "-" + str({local:damage}) + " HP"
保存到:    damage_text（Local）
```

这里有个坑要记住：StringExpression 里数值变量**不能直接和字符串相加**，必须套一层 `str()` 转换。`str({local:damage})` 把数字转成文本，然后再拼。字符串变量（如玩家名）可以直接用：`{local:player_name} + " joined"`。

**实战例 4：进度条文本。** 想在控制台或纯文本 Label 上画一条 `[####------] 40%` 的进度条，可以用 `pad_left`：

```
表达式:    "[" + pad_left("", {local:percent}, "#") + pad_left("", 100 - {local:percent}, "-") + "] " + str({local:percent}) + "%"
保存到:    progress_bar（Local）
```

`percent=40` 时，结果是 `[####------+...] 40%`。`pad_left("", n, "#")` 的意思是"在空字符串左侧填字符，直到长度为 n"——这里巧妙地用来生成 n 个井号。这种写法在纯代码里都得绕两下，在 Fuse 里一行搞定。

**实战例 5：等级补零。** 显示等级时想要 `Lv.005` 这种补零格式：

```
表达式:    "Lv." + pad_left(str({local:level}), 3, "0")
保存到:    level_text（Local）
```

`level=5` → `"Lv.005"`，`level=42` → `"Lv.042"`。补零、补位、右对齐，全是 `pad_left` / `pad_right` 一族。

StringExpression 还支持三元运算，这就引出第三个实战方向——条件文本。

## 六、ExpressionCondition：把判断也写成一行

ExpressionCondition 是条件，输出必须是布尔值。它的运算符就是比较（`> >= < <= == !=`）和逻辑（`and or not`），组合起来能写相当复杂的判断。

**实战例 6：分数分级。** 这是文章开头提过的那个例子，用嵌套三元运算做 S/A/B 评级。不过要注意：在 ExpressionCondition 里，三元运算要写成 Godot 风格的 `a if cond else b`。如果你只是想生成"评级文本"，更适合放在 StringExpression 里用 C 风格三元：

```
# 在 StringExpression 里（生成文本）
表达式:    {local:score} > 90 ? "S" : ({local:score} > 70 ? "A" : "B")
```

`score=85` → `"A"`，`score=95` → `"S"`，`score=50` → `"B"`。一个表达式搞定三档分级，不用三个 IfElse 嵌套。

如果你要的是"判断是否满足"，就用 ExpressionCondition：

```
# 在 ExpressionCondition 里（判断布尔）
表达式:    {local:mp} >= {local:skill_cost} and not {local:silenced} and {local:cooldown} <= 0
```

这一行表达了"蓝量够、没被沉默、冷却好了"才能放技能的复合判断。写法和 GDScript 的 `if` 条件一模一样。结果不是布尔的表达式（比如 `{local:hp} + {local:mp}`）会报错并返回 false，所以务必带比较运算符。

## 七、一个能直接跑的小案例：完整的伤害结算链

把前面几块串起来，做一个能在场景里跑通的伤害结算。场景里有一个敌人节点，身上挂一个 Trigger，事件用 OnHealthChanged 或者受击信号触发。指令序列如下：

1. **RandomNumber**（随机数）——掷暴击：范围 `[0.0, 1.0]`，存到 `crit_roll`。
2. **MathExpression**——定暴击倍率：`{local:crit_roll} < {local:crit_chance} ? 2.0 : 1.0`，存到 `multiplier`。
3. **MathExpression**——算最终伤害：`({local:attack} - {local:defense}) * {local:multiplier}`，存到 `damage`。
4. **ClampValue**——保底伤害：把 `damage` 限制在 `[1, 9999]`。
5. **MathExpression**——扣血：`{local:hp} - {local:damage}`，存回 `hp`。
6. **StringExpression**——拼飘字：`"-" + str({local:damage}) + " HP"`，存到 `damage_text`。
7. **SetUIText**——把 `damage_text` 显示到头顶的 Label 上。

运行场景，触发受击，飘字就跳出 `-15 HP`，且暴击时是 `-30 HP`。整个过程没有打开 `.gd` 文件，没有拖节点连线。这就是表达式三件套的威力：七条指令里，有四条的核心逻辑都是一行表达式。

## 八、护城河加重：三个让 Fuse 表达式与众不同的设计

这一篇是护城河篇，前面分散提过几个特性，这里统一拎出来加重，因为它们才是 Fuse 表达式系统真正甩开同类工具的地方。

**护城河特性一：统一变量引用语法。** 前面说过，三件套共用 `{local:hp}` `{scope:name}` `{global:max}` 这一套标记。这意味着你学一次语法，就能在数学计算、文本拼接、条件判断三处通用。很多可视化工具的"数学节点"和"字符串节点"变量寻址方式不同，数据在节点之间流转还要靠额外的连线——Fuse 里你只要写花括号，引擎自己从三层作用域里取值。这是设计一致性带来的复利。

**护城河特性二：游戏扩展函数库。** Godot 的 `Expression` 引擎本身只暴露基础数学函数。Fuse 在引擎之上又注入了一批专为游戏场景设计的函数：`vec2` / `vec3` 构造向量、`normalize` 归一化、`distance` / `direction` 算距离和方向、`remap` / `inverse_lerp` 做值域映射、`snap` 对齐步长、`format_num` / `pad_left` / `pad_right` 做格式化。这些函数在纯 Godot Expression 里都写不出来，必须回到代码里手搓。Fuse 把它们直接铺进了表达式沙盒，所以你才能在 Inspector 里一行写完 HP 归一化、伤害飘字、等级补零。

**护城河特性三：安全降级，不会因为一个变量没找到就崩。** 这是个容易被低估但实战极重要的特性。如果表达式里引用了 `{local:hp}`，而当时 `hp` 这个变量还没被创建，引擎**不会抛异常中断整条指令链**，而是在数学上下文里把它替换成 `0`，继续算下去，只在日志里打一条警告。这意味着你不会因为初始化顺序的时序问题让整个伤害结算崩溃。字符串上下文里则是替换成空字符串，布尔上下文里是 false。当然，如果你确实想确保变量存在，可以搭配 `SetVariable` 或 `CreateVariable` 先初始化——但默认的安全降级，让你在快速搭原型时不至于被 null 搞崩溃。

这三个特性叠在一起，让 Fuse 的表达式不只是"能算加减乘除"，而是"能在可视化环境里写真正的游戏逻辑公式"。

## 九、几点容易踩的坑

写表达式时，有几个细节记一下能少走弯路：

字符串字面量必须带引号。`{local:state} == "idle"` 是对的，`{local:state} == idle` 会把 `idle` 当成变量名去找，结果恒为不等于。字符串拼接里 `"Hello" + " " + "World"` 要引号，`Hello + World` 不行。

除以零不会崩，但会得到 `inf` 或 `nan`。想避免就套个三元：`{local:b} != 0 ? {local:a} / {local:b} : 0`。

`move_toward_val` 而不是 `move_toward`。因为 Godot Expression 内置已经占了 `move_toward` 这个名字，Fuse 的扩展版本加了 `_val` 后缀以避让，功能相同但支持自动类型转换。

结果保存可以选 Local / Scope / Global 三种作用域，选 Scope 时会多出一个 `save_scope_source`，用法和读取时一样。

## 十、下一篇：让逻辑会分支和循环

表达式解决了"怎么算"，但真实游戏逻辑不止是算式——它还有"如果血量低于 30% 就逃跑""每个波次生成 5 个敌人""遍历所有敌人检查是否全灭"。这些是流程控制的活儿，需要 If、循环、数组、字典。

**下一篇，我会讲透 Fuse 的流程控制和数据结构：IfElse / ForLoop / WhileLoop 怎么搭分支和循环，数组 18 个操作、字典 16 个操作怎么管理集合数据，以及为什么"可视化照样能写出真实逻辑"。** 到那一步，Fuse 的逻辑骨架就彻底完整了。
