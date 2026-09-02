# Node 事件指南

## 概述

Node 事件在节点状态变化或特定信号触发时响应，覆盖属性变化监听、信号转发、实例化检测等场景。共 **4 个事件**，位于 `events/node/` 目录。

| 事件 | class_name | 触发条件 | 触发模式 |
|------|-----------|----------|----------|
| OnPropertyChanged | OnPropertyChanged | 目标节点指定属性的值变化 | 轮询检查 |
| OnSignalFromGroup | OnSignalFromGroup | 组内任意节点发射指定信号 | 信号绑定 |
| OnTargetSignalEmit | OnTargetSignalEmit | 目标节点发射指定信号 | 信号绑定 |
| OnNodeInstance | OnNodeInstance | 指定场景被实例化 | 信号绑定 |

---

## OnPropertyChanged（属性变化）

**文件：** `events/node/on_property_changed.gd`
**class_name：** OnPropertyChanged

当目标节点的指定属性值变化时触发。

> **⚠️ 注意：** 该事件使用**轮询模式**（按 `check_interval` 定期检查），而非信号绑定。不会自动响应属性变化，存在检测延迟。

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `target_node` | NodePath | — | 要监听的节点 |
| `property_name` | String | "" | 要监听的属性名（如 `"health"`、`"position"`） |
| `check_interval` | float | 0.1 | 轮询间隔（秒） |
| `emit_old_and_new` | bool | true | 触发时是否传递旧值和新值 |

**`emit_old_and_new` 影响：**
- `false`：触发时仅传递属性名称
- `true`：触发时传递 `property_name`、`old_value`、`new_value` 到后续指令链

**示例：** 监听血量变化触发 UI 更新

```
OnPropertyChanged → target_node: Player, property_name: "health", check_interval: 0.05, emit_old_and_new: true
├── (血量变化时触发)
└── SetVariable → variable_name: "hud_health", value: {scope:new_value}
```

---

## OnSignalFromGroup（组信号）

**文件：** `events/node/on_signal_from_group.gd`
**class_name：** OnSignalFromGroup

**组内任意节点**发射指定信号时触发。适用于监听组中所有对象的统一行为（如敌人组中任意一个死亡）。

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `signal_name` | String | "" | 要监听的信号名称 |
| `group_name` | String | "" | 目标组名称 |
| `emit_node` | bool | false | 是否将发射信号的节点传递到指令链 |
| `emit_signal_name` | bool | false | 是否将信号名传递到指令链 |

**示例：** 组内任意敌人死亡

```
OnSignalFromGroup → signal_name: "died", group_name: "enemies"
├── (敌人死亡时触发)
├── AddScore → points: 100
└── LogInstruction → message: "敌人被击败"
```

---

## OnTargetSignalEmit（目标信号）

**文件：** `events/node/on_target_signal_emit.gd`
**class_name：** OnTargetSignalEmit

目标节点发射指定信号时触发。与 Editor 中的信号缓存自动刷新集成。

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `target_node` | NodePath | — | 目标节点路径 |
| `target_signal` | String | "" | 要监听的信号名称 |
| `trigger_once` | bool | false | 是否只触发一次 |
| `filter_signal_args` | bool | false | 是否启用信号参数过滤 |
| `arg_filter_values` | Array | [] | 参数过滤值（filter_signal_args=true 时生效） |

**编辑器支持：** 选择目标节点后，信号名称下拉列表会自动缓存该节点的可用信号，便于快速选择。

**示例：** 按钮点击事件

```
OnTargetSignalEmit → target_node: "UI/StartButton", target_signal: "pressed"
├── HideUI
├── InstantiateScene → scene_path: "res://levels/level_01.tscn"
└── LogInstruction → message: "游戏开始"
```

---

## OnNodeInstance（节点实例化）

**文件：** `events/node/on_node_instance.gd`
**class_name：** OnNodeInstance

当指定场景被实例化时触发。适用于场景预加载完成后执行初始化逻辑。

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `scene_path` | String | "" | 要监听的场景路径 |
| `parent_node` | NodePath | — | 实例化的父节点（用于匹配） |
| `emit_instance` | bool | false | 是否将实例化结果传递到指令链 |

**示例：** 场景预加载完成触发

```
OnNodeInstance → scene_path: "res://levels/boss_room.tscn"
├── (Boss 场景已实例化)
├── SetVariable → name: "boss_health", value: 1000, scope: GLOBAL
└── LogInstruction → message: "Boss 房间已加载"
```

---

## 常见用例

### 监听血量变化触发 UI

```
OnPropertyChanged → target_node: Player, property_name: "health", check_interval: 0.05
├── SetVariable → scope: GLOBAL, name: "player_health", value: {scope:new_value}
└── PlayAnimation → target: HealthBar, animation: "update"
```

### 组内事件广播

```
# 在任何敌人击中被监听
OnSignalFromGroup → signal_name: "hit", group_name: "enemies", emit_node: true
├── (获取被击中的敌人引用)
└── (触发受击反应逻辑)
```

### 按钮点击启动游戏

```
OnTargetSignalEmit → target_node: "CanvasLayer/MainMenu/PlayButton", target_signal: "pressed"
├── ChangeScene → scene_path: "res://levels/intro.tscn"
└── (播放过渡动画)
```

---

## 注意事项

1. **OnPropertyChanged 轮询模式**：该事件不是真正的信号绑定，而是按 `check_interval` 定时轮询属性值。响应有延迟（最长等于检查间隔）。高频率属性建议用低于 0.05s 的间隔。
2. **OnTargetSignalEmit 信号可用性**：目标节点必须拥有指定的信号。如果运行时节点变更，需要刷新编辑器中的信号缓存列表。
3. **OnSignalFromGroup 组名**：组名区分大小写，确保目标节点已被添加到指定组。
4. **OnNodeInstance 匹配**：场景路径需要与 `InstantiateScene` 指令中使用的路径完全一致（包含资源后缀 .tscn）。
