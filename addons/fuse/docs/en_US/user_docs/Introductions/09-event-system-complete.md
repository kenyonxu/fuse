> 🌐 [**中文版**](../../../zh_CN/user_docs/Introductions/09-事件系统全解.md) | English

# Triggers Explained: Fuse Lifecycle, Timing Events, and the Event Bus

The previous eight chapters have used the word "event" countless times: input events, physics events, UI events, animation events. But you may never have had the chance to look at the whole picture systematically: how many kinds of events does Fuse actually have, what is each one's temperament, and when should you use which. This chapter fills that gap, and puts its weight on Fuse's most differentiating feature, the Event Bus—it is not just "another event type", but the key design that truly decouples logic and enables cross-scene communication. After reading, you will know which event each kind of trigger should be paired with, and how to use the event bus to split systems that used to be entangled together into mutually independent modules.

Picking up from the previous chapter: events have been used many times, but never systematically surveyed.

## The Big Picture First: Four Event Categories, Each with Its Own Domain

Fuse's event source code lives in several subdirectories under `events/`, grouped by responsibility into four major categories.

**Lifecycle events**: bound to node lifecycle callbacks, they answer "when is this node born, when does it run each frame, when does it die". They include `OnReady`, `OnEnterTree`, `OnExitTree`, `OnProcess`, `OnPhysicsProcess`, `OnInterval`, `OnIntervalWithVariable`. They are the "heartbeat" of logic.

**Timing events**: they deal with time, answering "how long until the next run", "is the cooldown ready", "how many seconds are left". They include `OnTimer`, `OnCooldownFinished`, `OnCountdown`, `OnRealtime`. They govern rhythm and cooldowns.

**Node events**: they listen to node state changes or signals, answering "did this property change", "was this signal emitted", "was this scene instantiated". They include `OnPropertyChanged`, `OnTargetSignalEmit`, `OnSignalFromGroup`, `OnNodeInstance`. They wire Godot's native signal system into visual logic.

**Event Bus**: Fuse's own global event bus for cross-Trigger, cross-scene communication—the real moat of this system. Each category is expanded below, with extra ink on the Event Bus.

## Lifecycle Events: Don't Let OnProcess Tank Your Frame Rate

Among lifecycle events, the first thing to get straight is "trigger frequency". Two events can both be periodic yet differ wildly in cost.

Three are one-shot and all cheap. `OnReady` maps to `_ready()`, firing once after the scene tree is ready—the standard entry point for initialization: setting initial health, binding signals, loading config, and building the HUD all belong here. It also has a `delay_seconds` parameter for delayed triggering, leaving one frame for other nodes to get ready first. `OnEnterTree` fires even earlier than `OnReady`, as soon as the node enters the scene tree—at that point the parent may not be ready yet, so most initialization should still use `OnReady`, reserving `OnEnterTree` for special cases. `OnExitTree` maps to the node exiting the scene tree, the standard entry point for cleanup: saving progress, disconnecting signals, releasing resources.

The two frame-loop events are the dangerous ones. `OnProcess` maps to `_process(delta)` and fires **every frame**; the docs give a direct performance warning. Hang even a slightly complex instruction chain on it and your frame rate drops visibly. It must be paired with `execution_interval` to throttle down—the default is 0.016 (about 60 FPS); you should set it to at least 0.1 (at most 10 times per second). `OnPhysicsProcess` maps to `_physics_process` at a fixed rate (default 60 FPS), and should only be used for physics-related updates, like the character movement in the previous chapter.

Here is a very practical piece of advice: **the vast majority of "continuous checks" should not use `OnProcess` at all—they should use `OnInterval`**. `OnInterval` fires periodically at a fixed number of seconds; you control `interval_seconds`, making it far more predictable and far better for performance than `OnProcess`. Take "scan for nearby enemies every 2 seconds": with `OnProcess` you scan every frame—60 times a second (wasteful); with `OnInterval` at 2.0 you scan once every 2 seconds (precise).

```
OnInterval  interval_seconds: 2.0, max_repeats: 0
└── CheckDistance  target_a: Player, target_b: Enemy, operator: LESS_THAN, value: 10.0
    └── (enemy in range, start combat)
```

`OnIntervalWithVariable` is the advanced version of `OnInterval`: the interval value is read dynamically from a variable and can change at runtime. For "difficulty ramps up, enemies spawn faster and faster", just shrink the interval variable over time—no logic rewrite needed.

