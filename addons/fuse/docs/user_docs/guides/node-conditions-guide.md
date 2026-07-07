# Node 条件指南

## 概述

Node 条件用于在流程控制中查询节点状态：是否存在、是否启用/禁用、是否在组中、属性值、方位、层级关系等。共 **9 个条件**，位于 `conditions/node/` 目录。

| 分类 | 条件 | class_name | 功能 |
|------|------|-----------|------|
| 存在与状态 | CheckNodeExists | CheckNodeExists | 节点是否存在 |
| 存在与状态 | CheckNodeActive | CheckNodeActive | 节点是否启用/禁用 |
| 组与属性 | CheckNodeInGroup | CheckNodeInGroup | 节点是否在指定组中 |
| 组与属性 | CheckNodeProperty | CheckNodeProperty | 节点属性值比较 |
| 组与属性 | CheckGroupCount | CheckGroupCount | 组内节点数量比较 |
| 层次关系 | CheckIsChildOf | CheckIsChildOf | 是否是指定节点的子节点 |
| 层次关系 | CheckChildCount | CheckChildCount | 子节点数量比较 |
| 方位检测 | CheckDirection | CheckDirection | 节点相对于目标的方向 |
| 方位检测 | CheckFacingDirection | CheckFacingDirection | 节点是否朝向目标 |

---

## 存在与状态

### CheckNodeExists

**文件：** `conditions/node/check_node_exists.gd`
**class_name：** CheckNodeExists

检查节点是否在当前场景树中存在。

| 参数 | 类型 | 说明 |
|------|------|------|
| `node_path` | NodePath | 要检查的节点路径 |

**示例：** 检查武器是否存在再攻击

```
CheckNodeExists → node_path: "Player/Weapon"
├── true → (执行攻击逻辑)
└── false → (空手攻击或警告)
```

### CheckNodeActive

**文件：** `conditions/node/check_node_active.gd`
**class_name：** CheckNodeActive

检查节点是否处于启用/活动状态。通过 `process_mode` 判断。

| 参数 | 类型 | 说明 |
|------|------|------|
| `target_node` | NodePath | 目标节点 |
| `expected_active` | bool | 期望的活动状态（true = 启用，false = 禁用） |

**示例：** 检查机关是否激活

```
CheckNodeActive → target_node: "Traps/LaserGate", expected_active: false
├── true → (门已关闭，安全通过)
└── false → (门开着，有危险)
```

---

## 组与属性

### CheckNodeInGroup

**文件：** `conditions/node/check_node_in_group.gd`
**class_name：** CheckNodeInGroup

检查节点是否被添加到指定组中。

| 参数 | 类型 | 说明 |
|------|------|------|
| `target_node` | NodePath | 目标节点 |
| `group_name` | String | 组名称 |

**示例：** 检查敌人类型

```
CheckNodeInGroup → target_node: Enemy, group_name: "boss"
├── true → (Boss 级敌人，使用特殊处理)
└── false → (普通小兵)
```

### CheckNodeProperty

**文件：** `conditions/node/check_node_property.gd`
**class_name：** CheckNodeProperty

检查节点的指定属性值是否满足条件。

| 参数 | 类型 | 说明 |
|------|------|------|
| `target_node` | NodePath | 目标节点 |
| `property_name` | String | 属性名称 |
| `operator` | CompareOperator | 比较运算符 |
| `value` | Variant | 比较值 |

**示例：** Boss 阶段判断

```
CheckNodeProperty → target_node: Boss, property_name: "phase", operator: EQUALS, value: 2
├── true → (Boss 第二阶段，切换攻击模式)
└── false → (第一阶段攻击模式)
```

### CheckGroupCount

**文件：** `conditions/node/check_group_count.gd`
**class_name：** CheckGroupCount

检查指定组中的节点数量是否满足条件。

| 参数 | 类型 | 说明 |
|------|------|------|
| `group_name` | String | 组名称 |
| `operator` | CompareOperator | 比较运算符 |
| `value` | int | 比较数量 |

**示例：** 组内人数不足时召唤援军

```
CheckGroupCount → group_name: "enemies", operator: LESS_THAN, value: 3
├── true → (敌人少于 3 个，召唤援军)
└── false → (继续观察)
```

---

## 层次关系

