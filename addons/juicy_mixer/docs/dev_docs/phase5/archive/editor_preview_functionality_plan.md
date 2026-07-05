# 编辑器预览功能开发计划

## 概述

本文档详细描述了JuicyMixer V3中编辑器预览功能的开发计划。该系统提供了强大的编辑器内预览能力，包括实时效果预览、时间轴控制、预览状态管理和编辑器集成，使开发者能够在不运行游戏的情况下预览和调试效果。

## 系统架构

编辑器预览功能由以下核心组件构成：

- **JuicyPreviewManager** - 预览管理器
- **JuicyPreviewPanel** - 预览面板UI
- **JuicyTimelineControl** - 时间轴控制器
- **JuicyPreviewTarget** - 预览目标管理器

## 与现有系统的集成

### Director系统集成
- 预览系统需要与Director的执行流程同步
- 预览控制需要能够暂停和恢复Director
- 预览状态需要与Director状态保持一致

### 序列化系统协调
- 预览需要支持序列化和组合效果
- 预览控制需要能够控制序列化执行
- 预览状态需要考虑序列化的复杂性

### 事件系统协同
- 预览过程需要响应事件系统
- 预览控制需要能够触发事件
- 预览状态需要通过事件系统更新

### 状态还原协同
- 预览需要支持状态快照和还原
- 预览结束后需要恢复原始状态

## 开发时间线

**总体时间**：第15周（共1周）

## JuicyPreviewManager (预览管理器)

**文件路径**：`addons/juicy_mixer/editor/juicy_preview_manager.gd`

**核心职责**：
- 提供编辑器内预览
- 管理预览状态和控制
- 实现时间轴控制
- 支持实时预览更新

**详细实现计划**：

