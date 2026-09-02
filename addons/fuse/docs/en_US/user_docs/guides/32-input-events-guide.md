> 🌐 [**中文版**](../../../zh_CN/user_docs/guides/32-input-events-guide.md) | English

# Input Events Guide

Fuse provides 12 input events covering all input methods: keyboard, mouse, touch, gamepad, and text input.

## Event Overview

### Keyboard

| Event | Function | Key configuration |
|------|------|----------|
| OnInputKey | Keyboard key event | Key, trigger timing (pressed / released / repeat) |

### Mouse

| Event | Function | Key configuration |
|------|------|----------|
| OnMouseButton | Mouse button event | Button (left / right / middle), trigger timing |
| OnMouseMove | Mouse movement event | No extra configuration |
| OnMouseEnter | Mouse enters a Control node | No extra configuration |
| OnMouseExit | Mouse leaves a Control node | No extra configuration |

### Touch

| Event | Function | Key configuration |
|------|------|----------|
| OnTouch | Touch screen event | No extra configuration |
| OnTouchSwipe | Touch swipe gesture | Minimum swipe distance, swipe direction |

### Gamepad

| Event | Function | Key configuration |
|------|------|----------|
| OnGamepadButton | Gamepad button event | Button index, trigger timing |
| OnGamepadAxis | Gamepad stick/trigger event | Axis index, threshold (dead zone) |

### Input Map

| Event | Function | Key configuration |
|------|------|----------|
| OnInputAction | Input Map action event | Action name, trigger timing |
| OnInputActionComposite | Composite input action | Action combination configuration (e.g. WASD movement) |

### Text

| Event | Function | Key configuration |
|------|------|----------|
| OnInputText | Text input event | No extra configuration |

## Common Use Cases

### 1. Character Control

```
Move → OnInputActionComposite("move")
  → get the movement direction → MoveBy / SetVelocity

Jump → OnInputAction("jump", on pressed)
  → ApplyImpulse(upward force)

Dash → OnInputAction("dash", on pressed)
  → SetVelocity(dash direction)
  → Wait(0.2s)
  → SetVelocity(normal speed)
```

### 2. UI Interaction

```
Hover tooltip → OnMouseEnter
  → ShowHideUI(tooltip panel, show)

Mouse leaves → OnMouseExit
  → ShowHideUI(tooltip panel, hide)

Button click → OnMouseButton(left button, on pressed)
  → trigger the corresponding function
```

### 3. Gamepad Support

```
Gamepad attack → OnGamepadButton(button 0, on pressed)
  → run the attack logic

Gamepad aim → OnGamepadAxis(right stick X/Y, threshold=0.2)
  → get the stick direction → LookAt

Gamepad dash → OnGamepadAxis(left trigger, threshold=0.5)
  → perform the dash
```

### 4. Touch Gestures

```
Swipe left → OnTouchSwipe(direction=left)
  → switch to the previous option

Swipe right → OnTouchSwipe(direction=right)
  → switch to the next option

Tap → OnTouch
  → confirm the selection
```

## Context Data

When an input event fires, related data is passed through the ExecutionContext and can be accessed by subsequent instructions:

| Event | Data passed |
|------|-----------|
| OnInputKey | Key code, physical key code, pressed or not, Shift/Ctrl/Alt modifiers |
| OnMouseButton | Button index, pressed state, position, double-click state |
| OnMouseMove | Position, relative movement, velocity |
| OnTouch | Touch position, pressure |
| OnTouchSwipe | Start position, end position, direction, distance |
| OnGamepadButton | Device index, button index |
| OnGamepadAxis | Device index, axis index, axis value |
| OnInputAction | Action name, strength, pressed or not |
| OnInputText | The entered text |

## Notes

- OnInputKey and OnMouseButton support three trigger timings: **on pressed, on released, and repeat**
- OnMouseEnter / OnMouseExit only work on **Control nodes** (Button, Panel, etc.)
- OnGamepadAxis requires a **threshold** (dead zone) to avoid false triggers when the stick returns to center
- OnInputAction uses Godot's **Input Map** system and must be configured in Project Settings beforehand
- OnInputActionComposite automatically handles multi-key combinations (e.g. the up/down/left/right components of WASD)
- Touch events do not fire on non-touch devices