The docs provide a very handy performance tier list worth memorizing: `OnReady`/`OnEnterTree`/`OnExitTree` are low—use freely; `OnInterval`/`OnIntervalWithVariable` are medium—keep the interval no smaller than 0.033 seconds; `OnProcess`/`OnPhysicsProcess` are high—must be throttled and used only when nothing else will do.

## Timing Events: Four Different Clocks

The four timing events differ essentially in "which time scale they use" and "their trigger pattern".

`OnTimer` is equivalent to Godot's `Timer` node, firing periodically per `wait_time`; a `repeat_count` of 0 means infinite looping. It is the most direct choice for periodic jobs like "spawn a wave of enemies every 10 seconds". It is affected by game time—meaning it stops when the game pauses.

`OnCooldownFinished` is dedicated to skill cooldowns. Its essence is the `manual_trigger` parameter: set to true, the cooldown does not restart automatically; instead it waits for you to trigger it manually—only then does the cooldown start, and it notifies you when it finishes. Combined with the `CheckCountdownFinished` condition (countdown finished) to check cooldown state, you can build the standard skill system where "pressing during cooldown does nothing, and pressing when ready fires instantly". It also has a `show_progress` option that writes a cooldown progress value from 0.0 to 1.0 into a variable; a UI cooldown ring can read this value directly.

`OnCountdown` is a countdown that keeps firing over a specified duration, with `update_interval` controlling the update frequency. It writes the remaining time into a variable; for timed levels, the on-screen countdown digits just read that variable and refresh.

`OnRealtime` is the most special of the four: it is based on **real-world time**, unaffected by `time_scale` and pausing. It keeps running while the game is paused. So it only fits needs tied to the real world—daily quest resets, offline reward calculation, anti-cheat timing. **Never** use it for in-game logic: pause the game and your character's jump cooldown keeps ticking, which feels deeply wrong.

| Dimension | OnTimer | OnCooldownFinished | OnCountdown | OnRealtime |
|------|---------|--------------------|-------------|------------|
| Time scale | Game time | Game time | Game time | Real time |
| Affected by pause | Yes | Yes | Yes | No |
| Trigger pattern | Periodic/single | Instant on cooldown end | Continuous updates | Periodic |
| Typical use | Spawning waves | Skill cooldown | Timed levels | Daily resets |

## Node Events: Wiring Godot Signals into Visual Logic

The four node events handle "node-level state changes and signals", and two of them hide easy-to-trip details.

`OnPropertyChanged` (property changed) listens for changes to a property on a target node, such as health or position. But it uses **polling mode**, checking the property value periodically per `check_interval` rather than true signal binding. That means the response is delayed (up to the check interval), and high-frequency properties need the interval pushed below 0.05 seconds. Its advantage: the target node doesn't need to declare signals in advance—any property can be watched.

`OnTargetSignalEmit` (target signal emitted) listens to a specific signal of a specific node—true signal binding, zero latency. And it has editor integration: after picking the target node, the signal dropdown automatically caches all signals available on that node—no hand-typing names. `trigger_once` limits it to a single response, and `filter_signal_args` can filter by signal argument values—for example, respond only when the `health_changed` signal carries a "damage taken" argument. For button clicks, pairing it with the `pressed` signal is the most reliable choice.

`OnSignalFromGroup` (group signal listening) is the bulk version of `OnTargetSignalEmit`: it listens for the specified signal from **any** node in a group. Logic like "any enemy in the group dying grants score" is done with a single event—no per-enemy listeners needed. Note that group names are case-sensitive.

`OnNodeInstance` (node instantiated) fires when the specified scene is instantiated—a great fit for "initialize the boss's health once the boss room finishes loading" or "run follow-ups once a preloaded scene is ready". Matching is by scene path, which must exactly match the path used at instantiation (including `.tscn`).

These four node events are already powerful, but they are all confined to "within the same scene tree". The moment you need scene A to notify scene B, or a global system to react to a state change in any module, they fall short. That's when the Event Bus takes the stage.

## The Event Bus: Fuse's Moat

The Event Bus deserves the extra ink because it is the key design that sets this visual system apart from "scripts translated into nodes". It is a global event bus: any Trigger can send events onto it, and any Trigger can receive events from it—senders and receivers know nothing about each other and depend on nothing of each other.

