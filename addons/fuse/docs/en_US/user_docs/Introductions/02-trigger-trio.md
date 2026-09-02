> 🌐 [**中文版**](../../../zh_CN/user_docs/Introductions/02-触发器三件套.md) | English

# Build Your First Game Logic in 5 Minutes: Choosing Between Runner / Trigger / MultiEventTrigger

By the end of this chapter you will have used Fuse to build your first genuinely runnable piece of game logic within 5 minutes, and — facing any "when X happens, do Y" requirement — you'll be able to decide within ten seconds whether to use a Runner, a Trigger, or a MultiEventTrigger. This selection determines the foundation of everything you build afterwards; choosing wrong makes every later change more painful.

The previous chapter gave you the full capability map of Fuse. The numbers Event 70 / Instruction 185 / Condition 55 look intimidating, but the reader's real next question is usually another one: "I understand the map — where do I put my foot down first?" This chapter exists precisely for that. No concept-laying; we build three examples from scratch and feel out the boundaries of the three trigger types.

## The Trio: Three Keys to Fuse's Event Entrypoints

All "event-driven" logic in Fuse ultimately lands on a node: it listens for some event, then runs the ActionRunner (instruction sequence) attached to it. Runner, Trigger, and MultiEventTrigger are three forms of this entrypoint node, differing only in "what they listen to" and "how much they can control".

A table first, to build a global impression:

| Component | One-line positioning | Typical scenarios |
|---|---|---|
| Runner | Wraps an ActionRunner into a node, listening to one signal or called directly from code | Button clicks, Timer callbacks, code await |
| Trigger | The standard trigger carrying an Event resource, with trigger_once / cooldown / event parameters | Input, collision, lifecycle, animation events |
| MultiEventTrigger | Packs multiple event-action bindings into one node | Merged management of one entity's many behaviors |

Keep one main line in mind: in terms of control power, the order from weak to strong is Runner → Trigger → MultiEventTrigger, but lightness goes the other way. The Runner is the lightest and can be awaited from code; the Trigger is the most commonly used and is the standard unit of the event system; the MultiEventTrigger is for scenarios where "one node must respond to a bunch of events". Now let's walk through three examples.

## Runner: Button Clicks and Awaiting from Code

The Runner is the fastest component to get started with, because it doesn't need an Event resource at all — pick a target node, pick a signal, and the binding is done. Let's build the most classic "click a button, print a log".

**Step one, build the scene tree:**

```
UI
  Button          ← a plain Button
  Runner          ← add a child node, search "Runner"
```

**Step two, configure the Runner's three core properties:**

| Property | Value | Purpose |
|---|---|---|
| action_runner | New ActionRunner | Holds the instruction sequence |
| target_node | ../Button | Points at the button |
| signal_name | pressed | Listens for the pressed signal |

`target_node` and `signal_name` will automatically list all available signals of the target node in the Inspector; just pick `pressed` from the dropdown — no hand-typing strings.

**Step three, stuff instructions into the ActionRunner.** Double-click the new ActionRunner resource to edit it, click the `+` on the instructions array, pick a **Print**, and type "按钮被点了" into `message`. Save, press F5 to run, click the button — there's your console output. The whole process wrote zero lines of code and created zero Event resources.

