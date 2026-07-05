# JuicyMixer Driver 状态污染修复计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**目标:** 修复 JuicyMixer Driver 中的状态污染问题，确保多个播放可以独立运行而不互相干扰

**架构:** 将 Driver 实例级别的运行时状态迁移到按 context_id 隔离的状态存储，参考 Bricks 系统的 RuntimeInstance 模式

**技术栈:** Godot 4.6, GDScript 2.0, JuicyMixer V3

---

## 前置知识

### 问题本质
当同一个资源（如 TimelineResource）被多个对象同时播放时，会共享同一个 Driver 实例。如果运行时状态存储在 Driver 的成员变量中，多个播放会互相覆盖状态。

### 正确模式
```gdscript
# ✅ 正确：按 context_id 隔离
var _driver_states: Dictionary = {}  # context_id -> DriverState

class DriverState:
    var runtime_var: float = 0.0

func prepare(context: JuicyContext, delta: float, buffer: JuicyPropertyBuffer) -> void:
    var state = DriverState.new()
    _driver_states[context.context_id] = state

func process(context: JuicyContext, delta: float, buffer: JuicyPropertyBuffer) -> void:
    var state = _driver_states.get(context.context_id)
    if not state:
        return

func cleanup(context: JuicyContext) -> void:
    _driver_states.erase(context.context_id)
```

### 参考文档
- [状态污染审计报告](../analysis/juicy_mixer_driver_state_pollution_audit.md)
- [详细分析报告](../analysis/juicy_mixer_state_pollution_analysis.md)
- [JuicySequenceDriver 正确实现](../addons/juicy_mixer/drivers/juicy_sequence_driver.gd)
- [Bricks RuntimeInstance 模式](../addons/bricks/docs/architecture/runtime-instance-pattern.md)

---

## Phase 1: 修复 JuicyTimelineDriver（高优先级）

### Task 1: 创建 TimelineState 内部类

**文件:**
- Modify: `addons/juicy_mixer/drivers/juicy_timeline_driver.gd:43-68`

**Step 1: 添加 TimelineState 内部类定义**

在 `juicy_timeline_driver.gd` 中，在现有类成员变量之前添加 TimelineState 类：

```gdscript
# =============================================================================
# 时间轴状态管理
# =============================================================================

## Timeline 运行时状态类
class TimelineState:
	var current_time: float = 0.0
	var is_playing: bool = false
	var is_paused: bool = false
	var play_direction: int = 1  # 1为正向，-1为反向
	var current_loop: int = 0

	# 轨道状态跟踪
	var active_property_tracks: Array[JuicyPropertyTrack] = []
	var active_feedback_tracks: Array[JuicyFeedbackTrack] = []
	var active_method_tracks: Array[JuicyMethodTrack] = []
	var active_event_tracks: Array[JuicyEventTrack] = []

	# 触发状态记录
	var triggered_methods: Dictionary = {}  # method_track -> last_trigger_time
	var triggered_events: Dictionary = {}   # event_track -> last_trigger_time
	var active_sub_contexts: Dictionary = {}  # feedback_track -> context_id

	# 性能优化
	var property_batch_updates: Dictionary = {}  # property -> [value, mode]
	var last_processed_time: float = -1.0
	var track_cache_valid: bool = false

# 引用Timeline资源
var timeline_resource: JuicyTimelineResource

## 按context_id隔离的Timeline状态
var _timeline_states: Dictionary = {}  # context_id -> TimelineState
```

**Step 2: 运行 Godot 语法检查**

Run: `E:\Godot\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64.exe --headless --check-only --quit`
Expected: 无语法错误

**Step 3: 提交**

```bash
git add addons/juicy_mixer/drivers/juicy_timeline_driver.gd
git commit -m "refactor(timeline): add TimelineState inner class for state isolation"
```

---

### Task 2: 修改 prepare() 方法使用状态隔离

**文件:**
- Modify: `addons/juicy_mixer/drivers/juicy_timeline_driver.gd:64-106`

**Step 1: 修改 prepare() 方法**

将现有的 `prepare()` 方法修改为：

```gdscript
func prepare(context: JuicyContext, delta: float, buffer: JuicyPropertyBuffer) -> void:
	"""
	准备阶段，初始化Timeline状态和轨道

	@param context: JuicyContext实例，包含效果运行所需的所有数据
	@param delta: 时间增量（秒）
	@param buffer: JuicyPropertyBuffer实例，用于属性缓冲
	"""
	# 获取Timeline资源
	timeline_resource = context.get_driver_data("timeline_resource") as JuicyTimelineResource

	# 如果driver_data中没有，尝试从context.resource获取（TimelineResource作为FeedbackResource播放时）
	if not timeline_resource:
		if context.resource and context.resource is JuicyTimelineResource:
			timeline_resource = context.resource as JuicyTimelineResource
		else:
			_log_error("Timeline resource not found in context")
			return

	# Phase 3B: 确保时长自动计算在运行时生效
	if timeline_resource.auto_calculate_duration:
		timeline_resource.recalculate_duration()

	# ✅ 创建独立的 TimelineState
	var state = TimelineState.new()
	state.current_time = context.get_driver_data("current_time") if context.get_driver_data("current_time") != null else 0.0
	state.is_playing = true
	state.is_paused = false
	state.play_direction = 1
	state.current_loop = 0

	# 存储状态
	_timeline_states[context.context_id] = state

	# 初始化驱动器时间
	_initialize_driver_time(context)

	# 初始化轨道状态
	_initialize_track_states(context)

	# 初始化参数映射
	_initialize_parameter_mappings(context)

	# 重置性能统计
	_reset_performance_stats()

	_log_debug("Timeline driver prepared: " + timeline_resource.get_description())
```

