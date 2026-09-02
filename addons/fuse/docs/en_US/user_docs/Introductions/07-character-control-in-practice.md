> 🌐 [**中文版**](../../../zh_CN/user_docs/Introductions/07-character-control-in-practice.md) | English

# Building a Jumping, Wall-climbing Character Without Code: Fuse Input and Physics in Practice

By the end of this chapter you will have pushed Fuse from "animations that play" to "a character that's truly controlled". In Fuse you can assemble, from visual bricks, a 2D platformer character that responds to keyboard, touch, and gamepad input, with jump, double jump, wall climb, and slide — without writing a single `_process`.

Carrying over from the previous chapter: the animation system gave the character moves, but a character that only performs moves in place isn't a character — it needs to run, jump, and shimmy up walls.

## First, Get This Straight: How Input Events Flow into Logic

Many people new to visual programming get stuck on step one: a key is pressed — who exactly tells the character to "move"? In Fuse, the answer is **input Events**. Events are a Trigger's trigger source; once their conditions are met, they drive the Instruction chain attached to them.

Fuse has a dozen-plus input events, covering every input device you can think of. Let's group them by device:

For keyboards there's `OnInputKey` (key input), supporting three trigger timings: on press, on release, and repeat. The mouse splits further: `OnMouseButton` (mouse button) handles clicks, `OnMouseMove` (mouse move) handles movement, and `OnMouseEnter` (mouse enter) and `OnMouseExit` (mouse exit) do hover detection specifically for UI nodes like `Control`. Touch devices have `OnTouch` (touch) and `OnTouchSwipe` (touch swipe); the latter supports configuring `min_distance` (minimum swipe distance) and `swipe_direction` (swipe direction), very handy for mobile page flips and swipe dodges. Gamepads split into `OnGamepadButton` (gamepad button) and `OnGamepadAxis` (gamepad axis); the latter needs a `deadzone` threshold to avoid false triggers when the stick re-centers.

If you don't want to be locked to specific physical keys, there's another layer of abstraction: `OnInputAction` (action input) goes through Godot's native Input Map system. Define actions like `jump` and `attack` in project settings, map keyboard, mouse, and gamepad onto them, and the logic side only knows action names — switching devices costs nothing. For four-directional movement like WASD, use `OnInputActionComposite` (composite input action) directly: it bundles the four directional actions and automatically supports diagonal movement.

One easily overlooked point: when an input event fires, it stuffs key codes, positions, strengths, directions, and similar data into the ExecutionContext, where subsequent instructions can use them directly. After `OnTouchSwipe` fires, for instance, the instruction chain can read the start position, end position, direction, and distance — logic like "swipe right to switch weapons" needs no angle math of your own.

## Making the Character Move: Choosing Among Three Movement Modes

Input is hooked up; now for how the character responds. For a physics character like `CharacterBody2D`, Fuse provides the core instruction `MoveCharacterBody2DComposite` (move CharacterBody2D, composite). It takes four-directional input and updates the character's velocity according to the movement mode you choose.

These three modes define the character's "feel" and deserve expanding:

**DIRECT (set velocity directly).** The instruction sets `velocity` straight to the target value; releasing stops instantly, with zero inertia. First choice for grid movement, turn-based games, and anything demanding absolute response precision. Pro: it follows your fingers. Con: it's mechanical.

**SMOOTH (smooth interpolation).** Uses linear interpolation to transition current velocity smoothly toward target velocity; the transition speed is controlled by `smooth_factor` — larger means faster changes. Use it for casual games and anything wanting a "silky" look; the character carries a slight sliding afterglow without ever feeling out of control.

**ACCELERATION (acceleration).** The closest to real physics, simulating acceleration and braking with the two parameters `acceleration` and `friction`. Starts carry a sense of impulse; hard stops skid a little. Strongly recommended for platformers and action games, because it naturally carries "weight".

Let's first build a working four-directional mover. Prerequisites: the four Input Map actions `move_up`/`move_down`/`move_left`/`move_right` defined in project settings, and a `CharacterBody2D` with a `CollisionShape2D` in the scene.

Add a Trigger under the character node, pick `OnInputActionComposite` as the Event, fill in the four directional action names, and set the trigger rate (trigger_rate) to 60 FPS. Then give this Trigger one `MoveCharacterBody2DComposite` instruction: `target_node` pointing at the character itself, `speed` set to 200, `move_mode` set to DIRECT. Run the scene and WASD moves the character in four directions, with diagonals when two keys are held. Switch `move_mode` to ACCELERATION with `acceleration` at 1000 and `friction` at 800, and the character immediately gets a skating feel — the same character, two styles from different parameters.

One more performance trade-off: `OnInputActionComposite`'s `trigger_rate` determines how many times per second the event fires. 60 FPS is the smoothest but the heaviest load; 30 FPS is the balance point for casual games; 20 FPS suits mobile; 10 FPS stutters noticeably and isn't recommended. For something needing precise response like primary character control, don't drop to 20 FPS just to save performance.

## The Seven Physics Conditions: Letting the Character Know Where It Is

Movement is just the base; what makes platformers fun is the character's awareness of its own state: Am I on the ground? Against a wall? Rising or falling in the air? Is my speed enough to trigger a dash? These judgments all come from physics Conditions. Fuse provides 7 physics conditions under `conditions/physics/`; a panorama first:

