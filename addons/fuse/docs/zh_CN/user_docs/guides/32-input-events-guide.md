> 🌐 中文 | [**English**](../../../en_US/user_docs/guides/32-input-events-guide.md)

# 输入事件指南

Fuse 提供 12 个输入事件，覆盖键盘、鼠标、触摸、游戏手柄和文本输入等所有输入方式。

## 事件总览

### 键盘

| 事件 | 功能 | 关键配置 |
|------|------|----------|
| OnInputKey | 键盘按键事件 | 按键、触发时机（按下/释放/重复） |

### 鼠标

| 事件 | 功能 | 关键配置 |
|------|------|----------|
| OnMouseButton | 鼠标按键事件 | 按键（左/右/中）、触发时机 |
| OnMouseMove | 鼠标移动事件 | 无额外配置 |
| OnMouseEnter | 鼠标进入 Control 节点 | 无额外配置 |
| OnMouseExit | 鼠标离开 Control 节点 | 无额外配置 |

### 触摸

| 事件 | 功能 | 关键配置 |
|------|------|----------|
| OnTouch | 触摸屏幕事件 | 无额外配置 |
| OnTouchSwipe | 触摸滑动手势 | 最小滑动距离、滑动方向 |

### 游戏手柄

| 事件 | 功能 | 关键配置 |
|------|------|----------|
| OnGamepadButton | 手柄按键事件 | 按键索引、触发时机 |
| OnGamepadAxis | 手柄摇杆/扳机事件 | 轴索引、阈值（死区） |

### 输入映射

| 事件 | 功能 | 关键配置 |
|------|------|----------|
| OnInputAction | Input Map 动作事件 | 动作名称、触发时机 |
| OnInputActionComposite | 复合输入动作 | 动作组合配置（如 WASD 移动） |

### 文本

| 事件 | 功能 | 关键配置 |
|------|------|----------|
| OnInputText | 文本输入事件 | 无额外配置 |

## 常见用例

### 1. 角色控制

```
移动 → OnInputActionComposite("move")
  → 获取移动方向 → MoveBy / SetVelocity

跳跃 → OnInputAction("jump", 按下时)
  → ApplyImpulse(向上力)

冲刺 → OnInputAction("dash", 按下时)
  → SetVelocity(冲刺方向)
  → Wait(0.2秒)
  → SetVelocity(正常速度)
```

### 2. UI 交互

```
鼠标悬停提示 → OnMouseEnter
  → ShowHideUI(提示面板, 显示)

鼠标离开 → OnMouseExit
  → ShowHideUI(提示面板, 隐藏)

点击按钮 → OnMouseButton(左键, 按下时)
  → 触发对应功能
```

### 3. 手柄支持

```
手柄攻击 → OnGamepadButton(按钮0, 按下时)
  → 执行攻击逻辑

手柄瞄准 → OnGamepadAxis(右摇杆X/Y, 阈值=0.2)
  → 获取摇杆方向 → LookAt

手柄冲刺 → OnGamepadAxis(左扳机, 阈值=0.5)
  → 执行冲刺
```

### 4. 触摸手势

```
左滑 → OnTouchSwipe(方向=左)
  → 切换到上一个选项

右滑 → OnTouchSwipe(方向=右)
  → 切换到下一个选项

点击 → OnTouch
  → 确认选择
```

## 上下文数据

输入事件触发时，会通过 ExecutionContext 传递相关数据，后续指令可以访问：

| 事件 | 传递的数据 |
|------|-----------|
| OnInputKey | 按键码、物理按键码、是否按下、是否 Shift/Ctrl/Alt |
| OnMouseButton | 按键索引、按下状态、位置、双击状态 |
| OnMouseMove | 位置、相对位移、速度 |
| OnTouch | 触摸位置、压力 |
| OnTouchSwipe | 起始位置、结束位置、方向、距离 |
| OnGamepadButton | 设备索引、按键索引 |
| OnGamepadAxis | 设备索引、轴索引、轴值 |
| OnInputAction | 动作名称、力度、是否按下 |
| OnInputText | 输入的文本内容 |

## 注意事项

- OnInputKey 和 OnMouseButton 支持**按下时、释放时、重复触发**三种时机
- OnMouseEnter / OnMouseExit 仅对 **Control 节点**有效（如 Button、Panel 等）
- OnGamepadAxis 需要设置**阈值**（死区），避免摇杆回中时的误触发
- OnInputAction 使用 Godot 的 **Input Map** 系统，需在项目设置中预先配置
- OnInputActionComposite 自动处理多按键组合（如 WASD 的上下左右分量）
- 触摸事件在非触摸设备上不会触发
