> 🌐 [**中文版**](../../../zh_CN/user_docs/Introductions/06-animation-and-tween.md) | English

# From Animation Playback to Springy Tweens: Fuse's Animation Toolkit and Game Feel Polish

By the end of this chapter you will have pushed Fuse from "logic that runs" to "a screen that moves and feel that lands". How a character's attack plays its animation, how getting hit shakes and flashes red, how UI popups spring open, how picked-up items grow and fade out, how slow motion works by changing playback speed — the details that decide whether a game "feels good" are fully covered by Fuse's two systems: AnimationPlayer control (4 instructions + 6 events) and Tween tweens (13 instructions). This chapter clarifies each system's role and how to combine them with the logic and expressions from earlier chapters into interactions with feedback.

Carrying over from the previous chapter: flow control and data structures built the logic skeleton, but the skeleton doesn't move. The logic says "enemy was hit", yet the screen shows no reaction — because hit feedback is the job of animation and tweens. This chapter puts moving skin on that skeleton.

## Two Animation Systems, Each with Its Own Job

Fuse's animation capabilities come in two layers; first, get the roles straight:

**AnimationPlayer control** handles "playing pre-made animations". The animations you build in Godot's Animation panel (run, jump, attack, idle) are played, stopped, blended, and speed-adjusted through Fuse instructions. Suited to character actions, cutscenes, and state-machine-driven animation switching. It can also listen to the various signals AnimationPlayer emits as events — that's the entrypoint of "animation-driven logic".

**Tween tweens** handle "transitions computed in real time at runtime". You don't prepare an animation resource in advance; just tell it "scale this node from A to B over 0.3 seconds with Back easing", and it computes every frame's value itself at runtime. Suited to UI effects, hit feedback, and pickup effects — one-shot, parameterized transitions that don't warrant a full animation.

One line to tell them apart: **AnimationPlayer "plays a finished clip"; Tween "computes transitions in real time".** Real projects mix both — running, jumping, and attacking use AnimationPlayer; UI and hit feedback use Tween.

## AnimationPlayer Control: 4 Instructions

| Instruction | Purpose | Key parameters |
|------|------|----------|
| **PlayAnimation** (play animation) | Plays a specified animation on an AnimationPlayer | `animation_name`, `speed`, `from_end` |
| **StopAnimation** (stop animation) | Stops playback | `keep_position` (hold current frame or reset to start) |
| **BlendAnimation** (blend animation) | Sets an AnimationTree blend track's value | `blend_path`, `blend_amount` or variable-driven |
| **SetAnimationSpeed** (set animation speed) | Changes the AnimationPlayer's global speed scale | `speed_scale` |

`PlayAnimation` is the most used. Point `target_player` at the AnimationPlayer node (say, `%Player/AnimationPlayer`), fill `animation_name` with the animation name ("run", "attack"), and it plays. `speed` controls this playback's speed; `from_end = true` plays backwards — useful for "animating back to the starting pose".

`StopAnimation` has a detail: `keep_position = true` (default) pauses and holds the current pose; `keep_position = false` stops and resets to the start. Use the former to freeze a dead character's pose, the latter to reset a state machine.

`SetAnimationSpeed` and `PlayAnimation.speed` are easy to mix up. The difference: `PlayAnimation.speed` only affects that one playback call; `SetAnimationSpeed` directly changes the AnimationPlayer's `speed_scale` property and **affects all subsequent animations**. Use `SetAnimationSpeed` for global slow motion, and `PlayAnimation.speed` for one-off speed changes.

In practice: the slow-motion effect. To put the whole character into bullet time when hit:

```
Hit event → SetAnimationSpeed(speed_scale: 0.3)   # slow everything to 30%
Wait(0.5 seconds)
SetAnimationSpeed(speed_scale: 1.0)               # back to normal
```

## BlendAnimation: Animation Tree Blending

If your character uses an AnimationTree (blend spaces, state machines), `BlendAnimation` is central. It sets a blend track's value, such as `parameters/BlendSpace1D/blend_position`. Two modes: give a direct 0.0~1.0 number, or drive it with a variable.

Variable-driven mode is the key link with the earlier expressions and variable system:

```
BlendAnimation
  target_tree: %Player/AnimationTree
  blend_path:  "parameters/BlendSpace1D/blend_position"
  use_variable: true
  blend_variable: "move_speed"    # read the blend amount from the move_speed variable
  blend_scope: Local
```

