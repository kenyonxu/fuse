> 🌐 [**中文版**](../../../zh_CN/user_docs/guides/04-multi-event-trigger-guide.md) | English

# MultiEventTrigger Usage Guide

`MultiEventTrigger` is a composite trigger node that merges multiple event-action bindings into a single node, reducing the number of nodes in the scene.

## Overview

| Feature | Description |
|------|------|
| Node name | MultiEventTrigger |
| Inherits | BaseTrigger extends Node |
| Icon | Signal.svg |
| Core capability | Manages multiple event bindings in one node |

### Comparison with a Plain Trigger

| Feature | Trigger | MultiEventTrigger |
|------|---------|-------------------|
| Event count | 1 | Multiple (via EventBinding) |
| Condition checks | Configured separately | Configurable independently per binding |
| Cooldown control | Node level | Independent cooldown per binding |
| Parallel evaluation | Not supported | Supported (WorkerThreadPool) |
| Scene node count | Multiple nodes | 1 node |

## Creating a MultiEventTrigger

### Method 1: Add Directly

1. Right-click in the scene tree → Add Child Node
2. Search for "MultiEventTrigger"
3. After adding, configure `event_bindings` in the Inspector

### Method 2: Merge Existing Triggers (Recommended)

1. Select 2 or more Trigger nodes in the scene tree
2. Right-click → **Merge into MultiEventTrigger**
3. The system creates the MultiEventTrigger automatically and migrates all bindings
4. Undo (Ctrl+Z) restores the original nodes

## Configuring EventBinding

Each EventBinding contains the following configurable items:

| Property | Description |
|------|------|
| `event` | The triggering event (a BaseEvent resource) |
| `action_runner` | The instruction sequence to execute when triggered |
| `conditions` | Condition checks (optional, composite conditions supported) |
| `enabled` | Whether this binding is enabled |
| `trigger_once` | Whether it triggers only once |
| `cooldown_mode` | Cooldown mode |
| `cooldown_time` | Cooldown time (seconds) |

### Configuration Example

```
EventBinding[0]:
  event: OnSceneReady          # when the scene is ready
  action_runner: initialization instruction sequence
  trigger_once: true           # execute only once

EventBinding[1]:
  event: OnInputKey (space)   # when the space bar is pressed
  action_runner: jump instruction sequence
  conditions:
    - CheckAll:                # requirements:
      - Health > 0             #   alive
      - Not on cooldown             #   cooldown finished

EventBinding[2]:
  event: OnPhysicsBodyEnter   # on collision
  action_runner: hurt instruction sequence
  cooldown_mode: GLOBAL_COOLDOWN
  cooldown_time: 1.0           # 1-second cooldown
```

## Cooldown Modes

| Mode | Description | Use Case |
|------|------|----------|
| `GLOBAL_COOLDOWN` | Global wait after the last trigger | Prevents repeated triggers within a short time (e.g. taking damage) |
| `PER_OBJECT_COOLDOWN` | Independent cooldown per trigger source | Repeated triggers from the same object are cooled down; different objects are unaffected |

## Runtime Control

### Manual Triggering

```
# Trigger a specific binding manually from code
multi_event_trigger.trigger_binding(0)
multi_event_trigger.trigger_binding(1)
```

### Dynamic Enable/Disable

```
# Disable the second binding
multi_event_trigger.set_binding_enabled(1, false)

# Re-enable it
multi_event_trigger.set_binding_enabled(1, true)
```

### Resetting State

```
# Reset all trigger states and cooldown timers
multi_event_trigger.reset()
```

## Splitting a MultiEventTrigger

To restore a MultiEventTrigger into multiple standalone Triggers:

1. Select the MultiEventTrigger node in the scene tree
2. Right-click → **Split into Multiple Triggers**
3. Each EventBinding becomes a standalone Trigger node
4. Nodes are named automatically after the event (e.g. OnInputKey, OnSceneReady)
5. Undo (Ctrl+Z) restores the previous state

## Signals

| Signal | Description |
|------|------|
| `event_completed(context)` | Any binding finished executing |
| `event_stopped(reason, context)` | Any binding stopped executing |
| `event_completed_with_index(index, context)` | The specified binding finished executing |
| `event_stopped_with_index(index, reason, context)` | The specified binding stopped executing |

## Performance Optimizations

MultiEventTrigger has several built-in performance optimizations:

- **Parallel condition evaluation**: multiple conditions are checked in parallel in the WorkerThreadPool
- **Batched signal mode**: reduces signal overhead at high trigger frequencies
- **Short-circuit checks**: skips already-triggered trigger_once bindings and bindings on cooldown
- **Pre-allocated state arrays**: avoids dynamic lookups at runtime

## Notes

- Merging requires all Triggers to share the same parent node
- When splitting, the `enabled` property is not migrated (Trigger nodes have no such property)
- Multiple bindings can reference the same Event resource, each with its own runtime state
- If you only need simple single-event triggering, a plain Trigger is more intuitive
