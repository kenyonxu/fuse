# 基于现有Timeline Canvas的可视化Clip增强方案

## 现有架构分析

### 1. 当前Timeline Canvas的优势

现有的 [`juicy_timeline_canvas.gd`](addons/juicy_mixer/editor/juicy_timeline_canvas.gd) 已经具备了良好的基础架构：

#### 核心功能完备
- **完整的绘制系统**：背景、网格、轨道、播放头
- **交互处理**：鼠标点击、拖拽、右键菜单
- **坐标转换**：时间与屏幕坐标的双向转换
- **吸附功能**：时间吸附和网格对齐
- **选择系统**：轨道和关键帧的选择状态管理

#### 模块化设计
- **分层绘制**：`_draw_tracks()` → `_draw_track_content()` → 具体轨道绘制
- **类型匹配**：通过 `track.get_track_type()` 进行分发处理
- **事件处理**：清晰的输入事件分发机制

#### 扩展性良好
- **信号系统**：`timeline_changed()`, `track_selected()`, `keyframe_selected()` 等
- **配置参数**：颜色、尺寸、间距等可配置
- **公共接口**：完善的设置和获取方法

### 2. 现有Feedback Track绘制分析

当前 `_draw_feedback_track()` 函数（第338-354行）已经实现了基本的Clip绘制：

```gdscript
func _draw_feedback_track(track: JuicyTrack, track_rect: Rect2):
    if not track is JuicyFeedbackTrack:
        return
    
    var feedback_track = track as JuicyFeedbackTrack
    
    # 绘制反馈块
    var start_x = _time_to_screen(feedback_track.start_time)
    var duration = feedback_track.get_actual_duration()
    var end_x = _time_to_screen(feedback_track.start_time + duration)
    var block_rect = Rect2(start_x, track_rect.position.y + 2, end_x - start_x, track_rect.size.y - 4)
    draw_rect(block_rect, Color.ORANGE)
    
    # 绘制反馈类型标签
    if feedback_track.resource:
        var label = feedback_track.resource.get_class()
        draw_string(ThemeDB.fallback_font, block_rect.position + Vector2(2, 12), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)
```

这个实现已经具备了Clip的基本形态，但缺少交互功能。

## 增强方案设计

### 1. 设计原则

基于现有架构，我们采用**渐进式增强**的策略：

1. **保持向后兼容**：现有功能完全保留
2. **最小侵入性**：尽量复用现有代码结构
3. **模块化扩展**：新功能作为现有功能的增强
4. **统一交互模式**：Clip交互与关键帧交互保持一致

### 2. 核心增强点

#### 2.1 交互状态扩展

在现有的交互状态基础上添加Clip相关状态：

```gdscript
# 现有交互状态
var is_dragging: bool = false
var drag_start_pos: Vector2
var drag_start_time: float
var selected_track: JuicyTrack
var selected_keyframe: JuicyKeyframe

# 新增Clip交互状态
var selected_clip: JuicyTrack  # 当前选中的Clip（Feedback Track）
var clip_drag_mode: int = 0     # Clip拖拽模式：0=无, 1=移动, 2=左边界, 3=右边界
var clip_drag_start_data: Dictionary  # Clip拖拽开始时的数据
```

#### 2.2 鼠标交互增强扩展现有的 `_handle_left_click()` 和 `_handle_mouse_motion()` 函数：

```gdscript
func _handle_left_click(pos: Vector2):
    # 优先检查Clip交互
    var clip_result = _get_clip_at_position(pos)
    if clip_result.track:
        _handle_clip_selection(clip_result.track, clip_result.region, pos)
        return
    
    # 现有的关键帧检查逻辑...
    # 现有的轨道选择逻辑...
```

#### 2.3 绘制增强

扩展 `_draw_feedback_track()` 函数，添加交互视觉反馈：

```gdscript
func _draw_feedback_track(track: JuicyTrack, track_rect: Rect2):
    # 现有的基本绘制逻辑...
    
    # 新增：绘制Clip交互元素
    if track == selected_clip:
        _draw_clip_selection(track, block_rect)
    
    # 新增：绘制Clip手柄
    if track == selected_clip or _is_mouse_over_clip(track, block_rect):
        _draw_clip_handles(track, block_rect)
```

### 3. 具体实现方案

#### 3.1 Clip检测函数

```gdscript
# 新增函数：获取位置处的Clip
func _get_clip_at_position(pos: Vector2) -> Dictionary:
    """返回 {track: JuicyTrack, region: int}，region: 0=中间, 1=左边界, 2=右边界"""
    var track_index = _get_track_at_position(pos.y)
    if track_index < 0:
        return {track: null, region: -1}
    
    var track = _get_track_by_index(track_index)
    if not track or track.get_track_type() != "Feedback":
        return {track: null, region: -1}
    
    var feedback_track = track as JuicyFeedbackTrack
    var start_x = _time_to_screen(feedback_track.start_time)
    var duration = feedback_track.get_actual_duration()
    var end_x = _time_to_screen(feedback_track.start_time + duration)
    
    # 检查是否在Clip范围内
    if pos.x < start_x or pos.x > end_x:
        return {track: null, region: -1}
    
    # 检查具体区域（考虑手柄区域）
    var handle_width = 8.0  # 手柄宽度
    if pos.x <= start_x + handle_width:
        return {track: track, region: 1}  # 左边界
    elif pos.x >= end_x - handle_width:
        return {track: track, region: 2}  # 右边界
    else:
        return {track: track, region: 0}  # 中间区域
```

