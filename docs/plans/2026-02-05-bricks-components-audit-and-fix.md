# Bricks 系统组件审查与修复实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**目标:** 系统性审查并修复 Bricks 可视化编程系统中可能存在的节点路径解析、属性持久化和性能问题

**架构:** 基于 Material 属性 tweening 实现中发现的5个关键问题，审查所有使用动态属性列表和节点路径解析的组件，应用标准修复模式

**技术栈:**
- Godot 4.6-stable
- GDScript 2.0
- Bricks 可视化编程系统
- BricksNodeUtils 工具类

---

## 背景与上下文

### 已知问题（来自 Material 属性 tweening 实现）

1. **线程安全问题** - `get_material()` 等方法在编辑器模式下有线程检查
2. **节点路径解析问题** - Trigger 存储在子节点时，相对路径 `..` 需要特殊处理
3. **场景加载顺序问题** - 场景加载时 `edited_root` 为 null
4. **属性持久化问题** - 保存后重启编辑器，属性选择丢失
5. **性能问题** - 属性列表获取被重复调用 20+ 次

### 标准修复模式

这些模式将在审查中应用到所有相关组件：

#### 模式 1: 节点路径解析
```gdscript
# ❌ 旧代码
_target_node_instance = BricksNodeUtils.find_node_by_relative_path(
    edited_root, target_node
)

# ✅ 新代码
_target_node_instance = BricksNodeUtils.find_node_from_resource_context(
    edited_root, self, target_node
)
```

#### 模式 2: 场景加载顺序
```gdscript
func _get_property_list() -> Array[Dictionary]:
    if Engine.is_editor_hint() and _target_node_instance == null and not target_node.is_empty():
        _update_target_node_info()
    # ... 其余代码
```

#### 模式 3: 属性持久化
```gdscript
func _update_property_type_info():
    if _available_properties.is_empty():
        _update_available_properties()
    # ... 继续处理
```

#### 模式 4: 缓存机制
```gdscript
var _cached_properties: Array[PropertyInfo] = []
var _cached_node: Node = null

func _get_properties():
    if _cached_node == _target_node_instance and not _cached_properties.is_empty():
        return _cached_properties
    var properties = _compute_properties()
    _cached_properties = properties
    _cached_node = _target_node_instance
    return properties

var target_node: NodePath = NodePath(""):
    set(value):
        target_node = value
        _cached_properties.clear()
        _cached_node = null
```

---

## 审查范围

### 高优先级组件（已知有问题）

1. ✅ **TweenProperty** (`tween_property.gd`) - 已修复
2. ❌ **SetPropertyValue** (`set_property_value.gd`) - 需要修复
3. ⚠️ **RunTargetNodeFunction** (`run_target_node_function.gd`) - 需要审查

### 中优先级组件（需要检查）

**动画相关** (4个):
- `play_animation.gd`
- `set_animation_speed.gd`
- `stop_animation.gd`
- `blend_animation.gd`

**音频相关** (5个):
- `play_music.gd`
- `play_sound.gd`
- `set_audio_volume.gd`
- `pause_resume_audio.gd`
- `stop_audio.gd`

**相机相关** (4个):
- `camera_follow.gd`
- `camera_shake.gd`
- `set_camera_limit.gd`
- `set_camera_zoom.gd`

### 低优先级组件

**变换相关** (4个):
- `set_position.gd`
- `rotate_by.gd`
- `move_by.gd`
- `look_at.gd`

**物理相关** (4个):
- `set_velocity.gd`
- `apply_force.gd`
- `apply_impulse.gd`
- `set_collision_layer.gd`

**其他节点操作** (3个):
- `enable_disable_node.gd`
- `queue_free_node.gd`
- `reparent_node.gd`

---

## 任务列表

### Task 1: 审查 SetPropertyValue 组件

**文件:**
- 审查: `addons/bricks/instructions/node_operations/set_property_value.gd`
- 参考: `addons/bricks/instructions/tween/tween_property.gd` ✅ 已修复

**Step 1: 读取 SetPropertyValue 源代码**

