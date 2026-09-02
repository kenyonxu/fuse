> 🌐 中文 | [**English**](../../../en_US/user_docs/guides/17-scene-management-guide.md)

# 场景管理指令使用指南

Fuse 场景管理系统提供 6 个指令，覆盖场景切换、重新加载、场景路径获取、子节点实例化、预加载和后台加载等完整的场景操作链路。

## 指令列表

| 名称 | 功能描述 | 关键参数 |
|------|----------|----------|
| **ChangeScene** | 切换到新场景 | `scene_path`（目标场景路径）、`delay`（延迟时间，秒） |
| **ReloadScene** | 重新加载当前场景 | `delay`（延迟时间，秒） |
| **GetScenePath** | 获取当前场景路径 | `path_mode`（场景文件路径/根节点路径）、`save_to_variable` |
| **AddSceneAsChild** | 实例化场景为子节点 | `scene_path`（场景路径）、`target_parent`（父节点路径）、`new_node_name`（节点名称） |
| **PreloadSceneInstruction** | 后台预加载场景 | `scene_path`（场景路径）、`preload_mode`（Async Now/Async Later）、`status_variable`（状态变量） |
| **LoadSceneBackground** | 异步加载场景到变量 | `scene_path`（场景路径）、`save_to_variable`（保存 PackedScene 的变量名） |

---

## ChangeScene

切换到指定场景，支持延迟切换。

**分类:** Scene Management | **图标:** PlayCustom

### 参数说明

| 参数 | 类型 | 说明 |
|------|------|------|
| `scene_path` | String | 目标场景文件路径（.tscn/.scn） |
| `delay` | float | 延迟切换时间（秒），默认 0，范围 0-10 |

### 使用示例

```
# 立即切换到游戏场景
ChangeScene → scene_path: "res://scenes/game.tscn", delay: 0.0

# 延迟 2 秒后切换到主菜单（配合动画使用）
ChangeScene → scene_path: "res://scenes/main_menu.tscn", delay: 2.0
```

ChangeScene 是异步指令——设置延迟后会等待倒计时结束才完成。

---

## ReloadScene

重新加载当前场景，适用于重试/重新开始场景。

**分类:** Scene | **图标:** Reload

### 参数说明

| 参数 | 类型 | 说明 |
|------|------|------|
| `delay` | float | 延迟时间（秒），默认 0，范围 0-3600 |

### 使用示例

```
# 立即重新加载当前场景
ReloadScene → delay: 0.0

# 玩家死亡后延迟 3 秒重新加载
ReloadScene → delay: 3.0
```

---

## GetScenePath

获取当前场景的路径信息并保存到变量。

**分类:** Scene | **图标:** Tree

### 路径模式

| 模式 | 说明 | 返回值示例 |
|------|------|------------|
| **Current Scene File Path** | 场景文件路径 | `"res://scenes/level_01.tscn"` |
| **Root Node Path** | 根节点在场景树中的路径 | `"/root/Level_01"` |

### 使用示例

```
# 获取当前场景文件路径（用于日志/存档）
GetScenePath → path_mode: Current Scene File Path
  save_to: scene_path (Local)

# 获取根节点路径
GetScenePath → path_mode: Root Node Path
  save_to: root_path (Local)
```

注意：如果当前场景是从代码动态创建的（非 .tscn 文件），Current Scene File Path 模式可能返回空字符串，此时会输出警告日志。

---

## AddSceneAsChild

将场景实例化并添加为指定父节点的子节点。

**分类:** Scene | **图标:** FileTree

### 参数说明

| 参数 | 类型 | 说明 |
|------|------|------|
| `scene_path` | String | 要实例化的场景文件路径 |
| `target_parent` | NodePath | 父节点路径 |
| `new_node_name` | String | 新节点的名称（空 = 使用场景根节点的默认名称） |

### 使用示例

```
# 生成敌人
AddSceneAsChild → scene_path: "res://scenes/enemies/goblin.tscn"
  target_parent: "/root/Game/EnemyContainer"
  new_node_name: "Goblin_01"

# 在玩家位置生成粒子特效
AddSceneAsChild → scene_path: "res://scenes/effects/explosion.tscn"
  target_parent: "../Effects"
  new_node_name: ""  # 使用默认名称
```

---

## PreloadSceneInstruction

在后台预加载场景资源，避免运行时卡顿。

**分类:** Scene | **图标:** Load

### 预加载模式

| 模式 | 说明 | 适用场景 |
|------|------|----------|
| **Async Now** | 开始异步加载，阻塞等待完成 | 需要立即使用加载结果 |
| **Async Later** | 开始异步加载，立即返回 | 提前预加载，稍后检查状态 |

### 参数说明

| 参数 | 类型 | 说明 |
|------|------|------|
| `scene_path` | String | 场景文件路径 |
| `preload_mode` | PreloadMode | 预加载模式 |
| `timeout` | float | 超时时间（秒），默认 5.0 |
| `status_variable` | String | 保存状态到变量名 |

### 状态值

