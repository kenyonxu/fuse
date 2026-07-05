# 实施计划：NodePath 在 resource_name 中显示节点名而非相对路径

## 需求重述

Bricks 插件中有大量 Event/Condition/Instruction 组件使用 `target_node`（NodePath 类型）参数。当前在 `_update_resource_name()` / `get_description()` 中统一使用 `str(target_node)` 来显示目标节点信息，这会导致：

- 父节点显示为 `".."` 或 `"../.."`
- 当前节点显示为 `"."`
- 深层嵌套路径显示为 `"../../ChildNode"` 等不友好的形式

**目标**：在所有 `_update_resource_name()` 和 `get_description()` 中，将 `str(target_node)` 替换为可读的节点名称（即路径的最后一部分，如 `NodePath` 的 `get_file()` 或 `get_name()`），使 resource_name 始终显示具体的节点名。

## 问题分析

### 核心问题

NodePath 存储的是**相对路径**（如 `..`, `../SiblingNode`, `./ChildNode`），但 `str()` 转换会直接显示路径字符串，而非节点名称。

### 当前模式

```gdscript
# 当前做法（大多数组件）
var node_str = str(target_node) if not target_node.is_empty() else "..."

# 已有正确做法（少数组件，如 play_juicy_mixer_feedback.gd）
parts.append("→ %s" % str(target_node).get_file())
```

### 影响范围

搜索结果显示 `str(target_node)` 或 `str(target_node_path)` 在 **60+ 个源文件** 中被使用，分为两类：

1. **resource_name / description 用途**（需要修改）：在 `_update_resource_name()` 和 `get_description()` 中用于显示
2. **错误日志 / 调试信息用途**（不需要修改）：在 `_log_error` 和 `_log_debug` 中用于排查问题

## 方案设计

### 方案：在 BricksNodeUtils 中添加静态工具方法

添加一个统一的静态方法来提取 NodePath 的可读名称，供所有组件在 `_update_resource_name()` 中使用：

```gdscript
## 从 NodePath 中提取可读的节点显示名称
##
## 将相对路径（如 "..", "../NodeName"）转换为节点名称（如 "ParentNode", "NodeName"）
## 用于 resource_name 等需要用户可读显示的场景
static func get_node_display_name(path: NodePath) -> String:
    if path.is_empty():
        return ""
    var path_str = str(path)
    # 获取路径最后一部分
    var name = path_str.get_file()
    if name.is_empty() or name == "..":
        # 如果是 "." 或 ".." 之类的纯相对引用，无法提取名称
        # 返回原始路径作为 fallback
        return path_str
    return name
```

**但是**，对于 `..` 这种纯相对引用，即使使用 `get_file()` 也无法获取到真实节点名（因为路径本身就不包含）。要解决这个问题，需要**在编辑器中通过 `BricksNodeUtils` 解析相对路径找到实际节点，然后获取其 `name`**。

### 最终方案：双层策略

1. **简单提取**（无需节点上下文）：对大多数情况使用 `NodePath.get_file()` 提取路径末尾的名称
2. **编辑器解析**（需要节点上下文）：对 `..` / `.` 等纯相对引用，在编辑器模式下通过已有的 `BricksNodeUtils.find_node_from_resource_context()` 解析真实节点名

由于 `_update_resource_name()` 是在 Resource 中调用的，而 Resource 可能无法直接访问场景树，我们采用以下策略：

**提供两个级别的方法：**
- `BricksNodeUtils.get_node_display_name(path)` — 纯路径级别，使用 `get_file()` 提取
- `BricksNodeUtils.resolve_node_display_name(root, resource, path)` — 场景级别，通过上下文解析（编辑器专用）

## 实施阶段

### Phase 1：添加工具方法（1 个文件）

**文件**：`addons/bricks/utils/bricks_node_utils.gd`

添加：
```gdscript
## 从 NodePath 提取可读的节点显示名称（无需场景上下文）
## 提取路径最后一段作为节点名，对 ".." 等纯相对引用返回原始路径
static func get_node_display_name(path: NodePath) -> String:
    if path.is_empty():
        return ""
    var name = str(path).get_file()
    if name.is_empty():
        return str(path)
    return name
```

### Phase 2：修改 resource_name / description 中的引用（60+ 个文件）

**修改模式**：

对于 `_update_resource_name()` 和 `get_description()` 方法中的 NodePath 显示：

```gdscript
# 修改前
var node_str = str(target_node) if not target_node.is_empty() else "..."
var target_desc = str(target_node) if not target_node.is_empty() else "(未选择)"

# 修改后
var node_str = BricksNodeUtils.get_node_display_name(target_node) if not target_node.is_empty() else "..."
var target_desc = BricksNodeUtils.get_node_display_name(target_node) if not target_node.is_empty() else "(未选择)"
```

