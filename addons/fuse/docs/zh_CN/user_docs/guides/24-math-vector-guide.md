> 🌐 中文 | [**English**](../../../en_US/user_docs/guides/24-math-vector-guide.md)

# 数学/向量指令使用指南

Fuse 数学/向量系统提供 6 个数值计算指令，覆盖基础四则运算、线性插值、范围限制、向量运算、随机数生成和随机点生成。表达式类指令（MathExpression、StringExpression）请参阅 [表达式系统使用指南](05-expression-guide.md)。

## 指令列表

| 名称 | 功能描述 | 关键参数 |
|------|----------|----------|
| **MathOperation** | 基础四则运算 | `operation_type`（运算类型）、`operand_a`/`operand_b`（操作数，支持直接值或变量）、`save_to_variable`（结果变量） |
| **Lerp** | 线性插值 | `from`/`to`（插值端点，支持直接值或变量）、`weight`（插值权重 0.0-1.0）、`save_to_variable` |
| **ClampValue** | 值范围限制 | `value`（输入值，支持直接值或变量）、`min_value`/`max_value`（范围）、`save_to_variable` |
| **VectorOperation** | 向量运算 | `operation_type`（运算类型）、`vector_type`（VECTOR2/VECTOR3）、`operand_a`/`operand_b`（操作数）、`save_to_variable` |
| **RandomNumber** | 生成随机数 | `min_value`/`max_value`（范围）、`is_integer`（是否为整数）、`save_to_variable` |
| **GetRandomPointInRange** | 在范围内获取随机点 | `dimension_mode`（2D/3D）、`origin`（起点）、`range`（范围半径）、`plane_3d`（3D 平面类型）、`save_to_variable` |

---

## MathOperation

执行基础数学运算，支持从直接值或变量读取操作数。

**分类:** Math | **图标:** Variant

### 运算类型

| 运算 | 说明 | 示例 |
|------|------|------|
| ADD | 加法 | 10 + 5 = 15 |
| SUBTRACT | 减法 | 10 - 5 = 5 |
| MULTIPLY | 乘法 | 10 * 5 = 50 |
| DIVIDE | 除法 | 10 / 5 = 2 |
| MODULO | 取模 | 10 % 3 = 1 |

### 操作数来源

两个操作数都支持两种来源模式：

| 模式 | 说明 |
|------|------|
| VALUE | 直接输入数值 |
| VARIABLE | 从变量读取（支持 Local/Scope/Global 三种作用域） |

### 使用示例

```
# 伤害计算：攻击力 - 防御力
MathOperation → SUBTRACT
  operand_a: VALUE (20)
  operand_b: VARIABLE (defense, Local)
  save_to: damage (Local)

# 经验值翻倍
MathOperation → MULTIPLY
  operand_a: VARIABLE (exp, Local)
  operand_b: VALUE (2)
  save_to: new_exp (Local)
```

---

## Lerp

在两个值之间进行线性插值。

**分类:** Math | **图标:** Variant

### 参数说明

| 参数 | 说明 |
|------|------|
| `from` | 起始值（支持 VALUE 或 VARIABLE） |
| `to` | 目标值（支持 VALUE 或 VARIABLE） |
| `weight` | 插值权重（0.0 = 起始值，1.0 = 目标值） |

### 计算公式

```
result = from + (to - from) * weight
```

### 使用示例

```
# 平滑生命值显示（从当前显示值过渡到实际值）
Lerp → from: VARIABLE (display_hp), to: VARIABLE (actual_hp), weight: 0.1
  save_to: display_hp (Local)

# 颜色插值
Lerp → from: 0.0, to: 1.0, weight: VARIABLE (progress)
  save_to: alpha (Local)
```

---

## ClampValue

将值限制在指定范围内。

**分类:** Math | **图标:** Variant

### 参数说明

| 参数 | 说明 |
|------|------|
| `value` | 输入值（支持 VALUE 或 VARIABLE） |
| `min_value` | 最小值 |
| `max_value` | 最大值 |

### 计算公式

```
result = min(max(value, min_value), max_value)
```

### 使用示例

