# JuicyTimeline 可视化Clip增强方案

## 概述

本文档详细描述了对JuicyTimeline系统的可视化Clip增强方案，旨在解决当前Feedback Track使用`start_time`和`duration`不够直观的问题，提供类似Unity Timeline的直观操作体验。

## 问题分析

### 当前系统的局限性

1. **不直观的时间设置**：用户需要手动计算`start_time`和`duration`
2. **缺乏可视化反馈**：无法直观看到轨道的时间范围
3. **编辑效率低**：调整时间需要输入精确数值
4. **学习成本高**：新用户需要理解抽象的时间概念

### 用户需求

1. **直观的拖拽操作**：直接在时间轴上拖动调整时间
2. **可视化Clip边界**：清楚看到每个轨道的时间范围
3. **灵活的编辑模式**：支持多种编辑方式
4. **向后兼容性**：保持现有API不变

## 解决方案：混合模式轨道系统

### 1. 核心设计理念

**混合模式**：同时支持传统模式和可视化Clip模式，用户可以自由切换。

```gdscript
enum TrackEditMode {
    TRADITIONAL,    # 传统start_time + duration模式
    VISUAL_CLIP     # 可视化Clip拖拽模式
}
```

### 2. 增强的轨道基类

```gdscript
# JuicyEnhancedTrack - 增强的轨道基类
@tool
class_name JuicyEnhancedTrack
extends JuicyTrack

# 编辑模式
@export var edit_mode: TrackEditMode = TrackEditMode.TRADITIONAL

# 传统模式属性
@export var start_time: float = 0.0
@export var duration: float = 1.0

# 可视化Clip模式属性
@export var clip_start: float = 0.0      # Clip开始时间（0-1相对值）
@export var clip_end: float = 1.0        # Clip结束时间（0-1相对值）
@export var clip_color: Color = Color.BLUE  # Clip显示颜色
@export var clip_name: String = "Clip"    # Clip名称

# 编辑器属性
@export var show_clip_handles: bool = true
@export var clip_min_width: float = 50.0
@export var draggable: bool = true

# 时间轴参考
var timeline_duration: float = 1.0

# 模式同步
func sync_edit_modes():
    match edit_mode:
        TrackEditMode.TRADITIONAL:
            clip_start = start_time / timeline_duration
            clip_end = (start_time + duration) / timeline_duration
        TrackEditMode.VISUAL_CLIP:
            start_time = clip_start * timeline_duration
            duration = (clip_end - clip_start) * timeline_duration

# 获取实际时间
func get_actual_start_time() -> float:
    match edit_mode:
        TrackEditMode.TRADITIONAL:
            return start_time
        TrackEditMode.VISUAL_CLIP:
            return clip_start * timeline_duration

func get_actual_end_time() -> float:
    match edit_mode:
        TrackEditMode.TRADITIONAL:
            return start_time + duration
        TrackEditMode.VISUAL_CLIP:
            return clip_end * timeline_duration

func get_actual_duration() -> float:
    match edit_mode:
        TrackEditMode.TRADITIONAL:
            return duration
        TrackEditMode.VISUAL_CLIP:
            return (clip_end - clip_start) * timeline_duration
```

### 3. 可视化Feedback Track实现

```gdscript
# JuicyVisualFeedbackTrack - 可视化反馈轨道
@tool
class_name JuicyVisualFeedbackTrack
extends JuicyEnhancedTrack

# Clip可视化属性
@export var show_clip_preview: bool = true
@export var clip_border_width: float = 2.0
@export var clip_handle_size: float = 8.0

# 拖拽状态
var is_dragging: bool = false
var drag_mode: ClipDragMode = ClipDragMode.NONE
var drag_start_pos: Vector2
var drag_start_time: float

enum ClipDragMode {
    NONE,
    MOVE_CLIP,
    RESIZE_START,
    RESIZE_END
}

# 获取Clip屏幕矩形
func get_clip_screen_rect(timeline_rect: Rect2) -> Rect2:
    var pixels_per_second = timeline_rect.size.x / timeline_duration
    
    var start_x = clip_start * timeline_duration * pixels_per_second
    var end_x = clip_end * timeline_duration * pixels_per_second
    
    var clip_width = max(end_x - start_x, clip_min_width)
    var clip_height = timeline_rect.size.y * 0.8  # 轨道高度的80%
    
    return Rect2(start_x, timeline_rect.size.y * 0.1, clip_width, clip_height)

# 检查点击位置
func get_clip_interaction_at(pos: Vector2, clip_rect: Rect2) -> String:
    var screen_rect = get_clip_screen_rect(clip_rect)
    
    if not screen_rect.has_point(pos):
        return "none"
    
    var handle_size = clip_handle_size
    var left_handle = Rect2(screen_rect.position.x - handle_size/2, 
                          screen_rect.position.y + screen_rect.size.y/2 - handle_size/2, 
                          handle_size, handle_size)
    var right_handle = Rect2(screen_rect.position.x + screen_rect.size.x - handle_size/2,
                           screen_rect.position.y + screen_rect.size.y/2 - handle_size/2,
                           handle_size, handle_size)
    
    if left_handle.has_point(pos):
        return "resize_start"
    elif right_handle.has_point(pos):
        return "resize_end"
    else:
        return "move_clip"

# 编辑器交互处理
func handle_clip_input(event: InputEvent, timeline_rect: Rect2):
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            var interaction = get_clip_interaction_at(event.position, timeline_rect)
            
            match interaction:
                "move_clip", "resize_start", "resize_end":
                    is_dragging = true
                    drag_start_pos = event.position
                    drag_start_time = get_actual_start_time()
                    
                    match interaction:
                        "move_clip":
                            drag_mode = ClipDragMode.MOVE_CLIP
                        "resize_start":
                            drag_mode = ClipDragMode.RESIZE_START
                        "resize_end":
                            drag_mode = ClipDragMode.RESIZE_END
    
    elif event is InputEventMouseMotion and is_dragging:
        var time_delta = (event.position.x - drag_start_pos.x) / (timeline_rect.size.x / timeline_duration)
        
        match drag_mode:
            ClipDragMode.MOVE_CLIP:
                var time_offset = time_delta
                clip_start = max(0.0, min(1.0, clip_start + time_offset))
                clip_end = min(1.0, max(0.0, clip_end + time_offset))
            
            ClipDragMode.RESIZE_START:
                clip_start = max(0.0, min(clip_end, clip_start + time_delta))
            
            ClipDragMode.RESIZE_END:
                clip_end = min(1.0, max(clip_start, clip_end + time_delta))
        
        sync_edit_modes()
    
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
        is_dragging = false
        drag_mode = ClipDragMode.NONE
```

