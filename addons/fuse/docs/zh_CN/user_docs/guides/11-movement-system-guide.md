> 🌐 中文 | [**English**](../../../en_US/user_docs/guides/11-movement-system-guide.md)

# Fuse 移动系统用户指南

## 概述

Fuse 移动系统为 Godot 4.x 提供了一套完整的无代码移动控制解决方案。通过可视化编程的方式，你可以轻松实现角色的移动、碰撞检测和物理交互，无需编写任何代码。

## 核心组件

### 1. 事件（Events）

#### OnInputActionComposite
检测复合输入动作（如四向移动），支持对角线移动。

**参数：**
- `action_up` - 向上移动的输入动作名称
- `action_down` - 向下移动的输入动作名称
- `action_left` - 向左移动的输入动作名称
- `action_right` - 向右移动的输入动作名称
- `trigger_rate` - 触发帧率，控制事件触发频率：
  - `60 FPS` - 最流畅（默认，推荐）
  - `30 FPS` - 性能平衡
  - `20 FPS` - 低性能设备
  - `10 FPS` - 不推荐，会有明显卡顿

**特性：**
- 自动支持对角线移动（同时按下两个方向）
- 可禁用特定方向（选择"无"选项）
- 持续按住时连续触发事件

**示例配置：**
```
action_up = "move_up"
action_down = "move_down"
action_left = "move_left"
action_right = "move_right"
trigger_rate = 60 FPS  # 最流畅的体验
```

### 2. 指令（Instructions）

#### MoveCharacterBody2DComposite
控制 CharacterBody2D 节点进行四向移动，支持三种移动模式。

**参数：**
- `target_node` - 目标 CharacterBody2D 节点路径
- `speed` - 移动速度（像素/秒）
- `move_mode` - 移动模式：
  - `DIRECT` - 直接设置速度，精确控制，适合网格移动
  - `SMOOTH` - 平滑插值到目标速度，适合平滑的移动效果
  - `ACCELERATION` - 使用加速度和摩擦力，适合真实的物理感觉
- `smooth_factor` - 平滑因子（仅 SMOOTH 模式），值越大变化越快
- `acceleration` - 加速度（像素/秒²，仅 ACCELERATION 模式）
- `friction` - 摩擦力（像素/秒²，仅 ACCELERATION 模式）

**推荐配置：**
```
# 基础配置
target_node = NodePath("..")
speed = 200.0
move_mode = DIRECT

# 平滑移动
move_mode = SMOOTH
smooth_factor = 10.0

# 物理移动
move_mode = ACCELERATION
acceleration = 1000.0
friction = 800.0
```

## 快速开始

### 步骤 1: 配置 InputMap

在项目设置中定义输入动作：

```gdscript
# 在项目启动脚本中运行
func setup_input_map():
    var actions = ["move_up", "move_down", "move_left", "move_right"]
    var keys = [KEY_W, KEY_S, KEY_A, KEY_D]

    for i in range(actions.size()):
        if not InputMap.has_action(actions[i]):
            InputMap.add_action(actions[i])
            var event = InputEventKey.new()
            event.keycode = keys[i]
            InputMap.action_add_event(actions[i], event)
```

### 步骤 2: 创建角色场景

1. 创建 `CharacterBody2D` 节点
2. 添加 `CollisionShape2D` 并设置碰撞形状
3. 添加可视化节点（如 `Sprite2D`）

### 步骤 3: 配置 Trigger

在角色节点下添加 Trigger 组件：

1. 右键角色节点 → "添加子节点"
2. 选择 "Trigger" 节点
3. 在 Inspector 中配置：
   - **Event**: 选择 `OnInputActionComposite`
   - **ActionRunner**: 添加 `MoveCharacterBody2DComposite`

### 步骤 4: 测试

运行场景，使用 WASD 或方向键控制角色移动。

## 高级用法

### 自定义输入动作

你可以使用任何 InputMap 动作：

```
# 手柄控制
action_up = "gp_face_up"
action_down = "gp_face_down"
action_left = "gp_face_left"
action_right = "gp_face_right"

# 或自定义动作
action_up = "ui_up"
action_down = "ui_down"
```

### 调整移动速度

根据游戏需求调整 `speed` 参数：

- 慢速移动：`speed = 100.0`
- 正常移动：`speed = 200.0`
- 快速移动：`speed = 400.0`

### 选择移动模式

**DIRECT 模式：**
- 直接设置 velocity
- 最精确的控制
- 适合网格移动、即时响应
- 无惯性和滑行

**SMOOTH 模式：**
- 使用线性插值平滑过渡到目标速度
- 流畅的加减速效果
- 适合需要平滑体验的游戏
- 通过 `smooth_factor` 控制平滑度

**ACCELERATION 模式：**
- 模拟真实的物理加速和摩擦
- 有惯性和滑行感
- 适合动作游戏、平台游戏
- 通过 `acceleration` 和 `friction` 控制物理感

### 性能优化

**选择合适的触发帧率：**

| 帧率设置 | 适用场景 | 性能影响 |
|---------|---------|---------|
| **60 FPS** | 动作游戏、平台游戏、需要精确控制 | 较高系统负载，最流畅 |
| **30 FPS** | 一般游戏、休闲游戏 | 平衡的性能和流畅度 |
| **20 FPS** | 低端设备、移动设备 | 低系统负载，可接受的流畅度 |
| **10 FPS** | 不推荐 | 最低系统负载，会有明显卡顿 |

**性能优化建议：**
- 动作游戏：使用 60 FPS + DIRECT 模式
- 休闲游戏：使用 30 FPS + SMOOTH 模式
- 大量角色：使用 20 FPS + DIRECT 模式
- 移动平台：使用 30 FPS，根据设备调整

## 常见问题

### Q: 角色没有移动？

检查以下项：
1. InputMap 是否正确配置
2. 输入动作名称是否匹配
3. target_node 路径是否正确
4. CharacterBody2D 是否有 CollisionShape2D

### Q: 移动速度太慢/太快？

调整 `speed` 参数：
- 增加 speed 值 = 更快
- 减少 speed 值 = 更慢

### Q: 如何添加对角线移动？

系统已自动支持对角线移动！同时按下两个方向键即可。

### Q: 如何使用手柄控制？

只需将 InputMap 动作映射到手柄按钮：

```gdscript
# 将手柄按钮映射到动作
var joypad_event = InputEventJoypadButton.new()
joypad_event.button_index = JOY_BUTTON_DPAD_UP
InputMap.action_add_event("move_up", joypad_event)
```

## 示例场景

完整示例请参考：
- `demos/fuse/deep_tests/scenes/base_movement.tscn`（移动指令基础验证）
- `demos/fuse/deep_tests/scenes/test_deep_movement.tscn`（CharacterBody2D 复合移动实战）

## 技术支持

如有问题，请参考：
- 用户文档：`addons/fuse/docs/user_docs/`
- 系统文档：`addons/fuse/docs/system_docs/`
- 开发文档：`addons/fuse/docs/development/`

---

**版本:** 1.1
**最后更新:** 2026-02-08
**兼容:** Godot 4.7+

**更新日志:**
- v1.1 (2026-02-08): 更新移动模式说明，添加三种模式详细描述，添加性能优化指南
- v1.0 (2026-02-08): 初始版本
