> 🌐 [**中文版**](../../../zh_CN/user_docs/guides/12-animation-guide.md) | English

# Animation System User Guide

Fuse provides a complete set of animation control components — 4 instructions and 6 events — covering two major scenarios: AnimationPlayer playback control and AnimationTree blend control.

**Category:** Animation
**Applicable Godot nodes:** AnimationPlayer, AnimationTree

---

## Instructions

### PlayAnimation -- Play Animation

Plays the specified animation on an AnimationPlayer.

**File:** [play_animation.gd](../../../../instructions/animation/play_animation.gd)
**Icon:** AnimationPlayer

#### Properties

| Property | Type | Default | Description |
|------|------|--------|------|
| target_player | NodePath | "" | Target AnimationPlayer node path |
| animation_name | String | "" | Name of the animation to play |
| speed | float | 1.0 | Playback speed (range: 0.01 - 10.0+) |
| from_end | bool | false | Whether to play in reverse from the end |
| autoplay_only | bool | false | Whether to only autoplay |

#### Basic Usage

1. Add the PlayAnimation instruction to an ActionRunner's instruction list
2. Specify the AnimationPlayer's node path in `target_player` (e.g. `%CharacterBody2D/AnimationPlayer`)
3. Fill in the animation name to play in `animation_name` (e.g. "run", "jump", "attack")
4. Adjust `speed` as needed to control the playback speed

#### Use Cases

**Forward playback:**
```
target_player: %Player/AnimationPlayer
animation_name: "run"
speed: 1.0
from_end: false
```

**Reverse playback (e.g. playing an animation backwards):**
```
target_player: %Player/AnimationPlayer
animation_name: "idle"
speed: 1.0
from_end: true
```

**Slow motion playback:**
```
speed: 0.5    -- half speed
```

**Fast playback:**
```
speed: 2.0    -- double speed
```

#### Validation Rules

- target_player cannot be empty
- animation_name cannot be empty
- speed must be > 0
- The target node must be of type AnimationPlayer
- The animation name must exist in the AnimationPlayer's animation library

---

### StopAnimation -- Stop Animation

Stops the AnimationPlayer's animation playback.

**File:** [stop_animation.gd](../../../../instructions/animation/stop_animation.gd)
**Icon:** Stop

#### Properties

| Property | Type | Default | Description |
|------|------|--------|------|
| target_node | NodePath | "" | Target AnimationPlayer node path |
| keep_position | bool | true | Whether to keep the current animation position |

#### Behavior

- `keep_position = true` (default): calls `AnimationPlayer.pause()`, pausing while keeping the current frame position
- `keep_position = false`: calls `AnimationPlayer.stop()`, stopping and resetting to the start position

#### Use Cases

**Pause the animation (keep the pose):**
```
target_node: %Player/AnimationPlayer
keep_position: true
```

**Stop completely (reset position):**
```
target_node: %Player/AnimationPlayer
keep_position: false
```

#### Validation Rules

- target_node cannot be empty
- The target node must be of type AnimationPlayer

---

### BlendAnimation -- Blend Animation

Sets the value of an AnimationTree blend track, supporting either a direct value or variable-driven input.

**File:** [blend_animation.gd](../../../../instructions/animation/blend_animation.gd)
**Icon:** Blend

#### Properties

| Property | Type | Default | Description |
|------|------|--------|------|
| target_tree | NodePath | "" | Target AnimationTree node path |
| blend_path | String | "" | Blend path (e.g. "parameters/blend_position") |
| use_variable | bool | false | Whether to drive the blend amount with a variable |
| blend_amount | float | 0.5 | Direct blend amount (0.0 - 1.0) |
| blend_variable | String | "" | Blend amount variable name |
| blend_scope | enum | Local | Variable scope (Local/Scope/Global) |

#### Two Modes

**Direct value mode (use_variable = false):**

Directly set a numeric value between 0.0 and 1.0:
```
target_tree: %Player/AnimationTree
blend_path: "parameters/BlendSpace1D/blend_position"
blend_amount: 0.7
```

**Variable-driven mode (use_variable = true):**