Read: `addons/bricks/instructions/node_operations/set_property_value.gd`
关注点:
- 第83-89行：节点获取逻辑
- 第100-150行：属性列表生成逻辑
- 是否有缓存机制
- 是否有场景加载顺序处理

**Step 2: 检查节点路径解析方法**

确认第89行是否使用:
```gdscript
BricksNodeUtils.find_node_by_relative_path(edited_root, target_node)
```

如果是，记录为问题 #1：需要改为 `find_node_from_resource_context()`

**Step 3: 检查场景加载顺序处理**

搜索 `_get_property_list()` 方法，确认是否有:
```gdscript
if Engine.is_editor_hint() and _target_node_instance == null and not target_node.is_empty():
    _update_target_node_info()
```

如果没有，记录为问题 #2

**Step 4: 检查属性持久化处理**

在 `target_property` setter 中，确认是否有:
```gdscript
if _available_properties.is_empty():
    _update_available_properties()
```

如果没有，记录为问题 #3

**Step 5: 检查缓存机制**

搜索是否定义了:
- `_cached_properties`
- `_cached_node`

如果没有，记录为问题 #4

**Step 6: 创建审查报告**

Create: `docs/analysis/set_property_value-audit.md`

内容模板:
```markdown
# SetPropertyValue 组件审查报告

**审查日期:** 2026-02-05
**组件:** SetPropertyValue
**文件:** addons/bricks/instructions/node_operations/set_property_value.gd

## 发现的问题

### 问题 1: 节点路径解析
- **位置:** 第89行
- **当前代码:** `BricksNodeUtils.find_node_by_relative_path(...)`
- **问题:** 未使用资源上下文解析
- **影响:** Trigger 在子节点时会获取错误节点
- **严重程度:** 高

### 问题 2: 场景加载顺序
- **位置:** _get_property_list() 方法
- **问题:** 无场景加载顺序处理
- **影响:** 场景加载时属性信息丢失
- **严重程度:** 中

### 问题 3: 属性持久化
- **位置:** target_property setter
- **问题:** 无属性列表为空检查
- **影响:** 保存后重启属性选择丢失
- **严重程度:** 中

### 问题 4: 缓存机制
- **位置:** 整体架构
- **问题:** 无缓存机制
- **影响:** 性能问题（重复调用）
- **严重程度:** 低

## 修复建议

按优先级应用标准修复模式...

## 估计工作量

- 审查: 30分钟
- 修复: 1-2小时
- 测试: 30分钟
```

**Step 7: 提交审查报告**

```bash
git add docs/analysis/set_property_value-audit.md
git commit -m "docs(audit): 完成 SetPropertyValue 组件审查报告"
```

---

### Task 2: 修复 SetPropertyValue 组件

**文件:**
- 修改: `addons/bricks/instructions/node_operations/set_property_value.gd`
- 参考: `addons/bricks/instructions/tween/tween_property.gd:116-130` (场景加载顺序)
- 参考: `addons/bricks/instructions/tween/tween_property.gd:51-60` (属性持久化)
- 参考: `addons/bricks/instructions/tween/tween_property.gd:85-88` (缓存变量)

**Step 1: 添加缓存变量**

在第65行后添加:
```gdscript
## 运行时状态
var _target_node_instance: Node = null
var _current_property_info: PropertyInfo = null
var _current_property_type: int = TYPE_NIL
var _current_property_hint: int = PROPERTY_HINT_NONE
var _current_property_hint_string: String = ""
var _available_properties: Array[PropertyInfo] = []

# 缓存（避免重复计算属性列表）
var _cached_available_properties: Array[PropertyInfo] = []
var _cached_available_node: Node = null
```

**Step 2: 修复节点路径解析**

修改第89行:
```gdscript
# 旧代码
_target_node_instance = BricksNodeUtils.find_node_by_relative_path(edited_root, target_node)

# 新代码
_target_node_instance = BricksNodeUtils.find_node_from_resource_context(edited_root, self, target_node)
```

**Step 3: 添加场景加载顺序检查**

