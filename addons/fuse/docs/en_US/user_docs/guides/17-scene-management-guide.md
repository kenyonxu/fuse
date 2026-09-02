> 🌐 [**中文版**](../../../zh_CN/user_docs/guides/17-scene-management-guide.md) | English

# Scene Management Instructions Usage Guide

The Fuse scene management system provides 6 instructions covering the full scene operation chain: scene switching, reloading, scene path retrieval, child instantiation, preloading, and background loading.

## Instruction List

| Name | Description | Key parameters |
|------|----------|----------|
| **ChangeScene** | Switch to a new scene | `scene_path` (target scene path), `delay` (delay in seconds) |
| **ReloadScene** | Reload the current scene | `delay` (delay in seconds) |
| **GetScenePath** | Get the current scene path | `path_mode` (scene file path / root node path), `save_to_variable` |
| **AddSceneAsChild** | Instantiate a scene as a child node | `scene_path` (scene path), `target_parent` (parent node path), `new_node_name` (node name) |
| **PreloadSceneInstruction** | Preload a scene in the background | `scene_path` (scene path), `preload_mode` (Async Now/Async Later), `status_variable` (status variable) |
| **LoadSceneBackground** | Load a scene into a variable asynchronously | `scene_path` (scene path), `save_to_variable` (variable name that stores the PackedScene) |

---

## ChangeScene

Switch to the specified scene, with optional delayed switching.

**Category:** Scene Management | **Icon:** PlayCustom

### Parameters

| Parameter | Type | Description |
|------|------|------|
| `scene_path` | String | Target scene file path (.tscn/.scn) |
| `delay` | float | Delay before switching (seconds), default 0, range 0-10 |

### Usage Examples

```
# Switch to the game scene immediately
ChangeScene → scene_path: "res://scenes/game.tscn", delay: 0.0

# Switch to the main menu after a 2-second delay (pair with animations)
ChangeScene → scene_path: "res://scenes/main_menu.tscn", delay: 2.0
```

ChangeScene is an asynchronous instruction — when a delay is set, it waits for the countdown to finish before completing.

---

## ReloadScene

Reload the current scene; suited to retry/restart scenarios.

**Category:** Scene | **Icon:** Reload

### Parameters

| Parameter | Type | Description |
|------|------|------|
| `delay` | float | Delay time (seconds), default 0, range 0-3600 |

### Usage Examples

```
# Reload the current scene immediately
ReloadScene → delay: 0.0

# Reload 3 seconds after the player dies
ReloadScene → delay: 3.0
```

---

## GetScenePath

Get the current scene's path information and save it to a variable.

**Category:** Scene | **Icon:** Tree

### Path Modes

| Mode | Description | Example return value |
|------|------|------------|
| **Current Scene File Path** | Scene file path | `"res://scenes/level_01.tscn"` |
| **Root Node Path** | Path of the root node in the scene tree | `"/root/Level_01"` |

### Usage Examples

```
# Get the current scene file path (for logging/save games)
GetScenePath → path_mode: Current Scene File Path
  save_to: scene_path (Local)

# Get the root node path
GetScenePath → path_mode: Root Node Path
  save_to: root_path (Local)
```

Note: if the current scene was created dynamically from code (not from a .tscn file), the Current Scene File Path mode may return an empty string, and a warning is logged in that case.

---

## AddSceneAsChild

Instantiate a scene and add it as a child of the specified parent node.

**Category:** Scene | **Icon:** FileTree

### Parameters