#### 3.2 Clip选择处理

```gdscript
# 新增函数：处理Clip选择
func _handle_clip_selection(track: JuicyTrack, region: int, pos: Vector2):
    selected_clip = track
    selected_track = track
    selected_keyframe = null
    is_dragging = true
    drag_start_pos = pos
    
    # 设置拖拽模式
    match region:
        0: clip_drag_mode = 1  # 移动
        1: clip_drag_mode = 2  # 左边界
        2: clip_drag_mode = 3  # 右边界
    
    # 保存拖拽开始时的数据
    var feedback_track = track as JuicyFeedbackTrack
    clip_drag_start_data = {
        "start_time": feedback_track.start_time,
        "duration": feedback_track.get_actual_duration(),
        "original_track": track
    }
    
    track_selected.emit(track)
    queue_redraw()
```

#### 3.3 鼠标移动处理增强

```gdscript
func _handle_mouse_motion(event: InputEventMouseMotion):
    # 现有的关键帧拖拽逻辑...
    if is_dragging and selected_keyframe:
        # ... 现有代码 ...
        return
    
    # 新增：Clip拖拽逻辑
    if is_dragging and selected_clip and clip_drag_mode > 0:
        _handle_clip_drag(event.position)
        return

# 新增函数：处理Clip拖拽
func _handle_clip_drag(pos: Vector2):
    if not selected_clip or not selected_clip is JuicyFeedbackTrack:
        return
    
    var feedback_track = selected_clip as JuicyFeedbackTrack
    var new_time = _screen_to_time(pos.x)
    if snap_enabled:
        new_time = _snap_time(new_time)
    
    match clip_drag_mode:
        1:  # 移动整个Clip
            var delta_time = new_time - _screen_to_time(drag_start_pos.x)
            feedback_track.start_time = clip_drag_start_data.start_time + delta_time
        2:  # 调整左边界
            feedback_track.start_time = min(new_time, feedback_track.start_time + feedback_track.get_actual_duration() - 0.1)
        3:  # 调整右边界
            var new_duration = new_time - feedback_track.start_time
            if new_duration >= 0.1:
                if feedback_track.duration > 0:
                    feedback_track.duration = new_duration
                # 如果duration为-1（使用资源自身时长），则设置duration
    
    timeline_changed.emit()
    queue_redraw()
```

#### 3.4 绘制增强函数

```gdscript
# 新增函数：绘制Clip选择状态
func _draw_clip_selection(track: JuicyTrack, clip_rect: Rect2):
    # 绘制选择边框
    var border_color = Color.WHITE
    border_color.a = 0.8
    draw_rect(clip_rect.grow(1), border_color, false, 2.0)
    
    # 绘制选择高亮
    var highlight_color = Color.WHITE
    highlight_color.a = 0.1
    draw_rect(clip_rect, highlight_color)

# 新增函数：绘制Clip手柄
func _draw_clip_handles(track: JuicyTrack, clip_rect: Rect2):
    var handle_color = Color.CYAN
    var handle_width = 6.0
    
    # 左手柄
    var left_handle = Rect2(
        clip_rect.position.x - handle_width/2,
        clip_rect.position.y,
        handle_width,
        clip_rect.size.y
    )
    draw_rect(left_handle, handle_color)
    
    # 右手柄
    var right_handle = Rect2(
        clip_rect.position.x + clip_rect.size.x - handle_width/2,
        clip_rect.position.y,
        handle_width,
        clip_rect.size.y
    )
    draw_rect(right_handle, handle_color)

# 新增函数：检查鼠标是否在Clip上
func _is_mouse_over_clip(track: JuicyTrack, clip_rect: Rect2) -> bool:
    var mouse_pos = get_local_mouse_position()
    return clip_rect.has_point(mouse_pos)
```

#### 3.5 释放处理增强

```gdscript
func _handle_left_release():
    # 现有逻辑...
    if is_dragging and selected_keyframe:
        # ... 现有代码 ...
    
    # 新增：Clip拖拽释放处理
    if is_dragging and selected_clip and clip_drag_mode > 0:
        _handle_clip_release()
    
    is_dragging = false

# 新增函数：处理Clip拖拽释放
func _handle_clip_release():
    # 验证Clip的有效性
    if selected_clip and selected_clip is JuicyFeedbackTrack:
        var feedback_track = selected_clip as JuicyFeedbackTrack
        
        # 确保start_time不为负数
        feedback_track.start_time = max(0.0, feedback_track.start_time)
        
        # 确保duration不为负数或过小
        if feedback_track.duration > 0:
            feedback_track.duration = max(0.1, feedback_track.duration)
    
    # 重置Clip拖拽状态
    clip_drag_mode = 0
    clip_drag_start_data.clear()
    
    timeline_changed.emit()
    queue_redraw()
```

