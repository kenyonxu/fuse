# Event RuntimeInstance 迁移计划 - Phase 2

**状态**: 待执行
**版本**: 2.0
**作者**: Bricks 开发团队
**日期**: 2026-02-03
**关键词**: runtime-instance, migration, event, self-declared-state

---

## 概述

本文档规划剩余 Events 迁移到 RuntimeInstance **自声明状态模式**的详细步骤。在 Phase 1 中，我们已经成功迁移了 12 个 Events 并验证了架构的可行性。Phase 2 将完成剩余 Events 的迁移工作。

### 新版架构的核心优势 ⭐

**自声明状态模式（v2.0）**的关键改进：

1. **无需修改核心代码** - Event 通过 `get_default_runtime_state()` 声明状态
2. **遵循开闭原则** - 对扩展开放，对修改封闭
3. **用户友好** - 创建自定义 Event 更简单直观
4. **向后兼容** - 完全兼容旧版架构

### 迁移的两个核心方法 ⭐

每个需要迁移的 Event **必须实现**以下两个方法：

1. **`get_default_runtime_state()`** - 声明默认运行时状态
2. **`initialize_with_runtime_instance()`** - 接收 RuntimeEventInstance 实例

**示例**：
```gdscript
## 1. 声明状态（新版核心）
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["has_triggered"] = false
	base["trigger_count"] = 0
	return base

## 2. 接收实例（新版核心）
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		return

	_runtime_instance_ref = runtime_instance

	if not owner_node:
		_create_bricks_error_localized("BRICKS_ERROR_TARGET_NODE_NULL", BricksError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# ... 连接信号 ...

	_log_debug_localized("BRICKS_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})
```

---

## 迁移状态总结

### 已迁移 Events（12个）✅

| Event | 文件路径 | 状态变量数 | 复杂度 |
|-------|---------|----------|--------|
| OnTimer | `timing/on_timer.gd` | 1 | ⭐⭐ |
| OnInputKey | `input/on_input_key.gd` | 2 | ⭐⭐ |
| OnArea2DEnter | `physics/on_area_2d_enter.gd` | 1 | ⭐⭐ |
| OnArea3DEntered | `physics/on_area_3d_entered.gd` | 1 | ⭐⭐ |
| OnSignalFromGroup | `node/on_signal_from_group.gd` | 2 | ⭐⭐ |
| OnPropertyChanged | `node/on_property_changed.gd` | 3 | ⭐⭐⭐ |
| OnVariableChanged | `variable/on_variable_changed.gd` | 3 | ⭐⭐⭐ |
| OnInterval | `lifecycle/on_interval.gd` | 4 | ⭐⭐⭐⭐ |
| OnMouseButton | `input/on_mouse_button.gd` | 2 | ⭐⭐⭐ |
| OnCooldownFinished | `timing/on_cooldown_finished.gd` | 3 | ⭐⭐⭐⭐ |
| OnMouseEnter | `input/on_mouse_enter.gd` | 1 | ⭐⭐ |
| OnMouseExit | `input/on_mouse_exit.gd` | 1 | ⭐⭐ |

**总计**: 12 个 Events，26 个状态变量

### 未迁移 Events 分类

根据初步分析，剩余 47 个 Events 可以分为以下几类：

#### 第一类：有运行时状态，需要迁移（高优先级）- 约 20 个

这些 Event 包含明显的运行时状态变量，可能导致状态共享问题：

**生命周期类 (Lifecycle)**
- OnProcess - `_is_processing` 状态
- OnPhysicsProcess - `_is_physics_processing` 状态
- OnEnterTree - `_has_entered` 状态
- OnExitTree - `_has_exited` 状态
- OnReady - `_has_ready` 状态

**物理类 (Physics)**
- OnArea2DExited - `_triggered_bodies` 数组
- OnArea3DExited - `_triggered_bodies` 数组
- OnBodyEntered - `_triggered_bodies` 数组
- OnCollision - `_collision_count` 计数器
- OnOverlappingBodies - `_overlapping_bodies` 集合
- OnRaycastHit - `_last_hit` 状态
- OnScreenEnteredExited - `_is_on_screen` 状态
- OnShapeCast - `_last_cast_result` 状态

