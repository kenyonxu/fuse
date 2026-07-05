# Method Track 交互增强实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 为 JuicyMethodTrack 在 TimelineCanvas 中添加拖拽移动、选中高亮和重复触发可视化功能

**Architecture:** 在 TimelineCanvas 中新增 Method Track 交互状态变量，实现位置检测、拖拽处理和重写绘制函数，复用现有的时间吸附和关键帧图标系统

**Tech Stack:** Godot 4.5, GDScript 2.0, EditorInterface, EditorTheme

---

## Task 1: 添加 Method Track 交互状态变量

**Files:**
- Modify: `addons/juicy_mixer/editor/juicy_timeline_canvas.gd` (在 Clip 交互状态变量后添加)

**Step 1: 添加状态变量**

在 `juicy_timeline_canvas.gd` 第 45 行（`selected_clip` 之后）添加以下代码:

```gdscript
# Method Track 交互状态
var selected_method_track: JuicyMethodTrack = null  # 当前选中的Method Track
var method_track_drag_mode: int = 0                  # 0=无, 1=移动触发时间
var method_track_drag_start_data: Dictionary          # 保存拖拽开始时的数据
```

**Step 2: 验证语法**

打开 Godot 编辑器，检查 `juicy_timeline_canvas.gd` 是否有语法错误。

**Step 3: Commit**

```bash
git add addons/juicy_mixer/editor/juicy_timeline_canvas.gd
git commit -m "feat(method-track): 添加交互状态变量"
```

---

## Task 2: 实现 Method Track 位置检测函数

**Files:**
- Modify: `addons/juicy_mixer/editor/juicy_timeline_canvas.gd` (在 `_get_clip_at_position()` 后添加)

**Step 1: 实现位置检测函数**

在 `juicy_timeline_canvas.gd` 第 1820 行（`_get_clip_at_position()` 函数后）添加以下函数:

```gdscript
# Method Track 交互相关函数
func _get_method_track_at_position(pos: Vector2) -> Dictionary:
	"""返回 {track: JuicyMethodTrack, region: int}
	region: 0=标记主体

	检测 Method Track 标记是否被点击
	"""
	var track_index = _get_track_at_position(pos.y)
	if track_index < 0:
		return {track = null, region = -1}

	var track = _get_track_by_index(track_index)
	if not track or track.get_track_type() != "Method":
		return {track = null, region = -1}

	var method_track = track as JuicyMethodTrack
	var marker_x = _time_to_screen(method_track.trigger_time)

	# 扩展检测范围，提高可点击性
	var hit_width = 12.0

	if pos.x >= marker_x - hit_width and pos.x <= marker_x + hit_width:
		return {track = method_track, region = 0}

	return {track = null, region = -1}
```

**Step 2: 验证语法**

在 Godot 编辑器中检查语法。

**Step 3: Commit**

```bash
git add addons/juicy_mixer/editor/juicy_timeline_canvas.gd
git commit -m "feat(method-track): 实现位置检测函数"
```

---

## Task 3: 实现触发时间计算函数

**Files:**
- Modify: `addons/juicy_mixer/editor/juicy_timeline_canvas.gd` (在上一个函数后添加)

**Step 1: 实现触发时间计算函数**

在 `_get_method_track_at_position()` 函数后添加:

```gdscript
func _calculate_method_trigger_times(track: JuicyMethodTrack) -> Array[float]:
	"""计算 Method Track 的所有触发时间点（包括重复触发）"""
	var times: Array[float] = []

	# 主触发时间
	times.append(track.trigger_time)

	# 如果有重复间隔，计算重复触发时间
	if track.repeat_interval > 0.0:
		var max_count = track.max_repeats if track.max_repeats > 0 else 100
		var current_time = track.trigger_time

		for i in range(1, max_count + 1):
			current_time += track.repeat_interval
			# 限制在合理范围内
			if current_time > 3600.0:  # 最多1小时
				break
			times.append(current_time)

	return times
```

**Step 2: 验证语法**

在 Godot 编辑器中检查语法。

**Step 3: Commit**

```bash
git add addons/juicy_mixer/editor/juicy_timeline_canvas.gd
git commit -m "feat(method-track): 实现触发时间计算函数"
```

---

## Task 4: 实现重复触发标记绘制函数

**Files:**
- Modify: `addons/juicy_mixer/editor/juicy_timeline_canvas.gd` (在上一个函数后添加)

**Step 1: 实现重复触发标记绘制**

在 `_calculate_method_trigger_times()` 函数后添加:

