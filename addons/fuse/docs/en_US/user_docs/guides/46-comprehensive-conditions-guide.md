> 🌐 [**中文版**](../../../zh_CN/user_docs/guides/46-comprehensive-conditions-guide.md) | English

# Comprehensive Conditions Collection

## Overview

This guide collects **9 subcategories and 14 conditions**, covering distance, math, navigation, rendering, scope, string, system, scene, UI, and more. Each subcategory has few conditions (1-2 per category), so they are merged into a single guide as a quick reference.

| Subcategory | Count | Conditions | Source path |
|------|--------|---------|-----------|
| distance | 1 | CheckDistance | `conditions/distance/check_distance.gd` |
| math | 1 | ExpressionCondition | `conditions/math/expression_condition.gd` |
| navigation | 1 | CheckPathAvailable | `conditions/navigation/check_path_available.gd` |
| rendering | 1 | CheckIsOnScreen | `conditions/rendering/check_is_on_screen.gd` |
| scope | 1 | CheckScopeVariable | `conditions/scope/check_scope_variable.gd` |
| string | 2 | CheckStringContains, CheckStringLength | `conditions/string/check_string_*.gd` |
| system | 2 | CheckFrameRate, CheckPlatform | `conditions/system/check_*.gd` |
| scene | 1 | CheckPreloadStatus | `conditions/scene/check_preload_status.gd` |
| ui | 1 | CheckUIVisible | `conditions/ui/check_ui_visible.gd` |

**Supplement: non-core conditions of the variable category** (core variable comparison is covered in `01-variable-system-guide.md`):

| Supplement | Count | Conditions |
|------|--------|---------|
| variable supplement | 3 | CheckVector2VariableAxis, CheckHealthValue, CompareHealthThreshold |

---

## Distance and Navigation

### CheckDistance

**File:** `conditions/distance/check_distance.gd`
**class_name:** CheckDistance

Checks whether the distance between two nodes or positions satisfies a condition.

| Parameter | Type | Description |
|------|------|------|
| `source` | NodePath | The source node |
| `target` | NodePath | The target node (mutually exclusive with `target_position`) |
| `target_position` | Vector3 | The target position |
| `operator` | CompareOperator | The comparison operator |
| `value` | float | The distance value to compare against |
| `use_3d` | bool | Whether to use 3D distance calculation |

**Example:** Detect an approaching enemy

```
CheckDistance → source: Player, target: Enemy, operator: LESS_THAN, value: 10.0
├── true → (enemy approaching, switch to the combat state)
└── false → (distance is safe)
```

### CheckPathAvailable

**File:** `conditions/navigation/check_path_available.gd`
**class_name:** CheckPathAvailable

Checks whether a NavigationAgent2D/3D has a valid path to the target position.

| Parameter | Type | Description |
|------|------|------|
| `agent_node` | NodePath | The NavigationAgent node path |
| `target_position` | Vector2 | The target position |

**Example:** AI pathfinding check

```
CheckPathAvailable → agent_node: EnemyNavAgent, target_position: (100, 200)
├── true → (the target position is reachable, start chasing)
└── false → (path unreachable, switch to patrol mode)
```

---

## Math Expressions

### ExpressionCondition

**File:** `conditions/math/expression_condition.gd`
**class_name:** ExpressionCondition

Evaluates a boolean expression using the GDScript `Expression` evaluation engine. Supports variable references.

| Parameter | Type | Description |
|------|------|------|
| `expression` | String | The GDScript boolean expression (e.g. `"a > b && c <= 10"`) |
| `variable_bindings` | Dictionary | Variable bindings, mapping variable names to the names used in the expression |

**Example:** Complex condition check

```
ExpressionCondition → expression: "health > 50 && has_weapon == true", variable_bindings: {"health": {scope:player_health}, "has_weapon": {local:weapon_equipped}}
├── true → (plenty of health and armed, play aggressively)
└── false → (play conservatively)
```

---

## Rendering and UI

### CheckIsOnScreen

**File:** `conditions/rendering/check_is_on_screen.gd`
**class_name:** CheckIsOnScreen

Checks whether the node is within the visible area of the current viewport.

| Parameter | Type | Description |
|------|------|------|
| `target_node` | NodePath | The target node |
| `expected_on_screen` | bool | The expected on-screen state |

**Example:** Recycle after the enemy leaves the screen

```
CheckIsOnScreen → target_node: EnemyProjectile, expected_on_screen: false
├── true → (the projectile has left the screen, recycle it)
└── false → (still on screen)
```

### CheckUIVisible

**File:** `conditions/ui/check_ui_visible.gd`
**class_name:** CheckUIVisible

Checks the visibility state of a UI element (CanvasItem.visible). It has no external "expected value" parameter and directly evaluates the current visibility.