**不修改的场景**：
- `_log_error()` / `_log_warning()` / `_log_debug()` 中的路径信息（用于调试）
- `_create_bricks_error_localized()` 中的错误信息
- `set_error()` 中的错误信息
- `get_debug_info()` 中的调试信息

### Phase 3：处理 `..` 的特殊情况（可选增强）

对于 `target_node = ".."` 的情况，`get_file()` 返回空字符串。可以考虑：

**方案 A**（推荐）：在 `BricksNodeUtils.get_node_display_name()` 中，检测到 `..` 返回 `str(path)` 本身，同时在文档中说明这是已知限制
**方案 B**：在编辑器插件中通过场景树解析实际节点名 — 更复杂但更完善

## 需要修改的文件清单

### Instructions（指令）

| 文件 | 修改点 |
|------|--------|
| `instructions/ui/show_hide_ui.gd` | `_update_resource_name()` |
| `instructions/ui/set_ui_text.gd` | `_update_resource_name()` |
| `instructions/ui/set_ui_texture.gd` | `_update_resource_name()` |
| `instructions/ui/set_ui_progress.gd` | `_update_resource_name()` |
| `instructions/animation/play_animation.gd` | `_update_resource_name()` |
| `instructions/animation/set_animation_speed.gd` | `_update_resource_name()` |
| `instructions/animation/stop_animation.gd` | `_update_resource_name()` |
| `instructions/animation/blend_animation.gd` | `_update_resource_name()` |
| `instructions/camera/camera_shake.gd` | `_update_resource_name()` |
| `instructions/camera/camera_follow.gd` | `_update_resource_name()` |
| `instructions/camera/set_camera_zoom.gd` | `_update_resource_name()` |
| `instructions/camera/set_camera_limit.gd` | `_update_resource_name()` |
| `instructions/transform/set_position.gd` | `get_description()` |
| `instructions/transform/set_rotation.gd` | `get_description()` |
| `instructions/transform/set_scale.gd` | `get_description()` |
| `instructions/transform/look_at.gd` | `get_description()` |
| `instructions/transform/move_by.gd` | `get_description()` |
| `instructions/transform/rotate_by.gd` | `get_description()` |
| `instructions/physics/set_velocity.gd` | `_update_resource_name()` |
| `instructions/physics/set_collision_layer.gd` | `_update_resource_name()` |
| `instructions/physics/apply_force.gd` | `get_description()` |
| `instructions/physics/apply_impulse.gd` | `get_description()` |
| `instructions/tween/tween_property.gd` | `_update_resource_name()` |
| `instructions/tween/tween_move_to.gd` | `_update_resource_name()` |
| `instructions/tween/tween_scale_to.gd` | `_update_resource_name()` |
| `instructions/tween/tween_rotate_to.gd` | `_update_resource_name()` |
| `instructions/tween/tween_fade_in.gd` | `_update_resource_name()` |
| `instructions/tween/tween_fade_out.gd` | `_update_resource_name()` |
| `instructions/tween/tween_shake_animation.gd` | `_update_resource_name()` |
| `instructions/tween/tween_pulse_animation.gd` | `_update_resource_name()` |
| `instructions/tween/tween_pop_animation.gd` | `_update_resource_name()` |
| `instructions/tween/tween_bounce_animation.gd` | `_update_resource_name()` |
| `instructions/tween/tween_color_transition.gd` | `_update_resource_name()` |
| `instructions/node_operations/run_target_node_function.gd` | `_update_resource_name()` |
| `instructions/node_operations/set_property_value.gd` | `_update_resource_name()` |
| `instructions/node_operations/enable_disable_node.gd` | `_update_resource_name()` |
| `instructions/node_operations/reparent_node.gd` | `_update_resource_name()` |
| `instructions/node_operations/queue_free_node.gd` | `_update_resource_name()` |
| `instructions/node_operations/recycle_pooled_scene.gd` | `_update_resource_name()` |
| `instructions/node_operations/get_random_child.gd` | `_update_resource_name()` |
| `instructions/node_operations/get_last_child.gd` | `_update_resource_name()` |
| `instructions/node_operations/get_child_count.gd` | `_update_resource_name()` |
| `instructions/node_operations/get_child_by_index.gd` | `_update_resource_name()` |
| `instructions/node_operations/get_all_children.gd` | `_update_resource_name()` |
| `instructions/node_operations/get_all_children_position.gd` | `_update_resource_name()` |
| `instructions/flow_control/wait_until.gd` | `_update_resource_name()` |
| `instructions/flow_control/run_runner.gd` | `_update_resource_name()` |
| `instructions/integration/juicy_mixer/play_juicy_mixer_feedback.gd` | 已使用 `.get_file()` |
| `instructions/movement/move_character_body_2d_composite.gd` | 已使用 `.get_file()` |

