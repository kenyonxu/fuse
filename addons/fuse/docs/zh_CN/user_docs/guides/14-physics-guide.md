# 物理系统使用指南

Fuse 物理系统提供 5 个物理指令和 10 个物理事件，覆盖力的施加、速度设置、碰撞检测、区域检测、射线检测和屏幕可见性检测等常见物理交互需求。所有组件均支持 2D 和 3D 物理。

## 指令列表

| 名称 | 功能描述 | 关键参数 |
|------|----------|----------|
| **ApplyForce** | 对 RigidBody 施加持续力（如风力、推进器） | `target_node`（目标物理体）、`use_3d`（是否 3D）、`force` / `force_3d`（力向量）、`use_center`（是否在中心施力）、`force_position`（施力偏移位置） |
| **ApplyImpulse** | 对 RigidBody 施加瞬间冲量（如爆炸、跳跃） | `target_node`（目标物理体）、`use_3d`（是否 3D）、`impulse` / `impulse_3d`（冲量向量）、`use_center`（是否在中心施力）、`impulse_position`（施力偏移位置） |
| **SetVelocity** | 设置物理体的速度（CharacterBody / RigidBody） | `target_node`（目标物理体）、`use_3d`（是否 3D）、`velocity` / `velocity_3d`（速度向量）、`use_local_space`（是否使用局部坐标系） |
| **SetCollisionLayer** | 设置碰撞对象的碰撞层和/或掩码 | `target_node`（目标碰撞对象）、`set_type`（设置类型：Layer/Mask/Both）、`layer_value`（层值）、`mask_value`（掩码值） |
| **Raycast** | 从指定位置发射射线检测碰撞 | `use_3d`（是否 3D）、`from_position` / `from_position_3d`（起点）、`to_position` / `to_position_3d`（终点）、`collision_mask`（碰撞层掩码）、`exclude_target`（排除节点）、`save_result`（是否保存到变量）、`result_variable`（变量名） |

### 指令使用说明

**ApplyForce vs ApplyImpulse：**
- `ApplyForce` 施加持续力，适合风力、推进器等效果，需在物理帧中反复调用
- `ApplyImpulse` 施加瞬间冲量，适合爆炸、跳跃等一次性效果

**施力位置：**
- `use_center = true` 时在物体中心施力，不产生旋转
- `use_center = false` 时在偏移位置施力，会产生旋转力矩

**SetVelocity 目标类型：**
- CharacterBody2D/3D：直接设置 `velocity` 属性
- RigidBody2D/3D：设置 `linear_velocity` 属性，支持局部坐标系转换

**Raycast 结果格式：**
保存到变量时返回字典：
```json
{
  "collider": <碰撞体对象或 null>,
  "point": <碰撞点 Vector2/Vector3>,
  "normal": <碰撞法线 Vector2/Vector3>,
  "distance": <距离 float>
}
```

---

## 事件列表

| 名称 | 触发条件 | 输出数据 |
|------|----------|----------|
| **OnArea2DEnter** | PhysicsBody 或 Area 进入 Area2D 区域 | `body`（进入的物体）、`area`（进入的 Area2D） |
| **OnArea2DExited** | PhysicsBody 或 Area 离开 Area2D 区域 | `body`（离开的物体）、`area`（离开的 Area2D） |
| **OnArea3DEntered** | PhysicsBody 或 Area 进入 Area3D 区域 | `body`（进入的物体）、`area`（进入的 Area3D） |
| **OnArea3DExited** | PhysicsBody 或 Area 离开 Area3D 区域 | `body`（离开的物体）、`area`（离开的 Area3D） |
| **OnBodyEntered** | PhysicsBody 进入 Area2D 区域 | `body`（进入的 PhysicsBody2D） |
| **OnCollision** | 物理体发生碰撞时触发 | `collider`（碰撞体）、`collider_shape_index`、`local_shape_index`、`target_shape`、`body_shape`、`collider_velocity`（CharacterBody 时） |
| **OnOverlappingBodies** | 区域内重叠物体数量满足阈值条件 | `count`（当前重叠数量） |
| **OnShapeCast** | ShapeCast 检测到碰撞 | `collider`（碰撞体）、`collision_point`（碰撞点）、`collision_normal`（碰撞法线） |
| **OnRaycastHit** | RayCast 射线命中物体时触发 | `collider`（碰撞体）、`collision_point`（碰撞点）、`collision_normal`（碰撞法线）、`raycast_origin`（射线起点） |
| **OnScreenEnteredExited** | 节点进入或离开摄像机视野 | `target_node`（目标节点）、`is_on_screen`、`was_on_screen`、`event_type`（"entered" / "exited"） |

### 事件使用说明

**区域事件通用参数：**
- `area_node_path` / `area_node`：目标 Area 节点路径
- `target_group`：目标组名过滤，为空时匹配任何物体
- `trigger_once_per_body`：每个物体只触发一次（进入时触发，离开后重置）

**OnOverlappingBodies 比较方式：**
- `Greater`：数量大于阈值时触发
- `Less`：数量小于阈值时触发
- `Equal`：数量等于阈值时触发

**OnScreenEnteredExited 触发时机：**
- `ENTER`：仅进入屏幕时触发
- `EXIT`：仅离开屏幕时触发
- `BOTH`：进入和离开都触发

**OnCollision 碰撞层过滤：**
设置 `collision_mask` 可按碰撞层过滤碰撞对象，0 表示不过滤。

---

## 常见用例

### 1. 平台游戏 - 角色跳跃

使用 `OnBodyEntered` 检测角色落地，使用 `ApplyImpulse` 施加跳跃冲量：

```
# 事件：检测角色与地面碰撞
OnBodyEntered → area_node: GroundArea, target_group: "player"

# 指令：施加跳跃冲量
ApplyImpulse → target_node: Player, impulse: (0, -500), use_center: true
```

### 2. 2D 游戏 - 敌人视野检测

使用 `OnRaycastHit` 检测敌人是否看到玩家：

```
# 事件：射线检测
OnRaycastHit → origin_node_path: Enemy, target_position: (200, 0), collision_mask: Layer 1

# 指令（在事件触发后执行）：
# 检测到碰撞体后触发追击逻辑
```

### 3. 多人游戏 - 区域人数检测

使用 `OnOverlappingBodies` 检测区域内玩家数量：

```
# 事件：区域内人数 >= 2 时触发
OnOverlappingBodies → area_node: ZoneArea, comparison: Greater, check_threshold: 2, trigger_once: true, emit_count: true
```