```gdscript
func _draw_repeat_method_marker(x: float, y: float, track_rect: Rect2):
	"""绘制重复触发标记（弱化视觉，不可拖拽）"""
	var marker_size = 8.0
	var marker_rect = Rect2(x - marker_size/2, y - marker_size/2, marker_size, marker_size)

	# 半透明紫色，表示这是重复触发
	var color = Color(0.8, 0.2, 0.8, 0.4)
	draw_rect(marker_rect, color)
```

**Step 2: 验证语法**

在 Godot 编辑器中检查语法。

**Step 3: Commit**

```bash
git add addons/juicy_mixer/editor/juicy_timeline_canvas.gd
git commit -m "feat(method-track): 实现重复触发标记绘制"
```

---

## Task 5: 实现主触发点绘制函数

**Files:**
- Modify: `addons/juicy_mixer/editor/juicy_timeline_canvas.gd` (在上一个函数后添加)

**Step 1: 实现主触发点绘制**

在 `_draw_repeat_method_marker()` 函数后添加:

```gdscript
func _draw_primary_method_trigger(track: JuicyMethodTrack, x: float, y: float, track_rect: Rect2):
	"""绘制主触发点（可拖拽）"""
	var editor_interface = Engine.get_singleton("EditorInterface")
	var editor_theme = editor_interface.get_editor_theme()

	var is_selected = (track == selected_method_track)
	var icon: Texture2D = null

	# 根据选中状态选择图标
	if editor_theme:
		if is_selected:
			icon = editor_theme.get_icon("KeySelected", "EditorIcons")
		else:
			icon = editor_theme.get_icon("KeyBezierPoint", "EditorIcons")

	# 计算图标尺寸
	var icon_size = 16.0 * max(0.75, min(1.5, zoom_level))
	var icon_rect = Rect2(x - icon_size/2, y - icon_size/2, icon_size, icon_size)

	# 绘制图标
	if icon:
		draw_texture_rect(icon, icon_rect, false)
	else:
		# 备选方案：绘制钻石形状
		var points = PackedVector2Array([
			Vector2(x, y - icon_size/2),
			Vector2(x + icon_size/2, y),
			Vector2(x, y + icon_size/2),
			Vector2(x - icon_size/2, y)
		])
		var color = Color.YELLOW if is_selected else Color.MAGENTA
		draw_colored_polygon(points, color)

	# 绘制方法名
	if not track.method_name.is_empty():
		var text_pos = Vector2(x + icon_size/2 + 4, track_rect.position.y + 10)
		draw_string(ThemeDB.fallback_font, text_pos, track.method_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)

		# 选中时显示额外信息
		if is_selected:
			# 显示触发时间
			var time_text = "%.2fs" % track.trigger_time
			var time_pos = Vector2(x + icon_size/2 + 4, track_rect.position.y + 22)
			draw_string(ThemeDB.fallback_font, time_pos, time_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.CYAN)

			# 如果有重复间隔，显示重复信息
			if track.repeat_interval > 0.0:
				var repeat_text = "每 %.2fs 重复" % track.repeat_interval
				if track.max_repeats > 0:
					repeat_text += " (最多%d次)" % track.max_repeats
				var repeat_pos = Vector2(x + icon_size/2 + 4, track_rect.position.y + 34)
				draw_string(ThemeDB.fallback_font, repeat_pos, repeat_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.GRAY)
```

**Step 2: 验证语法**

在 Godot 编辑器中检查语法。

**Step 3: Commit**

```bash
git add addons/juicy_mixer/editor/juicy_timeline_canvas.gd
git commit -m "feat(method-track): 实现主触发点绘制"
```

---

## Task 6: 重写 Method Track 绘制函数

**Files:**
- Modify: `addons/juicy_mixer/editor/juicy_timeline_canvas.gd` (替换现有的 `_draw_method_track()`)

**Step 1: 替换现有绘制函数**

找到现有的 `_draw_method_track()` 函数（约第 1037-1058 行），完全替换为:

```gdscript
func _draw_method_track(track: JuicyTrack, track_rect: Rect2):
	if not track is JuicyMethodTrack:
		return

	var method_track = track as JuicyMethodTrack

	# 可见性检查
	var track_visible = track_rect.position.y + track_rect.size.y > 0 and track_rect.position.y < size.y
	if not track_visible:
		return

	# 计算所有触发时间点
	var trigger_times = _calculate_method_trigger_times(method_track)

	for i in range(trigger_times.size()):
		var trigger_time = trigger_times[i]
		var x = _time_to_screen(trigger_time)

		# 只有当标记在可见区域内时才绘制
		if x >= 0 and x <= size.x:
			var y = track_rect.position.y + track_rect.size.y / 2
			var is_primary = (i == 0)  # 第一个是主触发点

			if is_primary:
				# 主触发点：绘制可拖拽图标 + 详细信息
				_draw_primary_method_trigger(method_track, x, y, track_rect)
			else:
				# 重复触发点：绘制弱化标记
				_draw_repeat_method_marker(x, y, track_rect)
```