This way the character's idle → walk → run transition is driven entirely by the `move_speed` variable — you update the variable in your movement logic, and the animation blend follows automatically. That's the standard approach of "data-driven animation". Together with `SetAnimationBlendPosition` (set animation blend position) and `SetAnimationTreeParameter` (set animation tree parameter) from the table, every kind of AnimationTree parameter can be controlled from visual logic.

## 6 Animation Events: Let Animations Drive Logic

AnimationPlayer emits various signals, and Fuse turned them into 6 events — the entrypoint of "animation reaches a point → triggers a piece of logic":

| Event | Fires when |
|------|----------|
| **OnAnimationStarted** (animation started) | A given animation starts playing |
| **OnAnimationFinished** (animation finished) | Playback completes |
| **OnAnimationLoop** (animation looped) | A looping animation completes each cycle |
| **OnAnimationFrameReached** (animation frame reached) | Playback reaches a specified frame |
| **OnAnimationMarker** (animation marker) | Playback passes a marker placed in the animation |
| **OnAnimationBlend** (animation blended) | An AnimationTree blend weight crosses a threshold |

The most used is `OnAnimationFinished`. The classic pattern: switch back to idle when the attack animation finishes:

```
Event: OnAnimationFinished(animation_name: "attack")
Instruction: PlayAnimation(animation_name: "idle")
```

`OnAnimationFrameReached` and `OnAnimationMarker` are the sharp tools for "precise timing". If frame 12 of the attack animation is the true moment the blade connects, triggering the damage check on that exact frame is far more precise than guessing time with `Wait`. `OnAnimationMarker` is even more flexible — you tag keyframes with string markers in Godot's Animation panel (like "hit", "footstep"), and the animation triggers there, driving both audio (footstep sounds) and logic (damage checks) at once.

`OnAnimationBlend` suits detecting "whether a blend-space switch has completed". For instance, only trigger "running dust particles" once the blend weight crosses 0.8 while going from walk to run, avoiding a mis-fire mid-transition.

These events also stuff parameters like animation name, current frame, and playback position into the context via `set_meta()`; downstream instructions can fetch them with `context.get_meta("animation_name")` and the like.

## The Tween Toolkit: 13 Tween Instructions

The Tween side has more instructions, in three groups:

**Basic property animations** (7): `TweenFadeIn` (fade in), `TweenFadeOut` (fade out), `TweenMoveTo` (move to), `TweenScaleTo` (scale to), `TweenRotateTo` (rotate to), `TweenColorTransition` (color transition), `TweenPropertyInstruction` (property animation, general-purpose).

**Preset effect animations** (4): `TweenPopAnimation` (pop animation), `TweenShakeAnimation` (shake animation), `TweenBounceAnimation` (bounce animation), `TweenPulseAnimation` (pulse animation).

**Control** (2): `TweenPause` (pause tween), `TweenResume` (resume tween).

The first six of the basic group are "smoothly transition some property to a target value"; their parameters all include target node, target value, duration, Easing, and Trans. `TweenPropertyInstruction` is the catch-all general-purpose one that can animate any property, including Material and Shader parameters — for instance `modulate:a` (alpha) or `material:shader_param/glow_intensity` (a shader parameter); anything the six specialized ones don't cover, use it.

The preset group is "out-of-the-box game-feel effects" — no hand-tuning easing curves:

`TweenPopAnimation` springs from 0 to the target scale with spring easing — suited to popups, chests, and bubbles.

`TweenShakeAnimation` is the workhorse of hit feedback, with parameters for intensity, count, and axis (X/Y/XY). Character takes a hit → `TweenShakeAnimation` (intensity 10, count 3, XY) and you instantly feel the impact.

`TweenBounceAnimation` simulates a falling bounce — use it when items drop to the ground.

`TweenPulseAnimation` is breathing/pulsing, oscillating the scale between min/max; `loop_count = 0` loops forever — give "the hint icon above an interactable NPC" a persistent breathing effect, and players know instantly that it's clickable.

## Pairing Easing with Transition Types

Whether a Tween feels good is eighty percent decided by choosing the right Easing and Trans curves. This is where Fuse exposes all of Godot's native Tween curves for you.

Easing type controls how speed changes: `In` (slow start, fast finish — falling), `Out` (fast start, slow finish — decelerating to a stop), `InOut` (slow at both ends — smooth movement), `OutIn` (fast at both ends).

