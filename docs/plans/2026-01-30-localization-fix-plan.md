# Bricks 本地化修复计划

> **生成日期**: 2026-01-30
> **检查工具**: translation_checker.gd v3.0
> **总问题数**: 167 个文件存在本地化问题

---

## 📊 问题统计

- **指令**: 77 个文件，约 150+ 问题
- **事件**: 60 个文件，约 60+ 问题
- **条件**: 32 个文件，约 96+ 问题

---

## 🔴 优先级 1: 性能问题 (4 个文件)

### 问题描述
`_get_property_list()` 中直接调用 `BricksLocalization.translate()`，应使用静态缓存

### 影响范围
每次编辑器刷新属性面板时都会重新翻译，影响性能

### 问题文件

1. `events/input/on_input_key.gd`
2. `events/input/on_mouse_button.gd`
3. `events/input/on_mouse_move.gd`

### 修复建议
参考 `events/input/on_input_action.gd` 的实现模式：
- 添加静态缓存变量
- 创建 `_init_*_cache()` 静态方法
- 在 `_get_property_list()` 中使用缓存的字符串

---

## 🟠 优先级 2: 硬编码枚举值 (6 个文件)

### 问题描述
`_get_property_list()` 的 `hint_string` 包含硬编码中文枚举值

### 问题文件

1. `instructions/flow_control/break_loop.gd`
2. `instructions/flow_control/continue_loop.gd`
3. `instructions/node_operations/find_node.gd`
4. `instructions/node_operations/run_target_node_function.gd`
5. `instructions/scene/add_scene_as_child.gd`
6. `events/node/on_target_signal_emit.gd`

### 修复建议
- 添加对应的翻译键到 `translations.csv`
- 使用静态缓存模式（同优先级1）

---

## 🟡 优先级 3: 硬编码中文字符串 (150+ 处)

### 3.1 指令文件 (77 个文件中的大部分)

#### Animation 指令
- `instructions/animation/blend_animation.gd`
- `instructions/animation/play_animation.gd`
- `instructions/animation/set_animation_speed.gd`
- `instructions/animation/stop_animation.gd`

#### Audio 指令
- `instructions/audio/pause_resume_audio.gd`
- `instructions/audio/play_music.gd`
- `instructions/audio/play_sound.gd`
- `instructions/audio/set_audio_volume.gd`
- `instructions/audio/stop_audio.gd`

#### Camera 指令
- `instructions/camera/camera_follow.gd`
- `instructions/camera/camera_shake.gd`
- `instructions/camera/set_camera_limit.gd`
- `instructions/camera/set_camera_zoom.gd`

#### Debug 指令
- `instructions/debug/print.gd`
- `instructions/debug/print_variable_value.gd`

#### Flow Control 指令
- `instructions/flow_control/break_loop.gd`
- `instructions/flow_control/continue_loop.gd`
- `instructions/flow_control/count.gd`
- `instructions/flow_control/for_each.gd`
- `instructions/flow_control/for_loop.gd`
- `instructions/flow_control/if_else.gd`
- `instructions/flow_control/pause_game.gd`
- `instructions/flow_control/resume_game.gd`
- `instructions/flow_control/run_condition_check.gd`
- `instructions/flow_control/wait.gd`
- `instructions/flow_control/wait_until.gd`
- `instructions/flow_control/while_loop.gd`

#### Math 指令
- `instructions/math/clamp_value.gd`
- `instructions/math/lerp.gd`
- `instructions/math/math_operation.gd`
- `instructions/math/random_number.gd`
- `instructions/math/vector_operation.gd`

#### Node Operations 指令
- `instructions/node_operations/enable_disable_node.gd`
- `instructions/node_operations/find_node.gd`
- `instructions/node_operations/instantiate_scene.gd`
- `instructions/node_operations/queue_free_node.gd`
- `instructions/node_operations/reparent_node.gd`
- `instructions/node_operations/run_target_node_function.gd`
- `instructions/node_operations/set_property_value.gd`

#### Physics 指令
- `instructions/physics/apply_force.gd`
- `instructions/physics/apply_impulse.gd`
- `instructions/physics/raycast.gd`
- `instructions/physics/set_collision_layer.gd`
- `instructions/physics/set_velocity.gd`

#### Scene 指令
- `instructions/scene/add_scene_as_child.gd`
- `instructions/scene/get_scene_path.gd`
- `instructions/scene/load_scene_background.gd`
- `instructions/scene/reload_scene.gd`

#### Transform 指令
- `instructions/transform/look_at.gd`
- `instructions/transform/move_by.gd`
- `instructions/transform/rotate_by.gd`
- `instructions/transform/set_position.gd`
- `instructions/transform/set_rotation.gd`
- `instructions/transform/set_scale.gd`

