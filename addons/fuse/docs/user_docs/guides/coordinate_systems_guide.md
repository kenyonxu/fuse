# 坐标系统指南 - Global 与 Local

## 📚 概述

在 Fuse 可视化编程系统中，许多与节点变换相关的指令（如移动、旋转、缩放）都支持 **Global（全局）** 和 **Local（局部）** 两种坐标空间。

理解这两种坐标空间的区别对于正确控制游戏对象至关重要。

## 🌍 Global（全局）坐标系统

### 定义
**Global 坐标**是相对于**场景根节点**（世界原点）的绝对坐标。

### 特点
- ✅ **绝对位置**：不受父节点影响
- ✅ **世界坐标**：直接在世界空间中的位置
- ✅ **独立性**：移动父节点不会改变子节点的全局坐标值
- ✅ **直观性**：在 3D 空间中更直观

### 使用场景
```gdscript
# 示例：将对象移动到世界坐标 (10, 0, 5)
# 无论对象的父节点在哪里，它都会在世界空间中移动到该位置
```

**适用情况**：
- 将对象放置在游戏世界的特定位置
- 绝对位置控制（如传送点、出生点）
- 不受层级关系影响的移动
- 3D 空间中的导航

## 🏠 Local（局部）坐标系统

### 定义
**Local 坐标**是相对于**父节点**的相对坐标。

### 特点
- ✅ **相对位置**：受父节点变换影响
- ✅ **层级跟随**：父节点移动时，子节点跟随移动
- ✅ **相对性**：值表示相对于父节点的偏移
- ✅ **继承性**：继承父节点的旋转、缩放

### 使用场景
```gdscript
# 示例：将对象相对于父节点移动 (0, 1, 0)
# 如果父节点在 (10, 0, 0)，子节点会移动到 (10, 1, 0)
```

**适用情况**：
- 对象需要跟随父节点移动
- UI 元素布局
- 相对位置的调整
- 载具、角色附加物（如武器挂载点）

## 📊 对比示例

### 场景设置
```
World (0, 0, 0)
└─ Parent (10, 0, 0)
   └─ Child (local: 2, 0, 0)
```

### Child 节点的坐标
| 类型 | 坐标值 | 说明 |
|------|--------|------|
| **Local** | (2, 0, 0) | 相对 Parent 的偏移 |
| **Global** | (12, 0, 0) | 相对 World 的位置 |

### 移动示例

#### 使用 Local 坐标移动
```gdscript
# 将 Child 相对于 Parent 向 X 轴移动 +3
# Local: (2, 0, 0) → (5, 0, 0)
# Global: (12, 0, 0) → (15, 0, 0)
```

#### 使用 Global 坐标移动
```gdscript
# 将 Child 移动到世界坐标 (20, 0, 0)
# Local: (2, 0, 0) → (10, 0, 0)
# Global: (12, 0, 0) → (20, 0, 0)
```

## 🎮 实际应用案例

### 案例 1：角色武器系统

```
Character (世界中的位置: 100, 0, 50)
└─ Weapon (枪口)
```

**需求**：枪口需要跟随角色移动

**解决方案**：使用 **Local 坐标**
```gdscript
# 武器挂载在角色手部
# Local: (0.5, 1.5, 0.8)  # 相对角色的偏移
# 当角色移动时，武器自动跟随
```

### 案例 2：物品收集

**需求**：将收集到的金币移动到固定位置

**解决方案**：使用 **Global 坐标**
```gdscript
# 无论金币在哪里，都移动到 UI 固定位置
# MoveTo "UI_CoinIcon" with Global space
```

### 案例 3：2D 平台游戏

**需求**：玩家跳跃

**解决方案**：使用 **Global 坐标**（Y 轴）
```gdscript
# 物理系统通常在世界空间计算
# Jump height = 5 units in Global Y
```

### 案例 4：载具系统

```
Car (可移动)
├─ Driver Seat
├─ Passenger Seat
└─ Trunk
```

**解决方案**：使用 **Local 坐标**
```gdscript
# 所有座椅相对于车身的 Local 位置保持不变
# Car 移动时，所有座椅跟随
```

## 🔧 Fuse 指令中的坐标空间选择

