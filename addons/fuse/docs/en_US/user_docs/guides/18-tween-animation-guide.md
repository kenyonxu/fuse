> 🌐 [**中文版**](../../../zh_CN/user_docs/guides/18-tween-animation-guide.md) | English

# Tween Animation Usage Guide

> A complete usage guide for the Tween animation instructions of the Fuse visual programming system

**Last updated:** 2026-01-28
**Godot version:** 4.7+

---

## Table of Contents

1. [Overview](#overview)
2. [Basic Animation Instructions](#basic-animation-instructions)
3. [Preset Animation Instructions](#preset-animation-instructions)
4. [Advanced Features](#advanced-features)
5. [Parameter Reference](#parameter-reference)
6. [Common Use Cases](#common-use-cases)
7. [Best Practices](#best-practices)

---

## Overview

The Fuse Tween instruction system provides a complete set of tweening animation instructions built on Godot's native Tween system, covering almost every game animation need.

### Instruction Categories

**Basic property animations (P0-P1)**:
- Tween Fade In/Out - alpha fade in/out
- Tween Move To - position movement
- Tween Scale To - scaling
- Tween Rotate To - rotation
- Tween Color Transition - color transition

**Preset animations (P2-P3)**:
- Tween Pop Animation - pop-out effect
- Tween Shake Animation - shake effect
- Tween Bounce Animation - bounce effect
- Tween Pulse Animation - pulse/breathing effect

**Advanced features (P3)**:
- Tween Property - generic property animation (supports any property)

### Key Features

- ✅ **Asynchronous** - all Tween instructions run asynchronously and never block game logic
- ✅ **Cancellable** - every animation can be cancelled midway
- ✅ **Rich parameters** - advanced options such as easing type and transition type
- ✅ **Auto free** - the Fade Out and Property instructions can free the node automatically when the animation finishes
- ✅ **Localization** - full Chinese UI support
- ✅ **Ease of use** - visual editor, no coding required

---

## Basic Animation Instructions

### Tween Fade In - Fade-In Animation

Gradually makes the node opaque.

**Parameters:**
- `target_node` - target node
- `duration` - duration (seconds)
- `from_alpha` - starting alpha (0.0-1.0)
- `to_alpha` - target alpha (0.0-1.0)
- `easing_type` - easing type (In/Out/InOut/OutIn)
- `trans_type` - transition type (Linear/Sine/Quad, etc.)

**Typical uses:**
- UI fade-in display
- Character teleport appearance
- Scene transition effects

**Example:**
```
Fade duration: 1.0 seconds
Alpha: 0.0 → 1.0
Easing: Out + Sine (smooth deceleration)
```

---

### Tween Fade Out - Fade-Out Animation

Gradually makes the node transparent, with an option to free the node automatically.

**Parameters:**
- `target_node` - target node
- `duration` - duration (seconds)
- `auto_free` - whether to free the node automatically when the animation ends
- `easing_type` - easing type
- `trans_type` - transition type

**Typical uses:**
- UI fade-out close
- Item collection disappearance
- Temporary object cleanup (enable auto_free)

**auto_free usage:**
- `auto_free = false` (default) - the node stays, only transparent
- `auto_free = true` - the node is deleted automatically once the animation completes

**Example:**
```
Fade-out duration: 0.5 seconds
auto_free: true (delete automatically after the item is collected)
```

---

### Tween Move To - Move Animation

Smoothly moves the node to the target position.

**Parameters:**
- `target_node` - target node
- `target_position` - target position (Vector2)
- `duration` - duration (seconds)
- `space_mode` - coordinate space (Global/Local)
- `easing_type` - easing type
- `trans_type` - transition type

**Coordinate spaces:**
- `Global` - global coordinates (world coordinates)
- `Local` - local coordinates (relative to the parent)

**Typical uses:**
- Character movement
- UI slide in/out
- Door open/close animation

**Example:**
```
Move to: (100, 200)
Duration: 1.0 seconds
Space: Global
Easing: InOut + Sine (smooth acceleration and deceleration)
```

---

### Tween Scale To - Scale Animation

Smoothly scales the node to the target size.

**Parameters:**
- `target_node` - target node
- `target_scale` - target scale (Vector2)
- `duration` - duration (seconds)
- `easing_type` - easing type
- `trans_type` - transition type

**Scale values:**
- `Vector2(1, 1)` - original size
- `Vector2(2, 2)` - doubled in size
- `Vector2(0.5, 0.5)` - halved
- `Vector2(0, 0)` - scaled to zero

**Typical uses:**
- Button hover enlargement
- Item collection pop
- UI emphasis effects

**Example:**
```
Scale to: 1.5x
Duration: 0.3 seconds
Easing: Out + Back (slight overshoot, then settle back)
```

---

### Tween Rotate To - Rotation Animation

Smoothly rotates the node to the target angle.

**Parameters:**
- `target_node` - target node
- `target_rotation` - target angle (degrees)
- `duration` - duration (seconds)
- `space_mode` - coordinate space (Global/Local)
- `easing_type` - easing type
- `trans_type` - transition type

**Typical uses:**
- Attack swings
- Rotating door open/close
- Pointer turning

**Example:**
```
Rotate to: 90 degrees
Duration: 0.5 seconds
Space: Local
Easing: InOut + Sine
```

---

### Tween Color Transition - Color Transition

Smoothly changes the node's color.

**Parameters:**
- `target_node` - target node
- `target_color` - target color (Color)
- `duration` - duration (seconds)
- `easing_type` - easing type
- `trans_type` - transition type

**Typical uses:**
- Damage flash red
- Status indication (green = safe, yellow = warning)
- Environment changes

**Example:**
```
Color: white → red
Duration: 0.3 seconds
Purpose: character taking damage
```

---

## Preset Animation Instructions

### Tween Pop Animation - Pop-Out Animation

A springy pop effect that quickly pops out from scale 0.

**Parameters:**
- `target_node` - target node
- `target_scale` - target scale
- `duration` - duration

**Effect characteristics:**
- Uses TRANS_SPRING + EASE_OUT
- Starts from scale 0 and springs to the target value
- Suited to popups, chests, speech bubbles, etc.

**Typical uses:**
- Popup display
- Chest opening
- Bubble hints

**Example:**
```
Target scale: 1.0
Duration: 0.4 seconds
Effect: springy pop
```

---

### Tween Shake Animation - Shake Animation

A shake effect with configurable axes and intensity.

**Parameters:**
- `target_node` - target node
- `intensity` - shake intensity (pixels)
- `duration` - duration of each shake
- `shake_count` - number of shakes
- `shake_axis` - shake axis (X/Y/XY)

**Axes:**
- `X` - horizontal shake
- `Y` - vertical shake
- `XY` - shake in both directions

**Typical uses:**
- Hit feedback
- Explosion shake
- Error indication

**Example:**
```
Intensity: 15 pixels
Count: 3
Axis: XY
```

---

### Tween Bounce Animation - Bounce Animation

A bounce effect simulating the rebound after a fall.

**Parameters:**
- `target_node` - target node
- `bounce_height` - bounce height (pixels)
- `bounce_count` - number of bounces
- `duration` - duration

**Effect characteristics:**
- Uses TRANS_BOUNCE + EASE_OUT
- Bounces when reaching the target
- Suited to falling effects

**Typical uses:**
- Item drops
- Bouncing balls
- Landing effects

**Example:**
```
Bounce height: 50 pixels
Count: 3
Duration: 0.5 seconds
```

---

### Tween Pulse Animation - Pulse Animation

A breathing/pulsing effect with back-and-forth scale animation.

**Parameters:**
- `target_node` - target node
- `min_scale` - minimum scale
- `max_scale` - maximum scale
- `duration` - duration of one loop
- `loop_count` - loop count (0 = infinite loop)

**Loops:**
- `loop_count = 0` - infinite loop (must be stopped manually)
- `loop_count = 3` - stops after 3 loops

**Typical uses:**
- Idle animations
- Breathing effects
- Interactivity hints

**Example:**
```
Min scale: 0.9
Max scale: 1.1
Duration: 1.0 seconds
Loops: 0 (infinite)
```

---

## Advanced Features

### Tween Property - Generic Property Animation

Animates any property of a node, including Material animations.

**Parameters:**
- `target_node` - target node
- `property_path` - property path (dropdown selection)
- `to_value` - target value
- `duration` - duration
- `auto_free` - whether to free the node automatically
- `easing_type` - easing type
- `trans_type` - transition type

**Supported property types:**
- Basic properties: position, scale, rotation, modulate, etc.
- Sub-properties: modulate:a, position:x, position:y, etc.
- Material properties: material, material_override
- Shader parameters: material:shader_param/name

**Material animation support:**
- Shared Material
- Material Override
- Shader uniform parameters

**Typical uses:**
- Special property animations
- Material effect animations
- Shader parameter animations

**Example:**
```
Property: modulate:a (alpha)
Target value: 0.0
Duration: 1.0 seconds
```

---

## Parameter Reference

### Easing Type

Controls how the animation speed changes.

| Easing type | Effect | Typical use |
|---------|------|---------|
| **In** | Slow start, fast end | Gravity falls, accelerating starts |
| **Out** | Fast start, slow end | Decelerating stops, smooth landings |
| **InOut** | Slow start and end | Smooth movement, UI transitions |
| **OutIn** | Fast start and end | Quick transitions |

**Recommendations:**
- UI animations: Out
- Natural movement: InOut
- Falling effects: Out

---

### Transition Type

Controls the mathematical curve of the animation.

| Transition type | Effect | Typical use |
|---------|------|---------|
| **Linear** | Linear, constant speed | Simple movement |
| **Sine** | Sine curve | Natural motion, smooth transitions |
| **Quad** | Quadratic curve | Basic acceleration/deceleration |
| **Cubic** | Cubic curve | Standard animation curves |
| **Back** | Overshoot rebound | UI slide-ins, pop effects |
| **Spring** | Springy effect | Elastic animations, quick pops |
| **Bounce** | Bounce effect | Falling animations, landing effects |
| **Elastic** | Elastic stretch | Exaggerated animations, special effects |

**Recommendations:**
- UI interactions: Out + Back or Spring
- Natural movement: InOut + Sine
- Falling effects: Out + Bounce
- Elastic effects: Out + Elastic

---

## Common Use Cases

### Scenario 1: UI Button Hover Effect

**Goal:** enlarge the button on mouse hover

**Implementation:**
1. Use **Tween Scale To**
2. Target scale: `Vector2(1.1, 1.1)`
3. Duration: `0.1` seconds
4. Easing: `Out` + `Back`

**Fuse events:**
```
On Mouse Enter → Tween Scale To (1.1)
On Mouse Exit → Tween Scale To (1.0)
```

---

### Scenario 2: Character Hit Feedback

**Goal:** flash and shake the character when it takes damage

**Implementation:**
1. Use **Tween Shake Animation**
2. Intensity: `10` pixels
3. Count: `3`
4. Axis: `XY`

**Fuse events:**
```
On Take Damage → Tween Shake Animation
```

---

### Scenario 3: Item Collection Effect

**Goal:** enlarge and fade out the item when collected

**Implementation:**
1. Use **Tween Scale To** (scale up to 1.5x)
2. Use **Tween Fade Out** (auto_free = true)
3. Run in parallel

**Fuse events:**
```
On Item Collected → Parallel:
    - Tween Scale To (1.5)
    - Tween Fade Out (auto_free = true)
```

---

### Scenario 4: Popup Display

**Goal:** pop the window up from zero scale with a springy pop

**Implementation:**
1. Use **Tween Pop Animation**
2. Target scale: `Vector2(1, 1)`
3. Duration: `0.4` seconds

**Fuse events:**
```
On Show Popup → Tween Pop Animation
```

---

### Scenario 5: Infinite Breathing Effect

**Goal:** pulse the button endlessly to hint that it is interactive

**Implementation:**
1. Use **Tween Pulse Animation**
2. Min scale: `0.95`
3. Max scale: `1.05`
4. Loop count: `0` (infinite)

**Fuse events:**
```
On Quest Available → Tween Pulse Animation (loop = 0)
On Quest Accepted → Cancel Pulse Animation
```

---

## Best Practices

### 1. Choosing Animation Durations

- **Fast feedback:** 0.05-0.15 seconds (button clicks, flashes)
- **UI animations:** 0.2-0.5 seconds (fades, slides)
- **Character actions:** 0.3-0.8 seconds (movement, attacks)
- **Cutscene animations:** 0.5-2.0 seconds (scene switches, complex sequences)

### 2. Pairing Easing and Transitions

- **UI interactions:** Out + Back or Spring
- **Natural movement:** InOut + Sine
- **Falling effects:** Out + Bounce
- **Elastic effects:** Out + Elastic

### 3. Performance

- Avoid running too many Tweens at once (keep it under 50)
- Use `auto_free` to clean up temporary objects automatically
- Remember to stop infinite loop animations (Pulse) manually
- Consider object pools when animating large numbers of objects

### 4. Code Organization

- Wrap commonly used animations into Fuse Events
- Use Signals to connect animation completion callbacks
- Keep animation logic clear and readable
- Give animations meaningful resource names

### 5. Debugging Tips

- Check resource names in the editor to confirm parameters
- Use `FuseLogger` for debug logging
- Verify animation effects in a test scene
- Check that node paths are correct

---

## FAQ

### Q: Why doesn't the animation play?

**Possible causes:**
1. Wrong target node path
2. The node was freed before the animation started
3. Incorrect execution context

**Fixes:**
- Check the `target_node` path
- Confirm the node exists in the scene tree
- Check the FuseLogger logs

---

### Q: How do I run other actions after an animation completes?

**Method:**
Use the Fuse Event system's signal connections:
1. Create a Tween Animation Completed Event
2. Trigger follow-up actions when the animation completes

---

### Q: How do I stop an infinite loop animation?

**Method:**
Call the instruction's `cancel()` method:
1. Keep a reference to the Tween Pulse Animation instruction
2. Call `cancel()` when you need to stop it

---

### Q: Can multiple animations play at the same time?

**Answer:**
Yes! Use Fuse's parallel execution:
1. Use ActionRunner's parallel execution
2. Or add multiple Tween instructions to the same Event

---

### Q: How do I animate a custom property?

**Method:**
Use the **Tween Property** instruction:
1. Select the target node
2. Pick any writable property from the property list
3. Set the target value and parameters

---

## References

### Internal docs
- [Fuse Instruction Development Guide (Chinese)](../../../zh_CN/dev_docs/guides/instruction-creation-guide.md)

### External resources
- [Godot Official Documentation - Tween](https://docs.godotengine.org/en/stable/classes/class_tween.html)
- [Easing Functions Cheat Sheet](https://easings.net/)

---

## Changelog

**2026-01-28**
- Initial version
- Complete usage guide covering all 11 Tween instructions
- Added common scenario examples and best practices

---

**Maintainer:** JuicyGodot project team
**License:** internal project documentation
