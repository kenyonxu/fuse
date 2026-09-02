# Lifecycle 事件指南

## 概述

Lifecycle 事件在节点的生命周期节点触发，覆盖从场景就绪到退出的全过程。共 **7 个事件**，位于 `events/lifecycle/` 目录。

| 事件 | class_name | 触发时机 | 触发频率 | 性能影响 |
|------|-----------|----------|----------|----------|
| OnReady | OnReady | 场景树就绪后（`_ready()`） | 单次 | 低 |
| OnEnterTree | OnEnterTree | 节点进入场景树（`tree_entered`） | 单次 | 低 |
| OnExitTree | OnExitTree | 节点退出场景树（`tree_exiting`） | 单次 | 低 |
| OnProcess | OnProcess | 每帧（`_process(delta)`） | 每帧 | ⚠️ 高 |
| OnPhysicsProcess | OnPhysicsProcess | 每物理帧（`_physics_process(delta)`） | 固定频率（默认 60 FPS） | ⚠️ 高 |
| OnInterval | OnInterval | 按固定时间间隔 | 可配置 | 中 |
| OnIntervalWithVariable | OnIntervalWithVariable | 间隔由变量动态决定 | 可配置 | 中 |

---

## 一次性触发事件

### OnReady

**文件：** `events/lifecycle/on_ready.gd`
**class_name：** OnReady

对应 Godot 的 `_ready()` 回调。场景树就绪后立即触发，适合**初始化逻辑**。

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `delay_seconds` | float | 0.0 | 延迟触发秒数 |

**示例：** 初始化血量、绑定信号、加载配置

```
OnReady
└── SetVariable
    variable_name: "player_health"
    value: 100
    scope: GLOBAL
```

### OnEnterTree

**文件：** `events/lifecycle/on_enter_tree.gd`
**class_name：** OnEnterTree

对应 `tree_entered` 信号。节点进入场景树时触发，**早于 OnReady**。

**与 OnReady 的区别：**
- `OnEnterTree` 在节点加入场景树时立即触发，父节点可能尚未就绪
- `OnReady` 确保整个场景树就绪后触发，更安全
- 大部分情况应使用 `OnReady`

| 参数 | 类型 | 说明 |
|------|------|------|
| — | — | 无参数 |

### OnExitTree

**文件：** `events/lifecycle/on_exit_tree.gd`
**class_name：** OnExitTree

对应 `tree_exiting` 信号。节点即将退出场景树时触发，适合**资源清理**。

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `cleanup_resources` | bool | false | 是否自动清理持有的资源引用 |

**示例：** 保存游戏进度、断开信号、释放资源

```
OnExitTree
├── SaveGlobalVariables
│   save_target: Assistant Resource
│   save_scope: PERSISTENT_ONLY
└── LogInstruction
    message: "场景退出，数据已保存"
```

---

## 帧循环事件

### OnProcess

**文件：** `events/lifecycle/on_process.gd`
**class_name：** OnProcess

对应 `_process(delta)`。**每帧**触发，用于持续的检测和更新。

> **⚠️ 性能警告：** OnProcess 每帧触发，对性能影响极高。务必设置 `execution_interval` 降低频率。

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `execution_interval` | float | 0.016 | 执行间隔（秒），默认 0.016（约 60 FPS）；设为 0 为每帧执行 |

**建议：**
- 持续检测用 `OnInterval` 替代（更可控）
- 必须用 OnProcess 时设置 `execution_interval ≥ 0.1`（每秒最多 10 次）

### OnPhysicsProcess

**文件：** `events/lifecycle/on_physics_process.gd`
**class_name：** OnPhysicsProcess

对应 `_physics_process(delta)`。每**物理帧**触发，固定频率（默认 60 FPS）。适合物理相关更新。

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `execution_interval` | int | 0 | 执行间隔（物理帧数），0 = 每物理帧执行 |

