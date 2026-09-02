> 🌐 [**中文版**](../../../zh_CN/user_docs/guides/50-scene-preloading-guide.md) | English

# Scene Preloading System

Fuse provides scene preloading: `PreloadSceneInstruction` and `CheckPreloadStatus` work together to load scenes asynchronously and avoid hitches while the game is running.

## Component Overview

| Component | Type | Purpose |
|------|------|------|
| PreloadSceneInstruction | Instruction | Starts loading a scene asynchronously |
| CheckPreloadStatus | Condition | Checks the loading status |

## PreloadSceneInstruction

Loads a scene in the background using `ResourceLoader.load_threaded_request()`.

**File:** [preload_scene_instruction.gd](../../../../instructions/scene/preload_scene_instruction.gd)
**Category:** Scene
**Icon:** Load

### Preload Modes

| Mode | Description |
|------|------|
| Async Now | Starts async loading immediately and blocks until it completes |
| Async Later | Starts async loading and returns immediately (non-blocking) |

### Properties

| Property | Type | Description |
|------|------|------|
| scene_path | String | The scene resource path (.tscn) |
| preload_mode | PreloadMode | The preload mode |
| timeout | float | Timeout in seconds, default 5.0 |
| status_variable | String | Variable name to save the status to |

### Status Values

The loading status is saved to the specified variable with the following values:

| Value | Constant | Description |
|----|------|------|
| 0 | NOT_LOADED | Loading has not started |
| 1 | LOADING | Loading in progress |
| 2 | LOADED | Loading complete, ready to instantiate |
| 3 | FAILED | Loading failed |
| 4 | TIMEOUT | Loading timed out |

---

## CheckPreloadStatus

Checks the scene preloading status.

**File:** [check_preload_status.gd](../../../../conditions/scene/check_preload_status.gd)
**Category:** Scene
**Icon:** Load

### Properties

| Property | Type | Description |
|------|------|------|
| scene_path | String | The scene path to check |
| expected_status | PreloadStatus | The expected status |
| status_variable | String | The status variable name |

### Prerequisites

`PreloadSceneInstruction` must have started the preload first, with the same `scene_path` and `status_variable` passed in.

---

## Workflow

### 1. Start preloading

```
Instruction: PreloadSceneInstruction
scene_path: "res://scenes/enemy.tscn"
preload_mode: Async Later
status_variable: "enemy_preload_status"
```

### 2. Check the loading status

```
Condition: CheckPreloadStatus
scene_path: "res://scenes/enemy.tscn"
expected_status: LOADED
status_variable: "enemy_preload_status"
```

### 3. Instantiate after loading completes

Use `CheckPreloadStatus` as the condition; once loading completes, instantiate with `AddSceneAsChild`:

```
Condition: CheckPreloadStatus (expected_status: LOADED)
└── Instruction: AddSceneAsChild
    scene_path: "res://scenes/enemy.tscn"
    parent_path: "." (the current node)
    position: (0, 0)
```

---

## Complete Examples

### Enemy preloading

Preload the enemy scene before the player enters the combat area:

```
Trigger: AreaTrigger (on_body_entered)
│
├── PreloadSceneInstruction
│   scene_path: "res://scenes/enemy.tscn"
│   preload_mode: Async Later
│   status_variable: "enemy_preload_status"
│
└── (the follow-up check runs in another Trigger)
```

Another Trigger checks the status every frame:

```
Trigger: OnProcess (every frame)
│
└── Conditional (CheckPreloadStatus)
    condition: {status_variable} == LOADED
    then:
    │   └── AddSceneAsChild
    │       scene_path: "res://scenes/enemy.tscn"
    │       parent_path: "." (the Spawner node)
    │       position: (100, 0)
    └──
        └── (keep waiting)
```

### UI resource preloading

Preload multiple UI scenes:

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

## Timeout Handling

If loading takes too long (5 seconds by default), the status becomes `TIMEOUT`.

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
│   │       message: "Scene loading timed out"
```

---

## Notes

- `scene_path` must match exactly for the status check to work correctly
- Use a meaningful name for `status_variable` to avoid conflicts
- The Async Later mode is non-blocking, suitable for preloading while the game is running
- Once loading completes the scene is already cached; `add_to_cache` avoids redundant loads

---

**Related docs:**
- [Scene management instructions](../best_practices/custom_instruction.md)
- [Async loading best practices](../best_practices/)
