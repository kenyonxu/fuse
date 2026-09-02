> 🌐 [**中文版**](../../../zh_CN/user_docs/guides/42-physics-conditions-guide.md) | English

# Physics Conditions Guide

## Overview

Physics conditions evaluate the physical state of a `CharacterBody` — on floor/wall/in air, falling/velocity, slope angle, area overlaps, and more. **7 conditions** in total, located in the `conditions/physics/` directory.

| Condition | class_name | Function | Underlying method |
|------|-----------|------|----------|
| CheckOnFloor | CheckOnFloor | Detects whether on the floor | `is_on_floor()` |
| CheckOnWall | CheckOnWall | Detects whether on a wall | `is_on_wall()` |
| CheckInAir | CheckInAir | Detects whether in the air (not on a wall or the floor) | `!is_on_floor() && !is_on_wall()` |
| CheckIsFalling | CheckIsFalling | Detects whether currently falling | Vertical velocity < threshold |
| CheckVelocity | CheckVelocity | Velocity comparison | `velocity` |
| CheckSlope | CheckSlope | Slope angle comparison | `get_floor_normal()` |
| CheckOverlapArea | CheckOverlapArea | Area overlap detection | `overlaps_area()`/`overlaps_body()` |

> **Note:** these conditions must act on `CharacterBody2D` / `CharacterBody3D` nodes (or classes inheriting from CharacterBody), otherwise methods such as `is_on_floor()` will not return valid results.

---

## Floor / Wall / Air

### CheckOnFloor

**File:** `conditions/physics/check_on_floor.gd`
**class_name:** CheckOnFloor

Detects whether the target CharacterBody is standing on the floor. Calls `is_on_floor()` under the hood.

| Parameter | Type | Description |
|------|------|------|
| `target_node` | NodePath | The target character node |

**Example:** Jump check

```
CheckOnFloor → target_node: Player
├── true → CheckInputPressed → action_name: "jump"
│   └── true → (perform the jump)
└── false → (in the air, cannot jump)
```

### CheckOnWall

**File:** `conditions/physics/check_on_wall.gd`
**class_name:** CheckOnWall

Detects whether the target CharacterBody is against a wall. Calls `is_on_wall()` under the hood.

| Parameter | Type | Description |
|------|------|------|
| `target_node` | NodePath | The target character node |

**Example:** Wall-climb check

```
CheckOnWall → target_node: Player
├── true → CheckInputHeld → action_name: "climb"
│   └── true → (enter the wall-climbing state)
└── false → (not touching a wall)
```

### CheckInAir

**File:** `conditions/physics/check_in_air.gd`
**class_name:** CheckInAir

Detects whether the target CharacterBody is in the air (not on a wall, not on the floor).

| Parameter | Type | Description |
|------|------|------|
| `target_node` | NodePath | The target character node |

**Example:** Double jump in mid-air

```
CheckInAir → target_node: Player
├── true → CheckInputPressed → action_name: "jump"
│   └── true → (perform the double jump)
└── false → (on the floor, normal jump)
```

---

## Falling and Velocity

### CheckIsFalling

**File:** `conditions/physics/check_is_falling.gd`
**class_name:** CheckIsFalling

Detects whether the character is currently falling (vertical velocity is negative and below the threshold).

| Parameter | Type | Default | Description |
|------|------|--------|------|
| `target_node` | NodePath | — | The target character node |
| `fall_threshold` | float | -0.1 | The falling threshold (vertical velocity below this counts as falling) |

> **CheckInAir vs CheckIsFalling:** being in the air (CheckInAir = true) does not mean descending — it may be the rising phase of a jump. Combining the two distinguishes rising/falling states.

**Example:** Fall acceleration

```
CheckIsFalling → target_node: Player, fall_threshold: -0.5
├── true → (adjust the fall speed or animation)
└── false → (not falling)
```

### CheckVelocity

**File:** `conditions/physics/check_velocity.gd`
**class_name:** CheckVelocity

Checks whether the CharacterBody's velocity satisfies a condition, supporting scalar or vector comparison.

| Parameter | Type | Description |
|------|------|------|
| `target_node` | NodePath | The target character node |
| `check_type` | CheckType | Check type: `SCALAR` (speed magnitude), `X` (X-axis component), `Y` (Y-axis component), `Z` (Z-axis component) |
| `operator` | CompareOperator | The comparison operator |
| `value` | float | The value to compare against |

