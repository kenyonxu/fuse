# CharacterBody2D 移动系统架构文档

## 系统概述

本移动系统是为 Fuse 可视化编程系统设计的 CharacterBody2D 控制解决方案。系统采用事件驱动架构，通过输入检测、方向计算和位移应用的分层设计，实现了灵活的移动控制。

## 架构设计

### 核心组件

```
┌─────────────────────────────────────────────────────────────┐
│                        移动系统架构                          │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Event Layer: OnInputActionComposite                 │   │
│  │  - 监听四个方向的输入动作                             │   │
│  │  - 计算移动方向向量                                   │   │
│  │  - 触发 ActionRunner                                  │   │
│  └──────────────────┬────────────────────────────────────┘   │
│                     │ Event                                  │
│                     ▼                                        │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Execution Layer: MoveCharacterBody2DComposite       │   │
│  │  - 接收移动方向和速度参数                             │   │
│  │  - 应用移动到目标节点                                 │   │
│  │  - 处理碰撞检测                                       │   │
│  └──────────────────────────────────────────────────────┘   │
│                     │                                        │
│                     ▼                                        │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Target: CharacterBody2D                             │   │
│  │  - Godot 内置物理节点                                 │   │
│  │  - 自动处理碰撞                                       │   │
│  │  - 提供速度和位置属性                                 │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

## 组件详解

### 1. OnInputActionComposite（事件）

**文件位置：** `addons/fuse/events/input/on_input_action_composite.gd`

**职责：**
- 监听四个方向的输入动作
- 计算归一化的移动方向向量
- 触发下游指令执行

**核心算法：**

```gdscript
# 方向向量计算
var direction = Vector2.ZERO

# 水平方向
if Input.is_action_pressed(action_right):
    direction.x += 1.0
if Input.is_action_pressed(action_left):
    direction.x -= 1.0

# 垂直方向
if Input.is_action_pressed(action_down):
    direction.y += 1.0
if Input.is_action_pressed(action_up):
    direction.y -= 1.0

# 归一化（对角线移动速度修正）
if direction.length() > 0.0:
    direction = direction.normalized()

# 存储到执行上下文
context.set_local_var("move_direction", direction)
```

**设计决策：**

1. **归一化处理：**
   - 防止对角线移动速度过快（√2 倍）
   - 确保所有方向速度一致

2. **上下文存储：**
   - 使用 `ExecutionContext` 存储方向向量
   - 避免全局变量污染
   - 支持多个独立的移动系统

3. **输入分离：**
   - 四个方向独立配置
   - 支持任意 InputMap 动作
   - 灵活的输入映射

### 2. MoveCharacterBody2DComposite（指令）

**文件位置：** `addons/fuse/instructions/movement/move_character_body_2d_composite.gd`

**职责：**
- 从上下文获取移动方向
- 应用速度参数
- 执行 CharacterBody2D 移动
- 处理不同移动模式

**核心实现：**

```gdscript
func execute(context: ExecutionContext) -> void:
    # 获取目标节点
    var target: CharacterBody2D = _get_target_node(context)
    if not target:
        return

    # 获取移动方向
    var direction = context.get_local_var("move_direction", Vector2.ZERO)

    # 计算速度向量
    var velocity = direction * speed

    # 应用移动
    if move_mode == MoveMode.SLIDE:
        target.velocity = velocity
        target.move_and_slide()
    else:  # DIRECT
        # 对于小移动，直接修改位置
        var delta = get_physics_process_delta_time()
        target.position += velocity * delta
```

**移动模式对比：**

| 模式 | 方法 | 适用场景 | 优点 | 缺点 |
|------|------|----------|------|------|
| DIRECT | 修改 position | 小移动、网格移动 | 精确控制 | 可能穿墙 |
| SLIDE | move_and_slide | 持续移动 | 自动碰撞处理 | 需要每帧调用 |

**设计决策：**

1. **节点路径解析：**
   - 使用 `FuseNodeUtils.find_node_from_resource_context()`
   - 支持 Resource 上下文的相对路径
   - 编辑器安全的节点查找

2. **错误处理：**
   - 节点不存在时静默失败
   - 不抛出异常，避免中断执行流程
   - 使用 FuseLogger 记录警告

3. **类型安全：**
   - 强制类型检查 `as CharacterBody2D`
   - 防止类型错误导致的崩溃

## 数据流

```
Input (按键) → InputMap → OnInputActionComposite
                                    ↓
                            计算方向向量
                                    ↓
                            存储到 Context
                                    ↓
                            MoveCharacterBody2DComposite
                                    ↓
                            应用速度 × 方向
                                    ↓
                            CharacterBody2D.move_and_slide()
                                    ↓
                            物理引擎处理碰撞
                                    ↓
                            更新位置
```

## 扩展指南

### 添加新的移动模式

1. 在 `MoveCharacterBody2DComposite` 中添加枚举值：

```gdscript
enum MoveMode {
    DIRECT,
    SLIDE,
    NEW_MODE  # 新模式
}
```

2. 在 `execute()` 方法中实现逻辑：

```gdscript
elif move_mode == MoveMode.NEW_MODE:
    # 实现新模式逻辑
    pass
