# 综合条件合集

## 概述

本指南汇集 **9 个小类、14 个条件**，覆盖距离、数学、导航、渲染、作用域、字符串、系统、场景、UI 等领域。各小类条件数较少（每类 1-2 个），故合并为单篇指南作为 quick reference。

| 小类 | 条件数 | 条件名称 | 源文件路径 |
|------|--------|---------|-----------|
| distance | 1 | CheckDistance | `conditions/distance/check_distance.gd` |
| math | 1 | ExpressionCondition | `conditions/math/expression_condition.gd` |
| navigation | 1 | CheckPathAvailable | `conditions/navigation/check_path_available.gd` |
| rendering | 1 | CheckIsOnScreen | `conditions/rendering/check_is_on_screen.gd` |
| scope | 1 | CheckScopeVariable | `conditions/scope/check_scope_variable.gd` |
| string | 2 | CheckStringContains、CheckStringLength | `conditions/string/check_string_*.gd` |
| system | 2 | CheckFrameRate、CheckPlatform | `conditions/system/check_*.gd` |
| scene | 1 | CheckPreloadStatus | `conditions/scene/check_preload_status.gd` |
| ui | 1 | CheckUIVisible | `conditions/ui/check_ui_visible.gd` |

**补充：variable 类**中的非核心条件（核心变量比较已覆盖在 `01-variable-system-guide.md`）：

| 补充 | 条件数 | 条件名称 |
|------|--------|---------|
| variable 补充 | 3 | CheckVector2VariableAxis、CheckHealthValue、CompareHealthThreshold |

---

## 距离与导航

### CheckDistance

**文件：** `conditions/distance/check_distance.gd`
**class_name：** CheckDistance

检查两个节点或位置之间的距离是否满足条件。

| 参数 | 类型 | 说明 |
|------|------|------|
| `source` | NodePath | 源节点 |
| `target` | NodePath | 目标节点（与 `target_position` 二选一） |
| `target_position` | Vector3 | 目标位置 |
| `operator` | CompareOperator | 比较运算符 |
| `value` | float | 比较距离值 |
| `use_3d` | bool | 是否使用 3D 距离计算 |

**示例：** 检测敌人接近

```
CheckDistance → source: Player, target: Enemy, operator: LESS_THAN, value: 10.0
├── true → (敌人接近，切换战斗状态)
└── false → (距离安全)
```

### CheckPathAvailable

**文件：** `conditions/navigation/check_path_available.gd`
**class_name：** CheckPathAvailable

检查 NavigationAgent2D/3D 是否有到目标位置的有效路径。

| 参数 | 类型 | 说明 |
|------|------|------|
| `agent_node` | NodePath | NavigationAgent 节点路径 |
| `target_position` | Vector2 | 目标位置 |

**示例：** AI 寻路判断

```
CheckPathAvailable → agent_node: EnemyNavAgent, target_position: (100, 200)
├── true → (可以到达目标位置，开始追踪)
└── false → (路径不可达，切换巡逻模式)
```

---

## 数学表达式

### ExpressionCondition

**文件：** `conditions/math/expression_condition.gd`
**class_name：** ExpressionCondition

使用 GDScript `Expression` 求值引擎评估布尔表达式。支持变量引用。

| 参数 | 类型 | 说明 |
|------|------|------|
| `expression` | String | GDScript 布尔表达式（如 `"a > b && c <= 10"`） |
| `variable_bindings` | Dictionary | 变量绑定，将变量名映射到表达式中使用的名称 |

**示例：** 复杂条件判断

```
ExpressionCondition → expression: "health > 50 && has_weapon == true", variable_bindings: {"health": {scope:player_health}, "has_weapon": {local:weapon_equipped}}
├── true → (血量充足且有武器，主动进攻)
└── false → (保守策略)
```

---

## 渲染与 UI

### CheckIsOnScreen

**文件：** `conditions/rendering/check_is_on_screen.gd`
**class_name：** CheckIsOnScreen

检查节点是否在当前视口可见范围内。

| 参数 | 类型 | 说明 |
|------|------|------|
| `target_node` | NodePath | 目标节点 |
| `expected_on_screen` | bool | 期望的可见状态 |

**示例：** 敌人离开屏幕后回收

```
CheckIsOnScreen → target_node: EnemyProjectile, expected_on_screen: false
├── true → (弹幕已离开屏幕，回收对象)
└── false → (仍在屏幕上)
```

### CheckUIVisible

**文件：** `conditions/ui/check_ui_visible.gd`
**class_name：** CheckUIVisible

检查 UI 元素的可见性状态（CanvasItem.visible）。不含外部"期望值"参数，直接判断当前可见性。

| 参数 | 类型 | 说明 |
|------|------|------|
| `target_node` | NodePath | 目标 UI 节点（CanvasItem/Control 类型） |