```gdscript
@tool
class_name JuicyPreviewManager
extends EditorPlugin

# 预览配置
var _preview_enabled: bool = true
var _preview_target: Node2D
var _preview_context_id: String = ""
var _preview_resource: JuicyFeedbackResource
var _preview_time_scale: float = 1.0
var _preview_loop: bool = false
var _preview_auto_restart: bool = false

# 预览状态
enum PreviewState {
    STOPPED,
    PLAYING,
    PAUSED,
    SEEKING
}

var _preview_state: PreviewState = PreviewState.STOPPED
var _preview_progress: float = 0.0
var _preview_duration: float = 0.0
var _original_state: Dictionary = {}

# 编辑器集成
var _preview_panel: Control
var _timeline_slider: HSlider
var _play_button: Button
var _stop_button: Button
var _pause_button: Button
var _restart_button: Button
var _loop_checkbox: CheckBox
var _time_scale_spinbox: SpinBox
var _progress_label: Label
var _target_selector: OptionButton

# 预览目标管理
var _preview_targets: Array[Node] = []
var _active_target_index: int = 0

func _enter_tree():
    _create_preview_panel()
    add_control_to_dock(DOCK_SLOT_LEFT_UL, _preview_panel)
    
    # 连接编辑器信号
    EditorInterface.get_selection().selection_changed.connect(_on_selection_changed)
    EditorInterface.get_resource_filesystem().resources_reimported.connect(_on_resources_reimported)

func _exit_tree():
    # 清理预览
    stop_preview()
    
    # 移除面板
    remove_control_from_docks(_preview_panel)
    _preview_panel.queue_free()

func _create_preview_panel() -> void:
    _preview_panel = VBoxContainer.new()
    _preview_panel.name = "JuicyMixer Preview"
    
    # 标题
    var title_label = Label.new()
    title_label.text = "JuicyMixer 预览"
    title_label.add_theme_font_size_override("font_size", 14)
    _preview_panel.add_child(title_label)
    
    # 分隔线
    var separator1 = HSeparator.new()
    _preview_panel.add_child(separator1)
    
    # 预览控制
    _create_preview_controls()
    
    # 分隔线
    var separator2 = HSeparator.new()
    _preview_panel.add_child(separator2)
    
    # 时间轴控制
    _create_timeline_controls()
    
    # 分隔线
    var separator3 = HSeparator.new()
    _preview_panel.add_child(separator3)
    
    # 预览设置
    _create_preview_settings()

func _create_preview_controls() -> void:
    var controls_container = HBoxContainer.new()
    
    # 播放/暂停按钮
    _play_button = Button.new()
    _play_button.text = "▶ 播放"
    _play_button.tooltip_text = "播放预览"
    _play_button.pressed.connect(_on_play_pressed)
    controls_container.add_child(_play_button)
    
    # 停止按钮
    _stop_button = Button.new()
    _stop_button.text = "■ 停止"
    _stop_button.tooltip_text = "停止预览"
    _stop_button.pressed.connect(_on_stop_pressed)
    controls_container.add_child(_stop_button)
    
    # 重启按钮
    _restart_button = Button.new()
    _restart_button.text = "↺ 重启"
    _restart_button.tooltip_text = "重启预览"
    _restart_button.pressed.connect(_on_restart_pressed)
    controls_container.add_child(_restart_button)
    
    _preview_panel.add_child(controls_container)

func _create_timeline_controls() -> void:
    var timeline_container = VBoxContainer.new()
    
    # 进度标签
    _progress_label = Label.new()
    _progress_label.text = "0.0s / 0.0s (0%)"
    timeline_container.add_child(_progress_label)
    
    # 时间轴滑块
    _timeline_slider = HSlider.new()
    _timeline_slider.min_value = 0.0
    _timeline_slider.max_value = 1.0
    _timeline_slider.step = 0.001
    _timeline_slider.value_changed.connect(_on_timeline_changed)
    _timeline_slider.drag_started.connect(_on_timeline_drag_started)
    _timeline_slider.drag_ended.connect(_on_timeline_drag_ended)
    timeline_container.add_child(_timeline_slider)
    
    _preview_panel.add_child(timeline_container)

func _create_preview_settings() -> void:
    var settings_container = VBoxContainer.new()
    
    # 目标选择器
    var target_label = Label.new()
    target_label.text = "预览目标:"
    settings_container.add_child(target_label)
    
    _target_selector = OptionButton.new()
    _target_selector.item_selected.connect(_on_target_selected)
    settings_container.add_child(_target_selector)
    
    # 时间缩放
    var time_scale_container = HBoxContainer.new()
    var time_scale_label = Label.new()
    time_scale_label.text = "时间缩放:"
    time_scale_container.add_child(time_scale_label)
    
    _time_scale_spinbox = SpinBox.new()
    _time_scale_spinbox.min_value = 0.1
    _time_scale_spinbox.max_value = 5.0
    _time_scale_spinbox.step = 0.1
    _time_scale_spinbox.value = 1.0
    _time_scale_spinbox.value_changed.connect(_on_time_scale_changed)
    time_scale_container.add_child(_time_scale_spinbox)
    
    settings_container.add_child(time_scale_container)
    
    # 循环选项
    _loop_checkbox = CheckBox.new()
    _loop_checkbox.text = "循环播放"
    _loop_checkbox.toggled.connect(_on_loop_toggled)
    settings_container.add_child(_loop_checkbox)
    
    _preview_panel.add_child(settings_container)

func _on_play_pressed() -> void:
    match _preview_state:
        PreviewState.STOPPED:
            start_preview()
        PreviewState.PLAYING:
            pause_preview()
        PreviewState.PAUSED:
            resume_preview()

func _on_stop_pressed() -> void:
    stop_preview()

func _on_restart_pressed() -> void:
    restart_preview()

func _on_timeline_changed(value: float) -> void:
    if _preview_state == PreviewState.SEEKING:
        seek_preview(value)

func _on_timeline_drag_started() -> void:
    if _preview_state == PreviewState.PLAYING:
        _preview_state = PreviewState.SEEKING

func _on_timeline_drag_ended() -> void:
    if _preview_state == PreviewState.SEEKING:
        _preview_state = PreviewState.PLAYING

func _on_target_selected(index: int) -> void:
    _active_target_index = index
    if _preview_target != _preview_targets[index]:
        stop_preview()
        _preview_target = _preview_targets[index]

func _on_time_scale_changed(value: float) -> void:
    _preview_time_scale = value
    if _preview_state == PreviewState.PLAYING:
        JuicyMixer.set_time_scale(_preview_context_id, value)

func _on_loop_toggled(pressed: bool) -> void:
    _preview_loop = pressed

func _on_selection_changed() -> void:
    # 更新预览目标列表
    _update_preview_targets()

func _on_resources_reimported(resources: Array[Resource]) -> void:
    # 检查预览资源是否被重新导入
    for resource in resources:
        if resource == _preview_resource:
            restart_preview()
            break

func _update_preview_targets() -> void:
    var selected_nodes = EditorInterface.get_selection().get_selected_nodes()
    _preview_targets.clear()
    _target_selector.clear()
    
    for node in selected_nodes:
        if node is Node2D or node is Node3D:
            _preview_targets.append(node)
            _target_selector.add_item(node.name)
    
    if _preview_targets.size() > 0:
        _active_target_index = 0
        _preview_target = _preview_targets[0]
        _target_selector.selected = 0

func start_preview() -> void:
    if not _preview_resource or not _preview_target:
        return
    
    # 保存原始状态
    _save_original_state()
    
    # 创建预览上下文
    _preview_context_id = JuicyMixer.play(_preview_resource, _preview_target)
    
    if not _preview_context_id.is_empty():
        _preview_state = PreviewState.PLAYING
        _play_button.text = "⏸ 暂停"
        
        # 设置时间缩放
        JuicyMixer.set_time_scale(_preview_context_id, _preview_time_scale)
        
        # 设置循环
        if _preview_loop:
            JuicyMixer.set_loop(_preview_context_id, true)

func pause_preview() -> void:
    if _preview_context_id.is_empty():
        return
    
    JuicyMixer.pause(_preview_context_id)
    _preview_state = PreviewState.PAUSED
    _play_button.text = "▶ 播放"

func resume_preview() -> void:
    if _preview_context_id.is_empty():
        return
    
    JuicyMixer.resume(_preview_context_id)
    _preview_state = PreviewState.PLAYING
    _play_button.text = "⏸ 暂停"

func stop_preview() -> void:
    if not _preview_context_id.is_empty():
        JuicyMixer.stop(_preview_context_id)
        _preview_context_id = ""
    
    # 恢复原始状态
    _restore_original_state()
    
    _preview_state = PreviewState.STOPPED
    _preview_progress = 0.0
    _play_button.text = "▶ 播放"
    _timeline_slider.value = 0.0
    _update_progress_label()

func restart_preview() -> void:
    stop_preview()
    start_preview()

func seek_preview(progress: float) -> void:
    if _preview_context_id.is_empty():
        return
    
    JuicyMixer.seek(_preview_context_id, progress)
    _preview_progress = progress

func _save_original_state() -> void:
    if not _preview_target:
        return
    
    _original_state.clear()
    
    # 保存Transform属性
    if "position" in _preview_target:
        _original_state["position"] = _preview_target.position
    if "rotation" in _preview_target:
        _original_state["rotation"] = _preview_target.rotation
    if "scale" in _preview_target:
        _original_state["scale"] = _preview_target.scale
    
    # 保存视觉属性
    if "modulate" in _preview_target:
        _original_state["modulate"] = _preview_target.modulate
    if "visible" in _preview_target:
        _original_state["visible"] = _preview_target.visible

func _restore_original_state() -> void:
    if not _preview_target or _original_state.is_empty():
        return
    
    # 恢复Transform属性
    if "position" in _original_state:
        _preview_target.position = _original_state["position"]
    if "rotation" in _original_state:
        _preview_target.rotation = _original_state["rotation"]
    if "scale" in _original_state:
        _preview_target.scale = _original_state["scale"]
    
    # 恢复视觉属性
    if "modulate" in _original_state:
        _preview_target.modulate = _original_state["modulate"]
    if "visible" in _original_state:
        _preview_target.visible = _original_state["visible"]

func _process(delta: float) -> void:
    if not _preview_enabled or _preview_context_id.is_empty():
        return
    
    var context = JuicyMixer.get_context(_preview_context_id)
    if context:
        _preview_progress = context.progress
        _preview_duration = context.duration
        
        # 更新时间轴
        if _preview_state != PreviewState.SEEKING:
            _timeline_slider.value = _preview_progress
        
        # 更新进度标签
        _update_progress_label()
        
        # 检查是否完成
        if context.is_completed:
            if _preview_loop:
                restart_preview()
            elif _preview_auto_restart:
                restart_preview()
            else:
                stop_preview()

func _update_progress_label() -> void:
    var current_time = _preview_progress * _preview_duration
    var progress_percent = _preview_progress * 100
    
    _progress_label.text = "%.1fs / %.1fs (%.0f%%)" % [
        current_time, _preview_duration, progress_percent
    ]

func set_preview_resource(resource: JuicyFeedbackResource) -> void:
    _preview_resource = resource
    stop_preview()

func get_preview_resource() -> JuicyFeedbackResource:
    return _preview_resource

func set_preview_target(target: Node) -> void:
    _preview_target = target
    stop_preview()
    _update_preview_targets()

func get_preview_target() -> Node:
    return _preview_target

func enable_preview() -> void:
    _preview_enabled = true

func disable_preview() -> void:
    _preview_enabled = false
    stop_preview()

func is_preview_enabled() -> bool:
    return _preview_enabled

func get_preview_state() -> PreviewState:
    return _preview_state
```