**输入类 (Input)**
- OnGamepadAxis - `_current_axis_value` 状态
- OnGamepadButton - `_is_button_pressed` 状态
- OnInputAction - `_action_strength` 状态
- OnMouseMove - `_last_position` 状态
- OnTouch - `_touch_count` 状态
- OnTouchSwipe - `_swipe_start_position` 状态

**动画类 (Animation)**
- OnAnimationFinished - `_has_finished` 状态
- OnAnimationLoop - `_loop_count` 计数器
- OnAnimationFrameReached - `_last_frame` 状态
- OnAnimationMarker - `_last_marker` 状态
- OnAnimationStarted - `_has_started` 状态

**音频类 (Audio)**
- OnAudioFinished - `_has_finished` 状态
- OnMusicBeat - `_last_beat` 状态

#### 第二类：可能需要迁移（中优先级）- 约 15 个

这些 Event 可能包含一些状态，但影响较小：

**节点类 (Node)**
- OnNodeInstance - `_instance_refs` 引用集合
- OnTargetSignalEmit - `_last_emit_args` 参数缓存

**场景类 (Scene)**
- OnSceneLoaded - `_load_count` 计数器
- OnBackgroundLoadProgress - `_last_progress` 状态
- OnNodePausedResumed - `_is_paused` 状态
- OnSceneAboutToChange - `_has_warned` 状态
- OnTreeChanged - `_last_tree_state` 状态

**其他**
- OnCountdown - `_remaining_time` 状态
- OnHealthChanged - `_last_health` 状态
- OnAudioBusVolumeChanged - `_last_volume` 状态
- OnInputText - `_last_text` 状态
- OnAnimationBlend - `_blend_value` 状态

#### 第三类：可能无状态或状态影响小（低优先级）- 约 12 个

这些 Event 可能主要是信号转发，状态影响较小或无状态：

**信号连接类**
- 各种纯信号监听 Events

---

## 迁移策略

### 策略 1：分批渐进式迁移

**优势**：
- 风险可控，每批迁移后可以测试验证
- 可以根据优先级灵活调整
- 便于回滚和问题排查

**批次划分**：

**批次 A（高优先级，高频使用）** - 约 10 个 Events
- 生命周期：OnProcess, OnPhysicsProcess, OnReady, OnEnterTree, OnExitTree
- 物理：OnArea2DExited, OnBodyEntered, OnCollision
- 输入：OnGamepadButton, OnInputAction

**批次 B（中优先级，常用功能）** - 约 15 个 Events
- 动画：OnAnimationFinished, OnAnimationLoop, OnAnimationFrameReached
- 音频：OnAudioFinished, OnMusicBeat
- 物理：OnRaycastHit, OnOverlappingBodies
- 输入：OnGamepadAxis, OnMouseMove, OnTouch

**批次 C（低优先级，较少使用）** - 约 22 个 Events
- 剩余所有 Events

### 策略 2：按类别系统性迁移

**优势**：
- 同类别 Events 迁移模式相似，效率高
- 便于总结和文档化
- 可以建立每个类别的迁移模板

**类别顺序**：
1. **Lifecycle 类** - 最基础，影响最广
2. **Input 类** - 用户交互核心
3. **Physics 类** - 游戏逻辑关键
4. **Animation 类** - 视觉效果
5. **Audio 类** - 音效系统
6. **Scene/Node 类** - 场景管理
7. **其他类** - 剩余功能

---

## 详细迁移计划（按类别）

### 第一阶段：Lifecycle 类 Events 迁移（5个）

#### 1.1 OnProcess

**文件**: `addons/bricks/events/lifecycle/on_process.gd`

**预期状态变量**:
- `_is_processing`: bool - 是否正在处理中