**Step 2: 验证语法**

在 Godot 编辑器中检查语法。

**Step 3: Commit**

```bash
git add addons/juicy_mixer/editor/juicy_timeline_canvas.gd
git commit -m "feat(method-track): 重写绘制函数支持重复触发可视化"
```

---

## Task 7: 实现点击选择处理函数

**Files:**
- Modify: `addons/juicy_mixer/editor/juicy_timeline_canvas.gd` (在 Clip 交互函数后添加)

**Step 1: 实现点击选择处理**

在 `_handle_clip_selection()` 函数后添加:

```gdscript
func _handle_method_track_selection(track: JuicyMethodTrack, pos: Vector2):
	"""处理 Method Track 的选择"""
	selected_method_track = track
	selected_track = track
	selected_clip = null  # 清除 Clip 选择
	selected_keyframe = null

	is_dragging = true
	drag_start_pos = pos
	method_track_drag_mode = 1  # 移动触发时间

	# 保存拖拽开始时的数据
	method_track_drag_start_data = {
		"trigger_time": track.trigger_time,
		"original_track": track
	}

	track_selected.emit(track)
	queue_redraw()
```

**Step 2: 验证语法**

在 Godot 编辑器中检查语法。

**Step 3: Commit**

```bash
git add addons/juicy_mixer/editor/juicy_timeline_canvas.gd
git commit -m "feat(method-track): 实现点击选择处理"
```

---

## Task 8: 实现拖拽处理函数

**Files:**
- Modify: `addons/juicy_mixer/editor/juicy_timeline_canvas.gd` (在上一个函数后添加)

**Step 1: 实现拖拽和释放函数**

在 `_handle_method_track_selection()` 函数后添加:

```gdscript
func _handle_method_track_drag(pos: Vector2):
	"""处理 Method Track 的拖拽"""
	if not selected_method_track:
		return

	var new_time = _screen_to_time(pos.x)

	# 应用时间吸附
	if snap_enabled:
		new_time = _snap_time(new_time)

	selected_method_track.trigger_time = max(0.0, new_time)
	timeline_changed.emit()
	queue_redraw()

func _handle_method_track_release():
	"""处理 Method Track 的拖拽释放"""
	if selected_method_track:
		selected_method_track.trigger_time = max(0.0, selected_method_track.trigger_time)

	method_track_drag_mode = 0
	method_track_drag_start_data.clear()

	timeline_changed.emit()
	queue_redraw()
```

**Step 2: 验证语法**

在 Godot 编辑器中检查语法。

**Step 3: Commit**

```bash
git add addons/juicy_mixer/editor/juicy_timeline_canvas.gd
git commit -m "feat(method-track): 实现拖拽处理函数"
```

---

## Task 9: 修改点击处理集成 Method Track 检测

**Files:**
- Modify: `addons/juicy_mixer/editor/juicy_timeline_canvas.gd` (修改 `_handle_left_click()` 函数)

**Step 1: 修改 _handle_left_click 函数**

找到 `_handle_left_click()` 函数（约第 289-406 行），在 Property Track 时间范围检测之后（约第 309 行）添加以下代码:

```gdscript
	# 🔥 Method Track: 优先检查 Method Track 标记交互
	var method_result = _get_method_track_at_position(pos)
	if method_result.track:
		print("Method Track 标记交互被触发 - 轨道: ", method_result.track.track_name)
		_handle_method_track_selection(method_result.track, pos)
		return
```

**Step 2: 验证语法**

在 Godot 编辑器中检查语法。

**Step 3: Commit**

```bash
git add addons/juicy_mixer/editor/juicy_timeline_canvas.gd
git commit -m "feat(method-track): 集成点击检测到主处理流程"
```

---

## Task 10: 修改鼠标移动处理集成拖拽

**Files:**
- Modify: `addons/juicy_mixer/editor/juicy_timeline_canvas.gd` (修改 `_handle_mouse_motion()` 函数)

**Step 1: 修改 _handle_mouse_motion 函数**

找到 `_handle_mouse_motion()` 函数（约第 115-219 行），在 Property Track 时间范围拖拽逻辑之后（约第 188 行）添加以下代码:

```gdscript
	# 🔥 Method Track: 拖拽逻辑
	if is_dragging and selected_method_track and method_track_drag_mode > 0:
		_handle_method_track_drag(event.position)
		return
```

**Step 2: 验证语法**

在 Godot 编辑器中检查语法。