在 `_get_property_list()` 方法开头添加:
```gdscript
func _get_property_list() -> Array[Dictionary]:
    var properties: Array[Dictionary] = []

    # 在编辑器模式下，如果节点实例为 null 但 target_node 不为空，尝试重新获取节点
    if Engine.is_editor_hint() and _target_node_instance == null and not target_node.is_empty():
        _update_target_node_info()

    # ... 继续原有代码
```

**Step 4: 添加属性持久化检查**

在 `_update_property_type_info()` 开头添加:
```gdscript
func _update_property_type_info():
    _current_property_info = null

    if _target_node_instance == null or target_property.is_empty():
        return

    # 如果可用属性列表为空，先构建属性列表
    if _available_properties.is_empty():
        _update_available_properties()

    # ... 继续原有代码
```

**Step 5: 实现属性列表缓存**

修改 `_get_available_properties()` 方法:
```gdscript
func _get_available_properties() -> Array[PropertyInfo]:
    # 检查缓存
    if _cached_available_node == _target_node_instance and not _cached_available_properties.is_empty():
        return _cached_available_properties

    # 获取属性列表
    var properties: Array[PropertyInfo] = []
    if _target_node_instance:
        var prop_list = _target_node_instance.get_property_list()
        for prop_dict in prop_list:
            var prop_info = PropertyInfo.create(prop_dict)
            properties.append(prop_info)

    # 更新缓存
    _cached_available_properties = properties
    _cached_available_node = _target_node_instance

    return properties
```

**Step 6: 更新 target_node setter 清除缓存**

修改第22-27行:
```gdscript
var target_node: NodePath = "":
    set(value):
        target_node = value
        # 清除缓存
        _cached_available_properties.clear()
        _cached_available_node = null
        _update_target_node_info()
        _update_resource_name()
        notify_property_list_changed()
```

**Step 7: 在编辑器中测试**

1. 打开 Godot 编辑器
2. 打开测试场景: `demos/bricks/brick_ui_demo.tscn`
3. 找到包含 SetPropertyValue 指令的 Trigger
4. 修改 target_node
5. 修改 target_property
6. 保存场景
7. 关闭并重新打开编辑器
8. 确认属性选择正确恢复

**Step 8: 创建修复报告**

Create: `docs/plans/2026-02-05-set-property-value-fix-report.md`

内容模板:
```markdown
# SetPropertyValue 组件修复报告

**修复日期:** 2026-02-05
**组件:** SetPropertyValue
**文件:** addons/bricks/instructions/node_operations/set_property_value.gd

## 应用的修复

### 修复 1: 节点路径解析
- **修改位置:** 第89行
- **修改:** 使用 `find_node_from_resource_context()`
- **效果:** 正确处理 Trigger 在子节点的情况

### 修复 2: 场景加载顺序
- **修改位置:** _get_property_list() 方法
- **修改:** 添加惰性初始化检查
- **效果:** 场景加载时正确获取节点实例

### 修复 3: 属性持久化
- **修改位置:** _update_property_type_info() 方法
- **修改:** 添加属性列表为空检查
- **效果:** 保存后重启属性选择正确恢复

### 修复 4: 缓存机制
- **修改位置:** 整体架构
- **修改:** 添加缓存变量和检查逻辑
- **效果:** 避免重复计算，提升性能

## 测试结果

✅ 节点路径解析正确
✅ 场景加载顺序正确
✅ 属性持久化正确
✅ 缓存机制工作正常

## 后续建议

考虑将此修复模式应用到其他组件...
```

**Step 9: 提交修复**

```bash
git add addons/bricks/instructions/node_operations/set_property_value.gd
git add docs/plans/2026-02-05-set-property-value-fix-report.md
git commit -m "fix(set_property_value): 应用标准修复模式

- 使用 find_node_from_resource_context() 进行节点路径解析
- 添加场景加载顺序检查
- 添加属性持久化支持
- 实现属性列表缓存机制

参考: Material 属性 tweening 实现经验
"
```

---

### Task 3: 审查 RunTargetNodeFunction 组件

**文件:**
- 审查: `addons/bricks/instructions/node_operations/run_target_node_function.gd`
- 参考: `addons/bricks/instructions/tween/tween_property.gd` ✅ 已修复

