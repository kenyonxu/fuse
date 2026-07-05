# 变换系统使用指南

Fuse 变换系统提供 7 个变换指令，覆盖位置设置、相对移动、旋转设置、相对旋转、缩放设置、朝向目标和获取位置等完整的节点变换操作，所有组件均支持 2D 和 3D 节点。

## 指令列表

| 名称 | 功能描述 | 关键参数 |
|------|----------|----------|
| **SetPosition** | 设置节点的绝对位置 | `target_node`（目标节点）、`position`（目标位置 Vector3）、`space`（坐标空间：Global/Local）、`use_variable`（是否从变量读取位置）、`position_variable` / `position_scope`（位置变量名和作用域） |
| **MoveBy** | 相对于当前位置移动节点 | `target_node`（目标节点）、`offset`（偏移量 Vector3）、`space`（坐标空间：Global/Local）、`use_variable`（是否从变量读取偏移量）、`offset_variable` / `offset_scope`（偏移变量名和作用域） |
| **SetRotation** | 设置节点的绝对旋转角度 | `target_node`（目标节点）、`space`（坐标空间：Global/Local）、`rotation_variable`（旋转变量名，默认 "rotation"）、`rotation_scope`（旋转变量作用域） |
| **RotateBy** | 相对于当前旋转角度旋转节点 | `target_node`（目标节点）、`rotation_offset`（旋转偏移量，度数）、`space`（坐标空间：Global/Local，默认 Local）、`rotation_variable`（旋转偏移变量名）、`rotation_scope`（旋转偏移变量作用域） |
| **SetScale** | 设置节点的缩放 | `target_node`（目标节点）、`scale`（目标缩放 Vector3）、`use_variable`（是否从变量读取缩放）、`scale_variable` / `scale_scope`（缩放变量名和作用域） |
| **LookAt** | 让节点朝向目标位置或节点 | `target_node`（要旋转的节点）、`target_type`（目标类型：Position/Node）、`look_at_node`（目标节点路径）、`use_custom_up`（是否自定义 Up 向量，仅 3D）、`up_vector`（Up 向量） |
| **GetPosition** | 获取节点的当前位置并保存到变量 | `target`（目标节点路径）、`save_to_scope`（保存到作用域）、`scope_source`（作用域来源） |

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
- 2D 节点返回 `Vector2`
- 3D 节点返回 `Vector3`
- 通过 `save_to_scope` 和 `scope_source` 配置保存到指定作用域

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
