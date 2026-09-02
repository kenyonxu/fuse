> 🌐 中文 | [**English**](../../../en_US/user_docs/guides/10-transform-guide.md)

# 变换系统使用指南

## 概念准备：坐标系统

Fuse 变换指令支持 **Global（全局）** 和 **Local（局部）** 两种坐标空间。理解两者的区别对正确控制游戏对象至关重要。

### Global（全局）坐标

**Global 坐标**是相对于**场景根节点（世界原点）**的绝对坐标。

- **绝对位置**：不受父节点影响
- **世界坐标**：直接在世界空间中的位置
- **独立性**：移动父节点不会改变子节点的全局坐标值

**适用场景：** 传送点、出生点、世界空间导航、绝对位置控制

### Local（局部）坐标

**Local 坐标**是相对于**父节点**的相对坐标。

- **相对位置**：受父节点变换影响
- **层级跟随**：父节点移动时子节点跟随
- **继承性**：继承父节点的旋转与缩放

**适用场景：** 武器挂载点、UI 布局、载具座椅、相对位置调整

### 对比示例

```
World (0, 0, 0)
└─ Parent (10, 0, 0)
   └─ Child (local: 2, 0, 0)
```

| 类型 | 坐标值 | 说明 |
|------|--------|------|
| **Local** | (2, 0, 0) | 相对 Parent 的偏移 |
| **Global** | (12, 0, 0) | 相对 World 的位置 |

**使用 Local 移动 +3：** Child Local (2→5), Child Global (12→15)
**使用 Global 移动到 (20,0,0)：** Child Global (12→20), Child Local (2→10)

### 实际应用案例

| 案例 | 推荐空间 | 说明 |
|------|----------|------|
| 枪口跟随角色 | Local | 武器挂载偏移，角色移动时自动跟随 |
| 金币飞向 UI | Global | 从任意位置移动到 UI 固定位置 |
| 玩家跳跃 | Global | 物理系统在世界空间计算 |
| 载具座椅 | Local | 座椅相对车身偏移，车身移动时跟随 |

### 常见陷阱

1. **旋转后的坐标混淆**：父节点旋转后，Local X 轴 ≠ Global X 轴。明确操作是相对于对象本身还是世界。
2. **嵌套父节点**：`Root → A → B → C`，C 的 Local 是相对 B，不是相对 A。需相对更上层时使用 Global。
3. **混合使用**：同一对象上混用两种空间可能导致结果不符合预期。保持一致性。

### 坐标空间选择决策树

```
需要移动/旋转对象
├─ 是否相对于其他对象定位？ → Global
├─ 需要跟随父节点？ → Local
├─ UI 布局？ → Local
└─ 世界空间导航？ → Global
```

> **口诀**：Global 用于世界定位，Local 用于层级跟随。

---

## 变换指令详解

Fuse 变换系统提供 7 个变换指令，覆盖位置设置、相对移动、旋转设置、相对旋转、缩放设置、朝向目标和获取位置等完整的节点变换操作，所有组件均支持 2D 和 3D 节点。

### 指令列表

| 名称 | 功能描述 | 关键参数 |
|------|----------|----------|
| **SetPosition** | 设置节点的绝对位置 | `target_node`、`position`（Vector3）、`space`（Global/Local）、`use_variable`、`position_variable` / `position_scope` |
| **MoveBy** | 相对于当前位置移动节点 | `target_node`、`offset`（Vector3）、`space`（Global/Local）、`use_variable`、`offset_variable` / `offset_scope` |
| **SetRotation** | 设置节点的绝对旋转角度 | `target_node`、`space`（Global/Local）、`rotation_variable`、`rotation_scope` |
| **RotateBy** | 相对于当前旋转角度旋转 | `target_node`、`rotation_offset`（度数）、`space`（Global/Local，默认 Local）、`rotation_variable`、`rotation_scope` |
| **SetScale** | 设置节点的缩放 | `target_node`、`scale`（Vector3）、`use_variable`、`scale_variable` / `scale_scope` |
| **LookAt** | 让节点朝向目标位置或节点 | `target_node`、`target_type`（Position/Node）、`look_at_node`、`use_custom_up`、`up_vector`（3D only） |
| **GetPosition** | 获取节点当前位置并保存到变量 | `target`、`save_to_variable`、`save_to_scope`、`scope_source`、`use_global_position` |

### 指令使用说明

**坐标空间：**
- `GLOBAL`：在世界坐标系中操作
- `LOCAL`：在节点局部坐标系中操作（相对于父节点的变换）

**变量读取模式：**
- 多数变换指令支持 `use_variable` 模式，从 Local/Scope/Global 变量中读取值
- 支持 `ScopeSource` 配置作用域来源：Nearest / Custom ID / Trigger Scope / Target Node

**SetRotation 与 RotateBy 的区别：**
- `SetRotation` 设置绝对旋转角度，直接覆盖当前值
- `RotateBy` 在当前旋转基础上叠加偏移量

**LookAt 目标类型：**
- `POSITION`：朝向指定坐标位置
- `NODE`：朝向指定节点的位置

**GetPosition 结果：**
- 2D 节点返回 `Vector2`，3D 节点返回 `Vector3`
- `use_global_position`（默认 true）：true 时返回全局坐标（`global_position`），false 时返回局部坐标（`position`）
- 通过 `save_to_variable`（变量名）和 `save_to_scope`（作用域）配置保存位置

---

## 常见用例

### 1. 角色瞬移

```
SetPosition → target_node: Player, position: (100, 200, 0), space: Global
```

### 2. 角色朝向敌人

```
LookAt → target_node: Player, target_type: Node, look_at_node: Enemy
```

### 3. 获取敌人位置并计算距离

```
# 获取敌人位置
GetPosition → target: Enemy, save_to_scope: Local, result_variable: enemy_pos

# 使用 MathExpression 计算距离
MathExpression → 表达式: distance(vec2(0, 0), vec2({local:player_x}, {local:player_y}))
```

---

**相关文档:**
- [移动系统指南](11-movement-system-guide.md)
- [Node Operations 指令指南](20-node-operations-guide.md)