**Step 1: 读取 RunTargetNodeFunction 源代码**

Read: `addons/bricks/instructions/node_operations/run_target_node_function.gd`
关注点:
- 第931-961行：`_get_target_node_in_editor()` 方法
- 是否有资源上下文处理
- 自定义节点获取逻辑是否正确

**Step 2: 分析节点获取逻辑**

检查 `_get_target_node_in_editor()` 方法:
```gdscript
func _get_target_node_in_editor() -> Node:
    # 当前实现只处理了 "../" 前缀
    # 但没有考虑资源上下文
```

确认是否有以下问题:
- 问题 #1: 未使用 `BricksNodeUtils.find_node_from_resource_context()`
- 问题 #2: 自定义逻辑可能不完整

**Step 3: 检查是否可以复用 BricksNodeUtils**

确认自定义逻辑是否可以简化为:
```gdscript
return BricksNodeUtils.find_node_from_resource_context(
    edited_scene_root, self, target_node
)
```

**Step 4: 创建审查报告**

Create: `docs/analysis/run_target_node_function-audit.md`

内容模板:
```markdown
# RunTargetNodeFunction 组件审查报告

**审查日期:** 2026-02-05
**组件:** RunTargetNodeFunction
**文件:** addons/bricks/instructions/node_operations/run_target_node_function.gd

## 当前实现分析

### 节点获取逻辑
- **位置:** 第931-961行
- **方法:** `_get_target_node_in_editor()`
- **实现:** 自定义节点获取逻辑

## 发现的问题

### 问题 1: 未使用标准工具
- **问题:** 自定义实现而非使用 `BricksNodeUtils.find_node_from_resource_context()`
- **影响:** 可能有边缘情况未覆盖
- **严重程度:** 中

### 问题 2: 代码重复
- **问题:** 节点获取逻辑与其他组件重复
- **影响:** 维护成本增加
- **严重程度:** 低

## 修复建议

选项 A: 重构使用 BricksNodeUtils
- 优点: 简化代码，统一行为
- 缺点: 需要充分测试

选项 B: 保持自定义实现
- 优点: 保持现状
- 缺点: 代码重复，可能有边缘情况

## 建议

推荐选项 A：重构使用 BricksNodeUtils
```

**Step 5: 提交审查报告**

```bash
git add docs/analysis/run_target_node_function-audit.md
git commit -m "docs(audit): 完成 RunTargetNodeFunction 组件审查报告"
```

---

### Task 4: 审查动画相关组件

**文件:**
- 审查: `addons/bricks/instructions/animation/*.gd`

**Step 1: 搜索使用动态属性列表的动画指令**

```bash
grep -r "_get_property_list\|target_property" addons/bricks/instructions/animation/*.gd
```

**Step 2: 识别需要审查的组件**

根据搜索结果，识别使用以下模式的组件:
- `target_node: NodePath`
- `_get_property_list()` 方法
- `Engine.is_editor_hint()` 检查

**Step 3: 逐个审查识别的组件**

对每个识别的组件，检查:
1. 节点路径解析方法
2. 场景加载顺序处理
3. 属性持久化处理
4. 缓存机制

**Step 4: 创建批量审查报告**

Create: `docs/analysis/animation-components-audit.md`

内容模板:
```markdown
# 动画组件批量审查报告

**审查日期:** 2026-02-05
**范围:** addons/bricks/instructions/animation/

## 审查的组件

### play_animation.gd
- 需要修复: 是/否
- 问题: 列出问题
- 优先级: 高/中/低

### set_animation_speed.gd
...

## 修复优先级

1. play_animation.gd - 高优先级
2. ...

## 估计总工作量

- 审查: X小时
- 修复: Y小时
- 测试: Z小时
```

**Step 5: 提交审查报告**

```bash
git add docs/analysis/animation-components-audit.md
git commit -m "docs(audit): 完成动画组件批量审查报告"
```

---

### Task 5: 审查音频相关组件

**文件:**
- 审查: `addons/bricks/instructions/audio/*.gd`