**Step 2: 运行语法检查**

Run: `E:\Godot\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64.exe --headless --check-only --quit`
Expected: 无语法错误

**Step 3: 提交**

```bash
git add addons/juicy_mixer/drivers/juicy_timeline_driver.gd
git commit -m "refactor(timeline): use TimelineState in prepare() method"
```

---

### Task 3: 修改 process() 方法使用状态隔离

**文件:**
- Modify: `addons/juicy_mixer/drivers/juicy_timeline_driver.gd:108-156`

**Step 1: 修改 process() 方法访问状态**

将所有直接访问成员变量的地方改为访问 state 对象：

```gdscript
func process(context: JuicyContext, delta: float, buffer: JuicyPropertyBuffer) -> void:
	"""
	处理阶段，每帧更新和时间推进

	@param context: JuicyContext实例，包含效果运行所需的所有数据
	@param delta: 时间增量（秒）
	@param buffer: JuicyPropertyBuffer实例，用于属性缓冲
	"""
	# ✅ 获取状态
	var state = _timeline_states.get(context.context_id)
	if not state:
		_log_error("No timeline state found for context: " + context.context_id)
		return

	if not timeline_resource or not state.is_playing or state.is_paused:
		return

	# 开始性能计时
	var start_time = _start_execution_timer()

	# 更新驱动器时间
	var effective_delta = _update_driver_time(context, delta)

	# ✅ 使用 state.current_time
	state.current_time += effective_delta * state.play_direction * timeline_resource.time_scale

	# 处理循环
	var loop_completed = _handle_looping(state)

	# 如果循环完成，重置 PropertyTrack 的状态（支持 relative 和 additive）
	if loop_completed:
		_reset_property_track_states(context)

	# 处理所有轨道
	_process_all_tracks(context, buffer, state)

	# 批处理属性更新
	_flush_property_updates(buffer, state)

	# 更新上下文时间
	context.current_time = state.current_time
	context.progress = get_progress(state)

	# 更新性能统计
	_end_execution_timer(start_time)
	_update_performance_stats(state)

	# 检查是否完成
	if not state.is_playing:
		print("[JuicyTimelineDriver] Timeline completed - current_time: ", state.current_time, ", timeline_duration: ", timeline_resource.timeline_duration)
		context.complete()

	_log_debug("Timeline processed: time=%.3f, progress=%.2f" % [state.current_time, context.progress])
```

**Step 2: 修改 _process_all_tracks() 签名**

更新 `_process_all_tracks()` 方法以接受 state 参数：

```gdscript
func _process_all_tracks(context: JuicyContext, buffer: JuicyPropertyBuffer, state: TimelineState) -> void:
	"""
	处理所有轨道

	@param context: JuicyContext实例
	@param buffer: JuicyPropertyBuffer实例
	@param state: Timeline运行时状态
	"""
	# 如果时间没有变化，跳过处理
	if state.current_time == state.last_processed_time:
		return

	# 更新活跃轨道列表（如果需要）
	if not state.track_cache_valid:
		_update_active_track_lists(state)
		state.track_cache_valid = true

	# 处理属性轨道
	for track in state.active_property_tracks:
		_process_property_track(track, context, buffer, state)

	# 处理反馈轨道
	for track in state.active_feedback_tracks:
		_process_feedback_track(track, context, state)

	# 处理方法轨道
	for track in state.active_method_tracks:
		_process_method_track(track, context, state)

	# 处理事件轨道
	for track in state.active_event_tracks:
		_process_event_track(track, context, state)

	state.last_processed_time = state.current_time
```

**Step 3: 运行语法检查**

Run: `E:\Godot\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64.exe --headless --check-only --quit`
Expected: 无语法错误

**Step 4: 提交**

```bash
git add addons/juicy_mixer/drivers/juicy_timeline_driver.gd
git commit -m "refactor(timeline): use TimelineState in process() method"
```

---

### Task 4: 修改轨道处理方法使用状态

**文件:**
- Modify: `addons/juicy_mixer/drivers/juicy_timeline_driver.gd:225-348`

**Step 1: 修改 _process_property_track()**

```gdscript
func _process_property_track(track: JuicyPropertyTrack, context: JuicyContext, buffer: JuicyPropertyBuffer, state: TimelineState) -> void:
	"""
	处理属性轨道

	@param track: 属性轨道实例
	@param context: JuicyContext实例
	@param buffer: JuicyPropertyBuffer实例
	@param state: Timeline运行时状态
	"""
	# 检查轨道是否在当前时间活跃
	var is_active = track.is_active_at_time(state.current_time, context)
	if not is_active:
		return

	# 检查轨道时间范围
	var in_time_range = not (state.current_time < track.get_start_time() or state.current_time > track.get_end_time())
	if not in_time_range:
		return

	# 获取轨道的目标节点
	var track_target = track.get_target_node()
	if not track_target:
		_log_warning("Failed to get target node for property track: " + track.track_name)
		return

	# 获取属性值
	var property_value = track.get_value_at_time(state.current_time, context)

	# 应用参数映射
	if track.use_parameter_mapping:
		property_value = track.apply_parameter_mappings(context, property_value)
		_log_debug("Applied parameter mappings for track '" + track.track_name + "': " + str(property_value))

	# 添加到批处理更新（使用轨道的目标节点）
	_add_property_batch_update(track_target, track.property_path, property_value, track.blend_mode, track, state)

	state.performance_stats.properties_updated += 1
	_log_debug("Property track processed: %s.%s = %s" % [track_target.name, track.property_path, property_value])
```

**Step 2: 修改 _process_feedback_track()**