### Conditions（条件）

| 文件 | 修改点 |
|------|--------|
| `conditions/distance/check_distance.gd` | `_get_target_node_source_string()` |
| `conditions/animation/check_is_playing.gd` | `_update_resource_name()` |
| `conditions/animation/check_is_animation.gd` | `_update_resource_name()` |
| `conditions/animation/check_animation_tree_state.gd` | `_update_resource_name()` |
| `conditions/animation/check_animation_finished.gd` | `_update_resource_name()` |
| `conditions/physics/check_velocity.gd` | `_update_resource_name()` |
| `conditions/physics/check_is_falling.gd` | `_update_resource_name()` |
| `conditions/physics/check_on_wall.gd` | `_update_resource_name()` |
| `conditions/physics/check_in_air.gd` | `_update_resource_name()` |
| `conditions/physics/check_on_floor.gd` | `_update_resource_name()` |
| `conditions/node/check_node_in_group.gd` | `_update_resource_name()` |
| `conditions/node/check_node_property.gd` | `_update_resource_name()` |
| `conditions/node/check_child_count.gd` | `_update_resource_name()` |
| `conditions/node/check_facing_direction.gd` | `_update_resource_name()` |
| `conditions/node/check_direction.gd` | `_update_resource_name()` |
| `conditions/variable/compare_variable.gd` | `_get_scope_source_string()` |
| `conditions/arrays/check_array_contains.gd` | `_update_resource_name()` |
| `conditions/arrays/check_array_size.gd` | `_update_resource_name()` |

### Events（事件）

| 文件 | 修改点 |
|------|--------|
| `events/scene/on_node_paused_resumed.gd` | `get_description()` |
| `events/node/on_property_changed.gd` | `get_description()` |
| `events/physics/on_collision.gd` | `_update_resource_name()` |
| `events/physics/on_screen_entered_exited.gd` | `_update_resource_name()` |
| `events/ui/on_mouse_enter.gd` | `_update_resource_name()` |
| `events/ui/on_mouse_exit.gd` | `_update_resource_name()` |
| `events/ui/on_focus.gd` | `_update_resource_name()` |
| `events/ui/on_value_changed.gd` | `_update_resource_name()` |
| `events/ui/on_text_changed.gd` | `_update_resource_name()` |
| `events/ui/on_item_selected.gd` | `_update_resource_name()` |
| `events/animation/on_animation_marker.gd` | `_update_resource_name()` |
| `events/animation/on_animation_started.gd` | `_update_resource_name()` |
| `events/animation/on_animation_loop.gd` | `_update_resource_name()` |
| `events/animation/on_animation_finished.gd` | 可能 `_update_resource_name()` |
| `events/input/on_mouse_move.gd` | 可能 `_update_resource_name()` |
| `events/gameplay/on_health_changed.gd` | `_update_resource_name()` |
| `events/node/on_target_signal_emit.gd` | `_update_resource_name()` |

### 工具类

| 文件 | 修改点 |
|------|--------|
| `core/utils/variable_scope_utils.gd` | `get_scope_source_string()` |

### 编辑器代码生成

| 文件 | 修改点 |
|------|--------|
| `editor/instruction_generator/instruction_generator.gd` | 生成的模板代码 |
| `editor/instruction_generator/property_instruction_generator.gd` | 生成的模板代码 |

## 风险评估

| 风险 | 级别 | 说明 |
|------|------|------|
| 修改文件数量多 | **中** | 模式统一，批量修改风险可控 |
| `..` 路径无法解析 | **低** | 对 `..` 返回原路径字符串，不影响功能 |
| 运行时错误日志不修改 | **无** | 明确区分 resource_name 和日志信息 |
| 编辑器代码生成模板 | **低** | 需同步更新，确保新组件也使用新方法 |

## 复杂度评估

- **Phase 1**（工具方法）：**低**
- **Phase 2**（批量修改）：**中**（文件多但模式统一）
- **Phase 3**（可选增强）：**中**

## 建议

推荐采用**分批修改**策略：
1. 先完成 Phase 1，添加工具方法
2. 按类别分批修改（先 Instructions，再 Conditions，最后 Events）
3. 每批修改后在 Godot 编辑器中验证 resource_name 显示效果