**迁移步骤**:
```gdscript
## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - _is_processing: bool - 是否正在处理中
##
## 架构版本: 自声明状态模式 v2.0
## 相关文档: addons/bricks/docs/migration-guide-to-runtime-instance.md

# 运行时状态存储在 RuntimeEventInstance 中
var _runtime_instance_ref: RuntimeEventInstance = null

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["is_processing"] = false
	return base

## 使用运行时实例初始化事件
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		return

	# 保存 RuntimeEventInstance 引用
	_runtime_instance_ref = runtime_instance

	# 验证参数
	if not owner_node:
		_create_bricks_error_localized("BRICKS_ERROR_TARGET_NODE_NULL", BricksError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 连接 process 信号
	owner_node.set_process(true)
	owner_node.process.connect(_on_process)

	_log_debug_localized("BRICKS_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

func terminate(owner_node: Node) -> void:
	# 断开信号
	if owner_node and owner_node.process.is_connected(_on_process):
		owner_node.process.disconnect(_on_process)

	# 清理 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("is_processing", false)

	# 清理引用
	_runtime_instance_ref = null

	_log_debug_localized("BRICKS_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})
```

**验证**:
- [ ] process 事件正常触发
- [ ] 状态隔离正确（多个 Trigger）
- [ ] 性能无影响

#### 1.2 OnPhysicsProcess

**文件**: `addons/bricks/events/lifecycle/on_physics_process.gd`

**预期状态变量**:
- `_is_physics_processing`: bool

**迁移模式**: 同 OnProcess

#### 1.3 OnReady

**文件**: `addons/bricks/events/lifecycle/on_ready.gd`

**预期状态变量**:
- `_has_ready`: bool - 是否已就绪

**注意**: ready 事件只触发一次，状态隔离很重要

#### 1.4 OnEnterTree

**文件**: `addons/bricks/events/lifecycle/on_enter_tree.gd`

**预期状态变量**:
- `_has_entered`: bool

#### 1.5 OnExitTree

**文件**: `addons/bricks/events/lifecycle/on_exit_tree.gd`

**预期状态变量**:
- `_has_exited`: bool

**预计时间**: 0.5 天

---

### 第二阶段：Physics 类 Events 迁移（8个）

#### 2.1 OnArea2DExited

**文件**: `addons/bricks/events/physics/on_area_2d_exited.gd`

**预期状态变量**:
- `_triggered_bodies`: Array - 已触发的物体列表

**参考**: OnArea2DEnter（已迁移）

**迁移模式**: 相似于 OnArea2DEnter

#### 2.2 OnArea3DExited

**文件**: `addons/bricks/events/physics/on_area_3d_exited.gd`

**预期状态变量**:
- `_triggered_bodies`: Array

**参考**: OnArea3DEntered（已迁移）

#### 2.3 OnBodyEntered

**文件**: `addons/bricks/events/physics/on_body_entered.gd`

**预期状态变量**:
- `_triggered_bodies`: Array

#### 2.4 OnCollision

**文件**: `addons/bricks/events/physics/on_collision.gd`

**预期状态变量**:
- `_collision_count`: int - 碰撞次数
- `_last_collision`: CollisionData - 最后一次碰撞数据

#### 2.5 OnOverlappingBodies

**文件**: `addons/bricks/events/physics/on_overlapping_bodies.gd`

**预期状态变量**:
- `_overlapping_bodies`: Array - 重叠的物体集合

#### 2.6 OnRaycastHit

**文件**: `addons/bricks/events/physics/on_raycast_hit.gd`

**预期状态变量**:
- `_last_hit`: Dictionary - 最后一次射线命中结果

#### 2.7 OnScreenEnteredExited

**文件**: `addons/bricks/events/physics/on_screen_entered_exited.gd`

**预期状态变量**:
- `_is_on_screen`: bool - 是否在屏幕内

#### 2.8 OnShapeCast

**文件**: `addons/bricks/events/physics/on_shape_cast.gd`

**预期状态变量**:
- `_last_cast_result`: Dictionary - 最后一次投射结果

**预计时间**: 1 天

---

### 第三阶段：Input 类 Events 迁移（6个）

#### 3.1 OnGamepadAxis

**文件**: `addons/bricks/events/input/on_gamepad_axis.gd`

**预期状态变量**:
- `_current_axis_value`: float - 当前轴值

#### 3.2 OnGamepadButton

**文件**: `addons/bricks/events/input/on_gamepad_button.gd`

**预期状态变量**:
- `_is_button_pressed`: bool - 按钮是否按下

#### 3.3 OnInputAction

