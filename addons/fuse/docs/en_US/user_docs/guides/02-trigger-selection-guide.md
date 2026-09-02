> 🌐 [**中文版**](../../../zh_CN/user_docs/guides/02-trigger-selection-guide.md) | English

# Trigger Selection Guide: Runner, Trigger, and MultiEventTrigger

Fuse provides three components for responding to events and executing instruction sequences (ActionRunner). Each excels in different scenarios; this guide helps you choose for a concrete requirement.

## Quick Selection

**Pick what you need:**

- Quickly listen to a signal, or call from code → **Runner**
- Event parameter filtering, trigger control (trigger_once / cooldown) → **Trigger**
- Multiple event-action bindings on one node → **MultiEventTrigger**

---

## Overview of the Three

| Feature | Runner | Trigger | MultiEventTrigger |
|------|--------|---------|-------------------|
| Triggering | Signal binding / code call | Event resource (visual configuration) | Multiple Event resources |
| await support | `wait_completed()` | Not supported | Not supported |
| Trigger control | None | trigger_once, cooldown | Independent control per binding |
| Condition checks | None | None | Configurable conditions per binding |
| Event parameters | Not passed to the context | Passed to the ExecutionContext | Passed to the ExecutionContext |
| Node count | One node per action | One node per event | Multiple events share one node |
| Suited for | Programmers, rapid prototyping | Visual editing users | Experienced editing users |

---

## Runner: Lightweight Signal Binding and Code Calls

Runner is a node wrapper around ActionRunner. It does no event handling—it only "runs a set of instructions when a signal fires", or "is called directly from code".

### When to Use It

- **UI interaction**: execute instructions after a button click
- **Timer callbacks**: execute instructions when a timer finishes
- **Code orchestration**: `await runner.wait_completed()` in a script to wait for async execution to finish
- **Decoupling components**: listen to custom signals (such as `died`, `level_completed`) to trigger follow-up logic
- **Rapid prototyping**: no Event resource configuration needed—just pick a node + pick a signal

### When Not to Use It

- You need signal parameter filtering (e.g. "only trigger when the collider is in the Player group")
- You need trigger_once or a cooldown mechanism
- You need input events (keyboard, mouse, gamepad) or physics collision events
- You need condition checks

### Example

```
Scene structure:
  Player
    Sprite2D
    Runner (OnDeath)
      target_node: ..
      signal_name: "died"
      action_runner: death_actions  ← death-handling instruction sequence
```

```gdscript
# Code call + await
@onready var runner: Runner = $Runner

runner.run()
await runner.wait_completed()
print("死亡动画播放完毕，可以清理场景了")
```

> [!NOTE]
> The Runner's `target_node` and `signal_name` automatically list all available signals of the target node; just pick from the dropdown in the editor.

---

## Trigger: a Single Trigger with the Event System

Trigger is the standard unit of the Fuse event system. It defines trigger conditions through an Event resource and supports trigger control and event parameter passing.

### When to Use It

- **Physics collisions**: trigger on entering/leaving an Area (group filtering and collider deduplication supported)
- **Input events**: keyboard keys, mouse clicks, gamepad input
- **Lifecycle**: scene ready, node entering/exiting the tree
- **Animation events**: animation finished, reaching a specific frame/marker
- **Trigger control needed**: trigger_once (fires only once), cooldown time
- **Event parameters needed**: collider references, animation names, input vectors, etc., passed into the ExecutionContext

### When Not to Use It

- You only need to listen to one simple signal with no extra control (Runner is lighter)
- Multiple independent event-action bindings on the same node (MultiEventTrigger is more compact)
- You need await to wait for execution to finish (Runner supports it)

### Example

```
Scene structure:
  Player
    CollisionShape2D
    Trigger (OnHit)
      event_definition: OnBodyEntered
        target_group: "Enemy"       ← triggers only on enemy collisions
      action_runner: hurt_actions
      trigger_once: false
      cooldown_mode: GLOBAL_COOLDOWN
      cooldown_time: 0.5            ← no re-trigger within 0.5 seconds of taking damage
```

> [!NOTE]
> Event parameters in a Trigger (such as the collider or input vector) are automatically synced to the ExecutionContext, so subsequent instructions can access them directly as variables.