**示例：** 菜单已打开时阻止操作

```
CheckUIVisible → target_node: "UI/PauseMenu"
├── true → (暂停菜单已打开，不响应游戏内输入)
└── false → (菜单已关闭，游戏正常运行)
```

---

## 作用域与变量

### CheckScopeVariable

**文件：** `conditions/scope/check_scope_variable.gd`
**class_name：** CheckScopeVariable

检查作用域中的变量值是否满足条件。

| 参数 | 类型 | 说明 |
|------|------|------|
| `variable_name` | String | 作用域变量名 |
| `scope_source` | ScopeSource | 作用域来源 |
| `operator` | CompareOperator | 比较运算符 |
| `value` | Variant | 比较值 |

**示例：** 检查 Trigger 作用域中的参数

```
CheckScopeVariable → variable_name: "interactable_type", scope_source: TRIGGER_SCOPE, operator: EQUALS, value: "door"
├── true → (与门交互，执行开门逻辑)
└── false → CheckScopeVariable → variable_name: "interactable_type", operator: EQUALS, value: "item"
    └── true → (拾取物品)
```

### CheckVector2VariableAxis

**文件：** `conditions/variable/check_vector2_variable_axis.gd`
**class_name：** CheckVector2VariableAxis

检查 Vector2 变量的指定轴（X 或 Y）是否满足条件。

| 参数 | 类型 | 说明 |
|------|------|------|
| `variable_name` | String | Vector2 变量名 |
| `variable_scope` | ScopeSource | 变量作用域 |
| `axis` | AxisType | 轴选择：`X` 或 `Y` |
| `operator` | CompareOperator | 比较运算符 |
| `value` | float | 比较值 |

**示例：** 检查移动方向水平分量

```
CheckVector2VariableAxis → variable_name: "move_direction", variable_scope: LOCAL, axis: X, operator: GREATER_THAN, value: 0.0
├── true → (向右移动)
└── false → (向左或静止)
```

### CheckHealthValue

**文件：** `conditions/variable/check_health_value.gd`
**class_name：** CheckHealthValue

检查指定变量中的生命值是否等于目标值。通过变量名和作用域查找生命值。

| 参数 | 类型 | 说明 |
|------|------|------|
| `health_variable` | String | 生命值变量名 |
| `variable_scope` | VariableScope | 变量作用域（Local/Scope/Global） |
| `target_value` | float | 目标比较值 |

**示例：** 低血量警告

```
CheckHealthValue → health_variable: "player_hp", variable_scope: LOCAL, target_value: 30.0
├── true → (生命值等于 30，触发低血量特效)
└── false → (血量不等于目标值)
```

### CompareHealthThreshold

**文件：** `conditions/variable/compare_health_threshold.gd`
**class_name：** CompareHealthThreshold

比较当前生命值与单阈值，使用比较运算符判定关系。返回布尔值。

| 参数 | 类型 | 说明 |
|------|------|------|
| `health_variable` | String | 生命值变量名 |
| `variable_scope` | VariableScope | 变量作用域（Local/Scope/Global） |
| `threshold` | float | 比较阈值 |
| `comparison_operator` | int | 比较运算符：0=小于、1=大于、2=小于等于、3=大于等于、4=等于 |

**示例：** Boss 阶段判定

```
CompareHealthThreshold → health_variable: "boss_hp", variable_scope: LOCAL, threshold: 30.0, comparison_operator: 0
├── true → (血量低于 30%，最终阶段)
└── false → (血量不低于阈值)
```

---

## 字符串

### CheckStringContains

**文件：** `conditions/string/check_string_contains.gd`
**class_name：** CheckStringContains

检查字符串是否包含指定子串。

| 参数 | 类型 | 说明 |
|------|------|------|
| `source_variable` | String | 源字符串变量名 |
| `search` | String | 要包含的子串 |
| `case_sensitive` | bool | 是否区分大小写 |

**示例：** 对话选项匹配

```
CheckStringContains → source_variable: "player_input", search: "key", case_sensitive: false
├── true → (玩家输入包含"key"，触发钥匙相关对话)
└── false → (不包含关键词)
```

### CheckStringLength

**文件：** `conditions/string/check_string_length.gd`
**class_name：** CheckStringLength

检查字符串长度是否满足条件。

| 参数 | 类型 | 说明 |
|------|------|------|
| `source_variable` | String | 源字符串变量名 |
| `compare_type` | CompareType | 比较类型（EQUAL/NOT_EQUAL/GREATER/LESS/GREATER_EQUAL/LESS_EQUAL） |
| `threshold` | int | 阈值长度值 |

**示例：** 输入验证

```
CheckStringLength → source_variable: "player_name", compare_type: GREATER, threshold: 0
├── true → (玩家已输入名称)
└── false → (名称为空，提示输入)
```

---

## 系统与场景

### CheckFrameRate