**Step 3: Commit**

```bash
git add addons/juicy_mixer/editor/juicy_timeline_canvas.gd
git commit -m "feat(method-track): 集成拖拽处理到鼠标移动流程"
```

---

## Task 11: 修改释放处理集成清理

**Files:**
- Modify: `addons/juicy_mixer/editor/juicy_timeline_canvas.gd` (修改 `_handle_left_release()` 函数)

**Step 1: 修改 _handle_left_release 函数**

找到 `_handle_left_release()` 函数（约第 407-435 行），在 Property Track 时间范围释放处理之后（约第 428 行）添加以下代码:

```gdscript
	# 🔥 Method Track: 拖拽释放处理
	if is_dragging and selected_method_track and method_track_drag_mode > 0:
		_handle_method_track_release()
```

**Step 2: 验证语法**

在 Godot 编辑器中检查语法。

**Step 3: Commit**

```bash
git add addons/juicy_mixer/editor/juicy_timeline_canvas.gd
git commit -m "feat(method-track): 集成释放处理到主流程"
```

---

## Task 12: 测试基础功能

**Files:**
- Test: 在 Godot 编辑器中手动测试

**Step 1: 测试图标显示**

1. 打开 Godot 编辑器
2. 打开包含 Method Track 的 Timeline 场景
3. 观察 Method Track 是否显示 KeyBezierPoint 图标
4. 检查方法名是否正确显示

**预期结果**: Method Track 显示紫色图标和方法名

**Step 2: 测试选中高亮**

1. 点击 Method Track 图标
2. 观察图标是否变为 KeySelected（黄色）
3. 检查是否显示触发时间和重复间隔信息

**预期结果**: 图标变黄色，显示额外信息

**Step 3: 测试拖拽移动**

1. 点击并拖动 Method Track 图标
2. 观察图标是否跟随鼠标移动
3. 释放鼠标，检查 trigger_time 是否更新

**预期结果**: 图标跟随鼠标，trigger_time 正确更新

**Step 4: 测试时间吸附**

1. 启用网格吸附（snap_enabled）
2. 拖动 Method Track 图标
3. 观察是否吸附到网格间隔

**预期结果**: 图标移动时吸附到网格

**Step 5: 测试重复触发显示**

1. 创建一个 Method Track，设置 repeat_interval = 1.0, max_repeats = 3
2. 观察是否显示主触发点和重复触发标记

**预期结果**: 显示 1 个主图标 + 3 个弱化标记

**Step 6: Commit 测试结果**

```bash
# 如果测试通过，添加完成标记
git add docs/plans/2025-01-13-method-track-interaction-implementation.md
git commit -m "test(method-track): 完成基础功能测试"
```

---

## Task 13: 边界情况测试

**Files:**
- Test: 在 Godot 编辑器中手动测试

**Step 1: 测试边界值**

1. 设置 trigger_time = 0.0，测试是否能正确显示
2. 拖动到负值，测试是否被限制为 0
3. 设置很大的 trigger_time，测试是否能正确显示

**预期结果**: 边界值正确处理

**Step 2: 测试多个 Method Track**

1. 创建多个 Method Track
2. 点击选择不同的 Track
3. 验证只有当前 Track 被高亮

**预期结果**: 选中状态正确切换

**Step 3: 测试与其他 Track 的交互**

1. 同时包含 Method、Property、Feedback Track
2. 点击不同类型的 Track
3. 验证选择状态不会冲突

**预期结果**: 不同类型 Track 可以正常切换选择

**Step 4: Commit 测试结果**

```bash
git add docs/plans/2025-01-13-method-track-interaction-implementation.md
git commit -m "test(method-track): 完成边界情况测试"
```

---

## 完成检查清单

- [ ] Task 1: 添加状态变量
- [ ] Task 2: 实现位置检测函数
- [ ] Task 3: 实现触发时间计算函数
- [ ] Task 4: 实现重复触发标记绘制
- [ ] Task 5: 实现主触发点绘制
- [ ] Task 6: 重写绘制函数
- [ ] Task 7: 实现点击选择处理
- [ ] Task 8: 实现拖拽处理函数
- [ ] Task 9: 修改点击处理集成
- [ ] Task 10: 修改鼠标移动处理集成
- [ ] Task 11: 修改释放处理集成
- [ ] Task 12: 基础功能测试
- [ ] Task 13: 边界情况测试

---

## 相关文档

- 设计文档: `docs/plans/2025-01-13-method-track-interaction-design.md`
- JuicyMethodTrack: `addons/juicy_mixer/resources/juicy_method_track.gd`
- TimelineCanvas: `addons/juicy_mixer/editor/juicy_timeline_canvas.gd`
