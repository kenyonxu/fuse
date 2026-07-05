# ScopeSource 支持待办事项

> 创建日期：2026-02-10
> 状态：待处理
> 总计：23 个组件需要添加 ScopeSource 支持

## 📋 需要修改的组件列表

### Conditions（3个）

#### 1. check_countdown_finished.gd
- **文件路径：** `addons/fuse/conditions/time/check_countdown_finished.gd`
- **当前作用域：** `variable_scope` (读取开始时间变量)
- **修改类型：** 单作用域读取
- **优先级：** 中

#### 2. check_health_value.gd
- **文件路径：** `addons/fuse/conditions/variable/check_health_value.gd`
- **当前作用域：** `variable_scope` (读取生命值变量)
- **修改类型：** 单作用域读取
- **优先级：** 中

#### 3. compare_health_threshold.gd
- **文件路径：** `addons/fuse/conditions/variable/compare_health_threshold.gd`
- **当前作用域：** `variable_scope` (读取生命值变量)
- **修改类型：** 单作用域读取
- **优先级：** 中

---

### Instructions（20个）

#### Debug（1个）

#### 4. print_variable_value.gd
- **文件路径：** `addons/fuse/instructions/debug/print_variable_value.gd`
- **当前作用域：** `variable_scope` (读取要打印的变量)
- **修改类型：** 单作用域读取
- **优先级：** 中

---

#### Flow Control（4个）

#### 5. wait_until.gd ⚠️ 复杂
- **文件路径：** `addons/fuse/instructions/flow_control/wait_until.gd`
- **当前作用域：**
  - `variable_a_scope` (读取变量A)
  - `variable_b_scope` (读取变量B，可选)
  - `check_variable_scope` (检查变量存在性，可选)
- **修改类型：** 三作用域读取（条件化显示）
- **优先级：** 低（复杂度较高）
- **注意事项：** 根据条件类型显示不同的变量作用域

#### 6. while_loop.gd
- **文件路径：** `addons/fuse/instructions/flow_control/while_loop.gd`
- **当前作用域：** `variable_scope` (读取条件变量)
- **修改类型：** 单作用域读取
- **优先级：** 中

#### 7. for_each.gd
- **文件路径：** `addons/fuse/instructions/flow_control/for_each.gd`
- **当前作用域：**
  - `array_scope` (读取数组变量)
  - `item_scope` (写入当前元素)
- **修改类型：** 双作用域（一读一写）
- **优先级：** 中

#### 8. for_loop.gd
- **文件路径：** `addons/fuse/instructions/flow_control/for_loop.gd`
- **当前作用域：**
  - `loop_count_scope` (读取循环次数，可选)
  - `index_scope` (写入循环索引)
- **修改类型：** 双作用域（一读一写，条件化）
- **优先级：** 中

---

#### Variables（1个）

#### 9. set_int_variable.gd
- **文件路径：** `addons/fuse/instructions/variables/set_int_variable.gd`
- **当前作用域：**
  - `scope` (写入目标变量)
  - `from_variable_scope` (读取源变量，可选)
- **修改类型：** 双作用域（一写一读，条件化）
- **优先级：** 高（常用指令）
- **参考：** 类似 `set_variable.gd` 的实现

---

#### Node Operations（4个）

#### 10. instantiate_scene.gd
- **文件路径：** `addons/fuse/instructions/node_operations/instantiate_scene.gd`
- **当前作用域：** `target_scope` (写入实例ID)
- **修改类型：** 单作用域写入
- **优先级：** 高（常用指令）

#### 11. raycast.gd
- **文件路径：** `addons/fuse/instructions/physics/raycast.gd`
- **当前作用域：** `result_scope` (写入射线检测结果)
- **修改类型：** 单作用域写入
- **优先级：** 高（常用指令）

#### 12. find_node.gd
- **文件路径：** `addons/fuse/instructions/node_operations/find_node.gd`
- **当前作用域：** `result_scope` (写入节点引用)
- **修改类型：** 单作用域写入
- **优先级：** 中