**The basic model** is like a radio station. `SendEvent` (send event) is the station, `OnReceiveEvent` (receive event) is the radio, and the event name is the channel. The sender just calls out `"player_died"`, and every receiver Trigger tuned to that channel responds in its own way. The sender has no idea—and doesn't need to know—who is listening. That is the essence of loose coupling.

```
Trigger A (player system)         Trigger B (game-over UI)       Trigger C (enemy AI)
  SendEvent "player_died"   →   OnReceiveEvent "player_died"   OnReceiveEvent "player_died"
                                   show GameOver UI               stop all enemies
```

The direct payoff of this design: to add a new response to "player death", just add another Trigger listening for `"player_died"`—the player's sending logic stays untouched. The more complex the system, the more this decoupling is worth.

**Communication with arguments** is the Event Bus's second layer of capability. `SendEvent`'s `Event Args` is a dictionary that can carry arbitrary data; when the receiver enables `Store Args to Local`, those arguments are automatically stored as local variables, with a default prefix of `event_`. Send `{"item_id": "sword", "count": 1}` and the receiver's instruction chain can directly use `event_item_id`, `event_count`. Cross-module data passing is this clean—no shared global variables needed.

**One-shot events** use the `Trigger Once` option. First-launch tutorials and first-clear achievements—logic that "should fire only once"—just flip this switch and skip managing your own "has it fired already" state variable.

**Deferred sending** uses the `Deferred` option. It postpones the event to the end of the frame, avoiding a pile-up of many events within the same frame, smoothing load during dense broadcasts.

**Naming conventions** are the key to using the Event Bus well, and the docs give explicit advice: use a module prefix with a dot separator, e.g. `player:died`, `quest:completed`, `ui:refresh`, `scene:loaded`. Avoid names like `died` (too vague), `event1` (meaningless), or `playerDied` (inconsistent style). A clear naming convention is itself the best documentation—you know which module sent it and what kind of thing happened just from the name.

**Debug history** is a thoughtful engineering touch on the Event Bus. The bus node `FuseEventBus` keeps a history of the last 100 events, with event name, arguments, and timestamps. When an event "isn't received", this is the first place to investigate: find `FuseEventBus` in the scene tree, inspect `event_history`, and confirm whether the event was actually sent and whether the arguments are right. Far faster than hunting for a needle in a haystack of dozens of Triggers.

Let's build a working cross-scene communication case. Scenario: the player dies in the combat scene, and the main-menu system must be notified to show the results screen. Two Triggers in different scenes, connected by the Event Bus.

Sender side (combat scene, on the player's Trigger):

```
OnHealthChanged  (when health hits zero)
└── SendEvent  event_name: "player:died", event_args: {"score": "{local:score}"}, deferred: true
```

Receiver side (results UI; can hang on the root node of any scene, as long as it's alive):

```
OnReceiveEvent  event_name: "player:died", trigger_once: false, store_args_to_local: true
├── SetUIText  target_node: ScoreLabel, text: "本局得分:{local:event_score}"
└── ShowHideUI  target_node: ResultPanel, action: SHOW
```

The sender uses the well-named `player:died` with a `score` argument; the receiver enables `Store Args to Local` and directly consumes `event_score`. Neither side needs a reference to the other—they don't even live in the same scene. That is the power of the Event Bus: it completely separates "who triggered" from "who responds".

Finally, a comparison of communication options to help you choose per need:

| Method | Use case | Complexity |
|------|----------|--------|
| Event Bus | Cross-Trigger, cross-scene, global events | Low |
| `OnTargetSignalEmit` | Listening to a specific node's signal | Low |
| `OnSignalFromGroup` | Listening to a group of similar nodes | Medium |
| Global variable + polling | One-way state sync | High |

The principle is simple: if you can decouple, don't couple. Within one scene, one-to-one listening—`OnTargetSignalEmit` is enough; one-to-many or across a group—use `OnSignalFromGroup`; once it crosses scenes or you want modules to truly evolve independently—go Event Bus.

In this chapter we walked "triggering" from the bottom to the top: lifecycle events manage the heartbeat, timing events manage rhythm, node events connect to Godot signals, and the Event Bus opens up the global layer. Events answer "when to act", but often you also need to judge "under what conditions to act"—like confirming you're on the ground before jumping. The next chapter enters the condition system properly, covering the `CheckAll`/`CheckAny`/`CheckNot` composite logic as well as distance, time, expression and other conditions, so your logic can truly "think".