Dynamically control the blend amount through a variable:
```
target_tree: %Player/AnimationTree
blend_path: "parameters/BlendSpace1D/blend_position"
use_variable: true
blend_variable: "move_speed"
blend_scope: Local
```

When using the Scope scope, you can also specify the scope source:
- **Nearest** -- the nearest scope container (default)
- **Custom ID** -- the container matching the given custom_scope_id
- **Trigger Scope** -- the scope on the Trigger node
- **Target Node** -- the scope on the target node

#### Validation Rules

- target_tree cannot be empty
- blend_path cannot be empty
- blend_variable cannot be empty when using a variable
- The variable value must be convertible to float
- The final blend amount is clamped to [0.0, 1.0]

---

### SetAnimationSpeed -- Set Playback Speed

Sets the AnimationPlayer's global playback speed scale.

**File:** [set_animation_speed.gd](../../../../instructions/animation/set_animation_speed.gd)
**Icon:** ViewportSpeed

#### Properties

| Property | Type | Default | Description |
|------|------|--------|------|
| target_node | NodePath | "" | Target AnimationPlayer node path |
| speed_scale | float | 1.0 | Playback speed scale (range: 0.01 - 10.0+) |

#### Speed Value Reference

| speed_scale | Effect |
|-------------|------|
| 0.25 | Quarter speed (ultra slow motion) |
| 0.5 | Half speed (slow motion) |
| 1.0 | Normal speed |
| 2.0 | Double speed |
| 3.0 | Triple speed (fast rewind-style playback) |

#### Use Cases

**Global slow motion effect:**
```
target_node: %Player/AnimationPlayer
speed_scale: 0.3
```

**Fast cutscene playback:**
```
target_node: %Cutscene/AnimationPlayer
speed_scale: 3.0
```

#### Difference from PlayAnimation

- `PlayAnimation.speed`: only affects the current playback call, and is only set at execute time
- `SetAnimationSpeed.speed_scale`: directly modifies the AnimationPlayer.speed_scale property, affecting all subsequent animation playback

#### Validation Rules

- target_node cannot be empty
- speed_scale must be > 0
- The target node must be of type AnimationPlayer

---

## Events

### OnAnimationStarted -- Animation Started Event

Fires when an AnimationPlayer starts playing an animation.

**File:** [on_animation_started.gd](../../../../events/animation/on_animation_started.gd)
**Icon:** Animation

#### Properties

| Property | Type | Default | Description |
|------|------|--------|------|
| target_node_path | NodePath | "" | Target AnimationPlayer node path |
| animation_name | String | "" | Animation name (empty = any animation) |
| trigger_once_per_animation | bool | false | Trigger only once per animation |
| emit_animation_name | bool | true | Whether to pass the animation name |
| emit_animation_length | bool | true | Whether to pass the animation length |
| emit_loop_mode | bool | false | Whether to pass the loop mode |

#### Emitted Context Parameters

| Meta key | Type | Description |
|---------|------|------|
| animation_name | StringName | Animation name |
| animation_length | float | Animation duration (seconds) |
| loop_mode | int | Loop mode |
| animation_player | AnimationPlayer | AnimationPlayer reference |

#### Detection Mechanism

On Godot 4.7+, the `animation_started` signal is preferred. If the signal is unavailable, detection falls back to polling (checking whether the playback position is < 0.1 seconds to determine that it just started).

---

### OnAnimationFinished -- Animation Finished Event

Fires when an AnimationPlayer finishes playing the specified animation.

**File:** [on_animation_finished.gd](../../../../events/animation/on_animation_finished.gd)
**Icon:** Animation

#### Properties

| Property | Type | Default | Description |
|------|------|--------|------|
| animation_player | NodePath | "" | Target AnimationPlayer node path |
| animation_name | String | "" | Animation name (empty = any animation) |
| emit_animation_name | bool | true | Whether to pass the animation name |

#### Emitted Context Parameters

| Meta key | Type | Description |
|---------|------|------|
| animation_name | String | Name of the finished animation |
| animation_player | AnimationPlayer | AnimationPlayer reference |

