> 🌐 [**中文版**](../../../zh_CN/user_docs/guides/40-input-conditions-guide.md) | English

# Input Conditions Guide

## Overview

Input conditions **evaluate** the current input state (pressed, held, released) rather than responding to input events. They are usually combined with condition branches inside a Trigger, so that the same event can take different paths depending on the input state. **6 conditions** in total, located in the `conditions/input/` directory.

| Condition | class_name | Function |
|------|-----------|------|
| CheckInputPressed | CheckInputPressed | Whether the input action was **pressed this frame** |
| CheckInputHeld | CheckInputHeld | Whether the input action is **currently held** |
| CheckInputReleased | CheckInputReleased | Whether the input action was **released this frame** |
| CheckInputDirection | CheckInputDirection | Gets the stick/keyboard direction vector and compares it |
| CheckInputMagnitude | CheckInputMagnitude | Gets the input strength and compares it |
| CheckAnyInput | CheckAnyInput | Whether **any** input action was triggered |

> **Input conditions vs input events:** input **events** (such as `OnInputAction`) are trigger-style — they run an instruction sequence when a press happens. Input **conditions** are evaluation-style — they branch inside an existing event. The two are complementary.

---

## Three-State Detection

### CheckInputPressed

**File:** `conditions/input/check_input_pressed.gd`
**class_name:** CheckInputPressed

Returns `true` on the frame the input action is pressed. Suited to one-shot triggers (jump, attack).

| Parameter | Type | Description |
|------|------|------|
| `action_name` | String | The input action name (corresponds to the Input Map) |

**Example:** Jump detection

```
OnInterval (every frame)
├── CheckInputPressed → action_name: "jump"
│   └── (perform the jump)
```

### CheckInputHeld

**File:** `conditions/input/check_input_held.gd`
**class_name:** CheckInputHeld

Returns `true` while the input action is being held. Suited to continuous behaviors (running, charging).

| Parameter | Type | Description |
|------|------|------|
| `action_name` | String | The input action name |

**Example:** Speed up while held

```
CheckInputHeld → action_name: "sprint"
├── true → (set the movement speed to 600)
└── false → (set the movement speed to 300)
```

### CheckInputReleased

**File:** `conditions/input/check_input_released.gd`
**class_name:** CheckInputReleased

Returns `true` on the frame the input action is released. Suited to release triggers (releasing a charged attack).

| Parameter | Type | Description |
|------|------|------|
| `action_name` | String | The input action name |

**Example:** Charged bow release

```
CheckInputReleased → action_name: "attack"
├── true → (fire the charged arrow)
└── false → (keep charging)
```

---

## Direction and Magnitude

### CheckInputDirection

**File:** `conditions/input/check_input_direction.gd`
**class_name:** CheckInputDirection

Gets the input direction vector (stick or keyboard) and compares it with a target direction.

| Parameter | Type | Description |
|------|------|------|
| `action_name` | String | The input action (usually a combination such as "move_left/right") |
| `direction` | Vector2 | The direction to compare against |
| `operator` | CompareOperator | Comparison mode: `EQUALS`, `APPROX` (approximate) |

### CheckInputMagnitude

**File:** `conditions/input/check_input_magnitude.gd`
**class_name:** CheckInputMagnitude

Gets the input strength and compares it with a threshold. Stick input returns a value between 0.0 and 1.0.

| Parameter | Type | Description |
|------|------|------|
| `action_name` | String | The input action |
| `operator` | CompareOperator | Comparison mode |
| `value` | float | The threshold to compare against |

---

## Any Input

### CheckAnyInput

**File:** `conditions/input/check_any_input.gd`
**class_name:** CheckAnyInput

Detects whether **any** input action was triggered this frame. Suited to generic skip-the-intro detection.

| Parameter | Type | Description |
|------|------|------|
| — | — | No parameters. Checks all actions registered in the Input Map |

**Example:** Skip the intro animation

```
OnReady
├── PlayAnimation → animation: "intro"
└── OnInterval (every frame)
    └── CheckAnyInput
        └── true → SkipAnimation
```

---

## Common Use Cases

### Hold-to-Charge Attack (Held + timing)

```
Trigger: OnProcess (every frame)
├── CheckInputHeld → action_name: "attack"
│   ├── true → CheckCountdownFinished → cooldown: "charge" (cooldown ready?)
│   │   ├── true → (charging… increase the charge variable)
│   │   └── false → (wait for the cooldown)
│   └── false → CheckInputReleased → action_name: "attack" (release)
│       └── true → (fire different attack tiers based on the charge variable)
```

### Double-Click Detection (Pressed + OnCountdown + CheckPressed)

```
Trigger: OnInputAction → action_name: "dodge"
├── (first press, start a 0.3s cooldown countdown)
└── OnInterval (check whether pressed again within 0.3s)
    └── CheckInputPressed → action_name: "dodge"
        └── true → (trigger the double-click dodge)
```

### Stick Sensitivity Check (Magnitude)

```
CheckInputMagnitude → action_name: "move", operator: GREATER_THAN, value: 0.5
├── true → (fast walk / run)
└── false → (slow walk when the stick is pushed slightly)
```

---

## Working with OnInputAction

Input conditions work best when combined with input events:

```
Trigger: OnInputAction → action_name: "interact"
├── (interact key pressed at any time)
├── Condition: CheckNodeProperty → target: Player, property: "nearby_object", operator: NOT_EQUALS, value: null
│   ├── true → (an interactable object exists)
│   │   ├── CheckInputHeld → action_name: "interact" (hold to interact)
│   │   │   ├── true → (run the hold-interact logic — e.g. a loading progress bar)
│   │   │   └── false → CheckInputReleased → action_name: "interact"
│   │   │       └── true → (tap to interact)
│   └── false → (no interactable object, ignore)
```

---

## Notes

0. **Node path or variable:** conditions with NodePath parameters (such as CheckInputActionMap) support both hard-coded node paths and node references passed dynamically through variables.
1. **Pressed vs Held:** `CheckInputPressed` returns true only on the **frame of the press**; `CheckInputHeld` returns true on **every frame the action is held**. Decide explicitly whether you want the "press instant" or "held continuously" when choosing.
2. **Difference from the OnInputAction event:** if all you need is "when X is pressed, do Y", the `OnInputAction` event is a better fit. Input conditions suit branch decisions inside an existing event sequence.
3. **Input Map:** make sure the input actions are registered in Godot's Input Map. Conditions do not create actions automatically.