#### 13. set_property_value.gd
- **文件路径：** `addons/fuse/instructions/node_operations/set_property_value.gd`
- **当前作用域：** `variable_scope` (读取变量值作为属性值)
- **修改类型：** 单作用域读取
- **优先级：** 高（常用指令）

---

#### Scene（2个）

#### 14. load_scene_background.gd
- **文件路径：** `addons/fuse/instructions/scene/load_scene_background.gd`
- **当前作用域：** `save_to_scope` (写入加载状态)
- **修改类型：** 单作用域写入
- **优先级：** 低

#### 15. get_delta_time.gd
- **文件路径：** `addons/fuse/instructions/time/get_delta_time.gd`
- **当前作用域：** `save_to_scope` (写入时间增量)
- **修改类型：** 单作用域写入
- **优先级：** 中

---

#### Animation（1个）

#### 16. blend_animation.gd
- **文件路径：** `addons/fuse/instructions/animation/blend_animation.gd`
- **当前作用域：** `blend_scope` (读取混合变量)
- **修改类型：** 单作用域读取
- **优先级：** 中

---

#### Camera（1个）

#### 17. set_camera_zoom.gd
- **文件路径：** `addons/fuse/instructions/camera/set_camera_zoom.gd`
- **当前作用域：** `zoom_scope` (读取缩放变量)
- **修改类型：** 单作用域读取
- **优先级：** 中

---

#### UI（3个）

#### 18. set_ui_progress.gd
- **文件路径：** `addons/fuse/instructions/ui/set_ui_progress.gd`
- **当前作用域：** `value_scope` (读取进度值)
- **修改类型：** 单作用域读取
- **优先级：** 中

#### 19. set_ui_text.gd
- **文件路径：** `addons/fuse/instructions/ui/set_ui_text.gd`
- **当前作用域：** `text_scope` (读取文本内容)
- **修改类型：** 单作用域读取
- **优先级：** 中

#### 20. set_ui_texture.gd
- **文件路径：** `addons/fuse/instructions/ui/set_ui_texture.gd`
- **当前作用域：** `texture_scope` (读取纹理资源)
- **修改类型：** 单作用域读取
- **优先级：** 中

---

#### Transform（6个）

#### 21. look_at.gd
- **文件路径：** `addons/fuse/instructions/transform/look_at.gd`
- **当前作用域：** `offset_scope` (读取偏移量变量)
- **修改类型：** 单作用域读取
- **优先级：** 中

#### 22. move_by.gd
- **文件路径：** `addons/fuse/instructions/transform/move_by.gd`
- **当前作用域：** `position_scope` (读取位置变量)
- **修改类型：** 单作用域读取
- **优先级：** 中

#### 23. rotate_by.gd
- **文件路径：** `addons/fuse/instructions/transform/rotate_by.gd`
- **当前作用域：** `rotation_scope` (读取旋转变量)
- **修改类型：** 单作用域读取
- **优先级：** 中

#### 24. set_scale.gd
- **文件路径：** `addons/fuse/instructions/transform/set_scale.gd`
- **当前作用域：** `scale_scope` (读取缩放变量)
- **修改类型：** 单作用域读取
- **优先级：** 中

#### 25. set_rotation.gd
- **文件路径：** `addons/fuse/instructions/transform/set_rotation.gd`
- **当前作用域：** `rotation_scope` (读取旋转变量)
- **修改类型：** 单作用域读取
- **优先级：** 中

#### 26. set_position.gd
- **文件路径：** `addons/fuse/instructions/transform/set_position.gd`
- **当前作用域：** `position_scope` (读取位置变量)
- **修改类型：** 单作用域读取
- **优先级：** 中

---

## 📝 修改指南

### 标准单作用域修改（最常见）

对于大多数组件，按照以下模式修改：