[Figure 1: The Runner's three-property configuration in the Inspector, with target_node / signal_name / action_runner highlighted]
*Caption: The Runner's entire configuration is just these three items; signal names come straight from a dropdown — no strings to memorize.*

The Runner's real killer feature isn't signal binding — it's that code can `await` it. That's a capability neither of the other two components has. Say you want to wait in code for a death animation to finish before cleaning up the scene:

```gdscript
@onready var runner: Runner = $Runner

func _die() -> void:
    runner.run()                    # 触发死亡指令序列（含播放动画等）
    await runner.wait_completed()   # 等指令序列全部跑完
    print("死亡动画播完了，可以清理场景")
    queue_free()
```

The key is `await runner.wait_completed()` — it turns a visual instruction sequence into an asynchronous operation code can wait on. Even if the sequence contains time-consuming instructions like `Wait` or `TweenProperty`, the code dutifully waits for it to finish before moving on. This is extremely useful in the hybrid style of "visuals for presentation + code for orchestration": the designer drags the presentation together in an ActionRunner, and the programmer controls timing in the script.

The Runner also provides three signals — `execution_completed(total_time)` / `execution_failed(error)` / `execution_canceled(reason)` — plus a set of execution-control APIs: `is_running()`, `cancel()`, `reset()`. Consult the Runner guide when you need them.

**When should you NOT use a Runner?** If you need any of the following, it can't cope and you should switch to a Trigger:
- Input events (keyboard / mouse / gamepad), physics collision events
- trigger_once (fire only once) or a cooldown mechanism
- Event parameters passed to instructions (say, a collider reference, an input vector)
- Condition checks

## Trigger: Taking Damage on Contact, with a Cooldown

Runners can't handle physics collisions or firing control, and that's exactly the Trigger's home turf. Let's build the "character takes damage on touching an enemy, with no repeated damage within 0.5 seconds" example — a piece of logic nearly every platformer and action game has.

**Scene tree:**

```
Player
  CollisionShape2D
  Trigger (OnHit)
    event_definition: OnBodyEntered
    action_runner: hurt_actions
    cooldown_mode: GLOBAL_COOLDOWN
    cooldown_time: 0.5
```

The biggest difference from the Runner: a Trigger doesn't pick a target node + signal directly — it configures an **Event resource** (`event_definition`). This Event resource is what actually defines "when it fires". Here we use `OnBodyEntered`, meaning it triggers when a physics body enters the Player's area.

Configuring just that isn't enough — losing HP to any touch is clearly wrong; bullets, coins, and friendly units would all count. That's why the Event resource also has a `target_group` field: fill in `"Enemy"`, and only colliders in the Enemy group will trigger it. This is the "event parameter filtering" a Runner cannot do.

**Cooldown against repeat triggering.** A character usually gets a window of invulnerability after taking damage, otherwise grazing an enemy repeatedly would zero out the health bar instantly. The Trigger ships two ready-made fields:

| Field | Fill in here | Purpose |
|---|---|---|
| cooldown_mode | GLOBAL_COOLDOWN | Global wait after the last trigger |
| cooldown_time | 0.5 | No re-trigger within 0.5 seconds |

There are two cooldown modes worth remembering: `GLOBAL_COOLDOWN` cools down globally after the last trigger — suited to "hurt invulnerability frames"; `PER_OBJECT_COOLDOWN` cools down per trigger source — suited to "having a cooldown against the same enemy, but different enemies each count separately".

Another frequently used field is `trigger_once` — for something like a run-once initialization when the scene is ready, just configure **OnReady** + trigger_once, no hand-written flag variable needed.

[Figure 2: The Trigger configuration, with the event_definition / target_group / cooldown key field groups highlighted]
*Caption: The Trigger's core is the Event resource; cooldown and trigger_once are firing controls the Runner lacks.*

**Event parameters flow into the context automatically.** This is the Trigger's hidden advantage over the Runner: when `OnBodyEntered` fires, that collider reference is automatically stuffed into the ExecutionContext, and subsequent instructions can read it directly through a variable — for example, use `SetVariable` to record "who hit me", then emit an event to notify the UI. The next chapter covers this in more detail when discussing variables.

Manual triggering has an interface too: `trigger_manually()` — but note it does **not support await**. If you absolutely must wait in code for a sequence to finish, that's a job for the Runner. This is the trade-off of selection: for await pick Runner; for event control and parameters pick Trigger.

## MultiEventTrigger: Merging a Pile of Triggers into One Node

After building for a while you'll notice Triggers piling up on the same entity. A Player typically needs, all at once: initialization on scene ready, jump on spacebar, damage on touching an enemy, death when health hits zero. Four Trigger nodes sprawled across the scene tree look messy and are annoying to manage.

The MultiEventTrigger exists to solve this — it packs multiple "event-action bindings" (EventBindings) into one node, and each binding can still independently configure cooldown, trigger_once, and conditions.

**The most satisfying usage isn't building from scratch — it's merging what already exists.** The practical path:

1. First build and verify each event type normally with Triggers (single-event debugging is more intuitive)
2. Select those Triggers in the scene tree, right-click → **Merge into MultiEventTrigger**
3. The system automatically creates a MultiEventTrigger, migrates all bindings over, and deletes the original Trigger nodes
4. Ctrl+Z undo is supported

After merging it looks like this:

```
Player
  CollisionShape2D
  MultiEventTrigger (PlayerEvents)
    EventBinding[0]:  OnReady           → init_actions    trigger_once: true
    EventBinding[1]:  OnInputKey(Space) → jump_actions
    EventBinding[2]:  OnBodyEntered     → hurt_actions    cooldown_time: 1.0
    EventBinding[3]:  OnHealthChanged   → death_actions   trigger_once: true
```

The scene tree shrinks from four trigger nodes to one, yet not a single binding's configuration is lost.

[Figure 3: Animated demo of the right-click merge / split operations]
*Caption: Select multiple Triggers and right-click to merge; the reverse is right-click to split, where each EventBinding becomes an independent Trigger again, auto-named after its event.*

**Splitting is the inverse of merging.** When a binding needs dedicated deep debugging, or the logic changed and you want to manage it separately, select the MultiEventTrigger and right-click → **Split into multiple Triggers**; each EventBinding becomes an independent Trigger node, auto-named after its event (such as OnInputKey, OnReady). Note one detail: the `enabled` property does not migrate during splitting, because ordinary Trigger nodes don't have that field.

**Per-binding independent control is this component's advanced value.** Each binding can individually:
- Configure its own conditions (`conditions`, composite conditions supported) — for instance, the jump binding only fires if "health > 0 and not on cooldown"
- Be toggled at runtime with `set_binding_enabled(index, false)` — for instance, after the player dies, disable both the jump and hurt bindings so the corpse can't bounce around
- Own independent cooldowns and trigger_once

To manually trigger a specific binding from code, use `trigger_binding(index)`; to reset all state use `reset()`.

On performance, the MultiEventTrigger is optimized too: multiple conditions are evaluated in parallel on the WorkerThreadPool, there's a batched-signal mode for high-frequency firing, and bindings that already fired their trigger_once or are cooling down get short-circuited. So after merging, not only is the scene tree clean — runtime overhead doesn't grow either.

When NOT to use a MultiEventTrigger? With only one event, a plain Trigger is more intuitive; when you need await, only the Runner can do it.

## Selection at a Glance

Compress the three sections above into a single decision path; follow it when a new requirement arrives:

1. Need to call from code, or to `await` completion? → **Runner**
2. Just listening to one simple signal, no filtering or control needed? → **Runner**
3. Need input events / physics collisions / lifecycle / animation events? → **Trigger**
4. Need trigger_once, cooldowns, or event parameter filtering? → **Trigger**
5. Multiple event-action bindings on the same entity? → **MultiEventTrigger** (you can build several Triggers first, verify them, then right-click to merge)
6. Need to enable/disable a specific binding at runtime, or per-binding conditions? → **MultiEventTrigger**

Re-check a few high-frequency scenarios:

| Scenario | Pick | Why |
|---|---|---|
| Button click opens a panel | Runner | Pure signal binding |
| Timer ends, spawns an enemy | Runner | Signal forwarding |
| Code awaits an animation finishing | Runner | The only one supporting await |
| Jump on spacebar | Trigger | Input event + possibly conditions |
| Damage on enemy contact, with cooldown | Trigger | Physics event + group filter + cooldown |
| Initialization on scene ready | Trigger | trigger_once |
| One NPC's many behaviors | MultiEventTrigger | Merged multi-event management |

If you can't memorize it, no problem — the trigger selection guide has the complete feature matrix and decision flowchart; look it up when needed.

## Summary

Runner, Trigger, and MultiEventTrigger are the three entrypoints to all event-driven logic in Fuse: the Runner is the lightest and can be awaited from code, the Trigger is the standard unit carrying the event system, and the MultiEventTrigger folds multiple bindings into a single node. Holding these three keys, you own a complete toolchain for quickly landing any "when X happens, do Y" — from today on, most game logic can be built without writing code.

Still, you may have noticed a detail in the examples: the Trigger stuffed a collider into the "context", and the Runner's instructions could also read and write variables. Where does this data actually live, who can read it, and what happens across scenes? That's the main thread of the next chapter.

Next chapter: "Don't Let Global Variables Run Wild: Managing Fuse's LOCAL / SCOPE / GLOBAL Three-Layer Variables" — making clear where data in visual logic comes from and where it goes, and how global variable persistence hooks into save files.