```gdscript
func _process_feedback_track(track: JuicyFeedbackTrack, context: JuicyContext, state: TimelineState) -> void:
	"""
	处理反馈轨道

	@param track: 反馈轨道实例
	@param context: JuicyContext实例
	@param state: Timeline运行时状态
	"""
	# 检查是否应该触发
	if not track.should_trigger(state.current_time, context):
		return

	# 获取轨道的目标节点
	var track_target = track.get_target_node()
	if not track_target:
		_log_warning("Failed to get target node for feedback track: " + track.track_name)
		return

	# 触发子效果（使用轨道的目标节点）
	var sub_context_id = track.trigger_sub_effect_with_target(track_target, context)
	if sub_context_id != "":
		state.active_sub_contexts[track] = sub_context_id
		state.performance_stats.sub_effects_triggered += 1
		_log_debug("Feedback track triggered: " + track.track_name + " on target: " + track_target.name)

	# 更新子效果参数
	if track in state.active_sub_contexts:
		var progress = (state.current_time - track.start_time) / track.get_actual_duration()
		track.update_sub_effect_parameters(context, progress)

		# 记录子效果参数更新
		_log_debug("Updated sub-effect parameters for track '" + track.track_name + "' at progress: " + str(progress))
```

**Step 3: 修改 _process_method_track()**

```gdscript
func _process_method_track(track: JuicyMethodTrack, context: JuicyContext, state: TimelineState) -> void:
	"""
	处理方法轨道

	@param track: 方法轨道实例
	@param context: JuicyContext实例
	@param state: Timeline运行时状态
	"""
	# 检查是否应该触发
	if not track.should_trigger(state.current_time, context):
		return

	# 获取轨道的目标节点
	var track_target = track.get_target_node()
	if not track_target:
		_log_warning("Failed to get target node for method track: " + track.track_name)
		return

	# 触发方法调用（使用轨道的目标节点）
	track.trigger_method_with_target(track_target, context)
	state.triggered_methods[track] = state.current_time
	state.performance_stats.methods_called += 1
	_log_debug("Method track triggered: " + track.method_name + " on target: " + track_target.name + " with parameter mappings")

	# 处理待处理的调用
	track.process_pending_calls(context)
```

**Step 4: 修改 _process_event_track()**

```gdscript
func _process_event_track(track: JuicyEventTrack, context: JuicyContext, state: TimelineState) -> void:
	"""
	处理事件轨道

	@param track: 事件轨道实例
	@param context: JuicyContext实例
	@param state: Timeline运行时状态
	"""
	# 检查是否应该触发
	if not track.should_trigger(state.current_time, context):
		return

	# 获取轨道的目标节点
	var track_target = track.get_target_node()
	if not track_target:
		_log_warning("Failed to get target node for event track: " + track.track_name)
		return

	# 触发事件（使用轨道的目标节点）
	track.trigger_event_with_target(track_target, context)
	state.triggered_events[track] = state.current_time
	state.performance_stats.events_fired += 1
	_log_debug("Event track triggered: " + track.track_name + " on target: " + track_target.name + " with parameter mappings")

	# 处理待处理的事件
	track.process_pending_events(context)
```

**Step 5: 运行语法检查**

Run: `E:\Godot\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64.exe --headless --check-only --quit`
Expected: 无语法错误

**Step 6: 提交**

```bash
git add addons/juicy_mixer/drivers/juicy_timeline_driver.gd
git commit -m "refactor(timeline): use TimelineState in track processing methods"
```

---

### Task 5: 修改循环处理和辅助方法

**文件:**
- Modify: `addons/juicy_mixer/drivers/juicy_timeline_driver.gd:449-550`

**Step 1: 修改 _handle_looping()**

```gdscript
func _handle_looping(state: TimelineState) -> bool:
	"""
	处理循环逻辑

	@param state: Timeline运行时状态
	@return: 是否完成了一次循环
	"""
	if not timeline_resource:
		return false

	var duration = timeline_resource.timeline_duration
	var loop_completed = false

	match timeline_resource.loop_mode:
		JuicyTimelineResource.LoopMode.NO_LOOP:
			# 无循环，检查是否结束
			if state.current_time >= duration:
				state.current_time = duration
				state.is_playing = false
			elif state.current_time < 0:
				state.current_time = 0
				state.is_playing = false

		JuicyTimelineResource.LoopMode.LOOP:
			# 循环播放
			if state.current_time >= duration:
				state.current_time = fmod(state.current_time, duration)
				state.current_loop += 1
				loop_completed = true
			elif state.current_time < 0:
				state.current_time = duration - fmod(abs(state.current_time), duration)
				state.current_loop += 1
				loop_completed = true

		JuicyTimelineResource.LoopMode.PING_PONG:
			# 往返播放
			if state.current_time >= duration:
				state.current_time = duration - (state.current_time - duration)
				state.play_direction = -1
				state.current_loop += 1
				loop_completed = true
			elif state.current_time < 0:
				state.current_time = -state.current_time
				state.play_direction = 1
				state.current_loop += 1
				loop_completed = true

	# 检查循环次数限制
	if timeline_resource.loop_count > 0 and state.current_loop >= timeline_resource.loop_count:
		state.is_playing = false

	# 重置触发状态（如果完成了一次循环）
	if loop_completed:
		_reset_trigger_states(state)

	return loop_completed
```

**Step 2: 修改 _reset_trigger_states()**