**建议：**
- 物理移动/力控制配合 `OnPhysicsProcess` + `MoveCharacterBody`（移动系统）
- `execution_interval` 以物理帧为单位，设 `2` = 每 2 物理帧执行一次（约 30 FPS）

---

## 间隔执行事件

### OnInterval

**文件：** `events/lifecycle/on_interval.gd`
**class_name：** OnInterval

按固定时间间隔周期性触发。比 `OnProcess` 更可控、性能更好。

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `interval_seconds` | float | 1.0 | 触发间隔（秒） |
| `max_repeats` | int | 0 | 最大触发次数（0 = 无限） |
| `auto_start` | bool | true | 是否自动启动 |
| `trigger_on_start` | bool | false | 启动时立即触发一次 |

**示例：** 每 5 秒检查一次玩家状态

```
OnInterval → interval_seconds: 5.0, max_repeats: 0
└── CheckNodeProperty
    target_node: Player
    property_name: "health"
    operator: LESS_THAN
    value: 30
    └── (触发低血量处理)
```

### OnIntervalWithVariable

**文件：** `events/lifecycle/on_interval_with_variable.gd`
**class_name：** OnIntervalWithVariable

与 `OnInterval` 相同，但间隔值从**变量**动态读取，运行时可变。继承 `OnInterval` 所有参数。

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `variable_name` | String | "interval" | 存放间隔值的变量名 |
| `variable_scope` | VariableScope | LOCAL | 变量作用域（Local/Scope/Global） |
| `default_interval` | float | 1.0 | 变量不存在或无效时使用的默认间隔值 |
| `initialize_variable` | bool | true | 是否在初始化时自动设置变量的默认值 |
| `max_repeats` | int | 0 | 最大触发次数（0 = 无限） |
| `auto_start` | bool | true | 是否自动启动 |
| `trigger_on_start` | bool | false | 启动时立即触发 |

---

## 性能分级建议

| 事件 | 性能等级 | 使用建议 |
|------|---------|----------|
| **OnReady** | ✅ 低 | 任意使用 |
| **OnEnterTree** | ✅ 低 | 特殊场景使用 |
| **OnExitTree** | ✅ 低 | 必用在清理场景 |
| **OnInterval** | ⚠️ 中 | 按需设置间隔，推荐 ≥ 0.1s |
| **OnIntervalWithVariable** | ⚠️ 中 | 确保 min_interval ≥ 0.033s |
| **OnProcess** | 🔴 高 | 必须设置 execution_interval |
| **OnPhysicsProcess** | 🔴 高 | 仅物理更新时使用，设置 execution_interval |

---

## 常见用例

### 初始化逻辑（OnReady）

```
OnReady → delay_seconds: 0.5
├── SetVariable → scope: GLOBAL, name: "game_started", value: true
├── InstantiateScene → scene_path: "res://ui/hud.tscn", parent_node: "/root/Game/UI"
└── LogInstruction → message: "游戏初始化完成"
```

### 持续检测（OnInterval 替代 OnProcess）

```
OnInterval → interval_seconds: 2.0, max_repeats: 0
├── CheckDistance → target_a: Player, target_b: Enemy, operator: LESS_THAN, value: 10.0
│   └── (敌人接近玩家，触发战斗)
└── LogInstruction → message: "正在扫描敌人..."
```

### 物理帧同步更新（OnPhysicsProcess + MoveCharacterBody）

```
OnPhysicsProcess → execution_interval: 0
└── MoveCharacterBody
    target_node: Player
    direction: {scope:input_direction}
    speed: 300.0
```

---

## 注意事项

1. **OnProcess 性能**：每帧触发，复杂的指令链会严重掉帧。能用 `OnInterval` 的不要用 `OnProcess`。
2. **PhysicsProcess 默认帧率**：60 FPS，`execution_interval = 1` 等效 30 FPS。
3. **OnExitTree 清理**：需要手动断开信号引用的资源，否则可能内存泄漏。
4. **OnEnterTree 时机**：比 OnReady 早，此时某些子节点可能尚未就绪。大部分情况用 OnReady 即可。