**Example:** Dash speed check

```
CheckVelocity → target_node: Player, check_type: SCALAR, operator: GREATER_THAN, value: 500.0
├── true → (dashing, switch to the dash animation)
└── false → (normal speed)
```

---

## Slope and Area

### CheckSlope

**File:** `conditions/physics/check_slope.gd`
**class_name:** CheckSlope

Checks whether the slope angle of the surface the character stands on satisfies a condition. Computed via `get_floor_normal()` under the hood.

| Parameter | Type | Default | Description |
|------|------|--------|------|
| `target_node` | NodePath | — | The target character node |
| `operator` | CompareOperator | — | The angle comparison operator |
| `angle` | float | — | The slope angle (degrees) |

**Example:** Slide check (slope over 45° triggers a slide)

```
CheckSlope → target_node: Player, operator: GREATER_THAN, angle: 45.0
├── true → CheckInputHeld → action_name: "move_down"
│   └── true → (sliding down the steep slope)
└── false → (walking normally)
```

### CheckOverlapArea

**File:** `conditions/physics/check_overlap_area.gd`
**class_name:** CheckOverlapArea

Detects whether an Area2D/Area3D overlaps other collision bodies or Areas. Calls `get_overlapping_bodies()` / `get_overlapping_areas()` under the hood. **No `check_type` enum**; it always checks overlaps against both bodies and areas.

| Parameter | Type | Description |
|------|------|------|
| `area_node` | NodePath | The Area2D/Area3D node to check |
| `check_group` | String | Filters overlapping bodies by group (empty = no filtering) |
| `save_to_variable` | String | Saves the list of overlapping bodies to a local variable (empty = do not save) |

**Example:** Detect whether the player entered a hazard area

```
CheckOverlapArea → area_node: "Hazards/LavaArea"
├── true → (overlapping bodies present, trigger damage)
└── false → (safe)
```

---

## Common Use Cases

### Jump Check (OnFloor)

```
OnPhysicsProcess
├── CheckOnFloor → target_node: Player
│   ├── true → CheckInputPressed → action_name: "jump"
│   │   └── true → (perform the jump, set velocity.y = jump_velocity)
│   └── false → (in the air)
└── MoveCharacterBody → target_node: Player
```

### Double Jump (InAir + Velocity)

```
OnPhysicsProcess
├── CheckOnFloor → target_node: Player
│   └── true → SetVariable → scope: LOCAL, name: "jumps_left", value: 2
├── CheckInAir → target_node: Player
│   └── true → CheckInputPressed → action_name: "jump"
│       └── → CheckVariable → name: "jumps_left", operator: GREATER_THAN, value: 0
│           └── true → (double jump, jumps_left -= 1)
```

### Wall-Climb Check (OnWall + directional input)

```
OnPhysicsProcess
├── CheckOnWall → target_node: Player
│   └── true → CheckInputHeld → action_name: "climb"
│       └── true → (stop horizontal movement, enter the wall-climbing state)
└── (otherwise move normally)
```

### Slide Check (Slope angle)

```
OnPhysicsProcess
├── CheckOnFloor → target_node: Player
│   └── true → CheckSlope → target_node: Player, operator: GREATER_THAN, angle: 50.0
│       └── true → CheckInputHeld → action_name: "move_down"
│           └── true → (slide mode, switch animation and collision shape)
```

---

## Notes

0. **Node path or variable:** all conditions with NodePath parameters (such as CheckOnFloor and CheckVelocity) support both hard-coded node paths and node references passed dynamically through variables.
1. **CheckInAir vs CheckIsFalling:** the two are not equivalent. `CheckInAir` means "not touching any surface"; `CheckIsFalling` means "currently falling". During the rising phase of a jump `InAir = true` but `IsFalling = false`.
2. **Depends on `move_and_slide()`:** all CharacterBody floor/wall checks rely on the results of `move_and_slide()`. If the character does not call `move_and_slide()`, these conditions will be inaccurate.
3. **CheckOverlapArea requires an Area node:** the target `area_node` must be an `Area2D` / `Area3D` type (or inherit from Area); a bare CollisionShape does not trigger overlap detection.
4. **Slope angle units:** the `angle` parameter of `CheckSlope` uses **degrees** (0-90), not radians.