#### Common Usage

Return to the idle state after an attack animation ends:
```
animation_player: %Player/AnimationPlayer
animation_name: "attack"
```

---

### OnAnimationLoop -- Animation Loop Event

Fires when an animation loops (plays to the end and starts over).

**File:** [on_animation_loop.gd](../../../../events/animation/on_animation_loop.gd)
**Icon:** Animation

#### Properties

| Property | Type | Default | Description |
|------|------|--------|------|
| target_node_path | NodePath | "" | Target AnimationPlayer node path |
| animation_name | String | "" | Animation name (empty = any animation) |
| trigger_mode | enum | ON_EVERY_LOOP | Trigger mode |
| loop_count_threshold | int | 0 | Loop count threshold (0 = unlimited) |
| emit_animation_name | bool | true | Whether to pass the animation name |
| emit_current_loop | bool | true | Whether to pass the current loop count |
| emit_total_loops | bool | false | Whether to pass the total loop count |
| emit_animation_progress | bool | true | Whether to pass the animation progress |

#### Trigger Modes

| Mode | Description |
|------|------|
| ON_EVERY_LOOP | Fires on every loop |
| ON_THRESHOLD_REACHED | Fires only when loop_count_threshold is reached |

#### Use Cases

**Counting loops:**
```
animation_name: "run"
trigger_mode: ON_EVERY_LOOP
emit_current_loop: true
```

**Trigger a special event after the 3rd loop:**
```
animation_name: "idle"
trigger_mode: ON_THRESHOLD_REACHED
loop_count_threshold: 3
```

#### Emitted Context Parameters

| Meta key | Type | Description |
|---------|------|------|
| animation_name | String | Animation name |
| current_loop | int | Current loop count |
| total_loops | int | Total loop count |
| animation_progress | float | Animation progress (0.0 - 1.0) |
| animation_player | AnimationPlayer | AnimationPlayer reference |

---

### OnAnimationFrameReached -- Animation Frame Reached Event

Fires when animation playback reaches the specified frame.

**File:** [on_animation_frame_reached.gd](../../../../events/animation/on_animation_frame_reached.gd)
**Icon:** AnimationPlayer

#### Properties

| Property | Type | Default | Description |
|------|------|--------|------|
| animation_player_path | NodePath | "" | Target AnimationPlayer node path |
| target_frame | int | 0 | Target frame index (0 - 10000) |
| animation_name | String | "" | Animation name (empty = current animation) |
| emit_animation_name | bool | true | Whether to pass the animation name |
| emit_current_frame | bool | true | Whether to pass the current frame |
| emit_position | bool | true | Whether to pass the playback position (seconds) |

#### Behavior

- Uses a 60 FPS timer (~16ms) to check whether the current frame has reached target_frame
- Fires only once by default (has_triggered state); call reset() to reset it
- The frame index is computed from the animation's frame_rate: `current_frame = position * fps`

#### Emitted Context Parameters

| Meta key | Type | Description |
|---------|------|------|
| animation_name | String | Animation name |
| current_frame | int | Current frame index |
| position | float | Playback position (seconds) |
| target_frame | int | Target frame |
| animation_player | AnimationPlayer | AnimationPlayer reference |

---

### OnAnimationMarker -- Animation Marker Event

Fires when playback passes the specified marker point in an animation.

**File:** [on_animation_marker.gd](../../../../events/animation/on_animation_marker.gd)
**Icon:** Animation

#### Properties

| Property | Type | Default | Description |
|------|------|--------|------|
| target_node_path | NodePath | "" | Target AnimationPlayer node path |
| marker_name | String | "" | Marker name (empty = any marker) |
| animation_name | String | "" | Animation name (empty = any animation) |
| trigger_once_per_play | bool | false | Trigger only once per playback |
| emit_animation_name | bool | true | Whether to pass the animation name |
| emit_marker_name | bool | true | Whether to pass the marker name |
| emit_marker_position | bool | true | Whether to pass the marker position |
| emit_current_position | bool | true | Whether to pass the current playback position |

#### Marker Detection Mechanism