### CheckIsChildOf

**文件：** `conditions/node/check_is_child_of.gd`
**class_name：** CheckIsChildOf

检查节点是否是指定父节点的（直接或间接）子节点。

| 参数 | 类型 | 说明 |
|------|------|------|
| `target_node` | NodePath | 要检查的节点 |
| `parent_node` | NodePath | 父节点 |

**示例：** 检查物品是否在背包中

```
CheckIsChildOf → target_node: Potion, parent_node: "Player/Inventory"
├── true → (药水在背包中，可以使用)
└── false → (不在背包中)
```

### CheckChildCount

**文件：** `conditions/node/check_child_count.gd`
**class_name：** CheckChildCount

检查节点的直接子节点数量是否满足条件。

| 参数 | 类型 | 说明 |
|------|------|------|
| `target_node` | NodePath | 目标节点 |
| `operator` | CompareOperator | 比较运算符 |
| `value` | int | 比较数量 |

**示例：** 容器满时停止收集

```
CheckChildCount → target_node: "Player/Backpack", operator: GREATER_EQUALS, value: 20
├── true → (背包已满，提示清理)
└── false → (还可以继续收集)
```

---

## 方位检测

### CheckDirection

**文件：** `conditions/node/check_direction.gd`
**class_name：** CheckDirection

检查节点相对于目标的位置方向（左/右/上/下）。

| 参数 | 类型 | 说明 |
|------|------|------|
| `source_node` | NodePath | 源节点 |
| `target_node` | NodePath | 目标节点 |
| `direction` | Vector2 | 期望的方向向量 |

### CheckFacingDirection

**文件：** `conditions/node/check_facing_direction.gd`
**class_name：** CheckFacingDirection

检查节点是否朝向另一个节点或位置。

| 参数 | 类型 | 说明 |
|------|------|------|
| `source_node` | NodePath | 源节点 |
| `target_node` | NodePath | 目标节点（可选，与 target_position 二选一） |
| `target_position` | Vector3 | 目标位置（可选） |
| `angle_threshold` | float | 角度容差（度数） |

**示例：** 玩家是否面对宝箱

```
CheckFacingDirection → source_node: Player, target_node: TreasureChest, angle_threshold: 30.0
├── true → (玩家面对宝箱，显示开启提示)
└── false → (不显示)
```

---

## 常见用例

### 检查武器是否存在再攻击

```
Trigger: OnInputAction (attack)
├── CheckNodeExists → node_path: "Player/Weapon"
│   ├── true → (使用武器攻击)
│   └── false → CheckNodeProperty → target: Player, property: "has_weapon_equipped", operator: EQUALS, value: true
│       └── true → (有装备但节点未就绪，延迟处理)
└── (没有武器，播放空手攻击)
```

### 判断 Boss 阶段的组人数

```
OnInterval → interval_seconds: 5.0
├── CheckNodeProperty → target: Boss, property_name: "phase", operator: EQUALS, value: 2
│   └── true → CheckGroupCount → group_name: "boss_minions", operator: GREATER_THAN, value: 0
│       └── true → (还有小兵，Boss 无敌中)
│       └── false → (小兵已清完，Boss 进入可攻击阶段)
```

### 双面角色朝向检测

```
CheckFacingDirection → source_node: Enemy, target_node: Player, angle_threshold: 45.0
├── true → (敌人面对玩家，防御正面攻击)
└── false → CheckFacingDirection → source_node: Enemy, target_node: Player, angle_threshold: 135.0
    ├── true → (背对玩家，触发背刺伤害加成)
    └── false → (侧面)
```

---

## 注意事项

0. **节点路径与变量二选一**：含 NodePath 参数的条件（如 CheckNodeExists、CheckNodeActive 等）既支持直接写死节点路径，也支持通过变量动态传入节点引用。
1. **节点路径有效性**：在场景切换后，之前缓存的 `NodePath` 可能失效。场景切换后重新获取节点引用。
2. **组名大小写**：Godot 组名区分大小写，确保 `CheckNodeInGroup` 和 `CheckGroupCount` 使用的组名一致。
3. **CheckDirection vs CheckFacingDirection**：前者检查位置关系（源节点在目标节点的哪一侧），后者检查朝向（源节点的朝向是否指向目标）。