### 4. 增强的Timeline Canvas

```gdscript
# JuicyEnhancedTimelineCanvas - 增强的时间轴画布
@tool
class_name JuicyEnhancedTimelineCanvas
extends Control

# 编辑模式
@export var global_edit_mode: TrackEditMode = TrackEditMode.VISUAL_CLIP

# 可视化设置
@export var show_clip_grid: bool = true
@export var clip_snap_threshold: float = 5.0  # 像素
@export var clip_min_display_width: float = 30.0

# 拖拽状态
var dragged_track: JuicyVisualFeedbackTrack = null
var drag_preview_clip: Rect2

# 绘制增强的时间轴
func _draw():
    if not current_timeline:
        return
    
    # 绘制基础时间轴
    _draw_timeline_ruler()
    
    # 绘制轨道
    for i in range(current_timeline.tracks.size()):
        var track = current_timeline.tracks[i]
        var track_rect = get_track_rect(i)
        
        # 绘制轨道背景
        draw_track_background(track, track_rect)
        
        # 绘制Clip可视化
        if track is JuicyVisualFeedbackTrack and global_edit_mode == TrackEditMode.VISUAL_CLIP:
            _draw_visual_clip(track as JuicyVisualFeedbackTrack, track_rect)
        
        # 绘制轨道内容
        draw_track_content(track, track_rect)

# 绘制可视化Clip
func _draw_visual_clip(track: JuicyVisualFeedbackTrack, track_rect: Rect2):
    var clip_rect = track.get_clip_screen_rect(track_rect)
    
    # 绘制Clip背景
    draw_rect(clip_rect, track.clip_color, true)
    
    # 绘制Clip边框
    draw_rect(clip_rect, Color.WHITE, false, track.clip_border_width)
    
    # 绘制拖动手柄
    if track.show_clip_handles:
        _draw_clip_handles(track, clip_rect)
    
    # 绘制Clip名称
    _draw_clip_name(track, clip_rect)

# 绘制拖动手柄
func _draw_clip_handles(track: JuicyVisualFeedbackTrack, clip_rect: Rect2):
    var handle_size = track.clip_handle_size
    var handle_color = Color.WHITE
    
    # 左手柄
    var left_handle = Rect2(clip_rect.position.x - handle_size/2,
                          clip_rect.position.y + clip_rect.size.y/2 - handle_size/2,
                          handle_size, handle_size)
    draw_rect(left_handle, handle_color)
    
    # 右手柄
    var right_handle = Rect2(clip_rect.position.x + clip_rect.size.x - handle_size/2,
                           clip_rect.position.y + clip_rect.size.y/2 - handle_size/2,
                           handle_size, handle_size)
    draw_rect(right_handle, handle_color)

# 绘制Clip名称
func _draw_clip_name(track: JuicyVisualFeedbackTrack, clip_rect: Rect2):
    var font = get_theme_font("font", "Label")
    if font:
        var text_pos = clip_rect.position + Vector2(5, clip_rect.size.y/2 - font.get_height()/2)
        draw_string(font, text_pos, track.clip_name)

# 处理输入事件
func _gui_input(event: InputEvent):
    if global_edit_mode != TrackEditMode.VISUAL_CLIP:
        return
    
    # 处理轨道拖拽
    for i in range(current_timeline.tracks.size()):
        var track = current_timeline.tracks[i]
        if track is JuicyVisualFeedbackTrack:
            var track_rect = get_track_rect(i)
            if track.handle_clip_input(event, track_rect):
                return  # 事件已处理
    
    # 处理时间轴点击
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        var clicked_time = get_time_at_position(event.position)
        if event.double_click:
            # 双击创建新Clip
            _create_clip_at_time(clicked_time)
```

