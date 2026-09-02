> 🌐 [**中文版**](../../../zh_CN/user_docs/guides/31-timing-events-guide.md) | English

# Timing Events Guide

## Overview

Timing events provide time-related trigger mechanisms for timers, skill cooldowns, countdowns, and real-world time scenarios. **4 events** in total, located in the `events/timing/` directory.

| Event | class_name | Time scale | Trigger mode | Use case |
|------|-----------|----------|----------|----------|
| OnTimer | OnTimer | Game time | Periodic / one-shot | Periodic tasks, cooldown timing |
| OnCooldownFinished | OnCooldownFinished | Game time | One-shot (listens for cooldown end) | Skill cooldown completion |
| OnCountdown | OnCountdown | Game time | Periodic (fires continuously during the countdown) | Level countdown, time-limited challenges |
| OnRealtime | OnRealtime | Real-world time | Periodic / one-shot | Daily refresh, tasks unaffected by pausing |

---

## OnTimer (Timer)

**File:** `events/timing/on_timer.gd`
**class_name:** OnTimer

Fires periodically at a fixed interval, equivalent to an event wrapper around the Godot `Timer` node.

| Parameter | Type | Default | Description |
|------|------|--------|------|
| `wait_time` | float | 1.0 | Wait time (seconds) |
| `autostart` | bool | true | Whether to start automatically |
| `repeat_count` | int | 0 | Repeat count (0 = infinite) |

**Example:** Spawn a wave of enemies every 10 seconds

```
OnTimer → wait_time: 10.0, repeat_count: 0, autostart: true
├── InstantiateScene → scene_path: "res://enemies/wave.tscn"
└── LogInstruction → message: "新一波敌人已生成"
```

---

## OnCooldownFinished (Cooldown Finished)

**File:** `events/timing/on_cooldown_finished.gd`
**class_name:** OnCooldownFinished

Listens for whether a cooldown has finished. Pair with the `manual_trigger` mode for skill cooldown management.

| Parameter | Type | Default | Description |
|------|------|--------|------|
| `cooldown_seconds` | float | 1.0 | Cooldown duration (seconds) |
| `manual_trigger` | bool | false | Whether to start the cooldown manually |
| `show_progress` | bool | false | Whether to expose the cooldown progress in a variable |

**`manual_trigger` modes:**
- `false`: auto-loop (restarts immediately after the cooldown ends)
- `true`: manual trigger — an instruction chain starts a single cooldown run

**Cooldown progress variable (when `show_progress = true`):**
- Variable name: `{event_name}_cooldown_progress`
- Range: 0.0 (cooldown start) to 1.0 (cooldown end)

**Example:** Skill cooldown management

```
# Trigger the cooldown when the skill is pressed
Trigger: OnInputAction (action: "skill_fire")
├── CheckNot → CheckCountdownFinished (cooling down?)
│   └── (cooling down, cannot cast)
└── CheckCountdownFinished (cooldown has finished)
    └── (cast the skill and start the cooldown)
```

---

## OnCountdown (Countdown)

**File:** `events/timing/on_countdown.gd`
**class_name:** OnCountdown

Fires continuously over a specified duration, suited to displaying countdown progress or time-limited level logic.

| Parameter | Type | Default | Description |
|------|------|--------|------|
| `countdown_seconds` | float | 5.0 | Total countdown duration (seconds) |
| `auto_start` | bool | true | Whether to start the countdown automatically |
| `show_remaining_time` | bool | true | Whether to pass the remaining time through the context |
| `update_interval` | float | 0.1 | Progress update trigger interval (seconds) |

**Remaining time variable (when `show_remaining_time = true`):**
- Variable name: `{event_name}_remaining_time`
- Value: the current remaining seconds

**Example:** Time-limited survival level

```
OnCountdown → countdown_seconds: 120.0, update_interval: 1.0, auto_start: true
├── (updates the display every frame)
└── SetVariable → name: "ui_timer_text", value: {scope:countdown_remaining_time}
```

---

## OnRealtime (Real Time)

**File:** `events/timing/on_realtime.gd`
**class_name:** OnRealtime

Fires based on real-world time, **unaffected by `time_scale` or pausing**. Suited to daily refresh, offline rewards, and similar scenarios.

| Parameter | Type | Default | Description |
|------|------|--------|------|
| `interval_seconds` | float | 60.0 | Trigger interval (real-world seconds) |
| `max_triggers` | int | 0 | Maximum trigger count (0 = infinite) |
| `emit_timestamp` | bool | false | Whether to pass the current timestamp into the instruction chain |

**Key differences from OnTimer:**
- `OnTimer` is affected by `time_scale` (stops while paused)
- `OnRealtime` is **not** affected by `time_scale` / pausing

**Example:** Daily quest refresh check

```
OnRealtime → interval_seconds: 3600.0, emit_timestamp: true
├── (check the last refresh timestamp)
└── CompareVariable → name: "last_daily_refresh", operator: LESS_THAN, value: {current timestamp - 86400}
    └── ResetDailyTasks
```

---

## Event Comparison

| Dimension | OnTimer | OnCooldownFinished | OnCountdown | OnRealtime |
|------|---------|--------------------|-------------|------------|
| Time scale | Game time | Game time | Game time | Real-world time |
| Affected by time_scale | ✅ Yes | ✅ Yes | ✅ Yes | ❌ No |
| Affected by pausing | ✅ Yes | ✅ Yes | ✅ Yes | ❌ No |
| Trigger mode | Periodic / one-shot | The instant the cooldown ends | Continuous updates | Periodic |
| Typical interval | 1~60s | 1~30s | 0.1~1s updates | 3600s+ |
| Manual control | autostart switch | manual_trigger | auto_start | None |

---

## Common Use Cases

### Skill Cooldown Management

```
# Cast the skill
Trigger: OnInputAction (action: "skill_1")
├── CheckCountdownFinished (skill_1_cooldown)
│   └── (run the skill logic)
│       └── (start the cooldown)
└── (cooling down, show the remaining cooldown time)
```

### Level Countdown

```
OnReady
├── StartCountdown (start the timer manually)
├── OnCountdown → countdown_seconds: 300.0, update_interval: 1.0
│   └── SetVariable → name: "hud_time", value: {scope:countdown_remaining_time}
└── OnCountdownFinished (time is up)
    └── GameOver → result: "time_out"
```

### Daily Quest Refresh

```
OnRealtime → interval_seconds: 3600.0
├── CheckTimeRange → start_hour: 4, end_hour: 5 (refresh between 4 and 5 AM)
│   └── RefreshDailyQuests
└── LogInstruction → message: "检查每日刷新..."
```

---

## Notes

1. **OnRealtime is special:** it is unaffected by `time_scale` / pausing, which fits real-time needs — but do not use it for in-game logic (such as jump cooldowns).
2. **Cooldown manual_trigger:** once set to `true`, it will not restart automatically; a new cooldown cycle must be triggered manually via an instruction chain.
3. **Godot lifecycle of the Timer node:** `OnTimer` is built on the Godot `Timer` node. The Timer stops automatically when the scene is removed and must be restarted when the scene re-enters the tree.
4. **Interval settings:** avoid setting intervals below 0.1s unless high-frequency triggering is genuinely required.