### 4. 右键菜单增强

扩展现有的右键菜单，添加Clip相关选项：

```gdscript
func _handle_right_click(pos: Vector2):
    # 现有代码...
    
    var track_index = _get_track_at_position(pos.y)
    if track_index >= 0:
        var track = _get_track_by_index(track_index)
        if track:
            # 检查是否点击了Clip
            var clip_result = _get_clip_at_position(pos)
            if clip_result.track:
                # Clip相关的右键菜单
                context_menu.add_item("复制Clip", 10)
                context_menu.add_item("删除Clip", 11)
                context_menu.add_separator()
                context_menu.add_item("Clip属性...", 12)
            else:
                # 现有的轨道菜单
                context_menu.add_item("添加关键帧", 0)
                context_menu.add_separator()
                context_menu.add_item("删除轨道", 1)
    else:
        context_menu.add_item("添加轨道", 2)
    
    # 现有菜单处理代码...
    context_menu.id_pressed.connect(func(id: int):
        match id:
            # 现有菜单项...
            10: _duplicate_clip(clip_result.track)
            11: _delete_clip(clip_result.track)
            12: _show_clip_properties(clip_result.track)
        # ... 现有代码 ...
    )
```

### 5. 混合模式支持

为了支持传统模式和可视化Clip模式的混合使用，我们可以添加一个模式切换功能：

```gdscript
# 新增：编辑模式
var edit_mode: int = 0  # 0=传统模式, 1=可视化Clip模式

# 新增函数：切换编辑模式
func set_edit_mode(mode: int):
    edit_mode = mode
    queue_redraw()

# 修改绘制函数，根据模式显示不同界面
func _draw_feedback_track(track: JuicyTrack, track_rect: Rect2):
    if not track is JuicyFeedbackTrack:
        return
    
    var feedback_track = track as JuicyFeedbackTrack
    
    match edit_mode:
        0:  # 传统模式
            _draw_feedback_track_traditional(feedback_track, track_rect)
        1:  # 可视化Clip模式
            _draw_feedback_track_visual(feedback_track, track_rect)

func _draw_feedback_track_traditional(track: JuicyFeedbackTrack, track_rect: Rect2):
    # 现有的传统绘制逻辑
    var start_x = _time_to_screen(track.start_time)
    var duration = track.get_actual_duration()
    var end_x = _time_to_screen(track.start_time + duration)
    var block_rect = Rect2(start_x, track_rect.position.y + 2, end_x - start_x, track_rect.size.y - 4)
    draw_rect(block_rect, Color.ORANGE)
    
    if track.resource:
        var label = track.resource.get_class()
        draw_string(ThemeDB.fallback_font, block_rect.position + Vector2(2, 12), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)

func _draw_feedback_track_visual(track: JuicyFeedbackTrack, track_rect: Rect2):
    # 增强的可视化Clip绘制逻辑
    var start_x = _time_to_screen(track.start_time)
    var duration = track.get_actual_duration()
    var end_x = _time_to_screen(track.start_time + duration)
    var block_rect = Rect2(start_x, track_rect.position.y + 2, end_x - start_x, track_rect.size.y - 4)
    
    # 绘制Clip主体
    var clip_color = Color.ORANGE
    if track == selected_clip:
        clip_color = Color.YELLOW
    draw_rect(block_rect, clip_color)
    
    # 绘制Clip内容
    if track.resource:
        var label = track.resource.get_class()
        draw_string(ThemeDB.fallback_font, block_rect.position + Vector2(2, 12), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)
    
    # 绘制交互元素
    if track == selected_clip:
        _draw_clip_selection(track, block_rect)
    
    if track == selected_clip or _is_mouse_over_clip(track, block_rect):
        _draw_clip_handles(track, block_rect)
```

## 实施计划

### 阶段1：基础交互功能
1. 添加Clip检测和选择逻辑
2. 实现基本的Clip拖拽移动
3. 添加Clip选择状态的视觉反馈

### 阶段2：高级交互功能
1. 实现Clip边界调整（左/右手柄）
2. 添加Clip复制和删除功能
3. 完善右键菜单

### 阶段3：混合模式支持
1. 实现编辑模式切换
2. 添加模式切换UI（工具栏按钮）
3. 完善两种模式的同步机制

### 阶段4：优化和完善
1. 性能优化
2. 用户体验改进
3. 错误处理和边界情况

## 优势分析

### 1. 最小侵入性
- 复用现有的绘制系统
- 扩展现有的交互处理
- 保持现有API不变

### 2. 渐进式增强
- 可以分阶段实施
- 每个阶段都是可用的功能
- 便于测试和调试

### 3. 向后兼容
- 传统模式完全保留
- 现有Timeline资源无需修改
- 用户可以选择使用模式

### 4. 一致性
- 交互模式与关键帧保持一致
- 视觉风格与现有界面统一
- 操作逻辑符合用户预期

这种基于现有Canvas的增强方案，既保持了系统的稳定性，又提供了现代化的可视化编辑体验，是一个平衡性很好的解决方案。