| Parameter | Type | Description |
|------|------|------|
| `scene_path` | String | Scene file path to instantiate |
| `target_parent` | NodePath | Parent node path |
| `new_node_name` | String | Name of the new node (empty = use the scene root node's default name) |

### Usage Examples

```
# Spawn an enemy
AddSceneAsChild → scene_path: "res://scenes/enemies/goblin.tscn"
  target_parent: "/root/Game/EnemyContainer"
  new_node_name: "Goblin_01"

# Spawn particle effects at the player's position
AddSceneAsChild → scene_path: "res://scenes/effects/explosion.tscn"
  target_parent: "../Effects"
  new_node_name: ""  # 使用默认名称
```

---

## PreloadSceneInstruction

Preload scene resources in the background to avoid runtime hitches.

**Category:** Scene | **Icon:** Load

### Preload Modes

| Mode | Description | Use case |
|------|------|----------|
| **Async Now** | Starts async loading and blocks until completion | When the loaded result is needed immediately |
| **Async Later** | Starts async loading and returns immediately | Preload ahead of time, check the status later |

### Parameters

| Parameter | Type | Description |
|------|------|------|
| `scene_path` | String | Scene file path |
| `preload_mode` | PreloadMode | Preload mode |
| `timeout` | float | Timeout (seconds), default 5.0 |
| `status_variable` | String | Variable name that stores the status |

### Status Values

| Value | Constant | Description |
|----|------|------|
| 0 | NOT_LOADED | Loading has not started |
| 1 | LOADING | Loading in progress |
| 2 | LOADED | Loading complete, ready to instantiate |
| 3 | FAILED | Loading failed |
| 4 | TIMEOUT | Loading timed out |

Use together with the `CheckPreloadStatus` condition; see [Scene Preloading System (Chinese)](../../../zh_CN/user_docs/guides/50-scene-preloading-guide.md) for details.

### Usage Examples

```
# Preload the Boss scene (returns immediately, non-blocking)
PreloadSceneInstruction → scene_path: "res://scenes/boss.tscn"
  preload_mode: Async Later
  status_variable: "boss_load_status"
```

---

## LoadSceneBackground

Load a scene asynchronously in the background and save the PackedScene to a variable, without switching or instantiating immediately.

**Category:** Scene | **Icon:** Load

### Differences from PreloadSceneInstruction

| Feature | PreloadSceneInstruction | LoadSceneBackground |
|------|------------------------|---------------------|
| Output | Load status (integer) | PackedScene resource |
| Purpose | Check whether loading has finished | Obtain the scene resource for later use |
| How to check | Pair with the CheckPreloadStatus condition | Use the variable directly once the instruction completes |
| Blocking | Supports the Async Now blocking mode | Always asynchronous (polling mode) |

### Parameters

| Parameter | Type | Description |
|------|------|------|
| `scene_path` | String | Scene file path |
| `save_to_variable` | String | Variable name that stores the PackedScene |
| `save_to_scope` | VariableScope | Scope to save into (Local/Scope/Global) |

LoadSceneBackground is an asynchronous instruction that polls the load status at 0.1-second intervals and saves the PackedScene to the specified variable when finished.

### Usage Examples

```
# Load a scene into a variable in the background
LoadSceneBackground → scene_path: "res://scenes/ui/shop.tscn"
  save_to_variable: shop_scene (Local)

# Once loaded, the scene can be used by AddSceneAsChild or other instructions
```

---

## Scope Notes

GetScenePath, PreloadSceneInstruction, and LoadSceneBackground support three scopes for saving their results:

| Scope | Description |
|--------|------|
| **Local** | Local variables on the ExecutionContext (default) |
| **Scope** | Scope variables on the VariableScopeContainer |
| **Global** | Global variables |

Choosing Scope requires additional `scope_source` configuration.

---

## Common Use Cases

### 1. Level Switching Flow

```
# Player reaches the exit → switch after a 1-second delay
ChangeScene → scene_path: "res://scenes/level_02.tscn", delay: 1.0
```

### 2. Death Retry

```
# Player dies → play the death animation → reload after a delay
On Player Death →
  PlaySound → "res://audio/death.ogg"
  Tween Fade Out → duration: 0.5, auto_free: true  # 淡出死亡特效
  ReloadScene → delay: 2.0
```

### 3. Enemy Spawner

```
# Preload the enemy scene
On Game Start →
  PreloadSceneInstruction → scene_path: "res://scenes/enemies/goblin.tscn"
    preload_mode: Async Later
    status_variable: "goblin_status"

# Spawn on a timer
On Timer (every 5 seconds) →
  Conditional (CheckPreloadStatus → goblin_status == LOADED)
    then:
      GetRandomPointInRange → 2D, origin: (0, 0), range: (300, 200)
        save_to: spawn_pos
      AddSceneAsChild → scene_path: "res://scenes/enemies/goblin.tscn"
        target_parent: "/root/Game/EnemyContainer"
```

### 4. On-Demand UI Panel Loading

```
# Load in the background when the shop opens
On ShopButton Pressed →
  LoadSceneBackground → scene_path: "res://scenes/ui/shop.tscn"
    save_to_variable: shop_scene (Local)
  # Once loading completes, the shop_scene variable holds a PackedScene ready for later use
```

### 5. Scene Paths for Save Games

```
# Save the current level path
GetScenePath → path_mode: Current Scene File Path
  save_to: current_level (Global)

# Later, read it back and switch to the saved level
ChangeScene → scene_path: VARIABLE (current_level)
```

---

## Notes

- `scene_path` must be a full path using the `res://` protocol
- ChangeScene and ReloadScene destroy the current scene tree; make sure all data that needs to persist is saved before switching
- PreloadSceneInstruction's `scene_path` and `status_variable` must match exactly when checking the status
- AddSceneAsChild's `target_parent` path is a NodePath relative to the node the instruction runs on, not an absolute path
- After LoadSceneBackground finishes, the variable holds a PackedScene resource reference, which can be processed further with `AddSceneAsChild` or code
- For large scenes, preload them ahead of time with PreloadSceneInstruction or LoadSceneBackground to avoid runtime hitches

---

**Related docs:**
- [Scene Preloading System (Chinese)](../../../zh_CN/user_docs/guides/50-scene-preloading-guide.md) - Detailed usage flow of PreloadSceneInstruction and CheckPreloadStatus
- [Expression System Usage Guide](05-expression-guide.md) - Expression conditions and variable operations