```gdscript
func _reset_trigger_states(state: TimelineState) -> void:
	"""
	重置触发状态

	@param state: Timeline运行时状态
	"""
	# 重置Feedback Track的范围进入状态（支持循环时重新触发）
	for track in state.active_feedback_tracks:
		if track and track.has_method("_has_entered_range"):
			track._has_entered_range = false

	# 清理方法触发状态
	var methods_to_remove = []
	for track in state.triggered_methods.keys():
		if track.trigger_once:
			methods_to_remove.append(track)

	for track in methods_to_remove:
		state.triggered_methods.erase(track)

	# 清理事件触发状态
	var events_to_remove = []
	for track in state.triggered_events.keys():
		if track.trigger_once:
			events_to_remove.append(track)

	for track in events_to_remove:
		state.triggered_events.erase(track)
```

**Step 3: 修改 _add_property_batch_update()**

```gdscript
func _add_property_batch_update(target_node: Node, property: String, value: Variant, mode: int, track: JuicyTrack, state: TimelineState) -> void:
	"""
	添加属性批处理更新

	@param target_node: 目标节点
	@param property: 属性名称
	@param value: 属性值
	@param mode: 混合模式
	@param track: 轨道实例（用于生成唯一的 context_id）
	@param state: Timeline运行时状态
	"""
	# 使用节点ID作为键，支持多个目标节点
	var node_id = target_node.get_instance_id()

	if not state.property_batch_updates.has(node_id):
		state.property_batch_updates[node_id] = {}

	# 使用 track 的唯一标识符作为 context_id，避免不同 track 互相覆盖
	var context_id = "timeline_driver"
	if track:
		context_id = "track_" + str(track.get_instance_id())

	# 修改数据结构：支持同一属性的多个轨道更新（使用数组）
	if not state.property_batch_updates[node_id].has(property):
		state.property_batch_updates[node_id][property] = []

	state.property_batch_updates[node_id][property].append({"value": value, "mode": mode, "context_id": context_id})
```

**Step 4: 修改 _flush_property_updates()**

```gdscript
func _flush_property_updates(buffer: JuicyPropertyBuffer, state: TimelineState) -> void:
	"""
	批处理属性更新

	@param buffer: JuicyPropertyBuffer实例
	@param state: Timeline运行时状态
	"""
	if state.property_batch_updates.is_empty():
		return

	# 应用所有属性更新到各个目标节点
	for node_id in state.property_batch_updates:
		var node = instance_from_id(node_id) as Node
		if not node:
			continue

		var properties = state.property_batch_updates[node_id]
		for property in properties:
			var updates_array = properties[property]  # ← 现在是数组
			# 遍历所有轨道的更新
			for update_data in updates_array:
				buffer.add_sample(node, property, update_data.value, update_data.mode, update_data.context_id)

	# 清空批处理
	state.property_batch_updates.clear()
```

**Step 5: 修改 _update_performance_stats()**

```gdscript
func _update_performance_stats(state: TimelineState) -> void:
	"""
	更新性能统计

	@param state: Timeline运行时状态
	"""
	state.performance_stats.tracks_processed = (
		state.active_property_tracks.size() +
		state.active_feedback_tracks.size() +
		state.active_method_tracks.size() +
		state.active_event_tracks.size()
	)
```

**Step 6: 运行语法检查**

Run: `E:\Godot\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64.exe --headless --check-only --quit`
Expected: 无语法错误

**Step 7: 提交**

```bash
git add addons/juicy_mixer/drivers/juicy_timeline_driver.gd
git commit -m "refactor(timeline): use TimelineState in helper methods"
```

---

### Task 6: 修改 cleanup() 和初始化方法

**文件:**
- Modify: `addons/juicy_mixer/drivers/juicy_timeline_driver.gd:158-397`

**Step 1: 修改 cleanup() 方法**

```gdscript
func cleanup(context: JuicyContext) -> void:
	"""
	清理阶段，清理资源和子效果

	@param context: JuicyContext实例，包含效果运行所需的所有数据
	"""
	# ✅ 获取状态
	var state = _timeline_states.get(context.context_id)
	if not state:
		_log_warning("No timeline state found for cleanup: " + context.context_id)
		return

	# 停止所有活跃的子效果
	_cleanup_sub_effects(state)

	# 清理轨道状态
	_cleanup_track_states(state)

	# 清理驱动器时间
	_cleanup_driver_time(context)

	# ✅ 移除状态
	_timeline_states.erase(context.context_id)

	_log_debug("Timeline driver cleaned up")
```

**Step 2: 修改 _initialize_track_states()**

```gdscript
func _initialize_track_states(context: JuicyContext) -> void:
	"""
	初始化轨道状态

	@param context: JuicyContext实例
	"""
	if not timeline_resource:
		return

	# ✅ 获取状态
	var state = _timeline_states.get(context.context_id)
	if not state:
		_log_error("No timeline state found during track initialization: " + context.context_id)
		return

	# 初始化所有轨道
	for track in timeline_resource.get_all_tracks():
		track.initialize_track(context)

	# 更新活跃轨道列表
	_update_active_track_lists(state)
	state.track_cache_valid = true

	# 清理触发状态
	state.triggered_methods.clear()
	state.triggered_events.clear()
	state.active_sub_contexts.clear()
```

**Step 3: 修改 _cleanup_track_states()**

```gdscript
func _cleanup_track_states(state: TimelineState) -> void:
	"""
	清理轨道状态

	@param state: Timeline运行时状态
	"""
	if not timeline_resource:
		return

	# 创建临时上下文用于清理
	var temp_context = JuicyContext.create(timeline_resource, null)

	# 清理所有轨道
	for track in timeline_resource.get_all_tracks():
		track.cleanup_track(temp_context)

	# 清理活跃轨道列表
	state.active_property_tracks.clear()
	state.active_feedback_tracks.clear()
	state.active_method_tracks.clear()
	state.active_event_tracks.clear()
	state.track_cache_valid = false
```

**Step 4: 修改 _update_active_track_lists()**