Transition type controls the mathematical curve shape: `Linear` (constant speed — simple movement), `Sine` (sinusoidal — natural transitions), `Back` (overshoot — UI slide-ins), `Spring` (springy — elastic pops), `Bounce` (bouncing — landings), `Elastic` (elastic stretch — exaggerated effects).

A few classic pairings, once memorized, cover most scenarios:

- UI interactions (button hover, popups): `Out` + `Back` or `Spring` — that "slightly overshoots then springs back" elasticity.
- Natural movement (character gliding, camera follow): `InOut` + `Sine` — smooth acceleration and deceleration.
- Falling to land (items dropping): `Out` + `Bounce` — a bounce on landing.
- Elastic emphasis (score pop-outs, achievements): `Out` + `Elastic` — exaggerated stretch and rebound.

The preset instructions already chose curves for you (Pop uses Spring, Bounce uses Bounce) — just use them; the basic instructions require picking your own pairing, and the four combos above are enough.

## A Runnable Hit Feedback Example

Combine AnimationPlayer and Tween into a complete hit feedback — the most classic game-feel polish point. When the character is hit: flash red + shake + 0.2 seconds of slow motion + play the hurt animation.

```
Event: OnHealthChanged (when hp decreases) or a custom hit signal
Instructions:
  → PlayAnimation(animation_name: "hurt")          # play the hurt animation
  → TweenColorTransition(target: character, color: red, duration: 0.1)  # flash red
  → TweenShakeAnimation(target: character, intensity: 10, count: 3, axis: XY)  # shake
  → SetAnimationSpeed(speed_scale: 0.3)            # slow motion
  → Wait(0.2 seconds)
  → SetAnimationSpeed(speed_scale: 1.0)            # restore
  → TweenColorTransition(target: character, color: white, duration: 0.2)  # restore color
```

Run this chain and a hit makes the character flash red first, shake three times, enter slow motion for 0.2 seconds, then recover — that "weighty impact" of action games. Every step is an instruction covered above; combined, the effect is on another level. Tweak a few parameters (shake intensity, slow-motion factor, durations) and you get entirely different feels, all through drag-and-drop trial and error in the Inspector — no repeated code edits and recompiles.

One more UI popup example. A quest-complete popup springs from zero:

```
Event: quest completed (custom signal or OnVariableChanged)
Instruction:
  → TweenPopAnimation(target: popup, target_scale: 1.0, duration: 0.4)
```

One line, and the popup springs from zero to full size with a springy effect. For extra emphasis, add a `TweenPulseAnimation` (loop: 3) so it pulses three times after popping, drawing the player's attention.

## Practical Tips for Game Feel Polish

Finally, a few battle-tested tips for feel work, distilled from the Tween guide's best practices:

**Duration tiers.** Fast feedback (clicks, flashes) 0.05~0.15 seconds; UI animations (fades, slide-ins) 0.2~0.5 seconds; character actions (movement, attacks) 0.3~0.8 seconds; transitions (scene switches) 0.5~2.0 seconds. Wrong duration ruins even great easing — a 0.5-second button hover feels sluggish, a 0.1-second scene switch feels jarring.

**auto_free cleanup.** `TweenFadeOut` and `TweenPropertyInstruction` support an `auto_free` parameter that releases the node automatically when the animation finishes. For pickup "grow + fade out", use `auto_free = true` and the node disappears on its own — no manual `QueueFreeNode`.

**Remember to stop infinite loops.** `TweenPulseAnimation`'s `loop_count = 0` loops forever; after the player accepts the quest you must stop it manually (`TweenPause` or cancel), otherwise that hint icon keeps flashing until the game closes.

**Don't run too many at once.** Keep simultaneously running Tweens within about 50. When many objects need animation (say, a hundred particles), consider object pooling (`InstantiateScene` + `WarmUpPool` — content of the later engineering chapter) instead of hanging a Tween on each.

## Next Chapter: Making the Character Truly Controllable

Animations play, tweens work, hit feedback has feel. But the character still "plays animations without actually moving" — you press right, it plays the run animation, and stays in place. Because real character control is the combination of input events + physics movement + physics conditions — a separate system.

**In the next chapter, I'll cover character control in practice: how input events hook up keyboard, mouse, and gamepad; how `MoveCharacterBody2DComposite` does basic and smooth movement; and how physics conditions (CheckOnFloor / CheckOnWall / CheckInAir / CheckIsFalling) build jump, double jump, wall climb, and slide.** At that point, your character is truly "alive" — it can move, jump, and climb walls, all built visually.