```gdscript
## 添加 ScopeSource 枚举
enum ScopeSource {
    NEAREST,        # 最近的作用域容器（默认）
    CUSTOM_ID,      # 指定 scope_id
    TRIGGER_SCOPE,  # Trigger 节点上的作用域
    TARGET_NODE     # Target 节点上的作用域
}

## 替换原有的 variable_scope 为 scope_source
var scope_source: ScopeSource = ScopeSource.NEAREST:
    set(value):
        scope_source = value
        _update_resource_name()
        notify_property_list_changed()

## 添加额外的属性
var custom_scope_id: String = "":
    set(value):
        custom_scope_id = value
        _update_resource_name()

var target_node_path: NodePath = NodePath(""):
    set(value):
        target_node_path = value
        _update_resource_name()

## 在 _get_property_list() 中添加属性配置
properties.append({
    name = "Scope Source",
    type = TYPE_INT,
    hint = PROPERTY_HINT_ENUM,
    hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
    usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
})

## 根据条件添加额外属性
if scope_source == ScopeSource.CUSTOM_ID:
    properties.append({...})
elif scope_source == ScopeSource.TARGET_NODE:
    properties.append({...})

## 在 execute() 中使用 VariableScopeUtils
if scope_source == ScopeSource.NEAREST:
    value = VariableOperations.get_variable(context, variable_name, BaseVariable.VariableScope.SCOPE, null)
else:
    var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
    var scope_container = VariableScopeUtils.get_scope_container_by_source(
        context, utils_scope_source, custom_scope_id, target_node_path
    )
    if scope_container != null:
        value = scope_container.get_variable(variable_name)
```

### 双作用域修改

对于需要读取和写入两个作用域的组件（如 `set_int_variable.gd`），参考 `set_variable.gd` 的实现。

### 参考示例

- **单作用域读取：** `clamp_value.gd`
- **单作用域写入：** `random_number.gd`
- **双作用域：** `set_variable.gd`
- **条件化作用域：** `create_variable.gd`

---

## ✅ 已完成修改的组件（15个）

### Math指令（5个）
- ✅ random_number.gd
- ✅ clamp_value.gd
- ✅ math_operation.gd
- ✅ lerp.gd
- ✅ vector_operation.gd

### Variables指令（3个）
- ✅ create_variable.gd
- ✅ set_variable.gd
- ✅ get_scene_path.gd

### Conditions（4个）
- ✅ compare_variable.gd
- ✅ check_vector2_variable_axis.gd
- ✅ check_variable.gd
- ✅ check_scope_variable.gd

### 其他指令（1个）
- ✅ get_scope_variable.gd

---

## 🔍 审计方法

使用以下命令查找所有使用 VariableOperations 的组件：

```bash
# 查找所有使用 get_variable 的文件
grep -r "VariableOperations.get_variable" addons/fuse/instructions addons/fuse/conditions

# 查找所有使用 set_variable 的文件
grep -r "VariableOperations.set_variable" addons/fuse/instructions

# 查找所有使用 variable_scope 的文件
grep -r "variable_scope:" addons/fuse/instructions addons/fuse/conditions
```

---

## 📌 注意事项

1. **类型转换：** 每个组件定义本地 ScopeSource 枚举，需要使用 `as VariableScopeUtils.ScopeSource` 转换
2. **属性验证：** 使用 `VariableScopeUtils.validate_scope_source_property()` 控制 UI 可见性
3. **参数验证：** 使用 `VariableScopeUtils.validate_scope_source_params()` 验证参数
4. **NEAREST 模式：** 使用 `VariableOperations.get_variable/set_variable` 的 SCOPE 模式
5. **其他模式：** 使用 `VariableScopeUtils.get_scope_container_by_source()` 获取容器

---

## 🎯 优先级说明

- **高：** 常用指令，影响用户体验
- **中：** 一般使用频率
- **低：** 使用较少或复杂度较高

建议按优先级顺序处理，先完成高优先级的组件。