**文件**: `addons/bricks/events/input/on_input_action.gd`

**预期状态变量**:
- `_action_strength`: float - 动作强度

#### 3.4 OnMouseMove

**文件**: `addons/bricks/events/input/on_mouse_move.gd`

**预期状态变量**:
- `_last_position`: Vector2 - 最后位置
- `_movement_delta`: Vector2 - 移动增量

#### 3.5 OnTouch

**文件**: `addons/bricks/events/input/on_touch.gd`

**预期状态变量**:
- `_touch_count`: int - 触摸点数量
- `_last_touch_positions`: Array - 最后触摸位置

#### 3.6 OnTouchSwipe

**文件**: `addons/bricks/events/input/on_touch_swipe.gd`

**预期状态变量**:
- `_swipe_start_position`: Vector2 - 滑动起始位置
- `_swipe_start_time`: float - 滑动开始时间

**预计时间**: 0.75 天

---

### 第四阶段：Animation 类 Events 迁移（5个）

#### 4.1 OnAnimationFinished

**文件**: `addons/bricks/events/animation/on_animation_finished.gd`

**预期状态变量**:
- `_has_finished`: bool - 是否已完成

#### 4.2 OnAnimationLoop

**文件**: `addons/bricks/events/animation/on_animation_loop.gd`

**预期状态变量**:
- `_loop_count`: int - 循环次数

#### 4.3 OnAnimationFrameReached

**文件**: `addons/bricks/events/animation/on_animation_frame_reached.gd`

**预期状态变量**:
- `_last_frame`: int - 最后一帧
- `_has_triggered`: bool - 是否已触发

#### 4.4 OnAnimationMarker

**文件**: `addons/bricks/events/animation/on_animation_marker.gd`

**预期状态变量**:
- `_last_marker`: String - 最后的标记点
- `_has_triggered`: bool

#### 4.5 OnAnimationStarted

**文件**: `addons/bricks/events/animation/on_animation_started.gd`

**预期状态变量**:
- `_has_started`: bool

**预计时间**: 0.5 天

---

### 第五阶段：Audio 类 Events 迁移（4个）

#### 5.1 OnAudioFinished

**文件**: `addons/bricks/events/audio/on_audio_finished.gd`

**预期状态变量**:
- `_has_finished`: bool

#### 5.2 OnMusicBeat

**文件**: `addons/bricks/events/audio/on_music_beat.gd`

**预期状态变量**:
- `_last_beat`: int - 最后节拍
- `_beat_count`: int - 节拍计数

#### 5.3 OnAudioStarted

**文件**: `addons/bricks/events/audio/on_audio_started.gd`

**预期状态变量**:
- `_has_started`: bool

#### 5.4 OnAudioBusVolumeChanged

**文件**: `addons/bricks/events/audio/on_audio_bus_volume_changed.gd`

**预期状态变量**:
- `_last_volume`: float - 最后音量
- `_last_db`: float - 最后分贝值

**预计时间**: 0.5 天

---

### 第六阶段：Scene/Node 类 Events 迁移（约10个）

#### 6.1 OnSceneLoaded

**文件**: `addons/bricks/events/scene/on_scene_loaded.gd`

**预期状态变量**:
- `_load_count`: int - 加载次数
- `_last_loaded_scene`: String - 最后加载的场景

#### 6.2 OnBackgroundLoadProgress

**文件**: `addons/bricks/events/scene/on_background_load_progress.gd`

**预期状态变量**:
- `_last_progress`: float - 最后进度
- `_has_completed`: bool

#### 6.3 OnNodePausedResumed

**文件**: `addons/bricks/events/scene/on_node_paused_resumed.gd`

**预期状态变量**:
- `_is_paused`: bool
- `_last_pause_time`: float

#### 6.4 OnSceneAboutToChange

**文件**: `addons/bricks/events/scene/on_scene_about_to_change.gd`

**预期状态变量**:
- `_has_warned`: bool

#### 6.5 OnTreeChanged

**文件**: `addons/bricks/events/scene/on_tree_changed.gd`

**预期状态变量**:
- `_last_tree_state`: String

#### 6.6 OnNodeInstance

**文件**: `addons/bricks/events/node/on_node_instance.gd`