**开发任务分解**：
- [ ] 第15周第1天：预览面板UI设计
- [ ] 第15周第2天：预览控制逻辑
- [ ] 第15周第3天：时间轴控制
- [ ] 第15周第4天：实时预览更新
- [ ] 第15周第5天：编辑器集成和测试

## JuicyPreviewTarget (预览目标管理器)

**文件路径**：`addons/juicy_mixer/editor/juicy_preview_target.gd`

**核心职责**：
- 管理预览目标对象
- 提供目标选择和过滤
- 支持多目标预览

**详细实现计划**：

```gdscript
@tool
class_name JuicyPreviewTarget
extends RefCounted

# 预览目标配置
class PreviewTargetConfig:
    var target: Node
    var name: String
    var enabled: bool = true
    var auto_restore: bool = true
    var custom_properties: Dictionary = {}

var _preview_targets: Array[PreviewTargetConfig] = []
var _target_filters: Array[Callable] = []

func add_preview_target(target: Node, name: String = "") -> void:
    if name.is_empty():
        name = target.name
    
    var config = PreviewTargetConfig.new()
    config.target = target
    config.name = name
    
    _preview_targets.append(config)

func remove_preview_target(target: Node) -> void:
    for i in range(_preview_targets.size() - 1, -1, -1):
        if _preview_targets[i].target == target:
            _preview_targets.remove_at(i)

func get_preview_targets() -> Array[PreviewTargetConfig]:
    return _preview_targets.duplicate()

func get_enabled_targets() -> Array[PreviewTargetConfig]:
    var enabled_targets: Array[PreviewTargetConfig] = []
    for config in _preview_targets:
        if config.enabled:
            enabled_targets.append(config)
    return enabled_targets

func find_target_by_name(name: String) -> PreviewTargetConfig:
    for config in _preview_targets:
        if config.name == name:
            return config
    return null

func add_target_filter(filter_func: Callable) -> void:
    _target_filters.append(filter_func)

func remove_target_filter(filter_func: Callable) -> void:
    _target_filters.erase(filter_func)

func apply_filters(targets: Array[Node]) -> Array[Node]:
    var filtered_targets = targets.duplicate()
    
    for filter_func in _target_filters:
        var new_targets: Array[Node] = []
        for target in filtered_targets:
            if filter_func.call(target):
                new_targets.append(target)
        filtered_targets = new_targets
    
    return filtered_targets

func update_from_scene() -> void:
    # 从当前场景更新预览目标
    var scene_root = EditorInterface.get_edited_scene_root()
    if not scene_root:
        return
    
    _preview_targets.clear()
    _scan_scene_for_targets(scene_root)

func _scan_scene_for_targets(node: Node) -> void:
    # 检查当前节点是否是有效的预览目标
    if _is_valid_preview_target(node):
        add_preview_target(node)
    
    # 递归检查子节点
    for child in node.get_children():
        _scan_scene_for_targets(child)

func _is_valid_preview_target(node: Node) -> bool:
    # 检查节点是否是Node2D或Node3D
    if not (node is Node2D or node is Node3D):
        return false
    
    # 应用过滤器
    for filter_func in _target_filters:
        if not filter_func.call(node):
            return false
    
    return true
```

