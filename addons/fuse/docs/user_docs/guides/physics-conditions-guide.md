# Physics 条件指南

## 概述

Physics 条件用于判断 `CharacterBody` 的物理状态——在地面/墙壁/空中、下落/速度、斜坡角度、区域重叠等。共 **7 个条件**，位于 `conditions/physics/` 目录。

| 条件 | class_name | 功能 | 底层方法 |
|------|-----------|------|----------|
| CheckOnFloor | CheckOnFloor | 检测是否在地面 | `is_on_floor()` |
| CheckOnWall | CheckOnWall | 检测是否在墙壁上 | `is_on_wall()` |
| CheckInAir | CheckInAir | 检测是否在空中（不在墙不在面） | `!is_on_floor() && !is_on_wall()` |
| CheckIsFalling | CheckIsFalling | 检测是否正在下落 | 垂直速度 < 阈值 |
| CheckVelocity | CheckVelocity | 速度比较 | `velocity` |
| CheckSlope | CheckSlope | 斜坡角度比较 | `get_floor_normal()` |
| CheckOverlapArea | CheckOverlapArea | Area 重叠检测 | `overlaps_area()`/`overlaps_body()` |

> **注意：** 这些条件需要作用在 `CharacterBody2D` / `CharacterBody3D` 节点上（或继承自 CharacterBody 的类），否则 `is_on_floor()` 等方法将不返回有效结果。

---

## 地面/墙壁/空中

### CheckOnFloor

**文件：** `conditions/physics/check_on_floor.gd`
**class_name：** CheckOnFloor

检测目标 CharacterBody 是否站在地面上。底层调用 `is_on_floor()`。

| 参数 | 类型 | 说明 |
|------|------|------|
| `target_node` | NodePath | 目标角色节点 |

**示例：** 跳跃判定

```
CheckOnFloor → target_node: Player
├── true → CheckInputPressed → action_name: "jump"
│   └── true → (执行跳跃)
└── false → (在空中，不可跳跃)
```

### CheckOnWall

**文件：** `conditions/physics/check_on_wall.gd`
**class_name：** CheckOnWall

检测目标 CharacterBody 是否贴在墙壁上。底层调用 `is_on_wall()`。

| 参数 | 类型 | 说明 |
|------|------|------|
| `target_node` | NodePath | 目标角色节点 |

**示例：** 攀墙检测

```
CheckOnWall → target_node: Player
├── true → CheckInputHeld → action_name: "climb"
│   └── true → (进入攀墙状态)
└── false → (不接触墙面)
```

### CheckInAir

**文件：** `conditions/physics/check_in_air.gd`
**class_name：** CheckInAir

检测目标 CharacterBody 是否在空中（不在墙面、不在底面）。

| 参数 | 类型 | 说明 |
|------|------|------|
| `target_node` | NodePath | 目标角色节点 |

**示例：** 空中二段跳

```
CheckInAir → target_node: Player
├── true → CheckInputPressed → action_name: "jump"
│   └── true → (执行二段跳)
└── false → (在地面，正常跳跃)
```

---

## 下落与速度

### CheckIsFalling

**文件：** `conditions/physics/check_is_falling.gd`
**class_name：** CheckIsFalling

检测角色是否正在下落（垂直速度为负值且低于阈值）。

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `target_node` | NodePath | — | 目标角色节点 |
| `fall_threshold` | float | -0.1 | 下落判定阈值（垂直速度 < 此值视为下落） |

> **CheckInAir vs CheckIsFalling：** 在空中（CheckInAir = true）不代表在下降，可能是跳起上升阶段。两者结合可以区分上升/下降状态。

**示例：** 下落加速

```
CheckIsFalling → target_node: Player, fall_threshold: -0.5
├── true → (调整下坠速度或动画)
└── false → (非下落状态)
```

### CheckVelocity

**文件：** `conditions/physics/check_velocity.gd`
**class_name：** CheckVelocity

检查 CharacterBody 的速度是否满足条件，支持对标量或向量比较。

| 参数 | 类型 | 说明 |
|------|------|------|
| `target_node` | NodePath | 目标角色节点 |
| `check_type` | CheckType | 检查类型：`SCALAR`（速度大小）、`X`（X 轴分量）、`Y`（Y 轴分量）、`Z`（Z 轴分量） |
| `operator` | CompareOperator | 比较运算符 |
| `value` | float | 比较值 |

