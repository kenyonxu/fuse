> 🌐 [**中文版**](../../zh_CN/user_docs/quick_start.md) | English

# Fuse Quick Start Guide

Welcome to the Fuse visual programming system! This guide will help you get up to speed with Fuse's basic features in 5 minutes.

## Table of Contents

1. [System Overview](#system-overview)
2. [Get Started in 5 Minutes](#get-started-in-5-minutes)
3. [Basic Concepts](#basic-concepts)
4. [Common Tasks](#common-tasks)
5. [Next Steps](#next-steps)

---

## System Overview

Fuse is a powerful visual programming system that lets you create complex game logic without writing code.

### Core Features

- **Visual programming**: create logic through drag-and-drop and configuration
- **Event-driven**: respond to game events (key presses, collisions, signals, etc.)
- **Instruction system**: a rich library of built-in instructions
- **Variable management**: global and local variable support
- **Easy to extend**: create custom events and instructions

### Use Cases

- Game logic control
- UI interaction handling
- Level event triggering
- Player state management
- Sound effect and VFX triggering

---

## Get Started in 5 Minutes

### Step 1: Choose a Trigger Type

Fuse provides three components for responding to events and executing instructions. Choose based on your needs:

| Component | Best For | Complexity |
|------|---------|--------|
| **Runner** | Listening to a single signal, calling from code | Low |
| **Trigger** | Needs event filtering or trigger control (trigger_once / cooldown) | Medium |
| **MultiEventTrigger** | Multiple event-action bindings on the same node | High |

> Not sure which to use? See the [Trigger Selection Guide](guides/02-trigger-selection-guide.md).

### Step 2: Add Nodes to the Scene

1. In the Godot editor, select a suitable parent node in the scene
2. Add a child node, search for and select the corresponding component name
3. Name the node, e.g. "OnButtonPress" or "PlayerEvents"

```
# Runner — 最简单的入门方式
场景树：
  UI
    Button
    Runner
      action_runner: (你创建的 ActionRunner 资源)
      target_node: ../Button
      signal_name: "pressed"
```

```
# Trigger — 需要更多控制时
场景树：
  Player
    CollisionShape2D
    Trigger (OnHit)
      event_definition: OnBodyEntered (Event 资源)
      action_runner: (你创建的 ActionRunner 资源)
```

### Step 3: Create an Action Sequence

An action sequence (ActionRunner) defines the series of instructions to be executed.

1. Select the trigger node you just created
2. In the Inspector panel, find the **action_runner** property
3. Click the dropdown and choose **New ActionRunner**
4. Double-click the newly created ActionRunner resource to edit it

### Step 4: Add Instructions

Instructions are the concrete units of operation.

1. In the ActionRunner resource editor, find the **instructions** property
2. Click the `[+]` button on the right of the array to add an instruction
3. Choose the instruction type to execute, for example:
   - `PrintVariableValue` — print a variable's value (for debugging)
   - `SetVariable` — set a variable's value
   - `RunTargetNodeFunction` — call a node method
   - `ChangeScene` — change the scene

### Step 5: Configure Instruction Parameters

Every instruction has configurable parameters. Take `PrintVariableValue` as an example:

1. Enter parameter values in the corresponding fields
2. You can use variable placeholders, e.g. `"{player_name} 得分了！"`
3. Configure the other optional parameters

### Step 6: Test Run

1. Save the scene
2. Press F5 to run the game
3. Trigger the event (click the button, press a key, collide, etc.)
4. Check the output in the console

**Congratulations! You have just created your first piece of Fuse logic!**

---

## Basic Concepts

### Events

Events are the conditions that trigger actions. Fuse provides a rich set of event types:

| Category | Examples |
|------|------|
| Lifecycle | OnSceneReady, OnEnterTree, OnExitTree |
| Input | OnInputKey, OnMouseEnter, OnMouseExit |
| Physics | OnBodyEntered, OnArea2DEnter |
| Animation | OnAnimationFinished, OnAnimationStarted |
| Audio | OnAudioFinished, OnAudioStarted |
| UI | OnButtonPressed, OnTextChanged, OnValueChanged |
| Custom | OnTargetSignalEmit (listens to any node signal) |

### Instructions

Instructions are the units of operation to be executed:

| Category | Examples |
|------|------|
| Control flow | IfElse, ForLoop, While, Wait |
| Variables | SetVariable, GetVariable, MathOperation |
| Node operations | MoveNode, RotateNode, SetProperty |
| Tween animation | TweenProperty |
| Audio | PlayAudio, StopAudio |
| Scene | ChangeScene, InstantiateScene |

### Variables

Variables are used to store and pass data:

- **Global variables**: accessible throughout the game, with persistence support
- **Local variables**: accessible within the trigger's scope
- **Execution context variables**: passed along the instruction execution chain (e.g. event parameters)

### Conditions

Conditions control whether instructions execute:

| Type | Description |
|------|------|
| CompareVariable | Compare variable values (greater than, equal to, etc.) |
| CheckVariable | Check a variable's boolean value |
| CheckNodeProperty | Check a node property |
| Composite conditions | Combine multiple conditions with AND / OR |

### Trigger Components

Fuse provides three trigger components; see the [Trigger Selection Guide](guides/02-trigger-selection-guide.md) for details:

| Component | Description | Detailed Docs |
|------|------|---------|
| **Runner** | Lightweight signal binding + code calls | [Runner Guide](guides/03-runner-guide.md) |
| **Trigger** | Standard trigger with an Event | — |
| **MultiEventTrigger** | Multi-event merged trigger | [MultiEventTrigger Guide](guides/04-multi-event-trigger-guide.md) |

---

## Common Tasks

### Task 1: Run Instructions on Button Click (Runner)

The fastest way — no Event resource needed:

1. Add a Button node and a Runner node to the scene
2. Configure the Runner:
   - **action_runner**: create an ActionRunner and add the instructions you want to execute
   - **target_node**: point it at the Button node
   - **signal_name**: choose `pressed`
3. Run the game and click the button

### Task 2: Key Press Triggered Logic (Trigger)

Create logic that executes instructions when the space key is pressed:

1. Add a Trigger node
2. Configure **event_definition**: create an OnInputKey Event resource
3. Configure **action_runner**: create an ActionRunner and add instructions
4. In OnInputKey, set input_action to `ui_accept`
5. Run the game and press the space key to trigger

### Task 3: Collision Detection Trigger (Trigger)

1. Make sure the Player has a CollisionShape2D
2. Add a Trigger node
3. Configure **event_definition**: create an OnBodyEntered Event resource
4. Configure **action_runner**: add damage-handling instructions
5. Optional: set **trigger_once** or **cooldown** to prevent repeated triggering

### Task 4: Merging Multiple Events (MultiEventTrigger)

When a node needs to respond to multiple events:

1. Add a MultiEventTrigger node
2. Add multiple EventBindings to the **event_bindings** array
3. Each binding independently configures event, action_runner, trigger_once, etc.
4. Or: create multiple Trigger nodes first, then right-click in the scene tree → **Merge into MultiEventTrigger**

---

## Next Steps

### Guides

- [Trigger Selection Guide](guides/02-trigger-selection-guide.md) — How to choose between Runner / Trigger / MultiEventTrigger
- [Runner Guide](guides/03-runner-guide.md) — Signal binding and code calls in detail
- [MultiEventTrigger Guide](guides/04-multi-event-trigger-guide.md) — Merging and splitting multiple events

### System Guides

- [Input Events Guide](guides/32-input-events-guide.md) — Keyboard, mouse, gamepad
- [Physics System Guide](guides/14-physics-guide.md) — Collisions, raycasting
- [Animation System Guide](guides/12-animation-guide.md) — Animation events and control
- [UI System Guide](guides/15-ui-guide.md) — Button focus, text input, value changes
- [Tween Animation Guide](guides/18-tween-animation-guide.md) — Fades, elastic animations
- [Audio System Guide](guides/13-audio-guide.md) — Sound playback and control
- [Flow Control Guide](guides/23-flow-control-guide.md) — Conditional branches, loops, waits
- [Breakpoint Instruction Guide](guides/26-breakpoint-guide.md) — Breakpoint instructions for debugging

### Variables and Expressions

- [Global Variables Manager](guides/54-global-variables-guide.md) — The global variable system
- [Global Variable Persistence](guides/54-global-variables-guide.md) — Saving and loading
- [Expression System](guides/05-expression-guide.md) — Runtime expression evaluation
- [Event Bus Guide](guides/34-event-bus-guide.md) — Cross-scene event communication

### Best Practices

- [Creating Custom Instructions](best_practices/custom_instruction.md) — Extend the instruction system
- [Creating Custom Events](best_practices/custom_event.md) — Extend the event system

### System Docs

- [Visual Programming System Architecture (Chinese)](../../zh_CN/system_docs/architecture/visual_programming_complete_design_summary.md) — System design overview
- [Instruction System Design (Chinese)](../../zh_CN/system_docs/architecture/instruction_system_design.md) — Instruction execution mechanism

---

## FAQ

### Q: Should I use Runner or Trigger?

**A**: Use Runner for simple signal binding, and Trigger when you need event filtering or trigger control. See the [Trigger Selection Guide](guides/02-trigger-selection-guide.md) for details.

### Q: How do I debug Fuse logic?

**A**: Set `DEBUG` in the **log_level** property of a Trigger or Runner, and detailed logs will be printed to the console at runtime. You can also insert `PrintVariableValue` instructions into an ActionRunner to print variable values.

### Q: What if a variable is not updating?

**A**: Check the following:

1. Whether the variable name is spelled correctly
2. Whether the variable scope is correct (global / local / execution context)
3. Whether there are error messages in the console

### Q: How do I call Fuse instructions from code?

**A**: Use a Runner node:

```gdscript
@onready var runner: Runner = $Runner

runner.run()
await runner.wait_completed()  # 等待执行完成
```

### Q: What is the instruction execution order?

**A**: Instructions execute sequentially by default (SEQUENTIAL); this can be changed via the ActionRunner's execution_mode:

- `SEQUENTIAL` — sequential execution (default)
- `PARALLEL` — parallel execution

---

## Getting Help

### Documentation Resources

- [User Documentation Index](README.md) — All user documentation
- [System Docs (Chinese)](../../zh_CN/system_docs/README.md) — In-depth technical documentation
- [Developer Docs (Chinese)](../../zh_CN/dev_docs/README.md) — Developer documentation

### Example Projects

- [Demo Scenes](../../../../../demos/) — Feature demos

### References

- [Godot Official Documentation](https://docs.godotengine.org/)
- [Game Creator Documentation](https://gamecreator.io/)

---

**Start your Fuse journey now!**

If you have any questions, feel free to consult the documentation or contact the development team.

---

**Last updated**: 2026-03-21