Iterates over all keyframes in the animation tracks, looking for string values or dictionaries with a "marker" key as markers. Whether a marker has been passed is determined by comparing the previous playback position with the current one (tolerance 0.02 seconds).

When the animation loops and trigger_once_per_play is enabled, the marker trigger state is automatically reset.

#### Emitted Context Parameters

| Meta key | Type | Description |
|---------|------|------|
| animation_name | String | Animation name |
| marker_name | String | Marker name |
| marker_position | float | Marker position (seconds) |
| current_position | float | Current playback position (seconds) |
| animation_player | AnimationPlayer | AnimationPlayer reference |

---

### OnAnimationBlend -- Animation Blend Weight Changed Event

Fires when an AnimationTree blend node's weight reaches the specified threshold.

**File:** [on_animation_blend.gd](../../../../events/animation/on_animation_blend.gd)
**Icon:** AnimationTree

#### Properties

| Property | Type | Default | Description |
|------|------|--------|------|
| animation_tree_path | NodePath | "" | Target AnimationTree node path |
| blend_path | NodePath | "" | Blend path |
| threshold | float | 0.5 | Weight threshold (0.0 - 1.0) |
| comparison | enum | GREATER_OR_EQUAL | Comparison mode |

#### Comparison Modes

| Comparison mode | Description |
|---------|------|
| GREATER_OR_EQUAL | Fires when weight >= threshold (crossing from below to above) |
| LESS_OR_EQUAL | Fires when weight <= threshold (crossing from above to below) |
| EQUAL | Fires when weight is close to the threshold (tolerance 0.01) |

#### Behavior

- Uses a 100ms timer to detect blend weight changes
- Fires only once when the weight crosses from one side to the other; does not fire continuously
- For example, in GREATER_OR_EQUAL mode: fires only when the weight goes from < threshold to >= threshold

#### Use Cases

**Detect that a blend space switch has completed:**
```
animation_tree_path: %Player/AnimationTree
blend_path: "parameters/BlendSpace1D/blend_position"
threshold: 0.8
comparison: GREATER_OR_EQUAL
```

**Detect transition to a specific state:**
```
animation_tree_path: %Player/AnimationTree
blend_path: "parameters/StateMachine/conditions/is_running"
threshold: 0.5
comparison: GREATER_OR_EQUAL
```

#### Emitted Context Parameters

| Meta key | Type | Description |
|---------|------|------|
| blend_path | String | Blend path |
| weight | float | Current weight value |
| threshold | float | Threshold |
| comparison | int | Comparison mode enum value |
| animation_tree | AnimationTree | AnimationTree reference |

---

## Common Workflows

### Scenario 1: Character Animation State Machine

Use event listeners to drive animation state transitions:

```
OnAnimationFinished("attack")  -->  PlayAnimation("idle")
OnAnimationStarted("run")      -->  SetAnimationSpeed(1.0)
```

### Scenario 2: Cutscene Sequences

Use frame-reached and marker events to orchestrate cutscenes:

```
OnAnimationFrameReached(frame=120)  -->  PlayAnimation("scene2")
OnAnimationMarker("show_dialog")    -->  ShowDialog(...)
```

### Scenario 3: Animation Blend Control

Use BlendAnimation with variable-driven blending:

```
# Set the blend while moving
SetVariable("move_direction", 0.8)
BlendAnimation(use_variable=true, blend_variable="move_direction")

# Listen for blend completion
OnAnimationBlend(threshold=0.9)  -->  EnableMovement()
```

### Scenario 4: Slow Motion Effect

Slow motion when the game is paused or the character is hit:

```
# When hit
SetAnimationSpeed(0.2)

# When recovering
SetAnimationSpeed(1.0)
```

---

## Context Parameter Passing Pattern Shared by All Animation Events

Animation events pass parameters by creating a temporary Node as context and using `set_meta()`. Downstream instructions can read these parameters via `context.get_meta("key")`.

The temporary Node is cleaned up automatically after event handling completes (via `queue_free()`).

---

**Maintained by**: Fuse development team
**Last updated**: 2026-03-19
**Version**: 1.0.0