| Parameter | Type | Description |
|------|------|------|
| `target_node` | NodePath | The target UI node (CanvasItem/Control type) |

**Example:** Block actions while a menu is open

```
CheckUIVisible → target_node: "UI/PauseMenu"
├── true → (the pause menu is open, ignore in-game input)
└── false → (the menu is closed, the game runs normally)
```

---

## Scope and Variables

### CheckScopeVariable

**File:** `conditions/scope/check_scope_variable.gd`
**class_name:** CheckScopeVariable

Checks whether a variable value in a scope satisfies a condition.

| Parameter | Type | Description |
|------|------|------|
| `variable_name` | String | The scope variable name |
| `scope_source` | ScopeSource | The scope source |
| `operator` | CompareOperator | The comparison operator |
| `value` | Variant | The value to compare against |

**Example:** Check a parameter in the Trigger scope

```
CheckScopeVariable → variable_name: "interactable_type", scope_source: TRIGGER_SCOPE, operator: EQUALS, value: "door"
├── true → (interacting with a door, run the door-opening logic)
└── false → CheckScopeVariable → variable_name: "interactable_type", operator: EQUALS, value: "item"
    └── true → (pick up the item)
```

### CheckVector2VariableAxis

**File:** `conditions/variable/check_vector2_variable_axis.gd`
**class_name:** CheckVector2VariableAxis

Checks whether the specified axis (X or Y) of a Vector2 variable satisfies a condition.

| Parameter | Type | Description |
|------|------|------|
| `variable_name` | String | The Vector2 variable name |
| `variable_scope` | ScopeSource | The variable scope |
| `axis` | AxisType | Axis selection: `X` or `Y` |
| `operator` | CompareOperator | The comparison operator |
| `value` | float | The value to compare against |

**Example:** Check the horizontal component of the move direction

```
CheckVector2VariableAxis → variable_name: "move_direction", variable_scope: LOCAL, axis: X, operator: GREATER_THAN, value: 0.0
├── true → (moving right)
└── false → (moving left or stationary)
```

### CheckHealthValue

**File:** `conditions/variable/check_health_value.gd`
**class_name:** CheckHealthValue

Checks whether the health value in the specified variable equals the target value. The health value is looked up by variable name and scope.

| Parameter | Type | Description |
|------|------|------|
| `health_variable` | String | The health variable name |
| `variable_scope` | VariableScope | The variable scope (Local/Scope/Global) |
| `target_value` | float | The target value to compare against |

**Example:** Low health warning

```
CheckHealthValue → health_variable: "player_hp", variable_scope: LOCAL, target_value: 30.0
├── true → (health equals 30, trigger the low-health effect)
└── false → (health does not equal the target value)
```

### CompareHealthThreshold

**File:** `conditions/variable/compare_health_threshold.gd`
**class_name:** CompareHealthThreshold

Compares the current health value against a single threshold, using a comparison operator to determine the relationship. Returns a boolean.

| Parameter | Type | Description |
|------|------|------|
| `health_variable` | String | The health variable name |
| `variable_scope` | VariableScope | The variable scope (Local/Scope/Global) |
| `threshold` | float | The threshold to compare against |
| `comparison_operator` | int | The comparison operator: 0=less than, 1=greater than, 2=less than or equal, 3=greater than or equal, 4=equals |

**Example:** Boss phase check

```
CompareHealthThreshold → health_variable: "boss_hp", variable_scope: LOCAL, threshold: 30.0, comparison_operator: 0
├── true → (health below 30%, final phase)
└── false → (health not below the threshold)
```

---

## Strings

### CheckStringContains

**File:** `conditions/string/check_string_contains.gd`
**class_name:** CheckStringContains

Checks whether a string contains the specified substring.

| Parameter | Type | Description |
|------|------|------|
| `source_variable` | String | The source string variable name |
| `search` | String | The substring to look for |
| `case_sensitive` | bool | Whether the check is case-sensitive |

**Example:** Dialogue option matching

```
CheckStringContains → source_variable: "player_input", search: "key", case_sensitive: false
├── true → (the player input contains "key", trigger key-related dialogue)
└── false → (keyword not found)
```

### CheckStringLength

**File:** `conditions/string/check_string_length.gd`
**class_name:** CheckStringLength

Checks whether a string length satisfies a condition.

| Parameter | Type | Description |
|------|------|------|
| `source_variable` | String | The source string variable name |
| `compare_type` | CompareType | The comparison type (EQUAL/NOT_EQUAL/GREATER/LESS/GREATER_EQUAL/LESS_EQUAL) |
| `threshold` | int | The threshold length |

**Example:** Input validation

```
CheckStringLength → source_variable: "player_name", compare_type: GREATER, threshold: 0
├── true → (the player has entered a name)
└── false → (name is empty, prompt for input)
```

---

## System and Scene