```
# 限制生命值不超过上限
ClampValue → value: VARIABLE (hp), min_value: 0, max_value: 100
  save_to: hp (Local)

# 限制音量在 0-1 之间
ClampValue → value: VARIABLE (volume_input), min_value: 0.0, max_value: 1.0
  save_to: volume (Local)
```

---

## VectorOperation

执行向量数学运算，支持 Vector2 和 Vector3。

**分类:** Math | **图标:** Vector3

### 运算类型

| 运算 | 操作数 | 说明 | 结果类型 |
|------|--------|------|----------|
| VECTOR_ADD | A + B | 向量加法 | 向量 |
| VECTOR_SUBTRACT | A - B | 向量减法 | 向量 |
| SCALE | A * scalar | 向量缩放（B 为标量） | 向量 |
| NORMALIZE | normalize(A) | 归一化 | 向量 |
| LENGTH | length(A) | 向量长度 | Float |
| DISTANCE | distance(A, B) | 两点距离 | Float |

### 向量类型

| 类型 | 说明 | 适用场景 |
|------|------|----------|
| VECTOR2 | 2D 向量 (x, y) | 2D 游戏 |
| VECTOR3 | 3D 向量 (x, y, z) | 3D 游戏 |

操作数同样支持 VALUE（直接输入）和 VARIABLE（从变量读取）两种模式。

### 使用示例

```
# 计算敌人方向
VectorOperation → VECTOR_SUBTRACT (Vector2)
  operand_a: VARIABLE (enemy_pos)
  operand_b: VARIABLE (player_pos)
  save_to: direction (Local)

# 获取移动方向（归一化）
VectorOperation → NORMALIZE (Vector2)
  operand_a: VARIABLE (move_input)
  save_to: move_dir (Local)

# 计算到目标的距离
VectorOperation → DISTANCE (Vector2)
  operand_a: VARIABLE (player_pos)
  operand_b: VARIABLE (target_pos)
  save_to: distance (Local)

# 移动速度缩放
VectorOperation → SCALE (Vector2)
  operand_a: VARIABLE (direction)
  operand_b: VALUE (5.0)
  save_to: velocity (Local)
```

---

## RandomNumber

在指定范围内生成随机数。

**分类:** Math | **图标:** Variant

### 参数说明

| 参数 | 说明 |
|------|------|
| `min_value` | 最小值 |
| `max_value` | 最大值 |
| `is_integer` | 是否返回整数 |
| `save_to_variable` | 结果变量名 |
| `save_to_scope` | 保存作用域（Local/Scope/Global） |

### 使用示例

```
# 生成 1-6 的随机整数（骰子）
RandomNumber → [1, 6], is_integer: true
  save_to: dice_roll (Local)

# 生成 0.0-1.0 的随机浮点数
RandomNumber → [0.0, 1.0], is_integer: false
  save_to: random_factor (Local)

# 随机暴击伤害倍率
RandomNumber → [1.5, 3.0], is_integer: false
  save_to: crit_multiplier (Local)
```

---

## GetRandomPointInRange

从指定起点范围内的随机位置，支持 2D 和 3D。

**分类:** Math | **图标:** Vector3i

### 参数说明

| 参数 | 说明 |
|------|------|
| `dimension_mode` | 2D 或 3D |
| `plane_3d` | 3D 平面类型（仅 3D 模式） |
| `origin_mode` | 起点来源（Direct 直接设置 / Variable 从变量） |
| `origin` | 起点坐标 |
| `range_mode` | 范围来源（Direct 直接设置 / Variable 从变量） |
| `range` | 各轴范围（实际范围为 -range 到 +range） |
| `save_to_variable` | 结果变量名 |

### 3D 平面类型

| 平面 | 说明 | 不变轴 |
|------|------|--------|
| XY | 水平面 | Z |
| XZ | 地面 | Y |
| YZ | 侧面 | X |
| Full 3D | 完整 3D 空间 | 无 |

### 使用示例

```
# 在玩家周围 200 像素内生成随机位置（2D）
GetRandomPointInRange → 2D
  origin: Direct (player_position)
  range: Direct (200, 200)
  save_to: spawn_pos (Local)

# 在地面随机位置生成敌人（3D）
GetRandomPointInRange → 3D [XZ]
  origin: Direct (0, 10, 0)
  range: Direct (500, 0, 500)
  save_to: enemy_spawn_pos (Local)

# 从变量获取随机范围
GetRandomPointInRange → 2D
  origin: Variable (center_pos, Local)
  range: Variable (spawn_radius, Local)
  save_to: drop_pos (Local)
```