```gdscript
func _update_active_track_lists(state: TimelineState) -> void:
	"""
	更新活跃轨道列表

	@param state: Timeline运行时状态
	"""
	if not timeline_resource:
		return

	# 清空现有列表
	state.active_property_tracks.clear()
	state.active_feedback_tracks.clear()
	state.active_method_tracks.clear()
	state.active_event_tracks.clear()

	# 按优先级排序轨道
	var all_tracks = timeline_resource.get_all_tracks()
	all_tracks.sort_custom(func(a, b): return a.priority > b.priority)

	# 分类轨道
	for track in all_tracks:
		if not track.enabled:
			continue

		match track.get_track_type():
			"Property":
				state.active_property_tracks.append(track as JuicyPropertyTrack)
			"Feedback":
				state.active_feedback_tracks.append(track as JuicyFeedbackTrack)
			"Method":
				state.active_method_tracks.append(track as JuicyMethodTrack)
			"Event":
				state.active_event_tracks.append(track as JuicyEventTrack)
```

**Step 5: 修改 _cleanup_sub_effects()**

```gdscript
func _cleanup_sub_effects(state: TimelineState) -> void:
	"""
	清理所有活跃的子效果

	@param state: Timeline运行时状态
	"""
	for track in state.active_sub_contexts.keys():
		var context_id = state.active_sub_contexts[track]
		if context_id != "":
			JuicyMixer.stop(context_id)

	state.active_sub_contexts.clear()
```

**Step 6: 修改 _reset_performance_stats()**

```gdscript
func _reset_performance_stats() -> void:
	"""
	重置性能统计

	@param state: Timeline运行时状态（可选）
	"""
	# 注意：此方法在 prepare() 中调用，此时 state 已创建
	pass  # 性能统计现在在 TimelineState 中初始化时自动重置
```

**Step 7: 运行语法检查**

Run: `E:\Godot\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64.exe --headless --check-only --quit`
Expected: 无语法错误

**Step 8: 提交**

```bash
git add addons/juicy_mixer/drivers/juicy_timeline_driver.gd
git commit -m "refactor(timeline): use TimelineState in cleanup and initialization"
```

---

### Task 7: 修改公共接口方法

**文件:**
- Modify: `addons/juicy_mixer/drivers/juicy_timeline_driver.gd:804-858`

**Step 1: 修改 get_progress()**

```gdscript
func get_progress(state: TimelineState = null) -> float:
	"""
	获取播放进度（0.0-1.0）

	@param state: Timeline运行时状态（可选）
	@return: 播放进度（0.0-1.0）
	"""
	if not timeline_resource or timeline_resource.timeline_duration <= 0:
		return 0.0

	# 如果没有提供 state，返回 0.0（此方法现在需要 state 参数）
	if not state:
		return 0.0

	return clampf(state.current_time / timeline_resource.timeline_duration, 0.0, 1.0)
```

**Step 2: 修改 set_time()**

```gdscript
func set_time(context: JuicyContext, time: float) -> void:
	"""
	设置播放时间

	@param context: JuicyContext实例
	@param time: 时间值（秒）
	"""
	var state = _timeline_states.get(context.context_id)
	if not state:
		_log_warning("No timeline state found in set_time(): " + context.context_id)
		return

	if timeline_resource:
		state.current_time = clampf(time, 0.0, timeline_resource.timeline_duration)
		state.track_cache_valid = false  # 时间变化可能影响活跃轨道
```

**Step 3: 修改 get_current_loop()**

```gdscript
func get_current_loop(context: JuicyContext) -> int:
	"""
	获取当前循环次数

	@param context: JuicyContext实例
	@return: 循环次数
	"""
	var state = _timeline_states.get(context.context_id)
	if not state:
		return 0

	return state.current_loop
```

**Step 4: 修改 is_timeline_active()**

```gdscript
func is_timeline_active(context: JuicyContext) -> bool:
	"""
	检查是否正在播放

	@param context: JuicyContext实例
	@return: 是否正在播放
	"""
	var state = _timeline_states.get(context.context_id)
	if not state:
		return false

	return state.is_playing and not state.is_paused
```

**Step 5: 修改 get_playback_state()**

```gdscript
func get_playback_state(context: JuicyContext) -> String:
	"""
	获取播放状态描述

	@param context: JuicyContext实例
	@return: 状态描述字符串
	"""
	var state = _timeline_states.get(context.context_id)
	if not state:
		return "Unknown"

	if not state.is_playing:
		return "Stopped"
	elif state.is_paused:
		return "Paused"
	else:
		return "Playing"
```

**Step 6: 修改 get_debug_info()**

```gdscript
func get_debug_info(context: JuicyContext) -> Dictionary:
	"""
	获取调试信息

	@param context: JuicyContext实例
	@return: 调试信息字典
	"""
	var state = _timeline_states.get(context.context_id)

	return {
		"timeline_resource": timeline_resource.get_description() if timeline_resource else "null",
		"current_time": state.current_time if state else 0.0,
		"is_playing": state.is_playing if state else false,
		"is_paused": state.is_paused if state else false,
		"play_direction": state.play_direction if state else 1,
		"current_loop": state.current_loop if state else 0,
		"active_tracks": {
			"property": state.active_property_tracks.size() if state else 0,
			"feedback": state.active_feedback_tracks.size() if state else 0,
			"method": state.active_method_tracks.size() if state else 0,
			"event": state.active_event_tracks.size() if state else 0
		},
		"performance_stats": state.performance_stats.duplicate() if state else {},
		"driver_performance": get_performance_stats()
	}
```

**Step 7: 运行语法检查**

Run: `E:\Godot\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64.exe --headless --check-only --quit`
Expected: 无语法错误