**Step 1: 搜索使用动态属性列表的音频指令**

```bash
grep -r "_get_property_list\|target_property" addons/bricks/instructions/audio/*.gd
```

**Step 2: 识别需要审查的组件**

根据搜索结果识别组件

**Step 3: 逐个审查组件**

同 Task 4 的审查流程

**Step 4: 创建批量审查报告**

Create: `docs/analysis/audio-components-audit.md`

**Step 5: 提交审查报告**

```bash
git add docs/analysis/audio-components-audit.md
git commit -m "docs(audit): 完成音频组件批量审查报告"
```

---

### Task 6: 审查相机相关组件

**文件:**
- 审查: `addons/bricks/instructions/camera/*.gd`

**Step 1-5:** 同 Task 4 的流程

**Step 6: 创建批量审查报告**

Create: `docs/analysis/camera-components-audit.md`

**Step 7: 提交审查报告**

```bash
git add docs/analysis/camera-components-audit.md
git commit -m "docs(audit): 完成相机组件批量审查报告"
```

---

### Task 7: 创建综合修复优先级报告

**文件:**
- 创建: `docs/analysis/bricks-components-fix-priority.md`

**Step 1: 汇总所有审查报告**

收集以下报告:
- `set_property_value-audit.md`
- `run_target_node_function-audit.md`
- `animation-components-audit.md`
- `audio-components-audit.md`
- `camera-components-audit.md`

**Step 2: 创建修复优先级矩阵**

```markdown
# Bricks 组件修复优先级报告

**生成日期:** 2026-02-05
**范围:** 所有使用动态属性列表的 Bricks 组件

## 修复优先级分类

### 🔥 紧急修复（高影响 + 高风险）

1. **SetPropertyValue**
   - 文件: `set_property_value.gd`
   - 问题: 4个
   - 影响: 核心功能
   - 估计工作量: 2小时
   - 优先级: P0

### ⚠️ 高优先级（高影响 + 中风险）

2. **RunTargetNodeFunction**
   - 文件: `run_target_node_function.gd`
   - 问题: 2个
   - 影响: 核心功能
   - 估计工作量: 3小时
   - 优先级: P1

3. **PlayAnimation**
   - 文件: `play_animation.gd`
   - 问题: X个
   - 估计工作量: X小时
   - 优先级: P1

### 📝 中优先级（中影响）

4. 动画组件（其他）
5. 音频组件
6. 相机组件

### 🔍 低优先级（低影响）

7. 变换组件
8. 物理组件
9. 其他节点操作

## 修复工作量估算

| 优先级 | 组件数量 | 总估计时间 |
|--------|----------|------------|
| P0 | 1 | 2小时 |
| P1 | 5 | 15小时 |
| P2 | 10 | 20小时 |
| P3 | 10 | 10小时 |
| **总计** | **26** | **47小时** |

## 建议修复顺序

### 第一阶段（本周）
1. SetPropertyValue
2. RunTargetNodeFunction

### 第二阶段（下周）
3. PlayAnimation
4. SetAnimationSpeed
5. PlayMusic
6. PlaySound

### 第三阶段（后续）
7-16. 其他动画/音频/相机组件

### 第四阶段（按需）
17-26. 变换/物理/其他组件

## 风险评估

### 高风险
- SetPropertyValue: 核心功能，用户常用

### 中风险
- 动画组件: 用户体验相关
- 音频组件: 功能完整性

### 低风险
- 变换组件: 使用频率低
- 物理组件: 边缘功能

## 修复策略

1. **快速修复**: 先修复 P0 和 P1 组件
2. **批量修复**: 同类组件一起修复
3. **测试驱动**: 每个修复都需要测试
4. **文档更新**: 修复后更新文档

## 验收标准

每个修复必须满足:
- ✅ 使用 `find_node_from_resource_context()`
- ✅ 有场景加载顺序检查
- ✅ 有属性持久化处理
- ✅ 有缓存机制（如适用）
- ✅ 通过编辑器测试
- ✅ 通过场景保存/重启测试
```

**Step 3: 提交综合报告**