**示例：** 冲刺速度判断

```
CheckVelocity → target_node: Player, check_type: SCALAR, operator: GREATER_THAN, value: 500.0
├── true → (冲刺中，切换冲刺动画)
└── false → (普通速度)
```

---

## 斜坡与区域

### CheckSlope

**文件：** `conditions/physics/check_slope.gd`
**class_name：** CheckSlope

检测角色所站立面的坡度角度是否满足条件。底层通过 `get_floor_normal()` 计算。

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `target_node` | NodePath | — | 目标角色节点 |
| `operator` | CompareOperator | — | 角度比较运算符 |
| `angle` | float | — | 坡度角度（度数） |

**示例：** 滑铲检测（坡度超过 45° 触发滑铲）

```
CheckSlope → target_node: Player, operator: GREATER_THAN, angle: 45.0
├── true → CheckInputHeld → action_name: "move_down"
│   └── true → (在陡坡上下滑)
└── false → (正常行走)
```

### CheckOverlapArea

**文件：** `conditions/physics/check_overlap_area.gd`
**class_name：** CheckOverlapArea

检测 Area2D/Area3D 是否与其他碰撞体或 Area 发生重叠。底层调用 `get_overlapping_bodies()` / `get_overlapping_areas()`。**不含 `check_type` 枚举**，始终同时检测 bodies 和 areas 的重叠。

| 参数 | 类型 | 说明 |
|------|------|------|
| `area_node` | NodePath | 要检查的 Area2D/Area3D 节点 |
| `check_group` | String | 过滤重叠体所属组（空 = 不过滤） |
| `save_to_variable` | String | 将重叠体列表保存到本地变量（空 = 不保存） |

**示例：** 检测玩家是否进入危险区域

```
CheckOverlapArea → area_node: "Hazards/LavaArea"
├── true → (有重叠体，触发伤害)
└── false → (安全)
```

---

## 常见用例

### 跳跃判定（OnFloor）

```
OnPhysicsProcess
├── CheckOnFloor → target_node: Player
│   ├── true → CheckInputPressed → action_name: "jump"
│   │   └── true → (执行跳跃，设置 velocity.y = jump_velocity)
│   └── false → (空中状态)
└── MoveCharacterBody → target_node: Player
```

### 二段跳（InAir + Velocity）

```
OnPhysicsProcess
├── CheckOnFloor → target_node: Player
│   └── true → SetVariable → scope: LOCAL, name: "jumps_left", value: 2
├── CheckInAir → target_node: Player
│   └── true → CheckInputPressed → action_name: "jump"
│       └── → CheckVariable → name: "jumps_left", operator: GREATER_THAN, value: 0
│           └── true → (二段跳，jumps_left -= 1)
```

### 攀墙检测（OnWall + 方向输入）

```
OnPhysicsProcess
├── CheckOnWall → target_node: Player
│   └── true → CheckInputHeld → action_name: "climb"
│       └── true → (停止水平移动，进入攀墙状态)
└── (否则正常移动)
```

### 滑铲检测（Slope 角度）

```
OnPhysicsProcess
├── CheckOnFloor → target_node: Player
│   └── true → CheckSlope → target_node: Player, operator: GREATER_THAN, angle: 50.0
│       └── true → CheckInputHeld → action_name: "move_down"
│           └── true → (滑铲模式，切换动画和碰撞体积)
```

---

## 注意事项

0. **节点路径与变量二选一**：所有含 NodePath 参数的条件（如 CheckOnFloor、CheckVelocity 等）都支持直接写死节点路径或通过变量动态传入节点引用。
1. **CheckInAir vs CheckIsFalling**：两者不等价。`CheckInAir` 表示"不与任何表面接触"，`CheckIsFalling` 表示"正在下落"。跳跃上升阶段 `InAir = true` 但 `IsFalling = false`。
2. **依赖 `move_and_slide()`**：所有 CharacterBody 地面/墙壁检测依赖 `move_and_slide()` 的调用结果。如果角色未调用 `move_and_slide()`，这些条件将不准确。
3. **CheckOverlapArea 需要 Area 节点**：目标 `area_node` 必须是 `Area2D` / `Area3D` 类型（或继承自 Area），纯碰撞形状（CollisionShape）不触发重叠检测。
4. **斜坡角度单位**：`CheckSlope` 的 `angle` 参数使用**度数**（0-90），而非弧度。