**Step 8: 提交**

```bash
git add addons/juicy_mixer/drivers/juicy_timeline_driver.gd
git commit -m "refactor(timeline): update public interfaces to use TimelineState"
```

---

### Task 8: 移除旧的成员变量

**文件:**
- Modify: `addons/juicy_mixer/drivers/juicy_timeline_driver.gd:26-57`

**Step 1: 删除旧的成员变量**

删除以下已被 TimelineState 替代的成员变量：

```gdscript
# ❌ 删除这些行
# var current_time: float = 0.0
# var is_playing: bool = false
# var is_paused: bool = false
# var play_direction: int = 1  # 1为正向，-1为反向
# var current_loop: int = 0

# 轨道状态跟踪
# var _active_property_tracks: Array[JuicyPropertyTrack] = []
# var _active_feedback_tracks: Array[JuicyFeedbackTrack] = []
# var _active_method_tracks: Array[JuicyMethodTrack] = []
# var _active_event_tracks: Array[JuicyEventTrack] = []

# 触发状态记录
# var _triggered_methods: Dictionary = {}
# var _triggered_events: Dictionary = {}
# var _active_sub_contexts: Dictionary = {}

# 性能优化
# var _property_batch_updates: Dictionary = {}
# var _last_processed_time: float = -1.0
# var _track_cache_valid: bool = false
```

保留 `timeline_resource` 和 `_timeline_states`，以及调试和性能统计相关的成员变量。

**Step 2: 运行语法检查**

Run: `E:\Godot\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64.exe --headless --check-only --quit`
Expected: 无语法错误

**Step 3: 运行完整的项目验证**

Run: `E:\Godot\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64.exe --headless --validate-translations --quit`
Expected: 无验证错误

**Step 4: 提交**

```bash
git add addons/juicy_mixer/drivers/juicy_timeline_driver.gd
git commit -m "refactor(timeline): remove obsolete member variables after state migration"
```

---

### Task 9: 创建多播放测试场景

**文件:**
- Create: `addons/juicy_mixer/tests/test_timeline_multiplay.tscn`
- Create: `addons/juicy_mixer/tests/test_timeline_multiplay.gd`

**Step 1: 创建测试脚本**

```gdscript
# test_timeline_multiplay.gd
extends Node

## 测试 Timeline 多播放状态隔离
## 验证多个对象同时播放相同 Timeline 时不会互相干扰

var timeline_resource: JuicyTimelineResource
var enemy1: Sprite2D
var enemy2: Sprite2D
var context_id1: String = ""
var context_id2: String = ""

func _ready():
	print("=== Timeline 多播放测试开始 ===")

	# 创建测试对象
	_setup_test_scene()

	# 创建 Timeline 资源
	_create_test_timeline()

	# 等待一帧后开始测试
	await get_tree().process_frame
	_start_test()

func _setup_test_scene():
	"""创建测试场景"""
	# 敌人1 - 红色
	enemy1 = Sprite2D.new()
	enemy1.position = Vector2(200, 300)
	var texture1 = Texture2D.new()
	enemy1.modulate = Color.RED
	add_child(enemy1)

	# 敌人2 - 蓝色
	enemy2 = Sprite2D.new()
	enemy2.position = Vector2(600, 300)
	var texture2 = Texture2D.new()
	enemy2.modulate = Color.BLUE
	add_child(enemy2)

	print("测试场景创建完成")

func _create_test_timeline():
	"""创建测试 Timeline 资源"""
	timeline_resource = JuicyTimelineResource.new()
	timeline_resource.resource_name = "TestMultiplayTimeline"
	timeline_resource.timeline_duration = 2.0

	# 添加位置震动轨道
	var shake_track = ShakeTrack.new()
	shake_track.track_name = "PositionShake"
	shake_track.property = "position"
	shake_track.start_time = 0.0
	shake_track.duration = 2.0

	var shake_data = ShakeData.new()
	shake_data.property = "position"
	shake_data.amplitude = 20.0
	shake_data.frequency = 10.0
	shake_data.duration = 2.0

	shake_track.shake_data = [shake_data]
	timeline_resource.add_track(shake_track)

	print("Timeline 资源创建完成")

func _start_test():
	"""开始测试"""
	print("\n--- 同时播放 Timeline ---")

	# 同时播放相同的 Timeline
	context_id1 = JuicyMixer.play(timeline_resource, enemy1)
	context_id2 = JuicyMixer.play(timeline_resource, enemy2)

	print("敌人1 Context ID: ", context_id1)
	print("敌人2 Context ID: ", context_id2)

	# 等待一段时间后检查状态
	await get_tree().create_timer(0.5).timeout
	_check_states()

	# 继续等待
	await get_tree().create_timer(1.0).timeout
	_final_verification()

func _check_states():
	"""检查两个播放的状态是否独立"""
	print("\n--- 检查状态隔离（0.5秒后） ---")

	var context1 = JuicyMixer.get_context(context_id1)
	var context2 = JuicyMixer.get_context(context_id2)

	if context1 and context2:
		var driver1 = context1.get_driver()
		var driver2 = context2.get_driver()

		if driver1 and driver2 is JuicyTimelineDriver:
			var time1 = driver1.get_debug_info(context1).current_time
			var time2 = driver2.get_debug_info(context2).current_time

			print("敌人1 Timeline 时间: ", time1)
			print("敌人2 Timeline 时间: ", time2)

			# 验证时间应该不同（因为随机性和微小的时间差）
			if abs(time1 - time2) > 0.001:
				print("✅ 时间隔离成功：两个播放的时间不同")
			else:
				print("⚠️ 警告：两个播放的时间相同")

func _final_verification():
	"""最终验证"""
	print("\n--- 最终验证 ---")

	var context1 = JuicyMixer.get_context(context_id1)
	var context2 = JuicyMixer.get_context(context_id2)

	if context1 and context2:
		var state1 = driver1.get_debug_info(context1)
		var state2 = driver2.get_debug_info(context2)

		print("敌人1 最终位置: ", enemy1.position)
		print("敌人2 最终位置: ", enemy2.position)

		# 验证两个敌人的位置应该不同（震动轨迹不同）
		var distance = enemy1.position.distance_to(enemy2.position)
		print("两个敌人之间的距离: ", distance)

		if distance > 1.0:
			print("✅ 状态隔离成功：两个播放独立运行")
		else:
			print("❌ 状态污染：两个播放可能共享了状态")

	print("\n=== 测试完成 ===")

	# 停止播放
	JuicyMixer.stop(context_id1)
	JuicyMixer.stop(context_id2)
```

