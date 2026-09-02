> 🌐 中文 | [**English**](../../../en_US/user_docs/guides/50-scene-preloading-guide.md)

# 场景预加载系统

Fuse 提供场景预加载功能，通过 `PreloadSceneInstruction` 和 `CheckPreloadStatus` 配合实现异步加载，避免游戏运行时卡顿。

## 组件概览

| 组件 | 类型 | 用途 |
|------|------|------|
| PreloadSceneInstruction | 指令 | 开始异步加载场景 |
| CheckPreloadStatus | 条件 | 检查加载状态 |

## PreloadSceneInstruction

使用 `ResourceLoader.load_threaded_request()` 在后台加载场景。

**文件:** [preload_scene_instruction.gd](../../../../instructions/scene/preload_scene_instruction.gd)
**分类:** Scene
**图标:** Load

### 预加载模式

| 模式 | 说明 |
|------|------|
| Async Now | 立即开始异步加载，阻塞等待完成 |
| Async Later | 开始异步加载，立即返回（不阻塞） |

### 属性说明

| 属性 | 类型 | 说明 |
|------|------|------|
| scene_path | String | 场景资源路径 (.tscn) |
| preload_mode | PreloadMode | 预加载模式 |
| timeout | float | 超时时间（秒），默认 5.0 |
| status_variable | String | 保存状态到变量的名称 |

### 状态值

加载状态保存到指定的变量，值含义如下：

| 值 | 常量 | 说明 |
|----|------|------|
| 0 | NOT_LOADED | 尚未开始加载 |
| 1 | LOADING | 正在加载中 |
| 2 | LOADED | 加载完成，可以实例化 |
| 3 | FAILED | 加载失败 |
| 4 | TIMEOUT | 加载超时 |

---

## CheckPreloadStatus

检查场景预加载状态。

**文件:** [check_preload_status.gd](../../../../conditions/scene/check_preload_status.gd)
**分类:** Scene
**图标:** Load

### 属性说明

| 属性 | 类型 | 说明 |
|------|------|------|
| scene_path | String | 要检查的场景路径 |
| expected_status | PreloadStatus | 期望的状态 |
| status_variable | String | 状态变量名 |

### 使用前提

必须先使用 `PreloadSceneInstruction` 开始预加载，并将相同的 `scene_path` 和 `status_variable` 传入。

---

## 使用流程

### 1. 开始预加载

```
指令: PreloadSceneInstruction
scene_path: "res://scenes/enemy.tscn"
preload_mode: Async Later
status_variable: "enemy_preload_status"
```

### 2. 检查加载状态

```
条件: CheckPreloadStatus
scene_path: "res://scenes/enemy.tscn"
expected_status: LOADED
status_variable: "enemy_preload_status"
```

### 3. 加载完成后实例化

使用 `CheckPreloadStatus` 作为条件判断，加载完成后用 `AddSceneAsChild` 实例化：

```
条件: CheckPreloadStatus (expected_status: LOADED)
└── 指令: AddSceneAsChild
    scene_path: "res://scenes/enemy.tscn"
    parent_path: "." (当前节点)
    position: (0, 0)
```

---

## 完整示例

### 敌人预加载

在玩家进入战斗区域前预加载敌人场景：

```
Trigger: AreaTrigger (on_body_entered)
│
├── PreloadSceneInstruction
│   scene_path: "res://scenes/enemy.tscn"
│   preload_mode: Async Later
│   status_variable: "enemy_preload_status"
│
└── (后续检查在另一个 Trigger 中)
```

另一个 Trigger 每帧检查状态：

```
Trigger: OnProcess (每帧)
│
└── Conditional (CheckPreloadStatus)
    condition: {status_variable} == LOADED
    then:
    │   └── AddSceneAsChild
    │       scene_path: "res://scenes/enemy.tscn"
    │       parent_path: "." (Spawner 节点)
    │       position: (100, 0)
    └──
        └── (继续等待)
```

### UI 资源预加载

预加载多个 UI 场景：

```
Trigger: GameStart
│
├── PreloadSceneInstruction
│   scene_path: "res://scenes/ui/pause_menu.tscn"
│   preload_mode: Async Later
│   status_variable: "pause_menu_status"
│
├── PreloadSceneInstruction
│   scene_path: "res://scenes/ui/inventory.tscn"
│   preload_mode: Async Later
│   status_variable: "inventory_status"
│
└── PreloadSceneInstruction
    scene_path: "res://scenes/ui/shop.tscn"
    preload_mode: Async Later
    status_variable: "shop_status"
```

---

## 超时处理

如果加载时间过长（默认 5 秒），状态会变为 `TIMEOUT`。

```
Conditional (CheckPreloadStatus)
├── condition: status == LOADED
│   then:
│   │   └── AddSceneAsChild
│   │       scene_path: "res://scenes/heavy_scene.tscn"
│   │       parent_path: "."
│   │
├── condition: status == TIMEOUT
│   then:
│   │   └── LogInstruction
│   │       message: "场景加载超时"
```

---

## 注意事项

- `scene_path` 必须完全一致才能正确检查状态
- `status_variable` 建议使用有意义的名称避免冲突
- Async Later 模式不会阻塞，适合在游戏运行时预加载
- 加载完成后场景已被缓存，`add_to_cache` 可避免重复加载

---

**相关文档:**
- [场景管理指令](../best_practices/custom_instruction.md)
- [异步加载最佳实践](../best_practices/)
