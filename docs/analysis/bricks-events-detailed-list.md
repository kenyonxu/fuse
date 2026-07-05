# Bricks 事件组件详细清单

**生成日期**: 2026-02-05
**总组件数**: 59
**需要修复**: 33 (55.9%)
**无需修复**: 26 (44.1%)

---

## 📁 按分类统计

### Animation Events (6 个)
| 文件名 | 状态 | 问题 | 优先级 |
|--------|------|------|--------|
| animation/on_animation_blend.gd | 🔧 需修复 | 节点路径解析 | 高 |
| animation/on_animation_finished.gd | 🔧 需修复 | 节点路径解析 | 高 |
| animation/on_animation_frame_reached.gd | 🔧 需修复 | 节点路径解析 | 高 |
| animation/on_animation_loop.gd | 🔧 需修复 | 节点路径解析 | 高 |
| animation/on_animation_marker.gd | 🔧 需修复 | 节点路径解析 | 高 |
| animation/on_animation_started.gd | 🔧 需修复 | 节点路径解析 | 高 |

### Audio Events (4 个)
| 文件名 | 状态 | 问题 | 优先级 |
|--------|------|------|--------|
| audio/on_audio_bus_volume_changed.gd | ✅ 正常 | 无问题 | - |
| audio/on_audio_finished.gd | 🔧 需修复 | 节点路径解析 | 中 |
| audio/on_audio_started.gd | 🔧 需修复 | 节点路径解析 | 中 |
| audio/on_music_beat.gd | ✅ 正常 | 无问题 | - |

### Gameplay Events (2 个)
| 文件名 | 状态 | 问题 | 优先级 |
|--------|------|------|--------|
| gameplay/on_health_changed.gd | ✅ 正常 | 使用节点组 | - |
| gameplay/on_sound_listened.gd | ✅ 正常 | 使用节点组 | - |

### Input Events (12 个)
| 文件名 | 状态 | 问题 | 优先级 |
|--------|------|------|--------|
| input/on_gamepad_axis.gd | ✅ 正常 | Input系统事件 | - |
| input/on_gamepad_button.gd | ✅ 正常 | Input系统事件 | - |
| input/on_input_action.gd | ✅ 正常 | 使用 InputMap | - |
| input/on_input_key.gd | ✅ 正常 | Input系统事件 | - |
| input/on_input_text.gd | ✅ 正常 | Input系统事件 | - |
| input/on_mouse_button.gd | 🔧 需修复 | 节点路径解析 | 中 |
| input/on_mouse_enter.gd | 🔧 需修复 | 节点路径解析 | 中 |
| input/on_mouse_exit.gd | 🔧 需修复 | 节点路径解析 | 中 |
| input/on_mouse_move.gd | 🔧 需修复 | 节点路径解析 | 中 |
| input/on_touch.gd | ✅ 正常 | Input系统事件 | - |
| input/on_touch_swipe.gd | ✅ 正常 | Input系统事件 | - |

### Lifecycle Events (6 个)
| 文件名 | 状态 | 问题 | 优先级 |
|--------|------|------|--------|
| lifecycle/on_enter_tree.gd | ✅ 正常 | 无节点路径 | - |
| lifecycle/on_exit_tree.gd | ✅ 正常 | 无节点路径 | - |
| lifecycle/on_interval.gd | ✅ 正常 | 无节点路径 | - |
| lifecycle/on_physics_process.gd | ✅ 正常 | 无节点路径 | - |
| lifecycle/on_process.gd | ✅ 正常 | 无节点路径 | - |
| lifecycle/on_ready.gd | ✅ 正常 | 无节点路径 | - |

### Node Events (4 个)
| 文件名 | 状态 | 问题 | 优先级 |
|--------|------|------|--------|
| node/on_node_instance.gd | 🔧 需修复 | 节点路径解析 | 中 |
| node/on_property_changed.gd | 🔧 需修复 | 节点路径解析 | 中 |
| node/on_signal_from_group.gd | 🔧 需修复 | 节点路径解析 | 中 |
| node/on_target_signal_emit.gd | ⭐ 优秀 | 正确使用BricksNodeUtils | - |