```bash
git add docs/analysis/bricks-components-fix-priority.md
git commit -m "docs(audit): 创建 Bricks 组件修复优先级综合报告

- 汇总所有组件审查结果
- 建立修复优先级矩阵
- 提供工作量估算
- 制定分阶段修复计划
"
```

---

### Task 8: 创建修复指南文档

**文件:**
- 创建: `addons/bricks/docs/development/bricks-component-fix-guide.md`

**Step 1: 创建标准修复指南**

```markdown
# Bricks 组件标准修复指南

**创建日期:** 2026-02-05
**基于:** Material 属性 tweening 实现经验

## 适用场景

本指南适用于以下 Bricks 组件:
- 使用 `target_node: NodePath` 的组件
- 使用动态属性列表的组件
- 在编辑器模式下需要获取节点实例的组件

## 标准修复清单

### ✅ 修复 1: 节点路径解析

**问题:** 组件使用 `find_node_by_relative_path()` 而非 `find_node_from_resource_context()`

**如何检测:**
```bash
grep "find_node_by_relative_path" <component_file>.gd
```

**如何修复:**
```gdscript
# 旧代码
_target_node_instance = BricksNodeUtils.find_node_by_relative_path(
    edited_root, target_node
)

# 新代码
_target_node_instance = BricksNodeUtils.find_node_from_resource_context(
    edited_root, self, target_node
)
```

**验证:** 创建 Trigger 在子节点，使用 `..` 路径，确认正确获取节点

---

### ✅ 修复 2: 场景加载顺序

**问题:** 场景加载时 `edited_root` 为 null，导致节点实例获取失败

**如何检测:**
检查 `_get_property_list()` 方法是否有:
```gdscript
if Engine.is_editor_hint() and _target_node_instance == null and not target_node.is_empty():
    _update_target_node_info()
```

**如何修复:**
```gdscript
func _get_property_list() -> Array[Dictionary]:
    var properties: Array[Dictionary] = []

    # 添加这个检查
    if Engine.is_editor_hint() and _target_node_instance == null and not target_node.is_empty():
        _update_target_node_info()

    # ... 继续原有代码
```

**验证:** 保存场景，重启编辑器，确认属性正确显示

---

### ✅ 修复 3: 属性持久化

**问题:** 保存后重启编辑器，属性选择丢失

**如何检测:**
在属性 setter 中检查是否有:
```gdscript
if _available_properties.is_empty():
    _update_available_properties()
```

**如何修复:**
```gdscript
func _update_property_type_info():
    # 添加这个检查
    if _available_properties.is_empty():
        _update_available_properties()

    # ... 继续原有代码
```

**验证:** 选择属性，保存，重启编辑器，确认选择正确恢复

---

### ✅ 修复 4: 缓存机制（可选）

**问题:** 属性列表被重复计算，性能问题

**何时需要:**
- `_get_available_properties()` 被频繁调用
- Inspector 刷新时出现明显延迟

**如何修复:**
```gdscript
# 添加缓存变量
var _cached_properties: Array[PropertyInfo] = []
var _cached_node: Node = null

# 在获取方法中添加缓存检查
func _get_properties():
    if _cached_node == _target_node_instance and not _cached_properties.is_empty():
        return _cached_properties
    # ... 计算并更新缓存
}

# 在 setter 中清除缓存
var target_node: NodePath = NodePath(""):
    set(value):
        target_node = value
        _cached_properties.clear()
        _cached_node = null
```

**验证:** 多次打开 Inspector，确认属性列表快速加载

---

## 完整修复示例

参见: `tween_property.gd` ✅ 已应用所有修复

## 测试清单

每个修复必须通过以下测试:

- [ ] 编辑器中可以正常选择节点
- [ ] 编辑器中可以正常选择属性
- [ ] 保存场景后重启编辑器，选择正确恢复
- [ ] 运行时功能正常
- [ ] Trigger 在子节点时，节点路径正确
- [ ] Inspector 刷新无延迟（如适用）

## 常见问题

**Q: 是否所有组件都需要缓存?**
A: 不是。只有频繁调用 `get_property_list()` 的组件才需要。

**Q: `find_node_from_resource_context()` 和 `find_node_by_relative_path()` 的区别?**
A: `find_node_from_resource_context()` 会考虑 Resource 存储位置，正确处理 `..` 路径。

**Q: 如何确认修复是否成功?**
A: 使用测试清单，重点测试场景保存/重启。

## 参考资源

- Material 属性 tweening 实现: `tween_property.gd`
- BricksNodeUtils 工具类: `bricks_node_utils.gd`
- 问题总结报告: `docs/analysis/bricks-components-needing-fixes.md`
```

