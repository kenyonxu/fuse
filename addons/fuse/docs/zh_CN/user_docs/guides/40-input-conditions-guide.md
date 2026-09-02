> 🌐 中文 | [**English**](../../../en_US/user_docs/guides/40-input-conditions-guide.md)

# Input 条件指南

## 概述

Input 条件用于**判断**当前输入状态（按下、按住、释放），而非响应输入事件。通常配合 Trigger 中的条件分支使用，实现在同一事件下根据输入状态走不同路径。共 **6 个条件**，位于 `conditions/input/` 目录。

| 条件 | class_name | 功能 |
|------|-----------|------|
| CheckInputPressed | CheckInputPressed | 输入动作是否在**当前帧按下** |
| CheckInputHeld | CheckInputHeld | 输入动作是否**正在按住** |
| CheckInputReleased | CheckInputReleased | 输入动作是否在**当前帧释放** |
| CheckInputDirection | CheckInputDirection | 获取摇杆/键盘方向向量并比较 |
| CheckInputMagnitude | CheckInputMagnitude | 获取输入力度并比较 |
| CheckAnyInput | CheckAnyInput | 是否有**任意**输入动作被触发 |

> **Input 条件 vs 输入事件：** 输入**事件**（如 `OnInputAction`）是触发型——按下时执行指令序列。输入**条件**是判断型——在已有的事件中做分支。两者互补。

---

## 三态检测

### CheckInputPressed

**文件：** `conditions/input/check_input_pressed.gd`
**class_name：** CheckInputPressed

输入动作在当前帧被按下的瞬间返回 `true`。适合单次触发（跳跃、攻击）。

| 参数 | 类型 | 说明 |
|------|------|------|
| `action_name` | String | 输入动作名称（对应 Input Map） |

**示例：** 跳跃检测

```
OnInterval (每帧)
├── CheckInputPressed → action_name: "jump"
│   └── (执行跳跃)
```

### CheckInputHeld

**文件：** `conditions/input/check_input_held.gd`
**class_name：** CheckInputHeld

输入动作正在被按住时返回 `true`。适合持续行为（跑步、蓄力）。

| 参数 | 类型 | 说明 |
|------|------|------|
| `action_name` | String | 输入动作名称 |

**示例：** 按住加速

```
CheckInputHeld → action_name: "sprint"
├── true → (设置移动速度为 600)
└── false → (设置移动速度为 300)
```

### CheckInputReleased

**文件：** `conditions/input/check_input_released.gd`
**class_name：** CheckInputReleased

输入动作在当前帧被释放时返回 `true`。适合松手触发（蓄力攻击释放）。

| 参数 | 类型 | 说明 |
|------|------|------|
| `action_name` | String | 输入动作名称 |

**示例：** 蓄力弓释放

```
CheckInputReleased → action_name: "attack"
├── true → (发射已蓄力的箭)
└── false → (继续蓄力)
```

---

## 方向与幅度

### CheckInputDirection

**文件：** `conditions/input/check_input_direction.gd`
**class_name：** CheckInputDirection

获取输入的方向向量（摇杆或键盘），并与指定方向比较。

| 参数 | 类型 | 说明 |
|------|------|------|
| `action_name` | String | 输入动作（通常是 "move_left/right" 等组合） |
| `direction` | Vector2 | 比较目标方向 |
| `operator` | CompareOperator | 比较方式：`EQUALS`、`APPROX`（近似） |

### CheckInputMagnitude

**文件：** `conditions/input/check_input_magnitude.gd`
**class_name：** CheckInputMagnitude

获取输入力度大小并与阈值比较。摇杆输入返回 0.0 到 1.0 之间的值。

| 参数 | 类型 | 说明 |
|------|------|------|
| `action_name` | String | 输入动作 |
| `operator` | CompareOperator | 比较方式 |
| `value` | float | 比较阈值 |

---

## 任意输入

### CheckAnyInput

**文件：** `conditions/input/check_any_input.gd`
**class_name：** CheckAnyInput

检测是否有**任何**输入动作在当前帧被触发。适合引导界面跳过的通用检测。

| 参数 | 类型 | 说明 |
|------|------|------|
| — | — | 无参数。检查所有 Input Map 中注册的动作 |

**示例：** 跳过开场动画

```
OnReady
├── PlayAnimation → animation: "intro"
└── OnInterval (每帧)
    └── CheckAnyInput
        └── true → SkipAnimation
```

---

## 常见用例

### 按住蓄力攻击（Held + 计时）

```
Trigger: OnProcess (每帧)
├── CheckInputHeld → action_name: "attack"
│   ├── true → CheckCountdownFinished → cooldown: "charge" (已冷却?)
│   │   ├── true → (蓄力中… 增加蓄力变量)
│   │   └── false → (等待冷却)
│   └── false → CheckInputReleased → action_name: "attack" (释放)
│       └── true → (根据蓄力变量发射不同等级攻击)
```

### 双击检测（Pressed + OnCountdown + CheckPressed）

```
Trigger: OnInputAction → action_name: "dodge"
├── (第一次按下，启动冷却倒计时 0.3 秒)
└── OnInterval (检查 0.3 秒内是否再次按下)
    └── CheckInputPressed → action_name: "dodge"
        └── true → (触发双击闪避)
```

### 摇杆灵敏度判断（Magnitude）

```
CheckInputMagnitude → action_name: "move", operator: GREATER_THAN, value: 0.5
├── true → (快速行走/奔跑)
└── false → (慢走，摇杆轻微推动时)
```

---

## 与 OnInputAction 的协作

Input 条件和输入事件最佳搭配使用：

```
Trigger: OnInputAction → action_name: "interact"
├── (任何时候按下交互键)
├── Condition: CheckNodeProperty → target: Player, property: "nearby_object", operator: NOT_EQUALS, value: null
│   ├── true → (交互对象存在)
│   │   ├── CheckInputHeld → action_name: "interact" (长按交互)
│   │   │   ├── true → (执行长按交互逻辑 — 如加载进度条)
│   │   │   └── false → CheckInputReleased → action_name: "interact"
│   │   │       └── true → (短按交互)
│   └── false → (没有交互对象，忽略)
```

---

## 注意事项

0. **节点路径与变量二选一**：含 NodePath 参数的条件（如 CheckInputActionMap 等）既支持直接写死节点路径，也支持通过变量动态传入节点引用。
1. **Pressed vs Held**：`CheckInputPressed` 只在**按下帧**返回 true；`CheckInputHeld` 在**按住期间每一帧**都返回 true。选择时明确"按下瞬间"还是"持续按住"。
2. **与 OnInputAction 事件的区别**：如果你只需要"按下 X 就做什么"，用 `OnInputAction` 事件更合适。输入条件适合在已有的事件序列中做分支判断。
3. **Input Map**：确保输入动作已在 Godot 的 Input Map 中注册。条件不会自动创建动作。
