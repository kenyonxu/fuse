# Bricks Phase 1 Conditions 重命名计划

**目标:** 修复 Phase 1 条件的命名规范符合性问题
**参考规范:** [condition_creation_guide.md](../addons/bricks/docs/development/condition_creation_guide.md)
**创建日期:** 2026-01-30

---

## 📋 重命名清单

### 复合逻辑类（4个）

| 序号 | 当前文件名 | 新文件名 | 当前类名 | 新类名 | 类型 |
|------|-----------|---------|---------|--------|------|
| 1 | `condition_not.gd` | `check_not.gd` | ConditionNot | CheckNot | 检查类 |
| 2 | `condition_all.gd` | `check_all.gd` | ConditionAll | CheckAll | 检查类 |
| 3 | `condition_any.gd` | `check_any.gd` | ConditionAny | CheckAny | 检查类 |
| 4 | `condition_composite.gd` | `check_composite.gd` | ConditionComposite | CheckComposite | 检查类 |

### 节点操作类（2个）

| 序号 | 当前文件名 | 新文件名 | 当前类名 | 新类名 | 类型 |
|------|-----------|---------|---------|--------|------|
| 5 | `condition_node_active.gd` | `check_node_active.gd` | ConditionNodeActive | CheckNodeActive | 检查类 |
| 6 | `condition_node_in_group.gd` | `check_node_in_group.gd` | ConditionNodeInGroup | CheckNodeInGroup | 检查类 |

### 物理检测类（2个）

| 序号 | 当前文件名 | 新文件名 | 当前类名 | 新类名 | 类型 |
|------|-----------|---------|---------|--------|------|
| 7 | `condition_on_floor.gd` | `check_on_floor.gd` | ConditionOnFloor | CheckOnFloor | 检查类 |
| 8 | `condition_in_air.gd` | `check_in_air.gd` | ConditionInAir | CheckInAir | 检查类 |

### 输入检测类（3个）

| 序号 | 当前文件名 | 新文件名 | 当前类名 | 新类名 | 类型 |
|------|-----------|---------|---------|--------|------|
| 9 | `condition_input_pressed.gd` | `check_input_pressed.gd` | ConditionInputPressed | CheckInputPressed | 检查类 |
| 10 | `condition_input_released.gd` | `check_input_released.gd` | ConditionInputReleased | CheckInputReleased | 检查类 |
| 11 | `condition_input_held.gd` | `check_input_held.gd` | ConditionInputHeld | CheckInputHeld | 检查类 |

### 时间检测类（1个）

| 序号 | 当前文件名 | 新文件名 | 当前类名 | 新类名 | 类型 |
|------|-----------|---------|---------|--------|------|
| 12 | `condition_time_reached.gd` | `check_time_reached.gd` | ConditionTimeReached | CheckTimeReached | 检查类 |

### 距离检测类（1个）

| 序号 | 当前文件名 | 新文件名 | 当前类名 | 新类名 | 类型 |
|------|-----------|---------|---------|--------|------|
| 13 | `condition_distance.gd` | `check_distance.gd` | ConditionDistance | CheckDistance | 检查类 |

**注意:** 虽然 Distance 是比较值，但它的主要功能是"检查距离是否满足条件"，因此使用 `check_` 前缀更合适。

---

## 🔧 重命名步骤

### Step 1: 创建备份（可选但推荐）

```bash
# 创建备份分支
git checkout -b backup-before-renaming
git push origin backup-before-renaming

# 切回工作分支
git checkout Develop_brick
```

### Step 2: 重命名文件和更新类名

对每个文件执行以下操作：

1. **读取原文件**
2. **更新类名**（全局替换）
3. **更新所有引用**（测试文件等）
4. **写入新文件**
5. **删除原文件**

### Step 3: 更新测试文件引用

测试文件中需要更新的引用：

- `test_composite_conditions.gd` - 更新 ConditionNot, ConditionAll, ConditionAny, ConditionComposite
- `test_node_conditions.gd` - 更新 ConditionNodeActive, ConditionNodeInGroup
- `test_physics_conditions.gd` - 更新 ConditionOnFloor, ConditionInAir
- `test_input_conditions.gd` - 更新所有输入条件类名
- `test_time_conditions.gd` - 更新 ConditionTimeReached
- `test_distance_conditions.gd` - 更新 ConditionDistance
- `test_phase1_integration.gd` - 更新所有条件类名

### Step 4: 更新 .uid 文件

重命名 .gd.uid 文件以匹配新文件名。

### Step 5: 验证所有更改

```bash
# 运行 Godot 语法检查
E:\Godot\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64.exe --headless --check-only --quit
```

### Step 6: 提交更改