**Step 2: 提交修复指南**

```bash
git add addons/bricks/docs/development/bricks-component-fix-guide.md
git commit -m "docs(guide): 创建 Bricks 组件标准修复指南

- 提供4种标准修复模式
- 包含检测、修复、验证流程
- 提供完整修复示例
- 包含测试清单
"
```

---

### Task 9: 创建审查脚本（可选）

**文件:**
- 创建: `tools/check_bricks_components.py`

**Step 1: 创建自动化审查脚本**

```python
#!/usr/bin/env python3
"""
Bricks 组件自动化审查脚本

检查所有使用 target_node 的组件是否应用了标准修复模式
"""

import os
import re
from pathlib import Path

def check_file(filepath):
    """检查单个文件"""
    issues = []

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # 检查 1: 是否使用 find_node_by_relative_path
    if 'find_node_by_relative_path' in content:
        issues.append({
            'type': '节点路径解析',
            'severity': '高',
            'message': '使用 find_node_by_relative_path 而非 find_node_from_resource_context'
        })

    # 检查 2: 是否有场景加载顺序检查
    if '_get_property_list' in content:
        if 'if Engine.is_editor_hint() and _target_node_instance == null' not in content:
            issues.append({
                'type': '场景加载顺序',
                'severity': '中',
                'message': '缺少场景加载顺序检查'
            })

    # 检查 3: 是否有缓存机制
    if '_get_available_properties' in content:
        if '_cached_properties' not in content:
            issues.append({
                'type': '缓存机制',
                'severity': '低',
                'message': '缺少属性列表缓存'
            })

    return issues

def main():
    bricks_dir = Path('addons/bricks/instructions')

    for filepath in bricks_dir.rglob('*.gd'):
        issues = check_file(filepath)
        if issues:
            print(f"\n{filepath.relative_to(bricks_dir.parent.parent.parent)}:")
            for issue in issues:
                print(f"  [{issue['severity']}] {issue['type']}: {issue['message']}")

if __name__ == '__main__':
    main()
```

**Step 2: 运行审查脚本**

```bash
python tools/check_bricks_components.py
```

**Step 3: 提交脚本**

```bash
git add tools/check_bricks_components.py
git commit -m "tools(audit): 添加 Bricks 组件自动化审查脚本"
```

---

## 总结

### 交付物

1. **审查报告:**
   - `set_property_value-audit.md`
   - `run_target_node_function-audit.md`
   - `animation-components-audit.md`
   - `audio-components-audit.md`
   - `camera-components-audit.md`

2. **修复报告:**
   - `set_property_value-fix-report.md`

3. **综合报告:**
   - `bricks-components-fix-priority.md`

4. **指南文档:**
   - `bricks-component-fix-guide.md`

5. **工具脚本:**
   - `check_bricks_components.py` (可选)

### 预计总工作量

- Task 1-2: SetPropertyValue 审查与修复 - 2.5小时
- Task 3: RunTargetNodeFunction 审查 - 1小时
- Task 4-6: 批量审查 - 4小时
- Task 7-9: 报告与指南 - 2小时
- **总计:** 约 9.5小时

### 下一步行动

1. 立即修复 SetPropertyValue (Task 2)
2. 审查 RunTargetNodeFunction (Task 3)
3. 批量审查其他组件 (Task 4-6)
4. 根据综合报告制定修复计划 (Task 7)

---

**计划完成!** 保存到: `docs/plans/2026-02-05-bricks-components-audit-and-fix.md`
