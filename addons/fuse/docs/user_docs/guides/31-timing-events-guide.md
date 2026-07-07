# Timing 事件指南

## 概述

Timing 事件提供与时间相关的触发机制，适用于定时器、技能冷却、倒计时和现实时间场景。共 **4 个事件**，位于 `events/timing/` 目录。

| 事件 | class_name | 时间尺度 | 触发模式 | 适用场景 |
|------|-----------|----------|----------|----------|
| OnTimer | OnTimer | 游戏时间 | 周期/单次 | 周期性任务、冷却计时 |
| OnCooldownFinished | OnCooldownFinished | 游戏时间 | 单次（监听冷却结束） | 技能冷却完成 |
| OnCountdown | OnCountdown | 游戏时间 | 周期（倒计时中持续触发） | 关卡倒计时、限时挑战 |
| OnRealtime | OnRealtime | 现实时间 | 周期/单次 | 每日刷新、不受暂停影响的任务 |

---

## OnTimer（定时器）

**文件：** `events/timing/on_timer.gd`
**class_name：** OnTimer

按固定间隔周期性触发，等同于 Godot `Timer` 节点的事件封装。

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `wait_time` | float | 1.0 | 等待时间（秒） |
| `autostart` | bool | true | 是否自动启动 |
| `repeat_count` | int | 0 | 重复次数（0 = 无限） |

**示例：** 每 10 秒生成一波敌人

```
OnTimer → wait_time: 10.0, repeat_count: 0, autostart: true
├── InstantiateScene → scene_path: "res://enemies/wave.tscn"
└── LogInstruction → message: "新一波敌人已生成"
```

---

## OnCooldownFinished（冷却完成）

**文件：** `events/timing/on_cooldown_finished.gd`
**class_name：** OnCooldownFinished

监听冷却是否已结束。配合 `manual_trigger` 模式实现技能冷却管理。

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `cooldown_seconds` | float | 1.0 | 冷却时长（秒） |
| `manual_trigger` | bool | false | 是否手动启动冷却 |
| `show_progress` | bool | false | 是否在变量中显示冷却进度 |

**`manual_trigger` 模式：**
- `false`：自动循环（冷却结束后立即重新开始）
- `true`：手动触发，通过执行指令链启动单次冷却

**冷却进度变量（`show_progress = true` 时）：**
- 变量名：`{event_name}_cooldown_progress`
- 范围：0.0（冷却开始）~ 1.0（冷却结束）

**示例：** 技能冷却管理

```
# 技能按下时触发冷却
Trigger: OnInputAction (action: "skill_fire")
├── CheckNot → CheckCountdownFinished (冷却中？)
│   └── (冷却中，无法释放)
└── CheckCountdownFinished (冷却已结束)
    └── (释放技能并启动冷却)
```

---

## OnCountdown（倒计时）

**文件：** `events/timing/on_countdown.gd`
**class_name：** OnCountdown

在指定时长内持续触发，适合显示倒计时进度或限时关卡逻辑。

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `countdown_seconds` | float | 5.0 | 倒计时总时长（秒） |
| `auto_start` | bool | true | 是否自动开始倒计时 |
| `show_remaining_time` | bool | true | 是否在 context 中传递剩余时间 |
| `update_interval` | float | 0.1 | 进度更新触发间隔（秒） |

**剩余时间变量（`show_remaining_time = true` 时）：**
- 变量名：`{event_name}_remaining_time`
- 值：当前剩余秒数

**示例：** 限时生存关卡

```
OnCountdown → countdown_seconds: 120.0, update_interval: 1.0, auto_start: true
├── (每帧更新显示)
└── SetVariable → name: "ui_timer_text", value: {scope:countdown_remaining_time}
```

---

## OnRealtime（现实时间）

**文件：** `events/timing/on_realtime.gd`
**class_name：** OnRealtime

基于现实世界时间触发，**不受 `time_scale` 或暂停（pause）影响**。适用于每日刷新、离线奖励等场景。

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `interval_seconds` | float | 60.0 | 触发间隔（现实秒数） |
| `max_triggers` | int | 0 | 最大触发次数（0 = 无限） |
| `emit_timestamp` | bool | false | 是否将当前时间戳传入指令链 |

**与 OnTimer 的关键区别：**
- `OnTimer` 受 `time_scale` 影响（暂停时停止）
- `OnRealtime` **不受** `time_scale` / 暂停影响

**示例：** 每日任务刷新检查

```
OnRealtime → interval_seconds: 3600.0, emit_timestamp: true
├── (检查上次刷新时间戳)
└── CompareVariable → name: "last_daily_refresh", operator: LESS_THAN, value: {当前时间戳 - 86400}
    └── ResetDailyTasks
```

---

## 事件对比

| 维度 | OnTimer | OnCooldownFinished | OnCountdown | OnRealtime |
|------|---------|--------------------|-------------|------------|
| 时间尺度 | 游戏时间 | 游戏时间 | 游戏时间 | 现实时间 |
| 受 time_scale 影响 | ✅ 是 | ✅ 是 | ✅ 是 | ❌ 否 |
| 受暂停影响 | ✅ 是 | ✅ 是 | ✅ 是 | ❌ 否 |
| 触发模式 | 周期/单次 | 冷却结束瞬间 | 持续更新 | 周期 |
| 典型间隔 | 1~60s | 1~30s | 0.1~1s 更新 | 3600s+ |
| 手动控制 | autostart 开关 | manual_trigger | auto_start | 无 |

---

## 常见用例

### 技能冷却管理

```
# 技能释放
Trigger: OnInputAction (action: "skill_1")
├── CheckCountdownFinished (skill_1_cooldown)
│   └── (执行技能逻辑)
│       └──（启动冷却）
└── (冷却中，显示剩余冷却时间)
```

### 关卡倒计时

```
OnReady
├── StartCountdown (手动启动计时)
├── OnCountdown → countdown_seconds: 300.0, update_interval: 1.0
│   └── SetVariable → name: "hud_time", value: {scope:countdown_remaining_time}
└── OnCountdownFinished (时间到)
    └── GameOver → result: "time_out"
```

### 每日任务刷新

```
OnRealtime → interval_seconds: 3600.0
├── CheckTimeRange → start_hour: 4, end_hour: 5 (凌晨 4-5 点刷新)
│   └── RefreshDailyQuests
└── LogInstruction → message: "检查每日刷新..."
```

---

## 注意事项

1. **OnRealtime 的特殊性**：不受 `time_scale` / pause 影响，适合真实时间需求，但不要用它做游戏内逻辑（如跳跃冷却）。
2. **Cooldown 的 manual_trigger**：设为 `true` 后不会自动重启，需通过指令链手动触发新冷却周期。
3. **Timer 节点的 Godot 生命周期**：`OnTimer` 底层使用 Godot `Timer` 节点。场景被移除时 Timer 自动停止，重新加入场景时需重启。
4. **间隔设置**：避免将间隔设为 < 0.1s，除非确实需要高频触发。