**文件：** `conditions/system/check_frame_rate.gd`
**class_name：** CheckFrameRate

检查当前帧率是否满足阈值条件。可用于自动调整画质。

| 参数 | 类型 | 说明 |
|------|------|------|
| `compare_type` | CompareType | 比较类型（EQUAL/NOT_EQUAL/GREATER/LESS/GREATER_EQUAL/LESS_EQUAL） |
| `threshold_fps` | float | 帧率阈值（FPS） |

**示例：** 动态画质调整

```
CheckFrameRate → compare_type: LESS, threshold_fps: 30.0
├── true → (帧率低于 30，降低画质设置)
└── false → (帧率正常)
```

### CheckPlatform

**文件：** `conditions/system/check_platform.gd`
**class_name：** CheckPlatform

检查当前运行平台。适用于平台相关的条件分支。

| 参数 | 类型 | 说明 |
|------|------|------|
| `platform` | PlatformType | 目标平台：`WINDOWS`、`LINUX`、`MACOS`、`ANDROID`、`IOS`、`WEB` |

**示例：** 平台适配

```
CheckPlatform → platform: MOBILE
├── true → (移动端，使用触控 UI 方案)
└── false → (桌面端，使用键鼠方案)
```

### CheckPreloadStatus

**文件：** `conditions/scene/check_preload_status.gd`
**class_name：** CheckPreloadStatus

检查场景预加载（`ScenePreloader`）的状态。

| 参数 | 类型 | 说明 |
|------|------|------|
| `scene_path` | String | 场景路径 |
| `status` | PreloadStatus | 状态检查：`LOADING`（加载中）、`COMPLETE`（已完成）、`FAILED`（失败） |

**示例：** 预加载完成后切换场景

```
CheckPreloadStatus → scene_path: "res://levels/boss_level.tscn", status: COMPLETE
├── true → (预加载完成，切换到该场景)
└── false → CheckPreloadStatus → scene_path: "res://levels/boss_level.tscn", status: LOADING
    └── true → (加载中，显示进度条)
```

---

## 常见用例

### 敌人接近检测（Distance + 导航）

```
OnInterval → interval_seconds: 2.0
├── CheckDistance → source: Enemy, target: Player, operator: LESS_THAN, value: 15.0
│   └── true → CheckPathAvailable → agent_node: EnemyNavAgent, target_position: (100, 200)
│       ├── true → (开始追踪玩家)
│       └── false → CheckIsOnScreen → target_node: Enemy, expected_on_screen: true
│           └── true → (可见但不可达，使用其他方式接近)
```

### 输入验证 + UI 可见性

```
Trigger: OnInputAction → action_name: "submit_name"
├── CheckUIVisible → target_node: "UI/NameInput"
│   └── true → CheckStringLength → source_variable: "input_text", compare_type: GREATER, threshold: 0
│       ├── true → CheckStringContains → source_variable: "input_text", search: "admin"
│       │   ├── true → (管理员命令处理)
│       │   └── false → (普通玩家名，保存并继续)
│       └── false → (名称为空，提示错误)
```

### 动态画质调整（CheckFrameRate + CheckPlatform）

```
OnInterval → interval_seconds: 10.0
├── CheckFrameRate → compare_type: LESS, threshold_fps: 30.0
│   └── true → (低帧率模式)
│       ├── (降低阴影质量)
│       └── (禁用后处理特效)
└── CheckPlatform → platform: MOBILE
    └── true → (移动端默认使用中等画质预设)
```

---

## 注意事项

0. **节点路径与变量二选一**：含 NodePath 参数的条件（如 CheckDistance、CheckIsOnScreen 等）既支持直接写死节点路径，也支持通过变量（Scope/Local/Global）动态传入节点引用，灵活适配不同场景。
1. **CheckIsOnScreen 依赖视口**：需要节点在当前激活的视口内，且未被其他节点完全遮挡。
2. **CheckPathAvailable 需要 NavigationAgent**：目标节点必须是 NavigationAgent2D/3D。
3. **CheckPreloadStatus 需要 ScenePreloader**：场景必须已通过 `ScenePreloader` 或场景预加载指令启动加载。
4. **ExpressionCondition 仅支持布尔结果**：表达式最终必须返回 `true` 或 `false`。不支持非布尔返回值。
5. **距离开销**：`CheckDistance` 每次调用计算欧几里得距离，高频使用时考虑降低调用频率。

**相关文档不重复的范围：**
- 核心变量比较（`CompareVariable`、`CheckVariable`）→ 见 `01-variable-system-guide.md`
- 组合条件（`CheckAll`、`CheckAny`、`CheckNot`、`CheckComposite`）→ 见 `composite-conditions-guide.md`
- 数组条件 → 见 `array-operations-guide.md`
- 字典条件 → 见 `dictionary-operations-guide.md`