```

3. 更新 `_get_property_list()` 以支持新模式参数

### 添加加速度/减速度

```gdscript
@export var acceleration: float = 1000.0
@export var friction: float = 1000.0

func execute(context: ExecutionContext) -> void:
    var target: CharacterBody2D = _get_target_node(context)
    var direction = context.get_local_var("move_direction", Vector2.ZERO)

    # 计算目标速度
    var target_velocity = direction * speed

    # 应用加速度
    if direction.length() > 0:
        target.velocity = target.velocity.lerp(target_velocity, acceleration * delta)
    else:
        # 应用摩擦力
        target.velocity = target.velocity.lerp(Vector2.ZERO, friction * delta)

    target.move_and_slide()
```

### 添加动画支持

```gdscript
@export var animation_player: NodePath = NodePath("")

func execute(context: ExecutionContext) -> void:
    # 移动逻辑...

    # 播放动画
    var anim_player = get_node(animation_player) as AnimationPlayer
    if anim_player:
        if direction.length() > 0:
            anim_player.play("walk")
        else:
            anim_player.play("idle")
```

## 性能优化

### 1. 节点缓存

```gdscript
var _cached_target: CharacterBody2D = null

func _get_target_node(context: ExecutionContext) -> CharacterBody2D:
    if not _cached_target:
        _cached_target = FuseNodeUtils.find_node_from_resource_context(
            context,
            target_node,
            CharacterBody2D
        )
    return _cached_target
```

### 2. 避免重复计算

```gdscript
# ❌ 错误：每帧都归一化
func execute(context: ExecutionContext):
    var direction = context.get_local_var("move_direction")
    if direction.length() > 0:
        direction = direction.normalized()  # 重复归一化

# ✅ 正确：在 Event 中归一化一次
# Event 中已经归一化，直接使用
```

### 3. 使用物理回调

```gdscript
# 在 CharacterBody2D 的脚本中
func _on_body_entered(body):
    # 处理碰撞
    pass
```

## 测试策略

### 单元测试

```gdscript
# test_direction_calculation.gd
func test_cardinal_directions():
    var direction = Vector2(1, 0)
    assert(direction.normalized() == Vector2(1, 0))

func test_diagonal_directions():
    var direction = Vector2(1, 1)
    var normalized = direction.normalized()
    assert(abs(normalized.length() - 1.0) < 0.001)
```

### 集成测试

```gdscript
# test_movement_integration.gd
func test_full_movement():
    # 创建测试场景
    var player = create_test_player()
    var trigger = create_test_trigger()

    # 模拟输入
    simulate_input("move_right", true)

    # 执行一帧
    await get_tree().process_frame

    # 验证位置变化
    assert(player.position.x > 0)
```

## 调试技巧

### 1. 可视化调试

```gdscript
func _draw():
    if Engine.is_editor_hint():
        # 绘制移动方向
        draw_line(Vector2.ZERO, velocity * 0.1, Color.RED, 2)

        # 绘制速度向量
        draw_circle(Vector2.ZERO, 5, Color.BLUE)
```

### 2. 日志输出

```gdscript
func execute(context: ExecutionContext) -> void:
    FuseLogger.debug("MoveCharacterBody2DComposite", "Execute called")
    FuseLogger.debug("Direction: %s, Speed: %f" % [direction, speed])
```

### 3. 性能分析

```gdscript
var _start_time: float = 0.0

func execute(context: ExecutionContext) -> void:
    _start_time = Time.get_ticks_usec()

    # 执行逻辑...

    var elapsed = Time.get_ticks_usec() - _start_time
    if elapsed > 1000:  # 超过 1ms
        FuseLogger.warning("Movement took %d μs" % elapsed)
```

## 常见问题

### Q: 为什么使用 CharacterBody2D 而不是 RigidBody2D？

**A:** CharacterBody2D 专为玩家控制设计：
- 完全由代码控制（不受物理模拟影响）
- 内置 `move_and_slide()` 处理碰撞
- 不会翻滚或旋转

### Q: 如何处理多个移动系统？

**A:** 使用独立的 ExecutionContext：
- 每个 Trigger 有独立的上下文
- 本地变量不会互相干扰
- 支持同一节点的多个 Trigger

### Q: 如何支持 3D 移动？

**A:** 创建对应的 3D 版本：
- `OnInputActionComposite3D`（使用 Vector3）
- `MoveCharacterBody3DComposite`（继承 CharacterBody3D）
- 算法完全相同，只是向量维度不同

## 相关文档

- **用户指南：** `user_docs/movement-system-guide.md`
- **事件系统：** `system_docs/event-system.md`
- **指令系统：** `system_docs/instruction-system.md`
- **执行上下文：** `development/execution-context.md`

## 变更历史

| 版本 | 日期 | 变更内容 |
|------|------|----------|
| 1.0 | 2026-02-08 | 初始版本 |

---

**作者:** Fuse 开发团队
**版本:** 1.0
**最后更新:** 2026-02-08
**Godot 版本:** 4.6+