```bash
git add -A
git commit -m "refactor(conditions): 重命名条件文件以符合命名规范

- 将所有 condition_ 前缀改为 check_ 前缀
- 更新所有类名以匹配新文件名
- 更新测试文件中的引用
- 符合 condition_creation_guide.md 规范

重命名清单:
- condition_not.gd → check_not.gd (ConditionNot → CheckNot)
- condition_all.gd → check_all.gd (ConditionAll → CheckAll)
- condition_any.gd → check_any.gd (ConditionAny → CheckAny)
- condition_composite.gd → check_composite.gd (ConditionComposite → CheckComposite)
- condition_node_active.gd → check_node_active.gd (ConditionNodeActive → CheckNodeActive)
- condition_node_in_group.gd → check_node_in_group.gd (ConditionNodeInGroup → CheckNodeInGroup)
- condition_on_floor.gd → check_on_floor.gd (ConditionOnFloor → CheckOnFloor)
- condition_in_air.gd → check_in_air.gd (ConditionInAir → CheckInAir)
- condition_input_pressed.gd → check_input_pressed.gd (ConditionInputPressed → CheckInputPressed)
- condition_input_released.gd → check_input_released.gd (ConditionInputReleased → CheckInputReleased)
- condition_input_held.gd → check_input_held.gd (ConditionInputHeld → CheckInputHeld)
- condition_time_reached.gd → check_time_reached.gd (ConditionTimeReached → CheckTimeReached)
- condition_distance.gd → check_distance.gd (ConditionDistance → CheckDistance)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## 📝 需要更新的字符串

### 条件文件中的替换

每个文件中需要替换的字符串：

```gdscript
# 类名替换
class_name ConditionNot → class_name CheckNot
class_name ConditionAll → class_name CheckAll
class_name ConditionAny → class_name CheckAny
class_name ConditionComposite → class_name CheckComposite
class_name ConditionNodeActive → class_name CheckNodeActive
class_name ConditionNodeInGroup → class_name CheckNodeInGroup
class_name ConditionOnFloor → class_name CheckOnFloor
class_name ConditionInAir → class_name CheckInAir
class_name ConditionInputPressed → class_name CheckInputPressed
class_name ConditionInputReleased → class_name CheckInputReleased
class_name ConditionInputHeld → class_name CheckInputHeld
class_name ConditionTimeReached → class_name CheckTimeReached
class_name ConditionDistance → class_name CheckDistance

# 元数据中的类名引用
var condition = ConditionNot.new() → var condition = CheckNot.new()
var condition = ConditionAll.new() → var condition = CheckAll.new()
# ... 等等
```

### 测试文件中的替换

每个测试文件中需要更新的类名引用：

```gdscript
# test_composite_conditions.gd
ConditionNot → CheckNot
ConditionAll → CheckAll
ConditionAny → CheckAny
ConditionComposite → CheckComposite

# test_node_conditions.gd
ConditionNodeActive → CheckNodeActive
ConditionNodeInGroup → CheckNodeInGroup

# test_physics_conditions.gd
ConditionOnFloor → CheckOnFloor
ConditionInAir → CheckInAir

# test_input_conditions.gd
ConditionInputPressed → CheckInputPressed
ConditionInputReleased → CheckInputReleased
ConditionInputHeld → CheckInputHeld

# test_time_conditions.gd
ConditionTimeReached → CheckTimeReached

# test_distance_conditions.gd
ConditionDistance → CheckDistance

# test_phase1_integration.gd
# 所有上述类名都需要更新
```

---

## ⚠️ 注意事项

1. **类名区分大小写** - Godot 中类名区分大小写，必须全局替换
2. **字符串引用** - 确保字符串中的类名也被替换
3. **资源引用** - .tscn 文件中可能有对类的引用
4. **预加载** - 检查是否有 preload() 引用
5. **依赖关系** - 条件之间可能有相互引用（如 ConditionComposite 引用其他条件）

---

## 📊 影响范围

| 文件类型 | 数量 | 说明 |
|---------|------|------|
| 条件实现文件 | 13 | 需要重命名和类名替换 |
| 测试脚本文件 | 7 | 需要更新类名引用 |
| .uid 文件 | 13 | 需要重命名 |
| 场景文件 | 8+ | 可能包含类引用 |

---

## ✅ 验证清单

- [ ] 所有 .gd 文件已重命名
- [ ] 所有类名已更新
- [ ] 所有测试文件中的引用已更新
- [ ] .uid 文件已重命名
- [ ] Godot 语法检查通过
- [ ] 测试场景可以正常运行
- [ ] Git 提交已创建
- [ ] 文档已更新（如有需要）

---

## 🚀 执行

建议使用自动化脚本来执行重命名，以减少人为错误。

**下一步:** 执行重命名脚本