| 值 | 常量 | 说明 |
|----|------|------|
| 0 | NOT_LOADED | 尚未开始加载 |
| 1 | LOADING | 正在加载中 |
| 2 | LOADED | 加载完成，可以实例化 |
| 3 | FAILED | 加载失败 |
| 4 | TIMEOUT | 加载超时 |

配合 `CheckPreloadStatus` 条件使用，详见 [场景预加载系统](50-scene-preloading-guide.md)。

### 使用示例

```
# 预加载 Boss 场景（立即返回，不阻塞）
PreloadSceneInstruction → scene_path: "res://scenes/boss.tscn"
  preload_mode: Async Later
  status_variable: "boss_load_status"
```

---

## LoadSceneBackground

在后台异步加载场景并保存 PackedScene 到变量，不立即切换或实例化。

**分类:** Scene | **图标:** Load

### 与 PreloadSceneInstruction 的区别

| 特性 | PreloadSceneInstruction | LoadSceneBackground |
|------|------------------------|---------------------|
| 输出 | 加载状态（整数） | PackedScene 资源 |
| 用途 | 检查加载是否完成 | 获取场景资源供后续使用 |
| 检查方式 | 搭配 CheckPreloadStatus 条件 | 指令完成后直接使用变量 |
| 阻塞 | 支持 Async Now 阻塞模式 | 始终异步（轮询模式） |

### 参数说明

| 参数 | 类型 | 说明 |
|------|------|------|
| `scene_path` | String | 场景文件路径 |
| `save_to_variable` | String | 保存 PackedScene 的变量名 |
| `save_to_scope` | VariableScope | 保存作用域（Local/Scope/Global） |

LoadSceneBackground 是异步指令，使用 0.1 秒间隔轮询加载状态，完成后将 PackedScene 保存到指定变量。

### 使用示例

```
# 后台加载场景到变量
LoadSceneBackground → scene_path: "res://scenes/ui/shop.tscn"
  save_to_variable: shop_scene (Local)

# 加载完成后可以用 AddSceneAsChild 或其他指令使用该场景
```

---

## 作用域说明

GetScenePath、PreloadSceneInstruction 和 LoadSceneBackground 的结果保存支持三种作用域：

| 作用域 | 说明 |
|--------|------|
| **Local** | ExecutionContext 上的局部变量（默认） |
| **Scope** | VariableScopeContainer 上的作用域变量 |
| **Global** | 全局变量 |

选择 Scope 时需要额外配置 `scope_source`。

---

## 常见用例

### 1. 关卡切换流程

```
# 玩家到达出口 → 延迟 1 秒后切换
ChangeScene → scene_path: "res://scenes/level_02.tscn", delay: 1.0
```

### 2. 死亡重试

```
# 玩家死亡 → 播放死亡动画 → 延迟后重新加载
On Player Death →
  PlaySound → "res://audio/death.ogg"
  Tween Fade Out → duration: 0.5, auto_free: true  # 淡出死亡特效
  ReloadScene → delay: 2.0
```

### 3. 敌人生成器

```
# 预加载敌人场景
On Game Start →
  PreloadSceneInstruction → scene_path: "res://scenes/enemies/goblin.tscn"
    preload_mode: Async Later
    status_variable: "goblin_status"

# 定时生成
On Timer (每 5 秒) →
  Conditional (CheckPreloadStatus → goblin_status == LOADED)
    then:
      GetRandomPointInRange → 2D, origin: (0, 0), range: (300, 200)
        save_to: spawn_pos
      AddSceneAsChild → scene_path: "res://scenes/enemies/goblin.tscn"
        target_parent: "/root/Game/EnemyContainer"
```

### 4. UI 面板按需加载

```
# 打开商店时后台加载
On ShopButton Pressed →
  LoadSceneBackground → scene_path: "res://scenes/ui/shop.tscn"
    save_to_variable: shop_scene (Local)
  # 加载完成后 shop_scene 变量中为 PackedScene，可供后续使用
```

### 5. 场景路径用于存档

```
# 保存当前关卡路径
GetScenePath → path_mode: Current Scene File Path
  save_to: current_level (Global)

# 后续读取并切换到存档关卡
ChangeScene → scene_path: VARIABLE (current_level)
```

---

## 注意事项

- `scene_path` 必须使用 `res://` 协议的完整路径
- ChangeScene 和 ReloadScene 会销毁当前场景树，确保在切换前保存所有需要持久化的数据
- PreloadSceneInstruction 的 `scene_path` 和 `status_variable` 在检查状态时必须完全一致
- AddSceneAsChild 的 `target_parent` 路径是相对于指令所在节点的 NodePath，不是绝对路径
- LoadSceneBackground 加载完成后，变量中存储的是 PackedScene 资源引用，可以用 `AddSceneAsChild` 或代码进一步处理
- 大型场景建议使用 PreloadSceneInstruction 或 LoadSceneBackground 提前加载，避免运行时卡顿

---

**相关文档:**
- [场景预加载系统](50-scene-preloading-guide.md) - PreloadSceneInstruction 和 CheckPreloadStatus 的详细使用流程
- [表达式系统使用指南](05-expression-guide.md) - 表达式条件与变量操作