#### Tween 指令
- `instructions/tween/tween_bounce_animation.gd`
- `instructions/tween/tween_color_transition.gd`
- `instructions/tween/tween_fade_in.gd`
- `instructions/tween/tween_fade_out.gd`
- `instructions/tween/tween_move_to.gd`
- `instructions/tween/tween_pop_animation.gd`
- `instructions/tween/tween_property.gd`
- `instructions/tween/tween_pulse_animation.gd`
- `instructions/tween/tween_rotate_to.gd`
- `instructions/tween/tween_scale_to.gd`
- `instructions/tween/tween_shake_animation.gd`

#### UI 指令
- `instructions/ui/set_ui_progress.gd`
- `instructions/ui/set_ui_text.gd`
- `instructions/ui/set_ui_texture.gd`
- `instructions/ui/show_hide_ui.gd`

#### Variables 指令
- `instructions/variables/create_variable.gd`
- `instructions/variables/set_int_variable.gd`
- `instructions/variables/set_variable.gd`

#### 其他指令
- `instructions/scene_management/change_scene.gd`
- `instructions/system/quit.gd`
- `instructions/time/get_delta_time.gd`
- `instructions/time/set_time_scale.gd`

### 3.2 事件文件 (60 个文件中的大部分)

#### Animation 事件
- `events/animation/on_animation_blend.gd`
- `events/animation/on_animation_finished.gd`
- `events/animation/on_animation_frame_reached.gd`
- `events/animation/on_animation_loop.gd`
- `events/animation/on_animation_marker.gd`
- `events/animation/on_animation_started.gd`

#### Audio 事件
- `events/audio/on_audio_bus_volume_changed.gd`
- `events/audio/on_audio_finished.gd`
- `events/audio/on_audio_started.gd`
- `events/audio/on_music_beat.gd`

#### Gameplay 事件
- `events/gameplay/on_health_changed.gd`
- `events/gameplay/on_sound_listened.gd`

#### Input 事件
- `events/input/on_gamepad_axis.gd`
- `events/input/on_gamepad_button.gd`
- `events/input/on_input_text.gd`
- `events/input/on_touch.gd`
- `events/input/on_touch_swipe.gd`

#### Lifecycle 事件
- `events/lifecycle/on_enter_tree.gd`
- `events/lifecycle/on_exit_tree.gd`
- `events/lifecycle/on_interval.gd`
- `events/lifecycle/on_physics_process.gd`
- `events/lifecycle/on_process.gd`
- `events/lifecycle/on_ready.gd`

#### Node 事件
- `events/node/on_node_instance.gd`
- `events/node/on_property_changed.gd`
- `events/node/on_signal_from_group.gd`
- `events/node/on_target_signal_emit.gd`

#### Physics 事件
- `events/physics/on_area_2d_exited.gd`
- `events/physics/on_area_3d_entered.gd`
- `events/physics/on_area_3d_exited.gd`
- `events/physics/on_body_entered.gd`
- `events/physics/on_collision.gd`
- `events/physics/on_overlapping_bodies.gd`
- `events/physics/on_raycast_hit.gd`
- `events/physics/on_screen_entered_exited.gd`
- `events/physics/on_shape_cast.gd`

#### Scene 事件
- `events/scene/on_background_load_progress.gd`
- `events/scene/on_node_paused_resumed.gd`
- `events/scene/on_scene_about_to_change.gd`
- `events/scene/on_scene_loaded.gd`
- `events/scene/on_tree_changed.gd`

#### Timing 事件
- `events/timing/on_cooldown_finished.gd`
- `events/timing/on_countdown.gd`
- `events/timing/on_realtime.gd`
- `events/timing/on_timer.gd`

#### Tween 事件
- `events/tween/on_tween_completed.gd`

#### UI 事件
- `events/ui/on_button_pressed.gd`
- `events/ui/on_focus.gd`
- `events/ui/on_item_selected.gd`
- `events/ui/on_text_changed.gd`
- `events/ui/on_value_changed.gd`

#### Variable 事件
- `events/variable/on_variable_changed.gd`

#### 其他事件
- `events/examples/icon_test_event.gd`

### 3.3 条件文件 (所有 32 个文件)

#### Animation 条件
- `conditions/animation/check_animation_finished.gd`
- `conditions/animation/check_animation_tree_state.gd`
- `conditions/animation/check_is_animation.gd`
- `conditions/animation/check_is_playing.gd`

#### Composite 条件
- `conditions/composite/check_all.gd`
- `conditions/composite/check_any.gd`
- `conditions/composite/check_composite.gd`
- `conditions/composite/check_not.gd`

