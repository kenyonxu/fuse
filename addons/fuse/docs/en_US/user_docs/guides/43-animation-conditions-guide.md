> 🌐 [**中文版**](../../../zh_CN/user_docs/guides/43-animation-conditions-guide.md) | English

# Animation Conditions Guide

## Overview

Animation conditions evaluate animation playback state and AnimationTree states in flow control. **5 conditions** in total, located in the `conditions/animation/` directory.

| Category | Condition | class_name | Description |
|------|------|-----------|------|
| Playback state | CheckIsPlaying | CheckIsPlaying | Whether any animation is currently playing |
| Playback state | CheckIsAnimation | CheckIsAnimation | Whether the animation currently playing is the specified one |
| Playback state | CheckAnimationFinished | CheckAnimationFinished | Whether the specified animation has finished playing |
| AnimationTree | CheckAnimationTreeState | CheckAnimationTreeState | Whether the state machine node is in the specified state |
| AnimationTree | CheckAnimationTreeParameter | CheckAnimationTreeParameter | State machine parameter check |

---

## Playback State Checks

### CheckIsPlaying

**File:** `conditions/animation/check_is_playing.gd`
**class_name:** CheckIsPlaying

Checks whether the specified AnimationPlayer currently has an animation playing.

| Parameter | Type | Description |
|------|------|------|
| `target` | NodePath | The AnimationPlayer node path |
| `expected_state` | bool | The expected playback state |

**Example:** Do not interrupt while playing

```
CheckIsPlaying → target: "Player/AnimationPlayer", expected_state: true
├── true → (animation playing, do not interrupt)
└── false → (idle, a new animation can be played)
```

### CheckIsAnimation

**File:** `conditions/animation/check_is_animation.gd`
**class_name:** CheckIsAnimation

Checks whether the animation currently playing is the specified animation name.

| Parameter | Type | Description |
|------|------|------|
| `target` | NodePath | The AnimationPlayer node path |
| `animation_name` | String | The animation name |

**Example:** Switch skills based on animation state

```
CheckIsAnimation → target: "Player/AnimationPlayer", animation_name: "attack_slash"
├── true → (slash animation playing, combo input allowed)
└── false → CheckIsAnimation → target: "Player/AnimationPlayer", animation_name: "idle"
    └── true → (idle state, any attack allowed)
```

### CheckAnimationFinished

**File:** `conditions/animation/check_animation_finished.gd`
**class_name:** CheckAnimationFinished

Checks whether the specified animation has finished playing.

| Parameter | Type | Description |
|------|------|------|
| `target` | NodePath | The AnimationPlayer node path |
| `animation_name` | String | The animation name |

**Example:** Move only after the attack recovery ends

```
CheckAnimationFinished → target: "Player/AnimationPlayer", animation_name: "attack_heavy"
├── true → (attack animation finished, movement control restored)
└── false → (animation not finished, movement locked)
```

---

## AnimationTree Integration

### CheckAnimationTreeState

**File:** `conditions/animation/check_animation_tree_state.gd`
**class_name:** CheckAnimationTreeState

Checks whether the `StateMachine` node of an AnimationTree is in the specified state.

| Parameter | Type | Description |
|------|------|------|
| `animation_tree` | NodePath | The AnimationTree node path |
| `state_machine_path` | String | The state machine node path (e.g. `"parameters/StateMachine"`) |
| `state_name` | String | The expected state name |

**Example:** AI behavior driver

```
CheckAnimationTreeState → animation_tree: "Enemy/AnimationTree", state_machine_path: "parameters/StateMachine", state_name: "attack"
├── true → (the AI is in the attack state, execute attack behavior)
└── false → CheckAnimationTreeState → animation_tree: "Enemy/AnimationTree", state_machine_path: "parameters/StateMachine", state_name: "chase"
    └── true → (chase state, move toward the player)
```

### CheckAnimationTreeParameter

**File:** `conditions/animation/check_animation_tree_parameter.gd`
**class_name:** CheckAnimationTreeParameter

Checks whether the specified AnimationTree parameter value satisfies a condition. Suitable for checking parameters such as blend position.

| Parameter | Type | Description |
|------|------|------|
| `animation_tree` | NodePath | The AnimationTree node path |
| `parameter_path` | String | The parameter path (e.g. `"parameters/blend_position"`) |
| `operator` | CompareOperator | The comparison operator |
| `value` | float | The value to compare against |

**Example:** Blend direction check

```
CheckAnimationTreeParameter → animation_tree: "Player/AnimationTree", parameter_path: "parameters/blend_position", operator: GREATER_THAN, value: 0.5
├── true → (blend leans right, trigger the right-side animation set)
└── false → (blend leans left, trigger the left-side animation set)
```

---

## Common Use Cases

### Move only after the attack animation finishes

```
OnInputAction → action_name: "move"
├── CheckIsPlaying → target: "Player/AnimationPlayer", expected_state: true
│   └── true → CheckAnimationFinished → target: "Player/AnimationPlayer", animation_name: "attack_heavy"
│       ├── true → (animation finished, handle the move input)
│       └── false → (animation still playing, ignore the move input)
└── false → (no animation playing, move directly)
```

### Switch skills based on animation state

```
OnInputAction → action_name: "skill_1"
├── CheckIsAnimation → target: "Player/AnimationPlayer", animation_name: "idle"
│   └── true → (cast skill 1)
├── CheckIsAnimation → target: "Player/AnimationPlayer", animation_name: "attack_combo_1"
│   └── true → (chain skill 1's combo)
└── (casting not allowed in other states)
```

### AnimationTree state machine driven AI behavior

```
OnInterval → interval_seconds: 0.5
├── CheckAnimationTreeState → animation_tree: "Boss/AnimationTree", state_machine_path: "parameters/StateMachine", state_name: "idle"
│   └── true → (Boss idle, check the player's position to decide the next step)
├── CheckAnimationTreeState → animation_tree: "Boss/AnimationTree", state_machine_path: "parameters/StateMachine", state_name: "attack"
│   └── true → (Boss attacking, check whether the attack hits)
└── CheckAnimationTreeState → animation_tree: "Boss/AnimationTree", state_machine_path: "parameters/StateMachine", state_name: "stagger"
    └── true → (Boss staggered, the player can deal damage freely)
```

---

## Notes

0. **Node path or variable:** conditions with NodePath parameters (such as CheckIsPlaying and CheckIsAnimation) support both hard-coded node paths and node references passed dynamically through variables.
1. **AnimationTree conditions require an AnimationTree node:** `CheckAnimationTreeState` and `CheckAnimationTreeParameter` require an `AnimationTree` node in the scene with a configured state machine.
2. **CheckIsAnimation requires an AnimationPlayer:** this condition checks `AnimationPlayer.current_animation`, so the target node must be of type `AnimationPlayer`.
3. **CheckAnimationFinished does not reset its state:** after an animation completes, this condition returns `true`; it must be reset manually, or the state updates once a new animation plays.