**预期状态变量**:
- `_instance_refs`: Array - 实例引用集合

#### 6.7 OnTargetSignalEmit

**文件**: `addons/bricks/events/node/on_target_signal_emit.gd`

**预期状态变量**:
- `_last_emit_args`: Array - 最后发射的参数

**预计时间**: 1 天

---

### 第七阶段：剩余 Events 迁移（约9个）

#### 7.1 OnCountdown

**文件**: `addons/bricks/events/timing/on_countdown.gd`

**预期状态变量**:
- `_remaining_time`: float
- `_is_completed`: bool

#### 7.2 OnHealthChanged

**文件**: `addons/bricks/events/gameplay/on_health_changed.gd`

**预期状态变量**:
- `_last_health`: float
- `_last_change`: float

#### 7.3 OnInputText

**文件**: `addons/bricks/events/input/on_input_text.gd`

**预期状态变量**:
- `_last_text`: String

#### 7.4 OnAnimationBlend

**文件**: `addons/bricks/events/animation/on_animation_blend.gd`

**预期状态变量**:
- `_blend_value`: float

#### 7.5-7.9 其他 Events

**预计时间**: 1 天

---

## 迁移时间表

### 第 1 周

**Day 1-2**: 第一阶段 - Lifecycle 类（5个 Events）
- 验证基础生命周期 Events 的迁移模式

**Day 3-4**: 第二阶段 - Physics 类（8个 Events）
- 处理物理相关 Events

**Day 5**: 第三阶段 - Input 类（6个 Events）
- 输入类 Events 迁移

### 第 2 周

**Day 6-7**: 第四阶段 - Animation 类（5个 Events）
- 动画系统 Events

**Day 8**: 第五阶段 - Audio 类（4个 Events）
- 音频系统 Events

**Day 9-10**: 第六阶段 - Scene/Node 类（约10个 Events）
- 场景和节点管理 Events

### 第 3 周

**Day 11-12**: 第七阶段 - 剩余 Events（约9个 Events）
- 完成所有剩余迁移

**Day 13**: 全面测试和验证
- 状态隔离测试
- 性能测试
- 回归测试

**Day 14**: 文档更新和清理
- 更新迁移指南
- 更新 Event 列表
- 代码清理

**总预计时间**: 14 工作日（约 3 周）

---

## 迁移模板

每个 Event 的迁移都遵循相同的模式。完整的迁移包括以下 6 个步骤：

### 步骤 1：删除状态变量，添加 RuntimeInstance 引用

```gdscript
# ❌ 删除这些运行时状态变量
var _has_triggered: bool = false
var _trigger_count: int = 0

# ✅ 添加 RuntimeEventInstance 引用
var _runtime_instance_ref: RuntimeEventInstance = null
```

### 步骤 2：实现 get_default_runtime_state() 方法 ⭐

```gdscript
## 获取默认运行时状态（新版核心方法）
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["has_triggered"] = false
	base["trigger_count"] = 0
	return base
```

### 步骤 3：实现 initialize_with_runtime_instance() 方法 ⭐

```gdscript
## 使用运行时实例初始化事件
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		return

	# 🔧 保存 RuntimeEventInstance 引用
	_runtime_instance_ref = runtime_instance

	# 验证参数
	if not owner_node:
		_create_bricks_error_localized("BRICKS_ERROR_TARGET_NODE_NULL", BricksError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 连接信号或设置监听
	# ... 你的初始化逻辑 ...

	_log_debug_localized("BRICKS_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})
```

**关键点**：
- 必须先检查 `Engine.is_editor_hint()`
- 保存 `runtime_instance` 到 `_runtime_instance_ref`
- 使用传入的 `owner_node` 参数进行初始化
- 这是 Trigger 调用 Event 的入口点

### 步骤 4：修改状态访问

```gdscript
# 读取状态
var has_triggered: bool = false
if _runtime_instance_ref and _runtime_instance_ref.has_runtime_state("has_triggered"):
	has_triggered = _runtime_instance_ref.get_runtime_state("has_triggered")

# 写入状态
if _runtime_instance_ref:
	_runtime_instance_ref.set_runtime_state("has_triggered", true)
	_runtime_instance_ref.set_runtime_state("trigger_count",
		_runtime_instance_ref.get_runtime_state("trigger_count", 0) + 1
	)
```