### Physics Events (11 个)
| 文件名 | 状态 | 问题 | 优先级 |
|--------|------|------|--------|
| physics/on_area_2d_enter.gd | 🔧 需修复 | 节点路径解析 | 高 |
| physics/on_area_2d_exited.gd | 🔧 需修复 | 节点路径解析 | 高 |
| physics/on_area_3d_entered.gd | 🔧 需修复 | 节点路径解析 | 高 |
| physics/on_area_3d_exited.gd | 🔧 需修复 | 节点路径解析 | 高 |
| physics/on_body_entered.gd | 🔧 需修复 | 节点路径解析 | 高 |
| physics/on_collision.gd | 🔧 需修复 | 节点路径解析 | 高 |
| physics/on_overlapping_bodies.gd | ✅ 正常 | 使用节点组 | - |
| physics/on_raycast_hit.gd | ✅ 正常 | 使用 RayCast | - |
| physics/on_screen_entered_exited.gd | ✅ 正常 | 使用 RectangleShape2D | - |
| physics/on_shape_cast.gd | ✅ 正常 | 使用 ShapeCast | - |

### Scene Events (5 个)
| 文件名 | 状态 | 问题 | 优先级 |
|--------|------|------|--------|
| scene/on_background_load_progress.gd | ✅ 正常 | 使用 ResourceLoader | - |
| scene/on_node_paused_resumed.gd | ✅ 正常 | 使用节点组 | - |
| scene/on_scene_about_to_change.gd | ✅ 正常 | 全局信号 | - |
| scene/on_scene_loaded.gd | ✅ 正常 | 全局信号 | - |
| scene/on_tree_changed.gd | ✅ 正常 | 全局信号 | - |

### Timing Events (4 个)
| 文件名 | 状态 | 问题 | 优先级 |
|--------|------|------|--------|
| timing/on_cooldown_finished.gd | ✅ 正常 | 纯计时逻辑 | - |
| timing/on_countdown.gd | ✅ 正常 | 纯计时逻辑 | - |
| timing/on_realtime.gd | ✅ 正常 | 纯计时逻辑 | - |
| timing/on_timer.gd | ✅ 优秀 | RuntimeInstance实现完整 | - |

### Tween Events (1 个)
| 文件名 | 状态 | 问题 | 优先级 |
|--------|------|------|--------|
| tween/on_tween_completed.gd | ✅ 正常 | 信号连接 | - |

### UI Events (5 个)
| 文件名 | 状态 | 问题 | 优先级 |
|--------|------|------|--------|
| ui/on_button_pressed.gd | 🔧 需修复 | 节点路径解析 | 中 |
| ui/on_focus.gd | 🔧 需修复 | 节点路径解析 | 中 |
| ui/on_item_selected.gd | 🔧 需修复 | 节点路径解析 | 中 |
| ui/on_text_changed.gd | 🔧 需修复 | 节点路径解析 | 中 |
| ui/on_value_changed.gd | 🔧 需修复 | 节点路径解析 | 中 |

### Variable Events (1 个)
| 文件名 | 状态 | 问题 | 优先级 |
|--------|------|------|--------|
| variable/on_variable_changed.gd | ✅ 正常 | 变量系统 | - |

---

## 🔧 需要修复的组件详细列表

### 高优先级 (12 个) - 必须修复

#### 1. animation/on_animation_blend.gd
```gdscript
# 当前代码 (第 XX 行)
_anim_player_ref = owner_node.get_node_or_null(animation_player)

# 需要改为
_anim_player_ref = BricksNodeUtils.find_node_at_runtime(_trigger_ref, animation_player)
```
- **文件路径**: `addons/bricks/events/animation/on_animation_blend.gd`
- **影响**: 无法正确解析相对路径
- **测试场景**: 嵌套 Trigger 中使用

#### 2. animation/on_animation_finished.gd
- **文件路径**: `addons/bricks/events/animation/on_animation_finished.gd`
- **修复位置**: 第 62, 101 行
- **影响**: 同上

#### 3-6. 其他 Animation Events
- on_animation_frame_reached.gd
- on_animation_loop.gd
- on_animation_marker.gd
- on_animation_started.gd
- **相同修复模式**

#### 7-12. Physics Events
- on_area_2d_enter.gd
- on_area_2d_exited.gd
- on_area_3d_entered.gd
- on_area_3d_exited.gd
- on_body_entered.gd
- on_collision.gd
- **修复模式**: `owner_node.get_node_or_null(area_node)` → `BricksNodeUtils.find_node_at_runtime(_trigger_ref, area_node)`

