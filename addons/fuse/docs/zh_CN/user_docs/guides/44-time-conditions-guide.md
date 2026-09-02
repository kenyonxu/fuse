> 🌐 中文 | [**English**](../../../en_US/user_docs/guides/44-time-conditions-guide.md)

# Time 条件指南

## 概述

Time 条件用于在流程控制中判断游戏内时间——是否到达指定时间点、是否在时间段内、倒计时是否结束、游戏运行时长等。共 **4 个条件**，位于 `conditions/time/` 目录。

| 条件 | class_name | 功能 |
|------|-----------|------|
| CheckTimeReached | CheckTimeReached | 是否到达或超过指定时间点 |
| CheckTimeRange | CheckTimeRange | 当前时间是否在指定范围内 |
| CheckCountdownFinished | CheckCountdownFinished | 倒计时是否已结束 |
| CheckGameTime | CheckGameTime | 游戏运行时间比较 |

---

## 时间点与时间段

### CheckTimeReached

**文件：** `conditions/time/check_time_reached.gd`
**class_name：** CheckTimeReached

检查当前时间是否已达到或超过指定的时间点。

| 参数 | 类型 | 说明 |
|------|------|------|
| `target_time` | float | 目标时间点（秒或以变量形式指定） |
| `use_variable` | bool | 是否从变量读取目标时间 |
| `time_variable` | String | 时间变量名 |
| `time_scope` | ScopeSource | 变量作用域 |

**示例：** 限制战斗时长

```
CheckTimeReached → target_time: 120.0 (游戏开始后 120s)
├── true → (战斗超时，触发援军或失败判定)
└── false → (继续战斗)
```

### CheckTimeRange

**文件：** `conditions/time/check_time_range.gd`
**class_name：** CheckTimeRange

检查当前时间是否在指定的时间范围内（含起点和终点）。适用于日夜循环逻辑。

| 参数 | 类型 | 说明 |
|------|------|------|
| `start_time` | float | 范围开始时间（秒） |
| `end_time` | float | 范围结束时间（秒） |
| `wrap_around` | bool | 是否循环（当日/夜跨越 24 小时边界时） |

**示例：** 日夜循环逻辑

```
CheckTimeRange → start_time: 0.0, end_time: 43200.0 (0~12 小时)
├── true → (白天，使用白天光照和敌人 AI)
└── false → (夜晚，使用夜晚光照和敌人 AI)
```

---

## 倒计时与游戏时间

### CheckCountdownFinished

**文件：** `conditions/time/check_countdown_finished.gd`
**class_name：** CheckCountdownFinished

检查倒计时是否已经结束。通过变量记录开始时间，结合时长计算经过时间。**不与 `OnCountdown` 事件绑定**，独立工作。

| 参数 | 类型 | 说明 |
|------|------|------|
| `start_time_variable` | String | 存储开始时间的变量名 |
| `variable_scope` | VariableScope | 变量作用域（Local/Scope/Global） |
| `duration` | float | 倒计时时长（秒） |

**示例：** 技能冷却中判断

```
CheckCountdownFinished → start_time_variable: "skill_fire_start", variable_scope: LOCAL, duration: 5.0
├── true → (冷却已结束，可以释放技能)
└── false → (冷却中，提示剩余时间)
```

### CheckGameTime

**文件：** `conditions/time/check_game_time.gd`
**class_name：** CheckGameTime

检查自游戏启动以来的运行时间是否满足条件。

| 参数 | 类型 | 说明 |
|------|------|------|
| `operator` | CompareOperator | 比较运算符 |
| `value` | float | 比较值（秒） |

**示例：** 游戏限时模式

```
CheckGameTime → operator: GREATER_THAN, value: 300.0 (5 分钟)
├── true → (玩家存活超过 5 分钟，胜利)
└── false → (继续计时，显示剩余时间)
```

---

## 常见用例

### 限制战斗时长

```
OnInterval → interval_seconds: 1.0
├── CheckTimeReached → target_time: 180.0 (3 分钟)
│   ├── true → (战斗超时，Boss 暴走)
│   │   └── SetVariable → name: "boss_rage", value: true, scope: GLOBAL
│   └── false → (检查剩余时间并显示)
```

### 日夜循环逻辑

```
OnInterval → interval_seconds: 60.0
├── CheckTimeRange → start_time: 21600.0, end_time: 64800.0 (6:00 ~ 18:00)
│   ├── true → (白天)
│   │   ├── SetVariable → name: "lighting_mode", value: "day"
│   │   └── SetVariable → name: "spawn_rate", value: 0.5
│   └── false → (夜晚)
│       ├── SetVariable → name: "lighting_mode", value: "night"
│       └── SetVariable → name: "spawn_rate", value: 2.0
```

### 技能冷却中判断

```
Trigger: OnInputAction → action_name: "fireball"
├── CheckCountdownFinished → start_time_variable: "fireball_start", variable_scope: LOCAL, duration: 3.0
│   ├── true → (发射火球)
│   │   └── SetVariable → name: "fireball_start", value: {time_msec}, scope: LOCAL
│   └── false → (冷却中，播放"技能不可用"提示)
```

### 游戏限时模式

```
OnReady
├── SetVariable → name: "time_limit", value: 300.0, scope: GLOBAL
└── OnInterval → interval_seconds: 1.0
    ├── CheckGameTime → operator: GREATER_THAN, value: {scope:time_limit}
    │   ├── true → GameOver → result: "time_up"
    │   └── false → (更新 HUD 显示剩余时间: {scope:time_limit} - current_time)
```

---

## 注意事项

0. **变量引用支持**：所有含数值参数的条件（如 CheckTimeReached 的 `target_time`）既支持直接写值，也支持通过变量动态传入。
1. **游戏时间 vs 现实时间**：`CheckGameTime` 使用游戏时间（受 `time_scale` 影响）。如果需要不受暂停影响的时间判断，使用 `OnRealtime` + 变量记录。
2. **倒计时独立工作**：`CheckCountdownFinished` 自身管理倒计时状态，通过变量驱动。需要主动将开始时间写入变量（如 `Time.get_ticks_msec()`），再通过此条件检查是否超时。
3. **时间单位统一**：所有时间参数以**秒**为单位。使用时注意单位换算（如 1 小时 = 3600 秒）。
