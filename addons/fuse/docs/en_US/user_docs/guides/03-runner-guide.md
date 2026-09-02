> 🌐 [**中文版**](../../../zh_CN/user_docs/guides/03-runner-guide.md) | English

# Runner Usage Guide

`Runner` is a node wrapper around ActionRunner, providing signal binding, programmatic invocation, and awaitable execution. It suits signal-driven and code-called scenarios.

## Overview

| Feature | Description |
|------|------|
| Node name | Runner |
| Inherits | Node |
| Icon | Play.svg |
| Core capability | Wraps ActionRunner as a scene node |

### Runner vs Trigger

| Feature | Trigger | Runner |
|------|---------|--------|
| Triggering | Event-driven (input, collision, lifecycle, etc.) | Signal binding or programmatic call |
| Event configuration | Via BaseEvent resources | Via target_node + signal_name |
| awaitable | Not supported | Supports `wait_completed()` |
| Multiple events | Requires multiple Triggers or a MultiEventTrigger | A single ActionRunner |
| Typical scenarios | Key presses, collision responses | Button clicks, signal listening, code calls |

## Creating a Runner

1. Right-click in the scene tree → Add Child Node
2. Search for "Runner"
3. Configure in the Inspector:

| Property | Description |
|------|------|
| `action_runner` | The instruction sequence to execute (an ActionRunner resource) |
| `target_node` | Path of the node to listen to |
| `signal_name` | Name of the signal to listen to |
| `log_level` | Log level |

## Usage

### Method 1: Signal Binding (Automatic Triggering)

Listen to any signal of any node; instructions run automatically when the signal fires:

```
Scene structure:
  UI
    Button
    Runner
      action_runner: the instruction sequence to run on click
      target_node: ../Button
      signal_name: "pressed"

→ The user clicks the button → the pressed signal fires → the Runner executes its instructions
```

Common signal binding examples:

| Target Node | Signal Name | Description |
|---------|--------|------|
| Button | pressed | Button clicked |
| Timer | timeout | Timer finished |
| AnimationPlayer | animation_finished | Animation finished playing |
| Area2D | body_entered | A body entered the area |
| HSlider | value_changed | Slider value changed |

### Method 2: Code Call (Programmatic Triggering)

```gdscript
# Get a Runner reference
@onready var runner: Runner = $Runner

# Execute manually
runner.run()

# Execute with a context node
runner.run(context_node)

# Wait for execution to finish
runner.run()
await runner.wait_completed()
print("指令执行完毕")

# Cancel execution
runner.cancel("用户取消")
runner.stop()  # equivalent to cancel

# Check the state
if runner.is_running():
    print("正在执行中")

# Reset (cancel execution + disconnect signals + clean up instances)
runner.reset()
```

## Signals

| Signal | Parameters | Description |
|------|------|------|
| `execution_completed` | `total_time: float` | Execution completed (with elapsed time) |
| `execution_failed` | `error_message: String` | Execution failed |
| `execution_canceled` | `reason: String` | Execution was canceled |

### Signal Usage Example

```
Scene structure:
  Player
    HealthComponent
    Runner (OnDeath)
      target_node: ../HealthComponent
      signal_name: "died"
      action_runner: death-handling instruction sequence

→ Health reaches zero → the died signal fires → the Runner executes the death instructions
```

## Execution Control

### Full Execution Lifecycle

```
run() → create ExecutionContext → RuntimeActionRunnerInstance.run()
  → execute instructions one by one
  → all finished → execution_completed.emit(total_time)
  → an error occurs → execution_failed.emit(error_message)
  → canceled → execution_canceled.emit(reason)
```

### Querying Execution State

```gdscript
var status: Dictionary = runner.get_execution_status()
# Returns a dictionary with detailed state information
```

## Notes

- Runner is not part of the event system and has no Event concept; it suits simple signal-driven scenarios
- For event-driven logic such as input events or physics collisions, use Trigger or MultiEventTrigger
- `target_node` uses a NodePath; if the target node is deleted, the Runner cleans up automatically
- Modifying the `action_runner`, `target_node`, or `signal_name` properties rebuilds the runtime instance automatically
- `wait_completed()` is an awaitable method and can only be used inside async functions
