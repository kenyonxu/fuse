# Bricks 系统组件修复分析报告

**生成日期:** 2026-02-05
**基于问题:** Material 属性 tweening 实现中遇到的5个关键问题

## 问题回顾

在实现 Material 属性 tweening 功能时，我们遇到了以下问题：

1. **线程安全问题** - `get_material()` 等方法在编辑器模式下有线程检查
2. **节点路径解析问题** - Trigger 存储在子节点时，相对路径 `..` 需要特殊处理
3. **属性持久化问题（场景加载顺序）** - 场景加载时 `edited_root` 为 null
4. **属性持久化问题（保存与恢复）** - 保存后重启，属性选择丢失
5. **性能问题** - `_get_material_properties()` 被重复调用 20+ 次

## 需要修复的组件分析

### 🔴 高优先级 - 已确认需要修复

#### 1. **SetPropertyValue** (`set_property_value.gd`)

**当前状态:**
- ✅ 使用了 `BricksNodeUtils.find_node_by_relative_path()`
- ❌ 但**没有**使用 `find_node_from_resource_context()`
- ❌ 没有场景加载顺序修复
- ❌ 没有属性持久化修复

**需要的修复:**
```gdscript
# 第89行，需要改为：
_target_node_instance = BricksNodeUtils.find_node_from_resource_context(
    edited_root, self, target_node
)
```

**风险:** 当 Trigger 存储在子节点时，使用 `..` 路径会获取错误的节点

---

#### 2. **TweenProperty** (`tween_property.gd`) - ✅ 已修复

**已完成的修复:**
- ✅ 使用 `BricksNodeUtils.find_node_from_resource_context()`
- ✅ 添加了场景加载顺序修复
- ✅ 添加了属性持久化修复
- ✅ 添加了缓存机制

---

### 🟡 中优先级 - 需要检查

#### 3. **RunTargetNodeFunction** (`run_target_node_function.gd`)

**当前状态:**
- ✅ 有自己的节点获取逻辑 `_get_target_node_in_editor()`
- ⚠️ 自定义实现，可能有类似问题
- ⚠️ 有缓存机制，但可能不够健壮

**需要检查的点:**
```gdscript
# 第931-961行的自定义节点获取逻辑
# 需要确认是否正确处理了 Trigger 子节点的情况
func _get_target_node_in_editor() -> Node:
    # 当前实现只处理了 "../" 前缀的情况
    # 但没有考虑资源上下文
```

**建议:** 考虑统一使用 `BricksNodeUtils.find_node_from_resource_context()`

---

#### 4. **其他使用 `target_node` 的指令**

这些指令可能没有在编辑器模式下获取节点实例，所以可能不受影响，但需要确认：

**Animation 相关:**
- `play_animation.gd` - 可能有动画属性枚举
- `set_animation_speed.gd`
- `stop_animation.gd`
- `blend_animation.gd`

**Audio 相关:**
- `play_music.gd` - 可能有音频属性枚举
- `play_sound.gd`
- `set_audio_volume.gd`
- `pause_resume_audio.gd`
- `stop_audio.gd`

**Camera 相关:**
- `camera_follow.gd` - 可能有相机属性枚举
- `camera_shake.gd`
- `set_camera_limit.gd`
- `set_camera_zoom.gd`

**Transform 相关:**
- `set_position.gd`
- `rotate_by.gd`
- `move_by.gd`
- `look_at.gd`

**Physics 相关:**
- `set_velocity.gd`
- `apply_force.gd`
- `apply_impulse.gd`
- `set_collision_layer.gd`

**Node Operations:**
- `enable_disable_node.gd`
- `queue_free_node.gd`
- `reparent_node.gd`

---

### 🟢 低优先级 - 可能不需要修复

#### 5. **其他指令**

大部分指令没有使用动态属性列表或编辑器模式下的节点获取，因此可能不需要修复。

---

## 修复优先级建议

### 🔥 立即修复（高影响）