以下 Fuse 指令支持坐标空间选择：

| 指令 | 坐标空间选项 | 推荐场景 |
|------|-------------|----------|
| **Move To** | Global / Local | 绝对定位用 Global，相对布局用 Local |
| **Move By** | Global / Local | 世界移动用 Global，相对移动用 Local |
| **Rotate To** | Global / Local | 绝对角度用 Global，相对旋转用 Local |
| **Rotate By** | Global / Local | 累计旋转通常用 Local |
| **Set Scale** | Global / Local | 绝对大小用 Global，相对缩放用 Local |
| **Look At** | - | 始终使用 Global（世界空间朝向） |

## ⚠️ 常见陷阱

### 陷阱 1：旋转后的坐标混淆

**问题**：
```gdscript
# 父节点旋转 90° 后
# Local X 轴 ≠ Global X 轴！
```

**解决方案**：
- 明确你的操作是相对于对象本身还是世界
- 旋转相关的操作通常使用 Local 更直观

### 陷阱 2：嵌套父节点

**问题**：
```gdscript
World → A → B → C
# C 的 Local 是相对于 B，不是相对于 A
```

**解决方案**：
- 如果需要相对于更上层节点，使用 Global
- 或重新设计节点层级

### 陷阱 3：混合使用

**问题**：
```gdscript
# 先用 Local 移动，再用 Global 旋转
# 结果可能不符合预期
```

**解决方案**：
- 保持一致性：同一对象上尽量使用相同的坐标空间
- 或明确理解每次操作的影响

## 💡 最佳实践

### 1. 明确语义
```gdscript
# ✅ 好的做法
# "将角色传送到出生点" → 使用 Global
# "将武器附加到角色手部" → 使用 Local

# ❌ 避免混淆
# 不要在同一个逻辑中混用两种坐标空间
```

### 2. 节点层级设计
```gdscript
# ✅ 合理的层级
GameWorld
├─ Player (Global 移动)
│  └─ Weapon (Local 挂载)
├─ Enemies (Global 位置)
└─ UI (Local 布局)

# ❌ 避免过深嵌套
# 深层嵌套会使 Local 坐标难以追踪
```

### 3. 调试技巧
```gdscript
# 在 Godot 编辑器中：
# 1. 选中节点查看 Transform 面板
# 2. 切换 Local/Global 视图（3D 视图右上角）
# 3. 使用 Gizmo 可视化坐标轴
```

### 4. 性能考虑
```gdscript
# Global 坐标需要遍历父节点计算
# Local 坐标直接读取，性能更好

# 对于频繁操作，优先使用 Local
# 对于绝对定位，使用 Global
```

## 🎓 进阶概念

### 坐标空间转换
```gdscript
# Godot 内置转换方法
var global_pos = node.to_global(local_pos)
var local_pos = node.to_local(global_pos)
```

### 变换矩阵
- Global 变换 = 所有父节点变换的累积
- Local 变换 = 仅当前节点的变换
- `global_transform` = 父节点 `global_transform` × 本地 `transform`

## 📚 相关资源

### Godot 官方文档
- [坐标系统](https://docs.godotengine.org/en/stable/tutorials/mathematics/vector_math.html#coordinate-systems)
- [变换](https://docs.godotengine.org/en/stable/tutorials/mathematics/transformations.html)
- [节点与场景实例](https://docs.godotengine.org/en/stable/tutorials/scripting/scene_tree.html)

### Fuse 相关文档
- [变换指南](transform-guide.md) - 变换指令详解

## 🎯 快速参考

### 选择坐标空间的决策树

```
需要移动/旋转对象
    │
    ├─ 是否相对于其他对象定位？
    │   └─ YES → 使用 Global
    │
    ├─ 是否需要跟随父节点？
    │   └─ YES → 使用 Local
    │
    ├─ 是否是 UI 布局？
    │   └─ YES → 使用 Local
    │
    └─ 是否是世界空间导航？
        └─ YES → 使用 Global
```

### 口诀
> **"Global 用于世界定位，Local 用于层级跟随"**

---

**文档版本**: 1.0
**最后更新**: 2026-01-26
**作者**: Fuse 开发团队