| Condition | Readable name | Underlying check | Typical use |
|------|--------|----------|----------|
| `CheckOnFloor` | on the floor | `is_on_floor()` | Whether jumping is allowed |
| `CheckOnWall` | on a wall | `is_on_wall()` | Wall climbing, wall jumps |
| `CheckInAir` | in the air | neither on floor nor on wall | Double jumps, airborne behaviors |
| `CheckIsFalling` | falling | vertical velocity below threshold | Fall acceleration, wings-spread animation |
| `CheckVelocity` | velocity check | speed magnitude or components | Dash checks, overspeed feedback |
| `CheckSlope` | slope check | `get_floor_normal()` | Steep-slope slides |
| `CheckOverlapArea` | area overlap check | body/area overlap detection | Standing on lava, triggering traps |

The first three answer "where", the next two answer "how it's moving", and the last two answer "what it's touching". Note they all depend on the results of `move_and_slide()` — that is, the character must have actually moved during a physics frame for these judgments to be accurate. The character node that `target_node` points at must genuinely be a `CharacterBody2D`/`CharacterBody3D`.

The easiest to confuse are `CheckInAir` and `CheckIsFalling`. Being in the air (`CheckInAir` true) does not equal falling — the initial rise right after a jump is equally "in the air". Combining the two distinguishes the "rising" and "falling" states, which is crucial for switching between jump and fall animations. `CheckIsFalling` directly judges `velocity.y > 0` (in Godot's coordinate system Y points down, so Y velocity greater than 0 means falling), with no additional threshold parameter.

`CheckVelocity` is flexible; it compares speed magnitude (scalar), configured via `velocity_threshold` and `comparison_operator`. To judge "is dashing", pick `Greater Than` for `comparison_operator` with a large `velocity_threshold`; to judge "nearly stationary", use `Less Than` with a very small `velocity_threshold`.

## In Practice: Assembling Jump, Double Jump, Wall Climb, and Slide

Enough theory — let's build something that actually runs. The set below is driven by a single `OnPhysicsProcess` (physics frame processing), because physics state judgments are only meaningful inside the physics frame.

**1) Basic jump**

Jumping requires being on the ground. Place `CheckOnFloor` first; when true, nest a `CheckInputPressed` (key pressed) checking the `jump` action; only when both hold does the jump execute. The jump itself gives the character an upward velocity — either `SetVelocity` (set velocity) to change the Y component directly, or `ApplyImpulse` (apply impulse) for an upward impulse.

```
OnPhysicsProcess
└── CheckOnFloor  target_node: Player
    └── CheckInputPressed  action_name: "jump"
        └── SetVelocity  target_node: Player, velocity: (x, -500)
```

**2) Double jump**

A double jump is a second jump in the air — but not infinite jumps. Introduce a local variable `jumps_left` tracking remaining jumps. Reset it to 2 on landing; pressing jump in the air consumes one.

```
OnPhysicsProcess
├── CheckOnFloor  target_node: Player
│   └── SetVariable  target_variable_scope: LOCAL, target_variable: "jumps_left", new_value: 2
└── CheckInAir  target_node: Player
    └── CheckInputPressed  action_name: "jump"
        └── CheckVariable  variable_name: "jumps_left", comparison_operator: GREATER_THAN, expected_value: 0
            ├── SetVelocity  target_node: Player, velocity: (x, -450)
            └── AddVariable  variable_name: "jumps_left", add_value: -1
```

Here `CheckInAir` ensures only the airborne branch reaches the double jump, and `CheckVariable` gates the count. The landing `CheckOnFloor` refreshes the count back to 2 every frame, so the moment the character touches ground its jumping ability is fully restored.

**3) Wall climb**

When against a wall, holding the climb key moves upward. `CheckOnWall` judges wall contact; layer `CheckInputHeld` (key held) checking the `climb` action. When satisfied, stop horizontal movement and apply an upward velocity or impulse instead.

```
OnPhysicsProcess
└── CheckOnWall  target_node: Player
    └── CheckInputHeld  action_name: "climb"
        └── SetVelocity  target_node: Player, velocity: (0, -120)
```

For finer wall climbing, add `CheckIsFalling` to distinguish "active climbing" from "sliding down the wall", using a smaller falling speed for the slide to simulate friction.

**4) Slide**

Pressing down on a steep slope enters a slide. `CheckSlope`'s `angle_degrees` parameter is in degrees; set `compare_type` to `GREATER_EQUAL` with 45 degrees to trigger. Pair `CheckOnFloor` to ensure standing on the ground, then `CheckInputHeld` judging `move_down`.

```
OnPhysicsProcess
└── CheckOnFloor  target_node: Player
    └── CheckSlope  target_node: Player, compare_type: GREATER_EQUAL, angle_degrees: 45.0
        └── CheckInputHeld  action_name: "move_down"
            └── (switch to the slide animation + adjust the collision shape)
```

Combine the four pieces above with `CheckAll`/`CheckAny` into a single `OnPhysicsProcess` Trigger, and you have a platformer character with a complete state model. Worth mentioning is the `OnGroundStateChanged` (ground state changed) physics event — it fires once each at the instants the character "leaves the ground" and "lands again", cheaper than checking `CheckOnFloor` every frame and perfect for one-shot feedback like "jump dust effects" and "landing sounds".

This chapter made the character truly controlled: three input devices, three movement modes, and seven physics state judgments combined into jump, double jump, wall climb, and slide. But a character that moves and jumps can still feel "dry" to play — no feedback. The next chapter maxes out the game feel: the UI, camera, and audio triple combo, so every input gets a visible, audible echo.