### 5. 编辑器工具栏

```gdscript
# JuicyTimelineToolbar - Timeline工具栏
@tool
class_name JuicyTimelineToolbar
extends HBoxContainer

# 模式切换按钮
var traditional_mode_btn: Button
var visual_clip_mode_btn: Button

# 编辑工具
var snap_toggle_btn: Button
var grid_toggle_btn: Button
var zoom_slider: HSlider

func _ready():
    _create_mode_buttons()
    _create_edit_tools()
    _connect_signals()

# 创建模式切换按钮
func _create_mode_buttons():
    traditional_mode_btn = Button.new()
    traditional_mode_btn.text = "传统模式"
    traditional_mode_btn.toggle_mode = true
    traditional_mode_btn.pressed.connect(_on_traditional_mode_pressed)
    
    visual_clip_mode_btn = Button.new()
    visual_clip_mode_btn.text = "可视化模式"
    visual_clip_mode_btn.toggle_mode = true
    visual_clip_mode_btn.pressed.connect(_on_visual_clip_mode_pressed)
    
    add_child(traditional_mode_btn)
    add_child(visual_clip_mode_btn)

# 模式切换处理
func _on_traditional_mode_pressed():
    global_edit_mode = TrackEditMode.TRADITIONAL
    traditional_mode_btn.button_pressed = true
    visual_clip_mode_btn.button_pressed = false
    _update_timeline_display()

func _on_visual_clip_mode_pressed():
    global_edit_mode = TrackEditMode.VISUAL_CLIP
    visual_clip_mode_btn.button_pressed = true
    traditional_mode_btn.button_pressed = false
    _update_timeline_display()
```

### 6. 使用示例

```gdscript
# 创建可视化Timeline
func create_visual_timeline() -> JuicyTimelineResource:
    var timeline = JuicyTimelineResource.new()
    timeline.duration = 5.0
    
    # 创建可视化反馈轨道
    var visual_track = JuicyVisualFeedbackTrack.new()
    visual_track.edit_mode = TrackEditMode.VISUAL_CLIP
    visual_track.clip_start = 0.2      # 1秒开始 (0.2 * 5.0)
    visual_track.clip_end = 0.6        # 3秒结束 (0.6 * 5.0)
    visual_track.clip_color = Color.CYAN
    visual_track.clip_name = "攻击效果"
    visual_track.resource = attack_effect_resource
    
    timeline.tracks.append(visual_track)
    
    # 创建传统模式轨道（向后兼容）
    var traditional_track = JuicyFeedbackTrack.new()
    traditional_track.start_time = 3.5
    traditional_track.duration = 1.5
    traditional_track.resource = recovery_effect_resource
    
    timeline.tracks.append(traditional_track)
    
    return timeline

# 运行时切换编辑模式
func switch_edit_mode(mode: TrackEditMode):
    for track in timeline.tracks:
        if track is JuicyEnhancedTrack:
            track.edit_mode = mode
            track.sync_edit_modes()
    
    # 更新编辑器UI
    timeline_canvas.global_edit_mode = mode
    timeline_canvas.queue_redraw()
```

## 实现优势

### 1. 用户体验提升

- **直观操作**：拖拽调整时间，无需手动计算
- **可视化反馈**：清楚看到每个轨道的时间范围
- **快速编辑**：双击创建、拖拽调整、手柄缩放
- **降低学习成本**：类似Unity Timeline的操作方式

### 2. 开发者友好

- **向后兼容**：现有代码无需修改
- **灵活切换**：可以选择最适合的编辑模式
- **API一致性**：保持现有接口不变
- **扩展性强**：易于添加新的可视化功能

### 3. 编辑器集成

- **工具栏支持**：模式切换、吸附、网格显示
- **快捷键支持**：常用操作的键盘快捷键
- **撤销重做**：支持编辑操作的撤销重做
- **批量操作**：多选、批量调整时间

## 实施计划

### 阶段1：核心框架（1-2周）
1. 实现JuicyEnhancedTrack基类
2. 创建JuicyVisualFeedbackTrack
3. 实现基础的拖拽功能

### 阶段2：编辑器集成（2-3周）
1. 增强Timeline Canvas
2. 实现工具栏
3. 添加快捷键支持

### 阶段3：优化完善（3-4周）
1. 性能优化
2. 用户体验优化
3. 文档和示例完善

## 总结

混合模式方案通过同时支持传统模式和可视化Clip模式，既保证了向后兼容性，又提供了直观易用的现代化编辑体验。这种设计让Timeline系统更加强大和易用，同时保持了JuicyMixer V3架构的灵活性。

关键创新点：
1. **双模式支持**：传统模式 + 可视化模式
2. **直观拖拽**：直接在时间轴上操作
3. **可视化反馈**：清楚的Clip边界和手柄
4. **无缝切换**：实时切换编辑模式
5. **向后兼容**：现有代码无需修改