1. **SetPropertyValue** (`set_property_value.gd`)
   - **影响:** 设置节点属性的核心功能
   - **风险:** 当 Trigger 在子节点时，会获取错误的节点
   - **修复工作量:** 小（只需要改一个方法调用）

### ⚠️ 近期检查（中影响）

2. **RunTargetNodeFunction** (`run_target_node_function.gd`)
   - **影响:** 调用节点方法的核心功能
   - **风险:** 自定义实现可能有边缘情况
   - **修复工作量:** 中（需要重构节点获取逻辑）

3. **动画/音频相关指令**
   - **影响:** 如果有属性枚举，可能有相同问题
   - **风险:** 需要逐个检查
   - **修复工作量:** 中等

### 📝 后续优化（低影响）

4. **其他使用 target_node 的指令**
   - **影响:** 可能不受影响（没有动态属性枚举）
   - **风险:** 低
   - **修复工作量:** 需要先检查

---

## 修复模式总结

基于 Material 属性 tweening 的经验，以下修复应该标准化：

### 标准修复模式 1: 节点路径解析

```gdscript
## ❌ 旧代码
_target_node_instance = BricksNodeUtils.find_node_by_relative_path(
    edited_root, target_node
)

## ✅ 新代码
_target_node_instance = BricksNodeUtils.find_node_from_resource_context(
    edited_root, self, target_node  # 注意：传入 self 作为资源
)
```

### 标准修复模式 2: 场景加载顺序

```gdscript
func _get_property_list() -> Array[Dictionary]:
    # 在编辑器中，如果节点实例为 null，尝试重新获取
    if Engine.is_editor_hint() and _target_node_instance == null and not target_node.is_empty():
        _update_target_node_info()

    # ... 其余代码
```

### 标准修复模式 3: 属性持久化

```gdscript
func _update_property_type_info():
    # 如果属性列表为空，先构建属性列表
    if _available_properties.is_empty():
        _update_available_properties()

    # ... 继续处理
```

### 标准修复模式 4: 缓存机制

```gdscript
var _cached_properties: Array[PropertyInfo] = []
var _cached_node: Node = null

func _get_properties():
    # 检查缓存
    if _cached_node == _target_node_instance and not _cached_properties.is_empty():
        return _cached_properties

    # 计算属性
    var properties = _compute_properties()

    # 更新缓存
    _cached_properties = properties
    _cached_node = _target_node_instance
    return properties

var target_node: NodePath = NodePath(""):
    set(value):
        target_node = value
        _cached_properties.clear()
        _cached_node = null
        # ... 其余代码
```

---

## 检查清单

对于每个需要检查的指令，确认以下各项：

- [ ] 是否使用了 `BricksNodeUtils.find_node_by_relative_path()`？如果是，需要改为 `find_node_from_resource_context()`
- [ ] 是否有自定义节点获取逻辑？如果有，需要考虑是否统一使用 `BricksNodeUtils`
- [ ] 是否在 `_get_property_list()` 中添加了场景加载顺序检查？
- [ ] 是否在属性 setter 中添加了属性列表为空时的检查？
- [ ] 是否实现了缓存机制来避免重复计算？
- [ ] 是否避免了使用线程不安全的方法（如 `get_material()`）？

---

## 建议的修复顺序

1. **SetPropertyValue** - 高优先级，影响核心功能
2. **RunTargetNodeFunction** - 检查并重构
3. **动画指令** - 逐个检查
4. **音频指令** - 逐个检查
5. **其他指令** - 根据需要

---

## 相关文件

- 需要修复的核心文件：
  - `addons/bricks/instructions/node_operations/set_property_value.gd`
  - `addons/bricks/instructions/node_operations/run_target_node_function.gd`

- 工具类：
  - `addons/bricks/utils/bricks_node_utils.gd`

- 参考实现：
  - `addons/bricks/instructions/tween/tween_property.gd` ✅ 已修复完成

---

**最后更新:** 2026-02-05
**分析基于:** Material 属性 tweening 实现经验