### 步骤 5：在 terminate() 和 reset() 中清理状态

```gdscript
func terminate(owner_node: Node) -> void:
	# 断开信号连接
	_disconnect_signals(owner_node)

	# 清理 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("has_triggered", false)
		_runtime_instance_ref.set_runtime_state("trigger_count", 0)

	# 清理引用
	_runtime_instance_ref = null

	_log_debug_localized("BRICKS_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

func reset() -> void:
	super.reset()

	# 重置 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("has_triggered", false)
		_runtime_instance_ref.set_runtime_state("trigger_count", 0)
```

### 步骤 6：添加迁移注释

```gdscript
## Event: OnMyEvent
##
## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - _has_triggered: bool - 是否已触发
## - _trigger_count: int - 触发次数
##
## 架构版本: 自声明状态模式 v2.0
## 相关文档: addons/bricks/docs/migration-guide-to-runtime-instance.md
class_name OnMyEvent
extends BaseEvent
```

---

## 特定状态类型的迁移模板

### 模板 1：简单状态（布尔值）

```gdscript
## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - _has_triggered: bool - 是否已触发
##
## 架构版本: 自声明状态模式 v2.0
## 相关文档: addons/bricks/docs/migration-guide-to-runtime-instance.md

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["has_triggered"] = false
	return base

## 使用运行时实例初始化事件
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		return

	_runtime_instance_ref = runtime_instance

	if not owner_node:
		_create_bricks_error_localized("BRICKS_ERROR_TARGET_NODE_NULL", BricksError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# ... 初始化逻辑 ...

	_log_debug_localized("BRICKS_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})
```

### 模板 2：计数器状态

```gdscript
## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - _count: int - 计数
##
## 架构版本: 自声明状态模式 v2.0

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["count"] = 0
	return base

## 使用运行时实例初始化事件
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		return

	_runtime_instance_ref = runtime_instance

	if not owner_node:
		_create_bricks_error_localized("BRICKS_ERROR_TARGET_NODE_NULL", BricksError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# ... 初始化逻辑 ...

	_log_debug_localized("BRICKS_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})
```

### 模板 3：复杂状态（多个变量）

```gdscript
## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - _state1: bool - 状态1
## - _state2: int - 状态2
## - _state3: float - 状态3
##
## 架构版本: 自声明状态模式 v2.0

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["state1"] = false
	base["state2"] = 0
	base["state3"] = 0.0
	return base

## 使用运行时实例初始化事件
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		return

	_runtime_instance_ref = runtime_instance

	if not owner_node:
		_create_bricks_error_localized("BRICKS_ERROR_TARGET_NODE_NULL", BricksError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# ... 初始化逻辑 ...

	_log_debug_localized("BRICKS_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})
```

### 模板 4：数组/集合状态

```gdscript
## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - _items: Array - 项目集合
##
## 架构版本: 自声明状态模式 v2.0

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["items"] = []
	return base

## 使用运行时实例初始化事件
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		return

	_runtime_instance_ref = runtime_instance

	if not owner_node:
		_create_bricks_error_localized("BRICKS_ERROR_TARGET_NODE_NULL", BricksError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# ... 初始化逻辑 ...

	_log_debug_localized("BRICKS_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})
```

---

## 迁移检查清单

迁移前检查：
- [ ] 确认 Event 有运行时状态变量
- [ ] 确认 Event 可能被多个节点共享
- [ ] 备份原始 Event 文件
- [ ] 阅读完整迁移指南

迁移步骤（新版：自声明状态模式）：
- [ ] 1. **识别状态变量** - 找出所有运行时状态变量
- [ ] 2. **删除状态变量** - 删除 `var` 声明的状态变量
- [ ] 3. **添加 RuntimeInstance 引用** - 添加 `_runtime_instance_ref`
- [ ] 4. **⭐ 实现 `get_default_runtime_state()` 方法** - 声明默认状态
- [ ] 5. **⭐ 实现 `initialize_with_runtime_instance()` 方法** - 接收 RuntimeEventInstance 实例
- [ ] 6. **修改状态访问** - 使用 `get_runtime_state()` / `set_runtime_state()`
- [ ] 7. **清理状态** - 在 `terminate()` 和 `reset()` 中清理
- [ ] 8. **添加迁移注释** - 在文件顶部添加注释说明

