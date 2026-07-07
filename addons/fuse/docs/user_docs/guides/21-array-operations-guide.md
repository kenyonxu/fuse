# Array 操作指南

Fuse 提供 18 个 Array 操作指令，涵盖元素增删、查找、排序、数值统计和向量运算等场景。大多数指令支持负索引（从末尾计数）。

## 指令总览

### 基础操作

| 指令 | 功能 | 关键参数 |
|------|------|----------|
| ArrayGet | 获取指定索引的元素 | 数组来源、索引、目标变量 |
| ArraySet | 设置指定索引的元素值 | 数组来源、索引、新值 |
| ArrayAdd | 向末尾添加元素 (push_back) | 数组来源、要添加的值 |
| ArrayInsert | 在指定位置插入元素 | 数组来源、插入位置、新值 |
| ArrayRemove | 按索引或值移除元素 | 数组来源、移除方式（索引/值） |
| ArrayClear | 清空数组所有元素 | 数组来源 |
| ArraySize | 获取数组大小 | 数组来源、目标变量 |

### 查找与检测

| 指令 | 功能 | 关键参数 |
|------|------|----------|
| ArrayFind | 查找元素索引（未找到返回 -1） | 数组来源、查找值、目标变量 |
| ArrayContains | 检查是否包含指定元素 | 数组来源、查找值、目标变量 |
| ArrayRandom | 随机获取一个元素 | 数组来源、目标变量 |

### 排序与重排

| 指令 | 功能 | 关键参数 |
|------|------|----------|
| ArrayReverse | 反转数组（原地） | 数组来源 |
| ArrayShuffle | 随机打乱（Fisher-Yates 算法） | 数组来源 |
| ArrayNumericSort | 数值数组排序（原地） | 数组来源、排序方式（升序/降序） |
| ArrayVectorSort | 按距离参考点排序向量数组 | 数组来源、参考点、排序方式（近到远/远到近） |

### 数值统计

| 指令 | 功能 | 关键参数 |
|------|------|----------|
| ArrayNumericGetSmallest | 获取最小值 | 数组来源、目标变量 |
| ArrayNumericGetLargest | 获取最大值 | 数组来源、目标变量 |

### 向量运算

| 指令 | 功能 | 关键参数 |
|------|------|----------|
| ArrayVectorGetClosest | 获取距离参考点最近的向量 | 数组来源、参考点、目标变量 |
| ArrayVectorGetFurthest | 获取距离参考点最远的向量 | 数组来源、参考点、目标变量 |

## 常见用例

### 1. 管理敌人列表

```
游戏开始 → ArrayClear(敌人列表)
敌人生成 → ArrayAdd(敌人列表, 新敌人)
敌人死亡 → ArrayRemove(敌人列表, 敌人)
波次检查 → ArraySize(敌人列表) == 0 → 触发下一波
随机目标 → ArrayRandom(敌人列表) → SetPosition
```

### 2. 排行榜系统

```
添加分数 → ArrayAdd(分数列表, 新分数)
排序 → ArrayNumericSort(分数列表, 降序)
获取最高分 → ArrayNumericGetLargest(分数列表) → 显示
```

### 3. 寻找最近敌人

```
获取所有敌人 → GetNodesInGroup → 存入位置数组
ArrayVectorGetClosest(位置数组, 玩家位置) → 最近敌人位置
LookAt(最近敌人位置)
```

## 数组来源

所有 Array 指令支持三种数组来源方式：
- **变量** - 从 Scope Variable 或 Global Variable 获取
- **节点子节点** - 从目标节点的子节点获取
- **节点组** - 从场景树中的组获取

## 注意事项

- ArrayGet / ArraySet / ArrayInsert / ArrayRemove 支持**负索引**（-1 表示最后一个元素）
- ArrayNumericSort 和 ArrayVectorSort 是**原地排序**，会直接修改原数组
- ArrayRemove 默认按索引移除，也可切换为按值移除（移除第一个匹配项）
- 数值统计指令仅支持 `int` 和 `float` 类型的数组
- 向量运算指令支持 `Vector2` 和 `Vector3` 类型的数组
