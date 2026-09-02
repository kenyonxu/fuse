> 🌐 [**中文版**](../../../zh_CN/user_docs/guides/44-time-conditions-guide.md) | English

# Time Conditions Guide

## Overview

Time conditions evaluate in-game time in flow control — whether a time point has been reached, whether the current time falls within a range, whether a countdown has ended, how long the game has been running, and more. **4 conditions** in total, located in the `conditions/time/` directory.

| Condition | class_name | Description |
|------|-----------|------|
| CheckTimeReached | CheckTimeReached | Whether the specified time point has been reached or passed |
| CheckTimeRange | CheckTimeRange | Whether the current time is within the specified range |
| CheckCountdownFinished | CheckCountdownFinished | Whether a countdown has finished |
| CheckGameTime | CheckGameTime | Game time comparison |

---

## Time Points and Ranges

### CheckTimeReached

**File:** `conditions/time/check_time_reached.gd`
**class_name:** CheckTimeReached

Checks whether the current time has reached or passed the specified time point.

| Parameter | Type | Description |
|------|------|------|
| `target_time` | float | The target time point (in seconds, or specified via a variable) |
| `use_variable` | bool | Whether to read the target time from a variable |
| `time_variable` | String | The time variable name |
| `time_scope` | ScopeSource | The variable scope |

**Example:** Limit the battle duration

```
CheckTimeReached → target_time: 120.0 (120s after the game started)
├── true → (battle timed out, trigger reinforcements or the failure check)
└── false → (keep fighting)
```

### CheckTimeRange

**File:** `conditions/time/check_time_range.gd`
**class_name:** CheckTimeRange

Checks whether the current time is within the specified time range (start and end inclusive). Suitable for day/night cycle logic.

| Parameter | Type | Description |
|------|------|------|
| `start_time` | float | Range start time (seconds) |
| `end_time` | float | Range end time (seconds) |
| `wrap_around` | bool | Whether to wrap around (when a day/night cycle crosses the 24-hour boundary) |

**Example:** Day/night cycle logic

```
CheckTimeRange → start_time: 0.0, end_time: 43200.0 (0-12 hours)
├── true → (daytime, use daytime lighting and enemy AI)
└── false → (nighttime, use nighttime lighting and enemy AI)
```

---

## Countdown and Game Time

### CheckCountdownFinished

**File:** `conditions/time/check_countdown_finished.gd`
**class_name:** CheckCountdownFinished

Checks whether a countdown has finished. The start time is recorded in a variable, and the elapsed time is computed against the duration. **Not bound to the `OnCountdown` event**; works independently.

| Parameter | Type | Description |
|------|------|------|
| `start_time_variable` | String | The variable name that stores the start time |
| `variable_scope` | VariableScope | The variable scope (Local/Scope/Global) |
| `duration` | float | The countdown duration (seconds) |

**Example:** Skill cooldown check

```
CheckCountdownFinished → start_time_variable: "skill_fire_start", variable_scope: LOCAL, duration: 5.0
├── true → (cooldown finished, the skill can be cast)
└── false → (cooling down, show the remaining time)
```

### CheckGameTime

**File:** `conditions/time/check_game_time.gd`
**class_name:** CheckGameTime

Checks whether the time elapsed since the game started satisfies a condition.

| Parameter | Type | Description |
|------|------|------|
| `operator` | CompareOperator | The comparison operator |
| `value` | float | The value to compare against (seconds) |

**Example:** Time-limited game mode

```
CheckGameTime → operator: GREATER_THAN, value: 300.0 (5 minutes)
├── true → (the player survived more than 5 minutes, victory)
└── false → (keep counting, display the remaining time)
```

---

## Common Use Cases

### Limit the battle duration

```
OnInterval → interval_seconds: 1.0
├── CheckTimeReached → target_time: 180.0 (3 minutes)
│   ├── true → (battle timed out, the Boss goes berserk)
│   │   └── SetVariable → name: "boss_rage", value: true, scope: GLOBAL
│   └── false → (check and display the remaining time)
```

### Day/night cycle logic

```
OnInterval → interval_seconds: 60.0
├── CheckTimeRange → start_time: 21600.0, end_time: 64800.0 (6:00 ~ 18:00)
│   ├── true → (daytime)
│   │   ├── SetVariable → name: "lighting_mode", value: "day"
│   │   └── SetVariable → name: "spawn_rate", value: 0.5
│   └── false → (nighttime)
│       ├── SetVariable → name: "lighting_mode", value: "night"
│       └── SetVariable → name: "spawn_rate", value: 2.0
```

### Skill cooldown check

```
Trigger: OnInputAction → action_name: "fireball"
├── CheckCountdownFinished → start_time_variable: "fireball_start", variable_scope: LOCAL, duration: 3.0
│   ├── true → (cast the fireball)
│   │   └── SetVariable → name: "fireball_start", value: {time_msec}, scope: LOCAL
│   └── false → (cooling down, play the "skill unavailable" cue)
```

### Time-limited game mode

```
OnReady
├── SetVariable → name: "time_limit", value: 300.0, scope: GLOBAL
└── OnInterval → interval_seconds: 1.0
    ├── CheckGameTime → operator: GREATER_THAN, value: {scope:time_limit}
    │   ├── true → GameOver → result: "time_up"
    │   └── false → (update the HUD with the remaining time: {scope:time_limit} - current_time)
```

---

## Notes

0. **Variable reference support:** all conditions with numeric parameters (such as CheckTimeReached's `target_time`) accept both literal values and values passed dynamically through variables.
1. **Game time vs real time:** `CheckGameTime` uses game time (affected by `time_scale`). For time checks unaffected by pausing, use `OnRealtime` + variable bookkeeping.
2. **Countdowns work independently:** `CheckCountdownFinished` manages its own countdown state, driven by variables. You must actively write the start time into a variable (e.g. `Time.get_ticks_msec()`), then use this condition to check whether the countdown has expired.
3. **Consistent time units:** all time parameters use **seconds**. Watch unit conversion when configuring them (e.g. 1 hour = 3600 seconds).