**Step 2: 创建测试场景**

创建场景文件或在编辑器中手动创建：
- 根节点：Node（脚本：test_timeline_multiplay.gd）

**Step 3: 运行测试**

Run: 在 Godot 编辑器中打开 `test_timeline_multiplay.tscn` 并按 F5 运行
Expected: 控制台输出显示两个播放的时间不同，最终位置不同

**Step 4: 提交**

```bash
git add addons/juicy_mixer/tests/test_timeline_multiplay.tscn
git add addons/juicy_mixer/tests/test_timeline_multiplay.gd
git commit -m "test(timeline): add multi-play state isolation test"
```

---

## Phase 2: 修复 JuicyShakeDriver（中优先级）

### Task 10: 移除噪声生成器缓存

**文件:**
- Modify: `addons/juicy_mixer/drivers/juicy_shake_driver.gd:72,224-248`

**Step 1: 删除 _noise_generators 成员变量**

```gdscript
# ❌ 删除
# var _noise_generators: Dictionary = {}
```

**Step 2: 修改 _initialize_noise_generators()**

```gdscript
func _initialize_noise_generators(context: JuicyContext) -> void:
	"""
	初始化噪声生成器（不再缓存）

	@param context: JuicyContext实例
	"""
	# ✅ 不再缓存噪声生成器，每次都创建新的
	# 这样每个播放都有独立的噪声序列
	pass
```

**Step 3: 添加 _create_noise_generator() 方法**

```gdscript
func _create_noise_generator(config: ShakeConfig, context_id: String) -> FastNoiseLite:
	"""
	创建独立的噪声生成器

	@param config: 震动配置
	@param context_id: 上下文ID（用于生成随机种子）
	@return: 新的噪声生成器实例
	"""
	var noise = FastNoiseLite.new()

	# 配置噪声参数
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	# 使用 context_id 作为种子的一部分，确保每个播放有不同的噪声
	var seed = config.noise_seed if config.noise_seed > 0 else hash(context_id + str(randi()))
	noise.seed = seed
	noise.frequency = config.frequency * 0.1  # 缩放频率以适应噪声生成

	# 配置分形参数（用于八度音效果）
	if config.octaves > 1:
		noise.fractal_type = FastNoiseLite.FRACTAL_FBM
		noise.fractal_octaves = config.octaves
		noise.fractal_gain = config.persistence
		noise.fractal_lacunarity = config.lacunarity

	return noise
```

**Step 4: 修改 process() 方法**

```gdscript
func process(context: JuicyContext, delta: float, buffer: JuicyPropertyBuffer) -> void:
	"""
	处理震动效果，每帧调用

	@param context: JuicyContext实例，包含效果运行所需的所有数据
	@param delta: 时间增量（秒）
	@param buffer: JuicyPropertyBuffer实例，用于写入属性值
	"""
	var start_time = _start_execution_timer()

	# 使用基类时间管理
	var effective_delta = _update_driver_time(context, delta)

	# 检查是否所有震动属性都已完成
	var all_properties_complete = true

	# 处理每个震动属性
	for property in shake_properties.keys():
		var config = shake_properties[property]
		var state = _get_shake_state(context, property)

		# ✅ 每次创建新的噪声生成器
		var noise = _create_noise_generator(config, context.context_id)

		# 检查是否完成（使用基类时间）
		if not _is_time_based_complete(context, config.duration):
			all_properties_complete = false
		else:
			continue

		# 计算进度（使用基类时间）
		var progress = _get_driver_elapsed_time(context) / config.duration

		# 计算衰减系数
		var falloff_factor = _calculate_falloff_factor(progress, config)

		if falloff_factor <= 0.0:
			continue

		# 生成噪声值（使用基类时间管理）
		var noise_value = _generate_noise_value(noise, _get_driver_elapsed_time(context), config, property)

		# 应用振幅和衰减
		var shake_offset = _apply_amplitude_and_falloff(noise_value, config.amplitude, falloff_factor, property)

		# 计算偏移量差值
		var offset_delta = _calculate_offset_delta(state.last_offset, shake_offset, property)

		# 更新状态
		state.last_offset = shake_offset

		# 写入缓冲区（使用ADDITIVE混合模式）
		_add_property_sample(buffer, context, property, offset_delta, JuicyPropertyBuffer.BlendMode.ADDITIVE)

	# 如果所有属性都已完成，标记上下文为完成
	if all_properties_complete:
		print("JuicyShakeDriver: [DEBUG] All shake properties completed, calling context.complete() for context ", context.context_id)
		context.complete()

	_end_execution_timer(start_time)
```

**Step 5: 运行语法检查**

Run: `E:\Godot\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64.exe --headless --check-only --quit`
Expected: 无语法错误

**Step 6: 提交**

