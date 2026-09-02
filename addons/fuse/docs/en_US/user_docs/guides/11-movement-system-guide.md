> 🌐 [**中文版**](../../../zh_CN/user_docs/guides/11-movement-system-guide.md) | English

# Fuse Movement System User Guide

## Overview

The Fuse movement system provides a complete no-code movement control solution for Godot 4.x. Through visual programming, you can easily implement character movement, collision detection, and physics interaction without writing any code.

## Core Components

### 1. Events

#### OnInputActionComposite
Detects composite input actions (such as four-directional movement) and supports diagonal movement.

**Parameters:**
- `action_up` - Input action name for moving up
- `action_down` - Input action name for moving down
- `action_left` - Input action name for moving left
- `action_right` - Input action name for moving right
- `trigger_rate` - Trigger frame rate, controlling how often the event fires:
  - `60 FPS` - Smoothest (default, recommended)
  - `30 FPS` - Balanced performance
  - `20 FPS` - Low-end devices
  - `10 FPS` - Not recommended; noticeable stutter

**Features:**
- Automatic diagonal movement support (press two directions at once)
- Individual directions can be disabled (choose the "none" option)
- Fires events continuously while held down

**Example configuration:**
```
action_up = "move_up"
action_down = "move_down"
action_left = "move_left"
action_right = "move_right"
trigger_rate = 60 FPS  # Smoothest experience
```

### 2. Instructions

#### MoveCharacterBody2DComposite
Controls a CharacterBody2D node for four-directional movement, supporting three movement modes.

**Parameters:**
- `target_node` - Target CharacterBody2D node path
- `speed` - Movement speed (pixels/second)
- `move_mode` - Movement mode:
  - `DIRECT` - Sets velocity directly; precise control, suited to grid-based movement
  - `SMOOTH` - Smoothly interpolates toward the target speed; suited to smooth motion
  - `ACCELERATION` - Uses acceleration and friction; suited to a realistic physics feel
- `smooth_factor` - Smoothing factor (SMOOTH mode only); higher values change faster
- `acceleration` - Acceleration (pixels/second², ACCELERATION mode only)
- `friction` - Friction (pixels/second², ACCELERATION mode only)

**Recommended configuration:**
```
# Basic configuration
target_node = NodePath("..")
speed = 200.0
move_mode = DIRECT

# Smooth movement
move_mode = SMOOTH
smooth_factor = 10.0

# Physics-based movement
move_mode = ACCELERATION
acceleration = 1000.0
friction = 800.0
```

## Quick Start

### Step 1: Configure the InputMap

Define input actions in the project settings:

```gdscript
# Run in the project startup script
func setup_input_map():
    var actions = ["move_up", "move_down", "move_left", "move_right"]
    var keys = [KEY_W, KEY_S, KEY_A, KEY_D]

    for i in range(actions.size()):
        if not InputMap.has_action(actions[i]):
            InputMap.add_action(actions[i])
            var event = InputEventKey.new()
            event.keycode = keys[i]
            InputMap.action_add_event(actions[i], event)
```

### Step 2: Create the Character Scene

1. Create a `CharacterBody2D` node
2. Add a `CollisionShape2D` and set the collision shape
3. Add a visual node (such as `Sprite2D`)

### Step 3: Configure the Trigger

Add a Trigger component under the character node:

1. Right-click the character node → "Add Child Node"
2. Choose the "Trigger" node
3. Configure in the Inspector:
   - **Event**: select `OnInputActionComposite`
   - **ActionRunner**: add `MoveCharacterBody2DComposite`

### Step 4: Test

Run the scene and control the character with WASD or the arrow keys.

## Advanced Usage

### Custom Input Actions

You can use any InputMap action:

```
# Gamepad controls
action_up = "gp_face_up"
action_down = "gp_face_down"
action_left = "gp_face_left"
action_right = "gp_face_right"

# Or custom actions
action_up = "ui_up"
action_down = "ui_down"
```

### Adjusting Movement Speed

Tune the `speed` parameter to fit your game:

- Slow movement: `speed = 100.0`
- Normal movement: `speed = 200.0`
- Fast movement: `speed = 400.0`

### Choosing a Movement Mode

**DIRECT mode:**
- Sets velocity directly
- The most precise control
- Suited to grid-based movement and instant response
- No inertia or sliding

**SMOOTH mode:**
- Uses linear interpolation for a smooth transition to the target speed
- Smooth acceleration and deceleration
- Suited to games that need a smooth feel
- Smoothness controlled via `smooth_factor`

**ACCELERATION mode:**
- Simulates realistic acceleration and friction
- Has inertia and a sense of sliding
- Suited to action games and platformers
- Physics feel controlled via `acceleration` and `friction`

### Performance Optimization

**Choosing the right trigger frame rate:**

| Frame rate setting | Use case | Performance impact |
|---------|---------|---------|
| **60 FPS** | Action games, platformers, precise control needed | Higher system load, smoothest |
| **30 FPS** | General games, casual games | Balanced performance and smoothness |
| **20 FPS** | Low-end devices, mobile devices | Low system load, acceptable smoothness |
| **10 FPS** | Not recommended | Lowest system load, noticeable stutter |

**Performance tips:**
- Action games: use 60 FPS + DIRECT mode
- Casual games: use 30 FPS + SMOOTH mode
- Many characters: use 20 FPS + DIRECT mode
- Mobile platforms: use 30 FPS, adjust per device

## FAQ

### Q: The character doesn't move?

Check the following:
1. Is the InputMap configured correctly
2. Do the input action names match
3. Is the target_node path correct
4. Does the CharacterBody2D have a CollisionShape2D

### Q: Movement too slow or too fast?

Adjust the `speed` parameter:
- Increase the speed value = faster
- Decrease the speed value = slower

### Q: How do I get diagonal movement?

The system already supports diagonal movement! Just press two direction keys at the same time.

### Q: How do I use a gamepad?

Simply map InputMap actions to gamepad buttons:

```gdscript
# Map a gamepad button to an action
var joypad_event = InputEventJoypadButton.new()
joypad_event.button_index = JOY_BUTTON_DPAD_UP
InputMap.action_add_event("move_up", joypad_event)
```

## Example Scene

For complete examples, see:
- `demos/fuse/deep_tests/scenes/base_movement.tscn` (basic movement instruction tests)
- `demos/fuse/deep_tests/scenes/test_deep_movement.tscn` (CharacterBody2D composite movement in practice)

## Technical Support

If you run into problems, refer to:
- User docs: `addons/fuse/docs/user_docs/`
- System docs: `addons/fuse/docs/system_docs/`
- Development docs: `addons/fuse/docs/development/`

---

**Version:** 1.1
**Last updated:** 2026-02-08
**Compatibility:** Godot 4.7+

**Changelog:**
- v1.1 (2026-02-08): Updated movement mode descriptions, added detailed descriptions of the three modes, added a performance optimization guide
- v1.0 (2026-02-08): Initial version