迁移后验证：
- [ ] Event 功能正常工作
- [ ] 多个节点共享 Event 时状态独立
- [ ] 没有内存泄漏
- [ ] 更新了文档和注释

**关键要点**：
- ✅ **必须实现** `get_default_runtime_state()` 方法（新版核心）
- ✅ **必须实现** `initialize_with_runtime_instance()` 方法（接收 RuntimeEventInstance 实例）
- ✅ **无需修改** `RuntimeEventInstance` 核心代码
- ✅ **遵循开闭原则** - 对扩展开放，对修改封闭

---

## 验证和测试

### 每个阶段后的验证

**功能测试**:
- [ ] Event 正常触发
- [ ] 参数正确传递
- [ ] 上下文信息正确

**状态隔离测试**:
- [ ] 创建多个 Trigger 节点
- [ ] 配置同一个 Event 资源
- [ ] 验证状态互不干扰

**性能测试**:
- [ ] 内存使用正常
- [ ] CPU 开销可接受
- [ ] 无明显性能下降

**回归测试**:
- [ ] 已有功能不受影响
- [ ] 编辑器正常工作
- [ ] 项目可以正常编译

### 最终全面测试

**场景测试**:
1. 创建测试场景，包含各种 Events
2. 多个 Trigger 共享同一 Event
3. 验证所有 Events 都正常工作

**压力测试**:
1. 100 个 Trigger 节点
2. 共享 10 个 Event 资源
3. 验证内存和性能

**兼容性测试**:
1. 打开旧项目
2. 验证所有 Events 仍能工作
3. 验证向后兼容性

---

## 风险和缓解措施

### 风险 1：大规模迁移可能引入 Bug

**缓解措施**:
- 分批次迁移，每批独立测试
- 保留旧代码注释便于回滚
- 完善测试覆盖

### 风险 2：性能影响

**缓解措施**:
- 性能基准测试
- 监控内存使用
- 优化热路径代码

### 风险 3：向后兼容性

**缓解措施**:
- RuntimeEventInstance 保留旧版支持
- 渐进式迁移策略
- 用户可选择迁移时机

---

## 成功指标

### 定量指标

- **迁移完成度**: 100% Events 迁移完成
- **代码减少**: RuntimeEventInstance 代码减少 80%
- **测试覆盖**: 所有迁移 Events 有测试用例
- **性能影响**: < 5% CPU 开销，< 1% 内存开销

### 定性指标

- **架构改进**: 遵循开闭原则
- **用户体验**: 自定义 Event 更容易
- **代码质量**: 更清晰的状态管理
- **可维护性**: 更容易理解和扩展

---

## 后续工作

### 优先事项

1. **完成所有 Events 迁移** - 本计划的核心目标
2. **完善测试覆盖** - 每个迁移的 Event 都有测试
3. **更新文档** - Event 创建指南、迁移指南
4. **性能优化** - 如果有性能问题

### 可选增强

1. **自动化迁移工具** - Python 脚本辅助迁移
2. **状态可视化工具** - 在编辑器中查看运行时状态
3. **性能分析工具** - 监控状态访问性能
4. **最佳实践文档** - 总结常见模式和陷阱

---

## 参考资料

- **完整迁移指南**: [addons/bricks/docs/migration-guide-to-runtime-instance.md](../addons/bricks/docs/migration-guide-to-runtime-instance.md)
- **Event 创建指南**: [addons/bricks/docs/development/event_creation_guide.md](../addons/bricks/docs/development/event_creation_guide.md)
- **Phase 1 执行摘要**: [docs/plans/2025-02-03-runtime-instance-refactoring-execution-summary.md](2025-02-03-runtime-instance-refactoring-execution-summary.md)
- **迁移技能**: `/brick_event_runtime_instance_migration`

---

**文档版本**: 1.0
**创建日期**: 2026-02-03
**作者**: Bricks 开发团队
**状态**: 待审核和批准