**开发任务分解**：
- [ ] 第15周第1天：目标管理基础实现
- [ ] 第15周第2天：目标过滤和选择
- [ ] 第15周第3天：多目标支持
- [ ] 第15周第5天：单元测试

## JuicyTimelineControl (时间轴控制器)

**文件路径**：`addons/juicy_mixer/editor/juicy_timeline_control.gd`

**核心职责**：
- 提供时间轴UI控件
- 支持时间轴交互
- 显示时间标记和进度

**详细实现计划**：

```gdscript
@tool
class_name JuicyTimelineControl
extends Control

# 时间轴配置
var _duration: float = 1.0
var _progress: float = 0.0
var _time_scale: float = 1.0
var _show_time_markers: bool = true
var _marker_interval: float = 1.0

# 时间轴样式
var _timeline_color: Color = Color.WHITE
var _progress_color: Color = Color.BLUE
var _marker_color: Color = Color.GRAY
var _handle_color: Color = Color.RED

# 交互状态
var _is_dragging: bool = false
var _drag_start_progress: float = 0.0

# 信号
signal progress_changed(progress: float)
signal seek_requested(progress: float)

func _ready():
    mouse_filter = Control.MOUSE_FILTER_PASS
    set_process_input(true)

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed:
                _is_dragging = true
                _drag_start_progress = _get_progress_from_position(event.position)
                seek_requested.emit(_drag_start_progress)
            else:
                _is_dragging = false
    
    elif event is InputEventMouseMotion and _is_dragging:
        var new_progress = _get_progress_from_position(event.position)
        _set_progress(new_progress)
        progress_changed.emit(new_progress)

func _draw() -> void:
    var rect = get_rect()
    var timeline_height = rect.size.y
    
    # 绘制时间轴背景
    draw_rect(rect, Color.BLACK)
    
    # 绘制进度条
    var progress_rect = Rect2(0, 0, rect.size.x * _progress, timeline_height)
    draw_rect(progress_rect, _progress_color)
    
    # 绘制时间标记
    if _show_time_markers:
        _draw_time_markers(rect)
    
    # 绘制拖动手柄
    if _is_dragging:
        var handle_x = rect.size.x * _progress
        var handle_rect = Rect2(handle_x - 4, 0, 8, timeline_height)
        draw_rect(handle_rect, _handle_color)

func _draw_time_markers(rect: Rect2) -> void:
    var marker_count = int(_duration / _marker_interval) + 1
    
    for i in range(marker_count):
        var time = i * _marker_interval
        var x = rect.size.x * (time / _duration)
        
        # 绘制垂直线
        draw_line(Vector2(x, 0), Vector2(x, rect.size.y), _marker_color)
        
        # 绘制时间文本
        var time_text = "%.1fs" % time
        draw_string(ThemeDB.fallback_font, Vector2(x + 2, rect.size.y - 2), time_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, _marker_color)

func _get_progress_from_position(position: Vector2) -> float:
    var rect = get_rect()
    var progress = position.x / rect.size.x
    return clamp(progress, 0.0, 1.0)

func _set_progress(progress: float) -> void:
    _progress = clamp(progress, 0.0, 1.0)
    queue_redraw()

func set_duration(duration: float) -> void:
    _duration = max(duration, 0.1)
    queue_redraw()

func set_progress(progress: float) -> void:
    _set_progress(progress)

func set_time_scale(time_scale: float) -> void:
    _time_scale = max(time_scale, 0.1)
    queue_redraw()

func set_show_time_markers(show: bool) -> void:
    _show_time_markers = show
    queue_redraw()

func set_marker_interval(interval: float) -> void:
    _marker_interval = max(interval, 0.1)
    queue_redraw()

func get_duration() -> float:
    return _duration

func get_progress() -> float:
    return _progress

func get_time_scale() -> float:
    return _time_scale
```