```bash
git add addons/juicy_mixer/drivers/juicy_shake_driver.gd
git commit -m "refactor(shake): remove noise generator cache for better randomness"
```

---

## Phase 3: 更新文档

### Task 11: 更新审计报告

**文件:**
- Modify: `docs/analysis/juicy_mixer_driver_state_pollution_audit.md`

**Step 1: 更新状态**

在审计报告的开头添加修复状态：

```markdown
# JuicyMixer Driver 状态污染审计报告

**日期**: 2026-02-03
**审计范围**: 所有 JuicyMixer Driver
**严重程度**: 高 - 发现多个潜在问题
**修复状态**: ✅ 已完成

## 修复状态

| Driver | 状态隔离 | 修复状态 | 修复日期 |
|--------|---------|---------|---------|
| **JuicyTimelineDriver** | ✅ | ✅ 已修复 | 2026-02-03 |
| **JuicyShakeDriver** | ✅ | ✅ 已修复 | 2026-02-03 |
| **JuicyAnimationPlayDriver** | ✅ | 无需修复 | - |
| **JuicyCompositeDriver** | ✅ | 无需修复 | - |
| **JuicySpringDriver** | ✅ | 无需修复 | - |
| **JuicyTweenDriver** | ✅ | 无需修复 | - |
| **JuicyDriver** (基类) | ✅ | 无需修复 | - |
```

**Step 2: 提交**

```bash
git add docs/analysis/juicy_mixer_driver_state_pollution_audit.md
git commit -m "docs(audit): update audit report with fix status"
```

---

### Task 12: 创建修复完成报告

**文件:**
- Create: `docs/plans/2025-02-03-juicy-mixer-driver-state-pollution-fix-complete.md`

**Step 1: 创建完成报告**

```markdown
# JuicyMixer Driver 状态污染修复完成报告

**日期**: 2026-02-03
**修复范围**: JuicyTimelineDriver, JuicyShakeDriver
**影响**: 确保多个播放可以独立运行而不互相干扰

## 修复摘要

### 高优先级修复：JuicyTimelineDriver

**问题**: 运行时状态存储在成员变量中，导致多个播放共享状态

**修复方案**: 实现 TimelineState 内部类，按 context_id 隔离状态

**修复内容**:
1. 创建 TimelineState 内部类包含所有运行时状态
2. 修改 prepare() 创建独立状态
3. 修改 process() 访问隔离状态
4. 修改 cleanup() 清理隔离状态
5. 更新所有辅助方法接受 state 参数
6. 更新公共接口接受 context 参数

**测试**: 创建多播放测试场景验证状态隔离

### 中优先级修复：JuicyShakeDriver

**问题**: 噪声生成器缓存导致多个播放共享相同的噪声实例

**修复方案**: 移除缓存，每次创建新的噪声生成器

**修复内容**:
1. 删除 _noise_generators 成员变量
2. 添加 _create_noise_generator() 方法
3. 修改 process() 每次创建新的噪声生成器
4. 使用 context_id 生成不同的随机种子

## 影响分析

### 兼容性
- **公共 API 变化**: 部分公共方法现在需要 context 参数
- **行为变化**: 多个播放现在完全独立，不会互相干扰
- **性能影响**: 最小化（额外的字典查找）

### 测试覆盖
- ✅ 多播放状态隔离测试
- ✅ 语法检查通过
- ✅ 项目验证通过

## 后续工作

### 低优先级
1. 检查 Middleware 是否有类似问题
2. 添加更多多播放测试场景
3. 性能基准测试

## 参考文档
- [修复计划](./2025-02-03-juicy-mixer-driver-state-pollution-fix.md)
- [审计报告](../analysis/juicy_mixer_driver_state_pollution_audit.md)
- [详细分析](../analysis/juicy_mixer_state_pollution_analysis.md)
```

**Step 2: 提交**

```bash
git add docs/plans/2025-02-03-juicy-mixer-driver-state-pollution-fix-complete.md
git commit -m "docs: add state pollution fix completion report"
```

---

## 验证清单

在完成所有任务后，运行以下验证：

### 1. 语法检查
```bash
E:\Godot\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64.exe --headless --check-only --quit
```
Expected: 无错误

### 2. 项目验证
```bash
E:\Godot\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64.exe --headless --validate-translations --quit
```
Expected: 无错误

### 3. 多播放测试
在 Godot 编辑器中运行 `test_timeline_multiplay.tscn`
Expected:
- 两个播放的时间不同
- 两个敌人的最终位置不同
- 控制台显示 "✅ 状态隔离成功"

### 4. 代码审查
使用 code-reviewer agent 检查修改：
```
/agent code-reviewer addons/juicy_mixer/drivers/juicy_timeline_driver.gd
/agent code-reviewer addons/juicy_mixer/drivers/juicy_shake_driver.gd
```

---

## 故障排除

### 问题：语法错误
- 检查所有方法签名是否更新
- 确保所有状态访问都通过 state 对象

### 问题：运行时错误
- 检查 state 是否为 null
- 确保在 prepare() 中创建了 state

### 问题：测试失败
- 检查两个播放的 context_id 是否不同
- 验证 Timeline 资源是否正确创建
- 确认目标节点存在

---

## 总结

本修复计划解决了 JuicyMixer Driver 中的状态污染问题，确保多个播放可以完全独立运行。主要工作包括：

1. **JuicyTimelineDriver**: 实现完整的状态隔离机制
2. **JuicyShakeDriver**: 改善噪声生成器的随机性
3. **测试覆盖**: 添加多播放测试场景
4. **文档更新**: 更新审计报告和完成报告

修复后，JuicyMixer 系统的行为与 Bricks 系统的 RuntimeInstance 模式一致，每个播放都有完全独立的状态。