### CheckFrameRate

**File:** `conditions/system/check_frame_rate.gd`
**class_name:** CheckFrameRate

Checks whether the current frame rate satisfies a threshold condition. Can be used to adjust graphics quality automatically.

| Parameter | Type | Description |
|------|------|------|
| `compare_type` | CompareType | The comparison type (EQUAL/NOT_EQUAL/GREATER/LESS/GREATER_EQUAL/LESS_EQUAL) |
| `threshold_fps` | float | The frame rate threshold (FPS) |

**Example:** Dynamic quality adjustment

```
CheckFrameRate → compare_type: LESS, threshold_fps: 30.0
├── true → (frame rate below 30, lower the quality settings)
└── false → (frame rate normal)
```

### CheckPlatform

**File:** `conditions/system/check_platform.gd`
**class_name:** CheckPlatform

Checks the current runtime platform. Suitable for platform-specific conditional branches.

| Parameter | Type | Description |
|------|------|------|
| `platform` | PlatformType | The target platform: `WINDOWS`, `LINUX`, `MACOS`, `ANDROID`, `IOS`, `WEB` |

**Example:** Platform adaptation

```
CheckPlatform → platform: MOBILE
├── true → (mobile, use the touch UI scheme)
└── false → (desktop, use the keyboard-and-mouse scheme)
```

### CheckPreloadStatus

**File:** `conditions/scene/check_preload_status.gd`
**class_name:** CheckPreloadStatus

Checks the status of scene preloading (`ScenePreloader`).

| Parameter | Type | Description |
|------|------|------|
| `scene_path` | String | The scene path |
| `status` | PreloadStatus | The status to check: `LOADING` (loading), `COMPLETE` (complete), `FAILED` (failed) |

**Example:** Change scene once preloading completes

```
CheckPreloadStatus → scene_path: "res://levels/boss_level.tscn", status: COMPLETE
├── true → (preloading complete, change to that scene)
└── false → CheckPreloadStatus → scene_path: "res://levels/boss_level.tscn", status: LOADING
    └── true → (still loading, show a progress bar)
```

---

## Common Use Cases

### Enemy proximity detection (Distance + navigation)

```
OnInterval → interval_seconds: 2.0
├── CheckDistance → source: Enemy, target: Player, operator: LESS_THAN, value: 15.0
│   └── true → CheckPathAvailable → agent_node: EnemyNavAgent, target_position: (100, 200)
│       ├── true → (start chasing the player)
│       └── false → CheckIsOnScreen → target_node: Enemy, expected_on_screen: true
│           └── true → (visible but unreachable, approach another way)
```

### Input validation + UI visibility

```
Trigger: OnInputAction → action_name: "submit_name"
├── CheckUIVisible → target_node: "UI/NameInput"
│   └── true → CheckStringLength → source_variable: "input_text", compare_type: GREATER, threshold: 0
│       ├── true → CheckStringContains → source_variable: "input_text", search: "admin"
│       │   ├── true → (admin command handling)
│       │   └── false → (a regular player name, save and continue)
│       └── false → (name is empty, show an error)
```

### Dynamic quality adjustment (CheckFrameRate + CheckPlatform)

```
OnInterval → interval_seconds: 10.0
├── CheckFrameRate → compare_type: LESS, threshold_fps: 30.0
│   └── true → (low frame rate mode)
│       ├── (lower shadow quality)
│       └── (disable post-processing effects)
└── CheckPlatform → platform: MOBILE
    └── true → (mobile defaults to the medium quality preset)
```

---

## Notes

0. **Node path or variable:** conditions with NodePath parameters (such as CheckDistance and CheckIsOnScreen) support both hard-coded node paths and node references passed dynamically through variables (Scope/Local/Global), flexibly fitting different scenarios.
1. **CheckIsOnScreen depends on the viewport:** the node must be inside the currently active viewport and not fully occluded by other nodes.
2. **CheckPathAvailable requires a NavigationAgent:** the target node must be a NavigationAgent2D/3D.
3. **CheckPreloadStatus requires ScenePreloader:** the scene must already have started loading via `ScenePreloader` or the scene preload instruction.
4. **ExpressionCondition only supports boolean results:** the expression must ultimately return `true` or `false`. Non-boolean return values are not supported.
5. **Distance cost:** `CheckDistance` computes the Euclidean distance on every call; consider lowering the call frequency under heavy use.

**Topics covered by related docs (not repeated here):**
- Core variable comparison (`CompareVariable`, `CheckVariable`) → see `01-variable-system-guide.md`
- Composite conditions (`CheckAll`, `CheckAny`, `CheckNot`, `CheckComposite`) → see `composite-conditions-guide.md`
- Array conditions → see `array-operations-guide.md`
- Dictionary conditions → see `dictionary-operations-guide.md`