---

## MultiEventTrigger: Multi-Event Combined Trigger

MultiEventTrigger merges multiple event-action bindings into a single node, reducing the scene tree node count, with independent control per binding.

### When to Use It

- **Multiple events for one logical entity**: an enemy simultaneously listens for "hit", "death", and "AI state change"
- **Reducing node count**: several related trigger events merged into one node keeps the scene tree tidy
- **Per-binding conditions**: each EventBinding can be configured with different condition checks
- **Dynamic enable/disable**: toggle individual bindings at runtime

### When Not to Use It

- Only one event (a plain Trigger is more intuitive)
- You need await to wait for execution to finish (Runner supports it)
- No extra event-system control needed (Runner is lighter)

### Example

```
Scene structure:
  Player
    MultiEventTrigger (PlayerEvents)
      EventBinding[0]:              # scene ready
        event: OnSceneReady
        action_runner: init_actions
        trigger_once: true
      EventBinding[1]:              # hurt
        event: OnBodyEntered
        action_runner: hurt_actions
        cooldown_mode: GLOBAL_COOLDOWN
        cooldown_time: 1.0
      EventBinding[2]:              # death
        event: OnHealthZero
        action_runner: death_actions
        trigger_once: true
```

> [!NOTE]
> MultiEventTrigger supports being merged from multiple existing Trigger nodes (right-click in the scene tree → merge into a MultiEventTrigger) and can also be split back into standalone Trigger nodes.

---

## Decision Flow

```
Need to respond to events and execute instructions?
│
├─ Need input events (keyboard/mouse/gamepad) or physics events?
│  └─ Yes → Trigger or MultiEventTrigger
│
├─ Need trigger_once or cooldown control?
│  └─ Yes → Trigger or MultiEventTrigger
│
├─ Need event parameters (colliders, animation names, etc.)?
│  └─ Yes → Trigger or MultiEventTrigger
│
├─ Need await to wait for execution to finish?
│  └─ Yes → Runner
│
├─ Called from code rather than event-driven?
│  └─ Yes → Runner
│
├─ Only need to listen to one simple signal?
│  └─ Yes → Runner
│
├─ Multiple event-action bindings on one node?
│  └─ Yes → MultiEventTrigger
│
└─ Otherwise → Trigger
```

---

## Common Scenario Comparison

| Scenario | Recommended Component | Reason |
|------|---------|------|
| Button click opens the settings panel | Runner | Simple signal binding, no extra control needed |
| Timer finishes and spawns an enemy | Runner | Pure signal forwarding |
| Custom `died` signal triggers death | Runner | Signal-driven, simple enough |
| await execution completion in code | Runner | The only component supporting await |
| Jump on the space bar | Trigger | Input event + needs a condition (e.g. is on floor) |
| Taking damage on enemy contact (with cooldown) | Trigger | Physics event + group filter + cooldown |
| Special effect at a specific animation frame | Trigger | Animation frame event + parameter passing |
| Initialize when the scene is ready | Trigger (trigger_once) | One-time initialization |
| Multiple behaviors of one NPC | MultiEventTrigger | Multiple events merged, fewer nodes |
| Dynamic enable/disable at runtime | MultiEventTrigger | Independent control per binding |
| Listen to a signal from all nodes in a group | Trigger (OnSignalFromGroup) | Group signal listening |

---

## Feature Matrix

| Feature | Runner | Trigger | MultiEventTrigger |
|------|--------|---------|-------------------|
| Signal binding | target_node + signal_name | Via an Event resource | Via an Event resource |
| Code call `run()` | Supported | `trigger_manually()` | `trigger_binding(index)` |
| await completion | `wait_completed()` | - | - |
| trigger_once | - | Supported | Supported per binding |
| Cooldown time | - | Supported | Independent per binding |
| Condition checks | - | - | Supported per binding |
| Event parameter passing | - | Supported | Supported |
| Dynamic enable/disable | - | - | `set_binding_enabled()` |
| Merge via scene-tree right-click | - | → MultiEventTrigger | → multiple Triggers |
| UndoRedo support | - | - | Merge/split supported |