---

## 作用域说明

所有数学指令的结果保存都支持三种作用域：

| 作用域 | 说明 |
|--------|------|
| **Local** | ExecutionContext 上的局部变量，当前指令链内有效 |
| **Scope** | VariableScopeContainer 上的作用域变量，跨节点共享 |
| **Global** | 全局变量，整个游戏运行时有效 |

选择 Scope 时，需要额外配置 `scope_source` 指定从哪个作用域容器读写：

| ScopeSource | 说明 |
|-------------|------|
| Nearest | 最近的作用域容器（默认） |
| Custom ID | 指定 scope_id |
| Trigger Scope | Trigger 节点上的作用域 |
| Target Node | 目标节点路径上的作用域 |

---

## 常见用例

### 1. 伤害计算

```
# 计算最终伤害 = (攻击力 - 防御力) * 暴击倍率
MathOperation → SUBTRACT
  operand_a: VALUE (attack), operand_b: VARIABLE (defense)
  save_to: base_damage

# 随机暴击判定
RandomNumber → [0.0, 1.0], is_integer: false
  save_to: crit_roll

# 暴击倍率选择（使用 MathExpression）
MathExpression → {local:crit_roll} < {local:crit_chance} ? 2.0 : 1.0
  save_to: multiplier

# 最终伤害
MathOperation → MULTIPLY
  operand_a: VARIABLE (base_damage), operand_b: VARIABLE (multiplier)
  save_to: final_damage

# 限制最低伤害为 1
ClampValue → value: VARIABLE (final_damage), min: 1, max: 9999
  save_to: final_damage
```

### 2. 随机掉落位置

```
# 在击杀位置附近随机掉落物品
GetRandomPointInRange → 2D
  origin_mode: Variable
  origin: kill_position (Local)
  range_mode: Direct
  range: (30, 30)
  save_to: drop_position (Local)

# 实例化掉落物到随机位置
AddSceneAsChild → scene: "res://scenes/item_drop.tscn"
  parent: ItemContainer
```

### 3. 平滑相机跟随

```
# 每帧插值相机位置到目标
Lerp → from: VARIABLE (camera_pos), to: VARIABLE (target_pos), weight: 0.1
  save_to: camera_pos

SetPosition → target: Camera, position: VARIABLE (camera_pos)
```

### 4. 计算敌人与玩家的距离

```
# 获取敌人位置
GetPosition → target: Enemy
  save_to: enemy_pos (Local)

# 获取玩家位置
GetPosition → target: Player
  save_to: player_pos (Local)

# 计算距离
VectorOperation → DISTANCE (Vector2)
  operand_a: VARIABLE (enemy_pos)
  operand_b: VARIABLE (player_pos)
  save_to: distance (Local)

# 判断是否在攻击范围内
ClampValue → value: VARIABLE (distance), min: 0, max: 100
  # 如果 distance > 100，则 clamp 为 100，可以用 Clamp 判断范围
```

---

## 注意事项

- **除以零**: MathOperation 的 DIVIDE 运算在除数为 0 时会报错，建议使用 ClampValue 确保除数不为 0，或使用 MathExpression 的三元运算 `{local:b} != 0 ? {local:a} / {local:b} : 0`
- **类型匹配**: VectorOperation 的两个操作数类型必须一致（都是 Vector2 或都是 Vector3），且向量类型参数要匹配实际数据
- **变量存在性**: 从变量读取操作数时，确保变量已初始化。未找到变量时会产生运行时错误
- **随机数种子**: RandomNumber 和 GetRandomPointInRange 使用 Godot 的全局随机数生成器，游戏启动时自动随机化
- **表达式替代**: 如果需要复杂运算（嵌套公式、多变量），优先使用 MathExpression 而不是串联多个 MathOperation

---

**相关文档:**
- [表达式系统使用指南](05-expression-guide.md) - MathExpression、StringExpression、ExpressionCondition
- [变换系统使用指南](10-transform-guide.md) - SetPosition、MoveBy、LookAt 等节点变换指令