**开发任务分解**：
- [ ] 第15周第3天：时间轴基础实现
- [ ] 第15周第4天：时间轴交互功能
- [ ] 第15周第4天：时间标记和样式
- [ ] 第15周第5天：单元测试

## 性能优化

### 内存管理
- 编辑器预览需要最小化内存占用
- 预览状态需要高效的存储机制

### 执行效率
- 实时预览更新需要优化性能开销
- 时间轴控制需要响应迅速

## 测试计划

### 单元测试
- JuicyPreviewManager预览管理测试
- JuicyPreviewTarget目标管理测试
- JuicyTimelineControl时间轴控制测试

### 集成测试
- 与编辑器集成测试
- 与Director系统集成测试
- 与序列化系统集成测试

### 性能测试
- 实时预览性能测试
- 时间轴交互响应测试
- 内存使用优化验证

## 交付检查清单

### 代码交付
- [ ] JuicyPreviewManager预览系统
- [ ] JuicyPreviewTarget目标管理器
- [ ] JuicyTimelineControl时间轴控制器
- [ ] 单元测试和集成测试
- [ ] 性能基准测试

### 文档交付
- [ ] 编辑器预览功能使用文档
- [ ] API参考文档
- [ ] 性能优化指南

### 验收标准
- [ ] 所有单元测试通过（覆盖率100%）
- [ ] 所有集成测试通过
- [ ] 性能基准测试达标
- [ ] 代码审查通过
- [ ] 文档完整准确

## 风险管控

### 技术风险
1. **编辑器集成复杂性**：编辑器工具开发可能比预期复杂
   - 缓解措施：分阶段实现，先实现基础功能

2. **实时预览性能**：实时预览可能影响编辑器性能
   - 缓解措施：实现预览优化和性能监控

### 进度风险
1. **UI开发复杂性**：复杂的UI控件开发可能比预期耗时
   - 缓解措施：使用现有UI组件，简化设计

## 总结

编辑器预览功能是JuicyMixer V3的重要特性之一，它提供了强大的编辑器内预览能力。通过实时效果预览、时间轴控制和预览状态管理，开发者可以在不运行游戏的情况下预览和调试效果。

**关键成就**：
- 实现了完整的编辑器内预览系统
- 提供了直观的时间轴控制
- 确保了高效的预览性能
- 提供了灵活的目标管理

编辑器预览功能将为JuicyMixer V3用户提供优秀的开发体验，使效果的创建和调试变得更加便捷。