---

### 中优先级 (15 个) - 推荐修复

#### 13-15. Audio Events
- audio/on_audio_finished.gd
- audio/on_audio_started.gd
- **修复模式**: `owner_node.get_node_or_null(audio_player)` → `BricksNodeUtils.find_node_at_runtime(_trigger_ref, audio_player)`

#### 16-20. UI Events
- ui/on_button_pressed.gd
- ui/on_focus.gd
- ui/on_item_selected.gd
- ui/on_text_changed.gd
- ui/on_value_changed.gd
- **修复模式**: `owner_node.get_node_or_null(target_*)` → `BricksNodeUtils.find_node_at_runtime(_trigger_ref, target_*)`

#### 21-24. Input Events (鼠标相关)
- input/on_mouse_button.gd
- input/on_mouse_enter.gd
- input/on_mouse_exit.gd
- input/on_mouse_move.gd
- **修复模式**: `_owner_node.get_node_or_null(target_*)` → `BricksNodeUtils.find_node_at_runtime(_trigger_ref, target_*)`

#### 25-27. Node Events (部分)
- node/on_node_instance.gd
- node/on_property_changed.gd
- node/on_signal_from_group.gd
- **修复模式**: `owner_node.get_node_or_null(target_node)` → `BricksNodeUtils.find_node_at_runtime(_trigger_ref, target_node)`

---

## ✅ 无需修复的组件详细列表

### Lifecycle Events (6 个)
这些组件不需要节点路径，它们直接监听 owner_node 的生命周期事件。

### Timing Events (4 个)
纯计时逻辑，不涉及节点路径解析。

### Scene Events (5 个)
使用全局信号或 ResourceLoader，不涉及节点路径。

### Input Events (8 个)
使用 Input 系统内置的事件处理机制。

### Variable Events (1 个)
使用 Bricks 变量系统。

### Gameplay/Physics (部分)
使用节点组或特殊的检测节点（RayCast, ShapeCast）。

---

## 📊 修复进度跟踪

### Phase 1: 高优先级修复
- [ ] animation/on_animation_blend.gd
- [ ] animation/on_animation_finished.gd
- [ ] animation/on_animation_frame_reached.gd
- [ ] animation/on_animation_loop.gd
- [ ] animation/on_animation_marker.gd
- [ ] animation/on_animation_started.gd
- [ ] physics/on_area_2d_enter.gd
- [ ] physics/on_area_2d_exited.gd
- [ ] physics/on_area_3d_entered.gd
- [ ] physics/on_area_3d_exited.gd
- [ ] physics/on_body_entered.gd
- [ ] physics/on_collision.gd

**进度**: 0/12 (0%)

### Phase 2: 中优先级修复
- [ ] audio/on_audio_finished.gd
- [ ] audio/on_audio_started.gd
- [ ] ui/on_button_pressed.gd
- [ ] ui/on_focus.gd
- [ ] ui/on_item_selected.gd
- [ ] ui/on_text_changed.gd
- [ ] ui/on_value_changed.gd
- [ ] input/on_mouse_button.gd
- [ ] input/on_mouse_enter.gd
- [ ] input/on_mouse_exit.gd
- [ ] input/on_mouse_move.gd
- [ ] node/on_node_instance.gd
- [ ] node/on_property_changed.gd
- [ ] node/on_signal_from_group.gd

**进度**: 0/14 (0%)

### Phase 3: 低优先级优化
- [ ] 添加属性列表缓存 (8 个组件)

**进度**: 0/8 (0%)

---

## 🎯 总体进度

- **总组件数**: 59
- **需要修复**: 33
- **已修复**: 0
- **修复进度**: 0%

---

## 📝 注意事项

1. **修复前先备份**: 建议在修复前创建分支或备份文件
2. **逐个测试**: 修复每个组件后立即测试
3. **参考范例**: on_target_signal_emit.gd 是优秀范例
4. **统一模式**: 所有修复应使用相同的模式
5. **更新文档**: 修复完成后更新相关文档

---

**清单生成时间**: 2026-02-05
**下次更新**: Phase 1 修复完成后