#### Distance 条件
- `conditions/distance/check_distance.gd`

#### Input 条件
- `conditions/input/check_input_held.gd`
- `conditions/input/check_input_pressed.gd`
- `conditions/input/check_input_released.gd`

#### Node 条件
- `conditions/node/check_direction.gd`
- `conditions/node/check_facing_direction.gd`
- `conditions/node/check_is_child_of.gd`
- `conditions/node/check_node_active.gd`
- `conditions/node/check_node_exists.gd`
- `conditions/node/check_node_in_group.gd`
- `conditions/node/check_node_property.gd`

#### Physics 条件
- `conditions/physics/check_in_air.gd`
- `conditions/physics/check_is_falling.gd`
- `conditions/physics/check_on_floor.gd`
- `conditions/physics/check_on_wall.gd`
- `conditions/physics/check_velocity.gd`

#### Time 条件
- `conditions/time/check_countdown_finished.gd`
- `conditions/time/check_game_time.gd`
- `conditions/time/check_time_range.gd`
- `conditions/time/check_time_reached.gd`

#### Variable 条件
- `conditions/variable/check_health_value.gd`
- `conditions/variable/check_variable.gd`
- `conditions/variable/compare_health_threshold.gd`
- `conditions/variable/compare_variable.gd`

### 修复建议
**对于 `_update_resource_name()` 和 `get_description()`**:
1. 在 `translations.csv` 中添加对应的翻译键
2. 使用 `BricksLocalization.translate_format()` 替换硬编码字符串
3. 提供参数字典进行参数化

**示例**:
```gdscript
# ❌ 修复前
resource_name = "混合动画 '%s'" % blend_path

# ✅ 修复后
resource_name = BricksLocalization.translate_format(
    "BRICKS_INSTRUCTION_BLEND_ANIMATION_NAME",
    {"path": blend_path}
)
```

---

## 🟢 优先级 4: CSV 格式问题 (1 处)

### ✅ 状态: 已验证 - 无需修复

### 问题描述
CSV 文件中存在不符合命名规范的注释行

### 问题内容（原始记录）
```
# Phase 02 - Time Events (Countdown
```

### 验证结果（2026-01-30）
**实际内容**:
```
# Phase 02 - Time Events (Countdown, Interval, Cooldown)
```

**结论**: CSV 文件格式完全正确，所有注释行格式规范。原始问题记录可能是误判或已被修复。

**验证报告**: [docs/analysis/2026-01-30-csv-format-validation-report.md](../analysis/2026-01-30-csv-format-validation-report.md)

---

## 📋 修复优先级总结

| 优先级 | 问题类型 | 文件数量 | 工作量 | 建议顺序 |
|--------|----------|----------|--------|----------|
| 🔴 P1 | 性能问题 | 4 | 小 | 1 |
| 🟠 P2 | 硬编码枚举 | 6 | 中 | 2 |
| 🟡 P3 | 硬编码字符串 | 150+ | 大 | 3 |
| 🟢 P4 | CSV 格式 | 1 | 极小 | 4 |

---

## 🔧 通用修复指南

### 添加翻译键的步骤
1. 在 `translations.csv` 中添加新行：`key,zh_CN,en_US`
2. 确保键名符合 `BRICKS_*` 格式
3. 提供完整的中英文翻译

### 本地化方法选择
- **简单文本**: `BricksLocalization.translate(key)`
- **参数化文本**: `BricksLocalization.translate_format(key, {param: value})`
- **日志**: `_log_info_localized(key, {})`
- **错误**: `_set_error_localized(key, error_type, {})`

### 静态缓存模式（枚举值）
```gdscript
static var _cached_modes: Array[String] = []
static var _modes_cached: bool = false

static func _init_modes_cache():
    if _modes_cached: return
    _cached_modes = [
        BricksLocalization.translate("BRICKS_MODE_A"),
        BricksLocalization.translate("BRICKS_MODE_B")
    ]
    _modes_cached = true

func _get_property_list():
    _init_modes_cache()
    # 使用 _cached_modes
```

---

## 📝 检查清单

修复完成后，重新运行 `translation_checker.gd` 验证：

- [ ] 所有优先级 1 问题已修复
- [ ] 所有优先级 2 问题已修复
- [ ] 所有优先级 3 问题已修复
- [x] CSV 格式问题已验证（无需修复）
- [ ] 检查工具报告 0 个问题
- [ ] 在编辑器中验证显示正常

---

**相关文档**:
- [本地化 README](../addons/bricks/localization/README.md)
- [本地化不完整脚本列表](../addons/bricks/docs/本地化不完整脚本列表.md)
